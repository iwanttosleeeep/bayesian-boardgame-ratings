# STAT6106 P5 — external-SD sensitivity for M1a Extended (External SD)
# Uses ONLY locally saved P5_SD_matched.csv and the M1a Extended reference fit fit.
# No CSV downloads, no repeat of the earlier A-F experiments.
# Three SD scenarios: 0.8x, 1.0x, 1.2x historical within-game SD.
# 1.0x reuses saved posterior draws; 0.8x/1.2x are refitted in JAGS.
# Compare POSTERIOR SHRINKAGE under the same 6,416 development games.

library(rjags)
library(coda)
set.seed(610604)

base <- "P5_external_SD"
in_file <- file.path(base, "P5_SD_matched.csv")
fit_dir <- file.path(base, "Model_D_calibrated")
out_dir <- file.path(base, "SD_sensitivity")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(in_file),
          file.exists(file.path(fit_dir, "parameter_draws.rds")))

dat <- read.csv(in_file, stringsAsFactors = FALSE)
required <- c("id", "name", "average_2022", "n_2022", "sd_hist")
stopifnot(all(required %in% names(dat)), nrow(dat) == 6416L,
          !anyDuplicated(dat$id),
          all(is.finite(dat$average_2022)),
          all(is.finite(dat$n_2022) & dat$n_2022 >= 30),
          all(is.finite(dat$sd_hist) & dat$sd_hist > 0))

original <- readRDS(file.path(fit_dir, "parameter_draws.rds"))
stopifnot(all(c("draws", "x_center") %in% names(original)))
center <- original$x_center
x <- log(dat$n_2022) - center
n <- dat$n_2022
y <- dat$average_2022
vars <- c("alpha", "gamma", "a_tau", "b_tau")
stopifnot(all(vars %in% colnames(original$draws)))

model_string <- '
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
'

get_draws <- function(factor) {
  if (abs(factor - 1) < 1e-9) {
    message("SD factor 1.0: reusing existing baseline posterior draws")
    return(as.matrix(original$draws))
  }
  message("Fitting external-SD factor ", factor, " (no raw data download)")
  d <- list(N = length(y), y = y, x = x,
            v_obs = (factor * dat$sd_hist)^2 / n)
  k <- if (factor < 1) 100L else 200L
  init <- lapply(1:4, function(chain) {
    list(.RNG.name = "base::Mersenne-Twister",
         .RNG.seed = as.integer(20261122 + k + chain))
  })
  jm <- jags.model(textConnection(model_string), data = d,
                   inits = init, n.chains = 4, n.adapt = 1000, quiet = TRUE)
  update(jm, 3000, progress.bar = "none")
  smp <- coda.samples(jm, variable.names = vars,
                      n.iter = 3000, progress.bar = "none")
  rhat <- gelman.diag(smp, multivariate = FALSE)$psrf[, "Point est."]
  ess <- effectiveSize(smp)
  label <- if (factor < 1) "sd_080" else "sd_120"
  write.csv(data.frame(parameter = names(rhat),
                       rhat = as.numeric(rhat), ess = as.numeric(ess[names(rhat)])),
            file.path(out_dir, paste0(label, "_convergence.csv")),
            row.names = FALSE)
  saveRDS(as.matrix(smp), file.path(out_dir, paste0(label, "_parameter_draws.rds")))
  as.matrix(smp)
}

calc_posterior_ratings <- function(draws, factor) {
  stopifnot(all(vars %in% colnames(draws)))
  # Monte Carlo integration of conditional posterior mean E[theta_i | y, params]
  # No per-game random theta simulation: avoids noise when comparing scenarios.
  set.seed(610604)
  ids <- sample.int(nrow(draws), min(1000L, nrow(draws)))
  v_obs <- (factor * dat$sd_hist)^2 / n
  accum_theta <- numeric(length(y))
  accum_weight <- numeric(length(y))
  accum_m <- numeric(length(y))
  for (j in ids) {
    d <- draws[j, ]
    mu <- unname(d["alpha"] + d["gamma"] * x)
    tau2 <- unname(exp(2 * (d["a_tau"] + d["b_tau"] * x)))
    weight <- tau2 / (tau2 + v_obs)
    accum_theta <- accum_theta + mu + weight * (y - mu)
    accum_weight <- accum_weight + weight
    accum_m <- accum_m + ((factor * dat$sd_hist)^2 / tau2)
  }
  B <- length(ids)
  data.frame(id = dat$id, name = dat$name, n_2022 = n,
             raw_average = y, sd_hist = dat$sd_hist,
             factor = factor,
             posterior_mean = accum_theta / B,
             shrinkage_weight = accum_weight / B,
             effective_pseudo_votes = accum_m / B,
             stringsAsFactors = FALSE)
}

scenarios <- c(0.8, 1.0, 1.2)
res <- lapply(scenarios, function(f) calc_posterior_ratings(get_draws(f), f))
full <- do.call(rbind, res)
full$adjustment <- full$posterior_mean - full$raw_average
full$abs_adjustment <- abs(full$adjustment)
write.csv(full, file.path(out_dir, "SD_sensitivity_per_game.csv"), row.names = FALSE)

summary_rows <- lapply(scenarios, function(f) {
  d <- full[full$factor == f, ]
  data.frame(sd_factor = f, games = nrow(d),
             median_abs_adjustment = median(d$abs_adjustment),
             p90_abs_adjustment = unname(quantile(d$abs_adjustment, .9)),
             count_abs_adjust_gt_0_05 = sum(d$abs_adjustment > .05),
             count_abs_adjust_gt_0_10 = sum(d$abs_adjustment > .1),
             median_shrinkage_weight = median(d$shrinkage_weight),
             median_effective_pseudo_votes = median(d$effective_pseudo_votes))
})
summary <- do.call(rbind, summary_rows)
write.csv(summary, file.path(out_dir, "SD_sensitivity_summary.csv"), row.names = FALSE)

baseline <- full[full$factor == 1, c("id", "posterior_mean")]
names(baseline)[2] <- "base_posterior_mean"
comp <- merge(full, baseline, by = "id", sort = FALSE)
comp$change_from_baseline <- comp$posterior_mean - comp$base_posterior_mean
change <- do.call(rbind, lapply(scenarios, function(f) {
  d <- comp[comp$factor == f, ]
  data.frame(sd_factor = f,
             median_abs_change_from_baseline = median(abs(d$change_from_baseline)),
             p95_abs_change_from_baseline = unname(quantile(abs(d$change_from_baseline), .95)),
             max_abs_change_from_baseline = max(abs(d$change_from_baseline)))
}))
write.csv(change, file.path(out_dir, "SD_sensitivity_change_from_baseline.csv"),
          row.names = FALSE)

cat("\nSD sensitivity: summary\n")
print(summary, row.names = FALSE, digits = 4)
cat("\nChange in posterior mean relative to 1.0x historical SD\n")
print(change, row.names = FALSE, digits = 4)
cat("\nDone. Please share:\n  ",
    file.path(out_dir, "SD_sensitivity_summary.csv"), "\n  ",
    file.path(out_dir, "SD_sensitivity_change_from_baseline.csv"), "\n")
cat("For refitted runs, please also check sd_080_convergence.csv and sd_120_convergence.csv.\n")
cat("WARNING: these scenarios measure sensitivity to assumed historical SD,\n",
    "not verified same-snapshot within-game rating variability.\n", sep = "")