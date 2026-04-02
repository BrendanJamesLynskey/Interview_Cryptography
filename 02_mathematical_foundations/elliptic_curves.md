# Elliptic Curves

## Prerequisites
- Modular arithmetic and finite fields ($\mathbb{F}_p$ and $\text{GF}(2^n)$)
- Basic projective geometry (helpful for homogeneous coordinates)
- Group theory: cyclic groups, group order, generator
- Understanding of the discrete logarithm problem

---

## Concept Reference

### What is an Elliptic Curve?

An **elliptic curve** over a field $\mathbb{F}$ is the set of solutions $(x, y) \in \mathbb{F}^2$ to the **Weierstrass equation**, together with a special **point at infinity** $\mathcal{O}$:

$$
E : y^2 = x^3 + ax + b \quad \text{where} \quad 4a^3 + 27b^2 \neq 0
$$

The condition $4a^3 + 27b^2 \neq 0$ ensures the curve is **non-singular** (no cusps or self-intersections), which is required for the group law to work.

In cryptography, the field is typically:
- $\mathbb{F}_p$ — integers modulo a large prime $p$ (used in P-256, P-384, secp256k1)
- $\mathbb{F}_{2^n}$ — binary extension fields (B-163, B-233; less common now)
- $\mathbb{Z}$ — integers (used in theory and Ed25519/Curve25519 uses a birational map from Edwards to Weierstrass)

The number of points on $E(\mathbb{F}_p)$ (including $\mathcal{O}$) is denoted $\#E(\mathbb{F}_p)$. By **Hasse's theorem**:

$$
|\ \#E(\mathbb{F}_p) - (p + 1)\ | \leq 2\sqrt{p}
$$

The number of points is close to $p + 1$, with a deviation bounded by $2\sqrt{p}$.

---

### The Group Law

The set of points on $E$ together with the point at infinity forms an **abelian group** $E(\mathbb{F}_p)$ under a geometric addition law.

**Geometric interpretation (over $\mathbb{R}$):** To add two points $P$ and $Q$:
1. Draw the line through $P$ and $Q$.
2. The line intersects the curve at a third point $R'$.
3. Reflect $R'$ over the $x$-axis to obtain $R = P + Q$.

Special cases:
- If $P = Q$: use the tangent line at $P$ (point doubling).
- If $P = -Q$ (they have the same $x$-coordinate and opposite $y$-coordinates): the "line" is vertical, intersects the curve only at those two points, and $P + Q = \mathcal{O}$ (the point at infinity, identity element).
- If $P = \mathcal{O}$: $\mathcal{O} + Q = Q$ (identity).

#### Point Addition Formulas

For $P = (x_1, y_1)$ and $Q = (x_2, y_2)$ with $P \neq \pm Q$ and $P, Q \neq \mathcal{O}$:

$$
\lambda = \frac{y_2 - y_1}{x_2 - x_1} \pmod{p}
$$

$$
x_3 = \lambda^2 - x_1 - x_2 \pmod{p}
$$

$$
y_3 = \lambda(x_1 - x_3) - y_1 \pmod{p}
$$

Result: $P + Q = (x_3, y_3)$.

#### Point Doubling Formulas

For $P = (x_1, y_1)$ with $y_1 \neq 0$ (otherwise $2P = \mathcal{O}$):

$$
\lambda = \frac{3x_1^2 + a}{2y_1} \pmod{p}
$$

$$
x_3 = \lambda^2 - 2x_1 \pmod{p}
$$

$$
y_3 = \lambda(x_1 - x_3) - y_1 \pmod{p}
$$

Result: $2P = (x_3, y_3)$.

**Operation counts (affine coordinates):** One point addition requires 1 field inversion, 2 field multiplications, and 6 additions. One doubling requires 1 inversion, 2 multiplications, and 4 additions. Field inversion is expensive (typically 100–1000× a multiplication), so affine coordinates are inefficient for scalar multiplication.

