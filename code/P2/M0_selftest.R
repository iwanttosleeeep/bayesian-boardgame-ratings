# ============================================================
# M0 self-test - one file only. No packages, no data needed.
# How to run: open in RStudio -> Ctrl+A -> Ctrl+Enter
# Goal: check whether the hand-written Gibbs sampler is correct.
# Result: if the last lines say "CORRECT", you are done.
# ============================================================

cat("\n========== START SELF-TEST ==========\n\n")

# -----------------------------------------------------------
# STEP 1: Make fake data. We hide the answers on purpose.
# -----------------------------------------------------------
# We secretly set the true beta = (6.4, 0.5, -0.3) and noise = 0.9.
# Later the algorithm will guess them. If its guesses are close
# to these numbers, the code is right. If not, the code is wrong.

set.seed(42)                       # same random numbers every run
n <- 600                           # make 600 rows

beta_true  <- c(6.4, 0.5, -0.3)    # the hidden answers
sigma_true <- 0.9                  # noise size

X <- cbind(
  rep(1, n),    # column 1: all ones (intercept)
  rnorm(n),     # column 2: random numbers
  rnorm(n)      # column 3: random numbers
)

# Build y from the answers, then add a bit of noise
y <- as.vector(X %*% beta_true) + rnorm(n, sd = sigma_true)

cat("Fake data ready:", n, "rows\n")
cat("Hidden answers: beta = (", paste(round(beta_true, 2), collapse = ", "), ")\n\n", sep = "")


# -----------------------------------------------------------
# STEP 2: Hand-written Gibbs (the core algorithm)
# -----------------------------------------------------------
# In plain words: the algorithm keeps guessing the answer,
# thousands of times. Each round = guess beta, then guess noise.
# After many rounds we average the guesses. That average is our answer.
# Why does this work? Math proves that this process slowly moves
# toward the true answer.

v0 <- 100       # two tuning knobs, use the defaults for now
a0 <- 0.01
b0 <- 0.01

n_iter <- 12000 # total guesses
n_burn <- 2000  # ignore the first 2000 (still "warming up")
thin   <- 5     # save one guess out of every 5

p <- ncol(X)                          # 3 betas to guess
V0_inv <- diag(1 / v0, p)             # fixed quantity, compute once
Vn <- solve(crossprod(X) + V0_inv)    # inverse of (X'X + V0 inverse)
beta_hat <- as.vector(Vn %*% crossprod(X, y))
A <- t(chol(Vn))                      # shape used to draw random noise

set.seed(42)
beta_now <- beta_hat + rnorm(p)       # start anywhere
tau_now  <- 1                         # tau = 1 / (noise^2)

# A box to store the guesses we keep
keep <- floor((n_iter - n_burn) / thin)
draws <- matrix(NA_real_, nrow = keep, ncol = p + 1)
colnames(draws) <- c("beta1", "beta2", "beta3", "sigma2")

k <- 0
for (i in 1:n_iter) {

  # --- guess beta ---
  # start at beta_hat and wobble a little; wobble size depends on noise
  beta_now <- beta_hat + sqrt(1 / tau_now) * as.vector(A %*% rnorm(p))

  # --- guess noise ---
  # see how far this beta is from the real data (RSS):
  # farther away => larger estimated noise
  resid <- y - as.vector(X %*% beta_now)
  RSS   <- sum(resid^2)
  quad  <- as.numeric(crossprod(beta_now, V0_inv %*% beta_now))
  tau_now <- rgamma(1,
                    shape = a0 + (n + p) / 2,
                    rate  = b0 + (RSS + quad) / 2)

  # --- after warm-up, save one guess every 5 rounds ---
  if (i > n_burn && (i - n_burn) %% thin == 0) {
    k <- k + 1
    draws[k, ] <- c(beta_now, 1 / tau_now)
  }
}

cat("Done. Saved", keep, "guesses\n\n")


# -----------------------------------------------------------
# STEP 3: Check the answers - are the guesses near the truth?
# -----------------------------------------------------------
cat("========== CHECK ANSWERS ==========\n")
cat(sprintf("%-10s %10s %12s %16s\n", "param", "truth", "estimated", "95% interval"))
cat("--------------------------------------------------------\n")

for (j in 1:p) {
  m  <- mean(draws[, j])
  lo <- quantile(draws[, j], 0.025)
  hi <- quantile(draws[, j], 0.975)
  cat(sprintf("%-10s %10.3f %12.3f  [%.3f, %.3f]\n",
              paste0("beta", j), beta_true[j], m, lo, hi))
}

m_s  <- mean(draws[, "sigma2"])
lo_s <- quantile(draws[, "sigma2"], 0.025)
hi_s <- quantile(draws[, "sigma2"], 0.975)
cat(sprintf("%-10s %10.3f %12.3f  [%.3f, %.3f]\n",
            "sigma2", sigma_true^2, m_s, lo_s, hi_s))
cat("--------------------------------------------------------\n\n")

# Are all true values inside their 95% intervals?
ok <- all(beta_true >= apply(draws[, 1:p], 2, quantile, 0.025) &
          beta_true <= apply(draws[, 1:p], 2, quantile, 0.975)) &&
      (sigma_true^2 >= lo_s) && (sigma_true^2 <= hi_s)

if (ok) {
  cat(">>> CORRECT: every true value is inside its 95% interval.\n")
  cat(">>> Your task for tonight is finished.\n\n")
} else {
  cat(">>> WARNING: at least one true value fell outside its 95% interval.\n")
  cat(">>> Take a screenshot and send it to me.\n\n")
}

# Plot: distribution of the guesses for beta1; red line = truth
hist(draws[, 1], breaks = 40, col = "lightblue",
     main = "beta1 guesses (red line = truth)",
     xlab = "value")
abline(v = beta_true[1], col = "red", lwd = 2)

cat("Plot is ready. The red line (truth) should sit in the middle of the blue bars.\n")
cat("========== END SELF-TEST ==========\n")

