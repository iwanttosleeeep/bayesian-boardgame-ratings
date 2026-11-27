# STAT6106 P5: three-model WAIC on 6,489 identical development games
# Run with base R; no JAGS, model refit, or manual path editing.
# M0 JAGS is the primary M0; Gibbs is an independent sampler check.
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
repo_check_paths(c(repo_path("outputs/P2/M0_loglik_jags_share.rds"),
  repo_path("outputs/P2/M0_loglik_gibbs_share.rds"),
  repo_path("archive/outputs/P5/M1a_WAIC_6489/pointwise_loglik_share.rds"),
  repo_path("outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds")))

options(timeout=max(600, getOption("timeout", 60)))
outdir <- file.path(dirname(.p5_cache), "P5_WAIC_Comparison_6489")
cachedir <- file.path(outdir, "input_cache")
dir.create(cachedir, recursive=TRUE, showWarnings=FALSE)
raw_base <- "https://raw.githubusercontent.com/iwanttosleeeep/bayesian-boardgame-ratings/main/"
get_input <- function(path) {
  candidates <- c(repo_path(path), path, file.path("..", path), file.path("..", "..", path))
  found <- candidates[file.exists(candidates)]
  if (length(found)) return(found[1])
  dest <- file.path(cachedir, gsub("/", "__", path, fixed=TRUE))
  if (!file.exists(dest) || file.size(dest)==0) {
    tmp <- paste0(dest, ".download")
    if (file.exists(tmp)) unlink(tmp)
    cat("Downloading:", path, "\n")
    status <- tryCatch(utils::download.file(paste0(raw_base, path), tmp,
                                          mode="wb", quiet=FALSE),
                       error=function(e) stop(conditionMessage(e)))
    if (!identical(status, 0L) || !file.exists(tmp) || file.size(tmp)==0)
      stop("Download failed: ", path)
    if (!file.rename(tmp, dest)) stop("Cannot save: ", dest)
  }
  dest
}
files <- c(
  M0_JAGS="outputs/P2/M0_loglik_jags_share.rds",
  M0_Gibbs="outputs/P2/M0_loglik_gibbs_share.rds",
  M1a="archive/outputs/P5/M1a_WAIC_6489/pointwise_loglik_share.rds",
  M1b="outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds"
)
id_files <- c(
  M0_JAGS="outputs/P2/M0_train_game_ids.csv",
  M1a="archive/outputs/P5/M1a_WAIC_6489/train_game_ids.csv",
  M1b="outputs/P4/M1b_WAIC_6489/train_game_ids.csv"
)
cat("Loading pointwise likelihood files; no fitting...\n")
objects <- lapply(files, function(path) readRDS(get_input(path)))
read_ids <- function(path) as.character(read.csv(get_input(path))$id)
ids <- read_ids(id_files[["M0_JAGS"]])
stopifnot(length(ids)==6489L, !anyDuplicated(ids))
for (nm in names(objects)) {
  obj <- objects[[nm]]
  stopifnot(is.list(obj), all(c("ids", "loglik", "convention", "train_md5") %in% names(obj)))
  ll <- obj$loglik
  if (!is.matrix(ll) || !identical(dim(ll), c(500L, 6489L)) ||
      !is.numeric(ll) || !all(is.finite(ll)) ||
      !identical(as.character(obj$ids), ids) ||
      !identical(colnames(ll), ids)) stop(nm, ": incompatible or misaligned likelihood")
  if (!is.null(obj$draw_index))
    stopifnot(!is.null(dim(obj$draw_index)), nrow(obj$draw_index)==500L)
  cat("PASS:", nm, "500 x 6489 and ID order\n")
}
for (nm in names(id_files)) stopifnot(identical(read_ids(id_files[[nm]]), ids))
stopifnot(identical(as.character(objects$M0_JAGS$train_md5),
                    as.character(objects$M1a$train_md5)))
if (!is.null(objects$M1b$train_md5_git_lf))
  stopifnot(identical(as.character(objects$M1b$train_md5_git_lf),
                      as.character(objects$M1a$train_md5)))

