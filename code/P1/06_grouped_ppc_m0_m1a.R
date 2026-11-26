

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)


get_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0)
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable())
    return(dirname(normalizePath(rstudioapi::getActiveDocumentContext()$path)))
  getwd()
}

REPO_ROOT <- normalizePath(file.path(get_script_dir(), "..", ".."))  # code/P1 -> root
FIG_DIR   <- file.path(REPO_ROOT, "figures")
TAB_DIR   <- file.path(REPO_ROOT, "tables")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB_DIR, recursive = TRUE, showWarnings = FALSE)

theme_set(theme_minimal(base_size = 11))
BLUE <- "#2a78d6"; ORANGE <- "#eb6834"

set.seed(20261125)
N_DRAWS <- 500          
source(file.path(REPO_ROOT, "code", "P2", "M0_prepare.R"))
prep <- m0_prepare(file.path(REPO_ROOT, "dev_subsample.csv"))
y  <- prep$y
X  <- prep$X
ids <- prep$ids

train_ids <- as.integer(read_csv(file.path(REPO_ROOT, "outputs", "P2", "M0_train_game_ids.csv"),
                                 show_col_types = FALSE)$id)
stopifnot(identical(ids, train_ids))   # row order must match the fitted run
cat("Development games aligned:", length(ids), "\n")

dev <- read_csv(file.path(REPO_ROOT, "dev_subsample.csv"), show_col_types = FALSE) %>%
  filter(id %in% ids) %>%
  arrange(match(id, ids))              # same row order as y / X
stopifnot(identical(as.integer(dev$id), ids))
n_rated <- pmax(as.numeric(dev$users_rated), 1)   # guard against zeros

# ---- 2. Posterior draws ---------------------------------------------------
# M0: Gibbs mcmc.list -> single matrix, thinned to N_DRAWS evenly spaced draws.
gibbs <- readRDS(file.path(REPO_ROOT, "outputs", "P2", "M0_gibbs_draws.rds"))
m0_draws_all <- do.call(rbind, gibbs)            # 8000 x 8 (beta1..7, sigma2)
stopifnot(all(c(paste0("beta", 1:7), "sigma2") %in% colnames(m0_draws_all)))
pick <- round(seq(1, nrow(m0_draws_all), length.out = N_DRAWS))
m0_draws <- m0_draws_all[pick, , drop = FALSE]


m1a_draws_path <- file.path(REPO_ROOT, "archive", "outputs", "P5", "M1a_WAIC_6489",
                            "parameter_draws.rds")
stopifnot(file.exists(m1a_draws_path))   # P5 uploaded the 6,489-game refit draws
m1a_obj <- readRDS(m1a_draws_path)
# The draws must come from the same 6,489 development games, in the same row
# order as y / X; the RDS carries its own ID sequence, so verify directly.
stopifnot(identical(as.integer(m1a_obj$ids), ids))
cat("M1a draws verified against", length(ids), "development game IDs (order match)\n")
m1a_all <- m1a_obj$draws
stopifnot(all(c("alpha", "s", "tau") %in% colnames(m1a_all)))
m1a_draws <- m1a_all[round(seq(1, nrow(m1a_all), length.out = N_DRAWS)),
                     c("alpha", "s", "tau"), drop = FALSE]



simulate_m0 <- function(draws) {
  mu <- tcrossprod(draws[, paste0("beta", 1:7)], X)          # S x n
  mu + matrix(rnorm(length(mu)), nrow(mu)) * sqrt(draws[, "sigma2"])
}
simulate_m1a <- function(draws) {
  S <- nrow(draws)
  sd_mat <- sqrt(draws[, "tau"]^2 + outer(draws[, "s"]^2, 1 / n_rated))
  matrix(draws[, "alpha"], S, length(y)) +
    matrix(rnorm(S * length(y)), S) * sd_mat
}
yrep_m0  <- simulate_m0(m0_draws)
yrep_m1a <- simulate_m1a(m1a_draws)
cat("Replicate matrices:", nrow(yrep_m0), "draws x", ncol(yrep_m0), "games\n")


