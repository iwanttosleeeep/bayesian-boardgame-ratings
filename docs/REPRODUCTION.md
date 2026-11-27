# Reproduction paths and prerequisites

Updated 27 November 2026. Core deliveries are complete. The commands below distinguish read-only checks and artifact reuse from optional regeneration; no MCMC or analytical figure generation was run for this cleanup.

## Locating the checkout and original caches

The P2 entrypoints, numbered P5 R scripts and P4 likelihood exporter load [code/repo_paths.R](../code/repo_paths.R). They find it from the executing/sourced file, an explicit `BOARDGAME_REPO_ROOT`, or the launch directory, without changing the caller's working directory. A full checkout is required; a copied script can use `BOARDGAME_REPO_ROOT=/absolute/checkout`. Existing standalone `source(url(...))` examples require that same checkout context.

- `P5_CACHE_DIR=/absolute/P5_external_SD` selects an original P5 cache explicitly. Otherwise the launch directory's `P5_external_SD/` (or the launch directory itself when named `P5_external_SD`) is preferred, then the checkout's cache. No search into unrelated ancestor/home caches is performed.
- P5 inputs prefer that cache, then **explicitly mapped equivalent repository files**. `Model_A_same_6416/` maps to `outputs/P5/M1a_Baseline/`; `Model_D_calibrated/` maps to `outputs/P5/M1a_Extended_ExternalSD/`. The 6,489-game archived refit and 21,375-game ranking handoff are never substituted for these fits. A local fit directory owns its entire bundle: missing components are reported rather than filled from another saved run. Use a complete original cache or an empty cache to select the committed bundle. Original ID, model and checksum assertions remain in place.
- P5 generated outputs retain their original cache subfolders. Existing repository artifacts are read in place, not moved, copied back or overwritten by the input resolver.
- P2 generated outputs use `outputs/P2/`, `figures/` and `tables/` under the checkout by default. Set `BOARDGAME_OUTPUT_ROOT=/absolute/new-output-root` for an isolated reproduction. The likelihood exporter also recognises original full caches under `outputs/`; it does not require them when the committed shares already exist.

## Read-only checks and reuse

Run these examples from the repository root; absolute script paths also work from another working directory:

```sh
Rscript code/P2/M0_run.R --check-paths
Rscript code/P2/M0_cavi_run.R --check-paths
Rscript code/P2/P2_M1b_timing.R --check-paths
Rscript code/P2/M0_make_share_loglik.R
Rscript code/P4/M1b_export_WAIC_6489.R
Rscript code/P5/07_Baseline_vs_Extended_comparison.R --check-paths
Rscript code/P5/08_prepare_P6_handoff.R --validate-only
Rscript code/P5/13_Compare_Four_Models_WAIC_6416.R --check-paths
```

`--check-paths` exits **before modelling-package loading, seed setting, fitting, downloads or writes** in these R entrypoints. Status 0 means the listed paths exist; status 2 reports missing paths. It does not assert that binary contents, source hashes or every downstream dependency have been validated. P5 Scripts 04 and 11 require the original historical source cache and report its absence in a clean checkout.

P2's exporter validates and reuses the committed [Gibbs](../outputs/P2/M0_loglik_gibbs_share.rds) and [JAGS](../outputs/P2/M0_loglik_jags_share.rds) shares. P4's exporter similarly reuses the [original-prior 6,489-game shared likelihood](../outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds). These default exporter commands write no new results when those files exist. P5 Script 08's `--validate-only` checks the original **6,416-game** latent draw/summary agreement and exits before copying a handoff; it is separate from P6's completed full-scope handoff.

## Exact prerequisites that remain local

