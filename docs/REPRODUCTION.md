# Reproduction paths and prerequisites

Updated 27 November 2026. Core deliveries are complete. The commands below distinguish read-only checks and artifact reuse from optional regeneration; no MCMC or analytical figure generation was run for this cleanup.

## Locating the checkout and original caches

The P2 entrypoints, numbered P5 R scripts and P4 likelihood exporter load [code/repo_paths.R](../code/repo_paths.R). They find it from the executing/sourced file, an explicit `BOARDGAME_REPO_ROOT`, or the launch directory, without changing the caller's working directory. A full checkout is required; a copied script can use `BOARDGAME_REPO_ROOT=/absolute/checkout`. Existing standalone `source(url(...))` examples require that same checkout context.

- `P5_CACHE_DIR=/absolute/P5_external_SD` selects an original P5 cache explicitly. Otherwise the launch directory's `P5_external_SD/` (or the launch directory itself when named `P5_external_SD`) is preferred, then the checkout's cache. No search into unrelated ancestor/home caches is performed.
- P5 inputs prefer that cache, then **explicitly mapped equivalent repository files**. `Model_A_same_6416/` maps to `outputs/P5/M1a_Baseline/`; `Model_D_calibrated/` maps to `outputs/P5/M1a_Extended_ExternalSD/`. The 6,489-game archived refit and 21,375-game ranking handoff are never substituted for these fits. A local fit directory owns its entire bundle: missing components are reported rather than filled from another saved run. Use a complete original cache or an empty cache to select the committed bundle. Original ID, model and checksum assertions remain in place.
- Historical SD source lookup prefers `P5_CACHE_DIR/source_cache/historical_games.csv` (or the selected default cache), then a legacy `historical_games.csv` in the launch directory, then the committed [data/raw/historical_games.csv](../data/raw/historical_games.csv). No live historical-source download or compact-lookup substitution occurs.
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
Rscript code/P5/01_prepare_historical_SD.R --rebuild-lookup --check-paths
Rscript code/P5/04_Extended_holdout_validation.R --check-paths
Rscript code/P5/11_Export_Full_Cleaned_Data_Theta_for_P6.R --check-paths
Rscript code/P5/07_Baseline_vs_Extended_comparison.R --check-paths
Rscript code/P5/08_prepare_P6_handoff.R --validate-only
Rscript code/P5/13_Compare_Four_Models_WAIC_6416.R --check-paths
```

`--check-paths` exits **before modelling-package loading, seed setting, fitting, downloads or writes** in these R entrypoints. Status 0 means the listed paths exist; status 2 reports missing paths. It does not assert that binary contents, source hashes or every downstream dependency have been validated. P5 Scripts 01/04/11 can now locate the recovered historical source in a clean checkout; full Script 04/11 postprocessing was not rerun for this source addition.

P2's exporter validates and reuses the committed [Gibbs](../outputs/P2/M0_loglik_gibbs_share.rds) and [JAGS](../outputs/P2/M0_loglik_jags_share.rds) shares. P4's exporter similarly reuses the [original-prior 6,489-game shared likelihood](../outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds). These default exporter commands write no new results when those files exist. P5 Script 08's `--validate-only` checks the original **6,416-game** latent draw/summary agreement and exits before copying a handoff; it is separate from P6's completed full-scope handoff.

## Recovered original CSV and verified postprocessing

The original [P5_SD_matched.csv](../outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv) was recovered from the owner's local cache and restored by a direct byte copy. The only difference from the previous repository copy was one missing **final LF byte (`0x0A`)**: the original is 466,162 bytes and the previous copy was 466,161 bytes. All 6,416 data rows, 9 columns, field strings and row order are identical. This was not a data-value or CRLF/LF conversion difference.

The restored MD5 is **`db47f754a7637bca215937c481411cf1`**, exactly matching the saved Baseline posterior metadata. The previous missing-final-newline copy had MD5 `713f1976d7967b275e31e5c36b991eb0`. A file-specific `-text` Git attribute prevents line-ending conversion for this provenance-sensitive input; the checksum gate itself is unchanged.

Scripts **07 and 13 both completed successfully**, using committed posterior/likelihood files and the restored CSV, with all existing provenance/model/ordered-ID checks enabled. Outputs were directed to a newly created temporary run directory outside the checkout. No committed analytical result was overwritten, and no posterior file, model, seed or analysis script was changed for this restoration.

| Reproduced output | Existing committed comparison | Verification |
| --- | --- | --- |
| Script 07 per-game holdout comparison | Archived `comparison_holdout_per_game.csv` | 3,209 rows; exact parsed numeric/non-numeric values after mapping legacy `A` column names to `Baseline` equivalents |
| Script 07 convergence | Archived `convergence.csv` | 8 rows; exact parsed values |
| Script 07 holdout summary | Archived `holdout_summary.csv` | 12 metrics; exact parsed values |
| Script 07 grouped holdout PPC | Archived `holdout_grouped_PPC.csv` | 8 rows; exact parsed values |
| Script 07 shrinkage summary | Archived `shrinkage_summary.csv` | 9 metrics; exact parsed values |
| Script 13 four-model WAIC summary | Current `WAIC_four_model_summary.csv` | 4 rows; exact parsed values |
| Script 13 pairwise WAIC differences | Current `WAIC_pairwise_differences.csv` | 6 rows; exact parsed values |
| Script 13 gamewise WAIC diagnostics | Current `WAIC_gamewise_diagnostics.csv` | 6,416 rows; exact parsed values |

Across these eight CSVs, the **maximum absolute numerical difference was 0** and all non-numeric values matched. The WAIC interpretation text also matched. Script 07's additional development-rating CSV has no committed per-game counterpart; its ordered IDs/observed averages matched the source, and its shrinkage summary matched the archived result. No byte-identical-output claim is made for files with renamed headers or different final-newline formatting.

The existing results are in the [archived two-model comparison](../archive/outputs/P5/M1a_Model_Comparison/) and [current four-model WAIC folder](../outputs/P5/WAIC_Comparison_6416/). To repeat the postprocessing without overwriting them, use a new temporary run directory and empty cache:

```sh
repo=/absolute/checkout
run=$(mktemp -d /tmp/p5-verify.XXXXXX)
mkdir -p "$run/cache" "$run/run07" "$run/run13"
(
  cd "$run/run07"
  P5_CACHE_DIR="$run/cache" Rscript "$repo/code/P5/07_Baseline_vs_Extended_comparison.R"
)
(
  cd "$run/run13"
  P5_CACHE_DIR="$run/cache" Rscript "$repo/code/P5/13_Compare_Four_Models_WAIC_6416.R"
)
```

Script 07 writes under `$run/cache/M1a_A_vs_ExternalSD_Comparison/`; Script 13 writes under `$run/run13/P5_WAIC_Comparison_6416/`. Both are postprocessing of saved fits, not MCMC or parameter refits. Checks reject any input whose bytes do not match the recorded MD5, even when parsing gives the same data.

## Recovered full historical SD source

The original [historical_games.csv](../data/raw/historical_games.csv) is now committed at `data/raw/historical_games.csv`, copied without reserialization from `P5_external_SD/source_cache/historical_games.csv`. It is **22,119,464 bytes (21.09 MiB)**, with MD5 **`f5c23231f6c17937569dce304626d3c4`**. The [source record](../data/raw/README.md) also records SHA-256, the upstream URL named by the scripts, and the 21,925-row / 48-column schema. A file-specific Git `-text` attribute preserves the bytes. The original collection date and upstream snapshot provenance remain unverified; SD is still a fixed plug-in estimate.

The read-only [source test](../code/tests/test_historical_source.R) checks the checksum, unique IDs, required fields, and matching against the committed 6,416-game development lookup, 3,209-game holdout and full 21,631-game matching audit (21,375 usable SD matches). Historical SDs/counts and available historical means agree at numeric tolerance `1e-12`, with identical ordered game cohorts. This validates inputs and existing matching records without sampling, predictions, figure generation or output writes. It does not establish end-to-end numerical reproduction of Scripts 04/11; their full workflows were not run.

## Exact prerequisites that remain local

| Operation | Exact prerequisite and limitation |
| --- | --- |
| P2 new likelihood export | The exact full `M0_loglik_gibbs.rds` / `M0_loglik_jags.rds` matrices and companion training IDs from the intended saved run are required when an existing shared artifact is unavailable. The 500-draw shares do not reconstruct the original full matrices. |
| P4 `--regenerate` | Original `inputs.rds`, `pointwise_loglik.rds`, `chain_1.rds`–`chain_4.rds` and `train_game_ids.csv` under `P4_BASELINE_DIR`, matching the committed [source checksums](../outputs/P4/M1b_WAIC_6489/source_checksums.csv). The saved 500-draw share cannot reconstruct these full source files. The exporter validates root P1 data against the recorded Git-LF checksum while retaining the original source metadata. |
| Optional fits and sensitivity | Original source caches, matching installed R/JAGS packages and the recorded environment are still required. Alternative-prior/SD fitting is not a smoke test and was not run here. |

## Owner-run regeneration commands — not executed in this cleanup

For a missing P5 lookup, Scripts 01/04/11 can read the committed original historical source directly; restoring the same bytes under `source_cache/historical_games.csv` inside the chosen cache remains supported. The explicit `--rebuild-lookup` option writes a **missing local** lookup there rather than targeting the uploaded repository CSV:

```sh
P5_CACHE_DIR=/absolute/P5_external_SD Rscript code/P5/01_prepare_historical_SD.R --rebuild-lookup --check-paths
P5_CACHE_DIR=/absolute/P5_external_SD Rscript code/P5/01_prepare_historical_SD.R --rebuild-lookup
```

Rebuilding with a different snapshot or CSV serialisation is not evidence of byte-identical provenance. Scripts 07 and 13 now pass using the restored original CSV. Their recorded MD5 requirement remains unchanged. Scripts 04, 08 and 11 retain their original postprocessing/handoff commands and seeds, with the local prerequisites above where applicable. Script 11 samples conditional latent ratings from saved parameters; it does not refit parameters, but it is not part of this cleanup's tests.

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
Rscript code/tests/test_historical_source.R .
Rscript code/tests/test_repo_paths.R .
python3 code/tests/test_group_deck_wording.py
Rscript code/tests/test_analysis_invariants.R .
```

The path smoke suite uses an empty temporary P5 cache and checks 21 entrypoints from three launch locations plus `source()` from an unrelated directory. All 84 path checks now succeed with the committed historical source. The explicit Script 01 `--rebuild-lookup --check-paths` preflight also passes without rebuilding. The source test reconciles the recovered snapshot with committed matching records. Helper tests verify committed-source fallback, original-cache and legacy flat-file precedence, 6,416-game IDs and acceptance of the recovered original CSV; a temporary copy missing its final LF is confirmed to parse identically but fail the unchanged checksum gate. The deck comparison checks 19 slides and allows text-only XML changes, preserving geometry, styles, images, visible numerical results and speakers; the additional visible 5.5 on slide 15 makes the existing benchmark assumption explicit.
