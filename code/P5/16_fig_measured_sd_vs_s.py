"""Figure for the presentation: measured per-game rating SDs versus the s
that the averages-only models infer.

Inputs (all committed):
  outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv   historical per-game SD
  outputs/P5/M1a_Baseline/parameter_summary.csv          M1a Baseline s
  outputs/P4/ExternalSD_6416/comparison/scales.csv       M1b Baseline s

Output: figures/P5/fig07_measured_sd_vs_s.png

Run from the repository root:  python code/P5/16_fig_measured_sd_vs_s.py
"""

import csv

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

INK, INK2, MUTED, GRID, SURF = "#1a1a19", "#52514e", "#8a8984", "#e5e4e0", "#fcfcfb"
BLUE, ORANGE = "#2a78d6", "#eb6834"


def rows(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


sd = np.array([float(r["sd_hist"]) for r in rows(
    "outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv")])
m1a = {r["parameter"]: r for r in rows("outputs/P5/M1a_Baseline/parameter_summary.csv")}["s"]
m1b = {r["parameter"]: r for r in rows("outputs/P4/ExternalSD_6416/comparison/scales.csv")}["s"]

med = float(np.median(sd))
m1a_mean, m1a_lo, m1a_hi = (float(m1a[k]) for k in ("posterior_mean", "lower95", "upper95"))
m1b_mean, m1b_lo, m1b_hi = (float(m1b[k]) for k in
                            ("mean_baseline", "lower95_baseline", "upper95_baseline"))

fig, ax = plt.subplots(figsize=(9, 5), dpi=220)
fig.patch.set_facecolor(SURF)
ax.set_facecolor(SURF)

ax.hist(sd, bins=np.arange(0, 4.21, 0.1), color=BLUE, alpha=0.85, edgecolor=SURF,
        linewidth=0.6, label=f"Measured rating SD, {len(sd):,} games")
ax.axvline(med, color=BLUE, linestyle="--", linewidth=1.4)
ax.annotate(f"median {med:.2f}", xy=(med, ax.get_ylim()[1] * 0.80),
            xytext=(0.95, ax.get_ylim()[1] * 0.80), color=BLUE, ha="right",
            va="center", fontsize=11, fontweight="bold",
            arrowprops=dict(arrowstyle="->", color=BLUE, linewidth=1.2))

top = ax.get_ylim()[1]
for y, (name, mean, lo, hi) in zip(
        (0.62, 0.48),
        (("M1a Baseline", m1a_mean, m1a_lo, m1a_hi),
         ("M1b Baseline", m1b_mean, m1b_lo, m1b_hi))):
    ax.errorbar(mean, top * y, xerr=[[mean - lo], [hi - mean]], fmt="o", color=ORANGE,
                ecolor=ORANGE, elinewidth=2.2, capsize=4, markersize=6)
    ax.text(mean - 0.12, top * y, f"{name}: s = {mean:.2f}", color=ORANGE,
            ha="right", va="center", fontsize=10.5)
ax.axvline(3.0, color=MUTED, linewidth=1, linestyle=":")
ax.text(3.03, top * 0.97, "prior upper\nbound 3.0", color=MUTED, fontsize=9, va="top")

ax.set_xlim(0, 4.2)
ax.set_xlabel("Rating SD of one rater around a game's true score (rating points)", color=INK2)
ax.set_ylabel("Number of games", color=INK2)
ax.set_title("Measured rater SDs are about half what the averages-only models infer",
             color=INK, fontweight="bold", loc="left", fontsize=13)
ax.grid(axis="y", color=GRID, linewidth=0.6)
ax.set_axisbelow(True)
for side in ("top", "right"):
    ax.spines[side].set_visible(False)
for side in ("left", "bottom"):
    ax.spines[side].set_color(GRID)
ax.tick_params(colors=INK2)
fig.text(0.01, 0.01,
         "Blue: historical per-game SD (6,416 development games; snapshot date unverified). "
         "Orange: posterior mean and 95% interval of s, Uniform(0.5, 3) prior.",
         color=MUTED, fontsize=8)
fig.tight_layout(rect=(0, 0.03, 1, 1))
fig.savefig("figures/P5/fig07_measured_sd_vs_s.png", facecolor=SURF)
print(f"saved: median SD {med:.3f}; M1a s {m1a_mean:.3f}; M1b s {m1b_mean:.3f}")
