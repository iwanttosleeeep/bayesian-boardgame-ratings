"""Assemble the group's progress-presentation deck for 1 Dec.

P6 owns slide assembly. Figures come from figures/ (P1, P2, P3, P6); slides for
P4 and P5 use the numbers they published in outputs/ and docs/, because neither
workstream has committed presentation figures yet. Each such slide says so in
its speaker notes.

Run from the repository root:

    python code/P6/04_make_group_deck.py
"""

import os

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt

from pptx_helpers import (BLUE, INK, INK2, MUTED, ORANGE, RULE, SURF, W, H,
                          blank, header, note, picture, table, text)

FIG = "figures"
P3F = "figures/P3"
P6F = "figures/P6"
OUT = "slides/Group_deck_draft.pptx"

FOOT = "STAT6106 · BoardGameGeek rating shrinkage"


def title_slide(prs):
    s = blank(prs)
    text(s, Inches(0.9), Inches(2.0), Inches(11.5), Inches(1.4),
         "How much should a game's rating be shrunk?", size=38, bold=True)
    text(s, Inches(0.9), Inches(3.35), Inches(11.0), Inches(1.0),
         "Estimating the pseudo-vote count behind BoardGameGeek's adjusted score",
         size=19, colour=INK2)
    line = s.shapes.add_shape(1, Inches(0.9), Inches(4.35), Inches(3.2), Pt(2))
    line.fill.solid()
    line.fill.fore_color.rgb = BLUE
    line.line.fill.background()
    text(s, Inches(0.9), Inches(4.7), Inches(11.0), Inches(1.4), [
        "STAT6106 Bayesian Data Analysis · Group project",
        "Progress presentation · 1 December 2026",
    ], size=14, colour=MUTED, space_after=6)
    note(s, "Deck assembled by P6 from the owners' published outputs. "
            "Numbers on every slide are taken from files in this repository.")


def section_title(prs, kicker, title, body):
    s = blank(prs)
    text(s, Inches(0.9), Inches(2.6), Inches(11.5), Inches(0.5), kicker,
         size=13, colour=MUTED)
    text(s, Inches(0.9), Inches(3.0), Inches(11.5), Inches(1.2), title,
         size=34, bold=True)
    text(s, Inches(0.9), Inches(4.2), Inches(10.5), Inches(1.6), body,
         size=16, colour=INK2)


prs = Presentation()
prs.slide_width, prs.slide_height = W, H

# ------------------------------------------------------------------ 1 title ---
title_slide(prs)

# ----------------------------------------------------------------- 2 question ---
s = blank(prs)
header(s, "Two games both average 8.0. Are they equally reliable?",
       "One has 30 ratings, the other 30,000", FOOT, "2/15")
text(s, Inches(0.75), Inches(2.0), Inches(5.9), Inches(4.4), [
    "BoardGameGeek publishes an adjusted score that pulls every game toward 5.5.",
    "The size of that pull is a single number of dummy votes.",
    "BGG uses one fixed value for every game — but nobody publishes how it is chosen.",
], size=16, space_after=16)
text(s, Inches(6.9), Inches(2.0), Inches(5.8), Inches(4.4), [
    "Our question: under an explicit measurement-error model, how many dummy votes do the data actually justify?",
    "And once we have that number, what does it do to the ranking?",
], size=16, colour=INK2, space_after=16)

# -------------------------------------------------------------------- 3 data ---
s = blank(prs)
header(s, "The data", "January 2022 snapshot of every ranked BGG game (at least 30 ratings)", FOOT, "3/15")
picture(s, f"{FIG}/eda_01_average_distribution.png", Inches(0.45), Inches(1.85),
        Inches(6.1), Inches(4.2))
picture(s, f"{FIG}/eda_02_users_rated_distribution.png", Inches(6.8), Inches(1.85),
        Inches(6.1), Inches(4.2))
text(s, Inches(0.45), Inches(6.15), Inches(12.4), Inches(0.6),
     "21,831 games in ratings.csv; 21,631 join to details.csv. Median 124 ratings, 99th percentile about 15,000.",
     size=11.5, colour=MUTED)
note(s, "Figures from P1 (outputs committed 23 Nov).")

# ---------------------------------------------------------------- 4 why shrink ---
s = blank(prs)
header(s, "Ratings from few raters are much more variable",
       "The spread of averages shrinks sharply with the number of ratings", FOOT, "4/15")
