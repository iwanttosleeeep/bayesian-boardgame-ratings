# P5 presentation figures — delivery manifest

**Status:** six figures generated locally on 25 November 2026, all plots visually reviewed. The image binaries are **not yet committed here**; upload the six PNG files listed below into this directory. `code/P5/15_Generate_P5_Figures.R` reproduces them using the original local P5 cache or the repository inputs, without refitting models.

| Figure filename | Slide purpose | Key scope |
| --- | --- | --- |
| `fig01_prior_posterior_s.png` | Original M1a Baseline's noise parameter `s` concentrated near its U(0.5,3) prior upper bound | 6,416 development games; prior-sensitive inference |
| `fig02_rating_shrinkage.png` | Median absolute rating adjustment by rating-count band, Baseline vs Extended | Same 6,416 development games; bars are interquartile ranges |
| `fig03_grouped_holdout_ppc.png` | Observed vs posterior predictive group means and variances | Four selected bands within 3,209 exploratory holdout games; group-level 95% predictive intervals |
| `fig04_sensitivity.png` | Historical SD multiplier and selected prior scenarios | 6,416 development games, only tested scenarios; Top-50 overlap applies to development rankings |
| `fig05_four_model_holdout.png` | Four-model exploratory holdout ELPD and within-family paired contrasts | Same 3,209 holdout games; paired intervals use approximate designer-cluster standard errors |
| `fig06_four_model_waic.png` | Matched four-model development WAIC and pointwise warning rates | Same 6,416 development games; M1b WAIC conditions on learned designer effects and is less reliable |

**Suggested 1 December presentation order:** Fig 2 (shrinkage), Fig 5 (main predictive comparison), Fig 6 (WAIC caveats); optionally Fig 1 (identification limitations). Figs 3 and 4 can be backup or report figures. Avoid squeezing all six figures into the group deck.

Generated checks: `P5_figure_checks.txt` validates the 12,000-draw P5 inputs, ordered development IDs, training centering, rerun shrinkage medians, and model sample sizes. Upload the checks file along with the figures.

**Data and caveats:** See [P5 results](../../outputs/P5/README.md), [four-model holdout](../../outputs/P5/Holdout_Comparison_3209/README.md), and [four-model WAIC](../../outputs/P5/WAIC_Comparison_6416/README.md). The results do not establish causality; external historical SD is a fixed plug-in, with snapshot timing unverified. The holdout was previously explored, and model families differ in more than one component.
