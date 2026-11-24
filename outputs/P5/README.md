# STAT6106 — P5 Bayesian rating shrinkage

**Status:** planned P5 model calculations and cross-model comparisons complete as of 24 November 2026. Presentation and report remain. This is P5's contribution; P1's files and the team proposal remain unchanged.

## Final comparison deliverables (24 November)

- [6,489-game M0/M1a/M1b WAIC](WAIC_Comparison_6489/README.md) — complete, separate sample.
- [6,416-game four-model WAIC](WAIC_Comparison_6416/README.md) — complete; substantial M1b pointwise WAIC warnings.
- [3,209-game four-model exploratory holdout](Holdout_Comparison_3209/README.md) — complete; primary predictive evidence.
- [Full-scope P6 handoff](P6_Full_Handoff/README.md) — 21,375 games × 500 draws, uploaded and owner-validated; 256 unmatched games excluded.
- P4's [matched ExternalSD extension](../P4/ExternalSD_6416/README.md) and [holdout validation](../P4/Holdout_3209/README.md) are merged (PRs #5 and #6). No additional fitting required for these comparisons.

## Additional M1a Baseline refit for M0/M1a/M1b WAIC (6,489 games)

This is a **separate, same-specification baseline refit**, not a replacement for the matched 6,416-game Baseline-vs-Extended experiment described below. It uses **all 6,489 P1 development games** and never reads the 3,244-game holdout.

- Reproduction script: [09_M1a_Baseline_WAIC_6489.R](../../code/P5/09_M1a_Baseline_WAIC_6489.R).
- Handoff files and upload status: [M1a_WAIC_6489/README.md](M1a_WAIC_6489/README.md).
- Four MCMC chains, 3,000 retained samples/chain; all reported R-hat <=1.01 and ESS >=400.
- Posterior mean `s` = 2.9655, close to the U(0.5,3) upper boundary; this parameter is **not** a reliably identified individual-rater SD.
- **Single-model** WAIC = **17,496.15** (`p_WAIC` = 2.2385), calculated from a 500 × 6,489 game-level log-likelihood matrix with latent game rating integrated out. This is **in-sample**, not holdout ELPD, and does not yet establish which of M0/M1a/M1b performs best.
- P5's 6,489 training IDs have been checked **identical and in the same order** to P4 baseline's uploaded `train_game_ids.csv`. P2 and P4 subsequently delivered aligned likelihood files; the M1a 6,489 likelihood RDS is uploaded and the comparison is complete; the existing 6,416-game RDS must **not** be substituted.

## Two models retained for the final P5 narrative

| Model | Description | Shared training data |
|---|---|---|
| **M1a Baseline** (formerly “Model A”) | Intercept-only hierarchical shrinkage, shared rater SD `s`, constant between-game SD `tau` | 6,416 SD-matched development games |
| **M1a Extended (External SD)** (formerly “new Model D”) | Game-specific historical rating SD as fixed plug-in; mean and between-game variance vary with log rating count | Same 6,416 games |

Baseline: `y_i ~ Normal(alpha, tau^2 + s^2/n_i)`, `alpha ~ N(6.4,1^2)`, `s ~ Uniform(0.5,3)`, `tau ~ half-Cauchy(0,1)`. Common pseudo-votes: `m = s^2/tau^2`.

Extended: `x_i = log(n_i)-mean_training(log(n))`, `mu_i = alpha+gamma*x_i`, `tau_i = exp(a_tau+b_tau*x_i)`, `y_i ~ Normal(mu_i, tau_i^2+sd_hist_i^2/n_i)`. The plug-in `sd_hist_i` comes from a separate historical BGG snapshot of **unverified date**. Game-specific pseudo-votes: `m_i = sd_hist_i^2/tau_i^2`.

These models differ in the **mean**, **between-game variance**, and **measurement-noise** assumptions. A difference in predictive performance cannot be attributed to historical SD alone.

## Fixed data and comparison

- P1's development sample: 6,489 games, of which **6,416** match usable historical per-game SD. Both models are fitted to exactly those **same 6,416 game IDs**; no re-sampling of P1 data.
- P1's independent holdout: 3,244 games, of which **3,209** match usable SD. Both models are assessed on precisely the **same 3,209 holdout games**.
- The holdout was already consulted in earlier model development, so this is an **exploratory** predictive comparison, not a pristine, untouched test set.
- Posterior ranking and Top 50 comparisons cover only the **6,416 development games**, **not all BGG games**. Do not call these global BGG rankings.

## Verified outputs from the 6,416/3,209 comparison

