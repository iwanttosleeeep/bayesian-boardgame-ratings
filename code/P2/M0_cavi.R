# ============================================================
# P2 / M0: mean-field CAVI for the SAME model as Gibbs / JAGS.
# Course: STAT6106 Group Project
#
# Model (identical to M0_functions.R):
#   y_i ~ N(x_i' beta, sigma2)
#   beta | sigma2 ~ N(0, sigma2 * V0),  V0 = v0 * I
#   1 / sigma2 = tau ~ Gamma(a0, b0)   (shape / rate)
#
# Mean-field variational family: q(beta, tau) = q(beta) * q(tau)
#   q(beta) = N(m, S)
#   q(tau)  = Gamma(a, b)              (shape / rate)
# ============================================================

# Coordinate updates (derived from E_q[log joint]):
#
# q(beta): the precision is E[tau] * (X'X + V0^{-1}), so
#     S = solve(X'X + V0^{-1}) / E[tau] = Vn / E[tau]
#     m = Vn %*% X'y                <- does NOT depend on E[tau]
#   Same Vn and beta_hat as the Gibbs sampler; only the scale differs.
#
# q(tau): shape is CONSTANT, a = a0 + (n+p)/2 (the p/2 comes from the
#   sigma2-scaled prior on beta, exactly as in the Gibbs full conditional).
#   The rate uses expectations under q(beta):
#     b = b0 + 0.5 * ( E[RSS] + E[beta' V0^{-1} beta] )
#     E[RSS]    = ||y - X m||^2 + tr(X'X S)
#     E[quad]   = m' V0^{-1} m + tr(V0^{-1} S)
#
# Because a is fixed, only b is iterated; the ELBO increases monotonically.

fit_m0_cavi <- function(y, X,
                        v0 = 100, a0 = 0.01, b0 = 0.01,
                        tol = 1e-10, max_iter = 10000, verbose = TRUE) {

  y <- as.numeric(y)
  X <- as.matrix(X)
  n <- nrow(X); p <- ncol(X)
  stopifnot(length(y) == n, n > p)

  V0_inv <- diag(1 / v0, p)
  XtX    <- crossprod(X)
  Xty    <- as.vector(crossprod(X, y))

  Vn       <- solve(XtX + V0_inv)          # same as Gibbs
  beta_hat <- as.vector(Vn %*% Xty)        # same as Gibbs

  tr_XtX_Vn  <- sum(diag(XtX %*% Vn))
  tr_V0inv_Vn <- sum(diag(V0_inv %*% Vn))
  quad_beta  <- as.numeric(crossprod(beta_hat, V0_inv %*% beta_hat))
  rss_beta   <- sum((y - as.vector(X %*% beta_hat))^2)

  logdet_V0 <- p * log(v0)                  # V0 = v0 * I

  # Variational shape is constant (same as the Gibbs tau shape).
  a <- a0 + (n + p) / 2

  #ELBO in closed form, computed from the current q parameters.
  elbo_of <- function(b) {
    E_tau  <- a / b
    E_log_tau <- digamma(a) - log(b)
    S <- Vn / E_tau                         # = Vn * b / a
    E_rss  <- rss_beta  + sum(diag(XtX %*% S))
    E_quad <- quad_beta + sum(diag(V0_inv %*% S))

    E_log_joint <-
      (n / 2 + p / 2 + a0 - 1) * E_log_tau -
      0.5 * E_tau * (E_rss + E_quad) -
      b0 * E_tau -                          # Gamma(a0,b0) prior rate term
      (n / 2) * log(2 * pi) -
      (p / 2) * log(2 * pi) -
      0.5 * logdet_V0 +
      a0 * log(b0) - lgamma(a0)

    H_beta <- 0.5 * (p * log(2 * pi * exp(1)) +
                     as.numeric(determinant(S, logarithm = TRUE)$modulus))
    H_tau  <- a - log(b) + lgamma(a) + (1 - a) * digamma(a)

    E_log_joint + H_beta + H_tau
  }

  # Fixed-point iteration on b (coordinate ascent on the ELBO).
  b <- b0 + 0.5 * (rss_beta + quad_beta)     # OLS-based starting value
  if (b <= 0) b <- 1e-6
  elbo <- elbo_of(b)
  trace_elbo <- elbo
  converged <- FALSE

  for (it in seq_len(max_iter)) {
    E_tau <- a / b
    S <- Vn / E_tau
    E_rss  <- rss_beta  + sum(diag(XtX %*% S))
    E_quad <- quad_beta + sum(diag(V0_inv %*% S))
    b_new <- b0 + 0.5 * (E_rss + E_quad)

    elbo_new <- elbo_of(b_new)
    trace_elbo <- c(trace_elbo, elbo_new)

    if (!is.finite(elbo_new)) stop("ELBO became non-finite; check the data.")

    if (abs(elbo_new - elbo) < tol) {
      b <- b_new; elbo <- elbo_new; converged <- TRUE
      break
    }
    b <- b_new; elbo <- elbo_new
  }

  S <- Vn * (b / a)                          # final q(beta) covariance
  colnames(S) <- rownames(S) <- colnames(X)

  # sigma2 = 1/tau; tau ~ Gamma(a,b) => sigma2 ~ Inv-Gamma(shape=a, scale=b)
  sigma2_mean <- b / (a - 1)                 # a > 1 here by a wide margin
  sigma2_l95  <- 1 / stats::qgamma(0.975, shape = a, rate = b)
  sigma2_u95  <- 1 / stats::qgamma(0.025, shape = a, rate = b)

  if (isTRUE(verbose)) {
    message(sprintf("CAVI done: %d iterations, converged=%s, final ELBO=%.4f",
                    length(trace_elbo) - 1L, converged, elbo))
  }

  list(
    method       = "CAVI",
    beta_mean    = beta_hat,
    beta_sd      = sqrt(diag(S)),
    beta_l95     = beta_hat - 1.96 * sqrt(diag(S)),
    beta_u95     = beta_hat + 1.96 * sqrt(diag(S)),
    cov_beta     = S,
    tau_shape    = a,
    tau_rate     = b,
    sigma2_mean  = sigma2_mean,
    sigma2_sd    = sqrt(b^2 / ((a - 1)^2 * (a - 2))),
    sigma2_l95   = sigma2_l95,
    sigma2_u95   = sigma2_u95,
    elbo         = elbo,
    elbo_trace   = trace_elbo,
    n_iter       = length(trace_elbo) - 1L,
    converged    = converged,
    n            = n,
    p            = p,
    v0           = v0, a0 = a0, b0 = b0
  )
}


