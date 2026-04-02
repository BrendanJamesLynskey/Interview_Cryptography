# Modular Arithmetic

## Prerequisites
- Integer arithmetic: division, remainders, factors
- Basic algebra: solving linear equations
- Understanding of groups and rings is helpful but not required
- Familiarity with binary representation and bitwise operations

---

## Concept Reference

### The Integers Modulo $n$

For a positive integer $n$, the **integers modulo $n$** form the set $\mathbb{Z}_n = \{0, 1, 2, \ldots, n-1\}$. Arithmetic in $\mathbb{Z}_n$ wraps around: the result of any operation is reduced by taking the remainder when divided by $n$.

Formally, $a \equiv b \pmod{n}$ (read "$a$ is congruent to $b$ modulo $n$") means $n \mid (a - b)$, i.e., $n$ divides $a - b$ exactly.

**Examples:**
- $17 \equiv 5 \pmod{12}$ (clock arithmetic)
- $-3 \equiv 7 \pmod{10}$ (adding 10 to make positive)
- $100 \equiv 4 \pmod{12}$

Congruence is an equivalence relation: it is reflexive, symmetric, and transitive. Operations on congruence classes are well-defined: if $a \equiv a' \pmod{n}$ and $b \equiv b' \pmod{n}$, then $a + b \equiv a' + b' \pmod{n}$ and $a \cdot b \equiv a' \cdot b' \pmod{n}$.

---

### Greatest Common Divisor and Coprimality

The **greatest common divisor** $\gcd(a, b)$ is the largest integer dividing both $a$ and $b$.

Two integers are **coprime** (or relatively prime) if $\gcd(a, b) = 1$. Coprimality is the condition required for a modular multiplicative inverse to exist.

**Bezout's identity:** For any integers $a, b$, there exist integers $s, t$ (Bezout coefficients) such that:

$$
\gcd(a, b) = s \cdot a + t \cdot b
$$

This identity is the foundation of the extended Euclidean algorithm and modular inversion.

---

### The Euclidean Algorithm

The Euclidean algorithm computes $\gcd(a, b)$ efficiently using the identity:

$$
\gcd(a, b) = \gcd(b, a \bmod b)
$$

**Example:** $\gcd(48, 18)$

```
gcd(48, 18):
  48 = 2 × 18 + 12  →  gcd(18, 12)
  18 = 1 × 12 + 6   →  gcd(12, 6)
  12 = 2 × 6  + 0   →  gcd(6, 0) = 6

Therefore gcd(48, 18) = 6
```

**Time complexity:** $O(\log(\min(a, b)))$ divisions. The worst case is consecutive Fibonacci numbers.

```python
def gcd(a: int, b: int) -> int:
    """Euclidean algorithm. Returns gcd(a, b)."""
    while b:
        a, b = b, a % b
    return a

# Examples:
print(gcd(48, 18))   # 6
print(gcd(35, 64))   # 1 (coprime)
print(gcd(0, 7))     # 7
```

---

### The Extended Euclidean Algorithm

The **extended Euclidean algorithm** computes $\gcd(a, b)$ and simultaneously finds the Bezout coefficients $s, t$ satisfying $\gcd(a, b) = s \cdot a + t \cdot b$.

This is the standard method for computing **modular multiplicative inverses**. If $\gcd(a, n) = 1$, then there exist $s, t$ with $s \cdot a + t \cdot n = 1$, which reduces to $s \cdot a \equiv 1 \pmod{n}$. Thus $s \bmod n$ is the multiplicative inverse of $a$ modulo $n$.

**Example:** Find $17^{-1} \pmod{43}$, i.e., find $s$ such that $17s \equiv 1 \pmod{43}$.

Apply extended Euclidean to $(43, 17)$:

