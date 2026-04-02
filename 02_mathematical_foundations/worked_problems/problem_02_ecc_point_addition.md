# Problem 02: ECC Point Addition and Doubling

## Problem Statement

Work through elliptic curve arithmetic on a concrete small curve. All answers should be verified step by step.

**Curve:** $E: y^2 \equiv x^3 - x + 1 \pmod{7}$

(In Weierstrass form: $a = -1 \equiv 6$, $b = 1$, $p = 7$.)

**Part A:** Find all points on $E(\mathbb{F}_7)$ including the point at infinity.

**Part B:** Given $P = (0, 1)$ and $Q = (6, 3)$, compute $P + Q$.

**Part C:** Compute $2P = P + P$ (point doubling for $P = (0, 1)$).

**Part D:** Compute $[4]P$ using the double-and-add method.

**Part E:** Find the order of the point $P = (0, 1)$ in the group $E(\mathbb{F}_7)$.

---

## Part A: All Points on $E(\mathbb{F}_7)$

For each $x \in \{0, 1, 2, 3, 4, 5, 6\}$, compute $x^3 - x + 1 \bmod 7$ and determine if it is a quadratic residue modulo 7.

**Quadratic residues modulo 7:** $\{1^2, 2^2, 3^2\} \bmod 7 = \{1, 4, 2\}$.

So QR mod 7 = $\{0, 1, 2, 4\}$ (including 0). Non-residues: $\{3, 5, 6\}$.

| $x$ | $x^3 - x + 1 \bmod 7$ | QR? | Points $(x, y)$ |
|-----|------------------------|-----|-----------------|
| 0 | $0 - 0 + 1 = 1$ | Yes ($1 = 1^2$) | $(0, 1)$ and $(0, 6)$ |
| 1 | $1 - 1 + 1 = 1$ | Yes | $(1, 1)$ and $(1, 6)$ |
| 2 | $8 - 2 + 1 = 7 \equiv 0$ | Yes (0 = 0²) | $(2, 0)$ only |
| 3 | $27 - 3 + 1 = 25 \equiv 4$ | Yes ($4 = 2^2$) | $(3, 2)$ and $(3, 5)$ |
| 4 | $64 - 4 + 1 = 61 \equiv 5$ | No | — |
| 5 | $125 - 5 + 1 = 121 \equiv 2$ | Yes ($2 = 3^2$... check: $3^2 = 9 \equiv 2$. Yes.) | $(5, 3)$ and $(5, 4)$ |
| 6 | $216 - 6 + 1 = 211 \equiv 1$ | Yes | $(6, 1)$ and $(6, 6)$ |

Wait — let me recheck $x = 6$: $211 = 30 \times 7 + 1$, so $211 \equiv 1$. Yes.

**All points on $E(\mathbb{F}_7)$:**

$$
E(\mathbb{F}_7) = \{\mathcal{O}, (0,1), (0,6), (1,1), (1,6), (2,0), (3,2), (3,5), (5,3), (5,4), (6,1), (6,6)\}
$$

**Group order:** $\#E(\mathbb{F}_7) = 12$ (11 finite points + point at infinity).

**Hasse bound check:** $|\#E - (p+1)| = |12 - 8| = 4 \leq 2\sqrt{7} \approx 5.29$. $\checkmark$

---

## Part B: Point Addition $P + Q$ where $P = (0, 1)$ and $Q = (6, 3)$

Wait — is $Q = (6, 3)$ on the curve? Check: $3^2 = 9 \equiv 2 \pmod 7$, but $6^3 - 6 + 1 = 216 - 5 = 211 \equiv 1 \pmod 7$. We need $y^2 = 1$, so $y = 1$ or $y = 6$. The point $(6, 3)$ is NOT on this curve.

Use $Q = (6, 6)$ instead (which is on the curve).

**Compute $P + Q$ where $P = (0, 1)$, $Q = (6, 6)$:**

Since $P \neq Q$ and $P \neq -Q$ (check: $-P = (0, -1) = (0, 6) \neq Q$), use the addition formula.

$$
\lambda = \frac{y_Q - y_P}{x_Q - x_P} \bmod p = \frac{6 - 1}{6 - 0} \bmod 7 = \frac{5}{6} \bmod 7
$$

Find $6^{-1} \bmod 7$: $6 \times 6 = 36 = 5 \times 7 + 1 \equiv 1$, so $6^{-1} \equiv 6 \pmod 7$.

$$
\lambda = 5 \times 6 \bmod 7 = 30 \bmod 7 = 2
$$

$$
x_R = \lambda^2 - x_P - x_Q \bmod 7 = 4 - 0 - 6 = -2 \equiv 5 \pmod 7
$$

$$
y_R = \lambda(x_P - x_R) - y_P \bmod 7 = 2(0 - 5) - 1 = -10 - 1 = -11 \equiv 3 \pmod 7
$$

