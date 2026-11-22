# STAT6106 / P5 — Stage 2: Model D with game-specific historical SD
# Run AFTER P5_01_save_SD_lookup.R.
# This script does NOT download/read either large source dataset.
# Fits on matched DEVELOPMENT games only; comparison_sample is reserved.

library(rjags)
library(coda)

set.seed(6106)
in_path <- file.path("P5_external_SD", "P5_SD_matched.csv")
out_dir <- file.path("P5_external_SD", "Model_D_calibrated")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

dat <- read.csv(in_path, stringsAsFactors = FALSE)
stopifnot(nrow(dat) == 6416, !anyDuplicated(dat$id),
          all(is.finite(dat$average_2022)),
          all(dat$n_2022 >= 30),
          all(is.finite(dat$sd_hist) & dat$sd_hist > 0))

n <- dat$n_2022
y <- dat$average_2022
x_center <- mean(log(n))                 # fitted ONLY on development games
x <- log(n) - x_center
v_obs <- dat$sd_hist^2 / n                # fixed plug-in observation variance

# Model D, but no shared unidentifiable s:
# y_i ~ N(mu_i, tau_i^2 + sd_hist_i^2 / n_i)
# mu_i = alpha + gamma*x_i
# log(tau_i) = a_tau + b_tau*x_i
model_D_calibrated <- "
model {
  for (i in 1:N) {
    mu[i] <- alpha + gamma*x[i]
    tau2[i] <- exp(2*(a_tau + b_tau*x[i]))
    y[i] ~ dnorm(mu[i], 1/(tau2[i] + v_obs[i]))
  }
  alpha ~ dnorm(6.4, 1)
  gamma ~ dnorm(0, 1)
  a_tau ~ dnorm(log(0.85), 4)
  b_tau ~ dnorm(0, 16)
}
"

jags_data <- list(N = length(y), y = y, x = x, v_obs = v_obs)
inits <- lapply(1:4, function(k) {
  list(.RNG.name = "base::Mersenne-Twister", .RNG.seed = 20261122L + k)
})
fit <- jags.model(textConnection(model_D_calibrated), data = jags_data,
                  inits = inits, n.chains = 4, n.adapt = 1000, quiet = TRUE)
update(fit, n.iter = 3000, progress.bar = "none")
samples <- coda.samples(fit, variable.names = c("alpha", "gamma", "a_tau", "b_tau"),
                        n.iter = 3000, progress.bar = "none")

print(summary(samples))
print(gelman.diag(samples, multivariate = FALSE))
print(effectiveSize(samples))

z <- as.matrix(samples)
saveRDS(list(draws = z, x_center = x_center, model = model_D_calibrated),
        file.path(out_dir, "parameter_draws.rds"))
rhat <- gelman.diag(samples, multivariate = FALSE)$psrf
convergence <- data.frame(parameter = colnames(z),
                          rhat = rhat[colnames(z), "Point est."],
                          ess = unname(effectiveSize(samples)[colnames(z)]))
write.csv(convergence, file.path(out_dir, "convergence.csv"), row.names = FALSE)

# Posterior latent-rating draws for P6. Includes BOTH parameter and latent uncertainty.
# IMPORTANT: ranking over this partial development sample is not a global BGG Top 10.
B <- 500
pick <- sample.int(nrow(z), B)
theta <- matrix(NA_real_, nrow = length(y), ncol = B)
mu_pred <- matrix(NA_real_, nrow = length(y), ncol = B)
var_pred <- matrix(NA_real_, nrow = length(y), ncol = B)

for (b in seq_len(B)) {
  d <- z[pick[b], ]
  mu <- unname(d["alpha"] + d["gamma"]*x)
  tau2 <- unname(exp(2*(d["a_tau"] + d["b_tau"]*x)))
  weight <- tau2 / (tau2 + v_obs)
  post_mean <- mu + weight*(y - mu)
  post_sd <- sqrt(tau2*v_obs/(tau2 + v_obs))
  theta[, b] <- rnorm(length(y), mean = post_mean, sd = post_sd)
  mu_pred[, b] <- mu
  var_pred[, b] <- tau2 + v_obs
}

rownames(theta) <- as.character(dat$id)
saveRDS(list(id = dat$id, name = dat$name, theta_draws = theta,
             x_center = x_center, note = "Development-sample games only"),
        file.path(out_dir, "latent_rating_draws_for_P6.rds"))

ratings_out <- data.frame(
  id = dat$id, name = dat$name, n_2022 = n, raw_average = y,
  sd_hist = dat$sd_hist,
  posterior_mean = rowMeans(theta),
  ci_lower = apply(theta, 1, quantile, probs = 0.025),
  ci_upper = apply(theta, 1, quantile, probs = 0.975),
  stringsAsFactors = FALSE
)
ratings_out$adjustment <- ratings_out$posterior_mean - ratings_out$raw_average
write.csv(ratings_out, file.path(out_dir, "posterior_ratings_development.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

# Grouped posterior predictive check (same bands used in earlier M1a experiments).
groups <- list(
  "30-40" = which(n >= 30 & n <= 40),
  "100-200" = which(n >= 100 & n <= 200),
  "1000-5000" = which(n >= 1000 & n <= 5000),
  "5000+" = which(n > 5000)
)
rep_means <- matrix(NA_real_, nrow = B, ncol = length(groups))
rep_vars <- matrix(NA_real_, nrow = B, ncol = length(groups))
for (b in seq_len(B)) {
  for (g in seq_along(groups)) {
    ix <- groups[[g]]
    if (length(ix) < 2) next
    yy <- rnorm(length(ix), mu_pred[ix, b], sqrt(var_pred[ix, b]))
    rep_means[b, g] <- mean(yy)
    rep_vars[b, g] <- var(yy)
  }
}
q <- function(a, p) apply(a, 2, quantile, probs = p, na.rm = TRUE)
ppc <- data.frame(
  group = names(groups),
  games = sapply(groups, length),
  observed_mean = sapply(groups, function(ix) mean(y[ix])),
  pred_mean_median = q(rep_means, 0.5),
  pred_mean_low = q(rep_means, 0.025),
  pred_mean_high = q(rep_means, 0.975),
  observed_variance = sapply(groups, function(ix) var(y[ix])),
  pred_variance_median = q(rep_vars, 0.5),
  pred_variance_low = q(rep_vars, 0.025),
  pred_variance_high = q(rep_vars, 0.975),
  row.names = NULL
)
print(ppc)
write.csv(ppc, file.path(out_dir, "grouped_PPC_development.csv"), row.names = FALSE)

cat("\nOutputs saved in:", normalizePath(out_dir), "\n")
cat("Note: these are preliminary development-sample results.\n")
cat("Historical SDs are approximations from an unverified matching snapshot.\n")