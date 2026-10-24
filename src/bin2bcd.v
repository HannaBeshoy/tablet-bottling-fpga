`timescale 1ns / 1ps
// ============================================================================
// bin2bcd.v - code converter B: 7-bit binary (0..99) -> two BCD digits
// Lecture: comparators, binary subtraction; Lab 4_1c (if-else priority),
// Lab 5 comparators, Lab 6 subtractor.
//
// A chain of comparators finds the tens digit (the first test that is true
// wins), then a subtractor removes tens * 10 to leave the ones digit.
// The tablet counter never passes 99, but values 100..127 show "EE" (error)
// instead of a wrong number.
// ============================================================================
module bin2bcd (
    input      [6:0] bin,
    output reg [3:0] tens,
    output     [3:0] ones
);
    reg [6:0] rest;

    always @(*) begin
        tens = 4'd0;            // defaults for 0..9 (and no latches)
        rest = bin;
        if      (bin >= 7'd100) begin tens = 4'hE; rest = 7'h0E;       end
        else if (bin >= 7'd90)  begin tens = 4'd9; rest = bin - 7'd90; end
        else if (bin >= 7'd80)  begin tens = 4'd8; rest = bin - 7'd80; end
        else if (bin >= 7'd70)  begin tens = 4'd7; rest = bin - 7'd70; end
        else if (bin >= 7'd60)  begin tens = 4'd6; rest = bin - 7'd60; end
        else if (bin >= 7'd50)  begin tens = 4'd5; rest = bin - 7'd50; end
        else if (bin >= 7'd40)  begin tens = 4'd4; rest = bin - 7'd40; end
        else if (bin >= 7'd30)  begin tens = 4'd3; rest = bin - 7'd30; end
        else if (bin >= 7'd20)  begin tens = 4'd2; rest = bin - 7'd20; end
        else if (bin >= 7'd10)  begin tens = 4'd1; rest = bin - 7'd10; end
    end

    assign ones = rest[3:0];
endmodule
