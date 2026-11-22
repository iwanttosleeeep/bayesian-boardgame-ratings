# ============================================================
# P2 / M0: Bayesian baseline regression -- core functions
# Course: STAT6106 Group Project
# Model (Proposal, "M0: baseline regression"):
#   y_i ~ N(x_i' beta, sigma2)
#   beta | sigma2 ~ N(0, sigma2 * V0),  V0 = 100 * I
#   1 / sigma2    ~ Gamma(a0, b0),      a0 = b0 = 0.01
# Two fitters are provided: a hand-written Gibbs sampler and JAGS.
# All draws are returned as coda::mcmc.list so downstream owners
# (P1 for PPC, P5 for WAIC) can use them directly.
# ============================================================

# ------------------------------------------------------------
# 1. Hand-written Gibbs sampler
#
# WHY GIBBS IS CLOSED-FORM HERE (the "conjugate" trick):
# Both the likelihood and the prior on beta carry the SAME 1/sigma2
# factor. That makes the full conditionals standard distributions,
# so each Gibbs step is just one draw from a normal / gamma -- no
# Metropolis tuning, no proposal acceptance.
#
# Let tau = 1 / sigma2 (precision). Derive the two full conditionals:
#
# (a) beta | y, sigma2:
#     posterior precision = X'X / sigma2 + V0^{-1} / sigma2
#                         = (X'X + V0^{-1}) / sigma2
#     => Vn   = solve(X'X + V0^{-1})                [does not depend on sigma2]
#        beta_hat = Vn %*% X'y
#     => beta | y, sigma2 ~ N(beta_hat, sigma2 * Vn)
#
# (b) tau | y, beta:
#     Accumulate the exponents from likelihood, prior on beta, prior on tau.
#     Because Var(beta | sigma2) = sigma2 * V0, the prior on beta contributes
#     a tau^{p/2} term and a beta'V0^{-1}beta term. Hence
#     tau | y, beta ~ Gamma( a0 + (n+p)/2 ,
#                             b0 + (RSS + beta'V0^{-1}beta)/2 )
#     where RSS = (y - X beta)'(y - X beta).   [Gamma is shape/rate]
#
# NOTE the (n+p)/2 and the extra quadratic beta'V0^{-1}beta: these are the
# parts people most often get wrong. They come from the sigma2-scaled prior.
# ------------------------------------------------------------
fit_m0_gibbs <- function(y, X,
                         v0 = 100, a0 = 0.01, b0 = 0.01,
                         n_chains = 4, n_iter = 12000, n_burn = 2000,
                         thin = 5, seed = 42, verbose = TRUE) {

  y <- as.numeric(y)
  X <- as.matrix(X)
  n <- nrow(X); p <- ncol(X)
  stopifnot(length(y) == n, n > p)

  V0_inv <- diag(1 / v0, p)          # V0 = v0 * I  =>  V0^{-1} = I / v0
  XtX    <- crossprod(X)             # X'X  (compute ONCE, outside the loop)
  Xty    <- as.vector(crossprod(X, y))

  Vn       <- solve(XtX + V0_inv)    # posterior covariance factor (a)
  beta_hat <- as.vector(Vn %*% Xty)  # posterior mean factor (a)

  # chol(Vn) returns upper R with t(R) %*% R = Vn.
  # Let A = t(R). For z ~ N(0,I), Cov(A %*% z) = A %*% t(A) = t(R) %*% R = Vn.
  chol_factor <- t(chol(Vn))         # p x p

  set.seed(seed)
  keep <- floor((n_iter - n_burn) / thin)
  chain_list <- vector("list", n_chains)

  for (c in seq_len(n_chains)) {
    # Overdispersed starts help the R-hat diagnostic be meaningful.
    beta <- beta_hat + rnorm(p, sd = 1)
    tau  <- stats::rgamma(1, shape = a0, rate = b0)
    out  <- matrix(NA_real_, nrow = keep, ncol = p + 1)
    colnames(out) <- c(paste0("beta", seq_len(p)), "sigma2")

    k <- 0L
    for (it in seq_len(n_iter)) {
      # --- (a) draw beta | y, sigma2 (~ sigma2 * Vn) ---
      z    <- rnorm(p)
      beta <- beta_hat + sqrt(1 / tau) * as.vector(chol_factor %*% z)

      # --- (b) draw tau | y, beta (shape/rate gamma) ---
      resid <- y - as.vector(X %*% beta)
      RSS   <- sum(resid^2)
      quad  <- as.numeric(crossprod(beta, V0_inv %*% beta))  # beta'V0^{-1}beta
      tau   <- stats::rgamma(1,
                             shape = a0 + (n + p) / 2,
                             rate  = b0 + (RSS + quad) / 2)

      # --- store after burn-in, with thinning ---
      if (it > n_burn && (it - n_burn) %% thin == 0) {
        k <- k + 1L
        out[k, ] <- c(beta, 1 / tau)
      }
    }
    chain_list[[c]] <- coda::as.mcmc(out)
  }

  if (isTRUE(verbose)) {
    message(sprintf("Gibbs done: %d chains x %d kept draws (thin=%d).",
                    n_chains, keep, thin))
  }
  coda::as.mcmc.list(chain_list)
}


