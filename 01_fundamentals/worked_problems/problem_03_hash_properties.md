# Problem 03: Hash Security Properties — Analysis and Attack Scenarios

## Problem Statement

Analyse the security properties of cryptographic hash functions through five concrete scenarios. For each scenario, identify which property is relevant, determine whether a real attack exists, and quantify the work required.

**Scenarios:**

1. An attacker wants to find any input that hashes to a specific 256-bit target digest.
2. An attacker wants to find two different inputs that hash to the same 256-bit digest.
3. A MAC is constructed as $\text{MAC}_K(M) = H(K \| M)$ using SHA-256. Analyse the security.
4. A system hashes passwords as $H(\text{password})$ using SHA-256, with no salt. An attacker obtains the hash database. Analyse the security.
5. SHA-256 is used in a Merkle tree. An attacker wants to prove membership of a fabricated leaf without recomputing the tree.

---

## Solution

### Scenario 1: Finding a Preimage

**Property:** Preimage resistance (one-way property).

**Attack goal:** Given $y = H(x)$ for unknown $x$, find any $x'$ with $H(x') = y$.

**Generic attack:** Exhaustive search. Try random inputs and check whether $H(\text{input}) = y$.

**Work required for SHA-256 (256-bit output):**

The search space is $\{0,1\}^*$ (arbitrary-length inputs), but the target is one specific digest in $\{0,1\}^{256}$.

Expected number of trials before finding a preimage: $2^{256}$.

At $10^{18}$ hash computations per second (a hypothetical exascale machine):

$$
\text{Time} = \frac{2^{256}}{10^{18}} \approx \frac{1.16 \times 10^{77}}{10^{18}} = 1.16 \times 10^{59} \text{ seconds}
$$

This is approximately $3.7 \times 10^{51}$ years — over $10^{41}$ times the age of the universe. Computationally infeasible.

**Is there a better attack?** For SHA-256 specifically, no known attack improves significantly on $2^{256}$. The best theoretical preimage attack on weakened variants requires $2^{244.9}$ — still completely infeasible.

**Conclusion:** SHA-256 provides 256-bit preimage security. Practically unbreakable.

---

### Scenario 2: Finding a Collision

**Property:** Collision resistance.

