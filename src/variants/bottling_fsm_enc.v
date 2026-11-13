`timescale 1ns / 1ps
// ============================================================================
// bottling_fsm_enc.v - the control FSM with a selectable state encoding
//
// Lecture topic "FSM state encoding": the same state graph as bottling_fsm.v,
// with the state stored in one of three codes.
//   ENC = 0  binary    IDLE 00, FILL 01, DONE 10, MOVE 11     2 flip-flops
//   ENC = 1  Gray      IDLE 00, FILL 01, DONE 11, MOVE 10     2 flip-flops
//   ENC = 2  one-hot   IDLE 0001, FILL 0010, DONE 0100, MOVE 1000   4 flip-flops
// The outputs are Moore outputs, so they are identical for every encoding;
// tb_variants.v checks that against bottling_fsm.v clock by clock, and
// tools/resources.py compares what each encoding costs.
// (bottling_fsm.v, the board design, uses the Gray code.)
// ============================================================================
module bottling_fsm_enc #(parameter ENC = 0) (
    input        clk, rst,
    input        go, stop, full, in_place,
    output [3:0] state_bits,          // for the testbench: the raw state register
    output       idle, valve, conveyor, bottle_done
);
    localparam W = (ENC == 2) ? 4 : 2;
    localparam [3:0] IDLE = (ENC == 2) ? 4'b0001 : 4'b0000,
                     FILL = (ENC == 2) ? 4'b0010 : 4'b0001,
                     DONE = (ENC == 2) ? 4'b0100 : (ENC == 1) ? 4'b0011 : 4'b0010,
                     MOVE = (ENC == 2) ? 4'b1000 : (ENC == 1) ? 4'b0010 : 4'b0011;

    reg [W-1:0] state, next;

    always @(*)
        case (state)
            IDLE[W-1:0]: if (stop)            next = IDLE[W-1:0];
                         else if (go & full)  next = MOVE[W-1:0];
                         else if (go)         next = FILL[W-1:0];
                         else                 next = IDLE[W-1:0];
            FILL[W-1:0]: if (full)            next = DONE[W-1:0];
                         else if (stop)       next = IDLE[W-1:0];
                         else                 next = FILL[W-1:0];
            DONE[W-1:0]: if (stop)            next = IDLE[W-1:0];
                         else                 next = MOVE[W-1:0];
            MOVE[W-1:0]: if (stop)            next = IDLE[W-1:0];
                         else if (in_place)   next = FILL[W-1:0];
                         else                 next = MOVE[W-1:0];
            default:                          next = IDLE[W-1:0];   // illegal one-hot codes recover
        endcase

    always @(posedge clk)
        if (rst) state <= IDLE[W-1:0];
        else     state <= next;

    assign state_bits  = state;
    assign idle        = (state == IDLE[W-1:0]);
    assign valve       = (state == FILL[W-1:0]);
    assign conveyor    = (state == MOVE[W-1:0]);
    assign bottle_done = (state == DONE[W-1:0]);
endmodule
