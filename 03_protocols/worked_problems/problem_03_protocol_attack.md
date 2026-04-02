# Problem 03: Protocol Attack Analysis

## Problem Statement

Analyse the following three attack scenarios against cryptographic protocols. For each:
1. Identify the attack precisely.
2. Explain why the vulnerable protocol design permits it.
3. Show what a captured transcript looks like versus what it should look like.
4. Describe the exact countermeasure that prevents it.

---

## Scenario A — The Padding Oracle Attack (CBC-mode TLS)

A legacy server still supports TLS 1.2 with `TLS_RSA_WITH_AES_128_CBC_SHA`. A researcher
notices that when they send a malformed TLS record, the server takes 1.2 ms to respond
with an error if the CBC padding is structurally valid, but only 0.3 ms if the padding
is invalid.

**Task:** Explain how this timing difference allows the attacker to decrypt an arbitrary
ciphertext block, step by step.

---

### Solution A

**Attack name:** CBC Padding Oracle Attack (Vaudenay 2002; POODLE variant, 2014).

**Why it works:**

AES-CBC decryption works as follows for block $i$:

```
P[i] = Decrypt_K(C[i]) XOR C[i-1]
```

For PKCS#7 padding, the last block's plaintext must end with $n$ bytes of value $n$:
```
  1 byte of padding:   ...  0x01
  2 bytes of padding:  ...  0x02 0x02
  ...
  16 bytes of padding: 0x10 0x10 ... 0x10
```

**The oracle:** The server decrypts the record and checks the padding. If padding is
valid, it processes the request (slow path: full application logic). If padding is
invalid, it returns an error immediately (fast path: short circuit). The **timing
difference** reveals whether the padding was valid.

**Decrypting one ciphertext byte (byte 15 of a block):**

The attacker controls ciphertext block $C[i-1]$ (they can modify it). The target block
is $C[i]$.

```
Step 1: Brute-force the last byte.
  Attacker submits: C[i-1]' where C[i-1]'[15] is varied from 0x00 to 0xFF
  Goal: find the value x such that:
    Decrypt_K(C[i])[15] XOR x = 0x01  (valid single-byte padding)
  
  When x produces valid padding (0x01 at position 15), the server takes 1.2 ms.
  
  From x:  Decrypt_K(C[i])[15] = x XOR 0x01
  Original plaintext: P[i][15] = Decrypt_K(C[i])[15] XOR C[i-1][15]
```

**Decrypting subsequent bytes (byte 14, then 13, etc.):**

```
Step 2: Adjust known bytes to produce padding 0x02 0x02, then brute-force byte 14.
  Set C[i-1]'[15] = Decrypt_K(C[i])[15] XOR 0x02  (forces byte 15 = 0x02)
  Brute-force C[i-1]'[14] until byte 14 also = 0x02.
  
Repeat for all 16 bytes: recovers all 16 bytes of P[i] with at most 256*16 = 4096
oracle queries. In practice, ~128*16 = 2048 queries on average.
```

**Full transcript comparison:**

```
Legitimate request:
  C = AES_CBC_Encrypt(K, IV, "GET /api/secret HTTP/1.1\r\n...")
  T = HMAC-SHA1(K_mac, seq || type || version || len || C)  [MAC-then-Encrypt]

Attacker's oracle queries:
  For j = 0..255:
    C' = C[0] || ... || C[i-1]'(j) || C[i]   (only last two blocks sent)
    Server responds:
      timing < 0.5ms: invalid padding (discard)
      timing > 1.0ms: valid padding! -- record Decrypt_K(C[i])[15] XOR j = 0x01
```

**Countermeasure:**

1. **Remove CBC cipher suites.** TLS 1.3 eliminates all CBC-mode cipher suites. Only
   AEAD modes (GCM, CCM, Poly1305) are permitted. AEAD provides authenticated encryption
   where padding errors are indistinguishable from authentication tag failures — the
   attacker gains no information from a failed authentication check.

2. **Encrypt-then-MAC.** RFC 7366 defines Encrypt-then-MAC for TLS 1.2. The MAC covers
   the ciphertext; the server checks the MAC first. Invalid ciphertext (including manipulated
   padding) is rejected before any padding is inspected, eliminating the oracle.

3. **Constant-time padding verification.** Check all padding bytes without early exit.
   Return identical responses (type and timing) for both padding error and MAC error.

