# PKI and Certificates

## Prerequisites
- Public-key cryptography: RSA, ECDSA, digital signatures
- Hash functions: SHA-256, SHA-384
- Basic understanding of TLS and HTTPS
- ASN.1 and DER encoding (helpful but not required)

---

## Concept Reference

### What PKI Solves

Diffie-Hellman and ECDH establish shared secrets, but they provide no authentication. An
attacker who intercepts the key exchange can substitute their own public key, becoming a
man-in-the-middle. Public Key Infrastructure (PKI) solves the **binding problem**: how to
associate a public key with a specific identity (domain name, person, or organisation) in
a way that third parties can verify.

PKI's answer is a **certificate**: a digitally signed data structure binding a public key
to an identity. The signature is made by a trusted third party — a Certificate Authority
(CA). Any party who trusts the CA can verify that the certificate's public key genuinely
belongs to the named entity.

---

### X.509 Certificate Structure

An X.509v3 certificate is an ASN.1 DER-encoded structure containing:

```
Certificate ::= SEQUENCE {
    tbsCertificate      TBSCertificate,   -- "to-be-signed" data
    signatureAlgorithm  AlgorithmID,      -- algorithm used to sign tbsCertificate
    signatureValue      BIT STRING        -- CA's signature over tbsCertificate
}

TBSCertificate ::= SEQUENCE {
    version          [0] INTEGER,    -- v3 = 2
    serialNumber         INTEGER,    -- unique per CA; used in revocation
    signature            AlgorithmID, -- must match outer signatureAlgorithm
    issuer               Name,        -- CA's distinguished name
    validity             SEQUENCE {
        notBefore        Time,
        notAfter         Time
    },
    subject              Name,        -- entity this certificate describes
    subjectPublicKeyInfo SEQUENCE {
        algorithm        AlgorithmID, -- RSA, ECDSA, Ed25519, ...
        subjectPublicKey BIT STRING   -- the actual public key
    },
    extensions       [3] SEQUENCE ... -- v3 extensions
}
```

**Key v3 extensions:**

| Extension | Purpose |
|---|---|
| Subject Alternative Name (SAN) | DNS names, IP addresses, email the cert covers |
| Basic Constraints | Is this cert a CA? What is the max path depth? |
| Key Usage | What operations the key may perform (signing, key encipherment) |
| Extended Key Usage | Higher-level usages: TLS server auth, code signing, email |
| Authority Key Identifier | Key ID of the CA that signed this cert |
| Subject Key Identifier | Key ID of this cert's public key |
| CRL Distribution Points | URL(s) to download a Certificate Revocation List |
| Authority Information Access | URL to OCSP responder and issuer certificate |
| Certificate Policies | OID identifying the policy under which the cert was issued |

**Subject vs. SAN:** In modern certificates the `subject` field's CN (Common Name) is
**not** used for hostname matching by TLS clients. RFC 2818 (2000) deprecated CN matching
in favour of the SAN extension. Any certificate used for HTTPS must include the domain
name(s) in the SAN extension. Certificates issued without SAN are rejected by modern
browsers.

---

### Certificate Authority Hierarchy

PKI organises CAs into a hierarchy that limits exposure of the most critical key material.

```
Root CA  (self-signed, offline, physically secured)
    |
    |-- Intermediate CA 1  (online, issues end-entity certs)
    |       |-- End-entity cert A (leaf)
    |       |-- End-entity cert B (leaf)
    |
    |-- Intermediate CA 2  (online, different policy or geography)
            |-- End-entity cert C (leaf)
```

**Root CA:**
- Self-signed certificate (it signs its own certificate; no higher authority)
- The root CA public key is distributed as a **trust anchor** — embedded in operating
  systems, browsers, and libraries by the software vendor
- Root CA private keys are kept **offline** (air-gapped HSMs in physically secured
  facilities with multi-person ceremony requirements)
- Roots rarely issue leaf certificates directly; they sign intermediate CA certificates

**Intermediate CA (Issuing CA):**
- Private key is kept online in an HSM to enable automated certificate issuance
- Issues end-entity (leaf) certificates
- Its certificate is signed by the root (or another intermediate)
- If an intermediate CA is compromised, its certificate can be revoked without revoking the
  root — the blast radius is bounded

