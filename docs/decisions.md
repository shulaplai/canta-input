# 決策紀錄

每條決策記低：**決定**、**理由**、**代價**。理由比決定重要 —— 日後想推翻某條決策，
要先睇清楚當初為咩咁揀。日期係決策日，唔係實作日。

狀態：`已定` / `暫定`（可以用，但預期會變）/ `已推翻`（保留記錄，解釋為咩變）。

---

## D001 — 三條產品線，順序係 Mac → 手機

**已定**

v1 = Mac 粵拼輸入法；v2 = 語音聽寫（Typeless 式，斷句要靚）；v3 = 手機版（粵拼＋英文＋手寫）。

**理由**：使用者而家最想解決嘅係 Mac 上打廣東話。手機版可以參考現成開源（LIME BSD、Hamster）。

**代價**：三條線共用一套 core，所以 core 唔可以依賴 macOS API。

---

## D002 — 自己用為主，但會 open source

**已定**

架構按「要公開」嘅標準寫：唔寫死個人路徑、詞庫來源要記錄、授權要標清楚。

**理由**：使用者自己用，但想睇下有冇人加入。公開嘅代價細，唔公開但寫到一團糟嘅代價大。

---

## D003 — 非商用，版權唔設限

**已定**（使用者明確放寬）

所有詞庫、語料來源都可以用，只要標 attribution。原本打算只收 CC BY 商用友好嘅來源，已放寬。

**代價**：如果日後想改成寬鬆授權嘅 repo，要換一批來源重新 build。
`tools/build_lexicon.py` 已經將「來源」同「計分」分開，換來源唔使改引擎。

---

## D004 — 字形預設香港標準，另有一鍵簡體

**已定**，簡體轉換未做

**理由**：香港人睇慣 HK 字形（`粵` 嘅寫法、`裏` vs `裡`）。

**代價**：簡體轉換要 OpenCC 對照表或者自己建表，屬 v1.3。

---

## D005 — 輸入碼：全拼 + 可選聲調 + 詞語首字母簡拼

**已定**，簡拼未做

`nei` / `nei5` / `neihou` 都打得。聲調可加可唔加 —— 加咗就當過濾條件。

**理由**：學習者一開始唔記得聲調，強制打聲調會寸步難行；但想練聲調時又要打得。

**代價**：有聲調嘅時候跳過 Viterbi（見 D009），只做前綴過濾。

---

## D006 — 個人學習一定要有，同步暫時唔做

**已定**

`~/Library/Application Support/Cantainput/learning.json`，per-user，唔離開部機。
加權 = `min(count · e^(−days/60), 12) × 60`（60 日半衰期）。

**理由**：使用者明確要求「學習記憶一定要有」。同步係分散式問題，唔應該喺 v1 拉低速度。

---

## D007 — IMK host，唔係「攔鍵盤再自己畫」

**已定**

用 InputMethodKit 寫 `IMKInputController`，唔用 CGEventTap 假裝輸入法。

**理由**：IMK 係 macOS 上唯一有 zero TCC 權限 + 真 inline marked text 嘅路。CGEventTap 要
輔助使用權限、要自己處理所有 app 嘅編輯行為、marked text 亦係假嘅。

**代價**：`IMKInputController` 唔可以 breakpoint debug（會 freeze 個 client），
只可以靠 log 同 `--probe` / `--selftest` 離線測。

---

## D008 — 自己寫 Swift 引擎，唔用 librime

**已定**（一度考慮過 librime，已推翻）

**理由**：
1. v1 嘅價值係**教學**（打錯有提示、每個候選標粵拼、由速成過渡去粵拼）。
   librime 嘅 `speller/algebra` 只做固定規則，做唔到 edit distance 亦冇教學回饋。
2. 原本想重用 Squirrel 嘅 userdb，但實測 `jyut6ping3.userdb` 得 24K（空 LevelDB 約 20K），
   即係從來冇用過 —— 重用理由報廢。
3. 規模細：一個粵拼詞庫 + 上下文模型，幾百行 beam search 夠用。
4. 純 Swift = 零 C++ 依賴、零 deploy、crash 唔會拖死個 IME。將來寫 Android 可以抽 Rust。

