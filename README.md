# 粵拼 Cantainput

Mac 粵語拼音（粵拼／Jyutping）輸入法。自己寫嘅 Swift ranking engine（唔靠 librime），
本機學習你常用嘅字詞，目標係「打得快過而家」。

## 狀態（v1.2）

- [x] 詞庫：138,732 條（字／詞／phrase／英文／地名），由 rime-cantonese + rime-essay 編譯
- [x] 引擎：**Viterbi 整句解碼**（音節格 + beam search）、wordBonus、粵字 prior、個人學習加權
- [x] 候選窗：18 個、兩行、每個候選下面標粵拼讀音、即時整句預覽
- [x] IMK host：inline marked text、自製候選窗（唔用 IMKCandidates）
- [x] 學習紀錄：`~/Library/Application Support/Cantainput/learning.json`
- [ ] 首次註冊：macOS 要 **logout / login 一次** 之後，新 IME 才會出現在 Input Sources
- [x] 打錯字容錯（三級補救，見 `docs/spec.md` §7）
- [x] 語言模型：粵文維基 36.1M 字訓出嘅字 bigram（5.2MB），令「我想食飯」贏「我上食飯」
- [ ] 未做：trigram（救「你好嗎」）、「估嘅 6 個」候選
- [ ] 未試：真正喺 app 入面打字（等上面嗰步）

![候選窗](docs/candidates.png)

## 安裝

```bash
tools/fetch_data.sh          # 下載上游詞庫（唔會 commit）
python3 tools/build_lexicon.py
tools/build.sh                # 語言模型 .bin 已 commit，唔使重建
tools/install.sh             # 裝去 ~/Library/Input Methods
```

然後 **logout 再 login**（或用 `tools/verify.sh` 睇下認唔認到），
去 系統設定 → 鍵盤 → 輸入方式 → `+` → 中文（繁體）→「粵拼 Cantainput」。

更新版本（已經註冊過之後）唔需要再 logout：

```bash
tools/build.sh && tools/install.sh && open "$HOME/Library/Input Methods/Cantainput.app"
```

## 用法

- 打粵拼字母：`nei` → 你、`ngodei` → 我哋、`gamjattinheihouhou` → 今日天氣好好
- 成句一齊打都得：打落去會即時預覽最似嘅整句，`space` / `enter` 一次過上屏
- 聲調可加可唔加：`ngo4` 只出四聲
- 候選 18 個、分兩行；大字上面，**下面係嗰個候選嘅粵拼讀音**
- `1`–`9` 揀第一行，`Shift`+`1`–`9` 揀第二行，`←`/`→`/`↑`/`↓` 揀，`esc` 取消
- 打錯字都估到：`neig`（多打一個字母）→ 你；太亂嘅輸入（`zzzzzz`）寧願乜都唔出
- 打過嘅字詞會慢慢排前（per-user，唔會離開你部機）

## 自我測試

```bash
./build/Cantainput.app/Contents/MacOS/Cantainput --selftest
```

## 資料來源同授權

- 詞庫：[rime-cantonese](https://github.com/rime/rime-cantonese)（CC BY 4.0）
- 語言模型語料：[粵文維基百科](https://zh-yue.wikipedia.org)（CC BY-SA 4.0 + GFDL）—
  只發布 bigram 統計（`Resources/zh_char_bigram.bin`），唔發布原文
- 頻率：[rime-essay](https://github.com/rime/rime-essay)（LGPL-3.0）— **只用嚟 build，唔入 repo、唔隨 app 派**
- 地名 `maps` 表：OpenStreetMap，ODbL-1.0

`Data/` 同 `Resources/jyutping.tsv` 唔會 commit（可以重建）；`Resources/zh_char_bigram.bin`
（5.2MB）有 commit，所以 clone 返嚟唔使下載 129MB 語料都用得。要重建：

```bash
tools/fetch_corpus.sh && python3 tools/build_lm.py     # 約 1.5 分鐘
```

決策紀錄（每條決定同理由）見 [docs/decisions.md](docs/decisions.md)，粵語語料調查見
[docs/cantonese-corpora.md](docs/cantonese-corpora.md)。

## 結構

```
Sources/CantainputCore/   Lexicon（詞庫）、Decoder（Viterbi）、LanguageModel（bigram）、Engine（排序）、Learning（學習）
Sources/Cantainput/       IMK host、候選窗、Info.plist
tools/                    fetch_data.sh / build_lexicon.py / fetch_corpus.sh / build_lm.py / build.sh / install.sh / verify.sh
docs/spec.md              設計、排序公式、已知限制、路線圖
```
