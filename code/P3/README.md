# P3: M2 popularity analysis

This analysis uses P1's `data_clean.csv`. After removing rows with missing predictors, both models use the same 19,440 games. The outcome is `users_rated`, left-truncated at 30. These are full-sample, within-M2 comparisons, not independent holdout results.

## Model

```text
log(mu) = alpha + X beta + delta * z_game_age
```

`X` contains playing time, player counts, minimum age, 20 category indicators, 20 mechanic indicators and the multiple-designer indicator. Game age is included separately. Poisson and negative-binomial models are compared using WAIC. Coefficients are exponentiated to obtain rate ratios. Reported associations are not causal effects.

## Included files

- `01_prepare_data.R`: construct the common modelling sample.
- `02_fit_M2.R`: fit either model with four JAGS chains.
- `02b_fit_M2_source.R`: source-level MALA implementation matching the saved model settings.
- `03_analyze_M2.R`: regenerate posterior summaries, WAIC/DIC, paired WAIC SE, PPC results and figures.
- `04_prior_sensitivity.R`: run the joint alternative-prior sensitivity analysis.
- `05_write_report.R`: generate the report and presentation from result tables.
- `run_all.R`: coordinate preparation, optional refitting, analysis and document generation.

Saved posterior draws, numerical CSV tables in `tables/P3/`, and figures in `figures/P3/` are committed. Reviewers can inspect the findings without refitting.

The report and presentation are separate prose deliverables and are intentionally not committed. Running `05_write_report.R` generates them locally as `report/sections/P3_M2_popularity.md` and `slides/P3/P3_presentation.md`; these paths refer to generated local outputs, not missing committed files.

The two full `outputs/P3/M2_*_pointwise_loglik.rds` caches are not committed because each is approximately 427–430 MiB. They are intermediate results, not posterior draws. `03_analyze_M2.R` regenerates them from the included posteriors when absent.

## Rebuild without refitting

Run from the repository root with R and the `coda` package installed:

```sh
Rscript code/P3/run_all.R . saved
```

The default `saved` mode does not refit either model. It prepares the modelling data, uses the saved posteriors, regenerates analysis outputs, and writes the report and presentation. If the large log-likelihood caches are absent, their first regeneration requires substantial time and memory.

JAGS and `rjags` are required only for the optional JAGS refitting mode. See `P3_REPRODUCE.md` for all modes, overwrite behaviour and environment details.

## Optional refitting

```sh
Rscript code/P3/run_all.R . jags
Rscript code/P3/run_all.R . source
Rscript code/P3/run_all.R . sensitivity
```

These modes can overwrite posterior or sensitivity outputs. Back up existing results before using them. The JAGS script is an independent implementation of the same model and does not claim to reproduce identical random draws.

## Interpretation limits

The NB model is preferred to Poisson, but PPC still shows systematic misfit. Results apply only to ranked games with at least 30 ratings in the January 2022 snapshot. The analysis uses complete cases and has no independent holdout evaluation. M2 WAIC must not be compared directly with M0/M1a/M1b rating-model WAIC.
