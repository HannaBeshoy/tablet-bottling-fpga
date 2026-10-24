`timescale 1ns / 1ps
// ============================================================================
// tb_blocks.v - exhaustive test of the building blocks
//   hex7seg      all 16 inputs, against the Lab 3_3 table
//   key_encoder  all 1024 switch combinations
//   bcd2bin      all 100 two-digit BCD numbers
//   bin2bcd      all 128 inputs (0..99, and 100..127 -> "EE")
//   comparator   all 128 x 128 input pairs
//   bcd_counter  4 cascaded digits: 0000 -> 9999 -> 0000, every value checked
// Expected values are computed here in a different way (loops, / and %)
// so a mistake in a block cannot hide in its own test.
// ============================================================================
module tb_blocks;
    integer errors = 0, checks = 0;
    integer i, j, k, expect_key, value;

    // hex7seg
    reg  [3:0] hx;
    wire [6:0] seg;
    reg  [6:0] seg_ref [0:15];
    hex7seg U_hex (.x(hx), .a_to_g(seg));

    // key_encoder
    reg  [9:0] key;
    wire [3:0] key_bcd;
    wire       key_valid;
    key_encoder U_enc (.key(key), .bcd(key_bcd), .valid(key_valid));

    // bcd2bin
    reg  [3:0] tens_in, ones_in;
    wire [6:0] bin_out;
    bcd2bin U_b2b (.tens(tens_in), .ones(ones_in), .bin(bin_out));

    // bin2bcd
    reg  [6:0] bin_in;
    wire [3:0] tens_out, ones_out;
    bin2bcd U_bin (.bin(bin_in), .tens(tens_out), .ones(ones_out));

    // comparator
    reg  [6:0] a, b;
    wire       lt, eq, gt;
    comparator #(.N(7)) U_cmp (.a(a), .b(b), .a_lt_b(lt), .a_eq_b(eq), .a_gt_b(gt));

    // 4-digit BCD counter chain, connected as in bottling_top
    reg        clk = 1'b0, clr = 1'b1, en = 1'b0;
    wire [3:0] d3, d2, d1, d0;
    wire       tc0, tc1, tc2;
    bcd_counter C0 (.clk(clk), .clr(clr), .en(en),  .q(d0), .tc(tc0));
    bcd_counter C1 (.clk(clk), .clr(clr), .en(tc0), .q(d1), .tc(tc1));
    bcd_counter C2 (.clk(clk), .clr(clr), .en(tc1), .q(d2), .tc(tc2));
    bcd_counter C3 (.clk(clk), .clr(clr), .en(tc2), .q(d3), .tc());
    always #5 clk = ~clk;

    initial begin
        // ---------------- hex7seg ----------------
        seg_ref[0]  = 7'b0000001;  seg_ref[1]  = 7'b1001111;
        seg_ref[2]  = 7'b0010010;  seg_ref[3]  = 7'b0000110;
        seg_ref[4]  = 7'b1001100;  seg_ref[5]  = 7'b0100100;
        seg_ref[6]  = 7'b0100000;  seg_ref[7]  = 7'b0001111;
        seg_ref[8]  = 7'b0000000;  seg_ref[9]  = 7'b0000100;
        seg_ref[10] = 7'b0001000;  seg_ref[11] = 7'b1100000;
        seg_ref[12] = 7'b0110001;  seg_ref[13] = 7'b1000010;
        seg_ref[14] = 7'b0110000;  seg_ref[15] = 7'b0111000;
        for (i = 0; i < 16; i = i + 1) begin
            hx = i; #1;
            checks = checks + 1;
            if (seg !== seg_ref[i]) begin
                errors = errors + 1;
                $display("ERROR hex7seg %h -> %b", hx, seg);
            end
        end

        // ---------------- key_encoder ----------------
        for (i = 0; i < 1024; i = i + 1) begin
            key = i; #1;
            expect_key = 0;
            for (k = 0; k < 10; k = k + 1)
                if (key[k]) expect_key = k;     // the highest key that is on
            checks = checks + 1;
            if (key_bcd !== expect_key || key_valid !== (i != 0)) begin
                errors = errors + 1;
                $display("ERROR key_encoder %b -> %0d, valid %b", key, key_bcd, key_valid);
            end
        end

        // ---------------- bcd2bin ----------------
        for (i = 0; i < 10; i = i + 1)
            for (j = 0; j < 10; j = j + 1) begin
                tens_in = i; ones_in = j; #1;
                checks = checks + 1;
                if (bin_out !== i * 10 + j) begin
                    errors = errors + 1;
                    $display("ERROR bcd2bin %0d%0d -> %0d", i, j, bin_out);
                end
            end

        // ---------------- bin2bcd ----------------
        for (i = 0; i < 128; i = i + 1) begin
            bin_in = i; #1;
            checks = checks + 1;
            if (i < 100) begin
                if (tens_out !== i / 10 || ones_out !== i % 10) begin
                    errors = errors + 1;
                    $display("ERROR bin2bcd %0d -> %h%h", i, tens_out, ones_out);
                end
            end
            else if (tens_out !== 4'hE || ones_out !== 4'hE) begin
                errors = errors + 1;
                $display("ERROR bin2bcd %0d -> %h%h, expected EE", i, tens_out, ones_out);
            end
        end

        // ---------------- comparator ----------------
        for (i = 0; i < 128; i = i + 1)
            for (j = 0; j < 128; j = j + 1) begin
                a = i; b = j; #1;
                checks = checks + 1;
                if (lt !== (i < j) || eq !== (i == j) || gt !== (i > j)) begin
                    errors = errors + 1;
                    $display("ERROR comparator %0d, %0d -> lt %b eq %b gt %b", i, j, lt, eq, gt);
                end
            end

        // ---------------- bcd_counter chain ----------------
        repeat (2) @(posedge clk);
        @(negedge clk) begin clr = 1'b0; en = 1'b1; end
        for (i = 1; i <= 10000; i = i + 1) begin
            @(posedge clk); #1;
            value = i % 10000;                  // 10000 counts wrap to 0000
            checks = checks + 1;
            if (d3 !== value / 1000 || d2 !== (value / 100) % 10 ||
                d1 !== (value / 10) % 10 || d0 !== value % 10) begin
                errors = errors + 1;
                $display("ERROR bcd counter after %0d counts shows %h%h%h%h", i, d3, d2, d1, d0);
            end
        end
        en = 1'b0;

        $display("tb_blocks: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
