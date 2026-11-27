"""Assemble the group's progress-presentation deck for 1 Dec (12 minutes).

Every figure is a file already committed to the repository by its owner; this
script only places them and writes the connecting lines. Numbers are read from
the saved tables, never typed in.

Structure follows the storyline in the README (five acts), split by speaker so
that each of the six members presents once, in order:

    P1 (2 min)   Act I    the ranking problem
    P2 (1.5 min) Act II   M0 and why a measurement-error model is needed
    P5 (3 min)   Act II-III  weak identification, measured SDs, what prediction can't decide
    P4 (2 min)   Act IV   M1b: designer effects and covariates
    P3 (1.5 min) Act IV   M2: what drives the number of ratings
    P6 (2 min)   Act V    rankings and conclusion

Backup slides follow the conclusion. Run from the repository root:

    python code/P6/04_make_group_deck.py
"""

import csv
import os
import statistics

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
N = 15  # main slides; backups are numbered B1, B2, ...
FOOT = "STAT6106 · BoardGameGeek rating shrinkage"


# ------------------------------------------------------------------ numbers --
def rows(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def keyed(path, key="quantity", value="value"):
    return {r[key]: float(r[value]) for r in rows(path)}


S = keyed("outputs/P6/bgg_benchmark_summary.csv")
S.update(keyed("outputs/P6/rank_vs_bgg_summary.csv"))

ppc = {r["group"]: r for r in rows("tables/ppc_grouped_summary.csv")
       if r["model"] == "M0" and r["grouping"] == "rating_count"}
MEAN_LO, MEAN_HI = float(ppc["30-40"]["observed_mean"]), float(ppc["5000+"]["observed_mean"])
VAR_LO, VAR_HI = float(ppc["30-40"]["observed_variance"]), float(ppc["5000+"]["observed_variance"])

M0_GAP = max(float(r["max_mean_gap"]) for r in rows("tables/M0_three_method_comparison.csv"))

p4s = {r["parameter"]: r for r in rows("outputs/P4/s_prior_comparison/parameter_comparison.csv")}
M1B_S, M1B_S6 = float(p4s["s"]["mean_baseline"]), float(p4s["s"]["mean_upper6"])
p4g = {r["group"]: r for r in rows("outputs/P4/s_prior_comparison/grouped_shrinkage.csv")}
ADJ_RISE = (float(p4g["all"]["upper6_median_abs_adjustment"])
            / float(p4g["all"]["baseline_median_abs_adjustment"]) - 1) * 100

SD_MED = statistics.median(float(r["sd_hist"]) for r in
                           rows("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"))
M1A_S = float({r["parameter"]: r for r in
               rows("outputs/P5/M1a_Baseline/parameter_summary.csv")}["s"]["posterior_mean"])
band = rows("outputs/P6/ranking_model_effective_m_by_band.csv")
M_BAND_LO, M_BAND_HI = float(band[0]["median_m_eff"]), float(band[-1]["median_m_eff"])
sens = {r["sd_factor"]: float(r["median_effective_pseudo_votes"]) for r in
        rows("outputs/P5/Sensitivity_Analysis/External_SD/SD_sensitivity_summary.csv")}

hold = {(r["model_A"], r["model_B"]): r for r in
        rows("outputs/P5/Holdout_Comparison_3209/holdout_pairwise_differences.csv")}
EXT_BASE = hold[("M1a_Extended", "M1a_Baseline")]
M1B_SD = hold[("M1b_ExternalSD", "M1b_Baseline")]
M1B_M1A = hold[("M1b_ExternalSD", "M1a_Extended")]

shr = {r["group"]: r for r in rows("outputs/P4/ExternalSD_6416/comparison/grouped_shrinkage.csv")}
ADJ_BASE_3040 = float(shr["n30_40"]["baseline_median_abs_adjustment"])
ADJ_EXT_3040 = float(shr["n30_40"]["external_median_abs_adjustment"])

scales = {r["parameter"]: r for r in rows("outputs/P4/ExternalSD_6416/comparison/scales.csv")}
SIG_D, TAU = float(scales["sigma_d"]["mean_external"]), float(scales["tau"]["mean_external"])
terms = [r["term"] for r in rows("outputs/P4/ExternalSD_6416/external_sd/design_columns.csv")]
coef = {terms[int(r["parameter"][5:-1]) - 1]: float(r["mean_external"])
        for r in rows("outputs/P4/ExternalSD_6416/comparison/coefficients.csv")
        if r["parameter"].startswith("beta[")}

rr = {r["term"]: float(r["rr_median"]) for r in rows("tables/P3/M2_NB_effects.csv")}

ranks = rows("outputs/P6/rank_uncertainty_all_games.csv")
OUR_TOP_N = statistics.median(float(r["n_2022"]) for r in ranks if int(r["rank_model"]) <= 10)
BGG_TOP_N = statistics.median(float(r["n_2022"]) for r in ranks
                              if int(r["rank_bgg_adjusted"]) <= 10)
P_TOP10_HALF = sum(float(r["p_top_10"]) > 0.5 for r in ranks)

# ------------------------------------------------------------------- layout --
prs = Presentation()
prs.slide_width, prs.slide_height = W, H


def footer(s, label, speaker=None):
    text(s, Inches(0.6), Inches(6.95), Inches(9), Inches(0.35), FOOT,
         size=10, colour=MUTED)
    text(s, Inches(12.0), Inches(6.95), Inches(1.0), Inches(0.35),
         label, size=11, colour=MUTED, align=PP_ALIGN.RIGHT)
    if speaker:
        text(s, Inches(10.4), Inches(0.42), Inches(2.6), Inches(0.35),
             speaker, size=11, bold=True, colour=BLUE, align=PP_ALIGN.RIGHT)


def slide(n, title, subtitle=None, speaker=None):
    s = blank(prs)
    text(s, Inches(0.6), Inches(0.42), Inches(10.0), Inches(0.7), title,
         size=26, bold=True)
    if subtitle:
        text(s, Inches(0.6), Inches(1.10), Inches(12.1), Inches(0.45),
             subtitle, size=13.5, colour=INK2)
    footer(s, n if isinstance(n, str) else f"{n}/{N}", speaker)
    return s


def figure_slide(n, title, bullets, fig, speaker=None, fig_w=8.2, fig_top=1.3,
                 fig_h=5.1, credit=None, size=14):
    s = slide(n, title, speaker=speaker)
    picture(s, fig, Inches(0.42), Inches(fig_top), Inches(fig_w), Inches(fig_h))
    left = Inches(0.42) + Inches(fig_w) + Inches(0.35)
    text(s, left, Inches(fig_top + 0.15), Inches(12.75) - left, Inches(fig_h - 0.2),
         bullets, size=size, colour=INK2, space_after=13)
    if credit:
        text(s, Inches(0.42), Inches(6.55), Inches(9), Inches(0.3), credit,
             size=10, colour=MUTED)
    return s


# ================================================================ 1 title ====
s = blank(prs)
text(s, Inches(0.9), Inches(2.0), Inches(11.5), Inches(1.4),
     "How much should a game's rating be shrunk?", size=38, bold=True)
text(s, Inches(0.9), Inches(3.35), Inches(11.0), Inches(1.0),
     "Separating rater noise from real differences between BoardGameGeek games",
     size=19, colour=INK2)
bar = s.shapes.add_shape(1, Inches(0.9), Inches(4.35), Inches(3.2), Pt(2))
bar.fill.solid()
bar.fill.fore_color.rgb = BLUE
bar.line.fill.background()
text(s, Inches(0.9), Inches(4.7), Inches(11.0), Inches(1.4), [
    "STAT6106 Bayesian Data Analysis · Group project",
    "Progress presentation · 1 December 2026",
], size=14, colour=MUTED, space_after=6)
note(s, "Order of speakers: P1, P2, P5, P4, P3, P6. 12 minutes in total.")

# ============================================================ P1 · Act I =====
s = slide(2, "Two games both average 8.0. Are they equally reliable?",
          "One has 30 ratings, the other 30,000", speaker="P1")
text(s, Inches(0.75), Inches(2.0), Inches(5.9), Inches(4.3), [
    "An average from 30 people is noisier than one from 30,000.",
    "So averages should be shrunk toward a typical value.",
    "But how far? That depends on how much of the spread is noise.",
], size=17, space_after=18)
text(s, Inches(6.9), Inches(2.0), Inches(5.8), Inches(4.3), [
    "RQ1  How much shrinkage does sampling noise in average ratings justify?",
    "RQ2  What explains ratings and popularity?",
    "RQ3  What does this imply for the ranking, compared with BGG's?",
], size=16, colour=INK2, space_after=16)
note(s, "P1. Hook, then the three research questions.")

s = slide(3, "Fewer ratings: lower and more scattered averages",
          "21,631 ranked BGG games, January 2022 snapshot (at least 30 ratings each)",
          speaker="P1")
picture(s, f"{FIG}/eda_03_average_vs_users.png", Inches(0.45), Inches(1.75),
        Inches(7.6), Inches(4.6))
text(s, Inches(8.4), Inches(1.95), Inches(4.4), Inches(4.4), [
    f"Mean rating rises from {MEAN_LO:.2f} (30–40 ratings) to {MEAN_HI:.2f} (5,000+)",
    f"Variance falls from {VAR_LO:.3f} to {VAR_HI:.3f}",
    "Any model must reproduce both patterns",
], size=15, colour=INK2, space_after=16)
note(s, "P1. Band statistics from tables/ppc_grouped_summary.csv (6,489 development games).")

s = slide(4, "BGG benchmark: about 1,900 dummy votes",
          "Its adjusted score behaves like a Bayesian average with a fixed number of votes at 5.5",
          speaker="P1")
picture(s, f"{P6F}/fig_bgg_m_only.png", Inches(0.45), Inches(1.75),
        Inches(8.0), Inches(4.6))
text(s, Inches(8.8), Inches(1.95), Inches(4.1), Inches(4.3), [
    f"Best single fit: {S['bgg_m_best_single_fit']:,.0f} votes (RMSE {S['bgg_m_fit_rmse']:.3f})",
    "Similar across rating-count bands",
    "A fitted approximation, not BGG's published algorithm",
    "Our question: how many do the data themselves support?",
], size=14.5, space_after=14)
note(s, "P1 presents P6's benchmark. 20,694 usable games; 681 excluded as "
        "inconsistent with any positive m. The target of 5.5 is assumed by this fitted "
        "constant-m approximation, not verified as BGG's official algorithm.")

# =========================================================== P2 · Act II =====
s = slide(5, "Our models", "Three models for the average rating, one for the number of ratings",
          speaker="P2")
table(s, Inches(0.6), Inches(1.8), [
    ["Model", "Outcome", "What it adds", "Owner"],
    ["M0", "average", "Bayesian linear regression; no measurement error", "P2"],
    ["M1a Baseline", "average", "Measurement error with one unknown rater SD s", "P5"],
    ["M1a Extended", "average", "Measured per-game SD; mean and spread vary with rating count", "P5"],
    ["M1b", "average", "Covariates and designer random effects", "P4"],
    ["M2", "number of ratings", "Truncated negative binomial vs Poisson", "P3"],
], [Inches(2.0), Inches(2.1), Inches(6.9), Inches(1.0)], font_size=13, row_h=Inches(0.42))
text(s, Inches(0.6), Inches(4.75), Inches(12.2), Inches(1.8), [
    "Measurement error: observed average = true score + noise with variance s² / n.",
    "Pseudo-votes m = s² / τ²: extra ratings at the predicted value that reproduce the model's "
    "shrinkage (τ = spread of true scores between games).",
], size=14, colour=INK2, space_after=10)
note(s, "P2. M2 has a different outcome and sample, so its fit is never compared with the "
        "rating models.")

s = figure_slide(6, "M0 fits the means but not the spread", [
    "M0 assumes one variance for every game",
    "It under-predicts spread for games with few ratings and over-predicts it for popular games",
    "Adding a measurement-error term s²/n (M1a) helps the low-count bands",
    f"Computation check: JAGS, hand-written Gibbs and CAVI agree within {M0_GAP:.4f}",
], f"{FIG}/ppc_variance_comparison_rating_count.png", speaker="P2", credit="Figures: P1, P2")
note(s, "P2. Grouped posterior predictive check by rating-count band. CAVI interval widths "
        "are 0.98–1.01 times Gibbs's; details in backup.")

# ===================================================== P5 · Acts II–III =====
s = figure_slide(7, "With averages alone, the rater SD is not identified", [
    f"M1a Baseline: s = {M1A_S:.2f}, against its prior bound of 3",
    f"M1b Baseline: s = {M1B_S:.2f}; widening the prior to 6 moves it to {M1B_S6:.2f} "
    f"and raises the median adjustment by {ADJ_RISE:.0f}%",
    f"Implied m ≈ {S['model_m_mean']:.1f}: a diagnostic of weak identification, not our answer",
    "Averages cannot separate rater noise from real spread between games",
], f"{P5F}/fig01_prior_posterior_s.png", speaker="P5", credit="Figure: P5; P4 sensitivity run")
note(s, "P5. The data alone cannot tell whether the extra spread of low-count games is "
        "rater noise or real heterogeneity, so s absorbs it.")

s = figure_slide(8, "Extended model: about 3 effective pseudo-votes", [
    f"Historical per-game rating SD: median {SD_MED:.2f}, half the inferred s",
    f"M1a Extended: model-based median m = {S['ranking_model_m_eff_median']:.2f} "
    f"(IQR {S['ranking_model_m_eff_q25']:.2f}–{S['ranking_model_m_eff_q75']:.2f}), 21,375 games",
    f"From {M_BAND_LO:.1f} (30–99 ratings) to {M_BAND_HI:.1f} (10,000+)",
    f"SD scaled by 0.8–1.2: median {sens['0.8']:.1f}–{sens['1.2']:.1f} (sensitivity range)",
], f"{P5F}/fig07_measured_sd_vs_s.png", speaker="P5", credit="Figure: P5")
note(s, "P5. Snapshot date of the historical SDs is unverified; rating counts match the 2022 "
        "data closely (median ratio 0.998). SD is a fixed plug-in. Priors on the mean and "
        "spread parameters have negligible effect in the tested scenarios (backup). "
        "The Extended median effective count is model-dependent, not uniquely identified or "
        "universally optimal. Historical SD estimates support smaller observation noise than "
        "the averages-only Baseline; they do not conclusively rule out its s values.")

s = figure_slide(9, "Prediction does not identify the variance split", [
    f"Extended beats Baseline: ΔELPD {float(EXT_BASE['delta_ELPD_A_minus_B']):.0f} "
    f"(SE {float(EXT_BASE['SE_cluster_approx']):.0f})",
    f"M1b beats M1a by about {float(M1B_M1A['delta_ELPD_A_minus_B']):,.0f}",
    f"In M1b, swapping in measured SDs: ΔELPD {float(M1B_SD['delta_ELPD_A_minus_B']):.0f} "
    f"(95% ≈ {float(M1B_SD['approx95_lower']):.0f} to {float(M1B_SD['approx95_upper']):.0f}): "
    "no demonstrated difference",
    "Historical SDs support noise below s ≈ 3, subject to unverified timing "
    "and fixed plug-ins; prediction scores do not identify the split",
], f"{P5F}/fig05_four_model_holdout.png", speaker="P5", size=13.5,
   credit="Figure: P5 · 3,209 holdout games, exploratory (consulted during development)")
note(s, "P5. Extended changes mean, spread and noise together, so its gain is not attributed "
        "to any one of them. External historical SD estimates support smaller observation-noise "
        "values subject to the unverified snapshot date and fixed plug-in assumption; they "
        "do not conclusively rule out s ≈ 3. WAIC is secondary: 13–15% of games have "
        "p_WAIC > 0.4 in M1b (backup).")

# ============================================================ P4 · Act IV =====
s = figure_slide(10, "Real SDs shrink low-count games much less", [
    f"Median adjustment at 30–40 ratings: {ADJ_BASE_3040:.2f} → {ADJ_EXT_3040:.2f} rating points",
    "Popular games barely move under either model",
    "Same 6,416 games, same covariates and designer effects",
], f"{P4F}/fig1_shrinkage_by_rating_count.png", speaker="P4", credit="Figure: P4")
note(s, "P4. Bars are interquartile ranges across games, not credible intervals.")

s = figure_slide(11, "About half the remaining spread is between designers", [
    f"σ_d = {SIG_D:.2f} vs τ = {TAU:.2f}: designers explain about half of the residual "
    "latent-rating variance",
    f"Older games rated lower: {coef['log1p_age']:+.2f} per SD of log(1+age)",
    f"Longer games rated higher: {coef['log1p_play']:+.2f} per SD of log play time",
    f"Wargame {coef['cat_Wargame']:+.2f}, miniatures {coef['cat_Miniatures']:+.2f}, "
    f"roll-and-move {coef['mech_Roll...Spin.and.Move']:+.2f} rating points",
], f"{P4F}/fig2_designer_effects.png", speaker="P4", fig_w=7.6, size=13.5,
   credit="Figure: P4 · M1b-ExternalSD, effects conditional on the other covariates")
note(s, "P4. Associations, not causal effects; designer effects are not a ranking of designers.")

# ============================================================ P3 · Act IV =====
s = figure_slide(12, "Attention follows a different pattern", [
    f"Wargames get {(1 - rr['cat_Wargame']) * 100:.0f}% fewer ratings (RR {rr['cat_Wargame']:.2f})",
    f"Economic ×{rr['cat_Economic']:.1f}, deduction ×{rr['cat_Deduction']:.1f}, "
    f"party ×{rr['cat_Party.Game']:.1f}",
    "Negative binomial strongly preferred to Poisson; some PPC misfit remains",
    "Wargames: rated higher, by far fewer people — consistent with niche games "
    "being rated mainly by enthusiasts",
], f"{P3F}/M2_NB_effects_forest.png", speaker="P3", fig_w=7.4, size=13.5,
   credit="Figure: P3 · 19,440 games, rate ratios conditional on the other covariates")
note(s, "P3. 'Consistent with' only: the model does not identify self-selection.")

# ============================================================= P6 · Act V =====
s = figure_slide(13, "M1a Extended puts niche games near the top", [
    f"Ranking all 21,375 games in each of 500 posterior draws",
    f"{P_TOP10_HALF} games have P(top 10) > 0.5",
    f"Median 90% rank interval for top-10 candidates: about "
    f"{S['median_90pct_width_top10_candidates']:.0f} places",
], f"{P6F}/fig_top10_probability.png", speaker="P6", credit="Figure: P6")
note(s, "P6. Rankings use M1a Extended. Its shrinkage depends on rating count and each game's "
        "historical SD; the target and latent variance also vary with rating count. M1b adds "
        "game features and designer effects to its target. The fitted BGG benchmark instead "
        "assumes a target of 5.5, so this comparison does not hold all assumptions constant. "
        "Historical SD timing is unverified and SD uncertainty is not propagated.")

s = figure_slide(14, "Our top ten and BGG's share no games", [
    f"Our top ten: median {OUR_TOP_N:.0f} ratings. BGG's: {BGG_TOP_N:,.0f}",
    f"Spearman across all games: {S['spearman_vs_bgg_adjusted']:.2f}",
    "Statistical estimation and ranking design answer different questions",
    "The fitted BGG approximation may reflect other goals (stability, resisting strategic voting) "
    "that our data cannot test",
], f"{P6F}/fig_rank_vs_bgg.png", speaker="P6", size=13.5, credit="Figure: P6")
note(s, "P6. Neither ranking is 'wrong'. Our shrinkage target varies with rating count; "
        "the fitted BGG benchmark assumes a target of 5.5.")

s = slide(15, "Model-dependent shrinkage: about 3 versus 1,900", speaker="P6")
picture(s, f"{P6F}/fig_pseudovotes_comparison.png", Inches(0.42), Inches(1.3),
        Inches(7.6), Inches(4.6))
text(s, Inches(8.35), Inches(1.45), Inches(4.4), Inches(3.6),
     f"M1a Extended estimates a median of about {S['ranking_model_m_eff_median']:.0f} effective "
     "pseudo-votes, conditional on its model and historical SDs. A constant-m fit to BGG "
     f"at target 5.5 implies about {round(S['bgg_m_best_single_fit'], -2):,.0f}. "
     "These are different shrinkage assumptions, not a universal optimum.", size=16, bold=True, space_after=12)
text(s, Inches(8.35), Inches(4.75), Inches(4.4), Inches(1.8), [
    "Next, by 6 Dec: M0 scored on the same holdout games; optionally M1b with spread "
    "varying by rating count",
    "Final report, code and data by 18 Dec",
], size=12.5, colour=INK2, space_after=8)
text(s, Inches(0.42), Inches(6.55), Inches(9), Inches(0.3), "Figure: P6", size=10,
     colour=MUTED)
note(s, "P6. The Extended median is model-dependent, not uniquely identified or universally "
        "optimal. It depends on the fitted mean and latent variance, priors, and game-specific "
        "historical SD estimates. Their snapshot date is unverified; SDs are fixed plug-ins. "
        "The BGG value is a fitted constant-m approximation assuming target 5.5, not a verified "
        "official algorithm. Baseline m ≈ 11.6 remains a diagnostic of weak identification and "
        "prior sensitivity. Then questions.")

# ================================================================ backups ====
s = figure_slide("B1", "Backup · sensitivity of the Extended model", [
    "Historical SD scaled by 0.8, 1.0 and 1.2",
    "Alternative priors on the mean and spread parameters: negligible change",
    "6,416 development games",
], f"{P5F}/fig04_sensitivity.png", credit="Figure: P5")

s = figure_slide("B2", "Backup · development WAIC", [
    "Same 6,416 games, 500 draws per model",
    "M1b: 13.4% (Baseline) and 14.8% (ExternalSD) of games have p_WAIC > 0.4",
    "M1b's likelihood conditions on learned designer effects",
    "Holdout ELPD is therefore the primary comparison",
], f"{P5F}/fig06_four_model_waic.png", credit="Figure: P5")

s = slide("B3", "Backup · M0 three ways",
          "JAGS, hand-written Gibbs and mean-field CAVI on 6,489 development games")
picture(s, f"{FIG}/M0_three_method_intervals.png", Inches(0.45), Inches(1.70),
        Inches(6.4), Inches(3.5))
picture(s, f"{FIG}/M0_cavi_elbo.png", Inches(7.05), Inches(1.70),
        Inches(5.8), Inches(3.5))
text(s, Inches(0.45), Inches(5.4), Inches(12.4), Inches(1.2), [
    f"Posterior means agree within {M0_GAP:.4f}; CAVI interval widths 0.98–1.01 × Gibbs.",
    "Runtime on one machine: CAVI 0.04 s, Gibbs 3.89 s, JAGS 70.64 s.",
], size=12.5, colour=INK2, space_after=6)

s = figure_slide("B4", "Backup · holdout posterior predictive check", [
    "Four rating-count bands, 3,209 holdout games",
    "Extended: 3 of 4 bands within 95% intervals for both mean and variance",
], f"{P5F}/fig03_grouped_holdout_ppc.png", credit="Figure: P5")

os.makedirs("slides", exist_ok=True)
prs.save(OUT)
print("saved", OUT, "with", len(prs.slides), "slides;",
      f"top-10 median ratings ours {OUR_TOP_N:.0f}, BGG {BGG_TOP_N:,.0f}")