**Result:** $P + Q = (0,1) + (6,6) = (5, 3)$.

**Verification:** Is $(5, 3)$ on the curve? $3^2 = 9 \equiv 2 \pmod 7$; $5^3 - 5 + 1 = 121 \equiv 2 \pmod 7$. $2 = 2$. $\checkmark$

$(5, 3)$ is indeed in our list of points.

---

## Part C: Point Doubling $2P$ where $P = (0, 1)$

Use the doubling formula (since $P = Q$, use the tangent):

$$
\lambda = \frac{3x_P^2 + a}{2y_P} \bmod p
$$

Here $a = -1 \equiv 6 \pmod 7$, $x_P = 0$, $y_P = 1$:

$$
\lambda = \frac{3 \times 0^2 + 6}{2 \times 1} \bmod 7 = \frac{6}{2} \bmod 7
$$

Find $2^{-1} \bmod 7$: $2 \times 4 = 8 \equiv 1 \pmod 7$, so $2^{-1} = 4$.

$$
\lambda = 6 \times 4 \bmod 7 = 24 \bmod 7 = 3
$$

$$
x_{2P} = \lambda^2 - 2x_P \bmod 7 = 9 - 0 = 9 \equiv 2 \pmod 7
$$

$$
y_{2P} = \lambda(x_P - x_{2P}) - y_P \bmod 7 = 3(0 - 2) - 1 = -6 - 1 = -7 \equiv 0 \pmod 7
$$

**Result:** $2P = (2, 0)$.

**Verification:** Is $(2, 0)$ on the curve? $0^2 = 0$; $2^3 - 2 + 1 = 7 \equiv 0 \pmod 7$. $0 = 0$. $\checkmark$

Note that $(2, 0)$ is a point of order 2: $-P = (2, -0) = (2, 0) = P$, so $2 \cdot (2, 0) = \mathcal{O}$.

---

## Part D: Compute $[4]P$ using Double-and-Add

We have $P = (0, 1)$ and we want $[4]P$.

$4 = 100_2$ — use left-to-right binary method:

```
k = 4 = 100₂
R = identity (∞)

Process bit 2 (MSB = 1):
  R = 2R + P = 2(∞) + P = ∞ + P = P = (0, 1)

Process bit 1 (= 0):
  R = 2R = 2(0,1) = (2, 0)     [computed in Part C]

Process bit 0 (= 0):
  R = 2R = 2(2,0)
```

We need $2 \cdot (2, 0)$. Since $y_{(2,0)} = 0$, the tangent at this point is vertical, meaning $2 \cdot (2, 0) = \mathcal{O}$.

$$
[4]P = \mathcal{O}
$$

This means $P = (0, 1)$ has **order 4** in $E(\mathbb{F}_7)$.

---

## Part E: Order of Point $P = (0, 1)$

We compute successive multiples until we reach $\mathcal{O}$:

| $k$ | $[k]P$ | Computation |
|-----|--------|-------------|
| 1 | $(0, 1)$ | $P$ |
| 2 | $(2, 0)$ | Doubling from Part C |
| 3 | $[3]P = [2]P + P = (2,0) + (0,1)$ | See below |
| 4 | $\mathcal{O}$ | $2 \cdot (2,0) = \mathcal{O}$ (Part D) |

**Compute $[3]P = (2, 0) + (0, 1)$:**

$$
\lambda = \frac{1 - 0}{0 - 2} \bmod 7 = \frac{1}{-2} \bmod 7 = \frac{1}{5} \bmod 7
$$

Find $5^{-1} \bmod 7$: $5 \times 3 = 15 \equiv 1$, so $5^{-1} = 3$.

$$
\lambda = 1 \times 3 = 3 \pmod 7
$$

$$
x_3 = 9 - 2 - 0 = 7 \equiv 0 \pmod 7
$$

$$
y_3 = 3(2 - 0) - 0 = 6 \pmod 7
$$

$[3]P = (0, 6)$.

**Summary of orbit of $P$:**

| $k$ | $[k]P$ |
|-----|--------|
| 0 | $\mathcal{O}$ |
| 1 | $(0, 1)$ |
| 2 | $(2, 0)$ |
| 3 | $(0, 6)$ |
| 4 | $\mathcal{O}$ |

**Order of $P$ is 4.**

