# P5 / Model A — ORIGINAL intercept-only M1a baseline
# Reconstructed from the 2026-11-21 R/JAGS model recorded in the conversation.
# This is a reproduction script, NOT evidence that a new fit has been run.
# Uses the FULL original TidyTuesday ratings.csv (~21,831 games).
# DO NOT compare its WAIC/ELPD directly with fits on the 6,416-game SD-matched sample.

library(rjags)
library(coda)

dir.create("P5_Model_A_original", showWarnings = FALSE, recursive = TRUE)

url <- paste0(
  "https://raw.githubusercontent.com/rfordatascience/tidytuesday/",
  "main/data/2022/2022-01-25/ratings.csv"
)
ratings <- if (file.exists("ratings.csv")) {
  read.csv("ratings.csv")
} else {
  read.csv(url)
}
stopifnot(all(c("average", "users_rated") %in% names(ratings)))
dat <- ratings[
  is.finite(ratings$average) &
  is.finite(ratings$users_rated) &
  ratings$users_rated >= 30,
]
cat("Original full-sample games:", nrow(dat), "\n")

# Original Model A: constant mean and constant between-game SD.
model_A <- "
model {
  for (i in 1:N) {
    precision[i] <- 1 / (tau^2 + s^2 / n[i])
    y[i] ~ dnorm(alpha, precision[i])
  }
  alpha ~ dnorm(6.4, 1)
  s ~ dunif(0.5, 3)
  tau ~ dt(0, 1, 1) T(0,)
  m <- s^2 / tau^2
}
"

set.seed(6106)
jags_data <- list(N=nrow(dat), y=dat$average, n=dat$users_rated)
fit_A <- jags.model(
  textConnection(model_A), data=jags_data,
  n.chains=4, n.adapt=1000
)
update(fit_A, 3000)
samples_A <- coda.samples(
  fit_A,
  variable.names=c("alpha", "s", "tau", "m"),
  n.iter=5000
)

summary(samples_A)
gelman.diag(samples_A, multivariate=FALSE)
effectiveSize(samples_A)

mat <- as.matrix(samples_A)
summary_A <- data.frame(
  parameter=colnames(mat),
  mean=colMeans(mat),
  lower95=apply(mat, 2, quantile, 0.025),
  upper95=apply(mat, 2, quantile, 0.975),
  row.names=NULL
)
write.csv(summary_A, "P5_Model_A_original/parameter_summary.csv", row.names=FALSE)
saveRDS(samples_A, "P5_Model_A_original/parameter_draws.rds")

# Grouped PPC; all games and the four original rating-count bands.
set.seed(42)
n <- dat$users_rated
y <- dat$average
groups <- list(
  "30-40"=which(n >= 30 & n <= 40),
  "100-200"=which(n >= 100 & n <= 200),
  "1000-5000"=which(n >= 1000 & n <= 5000),
  "5000+"=which(n > 5000)
)
B <- 500L
idx_draw <- sample(seq_len(nrow(mat)), B, replace=FALSE)
ppc_rows <- list()
for (g in names(groups)) {
  ii <- groups[[g]]
  simulated_means <- numeric(B)
  simulated_vars <- numeric(B)
  for (b in seq_len(B)) {
    d <- mat[idx_draw[b], ]
    y_rep <- rnorm(length(ii), mean=d["alpha"],
                   sd=sqrt(d["tau"]^2+d["s"]^2/n[ii]))
    simulated_means[b] <- mean(y_rep)
    simulated_vars[b] <- var(y_rep)
  }
  for (stat in c("mean", "variance")) {
    rep <- if (stat=="mean") simulated_means else simulated_vars
    observed <- if (stat=="mean") mean(y[ii]) else var(y[ii])
    ppc_rows[[length(ppc_rows)+1]] <- data.frame(
      group=g, games=length(ii), statistic=stat,
      observed=observed, predicted_median=median(rep),
      lower95=unname(quantile(rep,.025)),
      upper95=unname(quantile(rep,.975))
    )
  }
}
write.csv(do.call(rbind,ppc_rows),
          "P5_Model_A_original/grouped_PPC.csv",row.names=FALSE)

# Original A is for documenting the baseline and misspecification;
# the Model D with external SD is a later extension, NOT a replacement for A.
