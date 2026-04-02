# Countermeasures: Masking and Hiding

## Prerequisites
- Side-channel attacks: DPA, SPA, timing attacks (see side_channel_attacks.md)
- AES hardware architecture and S-box implementations
- Boolean algebra: XOR properties, share arithmetic
- Probability and statistics: independence, conditional probability

---

## Concept Reference

### Two Fundamental Strategies

Side-channel countermeasures fall into two categories:

**Hiding (also called: suppression, balancing, noise injection):**
Reduce the signal-to-noise ratio in the side-channel measurement. Make the physical
observable (power, EM, timing) carry less information about secret data.

**Masking (also called: secret sharing, blinding):**
Transform the computation so that no individual intermediate value depends on the
secret alone. Each intermediate is combined with fresh random values so that observing
any one physical measurement reveals nothing about the secret.

Both strategies have formal security proofs and practical limitations. Most production
hardware cryptographic implementations combine both.

---

### Boolean Masking

Boolean masking splits every secret value $v$ into $d+1$ shares such that XOR of all
shares equals $v$:

$$v = s_0 \oplus s_1 \oplus \cdots \oplus s_d$$

The original value is never processed as a single entity; only shares are manipulated.

**First-order Boolean masking ($d = 1$):**

```
v is the secret byte
r is a fresh random byte (generated from a TRNG per operation)

s0 = v XOR r    (masked value)
s1 = r          (mask)

Process s0 through SubBytes using a masked S-box.
Process s1 separately.
Combine: output = masked_output XOR mask_correction
```

**Why standard S-box cannot be used directly:**

The S-box is a nonlinear operation: $\text{SubBytes}(v \oplus r) \neq \text{SubBytes}(v) \oplus r'$
for any fixed $r'$. Applying the standard S-box to the masked value $s_0 = v \oplus r$
produces a result that depends on both $v$ and $r$ in a nonlinear way. The mask $r$
would need to be "processed through" the nonlinearity, which is not straightforward.

**Masked S-box construction:**

For first-order masking, a **random look-up table (RLUT)** approach:
At the start of each encryption, generate a random output mask $r'$ and construct a
masked S-box $S'$ indexed by the masked input:
$$S'[x \oplus r] = S[x] \oplus r' \quad \text{for all } x \in \{0,\ldots,255\}$$

The table $S'$ is computed once per encryption using 256 lookups and XOR operations,
then used for all 16 × 10 = 160 S-box accesses. The output share is $S'[s_0]$; the
mask correction $r'$ is tracked through MixColumns.

**Cost:** One table re-randomisation per encryption (256 XOR operations) + mask
bookkeeping through all linear operations.

**Why it resists first-order DPA:**

At any time sample $t$ in the power trace, the processed value is $s_0 = v \oplus r$
or $r'$. For a random $r$, $s_0$ is uniformly distributed over all byte values
regardless of $v$. The Hamming weight $\text{HW}(s_0)$ is independent of $\text{HW}(v)$
for a uniform $r$. First-order DPA (which correlates hypothetical $\text{HW}(v)$ with
measured power) finds no correlation — the signal is zero.

**Limitation:** Does not resist second-order DPA. The attacker combines power samples
at two time points — one where $s_0 = v \oplus r$ is processed and one where $r$ is
processed — and correlates their product with $\text{HW}(v)$. The joint distribution
of $(s_0, r)$ is correlated with $v$.

**$d$-th order masking:** Splits $v$ into $d+1$ shares. Resists up to order-$d$ DPA.
The cost scales as $O(d^2)$ for nonlinear operations.

---

### Arithmetic Masking

When the secret value is involved in arithmetic operations (additions, multiplications
over integers), Boolean masking is inconvenient because $+$ and $\oplus$ do not commute.

**Arithmetic masking:** Represent $v$ as:
$$v \equiv s_0 + r \pmod{2^n}$$

where $r$ is random and $s_0 = v - r \bmod 2^n$.

Arithmetic masking is natural for modular exponentiation (RSA) and modular multiplication.
For AES (which mixes Boolean XOR in AddRoundKey with arithmetic-like MixColumns over
GF(2^8)), conversion between Boolean and arithmetic masking is needed, adding overhead.

---

### Threshold Implementation (TI)

Threshold Implementation (Nikova, Rechberger, Rijmen, 2006) provides provable first-order
security against power attacks under a stronger model than naive masking.

**Construction for first-order TI:**

