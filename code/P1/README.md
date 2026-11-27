# P1 script index

**Delivery status — 27 November 2026:** data preparation, EDA and grouped M0/M1a PPC are complete. Scripts 01–04 and the four shared CSVs remain at the repository root; Scripts 05–06 live in `code/P1/`.

| Script | Purpose | Committed outputs / notes |
| --- | --- | --- |
| [01_data_cleaning.R](../../01_data_cleaning.R) | Merge and clean raw BGG data | [Data guide](../../docs/P1_DATA_GUIDE.md); raw inputs and intermediate RDS are local reproduction files |
| [02_feature_engineering.R](../../02_feature_engineering.R) | Features and designer IDs | Shared [data_clean.csv](../../data_clean.csv) |
| [03_sampling.R](../../03_sampling.R) | Fixed development/holdout split | [dev_subsample.csv](../../dev_subsample.csv), [comparison_sample.csv](../../comparison_sample.csv) |
| [04_variable_dictionary.R](../../04_variable_dictionary.R) | Export variable definitions | [variable_dictionary.csv](../../variable_dictionary.csv) |
| [05_eda.R](05_eda.R) | Data distributions and development/holdout comparisons | [Ten EDA figures](../../figures/README.md#p1-eda-figures-05_edar-23-nov-2026), [descriptive summary](../../tables/eda_descriptive_summary.csv) |
| [06_grouped_ppc_m0_m1a.R](06_grouped_ppc_m0_m1a.R) | Grouped predictive means, variances and densities | [PPC summary](../../tables/ppc_grouped_summary.csv), [PPC figures](../../figures/README.md#p1-grouped-ppc-figures-codep106_grouped_ppc_m0_m1ar-updated-26-nov-2026), [conclusions and limitations](../../docs/P1_PPC_NOTES.md) |

Scripts 05–06 resolve the repository root from the script location when run with `Rscript` (or from the active RStudio document). From the repository root, their commands are `Rscript code/P1/05_eda.R` and `Rscript code/P1/06_grouped_ppc_m0_m1a.R`; they write to `figures/` and `tables/` and can overwrite those outputs. This documentation audit did not run them.

Script 06 reads P2's [Gibbs draws](../../outputs/P2/M0_gibbs_draws.rds) and [training IDs](../../outputs/P2/M0_train_game_ids.csv), plus the archived [6,489-game M1a refit draws](../../archive/outputs/P5/M1a_WAIC_6489/parameter_draws.rds). The 6,416-game M1a draws are a separate fit and must not be substituted.

See [the P1 data guide](../../docs/P1_DATA_GUIDE.md) for input paths, local pipeline outputs, sampling rules and downstream use. P1's original technical notes are [preserved](../../docs/P1_PIPELINE_NOTES_2026-11-22.md).
