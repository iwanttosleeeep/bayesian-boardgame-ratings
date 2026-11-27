# Repository documentation and reference audit — 27 November 2026

All six members have completed their core analytical deliverables. The committed [group deck](../slides/Group_deck_draft.pptx) contains 15 main slides and 4 backups. This audit checked files, source paths and PPTX XML read-only: no model fitting, analytical script execution, figure regeneration or deck rebuild was performed.

## Verified repository references

| Area | Verified location and scope |
| --- | --- |
| P1 pipeline | Root Scripts 01–04, including [04_variable_dictionary.R](../04_variable_dictionary.R), and all four shared root CSVs are present. Raw source CSVs and intermediate pipeline RDS remain local reproduction requirements. |
| P1 EDA / PPC | [Scripts 05–06](../code/P1/README.md), root data inputs, P2 training IDs/Gibbs draws and the archived [6,489-game M1a draws](../archive/outputs/P5/M1a_WAIC_6489/parameter_draws.rds) exist. The EDA and PPC tables/figures are committed. |
| P2 plots and results | Corrected interval [PNG](../figures/M0_three_method_intervals.png) and [SVG](../figures/M0_three_method_intervals.svg), CAVI results and comparison tables exist. Committed posterior/share files are under [outputs/P2/](../outputs/P2/), distinct from older local output paths. |
| P3 documentation | [Handoff](P3_HANDOFF.md) and [reproduction guide](P3_REPRODUCE.md) are in `docs/`; active links resolve there. |
| P5 archived evidence | Both RDS files exist in the [6,489-game refit](../archive/outputs/P5/M1a_WAIC_6489/README.md). Script 10's archived likelihood/ID inputs, Script 14's archived holdout input, and Script 15's archived summary inputs resolve. The [three-model WAIC comparison](../archive/outputs/P5/WAIC_Comparison_6489/README.md) is complete. |
| P5 current deliverables | All [seven PNGs](../figures/P5/README.md), current comparison/sensitivity folders and [full-scope handoff](../outputs/P5/P6_Full_Handoff/README.md) exist, including all five joint-draw RDS parts. The earlier 6,416-game ranking comparison is distinct from the completed 21,375-game ranking handoff. |
| P6 presentation | All [seven PNGs](../outputs/P6/README.md#5-figures) and the current [group builder](../code/P6/04_make_group_deck.py) exist. Its CSV and figure inputs resolve. The former standalone deck/builder are absent, with no active links to them. |

All **360 relative links across 38 Markdown files**, including **11 heading fragments**, resolve against actual files/headings. A focused static check resolved **95 source-path references** for the reorganised P1/P5/P6 consumers and P4's archived P5 peers; all checked paths exist. This is a path-presence check, not runtime or model validation. No broken relative file links were found at the start; the stale plain-text EDA invocation was corrected to `Rscript code/P1/05_eda.R`, figure paths were made clickable, and current-status links now target the README rather than the historical team plan. Added and updated links were checked again before committing.

## Remaining issues

These are reproduction or presentation follow-ups, not missing core analytical deliverables. Analytical code and existing outputs are unchanged.

| Location | Unresolved issue / required context |
| --- | --- |
| [P2 M0 runner](../code/P2/M0_run.R) | `DATA_PATH` is `../../data/dev_subsample.csv` from `code/P2/`; that file is absent because shared data live at root. Its fallback still names `code/P2_m0/`, so a direct repository-root launch can also fail to find helper scripts. The runner has no download fallback. |
| [P2 likelihood exporter](../code/P2/M0_make_share_loglik.R) | Uses the same absent `data/dev_subsample.csv` path and old directory fallback, and expects `outputs/M0_train_game_ids.csv` plus full `outputs/M0_loglik_{gibbs,jags}.rds` caches. Those local inputs are absent; committed IDs and 500-draw shares live under `outputs/P2/`. Full likelihood caches were not moved or regenerated. |
| [P2 CAVI / timing workflow](../code/P2/README.md) | The documented shell commands must run from `code/P2/`; these runners source sibling files and use `../../outputs/P2`, `../../figures` and `../../tables`. Do not interpret those output strings relative to a repository-root shell launch. |
| [Original P5 workflow](../outputs/P5/README.md#running-scripts-and-legacy-local-cache-paths) | Scripts 02–08 and 13 depend on local `P5_external_SD/` data/cache paths rather than consuming all committed folders directly. Some historical source caches are uncommitted. Scripts 10, 14–16 and the P6 consumers have the checked repository inputs; Script 11 can use repository inputs and download/cache its external historical source. This is not a complete offline, single-command reproduction package. |
| [P4 likelihood exporter](../code/P4/M1b_export_WAIC_6489.R) | Its archived P5 peer paths resolve, but regeneration also requires local P4 `inputs.rds`, `pointwise_loglik.rds` and `chain_*.rds` under `outputs/P4/baseline_development/`. These are not committed; the saved 500-draw shared likelihood is present. P4's established evidence trail was not edited. |
| [Group deck / builder](../docs/P6_DELIVERY.md#4b-assembled-group-deck--15-main-slides--4-backups) | Main slides 8, 9, 13 and 15, plus slide 13's notes, retain stronger wording about historical SD, sampling noise or shrinkage depending only on rating count. The builder contains the same wording. The documentation now qualifies these claims; the PPTX and builder were deliberately left unchanged as requested. |

The [24 Nov team plan](TEAM_PLAN_AND_STATUS.md), including its historical checklist, is untouched. Archived results and specifications are preserved; only a current-status note was added above the archived refit's historical pending-upload statements. Optional future analyses remain optional, and deadlines, speaker assignments and the agreed presentation structure are unchanged.
