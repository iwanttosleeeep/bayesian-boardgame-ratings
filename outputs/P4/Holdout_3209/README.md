# P4: exploratory holdout validation on 3,209 games

Only the PR #5 same-6,416-game matched_baseline and external_sd posteriors are reused. No refitting or tuning. Original 6,489-game models, upper-6 sensitivity, training PPC and WAIC files are unchanged.

Sample: comparison_sample.csv order, filtered using P5's published full historical SD matching audit and its exact validation rule. P5's individual holdout cache was not uploaded; this reconstruction matches its published group counts/observed moments and rating-count-discrepancy share. See [sample checks](sample_validation.txt), [IDs](holdout_ids.csv), [metadata](holdout_metadata.csv), [matching audit](holdout_matching_audit.csv) and [source SHA256](source_manifest.csv).

## Full-posterior evaluation

All 4×4,000 retained parameter draws/model are used, one chain at a time in batches of 128. No parameter thinning or subset selection. Pointwise density analytically integrates theta/new designer effects; joint replicates share each unseen named designer effect and keep anonymous effects independent.

| Model | Games | Holdout ELPD | 95% coverage | Mean interval width |
|---|---:|---:|---:|---:|
| matched_baseline | 3209 | -3009.639 | 94.36% | 2.408 |
| external_sd | 3209 | -3024.698 | 94.36% | 2.411 |

Paired pointwise ELPD difference (ExternalSD minus original): **-15.059**. This is holdout ELPD, not WAIC. [Per-game paired values](paired_log_predictive_density.csv) are supplied to P5; no cross-model ranking is published here.
No inferential SE is reported: games share seen/new designers. Individual-game independence would be an insufficient uncertainty assumption. Per-chain log predictive densities are retained to inspect Monte Carlo variation; they are not independent-game uncertainty intervals.

## Designer and rating-count summaries

| Model | Group | Games | ELPD | Coverage | Mean width |
|---|---|---:|---:|---:|---:|
| matched_baseline | designer/seen_named | 1793 | -1448.366 | 95.04% | 2.174 |
| matched_baseline | designer/unseen_named | 1105 | -1184.969 | 93.76% | 2.683 |
| matched_baseline | designer/missing | 88 | -128.923 | 89.77% | 2.837 |
| matched_baseline | designer/uncredited | 223 | -247.381 | 93.72% | 2.758 |
| matched_baseline | n/30-40 | 398 | -447.564 | 93.97% | 2.968 |
| matched_baseline | n/41-99 | 951 | -1085.745 | 93.17% | 2.628 |
| matched_baseline | n/100-200 | 600 | -570.609 | 93.33% | 2.322 |
| matched_baseline | n/201-999 | 838 | -674.616 | 95.35% | 2.161 |
| matched_baseline | n/1000-5000 | 312 | -170.956 | 97.76% | 2.019 |
| matched_baseline | n/5000+ | 110 | -60.150 | 94.55% | 1.934 |
| external_sd | designer/seen_named | 1793 | -1451.131 | 94.81% | 2.172 |
| external_sd | designer/unseen_named | 1105 | -1197.113 | 93.94% | 2.703 |
| external_sd | designer/missing | 88 | -128.220 | 90.91% | 2.777 |
| external_sd | designer/uncredited | 223 | -248.234 | 94.17% | 2.736 |
| external_sd | n/30-40 | 398 | -444.463 | 92.46% | 2.660 |
| external_sd | n/41-99 | 951 | -1075.906 | 92.74% | 2.505 |
| external_sd | n/100-200 | 600 | -567.349 | 93.50% | 2.371 |
| external_sd | n/201-999 | 838 | -684.136 | 95.94% | 2.315 |
| external_sd | n/1000-5000 | 312 | -187.065 | 97.76% | 2.227 |
| external_sd | n/5000+ | 110 | -65.779 | 98.18% | 2.160 |

Seen/unseen classification uses the actual 6,416-game designer map, not the 6,489-game fit. Missing and (Uncredited) are separate groups. [Unseen-name mapping](unseen_designer_mapping.csv) records repeated unseen designers.
P5's selected count bands are 30–40, 100–200, 1000–5000 and >5000; the two added complementary bands make the count summary exhaustive.

## Joint grouped PPC

| Model | Group | Observed mean within 95% replicated interval | Observed variance within 95% replicated interval |
|---|---|---|---|
| matched_baseline | all | TRUE | TRUE |
| matched_baseline | designer/seen_named | TRUE | FALSE |
| matched_baseline | designer/unseen_named | TRUE | FALSE |
| matched_baseline | designer/missing | TRUE | FALSE |
| matched_baseline | designer/uncredited | TRUE | TRUE |
| matched_baseline | n/30-40 | TRUE | TRUE |
| matched_baseline | n/41-99 | TRUE | FALSE |
| matched_baseline | n/100-200 | TRUE | TRUE |
| matched_baseline | n/201-999 | FALSE | TRUE |
| matched_baseline | n/1000-5000 | TRUE | FALSE |
| matched_baseline | n/5000+ | TRUE | FALSE |
| external_sd | all | TRUE | TRUE |
| external_sd | designer/seen_named | TRUE | FALSE |
| external_sd | designer/unseen_named | TRUE | TRUE |
| external_sd | designer/missing | TRUE | FALSE |
| external_sd | designer/uncredited | TRUE | TRUE |
| external_sd | n/30-40 | TRUE | TRUE |
| external_sd | n/41-99 | TRUE | FALSE |
| external_sd | n/100-200 | TRUE | TRUE |
| external_sd | n/201-999 | FALSE | FALSE |
| external_sd | n/1000-5000 | TRUE | FALSE |
| external_sd | n/5000+ | TRUE | FALSE |

[Full grouped PPC](holdout_grouped_PPC.csv) contains observed values and numerical intervals. Each row derives from whole-sample joint replications with a common parameter draw and the correct designer dependence. These are holdout observed-average predictions, not training PPC or conditional theta intervals.

## Reproduction, storage and limits

[Specification and commands](../../../docs/P4_HOLDOUT_3209.md). Each model directory contains holdout_game_predictions.csv, holdout_summary.csv, holdout_grouped_PPC.csv, draw_index.csv, run_configuration.csv, chain_log_predictive_density.csv, memory_samples.csv and validation.txt.
[Implementation/final checks](final_validation.txt), [original-file protection](protection_validation.txt) and [export hashes](file_manifest.csv) document validation. source_manifest.csv records actual execution bytes (including local complete posterior files); exported text hashes use Git LF normalization.
Local-only ignored files: prediction_inputs.rds and each model's predictive_draws.rds, plus logs/sessionInfo. Joint draws are rows=real chain/retained-row draws and columns=ordered games. Their sizes/hashes are inventoried, not download links; regenerate with the documented commands and the original local parameter chains. CSV summaries cannot reconstruct a joint posterior.

The target is observed average rating conditional on current n and covariates. Historical SD remains a fixed plug-in with unverified snapshot date and ignored estimation uncertainty. Shared/new-designer effects are associations. Feature-selection and first-listed-designer limitations persist. The team explored this holdout earlier, so this is not a pristine untouched final test. No validation-driven model changes are made.