```
Step 1:  43 = 2 × 17 + 9       →  9  = 43 - 2 × 17
Step 2:  17 = 1 × 9  + 8       →  8  = 17 - 1 × 9
Step 3:  9  = 1 × 8  + 1       →  1  = 9  - 1 × 8
Step 4:  8  = 8 × 1  + 0       gcd = 1

Back-substitute:
  1 = 9  - 1 × 8
    = 9  - 1 × (17 - 1 × 9)    = 2 × 9  - 1 × 17
    = 2 × (43 - 2 × 17) - 1 × 17
    = 2 × 43 - 5 × 17

So: 2 × 43 + (-5) × 17 = 1
Reducing mod 43:  (-5) × 17 ≡ 1 (mod 43)
Answer: 17^(-1) ≡ -5 ≡ 38 (mod 43)

Verification: 17 × 38 = 646 = 15 × 43 + 1  ✓
```

```python
def extended_gcd(a: int, b: int) -> tuple[int, int, int]:
    """
    Returns (gcd, s, t) such that gcd = s*a + t*b.
    """
    if b == 0:
        return a, 1, 0
    gcd, s1, t1 = extended_gcd(b, a % b)
    # s*a + t*b = gcd
    # s1*b + t1*(a%b) = gcd
    # s1*b + t1*(a - (a//b)*b) = gcd
    # t1*a + (s1 - (a//b)*t1)*b = gcd
    return gcd, t1, s1 - (a // b) * t1


def mod_inverse(a: int, n: int) -> int:
    """
    Returns a^(-1) mod n.
    Raises ValueError if gcd(a, n) != 1 (inverse does not exist).
    """
    gcd, s, _ = extended_gcd(a % n, n)
    if gcd != 1:
        raise ValueError(f"Inverse of {a} mod {n} does not exist (gcd={gcd})")
    return s % n


# Expected outputs:
print(mod_inverse(17, 43))   # 38
print(mod_inverse(3, 7))     # 5  (3 * 5 = 15 = 2*7 + 1)
print(mod_inverse(65537, 2 ** 127 - 1))  # Large number, computes quickly
```

---

### Modular Exponentiation

Modular exponentiation computes $a^e \bmod n$ efficiently. Naive repeated multiplication is $O(e)$ multiplications — infeasible for cryptographic $e$ (e.g., $e = 2^{64}$).

**Square-and-multiply (binary exponentiation):**

Write $e$ in binary. For each bit, square the current result. If the bit is 1, also multiply by $a$.

$$
a^e \bmod n \quad \text{computed in } O(\log e) \text{ multiplications}
$$

**Example:** $3^{13} \bmod 17$

$13 = 1101_2$

```
Start with result = 1, base = 3

Bit 3 (MSB=1): result = 1 × 3 = 3,       base² = 9
Bit 2 (1):     result = 3 × 9 = 27 = 10,  base² = 9² = 81 = 13
Bit 1 (0):     result stays 10,            base² = 13² = 169 = 16
Bit 0 (LSB=1): result = 10 × 16 = 160 = 7

Therefore: 3^13 mod 17 = 7
Verify:    3^13 = 1594323; 1594323 mod 17 = 7  ✓
```

```python
def mod_exp(base: int, exp: int, mod: int) -> int:
    """
    Compute base^exp mod mod using square-and-multiply.
    O(log exp) multiplications. Equivalent to Python's pow(base, exp, mod).
    """
    result = 1
    base %= mod
    while exp > 0:
        if exp & 1:               # current bit is 1
            result = result * base % mod
        base = base * base % mod  # square
        exp >>= 1                 # move to next bit
    return result


# Expected outputs:
print(mod_exp(3, 13, 17))      # 7
print(mod_exp(2, 10, 1000))    # 24
print(mod_exp(7, 256, 101))    # computed quickly despite large exponent

# Python built-in is faster (C implementation):
print(pow(3, 13, 17))          # 7 (same result)
```

**Time complexity:** $O(\log e)$ modular multiplications. Each multiplication of $k$-bit numbers costs $O(k^2)$ bit operations (schoolbook) or $O(k \log k)$ with FFT-based methods. Total: $O(k^2 \log k)$ bit operations for a $k$-bit modulus. In practice, Python's `pow(a, e, n)` uses optimised Montgomery multiplication.

