"""Presentation figures for the pseudo-vote comparison.

fig_bgg_m_only.png           BGG's implied dummy votes per game (opening slide;
                             shown before our models are introduced)
fig_pseudovotes_comparison.png  our M1a Extended effective m per game against
                             BGG's implied m (closing slide)

Inputs: outputs/P6/bgg_implied_m_by_game.csv, outputs/P6/ranking_model_effective_m.csv,
outputs/P6/bgg_benchmark_summary.csv. Run from the repository root:

    python code/P6/06_fig_pseudovotes.py
"""

import csv

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

INK, INK2, MUTED, GRID, SURF = "#1a1a19", "#52514e", "#8a8984", "#e5e4e0", "#fcfcfb"
BLUE, ORANGE = "#2a78d6", "#eb6834"


def col(path, name):
    with open(path, newline="") as f:
        return np.array([float(r[name]) for r in csv.DictReader(f) if r[name] not in ("", "NA")])


bgg = col("outputs/P6/bgg_implied_m_by_game.csv", "m_implied")
ours = col("outputs/P6/ranking_model_effective_m.csv", "m_eff")
with open("outputs/P6/bgg_benchmark_summary.csv", newline="") as f:
    S = {r["quantity"]: float(r["value"]) for r in csv.DictReader(f)}
best = S["bgg_m_best_single_fit"]
bins = np.logspace(-0.3, 4.7, 90)


def style(ax, title):
    ax.set_facecolor(SURF)
    ax.set_xscale("log")
    ax.set_xlabel("Pseudo-votes per game (log scale)", color=INK2)
    ax.set_ylabel("Number of games", color=INK2)
    ax.set_title(title, color=INK, fontweight="bold", loc="left", fontsize=13)
    ax.grid(axis="y", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(GRID)
    ax.tick_params(colors=INK2)
    ax.set_xticks([1, 10, 100, 1000, 10000])
    ax.set_xticklabels(["1", "10", "100", "1,000", "10,000"])


def save(fig, path, caption):
    fig.text(0.01, 0.01, caption, color=MUTED, fontsize=8)
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(path, facecolor=SURF)
    plt.close(fig)


# -- BGG only ------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5), dpi=220)
fig.patch.set_facecolor(SURF)
ax.hist(bgg, bins=bins, color=ORANGE, alpha=0.9, edgecolor=SURF, linewidth=0.4)
ax.axvline(best, color=ORANGE, linestyle="--", linewidth=1.4)
ax.text(best * 1.15, ax.get_ylim()[1] * 0.92, f"best single fit\n{best:,.0f} votes",
        color=ORANGE, fontsize=11, fontweight="bold", va="top")
style(ax, "BGG's adjusted score implies about 1,900 dummy votes for every game")
save(fig, "figures/P6/fig_bgg_m_only.png",
     f"Implied m solved per game from BGG's adjusted score, assuming votes at 5.5 "
     f"({len(bgg):,} games). A fitted approximation, not BGG's published algorithm.")

# -- comparison ----------------------------------------------------------------
fig, ax = plt.subplots(figsize=(9, 5), dpi=220)
fig.patch.set_facecolor(SURF)
ax.hist(ours, bins=bins, color=BLUE, alpha=0.9, edgecolor=SURF, linewidth=0.4,
        label="Our model (M1a Extended)")
ax.hist(bgg, bins=bins, color=ORANGE, alpha=0.9, edgecolor=SURF, linewidth=0.4,
        label="BGG (constant-m fit)")
med_ours, med_bgg = float(np.median(ours)), float(np.median(bgg))
for x, c in ((med_ours, BLUE), (med_bgg, ORANGE)):
    ax.axvline(x, color=c, linestyle="--", linewidth=1.4)
top = ax.get_ylim()[1]
ax.annotate("", xy=(med_bgg, top * 0.80), xytext=(med_ours, top * 0.80),
            arrowprops=dict(arrowstyle="<->", color=INK2, linewidth=1.2))
ax.text((med_ours * med_bgg) ** 0.5, top * 0.84,
        f"about {round(med_bgg / med_ours, -2):,.0f}× apart", color=INK, ha="center", fontsize=11,
        fontweight="bold")
ax.text(med_ours * 1.12, top * 0.66, f"median {med_ours:.1f}", color=BLUE, fontsize=10.5)
ax.text(med_bgg * 0.88, top * 0.66, f"median {med_bgg:,.0f}", color=ORANGE, fontsize=10.5,
        ha="right")
ax.legend(loc="center left", bbox_to_anchor=(0.36, 0.45), frameon=False, fontsize=9.5,
          labelcolor=INK2)
style(ax, "Pseudo-votes per game: our model versus BGG")
save(fig, "figures/P6/fig_pseudovotes_comparison.png",
     f"Ours: measured SD² / τ² per game, M1a Extended ({len(ours):,} games). "
     f"BGG: implied m per game, votes at 5.5 ({len(bgg):,} games).")
print(f"medians: ours {med_ours:.2f}, BGG {med_bgg:,.0f}")
