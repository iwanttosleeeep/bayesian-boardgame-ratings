

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)


# Resolve paths relative to the repository root so the script runs from a
# clean clone, regardless of the working directory it is launched from.
get_script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0)
    return(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable())
    return(dirname(normalizePath(rstudioapi::getActiveDocumentContext()$path)))
  getwd()
}

REPO_ROOT <- normalizePath(file.path(get_script_dir(), "..", ".."))  # code/P1 -> repo root
DATA_DIR  <- REPO_ROOT                       # CSVs live at the repository root
FIG_DIR   <- file.path(REPO_ROOT, "figures") # committed figures location
TAB_DIR   <- file.path(REPO_ROOT, "tables")  # committed tables location
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB_DIR, recursive = TRUE, showWarnings = FALSE)

theme_set(theme_minimal(base_size = 11))
BLUE <- "#2a78d6"; ORANGE <- "#eb6834"; GREEN <- "#1baf7a"

save_fig <- function(p, name, w = 8, h = 4.8) {
  ggsave(file.path(FIG_DIR, name), p, width = w, height = h, dpi = 200, bg = "white")
  cat("saved ", file.path(FIG_DIR, name), "\n", sep = "")
}

# ---- Load data --------------------------------------------------------
df      <- read_csv(file.path(DATA_DIR, "data_clean.csv"),         show_col_types = FALSE)
dev     <- read_csv(file.path(DATA_DIR, "dev_subsample.csv"),      show_col_types = FALSE)
holdout <- read_csv(file.path(DATA_DIR, "comparison_sample.csv"),  show_col_types = FALSE)

cat("data_clean:", nrow(df), "rows | dev:", nrow(dev), "| holdout:", nrow(holdout), "\n")

# ---- 0. Descriptive summary table -------------------------------------
key_vars <- c("average", "bayes_average", "users_rated", "yearpublished",
              "minplayers", "maxplayers", "playingtime", "minage",
              "owned", "wishing", "game_age")
summary_tbl <- df %>%
  summarise(across(all_of(key_vars),
                   list(n_valid  = ~ sum(!is.na(.x)),
                        n_missing = ~ sum(is.na(.x)),
                        mean   = ~ round(mean(.x,   na.rm = TRUE), 3),
                        sd     = ~ round(sd(.x,     na.rm = TRUE), 3),
                        median = ~ round(median(.x, na.rm = TRUE), 3),
                        min    = ~ round(min(.x,    na.rm = TRUE), 3),
                        max    = ~ round(max(.x,    na.rm = TRUE), 3)),
                   .names = "{.col}___{.fn}")) %>%
  pivot_longer(everything(), names_to = c("variable", "stat"), names_sep = "___") %>%
  pivot_wider(names_from = stat, values_from = value)
write_csv(summary_tbl, file.path(TAB_DIR, "eda_descriptive_summary.csv"))
cat("saved ", file.path(TAB_DIR, "eda_descriptive_summary.csv"), "\n", sep = "")

# ---- 1. Distribution of raw average rating ----------------------------
p1 <- ggplot(df, aes(average)) +
  geom_histogram(bins = 50, fill = BLUE, color = "white", linewidth = 0.2) +
  geom_vline(xintercept = mean(df$average, na.rm = TRUE), linetype = 2, color = ORANGE) +
  labs(title = "Distribution of raw average ratings",
       subtitle = sprintf("21,631 games | mean = %.2f | dashed line = mean",
                          mean(df$average, na.rm = TRUE)),
       x = "Average rating (1-10)", y = "Number of games")
save_fig(p1, "eda_01_average_distribution.png")

# ---- 2. Distribution of rating counts (log scale) ---------------------
p2 <- ggplot(df, aes(users_rated)) +
  geom_histogram(bins = 50, fill = BLUE, color = "white", linewidth = 0.2) +
  scale_x_log10(labels = comma) +
  labs(title = "Distribution of the number of ratings per game",
       subtitle = "Strong right skew: most games have very few ratings (log scale)",
       x = "Number of users who rated the game (log10)", y = "Number of games")
save_fig(p2, "eda_02_users_rated_distribution.png")

# ---- 3. Average rating vs rating count --------------------------------
set.seed(20261122)
p3 <- ggplot(df, aes(users_rated, average)) +
  geom_point(alpha = 0.15, size = 0.7, color = BLUE) +
  geom_smooth(method = "loess", se = FALSE, color = ORANGE, linewidth = 1) +
  scale_x_log10(labels = comma) +
  labs(title = "Average rating vs number of ratings",
       subtitle = "Games with few ratings show much wider spread -- motivation for shrinkage",
       x = "Number of ratings (log10)", y = "Average rating (1-10)")
save_fig(p3, "eda_03_average_vs_users.png", w = 8, h = 5.2)

