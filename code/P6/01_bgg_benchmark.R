# =============================================================================
# P6 — Step 1: the BGG pseudo-vote benchmark
#
# BGG's "Geek Rating" (bayes_average) behaves like a Bayesian average that adds a
# fixed number of dummy votes at a fixed prior mean. If that number is m and the
# prior mean is C, then for a game with raw average ybar and n ratings
#
#     bayes_average = (n * ybar + m * C) / (n + m)
#
# Solving for m gives the pseudo-vote count BGG's own rule implies for each game:
#
#     m_i = n_i * (ybar_i - bayes_i) / (bayes_i - C)
#
# We then compare that with the pseudo-vote count our M1a model implies,
# m = s^2 / tau^2, whose posterior P5 already estimated.
#
# Inputs : outputs/P5/P6_Full_Handoff/P6_all_games_posterior_ratings.csv
#          outputs/P5/M1a_Baseline/parameter_draws.rds
# Outputs: outputs/P6/*.csv, figures/P6/fig_bgg_pseudovotes.png
#
# Scope  : the 21,375 SD-matched games of the cleaned 2022 snapshot, not all BGG.
# =============================================================================

suppressPackageStartupMessages(library(data.table))
source("code/P6/00_theme.R")

C_PRIOR <- 5.5          # BGG's assumed prior mean for the Geek Rating
HANDOFF <- "outputs/P5/P6_Full_Handoff/P6_all_games_posterior_ratings.csv"
M1A     <- "outputs/P5/M1a_Baseline/parameter_draws.rds"
OUTDIR  <- "outputs/P6"
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

games <- fread(HANDOFF)
cat("games in handoff:", nrow(games), "\n")

# ---------------------------------------------------------------- implied m ---
games[, m_implied := n_2022 * (raw_average - bgg_bayes_average) /
                      (bgg_bayes_average - C_PRIOR)]

# A game is usable for this decomposition only if the implied m is finite and
# positive. A non-finite or negative value means BGG's rating is not consistent
# with that game's raw average under any positive m (e.g. bayes == raw, or
# bayes on the wrong side of the prior mean).
usable <- games[is.finite(m_implied) & m_implied > 0]
excluded <- games[!is.finite(m_implied) | m_implied <= 0]

cat("usable:", nrow(usable), "| excluded:", nrow(excluded), "\n")

q <- quantile(usable$m_implied, c(0, 0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99, 1))

# ------------------------------------------------- single-m least-squares fit --
rmse_at <- function(m) {
  pred <- (usable$n_2022 * usable$raw_average + m * C_PRIOR) / (usable$n_2022 + m)
  sqrt(mean((pred - usable$bgg_bayes_average)^2))
}
grid <- seq(500, 4000, by = 1)
rmses <- vapply(grid, rmse_at, numeric(1))
m_best <- grid[which.min(rmses)]

cat(sprintf("best single m by least squares: %.0f (RMSE %.5f)\n", m_best, min(rmses)))

# How constant is the implied m across rating-count bands? A truly fixed rule
# gives the same median m in every band.
usable[, band := cut(n_2022, c(30, 100, 1000, 10000, Inf),
                     labels = c("30-99", "100-999", "1,000-9,999", "10,000+"),
                     right = FALSE)]
by_band <- usable[, .(n_games = .N,
                      median_m = median(m_implied),
                      q25_m = quantile(m_implied, 0.25),
                      q75_m = quantile(m_implied, 0.75)),
                  by = band][order(band)]

# --------------------------------------------------- our model's posterior m ---
m1a <- readRDS(M1A)$draws[, "m"]
m_post <- c(mean = mean(m1a),
            lower95 = unname(quantile(m1a, 0.025)),
            upper95 = unname(quantile(m1a, 0.975)),
            median = median(m1a))

cat(sprintf("M1a posterior m: mean %.2f (95%% %.2f-%.2f)\n",
            m_post["mean"], m_post["lower95"], m_post["upper95"]))
cat(sprintf("ratio BGG / model: %.1fx\n", m_best / m_post["mean"]))

