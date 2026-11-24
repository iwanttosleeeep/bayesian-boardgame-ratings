# P4 M1b-ExternalSD — specification and execution record

## Scope and authority (2026-11-24)

New branch `p4/m1b-externalsd` starts from main `496ffe4`. Original P4 delivery
PR #1 and WAIC handoff PR #2 are merged. Original 6,489-game code, posterior,
results and WAIC share are protected by a local full-file SHA256 inventory; this
extension only adds new files and narrow share exceptions in .gitignore.
No slides, speeches, new three-model WAIC ranking or holdout tuning.

The requested P5 reference `12_Fit_M1b_ExternalSD_Independent.R` was read as an
unverified reference. Its likelihood transformation agrees with the algebra
below, but its final likelihood export lacks retained draw indices and it does
not run the required same-sample original-M1b control. We therefore do not execute
it or use its results. Existing P4 code is the basis for this isolated extension.

## Data audit and frozen sample

Historical table: `outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv`.
Upstream documented by P5 preparation code:
`https://raw.githubusercontent.com/AgeOfWar/AgeOfWar.github.io/master/games.csv`,
column `StdDev` matched by `BGGId`; `sd_hist` is a reported within-game individual
rating SD in rating points, not an SE of a game mean.
Acquisition date and exact alignment to the 2022 source remain unverified.

The supplied table has 6,416 unique development IDs with finite positive SD and
historical counts. SD range 0.196023–4.05257. Median/max historical count relative
difference: 0.0030053 / 0.622807. Historical SD is a fixed plug-in: no uncertainty
in the estimate or temporal mismatch is propagated. No historical averages/counts
replace the current target or denominator. Source description is P5's documented
provenance, not a new independent collection-date verification.

Preserve development CSV order, filter by valid supplied matches: **6,416 games**,
73 excluded. The supplied CSV is already prefiltered, so those 73 cannot be
subclassified as absent/invalid using this file alone. Confirm average_2022 and
n_2022 match the development average and users_rated. The audit and exact sequence
are under `outputs/P4/ExternalSD_6416/`.

Preprocessing is re-estimated once on these exact rows using unchanged P4 rules:
56 predictors, 3,192 named designer groups and 612 anonymous games. Both fits use
the same IDs, X, median imputation, standardization, retained columns and designer
mapping. Matched sample inputs and SD are frozen and compared before fitting.
Constant columns remain governed by the original recipe and its saved dropped list.
P1's full-table tag selection limitation remains.

## Models and conditional posterior

For named training designers, let k_i=1 and include posterior u_d in the mean;
otherwise k_i=0 and integrate an independent unknown designer effect.

```
mu_i = alpha + X_i beta + k_i u_d
t2_i = tau^2 + (1-k_i) sigma_d^2
v_i (matched original control) = s^2 / users_rated_i
v_i (ExternalSD)               = sd_hist_i^2 / users_rated_i
y_i ~ Normal(mu_i, t2_i + v_i)
JAGS precision = 1 / (t2_i + v_i)
```

The ExternalSD JAGS model is obtained by replacing only the observation variance
term and removing s and its prior. `tau` is constant, not covariate-dependent.
All other priors are unchanged: alpha~N(6.4,1²), tau~half-Cauchy(0,1),
sigma_d~half-Normal(0,.5²), continuous beta~N(0,.5²), indicator beta~N(0,.3²).
The control retains s~Uniform(.5,3), not the old upper-6 sensitivity prior.

With w=t2/(t2+v), conditional theta mean is mu+w(y-mu), variance t2*v/(t2+v).
Named effects are conditioned on their posterior draws. Missing/uncredited
designers do not become a shared group: their independent effects are integrated
as the extra sigma_d² in t2. PPC uses y_rep~Normal(mu,t2+v). Pointwise loglik is
the normalized Normal log density for the observed average with variance t2+v;
it integrates theta and anonymous effects, conditions on named training effects.
It is not posterior density, deviance or unseen-designer-group validation.

## Implementation and validation

- `code/P4/M1b_sd_inference.R`: isolated copy of the proven four-chain/checkpoint
  machinery plus sd_model/sd_latent and dynamic no-s monitors/plots. Originals
  remain unedited. Worker processes source this extension file explicitly.
- `M1b_sd_checks.R`: independent inverse-precision conditioning and scalar
  loglik calculation, baseline model/priors text equivalence, and 50,000-block
  named/anonymous covariance check. The test was observed failing before the new
  functions existed, then passing with the implementation.
- `M1b_sd_run.R`: data audit, short trial and sequential full-model entry points.
- `M1b_sd_compare.R`: same-input verification, parameters and designer counts,
  grouped latent changes, balanced 500-draw shares, numerical loglik checks and
  PPC comparison; no WAIC calculation.
