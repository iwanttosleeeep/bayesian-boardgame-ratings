# How Much Should We Shrink a Board Game Rating?

**STAT6106 Bayesian Data Analysis | Group project**  
**Working repository overview — updated 24 Nov 2026**

We examine Bayesian shrinkage of BoardGameGeek (BGG) average ratings, how assumptions influence adjusted scores and ranking uncertainty, and how our results compare with BGG's own adjusted-rating benchmark. M0, M1b and M2 support the central M1a shrinkage analysis.

**Key dates:** 28 Nov — freeze **presentation results**; 1 Dec — ~15-minute presentation; **18 Dec — final report, code and data**. The presentation freeze is not the final analysis deadline.

## Storyline — final version for the 1 Dec presentation (26 Nov)

This section is the agreed narrative for the presentation and the report. Every number below links to a committed file. Where the older status sections further down differ, **this section and its linked files take precedence**.

**Central conclusion.** Under our extended Bayesian model, sampling uncertainty in average ratings implies a median effective shrinkage of about **3 pseudo-votes**, compared with about **1,900** under a constant-weight approximation to BGG's adjusted score. The gap shows that statistical estimation of a game's rating and the design of a public ranking answer different questions.

### Presentation running order (12 minutes, every member speaks once)

The deck is [`slides/Group_deck_draft.pptx`](slides/Group_deck_draft.pptx), built by [`code/P6/04_make_group_deck.py`](code/P6/04_make_group_deck.py). Speaker labels are on each slide; caveats and prepared answers are in the speaker notes.

| Order | Speaker | Time | Slides | Content |
| --- | --- | --- | --- | --- |
| 1 | P1 | 2 min | 2–4 | Act I: the question, rating-count patterns, BGG's ≈1,900 dummy votes |
| 2 | P2 | 1.5 min | 5–6 | Act II: model overview; M0 misses the variance pattern (three-method check in one line) |
| 3 | P5 | 3 min | 7–9 | Acts II–III: s not identified from averages; measured SDs give ≈3 pseudo-votes; prediction cannot choose the variance split |
| 4 | P4 | 2 min | 10–11 | Act IV: smaller shrinkage with real SDs; designer and covariate effects |
| 5 | P3 | 1.5 min | 12 | Act IV: what drives the number of ratings; the wargame pattern |
| 6 | P6 | 2 min | 13–15 | Act V: ranking uncertainty, top-ten divergence, conclusion |
| — | — | — | B1–B4 | Backup: sensitivity, WAIC, M0 three ways, holdout PPC |

### Act I — The ranking problem

- BGG's adjusted score is well approximated by adding **1,874** dummy votes at 5.5 to every game (RMSE 0.020; 20,694 games) — [`outputs/P6/bgg_benchmark_summary.csv`](outputs/P6/bgg_benchmark_summary.csv). This is a fitted approximation, not BGG's published algorithm.
- In the data, games with more ratings have higher averages (6.19 for 30–40 ratings to 7.22 for 5,000+) and smaller spread (variance 1.172 to 0.365) — [`tables/ppc_grouped_summary.csv`](tables/ppc_grouped_summary.csv), 6,489 development games.
- Question: how much should an average rating be shrunk, statistically?

### Act II — Why simple shrinkage is not enough

- **M0** (regression, no measurement error) cannot reproduce the fall in variance with rating count — grouped PPC in [`tables/ppc_grouped_summary.csv`](tables/ppc_grouped_summary.csv).
- **M1a Baseline**: the rater SD `s` sits at its prior upper bound (2.96), giving m ≈ 11.6 — [`outputs/P5/M1a_Baseline/parameter_summary.csv`](outputs/P5/M1a_Baseline/parameter_summary.csv).
- **M1b Baseline**: `s` = 2.98, also at the bound; widening the prior to U(0.5, 6) moves it to 4.03 and raises the median adjustment by 78% — [`outputs/P4/README.md`](outputs/P4/README.md).
- **Message:** with averages only, the data cannot separate rater noise from genuine between-game spread. m ≈ 11.6 is a **diagnostic intermediate result** showing weak identification and prior dependence, not an alternative answer.

