# STAT6106 P5: four-model holdout comparison; base R, no fitting.
# Run from repository root. Outputs go to a new local reproduction directory.
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
repo_check_paths(c(repo_path("archive/outputs/P5/M1a_Model_Comparison/comparison_holdout_per_game.csv"),
  repo_path("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv"),
  repo_path("outputs/P4/Holdout_3209/holdout_metadata.csv"),
  repo_path("outputs/P4/Holdout_3209/paired_log_predictive_density.csv"),
  repo_path("outputs/P4/Holdout_3209/holdout_summary.csv")))

rd <- function(p) read.csv(repo_path(p),stringsAsFactors=FALSE,fileEncoding="UTF-8")
a <- rd("archive/outputs/P5/M1a_Model_Comparison/comparison_holdout_per_game.csv")
b <- rd("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv")
c <- rd("outputs/P4/Holdout_3209/holdout_metadata.csv")
d <- rd("outputs/P4/Holdout_3209/paired_log_predictive_density.csv")
s <- rd("outputs/P4/Holdout_3209/holdout_summary.csv")
N <- 3209L
ids <- as.character(a$id)
stopifnot(length(ids)==N,!anyDuplicated(ids),
  all(vapply(list(b,c,d),function(z) identical(as.character(z$id),ids),logical(1))),
  all(a$n==b$n),all(a$n==c$n),all(a$n==d$n),
  all(a$observed_average==b$observed_average),
  all(a$observed_average==c$observed_average),all(b$sd_hist==c$sd_hist))
ll <- cbind(M1a_Baseline=a$log_density_A,M1a_Extended=a$log_density_Extended,
  M1b_Baseline=d$log_predictive_density_baseline,M1b_ExternalSD=d$log_predictive_density_external)
stopifnot(all(is.finite(ll)))
cov <- c(mean(a$covered95_A),mean(a$covered95_Extended),
  s$coverage_95[s$model=="matched_baseline"&s$group=="all"],
  s$coverage_95[s$model=="external_sd"&s$group=="all"])
stopifnot(length(cov)==4L,all(is.finite(cov)))
summary <- data.frame(model=colnames(ll),games=N,posterior_draws=c(1000,1000,16000,16000),
  ELPD=colSums(ll),mean_log_predictive_density=colMeans(ll),coverage_95=cov)
g <- ifelse(d$designer_group %in% c("seen_named","unseen_named"),
  paste0(d$designer_group,":",trimws(d$designer_name)),paste0("anon:",ids))
G <- length(unique(g))
stopifnot(G==2226L)
pair <- do.call(rbind,lapply(combn(1:4,2,simplify=FALSE),function(p){
  z <- ll[,p[2]]-ll[,p[1]]
  delta <- sum(z)
  se <- sqrt(G/(G-1)*sum(tapply(z-mean(z),g,sum)^2))
  data.frame(model_A=colnames(ll)[p[2]],model_B=colnames(ll)[p[1]],
    delta_ELPD_A_minus_B=delta,SE_cluster_approx=se,
    approx95_lower=delta-1.96*se,approx95_upper=delta+1.96*se,clusters=G)
}))
out <- file.path(dirname(.p5_cache), "P5_Holdout_Comparison_3209_reproduced")
dir.create(out,showWarnings=FALSE)
write.csv(summary,file.path(out,"holdout_four_model_summary.csv"),row.names=FALSE)
write.csv(pair,file.path(out,"holdout_pairwise_differences.csv"),row.names=FALSE)
print(summary,row.names=FALSE);print(pair,row.names=FALSE)
