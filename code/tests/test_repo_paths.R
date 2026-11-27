# Lightweight lookup/provenance tests: no samplers, downloads or result writes.
args <- commandArgs(trailingOnly=TRUE)
root <- normalizePath(if(length(args)) args[1] else ".",winslash="/",mustWork=TRUE)
helper <- file.path(root,"code/repo_paths.R")
check <- function(cwd,cache="") {
  before <- getwd(); old <- Sys.getenv("P5_CACHE_DIR",unset=NA_character_)
  on.exit({setwd(before);if(is.na(old)) Sys.unsetenv("P5_CACHE_DIR") else Sys.setenv(P5_CACHE_DIR=old)},add=TRUE)
  setwd(cwd);Sys.setenv(P5_CACHE_DIR=cache)
  e <- new.env(parent=globalenv());e$.repo_helper<-helper;e$.launch_dir<-getwd()
  sys.source(helper,envir=e)
  stopifnot(identical(getwd(),normalizePath(cwd)),identical(e$repo_path("dev_subsample.csv"),file.path(root,"dev_subsample.csv")))
  e
}
e <- check(tempdir())
stopifnot(identical(e$p5_historical_source(),normalizePath(file.path(root,"data/raw/historical_games.csv"))))
stopifnot(identical(e$p5_input("a_draws"),normalizePath(file.path(root,"outputs/P5/M1a_Baseline/parameter_draws.rds"))),
          identical(e$p5_input("d_draws"),normalizePath(file.path(root,"outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds"))))
# A temporary copy of the actual committed CSV probes local-cache precedence.
cache <- tempfile("p5-path-test-");dir.create(cache)
stopifnot(file.copy(e$p5_input("train"),file.path(cache,"P5_SD_matched.csv")))
f <- check(tempdir(),cache)
stopifnot(identical(f$p5_input("train"),normalizePath(file.path(cache,"P5_SD_matched.csv"))))
dir.create(file.path(cache,"source_cache"))
historical <- file.path(cache,"source_cache","historical_games.csv")
stopifnot(file.copy(e$p5_historical_source(),historical),
          identical(f$p5_historical_source(),normalizePath(historical)),
          identical(unname(tools::md5sum(historical)),"f5c23231f6c17937569dce304626d3c4"))
# Preserve Script 11's original flat cache compatibility, using the real bytes.
flat <- tempfile("p5-flat-test-");dir.create(flat)
stopifnot(file.copy(e$p5_historical_source(),file.path(flat,"historical_games.csv")))
g <- check(flat,file.path(flat,"empty-cache"))
stopifnot(identical(g$p5_historical_source(),normalizePath(file.path(flat,"historical_games.csv"))))
dir.create(file.path(cache,"Model_D_calibrated"))
stopifnot(file.copy(e$p5_input("d_conv"),file.path(cache,"Model_D_calibrated","convergence.csv")))
stopifnot(!file.exists(f$p5_input("d_draws",required=FALSE)),
          inherits(try(f$p5_input("d_draws"),silent=TRUE),"try-error"))
stopifnot(inherits(try(f$repo_existing(file.path(cache,"absent"),"test missing input"),silent=TRUE),"try-error"))
a <- readRDS(e$p5_input("a_draws")); d <- readRDS(e$p5_input("d_draws")); train <- read.csv(e$p5_input("train"))
stopifnot(nrow(train)==6416L, identical(as.character(a$ids),as.character(train$id)),
          isTRUE(all.equal(as.numeric(d$x_center),mean(log(train$n_2022)),tolerance=1e-9)),
          grepl("v_obs[i]",d$model,fixed=TRUE))
# The recovered original must pass the unchanged checksum gate.
stopifnot(identical(unname(tools::md5sum(e$p5_input("train"))),unname(a$input_md5)))
e$p5_training_provenance(a,e$p5_input("train"))
# Regression: a missing final LF preserves CSV values but must fail provenance.
bytes <- readBin(e$p5_input("train"),"raw",n=file.info(e$p5_input("train"))$size)
stopifnot(tail(bytes,1)==as.raw(10L))
truncated <- file.path(cache,"missing-final-newline.csv")
writeBin(head(bytes,-1),truncated)
stopifnot(identical(read.csv(truncated),train),
          identical(unname(tools::md5sum(truncated)),"713f1976d7967b275e31e5c36b991eb0"))
provenance <- try(e$p5_training_provenance(a,truncated),silent=TRUE)
stopifnot(inherits(provenance,"try-error"),grepl("provenance mismatch",as.character(provenance)))
cat("PASS: absolute lookup, caller cwd, cache precedence, committed/legacy historical paths, partial-fit rejection, 6416 IDs, restored provenance and missing-final-newline rejection\n")
unlink(cache,recursive=TRUE)
unlink(flat,recursive=TRUE)
