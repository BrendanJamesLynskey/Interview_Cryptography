# Quiz: Cryptographic Protocols

15 multiple-choice questions covering TLS 1.3, key exchange, PKI, certificate management,
authentication protocols, and protocol attacks.

**Instructions:** Select the single best answer. Answers with explanations at the end.

---

## Questions

**Q1.** In TLS 1.3, how many round trips are required before the client can send
application data in a full (non-resumption) handshake?

A) 0-RTT
B) 1-RTT
C) 2-RTT
D) 3-RTT

---

**Q2.** Which TLS 1.3 messages are encrypted with the handshake traffic keys
(derived after ServerHello)?

A) ClientHello and ServerHello only
B) Certificate, CertificateVerify, and Finished (server side)
C) All messages including ClientHello
D) Only the Finished messages

---

**Q3.** TLS 1.3 removes which feature that was present in TLS 1.2?

A) Forward secrecy via ephemeral Diffie-Hellman
B) Certificate-based server authentication
C) Static RSA key exchange
D) HKDF-based key derivation

---

**Q4.** What is the purpose of the `CertificateVerify` message in TLS 1.3?

A) To verify that the client's IP address matches the certificate's SAN
B) To prove that the server possesses the private key corresponding to its certificate
C) To confirm that the server's certificate is not revoked
D) To authenticate the client to the server

---

**Q5.** In an X.509 certificate, which extension is used for hostname matching in
modern TLS clients?

A) Common Name (CN) in the Subject field
B) Subject Alternative Name (SAN)
C) Organization (O) in the Subject field
D) Authority Key Identifier

---

**Q6.** OCSP Stapling solves which problem with standard OCSP?

A) OCSP responses are too short-lived
B) OCSP requires the CA to maintain a database of all issued certificates
C) OCSP queries reveal the client's browsing activity to the CA's OCSP responder
D) OCSP responses are not digitally signed

---

**Q7.** What is a Signed Certificate Timestamp (SCT) in Certificate Transparency?

A) A timestamp from the CA indicating when the certificate was issued
B) A cryptographic proof that a certificate was submitted to a CT log
C) A hash of the certificate stored in the X.509 subject field
D) A revocation timestamp indicating when the certificate was revoked

---

**Q8.** In Diffie-Hellman key exchange, an active man-in-the-middle attacker can:

A) Recover the shared secret by solving the discrete logarithm problem
B) Block the key exchange from completing successfully
C) Substitute their own DH public key for each party, intercepting both
D) Decrypt all messages by observing only the public values

---

**Q9.** The Station-to-Station (STS) protocol extends Diffie-Hellman by adding:

A) Larger prime moduli for better security
B) Digital signatures from both parties over the exchange transcript
C) A symmetric key to encrypt the DH public values
D) Hashing of the shared secret before use

---

**Q10.** Which attack exploits a CBC padding oracle vulnerability?

A) BEAST
B) ROBOT
C) POODLE
D) Bleichenbacher's attack

---

**Q11.** FIDO2 authentication is considered phishing-resistant because:

A) It uses a one-time password that changes every 30 seconds
B) The signature is bound to the exact origin of the requesting website
C) The authenticator requires biometric verification every time
D) The private key is stored on the server, not the client

---

**Q12.** Argon2id uses which primary mechanism to resist GPU-based brute-force attacks?

A) Multiple rounds of SHA-256
B) Memory hardness — requiring large amounts of RAM per computation
C) Elliptic curve operations to slow computation
D) Public-key cryptography for password verification

---

**Q13.** During a TLS 1.3 0-RTT (early data) connection, what security property is
NOT provided for the early data itself?

A) Confidentiality
B) Integrity
C) Forward secrecy
D) Authentication of the server

---

**Q14.** A TOTP (Time-based One-Time Password) code can be used in a real-time phishing
attack because:

A) TOTP codes are valid for 24 hours
B) TOTP has no origin binding — the code can be forwarded to the legitimate server
C) TOTP codes can be factored to recover the shared secret
D) The TOTP shared secret is transmitted during each authentication

---

**Q15.** An `X.509` certificate has `maxPathLen=0` in its Basic Constraints extension.
What does this mean?

A) The certificate is a leaf certificate and cannot sign anything
B) The certificate is a CA certificate but can only sign leaf certificates, not other CAs
C) The certificate chain has zero depth (the root is directly trusted)
D) The certificate has expired and has zero days remaining

---

## Answers and Explanations

**Q1. Answer: B — 1-RTT**

In a TLS 1.3 full handshake:
- Client sends ClientHello (with key share): 1 message to server
- Server responds with ServerHello, EncryptedExtensions, Certificate, CertificateVerify,
  Finished — all in one flight
- Client sends Finished, then immediately begins sending application data

Total: one round trip (1-RTT) before application data. The client's key share in
ClientHello enables the server to derive handshake keys without waiting for another
message, which is the primary latency improvement over TLS 1.2 (which required 2-RTT).

0-RTT is only available for resumption (not a full handshake). 2-RTT occurs if a
HelloRetryRequest is needed (key share mismatch).

---

**Q2. Answer: B — Certificate, CertificateVerify, and Finished (server side)**

