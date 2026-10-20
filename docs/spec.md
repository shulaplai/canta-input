# 粵拼 Cantainput — 設計與路線

## 1. 目標與已定決策

方便用廣東話輸入。自己用為主，但會 GitHub open source，睇吓有冇人一齊用。

| # | 題目 | 決定 |
|---|---|---|
| 1 | 使用者 | 自己用 + 公開 source；架構要當「會有貢獻者」咁寫 |
| 2 | 字形 | 預設**香港標準字形**（`Hant-HK`），另有一鍵轉簡體 |
| 3 | 輸入碼 | 全拼 + 可選聲調 + 詞語首字母簡拼；模糊音預設關 |
| 4 | 學習／同步 | 學習一定要做；跨機同步暫時唔做（匯出／匯入留位） |
| 5 | 詞料授權 | 非商用，版權唔設限，所有來源都可以用 |
| 6 | 現有工具 | 而家用鼠鬚管（Squirrel），嫌唔夠快、唔夠貼合；**標點符號要重新設計** |
| 7 | 語音 | 先用免費本地模型；日後有 key 就喺設定即時切換雲端 |
| 8 | 平台 | 電腦 Mac 最優先；手機 Android 先於 iOS |
| 9 | 節奏 | 先砌框架 → 批准 → 逐塊揼；唔趕 |
| 10 | Core 語言 | **Swift 先**；Android 開工前才決定抽唔抽 Rust + UniFFI |
| 11 | 下一個功能 | **詞組動態組合（Viterbi）先**，標點／簡拼排後 |
| 12 | 手機語音 | 預設**本地**（Paraformer-trilingual），設定可切雲端 |

長期三件嘢：**v1 Mac 打字**、**v2 語音聽寫（純文字）**、**v3 手機（粵拼＋英文＋手寫）**。

## 2. 三層架構

```
┌─ Host（每平台一個，薄） ─────────────────────────┐
│  macOS  : IMKInputController (Swift)             │
│  Android: InputMethodService (Kotlin)            │
│  iOS    : UIInputViewController + 主 app          │
└──────────────────┬───────────────────────────────┘
                   │ 按鍵 / 音訊
┌─ Core（共用規格，可移植） ───────────────────────┐
│  Lexicon      粵拼 → 候選（TSV，平台無關）        │
│  Ranker       分數公式 + 個人學習                 │
│  Segmenter    簡拼、詞組動態組合（Viterbi）       │
│  Punctuator   標點對應表                          │
│  Converter    繁簡／字形轉換                      │
│  Settings     同一份 schema                       │
└──────────────────┬───────────────────────────────┘
                   │ 文字 / 音訊
┌─ ASR backend（可插拔） ──────────────────────────┐
│  Local : sherpa-onnx（Paraformer-yue / Qwen3-ASR）│
│  Cloud : OpenAI / Azure / Google / ElevenLabs     │
│  Post  : 標點、ITN、粵語語氣詞保留、書面語模式     │
└─────────────────────────────────────────────────┘
```

**Core 用咩語言寫？** v1 用 Swift（呢部機只有 CLT，冇 rustc／cmake；Swift 即刻開得工）。
Core 嘅**規格**（TSV 格式、排序公式、標點表、settings schema）寫成平台無關，
Android 開工時有兩條路：

- (a) 照規格用 Kotlin 重寫（快，但兩份邏輯會漂移）
- (b) 抽成 Rust core + UniFFI，Swift／Kotlin 共用（正路，但要裝 rustup + 多一層 FFI）

建議：**v1 先 Swift，Android 開工前才決定抽唔抽 Rust**。理由係排序公式同詞庫格式本身已經
可移植，屆時重寫只係幾百行；而家引入 Rust 只會拖慢 Mac 出貨。

## 3. v1 Mac 現狀（已 commit）

```
keydown → CantoneseInputController → Engine.candidates()
        → Decoder.nbest（音節格 Viterbi 整句）+ rank（詞級前綴補位）
        → Lexicon（byKey + 二分前綴）+ Learning（個人加權）
        → setMarkedText + CandidatePanel（自製 NSPanel）
        → insertText
```

- IMK host：zero TCC 權限、真 inline marked text，macOS 上唯一正路。
- 唔用 librime（要 glog / leveldb / yaml-cpp / OpenCC / boost + cmake），ranking 自控正好係個人化所在。
- 唔用 `IMKCandidates`（macOS 26 Liquid Glass 會白字白底），自繪 `NSPanel`，
  位置由 `attributes(forCharacterIndex:lineHeightRectangle:)` 攞插入點。

## 4. 標點符號（待批准）

原則：**中文模式直出全形**，Shift 出次選，`/` 開符號面板查。組字中嘅字母鍵唔受影響。

