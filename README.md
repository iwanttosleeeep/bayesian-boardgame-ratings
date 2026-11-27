# How Much Should We Shrink a Board Game Rating?

**STAT6106 Bayesian Data Analysis | Group project**  
**Working repository overview — updated 27 Nov 2026**

We examine Bayesian shrinkage of BoardGameGeek (BGG) average ratings, how assumptions influence adjusted scores and ranking uncertainty, and how our results compare with BGG's own adjusted-rating benchmark. M0, M1b and M2 support the central M1a shrinkage analysis.

**Key dates:** 28 Nov — freeze **presentation results**; 1 Dec — ~15-minute presentation; **18 Dec — final report, code and data**. The presentation freeze is not the final analysis deadline.

## Storyline — final version for the 1 Dec presentation (26 Nov)

This section is the agreed narrative for the presentation and the report. Every number below links to a committed file. Where the older status sections further down differ, **this section and its linked files take precedence**.

**Central conclusion.** Under **M1a Extended**, the median effective shrinkage estimate is **3.02 pseudo-votes** across 21,375 SD-matched games. This is a model-dependent estimate, not a uniquely identified or universally optimal amount of shrinkage. A fitted constant-m approximation to BGG's adjusted score, assuming a target of **5.5**, gives **1,874** pseudo-votes (about **1,900**); it does not identify BGG's official algorithm. The comparison illustrates that statistical rating estimation and public ranking design can answer different questions.

### Presentation running order (12 minutes, every member speaks once)

The deck is [`slides/Group_deck_draft.pptx`](slides/Group_deck_draft.pptx), built by [`code/P6/04_make_group_deck.py`](code/P6/04_make_group_deck.py). It contains **15 main slides and 4 backup slides**. Speaker labels are on each slide; caveats and prepared answers are in the speaker notes.

| Order | Speaker | Time | Slides | Content |
| --- | --- | --- | --- | --- |
| 1 | P1 | 2 min | 2–4 | Act I: the question, rating-count patterns, BGG's ≈1,900 dummy votes |
| 2 | P2 | 1.5 min | 5–6 | Act II: model overview; M0 misses the variance pattern (three-method check in one line) |
| 3 | P5 | 3 min | 7–9 | Acts II–III: s not identified from averages; Extended median ≈3 pseudo-votes; prediction cannot choose the variance split |
| 4 | P4 | 2 min | 10–11 | Act IV: smaller shrinkage with real SDs; designer and covariate effects |
| 5 | P3 | 1.5 min | 12 | Act IV: what drives the number of ratings; the wargame pattern |
| 6 | P6 | 2 min | 13–15 | Act V: ranking uncertainty, top-ten divergence, conclusion |
| — | — | — | B1–B4 | Backup: sensitivity, WAIC, M0 three ways, holdout PPC |

### Act I — The ranking problem

- A fitted constant-m approximation to BGG's adjusted score, assuming a target of **5.5**, adds **1,874** dummy votes to every game (RMSE 0.020; 20,694 games) — [`outputs/P6/bgg_benchmark_summary.csv`](outputs/P6/bgg_benchmark_summary.csv). This fit does not verify BGG's official algorithm.
- In the data, games with more ratings have higher averages (6.19 for 30–40 ratings to 7.22 for 5,000+) and smaller spread (variance 1.172 to 0.365) — [`tables/ppc_grouped_summary.csv`](tables/ppc_grouped_summary.csv), 6,489 development games.
- Question: how much should an average rating be shrunk, statistically?

### Act II — Why simple shrinkage is not enough

- **M0** (regression, no measurement error) cannot reproduce the fall in variance with rating count — grouped PPC in [`tables/ppc_grouped_summary.csv`](tables/ppc_grouped_summary.csv).
- **M1a Baseline**: the rater SD `s` sits at its prior upper bound (2.96), giving m ≈ 11.6 — [`outputs/P5/M1a_Baseline/parameter_summary.csv`](outputs/P5/M1a_Baseline/parameter_summary.csv).
- **M1b Baseline**: `s` = 2.98, also at the bound; widening the prior to U(0.5, 6) moves it to 4.03 and raises the median adjustment by 78% — [`outputs/P4/README.md`](outputs/P4/README.md).
- **Message:** with averages only, the data cannot separate rater noise from genuine between-game spread. m ≈ 11.6 is a **diagnostic intermediate result** showing weak identification and prior dependence, not an alternative answer.

### Act III — Separating noise from heterogeneity

