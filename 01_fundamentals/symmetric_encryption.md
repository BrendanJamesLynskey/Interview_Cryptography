# Symmetric Encryption

## Prerequisites
- Binary and hexadecimal number systems
- Basic linear algebra over finite fields (helpful but not required for Tier 1)
- Understanding of block vs. stream data processing
- XOR operation and its cryptographic significance

---

## Concept Reference

### What is Symmetric Encryption?

Symmetric encryption uses the **same key** for both encryption and decryption. The security model is: even if an adversary knows the algorithm completely, they cannot recover the plaintext without possessing the secret key.

Two fundamental categories exist:

- **Block ciphers**: Process fixed-size blocks (e.g., AES operates on 128-bit blocks). The algorithm is deterministic: the same key and plaintext always produce the same ciphertext block.
- **Stream ciphers**: Generate a keystream and XOR it with plaintext bit by bit. AES in CTR mode effectively converts a block cipher into a stream cipher.

The dominant standard today is **AES (Advanced Encryption Standard)**, standardised by NIST in 2001 from the Rijndael submission.

---

### AES Overview

AES operates on a fixed **128-bit block** with key sizes of 128, 192, or 256 bits. Internally, the 128-bit block is treated as a **4x4 matrix of bytes** called the **State**.

```
Plaintext bytes: b0  b1  b2  b3  b4  b5  ...  b15

State matrix (column-major order):
  | b0  b4  b8   b12 |
  | b1  b5  b9   b13 |
  | b2  b6  b10  b14 |
  | b3  b7  b11  b15 |
```

AES-128 performs **10 rounds**; AES-192 performs 12; AES-256 performs 14. Each round (except the final) applies four transformations in sequence.

---

### The Four AES Round Transformations

#### 1. SubBytes

SubBytes is a **non-linear byte substitution** applied to every byte of the State independently. Each byte is replaced by a value looked up from the **AES S-Box** — a fixed 256-entry lookup table.

The S-Box is constructed in two steps over $\text{GF}(2^8)$:

1. **Multiplicative inverse**: Replace each byte $b$ with $b^{-1}$ in $\text{GF}(2^8)$ (the byte $\texttt{0x00}$ maps to itself).
2. **Affine transformation**: Apply the affine map over $\text{GF}(2)$:

$$
s_i = b_i \oplus b_{(i+4) \bmod 8} \oplus b_{(i+5) \bmod 8} \oplus b_{(i+6) \bmod 8} \oplus b_{(i+7) \bmod 8} \oplus c_i
$$

where $c = \texttt{0x63} = \texttt{01100011}_2$.

**Why non-linearity matters:** XOR is linear over $\text{GF}(2)$. Without a non-linear component, AES would be a linear system solvable with Gaussian elimination. SubBytes is the sole source of non-linearity in AES; its algebraic complexity prevents simple algebraic attacks.

The inverse S-Box (used during decryption) reverses the affine transformation and applies the multiplicative inverse again.

```
Example S-Box lookups:
  SubBytes(0x00) = 0x63
  SubBytes(0x53) = 0xED
  SubBytes(0xFF) = 0x16
```

#### 2. ShiftRows

ShiftRows performs a **cyclic left rotation** on each row of the 4x4 State matrix:

- Row 0: rotated left by 0 bytes (unchanged)
- Row 1: rotated left by 1 byte
- Row 2: rotated left by 2 bytes
- Row 3: rotated left by 3 bytes

```
Before ShiftRows:        After ShiftRows:
| s00  s01  s02  s03 |   | s00  s01  s02  s03 |
| s10  s11  s12  s13 |   | s11  s12  s13  s10 |
| s20  s21  s22  s23 |   | s22  s23  s20  s21 |
| s30  s31  s32  s33 |   | s33  s30  s31  s32 |
```

**Why ShiftRows is necessary:** Without it, the MixColumns step would operate on each column independently and never mix bytes from different columns. ShiftRows ensures that each output byte after both ShiftRows and MixColumns depends on bytes from every column of the input. Combined with MixColumns, it achieves **diffusion across all 16 bytes** within two rounds.

Inverse ShiftRows rotates each row right by the same amounts.

#### 3. MixColumns

MixColumns treats each **column** of the State as a degree-3 polynomial over $\text{GF}(2^8)$ and multiplies it by a fixed polynomial:

