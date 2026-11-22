# STAT6106 P5 — M1a Baseline vs M1a-Extended (External SD)
# Fair comparison: SAME 6,416 development game IDs, SAME 3,209 holdout game IDs.
# Uses saved posterior draws only: NO JAGS refit, NO downloads, NO changes to prior outputs.
# Run from the same R working directory as 02_M1a_Baseline.R and 03_M1a_Extended_ExternalSD.R.

base <- "P5_external_SD"
train_path <- file.path(base, "P5_SD_matched.csv")
a_path <- file.path(base, "Model_A_same_6416", "parameter_draws.rds")
d_path <- file.path(base, "Model_D_calibrated", "parameter_draws.rds")
held_path <- file.path(base, "holdout_validation", "holdout_game_predictions.csv")
a_conv_path <- file.path(base, "Model_A_same_6416", "convergence.csv")
d_conv_path <- file.path(base, "Model_D_calibrated", "convergence.csv")
out_dir <- file.path(base, "M1a_A_vs_ExternalSD_Comparison")

inputs <- c(train_path, a_path, d_path, held_path, a_conv_path, d_conv_path)
missing <- inputs[!file.exists(inputs)]
if (length(missing)) stop("Missing saved inputs (check your RStudio working directory):\n",
                          paste(missing, collapse = "\n"))

train <- read.csv(train_path, stringsAsFactors = FALSE)
held <- read.csv(held_path, stringsAsFactors = FALSE)
a_fit <- readRDS(a_path)
d_fit <- readRDS(d_path)

a_need <- c("draws", "ids", "input_md5", "model")
d_need <- c("draws", "x_center", "model")
if (!all(a_need %in% names(a_fit)) || !all(d_need %in% names(d_fit))) {
  stop("Unexpected saved RDS structure. Use the genuine 02_M1a_Baseline.R/03_M1a_Extended_ExternalSD.R output files.")
}
if (!all(c("id", "average_2022", "n_2022", "sd_hist") %in% names(train)) ||
    !all(c("id", "observed_average", "n", "sd_hist") %in% names(held))) {
  stop("Required training or holdout columns are missing.")
}
stopifnot(
  nrow(train) == 6416L, nrow(held) == 3209L,
  !anyDuplicated(train$id), !anyDuplicated(held$id),
  length(intersect(as.character(train$id), as.character(held$id))) == 0L,
  identical(as.character(a_fit$ids), as.character(train$id)),
  identical(unname(a_fit$input_md5), unname(tools::md5sum(train_path))),
  isTRUE(all.equal(as.numeric(d_fit$x_center), mean(log(train$n_2022)),
                   tolerance = 1e-9)),
  all(is.finite(train$average_2022)), all(train$n_2022 >= 30),
  all(is.finite(train$sd_hist) & train$sd_hist > 0),
  all(is.finite(held$observed_average)), all(held$n >= 30),
  all(is.finite(held$sd_hist) & held$sd_hist > 0)
)

# Ensure Model A really is the ORIGINAL intercept-only M1a, not old Model D.
for (term in c("s ~ dunif(0.5, 3)", "tau ~ dt(0, 1, 1) T(0,)",
               "y[i] ~ dnorm(alpha, prec[i])")) {
  if (!grepl(term, a_fit$model, fixed = TRUE))
    stop("Saved Model A specification does not match the original baseline: ", term)
}
for (term in c("gamma ~ dnorm(0, 1)", "a_tau ~ dnorm(log(0.85), 4)",
               "b_tau ~ dnorm(0, 16)", "v_obs[i]")) {
  if (!grepl(term, d_fit$model, fixed = TRUE))
    stop("Saved external-SD model does not match the recorded extended model: ", term)
}

za <- as.matrix(a_fit$draws)
zd <- as.matrix(d_fit$draws)
stopifnot(all(c("alpha", "s", "tau") %in% colnames(za)),
          all(c("alpha", "gamma", "a_tau", "b_tau") %in% colnames(zd)))

B <- 1000L  # Posterior draws per model, reused for predictive and rating comparisons.
if (nrow(za) < B || nrow(zd) < B) stop("Insufficient saved posterior draws")
select_draws <- function(z) {
  ix <- unique(as.integer(round(seq(1, nrow(z), length.out = B))))
  if (length(ix) != B) stop("Could not select B distinct draws")
  z[ix, , drop = FALSE]
}
za <- select_draws(za)
zd <- select_draws(zd)

