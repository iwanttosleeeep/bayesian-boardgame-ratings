args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
setwd(root)
set.seed(42)

design <- readRDS("outputs/P3/M2_design.rds")
y <- design$y
X <- design$X
age <- design$age
N <- length(y)
posts <- list(Poisson = readRDS("outputs/P3/M2_Poisson_posterior.rds"),
              NB = readRDS("outputs/P3/M2_NB_posterior.rds"))

select_draws <- function(post, n_each = 1000) {
  unlist(lapply(1:4, function(chain) {
    index <- which(post$chain == chain)
    index[unique(round(seq(1, length(index), length.out = n_each)))]
  }))
}

get_mu <- function(post, index) {
  d <- post$draws[index, , drop = FALSE]
  beta <- grep("^beta\\[", colnames(d))
  eta <- d[, "alpha"] %o% rep(1, N) + d[, "delta"] %o% age +
    d[, beta, drop = FALSE] %*% t(X)
  exp(eta)
}

get_loglik <- function(post, index) {
  cache <- paste0("outputs/P3/M2_", post$label, "_pointwise_loglik.rds")
  if (file.exists(cache)) {
    ll <- readRDS(cache)
    expected_index <- select_draws(post)
    expected_index <- expected_index[order(expected_index)]
    if (nrow(ll) == length(expected_index) && ncol(ll) == N &&
        identical(index, expected_index) && all(is.finite(ll))) return(ll)
  }
  mu <- get_mu(post, index)
  yy <- matrix(y, length(index), N, byrow = TRUE)
  if (post$family == "negbin") {
    r <- post$draws[index, "r"]
    ll <- dnbinom(yy, size = r, mu = mu, log = TRUE) -
      pnbinom(29, size = r, mu = mu, lower.tail = FALSE, log.p = TRUE)
  } else {
    ll <- dpois(yy, mu, log = TRUE) -
      ppois(29, mu, lower.tail = FALSE, log.p = TRUE)
  }
  stopifnot(all(is.finite(ll)))
  if (length(index) == nrow(post$draws)) {
    saveRDS(ll, paste0("outputs/P3/M2_", post$label, "_pointwise_loglik.rds"),
            compress = "xz")
  }
  ll
}

get_loglik_split <- function(post, index) {

  cache <- paste0("outputs/P3/M2_", post$label, "_pointwise_loglik.rds")
  if (file.exists(cache)) {
    ll <- tryCatch(readRDS(cache), error = function(e) NULL)
    if (!is.null(ll) && nrow(ll) == length(index) && ncol(ll) == N && all(is.finite(ll))) {
      message("Using cached ", post$label, " log likelihood")
      return(ll)
    }
    unlink(cache)
  }
  blocks <- split(index, ceiling(seq_along(index) / 100L))

  result <- vector("list", length(blocks))
  for (block in seq_along(blocks)) {
    message(post$label, " log likelihood block ", block, "/", length(blocks))
    result[[block]] <- get_loglik(post, blocks[[block]])
    gc()
  }
  ll <- do.call(rbind, result)
  if (nrow(ll) == nrow(post$draws)) saveRDS(ll, cache, compress = "xz")
  ll
}

waic_one <- function(ll) {


  center <- apply(ll, 2, max)
  elpd <- center + log(colMeans(exp(sweep(ll, 2, center, "-"))))
  penalty <- apply(ll, 2, var)
  data.frame(waic = -2 * sum(elpd - penalty), p_waic = sum(penalty),
             n = ncol(ll), posterior_draws = nrow(ll))
}

dic_one <- function(post, ll, index) {
  d <- colMeans(post$draws[index, , drop = FALSE])
  beta <- grep("^beta\\[", names(d))
  mu <- as.numeric(exp(d["alpha"] + X %*% d[beta] + age * d["delta"]))
  if (post$family == "negbin") {
    ll_mean <- dnbinom(y, size = d["r"], mu = mu, log = TRUE) -
      pnbinom(29, size = d["r"], mu = mu, lower.tail = FALSE, log.p = TRUE)
  } else {
    ll_mean <- dpois(y, mu, log = TRUE) -
      ppois(29, mu, lower.tail = FALSE, log.p = TRUE)
  }
  d_bar <- mean(-2 * rowSums(ll))
  d_at_mean <- -2 * sum(ll_mean)
  p_dic <- d_bar - d_at_mean
  data.frame(d_bar = d_bar, d_at_posterior_mean = d_at_mean,
             p_dic = p_dic, dic = d_bar + p_dic)
}

