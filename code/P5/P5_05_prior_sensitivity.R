# STAT6106 P5 — Stage 5: PRIOR SENSITIVITY of calibrated Model D
# ---------------------------------------------------------------------------
# Run AFTER P5_01_save_SD_lookup.R and P5_02_Model_D_external_SD.R.
# Does NOT download anything, rerun the baseline, or redo SD x0.8/x1.2.
# Reuses existing 6,416-game lookup and baseline MCMC draws.
# Re-fits FOUR alternatives changing priors ONLY; likelihood/data stay fixed.
# Alternative fits are saved individually and reused if you run this again.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
})

base_dir <- "P5_external_SD"
input_csv <- file.path(base_dir, "P5_SD_matched.csv")
fit_dir <- file.path(base_dir, "Model_D_calibrated")
output_dir <- file.path(base_dir, "prior_sensitivity")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

base_fit_path <- file.path(fit_dir, "parameter_draws.rds")
base_ratings_path <- file.path(fit_dir, "posterior_ratings_development.csv")
base_conv_path <- file.path(fit_dir, "convergence.csv")
for (p in c(input_csv, base_fit_path, base_ratings_path, base_conv_path)) {
  if (!file.exists(p)) stop("Required local file missing: ", p,
                            "\nRun the earlier scripts from the same working directory.")
}

dat <- read.csv(input_csv, stringsAsFactors = FALSE)
required_cols <- c("id", "average_2022", "n_2022", "sd_hist")
stopifnot(all(required_cols %in% names(dat)), nrow(dat) == 6416L,
          !anyDuplicated(dat$id),
          all(is.finite(dat$average_2022)),
          all(is.finite(dat$n_2022) & dat$n_2022 >= 30),
          all(is.finite(dat$sd_hist) & dat$sd_hist > 0))

# Guard against silently aligning parameter draws with another sample/order.
saved_ratings <- read.csv(base_ratings_path, stringsAsFactors = FALSE)
stopifnot(nrow(saved_ratings) == nrow(dat),
          identical(as.character(saved_ratings$id), as.character(dat$id)))

original <- readRDS(base_fit_path)
stopifnot(all(c("draws", "x_center", "model") %in% names(original)))
pars <- c("alpha", "gamma", "a_tau", "b_tau")
stopifnot(all(pars %in% colnames(original$draws)),
          nrow(original$draws) >= 1200L,
          isTRUE(all.equal(unname(original$x_center),
                           mean(log(dat$n_2022)), tolerance = 1e-9)))

# Check that the saved baseline is the expected calibrated Model D.
expected_prior_lines <- c("alpha ~ dnorm(6.4, 1)",
                          "gamma ~ dnorm(0, 1)",
                          "a_tau ~ dnorm(log(0.85), 4)",
                          "b_tau ~ dnorm(0, 16)")
for (line in expected_prior_lines) {
  if (!grepl(line, original$model, fixed = TRUE)) {
    stop("Saved baseline model does not contain expected prior: ", line)
  }
}

n <- dat$n_2022
y <- dat$average_2022
x <- log(n) - original$x_center
v_obs <- dat$sd_hist^2 / n # FIXED throughout these prior experiments
N <- length(y)

# JAGS dnorm(mean, PRECISION); precision is 1 / prior SD^2.
# Only the 3 precision columns vary. alpha is held at N(6.4,1^2).
scenarios <- data.frame(
  scenario = c("baseline", "tau_tighter", "tau_wider",
               "gamma_tighter", "gamma_wider"),
  gamma_prior_sd = c(1, 1, 1, 0.5, 2),
  a_tau_prior_sd = c(0.5, 0.25, 1, 0.5, 0.5),
  b_tau_prior_sd = c(0.25, 0.125, 0.5, 0.25, 0.25),
  stringsAsFactors = FALSE
)
write.csv(scenarios, file.path(output_dir, "prior_sensitivity_setup.csv"),
          row.names = FALSE)

