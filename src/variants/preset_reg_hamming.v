`timescale 1ns / 1ps
// ============================================================================
// preset_reg_hamming.v - register A protected by a Hamming code
//
// Lecture topics "parity code" and "Hamming code". The preset (two BCD digits,
// 8 data bits) is stored as a 13-bit code word: a Hamming(12,8) code, whose
// four check bits sit at positions 1, 2, 4 and 8, plus one overall parity bit.
// Reading it back:
//   syndrome = 0, overall parity right   no error
//   overall parity wrong                 one bit flipped: the syndrome is its
//                                        position, the bit is corrected
//   syndrome != 0, overall parity right  two bits flipped: cannot be corrected,
//                                        `uncorrectable` goes high
// Why it matters here: a flipped bit in the preset would silently change how
// many tablets go into every bottle. With the code, one flip is repaired and
// two are reported, so the machine can stop instead of filling wrongly.
// `flip` exists for the testbench (fault injection); tie it to 0 on a board.
// ============================================================================
module preset_reg_hamming (
    input            clk, rst,
    input            shift,          // one-clock pulse: accept key_bcd
    input      [3:0] key_bcd,
    input     [12:0] flip,           // XORed into the stored word (fault injection)
    output     [3:0] tens, ones,     // corrected value
    output           corrected,      // a single-bit error was repaired
    output           uncorrectable   // a double-bit error was detected
);
    // ---- encoder: data bits go to positions 3,5,6,7,9,10,11,12 (1-based)
    function [12:0] encode(input [7:0] d);
        reg [12:1] c;
        begin
            c = 12'd0;
            c[3] = d[0]; c[5] = d[1]; c[6] = d[2]; c[7]  = d[3];
            c[9] = d[4]; c[10] = d[5]; c[11] = d[6]; c[12] = d[7];
            c[1] = c[3] ^ c[5] ^ c[7] ^ c[9]  ^ c[11];
            c[2] = c[3] ^ c[6] ^ c[7] ^ c[10] ^ c[11];
            c[4] = c[5] ^ c[6] ^ c[7] ^ c[12];
            c[8] = c[9] ^ c[10] ^ c[11] ^ c[12];
            encode = {c, ^c};                       // bit 0 = overall parity
        end
    endfunction

    reg [12:0] word;                                // {c[12:1], overall parity}
    wire [7:0] cur_data;

    always @(posedge clk)
        if (rst)        word <= encode(8'd0);
        else if (shift) word <= encode({cur_data[3:0], key_bcd});   // tens <= ones, ones <= key
        else            word <= word ^ flip;        // a stored fault stays until rewritten

    // ---- decoder
    wire [12:1] c = word[12:1];
    wire [3:0]  syndrome = { c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12],
                             c[4] ^ c[5] ^ c[6]  ^ c[7]  ^ c[12],
                             c[2] ^ c[3] ^ c[6]  ^ c[7]  ^ c[10] ^ c[11],
                             c[1] ^ c[3] ^ c[5]  ^ c[7]  ^ c[9]  ^ c[11] };
    wire        parity_bad = ^word;                 // overall parity over all 13 bits

    reg [12:1] fixed;
    always @(*) begin
        fixed = c;
        if (parity_bad && syndrome != 4'd0 && syndrome <= 4'd12)
            fixed[syndrome] = ~c[syndrome];
    end

    assign cur_data      = {fixed[12], fixed[11], fixed[10], fixed[9], fixed[7], fixed[6], fixed[5], fixed[3]};
    assign tens          = cur_data[7:4];
    assign ones          = cur_data[3:0];
    assign corrected     = parity_bad;                       // includes a flip of the parity bit itself
    assign uncorrectable = !parity_bad && syndrome != 4'd0;
endmodule
