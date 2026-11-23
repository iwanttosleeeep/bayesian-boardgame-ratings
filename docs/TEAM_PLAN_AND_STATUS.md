# Team project plan and progress — P1–P6

**Working status as of 23 November 2026**, grounded in the project plan dated 20 Nov and the deliverables visible in this repository. This is **not a replacement for the original proposal**. “Not in repo” does not mean the owner has not worked locally.

## Ownership, evidence, next handoff

| Owner | Assigned responsibilities | Current evidence | Next output / dependency |
| --- | --- | --- | --- |
| **P1** | Data joining/cleaning, feature engineering and dictionary; EDA; M0/M1 grouped PPC | 4 shared CSVs and 4 reproducibility scripts; P1 README | EDA figures/tables and model PPC once draws are shared |
| **P2** | M0 normal Bayesian regression using JAGS, hand-written Gibbs and CAVI; M1b runtime benchmark | JAGS/Gibbs R scripts, initial posterior/log-likelihood RDS and comparison table delivered. Code targets `comparison_sample.csv` (holdout); this fit is **not accepted as development training**. | Agree common development IDs, refit M0 on development, retain IDs and preprocessing; CAVI and M1b timing still unverified |
| **P3** | M2 popularity count models: Poisson and truncated NB, overdispersion, PPC and within-M2 WAIC | No P3-specific deliverables verified in GitHub | Check count truncation, fit Poisson/NB on the same sample, report diagnostics and tail/30-floor PPC |
| **P4** | M1b covariates + log rating count + designer random effects; shrinkage and partial pooling | **[PR #1 merged](https://github.com/iwanttosleeeep/bayesian-boardgame-ratings/pull/1)**: 6,489-game development M1b, four-chain convergence, `s` prior sensitivity, IDs and model/diagnostic summaries; [delivery details](P4_DELIVERY.md) | 28 Nov presentation plots and interpretation; coordinate identical training-ID M0/M1a/M1b WAIC; posterior/latent/loglik RDS remain local; simulation theta interval coverage only 84–88% |
| **P5** | M1a baseline and external-SD extension, prior/SD sensitivity, model checks and cross-model comparison | Earlier 6,416-game fits, comparison and 4 posterior RDS; **new [6,489-game M1a handoff](../outputs/P5/M1a_WAIC_6489/README.md)** (code, exact training IDs, diagnostics, parameter summary, single-model WAIC 17,496.15). Its large log-likelihood RDS remains local pending upload. | Upload 6,489-game likelihood RDS; agree comparison likelihood with P2/P4; complete joint WAIC and own report section |
| **P6** | BGG pseudo-vote benchmark, posterior rank credible intervals/Top 10 probabilities, slides and report integration | No P6-owned deliverables verified in GitHub | Both M1a models' latent rating RDS are available from P5; first ranking/benchmark and slide handoff |

## Dependencies (do not skip)

- **P1 → everyone:** [`data_clean.csv`](../data_clean.csv), [dictionary](../variable_dictionary.csv), [development](../dev_subsample.csv), [holdout](../comparison_sample.csv), documented in [P1 guide](P1_DATA_GUIDE.md).
- **P2 → P1/P5/P4:** M0 posterior draws, diagnostics, pointwise likelihood; M1b JAGS runtime evidence.
- **P3 → report/P6:** Poisson vs NB fit, count-tail and count-floor PPC, within-M2 model comparison. Do not mix popularity-model WAIC with rating-model WAIC.
- **P4 → P2/P5/P6:** Designer-effect specification, marginal likelihood, posterior draws, how unseen designers are handled, M1b ranking where possible.
- **P5 → P1/P6:** [Original 6,416-game baseline](../outputs/P5/M1a_Baseline/) and [external-SD posterior](../outputs/P5/M1a_Extended_ExternalSD/) (both have `parameter_draws.rds` and `latent_rating_draws_for_P6.rds`); [model comparison](../outputs/P5/M1a_Model_Comparison/) and [sensitivity](../outputs/P5/Sensitivity_Analysis/). Separately, [6,489-game M1a WAIC handoff](../outputs/P5/M1a_WAIC_6489/README.md) has IDs that were verified to match **P4 baseline IDs in the same order**; the P5 500-draw likelihood RDS still needs upload. Rank intervals require latent draws, not posterior mean CSV alone.
- **P6 → all:** BGG benchmark, within-sample rank uncertainty, consistent figures/slides, integrated results and final checks.

## Dates and intended checkpoints

| Date | Milestone | Evidence at this review |
| --- | --- | --- |
| **22 Nov** | P1 cleans data and freezes data files | Delivered in GitHub |
| **23 Nov** | P4 marginal M1b skeleton; P3 truncation feasibility | **P4 delivered and PR #1 merged; P3 unverified** |
| **24 Nov** | P5 latent draws; P2/P4 runtime and specification decision | **P5 draw files present; P4 runtime and 6,489-game specification delivered early; P2 runtime unverified** |
| **26 Nov** | Preliminary M0/M1b/M2; P1 EDA; P5 sensitivity; P6 BGG benchmark | P5 sensitivity already present; other owners unverified |
| **27 Nov** | P1/P3 model PPC; P6 initial ranking | P6 can use uploaded draws |
| **28 Nov** | **Freeze presentation results** (code, figures, slide points, limitations) | All owners |
| **29–30 Nov** | Integrate slides, check against outputs, rehearse | P6 coordinates |
| **1 Dec** | Progress presentation (~15 minutes) | All |
| **6 Dec** | Remaining CAVI, M1b sensitivity, matched-row WAIC/PSIS-LOO, ranking | All as applicable |
| **10 Dec** | Individual English report sections | Each owner |
| **14–16 Dec** | Complete draft, review and final corrections | P6 + all |
| **18 Dec** | Final PDF report, reproducible code/data | Designated submitter |

## Sampling and modeling rules that have changed since the 20 Nov plan

1. **Actual P1 split:** `dev_subsample.csv` has 6,489 game-random development rows, `comparison_sample.csv` has 3,244 disjoint game-random **holdout** rows (seed 20261122); 912 designers overlap. The original plan instead described designer-group sampling of ~5,000 and an *in-development* complete-case comparison sample.
2. **Formal M0/M1a/M1b WAIC:** the current `comparison_sample.csv` is reserved as holdout. The working target is **all 6,489 development games**. P4 fitted these, and P5's separate M1a refit uses identical IDs in identical order; **P2's final development-only fit and likelihood remain to be aligned**. Use appropriately integrated, comparable per-game likelihoods. **No three-model WAIC comparison has been completed.**
3. **P5 scope:** present M1a Baseline and Extended fits share only the 6,416 development games with historical SD matched; holdout ELPD is on 3,209 matched holdout games. This differs from the original full-data M1a aim. Global BGG Top 10/50 probabilities cannot be inferred from rankings computed on these 6,416 alone.
4. **P5 changes multiple assumptions:** the external-SD extension also changes mean and between-game dispersion vs the baseline. Its improvement cannot be ascribed solely to historical SD. The historical SD source date is unverified and observation noise uncertainty is plugged in rather than estimated.
5. **Holdout is exploratory:** the group has already used the holdout to guide previous model experiments; do not present it as fully untouched final testing.
6. **P4 prediction:** same designer can appear on both sides of P1's game-level split. A new designer requires integrating/sampling a new random effect; do not interpret these as the same prediction target.
7. **Preprocessing:** P1 standardized features and selected common indicators before sampling from the full dataset. Strict leakage-free holdout evaluation would derive those from training only. Do not silently replace P1's published CSVs after teammates begin modeling.

## Deliverable checklist (owner-reported completion still needed)

- [x] **P1 data preparation** — data cleaning, variables, splits and code uploaded
- [ ] **P1 model checking and EDA** — not yet evidenced in repo
- [ ] **P2 M0** — preliminary JAGS/Gibbs delivered, but holdout-trained fit must be replaced with a development-trained fit; CAVI, M1b runtime and final handoff pending
- [ ] **P3 M2** — Poisson/NB fits, PPC, diagnostics and model selection
- [x] **P4 M1b first three milestones** — full 6,489-game development fit, convergence and `s`-prior sensitivity merged in PR #1; [scientific caveats](P4_DELIVERY.md) documented
- [ ] **P4 continuing** — 28 Nov analysis/figures, model-comparison alignment and downloadable posterior/latent/loglik draws where needed
- [x] **P5 M1a model fitting/validation** — baseline, extension, sensitivity and same-ID exploratory holdout ELPD, posterior RDS in GitHub
- [x] **P5 6,489-game M1a WAIC refit** — four chains passed diagnostics; full development IDs match P4; standalone WAIC and metadata uploaded
- [ ] **P5 remaining** — upload pointwise likelihood RDS, complete formal M0/M1a/M1b matched comparison, and interpret limitations
- [ ] **P6** — BGG benchmark, ranking uncertainty, slides and report integration

Only change a pending status to completed once a teammate has linked or supplied the actual artifact.
