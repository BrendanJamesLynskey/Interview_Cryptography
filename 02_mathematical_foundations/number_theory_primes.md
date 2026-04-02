# Number Theory and Primes

## Prerequisites
- Modular arithmetic: congruences, GCD, modular inverse
- Basic abstract algebra: groups, rings
- Understanding of Miller-Rabin primality test (covered in asymmetric_encryption.md)
- Familiarity with RSA key generation requirements

---

## Concept Reference

### Prime Numbers and Primality

A **prime** $p$ is an integer $p \geq 2$ divisible only by 1 and $p$ itself. Primes are the multiplicative building blocks of the integers.

**Fundamental theorem of arithmetic:** Every integer $n \geq 2$ has a unique factorisation $n = p_1^{e_1} p_2^{e_2} \cdots p_k^{e_k}$ with primes $p_1 < p_2 < \cdots < p_k$.

**Prime Number Theorem (PNT):** The number of primes $\leq N$, denoted $\pi(N)$, satisfies:

$$
\pi(N) \sim \frac{N}{\ln N}
$$

Equivalently, the probability that a random integer near $N$ is prime is approximately $1/\ln N$. For $N = 2^{1024}$, $\ln(2^{1024}) \approx 710$, so roughly 1 in 710 random 1024-bit integers is prime. This makes random prime generation (for RSA) efficient.

---

### Primality Testing

#### Trial Division

Divide $n$ by all primes $p \leq \sqrt{n}$. If any $p$ divides $n$, it is composite; otherwise prime.

**Cost:** $O(\sqrt{n})$ divisions — infeasible for cryptographic sizes ($n \approx 2^{1024}$).

**Practical use:** Trial division by small primes (2, 3, 5, ..., up to a few thousand) quickly eliminates ~80% of composite candidates before applying probabilistic tests.

---

#### Fermat Primality Test

By Fermat's little theorem, if $p$ is prime then $a^{p-1} \equiv 1 \pmod p$ for all $a$ with $\gcd(a, p) = 1$.

**Test:** For random $a$, check $a^{n-1} \equiv 1 \pmod n$. If not, $n$ is composite.

**Weakness — Carmichael numbers:** Composite numbers $n$ for which $a^{n-1} \equiv 1 \pmod n$ for all $\gcd(a, n) = 1$. These unconditionally fool the Fermat test. The smallest is $561 = 3 \times 7 \times 11$. There are infinitely many Carmichael numbers.

---

#### Miller-Rabin Probabilistic Test

Miller-Rabin is the practical standard for RSA prime generation. See `asymmetric_encryption.md` for the full algorithm; key properties:

- **No false negatives:** Every prime passes.
- **False positive probability:** For a composite $n$ and random base $a$, the probability of a false prime verdict is at most $1/4$.
- **With $k$ rounds:** False prime probability $\leq 4^{-k}$. With $k = 40$: probability $< 2^{-80}$.
- **Immune to Carmichael numbers:** Unlike the Fermat test.

```python
def is_prime_miller_rabin(n: int, rounds: int = 40) -> bool:
    """
    Probabilistic primality test. False positive probability < 4^(-rounds).
    """
    if n < 2: return False
    # Quick trial division by small primes
    for small in [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]:
        if n == small: return True
        if n % small == 0: return False

    # Write n-1 = 2^s * d (d odd)
    s, d = 0, n - 1
    while d % 2 == 0:
        s += 1
        d //= 2

    import random
    for _ in range(rounds):
        a = random.randrange(2, n - 1)
        x = pow(a, d, n)
        if x == 1 or x == n - 1:
            continue
        for _ in range(s - 1):
            x = pow(x, 2, n)
            if x == n - 1:
                break
        else:
            return False  # Definitely composite
    return True  # Probably prime


def generate_prime(bits: int) -> int:
    """Generate a random probable prime of the specified bit length."""
    import random
    while True:
        # Generate random odd number with correct bit length
        n = random.getrandbits(bits)
        n |= (1 << (bits - 1))  # Set MSB (ensure correct bit length)
        n |= 1                   # Set LSB (ensure odd)
        if is_prime_miller_rabin(n):
            return n

# Example:
p = generate_prime(512)
print(f"Generated {p.bit_length()}-bit prime")
print(f"Primality check: {is_prime_miller_rabin(p)}")  # True
```

