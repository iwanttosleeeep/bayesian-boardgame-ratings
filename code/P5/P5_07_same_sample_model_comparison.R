# STAT6106 / P5 — Stage 7: Same-sample OLD Model D vs Calibrated Model D
# =====================================================================
# DOES NOT DOWNLOAD ANY DATA. DOES NOT REFIT THE CALIBRATED MODEL.
# It fits OLD Model D once on the exact 6,416 matched development games,
# then evaluates BOTH models on the same 3,209 historical-SD-matched
# comparison games. This is an exploratory held-out comparison because
# the comparison split was already consulted during earlier model selection.
#
# Old D: y_i ~ N(alpha + gamma*x_i, tau_i^2 + s^2/n_i)
#        s ~ Uniform(0.5, 4.5)     [the earlier D_wide prior]
# New D: y_i ~ N(alpha + gamma*x_i, tau_i^2 + sd_hist_i^2/n_i)
# Both:  log(tau_i) = a_tau + b_tau*x_i,
#        x_i = log(n_i) - mean(log(n_train))
# Both use identical Normal priors for alpha, gamma, a_tau, b_tau.
#
# Prerequisites (created by earlier scripts):
# P5_external_SD/P5_SD_matched.csv
# P5_external_SD/Model_D_calibrated/parameter_draws.rds
# P5_external_SD/Model_D_calibrated/posterior_ratings_development.csv
# P5_external_SD/Model_D_calibrated/convergence.csv
# P5_external_SD/holdout_validation/holdout_game_predictions.csv
#
# Outputs in P5_external_SD/same_sample_comparison/
# =====================================================================

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
})

base_dir <- "P5_external_SD"
train_path <- file.path(base_dir, "P5_SD_matched.csv")
new_dir <- file.path(base_dir, "Model_D_calibrated")
new_fit_path <- file.path(new_dir, "parameter_draws.rds")
new_ratings_path <- file.path(new_dir, "posterior_ratings_development.csv")
new_conv_path <- file.path(new_dir, "convergence.csv")
held_path <- file.path(base_dir, "holdout_validation", "holdout_game_predictions.csv")
out_dir <- file.path(base_dir, "same_sample_comparison")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for (p in c(train_path, new_fit_path, new_ratings_path, new_conv_path, held_path)) {
  if (!file.exists(p)) stop("Missing saved input: ", p, "\nRun from the same RStudio working directory as scripts 01–05.")
}

train <- read.csv(train_path, stringsAsFactors = FALSE)
held <- read.csv(held_path, stringsAsFactors = FALSE)
new_fit <- readRDS(new_fit_path)
new_ratings <- read.csv(new_ratings_path, stringsAsFactors = FALSE)

stopifnot(
  nrow(train) == 6416L, nrow(held) == 3209L,
  all(c("id", "average_2022", "n_2022", "sd_hist") %in% names(train)),
  all(c("id", "n", "observed_average", "sd_hist") %in% names(held)),
  all(c("draws", "x_center", "model") %in% names(new_fit)),
  !anyDuplicated(train$id), !anyDuplicated(held$id),
  length(intersect(as.character(train$id), as.character(held$id))) == 0L,
  all(is.finite(train$average_2022)), all(train$n_2022 >= 30),
  all(is.finite(train$sd_hist) & train$sd_hist > 0),
  all(is.finite(held$observed_average)), all(held$n >= 30),
  all(is.finite(held$sd_hist) & held$sd_hist > 0),
  identical(as.character(train$id), as.character(new_ratings$id)),
  isTRUE(all.equal(as.numeric(new_fit$x_center),
                   mean(log(train$n_2022)), tolerance = 1e-9))
)

expected_new <- c(
  "alpha ~ dnorm(6.4, 1)", "gamma ~ dnorm(0, 1)",
  "a_tau ~ dnorm(log(0.85), 4)", "b_tau ~ dnorm(0, 16)",
  "v_obs[i]"
)
for (s in expected_new) {
  if (!grepl(s, new_fit$model, fixed = TRUE)) {
    stop("Saved new-model specification differs from this comparison's assumptions: ", s)
  }
}

pars <- c("alpha", "gamma", "a_tau", "b_tau")
new_draws <- as.matrix(new_fit$draws)
stopifnot(all(pars %in% colnames(new_draws)), nrow(new_draws) >= 1200L)

center_x <- as.numeric(new_fit$x_center)
x_train <- log(train$n_2022) - center_x
x_held  <- log(held$n) - center_x # TRAIN center, never recomputed on holdout
Ntrain <- nrow(train)
train_md5 <- unname(tools::md5sum(train_path))

cat("\nMatched training games (both models):", Ntrain, "\n")
cat("Matched held-out games (both models):", nrow(held), "\n")

