# Side-Channel Attacks

## Prerequisites
- AES, ECC, and RSA implementation concepts
- Hardware power consumption fundamentals (CMOS switching)
- Statistical concepts: correlation, hypothesis testing
- Basic understanding of oscilloscope measurements

---

## Concept Reference

### What Side-Channel Attacks Are

Classical cryptanalysis attacks the algorithm: given ciphertexts, find the key by
exploiting mathematical weaknesses. Side-channel attacks attack the **implementation**:
instead of attacking the algorithm, they observe physical characteristics of the device
while it runs — power consumption, electromagnetic emission, timing, or temperature.

A side-channel provides information that leaks from the computation without being part
of the intended output. Even a mathematically perfect algorithm (like AES) can be
completely broken by a hardware implementation that correlates power consumption with
intermediate key-dependent values.

```
Attack surface:
  Classical:      Algorithm + Ciphertext --> Key
  Side-channel:   Physical observation during computation --> Key
```

---

### CMOS Power Consumption Fundamentals

CMOS logic dissipates power in three ways:

1. **Dynamic power** (dominant): $P_{dynamic} = \alpha \cdot C \cdot V_{DD}^2 \cdot f$
   - $\alpha$ = activity factor (fraction of gates switching per cycle)
   - $C$ = load capacitance
   - Switches when a node transitions 0→1 or 1→0

2. **Short-circuit current:** Brief current during input transition (both PMOS and NMOS
   momentarily conducting).

3. **Leakage current:** Subthreshold and gate-oxide leakage (dominant in deep submicron).

**Key insight for side-channel attacks:**

The **activity factor $\alpha$** depends on the data being processed. If a computation
involves the value `0xAB`, the number of bits that switch as the CPU or hardware loads
and processes `0xAB` depends on both `0xAB` and the previous value. This data-dependent
power consumption is measurable with a current probe or a small shunt resistor in the
supply line.

---

### Simple Power Analysis (SPA)

SPA uses **a single power trace** to directly read secret information.

**How it works:**

The attacker collects one (or a few) power traces during a cryptographic operation
and visually or algorithmically identifies operations in the trace.

**Example — RSA square-and-multiply:**

```
RSA private key operation: m = c^d mod n
Standard binary algorithm:
  result = 1
  for each bit of d from MSB to LSB:
    result = result^2 mod n    (square -- always)
    if bit == 1:
      result = result * c mod n  (multiply -- only for 1-bits)
```

The power profile of a squaring operation differs from a multiply. On a single trace:
```
Power trace (time axis):
  S M S S M S M S ... (S=square, M=multiply)
  
Reading the bit pattern: 1 0 1 1 0 1...
This is the private key d.
```

One trace + visual inspection = full private key.

**SPA on ECC double-and-add:** Identical principle. The absence or presence of a point
addition after each doubling reveals each key bit.

**SPA countermeasure:** Use algorithms where the sequence of operations does not depend
on secret data (Montgomery ladder for ECC, square-and-always-multiply for RSA).

---

### Differential Power Analysis (DPA)

DPA uses **many power traces** and statistical analysis to extract keys when individual
trace inspection is insufficient (e.g., too much noise).

**Kocher et al., 1999 — the original DPA:**

The attack targets a specific intermediate value: the first round key XOR a plaintext
byte in AES.

```
Setup:
  - Collect N power traces T_1, ..., T_N during encryption of N known plaintexts P_1..P_N
  - N is typically 1,000 to 100,000 traces

Attack:
  For each candidate key byte k* (0 to 255):
    For each trace i:
      Compute hypothetical intermediate value: v_i = SubBytes(P_i[0] XOR k*)
      Compute Hamming weight (bit count): h_i = popcount(v_i)  [power prediction]
    
    Correlate h_1,...,h_N with the measured power at a specific time point t:
      rho(k*) = Pearson_correlation(h_1..h_N, T_1[t]..T_N[t])
    
  The correct k* gives the highest correlation rho -- peaks out of noise.
```

**Why it works:**

- The Hamming weight model predicts power: processing a value with more 1-bits consumes
  more power (more transistors switch) than processing a value with fewer 1-bits.
- For the wrong $k^*$: the hypothetical values $v_i$ are statistically independent of
  the actual intermediate values, so $h_i$ and $T_i[t]$ are uncorrelated ($\rho \approx 0$).
