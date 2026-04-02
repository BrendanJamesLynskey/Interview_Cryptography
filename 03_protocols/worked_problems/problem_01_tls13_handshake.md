# Problem 01: TLS 1.3 Handshake Trace

## Problem Statement

A client connects to `api.example.com` and negotiates TLS 1.3 with the following
parameters:
- Cipher suite: `TLS_AES_128_GCM_SHA256`
- Named group: X25519
- Server authentication: ECDSA with P-256 certificate

Work through each phase of the handshake, identifying:

1. Every message exchanged and its direction
2. Which messages are encrypted and with which key material
3. At what point the server's identity is authenticated
4. At what point each party can begin sending application data
5. What the key schedule produces and in what order

---

## Solution

### Phase 1 — ClientHello (Client to Server, plaintext)

The client sends a ClientHello containing:

```
ClientHello {
    legacy_version:        0x0303    (TLS 1.2 for compatibility)
    random:                32 bytes  (client_random)
    session_id:            0 bytes   (TLS 1.3 uses PSK/ticket instead)
    cipher_suites:         [TLS_AES_128_GCM_SHA256]
    extensions:
      supported_versions:  [TLS 1.3]      (actual version negotiation)
      supported_groups:    [X25519, P-256, ...]
      key_share:           [(X25519, client_public_key)]   -- 32 bytes
      signature_algorithms:[ecdsa_secp256r1_sha256, ...]
      server_name:         ["api.example.com"]
}
```

Key observation: The client includes its X25519 public key in the **first message**. This
is the "predict and send" optimisation — the client predicts that the server will accept
X25519 and sends the key share immediately rather than waiting for server preference.

The client generates an ephemeral X25519 key pair:
```
client_private = random 32 bytes (clamped)
client_public  = X25519(client_private, G)   -- G = base point u=9
```

---

### Phase 2 — ServerHello (Server to Client, plaintext)

The server generates its own ephemeral X25519 key pair:
```
server_private = random 32 bytes (clamped)
server_public  = X25519(server_private, G)
```

The server sends:
```
ServerHello {
    legacy_version:       0x0303
    random:               32 bytes  (server_random)
    cipher_suite:         TLS_AES_128_GCM_SHA256
    extensions:
      supported_versions: [TLS 1.3]
      key_share:          (X25519, server_public_key)   -- 32 bytes
}
```

After receiving ServerHello, **both sides compute the ECDH shared secret**:
```
Client: DHE = X25519(client_private, server_public)   -- 32 bytes
Server: DHE = X25519(server_private, client_public)
-- Both produce the same 32-byte value by ECDH commutativity
```

---

### Phase 3 — Key Schedule (both sides, simultaneously)

With DHE in hand, both sides run the HKDF-based key schedule:

```
Step 1: Early Secret
  ES = HKDF-Extract(salt=0^32, IKM=0^32)   -- no PSK, so IKM=0

Step 2: Handshake Secret
  derived = Derive-Secret(ES, "derived", "")
  HS = HKDF-Extract(salt=derived, IKM=DHE)  -- DHE injected here

Step 3: Handshake traffic secrets
  -- Transcript at this point: ClientHello || ServerHello
  server_hs_secret = Derive-Secret(HS, "s hs traffic", CH||SH)
  client_hs_secret = Derive-Secret(HS, "c hs traffic", CH||SH)

Step 4: Handshake record keys
  server_write_key = HKDF-Expand-Label(server_hs_secret, "key", "", 16)
  server_write_iv  = HKDF-Expand-Label(server_hs_secret, "iv",  "", 12)
  client_write_key = HKDF-Expand-Label(client_hs_secret, "key", "", 16)
  client_write_iv  = HKDF-Expand-Label(client_hs_secret, "iv",  "", 12)
```

The server can now encrypt handshake messages. The client can decrypt them.

---

### Phase 4 — Encrypted Server Handshake Messages

All messages from this point until (and including) the server's Finished are encrypted
with `server_write_key` and `server_write_iv`.

**EncryptedExtensions:**
```
EncryptedExtensions {
    extensions: [server_name, ...]    -- encrypted
}
```
Contains any extensions that must be hidden from passive observers. The server name
extension is acknowledged here.

**Certificate:**
```
Certificate {
    certificates: [leaf_cert, intermediate_cert]
}
```
The server's ECDSA P-256 certificate chain. Because this is encrypted with the handshake
traffic key (derived from DHE), a passive eavesdropper cannot see the server's certificate
or its identity. This is a significant privacy improvement over TLS 1.2.

**CertificateVerify:**
```
CertificateVerify {
    algorithm: ecdsa_secp256r1_sha256
    signature: ECDSA_Sign(
        server_long_term_private_key,
        64 bytes of 0x20 ||
        "TLS 1.3, server CertificateVerify" || 0x00 ||
        Transcript-Hash(CH || SH || EE || Cert)
    )
}
```

