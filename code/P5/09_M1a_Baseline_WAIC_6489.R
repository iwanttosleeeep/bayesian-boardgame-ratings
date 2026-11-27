# STAT6106 — P5 M1a Baseline on all 6,489 development games
# Purpose: prepare same-game M0/M1a/M1b WAIC inputs (NOT holdout evaluation).
# This is a SEPARATE fit: it does not modify the earlier 6,416-game analyses.
# Run all lines in RStudio (or source this file). No manual path editing needed.
# Packages required: rjags, coda, and a working JAGS installation.

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
repo_check_paths(c(repo_path("dev_subsample.csv")))

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
})

# ---- 1. Find the fixed P1 DEVELOPMENT sample; download if absent ----
out_dir <- file.path(.p5_cache, "M1a_WAIC_6489")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

candidates <- c(
  repo_path("dev_subsample.csv"),                         # GitHub project root
  file.path("output", "dev_subsample.csv"),    # original P1 R export
  file.path("data", "dev_subsample.csv"),
  file.path("..", "dev_subsample.csv")
)
existing <- candidates[file.exists(candidates)]

if (length(existing)) {
  input_path <- existing[1]
  cat("Reading local development data:", normalizePath(input_path), "\n")
} else {
  input_path <- file.path(out_dir, "input_dev_subsample.csv")
  if (!file.exists(input_path)) {
    url <- paste0(
      "https://raw.githubusercontent.com/",
      "iwanttosleeeep/bayesian-boardgame-ratings/main/dev_subsample.csv"
    )
    cat("Local CSV not found. Downloading the public P1 development sample...\n")
    old_timeout <- getOption("timeout")
    options(timeout = max(180, old_timeout))
    tryCatch(
      utils::download.file(url, destfile = input_path, mode = "wb", quiet = FALSE),
      finally = options(timeout = old_timeout)
    )
  }
  if (!file.exists(input_path)) stop("Could not obtain dev_subsample.csv")
  cat("Reading downloaded development data:", input_path, "\n")
}

dat <- read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE,
                fileEncoding = "UTF-8")
required <- c("id", "average", "users_rated")
stopifnot(all(required %in% names(dat)))
stopifnot(nrow(dat) == 6489L,
          !anyNA(dat$id), !anyDuplicated(dat$id),
          is.numeric(dat$average), is.numeric(dat$users_rated),
          all(is.finite(dat$average)),
          all(is.finite(dat$users_rated)),
          all(dat$users_rated >= 30))

ids <- dat$id
n <- dat$users_rated
y <- dat$average
N <- length(y)
input_md5 <- unname(tools::md5sum(input_path))

cat("\nCHECK: exactly", N, "unique development games.\n")
cat("CHECK: only development data are read; comparison_sample.csv is never used.\n")

# Protect a completed result from accidental overwriting.
share_path <- file.path(out_dir, "pointwise_loglik_share.rds")
if (file.exists(share_path)) {
  stop("A completed log-likelihood file already exists at: ", share_path,
       "\nDo not overwrite it. Contact me if you want to rerun.")
}

write.csv(data.frame(row = seq_len(N), id = ids),
          file.path(out_dir, "train_game_ids.csv"), row.names = FALSE)

# ---- 2. EXACT original M1a Baseline model and priors ----
# y_i ~ Normal(alpha, tau^2 + s^2/n_i), with theta_i integrated out.
# This is the same model as code/P5/02_M1a_Baseline.R; only input IDs differ.
# JAGS dnorm uses PRECISION, not variance.
model_txt <- "
model {
  for (i in 1:N) {
    prec[i] <- 1 / (tau^2 + s^2 / n[i])
    y[i] ~ dnorm(alpha, prec[i])
  }
  alpha ~ dnorm(6.4, 1)
  s ~ dunif(0.5, 3)
  tau ~ dt(0, 1, 1) T(0,)
  m <- s^2 / tau^2
}
"

inits <- lapply(1:4, function(k) {
  list(.RNG.name = "base::Mersenne-Twister",
       .RNG.seed = as.integer(20261122L + 100L + k))
})

cat("\nFitting M1a Baseline: 4 chains; adapt=1000, burn=3000, sample=3000 each.\n")
fit <- rjags::jags.model(textConnection(model_txt),
                         data = list(N = N, y = y, n = n),
                         inits = inits, n.chains = 4,
                         n.adapt = 1000, quiet = TRUE)
update(fit, n.iter = 3000, progress.bar = "none")
samples <- rjags::coda.samples(fit,
                               variable.names = c("alpha", "s", "tau", "m"),
                               n.iter = 3000, progress.bar = "none")

# ---- 3. Save posterior and diagnostics ----
draws <- as.matrix(samples)
needed_params <- c("alpha", "s", "tau", "m")
stopifnot(all(needed_params %in% colnames(draws)), all(is.finite(draws)))

rhat <- coda::gelman.diag(samples, autoburnin = FALSE,
                          multivariate = FALSE)$psrf[, "Point est."]
