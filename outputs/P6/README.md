# P6 — BGG benchmark, ranking uncertainty and ranking results

Owner: P6 (Zhang Yihui, 1155272837). Covers RQ3 of the proposal.

Inputs are P5's handoff in [`outputs/P5/P6_Full_Handoff/`](../P5/P6_Full_Handoff/README.md).
Code is in [`code/P6/`](../../code/P6/). Every number below is produced by those
scripts; nothing is typed in by hand.

```bash
Rscript code/P6/01_bgg_benchmark.R     # benchmark
Rscript code/P6/02_rank_uncertainty.R  # ranking
Rscript code/P6/05_verification.R      # checks on the ranking pipeline
```

R 4.6, `data.table`, `ggplot2`. No model is fitted here: the scripts reuse the
posterior draws produced by P5.

---

## 1. A constant-m benchmark for BGG's adjusted score

BGG's adjusted score is consistent with a Bayesian average that adds a fixed number
of dummy votes at a fixed prior mean. With m dummy votes at C = 5.5,

```
bayes_average = (n · ybar + m · 5.5) / (n + m)
```

For a single game this can be inverted, giving the count that game's own numbers
imply:

```
m_i = n_i (ybar_i − bayes_i) / (bayes_i − 5.5)
```

**This is an equivalent count under a constant-m approximation, not an official BGG
parameter.** The numbers below describe how well that approximation reproduces the
published scores; they do not identify BGG's actual algorithm.

| Quantity | Value |
|---|---|
| Games in the handoff | 21,375 |
| Usable for the decomposition | 20,694 |
| Not consistent with any positive m | 681 |
| Implied m — median | 1,841 (IQR 1,709 – 2,081) |
| Implied m — 5th / 95th percentile | 1,278 / 3,283 |
| Best single m by least squares | **1,874** (RMSE 0.020) |

The median implied m is similar in every rating-count band (1,860 / 1,835 / 1,810 /
2,209 for 30–99, 100–999, 1,000–9,999 and 10,000+ ratings). That pattern is
**approximately consistent with a constant-m benchmark**, though the top band is
noticeably higher and the per-game spread is wide. It is not proof that BGG applies
one fixed number.

## 2. What the model implies

| Quantity | Value |
|---|---|
| M1a Baseline posterior m = s²/τ² | **11.6** (95% credible interval 10.7 – 12.3) |
| M1a Extended, effective per-game m | median **3.02** (IQR 2.36 – 3.84) over all 21,375 games |
| BGG ÷ Baseline | **161×** |
| BGG ÷ ranking-model median | **620×** |

Two caveats belong with these numbers.

First, the Baseline m is an estimate under this model and its priors, not a
property of the data alone. In the M1a posterior `s` sits at the top of its prior
(posterior mean 2.96, prior upper bound 3.0). The data contain averages only, so `s`
is weakly identified; a different prior on `s` would move `m`. It is therefore more
accurate to say the data are **consistent with a small m under this prior** than
that sampling noise alone justifies twelve votes.

Second, the ranking export uses the **Extended** model, which has a shrinkage target
that varies with n (`mu_i = alpha + gamma·x_i`, `x_i = log n_i − x_center`) and a
variance that varies with n (`tau2_i = exp(2(a_tau + b_tau·x_i))`). There is no single
m in that model. The effective per-game count is computed draw by draw as

```
m_i^(b) = sd_hist_i^2 / exp(2 (a_tau^(b) + b_tau^(b) x_i))
```

with the posterior mean taken per game and the median/IQR reported across games —
the same aggregation as `code/P5/05_Extended_SD_sensitivity.R`. All 12,000 parameter
draws are used, in batches, and no game is filtered out. The median is 3.02; P5's
independently computed 3.06 on 6,416 development games is consistent with it.