---

### Euler's Totient Function

**Euler's totient function** $\phi(n)$ counts the integers in $\{1, 2, \ldots, n\}$ that are coprime to $n$:

$$
\phi(n) = |\{k : 1 \leq k \leq n,\ \gcd(k, n) = 1\}|
$$

Key values:
- $\phi(p) = p - 1$ for prime $p$ (all integers $1$ to $p-1$ are coprime to $p$)
- $\phi(p^k) = p^{k-1}(p-1)$
- $\phi(mn) = \phi(m)\phi(n)$ when $\gcd(m, n) = 1$ (multiplicativity)
- $\phi(pq) = (p-1)(q-1)$ for distinct primes $p, q$ — the RSA case

**Euler's theorem:** For $\gcd(a, n) = 1$:

$$
a^{\phi(n)} \equiv 1 \pmod{n}
$$

This is the theoretical basis for RSA decryption correctness. **Fermat's little theorem** is the special case for prime $p$:

$$
a^{p-1} \equiv 1 \pmod{p} \quad \text{for } \gcd(a, p) = 1
$$

**Carmichael's function** $\lambda(n)$ is the smallest positive integer $m$ such that $a^m \equiv 1 \pmod{n}$ for all $a$ coprime to $n$. It always divides $\phi(n)$ and is often strictly smaller. For $n = pq$: $\lambda(pq) = \text{lcm}(p-1, q-1)$. Modern RSA implementations use $\lambda(n)$ because it yields a smaller private exponent with equivalent security.

---

### Chinese Remainder Theorem (CRT)

The **Chinese Remainder Theorem** states: if $n_1, n_2, \ldots, n_k$ are pairwise coprime (i.e., $\gcd(n_i, n_j) = 1$ for $i \neq j$), then for any integers $a_1, \ldots, a_k$, the system of congruences:

$$
x \equiv a_1 \pmod{n_1},\quad x \equiv a_2 \pmod{n_2},\quad \ldots,\quad x \equiv a_k \pmod{n_k}
$$

has a unique solution $x$ modulo $N = n_1 n_2 \cdots n_k$.

**Two-modulus construction formula:**

$$
x = a_1 \cdot M_1 \cdot (M_1^{-1} \bmod n_1) + a_2 \cdot M_2 \cdot (M_2^{-1} \bmod n_2) \pmod{N}
$$

where $M_1 = n_2$, $M_2 = n_1$.

The simplified Garner form for two moduli $p$ and $q$:

```
Given: x ≡ a (mod p)  and  x ≡ b (mod q)

Garner's formula:
  h = (a - b) × q_inv  mod p      where q_inv = q^(-1) mod p
  x = b + h × q
```

**Cryptographic uses of CRT:**
1. **RSA-CRT decryption:** Compute $m_p = c^{d_p} \bmod p$ and $m_q = c^{d_q} \bmod q$ separately, then combine. Provides ~4× speedup over direct computation modulo $n$.
2. **Multi-prime RSA:** Splitting the modulus into more factors (e.g., $n = pqr$) reduces each exponentiation modulus size further.
3. **Garner representation** in lattice-based cryptography and NTT-based polynomial multiplication.

```python
def crt_two(a: int, p: int, b: int, q: int) -> int:
    """
    Solve: x ≡ a (mod p), x ≡ b (mod q).
    Assumes gcd(p, q) = 1.
    Returns unique x in [0, p*q).
    """
    q_inv = mod_inverse(q, p)
    h = (a - b) * q_inv % p
    return b + h * q


# Example: x ≡ 2 (mod 3), x ≡ 3 (mod 5)
# Solution: x ≡ 8 (mod 15)
x = crt_two(2, 3, 3, 5)
print(x)          # 8
print(x % 3)      # 2  ✓
print(x % 5)      # 3  ✓
```

---

### Discrete Logarithm Problem

