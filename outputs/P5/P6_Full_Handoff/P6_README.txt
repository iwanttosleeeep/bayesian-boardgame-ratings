STAT6106 P5 -> P6: FULL CLEANED-DATASET latent-rating handoff
Source outcome: P1 2022 data_clean.csv (21,631 games, users_rated >= 30).
SD source: AgeOfWar/AgeOfWar.github.io games.csv (original P5 working source).
Historical SD snapshot date and ultimate upstream provenance are NOT verified.
Model: M1a Extended trained on original 6,416 development games.
No new parameter fitting: 500 balanced existing parameter draws.
For ranking, concatenate P6_theta_draws_part_01.rds ... part_05.rds by COLUMNS.
Every file's theta_draws matrix has GAMES IN ROWS and JOINT POSTERIOR DRAWS IN COLUMNS.
The ordered id vector is identical across parts and P6_all_games_posterior_ratings.csv.
Rank within the included P1 2022 dataset ONLY; not across all games currently on BGG.
Per-game theta conditions on that game's OBSERVED raw mean and number of ratings.
This includes observed averages of the 2022 held-out games for latent reconstruction.
Do NOT use these conditional theta estimates as holdout prediction scores.
Prediction for unseen games is a separate, unconditional operation.
Historical SD is treated as a fixed plug-in and may be from a different date.
BGG bayes_average and BGG rank are benchmark fields, NOT model predictors.
Games without valid historical SD are excluded; consult the full matching audit.
M0/M1a/M1b matched training WAIC is a separate comparison (6,489 games).
