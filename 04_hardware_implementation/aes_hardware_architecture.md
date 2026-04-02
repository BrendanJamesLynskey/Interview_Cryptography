# AES Hardware Architecture

## Prerequisites
- AES round transformations: SubBytes, ShiftRows, MixColumns, AddRoundKey
- GF(2^8) arithmetic: multiplication, inversion
- Digital design: combinational logic, pipeline registers, LUTs
- FPGA and ASIC implementation concepts

---

## Concept Reference

### The Implementation Trade-Off Space

AES hardware implementations must balance four competing constraints:

```
Throughput  <-------->  Latency   <-------->  Area   <-------->  Power
(Gbps)                  (cycles)              (gates/LUTs)        (mW)
```

No single design dominates all four. The application dictates the primary objective:

| Application | Primary objective | Typical architecture |
|---|---|---|
| High-speed network encryption | Maximum throughput | Fully unrolled pipeline |
| Embedded IoT / smart card | Minimum area | Iterative (1 S-box) |
| Disk encryption (AES-XTS) | Low latency, reasonable throughput | 4-stage pipeline |
| Side-channel protected device | Constant time, masked | Iterative with masking |

---

### Iterative Architecture

The simplest AES hardware reuses one round circuit for all 10 (or 12 or 14) rounds.

```
         +-----------+
         |           |
Input -->| Round     |--> State register --> Output (after 10/12/14 cycles)
         | Circuit   |^
         |           ||
         +-----------+|
              ^       |
              |       |
         Round key    |
         (from key    |
          schedule)   |
                      | feed-back
```

**Characteristics:**
- Area: minimum — one copy of the round datapath
- Latency: 10 cycles for AES-128, 12 for AES-192, 14 for AES-256
- Throughput: one block per 10 cycles; for 128-bit blocks at 100 MHz: 1.28 Gbps

**When to use:** Area-constrained designs (RFID, smart cards, microcontrollers).

---

### Fully Pipelined Architecture

Each of the 10 rounds is implemented as a separate combinational stage with a pipeline
register between each stage.

```
Stage 1        Stage 2        Stage 3               Stage 10
+---------+   +---------+   +---------+    ...    +---------+
| Round 1 |-->| Round 2 |-->| Round 3 |           | Round10 |--> Output
+---------+   +---------+   +---------+           +---------+
     ^              ^              ^                    ^
    RK[1]          RK[2]          RK[3]              RK[10]
```

**Characteristics:**
- Area: 10x the iterative design (10 round circuits + 9 pipeline registers)
- Latency: 10 cycles (same as iterative — but now a new block can enter every cycle)
- Throughput: one block per clock cycle; at 500 MHz: 64 Gbps for a 128-bit block
- Pipeline fill: first block takes 10 cycles; then 1 block output per cycle at full throughput

**When to use:** High-bandwidth applications (10 GbE/100 GbE network line cards, bulk
encryption, crypto accelerators).

**Critical path:** Must fit one full round's combinational logic within one clock period.
A single round includes SubBytes (16 S-box lookups), ShiftRows, MixColumns, and
AddRoundKey. On ASIC 65 nm, this typically allows 300–500 MHz clock rates.

---

### Partially Pipelined (Sub-Pipelined) Architecture

A compromise: pipeline each round into multiple stages (e.g., pipeline SubBytes
separately from MixColumns), allowing a higher clock rate while using less area than
full unrolling.

```
Round 1                    Round 2
+----------+  +----------+ +----------+  +----------+
| SubBytes |->| MixCols  | | SubBytes |->| MixCols  | ...
| ShiftRows|  | AddRK    | | ShiftRows|  | AddRK    |
+----------+  +----------+ +----------+  +----------+
     reg           reg          reg           reg
```

**Characteristics:**
- Area: 2x–5x iterative
- Can achieve higher clock frequency (shorter critical path per stage)
- Throughput: one block every 2 sub-stages if 2 stages per round, etc.

---

### The S-Box: Combinational vs LUT Implementation

