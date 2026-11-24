# P4: 3,209-game exploratory holdout validation

## Agreed scope and execution plan

Reuse only the two PR #5 posteriors in `outputs/P4/ExternalSD_6416/`:
`matched_baseline` (original s~Uniform(.5,3)) and `external_sd` (fixed historical
SD, no s). No fitting, tuning, training-output changes or WAIC computation.
Use an additive branch `p4/holdout-validation-3209` from main after PR #5 merged.

- [x] Recover P5's sample using its published SD audit and comparison-row order;
  verify 3,209 IDs, training disjointness, historical values and published observed
  grouped statistics. Hash inputs and protect all existing P4 files.
- [x] Test predictive moments, shared unseen-designer effects, independent
  anonymous effects, observation noise, response invariance and log-mean-exp;
  implement isolated prediction helpers after observing the tests fail.
- [x] Score all 16,000 retained draws/model in batches, loading one chain at a
  time. Export per-game predictions, paired log-density differences, grouped
  summaries and joint grouped PPC; retain full predictive draws locally.
- [x] Independently verify outputs and rereads, original-file hashes and Git scope.

Publication follows verification: push with verified SunshineSs920959 GCM
credentials and create a PR; do not push directly to main or merge it here.

## Data authority and exact order

P5's `04_Extended_holdout_validation.R` preserves `comparison_sample.csv` order
after matching historical BGGId and requiring finite y/n, n>=30, positive finite
StdDev and NumUserRatings. Its per-game holdout cache/IDs were not uploaded.
We reconstruct that sequence from P5's uploaded
`P6_Full_Handoff/P6_all_21631_SD_matching_audit.csv`, which its script 11 derives
from the same historical source and checks against every original training SD.
Script 11 permits a download fallback; byte identity with P5's unavailable
original holdout cache cannot be established. The published audit supplies the
exact SD/count values used here, and every development SD/count value agrees.
We never use P6's conditional theta values or posterior ratings for prediction.
Reconstruction is explicit, not a claim of direct byte comparison with P5's
unavailable per-game cache. Counts, observed moments and historical-count
discrepancy are checked against P5's published holdout tables.

## Predictive definition

Given one training parameter draw, mu=alpha+X beta+u_d for a seen named designer;
mu=alpha+X beta otherwise. Marginal predictive variance of observed game-average
y is tau²+v for seen designers and tau²+sigma_d²+v otherwise. v is s²/current n
for the original control, sd_hist²/current n for ExternalSD. Thus theta and new
designer effects are analytically integrated for pointwise predictive densities.

For joint prediction, draw one new N(0,sigma_d²) effect per distinct unseen named
designer per parameter draw and share it across that designer's games. Missing
and (Uncredited) games receive independent effects. Add independent residual and
observation noise with variance tau²+v. Posterior u for seen designers remains
draw-aligned. No holdout average enters preprocessing, mu or conditional theta.

Prediction intervals use all joint replicated observed averages; the predictive
mean averages conditional means, not noisy replications. Log predictive density
uses log-mean-exp of normalized Gaussian densities, not mean loglikelihood.
ELPD is the sum of these pointwise marginal log predictive densities, not the
joint log score of an entire designer group. Shared designers induce dependence;
no independent-game inferential SE or component-specific causal claim is made.

P5's selected count bands are 30–40, 100–200, 1000–5000, >5000. We retain those
and add 41–99 and 201–999 so the rating-count summary also partitions the sample.
PPC uses the same parameter draw jointly for every game, including correlated
new-designer effects, and compares observed group means and sample variances.

## Limits

The evaluation conditions on current rating count and covariates. Historical SD
is a fixed plug-in with unverified snapshot date and no estimation uncertainty.
First-listed-designer grouping and the original feature-selection limitations
remain. The team previously explored this holdout: this is exploratory validation,
not a pristine final test set. No holdout-driven model adjustments follow.

## Reproduction and local prerequisites

Validation is base R only; JAGS is not loaded or run. Tested with R 4.5.3.
Use your installed Rscript (`P4_RSCRIPT` or PATH), or the existing local P4 runtime.
The PowerShell wrapper uses the established runtime resolver, without installing
packages or changing global environment configuration.

The original **complete parameter posterior** files are local-only. Obtain the
genuine PR #5 files from the P4 owner and verify their SHA256 against
`outputs/P4/ExternalSD_6416/file_manifest.csv`. For **each** of matched_baseline
and external_sd, place `chain_1.rds` through `chain_4.rds`, `inputs.rds`,
`preprocessing.rds` and `run_settings.rds` under that model's existing directory.
This is 14 RDS files in total. Keep tracked model/diagnostic/ID files alongside
them. The 500-draw training likelihood share is insufficient to reproduce these
predictions; do not substitute the 6,489-game or prior-upper-6 parameter files.
No refitting is part of this validation workflow.

Commands below require a **fresh** `outputs/P4/Holdout_3209` execution directory.
The guards deliberately reject an existing run. In a separate disposable clone
or worktree, preserve the published directory by renaming it to
`Holdout_3209_reference` before reproducing; never clean or overwrite the working
copy containing the original training/posterior results. These commands are not
a request to rerun the completed validation in the owner workspace.

