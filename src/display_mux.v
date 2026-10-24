`timescale 1ns / 1ps
// ============================================================================
// display_mux.v - drives the 8-digit 7-segment display by scanning
//
// The 8 digits share the segment lines, so only one digit is switched on at
// a time. Moving to the next digit about 760 times a second makes all eight
// look lit at once. Everything here is a Digital Design lab block:
//   3-to-8 decoder, one-cold outputs (Lab 4_2b) -> an[7:0], active low
//   8-to-1 multiplexer, 4 bits wide (Lab 4_3)   -> value of the active digit
//   hex7seg (Lab 3_3)                           -> segment pattern a_to_g
// ============================================================================
module display_mux (
    input      [2:0] scan,              // active digit, from clkdiv
    input      [3:0] d7, d6, d5, d4,    // digit values, d7 = leftmost
    input      [3:0] d3, d2, d1, d0,    //               d0 = rightmost
    output reg [7:0] an,                // digit enables, active low
    output     [6:0] a_to_g,            // segments a..g, active low
    output           dp                 // decimal point, active low
);
    reg [3:0] digit;

    // 3-to-8 decoder with one-cold outputs: the selected anode is driven low
    always @(*)
        case (scan)
            3'd0:    an = 8'b11111110;
            3'd1:    an = 8'b11111101;
            3'd2:    an = 8'b11111011;
            3'd3:    an = 8'b11110111;
            3'd4:    an = 8'b11101111;
            3'd5:    an = 8'b11011111;
            3'd6:    an = 8'b10111111;
            default: an = 8'b01111111;
        endcase

    // 8-to-1 multiplexer: the value shown on the active digit
    always @(*)
        case (scan)
            3'd0:    digit = d0;
            3'd1:    digit = d1;
            3'd2:    digit = d2;
            3'd3:    digit = d3;
            3'd4:    digit = d4;
            3'd5:    digit = d5;
            3'd6:    digit = d6;
            default: digit = d7;
        endcase

    hex7seg U_seg (.x(digit), .a_to_g(a_to_g));

    // decimal points after digit 6 and digit 4 separate the three fields:
    //   PP.CC.BBBB  (preset . tablets in bottle . bottles filled)
    assign dp = ~((scan == 3'd6) | (scan == 3'd4));
endmodule
