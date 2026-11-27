# P6 — delivery summary and presentation material

Status at **27 Nov 2026**: all core P6 analytical deliverables and group slide integration are complete; the English report section remains a draft. Full method and caveats in
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
| Verification log (41 checks, all pass) | `outputs/P6/rank_verification_checks.md` | done |
| Figures (7) | [P6 figure index](../outputs/P6/README.md#5-figures) | done |
| Slide material | section 3 below | done |
| English report section | section 4 below | **draft, needs rewriting** |
| Slide integration | [Group deck](../slides/Group_deck_draft.pptx), 15 main + 4 backup slides | done |

## 1. Headline numbers

| Quantity | Value |
|---|---|
| Fitted constant-m pseudo-votes, assuming target 5.5 | **1,874** (per-game median 1,841) |
| Baseline diagnostic m = s²/τ² (weak identification / prior sensitivity) | **11.6** (95% CI 10.7 – 12.3) |
| M1a Extended model-dependent effective m | median **3.02** (IQR 2.36 – 3.84), all 21,375 games |
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
| [fig_bgg_pseudovotes.png](../figures/P6/fig_bgg_pseudovotes.png) | Earlier constant-m benchmark comparison with the Baseline diagnostic m ≈ 11.6 |
| [fig_bgg_m_by_band.png](../figures/P6/fig_bgg_m_by_band.png) | The implied count under target 5.5 is similar across most rating-count bands |
| [fig_top10_probability.png](../figures/P6/fig_top10_probability.png) | P(top 10) for the 20 most likely games; six exceed 50% |
| [fig_rank_intervals.png](../figures/P6/fig_rank_intervals.png) | 90% rank intervals are narrow at the top and widen quickly |
| [fig_rank_vs_bgg.png](../figures/P6/fig_rank_vs_bgg.png) | Broad agreement in the middle of the list, none at the top |
| [fig_bgg_m_only.png](../figures/P6/fig_bgg_m_only.png) | BGG constant-m approximation only, used on group slide 4 |
| [fig_pseudovotes_comparison.png](../figures/P6/fig_pseudovotes_comparison.png) | M1a Extended effective counts versus the BGG fitted approximation, used on slide 15 |

## 3. Supporting presentation wording

**Slide A — The benchmark.**
Assuming a target of 5.5, a fitted constant-m approximation summarises BGG's public score by adding a fixed number of dummy votes. Fitting one number to 20,694 games gives 1,874, and the implied
count varies little across rating counts. This is an equivalent count under a
constant-m approximation, not BGG's published algorithm.

**Slide B — What the model implies.**
Under **M1a Baseline** the diagnostic pseudo-vote count is `m = s²/τ²` with posterior mean 11.6 (95% CI
10.7 – 12.3). That value depends on the prior for `s`, which the data inform only
weakly — `s` sits near the top of its prior. The ranking export uses the Extended
model instead, which has no shared `s`: it plugs in each game's historical SD and has
its own priors on `a_tau` and `b_tau`. Its shrinkage depends on rating count and game-specific historical SD; the target and latent variance also vary with rating count. Its **model-dependent median effective count is 3.02** across 21,375 games, not a uniquely identified or universally optimal value. External historical SD estimates support smaller observation-noise values, subject to the unverified snapshot date and fixed plug-in assumption.

**Slide C — The consequence for the ranking.**
Ranking inside each of 500 joint posterior draws, our top ten has a median of 46
ratings against 25,535 for BGG's, and the two lists share no games. Agreement across
the whole list is 0.78.

**Slide D — Careful phrasing.**
The gap is consistent with the difference in shrinkage, but it is not attributable
to m alone: the shrinkage target, the heteroskedastic variance and fitted BGG benchmark assumptions
all differ. We do not claim BGG is wrong; the larger fitted benchmark m may be consistent with ranking-design goals such as resistance to strategic voting, which this study cannot test.

## 4. Report section — draft (must be rewritten before submission)

> **BGG benchmark and ranking uncertainty.**
> BoardGameGeek's adjusted score is consistent with a Bayesian average that adds a
> fixed number of dummy votes under an assumed target of 5.5. This is a fitted
> constant-m approximation, not a verified official BGG algorithm. Inverting that formula on
> 20,694 games gives an equivalent count of 1,874 dummy votes (per-game median
> 1,841), with little variation across rating counts. Under M1a Baseline the same
> quantity, m = s²/τ², has a posterior mean of 11.6 (95% CI 10.7–12.3); that estimate
> depends on the prior for the weakly identified rater SD. The model behind the
> ranking is a different specification, which replaces that shared SD with a per-game
> historical SD plug-in. Its model-dependent median effective count is 3.02, not
> a universal optimum. The shrinkage weight depends on rating count and per-game
> SD; the target and latent variance also vary with rating count. The historical
> SD snapshot date is unverified, and SD uncertainty is not propagated.
> Ranking 21,375 games inside each of 500 joint posterior draws shows that the top of
> the list is sensitive to that choice: the model's top ten has a median of 46
> ratings against 25,535 for BGG's, and the two top tens do not intersect, although
> the orderings correlate at 0.78 over the whole list. Because the shrinkage target,
> the variance structure and the fitted BGG benchmark assumptions all differ, we do not attribute the gap
> to the pseudo-vote count alone.

**Editor's note — delete before submission.** The paragraph above was drafted with AI
assistance and must be rewritten in the author's own words. The course guidance allows
AI support but expects each member to be able to explain and defend every number.

## 4b. Assembled group deck — 15 main slides + 4 backups

The current [group deck](../slides/Group_deck_draft.pptx) is assembled from the committed member figures. The [builder](../code/P6/04_make_group_deck.py) follows the agreed five-act narrative; the [README running order](../README.md#presentation-running-order-12-minutes-every-member-speaks-once) remains authoritative. The title slide is main slide 1.

| Slides | Speaker | Content | Figure sources |
| --- | --- | --- | --- |
| 2–4 | P1 | Question, rating-count pattern and fitted BGG benchmark | P1 EDA, P6 benchmark |
| 5–6 | P2 | Model map and M0 grouped variance PPC | Model table, P1 PPC |
| 7–9 | P5 | Baseline identification, historical SD and exploratory predictive comparison | P5 fig01, fig07, fig05 |
| 10–11 | P4 | Shrinkage by rating count and designer/covariate effects | P4 presentation figures |
| 12 | P3 | Popularity and the wargame pattern | P3 NB effects |
| 13–15 | P6 | Ranking uncertainty, top-ten divergence and conclusion | P6 top-ten probability, rank comparison, effective pseudo-votes |
| B1 | Backup | Extended-model sensitivity | P5 fig04 |
| B2 | Backup | Development WAIC and reliability caveats | P5 fig06 |
| B3 | Backup | M0 three-method comparison | P2 interval and ELBO figures |
| B4 | Backup | Exploratory holdout PPC | P5 fig03 |

The retired standalone P6 deck and its builder have been removed; the group deck and builder linked above are the current presentation files. This audit inspected the committed PPTX read-only and did not rebuild it. Some slide text and builder strings still use stronger scientific wording than the revised documentation; see the [audit's remaining issues](REPOSITORY_REFERENCE_AUDIT.md#remaining-issues).

## 5. Remaining work

- Rewrite and review the English report section before submission; core analysis and slide integration are complete.
- Optional analyses listed in the root README remain optional and are not marked complete.
- Any future change to P5's fitted model or draw handoff would require a separately authorised P6 revalidation; no such rerun was performed in this documentation audit.
