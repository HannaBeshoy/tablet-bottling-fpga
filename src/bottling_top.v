`timescale 1ns / 1ps
// ============================================================================
// bottling_top.v - Tablet-bottling controller (Digital Design course project)
//
// The tablet-bottling system from the Digital Design lecture (slide 23,
// after Floyd, Digital Fundamentals), built as one digital system on the
// Digilent Nexys 4 DDR (Artix-7 XC7A100T, 100 MHz clock) in Xilinx ISE 14.7.
//
//   keypad -> encoder -> register A (preset) -> code converter A --+
//                                                                  v
//   tablet sensor -> tablet counter --------------------------> comparator
//                                                                  | full
//   START, STOP, bottle in place -------------------------> control FSM
//                                         -> valve, conveyor, bottle done
//   bottle done -> bottle counter (4 BCD digits)
//   preset, tablet count (code converter B), bottles -> 8-digit display
//
// Board I/O
//   SW0..SW9   keypad keys 0..9          BTNU  ENTER: add the key to the preset
//   SW15       1 = AUTO: built-in feeder BTNC  START
//              and conveyor timer        BTNL  STOP (hold)
//              0 = MANUAL: buttons       BTNR  tablet sensor    (MANUAL)
//   CPU RESET  reset (red button)        BTND  bottle in place  (MANUAL)
//
//   Display  PP.CC.BBBB  PP = tablets per bottle, CC = tablets in the bottle,
//                        BBBB = bottles filled              e.g. 12.07.0003
//   LED0 valve open   LED1 conveyor on   LED2 bottle full   LED3 idle
//   LED4 keypad on    LED5 key switch on LED6 AUTO mode     LED7 heartbeat
//   LED8..LED14 tablet count in binary   LED15 STOP held
// ============================================================================
module bottling_top #(
    // Board values; the testbench makes them small so simulation is fast.
    parameter SCAN_BIT    = 17,   // next display digit every 2^17 clocks
    parameter SAMPLE_BITS = 20,   // buttons sampled every 2^20 clocks (10.5 ms)
    parameter FEED_BITS   = 24,   // AUTO feeder: a tablet every 2^24 clocks (168 ms)
    parameter MOVE_TICKS  = 12    // AUTO conveyor: 12 feeder ticks (~2 s) per bottle
)(
    input         clk,            // 100 MHz oscillator
    input         cpu_resetn,     // CPU RESET button, active low
    input         btnc, btnu, btnl, btnr, btnd,
    input  [9:0]  sw,             // keypad keys 0..9
    input         sw15,           // AUTO / MANUAL
    output [15:0] led,
    output [6:0]  a_to_g,         // segments a..g, active low
    output [7:0]  an,             // digit enables, active low
    output        dp              // decimal point, active low
);

    // ------------------------------------------------------------ signals
    reg        rst_s0, rst;                // reset synchronizer
    reg        auto_s0, auto;              // AUTO switch synchronizer
    reg  [9:0] key_s0, key;                // keypad switch synchronizer
    wire [2:0] scan;                       // active display digit
    wire       sample_tick, feed_tick, heartbeat;
    wire       start_p, enter_p, tablet_p, place_p, stop_lvl;
    wire [3:0] key_bcd;
    wire       key_valid, entry_en;
    wire [3:0] preset_tens, preset_ones;   // register A, BCD
    wire [6:0] preset_bin;                 // code converter A output
    wire       preset_ok;                  // preset is not 0
    wire [6:0] count;                      // tablets in the bottle, binary
    wire       count_zero;
    wire       cnt_lt, cnt_eq, cnt_gt, full;
    wire       tablet, in_place, move_done;
    wire [3:0] move_cnt;
    wire [1:0] state;
    wire       idle, valve, conveyor, bottle_done;
    wire [3:0] bot3, bot2, bot1, bot0;     // bottles filled, 4 BCD digits
    wire       tc0, tc1, tc2;
    wire [3:0] count_tens, count_ones;     // code converter B output

    // --------------------------------- synchronizers: 2 D flip-flops each
    always @(posedge clk) begin
        rst_s0  <= ~cpu_resetn;   rst  <= rst_s0;
        auto_s0 <= sw15;          auto <= auto_s0;
        key_s0  <= sw;            key  <= key_s0;
    end

    // ----------------------------------------------- clock divider (Lab 8_6)
    clkdiv #(.SCAN_BIT(SCAN_BIT), .SAMPLE_BITS(SAMPLE_BITS), .FEED_BITS(FEED_BITS))
        U_div (.clk(clk), .clr(rst), .scan(scan), .sample_tick(sample_tick),
               .feed_tick(feed_tick), .heartbeat(heartbeat));

    // ----------------------- push-buttons: debounced, one pulse per press
    btn_pulse U_start  (.clk(clk), .rst(rst), .sample_tick(sample_tick),
                        .btn(btnc), .level(),         .pulse(start_p));
    btn_pulse U_enter  (.clk(clk), .rst(rst), .sample_tick(sample_tick),
                        .btn(btnu), .level(),         .pulse(enter_p));
    btn_pulse U_stop   (.clk(clk), .rst(rst), .sample_tick(sample_tick),
                        .btn(btnl), .level(stop_lvl), .pulse());
    btn_pulse U_tablet (.clk(clk), .rst(rst), .sample_tick(sample_tick),
                        .btn(btnr), .level(),         .pulse(tablet_p));
    btn_pulse U_place  (.clk(clk), .rst(rst), .sample_tick(sample_tick),
                        .btn(btnd), .level(),         .pulse(place_p));

    // ------------------------------------- keypad -> encoder -> register A
    key_encoder U_enc (.key(key), .bcd(key_bcd), .valid(key_valid));

    // the preset may change only while stopped with an empty bottle
    assign entry_en = idle & count_zero;

    preset_reg U_regA (.clk(clk), .rst(rst), .shift(enter_p & key_valid & entry_en),
                       .key_bcd(key_bcd), .tens(preset_tens), .ones(preset_ones));

    // ----------------------------------- code converter A and comparator
    bcd2bin U_convA (.tens(preset_tens), .ones(preset_ones), .bin(preset_bin));

    comparator #(.N(7)) U_comp (.a(count), .b(preset_bin),
                                .a_lt_b(cnt_lt), .a_eq_b(cnt_eq), .a_gt_b(cnt_gt));

    assign preset_ok  = |preset_bin;
    assign full       = preset_ok & (cnt_eq | cnt_gt);   // tablets >= preset
    assign count_zero = ~|count;

    // ------------------------------ tablet sensor and bottle in place
    // 2:1 multiplexers (Lab 4_3a) choose the AUTO source or the buttons
    assign tablet = auto ? feed_tick : tablet_p;

    // AUTO conveyor timer: counts feeder ticks while the conveyor runs
    counter #(.N(4)) U_move (.clk(clk), .clr(rst | ~conveyor),
                             .en(conveyor & feed_tick), .q(move_cnt));
    assign move_done = feed_tick & (move_cnt == MOVE_TICKS - 1);
    assign in_place  = conveyor & (auto ? move_done : place_p);

    // --------------------------------------------------- tablet counter
    // counts only while the valve is open and the bottle is not full;
    // cleared when the next empty bottle is in place
    counter #(.N(7)) U_tablets (.clk(clk), .clr(rst | in_place),
                                .en(tablet & valve & ~full), .q(count));

    // ------------------------------------------------ control FSM (Moore)
    bottling_fsm U_fsm (.clk(clk), .rst(rst), .go(start_p & preset_ok),
                        .stop(stop_lvl), .full(full), .in_place(in_place),
                        .state(state), .idle(idle), .valve(valve),
                        .conveyor(conveyor), .bottle_done(bottle_done));

    // ------------------- bottle counter: 4 cascaded BCD decade counters
    bcd_counter U_bot0 (.clk(clk), .clr(rst), .en(bottle_done), .q(bot0), .tc(tc0));
    bcd_counter U_bot1 (.clk(clk), .clr(rst), .en(tc0),         .q(bot1), .tc(tc1));
    bcd_counter U_bot2 (.clk(clk), .clr(rst), .en(tc1),         .q(bot2), .tc(tc2));
    bcd_counter U_bot3 (.clk(clk), .clr(rst), .en(tc2),         .q(bot3), .tc());

    // ------------------------------------- code converter B and display
    bin2bcd U_convB (.bin(count), .tens(count_tens), .ones(count_ones));

    display_mux U_disp (.scan(scan),
                        .d7(preset_tens), .d6(preset_ones),
                        .d5(count_tens),  .d4(count_ones),
                        .d3(bot3), .d2(bot2), .d1(bot1), .d0(bot0),
                        .an(an), .a_to_g(a_to_g), .dp(dp));

    // ------------------------------------------------------------- LEDs
    assign led[0]    = valve;
    assign led[1]    = conveyor;
    assign led[2]    = full;
    assign led[3]    = idle;
    assign led[4]    = entry_en;
    assign led[5]    = key_valid;
    assign led[6]    = auto;
    assign led[7]    = heartbeat;
    assign led[14:8] = count;
    assign led[15]   = stop_lvl;

endmodule
