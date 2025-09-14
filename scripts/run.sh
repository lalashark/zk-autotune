#!/usr/bin/env bash
set -euo pipefail

# ========================
# zk-autotune one-click runner
# ========================
# Usage:
#   /work/scripts/run.sh [options] <circuit> [args...]
#
# Examples:
#   /work/scripts/run.sh add 3 4 7
#   /work/scripts/run.sh --reps 5 --max-j 16 heavy_chain 3
#
# Options:
#   --force-setup   無條件重做 Groth16 setup（忽略現有 zkey）
#   --no-compile    跳過編譯（假設 build 內容已存在且一致）
#   --reps N        每個 J 重覆次數（預設 3）
#   --max-j N       最高併行度上限（預設 16）
#   -h, --help      顯示說明

REPS="${REPS:-3}"
MAX_J="${MAX_J:-16}"
FORCE_SETUP=0
DO_COMPILE=1

usage() {
  cat <<'USAGE'
Usage:
  /work/scripts/run.sh [options] <circuit> [args...]

Options:
  --force-setup   force Groth16 setup
  --no-compile    skip compile
  --reps N        repeats per J (default 3)
  --max-j N       max parallel J (default 16)
USAGE
  exit 0
}

msg() { printf "%s\n" "$*" >&2; }
die() { printf "[ERR ] %s\n" "$*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

# ---- parse options ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-setup) FORCE_SETUP=1; shift ;;
    --no-compile)  DO_COMPILE=0; shift ;;
    --reps)        REPS="$2"; shift 2 ;;
    --max-j)       MAX_J="$2"; shift 2 ;;
    -h|--help)     usage ;;
    --)            shift; break ;;
    -* )           die "未知參數：$1（用 --help 看說明）" ;;
    * )            break ;;
  esac
done

[[ $# -ge 1 ]] || die "請提供 <circuit>；例：run.sh add 3 4 7"
CIRCUIT="$1"; shift
ARGS=("$@")

CIR_PATH="/work/circuits/${CIRCUIT}.circom"
BUILD="/work/build"
ZKEY_FINAL="${BUILD}/${CIRCUIT}_final.zkey"
VK_JSON="${BUILD}/verification_key.json"
JS_DIR="${BUILD}/${CIRCUIT}_js"

[[ -f "$CIR_PATH" ]] || die "找不到電路檔：$CIR_PATH"

INPUTS_DEF="/work/circuits/${CIRCUIT}.inputs"
if [[ -f "$INPUTS_DEF" ]]; then
  NEED_N=$(grep -v '^\s*$' "$INPUTS_DEF" | wc -l | tr -d ' ')
  GOT_N="${#ARGS[@]}"
  if [[ "$GOT_N" -ne "$NEED_N" ]]; then
    msg "[ERR ] ${CIRCUIT}.inputs 需要 $NEED_N 個參數，但你給了 $GOT_N 個。"
    msg "      參考（每行一個輸入名）："
    nl -ba "$INPUTS_DEF" | sed 's/^/[HINT] /'
    exit 1
  fi
fi

for bin in /work/scripts/compile.sh /work/scripts/setup_keys.sh /work/scripts/run_one.sh /work/scripts/tune.sh; do
  [[ -x "$bin" ]] || die "缺可執行檔：$bin"
done
for need in bc parallel time; do
  have "$need" || die "缺系統指令：$need（請確認 Dockerfile 已安裝）"
done

if [[ "$DO_COMPILE" -eq 1 ]]; then
  msg "[STEP] 編譯電路：$CIR_PATH → $BUILD"
  /work/scripts/compile.sh "$CIR_PATH" "$CIRCUIT"
else
  msg "[STEP] 跳過編譯（--no-compile）"
fi
[[ -f "${JS_DIR}/${CIRCUIT}.wasm" ]] || die "缺 ${JS_DIR}/${CIRCUIT}.wasm，編譯可能失敗"

NEED_SETUP=0
[[ -f "$ZKEY_FINAL" && -f "$VK_JSON" ]] || NEED_SETUP=1
if [[ "$FORCE_SETUP" -eq 1 ]]; then
  msg "[STEP] 強制重做 Groth16 setup（--force-setup）"
  NEED_SETUP=1
fi
if [[ "$NEED_SETUP" -eq 1 ]]; then
  /work/scripts/setup_keys.sh "$CIRCUIT"
else
  msg "[STEP] 跳過 setup_keys（檢測到 zkey/vk 已存在）"
fi

msg "[STEP] 煙霧測試：/work/scripts/run_one.sh $CIRCUIT ${ARGS[*]}"
/work/scripts/run_one.sh "$CIRCUIT" "${ARGS[@]}" >/dev/null || {
  die "Smoke test 失敗，請確認 compile/setup_keys 與輸入參數"
}
msg "[OK  ] 煙霧測試通過"

msg "[STEP] 調優（J only）：REPS=${REPS}  MAX_J=${MAX_J}"
REPS="$REPS" MAX_J="$MAX_J" /work/scripts/tune.sh "$CIRCUIT" "${ARGS[@]}"

msg "[DONE] 完成"
