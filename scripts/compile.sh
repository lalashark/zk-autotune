#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

usage() { echo "用法: $0 <circom檔路徑> <電路名>"; }

[[ $# -eq 2 ]] || { usage; exit 1; }
CIRCUIT_PATH="$1"
NAME="$2"

check_tools
[[ -f "$CIRCUIT_PATH" ]] || die "找不到電路檔: $CIRCUIT_PATH"

log "編譯電路：$CIRCUIT_PATH → $BUILD_DIR ($NAME)"
circom "$CIRCUIT_PATH" --r1cs --wasm --sym -o "$BUILD_DIR"

[[ -f "$BUILD_DIR/${NAME}.r1cs" ]] || die "缺少 ${NAME}.r1cs"
[[ -f "$BUILD_DIR/${NAME}.sym"  ]] || die "缺少 ${NAME}.sym"
[[ -f "$BUILD_DIR/${NAME}_js/${NAME}.wasm" ]] || die "缺少 ${NAME}.wasm"

log "完成：r1cs/sym/wasm 皆就緒"