| 按鍵 | 直出 | Shift |
|---|---|---|
| `,` | ， | 、 |
| `.` | 。 | … |
| `?` | ？ | ？ |
| `!` | ！ | ！ |
| `;` | ； | ： |
| `:` | ： | ； |
| `(` `)` | （ ） | ( ) 半形 |
| `[` `]` | 「 」 | 『 』 |
| `<` `>` | 《 》 | 〈 〉 |
| `"` | 「 | 」 |
| `-` | － | — |
| `~` | ～ | · |
| `$` | ＄ | ¥ |
| `%` | ％ | ‰ |

另加：

- **粵語常用字捷徑**：`/` 之後打 `d` → 啲、`g` → 嘅、`z` → 咗…（v1.2 做符號面板時一併）。
- **數字符號**：`1`–`9` 喺組字中係選字，唔組字時照常出數字（唔做全形數字）。
- **英文模式（未做）**：全半形自動切。

## 5. 速度設計（Squirrel 唔夠快嘅解法，按效益排序）

1. **詞組動態組合**（最大效益）：打完成句粵拼，Viterbi 揀最順嘅字詞組合，一次上屏一句，
   唔使逐個詞揀。呢個係 librime 真正贏嘅地方，亦係 v1 最大缺口。
2. **簡拼**：`nd` → 你哋、`mg` → 唔該。規則：只取每個音節首字母，聲調可加喺尾。
3. **單候選自動上屏**：只有一個候選就唔使撳 space。
4. **中英混打**：唔使切模式，連續英文字母（唔似粵拼）直接上英文。
5. **按 app 記憶**：唔同 app 用唔同候選（Terminal 英文多、WhatsApp 口語多）。

## 6. 詞庫

`tools/fetch_data.sh` → `tools/build_lexicon.py` → `Resources/jyutping.tsv`：

```
toneless_key \t toned_key \t text \t score
ngodei       \t ngo5dei6  \t 我哋  \t 660
```

- 來源：rime-cantonese `chars` / `words` / `phrase` / `lettered` / `maps`，跨表去重。
- 現況：138,732 條、89,219 個 toneless key、4.6 MB。
- `score = 100 × log1p(freq)`；freq 來自 rime-essay。essay 冇收錄嘅詞用固定值
  （二字 100、三字 30、其餘 10），排喺常用單字之後，靠學習升上來。

## 7. 排序（v1.1：整句 Viterbi）

輸入冇聲調數字時行 beam search 嘅 Viterbi 解碼：

```swift
// 音節表由 toned key 反推（831 個音節），喺輸入串上搵合法音節邊界，
// 沿邊界累積 key 查 byKey（89k 個 key / 138k 條詞）
wordScore = entry.score              // 100·ln(1+freq)，freq 來自 rime-essay
          + learningBonus(code, text)
          + 3000 × (音節數 − 1)       // wordBonus：對抗 unigram 偏好逐字切
          + prior(text)               // 粵字 +600；書面語虛字 −200/個（最多 −400）
pathScore = Σ wordScore
```

- `learningBonus = min(count · e^(−days/60), 12) × 60`，存
  `~/Library/Application Support/Cantainput/learning.json`。
- 每個輸入位置只留最高分 40 條路徑（beam），最後排序、按 text 去重。
- 去重後再過 `diversify`：**頭一個字唔同、其餘一樣**嘅候選（你號碼／呢號碼／您號碼…）
  每個 tail 最多留 2 個，免得 18 個位都係同一句嘅同音變體。
- 唔夠 18 個就用詞級前綴查詢（`rank`）補位，所以 short input 一定夠位。
- 有聲調數字（`ngo4`）跳過 Viterbi，用前綴 + `toned.hasPrefix` 過濾。
- **打錯字**分三級補救（`Engine.candidates`）：
  1. 完整輸入精確解碼（正常路徑）
  2. 完整輸入解唔夠 18 個 → 試 `dropLast(1...3)` 嘅前綴（每個丟咗嘅字母罰 −1000）。
     打錯通常喺最後一兩個字母，所以 `neig` → 用 `nei` 解出「你」。
  3. 仲係唔夠 → 開容錯格：每個可達位置只留**最少編輯距離**嘅 2 個音節
     （同長度=替換優先過 ±1=增刪），每個修補罰 −4000，最多修補 2 個音節。
  4. 分數 ≤ 0 嘅候選直接丟（`zzzzzz` 唔會出垃圾）。
- 容錯格成本：每位置掃 831 個音節 × 3 個長度，但每位置最多留 2 條邊，
  加全域 60k node 上限。實測 `zzzzzz` 9.4ms（未限邊時 230ms）。
