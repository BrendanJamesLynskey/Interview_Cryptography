# Lattice-Based Cryptography: CRYSTALS-Kyber and CRYSTALS-Dilithium

## Prerequisites
- Linear algebra: vectors, matrices, inner products
- Modular arithmetic
- Basic probability theory
- `quantum_threat.md` — understanding of why classical algorithms break under Shor's
- Public-key cryptography fundamentals: key encapsulation, digital signatures

---

## Concept Reference

### Lattice Problems: The Hardness Foundation

A lattice is a discrete additive subgroup of R^n — the set of all integer linear
combinations of a set of basis vectors. Given basis vectors b_1, ..., b_n in R^n:

```
L = { a_1*b_1 + a_2*b_2 + ... + a_n*b_n : a_i in Z }
```

Two canonical hard problems on lattices form the basis for post-quantum cryptography:

**Shortest Vector Problem (SVP):** Given a lattice basis, find the shortest non-zero
vector in the lattice. Believed to require exponential time even on quantum computers.

**Closest Vector Problem (CVP):** Given a lattice basis and a target point t, find the
lattice vector closest to t. At least as hard as SVP.

Modern lattice-based schemes use structured lattice problems that are more efficient but
retain the hardness properties.

---

### Learning With Errors (LWE)

LWE, introduced by Regev (2005), is the hardness assumption underlying Kyber and
Dilithium.

**LWE problem:** Given a random matrix A in Z_q^(m x n), a secret vector s in Z_q^n,
and a small error vector e in Z_q^m sampled from an error distribution chi (typically
discrete Gaussian), distinguish the pair (A, b = As + e mod q) from a uniform random
pair (A, b).

```
Parameters:
  n    -- lattice dimension (security parameter)
  q    -- modulus (typically a prime)
  chi  -- error distribution (Gaussian with small standard deviation sigma)
  m    -- number of samples

Key intuition: if e = 0, recovering s from (A, b=As) is easy (solve linear system).
The small error e makes the system computationally hard to solve -- the error is too
small to ignore but large enough to obscure s.
```

**Module-LWE (MLWE):** Kyber and Dilithium use MLWE, which operates over polynomial
rings rather than plain integers, providing better efficiency:

```
Ring: R_q = Z_q[X] / (X^n + 1)   where n is a power of 2 (n=256 in Kyber)

MLWE: Given matrix A in R_q^(k x k), secret s in R_q^k, error e in R_q^k
      (all elements are degree-(n-1) polynomials mod q)
      distinguish (A, b = As + e) from uniform
```

Working in the polynomial ring R_q reduces key sizes from O(n^2) for plain LWE to
O(k^2) polynomial elements (each of degree n-1), giving efficient implementations.

---

### CRYSTALS-Kyber (ML-KEM, FIPS 203)

Kyber is a Key Encapsulation Mechanism (KEM). A KEM provides three operations:
- **KeyGen:** Generate a public/private key pair
- **Encapsulate:** Using the public key, produce a ciphertext and a shared secret
- **Decapsulate:** Using the private key and ciphertext, recover the shared secret

**Kyber parameter sets:**

```
Variant          k   q      n    eta_1  eta_2  du  dv  Security level
------------     --  -----  ---  -----  -----  --  --  --------------
Kyber-512        2   3329   256  3      2      10  4   NIST Level 1 (~AES-128)
Kyber-768        3   3329   256  2      2      10  4   NIST Level 3 (~AES-192)
Kyber-1024       4   3329   256  2      2      11  5   NIST Level 5 (~AES-256)

k: module rank (number of polynomials in vectors/matrices)
q: prime modulus (3329 = 13 * 256 + 1, chosen for NTT efficiency)
n: polynomial degree (256)
eta: CBD (Centered Binomial Distribution) parameter for error sampling
du, dv: compression bit widths for ciphertext
```

**Kyber KeyGen:**

```
1. Generate random seed rho (for matrix A) and sigma (for secret)
2. Expand rho to matrix A in R_q^(k x k) using XOF (SHAKE-128)
3. Sample secret vector s in R_q^k from CBD_eta1  (small coefficients)
4. Sample error vector e in R_q^k from CBD_eta1
5. Compute public key: t = A*s + e  (polynomial matrix-vector product in R_q)
6. Public key:  (rho, t)
   Private key: (s, H(pk), z)  where z is a random rejection fallback seed

Sizes for Kyber-768:
  Public key:  1184 bytes  (k * 384 + 32)
  Private key: 2400 bytes  (includes decapsulation key material)
```

**Kyber Encapsulation:**

