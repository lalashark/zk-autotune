#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

CIRCUIT="${1:-add}"; A="${2:-3}"; B="${3:-4}"; C="${4:-7}"
REPS="${REPS:-3}"; MAX_J="${MAX_J:-16}"; CPU_N=$(nproc)

# 候選 J
J_LIST=()
for j in 1 2 4 8 16 32; do
  (( j<=CPU_N && j<=MAX_J )) && J_LIST+=("$j")
done
((${#J_LIST[@]}==0)) && J_LIST=(1)

echo "[CHK ] 煙霧測試（單 proof）..."
/work/scripts/run_one.sh "$CIRCUIT" "$A" "$B" "$C" >/dev/null

echo "[BASE] 量測 Baseline（J=1, REPS=${REPS}）..."
BASE_TOTAL=0
for ((r=1;r<=REPS;r++)); do
  tfile=$(mktemp)
  /usr/bin/time -f %e -o "$tfile" \
    bash -c '/work/scripts/run_one.sh "'"$CIRCUIT"'" "'"$A"'" "'"$B"'" "'"$C"'" >/dev/null' || true
  OUT=$(cat "$tfile"); rm -f "$tfile"
  BASE_TOTAL=$(awk -v a="$BASE_TOTAL" -v b="$OUT" 'BEGIN{printf("%.9f", a+b)}')
done
BASE_AVG=$(awk -v t="$BASE_TOTAL" -v r="$REPS" 'BEGIN{printf("%.9f", t/r)}')
printf "[BASE] J=1 平均時間 = %.3fs\n" "$BASE_AVG"

declare -A LAT THR
OK_LIST=()
echo "[INFO] 開始調優：候選並行度 = ${J_LIST[*]}，每個 J 重覆 ${REPS} 次"

for J in "${J_LIST[@]}"; do
  N=$((J*REPS))
  tfile=$(mktemp)
  /usr/bin/time -f %e -o "$tfile" bash -c '
    rm -f /work/results/parallel_joblog.txt /work/results/last_parallel_err.txt
    # -N0：不要把索引當額外參數丟進 run_one.sh
    seq 1 '"$N"' | parallel -j '"$J"' --no-notice -N0 \
      /work/scripts/run_one.sh '"$CIRCUIT"' '"$A"' '"$B"' '"$C"' \
      1>/dev/null 2>>/work/results/last_parallel_err.txt || true
  ' || true
  TOTAL_WALL=$(cat "$tfile"); rm -f "$tfile"

  # 如果有 joblog 就數 exit=0 的數量；沒有就當作全成功
  if [[ -f /work/results/parallel_joblog.txt ]]; then
    OKN=$(awk 'NR>1 && $7==0{c++}END{print c+0}' /work/results/parallel_joblog.txt 2>/dev/null || echo 0)
  else
    OKN=$N
  fi
  if (( OKN == 0 )); then
    echo "[WARN] J=$J 全部失敗，略過此 J。"
    continue
  fi

  AVG_PER=$(awk -v w="$TOTAL_WALL" -v n="$OKN" 'BEGIN{printf("%.9f", w/n)}')
  THRO=$(awk -v w="$TOTAL_WALL" -v n="$OKN" 'BEGIN{printf("%.9f", n/w)}')
  LAT["$J"]="$AVG_PER"; THR["$J"]="$THRO"; OK_LIST+=("$J")

  printf "[RES ] J=%-2s → 平均每 proof = %.3fs, 吞吐 = %.3f proof/s (總牆鐘=%.3fs, OK=%d/%d)\n" \
    "$J" "$AVG_PER" "$THRO" "$TOTAL_WALL" "$OKN" "$N"

  [[ -s /work/results/last_parallel_err.txt ]] && \
    echo "       (部分 job 失敗，詳見 /work/results/last_parallel_err.txt)"
done

((${#OK_LIST[@]}==0)) && { echo "[ERR ] 所有 J 都失敗，無法產生總結。"; exit 1; }

BEST_J=""; BEST_LAT=""; BEST_T_J=""; BEST_T=""
for J in "${OK_LIST[@]}"; do
  L=${LAT[$J]}; T=${THR[$J]}
  if [[ -z "$BEST_LAT" ]] || awk -v l="$L" -v b="$BEST_LAT" 'BEGIN{exit !(l<b)}'; then
    BEST_LAT="$L"; BEST_J="$J"
  fi
  if [[ -z "$BEST_T" ]] || awk -v t="$T" -v b="$BEST_T" 'BEGIN{exit !(t>b)}'; then
    BEST_T="$T"; BEST_T_J="$J"
  fi
done
SPEEDUP=$(awk -v base="$BASE_AVG" -v best="$BEST_LAT" 'BEGIN{printf("%.3f", base/best)}')

cat <<EOF
==================== 結果 ====================
Baseline (J=1):         $(printf "%.3fs" "$BASE_AVG")
最佳延遲  (Latency):     J=${BEST_J}  → $(printf "%.3fs/proof" "$BEST_LAT")  (Speedup x$SPEEDUP)
最佳吞吐  (Throughput):  J=${BEST_T_J} → $(printf "%.3f" "$BEST_T") proof/s
候選 J： ${J_LIST[*]}
==============================================
EOF
