import Foundation

public struct LexEntry {
    public let key: String      // toneless jyutping, e.g. "ngodei"
    public let toned: String    // tone-marked, e.g. "ngo5dei6"
    public let text: String
    public let score: Int32

    public init(key: String, toned: String, text: String, score: Int32) {
        self.key = key
        self.toned = toned
        self.text = text
        self.score = score
    }
}

/// Immutable, sorted view of the compiled jyutping lexicon.
public final class Lexicon {
    public static let shared = Lexicon()

    private var entries: [LexEntry] = []
    private var loaded = false
    public private(set) var entryCount = 0

    /// Toneless key -> entries. Used by the sentence decoder.
    public private(set) var byKey: [String: [LexEntry]] = [:]
    /// Every distinct toneless syllable in the lexicon, derived from toned keys.
    public private(set) var syllables: Set<String> = []
    /// Longest syllable length in letters ("gwaang" is 6).
    public private(set) var maxSyllableLength = 1
    /// Most syllables in one lexicon entry.
    public private(set) var maxSyllables = 1
    /// Syllables grouped by letter length, used by the fuzzy decoder.
    public private(set) var syllablesByLength: [Int: [String]] = [:]

    public func load(from url: URL) throws {
        guard !loaded else { return }
        let data = try Data(contentsOf: url)
        guard let blob = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Cantainput", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "lexicon is not valid UTF-8"])
        }
        var out: [LexEntry] = []
        out.reserveCapacity(150_000)
        for line in blob.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { continue }
            let key = fields[0], text = fields[2]
            guard !key.isEmpty, !text.isEmpty else { continue }
            out.append(LexEntry(key: String(key),
                                toned: String(fields[1]),
                                text: String(text),
                                score: Int32(fields[3]) ?? 0))
        }
        entries = out
        entryCount = out.count
        buildIndex()
        loaded = true
    }

    private func buildIndex() {
        var index: [String: [LexEntry]] = [:]
        index.reserveCapacity(100_000)
        for e in entries { index[e.key, default: []].append(e) }
        byKey = index

        var syl: Set<String> = []
        var longest = 1
        var most = 1
        for e in entries {
            let parts = Lexicon.splitSyllables(e.toned)
            most = max(most, parts.count)
            for p in parts {
                syl.insert(p)
                longest = max(longest, p.count)
            }
        }
        syllables = syl
        maxSyllableLength = longest
        maxSyllables = most

        var byLength: [Int: [String]] = [:]
        for s in syl { byLength[s.count, default: []].append(s) }
        syllablesByLength = byLength
    }

    /// Characters that are essentially Cantonese-only. A word containing one is
    /// far more likely to be what a jyutping typist meant, so it gets a boost
    /// over Mandarin homophones.
    public static let cantoneseChars: Set<Character> = Set("哋唔咗喺啲佢乜嘅嚟嗰咁嘢冇睇攞諗傾瞓掟嘞喇囉喎咩咪噉㗎嗌靚攰撳揸唞嚿喐㩒嘅")

    public static func containsCantonese(_ text: String) -> Bool {
        for ch in text where cantoneseChars.contains(ch) { return true }
        return false
    }

    /// Written-Chinese function characters. A colloquial jyutping typist rarely
    /// means these, so they are mildly demoted.
    public static let writtenChineseChars: Set<Character> = Set("說與於如或並卻僅曾已將被麼這那之其乃")

    public static func writtenChinesePenalty(_ text: String) -> Double {
        var hits = 0
        for ch in text where writtenChineseChars.contains(ch) {
            hits += 1
            if hits >= 2 { break }
        }
        return -200.0 * Double(hits)
    }

    /// Language prior shared by the decoder and the prefix ranker.
    public static func prior(_ text: String) -> Double {
        (containsCantonese(text) ? 600 : 0) + writtenChinesePenalty(text)
    }

    /// "nei5hou2" -> ["nei5", "hou2"]. Keeps the tone digits for display.
    static func splitToned(_ toned: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in toned {
            if ch.isLetter {
                current.append(ch)
            } else if ch.isNumber {
                current.append(ch)
                out.append(current)
                current = ""
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    /// "nei5hou2" -> ["nei", "hou"]; digits and letters are the only inputs.
    static func splitSyllables(_ toned: String) -> [String] {
        var out: [String] = []
        var current = ""
        for ch in toned {
            if ch.isLetter {
                current.append(ch)
            } else if ch.isNumber {
                if !current.isEmpty { out.append(current); current = "" }
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    private func lowerBound(_ prefix: String) -> Int {
        var lo = 0, hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].key < prefix { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Entries whose toneless key starts with `prefix`, capped for safety.
    public func matches(prefix: String, cap: Int = 20_000) -> [LexEntry] {
        guard loaded, !prefix.isEmpty else { return [] }
        var idx = lowerBound(prefix)
        var result: [LexEntry] = []
        while idx < entries.count, entries[idx].key.hasPrefix(prefix) {
            result.append(entries[idx])
            idx += 1
            if result.count >= cap { break }
        }
        return result
    }
}
