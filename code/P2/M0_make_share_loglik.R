# ============================================================
# P2: make GitHub-safe pointwise log-likelihood files for WAIC.
# Full loglik files are ~360MB each (8000 draws x 6489 games);
# GitHub's web uploader rejects any single file over 25MB. We keep
# 500 of the 8000 draws -> ~22MB each (under 25MB).
# Output format matches P5's M1a_WAIC_6489 handoff: a list with
# ids, draw_index, loglik (500 x 6489), convention, train_md5.
# Run: open in RStudio -> Ctrl+A -> Ctrl+Enter.
# ============================================================

.script_dir <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile)),
  error = function(e) NA_character_
)
if (is.na(.script_dir) || !file.exists(file.path(.script_dir, "M0_functions.R"))) {
  cand <- file.path(getwd(), "code", "P2_m0")
  .script_dir <- if (file.exists(file.path(cand, "M0_functions.R"))) {
    normalizePath(cand)
  } else {
    getwd()
  }
}
setwd(.script_dir)
cat("Working directory:", getwd(), "\n\n")

out_dir <- "../../outputs"
data_path <- "../../data/dev_subsample.csv"

# IDs actually used for the fit, saved by M0_run.R. They must be the
# same 6,489 IDs (same order) as P4/P5 before any WAIC comparison.
ids <- read.csv(file.path(out_dir, "M0_train_game_ids.csv"))$id
stopifnot(length(ids) == 6489, !anyDuplicated(ids))

# Source MD5 so P5 can verify both models read the same input file.
train_md5 <- unname(tools::md5sum(data_path))

for (who in c("gibbs", "jags")) {
  f_in  <- file.path(out_dir, sprintf("M0_loglik_%s.rds", who))
  f_out <- file.path(out_dir, sprintf("M0_loglik_%s_share.rds", who))

  if (!file.exists(f_in)) {
    cat(sprintf("SKIP: %s not found\n", f_in))
    next
  }

  ll <- readRDS(f_in)
  stopifnot(ncol(ll) == length(ids))      # columns align with saved IDs
  step <- ceiling(nrow(ll) / 500)         # keep 500 of 8000 draws -> ~22MB
  idx  <- seq(1, nrow(ll), by = step)
  ll_small <- ll[idx, , drop = FALSE]
  colnames(ll_small) <- as.character(ids)

  payload <- list(
    ids = ids,
    draw_index = data.frame(draw = idx),
    loglik = ll_small,
    convention = paste(
      "M0 pointwise log p(y_i | beta, sigma2, x_i), Normal linear regression;",
      "covariates mean-imputed for missing values, then standardized;",
      "all 6489 development training rows; latent theta NOT integrated",
      "(M0 has no game-level latent effect)"
    ),
    train_md5 = train_md5
  )
  saveRDS(payload, f_out, compress = "gzip")

  cat(sprintf("%s: %d x %d  ->  %d x %d, saved %s (%.1f MB)\n",
              who, nrow(ll), ncol(ll), nrow(ll_small), ncol(ll_small),
              f_out, file.info(f_out)$size / 1024 / 1024))
}

cat("\ntrain_md5:", train_md5, "\n")
cat("Upload the *_share.rds files. Keep the full versions locally.\n")
cat("Tell P5: 500 draws were kept (thinned); ids are embedded and in",
    "the same order as P4/P5.\n")
