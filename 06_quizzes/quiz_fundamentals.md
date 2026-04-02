# Quiz: Cryptography Fundamentals

15 multiple-choice questions covering symmetric encryption, hash functions, MACs,
digital signatures, and random number generation.

**Instructions:** Select the single best answer for each question. Answers with
explanations are at the end of this file.

---

## Questions

**Q1.** AES-128 encrypts a 16-byte block using how many rounds?

A) 8
B) 10
C) 12
D) 14

---

**Q2.** Which of the following is the ONLY non-linear transformation in the AES round function?

A) ShiftRows
B) MixColumns
C) SubBytes
D) AddRoundKey

---

**Q3.** A message is encrypted with AES-CBC. The IV is reused across two encryptions of messages
that share a common prefix. What information does an attacker learn?

A) Nothing; reusing an IV with CBC only affects confidentiality of the last block
B) The length of the longer message's suffix
C) The XOR of the two plaintexts up to the point where they first differ
D) The AES key

---

**Q4.** Which AES mode of operation converts a block cipher into a stream cipher by
encrypting a counter?

A) ECB
B) CBC
C) CTR
D) OFB

---

**Q5.** SHA-256 produces a 256-bit digest. The birthday attack finds a collision in
approximately how many hash operations?

A) $2^{256}$
B) $2^{128}$
C) $2^{64}$
D) $2^{32}$

---

**Q6.** An HMAC is computed as $\text{HMAC}(K, M) = H((K \oplus \text{opad}) \| H((K \oplus \text{ipad}) \| M))$.
Why is the two-level construction used instead of simply $H(K \| M)$?

A) The two-level construction is faster on hardware with two hash engines
B) $H(K \| M)$ is vulnerable to length extension attacks on Merkle-Damgard hash functions
C) The two-level construction provides message authentication with a shorter tag
D) HMAC was designed to work only with MD5 and requires nesting

---

**Q7.** RSA-OAEP is used instead of textbook RSA (direct modular exponentiation) for encryption.
What does OAEP add?

A) A larger key size to prevent brute-force attacks
B) Randomness and redundancy that provides semantic security and prevents padding oracles
C) Support for encrypting messages longer than the modulus
D) A digital signature scheme combined with encryption

---

**Q8.** Which property of a hash function ensures that given a hash output $h$, it is
computationally infeasible to find ANY message $m$ such that $H(m) = h$?

A) Collision resistance
B) Second-preimage resistance
C) Preimage resistance
D) Length extension resistance

---

**Q9.** AES-GCM is an AEAD cipher. What does "AEAD" provide that AES-CBC does NOT?

A) Confidentiality of the plaintext
B) A longer authentication tag than CBC
C) Both confidentiality and integrity/authentication in a single pass
D) Resistance to timing side-channel attacks

---

**Q10.** An ECDSA signature consists of two values $(r, s)$. If the nonce $k$ used during
signing is reused across two signatures on different messages, what can an attacker recover?

A) Only the message hash
B) The signature verification key (public key)
C) The signing key (private key)
D) The hash function used

---

**Q11.** Which of the following is TRUE about the difference between a MAC and a digital signature?

A) Both MACs and digital signatures provide non-repudiation
B) A MAC requires a shared symmetric key; a digital signature does not require a pre-shared secret
C) Digital signatures are always faster to compute than MACs
D) MACs provide public verifiability; signatures do not

---

**Q12.** A CSPRNG is seeded with 128 bits of entropy from a hardware TRNG. An adversary
who knows the PRNG algorithm but not the seed tries to predict future outputs.
What is the effective security level?

A) 0 bits — the PRNG output is deterministic once the algorithm is known
B) 64 bits — the birthday bound applies to the seed space
C) 128 bits — brute-forcing the 128-bit seed space is infeasible
D) 256 bits — the PRNG expands the entropy beyond the seed size

---

**Q13.** ChaCha20-Poly1305 is offered as an alternative to AES-256-GCM in TLS 1.3.
What is the primary reason to prefer ChaCha20-Poly1305?

