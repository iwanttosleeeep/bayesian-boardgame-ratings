# This gate uses synthetic data only, never development or holdout outcomes.
suppressPackageStartupMessages({library(rjags); library(coda)})
out <- "outputs/P4/smoke"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
model <- "model { for (i in 1:N) { y[i] ~ dnorm(mu, 1) } mu ~ dnorm(0, 0.01) }"
synthetic <- c(-1, 0, 1, 0.5, -0.5)
inits <- lapply(1:2, function(k) list(.RNG.name = "base::Mersenne-Twister",
                                    .RNG.seed = 610600L + k))
fit <- jags.model(textConnection(model), list(N = length(synthetic), y = synthetic),
                  inits = inits, n.chains = 2, n.adapt = 100, quiet = TRUE)
update(fit, 100, progress.bar = "none")
smp <- coda.samples(fit, "mu", n.iter = 200, progress.bar = "none")
stopifnot(all(is.finite(as.matrix(smp))), nrow(as.matrix(smp)) == 400L)
expected_mean <- sum(synthetic)/(length(synthetic) + 0.01)
expected_sd <- sqrt(1/(length(synthetic) + 0.01))
z <- as.matrix(smp)[,"mu"]
stopifnot(abs(mean(z) - expected_mean) < 0.2,
          sd(z) > 0.7*expected_sd, sd(z) < 1.3*expected_sd)
versions <- c(R.version.string, paste("JAGS", jags.version()),
               paste("rjags", packageVersion("rjags")),
               paste("coda", packageVersion("coda")),
               "PASS: synthetic Normal model compiled and sampled",
               "PASS: posterior mean/SD agree with conjugate calculation within smoke tolerance",
               paste("Synthetic posterior mean:", mean(z)),
               paste("Synthetic posterior SD:", sd(z)),
               paste("JAGS_HOME:", Sys.getenv("JAGS_HOME")),
               paste("Package library:", .libPaths()[1]))
writeLines(versions, file.path(out, "environment_verified.txt"))
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat(paste(versions, collapse = "\n"), "\n")
