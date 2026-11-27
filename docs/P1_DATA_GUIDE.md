# P1 — Data and sampling guide

**Documentation updated 27 Nov 2026.** The actual P1 files stay at the **repository root**; this guide indexes them without changing their contents or locations. The [original P1 notes](P1_PIPELINE_NOTES_2026-11-22.md) are preserved separately.

## Published P1 files

| Root file | Scope | Role |
| --- | --- | --- |
| [`data_clean.csv`](../data_clean.csv) | 21,631 rows × 83 fields | Full joined/cleaned data, engineered covariates; source of truth for covariate models |
| [`variable_dictionary.csv`](../variable_dictionary.csv) | 83 variables | Type, missingness, range, meaning |
| [`dev_subsample.csv`](../dev_subsample.csv) | 6,489 games (30%) | Fixed game-level training/development sample |
| [`comparison_sample.csv`](../comparison_sample.csv) | 3,244 games (15%) | Fixed *holdout*, disjoint from development by game ID |

The public raw inputs are the [TidyTuesday 2022-01-25](https://github.com/rfordatascience/tidytuesday/tree/master/data/2022/2022-01-25) BGG `ratings.csv` (21,831 rows) and `details.csv` (21,631 rows). The inner join yields 21,631 games. **Raw inputs and intermediate RDS are not committed to this repository.**

## P1 scripts and reproduction

| Order | Existing root script | Purpose |
| --- | --- | --- |
| 1 | [`01_data_cleaning.R`](../01_data_cleaning.R) | Read `data/raw/details.csv` and `ratings.csv`; merge and clean; save `data/processed/big_clean.rds` |
| 2 | [`02_feature_engineering.R`](../02_feature_engineering.R) | Add categories, mechanics, designer IDs, standardized and capped predictors; save `big_features.rds` |
| 3 | [`03_sampling.R`](../03_sampling.R) | Fixed random split; exports 3 CSVs to local `output/` |
| 4 | [`04_variable_dictionary.R`](../04_variable_dictionary.R) | Generate `output/variable_dictionary.csv` |

The script headers may mention `script/`, but **the committed R scripts are at the repository root**. In RStudio, set the project root as working directory. Once the two original raw CSVs have been placed in `data/raw/`, run in order:

```bash
Rscript 01_data_cleaning.R
Rscript 02_feature_engineering.R
Rscript 03_sampling.R
Rscript 04_variable_dictionary.R
```

These commands generate intermediate objects under `data/processed/` and files under local `output/`; the copies currently shared on GitHub are at **root**. P1's original README reports byte-for-byte reproducibility after running the four scripts in R 4.5.3 (Windows), with seed **20261122**. This documentation did not independently rerun the pipeline.

## Key field decisions

- `yearpublished` outside 1900–2022 → missing, and game age uses the **2022** reference year; `log_game_age = log1p(game_age)`.
- Structural zero-as-unknown values for minimum/maximum players, play time and minimum age → missing.
- The original `average`, `users_rated`, `playingtime` and `maxplayers` values are preserved; separate `playingtime_capped` (600) and `maxplayers_capped` (36) derived columns preserve NAs.
- Twenty category and twenty mechanic dummy features; first-listed designer ID and multi-designer flag; missing and uncredited designers need explicit model handling.
- `z_game_age` is standardized **log age**, not raw age. Continuous standardizations and top-20 tag selection were calculated on the **full cleaned table before the split**, a caveat for strict holdout prediction.
- The raw `year` remains uncleaned; use `yearpublished` for modeling.
- Under the research plan `rank`, `bayes_average`, `owned`, `trading`, `wanting`, `wishing` must **not** be predictors; `bayes_average` is for benchmark comparison.

## Sample definition: important for everyone

In [`03_sampling.R`](../03_sampling.R), **3,244** holdout rows are drawn first, then **6,489** distinct development rows from the remainder. There is **zero game-ID overlap**, but **912 designer IDs** appear in both partitions. This does **not** validate performance for entirely unseen designers; P4 needs separate seen-/unseen-designer prediction handling.

`comparison_sample.csv` is **not a trainable comparison sample**. Despite the filename, its current meaning is **holdout**. Do not train on it and then report its accuracy as held out. The [archived 6,489-game M0/M1a/M1b comparison](../archive/outputs/P5/WAIC_Comparison_6489/README.md) is complete; the current [6,416-game matched-SD WAIC](../outputs/P5/WAIC_Comparison_6416/README.md) and [3,209-game exploratory holdout](../outputs/P5/Holdout_Comparison_3209/README.md) use their documented aligned samples and predictive targets.

P5's two shrinkage models use the same **6,416** games within development that match usable historical per-game rating SD; their exploratory holdout comparison uses **3,209** matched held-out games. P5's output and posterior draws are in [`outputs/P5`](../outputs/P5/). These development/holdout subsets are separate from the completed [21,375-game ranking handoff](../outputs/P5/P6_Full_Handoff/README.md), which reuses the fitted Extended parameters and conditions on each included game's observed rating. Neither scope is the full/current BGG catalogue.

**P1 analytical delivery is complete:** [Script 05](../code/P1/05_eda.R), [ten EDA figures](../figures/README.md#p1-eda-figures-05_edar-23-nov-2026), [descriptive statistics](../tables/eda_descriptive_summary.csv), [Script 06](../code/P1/06_grouped_ppc_m0_m1a.R), [grouped PPC summary](../tables/ppc_grouped_summary.csv) and [PPC notes](P1_PPC_NOTES.md) are committed. Scripts 05–06 read repository-relative inputs and write to `figures/` and `tables/`. See the [script index](../code/P1/README.md) for their input dependencies and the distinction from the root data-preparation pipeline.