**Why intermediates exist:** If the root private key were used for every issuance, it would
need to be online and accessible, vastly increasing compromise risk. With an intermediate
layer, the root key is stored offline. Revoking a compromised intermediate affects far fewer
certificates than revoking a root trust anchor, which would require emergency OS/browser
updates distributed to billions of endpoints.

**Certificate chain validation:**

A TLS server sends its leaf certificate plus any intermediate CA certificates needed to
chain up to a root. The client:

1. Receives the server's certificate chain
2. Verifies each certificate's signature using the issuer's public key
3. Follows the chain until it reaches a self-signed certificate in its trust store
4. If the root is trusted, the chain validates

```
Validation steps (simplified per RFC 5280):
  For each certificate C_i in path (C_0 = leaf, C_n = root):
    1. Check validity period includes today
    2. Verify C_i's signature using the public key in C_{i+1}
    3. Check C_i is not revoked (CRL or OCSP)
    4. Check C_{i+1} has Basic Constraints CA=TRUE
    5. Check C_i's issuer DN matches C_{i+1}'s subject DN
    6. Check Key Usage allows certificate signing for C_{i+1}
    7. Check path length constraint (maxPathLen in Basic Constraints)
```

---

### Certificate Revocation

Certificates have a fixed validity window (typically 90 days for public certs today,
previously up to 2 years). When a private key is compromised before expiry, the certificate
must be revoked.

**Certificate Revocation Lists (CRL):**
- The CA periodically publishes a signed list of revoked serial numbers
- Clients download the CRL from the URL in the cert's `cRLDistributionPoints` extension
- Problems: CRL files can be large, latency between compromise and CRL publication, clients
  cache CRLs — a soft-fail approach means attackers who block CRL downloads allow clients
  to proceed anyway

**Online Certificate Status Protocol (OCSP):**
- Client sends a query to an OCSP responder with the certificate's serial number
- Responder returns a signed status: `good`, `revoked`, or `unknown`
- Fresher than CRLs (responses valid typically 24 hours)
- Problems: privacy leak (OCSP responder learns which sites you visit), extra RTT in the
  TLS handshake, still soft-fail in most deployments

**OCSP Stapling:**
- The **server** fetches its own OCSP response and staples it to the TLS handshake in the
  `status_request` extension
- Client receives the OCSP response during the handshake without a separate network request
- Eliminates the privacy concern (OCSP responder no longer learns client browsing behaviour)
- Response is signed by the CA; the server cannot forge it even though it delivers it
- Server must refresh the stapled response before it expires (typically within 24 hours)

**OCSP Must-Staple (RFC 7633):**
- A certificate extension signalling the client must receive a valid OCSP staple or abort
- Converts OCSP from soft-fail to hard-fail for that certificate
- Protects against an attacker who blocks OCSP responses to extend use of a revoked cert

**The revocation problem summary:** Neither CRL nor OCSP provides reliable hard-fail
revocation at scale without performance and privacy trade-offs. Short-lived certificates
(90 days, now 47 days for many public CAs) reduce the window during which a compromised
certificate can be misused, shifting the industry away from revocation dependency.

---

### Certificate Transparency (CT)

**The problem CT solves:** CAs sometimes issue fraudulent or erroneous certificates (e.g.,
DigiNotar 2011, CNNIC 2015, Symantec 2015-2017). Without independent monitoring, a mis-
issued certificate for `google.com` could be used for months before detection.

**Certificate Transparency (RFC 9162):** A public, append-only log of all issued
certificates. Before a certificate is trusted by Chrome and other major browsers, it must
be logged in at least two CT logs. The CA submits the pre-certificate to CT logs and
receives Signed Certificate Timestamps (SCTs) which are embedded in the final certificate.

```
CT Flow:
  1. CA constructs pre-certificate (identical to final cert except for SCT extension)
  2. CA submits pre-certificate to >= 2 CT logs
  3. Each log returns a Signed Certificate Timestamp (SCT):
     SCT = Log_Key_Sign(timestamp || pre-cert hash)
  4. CA embeds SCTs in the final certificate (or delivers via TLS extension or OCSP)
  5. TLS client verifies >= 2 SCT signatures from distinct, trusted CT logs
  6. Domain operators can monitor logs to detect any cert issued for their domain

CT Log Merkle tree structure:
  - New certs are appended; old certs are never removed (append-only)
  - Log operators publish Signed Tree Heads (STH) periodically
  - Consistency proofs allow anyone to verify no entries were removed
  - Inclusion proofs allow anyone to verify a cert appears in the tree
```