**Attack goal:** Find any pair $(x, x')$ with $x \neq x'$ and $H(x) = H(x')$.

**Generic attack — Birthday attack:**

The birthday paradox states: if we sample $k$ values uniformly from a domain of size $N$, the expected number of colliding pairs among them is $k^2 / (2N)$. Setting this to 1: $k = \Theta(\sqrt{N}) = \Theta(2^{n/2})$ for an $n$-bit hash.

For SHA-256 ($n = 256$): collision search requires approximately $2^{128}$ hash computations.

**Algorithm:**

```python
# Conceptual birthday attack (storage-efficient version via Floyd's cycle or Rho)
def birthday_attack_collision(hash_fn, target_bits: int):
    """
    Find a collision using random walk + Floyd cycle detection.
    Expected O(2^(n/2)) hash evaluations, O(1) storage.
    """
    def truncate(x):
        return x & ((1 << target_bits) - 1)

    # Small target for illustration (not SHA-256 sized)
    x = 0
    y = 0
    while True:
        x = truncate(hash_fn(x))        # tortoise: one step
        y = truncate(hash_fn(hash_fn(y)))  # hare: two steps
        if x == y:
            break

    # At this point we're in a cycle modulo the target domain
    # Back-trace to find the actual collision
    # (full implementation omitted for brevity)
    return x, y
```

**Storage-time tradeoff:** The naive birthday attack stores $2^{128}$ digests. Pollard's rho variant finds the collision with $O(2^{128})$ time but $O(1)$ storage. The distinguished-point method parallelises across many machines.

**Current state:** SHA-256 has no known collision. SHA-1 was broken in 2017 (SHAttered, $2^{63.1}$ ops). MD5 was broken in 2004 ($2^{24}$ ops).

**Conclusion:** SHA-256 provides 128-bit collision security. Secure against all classical attacks.

---

### Scenario 3: Length Extension Attack on $H(K \| M)$

**Property under attack:** This construction is NOT a secure MAC for SHA-256 (or any Merkle-Damgård hash).

**The vulnerability — length extension:**

SHA-256 uses the Merkle-Damgård construction. After computing $H(K \| M)$, the internal state of SHA-256 is essentially the output digest $h$. An attacker who knows $H(K \| M)$ can continue hashing from that state without knowing $K$.

**Attack procedure:**

Attacker knows: $(M, T = H(K \| M))$ where $|K| = 32$ bytes (unknown key).

1. The attacker sets the SHA-256 internal state to $T$ (the known tag).
2. They compute $T' = H_{\text{resume}}(S)$ where $S$ is any chosen suffix.
3. The resulting $T'$ equals $H(K \| M \| \text{pad}(K \| M) \| S)$ — a valid tag for the extended message $M' = M \| \text{pad}(K \| M) \| S$.

The padding $\text{pad}(K \| M)$ is known (it depends only on $|K| + |M|$, which the attacker can observe or guess).

```python
import struct

def sha256_length_extension_demo():
    """
    Conceptual demonstration of the length extension weakness.
    A real attack would manipulate the SHA-256 internal state directly.
    """
    # What the attacker observes:
    known_msg = b"amount=100&to=alice"
    # tag = SHA256(secret_key || known_msg)  -- attacker observes this
    # Attacker wants to forge:
    # forged = SHA256(secret_key || known_msg || sha256_padding || "&admin=true")
    # WITHOUT knowing secret_key.

    # Step 1: Determine padding that was applied to (key || known_msg)
    # Assuming |key| = 16 bytes, |known_msg| = 19 bytes → total = 35 bytes
    key_len = 16   # assumed/guessed
    msg_len = len(known_msg)
    padded_len = key_len + msg_len  # 35 bytes = 280 bits

    # SHA-256 padding: 0x80, then zeros, then 64-bit big-endian bit length
    pad = b'\x80'
    pad += b'\x00' * ((55 - padded_len) % 64)
    pad += struct.pack('>Q', padded_len * 8)

    # Step 2: Attacker appends their chosen suffix
    suffix = b"&admin=true"

    # Step 3: "Forged" message from the server's perspective:
    forged_msg = known_msg + pad + suffix
    print(f"Original message: {known_msg}")
    print(f"Padding bytes:    {pad.hex()}")
    print(f"Forged message:   {forged_msg}")

    # The forged tag would be computed by resuming SHA-256 from the observed
    # internal state (the tag), not recomputing from scratch.
    # This is why H(key || msg) is insecure as a MAC.
```

**Why HMAC is secure:**

HMAC wraps the hash with two layers of keying:

$$
\text{HMAC}_K(M) = H\bigl((K \oplus \text{opad}) \| H((K \oplus \text{ipad}) \| M)\bigr)
$$

The outer hash $H((K \oplus \text{opad}) \| \cdot)$ takes the inner hash as input. An attacker who extends the inner computation would need to also extend the outer hash with a known key ($K \oplus \text{opad}$) — which they do not have. The length extension on the inner hash produces a value that is then re-keyed by the outer hash, breaking the attack.

**Affected constructions:** $H(K \| M)$, $H(M \| K)$ (different vulnerability), and any raw hash-based MAC except HMAC and KMAC (SHA-3 based). Not affected: SHA-3 (sponge, no length extension), BLAKE2/3, HMAC-SHA-256, SHA-512/256 (truncated state).

**Conclusion:** $H(K \| M)$ is broken as a MAC for SHA-256. Use HMAC-SHA-256 instead.

---

### Scenario 4: Unsalted Password Hash Database Attack

**Property exploited:** Pre-computation (rainbow table) attack — circumvents preimage hardness.

**The setup:** Database stores $\{(u_i, H(\text{password}_i))\}$. Attacker obtains the database.

**Why raw preimage resistance is insufficient:**

Preimage resistance guarantees that for a *specific random target*, finding a preimage requires $2^{256}$ work. But password hashes are not random targets — passwords come from a small, predictable space.

**Dictionary attack:**

```
For each common password p in a dictionary of 10^9 entries:
    compute H(p) and look it up in the database
```

Most users choose passwords from a distribution of $\sim 10^8$ to $10^{10}$ common choices. A full SHA-256 computation takes ~$10^{-9}$ seconds on modern hardware, so $10^{10}$ passwords are tested in ~10 seconds.

**Rainbow table attack (time-space tradeoff):**

Precompute a compressed lookup structure mapping $\{H(p) \to p\}$ for all common passwords. A table covering $10^{10}$ passwords and their SHA-256 hashes takes ~$320$ GB. Once built, lookups are $O(\log N)$. Tables are reusable across all databases that use unsalted SHA-256.

**Why salting defeats this:**

A salt $s$ is a random value stored alongside each hash: the database stores $(u_i, s_i, H(s_i \| \text{password}_i))$.

1. **Rainbow tables become useless:** A rainbow table is specific to one (salt, hash_function) pair. With a 128-bit random salt, an attacker would need $2^{128}$ separate tables — infeasible.
2. **Dictionary attacks are per-user:** To crack a salted hash, the attacker must compute $H(s_i \| p)$ for each dictionary entry $p$ and each specific user $i$ — cannot share computation across users.

**Why SHA-256 (even with salt) is the wrong choice:**

SHA-256 is designed for speed. An attacker with GPU hardware can compute $10^{10}$ SHA-256 hashes per second. Password hashing should use a **deliberately slow** (memory-hard) function:

| Function | Design | GPU speed (rough) |
|---|---|---|
| SHA-256 | Fast | $10^{10}$/s per GPU |
| bcrypt | Expensive rounds | $10^4$/s per GPU |
| scrypt | Memory-hard | $10^3$/s per GPU |
| Argon2id | Memory-hard + parallel-hard | $10^3$/s per GPU |

**Correct approach:** Use Argon2id (OWASP recommended) with a 128-bit random salt, memory $\geq 64$ MB, iterations tuned to 1 second on the target hardware.

**Conclusion:** Unsalted SHA-256 is insecure for passwords — not due to hash weakness but due to predictable password distribution and pre-computation. Use salted Argon2id.

---

### Scenario 5: Merkle Tree Membership Forgery

**Property:** Second preimage resistance (and collision resistance in certain constructions).

**Merkle tree construction:**

A Merkle tree over $n$ leaves $\{L_1, \ldots, L_n\}$:

```
Level 3 (root):    R = H(H12 || H34)
Level 2:           H12 = H(H1 || H2),  H34 = H(H3 || H4)
Level 1 (leaves):  H1 = H(L1),  H2 = H(L2),  H3 = H(L3),  H4 = H(L4)
```

A **membership proof** (Merkle proof) for leaf $L_2$ consists of the sibling hashes on the path from $L_2$ to the root: $\{H1, H34\}$. The verifier checks:

```
H(H(H(L2) || H1) || H34) == root  →  accepted
```

(Note: in practice, left/right ordering is tracked.)

**Forgery attempt 1 — find $L_2'$ with $H(L_2') = H(L_2)$:**

This is a second preimage attack. Work required: $2^{256}$ for SHA-256. Infeasible.

**Forgery attempt 2 — collision attack at a node level:**

Find $H_{12}' \neq H_{12}$ but $H(H_{12}' \| H_{34}) = R$. This is a second preimage on the root computation. Also $2^{256}$ work.

