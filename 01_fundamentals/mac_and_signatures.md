# MAC and Digital Signatures

## Prerequisites
- Hash functions and their security properties (preimage, collision resistance)
- Modular arithmetic and basic number theory
- Elliptic curve group law (for ECDSA and EdDSA sections)
- Understanding of symmetric vs. asymmetric key usage
- Familiarity with the concept of a random oracle

---

## Concept Reference

### Message Authentication Codes (MACs)

A **MAC** is a symmetric authentication primitive. Given a shared secret key $K$ and a message $M$, it produces a short **tag** $T = \text{MAC}_K(M)$. A recipient who knows $K$ can verify the tag and be assured:

1. **Authenticity:** The tag was produced by someone who knows $K$.
2. **Integrity:** $M$ has not been modified since the tag was computed.

MACs provide no non-repudiation (both parties share $K$) and no confidentiality. They are used extensively in symmetric protocols: TLS record MAC, IPSEC, SSH integrity, and as the authentication component of AEAD schemes.

**Security model:** A MAC is **EUF-CMA** (existentially unforgeable under chosen-message attack) if no polynomial-time adversary, given access to a MAC oracle for messages of their choice, can produce a valid $(M^*, T^*)$ for any message $M^*$ they did not submit to the oracle.

---

### HMAC Construction

**HMAC** (Hash-based MAC, RFC 2104) is the dominant MAC construction, standardised in NIST SP 800-107.

$$
\text{HMAC}_K(M) = H\bigl((K' \oplus \text{opad}) \,\|\, H((K' \oplus \text{ipad}) \,\|\, M)\bigr)
$$

where:
- $K' = H(K)$ if $|K| > b$, else $K' = K$ zero-padded to block length $b$
- $\text{ipad} = \texttt{0x36}^b$ (inner pad, repeated to block length)
- $\text{opad} = \texttt{0x5C}^b$ (outer pad, repeated to block length)

```
HMAC computation steps:

1.  K'  = K padded or hashed to block length b
2.  K_i = K' XOR ipad          (inner key)
3.  K_o = K' XOR opad          (outer key)
4.  inner = H(K_i || M)        (inner hash)
5.  tag   = H(K_o || inner)    (outer hash = HMAC output)
```

**Why two nested hashes?**

- The inner hash produces a keyed digest of $M$ under $K_i$.
- The outer hash re-keys the output under $K_o$, providing a final output that depends on both keys and the inner hash.
- This double structure prevents length extension attacks: an attacker who extends the inner hash cannot produce the outer MAC without $K_o$.
- Bellare (2006) proved HMAC is a PRF under the assumption that the compression function is a PRF — importantly, this does not require collision resistance of the outer hash.

**Common variants:**
- `HMAC-SHA-256`: 256-bit tag; standard for TLS 1.2, IPsec, SSH
- `HMAC-SHA-384`: 384-bit tag; used in TLS with P-384
- `HMAC-SHA-512/256`: 256-bit truncated output; resistant to length extension on 64-bit platforms

```python
import hmac
import hashlib

key   = b"secret_key"
msg   = b"authenticate this message"
tag   = hmac.new(key, msg, hashlib.sha256).digest()

# Constant-time verification (prevents timing attacks)
received_tag = tag  # in practice, received from remote party
is_valid = hmac.compare_digest(
    hmac.new(key, msg, hashlib.sha256).digest(),
    received_tag
)
print(f"Tag (hex): {tag.hex()}")
print(f"Valid: {is_valid}")
```

**Critical:** Always use `hmac.compare_digest` (or equivalent constant-time comparison) for tag verification. Byte-by-byte comparison leaks timing information that can be exploited to forge tags in $O(256 \cdot n)$ guesses rather than the $O(2^{256/8})$ brute-force bound.

---

### CMAC (Cipher-based MAC)

**CMAC** (NIST SP 800-38B) constructs a MAC from a block cipher (typically AES):

```
CMAC-AES-128 structure:
  Process message blocks through CBC mode.
  XOR final block with a derived subkey K1 or K2.
  Output the final CBC block as the tag.
```

CMAC is preferred in hardware contexts (where AES-NI is available but SHA hardware is absent) and in FIPS 140-3 environments where AES-based primitives are required. It has a 128-bit tag and security up to $2^{64}$ operations (half the block size, due to birthday bound).

