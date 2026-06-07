"""Parse two VCD files (RTL and synth), compare key signals, and save waveform PNGs."""
import re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

# ---------------------------------------------------------------------------
# Minimal VCD parser
# ---------------------------------------------------------------------------

def parse_vcd(path):
    """Return (timescale_ns, {signal_name: (width, [(time, value), ...])})."""
    # id -> list of (name, width) — a single id can have aliases in different scopes
    id_to_names = {}
    waves = {}          # id -> [(time, value)]
    timescale_ns = 1

    with open(path) as f:
        text = f.read()

    m = re.search(r'\$timescale\s+(\d+)\s*(.*?)\s*\$end', text)
    if m:
        val, unit = int(m.group(1)), m.group(2).strip()
        if 'ps' in unit:   timescale_ns = val / 1000
        elif 'us' in unit: timescale_ns = val * 1000
        else:              timescale_ns = val

    for m in re.finditer(r'\$var\s+\w+\s+(\d+)\s+(\S+)\s+([\w\[\]:]+)', text):
        width, vid, raw_name = int(m.group(1)), m.group(2), m.group(3)
        name = re.sub(r'\[.*\]$', '', raw_name)   # strip "[7:0]" suffix
        if vid not in waves:
            waves[vid] = []
            id_to_names[vid] = []
        id_to_names[vid].append((name, width))

    cur_time = 0
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith('#'):
            cur_time = int(line[1:]) * timescale_ns
        elif line[0] in 'bB':
            parts = line.split()
            if len(parts) == 2:
                vid = parts[1]
                if vid in waves:
                    val_str = parts[0][1:].replace('x','0').replace('X','0').replace('z','0').replace('Z','0')
                    waves[vid].append((cur_time, int(val_str, 2)))
        elif len(line) >= 2 and line[0] in '01xXzZ':
            vid = line[1:]
            if vid in waves:
                waves[vid].append((cur_time, 0 if line[0] in 'xXzZ' else int(line[0])))

    # every alias (name) for an id shares the same wave list
    result = {}
    for vid, name_list in id_to_names.items():
        for name, width in name_list:
            if name not in result:
                result[name] = (width, waves[vid])
    return timescale_ns, result


def waveform_steps(entries, t_end):
    """Convert [(t, v)] to step-function arrays suitable for ax.step()."""
    if not entries:
        return np.array([0, t_end]), np.array([0, 0])
    t_arr, v_arr = zip(*entries)
    t_plot = [0] + list(t_arr) + [t_end]
    v_plot = [entries[0][1]] + list(v_arr) + [v_arr[-1]]
    return np.array(t_plot), np.array(v_plot)


# ---------------------------------------------------------------------------
# Load both VCDs
# ---------------------------------------------------------------------------
print("Parsing RTL VCD...")
_, rtl = parse_vcd("tb_spi_slave.vcd")
print("Parsing synth VCD...")
_, syn = parse_vcd("tb_spi_slave_synth.vcd")

T_END = 760

# ---------------------------------------------------------------------------
# B2B signal comparison
# ---------------------------------------------------------------------------
def final_val(wave_dict, name):
    entry = wave_dict.get(name)
    if entry is None: return None
    _, entries = entry
    return entries[-1][1] if entries else None

compare_sigs = [('rst_n',1), ('ssel',1), ('sck',1), ('mosi',1), ('miso',1), ('data',8), ('debug',8)]
print("\n=== B2B Signal Comparison at end of simulation ===")
all_match = True
for sig, width in compare_sigs:
    rv = final_val(rtl, sig)
    sv = final_val(syn, sig)
    match = rv == sv
    if not match: all_match = False
    status = "MATCH" if match else "MISMATCH ***"
    fmt = f"0x{{:0{(width+3)//4}X}}" if width > 1 else "{}"
    rv_s = fmt.format(rv) if rv is not None else "N/A"
    sv_s = fmt.format(sv) if sv is not None else "N/A"
    print(f"  {sig:12s}  RTL={rv_s:6s}  SYNTH={sv_s:6s}  {status}")

print(f"\nOverall B2B result: {'PASS — all signals match' if all_match else 'FAIL — mismatches detected'}")

