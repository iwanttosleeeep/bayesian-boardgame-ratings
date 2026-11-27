# Read-only source reconciliation: no models, random draws or analytical writes.
args <- commandArgs(trailingOnly=TRUE)
root <- normalizePath(if (length(args)) args[1] else ".", winslash="/", mustWork=TRUE)
source_path <- file.path(root,"data/raw/historical_games.csv")
stopifnot(file.info(source_path)$size==22119464,
          identical(unname(tools::md5sum(source_path)),"f5c23231f6c17937569dce304626d3c4"))
read <- function(path) read.csv(file.path(root,path),stringsAsFactors=FALSE,check.names=FALSE)
number <- function(x) suppressWarnings(as.numeric(gsub(",","",as.character(x),fixed=TRUE)))
same <- function(x,y) stopifnot(isTRUE(all.equal(number(x),number(y),tolerance=1e-12)))
hist <- read("data/raw/historical_games.csv")
stopifnot(nrow(hist)==21925L,ncol(hist)==48L,
          all(c("BGGId","StdDev","NumUserRatings","AvgRating") %in% names(hist)),
          all(is.finite(number(hist$BGGId))),!anyDuplicated(hist$BGGId))
lookup <- function(dat) {
  idx <- match(dat$id,hist$BGGId)
  sd <- number(hist$StdDev)[idx]; n <- number(hist$NumUserRatings)[idx]
  list(sd=sd,n=n,average=number(hist$AvgRating)[idx],
       valid=is.finite(sd) & sd>0 & is.finite(n) & n>0)
}
dev <- read("dev_subsample.csv"); compact <- read("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv")
d <- lookup(dev)
stopifnot(sum(d$valid)==6416L,identical(dev$id[d$valid],compact$id))
same(d$sd[d$valid],compact$sd_hist);same(d$n[d$valid],compact$n_hist)
same(d$average[d$valid],compact$average_hist)
same(abs(d$n[d$valid]-dev$users_rated[d$valid])/dev$users_rated[d$valid],compact$relative_n_diff)
cmp <- read("comparison_sample.csv")
holdout <- read("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv")
h <- lookup(cmp)
valid <- h$valid & is.finite(number(cmp$average)) & is.finite(number(cmp$users_rated)) & number(cmp$users_rated)>=30
stopifnot(sum(valid)==3209L,identical(cmp$id[valid],holdout$id))
same(h$sd[valid],holdout$sd_hist)
same(abs(h$n[valid]-cmp$users_rated[valid])/cmp$users_rated[valid],holdout$relative_n_diff)
dat <- read("data_clean.csv")
audit <- read("outputs/P5/P6_Full_Handoff/P6_all_21631_SD_matching_audit.csv")
a <- lookup(dat)
valid <- a$valid & is.finite(number(dat$average)) & is.finite(number(dat$users_rated)) & number(dat$users_rated)>=30
stopifnot(nrow(dat)==21631L,identical(dat$id,audit$id),sum(valid)==21375L,
          identical(a$valid,audit$valid_sd))
same(a$sd,audit$sd_hist);same(a$n,audit$n_hist)
same(abs(a$n-dat$users_rated)/dat$users_rated,audit$relative_n_diff)
cat("PASS: exact source bytes, 21,925 unique IDs / 48 columns; committed 6,416 development, 3,209 holdout and 21,375 / 21,631 full-scope matches agree (numeric tolerance 1e-12).\n")