- For the correct $k^*$: $v_i$ is the actual intermediate value; $h_i$ is correlated with
  the power at time $t$; $\rho$ rises above the noise floor.

**DPA extracts one key byte at a time.** Attacking all 16 bytes of an AES-128 key
independently requires $16 \times 256 = 4096$ hypotheses but only one pass through
the traces per byte.

---

### Correlation Power Analysis (CPA)

CPA (Brier et al., 2004) improves DPA by using Pearson correlation instead of
difference-of-means, requiring fewer traces (typically 3–10× fewer than DPA).

```
For each key hypothesis k* and time sample t:
  rho(k*, t) = Pearson_correlation({h_i(k*)}_{i=1..N}, {T_i[t]}_{i=1..N})

Plot the 2D correlation landscape: axes are k* (0..255) and t (time).
The correct k* shows a peak at the time sample t* where SubBytes output affects power.
```

**Hamming weight model:**
$$h_i(k^*) = \text{popcount}(\text{SubBytes}(P_i[b] \oplus k^*))$$

**Hamming distance model:** More accurate — predicts power as the number of bit transitions
between consecutive states:
$$h_i(k^*) = \text{popcount}(\text{previous\_state} \oplus \text{new\_state})$$

---

### Electromagnetic Analysis (EMA)

EM attacks are identical in concept to power analysis but use an EM probe positioned
near the chip to capture localised electromagnetic emissions instead of measuring supply
current.

**Advantages of EM over power:**
1. Localised: can target a specific module on the chip (e.g., just the S-box registers),
   reducing noise from other circuitry.
2. Harder to filter: power supply decoupling capacitors suppress high-frequency current
   spikes in power measurements; EM emissions bypass this mitigation.
3. Remote: requires no physical contact with the power supply rails (can attack packaged
   chips or devices behind plastic enclosures).

**Near-field EM probe:** A small loop antenna of diameter 1–5 mm placed close to the
chip captures the magnetic field from current loops in the power grid and signal lines.
Signal processing is the same as DPA/CPA.

---

### Timing Attacks

Timing attacks exploit the fact that the time taken by a computation depends on secret
data. Unlike power analysis, timing attacks can often be mounted **remotely** over a
network.

**Bleichenbacher's PKCS#1 v1.5 timing attack (RSA):**

RSA PKCS#1 v1.5 padding validation takes different amounts of time depending on whether
various padding checks pass. An attacker who can send millions of ciphertexts to an oracle
and measure response times can deduce, one bit at a time, the structure of the plaintext
— eventually decrypting any captured ciphertext.

**AES cache-timing attack (Bernstein 2005, Bonneau 2006):**

Software AES implementations using lookup tables (T-tables) access different memory
addresses depending on key XOR plaintext values. Cache hits are faster than cache misses.
An attacker who can force or observe cache behaviour can recover the key:

```
T-table lookup: t = T[(plaintext[0] XOR key[0])]
                    [key-dependent address]

Cache timing reveals: which cache lines were accessed -> which values appeared in the
                      first-round key XOR plaintext -> key bytes
```

This attack was practical against OpenSSL's AES-128 implementation over a network on a
shared machine (cloud VM on the same physical host).

**Countermeasure:** Use constant-time AES-NI hardware instructions (bypasses T-tables
entirely) or implement AES in bitsliced form (processes 8+ blocks simultaneously with
only XOR, AND, NOT — no table lookups, no data-dependent memory access).

---

### Fault Injection Attacks

Fault injection deliberately disrupts computation to cause errors that leak information.

**Bellcore attack on RSA-CRT:**

RSA with Chinese Remainder Theorem (RSA-CRT) computes signatures modulo $p$ and $q$
separately. A single bit fault in the computation mod $p$ produces a signature:
$$s' \equiv m^d \pmod{q} \text{ (correct)} \quad\text{but}\quad s' \not\equiv m^d \pmod{p} \text{ (wrong)}$$

