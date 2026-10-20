import Foundation

public struct Candidate {
    public let text: String
    public let code: String
    public let score: Double
    /// Per-word text of a decoded sentence (for learning).
    public let words: [String]
    /// Toned jyutping of each word, same order.
    public let codes: [String]

    public init(text: String, code: String, score: Double,
                words: [String] = [], codes: [String] = []) {
        self.text = text
        self.code = code
        self.score = score
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

        var out = Engine.diversify(Decoder.nbest(input, limit: max(limit * 40, 200)), limit: limit)
        if out.count < limit {
            let seen = Set(out.map { $0.text })
            let filler = rank(input: input, limit: limit * 3).filter { !seen.contains($0.text) }
            out.append(contentsOf: filler.prefix(limit - out.count))
        }
        if out.isEmpty { return rank(input: input, limit: limit) }
        return out
    }

    /// Kill near-duplicates: candidates that differ only in their first
    /// character are useless to show eight times.
    static func diversify(_ items: [Candidate], limit: Int) -> [Candidate] {
        var tails: [String: Int] = [:]
        var out: [Candidate] = []
        for c in items {
            if c.text.count >= 2 {
                let tail = String(c.text.dropFirst())
                let seen = tails[tail, default: 0]
                if seen >= 2 { continue }
                tails[tail] = seen + 1
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
