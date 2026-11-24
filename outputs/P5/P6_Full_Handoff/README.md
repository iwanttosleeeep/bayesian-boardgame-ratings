# P5 to P6: Full cleaned-dataset ranking handoff

**Status (24 Nov 2026):** Four CSV/TXT files uploaded. **Five RDS posterior-draw parts still pending manual upload.** Ranking posterior intervals and Top-10 probabilities need the RDS parts.

## Statistical scope

- Source: P1 cleaned 2022 BoardGameGeek table, 21,631 games with at least 30 ratings; not the entire/current BGG catalogue.
- Historical SD source: same AgeOfWar/AgeOfWar.github.io games.csv used in the original P5 Extended model. Historical snapshot date and ultimate upstream provenance remain unverified.
- Historical SD valid matches: **21,375 / 21,631 (98.82%)**; 256 unmatched or invalid.
- Model: M1a Extended parameter posterior fitted on **6,416 development games**; no parameter refitting for this handoff.
- Full-scope conditional theta estimation uses each included game's observed 2022 mean, rating count and external historical SD, plus common posterior parameter draws.
- The check file reports 12,000 fitted parameter draws and **500 joint theta-draw columns**.

## Files already uploaded

| File | Contents |
| --- | --- |
| [P6_README.txt](P6_README.txt) | Original model/run notes and statistical caveats |
| [P6_full_handoff_checks.csv](P6_full_handoff_checks.csv) | Counts, matching rate and draw counts |
| [P6_all_21631_SD_matching_audit.csv](P6_all_21631_SD_matching_audit.csv) | Audit of all 21,631 games and SD matching status |
| [P6_all_games_posterior_ratings.csv](P6_all_games_posterior_ratings.csv) | Posterior rating summaries and BGG benchmarks for 21,375 matched games |

## Pending binary files (upload them to this SAME directory)

- `P6_theta_draws_part_01.rds`
- `P6_theta_draws_part_02.rds`
- `P6_theta_draws_part_03.rds`
- `P6_theta_draws_part_04.rds`
- `P6_theta_draws_part_05.rds`

The [P5 generation script](../../../code/P5/11_Export_Full_Cleaned_Data_Theta_for_P6.R) writes a 500-column joint posterior draw matrix in five 100-column RDS parts. In each file, rows are game IDs in the original order and columns are joint posterior draws. P6 must confirm the ID vectors match in every part, then **concatenate the five matrices by columns** and rank games together *within each column*. The summary CSV does not suffice for rank credible intervals or Top-10 probabilities.

## Important limitations

- Ranking scope is 21,375 SD-matched games in the cleaned 2022 BGG dataset, **not all BGG games**, and not necessarily current site rankings.
- Conditional theta estimates use observed ratings of all included games, including games in the previous holdout; **do not present these as untouched holdout predictions**.
- Historical per-game SD values are fixed plug-ins from an unverified snapshot.
- BGG `bayes_average` and `rank` fields are benchmarks, not model predictors.