The **discrete logarithm problem (DLP)** in $\mathbb{Z}_p^*$: given prime $p$, generator $g$, and $y = g^x \bmod p$, find $x$.

While modular exponentiation (computing $y$ from $x$) is efficient — $O(\log x)$ multiplications — the inverse (finding $x$ from $y$) has no known polynomial-time classical algorithm for general $p$.

**Best-known algorithms:**

| Algorithm | Time | Applicable to |
|---|---|---|
| Baby-step giant-step | $O(\sqrt{p})$ time and space | Any group |
| Pohlig-Hellman | $O(\sqrt{q})$ where $q$ is largest prime factor of $p-1$ | When $p-1$ is smooth |
| Index calculus | $L_p[1/3]$ sub-exponential | $\mathbb{Z}_p^*$ only |
| Shor's algorithm | Polynomial | Quantum computer |

The **subgroup order** must have a large prime factor. If $p-1$ is smooth (all prime factors are small), Pohlig-Hellman breaks the DLP efficiently. This motivates using **safe primes** $p = 2q + 1$ (where $q$ is prime) in Diffie-Hellman.

---

## Tier 1 — Fundamentals

### Question F1
**Explain the extended Euclidean algorithm and show how it is used to compute $7^{-1} \pmod{26}$.**

**Answer:**

The extended Euclidean algorithm finds $\gcd(a, b)$ along with integers $s, t$ satisfying Bezout's identity $s \cdot a + t \cdot b = \gcd(a, b)$.

To find $7^{-1} \bmod 26$, compute $\gcd(7, 26)$ with Bezout coefficients:

```
26 = 3 × 7 + 5    →  5  = 26 - 3 × 7
7  = 1 × 5 + 2    →  2  = 7  - 1 × 5
5  = 2 × 2 + 1    →  1  = 5  - 2 × 2
2  = 2 × 1 + 0    gcd = 1

Back-substitute:
  1 = 5  - 2 × 2
    = 5  - 2 × (7 - 1 × 5)      = 3 × 5  - 2 × 7
    = 3 × (26 - 3 × 7) - 2 × 7  = 3 × 26 - 11 × 7

So: 3 × 26 + (-11) × 7 = 1
Reducing mod 26: (-11) × 7 ≡ 1 (mod 26)
Answer: 7^(-1) ≡ -11 ≡ 15 (mod 26)

Verification: 7 × 15 = 105 = 4 × 26 + 1  ✓
```

**Why the inverse exists:** $\gcd(7, 26) = 1$. A multiplicative inverse of $a$ modulo $n$ exists if and only if $\gcd(a, n) = 1$.

**Common mistake:** Not reducing the Bezout coefficient modulo $n$ at the end. The coefficient $s$ from the algorithm can be negative; the canonical inverse is $s \bmod n \in \{0, 1, \ldots, n-1\}$.

---

### Question F2
**Compute $7^{500} \bmod 13$ using Fermat's little theorem.**

**Answer:**

Since 13 is prime and $\gcd(7, 13) = 1$, Fermat's little theorem states:

$$
7^{12} \equiv 1 \pmod{13}
$$

Reduce the exponent 500 modulo 12:

$$
500 = 41 \times 12 + 8 \quad \Rightarrow \quad 500 \equiv 8 \pmod{12}
$$

Therefore:

$$
7^{500} = 7^{41 \times 12 + 8} = (7^{12})^{41} \times 7^8 \equiv 1^{41} \times 7^8 \equiv 7^8 \pmod{13}
$$

Compute $7^8 \bmod 13$ by repeated squaring:

$$
7^2 = 49 \equiv 10 \pmod{13}
$$
$$
7^4 = 10^2 = 100 \equiv 9 \pmod{13}
$$
$$
7^8 = 9^2 = 81 \equiv 3 \pmod{13}
$$

**Answer:** $7^{500} \equiv 3 \pmod{13}$.

**Common mistake:** Forgetting that the exponent reduction uses $\phi(p) = p - 1 = 12$ for prime $p$, not $p$ itself.

---

