# Zero Knowledge Proofs — Cryptography Interview Questions

**Subject:** Cryptography
**Topic:** Zero Knowledge Proofs, Schnorr, Sigma Protocols, zk-SNARKs, zk-STARKs
**Difficulty tiers:** Fundamentals / Intermediate / Advanced

---

## Fundamentals

### Q1. What is a zero-knowledge proof, and what are the three properties it must satisfy?

**Answer:**

A **zero-knowledge proof (ZKP)** is a cryptographic protocol that lets a **prover** convince a **verifier** that a statement is true, without revealing any additional information beyond the truth of the statement.

**The three properties:**

1. **Completeness:** If the statement is true and both parties follow the protocol honestly, the verifier accepts.

2. **Soundness:** If the statement is false, no cheating prover can convince the verifier (except with negligible probability).

3. **Zero-knowledge:** If the statement is true, the verifier learns nothing beyond that fact. The verifier could simulate the conversation without the prover, so the conversation reveals no useful information.

**The classic intuition — "Ali Baba's cave":**

Imagine a circular cave with a magic door at the back, openable only with a secret password. Peggy (the prover) wants to convince Victor (the verifier) that she knows the password, without revealing it.

1. Peggy enters the cave, randomly picks left or right at the fork.
2. Victor waits outside the entrance, unable to see which way Peggy went.
3. Victor calls out "come out left" or "come out right".
4. If Peggy went the way Victor asked, she comes out directly. If not, she uses the magic door (requiring the password).
5. After many rounds, if Peggy always comes out from the requested side, Victor is convinced she knows the password — but he's never seen the password.

