# Migration Strategies for Post-Quantum Cryptography

## Prerequisites
- `quantum_threat.md` — Shor's and Grover's algorithms
- `lattice_based_kyber_dilithium.md` — ML-KEM and ML-DSA
- `hash_based_signatures.md` — SPHINCS+
- TLS 1.3, PKI, and certificate management fundamentals
- NIST post-quantum standards: FIPS 203, 204, 205

---

## Concept Reference

### Migration Dimensions

A PQC migration is not a single event — it is an infrastructure-wide transition
across four dimensions simultaneously:

```
1. Key Exchange:   ECDH -> ML-KEM (Kyber) or hybrid X25519Kyber768
2. Signatures:     ECDSA/RSA -> ML-DSA (Dilithium) or SLH-DSA (SPHINCS+)
3. Certificates:   X.509 chains must use PQ signature algorithms
4. Symmetric keys: AES-128 -> AES-256 (Grover mitigation)
```

Each dimension has different urgency, different operational complexity, and different
protocol dependencies.

---

### Urgency Framework

Not all systems have equal urgency. The "Harvest Now, Decrypt Later" (HNDL) threat
motivates prioritisation:

```
Urgency tier    System type                          Migration target
------------    ---------------------------------    -------------------------
CRITICAL        Government/military comms            Complete by 2027-2028
                Long-lived classified data
                National security systems

HIGH            Financial transaction records         Complete by 2028-2030
                Healthcare records (HIPAA data)
                Legal/contractual records

MEDIUM          General TLS web traffic               Complete by 2030-2035
                Enterprise internal comms
                Cloud storage

LOW             Short-lived ephemeral data            Monitor; migrate on refresh
                Public social media
```

---

### Hybrid Key Exchange: X25519Kyber768

A hybrid key exchange combines a classical algorithm with a post-quantum algorithm.
The shared secret is derived from both, providing security if either component is secure.

**Rationale for hybrid:**

- If the post-quantum algorithm has an undiscovered weakness (new cryptanalysis),
  the classical component maintains security.
- If Shor's algorithm is deployed against the classical component, the PQ component
  maintains security.
- Hybrid provides a graceful transition: clients and servers support both algorithms
  and gradually deprecate the classical component.

**X25519Kyber768 construction (IETF draft-ietf-tls-hybrid-design):**

```
TLS 1.3 NamedGroup: X25519Kyber768Draft00 (or the standardised OID)

ClientHello key_share extension:
  Classical component: 32-byte X25519 public key
  PQ component:        1184-byte Kyber-768 public key
  Total client key share: 1216 bytes (vs 32 bytes for pure X25519)

ServerHello key_share extension:
  Classical component: 32-byte X25519 public key
  PQ component:        1088-byte Kyber-768 ciphertext
  Total server key share: 1120 bytes

Key derivation:
  classical_shared  = X25519(client_priv, server_pub)    -- 32 bytes
  pq_shared         = Kyber768_decapsulate(server_ct)    -- 32 bytes
  DHE input to HKDF = classical_shared || pq_shared      -- 64 bytes
```

The concatenated 64-byte value replaces the standard 32-byte X25519 output in the
TLS 1.3 key schedule. If either component is secure, the combined DHE input is
computationally indistinguishable from a 64-byte uniform random value.

**Deployment status (as of 2025):**
- Chrome 116+: default X25519Kyber768 for TLS 1.3
- Firefox 120+: X25519Kyber768 enabled by default
- Cloudflare, Google: deployed X25519Kyber768 on servers
- OpenSSL 3.2: supports OQS provider for hybrid key exchange

---

### Certificate and PKI Migration

Certificates must use post-quantum signature algorithms for the entire CA chain:
- Root CA signature: must be PQ (ML-DSA or SLH-DSA)
- Intermediate CA signature: must be PQ
- Leaf certificate signature: must be PQ

**Certificate size impact:**

```
Algorithm         Public key    Signature   Total cert overhead
--------------    ----------    ---------   -------------------
ECDSA P-256       64 bytes      64 bytes    ~128 bytes
RSA-2048          256 bytes     256 bytes   ~512 bytes
ML-DSA-65         1952 bytes    3293 bytes  ~5245 bytes
SLH-DSA-128f      32 bytes      17088 bytes ~17120 bytes
```

