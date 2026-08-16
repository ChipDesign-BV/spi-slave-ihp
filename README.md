# spi_slave — SPI Slave IP for IHP SG13G2

A small, synchronous SPI slave IP block implemented in Verilog and converted
to GDSII for the IHP SG13G2 0.13 µm BiCMOS process using the open-source
LibreLane/OpenROAD RTL-to-GDS flow.

**Author:** Koen Van Caekenberghe, ChipDesign B.V.
**License:** Apache 2.0
**PDK:** IHP SG13G2

The repository contains two variants:

| Variant | Location | SPI modes | Verified against |
|---|---|---|---|
| **Mode 0** (original) | repository root | 0 (CPOL=0, CPHA=0) | generic SPI master model |
| **All-modes** | [`allmodes/`](allmodes/) | 0–3, selected by `CPOL`/`CPHA` pins | Raspberry Pi (spidev) and Infineon AURIX (QSPI) master models |

Both variants share the register map and FSM; the all-modes variant adds two
mode-select input pins and generalises the SCK edge handling. See
[`allmodes/README.md`](allmodes/README.md) for its full documentation, and
[`verification_report.pdf`](verification_report.pdf) for the combined
verification and signoff report covering both variants and both
implementations (1.2 V `sg13g2_stdcell` and 3.3 V `sg13g2_stdcell_hv`),
including their comparison.

---

## Design overview (mode-0 variant)

The `spi_slave` module exposes eight 8-bit registers over SPI (Mode 0,
CPOL=0, CPHA=0) and provides a secondary parallel read port for on-chip
register readback independent of the SPI bus.

| Feature | Value |
|---|---|
| Protocol | SPI Mode 0 (CPOL=0, CPHA=0) |
| Register count | 8 × 8-bit |
| Address bits | 7 (lower bits of command byte) |
| R/nW flag | Bit 7 of command byte: 1=Read, 0=Write |
| Parallel read port | `Add2_in[7:0]` / `Data2_out[7:0]` |
| Debug port | `debug[7:0]` — sticky OR of FSM states visited |
| Reset | Active-low asynchronous (`iRST_N`) |

The SPI interface is a 5-state Moore FSM (IDLE → COMMAND → READ/WRITE → END).
All asynchronous SPI inputs pass through a two-flip-flop metastability
synchroniser before entering the system-clock domain.

---

## Repository layout

```
spi_slave.v                  RTL source (mode-0 variant)
spi_slave.gds                Final GDS (IHP SG13G2 core macro, DRC/LVS clean — see signoff note)
spi_slave.def                Final DEF
tb_spi_slave.v               RTL testbench (three SPI transactions: read, write, read-back)
tb_spi_slave_compare.v       B2B testbench (RTL vs synthesised netlist)
gen_waveforms.py             VCD parser and waveform PNG generator
waveform_rtl.png             RTL simulation waveform
waveform_b2b.png             B2B overlay waveform (RTL vs netlist)
verification_report.pdf      Verification & signoff report (both variants, both cell libraries)
report/                      Report source (Markdown, ChipDesign pandoc template)
flow/                        LibreLane flow configuration (see flow/README.md)
flow_hv/                     Thick-oxide (3.3 V) flow — sg13g2_stdcell_hv cells
signoff_hv/                  Thick-oxide GDS/DEF and its signoff DRC run
allmodes/                    All-modes variant: RTL, host testbenches, flows, GDS
```

---

## RTL simulation (mode-0 variant)