make_model <- function(pr) {
  sprintf('model {
    for (i in 1:N) {
      mu[i] <- alpha + gamma*x[i]
      tau2[i] <- exp(2*(a_tau + b_tau*x[i]))
      y[i] ~ dnorm(mu[i], 1/(tau2[i] + v_obs[i]))
    }
    alpha ~ dnorm(6.4, 1)
    gamma ~ dnorm(0, %.12g)
    a_tau ~ dnorm(log(0.85), %.12g)
    b_tau ~ dnorm(0, %.12g)
  }',
    1 / pr$gamma_prior_sd^2,
    1 / pr$a_tau_prior_sd^2,
    1 / pr$b_tau_prior_sd^2)
}

# Save every alternative immediately. On reruns only missing fits are run.
get_fit <- function(pr, scenario_index) {
  label <- pr$scenario
  if (label == "baseline") {
    message("baseline: reusing Model_D_calibrated/parameter_draws.rds")
    return(as.matrix(original$draws))
  }
  cache <- file.path(output_dir, paste0(label, "_fit.rds"))
  if (file.exists(cache)) {
    message(label, ": reusing cached posterior draws and diagnostics")
    obj <- readRDS(cache)
    stopifnot(identical(obj$scenario, label),
              isTRUE(all.equal(obj$prior_sds,
                               unname(unlist(pr[1, 2:4], use.names = FALSE)))))
    return(obj$draws)
  }
  message("Fitting ", label, " (PRIOR CHANGE ONLY; no downloads)")
  set.seed(610605 + scenario_index)
  inits <- lapply(seq_len(4), function(chain) {
    list(.RNG.name = "base::Mersenne-Twister",
         .RNG.seed = as.integer(6106050 + 100 * scenario_index + chain))
  })
  model <- make_model(pr)
  jm <- jags.model(textConnection(model),
                   data = list(N = N, y = y, x = x, v_obs = v_obs),
                   inits = inits, n.chains = 4, n.adapt = 1000,
                   quiet = TRUE)
  update(jm, n.iter = 3000, progress.bar = "none")
  smp <- coda.samples(jm, variable.names = pars,
                      n.iter = 3000, progress.bar = "none")
  zz <- as.matrix(smp)
  rhat <- gelman.diag(smp, multivariate = FALSE)$psrf[, "Point est."]
  ess <- effectiveSize(smp)
  obj <- list(scenario = label,
              prior_sds = unname(unlist(pr[1, 2:4], use.names = FALSE)),
              draws = zz,
              diagnostics = data.frame(parameter = pars,
                                       rhat = unname(rhat[pars]),
                                       ess = unname(ess[pars])),
              model = model)
  saveRDS(obj, cache)
  message(label, ": finished and saved as ", cache)
  zz
}

# Integrate out each game's latent rating analytically, rather than
# drawing random theta values. This reduces Monte Carlo comparison noise.
posterior_ratings <- function(z, label) {
  stopifnot(all(pars %in% colnames(z)), nrow(z) >= 1200)
  # Deterministic, spread evenly through all chains; same 1,200 draws per fit.
  picks <- unique(as.integer(round(seq(1, nrow(z), length.out = 1200))))
  rating_total <- numeric(N)
  weight_total <- numeric(N)
  pseudo_total <- numeric(N)
  for (j in picks) {
    d <- z[j, ]
    mu <- unname(d["alpha"] + d["gamma"] * x)
    tau2 <- unname(exp(2 * (d["a_tau"] + d["b_tau"] * x)))
    weight <- tau2 / (tau2 + v_obs)
    rating_total <- rating_total + mu + weight * (y - mu)
    weight_total <- weight_total + weight
    pseudo_total <- pseudo_total + dat$sd_hist^2 / tau2
  }
  K <- length(picks)
  data.frame(id = dat$id, scenario = label, raw_average = y,
             posterior_mean = rating_total / K,
             shrinkage_weight = weight_total / K,
             effective_pseudo_votes = pseudo_total / K)
}

fits <- vector("list", nrow(scenarios))
names(fits) <- scenarios$scenario
for (i in seq_len(nrow(scenarios))) {
  fits[[i]] <- get_fit(scenarios[i, , drop = FALSE], i)
}

# Parameter posterior summary across all scenarios.
parameter_summary <- do.call(rbind, lapply(names(fits), function(label) {
  z <- fits[[label]]
  do.call(rbind, lapply(pars, function(param) {
    zz <- z[, param]
    data.frame(scenario = label, parameter = param,
               posterior_mean = mean(zz),
               posterior_low_95 = unname(quantile(zz, .025)),
               posterior_high_95 = unname(quantile(zz, .975)))
  }))
}))
write.csv(parameter_summary,
          file.path(output_dir, "prior_sensitivity_parameter_summary.csv"),
          row.names = FALSE)

