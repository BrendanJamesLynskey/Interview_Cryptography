# Random Number Generation

## Prerequisites
- Basic probability and information theory (entropy concept)
- Understanding of symmetric encryption primitives (AES, hash functions)
- Familiarity with operating system concepts (kernel space, system calls)
- HMAC and hash function constructions

---

## Concept Reference

### Randomness in Cryptography

Cryptographic operations require randomness for:
- Key generation (AES keys, RSA primes, ECC private keys)
- Nonce and IV generation (AES-GCM nonces, TLS session randomness)
- Signature nonces (ECDSA $k$, EdDSA prefix)
- Salt generation (password hashing, key derivation)
- Protocol challenges (zero-knowledge proofs, commitment schemes)

The security of most cryptographic protocols reduces directly to the quality of the random numbers used. **Weak randomness is one of the most common causes of real-world cryptographic failures.**

---

### Entropy

**Entropy** (Shannon entropy) quantifies the unpredictability of a source. For a discrete random variable $X$ over outcomes $x_1, \ldots, x_n$:

$$
H(X) = -\sum_{i=1}^n p(x_i) \log_2 p(x_i) \quad \text{(bits)}
$$

For a uniform distribution over $2^k$ outcomes, $H(X) = k$ bits. For a non-uniform source, $H(X) < k$.

**Min-entropy** is more relevant for cryptographic security: it captures the probability of the single most likely outcome:

$$
H_\infty(X) = -\log_2\left(\max_x p(X = x)\right)
$$

A source with $H_\infty(X) = 128$ means the most likely single outcome has probability $\leq 2^{-128}$. This is the relevant measure for key generation — an attacker who guesses the most likely key must try $2^{128}$ attempts.

---

### True Random Number Generators (TRNGs)

A **TRNG** derives randomness from a physical process that is inherently unpredictable:

| Source | Mechanism | Quality | Notes |
|---|---|---|---|
| Thermal noise | Johnson–Nyquist noise in resistors | High | Requires analogue front-end |
| Shot noise | Discrete photon/electron arrival times | High | Used in optical TRNGs |
| Radioactive decay | Geiger counter inter-arrival times | High | Rarely practical |
| Oscillator jitter | Phase noise in ring oscillators | Medium | Common in hardware RNGs (RDRAND, TRNG blocks in FPGAs) |
| Atmospheric noise | Radio-frequency noise | Medium | Random.org, not suitable for latency-sensitive use |

**Hardware TRNGs on modern processors:**

- **Intel RDRAND/RDSEED** (Ivy Bridge 2012+): Hardware RNG using two AES-CBC-MAC conditioned ring oscillators. RDRAND returns conditioned output (after an AES post-processing step); RDSEED returns raw entropy suitable for seeding a DRBG.
- **ARM TrustZone TRNG**: Available on Cortex-A55+ and Cortex-M85; entropy source is jitter-based ring oscillators.
- **FIPS 140-3 TRNG validation**: Requires health tests (NIST SP 800-90B), stuck-bit detection, and autocorrelation analysis.

**Limitation of TRNGs:** Low throughput (typically 1–100 Mb/s maximum), variable quality depending on environmental conditions (temperature, power supply noise), and potential for hardware failure. TRNGs should be used to **seed** a DRBG, not directly for bulk key material.

---

### Pseudorandom Number Generators (PRNGs)

A **PRNG** is a deterministic algorithm that expands a short seed into a long sequence of apparently random values:

$$
\text{PRNG}_s : \{0,1\}^k \rightarrow \{0,1\}^{\gg k}
$$

A **cryptographically secure PRNG (CSPRNG)** must satisfy two properties:

1. **Next-bit unpredictability:** Given the first $i$ output bits, no polynomial-time algorithm can predict bit $i+1$ with probability $> 1/2 + \text{negl}(k)$. Equivalently, the output is computationally indistinguishable from a uniformly random sequence.

2. **State compromise extension resistance (backward security):** If the internal state is compromised at time $t$, an adversary cannot reconstruct outputs from before time $t$ (assuming state was not previously compromised).

A PRNG that is not cryptographically secure (e.g., `rand()`, Mersenne Twister) should **never** be used in cryptographic contexts.

---

### NIST SP 800-90A Deterministic Random Bit Generators (DRBGs)

NIST specifies three FIPS-approved DRBG constructions in SP 800-90A:

#### Hash_DRBG (SHA-256 based)

The internal state is a value $V$ and a constant $C$, both derived from the seed:

```
Reseed:
  seed_material = entropy_input || additional_input
  V = df(seed_material)      (derivation function — hash-based)
  C = df(0x00 || V)

Generate:
  output block: data = Hash(V)
  V = (V + C + reseed_counter) mod 2^seedlen
```

Hash_DRBG with SHA-256 provides 256-bit security and is widely used.

#### HMAC_DRBG (HMAC-SHA-256 based)

State: $(K, V)$ pair of 256-bit values.

```
Update(provided_data):
  K = HMAC(K, V || 0x00 || provided_data)
  V = HMAC(K, V)
  if provided_data is not empty:
    K = HMAC(K, V || 0x01 || provided_data)
    V = HMAC(K, V)

Generate:
  while need more output:
    V     = HMAC(K, V)
    output = V
  Update(additional_input)
```

HMAC_DRBG is used in RFC 6979 (ECDSA deterministic nonce generation) and is simpler to implement correctly than Hash_DRBG. The `K` acts as both a MAC key and a backtracking-resistance key.

#### CTR_DRBG (AES-256 based)

State: AES key $K$ (256 bits) and counter block $V$ (128 bits).

```
Generate:
  while need more output:
    V = V + 1 (mod 2^128)
    output = AES_K(V)
  Update(additional_input)
```

CTR_DRBG is preferred in hardware implementations where AES-NI is available but SHA hardware is absent. It is the default DRBG in many embedded systems and hardware security modules.

---

### OS Entropy Sources and /dev/random vs /dev/urandom

Modern operating systems collect entropy from multiple hardware sources into an **entropy pool**:

| Source | Entropy estimate | Notes |
|---|---|---|
| Interrupt timing | Low–medium | Network packets, USB, keyboard, disk |
| Hardware TRNG (RDRAND) | High | Seeded directly into pool |
| CPU jitter (jitterentropy) | Medium | Timing variations in CPU pipeline |
| Disk seek timing | Low | Spinning disks only |
| Network packet timing | Low | Not reliable alone |

#### Linux

- **`/dev/random`** (pre-Linux 5.6): Blocks when kernel estimates insufficient entropy. This caused significant latency issues in VMs and containers (low-entropy environments).
- **`/dev/urandom`**: Non-blocking; uses the ChaCha20-based CRNG seeded at boot. After initial seeding, provides cryptographic-quality output indefinitely.
- **Linux 5.17+:** `/dev/random` and `/dev/urandom` behaviour was unified — both use the same ChaCha20 CRNG. The distinction between "blocking" and "non-blocking" was eliminated because the kernel's entropy estimation was shown to be unreliable.
- **`getrandom(2)` syscall**: The preferred interface. Blocks only until the CRNG is initially seeded (typically a few milliseconds after boot), then returns immediately. Use flags `GRND_NONBLOCK` to avoid blocking at boot, or `GRND_RANDOM` for legacy `/dev/random` semantics.

```c
#include <sys/random.h>

uint8_t key[32];
ssize_t n = getrandom(key, sizeof(key), 0);  // blocks until seeded
if (n != sizeof(key)) {
    // Handle error
}
```

#### Windows

- **`BCryptGenRandom`** (CNG): The correct API. Uses the Fortuna algorithm seeded from multiple entropy sources including RDRAND and system events.
- **`CryptGenRandom`** (legacy, CAPI): Deprecated; wraps BCryptGenRandom.
- **`rand_s`** (MSVC): C runtime wrapper for BCryptGenRandom; correct for most use cases.

---

### Fortuna Algorithm

**Fortuna** (Ferguson and Schneier, 2003) is the design basis for macOS/iOS SecRandom and Windows BCryptGenRandom. Its key innovations address specific weaknesses of earlier designs:

**Architecture:**
- 32 separate entropy accumulator pools $P_0, P_1, \ldots, P_{31}$
- A generator (AES-256 CTR_DRBG)
- A seeding schedule: pool $P_i$ is used to reseed every $2^i$ reseedings

**Reseeding schedule advantage:**

If an attacker observes the internal state (state compromise), Fortuna's design limits the damage:
- $P_0$ is used in every reseed — fast recovery after compromise when a small amount of new entropy arrives.
- $P_{31}$ is used only once every $2^{31}$ reseeds — pools accumulate entropy over longer periods, ensuring that even a slow attacker-controlled entropy source cannot repeatedly bias the pool.

**Generator (AES-256 CTR mode):**

```
key:      256-bit AES key (K)
counter:  128-bit block counter (C)

Generate(n bytes):
  output = AES_K(C) || AES_K(C+1) || ...  (n bytes)
  Reseed self: K = first 256 bits of AES_K(C + blocks_used)
  C += blocks_used + 1  (advance counter, ensuring forward secrecy)
```

