# P6 — delivery summary and presentation material

Status at 25 Nov 2026. Full method and caveats in
[`outputs/P6/README.md`](../outputs/P6/README.md). All numbers come from
`code/P6/01_bgg_benchmark.R` and `code/P6/02_rank_uncertainty.R`.

## What is delivered

| Deliverable | Where | Status |
|---|---|---|
| BGG pseudo-vote benchmark | `outputs/P6/bgg_benchmark_summary.csv`, `bgg_implied_m_*.csv` | done (26 Nov milestone) |
| Ranking uncertainty over 500 joint draws | `outputs/P6/rank_uncertainty_all_games.csv` | done (27 Nov milestone) |
| Top-10 probabilities | `outputs/P6/top10_posterior_probabilities.csv` | done |
| Ranking comparison with BGG | `outputs/P6/rank_vs_bgg_summary.csv` | done |
| Figures (5) | `figures/P6/` | done |
| Slide material | section 3 below | done |
| English report section | section 4 below | **draft, needs rewriting** |
| Slide integration | — | **pending: needs all members' figures** |

## 1. Headline numbers

| Quantity | Value |
|---|---|
| Implied dummy votes in BGG's adjusted score | **1,874** (per-game median 1,841) |
| Posterior m = s²/τ² under M1a Baseline | **11.6** (95% CI 10.7–12.3) |
| Effective m in the ranking export (Extended model) | median **3.3** (IQR 2.1–5.3) |
| BGG ÷ Baseline | **161×** |
| BGG ÷ ranking-model median | **569×** |
| Spearman, our ranking vs BGG's adjusted ranking | **0.78** |
| Top-10 overlap / Top-50 overlap | **0 / 10** and **1 / 50** |
| Median 90% rank interval (all games) | 2,576 ranks |
| Median 90% rank interval (top-10 candidates) | 71 ranks |

## 2. Figures

| File | One-line description for the slide |
|---|---|
| `fig_bgg_pseudovotes.png` | BGG's rule is equivalent to ~1,870 dummy votes; sampling noise justifies ~12 |
| `fig_bgg_m_by_band.png` | The implied m is flat across rating counts — it is a fixed rule, not an n-dependent one |
| `fig_top10_probability.png` | P(top 10) for the 20 most likely games; only the first four exceed 50% |
| `fig_rank_intervals.png` | 90% rank intervals are narrow at the very top and widen quickly |
| `fig_rank_vs_bgg.png` | Broad agreement in the middle of the list (Spearman 0.78), none at the top |

## 3. Slide material (3–4 slides)

**Slide A — The benchmark.**
BGG's public score is not a raw average. Solving its formula game by game gives an
implied 1,874 dummy votes at 5.5 (median 1,841), and that number is essentially the
same at every rating count. It is a fixed rule.

**Slide B — What the data imply.**
Under M1a the pseudo-vote count is m = s²/τ² = 11.6 (95% CI 10.7–12.3) — about 160
times smaller. The ranking export uses an even lighter shrinkage (median 3.3).

**Slide C — The consequence.**
Ranking inside each of 500 joint posterior draws, our top ten has a median of 46
ratings; BGG's has 25,535. The lists share **zero** games. Agreement in the middle of
the list is high (Spearman 0.78), so this is not noise — it is the shrinkage choice.

**Slide D — The honest caveat.**
s is barely identified: the posterior sits near the top of its prior. So m is prior-
dependent, and the ranking is a direct expression of that choice. We are not claiming
BGG is wrong; its larger m also protects against strategic voting.

## 4. Report section — draft (must be rewritten before submission)

> **BGG benchmark and ranking uncertainty.**
> The adjusted score published by BoardGameGeek behaves like a Bayesian average that
> adds a fixed number of dummy votes at a prior mean of 5.5. Inverting that formula on
> 20,694 games gives an implied 1,874 dummy votes, with a median of 1,841 and almost no
> variation across rating counts, which confirms that the rule is fixed rather than
> sample-size dependent. Under our M1a model the same quantity, m = s²/τ², has a
> posterior mean of 11.6 (95% CI 10.7–12.3). The two answers differ by a factor of about
> 160, and the ranking used in this report applies an even smaller per-game shrinkage.
> Ranking 21,375 games inside each of 500 joint posterior draws shows that the top of
> the list is almost entirely determined by that choice: the model's top ten has a
> median of 46 ratings against 25,535 for BGG's, and the two top tens do not intersect,
> although the two orderings correlate at 0.78 over the whole list. Because s is only
> weakly identified by aggregated data, m inherits prior uncertainty; the benchmark
> therefore quantifies what sampling noise alone justifies, not what BGG should do.

**Editor's note — delete before submission.** The paragraph above was drafted with AI
assistance and must be rewritten in the author's own words. The course guidance allows
AI support but expects each member to be able to explain and defend every number. All
figures and CSVs here are reproducible from the two scripts.

## 5. Open items

- Slide integration needs every member's final figures (28 Nov freeze).
- P1's grouped PPC deliverable and a few presentation figures are still open on their
  side; P6 does not depend on them for the numbers above.
- If P5 later re-exports draws with a different model, both P6 scripts must be rerun;
  neither reads a cached result.
