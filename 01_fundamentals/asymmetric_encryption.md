# Asymmetric Encryption

## Prerequisites
- Modular arithmetic: addition, multiplication, and exponentiation modulo $n$
- Basic number theory: GCD, coprimality, Euler's totient function
- Understanding of one-way functions and trapdoor functions
- Familiarity with the distinction between a public key and private key

---

## Concept Reference

### What is Asymmetric Encryption?

Asymmetric (public-key) encryption uses **two mathematically related keys**:

- **Public key** $pk$: Distributed freely. Used to encrypt a message or verify a signature.
- **Private key** $sk$: Kept secret. Used to decrypt or produce a signature.

The fundamental security requirement is that knowing $pk$ reveals no computationally useful information about $sk$. This is grounded in the hardness of a mathematical problem: for RSA, the **integer factorisation problem**; for ECC-based schemes, the **elliptic curve discrete logarithm problem**.

Asymmetric encryption solves the **key distribution problem** that plagues symmetric cryptography: two parties who have never communicated can establish a shared secret over a public channel using only each other's public keys.

---

### RSA Encryption

RSA (Rivest–Shamir–Adleman, 1977) is the oldest and most widely deployed asymmetric cryptosystem.

#### Key Generation

1. Choose two large distinct primes $p$ and $q$ (typically 2048 bits total for the modulus).
2. Compute the modulus: $n = p \cdot q$
3. Compute Euler's totient: $\phi(n) = (p-1)(q-1)$
   - Alternatively, compute Carmichael's function: $\lambda(n) = \text{lcm}(p-1, q-1)$ (more common in current implementations)
4. Choose public exponent $e$ such that $1 < e < \phi(n)$ and $\gcd(e, \phi(n)) = 1$
   - Standard choice: $e = 65537 = 2^{16} + 1$ (prime, has only two set bits — fast modular exponentiation)
5. Compute private exponent: $d \equiv e^{-1} \pmod{\phi(n)}$ (using the extended Euclidean algorithm)
6. **Public key:** $(n, e)$
7. **Private key:** $(n, d)$ (or equivalently the full set $(p, q, d, d_p, d_q, q_{\text{inv}})$ for the CRT form)

#### Encryption and Decryption

**Encryption** (given plaintext integer $m$ where $0 \leq m < n$):

$$
c = m^e \bmod n
$$

**Decryption** (given ciphertext integer $c$):

$$
m = c^d \bmod n
$$

**Correctness proof:** By Euler's theorem, $m^{\phi(n)} \equiv 1 \pmod{n}$ for $\gcd(m, n) = 1$. Since $ed \equiv 1 \pmod{\phi(n)}$, we have $ed = 1 + k\phi(n)$ for some integer $k$. Therefore:

$$
c^d = (m^e)^d = m^{ed} = m^{1 + k\phi(n)} = m \cdot (m^{\phi(n)})^k \equiv m \cdot 1^k = m \pmod{n}
$$

#### Textbook RSA is Insecure

**Textbook RSA** (the raw mathematical operation above) is deterministic and lacks semantic security. Vulnerabilities:

1. **Determinism**: Encrypting the same message always gives the same ciphertext, allowing an adversary to test guesses.
2. **Small message space**: If $m$ is small (e.g., $m = 2$) and $e = 3$, then $c = m^e = 8$ and $m$ can be recovered by taking the integer cube root of $c$ without any modular arithmetic.
3. **Chosen ciphertext attacks**: RSA is multiplicatively homomorphic: $E(m_1) \cdot E(m_2) = E(m_1 \cdot m_2) \bmod n$. This enables adaptive attacks.

#### OAEP — Optimal Asymmetric Encryption Padding

In practice, **PKCS#1 v2.2 OAEP** (Optimal Asymmetric Encryption Padding) is used:

```
Input:  message M, label L (often empty), hash H, mask generation function MGF
Output: ciphertext C

1. Pad M: lHash || PS || 0x01 || M  (where lHash = H(L), PS = zero-padding)
2. seed = random bytes (length = hash output length)
3. maskedDB = DB  XOR  MGF(seed, |DB|)
4. maskedSeed = seed  XOR  MGF(maskedDB, |seed|)
5. EM = 0x00 || maskedSeed || maskedDB
6. C = EM^e mod n
```

