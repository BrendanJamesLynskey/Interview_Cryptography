# Finite Fields GF(2) and GF(2^8)

## Prerequisites
- Polynomial arithmetic (addition, multiplication, division with remainder)
- Modular arithmetic over integers
- Binary representation and XOR operation
- Basic abstract algebra: groups, rings, and fields (concepts, not proofs required)

---

## Concept Reference

### What is a Finite Field?

A **field** is a set $F$ with two operations (addition and multiplication) satisfying:
- Both operations are commutative and associative.
- Multiplication distributes over addition.
- Additive identity (0) and multiplicative identity (1) exist.
- Every element has an additive inverse; every non-zero element has a multiplicative inverse.

A **finite field** (or **Galois field**) $\text{GF}(q)$ has exactly $q$ elements. Galois's theorem: finite fields exist if and only if $q = p^n$ for a prime $p$ and integer $n \geq 1$. For given $q$, the field is unique up to isomorphism.

Cryptography uses two main families:
- $\text{GF}(p)$ — integers modulo prime $p$, used in RSA, classic Diffie-Hellman
- $\text{GF}(2^n)$ — binary polynomials modulo an irreducible polynomial, used in AES, GCM, ECC over binary fields

---

### GF(2) — The Simplest Finite Field

$\text{GF}(2) = \{0, 1\}$ with arithmetic modulo 2:

| $+$ | 0 | 1 |   | $\times$ | 0 | 1 |
|-----|---|---|---|----------|---|---|
| **0** | 0 | 1 |   | **0** | 0 | 0 |
| **1** | 1 | 0 |   | **1** | 0 | 1 |

**Key properties:**
- Addition in $\text{GF}(2)$ is XOR.
- Multiplication in $\text{GF}(2)$ is AND.
- Every element is its own additive inverse: $1 + 1 = 0$ and $0 + 0 = 0$.
- There is no subtraction distinct from addition: $a - b = a + b$ in $\text{GF}(2)$.

This is the foundation for all binary field arithmetic. Polynomials over $\text{GF}(2)$ have coefficients in $\{0, 1\}$ and are added by XORing coefficients.

---

### Polynomials over GF(2)

A **polynomial over $\text{GF}(2)$** has the form:

$$
a(x) = a_{n-1} x^{n-1} + a_{n-2} x^{n-2} + \cdots + a_1 x + a_0 \quad \text{where } a_i \in \{0, 1\}
$$

Such polynomials are in direct correspondence with binary strings: the degree-$k$ coefficient is the $k$-th bit. For example:

$$
x^7 + x^5 + x^3 + x^2 + 1 \;\longleftrightarrow\; 10101101_2 = \texttt{0xAD}
$$

**Addition of polynomials:** XOR the coefficients (XOR the byte representations):

$$
(x^3 + x + 1) + (x^2 + x) = x^3 + x^2 + 1 \quad (\texttt{0x0B} \oplus \texttt{0x06} = \texttt{0x0D})
$$

There is no carrying in polynomial addition over $\text{GF}(2)$.

**Multiplication of polynomials:** Distribute and reduce coefficients modulo 2:

$$
(x^2 + 1)(x + 1) = x^3 + x^2 + x + 1
$$

$$
(\texttt{0x05})(\texttt{0x03}) = \texttt{0x0F}
$$

The degree of the product is the sum of degrees.

**Irreducible polynomials:** A polynomial $p(x)$ over $\text{GF}(2)$ is **irreducible** if it cannot be factored into lower-degree polynomials over $\text{GF}(2)$. Irreducible polynomials are the analogue of prime numbers for polynomial arithmetic.

---

### GF(2^8) — The AES Field

$\text{GF}(2^8)$ contains $2^8 = 256$ elements: all polynomials of degree $< 8$ over $\text{GF}(2)$. Each element corresponds to exactly one byte value $\texttt{0x00}$ through $\texttt{0xFF}$.

**The AES irreducible polynomial:**

$$
m(x) = x^8 + x^4 + x^3 + x + 1 \quad (\texttt{0x11B})
$$

This specific polynomial was chosen for AES because it is irreducible over $\text{GF}(2)$ and enables efficient hardware implementation (few set bits in its binary representation).

