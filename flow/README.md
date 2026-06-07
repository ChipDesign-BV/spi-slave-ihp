# spi_slave RTL2GDS Flow

This directory contains a starter implementation for converting `spi_slave.v` into a gate-level design and placing/routing it with the IHP PDK.

## Files

- `ihp_pdk.env.example` - Example environment variables for locating IHP PDK files.
- `Makefile` - LibreLane build targets for RTL2GDS and OpenROAD.
- `config.yaml` - LibreLane flow configuration.
- `constraint.sdc` - Basic timing constraints for the `spi_slave` top-level clock.
- `run_flow.sh` - Orchestration script for LibreLane synthesis and OpenROAD.

## Prerequisites

- `yosys` in `PATH`
- `openroad` in `PATH`
- IHP PDK cell LEF / tech LEF / Liberty files installed locally

## Setup

1. Copy the example environment file:

   ```bash
   cp ihp_pdk.env.example ihp_pdk.env
   ```

2. Edit `ihp_pdk.env` and set the correct paths for your local IHP PDK installation.

## Run the flow

```bash
cd /foss/designs/spi_slave/flow
./run_flow.sh
```

The script will create a `work/` directory and invoke LibreLane to synthesize the design and generate the final GDS.

> In headless environments, `run_flow.sh` will skip the OpenROAD GUI step and still complete the RTL2GDS flow.

## Notes

- The LibreLane flow uses `config.yaml`; it requires a valid PDK root and PDK name.
- The existing `synth.ys` and `place_route.tcl` files remain available as fallback, but LibreLane is now the primary flow.
- This flow is intentionally scaffolded for an initial RTL2GDS implementation; additional PDK-specific tuning is expected once the actual IHP files are available.
