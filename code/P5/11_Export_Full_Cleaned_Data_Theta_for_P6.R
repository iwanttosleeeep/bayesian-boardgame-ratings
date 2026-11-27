# STAT6106 / P5 — Full cleaned-dataset latent-rating handoff to P6.
# This uses the ALREADY fitted 6,416-development-game Extended M1a parameters.
# It does NOT refit and does NOT use the full set of games to estimate parameters.
# All theta_i estimates CONDITION ON each game's observed average and n.
# Coverage is limited to the P1 cleaned 2022 BGG dataset (n=21,631, >=30 ratings).
# Use a full checkout or BOARDGAME_REPO_ROOT when sourcing from another location.
# Base R only.

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
repo_check_paths(c(p5_input("train", required=FALSE),
  p5_input("d_draws", required=FALSE),
  repo_path("data_clean.csv"),
  file.path(.p5_cache,"source_cache","historical_games.csv")))

options(timeout=max(600, getOption("timeout", 60)))
set.seed(20261126)
root <- .p5_cache
cache_dir <- file.path(root, "source_cache")
out_dir <- file.path(root, "P6_full_dataset_handoff")
dir.create(cache_dir, recursive=TRUE, showWarnings=FALSE)
dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)
repo_base <- paste0("https://raw.githubusercontent.com/",
                    "iwanttosleeeep/bayesian-boardgame-ratings/main/")
historical_url <- "https://raw.githubusercontent.com/AgeOfWar/AgeOfWar.github.io/master/games.csv"

# Prefer existing local files; otherwise cache the exact repository handoffs.
get_file <- function(candidates, url, cache_name) {
  candidates <- c(candidates, vapply(candidates,repo_path,""))
  local <- candidates[file.exists(candidates)]
  if (length(local)) {
    cat("Using existing:", local[1], "\n")
    return(local[1])
  }
  dest <- file.path(cache_dir, cache_name)
  if (file.exists(dest) && file.info(dest)$size > 100) {
    cat("Using cache:", dest, "\n")
    return(dest)
  }
  temp <- paste0(dest, ".part")
  if (file.exists(temp)) unlink(temp)
  cat("Downloading:", cache_name, "\n")
  ok <- FALSE
  for (attempt in seq_len(2L)) {
    if (file.exists(temp)) unlink(temp)
    status <- tryCatch(
      utils::download.file(url, destfile=temp, mode="wb",
                           method="libcurl", quiet=FALSE),
      error=function(e) { message(conditionMessage(e)); NA_integer_ }
    )
    if (isTRUE(status==0L) && file.exists(temp) && file.info(temp)$size > 100) {
      ok <- file.rename(temp, dest)
      if (ok) break
    }
  }
  if (!ok) stop("Could not download ", cache_name,
                ". Locate the existing cached source and run again.")
  dest
}

dat_path <- get_file(
  c("data_clean.csv", "../data_clean.csv", "../../data_clean.csv"),
  paste0(repo_base, "data_clean.csv"), "full_data_clean.csv"
)
# A live URL may now contain a different snapshot: require the original source.
hist_path <- repo_existing(c(file.path(root,"source_cache","historical_games.csv"),
                             file.path(.launch_dir,"historical_games.csv")),
                           "original historical snapshot for the P6 handoff")
param_path <- get_file(
  c(file.path(root, "Model_D_calibrated", "parameter_draws.rds"),
    "outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds",
    "../outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds"),
  paste0(repo_base, "outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds"),
  "P5_extended_parameter_draws.rds"
)
dev_match_path <- get_file(
  c(file.path(root, "P5_SD_matched.csv"),
    "outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv",
    "../outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"),
  paste0(repo_base, "outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv"),
  "P5_original_dev_SD_matched.csv"
)

cat("\n=== Validate source files and model ===\n")
dat <- read.csv(dat_path, stringsAsFactors=FALSE, check.names=FALSE)
hist <- read.csv(hist_path, stringsAsFactors=FALSE, check.names=FALSE)
trained <- readRDS(param_path)
original_match <- read.csv(dev_match_path, stringsAsFactors=FALSE)
required_dat <- c("id","name","average","users_rated","bayes_average","rank")
required_hist <- c("BGGId","StdDev","NumUserRatings")
required_match <- c("id","sd_hist","n_hist")
stopifnot(nrow(dat)==21631L, !anyDuplicated(dat$id),
          all(required_dat %in% names(dat)),
          all(required_hist %in% names(hist)),
          all(required_match %in% names(original_match)),
          is.list(trained), all(c("draws","x_center") %in% names(trained)))