### Act III — Separating noise from heterogeneity

- External information: each game's historical rating SD (median **1.49**; rating counts match the 2022 data closely, median ratio 0.998, but the snapshot date is unverified) — [`outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv`](outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv).
- **M1a Extended** (per-game SD; mean and between-game SD vary with log rating count): median effective pseudo-votes **3.02** (IQR 2.36–3.84) over 21,375 SD-matched games — [`outputs/P6/ranking_model_effective_m.csv`](outputs/P6/ranking_model_effective_m.csv). On the 6,416 development games, scaling the SD by 0.8 or 1.2 gives a median of 1.93 to 4.47 — [`outputs/P5/Sensitivity_Analysis/External_SD/`](outputs/P5/Sensitivity_Analysis/External_SD/). Priors on the mean and variance parameters have negligible effect.
- Exploratory holdout (3,209 games): Extended beats Baseline by **ΔELPD 221.7** (cluster SE 20.6) — [`outputs/P5/Holdout_Comparison_3209/`](outputs/P5/Holdout_Comparison_3209/). PPC: development 4/4 groups, holdout 3/4.
- **Key point:** in M1b, replacing `s` with the external SD shows no predictive gain (ΔELPD −15.1, SE 8.3, approximate 95% interval −31.4 to 1.3). Predictive scores depend on the predictive mean and total variance; shrinkage depends on how that variance is split. **Prediction cannot choose the split — the measured rater SDs (≈1.5) are what rule out s ≈ 3.** Extended changes the mean, the variance structure and the noise term together, so its predictive gain is not attributed to any one of them.

### Act IV — What explains ratings and popularity?

- **M1b-ExternalSD** (6,416 games) predicts far better than M1a Extended (ΔELPD 1,101, SE 54). Designer effects account for about half of the **residual latent-rating variance** (σ_d 0.464, τ 0.473) — [`outputs/P4/ExternalSD_6416/comparison/scales.csv`](outputs/P4/ExternalSD_6416/comparison/scales.csv).
- Conditional effects on true rating — [`outputs/P4/ExternalSD_6416/comparison/coefficients.csv`](outputs/P4/ExternalSD_6416/comparison/coefficients.csv): log(1+age) −0.38 per SD; log playing time +0.16 per SD; log rating count +0.21 per SD; wargame +0.26, miniatures +0.40, roll-and-move −0.33, uncredited designer −0.33 (rating points, indicators).
- **M2** (19,440 games; NB decisively preferred over Poisson, residual PPC misfit remains) — [`tables/P3/`](tables/P3/): conditional rate ratios for the number of ratings: wargame 0.23, economic 3.13, deduction 2.67, party 1.79; log(1+age) 1.53 per SD.
- **Link to the story:** wargames are rated higher yet attract far fewer raters. This pattern is **consistent with** niche games being rated mainly by enthusiasts; it does not establish a self-selection mechanism.

### Act V — Rethinking the rankings

- Ranking 21,375 SD-matched games in each of 500 joint posterior draws under M1a Extended — [`outputs/P6/`](outputs/P6/): our top 10 has a median of **46 ratings** versus **25,535** for BGG's; top-10 overlap 0, top-50 overlap 1; Spearman 0.78 over the whole list; median 90% rank interval for top-10 candidates ≈ 71 places; 6 games have P(top 10) > 0.5.
- Interpretation: shrinking only for sampling noise lets games with few, very favourable ratings reach the top. BGG's much larger shrinkage may serve other goals (stable rankings, resistance to strategic voting); our data cannot test that. Neither ranking is "wrong": they answer different questions.
- Prepared answer to "why rank with M1a Extended, not M1b?": M1a Extended shrinks only by rating count, the same kind of rule as BGG's, so the comparison is direct. M1b shrinks toward a designer- and feature-based prediction, a different target. Note also that M1a Extended's target varies with rating count, whereas BGG's is fixed at 5.5.

### Methods woven through the acts