The self-reseeding step after each output provides **forward secrecy**: an attacker who compromises the state at time $t$ cannot reconstruct outputs from before time $t$ because each generation step overwrites the key.

---

### Entropy Failures in Practice

Notable cryptographic failures caused by weak randomness:

1. **Debian OpenSSL RNG bug (2008, CVE-2008-0166):** A Debian maintainer removed what appeared to be an uninitialized-variable warning, inadvertently removing the entropy-gathering call from `MD_Update`. The OpenSSL PRNG was seeded only from the process ID (max 32768 values on Linux). All RSA and DSA keys generated on Debian/Ubuntu between 2006-2008 were vulnerable; the entire keyspace was enumerable.

2. **Android SecureRandom failure (2013):** Android 4.1-4.3 used Java's `SecureRandom` backed by OpenSSL, which failed to properly seed `/dev/urandom` on first use in some configurations. Bitcoin wallet applications were found to have reused ECDSA nonces, enabling private key recovery from blockchain transactions.

3. **Dual_EC_DRBG backdoor (2013):** NIST SP 800-90A originally included Dual_EC_DRBG, based on discrete logarithm over P-256. Documents revealed by Snowden confirmed the NSA had deliberately weakened the algorithm: the public point $Q$ had an unknown relationship to the generator $P$, allowing the NSA (who knew $Q = dP$) to predict all outputs from 32 bytes of DRBG output. Dual_EC_DRBG was removed from SP 800-90A Rev 1 in 2014.

4. **Heartbleed (2014):** While primarily a buffer overread, Heartbleed could expose TLS session keys and private key material from server memory, including DRBG state. Recovery required rekeying all affected services.

---

## Tier 1 — Fundamentals

### Question F1
**What is the difference between a TRNG, a PRNG, and a CSPRNG? Why is a standard PRNG like Mersenne Twister unsuitable for cryptography?**

**Answer:**

**TRNG (True Random Number Generator):** Derives randomness from a physical entropy source (thermal noise, oscillator jitter, radioactive decay). Output is non-deterministic — it cannot be reproduced. Throughput is limited and quality depends on the physical source. Used to seed a CSPRNG.

**PRNG (Pseudorandom Number Generator):** A deterministic algorithm that expands a seed into a long output sequence. Given the same seed, always produces the same sequence. A good PRNG passes statistical tests (NIST SP 800-22, Diehard) but this only measures statistical uniformity, not cryptographic security.

**CSPRNG (Cryptographically Secure PRNG):** A PRNG that additionally satisfies:
1. **Next-bit unpredictability:** Given any output prefix, no efficient algorithm predicts the next bit better than 50/50.
2. **State compromise extension resistance:** Compromising the state at time $t$ does not reveal prior outputs.

**Why Mersenne Twister (MT19937) is unsuitable:**

Mersenne Twister has a large internal state (624 × 32-bit words = 19,968 bits). After observing 624 consecutive 32-bit outputs, an attacker can reconstruct the **entire internal state** by inverting the tempering transformation. From the recovered state, all past and future outputs are known.

```python
# MT19937 state recovery — NEVER use for cryptography
# After observing 624 outputs, reconstruct full state:

def untemper(y: int) -> int:
    """Invert the MT19937 tempering step."""
    # Undo right shift XOR
    y ^= y >> 18
    # Undo left shift XOR (with mask)
    y ^= (y << 15) & 0xEFC60000
    # Undo left shift XOR (7 bits at a time)
    y ^= (y << 7) & 0x9D2C5680
    y ^= ((y ^ (y << 7) & 0x9D2C5680) << 7) & 0x9D2C5680
    # Undo right shift XOR (11 bits)
    y ^= y >> 11
    y ^= (y ^ (y >> 11)) >> 11
    return y & 0xFFFFFFFF

# After collecting 624 outputs, reconstruct state and predict future values
```

In contrast, a CSPRNG like AES-256-CTR_DRBG produces output by encrypting a counter — inverting AES output requires the key. Observing any amount of CSPRNG output cannot reconstruct the state.

**Common mistake:** Using `random.random()` or `rand()` for session tokens, API keys, or CSRF tokens. These are PRNGs, not CSPRNGs, and their state is recoverable from output.

---

### Question F2
**Explain Shannon entropy and min-entropy. Why is min-entropy the more relevant measure for key generation?**

**Answer:**

**Shannon entropy** measures the average information content of a source:

$$
H(X) = -\sum_x p(x) \log_2 p(x)
$$