---

### Digital Signatures

A **digital signature scheme** uses asymmetric keys to provide:

1. **Authentication:** Only the holder of the private key could have signed.
2. **Non-repudiation:** The signer cannot later deny signing (the public key is known to all).
3. **Integrity:** Any modification to the signed message invalidates the signature.

A signature scheme consists of:
- $\text{KeyGen}() \rightarrow (sk, pk)$
- $\text{Sign}(sk, M) \rightarrow \sigma$
- $\text{Verify}(pk, M, \sigma) \rightarrow \{\text{accept}, \text{reject}\}$

**Security model:** EUF-CMA — an adversary with access to a signing oracle cannot forge a valid signature on any message it has not queried.

---

### ECDSA (Elliptic Curve Digital Signature Algorithm)

ECDSA is standardised in FIPS 186-5 and is the dominant signature scheme in TLS certificates, Bitcoin, and code signing.

**Parameters:** A prime-order elliptic curve group $(\mathbb{E}, G, n)$ where $G$ is the generator point and $n$ is the group order. Common curves: P-256 (NIST), P-384, secp256k1 (Bitcoin).

#### Key Generation

$$
sk = d \xleftarrow{\$} [1, n-1] \qquad pk = Q = dG
$$

#### Signing

Given private key $d$, message $M$, and hash function $H$:

1. Compute $e = H(M)$; let $z$ = the leftmost $|n|$ bits of $e$.
2. Choose a **per-signature random nonce** $k \xleftarrow{\$} [1, n-1]$.
3. Compute $R = kG$; let $r = R_x \bmod n$ (the x-coordinate of $R$, reduced mod $n$).
4. If $r = 0$, go to step 2.
5. Compute $s = k^{-1}(z + rd) \bmod n$.
6. If $s = 0$, go to step 2.
7. Signature: $\sigma = (r, s)$.

#### Verification

Given public key $Q$, message $M$, signature $(r, s)$:

1. Check $r, s \in [1, n-1]$.
2. Compute $e = H(M)$; let $z$ = the leftmost $|n|$ bits of $e$.
3. Compute $w = s^{-1} \bmod n$.
4. Compute $u_1 = zw \bmod n$ and $u_2 = rw \bmod n$.
5. Compute $X = u_1 G + u_2 Q$.
6. Accept if $X_x \equiv r \pmod{n}$.

**Correctness:**

$$
X = u_1 G + u_2 Q = zw G + rw \cdot dG = w(z + rd) G = \frac{z + rd}{s} G
$$

Since $s = k^{-1}(z + rd)$, we have $\frac{z + rd}{s} = k$, so $X = kG = R$ and $X_x = r$. $\square$

#### Critical ECDSA Security Requirements

**Nonce reuse is catastrophic:** If the same $k$ is used for two signatures $(r, s_1)$ and $(r, s_2)$ on messages $M_1$ and $M_2$:

$$
s_1 - s_2 = k^{-1}(z_1 - z_2) \bmod n
$$

$$
k = (z_1 - z_2)(s_1 - s_2)^{-1} \bmod n
$$

Once $k$ is recovered, the private key follows immediately:

$$
d = r^{-1}(sk - z) \bmod n
$$

Real-world exploit: The PlayStation 3 hack (2010) recovered the ECDSA signing key because Sony used a **constant** $k$ across all signatures.

**Biased nonce attack (Lattice attack):** Even a few biased bits in $k$ (e.g., if $k$ is always in the lower half of $[1, n-1]$) leak enough information to recover $d$ using lattice reduction (LLL/BKZ) after collecting $\sim 100$–300 signatures. The Android Bitcoin wallet vulnerability (2013) exploited weak ECDSA nonce generation: the `SecureRandom` PRNG on affected Android versions produced repeated $k$ values, allowing private key recovery from two signatures sharing the same nonce.

```python
# ECDSA signing — DANGEROUS example showing nonce reuse vulnerability
# For educational purposes only

from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes

# Proper usage (library handles nonce generation internally)
private_key = ec.generate_private_key(ec.P_256())
public_key  = private_key.public_key()

message = b"Sign this message"
signature = private_key.sign(message, ec.ECDSA(hashes.SHA256()))

public_key.verify(signature, message, ec.ECDSA(hashes.SHA256()))
print("ECDSA signature verified successfully")
```