Requires [Icarus Verilog](https://steveicarus.github.io/iverilog/) ≥ 11.

### RTL testbench

```bash
iverilog -g2012 -o tb_rtl.out tb_spi_slave.v
vvp tb_rtl.out                    # produces tb_spi_slave.vcd
```

Expected output:

```
PASS 1100: miso_rx1=0x0B data=0xFF miso_rx3=0xFF debug=0x1F
```

### Back-to-back (RTL vs synthesised netlist)

```bash
# RTL
iverilog -g2012 -o tb_cmp_rtl.out tb_spi_slave_compare.v
vvp tb_cmp_rtl.out                # produces tb_spi_slave_compare.vcd

# Synthesised netlist (Yosys generic cells, no PDK library needed)
iverilog -g2012 -DSYNTH -o tb_cmp_syn.out flow/spi_slave_synth.v tb_spi_slave_compare.v
vvp tb_cmp_syn.out                # produces tb_spi_slave_synth.vcd
```

Both should print:

```
FINISH 1100: miso_rx1=0x0B data=0xFF miso_rx3=0xFF debug=0x1F
PASS: all checks passed
```

### Generate waveform images

```bash
pip install matplotlib numpy          # one-time
python3 gen_waveforms.py              # reads *.vcd, writes waveform_*.png
```

---

## RTL-to-GDS flow

Requires [IIC-OSIC-TOOLS](https://github.com/iic-jku/IIC-OSIC-TOOLS) or a
compatible environment with LibreLane, OpenROAD, and the IHP SG13G2 PDK.

```bash
cd flow
cp ihp_pdk.env.example ihp_pdk.env
# Edit ihp_pdk.env — set PDK_ROOT and PATH to match your installation
./run_flow.sh
```

The flow runs the LibreLane Classic flow (70 steps with LibreLane v3:
synthesis → floorplan → placement → CTS → routing → RCX → STA → GDS
stream-out). Final outputs land in `flow/runs/<RUN_DATE>/final/`. See
`flow/README.md` for LibreLane-version notes.

### Flow results (LibreLane v3.1.0, run RUN_2026-08-08_22-27-58)

| Metric | Value |
|---|---|
| Die size | 157.78 µm × 176.50 µm |
| Setup / hold WNS, TNS | 0 / 0 at all corners (ss 1.08 V 125 °C, tt 1.20 V 25 °C, ff 1.32 V −40 °C) |
| Routing DRC | 0 errors |
| Antenna check | 0 violations |
| LVS (Netgen) | Pass — circuits match uniquely (597 devices / 608 nets) |
| Signoff DRC (IHP KLayout deck) | Clean apart from 8 chip-level density/filler markers (foundry fill resolves at tapeout) |

> **Signoff note:** `spi_slave.gds` is the **core macro without seal ring**.
> The seal ring previously included in this file (inserted by the LibreLane
> `KLayout.SealRing` step) was found to be defective — it overlapped the
> routed core and carried a full-die `EdgeSeal` marker, failing the IHP
> signoff DRC deck with >21k violations. A seal ring must be added correctly
> at chip assembly. Full analysis in `verification_report.pdf`.

---

## Thick-oxide (3.3 V) builds

Both variants are also implemented on `sg13g2_stdcell_hv`, a thick-oxide
3.3 V rebuild of the IHP standard cells, in `flow_hv/` (mode-0) and
`allmodes/flow_hv/` (all-modes). The library is expected as a **sibling
checkout** next to this repository; `config.yaml` resolves it relatively.

```bash
cd flow_hv            # or allmodes/flow_hv
cp ihp_pdk.env.example ihp_pdk.env
./run_flow.sh
./verify_gl.sh        # gate-level simulation of the result
```

### Results

| Metric | mode-0 | all-modes |
|---|---|---|
| Die size | 354.4 × 400.0 µm | 354.0 × 399.6 µm |
| Std-cell area | 41 678 µm² | 41 630 µm² |
| Utilisation | 35.5 % | 36.2 % |
| Clock | 10 ns (100 MHz), same as the thin-oxide build | 10 ns (100 MHz) |
| Setup / hold WNS | 0 / 0 | 0 / 0 |
| Routing DRC | 0 | 0 |
| Antenna | 0 | 0 |
| LVS (Netgen) | clean | clean |
| Slew / cap / fanout violations | 0 / 0 / 0 | 0 / 0 / 0 |
| Signoff DRC (IHP KLayout deck) | clean* | clean* |
| Gate-level simulation | pass | pass, all 4 SPI modes |

\* Clean apart from the same 8 chip-level density/filler markers the
thin-oxide build carries (`M1.j`–`M5.j`, `TM1.c`/`TM2.c`, `AFil.g`) — they
apply to a filled die and resolve with foundry fill at tapeout. Getting
here surfaced a real library bug: the retargeted cells' rail-tap contacts
sat at cell-specific x positions, so any two *different* cells sharing a
rail in a placed block merged their taps into illegally short contact bars —
about 19 000 `Cnt`/`CntB` markers per build. The fix
(`sg13g2_stdcell_hv/work/fix_rail_contacts.py`) re-tiles every rail tap onto
the site-centred 0.48 µm grid; the library README documents it and the new
shared-rail regression harness that would have caught it.

The 3.3 V build is about **3.7× the cell area** of the 1.2 V build (41 678
against 11 284 µm²) and **5× the die area**: the thick-oxide cells are 7.14 µm
tall against 3.78 µm, and their PMOS is 2.4× wider. It still closes 100 MHz
with zero slack violations, so the SPI-side constraint (f_SCK ≤ f_Clk/8) is
unchanged at 12.5 MHz.

Timing is signed off at **one corner only** (typical, 3.30 V, 25 °C) — the
library is characterised nowhere else. That is weaker than the three-corner
signoff of the thin-oxide build, and power is not reported at all because the
library carries no internal-power tables.

### What the thick-oxide flow needs that the thin-oxide one does not

These are all documented in `flow_hv/config.yaml`, and every one of them is a
consequence of the library rather than of the design.

* **Flip-flop mapping (`hv_dff_map.v`).** `sg13g2_hv_sdfbbp_1` is the only
  flip-flop with layout, and `dfflibmap` cannot use it because its next state
  is a scan mux. The four flip-flop flavours the RTL produces are mapped onto
  it explicitly: `SET_B`/`RESET_B` tied off, and the scan mux reused as the
  clock-enable mux (`SCE = !E`, `SCD = Q`). `verify_gl.sh` is what shows this
  is right.
* **Excluded cells.** 12 flip-flops and latches are characterised but have no
  layout, so synthesis must not choose them. `sg13g2_hv_nand4_1` is excluded
  as well: its B pin has no routing track through it and no room to be
  widened to one, and place-and-route left it unconnected — Netgen saw the
  net split in two.
* **`RT_MIN_LAYER: Metal1`.** 25 of the library's signal pins are off the
  0.48 µm track grid (2 in the thin-oxide library), so the router needs
  Metal1 to jog to them.
* **Tie cells.** The library had none until this work; see its README.
* **No decap fillers.** Fill insertion runs after detailed routing, and this
  flow routes on Metal1 — the decap cells' tall Metal1 strap polygons are
  invisible to the router, so an inserted decap could land with its strap
  closer than the 0.18 µm Metal1 spacing to a routed wire (observed as 34
  `M1.b` signoff markers). The `fill_*` cells carry Metal1 only on the
  rails and cannot clash, so `DECAP_CELLS` points at them instead.

---

## Verification results (mode-0 variant)

All output signals are bit-for-bit identical between RTL and synthesised netlist:

| Signal | RTL | Synth | |
|---|---|---|---|
| `rst_n` | 1 | 1 | ✓ |
| `ssel` | 1 | 1 | ✓ |
| `sck` | 0 | 0 | ✓ |
| `mosi` | 1 | 1 | ✓ |
| `miso` | 1 | 1 | ✓ |
| `data` | 0xFF | 0xFF | ✓ |
| `debug` | 0x1F | 0x1F | ✓ |
| `miso_rx1` | 0x0B | 0x0B | ✓ |
| `miso_rx3` | 0xFF | 0xFF | ✓ |

`miso_rx1=0x0B` is Register 1's reset value read via SPI in Tx1.
`miso_rx3=0xFF` is the write-confirmation: Tx3 read back the 0xFF written by Tx2.
`debug=0x1F` confirms all five FSM states (IDLE, COMMAND, WRITE, READ, END) were visited.

![RTL simulation waveform — three transactions over 1200 ns](waveform_rtl.png)

![B2B overlay: RTL (blue) vs synthesised netlist (red dashed) — traces overlap completely](waveform_b2b.png)

The all-modes variant is additionally verified in all four SPI modes against
Raspberry Pi and AURIX QSPI master models, on RTL and synthesised netlist —
see [`allmodes/README.md`](allmodes/README.md).

See `verification_report.pdf` for the full combined analysis, including the
standalone signoff DRC/LVS investigation.

---

## License

Copyright 2026 Koen Van Caekenberghe, ChipDesign B.V.

Licensed under the [Apache License, Version 2.0](LICENSE).