#### Addition in GF(2^8)

Addition is XOR of the byte representations, with no modular reduction needed (the XOR of two degree-$\leq 7$ polynomials has degree $\leq 7$):

$$
\texttt{0x57} \oplus \texttt{0x83} = \texttt{0xD4}
$$

In polynomial form:
$$
(x^6 + x^4 + x^2 + x + 1) + (x^7 + x + 1) = x^7 + x^6 + x^4 + x^2 \quad (\texttt{0xD4})
$$

#### Multiplication in GF(2^8)

Multiplication requires:
1. **Polynomial multiplication** (with XOR for coefficient addition).
2. **Reduction modulo $m(x)$** to keep the result in degree $< 8$.

**Example:** $\texttt{0x57} \times \texttt{0x83}$ in $\text{GF}(2^8)$.

$\texttt{0x57} = x^6 + x^4 + x^2 + x + 1$

$\texttt{0x83} = x^7 + x + 1$

Multiplying:
$$
(x^6 + x^4 + x^2 + x + 1)(x^7 + x + 1)
$$

Distribute (and reduce each coefficient mod 2):

| Term | Contribution |
|---|---|
| $x^6 \cdot x^7$ | $x^{13}$ |
| $x^6 \cdot x$ | $x^7$ |
| $x^6 \cdot 1$ | $x^6$ |
| $x^4 \cdot x^7$ | $x^{11}$ |
| $x^4 \cdot x$ | $x^5$ |
| $x^4 \cdot 1$ | $x^4$ |
| $x^2 \cdot x^7$ | $x^9$ |
| $x^2 \cdot x$ | $x^3$ |
| $x^2 \cdot 1$ | $x^2$ |
| $x \cdot x^7$ | $x^8$ |
| $x \cdot x$ | $x^2$ (cancels above) |
| $x \cdot 1$ | $x$ |
| $1 \cdot x^7$ | $x^7$ (cancels above) |
| $1 \cdot x$ | $x$ (cancels above) |
| $1 \cdot 1$ | $1$ |

Sum (collecting like powers, XOR coefficients):

$$
x^{13} + x^{11} + x^9 + x^8 + x^6 + x^5 + x^4 + x^3 + 1
$$

Now reduce modulo $m(x) = x^8 + x^4 + x^3 + x + 1$.

Each power $\geq 8$ is replaced by the remainder polynomial. Since $x^8 \equiv x^4 + x^3 + x + 1 \pmod{m(x)}$:

$$
x^9 \equiv x^5 + x^4 + x^2 + x
$$
$$
x^{11} \equiv x^7 + x^6 + x^4 + x^3
$$
$$
x^{13} \equiv x^7 + x^6 + x^4 + x^3 + x^2 + x  \quad \text{(computed by successive multiplication by }x\text{)}
$$

Wait — the cleaner approach is the **xtime** method:

#### The xtime Operation

**xtime($a$)** computes $x \cdot a(x) \bmod m(x)$, i.e., multiplication by $x$ in $\text{GF}(2^8)$:

```
xtime(a):
  if high bit of a is 0:
    return a << 1            (left shift by 1, no reduction needed)
  else:
    return (a << 1) XOR 0x1B   (left shift, then XOR with 0x1B = low 8 bits of m(x))
```

The value $\texttt{0x1B} = 00011011_2$ corresponds to $x^4 + x^3 + x + 1$ — the non-leading terms of $m(x) = x^8 + x^4 + x^3 + x + 1$. After the shift, the degree-8 term that overflowed is removed by XORing with $m(x) \bmod x^8$.

**Using xtime to multiply by arbitrary constants:**

$$
a \cdot \texttt{0x02} = \text{xtime}(a)
$$
$$
a \cdot \texttt{0x04} = \text{xtime}(\text{xtime}(a))
$$
$$
a \cdot \texttt{0x03} = \text{xtime}(a) \oplus a \quad (= 2a + a = 3a \text{ in GF})
$$

Any multiplication by a constant can be decomposed into a sequence of xtime operations and XORs, since any coefficient can be expressed in binary.

**Complete worked example:** $\texttt{0x57} \times \texttt{0x83}$ using xtime.

