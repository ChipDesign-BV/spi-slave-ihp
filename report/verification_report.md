---
title: "SPI Slave IP for IHP SG13G2 — Verification & Signoff Report"
subtitle: "Mode-0 and all-modes (CPOL/CPHA) variants · 1.2 V (`sg13g2_stdcell`) and 3.3 V (`sg13g2_stdcell_hv`) implementations · RTL, host-level, RTL-to-GDS, DRC and LVS"
author:
  - "Koen Van Caekenberghe, Ph.D. — ChipDesign B.V. — [info@chipdesign.be](mailto:info@chipdesign.be)"
date: "2026-08-16 (rev. 2: thick-oxide implementations added)"
logo: "ChipDesign_logo.png"
---

# Scope and summary

This report documents the verification and physical signoff of the
`spi_slave` IP block for the IHP SG13G2 0.13 µm BiCMOS open PDK, in its two
variants:

* **Mode-0 variant** (repository root) — SPI mode 0 only (CPOL=0, CPHA=0).
* **All-modes variant** (`allmodes/`) — SPI modes 0–3, selected by two
  configuration pins `CPOL`/`CPHA`; designed to interface both a Raspberry
  Pi (spidev master) and an Infineon AURIX microcontroller (QSPI master).

Each variant is implemented **twice**: on the PDK's 1.2 V thin-oxide
library `sg13g2_stdcell` (sections 5–7) and on the 3.3 V thick-oxide
library `sg13g2_stdcell_hv` (section 8), for four GDS deliverables in
total. All verification steps pass for both variants and both libraries:

| Verification step | Mode-0 variant | All-modes variant |
|---|---|---|
| RTL functional testbench | pass | pass (all 4 modes) |
| B2B RTL vs. synthesised netlist | pass, bit-identical | pass, bit-identical (all 4 modes) |
| Raspberry Pi master model (RTL + netlist) | n/a | pass (all 4 modes) |
| AURIX QSPI master model, full register sweep (RTL + netlist) | n/a | pass (all 4 modes) |
| RTL-to-GDS flow, 1.2 V (LibreLane v3.1.0 Classic, 70 steps) | complete | complete |
| Static timing, 1.2 V (3 corners, setup + hold) | 0 violations | 0 violations |
| RTL-to-GDS flow, 3.3 V (`sg13g2_stdcell_hv`) | complete | complete |
| Static timing, 3.3 V (typical corner, setup + hold) | 0 violations | 0 violations |
| Gate-level simulation, 3.3 V netlist | pass | pass (all 4 modes) |
| Antenna check (both libraries) | 0 violations | 0 violations |
| LVS (both libraries) | match uniquely | match uniquely |
| Signoff DRC, IHP KLayout full deck (all four core macros) | clean¹ | clean¹ |

¹ Apart from eight single-marker chip-level metal-density and filler-presence
checks that fire on any unfilled macro (section 6.3); these are resolved by
foundry density fill at tapeout.

The signoff investigation additionally uncovered a **defect in the LibreLane
v3 `KLayout.SealRing` step** (section 7): the inserted seal ring physically
overlaps the routed core and carries an incorrect `EdgeSeal` marker. The
repository GDS deliverables are therefore the pre-seal-ring stream-outs; a
seal ring must be added correctly at chip assembly.

---

# Design description

## Architecture (both variants)

The `spi_slave` module exposes eight 8-bit registers over SPI and provides a
secondary parallel read port (`Add2_in`/`Data2_out`) for concurrent on-chip
register readback independent of the SPI bus.

| Feature | Value |
|---|---|
| Register map | 8 × 8-bit, addresses 0x00–0x07 |
| Command byte | bit 7 = R/nW (1 = read, 0 = write); bits 6:0 = address |
| Out-of-range read | returns 0xFF |
| Reset | active-low asynchronous `iRST_N`; registers reset to 0x0A…0x30 |
| Debug port | `debug[7:0]` — sticky OR of FSM states visited since reset |
| FSM | 5-state Moore: IDLE → COMMAND → READ/WRITE → END |

All asynchronous SPI inputs pass through a two-flip-flop metastability
synchroniser before entering the system-clock (`Clk`) domain; SPI clock
edges are detected by comparing two successive synchronised samples.

## All-modes extension

The all-modes variant adds two configuration inputs and generalises the edge
handling. The synchronised SCK is normalised with the clock polarity,

$$SCK_{norm} = SCK \oplus CPOL$$

so the FSM always sees mode-0 polarity: the leading edge is a rising edge of
$SCK_{norm}$, the trailing edge a falling edge. The clock phase then selects
the roles of the two edges:

