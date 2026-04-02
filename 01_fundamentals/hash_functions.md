# Hash Functions

## Prerequisites
- Bitwise operations: AND, OR, XOR, left/right shifts and rotations
- Basic understanding of iterative compression functions
- Familiarity with the concept of a one-way function
- Understanding of what "collision" and "preimage" mean in the cryptographic context

---

## Concept Reference

### What is a Cryptographic Hash Function?

A cryptographic hash function $H$ maps an input of arbitrary length to a fixed-length digest:

$$
H : \{0,1\}^* \rightarrow \{0,1\}^n
$$

For SHA-256, $n = 256$ bits. The output is sometimes called a **digest**, **hash value**, or simply a **hash**.

Three security properties are required:

| Property | Definition | Hardness Target (SHA-256) |
|---|---|---|
| **Preimage resistance** | Given $y$, find any $x$ such that $H(x) = y$ | $2^{256}$ work |
| **Second preimage resistance** | Given $x$, find $x' \neq x$ such that $H(x) = H(x')$ | $2^{256}$ work |
| **Collision resistance** | Find any pair $(x, x')$ with $x \neq x'$ and $H(x) = H(x')$ | $2^{128}$ work (birthday bound) |

The collision hardness is $2^{n/2}$ rather than $2^n$ due to the **birthday paradox**: among $\Omega(2^{n/2})$ randomly chosen inputs, a collision exists with constant probability. This is the tightest bound and dictates minimum output lengths — SHA-256 provides 128-bit collision security.

---

### SHA-256 Structure

SHA-256 is a member of the **SHA-2 family**, designed by the NSA and standardised by NIST in 2001.

#### Merkle–Damgård Construction

SHA-256 uses the **Merkle–Damgård (MD) construction** to process arbitrary-length inputs:

```
                ┌────────────────────────────────────────┐
                │         SHA-256 Message Processing      │
                │                                         │
IV (256 bits) ──►  f(IV, M1) ──► f(H1, M2) ──► ... ──► final digest
                      ▲               ▲
                      │               │
                    M1 (512 bits)   M2 (512 bits)
```

Steps:
1. **Padding:** Append a single `1` bit, then `0` bits, then the 64-bit big-endian encoding of the original message length (in bits). The total padded length is a multiple of 512 bits.
2. **Parsing:** Split into 512-bit (16-word) message blocks $M^{(1)}, M^{(2)}, \ldots, M^{(N)}$.
3. **Initialisation:** Set the initial hash value $H^{(0)}$ to eight 32-bit constants derived from the fractional parts of the square roots of the first eight primes.
4. **Compression:** For each block $M^{(i)}$, update: $H^{(i)} = f_{\text{compress}}(H^{(i-1)}, M^{(i)})$
5. **Finalisation:** Output $H^{(N)}$ (eight 32-bit words concatenated = 256 bits).

#### SHA-256 Constants

**Round constants** $K_t$ (64 values): the first 32 bits of the fractional parts of the cube roots of the first 64 primes.

**Initial hash values** $H_0^{(0)}$ through $H_7^{(0)}$:
```
H0 = 0x6a09e667    H1 = 0xbb67ae85    H2 = 0x3c6ef372    H3 = 0xa54ff53a
H4 = 0x510e527f    H5 = 0x9b05688c    H6 = 0x1f83d9ab    H7 = 0x5be0cd19
```

#### The Compression Function

The compression function $f_{\text{compress}}$ takes the current 256-bit state (eight 32-bit words $a$–$h$) and a 512-bit message block, and produces a new 256-bit state.

**Message schedule:** Expand the 16 input words $W_0, \ldots, W_{15}$ to 64 words:

$$
W_t = \sigma_1(W_{t-2}) + W_{t-7} + \sigma_0(W_{t-15}) + W_{t-16} \quad \text{for } 16 \leq t \leq 63
$$

where the lowercase $\sigma$ functions are:

$$
\sigma_0(x) = \text{ROTR}^7(x) \oplus \text{ROTR}^{18}(x) \oplus \text{SHR}^3(x)
$$

$$
\sigma_1(x) = \text{ROTR}^{17}(x) \oplus \text{ROTR}^{19}(x) \oplus \text{SHR}^{10}(x)
$$

**64 rounds of state mixing:** Starting from $(a, b, c, d, e, f, g, h) = H^{(i-1)}$:

$$
T_1 = h + \Sigma_1(e) + \text{Ch}(e, f, g) + K_t + W_t
$$

$$
T_2 = \Sigma_0(a) + \text{Maj}(a, b, c)
$$

$$
(a, b, c, d, e, f, g, h) \leftarrow (T_1 + T_2,\; a,\; b,\; c,\; d + T_1,\; e,\; f,\; g)
$$

The **uppercase $\Sigma$ functions** mix multiple rotations:

$$
\Sigma_0(a) = \text{ROTR}^2(a) \oplus \text{ROTR}^{13}(a) \oplus \text{ROTR}^{22}(a)
$$

$$
\Sigma_1(e) = \text{ROTR}^6(e) \oplus \text{ROTR}^{11}(e) \oplus \text{ROTR}^{25}(e)
$$

The **non-linear functions**:

$$
\text{Ch}(e, f, g) = (e \mathbin{\&} f) \oplus (\lnot e \mathbin{\&} g)
$$
$$
\text{Maj}(a, b, c) = (a \mathbin{\&} b) \oplus (a \mathbin{\&} c) \oplus (b \mathbin{\&} c)
$$

Ch ("Choose") selects bit $f$ where $e = 1$, and bit $g$ where $e = 0$. Maj ("Majority") outputs the majority bit among $a$, $b$, $c$.

**Finalisation:** Add the output of the 64 rounds back to the incoming state:

$$
H^{(i)} = H^{(i-1)} + (a, b, c, d, e, f, g, h)_{\text{after 64 rounds}}
$$

This **Davies–Meyer feed-forward** addition is what makes the compression function one-way: inverting it would require simultaneously inverting the block cipher and the modular addition.

---

### SHA-256 Security Properties and Attacks

#### Length Extension Attacks

The MD construction leaks the internal state after processing. Given $H(\text{prefix})$, an attacker can compute $H(\text{prefix} \,\|\, \text{pad} \,\|\, \text{suffix})$ without knowing the prefix, by resuming the computation from the leaked state.

**Affected:** SHA-1, SHA-256, MD5 (all MD-construction hashes).  
**Not affected:** SHA-3 (sponge construction), BLAKE2/3, SHA-512/256 (truncated output hides state), HMAC (properly wraps the hash).

This attack breaks naive MAC constructions like $H(\text{secret} \,\|\, \text{message})$; use HMAC instead.

#### Collision Resistance in Practice

SHA-256 has no known practical collision attacks. Compare:
- **MD5:** Full collision found by Wang et al. (2004) in $< 2^{24}$ operations. Entirely broken for collision resistance.
- **SHA-1:** Shattered collision demonstrated by Google (2017) with $\approx 2^{63.1}$ operations. Deprecated.
- **SHA-256:** No collision found; best known theoretical attack does not improve on $2^{128}$.

#### The SHA-3 Alternative (Keccak Sponge)

SHA-3 uses a fundamentally different construction — the **sponge** — rather than Merkle–Damgård. The sponge absorbs input bits into a large internal state (1600 bits) using the Keccak-$f$ permutation, then squeezes output. Sponge constructions are immune to length extension attacks and have a cleaner security proof. SHA-3 is the recommended alternative when Merkle–Damgård weaknesses are a concern.

---

### Reference: SHA-256 in Python

```python
import struct
import hashlib  # for verification

# SHA-256 round constants K[0..63]
K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    # ... (full table omitted for brevity; use hashlib in production)
]

def rotr(x: int, n: int) -> int:
    """32-bit right rotation."""
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF

def sha256_compress(state: list[int], block: bytes) -> list[int]:
    """
    Apply one SHA-256 compression round.
    state: list of 8 x 32-bit integers (current hash state)
    block: 64-byte (512-bit) message block
    Returns: updated state as list of 8 x 32-bit integers
    """
    # Parse block into 16 big-endian 32-bit words
    W = list(struct.unpack('>16I', block))

    # Message schedule expansion: 16 -> 64 words
    for t in range(16, 64):
        s0 = rotr(W[t-15], 7) ^ rotr(W[t-15], 18) ^ (W[t-15] >> 3)
        s1 = rotr(W[t-2], 17) ^ rotr(W[t-2], 19) ^ (W[t-2] >> 10)
        W.append((W[t-16] + s0 + W[t-7] + s1) & 0xFFFFFFFF)

    a, b, c, d, e, f, g, h = state

    # 64 rounds of mixing
    for t in range(64):
        S1  = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
        ch  = (e & f) ^ (~e & g)
        T1  = (h + S1 + ch + K[t] + W[t]) & 0xFFFFFFFF
        S0  = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
        maj = (a & b) ^ (a & c) ^ (b & c)
        T2  = (S0 + maj) & 0xFFFFFFFF

        h = g; g = f; f = e
        e = (d + T1) & 0xFFFFFFFF
        d = c; c = b; b = a
        a = (T1 + T2) & 0xFFFFFFFF

    # Davies-Meyer feed-forward
    return [(x + y) & 0xFFFFFFFF for x, y in zip(state, [a, b, c, d, e, f, g, h])]

# Verify against standard library
print(hashlib.sha256(b"abc").hexdigest())
# Expected: ba7816bf8f01cfea414140de5dae2ec73b00361bbef0469
#           32ead444d6f4da8b
```

---

## Tier 1 — Fundamentals

### Question F1
**Name and define the three security properties of a cryptographic hash function. Why is collision resistance harder to achieve than preimage resistance for a given output size?**

**Answer:**

The three properties are:

1. **Preimage resistance** (one-way): Given $y = H(x)$, it is computationally infeasible to find any $x'$ such that $H(x') = y$. An attacker must try $\Theta(2^n)$ inputs on average.

2. **Second preimage resistance** (weak collision resistance): Given a specific $x$, it is computationally infeasible to find $x' \neq x$ such that $H(x) = H(x')$. Again $\Theta(2^n)$ work for an $n$-bit hash.

