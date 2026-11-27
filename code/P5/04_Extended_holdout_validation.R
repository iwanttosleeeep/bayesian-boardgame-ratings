# STAT6106 / P5 — M1a Extended: validate saved posterior on held-out games
# Run AFTER 01_prepare_historical_SD.R and 03_M1a_Extended_ExternalSD.R.
# Does NOT rerun JAGS and does NOT download the full raw BGG dataset.
# Only comparison_sample.csv (3,244 games) is downloaded once and cached.
# Reuses the original cached or committed historical source and saved parameter draws.
# IMPORTANT: These holdout games were used in earlier project model exploration,
# so this is a held-out-games diagnostic, NOT a pristine untouched test set.

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
repo_check_paths(c(p5_input("d_draws", required=FALSE),
  p5_historical_source(required=FALSE),
  repo_path("comparison_sample.csv")))

set.seed(610603)
base_dir <- .p5_cache
cache_dir <- file.path(base_dir, "source_cache")
model_dir <- file.path(base_dir, "Model_D_calibrated")
out_dir <- file.path(base_dir, "holdout_validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

param_path <- p5_input("d_draws", required=FALSE)
hist_path <- p5_historical_source()
compare_path <- repo_existing(c(file.path(cache_dir,"comparison_sample.csv"), repo_path("comparison_sample.csv")), "holdout CSV", required=FALSE)
stopifnot(file.exists(param_path), file.exists(hist_path))

# Cache the independent comparison sample and reject incomplete downloads.
# GitHub repository listing reports 6,612,503 bytes for this version.
expected_bytes <- 6612503
cached_bytes <- if (file.exists(compare_path)) file.info(compare_path)$size else NA_real_
if (is.na(cached_bytes) || cached_bytes != expected_bytes) {
  if (!is.na(cached_bytes)) {
    message("Removing incomplete/outdated cache (", cached_bytes, " bytes)")
    if (normalizePath(compare_path)==normalizePath(repo_path("comparison_sample.csv")))
      stop("Committed holdout size differs from the expected source; refusing to overwrite it.")
    unlink(compare_path)
  }
  options(timeout = max(600, getOption("timeout")))
  url <- paste0(
    "https://raw.githubusercontent.com/iwanttosleeeep/",
    "bayesian-boardgame-ratings/main/comparison_sample.csv"
  )
  temp_path <- paste0(compare_path, ".part")
  complete <- FALSE
  for (attempt in seq_len(3)) {
    if (file.exists(temp_path)) unlink(temp_path)
    message("Downloading comparison_sample.csv: attempt ", attempt, "/3")
    tryCatch(
      download.file(url, destfile = temp_path, mode = "wb",
                    method = "libcurl", quiet = FALSE),
      error = function(e) message("Download interrupted: ", conditionMessage(e))
    )
    actual <- if (file.exists(temp_path)) file.info(temp_path)$size else NA_real_
    if (!is.na(actual) && actual == expected_bytes) {
      if (!file.rename(temp_path, compare_path)) {
        stop("Could not move completed download into the cache directory")
      }
      complete <- TRUE
      break
    }
    message("Incomplete download: ", actual, " / ", expected_bytes, " bytes")
  }
  if (!complete) stop("Comparison CSV could not be downloaded completely; no analysis was run")
} else {
  message("Using complete cached comparison_sample.csv (", cached_bytes, " bytes)")
}

# Read only the two cached input files and existing model parameter draws.
comparison <- read.csv(compare_path, stringsAsFactors = FALSE, check.names = FALSE)
history <- read.csv(hist_path, stringsAsFactors = FALSE, check.names = FALSE)
saved <- readRDS(param_path)
stopifnot(nrow(comparison) == 3244,
          all(c("id", "name", "average", "users_rated") %in% names(comparison)),
          all(c("BGGId", "StdDev", "NumUserRatings") %in% names(history)),
          all(c("draws", "x_center") %in% names(saved)))

num <- function(x) suppressWarnings(as.numeric(gsub(",", "", as.character(x), fixed = TRUE)))
hist_id <- suppressWarnings(as.integer(as.character(history$BGGId)))
stopifnot(!anyDuplicated(hist_id[!is.na(hist_id)]), !anyDuplicated(comparison$id))
idx <- match(as.integer(as.character(comparison$id)), hist_id)

all_cmp <- data.frame(
  id = as.integer(as.character(comparison$id)),
  name = comparison$name,
  y = num(comparison$average),
  n = num(comparison$users_rated),
  sd_hist = num(history$StdDev)[idx],
  n_hist = num(history$NumUserRatings)[idx],
  stringsAsFactors = FALSE
)
all_cmp$relative_n_diff <- abs(all_cmp$n_hist - all_cmp$n) / all_cmp$n
valid <- is.finite(all_cmp$y) & is.finite(all_cmp$n) & all_cmp$n >= 30 &
         is.finite(all_cmp$sd_hist) & all_cmp$sd_hist > 0 &
         is.finite(all_cmp$n_hist) & all_cmp$n_hist > 0
cmp <- all_cmp[valid, , drop = FALSE]
if (nrow(cmp) < 100) stop("Too few valid historical SD matches in comparison sample")
write.csv(all_cmp, file.path(out_dir, "holdout_SD_matching_audit.csv"), row.names = FALSE)
cat("Holdout total:", nrow(all_cmp), "\n")
cat("Holdout valid SD matches:", nrow(cmp), "\n")
cat("Holdout unmatched/invalid:", nrow(all_cmp) - nrow(cmp), "\n")
cat("Holdout rating-count discrepancy <=5%:",
    sum(cmp$relative_n_diff <= 0.05), "/", nrow(cmp), "\n")

# Reuse saved MCMC parameter draws from DEVELOPMENT fit (no refitting).
z <- as.matrix(saved$draws)
required <- c("alpha", "gamma", "a_tau", "b_tau")
stopifnot(all(required %in% colnames(z)), nrow(z) >= 500)
B <- 500L
pick <- sample.int(nrow(z), B)
N <- nrow(cmp)
x <- log(cmp$n) - saved$x_center  # Important: TRAINING centering, do not recenter on holdout
v_obs <- cmp$sd_hist^2 / cmp$n

sim_y <- matrix(NA_real_, nrow = N, ncol = B)
loglik <- matrix(NA_real_, nrow = N, ncol = B)
for (b in seq_len(B)) {
  d <- z[pick[b], ]
  mu <- unname(d["alpha"] + d["gamma"] * x)
  tau2 <- unname(exp(2 * (d["a_tau"] + d["b_tau"] * x)))
  sd_pred <- sqrt(tau2 + v_obs)
  sim_y[, b] <- rnorm(N, mean = mu, sd = sd_pred)
  loglik[, b] <- dnorm(cmp$y, mean = mu, sd = sd_pred, log = TRUE)
}

# Posterior predictive distribution of HELD-OUT observed average ratings.
qrow <- function(a, prob) apply(a, 1, quantile, probs = prob)
# log(mean(exp(loglik))) with stability correction, by game
log_score <- apply(loglik, 1, function(l) {
  peak <- max(l)
  peak + log(mean(exp(l - peak)))
})
per_game <- data.frame(
  id = cmp$id, name = cmp$name, n = cmp$n,
  observed_average = cmp$y, sd_hist = cmp$sd_hist,
  relative_n_diff = cmp$relative_n_diff,
  predictive_median = qrow(sim_y, .5),
  predictive_lower = qrow(sim_y, .025),
  predictive_upper = qrow(sim_y, .975),
  log_predictive_density = log_score,
  stringsAsFactors = FALSE
)
per_game$covered_95 <- with(per_game, observed_average >= predictive_lower &
                                         observed_average <= predictive_upper)
write.csv(per_game, file.path(out_dir, "holdout_game_predictions.csv"), row.names = FALSE)

# Check the SAME four rating-count groups as development PPC.
groups <- list(
  "30-40" = which(cmp$n >= 30 & cmp$n <= 40),
  "100-200" = which(cmp$n >= 100 & cmp$n <= 200),
  "1000-5000" = which(cmp$n >= 1000 & cmp$n <= 5000),
  "5000+" = which(cmp$n > 5000)
)
q <- function(v, p) quantile(v, probs = p, na.rm = TRUE, names = FALSE)
rows <- lapply(names(groups), function(g) {
  ix <- groups[[g]]
  if (length(ix) < 2) return(NULL)
  rep_mean <- colMeans(sim_y[ix, , drop = FALSE])
  rep_var <- apply(sim_y[ix, , drop = FALSE], 2, var)
  obs_mean <- mean(cmp$y[ix]); obs_var <- var(cmp$y[ix])
  lo_mean <- q(rep_mean, .025); hi_mean <- q(rep_mean, .975)
  lo_var <- q(rep_var, .025); hi_var <- q(rep_var, .975)
  data.frame(
    group = g, games = length(ix),
    observed_mean = obs_mean,
    predictive_mean_median = median(rep_mean),
    predictive_mean_low = lo_mean, predictive_mean_high = hi_mean,
    mean_in_95_interval = (obs_mean >= lo_mean & obs_mean <= hi_mean),
    observed_variance = obs_var,
    predictive_variance_median = median(rep_var),
    predictive_variance_low = lo_var, predictive_variance_high = hi_var,
    variance_in_95_interval = (obs_var >= lo_var & obs_var <= hi_var),
    individual_95_coverage = mean(per_game$covered_95[ix]),
    mean_log_density = mean(log_score[ix]),
    row.names = NULL
  )
})
grouped <- do.call(rbind, rows)
write.csv(grouped, file.path(out_dir, "holdout_grouped_PPC.csv"), row.names = FALSE)
print(grouped, row.names = FALSE, digits = 3)

summary_out <- data.frame(
  metric = c("total_comparison_games", "matched_games", "unmatched_or_invalid_games",
             "share_n_hist_within_5pct", "individual_95_predictive_coverage",
             "sum_log_predictive_density", "mean_log_predictive_density",
             "groups_passing_mean_PPC", "groups_passing_variance_PPC"),
  value = c(nrow(all_cmp), N, nrow(all_cmp) - N,
            mean(cmp$relative_n_diff <= .05), mean(per_game$covered_95),
            sum(log_score), mean(log_score),
            sum(grouped$mean_in_95_interval), sum(grouped$variance_in_95_interval))
)
write.csv(summary_out, file.path(out_dir, "holdout_summary.csv"), row.names = FALSE)
print(summary_out, row.names = FALSE)

cat("\nFinished. Upload ONLY holdout_summary.csv and holdout_grouped_PPC.csv for review.\n")
cat("Save all other files locally.\n")
cat("CAUTION: historical within-game SD is a plug-in estimate with unverified snapshot date.\n")
cat("CAUTION: prior exploratory work already inspected this holdout split.\n")