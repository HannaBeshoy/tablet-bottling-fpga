`timescale 1ns / 1ps
// ============================================================================
// tb_fsm_equiv.v - the behavioral FSM (bottling_fsm, a case statement) and
// the gate-level FSM (bottling_fsm_gates, the hand-derived equations) get
// the same random inputs. Their state and all four outputs must be equal on
// every clock. A 64-bit table records which (state, go, stop, full,
// in_place) combinations were tried: 4 states x 16 input patterns = 64.
// ============================================================================
module tb_fsm_equiv;
    reg  clk = 1'b0, rst = 1'b1;
    reg  go = 1'b0, stop = 1'b0, full = 1'b0, in_place = 1'b0;
    wire [1:0] st_b, st_g;
    wire idle_b, valve_b, conv_b, done_b;
    wire idle_g, valve_g, conv_g, done_g;

    bottling_fsm B (.clk(clk), .rst(rst), .go(go), .stop(stop), .full(full),
                    .in_place(in_place), .state(st_b), .idle(idle_b),
                    .valve(valve_b), .conveyor(conv_b), .bottle_done(done_b));

    bottling_fsm_gates G (.clk(clk), .rst(rst), .go(go), .stop(stop), .full(full),
                          .in_place(in_place), .state(st_g), .idle(idle_g),
                          .valve(valve_g), .conveyor(conv_g), .bottle_done(done_g));

    always #5 clk = ~clk;

    integer    cycle, i, errors = 0, covered = 0;
    reg [63:0] seen = 64'd0;
    reg [31:0] r;

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        for (cycle = 0; cycle < 200000; cycle = cycle + 1) begin
            @(negedge clk);
            // the two machines must agree after every clock edge
            if (st_b !== st_g || idle_b !== idle_g || valve_b !== valve_g ||
                conv_b !== conv_g || done_b !== done_g) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("ERROR cycle %0d: behavioral state %b, gate-level state %b",
                             cycle, st_b, st_g);
            end
            // new random inputs, and a reset about once every 256 clocks
            r        = $random;
            go       = r[0];
            stop     = r[1];
            full     = r[2];
            in_place = r[3];
            rst      = (r[11:4] == 8'd0);
            if (!rst) seen[{st_b, go, stop, full, in_place}] = 1'b1;
        end
        for (i = 0; i < 64; i = i + 1)
            if (seen[i]) covered = covered + 1;
        $display("tb_fsm_equiv: %0d clocks, %0d mismatches, %0d of 64 state/input combinations covered",
                 cycle, errors, covered);
        if (errors == 0 && covered == 64) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
