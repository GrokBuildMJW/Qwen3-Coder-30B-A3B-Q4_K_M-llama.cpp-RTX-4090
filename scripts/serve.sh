#!/usr/bin/env bash
# Ironclad coder pin on one RTX 4090 24 GB:
# Qwen3-Coder-30B-A3B Instruct Q4_K_M, 32k context, 2 slots, thinking off.
set -euo pipefail

BIN="${BIN:-$(command -v llama-server || true)}"
BIN="${BIN:-/mnt/llama-models/llama.cpp/build/bin/llama-server}"
MODEL="${MODEL:-${MODEL_DIR:-/mnt/llama-models/models}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8090}"
ALIAS="${ALIAS:-Qwen3-Coder-30B}"
CTX="${CTX:-32768}"
PARALLEL="${PARALLEL:-2}"
NGL="${NGL:-99}"

[[ -x "$BIN" ]] || { echo "llama-server not found: $BIN" >&2; exit 1; }
[[ -f "$MODEL" ]] || { echo "GGUF missing: $MODEL" >&2; exit 1; }

exec "$BIN" \
  --model "$MODEL" \
  --n-gpu-layers "$NGL" \
  --ctx-size "$CTX" \
  --parallel "$PARALLEL" \
  --flash-attn on \
  --jinja \
  --reasoning off \
  --no-reasoning-preserve \
  --no-mmproj \
  --alias "$ALIAS" \
  --host "$HOST" \
  --port "$PORT"
