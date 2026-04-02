# Problem 01: Kyber Key Encapsulation — Conceptual Walkthrough

## Problem Statement

Work through the three Kyber operations (KeyGen, Encapsulate, Decapsulate) at a
conceptual level using small numerical examples. Then answer the following questions:

1. What is the mathematical role of the error term $e$ in Kyber KeyGen?
2. Why is the Fujisaki-Okamoto (FO) transform applied to Kyber?
3. Walk through the decapsulation correctness argument showing that $v - s^T u$
   approximates the encoded message.
4. Compare the sizes of Kyber-768 keys and ciphertext against X25519 (ECDH).
   What is the bandwidth overhead in a TLS 1.3 handshake?

**Simplification for this problem:** Use toy parameters $n = 4$, $q = 17$, $k = 1$
(one polynomial with 4 coefficients, modulus 17). This illustrates the structure
without the full 256-coefficient polynomials of real Kyber.

---

## Solution

### Part 0 — Setup and Notation

**Toy parameters:**
```
n = 4    (polynomial degree; real Kyber uses n=256)
q = 17   (modulus; real Kyber uses q=3329)
k = 1    (module rank; Kyber-768 uses k=3)

Ring: R_q = Z_17[X] / (X^4 + 1)
Polynomials have coefficients in Z_17 = {0, 1, ..., 16}
Polynomial addition: coefficient-wise mod 17
Polynomial multiplication: mod (X^4 + 1), then coefficients mod 17
```

**Centered representation:** Coefficients can be written in $\{-8, \ldots, 8\}$
(symmetric around 0) or in $\{0, \ldots, 16\}$. We use $\{0, \ldots, 16\}$ here.

---

### Part 1 — Toy KeyGen

**Step 1: Generate public matrix A**

In real Kyber, $A$ is sampled by expanding a seed $\rho$ with SHAKE-128.
For our toy example: $A = [3]$ (a 1×1 matrix with single polynomial $a(X) = 3$
— a constant polynomial in $R_{17}$).

**Step 2: Sample secret and error**

Secret: $s = [2 + 1 \cdot X]$ (coefficients: $[2, 1, 0, 0]$)
Error:  $e = [1]$            (small error: $e(X) = 1$, all coefficients small)

**Step 3: Compute public key $t = A \cdot s + e$**

$a(X) \cdot s(X) = 3 \cdot (2 + X) = 6 + 3X$

Adding error: $t(X) = 6 + 3X + 1 = 7 + 3X$

$t = [7, 3, 0, 0] \pmod{17}$

**Public key:** $(A, t) = ([3], [7, 3, 0, 0])$

**Private key:** $s = [2, 1, 0, 0]$

---

### Part 2 — Toy Encapsulation

The sender wants to encapsulate message $m \in \{0, 1\}^4$ (4 bits for our 4-coefficient
ring). Say $m = (1, 0, 1, 0)$.

**Message encoding:** Each bit maps to 0 or $\lfloor q/2 \rceil = 8$ (half the modulus).
$m_{enc}(X) = 1 \cdot 8 + 0 \cdot X + 1 \cdot 8 X^2 + 0 \cdot X^3 = 8 + 8X^2$

**Randomness:** $r = [1 + X]$ (small random polynomial from CBD)

**Error vectors:** $e_1 = [0]$, $e_2 = 1$ (small errors; toy simplification)

**Compute ciphertext component $u$:**
$$u = A^T \cdot r + e_1 = 3 \cdot (1 + X) + 0 = 3 + 3X$$
$u = [3, 3, 0, 0] \pmod{17}$

**Compute ciphertext component $v$:**
$$v = t^T \cdot r + e_2 + m_{enc}$$
$$= (7 + 3X) \cdot (1 + X) + 1 + (8 + 8X^2)$$

Expand $(7 + 3X)(1 + X) = 7 + 7X + 3X + 3X^2 = 7 + 10X + 3X^2$

Add $1$: $8 + 10X + 3X^2$

Add $m_{enc} = 8 + 8X^2$: $16 + 10X + 11X^2$

$v = [16, 10, 11, 0] \pmod{17}$

**Ciphertext:** $(u, v) = ([3, 3, 0, 0], [16, 10, 11, 0])$

---

### Part 3 — Toy Decapsulation

The receiver has private key $s = [2, 1, 0, 0]$ and ciphertext $(u, v)$.

**Compute $v - s^T \cdot u$:**

$s^T \cdot u = (2 + X) \cdot (3 + 3X)$
$= 6 + 6X + 3X + 3X^2$
$= 6 + 9X + 3X^2$

$v - s^T u = (16 + 10X + 11X^2) - (6 + 9X + 3X^2)$
$= 10 + X + 8X^2$

**Correctness argument:**

