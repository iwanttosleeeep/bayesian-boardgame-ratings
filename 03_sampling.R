## ============================================================================
## 03_sampling.R
## STAT1606 Project — BoardGameGeek data
##
## Purpose : Produce the analysis samples with a fixed seed (reproducible):
##             - data_clean.csv        : full cleaned feature table
##             - dev_subsample.csv     : ~60% of games, split BY DESIGNER
##                                       (all games of a selected designer are
##                                       kept together, avoiding leakage)
##             - comparison_sample.csv : 5000 rows drawn from the complete-case
##                                       development subsample (shared by
##                                       M0 / M1a / M1b model comparisons)
## Input   : data/processed/big_features.rds   (from 02_feature_engineering.R)
## Output  : output/data_clean.csv, output/dev_subsample.csv,
##           output/comparison_sample.csv
## Run from the project root directory, e.g.:
##   Rscript script/03_sampling.R
## ============================================================================

suppressMessages(library(dplyr))

proc_dir <- file.path("data", "processed")
out_dir  <- "output"
dir.create(out_dir, showWarnings = FALSE)

big <- readRDS(file.path(proc_dir, "big_features.rds"))

## ---- 1. Development subsample: 60% of designers (grouped split) ---------------
set.seed(20261122)
designers <- unique(big$designer_id)
pick      <- sample(designers, size = round(length(designers) * 0.6))
dev_sub   <- big[big$designer_id %in% pick, ]

## ---- 2. Comparison sample: complete cases on model M1b variables ----------------
m1b_vars <- c("bayes_average", "z_log_users", "z_game_age", "z_log_play",
              "multi_designer",
              grep("^cat_",  names(big), value = TRUE),
              grep("^mech_", names(big), value = TRUE))
dev_cc  <- dev_sub[complete.cases(dev_sub[, m1b_vars]), ]
cmp_idx <- sample(nrow(dev_cc), min(5000, nrow(dev_cc)))
cmp_smp <- dev_cc[cmp_idx, ]

## ---- 3. Write outputs --------------------------------------------------------------
write.csv(big,     file.path(out_dir, "data_clean.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(dev_sub, file.path(out_dir, "dev_subsample.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(cmp_smp, file.path(out_dir, "comparison_sample.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

cat("03_sampling done\n")
cat("Total designers:", length(designers), " Selected:", length(pick), "\n")
cat("data_clean rows:", nrow(big), "\n")
cat("dev_subsample rows:", nrow(dev_sub), "\n")
cat("dev complete cases:", nrow(dev_cc), "\n")
cat("comparison_sample rows:", nrow(cmp_smp), "\n")
