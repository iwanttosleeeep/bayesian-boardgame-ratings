# P3: M2 popularity analysis

This analysis uses P1's `data_clean.csv` as the only modelling input. After removing rows with missing predictors, both models use the same 19,440 games. The outcome is `users_rated`, left-truncated at 30.

## Model

```text
log(mu) = alpha + X beta + delta * z_game_age
```

`X` contains playing time, player counts, minimum age, 20 category indicators, 20 mechanic indicators and the multiple-designer indicator. Game age is included separately. Poisson and negative-binomial models are compared using WAIC. Coefficients are exponentiated to obtain rate ratios.

## Files

- `01_prepare_data.R`: read the cleaned data and construct the common modelling sample.
- `02_fit_M2.R`: fit either model with four JAGS chains.
- `03_analyze_M2.R`: calculate posterior summaries, WAIC and posterior predictive checks, and draw the figures.
- `run_all.R`: run the complete analysis.

Saved posterior draws and output tables are included, so the report can be checked without fitting the models again. The script `02_fit_M2.R` is a short JAGS implementation of the same model; a full-data refit may take considerable time.

## Run

Run these commands from the repository root with R, JAGS, `rjags` and `coda` installed:

```sh
Rscript code/P3_popularity/01_prepare_data.R .
Rscript code/P3_popularity/02_fit_M2.R . poisson
Rscript code/P3_popularity/02_fit_M2.R . negbin
Rscript code/P3_popularity/03_analyze_M2.R .
```

To rebuild the tables and figures from the included posterior draws, run only the first and third scripts. Running `run_all.R` refits both models and replaces the saved posterior files.

The report is `report/sections/P3_M2_popularity.md`. Presentation text is in `slides/P3/P3_presentation.md`.