# Summarise an MCMC fit (coda mcmc.list) in the same shape as fit_m0_cavi.
mcmc_summary_for_cavi <- function(mc) {
  m <- as.matrix(mc)
  p <- ncol(m) - 1L
  list(
    beta_mean   = colMeans(m[, seq_len(p), drop = FALSE]),
    beta_sd     = apply(m[, seq_len(p), drop = FALSE], 2, stats::sd),
    beta_l95    = apply(m[, seq_len(p), drop = FALSE], 2, stats::quantile, 0.025),
    beta_u95    = apply(m[, seq_len(p), drop = FALSE], 2, stats::quantile, 0.975),
    sigma2_mean = mean(m[, "sigma2"]),
    sigma2_sd   = stats::sd(m[, "sigma2"]),
    sigma2_l95  = stats::quantile(m[, "sigma2"], 0.025),
    sigma2_u95  = stats::quantile(m[, "sigma2"], 0.975)
  )
}


# Three-method comparison table: posterior means, 95% interval widths.
m0_three_method_compare <- function(gibbs, jags, cavi) {
  g <- mcmc_summary_for_cavi(gibbs)
  j <- mcmc_summary_for_cavi(jags)
  p <- length(cavi$beta_mean)
  pars <- c(paste0("beta", seq_len(p)), "sigma2")

  mean_of <- function(s, k) if (k <= p) s$beta_mean[k] else s$sigma2_mean
  sd_of   <- function(s, k) if (k <= p) s$beta_sd[k]   else s$sigma2_sd
  l_of    <- function(s, k) if (k <= p) s$beta_l95[k]  else s$sigma2_l95
  u_of    <- function(s, k) if (k <= p) s$beta_u95[k]  else s$sigma2_u95

  out <- data.frame(
    parameter      = pars,
    gibbs_mean     = vapply(seq_along(pars), function(k) mean_of(g, k), 0),
    jags_mean      = vapply(seq_along(pars), function(k) mean_of(j, k), 0),
    cavi_mean      = vapply(seq_along(pars), function(k) mean_of(cavi, k), 0),
    gibbs_sd       = vapply(seq_along(pars), function(k) sd_of(g, k), 0),
    jags_sd        = vapply(seq_along(pars), function(k) sd_of(j, k), 0),
    cavi_sd        = vapply(seq_along(pars), function(k) sd_of(cavi, k), 0),
    gibbs_width95  = vapply(seq_along(pars), function(k) u_of(g, k) - l_of(g, k), 0),
    jags_width95   = vapply(seq_along(pars), function(k) u_of(j, k) - l_of(j, k), 0),
    cavi_width95   = vapply(seq_along(pars), function(k) u_of(cavi, k) - l_of(cavi, k), 0),
    row.names = NULL
  )
  out$max_mean_gap <- apply(cbind(abs(out$gibbs_mean - out$jags_mean),
                                  abs(out$gibbs_mean - out$cavi_mean),
                                  abs(out$jags_mean  - out$cavi_mean)), 1, max)
  out$cavi_width_vs_gibbs <- out$cavi_width95 / out$gibbs_width95
  out
}