picture(s, f"{FIG}/eda_03_average_vs_users.png", Inches(0.45), Inches(1.85),
        Inches(6.2), Inches(3.6))
picture(s, f"{FIG}/eda_04_bayes_vs_average.png", Inches(6.9), Inches(1.85),
        Inches(6.0), Inches(3.6))
text(s, Inches(0.45), Inches(5.65), Inches(12.4), Inches(1.1), [
    "Left: low-count games spread from 2.5 to 9; high-count games cluster tightly.",
    "Right: BGG's adjusted score lies almost exactly on a straight shrinkage line toward 5.5.",
], size=13, colour=INK2, space_after=6)

# ----------------------------------------------------------------- 5 models ---
s = blank(prs)
header(s, "Four models, one shared data contract",
       "Each answers a different question; they are not competing specifications", FOOT, "5/15")
table(s, Inches(0.6), Inches(1.9), [
    ["Model", "Outcome", "Structure", "Question", "Owner"],
    ["M0", "average", "Normal regression", "Baseline; two samplers", "P2"],
    ["M1a", "average", "Measurement error, intercept only", "Pseudo-vote count m", "P5"],
    ["M1b", "average", "Measurement error + covariates + designer effects", "Shrinkage and designer share", "P4"],
    ["M2", "users_rated", "Poisson vs truncated negative binomial", "What predicts rating count", "P3"],
], [Inches(1.1), Inches(1.7), Inches(4.6), Inches(3.5), Inches(1.2)])
text(s, Inches(0.6), Inches(4.4), Inches(12.2), Inches(2.0), [
    "Key quantity: m = s²/τ², the number of extra ratings at the predicted value that reproduces the model's shrinkage.",
    "s is one rater's SD around a game's true score. τ is the spread of true scores between games.",
    "The data contain averages only, so s is weakly identified — which makes m a model quantity with a posterior, not a constant.",
], size=13.5, colour=INK2, space_after=8)

# --------------------------------------------------------------------- 6 M0 ---
s = blank(prs)
header(s, "M0: the two samplers agree",
       "JAGS and a hand-written Gibbs sampler fitted to the same 6,489 development games", FOOT, "6/15")
picture(s, f"{FIG}/M0_trace_gibbs.png", Inches(0.5), Inches(1.85), Inches(7.4), Inches(4.5))
text(s, Inches(8.3), Inches(2.0), Inches(4.3), Inches(4.2), [
    "Posterior means differ by about 0.0001",
    "R-hat ≈ 1.00, ESS ≈ 7,600",
    "Both chains converge, so the hand-written sampler is safe to build on",
], size=15, space_after=16)
note(s, "P2. Figure committed at figures/M0_trace_gibbs.png.")

# --------------------------------------------------------------------- 7 M2 ---
s = blank(prs)
header(s, "M2: the number of ratings",
       "Negative binomial beats Poisson, but both still misfit the tails", FOOT, "7/15")
picture(s, f"{P3F}/M2_NB_effects_forest.png", Inches(0.4), Inches(1.8),
        Inches(7.2), Inches(4.7))
text(s, Inches(7.9), Inches(1.95), Inches(4.8), Inches(4.4), [
    "19,440 complete-case games, left-truncated at 30 ratings",
    "Game age, playing time and multiple designers are positively associated with rating count",
    "Residual PPC mismatch remains, and this is a full-sample fit, not a holdout result",
], size=14, space_after=14)
note(s, "P3. Effects shown as rate ratios from the truncated negative binomial.")

# -------------------------------------------------------------------- 8 M1a ---
s = blank(prs)
header(s, "M1a: the data justify very little shrinkage",
       "Posterior of the pseudo-vote count, 6,416 development games", FOOT, "8/15")
table(s, Inches(0.7), Inches(2.0), [
    ["Quantity", "Posterior", "95% interval"],
    ["alpha (mean rating)", "6.43", "6.41 – 6.45"],
    ["s (one rater's SD)", "2.96", "2.86 – 3.00"],
    ["tau (true-score spread)", "0.87", "0.85 – 0.89"],
    ["m = s²/τ²", "11.6", "10.7 – 12.3"],
], [Inches(3.4), Inches(2.2), Inches(2.2)], font_size=14, row_h=Inches(0.42))
text(s, Inches(8.5), Inches(2.0), Inches(4.2), Inches(4.4), [
    "s sits at the top of its prior: the data barely inform it.",
    "So m is small, and it is prior-dependent — that is the finding, not a nuisance.",
], size=14.5, colour=INK2, space_after=14)
note(s, "P5, outputs/P5/M1a_Baseline/parameter_summary.csv. "
        "A figure of the s posterior against its prior would strengthen this slide.")

