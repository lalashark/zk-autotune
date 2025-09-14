#!/usr/bin/env bash
set -euo pipefail

CIRCUIT="${1:?usage: setup_keys.sh <circuit_name>}"
BUILD="/work/build"
R1CS="${BUILD}/${CIRCUIT}.r1cs"
PTAU0="${BUILD}/ptau_0000.ptau"
PTAU1="${BUILD}/ptau_0001.ptau"
PTAUF="${BUILD}/ptau_final.ptau"
ZKEY0="${BUILD}/${CIRCUIT}_0000.zkey"
ZKEYF="${BUILD}/${CIRCUIT}_final.zkey"
VK="${BUILD}/${CIRCUIT}_vk.json"

[[ -f "$R1CS" ]] || { echo "[ERR ] $R1CS 不存在，請先 compile"; exit 1; }

echo "[INFO] Powers of Tau (bn128, power=12)"
snarkjs powersoftau new bn128 12 "$PTAU0" -v
snarkjs powersoftau contribute "$PTAU0" "$PTAU1" --name="contrib-1" -v
snarkjs powersoftau prepare phase2 "$PTAU1" "$PTAUF"

echo "[INFO] Groth16 setup / contribute"
snarkjs groth16 setup "$R1CS" "$PTAUF" "$ZKEY0"
snarkjs zkey contribute "$ZKEY0" "$ZKEYF" --name="key-1" -v

echo "[INFO] Export verification key -> $VK"
snarkjs zkey export verificationkey "$ZKEYF" "$VK"

echo "[OK  ] setup 完成：$ZKEYF 與 $VK"