```python
def point_add(P, Q, a, p):
    """
    Add two points P=(x1,y1) and Q=(x2,y2) on y^2 = x^3 + ax + b mod p.
    Returns the sum as (x3, y3) or None for the point at infinity.
    """
    if P is None:
        return Q
    if Q is None:
        return P
    x1, y1 = P
    x2, y2 = Q

    if x1 == x2:
        if y1 != y2:
            return None           # P + (-P) = infinity
        if y1 == 0:
            return None           # tangent at P is vertical
        # Point doubling
        lam = (3 * x1 * x1 + a) * pow(2 * y1, -1, p) % p
    else:
        lam = (y2 - y1) * pow(x2 - x1, -1, p) % p

    x3 = (lam * lam - x1 - x2) % p
    y3 = (lam * (x1 - x3) - y1) % p
    return (x3, y3)


def scalar_mul(k, P, a, p):
    """
    Compute k*P on curve y^2 = x^3 + ax + b mod p.
    Uses double-and-add (left-to-right binary method).
    """
    Q = None  # point at infinity (identity)
    while k > 0:
        if k & 1:
            Q = point_add(Q, P, a, p)
        P = point_add(P, P, a, p)  # doubling
        k >>= 1
    return Q
```

---

### Projective Coordinates

To avoid the expensive field inversion in affine coordinates, cryptographic implementations use **projective coordinates**. A projective point $(X : Y : Z)$ represents the affine point $(X/Z, Y/Z)$.

**Jacobian projective coordinates** use the representation $(X, Y, Z)$ for the affine point $(X/Z^2, Y/Z^2)$. The identity is represented as $(1 : 1 : 0)$.

Point addition in Jacobian coordinates costs approximately **12 field multiplications and 4 field squarings** — no inversions needed. The final conversion to affine (one inversion) only occurs once at the end of a scalar multiplication.

---

### Scalar Multiplication

**Scalar multiplication** (also called point multiplication) computes $[k]P = P + P + \cdots + P$ ($k$ times) for a scalar $k$ and a curve point $P$. This is the core operation in all ECC protocols.

**Double-and-add algorithm:** Analogous to square-and-multiply for modular exponentiation.

Write $k$ in binary: $k = \sum_{i=0}^{n-1} k_i 2^i$. Then:

$$
[k]P = \sum_{i : k_i = 1} [2^i]P
$$

**Left-to-right (MSB-first):**
```
R = 0 (identity)
For each bit of k from MSB to LSB:
    R = 2R          (doubling)
    if bit == 1:
        R = R + P   (addition)
Return R
```

**Cost:** For a $n$-bit scalar, approximately $n$ doublings and $n/2$ additions on average.

**Constant-time requirement:** The naive double-and-add algorithm has a data-dependent branch on each bit of $k$. This leaks the scalar through timing side channels (and power analysis, electromagnetic analysis). Secure implementations use:

1. **Montgomery ladder:** Always performs one doubling and one addition per bit, regardless of the bit value.
2. **Fixed-window methods:** Precompute small multiples and process $w$ bits at a time.
3. **Constant-time conditional swap:** Branch-free implementations.

```python
def montgomery_ladder(k: int, P, a: int, p: int):
    """
    Constant-time scalar multiplication using Montgomery ladder.
    Performs exactly n doublings and n additions for n-bit k.
    """
    R0 = None   # 0 * P = infinity
    R1 = P      # 1 * P
    n = k.bit_length()
    for i in range(n - 1, -1, -1):
        bit = (k >> i) & 1
        if bit == 0:
            R1 = point_add(R0, R1, a, p)  # R1 = R0 + R1
            R0 = point_add(R0, R0, a, p)  # R0 = 2*R0
        else:
            R0 = point_add(R0, R1, a, p)  # R0 = R0 + R1
            R1 = point_add(R1, R1, a, p)  # R1 = 2*R1
    return R0
```

