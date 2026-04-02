# ECC Hardware

## Prerequisites
- Elliptic curve arithmetic: point addition, point doubling, scalar multiplication
- Projective coordinates (Jacobian, Montgomery)
- Modular arithmetic: Montgomery multiplication, Barrett reduction
- GF(2^m) and GF(p) fields
- Digital design: state machines, datapath/control separation

---

## Concept Reference

### Why ECC Hardware Is Challenging

ECC hardware is significantly more complex than AES hardware for several reasons:

1. **Irregular computation:** Point multiplication involves a sequence of point
   additions and doublings whose pattern depends on the scalar (private key). This
   creates data-dependent timing — a major side-channel vulnerability.

2. **Large field arithmetic:** A P-256 field element is 256 bits. Modular
   multiplication of two 256-bit numbers requires computing a 512-bit product
   and reducing modulo a 256-bit prime — far more complex than 8-bit GF(2^8)
   operations in AES.

3. **Projective coordinate management:** To avoid expensive modular inversions in
   every step, hardware uses projective coordinates that require more multiplications
   per point operation but eliminate divisions.

4. **Constant-time requirement:** Private key operations must execute in constant
   time regardless of the key value, or an adversary can recover the key via timing
   or power analysis.

---

### Scalar Multiplication: The Core Operation

ECC hardware must compute `Q = k * P` where:
- `k` is a scalar (private key), typically 256 bits
- `P` is an elliptic curve point
- `Q` is the result point

This is the **fundamental operation** in:
- ECDH key agreement (compute shared point)
- ECDSA signing (compute nonce point)
- ECDSA verification (multi-scalar multiplication)

For a 256-bit scalar, approximately 256 point doublings and ~128 point additions are
needed on average.

---

### Double-and-Add Algorithm (Vulnerable)

```
# Standard left-to-right binary method
Q = O  (point at infinity)
for i from 255 downto 0:
    Q = 2 * Q           (point doubling, every bit)
    if k[i] == 1:
        Q = Q + P       (point addition, only for 1-bits)
return Q
```

**Why this is insecure for hardware:**

The `if k[i] == 1` branch means point addition is performed only for 1-bits of the
scalar. A power trace shows a distinct signature for doubling-only operations (bit=0)
versus doubling-followed-by-addition (bit=1). This leaks the entire private key bit
by bit — a **Simple Power Analysis (SPA)** attack requiring only a single power trace.

---

### Montgomery Ladder Algorithm

The Montgomery ladder processes every bit with the same sequence of operations,
regardless of bit value:

```
# Left-to-right Montgomery ladder
R0 = O  (point at infinity)
R1 = P
for i from 255 downto 0:
    if k[i] == 0:
        R1 = R0 + R1    (point addition)
        R0 = 2 * R0     (point doubling)
    else:
        R0 = R0 + R1    (point addition)
        R1 = 2 * R1     (point doubling)
return R0
```

**Key property:** Every iteration performs exactly **one addition and one doubling**,
regardless of whether `k[i]` is 0 or 1. An observer sees an identical sequence of
operations for any key value.

**Constant-time hardware implementation using conditional swap:**

```
for each bit k[i] from MSB to LSB:
    b = k[i]

    # Constant-time conditional swap: exchange R0, R1 if b == 1
    mask = 0 - b              # b=0 -> 0x00..0; b=1 -> 0xFF..F (all bits set)
    temp = mask & (R0 XOR R1)
    R0   = R0 XOR temp
    R1   = R1 XOR temp

    # Always execute in fixed order
    R1 = point_add(R0, R1)
    R0 = point_double(R0)

    # Conditional swap back (same mask)
    temp = mask & (R0 XOR R1)
    R0   = R0 XOR temp
    R1   = R1 XOR temp

return R0
```

This eliminates any data-dependent branch. Both paths execute identical hardware
operations; only the routing of data differs, and the routing uses bitwise masks
with no timing dependence on the mask value.

---

### Projective Coordinates

Point addition in affine coordinates requires a modular inversion (computing $z^{-1}$
mod $p$), which is expensive: one inversion takes ~300 multiplication-equivalent
operations using the extended Euclidean algorithm.

**Jacobian projective coordinates** represent a point $(X:Y:Z)$ as the affine point
$(X/Z^2, Y/Z^3)$. Point addition and doubling can be performed with only multiplications
and no inversions. One modular inversion is deferred to the final step.

**Point doubling in Jacobian coordinates** (for $a = -3$, as in P-256):
```
A = 4 * X * Y^2
B = 3 * (X - Z^2) * (X + Z^2)   (exploiting a = -3 for free reduction)
X' = B^2 - 2*A
Y' = B * (A - X') - 8 * Y^4
Z' = 2 * Y * Z
```