The Extended model does **not** inherit the Baseline's prior on `s`. It replaces
`s²/n` with a per-game `sd_hist²/n` plug-in, keeps no shared `s`, and has its own
priors on `a_tau` and `b_tau`. Its own prior- and SD-sensitivity runs are in
`outputs/P5/Sensitivity_Analysis/`; the numbers above should be read as that model's
result, not as a re-parameterisation of the Baseline.

## 3. Ranking under posterior shrinkage

P5 exports 500 **joint** posterior draws of each game's latent rating, in five RDS
parts of 21,375 games × 100 draws. The parts are concatenated by column and games
are ranked **inside each joint draw**, so that game A is compared with game B under
the same posterior sample. Ranking once on the posterior mean would ignore the
correlation between games and understate the uncertainty in the ordering.

These are latent ratings from **M1a Extended**, not from M1b, which has the best
holdout predictive performance. The two questions are different: M1b is fitted to
predict an average, M1a is the model from which a pseudo-vote count is defined.

| Quantity | Value |
|---|---|
| Games ranked | 21,375 |
| Joint draws | 500 |
| Spearman vs BGG's adjusted ranking (same games) | **0.78** |
| Top-10 overlap with BGG's adjusted ranking | **0 / 10** |
| Top-50 overlap | 1 / 50 |
| Median 90% rank-interval width, all games | 2,576 ranks |
| Median 90% rank-interval width, top-10 candidates | 71 ranks |
| Games with P(top 10) > 0.5 | 6 |
| Games with P(top 10) > 0.05 | 28 |

Top-k lists compared with BGG are ordered by **posterior median rank**, not by
P(top k). At 500 draws the Monte Carlo standard error of a probability is at most
0.022 (at p = 0.5). All 41 structural and numerical checks in
`rank_verification_checks.md` pass.

### The rankings disagree at the top

| | Our median-rank top 10 | BGG adjusted-score top 10 |
|---|---|---|
| Median rating count | **46** (range 30–101) | **25,535** (range 15,498 – 74,216) |
| Median raw average | 9.27 | 8.55 |
| Median latent / adjusted rating | 9.13 | 8.26 |
| Median rating count, top 100 | 76 | 20,767 |

A game with 43 ratings and a 9.56 average keeps almost all of that average under our
shrinkage, so it has the highest posterior median rank in this set; BGG's rule pulls
the same game back toward 5.5, which is why the familiar titles lead its list.

**Tie-breaking.** No single posterior draw contains a tie, but the summarised median
ranks do: the 10th and 11th games both have a median rank of 14. Both orderings
therefore use a fully determined key — our ranking by median rank, then mean rank,
then game id; BGG's by adjusted score, then game id — so the top-k lists do not depend
on input row order. At the 10/11 boundary the key puts **Urgency** in (mean rank
19.13) and leaves **Flip & Fish** out (mean rank 20.39), even though Flip & Fish
appears in the top 10 slightly more often (P(top 10) 0.374 against 0.300). The choice
of secondary key is arbitrary and the boundary is genuinely uncertain; the top-ten
statistics in the table above are reported with that caveat.

**What can and cannot be said.** The divergence at the top is consistent with the
much smaller shrinkage our model applies. It should not be attributed to m alone:
the Extended model's shrinkage target varies with n, its variance is
heteroskedastic, and both differ from the assumptions behind BGG's rule. The honest
statement is that the two rankings encode different beliefs about how much a rating
from a small number of raters should be trusted, and that this choice — not sampling
noise — is what separates the two lists.

## 4. Verification

`code/P6/05_verification.R` re-derives the structural checks from the raw inputs and
writes [`rank_verification_checks.csv`](rank_verification_checks.csv) and
[`rank_verification_checks.md`](rank_verification_checks.md). It confirms: each part
is 21,375 × 100 and the merge is 21,375 × 500; ids are unique and in the same order
everywhere; draws are finite; `draw_numbers` covers 1–500 without repeats; the
posterior means and intervals computed from the draws reproduce the handoff CSV;
rank intervals are ordered; each draw contains exactly one game at each rank and
exactly k games inside the top k (so there are no ties to break); and
P(top 10), P(top 50), P(top 100) lie in [0, 1], are monotone per game, and sum to
10, 50 and 100 respectively.

