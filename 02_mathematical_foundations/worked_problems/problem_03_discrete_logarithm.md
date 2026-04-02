# Problem 03: Discrete Logarithm — Solving DLP in a Small Group

## Problem Statement

Solve the discrete logarithm problem (DLP) in a small group using three different methods, and analyse the complexity of each.

**Setup:** Work in the group $\mathbb{Z}_{23}^*$ (integers modulo 23 under multiplication). The group has order $\phi(23) = 22$.

**Part A:** Verify that $g = 5$ is a primitive root (generator) of $\mathbb{Z}_{23}^*$.

**Part B:** Solve $5^x \equiv 8 \pmod{23}$ using **exhaustive search**.

**Part C:** Solve $5^x \equiv 8 \pmod{23}$ using the **Baby-step Giant-step (BSGS)** algorithm. Explicitly show the baby steps table and giant steps.

**Part D:** Solve $5^x \equiv 11 \pmod{23}$ using **Pohlig-Hellman**, exploiting the factored group order $22 = 2 \times 11$.

**Part E:** Analyse the work required for each method as a function of the group order $n$, and contrast with the complexity for elliptic curve groups.

---

## Part A: Verify $g = 5$ is a Primitive Root mod 23

$g$ is a primitive root modulo 23 if its multiplicative order is $\phi(23) = 22$.

The order of $g$ must divide 22. The divisors of 22 are: 1, 2, 11, 22.

To confirm the order is 22 (not a proper divisor), verify that $g^{22/q} \not\equiv 1 \pmod{23}$ for each prime factor $q$ of 22 ($q \in \{2, 11\}$):

**Check $5^{22/2} = 5^{11} \bmod 23$:**

Compute using square-and-multiply. $11 = 1011_2$:

```
R = 1, base = 5
Bit 3 (=1): R = 1 × 5 = 5;       base² = 25 mod 23 = 2
Bit 2 (=0): R = 5;                base² = 2² mod 23 = 4
Bit 1 (=1): R = 5 × 4 = 20;      base² = 4² mod 23 = 16
Bit 0 (=1): R = 20 × 16 = 320 mod 23

320 / 23 = 13.9...; 13 × 23 = 299; 320 - 299 = 21

5^11 mod 23 = 21 ≠ 1  ✓
```

