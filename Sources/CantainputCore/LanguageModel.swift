import Foundation

/// Character bigram model over written Cantonese, built by `tools/build_lm.py`.
///
/// It exists to answer one question the lexicon cannot: given that the previous
/// character was 我, is 想 or 上 more likely next? Word frequency alone ranks
/// 「我上食飯」 above 「我想食飯」; this fixes that without any runtime dependency.
///
/// The file is a flat sorted table of (prev << 16 | next) -> log10 P(next|prev),
/// quantised to Int16 thousandths. Binary search, no allocation per lookup.
public final class LanguageModel {
    public static let shared = LanguageModel()

    private var ids: [Character: UInt32] = [:]
    private var keys: [UInt32] = []
    private var scores: [Int16] = []
    public private(set) var isLoaded = false
    public private(set) var status = "not loaded"

    /// Score charged for a bigram the corpus never saw. Roughly the log10
    /// probability of a rare-but-legal pair, so unseen text is not treated as
    /// impossible.
    static let unseen = -3.0

    public func load(from url: URL) {
        guard let data = try? Data(contentsOf: url), data.count > 16 else {
            status = "missing model"
            NSLog("[Cantainput] lm %@", status)
            return
        }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            func u16(_ at: Int) -> UInt16 {
                UInt16(littleEndian: base.advanced(by: at).assumingMemoryBound(to: UInt16.self).pointee)
            }
            func u32(_ at: Int) -> UInt32 {
                UInt32(littleEndian: base.advanced(by: at).assumingMemoryBound(to: UInt32.self).pointee)
            }
            func i16(_ at: Int) -> Int16 {
                Int16(littleEndian: base.advanced(by: at).assumingMemoryBound(to: Int16.self).pointee)
            }
            guard u32(0) == 0x4D4C_4143 else {  // "CALM"
                status = "bad magic"
                return
            }
            let version = u16(4)
            let charCount = Int(u32(6))
            let biCount = Int(u32(10))
            offset = 14

            var table: [Character: UInt32] = [:]
            table.reserveCapacity(charCount)
            for i in 0..<charCount {
                let unit = u16(offset + i * 2)
                if let scalar = Unicode.Scalar(unit) {
                    table[Character(scalar)] = UInt32(i)
                }
            }
            offset += charCount * 2

            var k: [UInt32] = Array(repeating: 0, count: biCount)
            var v: [Int16] = Array(repeating: 0, count: biCount)
            for i in 0..<biCount {
                k[i] = u32(offset + i * 6)
                v[i] = i16(offset + i * 6 + 4)
            }
            ids = table
            keys = k
            scores = v
            isLoaded = true
            status = "loaded v\(version) \(charCount) chars \(biCount) bigrams"
        }
        NSLog("[Cantainput] lm %@", status)
    }

    public var bigramCount: Int { keys.count }

    private func id(of c: Character) -> UInt32? { ids[c] }

    private func lookup(_ a: UInt32, _ b: UInt32) -> Int16? {
        let target = (a << 16) | b
        var lo = 0
        var hi = keys.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let value = keys[mid]
            if value == target { return scores[mid] }
            if value < target { lo = mid + 1 } else { hi = mid - 1 }
        }
        return nil
    }

    /// Sum of log10 P(c_i | c_{i-1}) over the sentence. Characters outside the
    /// alphabet break the chain rather than penalising it.
    public func score(_ text: String) -> Double {
        guard isLoaded else { return 0 }
        var total = 0.0
        var previous: UInt32?
        for ch in text {
            guard let current = id(of: ch) else {
                // A character the corpus never saw is not free: charge it like an
                // unseen bigram, otherwise rare glyphs outrank common ones.
                total += LanguageModel.unseen
                previous = nil
                continue
            }
            if let prev = previous {
                if let q = lookup(prev, current) {
                    total += Double(q) / 1000.0
                } else {
                    total += LanguageModel.unseen
                }
            }
            previous = current
        }
        return total
    }

    /// Per-character average, used to compare sentences of different length.
    public func averageScore(_ text: String) -> Double {
        let n = text.count
        guard n > 1 else { return 0 }
        return score(text) / Double(n - 1)
    }
}
