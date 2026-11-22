## ============================================================================
## 03_sampling.R
## STAT6106 Project — BoardGameGeek data
## (regenerated 2026-11-21: implements the CORRECTED disjoint sampling scheme
##  used for the delivered dev_subsample.csv / comparison_sample.csv)
##
## Purpose : Produce the analysis samples with a fixed seed (reproducible):
##             - data_clean.csv        : full cleaned feature table
##             - dev_subsample.csv     : 30% random sample (6,489 rows),
##                                       model development & fitting
##             - comparison_sample.csv : 15% INDEPENDENT holdout (3,244 rows),
##                                       drawn FIRST, zero overlap with dev.
##                                       Reserved for posterior predictive
##                                       checks and final model comparison;
##                                       must NEVER be used for training.
## Input   : data/processed/big_features.rds   (from 02_feature_engineering.R)
## Output  : output/data_clean.csv, output/dev_subsample.csv,
##           output/comparison_sample.csv
## Run from the project root directory, e.g.:
##   Rscript script/03_sampling.R
##
## NOTES
## 1. This script REPLACES the previous scheme (60% of designers group split
##    + comparison drawn from complete cases within dev), under which
##    comparison_sample was a subset of dev_subsample and could not serve as
##    an independent holdout.
## 2. As of 2026-11-22 the delivered CSVs ARE the output of this script
##    (full pipeline rerun in R 4.5.3): same data, same code, same seed
##    reproduces dev_subsample.csv and comparison_sample.csv exactly.
## 3. The split is at row level: ~900 designer_ids appear in BOTH samples.
##    If the multilevel model (M1b) requires strict designer-group
##    separation, redraw at the designer level instead — team decision.
## ============================================================================

suppressMessages(library(dplyr))

proc_dir <- file.path("data", "processed")
out_dir  <- "output"
dir.create(out_dir, showWarnings = FALSE)

big <- readRDS(file.path(proc_dir, "big_features.rds"))

## ---- 1. Disjoint random split -------------------------------------------------
set.seed(20261122)
n       <- nrow(big)
n_comp  <- 3244   # 15% independent holdout
n_dev   <- 6489   # 30% development sample

idx      <- sample(n)
cmp_smp  <- big[idx[seq_len(n_comp)], ]
dev_sub  <- big[idx[n_comp + seq_len(n_dev)], ]

## ---- 2. Integrity checks (must always pass) --------------------------------------
stopifnot(nrow(cmp_smp) == n_comp,
          nrow(dev_sub) == n_dev,
          length(intersect(cmp_smp$id, dev_sub$id)) == 0)
cat("Row-level overlap dev vs comparison:",
    length(intersect(dev_sub$id, cmp_smp$id)), "\n")

## ---- 3. Write outputs --------------------------------------------------------------
write.csv(big,     file.path(out_dir, "data_clean.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(dev_sub, file.path(out_dir, "dev_subsample.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
write.csv(cmp_smp, file.path(out_dir, "comparison_sample.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")

cat("03_sampling done\n")
cat("data_clean rows:", nrow(big), "\n")
cat("dev_subsample rows:", nrow(dev_sub), "\n")
cat("comparison_sample rows:", nrow(cmp_smp), "(independent holdout)\n")
cat("designer_id overlap dev vs comparison:",
    length(intersect(dev_sub$designer_id, cmp_smp$designer_id)),
    "(row-level split; see NOTE 3)\n")
