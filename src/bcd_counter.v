`timescale 1ns / 1ps
// ============================================================================
// bcd_counter.v - one decimal digit (0..9) of a BCD counter
// Lab 8_4 decimal counter; lecture: BCD decade counter, cascaded counters.
//
// tc (terminal count) is 1 when the digit is 9 and is being counted up.
// It enables the next digit, so digits can be cascaded: the next counter
// counts only when the previous one reaches its terminal count.
// ============================================================================
module bcd_counter (
    input            clk, clr, en,
    output reg [3:0] q,
    output           tc
);
    assign tc = en & (q == 4'd9);

    always @(posedge clk)
        if (clr)     q <= 4'd0;
        else if (tc) q <= 4'd0;        // 9 -> 0, and the next digit counts
        else if (en) q <= q + 1'b1;
endmodule