The SubBytes operation is the most expensive component of AES hardware. Each of the 16
S-box lookups must be implemented in hardware. Two dominant approaches exist.

#### LUT-Based S-Box

The S-box is a 256-entry lookup table. In an FPGA, each byte maps directly to a 6-input
LUT (LUT6): the 8-bit input is split across two cascaded LUTs (with MUXF7/MUXF8 on
Xilinx) or implemented as a pair of block RAM entries.

```
// Simplified: single S-box lookup, all 256 values pre-computed
module sbox_lut (
    input  [7:0] in,
    output [7:0] out
);
    reg [7:0] sbox [0:255];
    initial $readmemh("sbox.hex", sbox);
    assign out = sbox[in];
endmodule
```

**Advantages:**
- Simple to implement and verify
- Fast: single memory access latency
- No complex arithmetic logic

**Disadvantages:**
- Each LUT maps to a fixed address: `sbox[0x53] = 0xED`, etc.
- Power consumption may correlate with input value — creates power side channels
- Requires a full 256-entry table (2048 bits per S-box instance; 32 Kbits for 16 S-boxes)

**FPGA implementation cost (Xilinx 7-series):**
- One S-box: ~6 LUT6s using distributed RAM (LUTRAM)
- 16 parallel S-boxes for SubBytes: ~96 LUT6s
- Alternative: use BlockRAM — 1 BRAM per S-box, but adds latency

#### Combinational (Tower Field) S-Box

The S-box function is decomposed into GF(2^8) arithmetic using **tower field
decomposition**: GF(2^8) → GF(2^4) → GF(2^2) → GF(2).

This allows the S-box to be implemented as a network of AND, XOR, and NOT gates without
any lookup table.

The construction (Canright 2005, Boyar-Peralta 2012):

```
Input byte b ∈ GF(2^8) = GF((2^4)^2) using irreducible polynomial x^2 + x + φ
over GF(2^4) with irreducible polynomial x^4 + x + 1 over GF(2).

Step 1: Map b from GF(2^8) to GF((2^4)^2) representation
  -- linear transformation (8 XOR operations per bit, one matrix multiply)
  [bH, bL] = M * b   where M is the change-of-basis matrix

Step 2: Invert in GF(2^4)^2 (the expensive step)
  d  = bH * bL  (GF(2^4) multiplication)
  e  = bH XOR bL
  f  = e^2 * φ  (GF(2^4) squaring and multiply by constant)
  g  = d XOR f  (GF(2^4) addition)
  g_inv = inverse in GF(2^4) (uses further decomposition to GF(2^2))
  
  cH = g_inv * e
  cL = g_inv * bH

Step 3: Apply affine transformation (8 XOR operations)
  output = A * [cH, cL] XOR 0x63
```

**Advantages:**
- No storage: entirely combinational logic
- Can be synthesised to any gate library (ASIC portability)
- Smaller area on some ASICs than equivalent BRAM usage
- Amenable to masking (each operation can be masked individually — see countermeasures)

**Disadvantages:**
- Complex to implement and verify correctly
- Multi-level critical path: typically 3–4 gate levels for GF(2^4) inversion
- Harder to understand and audit

**Area comparison (ASIC, typical 65 nm):**
```
S-box type              Gate equivalents (GE)   Critical path
LUT-based (ASIC ROM)    ~300 GE                 1 level (ROM access)
Combinational (Canright) ~105 GE                4 levels
```

The combinational S-box is typically smaller on ASIC. On FPGA, LUT-based is usually
smaller due to the native LUT structure.

---

### Key Schedule Hardware

The AES key schedule generates 11 round keys (for AES-128) from the original 128-bit
key. In hardware, there are two options:

**Pre-computed key schedule (stored in registers/RAM):**
- All round keys computed once during key setup and stored
- No key schedule logic on the critical path during encryption
- Storage: 11 × 128 = 1408 bits for AES-128
- Best for: applications where the key is fixed for many blocks (bulk encryption)

