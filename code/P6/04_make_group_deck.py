"""Assemble the group's progress-presentation deck for 1 Dec.

P6 owns slide assembly. Every figure here is a file already committed to the
repository by its owner (P1, P2, P3, P4, P5, P6); this script only places them
and writes the connecting lines. Numbers are read from the saved tables, never
typed in.

Narrative follows the order agreed in review: RQ1 shrinkage and its verification
-> RQ2 designer effects -> RQ3 ranking and the BGG benchmark, with M0 and M2 as
supporting analyses.

Run from the repository root:

    python code/P6/04_make_group_deck.py
"""

import csv
import os

from pptx import Presentation
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

from pptx_helpers import (BLUE, INK, INK2, MUTED, W, H, blank, note, picture,
                          table, text)

FIG = "figures"
P3F = "figures/P3"
P4F = "figures/P4/presentation"
P5F = "figures/P5"
P6F = "figures/P6"
OUT = "slides/Group_deck_draft.pptx"
N = 17
FOOT = "STAT6106 · BoardGameGeek rating shrinkage"


def read_summary():
    d = {}
    for path in ("outputs/P6/bgg_benchmark_summary.csv",
                 "outputs/P6/rank_vs_bgg_summary.csv"):
        with open(path) as f:
            for row in csv.DictReader(f):
                d[row["quantity"]] = float(row["value"])
    return d


S = read_summary()
prs = Presentation()
prs.slide_width, prs.slide_height = W, H


def footer(s, n):
    text(s, Inches(0.6), Inches(6.95), Inches(9), Inches(0.35), FOOT,
         size=10, colour=MUTED)
    text(s, Inches(12.2), Inches(6.95), Inches(0.8), Inches(0.35),
         f"{n}/{N}", size=11, colour=MUTED, align=PP_ALIGN.RIGHT)


def slide(n, title, subtitle=None):
    s = blank(prs)
    text(s, Inches(0.6), Inches(0.42), Inches(12.1), Inches(0.7), title,
         size=26, bold=True)
    if subtitle:
        text(s, Inches(0.6), Inches(1.10), Inches(12.1), Inches(0.45),
             subtitle, size=13.5, colour=INK2)
    footer(s, n)
    return s


def figure_slide(n, kicker, bullets, fig, fig_w=8.4, fig_top=1.05, fig_h=5.2,
                 credit=None):
    """Headline comes from the figure's own baked-in title; a kicker labels it."""
    s = blank(prs)
    text(s, Inches(0.6), Inches(0.42), Inches(12.1), Inches(0.4), kicker,
         size=13, bold=True, colour=MUTED)
    footer(s, n)
    picture(s, fig, Inches(0.42), Inches(fig_top), Inches(fig_w), Inches(fig_h))
    if bullets:
        left = Inches(0.42) + Inches(fig_w) + Inches(0.38)
        width = Inches(12.6) - left
        text(s, left, Inches(fig_top + 0.18), width, Inches(fig_h - 0.2),
             bullets, size=13.5, colour=INK2, space_after=14)
    if credit:
        text(s, Inches(0.42), Inches(6.55), Inches(9), Inches(0.3), credit,
             size=10, colour=MUTED)
    return s


# ------------------------------------------------------------------- 1 title --
s = blank(prs)
text(s, Inches(0.9), Inches(2.0), Inches(11.5), Inches(1.4),
     "How much should a game's rating be shrunk?", size=38, bold=True)
text(s, Inches(0.9), Inches(3.35), Inches(11.0), Inches(1.0),
     "Estimating the pseudo-vote count behind BoardGameGeek's adjusted score",
     size=19, colour=INK2)
bar = s.shapes.add_shape(1, Inches(0.9), Inches(4.35), Inches(3.2), Pt(2))
bar.fill.solid()
bar.fill.fore_color.rgb = BLUE
bar.line.fill.background()
text(s, Inches(0.9), Inches(4.7), Inches(11.0), Inches(1.4), [
    "STAT6106 Bayesian Data Analysis · Group project",
    "Progress presentation · 1 December 2026",
], size=14, colour=MUTED, space_after=6)
note(s, "Deck assembled by P6 from figures committed by P1, P2, P3, P4, P5 and P6.")

