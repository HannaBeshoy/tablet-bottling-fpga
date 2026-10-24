`timescale 1ns / 1ps
// ============================================================================
// counter.v - N-bit binary up counter with synchronous clear and enable
// Lab 8_5 N-bit counter (parameter N), Lab 8_1b synchronous clear,
// lecture: synchronous counters. Used as the tablet counter and the
// conveyor timer.
// ============================================================================
module counter #(parameter N = 4) (
    input              clk, clr, en,
    output reg [N-1:0] q
);
    always @(posedge clk)
        if (clr)     q <= 0;
        else if (en) q <= q + 1'b1;
endmodule
