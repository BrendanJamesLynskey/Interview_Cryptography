# Problem 02: Number Theoretic Transform for Lattice Cryptography

## Problem Statement

The Number Theoretic Transform (NTT) is the performance-critical operation in both
ML-KEM (Kyber) and ML-DSA (Dilithium). Polynomial multiplication in
$R_q = \mathbb{Z}_q[X]/(X^n + 1)$ dominates the computational cost of both schemes.

Answer the following:

1. Show how schoolbook polynomial multiplication in $R_q$ works for small examples,
   and derive the cost formula $O(n^2)$.
2. Explain why NTT reduces this to $O(n \log n)$.
3. For Kyber parameters $n = 8$, $q = 17$: verify that the NTT can be applied
   (find a primitive $2n$-th root of unity modulo $q$) and explain why $q = 3329$
   was chosen for real Kyber.
4. Explain the Cooley-Tukey butterfly and why bit-reversal permutation is needed.

---

## Solution

### Part 1 — Schoolbook Polynomial Multiplication in $R_q$

**Setting:** $R_q = \mathbb{Z}_q[X]/(X^n + 1)$. Polynomials have degree at most
$n-1$ with coefficients in $\{0, 1, \ldots, q-1\}$.

**Multiplication rule:** $X^n \equiv -1 \pmod{X^n + 1}$, so $X^{n+k} \equiv -X^k$.

**Example with $n = 4$, $q = 17$:**

Let $f(X) = 1 + 2X + 3X^2 + 4X^3$ and $g(X) = 5 + 6X$.

Step 1 — Standard polynomial product (before reduction):
```
f * g = 1*5 + (1*6 + 2*5)X + (2*6 + 3*5)X^2 + (3*6 + 4*5)X^3 + 4*6*X^4
      = 5 + 16X + 27X^2 + 38X^3 + 24X^4
```

Step 2 — Reduce $X^n = X^4 \equiv -1 \pmod{X^4+1}$:
```
24X^4 → 24 * (-1) = -24 → -24 mod 17 = -7 mod 17 = 10
```

Step 3 — Combine constant terms and reduce mod 17:
```
h(X) = (5 + 10) + 16X + 27X^2 + 38X^3  mod 17
     = 15 + 16X + 10X^2 + 4X^3  mod 17
     = 15 + 16X + 10X^2 + 4X^3
```

**Verification:** Each coefficient of $X^k$ in $h$ is:
$$h_k = \sum_{i+j \equiv k \pmod n} f_i g_j - \sum_{i+j \equiv k+n \pmod n} f_i g_j$$

The minus sign for the second sum comes from $X^n \equiv -1$.

**Schoolbook cost:** For degree-$(n-1)$ polynomials:
- $n^2$ multiplications mod $q$
- $n^2$ additions mod $q$
- For $n = 256$ (Kyber): $256^2 = 65,536$ multiplications per polynomial multiply

For a Kyber-768 matrix-vector product $A \cdot s$ (a $3 \times 3$ matrix times a
$3 \times 1$ vector = 9 polynomial multiplications + 6 additions):
$9 \times 65,536 = 589,824$ multiplications — very expensive.

---

### Part 2 — NTT Reduces Cost to $O(n \log n)$

**Key insight:** Polynomial multiplication is equivalent to convolution. The classical
DFT converts convolution in the time domain into pointwise multiplication in the
frequency domain. The NTT is the DFT over $\mathbb{Z}_q$ instead of $\mathbb{C}$.

**Standard convolution (mod $X^n - 1$):** The DFT-based approach works for circular
convolution (polynomial product mod $X^n - 1$). Kyber uses $X^n + 1$ (negacyclic
convolution), which requires a twisted NTT.

**Negacyclic NTT:** Define the primitive $2n$-th root of unity $\zeta$ such that
$\zeta^{2n} = 1 \pmod{q}$ and $\zeta^n = -1 \pmod{q}$.

The NTT of $f = (f_0, \ldots, f_{n-1})$ using this $\zeta$:
$$\hat{f}_i = \sum_{j=0}^{n-1} f_j \cdot \zeta^{(2i+1)j} \pmod{q}$$