It is maximised for a uniform distribution: $H(X) = \log_2 N$ for $N$ equally likely outcomes.

**Min-entropy** measures the probability of the single most likely outcome:

$$
H_\infty(X) = -\log_2\left(\max_x p(x)\right)
$$

Min-entropy is always $\leq$ Shannon entropy.

**Example:** Suppose a "random" 128-bit key is generated by a flawed PRNG that always outputs one of 1000 possible keys uniformly.

- Shannon entropy: $H = \log_2(1000) \approx 10$ bits
- Min-entropy: $H_\infty = \log_2(1000) \approx 10$ bits

An attacker needs to try at most 1000 keys — not $2^{128}$.

**Why min-entropy is relevant:**

A cryptographic adversary plays a **guessing game**, not an information game. They are trying to find the key, not measure how much information the key carries on average. The adversary will always try the most likely key first. The number of guesses needed to find the key with probability $\geq 1/2$ is determined by the min-entropy:

$$
\text{Guesses needed for P(success) = 1/2} \approx 2^{H_\infty(X) - 1}
$$

A source with $H_\infty = 128$ bits provides 128-bit security regardless of its Shannon entropy.

**Practical consequence:** NIST SP 800-90B requires entropy sources to provide $\geq 1$ bit of min-entropy per bit of output (full entropy). Sources failing this test must be conditioned (hashed) before use as seed material.

---

### Question F3
**What is the difference between `/dev/random` and `/dev/urandom` on Linux? Which should applications use?**

**Answer:**

Historically:

- **`/dev/random`:** Blocked when the kernel's estimated entropy pool fell below a threshold. The kernel maintained an entropy counter and decremented it with each output byte, blocking when the counter reached zero. Designed to provide "true" randomness gated by physical entropy.

- **`/dev/urandom`:** Never blocked. Used the same entropy pool but did not decrement the entropy counter. Described as suitable when "a little bit" of entropy is acceptable.

**The historical distinction was mostly misleading:**

1. The Linux kernel entropy estimator was acknowledged to be approximate and often wrong.
2. After initial seeding, both `/dev/random` and `/dev/urandom` used the same underlying CPRNG (an AES-based generator post-Linux 4.8 or ChaCha20 post-5.17). The blocking behaviour of `/dev/random` added latency without providing additional security once the CPRNG was seeded.
3. Theodore Ts'o (Linux kernel developer) stated publicly in 2012 that `/dev/random` blocking was security theater for most use cases.

**Current Linux 5.17+ behaviour:** The distinction was formally eliminated. Both sources use the same ChaCha20-based CPRNG. `/dev/random` no longer blocks (except during early boot before seeding).

**What applications should use:**

```c
// Best practice: use getrandom(2) syscall
#include <sys/random.h>

uint8_t buf[32];
// Blocks only until CPRNG is initially seeded (~boot time)
// Never blocks during normal operation
if (getrandom(buf, sizeof(buf), 0) != sizeof(buf)) {
    perror("getrandom");
    abort();
}
```

Or in higher-level languages:
```python
import os
key = os.urandom(32)   # uses getrandom() on Linux; BCryptGenRandom on Windows
```

**Never use `/dev/random` for blocking** in application code — it causes unnecessary latency in containerised and virtualised environments where entropy is initially scarce (e.g., freshly started VMs, serverless functions, Docker containers without host entropy forwarding).

---

### Question F4
**What is forward secrecy in the context of a CSPRNG? How does CTR_DRBG achieve it?**

**Answer:**

**Forward secrecy** (also called "backtracking resistance") for a CSPRNG means: if the internal state is compromised at time $t$, an adversary cannot reconstruct the outputs generated **before** time $t$.

This is distinct from forward secrecy in key exchange (where it refers to session key independence from long-term keys), but the intuition is similar — past outputs are protected from future compromise.

**Why it matters:**

Without forward secrecy, a single state compromise (e.g., a memory dump, cold-boot attack, or Heartbleed-style read) allows an adversary to reconstruct all past PRNG outputs — revealing previously generated session keys, nonces, and private keys.

**How CTR_DRBG achieves forward secrecy:**

After each generation request, CTR_DRBG performs a **key erasure** (sometimes called "ratcheting"):

```
Generate n bytes:
  output_blocks = AES_K(C) || AES_K(C+1) || ... (n bytes)

  # Advance key to new value — old key is overwritten and unrecoverable
  new_key = AES_K(C + n_blocks) || AES_K(C + n_blocks + 1)  [256 bits]
  K = new_key
  C = C + n_blocks + 2
```

