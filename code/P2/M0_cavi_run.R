# ============================================================
# P2 / M0: CAVI + three-method comparison + runtime comparison.
# Runs everything on the SAME 6,489 development games.
# Writes NEW files only; never overwrites the validated M0 outputs.
# Run: Rscript M0_cavi_run.R   (or Ctrl+A, Ctrl+Enter in RStudio)
# ============================================================

# Locate the checkout from Rscript, source(), RStudio or an explicit root.
.launch_dir <- getwd()
.repo_hints <- c(Sys.getenv("BOARDGAME_REPO_ROOT", unset=""),
  vapply(rev(sys.frames()), function(f) if (is.null(f$ofile)) "" else dirname(f$ofile), ""),
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE))), .launch_dir)
if (requireNamespace("rstudioapi", quietly=TRUE) && rstudioapi::isAvailable())
  .repo_hints <- c(.repo_hints, dirname(rstudioapi::getActiveDocumentContext()$path))
.repo_helper <- NULL
for (.start in unique(.repo_hints[nzchar(.repo_hints)])) {
  .p <- normalizePath(.start, winslash="/", mustWork=FALSE)
  repeat {
    .candidate <- file.path(.p, "code", "repo_paths.R")
    if (file.exists(.candidate)) { .repo_helper <- .candidate; break }
    .parent <- dirname(.p); if (identical(.parent,.p)) break; .p <- .parent
  }
  if (!is.null(.repo_helper)) break
}
if (is.null(.repo_helper)) stop("Cannot locate code/repo_paths.R; use a full checkout or set BOARDGAME_REPO_ROOT.")
source(.repo_helper, local=TRUE)
repo_check_paths(vapply(c("dev_subsample.csv","code/P2/M0_functions.R","code/P2/M0_prepare.R","code/P2/M0_cavi.R"), repo_path, ""))

suppressPackageStartupMessages(library(coda))


cat("Repository:", .repo_root, "\n")

source(repo_path("code", "P2", "M0_functions.R"))
source(repo_path("code", "P2", "M0_cavi.R"))
source(repo_path("code", "P2", "M0_prepare.R"))

DATA_PATH <- repo_existing(repo_path("dev_subsample.csv"), "P1 development CSV")

SEED      <- 42
N_ITER    <- 12000
N_BURN    <- 2000
THIN      <- 5
N_CHAINS  <- 4

