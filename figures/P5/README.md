# P5 presentation figures — delivery manifest

**Status — 27 November 2026:** all **seven PNG figures are committed**. [Script 15](../../code/P5/15_Generate_P5_Figures.R) produces Figures 1–6 from saved results; [Script 16](../../code/P5/16_fig_measured_sd_vs_s.py) produces Figure 7. Neither script was run during this documentation audit.

| Figure filename | Slide purpose | Key scope |
| --- | --- | --- |
| [fig01_prior_posterior_s.png](fig01_prior_posterior_s.png) | Original M1a Baseline's noise parameter `s` concentrated near its U(0.5,3) prior upper bound | 6,416 development games; prior-sensitive inference |
| [fig02_rating_shrinkage.png](fig02_rating_shrinkage.png) | Median absolute rating adjustment by rating-count band, Baseline vs Extended | Same 6,416 development games; bars are interquartile ranges |
| [fig03_grouped_holdout_ppc.png](fig03_grouped_holdout_ppc.png) | Observed vs posterior predictive group means and variances | Four selected bands within 3,209 exploratory holdout games; group-level 95% predictive intervals |
| [fig04_sensitivity.png](fig04_sensitivity.png) | Historical SD multiplier and selected prior scenarios | 6,416 development games, only tested scenarios; Top-50 overlap applies to development rankings |
| [fig05_four_model_holdout.png](fig05_four_model_holdout.png) | Four-model exploratory holdout ELPD and within-family paired contrasts | Same 3,209 holdout games; paired intervals use approximate designer-cluster standard errors |
| [fig06_four_model_waic.png](fig06_four_model_waic.png) | Matched four-model development WAIC and pointwise warning rates | Same 6,416 development games; M1b WAIC conditions on learned designer effects and is less reliable |
| [fig07_measured_sd_vs_s.png](fig07_measured_sd_vs_s.png) | Historical per-game SD estimates versus Baseline s posteriors | 6,416 development games; supports smaller observation-noise values subject to unverified snapshot timing and fixed SD plug-ins |

**Current group-deck use:** Fig 1 is on main slide 7, Fig 7 on slide 8 and Fig 5 on slide 9. Figs 4, 6 and 3 appear on backups B1, B2 and B4 respectively; Fig 2 remains available for the report. The [assembled deck](../../slides/Group_deck_draft.pptx) has 15 main slides and 4 backups.

[Generated checks](P5_figure_checks.txt) are already committed with the local machine path redacted; they validate the 12,000-draw P5 inputs, ordered development IDs, training centering, rerun shrinkage medians, and model sample sizes. The check file records the original six-figure run; Figure 7 is documented by its separate script and the manifest above.

**Data and caveats:** See [P5 results](../../outputs/P5/README.md), [four-model holdout](../../outputs/P5/Holdout_Comparison_3209/README.md), and [four-model WAIC](../../outputs/P5/WAIC_Comparison_6416/README.md). The results do not establish causality; external historical SD is a fixed plug-in, with snapshot timing unverified. The holdout was previously explored, and model families differ in more than one component.
