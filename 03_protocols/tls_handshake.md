# TLS Handshake

## Prerequisites
- Public-key cryptography: RSA, ECDH, digital signatures
- Symmetric encryption: AES-GCM, ChaCha20-Poly1305
- Hash functions: SHA-256, SHA-384, HMAC
- Basic understanding of X.509 certificates and PKI

---

## Concept Reference

### Why TLS 1.3 Is a Clean Redesign

TLS 1.2 accumulated 20 years of legacy cipher suites, optional features, and negotiation flexibility. That flexibility became a vulnerability surface: POODLE, BEAST, CRIME, and FREAK all exploited the ability to negotiate weaker parameters. TLS 1.3 (RFC 8446, 2018) eliminates this by:

- Removing all cipher suites with static RSA key exchange (forward secrecy is mandatory)
- Removing all CBC-mode cipher suites, export-grade ciphers, RC4, DES, and 3DES
- Reducing negotiated parameters to a minimal, well-defined set
- Cutting round-trips: full handshake is 1-RTT; resumption with early data is 0-RTT

### TLS 1.3 Cipher Suites

TLS 1.3 separates the record-layer cipher from the key-exchange and authentication mechanisms. A cipher suite specifies only the AEAD cipher and the hash function used in HKDF:

```
TLS_AES_128_GCM_SHA256       -- AES-128 in GCM mode, HKDF with SHA-256
TLS_AES_256_GCM_SHA384       -- AES-256 in GCM mode, HKDF with SHA-384
TLS_CHACHA20_POLY1305_SHA256 -- ChaCha20-Poly1305, HKDF with SHA-256
TLS_AES_128_CCM_SHA256       -- AES-128-CCM (IoT/constrained environments)
TLS_AES_128_CCM_8_SHA256     -- AES-128-CCM with 8-byte authentication tag
```

Key-exchange is handled by named groups (X25519, P-256, P-384, P-521, FFDHE groups), and authentication is determined by the certificate's signature algorithm. Both are separate from the cipher suite.

### 1-RTT Handshake: Step-by-Step

The 1-RTT handshake completes in one round-trip before the client can send application data.

```
Client                                          Server
  |                                               |
  |--- ClientHello -------------------------------->|
  |    + key_share (client ECDH public key)        |
  |    + supported_versions: TLS 1.3               |
  |    + supported_groups (X25519, P-256, ...)     |
  |    + signature_algorithms                      |
  |    + psk_key_exchange_modes (optional)         |
  |                                               |
  |<-- ServerHello --------------------------------|
  |    + key_share (server ECDH public key)        |
  |    + selected cipher suite                     |
  |                                               |
  |    [Both sides compute DHE shared secret]      |
  |    [Handshake keys derived here]               |
  |                                               |
  |<-- {EncryptedExtensions} --------------------|  encrypted with
  |<-- {CertificateRequest} (if needed) ---------|  server_handshake_
  |<-- {Certificate} ----------------------------|  traffic_secret
  |<-- {CertificateVerify} ----------------------|
  |<-- {Finished (server)} ----------------------|
  |                                               |
  |    [Application keys derived here]            |
  |                                               |
  |--- {Certificate} (if requested) ------------>|  encrypted with
  |--- {CertificateVerify} (if cert sent) ------>|  client_handshake_
  |--- {Finished (client)} ---------------------->|  traffic_secret
  |                                               |
  |<========= Application Data (1-RTT) ========>|
```

Key observations:
1. The client sends its ECDH key share in the very first message — no separate key-exchange step.
2. The server encrypts EncryptedExtensions, Certificate, CertificateVerify, and Finished using the handshake traffic key. The server's identity is not visible to a passive observer.
3. Application data flows immediately after the client sends Finished — no extra round trip.

### Key Schedule: HKDF-Based Derivation

TLS 1.3 uses a rigorous key derivation tree based on HKDF (RFC 5869). Every key is derived from a chain of HKDF-Extract and HKDF-Expand-Label operations.

```
HKDF-Extract(salt, IKM) = HMAC-Hash(salt, IKM)
    -- Produces a pseudorandom key (PRK) of Hash.length bytes

HKDF-Expand-Label(Secret, Label, Context, Length):
    HkdfLabel = Length || ("tls13 " + Label) || Context
    return HKDF-Expand(Secret, HkdfLabel, Length)

Derive-Secret(Secret, Label, Messages):
    return HKDF-Expand-Label(Secret, Label, Transcript-Hash(Messages), Hash.length)
```