Field operations: 4 multiplications, 4 squarings, 6 additions.
Compare to 1 inversion + 2 multiplications in affine. The inversions are eliminated
at the cost of extra multiplications — strongly preferable in hardware.

**Mixed addition** (Jacobian + affine input $Z_2 = 1$):
Reduces the full Jacobian addition count from ~16 to ~11 multiplications by exploiting
$Z_2 = 1$. Used in the Montgomery ladder when the base point $P$ remains in affine form.

---

### Modular Multiplication Hardware

All coordinate arithmetic requires **modular multiplication** mod $p$ (a 256-bit prime).
Naive multiplication produces a 512-bit product that must be reduced mod $p$.

**Montgomery Multiplication:**

Montgomery multiplication computes:
$$\text{MonMul}(a, b) = a \cdot b \cdot R^{-1} \bmod p$$
where $R = 2^{256}$. It replaces the costly division-by-$p$ step with a division by $R$
(a free right-shift), by adding a suitable multiple of $p$ to make the product divisible
by $R$.

```
Algorithm: MonPro(a, b, p)
  t = 0
  for i = 0 to 255:
    if a[i] == 1: t = t + b
    if t[0] == 1: t = t + p    (ensure t is even for the shift)
    t = t >> 1                 (Montgomery reduction step)
  if t >= p: return t - p
  return t
```

In hardware, this is typically implemented as a word-serial systolic array with 32-bit
or 64-bit word-level multipliers (DSP blocks on FPGA):

| Architecture | Latency (cycles at 200 MHz) | Throughput | Area |
|---|---|---|---|
| 1-bit serial | 256 cycles | Low | ~10 GE |
| 32-bit word | ~20 cycles (1 µs) | Medium | ~1,000 GE |
| 64-bit word | ~10 cycles (50 ns) | High | ~4,000 GE |
| 256-bit parallel | ~3 cycles (15 ns) | Very high | ~16,000 GE |

---

### Fixed vs Variable Base Scalar Multiplication

**Variable base:** $P$ and $k$ are both unknown (general case: ECDH).
Must compute the full ladder from scratch per operation.

**Fixed base:** $P$ is a known constant (ECDSA signing with generator $G$).
Pre-compute a table of multiples: $[1 \cdot G, 2 \cdot G, \ldots, 2^{255} \cdot G]$.
At runtime: look up pre-computed multiples using bits of $k$ and accumulate.
Typically 3–4× faster than variable base.

**Window methods:** Process $w$ bits at a time instead of 1.
- 4-bit window: 256/4 = 64 rounds, each requiring a 16-entry table lookup + 1 addition.
- Reduces additions by factor $w$, at cost of $2^w$ pre-computed points.

---

## Tier 1 — Fundamentals

### Question F1
**What is the difference between the double-and-add algorithm and the Montgomery
ladder for scalar multiplication? Why is the double-and-add algorithm insecure
for hardware?**

**Answer:**

**Double-and-add** processes each bit of the scalar with a mandatory point doubling
and a conditional point addition (only when the bit is 1). The conditional addition
creates **data-dependent control flow**: the operations executed depend on the secret
scalar value.

On hardware, this leaks the scalar bit pattern through:
- **Timing:** Addition takes longer than doubling-only; the total time reveals the
  Hamming weight of the scalar.
- **Power:** The power trace shows a larger spike when addition follows doubling
  (bit=1) than when doubling occurs alone (bit=0). One power trace is sufficient to
  read every bit of the key — a Simple Power Analysis (SPA) attack.

**Montgomery ladder** performs exactly **one addition and one doubling** per bit,
regardless of bit value. A constant-time conditional swap before and after the
operations routes data to the appropriate register without any branch. The power
and timing profile is identical for bit=0 and bit=1.

**Common mistake:** Believing the Montgomery ladder is slower because it always performs
two operations. It is slower than the average-case double-and-add (which skips additions
for 0-bits), but the same as the worst-case double-and-add — and crucially, its security
does not depend on the scalar.

---

### Question F2
**Why do ECC hardware implementations use Jacobian projective coordinates instead
of affine coordinates?**

**Answer:**

In affine coordinates, point addition requires computing:
$$\lambda = (y_2 - y_1)(x_2 - x_1)^{-1} \bmod p$$

This requires a **modular inversion** for every point addition. Over a 256-bit prime,
a modular inversion costs approximately 300 modular multiplications using the binary
extended Euclidean algorithm.

In a scalar multiplication with ~500 point operations, affine coordinates would require
~150,000 equivalent multiplications — roughly 300× slower than necessary.

