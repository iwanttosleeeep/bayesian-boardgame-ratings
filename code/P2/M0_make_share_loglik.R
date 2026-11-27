# ============================================================
# P2: make GitHub-safe pointwise log-likelihood files for WAIC.
# Full loglik files are ~360MB each (8000 draws x 6489 games);
# GitHub's web uploader rejects any single file over 25MB. We keep
# 500 of the 8000 draws -> ~22MB each (under 25MB).
# Output format matches P5's archive/outputs/P5/M1a_WAIC_6489 handoff: a list with
# ids, draw_index, loglik (500 x 6489), convention, train_md5.
# Run: open in RStudio -> Ctrl+A -> Ctrl+Enter.
# ============================================================


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
repo_check_paths(vapply(c("dev_subsample.csv","code/P2/M0_functions.R","code/P2/M0_prepare.R"), repo_path, ""))

out_dir <- repo_output_path("outputs", "P2")
dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
data_path <- repo_path("dev_subsample.csv")

# Reuse committed 500-draw shares without requiring uncommitted full caches.
ids_path <- repo_existing(c(file.path(out_dir,"M0_train_game_ids.csv"), repo_path("outputs/P2/M0_train_game_ids.csv"),
                           repo_path("outputs/M0_train_game_ids.csv")), "M0 training IDs")
# IDs actually used for the fit, saved by M0_run.R. They must be the
# same 6,489 IDs (same order) as P4/P5 before any WAIC comparison.
ids <- read.csv(ids_path)$id
stopifnot(length(ids) == 6489, !anyDuplicated(ids))

# Source MD5 so P5 can verify both models read the same input file.
train_md5 <- unname(tools::md5sum(data_path))

for (who in c("gibbs", "jags")) {
  f_in <- repo_existing(c(file.path(out_dir, sprintf("M0_loglik_%s.rds", who)),
                             repo_path("outputs", sprintf("M0_loglik_%s.rds", who))),
                        paste(who, "full M0 likelihood"), required=FALSE)
  f_out <- file.path(out_dir, sprintf("M0_loglik_%s_share.rds", who))

  if (file.exists(f_out)) {
    share <- readRDS(f_out)
    stopifnot(identical(dim(share$loglik), c(500L,6489L)),
              identical(as.character(share$ids),as.character(ids)),
              all(is.finite(share$loglik)),
              identical(colnames(share$loglik),as.character(ids)), identical(unname(share$train_md5),train_md5))
    cat("Using existing", who, "500-draw share:", f_out, "\n")
    next
  }
  if (!file.exists(f_in)) stop("Missing full likelihood and shared artifact for ",who,
    ". Recover the original M0 likelihood cache; see docs/REPRODUCTION.md. No refit was started.")

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
cat("Existing shares are ready to use. Full likelihood caches are only needed for a new export.\n")
cat("Tell P5: 500 draws were kept (thinned); ids are embedded and in",
    "the same order as P4/P5.\n")
