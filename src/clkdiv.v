`timescale 1ns / 1ps
// ============================================================================
// clkdiv.v - free-running counter used as a clock divider (Lab 8_6)
//
// Each counter bit has half the frequency of the bit below it, so bit q[n]
// toggles at 100 MHz / 2^(n+1). In the lab, q[n] drives other flip-flops as
// a new clock. Here every flip-flop stays on the 100 MHz clock instead, and
// the divider gives:
//   scan        - three counter bits that select the active display digit
//   sample_tick - one-clock pulse every 2^SAMPLE_BITS clocks (button sampling)
//   feed_tick   - one-clock pulse every 2^FEED_BITS clocks (AUTO feeder)
//   heartbeat   - q[26], about 0.75 Hz, blinks an LED (Lab 8_6 clk1)
// A tick is used as an enable (D flip-flop with enable, lecture) so the whole
// design stays synchronous to one clock.
// ============================================================================
module clkdiv #(
    parameter SCAN_BIT    = 17,   // scan = q[19:17]: next digit every 1.31 ms
    parameter SAMPLE_BITS = 20,   // sample_tick every 2^20 clocks = 10.5 ms
    parameter FEED_BITS   = 24    // feed_tick every 2^24 clocks = 168 ms (~6 Hz)
)(
    input        clk, clr,
    output [2:0] scan,
    output       sample_tick,
    output       feed_tick,
    output       heartbeat
);
    reg [26:0] q;   // 27-bit counter, as in Lab 8_6

    always @(posedge clk)
        if (clr) q <= 27'd0;
        else     q <= q + 1'b1;

    assign scan        = q[SCAN_BIT+2:SCAN_BIT];
    assign sample_tick = (q[SAMPLE_BITS-1:0] == 0);
    assign feed_tick   = (q[FEED_BITS-1:0] == 0);
    assign heartbeat   = q[26];
endmodule
