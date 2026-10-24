`timescale 1ns / 1ps
// ============================================================================
// preset_reg.v - Register A: number of tablets per bottle, two BCD digits
// Lecture: registers and shift registers; D flip-flop with enable.
//
// Each accepted key press shifts the digits left, like a calculator:
//   tens <= ones, ones <= new key
// so typing 1 then 2 gives 12. Eight D flip-flops with a common enable.
// ============================================================================
module preset_reg (
    input            clk, rst,
    input            shift,      // one-clock pulse: accept key_bcd
    input      [3:0] key_bcd,
    output reg [3:0] tens, ones
);
    always @(posedge clk)
        if (rst) begin
            tens <= 4'd0;
            ones <= 4'd0;
        end
        else if (shift) begin
            tens <= ones;
            ones <= key_bcd;
        end
endmodule
