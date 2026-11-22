# ============================================================
# P2 / M0: main runner -- self-test first, then real data
# Run this file top-to-bottom. Two modes:
#   MODE = "selftest"  : simulated data with KNOWN beta / sigma2.
#                       Verifies the hand-written Gibbs recovers truth.
#                       Use this tonight -- no external data needed.
#   MODE = "real"      : real BGG data. Before 22 Nov use ratings.csv;
#                       from 22 Nov switch to P1's comparison_sample.csv.
# See README.md for the run checklist.
# ============================================================

suppressPackageStartupMessages({
  library(coda)
})

# Auto-locate this script's folder, so all relative paths below work
# no matter where R was started. Falls back to the known local path.
.script_dir <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile)),
  error = function(e) NA_character_
)
if (is.na(.script_dir) || !file.exists(file.path(.script_dir, "M0_functions.R"))) {
  .script_dir <- "C:/Users/28131/WorkBuddy/2026-11-20-18-32-14/code/P2_m0"
}
setwd(.script_dir)
cat("Working directory:", getwd(), "\n")

source("M0_functions.R")

# ---- USER SETTINGS -------------------------------------------
MODE     <- "real"         # "selftest" or "real"
SEED     <- 42             # Proposal: seed 42 for all models
N_ITER   <- 12000          # total iterations per chain
N_BURN   <- 2000           # burn-in
THIN     <- 5              # thinning
N_CHAINS <- 4              # Proposal: 4 chains

# Settings for MODE = "real"
DATA_PATH <- "../../data/comparison_sample.csv"   # relative to code/P2_m0
Y_COL     <- "average"    # outcome
X_COLS    <- NULL         # NULL = auto-detect (see below). Or e.g. c("log_n", "year_scaled")