### Question F3
**What is the Chinese Remainder Theorem? Give a concrete example and explain one cryptographic use.**

**Answer:**

The CRT states that a system of congruences with pairwise coprime moduli has a unique solution modulo the product of the moduli.

**Example:** Find $x$ such that $x \equiv 1 \pmod{3}$ and $x \equiv 2 \pmod{5}$.

Using Garner's formula:
```
q_inv = 5^(-1) mod 3

5 mod 3 = 2, and 2 × 2 = 4 ≡ 1 (mod 3), so 5^(-1) mod 3 = 2.

h = (1 - 2) × 2  mod 3 = (-1) × 2 mod 3 = -2 mod 3 = 1
x = 2 + 1 × 5 = 7
```

Check: $7 \bmod 3 = 1$ and $7 \bmod 5 = 2$. The unique solution in $[0, 15)$ is $x = 7$.

**Cryptographic use — RSA-CRT decryption:** RSA decryption normally computes $m = c^d \bmod n$ where $n = pq$ is 2048 bits. Using CRT:
1. Compute $m_p = c^{d_p} \bmod p$ and $m_q = c^{d_q} \bmod q$ (each 1024 bits).
2. Combine with CRT to recover $m$.

The two half-size exponentiations are each approximately 4× cheaper than one full-size exponentiation, yielding a ~4× overall speedup.

---

### Question F4
**Define the discrete logarithm problem. Why is it believed to be hard and what threat does quantum computing pose?**

**Answer:**

Given a prime $p$, a generator $g$ of $\mathbb{Z}_p^*$, and $y = g^x \bmod p$, the **discrete logarithm problem (DLP)** is to find $x$.

**Why it is believed hard:** No polynomial-time classical algorithm is known for the general case. The best classical algorithm (index calculus / GNFS for $\mathbb{Z}_p^*$) runs in sub-exponential time $L_p[1/3, c] = e^{(c + o(1))(\ln p)^{1/3}(\ln \ln p)^{2/3}}$. For a 2048-bit prime, this requires approximately $2^{112}$ operations — computationally infeasible.

**Quantum threat:** Shor's algorithm (1994) solves DLP in polynomial time on a quantum computer. The circuit depth required is $O((\log p)^3)$ quantum gates. A fault-tolerant quantum computer with thousands of logical qubits would break classical DLP-based cryptography (Diffie-Hellman, DSA, ElGamal) completely. This is why post-quantum cryptography (lattice-based, hash-based, code-based) is being standardised by NIST.

---

## Tier 2 — Intermediate

### Question I1
**Explain the Pohlig-Hellman algorithm. When does it reduce DLP to a tractable problem? How does this influence the choice of group in Diffie-Hellman?**

**Answer:**

**Pohlig-Hellman** reduces the DLP in a group of order $n$ to a collection of DLPs in subgroups of prime order, then combines results using CRT.

If $n = \prod p_i^{e_i}$, the algorithm:
1. For each prime power factor $p_i^{e_i}$, solve the DLP in the subgroup of order $p_i^{e_i}$ using $O(e_i \cdot \sqrt{p_i})$ group operations.
2. Combine the $x \bmod p_i^{e_i}$ results via CRT to recover $x \bmod n$.

**Total complexity:** $O\left(\sum_i e_i \sqrt{p_i} \cdot \log n\right)$.

If $n$ is **smooth** (all prime factors $p_i$ are small, say $\leq 2^{20}$), each subgroup DLP is trivial and the full DLP collapses.

**Impact on group choice:**

For Diffie-Hellman in $\mathbb{Z}_p^*$, $p - 1$ must have a large prime factor $q$ to prevent Pohlig-Hellman. If all prime factors of $p - 1$ are small, the DLP can be broken efficiently.

**Mitigation — safe primes:** Choose $p = 2q + 1$ where $q$ is a large prime. Then $p - 1 = 2q$ has only one small prime factor (2). The DLP reduces to a DLP in the subgroup of order $q$, which has no shortcuts. RFC 3526 specifies safe primes of 1536, 2048, 3072, and 4096 bits for IKE/TLS.

