"""Build P6's own slides for the 1 Dec progress presentation.

Reads the figures and CSVs produced by 01_bgg_benchmark.R and
02_rank_uncertainty.R, so the slides always match the saved results.
Run from the repository root:

    python archive/code/P6/03_make_slides.py
"""

import csv
import os
import sys
from pathlib import Path

# Layout helpers remain with the current group-deck code.
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "code" / "P6"))

from pptx import Presentation
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches

from pptx_helpers import (INK, INK2, MUTED, W, H, blank, header, note,
                          picture, text)

FIG = "figures/P6"
OUT = "archive/slides/P6_slides.pptx"


def read_summary():
    d = {}
    for name in ("bgg_benchmark_summary.csv", "rank_vs_bgg_summary.csv"):
        with open(f"outputs/P6/{name}") as f:
            for row in csv.DictReader(f):
                d[row["quantity"]] = float(row["value"])
    return d


S = read_summary()
FOOT = "P6 · BGG benchmark and ranking uncertainty"

prs = Presentation()
prs.slide_width, prs.slide_height = W, H

# ----------------------------------------------------------------- slide 1 ---
s = blank(prs)
header(s, "What BGG's adjusted score is equivalent to",
       "A Bayesian average with a fixed number of dummy votes at 5.5", FOOT, "1/4")
picture(s, f"{FIG}/fig_bgg_pseudovotes.png", Inches(0.5), Inches(1.75),
        Inches(8.0), Inches(4.7))
text(s, Inches(8.85), Inches(1.9), Inches(4.0), Inches(4.5), [
    f"Equivalent to about {S['bgg_m_best_single_fit']:,.0f} dummy votes per game",
    "The implied count varies little across rating counts",
    f"One number reproduces the published score with RMSE {S['bgg_m_fit_rmse']:.3f}",
    "An equivalent count, not BGG's published algorithm",
], size=14.5)
note(s, "Method: invert bayes = (n*ybar + m*5.5)/(n + m) for each of 20,694 games. "
        "681 games are excluded because their published score is inconsistent with "
        "any positive m.")

# ----------------------------------------------------------------- slide 2 ---
s = blank(prs)
header(s, "The model implies a much smaller number",
       "Posterior of m = s²/τ² under M1a, and the effective count in the ranking model", FOOT, "2/4")
text(s, Inches(0.75), Inches(1.95), Inches(5.7), Inches(4.6), [
    f"Baseline: m = {S['model_m_mean']:.1f}",
    f"95% credible interval {S['model_m_lower95']:.1f} to {S['model_m_upper95']:.1f}",
    f"Ranking model: median effective m = {S['ranking_model_m_eff_median']:.1f}",
    f"BGG's equivalent count is {S['ratio_bgg_over_model']:.0f}× the Baseline",
], size=17, space_after=16)
text(s, Inches(6.7), Inches(1.95), Inches(6.0), Inches(4.6), [
    "s, one rater's SD around a game's true score, is only weakly identified from averages.",
    "In the M1a posterior s sits near the top of its prior, so m depends on that prior.",
    "Correct phrasing: the data are consistent with a small m under this model — not that they prove BGG's value is wrong.",
], size=14, colour=INK2, space_after=14)
note(s, "The ranking export uses the Extended model, which has a shrinkage target and "
        "a variance that both vary with n, so there is no single m. Its effective "
        "per-game count is computed draw by draw from sd_hist^2 / exp(2(a_tau+b_tau*x)).")

# ----------------------------------------------------------------- slide 3 ---
s = blank(prs)
header(s, "Ranking inside each of 500 joint draws",
       "21,375 games ranked within every posterior sample, so the ordering is internally consistent", FOOT, "3/4")
picture(s, f"{FIG}/fig_top10_probability.png", Inches(0.45), Inches(1.8),
        Inches(7.6), Inches(4.9))
text(s, Inches(8.35), Inches(1.95), Inches(4.5), Inches(4.6), [
    "Six games exceed a 50% chance of a top-ten place",
    f"{S['games_with_p_top10_above_005']:.0f} games have a P(top 10) above 5%",
    f"Median 90% rank interval: {S['median_90pct_rank_interval_width']:,.0f} ranks overall, "
    f"{S['median_90pct_width_top10_candidates']:.0f} for top-ten candidates",
    "Monte Carlo SE of a probability is at most 0.022 at 500 draws",
], size=13.5, space_after=13)
note(s, "41 structural checks pass: unique ids in the same order, finite draws, "
        "draw numbers 1-500, sums of P(top k) equal to 10/50/100.")

# ----------------------------------------------------------------- slide 4 ---
s = blank(prs)
header(s, "The two top tens share no games",
       "Agreement in the middle of the list, disagreement at the top", FOOT, "4/4")
picture(s, f"{FIG}/fig_rank_intervals.png", Inches(0.4), Inches(1.75),
        Inches(6.6), Inches(4.7))
text(s, Inches(7.35), Inches(1.9), Inches(5.4), Inches(4.7), [
    "Our top ten has a median of 46 ratings; BGG's has 25,535",
    f"Spearman across all games: {S['spearman_vs_bgg_adjusted']:.2f}",
    "The gap follows from the different shrinkage, but the shrinkage target and the variance structure differ too, so m is not the only factor",
    "These are latent ratings from M1a, not predictions from M1b",
], size=13.5, space_after=13)
note(s, "Scope: the 21,375 SD-matched games of the 2022 snapshot, not all of BGG.")

os.makedirs("slides", exist_ok=True)
prs.save(OUT)
print("saved", OUT, "with", len(prs.slides), "slides")