- `run_sd.ps1`: existing R/JAGS environment resolver, separate output paths,
  memory monitor, no-overwrite guard and stop-after-checkpoint request.

The 400-game ExternalSD trial completed with finite latent/PPC/loglik output and
no shared s. Independent all-game likelihood checks had max error 1.78e-15.
Its short-chain diagnostics did **not** pass (max Rhat 1.026, min bulk/tail ESS
70/160); it is an implementation check, not scientific evidence of convergence.
Read-only independent review found no important statistical or worker-source
errors. Frozen SD equality and source/SD hash provenance were added before full
runs. Unused shared-s simulation code was removed from the isolated extension.

## Full execution and reproducibility

Use installed matching R/JAGS, rjags, coda and posterior as described in the
original `code/P4/README.md`. Tested runtime is R4.5.3/JAGS4.3.2/rjags4-18/
posterior1.8.0. The source hash manifest records actual execution bytes (Windows
line endings may differ from Git LF blobs). Do not edit sources during a run.

From repository root, using your own configured P4_RSCRIPT/JAGS_HOME/R_LIBS_USER:

```powershell
python code/P4/M1b_sd_provenance.py capture
./code/P4/run_sd.ps1 -Stage prepare
./code/P4/run_sd.ps1 -Stage smoke
# After checks and trial export gate pass, run these SEQUENTIALLY:
./code/P4/run_sd.ps1 -Stage baseline
./code/P4/run_sd.ps1 -Stage external
# Then, in the same configured R environment:
Rscript --vanilla code/P4/M1b_sd_compare.R
Rscript --vanilla code/P4/M1b_sd_validate.R
Rscript --vanilla code/P4/M1b_sd_report.R
python code/P4/M1b_sd_provenance.py verify
python code/P4/M1b_sd_provenance.py package
```

These commands are for a fresh reproduction, not a request to overwrite existing
results. Preserve/rename a completed ExternalSD_6416 directory before starting a
new run; never remove original P4 result directories. `prepare` is run once and
requires a source_manifest.csv recording source SHA256 values; the capture helper
creates it before a new run and refuses to replace an existing execution. The checked-in
manifest documents this original execution. For another source checkout, record
its actual hashes in a separate run rather than falsely reusing this provenance.

Each full model: four parallel chains, 2,000 adaptation + 2,000 burn-in, 2,000
retained draws per batch, minimum 4,000 and ceiling 12,000 per chain. All monitors
and derived variance quantities require rank-normalized/folded split Rhat<=1.01,
bulk and tail ESS>=400, MCSE(mean)/SD<=.05. Failing batches extend the same model;
ceiling/resource stops do not imply convergence. Full fits are sequential.

Each new model directory contains exact IDs, mapping, model, configurations,
preprocessing RDS, chain IDs/seeds/RNG states and full draws, diagnostics, progress,
memory samples, traces, joint posterior and ACF. Joint theta draws and full
pointwise loglik retain parameter chain/retained-row indices. A separate 500-draw
share chooses 125 evenly spaced retained rows per chain; no invented indices.

Only small summaries, matched SD, IDs/mappings, diagnostics, existing figures,
verification and two explicitly named likelihood shares are intended for Git.
Full chain/latent/input RDS, local runtime, installers, source snapshots and logs
remain local and ignored. The two 500×6416 shares must not replace or be compared
numerically with the original 500×6489 WAIC handoff. P5 coordinates any future
same-sample model comparison.

The completed comparison is [reported here](../outputs/P4/ExternalSD_6416/README.md).
`M1b_sd_validate.R` independently replays all 1,000 exported theta draws and PPC
replications from saved indices/RNG, using inverse-precision conditioning and a
scalar Normal log density. `final_validation.txt` records maximum numerical errors.
`file_manifest.csv` inventories binary files with sizes/SHA256 and an explicit
uploaded/local-only flag. Local-only entries are an inventory, not download links.
`postprocessing_sources.csv` is captured later and kept separate from the original
fit-time source manifest; protected original dependencies were checked unchanged.

## Interpretation boundaries

Primary contrast is matched original M1b versus ExternalSD on the same 6,416 rows.
Original 6,489-game parameters are supplementary only: sample and standardization
also differ. Mean changes, 95% intervals and MCSE are reported separately.
Designer effects are conditional associations, not causal designer contributions.
Latent mean MCSE uses ordered thinned chain transforms; it is not theta's
posterior SD. Different model posterior mean MCSE values combine in quadrature
as a computational-precision diagnostic, not a scientific effect-size test.
PPC discrepancies and historical plug-in limitations remain even if chain
diagnostics pass. No result is predetermined to favor ExternalSD.
