# Four-model exploratory holdout comparison (3,209 games)

Completed 24 November 2026; postprocessing only. All four fits use the same 6,416 training games. Direct checks of the four published CSVs confirm identical ordered 3,209 unique holdout IDs, observed averages, counts and historical SD where available. No refitting or tuning.

- [Summary](holdout_four_model_summary.csv) and [six paired differences](holdout_pairwise_differences.csv).
- Inputs: [P5 same-sample per-game comparison](../../../archive/outputs/P5/M1a_Model_Comparison/comparison_holdout_per_game.csv), [P5 original Extended holdout metadata](../M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv), [P4 metadata](../../P4/Holdout_3209/holdout_metadata.csv), [P4 paired LPD](../../P4/Holdout_3209/paired_log_predictive_density.csv), [P4 summary](../../P4/Holdout_3209/holdout_summary.csv).
- Reproduce from repository root using [14_Compare_Four_Models_Holdout_3209.R](../../../code/P5/14_Compare_Four_Models_Holdout_3209.R) (base R; no fitting).

ELPD (higher is better): M1b Baseline -3009.639, M1b ExternalSD -3024.698, M1a Extended -4126.125, M1a Baseline -4347.828. P5 uses 1,000 posterior draws per model in script 07, P4 uses 16,000. Do not substitute the earlier standalone Extended validation for the paired P5 comparison.

Pairwise SE uses 2,226 clusters: same named designer grouped together (seen/unseen status fixed), missing/uncredited games each separate. For game differences d_i, cluster score is sum(d_i - mean(d)) within cluster, and SE = sqrt(G/(G-1) * sum(cluster_score^2)). Intervals are descriptive normal approximations, not posterior credible intervals or formal significance tests. Shared posterior parameters, multiple comparisons and prior holdout exploration are not fully accounted for. The sample is game-disjoint, not designer-disjoint. Historical SD is a fixed plug-in of unverified date; target is observed mean rating conditional on count/covariates, not latent rating or a genuinely future forecast.

M1a Extended changes multiple components, so the gain cannot be attributed to historical SD alone. P4 isolates the observation-noise specification relative to an original-prior control with s near its upper bound; ExternalSD reduces shrinkage but has no demonstrated overall predictive advantage (ELPD difference -15.06; cluster SE 8.34). Both M1b models retain PPC misfit. M1b Baseline has the numerically highest holdout ELPD, not proof of a causal designer effect. See the [separate development WAIC comparison](../WAIC_Comparison_6416/README.md).