# GitHub layout: M0 deliverables live under outputs/P2/, figures/, tables/.
OUT_DIR <- repo_output_path("outputs", "P2")
FIG_DIR <- repo_output_path("figures")
TAB_DIR <- repo_output_path("tables")
for (d in c(OUT_DIR, FIG_DIR, TAB_DIR)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

prep <- m0_prepare(DATA_PATH, y_col = "average")
y <- prep$y
X <- prep$X
cat(sprintf("Data: %s (n = %d, p = %d, ids = %d)\n",
            DATA_PATH, length(y), ncol(X), length(prep$ids)))

# ------------------------------------------------------------
# 1. CAVI (deterministic; timed)
# ------------------------------------------------------------
cat("\n--- CAVI ---\n")
t_cavi <- system.time(cavi <- fit_m0_cavi(y, X, verbose = TRUE))
cat(sprintf("CAVI elapsed: %.3f s, iterations: %d, converged: %s\n",
            t_cavi[["elapsed"]], cavi$n_iter, cavi$converged))
saveRDS(cavi, file.path(OUT_DIR, "M0_cavi_fit.rds"))

# ELBO convergence plot (300 dpi)
png(file.path(FIG_DIR, "M0_cavi_elbo.png"), width = 1600, height = 1000, res = 300)
plot(cavi$elbo_trace, type = "l", lwd = 2, col = "#1f5f99",
     xlab = "Coordinate-ascent iteration", ylab = "ELBO",
     main = "M0 CAVI: ELBO convergence")
dev.off()
cat("Saved ELBO plot to figures/M0_cavi_elbo.png\n")

# ------------------------------------------------------------
# 2. Hand-written Gibbs (timed, fresh run)
# ------------------------------------------------------------
cat("\n--- Hand-written Gibbs ---\n")
t_gibbs <- system.time(
  gibbs <- fit_m0_gibbs(y, X, n_chains = N_CHAINS, n_iter = N_ITER,
                        n_burn = N_BURN, thin = THIN, seed = SEED,
                        verbose = FALSE)
)
cat(sprintf("Gibbs elapsed: %.3f s (%d chains x %d iter, thin=%d)\n",
            t_gibbs[["elapsed"]], N_CHAINS, N_ITER, THIN))
dg_gibbs <- m0_diagnostics(gibbs, "M0 / Gibbs (runtime run)")
cat(sprintf("  max R-hat = %.4f, min ESS = %.0f\n",
            dg_gibbs$rhat_max, dg_gibbs$ess_min))

# ------------------------------------------------------------
# 3. JAGS (timed, fresh run)
# ------------------------------------------------------------
cat("\n--- JAGS ---\n")
t_jags <- system.time(
  jags <- fit_m0_jags(y, X, n_chains = N_CHAINS, n_iter = N_ITER,
                      n_burn = N_BURN, thin = THIN, seed = SEED,
                      verbose = FALSE)
)
cat(sprintf("JAGS elapsed: %.3f s (%d chains x %d iter, thin=%d)\n",
            t_jags[["elapsed"]], N_CHAINS, N_ITER, THIN))
dg_jags <- m0_diagnostics(jags, "M0 / JAGS (runtime run)")
cat(sprintf("  max R-hat = %.4f, min ESS = %.0f\n",
            dg_jags$rhat_max, dg_jags$ess_min))

# ------------------------------------------------------------
# 4. Three-method comparison table
# ------------------------------------------------------------
cmp <- m0_three_method_compare(gibbs, jags, cavi)
write.csv(cmp, file.path(TAB_DIR, "M0_three_method_comparison.csv"), row.names = FALSE)
cat("\nSaved tables/M0_three_method_comparison.csv\n")
print(cmp[, c("parameter", "gibbs_mean", "jags_mean", "cavi_mean",
              "gibbs_width95", "jags_width95", "cavi_width95",
              "cavi_width_vs_gibbs")], digits = 5)

# Grouped-interval-width figure for slides (300 dpi).
# X axis = parameter (beta1-beta7, sigma2); Y axis = 95% interval width.
png(file.path(FIG_DIR, "M0_three_method_intervals.png"),
    width = 1600, height = 1000, res = 300)
par(mar = c(5.1, 6.1, 4.1, 2.1))
# Reserve an empty strip below the smallest interval width for a horizontal legend.
# This avoids occluding beta7/sigma2 points, as happened in the old top-right legend.
rk <- seq_len(nrow(cmp))
# Human-readable parameter labels via plotmath (Unicode beta/sigma fails
# to render in R's PNG device on Windows -> use expressions instead).
plab <- expression(beta[1], beta[2], beta[3], beta[4], beta[5],
                   beta[6], beta[7], sigma^2)
lo <- min(cmp$gibbs_width95, cmp$jags_width95, cmp$cavi_width95)
hi <- max(cmp$gibbs_width95, cmp$jags_width95, cmp$cavi_width95)
pad <- 0.15 * (hi - lo)
plot(rk, cmp$gibbs_width95, type = "n",
     ylim = c(lo - max(0.35 * (hi - lo), 2 * pad), hi + pad),
     xaxt = "n", xlab = "Parameter", ylab = "95% interval width",
     main = "M0 95% interval width by method")
axis(1, at = rk, labels = plab, cex.axis = 0.9)
points(rk - 0.22, cmp$gibbs_width95, pch = 16, col = "#1f5f99", cex = 1.2)
points(rk,        cmp$jags_width95,  pch = 16, col = "#2e8b57", cex = 1.2)
points(rk + 0.22, cmp$cavi_width95,  pch = 16, col = "#d9534f", cex = 1.2)
legend("bottom", legend = c("Gibbs", "JAGS", "CAVI"), horiz = TRUE,
       col = c("#1f5f99", "#2e8b57", "#d9534f"), pch = 16,
       inset = 0.02, bty = "n", cex = 0.9)
dev.off()
cat("Saved figures/M0_three_method_intervals.png\n")

# ------------------------------------------------------------
# 5. Runtime comparison table
# ------------------------------------------------------------
# M0 rows: measured above on this machine (R 4.5.1, JAGS 4.3.2).
# M1b row: P4's already-uploaded timing evidence, NOT re-run by P2.
#   outputs/P4/timing_2000/status.txt (77.71 s for 500 draws/chain)
#   outputs/P4/timing_2000_corrected/status.txt (68.48 s, glm sampler)
#   docs/P4_DELIVERY.md: full baseline 1276.75 s for 4000 draws/chain,
#   4 parallel R workers, 6,489 games, 56 predictors + designer effects,
#   machine: 32 GB RAM / 22 logical CPUs, R 4.5.3, JAGS 4.3.2.
# We report seconds per 1,000 kept draws per chain where meaningful.
kept_per_chain <- floor((N_ITER - N_BURN) / THIN)
runtime <- data.frame(
  method   = c("M0 CAVI", "M0 hand-written Gibbs", "M0 JAGS",
               "M1b JAGS (P2 independent probe)",
               "M1b JAGS (P4 pilot, corrected)", "M1b JAGS (P4 full baseline)"),
  model    = c("M0", "M0", "M0", "M1b", "M1b", "M1b"),
  engine   = c("R coordinate ascent", "R loops", "JAGS via rjags",
               "JAGS glm, single chain", "JAGS glm, 4 parallel workers",
               "JAGS glm, 4 parallel workers"),
  games    = c(length(y), length(y), length(y), 6489L, 6489L, 6489L),
  chains   = c(1L, N_CHAINS, N_CHAINS, 1L, 4L, 4L),
  kept_draws_per_chain = c(NA_integer_, kept_per_chain, kept_per_chain, 1000L, 500L, 4000L),
  elapsed_seconds = c(t_cavi[["elapsed"]], t_gibbs[["elapsed"]],
                      t_jags[["elapsed"]], 52.03, 68.48, 1276.75),
  seconds_per_1000_kept_draws = c(NA_real_,
    1000 * t_gibbs[["elapsed"]] / kept_per_chain,
    1000 * t_jags[["elapsed"]] / kept_per_chain,
    52.03,
    1000 * 68.48 / 500,
    1000 * 1276.75 / 4000),
  timed_stage = c(
    "full deterministic fit to ELBO convergence; no warm-up/burn-in",
    "full run incl. 2000 burn-in per chain; Gibbs has no adaptation stage",
    "full run incl. JAGS adaptation + 2000 burn-in per chain",
    "SAMPLING ONLY (excl. 200 adapt + 200 burn-in, warm-up 25.17s reported separately)",
    "full run incl. compile + adaptation + burn-in + batched diagnostics; 4 chains in parallel",
    "full run incl. compile + 2000 adapt + 2000 burn-in + batched diagnostics; 4 chains in parallel"),
  comparable = c(
    "M0 - CAVI deterministic",
    "M0 - compare within M0",
    "M0 - compare within M0",
    "M1b - single chain; NOT comparable to P4 4-chain parallel",
    "M1b - 4-chain parallel; NOT comparable to P2 single chain",
    "M1b - 4-chain parallel; NOT comparable to P2 single chain"),
  source = c("P2 measured", "P2 measured", "P2 measured",
             "P2 measured (P2_M1b_timing.R, 1 chain)",
             "P4 uploaded timing_2000_corrected/status.txt",
             "P4 uploaded docs/P4_DELIVERY.md"),
  row.names = NULL
)
runtime$seconds_per_1000_kept_draws <- round(runtime$seconds_per_1000_kept_draws, 3)
write.csv(runtime, file.path(TAB_DIR, "M0_M1b_runtime_comparison.csv"), row.names = FALSE)
cat("\nSaved tables/M0_M1b_runtime_comparison.csv\n")
print(runtime[, c("method", "elapsed_seconds", "seconds_per_1000_kept_draws",
                  "timed_stage", "source")], digits = 5)

# Session info for reproducibility
sink(file.path(OUT_DIR, "M0_cavi_session_info.txt"))
cat("R:", R.version.string, "\n")
cat("cavi settings: tol=1e-10, max_iter=10000\n")
cat("MCMC settings: chains=", N_CHAINS, ", n_iter=", N_ITER,
    ", n_burn=", N_BURN, ", thin=", THIN, ", seed=", SEED, "\n", sep = "")
cat("JAGS:", as.character(rjags::jags.version()), "\n")
sessionInfo()
sink()

cat("\n########## DONE ##########\n")
