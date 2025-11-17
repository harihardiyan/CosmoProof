// client/src/App.jsx
import React, { useState } from 'react';
import { ethers } from 'ethers';
import ConnectWallet from './components/ConnectWallet';
import ABI from './CosmoProofABI.json'; 

// 🚨 GANTI INI setelah deploy Hardhat Anda!
const COSMOPROOF_ADDRESS = "0x0000000000000000000000000000000000000000"; // Placeholder

function App() {
    const [provider, setProvider] = useState(null);
    const [signer, setSigner] = useState(null);
    const [proofFile, setProofFile] = useState(null);
    const [publicFile, setPublicFile] = useState(null);
    const [status, setStatus] = useState("Awaiting Proof Upload");
    const [txHash, setTxHash] = useState(null);

    const handleFileChange = (e, setFileState) => {
        const file = e.target.files[0];
        if (file) {
            setFileState(file);
            setStatus("Ready to submit (Files uploaded)");
        }
    };

    const submitProof = async () => {
        if (!signer || !proofFile || !publicFile) {
            setStatus("ERROR: Wallet not connected or files missing.");
            return;
        }

        if (COSMOPROOF_ADDRESS === "0x0000000000000000000000000000000000000000") {
             setStatus("ERROR: Harap ganti alamat kontrak COSMOPROOF_ADDRESS.");
            return;
        }

        setStatus("Reading files and parsing ZK data...");
        
        try {
            const proofJson = JSON.parse(await proofFile.text());
            const publicJson = JSON.parse(await publicFile.text());
            
            // 1. Format Proof Groth16 (a, b, c) sesuai Solidity
            const a = proofJson.pi_a.slice(0, 2);
            const b = [proofJson.pi_b[0].slice(0, 2), proofJson.pi_b[1].slice(0, 2)];
            const c = proofJson.pi_c.slice(0, 2);
            
            // 2. Format Public Inputs (input)
            // Semua input ZK harus berupa BigNumber/string
            const input = publicJson.map(s => ethers.BigNumber.from(s));

            // 3. Ekstrak Argumen Utama (Sesuai urutan input Circom)
            // Perhatikan bahwa modelHash dan Lreg harus ditransfer sebagai argumen terpisah
            const modelHash = input[0]; // Index 0: modelHash
            const Lreg = input[3];     // Index 3: L_reg_q_claim

            // Konversi modelHash dari BigNumber ke bytes32 untuk Solidity (perlu pad-left ke 32 byte jika kurang)
            const modelHashBytes32 = ethers.utils.hexZeroPad(modelHash.toHexString(), 32);

            // 4. Panggil Kontrak
            const contract = new ethers.Contract(COSMOPROOF_ADDRESS, ABI, signer);
            setStatus("Sending transaction to Scroll...");

            const tx = await contract.submitStabilityProof(
                modelHashBytes32, 
                Lreg,     
                a, b, c, 
                input     
            );

            setStatus("Transaction pending: " + tx.hash);
            await tx.wait();

            setStatus("✅ Verification Success! Proof submitted on-chain.");
            setTxHash(tx.hash);

        } catch (error) {
            console.error("Submission Error:", error);
            setStatus("❌ Transaction Failed: " + (error.data?.message || error.message || String(error)));
        }
    };

    // Note: Anda mungkin perlu menambahkan CSS (mis. Tailwind) di index.html atau setup React Anda agar styling terlihat.
    return (
        <div className="container mx-auto p-8 max-w-xl bg-gray-50 min-h-screen">
            <h1 className="text-4xl font-extrabold mb-6 text-indigo-700 text-center">⚛️ CosmoProof ZK Submission</h1>
            
            <div className="mb-6">
                <ConnectWallet setProvider={setProvider} setSigner={setSigner} />
            </div>

            <div className="bg-white shadow-xl p-6 rounded-xl border border-gray-200">
                <h2 className="text-2xl font-semibold mb-4 text-gray-800">1. Upload Proof Artifacts</h2>

                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Proof File (proof.json):</label>
                        <input type="file" onChange={(e) => handleFileChange(e, setProofFile)} className="mt-1 block w-full text-sm file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Public Inputs (public.json):</label>
                        <input type="file" onChange={(e) => handleFileChange(e, setPublicFile)} className="mt-1 block w-full text-sm file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100" />
                    </div>
                </div>

                <button
                    onClick={submitProof}
                    disabled={!signer || !proofFile || !publicFile || status.includes("pending") || status.includes("ERROR")}
                    className="mt-6 w-full py-3 px-4 rounded-lg shadow-md text-base font-medium text-white bg-indigo-600 hover:bg-indigo-700 disabled:bg-gray-400 transition"
                >
                    {status.includes("pending") ? "Processing Transaction..." : "Submit Proof to Scroll"}
                </button>

                <p className={`mt-4 text-center font-semibold text-sm ${status.includes("✅") ? 'text-green-600' : status.includes("❌") ? 'text-red-600' : 'text-gray-600'}`}>
                    Status: {status}
                </p>

                {txHash && (
                    <div className="mt-3 text-center text-sm">
                        <a href={`https://scrollscan.com/tx/${txHash}`} target="_blank" rel="noopener noreferrer" className="text-indigo-500 underline hover:text-indigo-700">
                            View Transaction on Scroll Explorer
                        </a>
                    </div>
                )}
            </div>
        </div>
    );
}

export default App;
