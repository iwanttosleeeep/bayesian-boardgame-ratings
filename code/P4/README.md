# P4 — constant-tau M1b development analysis

Start with [the three milestone delivery and portable reproduction guide](../../docs/P4_DELIVERY.md). It distinguishes uploaded CSV/PNG evidence from local-only RDS files; a clean clone does not contain posterior RDS or `.local`.

## Diagnostic and full-development workflow

The follow-up execution is described in [P4_DIAGNOSTIC_PLAN.md](../../docs/P4_DIAGNOSTIC_PLAN.md)
and [P4_DIAGNOSTIC_NOTES.md](../../docs/P4_DIAGNOSTIC_NOTES.md). Original smoke files
are retained. Run stages with `run_analysis.ps1 -Stage <stage>`:

| Stage | Purpose |
|---|---|
| `extended` | Same 400 IDs/recipe/model; restart at saved endpoints and extend four chains |
| `simulation` | Two complete hierarchical recovery checks with repeated/anonymous designers |
| `information` | Full-development designer group audit without fitting |
| `timing` | Original 2,000-game default-sampler runtime pilot; memory omitted main interpreter |
| `timing_corrected` | Same pilot with correct master PID and glm block sampler |
| `baseline` | Full 6,489-game original-prior model, fresh preprocessing, batch diagnostics |
| `sensitivity` | Full 6,489-game s-upper-6 model, separately labeled, fresh preprocessing |

Before either full fit, run `M1b_resource_gate.R` after simulations and the
corrected timing stage. `M1b_checks.R`, `M1b_simulation_review.R`, and
`P4_resource_checks.ps1` contain independent implementation/resource probes.
After both full fits, run `M1b_compare.R` and `M1b_final_checks.R` in the same
process-local environment supplied by the wrapper.
`./code/P4/finish_analysis.ps1` runs those checks, verifies the original smoke
hashes, and regenerates the evidence report. It does not refit models.

**Do not rerun completed stages into the same output directory.** The delivery update rejects existing full/timing runs before opening logs. Use `M1b_reproduce.R` with a new empty directory instead.
Source snapshots, per-chain samples/RNG states, model settings and data recipes
are preserved with each formal run. Monitor `progress.csv`, `status.txt`,
`run_errors.log`, and `memory_samples.csv`. A file named `STOP_AFTER_CHECKPOINT`
requests a stop after saved samples/diagnostics; available RAM below 2 GB creates
this request automatically. A stopped or ceiling-limited run is not automatically
converged.

The `posterior` 1.8.0 package adds rank-normalized/folded split R-hat, bulk/tail
ESS and MCSE. Official diagnostic definitions:
[R-hat](https://mc-stan.org/posterior/reference/rhat.html),
[bulk ESS](https://mc-stan.org/posterior/reference/ess_bulk.html),
[MCSE](https://mc-stan.org/posterior/reference/mcse_mean.html).
The official [JAGS manual source](https://sources.debian.org/src/jags/4.3.2-1/doc/manual/jags_user_manual.tex)
describes glm block updating of normally distributed fixed/random effects.
Loading this sampler changes computation, not the model priors or likelihood.

Binary posterior artifacts for all P4 runs are ignored in Git and remain local;
readable metadata, IDs, maps, diagnostics and figures are retained. The recovery
checks expose theta interval undercoverage despite passing MCMC diagnostics;
read the caveats before interpreting uncertainty or ranking results.

## Original smoke commands

Read [the baseline decisions](../../docs/P4_BASELINE.md) first. These scripts
implement the authorized 400-game development-only smoke, not the final fit.
No P1/P2/P5 files are modified and the holdout is not read.

From the repository root in PowerShell:

```powershell
./code/P4/run_local.ps1 -Mode verify
./code/P4/run_local.ps1 -Mode smoke
```

- `verify_environment.R`: synthetic conjugate Normal check; no real data.
- `M1b_prepare.R`: train-fitted preprocessing and conditional latent moments.
- `M1b_baseline.bug`: theta-integrated JAGS model, constant tau, noncentered
  designer random intercepts; anonymous designer effects integrated separately.
- `M1b_smoke.R`: fixed-seed 400-game fit, implementation probes, four-chain
  diagnostics and 100 latent/pointwise likelihood draws.
- `run_local.ps1`: process-local runtime/library/JAGS/locale configuration and
  environment gate before smoke. A failing R process stops the runner.

The local runtime and packages are ignored under `.local/`. Binary smoke RDS
files are also ignored; CSV summaries, IDs, and environment evidence are visible
under `outputs/P4/smoke/`. Do not label these as converged full-data results.

## Verified local runtime preparation

The R installer was run silently for the current user into `.local/R-4.5.3`,
without shortcuts; JAGS was extracted with 7-Zip into `.local/JAGS-4.3.2`, with
`x64/bin` and `x64/modules` retained. The wrapper supplies `JAGS_HOME`, so JAGS
does not require a system installation or permanent PATH edit. Package ZIPs were
installed with `install.packages(..., repos=NULL, type="win.binary",
lib=".local/R-library")`.

| Distribution | Official source | Verification |
|---|---|---|
| R 4.5.3 | [CRAN archive](https://cran.r-project.org/bin/windows/base/old/4.5.3/) | MD5 `7750801cb615cb463a8c027cf8fbf1dd` matches official list; Authenticode Valid |
| JAGS 4.3.2 | [JAGS Windows releases](https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Windows/) | 29,014,264 bytes; Authenticode Valid (Martyn Plummer) |
| rjags 4-18 | [CRAN R 4.5 binary](https://cran.r-project.org/bin/windows/contrib/4.5/rjags_4-18.zip) | Installed package MD5 check passes; DESCRIPTION requires JAGS 4.x.y |
| coda 0.19-4.1 | [CRAN R 4.5 binary](https://cran.r-project.org/bin/windows/contrib/4.5/coda_0.19-4.1.zip) | Installed package MD5 check passes |

The current rjags source release requires JAGS 5; do not replace the pinned
binary with an unreviewed latest source package. The JAGS release README identifies
4.3.2 as built with Rtools45 for R 4.5.x.

Download SHA256 values (recorded provenance, not an independent upstream check):

```text
R-4.5.3-win.exe
768ae31bb0b6056def5b1a9789a7dc49306bd037d69b0a99cdd90183aa0c1a31
JAGS-4.3.2-verified.exe
197f3b32f35462fdbbb566035f459bade6c61207fb2bada265be1504c0fa414f
rjags_4-18.zip
97a72d1da6473ae15ef4321859fac9d47ee951f5bc9e031024a76ad9e354d0cf
coda_0.19-4.1.zip
7aafa611b8f28fed64c83fbb4ad21f670c3f5a504e62646a97262bf09403c58f
```

In the Codex restricted Windows sandbox, R `file.access` returned failure for
readable package files, causing `packageVersion`/rjags loading to fail. The same
files load and the synthetic test passes under normal user permissions. Run the
wrapper from a normal PowerShell session (or an approved unsandboxed tool call).
This is separate from R/JAGS binary compatibility.