$$
a(x) = \texttt{03} \cdot x^3 + \texttt{01} \cdot x^2 + \texttt{01} \cdot x + \texttt{02}
$$

modulo $x^4 + 1$.

In matrix form, each column $[s_0, s_1, s_2, s_3]^T$ is transformed as:

$$
\begin{pmatrix} s'_0 \\ s'_1 \\ s'_2 \\ s'_3 \end{pmatrix}
=
\begin{pmatrix}
\texttt{02} & \texttt{03} & \texttt{01} & \texttt{01} \\
\texttt{01} & \texttt{02} & \texttt{03} & \texttt{01} \\
\texttt{01} & \texttt{01} & \texttt{02} & \texttt{03} \\
\texttt{03} & \texttt{01} & \texttt{01} & \texttt{02}
\end{pmatrix}
\begin{pmatrix} s_0 \\ s_1 \\ s_2 \\ s_3 \end{pmatrix}
$$

All arithmetic is in $\text{GF}(2^8)$ with irreducible polynomial $x^8 + x^4 + x^3 + x + 1$ (hex: $\texttt{0x11B}$).

Multiplication by $\texttt{02}$ in $\text{GF}(2^8)$ is a left shift by one bit; if the high bit was 1, XOR with $\texttt{0x1B}$ (the low 8 bits of $\texttt{0x11B}$).

