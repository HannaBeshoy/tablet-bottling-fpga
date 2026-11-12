`timescale 1ns / 1ps
// ============================================================================
// tb_enter_start.v - regression test for ENTER and START pressed together
//
// Found by formal verification (github.com/HannaBeshoy/tablet-bottling-formal):
// with preset 10 and key 0 held, ENTER and START accepted in the same clock
// started the machine (the preset was still 10) while the preset shifted to
// 00. The machine then filled with preset 0: "full" can never become true,
// so the valve stayed open for ever.
// Fix: ENTER is ignored in the clock where START is accepted.
// This test presses both buttons together and checks that the machine never
// fills with preset 00 and that the bottle is closed at the preset.
// ============================================================================
module tb_enter_start;

    reg         clk = 1'b0;
    reg         cpu_resetn = 1'b0;
    reg         btnc = 1'b0, btnu = 1'b0;
    reg  [9:0]  sw = 10'd0;
    wire [15:0] led;
    wire [6:0]  a_to_g;
    wire [7:0]  an;
    wire        dp;

    localparam HOLD = 40;          // a button is held 40 clocks = 5 sample ticks
    integer errors = 0, checks = 0, max_count = 0;

    bottling_top #(.SCAN_BIT(0), .SAMPLE_BITS(3), .FEED_BITS(6), .MOVE_TICKS(3)) dut (
        .clk(clk), .cpu_resetn(cpu_resetn),
        .btnc(btnc), .btnu(btnu), .btnl(1'b0), .btnr(1'b0), .btnd(1'b0),
        .sw(sw), .sw15(1'b1),          // AUTO: the feeder gives the tablets
        .led(led), .a_to_g(a_to_g), .an(an), .dp(dp));

    always #5 clk = ~clk;

    // safety rule, every clock: the machine never runs with preset 00
    reg reported = 1'b0;
    always @(posedge clk) begin
        if (cpu_resetn && !dut.idle && !dut.preset_ok && !reported) begin
            errors = errors + 1;
            reported = 1'b1;
            $display("ERROR %0t ns: machine running with preset 00", $time);
        end
        if (dut.count > max_count) max_count = dut.count;
    end

    task press_enter;
        begin
            btnu = 1'b1; repeat (HOLD) @(posedge clk);
            btnu = 1'b0; repeat (HOLD) @(posedge clk);
        end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        cpu_resetn = 1'b1;
        repeat (20) @(posedge clk);

        // preset 10
        sw = 10'b00_0000_0010; press_enter;                 // key 1
        sw = 10'b00_0000_0001; press_enter;                 // key 0
        checks = checks + 1;
        if (dut.preset_bin !== 7'd10) begin
            errors = errors + 1;
            $display("ERROR: preset is %0d, expected 10", dut.preset_bin);
        end

        // key 0 still held: ENTER and START pressed in the same clock
        btnu = 1'b1; btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; btnc = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;

        checks = checks + 1;
        if (dut.idle) begin
            errors = errors + 1;
            $display("ERROR: START was not accepted");
        end
        checks = checks + 1;
        if (dut.preset_bin !== 7'd10) begin
            errors = errors + 1;
            $display("ERROR: preset changed to %0d while starting", dut.preset_bin);
        end

        // long enough for two bottles of 10 tablets (64 clocks per tablet)
        repeat (2000) @(posedge clk);
        checks = checks + 1;
        if (max_count !== 10) begin
            errors = errors + 1;
            $display("ERROR: bottle filled to %0d tablets, expected 10", max_count);
        end
        checks = checks + 1;
        if ({dut.bot3, dut.bot2, dut.bot1, dut.bot0} < 16'h0002) begin
            errors = errors + 1;
            $display("ERROR: fewer than 2 bottles finished");
        end

        $display("tb_enter_start: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