bands <- list(
  "30-40"    = function(n) n >= 30  & n <= 40,
  "40-100"   = function(n) n >  40  & n <  100,
  "100-200"  = function(n) n >= 100 & n <= 200,
  "200-1000" = function(n) n >  200 & n <  1000,
  "1000-5000"= function(n) n >= 1000 & n <= 5000,
  "5000+"    = function(n) n >  5000
)


cat_cols <- grep("^cat_", names(dev), value = TRUE)
top_cats <- dev %>% summarise(across(all_of(cat_cols), ~ sum(.x == 1, na.rm = TRUE))) %>%
  pivot_longer(everything(), names_to = "cat", values_to = "n") %>%
  slice_max(n, n = 8, with_ties = FALSE) %>% pull(cat)

group_index <- c(
  lapply(bands, function(f) list(grouping = "rating_count",
                                 idx = which(f(n_rated)))),
  setNames(lapply(top_cats, function(cc)
    list(grouping = "category", idx = which(dev[[cc]] == 1))),
    gsub("^cat_", "", top_cats))
)

summarise_group <- function(y_obs, yrep, idx, model, grouping, gname) {
  stopifnot(length(idx) >= 2)
  t_obs <- c(mean = mean(y_obs[idx]), var = var(y_obs[idx]))
  t_rep <- rbind(mean = rowMeans(yrep[, idx, drop = FALSE]),
                 var  = apply(yrep[, idx, drop = FALSE], 1, var))
  data.frame(
    model = model, grouping = grouping, group = gname, games = length(idx),
    observed_mean       = t_obs["mean"],
    pred_mean_median    = median(t_rep["mean", ]),
    pred_mean_low       = quantile(t_rep["mean", ], 0.025),
    pred_mean_high      = quantile(t_rep["mean", ], 0.975),
    p_mean              = mean(t_rep["mean", ] >= t_obs["mean"]),
    observed_variance   = t_obs["var"],
    pred_variance_median= median(t_rep["var", ]),
    pred_variance_low   = quantile(t_rep["var", ], 0.025),
    pred_variance_high  = quantile(t_rep["var", ], 0.975),
    p_variance          = mean(t_rep["var", ] >= t_obs["var"]),
    row.names = NULL)
}

ppc_table <- bind_rows(lapply(names(group_index), function(gn) {
  g <- group_index[[gn]]
  bind_rows(
    summarise_group(y, yrep_m0,  g$idx, "M0",  g$grouping, gn),
    summarise_group(y, yrep_m1a, g$idx, "M1a", g$grouping, gn))
}))
write_csv(ppc_table, file.path(TAB_DIR, "ppc_grouped_summary.csv"))
cat("saved ", file.path(TAB_DIR, "ppc_grouped_summary.csv"), "\n", sep = "")

plot_grouped <- function(tbl, model_name, grouping_name, file, w = 8, h = 4.8) {
  d <- tbl %>% filter(model == model_name, grouping == grouping_name) %>%
    mutate(group = factor(group, levels = unique(group)))
  p <- ggplot(d, aes(group)) +
    geom_pointrange(aes(y = pred_mean_median, ymin = pred_mean_low,
                        ymax = pred_mean_high, color = "predictive")) +
    geom_point(aes(y = observed_mean, color = "observed"), size = 2.5) +
    scale_color_manual(values = c(predictive = BLUE, observed = ORANGE),
                       name = NULL) +
    labs(title = sprintf("%s grouped PPC: mean rating by %s", model_name,
                         gsub("_", " ", grouping_name)),
         subtitle = "Points = group statistic; bars = 95% posterior predictive interval",
         x = NULL, y = "Group mean of average rating") +
    theme(legend.position = "top",
          axis.text.x = element_text(angle = 30, hjust = 1))
  ggsave(file.path(FIG_DIR, file), p, width = w, height = h, dpi = 200, bg = "white")
  cat("saved ", file.path(FIG_DIR, file), "\n", sep = "")
}

