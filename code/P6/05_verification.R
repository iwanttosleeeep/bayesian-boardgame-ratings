# =============================================================================
# P6 — verification of the ranking pipeline
#
# Re-derives the checks the reviewer asked for, from the saved inputs and from
# the outputs written by 02_rank_uncertainty.R. Writes a machine-readable log
# and a short markdown summary; every line is TRUE/FALSE plus the observed value.
#
# Run from the repository root, after 02_rank_uncertainty.R:
#
#     Rscript code/P6/05_verification.R
# =============================================================================

suppressPackageStartupMessages(library(data.table))

HANDOFF_DIR <- "outputs/P5/P6_Full_Handoff"
OUTDIR      <- "outputs/P6"
K           <- c(10L, 50L, 100L)

checks <- list()
add <- function(name, ok, observed) {
  checks[[length(checks) + 1L]] <<- data.table(check = name,
                                               pass = isTRUE(ok),
                                               observed = as.character(observed))
}

# ------------------------------------------------------------- input structure --
parts <- sprintf("%s/P6_theta_draws_part_%02d.rds", HANDOFF_DIR, 1:5)
first <- readRDS(parts[1])
ids <- first$id
draws <- first$theta_draws
draw_numbers <- first$draw_numbers

add("part01_rows", nrow(first$theta_draws) == 21375L, nrow(first$theta_draws))
add("part01_cols", ncol(first$theta_draws) == 100L, ncol(first$theta_draws))

same_ids <- TRUE
for (f in parts[-1]) {
  p <- readRDS(f)
  if (!identical(p$id, ids)) stop("id order differs in ", f)
  same_ids <- same_ids && identical(p$id, ids)
  add(sprintf("%s_rows", basename(f)), nrow(p$theta_draws) == 21375L, nrow(p$theta_draws))
  add(sprintf("%s_cols", basename(f)), ncol(p$theta_draws) == 100L, ncol(p$theta_draws))
  draws <- cbind(draws, p$theta_draws)
  draw_numbers <- c(draw_numbers, p$draw_numbers)
}

add("all_parts_same_id_order", same_ids, same_ids)
add("merged_rows", nrow(draws) == 21375L, nrow(draws))
add("merged_cols", ncol(draws) == 500L, ncol(draws))
add("ids_unique", !anyDuplicated(ids), length(unique(ids)))
add("draw_numbers_unique", !anyDuplicated(draw_numbers), length(draw_numbers))
add("draw_numbers_cover_1_500", setequal(draw_numbers, 1:500),
    paste(range(draw_numbers), collapse = "-"))
add("draws_all_finite", all(is.finite(draws)), sum(!is.finite(draws)))

games <- fread(file.path(HANDOFF_DIR, "P6_all_games_posterior_ratings.csv"))
add("handoff_id_order_matches_draws", identical(games$id, ids), identical(games$id, ids))

# posterior summaries from the draws must reproduce the handoff columns
theta_mean_calc <- rowMeans(draws)
theta_lo_calc   <- apply(draws, 1, quantile, 0.025)
theta_hi_calc   <- apply(draws, 1, quantile, 0.975)
add("theta_mean_matches_handoff", max(abs(theta_mean_calc - games$theta_mean)) < 1e-6,
    signif(max(abs(theta_mean_calc - games$theta_mean)), 3))
add("theta_ci_matches_handoff",
    max(abs(theta_lo_calc - games$theta_ci_lower)) < 1e-6 &&
      max(abs(theta_hi_calc - games$theta_ci_upper)) < 1e-6,
    signif(max(abs(c(theta_lo_calc - games$theta_ci_lower,
                     theta_hi_calc - games$theta_ci_upper))), 3))

# ------------------------------------------------------------------ rankings ---
R <- apply(draws, 2, function(v) rank(-v, ties.method = "average"))

# With continuous draws there should be no ties, so every draw has exactly one
# game at each rank 1..N and exactly K games inside the top K.
games_per_rank <- apply(R, 2, function(col) all(tabulate(col, nbins = nrow(R)) == 1L))
add("no_ties_within_any_draw", all(games_per_rank), sum(!games_per_rank))

for (k in K) {
  n_in_topk <- apply(R, 2, function(col) sum(col <= k))
  add(sprintf("exactly_%d_games_in_top_%d_each_draw", k, k), all(n_in_topk == k),
      paste(range(n_in_topk), collapse = "-"))
}

