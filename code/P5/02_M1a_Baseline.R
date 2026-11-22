# STAT6106 P5 — M1a Baseline, refit on SAME 6,416 games as external-SD Model D.
# Purpose: make a fair, game-ID-matched baseline. This script NEVER changes Model D or P1 files.
# Run from the same R working directory you used for 03_M1a_Extended_ExternalSD.R.
# Uses the existing fixed development-game IDs in the local P5 cache. No downloads or manual parameters.

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
})

# 1. Read EXACTLY the fixed Model D training games, in the SAME order.
in_path <- file.path("P5_external_SD", "P5_SD_matched.csv")
if (!file.exists(in_path)) {
  stop("Missing ", in_path,
       ". Run from your original P5 working directory (where P5_02 worked). ",
       "Do not substitute a newly sampled file.")
}
dat <- read.csv(in_path, stringsAsFactors = FALSE)
required <- c("id", "name", "average_2022", "n_2022")
stopifnot(all(required %in% names(dat)),
          nrow(dat) == 6416L,
          !anyDuplicated(dat$id),
          all(is.finite(dat$average_2022)),
          all(is.finite(dat$n_2022)),
          all(dat$n_2022 >= 30))

# Optional but recommended: verify Model D exists; do not touch it.
d_path <- file.path("P5_external_SD", "Model_D_calibrated", "parameter_draws.rds")
if (file.exists(d_path)) {
  d_saved <- readRDS(d_path)
  stopifnot(is.list(d_saved), !is.null(d_saved$draws))
  cat("Existing Model D parameter draws found; will NOT refit or modify Model D.\n")
  rm(d_saved)
} else {
  message("Note: Model D's RDS was not found locally. Model A can still be fitted, ",
          "but restore the original D files before doing A-vs-D comparisons.")
}

out_dir <- file.path("P5_external_SD", "Model_A_same_6416")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

N <- nrow(dat)
y <- dat$average_2022
n <- dat$n_2022
cat("Model A | fixed training games:", N, "\n")
cat("ID check: unique =", !anyDuplicated(dat$id), "\n")

# 2. EXACT original M1a-A likelihood and priors (not old Model D):
# y_i ~ Normal(alpha, tau^2 + s^2 / n_i)
# alpha ~ Normal(6.4, 1^2); s ~ Uniform(0.5, 3); tau ~ half-Cauchy(0, 1)
# m = s^2 / tau^2 (common pseudo-votes).
model_A <- "
model {
  for (i in 1:N) {
    prec[i] <- 1 / (tau^2 + s^2 / n[i])
    y[i] ~ dnorm(alpha, prec[i])
  }
  alpha ~ dnorm(6.4, 1)
  s ~ dunif(0.5, 3)
  tau ~ dt(0, 1, 1) T(0,)
  m <- s^2 / tau^2
}
"

# 3. Run the same MCMC budget as the external-SD D fit (four chains).
inits <- lapply(1:4, function(k) {
  list(.RNG.name = "base::Mersenne-Twister",
       .RNG.seed = as.integer(20261122L + 100L + k))
})
fit <- jags.model(textConnection(model_A),
                  data = list(N = N, y = y, n = n),
                  inits = inits, n.chains = 4,
                  n.adapt = 1000, quiet = TRUE)
update(fit, n.iter = 3000, progress.bar = "none")
samples <- coda.samples(fit, variable.names = c("alpha", "s", "tau", "m"),
                        n.iter = 3000, progress.bar = "none")

print(summary(samples))
print(gelman.diag(samples, multivariate = FALSE))
print(effectiveSize(samples))

z <- as.matrix(samples)
stopifnot(all(c("alpha", "s", "tau", "m") %in% colnames(z)))
rhat <- gelman.diag(samples, multivariate = FALSE)$psrf
convergence <- data.frame(
  parameter = colnames(z),
  rhat = unname(rhat[colnames(z), "Point est."]),
  ess = unname(effectiveSize(samples)[colnames(z)])
)
write.csv(convergence, file.path(out_dir, "convergence.csv"), row.names = FALSE)

summary_params <- data.frame(
  parameter = colnames(z),
  posterior_mean = unname(colMeans(z)),
  lower95 = unname(apply(z, 2, quantile, probs = 0.025)),
  upper95 = unname(apply(z, 2, quantile, probs = 0.975))
)
write.csv(summary_params, file.path(out_dir, "parameter_summary.csv"), row.names = FALSE)