**代價**：第一版嘅整句質素一定差過 librime，要自己迭代語言模型（見 D010）。

---

## D009 — 唔 fork Squirrel、唔 fork vChewing

**已定**

- Squirrel：GPL-3.0，價值 99% 喺 librime 唔喺嗰幾千行 Swift。
- vChewing：MIT，但係注音（Bopomofo），romanization 層要全部拆走，等於重寫。

**代價**：所有 UI 由零開始（候選窗、游標定位、翻頁）。

---

## D010 — 排序走「詞格 Viterbi → 之後加語言模型」，次序係 trigram 先、neural 後

**已定**（2026-10-20 更新）

現況：詞格 Viterbi + unigram 詞頻 + `wordBonus`（每個額外音節 +3000，對抗 unigram 偏好逐字切）
+ 粵字 prior（粵字 +600、書面語虛字 −200/個）。

已知不足（實測）：

| 打 | 出 | 應該 |
|---|---|---|
| `neihoumaa` | 你號碼 | 你好嗎（排第 3） |
| `ngosoengsikfaan` | 我上食飯 | 我想食飯（排第 2） |

呢啲係上下文機率問題，調參數解決唔到。所以：

1. **先建粵語語料**（無論行邊條路都要）
2. **字級 n-gram rescoring**：已做 **bigram**（5.2MB、856k 條、純 Swift 二分查表），
   trigram 留待 v1.3
3. 如果 trigram 到頂，**最後才**上 4.5MB 字級 Transformer rescorer

**理由**：兩條路同一個前置條件（粵語語料）。trigram 便宜十倍、無新依賴、即刻見效。
neural 要 GPU 訓練 + 幾千行 Swift 移植（要對齊 erf-GELU、LayerNorm eps、int8 量化尺度）。

**代價**：n-gram 到頂之後仍要再做一次 neural 工程。

**實作備註**（踩過嘅坑）：語料未見過嘅字要罰分（−3.0）而唔係 0，否則罕見字（`兲`）
因為「冇紀錄」而排第一。權重掃過 600–8000，600 最好。

---

## D011 — 唔用 msime-windows 嘅 C++，要用就用 `chinese-ime-lm/reference/`

**已定**

- `msime-windows` 整體 GPL-3.0，`engine/neural/` 嗰份 C++ port 用 int8 **AVX2**（x86 SIMD），
  Apple Silicon 要重寫。
- `chinese-ime-lm` 嘅 `reference/`（Rust，無 unsafe，除 serde 外無依賴）同**模型權重**
  都係 Apache-2.0，作者專登咁做，等 MIT/Apache/BSD 嘅輸入法鏈得到。

**理由**：GPL 鏈唔到（呢個 repo 係 MIT）。而且佢個架構係「詞格出 n-best → Transformer 重排」，
同我們現有嘅 `Decoder.nbest` 直接接得上。

**注意**：佢兩個公開模型係用 **C4 中文 + LCCC** 訓嘅，即**普通話**。粵語要自己由零訓。

---

## D012 — 候選窗自己畫（NSPanel），唔用 IMKCandidates

**已定**

**理由**：`IMKCandidates` 喺 macOS 26 Liquid Glass 下會白字白底，睇唔到。

**代價**：要自己計 caret 位置（`attributesForCharacterIndex:lineHeightRectangle:`）、
自己 clamp 到螢幕、自己處理多螢幕同翻上翻落。

---

## D013 — 候選 18 個、兩行，每個候選下面標粵拼

**已定**（使用者明確要求）

大字係候選字詞，下面細字係**嗰個候選嘅正確粵拼讀音**。`1`–`9` 揀第一行，
`Shift`+`1`–`9` 揀第二行。

**理由**：使用者要「打錯都知自己應該打咩」—— 標音就係教學位。

**代價**：面板闊（實測 1040px）；`嗎` 呢類多讀音字會標錯調（資料問題，見 D014）。

---