Split into $d \geq t \cdot (d+1) / t$ shares (where $t$ is the algebraic degree of the
function), typically 3 shares for first-order security of a degree-2 function (e.g.,
the AND gate in the S-box GF(2^4) inversion).

**Three properties required:**
1. **Correctness:** The combination of output shares equals the correct function value.
2. **Non-completeness:** Each output share depends on at most $d$ input shares (not all
   $d+1$). This ensures that no single share computation accesses the full secret.
3. **Uniformity:** For uniform input shares, the output shares are uniformly distributed.
   Uniformity prevents information leakage through the share distributions.

TI provides **glitch-resistant** first-order security: even if combinational glitches
(transient logic values during gate propagation) create momentary correlation, the TI
construction's non-completeness property prevents them from revealing the secret.

Naive Boolean masking without TI may be broken by glitch-based DPA even when the
register values are properly masked, because glitches temporarily expose unmasked values
in combinational logic.

---

### Hiding: Power Equalisation

**Dual-rail logic:** Implement each logic signal as a complementary pair $(d, d')$ where
$d' = \overline{d}$. Both rails always transition on every clock cycle — regardless of
whether $d$ goes 0→1 or 1→0.

```
Standard logic: wire may or may not switch -> data-dependent power
Dual-rail logic: both complementary wires always switch -> constant power per cycle
```

Two main implementations:
1. **SABL (Sense-Amplifier Based Logic):** Pre-charge both rails to a known state;
   evaluate; both rails transition exactly once per cycle. Used in ASIC designs.
2. **WDDL (Wave Dynamic Differential Logic):** A standard-cell implementation of
   dual-rail logic compatible with automated synthesis tools.

**Limitation:** Manufacturing variations (process spread, temperature gradients) cause
the two rails to have slightly different capacitances. The resulting imbalance means
power consumption is not exactly equal for 0 and 1 values — a residual side channel
remains. Empirically, dual-rail logic reduces the number of required DPA traces by
10–100× but does not eliminate the vulnerability.

---

### Hiding: Noise Injection and Shuffling

**Noise injection:**
Add random dummy operations (NOP cycles, dummy memory accesses) to inject additional
switching noise unrelated to secret data. Increases the trace count needed for DPA.

**Shuffling (random delay insertion):**
Execute the 16 S-box operations in a randomly permuted order. The attacker no longer
knows which time sample corresponds to which byte position, making time-aligned DPA
impossible without first recovering the permutation.

**Implementation:**

```c
// Shuffled AES SubBytes
uint8_t perm[16];
generate_random_permutation(perm);   // generate from TRNG
for (int i = 0; i < 16; i++) {
    state[perm[i]] = sbox[state[perm[i]] ^ roundkey[perm[i]]];
}
```

The permutation destroys temporal alignment between traces. DPA requires consistent
alignment because it correlates power at a fixed time sample with a predicted value.
With shuffling, the same S-box operation occurs at different times in different traces.

**Limitation:** Shuffling adds the permutation as a new secret the attacker can try to
recover via advanced trace alignment techniques (elastic alignment, pattern matching).
Effective against simple DPA; less effective against template attacks.

---

### Constant-Time Programming

For software implementations and hardware state machines, the most effective countermeasure
against timing attacks is eliminating all data-dependent execution paths.

**Rules for constant-time code:**

1. **No data-dependent branches:**
```c
// Vulnerable: branch on secret
if (key[i] == 1) { do_operation(); }

// Constant-time: always execute, conditionally apply
uint32_t mask = -(uint32_t)key[i];  // 0x00000000 or 0xFFFFFFFF
result = (result_if_1 & mask) | (result_if_0 & ~mask);
```

2. **No data-dependent memory indices:**
```c
// Vulnerable: cache timing
v = table[secret_value];

// Constant-time: access all entries, select result
v = 0;
for (int i = 0; i < TABLE_SIZE; i++) {
    uint32_t mask = ct_equal(i, secret_value);  // -1 if equal, 0 otherwise
    v |= table[i] & mask;
}
```

3. **Use constant-time comparison functions:**
```c
// Vulnerable: early exit
if (memcmp(computed_mac, received_mac, 32) == 0) { ... }

// Constant-time:
int ct_memcmp(const uint8_t *a, const uint8_t *b, size_t n) {
    uint8_t diff = 0;
    for (size_t i = 0; i < n; i++) diff |= a[i] ^ b[i];
    return diff;  // 0 = equal, nonzero = different (checked in constant time)
}
```

---

### Security Level Model: Probing Security

The **$t$-probing security model** (Ishai, Sahai, Wagner, 2003) formalises masking
security: an implementation is $t$-probing secure if an adversary who places $t$
probes at arbitrary wire positions in the circuit cannot learn anything about the secret.

**$t$-probing model vs DPA:**

- $t$-probing with $t = 1$ probes corresponds (approximately) to first-order DPA security.
- A $d$-th order Boolean masking scheme is $d$-probing secure if each intermediate depends
  on at most $d$ of the $d+1$ shares.

This gives a formal basis for comparing and evaluating countermeasures, which is required
by FIPS 140-3 and Common Criteria evaluations.

---

## Tier 1 — Fundamentals

### Question F1
**What is the difference between masking and hiding as countermeasures against DPA?
Give one concrete example of each.**

**Answer:**

**Hiding** reduces the physical side-channel signal without changing the mathematical
computation. It works by making the power consumption less dependent on data values,
or by adding noise.

Example of hiding: **Dual-rail logic.** Each signal is represented as a complementary
pair of wires; both wires always switch on every clock cycle. The power per cycle is
approximately constant regardless of whether the data value is 0 or 1 — the side-channel
signal is minimised.

**Masking** transforms the computation so that no individual intermediate value equals
the secret. It works by splitting secrets into random shares and ensuring only shares
(never the recombined secret) appear in intermediate computations.

Example of masking: **Boolean masking of AES.** The key byte $k$ is split into
$s_0 = k \oplus r$ and $s_1 = r$ for a random $r$. SubBytes is applied to the masked
value $s_0$; the mask is tracked through the computation and removed at the output.
A DPA attacker who measures power during $s_0$ processing sees a uniform distribution
(because $r$ is random) — no correlation with the true key $k$.

**Key distinction:** Hiding changes the physical medium (power balance, noise level);
masking changes the mathematical representation of the secret.

---

### Question F2
**Why can the standard AES S-box not be applied directly to a Boolean-masked input?
How is a masked S-box constructed?**

**Answer:**

The standard S-box is a nonlinear function. Boolean masking requires that the output
mask can be derived from the input mask alone: if $s_0 = v \oplus r$ is the masked
input, we need $\text{SubBytes}(v \oplus r) = \text{SubBytes}(v) \oplus r'$ for some
$r'$ derivable from $r$ alone. But because SubBytes is nonlinear, no such $r'$ exists
that depends only on $r$ and not on $v$.

**Masked S-box construction (RLUT approach):**

At the start of each encryption:
1. Generate random output mask $r'$ (fresh random byte).
2. Compute a 256-entry masked table:
   $$S'[i] = S[i \oplus r] \oplus r' \quad \text{for } i = 0, \ldots, 255$$
   where $r$ is the current input mask.
3. Apply $S'$ to the masked input $s_0 = v \oplus r$:
   $$S'[s_0] = S[s_0 \oplus r] \oplus r' = S[v] \oplus r'$$
   The output is masked with $r'$.
4. Track $r'$ through MixColumns (linear: the mask propagates predictably through
   XOR and GF multiplication) and apply at the AddRoundKey step.

