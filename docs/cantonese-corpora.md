# Cantonese (粵文) text corpora — reconnaissance report

All checks run **2026-10-20** against live servers. Every URL below was actually requested
(HEAD, ranged GET, or full GET where noted). Figures marked *measured* are counts I ran;
figures marked *est.* are extrapolations and are flagged as such.

---

## 1. How "Cantonese-ness" was measured

Bytes and "big Chinese corpus" tell you nothing about whether text is 粵文 or 書面語.
I used a **marker-density** metric: count of the high-frequency Cantonese-only glyphs

```
嘅 咗 哋 喺 唔 啲 嗰 咁 佢 嚟 睇 諗 乜 嘢 冇 嗌 咩 噉 攞 瞓 嘞 囉 喎 啩
```

per 1,000 Han characters. The scale is calibrated against two anchors measured the same way:

| Text | Han chars | Markers | Rate /1000 Han | Reads as |
|---|---:|---:|---:|---|
| **HKCanCor** (spontaneous Cantonese speech) | 165,291 | 26,013 | **157.4** | pure colloquial 粵文 |
| TED Cantonese transcripts | 26,940 | 3,200 | **118.8** | pure colloquial 粵文 |
| Cantonese Wikipedia, `香港` article | 7,210 | 492 | **68.2** | genuine 粵文, encyclopedic register |
| Cantonese Wikipedia, `粵語` article | 5,161 | 323 | **62.6** | genuine 粵文 |
| Cantonese Wikipedia, `中國` article | 1,617 | 85 | **52.6** | genuine 粵文 |
| `cc100-yue` sample | 713 | 42 | **58.9** | 粵文 prose |
| zh_yuewiki full dump (incl. markup) | 54,388,233 | 2,471,896 | **45.4** | 粵文 diluted by templates/refs |
| 法庭線 thewitnesshk.com | 1,727 | 5 | **2.9** | Standard Written Chinese |
| **LegCo Hansard 2024-01-10** | 33,978 | 2 | **0.06** | Standard Written Chinese |
| RTHK 中文新聞 | 703 | 0 | **0.0** | Standard Written Chinese |
| zh.wikipedia `香港` (same article) | 20,419 | 0 | **0.0** | Mandarin / SWC |
| zh.wikipedia `中國` (same article) | 32,170 | 0 | **0.0** | Mandarin / SWC |

Two reference readings matter: **>~100/1000 = unambiguously colloquial 粵文**;
**<3/1000 = Standard Written Chinese**, regardless of what the site's marketing says.

---

## 2. Master table

| # | Source | License | Est. Han chars | Cantonese-ness | Download ready | Notes |
|---|---|---|---:|---|---|---|
| 1 | **Cantonese Wikipedia dump** (zh-yue.wikipedia.org) | CC BY-SA 4.0 + GFDL | **54,388,233** (measured, exact) | **high** | **yes** | 129,410,920 B bz2, dump date 2026-10-01. Single file. |
| 2 | **`raptorkwok/cantonese_sentences`** (HF) | **none stated** | **~405,000,000** (est.) | **high** (colloquial forum) | **yes**, ungated | 30,150,987 sentences, 2.07 GB text. Best bulk colloquial source; dirty. |
| 3 | **`HKAllen/cantonese-chinese-parallel-corpus`** (HF) | **CC BY 4.0** | **~13,000,000** yue side (est.) | mixed (MT from zh-wiki) | **yes**, ungated | 105.8 MB JSON, `yue`/`zh` pairs, "improved through manual correction". |
| 4 | **`indiejoseph/cc100-yue`** (HF) | **none stated** | **~9,500,000** (est.) | high | **yes**, ungated | 176,047 docs, 32.1 MB. Filtered CommonCrawl. |
| 5 | **Cantonese Wikipedia via `jed351/cantonese-wikipedia`** (HF) | none stated | ~15,000,000 (est.) | high | yes, ungated | Pre-parsed CSV, 58.2 MB. Saves writing a dump parser. |
| 6 | **HKCanCor** (github fcbond/hkcancor) | **CC BY** (version unstated) | **165,291** (measured, exact) | **very high** (157/1000) | **yes** | Gold-standard spoken Cantonese, 1997–98, POS + Jyutping tags. Tiny — a seed, not a corpus. |
| 7 | **words.hk 粵典** | **《非商業開放資料授權協議 1.0》** (Non-Commercial Open Data Licence 1.0) | ~4,000,000 (est., 16,717 entries) | **very high** | **no** — request form | Extremely clean 粵文 example sentences with Jyutping. Non-commercial only. |
| 8 | **`indiejoseph/ted-transcriptions-cantonese`** (HF) | none stated; TED content is CC BY-NC-ND | ~500,000 (est.) | **very high** (119/1000) | **yes**, ungated | 249 talks. Cleanest bulk colloquial prose found. |
| 9 | **rime/rime-cantonese** (wordlist) | CC BY 4.0 + ODbL | n/a (not prose) | n/a | yes | Lexicon + a char-unigram frequency table. Use for vocabulary/char coverage, not LM text. |
| 10 | **LegCo Hansard** (legco.gov.hk) | LegCo copyright, no open licence | ~150,000/meeting PDF | **low** — 0.06/1000 = pure SWC | yes, but painful | PDF only, CID-encoded text. Useless for 粵文. |
| 11 | HK news (RTHK / 明報 / 香港01 / 法庭線) | © all rights reserved | large | **low** — 0–3/1000 | no | **Standard Written Chinese.** Confirmed by measurement. |
| 12 | LIHKG | — | large | high | **NO** | robots.txt: `Disallow: /` |
| 13 | 高登 forum.hkgolden.com | — | large | high | **no** | Page is a JS shell ("請先啟用 JavaScript") |
| 14 | OpenSubtitles / OPUS yue | ODbL-ish / unclear | ~1–5M | mixed; HK TV subs are SWC | **no** | API 403 without key; OPUS 502 |
| 15 | HK gov press releases (info.gov.hk, news.gov.hk) | © | very large | **low** (SWC) | no | Written 書面語 |