A) It has a higher security level (256 bits vs 128 bits)
B) It is faster on hardware with AES-NI instructions
C) It provides better performance on devices without hardware AES acceleration
D) It uses a larger nonce, reducing nonce collision probability

---

**Q14.** The MixColumns step of AES operates on each column of the state matrix. What
mathematical structure does this operation use?

A) Integer arithmetic modulo 256
B) Polynomial multiplication over GF(2^8) with a fixed MDS matrix
C) Modular exponentiation in a prime field
D) XOR with a key-dependent constant

---

**Q15.** You are storing user passwords in a database. Which of the following is the
MOST secure approach?

A) Store SHA-256(password)
B) Store SHA-256(salt || password) where salt is a random 16-byte value
C) Store bcrypt(password, cost=12) with a per-user random salt
D) Store Argon2id(password, t=1, m=65536, p=4) with a per-user random salt

---

## Answers and Explanations

**Q1. Answer: B — 10 rounds**

AES-128 uses 10 rounds. AES-192 uses 12 rounds. AES-256 uses 14 rounds. The number
of rounds scales with key length. Answer A (8) is incorrect — no standard AES variant
uses 8 rounds. Knowing the round counts is a basic AES fact for interviews.

---

**Q2. Answer: C — SubBytes**

SubBytes applies the AES S-Box, which is defined as GF(2^8) multiplicative inversion
followed by an affine transformation. The inversion is the non-linear step. Without
non-linearity, AES would be a linear system over GF(2) solvable by Gaussian elimination.

**Why the others are wrong:**
- ShiftRows: cyclic rotation — a permutation, linear over GF(2).
- MixColumns: matrix multiplication over GF(2^8) — linear.
- AddRoundKey: XOR with the round key — linear over GF(2).

SubBytes is the sole source of non-linearity.

---

**Q3. Answer: C — The XOR of the two plaintexts up to the point where they first differ**

CBC encryption of block $i$: $C_i = E_K(P_i \oplus C_{i-1})$ with $C_0 = IV$.

If IV is reused and the plaintexts share a common prefix of $j$ blocks:
- Blocks 0 through $j-1$: identical plaintexts XOR identical $C_{i-1}$ → identical ciphertext.
- Block $j$: $C_j^{(1)} = E_K(P_j^{(1)} \oplus C_{j-1})$ and $C_j^{(2)} = E_K(P_j^{(2)} \oplus C_{j-1})$.
- XOR: $C_j^{(1)} \oplus C_j^{(2)} = E_K(P_j^{(1)} \oplus C_{j-1}) \oplus E_K(P_j^{(2)} \oplus C_{j-1})$

This is not directly $P_j^{(1)} \oplus P_j^{(2)}$ because the E_K is inside. However,
the attacker does learn that the first $j$ blocks are identical, and that the first
differing ciphertext block encodes the XOR of the first differing plaintext blocks
(exploitable with a CPA). Under CPA security, reusing the IV with CBC breaks semantic
security — the attacker learns if two plaintexts share a prefix, which violates IND-CPA.

---

**Q4. Answer: C — CTR**

CTR (Counter) mode encrypts successive counter values with the block cipher and XORs
the keystream with the plaintext. This converts the block cipher into a stream cipher.

ECB encrypts blocks independently with no feedback. CBC chains ciphertext blocks.
OFB (Output Feedback) is also a stream cipher mode, but it feeds back the cipher
output (not a counter), making it less parallelisable than CTR.

---

**Q5. Answer: B — $2^{128}$**

The birthday paradox: for an $n$-bit hash, a collision is found in $O(2^{n/2})$
evaluations. For SHA-256 ($n = 256$): $2^{256/2} = 2^{128}$.

Preimage resistance is $O(2^{256})$ (answer A). $2^{64}$ would apply to a 128-bit hash
(MD5/SHA-1 collision resistance is worse than this). $2^{32}$ would be a trivially
breakable 64-bit hash.

