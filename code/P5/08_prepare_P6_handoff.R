# STAT6106 P5 — Prepare and validate P6 handoff (no model fitting, no downloads)
# Run from the checkout or via an absolute script path; --validate-only writes nothing.

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
repo_check_paths(c(p5_input("d_latent", required=FALSE),
  p5_input("d_ratings", required=FALSE),
  p5_input("d_draws", required=FALSE),
  p5_input("d_conv", required=FALSE),
  p5_input("d_ppc", required=FALSE)))

dst <- file.path(.p5_cache, 'P6_handoff')
files <- c('latent_rating_draws_for_P6.rds', 'posterior_ratings_development.csv',
           'parameter_draws.rds', 'convergence.csv', 'grouped_PPC_development.csv')
sources <- setNames(vapply(c('d_latent','d_ratings','d_draws','d_conv','d_ppc'),
                          p5_input, ""), files)

latent <- readRDS(sources[files[1]])
ratings <- read.csv(sources[files[2]], stringsAsFactors=FALSE,
                    check.names=FALSE)
params <- readRDS(sources[files[3]])
stopifnot(is.list(latent), all(c('id','name','theta_draws') %in% names(latent)),
          is.matrix(latent$theta_draws), nrow(latent$theta_draws)==length(latent$id),
          length(latent$name)==length(latent$id),
          nrow(ratings)==length(latent$id),
          all(c('id','name','raw_average','posterior_mean') %in% names(ratings)),
          !anyDuplicated(latent$id),
          identical(as.character(latent$id), as.character(ratings$id)),
          ncol(latent$theta_draws)>=100,
          all(is.finite(latent$theta_draws)),
          is.list(params), all(c('draws','x_center') %in% names(params)))
if (!is.null(rownames(latent$theta_draws))) {
  stopifnot(identical(rownames(latent$theta_draws), as.character(latent$id)))
}

# Cross-check the Monte Carlo means against the exported summary.
mc_means <- rowMeans(latent$theta_draws)
max_discrepancy <- max(abs(mc_means - ratings$posterior_mean))
if (!is.finite(max_discrepancy) || max_discrepancy > 1e-8) {
  stop('Posterior means do not match latent draws; check for mixed-up versions. ',
       'Max difference: ', max_discrepancy)
}

if ("--validate-only" %in% commandArgs(TRUE)) {
  cat("Validated the original development handoff; no files written.\n")
  quit(save="no",status=0L)
}

dir.create(dst, recursive=TRUE, showWarnings=FALSE)
for (f in files) {
  ok <- file.copy(sources[f], file.path(dst,f), overwrite=TRUE)
  if (!ok) stop('Could not copy: ', f)
}
readme <- c(
  'STAT6106 — P5 -> P6: Preliminary ranking handoff',
  paste0('Games: ', length(latent$id)),
  paste0('Latent-rating posterior draws per game: ', ncol(latent$theta_draws)),
  'Primary file: latent_rating_draws_for_P6.rds',
  'Read it in R: obj <- readRDS("latent_rating_draws_for_P6.rds")',
  'Rows of obj$theta_draws correspond IN ORDER to obj$id and obj$name;',
  'columns are joint Monte Carlo draws of latent ratings.',
  'Use each column to rank the games, then calculate within-sample Top-10/Top-50',
  'probabilities and rank credible intervals. Do not rank each row independently.',
  'Scope: DEVELOPMENT SAMPLE ONLY (games matched to historical SD).',
  'Do NOT label these results as global BoardGameGeek Top-10 or Top-50.',
  'Model: M1a Extended using external historical SD as plug-in estimates.',
  'Important caveat: historical SD snapshot date is not independently verified.',
  'posterior_ratings_development.csv provides summary means/intervals,',
  'but ranking probabilities require latent_rating_draws_for_P6.rds.',
  'The M1a Extended reference fit has been checked on holdout; performance is not perfect.',
  'Prior sensitivity and SD sensitivity results are retained by P5 separately.'
)
writeLines(readme, file.path(dst, 'P6_README.txt'), useBytes=TRUE)

cat('PASS — P6 handoff is ready.\n')
cat('Games:', length(latent$id), '\n')
cat('Posterior draws per game:', ncol(latent$theta_draws), '\n')
cat('Largest summary discrepancy:', format(max_discrepancy, digits=3), '\n')
cat('Location:', normalizePath(dst), '\n')
cat('Files:\n'); print(list.files(dst))