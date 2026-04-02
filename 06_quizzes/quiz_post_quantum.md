# Quiz: Post-Quantum Cryptography

15 multiple-choice questions covering quantum threats, lattice-based cryptography,
hash-based signatures, the Number Theoretic Transform, hybrid key exchange, and
NIST PQC migration strategies.

**Instructions:** Select the single best answer. Answers with explanations at the end.

---

## Questions

**Q1.** Shor's algorithm, run on a sufficiently large fault-tolerant quantum computer,
can break which of the following cryptographic schemes?

A) AES-256 symmetric encryption
B) SHA-3 hash functions
C) RSA-2048 public-key encryption
D) Argon2id password hashing

---

**Q2.** Grover's algorithm provides a quadratic speedup for unstructured search.
What is its practical effect on AES-128 security?

A) AES-128 becomes completely broken (0-bit security)
B) AES-128 security is reduced from 128 bits to 64 bits
C) AES-128 security is reduced from 128 bits to approximately 85 bits
D) AES-128 is unaffected because Grover's algorithm only applies to hash functions

---

**Q3.** The Learning With Errors (LWE) problem is computationally hard because:

A) It requires solving the discrete logarithm in a prime field
B) Distinguishing $(\mathbf{A}, \mathbf{As} + \mathbf{e})$ from a uniformly random
   matrix and vector is believed to be infeasible even for quantum computers
C) The lattice basis reduction algorithms (LLL/BKZ) run exponentially slower on quantum hardware
D) LWE is based on integer factoring with added Gaussian noise

---

**Q4.** ML-KEM (CRYSTALS-Kyber, FIPS 203) is a Key Encapsulation Mechanism.
Which role does the server play in a TLS-like key exchange using ML-KEM?

A) KeyGen: generates the public/private key pair
B) Encapsulate: uses the client's public key to produce a ciphertext and shared secret
C) Decapsulate: uses its private key to recover the shared secret from the ciphertext
D) Both A and C: the server generates the long-term key pair and decapsulates

---

**Q5.** In ML-DSA (CRYSTALS-Dilithium, FIPS 204), rejection sampling is used during
signing. What problem does rejection sampling solve?

A) It prevents the signer from ever using the same nonce twice
B) It ensures the signature distribution is independent of the secret key,
   preventing lattice attacks that could recover the secret from signatures
C) It reduces the signature size by discarding high-entropy components
D) It converts a deterministic signing algorithm into a probabilistic one for efficiency

---

**Q6.** SLH-DSA (SPHINCS+, FIPS 205) achieves post-quantum security based on:

A) The hardness of the Learning With Errors problem
B) The security of hash functions — specifically one-wayness and collision resistance
C) The difficulty of solving the Syndrome Decoding problem
D) The Module Short Integer Solution (MSIS) problem

---

**Q7.** XMSS (eXtended Merkle Signature Scheme) is described as a stateful signature
scheme. What does "stateful" mean in this context, and why is it dangerous?

A) Each key pair can only be used on one specific message; stateful means the key
   evolves with each use, and danger arises if the same state is reused
B) The verifier must maintain state between signature verifications
C) The public key changes with each signature, requiring the verifier to update it
D) Stateful means the private key is stored on a server, making it vulnerable to theft

---

**Q8.** The Number Theoretic Transform (NTT) reduces polynomial multiplication in
ML-KEM from $O(n^2)$ to $O(n \log n)$. Which property of the prime $q = 3329$ in
ML-KEM makes the NTT possible?

A) $q$ is a Mersenne prime, enabling fast modular reduction
B) $256 \mid (q - 1)$, so a primitive 256th root of unity exists in $\mathbb{Z}_q^*$
C) $q < 2^{16}$, so all arithmetic fits in a 16-bit register
D) $q$ is congruent to 3 mod 4, enabling the Tonelli-Shanks algorithm

---

**Q9.** HNDL (Harvest Now, Decrypt Later) is a threat model where an adversary:

A) Uses a quantum computer today to break AES-256 encrypted data in real time
B) Records encrypted classical communications now to decrypt them once a
   cryptographically-relevant quantum computer is available
C) Harvests public keys from certificates to derive private keys using Shor's algorithm
D) Exploits hash collisions in SHA-256 to forge digital signatures

