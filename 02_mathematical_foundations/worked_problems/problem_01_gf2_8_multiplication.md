# Problem 01: GF(2^8) Multiplication — Step by Step

## Problem Statement

Perform the following multiplications in $\text{GF}(2^8)$ with AES irreducible polynomial $m(x) = x^8 + x^4 + x^3 + x + 1$ (hex `0x11B`). Show every intermediate step.

**Part A:** Compute $\texttt{0x53} \times \texttt{0xCA}$. (These are multiplicative inverses — the result should be $\texttt{0x01}$.)

**Part B:** Compute $\texttt{0x57} \times \texttt{0x13}$ using both the polynomial method and the xtime method. Verify the results agree.

**Part C:** Compute the MixColumns output for input column $[0x87, 0x6E, 0x46, 0xA6]$ using the AES MixColumns matrix.

---

## Background

In $\text{GF}(2^8)$:
- Each element is a polynomial of degree $\leq 7$ over $\text{GF}(2)$, corresponding to one byte.
- Addition is XOR (no carry).
- Multiplication is polynomial multiplication followed by reduction modulo $m(x) = x^8 + x^4 + x^3 + x + 1$.
- The **xtime** operation computes $x \cdot a(x) \bmod m(x)$: left-shift the byte by 1, and if the high bit was set, XOR with `0x1B` ($= x^4 + x^3 + x + 1$, the non-leading terms of $m(x)$).

---

## Part A: $\texttt{0x53} \times \texttt{0xCA}$

Convert to polynomials:
$$
\texttt{0x53} = 01010011_2 = x^6 + x^4 + x + 1
$$
$$
\texttt{0xCA} = 11001010_2 = x^7 + x^6 + x^3 + x
$$

**Method: xtime decomposition.**

Decompose the second operand by its binary representation: $\texttt{0xCA} = x^7 + x^6 + x^3 + x$, so we compute $x^7 \cdot \texttt{0x53} \oplus x^6 \cdot \texttt{0x53} \oplus x^3 \cdot \texttt{0x53} \oplus x \cdot \texttt{0x53}$.

Build the xtime table for $\texttt{0x53}$:

```
a   = 0x53 = 01010011b

xtime(0x53):
  high bit of 0x53 = 0 (bit 7 of 01010011 = 0)
  → shift left: 10100110b = 0xA6
  x1 = 0xA6

xtime(0xA6):
  high bit of 0xA6 = 1 (10100110b)
  → shift left: 01001100b = 0x4C
  → XOR 0x1B:  01001100b XOR 00011011b = 01010111b = 0x57
  x2 = 0x57

xtime(0x57):
  high bit of 0x57 = 0 (01010111b)
  → shift left: 10101110b = 0xAE
  x3 = 0xAE

xtime(0xAE):
  high bit of 0xAE = 1 (10101110b)
  → shift left: 01011100b = 0x5C
  → XOR 0x1B:  01011100b XOR 00011011b = 01000111b = 0x47
  x4 = 0x47

xtime(0x47):
  high bit of 0x47 = 0 (01000111b)
  → shift left: 10001110b = 0x8E
  x5 = 0x8E

xtime(0x8E):
  high bit of 0x8E = 1 (10001110b)
  → shift left: 00011100b = 0x1C
  → XOR 0x1B:  00011100b XOR 00011011b = 00000111b = 0x07
  x6 = 0x07

xtime(0x07):
  high bit of 0x07 = 0 (00000111b)
  → shift left: 00001110b = 0x0E
  x7 = 0x0E
```

**Summary table: powers of $x$ times $\texttt{0x53}$**

| Multiplication | xtime chain | Result |
|---|---|---|
| $x^0 \cdot \texttt{0x53}$ | (original) | `0x53` |
| $x^1 \cdot \texttt{0x53}$ | xtime(0x53) | `0xA6` |
| $x^2 \cdot \texttt{0x53}$ | xtime(0xA6) | `0x57` |
| $x^3 \cdot \texttt{0x53}$ | xtime(0x57) | `0xAE` |
| $x^4 \cdot \texttt{0x53}$ | xtime(0xAE) | `0x47` |
| $x^5 \cdot \texttt{0x53}$ | xtime(0x47) | `0x8E` |
| $x^6 \cdot \texttt{0x53}$ | xtime(0x8E) | `0x07` |
| $x^7 \cdot \texttt{0x53}$ | xtime(0x07) | `0x0E` |

Now compute the product. $\texttt{0xCA} = 11001010_2$, so bits 7, 6, 3, 1 are set:

$$
\texttt{0x53} \times \texttt{0xCA} = x^7 \cdot \texttt{0x53} \oplus x^6 \cdot \texttt{0x53} \oplus x^3 \cdot \texttt{0x53} \oplus x^1 \cdot \texttt{0x53}
$$

$$
= \texttt{0x0E} \oplus \texttt{0x07} \oplus \texttt{0xAE} \oplus \texttt{0xA6}
$$

Compute step by step:

```
0x0E  = 00001110b
0x07  = 00000111b
       -----------  XOR
        00001001b  = 0x09

0x09  = 00001001b
0xAE  = 10101110b
       -----------  XOR
        10100111b  = 0xA7

0xA7  = 10100111b
0xA6  = 10100110b
       -----------  XOR
        00000001b  = 0x01
```

$$
\boxed{\texttt{0x53} \times \texttt{0xCA} = \texttt{0x01}}
$$

This confirms that $\texttt{0x53}$ and $\texttt{0xCA}$ are multiplicative inverses in $\text{GF}(2^8)$: their product is the multiplicative identity $\texttt{0x01}$.

---

## Part B: $\texttt{0x57} \times \texttt{0x13}$

### Method 1: Polynomial Multiplication and Reduction

Convert to polynomials:
$$
\texttt{0x57} = 01010111_2 = x^6 + x^4 + x^2 + x + 1
$$
$$
\texttt{0x13} = 00010011_2 = x^4 + x + 1
$$

**Multiply** (distribute):

$$
(x^6 + x^4 + x^2 + x + 1)(x^4 + x + 1)
$$

| Factor 1 | Factor 2 | Product term |
|---|---|---|
| $x^6$ | $x^4$ | $x^{10}$ |
| $x^6$ | $x$ | $x^7$ |
| $x^6$ | $1$ | $x^6$ |
| $x^4$ | $x^4$ | $x^8$ |
| $x^4$ | $x$ | $x^5$ |
| $x^4$ | $1$ | $x^4$ |
| $x^2$ | $x^4$ | $x^6$ (cancels!) |
| $x^2$ | $x$ | $x^3$ |
| $x^2$ | $1$ | $x^2$ |
| $x$ | $x^4$ | $x^5$ (cancels!) |
| $x$ | $x$ | $x^2$ (cancels!) |
| $x$ | $1$ | $x$ |
| $1$ | $x^4$ | $x^4$ (cancels!) |
| $1$ | $x$ | $x$ (cancels!) |
| $1$ | $1$ | $1$ |

Collecting surviving terms (XOR over $\text{GF}(2)$):

$$
x^{10} + x^8 + x^7 + x^3 + 1
$$

(Degree-6 from $x^6 \cdot 1$ and $x^2 \cdot x^4$: $1 \oplus 1 = 0$ — cancels. Degree-5 from $x^4 \cdot x$ and $x \cdot x^4$: also cancels. Degree-4 from $x^4 \cdot 1$ and $1 \cdot x^4$: cancels. Degree-2 from $x^2 \cdot 1$ and $x \cdot x$: cancels. Degree-1 from $x \cdot 1$ and $1 \cdot x$: cancels.)

**Reduce modulo $m(x) = x^8 + x^4 + x^3 + x + 1$:**

We need to eliminate $x^{10}$ and $x^8$. Since $m(x) = 0$ in the quotient ring:

$$
x^8 \equiv x^4 + x^3 + x + 1 \pmod{m(x)}
$$

$$
x^9 = x \cdot x^8 \equiv x^5 + x^4 + x^2 + x
$$

$$
x^{10} = x \cdot x^9 \equiv x^6 + x^5 + x^3 + x^2
$$

Now substitute:

$$
x^{10} + x^8 + x^7 + x^3 + 1
$$
$$
\equiv (x^6 + x^5 + x^3 + x^2) + (x^4 + x^3 + x + 1) + x^7 + x^3 + 1
$$

Collect (XOR all terms):

| Power | Count | Survives? |
|---|---|---|
| $x^7$ | 1 | Yes |
| $x^6$ | 1 | Yes |
| $x^5$ | 1 | Yes |
| $x^4$ | 1 | Yes |
| $x^3$ | 3 | Yes (odd) |
| $x^2$ | 1 | Yes |
| $x^1$ | 1 | Yes |
| $x^0$ | 2 | No (even) |

Result: $x^7 + x^6 + x^5 + x^4 + x^3 + x^2 + x = \texttt{11111110}_2 = \texttt{0xFE}$.

$$
\texttt{0x57} \times \texttt{0x13} = \texttt{0xFE}
$$

---

### Method 2: xtime Decomposition