**Cost:** One full table rebuild (256 table writes) per encryption block. This is
acceptable for most throughput targets.

---

### Question F3
**What is a constant-time HMAC comparison, and why is an early-exit comparison
insecure in a MAC verification function?**

**Answer:**

**Early-exit comparison** (standard `memcmp`) compares bytes left to right and returns
immediately when a mismatch is found:
```c
if (received_mac[i] != computed_mac[i]) return FAIL;  // exits early on first bad byte
```

An attacker who can query the verification function with different received MACs and
measure the response time can determine how many leading bytes matched:
- If the response is fastest: 0 bytes matched (first byte wrong).
- If the response takes one unit longer: 1 byte matched, second is wrong.
- Repeat to recover all 32 bytes of the expected MAC.

This allows the attacker to forge a valid MAC by recovering it byte by byte, requiring
at most $256 \times 32 = 8,192$ queries — feasible in practice.

**Constant-time comparison:**
```c
int ct_mac_compare(const uint8_t *a, const uint8_t *b, size_t n) {
    uint8_t diff = 0;
    for (size_t i = 0; i < n; i++) {
        diff |= a[i] ^ b[i];   // accumulate differences; no early exit
    }
    return diff == 0;   // 1 = equal, 0 = different
}
```

This always executes exactly $n$ iterations regardless of where the first mismatch
occurs. The response time is identical for `diff = 0` and `diff != 0`.