After the `K = new_key` step, the old key is overwritten. Even if the adversary obtains the new state $(K_{\text{new}}, C_{\text{new}})$:

- The old key $K_{\text{old}}$ is gone from memory.
- Recovering $K_{\text{old}}$ from $K_{\text{new}}$ requires inverting AES — infeasible.
- Therefore, past outputs computed under $K_{\text{old}}$ are irretrievable.

**Secure erasure in practice:**

Key erasure in software requires care: compilers may optimise away zero-fills of local variables. Use OS-provided secure memory wiping:
```c
// Correct way to erase sensitive material
explicit_bzero(old_key, sizeof(old_key));      // POSIX
SecureZeroMemory(old_key, sizeof(old_key));    // Windows
OPENSSL_cleanse(old_key, sizeof(old_key));     // OpenSSL
```

---

## Tier 2 — Intermediate

### Question I1
**Explain the Fortuna algorithm's multi-pool design. What attack does it defend against compared to single-pool designs?**

**Answer:**

**Single-pool weakness:**

A naive entropy accumulator collects all entropy events into one pool and reseeds the generator whenever enough entropy has arrived. If an attacker can:
1. Observe the internal state at time $t$ (state compromise)
2. Control or predict a fraction of subsequent entropy events (entropy injection attack)

Then after the generator reseeds from the pool (now contaminated with attacker-controlled entropy), the attacker can predict the new state. With a single pool, **a single reseed from a compromised pool compromises the generator**.

**Fortuna's multi-pool defence:**

Fortuna uses 32 pools $P_0, \ldots, P_{31}$. Entropy sources distribute events across pools in round-robin order. The reseeding schedule is:

$$
\text{Reseed } i \text{ uses pools } P_j \text{ where } 2^j \mid i
$$

- Reseed 1: uses $P_0$ only
- Reseed 2: uses $P_0, P_1$
- Reseed 4: uses $P_0, P_1, P_2$
- Reseed $2^k$: uses $P_0, P_1, \ldots, P_k$

**Consequence:** Pool $P_j$ is used in one out of every $2^j$ reseeds. For the attacker to contaminate a reseed that uses $P_j$, they must control a fraction of entropy events over a window of $2^j$ reseed cycles.

**Attack cost:** An attacker who controls a fraction $\alpha$ of entropy events cannot influence $P_j$ if $\alpha < 2^{-(j+1)}$ (they cannot reliably have their event be the last one into $P_j$ before it is used). With 32 pools, $P_{31}$ requires controlling the entropy source for $\sim 2^{31}$ reseed cycles — practically infeasible for a brief compromise.

**Recovery after compromise:** After a state compromise, $P_0$ is used in the very next reseed. If even a few bits of genuine entropy arrive before the reseed, the state diverges from what the attacker observed. Recovery time is proportional to how quickly $P_0$ accumulates genuinely unpredictable entropy — typically within milliseconds on an active system.

---

### Question I2
**Explain the Dual_EC_DRBG backdoor. What property of elliptic curves enabled it, and why was the backdoor undetectable without the secret?**

**Answer:**

**Dual_EC_DRBG construction:**

The generator uses two elliptic curve points $P$ and $Q$ on P-256. The internal state is an integer $s$:

```
Generate step:
  r = (s * P).x           (x-coordinate of sP)
  output = r * Q truncated to 240 bits
  s = (r * P).x           (next state)
```

**The backdoor:**

If the NSA chose $Q$ such that $Q = d \cdot P$ for a known scalar $d$ (the discrete log of $Q$ base $P$), then from any 30-byte output block:

1. The output is 240 bits from $(r \cdot Q)_x = (r \cdot d \cdot P)_x$. Given these 240 bits, all $2^{16}$ possible completions of the 256-bit x-coordinate can be tested.
2. For each candidate $x^*$, check if it is a valid P-256 x-coordinate; recover the point $r \cdot Q$.
3. Compute $r \cdot P = (r \cdot Q) \cdot d^{-1}$. This is the next-step input to produce $s_{\text{next}}$.
4. The new state $s_{\text{next}} = (r \cdot P)_x$ is now known — all future outputs are predictable.

The attacker recovers the full DRBG state from 32 bytes of output in $\leq 2^{16}$ operations — trivial.

**Why it was undetectable without $d$:**

Without knowing $d$ (the discrete log of $Q$ to base $P$), the relationship $Q = dP$ cannot be verified. The NSA published $P$ and $Q$ as "nothing-up-my-sleeve" constants but provided no derivation. Verifying that $Q$ was chosen without knowledge of $d$ would require solving the ECDLP on P-256 — believed to require $2^{128}$ work.

