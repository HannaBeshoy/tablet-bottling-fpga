# Project guide: Tablet-Bottling Controller

This guide explains how the design works, why it is built this way and how it was verified. The [README](../README.md) covers how to run it.

## 1. The system

The Digital Design lecture opens with a tablet-bottling system (slide 23, after Floyd, *Digital Fundamentals*):

- An operator types the number of tablets per bottle on a keypad.
- An **encoder** converts the key, **register A** stores it, and a decoder shows it on 7-segment displays.
- **Code converter A** turns the preset into binary for a **comparator**.
- A sensor sends one pulse per tablet to a **counter**, whose count goes to the comparator's other input.
- While the count is below the preset, the valve stays open. When the count equals the preset, the valve closes and the conveyor moves. The counter is cleared when the next bottle is in place.

This project builds that system and adds:

- a **control FSM** (IDLE, FILL, DONE, MOVE) with START and STOP;
- a 4-digit **bottle counter**;
- an 8-digit display `PP.CC.BBBB` (preset, tablets in this bottle, bottles filled);
- **AUTO** mode (built-in feeder and conveyor timer) and **MANUAL** mode (buttons);
- synchronized, debounced inputs.

Only the course's building blocks are used. There are no IP cores and no processor.

## 2. Signal flow, module by module

| Order | Module | What it does | Course topic |
| --- | --- | --- | --- |
| 1 | `btn_pulse.v` | one clean pulse per button press | D flip-flops (Lab 7) |
| 2 | `key_encoder.v` | 10 keys → BCD digit, highest key wins | priority encoder (Lab 4) |
| 3 | `preset_reg.v` | register A: two BCD digits | registers, shift registers |
| 4 | `bcd2bin.v` | code converter A: BCD → binary | BCD, adders (Lab 5) |
| 5 | `counter.v` | tablet counter and conveyor timer | counters (Lab 8) |
| 6 | `comparator.v` | count vs. preset | comparator (Lab 5) |
| 7 | `bottling_fsm.v` | control FSM, `case` statement | FSMs |
| 8 | `bottling_fsm_gates.v` | the same FSM from equations | FSM design steps 4–7 |
| 9 | `bcd_counter.v` | one decimal digit; 4 cascaded | decade counter (Lab 8) |
| 10 | `bin2bcd.v` | code converter B: binary → BCD | comparators, subtraction (Labs 5, 6) |
| 11 | `hex7seg.v` | 7-segment patterns | Lab 3 (unchanged) |
| 12 | `display_mux.v` | scans the 8 digits | decoder and multiplexer (Lab 4) |
| 13 | `clkdiv.v` | enable ticks and digit select | clock divider (Lab 8) |
| 14 | `bottling_top.v` | connects everything to the pins | top module |

**btn_pulse.v** conditions each button in three steps:

1. Two flip-flops synchronize it to the clock.
2. A flip-flop with enable samples it every 10.5 ms. A bounce lasts a few milliseconds, so one press gives one level change.
3. A flip-flop and an AND gate keep only the rising edge: `pulse = level & ~level_d`, exactly one clock long.

STOP uses the debounced `level` instead, because STOP acts while it is held.

**key_encoder.v.** SW0–SW9 are the keys. An `if`–`else` chain gives the highest key priority, like the 74HC147. `valid = |key` is the reduction OR from Lab 2.

**preset_reg.v.** Eight D flip-flops with a common enable. Each accepted key shifts the digits like a calculator: `tens <= ones; ones <= key`.

**bcd2bin.v.** The value is `tens * 10 + ones`, and `tens * 10 = tens * 8 + tens * 2`. A shift costs no logic, so the converter is two adders: `{tens, 3'b000} + {tens, 1'b0} + ones`.

**counter.v** is the Lab 8_5 N-bit counter with a synchronous clear and an enable.

- The 7-bit tablet counter is enabled by `tablet & valve & ~full`.
- It is cleared by `in_place`, when the next bottle arrives.
- In AUTO mode a 4-bit copy counts feeder ticks while the conveyor runs.

**comparator.v** is the Lab 5_1 comparator, made N bits wide with a parameter. The top module forms `full = preset_ok & (eq | gt)`. A preset of 00 never counts as full.