After ServerHello, both sides derive handshake traffic keys from the DHE shared secret.
The server immediately uses these keys to encrypt:
- EncryptedExtensions
- Certificate (and optional CertificateRequest)
- CertificateVerify
- Finished

Importantly, the server's Certificate is encrypted — this hides the server's identity
from passive observers, unlike TLS 1.2 where the Certificate was sent in plaintext.

ClientHello and ServerHello are plaintext (needed to establish the keys). The answer
"only Finished messages" (D) is wrong — four server-side messages are encrypted.

---

**Q3. Answer: C — Static RSA key exchange**

TLS 1.3 removed all cipher suites with static RSA key exchange (e.g.,
`TLS_RSA_WITH_AES_128_GCM_SHA256`). In static RSA, the client encrypts the pre-master
secret directly under the server's long-term RSA key — there is no forward secrecy.

What TLS 1.3 also removed: all CBC cipher suites, RC4, 3DES, export ciphers, and all
non-forward-secret key exchanges.

Answer A: TLS 1.3 requires forward secrecy — it did not remove ephemeral DH.
Answer B: certificate authentication remains in TLS 1.3.
Answer D: HKDF was introduced in TLS 1.3 (TLS 1.2 used PRF/HMAC, not HKDF).

---

**Q4. Answer: B — To prove that the server possesses the private key**

CertificateVerify is a digital signature over the full handshake transcript
(ClientHello through Certificate). It is computed using the server's long-term
private key (corresponding to the public key in the Certificate).

This proves two things: (1) the server has the private key matching the certificate,
and (2) the signature is bound to this specific handshake — an attacker cannot replay
the certificate or signature from another session.

Answer A is wrong: IP address verification is not part of TLS.
Answer C is wrong: revocation is checked via OCSP or CRL, not CertificateVerify.
Answer D is wrong: CertificateVerify in the standard server-auth flow proves server
identity, not client identity (client auth uses a separate Certificate/CertificateVerify
in the other direction).

---

**Q5. Answer: B — Subject Alternative Name (SAN)**

RFC 2818 (2000) deprecated the use of the Common Name (CN) field for hostname matching
in TLS. Modern clients (Chrome, Firefox, Safari) use only the SAN extension. A
certificate without a SAN containing the hostname will be rejected, regardless of what
the CN field says.

The SAN extension can contain multiple DNS names (e.g., `DNS:example.com` and
`DNS:www.example.com`), IP addresses, email addresses, and URIs.

Answer A (CN): historically used but deprecated; modern clients ignore it for hostname matching.
Answer C (Organization O): identifies the organisation, not the hostname.
Answer D (Authority Key Identifier): identifies the issuing CA's key, not the hostname.

---

**Q6. Answer: C — OCSP queries reveal browsing activity to the OCSP responder**

In standard OCSP, the client sends a query to the CA's OCSP responder containing the
certificate serial number. The OCSP responder therefore learns which website the client
is visiting. For a CA that issued certificates to many websites, this is a significant
privacy concern.

OCSP Stapling solves this: the server fetches its own OCSP response periodically and
includes it in the TLS handshake. The client never contacts the OCSP responder; the
server's visit to the OCSP responder reveals nothing about individual client behaviour.

Answer A is wrong: OCSP Stapling does not change response lifetime (typically 24 hours).
Answer B is wrong: CAs already maintain a database for both CRL and OCSP.
Answer D is wrong: OCSP responses are always digitally signed by the CA.

---

**Q7. Answer: B — A cryptographic proof that a certificate was submitted to a CT log**

A Signed Certificate Timestamp (SCT) is a signature from a CT log's key over the
pre-certificate and a timestamp. The signature proves that the certificate was
presented to that specific log, which committed to including it in the log's append-only
Merkle tree.

TLS clients verify that a certificate contains SCTs from at least two independent
trusted CT logs before accepting it. This requirement prevents CAs from issuing
certificates without public audit trail.

Answer A is wrong: the issuance timestamp is in the certificate's notBefore field, not an SCT.
Answer C is wrong: there is no certificate hash in the Subject field.
Answer D is wrong: SCTs are issued before issuance, not at revocation.

---

**Q8. Answer: C — Substitute their own DH public key, intercepting both**

Unauthenticated DH provides no authentication. An active MitM intercepts both parties'
DH public key shares and substitutes their own:

```
Alice  --[A = g^a]-->  MitM (Eve) --[A' = g^e]--> Bob
Alice  <--[B' = g^e]-- MitM (Eve) <--[B = g^b]-- Bob
```

Eve establishes separate shared secrets with Alice and Bob. Eve decrypts Alice's
messages, reads them, and re-encrypts them for Bob — and vice versa.

Answer A is wrong: Solving DLP is computationally infeasible — the attack exploits
the lack of authentication, not the DLP.
Answer B is wrong: the attacker does not block the exchange; they redirect it.
Answer D is wrong: a passive eavesdropper cannot compute $g^{ab}$ from $g^a$ and $g^b$
without solving the Diffie-Hellman problem.

---

**Q9. Answer: B — Digital signatures from both parties over the exchange**

