# STAT6106 — P5 Bayesian rating shrinkage

**Status — 27 November 2026:** all planned P5 model comparisons and ranking handoffs are complete. Seven presentation figures are committed and the group deck is assembled (15 main + 4 backup slides). Report writing and optional extensions remain. This is P5's contribution; P1's files and the team proposal remain unchanged.

## Completed comparison and ranking deliverables

- [Archived 6,489-game M0/M1a/M1b WAIC](../../archive/outputs/P5/WAIC_Comparison_6489/README.md) — complete, separate sample.
- [6,416-game four-model WAIC](WAIC_Comparison_6416/README.md) — complete; substantial M1b pointwise WAIC warnings.
- [3,209-game four-model exploratory holdout](Holdout_Comparison_3209/README.md) — complete; primary predictive evidence.
- [Full-scope P6 handoff](P6_Full_Handoff/README.md) — 21,375 games × 500 draws, uploaded and owner-validated; 256 unmatched games excluded.
- P4's [matched ExternalSD extension](../P4/ExternalSD_6416/README.md) and [holdout validation](../P4/Holdout_3209/README.md) are merged (PRs #5 and #6). No additional fitting required for these comparisons.

## Archived additional M1a Baseline refit for M0/M1a/M1b WAIC (6,489 games)

This is a **separate, same-specification baseline refit**, not a replacement for the matched 6,416-game Baseline-vs-Extended experiment described below. It uses **all 6,489 P1 development games** and never reads the 3,244-game holdout.

- Reproduction script: [09_M1a_Baseline_WAIC_6489.R](../../code/P5/09_M1a_Baseline_WAIC_6489.R).
- Handoff files and upload status: [archived M1a WAIC handoff](../../archive/outputs/P5/M1a_WAIC_6489/README.md).
- Four MCMC chains, 3,000 retained samples/chain; all reported R-hat <=1.01 and ESS >=400.
- Posterior mean `s` = 2.9655, close to the U(0.5,3) upper boundary; this parameter is **not** a reliably identified individual-rater SD.
- **Single-model** WAIC = **17,496.15** (`p_WAIC` = 2.2385), calculated from a 500 × 6,489 game-level log-likelihood matrix with latent game rating integrated out. This is **in-sample**, not holdout ELPD, and alone does not establish which model performs best; the [aligned three-model comparison](../../archive/outputs/P5/WAIC_Comparison_6489/README.md) is complete, with its predictive-target and WAIC caveats retained.
- P5's 6,489 training IDs have been checked **identical and in the same order** to P4 baseline's uploaded `train_game_ids.csv`. P2 and P4 subsequently delivered aligned likelihood files; the M1a 6,489 likelihood RDS is uploaded and the comparison is complete; the existing 6,416-game RDS must **not** be substituted.

## Two models retained for the final P5 narrative

| Model | Description | Shared training data |
|---|---|---|
| **M1a Baseline** (formerly “Model A”) | Intercept-only hierarchical shrinkage, shared rater SD `s`, constant between-game SD `tau` | 6,416 SD-matched development games |
| **M1a Extended (External SD)** (formerly “new Model D”) | Game-specific historical rating SD as fixed plug-in; mean and between-game variance vary with log rating count | Same 6,416 games |

Baseline: `y_i ~ Normal(alpha, tau^2 + s^2/n_i)`, `alpha ~ N(6.4,1^2)`, `s ~ Uniform(0.5,3)`, `tau ~ half-Cauchy(0,1)`. Common pseudo-votes: `m = s^2/tau^2`.

Extended: `x_i = log(n_i)-mean_training(log(n))`, `mu_i = alpha+gamma*x_i`, `tau_i = exp(a_tau+b_tau*x_i)`, `y_i ~ Normal(mu_i, tau_i^2+sd_hist_i^2/n_i)`. The plug-in `sd_hist_i` comes from a separate historical BGG snapshot of **unverified date**. Game-specific pseudo-votes: `m_i = sd_hist_i^2/tau_i^2`.

These models differ in the **mean**, **between-game variance**, and **measurement-noise** assumptions. A difference in predictive performance cannot be attributed to historical SD alone.

The Extended shrinkage weight depends on both rating count and game-specific historical SD; its target and latent variance vary with log rating count. The main full-scope ranking result is a **model-dependent median effective m ≈ 3.02** (IQR 2.36–3.84), not a unique or universally optimal shrinkage value. Historical SD estimates support smaller observation-noise values than the Baseline s ≈ 3, subject to their unverified snapshot date and fixed plug-in treatment. Baseline m ≈ 11.6 remains a diagnostic of weak identification and prior sensitivity.