This signature proves the server possesses the private key corresponding to the certificate
just sent. The signature covers the entire transcript so far, binding the server's identity
to this specific ECDH exchange. An attacker cannot replay the certificate from another
session — the transcript hash would differ.

**Server Finished:**
```
finished_key  = HKDF-Expand-Label(server_hs_secret, "finished", "", 32)
verify_data   = HMAC-SHA256(finished_key,
                             Transcript-Hash(CH||SH||EE||[CR]||Cert||CV))
Finished { verify_data }
```

The Finished MAC covers the complete handshake transcript. This authenticates the entire
negotiation: any tampering with any handshake message (downgrade attempt, cipher suite
modification) changes the transcript hash and produces a different expected `verify_data`.

---

### Phase 5 — Server Identity Is Now Authenticated

After the client receives and verifies:
1. The server's Certificate (certificate chain validates to a trusted root)
2. The CertificateVerify signature (proves private key possession)
3. The server's Finished (authenticates the full transcript)

the server's identity is established. The client now knows it is communicating with the
legitimate holder of the `api.example.com` certificate.

---

### Phase 6 — Application Keys Derived

```
Step 5: Master Secret
  derived2  = Derive-Secret(HS, "derived", "")
  MS        = HKDF-Extract(salt=derived2, IKM=0^32)

Step 6: Application traffic secrets
  -- Transcript at this point: CH || SH || EE || [CR] || Cert || CV || Finished_server
  server_app_secret = Derive-Secret(MS, "s ap traffic", CH..server_Finished)
  client_app_secret = Derive-Secret(MS, "c ap traffic", CH..server_Finished)

Step 7: Application record keys
  server_write_key = HKDF-Expand-Label(server_app_secret, "key", "", 16)
  server_write_iv  = HKDF-Expand-Label(server_app_secret, "iv",  "", 12)
  client_write_key = HKDF-Expand-Label(client_app_secret, "key", "", 16)
  client_write_iv  = HKDF-Expand-Label(client_app_secret, "iv",  "", 12)
```

---

### Phase 7 — Client Finished (Client to Server, encrypted)

```
Client Finished {
    verify_data: HMAC-SHA256(
        HKDF-Expand-Label(client_hs_secret, "finished", "", 32),
        Transcript-Hash(CH || SH || EE || [CR] || Cert || CV || server_Finished)
    )
}
```

The client authenticates the full transcript from its side. The server verifies the client
Finished and can now trust that the client received the same handshake messages.

---

### Phase 8 — Application Data Flows

Both parties switch to application record keys immediately after the client sends Finished.

```
Client                                                  Server
  |                                                       |
  |--- ClientHello ---------------------------------------->|  plaintext
  |                                                       |
  |<-- ServerHello ----------------------------------------|  plaintext
  |                                                       |
  |    [Both derive handshake keys from DHE]              |
  |                                                       |
  |<-- {EncryptedExtensions} -----------------------------|  server HS key
  |<-- {Certificate} ------------------------------------|  server HS key
  |<-- {CertificateVerify} -----------------------------|  server HS key
  |<-- {Finished (server)} -----------------------------|  server HS key
  |                                                       |
  |    [Both derive application keys]                     |
  |    [Client verifies server identity here]             |
  |                                                       |
  |--- {Finished (client)} ------------------------------>|  client HS key
  |                                                       |
  |<========= Application Data (1-RTT total) ==========>|  app keys
```

Total round trips before application data: **1-RTT**.

---

## Summary Table

| Message | Direction | Encrypted? | Key | Server identity proved? |
|---|---|---|---|---|
| ClientHello | C→S | No | — | No |
| ServerHello | S→C | No | — | No |
| EncryptedExtensions | S→C | Yes | server HS key | No |
| Certificate | S→C | Yes | server HS key | No (cert received but not yet verified) |
| CertificateVerify | S→C | Yes | server HS key | No (signature received but not yet verified) |
| Finished (server) | S→C | Yes | server HS key | **Yes** (after verifying all three) |
| Finished (client) | C→S | Yes | client HS key | — |
| Application Data | both | Yes | app keys | Yes |

---

## Key Points to Remember

1. The ECDH key share is sent in the very first message (ClientHello) — no extra RTT.
2. Certificate and CertificateVerify are **encrypted** — the server's identity is hidden
   from passive observers. This is different from TLS 1.2 where the Certificate was sent
   in plaintext.
3. The server's identity is fully authenticated only after the client verifies all three:
   Certificate + CertificateVerify + Finished.
4. Application keys are derived before the client sends its own Finished — the client can
   prepare the application request while computing the Finished message.
5. The HKDF key schedule always includes a full transcript hash, ensuring all derived
   secrets are session-specific and any transcript tampering is detectable.
