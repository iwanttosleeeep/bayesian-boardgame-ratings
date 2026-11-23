# ============================================================
# M0 data preparation - cleaning + mean imputation on the training file.
# Source: data/dev_subsample.csv (the 6,489 development games).
# Zeros and out-of-range years are first turned into NA, then each
# transformed covariate is mean-imputed so NO game is dropped. That
# keeps training IDs identical across M0 / M1a / M1b for WAIC.
# Only a missing outcome would drop a row (none in dev_subsample).
# Nothing here changes the source file; it only reads it.
# ============================================================

# Turn 0 into NA, keep everything else.
zero_to_na <- function(x) {
  x[!is.finite(x) | x == 0] <- NA_real_
  x
}

# Apply Proposal cleaning rules and build M0 covariates.
# Returns a list(y, X, X_raw, ids, n_in, n_out, dropped) ready for fit_m0_gibbs.
# `ids` are the game IDs actually used after cleaning. Save these so that
# M0/M1a/M1b can be compared on exactly the same games (WAIC alignment).
m0_prepare <- function(path,
                       y_col = "average",
                       cap_play = 600,
                       cap_maxplayers = 36) {

  dat <- read.csv(path, stringsAsFactors = FALSE)
  cat(sprintf("Loaded %s: %d rows, %d cols\n", path, nrow(dat), ncol(dat)))
  stopifnot(y_col %in% names(dat))

  num <- function(nm) as.numeric(dat[[nm]])

  # ---- 1. Outcome ----
  y <- num(y_col)

  # ---- 2. Sample size n = users_rated (NOT a banned covariate) ----
  n_rated <- zero_to_na(num("users_rated"))

  # ---- 3. year -> age, valid range 1900-2022 (Proposal rule 2) ----
  yr <- num("year")
  yr[yr < 1900 | yr > 2022] <- NA_real_
  age <- 2022 - yr
  log1p_age <- log1p(age)

  # ---- 4. zeros are missing (Proposal rule 3) ----
  play      <- zero_to_na(num("playingtime"))
  maxpl     <- zero_to_na(num("maxplayers"))
  minpl     <- zero_to_na(num("minplayers"))
  minage    <- zero_to_na(num("minage"))

  # ---- 5. cap extremes (Proposal rule 3) ----
  play  <- pmin(play,  cap_play)
  maxpl <- pmin(maxpl, cap_maxplayers)

  # ---- 6. log transforms (Proposal rules 3 & 2) ----
  log_n     <- log(n_rated)
  log_play  <- log(play)
  # log(1+age) already computed above

  # ---- 7. Assemble candidate covariate matrix (continuous only) ----
  # Banned as covariates: rank, bayes_average, owned, trading,
  # wanting, wishing. users_rated enters only as n / log(n).
  X_raw <- cbind(
    log_n     = log_n,
    log_play  = log_play,
    log1p_age = log1p_age,
    minplayers = minpl,
    maxplayers = maxpl,
    minage     = minage
  )

  # ---- 8. Missing covariates: mean-impute instead of dropping rows ----
  # Requirement: fit on ALL 6,489 development games so the training IDs
  # match M1a/M1b. Zeros/out-of-range years were turned into NA above.
  # Impute each transformed covariate with its observed column mean.
  n_miss <- colSums(is.na(X_raw))
  for (j in seq_len(ncol(X_raw))) {
    if (n_miss[j] > 0) {
      mu <- mean(X_raw[, j], na.rm = TRUE)
      X_raw[is.na(X_raw[, j]), j] <- mu
    }
  }
  cat("Imputed missing covariates (mean):",
      paste(sprintf("%s=%d", names(n_miss), n_miss), collapse = ", "), "\n")

  # Keep every row whose outcome is observed. In dev_subsample.csv the
  # outcome has no missing values, so all 6,489 games are retained.
  keep <- stats::complete.cases(y)
  n_in <- nrow(dat)
  n_out <- sum(keep)
  cat(sprintf("Dropped %d rows with missing outcome -> n = %d\n",
              n_in - n_out, n_out))

  y <- y[keep]
  X_raw <- X_raw[keep, , drop = FALSE]
  # Game IDs actually used, for cross-model WAIC row alignment.
  ids <- if ("id" %in% names(dat)) dat$id[keep] else seq_len(n_in)[keep]

  # ---- 9. Add intercept, then standardize continuous covariates ----
  # M0 is y_i ~ N(x_i' beta, sigma2) with beta including an intercept.
  # Without an all-ones column the model is forced through the origin:
  # since y has mean ~6.4, sigma2 would inflate to about 6.4^2 = 41,
  # which is a wrong (but silently plausible-looking) result.
  # IMPORTANT: the intercept must NOT be standardized -- it stays 1.
  X_scaled <- scale(X_raw)
  colnames(X_scaled) <- colnames(X_raw)
  attr(X_scaled, "scaled:center") <- NULL
  attr(X_scaled, "scaled:scale")  <- NULL
  X <- cbind(intercept = rep(1, n_out), X_scaled)

  cat("M0 covariates (standardized; intercept unstandardized):",
      paste(colnames(X), collapse = ", "), "\n")
  cat(sprintf("y = %s, mean = %.3f, SD = %.3f\n",
              y_col, mean(y), stats::sd(y)))

  list(y = y, X = X, X_raw = X_raw, ids = ids,
       n_in = n_in, n_out = n_out, dropped = n_in - n_out)
}