# ---------------------------------------------------------------------------
# Plot 1: RTL waveform (full signal set)
# ---------------------------------------------------------------------------
SIG_LIST = [
    ('rst_n', 1, False),
    ('ssel',  1, False),
    ('sck',   1, False),
    ('mosi',  1, False),
    ('miso',  1, False),
    ('data',  8, True),
    ('debug', 8, True),
]
CLR_RTL   = '#1f77b4'
CLR_SYNTH = '#d62728'

fig, axes = plt.subplots(len(SIG_LIST), 1, figsize=(12, 7), sharex=True)
fig.suptitle("SPI Slave — RTL Simulation Waveform", fontsize=11, y=0.99)

for ax, (name, width, is_bus) in zip(axes, SIG_LIST):
    ax.set_ylabel(name, rotation=0, labelpad=42, va='center', fontsize=8)
    ax.set_yticks([])
    ax.set_ylim(-0.25, 1.25)
    for sp in ('top', 'right', 'left'): ax.spines[sp].set_visible(False)

    if name not in rtl: continue
    _, entries = rtl[name]
    t_arr, v_arr = waveform_steps(entries, T_END)
    maxv = (1 << width) - 1 if width > 1 else 1
    norm = v_arr / maxv if maxv > 0 else v_arr

    ax.step(t_arr, norm, where='pre', color=CLR_RTL, linewidth=1.3)
    ax.fill_between(t_arr, 0, norm, step='pre', alpha=0.15, color=CLR_RTL)

    if is_bus:
        prev_v = None
        for t_v, v_v in entries:
            if v_v != prev_v:
                ax.text(t_v + 3, 0.5, f'0x{v_v:02X}', fontsize=6.5,
                        va='center', ha='left', color=CLR_RTL)
                prev_v = v_v

# transaction annotations on top panel
for ax in axes:
    ax.axvspan(20, 360, alpha=0.04, color='green')
    ax.axvspan(360, 700, alpha=0.04, color='orange')
axes[0].text(190, 1.05, "Tx1: READ Register1 (addr=0x01)", fontsize=7.5,
             ha='center', color='darkgreen')
axes[0].text(530, 1.05, "Tx2: WRITE 0xFF → Register3 (addr=0x03)", fontsize=7.5,
             ha='center', color='darkorange')

axes[-1].set_xlabel("Time (ns)", fontsize=9)
axes[-1].set_xlim(0, T_END)
plt.tight_layout(rect=[0, 0, 1, 0.98])
fig.savefig("waveform_rtl.png", dpi=150, bbox_inches='tight')
print("Saved waveform_rtl.png")

# ---------------------------------------------------------------------------
# Plot 2: B2B overlay — RTL vs Synth
# ---------------------------------------------------------------------------
B2B_SIGS = [('ssel',1,False), ('miso',1,False), ('data',8,True), ('debug',8,True)]
fig2, axes2 = plt.subplots(len(B2B_SIGS), 1, figsize=(12, 5), sharex=True)
fig2.suptitle("SPI Slave — B2B Comparison: RTL vs Synthesized Netlist", fontsize=11, y=0.99)

for ax, (name, width, is_bus) in zip(axes2, B2B_SIGS):
    ax.set_ylabel(name, rotation=0, labelpad=42, va='center', fontsize=8)
    ax.set_yticks([])
    ax.set_ylim(-0.35, 1.35)
    for sp in ('top', 'right', 'left'): ax.spines[sp].set_visible(False)
    maxv = (1 << width) - 1 if width > 1 else 1

    for label, wave_dict, col, lw, ls in [('RTL', rtl, CLR_RTL, 2.0, '-'), ('Synth', syn, CLR_SYNTH, 1.2, '--')]:
        if name not in wave_dict: continue
        _, entries = wave_dict[name]
        t_arr, v_arr = waveform_steps(entries, T_END)
        norm = v_arr / maxv if maxv > 0 else v_arr
        ax.step(t_arr, norm, where='pre', color=col, linewidth=lw,
                linestyle=ls, label=label, alpha=0.9)

    ax.legend(fontsize=7.5, loc='upper right', framealpha=0.5)

axes2[-1].set_xlabel("Time (ns)", fontsize=9)
axes2[-1].set_xlim(0, T_END)
plt.tight_layout(rect=[0, 0, 1, 0.98])
fig2.savefig("waveform_b2b.png", dpi=150, bbox_inches='tight')
print("Saved waveform_b2b.png")
