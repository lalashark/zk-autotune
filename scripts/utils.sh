#!/usr/bin/env bash
set -euo pipefail

# --- 顏色 & 日誌 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die() { echo -e "${RED}[ERR ]${NC} $*" >&2; exit 1; }

# --- 路徑 ---
ROOT_DIR="${ROOT_DIR:-/work}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
RESULTS_RAW="${RESULTS_RAW:-$ROOT_DIR/results/raw}"
RESULTS_SUM="${RESULTS_SUM:-$ROOT_DIR/results/summary}"
mkdir -p "$BUILD_DIR" "$RESULTS_RAW" "$RESULTS_SUM"

# --- 計時（高精度，無需 /usr/bin/time）---
now_ns() { date +%s%N; }
elapsed_sec() {
  local start_ns="$1" end_ns="$2"
  # 用 bc 計算秒，保留 3 位小數
  echo "scale=3; ($end_ns - $start_ns)/1000000000" | bc
}

# --- 環境檢查 ---
need() { command -v "$1" >/dev/null 2>&1 || die "找不到指令: $1"; }

check_tools() {
  for c in circom snarkjs node jq parallel bc; do need "$c"; done
  [[ -d "$BUILD_DIR" ]] || die "build 目錄不存在：$BUILD_DIR"
}

# --- 小工具 ---
write_json() { # write_json <path> <json-string>
  local out="$1" json="$2"
  echo "$json" | jq '.' > "$out"
}
