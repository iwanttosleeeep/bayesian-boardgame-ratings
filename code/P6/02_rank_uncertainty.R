# =============================================================================
# P6 — Step 2: ranking uncertainty under posterior shrinkage
#
# P5 exports 500 joint posterior draws of each game's latent rating theta, split
# across five RDS parts (21,375 games x 100 draws each). Because the draws are
# JOINT within a replicate, ranking must be done inside each column: game A is
# ranked against game B using the same draw. Ranking once on the posterior mean
# would ignore the correlation between games and understate the uncertainty in
# the ordering.
#
# For each game we report the posterior distribution of its rank:
#   - median rank and 5th/95th percentile rank (a 90% credible rank interval)
#   - P(top 10), P(top 50), P(top 100) = share of joint draws in which the game
#     falls in that band
# and we compare the resulting order with BGG's own adjusted rating.
#
# Inputs : outputs/P5/P6_Full_Handoff/P6_theta_draws_part_0{1..5}.rds
#          outputs/P5/P6_Full_Handoff/P6_all_games_posterior_ratings.csv
# Outputs: outputs/P6/rank_uncertainty_all_games.csv
#          outputs/P6/top10_posterior_probabilities.csv
#          outputs/P6/rank_vs_bgg_summary.csv
#          figures/P6/fig_*.png
#
# Scope and caveats (from the P5 handoff README):
#   - Ranking scope is the 21,375 SD-matched games of the cleaned 2022 snapshot,
#     NOT all games on BGG.
#   - theta conditions on each game's own observed average and rating count, so
#     these are within-sample latent estimates, not holdout predictions.
#   - bgg_bayes_average and bgg_rank are benchmarks, not model inputs.
# =============================================================================

suppressPackageStartupMessages(library(data.table))
source("code/P6/00_theme.R")

HANDOFF_DIR <- "outputs/P5/P6_Full_Handoff"
OUTDIR      <- "outputs/P6"
dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------- load and align draws --
parts <- sprintf("%s/P6_theta_draws_part_%02d.rds", HANDOFF_DIR, 1:5)
stopifnot(all(file.exists(parts)))

first <- readRDS(parts[1])
ids   <- first$id
names_ <- first$name
draws <- first$theta_draws
draw_numbers <- first$draw_numbers

for (f in parts[-1]) {
  p <- readRDS(f)
  if (!identical(p$id, ids)) stop("game ids differ in ", f)
  draws <- cbind(draws, p$theta_draws)
  draw_numbers <- c(draw_numbers, p$draw_numbers)
}

stopifnot(length(unique(draw_numbers)) == ncol(draws))
cat(sprintf("assembled %d games x %d joint draws from %d parts\n",
            nrow(draws), ncol(draws), length(parts)))
stopifnot(!anyNA(draws))

# ------------------------------------------------------------ rank per draw ---
# rank 1 = highest latent rating. Ties are broken by averaging, but the draws
# are continuous so ties are effectively absent.
cat("ranking within each of", ncol(draws), "joint draws ...\n")
R <- apply(draws, 2, function(v) rank(-v, ties.method = "average"))

ranks <- data.table(
  id   = ids,
  name = names_,
  rank_median = apply(R, 1, median),
  rank_mean   = rowMeans(R),
  rank_q05    = apply(R, 1, quantile, 0.05),
  rank_q95    = apply(R, 1, quantile, 0.95),
  rank_q25    = apply(R, 1, quantile, 0.25),
  rank_q75    = apply(R, 1, quantile, 0.75),
  p_top_10    = rowMeans(R <= 10),
  p_top_50    = rowMeans(R <= 50),
  p_top_100   = rowMeans(R <= 100)
)

games <- fread(file.path(HANDOFF_DIR, "P6_all_games_posterior_ratings.csv"))
stopifnot(identical(games$id, ids))          # same order in both files

out <- merge(ranks, games[, .(id, n_2022, raw_average, bgg_bayes_average,
                              bgg_rank, theta_mean, theta_ci_lower,
                              theta_ci_upper, shrinkage)],
             by = "id", sort = FALSE)

# ------------------------------------------------------- comparison with BGG --
# bgg_rank is the site-wide rank, which includes games outside our 21,375.
# For a like-for-like comparison we re-rank BGG's adjusted score WITHIN the same
# set of games we ranked.
out[, rank_bgg_adjusted := frank(-bgg_bayes_average, ties.method = "average")]
out[, rank_gap := rank_median - rank_bgg_adjusted]

spearman_rho <- cor(out$rank_median, out$rank_bgg_adjusted, method = "spearman")

top10_model <- out[order(rank_median)][1:10]
top10_bgg   <- out[order(rank_bgg_adjusted)][1:10]
top10_overlap <- length(intersect(top10_model$id, top10_bgg$id))

top50_model <- out[order(rank_median)][1:50]
top50_bgg   <- out[order(rank_bgg_adjusted)][1:50]
top50_overlap <- length(intersect(top50_model$id, top50_bgg$id))