```
Input: public key (rho, t), random message m in {0,1}^256
1. Expand rho to A (same generation as KeyGen)
2. Sample random vector r in R_q^k from CBD_eta1
3. Sample error vectors e1 in R_q^k, e2 in R_q from CBD_eta2
4. Compute: u = A^T * r + e1        (vector in R_q^k)
5. Compute: v = t^T * r + e2 + Decompress_q(m, 1)
              where Decompress_q(m, 1) encodes each bit of m as 0 or round(q/2)
6. Compress and output:
     c = ( Compress_q(u, du),  Compress_q(v, dv) )
7. Shared secret: K = H(m || H(pk))
   (Kyber uses FO transform; K is derived deterministically from m)

Ciphertext size for Kyber-768:  1088 bytes
Shared secret:                   32 bytes
```

**Kyber Decapsulation:**

```
Input: private key s, ciphertext c = (u_compressed, v_compressed)
1. Decompress u and v to recover approximate values
2. Compute: m' = Compress_q( v - s^T * u , 1 )
   Correctness argument:
     v - s^T * u
     = (t^T*r + e2 + msg_enc) - s^T*(A^T*r + e1)
     = (A*s + e)^T*r + e2 + msg_enc - s^T*A^T*r - s^T*e1
     = s^T*A^T*r + e^T*r + e2 + msg_enc - s^T*A^T*r - s^T*e1
     = msg_enc + (e^T*r + e2 - s^T*e1)
                  ^^^^^^^^^^^^^^^^^^^^ small error term
   Rounding via Compress_q removes the small error and recovers m' = m.
3. Re-encrypt m' to get c'  (using the stored pk)
4. If c' == c: output K = H(m' || H(pk))
   If c' != c: output K = H(z || c)  where z is the secret fallback seed
   (the implicit rejection prevents decryption failure oracle attacks)
```

**Key and ciphertext sizes:**

```
Variant       Public key   Private key   Ciphertext   Shared secret
----------    ----------   -----------   ----------   -------------
Kyber-512     800 bytes    1632 bytes    768 bytes    32 bytes
Kyber-768     1184 bytes   2400 bytes    1088 bytes   32 bytes
Kyber-1024    1568 bytes   3168 bytes    1568 bytes   32 bytes

For comparison:
X25519 (ECDH)    32 bytes     32 bytes       32 bytes     32 bytes
RSA-2048        256 bytes   ~2349 bytes     256 bytes    32 bytes (OAEP)
```

**IND-CCA2 security:** Kyber achieves IND-CCA2 (indistinguishability under adaptive
chosen-ciphertext attack) security via the Fujisaki-Okamoto (FO) transform. The FO
transform converts an IND-CPA secure scheme into IND-CCA2 by:
- Derandomising encapsulation (r is derived from m and pk, not chosen independently)
- Re-encrypting during decapsulation to detect tampering
- Returning a pseudorandom value on failure rather than an error code

---

### CRYSTALS-Dilithium (ML-DSA, FIPS 204)

Dilithium is a digital signature scheme based on the "Fiat-Shamir with Aborts"
paradigm applied to Module-LWE/SIS.

**Dilithium parameter sets:**

```
Variant         k   l   q         n    eta  gamma1   gamma2   tau  Security
----------      --  --  -------   ---  ---  -------  -------  ---  --------
Dilithium2      4   4   8380417   256  2    2^17     95232    39   NIST Level 2
Dilithium3      6   5   8380417   256  4    2^19     261888   49   NIST Level 3
Dilithium5      8   7   8380417   256  2    2^19     261888   60   NIST Level 5

k, l: matrix dimensions (A is k x l, vectors are sized accordingly)
q = 8380417 = 2^23 - 2^13 + 1 (prime; chosen so 2^13 | (q-1) for NTT)
eta: infinity-norm bound on secret key polynomial coefficients
gamma1: masking vector y coefficient bound
gamma2: low-order rounding parameter
tau: number of +/-1 coefficients in the challenge polynomial c
```

**Dilithium Key Generation:**

```
1. Generate random seed rho
2. Expand rho to matrix A in R_q^(k x l) using SHAKE-128
3. Sample secret vectors s1 in R_q^l, s2 in R_q^k
   (all coefficients in {-eta, ..., eta})
4. Compute t = A*s1 + s2
5. Split t into high and low bits: (t1, t0) = Power2Round(t, d)
   where t1 = high bits, t0 = low bits of t coefficients
6. Public key:  (rho, t1)            -- 1952 bytes for Dilithium3
   Private key: (rho, K, tr, s1, s2, t0)  -- 4000 bytes for Dilithium3
   tr = H(pk)  (used as a message nonce in signing)
```