**Why MixColumns is necessary:** ShiftRows rearranges bytes but does not mix their values. MixColumns ensures that each output byte is a linear combination of all four input bytes in the same column, providing **confusion** (in Shannon's sense). The matrix is chosen to be **MDS (Maximum Distance Separable)**, guaranteeing that any non-zero input to a column produces at least 5 non-zero output bytes across the combined ShiftRows+MixColumns step (the "wide trail" strategy).

MixColumns is **not applied in the final round** of AES, which simplifies the hardware and software implementation of decryption.

#### 4. AddRoundKey

AddRoundKey is a simple **bitwise XOR** of the State with a 128-bit round key derived from the key schedule:

$$
s'_{i,j} = s_{i,j} \oplus k_{i,j}
$$

Every round, including the initial "round 0" (before any SubBytes/ShiftRows/MixColumns), uses a different 128-bit round key.

**Why AddRoundKey works:** XOR with a secret key makes every intermediate state unpredictable to an attacker who does not know the key. This is the only step that involves the key; removing AddRoundKey would leave AES as a fixed public permutation. It also means AES is its own inverse in this step: applying AddRoundKey twice with the same subkey restores the original value.

---

### AES Key Schedule

The key schedule **expands** a single short key into a sequence of round keys — one 128-bit key per round, plus one for the initial AddRoundKey.

For **AES-128** (10 rounds), this produces 11 round keys (1408 bits total) from 128 bits of key material.

The key schedule operates on **32-bit words**. The original key is split into 4 words $W[0], W[1], W[2], W[3]$. Each subsequent group of 4 words is derived as:

```
For i = 4 to 43:
    temp = W[i-1]
    if i mod 4 == 0:
        temp = SubWord(RotWord(temp)) XOR Rcon[i/4]
    W[i] = W[i-4] XOR temp
```

Where:
- **RotWord**: rotate the 4-byte word left by one byte: $[a, b, c, d] \to [b, c, d, a]$
- **SubWord**: apply the AES S-Box to each of the four bytes independently
- **Rcon[i]**: round constant, equal to $[2^{i-1} \bmod \text{GF}(2^8),\ 0x00,\ 0x00,\ 0x00]$

The Rcon values for AES-128 are:

```
Rcon[1]  = 0x01000000
Rcon[2]  = 0x02000000
Rcon[3]  = 0x04000000
Rcon[4]  = 0x08000000
Rcon[5]  = 0x10000000
Rcon[6]  = 0x20000000
Rcon[7]  = 0x40000000
Rcon[8]  = 0x80000000
Rcon[9]  = 0x1B000000
Rcon[10] = 0x36000000
```

**Why Rcon?** Without round constants, $W[i] = W[i-4] \oplus f(W[i-1])$ would have structural symmetry. If all key bytes were identical, many round keys would also be identical. Rcon breaks this symmetry and ensures that similar keys produce different round key sequences, preventing related-key attacks.

**AES-256 key schedule** uses a slightly different structure: every 4th word (where $i \bmod 8 = 0$) applies RotWord+SubWord+Rcon, and every 8th word (where $i \bmod 8 = 4$) applies SubWord only, adding one more non-linearity injection.

---

### Block Cipher Modes of Operation

A raw block cipher (AES) is a **pseudorandom permutation**: it maps a 128-bit block to a 128-bit block deterministically. This alone is not sufficient for secure encryption of real messages because:

1. Messages are longer than 128 bits.
2. The block cipher is deterministic — the same plaintext block always produces the same ciphertext block.

Modes of operation solve both problems.

#### ECB — Electronic Codebook

$$
C_i = E_K(P_i)
$$

Each plaintext block is encrypted independently with the same key.

**Security: BROKEN for most uses.** Identical plaintext blocks produce identical ciphertext blocks, leaking structural information. The canonical demonstration is encrypting a bitmap image: ECB encryption preserves the outline of the original image because uniform colour regions produce repeated ciphertext blocks.

ECB is only appropriate for encrypting a single, unique, random block (e.g., a single key wrap operation).

#### CBC — Cipher Block Chaining

$$
C_i = E_K(P_i \oplus C_{i-1}), \quad C_0 = \text{IV}
$$

Each plaintext block is XORed with the previous ciphertext block before encryption. An **Initialisation Vector (IV)** is used for the first block.

**Properties:**
- IV must be random and unpredictable (though not secret) for each message.
- Encryption is **sequential** (cannot be parallelised); decryption can be parallelised.
- A single-bit error in ciphertext block $C_i$ corrupts block $P_i$ completely and flips the corresponding bit in $P_{i+1}$.
- Padding is required to fill the last block (e.g., PKCS#7 padding).

**Vulnerabilities:** BEAST attack (CBC padding oracle with predictable IV in TLS 1.0), POODLE (padding oracle in SSLv3/CBC), Lucky 13 (timing side-channel in CBC-MAC verification).

#### CTR — Counter Mode

$$
C_i = P_i \oplus E_K(\text{nonce} \,\|\, i)
$$

A counter (nonce concatenated with a block counter) is encrypted to produce a keystream block, which is then XORed with the plaintext.

**Properties:**
- Converts AES into a **synchronous stream cipher**.
- Encryption and decryption are **identical operations** (XOR is its own inverse).
- Fully **parallelisable** in both directions.
- No padding required (keystream bytes can be generated to exact message length).
- **Critical security requirement:** The nonce must never be reused with the same key. Nonce reuse reveals the XOR of two plaintexts directly.

CTR is widely used in practice and is the foundation of GCM.

#### GCM — Galois/Counter Mode

GCM combines CTR mode encryption with a **GHASH** authentication tag, providing **Authenticated Encryption with Associated Data (AEAD)**:

$$
T = \text{GHASH}_H(A \,\|\, C) \oplus E_K(\text{nonce} \,\|\, 0)
$$

Where:
- $H = E_K(0^{128})$ is the **hash subkey** (AES applied to an all-zero block)
- $A$ is **associated data** (authenticated but not encrypted, e.g., packet headers)
- $C$ is the ciphertext
- $T$ is the **authentication tag** (typically 96 or 128 bits)

GHASH is a polynomial evaluation over $\text{GF}(2^{128})$:

$$
\text{GHASH}_H(X) = \bigoplus_{i} X_i \cdot H^{k-i+1}
$$

**Properties:**
- Single-pass authentication: both confidentiality and integrity with one key.
- Parallelisable (GHASH blocks are independent given $H$).
- **Critical nonce requirement:** Nonce (IV) must be exactly 96 bits for the standard construction (a different derivation is used for other lengths). Nonce reuse in GCM is **catastrophic**: it reveals $H$, which allows the attacker to forge arbitrary ciphertexts.
- TLS 1.3 mandates AES-128-GCM or AES-256-GCM as the primary AEAD cipher suites.

```
Mode comparison summary:
  Mode   Parallelise-Enc  Parallelise-Dec  Auth  Padding  Nonce-reuse consequence
  ECB    Yes              Yes              No    Yes      Structural leakage
  CBC    No               Yes              No    Yes      Padding oracle
  CTR    Yes              Yes              No    No       Plaintext XOR revealed
  GCM    Yes              Yes              Yes   No       Key forgery possible
```

---

## Tier 1 — Fundamentals

### Question F1
**What are the four transformations in a single AES round and what is the purpose of each?**

**Answer:**

| Transformation | Purpose |
|----------------|---------|
| SubBytes | Introduces non-linearity by substituting each byte via the S-Box. Without this, AES would be a linear system. |
| ShiftRows | Provides inter-column diffusion by cyclically rotating rows, ensuring bytes from all columns are mixed by MixColumns. |
| MixColumns | Provides intra-column diffusion: each output byte depends linearly on all four input bytes in the column. Not applied in the final round. |
| AddRoundKey | Incorporates the secret key material via XOR. This is the only keyed step. |

The final round of AES **omits MixColumns**. This does not weaken security — it is balanced by the key schedule — but it makes decryption more straightforward to implement.

**Common mistake:** Stating that MixColumns provides non-linearity. It does not; it is entirely linear over $\text{GF}(2^8)$. All non-linearity comes from SubBytes alone.

---

### Question F2
**Why is ECB mode insecure for most applications? Give a concrete example.**

**Answer:**

In ECB mode, every 128-bit plaintext block is encrypted independently with the same key:

$$
C_i = E_K(P_i)
$$

Because the mapping is deterministic and key-dependent but otherwise context-free, **identical plaintext blocks always produce identical ciphertext blocks**. An attacker can observe this pattern without knowing the key.

Concrete example — image encryption: If you encrypt a 24-bit bitmap image with ECB mode, regions of uniform colour (e.g., a solid background) consist of many identical plaintext blocks. These map to many identical ciphertext blocks. Viewing the ciphertext as an image reveals the outlines and shapes of the original picture.

Practical consequence: ECB leaks **which blocks are the same**. In a login system storing ECB-encrypted passwords, two users with the same password produce identical ciphertext, allowing correlation. An attacker who knows their own plaintext can detect if another user has the same plaintext.

ECB is safe only when encrypting a **single random block** or when the plaintext is guaranteed to never contain repeated blocks — a condition that is extremely difficult to guarantee in practice.

---

### Question F3
**What is the role of the Initialisation Vector (IV) in CBC mode? What happens if the same IV is reused?**

**Answer:**

In CBC mode:

$$
C_1 = E_K(P_1 \oplus \text{IV})
$$

The IV ensures that two encryptions of the **same plaintext** under the **same key** produce **different ciphertexts**. Without an IV (or with IV = 0), encrypting the same message twice gives the identical ciphertext, revealing that the messages are equal and allowing offline dictionary attacks.

**Requirements for the IV:**
- Must be **unpredictable** (ideally uniformly random) for each encryption.
- Does not need to be secret — it is typically transmitted alongside the ciphertext.
- Must be exactly one block (128 bits for AES).

**Consequence of IV reuse:** If the same IV and key are used for two messages $P$ and $P'$, the first ciphertext blocks are $C_1 = E_K(P_1 \oplus \text{IV})$ and $C'_1 = E_K(P'_1 \oplus \text{IV})$. An attacker who observes $C_1 = C'_1$ immediately knows $P_1 = P'_1$. More seriously, the **BEAST attack** exploited the fact that TLS 1.0 used the previous message's last ciphertext block as the IV for the next message, allowing a chosen-plaintext attacker to recover plaintext byte by byte.

---

### Question F4
**How many round keys does AES-128 require and how are they produced?**

**Answer:**

AES-128 requires **11 round keys** of 128 bits each (one for the pre-round AddRoundKey and one for each of the 10 rounds), totalling 1408 bits expanded from the original 128-bit key.

The key schedule expands the key as 44 words of 32 bits each ($W[0]$ through $W[43]$). The initial key supplies $W[0]$–$W[3]$. Each subsequent word is derived as:

```
W[i] = W[i-4] XOR g(W[i-1])    when i mod 4 == 0
W[i] = W[i-4] XOR W[i-1]       otherwise
```

Where $g(W) = \text{SubWord}(\text{RotWord}(W)) \oplus \text{Rcon}[i/4]$.

Round key $n$ is assembled from words $W[4n]$ through $W[4n+3]$.

---

### Question F5
**What is the difference between CTR and CBC mode with respect to parallelism and error propagation?**

**Answer:**

| Property | CBC | CTR |
|----------|-----|-----|
| Encryption parallelism | No — $C_i$ depends on $C_{i-1}$ | Yes — each keystream block is independent |
| Decryption parallelism | Yes — given $C_{i-1}$, decryption of $P_i$ is independent | Yes |
| Error propagation | 1-bit error in $C_i$ corrupts all of $P_i$ and flips 1 bit in $P_{i+1}$ | 1-bit error in $C_i$ flips only the corresponding bit in $P_i$ |
| Padding required | Yes (last block must be padded to 128 bits) | No (keystream trimmed to message length) |
| IV/nonce reuse consequence | Leaks whether first blocks are equal | Reveals XOR of two plaintexts |

CTR's complete parallelisability makes it superior for high-throughput applications and hardware pipelines. CBC encryption is inherently serial, limiting throughput to one AES operation per block latency.

---

## Tier 2 — Intermediate

### Question I1
**Describe the algebraic structure of the AES S-Box. Why is multiplicative inversion chosen as the first step rather than, say, a random permutation?**

**Answer:**

The S-Box is not arbitrary. It is constructed algebraically over $\text{GF}(2^8)$ to achieve specific, provable security properties:

**Step 1 — Multiplicative inverse in $\text{GF}(2^8)$:**

Every non-zero element $b \in \text{GF}(2^8)$ maps to $b^{-1}$. The zero element maps to zero (a convention). The multiplicative inverse has maximum **algebraic degree** over $\text{GF}(2)$: degree 7 in each bit. This maximises the non-linearity of the S-Box as measured by its Walsh–Hadamard transform, giving it the best possible resistance to **linear cryptanalysis**.

**Step 2 — Affine transformation over $\text{GF}(2)$:**

The affine map ensures the S-Box has no fixed points ($S(x) = x$ for no $x$) and no "inverse fixed points" ($S(x) = \bar{x}$ for no $x$). This prevents trivially weak inputs and provides good **differential uniformity** (resistance to differential cryptanalysis).

**Why not a random permutation?** A random 8-bit permutation could not be proven to have good cryptographic properties. The algebraic construction guarantees:
- Non-linearity $\geq 112$ out of a maximum 128 (measured as minimum distance from all affine functions)
- Differential uniformity of 4 (the AES S-Box achieves the theoretical minimum for bijective GF(2^8) functions)
- Resistance to interpolation attacks by having a provably complex algebraic expression

The downside is that the algebraic structure is known, which contributed to the XSL (eXtended Sparse Linearisation) attack proposal, though XSL has not broken AES in practice.

---

### Question I2
**Explain the "wide trail" strategy and how ShiftRows and MixColumns together implement it in AES.**

**Answer:**

The **wide trail strategy** (Daemen and Rijmen, the AES designers) is a framework for proving resistance to both differential and linear cryptanalysis by ensuring a **minimum number of "active" S-Boxes** across any two consecutive rounds.

**Key definitions:**
- An S-Box is **active** in a differential attack if its input difference is non-zero.
- The **branch number** of a linear transformation is: $\min_{a \neq 0}(\text{wt}(a) + \text{wt}(L(a)))$, where $\text{wt}$ is the number of non-zero bytes.

**MixColumns has branch number 5.** This means any non-zero column input will produce a column output with at least 5 total active bytes between input and output (combined). The MDS property of the mixing matrix guarantees this.

**How ShiftRows and MixColumns work together:**

1. After ShiftRows, bytes from different columns are interleaved into the same column.
2. MixColumns then ensures each active byte in any column propagates to affect multiple bytes in the next round.

The minimum number of active S-Boxes across **two rounds** of AES is 25. Since the best differential characteristic for one S-Box has probability at most $2^{-6}$, any four-round differential characteristic has probability at most $2^{-150}$, far below the security threshold for a 128-bit key.

In practice, the 10-round AES-128 has a security margin orders of magnitude beyond what can be reached with current differential or linear cryptanalytic techniques.

---

### Question I3
**What is a padding oracle attack and which AES mode is most vulnerable to it?**

**Answer:**

A **padding oracle attack** exploits a system that reveals (through error messages, timing, or other side channels) whether a decrypted ciphertext has **valid padding** after decryption.

**CBC mode with PKCS#7 padding** is the classic target.

PKCS#7 padding appends $n$ bytes each with value $n$ to make the plaintext a multiple of the block size. Valid paddings: `...01`, `...02 02`, `...03 03 03`, etc.

**Attack mechanism:**

CBC decryption is:

$$
P_i = D_K(C_i) \oplus C_{i-1}
$$

If an attacker can submit modified ciphertexts and observe valid/invalid padding:

1. To recover byte $j$ of $P_i$, the attacker manipulates the corresponding byte of $C_{i-1}$.
2. They try all 256 values for that byte until the oracle returns "valid padding" (indicating the decrypted byte equals the padding value 0x01 for a single-byte pad).
3. The attacker then knows $D_K(C_i)_j = \texttt{0x01} \oplus C'_{i-1,j}$, and since $C_{i-1,j}$ is known, they can compute $P_{i,j}$.
4. This proceeds byte by byte; each byte requires at most 256 oracle queries.

**Total queries:** At most $256 \times 16 = 4096$ per 16-byte block. This recovers all plaintext bytes.

**Real-world examples:** POODLE (SSLv3), Lucky 13 (timing oracle in TLS), ASP.NET padding oracle CVE-2010-3332.

**Mitigations:**
- Use AEAD modes (GCM) instead of CBC with separate MAC.
- If CBC must be used: MAC-then-Encrypt is vulnerable; use **Encrypt-then-MAC**.
- Constant-time padding verification to eliminate timing oracles.

---

### Question I4
**Describe the GCM authentication mechanism. Why is nonce reuse in GCM more catastrophic than in CTR mode?**

**Answer:**

**GCM authentication** uses a polynomial MAC over $\text{GF}(2^{128})$:

$$
H = E_K(0^{128})
$$

The GHASH function evaluates a polynomial in $H$:

$$
\text{GHASH}_H(A, C) = A_1 H^{m+n+1} \oplus \cdots \oplus A_m H^{n+2} \oplus C_1 H^{n+1} \oplus \cdots \oplus C_n H^2 \oplus L \cdot H
$$

where $L$ encodes the lengths of $A$ and $C$, and $m$, $n$ are the block counts of associated data and ciphertext.

The final tag is:

$$
T = \text{GHASH}_H(A, C) \oplus E_K(\text{nonce} \,\|\, 0^{32})
$$

**Why nonce reuse in GCM is catastrophic:**

In **CTR mode** with a reused nonce:
- The same keystream is XORed with both messages.
- An attacker observing $C_1 = P_1 \oplus \text{KS}$ and $C_2 = P_2 \oplus \text{KS}$ can compute $C_1 \oplus C_2 = P_1 \oplus P_2$.
- This is bad, but requires knowing one plaintext to recover the other.

In **GCM** with a reused nonce, the **hash subkey $H$ can be recovered:**

If the same nonce is used for two authentications:

$$
T_1 = \text{GHASH}_H(A_1, C_1) \oplus E_K(\text{nonce} \,\|\, 0)
$$
$$
T_2 = \text{GHASH}_H(A_2, C_2) \oplus E_K(\text{nonce} \,\|\, 0)
$$

Since the last term is identical:

$$
T_1 \oplus T_2 = \text{GHASH}_H(A_1, C_1) \oplus \text{GHASH}_H(A_2, C_2)
$$

This is a polynomial equation in $H$ over $\text{GF}(2^{128})$. With enough nonce-reuse observations, $H$ can be solved for. Once $H$ is known, the attacker can **forge authentication tags for arbitrary messages**, completely breaking the integrity guarantee.

This attack was demonstrated against GCM with short tags and nonce reuse in the "Nonce-Disrespecting Adversary" paper (Joux, 2006; Böck et al., 2016). The consequence is not just confidentiality loss but **complete authentication bypass**.

---

## Tier 3 — Advanced

### Question A1
**An AES-256 implementation is suspected of being vulnerable to a related-key attack. Explain what related-key attacks are, why AES-256's key schedule is more susceptible than AES-128's, and what practical implications this has.**

**Answer:**

**Related-key attacks** are a class of attacks where the adversary can observe encryptions under multiple keys that have a known, structured mathematical relationship (e.g., they differ in a known subset of bits). This is distinct from single-key attacks; the adversary must be able to control or predict the key relationship.

**AES-128 vs AES-256 key schedule vulnerability:**

AES-128's key schedule has been shown to have no related-key distinguishers up to 9 rounds (and the full 10-round cipher is secure in the single-key model). However:

- **AES-256** was shown by Biryukov and Khovratovich (2009) to have a **related-key boomerang attack** requiring $2^{99.5}$ time and $2^{99.5}$ related-key queries — significantly better than $2^{256}$ brute force.
- The attack exploits **slow diffusion in the AES-256 key schedule**: the 256-bit key is divided into two 128-bit halves $K_0$ and $K_1$. In alternate rounds, SubWord is applied only to the last word of $K_0$ (not $K_1$). This creates a structural weakness where related-key differences diffuse slowly across round keys.
- AES-128's key schedule, while simpler, generates new round key material more quickly relative to the total key length.

**Why this weakness exists in AES-256:**

The AES designers extended the key schedule from 128 to 256 bits primarily by expanding the number of key words, without fundamentally redesigning the schedule structure. This left the schedule with weaker diffusion per bit of key material in the 256-bit variant.

**Practical implications:**

In practice, the related-key attack on AES-256 requires:
1. The adversary must **control the key relationship** — possible in some protocol designs (e.g., key derivation schemes that use AES in a Davies-Meyer construction, WPA/TKIP-like key mixing).
2. Nearly $2^{100}$ queries — computationally infeasible today.

For standard single-key TLS/storage encryption, AES-256 provides 256-bit security. The attack matters in:
- **Hash-from-cipher constructions** (AES used in a block cipher-based hash)
- **Key agreement protocols** where key relationships might be structurally predictable
- **Formal security proofs** that require security in the related-key model (e.g., some PRF constructions)

The NIST competition successor AES-256 remains approved for all use cases; the attack does not threaten practical deployments. However, it motivates the use of **properly designed key derivation functions** rather than using raw keys in constructions that expose related-key interfaces.

---

### Question A2
**Describe how AES can be implemented entirely as table lookups (the T-table implementation). What is the performance benefit and what side-channel vulnerability does this create?**

**Answer:**

**T-table (lookup table) implementation:**

A full AES round (SubBytes + ShiftRows + MixColumns + AddRoundKey) can be precomputed into four tables $T_0, T_1, T_2, T_3$, each of $256 \times 32$-bit entries (4 KB per table, 16 KB total):

```c
// Each T-table entry precomputes the contribution of one byte position
// through SubBytes, ShiftRows, and MixColumns simultaneously.

// T0[a] = MixColumns contribution of SubBytes(a) as column byte 0
// T1[a] = MixColumns contribution of SubBytes(a) as column byte 1
// T2[a] = MixColumns contribution of SubBytes(a) as column byte 2
// T3[a] = MixColumns contribution of SubBytes(a) as column byte 3

// One complete round:
s'[0] = T0[s[0]] ^ T1[s[5]] ^ T2[s[10]] ^ T3[s[15]] ^ RK[0];
s'[1] = T0[s[4]] ^ T1[s[9]] ^ T2[s[14]] ^ T3[s[3]]  ^ RK[1];
s'[2] = T0[s[8]] ^ T1[s[13]]^ T2[s[2]]  ^ T3[s[7]]  ^ RK[2];
s'[3] = T0[s[12]]^ T1[s[1]] ^ T2[s[6]]  ^ T3[s[11]] ^ RK[3];
```

This reduces one AES round to **16 table lookups** and **12 XOR operations** — extremely fast on 32-bit and 64-bit CPUs.

**Performance benefit:** On a CPU without AES-NI, the T-table implementation achieves roughly **2–5 cycles per byte** on modern x86-64, compared to ~10–20 cycles for a bitsliced or byte-substitution implementation. For AES-128 on a 3 GHz CPU, this translates to roughly 2–4 GB/s throughput.

**Cache-timing side-channel vulnerability:**

The T-table lookups are indexed by bytes of the AES state. Modern CPUs have L1 data caches of 32–64 KB. The 16 KB of T-tables may not fit entirely in cache lines accessed by a given process, and the **cache line loaded depends on the table index** — which depends on the key.

An attacker sharing the same CPU (e.g., on a virtualised server, or via JavaScript in a browser) can:
1. Flush the T-table cache lines (using clflush or memory pressure).
2. Allow the AES encryption to proceed.
3. Measure which cache lines were loaded (using Flush+Reload or Prime+Probe timing measurements).
4. The cache access pattern leaks **which table entries were accessed**, which leaks information about the key bytes.

**Bernstein's 2005 attack** demonstrated remote cache-timing attacks on AES T-table implementations over a network, recovering the full key with roughly $2^{28}$ timing measurements.

**Mitigations:**
1. **AES-NI hardware instructions**: Intel/AMD AES-NI (since ~2010) perform AES rounds as single instructions in constant time, with no data-dependent memory accesses. This eliminates the cache-timing vulnerability entirely.
2. **Bitsliced AES**: Implement AES operating on 128 blocks in parallel using only bitwise logic operations. No memory accesses with data-dependent addresses. Slower on single-block throughput but immune to cache timing.
3. **Constant-time software AES**: Implement SubBytes using arithmetic rather than table lookups (slower but portable and timing-safe).

In any security-sensitive context, AES-NI should always be preferred over software T-table AES if available.

---

### Question A3
**Compare AES-GCM and ChaCha20-Poly1305 as AEAD ciphers. In what environments is each preferred and why?**

**Answer:**

Both are **AEAD (Authenticated Encryption with Associated Data)** schemes standardised in TLS 1.3 and widely deployed. They provide equivalent security properties — IND-CCA2 security — but differ in design, performance characteristics, and implementation risk.

**AES-GCM:**

```
Encryption: CTR mode with AES
Authentication: GHASH polynomial MAC over GF(2^128)
Key sizes: 128 or 256 bits
Nonce: 96 bits (recommended)
Tag: 128 bits (standard), 96 bits (acceptable with care)
```

Performance depends heavily on hardware support:
- **With AES-NI + PCLMULQDQ** (carry-less multiply for GHASH): ~0.5–1 cycle/byte on modern x86-64
- **Without hardware acceleration** (e.g., microcontrollers, old CPUs): much slower; T-table AES is timing-vulnerable

Security risk: **Nonce reuse completely breaks authentication** (recovering $H$ allows tag forgery). Short tags (e.g., 32-bit truncated GCM) are weak against forgery attacks.

**ChaCha20-Poly1305:**

```
Encryption: ChaCha20 stream cipher (ARX design: Add-Rotate-XOR)
Authentication: Poly1305 MAC
Key size: 256 bits
Nonce: 96 bits
Tag: 128 bits
```

Performance:
- **Without special hardware**: ~1–2 cycles/byte on x86-64, using only 32-bit integer operations
- No data-dependent memory accesses in the core algorithm — inherently timing-safe
- Highly efficient on **ARM, MIPS, embedded processors** that lack AES-NI

Security risk: Nonce reuse in ChaCha20-Poly1305 leaks the XOR of plaintexts (bad) but does not provide tag forgery capability (better than GCM nonce reuse).

**When to prefer each:**

| Context | Preferred | Reason |
|---------|-----------|--------|
| x86-64 server with AES-NI | AES-GCM | Faster; hardware-accelerated |
| Mobile (ARM with AES instructions) | AES-GCM | ARM Cortex-A has AES extensions since ARMv8 |
| Embedded (ARM Cortex-M0, MIPS) | ChaCha20-Poly1305 | No AES hardware; ChaCha20 is faster and constant-time |
| Environment where AES-NI is unavailable | ChaCha20-Poly1305 | Timing-safe without special hardware |
| Systems requiring FIPS 140 compliance | AES-GCM | AES and GHASH are NIST-approved; ChaCha20 is not in FIPS 140-2 (approved in FIPS 140-3) |
| Key commitment required | Neither directly — add BLAKE3 or HKDF pre-processing | Both are malleable under key commitment requirements |

In TLS 1.3, both are mandatory cipher suites. Clients advertise both; the server chooses based on hardware capabilities. Google's QUIC protocol prioritises ChaCha20-Poly1305 for mobile clients and AES-GCM for desktop.
