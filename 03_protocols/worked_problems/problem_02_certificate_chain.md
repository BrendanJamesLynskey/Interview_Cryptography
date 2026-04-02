# Problem 02: Certificate Chain Validation

## Problem Statement

You are implementing a TLS client. The server presents the following certificate chain
during a TLS 1.3 handshake:

```
Certificate 0 (leaf):
  Subject:    CN=api.example.com, O=Example Corp
  SAN:        DNS:api.example.com, DNS:www.example.com
  Issuer:     CN=Example Corp Intermediate CA, O=Example Corp
  notBefore:  2025-01-15T00:00:00Z
  notAfter:   2025-04-15T00:00:00Z
  Serial:     0x3F2A1B4C
  Algorithm:  ecdsa-with-SHA256
  Public key: EC P-256
  Extensions:
    Basic Constraints: cA=FALSE, critical
    Key Usage: digitalSignature, critical
    Extended Key Usage: id-kp-serverAuth
    Authority Info Access: OCSP http://ocsp.example-ca.com
    CRL Distribution: http://crl.example-ca.com/intermediate.crl
    Certificate Transparency: 2 SCTs embedded
  Signature:  (ECDSA P-256 signature over tbsCertificate)

Certificate 1 (intermediate):
  Subject:    CN=Example Corp Intermediate CA, O=Example Corp
  Issuer:     CN=Example Corp Root CA, O=Example Corp
  notBefore:  2023-06-01T00:00:00Z
  notAfter:   2026-06-01T00:00:00Z
  Serial:     0x00A1
  Algorithm:  sha384WithRSAEncryption
  Public key: RSA-4096
  Extensions:
    Basic Constraints: cA=TRUE, maxPathLen=0, critical
    Key Usage: keyCertSign, cRLSign, critical
    Name Constraints: permittedSubtrees: DNS:.example.com

Root CA (in client trust store):
  Subject:    CN=Example Corp Root CA, O=Example Corp
  Issuer:     CN=Example Corp Root CA, O=Example Corp  (self-signed)
  notBefore:  2020-01-01T00:00:00Z
  notAfter:   2040-01-01T00:00:00Z
  Algorithm:  sha256WithRSAEncryption
  Public key: RSA-4096
  Extensions:
    Basic Constraints: cA=TRUE, critical
```

Current date: 2025-03-01.

**Tasks:**

1. List every validation check that must be performed on each certificate in order.
2. Identify which checks can be batched in parallel and which must be sequential.
3. Identify any potential failure conditions in this chain, even if they currently pass.
4. Explain the effect of the `maxPathLen=0` constraint on the intermediate.
5. Describe what the Name Constraints extension enforces and why it matters.

---

## Solution

### Step 1 — Order and Prepare the Chain

The client assembles the validation path in order:

```
C[0] = leaf certificate       (received from server)
C[1] = intermediate CA cert   (received from server)
C[2] = root CA cert           (from client trust store)
```

Validation proceeds from the trust anchor down: C[2] signs C[1], C[1] signs C[0].

---

### Step 2 — Validate the Intermediate CA Certificate (C[1])

C[1] must be validated before C[0] because C[0]'s signature is verified using C[1]'s key.

**Check 2.1 — Signature verification:**
```
C[1].signatureAlgorithm = sha384WithRSAEncryption
Verify: RSA_Verify(C[2].publicKey,
                   SHA-384(C[1].tbsCertificate),
                   C[1].signatureValue)
-- Uses the root CA's 4096-bit RSA public key from the trust store
```

**Check 2.2 — Validity period:**
```
C[1].notBefore = 2023-06-01  <=  2025-03-01 (today)  <=  2026-06-01 = C[1].notAfter
-- PASS
```

**Check 2.3 — Issuer/Subject name chaining:**
```
C[1].issuer = "CN=Example Corp Root CA, O=Example Corp"
C[2].subject = "CN=Example Corp Root CA, O=Example Corp"
-- Compare using RFC 5280 rules: case-insensitive, whitespace-normalised
-- PASS
```