The design of Dual_EC_DRBG was flagged as potentially backdoored by Shumow and Ferguson in 2007 (they noted the structure allowed a kleptographic backdoor if $Q = dP$). The Snowden documents confirmed the NSA had paid RSA Security $10M to make Dual_EC_DRBG the default in their BSAFE library.

**Lesson:** Any standardised cryptographic parameter without a verifiable derivation (a "nothing-up-my-sleeve" number) is potentially backdoored. All published NIST curves (P-256, P-384) have seed values with opaque derivations, though no backdoor has been found or demonstrated. Curve25519 and Ed25519 were designed with fully transparent, verifiable constants.

---

### Question I3
**What is the von Neumann extractor and when is it used in hardware RNG design?**

**Answer:**

Physical entropy sources (ring oscillators, thermal noise ADCs) often produce **biased** bits — the probability of a 1 may be $p \neq 0.5$. A biased source has fewer than 1 bit of entropy per output bit.

The **von Neumann extractor** (1951) de-biases a source of i.i.d. bits with unknown bias $p$:

```
Input: stream of independent bits with P(1) = p, P(0) = 1-p

1. Read pairs of bits.
2. If pair = (0,1): output 0
   If pair = (1,0): output 1
   If pair = (0,0) or (1,1): discard and read next pair
```

**Proof of correctness:**

$$
P(01) = p(1-p), \qquad P(10) = (1-p)p
$$

Since $P(01) = P(10)$, the output is unbiased (each output bit is equally likely 0 or 1), regardless of $p$.

**Efficiency:** The expected number of input bits consumed per output bit is:

$$
\frac{1}{2p(1-p)} \geq 2
$$

Maximised efficiency at $p = 0.5$ (unbiased input); efficiency drops as $p \to 0$ or $p \to 1$.

**Limitations:**

1. Requires **i.i.d. input** — if consecutive bits are correlated (e.g., due to thermal drift), the extractor fails. Ring oscillator TRNGs sometimes have autocorrelation; hardware designers must characterise this.

2. Not sufficient as a sole conditioning step for high-quality entropy. NIST SP 800-90B requires more sophisticated conditioning using a hash function or CMAC:

$$
\text{Conditioned seed} = H(\text{raw TRNG output})
$$

A hash conditioner is a **strong extractor**: it extracts near-uniform bits from any source with sufficient min-entropy, regardless of the distribution shape.

**FPGA implementation:** Intel/Xilinx FPGA TRNGs typically use free-running ring oscillators sampled by a faster clock. The raw bits are fed through a von Neumann extractor followed by an AES or SHA-based conditioner before being presented to the design via a dedicated TRNG IP block.

---

### Question I4
**Describe the NIST SP 800-90B health tests for entropy sources. Why are health tests necessary in production systems?**

**Answer:**

SP 800-90B mandates two classes of health tests for hardware entropy sources:

**1. Startup tests:**
Run before the entropy source is used for the first time after power-on. Collect 1024 samples and apply full statistical tests (repetition count test and adaptive proportion test). If the source fails, the system must not use the TRNG.

**2. Continuous online tests:**
Run during normal operation on every batch of new entropy. Detect sudden degradation (e.g., a hardware fault, temperature extreme, power glitch, or active attack).

**Repetition Count Test (RCT):**

Track how many consecutive samples repeat the same value. Threshold:

$$
C_{\text{RCT}} = 1 + \left\lceil \frac{-\log_2 \alpha}{H_\infty} \right\rceil
$$

where $\alpha$ is the false positive rate (typically $2^{-20}$) and $H_\infty$ is the claimed min-entropy per sample. If any value repeats $C_{\text{RCT}}$ or more times consecutively, the source is flagged as stuck (returning a constant).

**Adaptive Proportion Test (APT):**

In a window of 512 samples, count how many equal the first sample. If the count exceeds a threshold (derived from the binomial distribution at the claimed entropy level), the source is flagged.

**Why health tests are necessary:**

1. **Hardware failures:** A failed ring oscillator can output a constant or periodic sequence (stuck-at fault), providing zero entropy. Without health testing, a failed TRNG silently degrades to a constant source — all subsequent keys are predictable.

2. **Environmental attacks:** An adversary with physical access can apply voltage glitches or electromagnetic interference to bias or freeze a ring oscillator. Health tests detect unusually low entropy and trigger an alarm.

3. **Certification requirements:** FIPS 140-3 (replacing 140-2) mandates SP 800-90B compliance for entropy sources in approved modules. Failure to implement health tests causes certification failure.

