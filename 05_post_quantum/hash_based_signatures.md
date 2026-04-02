# Hash-Based Signatures: SPHINCS+ and Merkle Trees

## Prerequisites
- Hash functions and their security properties (preimage, collision, second-preimage
  resistance) — see `../01_fundamentals/hash_functions.md`
- Digital signatures conceptually — see `../01_fundamentals/mac_and_signatures.md`
- `quantum_threat.md` — Grover's algorithm and hash function quantum security

---

## Concept Reference

### Why Hash-Based Signatures Are Post-Quantum Secure

Hash-based signature schemes derive their security from the security of the underlying
hash function alone. Unlike RSA (which requires factoring hardness) or ECDSA (which
requires ECDLP hardness), there is no algebraic structure that Shor's algorithm can
exploit. A hash-based scheme is quantum-safe as long as:
- The hash function resists Grover's preimage search at the required security level
- The hash function resists quantum collision-finding (BHT or similar)

This makes hash-based signatures the most conservative post-quantum signature choice:
their security assumptions are minimal and well-understood. The trade-off is larger
signature sizes and, for some schemes, stateful key management.

---

### One-Time Signatures (OTS): The Foundation

Hash-based signature schemes are built from one-time signature (OTS) primitives that
can only sign a single message safely.

**Lamport-Diffie OTS:**

The simplest OTS scheme. For a 256-bit message:

```
Key generation:
  Private key: 512 random values x[0][0], x[0][1], ..., x[255][0], x[255][1]
               (each 256 bits; 2 values per message bit position)
  Public key:  512 hash values y[i][b] = H(x[i][b])

Signing message M (256 bits):
  For each bit i (0 to 255):
    If M[i] == 0: reveal s[i] = x[i][0]
    If M[i] == 1: reveal s[i] = x[i][1]
  Signature: (s[0], s[1], ..., s[255])

Verification:
  For each bit i:
    If M[i] == 0: check H(s[i]) == y[i][0]
    If M[i] == 1: check H(s[i]) == y[i][1]

Security: signing a second different message M' reveals additional x values.
An attacker who sees two signatures can combine them to forge signatures on
any message whose bits are a subset of the revealed bits.
```

Lamport signatures are enormous (512 * 32 = 16 KB for a 256-bit hash) but the
principle is clear. More compact OTS schemes exist:

**Winternitz OTS (WOTS):**

WOTS reduces signature size by signing multiple bits per chain. For a Winternitz
parameter w (typically 4 or 16):

```
Chain function: f^k(x) = apply hash function k times to x

Key generation for n-bit messages with w-bit chunks:
  l = ceil(n/log2(w)) + ceil((log2(l*w) + 1) / log2(w))
    (number of chains; accounts for checksum)
  Private key: l random n-bit values x[0], ..., x[l-1]
  Public key:  l values y[i] = f^(w-1)(x[i]) = H(H(...H(x[i])...))  [w-1 times]

Signing m (in base-w representation, m = m[0] || m[1] || ... || m[l-1]):
  s[i] = f^(m[i])(x[i])   -- apply hash m[i] times

Verification:
  Check: f^(w-1-m[i])(s[i]) == y[i]  for all i
         (complete the chain to w-1 steps and compare to public key)

Trade-off:
  w=4:   l ≈ 67, signature = 67 * 32 = 2144 bytes, verify = 3*67 = 201 hashes
  w=16:  l ≈ 35, signature = 35 * 32 = 1120 bytes, verify = 15*35 = 525 hashes
```

WOTS+ (used in SPHINCS+) adds a bitmask XOR step to each hash application, providing
tighter security proofs against adaptive chosen-message attacks.

---

### Merkle Trees: From OTS to Many-Time Signatures

An OTS can only sign one message. A Merkle tree authenticates a large pool of OTS key
pairs, enabling a many-time signature scheme.

**Structure:**