The full key schedule (Hash = SHA-256, no PSK):

```
IKM = 0 (32 zero bytes)
salt = 0 (32 zero bytes)
         |
         v
     HKDF-Extract(salt=0, IKM=0)
         |
    Early Secret (ES)
         |
         +-- client_early_traffic_secret = Derive-Secret(ES, "c e traffic", CH)
         +-- early_exporter_master_secret = Derive-Secret(ES, "e exp master", CH)
         |
         v
    HKDF-Extract(salt=Derive-Secret(ES,"derived",""), IKM=DHE)
         |
    Handshake Secret (HS)
         |
         +-- client_handshake_traffic_secret = Derive-Secret(HS, "c hs traffic", CH+SH)
         +-- server_handshake_traffic_secret = Derive-Secret(HS, "s hs traffic", CH+SH)
         |
         v
    HKDF-Extract(salt=Derive-Secret(HS,"derived",""), IKM=0)
         |
    Master Secret (MS)
         |
         +-- client_application_traffic_secret = Derive-Secret(MS, "c ap traffic", CH..SF)
         +-- server_application_traffic_secret = Derive-Secret(MS, "s ap traffic", CH..SF)
         +-- exporter_master_secret            = Derive-Secret(MS, "exp master",   CH..SF)
         +-- resumption_master_secret          = Derive-Secret(MS, "res master",   CH..CF)
```

Where: CH=ClientHello, SH=ServerHello, SF=server Finished, CF=client Finished, DHE=ECDH shared secret.

Actual record keys and IVs are derived from the traffic secrets:
```
write_key = HKDF-Expand-Label(traffic_secret, "key", "", key_length)
write_iv  = HKDF-Expand-Label(traffic_secret, "iv",  "", iv_length)
```

### 0-RTT (Early Data)

0-RTT allows the client to send application data before the server responds, using a pre-shared key (PSK) established in a previous session.

```
Client                                          Server
  |                                               |
  |--- ClientHello -------------------------------->|
  |    + early_data extension                      |
  |    + psk extension (session ticket binder)     |
  |    + key_share (fresh ECDH key)                |
  |                                               |
  |--- [0-RTT Application Data] ----------------->|
  |    (encrypted with client_early_traffic_secret)|
  |                                               |
  |<-- ServerHello --------------------------------|
  |<-- {EncryptedExtensions} --------------------|
  |    + early_data (accepted or rejected)         |
  |<-- {Finished (server)} ----------------------|
  |                                               |
  |--- {EndOfEarlyData} ------------------------->|
  |--- {Finished (client)} ---------------------->|
  |                                               |
  |<========= 1-RTT Application Data ==========>|
```

Security properties and limitations of 0-RTT:
- **No forward secrecy for early data**: if the PSK is compromised, early data can be decrypted retrospectively
- **Replay attacks**: an attacker can replay the early data to a different server instance; servers MUST implement replay protection (nonce caching, single-use tickets, or accept only idempotent requests)
- **Application responsibility**: the application layer must mark which requests are safe to replay (idempotent reads, not writes or transactions)

---

## Tier 1 — Fundamentals

### Question F1
**What are the five TLS 1.3 cipher suites? What does each component of a suite specify, and what does it explicitly not specify?**

**Answer:**

The five TLS 1.3 cipher suites are:

```
TLS_AES_128_GCM_SHA256
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_CCM_SHA256
TLS_AES_128_CCM_8_SHA256
```

Each suite specifies exactly two things:
1. **The AEAD algorithm** for record-layer encryption (AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305, or AES-128-CCM). This encrypts application data and encrypted handshake messages.
2. **The hash algorithm** used with HKDF for the key schedule and Finished MAC (SHA-256 or SHA-384).

A TLS 1.3 cipher suite does NOT specify:
- The key-exchange algorithm (always ephemeral DH; the named group is negotiated separately via `supported_groups`)
- The authentication or signature algorithm (negotiated via `signature_algorithms` and determined by the certificate)

This separation means replacing an RSA certificate with an ECDSA certificate requires no change to the cipher suite. In TLS 1.2, suites like `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256` encoded the key exchange and authentication method inside the suite name, requiring a different suite for every combination.

**Common mistake:** Writing TLS 1.3 suite names in the TLS 1.2 `_WITH_` format. TLS 1.3 suites have shorter names and contain no key-exchange or authentication component.

