`timescale 1ns / 1ps
// ============================================================================
// bcd2bin.v - code converter A: two BCD digits -> 7-bit binary (0..99)
// Lecture: number systems and codes (BCD), binary addition; Lab 5 adders.
//
// value = tens * 10 + ones, and tens * 10 = tens * 8 + tens * 2.
// Multiplying by 8 or 2 is only a left shift (wiring), so the whole
// converter is two adders.
// ============================================================================
module bcd2bin (
    input  [3:0] tens, ones,
    output [6:0] bin
);
    assign bin = {tens, 3'b000} + {tens, 1'b0} + ones;
endmodule