**CT benefits:**
- Domain operators can detect mis-issued certificates within minutes (crt.sh indexes all CT logs)
- Auditors can verify consistency (entries not retrospectively removed)
- CA misbehaviour becomes publicly observable and attributable

**CT limitations:**
- CT proves a certificate existed in the log, not that it is legitimate
- Rogue certificates can still be issued; CT improves detection speed, not prevention
- Monitoring requires domain operators to actively check logs or subscribe to alerting services

---

### Domain Validation, Organisation Validation, Extended Validation

CAs issue certificates under different validation levels:

| Type | What the CA verifies | Notes |
|---|---|---|
| DV (Domain Validated) | Requester controls the domain (via ACME challenge) | Automated; issued in minutes |
| OV (Organisation Validated) | Legal organisation name and domain ownership | Manual vetting; days |
| EV (Extended Validated) | Full vetting: legal existence, physical address, contacts | Expensive; previously showed green bar |

All three types provide the same TLS encryption strength. The difference is in what the
CA verified about the entity behind the certificate.

**ACME protocol (RFC 8555):** Automates DV certificate issuance. Let's Encrypt uses ACME
to issue over 3 million certificates per day.

```
ACME challenge types (proving domain control):
  HTTP-01:      Client places a token at http://<domain>/.well-known/acme-challenge/<token>
                CA retrieves it; match proves HTTP server control
  DNS-01:       Client creates TXT record _acme-challenge.<domain> = <token>
                CA looks it up; proves DNS control (required for wildcard certs)
  TLS-ALPN-01:  Client presents a challenge cert with acme-tls/1 ALPN extension
                Required when HTTP port 80 is inaccessible
```

---

## Tier 1 — Fundamentals

### Question F1
**What does an X.509 certificate contain, and what problem does it solve in TLS?**

**Answer:**

An X.509 certificate binds a **public key** to an **identity** (domain name, person, or
organisation) via a **digital signature from a trusted Certificate Authority (CA)**.

Core contents:
- Subject identity (domain name in the SAN extension)
- The subject's public key (RSA, ECDSA, or other)
- Validity period (notBefore, notAfter)
- Issuer identity (the CA that signed this certificate)
- The CA's digital signature over all of the above (the tbsCertificate portion)
- v3 Extensions: SAN, Key Usage, revocation endpoints, CT SCTs

**Problem it solves in TLS:** Without certificates, a TLS client connecting to `bank.com`
would establish an encrypted connection but could not verify it was talking to the real
`bank.com`. An attacker who intercepts the TCP connection could substitute their own ECDH
key share; the client would encrypt data to the attacker's key. Certificates allow the
client to verify that the server's public key is genuinely associated with `bank.com` —
a trusted CA checked that the domain owner requested that certificate.

**Common mistake:** Believing the certificate itself encrypts data. It does not. The
certificate only authenticates the server's public key. All encryption uses session keys
derived from the ephemeral ECDH exchange.

---

### Question F2
**Explain the chain of trust. Why does a browser trust `example.com`'s certificate even
though the browser has never seen it before?**

**Answer:**

Trust is transitive through a chain of signatures:

1. The browser ships with a list of **trusted root CA certificates** — typically 100-200
   roots — embedded by the OS or browser vendor (Mozilla, Apple, Microsoft, Google).
2. A root CA signs an **intermediate CA certificate**, asserting "this public key belongs
   to this intermediate CA and it may issue certificates."
3. The intermediate CA signs the **server's leaf certificate** for `example.com`.
4. The server presents both its leaf certificate and the intermediate CA certificate during
   the TLS handshake.
5. The browser verifies: the intermediate CA's signature validates the leaf certificate;
   the root's signature (already in the browser's trust store) validates the intermediate.
6. If the chain is valid, not expired, and not revoked, the browser trusts that the leaf
   certificate's public key genuinely belongs to `example.com`.