4. **VM entropy starvation:** In virtualised environments, a guest's TRNG may see repeating values if the hypervisor is not correctly forwarding physical entropy. Health tests trigger early failure rather than silently generating weak keys.

---

## Tier 3 — Advanced

### Question A1
**Explain the seed recovery attack on virtual machine clones. How does this affect CSPRNG security in cloud environments, and what mitigations exist?**

**Answer:**

**The attack:**

Cloud platforms (AWS, GCP, Azure) routinely:
- **Snapshot and restore** VM instances (for backup or migration)
- **Clone** VM images (spinning up multiple identical instances from the same base image)

When a VM is snapshotted and the snapshot is later restored, the CSPRNG state returns to the state at snapshot time. If the VM has already generated keys or nonces using the CSPRNG, those values will be regenerated upon restore — producing **identical keys, nonces, and signatures** from two independent-appearing points in time.

**Scenario:**

1. VM boots; CSPRNG seeds from `/dev/random` (reads RDRAND + kernel entropy pool).
2. TLS private key generated at time $t_0$. State: $S_0$.
3. Snapshot taken at time $t_1 > t_0$. State captured: $S_1$.
4. VM continues running; more keys generated. State advances to $S_2$.
5. Snapshot restored to create a clone. Clone's state: $S_1$.
6. Clone generates new keys. From $S_1$, generates **identical sequence** as the original VM after $t_1$.

**Consequence:** The original and the clone will generate the same session keys, ECDSA nonces, and TLS ephemeral keys. If both VMs use the same nonce in ECDSA, the private key is recovered (see mac_and_signatures.md, Question F3).

**Mitigations:**

1. **Include VM-unique data in CSPRNG reseed:**
   ```c
   // On each VM start/resume, reseed with instance-specific entropy
   uint8_t seed_material[64];
   // EC2: fetch instance metadata (contains unique instance ID + timestamp)
   // Include: RDRAND output, current time (nanoseconds), process ID
   getrandom(seed_material, sizeof(seed_material), 0);
   // Mix in instance identity
   RAND_add(instance_id, sizeof(instance_id), sizeof(instance_id));
   ```

2. **Check for VM resume on kernel CSPRNG init:** Linux 5.10+ detects hypervisor-signalled resumes (e.g., via ACPI events or paravirtual channels) and forces a CSPRNG reseed from hardware entropy.

3. **Use hardware TRNG (RDRAND) directly:** RDRAND output is not snapshotable — it comes from physical hardware state that is not captured in a VM snapshot. Seeding from RDRAND at startup and after every resume prevents state reuse.

4. **Avoid key generation before post-boot entropy:** Systemd and cloud-init now wait for the kernel entropy pool to be fully seeded before starting services that generate keys.

5. **Virtio-RNG:** The VirtIO random number device forwards entropy from the host to the guest, providing post-restore fresh entropy.

---

### Question A2
**Describe the cryptanalysis of the Debian OpenSSL entropy bug. What was the root cause, what was the impact, and how was it discovered?**

**Answer:**

**Root cause (CVE-2008-0166):**

In May 2006, a Debian maintainer patched OpenSSL to suppress Valgrind warnings about uninitialized memory usage. The offending lines in `md_rand.c` were:

```c
// REMOVED by Debian patch (lines that actually provided entropy):
MD_Update(&m, buf, j);   // j = uninitialized stack bytes — intentional entropy source
...
MD_Update(&m, (unsigned char*)&(md_c[1]), sizeof(md_c[1]));
```

The original code used uninitialized stack bytes (`buf`) as an entropy source — deliberately exploiting the non-determinism of stack memory. The Valgrind warning was a false positive; the uninitialized reads were intentional. Removing these lines reduced the PRNG's seed to a single source: the process ID (PID).

**State space after the patch:**

Linux PIDs are limited to a maximum of 32768 (configurable; default 32768). The effective seed space became:

$$
|\text{Seeds}| = 32768 = 2^{15}
$$

Any RSA key, DSA key, or ECDSA key generated with the patched OpenSSL on Debian/Ubuntu between 2006 and 2008 could be reproduced by iterating over all $\leq 32768$ PID values and regenerating the key.

**Impact:**

- SSH host keys and user keys on all Debian-based systems were vulnerable.
- All X.509 certificates (TLS server certificates) with private keys generated on affected systems were compromised.
- Any OpenVPN, stunnel, or Apache key generated during the affected period was recoverable.
- Debian published a tool to check if a given public key was in the set of 32768 possible keys. Matching any entry meant the private key was trivially recoverable.

**Discovery:**