# Common predictive distribution integrates over each game's latent theta.
# For Model A, mean_i=alpha and var_i=tau^2+s^2/n_i.
# For External SD, mean_i=alpha+gamma*x_i and
# var_i=exp(2*(a_tau+b_tau*x_i))+sd_hist_i^2/n_i.
get_mu_sd <- function(draw, model, n, sd_hist = NULL) {
  if (model == "A") {
    mu <- rep(unname(draw["alpha"]), length(n))
    tau2 <- rep(unname(draw["tau"]^2), length(n))
    v <- unname(draw["s"]^2 / n)
  } else {
    x <- log(n) - as.numeric(d_fit$x_center)  # ALWAYS the development center
    mu <- unname(draw["alpha"] + draw["gamma"] * x)
    tau2 <- unname(exp(2 * (draw["a_tau"] + draw["b_tau"] * x)))
    v <- sd_hist^2 / n
  }
  list(mu = mu, tau2 = tau2, v = v, sd_y = sqrt(tau2 + v))
}

log_mean_exp <- function(v) {
  mx <- max(v)
  mx + log(mean(exp(v - mx)))
}

predict_holdout <- function(z, model, seed) {
  N <- nrow(held)
  loglik <- matrix(NA_real_, nrow = N, ncol = B)
  simulated <- matrix(NA_real_, nrow = N, ncol = B)
  set.seed(seed)
  for (b in seq_len(B)) {
    p <- get_mu_sd(z[b, ], model, held$n, held$sd_hist)
    loglik[, b] <- dnorm(held$observed_average, p$mu, p$sd_y, log = TRUE)
    simulated[, b] <- rnorm(N, p$mu, p$sd_y)
  }
  lpd <- apply(loglik, 1, log_mean_exp)
  lower <- apply(simulated, 1, quantile, probs = 0.025, names = FALSE)
  upper <- apply(simulated, 1, quantile, probs = 0.975, names = FALSE)
  list(sim = simulated, lpd = lpd, lower = lower, upper = upper,
       covered = held$observed_average >= lower & held$observed_average <= upper)
}

cat("Training games for BOTH models:", nrow(train), "\n")
cat("Holdout games for BOTH models:", nrow(held), "\n")
cat("Calculating baseline (A) holdout predictions...\n")
pa <- predict_holdout(za, "A", 61060901)
cat("Calculating External-SD holdout predictions...\n")
pd <- predict_holdout(zd, "D", 61060902)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
per_game <- data.frame(
  id = held$id, n = held$n, observed_average = held$observed_average,
  log_density_Baseline = pa$lpd, log_density_Extended = pd$lpd,
  difference_Extended_minus_Baseline = pd$lpd - pa$lpd,
  covered95_Baseline = pa$covered, covered95_Extended = pd$covered
)
write.csv(per_game, file.path(out_dir, "comparison_holdout_per_game.csv"),
          row.names = FALSE)

diff <- pd$lpd - pa$lpd
convergence <- rbind(
  transform(read.csv(a_conv_path), model = "M1a_Baseline"),
  transform(read.csv(d_conv_path), model = "M1a_Extended_ExternalSD")
)
convergence <- convergence[, c("model", "parameter", "rhat", "ess")]
stopifnot(all(is.finite(convergence$rhat)), all(is.finite(convergence$ess)))
write.csv(convergence, file.path(out_dir, "comparison_convergence.csv"),
          row.names = FALSE)

metrics <- data.frame(
  metric = c("training_games_each", "holdout_games_each", "draws_per_model",
             "Baseline_holdout_ELPD", "Extended_holdout_ELPD", "ELPD_Extended_minus_Baseline",
             "approx_paired_SE_ELPD_difference",
             "Baseline_mean_log_predictive_density", "Extended_mean_log_predictive_density",
             "Baseline_individual_95pct_predictive_coverage",
             "Extended_individual_95pct_predictive_coverage",
             "all_rhat_below_1_01_and_ESS_at_least_400"),
  value = c(nrow(train), nrow(held), B,
            sum(pa$lpd), sum(pd$lpd), sum(diff),
            sqrt(nrow(held) * var(diff)),  # Approx, no designer clustering.
            mean(pa$lpd), mean(pd$lpd),
            mean(pa$covered), mean(pd$covered),
            as.numeric(all(convergence$rhat < 1.01 & convergence$ess >= 400)))
)
write.csv(metrics, file.path(out_dir, "comparison_holdout_summary.csv"),
          row.names = FALSE)
print(metrics, row.names = FALSE, digits = 6)