The browser trusts the root CA because it was pre-installed by the OS or browser vendor
after that CA passed their vetting programme. Trust ultimately rests on the OS/browser
vendor's judgement about which CAs are trustworthy — this is a policy decision, not a
purely technical one.

---

### Question F3
**What is the difference between CRL and OCSP revocation checking? What are the practical
limitations of each?**

**Answer:**

**CRL (Certificate Revocation List):**
- CA publishes a periodically updated signed list of revoked serial numbers
- Client downloads the CRL from a URL in the certificate's CRL Distribution Points extension
- Limitations: files can be very large (megabytes for high-volume CAs), updates may be hours
  to days behind an actual revocation, cached CRLs mean stale data, clients typically use
  soft-fail (proceed if CRL cannot be fetched)

**OCSP (Online Certificate Status Protocol):**
- Client queries a real-time responder with the specific serial number
- Responder returns `good`, `revoked`, or `unknown`
- Limitations: adds one RTT to the TLS handshake, exposes browsing behaviour to the OCSP
  responder (privacy concern), still soft-fail in most deployments

**OCSP Stapling** resolves both latency and privacy: the server fetches its own OCSP
response and includes it in the TLS handshake. The client receives fresh revocation data
without a separate network request.

**Fundamental limitation:** Both mechanisms are soft-fail by default. A sophisticated
attacker can block revocation traffic to extend use of a revoked certificate. Only
OCSP Must-Staple certificates enforce hard-fail behaviour.

---

### Question F4
**What is Certificate Transparency and why was it introduced?**

**Answer:**

Certificate Transparency (CT) is a public, append-only log of all certificates issued by
CAs. Before being trusted by major browsers, a certificate must be logged in at least two
independent CT logs; each log returns a Signed Certificate Timestamp (SCT) that browsers
verify during the TLS handshake.

**Why it was introduced:** Multiple CA incidents demonstrated that CAs could issue
fraudulent certificates (DigiNotar issued certs for `google.com` to Iranian attackers in
2011; CNNIC authorised an intermediate CA that issued fake Google certificates in 2015).
Without CT, these misissued certificates could be used for months before detection.

**What CT provides:**
- Domain operators can monitor CT logs and detect any certificate issued for their domain
  within minutes (services like crt.sh index all public CT logs)
- The Merkle tree structure allows auditors to prove no entries were retroactively removed
- Browser enforcement means certificates cannot be used without appearing in the public log

CT does not prevent misissue — it makes misissue detectable and attributable.

---

## Tier 2 — Intermediate

### Question I1
**Describe the RFC 5280 certificate path validation algorithm. What conditions must hold
for each certificate in the path?**

**Answer:**

RFC 5280 Section 6 defines path validation. Given a chain $C_0$ (leaf) $\to C_1$
(intermediate) $\to \ldots \to C_n$ (trust anchor / root), for each certificate $C_i$:

1. **Signature validity:** $C_i$'s signature verifies using the public key in $C_{i+1}$.
   For the final step, $C_n$'s signature verifies against the trust anchor.

2. **Validity period:** Today's date is within $[C_i.\text{notBefore},\ C_i.\text{notAfter}]$.
   Both boundaries must be checked; accepting a cert before its notBefore is a real
   implementation error (e.g., clock skew exploits in embedded devices).

3. **Revocation status:** $C_i$ has not been revoked. Checked via CRL or OCSP. If the
   check cannot be completed, policy determines whether to fail or proceed.

4. **Issuer/subject name chaining:** $C_i.\text{issuer} = C_{i+1}.\text{subject}$ using
   RFC 5280's DN comparison rules (not simple string comparison — case-folding, whitespace
   normalisation, and encoding normalisation are required).

5. **Basic Constraints for CA certs:** Every non-leaf certificate must have Basic
   Constraints with `cA=TRUE`. A leaf certificate without this flag must not sign other
   certificates; a path where a leaf is used as an issuer must be rejected.

6. **Path length constraint:** If $C_{i+1}$ has `maxPathLen = k` in Basic Constraints, at
   most $k$ certificates may follow it in the path, limiting delegation depth.

Additionally: `keyCertSign` bit in Key Usage must be set for each CA certificate, and
Name Constraints extensions restrict which domains an intermediate CA may certify.

---

