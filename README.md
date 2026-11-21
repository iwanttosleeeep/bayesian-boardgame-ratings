# STAT6106 Project — Data Preparation

## Pipeline (run in order)
1. 01_clean.R        — read raw BGG data, recode invalid years / zeros to NA,
                       produce big_clean.rds
2. 02_features.R     — feature engineering: category & mechanic indicators,
                       designer identifiers, capped / log / standardized
                       variables -> big_features.rds
3. 03_samples.R      — construct dev_subsample and comparison_sample
4. 04_dictionary.R   — export variable_dictionary.csv (83 variables)

## Cleaning & feature rules
- Invalid years: yearpublished < 1500 or > 2026 set to NA (302 games).
- Zero values recoded to NA: minplayers (44), maxplayers (164),
  playingtime (774), minage (1,301).
- Outlier handling: NO winsorization/clipping is applied to any original
  variable. Outlier-robust versions are created as NEW derived columns:
  playingtime_capped (cap 600 min), maxplayers_capped (cap 36),
  log_playingtime, log_users_rated, game_age (reference year 2022),
  log_game_age.
- IMPORTANT: `average` and `users_rated` are completely unmodified
  (verified row-by-row against the merged raw data: 0 of 21,631 values
  changed). They can be used directly as model outcome / weight.
- Indicators: cat_* (20 indicators), mech_* (20 indicators) as 0/1 dummies,
  split from the raw tag strings. KNOWN ISSUE: tags were split without
  trimming whitespace, so the same tag produced duplicate columns
  (e.g. 'Card Game' x3, 'Wargame' x2, 'Dice Rolling' x2,
  'Hand Management' x2, 'Set Collection' x2, 'Simulation' x2), and the
  mechanic 'Bag and Pool Building' was wrongly split into mech_Bag +
  mech_and.Pool.Building. Merge or re-parse these before modelling.
- Designer IDs: designer_first = first-listed designer; designer_id factor
  (7,974 unique); multi_designer = 1 if >1 designer credited (5,817 games).
- Standardization: z_ prefix = (x - mean) / sd, computed on full data
  (z_log_users, z_game_age, z_log_play).
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

## Sampling method (redrawn 2026-11-21 for clean train/holdout separation)
- comparison_sample: 15% independent holdout (3,244 rows), drawn FIRST
  from data_clean with seed 20261122. It must NEVER be used for training;
  reserve it for posterior predictive checks and final model comparison.
- dev_subsample: 30% random sample (6,489 rows) drawn from the REMAINING
  85% of games, same seed. Row-level overlap with comparison_sample is 0.
  Both samples carry all 83 variables (subsets of data_clean.csv).
- NOTE on designer leakage: the split is at row level, so 854 designer_ids
  appear in BOTH dev and comparison. If the multilevel model requires
  strict designer-group separation, re-draw comparison at the designer
  level instead (earlier plan: 60% of designers whole-group sampling).
- model_train / model_test: separate legacy 80/20 random split of the
  full merged data (32-variable schema, no engineered features).
  WARNING: 29.9% of model_test ids also appear in dev_subsample — do NOT
  mix the two splitting schemes; use dev/comparison for the final report.
- Replaced files: previous dev/comparison versions (comparison was a
  subset of dev, breaking holdout independence) are superseded; they
  remain in git history if needed for audit.