$\texttt{0x13} = 00010011_2$, so bits 4, 1, 0 are set.

We need: $x^4 \cdot \texttt{0x57} \oplus x^1 \cdot \texttt{0x57} \oplus x^0 \cdot \texttt{0x57}$.

Build xtime table for $\texttt{0x57} = 01010111_2$:

```
x0 = 0x57

xtime(0x57):
  high bit = 0  →  0x57 << 1 = 0xAE
x1 = 0xAE

xtime(0xAE):
  high bit = 1  →  (0xAE << 1) & 0xFF = 0x5C
              →  0x5C XOR 0x1B = 0x47
x2 = 0x47

xtime(0x47):
  high bit = 0  →  0x47 << 1 = 0x8E
x3 = 0x8E

xtime(0x8E):
  high bit = 1  →  (0x8E << 1) & 0xFF = 0x1C
              →  0x1C XOR 0x1B = 0x07
x4 = 0x07
```

Compute:

$$
\texttt{0x57} \times \texttt{0x13} = x^4 \cdot \texttt{0x57} \oplus x^1 \cdot \texttt{0x57} \oplus \texttt{0x57}
= \texttt{0x07} \oplus \texttt{0xAE} \oplus \texttt{0x57}
$$

```
0x07  = 00000111b
0xAE  = 10101110b
       -----------  XOR
        10101001b  = 0xA9

0xA9  = 10101001b
0x57  = 01010111b
       -----------  XOR
        11111110b  = 0xFE
```

$$
\boxed{\texttt{0x57} \times \texttt{0x13} = \texttt{0xFE}}
$$

Both methods agree. $\checkmark$

---

## Part C: MixColumns for Column $[0x87, 0x6E, 0x46, 0xA6]$

MixColumns applies the matrix:

$$
\begin{pmatrix} s'_0 \\ s'_1 \\ s'_2 \\ s'_3 \end{pmatrix}
=
\begin{pmatrix}
02 & 03 & 01 & 01 \\
01 & 02 & 03 & 01 \\
01 & 01 & 02 & 03 \\
03 & 01 & 01 & 02
\end{pmatrix}
\begin{pmatrix} 87 \\ 6E \\ 46 \\ A6 \end{pmatrix}
$$

All arithmetic in $\text{GF}(2^8)$.

**Step 1: Compute xtime for each input byte.**

```
xtime(0x87):
  0x87 = 10000111b, high bit = 1
  → (0x87 << 1) & 0xFF = 0x0E
  → 0x0E XOR 0x1B = 0x15
  xtime(0x87) = 0x15

xtime(0x6E):
  0x6E = 01101110b, high bit = 0
  → 0x6E << 1 = 0xDC
  xtime(0x6E) = 0xDC

xtime(0x46):
  0x46 = 01000110b, high bit = 0
  → 0x46 << 1 = 0x8C
  xtime(0x46) = 0x8C

xtime(0xA6):
  0xA6 = 10100110b, high bit = 1
  → (0xA6 << 1) & 0xFF = 0x4C
  → 0x4C XOR 0x1B = 0x57
  xtime(0xA6) = 0x57
```

**Step 2: Compute $03 \times$ each byte** ($03 \times x = \text{xtime}(x) \oplus x$):

```
03 × 0x87 = 0x15 XOR 0x87 = 0x92
03 × 0x6E = 0xDC XOR 0x6E = 0xB2
03 × 0x46 = 0x8C XOR 0x46 = 0xCA
03 × 0xA6 = 0x57 XOR 0xA6 = 0xF1
```

**Step 3: Compute each output byte.**

$$
s'_0 = (02 \times 0x87) \oplus (03 \times 0x6E) \oplus (01 \times 0x46) \oplus (01 \times 0xA6)
$$
```
s'_0 = 0x15 XOR 0xB2 XOR 0x46 XOR 0xA6

0x15 XOR 0xB2 = 0xA7
0xA7 XOR 0x46 = 0xE1
0xE1 XOR 0xA6 = 0x47
```
$$s'_0 = \texttt{0x47}$$

$$
s'_1 = (01 \times 0x87) \oplus (02 \times 0x6E) \oplus (03 \times 0x46) \oplus (01 \times 0xA6)
$$
```
s'_1 = 0x87 XOR 0xDC XOR 0xCA XOR 0xA6

0x87 XOR 0xDC = 0x5B
0x5B XOR 0xCA = 0x91
0x91 XOR 0xA6 = 0x37
```
$$s'_1 = \texttt{0x37}$$

