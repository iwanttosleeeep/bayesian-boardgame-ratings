# P4 diagnostic evidence and decisions — 23 November 2026

This supplements P4_BASELINE.md; it does not change the baseline likelihood or
priors. Holdout remains unused by all P4 fitting/diagnostic scripts.

## Original and extended 400-game chains

The original `outputs/P4/smoke` is preserved. `extended_400` reuses exactly its
IDs, order, feature recipe and model. Because original internal RNG states were
not saved, each chain was restarted at its own last parameter values with a new
explicit RNG seed, followed by 1,000 adaptation and 500 additional burn-in.
Only the 8,000 new retained draws per chain enter the extension diagnostics;
original draws are not silently concatenated.

All coefficients, named effects, scales and derived variance quantities pass
rank-normalized/folded split R-hat <=1.01, bulk/tail ESS >=400 and mean MCSE/SD
<=0.05. Maximum R-hat is 1.0046, minimum bulk ESS 531, minimum tail ESS 1,100.
Scale posterior means: tau 0.489, sigma_d 0.380, s 2.796.
Tau and sigma_d are strongly negatively correlated (-0.839); their squared sum
is much better identified. ACF plots show slow variance allocation mixing,
whereas s mixes faster but concentrates near its upper prior boundary.

## Full-structure recovery checks

Two fixed-truth simulated data sets each contain 2,000 games, the complete
covariate design, roughly 280 credited repeated designer groups, 200 missing and
200 uncredited games. Each named designer receives one shared effect; each
anonymous game receives an independent effect. Theta adds a separate game
residual, then observed mean ratings add noise s/sqrt(n). Both sets use
alpha=6.4, tau=0.55, sigma_d=0.4, s=1.8 plus nonzero continuous/tag coefficients.

Independent tests verify Gaussian conditional moments and empirical named-pair
versus anonymous-pair covariance over 20,000 replicates. Saved generator
measurement/latent standardized residuals have approximately unit SD. Both
posterior fits meet modern diagnostic thresholds at 2,000 retained draws/chain.

| Recovery measure | Replicate 1 | Replicate 2 |
|---|---:|---:|
| tau posterior mean | 0.542 | 0.591 |
| sigma_d posterior mean | 0.397 | 0.393 |
| s posterior mean | 1.322 | 1.126 |
| s 95% interval | [0.564, 2.069] | [0.530, 1.929] |
| theta RMSE / raw mean RMSE | 0.174 / 0.184 | 0.178 / 0.189 |
| theta posterior interval coverage | 88.45% | 84.05% |
| Oracle conditional theta coverage | 94.95% | 95.60% |
| Coefficient 95% interval coverage | 96.4% | 91.1% |
| Named designer effect interval coverage | 94.6% | 96.4% |

The scale recovery and covariance/oracle checks support the implementation, but
latent interval calibration is imperfect: s is low and weakly identified in both
replicates. No claim of universal recovery, nominal theta coverage or simulation-
based calibration follows from these two checks. A single tau interval missing
its truth is not, by itself, a sampler failure. The synthetic grouping is more
balanced than the actual development grouping; real-data mixing must be checked.

An execution mistake is recorded rather than hidden: editing the analysis script
while the original Rscript process was reading top-level expressions caused a
trailing parser error after both simulation results were saved. Current syntax
passes and both saved results were independently validated by
`M1b_simulation_review.R`. Future launches parse the whole script via source()
before evaluation; inference source is frozen during formal runs.

## Resource and review decisions

Development has 3,221 named designers: 2,320 singletons and 901 repeated groups.
Repeated groups contain 3,546 games and 16,210 pairs; pairs are not independent
information units. There are 623 missing/uncredited games. Full training builds
56 predictor columns and re-estimates all numeric preprocessing from these rows.

Read-only code review found an important Windows PID issue: bin/Rscript.exe is
only a launcher. The measured PID omitted the main interpreter's allocations.
A PID equality probe failed before the fix and passed after switching to
bin/x64/Rscript.exe. Both initial and corrected 2,000-game trials are retained.
Corrected pilot: 68.48 seconds, peak aggregate working set 917 MB; its deliberately
short 500-draw chains are not converged.

The official JAGS glm module blocks jointly Normal coefficients without changing
model or priors; sampler identities and run settings are saved. The corrected
pilot and full fits use this module; original/extended smoke and recovery checks
used the default sampler. Time/RAM projections are heuristics and actual full
resource measurements supersede them. With only about 8 GB free RAM at launch,
full baseline and sensitivity are scheduled sequentially. Available RAM is
checked during execution; a low-memory stop request is honored after checkpoint.

Review decisions: the main-process memory omission was fixed and tested. Source
snapshots and hashes were added to formal-run outputs; within-designer predictor
variation is audited separately. The remaining minor issue is that a refused
rerun can overwrite run logs before the posterior overwrite guard; do not rerun
a completed stage into the same output directory. Posterior artifacts themselves
are protected by the guard.

The reviewer did not assess scientific calibration from two replicates, future
full convergence, or a future holdout/new-designer prediction API. Those do not
constitute validated deliverables here: calibration caveats remain, convergence
will be measured, and no holdout prediction implementation is claimed.