---

**Q6. Answer: B — $H(K \| M)$ is vulnerable to length extension attacks**

Merkle-Damgard hash functions (SHA-256, SHA-512) allow extending the hash: given
$H(K \| M)$, an attacker can compute $H(K \| M \| \text{pad} \| M')$ for any $M'$
without knowing $K$. This breaks MAC security because the attacker can forge valid
tags for extended messages.

HMAC's double nesting prevents this: the outer hash applies $K \oplus \text{opad}$
as a key over the inner hash output. Even if the inner hash is extended, the extension
attacks against HMAC-SHA256 are not known to be feasible.

Answer A is wrong: two-level construction is not about hardware parallelism. Answer C
is wrong: HMAC's tag length is the same as the hash output, not shorter. Answer D is
wrong: HMAC works with any hash function.

---

**Q7. Answer: B — Randomness and redundancy providing semantic security and preventing padding oracles**

Textbook RSA $c = m^e \bmod n$ is deterministic: the same message always produces the
same ciphertext. This fails IND-CPA (attacker can test if a ciphertext corresponds to
a known message). RSA is also malleable: $c_1 \cdot c_2 = (m_1 m_2)^e \bmod n$.

OAEP adds randomness (a random seed) and redundancy (a hash-based check) before the
modular exponentiation, providing:
- IND-CCA2 security (in the ROM)
- Protection against padding oracle attacks (Bleichenbacher-style attacks on PKCS#1 v1.5)

Answer C is wrong: RSA-OAEP can only encrypt messages smaller than the modulus minus
OAEP overhead. Answer D is wrong: OAEP is not a signature scheme.

---

**Q8. Answer: C — Preimage resistance**

Preimage resistance: given $h$, it is hard to find $m$ such that $H(m) = h$.

Second-preimage resistance: given $m$, it is hard to find $m' \neq m$ such that $H(m') = H(m)$.

Collision resistance: it is hard to find any $m, m'$ with $H(m) = H(m')$.

The question specifically says "find ANY message $m$ such that $H(m) = h$" — this is
preimage resistance. Collision resistance involves finding any pair, not starting from
a given hash. Second-preimage resistance starts from a known message.

---

**Q9. Answer: C — Both confidentiality and integrity/authentication in a single pass**

AEAD (Authenticated Encryption with Associated Data) provides:
- **Confidentiality**: the plaintext is encrypted.
- **Integrity/Authentication**: the ciphertext includes an authentication tag that
  detects any modification (including bit-flips, block reordering, or ciphertext substitution).

AES-CBC alone provides only confidentiality — it has no integrity mechanism. An attacker
can modify ciphertext bits and produce predictable plaintext changes (bit-flipping attacks).

Answer A: AES-CBC also provides confidentiality — this is not what AEAD adds.
Answer B: The tag length in GCM (128 bits) is determined by configuration, not inherently
longer than CBC (which has no tag).
Answer D: AEAD does not inherently address timing side-channel attacks.

---

**Q10. Answer: C — The signing key (private key)**

ECDSA signing: $s = k^{-1}(H(m) + r \cdot d) \bmod n$ where $k$ is the nonce,
$r = (k \cdot G)_x \bmod n$, and $d$ is the private key.

If the same $k$ is used for two signatures $(r, s_1)$ and $(r, s_2)$ on messages
$m_1$ and $m_2$:

$s_1 - s_2 = k^{-1}(H(m_1) - H(m_2)) \bmod n$

$k = (H(m_1) - H(m_2)) / (s_1 - s_2) \bmod n$

Once $k$ is recovered, the private key follows from:
$d = (s \cdot k - H(m)) / r \bmod n$

This is how Sony's PS3 was compromised in 2010 and how the Debian ECDSA vulnerability
was exploited. Nonce reuse in ECDSA is catastrophic.

---

**Q11. Answer: B — A MAC requires a shared symmetric key; a digital signature does not require a pre-shared secret**