```
                        root
                       /    \
                   h01        h23
                  /   \      /   \
                h0    h1   h2    h3
                |     |    |     |
               pk0   pk1  pk2   pk3

Where:
  hX  = H(left_child || right_child)
  pkX = public key of OTS instance X

The Merkle root is the public verification key.
To sign message M using OTS instance i:
  1. Generate OTS signature sigma_i on M using private key sk_i
  2. Output (sigma_i, pk_i, authentication_path)
     where authentication_path is the sibling nodes needed to recompute the root:
     e.g., for i=0: authentication_path = [h1, h23]

Verification:
  1. Verify OTS signature sigma_i against pk_i
  2. Reconstruct root from pk_i and authentication_path
  3. Check reconstructed root == stored root
```

A Merkle tree of height h supports 2^h signatures. The signer tracks a counter to
avoid reusing OTS instances (stateful requirement).

**Authentication path length:** For a tree of height h, the authentication path
contains h node hashes (one per level). For h=20, that is 20 * 32 = 640 bytes of
authentication path plus the OTS signature.

---

### SPHINCS+: Stateless Hash-Based Signatures (FIPS 205, SLH-DSA)

SPHINCS+ is a stateless hash-based signature scheme, meaning the signer does not need to
track which OTS instances have been used. It avoids the state management problem by using
a hypertree structure with few-time signatures (FORS) at the leaves.

**Core insight:** In a stateful scheme, reusing an OTS key is catastrophic. SPHINCS+
avoids state by indexing OTS instances using a pseudorandom function of the message
and a secret seed — the same message always maps to the same OTS instance, but
different messages map to different instances with overwhelming probability.

**SPHINCS+ Structure:**

```
Hypertree: d layers of Merkle trees, each of height h'
           Total height H = h' * d
           Total OTS instances = 2^H

FORS (Forest Of Random Subsets):
  A few-time signature scheme used at the leaf of the hypertree
  Signs message digests; provides security against multi-target attacks

Top-level hypertree:
  Layer d-1 (top):  1 tree of height h', signs FORS public keys using WOTS+
  Layer d-2:        2^h' trees, each of height h'
  ...
  Layer 0 (bottom): 2^{h'*(d-1)} trees, each of height h'
                    leaves are FORS public keys

Signing:
  1. Compute randomised message digest using secret seed and message
  2. Use digest to index into FORS trees; sign with FORS
  3. Authenticate FORS public key up through d layers of WOTS+ and Merkle trees
```

**SPHINCS+ parameter sets:**

```
Notation: sphincs-<hash>-<n>f or sphincs-<hash>-<n>s
  n = security parameter (bytes of output / internal state)
  f = fast (smaller tree depth d, fewer hash calls, larger signatures)
  s = small (deeper trees, more hash calls, smaller signatures)

Selected parameter sets for FIPS 205 (SLH-DSA):

Variant                  n    h   d   log2(t)  k   w   Security  Sig size
-------------------     --   --  --   -------  --  --  --------  --------
SLH-DSA-SHA2-128f        16   66  22    6       33  16  NIST L1   17088 bytes
SLH-DSA-SHA2-128s        16  63   7    12       14  16  NIST L1    7856 bytes
SLH-DSA-SHA2-192f        24   66  22    8       33  16  NIST L3   35664 bytes
SLH-DSA-SHA2-192s        24  63   7    14       17  16  NIST L3   16224 bytes
SLH-DSA-SHA2-256f        32   68  17    9       35  16  NIST L5   49856 bytes
SLH-DSA-SHA2-256s        32  64   8    14       22  16  NIST L5   29792 bytes
SHAKE variants available: same parameters but using SHAKE-256 instead of SHA-256

n: security parameter in bytes
h: total Merkle tree height
d: number of layers in hypertree
k: number of FORS trees
w: Winternitz parameter
Sig size: bytes (substantially larger than Dilithium)
```

**Key sizes:**

```
Variant                  Public key   Private key
-------------------      ----------   -----------
SLH-DSA-SHA2-128f         32 bytes     64 bytes
SLH-DSA-SHA2-256f         64 bytes    128 bytes

Public keys are tiny (just a root hash and a seed). Private keys are also small.
The overhead is entirely in the signature.
```

---

### XMSS and LMS: Stateful Hash-Based Signatures

SPHINCS+ is stateless and approved for general use. Two stateful schemes are also
standardised and used in specific contexts:

**XMSS (eXtended Merkle Signature Scheme, RFC 8391):**

```
Structure: Single Merkle tree of height h, using WOTS+ OTS at leaves
Supports: 2^h signatures (h = 10, 16, or 20 typically)
State: signer must securely persist the next unused leaf index
Key sizes: small (public key = 2*n bytes for root + seed)
Signature: n*(h + 67) bytes approximately (for n=32, h=20: ~2500 bytes)

Fatal flaw if state is lost: signing the same message twice with different
randomness is detectable but safe; signing TWO DIFFERENT messages with the
same OTS leaf completely breaks security (attacker can forge signatures)
```

**LMS (Leighton-Micali Signatures, RFC 8554):**

```
Similar to XMSS but uses LM-OTS (Leighton-Micali OTS) instead of WOTS+
Simpler construction, widely used in firmware signing (IETF RFC 9360
specifies LMS for firmware update in constrained devices)
HSS (Hierarchical Signature System) extends LMS to multi-layer trees
for more signatures without proportionally increasing verification cost
```

**When to use stateful vs. stateless:**

```
Stateless (SPHINCS+):
  Use when: general-purpose signing, no state management infrastructure,
            signing keys shared across multiple devices/HSMs,
            code signing, certificate authorities (low signing volume OK)
  Drawback: large signatures (8-50 KB depending on variant)

Stateful (XMSS, LMS):
  Use when: high-volume signing with controlled state,
            firmware signing (embedded systems sign once per build),
            controlled HSM environment where state can be reliably preserved
  Advantage: smaller signatures (~2-3 KB)
  Risk: state corruption or rollback causes catastrophic security failure
```

---

### Comparison to Lattice-Based Signatures

```
Property              SPHINCS+ (SLH-DSA-128s)   Dilithium3 (ML-DSA)
------------------    -----------------------    -------------------
Security basis        Hash function only         MLWE + MSIS (structured lattice)
Public key            32 bytes                   1952 bytes
Private key           64 bytes                   4000 bytes
Signature             7856 bytes                 3293 bytes
Sign speed            Slow (millions of hashes)  Fast
Verify speed          Moderate                   Fast
Stateful              No                         No
Conservative choice   Yes (minimal assumptions)  Moderate (new math)
Deployment friction   High (large signatures)    Moderate (medium signatures)
```

SPHINCS+ is the more conservative choice: its security reduces to hash function
security, which is the most trusted post-quantum hardness assumption. Dilithium is
faster and has smaller signatures, but its security depends on the hardness of structured
lattice problems that have less cryptanalytic history than SHA-256 or SHA-3.

---

## Interview Questions

### Fundamentals

**Q1.** Why can a Lamport OTS only be used to sign a single message, and what breaks if
it is used twice?

**Answer:**

In a Lamport OTS, the private key consists of 2n random values (two per bit position).
The public key is the hash of each private value. To sign a message, the signer reveals
one of the two private values at each bit position — the one corresponding to the
message bit (0 or 1).

If the same key pair signs two different messages M and M', the revealed values are:
- For each bit position i where M[i] != M'[i], both x[i][0] and x[i][1] are now known.

With both values at even one bit position revealed, an attacker can forge a signature on
any message that agrees with either M or M' at all positions — covering an exponentially
large set. In the worst case, if M and M' differ at every bit, the attacker has seen all
2n private values and can sign any message.

This is why OTS schemes require a new key pair per message, and why higher-level
constructions (Merkle trees, SPHINCS+) are needed for practical many-message signing.

---

**Q2.** What is the purpose of the Merkle tree in hash-based signature schemes, and what
does the authentication path prove?

**Answer:**

The Merkle tree allows a single short root hash (the public key) to authenticate a large
pool of OTS key pairs. Without the tree, each OTS key pair would require its own
independent public key distribution channel.

Structure: Each leaf of the tree is an OTS public key hash. Each internal node is the
hash of its two children. The root summarises the entire pool.

The authentication path for leaf index i consists of the sibling nodes at each level:
the nodes you need to compute the path from leaf to root. Given the OTS public key pk_i
and its authentication path, anyone can recompute the root and verify it matches the
known public key. This proves that pk_i is one of the 2^h pre-committed OTS keys.

