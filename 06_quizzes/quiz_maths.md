# Quiz: Cryptographic Mathematics

15 multiple-choice questions covering modular arithmetic, finite fields, elliptic curves,
number theory, and GF(2^8) arithmetic.

**Instructions:** Select the single best answer. Answers with explanations at the end.

---

## Questions

**Q1.** Using the Extended Euclidean Algorithm, $17^{-1} \pmod{29}$ equals:

A) 12
B) 17
C) 19
D) 24

---

**Q2.** The order of the multiplicative group $\mathbb{Z}_{13}^*$ (nonzero integers mod 13) is:

A) 11
B) 12
C) 13
D) 6

---

**Q3.** In GF(2^8) with the AES reduction polynomial $0x11B$, what is $0x02 \times 0x80$?

A) 0x00
B) 0x1B
C) 0x80
D) 0x03

---

**Q4.** An elliptic curve $y^2 = x^3 + ax + b \pmod p$ is non-singular when:

A) $\gcd(a, b) = 1$
B) $4a^3 + 27b^2 \not\equiv 0 \pmod p$
C) $a$ and $b$ are prime
D) $a < b$

---

**Q5.** Pollard's rho algorithm solves the discrete logarithm in a group of prime order $q$
in approximately how many group operations?

A) $O(q)$
B) $O(\sqrt{q})$
C) $O(q^{1/3})$
D) $O(\log q)$

---

**Q6.** In RSA with $n = p \cdot q$, the private exponent $d$ satisfies:

A) $e \cdot d \equiv 1 \pmod n$
B) $e \cdot d \equiv 1 \pmod{p+q}$
C) $e \cdot d \equiv 1 \pmod{(p-1)(q-1)}$
D) $e + d \equiv n \pmod{pq}$

---

**Q7.** Which of the following is NOT true about a prime-order elliptic curve group?

A) Every nonzero element is a generator
B) The group operation is associative
C) Every element has an additive inverse
D) Scalar multiplication by the group order gives a non-zero result

---

**Q8.** Using Fermat's Little Theorem, the modular inverse $a^{-1} \pmod p$ (prime $p$) equals:

A) $a^p \pmod p$
B) $a^{p-2} \pmod p$
C) $a^{(p-1)/2} \pmod p$
D) $a^{p+1} \pmod p$

---

**Q9.** RSA-CRT computes $m = c^d \pmod n$ more efficiently by computing:

A) $c^d \pmod{p+q}$ and $c^d \pmod{p-q}$
B) $c^{d \bmod (p-1)} \pmod p$ and $c^{d \bmod (q-1)} \pmod q$
C) $c^{d/2} \pmod p$ and $c^{d/2} \pmod q$
D) $c^d \pmod{\phi(n)/2}$ and $c^d \pmod{\phi(n)/3}$

---

**Q10.** In the elliptic curve group $E(\mathbb{F}_p)$, the point at infinity $\mathcal{O}$ is:

A) The generator point for all scalar multiplications
B) The additive identity element
C) The base point for ECDH key exchange
D) The neutral element for scalar multiplication only

---

**Q11.** Miller-Rabin is best described as:

A) A deterministic test that always correctly identifies primes
B) A probabilistic test with no false negatives (composites that pass)
C) A probabilistic test with no false positives (primes that fail)
D) A deterministic algorithm that also factors the input

---

**Q12.** Over GF(2), the polynomial $X^4 + 1$ is:

A) Irreducible, since it has degree 4 and no roots in GF(2)
B) Reducible, because $X^4 + 1 = (X+1)^4$ over GF(2)
C) Irreducible — it is the AES reduction polynomial
D) Reducible only over extension fields of GF(2)

---

**Q13.** The Extended Euclidean Algorithm fails to compute a modular inverse when:

A) $a > b$
B) $a$ is even
C) $\gcd(a, b) > 1$
D) $b$ is not prime

---

**Q14.** In GF(2^8), what is $0x01 + 0x01$?

A) 0x02
B) 0x10
C) 0xFF
D) 0x00

---

**Q15.** Pohlig-Hellman decomposes the DLP into smaller sub-problems. It is most effective when:

A) The group order $N$ is a large prime
B) The group order $N$ is a power of 2
C) The group order $N$ is smooth (has many small prime factors)
D) The group order equals the field characteristic $p$

---

