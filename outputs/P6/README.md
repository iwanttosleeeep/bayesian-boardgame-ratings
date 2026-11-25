# P6 — BGG benchmark, ranking uncertainty and ranking results

Owner: P6 (Zhang Yihui, 1155272837). Covers RQ3 of the proposal.

Inputs are P5's handoff in [`outputs/P5/P6_Full_Handoff/`](../P5/P6_Full_Handoff/README.md).
Code is in [`code/P6/`](../../code/P6/). Every number below is produced by those
scripts; nothing is typed in by hand.

```bash
Rscript code/P6/01_bgg_benchmark.R
Rscript code/P6/02_rank_uncertainty.R
```

R 4.6, `data.table`, `ggplot2`. No model is fitted here: both scripts reuse
posterior draws produced by P5.

---

## 1. What BGG's rating rule implies

BGG's adjusted score (`bayes_average`) behaves like a Bayesian average that adds a
fixed number of dummy votes at a fixed prior mean. With m dummy votes at prior
mean C = 5.5,

```
bayes_average = (n · ybar + m · 5.5) / (n + m)
```

so each game's own implied m can be recovered exactly:

```
m_i = n_i (ybar_i − bayes_i) / (bayes_i − 5.5)
```

| Quantity | Value |
|---|---|
| Games in the handoff | 21,375 |
| Usable for the decomposition | 20,694 |
| Not consistent with any positive m | 681 |
| **Implied m — median** | **1,841** (IQR 1,709 – 2,081) |
| Implied m — 5th / 95th percentile | 1,278 / 3,283 |
| **Best single m by least squares** | **1,874** (RMSE 0.020) |

The median implied m is essentially the same in every rating-count band
(1,860 / 1,835 / 1,810 / 2,209 for 30–99, 100–999, 1,000–9,999 and 10,000+ ratings),
which confirms that BGG applies one fixed number rather than a rule that depends on n.
This reproduces the benchmark reported in the earlier literature and in the group plan.

## 2. What the model implies

| Quantity | Value |
|---|---|
| **M1a Baseline posterior m = s²/τ²** | **11.6** (95% CI 10.7 – 12.3) |
| M1a Extended, effective per-game m (ranking model) | median **3.3** (IQR 2.1 – 5.3), 8,995 games |
| BGG / Baseline ratio | **161×** |
| BGG / ranking-model median ratio | **569×** |

Two things matter for reading this.

First, the Baseline m is small because `s` — one rater's SD around a game's true
score — is barely identified. In the M1a posterior `s` sits at the upper end of its
prior (posterior mean 2.96 with the prior upper bound at 3.0). The data cannot pin
`s` down, so m inherits that uncertainty. This is RQ2, not a defect of P6.

Second, the ranking export uses the **Extended** model, which replaces the common
`s²/n` with each game's own `sd_hist²/n`. It therefore has no single m; the
effective per-game m has median 3.3. The ranking is consequently shrunk *even less*
than the Baseline, so the 161× figure understates the gap for the ranking below.

## 3. Ranking under posterior shrinkage

P5 exports 500 **joint** posterior draws of each game's latent rating, in five RDS
parts of 21,375 games × 100 draws. The parts are concatenated by column and games
are ranked **inside each joint draw**, so that game A is compared with game B under
the same posterior sample. Ranking once on the posterior mean would ignore the
correlation between games and understate the uncertainty in the ordering.

| Quantity | Value |
|---|---|
| Games ranked | 21,375 |
| Joint draws | 500 |
| Spearman vs BGG's adjusted ranking (same games) | **0.78** |
| Top-10 overlap with BGG's adjusted ranking | **0 / 10** |
| Top-50 overlap | 1 / 50 |
| Median 90% rank-interval width, all games | 2,576 ranks |
| Median 90% rank-interval width, top-10 candidates | 71 ranks |
| Games with P(top 10) > 0.05 | 28 |

### The rankings disagree completely at the top

| | Our median-rank top 10 | BGG adjusted-score top 10 |
|---|---|---|
| Median rating count | **46** (range 30–101) | **25,535** (range 15,498 – 74,216) |
| Median raw average | 9.27 | 8.55 |
| Median latent / adjusted rating | 9.13 | 8.26 |
| Median rating count, top 100 | 76 | 20,767 |

