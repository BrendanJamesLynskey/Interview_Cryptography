# Authentication Protocols

## Prerequisites
- Hash functions: SHA-256, HMAC, PBKDF2
- Public-key cryptography: ECDSA, RSA signatures
- Elliptic curves: P-256, X25519
- Basic understanding of TLS and PKI

---

## Concept Reference

### Categories of Authentication

Authentication answers the question: **who is this entity and can they prove it?**

Three fundamental factors exist:
- **Something you know:** password, PIN, recovery phrase
- **Something you have:** hardware token, smart card, FIDO2 authenticator, phone (TOTP)
- **Something you are:** biometric (fingerprint, face)

Multi-factor authentication (MFA) requires at least two factors from different categories.
A password plus TOTP code from the same phone is technically two-factor but the "have"
factor provides weak protection if the phone is compromised.

---

### Challenge-Response Authentication

Challenge-response is the fundamental pattern for proving knowledge of a secret without
transmitting the secret itself.

**Symmetric challenge-response (HMAC-based):**

```
Verifier generates:  challenge c  (random nonce, >= 128 bits)
Verifier sends c to claimant

Claimant computes:   response r = HMAC-SHA256(K, c)
Claimant sends r

Verifier computes:   expected = HMAC-SHA256(K, c)
Verifier checks:     r == expected (constant-time comparison)
```

Both sides share a symmetric key $K$. The verifier holds the key and verifies responses.

**Why random challenges matter:** A static challenge allows an attacker to pre-compute the
response. A random 128-bit challenge ensures each authentication produces a unique response;
an attacker who intercepts a response cannot replay it because the next challenge will be
different.

**Asymmetric challenge-response (signature-based):**

```
Verifier generates:  challenge c  (random nonce)
Verifier sends c

Claimant computes:   signature s = Sign(private_key, c || context)
Claimant sends s

Verifier checks:     Verify(public_key, c || context, s) == true
```

The claimant proves possession of the private key without revealing it. SSH public-key
authentication uses this pattern: the server sends a random challenge; the client signs it
with its private key; the server verifies the signature using the public key stored in
`~/.ssh/authorized_keys`.

**Context binding:** Signing only the raw challenge $c$ is dangerous — the signature could
be replayed in a different protocol. Binding the signature to a protocol identifier, session
ID, or application context (as in TLS `CertificateVerify` and FIDO2) prevents cross-protocol
signature reuse.

---

### Password Hashing: Why Simple Hashing Fails

Storing passwords as `SHA-256(password)` is insecure because:

1. **Rainbow tables:** Pre-computed hash-to-password tables can recover SHA-256(common_word)
   in microseconds regardless of hardware.
2. **Speed:** SHA-256 runs at >2 GB/s on modern GPUs, enabling billions of guesses per
   second for offline attacks against stolen hash databases.
3. **No salting:** Two users with the same password have the same hash, revealing the
   coincidence.

**Salt:** A per-user random value stored alongside the hash:
```
stored = salt || Hash(password || salt)
```
Salting defeats rainbow tables and forces per-user brute-force, but SHA-256 is still too
fast for an attacker with a GPU cluster.

---

### Argon2: Modern Password Hashing

Argon2 won the Password Hashing Competition in 2015 and is the current recommendation
(RFC 9106). It is designed to be:
- **Memory-hard:** Requires large amounts of RAM that cannot be efficiently parallelised on
  GPUs or ASICs without the full memory footprint
- **Configurable:** Tunable cost parameters allow operators to keep authentication time
  constant as hardware improves

**Three variants:**
- **Argon2d:** Data-dependent memory access; fastest; NOT suitable where side-channel
  attacks (cache timing) are a concern — use for cryptocurrency KDF where no side-channel
  attacker is present
- **Argon2i:** Data-independent memory access; side-channel resistant; 20-30% slower
- **Argon2id:** Hybrid — first pass uses Argon2i, remaining passes use Argon2d; recommended
  for password hashing and key derivation in interactive applications

**Parameters:**
```
Argon2id(password, salt, t, m, p) -> hash

  t  = time cost (number of iterations; increases CPU time linearly)
  m  = memory cost in KiB (2^k KiB; increases RAM requirement)
  p  = parallelism degree (number of independent lanes)
  salt: >= 16 random bytes, unique per password
  output length: typically 32 bytes
```

