# Quantum Threat to Classical Cryptography

## Prerequisites
- Asymmetric cryptography fundamentals: RSA, ECC, Diffie-Hellman
- Symmetric encryption fundamentals: AES, block cipher modes
- Basic complexity theory: polynomial vs. exponential time
- Hash functions and their security properties

---

## Concept Reference

### Why Quantum Computers Are Cryptographically Relevant

Classical computers execute operations one logical step at a time. A quantum computer
exploits two quantum-mechanical phenomena that have no classical analogue:

**Superposition:** A qubit can represent 0 and 1 simultaneously. An n-qubit register can
exist in a superposition of all 2^n states at once, allowing certain computations to
explore an exponentially large search space in parallel.

**Interference:** Quantum algorithms are structured so that correct answers have amplitudes
that constructively interfere (grow larger) while wrong answers destructively interfere
(cancel out). Measuring the register then collapses to the correct answer with high
probability.

These properties do not give a quantum computer universal speedup. The speedup depends
entirely on whether a problem has a quantum algorithm that can exploit interference
productively. Most classical problems do not. Cryptographic problems are special because
they are built on the hardness of specific mathematical structures—and those structures
happen to have efficient quantum algorithms.

---

### Shor's Algorithm: Threat to RSA and ECC

**What it solves:** Shor's algorithm (1994) solves the integer factoring problem and the
discrete logarithm problem in polynomial time on a quantum computer.

**Classical hardness assumptions:**

```
RSA security:  Given N = p * q, finding p and q is computationally infeasible
               for large N. Best classical algorithm (GNFS) runs in sub-exponential
               time: exp(c * (ln N)^(1/3) * (ln ln N)^(2/3))

DLP security:  Given g^x mod p = y, finding x is computationally infeasible.
               Best classical algorithm (index calculus) also runs in sub-exponential
               time.

ECDLP security: Given P and Q = k*P on an elliptic curve, finding k is
                computationally infeasible. Best classical algorithm (BSGS, Pollard rho)
                runs in fully exponential time: O(sqrt(n)) where n is group order.
```

**Shor's algorithm complexity:**

```
Integer factoring:   O((log N)^2 * (log log N) * (log log log N))  -- polynomial
Discrete logarithm: O((log p)^2 * (log log p))                     -- polynomial
ECDLP:              O((log n)^3)                                    -- polynomial

In practice, all three are polynomial in the number of qubits, which is polynomial
in the bit-length of the key. This is an exponential speedup over the best known
classical algorithms for RSA and DH, and an asymptotically larger speedup for ECC.
```

**How Shor's algorithm works (conceptual sketch):**

To factor N, Shor reduces factoring to the problem of finding the period r of the
function f(x) = a^x mod N for a randomly chosen a coprime to N. Once r is known:

```
1. Choose random a where 1 < a < N and gcd(a, N) = 1
2. Find the period r of f(x) = a^x mod N  [this is the quantum step]
3. If r is even and a^(r/2) != -1 mod N:
      gcd(a^(r/2) - 1, N) and gcd(a^(r/2) + 1, N) give non-trivial factors

Period finding uses:
  - Quantum Fourier Transform (QFT) to extract the period from superposition
  - QFT is the key quantum subroutine; it runs in O((log N)^2) gates vs
    O(N log N) for classical FFT
```

**Practical impact on key sizes:**

```
Algorithm      Classical bit-security   Qubits needed to break   Status
-----------    ---------------------   ----------------------   --------
RSA-1024       ~80 bits                ~2,048 logical qubits    Broken by Shor
RSA-2048       ~112 bits               ~4,096 logical qubits    Broken by Shor
RSA-3072       ~128 bits               ~6,144 logical qubits    Broken by Shor
ECC-256        ~128 bits               ~2,330 logical qubits    Broken by Shor
ECC-384        ~192 bits               ~3,484 logical qubits    Broken by Shor

Note: "Logical qubits" assumes error correction. Physical qubit overhead
for fault-tolerant quantum computing is estimated at 1,000-10,000x logical
qubits, meaning millions of physical qubits are required. As of 2025, the
largest publicly known quantum processors have ~1,000 physical qubits with
insufficient error rates for cryptanalysis of real-world key sizes.
```