---

### Standard Curves

#### NIST P-256 (secp256r1)

**Parameters:**

$$
p = 2^{256} - 2^{224} + 2^{192} + 2^{96} - 1 \quad \text{(a pseudo-Mersenne prime)}
$$

$$
a = p - 3, \quad b = \texttt{0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B}
$$

**Generator $G$ (compressed):**

$$
G_x = \texttt{0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296}
$$

**Group order:**

$$
n = \texttt{0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551}
$$

The special form of $p$ (pseudo-Mersenne) enables extremely fast modular reduction: reducing a 512-bit product modulo $p$ requires only additions and subtractions of shifted words, no division.

The choice $a = -3 \equiv p - 3$ allows a more efficient doubling formula: $\lambda = (3x^2 + a)/(2y) = 3(x-1)(x+1)/(2y) = 3(x^2-1)/(2y)$, saving one field multiplication per doubling.

#### Curve25519 / X25519

Curve25519 (Bernstein, 2006) uses a **Montgomery curve** form:

$$
E : y^2 = x^3 + 486662 x^2 + x \pmod{p}
$$

$$
p = 2^{255} - 19 \quad \text{(a Mersenne-like prime, 255 bits)}
$$

The group order $n = 2^{252} + 27742317777372353535851937790883648493$, with the curve having cofactor $h = 8$ (the group has a large prime-order subgroup of index 8).

**Why Curve25519 is preferred over P-256 in many contexts:**

1. **Efficiency:** Arithmetic modulo $2^{255} - 19$ is faster than modulo the P-256 prime.
2. **Complete addition formulas:** The Montgomery ladder for X25519 only requires the $x$-coordinate, and the formulas are complete (handle all cases including the identity, without branching on special cases).
3. **Deterministic:** No random nonce required for X25519 (Diffie-Hellman key exchange); all state is in the scalar.
4. **Side-channel resistance by construction:** The Montgomery ladder is inherently constant-time in the number of operations.
5. **Immunity to twist attacks:** Cofactor 8 means all valid inputs (any 255-bit scalar) land on either the main curve or a twist with a small number of points. The X25519 spec mandates clamping scalars to avoid these small subgroups.

#### Ed25519 / EdDSA

Ed25519 is defined on a **twisted Edwards curve** over the same field:

$$
E : -x^2 + y^2 = 1 + dx^2y^2 \pmod{p}
$$

$$
d = -121665/121666 \pmod{p}
$$

The birational equivalence to a Montgomery curve means Ed25519 and Curve25519 use the same underlying field arithmetic. Edwards curves have **complete addition formulas** — the same formula handles all cases (doubling, addition, identity) without case analysis.

**Ed25519 signature scheme (EdDSA):**

- Private key: random 32-byte seed $k$. Expand with SHA-512: $(s, \text{prefix}) = \text{SHA-512}(k)$.
- Public key: $A = [s]B$ where $B$ is the base point.
- Signing message $M$: nonce $r = H(\text{prefix} \| M)$ (deterministic!), $R = [r]B$, $S = (r + H(R \| A \| M) \cdot s) \bmod \ell$.
- Signature: $(R, S)$.
- Verification: $[S]B \stackrel{?}{=} R + [H(R\|A\|M)]A$.

**Key advantage of deterministic nonce generation:** ECDSA requires a random nonce $k$ per signature; reusing $k$ leaks the private key. Ed25519 derives $r$ deterministically from the private key and message, eliminating the per-signature randomness requirement and the catastrophic failure mode of nonce reuse.

---

### ECDH — Elliptic Curve Diffie-Hellman

ECDH allows two parties to establish a shared secret over a public channel:

1. Agree on a curve $E$ and generator $G$ of prime order $n$.
2. Alice: choose private key $a \leftarrow \{1, \ldots, n-1\}$, compute public key $A = [a]G$.
3. Bob: choose private key $b$, compute public key $B = [b]G$.
4. Alice computes $[a]B = [a][b]G = [ab]G$.
5. Bob computes $[b]A = [b][a]G = [ab]G$.
6. Shared secret: $[ab]G$ (Alice and Bob agree; an eavesdropper knows only $G$, $A$, $B$).

**Security:** Breaking ECDH requires solving the **Elliptic Curve Diffie-Hellman Problem (ECDHP)**: given $G$, $A = [a]G$, $B = [b]G$, find $[ab]G$. This is at most as hard as the **Elliptic Curve Discrete Logarithm Problem (ECDLP)**: given $G$ and $P = [k]G$, find $k$.

The best classical attack on ECDLP is Pollard's rho algorithm with complexity $O(\sqrt{n})$. For P-256, $n \approx 2^{256}$, giving $O(2^{128})$ security. For Curve25519, the prime-order subgroup has order $\approx 2^{252}$, giving $O(2^{126})$ security (slightly weaker but entirely adequate).

---

## Tier 1 — Fundamentals

### Question F1
**Define the elliptic curve group law geometrically and algebraically. What is the identity element?**

**Answer:**

**Geometrically** (over $\mathbb{R}$): Given two distinct points $P$ and $Q$ on a curve $E$, their sum $P + Q$ is found by:
1. Drawing the unique line $\ell$ through $P$ and $Q$.
2. Finding the third intersection point $R'$ of $\ell$ with $E$ (guaranteed by Bezout's theorem: a line intersects a cubic in 3 points counting multiplicity, over the algebraically closed field).
3. Reflecting $R'$ over the $x$-axis to obtain $R = P + Q$.

For $P = Q$, replace $\ell$ with the tangent to $E$ at $P$.

**Algebraically** (over $\mathbb{F}_p$, for $P \neq Q$, $P \neq -Q$):

$$
\lambda = (y_2 - y_1)(x_2 - x_1)^{-1} \bmod p
$$
$$
x_3 = \lambda^2 - x_1 - x_2 \bmod p, \quad y_3 = \lambda(x_1 - x_3) - y_1 \bmod p
$$

**Identity element:** The **point at infinity** $\mathcal{O}$, which is not a finite point on the curve but is formally included in the projective completion. It satisfies $P + \mathcal{O} = P$ for all $P$.

Geometrically: a vertical line through $P = (x, y)$ and $-P = (x, -y)$ does not intersect the curve at a third finite point — it "intersects at infinity," giving $P + (-P) = \mathcal{O}$.

---

### Question F2
**What is ECDLP? Why is it the basis for ECC security? What is the best-known classical attack complexity?**

**Answer:**

The **Elliptic Curve Discrete Logarithm Problem:** Given a curve $E(\mathbb{F}_p)$, a generator $G$ of a subgroup of prime order $n$, and a point $Q = [k]G$, find the integer $k \in \{0, 1, \ldots, n-1\}$.

**Why it underpins ECC security:** ECC key generation produces a public key $Q = [k]G$ from a private key $k$. Computing $Q$ from $k$ is efficient (scalar multiplication, $O(\log k)$ group operations). Recovering $k$ from $Q$ is believed to require $O(\sqrt{n})$ work — the ECDLP. There is no known sub-exponential algorithm for ECDLP on a well-chosen curve, unlike the integer DLP (which has index calculus) or integer factorisation.

**Best-known classical attack:** Pollard's rho algorithm runs in $O(\sqrt{n})$ group operations on average. For P-256 with $n \approx 2^{256}$, this is $O(2^{128})$ — computationally infeasible. The parallelised version with $c$ processors achieves $O(\sqrt{n}/c)$.

**No sub-exponential algorithm for generic curves:** The Pohlig-Hellman reduction applies only when $n$ is smooth. For P-256, $n$ is prime, so Pohlig-Hellman does not help. The index calculus attack (which breaks DLP in $\mathbb{Z}_p^*$ in sub-exponential time) does not generalise to elliptic curves — ECDLP is believed strictly harder than integer DLP.