## Answers and Explanations

**Q1. Answer: A — 12**

Using the Extended Euclidean Algorithm:
$29 = 1 \times 17 + 12$;
$17 = 1 \times 12 + 5$;
$12 = 2 \times 5 + 2$;
$5 = 2 \times 2 + 1$.

Back-substituting: $1 = 12 \times 17 - 7 \times 29$, so $17^{-1} \equiv 12 \pmod{29}$.

Verify: $17 \times 12 = 204 = 7 \times 29 + 1 \equiv 1 \pmod{29}$. ✓

The other options do not satisfy $17x \equiv 1 \pmod{29}$.

---

**Q2. Answer: B — 12**

For a prime $p$, the multiplicative group $\mathbb{Z}_p^*$ has order $\phi(p) = p - 1$.
For $p = 13$: order $= 12$.

Answer A (11) is $p - 2$, not $p - 1$.
Answer C (13) is the modulus, not the group order.
Answer D (6) is the order of the quadratic residue subgroup, not the full group.

---

**Q3. Answer: B — 0x1B**

In GF(2^8), multiplication by $0x02$ (xtime): left-shift by 1, XOR with $0x1B$ if bit 7 was 1.

$0x80 = 10000000_2$. Bit 7 is 1.
$0x80 \ll 1 = 0x00$ (bit 8 is dropped; result is 8-bit zero).
XOR with $0x1B$: $0x00 \oplus 0x1B = 0x1B$.

Answer A (0x00) omits the XOR reduction.
Answer C (0x80) would result from no operation.
Answer D (0x03) is unrelated.

---

**Q4. Answer: B — $4a^3 + 27b^2 \not\equiv 0 \pmod p$**

The discriminant $\Delta = -16(4a^3 + 27b^2)$. A curve is non-singular (an elliptic curve)
iff $\Delta \neq 0$. A zero discriminant means the cubic $x^3 + ax + b$ has a repeated
root, causing a singular point where the group law is undefined.

Standard named curves (P-256, Curve25519) are verified non-singular at parameter generation.

---

**Q5. Answer: B — $O(\sqrt{q})$**

Pollard's rho uses a random walk and birthday paradox. For a group of prime order $q$,
it finds the discrete logarithm in $O(\sqrt{q})$ group operations.

For P-256 ($q \approx 2^{256}$): $\sqrt{2^{256}} = 2^{128}$ operations — this is the
source of the 128-bit security claim.

$O(q)$ is brute-force. $O(q^{1/3})$ appears in index calculus for classical DLP (finite
fields), not ECDLP. $O(\log q)$ is the cost of one scalar multiplication, not the attack.

---

**Q6. Answer: C — $e \cdot d \equiv 1 \pmod{(p-1)(q-1)}$**

RSA correctness requires $m^{ed} \equiv m \pmod n$. Since $\phi(n) = (p-1)(q-1)$, Euler's
theorem gives $m^{\phi(n)} \equiv 1 \pmod n$ (for $\gcd(m, n) = 1$). So $ed \equiv 1
\pmod{\phi(n)}$ ensures $m^{ed} = m^{1+k\phi(n)} \equiv m \pmod n$.

Modular inverse $\pmod n$ (answer A) has no role in RSA correctness. The sum $p+q$
(answer B) is irrelevant to Euler's theorem.

---

**Q7. Answer: D — Scalar multiplication by the group order gives a non-zero result**

In any group of order $q$, multiplying any element by $q$ gives the identity: $q \cdot P = \mathcal{O}$.
This is a fundamental group theory result (Lagrange's theorem implies the order of any
element divides the group order; for prime-order groups, every non-identity element has
order $q$, so $q \cdot P = \mathcal{O}$).

The other statements are all true of prime-order groups. Answer A: every nonzero element
generates the group (characteristic of prime-order cyclic groups). Answers B and C are
basic group axioms.

---

**Q8. Answer: B — $a^{p-2} \pmod p$**

Fermat: $a^{p-1} \equiv 1 \pmod p$, so $a \cdot a^{p-2} \equiv 1 \pmod p$, giving
$a^{-1} \equiv a^{p-2} \pmod p$.

