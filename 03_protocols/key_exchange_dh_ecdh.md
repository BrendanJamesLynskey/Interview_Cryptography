# Key Exchange: Diffie-Hellman and ECDH

## Prerequisites
- Modular arithmetic and the discrete logarithm problem
- Elliptic curve point addition and scalar multiplication
- Basic public-key infrastructure concepts
- Understanding of forward secrecy and session key derivation

---

## Concept Reference

### The Key Exchange Problem

Two parties communicating over an authenticated but insecure channel need to establish a
shared secret that a passive eavesdropper cannot derive. Before Diffie-Hellman (1976), the
only solution was to share a secret out-of-band in advance. Diffie-Hellman solved this by
constructing a computation that both parties can complete to the same result, but which
reveals nothing useful to an observer who sees only the messages exchanged.

---

### Finite-Field Diffie-Hellman (FFDH)

**Public parameters:** A large prime $p$ and a generator $g$ of $\mathbb{Z}_p^*$ (or a
large prime-order subgroup of it). These are standardised and publicly known.

**Protocol:**

```
Setup (public):  prime p, generator g

Alice:                              Bob:
Choose random a (2 <= a <= p-2)     Choose random b (2 <= b <= p-2)
Compute A = g^a mod p               Compute B = g^b mod p
Send A to Bob  ------------------>  Send B to Alice
              <------------------
Compute S = B^a mod p               Compute S = A^b mod p

Both arrive at S = g^(ab) mod p
```

**Why it works:** $B^a = (g^b)^a = g^{ab} = (g^a)^b = A^b \pmod{p}$. The commutative
property of exponents means both parties compute the same value. An eavesdropper sees $g$,
$p$, $A = g^a \bmod p$, and $B = g^b \bmod p$, but recovering $a$ from $A$ is the
**discrete logarithm problem (DLP)** — believed to be computationally infeasible for
sufficiently large $p$.

**Security parameter sizing:**

```
Target security  |  RSA/DH prime size  |  ECC key size
128-bit          |  3072 bits          |  256 bits
192-bit          |  7680 bits          |  384 bits
256-bit          |  15360 bits         |  521 bits
```

FFDH with a 2048-bit prime provides approximately 112 bits of security — below the modern
128-bit target. This is why ECDH has largely superseded FFDH.

**FFDH in practice:** RFC 7919 defines "safe primes" for FFDH where $p = 2q + 1$ with $q$
also prime. Using a safe prime ensures the subgroup order is $q$, preventing small-subgroup
attacks. TLS 1.3 supports FFDHE2048 through FFDHE8192 groups (RFC 7919 named groups).

**Vulnerability — small subgroup attacks:** If the group order is smooth (has many small
factors), an attacker can force the key exchange into a small subgroup by sending a
specially crafted public key, revealing bits of the private key through the Pohlig-Hellman
algorithm. Safe primes and subgroup order validation prevent this.

---

### Elliptic Curve Diffie-Hellman (ECDH)

ECDH replaces the multiplicative group $\mathbb{Z}_p^*$ with the group of points on an
elliptic curve $E(\mathbb{F}_p)$ or $E(\mathbb{F}_{2^m})$.

**Public parameters:** A named curve (e.g., P-256, X25519), base point $G$ of prime order
$n$, and the curve equation.

**Protocol:**

```
Setup (public):  curve E, base point G of order n

Alice:                              Bob:
Choose random a (1 <= a <= n-1)     Choose random b (1 <= b <= n-1)
Compute A = a * G  (EC scalar mul)  Compute B = b * G  (EC scalar mul)
Send A to Bob  ------------------>  Send B to Alice
              <------------------
Compute S = a * B                   Compute S = b * A

Both arrive at S = ab * G
Shared secret = x-coordinate of S
```

