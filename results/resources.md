# Resources after synthesis

Yosys `synth_xilinx -family xc7` (Artix-7), cell counts from `stat`. Written by `tools/resources.py`.

| Design | LUTs | Flip-flops | CARRY4 |
| --- | ---: | ---: | ---: |
| FSM, binary encoding | 6 | 2 | 0 |
| FSM, Gray encoding (as on the board) | 6 | 2 | 0 |
| FSM, one-hot encoding | 9 | 4 | 0 |
| Preset register, plain (on the board) | 0 | 8 | 0 |
| Preset register, Hamming-protected | 66 | 13 | 10 |
| Running total: adder, register B, BCD converter | 206 | 14 | 31 |