---

#### AKS Deterministic Primality Test

The **Agrawal-Kayal-Saxena (AKS) test** (2002) was the first deterministic polynomial-time primality test, running in $O((\log n)^{12})$ — a theoretical breakthrough. In practice it is much slower than Miller-Rabin and not used in production cryptography.

---

### Integer Factorisation

#### Trial Division
$O(\sqrt{n})$ operations. Only practical for small factors.

#### Pollard's rho Algorithm

Pollard's rho (1975) finds a factor of $n$ in $O(n^{1/4})$ expected time using $O(1)$ space, exploiting the birthday paradox in a cyclic pseudo-random sequence.

**Algorithm:**

Define a pseudo-random function $f(x) = x^2 + c \bmod n$ for random $c$. Generate two sequences using Floyd's cycle detection:

```
x = y = 2; d = 1
while d == 1:
    x = f(x)            # tortoise: one step
    y = f(f(y))         # hare: two steps
    d = gcd(|x - y|, n)
if d != n: return d     # found factor
else: retry with different c
```

**Why it works:** The sequence $x, f(x), f^2(x), \ldots$ modulo a factor $p \mid n$ enters a cycle of length $O(\sqrt{p})$. The tortoise and hare meet when both are in the same residue class modulo $p$, at which point $\gcd(|x - y|, n)$ reveals $p$. The name "rho" comes from the shape of the sequence: a tail followed by a cycle.

**Expected time:** $O(p^{1/2}) = O(n^{1/4})$ for the smallest prime factor $p$.

```python
def pollard_rho(n: int) -> int:
    """
    Find a non-trivial factor of n using Pollard's rho.
    Returns n if no factor found (retry with different c).
    """
    import random
    if n % 2 == 0:
        return 2
    x = random.randint(2, n - 1)
    y = x
    c = random.randint(1, n - 1)
    d = 1
    while d == 1:
        x = (x * x + c) % n
        y = (y * y + c) % n
        y = (y * y + c) % n
        d = gcd(abs(x - y), n)
    return d if d != n else None


def gcd(a: int, b: int) -> int:
    while b:
        a, b = b, a % b
    return a


# Test: factor 8051 = 83 × 97
print(pollard_rho(8051))   # 83 or 97
```

#### Pollard's $p - 1$ Algorithm

Exploits smooth $p - 1$ values. If $p - 1$ is $B$-smooth (all prime factors $\leq B$), and $p \mid n$:

$$
M = \text{lcm}(1, 2, \ldots, B) = \prod_{q \leq B, q\text{ prime}} q^{\lfloor \log_B q \rfloor}
$$

Then $a^M \equiv 1 \pmod p$ for any $a$ coprime to $p$. Therefore $p \mid \gcd(a^M - 1, n)$.

```python
def pollard_pm1(n: int, B: int = 1000) -> int | None:
    """
    Pollard p-1 factorisation with smoothness bound B.
    Returns factor of n, or None if not found with this bound.
    """
    a = 2
    # For each prime power q^e <= B, multiply exponent M by q^e
    for p in sieve_primes(B):
        pe = p
        while pe <= B:
            a = pow(a, p, n)   # a = a^p mod n  (accumulate p-1 = p1^e1 * ...)
            pe *= p
    d = gcd(a - 1, n)
    if 1 < d < n:
        return d
    return None
```

#### General Number Field Sieve (GNFS)

The fastest known factorisation algorithm for large integers. Runs in sub-exponential time:

$$
L_n\left[\frac{1}{3}, \sqrt[3]{\frac{64}{9}}\right] = \exp\left(\left(\sqrt[3]{\frac{64}{9}} + o(1)\right) (\ln n)^{1/3} (\ln \ln n)^{2/3}\right)
$$

**Practical records:**

| RSA Challenge | Bits | Year | Method |
|---|---|---|---|
| RSA-512 | 512 | 1999 | GNFS |
| RSA-768 | 768 | 2009 | GNFS |
| RSA-829 | 829 | 2020 | GNFS (record as of 2025) |

RSA-2048 (2048 bits) would require approximately $10^{30}$ operations — completely infeasible.

---

### Chinese Remainder Theorem (CRT) in Factorisation