# Where outputs go (repo layout)
OUT_DIR <- "../../outputs"
FIG_DIR <- "../../figures"
TAB_DIR <- "../../tables"
for (d in c(OUT_DIR, FIG_DIR, TAB_DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- HELPER: convergence summary printed to console ----------
report_conv <- function(mc, label) {
  dg <- m0_diagnostics(mc, label)
  cat("\n== Convergence:", label, "==\n")
  cat(sprintf("  max R-hat = %.4f  (target <= 1.01)\n", dg$rhat_max))
  cat(sprintf("  min ESS   = %.0f   (target >= 400)\n", dg$ess_min))
  ok <- dg$rhat_max <= 1.01 && dg$ess_min >= 400
  cat(if (ok) "  STATUS: converged\n" else "  STATUS: CHECK -- did not meet target\n")
  invisible(dg)
}

# ============================================================
# MODE 1: SELF-TEST on simulated data
# If the sampler is correct, posterior means should sit near the
# true beta and true sigma2, and a 95% interval should cover them.
# ============================================================
if (MODE == "selftest") {
  cat("\n########## SELF-TEST (simulated data) ##########\n")

  set.seed(SEED)
  n_sim <- 600
  p_sim <- 3
  # True parameters: intercept near BGG mean rating 6.4, two slopes.
  beta_true  <- c(6.4, 0.5, -0.3)
  sigma_true <- 0.9
  sigma2_true <- sigma_true^2

  X_sim <- cbind(1,
                 rnorm(n_sim, 0, 1),
                 rnorm(n_sim, 0, 1))
  colnames(X_sim) <- c("(Intercept)", "x1", "x2")
  y_sim <- as.vector(X_sim %*% beta_true) + rnorm(n_sim, 0, sigma_true)

  cat(sprintf("Simulated n=%d, true beta=(%s), true sigma2=%.3f\n",
              n_sim, paste(round(beta_true, 2), collapse = ", "), sigma2_true))

  # --- Fit with the hand-written Gibbs sampler ---
  cat("\nFitting hand-written Gibbs...\n")
  fit_gibbs <- fit_m0_gibbs(y_sim, X_sim, n_chains = N_CHAINS,
                            n_iter = N_ITER, n_burn = N_BURN,
                            thin = THIN, seed = SEED)
  dg_gibbs <- report_conv(fit_gibbs, "SELFTEST / Gibbs")

  # --- Truth-recovery check ---
  g_stats <- summary(fit_gibbs)$statistics
  cat("\n== Truth recovery (Gibbs) ==\n")
  cat(sprintf("  %-12s %8s %8s %8s %8s\n", "param", "truth", "post.mean", "2.5%", "97.5%"))
  for (k in seq_len(p_sim)) {
    cat(sprintf("  %-12s %8.3f %8.3f %8.3f %8.3f\n",
                colnames(X_sim)[k], beta_true[k],
                g_stats[k, "Mean"], g_stats[k, "2.5%"], g_stats[k, "97.5%"]))
  }
  cat(sprintf("  %-12s %8.3f %8.3f %8.3f %8.3f\n",
              "sigma2", sigma2_true,
              g_stats["sigma2", "Mean"], g_stats["sigma2", "2.5%"], g_stats["sigma2", "97.5%"]))
  covered <- all(
    beta_true >= g_stats[seq_len(p_sim), "2.5%"] & beta_true <= g_stats[seq_len(p_sim), "97.5%"]
  ) && sigma2_true >= g_stats["sigma2", "2.5%"] && sigma2_true <= g_stats["sigma2", "97.5%"]
  cat(if (covered) "  All true values inside 95% intervals -> sampler looks correct.\n"
      else "  WARNING: some true values outside 95% intervals -> check the code.\n")

  # --- Fit with JAGS if available, and compare ---
  if (requireNamespace("rjags", quietly = TRUE)) {
    cat("\nFitting JAGS...\n")
    fit_jags <- fit_m0_jags(y_sim, X_sim, n_chains = N_CHAINS,
                            n_iter = N_ITER, n_burn = N_BURN,
                            thin = THIN, seed = SEED)
    report_conv(fit_jags, "SELFTEST / JAGS")
    cat("\n== JAGS vs Gibbs (should agree) ==\n")
    print(m0_compare(fit_gibbs, fit_jags))
  } else {
    cat("\n[rjags not installed -- skipped JAGS. Gibbs self-test still valid.]\n")
  }

  cat("\n########## END SELF-TEST ##########\n")
}

# ============================================================
# MODE 2: REAL DATA
# Before 22 Nov: point DATA_PATH at ratings.csv; a minimal X is
# built on the fly (log users_rated = sample size proxy is NOT used
# here; M0 uses game features only). From 22 Nov: use P1's file.
# ============================================================
if (MODE == "real") {
  cat("\n########## REAL DATA ##########\n")
  source("M0_prepare.R")

  # Defensive cleaning: P1's file is a raw join, so apply Proposal
  # cleaning rules here instead of feeding dirty values into the model.
  prep <- m0_prepare(DATA_PATH, y_col = Y_COL)
  y <- prep$y
  X <- prep$X

  cat("\nFitting hand-written Gibbs on real data...\n")
  fit_gibbs <- fit_m0_gibbs(y, X, n_chains = N_CHAINS,
                            n_iter = N_ITER, n_burn = N_BURN,
                            thin = THIN, seed = SEED)
  dg_gibbs <- report_conv(fit_gibbs, "M0 / Gibbs")
  saveRDS(fit_gibbs, file.path(OUT_DIR, "M0_gibbs_draws.rds"))
  saveRDS(dg_gibbs,  file.path(OUT_DIR, "M0_gibbs_diagnostics.rds"))

  # Pointwise log-likelihood for P5's WAIC (save as n_draws x n matrix)
  ll_gibbs <- m0_pointwise_loglik(fit_gibbs, y, X)
  saveRDS(ll_gibbs, file.path(OUT_DIR, "M0_loglik_gibbs.rds"))
  cat(sprintf("Saved pointwise loglik: %d draws x %d obs\n", nrow(ll_gibbs), ncol(ll_gibbs)))

  if (requireNamespace("rjags", quietly = TRUE)) {
    cat("\nFitting JAGS on real data...\n")
    fit_jags <- fit_m0_jags(y, X, n_chains = N_CHAINS,
                            n_iter = N_ITER, n_burn = N_BURN,
                            thin = THIN, seed = SEED)
    dg_jags <- report_conv(fit_jags, "M0 / JAGS")
    saveRDS(fit_jags, file.path(OUT_DIR, "M0_jags_draws.rds"))
    saveRDS(dg_jags,  file.path(OUT_DIR, "M0_jags_diagnostics.rds"))
    ll_jags <- m0_pointwise_loglik(fit_jags, y, X)
    saveRDS(ll_jags, file.path(OUT_DIR, "M0_loglik_jags.rds"))

    cmp <- m0_compare(fit_gibbs, fit_jags)
    write.csv(cmp, file.path(TAB_DIR, "M0_method_comparison.csv"), row.names = FALSE)
    cat("\nSaved JAGS vs Gibbs comparison table.\n")
    print(cmp)
  } else {
    cat("\n[rjags not installed -- JAGS fit and comparison skipped.]\n")
  }

  # Trace plots for the report (300 dpi PNG)
  png(file.path(FIG_DIR, "M0_trace_gibbs.png"), width = 1600, height = 1200, res = 300)
  plot(fit_gibbs, trace = TRUE, density = FALSE, main = "M0 Gibbs trace")
  dev.off()
  cat("Saved trace plot to figures/M0_trace_gibbs.png\n")

  cat("\n########## END REAL DATA ##########\n")
}


install.packages("rjags")


                 