The eavesdropper sees $G$, $A = aG$, and $B = bG$. Recovering $a$ from $A$ is the
**elliptic curve discrete logarithm problem (ECDLP)** — no sub-exponential algorithm is
known for properly chosen curves. The best known attack (Pollard's rho) runs in
$O(\sqrt{n})$ time.

**X-coordinate extraction:** The shared secret is typically the x-coordinate of the point
$S$, not the full point. This is because $(x, y)$ and $(x, -y)$ both represent valid points
with the same $x$-coordinate, and including $y$ would cause different results if the two
parties happen to negate the point differently.

---

### Named Curves

**P-256 (secp256r1, prime256v1):**
- 256-bit prime field $\mathbb{F}_p$ with NIST-chosen parameters
- Security level: ~128 bits
- Curve: $y^2 = x^3 - 3x + b \pmod{p}$
- Used in: TLS 1.3, HTTPS, S/MIME, code signing
- Concern: The NIST curve constants were generated with a "nothing-up-my-sleeve" seed that
  was never fully explained, raising theoretical but unproven concerns about backdoors

**P-384 (secp384r1):**
- 384-bit field, ~192-bit security level
- Required for NSA Suite B at SECRET classification level
- Slower than P-256; used where higher security margins are mandated

**X25519 (Curve25519):**
- Bernstein's 2005 curve over $\mathbb{F}_{2^{255}-19}$
- Security level: ~128 bits (same as P-256)
- Designed for safety: resistant to implementation errors, cofactor is 8 (not prime order)
- The Montgomery ladder scalar multiplication is constant-time by construction
- No mysterious constants: the parameter $A = 486662$ was chosen as the smallest value
  producing a curve with good security properties
- X25519 specifies only the x-coordinate Diffie-Hellman function, not full point
  representation — this eliminates many classes of invalid-point attacks
- Preferred in modern deployments: TLS 1.3, SSH, Signal Protocol, WireGuard

**X448 (Curve448-Goldilocks):**
- 448-bit field, ~224-bit security level
- Similar design philosophy to X25519; slower but higher security margin
- Used when 128-bit security is considered insufficient

```
Performance comparison (approximate, software, 64-bit platform):
  X25519:    ~100 µs per scalar multiplication
  P-256:     ~150 µs per scalar multiplication (optimised)
  P-384:     ~350 µs per scalar multiplication
  FFDHE3072: ~3000 µs per modular exponentiation
```

---

### Forward Secrecy (Perfect Forward Secrecy)

**Definition:** Forward secrecy is the property that compromise of the long-term private key
does not enable decryption of previously recorded sessions.

**Why static DH fails:** In static DH, the server's private key $a$ is long-lived and used
in every connection. An attacker who records the server's public key $A$ and all client
ephemeral public keys $B_1, B_2, \ldots$ can compute $S_i = a \cdot B_i$ retrospectively
once the server's private key is compromised. All past sessions are decryptable.

**Why ephemeral DH achieves forward secrecy:**

```
Ephemeral DH (ECDHE):
  Per-session:  server generates fresh (a_i, A_i) for each connection
  After session: a_i is immediately discarded
  
  Attacker later compromises server long-term key:
  - Can verify server's identity (the long-term key was used only for signing)
  - Cannot compute a_i (it was never stored, only existed in RAM during the session)
  - Cannot decrypt any recorded session
```

The term "Perfect Forward Secrecy" (PFS) is sometimes preferred to distinguish ephemeral
key exchange from protocols like DTLS or IKEv2 that have partial forward secrecy properties.
RFC 8446 consistently uses "forward secrecy" without "perfect".

**Implementation requirement:** Forward secrecy is only real if the ephemeral private key is
genuinely discarded after use. If the server logs ephemeral private keys (for debugging or
key escrow), forward secrecy is lost. This is a deployment and operational security concern,
not a protocol weakness.

---

### ECDH with Key Derivation: HKDF

The raw shared secret $S$ (the x-coordinate of $aB$) is not used directly as a symmetric
key. It is passed through a key derivation function:

```python
# ECDH key derivation (simplified, as in TLS 1.3 and Signal)
shared_point = scalar_multiply(a, B)          # a * B on the curve
raw_secret   = shared_point.x_coordinate      # 32 bytes for X25519

# Key derivation with HKDF
ikm  = raw_secret
salt = b""                                    # or a protocol-specific salt
info = b"protocol-label"
key  = HKDF(ikm, salt, info, length=32)
```

**Why KDF is necessary:**
1. The EC x-coordinate is not uniformly random — it has the distribution of x-coordinates
   of random curve points, which differs slightly from uniform. HKDF-Extract normalises it.
2. Multiple keys (encryption key, IV, authentication key) can be derived from one DH
   exchange without correlating them cryptographically.
3. The `info` parameter allows domain separation: the same DH exchange can produce
   independent keys for different protocol layers by using different info strings.

---

### Station-to-Station Protocol (STS) and Authentication

**The problem with unauthenticated DH:** Vanilla ECDH provides no authentication. A
man-in-the-middle can intercept both public keys and substitute their own:

```
Alice ---> A = aG ----------> MitM (Eve) ---> A' = eG ----------> Bob
Alice <--- B' = e'G <-------- MitM (Eve) <--- B = bG <----------- Bob

Alice computes shared secret with Eve.
Bob computes shared secret with Eve.
Eve decrypts and re-encrypts all traffic.
```

Neither Alice nor Bob detects the attack because ECDH provides only **key agreement**, not
**authentication**.

**Station-to-Station (STS) protocol** adds authentication via signatures:

```
1. Alice sends: A = aG
2. Bob sends:   B = bG, Sig_Bob(A || B)
3. Alice verifies Bob's signature; sends: Sig_Alice(A || B)
4. Both derive session key from aB = bA
```

Bob's signature over $(A \| B)$ proves Bob knows the private key corresponding to his
long-term public key. Alice's signature proves the same. The signatures bind the long-term
identities to the specific ephemeral key exchange.

TLS 1.3 uses this pattern: the server signs the handshake transcript (which includes both
key shares) in `CertificateVerify`. The signature covers the specific ephemeral keys of
this session, preventing key-forwarding attacks.

---

## Tier 1 — Fundamentals

### Question F1
**Describe the basic Diffie-Hellman key exchange protocol. What is the hard problem it
relies on, and why does the protocol work?**

**Answer:**

Both parties agree on public parameters: a large prime $p$ and generator $g$.

1. Alice chooses a random private key $a$ and computes $A = g^a \bmod p$. She sends $A$.
2. Bob chooses a random private key $b$ and computes $B = g^b \bmod p$. He sends $B$.
3. Alice computes $S = B^a \bmod p = g^{ab} \bmod p$.
4. Bob computes $S = A^b \bmod p = g^{ab} \bmod p$.

Both compute the same $S$ because exponentiation is commutative: $(g^b)^a = g^{ab} = (g^a)^b$.

The security relies on the **discrete logarithm problem**: given $g$, $p$, and $A = g^a \bmod p$,
finding $a$ is believed to be computationally infeasible for large $p$. An eavesdropper who
sees $A$ and $B$ cannot compute $g^{ab}$ without solving DLP.

**Common mistakes:**
- Confusing DH key agreement with encryption — DH produces a shared secret, it does not
  encrypt or authenticate any data on its own.
- Forgetting that vanilla DH provides no authentication. An active attacker (MitM) can
  substitute their own keys and compromise both sides.

---

### Question F2
**What is the key difference between FFDH and ECDH? Why is ECDH preferred in modern systems?**

**Answer:**

Both protocols achieve the same goal (shared secret from public key exchange) but use
different mathematical groups:

- **FFDH** uses the multiplicative group $\mathbb{Z}_p^*$. The hard problem is the classical
  discrete logarithm in a finite field. Sub-exponential index-calculus algorithms exist, so
  keys must be 2048+ bits to achieve 112-bit security.

- **ECDH** uses an elliptic curve group $E(\mathbb{F}_p)$. The hard problem is the elliptic
  curve discrete logarithm. No sub-exponential algorithm is known for properly chosen
  curves, so only 256-bit keys are needed for 128-bit security.

ECDH is preferred because:
1. **Key size**: 256-bit ECDH key vs. 3072-bit FFDH key for equivalent security — smaller
   keys mean faster key generation, faster handshakes, and smaller network messages.
2. **Computation speed**: EC scalar multiplication is faster than modular exponentiation
   at comparable security levels.
3. **Bandwidth**: Smaller public keys reduce ClientHello and ServerHello message sizes in TLS.

---

### Question F3
**What is forward secrecy and how does ephemeral key exchange provide it?**

**Answer:**

Forward secrecy is the property that compromise of a server's long-term private key does
not enable an adversary to decrypt previously recorded sessions.

Without forward secrecy (e.g., TLS 1.2 with static RSA), the server's long-term RSA private
key directly decrypts the session's pre-master secret. An attacker who recorded past traffic
and later steals the private key can decrypt all of it.

With ephemeral ECDH (ECDHE):
- The server generates a fresh EC key pair $(a_i, A_i)$ for each session.
- The session key is derived from the ephemeral $a_i$ and the client's ephemeral public key.
- After the session, $a_i$ is discarded from memory.
- The server's long-term key is used only to sign the handshake (authentication), never to
  encrypt keying material.

Even if the long-term key is stolen years later, the attacker cannot recover $a_i$ (it no
longer exists) and therefore cannot derive the session key from recorded traffic.

**Common mistake:** Believing that "ephemeral" alone guarantees forward secrecy. It does
only if the ephemeral private key is genuinely deleted after use. Systems that log session
keys (for lawful intercept or debugging) lose forward secrecy at the operational level.

---

### Question F4
**Why is X25519 often preferred over P-256 for new deployments, given that both offer
approximately the same 128-bit security level?**

**Answer:**

X25519 has several practical advantages over P-256:

1. **Constant-time by construction:** The X25519 function uses the Montgomery ladder
   algorithm. Because the ladder performs the same sequence of operations regardless of the
   scalar value, it is inherently resistant to timing side-channel attacks. P-256
   implementations must explicitly add constant-time measures.

2. **Cofactor robustness:** Curve25519 has cofactor 8. The X25519 function specification
   includes cofactor clearing (multiplying by 8), which eliminates small-subgroup attacks
   against the shared secret without requiring explicit point validation.

3. **No invalid-point attacks:** X25519 operates only on x-coordinates; sending a point
   not on the curve is impossible in the x-only representation, eliminating invalid-curve
   attacks that affect full-point Weierstrass implementations.

4. **Transparent parameters:** The curve constant $A = 486662$ was selected as the smallest
   working value. The NIST P-256 seed is an unexplained SHA-1 hash, raising theoretical
   (though unproven) concerns about hidden weaknesses.

5. **Performance:** X25519 is typically faster than P-256 in software on 64-bit platforms.

The main reason to choose P-256 is compatibility: it is required by some older TLS stacks,
FIPS 140 compliance environments, and government specifications that mandate NIST curves.

---

## Tier 2 — Intermediate

### Question I1
**Describe the small-subgroup attack against FFDH. What conditions make a group vulnerable,
and what countermeasures prevent it?**

**Answer:**

**The attack:**

If the order $N$ of the group $\mathbb{Z}_p^*$ has small factors $q_1, q_2, \ldots$, the
Pohlig-Hellman algorithm decomposes the DLP into a system of smaller DLPs modulo each
$q_i$, then combines results via CRT. If $N$ is smooth (all factors small), the DLP becomes
tractable.

A stronger form: if the attacker controls one party's public key, they can send a value
$g^{p/q}$ (a generator of the order-$q$ subgroup) as their "public key". The legitimate
party computes a shared secret that lies in the small subgroup. The attacker then queries
the result with $q$ trial values (at most) to determine the victim's private key modulo $q$.
Combining multiple such queries with different small subgroups reveals the full private key.

**Vulnerable condition:** $p - 1$ (the group order) has small prime factors.

**Countermeasures:**

1. **Safe primes:** Use $p = 2q + 1$ where both $p$ and $q$ are prime. The subgroup of
   quadratic residues has prime order $q$; there are no small subgroups to exploit. RFC 7919
   named groups (FFDHE2048 through FFDHE8192) all use safe primes.

2. **Public key validation:** Verify that the received public key $A$ satisfies
   $2 \leq A \leq p - 2$ and $A^q \equiv 1 \pmod{p}$. The second check confirms membership
   in the order-$q$ subgroup, rejecting any element of a small subgroup.

3. **Use ECDH with prime-order groups:** P-256 and X25519 groups have prime order (or use
   cofactor clearing), eliminating the small-subgroup structure entirely.

---

### Question I2
**TLS 1.3 uses X25519 as its default key exchange group. Walk through how both client and
server would derive the same 32-byte shared secret, starting from their random private
scalars. What function is actually computed?**

**Answer:**

X25519 computes the x-coordinate of a scalar multiple of a curve point using the
Montgomery curve $y^2 = x^3 + 486662x^2 + x$ over $\mathbb{F}_{2^{255} - 19}$.

**Client side:**
```
client_private = 32 random bytes (masked: set bits 0,1,2 of byte 0 to 0,
                                            set bit 7 of byte 31 to 0,
                                            set bit 6 of byte 31 to 1)
client_public  = X25519(client_private, base_point_u=9)
                 -- 32-byte output: u-coordinate of client_private * G
```

**Server side:**
```
server_private = 32 random bytes (same masking)
server_public  = X25519(server_private, base_point_u=9)
```

**After exchange:**
```
Client computes: shared = X25519(client_private, server_public_u)
Server computes: shared = X25519(server_private, client_public_u)

Both arrive at:  u-coordinate of (client_private * server_private * G)
```

The bit masking (clamping) serves specific purposes:
- Clearing the low 3 bits of byte 0 multiplies the scalar by 8, performing cofactor
  clearing — this ensures the result is always in the prime-order subgroup, preventing
  small-subgroup leakage
- Setting bit 6 of byte 31 and clearing bit 7 ensures the scalar is in $[2^{254}, 2^{255})$,
  making scalar multiplication constant-time by fixing the top bit

The 32-byte output of `X25519` is not used directly as a key — in TLS 1.3 it is passed
to `HKDF-Extract` as the IKM to produce the Handshake Secret.

---

### Question I3
**Compare the security assumptions underlying FFDH and ECDH against quantum computers.
If a 2048-bit FFDH group and a 256-bit ECDH group both offer approximately 112-bit
classical security, what quantum security do they provide and why?**

**Answer:**

**Against Shor's algorithm:**

Both FFDH and ECDH are broken by Shor's algorithm, but the qubit requirements differ:

```
Algorithm          Classical security  Qubits needed (logical)   Status
FFDHE2048          ~112 bits           ~4000 logical qubits       Broken by Shor's
ECDH P-256         ~128 bits           ~2500 logical qubits       Broken by Shor's
```

Shor's algorithm for the DLP in $\mathbb{Z}_p^*$ requires approximately $2 \log_2 p$
qubits and runs in $O((\log p)^2)$ quantum operations. For ECDLP it requires approximately
$9 \log_2 n + O(\log \log n)$ qubits (n is group order). The ECDLP circuit is larger per
bit of security but smaller in absolute terms because ECC uses smaller groups.

**Key point:** Both schemes provide **zero** quantum security. A sufficiently large quantum
computer (thousands of fault-tolerant logical qubits) breaks either completely. The
difference in qubit count is practically irrelevant; neither will resist a cryptographically
relevant quantum computer.

**Against Grover's algorithm:**

Grover's algorithm does not apply to DLP or ECDLP — it provides a generic search speedup
for unstructured problems (like finding hash preimages), not for algebraically structured
problems like DLP where Shor's gives polynomial-time speedup.

**Consequence for migration:** Any system using FFDH or ECDH for key exchange needs to
migrate to a post-quantum algorithm (e.g., ML-KEM / Kyber) to resist quantum attack. NIST
completed standardisation of ML-KEM (FIPS 203) in 2024. TLS 1.3 supports hybrid key
exchange (X25519Kyber768) that provides classical and quantum security simultaneously.

---

### Question I4
**What is the Logjam attack and what does it reveal about the security of Diffie-Hellman
in practice?**

**Answer:**

**The Logjam attack (2015):**

Logjam exploited two weaknesses simultaneously:

1. **Export cipher suite downgrade:** TLS servers that still supported DHE-EXPORT cipher
   suites could be forced by an active attacker to negotiate DH with a 512-bit prime. This
   was a legacy of 1990s US export regulations that limited key sizes to 512 bits.

2. **Shared prime exploitation:** Over 92% of HTTPS servers, 98% of SMTP with STARTTLS
   servers, and 26% of SSH servers that supported export-grade DH used one of only two
   primes (a 512-bit prime from OpenSSL and another from Apache). The researchers
   precomputed the NFS sieve for both primes (taking several weeks on a cluster), reducing
   online per-connection attacks to minutes.

**What Logjam revealed about DH security:**

- **The cost of precomputation is amortised:** The discrete logarithm algorithms (NFS for
  fields, GNFS) consist of a slow precomputation phase (sieve) and a fast per-instance
  phase. The precomputation is done once per prime; the per-target cost is much lower. A
  government-scale attacker could precompute sieve tables for the handful of standardised
  primes (1024-bit) used across the internet and then break any individual session quickly.

- **1024-bit DH is insufficient:** The researchers estimated that NSA-scale resources could
  crack 1024-bit DH. NSA and GCHQ documents (Snowden) corroborated this. NIST recommends
  a minimum of 2048 bits for current deployments, 3072 bits for 128-bit security targets.

- **Group diversity matters:** If every server used a different prime, the amortised
  precomputation benefit disappears. RFC 7919 FFDHE groups are common but fixed by the
  RFC; for maximum security, ECDH with named curves (which cannot benefit from NFS
  precomputation) is preferable.

**Countermeasures applied after Logjam:**
- Remove all DHE-EXPORT and SSL_EXPORT cipher suites from server configurations
- Upgrade minimum DH prime size to 2048 bits
- Prefer ECDHE over FFDHE to avoid NFS precomputation entirely
- TLS 1.3 removed all export ciphers and all static/non-forward-secret key exchange

---

## Tier 3 — Advanced

### Question A1
**Describe the invalid-curve attack against ECDH implementations that use full Weierstrass
point representation. How does it extract the server's private key, and why does X25519
prevent it?**

**Answer:**

**The attack (Jager, Schwenk, Somorovsky, 2015 and earlier):**

In ECDH with full point representation (Weierstrass short form), the server receives a
client public key $(x, y)$ and computes the shared secret as $S = a \cdot (x, y)$ where
$a$ is the server's private key.

A vulnerable implementation that does not verify that $(x, y)$ lies on the specified curve
will accept points from other curves. An attacker deliberately sends points on a
**different** curve — one with a small group order $r$ (e.g., $r = 3, 5, 7, \ldots$).

```
Attack procedure:
  For small prime r:
    Find a point P of order r NOT on the target curve E
    (but satisfying a*P on the "wrong" curve with group order r)
    
    Send P as the "client public key"
    Server computes S = a * P  (on the wrong curve)
    Shared secret S is one of r possible values
    
    Attacker tries all r values: the correct one is accepted
    This reveals: a mod r
    
  Collect congruences: a ≡ c_1 (mod r_1), a ≡ c_2 (mod r_2), ...
  Chinese Remainder Theorem: recover a mod (r_1 * r_2 * ...)
  Repeat with enough small primes until product exceeds group order n
```

For a 256-bit curve, the attacker needs primes summing to ~256 bits. Finding suitable small
curves near each parameter set requires effort, but numerous such curves exist.

**Why X25519 prevents this:**

1. **X-coordinate only:** X25519 takes and returns only the u-coordinate of a point. The
   v-coordinate is never used. Because the adversary cannot specify a full $(u, v)$ pair,
   they cannot unambiguously specify a point on a specific "target" curve of their choosing
   — the incomplete specification prevents the attack.

2. **Twist security:** Curve25519 is designed so that its quadratic twist (the "other" curve
   sharing the same u-coordinates) has a large prime-order subgroup. All u-coordinates
   correspond to valid points on either the curve or its twist, both with large prime group
   orders. No small-order subgroups are accessible via u-coordinate manipulation.

3. **Cofactor clearing:** The X25519 function multiplies by 8 (cofactor), ensuring the
   result is always in the large prime-order subgroup of the original curve or twist.

**Countermeasure for Weierstrass curves:**
Any ECDH implementation using full point representation must validate that the received
point satisfies the curve equation $y^2 \equiv x^3 + ax + b \pmod{p}$ and that the point
has the expected order before computing the shared secret. NIST SP 800-56A specifies this
validation as a requirement.

---

### Question A2
**A client and server negotiate TLS 1.3 with X25519 key exchange. The server is deployed
on an HSM that exposes only PKCS#11 operations. Describe how the ECDH operation must be
structured when the server's long-term private key cannot leave the HSM, but the ephemeral
key pair can be generated in software. What operations go to the HSM, and what stays in
software?**

**Answer:**

In TLS 1.3 with X25519, the long-term private key is used only for the `CertificateVerify`
signature. The ephemeral ECDH key pair is used for key agreement.

**Operations and their placement:**

```
Operation                               Location        Reason
--------------------------------------  --------------  -----------------------------------
Generate ephemeral key pair (a, A)      Software        Ephemeral keys have no value after
                                                        the session; HSM storage is wasted
Compute X25519(a, client_pub_key)       Software        Uses ephemeral a; no HSM needed
HKDF key derivation                     Software        Only uses derived secrets, no LTK
CertificateVerify signature             HSM             Uses long-term private key
                                                        (ECDSA or RSA); must not leave HSM
```

**PKCS#11 call for CertificateVerify:**

```c
// Sign the transcript hash with the long-term key stored on the HSM
CK_MECHANISM mechanism = {CKM_ECDSA, NULL, 0};  // for ECDSA with P-256
CK_BYTE transcript_hash[32];  // SHA-256 of full handshake transcript up to CertificateVerify
// PKCS#11 pre-hashes or signs the hash depending on mechanism

rv = C_Sign(session,
            transcript_hash, sizeof(transcript_hash),
            signature, &sig_len);
```

The `CertificateVerify` in TLS 1.3 covers:
```
64 bytes of 0x20  ||  "TLS 1.3, server CertificateVerify"  ||  0x00  ||  Transcript-Hash
```
This context string prevents the signature from being reusable across protocols.

**Key insight:** Because TLS 1.3 separates authentication (long-term key, HSM) from key
agreement (ephemeral, software), the HSM is only invoked once per handshake — for the
signature. The DHE computation is done entirely in software with the ephemeral key pair
that lives only in RAM for the duration of the handshake.

**Contrast with TLS 1.2 RSA key exchange:** In TLS 1.2 with static RSA, the server's HSM
would need to decrypt the client-encrypted pre-master secret — one RSA decryption per
handshake, with the long-term key directly involved in key agreement. This is slower,
requires HSM involvement in the critical path, and provides no forward secrecy.