indices <- lapply(posts, select_draws)
loglik <- Map(get_loglik_split, posts, indices)
waic <- do.call(rbind, Map(function(label, ll) {

  cbind(model = label, waic_one(ll))
}, names(loglik), loglik))
waic$delta_waic <- waic$waic - min(waic$waic)
write.csv(waic, "tables/P3/M2_WAIC.csv", row.names = FALSE)

dic <- do.call(rbind, Map(function(label, post, ll, index) {
  cbind(model = label, dic_one(post, ll, index))
}, names(posts), posts, loglik, indices))
dic$delta_dic <- dic$dic - min(dic$dic)
write.csv(dic, "tables/P3/M2_DIC.csv", row.names = FALSE)

elpd <- function(ll) {
  center <- apply(ll, 2, max)
  center + log(colMeans(exp(sweep(ll, 2, center, "-"))))
}
difference <- elpd(loglik$NB) - elpd(loglik$Poisson)
comparison <- data.frame(
  comparison = "NB minus Poisson",
  delta_elpd = sum(difference),
  delta_waic = waic$waic[waic$model == "NB"] - waic$waic[waic$model == "Poisson"],
  se_delta_waic = 2 * sqrt(N * var(difference))
)
write.csv(comparison, "tables/P3/M2_WAIC_difference.csv", row.names = FALSE)

dictionary <- read.csv("outputs/P3/M2_parameter_dictionary.csv", check.names = FALSE)
labels <- setNames(dictionary$label, dictionary$parameter)
terms <- setNames(dictionary$term, dictionary$parameter)
for (label in names(posts)) {
  d <- posts[[label]]$draws
  out <- data.frame(
    model = label, parameter = colnames(d),
    term = unname(terms[colnames(d)]), label = unname(labels[colnames(d)]),
    posterior_mean = colMeans(d), posterior_sd = apply(d, 2, sd),
    q025 = apply(d, 2, quantile, 0.025), median = apply(d, 2, median),
    q975 = apply(d, 2, quantile, 0.975), row.names = NULL
  )
  conv <- read.csv(paste0("tables/P3/M2_", label, "_convergence.csv"))
  out$rhat <- conv$rhat[match(out$parameter, conv$parameter)]
  out$ess <- conv$ess[match(out$parameter, conv$parameter)]
  write.csv(out, paste0("tables/P3/M2_", label, "_posterior_summary.csv"), row.names = FALSE)
  effects <- out[!out$parameter %in% c("alpha", "r"), ]
  effects$rr_q025 <- exp(effects$q025)
  effects$rr_median <- exp(effects$median)
  effects$rr_q975 <- exp(effects$q975)
  write.csv(effects, paste0("tables/P3/M2_", label, "_effects.csv"), row.names = FALSE)
}

stats <- function(v) c(
  exact_30 = mean(v == 30), band_30_39 = mean(v >= 30 & v <= 39),
  at_least_1000 = mean(v >= 1000), at_least_10000 = mean(v >= 10000),
  at_least_50000 = mean(v >= 50000), variance_mean_ratio = var(v) / mean(v),
  median = median(v), q90 = quantile(v, 0.9, names = FALSE),
  q99 = quantile(v, 0.99, names = FALSE), maximum = max(v)
)

