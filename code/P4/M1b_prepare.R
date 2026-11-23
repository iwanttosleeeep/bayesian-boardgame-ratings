# Only training data are consumed here. No holdout reading or fitting.
m1b_raw_numeric <- function(dat) {
  cbind(log1p_n = log1p(dat$users_rated),
        log1p_age = log1p(dat$game_age),
        log1p_play = log1p(dat$playingtime_capped),
        minplayers = dat$minplayers, maxplayers_capped = dat$maxplayers_capped,
        minage = dat$minage)
}

m1b_missing <- function(x) is.na(x) | trimws(as.character(x)) %in% c("", "NA")

m1b_prepare <- function(dat, recipe = NULL) {
  stopifnot(nrow(dat) > 0, !anyDuplicated(dat$id),
            all(is.finite(dat$average)), all(is.finite(dat$users_rated)),
            all(dat$users_rated >= 30))
  raw <- m1b_raw_numeric(dat)
  fitting <- is.null(recipe)
  if (fitting) {
    stopifnot(all(colSums(is.finite(raw)) > 0))
    recipe <- list(medians = apply(raw, 2, median, na.rm = TRUE),
                   missing_numeric = colnames(raw)[colSums(!is.finite(raw)) > 0],
                   tag_cols = grep("^(cat_|mech_)", names(dat), value = TRUE))
    stopifnot(length(recipe$tag_cols) == 40)
  }
  miss <- !is.finite(raw)
  filled <- raw
  for (k in seq_len(ncol(raw))) filled[miss[, k], k] <- recipe$medians[k]
  if (fitting) {
    recipe$center <- colMeans(filled)
    recipe$scale <- apply(filled, 2, sd)
    recipe$scale[!is.finite(recipe$scale) | recipe$scale == 0] <- 1
  }
  scaled <- sweep(sweep(filled, 2, recipe$center, "-"), 2, recipe$scale, "/")
  designer_name <- trimws(as.character(dat$designer_id))
  anonymous <- m1b_missing(dat$designer_id)
  uncredited <- !anonymous & designer_name == "(Uncredited)"
  named <- !anonymous & !uncredited
  if (fitting) recipe$designers <- sort(unique(designer_name[named]))
  idx <- match(designer_name, recipe$designers)
  known <- named & !is.na(idx)
  # Placeholder index is multiplied by zero for unknown designers in JAGS.
  idx[!known] <- 1L
  miss_x <- miss[, recipe$missing_numeric, drop = FALSE] * 1
  colnames(miss_x) <- paste0("missing_", colnames(miss_x))
  tags <- as.matrix(dat[, recipe$tag_cols, drop = FALSE])
  stopifnot(all(is.finite(tags)), all(tags %in% c(0, 1)))
  X <- cbind(scaled, tags, multi_designer = dat$multi_designer, miss_x,
             missing_category = as.integer(m1b_missing(dat$boardgamecategory)),
             missing_mechanic = as.integer(m1b_missing(dat$boardgamemechanic)),
             missing_designer = as.integer(anonymous),
             uncredited_designer = as.integer(uncredited))
  if (fitting) {
    recipe$columns <- colnames(X)[apply(X, 2, function(x) length(unique(x)) > 1)]
    recipe$dropped_constants <- setdiff(colnames(X), recipe$columns)
  }
  X <- X[, recipe$columns, drop = FALSE]
  stopifnot(ncol(X) > 0, all(is.finite(X)), all(is.finite(dat$average)))
  prior_sd <- ifelse(colnames(X) %in% colnames(raw), 0.5, 0.3)
  list(data = list(N = nrow(dat), P = ncol(X), J = max(1L, length(recipe$designers)),
                   y = dat$average, n = dat$users_rated, X = X,
                   known = as.integer(known), designer = as.integer(idx),
                   beta_prec = 1/prior_sd^2), recipe = recipe, ids = dat$id)
}

m1b_latent <- function(y, n, mu, tau, s, sigma_d, known) {
  v <- s^2/n
  t2 <- tau^2 + (1-known)*sigma_d^2
  w <- t2/(t2+v)
  list(mean = mu + w*(y-mu), sd = sqrt(t2*v/(t2+v)), weight = w)
}