- **未做**：打錯之後仍然砌得出合法音節嘅情況（`ngodeu` 想打 `ngodei`）唔會觸發容錯，
  因為精確路徑已經夠 18 個。要真正解決要喺正常路徑都混入估嘅候選（使用者要嘅 6 個）。
- 候選下面顯示嘅粵拼來自詞條本身（`Lexicon.splitToned`，保留聲調），
  所以會見到 `nei5 hou2 maa1`。單字第一個讀音 build 時 +5 分（`好` → `hou2` 唔係
  `hou3`），但 rime 個 `%` 欄唔可靠，間中仍會揀錯調（例：`嗎` 出 `maa1` 唔係 `maa3`）。
### 語言模型（字 bigram，v1.2）

詞頻係 unigram，分唔清「我上食飯」同「我想食飯」。所以加一層字 bigram rescoring：

```
Resources/zh_char_bigram.bin   5.2MB
  CALM v1 | 13,000 字 | 856,180 條 bigram | log10 P(b|a) 量化成 Int16 千分位

score += 600 × Σ log10 P(c_i | c_{i-1})
```

- 語料：粵文維基百科 dump（`tools/fetch_corpus.sh` 下載 129MB bz2），
  `tools/build_lm.py` 剝 wiki markup、只留漢字、以非漢字斷句，數 36.1M 字。
- **每個候選都覆蓋同一批音節**，所以字數一樣，sum 同 average 排名等價 —— 用 sum。
- **只計相鄰字對**，冇逐字項。語料未見過嘅字**唔會獨立罰分**，而係佢前後兩對都當
  unseen 罰 −3.0。呢個好緊要：如果只罰一次，`傒`（唔在字表）只罰 −3.0，
  而正字 `喺`（在字表）要罰兩對 −3.0−1.5，結果**罕見字比常用字便宜**，
  `我傒屋企` 會贏 `我喺屋企`。改做成對計之後 `ngohaiukkei → 我喺屋企` ✅。
- 試過加**字 unigram**（`P(c)` 加權 0.6），**結果更差**：`nei` 出 `呢` 唔出 `你`
  （粵文維基入面 `呢` 比 `你` 更常見）。已經 rollback，模型維持只有 bigram。
- 權重 `Engine.lmWeight = 600` 可以喺 command line 調（`--lm-weight`）。
  實測掃 600→8000：**600 最好（12/13）**，越高越差（`尼號碼`、`今日兲起` 返嚟）。

實測 13 條句子（`nei/你`、`ngodei/我哋`、`zousan/早晨`、`gamjattinhei/今日天氣`…）：

| | 加 LM 前 | 加 LM 後 |
|---|---|---|
| `ngosoengsikfaan` | 我上食飯 | **我想食飯** ✅ |
| `gamjattinhei` | 今日兲起 | **今日天氣** ✅ |
| `neihoumaa` | 你號碼（你好嗎第 3） | 你號碼（你好嗎仍然落後）❌ |
| `ngohaiukkei` | 我傒屋企 | **我喺屋企** ✅ |

`你好嗎` 輸蝕係因為 `號碼` 嘅 unigram 分數高過 `你好`+`嗎` 1418 分，而 LM 只補得返 168 分
（`你好` −1.77 vs `你號` unseen −3.0；`好嗎` −3.26 vs `號碼` −2.31）。
要贏就要 LM 權重 >5000，但咁會令其他句子變差 → 呢個要靠 trigram 或者詞級 LM，唔係調參數。

- **取捨**：`wordBonus` 大 → 長詞贏（`多謝`／`早晨`／`今日天氣` 正確），
  但成本相近時 unigram 仍然會揀錯（`ngosoengsikfaan` → `我上食飯` 先過 `我想食飯`，
  正解排第 2）。真正解決要 bigram / 粵語詞頻，唔係調參數。

## 8. 手機與語音

### 8.1 關鍵限制：模型唔可以放喺鍵盤入面

- **iOS 鍵盤 extension 記憶體上限約 30–60 MB**（Apple 冇公開，社群實測）。
  一個 0.6B int4 模型都要 ~400 MB，塞唔入。所以 iOS 嘅語音一定要喺**主 app**，
  鍵盤只負責打字。Apple 亦冇 API 叫系統手寫鍵盤，第三方鍵盤只可以 `advanceToNextInputMode()`。
- **Android IME service 鬆好多**（100–200 MB 撐得住），但一樣有機型／散熱／耗電差異。
- 兩個平台都要預 VAD 同「短句」策略，唔好期待手機跑長段即時轉錄。

### 8.2 語音三條路

| 方案 | 準確度 | 成本 | 離線 | 判斷 |
|---|---|---|---|---|
| 全本地小模型 | 中（粵語 WER 約 5–8%） | 免費 | ✅ | 日常短句、私隱 |
| 全雲端（自己 key） | 高（4–5%） | $0.2–1 / 小時 | ❌ | 長段落、重要文字 |
| **混合：預設本地，設定可切雲端** | 睇情況 | 免費為主 | ✅ / ❌ | **建議** |