# WAIC: sum over identical games of -2*(lppd_i - var_posterior(loglik_i)).
waic_one <- function(ll, nm) {
  m <- apply(ll, 2, max)
  lppd <- m + log(colMeans(exp(sweep(ll, 2, m, "-"))))
  p <- apply(ll, 2, var)
  point <- -2*(lppd-p)
  list(point=point, penalty=p,
       tab=data.frame(model=nm, games=ncol(ll), posterior_draws=nrow(ll),
                      lppd=sum(lppd), p_waic=sum(p),
                      elpd_waic=sum(lppd-p), WAIC=sum(point),
                      SE_WAIC=sqrt(length(point)*var(point)),
                      max_pointwise_p_waic=max(p),
                      n_pointwise_p_waic_gt_0_4=sum(p>0.4)))
}
cat("Computing WAIC...\n")
results <- lapply(names(objects), function(nm) waic_one(objects[[nm]]$loglik, nm))
names(results) <- names(objects)
tables <- do.call(rbind, lapply(results, function(x) x$tab))
main <- tables[match(c("M0_JAGS", "M1a", "M1b"), tables$model), , drop=FALSE]
best <- main$model[which.min(main$WAIC)]
main$delta_WAIC <- main$WAIC-min(main$WAIC)
main$SE_delta_WAIC <- vapply(main$model, function(nm) {
  if (nm==best) return(0)
  diff <- results[[nm]]$point - results[[best]]$point
  sqrt(length(diff)*var(diff))
}, numeric(1))
main <- main[order(main$WAIC), , drop=FALSE]
rownames(main) <- NULL
pairs <- list(c("M0_JAGS","M1a"), c("M0_JAGS","M1b"), c("M1a","M1b"))
pairwise <- do.call(rbind, lapply(pairs, function(p) {
  diff <- results[[p[1]]]$point-results[[p[2]]]$point
  data.frame(model_A=p[1], model_B=p[2], delta_WAIC_A_minus_B=sum(diff),
             SE_delta_WAIC=sqrt(length(diff)*var(diff)))
}))
m0_diff <- results$M0_Gibbs$point-results$M0_JAGS$point
m0_check <- data.frame(comparison="Gibbs minus JAGS (same M0)",
                       Gibbs_WAIC=results$M0_Gibbs$tab$WAIC,
                       JAGS_WAIC=results$M0_JAGS$tab$WAIC,
                       delta_WAIC=sum(m0_diff),
                       SE_delta_WAIC=sqrt(length(m0_diff)*var(m0_diff)))

# Independent benchmark produced previously for the exact M1a input RDS.
if (abs(results$M1a$tab$WAIC - 17496.148377997575)>0.02)
  stop("M1a WAIC did not reproduce its previously verified value.")

write.csv(main, file.path(outdir,"WAIC_three_model_summary.csv"), row.names=FALSE)
write.csv(pairwise, file.path(outdir,"WAIC_pairwise_differences.csv"), row.names=FALSE)
write.csv(m0_check, file.path(outdir,"M0_Gibbs_vs_JAGS_check.csv"), row.names=FALSE)
write.csv(data.frame(id=ids,
                     M0_JAGS_pointwise_WAIC=results$M0_JAGS$point,
                     M1a_pointwise_WAIC=results$M1a$point,
                     M1b_pointwise_WAIC=results$M1b$point,
                     M0_JAGS_p_waic=results$M0_JAGS$penalty,
                     M1a_p_waic=results$M1a$penalty,
                     M1b_p_waic=results$M1b$penalty),
          file.path(outdir, "WAIC_gamewise_diagnostics.csv"), row.names=FALSE)

notes <- c(
  "STAT6106 P5: matched-game WAIC comparison (6,489 development games).",
  "M0 JAGS is primary; Gibbs is the same model via another sampler.",
  "WAIC=-2 sum_i (lppd_i-Var_draw(loglik_i)).",
  "Delta WAIC SE is paired across games: sqrt(N*Var_i(WAIC_Ai-WAIC_Bi)).",
  "These are in-sample WAIC approximations, NOT independent holdout scores.",
  "M1a integrates game latent theta; M0 has no game latent effect.",
  "M1b integrates game theta BUT conditions on learned named-designer effects.",
  "M1b's predictive target is not an entirely unseen designer; singleton",
  "designer effects and conditional scoring can undermine WAIC reliability.",
  "Different covariates, random effects, and noise models change together.",
  "WAIC differences do not isolate the causal effect of model components.",
  "If many pointwise p_waic values exceed 0.4, flag WAIC reliability.",
  "Do not compare rating-model WAIC to P3's popularity-model WAIC.",
  paste("Numerically lowest development WAIC:", best),
  "Use posterior predictive checks and scientific interpretation as well."
)
writeLines(notes, file.path(outdir,"WAIC_interpretation_and_checks.txt"))
cat("\n=== Three-model WAIC (numerically lower is better) ===\n")
print(main[,c("model","WAIC","SE_WAIC","delta_WAIC",
              "SE_delta_WAIC","p_waic","n_pointwise_p_waic_gt_0_4")],
      row.names=FALSE, digits=7)
cat("\n=== Pairwise model comparisons ===\n")
print(pairwise, row.names=FALSE, digits=7)
cat("\n=== M0 Gibbs/JAGS agreement ===\n")
print(m0_check, row.names=FALSE, digits=7)
cat("\nDONE. Files created in:", normalizePath(outdir), "\n")
cat("Send me: WAIC_three_model_summary.csv, WAIC_pairwise_differences.csv,\n")
cat("M0_Gibbs_vs_JAGS_check.csv, WAIC_interpretation_and_checks.txt\n")