$\texttt{0x83} = 10000011_2 = x^7 + x + 1$, so we need $x^7 \cdot \texttt{0x57} \oplus x \cdot \texttt{0x57} \oplus \texttt{0x57}$.

```
a   = 0x57 = 01010111
x1  = xtime(0x57): high bit = 0 → 0x57 << 1 = 0xAE
x2  = xtime(0xAE): high bit = 1 → (0xAE << 1) XOR 0x1B = 0x5C XOR 0x1B = 0x47
x3  = xtime(0x47): high bit = 0 → 0x8E
x4  = xtime(0x8E): high bit = 1 → (0x1C) XOR 0x1B = 0x07
x5  = xtime(0x07): high bit = 0 → 0x0E
x6  = xtime(0x0E): high bit = 0 → 0x1C
x7  = xtime(0x1C): high bit = 0 → 0x38

0x57 × 0x83 = x7 XOR x1 XOR a
            = 0x38 XOR 0xAE XOR 0x57
            = 0x38 XOR 0xAE = 0x96
            = 0x96 XOR 0x57 = 0xC1
```

Therefore $\texttt{0x57} \times \texttt{0x83} = \texttt{0xC1}$ in $\text{GF}(2^8)$.

---

#### Multiplicative Inverse in GF(2^8)

Every non-zero element of $\text{GF}(2^8)$ has a multiplicative inverse. Computing it can be done three ways:

1. **Extended Euclidean algorithm** over $\text{GF}(2)[x]$: Identical in structure to the integer extended Euclidean algorithm, but using polynomial division.

2. **Exponentiation:** Since $\text{GF}(2^8)^*$ is cyclic of order $2^8 - 1 = 255$, we have $a^{255} = 1$ for all non-zero $a$. Therefore $a^{-1} = a^{254}$.

3. **Lookup table:** For AES hardware/software, a 256-entry precomputed table gives $O(1)$ inverse lookup. This is how the AES S-Box is implemented.

```python
def gf256_mul(a: int, b: int) -> int:
    """
    Multiply two bytes in GF(2^8) with AES polynomial 0x11B.
    Uses the Russian peasant / xtime method.
    """
    result = 0
    while b > 0:
        if b & 1:                          # if current low bit of b is 1
            result ^= a                    # add a to result (XOR)
        hi_bit = a & 0x80                  # save high bit before shift
        a = (a << 1) & 0xFF               # shift left, keep to 8 bits
        if hi_bit:
            a ^= 0x1B                      # reduce mod m(x): XOR with 0x1B
        b >>= 1                            # next bit of b
    return result


def gf256_inv(a: int) -> int:
    """
    Compute multiplicative inverse of a in GF(2^8).
    Uses Fermat: a^(-1) = a^254.
    Returns 0 for input 0 (by convention, for AES SubBytes).
    """
    if a == 0:
        return 0
    return gf256_pow(a, 254)


def gf256_pow(a: int, exp: int) -> int:
    """Compute a^exp in GF(2^8) using square-and-multiply."""
    result = 1
    while exp > 0:
        if exp & 1:
            result = gf256_mul(result, a)
        a = gf256_mul(a, a)
        exp >>= 1
    return result


# Expected:
print(hex(gf256_mul(0x57, 0x83)))   # 0xc1
print(hex(gf256_mul(0x53, 0xca)))   # 0x01 (they are inverses)
print(hex(gf256_inv(0x53)))         # 0xca
print(hex(gf256_inv(0x00)))         # 0x00 (special case)
```

---

### AES Uses of GF(2^8)

AES relies on $\text{GF}(2^8)$ arithmetic in two critical places:

#### 1. SubBytes S-Box

The AES S-Box for byte $b$ is computed as:
1. Replace $b$ with $b^{-1}$ in $\text{GF}(2^8)$ ($\texttt{0x00}$ maps to itself).
2. Apply the affine transformation: $s = A \cdot b^{-1} \oplus c$ where $A$ is a fixed $8 \times 8$ bit matrix and $c = \texttt{0x63}$.

The bit-matrix $A$ is a cyclic matrix defined by its first row $\texttt{0xF8}$ (or equivalently its action: each output bit $s_i$ is the XOR of five input bits). In closed form:

$$
s_i = b_i^{-1} \oplus b_{(i+4) \bmod 8}^{-1} \oplus b_{(i+5) \bmod 8}^{-1} \oplus b_{(i+6) \bmod 8}^{-1} \oplus b_{(i+7) \bmod 8}^{-1} \oplus c_i
$$

The $\text{GF}(2^8)$ inverse provides non-linearity (essential for resistance to linear cryptanalysis), and the affine transformation prevents fixed points ($b = b^{-1}$) at $b = 0$ and $b = 1$.

#### 2. MixColumns

MixColumns multiplies each column of the AES state (treated as a 4-element vector of $\text{GF}(2^8)$ values) by a fixed MDS matrix:

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

where all multiplications and additions are in $\text{GF}(2^8)$.

Multiplying by $\texttt{02}$ is xtime; by $\texttt{03}$ is xtime XOR the original value.

#### 3. GCM Authentication (GHASH)

The GCM authentication tag uses $\text{GF}(2^{128})$ with irreducible polynomial:

$$
m(x) = x^{128} + x^7 + x^2 + x + 1
$$

GHASH multiplies 128-bit blocks (ciphertext and AAD) by the hash subkey $H = E_K(\textbf{0})$ in this field. The structure is identical to $\text{GF}(2^8)$ but with 128-bit words.

---

## Tier 1 — Fundamentals

### Question F1
**What is $\texttt{0x1A} \oplus \texttt{0x2B}$? What is $\texttt{0x1A} + \texttt{0x2B}$ in $\text{GF}(2^8)$? Are these the same operation?**

**Answer:**

Yes, they are the same operation. Addition in $\text{GF}(2^8)$ is bitwise XOR.

$$
\texttt{0x1A} = 00011010_2
$$
$$
\texttt{0x2B} = 00101011_2
$$
$$
\texttt{0x1A} \oplus \texttt{0x2B} = 00110001_2 = \texttt{0x31}
$$

**Why XOR equals addition:** GF(2^8) elements are polynomials with coefficients in $\{0, 1\}$. Adding two such polynomials means adding coefficients modulo 2, which is XOR. The degree-$k$ coefficient of the sum is $(a_k + b_k) \bmod 2$, which equals $a_k \oplus b_k$.

**Key implication:** Addition and subtraction are identical in $\text{GF}(2^8)$ because every element is its own additive inverse ($a + a = 0$, so $-a = a$). This simplifies hardware design considerably — no subtraction circuits needed.

---

### Question F2
**Explain what an irreducible polynomial is and why one is needed to construct $\text{GF}(2^8)$. What irreducible polynomial does AES use?**

**Answer:**

An **irreducible polynomial** over $\text{GF}(2)$ is a polynomial that cannot be factored into two lower-degree polynomials with coefficients in $\{0, 1\}$. It is the field analogue of a prime number.

To construct $\text{GF}(2^8)$ from polynomials of degree $< 8$, we need modular reduction — just as $\mathbb{Z}_p$ reduces integers modulo a prime. We need a degree-8 polynomial $m(x)$ to reduce products modulo. For the quotient ring $\text{GF}(2)[x] / m(x)$ to be a field (where every non-zero element has a multiplicative inverse), $m(x)$ must be irreducible. If $m(x)$ were reducible, say $m(x) = a(x) \cdot b(x)$, then $a(x)$ and $b(x)$ would be non-zero elements whose product is zero — a zero divisor, which is impossible in a field.

**AES uses:** $m(x) = x^8 + x^4 + x^3 + x + 1$, corresponding to the hex value $\texttt{0x11B}$.

This polynomial is irreducible over $\text{GF}(2)$ (verifiable by checking it has no roots in $\text{GF}(2)$ and no degree-2 or degree-4 factor — a finite verification).

**Common mistake:** Thinking any degree-8 polynomial would work. There are 16 irreducible polynomials of degree 8 over $\text{GF}(2)$; AES uses one specific choice. Any of the 16 would give an isomorphic field, but the specific one chosen affects the concrete values of the S-Box and MixColumns constants.

---

