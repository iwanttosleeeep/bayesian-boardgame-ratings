# P4 M1b baseline — 23 November 2026

## Current authority and scope

Authority: [repository README](../README.md), [team plan](TEAM_PLAN_AND_STATUS.md),
[P1 data guide](P1_DATA_GUIDE.md), and the user's constant-tau instruction.
After `git fetch origin`, HEAD and origin/main were both
`1853171366334ff9b671c7dda11e54450f7aa262`; no local changes existed before this work.
The README and linked documents are the current working plan; a separate Proposal
is not a prerequisite. Recommendations below are P4 implementation choices, not
claims that the repository already specifies them.

| Topic | Already required | Recommended baseline and reason |
|---|---|---|
| Data | Fit development only; comparison is holdout | Read only `dev_subsample.csv` for preparation/fitting. Keep all 6,489 valid outcomes rather than discard games for missing covariates. Smoke run samples 400 development games with seed 42. |
| Structure | Covariates, log rating count, designer effects; user fixes constant tau | Normal measurement model with shared rating SD s, constant residual latent SD tau, and Normal designer random intercepts. This extends P5 Baseline without also changing latent dispersion or importing historical SD. |
| Continuous predictors | Log rating count and cleaned P1 field meanings | `log1p(users_rated)`, `log1p(game_age)`, `log1p(playingtime_capped)`, `minplayers`, `maxplayers_capped`, `minage`; standardized using training means/SDs. Uses the delivered P1 transformations; log1p(n) is explicit, not silently called log(n). |
| Other predictors | P1 supplies 20 category + 20 mechanic flags; no exact M1b subset mandated | Include all 40 with shrinkage priors, plus `multi_designer`. Multi-label flags need no reference category. Do not select predictors using holdout outcomes. |
| Forbidden predictors | No rank, bayes_average, owned, trading, wanting, wishing | Exclude these and raw year; use average as outcome and users_rated as n. |
| Preprocessing | Full-table P1 scaling/tag selection is a documented limitation; do not rewrite shared CSVs | Recalculate continuous scaling locally from training values, retaining fixed P1 tag columns for team consistency. This removes full-table scaling dependence but does not undo full-table tag selection. Save all transformation parameters and dropped constant columns. |
| Missing numeric predictors | Must be handled explicitly; exact method unspecified | Training-median imputation before standardization, with an unscaled missingness indicator for each affected numeric predictor. Retains games, is reproducible, and avoids treating an unknown play time as 600. It does not propagate imputation uncertainty; later complete-case sensitivity is appropriate. |
| Missing tags | P1 flags code missing raw tags as all zero | Add category-missing and mechanic-missing indicators so unknown tags can differ from a known game outside the selected tags. |
| Designer grouping | First-listed designer; distinguish seen/unseen designers | Reindex nonmissing, credited designer names to contiguous training-only integers. Keep the first-listed convention and multi_designer flag; this is not a multiple-membership model. |
| Missing / uncredited designer | Requires explicit handling; exact model unspecified | Never pool all NA or `(Uncredited)` games as one designer. Treat each such game as an independent unknown designer, integrating its effect as extra variance sigma_d^2. Add separate missing/uncredited status flags with regularized coefficients to permit systematic mean differences. This retains rows without fabricating shared identity. |
| Priors | M1b priors unspecified; P5 Baseline priors are available | alpha ~ N(6.4,1^2), s ~ Uniform(0.5,3), tau ~ half-Cauchy(0,1), matching P5 baseline; sigma_d ~ half-Normal(0,0.5^2). Standardized continuous slopes ~ N(0,0.5^2); tag/indicator slopes ~ N(0,0.3^2), discouraging large effects from sparse flags. These are recommendations; sensitivity remains necessary, especially for weakly identified s and the many singleton designers. |
| Prediction and comparison | Seen/new designer targets differ; common development IDs needed for formal WAIC | Seen named designer: use its posterior effect. New named designer: draw one new effect per distinct designer per draw, shared by its games. Anonymous games: independent new effects. Keep holdout entirely out of parameter and preprocessing estimation. Save exact training IDs and game-level log likelihood integrating theta; designer effects remain conditional, so designer-level LOO requires a separate integration strategy. |