**Dilithium Sign:**

```
Input: message M, private key

1. Compute mu = H(tr || M)    where tr = H(pk)
2. Set kappa = 0, repeat:
   a. Derive nonce using K and kappa; sample masking vector y in R_q^l
      with all coefficients in (-gamma1, gamma1)
   b. Compute w = A*y
   c. Compute w1 = HighBits(w, 2*gamma2)
   d. Compute challenge seed: c_tilde = H(mu || w1)
   e. Expand c_tilde to sparse challenge polynomial c
      (exactly tau coefficients are +/-1, rest are 0)
   f. Compute response: z = y + c*s1
   g. Check rejection conditions:
        - If ||z||_inf >= gamma1 - beta: reject  (z too large, leaks s1)
        - If ||LowBits(w - c*s2)||_inf >= gamma2 - beta: reject
   h. Compute hint vector h (one bit per coefficient, indicating rounding)
   i. If h has too many 1-bits: reject
   j. Increment kappa, loop if rejected
3. Signature: sigma = (c_tilde, z, h)   -- 3293 bytes for Dilithium3
```

**Why rejection sampling is necessary:** z = y + c*s1 must not reveal s1. If z had
a distribution correlated with s1, an attacker could collect many (c_i, z_i) pairs and
solve for s1 via a lattice attack. Rejection sampling ensures that only z values with
all coefficients in a safe range are output, making the z distribution statistically
independent of s1.

**Dilithium Verify:**

```
Input: message M, signature (c_tilde, z, h), public key (rho, t1)

1. Expand A from rho  (deterministic, same as KeyGen)
2. Compute tr = H(pk), mu = H(tr || M)
3. Expand c from c_tilde  (sparse polynomial)
4. Compute: w'_1 = UseHint(h, A*z - c*t1 * 2^d)
   (t1*2^d re-inflates the compressed public key; the result approximates w)
5. Recompute: c'_tilde = H(mu || w'_1)
6. Accept iff c'_tilde == c_tilde  AND  ||z||_inf < gamma1 - beta
```

**Signature sizes:**

```
Variant         Public key   Private key   Signature
----------      ----------   -----------   ---------
Dilithium2      1312 bytes   2528 bytes    2420 bytes
Dilithium3      1952 bytes   4000 bytes    3293 bytes
Dilithium5      2592 bytes   4864 bytes    4595 bytes

For comparison:
ECDSA P-256      64 bytes     32 bytes       64 bytes  (DER ~72 bytes)
RSA-2048        256 bytes   ~1193 bytes     256 bytes
Ed25519          32 bytes     64 bytes       64 bytes
```

---

### Number Theoretic Transform (NTT)

Both Kyber and Dilithium perform polynomial multiplication in R_q = Z_q[X]/(X^n + 1).
Direct (schoolbook) polynomial multiplication is O(n^2). The NTT achieves O(n log n).

```
Why NTT works for Kyber:
  q = 3329, n = 256
  zeta = 17 is a primitive 512th root of unity mod 3329
    (17^256 = -1 mod 3329, so 17^512 = 1 mod 3329)

Forward NTT (Cooley-Tukey butterfly, bit-reversed order):
  NTT(f)[i] = sum_{j=0}^{255} f[j] * zeta^{(2*br(i)+1)*j}  mod 3329
  where br() is the bit-reversal of the index

Multiplication of polynomials f, g in R_q:
  (f * g) = INTT( NTT(f) o NTT(g) )
  where o = pointwise multiplication mod q

Cost comparison for n=256:
  Schoolbook:   256^2  = 65,536 multiplications mod q
  NTT-based:   3 * 256 * 8 = ~6,144 multiplications mod q  (roughly)
               (2 NTTs + 1 INTT, each O(n log n))
```

The q values in both Kyber and Dilithium are specifically chosen to support the NTT:
the requirement is that a 2n-th root of unity exists in Z_q, which requires (2n) | (q-1).
For Kyber: 512 | 3328 (3328 = 512 * 6 + 256... actually 3329 - 1 = 3328 = 2^6 * 52,
and 256 | 3328 since 3328/256 = 13). For Dilithium: 8380416 = 2^23 - 2^13 is divisible
by 512.

---

### Security Reductions

```
Kyber IND-CCA2 security (ROM):
  Breaking Kyber  =>  Breaking MLWE  =>  Solving worst-case SVP on module lattices

Dilithium EUF-CMA security (ROM):
  Breaking Dilithium  =>  Breaking MLWE or MSIS
  (Module Short Integer Solution: given A, find short s != 0 such that As = 0 mod q)

Best known quantum attacks on MLWE/MSIS:
  - Quantum lattice sieve algorithms (e.g., BDGL) achieve O(2^{0.265n}) time
  - At n=256 with k=3 (Kyber-768): concrete security estimated ~180 bits quantum
  - Substantially harder than breaking AES-128 (2^64 quantum via Grover)
```