The authentication path has h nodes (one per tree level). For h=20, this is 20 * 32 =
640 bytes, which is small compared to the OTS signature itself. A Merkle tree of height
20 supports 2^20 = ~1 million signatures from a single public key.

---

### Intermediate

**Q3.** Explain the stateless property of SPHINCS+ and how it avoids the state management
problem of XMSS.

**Answer:**

XMSS requires the signer to maintain a counter tracking which OTS leaf has been used.
If the counter is ever duplicated (hardware failure, HSM migration, software bug),
the same OTS leaf is reused, breaking security completely.

SPHINCS+ avoids this by selecting the OTS leaf index pseudorandomly based on the
message content rather than a persistent counter:

```
Leaf index = PRF(SK_prf, R || M)
where SK_prf is a secret seed, R is per-signature randomness, M is the message
```

Each message signs using a different pseudorandomly selected leaf. The tree is large
enough (total height H = 60-70) that the probability of two different messages
selecting the same leaf is negligible (birthday bound: after 2^(H/2) ≈ 2^30-35
signatures, collisions become likely — well beyond practical signing volumes).

FORS (the few-time signature component at the hypertree leaves) provides additional
protection: FORS can sign a bounded number of messages per leaf without security loss.

The trade-off: each SPHINCS+ signature must include enough tree material to authenticate
the chosen leaf from scratch (the entire hypertree path). This produces the large
signature sizes (8-50 KB), in contrast to XMSS signatures (~2-3 KB) which amortise
tree authentication over many signatures with a known state.

---

**Q4.** A system needs to sign firmware images (~10 MB) for 10 million IoT devices.
Compare SPHINCS+ and LMS/XMSS for this use case and recommend one.

**Answer:**

**Signing volume:** 10 million devices implies at most one firmware release per device
per year, with perhaps 5-10 firmware versions over the device lifetime. Total signatures:
~50-100 million over the device fleet lifetime. This is manageable for both schemes.

**Firmware signing constraints:**
- Signing is done offline, by a controlled build system — not by the devices
- The firmware verification is done by each device, which may have limited RAM and flash
- Code-signing keys are typically stored in HSMs with controlled access
- State management: an HSM can reliably track XMSS leaf indices with hardware protection

**Comparison for this use case:**

```
Property           SPHINCS+-128s       LMS (HSS)
--------------     -------------       ---------
Signature size     7856 bytes          ~2500 bytes
Signing speed      Slow (~millions     Fast (~thousands of hashes)
                   of hashes)
State required     No                  Yes (in HSM)
Verification       ~40,000 hashes      ~5,000 hashes  (on device)
RAM for verify     Minimal             Minimal
Max signatures     No practical limit  2^50+ with HSS
Risk               None (stateless)    State loss in HSM = catastrophic failure
```

**Recommendation: LMS/HSS** for this specific use case.

Rationale:
- The build system HSM can reliably maintain LMS state (this is a controlled environment)
- Verification speed is critical: IoT devices may have 8-32 MHz processors with limited
  flash. SPHINCS+ requires ~40,000 hash calls to verify; LMS requires ~5,000. At 1 SHA-2
  compression per ~1000 cycles, SPHINCS+ takes ~40 ms vs. LMS ~5 ms at 1 MHz.
- Signature size: saving 5 KB per device during OTA update is meaningful at scale
  (50 GB saved per 10 million devices per update)
- LMS is standardised in RFC 8554 and used in IETF firmware update protocols (RFC 9360)

SPHINCS+ would be preferred if: the signing infrastructure is distributed (multiple
signing parties without shared state), or if state management cannot be guaranteed (e.g.,
cloud-based signing with potential for concurrent signing on multiple instances).

---

### Advanced

**Q5.** Describe the FORS (Forest Of Random Subsets) component in SPHINCS+ and explain
why it is a few-time signature scheme rather than a one-time scheme.

**Answer:**

FORS is the leaf-level signature component in SPHINCS+. It signs the message digest that
is derived from the actual message M and a randomness value R.