STS protocol adds mutual authentication to DH by having each party sign the transcript
of the key exchange (including both public values). Alice signs $A \| B$ with her
long-term key; Bob signs $A \| B$ with his long-term key. Each party verifies the
other's signature before accepting the shared secret.

TLS 1.3 uses this pattern: the server signs the handshake transcript in CertificateVerify,
binding the server's long-term identity to this specific ephemeral key exchange.

Answer A: larger primes increase DLP security but do not address authentication.
Answer C: encrypting DH public values does not authenticate them.
Answer D: hashing the shared secret is good practice (to normalise the EC output) but
does not authenticate the exchange.

---

**Q10. Answer: C — POODLE**

POODLE (Padding Oracle On Downgraded Legacy Encryption, 2014) exploits a padding oracle
in SSL 3.0's CBC mode. The attack uses the server's different error responses for valid
vs invalid padding to decrypt ciphertext byte by byte, requiring approximately 256
requests per byte.

BEAST (2011): Also exploits CBC mode (a chosen-plaintext attack on TLS 1.0's predictable
IV chaining) — different attack.

ROBOT (Return Of Bleichenbacher's Oracle Threat, 2017): Exploits RSA PKCS#1 v1.5
padding in TLS RSA key exchange — an RSA padding oracle, not CBC.

Bleichenbacher's attack (1998): Exploits RSA PKCS#1 v1.5 padding directly — also an
RSA oracle, not CBC.

---

**Q11. Answer: B — The signature is bound to the exact origin of the requesting website**

In FIDO2 authentication, the clientDataHash includes the origin field:
`{"type":"webauthn.get","challenge":"...","origin":"https://bank.com"}`.

This value is set by the browser based on the actual URL of the requesting page, not
by the JavaScript on the page. A phishing page at `https://bank-1ogin.com` will embed
`https://bank-1ogin.com` as the origin, producing an assertion that the real
`bank.com` server will reject because the origin does not match.

Answer A: FIDO2 does not use time-based codes (that describes TOTP).
Answer C: user verification (biometric/PIN) is optional and configurable; it is not
the source of phishing resistance.
Answer D is backward: in FIDO2, the private key is stored on the client device, and
only the public key is stored on the server.

---

**Q12. Answer: B — Memory hardness — requiring large amounts of RAM per computation**

Argon2id requires a configurable amount of memory (e.g., 64 MiB) for each password
hash computation. A GPU has thousands of cores but limited per-core memory bandwidth.
Running 1000 parallel guesses at 64 MiB each would require 64 GB of GPU VRAM —
far beyond typical hardware. ASICs are similarly constrained: they cannot remove the
memory access pattern without fundamentally redesigning the algorithm.

Answer A: multiple SHA-256 rounds (PBKDF2) is purely CPU-bound with no memory hardness —
vulnerable to GPU attacks.
Answer C: Argon2id does not use elliptic curve operations.
Answer D: Argon2id is a symmetric construction; no public-key operations are involved.

---

**Q13. Answer: C — Forward secrecy**

In 0-RTT, early data is encrypted under `client_early_traffic_secret`, derived from
the PSK (session ticket) and ClientHello transcript — but NOT from the new ephemeral
DHE shared secret. If the PSK (session ticket encryption key) is later compromised,
an attacker can retrospectively decrypt the early data.

Confidentiality (A) and integrity (B) are provided by the AEAD cipher used for early
data (same as for 1-RTT application data). Server authentication (D) is available
from the certificate and CertificateVerify later in the handshake.

Forward secrecy is specifically the property that is absent for early data — this is
one of the documented limitations of 0-RTT.

---

**Q14. Answer: B — TOTP has no origin binding**

TOTP is based on HMAC of a shared secret and the current time. The code has no
cryptographic binding to the website that requested it. A real-time phishing proxy can:
1. Display a fake login page at `bank-phishing.com`
2. Relay the entered username and TOTP code to the real `bank.com` in real time
3. Forward the session cookie back to the attacker

The 30-second window is sufficient for this relay attack. This is why TOTP is
considered phishable and FIDO2/Passkeys are preferred for phishing-resistant MFA.

Answer A is wrong: TOTP codes expire after 30 seconds (or at most 90 seconds with
clock tolerance), not 24 hours.
Answer C is wrong: the shared secret cannot be recovered by factoring the code.
Answer D is wrong: the TOTP shared secret is provisioned once during setup, not
transmitted per authentication.

---

**Q15. Answer: B — The certificate is a CA but can only sign leaf certificates**

`maxPathLen=0` in BasicConstraints means: at most zero additional CA certificates
may appear below this certificate in the chain. This certificate can sign end-entity
(leaf) certificates, but it cannot sign another CA certificate that would then sign
leaf certificates.

`maxPathLen=1` would mean one more CA is allowed below this one.

Answer A is wrong: a certificate without `cA=TRUE` in BasicConstraints is a leaf
certificate. The presence of `cA=TRUE` (with `maxPathLen=0`) means it IS a CA.
Answer C is wrong: chain depth is about certification path length, not this field's
zero value.
Answer D is wrong: validity period is specified in the notBefore/notAfter fields.
