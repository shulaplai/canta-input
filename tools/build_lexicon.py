#!/usr/bin/env python3
"""Convert rime-cantonese tables + rime-essay frequencies into a TSV index.

Output columns: toneless_key \t toned_key \t text \t score
score = 100 * log1p(frequency), estimated from component chars when absent.
"""
import math
import os
import sys

DATA = os.path.join(os.path.dirname(__file__), "..", "Data")
OUT = os.path.join(os.path.dirname(__file__), "..", "Resources", "jyutping.tsv")
TABLES = ["chars", "words", "phrase", "lettered", "maps"]


def rows(path):
    seen = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not seen:
                if line.strip() == "...":
                    seen = True
                continue
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            text, code = parts[0].strip(), parts[1].strip()
            if text and code:
                yield text, code, (parts[2].strip() if len(parts) > 2 else "")


def load_essay(path):
    word, char = {}, {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            try:
                w = int(parts[1])
            except ValueError:
                continue
            word[parts[0]] = w
            if len(parts[0]) == 1:
                char[parts[0]] = w
    return word, char


def main():
    word_freq, char_freq = load_essay(os.path.join(DATA, "essay.txt"))
    print("essay: words=%d chars=%d" % (len(word_freq), len(char_freq)), file=sys.stderr)

    def score(text):
        f = word_freq.get(text)
        if f is None and len(text) > 1:
            known = [char_freq[c] for c in text if c in char_freq]
            if len(known) == len(text):
                f = min(known) * 0.5 ** (len(text) - 1)
        return 100.0 * math.log1p(f) if f else 0.0

    seen = set()
    first_seen = set()
    out_rows = []
    for table in TABLES:
        path = os.path.join(DATA, "jyut6ping3.%s.dict.yaml" % table)
        if not os.path.exists(path):
            print("missing", path, file=sys.stderr)
            continue
        for text, code, pct in rows(path):
            toned = "".join(ch for ch in code.lower() if ch.isalnum())
            toneless = "".join(ch for ch in toned if not ch.isdigit())
            if not toneless or any(ch.isdigit() for ch in toneless):
                continue
            k = (toned, text)
            if k in seen:
                continue
            seen.add(k)
            # The first listed reading of a character is its usual one; nudge it
            # ahead of the alternate readings that share the same frequency.
            fk = text + "\u0000" + toneless
            first = fk not in first_seen
            if first:
                first_seen.add(fk)
            s = score(text) + (5.0 if first else 0.0)
            out_rows.append((toneless, toned, text, int(round(s))))

    out_rows.sort(key=lambda r: (r[0], -r[3]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as out:
        for r in out_rows:
            out.write("%s\t%s\t%s\t%d\n" % r)
    print("entries: %d  bytes: %d" % (len(out_rows), os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