| Mode | CPOL | CPHA | SCK idle | Sample edge (both sides) | Slave drives MISO on |
|---|---|---|---|---|---|
| 0 | 0 | 0 | low | leading (rising) | trailing (falling) |
| 1 | 0 | 1 | low | trailing (falling) | leading (rising) |
| 2 | 1 | 0 | high | leading (falling) | trailing (rising) |
| 3 | 1 | 1 | high | trailing (rising) | leading (falling) |

`CPOL`/`CPHA` pass through the same two-flop synchroniser and are latched
only while the FSM is in IDLE, so a transaction always runs with a
consistent mode pair; the pins may be strap resistors or host GPIOs, stable
before `SSEL` assertion.

Because SCK is oversampled by `Clk`, the synchroniser and edge detector add
up to three `Clk` cycles of latency between a physical SCK edge and the
MISO update. With the constraint $f_{SCK} \leq f_{Clk}/8$ the slave output is
guaranteed stable at the master's sampling edge with margin; at the
implemented $f_{Clk} = 100$ MHz this permits $f_{SCK} \leq 12.5$ MHz.

---

# RTL functional verification

## Mode-0 variant

Testbench `tb_spi_slave.v` (Icarus Verilog ≥ 11) executes three
transactions: Tx1 reads Register 1 (expects reset value 0x0B), Tx2 writes
0xFF to Register 3, Tx3 reads Register 3 back. Result:

```
PASS 1100: miso_rx1=0x0B data=0xFF miso_rx3=0xFF debug=0x1F
```

`debug = 0x1F` confirms all five FSM states were visited; `data = 0xFF`
confirms the write is also visible on the parallel read port.

## All-modes variant

Testbench `allmodes/tb_spi_slave.v` repeats a read/write/read-back sequence
in each of the four SPI modes, with a DUT reset between modes and a
mode-correct master model (data set up before the leading edge for CPHA=0,
changed on the leading edge for CPHA=1):

```
MODE 0 (CPOL=0 CPHA=0) 1120: miso_rx1=0x0b data=0xa0 miso_rx3=0xa0 debug=0x1f
MODE 1 (CPOL=0 CPHA=1) 2240: miso_rx1=0x0b data=0xa1 miso_rx3=0xa1 debug=0x1f
MODE 2 (CPOL=1 CPHA=0) 3360: miso_rx1=0x0b data=0xa2 miso_rx3=0xa2 debug=0x1f
MODE 3 (CPOL=1 CPHA=1) 4480: miso_rx1=0x0b data=0xa3 miso_rx3=0xa3 debug=0x1f
PASS: all checks passed in all 4 SPI modes
```

![All-modes RTL simulation — read/write/read-back in SPI modes 0–3, with mode windows shaded](../allmodes/waveform_rtl.png)

## Back-to-back RTL vs. synthesised netlist

Each variant's testbench is re-run against its Yosys-synthesised structural
netlist (`flow/spi_slave_synth.v`, generic cells). For both variants every
checked signal is bit-for-bit identical between RTL and netlist across the
entire simulation, and the same `PASS` line is printed.

![B2B overlay for the all-modes variant: RTL (blue) vs. synthesised netlist (red dashed) across all four modes — traces overlap completely](../allmodes/waveform_b2b.png)

---

# Host-level verification (all-modes variant)

Two additional testbenches model the intended host masters. Both run in all
four SPI modes against the RTL **and** the synthesised netlist (eight runs
in total, all passing), with the DUT clocked at its implemented 100 MHz.

## Raspberry Pi master model

`tb_spi_slave_rpi.v` models the BCM283x/BCM2711 SPI controller as driven by
spidev's `xfer2()`: CE0 asserted for the whole 2-byte buffer with about one
SCK period of setup, bytes clocked back-to-back with no inter-byte gap, MSB
first, 10 MHz SCK. Per mode it checks: register read (0x0B), write +
read-back (0x5A), the parallel port, an out-of-range address read (0xFF) and
`debug = 0x1F`.

```
PASS: Raspberry Pi master model — all checks passed in all 4 SPI modes
```

## AURIX QSPI master model

`tb_spi_slave_aurix.v` models an AURIX (TC2xx/TC3xx) QSPI channel: SLSO lead
and trail delays and an inter-word idle of one SCLK period each (SLSO held
asserted across the frame), 12.5 MHz SCLK — deliberately at the
$f_{Clk}/8$ limit to demonstrate margin. Per mode it performs a full
register-map sweep: writes a distinct value to all eight registers, reads
all eight back over SPI, reads all eight through the parallel port, then
checks the out-of-range read and the debug port.