Polynomial multiplication in $R_q$ then becomes:
$$f \cdot g \equiv \text{INTT}(\hat{f} \odot \hat{g}) \pmod{X^n + 1}$$
where $\odot$ is pointwise multiplication.

**Cost of NTT:** The Cooley-Tukey radix-2 FFT algorithm requires $\frac{n}{2} \log_2 n$
butterfly operations. For $n = 256$: $128 \times 8 = 1024$ butterflies per NTT.

Each butterfly: 1 multiplication + 2 additions.

**Total cost of one polynomial multiplication via NTT:**
```
2 forward NTTs + 1 pointwise multiplication + 1 inverse NTT
= 3 NTTs + n multiplications
≈ 3 × 1024 + 256 = 3328 multiplications
```

Compare to schoolbook $65,536$: **NTT is ~20× faster** for $n = 256$.

---

### Part 3 — NTT Existence for Kyber Parameters

**Condition for NTT to exist:** A primitive $2n$-th root of unity must exist in
$\mathbb{Z}_q^*$. By Lagrange's theorem, this requires $2n \mid (q-1)$.

**Toy case: $n = 8$, $q = 17$**

Check: $q - 1 = 16 = 2 \times 8 = 2n$. So $2n \mid (q-1)$. ✓

Find $\zeta$ such that $\zeta^{16} \equiv 1 \pmod{17}$ and $\zeta^8 \equiv -1 \equiv 16 \pmod{17}$:

Test $\zeta = 2$:
```
2^1 = 2
2^2 = 4
2^4 = 16 ≡ -1 mod 17
2^8 = (2^4)^2 = 16^2 = 256 mod 17 = 256 - 15*17 = 1 mod 17
So ord(2) = 8, not 16. We need ord(ζ) = 2n = 16, so ζ = 2 is insufficient.
```

Test $\zeta = 3$:
```
3^1 = 3
3^2 = 9
3^4 = 81 mod 17 = 81 - 4*17 = 81 - 68 = 13
3^8 = 13^2 mod 17 = 169 mod 17 = 169 - 9*17 = 169 - 153 = 16 ≡ -1 mod 17  ✓
3^16 = (3^8)^2 = 16^2 mod 17 = 256 mod 17 = 1  ✓
```

So $\zeta = 3$ is a primitive $2n = 16$-th root of unity modulo 17, satisfying
$\zeta^8 \equiv -1 \pmod{17}$. The NTT for $R_{17}[X]/(X^8 + 1)$ uses $\zeta = 3$.

**Why $q = 3329$ for real Kyber ($n = 256$):**

The condition is $2n = 512 \mid (q-1)$.

Check: $q - 1 = 3328 = 512 \times 6 + 256$. Hmm — $3328 / 512 = 6.5$, which is not
integer. Let us re-verify: $3329 - 1 = 3328$. $3328 = 2^6 \times 52 = 64 \times 52$.

$512 = 2^9$. Does $2^9 \mid 3328$? $3328 / 512 = 6.5$. No.

But $256 = 2^8$ and $3328 / 256 = 13$. So $256 \mid 3328$.

The Kyber NTT actually uses $\zeta$ with order $2n = 512$... but $3328 = 2^8 \times 13$
does not have $512 \mid 3328$. The resolution is that Kyber uses a **length-256 NTT
with a specific butterfly structure** where the NTT works mod $X^{256} + 1$ by
computing 128 separate 2-point NTTs in the final layer, not a full length-512 transform.

Specifically, Kyber's NTT operates on 256-point polynomials by:
- Using $\zeta = 17$ (a primitive 512th root of unity... let us verify):
  $\zeta^{512} = 17^{512} \pmod{3329}$. Since $3329$ is prime and $3328 = 2^8 \times 13$,
  the multiplicative group order is $3328$. For $\text{ord}(\zeta) = 512$ we need
  $512 \mid 3328$. Since $3328 = 512 \times 6.5$ this fails. The actual condition is:
  Kyber uses $\text{ord}(\zeta) = 256$ with $\zeta^{128} \equiv -1 \pmod{3329}$.