---

## 3. Top 3 sources to actually build a >10M-character corpus

### #1 — Cantonese Wikipedia dump → 54.4M Han chars, clean licence

Alone this clears the 10M target five times over, and it is genuinely 粵文
(measured 45.4 markers/1000 across the whole dump; individual articles 62–68).

```bash
curl -sS -O https://dumps.wikimedia.org/zh_yuewiki/latest/zh_yuewiki-latest-pages-articles.xml.bz2
# 129,410,920 bytes, Last-Modified: Thu, 01 Oct 2026 22:22:59 GMT

# strip MediaWiki markup (wikiextractor) and keep only <text> per <page>
pip install wikiextractor
python -m wikiextractor.WikiExtractor zh_yuewiki-latest-pages-articles.xml.bz2 -o yue_wiki --json
```

Measured by downloading and streaming-decompressing the real file:

```
<text> payload          277,195,158 chars
Han characters           54,388,233
Cantonese markers         2,471,896   (45.4 / 1000 Han)
```

Caveats: this is **encyclopaedic register**, not speech — it is 粵文 but formal 粵文
(`係…嘅`, `同埋`, `冇` rather than `不`, `和`, `沒`). Roughly 10 % of articles are stubs;
~80 % of Han chars live in articles ≥300 Han. Attribution required (CC BY-SA 4.0 +
GFDL) — your n-gram counts are a derivative work, so carry the notice and share alike.

### #2 — `raptorkwok/cantonese_sentences` → ~405M Han chars, the colloquial register

This is the closest thing to a ready-made colloquial 粵文 dump. 30.1 M forum sentences
from a Hong Kong forum, measured at **68.6 markers/1000 Han** — three times denser than
Wikipedia, i.e. unmistakably spoken-style writing, including 錯別字 and code-mixing.

```bash
pip install -U huggingface_hub
hf download raptorkwok/cantonese_sentences --repo-type dataset --local-dir data/canto_sentences
# 1,530,555,311 bytes download, 2,068,932,282 bytes of text, 30,150,987 rows
```

Derivation of the 405M figure: 50 sampled rows gave 671 Han over 50 sentences =
**13.4 Han/sentence** → 13.4 × 30,150,987 ≈ **404 M Han chars** (call it 380–430 M).

Caveats, and they are real:
- **No licence of any kind is declared.** Not CC, not public domain — nothing. Legally
  this is "all rights reserved by unknown parties". Using it for a personal IME and
  shipping it commercially are very different risk profiles.
- Provenance is vague ("Hong Kong-based local forum"). It styles like LIHKG/高登.
- Expect heavy duplication, spam, one-liners, romanisation, and 錯別字. Dedupe
  (exact + near-dup shingling) and length-filter before counting n-grams.
- Character-level n-grams are fairly robust to this noise, but not to *duplicate*
  sentences — a repeated meme sentence will distort your model badly.