---

### Question F2
**Describe the sequence of messages in a TLS 1.3 1-RTT handshake. Which messages are encrypted, and with which key material?**

**Answer:**

```
Message               Direction   Encrypted?   Key used
--------------------  ----------  ----------   --------------------------------
ClientHello           C -> S      No           (plaintext)
ServerHello           S -> C      No           (plaintext)
EncryptedExtensions   S -> C      Yes          server_handshake_traffic_secret
CertificateRequest    S -> C      Yes          server_handshake_traffic_secret
Certificate           S -> C      Yes          server_handshake_traffic_secret
CertificateVerify     S -> C      Yes          server_handshake_traffic_secret
Finished (server)     S -> C      Yes          server_handshake_traffic_secret
Certificate           C -> S      Yes          client_handshake_traffic_secret
CertificateVerify     C -> S      Yes          client_handshake_traffic_secret
Finished (client)     C -> S      Yes          client_handshake_traffic_secret
Application Data      both        Yes          application_traffic_secret
```

The handshake traffic secrets are derived from the ECDH shared secret (DHE) immediately after ServerHello. This means Certificate and CertificateVerify are transmitted encrypted — the server's identity is hidden from a passive network observer. In TLS 1.2, the Certificate was sent in plaintext, revealing the server's identity.

Both sides derive the same handshake traffic keys independently from their copy of the DHE shared secret and the transcript hash, without any additional round-trip.

---

### Question F3
**What is forward secrecy, and how does TLS 1.3 guarantee it for every connection?**

**Answer:**

Forward secrecy (also called perfect forward secrecy, PFS) is the property that compromise of a long-term key does not enable decryption of past recorded sessions.

In TLS 1.2 with static RSA key exchange, the client encrypted the pre-master secret directly with the server's RSA public key. An attacker who recorded traffic and later obtained the server's private RSA key could decrypt all recorded sessions — there is no forward secrecy.

TLS 1.3 guarantees forward secrecy because:

1. **Static RSA key exchange is completely removed.** No TLS 1.3 cipher suite allows the server's long-term key to encrypt session keying material.
2. **All key exchange uses ephemeral Diffie-Hellman.** The server generates a fresh ECDH key pair for every connection. The private key is discarded immediately after the shared secret DHE is computed.
3. **Session keys depend on the ephemeral DH secret.** The server's long-term private key is used only to sign the handshake transcript in CertificateVerify (authentication). Knowing the long-term key after the session ends tells an attacker nothing about the ephemeral DH private key that was already discarded.

Even complete server compromise after the fact does not enable decryption of previously recorded sessions.

---

### Question F4
**What is the Finished message in TLS 1.3? What does it contain, and what attack does it prevent?**

**Answer:**

The Finished message is a MAC over the complete handshake transcript, computed using the handshake traffic secret:

```
finished_key    = HKDF-Expand-Label(handshake_traffic_secret, "finished", "", Hash.length)
verify_data     = HMAC(finished_key, Transcript-Hash(all messages up to CertificateVerify))
```

It prevents **handshake tampering attacks**. Without Finished:
- An active man-in-the-middle could modify parameters in ClientHello (downgrade offered cipher suites or named groups) or ServerHello (select a weaker cipher suite than the server would have chosen)
- The client and server would complete the handshake believing they negotiated parameters they did not both agree to

Because Finished is a MAC over the entire transcript, any modification to any handshake message changes the transcript hash, produces a different expected verify_data, and causes the receiving side to abort with a `decrypt_error` alert.

Both sides send a Finished. The server's Finished authenticates the server's view of the transcript. The client verifies it before sending its own Finished and before accepting application data — only then is the handshake considered authenticated.

---

## Tier 2 — Intermediate

### Question I1
**Walk through the TLS 1.3 key schedule from the ECDH shared secret to the first application write key. Name every HKDF operation and the transcript bound to each step.**

**Answer:**

Given: ECDH shared secret `DHE` (32 bytes for X25519), no PSK.

**Step 1 — Early Secret:**
```
Early Secret = HKDF-Extract(salt=0^32, IKM=0^32)
```
Both inputs are zero because no PSK is present. This anchors the derivation tree.

**Step 2 — Salt for Handshake Secret:**
```
derived_hs = Derive-Secret(Early Secret, "derived", "")
           = HKDF-Expand-Label(Early Secret, "derived", SHA256(""), 32)
```
The empty string transcript hash SHA256("") is used since no messages have been bound yet.

