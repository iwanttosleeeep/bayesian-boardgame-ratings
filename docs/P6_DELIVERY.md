# P6 — delivery summary and presentation material

Status at 25 Nov 2026, revised after the first PR review. Full method and caveats in
[`outputs/P6/README.md`](../outputs/P6/README.md). Every number comes from
`code/P6/01_bgg_benchmark.R`, `02_rank_uncertainty.R` and `05_verification.R`.

## What is delivered

| Deliverable | Where | Status |
|---|---|---|
| Constant-m benchmark for BGG's adjusted score | `outputs/P6/bgg_benchmark_summary.csv` | done |
| Effective pseudo-votes of the ranking model | `outputs/P6/ranking_model_effective_m*.csv` | done |
| Ranking uncertainty over 500 joint draws | `outputs/P6/rank_uncertainty_all_games.csv` | done |
| Top-10 probabilities | `outputs/P6/top10_posterior_probabilities.csv` | done |
| Ranking comparison with BGG | `outputs/P6/rank_vs_bgg_summary.csv` | done |
| Verification log (36 checks, all pass) | `outputs/P6/rank_verification_checks.md` | done |
| Figures (5) | `figures/P6/` | done |
| Slide material | section 3 below | done |
| English report section | section 4 below | **draft, needs rewriting** |
| Slide integration | — | pending other members' final material |

## 1. Headline numbers

| Quantity | Value |
|---|---|
| Implied dummy votes under a constant-m benchmark | **1,874** (per-game median 1,841) |
| Posterior m = s²/τ² under M1a Baseline | **11.6** (95% CI 10.7 – 12.3) |
| Effective per-game m in the ranking model | median **3.02** (IQR 2.36 – 3.84), all 21,375 games |
| BGG ÷ Baseline | **161×** |
| BGG ÷ ranking-model median | **620×** |
| Spearman, our ranking vs BGG's adjusted ranking | **0.78** |
| Top-10 overlap / Top-50 overlap | **0 / 10** and **1 / 50** |
| Games with P(top 10) > 0.5 | **6** |
| Median 90% rank interval (all games) | 2,576 ranks |
| Median 90% rank interval (top-10 candidates) | 71 ranks |

## 2. Figures

| File | One-line description for the slide |
|---|---|
| `fig_bgg_pseudovotes.png` | BGG's rule corresponds to ~1,870 dummy votes; the model's m is about 12 |
| `fig_bgg_m_by_band.png` | The implied m varies little across rating counts |
| `fig_top10_probability.png` | P(top 10) for the 20 most likely games; six exceed 50% |
| `fig_rank_intervals.png` | 90% rank intervals are narrow at the top and widen quickly |
| `fig_rank_vs_bgg.png` | Broad agreement in the middle of the list, none at the top |

## 3. Slide material (3–4 slides)

**Slide A — The benchmark.**
BGG's public score is consistent with a Bayesian average that adds a fixed number of
dummy votes at 5.5. Fitting one number to 20,694 games gives 1,874, and the implied
count varies little across rating counts. This is an equivalent count under a
constant-m approximation, not BGG's published algorithm.

**Slide B — What the model implies.**
Under M1a the pseudo-vote count is `m = s²/τ²` with posterior mean 11.6 (95% CI
10.7 – 12.3). The ranking export uses the Extended model, whose effective per-game
count has median 3.0. Both numbers depend on the prior for `s`, which the data
inform only weakly — `s` sits near the top of its prior.

**Slide C — The consequence for the ranking.**
Ranking inside each of 500 joint posterior draws, our top ten has a median of 46
ratings against 25,535 for BGG's, and the two lists share no games. Agreement across
the whole list is 0.78.

**Slide D — Careful phrasing.**
The gap is consistent with the difference in shrinkage, but it is not attributable
to m alone: the shrinkage target, the heteroskedastic variance and BGG's own rule
all differ. We do not claim BGG is wrong; its larger m may also resist strategic
voting.

## 4. Report section — draft (must be rewritten before submission)

> **BGG benchmark and ranking uncertainty.**
> BoardGameGeek's adjusted score is consistent with a Bayesian average that adds a
> fixed number of dummy votes at a prior mean of 5.5. Inverting that formula on
> 20,694 games gives an equivalent count of 1,874 dummy votes (per-game median
> 1,841), with little variation across rating counts. Under the M1a model the same
> quantity, m = s²/τ², has a posterior mean of 11.6 (95% CI 10.7–12.3), and the
> model behind the ranking has an effective per-game count of about 3. Both are
> model-based quantities that depend on the prior for the weakly identified rater SD.
> Ranking 21,375 games inside each of 500 joint posterior draws shows that the top of
> the list is sensitive to that choice: the model's top ten has a median of 46
> ratings against 25,535 for BGG's, and the two top tens do not intersect, although
> the orderings correlate at 0.78 over the whole list. Because the shrinkage target,
> the variance structure and BGG's own rule all differ, we do not attribute the gap
> to the pseudo-vote count alone.

**Editor's note — delete before submission.** The paragraph above was drafted with AI
assistance and must be rewritten in the author's own words. The course guidance allows
AI support but expects each member to be able to explain and defend every number.

## 5. Open items

- Slide integration needs every member's final figures (28 Nov freeze).
- P4 and P5 have no presentation figures committed yet; their slides currently carry
  numbers only.
- If P5 re-exports draws with a different model, all three P6 scripts must be rerun.