OAEP is **IND-CCA2 secure** in the random oracle model, meaning it is secure against adaptive chosen-ciphertext attacks. The randomness introduced by the random seed ensures non-determinism.

---

### RSA Digital Signatures

RSA can also be used to **sign** messages, providing authenticity and non-repudiation.

#### Signing and Verification

**Signing** (with private key $d$, on hash $H(m)$):

$$
\sigma = H(m)^d \bmod n
$$

**Verification** (with public key $e$):

$$
H(m) \stackrel{?}{=} \sigma^e \bmod n
$$

If the equation holds, the signature is valid. Only the holder of $d$ could have produced a value $\sigma$ such that $\sigma^e \equiv H(m)$.

**Why hash before signing?** Direct signing of $m$ is vulnerable to forgery: given any $\sigma$, one can compute $m = \sigma^e \bmod n$ and claim to have signed $m$. Hashing $m$ first breaks this existential forgery because $H(m)$ is a fixed-size digest and hash preimage resistance prevents the attacker from finding $m$ given $H(m)$.

#### RSA-PSS — Probabilistic Signature Scheme

PSS (used in PKCS#1 v2.1 and later) is the signature analogue of OAEP, adding randomness and providing provable security:

```
1. mHash = H(M)
2. salt = random bytes (length sLen)
3. M' = 0x00^8 || mHash || salt
4. H = H(M')
5. DB = PS || 0x01 || salt  (PS = zero padding)
6. dbMask = MGF(H, emLen - hLen - 1)
7. maskedDB = DB XOR dbMask
8. EM = maskedDB || H || 0xBC
9. signature = EM^d mod n
```

RSA-PSS is provably secure (tight reduction to RSA problem) in the random oracle model. PKCS#1 v1.5 signatures (without PSS) are still widely used for legacy compatibility but do not have a tight security proof.

---

### RSA Key Generation and Primality Testing

Secure RSA requires generating large primes. The standard approach:

1. Generate a random odd integer $p$ of the required bit length.
2. Test whether $p$ is prime.
3. If not, increment by 2 and retry.

The **Prime Number Theorem** guarantees that the density of primes near $N$ is approximately $1/\ln N$. For a 1024-bit prime (a random 1024-bit number), roughly $\ln(2^{1024}) \approx 710$ candidates must be tested on average. In practice, trial division by small primes filters out ~80% of candidates cheaply before expensive primality tests.

#### Miller-Rabin Probabilistic Primality Test

Miller-Rabin is the standard primality test used in RSA key generation.

**Setup:** Write $n - 1 = 2^s \cdot d$ where $d$ is odd (factor out powers of 2).

**Test for witness $a$:**

$$
\text{Compute } a^d \bmod n
$$

$n$ is declared a **probable prime** to base $a$ if either:
- $a^d \equiv 1 \pmod{n}$, or
- $a^{2^r d} \equiv -1 \pmod{n}$ for some $0 \leq r < s$

If neither condition holds, $a$ is a **witness to the compositeness** of $n$.

**Error probability:** A single Miller-Rabin test with a random base $a$ declares a composite $n$ as probably prime with probability at most $1/4$. With $k$ independent random bases, the false-prime probability is at most $4^{-k}$.

**Deterministic for small $n$:** For $n < 3.3 \times 10^{24}$, testing bases $\{2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37\}$ is sufficient to determine primality with certainty (no false positives).

```python
def miller_rabin(n: int, a: int) -> bool:
    """
    Returns True if n is a probable prime to base a.
    Returns False if n is definitely composite.
    """
    if n < 2:
        return False
    if n == 2 or n == 3:
        return True
    if n % 2 == 0:
        return False

    # Write n-1 = 2^s * d with d odd
    s, d = 0, n - 1
    while d % 2 == 0:
        s += 1
        d //= 2

    x = pow(a, d, n)  # a^d mod n

    if x == 1 or x == n - 1:
        return True  # probable prime

    for _ in range(s - 1):
        x = pow(x, 2, n)  # square
        if x == n - 1:
            return True  # probable prime

    return False  # composite


def is_prime(n: int, rounds: int = 40) -> bool:
    """
    Miller-Rabin with `rounds` random witnesses.
    False positive probability: at most 4^(-rounds).
    For rounds=40: probability < 2^(-80).
    """
    import random
    if n < 2:
        return False
    small_primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
    for p in small_primes:
        if n == p:
            return True
        if n % p == 0:
            return False
    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        if not miller_rabin(n, a):
            return False
    return True  # probable prime


# Expected outputs:
print(is_prime(7))        # True
print(is_prime(561))      # False (Carmichael number — fools Fermat test but not Miller-Rabin)
print(is_prime(2**127-1)) # True (Mersenne prime M127)
```

#### Fermat Primality Test (and why it is insufficient)

For completeness: the Fermat test checks $a^{n-1} \equiv 1 \pmod{n}$ for random $a$. This works for most composites but fails for **Carmichael numbers** (e.g., 561 = 3 × 7 × 11), which satisfy $a^{n-1} \equiv 1 \pmod{n}$ for all $a$ coprime to $n$. Miller-Rabin is immune to Carmichael numbers and is always preferred.

---

## Tier 1 — Fundamentals

### Question F1
**State the RSA key generation procedure and explain why $d$ must satisfy $e \cdot d \equiv 1 \pmod{\phi(n)}$.**

**Answer:**

Key generation steps:
1. Select two large random primes $p$ and $q$.
2. Compute modulus $n = pq$.
3. Compute $\phi(n) = (p-1)(q-1)$.
4. Choose $e$ with $\gcd(e, \phi(n)) = 1$; standard choice is $e = 65537$.
5. Compute $d = e^{-1} \bmod \phi(n)$.

The requirement $ed \equiv 1 \pmod{\phi(n)}$ is the algebraic condition that makes decryption the inverse of encryption. By Euler's theorem, $m^{\phi(n)} \equiv 1 \pmod{n}$ for any $m$ coprime to $n$. Therefore:

$$
(m^e)^d = m^{ed} = m^{1 + k\phi(n)} = m \cdot (m^{\phi(n)})^k \equiv m \cdot 1 \pmod{n}
$$

The extended Euclidean algorithm efficiently computes $d$ given $e$ and $\phi(n)$, running in $O(\log^2 n)$ time.

**Common mistake:** Using $\phi(n)$ vs. $\lambda(n)$ (Carmichael's function). Modern implementations use $\lambda(n) = \text{lcm}(p-1, q-1)$, which produces a smaller $d$ and is equally correct. Both satisfy $m^{e d} \equiv m \pmod{n}$ because $\lambda(n) \mid \phi(n)$.

---

### Question F2
**Why is $e = 65537$ universally used as the RSA public exponent rather than a smaller value like $e = 3$?**

**Answer:**

$e = 65537 = 2^{16} + 1$ is chosen for two reasons:

1. **Security over $e = 3$:** If $e = 3$ and the same message $m$ is sent to three recipients with independent moduli $n_1, n_2, n_3$, the Chinese Remainder Theorem yields $m^3$ over $\mathbb{Z}$, and taking the integer cube root recovers $m$ directly (**Håstad's broadcast attack**). With $e = 65537$, an attacker would need 65537 recipients for the analogous attack, which is not practical.

2. **Efficient modular exponentiation with $e = 65537$:** In binary, $65537 = 1\underbrace{00\ldots0}_{16}1$. Exponentiation using square-and-multiply requires exactly **16 squarings and 1 multiplication** (16 squarings to traverse the 16 zero bits after the leading 1, plus 1 multiply for the trailing set bit). This is fast and has minimal timing variation.

Small $e$ values ($e = 3$, $e = 17$) are also vulnerable to low-public-exponent attacks when plaintext messages are short or when OAEP is not used. $e = 65537$ is large enough to avoid these concerns while still being efficient.

---

### Question F3
**What is the security basis of RSA? What problem would need to be solved to break RSA?**

**Answer:**

The security of RSA relies on the assumed hardness of two related problems:

1. **Integer Factorisation Problem (IFP):** Given $n = pq$ (product of two large primes), find $p$ and $q$. If an attacker factors $n$, they can compute $\phi(n) = (p-1)(q-1)$ and then $d = e^{-1} \bmod \phi(n)$, recovering the private key entirely.

2. **RSA Problem:** Given $n$, $e$, and $c = m^e \bmod n$, find $m$. This is at most as hard as factoring (factoring reduces the RSA problem to trivial), but may be strictly easier in principle — though no efficient algorithm for the RSA problem without factoring is known.

Current state: Factoring a 2048-bit RSA modulus requires approximately $2^{112}$ operations with the best-known algorithm (General Number Field Sieve). NIST recommends 2048-bit RSA for security until 2030 and 3072-bit for beyond.

**Quantum threat:** Shor's algorithm solves the factorisation problem in polynomial time on a quantum computer. A cryptographically relevant quantum computer with ~4000 logical qubits would break 2048-bit RSA. This motivates the transition to post-quantum cryptography.

---

### Question F4
**Describe the difference between RSA used for encryption versus RSA used for signing. Are the mathematical operations the same?**

**Answer:**

The underlying mathematics is the same in both cases (modular exponentiation), but the key usage is **reversed**:

| Operation | Encryption | Signing |
|-----------|-----------|---------|
| Sender uses | Recipient's public key $e$ | Signer's private key $d$ |
| Receiver uses | Recipient's private key $d$ | Verifier's public key $e$ |
| Input | Plaintext $m$ | Hash of message $H(m)$ |
| Formula | $c = m^e \bmod n$ | $\sigma = H(m)^d \bmod n$ |
| Goal | Confidentiality | Authenticity and non-repudiation |

**Critical difference:** In encryption, the output is kept confidential. In signing, both the message and the signature are public — anyone can verify. Privacy in signing comes from the infeasibility of forging $\sigma$ without knowing $d$, not from secrecy of the signature itself.

**Common mistake:** Signing raw message $m$ without hashing first. This is vulnerable to existential forgery: for any random $\sigma$, the value $m = \sigma^e \bmod n$ is a valid message with signature $\sigma$. Hashing with a collision-resistant function prevents this.

---

## Tier 2 — Intermediate

### Question I1
**Explain the Chinese Remainder Theorem (CRT) optimisation for RSA decryption. What speedup does it provide?**

**Answer:**

Standard RSA decryption computes $m = c^d \bmod n$ where $n$ is a 2048-bit number. The cost is $O(\log d)$ multiplications of 2048-bit numbers, each of which is itself $O((\log n)^2)$ — expensive.

The **CRT optimisation** computes two separate exponentiations modulo $p$ and $q$ (each 1024-bit numbers) and combines them:

```
Precomputed values (stored in private key):
  d_p = d mod (p-1)
  d_q = d mod (q-1)
  q_inv = q^(-1) mod p

Decryption:
  m_p = c^(d_p) mod p
  m_q = c^(d_q) mod q

  h = q_inv * (m_p - m_q) mod p
  m = m_q + h * q
```

**Speedup analysis:**

- Each modular exponentiation is now with a 1024-bit modulus (instead of 2048-bit).
- Cost of modular multiplication scales as $O(k^2)$ where $k$ is the modulus bit length.
- Two 1024-bit exponentiations: $2 \times (1024/2048)^2 = 2 \times 1/4 = 1/2$ the cost of one 2048-bit exponentiation.

**Practical speedup: approximately 4×** (the reduction in exponent length also helps).

**Security consideration:** The CRT form requires keeping $p$, $q$, $d_p$, $d_q$, and $q_{\text{inv}}$ in the private key structure. If any of these values leaks (e.g., through a fault attack that corrupts one of $m_p$ or $m_q$), the factorisation of $n$ can be recovered from the faulty signature. RSA implementations on hardware must use **CRT fault countermeasures** (e.g., verify the signature after computing it) to prevent Bellcore-style fault attacks.

---

### Question I2
**What are Carmichael numbers and why do they defeat the Fermat primality test but not Miller-Rabin?**

**Answer:**

A **Carmichael number** is a composite integer $n$ such that:

$$
a^{n-1} \equiv 1 \pmod{n} \quad \text{for all } a \text{ with } \gcd(a, n) = 1
$$

The smallest Carmichael number is $561 = 3 \times 7 \times 11$.

**Why Fermat's test fails:** The Fermat primality test declares $n$ probably prime if $a^{n-1} \equiv 1 \pmod{n}$ for a random base $a$. For a Carmichael number, this condition holds for every $a$ coprime to $n$, so the test always returns "probably prime" regardless of how many random bases are tried. Carmichael numbers are effectively **unconditional false positives** for the Fermat test.

**Why Miller-Rabin detects Carmichael numbers:**

Miller-Rabin requires not just $a^{n-1} \equiv 1 \pmod{n}$ but that the sequence of square roots of 1 was reached in a specific way. Write $n - 1 = 2^s d$. Miller-Rabin requires either:
- $a^d \equiv 1 \pmod{n}$, or
- $a^{2^r d} \equiv -1 \pmod{n}$ for some $0 \leq r < s$

For $n = 561 = 3 \times 7 \times 11$, consider $a = 2$:
- $n - 1 = 560 = 2^4 \times 35$
- $2^{35} \bmod 561 = 263 \neq 1$ and $\neq 560$
- $2^{70} \bmod 561 = 166 \neq 560$
- $2^{140} \bmod 561 = 67 \neq 560$
- $2^{280} \bmod 561 = 1$, but none of the earlier values were $-1$.

This violates the Miller-Rabin conditions, correctly identifying 561 as composite.

Theoretically, for composite $n$, at most $1/4$ of all bases $a$ satisfy the Miller-Rabin probable-prime conditions. This bound is tight and does not have exceptions like Carmichael numbers for the Fermat test.

---

### Question I3
**Describe a padding oracle attack on PKCS#1 v1.5 RSA encryption (Bleichenbacher's attack). What is its complexity and how is it mitigated?**

**Answer:**

**PKCS#1 v1.5 padding format:**

RSA PKCS#1 v1.5 encryption pads the message as:

```
EM = 0x00 || 0x02 || PS || 0x00 || M
```

Where PS is at least 8 bytes of random non-zero padding. After decryption, the implementation checks that EM begins with `0x00 0x02`.

**Bleichenbacher's 1998 attack** exploits a system that indicates (via error message or timing) whether a decrypted RSA ciphertext has valid PKCS#1 v1.5 padding.

**Mechanism:**

Given a target ciphertext $C = M^e \bmod n$, the attacker:

1. Uses RSA's multiplicative homomorphism: $C' = s^e \cdot C \bmod n$ decrypts to $s \cdot M \bmod n$.
2. Submits $C'$ as a forged ciphertext.
3. If the oracle returns "valid padding," the attacker learns that $s \cdot M \bmod n$ has the required byte pattern, placing a constraint on the range of $M$.
4. Iterates with different $s$ values, progressively narrowing the range of possible values for $M$.

**Complexity:** Approximately $2^{20}$ to $2^{23}$ oracle queries (TLS decrypt calls) for a 1024-bit RSA key. Modern implementations of this attack (ROBOT attack, 2017) recovered TLS session keys against major vendors in practice.

**Mitigations:**

1. **Switch to OAEP** (PKCS#1 v2.x): OAEP is provably secure against adaptive chosen-ciphertext attacks. PKCS#1 v1.5 is no longer recommended for new systems.
2. **Constant-time padding check**: Even with PKCS#1 v1.5, the implementation must not return a different error for padding failures vs. other errors, and must process the decryption in constant time regardless of padding validity.
3. **Randomise error handling**: Return a random pre-generated value as the "decrypted plaintext" when padding fails, rather than an error — this is the RFC 5246 countermeasure, though it is fragile.
4. **TLS 1.3 removes RSA key exchange entirely**, using only (EC)DHE, which eliminates the attack surface.

---

## Tier 3 — Advanced

### Question A1
**Describe the PKCS#1 v1.5 signature format and explain the Bleichenbacher 2006 signature forgery attack on RSA implementations that do not verify the full padding.**

**Answer:**

**PKCS#1 v1.5 signature encoding (for SHA-256):**

```
EM = 0x00 || 0x01 || PS || 0x00 || DigestInfo
```

Where PS is $k - 3 - \text{len}(\text{DigestInfo})$ bytes of `0xFF`, and DigestInfo is a DER-encoded structure containing the hash algorithm OID and the hash value.

For a 2048-bit key and SHA-256:

```
DigestInfo (51 bytes):
  30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20
  || SHA-256-hash-bytes (32 bytes)

Full EM (256 bytes):
  00 01 FF FF ... FF (202 bytes of FF) 00 DigestInfo
```

**Bleichenbacher's 2006 forgery attack:**

Some RSA implementations verify only the beginning and end of the decoded signature, not the full padding. If an implementation verifies:
- EM starts with `0x00 0x01`
- Followed by at least one `0xFF`
- Contains `0x00`
- Ends with a valid DigestInfo

...but does not verify that the entire space between the `0xFF` block and DigestInfo is filled with `0xFF` (i.e., allows trailing garbage), the attacker can exploit this.

For small public exponents (especially $e = 3$), the attacker can **construct a perfect cube** that passes the partial verification:

```
Construct: 0x00 0x01 0xFF 0x00 DigestInfo garbage
           |                                    |
           valid prefix                valid suffix

Find integer X such that:
  (floor(cbrt(X)))^3 has the right prefix and suffix.
```

For $e = 3$, this is a cube-root computation (polynomial time). The attacker computes $\sigma = \lfloor X^{1/3} \rfloor$ and the implementation incorrectly accepts $\sigma^3 \bmod n \approx X$ as a valid signature.

**Affected implementations:** OpenSSL prior to 0.9.7k/0.9.8c (2006), multiple other implementations. NSS, GnuTLS were affected.

**Mitigation:** Verify the **complete** PKCS#1 v1.5 encoding byte-by-byte, not just head and tail. Better: migrate to RSA-PSS, which has no equivalent attack due to its probabilistic structure.

---

### Question A2
**Explain why the choice of $p$ and $q$ in RSA key generation has strict requirements beyond simply being large primes. What are "strong primes" and are they still required?**

**Answer:**

Simple random large primes are insufficient because special factorisation algorithms can exploit structural weaknesses in $p$ and $q$.

**Requirements and attacks they prevent:**

**1. $p$ and $q$ must not be close together.**

If $p \approx q \approx \sqrt{n}$, Fermat's factorisation method finds $p$ and $q$ quickly:

$$
n = p \cdot q = \left(\frac{p+q}{2}\right)^2 - \left(\frac{p-q}{2}\right)^2
$$

This is a difference of squares. If $p$ and $q$ are close, $a = (p+q)/2$ is just above $\sqrt{n}$, and trial of small increments finds the factorisation rapidly. Mitigation: require $|p - q| > 2^{n/2 - 100}$.

**2. $p - 1$ and $q - 1$ must not have only small prime factors.**

Pollard's $p-1$ algorithm factors $n$ if $p-1$ is **smooth** (all prime factors below some bound $B$):

$$
M = \text{lcm}(1, 2, \ldots, B) \approx e^B
$$
$$
g^M - 1 \equiv 0 \pmod{p} \implies p \mid \gcd(g^M - 1, n)
$$

If $p - 1$ has all prime factors $\leq 2^{20}$, this algorithm finds $p$ in minutes. Mitigation: $p - 1$ must have at least one large prime factor $r$ such that $r > 2^{100}$ (requiring $p = 2r + 1$ for a Sophie Germain prime makes $p$ maximally resistant).

**3. $p + 1$ must not be smooth** (for Williams' $p+1$ algorithm, analogous to Pollard's $p-1$).

**Strong primes** (ANSI X9.31 definition) are primes $p$ such that:
- $p - 1$ has a large prime factor $r$
- $p + 1$ has a large prime factor
- $r - 1$ has a large prime factor

**Are strong primes still required in practice?**

For **2048-bit RSA**: The answer is **no**, with modern key sizes. The probability that a randomly generated 1024-bit prime $p$ has a smooth $p-1$ is negligible for any reasonable smoothness bound. NIST FIPS 186-5 no longer requires strong primes for key generation, requiring only that $|p - q| > 2^{n/2 - 100}$.

For **legacy or constrained key sizes** (512–1024 bit, still seen in embedded devices): strong prime requirements provide meaningful additional protection.

The requirement persists in ANSI X9.31 (financial applications) for conservative compliance, but is absent from modern NIST, RFC 4492, and PKCS recommendations for contemporary key sizes.