- External information: each game's historical rating SD (median **1.49**; rating counts match the 2022 data closely, median ratio 0.998, but the snapshot date is unverified) — [`outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv`](outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv).
- **M1a Extended** (per-game SD; mean and between-game SD vary with log rating count): model-dependent median effective pseudo-votes **3.02** (IQR 2.36–3.84) over 21,375 SD-matched games — [`outputs/P6/ranking_model_effective_m.csv`](outputs/P6/ranking_model_effective_m.csv). On the 6,416 development games, scaling the SD by 0.8 or 1.2 gives a median of 1.93 to 4.47 — [`outputs/P5/Sensitivity_Analysis/External_SD/`](outputs/P5/Sensitivity_Analysis/External_SD/). The tested alternative priors on the mean and variance parameters have negligible effect.
- Exploratory holdout (3,209 games): Extended beats Baseline by **ΔELPD 221.7** (cluster SE 20.6) — [`outputs/P5/Holdout_Comparison_3209/`](outputs/P5/Holdout_Comparison_3209/). PPC: development 4/4 groups, holdout 3/4.
- **Key point:** in M1b, replacing `s` with the external SD shows no predictive gain (ΔELPD −15.1, SE 8.3, approximate 95% interval −31.4 to 1.3). Predictive scores depend on the predictive mean and total variance; shrinkage depends on how that variance is split. **Predictive scores alone do not identify the variance split. External historical SD estimates (≈1.5) provide evidence supporting smaller observation-noise values than s ≈ 3, subject to the unverified snapshot date and the fixed plug-in assumption.** Extended changes the mean, the variance structure and the noise term together, so its predictive gain is not attributed to any one of them.

### Act IV — What explains ratings and popularity?

- **M1b-ExternalSD** (6,416 games) predicts far better than M1a Extended (ΔELPD 1,101, SE 54). Designer effects account for about half of the **residual latent-rating variance** (σ_d 0.464, τ 0.473) — [`outputs/P4/ExternalSD_6416/comparison/scales.csv`](outputs/P4/ExternalSD_6416/comparison/scales.csv).
- Conditional effects on true rating — [`outputs/P4/ExternalSD_6416/comparison/coefficients.csv`](outputs/P4/ExternalSD_6416/comparison/coefficients.csv): log(1+age) −0.38 per SD; log playing time +0.16 per SD; log rating count +0.21 per SD; wargame +0.26, miniatures +0.40, roll-and-move −0.33, uncredited designer −0.33 (rating points, indicators).
- **M2** (19,440 games; NB decisively preferred over Poisson, residual PPC misfit remains) — [`tables/P3/`](tables/P3/): conditional rate ratios for the number of ratings: wargame 0.23, economic 3.13, deduction 2.67, party 1.79; log(1+age) 1.53 per SD.
- **Link to the story:** wargames are rated higher yet attract far fewer raters. This pattern is **consistent with** niche games being rated mainly by enthusiasts; it does not establish a self-selection mechanism.

### Act V — Rethinking the rankings

- Ranking 21,375 SD-matched games in each of 500 joint posterior draws under M1a Extended — [`outputs/P6/`](outputs/P6/): our top 10 has a median of **46 ratings** versus **25,535** for BGG's; top-10 overlap 0, top-50 overlap 1; Spearman 0.78 over the whole list; median 90% rank interval for top-10 candidates ≈ 71 places; 6 games have P(top 10) > 0.5.
- Interpretation: under M1a Extended's mean, latent-variance and historical-SD assumptions, games with few, very favourable ratings can reach the top. The larger shrinkage in the fitted BGG approximation may reflect other goals (stable rankings, resistance to strategic voting); our data cannot test that. Neither ranking is "wrong": they answer different questions.
- Prepared answer to "why rank with M1a Extended, not M1b?": M1a Extended uses rating count and game-specific historical SD for shrinkage; its target and latent variance also vary with rating count. M1b uses additional game covariates and designer effects to define its target. The fitted BGG benchmark assumes a fixed target of 5.5, so this is a comparison of different shrinkage assumptions rather than identical rules.

### Methods woven through the acts

- **M0, three ways:** JAGS, hand-written Gibbs and mean-field CAVI agree (maximum posterior-mean gap 0.000303; CAVI 95% widths 0.98–1.01 × Gibbs) — [`tables/M0_three_method_comparison.csv`](tables/M0_three_method_comparison.csv).
- **Model comparison:** exploratory holdout ELPD on 3,209 games is primary; WAIC is secondary because 13.4% (M1b Baseline) and 14.8% (M1b-ExternalSD) of games have pointwise p_WAIC > 0.4 — [`outputs/P5/WAIC_Comparison_6416/`](outputs/P5/WAIC_Comparison_6416/).
- **Prior sensitivity:** the `s` prior in M1a/M1b Baseline (Act II), external-SD scaling (Act III), and M2 prior widths ([`tables/P3/M2_prior_sensitivity.csv`](tables/P3/M2_prior_sensitivity.csv)).