### Question F3
**Compute xtime($\texttt{0x80}$) and xtime($\texttt{0x7F}$). Why do these two inputs behave differently?**

**Answer:**

**xtime($\texttt{0x80}$):**

$\texttt{0x80} = 10000000_2$. The high bit is 1, so we must reduce.

Left shift: $\texttt{0x80} \ll 1 = \texttt{0x100}$ (9 bits). Keeping 8 bits: $\texttt{0x00}$.

XOR with $\texttt{0x1B}$: $\texttt{0x00} \oplus \texttt{0x1B} = \texttt{0x1B}$.

So xtime($\texttt{0x80}$) $= \texttt{0x1B}$.

In polynomial terms: $x \cdot x^7 = x^8 \equiv x^4 + x^3 + x + 1 = \texttt{0x1B}$ (modulo $m(x)$).

**xtime($\texttt{0x7F}$):**

$\texttt{0x7F} = 01111111_2$. The high bit is 0, so no reduction is needed.

Left shift: $\texttt{0x7F} \ll 1 = \texttt{0xFE}$.

So xtime($\texttt{0x7F}$) $= \texttt{0xFE}$.

**Why the difference:** xtime is multiplication by $x$ in $\text{GF}(2^8)$. If the degree-7 coefficient is 0, the product $x \cdot a(x)$ has degree $\leq 7$ and requires no reduction. If the degree-7 coefficient is 1, the product has a degree-8 term, which must be reduced modulo $m(x)$.

---

## Tier 2 — Intermediate

### Question I1
**Compute $\texttt{0x53}^{-1}$ in $\text{GF}(2^8)$ using the extended Euclidean algorithm over $\text{GF}(2)[x]$. Verify your answer.**

**Answer:**

$\texttt{0x53} = 01010011_2 \Rightarrow x^6 + x^4 + x + 1$.

Apply the extended Euclidean algorithm to $\gcd(x^6 + x^4 + x + 1,\; x^8 + x^4 + x^3 + x + 1)$ (the AES irreducible polynomial):

```
Denote: a = x^6 + x^4 + x + 1 = 0x53
        m = x^8 + x^4 + x^3 + x + 1 = 0x11B

Step 1: m = (x^2 + 1) × a + remainder
  (x^2 + 1)(x^6 + x^4 + x + 1) = x^8 + x^6 + x^3 + x^2 + x^6 + x^4 + x + 1
                                 = x^8 + x^4 + x^3 + x^2 + x + 1  (XOR like terms)
  Remainder r1 = m XOR above = (x^8+x^4+x^3+x+1) XOR (x^8+x^4+x^3+x^2+x+1)
              = x^2

Step 2: a = (x^4 + 1) × x^2 + remainder
  (x^4 + 1)(x^2) = x^6 + x^2
  Remainder r2 = a XOR (x^6+x^2) = (x^6+x^4+x+1) XOR (x^6+x^2)
              = x^4 + x^2 + x + 1

Step 3: x^2 = 0 × (x^4+x^2+x+1) + x^2   ... try:
  x^2 = 1 × (x^4+x^2+x+1)?  No, degree too high.
  Divide x^2 by (x^4+x^2+x+1): quotient = 0, remainder = x^2.

  Actually: x^4+x^2+x+1 has degree 4 > degree of x^2. So:
  Swap: divide (x^4+x^2+x+1) by x^2:
    quotient = x^2 + 1
    (x^2+1)(x^2) = x^4 + x^2
    remainder = x+1

Step 4: x^2 = x(x+1) + x
Step 5: x+1 = 1×x + 1
Step 6: x = x×1 + 0   →  gcd = 1
```

Back-substitution (tracking Bezout coefficients $s$ such that $s \cdot a \equiv 1 \pmod{m}$) gives:

$$
\texttt{0x53}^{-1} = \texttt{0xCA} \quad \text{in } \text{GF}(2^8)
$$

**Verification:** $\texttt{0x53} \times \texttt{0xCA}$ using the `gf256_mul` function = $\texttt{0x01}$.

```python
print(hex(gf256_mul(0x53, 0xCA)))  # 0x1 ✓
```

