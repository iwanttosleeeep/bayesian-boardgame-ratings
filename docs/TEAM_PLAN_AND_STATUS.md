# Team project plan and progress — P1–P6

**Verified repository status as of 24 November 2026**, reconciled against merged PRs and existing files. This records implementation status, **not a replacement for the original 20 Nov proposal**. “Not in repo” does not imply that a member has not worked locally.

## Ownership, evidence, next handoff

| Owner | Assigned responsibilities | Verified evidence at 24 Nov | Next output / dependency |
| --- | --- | --- | --- |
| **P1** | Clean/join data, feature engineering, dictionary and EDA; M0/M1 grouped PPC | Root data CSVs and pipeline; [10 EDA figures](../figures/README.md) and [descriptive table](../tables/eda_descriptive_summary.csv) committed 23 Nov | Provide/confirm model-specific PPC and select EDA slides; portable \`05_eda.R\` paths require cleanup |
| **P2** | M0 Normal Bayesian regression, JAGS/Gibbs/CAVI; M1b runtime comparison | 6,489 development IDs, shared Gibbs/JAGS posteriors, diagnostics and two [500-draw loglik files](../outputs/P2/); [M0 sampler WAIC agreement](../outputs/P5/WAIC_Comparison_6489/M0_Gibbs_vs_JAGS_check.csv) | Presentation-ready M0 findings/figure; CAVI and independent runtime comparison not yet verified (later phase if required) |
| **P3** | M2 rating-count Poisson vs truncated NB, PPC, WAIC and sensitivity | [PR #4 merged](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/4): code, 19,440-case fit, PPC plots, tables and [handoff](../P3_HANDOFF.md) | Select concise slides; retain marked NB PPC mismatch and full-sample (not holdout) caveat |
| **P4** | M1b covariates and designer random effects; partial pooling, diagnostics and sensitivity | [PR #1](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/1) and [PR #2](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/2) merged: 6,489-game fit, s-upper-6 sensitivity, diagnostic/PPC figures, 500 × 6,489 [likelihood handoff](../outputs/P4/M1b_WAIC_6489/README.md) | Prepare presentation figures and interpretation; full joint posterior RDS remains local; distinguish seen/new designer generalization |
| **P5** | M1a baseline and Extended External-SD, checks, holdout, prior/SD sensitivity and model comparison | 6,416-game matched Baseline/Extended, 3,209-game exploratory holdout, latent draws for P6, 6,489-game Baseline refit, [completed three-model WAIC](../outputs/P5/WAIC_Comparison_6489/README.md) and [script](../code/P5/10_Compare_M0_M1a_M1b_WAIC_6489.R) | 1–2 presentation slides and English report section; flag M1b WAIC diagnostic warnings; await requested P4 External-SD extension and aligned predictive comparison if feasible |
| **P6** | BGG pseudo-vote benchmark, posterior rank intervals/Top-10 probabilities, slide/report integration | No P6-owned artifacts or PR verified in main at this review; P5 full-scope handoff uploaded and owner-validated (21,375 games × 500 draws) | Confirm progress; benchmark preview by 26 Nov, initial rank-uncertainty figures by 27 Nov, coordinate slide integration |

## Dependencies (do not skip)

- **P1 → all:** [cleaned source](../data_clean.csv), [dictionary](../variable_dictionary.csv), [6,489-game development](../dev_subsample.csv), [3,244-game game-disjoint holdout](../comparison_sample.csv); [10 EDA plots](../figures/README.md) and [summary table](../tables/eda_descriptive_summary.csv) uploaded. M0/M1 **model PPC** is a separate outstanding item.
- **P2 → P5:** M0 development Gibbs/JAGS shared log-likelihood files, IDs, posterior and diagnostics delivered; CAVI is not required to compute the matched WAIC. [Gibbs-vs-JAGS WAIC check](../outputs/P5/WAIC_Comparison_6489/M0_Gibbs_vs_JAGS_check.csv) differs by ~0.020.
- **P3 → presentation/report:** Poisson versus NB for 19,440 complete-case games, left-truncation, PPC and sensitivity; [tables](../tables/P3/) and [plots](../figures/P3/) committed. M2 predicts **rating count**, not mean rating: never mix its WAIC with M0/M1a/M1b.
- **P4 → P5/P6:** 6,489 development M1b and s-upper-6 sensitivity completed; 500 × 6,489 likelihood [exported and merged](../outputs/P4/M1b_WAIC_6489/README.md). Full posterior/latent-draw RDS remain **local**, but the required WAIC share is uploaded. Named-designer effects are **conditioned on** for the comparison. [P4 summary and figures](../outputs/P4/README.md).
- **P5 → P1/P6:** 6,416 development and 3,209 exploratory holdout historical-SD-matched [model results](../outputs/P5/README.md); [Baseline latent draws](../outputs/P5/M1a_Baseline/) and [Extended latent draws](../outputs/P5/M1a_Extended_ExternalSD/) are in repo for P6's **within-sample** ranking; [matched three-model WAIC outputs](../outputs/P5/WAIC_Comparison_6489/README.md) uploaded with model-specific caveats.
- **P6 → all:** Benchmark against BGG's published adjusted average, posterior rank uncertainty/Top-10 probabilities and assembled presentation/report; no verified P6 handoff yet. Use the [full-scope handoff](../outputs/P5/P6_Full_Handoff/README.md) for ranking among 21,375 SD-matched games in the cleaned 2022 dataset; not a global BGG ranking.

## Dates and intended checkpoints

| Date | Milestone | Evidence / next requirement at 24 Nov |
| --- | --- | --- |
| **22 Nov** | Freeze P1 data | Delivered and documented |
| **23 Nov** | Early M1b implementation and P3 feasibility | P4 baseline/sensitivity merged in PR #1; P1 EDA committed |
| **24 Nov** | P5 latent draws, cross-team model inputs | P2 development Gibbs/JAGS, P3 final M2 PR #4, P4 WAIC PR #2 and P5 three-model WAIC delivered; P6 analysis not yet verified |
| **26 Nov** | Preliminary M0/M1b/M2, P1 EDA, P5 sensitivity, P6 benchmark | Model-side analytical milestones largely delivered; confirm P6 preliminary BGG benchmark and finalize figures |
| **27 Nov** | Model PPC, P6 initial ranking | P1 grouped PPC still to confirm; P6 rank-uncertainty outputs expected |
| **28 Nov** | **Freeze 1 Dec presentation results** | All: figures, concise findings, limitations and slide text; resolve P6 dependency |
| **29–30 Nov** | Integrate and rehearse | P6 coordinates presentation; cross-check numbers and claims |
| **1 Dec** | ~15-minute progress presentation | All |
| **By 6 Dec** | Post-presentation extensions as justified | CAVI, additional diagnostics/PSIS-LOO or fuller ranking work if needed. **Matched WAIC and P4 s-prior sensitivity are already complete.** |
| **10 Dec** | Individual English report sections | Each owner |
| **14–16 Dec** | Full draft, review and corrections | P6 + all |
| **18 Dec** | Final PDF report (≤20 pages excluding appendix), code/data | Designated submitter |

## Sampling and modeling rules that have changed since the 20 Nov plan

1. **Actual P1 split:** 6,489 game-random development rows and 3,244 game-disjoint holdout rows (seed 20261122); **912 designers overlap**. The original plan's designer-group sampling and nested WAIC comparison sample were not used.
2. **M0/M1a/M1b matched WAIC is now done:** P2/P4/P5 supplied 500 × 6,489 finite pointwise log-likelihoods in exactly matching ordered game IDs. [P5 result tables](../outputs/P5/WAIC_Comparison_6489/README.md): M1b 11,939.468; M0 JAGS 14,399.379; M1a Baseline 17,496.148. Gibbs/JAGS M0 WAIC differs by ~0.020. These are **development WAIC**, not independent holdout scores.
3. **WAIC diagnostic/target caution:** M1b's pointwise pWAIC exceeds 0.4 for **888 / 6,489** games (max 8.082), making its reported WAIC potentially unreliable; it **conditions on learned named-designer effects**, whereas M1a has none and M0 is ordinary regression. Do not claim a definitive new-designer predictive ranking or causal interpretation of a WAIC difference. It is valid to report the numeric comparison with these limitations.
4. **P5's separate External-SD exercise:** Baseline and Extended share 6,416 development games and 3,209 matched holdout games; it is not included in the 6,489-row model-comparison WAIC. Its extension changes mean structure, between-game variance and external noise assumptions; no benefit can be attributed to the SD plug-in alone. The historical SD snapshot date is unverified, and the plug-in ignores measurement-noise uncertainty.
5. **Exploratory holdout:** The holdout was consulted during model exploration, so do not present prior P5 holdout comparisons as untouched confirmatory testing; P1 splits by game, not new designer. Both data selection/feature standardization rules and top-20 tags were defined on the full cleaned data before splitting.
6. **P4 caveats remain:** The 6,489 development fit and upper-6 s prior sensitivity passed MCMC convergence checks, but simulation theta-interval coverage was around **84–88%**, and grouped development PPC retains misfit. Passing convergence does not prove uncertainty calibration.
7. **P3 scope:** 19,440 complete-case BGG games, outcome is number of ratings with lower truncation at 30. NB is preferred to Poisson within M2; PPC still misfits, and the comparison is full-sample not holdout.
8. **P6 ranking:** P5 also provides the uploaded and owner-validated full-scope handoff for 21,375 of 21,631 cleaned 2022 games (500 joint draws); 256 unmatched or invalid SD cases excluded. No verified P6 benchmark/rank intervals/Top-10 probabilities have been committed as of 24 Nov; Full-BGG ranking claims remain unsupported.

## Deliverable checklist (owner-reported completion still needed)

- [x] **P1 data preparation** — cleaning, features, dictionary, random split, scripts and shared CSVs
- [x] **P1 EDA** — 10 figures and descriptive table uploaded
- [ ] **P1 M0/M1 grouped PPC** — not yet verified as a P1 deliverable
- [x] **P2 M0 Gibbs/JAGS development analysis** — posterior/diagnostics, 6,489 aligned IDs and shared likelihood files
- [ ] **P2 later extensions** — CAVI and independent runtime comparison not verified; not a blocker for 1 Dec
- [x] **P3 M2** — PR #4 merged, Poisson/NB, PPC, WAIC, sensitivity, docs and plots
- [x] **P4 M1b fit and s-prior sensitivity** — baseline and sensitivity, diagnostics, figures, PPC and model documentation
- [x] **P4 WAIC file handoff** — PR #2 merged, 500 × 6,489 RDS, IDs/checksums and validation
- [ ] **P4 presentation materials** — final chosen figures, concise interpretation and limitations to be consolidated
- [x] **P5 Baseline/Extended and robustness** — grouped PPC, exploratory holdout, prior/SD sensitivity and latent P6 handoff
- [x] **P5 matched-game WAIC** — same-game M0/M1a/M1b summary, paired SE, M0 sampler check and interpretation uploaded
- [ ] **P5 presentation/report prose** — results delivered, slides and English section still to assemble
- [ ] **P6** — BGG benchmark, posterior ranking uncertainty, presentation/report integration not yet verified in GitHub

Only change a pending status to completed once a teammate has linked or supplied the actual artifact.
