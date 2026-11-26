M0 figures

## P1 EDA figures (05_eda.R, 23 Nov 2026)

| File | Content |
| --- | --- |
| eda_01_average_distribution.png | Distribution of raw average ratings |
| eda_02_users_rated_distribution.png | Distribution of rating counts per game (log scale) |
| eda_03_average_vs_users.png | Average rating vs number of ratings — shrinkage motivation |
| eda_04_bayes_vs_average.png | BGG bayes_average vs raw average — BGG shrinkage effect |
| eda_05_rating_by_year.png | Mean rating by publication year |
| eda_06_category_boxplot.png | Ratings by game category (top 12) |
| eda_07_mechanic_boxplot.png | Ratings by game mechanic (top 12) |
| eda_08_correlation_heatmap.png | Correlation matrix of key numeric variables |
| eda_09a_dev_vs_holdout_average.png | Development vs holdout: average rating density |
| eda_09b_dev_vs_holdout_users.png | Development vs holdout: rating-count density |

Summary statistics: [tables/eda_descriptive_summary.csv](../tables/eda_descriptive_summary.csv).
Reproduce with `05_eda.R` at the repository root.

## P1 grouped PPC figures (code/P1/06_grouped_ppc_m0_m1a.R, updated 26 Nov 2026)

Run with the 6,489-game M1a refit draws (`archive/outputs/P5/M1a_WAIC_6489/parameter_draws.rds`);
see [docs/P1_PPC_NOTES.md](../docs/P1_PPC_NOTES.md) for conclusions.

| File | Content |
| --- | --- |
| ppc_m0_rating_count_bands.png | M0 grouped PPC: mean rating by rating-count band |
| ppc_m1a_rating_count_bands.png | M1a grouped PPC: mean rating by rating-count band |
| ppc_m0_category.png | M0 grouped PPC: mean rating by category |
| ppc_m1a_category.png | M1a grouped PPC: mean rating by category |
| ppc_m0_density.png | M0 posterior predictive density vs observed |
| ppc_m1a_density.png | M1a posterior predictive density vs observed |
| ppc_variance_comparison_rating_count.png | **Variance PPC by rating-count band, M0 vs M1a — motivation for the Extended model** |