**Forgery attempt 3 — collision at a leaf pair level:**

Find two different pairs $(H1', H2')$ and $(H1, H2)$ with $H(H1' \| H2') = H(H1 \| H2) = H_{12}$. This is a collision attack on the level-2 hash. Work required: $2^{128}$ (birthday attack). Still infeasible in practice.

**The "second preimage attack on Merkle-Damgård" concern:**

Kelsey and Schneier (2005) showed a second preimage attack on long messages hashed with Merkle-Damgård constructions in $2^{n - k}$ work (where $k = \log_2$(message blocks) and $n$ = output bits), which is lower than $2^n$. For SHA-256 with messages up to $2^{64}$ blocks, this gives $2^{192}$ work — still infeasible.

**Practical vulnerability — leaf vs. node confusion:**

A subtle real vulnerability: if the tree does not distinguish leaf hashes from internal node hashes, an attacker can present an internal node as a "leaf" and construct a false proof. Mitigation: prepend a domain separator before hashing: $H(\texttt{0x00} \| \text{leaf data})$ for leaves, $H(\texttt{0x01} \| L \| R)$ for internal nodes. This prevents an internal node hash from being mistaken for a valid leaf hash.

This vulnerability affected some early Bitcoin SPV implementations and several smart contract Merkle tree verifiers.

```python
import hashlib

def leaf_hash(data: bytes) -> bytes:
    """Hash a leaf with domain separation."""
    return hashlib.sha256(b'\x00' + data).digest()

def node_hash(left: bytes, right: bytes) -> bytes:
    """Hash an internal node with domain separation."""
    return hashlib.sha256(b'\x01' + left + right).digest()

def build_merkle_tree(leaves: list[bytes]) -> list[list[bytes]]:
    """Build a Merkle tree and return all levels."""
    level = [leaf_hash(l) for l in leaves]
    tree = [level]
    while len(level) > 1:
        next_level = []
        for i in range(0, len(level), 2):
            left = level[i]
            right = level[i+1] if i+1 < len(level) else left  # duplicate last if odd
            next_level.append(node_hash(left, right))
        level = next_level
        tree.append(level)
    return tree

def merkle_proof(tree: list[list[bytes]], leaf_index: int) -> list[tuple[str, bytes]]:
    """Return the sibling hashes (with side) needed to verify leaf_index."""
    proof = []
    idx = leaf_index
    for level in tree[:-1]:  # all levels except root
        sibling_idx = idx ^ 1  # toggle last bit to get sibling
        if sibling_idx < len(level):
            side = 'right' if idx % 2 == 0 else 'left'
            proof.append((side, level[sibling_idx]))
        idx //= 2
    return proof

# Example
leaves = [b"tx_alice_to_bob", b"tx_bob_to_carol", b"tx_carol_to_dave", b"tx_dave_to_eve"]
tree = build_merkle_tree(leaves)
root = tree[-1][0]
proof = merkle_proof(tree, leaf_index=1)

print(f"Root: {root.hex()[:16]}...")
print(f"Proof for leaf 1: {len(proof)} nodes")
```

**Conclusion:** SHA-256 Merkle trees are secure against forgery for practical parameters. The key engineering concern is domain separation between leaf and internal node hashing.

---

## Summary Table

| Scenario | Property | Attack type | Work for SHA-256 | Secure? |
|---|---|---|---|---|
| 1 | Preimage resistance | Exhaustive search | $2^{256}$ | Yes |
| 2 | Collision resistance | Birthday attack | $2^{128}$ | Yes |
| 3 | MAC security | Length extension | $O(1)$ given tag | No — use HMAC |
| 4 | Password security | Dictionary + rainbow table | $10^{10}$ ops/s (GPU) | No — use Argon2id |
| 5 | 2nd preimage / Merkle | Long-msg 2nd preimage | $2^{192}$ | Yes (with domain sep.) |