3. **Collision resistance** (strong): It is computationally infeasible to find **any** pair $(x, x')$ with $x \neq x'$ and $H(x) = H(x')$.

**Why collision resistance is weaker (easier to break) than preimage resistance:**

The adversary finding a collision has far more freedom — they choose **both** inputs. The birthday paradox exploits this: after sampling $\Theta(2^{n/2})$ random inputs, the probability of any two colliding exceeds 50% (since we are counting all pairs, not matches against a specific target).

Formally: if we sample $k$ values uniformly from a set of size $N$, the expected number of colliding pairs is $\binom{k}{2}/N \approx k^2/(2N)$. Setting this to 1 gives $k = \Theta(\sqrt{N}) = \Theta(2^{n/2})$.

For SHA-256: collision search requires $\approx 2^{128}$ operations, while preimage search requires $\approx 2^{256}$ — a factor of $2^{128}$ difference.

**Implication:** A hash used for password storage (where preimage resistance matters) could use 128-bit output, but a hash used in digital signatures (where collision resistance matters) needs at least 256-bit output to provide 128-bit security. SHA-256 is sized appropriately for both.

---

### Question F2
**Explain the Merkle–Damgård construction. What is the length extension attack and which common hash functions are vulnerable?**

**Answer:**

The **Merkle–Damgård (MD) construction** builds a hash over arbitrary-length inputs from a fixed-input-length compression function $f$:

1. Pad the message $M$ to a multiple of the block size $b$. The padding always encodes the original message length (Merkle–Damgård strengthening).
2. Divide into blocks $M_1, M_2, \ldots, M_k$.
3. Iteratively apply: $H_i = f(H_{i-1}, M_i)$, starting from a fixed IV.
4. Output $H_k$.

**Length extension attack:**

The hash output $H_k$ equals the raw compression state after processing all blocks. An attacker who knows $H(M)$ and $|M|$ can:

1. Reconstruct the padding $\text{pad}(M)$ (it is deterministic given $|M|$).
2. Set their own IV to $H(M)$ (the leaked state).
3. Continue hashing any chosen suffix $S$.
4. Output $H(M \,\|\, \text{pad}(M) \,\|\, S)$ — a valid hash of a longer message — without knowing $M$.

**Vulnerable:** MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512.  
**Not vulnerable:** SHA-3 (sponge construction), BLAKE2/3, SHA-512/256 and SHA-512/224 (output is truncated, hiding the state), HMAC (double hashing prevents state recovery).

**Practical consequence:** Any MAC of the form $H(\text{key} \,\|\, \text{message})$ is broken by the length extension attack. Use HMAC or KMAC instead.

---

### Question F3
**What is the purpose of the message schedule expansion in SHA-256? Why is a simple repetition of the 16 input words not used?**

**Answer:**

SHA-256 operates for 64 rounds but receives only 16 words (512 bits) of input per block. The **message schedule** expands these 16 words to 64 distinct words $W_0, \ldots, W_{63}$:

$$
W_t = \sigma_1(W_{t-2}) + W_{t-7} + \sigma_0(W_{t-15}) + W_{t-16} \quad (t \geq 16)
$$

**Why not simply repeat the 16 words four times?**

If $W_{16} = W_0, W_{17} = W_1, \ldots$, an attacker could craft message pairs that produce structured cancellations across the rounds that use the same word. The compression function would become analysable as a periodic system.

The expansion achieves two goals:

1. **Each of the 64 round inputs depends on all 16 original message words** (after sufficient expansion steps). A single flipped bit in the input changes many of the 64 $W_t$ values.

2. **The $\sigma$ functions are non-linear within GF(2)** because they mix rotations (which move bits to different positions) with XOR. This breaks the linear structure that would otherwise make differential analysis tractable.

Together, the message schedule ensures that the 64 rounds of state mixing see non-trivially related but distinct inputs, maximising the diffusion of message bits through the state.

---

### Question F4
**Why is SHA-256 not suitable for direct use as a password hash? What algorithms should be used instead?**

**Answer:**

SHA-256 is designed for **speed** — it processes data at several GB/s on modern hardware. For password hashing, speed is the opposite of what is needed: an attacker can compute billions of SHA-256 hashes per second on a GPU, making offline dictionary and brute-force attacks practical.

**Specific problems with SHA-256 for passwords:**

1. **No work factor:** SHA-256 has a fixed cost. There is no parameter to increase computation as hardware improves.
2. **No salt by default:** Raw SHA-256 hashing allows precomputed **rainbow table** attacks — the attacker precomputes $H(p)$ for a large dictionary of passwords $p$ and looks up any matching hash in O(1) time.
3. **GPU acceleration:** SHA-256 is highly parallelisable. A modern GPU can compute $10^{10}$ SHA-256 hashes per second.

**Proper password hashing algorithms:**

| Algorithm | Memory-hard | Work Factor | Notes |
|---|---|---|---|
| **bcrypt** | No (but sequential) | Configurable cost parameter | Good; limited to 72-byte inputs |
| **scrypt** | Yes | N, r, p parameters | Memory-hard; used in Litecoin |
| **Argon2id** | Yes | time, memory, parallelism | NIST/PHC winner; recommended default |
| **PBKDF2-HMAC-SHA256** | No | Iteration count | FIPS-approved; weaker than Argon2 |

**Argon2id** is the current recommendation (RFC 9106). Its memory-hardness means an attacker with a GPU gains far less advantage over a defender using commodity RAM, because each hash attempt requires allocating large amounts of memory.

**Common mistake:** Using `HMAC(key, password)` as a password hash. HMAC is not a KDF; its cost is fixed and it is still fast.

---

## Tier 2 — Intermediate

### Question I1
**Explain the Davies–Meyer compression function. Why does the feed-forward XOR (or addition) make it one-way?**

**Answer:**

The **Davies–Meyer construction** builds a one-way compression function from a block cipher $E$:

$$
f(H, M) = E_M(H) \oplus H
$$

Here $M$ is the block cipher key, $H$ is the chaining value (and plaintext input to the cipher). In SHA-256, the feed-forward uses modular addition rather than XOR:

$$
f(H, M) = E_M(H) + H \pmod{2^{32}} \quad \text{(component-wise on 8 words)}
$$

**Why is it one-way despite $E_M$ being invertible?**

The compression function takes two inputs $(H, M)$ and produces one output. Finding a preimage means: given output $Z$, find some $(H, M)$ such that $E_M(H) + H = Z$.

Two scenarios for an attacker:
1. **Fix $H$, find $M$:** They need $E_M(H) = Z - H$, i.e., find a key $M$ such that encrypting $H$ gives a specific target. For a well-designed block cipher, this "key recovery from plaintext-ciphertext pair" problem requires $\Theta(2^k)$ operations where $k$ is the key length.

2. **Fix $M$, find $H$:** They need $E_M(H) = Z - H$. Since $E_M$ is a permutation, there is exactly one solution $H = E_M^{-1}(Z - H)$, but this is a fixed-point equation — not directly invertible.

**Without the feed-forward:** If $f(H, M) = E_M(H)$ alone, finding a preimage for $Z$ is trivial: choose any $M$, compute $H = E_M^{-1}(Z)$. The feed-forward prevents this by making the inversion step non-linear and coupling $H$ to the output.

**Common mistake:** Thinking that because a block cipher is invertible, the Davies–Meyer construction is invertible. The feed-forward addition is what breaks invertibility.

---

### Question I2
**Describe the birthday attack on collision resistance. How many hash evaluations are needed to find a collision in SHA-256 with probability 0.5?**

**Answer:**

The birthday attack is a probabilistic collision-finding algorithm based on the birthday paradox from combinatorics.

**Birthday paradox:** With $k$ people, the probability that some two share a birthday (from $N$ possibilities) is approximately:

$$
P(\text{collision}) \approx 1 - e^{-k^2 / (2N)}
$$

Setting $P = 0.5$: $k \approx \sqrt{2N \ln 2} \approx 1.17 \sqrt{N}$.

**Applied to hash functions:** An $n$-bit hash has $N = 2^n$ possible outputs. To find a collision with probability $\geq 0.5$, we need approximately:

$$
k \approx 1.17 \times 2^{n/2} \approx 2^{n/2}
$$

evaluations. For SHA-256 ($n = 256$): approximately $2^{128}$ evaluations.

**Algorithm:**
```python
# Naive birthday attack (conceptual — not feasible for SHA-256)
# For a toy hash with n=32 bits:

import hashlib, os, random

def birthday_attack_demo(bits=32):
    """
    Demonstrate a birthday collision on a truncated hash.
    For illustration only — use truncated SHA-256 as the toy hash.
    """
    seen = {}  # hash -> input
    count = 0
    while True:
        x = os.urandom(16)
        h = int.from_bytes(hashlib.sha256(x).digest(), 'big') >> (256 - bits)
        if h in seen and seen[h] != x:
            print(f"Collision found after {count} tries:")
            print(f"  x1 = {seen[h].hex()}, H = {h:#x}")
            print(f"  x2 = {x.hex()}, H = {h:#x}")
            return count
        seen[h] = x
        count += 1
```

**Memory-time trade-off (van Oorschot–Wiener):** A parallel birthday attack using a distinguished-point method can find SHA-256 collisions using $O(2^{128/3})$ memory and $O(2^{128/3})$ time per processor, but total work is still $\Theta(2^{128})$. This is why SHA-256 provides 128-bit collision security and is generally considered sufficient.

**Common mistake:** Confusing the $2^{n/2}$ collision security with the $2^n$ preimage security. A 256-bit hash gives 128-bit collision resistance and 256-bit preimage resistance.

---

### Question I3
**What are length extension attacks and why does SHA-3 (Keccak sponge) not suffer from them?**

**Answer:**

**Length extension attack:** For any hash function built on the Merkle–Damgård construction, the output $H(M)$ equals the raw internal state after processing $M \,\|\, \text{pad}(M)$. An adversary who knows $H(M)$ and $|M|$ can:

1. Reconstruct $\text{pad}(M)$ (padding is deterministic from length).
2. Initialise the hash state to $H(M)$.
3. Continue processing any chosen suffix $S$.
4. Produce $H(M \,\|\, \text{pad}(M) \,\|\, S)$ — without knowing $M$.

This breaks any MAC scheme of the form $H(\text{key} \,\|\, \text{message})$ because the tag reveals the state after processing the key, allowing extension.

**Why the Keccak sponge is immune:**

The Keccak sponge has a state of $b = 1600$ bits divided into a **rate** $r$ (publicly absorbed) and a **capacity** $c = b - r$ (secret). For SHA-3-256: $r = 1088$ bits, $c = 512$ bits.

```
Absorb phase:
  State[0..r-1] ^= message_block
  State = Keccak-f(State)   ← full 1600-bit permutation mixes rate and capacity

Squeeze phase:
  Output = State[0..255]    ← only 256 bits of the 1600-bit state are output
```

**Key difference:** The output is a 256-bit **truncation** of the 1600-bit internal state. An adversary seeing the output cannot reconstruct the full state because $1600 - 256 = 1344$ bits are hidden. Without the full state, they cannot resume the sponge computation to extend the hash.

Additionally, the capacity $c$ is never directly XORed with input — it acts as a hidden security buffer. Even if the full $r = 1088$ output bits were released, inverting the Keccak-$f$ permutation (a 1600-bit permutation with 24 rounds) is believed to require $2^{c/2} = 2^{256}$ work.

**Practical consequence:** SHA-3 can safely be used for $H(\text{key} \,\|\, \text{message})$ MACs without the length extension vulnerability, though KMAC (SHA-3-based MAC) is the recommended construction.

---

### Question I4
**What is a random oracle and how is it used in security proofs for hash-based constructions? What are the limitations of random oracle model security?**

**Answer:**

A **random oracle** is an idealised cryptographic hash function modelled as a truly random function: for each input, the output is an independently and uniformly random value, consistent across queries (the same input always returns the same output).

**Use in security proofs:**

In the random oracle model (ROM), the hash function is replaced by the random oracle $\mathcal{O}$. Security proofs show: if an adversary $\mathcal{A}$ breaks the protocol, we can construct an algorithm $\mathcal{B}$ that either (a) breaks an underlying hard problem, or (b) makes an exponential number of queries to $\mathcal{O}$.

Examples of ROM-proven constructions:
- **RSA-OAEP:** IND-CCA2 secure under the RSA assumption in the ROM.
- **RSA-PSS:** Existentially unforgeable under chosen-message attack (EUF-CMA) in the ROM.
- **ECDSA:** Security proof relies on the ROM for hash-to-scalar modelling.
- **HMAC:** Security proof requires only a PRF assumption when the ROM models the compression function.

**Limitations of ROM security:**

1. **No instantiation guarantee:** A real hash function (SHA-256) is not a random oracle — it is a fixed deterministic circuit. Canetti, Goldreich, and Halevi (1998) constructed protocols provably secure in the ROM but insecure with **any** real hash function. The ROM is an idealisation, not a cryptographic assumption.

2. **Implementation-specific attacks:** Properties like length extension do not exist for a random oracle but do exist for SHA-256. The ROM proof does not capture these structural weaknesses.

3. **Algebraic attacks:** For schemes like ECDSA, an adversary who can program the random oracle (simulate hash outputs) gains powers that do not translate to real attackers.

**Standard model alternatives:** Some constructions have proofs without ROM (e.g., Cramer–Shoup encryption is IND-CCA2 secure under DDH without ROM). These are preferred when strong provable security is required, though they tend to be less efficient.

---

## Tier 3 — Advanced

### Question A1
**Analyse the security reduction for HMAC. Under what assumptions is HMAC a PRF, and why does the double-hashing structure provide security even if the underlying hash has a length extension weakness?**

**Answer:**

**HMAC construction:**

$$
\text{HMAC}_K(M) = H\bigl((K \oplus \text{opad}) \,\|\, H((K \oplus \text{ipad}) \,\|\, M)\bigr)
$$

where $\text{ipad} = \texttt{0x36}^b$ and $\text{opad} = \texttt{0x5C}^b$, both repeated to the block length $b$.

**Security reduction (Bellare 2006):**

HMAC is a PRF if either:
1. The compression function $f$ is a PRF (sufficient for PRF security of HMAC), **or**
2. The compression function $f$ is a weakly collision-resistant PRF.

This is notable: the proof does **not** require the hash function $H$ to be collision-resistant. HMAC retains PRF security even if the outer hash has structural weaknesses, as long as the compression function is a good PRF.

**Why double hashing defends against length extension:**

In a length extension attack on $H(\text{key} \,\|\, M)$, the adversary extends by computing the compression function from the leaked state. But HMAC's inner hash output is:

$$
H_{\text{inner}} = H((K \oplus \text{ipad}) \,\|\, M)
$$

Even if the adversary could extend this (producing $H((K \oplus \text{ipad}) \,\|\, M \,\|\, \text{pad} \,\|\, S)$), that extended value is then used as **input** to the outer hash:

$$
\text{HMAC} = H((K \oplus \text{opad}) \,\|\, H_{\text{inner}})
$$

The adversary cannot compute the outer hash without knowing $K \oplus \text{opad}$ — the outer key. The outer hash acts as a one-way commitment over $H_{\text{inner}}$. Even if $H_{\text{inner}}$ could be extended, the adversary cannot forge the outer MAC without the key.

**Formal argument:** In the PRF security model, an adversary must distinguish $\text{HMAC}_K(M)$ from a truly random function. The inner hash with ipad-key behaves as a PRF (by assumption). The outer hash with opad-key then applies another PRF to the inner output. A composition of two PRFs is a PRF, giving the double-layer protection.

**Common mistake:** Believing that HMAC requires collision resistance of SHA-256. The Bellare proof showed this is not needed — PRF security of the compression function suffices.

---

### Question A2
**Explain the multicollision attack by Joux (2004) on iterated hash functions. What does it reveal about the Merkle–Damgård structure, and what is its implication for concatenated hash constructions like MD5 || SHA-1?**

**Answer:**

**Joux multicollision attack (2004):**

In a Merkle–Damgård hash with $n$-bit output and block size $b$, finding a **2-collision** (two inputs with the same hash) costs $\Theta(2^{n/2})$ by the birthday attack. Naively, one might expect a $2^k$-collision to cost $\Theta(2^{kn/2})$ — exponential in $k$.

Joux showed a $2^k$-multicollision (a set of $2^k$ inputs all hashing to the same value) costs only $k \cdot 2^{n/2}$ — **linear** in $k$.

**Construction:**
For each stage $i = 1, \ldots, k$:
1. Starting from the current chaining value $H_{i-1}$, find two message blocks $M_i^0$ and $M_i^1$ such that $f(H_{i-1}, M_i^0) = f(H_{i-1}, M_i^1) = H_i$. Cost: $\Theta(2^{n/2})$ by birthday attack.
2. Advance to $H_i$.

After $k$ stages, any combination of choices $(b_1, b_2, \ldots, b_k) \in \{0,1\}^k$ produces a distinct message $M^{b_1} \,\|\, M^{b_2} \,\|\, \cdots \,\|\, M^{b_k}$ that hashes to the same final chaining value $H_k$. Total cost: $k \cdot 2^{n/2}$.

**Implication for concatenated hashes (MD5 || SHA-1):**

Preneel and van Rooij proposed $H_1(M) \,\|\, H_2(M)$ (concatenate two independent hash outputs) as a way to combine security — presumably requiring $2^{(n_1 + n_2)/2}$ for a collision.

Joux showed this is false for Merkle–Damgård hashes:

1. Use the multicollision attack to generate $2^{n_2/2}$ messages all colliding in $H_1$ (MD5). Cost: $\frac{n_2}{2} \cdot 2^{n_1/2}$.
2. By the birthday bound, among $2^{n_2/2}$ messages, a collision in $H_2$ (SHA-1) exists with constant probability. Finding it costs $\Theta(2^{n_2/2})$.

Total cost: $\Theta(n_2 \cdot 2^{n_1/2} + 2^{n_2/2})$, which for MD5 ($n_1 = 128$) || SHA-1 ($n_2 = 160$) is $\Theta(2^{80})$ — far less than the expected $2^{144}$.

**Lesson:** Security of concatenated Merkle–Damgård hashes is not the sum of their individual securities. The structured multicollision property of the MD construction makes the concatenation far weaker than expected. This is why MD5 || SHA-1 was removed from TLS and why SHA-3 (sponge construction) does not have this multicollision weakness.

---

### Question A3
**Discuss the Merkle tree hash construction. How does it enable parallel hashing and provide position-binding security? Where is it used in practice?**

**Answer:**

A **Merkle tree** is a binary tree where:
- Each leaf node contains the hash of a data block: $L_i = H(\text{block}_i)$.
- Each internal node contains the hash of its children: $N = H(N_{\text{left}} \,\|\, N_{\text{right}})$.
- The **Merkle root** is the hash at the top of the tree.

```
                Root = H(N01 || N23)
               /                    \
    N01 = H(L0 || L1)      N23 = H(L2 || L3)
      /          \            /           \
  L0=H(b0)  L1=H(b1)   L2=H(b2)   L3=H(b3)
```

**Parallel hashing:** All leaf hashes can be computed independently and simultaneously. Internal node computation only requires their two children. For $n$ blocks on a machine with $p$ processors, the parallel time is $O((n/p) + \log n)$, compared to $O(n)$ for sequential Merkle–Damgård. For large files, this can provide near-linear speedup with multiple cores. BLAKE3 uses a Merkle tree internally for this reason.

**Position-binding (Merkle inclusion proofs):**

To prove block $i$ is in the tree without revealing all blocks, provide:
- The leaf $L_i = H(\text{block}_i)$
- The **sibling hashes** along the path from $L_i$ to the root (the authentication path)

The verifier recomputes the root from $L_i$ and the sibling path. If it matches the trusted root, the block is authenticated. This requires $O(\log n)$ hashes — efficient for $n = 2^{20}$ blocks.

**Position-binding security:** An adversary cannot produce a valid proof for a fake block at position $i$ without finding a collision in $H$. Since the root uniquely commits to all leaf positions, substituting any block changes the root (with overwhelming probability). This relies on second preimage resistance.

**Second preimage binding property:** The tree hash resists second preimage attacks more efficiently than sequential MD hashing. For a tree of depth $d$, finding a second preimage costs $\Theta(d \cdot 2^{n/2})$ — linear in tree depth — rather than $\Theta(2^n)$, but note this is a second preimage against the adversary choosing the internal node to attack, not against the fixed root.

**Practical deployments:**

| System | Use |
|---|---|
| **Bitcoin** | Each block header commits to transactions via a Merkle root |
| **Git** | Object DAG uses SHA-1 (transitioning to SHA-256) tree hashing |
| **Certificate Transparency** | Logs use Merkle trees for tamper-evidence and inclusion proofs |
| **BLAKE3** | Internal Merkle tree enables parallel hashing and arbitrary output length |
| **Ethereum** | Merkle Patricia trie for state commitment |
| **TLS Certificate Transparency** | Signed Certificate Timestamps backed by Merkle inclusion proofs |

The key advantage over a flat sequential hash is that inclusion proofs are $O(\log n)$ rather than $O(n)$, enabling scalable verification without revealing the full dataset.
