const { ethers } = require("hardhat"); // Import ethers dari hardhat

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const Verifier = await ethers.getContractFactory("Verifier");
    const verifier = await Verifier.deploy();
    await verifier.deployed();
    console.log("Verifier contract deployed at:", verifier.address);

    const Cosmo = await ethers.getContractFactory("CosmoProof");
    const cosmo = await Cosmo.deploy(verifier.address);
    await cosmo.deployed();
    console.log("CosmoProof contract deployed at:", cosmo.address);
} 

main().catch((err) => { 
    console.error(err); 
    process.exit(1); 
});
