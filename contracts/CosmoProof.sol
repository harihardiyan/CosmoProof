// contracts/CosmoProof.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Verifier.sol";

contract CosmoProof {
    Verifier public verifier;
    address public owner;

    event StabilityVerified(bytes32 indexed modelHash, address indexed prover, uint256 Lreg);

    constructor(address _verifier) {
        verifier = Verifier(_verifier);
        owner = msg.sender;
    }

    function submitStabilityProof(
        bytes32 modelHash,
        uint256 Lreg, // Ini adalah L_reg_q_claim yang sudah di-Q-scale
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[] memory input // Harus sesuai urutan di Circom
    ) public returns (bool) {
        // 1. Cek modelHash: input[0] (dari ZK proof) harus cocok dengan argumen
        require(input[0] == uint256(modelHash), "ZK modelHash mismatch (input[0])");

        // 2. Cek Lreg: input[3] (dari ZK proof, yaitu L_reg_q_claim) harus cocok dengan argumen Lreg
        require(input[3] == Lreg, "ZK claim Lreg mismatch (input[3])");

        // 3. Verifikasi Proof
        require(verifier.verifyProof(a, b, c, input), "Invalid ZK proof");

        emit StabilityVerified(modelHash, msg.sender, Lreg);
        return true;
    }

    function updateVerifier(address newVerifier) external {
        require(msg.sender == owner, "only owner");
        verifier = Verifier(newVerifier);
    }
}
