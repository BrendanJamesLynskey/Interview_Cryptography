// =============================================================================
// Challenge 02: GF(2^8) Multiplier
// =============================================================================
//
// BACKGROUND
// ----------
// Galois Field GF(2^8) arithmetic is fundamental to AES:
//   - MixColumns uses GF(2^8) multiplication by constants 0x02 and 0x03
//   - The combinational AES S-Box uses GF(2^8) inversion and GF(2^4) operations
//   - GHASH (the authenticator in AES-GCM) uses GF(2^128) multiplication
//
// GF(2^8) is defined as polynomials over GF(2) reduced modulo the AES irreducible
// polynomial:
//   m(x) = x^8 + x^4 + x^3 + x + 1   (binary: 0x11B = 0b1_0001_1011)
//
// Elements of GF(2^8) are 8-bit values 0x00..0xFF.
// Addition in GF(2^8) is XOR.
// Multiplication is polynomial multiplication reduced modulo m(x).
//
// Key property (xtime):
//   Multiplying by 0x02 is left-shift-by-1 with conditional XOR of 0x1B
//   if bit 7 of the original value was 1:
//     xtime(a):
//       if a[7] == 1: return (a << 1) ^ 0x1B
//       else:         return (a << 1)
//
// INTERVIEW TASKS
// ---------------
// Task A (Fundamentals):
//   Implement combinational multiplication by the constant 0x02 (xtime).
//   - Input:  8-bit value 'a'
//   - Output: 8-bit value 'out' = a * 0x02 in GF(2^8)
//
// Task B (Intermediate):
//   Implement general GF(2^8) multiplication: 'a' * 'b' for arbitrary 8-bit inputs.
//   Use the repeated xtime approach (Russian peasant multiplication).
//   - Input:  8-bit values 'a', 'b'
//   - Output: 8-bit 'out' = a * b in GF(2^8)
//
// Task C (Advanced):
//   Implement the AES MixColumns operation for a single 4-byte column.
//   MixColumns multiplies the column vector by the fixed matrix:
//   [ 2 3 1 1 ]
//   [ 1 2 3 1 ]
//   [ 1 1 2 3 ]
//   [ 3 1 1 2 ]
//   - Input:  32-bit 'col_in' = {s3, s2, s1, s0}
//   - Output: 32-bit 'col_out' = mixed column
//
// REFERENCE VALUES
//   xtime(0x57) = 0xAE
//   xtime(0xAE) = 0x47   (0xAE[7]=1: shift + XOR 0x1B)
//   xtime(0x80) = 0x1B
//   gf_mul(0x57, 0x13) = 0xFE
//   gf_mul(0xFF, 0xFF) = 0x13
//
// =============================================================================

// -----------------------------------------------------------------------------
// Task A: Multiply by 0x02 (xtime)
// -----------------------------------------------------------------------------
module gf_xtime (
    input  logic [7:0] a,
    output logic [7:0] out
);
    // TODO: Implement xtime(a) = a * 0x02 in GF(2^8).
    // Left shift by 1; if a[7] was 1, XOR with 0x1B (the low 8 bits of 0x11B).

    assign out = 8'h00; // placeholder

endmodule : gf_xtime


// Reference solution for gf_xtime
module gf_xtime_ref (
    input  logic [7:0] a,
    output logic [7:0] out
);
    assign out = (a[7]) ? ((a << 1) ^ 8'h1b) : (a << 1);

endmodule : gf_xtime_ref


// -----------------------------------------------------------------------------
// Task B: General GF(2^8) Multiplier
// -----------------------------------------------------------------------------
module gf_mul (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] out
);
    // TODO: Implement a * b in GF(2^8).
    //
    // Russian peasant / double-and-add algorithm (unrolled for combinational logic):
    //   - Precompute 8 successive xtime values: a, 2a, 4a, ..., 128a
    //   - For each bit b[i], conditionally XOR the corresponding multiple into the result
    //
    // Hint: Declare 9 signals ax[0..7] where ax[i] = a * x^i.
    //       Compute ax[i] = xtime(ax[i-1]) for i = 1..7.
    //       Then: out = (b[0] ? ax[0] : 0) ^ (b[1] ? ax[1] : 0) ^ ... ^ (b[7] ? ax[7] : 0)

    assign out = 8'h00; // placeholder