out <- fread(file.path(OUTDIR, "rank_uncertainty_all_games.csv"))

# The saved file is sorted by median rank; re-align to the draw order by id
# before comparing, otherwise this check compares different games.
rank_median_by_id <- apply(R, 1, median)
rank_median_aligned <- rank_median_by_id[match(out$id, ids)]
add("rank_median_matches_recomputed",
    max(abs(out$rank_median - rank_median_aligned)) < 1e-9,
    signif(max(abs(out$rank_median - rank_median_aligned)), 3))

p_top10_aligned <- rowMeans(R <= 10)[match(out$id, ids)]
add("p_top10_matches_recomputed",
    max(abs(out$p_top_10 - p_top10_aligned)) < 1e-9,
    signif(max(abs(out$p_top_10 - p_top10_aligned)), 3))

setorder(out, rank_median)
add("rank_bounds_ok",
    all(out$rank_q05 >= 1) && all(out$rank_q95 <= nrow(out)),
    paste(min(out$rank_q05), max(out$rank_q95)))
add("rank_interval_ordered",
    all(out$rank_q05 <= out$rank_q75) && all(out$rank_q75 <= out$rank_q95) &&
      all(out$rank_q05 <= out$rank_median) && all(out$rank_median <= out$rank_q95),
    "q05 <= q75 <= q95 and q05 <= median <= q95")

for (k in K) {
  col <- paste0("p_top_", k)
  add(sprintf("%s_in_unit_interval", col),
      all(out[[col]] >= 0 & out[[col]] <= 1), paste(range(out[[col]]), collapse = "-"))
  add(sprintf("%s_sums_to_%d", col, k), abs(sum(out[[col]]) - k) < 1e-8,
      signif(sum(out[[col]]), 10))
}
add("p_top10_le_p_top50", all(out$p_top_10 <= out$p_top_50 + 1e-12),
    sum(out$p_top_10 > out$p_top_50 + 1e-12))
add("p_top50_le_p_top100", all(out$p_top_50 <= out$p_top_100 + 1e-12),
    sum(out$p_top_50 > out$p_top_100 + 1e-12))

# Monte Carlo precision at B = 500: largest standard error is at p = 0.5
B <- ncol(draws)
mc_se <- sqrt(0.25 / B)

# ---------------------------------------------------------------- tie handling --
# Top-k lists are built from posterior MEDIAN rank, not from P(top k). State it,
# and check whether the k-th and (k+1)-th median ranks are ever tied.
tie_note <- character(0)
for (k in K) {
  r <- sort(out$rank_median)
  tie_note <- c(tie_note, sprintf("k=%d: median rank at k is %.1f, at k+1 is %.1f",
                                  k, r[k], r[k + 1]))
}

# --------------------------------------------------------------------- output --
log <- rbindlist(checks)
fwrite(log, file.path(OUTDIR, "rank_verification_checks.csv"))

md <- c(
  "# P6 ranking verification",
  "",
  sprintf("Generated by `code/P6/05_verification.R` on %s.", Sys.Date()),
  "",
  "| check | pass | observed |",
  "| --- | --- | --- |",
  sprintf("| %s | %s | %s |", log$check, ifelse(log$pass, "PASS", "**FAIL**"), log$observed),
  "",
  "## Conventions",
  "",
  "- Games are ranked **inside each joint posterior draw**; rank 1 is the highest latent rating.",
  "- `p_top_k` is the share of draws in which a game's rank is k or better.",
  "- The top-k lists compared with BGG are ordered by **posterior median rank**, not by `p_top_k`.",
  paste0("- Median-rank ties around the cut-off: ", paste(tie_note, collapse = "; "), "."),
  sprintf("- Monte Carlo precision at %d draws: the standard error of a probability is at most %.3f (at p = 0.5).", B, mc_se),
  "",
  sprintf("**Overall: %d of %d checks pass.**", sum(log$pass), nrow(log))
)
writeLines(md, file.path(OUTDIR, "rank_verification_checks.md"))

cat(sprintf("%d of %d checks passed\n", sum(log$pass), nrow(log)))
if (any(!log$pass)) print(log[pass == FALSE])