```
PASS: AURIX QSPI master model — all checks passed in all 4 SPI modes
```

## Host wiring summary

| Host | Connections | Mode selection |
|---|---|---|
| Raspberry Pi (3.3 V, direct) | pin 19 MOSI, pin 21 MISO, pin 23 SCLK, pin 24 CE0 → `SSEL` | `spi.mode = 0…3` in spidev; strap or GPIO on `CPOL`/`CPHA` to match |
| AURIX (3.3 V pad supply) | QSPI `MTSR` → `MOSI`, `MRST` ← `MISO`, `SCLK` → `SCK`, `SLSO[n]` → `SSEL` | iLLD `clockPolarity` / `shiftClock` channel config; strap or GPIO on `CPOL`/`CPHA` |

Both hosts must keep the chip select asserted across the command + data
byte pair (spidev `xfer2` and a 2-byte QSPI exchange buffer both do), and
keep $f_{SCK} \leq f_{Clk}/8$.

---

# RTL-to-GDS implementation (1.2 V, `sg13g2_stdcell`)

Both variants were taken through the LibreLane v3.1.0 Classic flow
(70 steps) on the IHP SG13G2 open PDK's thin-oxide standard cell library,
with a 10 ns system clock constraint. Timing is analysed at three corners:
slow 1.08 V 125 °C, typical 1.20 V 25 °C, fast 1.32 V −40 °C.

| Metric | Mode-0 variant | All-modes variant |
|---|---|---|
| Flow run | RUN_2026-08-08_22-27-58 | RUN_2026-08-08_21-52-37 |
| Die size | 157.78 µm × 176.50 µm | 160.61 µm × 179.33 µm |
| Std-cell utilisation | ≈ 54 % | 53.5 % |
| Setup WNS / TNS (all corners) | 0 / 0 | 0 / 0 |
| Hold WNS / TNS (all corners) | 0 / 0 | 0 / 0 |
| Detailed-routing DRC errors | 0 | 0 |
| Antenna violations | 0 | 0 |
| Max slew / max cap violations | 0 / 0 | 0 / 0 |
| Max fanout violations | — | 1 (buffer drives 9 loads, limit 8; no timing impact) |
| Routed wirelength | — | 21.2 mm |
| Total power (tt, 1.2 V, 25 °C) | — | ≈ 1.08 mW |

![All-modes variant — final routed layout (LibreLane render)](../allmodes/layout_render.png)

---

# Signoff LVS and DRC

## LVS

LVS is performed by the flow's signoff stage: Magic extracts a SPICE netlist
from the final layout, and Netgen compares it against the post-PnR powered
Verilog netlist mapped to the PDK SPICE libraries.

| Design | Devices (layout = netlist) | Nets (layout = netlist) | Verdict |
|---|---|---|---|
| Mode-0 variant | 597 = 597 | 608 = 608 | **Circuits match uniquely** |
| All-modes variant | 617 = 617 | 630 = 630 | **Circuits match uniquely** |

Zero unmatched devices, nets or pins, and zero property failures in both
runs.

## DRC methodology

Signoff DRC uses the IHP SG13G2 KLayout rule deck
(`$PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/drc/run_drc.py`), full rule
set, deep mode, identical invocation for every run — violation counts from
different invocations of this deck are not comparable, so a fixed harness is
used throughout. The verdict is taken from the produced `.lyrdb` marker
database, not from the runner's exit code.

Two control runs anchor the interpretation:

1. **Pristine PDK standard cell** (`sg13g2_xnor2_1` from the PDK library)
   through the identical harness → 7 markers, all single-count chip-level
   density/filler checks. Confirms the harness does not flag IHP's own
   cells.
2. **Pre-seal-ring stream-outs** of both designs (below).

## DRC results

| Layout under test | Total markers | Content |
|---|---|---|
| Pristine PDK std cell (control) | 7 | chip-level density/filler only |
| Mode-0 core macro (pre-seal-ring) | 8 | chip-level density/filler only |
| All-modes core macro (pre-seal-ring) | 8 | chip-level density/filler only |
| Mode-0 final GDS incl. seal ring | 21,208 | seal-ring defect (section 7) |
| All-modes final GDS incl. seal ring | 15,177 | seal-ring defect (section 7) |

