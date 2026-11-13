`timescale 1ns / 1ps
// ============================================================================
// tb_variants.v - self-checking tests of the three variants in src/variants/
//   1. state encodings: binary, Gray and one-hot give the same outputs as
//      bottling_fsm.v on 20,000 random input clocks; counts the state bits
//      that change per transition
//   2. Hamming-protected preset: every value x every single-bit flip is
//      corrected, every double-bit flip is reported
//   3. running total: against a reference on random bottle sequences
// ============================================================================
module tb_variants;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;
    integer errors = 0, checks = 0;

    // ------------------------------------------------------------ 1. encodings
    reg go = 0, stop = 0, full = 0, in_place = 0;
    wire [1:0] s_ref;
    wire i_ref, v_ref, c_ref, d_ref;
    wire [3:0] sb [0:2];
    wire [2:0] i_e, v_e, c_e, d_e;
    bottling_fsm U_ref (.clk(clk), .rst(rst), .go(go), .stop(stop), .full(full), .in_place(in_place),
                        .state(s_ref), .idle(i_ref), .valve(v_ref), .conveyor(c_ref), .bottle_done(d_ref));
    genvar g;
    generate for (g = 0; g < 3; g = g + 1) begin : G_enc
        bottling_fsm_enc #(.ENC(g)) U (.clk(clk), .rst(rst), .go(go), .stop(stop), .full(full),
            .in_place(in_place), .state_bits(sb[g]), .idle(i_e[g]), .valve(v_e[g]),
            .conveyor(c_e[g]), .bottle_done(d_e[g]));
    end endgenerate

    reg [3:0] prev [0:2];
    integer flips [0:2], trans [0:2], maxflip [0:2];
    integer k, n, e, a, b;
    function integer ones(input [12:0] v); integer q; begin ones = 0; for (q = 0; q < 13; q = q + 1) ones = ones + v[q]; end endfunction

    // ------------------------------------------------------------ 2. Hamming
    reg shift = 0; reg [3:0] key = 0; reg [12:0] flip = 0;
    wire [3:0] h_tens, h_ones; wire h_corr, h_unc;
    preset_reg_hamming U_ham (.clk(clk), .rst(rst), .shift(shift), .key_bcd(key), .flip(flip),
                              .tens(h_tens), .ones(h_ones), .corrected(h_corr), .uncorrectable(h_unc));
    task load(input [3:0] t, input [3:0] o);
        begin
            @(negedge clk); shift = 1; key = t;
            @(negedge clk); key = o;
            @(negedge clk); shift = 0;
        end
    endtask
    task inject(input [12:0] f);
        begin @(negedge clk); flip = f; @(negedge clk); flip = 0; end
    endtask

    // ------------------------------------------------------------ 3. total
    reg clear = 0, bd = 0; reg [6:0] tablets = 0;
    wire [13:0] total; wire [15:0] bcd;
    running_total U_tot (.clk(clk), .rst(rst), .clear(clear), .bottle_done(bd), .tablets(tablets),
                         .total(total), .total_bcd(bcd));
    integer ref_total;
    function [15:0] ref_bcd(input integer v);
        reg [3:0] d3, d2, d1, d0;
        begin d3 = v / 1000 % 10; d2 = v / 100 % 10; d1 = v / 10 % 10; d0 = v % 10; ref_bcd = {d3, d2, d1, d0}; end
    endfunction

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;

        // 1. encodings
        for (e = 0; e < 3; e = e + 1) begin flips[e] = 0; trans[e] = 0; maxflip[e] = 0; prev[e] = sb[e]; end
        for (n = 0; n < 20000; n = n + 1) begin
            @(negedge clk);
            {go, stop, full, in_place} = $random;
            if (n % 16 != 0) stop = 0;                    // stop is rare, like on the machine
            #1;
            for (e = 0; e < 3; e = e + 1) begin
                checks = checks + 1;
                if ({i_e[e], v_e[e], c_e[e], d_e[e]} !== {i_ref, v_ref, c_ref, d_ref}) begin
                    errors = errors + 1;
                    if (errors <= 5) $display("FAIL encoding %0d differs from bottling_fsm at clock %0d", e, n);
                end
                if (sb[e] !== prev[e]) begin
                    k = ones({9'd0, sb[e] ^ prev[e]});
                    flips[e] = flips[e] + k; trans[e] = trans[e] + 1;
                    if (k > maxflip[e]) maxflip[e] = k;
                end
                prev[e] = sb[e];
            end
        end
        $display("encodings: %0d output checks; state bits changed per transition (average x100, maximum):", 3 * 20000);
        $display("  binary  %0d  %0d", 100 * flips[0] / trans[0], maxflip[0]);
        $display("  Gray    %0d  %0d", 100 * flips[1] / trans[1], maxflip[1]);
        $display("  one-hot %0d  %0d", 100 * flips[2] / trans[2], maxflip[2]);

        // 2. Hamming: all 256 stored values
        for (n = 0; n < 256; n = n + 1) begin
            load(n[7:4], n[3:0]);
            checks = checks + 1;
            if ({h_tens, h_ones} !== n[7:0] || h_corr || h_unc) begin errors = errors + 1; $display("FAIL hamming clean value %0d", n); end
            for (a = 0; a < 13; a = a + 1) begin           // every single-bit flip is corrected
                load(n[7:4], n[3:0]);
                inject(13'd1 << a);
                checks = checks + 1;
                if ({h_tens, h_ones} !== n[7:0] || !h_corr || h_unc) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("FAIL hamming value %0d, flip bit %0d: got %h corr=%b unc=%b", n, a, {h_tens, h_ones}, h_corr, h_unc);
                end
            end
            if (n % 16 == 5)                               // every double-bit flip is reported (16 values)
                for (a = 0; a < 13; a = a + 1)
                    for (b = a + 1; b < 13; b = b + 1) begin
                        load(n[7:4], n[3:0]);
                        inject((13'd1 << a) | (13'd1 << b));
                        checks = checks + 1;
                        if (!h_unc) begin
                            errors = errors + 1;
                            if (errors <= 10) $display("FAIL hamming value %0d, flips %0d and %0d not reported", n, a, b);
                        end
                    end
        end

        // 3. running total
        ref_total = 0;
        @(negedge clk); clear = 1; @(negedge clk); clear = 0;
        for (n = 0; n < 400; n = n + 1) begin
            @(negedge clk);
            bd = ($random % 3 == 0); tablets = $urandom % 100;
            if (n == 150) begin clear = 1; end else clear = 0;
            @(posedge clk); #1;
            if (clear) ref_total = 0;
            else if (bd) ref_total = (ref_total + tablets > 9999) ? 9999 : ref_total + tablets;
            checks = checks + 1;
            if (total !== ref_total || bcd !== ref_bcd(ref_total)) begin
                errors = errors + 1;
                if (errors <= 10) $display("FAIL total at step %0d: %0d (bcd %h), expected %0d", n, total, bcd, ref_total);
            end
        end
        for (n = 0; n < 120; n = n + 1) begin            // drive it into the 9999 limit
            @(negedge clk); bd = 1; tablets = 7'd99; clear = 0;
            @(posedge clk); #1;
            ref_total = (ref_total + 99 > 9999) ? 9999 : ref_total + 99;
            checks = checks + 1;
            if (total !== ref_total || bcd !== ref_bcd(ref_total)) begin errors = errors + 1; $display("FAIL total near the limit: %0d, expected %0d", total, ref_total); end
        end
        checks = checks + 1;
        if (total !== 14'd9999) begin errors = errors + 1; $display("FAIL total did not stop at 9999"); end

        if (errors == 0) $display("PASS: tb_variants, %0d checks, 0 errors", checks);
        else             $display("FAILED: tb_variants, %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