候選本地模型：

- **Paraformer-trilingual (zh / yue / en)**，~200–250 MB，sherpa-onnx 有現成 ONNX，
  一個模型處理粵英夾雜 → 手機首選。
- **Qwen3-ASR-0.6B / 1.7B**：準確度最好（vendor 自報粵語 WER 4.80% / 4.12%），
  但運算重，Mac 先好用；手機只考慮旗艦 + int4。
- Whisper 系唔用：large-v3 粵語 WER 31%，差太遠。
- 標點：sherpa-onnx CT-Transformer（幾十 ms 離線）或雲端自帶標點。

### 8.3 同一套 backend protocol

```
Audio → VAD → ASRBackend ─┬─ LocalBackend(sherpa-onnx, model path)
                           └─ CloudBackend(provider, api key)
       → PostProcessor（標點 / ITN / 繁簡 / 語氣詞保留 / 書面語模式）
```

設定 schema 三平台共用（各自實作 storage）。「之後有條 key 就即刻切換」就係呢個介面。

### 8.4 落地次序

| 階段 | 內容 | 要唔要模型 |
|---|---|---|
| A | Android 鍵盤：粵拼 + 英文 + 手寫（ML Kit Digital Ink，`zh-Hani`，離線免費） | 唔要 |
| B | Android 語音：主 app 內（或 IME 內視機型），Paraformer 離線，設定可切雲端 | 要 |
| C | iOS 鍵盤 extension（只打字） | 唔要 |
| D | iOS 語音：主 app / Shortcuts / 分享 | 要 |

## 9. 已知限制（v1）

- 冇簡拼、冇模糊音、冇 bigram（只有 unigram + 人手 prior），所以長句仍會揀錯詞。
- 容錯只在精確解碼唔夠位時觸發；打錯但仍成合法音節（`ngodeu`）唔會估。
- 字 bigram 補唔到 `你好嗎`（詳見 §7），要 trigram 或詞級 LM 才搞得掂。
- 候選 18 個、2 行（1–9，Shift+1–9）；未做翻頁。
- 打唔到嘅字未接聲音輸出（v2 嘅介面已預留）。
- 未做 `IsSecureEventInputEnabled()` 直通（password field 會照樣被攔）。
- 繁簡轉換未做（詞庫係繁體，附帶少量簡體字）。

## 10. 註冊陷阱（實測）

新 bundle ID 嘅 IME **要 logout / login 一次** TIS 才會見到：

- `TISRegisterInputSource()` 回 noErr、`lsregister` 認得 bundle、`IMKServer` 起到
  （`com.apple.inputmethodkit.setxpcendpoint` 有連線），但 `TISCreateInputSourceList`
  就係唔列出。用 Squirrel 改 bundle id 再試都一樣 → 係 `imklaunchagent` 喺 login 時掃一次。
- 註冊過之後，換版本只需 `killall Cantainput`，唔使再 logout。

## 11. 授權

使用者已定：非商用，版權唔設限。所以詞庫連分數一齊 commit，公開時標 attribution 就算。

| 資料 | 授權 | 處理 |
|---|---|---|
| rime-cantonese 詞庫 | CC BY 4.0 | 用，標 attribution |
| rime-essay 頻率 | LGPL-3.0 | 用嚟計分，標出處（分數已係聚合數字） |
| maps 表（地名） | ODbL-1.0 | 用，標 attribution |
| 粵文維基百科（語言模型語料） | CC BY-SA 4.0 + GFDL | 用，標 attribution；只發布 bigram 統計，唔發布原文 |

若日後想轉做寬鬆授權嘅 repo，只需換一個頻率來源重新 build（`build_lexicon.py` 已將來源隔離）。

## 12. 路線圖

- **v1.0**（已做完）：註冊、打得順
- **v1.1**（已做完）：**Viterbi 整句解碼、18 個候選 2 行、粵拼標音、粵字 prior**
- **v1.2**（已做完）：edit-distance 容錯 ✅、粵語語料 ✅、字 bigram rescoring ✅
- **v1.3**：字 trigram（救 `你好嗎`）、「估嘅 6 個」候選、簡拼、繁簡一鍵切換、
  `SecureEventInput` 直通、翻頁、符號面板
- **v1.4**：按 app 記憶、拼音提示浮窗（睇返已經上屏嘅字點讀）
- **v2.0**：Mac 語音聽寫（本地 sherpa-onnx + 可切雲端）
- **v2.5**：Android 鍵盤（粵拼＋英文＋手寫）
- **v3.0**：Android 語音、iOS 鍵盤＋主 app 語音