CRT is used extensively within GNFS and other algorithms to manage computations modulo multiple primes simultaneously. See `modular_arithmetic.md` for the CRT construction; here we highlight its use in RSA optimisation and cryptanalysis.

---

### Safe Primes and Strong Primes

**Safe prime:** A prime $p = 2q + 1$ where $q$ is also prime. The group $\mathbb{Z}_p^*$ then has order $p - 1 = 2q$. The Pohlig-Hellman attack reduces to a DLP in the order-$q$ subgroup — infeasible for large $q$.

**Sophie Germain prime:** $q$ in the pair $(q, 2q+1)$ is called a Sophie Germain prime. These are rarer than general primes; the density near $N$ is approximately $C/(\ln N)^2$ for a constant $C$.

**Generating safe primes:**

```python
def generate_safe_prime(bits: int) -> tuple[int, int]:
    """
    Generate a safe prime p = 2q + 1 where q is prime.
    Returns (p, q). Slower than general prime generation.
    """
    while True:
        q = generate_prime(bits - 1)    # q is (bits-1)-bit prime
        p = 2 * q + 1
        if is_prime_miller_rabin(p):
            return p, q

# Example usage:
p, q = generate_safe_prime(256)  # Small size for illustration
print(f"Safe prime p = {p}")
print(f"Sophie Germain prime q = {q}")
print(f"Verify: p = 2q+1? {p == 2*q+1}")
```

---

### Smooth Numbers

An integer $n$ is **$B$-smooth** if all its prime factors are $\leq B$.

The density of $B$-smooth numbers among integers up to $N$ is approximated by:

$$
\Psi(N, B) \approx N \cdot u^{-u} \quad \text{where } u = \frac{\ln N}{\ln B}
$$

This density is the basis for the sub-exponential running time of factorisation and discrete logarithm algorithms that sieve for smooth numbers in a factor base.

**Cryptographic relevance:**
- RSA prime $p - 1$ must not be smooth (prevents Pollard $p-1$).
- Diffie-Hellman prime $p - 1$ must have a large prime factor (prevents Pohlig-Hellman).
- Sub-exponential sieving algorithms (GNFS, function field sieve) find relations by searching for smooth residues, which motivates the $L_p[1/3]$ complexity.

---

## Tier 1 — Fundamentals

### Question F1
**State the Prime Number Theorem and explain how it is used to estimate the cost of generating a 2048-bit RSA prime.**

**Answer:**

The **Prime Number Theorem** states that the number of primes $\leq N$ is asymptotically:

$$
\pi(N) \sim \frac{N}{\ln N}
$$

Equivalently, the probability that a uniformly random integer near $N$ is prime is approximately $1/\ln N$.

For a 2048-bit RSA prime: $N \approx 2^{2048}$, so $\ln N = 2048 \ln 2 \approx 1419$.

**Expected candidates before finding a prime:** ~$1419/2 \approx 710$ (dividing by 2 because we only test odd numbers).

**Generation procedure:**
1. Generate a random 1024-bit integer (for a 2048-bit modulus, each prime is ~1024 bits: $N \approx 2^{1024}$, $\ln N \approx 710$).
2. Apply trial division by small primes to eliminate ~80% of candidates cheaply.
3. Apply 40 rounds of Miller-Rabin to each remaining candidate.

**Cost:** Each Miller-Rabin round costs $O(\log^3 n)$ bit operations (modular exponentiation). With ~710 expected candidates and 40 rounds each, total cost is approximately $710 \times 40 \times O((\log n)^3) = O(n^{1/3} (\log n)^3)$ bit operations — fast in practice (milliseconds on modern hardware).

---

### Question F2
**Why does integer factorisation break RSA, and what is the current record for factoring an RSA modulus?**

**Answer:**

RSA's security rests on the assumed hardness of factoring $n = pq$. If an attacker factors $n$ into $p$ and $q$, they can compute:

$$
\phi(n) = (p-1)(q-1) \quad \Rightarrow \quad d = e^{-1} \bmod \phi(n)
$$

This immediately recovers the private key $d$, allowing decryption of any ciphertext.

**Note:** The RSA Problem (finding $m$ from $c = m^e \bmod n$) may theoretically be easier than factoring, but no algorithm that solves RSA without factoring is known.