---

### Question F4
**What is shuffling as a countermeasure against DPA? What type of attack does it
primarily defend against, and what is its limitation?**

**Answer:**

**Shuffling** randomises the order in which AES S-box operations are performed across
the 16 bytes of the state. A random permutation is generated at the start of SubBytes;
S-box operations execute in that random order.

**What it defends against:** Time-aligned DPA. Standard DPA correlates the power at a
specific time sample with a hypothetical intermediate value for a specific byte position.
Shuffling destroys this alignment: the S-box operation for byte 0 may occur at time
$t_1$ in one trace and at time $t_{13}$ in another trace. When traces are averaged,
the signal for any individual byte is spread across 16 time positions — reduced by a
factor of 16 in amplitude.

**Limitation:** An attacker who can de-shuffle the traces (recover the permutation for
each trace) can realign them and perform standard DPA. De-shuffling techniques include:

1. **Trace alignment via pattern matching:** Find the characteristic shape of each
   S-box operation (each byte may have a slightly different power signature if operated
   on with a different key byte). Match patterns across traces to infer the permutation.

2. **Horizontal DPA:** Exploit correlations within a single trace across the 16 S-box
   operations, which are related through the known plaintext and unknown key.

Shuffling is effective against an attacker with limited capabilities but is not a
standalone protection against a determined adversary with sophisticated trace-processing
tools. It is most effective when combined with masking.

---

## Tier 2 — Intermediate

### Question I1
**Describe Threshold Implementation for a single AND gate. How many shares are needed,
and how does the non-completeness property provide glitch resistance?**

**Answer:**

For a Boolean AND gate $z = a \wedge b$, the algebraic degree is 2 (the function is a
degree-2 polynomial over GF(2)).

**Threshold Implementation construction (3 shares, degree 2):**

Split inputs into 3 shares each:
$$a = a_0 \oplus a_1 \oplus a_2, \qquad b = b_0 \oplus b_1 \oplus b_2$$

The AND function is computed as 3 output shares, each depending on only 2 of the 6
input shares (non-completeness):
$$z_0 = (a_1 \wedge b_1) \oplus (a_1 \wedge b_2) \oplus (a_2 \wedge b_1)$$
$$z_1 = (a_0 \wedge b_0) \oplus (a_0 \wedge b_2) \oplus (a_2 \wedge b_0)$$
$$z_2 = (a_0 \wedge b_1) \oplus (a_1 \wedge b_0)$$

Verify: $z_0 \oplus z_1 \oplus z_2 = a \wedge b$ (correctness — can be verified by
expanding and using $a_i = a \oplus$ other shares).

**Non-completeness check:**
- $z_0$ depends on $a_1, a_2, b_1, b_2$ (not $a_0, b_0$) — missing both $a_0$ and $b_0$
- $z_1$ depends on $a_0, a_2, b_0, b_2$ (not $a_1, b_1$) — missing both $a_1$ and $b_1$
- $z_2$ depends on $a_0, a_1, b_0, b_1$ (not $a_2, b_2$) — missing both $a_2$ and $b_2$

No output share depends on all 6 input shares; each output share is missing at least one
share of each input.

**Glitch resistance:**

In standard Boolean masking (1 mask share), even if the registers hold the correct masked
values, the combinational logic computing the S-box may produce transient glitches —
momentary incorrect values — as gate delays cause intermediate nodes to briefly hold
unmasked values. These glitches cause momentary power spikes that correlate with
unmasked data.

TI's non-completeness prevents this: each output share's combinational logic only touches
a strict subset of the input shares (never the full secret). Glitches within the
combinational logic for $z_0$ can only produce values that depend on $\{a_1, a_2, b_1,
b_2\}$ — not the complete secret. Any glitch is therefore masked.

---

### Question I2
**Compare first-order Boolean masking, Threshold Implementation, and dual-rail logic
in terms of: area overhead, resistance order achieved, and glitch resistance.**

**Answer:**