# ------------------------------------------------------------
# 2. JAGS implementation of the SAME model.
# Key JAGS gotcha: dnorm takes PRECISION, not variance.
#   beta[k] variance = sigma2 * V0_kk = V0_kk / tau
#   => precision     = tau / V0_kk  = tau / v0   (since V0 = v0 * I)
#   dnorm(mu, tau): tau is precision of y, correct.
# dgamma(a0, b0) in JAGS is shape/rate, matching the Gibbs code.
# ------------------------------------------------------------
fit_m0_jags <- function(y, X,
                        v0 = 100, a0 = 0.01, b0 = 0.01,
                        n_chains = 4, n_iter = 12000, n_burn = 2000,
                        thin = 5, seed = 42, verbose = TRUE) {

  if (!requireNamespace("rjags", quietly = TRUE)) {
    stop("Package 'rjags' (and the JAGS runtime) is required for the JAGS fit.")
  }

  y <- as.numeric(y); X <- as.matrix(X)
  n <- nrow(X); p <- ncol(X)
  jags_data <- list(y = y, X = X, n = n, p = p,
                    v0 = v0, a0 = a0, b0 = b0)

  model_txt <- "
  model {
    for (i in 1:n) {
      mu[i] <- inprod(X[i, 1:p], beta[1:p])
      y[i]  ~ dnorm(mu[i], tau)
    }
    for (k in 1:p) {
      beta[k] ~ dnorm(0, tau / v0)     # precision = tau / v0
    }
    tau    ~ dgamma(a0, b0)            # shape/rate
    sigma2 <- 1 / tau
  }
  "

  inits <- lapply(seq_len(n_chains), function(i) {
    list(.RNG.name = "base::Mersenne-Twister",
         .RNG.seed = seed + i,
         beta = as.numeric(rnorm(p)),
         tau  = stats::rgamma(1, shape = 2, rate = 1))
  })

  jm <- rjags::jags.model(textConnection(model_txt), data = jags_data,
                          inits = inits, n.chains = n_chains, quiet = !verbose)
  stats::update(jm, n.iter = n_burn)
  rjags::coda.samples(jm, variable.names = c("beta", "sigma2"),
                      n.iter = (n_iter - n_burn), thin = thin)
}


# ------------------------------------------------------------
# 3. Convergence diagnostics shared by both fitters.
# Proposal targets: R-hat <= 1.01, ESS >= 400 for reported quantities.
# ------------------------------------------------------------
m0_diagnostics <- function(mc, label = "M0") {
  psrf <- coda::gelman.diag(mc, autoburnin = FALSE, multivariate = FALSE)$psrf
  ess  <- coda::effectiveSize(mc)
  list(
    model    = label,
    rhat     = psrf[, "Point est."],
    rhat_max = max(psrf[, "Point est."]),
    ess_min  = min(ess),
    ess      = ess
  )
}


# ------------------------------------------------------------
# 4. Pointwise log-likelihood for WAIC (needed by P5).
# For each posterior draw s and observation i:
#   log p(y_i | beta^s, tau^s) = dnorm(y_i, x_i'beta^s, sd = sqrt(1/tau^s), log = TRUE)
# Returns an (n_draws x n_obs) matrix. Save as .rds for P5.
# NOTE: use the likelihood integrated over beta is NOT needed for M0 -- M0 has
# no latent theta; this is already the pointwise likelihood for WAIC.
# ------------------------------------------------------------
m0_pointwise_loglik <- function(mc, y, X) {
  mat  <- as.matrix(mc)                    # rows = draws, cols = beta..., sigma2
                                           # as.matrix() is base R, not coda::
  p    <- ncol(X)
  beta <- as.matrix(mat[, seq_len(p), drop = FALSE])
  eta  <- beta %*% t(X)                    # n_draws x n_obs
  ymat <- matrix(y, nrow = nrow(beta), ncol = length(y), byrow = TRUE)
  # R matrices are column-major: element (i,j) is draw i. So replicate each
  # draw's sigma2 `times = n_obs` (NOT each=), matching the column layout.
  sd   <- sqrt(rep(mat[, "sigma2"], times = length(y)))
  -0.5 * log(2 * pi) - log(sd) - (ymat - eta)^2 / (2 * sd^2)
}


# ------------------------------------------------------------
# 5. Side-by-side comparison table (JAGS vs Gibbs).
# ------------------------------------------------------------
m0_compare <- function(mc_gibbs, mc_jags) {
  # Compute summary statistics directly from the draws. Do NOT rely on
  # summary()$statistics column names: coda versions label the 2.5% column
  # differently (e.g. "2.5%" vs "2.50%"), which causes subscript errors.
  stats_from_draws <- function(mc) {
    m <- as.matrix(mc)                # rows = draws, cols = parameters
    data.frame(
      mean = colMeans(m),
      sd   = apply(m, 2, stats::sd),
      l95  = apply(m, 2, stats::quantile, 0.025),
      u95  = apply(m, 2, stats::quantile, 0.975)
    )
  }
  g <- stats_from_draws(mc_gibbs)
  j <- stats_from_draws(mc_jags)
  # JAGS names vector elements "beta[1]"; hand-written uses "beta1".
  # Match by POSITION, not by name.
  stopifnot(nrow(g) == nrow(j))
  pars <- colnames(as.matrix(mc_gibbs))
  data.frame(
    parameter  = pars,
    gibbs_mean = g$mean, jags_mean = j$mean,
    gibbs_sd   = g$sd,   jags_sd   = j$sd,
    gibbs_l95  = g$l95,  gibbs_u95 = g$u95,
    jags_l95   = j$l95,  jags_u95  = j$u95,
    mean_diff  = abs(g$mean - j$mean),
    row.names  = NULL
  )
}