| Metric | Baseline | Extended |
|---|---:|---:|
| Holdout ELPD (higher is better) | −4347.83 | −4126.12 |
| 95% individual predictive coverage | 94.61% | 94.33% |
| Holdout grouped mean PPC passing | 1/4 | 3/4 |
| Holdout grouped variance PPC passing | 2/4 | 3/4 |
| Development grouped mean PPC passing | 0/4 | 4/4 |
| Development grouped variance PPC passing | 1/4 | 4/4 |
| Median absolute shrinkage (rating points) | 0.0360 | 0.0095 |

Difference in holdout ELPD (Extended − Baseline) is **+221.70**, approximate paired SE **18.02** (assumes independence across games and does not adjust for designer clustering). Development Top 50 overlap is **36/50**. Numerically, both fits pass the reported R-hat < 1.01 and ESS ≥ 400 checks. Baseline `s` remains near its prior upper bound, and neither model is perfect in the highest-rating-count holdout group.

This is **holdout ELPD, not WAIC**. The separate 6,489-game M0/M1a/M1b WAIC exercise and the 6,416-game four-model WAIC are now complete; see final deliverables above.

## Repository layout

- `code/P5/01_prepare_historical_SD.R` — source match and fixed 6,416-game lookup
- `code/P5/02_M1a_Baseline.R` — refit the original M1a baseline on those same games
- `code/P5/03_M1a_Extended_ExternalSD.R` — fit extended M1a with game-specific SD
- `code/P5/04_Extended_holdout_validation.R` — exploratory holdout predictions
- `code/P5/05_Extended_SD_sensitivity.R` — historical SD ×0.8, ×1, ×1.2
- `code/P5/06_Extended_prior_sensitivity.R` — alternative gamma/tau prior choices
- `code/P5/07_Baseline_vs_Extended_comparison.R` — matched-game comparison, no model refitting
- `code/P5/08_prepare_P6_handoff.R` — check and prepare ranking-draw handoff, no refitting
- `code/P5/09_M1a_Baseline_WAIC_6489.R` — new separate 6,489-development-game M1a fit for formal WAIC handoff
- `outputs/P5/M1a_Baseline/` — updated same-sample baseline parameter, convergence and PPC CSVs
- `outputs/P5/M1a_Extended_ExternalSD/` — matched SD, posterior rating summaries, convergence and PPC, holdout summaries
- `outputs/P5/M1a_Model_Comparison/` — matched baseline/extended held-out predictive and shrinkage summaries
- `outputs/P5/Sensitivity_Analysis/` — extended-model SD and prior robustness summaries

The earlier full-21,831-game Model A outputs and **old common-s D vs external-SD D** comparison files have been removed from the **current** P5 tree. They remain recoverable via Git history. This does not erase the old experiments or mean they were invalid; they simply do not belong in the current two-model report.

## Running scripts and legacy local cache paths

Run the R scripts from the **same RStudio working directory** used for the initial P5 analysis. All scripts deliberately retain existing local input/output paths under `P5_external_SD/` (e.g. `Model_A_same_6416/`, `Model_D_calibrated/`, `M1a_A_vs_ExternalSD_Comparison/`) to **avoid moving or invalidating previously generated posterior draws**. These are internal cache paths, **not** the GitHub folder names above. The numbered script names and external documentation are now normalized; no reruns were needed for this repository reorganization.

If starting clean: run 01 to prepare external SD; 02 and 03 to fit both models; 04 to construct the holdout prediction cache; 05/06 for sensitivities; 07 for the model comparison; 08 for P6 handoff. R packages `rjags` and `coda` plus JAGS are required.

## Posterior draws and reproducibility status

**Both M1a model folders now contain the genuine uploaded posterior files**:

- [Baseline](M1a_Baseline/): `parameter_draws.rds`, `latent_rating_draws_for_P6.rds`
- [Extended External SD](M1a_Extended_ExternalSD/): `parameter_draws.rds`, `latent_rating_draws_for_P6.rds`

The GitHub object listing confirms each file is present; these binary files have **not** been independently opened or the model fits rerun during this README update. They are intended for P6's **within-6,416-game** rank credible intervals and top-10 probabilities.

**Not a complete single-command reproduction package:** the local P5 R scripts still use original working paths under `P5_external_SD/` rather than the GitHub presentation folders. For reuse without refitting, download or copy the RDS and matched CSV into the script-expected local locations. Some source caches and detailed development comparisons are not committed. Both P5 per-game holdout CSVs are now uploaded.

The external historical rating SD snapshot date is not verified, SD is treated as a plug-in value, and holdout data were consulted during exploration; these limitations should remain visible in the final report. Formal cross-model comparisons are complete. Use the separate comparison READMEs for sample definitions and interpretation.

See the [team status](../../docs/TEAM_PLAN_AND_STATUS.md) and [P1 data contract](../../docs/P1_DATA_GUIDE.md).
