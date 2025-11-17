#!/usr/bin/env python3
import numpy as np
import json
import subprocess
from pathlib import Path

# --- CONFIG ---
N = 128
H2_MAX_FLOAT = 16.0
G_MAX_FLOAT = 256.0
Q = 2**32 - 1 # Q_scalar (Fixed-point 32-bit scale)
MODEL_HASH = 9876543210123456789 

# Proxy untuk Field Modulus (r ~ 2^254) untuk wrapping bilangan negatif
PRIME_MODULUS_PROXY = 2**254 

# Koefisien float ASR (phi = C*u^1 + B*u^2 + A*u^3)
A, B, C = 0.864, 0.384, 0.256
# Koefisien lambda polynomial (lambda = p0 + p1*g + p2*g^2 + p3*g^3)
p0, p1, p2, p3 = 0.95, -0.4, 0.3, -0.05

# --- Fungsi Utility ---

def to_field_element(val):
    """Mengubah float (setelah dikalikan Q) menjadi elemen field. Menangani negatif."""
    int_val = int(round(val * Q))
    if int_val < 0:
        # Wrap negatif ke dalam field (int_val + r)
        return int_val + PRIME_MODULUS_PROXY
    return int_val

# Hitung koefisien tetap dalam bentuk fixed-point dan field-wrapped
A_q = to_field_element(A)
B_q = to_field_element(B)
C_q = to_field_element(C)
p_q = [to_field_element(x) for x in (p0, p1, p2, p3)]


def compute_poseidon(u_list):
    """Menghitung Poseidon hash menggunakan snarkjs CLI via subprocess."""
    input_json = {"inputs": [str(x) for x in u_list]}
    
    # Path relatif ke circuits/temp_poseidon.json
    temp_path = Path("circuits/temp_poseidon.json")
    temp_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path.write_text(json.dumps(input_json))
    
    try:
        # Panggil snarkjs dari root (perlu diubah path input)
        result = subprocess.run(
            ["snarkjs", "calculate", "poseidon", str(temp_path)],
            capture_output=True, text=True, check=True, timeout=10
        )
        temp_path.unlink() 
        return int(result.stdout.strip())
    except Exception as e:
        print(f"ERROR: Gagal menjalankan snarkjs untuk Poseidon.")
        raise e

def eval_phi_q_horner(u_q):
    """Mengevaluasi phi(u) * Q (target skala di Circom) di Python."""
    phi_list = []
    
    # Koefisien A_q, B_q, C_q sudah Q-scaled
    Q1 = Q 
    
    for u in u_q:
        u = int(u)
        # Simulasi Horner evaluation dengan fixed-point: t = (C*u + B*Q)*u + A*Q^2)*u / Q^2
        
        # t1 = C_q * u / Q
        t1 = (C_q * u) // Q1 
        # t2 = t1 + B_q 
        t2 = t1 + B_q 
        # t3 = t2 * u / Q
        t3 = (t2 * u) // Q1
        # t4 = t3 + A_q 
        t4 = t3 + A_q
        # t5 = t4 * u / Q (Result is phi[i] * Q)
        t5 = (t4 * u) // Q1
        
        # Hasilnya adalah phi_q * Q.
        phi_list.append(int(t5))
    return np.array(phi_list, dtype=np.uint64)

def eval_lambda_q_from_gq(g_q):
    """Mengevaluasi lambda(g) * Q (target skala di Circom) di Python."""
    # g_q sudah Q-scaled. pX_q sudah Q-scaled.
    Q1 = Q
    
    # v = p3_q
    v = p_q[3]
    # v = v*g_q / Q + p2_q
    v = (v * g_q) // Q1 + p_q[2]
    # v = v*g_q / Q + p1_q
    v = (v * g_q) // Q1 + p_q[1]
    # v = v*g_q / Q + p0_q
    v = (v * g_q) // Q1 + p_q[0]
    
    # Hasilnya adalah lambda_q * Q
    return int(v)


# --- Fungsi Export Utama ---

def export_demo_payload():
    # 1. Generate inputs
    h = np.abs(np.random.randn(N)).astype(np.float64)
    h2 = np.minimum(h**2, H2_MAX_FLOAT)
    u_float = h2 / H2_MAX_FLOAT
    u_q = (u_float * Q).astype(np.uint32)
    u_list = u_q.tolist()

    # 2. Hitung Poseidon Hash (Transcript)
    transcript_hash = compute_poseidon(u_list)
    
    # 3. Hitung Klaim (L_reg)
    grad_norm_sq = float(np.random.rand() * G_MAX_FLOAT)
    g_q = int(min(grad_norm_sq / G_MAX_FLOAT, 1.0) * Q)
    
    # Hitung S_reg_q * Q
    phi_q_scaled = eval_phi_q_horner(u_q)
    S_reg_q = int(np.sum(phi_q_scaled)) 
    
    # Hitung lambda_q * Q
    lambda_q = eval_lambda_q_from_gq(g_q)
    
    # L_reg_q * Q = (lambda_q * Q) * (S_reg_q * Q) / Q
    # L_reg_q = (lambda_q * S_reg_q) / Q
    L_reg_q_claim = (lambda_q * S_reg_q) // Q 
    
    # 4. Susun Payload (Sesuai urutan di Circom)
    payload = {
        "modelHash": str(MODEL_HASH),
        "transcriptHash": str(transcript_hash),
        "g_q_input": int(g_q),
        "L_reg_q_claim": int(L_reg_q_claim),
        "A_q": int(A_q),
        "B_q": int(B_q),
        "C_q": int(C_q),
        "p0_q": p_q[0],
        "p1_q": p_q[1],
        "p2_q": p_q[2],
        "p3_q": p_q[3],
        "Q_scalar": int(Q),
        "u": [int(x) for x in u_list]
    }
    
    out = Path("../circuits/input.json") # Output di circuits/
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as f:
        json.dump(payload, f, indent=2)
    print("Wrote", out.resolve())

if __name__ == "__main__":
    export_demo_payload()