**Jacobian projective coordinates** represent the affine point $(X, Y)$ as the triple
$(X \cdot Z^2 : Y \cdot Z^3 : Z)$ for any nonzero $Z$. Point doubling and addition
in Jacobian form use only multiplications and squarings:

- Point doubling: ~4 multiplications + 4 squarings
- Point addition: ~10–16 multiplications

A single modular inversion is performed at the very end to convert the final result
back to affine coordinates. This one inversion (300 mults equivalent) amortised
over 500 operations has negligible impact compared to performing inversion every step.

---

### Question F3
**What is Montgomery multiplication and why is it used in ECC field arithmetic hardware?**

**Answer:**

Montgomery multiplication computes:
$$\text{MonMul}(a, b) = a \cdot b \cdot R^{-1} \bmod p$$
where $R = 2^k$ (a power of 2 chosen larger than $p$).

**Why it is used:** Standard modular multiplication requires computing $a \cdot b \bmod p$,
which involves dividing the 512-bit product by $p$ to find the remainder. Division by an
arbitrary large prime is expensive in hardware — it requires a complex quotient estimation
step.

Montgomery multiplication replaces the division by $p$ with a division by $R = 2^k$
(a right shift by $k$ bits — a single cycle in hardware). It works by adding a carefully
chosen multiple of $p$ to the product to ensure the result is divisible by $R$, then
shifting right. The key multiplication $p' = -p^{-1} \bmod R$ is a constant computed
once.

In ECC hardware, all field elements are converted to Montgomery form ($a \to aR \bmod p$)
at input. All intermediate multiplications use MonMul, automatically maintaining
Montgomery form throughout. Final conversion back is one additional MonMul. The overhead
of one extra multiplication per scalar multiplication is negligible relative to the
speedup from eliminating costly divisions.

---

### Question F4
**How many field multiplications does one P-256 scalar multiplication require
using the Montgomery ladder with Jacobian coordinates? What determines this count?**

**Answer:**

**Per-iteration cost:**

Each iteration of the Montgomery ladder performs:
- 1 point addition (mixed Jacobian + affine): ~11 field multiplications
- 1 point doubling (Jacobian): ~4 multiplications + 4 squarings ≈ 8 multiplications
  (squarings are cheaper than general multiplications on some hardware)

Total per iteration: ~19 multiplications.

**For 256-bit scalar:**

256 iterations × ~19 multiplications = ~4,864 field multiplications

Plus one final inversion for affine conversion: ~300 multiplications equivalent.

**Total: ~5,164 field multiplications** for a complete P-256 ECDH operation.

**What determines this count:**
1. Scalar bit length (256 for P-256)
2. Coordinate system (Jacobian; mixed add saves ~5 multiplications per addition)
3. Algorithm (Montgomery ladder uses 1 add + 1 double per bit; window methods reduce
   the number of additions by processing multiple bits at once)
4. Optimisations for the specific curve (P-256 has $a = -3$, reducing doubling cost)

---

## Tier 2 — Intermediate

### Question I1
**Trace three iterations of the Montgomery ladder for scalar k = 0b110 (6) and
base point P. Show R0 and R1 after each iteration.**

**Answer:**

k = 6 = binary 110, bits from MSB: k[2]=1, k[1]=1, k[0]=0.

**Initial state:** R0 = O (point at infinity), R1 = P.

**Iteration 1 (bit k[2] = 1):**
```
b = 1. mask = 0xFF...F.
Conditional swap (b=1): exchange R0 ↔ R1
  R0 = P, R1 = O

R1 = point_add(R0, R1) = P + O = P
R0 = point_double(R0) = 2P

Conditional swap back (b=1): exchange R0 ↔ R1
  R0 = P, R1 = 2P
```

After iteration 1: R0 = P = 1P, R1 = 2P.

**Iteration 2 (bit k[1] = 1):**
```
b = 1. Conditional swap (b=1): R0 = 2P, R1 = P

R1 = point_add(R0, R1) = 2P + P = 3P
R0 = point_double(R0) = 4P

Conditional swap back (b=1): R0 = 3P, R1 = 4P
```

After iteration 2: R0 = 3P, R1 = 4P.

**Iteration 3 (bit k[0] = 0):**
```
b = 0. mask = 0x00...0. No swap.
  R0 = 3P, R1 = 4P

R1 = point_add(R0, R1) = 3P + 4P = 7P
R0 = point_double(R0) = 6P

Conditional swap back (b=0): no swap. R0 = 6P, R1 = 7P
```

After iteration 3: R0 = 6P, R1 = 7P. **Result: R0 = 6P = k * P. Correct.**

**Invariant check:** R1 - R0 = 7P - 6P = P throughout. This invariant can be checked
at the end to detect fault injection attacks.

---

