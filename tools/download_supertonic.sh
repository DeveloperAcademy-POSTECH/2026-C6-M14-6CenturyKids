#!/bin/bash
# Supertonic 3 음성 합성 모델(목소리 M3)을 내려받아 Models/supertonic-3에 넣는다.
# 고정 revision에서 받고 SHA256을 검사하며, 하나라도 다르면 넣지 않는다. 모델은 git에 올리지 않는다(Models/는 .gitignore).
# 모델 라이선스: OpenRAIL-M (ToDoc/Resources/Licenses/Supertonic-Model-OpenRAIL-M.txt)
# 사용: tools/download_supertonic.sh
set -euo pipefail

REPO="supertone-oss-archive/supertonic-3"
REV="aafc6e32416a594460b32413efc49d7fe4ce6d46"
FILES="onnx/duration_predictor.onnx onnx/text_encoder.onnx onnx/vector_estimator.onnx onnx/vocoder.onnx onnx/tts.json onnx/unicode_indexer.json voice_styles/M3.json"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUMS="$ROOT/tools/models/supertonic-3.sha256"
DEST="$ROOT/Models/supertonic-3"

if [ -d "$DEST" ] && (cd "$DEST" && shasum -a 256 -c --quiet "$SUMS") 2>/dev/null; then
    echo "이미 있음: $DEST"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for path in $FILES; do
    echo "내려받는 중: $path"
    curl -fL --retry 3 -o "$TMP/$(basename "$path")" "https://huggingface.co/$REPO/resolve/$REV/$path"
done
(cd "$TMP" && shasum -a 256 -c "$SUMS")

rm -rf "$DEST"
mkdir -p "$DEST"
mv "$TMP"/* "$DEST"/
echo "완료: $DEST"