# ---- 4. BGG geek-style shrinkage: bayes_average vs average ------------
p4 <- ggplot(df, aes(average, bayes_average, color = log10(users_rated))) +
  geom_point(alpha = 0.3, size = 0.7) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, color = "grey40") +
  scale_color_viridis_c(name = "log10\nratings") +
  labs(title = "BGG bayes_average vs raw average",
       subtitle = "Points below the diagonal are pulled down toward the prior -- stronger for low-count games",
       x = "Raw average rating", y = "BGG bayes_average")
save_fig(p4, "eda_04_bayes_vs_average.png", w = 8, h = 5.2)

# ---- 5. Ratings over publication year ----------------------------------
yearly <- df %>%
  filter(!is.na(yearpublished), yearpublished >= 1950, yearpublished <= 2022) %>%
  group_by(yearpublished) %>%
  summarise(n = n(), mean_avg = mean(average, na.rm = TRUE), .groups = "drop")
p5 <- ggplot(yearly, aes(yearpublished, mean_avg)) +
  geom_point(aes(size = n), alpha = 0.35, color = BLUE) +
  geom_smooth(method = "loess", se = TRUE, color = ORANGE, linewidth = 1) +
  scale_size_continuous(range = c(0.5, 4), name = "games") +
  labs(title = "Average rating by publication year",
       subtitle = "Post-1990 games only (earlier years have very few games)",
       x = "Year published", y = "Mean average rating")
save_fig(p5, "eda_05_rating_by_year.png")

# ---- Helper: long table of indicator groups ----------------------------
indicator_long <- function(data, prefix) {
  data %>%
    select(id, average, starts_with(prefix)) %>%
    pivot_longer(cols = starts_with(prefix), names_to = "group", values_to = "flag") %>%
    filter(flag == 1) %>%
    mutate(group = gsub(paste0("^", prefix), "", group),
           group = gsub("\\.", " ", group))
}

group_plot <- function(long, title, prefix_label) {
  top <- long %>%
    group_by(group) %>%
    summarise(n = n(), mean_avg = mean(average), .groups = "drop") %>%
    filter(n >= 100) %>%
    slice_max(n, n = 12)
  ggplot(long %>% filter(group %in% top$group),
         aes(reorder(group, average, median), average)) +
    geom_boxplot(fill = BLUE, alpha = 0.6, outlier.size = 0.3, outlier.alpha = 0.2) +
    coord_flip() +
    labs(title = title,
         subtitle = "Top 12 groups by number of games (groups with >= 100 games)",
         x = prefix_label, y = "Average rating (1-10)")
}

# ---- 6. Ratings by category --------------------------------------------
cat_long <- indicator_long(df, "cat_")
p6 <- group_plot(cat_long, "Average rating by game category", "Category")
save_fig(p6, "eda_06_category_boxplot.png", w = 8, h = 5.6)

# ---- 7. Ratings by mechanic ---------------------------------------------
mech_long <- indicator_long(df, "mech_")
p7 <- group_plot(mech_long, "Average rating by game mechanic", "Mechanic")
save_fig(p7, "eda_07_mechanic_boxplot.png", w = 8, h = 5.6)

# ---- 8. Correlation heatmap of key numeric variables --------------------
cor_vars <- c("average", "bayes_average", "users_rated", "log_users_rated",
              "game_age", "playingtime_capped", "minplayers", "maxplayers_capped",
              "minage", "owned", "wishing")
cor_mat <- cor(df[, cor_vars], use = "pairwise.complete.obs")
cor_long <- as.data.frame(as.table(cor_mat))
names(cor_long) <- c("var1", "var2", "cor")
p8 <- ggplot(cor_long, aes(var1, var2, fill = cor)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", cor)), size = 2.6) +
  scale_fill_gradient2(low = "#b2182b", mid = "white", high = "#2166ac",
                       midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Correlation matrix of key numeric variables", x = NULL, y = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(p8, "eda_08_correlation_heatmap.png", w = 8.5, h = 6.5)

# ---- 9. Development vs holdout representativeness -----------------------
dev$sample     <- "Development (n = 6,489)"
holdout$sample <- "Holdout (n = 3,244)"
both <- bind_rows(dev %>% select(sample, average, users_rated),
                  holdout %>% select(sample, average, users_rated))

p9a <- ggplot(both, aes(average, fill = sample)) +
  geom_density(alpha = 0.45, color = NA) +
  scale_fill_manual(values = c(BLUE, ORANGE), name = NULL) +
  labs(title = "Average rating: development vs holdout", x = "Average rating", y = "Density") +
  theme(legend.position = "top")
p9b <- ggplot(both, aes(users_rated, fill = sample)) +
  geom_density(alpha = 0.45, color = NA) +
  scale_x_log10(labels = comma) +
  scale_fill_manual(values = c(BLUE, ORANGE), name = NULL) +
  labs(title = "Rating counts: development vs holdout",
       x = "Number of ratings (log10)", y = "Density") +
  theme(legend.position = "top")
save_fig(p9a, "eda_09a_dev_vs_holdout_average.png")
save_fig(p9b, "eda_09b_dev_vs_holdout_users.png")

cat("\nAll EDA outputs written to", FIG_DIR, "and", TAB_DIR, "\n")