**Current record (as of 2025):** RSA-829 (829 bits, 250 decimal digits) was factored in 2020 using GNFS, requiring approximately 2,700 CPU core-years. RSA-2048 is completely out of reach — the GNFS complexity scales super-polynomially, and the resource estimate for 2048-bit factoring exceeds $10^{30}$ operations.

**NIST recommendations:**
- RSA-2048: sufficient until at least 2030 (provides 112-bit security).
- RSA-3072: recommended for beyond 2030 (provides 128-bit security).
- Transition to post-quantum algorithms recommended for long-term security.

---

### Question F3
**What is a smooth number? Give an example of a cryptographic construction that is weakened or broken when a parameter is smooth.**

**Answer:**

An integer $n$ is **$B$-smooth** if every prime factor of $n$ is $\leq B$. For example:
- $72 = 2^3 \times 3^2$ is 3-smooth.
- $360 = 2^3 \times 3^2 \times 5$ is 5-smooth.
- $123$ is 41-smooth (factors: 3 and 41).

**Cryptographic weakness — Pollard's $p-1$ attack:**

If an RSA prime $p$ has a smooth $p - 1$ (all prime factors $\leq B$ for moderate $B$), Pollard's $p-1$ algorithm factors the RSA modulus $n = pq$ in $O(B \log B)$ operations.

**Example:** If $p = 2^{16} \times 3^7 \times 5^4 \times 7^2 + 1$ (hypothetically), then $p-1$ is $B$-smooth for $B = 7$. Pollard's $p-1$ with $B = 7$ computes $M = \text{lcm}(1, \ldots, 7)$ and finds $p \mid \gcd(2^M - 1, n)$ in seconds.

**Defence:** RSA primes must have at least one large prime factor in $p-1$. Modern random large primes almost certainly satisfy this — the probability that a random 1024-bit prime has all factors of $p-1$ below $2^{40}$ is negligibly small.

---

## Tier 2 — Intermediate

### Question I1
**Describe Pollard's rho factorisation algorithm. Derive its expected running time and explain the connection to the birthday paradox.**

**Answer:**

**Algorithm:** Define a pseudo-random function $f(x) = x^2 + c \bmod n$. Generate two sequences:
- Tortoise: $x_0 = 2$, $x_{i+1} = f(x_i)$
- Hare: $y_0 = 2$, $y_{i+1} = f(f(y_i))$ (two steps per iteration)

At each step, compute $d = \gcd(|x_i - y_i|, n)$. If $1 < d < n$, $d$ is a factor.

**Why it works — birthday connection:** Consider the sequence $x_0, x_1, x_2, \ldots$ modulo a prime factor $p \mid n$. The values $x_i \bmod p$ form a pseudo-random sequence in $\{0, 1, \ldots, p-1\}$. By the birthday paradox, a collision $x_i \equiv x_j \pmod p$ is expected after $\Theta(\sqrt{p})$ steps. When $x_i \equiv x_j \pmod p$ but $x_i \not\equiv x_j \pmod n$, we have $p \mid (x_i - x_j)$ but $n \nmid (x_i - x_j)$, so $\gcd(x_i - x_j, n) = p$.

Floyd's cycle detection finds the collision in linear time (when the tortoise and hare are at the same point in the cycle modulo $p$) without storing the sequence. The hare moves at twice the speed; they must meet within $O(\sqrt{p})$ steps.

**Expected running time:** $O(p^{1/2})$ where $p$ is the smallest prime factor. For $n \approx N$, the smallest factor is at most $N^{1/2}$, giving worst case $O(N^{1/4})$ — better than trial division's $O(N^{1/2})$.

**Space:** $O(1)$ (Floyd's cycle detection stores only two points). This is the key advantage over Baby-step Giant-step.

---

### Question I2
**Explain the relationship between the discrete logarithm problem and integer factorisation in terms of sub-exponential complexity. Why do both belong to the class of problems believed to be hard but not NP-complete?**

**Answer:**

**Complexity of factorisation and DLP:**

Both integer factorisation and DLP in $\mathbb{Z}_p^*$ are solved by the General/Special Number Field Sieve in sub-exponential time:

$$
L_N\left[\frac{1}{3}, c\right] = \exp\left((c + o(1))(\ln N)^{1/3}(\ln \ln N)^{2/3}\right)
$$

This is faster than exponential $(\exp(\ln N)) = N)$ but slower than polynomial $(\text{poly}(\log N))$.