for (label in names(posts)) {
  post <- posts[[label]]
  available <- indices[[label]]
  index <- available[unique(round(seq(1, length(available), length.out = 50)))]
  ppc_cache <- paste0("outputs/P3/M2_", label, "_ppc_replicates.rds")
  if (file.exists(ppc_cache)) {
    cached <- readRDS(ppc_cache)
    if (nrow(cached) == 50L && ncol(cached) == N && all(is.finite(cached))) {
      yrep <- cached
    }
  }
  if (!exists("yrep")) {
    mu <- get_mu(post, index)
    yrep <- matrix(NA_real_, length(index), N)
  }
  for (s in seq_along(index)) {
    if (all(is.finite(yrep[s, ]))) next
    if (post$family == "negbin") {
      r <- post$draws[index[s], "r"]
      lower <- pnbinom(29, size = r, mu = mu[s, ])
      yrep[s, ] <- qnbinom(runif(N, lower, 1), size = r, mu = mu[s, ])
    } else {
      lower <- ppois(29, mu[s, ])
      yrep[s, ] <- qpois(runif(N, lower, 1), mu[s, ])
    }
  }
  simulated <- t(apply(yrep, 1, stats))
  tab <- data.frame(
    model = label, statistic = colnames(simulated), observed = stats(y),
    predictive_mean = colMeans(simulated),
    predictive_q025 = apply(simulated, 2, quantile, 0.025),
    predictive_q975 = apply(simulated, 2, quantile, 0.975), row.names = NULL
  )
  saveRDS(yrep, paste0("outputs/P3/M2_", label, "_ppc_replicates.rds"), compress = "xz")
  write.csv(tab, paste0("tables/P3/M2_", label, "_PPC.csv"), row.names = FALSE)

  png(paste0("figures/P3/M2_", label, "_ppc_summary.png"),
      width = 2200, height = 1500, res = 300)
  par(mfrow = c(1, 2), mar = c(7, 4.5, 3, 1))
  shown <- tab[tab$statistic %in% c("exact_30", "band_30_39", "at_least_1000",
                                    "at_least_10000", "at_least_50000"), ]
  x <- seq_len(nrow(shown))
  plot(x, shown$observed, pch = 19, xaxt = "n", xlab = "", ylab = "Proportion",
       ylim = c(0, max(shown$predictive_q975, shown$observed) * 1.1),
       main = "Observed and predicted proportions")
  axis(1, x, c("30", "30-39", ">=1k", ">=10k", ">=50k"), las = 2)
  segments(x, shown$predictive_q025, x, shown$predictive_q975)
  probs <- seq(0.1, 0.99, 0.1)
  predicted <- apply(yrep, 1, quantile, probs = probs, names = FALSE)
  plot(quantile(y, probs), rowMeans(predicted), log = "xy", pch = 19,
       xlab = "Observed quantile", ylab = "Predicted quantile", main = "Count quantiles")
  abline(0, 1, lty = 2)
  dev.off()
}

nb <- read.csv("tables/P3/M2_NB_effects.csv")
selected <- nb[nb$term %in% c("z_log_play", "z_minplayers", "z_maxplayers",
                              "z_minage", "z_game_age", "multi_designer"), ]
significant <- nb[nb$q025 * nb$q975 > 0, ]
top <- significant[order(-abs(significant$posterior_mean)), ][1:6, ]
forest <- unique(rbind(selected, top))
forest <- forest[order(forest$posterior_mean), ]
png("figures/P3/M2_NB_effects_forest.png", width = 2800, height = 1900, res = 300)
par(mar = c(5, 15, 3, 1))
plot(forest$posterior_mean, seq_len(nrow(forest)), pch = 19, yaxt = "n", ylab = "",
     xlim = range(c(forest$q025, forest$q975, 0)),
     xlab = "Log rate ratio with 95% credible interval", main = "NB feature associations")
axis(2, seq_len(nrow(forest)), forest$label, las = 1, cex.axis = 0.7)
arrows(forest$q025, seq_len(nrow(forest)), forest$q975, seq_len(nrow(forest)),
       angle = 90, code = 3, length = 0.03)
abline(v = 0, lty = 2)
dev.off()

for (label in names(posts)) {
  post <- posts[[label]]
  pars <- c("alpha", "delta", if (label == "NB") "r")
  png(paste0("figures/P3/M2_", label, "_trace.png"), width = 2200, height = 1500, res = 300)
  par(mfrow = c(length(pars), 1), mar = c(3, 4, 2, 1))
  for (p in pars) {
    plot(NA, xlim = range(post$iteration), ylim = range(post$draws[, p]),
         xlab = "Saved iteration", ylab = p, main = paste(label, p))
    for (chain in 1:4) {
      use <- post$chain == chain
      lines(post$iteration[use], post$draws[use, p], col = chain)
    }
  }
  dev.off()
}

cat("Analysis finished. WAIC table:\n")
print(waic[, c("model", "waic", "delta_waic", "p_waic")])
cat("DIC table:\n")
print(dic[, c("model", "dic", "delta_dic", "p_dic")])