**bottling_fsm.v and bottling_fsm_gates.v.** The same Moore machine written two ways, with identical ports. See section 4.

**bcd_counter.v** is one decimal digit with `tc = en & (q == 9)`. Four digits are cascaded, each enabled by the previous digit's `tc`, like the lecture's cascaded counters. Because `tc` includes `en`, a digit rolls over only when it is actually counting.

**bin2bcd.v.** A chain of comparisons (≥ 90, ≥ 80 …) finds the tens digit, and a subtractor leaves the ones. Defaults at the top of the `always @(*)` block prevent latches. Values 100–127 cannot occur, but would show `EE`.

**display_mux.v.** The eight digits share one set of segment lines, so they are driven one at a time:

- a 3-to-8 decoder with one-cold outputs switches on one digit (anodes are active low);
- an 8-to-1 multiplexer selects that digit's value;
- `hex7seg` draws it.

Each digit is on for 1.31 ms, so the display refreshes at about 95 Hz. The decimal points after digits 6 and 4 separate the three fields.

**clkdiv.v** is the Lab 8_6 27-bit counter, but its outputs are enables, not clocks:

- `sample_tick` every 2^20 clocks (10.5 ms) for button sampling;
- `feed_tick` every 2^24 clocks (168 ms) for the AUTO feeder;
- `q[19:17]` select the display digit;
- `q[26]` blinks the heartbeat LED.

**bottling_top.v** wires everything together:

- The reset, the AUTO switch and the keypad switches each pass through two flip-flops.
- `entry_en = idle & count_zero`: the preset can only change while stopped with an empty bottle.
- Two 2:1 multiplexers choose the AUTO or MANUAL sources.
- The divider periods are parameters, so the testbench can shrink them.

## 3. Design decisions

1. **One clock, enable ticks.** The labs clock counters with a divider bit such as `q[26]`. That creates a second clock built from logic: it has skew, and the timing tools cannot check the paths between the two clocks. Here every flip-flop runs on the 100 MHz clock, and slow events are one-clock enable pulses.
2. **Clean inputs.** Every input from outside the FPGA is asynchronous to the clock: buttons, switches and reset. Two flip-flops in a row (a synchronizer) give a possibly metastable first flip-flop a whole clock period to settle. Buttons are also debounced and edge-detected.
3. **A Moore FSM.** The outputs drive actuators, so they come only from the state flip-flops and cannot glitch when an input changes. The one-clock delay (10 ns) does not matter.
4. **Rules for STOP.** In FILL, `full` wins over `stop`, so a full bottle is always counted. START from IDLE goes to MOVE if the bottle is already full, so a bottle is never counted twice.
5. **DONE is its own state.** It lasts exactly one clock, so `bottle_done` is a clean one-clock pulse that advances the bottle counter exactly once.
6. **Course blocks instead of operators.** The code converters use adders, comparators and a subtractor rather than `*`, `/` and `%`. The testbenches use `/` and `%` as an independent reference.
7. **No latches.** Every `always @(*)` block assigns all of its outputs on every path. Open-source synthesis (Yosys) confirms that no latch is inferred.

## 4. Control FSM

**Inputs:**

- `go`: START pressed and the preset is not 0
- `stop`: STOP held
- `full`: count ≥ preset
- `in_place`: the next bottle is in place

**Outputs:** `valve`, `conveyor`, `bottle_done`, `idle`.

**Encoding:** IDLE = 00, FILL = 01, DONE = 11, MOVE = 10. With this choice:

- every output is a single AND of the two state bits;
- the normal cycle FILL → DONE → MOVE changes one bit at a time;
- all four codes are used, so there is no unused state to get stuck in.

| Current state | Inputs | Next state |
| --- | --- | --- |
| IDLE | `stop` | IDLE |
| IDLE | `~stop & go & ~full` | FILL |
| IDLE | `~stop & go & full` | MOVE |
| FILL | `full` | DONE |
| FILL | `~full & stop` | IDLE |
| DONE | `stop` | IDLE |
| DONE | `~stop` | MOVE |
| MOVE | `stop` | IDLE |
| MOVE | `~stop & in_place` | FILL |
| any | none of the above | same state |

