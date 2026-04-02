# Quiz: Cryptographic Hardware Implementation

15 multiple-choice questions covering AES hardware architectures, S-box implementations,
GF(2^8) arithmetic, side-channel attacks, countermeasures, ECC hardware, and LFSR design.

**Instructions:** Select the single best answer. Answers with explanations at the end.

---

## Questions

**Q1.** A pipelined AES-128 implementation inserts registers between every one of its
10 rounds. What is the latency (in clock cycles) to produce the first encrypted block?

A) 1 cycle
B) 10 cycles
C) 11 cycles
D) 160 cycles

---

**Q2.** An iterative AES-128 hardware core runs at 200 MHz and encrypts one block per
10 cycles (one round per cycle, plus one initial AddRoundKey). What is its throughput?

A) 200 Mbps
B) 3.2 Gbps
C) 320 Mbps
D) 2.56 Gbps

---

**Q3.** In GF(2^8) with the AES reduction polynomial, `xtime(0x57)` equals:

A) 0xAE
B) 0xB7
C) 0x57
D) 0x1B

---

**Q4.** An AES S-box implemented as a 256-entry lookup table (LUT) requires how many
bits of storage?

A) 256 bits
B) 512 bits
C) 1024 bits
D) 2048 bits

---

**Q5.** Simple Power Analysis (SPA) on a square-and-multiply RSA implementation can
recover the private key because:

A) The power consumption leaks the exact value of each bit in the modulus
B) Square operations and multiply operations have distinguishable power traces,
   revealing the key bit sequence
C) The total energy consumed equals the Hamming weight of the private key
D) SPA requires only a single trace and always recovers the key in one attempt for any RSA implementation

---

**Q6.** Differential Power Analysis (DPA) targets which intermediate value in an
AES implementation?

A) The final ciphertext output
B) The XOR of the key with the IV
C) The output of the first SubBytes operation (S-box applied to plaintext XOR key)
D) The output of the last MixColumns operation

---

**Q7.** Boolean masking of a cryptographic implementation protects against first-order
DPA by ensuring that:

A) The masked intermediate value is always zero
B) Each intermediate value is XORed with a random mask, so no individual intermediate
   value is correlated with the unmasked sensitive data
C) The power consumption is constant regardless of input data
D) All operations are performed in constant time on all platforms

---

**Q8.** The Montgomery ladder algorithm for elliptic curve scalar multiplication
provides side-channel resistance primarily because:

A) It uses larger field coordinates that hide the point values
B) It performs the same sequence of field operations regardless of the key bit value,
   eliminating data-dependent branching
C) It randomises the base point before scalar multiplication
D) It uses projective coordinates, which are inherently harder to attack

---

**Q9.** A Threshold Implementation (TI) of a cryptographic function requires a minimum
of how many shares for first-order probing security when the function has algebraic
degree $d$?

A) $d$ shares
B) $d + 1$ shares
C) $2d$ shares
D) $2d + 1$ shares

---

**Q10.** In CMOS logic, the primary source of power consumption that side-channel
attacks exploit is:

A) Leakage current through the gate oxide
B) Short-circuit current during switching transitions
C) Dynamic power from charging and discharging load capacitances proportional
   to the number of 0→1 transitions
D) Static power from always-on bias circuits

---

**Q11.** A Fibonacci LFSR of degree 8 with a maximal-length feedback polynomial
has a period of:

A) 8
B) 128
C) 255
D) 256

---

**Q12.** Which countermeasure directly prevents fault injection attacks on RSA-CRT
implementations?

A) Applying Boolean masking to the modular exponentiation
B) Verifying the computed signature by re-encrypting with the public key before output
C) Using a faster modular reduction algorithm (Barrett reduction)
D) Increasing the RSA key size to 4096 bits

---

**Q13.** Projective (Jacobian) coordinates are used in ECC hardware implementations
primarily to:

A) Reduce the degree of the elliptic curve equation
B) Enable parallelisation of point doubling across multiple multipliers
C) Eliminate modular inversions during point addition and doubling,
   replacing them with field multiplications
D) Increase the order of the curve group

---

**Q14.** An AES combinational S-box implemented using tower field decomposition
(GF(2^4) over GF(2^2) over GF(2)) has a primary advantage over an LUT-based S-box for:

A) Reducing the number of AND gates required
B) Achieving lower latency than a single-cycle LUT
C) Enabling mask refreshing with fewer random bits in a masked implementation
D) Reducing the FPGA block RAM consumption and allowing a smaller protected implementation

---