---

### Question F3
**Compare the key sizes for equivalent security levels between RSA, classical DH, and ECC. Why does ECC achieve higher security per bit?**

**Answer:**

| Security level (bits) | RSA/DH key size | ECC key size |
|---|---|---|
| 80 | 1024 bits | 160 bits |
| 112 | 2048 bits | 224 bits |
| 128 | 3072 bits | 256 bits |
| 192 | 7680 bits | 384 bits |
| 256 | 15360 bits | 521 bits |

**Why ECC is more efficient:**

RSA and classical DH rely on the hardness of integer factorisation and integer DLP respectively. Both have sub-exponential attacks (NFS/GNFS) that run in time:

$$
L_n\left[\frac{1}{3}, c\right] = \exp\left(c(\ln n)^{1/3}(\ln \ln n)^{2/3}\right)
$$

As $n$ grows, the attack grows sub-exponentially — requiring rapidly increasing key sizes for linear security improvements.

ECC ECDLP has only exponential attacks ($O(\sqrt{n})$). Security grows as the square root of the group order: to get 128-bit security, you need $n \approx 2^{256}$ (a 256-bit key). The linear relationship between key bits and security bits (halved due to square root) is far more efficient than the sub-linear relationship for RSA.

**Practical benefits:** Smaller keys mean smaller certificates, faster key generation, less bandwidth in TLS handshakes, and lower power consumption in constrained devices (IoT, smart cards).

---

## Tier 2 — Intermediate

### Question I1
**Work through a concrete ECDH key exchange on a small toy curve. Use $E: y^2 = x^3 + 2x + 2 \pmod{17}$, generator $G = (5, 1)$, with Alice's private key $a = 3$ and Bob's private key $b = 4$.**

**Answer:**

First, verify $G = (5, 1)$ is on the curve:
$1^2 = 1$; $5^3 + 2 \cdot 5 + 2 = 125 + 12 = 137 \equiv 137 - 8 \times 17 = 1 \pmod{17}$. Yes. $\checkmark$

**Compute Alice's public key $A = [3]G$:**

$[2]G = G + G$ (doubling):

$$
\lambda = \frac{3 \times 5^2 + 2}{2 \times 1} \bmod 17 = \frac{77}{2} \bmod 17 = \frac{9}{2} \bmod 17
$$

$2^{-1} \bmod 17 = 9$ (since $2 \times 9 = 18 \equiv 1$), so $\lambda = 9 \times 9 \bmod 17 = 81 \bmod 17 = 13$.

$$
x_{2G} = 13^2 - 5 - 5 = 169 - 10 = 159 \equiv 159 - 9 \times 17 = 6 \pmod{17}
$$
$$
y_{2G} = 13(5 - 6) - 1 = -13 - 1 = -14 \equiv 3 \pmod{17}
$$

$[2]G = (6, 3)$.

$[3]G = [2]G + G = (6, 3) + (5, 1)$:

$$
\lambda = \frac{1 - 3}{5 - 6} \bmod 17 = \frac{-2}{-1} \bmod 17 = 2
$$
$$
x_{3G} = 4 - 6 - 5 = -7 \equiv 10 \pmod{17}
$$
$$
y_{3G} = 2(6 - 10) - 3 = -8 - 3 = -11 \equiv 6 \pmod{17}
$$

**Alice's public key:** $A = [3]G = (10, 6)$.

**Compute Bob's public key $B = [4]G$:**

$[4]G = [2]([2]G) = (6, 3) + (6, 3)$:

$$
\lambda = \frac{3 \times 36 + 2}{2 \times 3} \bmod 17 = \frac{110}{6} \bmod 17 = \frac{8}{6} \bmod 17
$$

