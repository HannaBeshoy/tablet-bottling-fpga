`timescale 1ns / 1ps
// ============================================================================
// key_encoder.v - keypad encoder: 10 keys -> BCD digit
// Lab 4_1c priority encoder, extended from 8 to 10 inputs; lecture: encoders.
//
// Switches SW0..SW9 act as the decimal keys 0..9. If more than one key is on,
// the highest key wins, like the 74HC147 decimal-to-BCD priority encoder.
// valid is the OR of all keys (bit-reduction operator, Lab 2_3a).
// ============================================================================
module key_encoder (
    input      [9:0] key,
    output reg [3:0] bcd,
    output           valid
);
    assign valid = |key;

    always @(*)
        if      (key[9]) bcd = 4'd9;
        else if (key[8]) bcd = 4'd8;
        else if (key[7]) bcd = 4'd7;
        else if (key[6]) bcd = 4'd6;
        else if (key[5]) bcd = 4'd5;
        else if (key[4]) bcd = 4'd4;
        else if (key[3]) bcd = 4'd3;
        else if (key[2]) bcd = 4'd2;
        else if (key[1]) bcd = 4'd1;
        else             bcd = 4'd0;   // key 0, or no key (then valid = 0)
endmodule
