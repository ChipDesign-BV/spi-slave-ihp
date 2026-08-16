#!/usr/bin/env bash
# Gate-level simulation of the thick-oxide build against the RTL testbench.
#
# This is the check that matters for the thick-oxide port, because the
# flip-flop mapping is not the usual one: sg13g2_hv_sdfbbp_1 is the only
# flip-flop in the library with layout, so hv_dff_map.v maps every flop onto
# it -- tying SET_B/RESET_B off, and using the scan mux as the clock-enable
# mux (SCE = !E, SCD = Q). Whether that is right is a simulation question,
# not a review question.
#
# The library's Verilog models cannot be fed to Icarus as they ship (they use
# `ifnone` on edge-sensitive paths, and their delayed_*/notifier signals come
# from inside the specify block), so the library's own
# work/make_functional_models.py is used to write a zero-delay copy first.
#
# Usage:  ./verify_gl.sh [run_dir]     (default: newest runs/RUN_*)
set -euo pipefail
cd "$(dirname "$0")"

HV_LIB=$(cd ../../sg13g2_stdcell_hv && pwd)
PDK_ROOT=${PDK_ROOT:-/foss/pdks}
UDP="$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_udp.v"
TB=../tb_spi_slave_compare.v

RUN=${1:-$(ls -d runs/RUN_* 2>/dev/null | tail -1)}
[[ -n "$RUN" && -d "$RUN" ]] || { echo "ERROR: no run directory; run ./run_flow.sh first"; exit 1; }

NL=$(ls "$RUN"/*yosys-synthesis/*.nl.v 2>/dev/null | head -1)
[[ -f "$NL" ]] || { echo "ERROR: no synthesis netlist under $RUN"; exit 1; }

mkdir -p gl
python3 "$HV_LIB/work/make_functional_models.py" \
    "$HV_LIB/verilog/sg13g2_stdcell_hv.v" gl/hv_models_func.v

echo "=== netlist: $NL"
iverilog -g2012 -DSYNTH -o gl/tb_gl.out "$UDP" gl/hv_models_func.v "$NL" "$TB"
vvp gl/tb_gl.out | tee gl/tb_gl.log

grep -q "^PASS" gl/tb_gl.log