# Save full parameter draws for later SAME-SAMPLE A-vs-D validation.
saveRDS(list(draws = z, model = model_A, ids = dat$id,
             input_md5 = unname(tools::md5sum(in_path)),
             note = "Original M1a baseline on D-matched 6416 development games"),
        file.path(out_dir, "parameter_draws.rds"))

# 4. Conditional latent theta draws (same format and 500 draws as D) for optional P6 comparison.
# theta_i | y_i,params ~ Normal(alpha + w_i*(y_i-alpha), tau^2*(s^2/n_i)/(tau^2+s^2/n_i)).
set.seed(610608)
B <- 500L
pick <- sample.int(nrow(z), B, replace = FALSE)
theta <- matrix(NA_real_, nrow = N, ncol = B)

for (b in seq_len(B)) {
  d <- z[pick[b], ]
  tau2 <- unname(d["tau"]^2)
  v_obs <- unname(d["s"]^2 / n)
  weight <- tau2 / (tau2 + v_obs)
  post_mean <- unname(d["alpha"] + weight * (y - d["alpha"]))
  post_sd <- sqrt(tau2 * v_obs / (tau2 + v_obs))
  theta[, b] <- rnorm(N, mean = post_mean, sd = post_sd)
}
rownames(theta) <- as.character(dat$id)
saveRDS(list(id = dat$id, name = dat$name, theta_draws = theta,
             note = "Model A baseline; fixed 6416 development games only"),
        file.path(out_dir, "latent_rating_draws_for_P6.rds"))

post_mean <- rowMeans(theta)
ratings_out <- data.frame(
  id = dat$id, name = dat$name, n_2022 = n, raw_average = y,
  posterior_mean = post_mean,
  ci_lower = apply(theta, 1, quantile, probs = 0.025),
  ci_upper = apply(theta, 1, quantile, probs = 0.975),
  adjustment = post_mean - y,
  stringsAsFactors = FALSE
)
write.csv(ratings_out, file.path(out_dir, "posterior_ratings_development.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
rm(theta)

# 5. Same grouped PPC bands / output columns as external-SD D.
groups <- list(
  "30-40" = which(n >= 30 & n <= 40),
  "100-200" = which(n >= 100 & n <= 200),
  "1000-5000" = which(n >= 1000 & n <= 5000),
  "5000+" = which(n > 5000)
)
stopifnot(all(lengths(groups) >= 2L))
set.seed(610609)
rep_means <- matrix(NA_real_, nrow = B, ncol = length(groups))
rep_vars  <- matrix(NA_real_, nrow = B, ncol = length(groups))
for (b in seq_len(B)) {
  d <- z[pick[b], ]
  for (g in seq_along(groups)) {
    ix <- groups[[g]]
    y_rep <- rnorm(length(ix), mean = unname(d["alpha"]),
                   sd = sqrt(unname(d["tau"]^2 + d["s"]^2 / n[ix])))
    rep_means[b, g] <- mean(y_rep)
    rep_vars[b, g] <- var(y_rep)
  }
}
qcol <- function(a, p) unname(apply(a, 2, quantile, probs = p))
ppc <- data.frame(
  group = names(groups),
  games = lengths(groups),
  observed_mean = vapply(groups, function(ix) mean(y[ix]), numeric(1)),
  pred_mean_median = qcol(rep_means, 0.5),
  pred_mean_low = qcol(rep_means, 0.025),
  pred_mean_high = qcol(rep_means, 0.975),
  observed_variance = vapply(groups, function(ix) var(y[ix]), numeric(1)),
  pred_variance_median = qcol(rep_vars, 0.5),
  pred_variance_low = qcol(rep_vars, 0.025),
  pred_variance_high = qcol(rep_vars, 0.975),
  row.names = NULL
)
write.csv(ppc, file.path(out_dir, "grouped_PPC_development.csv"), row.names = FALSE)
print(ppc, row.names = FALSE)

cat("\nDONE: Model A fitted on exactly 6,416 matched development games.\n")
cat("Saved in:", normalizePath(out_dir), "\n")
cat("Model D unchanged. Holdout was NOT used in fitting.\n")
cat("Reminder: Model A baseline's s upper prior bound is 3; verify s posterior and PPC before substantive claims.\n")