---

## Interview Questions

### Fundamentals

**Q1.** What is a Key Encapsulation Mechanism (KEM) and how does it differ from
traditional public-key encryption?

**Answer:**

A KEM establishes a shared secret rather than encrypting arbitrary data. It provides
three operations: KeyGen, Encapsulate, and Decapsulate. Encapsulate takes a public key
and outputs a ciphertext plus a uniformly random shared secret; Decapsulate recovers that
same shared secret from the ciphertext using the private key.

Traditional public-key encryption (e.g., RSA-OAEP) encrypts an arbitrary plaintext
directly under the public key. In practice this is inefficient for large messages and has
complex padding requirements. A KEM + DEM (Data Encapsulation Mechanism) construction
uses the KEM only for a 32-byte symmetric key, then encrypts the actual message with
AES-GCM or ChaCha20-Poly1305. This separation of concerns gives cleaner security proofs
and avoids the pitfalls of padding oracle attacks.

For Kyber: it is exclusively a KEM. Attempting to encrypt data directly with Kyber
is not how the scheme is designed. Use Kyber to establish a 32-byte key, then use that
key with a symmetric cipher.

---

**Q2.** Explain intuitively why the Learning With Errors (LWE) problem is hard, and
why the error term is essential.

**Answer:**

LWE asks: given (A, b = As + e), recover s. The linear system As = b is easy to invert
with Gaussian elimination (polynomial time). The error e makes this an approximate linear
system — no exact solution exists, so exact linear algebra fails.

Finding s requires solving the Closest Vector Problem on the lattice generated by the
columns of A: b = As + e means b is a lattice point As displaced by a small vector e.
CVP is believed exponentially hard.

Without e: the system is exactly solvable in O(n^3) operations. LWE is entirely broken.
With e too large: rounding during decryption fails to recover the message (decryption
errors occur). With e too small: the LWE samples are not statistically close to uniform,
allowing distinguishing attacks. The error distribution is tuned to satisfy both
correctness (decryption succeeds) and security (looks random).

---

### Intermediate

**Q3.** Why does Dilithium use rejection sampling during signing, and what attack does
it prevent?

**Answer:**

Dilithium computes z = y + c*s1 where y is a fresh random mask, c is the challenge
derived from the message, and s1 is the signing key. z must be output as part of the
signature, making it public.

Without rejection sampling, an attacker collecting signatures (c_1, z_1), (c_2, z_2),
... can form: z_i - z_j = (y_i - y_j) + (c_i - c_j)*s1. Since y values are uniform
over a known range and the differences c_i - c_j are known from the signatures, this is
a system of linear equations in s1 over R_q. With enough samples, a lattice basis
reduction attack (BKZ) recovers s1.

Rejection sampling enforces the condition ||z||_inf < gamma1 - beta. This means only
z values that fall within a strict bound are output. A z vector satisfying this bound
has a distribution that is statistically close to uniform over the bounded range,
independent of s1's value. The attacker's equations are no longer informative.

The cost is that some iterations are rejected and the loop repeats. For Dilithium3, the
expected number of iterations is approximately 5, so the expected signing cost is about
5 iterations on average. Rejection is unpredictable from the outside, which also means
implementations must handle variable-time loops carefully (see side-channel concerns).

---

**Q4.** Compare Kyber-768 and X25519 on key sizes, security, and practical deployment.
When would you use each?

**Answer:**

```
Property           Kyber-768          X25519
--------------     ---------          ------
Security model     MLWE (quantum-hard) ECDLP (broken by Shor)
Quantum security   ~Level 3 (~AES-192) ~50 bits (Shor applies)
Public key         1184 bytes          32 bytes
Private key        2400 bytes          32 bytes
Ciphertext         1088 bytes          32 bytes
Shared secret      32 bytes            32 bytes
Standardisation    FIPS 203 (2024)     RFC 7748 (2016)
```

Deployment considerations for Kyber-768:
- Ciphertext is ~34x larger than X25519's DH share. TLS ClientHello/ServerHello grow
  by ~2 KB. This is measurable but not problematic for most connections.
- Certificate stores, protocol parsers, and HSMs must be updated to handle larger keys.
- Available in OpenSSL 3.x, BoringSSL, and most modern TLS stacks.