**On-the-fly key schedule:**
- Compute round key $i$ from round key $i-1$ in the pipeline stage that needs it
- Requires only one round key at a time to be stored
- Storage: 128 bits
- Best for: deeply pipelined designs where key schedule matches round pipeline depth

**Key schedule critical path:** One RotWord (byte rotation) + one S-box lookup + one
Rcon XOR per column. This is much simpler than a round function.

---

### Performance Analysis

**Throughput equation:**
```
Throughput (bps) = (Block_size × Clock_frequency) / Cycles_per_block

Iterative AES-128:    Throughput = (128 × f) / 10 = 12.8f bps
Pipelined AES-128:    Throughput = 128 × f bps (one block per cycle at full pipeline)
```

**Latency equation:**
```
Latency (seconds) = Cycles_per_block / Clock_frequency

Both iterative and pipelined AES-128: Latency = 10 / f seconds
```

**Example at 200 MHz:**
```
Architecture      Throughput    Latency
Iterative         2.56 Gbps     50 ns
4-stage pipeline  25.6 Gbps     50 ns (pipeline depth = 10 stages, 4 sub-stages each)
Fully unrolled    25.6 Gbps     50 ns (same latency as pipeline at this frequency)
                               but may achieve higher frequency due to shorter stages
```

---

## Tier 1 — Fundamentals

### Question F1
**What are the two primary AES hardware architectures, and what are the key trade-offs
between them in terms of area, throughput, and latency?**

**Answer:**

**Iterative architecture:**
- Implements one round of AES as combinational logic; feeds the output back to the
  input for each of the 10 rounds (AES-128)
- Area: minimum — one round datapath
- Latency: 10 clock cycles per block
- Throughput: one block per 10 cycles. At 200 MHz: 2.56 Gbps

**Pipelined architecture:**
- Implements all 10 rounds as separate combinational stages with pipeline registers
- Area: approximately 10× the iterative design
- Latency: still 10 cycles (pipeline depth) — one block takes 10 cycles to emerge
- Throughput: one block per cycle at steady state. At 200 MHz: 25.6 Gbps

Key insight: **pipeline increases throughput without reducing latency**. It enables more
blocks to be processed simultaneously (10 blocks in flight at once), but any single
block still takes 10 cycles.

**Common mistake:** Confusing latency with throughput. The pipeline does not speed up
any individual block — it speeds up the sustained rate at which a stream of blocks is
processed.

---

### Question F2
**Explain the two main approaches to implementing the AES S-box in hardware: LUT-based
and combinational. What is the main advantage of the combinational approach on ASIC?**

**Answer:**

**LUT-based S-box:**
Stores all 256 substitution values in a lookup table (ROM on ASIC; LUTRAM or BRAM on
FPGA). The 8-bit input directly indexes the table.

Advantage: simple design, single-cycle access.
Disadvantage: the memory access power consumption correlates with the input byte value,
creating power side channels exploitable by Differential Power Analysis (DPA).

**Combinational S-box:**
Decomposes the S-box into GF(2^8) multiplicative inversion followed by an affine
transformation. Uses tower field decomposition to reduce to GF(2^4) and GF(2^2)
arithmetic — pure gate logic (AND, XOR, NOT).

Advantage on ASIC: smaller area (~105 GE vs ~300 GE for ROM). More importantly,
individual gate operations can be independently masked (XOR with random values) to
protect against DPA — masking is straightforward when the computation is a network of
XOR and AND gates.

Disadvantage: more complex to implement and verify; multi-gate critical path.

---

### Question F3
**An AES-128 iterative implementation runs at 250 MHz. What is its throughput in Gbps?
If the same design is fully pipelined across all 10 rounds, what throughput can it
achieve at the same clock frequency?**

**Answer:**

**Iterative:**
```
Throughput = (128 bits × 250 × 10^6 Hz) / 10 cycles
           = 128 × 25 × 10^6
           = 3,200 × 10^6 bits/s
           = 3.2 Gbps
```