- **M0, three ways:** JAGS, hand-written Gibbs and mean-field CAVI agree (maximum posterior-mean gap 0.000303; CAVI 95% widths 0.98–1.01 × Gibbs) — [`tables/M0_three_method_comparison.csv`](tables/M0_three_method_comparison.csv).
- **Model comparison:** exploratory holdout ELPD on 3,209 games is primary; WAIC is secondary because 13.4% (M1b Baseline) and 14.8% (M1b-ExternalSD) of games have pointwise p_WAIC > 0.4 — [`outputs/P5/WAIC_Comparison_6416/`](outputs/P5/WAIC_Comparison_6416/).
- **Prior sensitivity:** the `s` prior in M1a/M1b Baseline (Act II), external-SD scaling (Act III), and M2 prior widths ([`tables/P3/M2_prior_sensitivity.csv`](tables/P3/M2_prior_sensitivity.csv)).

### Wording rules

- Self-selection: "consistent with", never "shows" or "confirms".
- m ≈ 11.6: diagnostic of weak identification, not an answer. 1,874: a constant-m approximation, not BGG's algorithm.
- 1.93–4.47 is an SD-scaling sensitivity range on 6,416 games, not a credible interval.
- Designer share is of residual latent variance under M1b's assumptions, not of all rating variation. M2 rate ratios are conditional on the other covariates.
- The holdout was consulted during exploration: all holdout results are exploratory. Rankings cover the 21,375 SD-matched games, not the whole BGG catalogue.

### Not added before the presentation (optional, by 6 Dec)

- M0 refitted on the same 6,416 games and scored on the same 3,209 holdout games (P2).
- M1b-ExternalSD with between-game SD varying with rating count (P4); requires fresh diagnostics, PPC and holdout scoring, and its superiority cannot be assumed.
- Earlier exploratory models (A–F, Student-t), P4 resource and simulation checks, and the 6,489-game WAIC table move to the appendix; their substantive limitations stay in the main text.

## Repository guide