Because the model justifies almost no shrinkage, a game with 43 ratings and a 9.56
average keeps a latent rating of 9.44 and outranks everything. BGG's rule shrinks the
same game toward 5.5 hard enough that the familiar titles — Gloomhaven, Pandemic
Legacy, Brass: Birmingham — occupy the top ten. The two lists are not a mistake in
either method; they are two answers to "how much should a 40-rating average be
trusted".

**The ranking is therefore an expression of m, not an independent result.** This is
the strongest evidence in the project that the pseudo-vote choice is a modelling
decision with substantive consequences, and it is the point the BGG comparison should
make in the report.

## 4. Figures

| File | Contents |
|---|---|
| `figures/P6/fig_bgg_pseudovotes.png` | Distribution of BGG's implied m against the model's m (log scale) |
| `figures/P6/fig_bgg_m_by_band.png` | Implied m by rating-count band — evidence the rule is a fixed m |
| `figures/P6/fig_top10_probability.png` | P(top 10) for the 20 most likely games |
| `figures/P6/fig_rank_intervals.png` | 90% rank intervals for the 15 highest-ranked games, with BGG's rank marked |
| `figures/P6/fig_rank_vs_bgg.png` | Our median rank against BGG's adjusted rank, all 21,375 games |

## 5. Data files

| File | Contents |
|---|---|
| `bgg_benchmark_summary.csv` | Every quantity in sections 1 and 2 |
| `bgg_implied_m_by_game.csv` | Per-game implied m (20,694 games) |
| `bgg_implied_m_excluded.csv` | The 681 games inconsistent with any positive m |
| `bgg_implied_m_by_rating_band.csv` | Median and quartiles of implied m by n |
| `ranking_model_effective_m.csv` | Per-game effective m of the Extended ranking model |
| `ranking_model_effective_m_by_band.csv` | The same, aggregated by n |
| `rank_uncertainty_all_games.csv` | Median rank, 5th/95th rank, P(top 10/50/100), BGG rank |
| `top10_posterior_probabilities.csv` | Top 30 games by P(top 10) |
| `rank_vs_bgg_summary.csv` | Spearman, overlaps, interval widths |

## 6. Scope and limitations

1. **Ranking scope.** All rankings are within the 21,375 SD-matched games of the
   cleaned 2022 snapshot — not all games on BGG and not the current site ranking.
2. **Not holdout predictions.** `theta` conditions on each game's own observed
   average and rating count, including games that were in P5's exploratory holdout.
   These are within-sample latent estimates, not out-of-sample forecasts.
3. **Historical SD is a plug-in.** The Extended model's per-game `sd_hist` comes from
   an external snapshot whose date and provenance are not verified, and its
   measurement uncertainty is not propagated.
4. **`bgg_bayes_average` and `bgg_rank` are benchmarks**, not model predictors. The
   site-wide `bgg_rank` also counts games outside our 21,375, so the comparison
   re-ranks BGG's adjusted score within the same set.
5. **681 games** cannot be decomposed into a positive m at all (for example when
   `bayes_average` equals `raw_average`); they are excluded from the benchmark and
   listed separately.
6. **"BGG's rule is wrong" is not a supported claim.** Its larger m also resists
   strategic voting and produces a more stable list. Our m answers a narrower
   question — how much shrinkage sampling noise alone justifies.

## 7. Slide-ready points (1 Dec presentation)

- BGG's adjusted score implies **about 1,874 dummy votes at 5.5** per game, and the
  implied number barely varies with rating count — it is a fixed rule.
- Under M1a, sampling noise alone justifies **about 12** (95% CI 10.7–12.3), roughly
  **160× fewer**; the ranking export uses an even lighter shrinkage (median 3.3).
- Because of that, the two rankings agree on the broad shape of the list
  (Spearman 0.78) but share **zero** of their top ten.
- The top ten therefore demonstrates the consequence of the m choice rather than a
  separate finding: our model favours low-n, high-average games; BGG favours
  well-established ones.

## 8. Report mapping

Feeds **RQ3 (BGG benchmark and ranking uncertainty)** and the discussion of what the
gap reflects. Report outline slots: "Bayesian inference" (rank intervals) and
"Results and conclusion" (benchmark, watchlist). English section drafted in
[`docs/P6_DELIVERY.md`](../../docs/P6_DELIVERY.md).