ess <- coda::effectiveSize(samples)
conv <- data.frame(parameter = needed_params,
                   rhat = unname(rhat[needed_params]),
                   ess = unname(ess[needed_params]))
conv$pass <- is.finite(conv$rhat) & is.finite(conv$ess) &
             conv$rhat <= 1.01 & conv$ess >= 400

param <- data.frame(
  parameter = needed_params,
  posterior_mean = unname(colMeans(draws[, needed_params, drop = FALSE])),
  lower95 = unname(apply(draws[, needed_params, drop = FALSE], 2,
                          quantile, probs = 0.025)),
  upper95 = unname(apply(draws[, needed_params, drop = FALSE], 2,
                          quantile, probs = 0.975))
)

write.csv(conv, file.path(out_dir, "convergence.csv"), row.names = FALSE)
write.csv(param, file.path(out_dir, "parameter_summary.csv"), row.names = FALSE)
saveRDS(list(draws = draws, ids = ids, model = model_txt,
             input_md5 = input_md5,
             note = "M1a Baseline, 6489 development games; separate WAIC refit"),
        file.path(out_dir, "parameter_draws.rds"), compress = TRUE)

cat("\nConvergence:\n")
print(conv, row.names = FALSE)
cat("\nPosterior:\n")
print(param, row.names = FALSE, digits = 5)
if (!all(conv$pass)) {
  warning("Convergence targets not fully met. Preserve outputs, but do not ",
          "treat this fit as validated until diagnostics are reviewed.")
}

# ---- 4. Pointwise, latent-theta-INTEGRATED log likelihood for WAIC ----
# Each row = a joint posterior draw; each column = one game in 'ids' order.
# Same kind of likelihood as P4's M1b (but M1a has no designer effect).
# Save a 500-draw subset (125 per chain) to stay small enough for GitHub upload.
per_chain <- nrow(as.matrix(samples[[1]]))
stopifnot(length(samples) == 4L,
          all(vapply(samples, function(z) nrow(as.matrix(z)), 0L) == per_chain))

B_per_chain <- 125L
within <- as.integer(round(seq(1, per_chain, length.out = B_per_chain)))
stopifnot(length(unique(within)) == B_per_chain)
pick <- unlist(lapply(0:3, function(k) k * per_chain + within),
               use.names = FALSE)
draw_index <- data.frame(chain = rep(1:4, each = B_per_chain),
                         iteration = rep(within, times = 4))

loglik <- matrix(NA_real_, nrow = length(pick), ncol = N)
for (b in seq_along(pick)) {
  d <- draws[pick[b], ]
  obs_sd <- sqrt(unname(d["tau"]^2 + d["s"]^2 / n))
  loglik[b, ] <- dnorm(y, mean = unname(d["alpha"]),
                      sd = obs_sd, log = TRUE)
}
stopifnot(all(is.finite(loglik)))
colnames(loglik) <- as.character(ids)

saveRDS(list(ids = ids, draw_index = draw_index, loglik = loglik,
             convention = paste(
               "Pointwise p(y_i | alpha,s,tau) with game theta_i integrated out;",
               "development training rows only; M1a no designer effects"
             ),
             train_md5 = input_md5),
        share_path, compress = "gzip")

# ---- 5. Small metadata file to send with diagnostics ----
metadata <- c(
  "STAT6106 P5 — M1a Baseline WAIC handoff (6489 games)",
  paste("Date:", Sys.Date()),
  paste("Input:", normalizePath(input_path, mustWork = TRUE)),
  paste("Input MD5:", input_md5),
  paste("Training games:", N),
  paste("Unique game IDs:", length(unique(ids))),
  paste("Posterior chains:", length(samples)),
  paste("Samples per chain:", per_chain),
  paste("Shared pointwise loglik matrix:", nrow(loglik), "draws x", ncol(loglik), "games"),
  paste("Shared loglik file size (MiB):",
        round(file.info(share_path)$size / 1024^2, 2)),
  paste("All convergence targets passed:", all(conv$pass)),
  "Original M1a priors: alpha~N(6.4,1^2); s~Uniform(0.5,3); tau~half-Cauchy(0,1)",
  "Likelihood: y_i~Normal(alpha, tau^2+s^2/n_i), latent theta integrated",
  "No holdout data read. Do NOT call this an out-of-sample evaluation.",
  "This is a separate 6489-game refit; original 6416-game P5 outputs unchanged.",
  "Formal cross-model WAIC is pending P2/P4 same-ID and likelihood verification."
)
writeLines(metadata, file.path(out_dir, "run_metadata.txt"))

cat("\n====== DONE ======\n")
cat(paste(metadata, collapse = "\n"), "\n")
cat("\nSEND ME THESE SMALL FILES:\n")
cat("  ", file.path(out_dir, "convergence.csv"), "\n", sep = "")
cat("  ", file.path(out_dir, "parameter_summary.csv"), "\n", sep = "")
cat("  ", file.path(out_dir, "run_metadata.txt"), "\n", sep = "")
cat("KEEP FOR LATER WAIC COMPARISON:\n")
cat("  ", share_path, "\n", sep = "")