---

### EdDSA (Edwards-curve Digital Signature Algorithm)

EdDSA (RFC 8032) is a deterministic signature scheme designed to address ECDSA's nonce management vulnerability. The most common instantiation is **Ed25519** (using Curve25519 in its twisted Edwards form).

#### Ed25519 Key Generation

The private key is a 32-byte random seed $s$. From it:

$$
(a, \text{prefix}) = H_{512}(s) \quad \text{(split SHA-512 output)}
$$

The scalar $a$ is the private signing scalar (with specific bit clamping):
- Set the three lowest bits of $a[0]$ to 0 (ensures $a$ is a multiple of the cofactor 8)
- Set the highest bit of $a[31]$ to 0 and the second highest to 1

$$
A = a \cdot B \quad \text{(public key, a point on the curve)}
$$

where $B$ is the Ed25519 base point of prime order $\ell = 2^{252} + 27742317777372353535851937790883648493$.

#### Ed25519 Signing

**Deterministic nonce generation** — the critical difference from ECDSA:

$$
r = H(\text{prefix} \,\|\, M) \bmod \ell
$$

The nonce $r$ is derived deterministically from the message and a secret prefix, not from a CSPRNG. This eliminates any possibility of nonce reuse across different messages.

1. Compute $R = r \cdot B$ (nonce point)
2. Compute $S = (r + H(R \,\|\, A \,\|\, M) \cdot a) \bmod \ell$
3. Signature: $\sigma = (R, S)$ — 64 bytes for Ed25519

#### Ed25519 Verification

Given public key $A$, message $M$, signature $(R, S)$:

$$
S \cdot B \stackrel{?}{=} R + H(R \,\|\, A \,\|\, M) \cdot A
$$

**Correctness:** $S \cdot B = (r + H \cdot a) B = rB + H \cdot aB = R + H \cdot A$ $\square$

**Batch verification:** EdDSA allows verifying $n$ signatures simultaneously using multi-scalar multiplication, reducing cost to roughly $1.5n$ scalar multiplications instead of $2n$.

#### ECDSA vs EdDSA Comparison

| Property | ECDSA | Ed25519 |
|---|---|---|
| Nonce generation | Random (CSPRNG) | Deterministic (from key + message) |
| Nonce reuse risk | Catastrophic key recovery | Impossible by construction |
| Signature size | 64 bytes (P-256) | 64 bytes |
| Verification speed | ~110 µs (P-256) | ~60 µs |
| Cofactor | 1 (P-256) | 8 (Curve25519) |
| Side-channel risk | Timing leaks in scalar mult | Constant-time by design |
| Standardisation | FIPS 186-5, X.509 | RFC 8032, TLS 1.3 (optional) |
| FIPS approved | Yes | FIPS 186-5 (2023) |

---

### KMAC and SHA-3 Based MACs

**KMAC** (NIST SP 800-185) is the SHA-3 based MAC. Unlike HMAC, it is a direct function of the Keccak sponge without the nested hash structure:

$$
\text{KMAC}(K, X, L, S) = \text{cSHAKE}_{256}(\text{encode}(K) \,\|\, X, L, \texttt{"KMAC"}, S)
$$

KMAC is immune to length extension attacks (sponge construction), has a clean security proof, and supports variable output lengths. It is preferred over HMAC-SHA-3 in new designs.

---

## Tier 1 — Fundamentals

### Question F1
**What is the difference between a MAC and a digital signature? In what scenarios is each appropriate?**

**Answer:**

| Property | MAC | Digital Signature |
|---|---|---|
| Key type | Symmetric (shared secret) | Asymmetric (private/public pair) |
| Who can verify | Only parties who know $K$ | Anyone with the public key |
| Non-repudiation | No — either party could have created it | Yes — only private key holder can sign |
| Performance | Fast (AES-based or hash-based) | Slower (modular exponentiation or EC scalar mult) |
| Key management | Requires pre-shared key | Public key can be distributed freely |

**When to use a MAC:**