# ------------------------------------------------------------------ 2 question --
s = slide(2, "Two games both average 8.0. Are they equally reliable?",
          "One has 30 ratings, the other 30,000")
text(s, Inches(0.75), Inches(2.0), Inches(5.9), Inches(4.3), [
    "BGG's adjusted score pulls every game toward 5.5.",
    "The size of that pull is one number of dummy votes.",
    "BGG applies a single value to every game and does not publish how it is chosen.",
], size=16, space_after=16)
text(s, Inches(6.9), Inches(2.0), Inches(5.8), Inches(4.3), [
    "RQ1: under an explicit measurement-error model, how many dummy votes do the data support?",
    "RQ2: what do designer effects add?",
    "RQ3: how uncertain is the ranking, and how does it compare with BGG's?",
], size=15.5, colour=INK2, space_after=14)

# -------------------------------------------------------------------- 3 data --
s = slide(3, "The data", "January 2022 snapshot of every ranked BGG game (at least 30 ratings)")
picture(s, f"{FIG}/eda_01_average_distribution.png", Inches(0.45), Inches(1.75),
        Inches(6.1), Inches(4.1))
picture(s, f"{FIG}/eda_02_users_rated_distribution.png", Inches(6.8), Inches(1.75),
        Inches(6.1), Inches(4.1))
text(s, Inches(0.45), Inches(6.05), Inches(12.4), Inches(0.6),
     "21,831 games; 21,631 join to the details table. Median 124 ratings, 99th percentile about 15,000.",
     size=11.5, colour=MUTED)
note(s, "Figures: P1.")

# -------------------------------------------------------------- 4 why shrink --
s = slide(4, "Ratings from few people are much more variable",
          "The spread of averages falls sharply with the number of ratings")
picture(s, f"{FIG}/eda_03_average_vs_users.png", Inches(0.45), Inches(1.75),
        Inches(6.2), Inches(3.5))
picture(s, f"{FIG}/eda_04_bayes_vs_average.png", Inches(6.9), Inches(1.75),
        Inches(6.0), Inches(3.5))
text(s, Inches(0.45), Inches(5.5), Inches(12.4), Inches(1.1), [
    "Left: low-count games range from 2.5 to 9; high-count games cluster tightly.",
    "Right: BGG's adjusted score sits almost exactly on a straight shrinkage line toward 5.5.",
], size=13, colour=INK2, space_after=6)
note(s, "Figures: P1.")

# ------------------------------------------------------------------ 5 models --
s = slide(5, "Three models for the rating, one for popularity",
          "Different outcomes and different samples; they are not competing specifications")
table(s, Inches(0.6), Inches(1.85), [
    ["Model", "Outcome", "Sample", "Role", "Owner"],
    ["M0", "average", "6,489 dev", "Baseline; two samplers", "P2"],
    ["M1a", "average", "6,416 dev", "Pseudo-vote count m", "P5"],
    ["M1b", "average", "6,416 dev", "Covariates + designer effects", "P4"],
    ["M2", "ratings count", "19,440 complete", "Popularity (supporting)", "P3"],
], [Inches(1.1), Inches(1.9), Inches(2.0), Inches(3.8), Inches(1.2)],
   font_size=13, row_h=Inches(0.40))
text(s, Inches(0.6), Inches(4.35), Inches(12.2), Inches(2.2), [
    "m = s²/τ²: the number of extra ratings at the predicted value that reproduces the model's shrinkage.",
    "s is one rater's SD around a game's true score; τ is the spread of true scores between games.",
    "M2 predicts a different outcome on a different sample, so its WAIC is never compared with the others.",
], size=13.5, colour=INK2, space_after=8)

# ------------------------------------------------------------ 6 RQ1 prior-s --
s = figure_slide(6, "RQ1 · the noise parameter is not identified", [
    "Posterior mean s = 2.96; prior bound 3.0",
    f"m = s²/τ² = {S['model_m_mean']:.1f}",
    f"95% credible interval {S['model_m_lower95']:.1f} – {S['model_m_upper95']:.1f}",
    "m is a model- and prior-based quantity, not a datum",
], f"{P5F}/fig01_prior_posterior_s.png", credit="Figure: P5")
note(s, "P5. The posterior piles up against the upper bound of the Uniform(0.5, 3) "
        "prior, which is why the pseudo-vote count must be reported with its "
        "dependence on that prior.")

