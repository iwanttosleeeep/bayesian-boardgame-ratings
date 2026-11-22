# ============================================================
# P2: make GitHub-safe log-likelihood files.
# Problem: full loglik files are ~161MB each; GitHub's web uploader
# rejects any single file over 25MB. WAIC needs only a subset of
# draws, so we keep 500 of the 8000 draws -> roughly 10MB each
# (comfortably under 25MB).
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

for (who in c("gibbs", "jags")) {
  f_in  <- file.path(out_dir, sprintf("M0_loglik_%s.rds", who))
  f_out <- file.path(out_dir, sprintf("M0_loglik_%s_share.rds", who))

  if (!file.exists(f_in)) {
    cat(sprintf("SKIP: %s not found\n", f_in))
    next
  }

  ll <- readRDS(f_in)
  step <- ceiling(nrow(ll) / 500)           # keep 500 of 8000 draws -> ~10MB
  idx  <- seq(1, nrow(ll), by = step)
  ll_small <- ll[idx, , drop = FALSE]
  saveRDS(ll_small, f_out, compress = TRUE)

  cat(sprintf("%s: %d x %d  ->  %d x %d, saved %s (%.1f MB)\n",
              who, nrow(ll), ncol(ll), nrow(ll_small), ncol(ll_small),
              f_out, file.info(f_out)$size / 1024 / 1024))
}

cat("\nUpload the *_share.rds files. Keep the full versions locally.\n")
cat("Tell P5: 500 draws were kept (thinned) -- enough for WAIC.\n")
