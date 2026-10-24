`timescale 1ns / 1ps
// ============================================================================
// bottling_fsm_gates.v - the same FSM, built from hand-derived equations
// Lecture FSM design steps 4-7: binary state encoding, encoded transition
// table, Boolean next-state and output equations, circuit.
//
// Encoding: IDLE = 00, FILL = 01, DONE = 11, MOVE = 10  (state = S1 S0)
//
//   S1' = S1 & ~stop & (S0 | ~in_place)  |  ~S1 & full & (S0 | ~stop & go)
//   S0' = ~S1 & ~S0 & ~stop & go & ~full
//       | ~S1 &  S0 & (full | ~stop)
//       |  S1 & ~S0 & ~stop & in_place
//
//   valve = ~S1 & S0    conveyor = S1 & ~S0    bottle_done = S1 & S0
//   idle  = ~S1 & ~S0
// The derivation is in the README. Ports match bottling_fsm.v, so either
// module can be used in bottling_top.v.
// ============================================================================
module bottling_fsm_gates (
    input        clk, rst,
    input        go, stop, full, in_place,
    output [1:0] state,
    output       idle, valve, conveyor, bottle_done
);
    reg  S1, S0;              // state register
    wire S1_next, S0_next;    // next-state logic

    assign S1_next = (S1 & ~stop & (S0 | ~in_place))
                   | (~S1 & full & (S0 | (~stop & go)));

    assign S0_next = (~S1 & ~S0 & ~stop & go & ~full)
                   | (~S1 &  S0 & (full | ~stop))
                   | ( S1 & ~S0 & ~stop & in_place);

    always @(posedge clk)
        if (rst) begin
            S1 <= 1'b0;
            S0 <= 1'b0;
        end
        else begin
            S1 <= S1_next;
            S0 <= S0_next;
        end

    assign state       = {S1, S0};
    assign idle        = ~S1 & ~S0;
    assign valve       = ~S1 &  S0;
    assign conveyor    =  S1 & ~S0;
    assign bottle_done =  S1 &  S0;
endmodule
