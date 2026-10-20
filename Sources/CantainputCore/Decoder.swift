import Foundation

/// Sentence decoder: turns a run of toneless jyutping letters into the best
/// segmentation, plus near-best alternatives.
public enum Decoder {
    struct Step {
        let score: Double
        let text: String
        let code: String
        let words: [String]
        let codes: [String]
    }

    /// Bonus for each extra syllable inside a word. Without it a unigram model
    /// prefers single characters (their raw frequencies add up higher).
    static let wordBonus = 3000.0

    /// How many paths survive at each input position.
    static let beam = 40

    /// Top `limit` full decodings of `letters`, best first.
    public static func nbest(_ letters: String, limit: Int) -> [Candidate] {
        let chars = Array(letters)
        let n = chars.count
        guard n > 0, n <= 32 else { return [] }
        let lex = Lexicon.shared
        guard !lex.syllables.isEmpty else { return [] }

        // Every syllable end reachable from each position.
        var ends: [[Int]] = Array(repeating: [], count: n + 1)
        let maxLen = lex.maxSyllableLength
        for p in 0..<n {
            var e = p + 1
            while e <= n && e - p <= maxLen {
                if lex.syllables.contains(String(chars[p..<e])) { ends[p].append(e) }
                e += 1
            }
        }

        var best: [[Step]] = Array(repeating: [], count: n + 1)
        best[0] = [Step(score: 0, text: "", code: "", words: [], codes: [])]

        for p in 0..<n {
            guard !best[p].isEmpty else { continue }
            if best[p].count > beam {
                best[p].sort { $0.score > $1.score }
                best[p] = Array(best[p].prefix(beam))
            }
            guard !ends[p].isEmpty else { continue }

            var stack: [(pos: Int, key: String, syls: Int)] = [(p, "", 0)]
            while let node = stack.popLast() {
                for e in ends[node.pos] {
                    let nextKey = node.key + String(chars[node.pos..<e])
                    let syls = node.syls + 1
                    if let entries = lex.byKey[nextKey] {
                        for en in entries {
                            let bonus = Learning.shared.bonus(code: en.key, text: en.text)
                            var wordScore = Double(en.score) + bonus
                                + wordBonus * Double(syls - 1)
                            wordScore += Lexicon.prior(en.text)
                            let parts = Lexicon.splitToned(en.toned)
                            let wordCode = parts.joined(separator: " ")
                            for prev in best[p] {
                                best[e].append(Step(
                                    score: prev.score + wordScore,
                                    text: prev.text + en.text,
                                    code: prev.code.isEmpty ? wordCode : prev.code + " " + wordCode,
                                    words: prev.words + [en.text],
                                    codes: prev.codes + [wordCode]))
                            }
                        }
                    }
                    if syls < lex.maxSyllables && e < n {
                        stack.append((e, nextKey, syls))
                    }
                }
            }
        }

        var final = best[n]
        guard !final.isEmpty else { return [] }
        final.sort { $0.score > $1.score }
        var seen: Set<String> = []
        var out: [Candidate] = []
        for step in final {
            guard !seen.contains(step.text) else { continue }
            seen.insert(step.text)
            out.append(Candidate(text: step.text, code: step.code, score: step.score,
                                 words: step.words, codes: step.codes))
            if out.count >= limit { break }
        }
        return out
    }
}
