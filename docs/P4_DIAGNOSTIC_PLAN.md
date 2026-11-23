# P4 diagnostic and full-development execution plan — 23 November 2026

Authority: P4_BASELINE.md and the user's six-point follow-up. Continue on p4/m1b
with the existing uncommitted P4 work; preserve the original smoke directory.
No holdout reads and no changes to other members' files.

1. Add modern posterior diagnostics and checks for chain separation, anonymous
   variance integration, and repeated-designer covariance. Validate these before
   expensive fits. Use rank-normalized/folded split R-hat <=1.01, bulk/tail ESS
   >=400 and mean MCSE/posterior SD <=0.05 as monitored criteria for all parameters.
2. Refit/extend the exact smoke IDs and recipe from each chain's saved final
   parameter values. Original JAGS internal RNG state was not saved, so this is
   an explicitly documented restart from chain endpoints, not bitwise continuation.
   Keep 8,000 new draws/chain initially; inspect tau, sigma_d, s and their joint
   distribution/ACF. Preserve original 1,000-draw chains separately.
3. Simulate full covariate + repeated designer + independent anonymous designer
   + game latent + measurement hierarchy, using fixed seeds. Recover scales,
   selected slopes, named effects, and theta. Judge aggregate error/coverage and
   diagnostics, not whether every interval contains truth. Check analytic marginal
   covariance and conditional latent moments independently.
4. Audit all 6,489 development games' designer group sizes, repeated pairs and
   within-designer count/predictor variation. Time a 2,000-game four-chain pilot
   with 500 adaptation + 500 burn-in + 500 retained. Measure process working set
   externally and R object sizes. Extrapolate with explicit limitations.
5. Once implementation and resource gates pass, fit all 6,489 development games,
   re-estimating and saving preprocessing and designer map on these exact rows.
   Four parallel R workers; checkpoint samples/state per chain every batch.
   Start 2,000 adaptation + 2,000 burn-in + 2,000 retained/chain, then extend in
   batches to a predeclared ceiling of 12,000 retained/chain if criteria fail.
   A ceiling is a resource limit, never evidence of convergence.
6. Separately label full-development sensitivity U(0.5,6) for s, with all other
   priors unchanged. Compare scale/mean coefficients, theta, shrinkage, ranks and
   descriptive PPC on identical development IDs; no holdout model selection.
   Keep baseline and sensitivity outputs and convergence flags separate.
7. Save chain identity, model/recipe/source hashes, seeds/internal states,
   parameter and latent draws, log likelihood conventions, plots, timings and
   memory evidence. Report convergence failures and prior dependence honestly.

Outputs live under outputs/P4/{extended_400,simulation,timing_2000,
baseline_development,sensitivity_s_upper6}. Binary posterior artifacts are local
and ignored; reproducible scripts and readable evidence are retained.
