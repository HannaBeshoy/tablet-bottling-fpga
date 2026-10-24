`timescale 1ns / 1ps
// ============================================================================
// comparator.v - N-bit magnitude comparator
// Lab 5_1 comparator, made N bits wide with a parameter (as in Lab 8_5).
// Exactly one of the three outputs is 1.
// ============================================================================
module comparator #(parameter N = 7) (
    input      [N-1:0] a, b,
    output reg         a_lt_b, a_eq_b, a_gt_b
);
    always @(*) begin
        a_lt_b = 1'b0;
        a_eq_b = 1'b0;
        a_gt_b = 1'b0;
        if (a == b)     a_eq_b = 1'b1;
        else if (a > b) a_gt_b = 1'b1;
        else            a_lt_b = 1'b1;
    end
endmodule
