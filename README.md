# STAT6106 Project — Data Preparation

## Pipeline (run in order)
1. 01_clean.R        — read raw BGG data, recode invalid years / zeros to NA,
                       produce big_clean.rds
2. 02_features.R     — feature engineering: category & mechanic indicators,
                       designer identifiers, capped / log / standardized
                       variables -> big_features.rds
3. 03_samples.R      — construct dev_subsample and comparison_sample
4. 04_dictionary.R   — export data_dictionary.csv (83 variables)

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
- data_dictionary.csv   — definitions for all 83 variables, with n_missing,
                          missing ratio and value range per variable.
- details_cleaned.csv   — cleaned details table (21,631 rows x 23 vars).
- ratings_cleaned.csv   — cleaned ratings table (21,631 rows x 10 vars;
                          pre-filtered to users_rated >= 30).
- data_merged.csv       — raw merge of details + ratings
                          (21,631 rows x 32 vars), kept for audit.
- dev_subsample.csv     — 6,489 rows (30% random sample, seed 20261122),
                          model development & fitting.
- comparison_sample.csv — 3,244 rows (15% random sample drawn WITHIN
                          dev_subsample), posterior predictive checks and
                          model comparison.
- model_sample.csv      — alias of the full merged data (21,631 rows).
- model_train.csv       — 17,305 rows (80% split of model_sample).
- model_test.csv        — 4,326 rows (20% split of model_sample).
- big_clean.rds / big_features.rds — intermediate R objects (local only).

## Sampling method (as actually delivered)
- dev_subsample: 30% simple random sample of the 21,631 games
  (6,489 rows). NOTE: the earlier plan of whole-group sampling by
  designer (60% of designers) was NOT applied — designer_ids appear in
  both dev and holdout (1,797 overlap). If the multilevel model requires
  designer-group sampling, re-draw the sample.
- comparison_sample: 15% random sample drawn within dev_subsample
  (3,244 rows), same seed.
- model_train / model_test: 80/20 random split of the full data.