**Key generation rule:** The private key $x$ must be chosen uniformly from $\{1, \ldots, q-1\}$ (the large prime order subgroup), not from $\{1, \ldots, p-2\}$, to avoid leaking information through subgroup membership.

---

### Question I2
**Explain Montgomery modular multiplication. Why is it preferred over naive reduction for cryptographic implementations?**

**Answer:**

Naive modular multiplication requires a division to compute $a \cdot b \bmod n$, and division is expensive on hardware. **Montgomery multiplication** replaces division by $n$ with a series of additions and shifts, which are much faster.

**Montgomery form:** Choose $R = 2^k$ where $k$ is the number of bits in $n$ (so $R > n$ and $R$ is a power of 2). The **Montgomery representation** of $a$ is $\hat{a} = aR \bmod n$.

**Montgomery product** $\text{MonPro}(x, y)$ computes $xyR^{-1} \bmod n$ without division:

```
Given: x = aR mod n, y = bR mod n
Want:  MonPro(x, y) = ab·R mod n

Algorithm:
  t = x × y                          (integer multiply)
  u = (t × n') mod R                 (where n' = -n^(-1) mod R, precomputed)
  result = (t + u × n) / R           (division by R is a right-shift!)
  if result >= n: result -= n
  Output: result = ab·R mod n ✓
```

The division by $R$ is exact (the choice of $u$ guarantees $t + u \cdot n \equiv 0 \pmod{R}$) and is a free shift operation.

**Workflow for modular exponentiation:**
1. Convert inputs to Montgomery form: $\hat{a} = aR \bmod n$.
2. Perform all multiplications using MonPro.
3. Convert output back: $\text{MonPro}(\hat{a}, 1) = a \bmod n$.

**Why preferred:** Montgomery multiplication replaces the single most expensive operation in public-key cryptography (modular division / Barrett reduction) with cheaper additions and shifts. Modern CPU implementations of RSA and ECC use Montgomery arithmetic internally.

---

### Question I3
**State and prove Fermat's little theorem. Then explain why it implies that $a^p \equiv a \pmod{p}$ for all integers $a$, not just those coprime to $p$.**

**Answer:**

**Fermat's little theorem:** For prime $p$ and integer $a$ with $\gcd(a, p) = 1$:

$$
a^{p-1} \equiv 1 \pmod{p}
$$

**Proof (using group theory):** The multiplicative group $(\mathbb{Z}_p^*, \cdot)$ has order $p - 1$. By Lagrange's theorem, the order of any element divides the group order. Therefore $a^{p-1} \equiv 1 \pmod{p}$. $\square$

**Alternative proof (direct):** Consider the set $\{a, 2a, 3a, \ldots, (p-1)a\} \pmod p$. Since $\gcd(a, p) = 1$, multiplication by $a$ permutes $\{1, 2, \ldots, p-1\}$. Therefore the product of all elements satisfies:

$$
(a)(2a)(3a)\cdots((p-1)a) \equiv 1 \cdot 2 \cdot 3 \cdots (p-1) \pmod{p}
$$

$$
a^{p-1} \cdot (p-1)! \equiv (p-1)! \pmod{p}
$$

Since $\gcd((p-1)!, p) = 1$, divide both sides by $(p-1)!$: $a^{p-1} \equiv 1 \pmod{p}$.

**Extension to all $a$:** Multiply both sides by $a$: $a^p \equiv a \pmod p$.

For $\gcd(a, p) = 1$, this follows directly. For $p \mid a$: $a \equiv 0 \pmod p$, so $a^p \equiv 0 \equiv a \pmod p$. Therefore $a^p \equiv a \pmod p$ holds for **all integers $a$**.

This generalised form is used in primality testing: if $p$ is prime, $a^p \equiv a \pmod p$ for every $a$. If we find an $a$ for which this fails, $p$ is definitely composite.

---