**Why TLS 1.3 is immune:** TLS 1.3 uses only AEAD ciphers. AES-GCM and ChaCha20-Poly1305
verify authentication tags before any decryption output is usable. Tag verification is
constant-time and produces no information about the plaintext structure.

---

## Scenario B — The Downgrade Attack (FREAK / Logjam pattern)

A man-in-the-middle attacker intercepts a TLS 1.3 ClientHello between a client and a
server. The attacker modifies the `supported_versions` extension to remove TLS 1.3 and
leaves only TLS 1.2. The server, which supports both, responds with a TLS 1.2 ServerHello
and proceeds with a legacy RSA key exchange cipher suite.

**Task:** Explain why this attack fails against a correctly implemented TLS 1.3 client,
and describe exactly where the client detects the tampering.

---

### Solution B

**Attack name:** Version Downgrade Attack / Protocol Confusion Attack.

**Why the attack fails:**

**Mechanism 1 — Downgrade sentinel in ServerHello.random:**

RFC 8446 §4.1.3 mandates: when a TLS 1.3-capable server negotiates TLS 1.2 (because a
client sent a TLS 1.2-only ClientHello), it MUST embed a sentinel in ServerHello.random:

```
If negotiated version is TLS 1.2:
  ServerHello.random[24..31] = 44 4F 57 4E 47 52 44 01  (DOWNGRD\x01)
If negotiated version is TLS 1.1 or lower:
  ServerHello.random[24..31] = 44 4F 57 4E 47 52 44 00  (DOWNGRD\x00)
```

A TLS 1.3-capable client receiving a TLS 1.2 ServerHello MUST check bytes 24–31 of
random. If the sentinel is present, the client knows a TLS 1.3-capable server has been
forced to downgrade — which only happens if the ClientHello was modified. The client MUST
abort with an `illegal_parameter` alert.

**Mechanism 2 — Finished MAC over the complete transcript:**

Even if the attacker replaces the `supported_versions` extension in the ClientHello and
the resulting negotiation produces a TLS 1.2 handshake, the TLS 1.2 Finished message is
a MAC over the entire handshake transcript (including the modified ClientHello). The
legitimate server computes a Finished using its view of the transcript (the original
ClientHello). The attacker's modified ClientHello produces a different transcript, so the
server's Finished will not match what the client computes — the handshake fails.

**Transcript comparison:**

```
Legitimate flow (no attacker):
  Client          Server
  ClientHello (TLS 1.3 offer, key_share for X25519)
                  ServerHello (TLS 1.3 accepted)
                  EncryptedExtensions, Certificate, CertificateVerify, Finished
  Finished
  Application Data

Attacker's modified flow:
  Client          Attacker              Server
  ClientHello --> [strip TLS 1.3] -->  ClientHello (TLS 1.2 only)
                                        ServerHello (TLS 1.2)
                                        [random[24..31] = DOWNGRD\x01 if server is
                                         RFC 8446 compliant]
  Client receives ServerHello (TLS 1.2)
  Client checks random[24..31]:
    == DOWNGRD\x01? -> ABORT: illegal_parameter alert
```

**Where the client detects the tampering:**

Detection happens at the ServerHello message, before any sensitive data is sent.
The client:

1. Parses the ServerHello version field: sees 0x0303 (TLS 1.2) when it expected 0x0304.
2. Checks if `supported_versions` is present in ServerHello extensions.
   - If absent: this is a TLS 1.2 ServerHello.
3. Checks random[24..31] for the DOWNGRD sentinel.
4. If sentinel present: aborts immediately.

**Why TLS 1.2 alone is vulnerable:**

TLS 1.2 did not have the downgrade sentinel mechanism. FREAK (2015) and Logjam (2015)
exploited exactly this gap: a MITM could strip strong cipher suites from ClientHello,
force export-grade cryptography, and the TLS 1.2 Finished MAC (while protecting against
content tampering) did not provide the early-abort signal the client needed to refuse
the weaker handshake before committing to it.

---

## Scenario C — The Key Confusion Attack (JWT Algorithm Substitution)

A web API uses RS256-signed JWTs for authentication. The server's public key is published
at `https://api.example.com/jwks`. An attacker discovers the server validates JWTs using
the following pseudo-code:

```python
def verify_jwt(token, key):
    header, payload, sig = token.split(".")
    alg = json_decode(base64url_decode(header))["alg"]
    data = header + "." + payload
    if alg == "RS256":
        return rsa_verify(key, sha256(data), sig)
    elif alg == "HS256":
        return hmac_sha256(key, data) == sig
```

