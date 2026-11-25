# Quick correctness check for CAVI: ELBO monotone, mean matches Gibbs.
suppressPackageStartupMessages(library(coda))
.sd <- tryCatch(normalizePath(dirname(sys.frame(1)$ofile)), error = function(e) getwd())
if (!file.exists(file.path(.sd, "M0_functions.R"))) .sd <- getwd()
setwd(.sd)
source("M0_functions.R")
source("M0_cavi.R")

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