**Structure:** FORS uses k independent binary trees of height a (so each tree has 2^a
leaves). The message digest is split into k chunks of a bits each. For each chunk i
(with value m_i in range [0, 2^a)):

```
1. Reveal the m_i-th leaf value from tree i as the signature component
2. Provide the authentication path in tree i (a sibling hashes)
3. Verification: check the revealed leaf and path authenticate to tree i's root
```

The FORS public key is the hash of all k tree roots.

**Why few-time, not one-time:** An OTS scheme leaks information about the private key
with every signature. FORS leaks one leaf per tree per signature. After f signatures
with different message digests, an attacker has seen on average f/2^a distinct leaves
per tree. A forgery requires producing a valid signature on a new message, which requires
knowing a specific subset of leaves — specifically, the exact leaves indexed by the new
message's digest.

The security analysis shows that FORS withstands a number of signatures that depends on
the parameters (k, a). Typically FORS is designed to be used for at most a small number
of signatures per instance (bounded by the multi-target attack resistance). SPHINCS+
ensures that different messages are mapped to different FORS instances via the hypertree
structure, so the few-time property is never violated in practice.

**Why not just use WOTS+ at the leaves?** FORS provides better multi-target security for
the specific use case of signing fixed-size message digests at the bottom of the
hypertree. It is more efficient than WOTS+ for this role because the message digest is
already uniformly random (output of a hash), so the few-time security is sufficient.

---

**Q6.** What is the security impact if an XMSS private key is used to sign two different
messages with the same leaf index? Can the scheme recover?

**Answer:**

This is a catastrophic, unrecoverable security failure.

**What breaks:** Each WOTS+ instance at a leaf is an OTS scheme. Signing two different
messages M and M' with the same WOTS+ instance reveals:
- For M: WOTS+ signature s[i] = f^(m_i)(x[i]) for each chain i
- For M': WOTS+ signature s'[i] = f^(m'_i)(x[i]) for each chain i

Where m_i and m'_i are the i-th Winternitz digit of M's and M's digests respectively.
For any chain position i where m'_i < m_i, the attacker already knows f^(m_i)(x[i])
from the first signature. They can compute f^(m'_i)(x[i]) = f^{m_i - m'_i - 1}(s[i])
by applying the hash chain function additional times. By collecting both signatures,
the attacker can reconstruct enough chain values to forge a WOTS+ signature on an
arbitrary message.

**Can the scheme recover?** No. Once the leaf index is reused, the attacker has
permanent, irreversible forgery capability for any message. The only remediation is to:
1. Revoke and replace the XMSS public key in all relying parties
2. Re-sign all previously signed artefacts with a new key
3. Investigate the cause of the state rollback or duplication

**Prevention:** XMSS state must be managed with the same care as an HSM-protected
signing counter. Hardware write-once registers, TPM monotonic counters, or HSM-native
state management (as in PKCS#11 CKA_ALWAYS_AUTHENTICATE mechanisms) must be used.
Backups of XMSS private key state must be treated as active keys, not as restore points
— restoring from a backup after signing constitutes a state rollback and must be treated
as a key compromise event.

---

## Common Mistakes

- Treating SPHINCS+ as interchangeable with XMSS. SPHINCS+ is stateless; XMSS is
  stateful. They have different operational requirements and failure modes.
- Underestimating SPHINCS+ signature sizes. At 8-50 KB depending on variant, signatures
  can break protocol assumptions (certificate formats, TLS record limits) designed for
  64-256 byte signatures.
- Assuming the Lamport OTS is practically deployable. It is a conceptual building block;
  its 16 KB signatures make it impractical. WOTS+ is used in production schemes.
- Believing hash-based signatures are slow for verification. SPHINCS+ verification is
  moderate (not fast), but XMSS and LMS verification is fast and suitable for IoT.
- Overlooking the quantum security of the hash function. Using SHA-1 or MD5 in a
  hash-based signature scheme provides no meaningful post-quantum security, since these
  functions are already classically weak.
- Misunderstanding statefulness. XMSS/LMS do not require online state management for
  verification (verifiers are stateless); only signers need state.