number <- function(z) suppressWarnings(as.numeric(gsub(",", "", as.character(z), fixed=TRUE)))
hist_id <- suppressWarnings(as.integer(as.character(hist$BGGId)))
if (anyDuplicated(hist_id[!is.na(hist_id)])) stop("Historical IDs contain duplicates.")
idx <- match(as.integer(as.character(dat$id)), hist_id)
all_games <- data.frame(
  id=as.integer(as.character(dat$id)), name=dat$name,
  average_2022=number(dat$average), n_2022=number(dat$users_rated),
  bgg_bayes_average=number(dat$bayes_average), bgg_rank=number(dat$rank),
  sd_hist=number(hist$StdDev)[idx],
  n_hist=number(hist$NumUserRatings)[idx],
  stringsAsFactors=FALSE
)
all_games$relative_n_diff <- abs(all_games$n_hist-all_games$n_2022)/all_games$n_2022
all_games$valid_sd <- is.finite(all_games$sd_hist) & all_games$sd_hist>0 &
  is.finite(all_games$n_hist) & all_games$n_hist>0
valid <- all_games$valid_sd & is.finite(all_games$average_2022) &
  is.finite(all_games$n_2022) & all_games$n_2022>=30

# Revalidate that the complete historical source matches the 6,416 SD records
# used when the committed Extended parameter posterior was originally fitted.
refidx <- match(as.character(original_match$id), as.character(all_games$id))
stopifnot(nrow(original_match)==6416L, all(!is.na(refidx)),
          all(valid[refidx]))
if (any(abs(all_games$sd_hist[refidx]-number(original_match$sd_hist))>1e-8) ||
    any(abs(all_games$n_hist[refidx]-number(original_match$n_hist))>1e-8))
  stop("Historical source values disagree with the original Extended fit lookup. ",
       "Do not mix changing external data snapshots; inspect the historical cache.")
cat("PASS: 6,416 originally fitted development-game SD values match source.\n")

write.csv(all_games, file.path(out_dir, "P6_all_21631_SD_matching_audit.csv"),
          row.names=FALSE, fileEncoding="UTF-8")
games <- all_games[valid, , drop=FALSE]
N <- nrow(games)
if (N<19000L) stop("Unexpectedly few historical SD matches (",N,"). Review source.")
stopifnot(!anyDuplicated(games$id))

z <- as.matrix(trained$draws)
required_params <- c("alpha","gamma","a_tau","b_tau")
stopifnot(all(required_params %in% colnames(z)),
          all(is.finite(z[,required_params,drop=FALSE])),
          length(trained$x_center)==1L, is.finite(trained$x_center),
          nrow(z)>=500L)
# The original model has four chains. Draw a balanced, spaced posterior subset.
B <- 500L
if (nrow(z) %% 4L != 0L) stop("Posterior draws cannot be divided into four chains.")
chain_size <- nrow(z)%/%4L
within <- as.integer(round(seq(1, chain_size, length.out=B%/%4L)))
stopifnot(length(unique(within))==B%/%4L)
pick <- unlist(lapply(0:3, function(k) within+k*chain_size),
               use.names=FALSE)
stopifnot(length(pick)==B)
cat("PASS:", nrow(z), "saved parameter draws;", B,
    "balanced posterior draws selected.\n")

x <- log(games$n_2022)-trained$x_center
vobs <- games$sd_hist^2/games$n_2022
stopifnot(all(is.finite(x)),all(is.finite(vobs)),all(vobs>0))
theta <- matrix(NA_real_, nrow=N, ncol=B)
for (b in seq_len(B)) {
  d <- z[pick[b], ]
  mu <- unname(d["alpha"] + d["gamma"]*x)
  tau2 <- unname(exp(2*(d["a_tau"]+d["b_tau"]*x)))
  w <- tau2/(tau2+vobs)
  theta[,b] <- stats::rnorm(N,
      mean=mu+w*(games$average_2022-mu),
      sd=sqrt(tau2*vobs/(tau2+vobs)))
}
if (!all(is.finite(theta))) stop("Non-finite theta samples; no files exported.")
rownames(theta) <- as.character(games$id)

