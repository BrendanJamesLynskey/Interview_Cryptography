// =============================================================================
// Challenge 03: LFSR PRNG
// =============================================================================
//
// BACKGROUND
// ----------
// A Linear Feedback Shift Register (LFSR) is a shift register where the input
// bit is a linear function (XOR) of some of the register's previous state bits.
// LFSRs produce a deterministic sequence that appears pseudo-random.
//
// A maximal-length LFSR of degree n cycles through all 2^n - 1 non-zero states
// before repeating. The tap positions that produce maximal length come from
// primitive polynomials over GF(2).
//
// Example: 8-bit Galois LFSR with primitive polynomial x^8 + x^6 + x^5 + x^4 + 1
//   Taps: bits 8, 6, 5, 4 (using 1-indexed notation, bit 8 is MSB)
//   LFSR seed: any non-zero 8-bit value
//   Maximal period: 2^8 - 1 = 255 states
//
// Two LFSR architectures:
//
//   Fibonacci (external XOR):
//     The XOR of tap bits feeds back to the input (bit 0).
//     One bit shifts in per clock, feedback applied at input end.
//     Output: LSB.
//
//   Galois (internal XOR):
//     XOR gates are distributed through the register at tap positions.
//     The MSB shifts into the register; tapped bits XOR with the outgoing bit.
//     Output: LSB (or any bit).
//     Advantage: shorter critical path (XOR in parallel, not in series).
//
// INTERVIEW TASKS
// ---------------
// Task A (Fundamentals):
//   Implement an 8-bit maximal-length Fibonacci LFSR.
//   Primitive polynomial: x^8 + x^6 + x^5 + x^4 + 1 (taps: 8,6,5,4)
//   - Input:  clk, rst_n (async active-low reset), enable
//   - Output: 8-bit 'state' (current register contents)
//             1-bit 'rand_bit' (output bit)
//   - On reset: state initialises to 8'hFF (non-zero seed)
//
// Task B (Intermediate):
//   Implement a Galois LFSR with the same polynomial.
//   Verify both implementations produce the same sequence from the same seed.
//
// Task C (Advanced):
//   Explain why an LFSR is NOT cryptographically secure and propose a hardware
//   architecture that converts LFSR output into a cryptographically secure
//   random bit stream. Hint: consider LFSR + AES-CTR or Trivium stream cipher.
//
// CONSTRAINTS
// -----------
//   - Use synchronous logic with async reset
//   - The all-zeros state must never be entered (LFSR would lock up)
//   - Synthesisable SystemVerilog
//   - The primitive polynomial x^8 + x^6 + x^5 + x^4 + 1 has taps at positions
//     8, 6, 5, 4 (standard notation where position n is the MSB for an n-bit LFSR)
//
// REFERENCE SEQUENCE (from seed 0xFF, Fibonacci LFSR):
//   State[0] = 0xFF
//   State[1] = 0x7F  (shift right, feedback = XOR(bit8, bit6, bit5, bit4) of 0xFF)
//     feedback = 1^1^1^1 = 0; new MSB = 0; state = 0x7F
//   State[2] = 0xBF  (feedback = 0^1^1^1 = 1; new MSB = 1; state = 0b10111111 = 0xBF)
//   ... (period = 255)
//
// =============================================================================

// -----------------------------------------------------------------------------
// Task A: 8-bit Fibonacci LFSR
// Polynomial: x^8 + x^6 + x^5 + x^4 + 1
// Taps: positions 8,6,5,4 (1-indexed from LSB; position 8 = state[7] = MSB)
// In common Fibonacci notation: feedback = state[7] ^ state[5] ^ state[4] ^ state[3]
// (0-indexed: bits 7, 5, 4, 3 of the current 8-bit state)
// -----------------------------------------------------------------------------
module lfsr_fibonacci_8 (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [7:0] state,
    output logic       rand_bit
);
    // TODO: Implement an 8-bit maximal Fibonacci LFSR.
    //
    // Fibonacci LFSR operation:
    //   1. Compute feedback = XOR of tap positions
    //   2. Shift state right by 1
    //   3. Insert feedback into the MSB (state[7])
    //
    // Polynomial x^8 + x^6 + x^5 + x^4 + 1:
    //   Tap bits (0-indexed from bit0 as LSB):
    //   The polynomial has terms x^8 (implicit), x^6, x^5, x^4, 1 (x^0).
    //   For an n-bit LFSR this means feedback = state[7] ^ state[5] ^ state[4] ^ state[3]
    //   (subtracting 1 to convert 1-indexed polynomial exponents to 0-indexed state bits)
    //
    // On reset: state = 8'hFF
    // rand_bit: output the LSB (state[0]) before the shift

    assign rand_bit = state[0]; // LSB output (update this if needed)

    // TODO: Register update logic here