---

**Q10.** In the X25519Kyber768 hybrid key exchange for TLS 1.3, why is the shared
secret formed by concatenating the X25519 output and the Kyber output rather than
XORing them?

A) Concatenation is faster to compute than XOR for 32-byte values
B) XOR of two secrets would be zero if an attacker can control one of the components;
   concatenation is secure if at least one component is computationally random
C) TLS 1.3 requires exactly 64 bytes of key material and neither 32-byte value alone
   is sufficient
D) Concatenation ensures that the combined secret has the same distribution as a
   uniform 64-byte string

---

**Q11.** Which NIST post-quantum signature standard is the best choice for use cases
that require extremely small public keys and signatures but can tolerate slow signing?

A) ML-DSA (CRYSTALS-Dilithium, FIPS 204)
B) SLH-DSA (SPHINCS+, FIPS 205)
C) FN-DSA (FALCON, FIPS 206)
D) XMSS (RFC 8391)

---

**Q12.** An organisation encrypts sensitive files today using RSA-4096 and stores them
for 20 years. A quantum computer capable of running Shor's algorithm at scale becomes
available in 2035. Which statement best describes the security of these files?

A) The files are secure because RSA-4096 has not been broken by classical computers
B) The files are at risk because Shor's algorithm would factor RSA-4096 in polynomial
   time on a sufficiently large quantum computer
C) The files are secure because 20-year-old encryption cannot be retroactively broken
D) The files are at risk only if the adversary has the original plaintext for comparison

---

**Q13.** In Kyber-768, the secret vector $\mathbf{s}$ has small coefficients drawn from
a centred binomial distribution. What would happen to security if $\mathbf{s}$ were
instead drawn from a uniform distribution over $\{0, \ldots, q-1\}$?

A) Security would improve because $\mathbf{s}$ would have higher entropy
B) Security would be unchanged because the hardness of MLWE does not depend on
   the secret distribution
C) The correctness of decryption would break down because large noise would overwhelm
   the message encoding
D) The NTT would no longer be applicable to the scheme

---

**Q14.** Dual-stack certificate deployment during PQC migration means:

A) Running two separate TLS servers — one with classical certificates and one
   with post-quantum certificates — behind a load balancer
B) Issuing a single X.509 certificate that contains both a classical (ECDSA)
   and a post-quantum (ML-DSA) public key
C) Issuing two separate certificates for the same entity — one classical and
   one post-quantum — and selecting between them based on client capability
D) Embedding the post-quantum public key in the X.509 Subject Alternative Name extension

---

**Q15.** The Fujisaki-Okamoto (FO) transform is applied to Kyber's base PKE scheme
to produce an IND-CCA2 secure KEM. What does this transform add?

A) A zero-knowledge proof that the ciphertext was honestly generated
B) Re-encryption of the decapsulated plaintext during decapsulation to verify
   ciphertext validity, rejecting malformed ciphertexts implicitly
C) A digital signature over the ciphertext to prevent modification
D) Randomisation of the encapsulation output using an external PRNG seed

---

## Answers and Explanations

**Q1. Answer: C — RSA-2048 public-key encryption**

Shor's algorithm solves integer factoring and the discrete logarithm problem in
polynomial time on a quantum computer. RSA security relies on the hardness of
factoring $n = p \times q$. Shor's algorithm factors RSA-2048 in $O((\log n)^3)$
quantum gate operations — completely breaking it.

AES-256 (A): Shor's algorithm does not apply to symmetric ciphers. The best quantum
attack on AES is Grover's algorithm, which gives a $2^{128}$ brute-force (not a break).
SHA-3 (B): Hash functions are not broken by Shor's; Grover halves the security margin
for preimage resistance but does not break SHA-3 with sufficient output length.
Argon2id (D): A password hashing function; not based on factoring or DLP.

---

**Q2. Answer: B — AES-128 security is reduced from 128 bits to 64 bits**

Grover's algorithm provides a quadratic speedup for exhaustive key search: an $n$-bit
key requires $O(2^{n/2})$ quantum operations instead of $O(2^n)$ classical operations.