| Where | What you will find |
| --- | --- |
| **[P1 data guide](docs/P1_DATA_GUIDE.md)** | Four shared CSVs, cleaning/sampling scripts, training and holdout contract |
| **[P1 EDA figures](figures/README.md)** and **[summary statistics](tables/eda_descriptive_summary.csv)** | Ten EDA PNGs and a descriptive table (committed 23 Nov) |
| **[P1 original technical notes](docs/P1_PIPELINE_NOTES_2026-11-22.md)** | Detailed data preparation and reproducibility notes |
| **[Team plan and progress](docs/TEAM_PLAN_AND_STATUS.md)** | P1–P6 status, remaining handoffs, checkpoints and limitations |
| **[P2 M0 code](code/P2/README.md)** | Gibbs/JAGS code, development-sample inference and shared likelihoods |
| **[P3 M2 workflow](code/P3/README.md)** and **[handoff](docs/P3_HANDOFF.md)** | Truncated Poisson/NB models, PPC, comparisons and report-generation instructions; [PR #4 merged](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/4) |
| **[P4 M1b delivery](docs/P4_DELIVERY.md)** and **[WAIC handoff](outputs/P4/M1b_WAIC_6489/README.md)** | Full development fit, diagnostics, sensitivity, shared likelihood; [PR #1](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/1) and [PR #2](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/2) merged |
| **[P5 results](outputs/P5/README.md)** | M1a Baseline and External-SD extension; exploratory holdout, PPC and sensitivity |
| **[P5 6,489-game M1a refit](archive/outputs/P5/M1a_WAIC_6489/)** | Matched-game Baseline likelihood and diagnostic artifacts (RDS uploaded; older folder README has a stale pending note) |
| **[P5 three-model WAIC comparison](archive/outputs/P5/WAIC_Comparison_6489/README.md)** | Final same-game WAIC/ΔWAIC tables, paired SE, M0 Gibbs/JAGS check and interpretation safeguards |
| **[P5 R scripts](code/P5/)** | Numbered workflow, including the [matched-WAIC script](code/P5/10_Compare_M0_M1a_M1b_WAIC_6489.R) |

**P1's original scripts and CSVs remain at the repository root** for compatibility; the P1 index is [here](code/P1/README.md). The current EDA script has a machine-specific input/output path and needs a relative-path adjustment for a clean-clone rerun; the resulting figures are committed.

## Fixed data contract

| Root file | Size | Correct use |
| --- | ---: | --- |
| [data_clean.csv](data_clean.csv) | 21,631 games × 83 columns | Full cleaned/engineered BGG table |
| [variable_dictionary.csv](variable_dictionary.csv) | 83 fields | Variable definitions, types and missingness |
| [dev_subsample.csv](dev_subsample.csv) | 6,489 games | **Development / fitting** for the common M0/M1a/M1b WAIC comparison |
| [comparison_sample.csv](comparison_sample.csv) | 3,244 games | **Game-disjoint holdout; do not use to fit the models being evaluated** |

The game-level split uses seed **20261122** and has no overlapping game IDs, but **912 designer IDs** appear in both subsets. Thus, it is **not** a split by previously unseen designer. The historical 20 Nov plan described a different split; the implemented data contract above is authoritative for current scripts.

**Same-game rating-model WAIC is now computed:** M0 (JAGS primary, Gibbs as sampler check), M1a (a separate Baseline refit), and M1b use the same **6,489 ordered development game IDs**, with 500 posterior log-likelihood draws per model. The results are in [P5's WAIC comparison](archive/outputs/P5/WAIC_Comparison_6489/README.md); they are not holdout validation, and different designer-conditioning conventions limit generalization of the numerical ordering.

**Separate M1a experiment:** Baseline versus External-SD Extended uses **6,416** historical-SD-matched development games and **3,209** matched holdout games. The holdout was consulted during earlier model exploration, so results from this exercise are **exploratory**, not a pristine untouched test set. These subsets are not global BGG ranking populations.

## Team ownership and current GitHub status

**Verified GitHub status as of 24 Nov 2026.** A missing repository artifact does **not** prove a teammate has not worked locally. See the [detailed progress record](docs/TEAM_PLAN_AND_STATUS.md).

| Owner | Responsibility | Verified delivery and remaining work |
| --- | --- | --- |
| **P1** | Data preparation, EDA, M0/M1 grouped PPC | **Data pipeline and 4 CSVs delivered; 10 EDA PNGs and descriptive table committed.** Model-specific grouped PPC handoff not yet verified. |
| **P2** | M0 Bayesian regression (Gibbs/JAGS/CAVI); runtime comparison | **Development-aligned M0 Gibbs/JAGS posterior, diagnostics, IDs and two 500 × 6,489 likelihood RDS files delivered.** Same-model WAIC differs by ~0.020 across samplers. CAVI and independent M1b runtime comparison not yet verified. |
| **P3** | M2 popularity: left-truncated Poisson/NB | **[PR #4 merged](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/4):** 19,440 complete-case games, code, posterior, PPC, diagnostics, sensitivity and comparison tables. NB preferred numerically; residual PPC mismatch remains. Presentation content to integrate. |
| **P4** | M1b covariates and designer random effects | **[PR #1](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/1) and [PR #2](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/2) merged:** 6,489-game Baseline and s-upper-6 sensitivity, PPC/diagnostic figures, and shared WAIC likelihood. Full joint posterior remains local; final slide selection/interpretation pending. |
| **P5** | M1a shrinkage, external SD, robustness and model comparison | **Baseline/Extended, exploratory holdout, PPC, SD/prior sensitivity, latent draws for P6, separate 6,489-game refit, and [M0/M1a/M1b WAIC comparison](archive/outputs/P5/WAIC_Comparison_6489/README.md) delivered.** Final presentation/report section to assemble. |
| **P6** | BGG benchmark, posterior rank uncertainty, integration | **No P6-owned ranking/benchmark or slides deliverables verified in main.** P5 latent draw handoff is available; confirm first results and coordination of slides. |

## Model naming

| Model | Summary | Owner |
| --- | --- | --- |
| **M0** | Bayesian regression on average rating; hand-written Gibbs and JAGS | P2 |
| **M1a Baseline** | Intercept-only Normal hierarchical shrinkage; constant between-game spread and shared unknown rating SD | P5 |
| **M1a Extended — External SD** | Historical per-game SD plug-in; mean and latent spread vary with log rating count | P5 |
| **M1b** | Hierarchical shrinkage with covariates, log rating count and designer effects | P4 |
| **M2** | Number of ratings: left-truncated Poisson versus negative binomial | P3 |

### Matched-game WAIC — completed 24 Nov

The same 6,489 development games and 500 shared log-likelihood draws per fit were used for the M0/M1a/M1b comparison. The primary M0 is JAGS; Gibbs verifies the same statistical model.

| Rating model | WAIC (lower numerically) | ΔWAIC vs M1b | pWAIC |
| --- | ---: | ---: | ---: |
| **M1b** | **11,939.468** | **0** | **1,345.704** |
| M0 (JAGS) | 14,399.379 | 2,459.911 | 10.834 |
| M1a Baseline (6,489-game refit) | 17,496.148 | 5,556.681 | 2.239 |

**Important reliability/target warning:** M1b has **888 / 6,489** pointwise pWAIC values above 0.4 (maximum **8.082**). Its game latent ratings are integrated out, but likelihoods for named designers **condition on effects estimated from training games**. M0 has no game latent effect; M1a integrates the game effect and has no designer term. The numerical WAIC ordering is **not** a definitive comparison of new-designer prediction, and it cannot attribute differences to any one modelling feature. These are development-sample WAIC estimates, not independent holdout scores. [See full comparison, paired standard errors and warnings](archive/outputs/P5/WAIC_Comparison_6489/README.md).

M2 concerns **rating counts**, not average ratings, so **do not compare M2 WAIC to these rating-model WAICs**. External-SD M1a also changes several model assumptions together; its exploratory holdout improvement cannot be attributed solely to the SD plug-in. Rankings from 6,416 matched games are **within-sample**, not global BGG rankings.

## Next checkpoints

| Date | Planned handoff |
| --- | --- |
| **24 Nov** | **P1 data/EDA, P2 Gibbs/JAGS, P3 M2, P4 M1b/WAIC, P5 shrinkage and matched WAIC already delivered.** P6 ranking/benchmark handoff still unverified. |
| **26–27 Nov** | P6 initial BGG benchmark and ranking uncertainty; P1 grouped model PPC if in scope; P2/P4/P5 presentation-ready figures and concise findings |
| **28 Nov** | **Freeze 1 Dec presentation results:** reproduce numbers, choose figures, capture limitations, collect every owner’s slide text |
| **29–30 Nov** | Assemble ~15-minute slides, check against saved results and rehearse |
| **1 Dec** | Progress presentation |
| **By 6 Dec** | Remaining optional/final-report analysis (e.g. P2 CAVI, deeper diagnostics/PSIS-LOO if justified, P6 ranking), **not** the already completed matched WAIC or P4 prior sensitivity |
| **10 Dec** | Individual English report sections |
| **14–16 Dec** | Complete draft, evidence/citation checks, revision and accessibility/layout review |
| **18 Dec** | Final PDF report (≤20 pages excluding appendix), reproducible code/data submission |

## Working rules and limitations

- Keep *training* and *holdout* distinct. Report models' game-ID sets, priors, seeds, diagnostics, and which results have actually been fitted and verified.
- Current P1 features were standardized and high-frequency categories selected **before** splitting on the full merged dataset. For strict leakage-free assessment, preprocessing rules should be fit on training data; report this limitation rather than silently changing existing samples.
- P4's conditional designer-effect scoring should not be presented as unseen-designer prediction; the game-level split includes some shared designers, and M1b WAIC has substantial pointwise reliability flags.
- External per-game SD is from a historical BGG snapshot with **unverified collection date** and is treated as a fixed plug-in value; M1a's `s` is not a well-identified individual-rater SD.
- Each member should understand, run, check and explain the model code and author their own English report contribution, consistent with course integrity requirements.

**Plan reconciliation:** The implemented game-level P1 development/holdout split differs from the designer-group development and nested WAIC comparison samples in the plan dated 20 Nov. This README documents *what is currently implemented*; it does **not** silently amend the original proposal or eliminate the need for the team to explain the selected design.
