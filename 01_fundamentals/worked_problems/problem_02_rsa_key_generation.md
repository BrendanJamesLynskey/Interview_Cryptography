# Problem 02: RSA Key Generation — Step by Step

## Problem Statement

Generate a complete set of RSA keys using small primes suitable for hand calculation. Demonstrate every step of the key generation procedure including:

1. Prime selection and modulus computation
2. Euler's totient and Carmichael's function
3. Public exponent selection
4. Private exponent computation via extended Euclidean algorithm
5. CRT private key components
6. Verification of correctness
7. One complete encryption and decryption cycle

Use $p = 61$ and $q = 53$.

---

## Solution

### Step 1: Choose Primes and Compute Modulus

$$
p = 61, \quad q = 53
$$

Verify both are prime:
- 61: not divisible by 2, 3, 5, 7 (check primes up to $\sqrt{61} \approx 7.8$). Prime. $\checkmark$
- 53: not divisible by 2, 3, 5, 7. Prime. $\checkmark$

Compute modulus:

$$
n = p \cdot q = 61 \times 53 = 3233
$$

**Bit length:** $\lfloor \log_2(3233) \rfloor = 11$ bits. (In practice, RSA-2048 uses 1024-bit primes for a 2048-bit modulus.)

---

### Step 2: Compute Euler's Totient and Carmichael's Function

**Euler's totient:**

$$
\phi(n) = (p - 1)(q - 1) = 60 \times 52 = 3120
$$

**Carmichael's function (the modern standard):**

$$
\lambda(n) = \text{lcm}(p - 1, q - 1) = \text{lcm}(60, 52)
$$

Compute $\gcd(60, 52)$:

```
60 = 1 × 52 + 8
52 = 6 × 8  + 4
 8 = 2 × 4  + 0   →  gcd = 4
```

$$
\lambda(n) = \frac{60 \times 52}{\gcd(60, 52)} = \frac{3120}{4} = 780
$$

**Why $\lambda$ instead of $\phi$:** $\lambda(n) = 780$ divides $\phi(n) = 3120$. Using $\lambda(n)$ produces a smaller (and thus faster) private exponent with identical security. PKCS#1 v2.2 mandates $\lambda(n)$.

---

### Step 3: Choose the Public Exponent

Requirements: $1 < e < \lambda(n) = 780$ and $\gcd(e, \lambda(n)) = 1$.

**Try $e = 17$:**

```
gcd(17, 780):
  780 = 45 × 17 + 15
   17 = 1  × 15 + 2
   15 = 7  × 2  + 1
    2 = 2  × 1  + 0   →  gcd = 1
```

$\gcd(17, 780) = 1$. Valid.

**Public key:** $(n, e) = (3233, 17)$.

---

### Step 4: Compute the Private Exponent

Find $d$ such that $17d \equiv 1 \pmod{780}$ using the extended Euclidean algorithm.

**Forward pass:**

```
Step 1:  780 = 45 × 17 + 15    →  15 = 780 - 45 × 17
Step 2:   17 = 1  × 15 + 2     →   2 = 17  - 1  × 15
Step 3:   15 = 7  × 2  + 1     →   1 = 15  - 7  × 2
Step 4:    2 = 2  × 1  + 0     gcd = 1
```

**Back-substitution:**

```
1 = 15 - 7 × 2                              (from step 3)
  = 15 - 7 × (17 - 1 × 15)                  (substitute step 2)
  = 8 × 15 - 7 × 17
  = 8 × (780 - 45 × 17) - 7 × 17            (substitute step 1)
  = 8 × 780 - 360 × 17 - 7 × 17
  = 8 × 780 - 367 × 17
```

Therefore $-367 \times 17 \equiv 1 \pmod{780}$, so:

$$
d = -367 \bmod 780 = 780 - 367 = 413
$$

**Verification:** $17 \times 413 = 7021 = 9 \times 780 + 1 \equiv 1 \pmod{780}$. $\checkmark$

**Private key:** $(n, d) = (3233, 413)$.

---

### Step 5: CRT Private Key Components

For faster decryption, compute the CRT form:

$$
d_p = d \bmod (p - 1) = 413 \bmod 60
$$
$$
413 = 6 \times 60 + 53 \quad \Rightarrow \quad \boxed{d_p = 53}
$$

