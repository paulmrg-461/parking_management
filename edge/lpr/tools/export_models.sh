#!/bin/sh
# Build the TensorRT engines on the target (they are tied to the GPU and
# JetPack) and print their SHA-256 for lpr.yaml.
#
#   tools/export_models.sh /path/plate.onnx /path/ocr.onnx
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <detector.onnx> <ocr.onnx>" >&2
  exit 2
fi

if ! command -v trtexec >/dev/null 2>&1; then
  echo "trtexec not found: run this on the Jetson with JetPack installed" >&2
  exit 1
fi

OUT=${LPR_MODELS_DIR:-/opt/lpr-edge/models}
mkdir -p "$OUT"

build() {
  onnx=$1
  engine=$2
  trtexec --onnx="$onnx" --saveEngine="$engine" --fp16 \
    --memPoolSize=workspace:1024 --skipInference
  sha256sum "$engine"
}

build "$1" "$OUT/plate_fp16.engine"
build "$2" "$OUT/ocr_fp16.engine"

echo "paste the two hashes into models.detector.sha256 and models.ocr.sha256"