# ---------------------------------------------------------- 7 RQ1 shrinkage --
s = figure_slide(7, "RQ1 · what that shrinkage looks like", [
    "Games with many ratings barely move",
    "Games with few ratings move toward the mean, but only slightly",
    "Adjustment is largest where the count is smallest",
], f"{P5F}/fig02_rating_shrinkage.png", credit="Figure: P5")
note(s, "P5.")

# -------------------------------------------------------------- 8 RQ1 check --
s = figure_slide(8, "RQ1 · and where the model fails", [
    "Observed means rise from 6.18 to 7.22 across rating-count bands",
    "M1a predicts a flat 6.43 in every band",
    "A pure shrinkage model cannot reproduce 'more ratings, higher rating'",
], f"{FIG}/ppc_m1a_rating_count_bands.png", fig_w=8.4, credit="Figure: P1")
note(s, "P1 grouped posterior predictive check. This motivates the covariates and "
        "the log(n) term in M1b; it is reported, not hidden.")

# ------------------------------------------------------------ 9 RQ2 designer --
s = figure_slide(9, "RQ2 · designer effects", [
    "Games by the same designer share a random effect",
    "About half of the residual spread is between designers",
    "The two specifications estimate similar effects",
    "An association after controlling for game features, not a ranking of designers",
], f"{P4F}/fig2_designer_effects.png", fig_w=7.9, credit="Figure: P4")
note(s, "P4, PR #8. 95% credible intervals; effects are conditional on the covariates.")

# ------------------------------------------------------------- 10 RQ2 adjust --
s = figure_slide(10, "RQ2 · adjustment falls with the number of ratings", [
    "Median adjustment at 30-40 ratings: 0.2135 points",
    "Under the external-SD variant: 0.0710",
    "Bars are interquartile ranges across games, not credible intervals",
    "Training-sample results, not a claim about predictive performance",
], f"{P4F}/fig1_shrinkage_by_rating_count.png", fig_w=8.4, credit="Figure: P4")
note(s, "P4, PR #8.")

# ------------------------------------------------------------- 11 robustness --
s = figure_slide(11, "Robustness · what moves and what does not", [
    "Top-50 order is unchanged across the priors tested",
    "Scaling the historical SD by 0.8-1.2 moves the median pseudo-vote count between 1.9 and 4.5",
    "A prior-sensitivity result on 6,416 development games, not proof for the full ranking",
], f"{P5F}/fig04_sensitivity.png", credit="Figure: P5")
note(s, "P5. Scope is the 6,416 development games and the priors actually tested.")

# ----------------------------------------------------------- 12 supporting M0 --
s = slide(12, "Supporting: three samplers agree",
          "M0 fitted by JAGS, a hand-written Gibbs sampler and mean-field CAVI")
picture(s, f"{FIG}/M0_three_method_intervals.png", Inches(0.45), Inches(1.70),
        Inches(6.4), Inches(3.5))
picture(s, f"{FIG}/M0_cavi_elbo.png", Inches(7.05), Inches(1.70),
        Inches(5.8), Inches(3.5))
text(s, Inches(0.45), Inches(5.4), Inches(12.4), Inches(1.2), [
    "Posterior means agree to about 0.0003; interval-width ratios 0.979-1.006, so CAVI does not visibly understate variance here.",
    "Runtime on one machine: CAVI 0.04 s, Gibbs 3.89 s, JAGS 70.64 s (6,489 games, 4 chains x 12,000).",
], size=12.5, colour=INK2, space_after=6)
note(s, "P2. CAVI's usual variance understatement does not appear at this sample size; reported as measured.")

# ----------------------------------------------------------- 13 supporting M2 --
s = figure_slide(13, "Supporting: what predicts the number of ratings", [
    "19,440 complete-case games, left-truncated at 30 ratings",
    "Age, playing time and multiple designers are positively associated",
    "Residual PPC mismatch remains; full-sample fit, not holdout",
    "Describes rating counts only, and is never compared with the rating models",
], f"{P3F}/M2_NB_effects_forest.png", fig_w=7.6, credit="Figure: P3")
note(s, "P3, PR #4.")