For AES-128: $2^{128/2} = 2^{64}$ quantum operations.

The NIST response is to use AES-256 (which Grover reduces to $2^{128}$, still considered
secure). AES-128 with 64-bit effective security is insufficient for long-term protection.

Answer C (85 bits) has no basis — the quadratic speedup is exactly $2^{64}$, not some
other reduction. Answer D is wrong: Grover's algorithm applies to any exhaustive search,
including key search in symmetric ciphers.

---

**Q3. Answer: B — Distinguishing (A, As+e) from uniform is believed infeasible**

The LWE problem: given a matrix $\mathbf{A} \in \mathbb{Z}_q^{m \times n}$ drawn
uniformly and a vector $\mathbf{b} = \mathbf{As} + \mathbf{e}$ where $\mathbf{s}$
is a secret and $\mathbf{e}$ is a small noise vector, distinguish $(\mathbf{A},
\mathbf{b})$ from a uniformly random pair.

The hardness of this problem is believed to hold even against quantum computers, unlike
factoring and DLP. No sub-exponential quantum algorithm for LWE is known; the best
attacks are lattice-based (BKZ algorithm) and run in $2^{O(n)}$ time.

Answer A: LWE is not based on DLP. Answer C: BKZ is a classical algorithm, and its
quantum speedups are modest (polynomial, not exponential). Answer D: LWE is unrelated
to integer factoring.

---

**Q4. Answer: B — Encapsulate: uses the client's public key**

In a TLS-like deployment with ML-KEM, roles are:

- **Client**: runs KeyGen, sends the public key in ClientHello.
- **Server**: runs Encapsulate on the client's public key, producing ciphertext
  (sent to client in ServerHello) and shared secret (kept by server).
- **Client**: runs Decapsulate on the server's ciphertext using its private key to
  recover the shared secret.

This mirrors the DH pattern: the client generates the long-term KEM key pair (or
ephemeral), and the server "encapsulates" (analogous to selecting and encrypting a
pre-master secret in RSA key exchange).

Answer D would describe the server as doing both key generation and decapsulation,
but in this model the client generates the key pair, not the server.

---

**Q5. Answer: B — Ensures signature distribution is independent of the secret key**

Without rejection sampling, the distribution of Dilithium signatures would leak
information about the secret key $\mathbf{s}$. The signing algorithm:

1. Commits to a random vector $\mathbf{y}$
2. Computes a candidate response $\mathbf{z} = \mathbf{y} + c\mathbf{s}$ (where $c$
   is the challenge)
3. **Rejects** if $\mathbf{z}$ is too large (would leak info about $\mathbf{s}$)
4. Repeats until a valid $\mathbf{z}$ is found

The output distribution of accepted $\mathbf{z}$ values is statistically close to
a distribution that does not depend on $\mathbf{s}$ — making lattice attacks from
signatures infeasible.

Answer A: rejection sampling prevents correlation with the secret but does not prevent
nonce reuse; nonce uniqueness is a separate concern. Answer C: rejected values are
discarded entirely, not reused. Answer D: Dilithium with rejection sampling is already
probabilistic even from a deterministic nonce.

---

**Q6. Answer: B — Security of hash functions**

SLH-DSA (SPHINCS+) is a stateless hash-based signature scheme. Its security reduces
entirely to properties of the underlying hash function (SHA-256, SHAKE256, or Haraka):
- **One-wayness** for Winternitz OTS (W-OTS+) chains
- **Pseudorandomness** for key generation
- **Second-preimage resistance** for the Merkle tree construction
- **Collision resistance** for the FORS (Forest of Random Subsets) component

No algebraic structure (lattices, codes, isogenies) is required — this makes SPHINCS+
the most conservative PQC scheme: it will be secure as long as SHA-256 or SHAKE256 is
secure.

Answer A (LWE): ML-KEM and ML-DSA. Answer C (Syndrome Decoding): Classic McEliece.
Answer D (MSIS): ML-DSA (Dilithium) uses MSIS for unforgeability.

---

**Q7. Answer: A — The private key evolves with each use; reusing a state recovers the key**

XMSS uses one-time signature (OTS) keys internally. Each leaf of the Merkle tree is
a W-OTS+ one-time key pair. The signer must track which leaves have been used and
never reuse one. The state is the index of the next unused leaf.