cat(sprintf("Spearman(our median rank, BGG adjusted rank) = %.3f\n", spearman_rho))
cat(sprintf("Top-10 overlap: %d/10 | Top-50 overlap: %d/50\n",
            top10_overlap, top50_overlap))

# How wide is the 90% rank interval? Report it for the whole ranking and for
# games that are plausible top-10 candidates.
median_width <- median(out$rank_q95 - out$rank_q05)
top_width <- median(out[p_top_10 > 0.05, rank_q95 - rank_q05])

summary_tbl <- data.table(
  quantity = c("games_ranked", "joint_draws", "spearman_vs_bgg_adjusted",
               "top10_overlap", "top50_overlap",
               "median_90pct_rank_interval_width",
               "median_90pct_width_top10_candidates",
               "games_with_p_top10_above_005"),
  value = c(nrow(out), ncol(draws), spearman_rho, top10_overlap, top50_overlap,
            median_width, top_width, sum(out$p_top_10 > 0.05))
)

# ------------------------------------------------------------------ outputs ---
setorder(out, rank_median)
fwrite(out, file.path(OUTDIR, "rank_uncertainty_all_games.csv"))

fwrite(out[order(-p_top_10)][1:30, .(id, name, rank_median, rank_q05, rank_q95,
                                     p_top_10, p_top_50, rank_bgg_adjusted,
                                     bgg_bayes_average, theta_mean)],
       file.path(OUTDIR, "top10_posterior_probabilities.csv"))

fwrite(summary_tbl, file.path(OUTDIR, "rank_vs_bgg_summary.csv"))
print(summary_tbl)

# ------------------------------------------------------------------- figures ---
# Long product names overrun the device, so wrap them onto two lines.
wrap_name <- function(x, width = 40) {
  vapply(x, function(s) paste(strwrap(s, width = width), collapse = "\n"),
         character(1), USE.NAMES = FALSE)
}


# Fig 3: probability of being in the top 10, for the 20 most likely games.
top20 <- out[order(-p_top_10)][1:20]
top20[, name := factor(wrap_name(name), levels = rev(wrap_name(name)))]
p3 <- ggplot(top20, aes(x = p_top_10, y = name)) +
  geom_col(fill = P6_BLUE, width = 0.68) +
  geom_text(aes(label = sprintf("%.0f%%", 100 * p_top_10)), hjust = -0.15,
            size = 3.1, colour = P6_INK2) +
  scale_x_continuous(labels = scales::percent, limits = c(0, 1.08),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(title = "How likely is each game to be ranked in the top 10?",
       subtitle = "Share of 500 joint draws in which the game ranks in the top 10 of 21,375",
       x = "P(top 10)", y = NULL,
       caption = "Ranks are computed within each joint draw, so the ordering is internally consistent.") +
  theme_p6()
save_p6(p3, "figures/P6/fig_top10_probability.png", 11, 7)

# Fig 4: 90% rank intervals for the 15 games with the best median rank.
top15 <- out[order(rank_median)][1:15][order(-rank_median)]
top15[, name := factor(wrap_name(name), levels = wrap_name(name))]
p4 <- ggplot(top15, aes(y = name)) +
  geom_segment(aes(x = rank_q05, xend = rank_q95, yend = name),
               colour = P6_BLUE, linewidth = 2.6, alpha = 0.35) +
  geom_point(aes(x = rank_median), colour = P6_BLUE, size = 2.6) +
  geom_point(aes(x = rank_bgg_adjusted), colour = P6_ORANGE, shape = 4,
             size = 2.6, stroke = 0.9) +
  scale_x_log10() +
  labs(title = "Rank intervals for the 15 highest-ranked games",
       subtitle = "Blue: posterior median and 90% rank interval. Orange x: BGG's adjusted-score rank for the same game.",
       x = "Rank among 21,375 games (log scale)", y = NULL,
       caption = "A narrow interval means the position is well determined; a wide one means it depends on which draw you look at.") +
  theme_p6()
save_p6(p4, "figures/P6/fig_rank_intervals.png", 11, 6.6)

# Fig 5: our order against BGG's, on the same games.
p5 <- ggplot(out, aes(x = rank_bgg_adjusted, y = rank_median)) +
  geom_abline(slope = 1, intercept = 0, colour = P6_MUTED, linewidth = 0.6) +
  geom_point(alpha = 0.18, size = 0.7, colour = P6_BLUE) +
  scale_x_log10(breaks = c(1, 10, 100, 1000, 10000)) +
  scale_y_log10(breaks = c(1, 10, 100, 1000, 10000)) +
  labs(title = "Our shrunk ranking against BGG's adjusted rating",
       subtitle = sprintf("Spearman %.2f on the same %s games; grey line is perfect agreement",
                          spearman_rho, format(nrow(out), big.mark = ",")),
       x = "Rank by BGG adjusted score (log scale)",
       y = "Median posterior rank (log scale)",
       caption = "Both orderings are computed within this set of games only.") +
  theme_p6()
save_p6(p5, "figures/P6/fig_rank_vs_bgg.png", 8, 6)

cat("written:", OUTDIR, "and figures/P6\n")