# Convergence: reuse baseline's existing diagnostics, and cached new diagnostics.
base_conv <- read.csv(base_conv_path, stringsAsFactors = FALSE)
stopifnot(all(c("parameter", "rhat", "ess") %in% names(base_conv)))
base_conv$scenario <- "baseline"
all_conv <- list(base_conv[, c("scenario", "parameter", "rhat", "ess")])
for (label in scenarios$scenario[-1]) {
  dd <- readRDS(file.path(output_dir, paste0(label, "_fit.rds")))$diagnostics
  dd$scenario <- label
  all_conv[[length(all_conv) + 1]] <- dd[, c("scenario", "parameter", "rhat", "ess")]
}
all_conv <- do.call(rbind, all_conv)
write.csv(all_conv, file.path(output_dir, "prior_sensitivity_convergence.csv"),
          row.names = FALSE)

results <- do.call(rbind, lapply(names(fits), function(label) {
  posterior_ratings(fits[[label]], label)
}))
results$adjustment <- results$posterior_mean - results$raw_average
write.csv(results, file.path(output_dir, "prior_sensitivity_per_game.csv"),
          row.names = FALSE)

base_row <- results[results$scenario == "baseline", ]
stopifnot(nrow(base_row) == N, identical(as.character(base_row$id),
                                        as.character(dat$id)))
base_means <- base_row$posterior_mean
base_top50 <- dat$id[order(-base_means)][seq_len(50)]

summaries <- lapply(scenarios$scenario, function(label) {
  dd <- results[results$scenario == label, ]
  stopifnot(identical(as.character(dd$id), as.character(dat$id)))
  diff <- dd$posterior_mean - base_means
  top50 <- dat$id[order(-dd$posterior_mean)][seq_len(50)]
  data.frame(
    scenario = label,
    games = nrow(dd),
    median_abs_adjustment = median(abs(dd$adjustment)),
    games_abs_adjust_gt_0_05 = sum(abs(dd$adjustment) > 0.05),
    games_abs_adjust_gt_0_10 = sum(abs(dd$adjustment) > 0.10),
    median_shrinkage_weight = median(dd$shrinkage_weight),
    median_effective_pseudo_votes = median(dd$effective_pseudo_votes),
    median_abs_change_from_baseline = median(abs(diff)),
    p95_abs_change_from_baseline = unname(quantile(abs(diff), .95)),
    max_abs_change_from_baseline = max(abs(diff)),
    games_change_gt_0_05 = sum(abs(diff) > 0.05),
    top50_overlap_with_baseline = length(intersect(base_top50, top50)),
    stringsAsFactors = FALSE
  )
})
summary_df <- do.call(rbind, summaries)
write.csv(summary_df,
          file.path(output_dir, "prior_sensitivity_summary.csv"),
          row.names = FALSE)

cat("\n=== PRIOR SENSITIVITY SUMMARY ===\n")
print(summary_df[, c("scenario", "median_abs_adjustment",
                     "median_abs_change_from_baseline",
                     "p95_abs_change_from_baseline",
                     "top50_overlap_with_baseline")],
      row.names = FALSE, digits = 4)
cat("\n=== MCMC CHECK ===\n")
conv_summary <- do.call(rbind, lapply(split(all_conv, all_conv$scenario), function(d) {
  data.frame(scenario = d$scenario[1],
             max_rhat = max(d$rhat), min_ess = min(d$ess))
}))
print(conv_summary, row.names = FALSE, digits = 4)
cat("\nSaved in: ", normalizePath(output_dir), "\n", sep = "")
cat("Please upload just these THREE files for review:\n")
cat("  prior_sensitivity_summary.csv\n")
cat("  prior_sensitivity_parameter_summary.csv\n")
cat("  prior_sensitivity_convergence.csv\n")
cat("Other per-game outputs and fit caches can stay on your computer.\n")
cat("CAUTION: results are for the 6,416 matched DEVELOPMENT games only;\n")
cat("historical SDs are plug-in estimates from an unverified snapshot.\n")