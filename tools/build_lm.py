#!/usr/bin/env python3
"""Build a character bigram language model from Cantonese Wikipedia.

Input : Data/zh_yuewiki.xml.bz2   (wikimedia dump, fetched by tools/fetch_corpus.sh)
Output: Resources/zh_char_bigram.bin

The model is deliberately tiny and dependency-free: an alphabet of characters,
then a sorted table of (prev, next) -> quantised log10 P(next | prev). The Swift
side binary-searches it. No KenLM, no ARPA parser, no C++.

Only Han characters carry context. Everything else (punctuation, markup,
whitespace) is a boundary, so a bigram never straddles two sentences.

Usage:
    python3 tools/build_lm.py [--min-count 2] [--dump Data/zh_yuewiki.xml.bz2]
"""

import argparse
import bz2
import math
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
from collections import Counter

HAN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
TAG = re.compile(r"<[^>]{0,200}>")
REF = re.compile(r"<ref[^>]*?/>|<ref[^>]*?>.*?</ref>", re.S)
COMMENT = re.compile(r"<!--.*?-->", re.S)
BRACE = re.compile(r"\{\{[^{}]*\}\}", re.S)
TABLE = re.compile(r"\{\|.*?\|\}", re.S)
LINK = re.compile(r"\[\[([^\[\]|]*)\|?([^\[\]]*)\]\]")
EXT = re.compile(r"\[https?://[^\]]*\]")
URL = re.compile(r"https?://\S+")
SPECIAL = re.compile(r"\[\[(File|Image|Category|分類|檔案|文件):.*?\]\]", re.S | re.I)


def strip_markup(text: str) -> str:
    text = COMMENT.sub("", text)
    text = REF.sub("", text)
    text = SPECIAL.sub("", text)
    text = TABLE.sub("", text)
    for _ in range(4):  # nested templates
        new = BRACE.sub("", text)
        if new == text:
            break
        text = new
    text = LINK.sub(lambda m: m.group(2) or m.group(1), text)
    text = EXT.sub("", text)
    text = URL.sub("", text)
    text = TAG.sub("", text)
    text = text.replace("'''", "").replace("''", "")
    return text


def sentences(text: str):
    """Yield runs of Han characters, dropping everything else."""
    for run in re.split(r"[^\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+", text):
        if run:
            yield run


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", default="Data/zh_yuewiki.xml.bz2")
    ap.add_argument("--out", default="Resources/zh_char_bigram.bin")
    ap.add_argument("--min-count", type=int, default=2)
    ap.add_argument("--min-char", type=int, default=5,
                    help="ignore characters seen fewer times than this")
    args = ap.parse_args()

    if not os.path.exists(args.dump):
        sys.exit(f"missing {args.dump}; run tools/fetch_corpus.sh first")

    uni: Counter = Counter()
    bi: Counter = Counter()
    han_total = 0
    pages = 0

    with bz2.open(args.dump, "rb") as fh:
        for event, elem in ET.iterparse(fh, events=("end",)):
            if not elem.tag.endswith("text"):
                continue
            raw = elem.text or ""
            plain = strip_markup(raw)
            for run in sentences(plain):
                han_total += len(run)
                for ch in run:
                    uni[ch] += 1
                for a, b in zip(run, run[1:]):
                    bi[(a, b)] += 1
            elem.clear()
            pages += 1
            if pages % 20000 == 0:
                print(f"  {pages} pages, {han_total:,} han chars, "
                      f"{len(bi):,} bigrams", file=sys.stderr)
                sys.stderr.flush()

    print(f"pages={pages:,} han={han_total:,} unigrams={len(uni):,} "
          f"bigrams={len(bi):,}", file=sys.stderr)

    # Keep characters with enough support, then prune bigrams that occur once.
    alphabet = [c for c, n in uni.most_common() if n >= args.min_char]
    index = {c: i for i, c in enumerate(alphabet)}
    print(f"alphabet={len(alphabet):,}", file=sys.stderr)

    # Conditional probability P(b | a) = count(a,b) / count(a).
    entries = []
    kept = 0
    for (a, b), n in bi.items():
        if n < args.min_count:
            continue
        ia = index.get(a)
        ib = index.get(b)
        if ia is None or ib is None:
            continue
        p = n / uni[a]
        score = int(round(1000.0 * math.log10(p)))
        score = max(-32000, min(0, score))
        entries.append(((ia << 16) | ib, score))
        kept += 1
    entries.sort()
    print(f"kept={kept:,} bigrams", file=sys.stderr)

    with open(args.out, "wb") as out:
        out.write(b"CALM")
        out.write(struct.pack("<HII", 1, len(alphabet), len(entries)))
        for c in alphabet:
            out.write(struct.pack("<H", ord(c) if ord(c) <= 0xFFFF else 0xFFFF))
        for key, score in entries:
            out.write(struct.pack("<Ih", key, score))

    size = os.path.getsize(args.out)
    print(f"wrote {args.out} {size/1e6:.1f} MB")


if __name__ == "__main__":
    main()