- Two parties share a long-term or session key (e.g., TLS record authentication after handshake, IPsec packet integrity, HMAC-based API authentication tokens).
- Performance matters and non-repudiation is not required.
- The threat model only requires protection against external attackers, not disputes between the communicating parties.

**When to use a digital signature:**

- Authentication must be verifiable by third parties (e.g., TLS certificates signed by a CA, software code signing, document signing).
- Non-repudiation is required: the signer cannot later deny having signed.
- A certificate authority model is in use.
- The communicating parties are not pre-provisioned with a shared key.

**Common mistake:** Using a MAC in contexts requiring non-repudiation (e.g., signing a legal document). A MAC proves only that one of the key holders produced the tag — it does not identify which one.

---

### Question F2
**Explain the HMAC construction. Why are two different padded keys (ipad and opad) used rather than a single key?**

**Answer:**

HMAC uses:
- **Inner key** $K_i = K' \oplus \text{ipad}$: used in $H(K_i \,\|\, M)$
- **Outer key** $K_o = K' \oplus \text{opad}$: used in $H(K_o \,\|\, \text{inner})$

**Why two distinct keys?**

If both hashes used the same key $K$:

$$
\text{NMAC}_K(M) = H(K \,\|\, H(K \,\|\, M))
$$

This construction would be analysable if $K = K_{\text{inner}} = K_{\text{outer}}$: an adversary who finds a collision in the inner hash could reuse it for the outer hash. The ipad/opad separation ensures that $K_i \neq K_o$ for all key values, effectively treating the inner and outer hashes as keyed with **independent** keys.

The specific constants $\text{ipad} = \texttt{0x36}^b$ and $\text{opad} = \texttt{0x5C}^b$ were chosen such that:
- $\text{ipad} \oplus \text{opad} = \texttt{0x6A}^b$ (Hamming distance = 4 per byte — sufficient separation)
- They are not related by simple shift or complement operations
- The original RFC 2104 chose them empirically for sufficient bit-distance

In practice, ipad and opad are XORed with the full block-length key before the hash, ensuring even a single-byte key difference $K_i$ vs $K_o$ propagates to all 512 bits of the first hash block, effectively making inner and outer hashing independent keyed functions.

---

### Question F3
**Why must the ECDSA nonce $k$ be unique per signature? Describe the attack that occurs if $k$ is reused.**

**Answer:**

The ECDSA signing equation is $s = k^{-1}(z + rd) \bmod n$. The nonce $k$ is the only source of randomness; $d$ is the fixed private key, $z$ is determined by the message, and $r = (kG)_x$.

**If the same $k$ is used for two signatures on different messages $M_1, M_2$:**

Both signatures share the same $r$ value (since $r = (kG)_x$ and $k$ is the same). Given $(r, s_1)$ and $(r, s_2)$ with $s_1 \neq s_2$:

$$
s_1 = k^{-1}(z_1 + rd) \bmod n
$$
$$
s_2 = k^{-1}(z_2 + rd) \bmod n
$$

Subtracting:

$$
s_1 - s_2 \equiv k^{-1}(z_1 - z_2) \pmod{n}
$$

$$
k \equiv \frac{z_1 - z_2}{s_1 - s_2} \pmod{n}
$$

Both $z_1, z_2, s_1, s_2$ are public. The attacker solves for $k$ using modular arithmetic, then recovers the private key:

$$
d \equiv \frac{sk - z}{r} \pmod{n}
$$

**Real-world consequence:** The PlayStation 3 (2010) used a fixed constant instead of a random $k$, allowing geohot to recover Sony's private ECDSA key from any two firmware signatures. All PS3 games could then be signed as legitimate.

**Defence:** Use a CSPRNG seeded from a high-entropy source, or better, use **RFC 6979 deterministic nonce generation** which derives $k$ deterministically from $(d, M)$ using HMAC-DRBG, making nonce uniqueness a mathematical guarantee rather than an entropy requirement.

---

### Question F4
**What advantage does Ed25519 provide over ECDSA-P256 from a security engineering perspective?**

**Answer:**

Ed25519 addresses several known weaknesses and implementation pitfalls of ECDSA:

1. **Deterministic nonces:** ECDSA requires a fresh random $k$ per signature. If the CSPRNG fails, is biased, or $k$ is reused, the private key is recovered trivially. Ed25519 derives $k$ deterministically from $H(\text{prefix} \,\|\, M)$ — nonce failure is structurally impossible.

