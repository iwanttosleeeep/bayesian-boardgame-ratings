# STAT6106 Project — Data Preparation

## Pipeline (run in order)
1. 01_clean.R        — read raw BGG data, clean invalid years / zeros /
                       extremes, produce big_clean.rds
2. 02_features.R     — feature engineering: category & mechanism
                       indicators, designer identifiers, standardized
                       continuous variables -> big_features.rds
3. 03_samples.R      — construct dev_subsample and comparison_sample
4. 04_dictionary.R   — export data_dictionary.csv (83 variables)

## Cleaning & feature rules
- Invalid years: year < 1500 or year > 2026 set to NA
- Zero values: users / average rating = 0 recoded to NA
- Extremes: continuous variables winsorized at 1st/99th percentile
- Indicators: cat_* (28 categories), mech_* (31 mechanisms) as 0/1 dummies
- Designer IDs: designer_id factor; multi_designer = 1 if >1 designer
- Standardization: z_ prefix = (x - mean) / sd, computed on full data

## Sampling method (proposal rule 7)
- dev_subsample: whole-group sampling by designer. 7,975 unique designers;
  60% (4,785) drawn at random with seed 20261122; ALL games of selected
  designers retained -> 12,986 games. Group sampling preserves the
  within-designer correlation structure required for the multilevel model.
- comparison_sample: complete cases on M1b covariates (12,738 of 12,986),
  then 5,000 games drawn at random (same seed).

## Data files
- data_clean.csv        — full cleaned & engineered dataset (21,631 rows).
                          THIS IS THE UNIFIED CLEANED DATASET used for all
                          modelling; dev/comparison samples are subsets.
- dev_subsample.csv     — 12,986 rows, model development & fitting.
- comparison_sample.csv — 5,000 rows, posterior predictive checks and
                          model comparison.
- big_clean.rds / big_features.rds — intermediate objects (reproducibility).
- data_dictionary.csv   — definitions for all 83 variables incl. derived
                          indicators, with n_missing per variable.
- Note: previous files (data_merged.csv, model_sample.csv, train/test splits)
  have been removed; data_clean.csv is the single source of truth.

## Notes on variable definitions
- minage: minimum recommended player age (0 recoded to NA; 1,301 missing).
- year: year the game was published (from ratings table).
- num.x / num.y: row-index artifacts from the raw merge; DROPPED.