MACs use a shared symmetric key known to both parties. The verifier has the same key
as the signer. This means the verifier can forge MACs — MACs do not provide
non-repudiation (answer A is wrong about MACs).

Digital signatures use asymmetric keys: the signing key is private, the verification
key is public. Anyone with the public key can verify; the signer alone can create.
This enables non-repudiation and public verifiability.

Answer C is wrong: symmetric MAC operations (HMAC) are generally faster than asymmetric
signature operations (ECDSA involves elliptic curve scalar multiplication).
Answer D is wrong: it reverses the properties — MACs require key knowledge to verify;
signatures use public keys.

---

**Q12. Answer: C — 128 bits**

A CSPRNG is computationally secure: given the algorithm and any output, predicting
future or past outputs requires brute-forcing the seed. With 128 bits of entropy in
the seed, brute-forcing requires $2^{128}$ guesses — computationally infeasible.

Answer A is wrong: knowing the algorithm does not help if the seed is unknown. All
CSPRNG security is derived from the seed's entropy.
Answer B is wrong: the birthday bound applies to collision-finding in the output space,
not to seed-guessing.
Answer D is wrong: a PRNG expands the seed into a long pseudo-random sequence, but
the security level is bounded by the seed entropy. You cannot have more security than
the entropy you put in.

---

**Q13. Answer: C — Better performance on devices without hardware AES acceleration**

ChaCha20-Poly1305 is a software-friendly cipher: it uses only 32-bit additions, XORs,
and rotations — operations that are fast on all CPUs including those without AES-NI
hardware instructions.

AES-256-GCM is extremely fast on CPUs with AES-NI (Intel Sandy Bridge+, all modern
ARM with Cortex-A53+ that support NEON AES) but much slower in software.

Answer A is wrong: both cipher suites in TLS 1.3 target 128-bit security.
Answer B is wrong: AES-256-GCM with AES-NI hardware is faster than ChaCha20-Poly1305.
Answer D is wrong: ChaCha20-Poly1305 uses a 96-bit nonce, same as AES-GCM; the nonce
size is not the primary differentiator.

---

**Q14. Answer: B — Polynomial multiplication over GF(2^8) with a fixed MDS matrix**

MixColumns treats each column of the 4×4 state as a polynomial over GF(2^8) (a
4-term polynomial with byte coefficients). It multiplies by a fixed circulant matrix
whose entries are {1, 2, 3} in GF(2^8). The matrix is an MDS (Maximum Distance
Separable) matrix, providing optimal diffusion.

Answer A is wrong: AES arithmetic is in GF(2^8), not integer arithmetic mod 256.
Addition in GF(2^8) is XOR, not modular addition. The field characteristic is 2.
Answer C is wrong: modular exponentiation is not used in MixColumns.
Answer D is wrong: AddRoundKey uses XOR with the round key, not MixColumns.

---

**Q15. Answer: D — Argon2id with appropriate parameters**

Argon2id is the current recommended password hashing algorithm:
- Memory-hard (64 MiB in this example): resistant to GPU/ASIC parallelisation
- Time-tunable: t=1 iteration balances speed vs security
- Salted: per-user salt eliminates rainbow tables
- Both time and memory cost are configurable as hardware improves

**Why the others are weaker:**

A) SHA-256(password): no salt, no work factor, not memory-hard. Broken by rainbow
   tables and GPU brute-force in seconds for common passwords.

B) SHA-256(salt || password): salting prevents rainbow tables but SHA-256 is still
   fast (billions of guesses/second on a GPU). Not memory-hard. Insufficient.

C) bcrypt with cost=12: bcrypt is salted and has a tunable work factor, but its
   memory hardness is fixed at 4 KiB — far too small for modern GPU/FPGA attacks.
   Bcrypt is widely deployed and still adequate in practice, but Argon2id is strictly
   better for new deployments.

In FIPS 140 environments where Argon2id is not yet approved, bcrypt or PBKDF2-HMAC-SHA256
with a high iteration count (600,000+ per NIST SP 800-132) is the required alternative.