### Wording rules

- Self-selection: "consistent with", never "shows" or "confirms".
- m ≈ 11.6: Baseline diagnostic of weak identification and prior sensitivity. m ≈ 3.02: the model-dependent median effective estimate under M1a Extended, not a unique or universal optimum. 1,874: a fitted constant-m approximation assuming a target of 5.5, not a verified official BGG algorithm.
- 1.93–4.47 is an SD-scaling sensitivity range on 6,416 games, not a credible interval.
- Designer share is of residual latent variance under M1b's assumptions, not of all rating variation. M2 rate ratios are conditional on the other covariates.
- The holdout was consulted during exploration: all holdout results are exploratory. Rankings cover the 21,375 SD-matched games, not the whole BGG catalogue.

### Not added before the presentation (optional, by 6 Dec)

- M0 refitted on the same 6,416 games and scored on the same 3,209 holdout games (P2).
- M1b-ExternalSD with between-game SD varying with rating count (P4); requires fresh diagnostics, PPC and holdout scoring, and its superiority cannot be assumed.
- Earlier exploratory models (A–F, Student-t), P4 resource and simulation checks, and the 6,489-game WAIC table move to the appendix; their substantive limitations stay in the main text.

## Repository guide

Current structure and entry points as of **27 November 2026**. The [archive index](archive/README.md) records superseded P5 comparisons without discarding their evidence.

| Folder / owner | Key file or entry point | Contents |
| --- | --- | --- |
| Root and `code/P1/` — P1 | [P1 script index](code/P1/README.md), [grouped PPC](code/P1/06_grouped_ppc_m0_m1a.R) | Root data-preparation scripts and four shared CSVs; EDA and grouped M0/M1a PPC |
| `code/P2/`, `outputs/P2/` — P2 | [M0 workflow](code/P2/README.md), [CAVI runner](code/P2/M0_cavi_run.R) | Gibbs/JAGS/CAVI inference, diagnostics and shared likelihoods |
| `code/P3/`, `outputs/P3/` — P3 | [M2 workflow](code/P3/README.md), [handoff](docs/P3_HANDOFF.md), [reproduction guide](docs/P3_REPRODUCE.md) | Truncated Poisson/NB popularity models, posteriors, PPC and sensitivity |
| `code/P4/`, `outputs/P4/` — P4 | [ExternalSD delivery](docs/P4_EXTERNALSD.md), [holdout results](outputs/P4/Holdout_3209/README.md) | M1b Baseline/ExternalSD, diagnostics, sensitivity, resources and comparison evidence |
| `code/P5/`, `outputs/P5/` — P5 | [P5 results index](outputs/P5/README.md), [four-model holdout script](code/P5/14_Compare_Four_Models_Holdout_3209.R) | Current `M1a_Baseline/`, `M1a_Extended_ExternalSD/`, `WAIC_Comparison_6416/`, `Holdout_Comparison_3209/`, `Sensitivity_Analysis/` and `P6_Full_Handoff/` |
| `code/P6/`, `outputs/P6/`, `slides/` — P6 | [Ranking results](outputs/P6/README.md), [group deck builder](code/P6/04_make_group_deck.py) | BGG benchmark, posterior ranking uncertainty and the [group deck](slides/Group_deck_draft.pptx) (15 main + 4 backup slides) |
| `data/raw/` — P5 source | [Frozen historical source and checksums](data/raw/README.md), [original CSV](data/raw/historical_games.csv) | Original historical rating-SD snapshot; 21,925 records, available for Scripts 01/04/11; collection date remains unverified |
| `figures/`, `tables/` | [Figure index](figures/README.md), [table index](tables/README.md) | Committed EDA, model, diagnostic and presentation artifacts, including member subfolders |
| `docs/` | [Data guide](docs/P1_DATA_GUIDE.md), [24 Nov status record](docs/TEAM_PLAN_AND_STATUS.md) | Handoffs, reproduction instructions and methodological evidence; this README is the current team status source |
| `archive/` | [Archive index](archive/README.md) | Superseded P5 results, with working references for scripts that still need them |

**P1's data-preparation scripts 01–04 and the four shared CSVs remain at the repository root** for compatibility; the dictionary script is now [04_variable_dictionary.R](04_variable_dictionary.R). Scripts [05 (EDA)](code/P1/05_eda.R) and [06 (grouped PPC)](code/P1/06_grouped_ppc_m0_m1a.R) resolve inputs relative to the repository and write to `figures/` and `tables/`. P4's evidence remains at its established paths. See the [reference audit](docs/REPOSITORY_REFERENCE_AUDIT.md) for verified fixes and remaining original-source requirements; [reproduction instructions](docs/REPRODUCTION.md) distinguish read-only checks from optional fitting.