$6^{-1} \bmod 17 = 3$ (since $6 \times 3 = 18 \equiv 1$), so $\lambda = 8 \times 3 \bmod 17 = 24 \bmod 17 = 7$.

$$
x_{4G} = 49 - 12 = 37 \equiv 3 \pmod{17}
$$
$$
y_{4G} = 7(6 - 3) - 3 = 21 - 3 = 18 \equiv 1 \pmod{17}
$$

**Bob's public key:** $B = [4]G = (3, 1)$.

**Shared secret:**

Alice: $[a]B = [3](3, 1)$.

$[2](3,1)$: $\lambda = (3 \times 9 + 2)/(2 \times 1) \bmod 17 = 29/2 \bmod 17 = 12 \times 9 \bmod 17 = 108 \bmod 17 = 6$.

$x = 36 - 6 = 30 \equiv 13 \pmod{17}$, $y = 6(3-13)-1 = -61 \equiv -61 + 4 \times 17 = 7 \pmod{17}$.

$[2](3,1) = (13, 7)$. Then $[3](3,1) = (13, 7) + (3, 1)$:

$\lambda = (1-7)/(3-13) \bmod 17 = (-6)/(-10) \bmod 17 = 6 \times 10^{-1} \bmod 17$.

$10^{-1} \bmod 17 = 12$ (since $10 \times 12 = 120 = 7 \times 17 + 1$), so $\lambda = 72 \bmod 17 = 4$.

$x_3 = 16 - 13 - 3 = 0$, $y_3 = 4(13 - 0) - 7 = 52 - 7 = 45 \equiv 11 \pmod{17}$.

Alice's shared point: $(0, 11)$.

Bob: $[b]A = [4](10, 6)$. (Should also give $(0, 11)$ — verifiable with the same arithmetic.)

**Shared secret $x$-coordinate:** $0$. (In X25519/P-256, only the $x$-coordinate is used as the shared secret.)

---

### Question I2
**Explain the invalid curve attack on ECDH. What implementation precaution prevents it?**

**Answer:**

An **invalid curve attack** exploits ECDH implementations that accept arbitrary elliptic curve points without validating that they lie on the specified curve.

**Attack mechanism:**

In standard ECDH with a curve $E$ of prime order $n$, the protocol is secure. However, many other curves $E'$ (with different $b$ parameters, same $a$ and $p$) have small-order groups with known discrete logs.

If Alice sends Bob a point $Q'$ from a small-order curve $E'$ (order $r$, with $r$ small — e.g., $r = 2, 3, 5$):
1. Bob computes $[b]Q'$ where $b$ is his private key.
2. Since $Q'$ has order $r$, the result $[b]Q' = [b \bmod r]Q'$ lies in a set of $r$ values.
3. Alice receives $[b]Q'$, which tells her $b \bmod r$.

By sending points from multiple small-order curves (with coprime orders $r_1, r_2, \ldots$), Alice accumulates congruences $b \equiv b_i \pmod{r_i}$ and recovers $b \bmod (r_1 r_2 \cdots)$ via CRT. If the product of orders exceeds $n$, the full private key $b$ is recovered.

**Why this works:** The attack requires no ECDLP solving — just oracle queries to Bob's implementation.

**Precautions:**

1. **Point validation:** Before using any received public key $Q'$, verify:
   - $Q' \neq \mathcal{O}$ (not the point at infinity).
   - $Q'_x, Q'_y \in [0, p-1]$ (coordinates are in range).
   - $Q'^2_y \equiv Q'^3_x + a Q'_x + b \pmod p$ (point lies on the correct curve).
   - $[n]Q' = \mathcal{O}$ (point has the correct order — this follows from the group structure if point validation passes, for prime-order curves).