**Key implication:** No key size makes RSA or ECC quantum-resistant. Doubling the RSA key
from 2048 to 4096 bits roughly doubles the number of qubits needed — a linear scaling
that does not restore security against a sufficiently capable quantum computer.

---

### Grover's Algorithm: Threat to Symmetric Cryptography and Hash Functions

**What it solves:** Grover's algorithm (1996) provides a quadratic speedup for searching
an unstructured database of N items, finding a target in O(sqrt(N)) quantum operations
instead of O(N) classical operations.

**Application to symmetric cryptography:**

```
AES-128 classical security:  2^128 operations to break by exhaustive search
AES-128 quantum security:    2^64 operations  (sqrt(2^128) = 2^64)

AES-192 classical security:  2^192 operations
AES-192 quantum security:    2^96 operations

AES-256 classical security:  2^256 operations
AES-256 quantum security:    2^128 operations
```

**Implication for symmetric key sizes:**

To maintain 128-bit post-quantum security, use 256-bit keys. This is a straightforward
fix: AES-256 already exists and is widely deployed. Grover's algorithm does not break
AES-256; it merely reduces its effective security from 256-bit to 128-bit quantum
security, which is still considered sufficient.

**Application to hash functions:**

```
Collision resistance:   Classical O(2^(n/2)) by birthday attack
                        Quantum  O(2^(n/3))  by Brassard-Hoyer-Tapp algorithm
                        (BHT, which uses quantum walk search)

Preimage resistance:    Classical O(2^n)
                        Quantum   O(2^(n/2)) by Grover

SHA-256 post-quantum:   Preimage: 2^128 quantum ops -- acceptable
                        Collision: 2^85 quantum ops  -- marginal (BHT)

SHA-384 post-quantum:   Preimage: 2^192 quantum ops -- comfortable
                        Collision: 2^128 quantum ops -- acceptable

SHA-512 post-quantum:   Preimage: 2^256 quantum ops -- very comfortable
                        Collision: 2^170 quantum ops -- comfortable
```

**NIST recommendation:** Use SHA-256 or larger for hash-based applications needing
post-quantum collision resistance. SHA-384 or SHA-512 provides comfortable margins.

---

### Comparing the Two Threats

```
Property                  Shor's Algorithm          Grover's Algorithm
----------------------    ----------------------    ----------------------
Speedup type              Exponential               Quadratic
Target                    RSA, ECC, DH, DSA         AES, 3DES, SHA, HMAC
Impact                    Complete break            Security halved (bits)
Mitigation                Replace algorithm         Double key/output size
Urgency                   Critical                  Manageable
Current classical fix     None (algorithm must      AES-256, SHA-384+
                          be replaced)
```

---

### The Harvest Now, Decrypt Later (HNDL) Threat

An adversary with access to encrypted traffic today can:

1. Record ciphertext encrypted under RSA or ECDH key exchange
2. Store it until a cryptographically relevant quantum computer (CRQC) is available
3. Retroactively decrypt the stored ciphertext using Shor's algorithm

This threat is real for data that must remain confidential beyond the expected timeline for
quantum computers. The relevant timelines cited by national security agencies:

```
Conservative estimate:  15-20 years to CRQC
Aggressive estimate:    8-10 years to CRQC (cited by some intelligence agencies)

Data lifetime implication:
  - A secret that must be kept for 20 years is already at risk today
  - Financial records, health records, government secrets: migrate NOW
  - Session keys for web traffic: lower urgency (short-lived secrets)
```

This is why NIST began the PQC standardisation process in 2016, finalising the first
standards in 2024.

---

### NIST Post-Quantum Standardisation Timeline

```
2016:  NIST calls for PQC proposals
2017:  69 submissions received
2019:  26 candidates advance to Round 2
2020:  15 candidates advance to Round 3 (7 finalists + 8 alternates)
2022:  NIST announces initial selections:
         CRYSTALS-Kyber  (KEM)
         CRYSTALS-Dilithium  (signatures)
         FALCON  (signatures)
         SPHINCS+  (signatures)
2024:  FIPS 203 (ML-KEM / Kyber), FIPS 204 (ML-DSA / Dilithium),
       FIPS 205 (SLH-DSA / SPHINCS+) formally published
2024+: Additional standards expected (FN-DSA / FALCON as FIPS 206)
```

