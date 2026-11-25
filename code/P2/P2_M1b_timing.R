# ============================================================
# P2 independent M1b runtime benchmark.
# Purpose: original proposal 24 Nov task -- "run P4's M1b code,
# report seconds per 1,000 iterations and computational feasibility".
#
# Uses P4's EXACT model + preprocessing (copied locally, unmodified),
# but a minimal single-chain rjags driver so it does not need the
# 'posterior' package. This is a TIMING probe, not a fitted result:
# no convergence claim is made and no posterior is delivered.
#
# Run: Rscript P2_M1b_timing.R
# ============================================================

suppressPackageStartupMessages(library(rjags))

.sd <- tryCatch(normalizePath(dirname(sys.frame(1)$ofile)), error = function(e) getwd())
if (!file.exists(file.path(.sd, "P4_M1b_prepare_local.R"))) .sd <- getwd()
setwd(.sd)

source("P4_M1b_prepare_local.R")
load.module("glm", quiet = TRUE)

DATA_PATH <- "../../data/dev_subsample.csv"
N_ADAPT   <- 200
N_BURN    <- 200
N_SAMPLE  <- 1000                 # fixed iterations for a stable rate
SEED      <- 610801L

dev <- read.csv(DATA_PATH, stringsAsFactors = FALSE)
stopifnot(nrow(dev) == 6489L, !anyDuplicated(dev$id))
prep <- m1b_prepare(dev)
d <- prep$data
cat(sprintf("M1b prep: N=%d, P=%d, J=%d designers, known=%d\n",
            d$N, d$P, d$J, sum(d$known)))

model_txt <- paste(readLines("P4_M1b_baseline_local.bug"), collapse = "\n")

set.seed(SEED)
init <- list(.RNG.name = "base::Mersenne-Twister", .RNG.seed = SEED,
             alpha = 6.4, s = 1.5, tau = 0.7, sigma_d = 0.3,
             beta = rnorm(d$P, 0, 0.03), z_u = rnorm(d$J, 0, 0.2))

# Split timing: compile+adapt+burn vs sampling, so we report the
# per-iteration sampling cost (the number P4 needs for scale decisions).
t_warm <- system.time({
  jm <- jags.model(textConnection(model_txt), data = d, inits = init,
                   n.chains = 1, n.adapt = N_ADAPT, quiet = TRUE)
  if (N_BURN > 0) update(jm, N_BURN, progress.bar = "none")
})
t_sample <- system.time(
  mc <- coda.samples(jm, variable.names = c("alpha", "tau", "s", "sigma_d"),
                     n.iter = N_SAMPLE, thin = 1, progress.bar = "none")
)

warm_s   <- unname(t_warm[["elapsed"]])
sample_s <- unname(t_sample[["elapsed"]])
per_1000 <- 1000 * sample_s / N_SAMPLE
cat(sprintf("Warm-up (compile+adapt+burn %d+%d): %.2f s\n",
            N_ADAPT, N_BURN, warm_s))
cat(sprintf("Sampling %d iterations: %.2f s\n", N_SAMPLE, sample_s))
cat(sprintf(">>> M1b sampling rate: %.2f seconds per 1,000 iterations (1 chain, this machine)\n",
            per_1000))
cat("Machine: single chain, R 4.5.1, JAGS 4.3.2, glm module,",
    "6,489 games, 4 parallel chains in P4's full run.\n")

out <- data.frame(
  owner = "P2 independent",
  model = "M1b",
  games = d$N,
  predictors = d$P,
  designers = d$J,
  chains = 1L,
  adapt = N_ADAPT, burn = N_BURN, sample_iter = N_SAMPLE,
  warmup_seconds = warm_s,
  sample_seconds = sample_s,
  seconds_per_1000_iter = per_1000,
  engine = "JAGS glm via rjags, single chain",
  note = "timing probe only; no convergence claim; posterior package not required",
  row.names = NULL
)
write.csv(out, "../../tables/M1b_P2_timing_probe.csv", row.names = FALSE)
cat("Saved tables/M1b_P2_timing_probe.csv\n")