endmodule : lfsr_fibonacci_8


// Reference solution: 8-bit Fibonacci LFSR
module lfsr_fibonacci_8_ref (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [7:0] state,
    output logic       rand_bit
);
    logic feedback;

    // Feedback for x^8 + x^6 + x^5 + x^4 + 1
    // Tap positions (0-indexed from LSB):
    //   x^8 -> state shifts out from state[7] (the MSB being shifted out)
    //   x^6 -> state[5]
    //   x^5 -> state[4]
    //   x^4 -> state[3]
    //   x^0 -> implicit constant 1 = state[0] is the feedback input position
    // In Fibonacci form: feedback = state[7] ^ state[5] ^ state[4] ^ state[3]
    assign feedback = state[7] ^ state[5] ^ state[4] ^ state[3];
    assign rand_bit = state[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 8'hFF;   // non-zero seed required
        end else if (enable) begin
            state <= {feedback, state[7:1]};  // shift right, insert feedback at MSB
        end
    end

endmodule : lfsr_fibonacci_8_ref


// -----------------------------------------------------------------------------
// Task B: 8-bit Galois LFSR
// Same polynomial; distributed internal XOR architecture
// -----------------------------------------------------------------------------
module lfsr_galois_8 (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [7:0] state,
    output logic       rand_bit
);
    // TODO: Implement an 8-bit Galois LFSR.
    //
    // Galois LFSR operation:
    //   1. The output bit is state[0] (LSB)
    //   2. Each bit shifts right by 1
    //   3. Tap positions XOR with the output bit
    //   4. MSB = output bit (the shifted-out LSB feeds back to MSB)
    //
    // For polynomial x^8 + x^6 + x^5 + x^4 + 1:
    //   Bits 7, 5, 4, 3 (0-indexed) are tap positions.
    //   New state:
    //     new_state[7] = state[0]
    //     new_state[6] = state[7]         (no tap)
    //     new_state[5] = state[6] ^ state[0]  (tap at bit 5 = position x^6)
    //     new_state[4] = state[5] ^ state[0]  (tap at bit 4 = position x^5)
    //     new_state[3] = state[4] ^ state[0]  (tap at bit 3 = position x^4)
    //     new_state[2] = state[3]         (no tap)
    //     new_state[1] = state[2]         (no tap)
    //     new_state[0] = state[1]         (no tap)
    //
    // Advantage over Fibonacci: XOR gates are in parallel (shorter critical path).

    assign rand_bit = state[0];

    // TODO: Register update logic here

endmodule : lfsr_galois_8


// Reference solution: 8-bit Galois LFSR
module lfsr_galois_8_ref (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [7:0] state,
    output logic       rand_bit
);
    logic out_bit;
    assign out_bit  = state[0];
    assign rand_bit = out_bit;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 8'hFF;
        end else if (enable) begin
            // Galois shift: each tap bit XORs with the output bit
            state[7] <= out_bit;
            state[6] <= state[7];
            state[5] <= state[6] ^ out_bit;  // tap
            state[4] <= state[5] ^ out_bit;  // tap
            state[3] <= state[4] ^ out_bit;  // tap
            state[2] <= state[3];
            state[1] <= state[2];
            state[0] <= state[1];
        end
    end

endmodule : lfsr_galois_8_ref


// =============================================================================
// TESTBENCH
// =============================================================================
module tb_lfsr_prng;

    logic clk, rst_n, enable;
    logic [7:0] fib_state, fib_ref_state, gal_state, gal_ref_state;
    logic fib_bit, fib_ref_bit, gal_bit, gal_ref_bit;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    lfsr_fibonacci_8     dut_fib     (.clk, .rst_n, .enable, .state(fib_state),     .rand_bit(fib_bit));
    lfsr_fibonacci_8_ref ref_fib     (.clk, .rst_n, .enable, .state(fib_ref_state), .rand_bit(fib_ref_bit));
    lfsr_galois_8        dut_gal     (.clk, .rst_n, .enable, .state(gal_state),     .rand_bit(gal_bit));
    lfsr_galois_8_ref    ref_gal     (.clk, .rst_n, .enable, .state(gal_ref_state), .rand_bit(gal_ref_bit));

    integer pass_cnt, fail_cnt;
    integer seen_states [256];
    integer period_count;

    initial begin
        $display("=== LFSR PRNG Testbench ===");
        pass_cnt  = 0;
        fail_cnt  = 0;
        enable    = 1'b0;
        rst_n     = 1'b0;

        // Assert reset
        @(posedge clk); #1;
        rst_n = 1'b1;
        enable = 1'b1;

        // --- Test 1: Fibonacci DUT matches reference for 260 cycles ---
        $display("\n-- Test 1: Fibonacci LFSR matches reference (260 cycles) --");
        begin
            automatic logic ok = 1'b1;
            repeat (260) begin
                @(posedge clk); #1;
                if (fib_state !== fib_ref_state) begin
                    $display("FAIL: Fibonacci state mismatch: DUT=0x%02h REF=0x%02h",
                             fib_state, fib_ref_state);
                    ok = 1'b0; fail_cnt++;
                end
            end
            if (ok) begin
                $display("PASS: Fibonacci DUT matches reference for 260 cycles"); pass_cnt++;
            end
        end

        // --- Test 2: Fibonacci LFSR period = 255 (maximal length) ---
        $display("\n-- Test 2: Fibonacci LFSR period = 255 --");

        // Reset and restart
        enable = 1'b0; rst_n = 1'b0;
        @(posedge clk); #1;
        rst_n = 1'b1; enable = 1'b1;

        begin
            automatic logic [7:0] initial_state;
            automatic integer period;
            @(posedge clk); #1;
            initial_state = fib_ref_state;
            period = 0;

            // Count cycles until state returns to initial
            @(posedge clk); #1;
            period = 1;
            while (fib_ref_state !== initial_state && period < 300) begin
                @(posedge clk); #1;
                period++;
            end

            if (period === 255) begin
                $display("PASS: Fibonacci LFSR period = 255 (maximal-length)"); pass_cnt++;
            end else begin
                $display("FAIL: Fibonacci LFSR period = %0d (expected 255)", period); fail_cnt++;
            end
        end

        // --- Test 3: All-zeros state never reached ---
        $display("\n-- Test 3: All-zeros state never entered --");
        begin
            automatic logic zero_seen = 1'b0;
            enable = 1'b0; rst_n = 1'b0;
            @(posedge clk); #1;
            rst_n = 1'b1; enable = 1'b1;

            repeat (300) begin
                @(posedge clk); #1;
                if (fib_ref_state === 8'h00) begin
                    $display("FAIL: All-zeros state reached (LFSR would lock up)");
                    zero_seen = 1'b1; fail_cnt++;
                end
            end
            if (!zero_seen) begin
                $display("PASS: All-zeros state never reached in 300 cycles"); pass_cnt++;
            end
        end

        // --- Test 4: Galois LFSR matches reference ---
        $display("\n-- Test 4: Galois LFSR matches reference (260 cycles) --");
        enable = 1'b0; rst_n = 1'b0;
        @(posedge clk); #1;
        rst_n = 1'b1; enable = 1'b1;

        begin
            automatic logic ok2 = 1'b1;
            repeat (260) begin
                @(posedge clk); #1;
                if (gal_state !== gal_ref_state) begin
                    $display("FAIL: Galois state mismatch: DUT=0x%02h REF=0x%02h",
                             gal_state, gal_ref_state);
                    ok2 = 1'b0; fail_cnt++;
                end
            end
            if (ok2) begin
                $display("PASS: Galois DUT matches reference for 260 cycles"); pass_cnt++;
            end
        end

        // --- Test 5: Galois LFSR period = 255 ---
        $display("\n-- Test 5: Galois LFSR period = 255 --");
        enable = 1'b0; rst_n = 1'b0;
        @(posedge clk); #1;
        rst_n = 1'b1; enable = 1'b1;

        begin
            automatic logic [7:0] gal_init;
            automatic integer gal_period;
            @(posedge clk); #1;
            gal_init = gal_ref_state;
            gal_period = 0;
            @(posedge clk); #1; gal_period = 1;
            while (gal_ref_state !== gal_init && gal_period < 300) begin
                @(posedge clk); #1;
                gal_period++;
            end
            if (gal_period === 255) begin
                $display("PASS: Galois LFSR period = 255"); pass_cnt++;
            end else begin
                $display("FAIL: Galois LFSR period = %0d (expected 255)", gal_period); fail_cnt++;
            end
        end

        // Summary
        $display("\n=== Test Summary ===");
        $display("Passed: %0d   Failed: %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule : tb_lfsr_prng

// =============================================================================
// DISCUSSION NOTES
// =============================================================================
//
// Task C: Why LFSR is NOT cryptographically secure
// -------------------------------------------------
// An LFSR is a linear recurrence: the state at time t+1 is a linear function
// of the state at time t. Given 2n consecutive output bits of an n-bit LFSR,
// the Berlekamp-Massey algorithm recovers the entire feedback polynomial (and
// thus all future states) in O(n^2) time.
//
// For an 8-bit LFSR: 16 consecutive output bits -> full state recovery.
// For a 32-bit LFSR: 64 consecutive bits -> full recovery.
//
// LFSR outputs fail these cryptographic requirements:
//   1. Next-bit unpredictability: given t bits, the (t+1)-th bit is predictable.
//   2. State-recovery resistance: any 2n outputs reveal all future outputs.
//   3. Statistical indistinguishability from random: linear correlation tests
//      (NIST SP 800-22, Diehard) detect the linear structure.
//
// Making LFSR cryptographically secure:
//
// Option 1 -- LFSR as seed for AES-CTR DRBG:
//   Use the LFSR only to generate a 128-bit seed, then run AES-CTR mode:
//   PRNG output = AES_K(counter++)
//   AES provides computational security: next-bit unpredictability under AES security.
//   Hardware cost: LFSR (trivial) + AES core (~1,500 LUTs).
//
// Option 2 -- Trivium stream cipher:
//   A hardware stream cipher (eSTREAM finalist) designed for efficient FPGA/ASIC.
//   Uses three shift registers + 3 AND gates + XOR for 1 bit/cycle.
//   Period: 2^70 bits. Proven cryptographic strength (no known attacks).
//   Hardware cost: 288 flip-flops + ~10 logic gates = ~600 GE.
//
// Option 3 -- Nonlinear combination/filtering of multiple LFSRs:
//   Geffe generator: combine 3 LFSRs nonlinearly. Still broken by correlation attacks.
//   Not recommended. Use AES-CTR DRBG or Trivium instead.
//
// Practical use of LFSRs in cryptographic hardware:
//   LFSRs ARE used in cryptographic hardware, but not as the sole randomness source:
//   - Mask generation: XOR of multiple LFSR outputs approximates pseudorandomness
//     sufficient for first-order DPA protection (but NOT for key generation)
//   - Test pattern generation (BIST): LFSRs generate pseudo-random test vectors
//   - Signature analysis (MISR): LFSRs compress test outputs for fault detection
//
// Key requirement: any application requiring unpredictability for security
// (key generation, nonce generation, mask generation in masked implementations)
// MUST use a CSPRNG backed by a hardware TRNG, not a bare LFSR.
//
// Interview follow-up questions:
//   1. What does it mean for a polynomial to be primitive over GF(2)?
//      Answer: A primitive polynomial p(x) of degree n over GF(2) has the property
//      that x is a generator of the multiplicative group of GF(2^n). Using p(x) as
//      the LFSR feedback polynomial produces a maximal-length sequence of period 2^n-1.
//
//   2. What is the Berlekamp-Massey algorithm?
//      Answer: An O(n^2) algorithm that finds the shortest LFSR that generates a
//      given binary sequence. Given 2n output bits, it recovers the feedback polynomial
//      of an n-bit LFSR, exposing the complete state.
//
//   3. What is the difference between a TRNG and PRNG?
//      Answer: A TRNG (True Random Number Generator) sources entropy from physical
//      phenomena (thermal noise, shot noise, jitter). A PRNG is deterministic given
//      its seed. A CSPRNG (Cryptographically Secure PRNG) is a PRNG designed so that
//      next-bit prediction is computationally infeasible; it must be seeded from a TRNG.
