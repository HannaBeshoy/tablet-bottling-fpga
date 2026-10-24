`timescale 1ns / 1ps
// ============================================================================
// bottling_fsm.v - Moore FSM that controls the valve and the conveyor
// Lecture: finite state machines, FSM design steps, state encoding.
//
//   state  code  valve  conveyor  bottle_done   meaning
//   IDLE    00     0       0          0         stopped; preset can be entered
//   FILL    01     1       0          0         valve open, tablets fall in
//   DONE    11     0       0          1         bottle full: count it (1 clock)
//   MOVE    10     0       1          0         conveyor brings the next bottle
//
// Inputs: go (START pressed and preset is not 0), stop (STOP held),
// full (tablets in bottle >= preset), in_place (next bottle under the valve).
// Two rules keep the bottle count right when STOP is used:
//   * in FILL, full wins over stop, so a full bottle is always counted
//   * START from IDLE goes to MOVE if the bottle is already full
// The same machine built from the hand-derived equations is in
// bottling_fsm_gates.v; tb_fsm_equiv.v proves the two are equal.
// ============================================================================
module bottling_fsm (
    input            clk, rst,
    input            go, stop, full, in_place,
    output reg [1:0] state,
    output           idle, valve, conveyor, bottle_done
);
    localparam IDLE = 2'b00,
               FILL = 2'b01,
               DONE = 2'b11,
               MOVE = 2'b10;

    reg [1:0] next;

    // next-state logic
    always @(*)
        case (state)
            IDLE:    if (stop)            next = IDLE;
                     else if (go & full)  next = MOVE;   // resume a stopped move
                     else if (go)         next = FILL;
                     else                 next = IDLE;
            FILL:    if (full)            next = DONE;
                     else if (stop)       next = IDLE;
                     else                 next = FILL;
            DONE:    if (stop)            next = IDLE;
                     else                 next = MOVE;
            default: if (stop)            next = IDLE;   // MOVE
                     else if (in_place)   next = FILL;
                     else                 next = MOVE;
        endcase

    // state register: two D flip-flops
    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= next;

    // output logic: Moore, so the outputs depend on the state only
    assign idle        = (state == IDLE);
    assign valve       = (state == FILL);
    assign conveyor    = (state == MOVE);
    assign bottle_done = (state == DONE);
endmodule