**Why not NP-complete:** NP-complete problems are believed to require exponential time in the worst case. Factorisation has a sub-exponential algorithm — meaning it is (likely) strictly easier than NP-complete problems. Factorisation is in **NP** (a factor is easily verified) and in **co-NP** (primality is in co-NP; proved to be in P by AKS). If factorisation were NP-complete, then NP = co-NP, which would have sweeping consequences believed to be false.

**Practical implication:** The sub-exponential nature of these attacks means classical-computer security requires rapidly growing key sizes. ECC avoids this by using groups (elliptic curves) where no sub-exponential DLP algorithm is known — only $O(\sqrt{n})$ generic attacks (Pollard's rho). This is why ECC achieves higher security per bit than RSA.

**Quantum computers:** Shor's algorithm solves both factorisation and DLP in polynomial time $O((\log N)^3)$ on a quantum computer, reducing both to the "easy" category. This motivates the NIST post-quantum standardisation effort.

---

### Question I3
**Describe the Quadratic Sieve (QS) factorisation algorithm at a high level. What is its complexity, and how does it compare to GNFS?**

**Answer:**

The **Quadratic Sieve** (Pomerance, 1981) is the second-fastest general factorisation algorithm (after GNFS) and the fastest for numbers under ~100 digits (~330 bits).

**Core idea:** Find two integers $x$ and $y$ with $x \not\equiv \pm y \pmod n$ but $x^2 \equiv y^2 \pmod n$. Then $n \mid (x-y)(x+y)$, so $\gcd(x-y, n)$ is likely a non-trivial factor.

**How to find such pairs:**

1. Choose a **factor base** $\mathcal{F} = \{p_1, p_2, \ldots, p_t\}$ of the first $t$ primes.
2. For integers $a$ near $\sqrt{n}$, compute $r_a = (a + \lfloor\sqrt{n}\rfloor)^2 \bmod n$.
3. **Sieve:** For each prime $p \in \mathcal{F}$, mark all $a$ where $p \mid r_a$ (the values of $a$ are periodic modulo $p$). After sieving, each $r_a$ divisible only by primes in $\mathcal{F}$ is **$\mathcal{F}$-smooth** — fully factored over $\mathcal{F}$.
4. Collect $t + 1$ smooth values. Use Gaussian elimination over $\mathbb{F}_2$ (on the exponent vectors modulo 2) to find a subset whose product is a perfect square: $\prod r_{a_i} = y^2$.
5. Set $x = \prod (a_i + \lfloor\sqrt{n}\rfloor) \bmod n$ and extract $\gcd(x \pm y, n)$.

**Complexity:**

$$
L_n\left[\frac{1}{2}, 1\right] = \exp\left((1+o(1))\sqrt{\ln n \cdot \ln \ln n}\right)
$$

**Comparison to GNFS:**

| Algorithm | Complexity class | Practical limit |
|---|---|---|
| Trial division | $O(n^{1/2})$ | ~12 digits |
| Pollard's rho | $O(n^{1/4})$ | ~20 digits |
| Pollard's $p-1$ | $O(B \log B)$ | N/A (conditional) |
| Quadratic Sieve | $L_n[1/2, 1]$ | ~100 digits |
| GNFS | $L_n[1/3, c]$ | 250+ digits (current record) |

GNFS grows asymptotically slower than QS. For $n$ with more than ~100 decimal digits, GNFS is faster. For cryptographic RSA keys (1024+ bits), GNFS is always used.

---

## Tier 3 — Advanced

### Question A1
**Describe the factorisation step of Shor's quantum algorithm. What circuit components are required, and what is the realistic timeline for breaking RSA-2048?**

**Answer:**

**Shor's algorithm** (1994) factors $n$ in polynomial time on a quantum computer.

**Reduction to order-finding:** Factorisation of $n$ reduces to finding the **order** of a random element $a \in \mathbb{Z}_n^*$: the smallest positive integer $r$ such that $a^r \equiv 1 \pmod n$. If $r$ is even and $a^{r/2} \not\equiv -1 \pmod n$, then $\gcd(a^{r/2} - 1, n)$ is a non-trivial factor with probability $\geq 1/2$.

**Quantum circuit for order-finding:**

1. **Quantum Fourier Transform (QFT)** on $O(\log n)$ qubits. The QFT maps the period of a function to its frequency, exposing the order $r$.

2. **Phase estimation circuit:**
   - First register: $m = 2\lceil\log n\rceil + O(1)$ qubits in uniform superposition.
   - Second register: $\lceil \log n \rceil$ qubits in $|1\rangle$.
   - Apply controlled-$U^{2^j}$ operations where $U|x\rangle = |ax \bmod n\rangle$.
   - Apply inverse QFT to first register.
   - Measure first register to obtain an approximation of $k/r$ for random integer $k$.

3. **Continued fraction expansion** extracts $r$ from the measurement result.

**Circuit requirements for RSA-2048:**

| Requirement | Estimate |
|---|---|
| Logical qubits | ~4,000 logical qubits |
| Physical qubits (error-corrected) | ~4 million (with surface codes at realistic error rates) |
| Circuit depth | ~$10^{10}$ Toffoli gates |
| Runtime | ~8 hours on a hypothetical fault-tolerant quantum computer |

**Realistic timeline (2025 assessment):** Current quantum computers have hundreds to thousands of **noisy** physical qubits. Fault-tolerant operation (essential for Shor's algorithm) requires physical error rates below the fault-tolerance threshold ($\sim 10^{-3}$) and likely millions of physical qubits. Conservative expert estimates place cryptographically relevant quantum computers 10–20 years away, though uncertainty is high. NIST's post-quantum standards (ML-KEM, ML-DSA, SLH-DSA) are designed to be deployed before such machines exist.

---

### Question A2
**The AKS primality test proved PRIMES is in P. Describe the mathematical core of the test and explain why it is not used in practice despite this theoretical importance.**

**Answer:**

**AKS test (Agrawal-Kayal-Saxena, 2002):** The key theorem is:

$n$ is prime if and only if for an appropriate integer $r$ and all $a$ with $\gcd(a, n) = 1$:

$$
(X + a)^n \equiv X^n + a \pmod{X^r - 1, n}
$$

This is a polynomial identity over $\mathbb{Z}_n[X]/(X^r - 1)$.

**Derivation:** By the binomial theorem, $(X + a)^n = X^n + a^n + \sum_{k=1}^{n-1} \binom{n}{k} a^{n-k} X^k$. For prime $n$, all middle binomial coefficients are divisible by $n$, and $a^n \equiv a \pmod n$ (Fermat), so $(X+a)^n \equiv X^n + a \pmod n$. The converse (a composite satisfying this for enough $a$ is prime) is the hard part, proved using properties of the order of $X$ in $\mathbb{Z}_n[X]/(X^r-1)$.

**Algorithm structure:**
1. Check if $n = a^b$ for small $a, b$ (perfect powers are composite or $n=2$).
2. Find the smallest $r$ such that $\text{ord}_r(n) > (\log n)^2$.
3. Check $\gcd(a, n) = 1$ for $a \leq r$ (if any $1 < \gcd < n$, return composite).
4. Verify the polynomial identity for each $a \leq \lfloor\sqrt{\phi(r)}\log n\rfloor$.

**Complexity:** The original paper proved $O((\log n)^{12})$. Subsequent improvements reduced this to $\tilde{O}((\log n)^6)$, and conditional on reasonable conjectures, $\tilde{O}((\log n)^3)$.

**Why not used in practice:**

1. **Constant factors:** Even $O((\log n)^6)$ has large constants. For a 1024-bit number, $(\log n)^6 = 1024^6 \approx 10^{18}$, compared to 40 Miller-Rabin rounds at $O((\log n)^3) \approx 10^9$ — AKS is roughly $10^9$ times slower.

2. **No need for determinism:** Miller-Rabin with 40 rounds has a false-prime probability of $4^{-40} \approx 10^{-24}$ — far below any practical concern. The gain from determinism is theoretical, not operational.

3. **ECPP alternative:** The **Elliptic Curve Primality Proving (ECPP)** algorithm is deterministic, produces a verifiable certificate, and runs in $\tilde{O}((\log n)^4)$ in practice — faster than AKS for large numbers while still providing a proof.

The AKS test's significance is theoretical: it settled the long-open question of whether PRIMES $\in$ P and unifies the theory of primality testing. It does not replace Miller-Rabin in cryptographic key generation.
