`timescale 1ns / 1ps
// ============================================================================
// tb_bottling_top.v - system test of the whole tablet-bottling controller
//
// The divider periods are made small with parameters, so a bottle takes
// about a thousand clocks instead of seconds:
//   buttons sampled every 8 clocks     feeder tick every 64 clocks
//   conveyor runs 3 feeder ticks       display digit changes every clock
// Monitors check three safety rules on every clock. The scenario then runs
// the machine like an operator would and checks the result of each step.
// Every failed check prints a line starting with ERROR.
// ============================================================================
module tb_bottling_top;

    reg         clk = 1'b0;
    reg         cpu_resetn = 1'b0;
    reg         btnc = 1'b0, btnu = 1'b0, btnl = 1'b0, btnr = 1'b0, btnd = 1'b0;
    reg  [9:0]  sw = 10'd0;
    reg         sw15 = 1'b0;
    wire [15:0] led;
    wire [6:0]  a_to_g;
    wire [7:0]  an;
    wire        dp;

    localparam HOLD = 40;          // a button is held 40 clocks = 5 sample ticks

    integer    errors = 0, checks = 0, monitor_clocks = 0;
    reg [6:0]  count_saved;
    reg [15:0] bottles_saved;
    wire [15:0] bottles = {dut.bot3, dut.bot2, dut.bot1, dut.bot0};   // BCD

    bottling_top #(.SCAN_BIT(0), .SAMPLE_BITS(3), .FEED_BITS(6), .MOVE_TICKS(3)) dut (
        .clk(clk), .cpu_resetn(cpu_resetn),
        .btnc(btnc), .btnu(btnu), .btnl(btnl), .btnr(btnr), .btnd(btnd),
        .sw(sw), .sw15(sw15),
        .led(led), .a_to_g(a_to_g), .an(an), .dp(dp));

    always #5 clk = ~clk;          // 100 MHz

    // ------------------------------------------ safety monitors, every clock
    reg [6:0] prev_count = 7'd0;
    reg       prev_valve = 1'b0;
    always @(posedge clk) begin
        if (cpu_resetn) monitor_clocks = monitor_clocks + 1;
        if (dut.valve && dut.conveyor) begin
            errors = errors + 1;
            $display("ERROR %0t ns: valve and conveyor on together", $time);
        end
        if (dut.preset_ok && dut.count > dut.preset_bin) begin
            errors = errors + 1;
            $display("ERROR %0t ns: bottle overfilled, %0d > %0d", $time, dut.count, dut.preset_bin);
        end
        if (dut.count > prev_count && !prev_valve) begin
            errors = errors + 1;
            $display("ERROR %0t ns: tablet counted while the valve was closed", $time);
        end
        prev_count <= dut.count;
        prev_valve <= dut.valve;
    end

    // ------------------------------------------------------------ scenario
    initial begin
        $dumpfile("tb_bottling_top.vcd");
        $dumpvars(0, tb_bottling_top);

        // ---- 1. reset ----
        repeat (20) @(posedge clk);
        cpu_resetn = 1'b1;
        repeat (20) @(posedge clk);
        checks = checks + 1;
        if (!dut.idle || dut.count !== 7'd0 || dut.preset_bin !== 7'd0 || bottles !== 16'h0000) begin
            errors = errors + 1;
            $display("ERROR step 1: machine not cleared after reset");
        end

        // ---- 2. START with preset 00 is ignored ----
        btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnc = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (!dut.idle) begin
            errors = errors + 1;
            $display("ERROR step 2: machine started with preset 00");
        end

        // ---- 3. keypad: 1, 2 -> preset 12 ----
        sw = 10'b00_0000_0010;                              // key 1
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'b00_0000_0100;                              // key 2
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;
        checks = checks + 1;
        if (dut.preset_tens !== 4'd1 || dut.preset_ones !== 4'd2 || dut.preset_bin !== 7'd12) begin
            errors = errors + 1;
            $display("ERROR step 3: preset is %0d%0d, expected 12", dut.preset_tens, dut.preset_ones);
        end

        // ---- 4. two keys on: the higher key wins (27), then 1, 2 -> 12 again ----
        sw = 10'b00_1000_1000;                              // keys 7 and 3
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;
        checks = checks + 1;
        if (dut.preset_tens !== 4'd2 || dut.preset_ones !== 4'd7) begin
            errors = errors + 1;
            $display("ERROR step 4: preset is %0d%0d, expected 27", dut.preset_tens, dut.preset_ones);
        end
        sw = 10'b00_0000_0010;                              // 27 -> 71
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'b00_0000_0100;                              // 71 -> 12
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;
        checks = checks + 1;
        if (dut.preset_bin !== 7'd12) begin
            errors = errors + 1;
            $display("ERROR step 4: preset is %0d, expected 12", dut.preset_bin);
        end

        // ---- 5. display: "1" on digit 7, "2." on digit 6 ----
        // The display is read on falling clock edges, in the middle of a
        // clock period, never on the rising edge where the digit changes.
        @(negedge clk); while (an !== 8'b0111_1111) @(negedge clk);
        checks = checks + 1;
        if (a_to_g !== 7'b1001111 || dp !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR step 5: digit 7 shows %b, dp %b", a_to_g, dp);
        end
        @(negedge clk); while (an !== 8'b1011_1111) @(negedge clk);
        checks = checks + 1;
        if (a_to_g !== 7'b0010010 || dp !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR step 5: digit 6 shows %b, dp %b", a_to_g, dp);
        end

        // ---- 6. AUTO mode: fill three bottles ----
        sw15 = 1'b1;
        repeat (5) @(posedge clk);
        $display("WAVE_START %0t", $time);
        btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnc = 1'b0;
        checks = checks + 1;
        if (!dut.valve) begin
            errors = errors + 1;
            $display("ERROR step 6: valve did not open after START");
        end
        wait (bottles == 16'h0001);
        wait (dut.valve);                                   // bottle 2 in place
        $display("WAVE_END %0t", $time);
        wait (bottles == 16'h0003);
        #1;
        checks = checks + 1;
        if (!dut.conveyor || dut.count !== 7'd12) begin
            errors = errors + 1;
            $display("ERROR step 6: after bottle 3 expected conveyor on and 12 tablets");
        end

        // ---- 7. STOP while filling, START resumes with the same count ----
        wait (dut.valve && dut.count == 7'd5);
        btnl = 1'b1; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (!dut.idle || dut.valve) begin
            errors = errors + 1;
            $display("ERROR step 7: STOP did not close the valve");
        end
        count_saved = dut.count;
        repeat (300) @(posedge clk);                        // several feeder ticks
        btnl = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (count_saved !== 7'd5 || dut.count !== count_saved || !dut.idle) begin
            errors = errors + 1;
            $display("ERROR step 7: count changed while stopped (%0d -> %0d)", count_saved, dut.count);
        end
        btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnc = 1'b0;
        checks = checks + 1;
        if (!dut.valve) begin
            errors = errors + 1;
            $display("ERROR step 7: START did not resume filling");
        end

        // ---- 8. keypad is locked while the machine runs ----
        sw = 10'b10_0000_0000;                              // key 9
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;
        checks = checks + 1;
        if (dut.preset_bin !== 7'd12) begin
            errors = errors + 1;
            $display("ERROR step 8: preset changed while running");
        end

        // ---- 9. STOP while moving; START finishes the move, no double count ----
        wait (dut.conveyor);                                // bottle 4 full, moving
        bottles_saved = bottles;
        btnl = 1'b1; repeat (HOLD) @(posedge clk);
        btnl = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (!dut.idle || bottles_saved !== 16'h0004) begin
            errors = errors + 1;
            $display("ERROR step 9: expected IDLE with 4 bottles, bottles = %h", bottles);
        end
        btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnc = 1'b0;
        checks = checks + 1;
        if (!dut.conveyor) begin
            errors = errors + 1;
            $display("ERROR step 9: START should continue moving the full bottle");
        end
        wait (dut.valve); #1;                               // bottle 5 in place
        checks = checks + 1;
        if (bottles !== 16'h0004 || dut.count !== 7'd0) begin
            errors = errors + 1;
            $display("ERROR step 9: bottle counted twice, bottles = %h", bottles);
        end
        wait (bottles == 16'h0005);

        // ---- 10. reset clears everything ----
        cpu_resetn = 1'b0; repeat (10) @(posedge clk);
        cpu_resetn = 1'b1; repeat (10) @(posedge clk);
        checks = checks + 1;
        if (!dut.idle || dut.count !== 7'd0 || dut.preset_bin !== 7'd0 || bottles !== 16'h0000) begin
            errors = errors + 1;
            $display("ERROR step 10: reset did not clear the machine");
        end

        // ---- 11. MANUAL mode, preset 3, bouncing buttons ----
        sw15 = 1'b0;
        sw = 10'b00_0000_1000;                              // key 3
        btnu = 1'b1; repeat (HOLD) @(posedge clk);
        btnu = 1'b0; repeat (HOLD) @(posedge clk);
        sw = 10'd0;
        btnc = 1'b1; repeat (HOLD) @(posedge clk);
        btnc = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (dut.preset_bin !== 7'd3 || !dut.valve) begin
            errors = errors + 1;
            $display("ERROR step 11: expected preset 3 and the valve open");
        end
        // one press that bounces on press and on release = one tablet
        btnr = 1'b1; @(posedge clk); btnr = 1'b0; @(posedge clk);
        btnr = 1'b1; @(posedge clk); btnr = 1'b0; @(posedge clk);
        btnr = 1'b1; repeat (HOLD) @(posedge clk);
        btnr = 1'b0; @(posedge clk); btnr = 1'b1; @(posedge clk);
        btnr = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (dut.count !== 7'd1) begin
            errors = errors + 1;
            $display("ERROR step 11: one bouncing press counted %0d tablets", dut.count);
        end
        // two more tablets fill the bottle
        btnr = 1'b1; repeat (HOLD) @(posedge clk);
        btnr = 1'b0; repeat (HOLD) @(posedge clk);
        btnr = 1'b1; repeat (HOLD) @(posedge clk);
        btnr = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (dut.count !== 7'd3 || !dut.conveyor || bottles !== 16'h0001) begin
            errors = errors + 1;
            $display("ERROR step 11: expected a full bottle on the conveyor");
        end
        // tablet button while the valve is closed: not counted
        btnr = 1'b1; repeat (HOLD) @(posedge clk);
        btnr = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (dut.count !== 7'd3) begin
            errors = errors + 1;
            $display("ERROR step 11: tablet counted with the valve closed");
        end
        // bottle in place: count cleared, valve open again
        btnd = 1'b1; repeat (HOLD) @(posedge clk);
        btnd = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (!dut.valve || dut.count !== 7'd0) begin
            errors = errors + 1;
            $display("ERROR step 11: next bottle did not start filling");
        end
        // one tablet, then "bottle in place" while filling is ignored
        btnr = 1'b1; repeat (HOLD) @(posedge clk);
        btnr = 1'b0; repeat (HOLD) @(posedge clk);
        btnd = 1'b1; repeat (HOLD) @(posedge clk);
        btnd = 1'b0; repeat (HOLD) @(posedge clk);
        checks = checks + 1;
        if (!dut.valve || dut.count !== 7'd1) begin
            errors = errors + 1;
            $display("ERROR step 11: BTND during filling changed the count");
        end

        // ---- 12. display: count "01." and bottles "0001" ----
        // digit 5: count tens
        @(negedge clk); while (an !== 8'b1101_1111) @(negedge clk);
        checks = checks + 1;
        if (a_to_g !== 7'b0000001 || dp !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR step 12: digit 5 shows %b, dp %b", a_to_g, dp);
        end
        // digit 4: count ones
        @(negedge clk); while (an !== 8'b1110_1111) @(negedge clk);
        checks = checks + 1;
        if (a_to_g !== 7'b1001111 || dp !== 1'b0) begin
            errors = errors + 1;
            $display("ERROR step 12: digit 4 shows %b, dp %b", a_to_g, dp);
        end
        // digit 0: bottles ones
        @(negedge clk); while (an !== 8'b1111_1110) @(negedge clk);
        checks = checks + 1;
        if (a_to_g !== 7'b1001111 || dp !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR step 12: digit 0 shows %b, dp %b", a_to_g, dp);
        end

        // ---- summary ----
        $display("tb_bottling_top: %0d scenario checks, safety rules checked on %0d clocks, %0d errors",
                 checks, monitor_clocks, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end

    // watchdog: stop if a wait never ends
    initial begin
        #2000000;
        $display("ERROR: timeout");
        $display("FAIL");
        $finish;
    end
endmodule