**Step 3 — Handshake Secret:**
```
Handshake Secret = HKDF-Extract(salt=derived_hs, IKM=DHE)
```
This is where the ECDH shared secret first enters the schedule. HKDF-Extract "randomises" the potentially biased EC x-coordinate into a uniform 32-byte key.

**Step 4 — Handshake traffic secrets (transcript: ClientHello through ServerHello):**
```
server_handshake_traffic_secret =
    Derive-Secret(Handshake Secret, "s hs traffic", ClientHello || ServerHello)

client_handshake_traffic_secret =
    Derive-Secret(Handshake Secret, "c hs traffic", ClientHello || ServerHello)
```
"Transcript hash" means SHA-256 of the concatenated handshake messages.

**Step 5 — Handshake record keys (used to encrypt Certificate, CertificateVerify, Finished):**
```
server_write_key = HKDF-Expand-Label(server_handshake_traffic_secret, "key", "", 16)
server_write_iv  = HKDF-Expand-Label(server_handshake_traffic_secret, "iv",  "", 12)
```

**Step 6 — Salt for Master Secret:**
```
derived_ms    = Derive-Secret(Handshake Secret, "derived", "")
Master Secret = HKDF-Extract(salt=derived_ms, IKM=0^32)
```
IKM is zero here; all entropy has already been introduced via DHE.

**Step 7 — Application traffic secrets (transcript: ClientHello through server Finished):**
```
server_application_traffic_secret =
    Derive-Secret(Master Secret, "s ap traffic", ClientHello..server_Finished)

client_application_traffic_secret =
    Derive-Secret(Master Secret, "c ap traffic", ClientHello..server_Finished)
```

**Step 8 — Application record keys:**
```
server_write_key = HKDF-Expand-Label(server_application_traffic_secret, "key", "", 16)
server_write_iv  = HKDF-Expand-Label(server_application_traffic_secret, "iv",  "", 12)
```
(For AES-128-GCM: key=16 bytes, IV=12 bytes.)

The transcript binding at each step ensures keys are unique to this specific session's negotiated parameters. Any tampering with the transcript changes the derived secrets and causes Finished verification to fail.

---

### Question I2
**What is a HelloRetryRequest, and under what circumstances does a TLS 1.3 server send one? How is it distinguished from a regular ServerHello?**

**Answer:**

A HelloRetryRequest (HRR) is a special ServerHello whose `random` field is set to the specific constant:

```
SHA-256("HelloRetryRequest") =
  CF 21 AD 74 E5 9A 61 11 BE 1D 8C 02 1E 65 B8 91
  C2 A2 11 16 7A BB 8C 5E 07 9E 09 E2 C8 A8 33 9C
```

A server sends an HRR when it cannot proceed with the ECDH key shares offered in ClientHello:

- **Key share mismatch:** The client offered a key share for group X (e.g., P-256) but the server prefers group Y (e.g., X25519). The HRR specifies the preferred group, and the client re-sends ClientHello with a fresh key share for that group.
- **No key share offered:** The client sent no key shares at all (possible when the client has no prediction of server preference).

The HRR adds one extra round trip (the handshake becomes 2-RTT). To minimise this, clients typically include a key share for X25519 by default, since it is supported by almost all modern servers.

**Transcript handling after HRR:** When computing transcript hashes following an HRR, the original ClientHello is replaced by a special synthetic `message_hash` record containing only `Hash(ClientHello)`. This prevents the transcript from growing unboundedly when the client sends large key shares for many groups.

**Distinguished from real ServerHello:** A TLS 1.3 client MUST check the `random` field of any ServerHello for the HRR sentinel. The message type byte alone (0x02) does not distinguish them. Without this check, a downgrade or confusion attack could cause a client to misinterpret a retried handshake.

---

### Question I3
**Explain how TLS 1.3 prevents version downgrade attacks to TLS 1.2 or earlier.**

**Answer:**

TLS 1.3 uses two complementary mechanisms:

**Mechanism 1 — Finished MAC over the complete transcript:**

Both Finished messages authenticate the complete transcript of the handshake, including ClientHello and ServerHello. An active attacker who strips TLS 1.3 support from ClientHello (removing the `supported_versions` extension or the `key_share` extension) produces a different transcript. The Finished derived from the modified transcript will not match what the legitimate server computes, and verification fails.

