# 粵拼 Cantainput — v1 設計

## 目標

Mac 上用粵拼打廣東話，候選字詞要跟住自己嘅習慣排。長遠：v2 語音聽寫（純文字），
v3 手機版（粵拼＋英文＋手寫）。

## 架構

```
keydown → CantoneseInputController (IMKInputController)
        → Engine.candidates()  → Lexicon（二分前綴查詢）+ Learning（個人加權）
        → client.setMarkedText() + CandidatePanel（自製 NSPanel）
        → insertText()
```

- **IMK host**（`InputMethodKit`）：zero TCC 權限、真 inline marked text，係 macOS 上唯一正路。
- **自製引擎**：librime 要 glog / leveldb / yaml-cpp / OpenCC / boost + cmake，呢部機（只有 CLT、
  冇 rustc/cmake）今晚砌唔起；而且 ranking 完全自控正是個人化所在。日後可以喺
  `Engine` protocol 後面換 librime，host 唔使改。
- **候選窗**：唔用 `IMKCandidates`（macOS 26 上 Liquid Glass 會變白字白底）。
  自己畫 `NSPanel`，位置由 `attributes(forCharacterIndex:lineHeightRectangle:)` 攞插入點。

## 詞庫

`tools/fetch_data.sh` 下載 → `tools/build_lexicon.py` 編譯成 `Resources/jyutping.tsv`：

```
toneless_key \t toned_key \t text \t score
ngodei       \t ngo5dei6  \t 我哋  \t 660
```

- 來源：rime-cantonese 嘅 `chars` / `words` / `phrase` / `lettered` / `maps` 五張表，跨表去重。
- `score = 100 * log1p(freq)`，freq 來自 rime-essay；essay 冇收錄嘅詞用固定值
  （二字 100、三字 30、其餘 10），令佢哋排喺常用單字之後，靠學習升上來。
- `maps` 表（地名）分數 +3。

## 排序

```swift
score = entry.score
      + learningBonus(code, text)     // min(count·e^(-days/60), 12) × 60
      + 200 (key 完全等於輸入，即單音節)
      + 200 (toned 完全等於輸入)
```

- 輸入冇數字 → 用 toneless key 做前綴查詢（打 `ngo` 可以出 `ngodei`）。
- 輸入有數字 → 同一批候選再過濾 `toned.hasPrefix(input)`，所以 `ngo4` 只出四聲。
- 同一 text 只留最高分。

## 已知限制

- 冇簡拼（`nd` → 你哋）、冇模糊音、冇詞組動態組合（只出詞庫裡有嘅詞）。
- 候選窗最多 9 個、單行；未做翻頁。
- 未做 `IsSecureEventInputEnabled()` 直通（password field 會照樣被攔）。
- 繁簡轉換未做（詞庫係繁體，附帶少量簡體字）。

## 註冊陷阱（今晚實測）

新 bundle ID 嘅 IME **要 logout/login 一次** TIS 才會見到：

- `TISRegisterInputSource()` 回 `0`（noErr），`lsregister` 認得個 bundle，
  `IMKServer` 都起咗（`com.apple.inputmethodkit.setxpcendpoint` 有連線），
  但 `TISCreateInputSourceList(nil, true)` 就係唔列出我哋。
- 用 Squirrel 改 bundle id 再註冊都一樣唔出現 → 唔係我們 bundle 嘅問題，
  係 `imklaunchagent` 喺 login 時掃一次 Input Methods 資料夾。
- 已經註冊過之後，換版本只需 `killall Cantainput` + 重開，唔使再 logout。

## 授權 TODO（公開之前一定要處理）

| 資料 | 授權 | 處理 |
|---|---|---|
| rime-cantonese 詞庫 | CC BY 4.0 | 可以用，要標 attribution |
| rime-essay 頻率 | **LGPL-3.0** | 只做 build-time 下載，唔 commit、唔隨 app 派 |
| maps 表（地名） | ODbL-1.0 | 要標 attribution，公開前考慮剔走 |

公開派街前要換一個 clean 嘅頻率來源（例如自己由 CC 授權語料統計，或者 words.hk 嘅
public-domain frequency dump），否則 LGPL 會牽連到成個 repo。

## 路線圖

- **v1.1**：簡拼、翻頁、繁簡切換、候選窗 keyboard 導航打磨、`SecureEventInput` 直通
- **v1.2**：詞組動態組合（bigram/trigram）、按 app 記憶（唔同 app 用唔同候選）
- **v2**：Typeless 式粵語聽寫（本地 Qwen3-ASR / sherpa-onnx，CT-Transformer 標點），純文字 app
- **v3**：iPhone 鍵盤 extension（粵拼＋英文＋ML Kit 手寫）