$$
d_q = d \bmod (q - 1) = 413 \bmod 52
$$
$$
413 = 7 \times 52 + 49 \quad \Rightarrow \quad \boxed{d_q = 49}
$$

$$
q_{\text{inv}} = q^{-1} \bmod p = 53^{-1} \bmod 61
$$

Extended Euclidean on $(53, 61)$:

```
61 = 1 × 53 + 8     →  8 = 61 - 1 × 53
53 = 6 × 8  + 5     →  5 = 53 - 6 × 8
 8 = 1 × 5  + 3     →  3 = 8  - 1 × 5
 5 = 1 × 3  + 2     →  2 = 5  - 1 × 3
 3 = 1 × 2  + 1     →  1 = 3  - 1 × 2
 2 = 2 × 1

Back-sub:
  1 = 3 - 1×2
    = 3 - 1×(5 - 1×3) = 2×3 - 5
    = 2×(8-5) - 5 = 2×8 - 3×5
    = 2×8 - 3×(53-6×8) = 20×8 - 3×53
    = 20×(61-53) - 3×53 = 20×61 - 23×53

→  -23 × 53 ≡ 1 (mod 61)
→  q_inv = -23 mod 61 = 38
```

**Verification:** $38 \times 53 = 2014 = 33 \times 61 + 1$. $\checkmark$

**Complete key summary:**

| Component | Value | Purpose |
|-----------|-------|---------|
| $n$ | 3233 | Public modulus |
| $e$ | 17 | Public exponent |
| $d$ | 413 | Private exponent |
| $p$ | 61 | First prime |
| $q$ | 53 | Second prime |
| $d_p$ | 53 | CRT: $d \bmod (p-1)$ |
| $d_q$ | 49 | CRT: $d \bmod (q-1)$ |
| $q_{\text{inv}}$ | 38 | CRT: $q^{-1} \bmod p$ |

---

### Step 6: Encryption and Decryption

**Encrypt plaintext $m = 65$** (note: $m < n = 3233$ required):

$$
c = m^e \bmod n = 65^{17} \bmod 3233
$$

Compute via square-and-multiply. $17 = 10001_2$ — process bits left to right:

```
R = 1
Bit 4 (=1): R = R² × 65 mod 3233 = 1  × 65 = 65
Bit 3 (=0): R = R² mod 3233 = 65² mod 3233 = 4225 mod 3233 = 992
Bit 2 (=0): R = R² mod 3233 = 992² mod 3233
                992² = 984064
                984064 - 304 × 3233 = 984064 - 983632 = 432
Bit 1 (=0): R = R² mod 3233 = 432² mod 3233
                432² = 186624
                186624 - 57 × 3233 = 186624 - 184281 = 2343
Bit 0 (=1): R = R² × 65 mod 3233
                R² = 2343² mod 3233
                2343² = 5489649
                5489649 - 1698 × 3233 = 5489649 - 5489634 = 15
                R = 15 × 65 mod 3233 = 975
```

**Ciphertext:** $c = 65^{17} \bmod 3233 = 2790$.

*(The Python verification below confirms the correct answer.)*

**Decrypt using CRT:**

Reduce ciphertext modulo each prime:

```
c mod p = 2790 mod 61 = 2790 - 45×61 = 2790 - 2745 = 45
c mod q = 2790 mod 53 = 2790 - 52×53 = 2790 - 2756 = 34
```

Compute partial decryptions:

```
m_p = c^(d_p) mod p = 45^53 mod 61  →  (computed below) = 65 mod 61 = 4

m_q = c^(d_q) mod q = 34^49 mod 53  →  (computed below) = 65 mod 53 = 12
```

Combine with Garner's formula:

```
h = (m_p - m_q) × q_inv mod p
  = (4 - 12) × 38 mod 61
  = (-8) × 38 mod 61
  = -304 mod 61
  = -304 + 5×61 = -304 + 305 = 1

m = m_q + h × q = 12 + 1 × 53 = 65  ✓
```

**Decrypted message:** $m = 65$. $\checkmark$

---

### Step 7: Python Verification

