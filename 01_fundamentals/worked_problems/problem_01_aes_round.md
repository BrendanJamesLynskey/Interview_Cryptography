# Problem 01: AES Round — One Complete Round with Hex Values

## Problem Statement

Walk through a complete AES-128 round (not the final round) using actual hex values. Starting from the State after the initial AddRoundKey, apply SubBytes, ShiftRows, MixColumns, and AddRoundKey with the Round 1 key.

**Given:**

State after initial AddRoundKey (input to Round 1):

```
19  a0  9a  e9
3d  f4  c6  f8
e3  e2  8d  48
be  2b  2a  08
```

Round 1 subkey:

```
a0  88  23  2a
fa  54  a3  6c
fe  2c  39  76
17  b1  39  05
```

(These are the actual values from FIPS 197 Appendix B.)

---

## Solution

### Step 1: SubBytes

Replace each byte using the AES S-Box. The S-Box value for byte `XY` is found at row `X`, column `Y` of the S-Box table.

**Key S-Box lookups for this state:**

| Input | S-Box output |
|-------|-------------|
| `0x19` | `0xD4` |
| `0xA0` | `0xE0` |
| `0x9A` | `0xB8` |
| `0xE9` | `0x1E` |
| `0x3D` | `0x27` |
| `0xF4` | `0xBF` |
| `0xC6` | `0xB4` |
| `0xF8` | `0x41` |
| `0xE3` | `0x11` |
| `0xE2` | `0x98` |
| `0x8D` | `0x5D` |
| `0x48` | `0x52` |
| `0xBE` | `0xAE` |
| `0x2B` | `0xF1` |
| `0x2A` | `0xE5` |
| `0x08` | `0x30` |

**State after SubBytes:**

```
d4  e0  b8  1e
27  bf  b4  41
11  98  5d  52
ae  f1  e5  30
```

**Verification note:** The S-Box is constructed by first computing the GF(2^8) multiplicative inverse of each byte, then applying an affine transformation. The inverse of `0x00` is `0x00` itself; the constant addition `0x63` is why `0x00` maps to `0x63` (try: `SubBytes(0x00) = 0x63`).

---

### Step 2: ShiftRows

Row 0: no rotation (shift by 0).
Row 1: rotate left by 1 byte.
Row 2: rotate left by 2 bytes.
Row 3: rotate left by 3 bytes.

**Before ShiftRows (column-major layout, same data as above):**

```
Row 0:  d4  e0  b8  1e
Row 1:  27  bf  b4  41
Row 2:  11  98  5d  52
Row 3:  ae  f1  e5  30
```

**After ShiftRows:**

```
Row 0:  d4  e0  b8  1e        (unchanged)
Row 1:  bf  b4  41  27        (27 moved from front to back)
Row 2:  5d  52  11  98        (first two moved to back)
Row 3:  30  ae  f1  e5        (last element moved to front)
```

**Why this matters:** Before MixColumns operates column-by-column, ShiftRows ensures that each output column of MixColumns draws input bytes from four different columns of the pre-ShiftRows state. Without this, each column would evolve independently and never mix with other columns.

---

### Step 3: MixColumns

MixColumns treats each column as a 4-element vector over GF(2^8) and multiplies by the MDS matrix:

$$
M = \begin{pmatrix} \texttt{02} & \texttt{03} & \texttt{01} & \texttt{01} \\ \texttt{01} & \texttt{02} & \texttt{03} & \texttt{01} \\ \texttt{01} & \texttt{01} & \texttt{02} & \texttt{03} \\ \texttt{03} & \texttt{01} & \texttt{01} & \texttt{02} \end{pmatrix}
$$

All multiplications are in GF(2^8) with AES polynomial `0x11B`. Key operations:
- Multiply by `0x02`: xtime (left shift + conditional XOR with `0x1B`).
- Multiply by `0x03`: xtime XOR original value.
- Multiply by `0x01`: identity (no change).

**Working through Column 0:** State column 0 after ShiftRows = `[d4, bf, 5d, 30]`.

```
s'_0 = (02 × d4) ⊕ (03 × bf) ⊕ (01 × 5d) ⊕ (01 × 30)
s'_1 = (01 × d4) ⊕ (02 × bf) ⊕ (03 × 5d) ⊕ (01 × 30)
s'_2 = (01 × d4) ⊕ (01 × bf) ⊕ (02 × 5d) ⊕ (03 × 30)
s'_3 = (03 × d4) ⊕ (01 × bf) ⊕ (01 × 5d) ⊕ (02 × 30)
```

Computing the GF(2^8) products:

```
xtime(0xD4):
  0xD4 = 11010100b, high bit = 1
  → (0xD4 << 1) & 0xFF = 0xA8
  → 0xA8 ⊕ 0x1B = 0xB3
  xtime(0xD4) = 0xB3

02 × d4 = 0xB3
03 × d4 = xtime(0xD4) ⊕ 0xD4 = 0xB3 ⊕ 0xD4 = 0x67

xtime(0xBF):
  0xBF = 10111111b, high bit = 1
  → (0xBF << 1) & 0xFF = 0x7E
  → 0x7E ⊕ 0x1B = 0x65
  xtime(0xBF) = 0x65

02 × bf = 0x65
03 × bf = 0x65 ⊕ 0xBF = 0xDA

xtime(0x5D):
  0x5D = 01011101b, high bit = 0
  → 0x5D << 1 = 0xBA
  xtime(0x5D) = 0xBA

02 × 5d = 0xBA
03 × 5d = 0xBA ⊕ 0x5D = 0xE7

xtime(0x30):
  0x30 = 00110000b, high bit = 0
  → 0x30 << 1 = 0x60
  xtime(0x30) = 0x60

02 × 30 = 0x60
03 × 30 = 0x60 ⊕ 0x30 = 0x50
```

