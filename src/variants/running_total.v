`timescale 1ns / 1ps
// ============================================================================
// running_total.v - the second half of the lecture's tablet-bottling system
//
// The lecture's block diagram also keeps the total number of tablets bottled:
// each time a bottle is finished, an adder adds the tablets in that bottle to
// register B. Here: a 14-bit adder and register B (0 .. 9999, it stops at 9999
// instead of wrapping), and a code converter to four BCD digits for the
// display (shift-and-add-3 method).
// ============================================================================
module running_total (
    input             clk, rst,
    input             clear,          // operator clears the total
    input             bottle_done,    // one clock per finished bottle
    input       [6:0] tablets,        // tablets in that bottle (0 .. 99)
    output reg [13:0] total,          // register B
    output     [15:0] total_bcd       // thousands, hundreds, tens, ones
);
    wire [14:0] sum = total + tablets;                    // the adder

    always @(posedge clk)
        if (rst | clear)      total <= 14'd0;
        else if (bottle_done) total <= (sum > 15'd9999) ? 14'd9999 : sum[13:0];

    // binary -> BCD with the shift-and-add-3 (double dabble) method: before each
    // shift, every BCD digit that is 5 or more gets 3 added, so that the shift
    // (a doubling) carries into the next digit at 10 instead of 16
    reg [15:0] bcd;
    integer k;
    always @(*) begin
        bcd = 16'd0;
        for (k = 13; k >= 0; k = k - 1) begin
            if (bcd[3:0]   >= 4'd5) bcd[3:0]   = bcd[3:0]   + 4'd3;
            if (bcd[7:4]   >= 4'd5) bcd[7:4]   = bcd[7:4]   + 4'd3;
            if (bcd[11:8]  >= 4'd5) bcd[11:8]  = bcd[11:8]  + 4'd3;
            if (bcd[15:12] >= 4'd5) bcd[15:12] = bcd[15:12] + 4'd3;
            bcd = {bcd[14:0], total[k]};
        end
    end
    assign total_bcd = bcd;
endmodule
