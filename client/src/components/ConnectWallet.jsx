// client/src/components/ConnectWallet.jsx
import React, { useState } from 'react';
import { ethers } from 'ethers';
import Web3Modal from 'web3modal';

const providerOptions = {}; 

const ConnectWallet = ({ setProvider, setSigner }) => {
    const [status, setStatus] = useState("Connect Wallet");

    const connectWallet = async () => {
        try {
            const web3Modal = new Web3Modal({
                cacheProvider: false,
                providerOptions
            });
            const instance = await web3Modal.connect();
            const provider = new ethers.providers.Web3Provider(instance);
            const signer = provider.getSigner();

            setProvider(provider);
            setSigner(signer);
            
            const address = await signer.getAddress();
            setStatus(`Wallet Connected: ${address.slice(0, 6)}...`);
            
        } catch (error) {
            console.error("Could not connect wallet:", error);
            setStatus("Connection Failed");
        }
    };

    return (
        <button 
            onClick={connectWallet}
            className="w-full py-3 px-4 border border-transparent rounded-lg shadow-md text-base font-medium text-white bg-green-600 hover:bg-green-700 transition disabled:bg-gray-400"
            disabled={status.includes("Connected")}
        >
            {status}
        </button>
    );
};

export default ConnectWallet;