### Question I2
**A server presents a certificate chain: leaf cert issued by "Intermediate CA A" which
was issued by "Root CA". The browser has "Root CA" in its trust store. Describe exactly
what cryptographic operations the browser performs to validate this chain.**

**Answer:**

**Step 1 — Order the chain:**
The browser receives the leaf and intermediate certificates from the server and orders them:
leaf ($C_0$) → Intermediate CA A ($C_1$) → Root CA ($C_2$, from trust store).

**Step 2 — Validate the leaf certificate ($C_0$):**
```
a. Parse C_0; extract subject public key, SAN extension, validity, revocation URL
b. Verify signature: SHA-256(C_0.tbsCertificate) verified under C_1's public key
c. Check validity period: notBefore <= now <= notAfter
d. Check SAN contains the requested hostname
e. Check Key Usage is appropriate for the cert's purpose
f. Check revocation: verify stapled OCSP response or fetch from OCSP responder
g. Check CT SCTs: verify >= 2 SCT signatures using the CT logs' public keys;
   SCT timestamps must predate the cert's notBefore
```

**Step 3 — Validate the intermediate CA certificate ($C_1$):**
```
a. Parse C_1; extract public key used in Step 2
b. Verify signature: signed by C_2 (Root CA) using Root CA's public key from trust store
c. Check validity period
d. Check Basic Constraints: cA=TRUE, note maxPathLen value
e. Check Key Usage: keyCertSign bit must be set
f. Check revocation
```

**Step 4 — Anchor at Root CA ($C_2$):**
The Root CA certificate is in the browser's trust store and is a trust anchor. Its
self-signature is not reverified — the trust store entry itself represents the policy
decision to trust this root.

**Step 5 — Final hostname binding:**
Confirm the requested hostname matches a name in $C_0$'s SAN extension. Wildcard rules
apply: `*.example.com` matches `www.example.com` but not `a.b.example.com`.

---

### Question I3
**What is certificate pinning? What are its benefits and dangers, and why have major
browser vendors moved away from it?**

**Answer:**

**Certificate pinning** hardcodes the expected public key (or certificate hash) of a
server's certificate into a client application. When connecting, the client checks that
the received certificate's public key matches the pin, rejecting the connection even if
the certificate is otherwise valid and CA-signed.

**Benefits:**
- Prevents attacks using fraudulently CA-issued certificates: even if a rogue CA issues a
  cert for the pinned domain, the public key will not match
- Protects against CA compromise for specific high-value clients
- Used by mobile apps and enterprise environments where the cert set is known in advance

**Dangers:**
1. **Certificate rotation breaks clients:** When the server rotates its certificate (annual
   renewal), all clients with the old pin stop working until the app is updated. Twitter,
   Facebook, and others have experienced pin-related outages.
2. **Emergency recovery is difficult:** If a private key is compromised and the certificate
   must be replaced urgently, updating pins across all deployed clients takes days or weeks.
3. **HPKP-based ransom attacks:** HTTP Public Key Pinning (RFC 7469) allowed a malicious
   or compromised website to set pins that permanently locked users out of the site.

**Why HPKP was removed:** Chrome removed HPKP support in 2017, Firefox in 2020.
- Operators frequently misconfigured pins and locked themselves out of their own sites
- Malicious actors could set long-duration pins as a denial-of-service weapon
- The security benefit was small relative to the operational fragility

**Current approach:** Mandatory Certificate Transparency with short-lived certificates
(47-90 days) and robust CT monitoring provides comparable security without the fragility
of pinning. Expect-CT and CAA DNS records provide additional protection.

---

## Tier 3 — Advanced

### Question A1
**The CA/Browser Forum has progressively reduced maximum TLS certificate validity from
825 days (2018) to 398 days (2020), with proposals for 47 days. Analyse the cryptographic
and operational implications of this trend.**

**Answer:**

**Security improvements from shorter validity:**

1. **Reduced revocation dependency:** A compromised private key can be abused only until
   expiry. At 47-day validity, even without revocation infrastructure, the window is under
   two months. This reduces operational dependency on CRL and OCSP mechanisms that are
   fundamentally soft-fail.

2. **Forced cryptographic agility:** Short-lived certificates require automated renewal
   infrastructure. Any migration to new algorithms (e.g., post-quantum signatures) rolls
   out within 47 days — old certs simply expire. Long-lived certs can embed deprecated
   signature algorithms for years after they should have been retired.