$$v - s^T u = (t^T r + e_2 + m_{enc}) - s^T(A^T r + e_1)$$
$$= t^T r + e_2 + m_{enc} - s^T A^T r - s^T e_1$$
$$= (As + e)^T r + e_2 + m_{enc} - s^T A^T r - s^T e_1$$
$$= s^T A^T r + e^T r + e_2 + m_{enc} - s^T A^T r - s^T e_1$$
$$= m_{enc} + \underbrace{(e^T r + e_2 - s^T e_1)}_{\text{small error term}}$$

**Check:** $e^T r = 1 \cdot (1 + X) = 1 + X$; $s^T e_1 = 0$; $e_2 = 1$

Error term $= 1 + X + 1 = 2 + X$

$m_{enc} + error = (8 + 8X^2) + (2 + X) = 10 + X + 8X^2$ ✓ (matches our computation)

**Rounding to recover message:**

For each coefficient, round to nearest multiple of $\lfloor q/2 \rceil = 8$:

```
Coefficient 0: 10 → nearest of {0, 8, 16}: |10-8|=2, |10-0|=10, |10-16|=6 → round to 8 → bit=1
Coefficient 1:  1 → nearest of {0, 8}: |1-0|=1 → round to 0 → bit=0
Coefficient 2:  8 → nearest of {8}: exactly 8 → bit=1
Coefficient 3:  0 → nearest of {0}: exactly 0 → bit=0
```

Recovered message: $(1, 0, 1, 0)$ ✓

---

### Part 4 — Question Answers

**Q1: Role of the error term $e$ in KeyGen**

Without $e$: $t = As$, and an attacker can solve the linear system $As = t$ to recover
$s$ directly (e.g., by Gaussian elimination, since $A$ and $t$ are public).

With $e$: $t = As + e$. Now solving for $s$ requires finding the exact solution to an
approximate linear system where the approximation error is small but unknown. This is
the **Learning With Errors (LWE) problem** — believed to be exponentially hard even
for quantum computers. The error $e$ is sampled from a small distribution (Centered
Binomial Distribution in Kyber) so that it is too large to ignore but small enough
that decapsulation succeeds.

**Q2: Purpose of the FO transform**

Kyber without FO is IND-CPA secure: an adversary who only sees ciphertexts cannot
distinguish encryptions of different messages. However, in a real TLS-like deployment,
the server acts as a decapsulation oracle: it attempts decapsulation and behaves
differently on success vs failure. An adversary submitting modified ciphertexts can
use this oracle to extract the private key bit by bit (chosen ciphertext attack).

The FO transform converts Kyber from IND-CPA to IND-CCA2:
1. Derandomises encapsulation: $r$ is derived from $m$ and $pk$ deterministically.
2. Re-encrypts during decapsulation to verify ciphertext integrity.
3. Returns a pseudorandom value $H(z \| c)$ on failure instead of an error — the
   attacker cannot distinguish a failed decapsulation from a successful one.

IND-CCA2 is the practical minimum for deployment in any protocol that exposes
decapsulation to an adversary.

**Q3: Decapsulation correctness** (shown above in Part 3)

The key step is:
$$v - s^T u = m_{enc} + (e^T r + e_2 - s^T e_1)$$

The error term $e^T r + e_2 - s^T e_1$ is small because $e$, $r$, $e_1$, $e_2$, and
$s$ are all drawn from small distributions (at most $\eta$ bound on coefficients). For
Kyber-768, each coefficient of this error term is bounded by approximately
$\eta_1 n + \eta_2 + \eta_1 \eta_2 n < q/4$, ensuring that rounding recovers the
correct bit for each coefficient of $m$.

Decryption failure probability for Kyber-768 is $< 2^{-164}$ — negligible.

**Q4: Bandwidth overhead in TLS 1.3**

```
Comparison: Kyber-768 vs X25519

                     X25519      Kyber-768    X25519Kyber768 hybrid
ClientHello key_share:  32 B      1184 B          1216 B
ServerHello key_share:  32 B      1088 B          1120 B
Total handshake overhead: 64 B    2272 B          2336 B

Additional bytes vs pure X25519:
  Pure Kyber-768 hybrid:   +2208 B = ~2.2 KB
  X25519Kyber768 hybrid:   +2272 B = ~2.2 KB (X25519 adds only 64 B)
```

**Impact:** The TLS handshake grows by approximately 2.2 KB. For a typical HTTPS
connection downloading a 100 KB web page, this is roughly a 2% overhead in bytes
transferred. At modern broadband speeds (50 Mbps+), the extra 2.2 KB adds less
than 1 ms of additional transfer time. The additional processing time for
Kyber-768 KEM operations is typically 0.1–0.5 ms on modern hardware.

This overhead is acceptable for most applications. Edge cases where it matters:
- High-frequency TLS connections (microservices making thousands of connections/sec)
- Very low-bandwidth IoT links (LoRaWAN, LPWAN) where every byte is costly
- Latency-sensitive protocols on satellite links with high propagation delay

For these cases, pure Kyber-512 (800-byte public key, 768-byte ciphertext) reduces
overhead to ~1.6 KB, with a slight reduction in security margin (NIST Level 1 vs 3).