Answer A: $a^p \equiv a \pmod p$ (Fermat's little theorem in the form $a^p = a$, not the inverse).
Answer C: $a^{(p-1)/2}$ is the Legendre symbol, which equals $\pm 1$ and indicates
quadratic residuosity — not the multiplicative inverse.
Answer D: $a^{p+1} \equiv a^2 \pmod p$, not the inverse.

---

**Q9. Answer: B — $c^{d \bmod (p-1)} \pmod p$ and $c^{d \bmod (q-1)} \pmod q$**

Fermat's Little Theorem: $c^{p-1} \equiv 1 \pmod p$, so $c^d \equiv c^{d \bmod (p-1)} \pmod p$.
Similarly mod $q$. The CRT then combines these two 1024-bit results into the 2048-bit answer.

Speedup: $\approx 4\times$ since squarings are 4× cheaper for half-length inputs.

---

**Q10. Answer: B — The additive identity element**

The point at infinity $\mathcal{O}$ satisfies $P + \mathcal{O} = \mathcal{O} + P = P$ for
all curve points $P$. It is the identity element for the group law, analogous to 0 in
$(\mathbb{Z}, +)$ or 1 in $(\mathbb{Z}^*, \times)$.

Answer A: the generator/base point $G$ is a separate specified curve parameter.
Answer C: ECDH uses $G$ (a public parameter of the named curve), not $\mathcal{O}$.
Answer D: $\mathcal{O}$ is the full additive identity, not restricted to scalar multiplication.

---

**Q11. Answer: C — Probabilistic with no false positives (primes that fail)**

Miller-Rabin never reports a prime as composite. If the test is passed, the number may
be prime (with high probability) or a pseudoprime (rare false negative). A composite
number can pass the test for a specific witness with probability $\leq 1/4$.

With $k$ random witnesses, the probability of a composite passing all tests is $\leq 4^{-k}$.
With $k = 64$ witnesses: probability $\leq 4^{-64} = 2^{-128}$ — negligible.

---

**Q12. Answer: B — Reducible, $X^4 + 1 = (X+1)^4$ over GF(2)**

In characteristic 2: $(a+b)^{2^k} = a^{2^k} + b^{2^k}$. Therefore $(X+1)^4 = X^4 + 1$
over GF(2). The polynomial factors as $(X+1)^4$ and is not irreducible.

Answer A: having no roots in GF(2) means no degree-1 factors, but degree-4 polynomials
can still factor into degree-2 polynomials. A polynomial is irreducible only if it has
no polynomial divisors of degree 1 through $\lfloor n/2 \rfloor$.

Answer C: the AES polynomial is $x^8 + x^4 + x^3 + x + 1$ (degree 8, irreducible over GF(2)).

---

**Q13. Answer: C — When $\gcd(a, b) > 1$**

Bezout's identity: for integers $a, b$, there exist $s, t$ such that $sa + tb = \gcd(a, b)$.
A modular inverse $a^{-1} \pmod m$ exists iff $\gcd(a, m) = 1$.

If $\gcd(a, m) = d > 1$, then $a$ and $m$ share a common factor; no integer $s$ satisfies
$sa \equiv 1 \pmod m$ (the equation $sa + tm = 1$ would require $d \mid 1$, impossible for $d > 1$).

Order of inputs (A), parity (B), and primality of modulus (D) do not affect the existence
of the inverse — only coprimality does.

---

**Q14. Answer: D — 0x00**

GF(2^8) uses bitwise XOR as addition. The field characteristic is 2: $a + a = 0$ for
all $a$.

$0x01 \oplus 0x01 = 0x00$.

Answer A (0x02) applies integer addition — wrong for GF(2^8).
This fundamental property distinguishes GF(2^8) arithmetic from modular integer arithmetic.

---

**Q15. Answer: C — $N$ is smooth (has many small prime factors)**

Pohlig-Hellman decomposes the DLP in a group of order $N$ into DLPs of order $q_i$ for
each prime power factor $q_i^{e_i}$ of $N$, then combines using CRT. The total cost is
$O(\sum_{i} e_i(\log N + \sqrt{q_i}))$. If all $q_i$ are small (N is smooth), all
sub-problems are easy.

Answer A: a prime $N$ has no subgroup structure to exploit — Pohlig-Hellman collapses
to the full DLP. This is why cryptographic groups have prime order.
Answer B: $N = 2^{64}$ is extremely smooth — Pohlig-Hellman would be trivially fast.
Answer D is not a meaningful condition for the group order.