The eight core-macro markers are `M1.j`–`M5.j`, `TM1.c`, `TM2.c` (metal
density windows) and `AFil.g`/`GFil.g` (active/gate filler presence) — one
marker each. These are chip-level manufacturing-readiness checks that fire
on any macro without dummy fill; they are resolved by foundry density fill
at tapeout and are not layout defects. **Both core macros are therefore
DRC-clean**, and both are shipped as the repository's `spi_slave.gds`
deliverables.

---

# LibreLane v3 seal-ring defect

The seal-ringed final GDS produced by the LibreLane v3 `KLayout.SealRing`
step fails signoff DRC massively in both designs, with identical rule
signatures. The failure was isolated experimentally:

* **The ring physically overlaps the routed core.** The step generates the
  ring PCell sized `die − 64.4 µm` and inset 32.2 µm from the die origin —
  inside the core area instead of surrounding it. Measured overlap between
  ring and core geometry (Activ + pSD + Metal1 + Cont): ≈ 2,316 µm² in the
  mode-0 design's previously shipped GDS, ≈ 1,730 µm² in the all-modes
  design. Ring metal crossing core routing constitutes physical shorts to
  the grounded seal structure; these layouts are not manufacturable.
* **The `EdgeSeal` (39/4) marker is a full-die rectangle** instead of the
  ring annulus. The DRC deck derives the seal-ring region from this layer,
  so the entire chip is classified as seal-ring structure and every core
  shape violates the `Seal.*` rule family — the bulk of the 15k–21k
  markers. Rewriting `EdgeSeal` as the true annulus removes this cascade
  but cannot repair the physical core overlap.

Because the defect is in the flow step (present identically in both designs,
including the previously published mode-0 GDS), the repository deliverables
were regenerated from the DRC/LVS-clean pre-seal-ring KLayout stream-outs.
**The LibreLane v3 seal-ringed GDS must not be used for fabrication**; the
seal ring is to be added correctly at chip assembly. Flow-level notes and
the resume procedure are documented in `flow/README.md`.

---

# Thick-oxide (3.3 V) implementation

Both variants were re-implemented on **`sg13g2_stdcell_hv`**, a thick-oxide
3.3 V rebuild of the IHP standard cells (a sibling repository with its own
generation and sign-off report), through the same LibreLane v3.1.0 Classic
flow at the same 10 ns clock. The flows live in `flow_hv/` and
`allmodes/flow_hv/`; the signoff GDS/DEF and their DRC runs in
`signoff_hv/` and `allmodes/signoff_hv/`.

## Flow adaptations

Every deviation from the thin-oxide flow is a consequence of the library,
documented at the point of use in `flow_hv/config.yaml`:

* **Flip-flop mapping** (`hv_dff_map.v`): `sg13g2_hv_sdfbbp_1` is the only
  flip-flop with layout; the four flavours the RTL produces map onto it
  with the scan mux reused as the clock-enable mux. Gate-level simulation
  (`verify_gl.sh`) is what proves this mapping right.
* **Excluded cells**: 12 characterised-but-unlaid-out flip-flops/latches,
  plus `sg13g2_hv_nand4_1` (its B pin has no routing track through it).
* **Metal1 routing** (`RT_MIN_LAYER: Metal1`): 25 library pins sit off the
  0.48 µm vertical track grid, and the router needs Metal1 jogs to reach
  them.
* **No preventive antenna diodes**: the heuristic pass placed 1 088
  diodes the design does not need (~20 % of the std-cell area); targeted
  repair on the nets that need it keeps the antenna check at zero.
* **Rails-only fillers**: fillers are inserted after routing, and the
  decap cells' Metal1 straps are invisible to the router — with Metal1
  routing they can land inside the 0.18 µm Metal1 spacing of a routed
  wire. The `fill_*` cells carry Metal1 only on the rails.
* **One timing corner** (typical, 3.30 V, 25 °C): the library is
  characterised nowhere else, and it carries no internal-power tables, so
  power is not reported.

## Results

| Metric | Mode-0 variant | All-modes variant |
|---|---|---|
| Flow run | RUN_2026-08-16_13-42-07 | RUN_2026-08-16_13-42-22 |
| Die size | 354.38 µm × 399.98 µm | 354.01 µm × 399.61 µm |
| Std-cell area | 41 678 µm² | 41 630 µm² |
| Std-cell utilisation | 35.5 % | 36.2 % |
| Setup / hold WNS (typ 3.3 V 25 °C) | 0 / 0 | 0 / 0 |
| Detailed-routing DRC / antenna | 0 / 0 | 0 / 0 |
| Max slew / cap / fanout violations | 0 / 0 / 0 | 0 / 0 / 0 |
| LVS (Netgen) | match uniquely | match uniquely |
| Gate-level simulation | pass | pass, all 4 SPI modes |
| Signoff DRC (full IHP deck) | clean¹ | clean¹ |