---

## Interview Questions

### Fundamentals

**Q1.** Explain the difference between the threats posed by Shor's algorithm and Grover's
algorithm to cryptographic systems. Which is more immediately dangerous, and why?

**Answer:**

Shor's algorithm poses an existential threat to all public-key cryptography built on
integer factoring (RSA) or discrete logarithm problems (DH, DSA, ECDH, ECDSA). It solves
these problems in polynomial time, meaning no key size provides security — doubling the
key only doubles the quantum computational cost, which scales linearly rather than
exponentially. The entire algorithm class must be replaced.

Grover's algorithm poses a more limited threat to symmetric and hash-based cryptography.
It provides only a quadratic speedup: it halves the effective bit-security. AES-128
becomes AES-64-equivalent under Grover. The fix is straightforward: double the key size.
AES-256 provides 128-bit quantum security, which is considered safe.

Shor's is more immediately dangerous because it requires replacing the entire deployed
public-key infrastructure — TLS, certificate authorities, code signing, SSH — which takes
years or decades. Grover's requires only configuration changes (use AES-256 and SHA-384+),
which can be deployed incrementally.

---

**Q2.** What is the "Harvest Now, Decrypt Later" (HNDL) attack? Which types of secrets
are most at risk?

**Answer:**

HNDL refers to the strategy of recording encrypted traffic today and decrypting it once a
cryptographically relevant quantum computer becomes available. An attacker archives
ciphertext that is currently secure under RSA or ECDH key exchange, then applies Shor's
algorithm retrospectively.

Most at-risk secrets:
- Long-lived confidential data: government intelligence, military communications, trade
  secrets, medical records
- Data encrypted under static long-term keys (as opposed to ephemeral per-session keys)
- Anything with a confidentiality requirement spanning 10-20+ years

Less at risk: short-lived session keys (e.g., HTTPS sessions). By the time a CRQC
exists, those sessions will have long since ended and the plaintext will typically be
publicly available or irrelevant. However, forward secrecy in TLS does not protect
against HNDL if the key exchange mechanism itself is non-quantum-safe, because the
session key derivation relies on ECDH which Shor can attack.

---

**Q3.** What is the quantum security of AES-256 under Grover's algorithm, and is it
sufficient for long-term security?

**Answer:**

Grover's algorithm searches N items in O(sqrt(N)) quantum operations. For AES-256 with a
keyspace of size 2^256, Grover requires approximately 2^128 quantum operations. This gives
AES-256 a post-quantum security level of 128 bits.

NIST considers 128-bit security adequate for most applications through 2030 and beyond.
128-bit quantum security means an adversary with a quantum computer would need to perform
2^128 operations to break a single key — an astronomical number that remains
computationally infeasible even with quantum hardware.

There are caveats: Grover's speedup assumes an ideal quantum oracle over all AES-256 key
candidates. Practical limitations — including the serial nature of Grover iterations
(they cannot be trivially parallelised without reducing the per-unit speedup), circuit
depth, and quantum error correction overhead — mean that practical quantum attacks on
AES-256 remain far beyond near-term capability.

---

### Intermediate

**Q4.** Shor's algorithm reduces integer factoring to period-finding. Explain what the
Quantum Fourier Transform (QFT) does in this context and why a classical FFT cannot
achieve the same speedup.

**Answer:**

The QFT is the quantum analogue of the classical discrete Fourier transform, but it
operates on quantum amplitudes. In Shor's algorithm, after preparing a superposition
state encoding a^x mod N for all x simultaneously, the QFT extracts the periodicity of
this function by transforming the state into the frequency domain. The period r manifests
as peaks at multiples of N/r in the frequency domain. A single measurement then collapses
the state to one of these peaks, allowing r to be inferred by classical post-processing.

A classical FFT cannot replicate this because:
1. The classical FFT requires explicitly computing all 2^n values of f(x) = a^x mod N
   before transforming — this costs O(N) time just in evaluation, where N = 2^n.