**Fully pipelined** (10 stages, one block per cycle):
```
Throughput = 128 bits × 250 × 10^6 Hz
           = 32,000 × 10^6 bits/s
           = 32 Gbps
```

The pipelined version achieves 10× the throughput of the iterative version because it
processes one new block per clock cycle versus one block per 10 cycles.

---

### Question F4
**Why is a combinational S-box preferred over a LUT-based S-box in side-channel-
protected AES implementations?**

**Answer:**

In a LUT-based S-box, the value read from the lookup table (and the power consumed
during the access) depends on the exact input byte. This creates a **power side channel**:
an attacker who monitors power consumption during S-box lookups can run Differential
Power Analysis (DPA) to correlate observed power traces with hypothetical input values,
recovering the AES key.

In a combinational S-box, the computation is a network of XOR and AND operations. Each
individual gate can be **masked**: replace the true signal $b$ with a masked version
$b' = b \oplus r$ (where $r$ is a fresh random value). If every signal in the circuit
carries a masked value, the intermediate power consumption is decorrelated from the true
data value. Boolean masking is straightforward to apply to individual gates.

Applying masking to a LUT lookup is harder: the LUT must be re-randomised on every
operation (random-address masking), which requires generating a new masked S-box for each
block processed — expensive in area and time.

---

## Tier 2 — Intermediate

### Question I1
**Describe how GF(2^8) multiplicative inversion is implemented in a tower field
combinational S-box. Why is the tower field decomposition useful?**

**Answer:**

Direct GF(2^8) inversion (finding $b^{-1}$ in GF(2^8)) requires computing $b^{254}$
using Fermat's little theorem: $b^{-1} = b^{2^8 - 2} = b^{254}$. This involves 11
squarings and 1 multiplication in GF(2^8) — expensive in hardware.

**Tower field decomposition** reduces the problem:

Represent GF(2^8) as GF((2^4)^2) using a degree-2 extension over GF(2^4):
```
GF(2^8) = GF(2^4)[x] / (x^2 + x + φ)  where φ ∈ GF(2^4) is a constant
```

An element $b = (bH, bL)$ where $bH, bL \in GF(2^4)$.

Inversion formula over GF((2^4)^2):
```
b^{-1} = (bH, bL)^{-1}:
  d = bH * bL                         (GF(2^4) multiplication)
  e = bH XOR bL                       (GF(2^4) addition = XOR)
  f = bH^2 * φ                        (squaring in GF(2^4) = free; one multiply)
  g = (d XOR f)                       (GF(2^4) addition)
  g_inv = g^{-1} in GF(2^4)          (GF(2^4) inversion -- recursively)
  cH = g_inv * e
  cL = g_inv * bH
```

**Why this is useful:**

GF(2^4) operations are much cheaper than GF(2^8) operations:
- GF(2^4) multiplication: ~9 AND gates + 6 XOR gates
- GF(2^4) inversion: ~17 gates (using a small LUT or further tower field decomposition)
- GF(2^8) multiplication without tower field: ~32–64 gates

The tower field decomposes one expensive GF(2^8) inversion into a few GF(2^4)
operations, each of which can be further decomposed to GF(2^2) operations. The total
gate count for the full S-box is approximately 100–120 gates, versus 300+ for a ROM.

---

### Question I2
**A high-throughput AES encryption engine is to be implemented on a Xilinx Ultrascale+
FPGA for a 100 GbE line rate application (128 Gbps required). How many parallel AES
cores are needed, and what architectural choices should be made?**

**Answer:**

**Step 1 — Determine throughput per core:**

A fully pipelined AES-128 core on Xilinx Ultrascale+:
- Typical maximum clock: 450–500 MHz (with aggressive placement and timing closure)
- One block (128 bits) per cycle
- Throughput per core: 128 × 500 × 10^6 = 64 Gbps

**Step 2 — Number of cores required:**
```
Required: 128 Gbps
Per core: 64 Gbps (at 500 MHz)
Cores needed: ceil(128 / 64) = 2 parallel cores
```

**Step 3 — Architectural choices:**

