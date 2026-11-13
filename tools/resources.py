#!/usr/bin/env python3
"""Synthesises the variants for a Xilinx 7-series FPGA with Yosys and counts the
resources. Writes results/resources.md.

    apt install yosys      (or the OSS CAD Suite; any Yosys with ABC)
    python3 tools/resources.py
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
V = SRC / "variants"
YOSYS = shutil.which("yosys") or "yowasp-yosys"

DESIGNS = [
    ("FSM, binary encoding", "bottling_fsm_enc", {"ENC": 0}, [V / "bottling_fsm_enc.v"]),
    ("FSM, Gray encoding (as on the board)", "bottling_fsm_enc", {"ENC": 1}, [V / "bottling_fsm_enc.v"]),
    ("FSM, one-hot encoding", "bottling_fsm_enc", {"ENC": 2}, [V / "bottling_fsm_enc.v"]),
    ("Preset register, plain (on the board)", "preset_reg", {}, [SRC / "preset_reg.v"]),
    ("Preset register, Hamming-protected", "preset_reg_hamming", {}, [V / "preset_reg_hamming.v"]),
    ("Running total: adder, register B, BCD converter", "running_total", {}, [V / "running_total.v"]),
]


def synth(top, params, files):
    script = "; ".join([f"read_verilog {f}" for f in files]
                       + [f"chparam -set {k} {v} {top}" for k, v in params.items()]
                       + [f"synth_xilinx -family xc7 -top {top} -flatten -noiopad", "stat"])
    out = subprocess.run([YOSYS, "-p", script], cwd=SRC, capture_output=True, text=True)
    if out.returncode:
        sys.exit(out.stderr[-2000:])
    block = out.stdout.rsplit("Number of cells:", 1)[1]
    cells = {name: int(n) for name, n in re.findall(r"^\s+(\$?[A-Za-z0-9_]+)\s+(\d+)\s*$", block, re.M)}
    lut = sum(n for c, n in cells.items() if re.fullmatch(r"LUT[1-6]", c))
    ff = sum(n for c, n in cells.items() if re.fullmatch(r"FD[RSCP]E", c))
    return lut, ff, cells.get("CARRY4", 0)


def main():
    rows = ["| Design | LUTs | Flip-flops | CARRY4 |", "| --- | ---: | ---: | ---: |"]
    for label, top, params, files in DESIGNS:
        rows.append(f"| {label} | " + " | ".join(str(v) for v in synth(top, params, files)) + " |")
        print(rows[-1])
    (ROOT / "results").mkdir(exist_ok=True)
    (ROOT / "results" / "resources.md").write_text(
        "# Resources after synthesis\n\nYosys `synth_xilinx -family xc7` (Artix-7), cell counts from `stat`. "
        "Written by `tools/resources.py`.\n\n" + "\n".join(rows) + "\n")


if __name__ == "__main__":
    main()
