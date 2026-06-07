# spi_slave RTL-to-GDS Public Repo

This repository contains the RTL, testbench, and LibreLane/OpenROAD flow files needed to reproduce the `spi_slave` verification and place-and-route flow.

## Included files

- `spi_slave.v` — RTL design
- `tb_spi_slave.v` — original RTL testbench
- `tb_spi_slave_compare.v` — comparison testbench for RTL vs synthesized netlist
- `flow/Makefile` — build targets for LibreLane/OpenROAD
- `flow/README.md` — flow-specific documentation
- `flow/config.yaml` — LibreLane flow configuration
- `flow/constraint.sdc` — timing constraints
- `flow/run_flow.sh` — helper script to run the flow
- `flow/ihp_pdk.env.example` — PDK environment template
- `flow/place_route.tcl` — fallback OpenROAD script
- `flow/synth.ys` — Yosys synthesis script
- `flow/spi_slave_synth.v` — generated Yosys netlist
- `flow/spi_slave_synth.json` — synthesis metadata
- `verification_report.tex` — LaTeX verification report
- `verification_report.pdf` — compiled PDF report

## Prerequisites

- `yosys` in `PATH`
- `openroad` in `PATH`
- IHP PDK installed locally (for example `ihp-sg13g2`)

## Setup

1. Copy the PDK environment example:

   ```bash
   cp flow/ihp_pdk.env.example flow/ihp_pdk.env
   ```

2. Update `flow/ihp_pdk.env` to point to your local IHP PDK installation.

## Run the flow

```bash
cd spi_slave_github_repo/flow
./run_flow.sh
```

## Run simulation

From the repo root, RTL simulation:

```bash
cd spi_slave_github_repo
iverilog -g2012 -o tb_rtl.out tb_spi_slave_compare.v
vvp tb_rtl.out
```

Synthesis/netlist comparison:

```bash
cd spi_slave_github_repo
iverilog -g2012 -DSYNTH -o tb_synth.out flow/spi_slave_synth.v tb_spi_slave_compare.v
vvp tb_synth.out
```

## Notes

The flow is configured for the IHP SG13G2 PDK. External PDK paths are required and are not included in this repository.