# ---------------------------------------------------------------------
# 1. Fit old Model D on EXACTLY the new model's training game IDs.
# ---------------------------------------------------------------------
old_model <- "
model {
  for (i in 1:N) {
    mu[i] <- alpha + gamma*x[i]
    tau2[i] <- exp(2*(a_tau + b_tau*x[i]))
    y[i] ~ dnorm(mu[i], 1/(tau2[i] + s*s/n[i]))
  }
  alpha ~ dnorm(6.4, 1)
  gamma ~ dnorm(0, 1)
  a_tau ~ dnorm(log(0.85), 4)
  b_tau ~ dnorm(0, 16)
  s ~ dunif(0.5, 4.5)
}
"

old_path <- file.path(out_dir, "old_D_same_6416_fit.rds")
if (file.exists(old_path)) {
  message("Reusing cached OLD D (no MCMC refit)")
  old_fit <- readRDS(old_path)
  stopifnot(identical(old_fit$model, old_model),
            identical(old_fit$train_md5, train_md5),
            identical(as.character(old_fit$train_ids), as.character(train$id)),
            isTRUE(all.equal(old_fit$x_center, center_x, tolerance = 1e-9)))
} else {
  message("Fitting OLD D on the SAME 6,416 matched games; calibrated D is reused")
  inits <- lapply(1:4, function(k) {
    list(.RNG.name = "base::Mersenne-Twister",
         .RNG.seed = as.integer(20261130L + k))
  })
  old_jags <- jags.model(
    textConnection(old_model),
    data = list(N = Ntrain, y = train$average_2022,
                n = train$n_2022, x = x_train),
    inits = inits, n.chains = 4, n.adapt = 1000, quiet = TRUE
  )
  update(old_jags, n.iter = 3000, progress.bar = "none")
  old_samples <- coda.samples(
    old_jags, variable.names = c(pars, "s"),
    n.iter = 3000, progress.bar = "none"
  )
  old_rhat <- gelman.diag(old_samples, multivariate = FALSE)$psrf[, "Point est."]
  old_ess <- effectiveSize(old_samples)
  old_convergence <- data.frame(
    model = "old_D_common_s", parameter = c(pars, "s"),
    rhat = unname(old_rhat[c(pars, "s")]),
    ess = unname(old_ess[c(pars, "s")])
  )
  old_fit <- list(
    model = old_model, draws = as.matrix(old_samples),
    diagnostics = old_convergence, train_ids = train$id,
    train_md5 = train_md5, x_center = center_x
  )
  saveRDS(old_fit, old_path) # Save immediately so next run doesn't refit.
  message("Old D fit saved: ", old_path)
}
old_draws <- as.matrix(old_fit$draws)
stopifnot(all(c(pars, "s") %in% colnames(old_draws)))

new_conv <- read.csv(new_conv_path, stringsAsFactors = FALSE)
stopifnot(all(c("parameter", "rhat", "ess") %in% names(new_conv)))
new_conv$model <- "new_D_external_SD"
old_conv <- old_fit$diagnostics
conv <- rbind(
  old_conv[, c("model", "parameter", "rhat", "ess")],
  new_conv[, c("model", "parameter", "rhat", "ess")]
)
write.csv(conv, file.path(out_dir, "same_sample_convergence.csv"), row.names = FALSE)
print(conv, row.names = FALSE, digits = 4)
convergence_ok <- all(is.finite(conv$rhat) & conv$rhat < 1.01 &
                      is.finite(conv$ess) & conv$ess >= 400)
if (!convergence_ok) warning(
  "A convergence diagnostic did not meet R-hat < 1.01 / ESS >= 400; ",
  "treat model-comparison results as exploratory until resolved."
)

# ---------------------------------------------------------------------
# 2. Held-out predictive scores / intervals, SAME game IDs and target.
#    Higher summed held-out log predictive density (ELPD) is better.
#    This is NOT WAIC; it is out-of-sample posterior predictive scoring.
# ---------------------------------------------------------------------
B <- 1200L
choose_draws <- function(z) {
  ix <- unique(as.integer(round(seq(1, nrow(z), length.out = B))))
  if (length(ix) != B) stop("Not enough unique posterior draws")
  z[ix, , drop = FALSE]
}

