args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
family <- if (length(args) >= 2) tolower(args[2]) else "negbin"
warmup <- if (length(args) >= 3) as.integer(args[3]) else 2000L
n_samples <- if (length(args) >= 4) as.integer(args[4]) else 6000L
thin <- if (length(args) >= 5) as.integer(args[5]) else 6L
n_cores <- if (length(args) >= 6) as.integer(args[6]) else 4L
stopifnot(family %in% c("poisson", "negbin"), n_cores >= 1L, n_cores <= 4L)
setwd(root)
suppressPackageStartupMessages(library(coda))
label <- if (family == "negbin") "NB" else "Poisson"
design <- readRDS("outputs/P3/M2_design.rds")
y <- design$y
X <- design$X
age <- design$age
P <- ncol(X) + 2L + as.integer(family == "negbin")
parameter_names <- c("alpha", paste0("beta[", seq_len(ncol(X)), "]"), "delta",
                     if (family == "negbin") "log_r" else NULL)
alpha_centre <- log(median(y))

evaluate <- function(par, yy, xx, aa) {
  alpha <- par[1]
  beta <- par[2:(ncol(xx) + 1L)]
  delta <- par[ncol(xx) + 2L]
  log_r <- if (family == "negbin") par[length(par)] else NA_real_
  r <- if (family == "negbin") exp(log_r) else NA_real_
  eta <- as.numeric(alpha + xx %*% beta + delta * aa)
  if (any(eta > 700 | eta < -700)) {
    return(list(log_posterior = -Inf, gradient = rep(NA_real_, length(par))))
  }
  mu <- exp(eta)
  if (family == "poisson") {
    tail_probability <- ppois(29, lambda = mu, lower.tail = FALSE)
    ll <- dpois(yy, mu, log = TRUE) -
      ppois(29, lambda = mu, lower.tail = FALSE, log.p = TRUE)
    tail_mean <- mu * (1 + dpois(29, lambda = mu) / tail_probability)
    score_eta <- yy - tail_mean
    log_prior <- dnorm(alpha, alpha_centre, 2, log = TRUE) +
      sum(dnorm(beta, 0, 1, log = TRUE)) + dnorm(delta, 0, 1, log = TRUE)
    gradient <- c(sum(score_eta) - (alpha - alpha_centre) / 4,
                  as.numeric(crossprod(xx, score_eta)) - beta,
                  sum(aa * score_eta) - delta)
  } else {
    tail_probability <- pnbinom(29, size = r, mu = mu, lower.tail = FALSE)
    ll <- dnbinom(yy, size = r, mu = mu, log = TRUE) -
      pnbinom(29, size = r, mu = mu, lower.tail = FALSE, log.p = TRUE)
    q <- mu / (r + mu)
    lower_p <- exp(r * (log(r) - log(r + mu)))
    lower_h_sum <- numeric(length(mu))
    log_p <- log(r) - log(r + mu)
    lower_h_sum <- lower_p * (log_p + mu / (r + mu))
    for (kk in 1:29) {
      lower_p <- lower_p * ((kk - 1 + r) / kk) * q
      h_k <- digamma(kk + r) - digamma(r) + log_p + (mu - kk) / (r + mu)
      lower_h_sum <- lower_h_sum + lower_p * h_k
    }
    tail_mean <- mu * (1 + ((r + 29) / r) * dnbinom(29, size = r, mu = mu) / tail_probability)
    score_eta <- r * (yy - tail_mean) / (r + mu)
    h_y <- digamma(yy + r) - digamma(r) + log_p + (mu - yy) / (r + mu)
    score_log_r <- r * sum(h_y + lower_h_sum / tail_probability)
    log_prior <- dnorm(alpha, alpha_centre, 2, log = TRUE) +
      sum(dnorm(beta, 0, 1, log = TRUE)) + dnorm(delta, 0, 1, log = TRUE) +
      dgamma(r, shape = 2, rate = 0.1, log = TRUE) + log_r
    gradient <- c(sum(score_eta) - (alpha - alpha_centre) / 4,
                  as.numeric(crossprod(xx, score_eta)) - beta,
                  sum(aa * score_eta) - delta, score_log_r + 2 - 0.1 * r)
  }
  list(log_posterior = sum(ll) + log_prior, gradient = gradient)
}

