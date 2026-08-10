# spi_slave — RTL-to-GDS Flow

LibreLane/OpenROAD flow for the `spi_slave` design targeting the IHP SG13G2
0.13 µm BiCMOS open PDK.

## Prerequisites

| Requirement | Notes |
|---|---|
| LibreLane | Classic flow, 1.x |
| OpenROAD | 2.x |
| Yosys | ≥ 0.40 |
| KLayout | 0.30.x with Python PCell support |
| IHP SG13G2 PDK | Open-source release from [IHP-Open-PDK](https://github.com/IHP-GmbH/IHP-Open-PDK) |

The simplest way to satisfy all dependencies is the
[IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) Docker/WSL2
container.

## Setup

```bash
cp ihp_pdk.env.example ihp_pdk.env
```

Edit `ihp_pdk.env` and set:

```bash
export PDK_ROOT=/path/to/pdks        # directory that contains ihp-sg13g2/
export PDK=ihp-sg13g2
export PATH=/path/to/foss/tools/bin:/path/to/foss/tools/sak:${PATH}
```

The PATH line is required because `run_flow.sh` invokes LibreLane via a
login shell (`bash -lc`) which may not inherit the interactive-shell PATH.

## Running the flow

```bash
./run_flow.sh
```

The flow runs 69 steps and writes outputs to `runs/<RUN_DATE>/`.
Final GDS and DEF are in `runs/<RUN_DATE>/final/`.

## Flow configuration

| File | Purpose |
|---|---|
| `config.yaml` | LibreLane Classic flow config (die area, design name, SDC paths) |
| `constraint.sdc` | Timing: 10 ns system clock; 2 ns I/O delays (adjust as needed) |
| `synth.ys` | Standalone Yosys script (used to pre-generate `spi_slave_synth.v`) |
| `place_route.tcl` | Fallback OpenROAD TCL script (not used by `run_flow.sh`) |

## Known issues / patches

### LibreLane v3: klayout must be on the login-shell PATH

The Makefile invokes LibreLane through `bash -lc`, so the PATH comes from
`ihp_pdk.env` only. The `KLayout.SealRing` step spawns the `klayout` binary
directly; if it is not on that PATH the flow dies at step ~66 with
`FileNotFoundError: [Errno 2] No such file or directory: 'klayout'`.
`ihp_pdk.env.example` therefore includes the klayout directory in its PATH
line. A failed run can be resumed without redoing PnR:

```bash
librelane config.yaml --pdk $PDK --pdk-root $PDK_ROOT --manual-pdk \
  --last-run --from KLayout.SealRing
```

### LibreLane v3: KLayout.SealRing output is defective — do not use it

With LibreLane v3.1.0 the seal-ring step runs to completion but produces a
broken ring: it is sized `die − 64.4 µm`, inset 32.2 µm into the die (so it
physically overlaps the routed core on Activ/pSD/Metal1/Cont), and its
`EdgeSeal` (39/4) marker is a full-die box instead of the ring annulus,
which makes the IHP signoff DRC deck classify the entire chip as seal-ring
structures (>15k violation markers). The repository's `spi_slave.gds` is
therefore the pre-seal-ring KLayout stream-out
(`runs/<RUN>/final/klayout_gds/`), which passes the IHP signoff deck apart
from the usual chip-level density/filler checks. Add the seal ring at chip
assembly instead. Full analysis: `../verification_report.pdf`.

### Historical note (librelane ≤ 1.x)

Older librelane releases shipped an `ihp_seal_ring.py` with a
`create_cell`/PCell API mismatch and an nm-vs-µm unit bug that crashed the
step with `AttributeError: 'NoneType' object has no attribute 'cell_index'`.
That patch is obsolete with LibreLane v3, which drives the seal ring through
the PDK-provided `KLAYOUT_SEALRING_SCRIPT`.
