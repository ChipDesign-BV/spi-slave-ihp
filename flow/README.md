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

### KLayout seal ring — librelane API mismatch

`librelane` ≤ 1.x ships an `ihp_seal_ring.py` that calls
`layout.create_cell("sealring", "SG13_dev", params)`.  This API works only
for native KLayout PCells; the IHP PDK registers its seal ring via a
`cni.dlo.PCellWrapper`, which requires `add_pcell_variant` instead.  The
script also passes die dimensions in database units (nm) where the PCell
expects µm.

If you encounter:

```
AttributeError: 'NoneType' object has no attribute 'cell_index'
```

at step KLayout.SealRing, patch the installed script
(`site-packages/librelane/scripts/klayout/ihp_seal_ring.py`) as follows:

1. Change `layout = pya.Layout()` → `layout = pya.Layout(True)`
2. Replace the `create_cell` block with:
   ```python
   lib = pya.Library.library_by_name("SG13_dev", "sg13g2")
   pcell_decl = lib.layout().pcell_declaration("sealring")
   p = pcell_decl.params_as_hash(pcell_decl.get_parameters())
   edge_box = float(re.sub(r"[a-zA-Z]+", "", p["edgeBox"].default))
   die_w_um = die_width / 1000.0 - edge_box * 2
   die_h_um = die_height / 1000.0 - edge_box * 2
   params = {"l": f"{die_w_um:.6f}u", "w": f"{die_h_um:.6f}u"}
   sealring_pcell_i = layout.add_pcell_variant(lib, pcell_decl.id(), params)
   ```
3. Add `import re` at the top of the file.
