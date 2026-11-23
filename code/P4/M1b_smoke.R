# Authorized 400-game spike: runtime/implementation evidence, not final results.
# Run from repository root using code/P4/run_local.ps1.
options(warn = 1)
suppressPackageStartupMessages({library(rjags); library(coda)})
source("code/P4/M1b_prepare.R")
out <- "outputs/P4/smoke"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(file.path(out, "environment_verified.txt")))

dev_path <- "dev_subsample.csv"
dat <- read.csv(dev_path, stringsAsFactors = FALSE, check.names = FALSE,
                fileEncoding = "UTF-8")
stopifnot(nrow(dat) == 6489L, !anyDuplicated(dat$id))
set.seed(42)
dat <- dat[sample.int(nrow(dat), 400L), , drop = FALSE]
prep <- m1b_prepare(dat)
write.csv(data.frame(id = prep$ids), file.path(out, "train_game_ids.csv"), row.names = FALSE)
write.csv(data.frame(term = colnames(prep$data$X),
                     prior_sd = 1/sqrt(prep$data$beta_prec)),
          file.path(out, "design_columns.csv"), row.names = FALSE)
saveRDS(prep$recipe, file.path(out, "preprocessing.rds"))

# Check replay and unseen/anonymous design handling without reading holdout.
replay <- m1b_prepare(dat, prep$recipe)
stopifnot(identical(prep$data$X, replay$data$X))
probe <- dat[1:3, , drop = FALSE]
probe$designer_id <- c("P4_SYNTHETIC_UNSEEN_DESIGNER", NA, "(Uncredited)")
probe$minage[1] <- NA
pp <- m1b_prepare(probe, prep$recipe)
stopifnot(all(pp$data$known == 0), all(is.finite(pp$data$X)),
          identical(prep$recipe, pp$recipe))
lc <- m1b_latent(y = c(7,7), n = c(30,3000), mu = 6,
                  tau = 0.8, s = 2, sigma_d = 0.4, known = c(1,1))
stopifnot(all(lc$mean > 6 & lc$mean < 7), all(lc$sd > 0),
          lc$weight[1] < lc$weight[2], lc$sd[2] < lc$sd[1])

seeds <- 42L + 1:4
inits <- lapply(seeds, function(seed) list(
  .RNG.name = "base::Mersenne-Twister", .RNG.seed = seed,
  alpha = 6.4, s = 1.5, tau = 0.8, sigma_d = 0.3,
  beta = rep(0, prep$data$P), z_u = rep(0, prep$data$J)))
model_path <- "code/P4/M1b_baseline.bug"
elapsed <- system.time({
  fit <- jags.model(model_path, data = prep$data, inits = inits,
                    n.chains = 4, n.adapt = 1000, quiet = TRUE)
  update(fit, 1000, progress.bar = "none")
  samples <- coda.samples(fit, c("alpha", "beta", "s", "tau", "sigma_d", "u"),
                          n.iter = 1000, progress.bar = "none")
})
draws <- as.matrix(samples)
stopifnot(nrow(draws) == 4000L, all(is.finite(draws)))
psrf <- gelman.diag(samples, multivariate = FALSE, autoburnin = FALSE)$psrf
ess <- effectiveSize(samples)
conv <- data.frame(parameter = colnames(draws), rhat = psrf[, "Point est."],
                   ess = unname(ess[colnames(draws)]), row.names = NULL)
write.csv(conv, file.path(out, "convergence.csv"), row.names = FALSE)
quant <- t(apply(draws, 2, quantile, c(.025, .5, .975)))
summ <- data.frame(parameter = colnames(draws), mean = colMeans(draws),
                   lower95 = quant[,1], median = quant[,2], upper95 = quant[,3],
                   row.names = NULL)
write.csv(summ, file.path(out, "parameter_summary.csv"), row.names = FALSE)
saveRDS(list(samples = samples, ids = prep$ids, recipe = prep$recipe,
             model = readLines(model_path), input_md5 = tools::md5sum(dev_path),
             chain_seeds = seeds), file.path(out, "smoke_draws.rds"))

set.seed(610604)
pick <- sample.int(nrow(draws), 100)
theta <- matrix(NA_real_, nrow(dat), length(pick))
ll <- matrix(NA_real_, length(pick), nrow(dat))
for (b in seq_along(pick)) {
  z <- draws[pick[b], ]
  bet <- z[paste0("beta[", seq_len(prep$data$P), "]")]
  u <- z[paste0("u[", prep$data$designer, "]")]
  mu <- as.numeric(z["alpha"] + prep$data$X %*% bet + prep$data$known*u)
  conditional <- m1b_latent(dat$average, dat$users_rated, mu,
                           z["tau"], z["s"], z["sigma_d"], prep$data$known)
  theta[, b] <- rnorm(nrow(dat), conditional$mean, conditional$sd)
  marginal_sd <- sqrt(z["tau"]^2 + (1-prep$data$known)*z["sigma_d"]^2 +
                        z["s"]^2/dat$users_rated)
  ll[b, ] <- dnorm(dat$average, mu, marginal_sd, log = TRUE)
}
stopifnot(all(is.finite(theta)), all(is.finite(ll)))
rownames(theta) <- as.character(dat$id)
colnames(ll) <- as.character(dat$id)
saveRDS(list(id = dat$id, theta_draws = theta, loglik = ll,
             note = "SMOKE ONLY; theta-integrated, designer-conditional loglik"),
        file.path(out, "latent_and_loglik.rds"))
key <- !grepl("^u\\[", conv$parameter)
checks <- c("Status: completed implementation/runtime smoke; NOT a final model fit",
  paste("Training games:", nrow(dat)), paste("Predictors:", prep$data$P),
  paste("Named designers:", length(prep$recipe$designers)),
  paste("Unknown designer games:", sum(prep$data$known == 0)),
  paste("Elapsed seconds:", unname(elapsed["elapsed"])),
  paste("Max R-hat, all monitored parameters:", max(conv$rhat)),
  paste("Min ESS, all monitored parameters:", min(conv$ess)),
  paste("Max R-hat, coefficients and scales:", max(conv$rhat[key])),
  paste("Min ESS, coefficients and scales:", min(conv$ess[key])),
  paste("R-hat <=1.01 AND ESS >=400 for ALL:",
        all(conv$rhat <= 1.01 & conv$ess >= 400)),
  "Passed: recipe replay, finite imputation, unseen/anonymous designer probe, latent shrinkage direction",
  "Passed: finite parameter/latent/loglik draws; game IDs saved",
  "No holdout file was read; no WAIC or holdout performance claimed",
  paste("Development MD5:", unname(tools::md5sum(dev_path))))
writeLines(checks, file.path(out, "smoke_summary.txt"))
cat(paste(checks, collapse = "\n"), "\n")
