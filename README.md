# ⚛️ CosmoProof — ZK-Verified Polynomial Stability Loss (Final Submission)

Status: **100% Submission-Ready. High-Level ZK-EVM Implementation.**

This project uses Zero-Knowledge Groth16 proofs to verify a complex, fixed-point **Axiomatic Stability Regularizer (ASR) Loss** calculation. It ensures AI model stability can be proven on-chain without revealing private model parameters.

### 🛠️ Prerequisites

1.  Node.js (18+), npm, Python 3.10+
2.  **circom** v2, **snarkjs** (global install required)
3.  Hardhat (`npm install --save-dev hardhat`)

### 📦 Setup & Installation

From the repo root:

```bash
# 1. Install Global and Project Dependencies
npm install -g circom snarkjs 
npm install 
cd prover && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && cd ..
```
# 2. Grant execution permissions for the main script
chmod +x run_me.sh


##⚡ Full ZK Pipeline Demo
Run this single command to generate the proof and the Solidity Verifier:
```bahs
./run_me.sh
```

#The script successfully generates proof.json, public.json, and overwrites contracts/Verifier.sol.
#🚀 Deployment & Frontend
•Deployment: Fill in .env and deploy the contracts:
```bash
npx hardhat run contracts/deploy.js --network scroll

```
     ACTION: Note the deployed CosmoProof contract address.
•Frontend Setup:
```bash
cd client
npm install
# ⚠️ IMPORTANT: Before running, update the contract address in client/src/App.jsx.
npm start

```
(Open http://localhost:3000 to upload the generated proof.json and public.json and verify the proof on-chain.)