## Fixed data and comparison

- P1's development sample: 6,489 games, of which **6,416** match usable historical per-game SD. Both models are fitted to exactly those **same 6,416 game IDs**; no re-sampling of P1 data.
- P1's independent holdout: 3,244 games, of which **3,209** match usable SD. Both models are assessed on precisely the **same 3,209 holdout games**.
- The holdout was already consulted in earlier model development, so this is an **exploratory** predictive comparison, not a pristine, untouched test set.
- The **earlier Baseline-vs-Extended ranking and Top 50 comparison** covers only the **6,416 development games**; its overlap of 36/50 is a development-sample result. The completed [full-scope P6 handoff](P6_Full_Handoff/README.md) instead covers **21,375 SD-matched games**, using 500 joint latent-rating draws from the already fitted Extended model; P6 has delivered [ranking results](../P6/README.md). Neither scope is the entire/current BGG catalogue.

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
- `archive/outputs/P5/M1a_Model_Comparison/` — matched baseline/extended held-out predictive and shrinkage summaries
- `outputs/P5/Sensitivity_Analysis/` — extended-model SD and prior robustness summaries

The earlier full-21,831-game Model A outputs and **old common-s D vs external-SD D** comparison files have been removed from the **current** P5 tree. They remain recoverable via Git history. This does not erase the old experiments or mean they were invalid; they simply do not belong in the current two-model report.

## Running scripts and legacy local cache paths

Numbered P5 R scripts now locate the checkout independently of the launch directory and use explicit equivalent-file mappings. The original `P5_external_SD/` cache remains first priority; set `P5_CACHE_DIR` to use an external original cache. Generated outputs retain their original cache subfolders; repository artifacts are read in place. A full checkout (or `BOARDGAME_REPO_ROOT`) supplies the shared path helper.

Use `--check-paths` for a read-only check before running a workflow. Scripts 04 and 11 still require the uncommitted original historical snapshot. Scripts 07 and 13 now explain a preserved provenance failure: the Baseline RDS expects CSV MD5 `db47f754a7637bca215937c481411cf1`, whereas the uploaded matched CSV is `713f1976d7967b275e31e5c36b991eb0`. Their 6,416 ordered IDs agree, but the exact original CSV must be restored; the checksum assertion is not relaxed. This does not invalidate the already committed comparison artifacts.

Script 01 reuses the committed compact lookup without downloading/rebuilding the missing full audit cache. Explicit `--rebuild-lookup` can create a missing local lookup from the original historical snapshot. Script 08 supports `--validate-only` to check the original development handoff without writing copies. These changes do not substitute the archived 6,489-game refit or the 21,375-game handoff for the original 6,416-game fits.

See [reproduction prerequisites and commands](../../docs/REPRODUCTION.md) for the mapping, exact missing intermediates, read-only checks and owner-run regeneration commands. Original fitting/sensitivity commands still require JAGS and their recorded packages; they were not run in this cleanup.

## Posterior draws and reproducibility status

**Both M1a model folders now contain the genuine uploaded posterior files**:

- [Baseline](M1a_Baseline/): `parameter_draws.rds`, `latent_rating_draws_for_P6.rds`
- [Extended External SD](M1a_Extended_ExternalSD/): `parameter_draws.rds`, `latent_rating_draws_for_P6.rds`

All four files are present; their contents were not decoded and no model was refitted in this documentation audit. They belong to the **6,416-game development analysis**. P6's completed **21,375-game** ranking uses the separate [P6_Full_Handoff](P6_Full_Handoff/README.md), including all five uploaded `P6_theta_draws_part_*.rds` files and the full-scope summary CSV. P6 ranks within each of the 500 joint draw columns; the development-only latent files must not replace that handoff.

**Not a complete offline reproduction package:** equivalent committed inputs are located automatically, but exact source-CSV provenance and uncommitted historical snapshots remain requirements for some operations. Both P5 per-game holdout CSVs are committed. No original CSV, posterior or source cache was fabricated to make a workflow pass.

The external historical rating SD snapshot date is not verified, SD is treated as a plug-in value, and holdout data were consulted during exploration; these limitations should remain visible in the final report. Formal cross-model comparisons are complete. Use the separate comparison READMEs for sample definitions and interpretation.

See the [current team status](../../README.md#team-status--27-november-2026), [24 Nov historical record](../../docs/TEAM_PLAN_AND_STATUS.md) and [P1 data contract](../../docs/P1_DATA_GUIDE.md).
