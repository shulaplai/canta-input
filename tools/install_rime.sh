#!/bin/bash
# 把 canta-input 嘅詞庫裝入 Squirrel（鼠鬚管）。
#
# 為甚麼要這樣做：macOS 26 唔接受新登記嘅 ad-hoc 簽名輸入法，我們自己嘅
# Swift IME 註冊唔到（見 docs/spec.md）。Squirrel 已經註冊得到，所以借用
# 佢做宿主，用同一份詞庫、同一組頻率權重，令今日有得打。
#
# 做法：喺 ~/Library/Rime/ 放一份同名嘅 jyut6ping3.schema.yaml，
# 用戶目錄嘅 schema 會覆蓋 Squirrel 內置嗰份，只改 dictionary 同顯示名。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RIME_DIR="$HOME/Library/Rime"
SQUIRREL="/Library/Input Methods/Squirrel.app"

if [ ! -d "$SQUIRREL" ]; then
  echo "Squirrel 未裝：brew install --cask squirrel" >&2
  exit 1
fi

echo "== 1/3 由 Resources/jyutping.tsv 編 cantainput.dict.yaml"
python3 "$ROOT/tools/build_rime_dict.py"

echo "== 2/3 複製 schema 去 $RIME_DIR"
mkdir -p "$RIME_DIR"
cp "$ROOT/rime/cantainput.schema.yaml" "$ROOT/rime/jyut6ping3.schema.yaml" "$RIME_DIR/"
cp "$ROOT/rime/cantainput.dict.yaml" "$RIME_DIR/"

echo "== 3/3 重新 deploy（要開一次 Squirrel，--reload 係唔 work 嘅）"
pkill -f "Squirrel.app/Contents/MacOS/Squirrel" || true
sleep 1
open -a "$SQUIRREL"
sleep 15
ls -la "$RIME_DIR/build/" | grep cantainput || {
  echo "deploy 冇出 cantainput.*.bin，試下打開 Squirrel 選單揀「重新部署」" >&2
  exit 1
}

cat <<'TIP'

搞好了。用法：
  1. 系統設定 → 鍵盤 → 文字輸入 → 輸入方式 → 編輯 → 「+」
  2. 中文（繁體）→ 揀「Squirrel」（如果已經有就唔使加）
  3. 切去 Squirrel，撳 Ctrl+` （或者 F4）揀「粵拼 Cantainput」
TIP
