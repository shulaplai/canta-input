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
        loaded = true
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