**Task:** Describe the algorithm confusion attack. What does the attacker submit and why
does the server accept it?

---

### Solution C

**Attack name:** JWT Algorithm Confusion Attack / Algorithm Substitution Attack
(also called "alg:none" or "RS256 to HS256" confusion; described by Tim McLean, 2015).

**The vulnerability:**

The server code reads the `alg` field from the **attacker-controlled JWT header** and
uses it to select the verification method. For HS256, it calls `hmac_sha256(key, data)`,
where `key` is the server's **RSA public key** (the same variable used for RS256).

The attacker exploits this by:
1. Crafting a JWT with `"alg": "HS256"` in the header.
2. Signing it with HMAC-SHA256 using the server's **RSA public key** as the HMAC key.
   (The RSA public key is public — the attacker can download it from `/jwks`.)

**Attack execution:**

```python
# Attacker downloads the RSA public key
public_key_pem = download("https://api.example.com/jwks")
public_key_bytes = pem_to_der(public_key_pem)

# Craft malicious JWT header claiming HS256
header  = base64url(json({"alg": "HS256", "typ": "JWT"}))
payload = base64url(json({"sub": "admin", "role": "superuser", "iat": now()}))
data    = header + "." + payload

# Sign with HMAC-SHA256 using the public key as the HMAC "secret"
sig     = base64url(HMAC_SHA256(key=public_key_bytes, message=data))

malicious_token = header + "." + payload + "." + sig
```

**Why the server accepts it:**

```python
verify_jwt(malicious_token, rsa_public_key):
  alg = "HS256"          # read from attacker's header
  key = rsa_public_key   # same variable — server's RSA public key

  # HS256 branch:
  return hmac_sha256(rsa_public_key, data) == sig
  # Attacker computed sig = hmac_sha256(rsa_public_key, data) -- MATCH
  # Returns True
```

The server accepts the forged token as valid.

**Why this is catastrophic:**

The attacker can put any claims they want in the payload (`"role": "admin"`,
`"sub": "arbitrary_user"`) and create a valid token for any identity.

**Countermeasures:**

1. **Never trust the `alg` field in the token header to select the verification
   algorithm.** The verification algorithm must be determined by the server's configuration,
   not the token itself.

```python
# CORRECT approach:
EXPECTED_ALGORITHM = "RS256"   # server configuration, not from token

def verify_jwt(token, rsa_public_key):
    header, payload, sig = token.split(".")
    alg = json_decode(base64url_decode(header))["alg"]
    if alg != EXPECTED_ALGORITHM:
        raise SecurityError("Unexpected algorithm: " + alg)
    data = header + "." + payload
    return rsa_verify(rsa_public_key, sha256(data), sig)
```

2. **Use separate keys for separate algorithms.** Never reuse an RSA key pair as
   an HMAC key. The RSA public key is not a secret; using it as an HMAC "secret" provides
   zero security because HMAC requires a secret key.

3. **Use a well-audited JWT library.** Libraries like `python-jose` (>=3.2.0), `PyJWT`
   (>=2.4.0), and `jsonwebtoken` (Node.js >=9.0.0) reject algorithm confusion by design.
   Avoid implementing JWT verification from scratch.

4. **Reject `alg: none`.** Some early libraries accepted unsigned tokens when the header
   contained `"alg": "none"`. Conforming libraries must reject this unless explicitly
   configured for special use cases (and never in authentication contexts).

---

## Summary

| Attack | Root Cause | Key Countermeasure |
|---|---|---|
| CBC Padding Oracle | Timing side-channel in MAC-then-Encrypt padding check | Use AEAD (TLS 1.3); Encrypt-then-MAC |
| Version Downgrade | Client trusts negotiation without authenticating it | Downgrade sentinel + Finished transcript MAC |
| JWT Algorithm Confusion | Algorithm selected from attacker-controlled header field | Server enforces algorithm; never trust `alg` from token |

**Common thread:** All three attacks exploit a discrepancy between what the protocol
*verifies* and what it *trusts*. CBC padding checked padding before the MAC. TLS 1.2
trusted the negotiated version without authenticating it end-to-end until late. JWT
verification trusted an attacker-controlled field to select security-critical behaviour.
The fix in each case is to authenticate the full context (algorithm, version, padding
validity) as an integral part of the security check.