initial <- c(alpha_centre, rep(0, ncol(X)), 0, if (family == "negbin") log(20) else NULL)
names(initial) <- parameter_names
small <- 1:200
base_eval <- evaluate(initial, y[small], X[small, , drop = FALSE], age[small])
numeric_gradient <- numeric(P)
for (j in seq_len(P)) {
  step <- 1e-5 * (1 + abs(initial[j]))
  plus <- initial
  minus <- initial
  plus[j] <- plus[j] + step
  minus[j] <- minus[j] - step
  numeric_gradient[j] <- (evaluate(plus, y[small], X[small, , drop = FALSE], age[small])$log_posterior -
    evaluate(minus, y[small], X[small, , drop = FALSE], age[small])$log_posterior) / (2 * step)
}
gradient_error <- abs(base_eval$gradient - numeric_gradient)
stopifnot(max(gradient_error) < 2e-3)

objective <- function(par) {
  value <- evaluate(par, y, X, age)$log_posterior
  if (is.finite(value)) -value else 1e100
}
objective_gradient <- function(par) {
  gradient <- evaluate(par, y, X, age)$gradient
  if (all(is.finite(gradient))) -gradient else rep(0, length(par))
}
chol_solve <- function(root, v) {
  interim <- forwardsolve(t(root), v, upper.tri = FALSE)
  as.numeric(backsolve(root, interim))
}
safe_chol <- function(H) {
  scale_value <- max(abs(diag(H)), na.rm = TRUE)
  for (jitter in c(0, scale_value * 10^seq(-10, -2, by = 1))) {
    A <- H + diag(jitter, P)
    root <- tryCatch(chol(A), error = function(e) NULL)
    if (!is.null(root)) return(list(root = root, jitter = jitter))
  }
  list(root = diag(sqrt(pmax(diag(H), scale_value * 1e-6, 1e-6))), jitter = NA_real_)
}
lower <- rep(-15, P)
upper <- rep(15, P)
if (family == "negbin") {
  lower[P] <- -5
  upper[P] <- 10
}
map_par <- initial
map_par[1] <- log(mean(y))
if (family == "negbin") map_par[P] <- log(2)
map_code <- 1L
for (iteration in seq_len(30L)) {
  current <- evaluate(map_par, y, X, age)
  if (max(abs(current$gradient)) < 0.05) {
    map_code <- 0L
    break
  }
  H <- optimHess(map_par, objective, objective_gradient)
  direction <- chol_solve(safe_chol((H + t(H)) / 2)$root, current$gradient)
  if (max(abs(direction)) > 2) direction <- direction * 2 / max(abs(direction))
  accepted_step <- FALSE
  fraction <- 1
  for (line_search in seq_len(25L)) {
    candidate_par <- map_par + fraction * direction
    if (all(candidate_par >= lower & candidate_par <= upper)) {
      candidate <- evaluate(candidate_par, y, X, age)
      if (is.finite(candidate$log_posterior) && candidate$log_posterior >= current$log_posterior + 1e-9) {
        accepted_step <- TRUE
        break
      }
    }
    fraction <- fraction / 2
  }
  if (!accepted_step) break
  map_par <- candidate_par
}
map_eval <- evaluate(map_par, y, X, age)
H <- optimHess(map_par, objective, objective_gradient)
chol_result <- safe_chol((H + t(H)) / 2)
chol_information <- chol_result$root
proposal_information <- crossprod(chol_information)
information_solve <- function(v) chol_solve(chol_information, v)