**Mechanism 2 — Downgrade sentinel in ServerHello.random:**

When a TLS 1.3-capable server is forced to negotiate TLS 1.2 (because an intermediary modified the ClientHello), RFC 8446 requires the server to embed one of two sentinel values in the last 8 bytes of `ServerHello.random`:

```
Server negotiates TLS 1.2: random[24..31] = 44 4F 57 4E 47 52 44 01  ("DOWNGRD\x01")
Server negotiates TLS 1.1: random[24..31] = 44 4F 57 4E 47 52 44 00  ("DOWNGRD\x00")
```

A TLS 1.3-capable client receiving a TLS 1.2 ServerHello MUST inspect these bytes. If the sentinel is present, the client knows a downgrade occurred and MUST abort unless it truly does not support TLS 1.3.

**Why both mechanisms are needed:** The Finished MAC detects tampering but only at the end of the handshake, after the client may have sent sensitive data in later handshake messages. The sentinel provides early detection — the client can abort at the ServerHello stage before committing to the weaker handshake.

---

### Question I4
**Describe the security properties and limitations of TLS 1.3 0-RTT early data. What categories of applications should and should not use it?**

**Answer:**

**What 0-RTT provides:**
- Zero additional latency for repeat clients to established servers
- Encryption of early data under `client_early_traffic_secret` (derived from the PSK)
- The concurrent fresh ECDH key share ensures that the full 1-RTT handshake retains forward secrecy for all data sent after the ServerHello

**Limitation 1 — No forward secrecy for early data:**
`client_early_traffic_secret` is derived from the PSK (session ticket) and the ClientHello transcript, but NOT from any DHE secret. If the server's session-ticket encryption key is later compromised, all early data encrypted under tickets created with that key can be retrospectively decrypted.

**Limitation 2 — Replay attacks:**
An attacker who captures the ClientHello and early data segment can replay it: deliver it to the same server again, or to a different instance of the server (e.g., another node behind a load balancer). There is no nonce or counter in the early data itself that the server can use to detect a replay.

TLS 1.3 permits servers to implement optional replay protection:
- Single-use session tickets (the ticket is invalidated on first use)
- A server-maintained nonce/bloom-filter cache, keyed by the ClientHello random

**Appropriate use — safe:**
- HTTP GET requests for public, cacheable resources
- Read-only queries with no state change
- Contexts where idempotency is guaranteed and re-execution has no side effects

**Inappropriate use — unsafe:**
- Financial transactions, purchases, or any state-changing operation
- Authentication tokens or session establishment
- Any request where replaying it a second time causes harm

The HTTP/2 specification explicitly restricts 0-RTT to safe HTTP methods (GET, HEAD, OPTIONS) and requires servers to handle the potential for replay at the application layer.

---

## Tier 3 — Advanced

### Question A1
**A TLS 1.3 server farm has 20 load-balanced instances. Describe all the problems this creates for session resumption and 0-RTT, and propose concrete, deployable solutions for each.**

**Answer:**

**Problem 1 — Session ticket key distribution:**

Each instance needs the same ticket encryption key to decrypt tickets issued by other instances. If instances generate independent keys, a client that connects to instance A and then instance B will fail resumption and fall back to a full handshake.

Solution:
- Distribute a shared AES-256 key (for ticket encryption) and HMAC key (for ticket authentication) to all instances via a centralised key management service (e.g., HashiCorp Vault, AWS Secrets Manager)
- Rotate keys on a schedule (e.g., every 24 hours). Maintain a key ring of N=3 keys: one current (used for issuance), two previous (accepted for decryption). Retire a key after `ticket_lifetime` has passed since its last issuance
- Stateless ticket format: the ticket contains the session state (resumption_master_secret, cipher suite, timestamp, client identity) encrypted and authenticated with the shared key — no server-side session store required

**Problem 2 — 0-RTT replay protection across instances:**

A client sending 0-RTT to the load balancer may have its second (replayed) request routed to a different instance than the first. Per-instance replay caches do not protect against cross-instance replays.

Solution options (ranked by security vs. complexity):

Option A — Reject 0-RTT entirely. Safest approach for high-security deployments. Eliminates the attack surface at the cost of one RTT latency for returning clients.

Option B — Accept 0-RTT only for safe (idempotent) HTTP methods. Document the replay risk and enforce at the application layer. Suitable for content delivery.