3. **Faster security policy enforcement:** New baseline requirements (e.g., mandatory
   CT SCTs, stricter key usage) reach 100% of active certificates sooner when certs cycle
   rapidly.

4. **CAA record effectiveness:** DNS CAA records specify which CAs may issue for a domain.
   Misissued certs issued before a CAA record was added expire sooner.

**Operational degradations requiring redesign:**

1. **Manual management becomes impossible:** Downloading a PFX file from a CA portal and
   manually installing it every 47 days is not viable at scale. All infrastructure must
   support ACME (RFC 8555) or equivalent automated renewal. Any server that cannot reach
   an ACME CA will fail with an expired certificate.

2. **Infrastructure pipeline changes:** Certificates baked into container images, load
   balancer configs, API gateways, or TLS termination proxies must be dynamically fetched
   from a secrets manager at startup — not embedded at build time.

3. **Non-HTTP services:** ACME HTTP-01 assumes port-80 reachability. Databases, gRPC
   services, and MQTT brokers may require DNS-01 challenges, which in turn require API
   access to the DNS provider — automation many organisations lack.

4. **Monitoring overhead:** Higher cert turnover generates more CT log entries. Domain
   monitoring tools must handle higher volumes to detect misissued certificates quickly.

**Net assessment:** The trend is correct. Let's Encrypt demonstrates (>3 million certs/day)
that ACME automation is mature. The security gain — reduced revocation dependence, faster
cryptographic agility — outweighs operational cost for well-managed infrastructure. Legacy
on-premises software that was never designed for automated renewal will bear the greatest
pain.

---

### Question A2
**Describe two real-world CA compromise incidents. For each, explain what technical or
process failure occurred, how it was detected, and what systematic changes resulted.**

**Answer:**

**Incident 1 — DigiNotar (2011):**

DigiNotar was a Dutch CA trusted by all major browsers. In June–July 2011, attackers
(believed to be Iranian state-sponsored) compromised DigiNotar's infrastructure and issued
fraudulent wildcard certificates including `*.google.com`.

Technical failure:
- DigiNotar's CA servers were internet-connected with inadequate network segmentation
- Attackers gained unrestricted access to the CA signing software
- Over 531 fraudulent certificates were issued; DigiNotar's internal monitoring failed to
  detect the compromise for weeks

Detection:
- The `*.google.com` certificate was used against Iranian Gmail users
- A user noticed the certificate fingerprint did not match Google's actual certificate
  (Chrome had Google's certificate pinned)
- Public disclosure: August 28, 2011

Response and industry changes:
- DigiNotar was removed from all browser trust stores within days; the company filed for
  bankruptcy
- Accelerated development and deployment of Certificate Transparency
- Google began requiring CT for all certificates trusted by Chrome
- CA/Browser Forum strengthened audit requirements (annual WebTrust audits, network
  security guidelines for CA systems)

**Incident 2 — Symantec/VeriSign (2015-2018):**

Symantec (owner of VeriSign, Thawte, GeoTrust, RapidSSL) issued thousands of certificates
violating CA/Browser Forum baseline requirements — including test certificates for
`google.com` and certificates without proper domain validation.

Technical failure:
- Symantec delegated issuance to Registration Authorities (RAs) without adequate oversight
- RAs bypassed domain validation requirements for internal testing
- Investigation found over 30,000 non-compliant certificates issued over several years

Detection:
- Google's Certificate Transparency team identified anomalous issuance patterns in CT logs
- Public disclosure began March 2017; Symantec's repeated compliance assurances were
  later shown to be inaccurate

Response and industry changes:
- Google Chrome progressively distrusted Symantec-issued certificates; full distrust
  from October 2018
- Symantec's CA business was acquired by DigiCert in 2017; all existing certificates
  were reissued under DigiCert infrastructure
- CT log monitoring became a mandatory Chrome requirement (April 2018)
- CA/B Forum Baseline Requirements were strengthened regarding RA oversight; annual audits
  of subCAs (technically-constrained intermediates) were mandated
- The incident demonstrated that CT monitoring could detect systemic mis-issuance at a
  scale previously invisible, validating CT as a security mechanism