Next-state equations, with one product term per arrow into a state whose code has a 1 in that bit:

```
S1' = S1 & ~stop & (S0 | ~in_place)  |  ~S1 & full & (S0 | ~stop & go)
S0' = ~S1 & ~S0 & ~stop & go & ~full  |  ~S1 & S0 & (full | ~stop)  |  S1 & ~S0 & ~stop & in_place

valve = ~S1 & S0    conveyor = S1 & ~S0    bottle_done = S1 & S0    idle = ~S1 & ~S0
```

| Term | Arrow |
| --- | --- |
| `S1 & S0 & ~stop` | DONE → MOVE |
| `S1 & ~S0 & ~stop & ~in_place` | MOVE stays in MOVE |
| `~S1 & S0 & full` | FILL → DONE |
| `~S1 & ~S0 & ~stop & go & full` | IDLE → MOVE (resume a stopped move) |
| `~S1 & ~S0 & ~stop & go & ~full` | IDLE → FILL |
| `~S1 & S0 & (full \| ~stop)` | FILL → DONE, or stay in FILL |
| `S1 & ~S0 & ~stop & in_place` | MOVE → FILL |

Synthesis tools may re-encode an FSM. Yosys chooses one-hot for this one. In ISE, *FSM Encoding Algorithm = User* keeps the codes above.

## 5. Verification

| Testbench | Method | Result |
| --- | --- | --- |
| `tb_blocks.v` | exhaustive: hex7seg 16, key_encoder 1,024, bcd2bin 100, bin2bcd 128, comparator 16,384 inputs; BCD counter through 10,000 counts | 27,652 checks, 0 errors |
| `tb_fsm_equiv.v` | behavioral vs. gate-level FSM, 200,000 random clocks with random resets | 0 mismatches, 64 of 64 state/input combinations covered |
| `tb_bottling_top.v` | 12-step operator scenario; three safety rules on every clock | 26 checks, 6,327 clocks, 0 errors |

The system scenario:

1. reset
2. START blocked at preset 00
3. keypad entry
4. two keys at once
5. display digits
6. three bottles in AUTO
7. STOP and resume while filling
8. keypad locked while running
9. STOP and resume while moving, with no double count (5 bottles in total)
10. reset
11. MANUAL mode with bouncing buttons
12. display fields

The safety monitors check that:

- valve and conveyor are never on together;
- a bottle is never overfilled;
- no tablet is counted while the valve is closed.

## 6. Size

The design as written has 108 flip-flops: 24 synchronizers, 27 divider bits, 20 in the button circuits, 8 in register A, 11 in the counters, 2 for the FSM and 16 in the bottle counter. That is under 0.1 % of the XC7A100T's 126,800 flip-flops.

Yosys (`synth_xilinx`) reports 109 FDRE cells, because it re-encodes the FSM as one-hot and removes one unused flip-flop. It also uses 21 CARRY4 carry chains.

## 7. Interview questions to prepare

1. Describe the project in one minute.
2. Why enable ticks instead of divided clocks?
3. How are the buttons conditioned, and why three steps?
4. What is metastability, and where could it occur here?
5. Why a Moore machine?
6. What happens if STOP is pressed exactly when the bottle becomes full?
7. How was it verified, and why are the expected values computed differently?
8. How big is the design?
9. Why build code converter B from comparators instead of `/` and `%`?
10. How would you support presets up to 999?
11. What would you add before using it on a real machine?

Short answers are in sections 3–6.

- For question 10: add a hundreds digit to register A and extend bcd2bin with `hundreds * 100 = hundreds * 64 + hundreds * 32 + hundreds * 4`. Widen the counter and the comparator to 10 bits, and add a hundreds stage to bin2bcd.
- For question 11: use a real infrared break-beam sensor, add a timeout alarm when no tablet arrives while the valve is open and an illegal-state check, and test on the board.

## 8. Ideas to extend it

- An infrared break-beam tablet sensor on a Pmod port.
- The lecture's second half: a running total of tablets with an adder and register B.
- A real 4×4 keypad (Digilent PmodKYPD) instead of switches.
- A sensor timeout and an alarm output.