### #3 — `HKAllen/cantonese-chinese-parallel-corpus` (CC BY 4.0) + `cc100-yue`

The only **properly licensed** bulk colloquial-ish data beyond Wikipedia.

```bash
hf download HKAllen/cantonese-chinese-parallel-corpus --repo-type dataset --local-dir data/hkallen
# 105,817,819 B data-wiki.json, fields {"yue": ..., "zh": ...}, license: cc-by-4.0

hf download indiejoseph/cc100-yue --repo-type dataset --local-dir data/cc100_yue
# 32,135,136 B text, 176,047 rows, no license declared
```

`HKAllen` sampled at 26.7 markers/1000 — half the colloquialness of native forum text,
because the `yue` side is machine-translated from Chinese Wikipedia and then partially
hand-corrected. It reads as grammatical but slightly stiff Cantonese. ~13 M Han on the
`yue` side (105.8 MB JSON ÷ 2 languages ÷ 3 bytes, then × ~0.75 Han share — estimate,
not measured).

`cc100-yue` sampled at 58.9 markers/1000 and is native-written Cantonese prose. Its
licence is undeclared; CC100 is CommonCrawl-derived, so the underlying documents are
third-party copyright with no clear grant.

**Practical combination:** wiki (54 M) for formal coverage + `cantonese_sentences`
(after dedupe/filter) for the colloquial register + HKCanCor (165 k) and words.hk as
a clean quality anchor. That comfortably exceeds 10 M with two registers represented.

---

## 4. Second tier / useful complements

**HKCanCor** — tiny but the highest-quality 粵文 you can get, and freely licensed.

```bash
curl -sSLO https://raw.githubusercontent.com/fcbond/hkcancor/master/data/hkcancor-utf8.zip
# 961,514 B, 63 files, 165,291 Han chars, 157.4 markers/1000
```
`<sent>`-tagged with POS and LSHK Jyutping per word (`有/v1/jau5/`). Licence file is
`data/LICENSE` (15,037 B), README says "CC BY" without a version number — confirm before
redistributing. Use it as dev/test data and for choosing which n-gram orders matter,
not as bulk training text.

**words.hk 粵典** — the cleanest curated colloquial 粵文, 16,717 dictionary entries, each
with several example sentences, Jyutping and English glosses, server-rendered and
robots-allowed (`Disallow` only for `/accounts/ /login/ /zidin/wan/ /dictionary/`):

```bash
curl -sS https://words.hk/sitemap.xml   # 2,193,119 B, 17,056 <loc>, 16,717 of them /zidin/
```
Bulk CSV exists but **only by request**: https://words.hk/faiman/request_data/ (returns
200, a form asking name/organisation and purpose). The page states verbatim:
> 粵典嘅詞典資料係以《非商業開放資料授權協議 1.0》發佈。

i.e. **Non-Commercial Open Data Licence 1.0** — usable for a personal/open-source IME,
not for a commercial product. Scraping 16.7 k pages is technically easy but the licence
is request-gated, so the sanctioned route is the form.

**`indiejoseph/ted-transcriptions-cantonese`** — 249 TED talks, 1.57 MB, **119/1000**
markers. The most natural-sounding bulk prose I found. But 249 rows is ~0.5 M Han, and
TED content is CC BY-NC-ND upstream, so it is a quality sample rather than a corpus.

**`rime/rime-cantonese`** — CC BY 4.0 + ODbL. Contains `essay-cantonese.txt`
(3,416,812 B) which is **not** essays: it is a `character<TAB>count` frequency table
(266,870 lines). Genuinely useful as a unigram sanity check for your n-gram counts,
not as training text.

**`jed351/cantonese-wikipedia`** — pre-parsed wiki text as CSV (train 46.7 MB +
test 11.5 MB). Same content as #1 but saves you the Markup parser.

**Existing Cantonese LMs / n-gram counts — none usable.** I found no downloadable
KenLM/ARPA for `yue`. What exists is LLM-scale: `hon9kon9ize/CantoneseLLM` family
(6B/8B, CC BY-NC-SA 4.0) and `facebook/mms-cclms` (CC BY-NC 4.0, covers `yue`). Neither
gives you n-gram counts, and both are non-commercial. So you are building counts from
text, not borrowing them.

---

## 5. Blocked / not usable

- **LIHKG** — robots.txt is explicit: `User-agent: *` … `Disallow: /`. Only `/`, `/category/`,
  `/thread/` are allow-listed before the catch-all disallow, which is contradictory in
  spirit; fetching at scale would violate it. Ruled out regardless of technical feasibility.