This makes sense: the group order is 12, and $4 \mid 12$ (Lagrange's theorem). The subgroup generated by $P$ is $\{(0,1), (2,0), (0,6), \mathcal{O}\}$, a cyclic subgroup of order 4.

**Finding a generator of the full group:** Since $\#E = 12 = 4 \times 3$, a generator of the full group must have order 12. Try $G = (3, 2)$:

Compute $[12]G$ and check that no smaller multiple gives $\mathcal{O}$. (A generator must have order not dividing 1, 2, 3, 4, or 6.)

---

## Python Verification

```python
def mod_inv(a: int, p: int) -> int:
    """Modular inverse using Fermat's little theorem (p is prime)."""
    return pow(a, p - 2, p)


def point_add(P, Q, a: int, p: int):
    """Add two points on y^2 = x^3 + ax + b mod p."""
    if P is None:
        return Q
    if Q is None:
        return P
    x1, y1 = P
    x2, y2 = Q

    if x1 == x2:
        if (y1 + y2) % p == 0:
            return None            # P + (-P) = infinity
        if y1 == 0:
            return None            # tangent at point with y=0 is vertical
        # Doubling
        lam = (3 * x1 * x1 + a) * mod_inv(2 * y1, p) % p
    else:
        lam = (y2 - y1) * mod_inv(x2 - x1, p) % p

    x3 = (lam * lam - x1 - x2) % p
    y3 = (lam * (x1 - x3) - y1) % p
    return (x3, y3)


def scalar_mul(k: int, P, a: int, p: int):
    """Compute k*P using double-and-add."""
    Q = None
    while k > 0:
        if k & 1:
            Q = point_add(Q, P, a, p)
        P = point_add(P, P, a, p)
        k >>= 1
    return Q


# Curve: y^2 = x^3 - x + 1 mod 7  (a = -1 = 6, b = 1)
a_param = 6   # a = -1 mod 7
p_val   = 7

# Part A: enumerate all points
print("=== All Points on E(F_7) ===")
points = []
for x in range(p_val):
    rhs = (pow(x, 3, p_val) + a_param * x + 1) % p_val
    for y in range(p_val):
        if pow(y, 2, p_val) == rhs:
            points.append((x, y))
            print(f"  ({x}, {y})")
points.append(None)
print(f"  infinity (O)")
print(f"Group order: {len(points)}")

# Part B: P + Q
P = (0, 1)
Q = (6, 6)
PQ = point_add(P, Q, a_param, p_val)
print(f"\n=== P + Q ===")
print(f"P = {P}, Q = {Q}")
print(f"P + Q = {PQ}")   # (5, 3)

# Part C: 2P
P2 = point_add(P, P, a_param, p_val)
print(f"\n=== 2P ===")
print(f"2P = {P2}")      # (2, 0)

# Part D: 4P
P4 = scalar_mul(4, P, a_param, p_val)
print(f"\n=== 4P ===")
print(f"4P = {P4}")      # None (infinity)

# Part E: order of P
print(f"\n=== Orbit of P = {P} ===")
R = None
for k in range(1, len(points) + 1):
    R = point_add(R, P, a_param, p_val)
    print(f"  [{k}]P = {R}")
    if R is None:
        print(f"  Order of P = {k}")
        break


# Expected output (partial):
# === All Points on E(F_7) ===
#   (0, 1)
#   (0, 6)
#   (1, 1)
#   (1, 6)
#   (2, 0)
#   (3, 2)
#   (3, 5)
#   (5, 3)
#   (5, 4)
#   (6, 1)
#   (6, 6)
#   infinity (O)
# Group order: 12
#
# === P + Q ===
# P = (0, 1), Q = (6, 6)
# P + Q = (5, 3)
#
# === 2P ===
# 2P = (2, 0)
#
# === 4P ===
# 4P = None
#
# === Orbit of P = (0, 1) ===
#   [1]P = (0, 1)
#   [2]P = (2, 0)
#   [3]P = (0, 6)
#   [4]P = None
#   Order of P = 4
```

---

## Summary of Results

| Problem | Result |
|---------|--------|
| Group order $\#E(\mathbb{F}_7)$ | 12 |
| $(0,1) + (6,6)$ | $(5, 3)$ |
| $2 \times (0,1)$ | $(2, 0)$ |
| $4 \times (0,1)$ | $\mathcal{O}$ (infinity) |
| Order of $(0,1)$ | 4 |

---

## Interview Insight

Key observations to make in an interview context:

1. **The negation rule:** $-(x, y) = (x, -y \bmod p)$. When adding $P + (-P)$, the "slope" is vertical (undefined), giving $\mathcal{O}$. This is not a special case in Jacobian coordinates.

2. **Points of order 2:** Points $(x, 0)$ (where $y = 0$) satisfy $P = -P$, so $2P = \mathcal{O}$. Here $(2, 0)$ is such a point.

3. **Lagrange's theorem:** The order of any point divides the group order. Since $\#E = 12$ and $P$ has order 4, this is consistent ($4 \mid 12$).

4. **In production ECC:** The curve order is a large prime (e.g., P-256 has prime order $n \approx 2^{256}$), ensuring every non-identity point has the same large prime order — no small subgroups exist to exploit in the Pohlig-Hellman attack.

5. **Computational cost:** This small example required field inversions at every step. Production ECC uses Jacobian projective coordinates to defer inversion, performing all intermediate additions with only multiplications and a single inversion at the end.