calc_predictions <- function(z, kind, seed) {
  z <- choose_draws(z)
  n_games <- nrow(held)
  x <- x_held
  n <- held$n
  v_external <- held$sd_hist^2 / n
  y <- held$observed_average
  sim <- matrix(NA_real_, nrow = n_games, ncol = B)
  loglik <- matrix(NA_real_, nrow = n_games, ncol = B)
  set.seed(seed)
  for (b in seq_len(B)) {
    d <- z[b, ]
    mu <- unname(d["alpha"] + d["gamma"] * x)
    tau2 <- unname(exp(2 * (d["a_tau"] + d["b_tau"] * x)))
    v <- if (kind == "old") unname(d["s"]^2 / n) else v_external
    sdy <- sqrt(tau2 + v)
    loglik[, b] <- dnorm(y, mean = mu, sd = sdy, log = TRUE)
    sim[, b] <- rnorm(n_games, mean = mu, sd = sdy)
  }
  logmeanexp <- function(a) {
    m <- max(a)
    m + log(mean(exp(a - m)))
  }
  per_game <- data.frame(
    id = held$id,
    y = y,
    n = n,
    lpd = apply(loglik, 1, logmeanexp),
    pred_median = apply(sim, 1, median),
    lower = apply(sim, 1, quantile, probs = 0.025),
    upper = apply(sim, 1, quantile, probs = 0.975)
  )
  per_game$covered95 <- with(per_game, y >= lower & y <= upper)
  list(sim = sim, per_game = per_game)
}

cat("\nScoring OLD D on the SAME 3,209 holdout games...\n")
old_pred <- calc_predictions(old_draws, "old", 610607)
cat("Scoring NEW D on the SAME 3,209 holdout games...\n")
new_pred <- calc_predictions(new_draws, "new", 610608)
stopifnot(identical(as.character(old_pred$per_game$id),
                    as.character(new_pred$per_game$id)))

game_scores <- data.frame(
  id = held$id, n = held$n,
  observed_average = held$observed_average,
  lpd_old = old_pred$per_game$lpd,
  lpd_new = new_pred$per_game$lpd,
  delta_lpd_new_minus_old = new_pred$per_game$lpd - old_pred$per_game$lpd,
  covered_95_old = old_pred$per_game$covered95,
  covered_95_new = new_pred$per_game$covered95
)
write.csv(game_scores, file.path(out_dir, "same_sample_per_game_scores.csv"), row.names = FALSE)

Nhold <- nrow(held)
difference <- game_scores$delta_lpd_new_minus_old
paired_se <- sqrt(Nhold * var(difference)) # Approximate; not designer-cluster adjusted.
metrics <- data.frame(
  metric = c("matched_training_games_each", "matched_heldout_games_each",
             "old_s_prior_lower", "old_s_prior_upper",
             "old_s_posterior_mean", "old_s_posterior_2_5pct", "old_s_posterior_97_5pct",
             "old_heldout_ELPD", "new_heldout_ELPD",
             "delta_ELPD_new_minus_old", "approx_paired_SE_delta_ELPD",
             "old_mean_log_predictive_density", "new_mean_log_predictive_density",
             "old_95pct_predictive_coverage", "new_95pct_predictive_coverage",
             "all_Rhat_below_1_01_and_ESS_at_least_400"),
  value = c(Ntrain, Nhold, 0.5, 4.5,
            mean(old_draws[, "s"]),
            unname(quantile(old_draws[, "s"], 0.025)),
            unname(quantile(old_draws[, "s"], 0.975)),
            sum(old_pred$per_game$lpd), sum(new_pred$per_game$lpd),
            sum(difference), paired_se,
            mean(old_pred$per_game$lpd), mean(new_pred$per_game$lpd),
            mean(old_pred$per_game$covered95), mean(new_pred$per_game$covered95),
            as.numeric(convergence_ok))
)
write.csv(metrics, file.path(out_dir, "same_sample_model_comparison_summary.csv"), row.names = FALSE)
print(metrics, row.names = FALSE, digits = 6)

# Grouped mean and variance posterior predictive checks. Groups/observations
# are identical for both models; note groups cover only four selected bands.
q <- function(v, p) as.numeric(quantile(v, p, na.rm = TRUE))
groups <- list(
  "30-40" = which(held$n >= 30 & held$n <= 40),
  "100-200" = which(held$n >= 100 & held$n <= 200),
  "1000-5000" = which(held$n >= 1000 & held$n <= 5000),
  "5000+" = which(held$n > 5000)
)
ppc_rows <- function(obj, label) {
  do.call(rbind, lapply(names(groups), function(g) {
    ix <- groups[[g]]
    if (length(ix) < 2L) stop("Not enough games in PPC group: ", g)
    sims <- obj$sim[ix, , drop = FALSE]
    rep_mean <- colMeans(sims)
    rep_var <- apply(sims, 2, var)
    obs_mean <- mean(held$observed_average[ix])
    obs_var <- var(held$observed_average[ix])
    mlo <- q(rep_mean, .025); mhi <- q(rep_mean, .975)
    vlo <- q(rep_var, .025); vhi <- q(rep_var, .975)
    data.frame(
      model = label, group = g, games = length(ix),
      observed_mean = obs_mean, pred_mean_median = median(rep_mean),
      pred_mean_low = mlo, pred_mean_high = mhi,
      mean_in_95_interval = (obs_mean >= mlo && obs_mean <= mhi),
      observed_variance = obs_var, pred_variance_median = median(rep_var),
      pred_variance_low = vlo, pred_variance_high = vhi,
      variance_in_95_interval = (obs_var >= vlo && obs_var <= vhi),
      individual_95_coverage = mean(obj$per_game$covered95[ix])
    )
  }))
}
grouped <- rbind(ppc_rows(old_pred, "old_D_common_s"),
                 ppc_rows(new_pred, "new_D_external_SD"))