**Recommended minimum parameters (RFC 9106, 2021):**
```
Interactive login (< 1 second target):   t=1, m=64 MiB, p=4
Sensitive offline KDF (3 seconds OK):    t=1, m=256 MiB, p=4
High-security offline:                   t=1, m=4 GiB,   p=4
```

**Why memory hardness defeats GPU/ASIC attacks:** A GPU has thousands of cores but shared
memory bandwidth is its bottleneck. If each Argon2id computation requires 64 MiB of RAM,
running 1000 parallel guesses requires 64 GB of GPU VRAM — well beyond typical hardware.
An ASIC cannot remove the memory requirement without fundamentally redesigning the algorithm.

**Alternatives (acceptable but less preferred):**
- **bcrypt:** Memory cost is fixed at 4 KiB — too small for modern hardware; vulnerable to
  FPGA acceleration. Maximum password length is 72 bytes (bcrypt truncates silently).
- **scrypt (RFC 7914):** Memory-hard predecessor of Argon2; the parameter interaction is
  more complex; Argon2id is preferred for new designs.
- **PBKDF2 (RFC 2898):** Not memory-hard; purely CPU-bound; vulnerable to GPU attacks.
  Required in some FIPS 140 environments where Argon2 is not yet approved.

---

### Time-Based One-Time Passwords (TOTP)

TOTP (RFC 6238) generates a 6-digit code from a shared secret and the current time:

```
T = floor(unix_timestamp / time_step)    -- typically time_step = 30 seconds
TOTP = HOTP(K, T)
HOTP(K, C) = truncate(HMAC-SHA1(K, C))  -- RFC 4226
           = (HMAC[offset..offset+3] & 0x7FFFFFFF) mod 10^6
```

**Properties:**
- Both sides hold the same shared secret $K$ (a 160-bit random key encoded as Base32 in a
  QR code)
- Time step of 30 seconds allows for clock drift of ±30 seconds (servers check T-1, T, T+1)
- The 6-digit code changes every 30 seconds; a captured code is valid for at most 90 seconds
- Server should mark used codes as consumed within their validity window to prevent replay
  within the same time step

**Weaknesses:**
- Phishable: an attacker who proxies an authentication request can use the TOTP code
  in real time before it expires (TOTP provides no origin binding)
- Shared secret must be stored on the server and the user's device — server-side breach
  exposes all TOTP seeds
- SIM-swapping attacks can compromise SMS-based OTP (separate from TOTP but commonly
  confused)

---

### FIDO2 / WebAuthn

FIDO2 is the combination of the W3C **WebAuthn API** (browser-level interface) and the
CTAP2 protocol (communication between browser and a hardware authenticator). It provides
**phishing-resistant MFA** using public-key cryptography.

**Core properties:**
- **Origin binding:** The signature is bound to the exact origin (scheme + hostname + port)
  of the requesting website. A phishing site at `bank-1ogin.com` receives a signature
  bound to that origin, which the legitimate `bank.com` will reject.
- **No shared secret:** The server stores only the user's public key. A server breach
  exposes no usable credential material.
- **No password:** The authenticator provides a second factor (or, in Passkeys, the sole
  factor) using a device-generated key pair.

**Registration flow:**

```
1. Server generates registration challenge c (random, 16+ bytes)
2. Browser calls navigator.credentials.create({publicKey: options})
3. Authenticator (hardware key or platform authenticator):
   a. User verifies presence (touch sensor or biometric)
   b. Generates ECDSA P-256 key pair (credentialId -> private key, stored on device)
   c. Creates attestation object:
      attestedCredentialData = AAGUID || credentialId || publicKey
      authData = rpIdHash || flags || signCount || attestedCredentialData
      attestationStatement = Attest_Key_Sign(authData || clientDataHash)
4. Browser sends attestation to server
5. Server verifies attestation, stores publicKey and credentialId for this user
```

**Authentication flow:**

```
1. Server generates authentication challenge c (random, 16+ bytes)
2. Browser calls navigator.credentials.get({publicKey: options})
3. Authenticator:
   a. User verifies presence
   b. Looks up key pair by credentialId
   c. Increments sign counter (detects cloned authenticators)
   d. Signs: signature = ECDSA_Sign(private_key, authData || clientDataHash)
      clientDataHash = SHA-256({"type":"webauthn.get",
                                "challenge": base64url(c),
                                "origin": "https://bank.com"})
4. Browser sends authData + signature to server
5. Server verifies:
   - rpIdHash = SHA-256("bank.com") (origin binding check)
   - signature verifies under stored public key
   - signCount > previously stored signCount (clone detection)
   - challenge matches issued challenge (replay prevention)
```