2. The quantum computer evaluates all values simultaneously through superposition without
   reading them out individually. The QFT then acts on this superposition coherently.
3. The QFT requires only O(n^2) quantum gates, versus O(N log N) = O(2^n * n) for a
   classical FFT over the same N-point dataset.

The exponential advantage comes from quantum parallelism in the evaluation phase, not
from the Fourier transform itself.

---

**Q5.** An engineer proposes upgrading RSA-2048 to RSA-8192 as a quantum-safe measure.
Evaluate this proposal.

**Answer:**

This proposal does not provide quantum safety and represents a fundamental misunderstanding
of Shor's threat model.

Shor's algorithm solves RSA factoring in polynomial time O((log N)^2 * polylog(log N)).
The number of logical qubits required to factor an n-bit RSA modulus is approximately
2n. So:

```
RSA-2048:  ~4,096 logical qubits
RSA-8192:  ~16,384 logical qubits
```

Going from RSA-2048 to RSA-8192 increases the quantum computational cost by a factor of
only 4 (in terms of qubits needed, roughly). This is a linear scaling of a hardware
resource. As quantum computers scale, this offers no long-term protection — it merely
delays the attacker by a fixed hardware improvement factor.

Contrast with classical security: doubling the RSA key size from 2048 to 4096 increases
the classical attack cost by a sub-exponential factor due to GNFS scaling. This is why
larger keys help classically. But against Shor, the cost scaling is polynomial, not
exponential, so no key size restores security.

The correct approach is to replace RSA entirely with a post-quantum algorithm such as
ML-KEM (Kyber) for key encapsulation or ML-DSA (Dilithium) for signatures, which are
based on mathematical problems that do not have known polynomial quantum algorithms.

---

### Advanced

**Q6.** The BHT (Brassard-Hoyer-Tapp) quantum collision-finding algorithm achieves
O(2^(n/3)) for an n-bit hash. Compare this to the classical birthday attack O(2^(n/2))
and explain the implications for SHA-256 and SHA-3-256 post-quantum security.

**Answer:**

The classical birthday attack exploits the birthday paradox: among O(2^(n/2)) random
hash evaluations, a collision is found with constant probability. BHT improves this using
a quantum walk algorithm over a hash value database stored in a quantum-accessible
structure (QRAM), achieving O(2^(n/3)) quantum queries.

For SHA-256 (n=256):
```
Classical collision: 2^128 operations -- 128-bit collision resistance
Quantum collision (BHT): 2^(256/3) ≈ 2^85 operations -- ~85-bit collision resistance
```

For SHA-3-256 the situation is identical since both produce 256-bit outputs and BHT
applies to any ideal random oracle.

85-bit collision resistance falls below NIST's 128-bit post-quantum security threshold.
This is relevant for applications requiring collision resistance, such as:
- Hash-based digital signature schemes (where collision finding could allow forgery)
- Commitment schemes
- Merkle tree constructions

For preimage resistance, Grover gives O(2^128) quantum operations on SHA-256, which is
still considered safe. NIST's guidance is to use SHA-384 or SHA-512 for applications
where quantum collision resistance matters, giving BHT collision costs of 2^128 and
2^170 respectively.

Note: BHT requires QRAM (quantum random access memory), a hardware resource whose
practical feasibility remains highly uncertain. Some analyses consider BHT
circuit-model infeasible in practice, making Grover the more realistic threat model
for hash functions in the near term.

---

## Common Mistakes

- Confusing Shor and Grover threats. Shor breaks asymmetric cryptography completely;
  Grover reduces symmetric security by half.
- Believing larger RSA/ECC keys provide quantum safety. They do not — Shor scales
  polynomially with key size.
- Believing AES-128 is quantum-safe. Under Grover it has only 64-bit effective security.
- Overlooking the HNDL threat for short-lived TLS sessions. HNDL matters for data
  confidentiality requirements, not session lifetime.
- Conflating "quantum computer exists" with "quantum computer breaks cryptography". A
  cryptographically relevant quantum computer (CRQC) requires millions of low-error-rate
  physical qubits; current machines are far from this.