**Check 2.4 — Basic Constraints (CA flag):**
```
C[1].BasicConstraints.cA = TRUE   -- required for any non-leaf cert in the path
C[1].BasicConstraints.maxPathLen = 0   -- at most 0 additional CAs may follow
-- PASS (C[1] is used to sign C[0], a leaf, not another CA)
```

**Check 2.5 — Key Usage:**
```
C[1].KeyUsage contains keyCertSign   -- required for certificate signing
-- PASS
```

**Check 2.6 — Revocation:**
Check the CRL or OCSP for C[1] using the endpoints in C[1]'s AIA extension (not shown
in this example; assume the check is performed).

---

### Step 3 — Validate the Leaf Certificate (C[0])

**Check 3.1 — Signature verification:**
```
C[0].signatureAlgorithm = ecdsa-with-SHA256
Verify: ECDSA_Verify(C[1].publicKey,         -- C[1]'s RSA-4096 key
                     SHA-256(C[0].tbsCertificate),
                     C[0].signatureValue)
```

There is an inconsistency here: C[0] is an EC certificate signed with ECDSA, but
C[1]'s public key is RSA-4096. A RSA public key cannot verify an ECDSA signature, and
an ECDSA private key cannot produce an RSA signature.

**This chain has a signature algorithm mismatch.** The leaf's `signatureAlgorithm` field
says `ecdsa-with-SHA256`, meaning it was signed with an ECDSA private key. But the
intermediate CA's public key is RSA-4096. Either:
- The leaf was signed by a different CA than the one presented, or
- The `signatureAlgorithm` field is incorrect

A real TLS client would reject this chain at this step with a certificate signature
verification failure.

**Assuming the chain is corrected** (C[1] has an EC P-256 or P-384 key, or C[0]'s
algorithm matches RSA), the remaining checks proceed:

**Check 3.2 — Validity period:**
```
C[0].notBefore = 2025-01-15  <=  2025-03-01  <=  2025-04-15 = C[0].notAfter
-- PASS
-- Note: 90-day validity period (Jan 15 to Apr 15). This is at the short end
-- of current CA/Browser Forum allowed validity.
```

**Check 3.3 — Hostname binding (Subject Alternative Name):**
```
Requested hostname: api.example.com
C[0].SAN contains: DNS:api.example.com
-- PASS (exact match)
-- For www.example.com, DNS:www.example.com also present.
-- The CN field is NOT checked by conforming TLS clients (RFC 2818 §3.1 deprecated CN).
```

**Check 3.4 — Basic Constraints:**
```
C[0].BasicConstraints.cA = FALSE, marked critical
-- Correct for a leaf certificate.
-- If this were absent or cA=TRUE on a leaf cert used for server auth, it would be
-- a policy violation (but some older implementations accepted it).
```

**Check 3.5 — Key Usage and Extended Key Usage:**
```
C[0].KeyUsage: digitalSignature   -- correct for ECDSA server authentication
C[0].ExtendedKeyUsage: id-kp-serverAuth  -- required by TLS for server certificates
-- PASS
```

**Check 3.6 — Revocation:**
```
OCSP responder: http://ocsp.example-ca.com
CRL URL: http://crl.example-ca.com/intermediate.crl

Options:
  a. Fetch OCSP response from the responder (adds RTT to handshake)
  b. Accept OCSP staple if server provided one in TLS status_request extension
  c. Download CRL and check C[0].serialNumber = 0x3F2A1B4C is not listed
```

If the server provides a valid OCSP staple, no external request is needed. The client
verifies the OCSP response signature using the CA's OCSP signing certificate.

**Check 3.7 — Certificate Transparency SCTs:**
```
C[0] contains 2 embedded SCTs from distinct CT logs
Client verifies each SCT:
  SCT_i = Log_i_Key_Sign(timestamp_i || pre-cert-hash)
  
Requirements:
  - At least 2 SCTs from Google-approved logs (for Chrome)
  - SCT timestamps must be before C[0].notAfter
  - Log keys must be in the client's trusted log list
-- PASS if both SCTs verify
```

---

### Step 4 — Name Constraints Analysis

The intermediate CA has:
```
Name Constraints (critical extension):
  permittedSubtrees: DNS:.example.com
```

This means the intermediate CA is **technically constrained**: it may only issue
certificates for domain names that are **subdomains of example.com** or equal to
`example.com` itself.