endmodule : gf_mul


// Reference solution for gf_mul
module gf_mul_ref (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] out
);
    logic [7:0] ax [0:7];  // ax[i] = a * x^i in GF(2^8)

    always_comb begin
        ax[0] = a;
        for (int i = 1; i < 8; i++) begin
            ax[i] = (ax[i-1][7]) ? ((ax[i-1] << 1) ^ 8'h1b) : (ax[i-1] << 1);
        end
        out = 8'h00;
        for (int i = 0; i < 8; i++) begin
            if (b[i]) out = out ^ ax[i];
        end
    end

endmodule : gf_mul_ref


// -----------------------------------------------------------------------------
// Task C: AES MixColumns (single column)
// -----------------------------------------------------------------------------
module aes_mix_columns (
    input  logic [31:0] col_in,    // {s3[7:0], s2[7:0], s1[7:0], s0[7:0]}
    output logic [31:0] col_out
);
    // TODO: Implement MixColumns for one 32-bit column.
    //
    // Extract bytes s0..s3 from col_in.
    // Compute xtime for each byte (mul2).
    // Use: mul3(x) = mul2(x) ^ x   (since 3 = 2 + 1 in GF(2^8))
    //
    // Output column:
    //   t0 = mul2(s0) ^ mul3(s1) ^ s2 ^ s3
    //   t1 = s0 ^ mul2(s1) ^ mul3(s2) ^ s3
    //   t2 = s0 ^ s1 ^ mul2(s2) ^ mul3(s3)
    //   t3 = mul3(s0) ^ s1 ^ s2 ^ mul2(s3)

    assign col_out = 32'h0; // placeholder

endmodule : aes_mix_columns


// Reference solution for aes_mix_columns
module aes_mix_columns_ref (
    input  logic [31:0] col_in,
    output logic [31:0] col_out
);
    logic [7:0] s0, s1, s2, s3;
    logic [7:0] t0, t1, t2, t3;
    logic [7:0] x2s0, x2s1, x2s2, x2s3;

    assign s0 = col_in[ 7: 0];
    assign s1 = col_in[15: 8];
    assign s2 = col_in[23:16];
    assign s3 = col_in[31:24];

    // mul2 via xtime
    assign x2s0 = (s0[7]) ? ((s0 << 1) ^ 8'h1b) : (s0 << 1);
    assign x2s1 = (s1[7]) ? ((s1 << 1) ^ 8'h1b) : (s1 << 1);
    assign x2s2 = (s2[7]) ? ((s2 << 1) ^ 8'h1b) : (s2 << 1);
    assign x2s3 = (s3[7]) ? ((s3 << 1) ^ 8'h1b) : (s3 << 1);

    // MixColumns: t_i uses mul2 and mul3 = mul2 ^ identity
    // t0 = 2*s0 ^ 3*s1 ^ 1*s2 ^ 1*s3 = x2s0 ^ (x2s1^s1) ^ s2 ^ s3
    assign t0 = x2s0 ^ x2s1 ^ s1 ^ s2 ^ s3;
    assign t1 = s0 ^ x2s1 ^ x2s2 ^ s2 ^ s3;
    assign t2 = s0 ^ s1 ^ x2s2 ^ x2s3 ^ s3;
    assign t3 = x2s0 ^ s0 ^ s1 ^ s2 ^ x2s3;

    assign col_out = {t3, t2, t1, t0};

endmodule : aes_mix_columns_ref


// =============================================================================
// TESTBENCH
// =============================================================================
module tb_gf_multiplier;

    logic [7:0]  a_in, b_in;
    logic [7:0]  xtime_out, xtime_ref_out;
    logic [7:0]  mul_out, mul_ref_out;
    logic [31:0] col_in_vec, col_out_vec, col_ref_out;

    gf_xtime          dut_xtime (.a(a_in),                      .out(xtime_out));
    gf_xtime_ref      ref_xtime (.a(a_in),                      .out(xtime_ref_out));
    gf_mul            dut_mul   (.a(a_in), .b(b_in),            .out(mul_out));
    gf_mul_ref        ref_mul   (.a(a_in), .b(b_in),            .out(mul_ref_out));
    aes_mix_columns     dut_mc  (.col_in(col_in_vec),           .col_out(col_out_vec));
    aes_mix_columns_ref ref_mc  (.col_in(col_in_vec),           .col_out(col_ref_out));

    integer pass_cnt, fail_cnt;

    initial begin
        $display("=== GF(2^8) Multiplier Testbench ===");
        pass_cnt = 0;
        fail_cnt = 0;

        // --- Task A: xtime known vectors ---
        $display("\n-- xtime (multiply by 0x02) known vectors --");

        a_in = 8'h57; #1;
        if (xtime_out === 8'hae) begin
            $display("PASS: xtime(0x57) = 0xAE"); pass_cnt++;
        end else begin
            $display("FAIL: xtime(0x57) = 0x%02h (expected 0xAE)", xtime_out); fail_cnt++;
        end

        a_in = 8'hae; #1;
        if (xtime_out === 8'h47) begin
            $display("PASS: xtime(0xAE) = 0x47"); pass_cnt++;
        end else begin
            $display("FAIL: xtime(0xAE) = 0x%02h (expected 0x47)", xtime_out); fail_cnt++;
        end

        a_in = 8'h80; #1;
        if (xtime_out === 8'h1b) begin
            $display("PASS: xtime(0x80) = 0x1B"); pass_cnt++;
        end else begin
            $display("FAIL: xtime(0x80) = 0x%02h (expected 0x1B)", xtime_out); fail_cnt++;
        end

        // Exhaustive xtime check vs reference
        $display("\n-- xtime exhaustive (256 values) --");
        begin
            automatic logic ok = 1'b1;
            for (int v = 0; v < 256; v++) begin
                a_in = v[7:0]; #1;
                if (xtime_out !== xtime_ref_out) begin
                    $display("FAIL: xtime(0x%02h) mismatch: got 0x%02h ref 0x%02h",
                             a_in, xtime_out, xtime_ref_out);
                    ok = 1'b0; fail_cnt++;
                end
            end
            if (ok) begin
                $display("PASS: xtime matches reference for all 256 inputs"); pass_cnt++;
            end
        end

        // --- Task B: gf_mul known vectors ---
        $display("\n-- GF multiply known vectors --");

        a_in = 8'h57; b_in = 8'h13; #1;
        if (mul_out === 8'hfe) begin
            $display("PASS: gf_mul(0x57, 0x13) = 0xFE"); pass_cnt++;
        end else begin
            $display("FAIL: gf_mul(0x57, 0x13) = 0x%02h (expected 0xFE)", mul_out); fail_cnt++;
        end

        // Identity: a * 1 = a
        a_in = 8'hd4; b_in = 8'h01; #1;
        if (mul_out === 8'hd4) begin
            $display("PASS: gf_mul(0xD4, 0x01) = 0xD4 (identity)"); pass_cnt++;
        end else begin
            $display("FAIL: gf_mul(0xD4, 0x01) = 0x%02h (expected 0xD4)", mul_out); fail_cnt++;
        end

        // Annihilator: a * 0 = 0
        a_in = 8'hd4; b_in = 8'h00; #1;
        if (mul_out === 8'h00) begin
            $display("PASS: gf_mul(0xD4, 0x00) = 0x00"); pass_cnt++;
        end else begin
            $display("FAIL: gf_mul(0xD4, 0x00) = 0x%02h (expected 0x00)", mul_out); fail_cnt++;
        end

        // Spot-check vs reference (1000 random pairs)
        $display("\n-- GF multiply spot check (1000 random pairs vs reference) --");
        begin
            automatic logic ok2 = 1'b1;
            for (int i = 0; i < 1000; i++) begin
                a_in = $urandom_range(0, 255);
                b_in = $urandom_range(0, 255);
                #1;
                if (mul_out !== mul_ref_out) begin
                    $display("FAIL: gf_mul(0x%02h,0x%02h)=0x%02h ref=0x%02h",
                             a_in, b_in, mul_out, mul_ref_out);
                    ok2 = 1'b0; fail_cnt++;
                end
            end
            if (ok2) begin
                $display("PASS: gf_mul matches reference for 1000 random pairs"); pass_cnt++;
            end
        end

        // --- Task C: MixColumns ---
        $display("\n-- MixColumns check --");
        // Column {s3=0, s2=0, s1=0, s0=0x02}: all-zero except first byte
        col_in_vec = {8'h00, 8'h00, 8'h00, 8'h02}; #1;
        if (col_out_vec === col_ref_out) begin
            $display("PASS: MixColumns({0,0,0,2}) = 0x%08h (matches ref)", col_out_vec); pass_cnt++;
        end else begin
            $display("FAIL: MixColumns({0,0,0,2}) = 0x%08h (ref 0x%08h)",
                     col_out_vec, col_ref_out); fail_cnt++;
        end

        // All-ones column
        col_in_vec = {8'h01, 8'h01, 8'h01, 8'h01}; #1;
        if (col_out_vec === col_ref_out) begin
            $display("PASS: MixColumns(all-ones) = 0x%08h", col_out_vec); pass_cnt++;
        end else begin
            $display("FAIL: MixColumns(all-ones) mismatch"); fail_cnt++;
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

endmodule : tb_gf_multiplier

// =============================================================================
// DISCUSSION NOTES
// =============================================================================
//
// xtime() and the AES reduction polynomial:
//   m(x) = x^8 + x^4 + x^3 + x + 1 corresponds to binary 0x11B.
//   When a left shift produces a degree-8 term, subtract m(x) by XORing 0x11B.
//   Since we shift a to produce an 8-bit result (dropping the degree-8 term),
//   we only need to XOR the lower 8 bits of m(x): 0x1B.
//
// MixColumns implementation efficiency:
//   Only mul1, mul2, mul3 are needed (constants 1, 2, 3).
//   mul1(x) = x               (wire -- free)
//   mul2(x) = xtime(x)        (1 XOR gate tree, ~2 gate levels)
//   mul3(x) = xtime(x) ^ x   (~3 gate levels)
//   Each output byte: 3 XOR-reduces of 4 terms -- ~6 XOR gate levels total.
//
// GHASH (AES-GCM extension):
//   GHASH uses GF(2^128) with polynomial x^128 + x^7 + x^2 + x + 1.
//   Same principle; hardware uses carry-less multipliers (CLMUL instruction on x86).
//
// Interview follow-up questions:
//   1. Why is GF(2^8) multiplication not the same as integer multiplication mod 256?
//      Answer: Integer mod 256 uses carry; GF(2^8) uses XOR (carry-less). The results
//      differ for most inputs.
//   2. What is the multiplicative inverse of 0x02 in GF(2^8)?
//      Answer: 0x8D (since 0x02 * 0x8D = 0x01 in GF(2^8)).
//   3. How would you implement GF(2^128) multiplication for AES-GCM efficiently?
//      Answer: Use carry-less multiplication (PCLMULQDQ on x86) to compute the
//      256-bit unreduced product, then reduce modulo the GF(2^128) polynomial.
