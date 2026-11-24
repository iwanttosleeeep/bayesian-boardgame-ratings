args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
family <- if (length(args) >= 2) tolower(args[2]) else "negbin"
n_adapt <- if (length(args) >= 3) as.integer(args[3]) else 1000L
n_burn <- if (length(args) >= 4) as.integer(args[4]) else 1000L
n_iter <- if (length(args) >= 5) as.integer(args[5]) else 4000L
thin <- if (length(args) >= 6) as.integer(args[6]) else 4L
prior_set <- if (length(args) >= 7) args[7] else "base"
n_cores <- if (length(args) >= 8) as.integer(args[8]) else 4L
stopifnot(family %in% c("poisson", "negbin"), prior_set %in% c("base", "wide"))
setwd(root)
suppressPackageStartupMessages({library(rjags); library(coda)})
load.module("glm", quiet = TRUE)

label <- if (family == "negbin") "NB" else "Poisson"
suffix <- if (prior_set == "wide") "_wide" else ""
stem <- paste0("M2_", label, suffix)
design <- readRDS("outputs/P3/M2_design.rds")
alpha_mean <- log(median(design$y))
beta_precision <- if (prior_set == "wide") 0.25 else 1
r_shape <- if (prior_set == "wide") 1 else 2

model_lines <- c(
  "model {",
  "  for (i in 1:N) {",
  if (family == "negbin") "    y[i] ~ dnegbin(p[i], r) T(30,)" else "    y[i] ~ dpois(mu[i]) T(30,)",
  "    log(mu[i]) <- alpha + inprod(X[i, ], beta) + delta * age[i]",
  if (family == "negbin") "    p[i] <- r / (r + mu[i])" else NULL,
  "  }",
  "  alpha ~ dnorm(alpha_mean, 0.25)",
  paste0("  delta ~ dnorm(0, ", beta_precision, ")"),
  paste0("  for (j in 1:K) { beta[j] ~ dnorm(0, ", beta_precision, ") }"),
  if (family == "negbin") paste0("  r ~ dgamma(", r_shape, ", 0.1)") else NULL,
  "}"
)
model_file <- paste0("outputs/P3/", stem, ".jags")
writeLines(model_lines, model_file)

jags_data <- list(N = length(design$y), K = ncol(design$X), y = design$y,
                  X = design$X, age = design$age, alpha_mean = alpha_mean)
make_inits <- function(chain) {
  z <- list(alpha = alpha_mean, beta = rep(0, ncol(design$X)), delta = 0,
            .RNG.name = "base::Mersenne-Twister", .RNG.seed = 42L + chain - 1L)
  if (family == "negbin") z$r <- c(0.0003, 0.0007, 0.0015, 0.003)[chain]
  z
}
monitors <- c("alpha", "beta", "delta", if (family == "negbin") "r")

fit_chain <- function(chain) {
  setwd(root)
  model <- jags.model(model_file, jags_data, inits = list(make_inits(chain)),
                      n.chains = 1, n.adapt = n_adapt, quiet = TRUE)
  update(model, n_burn, progress.bar = "none")
  samples <- coda.samples(model, monitors, n.iter = n_iter, thin = thin,
                          progress.bar = "none")
  samples[[1]]
}

start <- Sys.time()
if (n_cores > 1L) {
  cl <- parallel::makeCluster(n_cores)
  invisible(parallel::clusterEvalQ(cl, {
    suppressPackageStartupMessages({library(rjags); library(coda)})
    load.module("glm", quiet = TRUE)
  }))
  parallel::clusterExport(cl, c("root", "model_file", "jags_data", "make_inits",
                                "design", "family", "alpha_mean", "n_adapt",
                                "n_burn", "n_iter", "thin", "monitors"),
                          envir = environment())
  chain_samples <- parallel::parLapply(cl, 1:4, fit_chain)
  parallel::stopCluster(cl)
} else {
  chain_samples <- lapply(1:4, fit_chain)
}
samples <- mcmc.list(chain_samples)

posterior <- list(
  draws = as.matrix(samples),
  chain = rep(1:4, each = nrow(samples[[1]])),
  iteration = rep(as.integer(time(samples[[1]])), 4),
  family = family, label = label, prior_set = prior_set, x_names = design$x_names,
  run = list(seed = 42L, chains = 4L, engine = "JAGS", cores = n_cores,
             n_adapt = n_adapt, n_burn = n_burn, n_iter_per_chain = n_iter,
             thin = thin, saved_per_chain = nrow(samples[[1]]),
             total_saved = nrow(as.matrix(samples)),
             elapsed_seconds = as.numeric(difftime(Sys.time(), start, units = "secs"))),
  prior = list(beta_precision = beta_precision, r_shape = r_shape, r_rate = 0.1)
)
saveRDS(posterior, paste0("outputs/P3/", stem, "_posterior.rds"), compress = "gzip")

rhat <- gelman.diag(samples, autoburnin = FALSE, multivariate = FALSE)$psrf[, 1]
ess <- effectiveSize(samples)
diagnostics <- data.frame(parameter = names(rhat), rhat = as.numeric(rhat),
                          ess = as.numeric(ess[names(rhat)]), row.names = NULL)
write.csv(diagnostics, paste0("tables/P3/", stem, "_convergence.csv"), row.names = FALSE)
cat(stem, "finished in", round(posterior$run$elapsed_seconds / 60, 1), "minutes\n")
cat("Max R-hat:", max(diagnostics$rhat, na.rm = TRUE),
    " Min ESS:", min(diagnostics$ess, na.rm = TRUE), "\n")
