# STAT6106 Project — Data Preparation

## Pipeline (run in order)
1. 01_data_cleaning.R       — read raw BGG data, recode invalid years / zeros
                              to NA, produce big_clean.rds
2. 02_feature_engineering.R — feature engineering: category & mechanic
                              indicators, designer identifiers, capped / log /
                              standardized variables -> big_features.rds
3. 03_sampling.R            — construct dev_subsample and comparison_sample
4. 04_varibale_dictionary.R — export variable_dictionary.csv (83 variables)

## Reproducibility (verified 2026-11-22)
The full pipeline 01-04 was rerun end-to-end in R 4.5.3 (Windows): the
delivered data_clean.csv, dev_subsample.csv, comparison_sample.csv and
variable_dictionary.csv are EXACTLY the outputs of these four scripts with
seed 20261122. Re-running the scripts reproduces all four files byte-for-byte.

## Cleaning & feature rules
- Invalid years: yearpublished outside 1900-2022 set to NA (302 games).
- Zero values recoded to NA: minplayers (44), maxplayers (164),
  playingtime (774), minage (1,301).
- Outlier handling: NO winsorization/clipping is applied to any original
  variable. Outlier-robust versions are created as NEW derived columns:
  playingtime_capped (cap 600 min), maxplayers_capped (cap 36),
  log_playingtime, log_users_rated, game_age (reference year 2022),
  log_game_age. Capped columns KEEP NA where the original is unknown
  (fixed 2026-11-22: pmin no longer fills NA with the cap value).
- IMPORTANT: `average` and `users_rated` are completely unmodified
  (verified row-by-row against the merged raw data: 0 of 21,631 values
  changed). They can be used directly as model outcome / weight.
- Indicators: cat_* (20 categories), mech_* (20 mechanics) as 0/1 dummies,
  top-20 tags split from the raw strings with trimming. FIXED 2026-11-22:
  the first delivery contained duplicate/artifact indicator columns (e.g.
  'Card Game' x3, 'Bag and Pool Building' split in two) caused by a broken
  gsub character class; the pipeline now produces clean deduplicated
  indicators.
- Designer IDs: designer_first = first-listed designer; designer_id factor
  (7,131 unique after deduplication); multi_designer = 1 if >1 designer
  credited (5,817 games).
- Standardization: z_ prefix = (x - mean) / sd, computed on full data
  (z_log_users, z_game_age, z_log_play). NOTE: z_game_age standardizes
  log_game_age (the log of game age), matching the delivered data.
- `year` is the RAW publication year from the ratings table (not cleaned);
  it duplicates yearpublished where valid — use yearpublished for modelling.
- num.x / num.y (row-index artifacts from the raw merge): DROPPED.

## Data files
- data_clean.csv        — unified cleaned & engineered dataset
                          (21,631 rows x 83 variables).
                          THIS IS THE SINGLE SOURCE OF TRUTH for modelling.
- variable_dictionary.csv — definitions for all 83 variables, with n_missing,
                          missing ratio and value range per variable.
- dev_subsample.csv     — 6,489 rows (30% random sample of data_clean,
                          seed 20261122), model development & fitting.
- comparison_sample.csv — 3,244 rows (15% INDEPENDENT holdout, drawn first
                          from data_clean with the same seed; ZERO overlap
                          with dev_subsample), posterior predictive checks
                          and model comparison.
- big_clean.rds / big_features.rds — intermediate R objects (local only).
- Removed legacy files (in git history): data_merged.csv, details_cleaned.csv,
  ratings_cleaned.csv, model_sample.csv, model_train.csv, model_test.csv,
  data_dictionary.csv (renamed to variable_dictionary.csv).

## Sampling method (regenerated 2026-11-22 by 03_sampling.R in R)
- comparison_sample: 15% independent holdout (3,244 rows), drawn FIRST
  from data_clean with seed 20261122. It must NEVER be used for training;
  reserve it for posterior predictive checks and final model comparison.
- dev_subsample: 30% random sample (6,489 rows) drawn from the REMAINING
  85% of games, same seed. Row-level overlap with comparison_sample is 0.
  Both samples carry all 83 variables (subsets of data_clean.csv).
  Reproducible: re-running 03_sampling.R regenerates both files exactly.
- NOTE on designer leakage: the split is at row level, so 912 designer_ids
  appear in BOTH dev and comparison. If the multilevel model requires
  strict designer-group separation, re-draw comparison at the designer
  level instead (earlier plan: 60% of designers whole-group sampling).
