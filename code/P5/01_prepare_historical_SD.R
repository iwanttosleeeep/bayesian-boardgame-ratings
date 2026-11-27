# STAT6106 / P5 — Stage 1: create reusable historical BGG SD lookup
# Run once. On subsequent runs, the saved small CSV is reused.
# Source data: P1 dev_subsample.csv and historical AgeOfWar games.csv.
# IMPORTANT: Historical SD collection date is not independently verified.

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
repo_check_paths(if ("--rebuild-lookup" %in% commandArgs(TRUE))
  c(repo_path("dev_subsample.csv"),p5_historical_source(required=FALSE))
  else p5_input("train",required=FALSE))

out_dir <- .p5_cache
cache_dir <- file.path(out_dir, "source_cache")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

all_path <- file.path(out_dir, "P5_SD_all_6489.csv")
matched_path <- if ("--rebuild-lookup" %in% commandArgs(TRUE))
  file.path(out_dir,"P5_SD_matched.csv") else p5_input("train", required=FALSE)

if (!file.exists(matched_path)) {

  repo <- "https://raw.githubusercontent.com/iwanttosleeeep/bayesian-boardgame-ratings/main/"
  hist_url <- "https://raw.githubusercontent.com/AgeOfWar/AgeOfWar.github.io/master/games.csv"

  dev_path <- repo_existing(c(file.path(cache_dir,"dev_subsample.csv"), repo_path("dev_subsample.csv")), "P1 development CSV")
  hist_path <- p5_historical_source()

  dev <- read.csv(dev_path, stringsAsFactors = FALSE, check.names = FALSE)
  hist <- read.csv(hist_path, stringsAsFactors = FALSE, check.names = FALSE)

  stopifnot(nrow(dev) == 6489,
            all(c("id", "name", "average", "users_rated") %in% names(dev)),
            all(c("BGGId", "StdDev", "NumUserRatings") %in% names(hist)),
            !anyDuplicated(dev$id))

  numeric_column <- function(z) suppressWarnings(as.numeric(gsub(",", "", as.character(z), fixed = TRUE)))
  hist_id <- suppressWarnings(as.integer(as.character(hist$BGGId)))
  good_id <- !is.na(hist_id)
  if (anyDuplicated(hist_id[good_id])) {
    stop("Historical BGGId has duplicates; review before matching, rather than arbitrarily selecting rows.")
  }

  idx <- match(as.integer(as.character(dev$id)), hist_id)
  hist_mean_col <- intersect(c("AvgRating", "AverageRating", "Average", "Avg"), names(hist))
  mean_hist <- if (length(hist_mean_col) > 0) numeric_column(hist[[hist_mean_col[1]]])[idx] else rep(NA_real_, nrow(dev))

  joined <- data.frame(
    id = as.integer(as.character(dev$id)),
    name = dev$name,
    average_2022 = numeric_column(dev$average),
    n_2022 = numeric_column(dev$users_rated),
    sd_hist = numeric_column(hist$StdDev)[idx],
    n_hist = numeric_column(hist$NumUserRatings)[idx],
    average_hist = mean_hist,
    stringsAsFactors = FALSE
  )

  joined$relative_n_diff <- abs(joined$n_hist - joined$n_2022) / joined$n_2022
  joined$valid_sd <- is.finite(joined$sd_hist) & joined$sd_hist > 0 &
                     is.finite(joined$n_hist) & joined$n_hist > 0

  matched <- joined[joined$valid_sd, , drop = FALSE]
  stopifnot(!anyDuplicated(matched$id), all(matched$n_2022 >= 30))

  write.csv(joined, all_path, row.names = FALSE, fileEncoding = "UTF-8")
  write.csv(matched, matched_path, row.names = FALSE, fileEncoding = "UTF-8")
  writeLines(c(
    paste0("Historical source: ", hist_url),
    paste0("Development source: ", repo, "dev_subsample.csv"),
    "Historical acquisition date not independently verified.",
    "sd_hist is a plug-in estimate of within-game individual-rating SD, not an error-free 2022 value.",
    "Sample uses the 2026-11-22 P1 development split, not the independent comparison holdout."
  ), file.path(out_dir, "SD_PROVENANCE.txt"))

  message("Created the compact matched SD file.")
} else {
  message("Compact match already saved. Skipping BOTH large source datasets.")
}

matched <- read.csv(matched_path, stringsAsFactors = FALSE)
cat("\nDevelopment sample: 6489 games\n")
cat("Matched with usable historical SD:", nrow(matched), "\n")
cat("Unmatched:", 6489 - nrow(matched), "\n")
cat("Median historical within-game SD:", round(median(matched$sd_hist), 4), "\n")
cat("Number with historical rating-count difference <=5%:",
    sum(matched$relative_n_diff <= 0.05, na.rm = TRUE), "\n")
cat("Saved lookup:", normalizePath(matched_path), "\n")