| Operation | Exact prerequisite and limitation |
| --- | --- |
| P5 Scripts 07 and 13 | The Baseline RDS records training-CSV MD5 `db47f754a7637bca215937c481411cf1`; the uploaded matched CSV has MD5 `713f1976d7967b275e31e5c36b991eb0`. Ordered 6,416-game IDs match, but the hash difference is not explained by LF/CRLF conversion. Restore the original `P5_SD_matched.csv` in `P5_CACHE_DIR`; the original assertions must not be bypassed. Both scripts now report this discrepancy explicitly before postprocessing. |
| P5 Scripts 04 and 11 | `P5_external_SD/source_cache/historical_games.csv`, the exact historical snapshot used for the saved fits, is not committed. Script 04 needs it for holdout SD matching; Script 11 needs it for full-dataset matching. The compact development lookup cannot replace the full historical source. The upstream URL alone does not guarantee the original snapshot, so Scripts 01/11 now require the staged original file instead of automatically downloading a live historical source. |
| P2 new likelihood export | The exact full `M0_loglik_gibbs.rds` / `M0_loglik_jags.rds` matrices and companion training IDs from the intended saved run are required when an existing shared artifact is unavailable. The 500-draw shares do not reconstruct the original full matrices. |
| P4 `--regenerate` | Original `inputs.rds`, `pointwise_loglik.rds`, `chain_1.rds`–`chain_4.rds` and `train_game_ids.csv` under `P4_BASELINE_DIR`, matching the committed [source checksums](../outputs/P4/M1b_WAIC_6489/source_checksums.csv). The saved 500-draw share cannot reconstruct these full source files. The exporter validates root P1 data against the recorded Git-LF checksum while retaining the original source metadata. |
| Optional fits and sensitivity | Original source caches, matching installed R/JAGS packages and the recorded environment are still required. Alternative-prior/SD fitting is not a smoke test and was not run here. |

## Owner-run regeneration commands — not executed in this cleanup

For a missing P5 lookup, first restore the original historical snapshot as `source_cache/historical_games.csv` inside the chosen cache. The explicit `--rebuild-lookup` option writes a **missing local** lookup there rather than targeting the uploaded repository CSV:

```sh
P5_CACHE_DIR=/absolute/P5_external_SD Rscript code/P5/01_prepare_historical_SD.R --rebuild-lookup --check-paths
P5_CACHE_DIR=/absolute/P5_external_SD Rscript code/P5/01_prepare_historical_SD.R --rebuild-lookup
```

Rebuilding with a different snapshot or CSV serialisation is not evidence of byte-identical provenance. Scripts 07 and 13 still require the original MD5; restoration of the original CSV is preferred. Once exact prerequisites are restored, Scripts 04, 07, 08, 11 and 13 retain their original postprocessing/handoff commands and seeds. Script 11 samples conditional latent ratings from saved parameters; it does not refit parameters, but it is not part of this cleanup's tests.

For P4, restore the original source RDS files, then use a **new empty export directory**:

```sh
P4_BASELINE_DIR=/absolute/original-baseline Rscript code/P4/M1b_export_WAIC_6489.R --regenerate --check-paths
P4_BASELINE_DIR=/absolute/original-baseline P4_EXPORT_DIR=/absolute/new-export Rscript code/P4/M1b_export_WAIC_6489.R --regenerate
```

This is an export from the original saved fit, not a refit. A newly fitted P4 posterior cannot replace the historical source files under that provenance record. A separate new reproduction can be requested with `Rscript code/P4/M1b_reproduce.R baseline /absolute/new-baseline`, but it requires JAGS, `rjags`, `coda` and `posterior`, runs MCMC, and does not recover the original random draws. It was not executed.

For a separately authorised new P2 fit and full likelihood caches:

```sh
BOARDGAME_OUTPUT_ROOT=/absolute/new-output-root Rscript code/P2/M0_run.R
BOARDGAME_OUTPUT_ROOT=/absolute/new-output-root Rscript code/P2/M0_make_share_loglik.R
```

The first command runs the existing `MODE = "real"` MCMC configuration. These commands are documented prerequisites, not validation performed here. Never treat a fresh run as the original saved posterior.

## Lightweight regression tests

```sh
python3 code/tests/smoke_paths.py
Rscript code/tests/test_repo_paths.R .
python3 code/tests/test_group_deck_wording.py
Rscript code/tests/test_analysis_invariants.R .
```

The path smoke suite uses an empty temporary P5 cache and checks 21 entrypoints from three launch locations plus `source()` from an unrelated directory. It expects 76 successful path checks and eight explicit missing-historical-cache reports. Helper tests verify local-cache precedence, 6,416-game IDs and rejection of the known CSV provenance mismatch. The deck comparison checks 19 slides and allows text-only XML changes, preserving geometry, styles, images, visible numerical results and speakers; the additional visible 5.5 on slide 15 makes the existing benchmark assumption explicit.