# ------------------------------------------------------------ 9 sensitivity ---
s = blank(prs)
header(s, "The ranking does not move when these priors move",
       "Top-50 overlap on the 6,416 development games under each prior variant tested", FOOT, "9/15")
table(s, Inches(0.7), Inches(1.95), [
    ["Prior scenario", "Median adjustment", "Median pseudo-votes", "Top-50 overlap"],
    ["baseline", "0.0095", "3.06", "50 / 50"],
    ["τ tighter", "0.0095", "3.06", "50 / 50"],
    ["τ wider", "0.0095", "3.06", "50 / 50"],
    ["γ tighter", "0.0095", "3.06", "50 / 50"],
    ["γ wider", "0.0095", "3.06", "50 / 50"],
], [Inches(3.2), Inches(2.8), Inches(2.9), Inches(2.6)], font_size=13.5,
   row_h=Inches(0.40))
text(s, Inches(0.7), Inches(5.35), Inches(12.0), Inches(1.3), [
    "Scaling the historical SD by 0.8 to 1.2 moves the median pseudo-vote count only between 1.9 and 4.5.",
    "This is a prior-sensitivity check on the development games, not evidence that the full 21,375-game ranking is robust to everything.",
], size=13.5, colour=INK2, space_after=8)
note(s, "P5, outputs/P5/Sensitivity_Analysis/Priors/prior_sensitivity_summary.csv "
        "and .../External_SD/SD_sensitivity_summary.csv.")

# -------------------------------------------------------------------- 10 M1b ---
s = blank(prs)
header(s, "M1b: about half the residual spread is between designers",
       "Measurement-error model with covariates and a designer random effect, 6,416 games", FOOT, "10/15")
table(s, Inches(0.7), Inches(2.0), [
    ["Quantity", "M1b", "M1b with external SD"],
    ["τ (true-score spread)", "0.4175", "0.4732"],
    ["σ_d (designer SD)", "0.4331", "0.4645"],
    ["Designer share σ_d²/(σ_d²+τ²)", "about 52%", "about 49%"],
    ["Median adjustment, 30–40 ratings", "0.2135", "0.0710"],
], [Inches(5.0), Inches(2.3), Inches(3.0)], font_size=13.5, row_h=Inches(0.40))
text(s, Inches(0.7), Inches(4.75), Inches(12.0), Inches(1.9), [
    "Games by the same designer share a random effect, so roughly half of the remaining between-game spread is between designers.",
    "Swapping in each game's historical SD gives the lowest WAIC but not the better holdout ELPD; we do not claim either version is better overall.",
], size=13.5, colour=INK2, space_after=10)
note(s, "P4, docs/P4_EXTERNALSD.md and the PR #5 summary. "
        "A shrinkage plot (adjusted vs raw rating by rating count) would replace this table.")

# ------------------------------------------------------------- 11 comparison ---
s = blank(prs)
header(s, "Model comparison: the criteria do not agree",
       "WAIC on 6,416 development games; ELPD on the same 3,209 matched holdout games", FOOT, "11/15")
table(s, Inches(0.7), Inches(1.95), [
    ["Model", "Development WAIC", "Holdout ELPD"],
    ["M1a Baseline", "17,222.0", "−4,347.8"],
    ["M1a Extended", "16,509.0", "−4,126.1"],
    ["M1b Baseline", "11,766.7", "−3,009.6"],
    ["M1b ExternalSD", "11,758.5", "−3,024.7"],
], [Inches(3.6), Inches(3.2), Inches(3.0)], font_size=13.5, row_h=Inches(0.40))
text(s, Inches(0.7), Inches(4.45), Inches(12.2), Inches(2.2), [
    "Lower WAIC is better; higher (less negative) ELPD is better.",
    "They disagree at the top: ExternalSD has the lowest WAIC by about 8, while M1b Baseline has the better holdout ELPD (−15.1, cluster SE ≈ 8.3).",
    "M1b's WAIC also warns: pWAIC exceeds 0.4 for 858–948 games, and the likelihood conditions on learned designer effects.",
], size=12.5, colour=INK2, space_after=8)
note(s, "P5, outputs/P5/WAIC_Comparison_6416 and outputs/P5/Holdout_Comparison_3209. "
        "A separate three-model comparison on 6,489 games gives M1b 11,939 / M0 14,399 / "
        "M1a 17,496; it uses different games and is not mixed into this table.")

