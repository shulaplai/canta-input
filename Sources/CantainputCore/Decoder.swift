import Foundation

/// Sentence decoder: turns a run of toneless jyutping letters into the best
/// segmentation, plus near-best alternatives.
///
/// The lattice is built over *syllable* boundaries rather than raw letters, so a
/// single mistyped syllable can be repaired without blowing up the search. In
/// fuzzy mode every syllable within one edit of what was typed becomes an edge
/// that pays `fuzzyPenalty`, which keeps correct readings ahead of repaired ones
/// while still producing something when the typist slips.
public enum Decoder {
    struct Step {
        let score: Double
        let text: String
        let code: String
        let words: [String]
        let codes: [String]
        let fuzzy: Bool
    }

    struct Edge {
        let end: Int
        let syllable: String
        let penalty: Double
    }

    /// Bonus for each extra syllable inside a word. Without it a unigram model
    /// prefers single characters (their raw frequencies add up higher).
    static let wordBonus = 3000.0

    /// How many paths survive at each input position.
    static let beam = 24

    /// Paid by every repaired syllable. Large enough that any exact reading wins.
    static let fuzzyPenalty = 4000.0

    /// A reading may repair at most this many syllables. Two is already a lot of
    /// slack; beyond that the lattice explodes without getting more useful.
    static let maxRepairs = 2

    /// Hard ceiling on lattice nodes visited, so a garbage input cannot stall
    /// the typing path.
    static let nodeBudget = 60_000

    /// Top `limit` full decodings of `letters`, best first.
    public static func nbest(_ letters: String, limit: Int, fuzzy: Bool = false) -> [Candidate] {
        let chars = Array(letters)
        let n = chars.count
        guard n > 0, n <= 32 else { return [] }
        let lex = Lexicon.shared
        guard !lex.syllables.isEmpty else { return [] }

        let edges = buildEdges(chars, fuzzy: fuzzy)

        var best: [[Step]] = Array(repeating: [], count: n + 1)
        best[0] = [Step(score: 0, text: "", code: "", words: [], codes: [], fuzzy: false)]

        var budget = nodeBudget
        for p in 0..<n {
            guard !best[p].isEmpty else { continue }
            if best[p].count > beam {
                best[p].sort { $0.score > $1.score }
                best[p] = Array(best[p].prefix(beam))
            }
            guard !edges[p].isEmpty else { continue }

            var stack: [(pos: Int, key: String, syls: Int, pen: Double, fuzzy: Bool, repairs: Int)] =
                [(p, "", 0, 0, false, 0)]
            walk: while let node = stack.popLast() {
                budget -= 1
                if budget <= 0 { break walk }
                for edge in edges[node.pos] {
                    let nextKey = node.key + edge.syllable
                    let syls = node.syls + 1
                    let pen = node.pen + edge.penalty
                    let repairs = node.repairs + (edge.penalty < 0 ? 1 : 0)
                    let wasFuzzy = node.fuzzy || repairs > node.repairs
                    if let entries = lex.byKey[nextKey] {
                        for en in entries {
                            let wordScore = Double(en.score)
                                + Learning.shared.bonus(code: en.key, text: en.text)
                                + wordBonus * Double(syls - 1)
                                + Lexicon.prior(en.text)
                                + pen
                            let parts = Lexicon.splitToned(en.toned)
                            let wordCode = parts.joined(separator: " ")
                            for prev in best[p] {
                                best[edge.end].append(Step(
                                    score: prev.score + wordScore,
                                    text: prev.text + en.text,
                                    code: prev.code.isEmpty ? wordCode : prev.code + " " + wordCode,
                                    words: prev.words + [en.text],
                                    codes: prev.codes + [wordCode],
                                    fuzzy: prev.fuzzy || wasFuzzy))
                            }
                        }
                    }
                    if syls < lex.maxSyllables && edge.end < n && repairs <= maxRepairs {
                        stack.append((edge.end, nextKey, syls, pen, wasFuzzy, repairs))
                    }
                }
            }
        }

        if budget <= 0 { NSLog("[Cantainput] decoder hit node budget") }
        var final = best[n]
        guard !final.isEmpty else { return [] }
        final.sort { $0.score > $1.score }
        var seen: Set<String> = []
        var out: [Candidate] = []
        for step in final {
            guard !seen.contains(step.text) else { continue }
            seen.insert(step.text)
            out.append(Candidate(text: step.text, code: step.code, score: step.score,
                                 words: step.words, codes: step.codes, fuzzy: step.fuzzy))
            if out.count >= limit { break }
        }
        return out
    }

    // MARK: - Lattice

    private static func buildEdges(_ chars: [Character], fuzzy: Bool) -> [[Edge]] {
        let n = chars.count
        let lex = Lexicon.shared
        var edges: [[Edge]] = Array(repeating: [], count: n + 1)

        // Exact syllables first: one cheap slice-and-lookup per position.
        for p in 0..<n {
            var e = p + 1
            while e <= n && e - p <= lex.maxSyllableLength {
                let s = String(chars[p..<e])
                if lex.syllables.contains(s) {
                    edges[p].append(Edge(end: e, syllable: s, penalty: 0))
                }
                e += 1
            }
        }
        guard fuzzy else { return edges }

        // Repairs: for each reachable end, the closest syllables one edit away.
        // Keeping only a couple per end is what makes the fuzzy lattice cheap —
        // the raw cartesian product is thousands of edges per position.
        for p in 0..<n {
            var perEnd: [Int: [(priority: Int, syllable: String)]] = [:]
            for (len, group) in lex.syllablesByLength {
                for s in group {
                    let charsOf = Array(s)
                    for l in [len - 1, len, len + 1] {
                        guard l >= 1, p + l <= n else { continue }
                        let slice = Array(chars[p..<(p + l)])
                        if l == len && String(slice) == s { continue }
                        guard withinOne(charsOf, slice) else { continue }
                        let priority = l == len ? 0 : 1
                        perEnd[p + l, default: []].append((priority, s))
                    }
                }
            }
            for (end, options) in perEnd {
                let best = options.sorted { $0.priority < $1.priority }.prefix(2)
                for option in best {
                    edges[p].append(Edge(end: end, syllable: option.syllable,
                                         penalty: -fuzzyPenalty))
                }
            }
        }
        return edges
    }

    /// True when `a` and `b` differ by exactly one insertion, deletion or
    /// substitution. Transpositions are not repaired — in jyutping a swapped
    /// pair is nearly always two different syllables, not a typo.
    static func withinOne(_ a: [Character], _ b: [Character]) -> Bool {
        let la = a.count, lb = b.count
        if la == lb {
            var diff = 0
            for i in 0..<la where a[i] != b[i] {
                diff += 1
                if diff > 1 { return false }
            }
            return diff == 1
        }
        let (short, long) = la < lb ? (a, b) : (b, a)
        if long.count - short.count != 1 { return false }
        var i = 0, j = 0
        var skipped = false
        while i < short.count && j < long.count {
            if short[i] == long[j] {
                i += 1
                j += 1
            } else if skipped {
                return false
            } else {
                skipped = true
                j += 1
            }
        }
        return true
    }
}