If the intermediate CA issued a certificate for `attacker.com`, the path validation
algorithm would detect that `attacker.com` does not match `.example.com` and would
fail chain validation at the Name Constraints check, even if the certificate was
properly signed.

**Why this matters:**

1. **Reduces blast radius of CA compromise:** If the intermediate CA's private key is
   stolen, the attacker can only issue certificates for `*.example.com` domains.
   Browsers would reject a fraudulently issued certificate for `google.com` at the
   Name Constraints step.

2. **Common in enterprise PKI:** Large organisations operate private CAs with Name
   Constraints to prevent their internal CAs from being usable outside their domain.
   Browser vendors (Mozilla, Chrome) accept such CAs with Name Constraints without
   adding them to the public trust store.

3. **Name Constraints on IP addresses:** The extension can also constrain IP address
   ranges (`permittedSubtrees: IPAddress: 192.168.0.0/16`).

---

### Step 5 — maxPathLen Analysis

The intermediate CA has `BasicConstraints: cA=TRUE, maxPathLen=0`.

`maxPathLen=0` means: **zero additional CA certificates may appear below this
intermediate in the path.** In other words, the intermediate CA may sign leaf
certificates but cannot sign another intermediate CA's certificate.

```
Allowed:
  Root CA  --(signs)-->  Intermediate (maxPathLen=0)  --(signs)-->  Leaf cert
  
Not allowed:
  Root CA  --(signs)-->  Intermediate (maxPathLen=0)  --(signs)-->  Sub-Intermediate CA
```

If the intermediate CA attempted to sign another CA certificate (one with `cA=TRUE`),
path validation would fail at Check 2.4 for any chain containing that sub-CA.

**Why this constraint is set:** Prevents delegation attacks. An attacker who compromises
this intermediate CA cannot create their own "sub-CA" that appears to have a longer
path to issue certificates for arbitrary domains.

---

### Step 6 — Parallel vs Sequential Validation

```
Sequential (cannot parallelise — order matters):
  1. Validate C[2] as trust anchor (lookup in trust store)
  2. Verify C[1] signature using C[2]'s key       -- requires C[2] to be trusted first
  3. Verify C[0] signature using C[1]'s key        -- requires C[1] to be valid
  4. Check hostname binding on C[0]                -- requires C[0] to be valid

Can parallelise (independent once cert is parsed):
  - Validity period check (C[0] and C[1] simultaneously)
  - CT SCT verification (independent of OCSP)
  - Issuer/subject name chaining checks
  - Key Usage / Extended Key Usage checks
  - Name Constraints evaluation

OCSP/CRL queries for C[0] and C[1] can be parallelised with each other,
but only launched after their respective certs are received.
```

---

### Step 7 — Potential Failure Conditions Summary

| Check | Current Status | Future Risk |
|---|---|---|
| C[0] signature algorithm vs C[1] key type | **FAILS** (ECDSA sig / RSA key mismatch) | Must fix |
| C[0] validity expires 2025-04-15 | PASS now | Must renew before Apr 15, 2025 |
| C[1] validity expires 2026-06-01 | PASS | Plan renewal |
| C[0] revocation (OCSP/CRL) | Assumed PASS | Key compromise triggers revocation |
| CT SCTs | PASS (2 embedded) | Log key expiry or log distrust |
| Name Constraints | PASS (api.example.com matches .example.com) | Any cert outside example.com fails |
| maxPathLen=0 | PASS (leaf below intermediate) | Would fail if intermediate used to sign sub-CA |

---

## Key Points to Remember

1. Chain validation is path-ordered: trust anchor is validated first, then each
   certificate in sequence toward the leaf.
2. Signature algorithm in C[0] must match the key type of the issuer C[1] — a common
   source of misconfiguration errors.
3. Hostname matching uses **SAN only** in modern clients. The CN field is ignored.
4. `maxPathLen=0` prevents sub-CA delegation below the intermediate.
5. Name Constraints technically constrain an intermediate CA's issuance scope —
   a key tool for limiting damage from CA compromise.
6. CT SCT verification adds a second layer of validation beyond the PKI chain.