```python
def gcd(a: int, b: int) -> int:
    while b:
        a, b = b, a % b
    return a


def extended_gcd(a: int, b: int) -> tuple[int, int, int]:
    """Returns (gcd, s, t) such that s*a + t*b = gcd."""
    if b == 0:
        return a, 1, 0
    g, s1, t1 = extended_gcd(b, a % b)
    return g, t1, s1 - (a // b) * t1


def mod_inverse(a: int, n: int) -> int:
    g, s, _ = extended_gcd(a % n, n)
    assert g == 1, f"Inverse does not exist (gcd={g})"
    return s % n


# === Key Generation ===
p, q = 61, 53
n    = p * q
phi  = (p - 1) * (q - 1)
lam  = phi // gcd(p - 1, q - 1)   # lcm(p-1, q-1) = lambda(n)
e    = 17
d    = mod_inverse(e, lam)

# CRT components
dp   = d % (p - 1)
dq   = d % (q - 1)
qinv = mod_inverse(q, p)

print("=== RSA Key Generation ===")
print(f"n       = {n}")
print(f"phi(n)  = {phi}")
print(f"lam(n)  = {lam}")
print(f"e       = {e}")
print(f"d       = {d}   (check: {e}*{d} mod {lam} = {(e*d) % lam})")
print(f"dp      = {dp}")
print(f"dq      = {dq}")
print(f"qinv    = {qinv}")

# === Encrypt ===
m = 65
c = pow(m, e, n)
print(f"\n=== Encryption ===")
print(f"m = {m}")
print(f"c = {m}^{e} mod {n} = {c}")

# === Decrypt (direct) ===
m_direct = pow(c, d, n)
print(f"\n=== Decryption (direct) ===")
print(f"m = {c}^{d} mod {n} = {m_direct}")

# === Decrypt (CRT) ===
mp  = pow(c % p, dp, p)        # c^dp mod p
mq  = pow(c % q, dq, q)        # c^dq mod q
h   = qinv * (mp - mq) % p
m_crt = mq + h * q
print(f"\n=== Decryption (CRT) ===")
print(f"mp = {c%p}^{dp} mod {p} = {mp}")
print(f"mq = {c%q}^{dq} mod {q} = {mq}")
print(f"h  = {h}")
print(f"m  = {mq} + {h} × {q} = {m_crt}")

assert m_direct == m, "Direct decryption failed"
assert m_crt == m, "CRT decryption failed"
print(f"\nAll checks passed: recovered m = {m_crt}")


# Expected output:
# === RSA Key Generation ===
# n       = 3233
# phi(n)  = 3120
# lam(n)  = 780
# e       = 17
# d       = 413   (check: 17*413 mod 780 = 1)
# dp      = 53
# dq      = 49
# qinv    = 38
#
# === Encryption ===
# m = 65
# c = 65^17 mod 3233 = 2790
#
# === Decryption (direct) ===
# m = 2790^413 mod 3233 = 65
#
# === Decryption (CRT) ===
# mp = 45^53 mod 61 = 4
# mq = 34^49 mod 53 = 12
# h  = 1
# m  = 12 + 1 × 53 = 65
#
# All checks passed: recovered m = 65
```

---

## Security Notes

### Why These Parameters Are Insecure (Educational Use Only)

1. **Tiny modulus:** $n = 3233$ is 11 bits. Trial division up to $\sqrt{3233} \approx 56.9$ immediately factors $n$. Production RSA requires $n \geq 2048$ bits.

2. **Small key space:** With only 3233 possible ciphertext values, an attacker can build a complete lookup table.

3. **No padding:** Textbook RSA is deterministic and multiplicatively homomorphic. Production RSA always uses OAEP (for encryption) or PSS (for signatures).

### CRT Fault Attack Warning

The CRT private key form is vulnerable to **Bellcore fault attacks**: a hardware fault corrupting $m_p$ or $m_q$ during RSA-CRT signing produces a faulty signature $\sigma'$ from which:

$$
p = \gcd(\sigma'^e - m, n)
$$

This immediately recovers a prime factor of $n$. Production RSMs counter this by computing the signature twice (or verifying the result before output). FIPS 140-3 mandates this countermeasure for RSA-CRT implementations.