Discovered in May 2008 by Luciano Bello, who noticed during security auditing that ssh-keygen on Debian produced keys suspiciously quickly and that consecutive invocations had detectable structural similarities. He correlated the weak output with the 2006 patch and produced a proof-of-concept key recovery tool.

**Lesson:** Entropy code should be treated as security-critical and protected from "cleanup" patches. Uninitialized memory reads that produce Valgrind warnings in entropy-gathering code are often intentional. The standard for patching cryptographic code must include a security review, not just a build warning review.

---

### Question A3
**Explain the concept of a randomness extractor and the leftover hash lemma. How is this applied in key derivation?**

**Answer:**

**Problem:** A physical entropy source may have high min-entropy but non-uniform distribution. We need to extract near-uniform random bits from it.

A **randomness extractor** is a function $\text{Ext}: \{0,1\}^n \times \{0,1\}^d \rightarrow \{0,1\}^m$ that takes:
- A source $X$ with min-entropy $\geq k$
- A short random seed $Y$ of length $d$

And produces an output $\text{Ext}(X, Y)$ that is $\epsilon$-close to uniform, meaning:

$$
\Delta\left(\text{Ext}(X, Y),\; U_m\right) \leq \epsilon
$$

where $\Delta$ is statistical distance.

**Leftover Hash Lemma (LHL) (Impagliazzo–Levin–Luby 1989):**

Let $\mathcal{H}$ be a family of 2-universal hash functions $h: \{0,1\}^n \rightarrow \{0,1\}^m$. If the source $X$ has min-entropy $\geq k$, then for a random $h \xleftarrow{\$} \mathcal{H}$:

$$
\Delta\bigl((h, h(X)),\; (h, U_m)\bigr) \leq \frac{1}{2}\sqrt{\frac{2^m}{2^k}} = 2^{(m-k-2)/2}
$$

**Interpretation:** To extract $m$ near-uniform bits from a source with $k$ bits of min-entropy, use a universal hash function mapping to $m$ bits. The extraction is valid as long as $m \leq k - 2\log_2(1/\epsilon)$ (the **extractable entropy** is $k - 2\log_2(1/\epsilon)$).

**Application in key derivation (HKDF):**

HKDF (RFC 5869, NIST SP 800-56C) has two steps:

1. **Extract:** $\text{PRK} = \text{HMAC-Hash}(\text{salt}, \text{IKM})$

   The input keying material (IKM) may be from Diffie-Hellman output (non-uniform, but high min-entropy). HMAC with a random salt acts as a 2-universal hash function, applying the LHL to produce a near-uniform PRK.

2. **Expand:** $\text{OKM} = T_1 \,\|\, T_2 \,\|\, \cdots$ where $T_i = \text{HMAC-Hash}(\text{PRK}, T_{i-1} \,\|\, \text{info} \,\|\, i)$

   The expand step is a standard PRF, producing keying material of any required length.

```python
import hmac, hashlib, os

def hkdf(ikm: bytes, length: int,
         salt: bytes | None = None,
         info: bytes = b"") -> bytes:
    """
    HKDF-SHA256: Extract-then-expand key derivation.
    ikm:    Input keying material (e.g., ECDH shared secret)
    length: Desired output length in bytes
    salt:   Optional salt; defaults to zeroed block if not provided
    info:   Context-specific information string
    """
    # Step 1: Extract
    if salt is None:
        salt = bytes(hashlib.sha256().digest_size)  # zero-filled block
    prk = hmac.new(salt, ikm, hashlib.sha256).digest()

    # Step 2: Expand
    okm  = b""
    prev = b""
    for i in range(1, (length + 31) // 32 + 1):
        prev = hmac.new(prk, prev + info + bytes([i]), hashlib.sha256).digest()
        okm += prev
    return okm[:length]

# Example: derive session keys from ECDH shared secret
shared_secret = os.urandom(32)   # would come from ECDH in practice
aes_key   = hkdf(shared_secret, 32, info=b"aes-key")
hmac_key  = hkdf(shared_secret, 32, info=b"hmac-key")
print(f"AES key:  {aes_key.hex()}")
print(f"HMAC key: {hmac_key.hex()}")
```

**Why the salt matters:** A ECDH shared secret $g^{xy}$ is a group element — it is not uniformly distributed over $\{0,1\}^{256}$. Without the extract step (hashing with a salt), the non-uniformity could weaken derived keys. The salt makes HMAC act as a strong extractor, converting arbitrary min-entropy to near-uniform PRK. NIST SP 800-56C mandates the extract step when the input is from a key agreement (DH/ECDH).