# ------------------------------------- effective m implied by the ranking model --
# The P6 handoff draws come from the M1a EXTENDED model, not the Baseline. In that
# model both the shrinkage target and the between-game variance depend on n:
#
#   mu_i   = alpha + gamma * x_i
#   tau2_i = exp(2 * (a_tau + b_tau * x_i)),   x_i = log(n_i) - x_center
#   v_i    = sd_hist_i^2 / n_i
#
# so there is no single m. The effective per-game pseudo-vote count is the ratio of
# the observation variance to the between-game variance, evaluated draw by draw:
#
#   m_i^(b) = sd_hist_i^2 / exp(2 * (a_tau^(b) + b_tau^(b) * x_i))
#
# We take the posterior mean of m for each game, then report the median and IQR
# across games. That is the same aggregation P5 uses in
# code/P5/05_Extended_SD_sensitivity.R, so the two numbers can be compared directly.
# No game is filtered out. Draws are processed in batches to avoid a large matrix.
ext <- readRDS("outputs/P5/M1a_Extended_ExternalSD/parameter_draws.rds")
stopifnot(all(c("draws", "x_center") %in% names(ext)),
          all(c("a_tau", "alpha", "b_tau", "gamma") %in% colnames(ext$draws)),
          all(is.finite(games$sd_hist) & games$sd_hist > 0),
          all(is.finite(games$n_2022) & games$n_2022 > 0))

x_ext   <- log(games$n_2022) - ext$x_center
n_draws <- nrow(ext$draws)
acc_m   <- numeric(nrow(games))
STEP    <- 1000L
for (s in seq(1L, n_draws, by = STEP)) {
  for (j in s:min(s + STEP - 1L, n_draws)) {
    d <- ext$draws[j, ]
    tau2 <- exp(2 * (d["a_tau"] + d["b_tau"] * x_ext))
    acc_m <- acc_m + games$sd_hist^2 / tau2
  }
}
games[, m_eff := acc_m / n_draws]

eff <- games
cat(sprintf("Extended-model effective m: median %.3f (IQR %.3f-%.3f) over %d games, %d draws\n",
            median(eff$m_eff), quantile(eff$m_eff, 0.25), quantile(eff$m_eff, 0.75),
            nrow(eff), n_draws))
eff[, band := cut(n_2022, c(30, 100, 1000, 10000, Inf),
                  labels = c("30-99", "100-999", "1,000-9,999", "10,000+"),
                  right = FALSE)]
eff_by_band <- eff[, .(n_games = .N, median_m_eff = median(m_eff)), by = band][order(band)]

# ------------------------------------------------------------------ outputs ---
summary_tbl <- data.table(
  quantity = c("games_in_handoff", "games_usable", "games_excluded",
               "bgg_m_median", "bgg_m_q25", "bgg_m_q75", "bgg_m_p05", "bgg_m_p95",
               "bgg_m_best_single_fit", "bgg_m_fit_rmse",
               "model_m_mean", "model_m_lower95", "model_m_upper95",
               "ratio_bgg_over_model",
               "ranking_model_m_eff_median", "ranking_model_m_eff_q25",
               "ranking_model_m_eff_q75", "ratio_bgg_over_ranking_m"),
  value = c(nrow(games), nrow(usable), nrow(excluded),
            q[["50%"]], q[["25%"]], q[["75%"]], q[["5%"]], q[["95%"]],
            m_best, min(rmses),
            m_post["mean"], m_post["lower95"], m_post["upper95"],
            m_best / m_post["mean"],
            median(eff$m_eff), quantile(eff$m_eff, 0.25), quantile(eff$m_eff, 0.75),
            m_best / median(eff$m_eff))
)
fwrite(summary_tbl, file.path(OUTDIR, "bgg_benchmark_summary.csv"))
fwrite(by_band, file.path(OUTDIR, "bgg_implied_m_by_rating_band.csv"))
fwrite(usable[, .(id, name, n_2022, raw_average, bgg_bayes_average, m_implied)],
       file.path(OUTDIR, "bgg_implied_m_by_game.csv"))
fwrite(excluded[, .(id, name, n_2022, raw_average, bgg_bayes_average, m_implied)],
       file.path(OUTDIR, "bgg_implied_m_excluded.csv"))
fwrite(eff[, .(id, name, n_2022, raw_average, sd_hist, theta_mean, m_eff)],
       file.path(OUTDIR, "ranking_model_effective_m.csv"))
fwrite(eff_by_band, file.path(OUTDIR, "ranking_model_effective_m_by_band.csv"))

# ------------------------------------------------------------------- figure ---
# The story is a ratio of about 160x, so the x-axis is logarithmic: a linear
# axis would collapse the model value onto zero and hide the comparison.
plot_dt <- usable[m_implied > 0]
plot_dt[, log10_m := log10(m_implied)]