### Question I2
**An ECDSA signing engine must produce a signature in under 200 µs at 200 MHz.
The core operation is a fixed-base scalar multiplication (k * G for ephemeral key k,
where G is the known generator point). What architecture achieves this target?**

**Answer:**

**Fixed-base optimisation:**

Since G is constant, pre-compute a table of multiples during device initialisation.
Using a 4-bit window (w=4):
```
Precomputed table:  [1*G, 2*G, 3*G, ..., 15*G]   (for 1st window)
                    [2^4*G, 2*2^4*G, ..., 15*2^4*G]  (for 2nd window)
                    ... (64 windows total for 256-bit scalar)
Table size: 64 × 15 points × 2 × 256 bits = 491,520 bits ≈ 60 KB
```

At runtime:
- Divide k into 64 4-bit windows: $k = w_{63} \| w_{62} \| \ldots \| w_0$
- For each window: look up pre-computed point, add to accumulator.
- Total: 63 point additions + 0 doublings (doublings are absorbed into the table).

**Operations count:**
```
63 point additions × ~11 multiplications = 693 multiplications
```

**Modular multiplier target:**
```
693 multiplications in < 200 µs at 200 MHz
Time budget per multiplication: 200,000 ns / 693 = 289 ns ≈ 58 cycles at 200 MHz

A 32-bit word Montgomery multiplier can complete in ~16–24 cycles.
Target: 16 cycles per multiplication.
```

**Verification:**
```
693 × 16 cycles / (200 × 10^6 Hz) = 11,088 cycles / 200 MHz = 55 µs
```

Well under the 200 µs target, leaving margin for:
- ECDSA modular arithmetic (k^{-1}, r, s computation): ~10 more multiplications
- Control overhead (state machine transitions, data routing)
- Random scalar generation (k)

**Architecture summary:**
- 32-bit Montgomery multiplier: 4 DSP48 blocks (FPGA) or ~600 GE (ASIC)
- Pre-computed point table: 60 KB BRAM (on FPGA) or ROM (on ASIC)
- Control FSM: sequencing point additions and coordinate conversions

---

## Tier 3 — Advanced

### Question A1
**State the Montgomery ladder invariant and explain how it is used to detect fault
injection attacks. What are the limitations of this detection method?**

**Answer:**

**The invariant:**

At any point during the Montgomery ladder computation (after processing bit $k[i]$):
$$R_1 - R_0 = P$$
where $P$ is the original input base point.

**Why it holds:**

Initialisation: $R_0 = O, R_1 = P$. Difference: $P - O = P$.

Each iteration (after the conditional swaps) computes:
$(R_0, R_1) \to (R_0 + R_1, 2R_0)$ or $(2R_1, R_0 + R_1)$.

In either case: $(R_0 + R_1) - 2R_0 = R_1 - R_0$ and $2R_1 - (R_0 + R_1) = R_1 - R_0$.
The difference is preserved. By induction, $R_1 - R_0 = P$ at every step.

**Using it for fault detection:**

After the scalar multiplication completes, compute:
```python
check = R1 - R0    # one point subtraction = point_add(R1, negate(R0))
if check != P:
    # fault detected — discard result, alert, possibly zeroize
    raise SecurityException("Fault detected in scalar multiplication")
```

This adds ~11 field multiplications (one point addition) to the computation.

**Limitations:**

1. **End-of-computation detection only:** A fault injected in the middle of the ladder
   may corrupt $R_0$ while leaving the invariant formally satisfied — if the corruption
   happens to be consistent across both registers. More precisely, if the attacker can
   inject correlated faults into both $R_0$ and $R_1$ simultaneously such that
   $\delta R_1 = \delta R_0$ (same corruption applied to both), the invariant is
   preserved but the result is wrong.

2. **Single-point verification:** The check verifies the relationship between the final
   $R_0$ and $R_1$ but not the correctness of intermediate computations. A sophisticated
   attacker who forces an incorrect computation that coincidentally satisfies the invariant
   at the end can bypass detection.

3. **Information leakage via error signals:** If the security exception is observable
   (timing, power, error output), an attacker can use it as an oracle. The response to
   a detected fault must itself be constant-time and non-informative.

**Stronger alternatives:**

- **Double computation:** Run the entire scalar multiplication twice with different
  randomisations and compare results. Catches any non-coherent fault.
- **Randomised projective coordinates:** At each step, randomise the $Z$ coordinate
  of projective points (multiply $X$ by $\lambda^2$, $Y$ by $\lambda^3$, $Z$ by
  $\lambda$ for random $\lambda$). This does not change the affine point but randomises
  the power profile of the coordinate computation, resisting differential fault analysis.
- **Shamir's trick with a random auxiliary point:** Add a random curve point to the
  computation to prevent targeted fault attacks on specific intermediate values.