2. **Constant-time by design:** The Curve25519 Montgomery ladder and the Edwards curve arithmetic used by Ed25519 are defined over a field of size $2^{255} - 19$, enabling efficient constant-time implementations. P-256 conditional field reductions make constant-time implementation harder.

3. **No cofactor issues for standard operations:** While Curve25519 has cofactor 8 (requiring careful key clamping for Diffie-Hellman), the Ed25519 specification mandates scalar clamping and defines validation rules that prevent small-subgroup attacks.

4. **Simpler validation rules:** Signature verification for Ed25519 has a single unified equation ($S \cdot B = R + H \cdot A$) without the many boundary checks ECDSA requires ($r, s \neq 0$, point at infinity handling, etc.).

5. **Speed:** Ed25519 is approximately 2× faster to verify than ECDSA-P256 on typical hardware, and 4× faster to sign, because Curve25519 arithmetic uses a simpler field.

**Where ECDSA-P256 remains necessary:** FIPS 140-2 compliance (pre-2023), certificate ecosystems (X.509 infrastructure still predominantly uses P-256), and contexts where legacy hardware only supports NIST curves.

---

## Tier 2 — Intermediate

### Question I1
**Explain the timing side-channel in MAC verification and how `hmac.compare_digest` prevents it.**

**Answer:**

A naive tag comparison such as:

```python
# VULNERABLE: early exit on first differing byte
def bad_verify(tag1: bytes, tag2: bytes) -> bool:
    if len(tag1) != len(tag2):
        return False
    for b1, b2 in zip(tag1, tag2):
        if b1 != b2:
            return False   # returns early
    return True
```

leaks information through **response time**: a guess whose first $k$ bytes are correct takes longer to fail than one whose first byte is wrong. An attacker can:

1. Submit a forged tag $T' = \texttt{0x00}^{32}$.
2. Measure response time for each first byte $b \in [0, 255]$.
3. The correct first byte causes the longest average comparison time.
4. Repeat for each byte position.

This recovers the 32-byte HMAC-SHA-256 tag with only $256 \times 32 = 8192$ queries and careful timing measurements — far below the $2^{256}$ brute-force bound.

**Constant-time comparison:**

```python
# SAFE: constant-time comparison
def safe_verify(tag1: bytes, tag2: bytes) -> bool:
    """
    Compares two byte strings in constant time.
    Returns True only if equal. Never reveals which bytes differ.
    """
    if len(tag1) != len(tag2):
        return False
    # XOR all bytes; accumulate into result
    result = 0
    for b1, b2 in zip(tag1, tag2):
        result |= b1 ^ b2   # result becomes non-zero on first difference
    return result == 0      # but we check only at the end

# Python standard library version:
import hmac
is_equal = hmac.compare_digest(computed_tag, received_tag)
```

The constant-time property holds because: (1) the loop always iterates over all bytes, (2) the branch is only at the end (independent of content), and (3) the `|=` operation ensures all bytes are evaluated regardless of early differences.

**Practical note:** Even constant-time comparison is vulnerable to cache-timing if the tag data is paged out to disk or cache-cold. In production, ensure MAC verification happens on resident memory.

---

### Question I2
**Describe how ECDSA batch verification works and why it is beneficial for blockchain validation.**

**Answer:**

Standard ECDSA verification requires, for each signature $(r_i, s_i)$ on message $M_i$ with public key $Q_i$:

$$
X_i = u_{1,i} G + u_{2,i} Q_i \quad \text{and check } X_{i,x} \equiv r_i
$$

