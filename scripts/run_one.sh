#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "[ERR ] 用法：run_one.sh <circuit> [values...]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
CIRCUIT="$1"; shift
VALUES=("$@")

BUILD="/work/build"
R1CS="${BUILD}/${CIRCUIT}.r1cs"
JS_DIR="${BUILD}/${CIRCUIT}_js"
WASM="${JS_DIR}/${CIRCUIT}.wasm"
ZKEY="${BUILD}/${CIRCUIT}_final.zkey"
VK="${BUILD}/${CIRCUIT}_vk.json"

# 檢查產物
[[ -f "$R1CS" ]] || { echo "[ERR ] 缺 ${R1CS}（請先 compile.sh）" >&2; exit 1; }
[[ -f "$WASM" ]] || { echo "[ERR ] 缺 ${WASM}（請先 compile.sh）" >&2; exit 1; }
[[ -f "$ZKEY" ]] || { echo "[ERR ] 缺 ${ZKEY}（請先 setup_keys.sh）" >&2; exit 1; }
[[ -f "$VK"   ]] || { echo "[ERR ] 缺 ${VK}（請先 setup_keys.sh）"   >&2; exit 1; }

# 讀取輸入鍵名
INPUTS_DEF="/work/circuits/${CIRCUIT}.inputs"
if [[ -f "$INPUTS_DEF" ]]; then
  mapfile -t KEYS < <(grep -v '^\s*$' "$INPUTS_DEF" | sed 's/#.*$//' | sed '/^\s*$/d')
else
  KEYS=(a b c)
fi

NEED=${#KEYS[@]}
# 修正：只取前 NEED 個參數，多的忽略
VALUES=( "${VALUES[@]:0:$NEED}" )
GOT=${#VALUES[@]}

if [[ $GOT -ne $NEED ]]; then
  echo "[ERR ] ${CIRCUIT}.inputs 需要 ${NEED} 個參數，你給了 ${GOT} 個。" >&2
  echo "      參考：" >&2
  printf "[HINT] %s\n" "${KEYS[@]}" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 產生 input.json
{
  echo -n "{ "
  for i in "${!KEYS[@]}"; do
    k="${KEYS[$i]}"
    v="${VALUES[$i]}"
    printf '"%s": %s' "$k" "$v"
    [[ $i -lt $((NEED-1)) ]] && echo -n ", "
  done
  echo " }"
} > "${TMP}/input.json"

snarkjs wtns calculate "$WASM" "${TMP}/input.json" "${TMP}/witness.wtns" >/dev/null 2>&1
snarkjs groth16 prove "$ZKEY" "${TMP}/witness.wtns" "${TMP}/proof.json" "${TMP}/public.json" >/dev/null 2>&1
snarkjs groth16 verify "$VK" "${TMP}/public.json" "${TMP}/proof.json" >/dev/null 2>&1
exit 0