# Four identical grouped held-out PPCs. These bands don't include all games.
groups <- list(
  "30-40" = which(held$n >= 30 & held$n <= 40),
  "100-200" = which(held$n >= 100 & held$n <= 200),
  "1000-5000" = which(held$n >= 1000 & held$n <= 5000),
  "5000+" = which(held$n > 5000)
)
stopifnot(all(lengths(groups) >= 2L))
qq <- function(v, p) unname(quantile(v, probs = p))
grouped_PPC <- function(obj, label) {
  do.call(rbind, lapply(names(groups), function(g) {
    ix <- groups[[g]]
    replicated_means <- colMeans(obj$sim[ix, , drop = FALSE])
    replicated_vars <- apply(obj$sim[ix, , drop = FALSE], 2, var)
    observed_mean <- mean(held$observed_average[ix])
    observed_var <- var(held$observed_average[ix])
    ml <- qq(replicated_means, .025); mh <- qq(replicated_means, .975)
    vl <- qq(replicated_vars, .025); vh <- qq(replicated_vars, .975)
    data.frame(
      model = label, group = g, games = length(ix),
      observed_mean = observed_mean,
      pred_mean_median = median(replicated_means),
      pred_mean_low = ml, pred_mean_high = mh,
      mean_in_95_interval = (observed_mean >= ml && observed_mean <= mh),
      observed_variance = observed_var,
      pred_variance_median = median(replicated_vars),
      pred_variance_low = vl, pred_variance_high = vh,
      variance_in_95_interval = (observed_var >= vl && observed_var <= vh),
      individual_95_coverage = mean(obj$covered[ix])
    )
  }))
}
ppc <- rbind(grouped_PPC(pa, "M1a_Baseline"),
             grouped_PPC(pd, "M1a_Extended_ExternalSD"))
write.csv(ppc, file.path(out_dir, "comparison_holdout_grouped_PPC.csv"),
          row.names = FALSE)
print(ppc, row.names = FALSE, digits = 4)

# Posterior E[theta_i | observed y_i], integrated over saved parameter draws.
# This is analytic Rao-Blackwellization: avoids extra Monte Carlo latent noise.
train_rating <- function(z, model) {
  rating <- numeric(nrow(train))
  weight <- numeric(nrow(train))
  for (b in seq_len(B)) {
    p <- get_mu_sd(z[b, ], model, train$n_2022, train$sd_hist)
    w <- p$tau2 / (p$tau2 + p$v)
    rating <- rating + p$mu + w * (train$average_2022 - p$mu)
    weight <- weight + w
  }
  list(mean = rating / B, weight = weight / B)
}
ra <- train_rating(za, "A")
rd <- train_rating(zd, "D")
comparison <- data.frame(
  id = train$id, name = train$name, n = train$n_2022,
  raw_average = train$average_2022,
  posterior_Baseline = ra$mean, posterior_Extended = rd$mean,
  Extended_minus_Baseline = rd$mean - ra$mean,
  shrinkage_weight_Baseline = ra$weight, shrinkage_weight_Extended = rd$weight
)
write.csv(comparison, file.path(out_dir, "comparison_ratings_per_game.csv"),
          row.names = FALSE)

top50_a <- train$id[order(-ra$mean, train$id)[1:50]]
top50_d <- train$id[order(-rd$mean, train$id)[1:50]]
shrinkage <- data.frame(
  metric = c("development_games_each", "Baseline_median_abs_adjustment",
             "Extended_median_abs_adjustment", "median_abs_rating_difference",
             "p95_abs_rating_difference", "max_abs_rating_difference",
             "Baseline_median_shrinkage_weight", "Extended_median_shrinkage_weight",
             "development_top50_overlap"),
  value = c(nrow(train),
            median(abs(ra$mean - train$average_2022)),
            median(abs(rd$mean - train$average_2022)),
            median(abs(rd$mean - ra$mean)),
            qq(abs(rd$mean - ra$mean), .95),
            max(abs(rd$mean - ra$mean)),
            median(ra$weight), median(rd$weight),
            length(intersect(top50_a, top50_d)))
)
write.csv(shrinkage, file.path(out_dir, "comparison_shrinkage_summary.csv"),
          row.names = FALSE)
print(shrinkage, row.names = FALSE, digits = 5)

writeLines(c(
  "M1a Baseline (original Model A) vs M1a-Extended (External-SD Model D).",
  "Both fitted to identical 6,416 development game IDs; both evaluated on",
  "the identical 3,209 historically SD-matched holdout IDs.",
  "No JAGS refitting and no resampling of games was performed by this script.",
  "Scores are holdout ELPD (higher is better), NOT WAIC.",
  "The difference standard error assumes independent games; designer clustering",
  "and earlier exploration of this holdout limit confirmatory interpretation.",
  "Both mean/dispersion and observation-noise specifications change between models.",
  "Thus any improvement cannot be attributed to external SD ALONE.",
  "External SD snapshot timing and plug-in uncertainty are not fully resolved.",
  "Top50 overlap is within 6,416 selected games, NOT the global BGG Top50."
), file.path(out_dir, "README_comparison_limits.txt"))
cat("\nSUCCESS: M1a Baseline vs M1a-Extended comparison done.\n")
cat("Results saved to: ", normalizePath(out_dir), "\n", sep = "")
cat("Please send these FOUR small CSV files for review:\n")
cat("  comparison_holdout_summary.csv\n")
cat("  comparison_holdout_grouped_PPC.csv\n")
cat("  comparison_shrinkage_summary.csv\n")
cat("  comparison_convergence.csv\n")