2. **Use prime-order curves:** On curves where every non-identity point has the same prime order $n$ (e.g., P-256, Curve25519's prime-order subgroup), the attack has no useful small subgroups.

3. **Cofactor multiplication:** For curves with cofactor $h > 1$ (e.g., Curve25519 has $h = 8$), multiply the received point by $h$ before use to clear small-subgroup components.

RFC 8446 (TLS 1.3) mandates point validation for all received EC public keys.

---

### Question I3
**Describe the ECDSA signature scheme. What is the critical security requirement on the nonce $k$? What happened to Sony's PS3 when this was violated?**

**Answer:**

**ECDSA (Elliptic Curve Digital Signature Algorithm):**

Setup: curve $E$, generator $G$ of prime order $n$, private key $d$, public key $Q = [d]G$.

**Signing** message $m$:
1. Compute $e = H(m)$ (e.g., SHA-256).
2. Choose random $k \in \{1, \ldots, n-1\}$.
3. Compute $R = [k]G = (x_1, y_1)$; set $r = x_1 \bmod n$. If $r = 0$, retry.
4. Compute $s = k^{-1}(e + r \cdot d) \bmod n$. If $s = 0$, retry.
5. Signature: $(r, s)$.

**Verification** of $(r, s)$ on message $m$ with public key $Q$:
1. Verify $r, s \in \{1, \ldots, n-1\}$.
2. Compute $e = H(m)$.
3. Compute $u_1 = e s^{-1} \bmod n$ and $u_2 = r s^{-1} \bmod n$.
4. Compute $R' = [u_1]G + [u_2]Q$.
5. Verify $R'_x \equiv r \pmod n$.

**Critical security requirement on $k$:**

$k$ must be:
- **Uniformly random** over $\{1, \ldots, n-1\}$.
- **Secret** (never revealed).
- **Used only once per signature** (never reused across different signatures with the same key).

**Why nonce reuse is catastrophic:** If the same $k$ is used for two signatures $(r, s_1)$ and $(r, s_2)$ on messages with hashes $e_1$ and $e_2$:

$$
s_1 = k^{-1}(e_1 + r d) \bmod n
$$
$$
s_2 = k^{-1}(e_2 + r d) \bmod n
$$

Then $s_1 - s_2 = k^{-1}(e_1 - e_2) \bmod n$, so:

$$
k = (e_1 - e_2)(s_1 - s_2)^{-1} \bmod n
$$

With $k$ recovered, the private key is $d = r^{-1}(k s_1 - e_1) \bmod n$.

**Sony PS3 (2010):** Sony used a fixed constant for $k$ across all firmware signatures. Researchers (fail0verflow) obtained two firmware signatures, computed $k$ from the above formula, then recovered the private signing key. This allowed signing arbitrary homebrew software as legitimate Sony firmware, completely breaking the console's security model.

**Mitigation (RFC 6979):** Deterministic ECDSA derives $k$ as a HMAC-DRBG output from the private key $d$ and message hash $e$. This eliminates RNG failures while ensuring each $(d, e)$ pair produces a distinct $k$.

---

## Tier 3 — Advanced

### Question A1
**Explain the Lenstra Elliptic Curve Factorisation Method (ECM). How does the group law on an elliptic curve over $\mathbb{Z}/n\mathbb{Z}$ assist in finding factors?**

**Answer:**

**ECM** (Lenstra, 1987) is the third-fastest general-purpose factorisation algorithm (behind GNFS and SNFS) and the fastest for finding factors up to ~60 digits.

**Core idea:** In Pollard's $p-1$ algorithm, factorisation succeeds when $p - 1$ is smooth (all prime factors small). ECM generalises this by replacing $\mathbb{Z}_p^*$ with the group $E(\mathbb{F}_p)$ for a random elliptic curve $E$.

**Algorithm:**

1. Choose a random elliptic curve $E$ defined over $\mathbb{Z}/n\mathbb{Z}$ and a random point $P \in E$.
2. Compute $[M]P$ where $M = \text{lcm}(1, 2, \ldots, B_1)$ for a smoothness bound $B_1$.
3. During the scalar multiplication, field operations are performed modulo $n$. When a denominator (from the point addition formula) shares a factor with $n$, the inversion $d^{-1} \bmod n$ fails — but $\gcd(d, n)$ gives a non-trivial factor.

**Why random curves help:** The group order $\#E(\mathbb{F}_p)$ varies with the choice of $E$, ranging over roughly $[p+1-2\sqrt{p}, p+1+2\sqrt{p}]$. For a given $p$, most curves have order close to $p$, but if we try many random curves, eventually we find one where $\#E(\mathbb{F}_p)$ is smooth (all prime factors $\leq B_1$). Then $[M]P \equiv \mathcal{O} \pmod p$, which forces a denominator divisible by $p$, and $\gcd$ reveals $p$.

**Expected complexity:** $O\left(e^{\sqrt{2 \ln p \ln \ln p}}\right)$ — sub-exponential in $\log p$, or equivalently $L_p[1/2, \sqrt{2}]$. This is faster than Pollard's $p-1$ when the smoothness bound is tuned correctly.

**Cryptographic implication:** ECM can factor RSA primes $p$ of up to ~60 decimal digits efficiently. This motivates requiring RSA primes to be at least 512 bits (155 decimal digits) — well beyond ECM's reach.

---

### Question A2
**What is the MOV attack? Describe the conditions under which it applies and explain why P-256 is immune while anomalous curves are vulnerable to a different attack.**

**Answer:**

**The MOV (Menezes-Okamoto-Vanstone) Attack** reduces ECDLP on a supersingular curve to DLP in a finite field extension, where the sub-exponential index calculus applies.

**Weil pairing:** For an elliptic curve $E(\mathbb{F}_p)$ with a point of order $n$, the Weil pairing maps:

$$
e_n : E[n] \times E[n] \rightarrow \mu_n \subset \mathbb{F}_{p^k}^*
$$

where $E[n]$ is the $n$-torsion subgroup and $\mu_n$ is the group of $n$-th roots of unity. The parameter $k$ is the **embedding degree** — the smallest $k$ such that $n \mid p^k - 1$.

**MOV attack:**
1. Compute $\alpha = e_n(P, T)$ and $\beta = e_n(Q, T)$ for a suitable auxiliary point $T$, where $Q = [k]P$.
2. The pairing is bilinear: $\beta = e_n([k]P, T) = e_n(P, T)^k = \alpha^k$.
3. This is a DLP in $\mathbb{F}_{p^k}^*$, solvable by index calculus in sub-exponential time in $p^k$.

**When it applies:** On **supersingular curves**, the embedding degree $k \leq 6$ always. For $k = 1$, the ECDLP immediately reduces to DLP in $\mathbb{F}_p^*$ — trivially broken. Supersingular curves over $\mathbb{F}_p$ have $\#E = p + 1$ and embedding degree $k = 2$.

**P-256 is immune:** P-256 is an **ordinary (non-supersingular)** curve. Its embedding degree is $k \approx 2^{248}$ — astronomically large. The field $\mathbb{F}_{p^k}$ is so large that index calculus there is harder than the original ECDLP. In practice, for all NIST recommended curves, the embedding degree is large enough to make the MOV attack useless.

**Anomalous curves — Smart's attack:** A different, even more devastating attack applies to **anomalous curves**: curves over $\mathbb{F}_p$ where $\#E(\mathbb{F}_p) = p$ (trace of Frobenius $= 1$). Smart (1999) showed that ECDLP on anomalous curves lifts to a DLP in $\mathbb{Z}_p$ (the $p$-adic numbers), solvable in polynomial time $O(\log^3 p)$. This completely breaks ECDLP on anomalous curves.

**Countermeasure:** All standardised curves verify that $\#E \neq p$. P-256's group order $n$ is close to but strictly not equal to $p$, making Smart's attack inapplicable.