## D014 — 唔做反向查字（reverse lookup），改用「聲音輸出 + 拼音提示浮窗」

**已定**（使用者 2026-10-20 推翻原案）

原本打算做 reverse lookup（打唔到嘅字用部件/筆畫查）。使用者話唔需要，改成：

1. **打唔到粵拼就用聲音輸出**（v2 語音）
2. 輸出文字之後，撳一粒掣睇返每粒字嘅粵語拼音：
   - Mac：右上／右下角浮窗（位置喺設定可較）
   - 手機：一粒掣顯示啱啱輸出嘅文字同拼音

**理由**：佢真正嘅需求係「唔記得個字點寫／點讀」，唔係「用筆畫搵字」。

---

## D015 — 打錯字要估到（edit distance 容錯）

**已定**，v1.2 已實作

就算打錯一兩個字母都要出候選，而且照樣標**正確**粵拼，等使用者知自己打錯咩。

**做法**（已實作）：三級補救 —— 精確解碼 → 丟尾字母（−1000／個）→ 音節層 edit distance
（每個修補 −4000，最多 2 個，每個位置只留 2 條邊）。分數 ≤ 0 嘅候選丟棄。

**已知缺口**：打錯但仲砌得出合法音節（`ngodeu` 想打 `ngodei`）唔會觸發，因為精確路徑
已經夠 18 個。要解決就要喺正常路徑都混入估嘅候選（使用者要求嘅「6 個估」）。

**理由**：使用者原話「唔一定要跟打咗嘅字母，就算打錯都要估到」。

---

## D016 — 只做粵語中文輸入，唔做英文模式

**已定**（使用者 2026-10-20）

**理由**：使用者喺 Mac 會自己轉輸入法。做英文模式係另一條產品線，唔應該分薄 v1。

**代價**：詞庫入面嘅英文條目（`lettered.dict.yaml`）可以保留但唔優化，之後可以剷。

---

## D017 — 手機語音預設本地，設定可切雲端

**已定**

三平台共用一個 `ASRBackend` protocol + `PostProcessor`（標點／ITN／繁簡／語氣詞保留）。

**理由**：iOS 鍵盤 extension 記憶體上限約 30–60MB（Apple 冇公開，社群實測），
0.6B int4 都要 ~400MB，塞唔入 → iOS 語音一定要放主 app，鍵盤只打字。
Android IME service 100–200MB 撐得住。

**代價**：iOS 版要兩個 target（鍵盤 + 主 app），體驗上要來回跳。

---

## D018 — 註冊陷阱：新 bundle id 要 logout / login 一次

**已定**（實測）

`TISRegisterInputSource` 回 noErr、`lsregister` 認得 bundle、`IMKServer` 起到，
但 `TISCreateInputSourceList` 就係唔列出。用 Squirrel 改 bundle id 再試都一樣 →
係 `imklaunchagent` 喺 login 時掃一次（PlugInKit，extension point
`com.apple.textinputmethod-services`）。註冊過之後換版本只需 `killall`。

---

## D019 — 標點：全形直出，引號前後輪換

**已定**

`,`→`，`、`.`→`。`、`?`→`？`、`!`→`！`、`:`→`：`、`;`→`；`、`(`→`（`、`)`→`）`、
`[`→`「`、`]`→`」`、`"` 前後引號輪換（`“` / `”`）。破折號唔要。

**理由**：使用者原話「好多符號全形直出」。

---

## D020 — 測試方式：`--selftest`，唔用 XCTest

**已定**

**理由**：呢部機只有 Command Line Tools，`/Library/Developer/CommandLineTools/usr/lib/swift/macosx/`
既冇 XCTest 亦冇 Testing module，`swift test` 用唔到。

---

## 未決

- 簡拼規則（聲母 + 韻母首字母？詞首字母？幾時觸發？）
- 標點表細節（`~`、`...`、書名號《》）
- 語音浮窗嘅具體位置同觸發方式
- `嗎` 呢類多讀音字嘅「常用讀音」表要唔要自己建
- 粵語語料最終用邊幾個來源、夠唔夠訓 trigram（進行中）
