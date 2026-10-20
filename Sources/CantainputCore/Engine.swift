import Foundation

public struct Candidate {
    public let text: String
    public let code: String
    public let score: Double
    public init(text: String, code: String, score: Double) {
        self.text = text
        self.code = code
        self.score = score
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
            loadStatus = "loaded \(Lexicon.shared.entryCount) entries"
        } catch {
            loadStatus = "load failed: \(error)"
        }
        NSLog("[Cantainput] lexicon %@", loadStatus)
    }

    public var entryCount: Int { Lexicon.shared.entryCount }

    public func candidates(for raw: String, limit: Int = 9) -> [Candidate] {
        ensureLoaded()
        return rank(input: raw, limit: limit)
    }

    public func rank(input raw: String, limit: Int) -> [Candidate] {
        let input = String(raw.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        guard !input.isEmpty else { return [] }
        let withTones = input.contains(where: { $0.isNumber })
        let lookup = String(input.filter { !$0.isNumber })
        var best: [String: Candidate] = [:]
        for e in Lexicon.shared.matches(prefix: lookup) {
            if withTones && !e.toned.hasPrefix(input) { continue }
            var s = Double(e.score) + Learning.shared.bonus(code: e.key, text: e.text)
            if e.key == lookup && !withTones { s += 200 }
            if e.toned == input { s += 200 }
            if let prev = best[e.text], prev.score >= s { continue }
            best[e.text] = Candidate(text: e.text, code: e.toned, score: s)
        }
        return Array(best.values.sorted { $0.score > $1.score }.prefix(limit))
    }
}