From the disposable checkout's repository root:

```powershell
# Only in that disposable checkout, if published validation outputs are present:
if (Test-Path -LiteralPath outputs/P4/Holdout_3209) {
    Rename-Item -LiteralPath outputs/P4/Holdout_3209 -NewName Holdout_3209_reference
}
. ./code/P4/P4_runtime.ps1
Initialize-P4Environment (Get-Location).Path
$r = Get-P4Runtime (Get-Location).Path
& $r --vanilla code/P4/M1b_holdout_checks.R
py -3 code/P4/M1b_holdout_integrity.py snapshot
py -3 code/P4/M1b_holdout_provenance.py capture
./code/P4/run_holdout.ps1 -Stage audit
# Sequential prediction/export only:
./code/P4/run_holdout.ps1 -Stage baseline
./code/P4/run_holdout.ps1 -Stage external
& $r --vanilla code/P4/M1b_holdout_report.R
& $r --vanilla code/P4/M1b_holdout_validate.R
py -3 code/P4/M1b_holdout_provenance.py verify
py -3 code/P4/M1b_holdout_integrity.py verify
py -3 code/P4/M1b_holdout_provenance.py package
```

Use `python` instead of `py -3` where appropriate (Python standard library only).
Stop on any command error. PowerShell wrappers throw on R process failure;
`$LASTEXITCODE` is for native executables and is not a wrapper status indicator.
Source manifests describe actual execution bytes, which can differ from Git LF
text because of checkout line endings. Capture a fresh manifest for a fresh
execution instead of falsely reusing this execution's source hash record.
The integrity snapshot is private and non-overwriting; take it once before the
new run, then verify it afterward. The later delivery helper's source hash is
recorded separately in postprocessing_sources.csv for this original execution.

Parameter source commit: `5512beeeb213a23e2de734c286254d075f237910` (PR #5).
Validation starts from merge commit `fa2d460a21beddef54ecab7bbb6ee52dac6fd138`.
Prediction seeds are 6320901–6320904 for baseline and 6321901–6321904 for ExternalSD.
All retained rows 1–4000 from each genuine chain are used, without thinning.
Batch size 128 and the RNG stream are recorded; the final partial batch has 32
draws and receives its correct weight in log-mean-exp accumulation.

Uploaded files are CSV summaries, per-game predictions, paired log-density
differences, IDs/maps, configurations, source hashes, validation records and this
documentation. `prediction_inputs.rds`, each model's `predictive_draws.rds`, logs
and sessionInfo remain ignored locally. The predictive RDS contains all 16,000
joint observed-average replicates with real chain/retained-row indices and grouped
mean/variance draws. Hash inventories list local-only files without download links.

## Recorded results and interpretation

Full tables and per-game files: [execution README](../outputs/P4/Holdout_3209/README.md).
There are 1,793 seen named, 1,105 unseen named, 88 missing and 223 uncredited
games. Unseen names comprise 1,013 groups, 75 repeated across holdout games.

| Measure | Same-6,416 original M1b | M1b-ExternalSD |
|---|---:|---:|
| Holdout games | 3,209 | 3,209 |
| Used parameter draws | 16,000 | 16,000 |
| Holdout ELPD | -3009.638870 | -3024.698182 |
| 95% predictive coverage | 94.3596% | 94.3596% |
| Mean interval width | 2.408040 | 2.410551 |
| Prediction + export seconds | 27.63 | 23.82 |
| Sampled peak process working set MiB | 1103.06 | 1102.79 |

ExternalSD minus original ELPD is **-15.059312**, with no independent-game
inferential SE attached. Four single-chain density estimates yield ELPD ranges
[-3010.219,-3009.232] and [-3025.512,-3024.366], respectively. This describes
Monte Carlo variation, not a confidence interval for generalization performance.

ExternalSD gains pointwise score in the three bands up to 200 ratings but loses
score in the higher-count bands; most of the designer-partition score loss is in
unseen named games (-12.144). This is descriptive, not a causal decomposition.
The equal overall coverage percentages do not mean the same games are covered.
For n=30–40, coverage declines from 93.97% to 92.46% while intervals narrow.
For n>5000, coverage increases from 94.55% to 98.18% and intervals widen.

Both models' observed mean lies inside all four P5 count-band PPC mean intervals;
both contain the observed variance in only the two lower P5 bands. High-count
variance remains overpredicted (n>5000 observed variance 0.241, original interval
[0.373,0.604], ExternalSD [0.418,0.688]). The added 41–99 band underpredicts
variance in both; the added 201–999 band has a mean discrepancy in both and a
variance discrepancy in ExternalSD. Missing-designer coverage remains low
(89.77% / 90.91%). These checks do not support a blanket improvement claim.

The independently checked scalar mixtures, total predictive moments, intervals
and joint PPC agree within 2.8e-14. A read-only review found no statistical or
array/batching blocker; its missing-reproduction-instructions finding is addressed
above. P5's unavailable original per-game cache remains an explicit provenance
limit. A missing terminal newline in P5's published PPC CSV produces an innocuous
R reader warning; that member file was preserved. Prediction scripts themselves
completed with empty error logs. No model or prior was changed after validation.