Gate-level simulation runs the RTL testbenches against the synthesised
`sg13g2_hv_*` netlist using zero-delay functional models of the library
cells — the check that proves the non-standard flip-flop mapping.

The first signoff DRC of these builds reported ~19 000 `Cnt`/`CntB`
markers, which traced not to the flow but to a defect in the library
itself: rail-tap contacts at cell-specific x positions, merging illegally
wherever two *different* cells share a power rail — a geometry the
library's own DRC harness never built. The fix (site-centred rail-tap
grid) and the regression harness live in the library repository; both
builds were re-run on the fixed library. The full analysis is the
library's companion report, *The Shared-Rail Contact Clash in
sg13g2_stdcell_hv*.

## Comparing the two libraries

| | Mode-0, 1.2 V | Mode-0, 3.3 V | All-modes, 1.2 V | All-modes, 3.3 V |
|---|---|---|---|---|
| Library | `sg13g2_stdcell` | `sg13g2_stdcell_hv` | `sg13g2_stdcell` | `sg13g2_stdcell_hv` |
| Row height / tracks | 3.78 µm / 9 | 7.14 µm / 17 | 3.78 µm / 9 | 7.14 µm / 17 |
| Die size (µm) | 157.78 × 176.50 | 354.38 × 399.98 | 160.61 × 179.33 | 354.01 × 399.61 |
| Die area | 27 848 µm² | 141 745 µm² (**5.1×**) | 28 802 µm² | 141 462 µm² (**4.9×**) |
| Std-cell area | 11 284 µm² | 41 678 µm² (**3.7×**) | 11 737 µm² | 41 630 µm² (**3.5×**) |
| Utilisation | 53.8 % | 35.5 % | 53.5 % | 36.2 % |
| Clock closed | 100 MHz | 100 MHz | 100 MHz | 100 MHz |
| Timing corners | 3 (ss/tt/ff) | 1 (typ only) | 3 | 1 |
| Total power (tt) | ≈ 1.01 mW @ 1.2 V | not characterised | ≈ 1.08 mW @ 1.2 V | not characterised |
| Signoff DRC | clean¹ | clean¹ | clean¹ | clean¹ |

The ~3.6× cell-area and ~5× die-area cost of the 3.3 V build follows
directly from the library geometry — 1.89× taller rows and 2.40× wider
PMOS — not from the design: cell count and netlist structure are
essentially unchanged. Both libraries close the same 100 MHz clock with
zero slack violations, so the SPI-side constraint is identical
($f_{SCK} \leq f_{Clk}/8 = 12.5$ MHz), and the lower utilisation of the
thick-oxide builds is headroom, not congestion (routing closes with zero
DRC at 35–36 %). What the 3.3 V build buys is native 3.3 V I/O — direct
connection to the Raspberry Pi and AURIX hosts with no level shifting —
at the price of single-corner timing sign-off and no power numbers, both
library limitations rather than flow limitations.

---

# Conclusions

* Both `spi_slave` variants are functionally verified at RTL and against
  their synthesised netlists; the all-modes variant is additionally verified
  in all four SPI modes against Raspberry Pi and AURIX QSPI master models,
  including a full register-map sweep at the maximum-rated SCK of
  $f_{Clk}/8$.
* Both variants complete the LibreLane v3 RTL-to-GDS flow **on both
  standard-cell libraries** — 1.2 V `sg13g2_stdcell` and 3.3 V
  `sg13g2_stdcell_hv` — with zero timing, antenna and routing violations,
  and pass Netgen LVS with uniquely matching circuits; the thick-oxide
  netlists additionally pass gate-level simulation, proving the
  non-standard flip-flop mapping.
* All four core macros pass the IHP SG13G2 signoff DRC deck; the only
  residual markers are the expected chip-level density/filler checks
  common to all unfilled macros. The thick-oxide signoff surfaced, and
  drove the fix of, a shared-rail contact defect in the cell library
  (section 8.2).
* The thick-oxide build costs ~3.6× the cell area and ~5× the die area for
  the same 100 MHz closure, and buys native 3.3 V I/O toward both target
  hosts; its sign-off is weaker only where the library is (one timing
  corner, no power tables).
* The LibreLane v3 `KLayout.SealRing` step is defective (core overlap +
  wrong `EdgeSeal` marker) and its output is excluded from the
  deliverables. Seal-ring insertion, dummy fill, and final chip-level DRC
  remain tapeout-assembly tasks.
