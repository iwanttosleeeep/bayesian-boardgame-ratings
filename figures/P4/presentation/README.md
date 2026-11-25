# P4: two presentation-ready figures for P6

Only the verified PR #5 **same-6,416-development-game** original-prior M1b and
M1b-ExternalSD are shown. No fitting, model changes, new holdout evaluation or
deck edits. Original 6,489-game and s-upper-6 results are not used.

## Files and shared styling

| Figure | High-resolution PNG | Vector PDF |
|---|---|---|
| Shrinkage and rating count | [PNG](fig1_shrinkage_by_rating_count.png) | [PDF](fig1_shrinkage_by_rating_count.pdf) |
| Designer effects and uncertainty | [PNG](fig2_designer_effects.png) | [PDF](fig2_designer_effects.pdf) |

Both use 16:9 layout, 3200×1800 PNG (200 dpi; 16×9 inches) and matching vector PDF.
Insert at original aspect ratio; PDF is scalable. P6's `00_theme.R` / deck helpers
specify blue #2a78d6, orange #eb6834, off-white #fcfcfb and sans typography. These
are reproduced with base R/Cairo, avoiding an unnecessary ggplot2 installation.
The model legend has consistent colors and distinct circle/diamond symbols.
No team template or other member's files were modified.

## Figure 1 — caption and takeaway

**English caption:** Median absolute posterior rating adjustment by rating-count
band for the same 6,416 development games. Bars show interquartile ranges across
games, not posterior credible intervals.

**English takeaway:** Low-count games receive the largest adjustments. For games
with 30–40 ratings, the median falls from 0.2135 under M1b baseline to 0.0710 under
ExternalSD; this describes training shrinkage, not predictive superiority.

**中文解释：** 评分人数较少的游戏调整更明显，ExternalSD 下调整减弱。竖线表示组内游戏的四分位差异，不是后验可信区间。

Data: `outputs/P4/ExternalSD_6416/{matched_baseline,external_sd}/balanced_latent_summary.csv`.
These use the existing Rao–Blackwell posterior-mean estimates from 500 balanced
parameter draws (125 real retained rows per chain); no new posterior computation.
Adjustments are abs(mean − raw), grouped into six exhaustive count bands. X is
logarithmic, with each group plotted at its median n; colors are offset by ±3%
only for readability. Lines connect group medians, not a fitted regression.
The 30–40 band contains 778 games; exact medians 0.213519539462971 and
0.0709525801649646 agree with the saved comparison report. Complete plotted values
and game counts: [shrinkage_plot_data.csv](shrinkage_plot_data.csv).

## Figure 2 — caption and takeaway

**English caption:** Posterior mean designer effects and 95% credible intervals
for the 14 named designers with the most training games. Both models use the
same designers; n gives their game counts in the 6,416-game development sample.

**English takeaway:** For these frequently represented designers, effect estimates
are similar across the two models, with substantial uncertainty. These are
associations after controlling for game features, not a causal ranking of ability.

**中文解释：** 按训练游戏数最多选择14位设计师，而非按效应大小挑选。两模型的效应估计接近且存在不确定性；不能将其当作设计师能力的因果排名。

Selection is descending training-game count, then UTF-8 name byte order for ties;
the displayed order follows that rule. Counts range from 21 to 97. The original
model's first-listed-designer grouping is retained. Posterior means and equal-tail
95% intervals are copied directly from the full-four-chain, 16,000-draw saved
`comparison/designer_effects.csv`; intervals are never estimated from mean/SD.
Zero is a reference, not a cutoff for a causal or multiple-comparison ranking.
Exact values: [designer_plot_data.csv](designer_plot_data.csv).

## Reproduction and verification

Run from repository root with your own Rscript (base R with Cairo; no JAGS needed):

```powershell
. ./code/P4/P4_runtime.ps1
Initialize-P4Environment (Get-Location).Path
$r = Get-P4Runtime (Get-Location).Path
& $r --vanilla code/P4/M1b_presentation_figures.R
```

All source CSVs are already tracked: no local posterior RDS is needed. The script
only writes this presentation directory and refuses mismatched samples via
assertions. [Validation](validation.txt), source SHA256 and file SHA256 inventories
document the selected source/result files. The PNGs and rasterized PDF pages were
opened for visual inspection; all six count labels, all 14 designer labels,
legends and captions were checked for overlap/clipping. This check corrected an
initial auto-suppressed count label before delivery.

Historical SD remains a fixed plug-in of unverified snapshot date. The baseline
retains its original s prior and constant tau; these training figures do not
establish that ExternalSD is better overall. No training, WAIC or holdout files
are replaced by this delivery.