x_bgg   <- log10(m_best)
x_model <- log10(m_post["mean"])

p1 <- ggplot(plot_dt, aes(x = log10_m)) +
  geom_histogram(bins = 70, fill = P6_ORANGE, colour = NA, alpha = 0.85) +
  geom_vline(xintercept = x_bgg, colour = P6_ORANGE, linewidth = 0.9,
             linetype = "dashed") +
  geom_vline(xintercept = x_model, colour = P6_BLUE, linewidth = 1.2) +
  annotate("segment", x = x_model + 0.06, xend = x_bgg - 0.06,
           y = 3350, yend = 3350, colour = P6_INK2, linewidth = 0.5,
           arrow = arrow(length = unit(0.09, "inches"), ends = "both")) +
  annotate("label", x = (x_model + x_bgg) / 2, y = 3350,
           label = sprintf("%.0fx apart", m_best / m_post["mean"]),
           size = 3.4, colour = P6_INK, fill = P6_SURF, label.size = 0,
           vjust = -0.5) +
  annotate("text", x = x_model, y = 1500, hjust = -0.12, size = 3.5,
           colour = P6_BLUE,
           label = sprintf("our model\nm = %.1f", m_post["mean"])) +
  annotate("segment", x = x_bgg + 0.02, xend = 3.78, y = 2150, yend = 2150,
           colour = P6_ORANGE, linewidth = 0.4) +
  annotate("text", x = 3.84, y = 2150, hjust = 0, size = 3.5, colour = P6_ORANGE,
           label = sprintf("BGG rule\nm = %.0f", m_best)) +
  scale_x_continuous(breaks = 0:4, limits = c(0, 4.6),
                     labels = c("1", "10", "100", "1,000", "10,000")) +
  coord_cartesian(ylim = c(0, 3600)) +
  labs(
    title = "BGG's adjusted score is equivalent to about 1,870 dummy votes.\nOur model implies about 12.",
    subtitle = sprintf("Implied pseudo-vote count m for %s games (log scale); the blue line is the M1a posterior mean of m = s²/τ²",
                       format(nrow(usable), big.mark = ",")),
    x = "Implied number of dummy votes at 5.5 (m, log scale)",
    y = "Games",
    caption = "BGG rule solved from bayes_average = (n·ybar + m·5.5)/(n+m) using each game's 2022 rating count and averages.\nExcludes 681 games whose BGG rating is not consistent with any positive m (for example bayes_average equal to raw_average)."
  ) +
  theme_p6(base_size = 11) +
  theme(plot.title = element_text(size = 13, lineheight = 1.15),
        plot.subtitle = element_text(margin = margin(b = 8)),
        plot.margin = margin(10, 16, 8, 10))

save_p6(p1, "figures/P6/fig_bgg_pseudovotes.png", 9.4, 5.6)

# A second panel: is BGG's m really constant across rating counts?
# Log scale so that both ~1,800 and 11.6 are legible on the same axis.
p2 <- ggplot(by_band, aes(x = band, y = median_m)) +
  geom_errorbar(aes(ymin = q25_m, ymax = q75_m), width = 0.0,
                colour = P6_ORANGE, linewidth = 0.9) +
  geom_point(colour = P6_ORANGE, size = 3.2) +
  geom_hline(yintercept = m_post["mean"], colour = P6_BLUE, linewidth = 1.1) +
  annotate("label", x = 1, y = m_post["mean"] * 2.6,
           label = sprintf("our model: m = %.1f", m_post["mean"]),
           colour = P6_BLUE, size = 3.3, hjust = 0, fill = P6_SURF, label.size = 0) +
  scale_y_log10(breaks = c(1, 10, 100, 1000, 10000),
                labels = c("1", "10", "100", "1,000", "10,000")) +
  labs(
    title = "The implied m varies little across rating counts",
    subtitle = "Median and interquartile range of implied m within each band of n (log scale)",
    x = "Number of ratings (2022)", y = "Implied m (log scale)",
    caption = "A constant-m benchmark implies a similar median in every band. The 10,000+ band is noticeably higher, so the rule is not exactly constant."
  ) +
  theme_p6()

save_p6(p2, "figures/P6/fig_bgg_m_by_band.png", 8.4, 5)

cat("written:", OUTDIR, "and figures/P6\n")
print(summary_tbl)