Each verification costs 2 scalar multiplications (or ~1.5 with Shamir's trick). For $n$ signatures: $\Theta(2n)$ scalar multiplications.

**Batch verification (Schnorr-style or randomised):**

For Ed25519 / EdDSA (which supports batch verification natively), the verification equation for all $n$ signatures is combined:

$$
\sum_{i=1}^{n} c_i S_i \cdot B \stackrel{?}{=} \sum_{i=1}^{n} c_i R_i + \sum_{i=1}^{n} c_i H(R_i, A_i, M_i) \cdot A_i
$$

where $c_i \xleftarrow{\$} [0, 2^{128})$ are random scalars used to prevent combining attacks.

The left side is a single multi-scalar multiplication with $n$ terms; the right side has $2n$ terms. Using the **Bos–Coster algorithm** or Pippenger's algorithm, a $k$-term multi-scalar multiplication costs approximately $k / \log k$ group operations. For $n = 1000$:
- Individual: $\sim 2000$ scalar multiplications
- Batch: $\sim 3000 / \log(3000) \approx 260$ scalar multiplications — a ~7× speedup

**Bitcoin/Ethereum block validation:** Each block can contain thousands of transaction signatures. Batch verification provides a significant throughput improvement during initial blockchain sync (IBD). Bitcoin Core 0.21+ implements Schnorr batch verification for Taproot (BIP 340). Ethereum uses batch BLS signature verification for validator attestations.

**Security:** The random scalars $c_i$ ensure that if any single signature is invalid, the combined equation fails with overwhelming probability ($1 - 2^{-128}$ per batch), since cancellation would require solving discrete logarithms.

---

### Question I3
**Why is ECDSA signing potentially vulnerable to lattice attacks with biased nonces, and what is the structure of the attack?**

**Answer:**

The ECDSA signing equation:

$$
s_i = k_i^{-1}(z_i + r_i d) \bmod n
$$

rearranges to:

$$
k_i = s_i^{-1} z_i + s_i^{-1} r_i d \bmod n
$$

Let $t_i = s_i^{-1} r_i \bmod n$ and $u_i = s_i^{-1} z_i \bmod n$ (both computable from the public signature). Then:

$$
k_i \equiv t_i d + u_i \pmod{n}
$$

If the nonce $k_i$ is **biased** — say, its top $\ell$ bits are always 0, so $k_i < 2^{|n| - \ell}$ — then:

$$
k_i - u_i \equiv t_i d \pmod{n} \quad \text{with } k_i \text{ small}
$$

This is a system of **Hidden Number Problem (HNP)** instances. Collecting $m$ signatures gives $m$ equations of the form: "the vector $\mathbf{k} = (k_1, \ldots, k_m)$ satisfies $k_i \equiv t_i d + u_i \pmod{n}$ and $\|\mathbf{k}\|$ is small."

**Lattice formulation:** Construct a lattice $\Lambda$ from the $t_i, u_i, n$ values. The target vector $(k_1, \ldots, k_m, d, 1)$ is a short vector in this lattice. The **LLL** or **BKZ** algorithm finds short vectors in polynomial time.

For $\ell$-bit bias in 256-bit nonces:
- $\ell = 1$ (one biased bit): requires $\sim 300$ signatures
- $\ell = 4$ (four known bits): requires $\sim 40$ signatures
- $\ell = 8$ (one biased byte): requires $\sim 6$ signatures

**Real-world examples:** The Android Bitcoin wallet vulnerability (2013) exploited a faulty `SecureRandom` implementation that repeated ECDSA nonces, directly exposing private keys. OpenSSL CVE-2011-4354 (ARM) had weak nonce generation. The Minerva attack (2019) exploited sub-nanosecond timing leaks in ECDSA nonce generation on smartcards.

**Defence:** RFC 6979 deterministic nonce generation eliminates bias entirely; the nonce is derived via HMAC-DRBG from the private key and message hash, providing provably uniform distribution with no timing leakage from the nonce generation step.

---

### Question I4
**Compare HMAC and CMAC. In what deployment scenarios is each preferred?**

**Answer:**

| Property | HMAC | CMAC |
|---|---|---|
| Primitive | Hash function (SHA-256/384/512) | Block cipher (AES-128/256) |
| Tag length | Variable (hash output length) | 128 bits (AES block size) |
| Security bound | PRF if compression function is PRF | PRF up to $2^{64}$ queries (birthday bound on 128-bit block) |
| Performance (software) | Faster on CPUs with SHA extensions | Faster on CPUs with AES-NI |
| FIPS 140 status | FIPS-approved (HMAC-SHA-1/2/3) | FIPS-approved (CMAC-AES) |
| Variable-length key | Yes (any length) | Fixed: 128 or 256 bits |
| Parallel computation | Inner/outer hash independent | Sequential (CBC-based) |

**When to prefer HMAC:**
- Software environments with SHA hardware acceleration (modern server CPUs have SHA-NI extensions since 2017).
- When variable-length output or variable-length keys are needed.
- TLS record authentication (uses HMAC-SHA-256/384 by default).
- When the threat model involves high-volume queries (HMAC has no $2^{64}$ query limit).

**When to prefer CMAC:**
- Hardware security modules (HSMs) and smartcards where AES is the dominant primitive and SHA hardware is absent.
- Systems already using AES for encryption — a single cipher primitive serves both MAC and encryption, reducing code size.
- Embedded systems (ARM Cortex-M with AES hardware but no SHA hardware).
- NIST-validated cryptographic modules where AES-based MAC is mandated.

**Query limit:** CMAC's security degrades after $2^{64}$ queries on the same key (birthday bound on the 128-bit block cipher). For applications generating millions of MACs per second, a key rotation policy must be enforced. HMAC-SHA-256 has no analogous query limit.

---

## Tier 3 — Advanced

### Question A1
**Analyse the security of Schnorr signatures and explain why they provide a cleaner security proof than ECDSA.**

**Answer:**

**Schnorr signature scheme** (over an elliptic curve group of prime order $q$):

- **Key generation:** $sk = x \xleftarrow{\$} \mathbb{Z}_q$, $pk = X = xG$
- **Signing:** Choose $k \xleftarrow{\$} \mathbb{Z}_q$, compute $R = kG$, $e = H(R \,\|\, X \,\|\, M)$, $s = k + ex \bmod q$. Output $(R, s)$.
- **Verification:** Compute $e = H(R \,\|\, X \,\|\, M)$; check $sG = R + eX$.

**Why Schnorr has a cleaner proof than ECDSA:**

1. **Linear signing equation:** $s = k + ex$ is linear in both $k$ and $x$. The Schnorr signature satisfies $sG = kG + exG = R + eX$ directly by group linearity. There is no modular inversion of $k$ — ECDSA requires $k^{-1}$, which complicates proofs.

2. **Tight security reduction:** Schnorr is provably EUF-CMA secure under the discrete logarithm assumption in the random oracle model via the **Forking Lemma** (Pointcheval–Stern 1996). If an adversary forges with non-negligible probability $\epsilon$ in time $T$, we can rewind the adversary to extract the discrete log in time $O(T/\epsilon)$.

   ECDSA's security proof is messier: the linear relationship between $r, s, d$ is obscured by the $k^{-1}$ inversion, and the reduction requires additional idealisations beyond the standard ROM.

3. **Algebraic structure for multi-signatures:** Schnorr signatures are **linearly homomorphic**: $s_1 + s_2$ is a valid signature for $R_1 + R_2$ under key $X_1 + X_2$. This enables native multi-signature protocols (MuSig, MuSig2) without hacks. ECDSA requires more complex constructions for multi-signatures.

4. **Batch verification:** As discussed in I2, Schnorr/EdDSA batch verification is straightforward. ECDSA batch verification is more complex because of the asymmetric $k^{-1}$ structure.

**Schnorr's patent** (US 4,995,082, expired 2008) prevented widespread deployment for decades, which is why ECDSA (a patented workaround) became the de facto standard. Post-patent, Schnorr has seen rapid adoption: Bitcoin Taproot (BIP 340), Polkadot, Zcash.

---

### Question A2
**Describe the Rogue Key Attack on naive Schnorr multi-signatures and how MuSig2 defends against it.**

**Answer:**

**Naive Schnorr multi-signature (insecure):**

Suppose $n$ parties each hold private key $x_i$ and publish $X_i = x_i G$. The aggregate public key is:

$$
\tilde{X} = \sum_{i=1}^n X_i
$$

**Rogue key attack (Wagner 2002):**

A malicious participant $P_n$ sees all other parties' keys $X_1, \ldots, X_{n-1}$ before registering their own. They choose:

$$
X_n = x_n G - \sum_{i=1}^{n-1} X_i
$$

Then the aggregate key is:

$$
\tilde{X} = \sum_{i=1}^n X_i = x_n G
$$

Now $P_n$ alone controls the aggregate key! They can sign arbitrary messages under $\tilde{X}$ using only $x_n$, forging signatures that appear to be co-signed by all participants.

**Defence in MuSig (Maxwell et al., 2018):**

MuSig computes each participant's weight using a hash of **all** public keys in the signing group:

$$
a_i = H_{\text{agg}}(L, X_i), \quad L = H(X_1 \,\|\, X_2 \,\|\, \cdots \,\|\, X_n)
$$

$$
\tilde{X} = \sum_{i=1}^n a_i X_i
$$

Now the rogue key attack requires finding $X_n$ such that $a_n X_n = (\sum_{i=1}^{n-1} a_i X_i)$, which requires solving the discrete logarithm problem — infeasible.

**MuSig2 improvement (2021, RFC in progress):**

MuSig required 3 rounds of communication (commitment, nonce, signature). MuSig2 reduces this to **2 rounds** while maintaining security by using **two nonces per signer**:

$$
R_i = r_{i,1} G + b \cdot r_{i,2} G \quad \text{where } b = H_{\text{noncecoef}}(\tilde{R}_1, \tilde{R}_2, \tilde{X}, M)
$$

The two-nonce trick allows the round-1 nonce commitments to bind the final nonce selection, preventing Wagner's generalised birthday attack on multi-nonce schemes. MuSig2 has a proof under the algebraic group model (AGM) and the random oracle model.

**Practical deployment:** MuSig2 is the basis for threshold signing in the Lightning Network and Bitcoin Taproot cooperative channel closings, allowing $n$-of-$n$ multi-party signatures that appear as a single Schnorr signature on-chain — indistinguishable from a single-party signature and consuming the same block space.

---

### Question A3
**How does RFC 6979 deterministic nonce generation for ECDSA work, and why does it not reduce security compared to random nonces?**

**Answer:**

**RFC 6979 construction:**

Given private key $d$ and message hash $h_1 = H(M)$, the deterministic nonce $k$ is generated as follows (HMAC-DRBG, Section 3.2):

```
Input: private key d (as octet string), hash h1 = H(M)

1.  V = 0x01 * hlen                  (initialise to all-ones)
2.  K = 0x00 * hlen                  (initialise to all-zeros)
3.  K = HMAC_K(V || 0x00 || int2octets(d) || bits2octets(h1))
4.  V = HMAC_K(V)
5.  K = HMAC_K(V || 0x01 || int2octets(d) || bits2octets(h1))
6.  V = HMAC_K(V)
7.  Loop:
        V = HMAC_K(V)
        k = bits2int(V)
        if k in [1, n-1]: return k
        else: K = HMAC_K(V || 0x00); V = HMAC_K(V)
```

The HMAC-DRBG is initialised with both the private key $d$ and the message hash $h_1$ as entropy input. The nonce $k$ is therefore a deterministic function of $(d, M)$.

**Why this does not reduce security:**

Security of ECDSA nonces requires only two properties:

1. **Unpredictability to adversaries:** An adversary who does not know $d$ cannot predict $k$, because $k$ is derived via HMAC with $d$ as part of the key material. HMAC is a PRF; without $d$, $k$ is computationally indistinguishable from uniform.

2. **Uniqueness across messages:** For distinct messages $M_1 \neq M_2$, the nonces $k_1 = F(d, H(M_1))$ and $k_2 = F(d, H(M_2))$ are distinct with overwhelming probability (a collision in HMAC-DRBG requires a collision in the underlying hash). The only exception is hash collisions — if $H(M_1) = H(M_2)$, the nonces coincide, but then $M_1$ and $M_2$ are a hash collision, already a security failure.

**The randomness fallacy:** Some argue that deterministic nonces are "weaker" because they are not "truly random." This confuses information-theoretic randomness with computational unpredictability. ECDSA security only requires computational unpredictability (a PRF suffices); true randomness is not necessary and introduces implementation risk (CSPRNG failures, low-entropy environments, virtualisation that clones RNG state).

**Additional benefit:** RFC 6979 nonces are **testable**. A test vector for a given $(d, M)$ produces a specific $k$, $r$, $s$. This enables implementation validation that is impossible with random nonces, reducing the risk of subtle bugs in nonce generation. The OpenSSL, BoringSSL, and libsodium implementations all support RFC 6979 test vector validation.