Mode of operation: For 100 GbE, AES-GCM (Galois/Counter Mode) is standard (used in
TLS_AES_128_GCM_SHA256). GCM requires:
- AES-CTR for encryption: each 128-bit counter block is independently encrypted —
  perfect for pipeline parallelism (no dependencies between blocks)
- GHASH for authentication: GF(2^128) polynomial evaluation — can be pipelined
  separately or computed in parallel

S-box implementation: Use LUT-based S-boxes (LUTRAM on Ultrascale+). The native 6-input
LUT is efficient for S-box lookup. Combinational S-boxes are preferable on ASIC but FPGA
LUTs make the ROM approach efficient here.

Key schedule: Pre-compute all round keys and store in registers (11 × 128 = 1408 bits
per core). This eliminates the key schedule from the encryption critical path.

Resource estimation per core (Xilinx Ultrascale+ HBM2):
```
LUT6s:     ~1,500 (10 rounds × ~150 LUTs/round for SubBytes + MixColumns)
FFs:       ~1,500 (pipeline stage registers)
BRAM:      0 (use LUTRAM for S-boxes)
```

Two cores: ~3,000 LUTs — well within a medium-size FPGA.

---

### Question I3
**Compare the critical path of an iterative vs. pipelined AES implementation.
Why can a pipelined design achieve a higher maximum clock frequency?**

**Answer:**

**Iterative design critical path:**

The clock period must accommodate the worst-case delay through one complete round:
```
SubBytes (8-bit S-box delay: ~3 ns) +
ShiftRows (wire routing: ~0.2 ns) +
MixColumns (GF(2^8) multiplications: ~2 ns) +
AddRoundKey (XOR: ~0.1 ns) +
State register setup time (~0.1 ns)
= ~5.4 ns → max frequency ~185 MHz
```

**Pipelined design critical path:**

With inter-stage pipeline registers, the critical path is reduced to the worst-case delay
within a single pipeline stage. If each round is implemented as one stage, the path is the
same as the iterative design (~5.4 ns). However, the pipeline can be sub-divided:

If SubBytes and (MixColumns + AddRoundKey) are separate stages:
```
Stage A: SubBytes + ShiftRows: ~3.2 ns → 313 MHz
Stage B: MixColumns + AddRoundKey: ~2.1 ns → 476 MHz
```

The maximum frequency is limited by the slowest stage (313 MHz). By splitting at the
natural latency boundary, the pipeline achieves 313 MHz vs 185 MHz for the iterative
design — a 70% clock rate improvement.

The pipeline's maximum achievable frequency improves as stages are subdivided further,
at the cost of more pipeline registers and higher latency (more stages to fill).

---

## Tier 3 — Advanced

### Question A1
**Design an AES-GCM hardware accelerator for an ASIC targeting 10 Gbps throughput at
maximum 20 mW power budget. Describe the architecture, justify the S-box choice, and
estimate the gate count.**

**Answer:**

**Target analysis:**
```
Throughput: 10 Gbps = 10 × 10^9 bits/s
Block size: 128 bits
Blocks/second: 10 × 10^9 / 128 ≈ 78.1 × 10^6 blocks/s
```

**Architecture: 3-stage sub-pipeline iterative design**

To minimise area while achieving 10 Gbps at a reasonable frequency (150 MHz target):

```
Blocks needed per cycle: 10 × 10^9 / (150 × 10^6 × 128) ≈ 0.52
```

One iterative core at 150 MHz: `128 × 150 × 10^6 / 10 = 1.92 Gbps` — insufficient.

Adjust: target 200 MHz, pipeline each round into 2 sub-stages:
```
One core at 200 MHz, pipeline depth 20 (10 rounds × 2 stages):
Throughput = 128 × 200 × 10^6 = 25.6 Gbps
```

One core achieves the target; use one core with a 5-stage CTR block generator.

**AES-GCM block diagram:**
```
CTR counter generator -> AES-CTR pipeline (20 stages) -> XOR with plaintext
                                                        -> GHASH accumulator
```

