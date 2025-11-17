#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"

echo "[0] Checking Prerequisites..."
command -v circom >/dev/null || { echo "ERROR: circom not found"; exit 1; }
command -v snarkjs >/dev/null || { echo "ERROR: snarkjs not found"; exit 1; }
python3 -c "import numpy" >/dev/null 2>&1 || { echo "ERROR: numpy not installed. Run: cd prover && source venv/bin/activate && pip install -r requirements.txt"; exit 1; }
echo "Prerequisites OK."

# 1) produce input.json
echo "[1] Exporting payload & calculating REAL Poseidon hash (fixed-point logic)..."
python3 prover/export_payload_fixed.py

# 2) compile circuit
echo "[2] Compiling circuit..."
cd circuits
rm -rf build
circom asrzk_fixed.circom --r1cs --wasm --sym -o build
echo "Circuit compiled successfully."

# 3) download ptau
PTAU=pot16_final.ptau 
if [ ! -f "$PTAU" ]; then
    echo "[3] Downloading ptau (pot16: 2^16 = 65k constraints)..."
    wget -O "$PTAU" https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_16.ptau
fi

# 4) setup zkey (Groth16)
echo "[4] Setting up zkey (Setup & Contribute)..."
snarkjs groth16 setup build/asrzk_fixed.r1cs "$PTAU" asrzk_0000.zkey
snarkjs zkey contribute asrzk_0000.zkey asrzk_final.zkey --name="CosmoProof Contributor" -v

# 5) export verification key & solidity verifier
echo "[5] Exporting verification key and Solidity Verifier (Overwriting contracts/Verifier.sol)..."
snarkjs zkey export verificationkey asrzk_final.zkey verification_key.json
snarkjs zkey export solidityverifier asrzk_final.zkey ../contracts/Verifier.sol

# 6) copy input.json into build folder for witness generation
echo "[6] Copying input.json into build folder..."
cp ../circuits/input.json build/input.json

# 7) generate witness 
echo "[7] Generating witness..."
node build/asrzk_fixed_js/generate_witness.js build/asrzk_fixed_js/asrzk_fixed.wasm build/input.json witness.wtns

# 8) produce proof
echo "[8] Producing Groth16 proof..."
snarkjs groth16 prove asrzk_final.zkey witness.wtns proof.json public.json

# 9) verify locally
echo "[9] Verifying proof locally..."
snarkjs groth16 verify verification_key.json public.json proof.json
echo "========================================================="
echo "✅ SUCCESS: Proof Verified Locally. Contracts ready for deploy."
echo "========================================================="

# Kembali ke root
cd $ROOT