The precise statement: $3329 - 1 = 3328$; for the negacyclic NTT of length 256, we
need an element of order $512 = 2 \times 256$ modulo $3329$. Since $512 \nmid 3328$,
the standard negacyclic NTT does not directly apply. Kyber resolves this with a
**Good-Thomas (merged) NTT structure**: the 256-point polynomial is transformed by a
7-layer forward NTT where the final layer handles pairs via 2-point NTTs, and the
modular reductions are adapted accordingly.

The practical reason $q = 3329$ was chosen:
- $q = 13 \times 256 + 1$, so $256 \mid (q-1)$ — necessary for the 256-length NTT
- $q$ is prime — required for the multiplicative group structure
- $q < 2^{12}$ — fits in 12 bits, enabling efficient Montgomery multiplication
  with 32-bit arithmetic ($2q < 2^{13}$, so products of two reduced elements fit in 24 bits)
- $q \approx 3300$ keeps polynomial coefficients manageable for noise analysis

---

### Part 4 — Cooley-Tukey Butterfly and Bit-Reversal

**The butterfly operation (Cooley-Tukey, DIT — Decimation-In-Time):**

The butterfly transforms a 2-element input $(a, b)$ into:
```
a' = a + zeta^k * b   mod q
b' = a - zeta^k * b   mod q
```
where $\zeta^k$ is the twiddle factor for this stage and position.

One butterfly requires 1 field multiplication (by $\zeta^k$) and 2 additions — the
"multiply-add-subtract" structure is why it is called a butterfly (the dataflow
diagram resembles butterfly wings).

**Full NTT for $n = 8$ using Cooley-Tukey:**

Input: $(f_0, f_1, f_2, f_3, f_4, f_5, f_6, f_7)$

Stage 1 (distance 4): butterflies operating on pairs $(f_j, f_{j+4})$ for $j = 0,1,2,3$
Stage 2 (distance 2): butterflies on $(f_j, f_{j+2})$ for $j$ in each half
Stage 3 (distance 1): butterflies on adjacent pairs

After 3 stages: output is in bit-reversed order.

**Why bit-reversal is needed:**

The Cooley-Tukey algorithm recursively splits the input into even and odd indices:
```
Layer 0: f = (f_0, f_1, f_2, f_3, f_4, f_5, f_6, f_7)
Layer 1: even = (f_0, f_2, f_4, f_6), odd = (f_1, f_3, f_5, f_7)
Layer 2: even-even = (f_0, f_4), even-odd = (f_2, f_6), ...
Layer 3: individual elements
```

The final order of the recursively split elements corresponds to reading their indices
in bit-reversed order:

```
Index  Binary  Bit-reversed  Value
0      000     000 = 0       f_0
1      001     100 = 4       f_4
2      010     010 = 2       f_2
3      011     110 = 6       f_6
4      100     001 = 1       f_1
5      101     101 = 5       f_5
6      110     011 = 3       f_3
7      111     111 = 7       f_7
```

The bit-reversal permutation reorders the input data before the butterfly stages so that
the output emerges in natural order, OR reorders the output after the butterfly stages.
One of these two permutations is necessary for the Cooley-Tukey DIT or DIF variants.

**Why hardware cares about bit-reversal:**

In software NTT, the bit-reversal permutation can be computed with a single pass ($O(n)$
operations). In hardware pipelines, the bit-reversal can be implemented as a wire
crossover network (zero latency, zero area), making it essentially free. This is one
reason hardware NTT implementations are particularly efficient.

---

### Summary Table

| Parameter | Schoolbook | NTT-based |
|---|---|---|
| Polynomial mult $n=256$ | $65,536$ mults | $\approx 3,328$ mults |
| Polynomial mult $n=256$ (multiplications only) | $65,536$ | $3 \times 1,024 + 256 = 3,328$ |
| Speedup factor | baseline | $\approx 20 \times$ |
| Kyber-768 matrix-vector multiply | $9 \times 65,536 = 590$K mults | $\approx 30$K mults |

The NTT is fundamental to making ML-KEM and ML-DSA efficient enough for real-world
deployment. Without NTT, Kyber key generation and encapsulation would be 20× slower,
making it impractical for TLS where handshake latency matters.