**Why FIDO2 is phishing-resistant:** The `clientDataHash` includes `"origin": "https://bank.com"`.
If the user is on `https://bank-1ogin.com`, the origin in the signature will be
`https://bank-1ogin.com`, which the legitimate server rejects during verification. An
attacker who intercepts the authentication attempt in real time cannot strip the origin
binding without invalidating the signature.

**Passkeys:** Resident credentials stored in the device's secure enclave or a password
manager (iCloud Keychain, Google Password Manager). The key pair is synced across a user's
devices via end-to-end encrypted backup. Passkeys allow passwordless authentication with
phishing resistance and account recovery across device loss.

---

## Tier 1 — Fundamentals

### Question F1
**Explain challenge-response authentication. Why does the server send a random challenge
rather than asking the client to hash their password?**

**Answer:**

In challenge-response, the server sends a fresh random nonce (the challenge) to the client.
The client proves knowledge of a shared secret by computing a response derived from both
the challenge and the secret — for example, `response = HMAC(K, challenge)`. The server
computes the expected response and compares.

**Why not hash the password directly:**

Sending `Hash(password)` over the wire makes the hash equivalent to the password — an
attacker who intercepts it can replay it in future authentications. It also exposes the
hash to offline dictionary attacks.

**Why the challenge must be random:**

If the challenge were static (always the same value), an attacker could pre-compute the
valid response `HMAC(K, fixed_challenge)` from a dictionary of common passwords, or simply
record and replay a valid response seen in a previous authentication.

A fresh random challenge ensures each response is valid for exactly one authentication
attempt. An intercepted response from session $i$ is worthless for session $i+1$ because
the challenge will be different.

---

### Question F2
**Why is MD5 or SHA-256 alone unsuitable for storing passwords, and what properties should
a password-hashing function have?**

**Answer:**

SHA-256 alone fails for password storage for three reasons:

1. **No salt:** Two users with identical passwords produce identical hashes, revealing the
   coincidence to an attacker who reads the database. Rainbow table precomputation can
   recover common passwords instantly.

2. **Speed:** SHA-256 runs at multi-GB/s on consumer hardware. An attacker can test
   billions of candidate passwords per second against a stolen hash, exhausting all
   lowercase-letter passwords of length <= 8 in minutes.

3. **No memory hardness:** Specialised hardware (GPU clusters, ASICs) can parallelise
   SHA-256 hashing at near-zero marginal cost per guess.

A proper password-hashing function should be:
- **Salted:** Per-user random salt (>= 16 bytes) stored alongside the hash
- **Slow:** Deliberately expensive in CPU time, calibrated to take 100-500ms on a login server
- **Memory-hard:** Require large amounts of RAM to resist GPU and ASIC parallelisation
- **Configurable:** Tunable cost parameters so the function can be made harder as hardware
  improves without changing the algorithm

Argon2id satisfies all four requirements. bcrypt provides the first two but not memory
hardness. PBKDF2 provides only the first two at adjustable iteration count.

---

### Question F3
**What is FIDO2 and how does it differ from TOTP as a second factor?**

**Answer:**

Both FIDO2 and TOTP are second-factor authentication mechanisms, but they differ
significantly in security properties:

| Property | TOTP | FIDO2 |
|---|---|---|
| Underlying mechanism | Shared secret + time-based HMAC | Public-key signature |
| Server stores | Shared secret (TOTP seed) | Public key only |
| Phishing resistance | None — code can be proxied in real time | Yes — signature is origin-bound |
| Replay window | Up to 90 seconds | None — challenge is one-use |
| Server breach impact | All TOTP seeds exposed; accounts compromised | Public keys only; no account compromise |
| Physical requirement | None (code visible on screen) | User presence (touch or biometric) |

**FIDO2** binds authentication to the exact origin (domain) of the requesting site. A
phishing page at `bank-1ogin.com` cannot use the user's FIDO2 credential for `bank.com`
because the origin is embedded in the signed data. TOTP codes have no such binding; a
real-time phishing proxy can extract and immediately use a TOTP code.

---

### Question F4
**What parameters does Argon2id take and what does each control?**

**Answer:**

Argon2id takes five parameters:

| Parameter | Name | Effect |
|---|---|---|
| `password` | Secret input | The credential to be hashed |
| `salt` | Per-user random value (>= 16 bytes) | Prevents rainbow tables; must be unique per user |
| `t` | Time cost (iterations) | Number of passes over memory; increases CPU time linearly |
| `m` | Memory cost (KiB) | Amount of RAM required; memory-hardness against GPU attacks |
| `p` | Parallelism | Number of independent lanes; can use multi-core but also allows attacker to parallelise |

**RFC 9106 recommended parameters for interactive login:**
```
t = 1,  m = 65536 (64 MiB),  p = 4
```

Increasing `m` is the most effective defence against GPU attacks. Increasing `t` adds CPU
cost without adding memory cost — useful for scenarios where RAM is limited. A 64 MiB
per-attempt memory requirement limits GPU parallelism to ~1000 simultaneous guesses on a
64 GB GPU, compared to millions for SHA-256.

---

## Tier 2 — Intermediate

### Question I1
**Describe the FIDO2 authentication flow in detail. How does origin binding prevent
phishing, and how does the sign counter detect cloned authenticators?**

**Answer:**

**Authentication flow (server perspective):**

```
1. Server issues:   challenge c (random, 16+ bytes), relying party ID = "bank.com"
2. Client computes: clientDataHash = SHA-256(JSON{type, challenge, origin})
3. Authenticator:   authData = SHA-256("bank.com") || flags || signCount || credentialId
                    assertion = Sign(private_key, authData || clientDataHash)
4. Server verifies:
   a. SHA-256("bank.com") == rpIdHash in authData  [origin binding]
   b. assertion verifies under stored publicKey     [possession proof]
   c. signCount > stored signCount                 [clone detection]
   d. challenge matches issued c and is not reused [replay prevention]
```

**How origin binding prevents phishing:**

The `clientDataHash` includes `"origin": "https://bank.com"`. This value is set by the
browser — not the page — based on the actual URL the user is visiting. If a phishing page
at `https://bank-1ogin.com` invokes the FIDO2 API, the browser puts `https://bank-1ogin.com`
in the origin field. The signature is then bound to the phishing origin.

When the phishing attacker forwards the assertion to the real `bank.com` server, step (a)
fails: the rpIdHash in authData would need to be `SHA-256("bank-1ogin.com")`, not
`SHA-256("bank.com")`. The server rejects it.

Even if the attacker intercepts in real time, they cannot modify the signed data without
invalidating the signature.

**Sign counter and clone detection:**

Each time the authenticator signs, it increments an internal monotonic counter. The server
stores the last observed counter value. On each authentication:
- If `new_signCount > stored_signCount`: normal — accept and update
- If `new_signCount <= stored_signCount`: the authenticator may be cloned or the signing
  state was rolled back — the server should alert the user and may reject authentication

Hardware authenticators store sign counters in non-volatile memory. Platform authenticators
(Windows Hello, Face ID) may return a counter of 0 if they use device-scoped keys that
cannot be synced, indicating clone detection is not applicable for that credential.

---

### Question I2
**Compare PBKDF2, bcrypt, scrypt, and Argon2id for server-side password storage. For
each, identify its key weakness and the attack it fails to prevent.**

**Answer:**

| Algorithm | Key weakness | Fails to prevent |
|---|---|---|
| PBKDF2 | Not memory-hard; purely CPU-bound | GPU/ASIC parallel brute-force. A modern GPU testing PBKDF2-HMAC-SHA256 with 100k iterations can still test ~1 million passwords/second per GPU |
| bcrypt | Memory cost fixed at 4 KiB — far too small | FPGA-accelerated attacks. FPGAs can implement bcrypt cheaply with 4 KiB scratchpad per core; hardware costing ~$10k can test ~1 billion bcrypt-cost-10 hashes/day |
| scrypt | Parameter interaction is complex; CPU/memory tradeoff can be misconfigured | If `N` is set low to save RAM, it degrades to near-PBKDF2 performance; incorrect `r,p` parameters can eliminate memory hardness entirely |
| Argon2id | Newer; may not be available in FIPS 140 validated libraries | In constrained environments (smart cards, embedded), the memory requirement (minimum 64 MiB) may be infeasible |

**Argon2id is the current recommendation** because:
- Its memory-hardness is well-defined and not dependent on parameter interaction
- It resists both side-channel attacks (first pass uses Argon2i, data-independent) and
  GPU attacks (subsequent passes use Argon2d, GPU-unfriendly)