## Model and conditional latent ratings

For credited training designers:

\[
y_i\mid\theta_i\sim N(\theta_i,s^2/n_i),\quad
\theta_i\mid u,\alpha,\beta,\tau\sim N(\mu_i,\tau^2),\quad
\mu_i=\alpha+X_i\beta+u_{d(i)},\quad
u_d\sim N(0,\sigma_d^2).
\]

Let k_i indicate a known credited designer and define
`mu_i = alpha + X_i beta + k_i u[d(i)]` and
`t_i^2 = tau^2 + (1-k_i) sigma_d^2`.
For missing/uncredited designers this analytically integrates an independent
designer effect. The fitted marginal likelihood is
`y_i ~ Normal(mu_i, t_i^2 + s^2/n_i)`.
**Tau is constant for every game**; the additional anonymous-designer uncertainty
is not a covariate-dependent tau model. JAGS Normal distributions use precision.

Conditional latent draws use `v_i=s^2/n_i`, `w_i=t_i^2/(t_i^2+v_i)`:
`theta_i | y_i,parameters ~ Normal(mu_i+w_i*(y_i-mu_i), t_i^2*v_i/(t_i^2+v_i))`.
Use the same posterior parameter draw across games to preserve designer and
parameter dependence in ranking draws. Rankings from a development subset are
within-sample, not global BGG rankings.

## Original preparation / smoke sequence (historical scope)

1. Download official R/JAGS distributions into ignored `.local/`, verify R MD5
   and installer signatures, and use a local package library. Record versions.
2. Verify `rjags`, `coda`, JAGS model compilation and short sampling on synthetic
   data before reading development outcomes for the smoke fit.
3. Fit preprocessing on the 400-game development smoke subset only; save IDs,
   source hash, preprocessing, model, per-chain seeds, timing and diagnostics.
4. Run four chains (1,000 adaptation, 1,000 burn-in, 1,000 retained iterations).
   Check finite draws, conditional latent calculations and R-hat/ESS. This is a
   runtime/implementation smoke test, not a final convergence or model-quality claim.
5. Do not fit all 6,489 games or score holdout as part of this smoke task.

## Known limitations

- Normal rating likelihood is unbounded; future PPC should inspect support/tails.
- Aggregated means and n alone may weakly identify s; P5 reports an upper-bound
  tendency. Check this and prior sensitivity before interpreting pseudo-votes.
- Many designer groups are singletons; variance allocation needs diagnostics.
- Holdout was used by the group in earlier exploration; evaluation is exploratory.
- P2 artifacts have inconsistent training IDs and cannot be reused as a matched
  comparison without a development-only refit. Do not change teammates' files.
- R/JAGS installation or a 400-game smoke success does not establish full-data
  runtime or convergence. No presentation-result freeze status is changed here.

## Observed initial preparation outcome

Environment gate and the 400-game smoke completed; see
[the evidence index](../outputs/P4/README.md). Fit time was 43.36 seconds.
Short-chain convergence targets were **not** met (max classical R-hat 1.02112,
min ESS 78.63), so no final inference is claimed. No full-development fit or
holdout scoring was performed. The next modeling work should inspect tau versus
sigma_d mixing, increase retained draws, and check s-prior sensitivity.

## Follow-up diagnostic and full-development scope

The user's subsequent authorization supersedes the original smoke-only scope:
extend the same 400-game model, check full-structure simulation recovery and
larger-sample resources, then fit all 6,489 development games and a separately
labeled s-prior sensitivity. The baseline priors and constant tau remain exactly
as specified above. Actual training rows determine fresh preprocessing for every
new fit. See [execution plan](P4_DIAGNOSTIC_PLAN.md) and
[diagnostic evidence/caveats](P4_DIAGNOSTIC_NOTES.md). No holdout tuning or formal
cross-team model-comparison sample is part of this work.
