#!/bin/sh
# run_sim.sh - run every testbench with Icarus Verilog (free, Linux/macOS/Windows)
# In Xilinx ISE you can run the same testbenches in ISim instead (see README).
set -e
cd "$(dirname "$0")"
mkdir -p out
SRC=../src

echo "== building-block tests"
iverilog -g2005 -Wall -s tb_blocks -o out/tb_blocks tb_blocks.v \
    $SRC/hex7seg.v $SRC/key_encoder.v $SRC/bcd2bin.v $SRC/bin2bcd.v \
    $SRC/comparator.v $SRC/bcd_counter.v
vvp -n out/tb_blocks

echo "== FSM: behavioral vs. hand-derived equations"
iverilog -g2005 -Wall -s tb_fsm_equiv -o out/tb_fsm_equiv tb_fsm_equiv.v \
    $SRC/bottling_fsm.v $SRC/bottling_fsm_gates.v
vvp -n out/tb_fsm_equiv

echo "== whole system"
iverilog -g2005 -Wall -s tb_bottling_top -o out/tb_bottling_top tb_bottling_top.v $SRC/*.v
cd out && vvp -n tb_bottling_top