| Property | 1st-order Boolean masking | Threshold Implementation | Dual-rail logic (WDDL/SABL) |
|---|---|---|---|
| Area overhead | 2–3× (one random share per signal + mask bookkeeping) | 3–4× (three shares per signal + register replication) | 2× (complementary signal pair per wire) |
| Resistance order | 1st order (resists single-probe / 1st-order DPA) | 1st order (guaranteed by non-completeness) | Depends on implementation balance |
| Glitch resistance | No — combinational glitches expose unmasked values | Yes — non-completeness prevents glitches from leaking | Partial — depends on physical balance of rails |
| Random number requirements | 1 byte per S-box (or per-block with RLUT) | Same as Boolean masking | None |
| Provable security | $t$-probing model, 1-probe secure | $t$-probing + glitch model | No formal proof; physical measurement dependent |
| Implementation complexity | Moderate | High (resharing needed across shares) | High (custom cell library needed) |

**Practical recommendation:** For ASIC implementations requiring EAL5+ or FIPS 140-3
(Physical Security Level 3), TI with 3 shares is the standard approach because it
provides formal glitch resistance. For FPGA implementations, Boolean masking is more
commonly used (FPGA routing makes dual-rail logic impractical; glitch concerns are
mitigated by registered masking schemes).

---

## Tier 3 — Advanced

### Question A1
**Prove that first-order Boolean masking renders the Hamming weight DPA distinguisher
ineffective (correlation = 0 for wrong and correct key). What additional requirement
on the mask generator is necessary for this proof to hold?**

**Answer:**

**Setting:**

Let $v = K[b] \oplus P[b]$ be the target intermediate (byte $b$ of round-1 AES, before
SubBytes). The masked computation uses:
$$s = v \oplus r = K[b] \oplus P[b] \oplus r$$
where $r \in \{0, \ldots, 255\}$ is a uniform random mask independent of $v$.

**Power model:** The power at the relevant time point is:
$$W = \text{HW}(s) + \eta = \text{HW}(v \oplus r) + \eta$$
where $\eta$ is measurement noise (zero-mean).

**DPA hypothesis:** For key candidate $k^*$, the predicted power is:
$$H(k^*) = \text{HW}(\text{SubBytes}(P[b] \oplus k^*))$$

For the correct key $k^* = K[b]$: $H(K[b]) = \text{HW}(\text{SubBytes}(v))$.

**Correlation with $W$:**

$$\text{Cov}(H(K[b]), W) = \text{Cov}(\text{HW}(\text{SubBytes}(v)), \text{HW}(v \oplus r))$$

Expand $\text{HW}(v \oplus r) = \sum_{i=0}^{7} (v_i \oplus r_i)$ (sum of bit XORs).

Since $r$ is independent of $v$ and uniform over $\{0, 1\}^8$:
$$\mathbb{E}[(v_i \oplus r_i)] = \mathbb{E}[v_i] \cdot \mathbb{E}[\overline{r_i}] +
\mathbb{E}[\overline{v_i}] \cdot \mathbb{E}[r_i] = \frac{1}{2}$$
Regardless of $v_i$.

The joint expectation:
$$\mathbb{E}[\text{HW}(v \oplus r) \cdot \text{HW}(\text{SubBytes}(v))]$$
factors as $\mathbb{E}[\text{HW}(v \oplus r)] \cdot \mathbb{E}[\text{HW}(\text{SubBytes}(v))]$
because $r$ is independent of $v$.

Therefore: $\text{Cov}(H(K[b]), W) = 0$ — the correlation is exactly zero.

**The same holds for wrong key candidates** $k^* \neq K[b]$: the predicted HW is based
on a value independent of the actual intermediate $v$, so the covariance is also zero
(by the standard argument that DPA fails when the hypothesis is independent of the
computation). Both correct and wrong keys give zero correlation.

**Additional requirement — uniform, fresh mask:**

The proof requires:
1. $r$ is **uniformly distributed** over $\{0, 1\}^8$. If the TRNG is biased (e.g.,
   returns 0 with probability 0.6 per bit), the masks are not uniform and the covariance
   is nonzero.
2. $r$ is **independent of $v$** (and of $P, K$). If the TRNG is seeded from a value
   correlated with the plaintext or key, the independence fails.
3. $r$ is **fresh per operation** (or at least per encryption). Reusing the same mask
   across multiple encryptions allows an attacker to construct a second-order attack that
   cancels the mask by averaging.

In hardware, these requirements translate to: use a certified TRNG with tested
statistical quality, refresh the mask from the TRNG at the granularity required by the
security claim, and architecturally prevent the mask generator from being observable
through any shared resource (cache, power rail, register file).
