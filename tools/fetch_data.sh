#!/bin/bash
# Fetch the upstream data needed to rebuild Resources/jyutping.tsv.
# Nothing here is committed: see .gitignore and docs/spec.md (licensing).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p Data

DICT=https://raw.githubusercontent.com/rime/rime-cantonese/main
for table in chars words phrase lettered maps; do
  echo "fetching jyut6ping3.$table.dict.yaml"
  curl -fsSL "$DICT/jyut6ping3.$table.dict.yaml" -o "Data/jyut6ping3.$table.dict.yaml"
done
curl -fsSL "$DICT/jyut6ping3.dict.yaml" -o "Data/jyut6ping3.dict.yaml"

echo "fetching essay.txt (rime-essay, LGPL-3.0, build-time only)"
curl -fsSL "https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt" -o "Data/essay.txt"
echo "done; now run: python3 tools/build_lexicon.py"