- **高登 (forum.hkgolden.com)** — robots.txt is permissive (`Allow: /`, `/channel/`, `/thread/`,
  plus sitemaps), but every page returns a 40 KB JavaScript shell reading
  「香港高登討論區 請先啟用 JavaScript」. `sitemap_topics.xml` 302-redirects. Effectively
  requires their internal API; not a scriptable corpus today.
- **Uwants / discuss.com.hk** — robots allows thread pages but explicitly `Disallow: /` for
  `GPTBot`; both are vBulletin with aggressive anti-scrape. Not worth it, and the forum
  text you would get is already inside source #2.
- **LegCo Hansard** — downloadable, and I verified the URL pattern:
  `https://www.legco.gov.hk/yr2024/chinese/counmtg/hansard/cm{YYYYMMDD}-translate-c.pdf`
  (e.g. `cm20240110-translate-c.pdf` = 9,701,098 B, 264 pages; `cm20240508` = 7,518,919 B).
  But I extracted the text: **0.06 Cantonese markers per 1,000 Han characters** — it is
  edited Standard Written Chinese, not the members' Cantonese. Also LegCo copyright with
  no open licence, PDF-only, CID-encoded text needing MuPDF. **Do not use.**
- **Hong Kong news media** — this is the honest headline: **HK news is Standard Written
  Chinese.** Measured 0.0/1000 for RTHK 中文新聞, 2.9/1000 for 法庭線 (which is WordPress,
  so `https://thewitnesshk.com/feed/` gives you full-text RSS for free — still SWC).
  香港01 allows `/article/` in robots but renders via JS; 明報 和 東方 are paywalled or
  registration-gated. None of it helps a 粵文 LM. inmediahk.net returns a Cloudflare
  「Attention Required!」 challenge to non-browser clients.
- **OpenSubtitles** — `https://api.opensubtitles.com/api/v1/subtitles?languages=yue`
  returns **403** without an `Api-Key`; a free account + key is required. `opensubtitles.org`
  search 307-redirects. OPUS (`opus.nlpl.eu`) returned **502** on every endpoint I tried,
  and the direct object URL
  `object.pouta.csc.fi/OPUS-OpenSubtitles/v2018/moses/yue-zh_cn.txt.zip` is **404**.
  Independently: HK TV drama subtitles are written in 書面語 by convention, so even a
  full OpenSubtitles `yue` extraction would grade low on this metric.
- **HK government** — press releases on info.gov.hk / news.gov.hk are 書面語 and the
  Chinese variants were not directly reachable by language cookie in my tests
  (`?lang=zh` still served the English page; `news.gov.hk` is a JS SPA whose Chinese
  index path I could not confirm). Not worth pursuing.
- **`CanCLID/rime-cantonese-upstream`** — **does not exist (404)**. The real repo is
  `rime/rime-cantonese`. `CanCLID/sentences` (粵語對話語料) exists, 4.2 MB, but declares
  **no licence**, so it is in the same legal grey zone as source #2.

---

## 6. Uncertainty, stated plainly

- **Exact**: the Wikipedia dump byte size (129,410,920), its date (2026-10-01 22:22:59 GMT),
  and the 54,388,233 Han-char count — I downloaded the whole file and counted.
  Also exact: HKCanCor's 165,291 Han chars, and all the per-source marker rates.
- **Estimated, and could be off by ±20 %**: `cantonese_sentences` at ~405 M Han (from a
  50-sentence sample), `HKAllen` at ~13 M yue chars (from byte arithmetic on the JSON),
  `cc100-yue` at ~9.5 M (from a 12-row sample), words.hk at ~4 M.
- **Licence facts I could not fully pin down**: HKCanCor says "CC BY" without a version;
  words.hk's Non-Commercial Open Data Licence 1.0 is a Hong Kong-style custom licence, not
  a Creative Commons one — read it before relying on it. `cantonese_sentences`, `cc100-yue`
  and `jed351/cantonese-wikipedia` have **no declared licence at all**, which is not the
  same as being free.
- **`HKAllen/cantonese-chinese-parallel-corpus`** is flagged CC BY 4.0 by its uploader, but
  its content is partly machine-translated Wikipedia text; CC BY 4.0 is only as good as the
  uploader's right to license the underlying article text.
- **Not verified**: whether `正` zh-yue wiki content is uniformly 粵文. My samples were
  15 well-known articles plus a full-dump aggregate; individual obscure articles may lapse
  into 書面語.
