# ============================================================
# P2: make GitHub-safe log-likelihood files.
# Problem: full loglik files are ~161MB each; GitHub rejects any
# single file over 100MB. WAIC needs only a subset of draws, so
# we keep about 1000 of the 8000 draws -> roughly 20MB each.
# Run: open in RStudio -> Ctrl+A -> Ctrl+Enter.
# ============================================================

.script_dir <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile)),
  error = function(e) NA_character_
)
if (is.na(.script_dir) || !file.exists(file.path(.script_dir, "M0_functions.R"))) {
  .script_dir <- "C:/Users/28131/WorkBuddy/2026-11-20-18-32-14/code/P2_m0"
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
  step <- ceiling(nrow(ll) / 1000)          # keep about 1000 draws
  idx  <- seq(1, nrow(ll), by = step)
  ll_small <- ll[idx, , drop = FALSE]
  saveRDS(ll_small, f_out, compress = TRUE)

  cat(sprintf("%s: %d x %d  ->  %d x %d, saved %s (%.1f MB)\n",
              who, nrow(ll), ncol(ll), nrow(ll_small), ncol(ll_small),
              f_out, file.info(f_out)$size / 1024 / 1024))
}

cat("\nUpload the *_share.rds files. Keep the full versions locally.\n")
cat("Tell P5: 1000 draws were kept (every 8th) -- enough for WAIC.\n")