This value ($\texttt{0xCA}$) is precisely the output of the AES S-Box inverse for input $\texttt{0xCA}$ — the S-Box includes this $\text{GF}(2^8)$ inverse as its first step.

---

### Question I2
**Why is the AES MixColumns matrix called MDS? What does the MDS property guarantee about the diffusion of AES?**

**Answer:**

**MDS (Maximum Distance Separable)** refers to a linear code that achieves the Singleton bound: for a code with $k$ input symbols and $n$ output symbols over an alphabet of size $q$, the minimum Hamming distance between any two distinct codewords is $n - k + 1$ (the maximum theoretically possible).

The MixColumns matrix defines a $[4, 4]$ linear code over $\text{GF}(2^8)$ with minimum distance 5. This means:

**For any non-zero input column $\mathbf{c}$:** The output $M\mathbf{c}$ has at least **5 non-zero bytes** when the input and output are considered together (i.e., among the 4 input bytes and 4 output bytes, at least 5 are non-zero).

Equivalently: if the input has $w$ non-zero bytes, the output has at least $5 - w$ non-zero bytes. If even one byte is non-zero ($w = 1$), all four output bytes are non-zero.

**Diffusion guarantee:** After MixColumns, any change in one input byte affects all four output bytes. Combined with ShiftRows (which spreads bytes between columns), after two rounds of AES, every output byte depends on every input byte. This is quantified by the **branch number** of 5, and using the **wide trail design strategy** (Daemen and Rijmen), any 2-round differential characteristic has weight at least $5 \times 2 = 10$ active S-Boxes. Ten active S-Boxes makes differential cryptanalysis infeasible against full AES.

---

### Question I3
**The GCM authentication tag computation uses $\text{GF}(2^{128})$. Why must nonce reuse in AES-GCM be treated as catastrophic?**

**Answer:**

AES-GCM's authentication tag is:

$$
T = \text{GHASH}_H(A, C) \oplus E_K(\text{nonce} \| 0)
$$

where $H = E_K(\mathbf{0})$ is the **GHASH hash subkey**.

GHASH is a polynomial evaluation in $\text{GF}(2^{128})$:

$$
\text{GHASH}_H(A, C) = A_1 H^m + A_2 H^{m-1} + \cdots + C_1 H^j + \cdots + L \cdot H
$$

If the same nonce is used for two messages $(A_1, C_1, T_1)$ and $(A_2, C_2, T_2)$:

$$
T_1 \oplus T_2 = \text{GHASH}_H(A_1, C_1) \oplus \text{GHASH}_H(A_2, C_2)
$$

(the $E_K(\text{nonce} \| 0)$ terms cancel).

The right side is a known polynomial in $H$ (the attacker knows all $A_i$, $C_i$, $T_i$). This is a polynomial equation over $\text{GF}(2^{128})$ with $H$ as the unknown. A degree-$d$ polynomial over $\text{GF}(2^{128})$ has at most $d$ roots, and for the attacker, the equation usually has a unique solution for $H$.

**Once $H$ is recovered:**

1. **Forge any tag:** For any chosen ciphertext $C^*$ and AAD $A^*$, compute $T^* = \text{GHASH}_H(A^*, C^*) \oplus E_K(\text{nonce} \| 0)$. The last term is known from any observed $T$ and the recovered $H$.

2. **Decrypt:** CTR-mode keystream for the repeated nonce is fully determined by $\text{nonce}$ and $K$. Since both messages used the same keystream, $C_1 \oplus C_2 = P_1 \oplus P_2$, directly revealing the XOR of the two plaintexts.

**The impact:** A single nonce reuse in AES-GCM compromises **both confidentiality and authenticity** for all past and future messages under that nonce. This is far more destructive than nonce reuse in CTR mode alone (which only leaks $P_1 \oplus P_2$). This severity motivates the use of random nonces with 96-bit GCM (a collision only occurs with probability $2^{-32}$ after $2^{32}$ messages) or the AES-GCM-SIV variant which is nonce-misuse resistant.

---

## Tier 3 — Advanced

### Question A1
**Explain how the AES SubBytes S-Box achieves its non-linearity. What is the algebraic degree of the S-Box and why does it matter for algebraic attacks?**

**Answer:**