# ------------------------------------------------------------ 12 BGG benchmark ---
s = blank(prs)
header(s, "What BGG's adjusted score is equivalent to",
       "A constant-m Bayesian average: a fixed number of dummy votes at 5.5", FOOT, "12/15")
picture(s, f"{P6F}/fig_bgg_pseudovotes.png", Inches(0.45), Inches(1.75),
        Inches(8.1), Inches(4.8))
text(s, Inches(8.85), Inches(1.95), Inches(4.0), Inches(4.4), [
    "Equivalent to about 1,874 dummy votes per game",
    "The implied count varies little across rating counts",
    "One number reproduces the published score; RMSE 0.020",
    "An equivalent count, not BGG's published algorithm",
], size=14.5, space_after=14)
note(s, "P6. Method: invert bayes = (n·ybar + m·5.5)/(n + m) for every game.")

# ------------------------------------------------------- 13 ranking uncertainty ---
s = blank(prs)
header(s, "Ranking 21,375 games inside each of 500 joint draws",
       "Every comparison uses the same posterior sample, so the ordering is internally consistent", FOOT, "13/15")
picture(s, f"{P6F}/fig_top10_probability.png", Inches(0.45), Inches(1.8),
        Inches(7.5), Inches(4.8))
text(s, Inches(8.3), Inches(1.95), Inches(4.4), Inches(4.4), [
    "Six games exceed a 50% chance of a top-ten place",
    "28 games have a P(top 10) above 5%",
    "Median 90% rank interval: 2,576 ranks overall, 71 for top-ten candidates",
], size=14, space_after=14)
note(s, "P6. Intervals widen quickly below the very top of the list.")

# --------------------------------------------------------- 14 disagreement ---
s = blank(prs)
header(s, "The two top tens share no games",
       "Agreement in the middle of the list, complete disagreement at the top", FOOT, "14/15")
table(s, Inches(0.55), Inches(1.9), [
    ["", "Our ranking", "BGG adjusted"],
    ["Median rating count", "46", "25,535"],
    ["Median raw average", "9.27", "8.55"],
    ["Top-10 overlap", "0 / 10", "—"],
    ["Spearman, all games", "0.78", "—"],
], [Inches(2.6), Inches(1.9), Inches(1.9)], font_size=13, row_h=Inches(0.38))
text(s, Inches(0.55), Inches(4.6), Inches(6.3), Inches(1.9), [
    "Because our shrinkage is small, a game with 43 ratings and a 9.56 average keeps almost all of it.",
    "BGG's rule pulls that game back toward 5.5, which is why the familiar titles lead its list.",
], size=13, colour=INK2, space_after=8)
picture(s, f"{P6F}/fig_rank_intervals.png", Inches(7.0), Inches(1.8),
        Inches(5.9), Inches(4.7))
note(s, "P6. The disagreement is the consequence of the pseudo-vote choice, not noise.")

# ------------------------------------------------------------- 15 closing ---
s = blank(prs)
header(s, "What we have shown, and what is left",
       "", FOOT, "15/15")
text(s, Inches(0.75), Inches(1.8), Inches(5.9), Inches(3.9), [
    "Shown",
    "•  BGG's adjusted score is equivalent to about 1,874 dummy votes",
    "•  Under our model the implied count is about 3 to 12",
    "•  The ranking is stable to the priors we tested, but not to a BGG-scale belief about s",
], size=14.5, space_after=12)
text(s, Inches(6.9), Inches(1.8), Inches(5.8), Inches(3.9), [
    "Still to do",
    "•  Grouped posterior predictive checks for M0 and M1",
    "•  CAVI comparison for M0",
    "•  Final report sections and full-draft integration",
], size=14.5, colour=INK2, space_after=12)
text(s, Inches(0.75), Inches(6.05), Inches(12.0), Inches(0.6),
     "All results describe ranked BGG games in a 2022 snapshot. None of them are causal.",
     size=12, colour=MUTED)

os.makedirs("slides", exist_ok=True)
prs.save(OUT)
print("saved", OUT, "with", len(prs.slides), "slides")