From one faulty signature $s'$ and the correct message $m$, the attacker can factor $n$:
$$\gcd(s' - m^d \bmod n, n) = p \text{ (with high probability)}$$

Private key recovered from **one fault**.

**Fault injection methods:**
- **Voltage glitch:** Brief drop in supply voltage causes setup-time violation; a flip-flop
  captures the wrong value.
- **Clock glitch:** Brief clock pulse faster than the design's timing budget; same effect.
- **Laser fault injection:** Focused laser beam on die surface ionises a transistor,
  causing a transient bit flip. Requires chip decapsulation.
- **EM fault injection:** Localised EM pulse near the chip induces a fault in specific
  circuitry without requiring direct access.

---

## Tier 1 — Fundamentals

### Question F1
**Explain the fundamental difference between a classical cryptanalytic attack and a
side-channel attack. Why can a theoretically unbreakable algorithm still be broken by
a side-channel attack?**

**Answer:**

A **classical cryptanalytic attack** works only with the algorithm's inputs and outputs
(ciphertexts, plaintexts, signatures). It exploits mathematical weaknesses in the
algorithm's structure. AES has no known classical weaknesses that are computationally
practical.

A **side-channel attack** exploits physical properties of the hardware implementation
during execution — power consumption, timing, electromagnetic emission — that are not
part of the algorithm's specification but arise from how the computation is physically
realised.

**Why a mathematically perfect algorithm can be broken:**

CMOS transistors dissipate power proportional to the number of gate transitions per
clock cycle. The number of transitions depends on the data being processed. If AES
S-box input byte $b = \text{key}[i] \oplus \text{plaintext}[i]$, then the power
consumed during the S-box lookup is correlated with $b$. An attacker who measures
power during many encryptions with known plaintexts can statistically separate the
correct key hypothesis (the one that correlates power with the S-box output model)
from all wrong hypotheses.

The algorithm is mathematically secure; the implementation reveals the key via physics.

---

### Question F2
**Describe a Simple Power Analysis attack on the RSA square-and-multiply exponentiation.
What does the attacker observe, and what information does it reveal?**

**Answer:**

The RSA private key operation computes $c^d \bmod n$ using square-and-multiply:
for each bit of $d$ from MSB to LSB, always square; if the bit is 1, also multiply.

The attacker measures the power supply current while the device performs this computation
and records a power trace over time.

On the trace, point squarings and multiplications produce recognisably different power
signatures: multiplications have a distinct shape from squarings because they involve
different data paths and may take different numbers of clock cycles.

The attacker reads the trace left to right:
- A squaring-only pattern: bit of $d$ was 0.
- A squaring followed immediately by a multiplication: bit of $d$ was 1.

By reading the entire trace, the attacker recovers every bit of the private key $d$
from a single power measurement. No mathematical computation is needed beyond visual
pattern recognition on the trace.

**Why this is devastating:** A single measurement is sufficient. There is no statistical
averaging required. The entire 2048-bit RSA private key can be read directly from one
trace.

---

### Question F3
**What is the Hamming weight power model, and why is it used in DPA?**

**Answer:**

The Hamming weight of a value is the number of 1-bits in its binary representation:
$$\text{HW}(0xAB) = \text{HW}(10101011_2) = 5$$

The Hamming weight power model assumes that the power consumed by a CMOS device
to process a value is proportional to the number of 1-bits in that value. Physically:
when a register stores a value, the capacitances on the bit lines for each 1-bit must
be charged; more 1-bits means more capacitance switched, means more energy dissipated.

In DPA, the model is used to predict the hypothetical power trace for each key guess:

For a key byte candidate $k^*$ and plaintext byte $p$, the hypothetical intermediate
value is $v = \text{SubBytes}(p \oplus k^*)$ and the predicted power is $\text{HW}(v)$.

This prediction is correlated with the measured traces. The correct $k^*$ gives the
highest correlation; all wrong key guesses give near-zero correlation.

**Why it is practical:** The Hamming weight model is approximate — real power also
depends on previous state (Hamming distance model) and parasitic effects — but the
approximation is accurate enough that DPA works reliably. Higher-accuracy models
(Hamming distance, specific gate-level models) reduce the required trace count further.

---

### Question F4
**What is a fault injection attack? Describe one specific attack that recovers an RSA
private key from a single faulty signature.**

**Answer:**

A fault injection attack deliberately causes a computation error during cryptographic
processing by physically disrupting the hardware — through a voltage glitch, clock glitch,
laser pulse, or EM pulse. The incorrect output, compared to the correct output or the
expected value, reveals information about secret state.

**Bellcore attack on RSA-CRT:**

RSA with CRT computes $s = m^d \bmod n$ using:
$$s_p = m^d \bmod p, \quad s_q = m^d \bmod q, \quad s = \text{CRT}(s_p, s_q)$$

If a fault occurs during the computation of $s_p$, the device produces:
$$s' = \text{CRT}(s'_p, s_q)$$
where $s'_p \neq s_p$.

