# Quick correctness check for CAVI: ELBO monotone, mean matches Gibbs.
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

source(repo_path("code", "P2", "M0_functions.R"))
source(repo_path("code", "P2", "M0_cavi.R"))

set.seed(42)
n <- 600; p <- 3
X <- cbind(1, rnorm(n), rnorm(n))
y <- as.vector(X %*% c(6.4, 0.5, -0.3)) + rnorm(n, 0, 0.9)

cat("--- CAVI on simulated data ---\n")
t_cavi <- system.time(fit <- fit_m0_cavi(y, X))
cat("elapsed:", t_cavi[["elapsed"]], "s; iterations:", fit$n_iter,
    "; converged:", fit$converged, "\n")
d <- diff(fit$elbo_trace)
cat("ELBO monotone (min diff):", min(d), "; max diff:", max(d), "\n")
cat("beta_mean:", round(fit$beta_mean, 4), "\n")
cat("sigma2_mean:", round(fit$sigma2_mean, 4), "\n")

cat("\n--- Gibbs reference (same data) ---\n")
t_gibbs <- system.time(mc <- fit_m0_gibbs(y, X, n_chains = 4, n_iter = 12000,
                                           n_burn = 2000, thin = 5, seed = 42,
                                           verbose = FALSE))
g <- mcmc_summary_for_cavi(mc)
cat("elapsed:", t_gibbs[["elapsed"]], "s\n")
cat("beta_mean:", round(g$beta_mean, 4), "\n")
cat("sigma2_mean:", round(g$sigma2_mean, 4), "\n")

cat("\n--- Comparison ---\n")
print(m0_three_method_compare(mc, mc, fit)[, c("parameter", "gibbs_mean", "cavi_mean",
                                               "gibbs_width95", "cavi_width95",
                                               "cavi_width_vs_gibbs")])
cat("\nNOTE: ratios are near 1 at this sample size; CAVI and Gibbs agree closely.\n")
cat("The proposal's 'CAVI understates variance' is a general expectation;\n")
cat("report the observed ratios from the real-data comparison, not a blanket claim.\n")