Option C — Centralised nonce store (Redis/Memcached). Each 0-RTT ClientHello carries a unique PSK nonce; the server atomically checks and inserts the nonce into the shared store before accepting early data. Latency: one network round-trip to the nonce store per 0-RTT handshake. Risk: the nonce store becomes a single point of failure.

Option D — Single-use tickets with token binding. Issue single-use session tickets; the ticket identifier is inserted into the shared store on issuance and deleted on first use. Prevents replays but requires a distributed atomic delete.

**Problem 3 — Ticket key rotation during active connections:**

When the ticket key is rotated, outstanding tickets encrypted with the old key become undecryptable if all instances immediately switch to the new key.

Solution: Implement a two-phase rotation:
1. Phase 1 (hours 0-1): new key distributed; all instances accept both old and new tickets, but issue only new
2. Phase 2 (after ticket_lifetime): old key retired; all instances accept only new tickets
The total overlap window equals the ticket lifetime (typically 7 days, though shorter is more secure).

**Problem 4 — Clock synchronisation for ticket validity:**

Tickets include a timestamp and the server checks `ticket_age_add` against the session ticket lifetime. If instance clocks drift significantly, a valid ticket may be rejected as expired or accepted past its validity window.

Solution: Use NTP or PTP across all instances with a tolerance of ±30 seconds. Set ticket lifetime conservatively to account for clock drift.

---

### Question A2
**Compare the TLS 1.3 HKDF-based key schedule against a naive approach of hashing together the DHE secret and random nonces. What specific attacks does the structured schedule prevent?**

**Answer:**

A naive approach might derive session keys as:
```
master_key = SHA-256(DHE || client_random || server_random)
write_key  = SHA-256(master_key || "key")
write_iv   = SHA-256(master_key || "iv")
```

**Attack 1 — Length extension (Merkle-Damgard hash weakness):**

SHA-256 without HMAC is vulnerable to length extension: given `H(m)`, an attacker can compute `H(m || pad || extra)` without knowing `m`. A naive `SHA-256(DHE || ...)` key derivation could allow an attacker knowing one derived key to forge related keys. HKDF uses HMAC internally, which is immune to length extension because the key is mixed at both the inner and outer padding levels.

**Attack 2 — Poor extraction from biased input:**

A raw EC x-coordinate (the DHE output for P-256 or X25519) is not uniformly distributed over all 32-byte strings — it is a field element with specific statistical properties. Using it directly as a key without extraction could subtly weaken HMAC-based derivations. `HKDF-Extract` converts non-uniform IKM into a pseudorandom PRK indistinguishable from random, regardless of the input distribution, provided HMAC security holds.

**Attack 3 — Cross-context key reuse:**

A naive scheme produces a single master key and derives traffic keys, IV, and Finished MACs from it by appending different labels. If any two labels collide or if the derivation function is not a PRF, keys for different purposes could be correlated. HKDF-Expand-Label uses distinct label strings ("key", "iv", "finished", "c ap traffic", etc.) as part of the HMAC input, providing formal domain separation. Each output is computationally independent of all others given PRF security of HMAC.

**Attack 4 — Transcript forgery:**

A naive scheme that derives keys from `DHE || client_random || server_random` but not from the full transcript allows an active attacker to modify cipher suite selection, extensions, or server certificate details without changing the derived keys. The session keys would be the same regardless of which cipher suite was negotiated or whether a weak named group was selected. TLS 1.3 binds each Derive-Secret call to a running transcript hash, so the resulting secrets are unique to the exact bytes of the negotiated handshake. Any modification invalidates the Finished verification.

**Attack 5 — PSK/DHE mixture weakness:**

When a PSK and DHE are both present, naive XOR or concatenation mixing can cancel entropy if DHE = PSK (possible if both are derived from the same source). HKDF-Extract's two-stage design (IKM + salt) ensures that the output entropy is at least as large as the stronger of the two inputs. The design also ensures that a weak PSK (e.g., a short password) does not reduce security below the DHE level, because DHE enters as IKM (not just salt) at the Handshake Secret extraction.

**Why two HKDF stages per level (Extract then Expand)?**

HKDF-Extract converts potentially biased IKM into a uniformly random PRK. HKDF-Expand then stretches that PRK into keying material of arbitrary length. The separation is important because the security proofs for HKDF-Expand assume a uniform key input. Skipping Extract and using DHE directly as the HMAC key would invalidate the PRF proof for non-uniform DHE outputs.
