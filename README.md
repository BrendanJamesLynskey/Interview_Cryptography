# Cryptography Interview Preparation

[![Cryptography](https://img.shields.io/badge/Subject-Cryptography-blue.svg)](https://en.wikipedia.org/wiki/Cryptography)

This repository contains comprehensive interview preparation materials for cryptography, covering symmetric and asymmetric encryption algorithms, cryptographic protocols, hardware implementation considerations, side-channel attacks, and post-quantum cryptography.

## Table of Contents

- [01 Fundamentals](#01-fundamentals)
- [02 Mathematical Foundations](#02-mathematical-foundations)
- [03 Protocols](#03-protocols)
- [04 Hardware Implementation](#04-hardware-implementation)
- [05 Post-Quantum Cryptography](#05-post-quantum-cryptography)
- [06 Quizzes](#06-quizzes)
- [How to Use](#how-to-use)
- [Contributing](#contributing)
- [Related Repositories](#related-repositories)

## 01 Fundamentals

Core concepts of cryptography including encryption, hashing, and authentication.

- [Symmetric Encryption](01_fundamentals/symmetric_encryption.md)
- [Asymmetric Encryption](01_fundamentals/asymmetric_encryption.md)
- [Hash Functions](01_fundamentals/hash_functions.md)
- [MAC and Digital Signatures](01_fundamentals/mac_and_signatures.md)
- [Random Number Generation](01_fundamentals/random_number_generation.md)
- [Worked Problems](01_fundamentals/worked_problems/)
  - [Problem 01: AES Round](01_fundamentals/worked_problems/problem_01_aes_round.md)
  - [Problem 02: RSA Key Generation](01_fundamentals/worked_problems/problem_02_rsa_key_generation.md)
  - [Problem 03: Hash Properties](01_fundamentals/worked_problems/problem_03_hash_properties.md)

## 02 Mathematical Foundations

Mathematical theory underlying cryptographic algorithms.

- [Modular Arithmetic](02_mathematical_foundations/modular_arithmetic.md)
- [Finite Fields GF(2) and GF(2^8)](02_mathematical_foundations/finite_fields_gf2.md)
- [Elliptic Curves](02_mathematical_foundations/elliptic_curves.md)
- [Number Theory and Primes](02_mathematical_foundations/number_theory_primes.md)
- [Worked Problems](02_mathematical_foundations/worked_problems/)
  - [Problem 01: GF(2^8) Multiplication](02_mathematical_foundations/worked_problems/problem_01_gf2_8_multiplication.md)
  - [Problem 02: ECC Point Addition](02_mathematical_foundations/worked_problems/problem_02_ecc_point_addition.md)
  - [Problem 03: Discrete Logarithm](02_mathematical_foundations/worked_problems/problem_03_discrete_logarithm.md)

## 03 Protocols

Cryptographic protocols and their design patterns.

- [TLS Handshake](03_protocols/tls_handshake.md)
- [Key Exchange: Diffie-Hellman and ECDH](03_protocols/key_exchange_dh_ecdh.md)
- [PKI and Certificates](03_protocols/pki_and_certificates.md)
- [Authentication Protocols](03_protocols/authentication_protocols.md)
- [Worked Problems](03_protocols/worked_problems/)
  - [Problem 01: TLS 1.3 Handshake](03_protocols/worked_problems/problem_01_tls13_handshake.md)
  - [Problem 02: Certificate Chain](03_protocols/worked_problems/problem_02_certificate_chain.md)
  - [Problem 03: Protocol Attack](03_protocols/worked_problems/problem_03_protocol_attack.md)

## 04 Hardware Implementation

Cryptographic hardware design, optimization, and security.

- [AES Hardware Architecture](04_hardware_implementation/aes_hardware_architecture.md)
- [ECC Hardware](04_hardware_implementation/ecc_hardware.md)
- [Side-Channel Attacks](04_hardware_implementation/side_channel_attacks.md)
- [Countermeasures: Masking and Hiding](04_hardware_implementation/countermeasures_masking_hiding.md)
- [Coding Challenges](04_hardware_implementation/coding_challenges/)
  - [Challenge 01: AES S-Box](04_hardware_implementation/coding_challenges/challenge_01_aes_sbox.sv)
  - [Challenge 02: GF Multiplier](04_hardware_implementation/coding_challenges/challenge_02_gf_multiplier.sv)
  - [Challenge 03: PRNG LFSR](04_hardware_implementation/coding_challenges/challenge_03_prng_lfsr.sv)

## 05 Post-Quantum Cryptography

Quantum-resistant cryptographic algorithms and migration strategies.

- [Quantum Threat](05_post_quantum/quantum_threat.md)
- [Lattice-Based: Kyber and Dilithium](05_post_quantum/lattice_based_kyber_dilithium.md)
- [Hash-Based Signatures](05_post_quantum/hash_based_signatures.md)
- [Migration Strategies](05_post_quantum/migration_strategies.md)
- [Worked Problems](05_post_quantum/worked_problems/)
  - [Problem 01: Kyber Overview](05_post_quantum/worked_problems/problem_01_kyber_overview.md)
  - [Problem 02: NTT for Lattice](05_post_quantum/worked_problems/problem_02_ntt_for_lattice.md)
  - [Problem 03: Hybrid Approach](05_post_quantum/worked_problems/problem_03_hybrid_approach.md)

## 06 Quizzes

Self-assessment quizzes covering each major topic area.

- [Quiz: Fundamentals](06_quizzes/quiz_fundamentals.md)
- [Quiz: Mathematics](06_quizzes/quiz_maths.md)
- [Quiz: Protocols](06_quizzes/quiz_protocols.md)
- [Quiz: Hardware](06_quizzes/quiz_hardware.md)
- [Quiz: Post-Quantum](06_quizzes/quiz_post_quantum.md)

## How to Use

This repository is structured for progressive learning and interview preparation:

1. **Start with fundamentals**: Begin with 01_fundamentals to understand the basic cryptographic primitives: symmetric encryption, asymmetric encryption, hashing, and digital signatures.

2. **Learn the mathematics**: Study 02_mathematical_foundations to understand the underlying mathematics of elliptic curves, finite fields, modular arithmetic, and number theory.

3. **Study protocols**: Review 03_protocols to understand how cryptographic primitives are combined into security protocols like TLS, key exchange mechanisms, and PKI.

4. **Explore hardware implementation**: Read 04_hardware_implementation to understand how cryptographic algorithms are efficiently implemented in hardware, side-channel vulnerabilities, and protection mechanisms.

5. **Understand post-quantum cryptography**: Study 05_post_quantum to learn about quantum threats and quantum-resistant algorithms including lattice-based and hash-based approaches.

6. **Test your knowledge**: Use the quizzes in 06_quizzes to assess your understanding and identify areas for deeper study.

Each section includes worked problems that demonstrate practical application of the concepts. Use these to verify your understanding before moving forward.

## Contributing

Contributions are welcome. Please follow these guidelines:

- Maintain clarity and technical accuracy
- Follow the existing markdown structure
- Add examples and worked problems where appropriate
- Ensure all links are relative and functional
- Test any code examples or technical claims

For significant additions, please open an issue first to discuss the proposed changes.

## Related Repositories

These repositories complement this interview preparation material:

- [Cryptography](https://github.com/BrendanJamesLynskey/Cryptography) - Cryptography presentation series and educational materials