## Tier 3 — Advanced

### Question A1
**Explain the Baby-step Giant-step (BSGS) algorithm for the discrete logarithm. Derive its time and space complexity. When is Pollard's rho algorithm preferred?**

**Answer:**

**Baby-step Giant-step (BSGS)** solves $y = g^x \bmod p$ in a group of order $n$ in $O(\sqrt{n})$ time and space.

**Algorithm:**

Let $m = \lceil \sqrt{n} \rceil$. Write $x = im - j$ where $0 \leq i, j < m$. Then:

$$
g^x = g^{im-j} = (g^m)^i \cdot g^{-j} \quad \Rightarrow \quad y \cdot g^j = (g^m)^i
$$

**Steps:**
1. **Baby steps:** Precompute and store all pairs $(j, y \cdot g^j \bmod p)$ for $j = 0, 1, \ldots, m-1$ in a hash table. $O(m)$ time and space.
2. **Giant steps:** For each $i = 0, 1, \ldots, m-1$, compute $(g^m)^i \bmod p$ and look it up in the hash table. $O(m)$ time, $O(1)$ space per step.
3. A match $(j, (g^m)^i)$ gives $x = im - j \bmod n$.

**Complexity:** $O(\sqrt{n})$ time and $O(\sqrt{n})$ space.

**Pollard's rho algorithm:** Also $O(\sqrt{n})$ time but only $O(1)$ space, using Floyd's cycle detection on a pseudo-random walk in the group. It is preferred when memory is the bottleneck (e.g., groups of order $2^{128}$, where BSGS would require $2^{64}$ storage — $\sim 10^{20}$ bytes — while Pollard's rho uses constant memory).

**Parallelisation:** Pollard's rho parallelises almost linearly: with $k$ processors, the running time drops to $O(\sqrt{n}/k)$. BSGS is harder to parallelise efficiently due to the shared hash table. For attacking ECC groups, parallelised Pollard's rho is the state-of-the-art classical attack.

---

### Question A2
**Describe the structure of $\mathbb{Z}_n^*$ using the Chinese Remainder Theorem and the concept of primitive roots. For which $n$ does a primitive root exist?**

**Answer:**

A **primitive root** modulo $n$ is an element $g \in \mathbb{Z}_n^*$ whose multiplicative order equals $\phi(n)$ — i.e., $g$ generates the entire group. Such a $g$ exists if and only if $\mathbb{Z}_n^*$ is **cyclic**.

**Classification (Gauss):** $\mathbb{Z}_n^*$ is cyclic (primitive roots exist) if and only if:
- $n = 1$ or $n = 2$ (trivial)
- $n = 4$
- $n = p^k$ for odd prime $p$ and $k \geq 1$
- $n = 2p^k$ for odd prime $p$ and $k \geq 1$

For all other $n$ (e.g., $n = 8$, $n = 15$, $n = pq$ with distinct odd primes), no primitive root exists.

**Structure via CRT:** For $n = p_1^{e_1} p_2^{e_2} \cdots p_k^{e_k}$:

$$
\mathbb{Z}_n^* \cong \mathbb{Z}_{p_1^{e_1}}^* \times \mathbb{Z}_{p_2^{e_2}}^* \times \cdots \times \mathbb{Z}_{p_k^{e_k}}^*
$$

Each $\mathbb{Z}_{p^e}^*$ is cyclic of order $\phi(p^e) = p^{e-1}(p-1)$. The full group is cyclic iff all these subgroup orders are pairwise coprime, which happens exactly in the cases above.

**Cryptographic consequence:** Diffie-Hellman requires a large prime-order subgroup. In $\mathbb{Z}_p^*$ with safe prime $p = 2q + 1$, the group structure is $\mathbb{Z}_{p-1}^* \cong \mathbb{Z}_2 \times \mathbb{Z}_q$. Choosing the generator from the order-$q$ subgroup gives a simple, well-understood group structure for the DLP-based protocol. This is why safe primes and prime-order subgroups are the standard choice.