plot_density <- function(yrep, model_name, file) {
  keep <- sample(seq_len(nrow(yrep)), 50)         # 50 replicates is plenty
  dens <- data.frame(value = as.vector(yrep[keep, ]), what = "y_rep")
  obs  <- data.frame(value = y, what = "y_obs")
  p <- ggplot(bind_rows(dens, obs), aes(value, color = what, linewidth = what)) +
    geom_density() +
    scale_color_manual(values = c(y_rep = BLUE, y_obs = ORANGE), name = NULL) +
    scale_linewidth_manual(values = c(y_rep = 0.4, y_obs = 1.1), guide = "none") +
    labs(title = sprintf("%s posterior predictive density vs observed", model_name),
         subtitle = "50 replicated datasets vs observed development ratings",
         x = "Average rating (1-10)", y = "Density") +
    theme(legend.position = "top")
  ggsave(file.path(FIG_DIR, file), p, width = 8, height = 4.8, dpi = 200, bg = "white")
  cat("saved ", file.path(FIG_DIR, file), "\n", sep = "")
}

plot_grouped(ppc_table, "M0",  "rating_count", "ppc_m0_rating_count_bands.png")
plot_grouped(ppc_table, "M1a", "rating_count", "ppc_m1a_rating_count_bands.png")
plot_grouped(ppc_table, "M0",  "category", "ppc_m0_category.png",  h = 5.2)
plot_grouped(ppc_table, "M1a", "category", "ppc_m1a_category.png", h = 5.2)
plot_density(yrep_m0,  "M0",  "ppc_m0_density.png")
plot_density(yrep_m1a, "M1a", "ppc_m1a_density.png")

# ---- Variance PPC comparison: M0 vs M1a by rating-count band -----------
# Motivation for the Extended model: M0's constant residual variance
# under-predicts spread for low-count bands and over-predicts it for
# high-count bands, while M1a's tau^2 + s^2/n structure adapts with n.
plot_variance_comparison <- function(tbl, file, w = 8, h = 5) {
  d <- tbl %>%
    filter(grouping == "rating_count") %>%
    mutate(group = factor(group, levels = unique(group)))
  obs <- d %>% distinct(group, observed_variance)
  pd  <- position_dodge(width = 0.55)
  p <- ggplot(d, aes(group, color = model)) +
    geom_pointrange(aes(y = pred_variance_median, ymin = pred_variance_low,
                        ymax = pred_variance_high),
                    position = pd, size = 0.5) +
    geom_point(data = obs, aes(y = observed_variance),
               color = "black", shape = 18, size = 3.5, position = pd) +
    scale_color_manual(values = c(M0 = BLUE, M1a = ORANGE), name = NULL) +
    labs(title = "Variance PPC by rating-count band: M0 vs M1a",
         subtitle = paste0("Bars = 95% posterior predictive intervals for group variance; black diamonds = observed.\n",
                           "M0's constant variance under-predicts low-count spread and over-predicts high-count spread."),
         x = "Ratings per game", y = "Group variance of average rating") +
    theme(legend.position = "top",
          axis.text.x = element_text(angle = 30, hjust = 1))
  ggsave(file.path(FIG_DIR, file), p, width = w, height = h, dpi = 200, bg = "white")
  cat("saved ", file.path(FIG_DIR, file), "\n", sep = "")
}
plot_variance_comparison(ppc_table, "ppc_variance_comparison_rating_count.png")

cat("\n== Bayesian p-values outside [0.05, 0.95] (possible misfit) ==\n")
flag <- ppc_table %>%
  filter(p_mean < 0.05 | p_mean > 0.95 | p_variance < 0.05 | p_variance > 0.95)
if (nrow(flag) == 0) cat("none\n") else print(as.data.frame(flag), row.names = FALSE)

cat("\nDONE. Outputs in figures/ (ppc_*.png) and tables/ppc_grouped_summary.csv\n")