posterior <- data.frame(
  id=games$id, name=games$name,
  n_2022=games$n_2022, raw_average=games$average_2022,
  sd_hist=games$sd_hist, n_hist=games$n_hist,
  bgg_bayes_average=games$bgg_bayes_average,
  bgg_rank=games$bgg_rank,
  theta_mean=rowMeans(theta),
  theta_ci_lower=apply(theta,1,stats::quantile,probs=0.025,names=FALSE),
  theta_ci_upper=apply(theta,1,stats::quantile,probs=0.975,names=FALSE),
  stringsAsFactors=FALSE
)
posterior$shrinkage <- posterior$theta_mean-posterior$raw_average
write.csv(posterior, file.path(out_dir,"P6_all_games_posterior_ratings.csv"),
          row.names=FALSE, fileEncoding="UTF-8")

# Save 5 independent files with the SAME ordered game rows and disjoint draw
# columns. Each has only 100 columns: safe for GitHub's 25-MiB web upload limit.
# P6 must concatenate columns, not treat the five parts as different datasets.
parts <- split(seq_len(B), ceiling(seq_len(B)/100L))
for (k in seq_along(parts)) {
  path <- file.path(out_dir, sprintf("P6_theta_draws_part_%02d.rds",k))
  saveRDS(list(
    id=games$id, name=games$name,
    theta_draws=theta[,parts[[k]],drop=FALSE],
    draw_numbers=parts[[k]],
    model="M1a Extended, fitted on 6416 development games",
    scope="P1 cleaned 2022 BGG dataset with valid historical SD, >=30 ratings",
    conditioning="theta conditions on each game's observed average and rating count"
  ), path, compress="gzip")
  cat(sprintf("Saved %s: %d games x %d joint draws (%.2f MiB)\n",
              basename(path),N,length(parts[[k]]),
              file.info(path)$size/(1024^2)))
  if (file.info(path)$size>=25*1024^2)
    warning("This part is too large for browser upload; split into smaller parts.")
}

summary_rows <- data.frame(
  metric=c("P1_cleaned_games","historical_SD_matched_games",
           "historical_SD_unmatched_or_invalid",
           "original_development_matched_games","posterior_parameter_draws",
           "joint_theta_draws","historical_count_within_5pct_fraction"),
  value=c(nrow(all_games),N,nrow(all_games)-N,6416L,nrow(z),B,
          mean(games$relative_n_diff<=0.05,na.rm=TRUE))
)
write.csv(summary_rows, file.path(out_dir,"P6_full_handoff_checks.csv"),
          row.names=FALSE)
writeLines(c(
  "STAT6106 P5 -> P6: FULL CLEANED-DATASET latent-rating handoff",
  "Source outcome: P1 2022 data_clean.csv (21,631 games, users_rated >= 30).",
  "SD source: AgeOfWar/AgeOfWar.github.io games.csv (original P5 working source).",
  "Historical SD snapshot date and ultimate upstream provenance are NOT verified.",
  "Model: M1a Extended trained on original 6,416 development games.",
  "No new parameter fitting: 500 balanced existing parameter draws.",
  "For ranking, concatenate P6_theta_draws_part_01.rds ... part_05.rds by COLUMNS.",
  "Every file's theta_draws matrix has GAMES IN ROWS and JOINT POSTERIOR DRAWS IN COLUMNS.",
  "The ordered id vector is identical across parts and P6_all_games_posterior_ratings.csv.",
  "Rank within the included P1 2022 dataset ONLY; not across all games currently on BGG.",
  "Per-game theta conditions on that game's OBSERVED raw mean and number of ratings.",
  "This includes observed averages of the 2022 held-out games for latent reconstruction.",
  "Do NOT use these conditional theta estimates as holdout prediction scores.",
  "Prediction for unseen games is a separate, unconditional operation.",
  "Historical SD is treated as a fixed plug-in and may be from a different date.",
  "BGG bayes_average and BGG rank are benchmark fields, NOT model predictors.",
  "Games without valid historical SD are excluded; consult the full matching audit.",
  "M0/M1a/M1b matched training WAIC is a separate comparison (6,489 games)."
), file.path(out_dir,"P6_README.txt"))
cat("\n=== DONE ===\n")
print(summary_rows, row.names=FALSE)
cat("Output folder:", normalizePath(out_dir), "\n")
cat("Send the two small CSV files and P6_README.txt for inspection first.\n")
cat("For P6's ranking, also share all five P6_theta_draws_part_*.rds files.\n")
cat("No MCMC refit performed.\n")
