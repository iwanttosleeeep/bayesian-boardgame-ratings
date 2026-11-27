# Shared filesystem lookup only: no fitting, downloads, random draws or writes.
.repo_root <- normalizePath(file.path(dirname(.repo_helper), ".."), winslash="/", mustWork=TRUE)
repo_path <- function(...) file.path(.repo_root, ...)
repo_output_path <- function(...) file.path(Sys.getenv("BOARDGAME_OUTPUT_ROOT", unset=.repo_root), ...)
repo_existing <- function(paths, label, required=TRUE) {
  hit <- paths[file.exists(paths)]
  if (length(hit)) return(normalizePath(hit[1], winslash="/", mustWork=TRUE))
  if (!required) return(paths[1])
  stop("Missing ", label, ". Checked:\n", paste(paths, collapse="\n"),
       "\nSee docs/REPRODUCTION.md for exact prerequisites; no replacement was generated.", call.=FALSE)
}
repo_check_paths <- function(paths, label="inputs") {
  if (!"--check-paths" %in% commandArgs(trailingOnly=TRUE)) return(invisible(FALSE))
  ok <- file.exists(paths)
  cat("Repository:", .repo_root, "\n", label, ":\n", sep="")
  for (i in seq_along(paths)) cat(if (ok[i]) "OK " else "MISSING ", paths[i], "\n", sep="")
  quit(save="no", status=if (all(ok)) 0L else 2L)
}
# Preserve the original P5 working cache, including caches outside the checkout.
.p5_cache <- Sys.getenv("P5_CACHE_DIR", unset="")
if (!nzchar(.p5_cache)) {
  candidates <- c(if (basename(.launch_dir)=="P5_external_SD") .launch_dir
                  else file.path(.launch_dir,"P5_external_SD"), repo_path("P5_external_SD"))
  hits <- candidates[dir.exists(candidates)]
  .p5_cache <- if (length(hits)) hits[1] else repo_path("P5_external_SD")
}
.p5_cache <- normalizePath(.p5_cache, winslash="/", mustWork=FALSE)
# Each entry names a single model fit/dataset; there is no basename-wide search.
.p5_files <- list(
  train=c("P5_SD_matched.csv", "outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"),
  a_draws=c("Model_A_same_6416/parameter_draws.rds", "outputs/P5/M1a_Baseline/parameter_draws.rds"),
  a_conv=c("Model_A_same_6416/convergence.csv", "outputs/P5/M1a_Baseline/convergence.csv"),
  d_draws=c("Model_D_calibrated/parameter_draws.rds", "outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds"),
  d_conv=c("Model_D_calibrated/convergence.csv", "outputs/P5/M1a_Extended_ExternalSD/convergence.csv"),
  d_ratings=c("Model_D_calibrated/posterior_ratings_development.csv", "outputs/P5/M1a_Extended_ExternalSD/posterior_ratings_development.csv"),
  d_latent=c("Model_D_calibrated/latent_rating_draws_for_P6.rds", "outputs/P5/M1a_Extended_ExternalSD/latent_rating_draws_for_P6.rds"),
  d_ppc=c("Model_D_calibrated/grouped_PPC_development.csv", "outputs/P5/M1a_Extended_ExternalSD/grouped_PPC_development.csv"),
  holdout=c("holdout_validation/holdout_game_predictions.csv", "outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv")
)
p5_input <- function(key, required=TRUE) {
  paths <- .p5_files[[key]]
  if (is.null(paths)) stop("Unknown P5 input key: ", key)
  local_path <- file.path(.p5_cache,paths[1])
  # A restored fit directory owns its entire bundle. Never complete a partial
  # local posterior/summary bundle with files from another saved run.
  if (grepl("^[ad]_",key) && dir.exists(dirname(local_path)))
    return(repo_existing(local_path,paste("original local P5 fit component",key),required))
  repo_existing(c(local_path,repo_path(paths[2])),paste("P5",key),required)
}
p5_training_provenance <- function(fit, path) {
  observed <- unname(tools::md5sum(path)); expected <- unname(fit$input_md5)
  if (!identical(observed,expected))
    stop("Training CSV provenance mismatch: expected MD5 ", expected,
         "; found ", observed, " at ", path,
         ". Restore the ORIGINAL P5_SD_matched.csv for this fit in P5_CACHE_DIR; ",
         "do not refit, replace draws, or bypass this check. See docs/REPRODUCTION.md.", call.=FALSE)
  invisible(TRUE)
}