## Fixed data contract

| Root file | Size | Correct use |
| --- | ---: | --- |
| [data_clean.csv](data_clean.csv) | 21,631 games × 83 columns | Full cleaned/engineered BGG table |
| [variable_dictionary.csv](variable_dictionary.csv) | 83 fields | Variable definitions, types and missingness |
| [dev_subsample.csv](dev_subsample.csv) | 6,489 games | **Development / fitting** for the common M0/M1a/M1b WAIC comparison |
| [comparison_sample.csv](comparison_sample.csv) | 3,244 games | **Game-disjoint holdout; do not use to fit the models being evaluated** |

The game-level split uses seed **20261122** and has no overlapping game IDs, but **912 designer IDs** appear in both subsets. Thus, it is **not** a split by previously unseen designer. The historical 20 Nov plan described a different split; the implemented data contract above is authoritative for current scripts.

**Separate M1a experiment:** Baseline versus External-SD Extended uses **6,416** historical-SD-matched development games and **3,209** matched holdout games. The holdout was consulted during earlier model exploration, so results from this exercise are **exploratory**, not a pristine untouched test set. These subsets are not global BGG ranking populations.

Current comparisons are in [6,416-game WAIC](outputs/P5/WAIC_Comparison_6416/) and [3,209-game exploratory holdout](outputs/P5/Holdout_Comparison_3209/); **holdout ELPD is primary**, with WAIC secondary.

## Team status — 27 November 2026

All six members have completed their core analytical deliverables. The assembled group deck has **15 main slides and 4 backup slides** and follows the agreed running order above. Report writing, optional extensions and final submission checks remain; optional analyses are not marked complete.

| Member | Delivered | Main output folder(s) |
| --- | --- | --- |
| **P1** | Shared data, EDA and grouped M0/M1a PPC | [tables/](tables/) and [figures/](figures/); four data CSVs at root |
| **P2** | M0 Gibbs/JAGS/CAVI, diagnostics and three-method comparison | [outputs/P2/](outputs/P2/); comparison tables in [tables/](tables/) |
| **P3** | M2 Poisson/NB, PPC, sensitivity and handoff | [outputs/P3/](outputs/P3/), [tables/P3/](tables/P3/), [figures/P3/](figures/P3/) |
| **P4** | M1b Baseline/ExternalSD, holdout, sensitivity and presentation figures | [outputs/P4/](outputs/P4/) and [figures/P4/presentation/](figures/P4/presentation/) |
| **P5** | M1a Baseline/Extended, holdout, WAIC, sensitivity and ranking-draw handoff | [outputs/P5/](outputs/P5/) and [figures/P5/](figures/P5/) |
| **P6** | BGG benchmark, ranking uncertainty and integrated group deck | [outputs/P6/](outputs/P6/), [figures/P6/](figures/P6/), [slides/](slides/) |

## Model naming

| Model | Summary | Owner |
| --- | --- | --- |
| **M0** | Bayesian regression on average rating; hand-written Gibbs, JAGS and mean-field CAVI | P2 |
| **M1a Baseline** | Intercept-only Normal hierarchical shrinkage; constant between-game spread and shared unknown rating SD | P5 |
| **M1a Extended** | Historical per-game SD plug-in; mean and latent spread vary with log rating count | P5 |
| **M1b Baseline** | Hierarchical shrinkage with covariates, log rating count, designer effects and shared unknown rating SD | P4 |
| **M1b-ExternalSD** | M1b with historical per-game SD replacing the shared unknown rating SD | P4 |
| **M2** | Number of ratings: left-truncated Poisson versus negative binomial | P3 |

M2 concerns **rating counts**, so its WAIC must not be compared with rating-model WAIC. M1a Extended changes several assumptions together; its predictive gain cannot be attributed solely to the SD plug-in. Rankings on the 6,416 development games are within-sample; P6's ranking uses the separate 21,375-game SD-matched handoff.

## Next checkpoints

| Date | Planned handoff |
| --- | --- |
| **28 Nov** | Freeze presentation results, verify evidence and select final figures and wording |
| **29–30 Nov** | Rehearse the agreed 12-minute running order and check the assembled deck |
| **1 Dec** | Group presentation |
| **By 6 Dec** | Optional report extensions listed in the storyline above, with fresh diagnostics and scoring if undertaken |
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