$$
s'_2 = (01 \times 0x87) \oplus (01 \times 0x6E) \oplus (02 \times 0x46) \oplus (03 \times 0xA6)
$$
```
s'_2 = 0x87 XOR 0x6E XOR 0x8C XOR 0xF1

0x87 XOR 0x6E = 0xE9
0xE9 XOR 0x8C = 0x65
0x65 XOR 0xF1 = 0x94
```
$$s'_2 = \texttt{0x94}$$

$$
s'_3 = (03 \times 0x87) \oplus (01 \times 0x6E) \oplus (01 \times 0x46) \oplus (02 \times 0xA6)
$$
```
s'_3 = 0x92 XOR 0x6E XOR 0x46 XOR 0x57

0x92 XOR 0x6E = 0xFC
0xFC XOR 0x46 = 0xBA
0xBA XOR 0x57 = 0xED
```
$$s'_3 = \texttt{0xED}$$

**Result:**

$$
\text{MixColumns}([0x87, 0x6E, 0x46, 0xA6]) = [0x47, 0x37, 0x94, 0xED]
$$

---

## Python Verification

```python
def xtime(a: int) -> int:
    """Multiply by x in GF(2^8) with AES polynomial."""
    return ((a << 1) ^ 0x1B) & 0xFF if (a & 0x80) else (a << 1) & 0xFF


def gf_mul(a: int, b: int) -> int:
    """
    Multiply two bytes in GF(2^8) using Russian peasant multiplication.
    """
    result = 0
    while b:
        if b & 1:
            result ^= a
        a = xtime(a)
        b >>= 1
    return result


def mix_column(col: list[int]) -> list[int]:
    """Apply AES MixColumns to a 4-byte column."""
    s0, s1, s2, s3 = col
    return [
        gf_mul(2, s0) ^ gf_mul(3, s1) ^ s2        ^ s3,
        s0            ^ gf_mul(2, s1) ^ gf_mul(3, s2) ^ s3,
        s0            ^ s1            ^ gf_mul(2, s2) ^ gf_mul(3, s3),
        gf_mul(3, s0) ^ s1            ^ s2            ^ gf_mul(2, s3),
    ]


# Part A: verify 0x53 × 0xCA = 0x01
print(hex(gf_mul(0x53, 0xCA)))   # 0x1  ✓

# Part B: verify 0x57 × 0x13 = 0xFE
print(hex(gf_mul(0x57, 0x13)))   # 0xfe  ✓

# Part C: verify MixColumns output
col = [0x87, 0x6E, 0x46, 0xA6]
result = mix_column(col)
print([hex(x) for x in result])  # ['0x47', '0x37', '0x94', '0xed']  ✓


# Additional verification: MixColumns is invertible
# InvMixColumns uses the matrix with entries {0e, 0b, 0d, 09}
def inv_mix_column(col: list[int]) -> list[int]:
    s0, s1, s2, s3 = col
    return [
        gf_mul(0x0e, s0) ^ gf_mul(0x0b, s1) ^ gf_mul(0x0d, s2) ^ gf_mul(0x09, s3),
        gf_mul(0x09, s0) ^ gf_mul(0x0e, s1) ^ gf_mul(0x0b, s2) ^ gf_mul(0x0d, s3),
        gf_mul(0x0d, s0) ^ gf_mul(0x09, s1) ^ gf_mul(0x0e, s2) ^ gf_mul(0x0b, s3),
        gf_mul(0x0b, s0) ^ gf_mul(0x0d, s1) ^ gf_mul(0x09, s2) ^ gf_mul(0x0e, s3),
    ]

recovered = inv_mix_column(result)
print([hex(x) for x in recovered])  # ['0x87', '0x6e', '0x46', '0xa6']  ✓
```

---

## Key Observations

1. **GF(2^8) inverse verification:** The result $\texttt{0x53} \times \texttt{0xCA} = \texttt{0x01}$ confirms that these bytes are used in the AES S-Box: SubBytes of $\texttt{0x53}$ begins by computing the inverse $\texttt{0xCA}$, then applies the affine transform to get `0xED` (the actual S-Box output).

2. **xtime efficiency:** The xtime method reduces any GF(2^8) multiplication to a sequence of shifts, conditional XORs, and final XOR accumulations. Hardware implementations carry out all eight xtime steps in parallel and select outputs based on the second operand's bits.

3. **MixColumns diffusion:** Note that one non-zero input byte would affect all four output bytes (the MDS property with branch number 5). The column $[0x87, 0x6E, 0x46, 0xA6]$ has all four bytes non-zero, and all four output bytes $[0x47, 0x37, 0x94, 0xED]$ are also non-zero and completely different from the inputs — demonstrating the mixing property.
