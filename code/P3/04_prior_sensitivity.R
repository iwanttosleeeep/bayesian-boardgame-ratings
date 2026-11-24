args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
setwd(root)
suppressPackageStartupMessages(library(coda))

design <- readRDS("outputs/P3/M2_design.rds")
base <- readRDS("outputs/P3/M2_NB_posterior.rds")
y <- design$y
X <- design$X
age <- design$age
alpha_mean <- log(median(y))
base_draws <- base$draws
base_draws[, "r"] <- log(base_draws[, "r"])
parameter_names <- colnames(base_draws)
P <- length(parameter_names)
proposal_cov <- cov(base_draws)
proposal_cov <- proposal_cov + diag(1e-8 * mean(diag(proposal_cov)), P)
proposal_chol <- chol(proposal_cov)
warmup <- 2000L
n_samples <- 24000L
thin <- 24L
n_saved <- n_samples %/% thin

log_posterior <- function(par) {
  alpha <- par[1]
  beta <- par[2:(ncol(X) + 1L)]
  delta <- par[ncol(X) + 2L]
  log_r <- par[P]
  r <- exp(log_r)
  eta <- as.numeric(alpha + X %*% beta + delta * age)
  if (any(!is.finite(eta)) || any(eta > 700 | eta < -700)) return(-Inf)
  mu <- exp(eta)
  ll <- sum(dnbinom(y, size = r, mu = mu, log = TRUE) -
            pnbinom(29, size = r, mu = mu, lower.tail = FALSE, log.p = TRUE))
  prior <- dnorm(alpha, alpha_mean, 2, log = TRUE) +
    sum(dnorm(beta, 0, 2, log = TRUE)) + dnorm(delta, 0, 2, log = TRUE) +
    dgamma(r, shape = 1, rate = 0.1, log = TRUE) + log_r
  value <- ll + prior
  if (is.finite(value)) value else -Inf
}

fit_chain <- function(chain) {
  set.seed(42L + chain - 1L)
  current <- base_draws[sample.int(nrow(base_draws), 1L), ]
  current_lp <- log_posterior(current)
  draws <- matrix(NA_real_, n_saved, P, dimnames = list(NULL, parameter_names))
  log_step <- log(0.5)
  accepted <- integer()
  saved <- 0L
  final_step <- NA_real_
  post_accept <- 0L
  for (iter in seq_len(warmup + n_samples)) {
    step <- exp(log_step)
    proposal <- current + step * as.numeric(t(proposal_chol) %*% rnorm(P))
    proposal_lp <- log_posterior(proposal)
    accept <- log(runif(1)) < min(0, proposal_lp - current_lp)
    if (accept) {
      current <- proposal
      current_lp <- proposal_lp
    }
    if (iter <= warmup) {
      accepted <- c(accepted, as.integer(accept))
      if (length(accepted) == 50L) {
        log_step <- log_step + 0.2 * (mean(accepted) - 0.3)
        log_step <- max(-8, min(2, log_step))
        accepted <- integer()
      }
      if (iter == warmup) final_step <- exp(log_step)
    } else {
      if (iter == warmup + 1L) final_step <- exp(log_step)
      post_accept <- post_accept + as.integer(accept)
      if ((iter - warmup) %% thin == 0L) {
        saved <- saved + 1L
        draws[saved, ] <- current
      }
    }
  }
  list(draws = draws, acceptance = post_accept / n_samples, final_step = final_step)
}

cl <- parallel::makeCluster(4)
parallel::clusterExport(cl, c("base_draws", "proposal_chol", "log_posterior", "y", "X",
                              "age", "alpha_mean", "P", "parameter_names", "warmup",
                              "n_samples", "thin", "n_saved"), envir = environment())
chains <- tryCatch(parallel::parLapply(cl, 1:4, fit_chain),
                   finally = parallel::stopCluster(cl))
for (chain in seq_along(chains)) {
  chains[[chain]]$draws[, "r"] <- exp(chains[[chain]]$draws[, "r"])
}
draws <- do.call(rbind, lapply(chains, `[[`, "draws"))
samples <- mcmc.list(lapply(chains, function(z) mcmc(z$draws)))
wide <- list(
  draws = draws,
  chain = rep(1:4, each = n_saved),
  iteration = rep(seq_len(n_saved), 4),
  family = "negbin", label = "NB", prior_set = "wide", x_names = design$x_names,
  run = list(seed = 42L, chains = 4L, engine = "Random-walk Metropolis", cores = 4L,
             n_adapt = warmup, n_burn = 0L, n_iter_per_chain = n_samples, thin = thin,
             saved_per_chain = n_saved, total_saved = nrow(draws),
             acceptance_rates = vapply(chains, `[[`, numeric(1), "acceptance"),
             final_step_sizes = vapply(chains, `[[`, numeric(1), "final_step")),
  prior = list(beta_precision = 0.25, r_shape = 1, r_rate = 0.1)
)
saveRDS(wide, "outputs/P3/M2_NB_wide_posterior.rds", compress = "gzip")

rhat <- gelman.diag(samples, autoburnin = FALSE, multivariate = FALSE)$psrf[, 1]
ess <- effectiveSize(samples)
diagnostics <- data.frame(parameter = names(rhat), rhat = as.numeric(rhat),
                          ess = as.numeric(ess[names(rhat)]), row.names = NULL)
write.csv(diagnostics, "tables/P3/M2_NB_wide_convergence.csv", row.names = FALSE)

wide_draws <- wide$draws[, colnames(base$draws), drop = FALSE]
result <- data.frame(
  parameter = colnames(base$draws),
  base_mean = colMeans(base$draws),
  wide_mean = colMeans(wide_draws),
  base_q025 = apply(base$draws, 2, quantile, 0.025),
  base_median = apply(base$draws, 2, median),
  base_q975 = apply(base$draws, 2, quantile, 0.975),
  wide_q025 = apply(wide_draws, 2, quantile, 0.025),
  wide_median = apply(wide_draws, 2, median),
  wide_q975 = apply(wide_draws, 2, quantile, 0.975),
  row.names = NULL
)
result$median_difference <- result$wide_median - result$base_median
write.csv(result, "tables/P3/M2_prior_sensitivity.csv", row.names = FALSE)
cat("Maximum R-hat:", max(diagnostics$rhat, na.rm = TRUE),
    " Minimum ESS:", min(diagnostics$ess, na.rm = TRUE), "\n")
cat("Acceptance rates:", paste(round(wide$run$acceptance_rates, 3), collapse = ", "), "\n")
print(result[result$parameter %in% c("beta[1]", "beta[2]", "beta[3]", "beta[4]",
                                     "delta", "r"), ])
