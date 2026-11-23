# P4 smoke evidence — 23 November 2026

This is a development-only 400-game implementation/runtime trial. It is **not**
a final converged M1b fit and is not evidence of full-development runtime.

| Item | Observed result |
|---|---|
| Environment | R 4.5.3, JAGS 4.3.2, rjags 4-18, coda 0.19-4.1 |
| Environment gate | Synthetic Normal model compiles/samples; conjugate mean/SD check passes |
| Data | 400 games from dev_subsample.csv, sampling seed 42; no holdout reading |
| Model | Constant tau; 55 retained predictors; 319 named designers; 36 unknown-designer games |
| MCMC | Four chains; seeds 43–46; 1,000 adaptation + 1,000 burn-in + 1,000 retained per chain |
| Fit time | 43.36 seconds (compile/adapt/burn/sample only) |
| Largest classical coda R-hat | 1.02112 (tau) |
| Smallest coda ESS | 78.63 (sigma_d); tau ESS 85.37 |
| R-hat <=1.01 and ESS >=400 for all | **Not met** |
| Implementation checks | Recipe replay; finite imputation; unseen/anonymous designer probe; latent shrinkage direction; finite parameter/latent/loglik draws |

The slowest scale parameters are tau and sigma_d. Longer runs and variance
allocation diagnostics are needed before inference. The short-run s posterior
also leans toward its upper prior limit (mean 2.80, 97.5% quantile 2.995); this
motivates later sensitivity checking, not changing the baseline based on holdout.

Evidence in `smoke/`:

- `environment_verified.txt`, `sessionInfo.txt`: actual runtime/gate output.
- `train_game_ids.csv`: exact 400 IDs, in fitted order.
- `design_columns.csv`: retained columns and prior SDs; beta[k] refers to row k.
- `convergence.csv`, `parameter_summary.csv`, `smoke_summary.txt`: short-run results.
- Local ignored RDS: `preprocessing.rds`, `smoke_draws.rds`,
  `latent_and_loglik.rds`. These preserve recipe, model, source hash, chain seeds,
  parameter draws, 100 latent draws and theta-integrated/designer-conditional
  loglik. They can be regenerated with `code/P4/run_local.ps1 -Mode smoke`.

No WAIC, holdout score, final ranking, or final convergence claim is made.
The baseline recommendations and reasons are in [P4_BASELINE.md](../../docs/P4_BASELINE.md),
and local environment provenance/commands in [code/P4/README.md](../../code/P4/README.md).