Now compute the column:

```
s'_0 = (02×d4) ⊕ (03×bf) ⊕ (01×5d) ⊕ (01×30)
     = 0xB3    ⊕  0xDA   ⊕  0x5D   ⊕  0x30
     = 0xB3 ⊕ 0xDA = 0x69
     = 0x69 ⊕ 0x5D = 0x34
     = 0x34 ⊕ 0x30 = 0x04

s'_1 = (01×d4) ⊕ (02×bf) ⊕ (03×5d) ⊕ (01×30)
     = 0xD4    ⊕  0x65   ⊕  0xE7   ⊕  0x30
     = 0xD4 ⊕ 0x65 = 0xB1
     = 0xB1 ⊕ 0xE7 = 0x56
     = 0x56 ⊕ 0x30 = 0x66

s'_2 = (01×d4) ⊕ (01×bf) ⊕ (02×5d) ⊕ (03×30)
     = 0xD4    ⊕  0xBF   ⊕  0xBA   ⊕  0x50
     = 0xD4 ⊕ 0xBF = 0x6B
     = 0x6B ⊕ 0xBA = 0xD1
     = 0xD1 ⊕ 0x50 = 0x81

s'_3 = (03×d4) ⊕ (01×bf) ⊕ (01×5d) ⊕ (02×30)
     = 0x67    ⊕  0xBF   ⊕  0x5D   ⊕  0x60
     = 0x67 ⊕ 0xBF = 0xD8
     = 0xD8 ⊕ 0x5D = 0x85
     = 0x85 ⊕ 0x60 = 0xE5
```

Column 0 after MixColumns: `[04, 66, 81, E5]`.

**Full state after MixColumns** (applying the same computation to all four columns):

```
04  e0  48  28
66  cb  f8  06
81  19  d3  26
e5  9a  7a  4c
```

---

### Step 4: AddRoundKey

XOR each byte of the State with the corresponding byte of the Round 1 subkey.

**State (after MixColumns):**

```
04  e0  48  28
66  cb  f8  06
81  19  d3  26
e5  9a  7a  4c
```

**Round 1 subkey:**

```
a0  88  23  2a
fa  54  a3  6c
fe  2c  39  76
17  b1  39  05
```

**XOR each byte:**

```
04 ⊕ a0 = a4    e0 ⊕ 88 = 68    48 ⊕ 23 = 6b    28 ⊕ 2a = 02
66 ⊕ fa = 9c    cb ⊕ 54 = 9f    f8 ⊕ a3 = 5b    06 ⊕ 6c = 6a
81 ⊕ fe = 7f    19 ⊕ 2c = 35    d3 ⊕ 39 = ea    26 ⊕ 76 = 50
e5 ⊕ 17 = f2    9a ⊕ b1 = 2b    7a ⊕ 39 = 43    4c ⊕ 05 = 49
```

**State after Round 1 (output):**

```
a4  68  6b  02
9c  9f  5b  6a
7f  35  ea  50
f2  2b  43  49
```

---

## Summary

| Step | Operation | Purpose |
|------|-----------|---------|
| SubBytes | S-Box substitution on each byte | Non-linearity; confusion |
| ShiftRows | Cyclic row rotations | Spread bytes across columns for MixColumns |
| MixColumns | GF(2^8) matrix multiply per column | Diffusion within each column; MDS property |
| AddRoundKey | XOR with round subkey | Key mixing; introduces secret |

The final state `a4 68 6b 02 / 9c 9f 5b 6a / 7f 35 ea 50 / f2 2b 43 49` is the input to Round 2. After 10 complete rounds (the last without MixColumns), the AES-128 output is produced.

---

## Python Verification

```python
# AES S-Box (first 32 entries shown; full 256-entry table required)
SBOX = [
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5,
    0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    # ... (full table required for complete implementation)
]

def xtime(a: int) -> int:
    """Multiply by x (0x02) in GF(2^8) with AES polynomial."""
    return ((a << 1) ^ 0x1B) & 0xFF if a & 0x80 else (a << 1) & 0xFF

def mix_column(col: list[int]) -> list[int]:
    """Apply MixColumns to a single 4-byte column."""
    s0, s1, s2, s3 = col
    return [
        xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3,
        s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3,
        s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3),
        (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3),
    ]

# Verify column 0: [0xD4, 0xBF, 0x5D, 0x30] → [0x04, 0x66, 0x81, 0xE5]
result = mix_column([0xD4, 0xBF, 0x5D, 0x30])
print([hex(x) for x in result])  # ['0x4', '0x66', '0x81', '0xe5']
```

---

## Interview Insight

This problem is frequently asked in hardware security and cryptographic engineering interviews. Key points examiners look for:

1. **Knowing which step provides non-linearity** (SubBytes only — through GF(2^8) inversion).
2. **Explaining why MixColumns is omitted in the final round** (to allow the inverse cipher to mirror the forward cipher structure without extra transformations).
3. **Understanding the "wide trail" design**: after 2 complete rounds, every output bit depends on every input bit (full avalanche). This follows from the combination of ShiftRows (inter-column spread) and MixColumns (intra-column MDS property, branch number = 5).