A certificate chain with two ML-DSA certificates (leaf + intermediate) adds ~10 KB
to the TLS handshake. For most connections this is tolerable, but it requires:
- TLS record layer: can fragment across multiple records (transparent)
- HTTP/2 server push: certificate delivery may increase first-page load time
- Certificate parsing buffers: must accommodate larger certificates
- Mobile clients: increased battery consumption from larger certificate processing

**Migration path for PKI:**

```
Phase 1 — Dual-stack certificates (2024-2027):
  Issue two certificates per entity: one ECDSA (classical) + one ML-DSA (PQ)
  TLS servers present both; clients use whichever they support
  Certificate Transparency logs must handle ML-DSA certificates

Phase 2 — PQ-only for new issuances (2027-2030):
  New certificates use ML-DSA only
  Existing ECDSA certificates continue until expiry (90-day rotation helps)
  OCSP stapling: OCSP responses must also be PQ-signed

Phase 3 — ECDSA decommission (2030+):
  Remove ECDSA certificate handling from TLS stacks
  Browser/OS roots: remove all non-PQ root CAs
```

---

### Code Signing Migration

Code signing (firmware, software updates) has different requirements than TLS:
- Signatures are stored with the artefact indefinitely
- Verification keys are embedded in devices at manufacture time
- Rollback protection requires monotonic counters
- Many devices cannot receive root CA updates

**Key challenge:** A device manufactured today with an ECDSA verification key embedded
cannot be retrospectively upgraded to verify ML-DSA signatures. The new verification
key must either be:
1. Included at manufacture (requires forecasting PQ needs)
2. Delivered via a separate authenticated update mechanism
3. Dual-signed (ECDSA + ML-DSA) to support legacy and new verifiers simultaneously

**Firmware dual-signing format:**

```
Image:  [ECDSA signature][ML-DSA signature][firmware payload]

Legacy device (ECDSA only):  verifies ECDSA, ignores ML-DSA
PQ-capable device:            verifies ML-DSA, ignores ECDSA
Hybrid device:                verifies both, requires both valid
```

This approach requires no format changes to existing firmware delivery infrastructure
and allows gradual transition of the device fleet.

---

### Symmetric Cryptography Migration

Grover's algorithm halves the bit-security of symmetric keys and hash outputs.
The mitigation is straightforward:

| Current | Post-Quantum equivalent | Action required |
|---|---|---|
| AES-128 | AES-256 | Replace with AES-256 |
| AES-192 | AES-256 | Replace with AES-256 |
| AES-256 | Already PQ-safe (~128-bit quantum) | No change needed |
| SHA-256 | SHA-384 (for collision resistance) | Evaluate per use case |
| SHA-384 | Already PQ-safe | No change needed |
| HMAC-SHA256 | HMAC-SHA256 still safe for PRF use | Monitor |

**SHA-256 nuance:** For preimage resistance (hash-then-sign, HMAC), SHA-256 retains
128-bit quantum security under Grover and remains safe. For collision resistance
(Merkle trees in hash-based signatures, certificate fingerprints), use SHA-384 or
SHA-512 to maintain 128-bit quantum collision resistance.

---

### NIST PQC Standards Summary

```
Standard    Algorithm        Purpose           Key sizes            Status
---------   ----------       -------           ---------            ------
FIPS 203    ML-KEM (Kyber)   KEM               768 bytes (pk)       Published 2024
FIPS 204    ML-DSA (Dilith)  Signatures        1952 bytes (pk)      Published 2024
FIPS 205    SLH-DSA (SPHINCS+) Signatures      32 bytes (pk)        Published 2024
FIPS 206    FN-DSA (FALCON)  Signatures        897 bytes (pk)       Drafting 2025
```

**Algorithm selection guidance:**

```
Use case                          Recommended algorithm
---------------------             ---------------------
TLS key exchange                  ML-KEM-768 (hybrid with X25519)
Application-level encryption      ML-KEM-768 or ML-KEM-1024
Digital signatures (general)      ML-DSA-65 (Dilithium3)
Signatures (minimal pk size)      FN-DSA (FALCON-1024) -- when FIPS 206 published
Firmware signing                  ML-DSA-65 or SLH-DSA-SHA2-128s
High-assurance minimal assumption SLH-DSA (hash-only security basis)
```

---

## Tier 1 — Fundamentals

### Question F1
**Why is a hybrid approach (e.g., X25519Kyber768) recommended for TLS key exchange
rather than immediately switching to pure ML-KEM?**

**Answer:**

A hybrid approach provides security under two complementary assumptions:

1. **If ML-KEM has an undiscovered weakness:** The classical X25519 component
   remains secure, protecting the session. Post-quantum algorithms are relatively new;
   ML-KEM has only a few years of broad cryptanalytic scrutiny compared to decades
   for ECDH. A hybrid ensures that even if a break in ML-KEM is discovered, no
   retrospective decryption of recorded traffic is possible.

2. **If a quantum computer attacks the classical component:** The ML-KEM component
   provides quantum-resistant security, protecting against HNDL attacks.

Security guarantee: "At least as secure as the stronger component."

The hybrid approach also provides a gradual migration path: servers can enable hybrid
support while maintaining compatibility with clients that only support X25519, falling
back to pure X25519 for unaware clients. This avoids a forced flag-day cutover.

The operational cost is larger TLS handshake messages (~2 KB larger than pure X25519)
which is generally acceptable.

---

### Question F2
**A company currently uses RSA-2048 for TLS certificates. What is the migration path
to post-quantum certificates, and what operational challenges arise?**

**Answer:**

**Migration path:**

Step 1 — Upgrade key exchange (immediate, high urgency):
Deploy X25519Kyber768 hybrid on TLS servers. This protects against HNDL for forward
secrecy without requiring certificate changes. Certificate signatures remain RSA/ECDSA
for now — they authenticate identity, not session keys, so past traffic is not
retroactively decryptable.

Step 2 — Request ML-DSA certificates from your CA:
When the CA supports FIPS 204 (ML-DSA), request new certificates. Operate dual-cert
if needed (ECDSA for legacy clients, ML-DSA for modern clients).

Step 3 — Update OCSP and CRL infrastructure:
OCSP responses and CRLs must be signed with ML-DSA once the CA migrates.

Step 4 — Update client trust stores:
Browser and OS trust stores must contain ML-DSA-signed root CA certificates.
This requires coordination with browser vendors and OS vendors.

**Operational challenges:**

1. **Certificate size:** ML-DSA certificates are ~5 KB vs ~2 KB for RSA/ECDSA.
   Certificates must fit within TLS record limits and be handled by all certificate
   parsing code in the stack.

2. **Signing latency:** ML-DSA signing is slower than ECDSA P-256 on some hardware.
   High-volume CAs (issuing millions of certificates daily, like Let's Encrypt) need
   hardware acceleration or additional capacity.

3. **HSM support:** Hardware Security Modules holding CA private keys must support
   ML-DSA operations. Most existing HSMs do not; firmware updates or replacements
   are required.

4. **Certificate Transparency:** CT logs must accept and prove inclusion of ML-DSA
   certificates. CT log operators must update their software.

---

### Question F3
**What does AES-256 provide against a quantum adversary using Grover's algorithm,
and is it sufficient for long-term security?**

**Answer:**

Grover's algorithm provides a quadratic speedup for unstructured search. Applied to
AES-256 key search (keyspace $2^{256}$), Grover reduces the attack cost to approximately
$2^{128}$ quantum operations.

AES-256 therefore provides approximately **128-bit quantum security** for key-guessing
attacks. NIST considers 128-bit quantum security sufficient for general confidentiality
needs through at least 2030 and likely much longer.

**Practical considerations:**

1. Grover's algorithm is **not easily parallelisable**: unlike classical brute force
   (which scales linearly with number of cores), parallelising Grover's algorithm among
   $k$ quantum processors reduces query count by only $k^{1/2}$, not $k$. This
   makes brute-force Grover attacks on AES-256 practically infeasible even with
   large quantum clusters.

2. Grover requires a quantum circuit for AES-256 evaluation. The circuit has substantial
   T-gate depth, requiring millions of error-corrected logical qubits. Current (2025)
   quantum hardware is far from this capability.

3. AES-256 is considered **sufficient for post-quantum symmetric security** by NIST,
   NSA, and ENISA. Upgrading from AES-128 to AES-256 is the appropriate symmetric
   migration step.

---

### Question F4
**What is the difference between FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), and FIPS 205
(SLH-DSA)? When would you choose each?**

**Answer:**

**FIPS 203 — ML-KEM (Kyber):** A Key Encapsulation Mechanism. Establishes a shared
symmetric key between two parties. Used for:
- TLS 1.3 key exchange (replacing ECDH)
- Hybrid key encapsulation in encrypted messaging
- Any protocol that needs to establish a shared secret

**FIPS 204 — ML-DSA (Dilithium):** A digital signature scheme based on module lattices.
Used for:
- Authenticating TLS certificates (replacing ECDSA/RSA in X.509)
- Code signing, firmware signing
- JWT/OAuth token signing
- Any application requiring a verifiable digital signature

