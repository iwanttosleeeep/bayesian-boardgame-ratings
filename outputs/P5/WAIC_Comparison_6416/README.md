# Four-model matched development WAIC (6,416 games)

Completed 24 November 2026. All four models score the same game-average outcome on the same matched development IDs, with 500 posterior draws per model (125 per chain). No new fits. The original 6,489-game M0/M1a/M1b comparison remains separate and unchanged.

| Model | WAIC | Games with pointwise p-WAIC > 0.4 |
|---|---:|---:|
| M1b ExternalSD | 11758.52 | 948 / 6416 (14.78%) |
| M1b Baseline | 11766.70 | 858 / 6416 (13.37%) |
| M1a Extended | 16509.03 | 2 / 6416 (0.03%) |
| M1a Baseline | 17222.01 | 0 / 6416 |

- [Summary](WAIC_four_model_summary.csv), [paired differences](WAIC_pairwise_differences.csv), [gamewise diagnostics](WAIC_gamewise_diagnostics.csv), [checks and limitations](WAIC_interpretation_and_checks.txt).
- [Original executed R script](../../../code/P5/13_Compare_Four_Models_WAIC_6416.R). Retains legacy local P5 cache paths; read the script for required saved inputs and P4 RDS selection.
- P4 likelihoods: [matched comparison](../../P4/ExternalSD_6416/README.md).
- Primary predictive comparison: [aligned exploratory holdout ELPD](../Holdout_Comparison_3209/README.md).

ExternalSD minus Baseline WAIC is -8.18 for M1b (gamewise approximate paired SE 24.96), versus -712.99 for M1a Extended (SE 66.66). These SEs do not account for designer dependence. M1b integrates game theta, conditions on learned named designer effects, and integrates independent anonymous effects; WAIC warnings are substantial. Neither numerical ranking nor the small M1b WAIC difference establishes predictive superiority. M1a Extended saved RDS has no independent ID vector, and its provenance check relies on the original training file and centering. Historical SD timing is unverified; uncertainty is not propagated. Do not compare WAIC across the two training sample sizes or across rating and count outcomes.
