import Foundation

public struct Candidate {
    public let text: String
    public let code: String
    public let score: Double
    /// Per-word text of a decoded sentence (for learning).
    public let words: [String]
    /// Toned jyutping of each word, same order.
    public let codes: [String]
    /// True when the decoder had to correct a mistyped syllable to produce this.
    public let fuzzy: Bool

    public init(text: String, code: String, score: Double,
                words: [String] = [], codes: [String] = [], fuzzy: Bool = false) {
        self.text = text
        self.code = code
        self.score = score
        self.fuzzy = fuzzy
        self.words = words.isEmpty ? [text] : words
        self.codes = codes.isEmpty ? [code] : codes
    }
}

public final class Engine {
    public static let shared = Engine()
    private var ready = false
    public private(set) var loadStatus = "not loaded"

    public func ensureLoaded() {
        guard !ready else { return }
        ready = true
        guard let url = Bundle.main.url(forResource: "jyutping", withExtension: "tsv") else {
            loadStatus = "missing jyutping.tsv"
            NSLog("[Cantainput] %@", loadStatus)
            return
        }
        do {
            try Lexicon.shared.load(from: url)
            loadStatus = "loaded \(Lexicon.shared.entryCount) entries, "
                + "\(Lexicon.shared.syllables.count) syllables, "
                + "max \(Lexicon.shared.maxSyllables) per word"
        } catch {
            loadStatus = "load failed: \(error)"
        }
        if let lmURL = Bundle.main.url(forResource: "zh_char_bigram", withExtension: "bin") {
            LanguageModel.shared.load(from: lmURL)
        }
        NSLog("[Cantainput] lexicon %@", loadStatus)
    }

    public var entryCount: Int { Lexicon.shared.entryCount }

    static func normalize(_ raw: String) -> String {
        String(raw.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    /// Candidates for the whole composition. Tones fall back to prefix search;
    /// plain letters go through the sentence decoder and are then padded with
    /// word-level prefix matches.
    public func candidates(for raw: String, limit: Int = 18) -> [Candidate] {
        ensureLoaded()
        let input = Engine.normalize(raw)
        guard !input.isEmpty else { return [] }

        if input.contains(where: { $0.isNumber }) {
            return rank(input: input, limit: limit)
        }

        let pool = max(limit * 18, 120)
        var merged: [String: Candidate] = [:]
        func add(_ list: [Candidate], penalty: Double) {
            for c in list {
                let score = c.score + penalty
                if let prev = merged[c.text], prev.score >= score { continue }
                merged[c.text] = Candidate(text: c.text, code: c.code, score: score,
                                           words: c.words, codes: c.codes, fuzzy: c.fuzzy)
            }
        }

        // 1. Exact decoding. This is the normal path.
        add(Decoder.nbest(input, limit: pool), penalty: 0)

        // 2. The typo is usually in the syllable being typed, so a truncated
        //    prefix often decodes cleanly while the full string does not.
        if merged.count < limit {
            var dropped = 1
            while dropped <= 3 && input.count - dropped >= 2 {
                let prefix = String(input.dropLast(dropped))
                add(Decoder.nbest(prefix, limit: pool), penalty: -1000 * Double(dropped))
                dropped += 1
            }
        }

        // 3. Last resort: repair one syllable at a time. Kept behind the first
        //    two stages because it costs milliseconds rather than microseconds.
        if merged.count < limit {
            add(Decoder.nbest(input, limit: pool, fuzzy: true), penalty: 0)
        }

        // A repaired reading that still scores below zero is noise, not a guess.
        var poolOut = merged.values.filter { $0.score > 0 }

        // Rerank with the character bigram model. Word frequency alone cannot
        // tell 我想食飯 from 我上食飯; the bigram can. Averaged per character so
        // long and short candidates stay comparable.
        let lm = LanguageModel.shared
        if lm.isLoaded {
            poolOut = poolOut.map { c in
                Candidate(text: c.text, code: c.code,
                          score: c.score + Engine.lmWeight * lm.score(c.text),
                          words: c.words, codes: c.codes, fuzzy: c.fuzzy)
            }
        }

        var out = Engine.diversify(poolOut.sorted { $0.score > $1.score }, limit: limit)
        if out.count < limit {
            let seen = Set(out.map { $0.text })
            let filler = rank(input: input, limit: limit * 3).filter { !seen.contains($0.text) }
            out.append(contentsOf: filler.prefix(limit - out.count))
        }
        if out.isEmpty { return rank(input: input, limit: limit) }
        return out
    }

    /// Log10 probability is worth this much per unit, in the same units as
    /// `LexEntry.score`. Every candidate for one input covers the same syllables,
    /// so the sum is length-neutral here even though it is a sum.
    public static var lmWeight = 600.0

    /// Kill near-duplicates: candidates that differ only in their first
    /// character are useless to show eight times.
    static func diversify(_ items: [Candidate], limit: Int) -> [Candidate] {
        var tails: [String: Int] = [:]
        var heads: [String: Int] = [:]
        var out: [Candidate] = []
        for c in items {
            if c.text.count >= 2 {
                let tail = String(c.text.dropFirst())
                let seen = tails[tail, default: 0]
                if seen >= 2 { continue }
                // Also cap candidates that agree on everything but the last
                // character, otherwise 你食咗飯未/咪/沒/美 fill the whole strip.
                let head = String(c.text.dropLast())
                let headSeen = heads[head, default: 0]
                if headSeen >= 3 { continue }
                tails[tail] = seen + 1
                heads[head] = headSeen + 1
            }
            out.append(c)
            if out.count >= limit { break }
        }
        return out
    }

    /// Word-level prefix search. Used for toned input and as filler.
    public func rank(input raw: String, limit: Int) -> [Candidate] {
        let input = Engine.normalize(raw)
        guard !input.isEmpty else { return [] }
        let withTones = input.contains(where: { $0.isNumber })
        let lookup = String(input.filter { !$0.isNumber })
        var best: [String: Candidate] = [:]
        for e in Lexicon.shared.matches(prefix: lookup) {
            if withTones && !e.toned.hasPrefix(input) { continue }
            var s = Double(e.score) + Learning.shared.bonus(code: e.key, text: e.text)
            s += Lexicon.prior(e.text)
            if e.key == lookup && !withTones { s += 200 }
            if e.toned == input { s += 200 }
            if let prev = best[e.text], prev.score >= s { continue }
            best[e.text] = Candidate(text: e.text,
                                     code: Lexicon.splitToned(e.toned).joined(separator: " "),
                                     score: s,
                                     words: [e.text],
                                     codes: [e.toned])
        }
        return Array(best.values.sorted { $0.score > $1.score }.prefix(limit))
    }
}