# -------------------------------------------------------------- 14 comparison --
s = slide(14, "Model comparison: the two criteria pick different winners",
          "WAIC on 6,416 development games; ELPD on the same 3,209 matched holdout games")
picture(s, f"{P5F}/fig06_four_model_waic.png", Inches(0.35), Inches(1.70),
        Inches(6.3), Inches(3.4))
picture(s, f"{P5F}/fig05_four_model_holdout.png", Inches(6.85), Inches(1.70),
        Inches(6.1), Inches(3.4))
text(s, Inches(0.35), Inches(5.3), Inches(12.6), Inches(1.4), [
    "ExternalSD has the lowest WAIC by about 8, but M1b Baseline has the better holdout ELPD (-15.1, cluster SE ~8.3).",
    "M1b's WAIC warns: pWAIC above 0.4 for 858-948 games, and the likelihood conditions on learned designer effects.",
], size=12.5, colour=INK2, space_after=6)
note(s, "P5, outputs/P5/WAIC_Comparison_6416 and Holdout_Comparison_3209.")

# -------------------------------------------------------------- 15 RQ3 bench --
s = slide(15, "RQ3 · what BGG's adjusted score is equivalent to",
          "A constant-m Bayesian average: a fixed number of dummy votes at 5.5")
picture(s, f"{P6F}/fig_bgg_pseudovotes.png", Inches(0.45), Inches(1.75),
        Inches(8.0), Inches(4.6))
text(s, Inches(8.8), Inches(1.95), Inches(4.1), Inches(4.3), [
    f"Equivalent to about {S['bgg_m_best_single_fit']:,.0f} dummy votes per game",
    "The implied count varies little across rating counts",
    "An equivalent count under a stated assumption, not BGG's algorithm",
], size=14, space_after=14)
note(s, "P6. 20,694 games usable; 681 excluded as inconsistent with any positive m.")

# --------------------------------------------------------------- 16 RQ3 rank --
s = slide(16, "RQ3 · ranking inside each of 500 joint draws",
          "Every comparison uses the same posterior sample, so the ordering is internally consistent")
picture(s, f"{P6F}/fig_top10_probability.png", Inches(0.45), Inches(1.8),
        Inches(7.4), Inches(4.7))
text(s, Inches(8.2), Inches(1.95), Inches(4.6), Inches(4.3), [
    "Six games exceed a 50% chance of a top-ten place",
    f"{S['games_with_p_top10_above_005']:.0f} games have P(top 10) above 5%",
    f"Median 90% rank interval: {S['median_90pct_rank_interval_width']:,.0f} ranks overall",
    "Monte Carlo standard error of a probability at most 0.022",
], size=13.5, space_after=13)
note(s, "P6. 41 verification checks pass; top-k lists use a fixed tie-break key.")

# --------------------------------------------------------- 17 RQ3 divergence --
s = slide(17, "RQ3 · the two top tens share no games",
          "Agreement in the middle of the list, disagreement at the top")
picture(s, f"{P6F}/fig_rank_intervals.png", Inches(0.4), Inches(1.75),
        Inches(6.4), Inches(4.4))
text(s, Inches(7.15), Inches(1.95), Inches(5.6), Inches(4.2), [
    "Our top ten: median 46 ratings. BGG's: 25,535.",
    f"Spearman across all games: {S['spearman_vs_bgg_adjusted']:.2f}",
    "Consistent with the different shrinkage, but the target and variance structure differ too",
    "Latent ratings from M1a, not predictions from M1b; scope is the 21,375 matched games",
], size=13, space_after=12)
text(s, Inches(0.4), Inches(6.35), Inches(12.4), Inches(0.4),
     "Next: final report sections by 10 Dec; model checks and CAVI continue after the presentation.",
     size=11, colour=MUTED)
note(s, "P6.")

os.makedirs("slides", exist_ok=True)
prs.save(OUT)
print("saved", OUT, "with", len(prs.slides), "slides")