This satisfies all three properties: complete (if Peggy knows the password, she always succeeds), sound (if she doesn't know it, she can only succeed by chance), and zero-knowledge (Victor learns nothing about the password).

**Real-world ZKPs:**

The cave is illustrative but not practical. Real ZKPs use mathematical structures:

- **Schnorr identification:** prove knowledge of a discrete logarithm.
- **zk-SNARKs:** prove arbitrary computations (used in Zcash, Ethereum rollups).
- **zk-STARKs:** similar but without a trusted setup.
- **Bulletproofs:** prove range membership efficiently.

**Why ZKPs matter:**

1. **Privacy.** Prove you're over 18 without revealing your birthdate. Prove you have enough money without revealing the amount.

2. **Authentication without password transmission.** Prove you know the password without sending it (like Schnorr).

3. **Blockchain scaling.** zk-rollups prove the validity of many transactions without revealing the details (for privacy) or replaying them all (for scalability).

4. **Verifiable computation.** A weak client can outsource a computation and verify the result is correct without redoing the work.

**Interactive vs non-interactive:**

- **Interactive ZKP:** prover and verifier exchange messages back and forth (like the cave).
- **Non-interactive ZKP (NIZK):** the prover sends a single message; the verifier checks it. Useful for blockchains where the verifier may not be online.

The **Fiat-Shamir transform** converts interactive proofs to non-interactive by replacing the verifier's random challenges with a hash of the prover's commitments.

### Q2. Describe the Schnorr identification protocol.

**Answer:**

The **Schnorr identification protocol** (Schnorr, 1989) lets a prover demonstrate knowledge of a discrete logarithm without revealing it. It's the foundation of many modern cryptographic protocols.

**Setup:**

A cyclic group `G` of prime order `q` with generator `g`. The prover Peggy has a secret `x` (her private key) and the public key `y = g^x mod p`.

**The protocol:**

1. **Commit:** Peggy picks a random `r` in [0, q-1] and computes `t = g^r mod p`. She sends `t` to Victor.

2. **Challenge:** Victor picks a random `c` in [0, q-1] and sends it to Peggy.

3. **Response:** Peggy computes `s = r + c*x mod q` and sends `s` to Victor.

4. **Verify:** Victor checks that `g^s = t * y^c mod p`. If yes, accept; otherwise reject.

**Why it works:**

Substitute Peggy's response into the verification equation:

```
g^s = g^(r + c*x) = g^r * g^(c*x) = g^r * (g^x)^c = t * y^c
```

If Peggy knows the secret `x`, she can correctly compute `s` and the equation holds.

**Why it's zero-knowledge:**

Victor sees `(t, c, s)`. None of these reveals `x`:
- `t = g^r` is uniformly random (since `r` is random).
- `c` is Victor's own random choice.
- `s = r + c*x` is uniformly random because `r` is random and unknown to Victor.

Furthermore, a simulator can produce a valid-looking transcript without knowing `x`: pick `c` and `s` first, then compute `t = g^s * y^(-c)`. The triple `(t, c, s)` looks identical to a real transcript but reveals nothing about `x`.

**Why it's sound:**

If Peggy doesn't know `x`, she can't pre-compute `t` and then answer any challenge `c`. She'd have to commit to `t`, then answer the random `c` — which she can only do correctly if she knows `x` (or guesses, with probability 1/q).

**Practical use:**

Schnorr signatures are derived from this protocol via the Fiat-Shamir transform: instead of `c` being chosen by Victor, it's computed as `c = H(t || message)`. The signature is `(t, s)`.

Schnorr signatures are simpler and more efficient than ECDSA. Bitcoin's Taproot upgrade (2021) adds Schnorr signatures.

**Variants:**

- **Schnorr identification** — interactive, just for "I know x".
- **Schnorr signature** — non-interactive (Fiat-Shamir).
- **Aggregate Schnorr** — combine multiple signatures into one (used in Bitcoin Taproot and elsewhere).

**Interview insight:** Schnorr is the canonical example of an interactive ZKP. A candidate who can derive the verification equation and explain why it's zero-knowledge shows real cryptographic understanding.

### Q3. What is a "Sigma protocol"?

**Answer:**

A **Sigma protocol** is a 3-move public-coin interactive proof system: commit, challenge, response. It's named for the Greek letter Σ (sigma), which the three messages roughly form.

**The structure:**

1. **Commit (Σ⌐):** Prover sends a commitment based on randomness.
2. **Challenge (Σ\):** Verifier sends a random challenge.
3. **Response (Σ_):** Prover sends a response derived from the secret, the random commitment, and the challenge.
4. **Verify:** Verifier checks the consistency of (commit, challenge, response).

The Schnorr protocol from Q2 is a Sigma protocol. Many other ZKPs follow this structure.

**Properties:**

A Sigma protocol satisfies:

1. **Completeness:** Honest provers always succeed.

2. **Special soundness:** Given two valid transcripts with the *same commit* but different challenges, you can extract the secret. (This is stronger than regular soundness.)

3. **Honest verifier zero-knowledge (HVZK):** The transcript can be simulated when the verifier picks the challenge honestly.

**Why "honest verifier":**

Pure zero-knowledge requires the simulation to work even against malicious verifiers. Sigma protocols only guarantee zero-knowledge against verifiers who follow the protocol. In most practical cases this is fine (especially after Fiat-Shamir).

**Examples of Sigma protocols:**

1. **Schnorr identification** — knowledge of discrete logarithm.

2. **Guillou-Quisquater** — knowledge of e-th root modulo n.

3. **Chaum-Pedersen** — knowledge of equal discrete logarithms (`x` such that `g^x = y` and `h^x = z`).

4. **Okamoto** — variant of Schnorr with two secrets.

5. **Range proofs** (in some variants) — prove a committed value is in a range.

**Composition:**

Sigma protocols can be combined to prove conjunctions ("I know x AND y") and disjunctions ("I know x OR y"). The disjunction case is particularly interesting — prove you know one of several secrets without revealing which.

**Fiat-Shamir transform:**

Convert any Sigma protocol to a non-interactive proof by replacing the verifier's random challenge with a hash:

```
challenge = H(commit || statement)
```

Now the prover sends (commit, response) as a self-contained proof. The verifier hashes the commit and statement to recover the challenge, then verifies.

**Why hash here:**

The hash acts as a "random oracle" — assumed to be a random function. The prover can't predict its output without committing first, so the prover's commit really commits them.

**Limitations of Fiat-Shamir:**

The transform is only secure if the hash is a "good" random oracle. In practice, this is an approximation. There have been attacks on naively-implemented Fiat-Shamir constructions.

**Interview insight:** A candidate who can describe Sigma protocols generically (not just Schnorr) and mention Fiat-Shamir shows they've studied cryptography beyond the textbook level.

---

## Intermediate

### Q4. What is a zk-SNARK and how does it differ from a Sigma protocol?

**Answer:**

**zk-SNARK** stands for **Zero-Knowledge Succinct Non-interactive ARgument of Knowledge**. It's a class of zero-knowledge proofs with several distinguishing properties:

- **Zero-knowledge:** reveals nothing about the witness.
- **Succinct:** the proof is small (typically a few hundred bytes), regardless of the complexity of the statement being proven.
- **Non-interactive:** the prover sends a single message, no back-and-forth.
- **Argument of knowledge:** the prover demonstrates knowledge of a witness (not just that one exists).

**The key advantage over Sigma protocols:**

A Sigma protocol like Schnorr proves a specific algebraic statement (knowledge of discrete log). To prove a complex computation (e.g., "I executed this program correctly"), you'd need a custom Sigma protocol for each computation.

zk-SNARKs prove **arbitrary computations** with a single, generic protocol. You write the computation as an arithmetic circuit, and the proof system handles it.

**The pieces:**

A zk-SNARK has:

1. **Setup:** generates public parameters (a "common reference string" or CRS). This may be a "trusted setup" where the parameters must be generated honestly.

2. **Prover:** given the CRS, the statement, and the witness, produces a proof. This is computationally expensive — minutes to hours for complex statements.

3. **Verifier:** given the CRS, the statement, and the proof, verifies in milliseconds. Verification is fast and constant-time regardless of statement complexity.

**Trusted setup — the controversy:**

Most zk-SNARKs require a "trusted setup ceremony" where some random values are generated and then must be destroyed. If anyone keeps the values, they can forge proofs.

To mitigate this, ceremonies are conducted with many participants — as long as one participant honestly destroys their share, the whole setup is secure. Examples:

- **Zcash's "Powers of Tau" ceremony.**
- **Ethereum KZG ceremony** for proto-danksharding.

Hundreds of participants from around the world contributed entropy.

**Examples of zk-SNARK constructions:**

- **Groth16 (2016):** the most efficient verification, very small proof (~200 bytes). Used by Zcash. Requires per-circuit trusted setup.

- **PLONK (2019):** universal trusted setup (one setup works for all circuits). Slightly larger proofs.

- **Marlin, Sonic, etc.:** other variants with different trade-offs.

**Use cases:**

1. **Zcash:** private cryptocurrency. Transactions hide sender, receiver, and amount, while a SNARK proves the transaction is valid.

2. **zk-Rollups:** Ethereum scaling. A rollup batches many transactions, proves them all valid with a single SNARK, posts the proof to Ethereum. Ethereum verifies the SNARK in O(1) regardless of how many transactions.

3. **Verifiable computation:** outsource computation; verify the result with a tiny proof.

4. **Privacy-preserving authentication:** prove credentials without revealing them.

**Performance:**

- **Proof size:** ~200 bytes (Groth16) to ~1 KB.
- **Verification:** ~1-10 ms.
- **Proof generation:** seconds to hours, depending on circuit size and prover power.

The proof size and verification cost are the magic — they're constant regardless of how complex the computation is.

**Compared to Sigma protocols:**

- Sigma protocols: simple, no setup, fast proving and verifying, but only for specific algebraic statements.
- zk-SNARKs: complex, may need trusted setup, proving is slow, but can prove arbitrary computations succinctly.

**Interview insight:** A candidate who can describe both Schnorr (a Sigma protocol) and zk-SNARKs (general-purpose) and explain the trade-offs shows they understand the spectrum of ZKP techniques.

### Q5. What is a zk-STARK, and how does it differ from a zk-SNARK?

**Answer:**

**zk-STARK** stands for **Zero-Knowledge Scalable Transparent ARgument of Knowledge**. It's another class of ZKPs with different trade-offs from zk-SNARKs:

- **Scalable:** proving time scales sub-linearly with statement complexity (in the asymptotic sense).
- **Transparent:** no trusted setup required.
- **Otherwise similar properties** to zk-SNARKs (zero-knowledge, non-interactive, argument of knowledge).

**Key advantages over zk-SNARKs:**

1. **No trusted setup.** The setup uses only public randomness (e.g., a hash of recent block headers). No "toxic waste" to destroy. No need for elaborate ceremonies.

2. **Post-quantum security.** zk-SNARKs typically rely on elliptic curves or pairings, which are vulnerable to quantum computers. zk-STARKs rely only on hash functions, which are quantum-resistant.

3. **Faster proving for very large computations.** zk-STARKs scale better as the computation grows.

**Disadvantages:**

1. **Larger proofs.** zk-STARK proofs are typically 100s of KB, vs zk-SNARKs' 200-1000 bytes. About 100-1000× larger.

2. **Slower verification (in absolute terms).** A few milliseconds for SNARKs vs tens of milliseconds for STARKs.

3. **More memory during proving.** STARKs have higher prover memory requirements.

**Construction overview:**

zk-STARKs use:

1. **Polynomial commitments** based on hashes (Merkle trees over polynomial evaluations).

2. **FRI (Fast Reed-Solomon Interactive Oracle Proof of Proximity).** A protocol for proving that a function is close to a low-degree polynomial. The "soundness" of zk-STARKs ultimately relies on FRI.

3. **AIR (Algebraic Intermediate Representation):** the way computations are encoded into polynomial constraints.

**Use cases:**

1. **StarkNet:** Ethereum L2 using STARKs for scaling.

2. **StarkEx:** validity proofs for various dApps (DeFi, NFTs).

3. **Generic verifiable computation:** any setting where avoiding trusted setup is important.

**SNARKs vs STARKs comparison:**

| Property | zk-SNARK | zk-STARK |
|---|---|---|
| Trusted setup | Usually required | No |
| Proof size | ~200-1000 bytes | ~100-1000 KB |
| Verification time | ~1-10 ms | ~10-100 ms |
| Quantum resistance | No (ECC-based) | Yes (hash-based) |
| Prover time | Slower | Faster (asymptotically) for large circuits |
| Maturity | Older, well-tested | Newer |

**The trade-off:**

If you need the smallest proofs and verification cost, and trust the setup ceremony, zk-SNARKs win. If you need transparency, post-quantum security, or are dealing with very large computations, zk-STARKs win.

**Practical adoption:**

- **Zcash:** SNARKs (Groth16, then Halo2).
- **Ethereum L2s:** mix of SNARKs (zkSync, Scroll, Linea) and STARKs (StarkNet, Polygon Miden).
- **Bitcoin:** no L1 ZKPs yet, but L2s like RGB use various.

**Interview insight:** A candidate who can compare SNARKs and STARKs by their properties and use cases shows they understand the broader cryptographic landscape, not just one technique.

### Q6. What is the "Fiat-Shamir transform" and what are its security implications?

**Answer:**

The **Fiat-Shamir transform** (Fiat and Shamir, 1986) is a method for converting an interactive proof system into a non-interactive one. It's a foundational technique used in almost every modern ZKP.

**The basic idea:**

In an interactive proof (e.g., Sigma protocol), the verifier chooses a random challenge after seeing the prover's commit. The transform replaces this with a hash:

```
challenge = H(commit, statement)
```

The prover computes the challenge themselves (since they know commit and statement) and proceeds. The result is a proof that the verifier can check independently.

**Schnorr signature example:**

Original (interactive Schnorr identification):
1. Prover: pick `r`, compute `t = g^r`, send `t`.
2. Verifier: pick random `c`, send `c`.
3. Prover: compute `s = r + c*x`, send `s`.
4. Verifier: check `g^s == t * y^c`.

Fiat-Shamir transformed (Schnorr signature):
1. Prover: pick `r`, compute `t = g^r`, then `c = H(t || message)`, then `s = r + c*x`. Output signature `(t, s)`.
2. Verifier: compute `c = H(t || message)`, check `g^s == t * y^c`.

The signature is non-interactive — anyone can verify it without communication with the signer.

**Why the random oracle assumption matters:**

Fiat-Shamir's security relies on `H` being modelled as a "random oracle" — a function that returns truly random outputs for fresh inputs. Real hash functions (SHA-256, BLAKE2) are not random oracles, but they're close enough to be safe in practice for well-designed protocols.

**Security implications:**

1. **Prover can't precompute.** Since the challenge depends on the commit, and the commit determines the challenge before the prover sees the response phase, the prover can't manipulate the order.

2. **Domain separation matters.** The hash input must include not just the commit but also the statement, the public key, and any other relevant context. Otherwise, an attacker may reuse a proof from a different context.

3. **Strong Fiat-Shamir vs weak Fiat-Shamir.** Some early implementations only hashed the commit, not the statement. This led to attacks. The "strong" version hashes everything.

**Famous attacks:**

1. **Frozen heart attack (2022):** Affected several zero-knowledge proof systems that had implemented Fiat-Shamir incorrectly. Attackers could forge proofs because the hash didn't include enough context.

2. **Various weak Fiat-Shamir attacks:** When the statement isn't included in the hash, attackers can reuse proofs across statements.

**Best practices:**

1. **Hash everything:** the commit, the statement, public keys, any group parameters.

2. **Use a domain-separating prefix:** to ensure proofs from one protocol can't be reused in another.

3. **Use a well-vetted hash function:** SHA-256 or SHA-3 or BLAKE2.

4. **Prefer libraries:** don't implement Fiat-Shamir manually unless you're an expert. Use libraries like libsnark, arkworks, or libsecp256k1.

**Random oracle model in proofs:**

When proving a Fiat-Shamir-transformed protocol secure, cryptographers use the "random oracle model" (ROM). Proofs in the ROM are widely accepted but not as strong as proofs in the standard model.

Some constructions explicitly avoid Fiat-Shamir to get standard model security, but they're typically less efficient.

**Interview insight:** A candidate who knows about the random oracle model, the importance of including the statement in the hash, and the existence of attacks on weak Fiat-Shamir implementations shows real cryptographic depth.

---

## Advanced

### Q7. How are zero-knowledge proofs used in private cryptocurrencies like Zcash?

**Answer:**

**Zcash** uses zk-SNARKs to enable fully private cryptocurrency transactions. A transaction can hide:

- The sender.
- The recipient.
- The amount.
- The asset type (in newer versions).

While still being verifiable as valid by the network.

**The challenge:**

A traditional cryptocurrency (like Bitcoin) has public ledgers. Every transaction shows sender, receiver, amount. Privacy-conscious users have no recourse.

Zcash hides this information using ZKPs while preserving the property that the network can verify all transactions are valid (no double-spends, no money creation).

**The mechanism — shielded pool:**

1. **Shielded notes:** Instead of UTXOs, Zcash uses "notes" — encrypted commitments to (recipient, amount, randomness). Each note is a hash that hides everything but is verifiable.

2. **Note commitment tree:** All notes are stored in a Merkle tree. The current root represents the entire shielded pool's state.

3. **Spending a note:** To spend a note, the prover:
   - Reveals a "nullifier" — a unique identifier for the spent note (preventing double-spend).
   - Provides a SNARK proving:
     - The note exists in the Merkle tree.
     - The prover knows the spending key.
     - The note's value matches the transaction.
     - The output notes are well-formed.
   - Network verifies the SNARK and accepts the nullifier.

4. **Network verification:** The network verifies the SNARK (200 bytes, ~10 ms) and checks the nullifier hasn't been used. No other information is revealed.

**What's hidden:**

- **Sender:** the input note is one of many possible notes in the tree; the SNARK proves it exists without revealing which.
- **Recipient:** the output notes are encrypted to the recipient's key.
- **Amount:** the value is part of the note commitment, not revealed.

**What's public:**

- **Transaction fee.** Required for the network's fee market.
- **Block time.** When the transaction was confirmed.
- **The fact that a transaction occurred.** Just not who or how much.

**The trusted setup:**

Zcash's original setup ceremony was famously controversial. Six participants generated parameters; if all six destroyed their shares, the system was secure. Subsequent ceremonies had hundreds of participants.

Newer versions of Zcash use **Halo 2**, a SNARK with no trusted setup. This removes the ceremony's risk.

**Performance considerations:**

- **Proof generation:** seconds. A normal user can generate a shielded transaction on a smartphone, though slowly.
- **Proof verification:** milliseconds. The network can handle many transactions.
- **Wallet sync:** scanning the chain for incoming notes is slow because each user must trial-decrypt every note to find ones addressed to them. Optimisations exist.

**Limitations:**

1. **Most users use the public pool.** The shielded pool is more complex to use, so most Zcash transactions are still public. This reduces the anonymity set.

2. **Compliance friction.** Tax authorities and regulators struggle with fully-private money. Some exchanges have stopped supporting shielded Zcash.

3. **Complexity.** The cryptographic complexity of zk-SNARKs makes the system harder to audit and bug-prone.

**Other privacy techniques:**

- **Monero:** uses ring signatures (one of N possible senders) and confidential transactions (hide amounts). Less powerful than Zcash but no trusted setup.

- **Tornado Cash:** Ethereum mixer using zk-SNARKs. Anyone can deposit ETH, anyone can withdraw later, with no link between deposits and withdrawals.

- **Aztec:** general-purpose privacy on Ethereum using zk-SNARKs.

**Interview insight:** A candidate who can describe the note/nullifier model and explain why a SNARK is needed shows understanding of practical ZKP applications.

### Q8. What are "succinct arguments of knowledge" and why is the "knowledge" property important?

**Answer:**

A **succinct argument of knowledge** (SARG) is a proof system where:

1. **Succinct:** the proof is small (poly-logarithmic in the size of the statement).
2. **Argument:** soundness holds against computationally-bounded provers (vs "proof" which is for unconditional security).
3. **Knowledge:** the prover demonstrates knowledge of a witness, not just that one exists.

**Why "knowledge" matters:**

There's a subtle distinction between proving:

- **Existence:** "There exists a witness `w` such that `R(x, w)` holds." (e.g., "There exists a valid Sudoku solution.")

- **Knowledge:** "The prover *knows* a witness `w` such that `R(x, w)` holds."

For most practical applications, you want knowledge. If a prover can convince you a Sudoku has a solution without actually knowing one, what good is the proof? You want the prover to demonstrate they know the solution.

**Formal definition — extractor:**

Knowledge is formalised via an **extractor**: an algorithm that, given black-box access to a successful prover, can extract a witness. If such an extractor exists, the prover must "know" the witness in the sense that the witness can be computed from the prover's behaviour.

**Why the distinction matters in practice:**

Consider a ZK proof of "I know a private key `k` such that `g^k = pubkey`". 

- **Existence proof:** prover convinces verifier that some private key exists. Trivially true if `pubkey` is in the group.
- **Knowledge proof:** prover convinces verifier that they specifically know the private key. This is what you actually want for authentication.

Without knowledge, an adversary could prove "someone knows the private key" without knowing it themselves. Authentication would be meaningless.

**Knowledge extractors and rewinding:**

In Schnorr, the knowledge extractor works by "rewinding" the prover:

1. Run the prover, get `(t, c1, s1)` for challenge c1.
2. Rewind to the point before c1 was sent.
3. Send a different challenge c2.
4. Get response `s2`.
5. From the two responses: `s1 = r + c1*x`, `s2 = r + c2*x`. Subtract: `s1 - s2 = (c1 - c2) * x`. Solve for `x`.

The extractor recovers the secret. This proves Schnorr is a proof of knowledge.

**Argument vs proof:**

- **Proof:** soundness against unbounded provers. Stronger but rare in practice.
- **Argument:** soundness against polynomial-time provers (computational soundness). Weaker but typically sufficient — adversaries are bounded.

zk-SNARKs and zk-STARKs are both "arguments" in this sense — their soundness relies on cryptographic assumptions like the hardness of discrete log or hash function security.

**The "of Knowledge" suffix:**

zk-SNARK = Zero-Knowledge Succinct Non-interactive ARgument of Knowledge.

The "of Knowledge" suffix (the K) is the formal extractability property. It's what distinguishes a "proof of knowledge" from a "proof of existence".

**Practical example:**

In Zcash, the prover must prove "I know the spending key for this note." Without the knowledge property, an adversary could create a "valid" proof for a note they don't actually own — completely breaking the system.

**Interview insight:** A candidate who can articulate the knowledge property and the role of extractors shows understanding beyond the surface "ZKPs prove things". The K in SNARK matters.

### Q9. What is a "polynomial commitment scheme" and why is it central to modern ZKPs?

**Answer:**

A **polynomial commitment scheme (PCS)** is a cryptographic primitive that lets a prover:

1. **Commit** to a polynomial `f(x)` (as a single short value).
2. **Open** the commitment at a specific point `z`, revealing `f(z)` and proving it's consistent with the commitment.

The verifier learns nothing about the polynomial except its value at the queried points.

**Why polynomials:**

Modern ZKP systems (zk-SNARKs, zk-STARKs, PLONK, etc.) all reduce computations to polynomial identities. "Prove the computation is correct" becomes "prove the polynomial equation holds at all points." A polynomial commitment scheme lets you commit to the polynomial and selectively reveal evaluations without revealing the whole thing.

**Properties:**

1. **Binding:** the prover can't change their mind about the polynomial after committing.
2. **Hiding:** the commitment reveals nothing about the polynomial (zero-knowledge).
3. **Succinct:** the commitment is much smaller than the polynomial itself.
4. **Efficient evaluation proof:** opening at a point produces a proof much smaller than the polynomial.

**Common schemes:**

**1. KZG (Kate-Zaverucha-Goldberg) commitments:**

Based on bilinear pairings on elliptic curves.

- **Commit:** `C = g^{f(τ)}` where `τ` is the trusted setup secret.
- **Open at z:** quotient polynomial `q(x) = (f(x) - f(z))/(x - z)`. Proof = `g^{q(τ)}`.
- **Verify:** pairing check `e(C - g^{f(z)}, g) == e(proof, g^{τ - z})`.

Pros: tiny commitments and proofs (32 bytes each), constant-time verification.
Cons: requires trusted setup, vulnerable to quantum computers.

Used in: Ethereum's KZG-based proto-danksharding (EIP-4844), most modern SNARK constructions.

**2. FRI (Fast Reed-Solomon IOP of Proximity):**

Based on Merkle trees over polynomial evaluations.

- **Commit:** evaluate `f` at many points, build a Merkle tree, root is the commitment.
- **Open:** prove evaluations using Merkle paths, plus the FRI protocol to prove that the evaluations come from a low-degree polynomial.

Pros: no trusted setup, post-quantum secure, fast prover.
Cons: large proofs (100s of KB).

Used in: zk-STARKs, StarkNet, Polygon Miden.

**3. Inner Product Arguments (IPA):**

Based on discrete log assumption.

Pros: no trusted setup.
Cons: logarithmic proof size, slower verification than KZG.

Used in: Bulletproofs, Halo 2.

**4. Vector commitments:**

A simpler form for committing to a vector (rather than a polynomial). Used as building blocks.

**Why this is the foundation:**

A typical SNARK construction:

1. Encode the computation as a polynomial constraint system.
2. Prover commits to the relevant polynomials.
3. Verifier challenges by asking for evaluations at random points.
4. Prover provides openings.
5. Verifier checks the openings are consistent with the constraints.

The polynomial commitment scheme is what enables steps 2 and 4 efficiently. Without it, the prover would have to send the entire polynomial.

**The trade-off:**

Different commitment schemes lead to different SNARKs with different properties:

- KZG-based SNARKs (Groth16, PLONK with KZG): tiny proofs, trusted setup.
- FRI-based STARKs: large proofs, no trusted setup, post-quantum.
- IPA-based (Halo 2): no trusted setup, but slower.

**Recent innovations:**

- **FRI improvements:** smaller proofs, lower prover cost.
- **Lookup arguments:** efficiently express "this value is in this set" via polynomial commitments.
- **Pairing-friendly curves:** new elliptic curves optimised for KZG and pairing operations.

**Interview insight:** Polynomial commitments are the heart of modern ZKPs. A candidate who can describe them and name examples (KZG, FRI) shows real depth in the field.

### Q10. What are the practical applications of ZKPs beyond cryptocurrency?

**Answer:**

While cryptocurrencies have been the most visible early adopters of ZKPs, the technology has many other applications.

**1. Authentication without password transmission:**

**Schnorr-based protocols** prove you know a password without sending it. Resistant to phishing and replay attacks. The basis of most modern authentication standards (FIDO2, WebAuthn rely on similar principles).

**2. Anonymous credentials:**

Prove you have a valid credential (driver's license, university degree, age) without revealing your identity or unnecessary attributes.

- **Anonymous voting:** prove you're an eligible voter without revealing which ballot is yours.
- **Age verification:** prove you're over 18 without revealing your birthdate.
- **Credential federation:** prove you have an account at site A without telling site B who you are.

**3. Verifiable computation:**

A weak client (smartphone, IoT device) outsources computation to a powerful server. The server returns the result plus a SNARK proving the computation was correct. The client verifies in milliseconds.

- **Cloud computing trust:** verify the cloud actually ran your code correctly.
- **ML inference verification:** prove an AI model produced a specific output, without revealing the model.

**4. Regulatory compliance with privacy:**

Prove regulatory compliance without revealing sensitive details:

- **AML/KYC:** prove a transaction's parties are KYC'd without revealing who they are.
- **Tax compliance:** prove tax obligations are met without revealing income details.
- **Financial reporting:** prove a balance sheet is consistent without revealing positions.

**5. Private voting:**

End-to-end verifiable voting where voters can confirm their vote was counted, but no one can determine how anyone voted.

- **Helios:** an academic e-voting system using ZKPs.
- **Various national pilots** for digital voting.

**6. Data privacy in databases:**

- **Private set intersection:** two parties find common entries in their datasets without revealing other entries.
- **Private database queries:** query a database without revealing what you queried.

**7. Identity management:**

- **Self-sovereign identity:** own your credentials, prove specific attributes selectively.
- **Decentralized identifiers (DIDs):** identity systems with selective disclosure.

**8. Supply chain transparency:**

Prove chain-of-custody and provenance without revealing competitive information.

- **"Proof of fair trade":** prove a product followed fair-trade requirements without revealing supplier details.
- **Pharmaceutical traceability:** prove a drug's origin without exposing the entire supply chain.

**9. Privacy-preserving machine learning:**

- **Federated learning with ZKPs:** participants prove their gradient updates are correct without revealing their training data.
- **ZK-ML inference:** prove an ML model produced a result without revealing the model's weights.

**10. Layer-2 blockchain scaling:**

Beyond cryptocurrency, ZKPs enable Layer-2 scaling for any blockchain:

- **zk-Rollups:** batch transactions, prove validity to L1.
- **Validium:** keep data off-chain, validity on-chain via ZKP.
- **zk-SNARK-based bridges:** prove cross-chain transactions efficiently.

**Adoption status (2024):**

- **Crypto:** widely deployed (Zcash, Ethereum L2s).
- **Authentication:** Schnorr-based protocols ubiquitous.
- **General-purpose verifiable computation:** early commercial offerings (Aleo, Aztec).
- **Privacy-preserving compliance:** pilot deployments in finance and healthcare.

**Challenges:**

1. **Performance.** SNARK proving is still slow for complex computations.
2. **Developer experience.** Writing circuits is hard. DSLs (Circom, Cairo, Noir) help but the learning curve is steep.
3. **Auditing.** ZKP systems are cryptographically complex. Bugs in the circuit or underlying scheme can be catastrophic.
4. **Education.** Few engineers understand ZKPs deeply enough to design correct systems.

**The future:**

ZKPs are moving from a specialised research area to a standard tool. As DSLs mature and proving becomes cheaper (via better hardware and algorithms), we'll see ZKPs integrated into many systems where privacy and verifiability matter.

**Interview insight:** A candidate who can name diverse ZKP applications shows they think beyond cryptocurrency. The technology has much broader implications for privacy, compliance, and trust.