Use X25519 only for: short-lived data where HNDL is not a concern, legacy systems that
cannot be updated, or environments where the extra ~2 KB is genuinely prohibitive
(e.g., extremely constrained IoT radio links).

Use Kyber-768 (or X25519Kyber768 hybrid) for: any new system, government/regulated
sectors, systems handling long-lived confidential data, and TLS 1.3 key exchange where
HNDL-resistant forward secrecy is required.

---

### Advanced

**Q5.** Explain how the Fujisaki-Okamoto (FO) transform upgrades Kyber from IND-CPA
to IND-CCA2, and why IND-CCA2 is necessary in practice.

**Answer:**

IND-CPA secures against passive adversaries who only observe ciphertexts. Real protocols
(TLS, SSH, email) expose decryption oracles: a server attempting decapsulation with a
tampered ciphertext will behave differently from one that succeeds, leaking information.
IND-CCA2 security protects against adversaries who can submit arbitrary ciphertexts for
decapsulation (other than the challenge itself).

The FO transform applied to Kyber:

1. **Derandomisation:** In standard Kyber, encapsulation samples r from the error
   distribution. In Kyber-CCA2, r is derived as r = PRF(m, pk) deterministically from
   the message m and public key. Encapsulation is now fully determined by m.

2. **Re-encryption check:** Decapsulation recovers m', then re-runs encapsulation to
   produce c'. If c' != c (indicating tampering or a malformed ciphertext), the
   scheme returns K = PRF(z, c) where z is a secret seed, rather than an error signal.

3. **Implicit rejection:** The mismatch path returns a pseudorandom value derived from
   z (a secret). This prevents a selective-failure attack: without this, an adversary
   could submit modified ciphertexts, observe which ones cause genuine decapsulation
   failures vs. accepted ciphertexts, and use the oracle to recover the private key bit
   by bit.

Security proof: Under the ROM (random oracle model), if the underlying IND-CPA scheme
is secure, Kyber-CCA2 is IND-CCA2 secure. The FO transform is proven secure through
a tight reduction to MLWE in the quantum random oracle model (QROM), which is important
because adversaries in the post-quantum setting can make quantum queries to the hash
function oracles.

---

**Q6.** A firmware engineer notices Dilithium signing loops variably. What side-channel
risk does this introduce, and how should a correct implementation mitigate it?

**Answer:**

The rejection sampling loop runs until z satisfies ||z||_inf < gamma1 - beta and the
hint constraints are met. Each rejection event is slightly more likely for certain
values of the private key because the rejection condition depends on z = y + c*s1. An
attacker measuring the number of signing iterations across many signing operations
observes a distribution whose mean and variance are weakly correlated with s1.

In practice: Ravi et al. (2019) demonstrated a timing side-channel on Dilithium where
the iteration count, observable through power analysis or precise timing measurement,
leaked enough information about s1 to recover it within a feasible attack budget.

Correct mitigations:

1. **Fixed iteration count:** Always execute exactly max_iterations (e.g., 16) inner
   loop bodies regardless of when a valid signature is found. Accept the result from
   the first successful iteration and dummy-execute the rest. This makes iteration count
   constant.

2. **Constant-time rejection check:** The decision of whether to accept or reject must
   not cause observable control-flow divergence. Use constant-time comparison and
   conditional move (CMOV) instructions rather than early exits.

3. **Masking s1 and s2:** Apply arithmetic masking (secret sharing) to s1 before
   computing z = y + c*s1. Split s1 = s1_share_0 + s1_share_1 and operate on shares
   independently, recombining only at the final output stage.

4. **Hardware security:** Use a dedicated cryptographic coprocessor with physical
   isolation and power-analysis countermeasures for keys in high-assurance environments.

---

## Common Mistakes

- Treating Kyber as a drop-in replacement for RSA encryption. Kyber is a KEM; combine
  it with AES-256-GCM for actual data encryption.
- Confusing Kyber and Dilithium. Kyber handles key exchange (like ECDH). Dilithium
  handles digital signatures (like ECDSA). They are different algorithms.
- Ignoring larger key and ciphertext sizes. A full Kyber-768 key exchange adds ~2 KB
  to a TLS handshake. Protocol buffers and parsers must accommodate this.
- Skipping the FO transform. Kyber without FO provides only IND-CPA security, which
  is broken by a simple decryption oracle attack in TLS-like settings.
- Underestimating NTT implementation complexity. Correct NTT requires Montgomery
  reduction, Barrett reduction, and careful bit-reversal permutation. Off-by-one errors
  in the butterfly ordering produce silently incorrect but plausible-looking outputs.
- Forgetting that Dilithium signing is variable-time by design; naive implementations
  are vulnerable to side-channel attacks.