write.csv(grouped, file.path(out_dir, "same_sample_grouped_PPC.csv"), row.names = FALSE)
print(grouped, row.names = FALSE, digits = 4)

# ---------------------------------------------------------------------
# 3. Shrinkage comparison on exactly the SAME 6,416 development games.
#    Integrate out theta analytically: no random latent-theta noise.
# ---------------------------------------------------------------------
train_ratings <- function(z, kind) {
  z <- choose_draws(z)
  y <- train$average_2022
  n <- train$n_2022
  v_external <- train$sd_hist^2 / n
  out <- numeric(Ntrain)
  weights <- numeric(Ntrain)
  for (b in seq_len(B)) {
    d <- z[b, ]
    mu <- unname(d["alpha"] + d["gamma"] * x_train)
    tau2 <- unname(exp(2 * (d["a_tau"] + d["b_tau"] * x_train)))
    v <- if (kind == "old") unname(d["s"]^2 / n) else v_external
    w <- tau2 / (tau2 + v)
    out <- out + mu + w * (y - mu)
    weights <- weights + w
  }
  list(rating = out / B, weight = weights / B)
}
old_rating <- train_ratings(old_draws, "old")
new_rating <- train_ratings(new_draws, "new")
train_diff <- new_rating$rating - old_rating$rating
train_comparison <- data.frame(
  id = train$id, n = train$n_2022, raw_average = train$average_2022,
  posterior_old = old_rating$rating, posterior_new = new_rating$rating,
  new_minus_old = train_diff,
  weight_old = old_rating$weight, weight_new = new_rating$weight
)
write.csv(train_comparison, file.path(out_dir, "same_sample_shrinkage_per_game.csv"),
          row.names = FALSE)
old_top50 <- train$id[order(-old_rating$rating)[1:50]]
new_top50 <- train$id[order(-new_rating$rating)[1:50]]
shrinkage_summary <- data.frame(
  metric = c("train_games", "old_median_abs_adjustment",
             "new_median_abs_adjustment", "median_abs_new_minus_old",
             "p95_abs_new_minus_old", "max_abs_new_minus_old",
             "old_median_shrinkage_weight", "new_median_shrinkage_weight",
             "development_top50_overlap"),
  value = c(Ntrain,
            median(abs(old_rating$rating - train$average_2022)),
            median(abs(new_rating$rating - train$average_2022)),
            median(abs(train_diff)), q(abs(train_diff), .95), max(abs(train_diff)),
            median(old_rating$weight), median(new_rating$weight),
            length(intersect(old_top50, new_top50)))
)
write.csv(shrinkage_summary, file.path(out_dir, "same_sample_shrinkage_summary.csv"),
          row.names = FALSE)
print(shrinkage_summary, row.names = FALSE, digits = 5)

writeLines(c(
  "Model comparison: Old Normal D (shared s~U(0.5,4.5)) vs new D (historical game-specific SD).",
  "Both fit to exactly 6416 matched development IDs and scored on the same 3209 holdout IDs.",
  "Old D was refitted once for comparability; new D was not refitted.",
  "ELPD = sum over heldout games of log posterior predictive density; higher is better.",
  "ELPD paired SE is approximate and not designer-cluster adjusted.",
  "The holdout was examined in earlier model exploration: it is NOT a pristine final test.",
  "Historical SD snapshot date unverified; each SD is used as a fixed plug-in estimate.",
  "The four rating-count PPC groups do not cover every heldout game.",
  "Development Top50 is among 6416 selected games, NOT a global BGG ranking.",
  "This is NOT the eventual cross-teammate M0/M1a/M1b WAIC comparison."
), file.path(out_dir, "README_comparison_limits.txt"))

cat("\nSUCCESS — same-sample Old D vs New D comparison completed.\n")
cat("Outputs: ", normalizePath(out_dir), "\n", sep = "")
cat("Send these 4 files: same_sample_model_comparison_summary.csv, ",
    "same_sample_grouped_PPC.csv, same_sample_shrinkage_summary.csv, ",
    "same_sample_convergence.csv\n", sep = "")