The faulty signature satisfies:
$$s' \equiv m^d \pmod{q} \quad\text{(correct)}, \qquad s'^e \not\equiv m \pmod{p} \quad\text{(wrong)}$$

From the faulty signature $s'$ and the original message $m$ (or its hash), compute:
$$\gcd(s'^e - m \bmod n, \, n)$$

This GCD yields $p$ or $q$ with high probability, completely factoring the RSA modulus
and exposing the private key.

**Required:** One valid signature (to recover $m$) + one faulty signature = complete key
compromise. No knowledge of the private key or the internal state is needed beyond
these two values.

---

## Tier 2 — Intermediate

### Question I1
**Walk through a CPA attack on AES-128. Given N power traces, describe every step from
data collection to key byte recovery. How many traces are typically needed?**

**Answer:**

**Step 1 — Data collection:**
```
Encrypt N random plaintexts P_1, ..., P_N on the target device.
Record power trace T_i[t] at M time samples for each encryption i.
Typical: N = 5,000 traces, M = 10,000 time samples per trace.
```

**Step 2 — Choose the attack point:**
Target the output of SubBytes in round 1, specifically byte 0:
$$v_i(k^*) = \text{SubBytes}(P_i[0] \oplus k^*)$$

This value depends on the plaintext byte (known) and one key byte (unknown).

**Step 3 — Compute power model for all key candidates:**
```
For each key candidate k* in {0, 1, ..., 255}:
  For each trace i in {1, ..., N}:
    h_i(k*) = popcount(SubBytes(P_i[0] XOR k*))   [Hamming weight]
```

**Step 4 — Compute Pearson correlation:**
```
For each k* and each time sample t:
  numerator = N * sum(h_i * T_i[t]) - sum(h_i) * sum(T_i[t])
  denom_h = sqrt(N * sum(h_i^2) - sum(h_i)^2)
  denom_t = sqrt(N * sum(T_i[t]^2) - sum(T_i[t])^2)
  rho(k*, t) = numerator / (denom_h * denom_t)
```

**Step 5 — Identify the correct key byte:**
```
For each k*:
  rho_max(k*) = max over t of |rho(k*, t)|

The correct key byte k is: argmax_{k*} rho_max(k*)

Typically: correct k shows rho > 0.8; all others show |rho| < 0.1
```

**Step 6 — Repeat for all 16 key bytes independently:**
Attack byte 1 using $P_i[1]$, etc. After 16 independent attacks, the complete
128-bit key is recovered.

**Typical trace counts:**

| Protection level | Traces needed |
|---|---|
| Unprotected AES (ASIC, no noise) | 500–2,000 |
| Software AES on microcontroller (noise) | 2,000–10,000 |
| First-order masked AES (1 random share) | Theoretically infinite for 1st order; 2nd order needs ~100,000 |
| Hardware AES with decoupling and EM shielding | 10,000–1,000,000 |

---

### Question I2
**Why are cache-timing attacks feasible against software AES implementations on
shared systems (e.g., cloud VMs), and what implementation technique eliminates the
vulnerability?**

**Answer:**

**Why cache-timing attacks work:**

Standard software AES uses 8 lookup tables (T-tables), each containing 256 32-bit entries
(1 KB per table). The table index accessed during round 1 is:

$$\text{T}_{0}[P[0] \oplus K[0]], \quad \text{T}_{1}[P[1] \oplus K[1]], \ldots$$

The table index is a function of `key[i] XOR plaintext[i]`. Two encryptions with the
same key but different plaintexts access different T-table entries. If the attacker can
determine which cache lines were accessed (by measuring response time or via a shared
cache side channel on a co-tenant VM), they learn which T-table indices were used — which
reveals $\text{key}[i] \oplus \text{plaintext}[i]$, directly exposing the key byte.

On a shared L3 cache (two VMs on the same physical core), the attacker can use a
PRIME+PROBE attack: fill specific cache sets, trigger the victim's AES, then probe
which sets were evicted. Evicted sets correspond to T-table entries accessed — i.e.,
specific key XOR plaintext values.

This attack was demonstrated to recover AES-128 keys with ~100,000 encryptions over
a network on the same physical host (Bernstein 2005; Osvik, Shamir, Tromer 2006).

**Elimination via AES-NI hardware instructions:**

Intel AES-NI (available on Intel/AMD processors from ~2010) provides native SIMD
instructions that implement AES operations in hardware:

```asm
AESENC xmm0, xmm1     ; one round of AES encryption (SubBytes + ShiftRows + MixColumns)
AESENCLAST xmm0, xmm1 ; final round
AESKEYGENASSIST       ; key schedule step
```

These instructions operate on 128-bit XMM registers and perform the entire AES round
in a fixed number of cycles (3–8 cycles for AESENC). They do not use any T-tables or
any data-dependent memory access. The operation is:
- **Timing-independent:** identical cycle count regardless of data
- **Cache-independent:** no memory access during the operation
- **Side-channel resistant** against software-level cache timing attacks

Any AES implementation using AES-NI is immune to T-table cache timing attacks.

---

## Tier 3 — Advanced

### Question A1
**Design a test setup to perform a CPA attack against a target microcontroller running
AES-128. Specify the measurement setup, the number of traces required, and the
expected attack outcome against an unprotected vs first-order masked implementation.**

**Answer:**

**Measurement setup:**

```
Physical setup:
  Target: ARM Cortex-M4 microcontroller running AES-128 in software
  Power measurement: 10-ohm shunt resistor in series with VCC supply line
  Oscilloscope: 200 MHz, 8-bit resolution, 1 Gs/s sample rate
  Trigger: GPIO pin toggled by firmware at start of AES_Encrypt() call
  Communication: UART to computer for sending plaintexts and receiving ciphertexts
  
Signal conditioning:
  - Low-pass filter at 100 MHz to remove RF noise
  - Differential probe to reject common-mode noise
  - AC coupling to remove DC offset (we care about switching noise, not average current)
```

**Data collection:**

```python
traces = []
plaintexts = []
for i in range(N):
    pt = os.urandom(16)
    plaintexts.append(pt)
    trigger_and_collect()
    trace = oscilloscope.capture(timebase=50us, samples=10000)
    traces.append(trace)
    device.uart.send(pt)
```

**Against unprotected AES (Hamming weight model):**

```
Required traces: N = 1,000 – 5,000

For each key byte position b in 0..15:
  For each key candidate k* in 0..255:
    Compute h_i = HW(SubBytes(pt_i[b] XOR k*)) for all i
    Compute Pearson correlation between {h_i} and {trace_i[t]} for each time t
  
  Identify correct k* as highest max-correlation peak.
  Expected peak correlation: rho ≈ 0.7 – 0.9 for 5,000 traces

Expected outcome: full 16-byte key recovered with high confidence in minutes.
```

**Against first-order boolean-masked AES:**

A first-order masked implementation computes:
$$v_{\text{masked}} = v \oplus r$$
where $r$ is a fresh random byte per operation. The measured power at any single time
is correlated with $v \oplus r$ — statistically independent of $v$ alone.

A first-order CPA (targeting $v$ via Hamming weight) fails: the correlation is zero
because $r$ randomises the intermediate.

A **second-order CPA** is required: it targets the joint distribution of two time
points — one where $v \oplus r$ appears, one where $r$ appears — and combines them:

```
Combined sample: T_i^{(2)}[t1, t2] = T_i[t1] * T_i[t2]  (or centered product)

Correlation of the combined sample with HW(v) reveals the key.

Required traces: N = 100,000 – 1,000,000
Expected peak correlation: rho ≈ 0.3 – 0.5 for 500,000 traces (much weaker signal)
```

**Expected outcomes summary:**

| Implementation | Attack order | Traces needed | Attack feasibility |
|---|---|---|---|
| Unprotected software AES | 1st order CPA | ~5,000 | Practical; ~10 min setup |
| 1st-order masked AES | 2nd order CPA | ~500,000 | Practical on dedicated lab; ~hours |
| 2nd-order masked AES | 3rd order CPA | >50,000,000 | Research-grade; borderline practical |
| Hardware AES with hiding | Combination | Trace-count dependent | Context-dependent |