**FIPS 205 — SLH-DSA (SPHINCS+):** A digital signature scheme based on hash functions only.
Used for:
- High-security environments where minimal hardness assumptions are required
- Certificate authorities (sign fewer times; large signatures acceptable)
- Long-lived signatures where the quantum security of lattice problems is uncertain
- Backup/alternative signature algorithm alongside ML-DSA

**Selection guidance:**

- Need key exchange: use ML-KEM.
- Need signatures, performance is important, medium-to-large signatures acceptable:
  use ML-DSA.
- Need signatures, minimal security assumptions, can tolerate large (~8-50 KB)
  signatures: use SLH-DSA.
- Cannot choose between ML-DSA and SLH-DSA: implement both as supported algorithms;
  use ML-DSA for normal operations and SLH-DSA for high-value signing.

---

## Tier 2 — Intermediate

### Question I1
**A TLS 1.3 server needs to support both classical and post-quantum clients during
a transition period. Describe the handshake negotiation for each client type when
the server has both an ECDSA and an ML-DSA certificate.**

**Answer:**

**Case 1 — Classical-only client (does not support ML-KEM or ML-DSA):**

```
ClientHello:
  - supported_groups: X25519, P-256
  - signature_algorithms: ecdsa_secp256r1_sha256, rsa_pss_rsae_sha256

Server response:
  - ServerHello: X25519 key share
  - Certificate: ECDSA P-256 certificate (classical)
  - CertificateVerify: ECDSA signature
  - Handshake key derivation: standard X25519-based
```

Forward secrecy: classical only. HNDL risk remains.

**Case 2 — Hybrid-capable client (supports X25519Kyber768):**

```
ClientHello:
  - key_share: X25519Kyber768 (1216 bytes: X25519 pk + Kyber pk)
  - signature_algorithms: ecdsa_secp256r1_sha256,
                          mldsa65  (FIPS 204 algorithm ID)

Server response:
  - ServerHello: X25519Kyber768 server share (1120 bytes: X25519 pk + Kyber ct)
  - Certificate: ML-DSA certificate (server selects PQ cert when client supports it)
    OR: ECDSA cert if browser supports hybrid KE but not PQ cert verification
  - CertificateVerify: ML-DSA signature (or ECDSA if cert is ECDSA)
```

Key derivation: DHE = X25519_shared || Kyber_shared (64 bytes).
Both components enter HKDF, providing quantum-safe forward secrecy.

**Case 3 — Full PQ client (supports ML-KEM-768 pure, no hybrid):**

```
ClientHello:
  - key_share: ML-KEM-768 only
  - signature_algorithms: mldsa65 only

Server response:
  - ServerHello: ML-KEM-768 ciphertext (1088 bytes)
  - Certificate: ML-DSA certificate
```

**Server configuration requirement:** Dual-certificate configuration with algorithm
negotiation. The server selects which certificate to present based on the client's
`signature_algorithms` extension. If the client advertises ML-DSA support, the server
prefers the ML-DSA certificate. Otherwise, it falls back to ECDSA.

---

### Question I2
**An embedded firmware device has a 64 KB flash budget for a firmware update module.
What signature scheme is viable for verifying 10 MB firmware images, and what are
the key management constraints?**

**Answer:**

**Flash budget analysis:**

```
Flash allocation (64 KB total):
  Verification code + stack:  ~20 KB
  Public key storage:         variable (see below)
  Signature storage:          variable (see below)
  Firmware image (in flash):  external storage, verified in-place
  Available for crypto:       ~44 KB

Signature scheme options:
  ECDSA P-256:  public key = 64 bytes, signature = 64 bytes   -- too small a total
  ML-DSA-44:    public key = 1312 bytes, signature = 2420 bytes  -- 3.7 KB total
  ML-DSA-65:    public key = 1952 bytes, signature = 3293 bytes  -- 5.2 KB total
  SLH-DSA-128s: public key = 32 bytes, signature = 7856 bytes   -- 7.9 KB total
  SLH-DSA-128f: public key = 32 bytes, signature = 17088 bytes  -- 17.1 KB total
  LMS (h=20):   public key = 64 bytes, signature = ~2500 bytes  -- 2.6 KB total
```

All post-quantum schemes fit within the 44 KB crypto budget.

**Viability comparison for 10 MB images:**