**Q15.** A cache-timing attack on a table-based AES implementation (such as OpenSSL's
T-table approach) leaks information because:

A) The cache access time is proportional to the Hamming weight of the table index
B) Memory access patterns to the T-tables depend on the key and plaintext, and
   cache hit/miss timing reveals which table entries were accessed
C) The branch predictor mis-predicts more often for low-entropy keys
D) Cache lines are flushed more frequently during encryption than decryption

---

## Answers and Explanations

**Q1. Answer: C — 11 cycles**

A pipelined AES-128 core has 10 rounds, each in one pipeline stage, plus an initial
AddRoundKey stage before round 1 — giving 11 pipeline stages total. The latency for
the first block is 11 clock cycles (one per stage).

After the pipeline is filled, throughput is one block per clock cycle. This is the
key distinction between latency and throughput in pipelined designs.

Answer B (10 cycles) omits the initial AddRoundKey stage. Answer A (1 cycle) would
require a fully unrolled combinational design — technically possible but not "pipelined
with registers between rounds." Answer D (160 cycles) would apply to an iterative core
running 16 cycles per round with 10 rounds.

---

**Q2. Answer: D — 2.56 Gbps**

Throughput = (Block size × Clock frequency) / Cycles per block

```
Block size:       128 bits
Clock frequency:  200 MHz = 200 × 10^6 cycles/second
Cycles per block: 10 (as stated — one round per cycle plus the initial AddRoundKey
                  counted together as 10 total)
```

```
Throughput = (128 bits × 200,000,000 cycles/sec) / 10 cycles
           = 128 × 20,000,000 bits/sec
           = 2,560,000,000 bps
           = 2.56 Gbps
```

Answer C (320 Mbps) would correspond to 128 bits × 200 MHz / 80 cycles — this is the
throughput if the core required 80 cycles per block, e.g., an iterative design spending
8 cycles per round. Answer B (3.2 Gbps) corresponds to 128 bits × 200 MHz / 8 cycles,
which would require each block to complete in 8 cycles — not matching the stated 10.
Answer A (200 Mbps) would require 128 cycles per block.

The key formula to memorise: Throughput (bps) = Block_size_bits × f_MHz × 10^6 / Cycles_per_block.

---

**Q3. Answer: A — 0xAE**

`xtime` multiplies by 0x02 in GF(2^8): left-shift by 1 bit; if bit 7 was set,
XOR with 0x1B (the low 8 bits of the AES reduction polynomial 0x11B).

```
0x57 = 0101 0111 in binary. Bit 7 = 0.
xtime(0x57) = 0x57 << 1 = 0xAE = 1010 1110
No reduction needed because bit 7 of the original was 0.
```

Verify: $0x57 \times 2 = 0xAE$ in GF(2^8). ✓

Answer B (0xB7) is wrong — $0xAE \oplus 0x1B = 0xB5$, not 0xB7.
Answer D (0x1B) is the reduction polynomial byte used only when bit 7 is set; it is
not the result here.

---

**Q4. Answer: D — 2048 bits**

A LUT-based AES S-box maps 8-bit inputs to 8-bit outputs. It has:
- 256 entries (one for each possible 8-bit input value)
- 8 bits per entry

Total: $256 \times 8 = 2048$ bits = 256 bytes of storage.

Answer A (256 bits) confuses the number of entries with total storage.
Answer B (512 bits) is 256 entries × 2 bits — wrong entry width.
Answer C (1024 bits) is 256 entries × 4 bits — also wrong.

In practice, a 256×8 single-port ROM on an FPGA occupies half a block RAM tile
(one BRAM tile is typically 18 Kbits = 2 KiB).

---

**Q5. Answer: B — Square and multiply operations have distinguishable power traces**

In square-and-multiply RSA:
```python
result = 1
for bit in key_bits:           # MSB to LSB
    result = result^2 mod n    # always square
    if bit == 1:
        result = result * base mod n  # conditional multiply
```

A modular squaring and a full modular multiplication have different Hamming weights
of intermediate values and different numbers of operations — they produce distinct
power signatures. An SPA adversary can read each bit of the key from a single power
trace by identifying the "square-only" vs "square-then-multiply" patterns.

Answer A is wrong: SPA does not directly leak the modulus value.
Answer C is wrong: total energy relates to total Hamming weight of all intermediates,
not specifically to the private key bit pattern.
Answer D is wrong: SPA recovery is not guaranteed for all implementations (constant-time
implementations use the Montgomery ladder or always-multiply-and-discard variants).

---

**Q6. Answer: C — The output of the first SubBytes operation**