**S-box choice for low power: combinational (Canright) S-box**

Reasons:
1. ASIC ROM requires precharge and evaluate cycles — high switching power per access.
2. Combinational S-box gates switch only when their inputs change; for counter mode
   (incrementing counter), many S-box inputs repeat between blocks, reducing switching.
3. Combinational S-box enables fine-grained clock gating: entire gate clusters can be
   clock-gated when their outputs are not needed.
4. Estimated area: 16 × 105 GE = 1,680 GE for all 16 parallel S-boxes per round.

**Gate count estimate (ASIC, 65 nm standard cell):**
```
Component                   GE estimate
16 × combinational S-boxes  1,680
ShiftRows (wire routing)    ~0 (free wiring)
MixColumns (8 × GF mult)    ~1,200
AddRoundKey (128 XOR)       ~128
Round register (128 FF)     ~640
Sub-pipeline registers      ~640
Key schedule                ~800
Total per round             ~5,088 GE
× 10 rounds (unrolled)      ~50,880 GE
GHASH unit                  ~8,000 GE
CTR unit                    ~2,000 GE
Total                       ~60,880 GE ≈ 61 KGE
```

At 65 nm (typical ~1 GE ≈ 2 µm²): 61 KGE ≈ 0.12 mm² active area.

**Power estimate:**

At 200 MHz, 1.0 V supply, 65 nm: dynamic power ≈ α × C × V² × f
For 61 KGE with typical switching activity α ≈ 0.1 and unit cell capacitance:
```
Power ≈ 0.1 × 61,000 × 2 fF × 1.0² × 200 × 10^6 ≈ 2.4 mW
```

Well within the 20 mW budget. Remaining budget used for GHASH and bus interface logic.

---

### Question A2
**A security engineer proposes replacing the 16 parallel S-box instances in a round
with a single shared S-box that processes all 16 bytes in 16 clock cycles. Describe
the throughput impact and identify any new security concerns this introduces.**

**Answer:**

**Throughput impact:**

In the standard iterative design, one round completes in 1 clock cycle (all 16 S-box
lookups are parallel). If the S-boxes are serialised to 16 cycles per round:

```
Standard iterative (16 parallel S-boxes):
  Cycles per block: 10 rounds × 1 cycle/round = 10 cycles

Serialised S-box (1 S-box, 16 cycles per round):
  Cycles per block: 10 rounds × 16 cycles/round = 160 cycles

Throughput reduction: 10 / 160 = 16× throughput decrease
```

At 200 MHz: serial design achieves 128 × 200 MHz / 160 = 160 Mbps vs 2.56 Gbps.
This is only acceptable in extremely area-constrained applications (e.g., 8-bit
microcontroller AES where one S-box lookup per instruction cycle is normal).

**New security concerns:**

1. **Timing side channel (serialised address access):**
   The single shared S-box is accessed with each of the 16 bytes in sequence. The timing
   of when each byte is accessed, and whether the access is a cache hit or miss, reveals
   information about which bytes are being processed and when. This is the exact attack
   that OpenSSL's AES T-table implementation was vulnerable to (cache-timing attacks on
   software AES).

2. **Power trace alignment:**
   In the parallel design, all 16 S-box lookups produce power spikes simultaneously,
   making it difficult to correlate a single spike with a single byte value. In the
   serial design, each S-box access is temporally isolated — the power spike for byte $k$
   occurs at a predictable time, making it much easier to associate that spike with
   $\text{key}[k] \oplus \text{plaintext}[k]$ in a DPA attack.

3. **EM emission per byte:**
   Electromagnetic emissions from the single S-box repeat at intervals of 16 cycles, each
   emission corresponding to one key-XOR-plaintext value. This regularity simplifies
   Electromagnetic Analysis (EMA) considerably.

**Mitigation if area is truly the constraint:**
Use a combinational S-box with Boolean masking (not a LUT-based serial S-box). A masked
combinational S-box can be made small and provide side-channel resistance simultaneously,
albeit at higher area cost than an unmasked serial S-box.