Alternatively: $21 \equiv -1 \pmod{23}$. Since $5^{11} \equiv -1$, this also confirms $5$ has order exactly 22 (by Fermat's little theorem, $5^{22} \equiv 1$, and $5^{11} \equiv -1 \not\equiv 1$).

**Check $5^{22/11} = 5^{2} \bmod 23$:**

$5^2 = 25 \equiv 2 \pmod{23} \neq 1$. $\checkmark$

Since neither $5^2$ nor $5^{11}$ equals 1 modulo 23, the order of 5 is exactly 22.

**Conclusion:** $g = 5$ is a primitive root modulo 23.

---

## Part B: Exhaustive Search for $5^x \equiv 8 \pmod{23}$

Compute all powers of 5 modulo 23 until we find 8:

| $x$ | $5^x \bmod 23$ |
|-----|-----------------|
| 0 | 1 |
| 1 | 5 |
| 2 | 2 |
| 3 | 10 |
| 4 | 4 |
| 5 | 20 |
| 6 | 8 |

$5^6 \equiv 8 \pmod{23}$.

**Answer:** $x = 6$.

**Complexity:** $O(n) = O(22)$ in the worst case, where $n$ is the group order. Each step is one multiplication modulo $p$.

---

## Part C: Baby-step Giant-step for $5^x \equiv 8 \pmod{23}$

**Setup:** Group order $n = 22$. Set $m = \lceil\sqrt{22}\rceil = 5$.

Write $x = im - j$ where $0 \leq i, j < m$. Then:

$$
5^x = 5^{im-j} = (5^m)^i \cdot 5^{-j} \equiv 8 \pmod{23}
$$

Rearranging: $8 \cdot 5^j \equiv (5^m)^i \pmod{23}$.

**Baby steps:** Compute $8 \cdot 5^j \bmod 23$ for $j = 0, 1, 2, 3, 4$ and store in a table.

Compute $5^j \bmod 23$ first:

| $j$ | $5^j \bmod 23$ |
|-----|-----------------|
| 0 | 1 |
| 1 | 5 |
| 2 | 2 |
| 3 | 10 |
| 4 | 4 |

Now compute $8 \cdot 5^j \bmod 23$:

| $j$ | $8 \cdot 5^j \bmod 23$ |
|-----|------------------------|
| 0 | $8 \times 1 = 8$ |
| 1 | $8 \times 5 = 40 \equiv 17$ |
| 2 | $8 \times 2 = 16$ |
| 3 | $8 \times 10 = 80 \equiv 80 - 3 \times 23 = 11$ |
| 4 | $8 \times 4 = 32 \equiv 9$ |

**Baby steps table:** $\{8: 0,\; 17: 1,\; 16: 2,\; 11: 3,\; 9: 4\}$

**Giant step base:** $5^m = 5^5 \bmod 23$.

$5^5 = 5^4 \times 5 = 4 \times 5 = 20 \pmod{23}$ (using $5^4 = 4$ from above).

**Giant steps:** Compute $(5^5)^i \bmod 23$ for $i = 0, 1, 2, 3, 4$ and look up in the baby steps table.

| $i$ | $(5^5)^i \bmod 23$ | In table? |
|-----|---------------------|-----------|
| 0 | $20^0 = 1$ | No |
| 1 | $20^1 = 20$ | No |
| 2 | $20^2 = 400 \equiv 400 - 17 \times 23 = 400 - 391 = 9$ | **Yes! $j = 4$** |

Found: $i = 2$, $j = 4$.

**Recover $x$:**

$$
x = im - j = 2 \times 5 - 4 = 10 - 4 = 6
$$

**Answer:** $x = 6$. $\checkmark$ (Matches Part B.)

**Verification:** $5^6 \bmod 23 = 8$. From the table above: $5^6 = 5^4 \times 5^2 = 4 \times 2 = 8$. $\checkmark$

**Complexity:** $O(\sqrt{n}) = O(\sqrt{22}) \approx O(5)$ baby steps and $O(\sqrt{n})$ giant steps. Storage: $O(\sqrt{n})$ table entries.

---

## Part D: Pohlig-Hellman for $5^x \equiv 11 \pmod{23}$

**Group order:** $n = 22 = 2 \times 11$.

Pohlig-Hellman decomposes the DLP modulo each prime factor of $n$, then combines with CRT.

We want $x$ such that $5^x \equiv 11 \pmod{23}$, i.e., $x \bmod 22$.

**Step 1: Solve modulo 2.**

Find $x_2 = x \bmod 2$.

Compute $g^{n/2} = 5^{11} \bmod 23$. We showed above: $5^{11} \equiv -1 \equiv 22 \pmod{23}$.

Compute $y^{n/2} = 11^{11} \bmod 23$.

$11^{11} \bmod 23$ — using square-and-multiply:

```
11 = 1011₂
R = 1, base = 11
Bit 3 (=1): R = 11;              base² = 121 mod 23 = 6  (121 = 5×23+6)
Bit 2 (=0): R = 11;              base² = 36 mod 23 = 13
Bit 1 (=1): R = 11 × 13 = 143 mod 23 = 143 - 6×23 = 5;  base² = 169 mod 23 = 8 (169=7×23+8)
Bit 0 (=1): R = 5 × 8 = 40 mod 23 = 17
```

Wait — let me re-examine the algorithm. $11 = 1011_2$ (4 bits). Left-to-right:

```
R = 1
Bit 3 (MSB=1): R = 1² × 11 mod 23 = 11
Bit 2 (=0):    R = 11² mod 23 = 121 mod 23 = 6
Bit 1 (=1):    R = 6² × 11 mod 23 = 36 × 11 mod 23 = 13 × 11 mod 23 = 143 mod 23 = 5
Bit 0 (=1):    R = 5² × 11 mod 23 = 25 × 11 mod 23 = 2 × 11 mod 23 = 22
```

$11^{11} \equiv 22 \equiv -1 \pmod{23}$.

Now determine $x_2$: the discrete log of $y^{n/2}$ in the subgroup of order 2, whose elements are $\{1, -1\} = \{1, 22\}$.

The generator of the order-2 subgroup is $g^{n/2} = 22$. We need $22^{x_2} \equiv 22 \pmod{23}$, so $x_2 = 1$.

$$
x \equiv 1 \pmod{2}
$$

**Step 2: Solve modulo 11.**

Find $x_{11} = x \bmod 11$.

Compute $g^{n/11} = 5^{2} \bmod 23 = 2$.

The element $h = g^{n/11} = 2$ generates the subgroup of order 11: $\{1, 2, 4, 8, 16, 9, 18, 13, 3, 6, 12\} \bmod 23$.

Verify (compute powers of 2 mod 23):
```
2^0  = 1
2^1  = 2
2^2  = 4
2^3  = 8
2^4  = 16
2^5  = 32 mod 23 = 9
2^6  = 18
2^7  = 36 mod 23 = 13
2^8  = 26 mod 23 = 3
2^9  = 6
2^10 = 12
2^11 = 24 mod 23 = 1  ✓ (order 11)
```

Now compute $y^{n/11} = 11^{2} \bmod 23 = 121 \bmod 23 = 6$.

Find $x_{11}$ such that $2^{x_{11}} \equiv 6 \pmod{23}$:

From the table: $2^9 \equiv 6 \pmod{23}$.

$$
x \equiv 9 \pmod{11}
$$

**Step 3: Combine with CRT.**

$$
x \equiv 1 \pmod{2}, \quad x \equiv 9 \pmod{11}
$$

Use Garner's formula (solve $x = 2k + 1$ for some $k$, then impose $2k + 1 \equiv 9 \pmod{11}$):

$2k \equiv 8 \pmod{11}$, so $k \equiv 4 \pmod{11}$ (since $2^{-1} \equiv 6 \pmod{11}$, $k = 8 \times 6 \bmod 11 = 48 \bmod 11 = 4$).

$x = 2 \times 4 + 1 = 9$.

**Answer:** $x = 9$.

**Verification:** $5^9 \bmod 23$.

From Part B table: $5^6 = 8$, $5^7 = 8 \times 5 = 40 \equiv 17$, $5^8 = 17 \times 5 = 85 \equiv 85 - 3 \times 23 = 16$, $5^9 = 16 \times 5 = 80 \equiv 80 - 3 \times 23 = 11$. $\checkmark$

---

## Part E: Complexity Analysis

### Classical Algorithms Compared

| Algorithm | Time | Space | Conditions |
|-----------|------|-------|------------|
| Exhaustive search | $O(n)$ | $O(1)$ | Always |
| Baby-step giant-step | $O(\sqrt{n})$ | $O(\sqrt{n})$ | Always |
| Pollard's rho | $O(\sqrt{n})$ | $O(1)$ | Always |
| Pohlig-Hellman | $O(\sqrt{q_{\max}} \cdot \log n)$ | $O(\sqrt{q_{\max}})$ | $q_{\max}$ = largest prime factor of $n$ |
| Index calculus | $L_p[1/3, c]$ | Large | $\mathbb{Z}_p^*$ only (not ECC) |

**Pohlig-Hellman detail:** If $n = q_1^{e_1} \cdots q_k^{e_k}$, complexity is $O\left(\sum_i e_i \sqrt{q_i}\right)$.

For our example ($n = 22 = 2 \times 11$): $O(\sqrt{2} + \sqrt{11}) \approx O(1.4 + 3.3) = O(5)$. Much cheaper than $O(\sqrt{22}) \approx O(5)$ BSGS, though at this scale the difference is minimal. The power of Pohlig-Hellman shows for groups with very smooth order:

**Contrast — smooth vs. prime order groups:**

For $n = 2^{40}$ (smooth): Pohlig-Hellman recursively splits into 40 DLPs in the order-2 group — trivial. Total cost: $O(40)$.

For $n$ prime (e.g., $n \approx 2^{256}$ for P-256): Pohlig-Hellman provides no speedup; reduces to one DLP in the full group. Cost: $O(\sqrt{n}) = O(2^{128})$.

### Elliptic Curve DLP vs. $\mathbb{Z}_p^*$ DLP

The key difference: **index calculus does not apply to elliptic curve groups**.

Index calculus for DLP in $\mathbb{Z}_p^*$ works by finding smooth relations: find elements $g^a \bmod p$ that factor completely over a small prime base, then solve a linear system. The "smoothness" concept — an element factors into small primes — has no meaningful analogue in an elliptic curve group where elements are points.

**Result:** For ECC with group order $n$:
- Best classical attack: Pollard's rho, $O(\sqrt{n})$.
- No sub-exponential attack known.

For DLP in $\mathbb{Z}_p^*$ with modulus of $k$ bits:
- Best classical attack: General Number Field Sieve, $L_p[1/3, c]$ — sub-exponential.

**Security comparison:** 

| Security level | $\mathbb{Z}_p^*$ key size | ECC key size | Ratio |
|---|---|---|---|
| 80 bits | 1024 bits | 160 bits | 6.4× |
| 112 bits | 2048 bits | 224 bits | 9.1× |
| 128 bits | 3072 bits | 256 bits | 12× |
| 256 bits | 15360 bits | 512 bits | 30× |

ECC achieves the same security with dramatically smaller keys because there is no sub-exponential attack.

---

## Python Verification

```python
def mod_inv(a: int, n: int) -> int:
    """Modular inverse via Fermat (n prime) or extended Euclidean."""
    return pow(a, n - 2, n)  # works when n is prime


def baby_step_giant_step(g: int, y: int, n: int, p: int) -> int:
    """
    Solve g^x ≡ y (mod p) where g has order n in Z_p*.
    Returns x in [0, n).
    """
    import math
    m = math.ceil(math.sqrt(n))

    # Baby steps: build table {y * g^j : j}
    baby = {}
    gj = 1
    for j in range(m):
        key = y * gj % p
        baby[key] = j
        gj = gj * g % p

    # Giant steps: compute (g^m)^i and look up
    gm = pow(g, m, p)
    gi = 1
    for i in range(m + 1):
        if gi in baby:
            j = baby[gi]
            x = (i * m - j) % n
            return x
        gi = gi * gm % p

    raise ValueError("DLP not found")


def pohlig_hellman(g: int, y: int, p: int, factors: list[tuple[int, int]]) -> int:
    """
    Solve g^x ≡ y (mod p) given the factorisation of group order n = p(factors).
    factors: list of (prime, exponent) pairs.
    """
    def gcd(a, b):
        while b:
            a, b = b, a % b
        return a

    def crt(residues: list[tuple[int, int]]) -> int:
        """CRT: given [(r_i, m_i)], find x with x ≡ r_i (mod m_i)."""
        x, M = 0, 1
        for r, m in residues:
            # Extend: x + M*k ≡ r (mod m)
            k = (r - x) * mod_inv(M % m, m) % m
            x += M * k
            M *= m
        return x % M

    n = 1
    for q, e in factors:
        n *= q ** e

    residues = []
    for q, e in factors:
        qe = q ** e
        # Solve x mod qe
        # h = g^(n/q), a subgroup generator of order q
        h = pow(g, n // q, p)
        # precompute powers of h for baby-step lookup
        h_table = {}
        hi = 1
        for k in range(q):
            h_table[hi] = k
            hi = hi * h % p

        # Compute x_qe = sum_{k=0}^{e-1} x_k * q^k  (base-q representation)
        x_qe = 0
        gamma = 1  # g^(-x_qe) as we accumulate

        for k in range(e):
            # Compute (y * g^(-x_qe))^(n/q^(k+1))
            exponent = n // (q ** (k + 1))
            delta = pow(y * mod_inv(gamma, p) % p, exponent, p)
            dk = h_table[delta]   # dk is the k-th digit in base q
            x_qe += dk * (q ** k)
            gamma = gamma * pow(g, dk * (q ** k), p) % p

        residues.append((x_qe, qe))

    return crt(residues)


p = 23
g = 5
n = 22   # phi(23)

# Part B: exhaustive search
print("=== Exhaustive Search: 5^x ≡ 8 (mod 23) ===")
for x in range(n):
    if pow(g, x, p) == 8:
        print(f"x = {x}")
        break

# Part C: BSGS
print("\n=== BSGS: 5^x ≡ 8 (mod 23) ===")
x_bsgs = baby_step_giant_step(g, 8, n, p)
print(f"x = {x_bsgs}")
print(f"Verify: 5^{x_bsgs} mod 23 = {pow(g, x_bsgs, p)}")

# Part D: Pohlig-Hellman
print("\n=== Pohlig-Hellman: 5^x ≡ 11 (mod 23) ===")
x_ph = pohlig_hellman(g, 11, p, [(2, 1), (11, 1)])
print(f"x = {x_ph}")
print(f"Verify: 5^{x_ph} mod 23 = {pow(g, x_ph, p)}")


# Expected output:
# === Exhaustive Search: 5^x ≡ 8 (mod 23) ===
# x = 6
#
# === BSGS: 5^x ≡ 8 (mod 23) ===
# x = 6
# Verify: 5^6 mod 23 = 8
#
# === Pohlig-Hellman: 5^x ≡ 11 (mod 23) ===
# x = 9
# Verify: 5^9 mod 23 = 11
```

---

## Key Takeaways

1. **All three algorithms give the same correct answer** for the same problem — they differ in computational cost, not correctness.

2. **Pohlig-Hellman requires knowing the group order factorisation.** In practice, factoring large numbers is hard, but for standard Diffie-Hellman groups, the group order $p - 1$ is publicly known.

3. **Safe primes defeat Pohlig-Hellman:** For a safe prime $p = 2q + 1$, the order is $p - 1 = 2q$. The only prime factor exceeding 2 is $q \approx p/2$. Pohlig-Hellman reduces to a DLP in the order-$q$ subgroup, which requires $O(\sqrt{q}) = O(\sqrt{p/2})$ work — no improvement over working in the full group.

4. **ECC groups are designed with prime order:** P-256's group order is prime, making Pohlig-Hellman completely inapplicable. Every non-identity element has order equal to the full group order $n$.

5. **Index calculus does not apply to ECC:** This is why ECC at 256-bit key size provides 128-bit security, while DH in $\mathbb{Z}_p^*$ requires a 3072-bit modulus for the same 128-bit security level.