If the same OTS key is used to sign two different messages, an attacker can combine
the two signatures to reconstruct the OTS private key — forging arbitrary signatures
for that leaf.

Dangerous scenarios: VM snapshots, backup restoration, hardware faults that reset the
counter. XMSS is suitable only for systems with reliable, tamper-evident state storage.

SPHINCS+ is the stateless alternative: it derives the OTS key index from a random
value included in the signature, sacrificing signature size for statelessness.

---

**Q8. Answer: B — $256 \mid (q - 1)$**

For an NTT of length $n$ to exist in $\mathbb{Z}_q$, a primitive $n$-th root of unity
must exist, which requires $n \mid (q - 1)$ (by Lagrange's theorem applied to the
cyclic group $\mathbb{Z}_q^*$ of order $q-1$).

For ML-KEM with $n = 256$ and $q = 3329$:
$q - 1 = 3328 = 256 \times 13$.
So $256 \mid 3328$. ✓

The primitive root $\zeta$ with $\text{ord}(\zeta) = 256$ satisfies $\zeta^{128} \equiv
-1 \pmod{3329}$, enabling the negacyclic NTT required for $R_q = \mathbb{Z}_q[X]/(X^{256}+1)$.

Answer A: $q = 3329$ is not a Mersenne prime ($2^k - 1$ form). Answer C: fitting in
16 bits helps with implementation but does not enable the NTT. Answer D: the Tonelli-Shanks
algorithm is for square roots, unrelated to NTT existence.

---

**Q9. Answer: B — Records encrypted communications now to decrypt later with a quantum computer**

The HNDL threat motivates urgent deployment of post-quantum key exchange even before
large-scale quantum computers exist. Data with long confidentiality requirements (state
secrets, medical records, intellectual property) encrypted today with X25519/RSA could
be retroactively decrypted when quantum computers become available.

The timeline concern: if quantum computers capable of breaking RSA/ECC become available
in 10–15 years, any data encrypted today using classical KEMs that must remain secret
for 15+ years is already at risk.

Answer A is wrong: current quantum computers cannot break AES-256 in real time or any
reasonable timeframe (billions of logical qubits with low error rates would be needed).
Answer C is wrong: HNDL does not require public key derivation attacks in real time.
Answer D is wrong: SHA-256 collision resistance is not broken by current quantum algorithms.

---

**Q10. Answer: B — Concatenation is secure if at least one component is computationally random**

The hybrid security proof: let $X$ be the X25519 shared secret and $K$ be the Kyber
shared secret. The combined secret is $\text{HKDF}(X \| K)$.

- If X25519 is secure (adversary cannot distinguish $X$ from random), the HKDF output
  is pseudorandom regardless of $K$.
- If ML-KEM is secure (adversary cannot distinguish $K$ from random), the HKDF output
  is pseudorandom regardless of $X$.
- The adversary must break **both** schemes simultaneously to distinguish the output.

XOR would work too in principle: $X \oplus K$ is a one-time-pad-like construction if
one component is random. However, if an adversary could set one component to zero (e.g.,
by sending a malformed ciphertext), XOR would reveal the other. Concatenation followed
by HKDF avoids this: HKDF's extraction of both components into one key is secure even
if one is adversarially controlled, as long as the other has enough entropy.

Answer C is wrong: HKDF can output any desired length regardless of input size.
Answer D is wrong: the concatenation is not uniformly distributed over 64 bytes; it
is two 32-byte pseudorandom outputs concatenated.

---

**Q11. Answer: C — FN-DSA (FALCON, FIPS 206)**

FALCON (Fast Fourier Lattice-based Compact Signatures over NTRU) produces the smallest
signatures among NIST PQC signature standards:

| Scheme    | Public key | Signature | Signing speed |
|-----------|-----------|-----------|---------------|
| ML-DSA-44 | 1312 bytes | 2420 bytes | Fast          |
| SLH-DSA-128s | 32 bytes | 7856 bytes | Very slow   |
| FN-DSA-512 | 897 bytes | 666 bytes | Moderate (needs CDT sampler) |