DPA on AES targets the output of `SubBytes(plaintext XOR key[0..15])` — the first
non-linear operation. This intermediate value is a function of:
- A known quantity (the plaintext)
- A small portion of the unknown key (typically one byte)

An attacker hypothesises each possible byte of the first round key (256 guesses),
computes the predicted Hamming weight of `S[p XOR k]` for each trace, and correlates
this prediction against the measured power traces. The correct key byte produces a
strong correlation; all others produce near-zero correlation.

Answer A is wrong: the final ciphertext is known to the attacker but depends on all
key bytes simultaneously — too many degrees of freedom.
Answer B is wrong: there is no IV in ECB/single-block AES.
Answer D is wrong: MixColumns output depends on all four bytes of the column, making
key isolation harder for a single byte hypothesis.

---

**Q7. Answer: B — Each intermediate value is XORed with a random mask**

Boolean masking works by replacing a sensitive value $x$ with $x' = x \oplus r$
where $r$ is a fresh random mask. Every operation works on the masked value; the
mask is removed only at the output.

First-order DPA works by correlating power with a single intermediate value. With
masking, the intermediate value $x' = x \oplus r$ is independent of $x$ (when
$r$ is uniformly random), so correlation with $x'$ yields nothing. The adversary
would need a second-order attack that targets $(x', r)$ simultaneously.

Answer A is wrong: a zero intermediate value would be trivially detectable.
Answer C describes hiding (equalising power consumption), not masking.
Answer D describes constant-time programming, which is a different (software-focused)
countermeasure.

---

**Q8. Answer: B — Same sequence of field operations regardless of key bit**

The Montgomery ladder maintains two points $(R_0, R_1)$ with invariant $R_1 - R_0 = P$
and processes key bits as:

```
if bit == 0:
    R1 = R0 + R1   # point addition
    R0 = 2*R0      # point doubling
if bit == 1:
    R0 = R0 + R1   # point addition
    R1 = 2*R1      # point doubling
```

In both cases, the operations are: one point addition and one point doubling, in the
same sequence. The operations differ only in which register is assigned which result —
but with conditional swap (cswap) implemented as a constant-time select, there is no
data-dependent branching in the operation sequence. A power trace reveals no information
about whether the key bit was 0 or 1.

Answer A is wrong: Jacobian coordinates do not hide point values — they transform them.
Answer C describes point blinding (a separate countermeasure, not the ladder).
Answer D is partially true but is not the primary SCA protection mechanism.

---

**Q9. Answer: B — $d + 1$ shares**

Threshold Implementation uses $d + 1$ shares for first-order probing security against
functions of algebraic degree $d$:

- AES SubBytes has algebraic degree 7 in GF(2^8) (or degree 4 in the tower field
  decomposition). In practice, TI of AES uses 3 shares ($d = 2$, one AND gate per
  share set), based on decomposing the S-box into quadratic components.

The non-completeness property requires that each output share depends on at most
$n - 1$ of the $n$ input shares (where no single share function depends on all shares).
With $d + 1$ shares, any $d$-th order DPA attacker cannot compute a function involving
all shares simultaneously.

Answer A ($d$ shares) is insufficient for non-completeness.
Answer C ($2d$ shares): used in some higher-order constructions but not the minimum.
Answer D ($2d + 1$ shares): applies to secure computation protocols (Shamir), not TI.

---

**Q10. Answer: C — Dynamic power from charging and discharging load capacitances**

CMOS power model:
$$P_\text{dynamic} = \alpha \cdot C_L \cdot V_{DD}^2 \cdot f$$

where $\alpha$ is the activity factor (fraction of transitions that are 0→1). The
key insight: the power consumed in a clock cycle is proportional to the number of
logic nodes that transition from 0 to 1, which correlates with the Hamming weight
(number of 1s) in the data being processed.

This is the physical basis for the Hamming weight power model used in CPA:
- Processing a byte with many 1-bits causes more capacitance to charge → more power
- Intermediate values are thus leaked through power measurements

Answer A (leakage current): relevant for static power and sub-threshold leakage, but
this is not the primary DPA mechanism.
Answer B (short-circuit current): real but small; not the primary correlation source.
Answer D (static power): constant across inputs; provides no useful correlation for SCA.

---

**Q11. Answer: C — 255**

A maximal-length LFSR of degree $n$ (with an irreducible/primitive feedback polynomial)
has period $2^n - 1$. The all-zeros state is excluded (it is a fixed point).

For $n = 8$: period $= 2^8 - 1 = 255$.

Answer D (256) is $2^8$ — this would require the LFSR to cycle through all states
including the all-zeros state. No linear feedback function can escape the all-zeros
state (it maps to itself: 0 XOR 0 = 0).
Answer B (128) is $2^7$, the period of a degree-7 LFSR.
Answer A (8) is the degree, not the period.

---

**Q12. Answer: B — Verify the signature by re-encrypting with the public key before output**

The Bellcore fault attack on RSA-CRT: if a fault is induced during computation of
$s_p = m^{d_p} \pmod p$ (or $s_q$), the final signature $s = \text{CRT}(s_p, s_q)$
is faulty. Comparing $s^e \pmod n$ against $m$ reveals whether the signature is
correct before it is output. If faulty, the signature is discarded.

This countermeasure is simple and effective: a correct CRT output satisfies
$s^e \equiv m \pmod n$; a faulty output does not, and is caught before leaking.

Answer A (Boolean masking): masking prevents DPA by hiding intermediate values, but
a fault that corrupts $s_p$ would pass through a masked computation undetected —
masking does not protect against fault attacks.
Answer C (Barrett reduction): changes modular reduction algorithm, not the attack surface.
Answer D (larger key): does not affect susceptibility to fault attacks in CRT.

---

**Q13. Answer: C — Eliminate modular inversions during point operations**

In affine coordinates, point addition on $y^2 = x^3 + ax + b$ requires a modular
inversion to compute the slope $\lambda = (y_2 - y_1)(x_2 - x_1)^{-1}$. Modular
inversion (via Extended Euclidean or Fermat's little theorem) is extremely expensive:
approximately 10–30× the cost of a field multiplication.

Projective (Jacobian) coordinates represent a point $(X : Y : Z)$ where
$(x, y) = (X/Z^2, Y/Z^3)$. Point addition and doubling are reformulated to use
only multiplications and additions — inversions are deferred until the final result
is converted back to affine. For a scalar multiplication of $k$ bits, this saves
approximately $k$ inversions (one per doubling/addition step) at the cost of extra
multiplications for the $Z$ coordinate bookkeeping.

Answer A: projective coordinates do not reduce the degree of the curve equation.
Answer B: projective coordinates do not directly enable parallelisation.
Answer D: the group order is a property of the curve parameters, not the coordinate system.

---

**Q14. Answer: D — Reducing FPGA block RAM and enabling a smaller protected implementation**

A LUT-based S-box on an FPGA uses a 256×8 ROM (one BRAM), which is opaque — it cannot
be masked easily because the mask must propagate through the table lookup. A Boolean
masked table-based S-box requires splitting into 256 separate tables (one per mask value),
using 256 BRAMs or large distributed LUT arrays.

A combinational tower field S-box uses only logic gates (AND, XOR). This enables direct
application of Boolean masking at the gate level: each AND gate gets its own masked
version using the TI share approach, and the mask can be refreshed at well-defined
points. The total gate count is higher than a ROM but the masked version requires no
additional BRAM — only more logic fabric, which is more plentiful.

Answer A is wrong: the tower field decomposition uses more AND gates than a simple LUT
(the LUT has zero explicit AND gates; it is a ROM).
Answer B is wrong: a LUT-based S-box has lower latency (one BRAM read = 1 clock) vs a
combinational gate chain (multiple gate delays).
Answer C is wrong: the tower field implementation requires careful mask refreshing and
typically uses more random bits per S-box evaluation in a full TI, not fewer.

---

**Q15. Answer: B — Memory access patterns depend on key and plaintext, revealing cache entries accessed**

T-table AES replaces 4 operations (SubBytes, ShiftRows, MixColumns, AddRoundKey) with
a single 256-entry table lookup per byte per round. The table index is
`plaintext_byte XOR key_byte`. Cache line accesses for these lookups are observable
by:

1. **Flush+Reload**: the attacker flushes the T-table cache lines, then lets AES run,
   then measures which lines were re-loaded (fast = accessed, slow = not accessed).
2. **Prime+Probe**: similar but based on cache eviction.

If the attacker observes that table entry `T[i]` was accessed, they know
`plaintext_byte XOR key_byte = i`, which (with known plaintext) reveals `key_byte`.
This attack works even across process boundaries (e.g., cloud VMs sharing a CPU).

Answer A is wrong: cache access time is binary (hit or miss), not proportional to
Hamming weight.
Answer C is wrong: branch prediction is not the mechanism; T-table AES uses no
key-dependent branches.
Answer D is wrong: flush rate is not the attack vector; access pattern is.