fit_chain <- function(chain) {
  set.seed(42L + chain - 1L)
  current_par <- as.numeric(map_par + 0.05 * backsolve(chol_information, rnorm(P)))
  current <- evaluate(current_par, y, X, age)
  accepted <- 0L
  log_step <- log(0.2)
  warm_accepts <- integer()
  n_saved <- floor(n_samples / thin)
  draws <- matrix(NA_real_, n_saved, P, dimnames = list(NULL, parameter_names))
  saved <- 0L
  for (iter in seq_len(warmup + n_samples)) {
    step_size <- exp(log_step)
    drift <- step_size^2 / 2 * information_solve(current$gradient)
    proposal_par <- current_par + drift + step_size * backsolve(chol_information, rnorm(P))
    proposal <- evaluate(proposal_par, y, X, age)
    log_acceptance <- -Inf
    if (is.finite(proposal$log_posterior) && all(is.finite(proposal$gradient))) {
      proposal_drift <- step_size^2 / 2 * information_solve(proposal$gradient)
      forward_delta <- proposal_par - current_par - drift
      reverse_delta <- current_par - proposal_par - proposal_drift
      log_q_forward <- -0.5 * sum(forward_delta * as.numeric(proposal_information %*% forward_delta)) / step_size^2
      log_q_reverse <- -0.5 * sum(reverse_delta * as.numeric(proposal_information %*% reverse_delta)) / step_size^2
      log_acceptance <- proposal$log_posterior - current$log_posterior + log_q_reverse - log_q_forward
    }
    accept <- log(runif(1)) < min(0, log_acceptance)
    if (accept) {
      current_par <- proposal_par
      current <- proposal
    }
    if (iter <= warmup) {
      warm_accepts <- c(warm_accepts, as.integer(accept))
      if (length(warm_accepts) == 25L) {
        log_step <- max(-12, min(1, log_step + 0.25 * (mean(warm_accepts) - 0.55)))
        warm_accepts <- integer()
      }
    } else {
      accepted <- accepted + as.integer(accept)
      if ((iter - warmup) %% thin == 0L) {
        saved <- saved + 1L
        draws[saved, ] <- current_par
      }
    }
  }
  list(draws = draws, acceptance_rate = accepted / n_samples, final_step = exp(log_step))
}

export_names <- c("family", "y", "X", "age", "P", "parameter_names", "alpha_centre",
                  "evaluate", "map_par", "proposal_information", "chol_information",
                  "information_solve", "chol_solve", "warmup", "n_samples", "thin")
if (n_cores > 1L) {
  cl <- parallel::makeCluster(n_cores)
  parallel::clusterExport(cl, export_names, envir = environment())
  chain_results <- tryCatch(parallel::parLapply(cl, 1:4, fit_chain),
                            finally = parallel::stopCluster(cl))
} else {
  chain_results <- lapply(1:4, fit_chain)
}
if (family == "negbin") {
  for (chain in seq_along(chain_results)) {
    chain_results[[chain]]$draws[, "log_r"] <- exp(chain_results[[chain]]$draws[, "log_r"])
    colnames(chain_results[[chain]]$draws)[P] <- "r"
  }
}
draw_matrix <- do.call(rbind, lapply(chain_results, `[[`, "draws"))
if (family == "negbin") colnames(draw_matrix)[P] <- "r"
samples <- mcmc.list(lapply(chain_results, function(z) mcmc(z$draws)))
posterior <- list(
  draws = draw_matrix, chain = rep(1:4, each = nrow(chain_results[[1]]$draws)),
  iteration = rep(seq_len(nrow(chain_results[[1]]$draws)), 4),
  family = family, label = label, x_names = design$x_names,
  run = list(seed = 42L, chains = 4L, n_adapt = warmup, n_burn = 0L,
             n_iter_per_chain = n_samples, thin = thin,
             saved_per_chain = nrow(chain_results[[1]]$draws), total_saved = nrow(draw_matrix),
             engine = "MCMC", implementation = "Preconditioned MALA",
             source_script = "code/P3/02b_fit_M2_source.R",
             acceptance_rates = vapply(chain_results, `[[`, numeric(1), "acceptance_rate"),
             map_convergence = map_code, map_max_absolute_gradient = max(abs(map_eval$gradient)),
             gradient_max_absolute_error = max(gradient_error)),
  prior = list(beta_mean = 0, beta_precision = 1, delta_mean = 0, delta_precision = 1,
               alpha_mean = alpha_centre, alpha_precision = 0.25,
               r_shape = 2, r_rate = 0.1, r_parameterization = "log r with Jacobian")
)
saveRDS(posterior, paste0("outputs/P3/M2_", label, "_posterior.rds"), compress = "gzip")
rhat <- gelman.diag(samples, autoburnin = FALSE, multivariate = FALSE)$psrf[, 1]
ess <- effectiveSize(samples)
diagnostics <- data.frame(parameter = names(rhat), rhat = as.numeric(rhat),
                          ess = as.numeric(ess[names(rhat)]), row.names = NULL)
write.csv(diagnostics, paste0("tables/P3/M2_", label, "_convergence.csv"), row.names = FALSE)
cat(label, "finished:", nrow(draw_matrix), "draws; max R-hat", max(diagnostics$rhat),
    "min ESS", min(diagnostics$ess), "\n")