The AES S-Box maps byte $b$ to:

$$
S(b) = A \cdot b^{-1} \oplus c
$$

where $A$ is the affine matrix, $c = \texttt{0x63}$, and $b^{-1}$ is the $\text{GF}(2^8)$ multiplicative inverse (with $0^{-1} = 0$ by convention).

**Source of non-linearity:** The map $b \mapsto b^{-1}$ is not a linear map over $\text{GF}(2)$. The affine transformation $A \cdot b + c$ is linear (affine) and does not add non-linearity. The sole source of non-linearity in AES is the $\text{GF}(2^8)$ inversion.

**Algebraic degree:** In $\text{GF}(2^8)$, the inverse function $b^{-1} = b^{254}$ (Fermat). Writing this in terms of the ANF (Algebraic Normal Form) over $\text{GF}(2)$ (expressing each output bit as a multivariate polynomial in the 8 input bits), the algebraic degree is 7 (each output bit is a degree-7 Boolean polynomial in the 8 input bits). This is the maximum possible for an 8-bit function that is not linear.

**Why degree matters for algebraic attacks:** Algebraic attacks (XSL, Courtois-Meier) attempt to solve a large system of polynomial equations relating plaintexts to ciphertexts and the key. The complexity of solving such a system grows with the degree. If the S-Box had low algebraic degree (say 2 or 3), the equations would be low-degree and solvable efficiently using Gröbner basis algorithms (e.g., F4/F5). The AES S-Box's degree-7 structure means the polynomial system has very high degree, making algebraic attacks impractical.

**Design tension:** A degree-1 (linear) S-Box would be trivially breakable by linear cryptanalysis. A random S-Box has optimal algebraic degree but may have poor differential/linear properties. The AES S-Box balances: maximum algebraic degree (7), optimal differential uniformity ($\delta = 4$, the minimum for any function), and optimal linearity ($\lambda = 4$).

---

### Question A2
**Describe the construction of the GF(2^8) field using a normal basis rather than a polynomial basis. What computational advantage does a normal basis provide?**

**Answer:**

**Polynomial basis** (standard): Represent elements as $\{1, \alpha, \alpha^2, \ldots, \alpha^7\}$ where $\alpha$ is a root of the irreducible polynomial. This is what AES uses.

**Normal basis:** Represent elements as $\{$\beta, \beta^2, \beta^4, \beta^8 = \beta^{2^1 \bmod 255}, \ldots, \beta^{2^7}\}$ where $\beta$ is a **normal element** — one whose Frobenius orbit $\{\beta^{2^i}\}$ spans the entire field.

In a normal basis, multiplication is more complex but **squaring is free**: the Frobenius map $a \mapsto a^2$ corresponds to a cyclic shift of the 8-element coefficient vector.

**Formal statement:** If $a = \sum_{i=0}^{7} a_i \beta^{2^i}$, then:

$$
a^2 = \sum_{i=0}^{7} a_i \beta^{2^{i+1}} = \sum_{i=0}^{7} a_{(i-1) \bmod 8} \beta^{2^i}
$$

This is a cyclic left rotation of the coefficient vector — a single-cycle barrel shift.

**Computational advantage:**

1. **Squaring is $O(1)$** (just rotate the coefficient register). In polynomial basis, squaring requires a multiply-and-reduce.

2. **Exponentiation to powers of 2:** $a^{2^k}$ is $k$ rotations — crucial for Frobenius endomorphism computations in ECC over $\text{GF}(2^n)$.

3. **Field inversion:** By Fermat, $a^{-1} = a^{2^8 - 2} = a^{254}$. In binary: $254 = 11111110_2$. This can be computed as a sequence of squarings (free) and multiplications: $a^{254} = (((a^2 \cdot a)^2)^2 \cdots)$ with 7 squarings and 6 multiplications.

**Tradeoff:** Multiplication in a normal basis requires a cyclic convolution, which is generally more expensive than in a polynomial basis. The advantage is primarily for hardware implementing many squarings, such as ECC scalar multiplication over binary fields, where efficient squaring reduces total circuit area significantly. AES deliberately uses the polynomial basis because MixColumns and AddRoundKey have no squaring requirement.