FALCON's NTRU-based lattice structure enables compact signatures at the cost of a
complex constant-time Gaussian sampler (CDT or Falcon sampler) that is difficult to
implement securely.

Answer B (SLH-DSA): has very small public keys (32 bytes) but very large signatures
(7–50 KB depending on parameter set) and very slow signing. Answer A (ML-DSA) has
faster signing but larger signatures. Answer D (XMSS): has small signatures but is
stateful, limiting its applicability.

---

**Q12. Answer: B — The files are at risk because Shor's algorithm breaks RSA**

RSA-4096 provides larger classical security than RSA-2048, but Shor's algorithm breaks
RSA in polynomial time regardless of key size (albeit requiring more qubits for larger
keys). Once a cryptographically relevant quantum computer exists, RSA-4096 is no safer
than RSA-2048 from a quantum perspective — both are broken in polynomial time.

The 20-year retention period combined with a projected ~10-15 year timeline for
quantum computers creates an urgent requirement to re-encrypt or move to quantum-safe
encryption for long-lived sensitive data.

Answer A is wrong: classical security is irrelevant to quantum threats. Answer C is
wrong: there is no technical barrier to retroactively decrypting stored ciphertext.
Answer D (known-plaintext comparison) is irrelevant — Shor's algorithm recovers the
private key directly from the public key.

---

**Q13. Answer: C — Large noise would overwhelm the message encoding**

In Kyber, correctness of decryption requires that the decryption noise
$e_\text{total} = \mathbf{e}^T\mathbf{r} + e_2 - \mathbf{s}^T\mathbf{e}_1$
is small relative to $q/4$ (the message encoding threshold). If $\mathbf{s}$ were
uniform over $\mathbb{Z}_q$, the term $\mathbf{s}^T\mathbf{e}_1$ could be as large
as $\sim k \cdot n \cdot q/2$, which would dwarf the message component and cause
incorrect decryption with high probability.

Small secrets are essential for correctness. Fortunately, Regev's proof shows LWE
is as hard with small secrets as with uniform secrets (a "secret is small" reduction),
so using small secrets does not reduce security.

Answer A is wrong: although uniform secrets have higher entropy, correctness breaks.
Answer B is partially true (security is equivalent under reduction) but the question
asks what would happen operationally. Answer D: NTT operates on the polynomial
structure, not the secret distribution.

---

**Q14. Answer: C — Two separate certificates: one classical, one post-quantum**

Dual-stack certificate deployment issues two independent X.509 certificates for the
same server:
1. A classical ECDSA/RSA certificate (for legacy clients)
2. A post-quantum ML-DSA certificate (for PQ-capable clients)

The server presents one or both during the TLS handshake. The client selects based
on its supported signature algorithms list. This approach allows gradual migration
without breaking compatibility.

Answer B describes a composite certificate — a single certificate embedding both key
types — which is a different (and less widely deployed) approach being standardised
separately (draft-ietf-lamps-pq-composite-sigs). Answer A (two separate servers) is
an operational approach but not the meaning of "dual-stack certificates."
Answer D: embedding a PQ public key in SAN is not a standard approach.

---

**Q15. Answer: B — Re-encryption during decapsulation to verify ciphertext validity**

The Fujisaki-Okamoto transform converts an IND-CPA secure PKE scheme into an IND-CCA2
secure KEM. In Kyber's FO transform, the Decapsulate algorithm:

1. Recovers the message $m'$ using the private key
2. Re-encrypts $m'$ to produce $c' = \text{Encrypt}(pk, m'; H(m'))$ (deterministic,
   using the hash of $m'$ as randomness)
3. Compares $c'$ to the received ciphertext $c$

If $c' \neq c$, the ciphertext is malformed — the decapsulation outputs an implicit
rejection value $\text{PRF}(z, c)$ instead of the real shared secret. This prevents
an IND-CCA2 adversary from using decapsulation as a decryption oracle, because
manipulated ciphertexts produce pseudorandom (unpredictable) output.

Answer A: FO uses re-encryption, not zero-knowledge proofs. Answer C: FO does not add
a digital signature. Answer D: the randomness in encapsulation comes from hashing the
message, not an external PRNG seed — this is the "derandomisation" aspect of FO.