ML-DSA-44 or LMS are best suited:
- ML-DSA-44: 3.7 KB total. No state management. Verification requires polynomial
  arithmetic (NTT). Code size for ML-DSA verification: ~10-15 KB for a compact
  implementation.
- LMS: 2.6 KB total. Simple hash-chain verification (~5,000 SHA-256 calls). Code
  size: ~2-4 KB for a compact implementation. **However: signer must maintain state.**

Recommendation for most embedded devices: **LMS with HSS** (if the signing server
can maintain state) or **ML-DSA-44** (if stateless signing is required).

**Key management constraints:**

1. **Key provisioning:** The verification public key must be securely embedded at
   device manufacture. If ML-DSA is used, the 1312-byte public key is stored in
   read-only flash (write-once OTP or protected flash sector).

2. **Key rollover:** When the signing key is rotated, all devices must receive the
   new public key via an authenticated key update mechanism. This must itself use
   the current valid signing key, creating a chicken-and-egg problem if the key is
   compromised.

3. **Rollback protection:** The firmware version must be stored in a monotonic counter
   (TPM or hardware OTP register) so an attacker cannot replay an older, vulnerable
   firmware image with a valid signature.

4. **LMS state if used:** The build system's HSM must track the LMS leaf index. The
   build pipeline must be designed to prevent parallel signing of different firmware
   images on the same HSM without coordinated leaf advancement.

---

## Tier 3 — Advanced

### Question A1
**A telecommunications company stores 20 years of recorded TLS sessions encrypted under
ECDH key exchange. Design a migration plan that addresses the HNDL risk for this
historical archive.**

**Answer:**

**Assessment of exposure:**

The 20-year archive contains sessions whose key exchange occurred via ECDH. All session
keys were derived from ephemeral ECDH shared secrets that no longer exist. However, the
ECDH public keys are in the TLS handshake records. A quantum adversary with a CRQC can:

1. Extract the ephemeral ECDH public key shares from stored ClientHello/ServerHello
2. Apply Shor's algorithm to recover the ephemeral private key from the public key
3. Recompute the ECDH shared secret
4. Apply the TLS 1.3 key schedule to recover the session keys
5. Decrypt all application data in the recorded session

The data is therefore retroactively vulnerable once a CRQC exists.

**Migration options:**

Option A — Re-encrypt the archive (most complete):

If the plaintext TLS session content was captured (by the company's own inspection
infrastructure, e.g., TLS inspection appliances), re-encrypt each session under
AES-256-GCM with a new key derived from a quantum-safe KMS:

```
For each session:
  plaintext = TLS_inspect_decrypt(session_record)
  new_key = KMS_derive(session_id, "pq-rearchive-2025")
  new_ciphertext = AES_256_GCM_encrypt(new_key, plaintext)
  store(session_id, new_ciphertext)
  securely_delete(session_record)
```

Cost: requires decrypting and re-encrypting the full 20-year archive. If the archive
is 1 PB, this requires substantial compute and I/O over months.

Option B — Tiered re-encryption (risk-based):

Classify sessions by data sensitivity:
- Tier 1 (high-value: authentication sessions, financial transactions): re-encrypt now
- Tier 2 (medium-value: user content): re-encrypt by 2027
- Tier 3 (low-value: telemetry, public content): monitor; re-encrypt only if CRQC
  timeline accelerates

This reduces the re-encryption cost by 80-90% while protecting the most sensitive data.

Option C — Secure deletion (if re-encryption is infeasible):

For sessions whose plaintext is genuinely expendable, cryptographically secure deletion
(overwrite with random data, then key destruction) eliminates the HNDL risk. This
requires verifying that no copies exist in backup systems.

**Implementation recommendations:**

1. Deploy a quantum-safe KMS (using ML-KEM + AES-256) for new archival encryption today.
   All sessions recorded after migration are automatically HNDL-safe.

2. Begin Tier 1 re-encryption immediately. Prioritise sessions involving authentication
   tokens, payment data, or privileged API access.

3. Audit backup and cold storage systems: the archive likely exists in multiple copies.
   All copies must be migrated or deleted.

4. Document the migration timeline and retain evidence of quantum-safe re-encryption
   for compliance purposes (HIPAA, PCI-DSS, GDPR incident response requirements).

**What cannot be fixed:** Sessions that were already exfiltrated by an adversary and are
stored outside the company's infrastructure cannot be re-encrypted. The priority is to
ensure that the company's own controlled copies are migrated before a CRQC becomes
available.