## 5. Figures

| File | Contents |
|---|---|
| `figures/P6/fig_bgg_pseudovotes.png` | Distribution of BGG's implied m against the model's m (log scale) |
| `figures/P6/fig_bgg_m_by_band.png` | Implied m by rating-count band |
| `figures/P6/fig_top10_probability.png` | P(top 10) for the 20 most likely games |
| `figures/P6/fig_rank_intervals.png` | 90% rank intervals for the 15 highest-ranked games, with BGG's rank marked |
| `figures/P6/fig_rank_vs_bgg.png` | Our median rank against BGG's adjusted rank, all 21,375 games |

## 6. Data files

| File | Contents |
|---|---|
| `bgg_benchmark_summary.csv` | Every quantity in sections 1 and 2 |
| `bgg_implied_m_by_game.csv` | Per-game implied m (20,694 games) |
| `bgg_implied_m_excluded.csv` | The 681 games inconsistent with any positive m |
| `bgg_implied_m_by_rating_band.csv` | Median and quartiles of implied m by n |
| `ranking_model_effective_m.csv` | Per-game effective m of the Extended ranking model (all 21,375 games) |
| `ranking_model_effective_m_by_band.csv` | The same, aggregated by n |
| `rank_uncertainty_all_games.csv` | Median rank, 5th/95th rank, P(top 10/50/100), BGG rank |
| `top10_posterior_probabilities.csv` | Top 30 games by P(top 10) |
| `rank_vs_bgg_summary.csv` | Spearman, overlaps, interval widths |
| `rank_verification_checks.csv` / `.md` | The 41 checks |

## 7. Scope and limitations

1. **Ranking scope.** All rankings are within the 21,375 SD-matched games of the
   cleaned 2022 snapshot — not all games on BGG and not the current site ranking.
   Conclusions must not be extended beyond this set.
2. **Not holdout predictions.** `theta` conditions on each game's own observed
   average and rating count, including games that were in P5's exploratory holdout.
   These are within-sample latent estimates.
3. **Historical SD is a plug-in.** The Extended model's per-game `sd_hist` comes from
   an external snapshot whose date and provenance are not verified, and its
   measurement uncertainty is not propagated.
4. **`bgg_bayes_average` and `bgg_rank` are benchmarks**, not model predictors. The
   site-wide `bgg_rank` also counts games outside our 21,375, so the comparison
   re-ranks BGG's adjusted score within the same set.
5. **681 games** cannot be decomposed into a positive m at all (for example when
   `bayes_average` equals `raw_average`); they are excluded from the benchmark and
   listed separately.
6. **"BGG's rule is wrong" is not a supported claim.** Its larger m may also serve to
   resist strategic voting and to produce a stable list; that is a plausible design
   purpose, not something this study demonstrates. The benchmark quantifies what one
   model, under one prior, implies.

## 8. Slide-ready points

- BGG's published adjusted score is consistent with about **1,874 dummy votes at
  5.5**, and the implied count varies little across rating counts.
- Under M1a, `m = s²/τ²` has posterior mean **11.6 (95% CI 10.7 – 12.3)**; the
  ranking model's effective per-game count has median **3.0**. Both are model-based
  and depend on the prior for `s`.
- The two rankings agree broadly (Spearman 0.78) but share **none** of their top ten.
  That gap reflects the different shrinkage assumptions, not sampling noise alone.

## 9. Report mapping

Feeds **RQ3 (BGG benchmark and ranking uncertainty)** and the discussion of what the
gap reflects. English section draft in
[`docs/P6_DELIVERY.md`](../../docs/P6_DELIVERY.md).