- RFC 9106 provides clear parameter guidance

**bcrypt vs. Argon2id:** bcrypt is widely deployed and still provides reasonable protection
when the cost factor is set to 12+ (>100ms on modern hardware). Argon2id is strictly
better; any new system should use Argon2id. Migrating existing bcrypt deployments requires
re-hashing passwords on next login.

---

### Question I3
**An authentication system uses HMAC-SHA256 challenge-response with a 128-bit shared key.
An attacker intercepts 10,000 challenge-response pairs from different sessions. What attacks
can they mount, and what is the practical security level?**

**Answer:**

**Attack 1 — Offline forgery via HMAC brute-force:**

The attacker has pairs $(c_1, r_1), \ldots, (c_{10000}, r_{10000})$ where
$r_i = \text{HMAC-SHA256}(K, c_i)$. To forge a new response, they must recover $K$ or
find a collision.

With a 128-bit key:
- Brute-force requires $2^{128}$ HMAC evaluations on average — computationally infeasible
  regardless of the number of observed pairs (each pair adds no constraint that reduces
  the keyspace)
- HMAC-SHA256 with a 128-bit key has no known shortcut attacks; the security is limited by
  the HMAC security proof to approximately 128 bits minus $O(\log q)$ bits for $q$ queries

**Attack 2 — Replay within a session:**

If sessions are independent (new challenge per authentication), none of the 10,000
responses can be replayed because each was bound to a unique challenge. Replay attacks
are prevented by the fresh-challenge requirement.

**Attack 3 — Timing side-channel in verification:**

If the server compares `r == expected` using a non-constant-time comparison (e.g., early
exit on first differing byte), an attacker can determine how many leading bytes of their
forged response are correct and iterate byte by byte, recovering a valid response in
$256 \times 32 = 8192$ attempts. This is why HMAC comparison must use constant-time
comparison (e.g., `hmac.compare_digest()` in Python, `CRYPTO_memcmp()` in OpenSSL).

**Practical security level:**

Against a computationally bounded attacker:
- Brute-force: 128-bit key, infeasible
- Replay: prevented by fresh challenges
- Forgery without key: HMAC security, infeasible

The system is secure against passive attackers. Active attackers who can inject challenges
and observe responses still cannot recover $K$ without brute-forcing it. The primary risk
is key storage (the shared key must be protected at rest on both client and server).

---

## Tier 3 — Advanced

### Question A1
**Describe the full security model of FIDO2 Passkeys, including the threat model it
addresses, the threats it does not address, and the specific risks introduced by
credential synchronisation across devices.**

**Answer:**

**Threat model addressed by Passkeys:**

Passkeys use ECDSA P-256 (or EdDSA) with origin-bound challenge-response, providing:

1. **Phishing resistance:** Signatures are bound to the relying party's origin via
   `clientDataHash`. A phishing site cannot obtain a valid assertion for the legitimate
   site.

2. **Password breach resistance:** The server stores only the public key; no password or
   shared secret is exposed in a server breach.

3. **Credential stuffing resistance:** Credentials are site-specific; a passkey for
   `bank.com` cannot be used on `shopping.com`, even if both are controlled by an attacker.

4. **Replay prevention:** The server issues a fresh random challenge per authentication;
   each signed assertion is bound to that one-use challenge.

5. **Man-in-the-middle resistance:** The origin binding means a real-time MitM proxy
   cannot forward a FIDO2 assertion to the legitimate server — the origin in the signed
   data will reveal the MitM's domain.

**Threats Passkeys do not address:**

1. **Compromised device:** If the device's secure enclave or OS is compromised, the
   attacker can trigger authentication directly (sign arbitrary challenges using the stored
   key without user interaction beyond the local verification bypass).

2. **Account recovery bypass:** Many relying parties still offer email/SMS-based account
   recovery as a fallback, which attackers can target when Passkeys authentication is too
   hard to attack directly.

3. **Denial of service:** An attacker who deletes the passkey (or the sync provider account)
   can lock the user out if no backup authentication method exists.

**Risks from credential synchronisation (iCloud Keychain, Google Password Manager):**

Passkeys stored in a cloud-backed keychain are synced end-to-end encrypted across the
user's devices. This introduces:

1. **Sync account compromise:** If an attacker gains access to the user's Apple ID or
   Google account, they may be able to restore the passkey to their own device, bypassing
   the physical-presence requirement. The sync provider's account security becomes part
   of the authentication security.

2. **Device unlock credential as root of trust:** The sync account is protected by the
   device's biometric or PIN. A weak PIN (e.g., 6 digits) becomes the weakest link.

3. **Cross-device coherence vs. security:** A passkey synced to five devices means
   compromise of any one device potentially exposes the credential. This is the opposite
   of hardware FIDO2 tokens (e.g., YubiKey), which are non-exportable.

4. **Attestation weakening:** Hardware authenticators provide attestation that the key is
   stored in a certified secure element with specific properties. Platform passkeys
   synced via cloud keychains typically provide weaker attestation — the server may not
   be able to verify that the key is hardware-bound on a specific device.

**Enterprise recommendation:** For high-assurance scenarios (privileged access, financial
transactions), use non-synced, hardware-bound FIDO2 credentials (YubiKey or platform
attestation with `userVerification = required` and `attestation = direct`). Synced
passkeys are appropriate for consumer authentication where the improvement over passwords
is the primary goal.

---

### Question A2
**Design an authentication protocol for a high-security API where the client is a
server-side service (not a human), the connection crosses an untrusted network, and
the protocol must provide mutual authentication and forward secrecy for all API calls.
Justify each design choice.**

**Answer:**

**Requirements:**
- Machine-to-machine (no human interaction)
- Mutual authentication (server authenticates client and client authenticates server)
- Forward secrecy (compromise of long-term keys does not expose past sessions)
- Operate over an untrusted network

**Recommended design: mTLS (mutual TLS) with short-lived client certificates**

**Layer 1 — Transport: TLS 1.3 with ECDHE**

TLS 1.3 with X25519 key exchange provides:
- Forward secrecy: ephemeral keys are discarded after each session
- Cipher suites: `TLS_AES_256_GCM_SHA384` for 256-bit security
- No static RSA key exchange; all key agreement is ephemeral

**Layer 2 — Server authentication:**

Standard TLS certificate authentication. The client verifies the server's certificate
chain against a pinned intermediate CA certificate (not a public root) to prevent
certificates issued by other CAs from being accepted. This mitigates rogue-CA attacks
without the fragility of leaf-pinning.

**Layer 3 — Client authentication: mTLS with short-lived certificates**

Rather than pre-shared keys or long-lived client certificates:

```
- Client service has a long-term identity key pair (stored in HSM or KMS)
- An internal CA (SPIFFE/SPIRE, or HashiCorp Vault PKI) issues short-lived
  client certificates (validity: 1-24 hours) signed by the identity key
- Client presents this short-lived cert in the TLS ClientCertificate message
- Server verifies the certificate is signed by the internal CA
- Short validity means revocation infrastructure is not critical:
  certificates expire before a revocation check is needed
```

**Why not pre-shared keys (PSK):**
- PSKs must be distributed and stored on both sides; if either side is compromised, the
  PSK is exposed and all past and future sessions using it are at risk
- PSK rotation requires coordination; automated rotation is complex
- PSKs provide no forward secrecy (the PSK itself is a long-term secret)

**Why not long-lived client certificates:**
- A long-lived certificate associated with a compromised service account remains valid
  until it expires — potentially months
- Short-lived certs (1-24 hours) bound to a SPIFFE identity eliminate this window without
  requiring a revocation infrastructure

**Layer 4 — Request-level authentication (defence in depth):**

For the most sensitive endpoints, add a request signature in an HTTP Authorization header:

```
Authorization: Bearer <JWT signed with client's private key>
JWT claims: {sub: "service-name", aud: "api.server.com",
             iat: now, exp: now+60, jti: random-uuid}
```

The JWT `jti` claim (JWT ID) is a random UUID stored by the server as a one-time-use nonce,
preventing replay within the JWT's validity window. The short `exp` (60 seconds) limits
replay window even without a nonce store.

**Summary:**

```
Threat                        Mitigation
---------------------------   ------------------------------------------
Server impersonation          TLS certificate, pinned to internal CA
Client impersonation          mTLS with short-lived SPIFFE certificate
Replay of captured requests   JWT with jti nonce + short expiry
Long-term key compromise      Short-lived certs; ephemeral TLS keys
Traffic decryption (passive)  TLS 1.3 ECDHE forward secrecy
```
