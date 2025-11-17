// circuits/asrzk_fixed.circom
pragma circom 2.0.0;
include "circomlib/poseidon.circom";
include "circomlib/bitify.circom";

/* ASRZK Fixed Circuit (N = 128) */
template ASRZK(N) {
    // PUBLIC (12 Inputs total)
    signal input modelHash;
    signal input transcriptHash; // Poseidon hash(u)
    signal input g_q_input;      // g * Q
    signal input L_reg_q_claim;  // L_reg * Q
    signal input A_q;
    signal input B_q;
    signal input C_q;
    signal input p0_q;
    signal input p1_q;
    signal input p2_q;
    signal input p3_q;
    signal input Q_scalar;

    // PRIVATE
    signal private u[N]; // Activation squared normalized * Q (u = h^2 / H_max^2 * Q)

    // --- 1. PROVE INTEGRITY: transcriptHash = Poseidon(u) ---
    component pose = Poseidon(N);
    for (var i = 0; i < N; i++) {
        pose.inputs[i] <== u[i];
    }
    pose.out === transcriptHash; 

    // --- 2. RANGE CHECK: u[i] is 32-bit ---
    for (var i = 0; i < N; i++) {
        component bchk = Num2Bits(32);
        bchk.in <== u[i];
    }

    // Q1 = Q_scalar
    signal Q1;
    Q1 <== Q_scalar;
    
    // --- 3. CALCULATE PHI (phi = C*u^1 + B*u^2 + A*u^3) via Horner's Method ---
    // Target scale: phi[i] * Q
    signal phi[N];
    for (var i = 0; i < N; i++) {
        // t1 = C_q * u[i] / Q
        signal t1;
        t1 <== C_q * u[i];
        t1 === Q1 * (t1/Q1); // Division by Q1 (Q_scalar)
        
        // t2 = t1 + B_q (Result is approx Q-scaled)
        signal t2;
        t2 <== t1 + B_q;
        
        // t3 = t2 * u[i] / Q
        signal t3;
        t3 <== t2 * u[i];
        t3 === Q1 * (t3/Q1); 

        // t4 = t3 + A_q (Result is approx Q-scaled)
        signal t4;
        t4 <== t3 + A_q;
        
        // t5 = t4 * u[i] / Q 
        signal t5;
        t5 <== t4 * u[i];
        t5 === Q1 * (t5/Q1); 
        
        // Final value: phi[i] * Q = t5/Q
        phi[i] <== t5 / Q1; 
        phi[i] * Q1 === t5; // Constraint: phi[i] * Q = t5
    }

    // --- 4. SUM S_REG ---
    signal S_reg_q; // S_reg is scaled by Q (S_reg * Q)
    S_reg_q <== 0;
    for (var i = 0; i < N; i++) {
        S_reg_q <== S_reg_q + phi[i];
    }

    // --- 5. CALCULATE LAMBDA (lambda = p0 + p1*g + p2*g^2 + p3*g^3) ---
    // Target scale: lambda_q * Q
    
    // ta = p3_q * g_q_input / Q
    signal ta;
    ta <== p3_q * g_q_input;
    ta === Q1 * (ta/Q1);

    // tb = ta + p2_q 
    signal tb;
    tb <== ta + p2_q;

    // tc = tb * g_q_input / Q
    signal tc;
    tc <== tb * g_q_input;
    tc === Q1 * (tc/Q1);

    // td = tc + p1_q
    signal td;
    td <== tc + p1_q;

    // te = td * g_q_input / Q
    signal te;
    te <== td * g_q_input;
    te === Q1 * (te/Q1);

    // tf = te + p0_q (Result is lambda_q * Q)
    signal tf;
    tf <== te + p0_q;
    
    signal lambda_q;
    lambda_q <== tf / Q1;
    lambda_q * Q1 === tf; // Constraint: lambda_q * Q = tf

    // --- 6. FINAL CLAIM CHECK: L_reg_q_claim * Q = lambda_q * S_reg_q ---
    // L_reg_q_claim: Q-scaled
    // lambda_q: Q-scaled
    // S_reg_q: Q-scaled
    
    // Right side: lambda_q (Q-scaled) * S_reg_q (Q-scaled) = Q^2-scaled
    signal right_side;
    right_side <== lambda_q * S_reg_q;
    
    // We need to divide by Q to get L_reg_q * Q
    signal L_reg_calculated_q;
    L_reg_calculated_q <== right_side / Q1;
    
    // Final Constraint: The claimed L_reg must equal the calculated one
    L_reg_q_claim === L_reg_calculated_q;
    
    L_reg_q_claim * Q1 === right_side; // Final simplified check
}

// Urutan public inputs yang wajib sinkron dengan CosmoProof.sol
component main {public [ 
    modelHash,           // Index 0
    transcriptHash,      // Index 1
    g_q_input,           // Index 2
    L_reg_q_claim,       // Index 3
    A_q, B_q, C_q,       // Index 4, 5, 6
    p0_q, p1_q, p2_q, p3_q, // Index 7, 8, 9, 10
    Q_scalar             // Index 11
]} = ASRZK(128);
