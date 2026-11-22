# P5 — Preliminary Bayesian shrinkage analysis (2026-11-22)

**Status:** preliminary, exploratory analysis. **Model A, not old D, is the original M1a baseline.** See [model_a_original](./model_a_original/) for its historically recorded output and a reproduction script. The earlier 'old D' is only the comparator for the external-SD D extension. This directory and `code/P5/` do not replace the group proposal, original M1a, or P1's data files.

## Scope and samples

- P1's `dev_subsample.csv`: 6,489 games; **6,416** match historical within-game rating SD data and are used for the calibrated Model D training.
- P1's `comparison_sample.csv`: 3,244 distinct game IDs; **3,209** match historical SD data and are used for exploratory holdout checks.
- Neither the model nor ranking outputs currently cover all BGG games. Ranked Top 10/Top 50 results would be **within the 6,416 matched development games only**.
- P1's holdout had been consulted during earlier model exploration; treat its results as **exploratory**, not as an untouched independent test.

## Model (extension, NOT original intercept-only M1a)

For `x_i = log(n_i) - mean_train(log(n))`:

```
y_i ~ Normal(alpha + gamma*x_i, tau_i^2 + sd_hist_i^2/n_i)
log(tau_i) = a_tau + b_tau*x_i
```

`sd_hist_i` is a historical per-game rating SD, used as a fixed plug-in estimate. Its snapshot date has **not** been independently established as identical to the January 2022 BGG snapshot. Missing historical SD observations are not modeled here. The implied per-game effective pseudo-votes are `m_i = sd_hist_i^2/tau_i^2`; this is not a globally common pseudo-vote count and cannot be interpreted as fully equivalent to the BGG ~2,000-vote adjustment.

The original constant-s and constant-tau M1a should remain documented as a baseline, rather than being silently replaced by this extension.

## Workflow

Run R scripts from the project working directory, in this order:

1. `code/P5/P5_01_save_SD_lookup.R`: matches P1 development data to historical SD, caches source data locally.
2. `code/P5/P5_02_Model_D_external_SD.R`: fits calibrated D and saves posterior summaries and latent rating draws.
3. `code/P5/P5_03_holdout_validation_fixed.R`: exploratory holdout evaluation (fixed download timeout).
4. `code/P5/P5_04_SD_sensitivity.R`: historical SD x0.8, x1.0, x1.2.
5. `code/P5/P5_05_prior_sensitivity.R`: four tau/gamma prior variations.
6. `code/P5/P5_07_same_sample_model_comparison.R`: old common-s D vs calibrated D with 6,416 shared training games and 3,209 shared holdout games.
7. `code/P5/P5_06_prepare_P6_handoff.R`: optional handoff validation; **not yet confirmed to have been run**.

Requires R, JAGS, `rjags`, `coda`. Working directory must be consistent across scripts. The matching script downloads P1 development data and a separate historical SD source. The later scripts require locally saved caches and RDS posterior objects.

## Saved results

- `model_d/`: numeric convergence, grouped development PPC and posterior ratings (where available).
- `holdout/`: 3,209-game holdout summary and grouped PPC.
- `sd_sensitivity/`: SD multiplier sensitivity summaries and convergence.
- `prior_sensitivity/`: model parameter prior sensitivity summaries and convergence.
- `model_comparison/`: like-for-like old vs calibrated D holdout scoring, shrinkage and convergence.

**Repository artifact status (2026-11-22):** `model_d/P5_SD_matched.csv` has been uploaded and verified (6,416 matched games). The user has supplied the genuine `parameter_draws.rds` and `latent_rating_draws_for_P6.rds` in ChatGPT, but the connected GitHub text-file write interface does **not** support direct binary uploads; these RDS files have NOT yet been pushed to GitHub. They must be uploaded separately to `outputs/P5/model_d/` before the repository is self-contained and P6 can run rank-interval calculations. Do not substitute CSV posterior means for latent rating draws.

**Model history:** original intercept-only A (full raw ratings) → B varying-tau only → C varying-mean only → D varying-mean and varying-tau with unknown common s → external-SD D with game-specific historical SD. The existing matched-sample model comparison is **old D vs external-SD D, not A vs external-SD D**.

**No final report claims or all-BGG ranking claims are authorized by this preliminary folder.**

## Interpretation

Initial diagnostics indicate numerical convergence and reasonable grouped PPC on most bands, with residual misfit for very high-rating-count games. Fixed historical SD assumptions alter shrinkage meaningfully; tested tau/gamma priors have much less effect. Old/common-s and calibrated models have similar holdout predictive scores but substantially different shrinkage/ranking behavior. Comparisons involving additional historical SD information are conditional on that extra information; beware snapshot timing and data reuse.

## Team interface

- P1 files are left untouched; holdout data are never used for parameter fitting.
- P2/P4/P5 must agree on common training game IDs for formal matched-row WAIC.
- P4's designer effects cannot be isolated by comparing two models that also differ in observation noise, mean and dispersion.
- P6 should use **actual** latent posterior draws `latent_rating_draws_for_P6.rds`, not just posterior means, to compute rank credible intervals and top-10 probabilities. Do not claim a whole-BGG rank from 6,416 matched development games.
