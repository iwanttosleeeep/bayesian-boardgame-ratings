## ============================================================================
## 02_feature_engineering.R
## STAT6106 Project — BoardGameGeek data
## (regenerated 2026-11-21; parse bug fixed 2026-11-22)
##
## Purpose : Build the features promised in the proposal:
##             - category indicators  : top 20 boardgamecategory -> cat_* (0/1)
##             - mechanic indicators  : top 20 boardgamemechanic -> mech_* (0/1)
##             - designer identifiers : designer_first, designer_id (factor),
##                                      multi_designer (0/1)
##             - standardized continuous variables (mean 0, sd 1):
##                                      z_log_users, z_game_age, z_log_play
## Input   : data/processed/big_clean.rds   (from 01_data_cleaning.R)
## Output  : data/processed/big_features.rds
## Run from the project root directory, e.g.:
##   Rscript script/02_feature_engineering.R
##
## HISTORY: the first delivered data_clean.csv (2026-11-21) was produced with
##   a broken parse (default-TRE character class silently matched nothing, so
##   brackets/quotes/whitespace leaked into the tag tokens), creating duplicate
##   indicator columns (e.g. 'Card Game' x3) and splitting the mechanic
##   'Bag and Pool Building'. The 2026-11-22 rerun of the full pipeline
##   (01-04) with the fixes below produced the current clean CSV: 20 + 20
##   deduplicated indicators, 83 variables total.
## ============================================================================

suppressMessages(library(dplyr))

proc_dir <- file.path("data", "processed")
big <- readRDS(file.path(proc_dir, "big_clean.rds"))

## ---- Helper: split a comma-separated list field into clean tokens -------------
## FIXED 2026-11-22: perl = TRUE is REQUIRED — with the default TRE engine the
## character class "[\\[\\]\"']" silently matches nothing (verified on
## R 4.5.3/Windows), which is exactly how the legacy artifact columns
## (cat_X..Card.Game. etc.) were created. trimws() is the second fix.
parse_list <- function(x) {
  x <- gsub("[\\[\\]\"']", "", as.character(x), perl = TRUE)
  trimws(unlist(strsplit(x, ",")))
}

## ---- 1. Category indicators: top 20 categories -> cat_* -----------------------
cat_vec <- unlist(lapply(big$boardgamecategory, parse_list))
top_cat <- names(sort(table(cat_vec), decreasing = TRUE))[1:20]
cat("Selected categories:", top_cat, "\n")
for (v in top_cat) {
  big[[paste0("cat_", make.names(v))]] <-
    as.integer(vapply(big$boardgamecategory,
                      function(s) v %in% parse_list(s), logical(1)))
}

## ---- 2. Mechanic indicators: top 20 mechanics -> mech_* -----------------------
mech_vec <- unlist(lapply(big$boardgamemechanic, parse_list))
top_mech <- names(sort(table(mech_vec), decreasing = TRUE))[1:20]
cat("Selected mechanics:", top_mech, "\n")
for (v in top_mech) {
  big[[paste0("mech_", make.names(v))]] <-
    as.integer(vapply(big$boardgamemechanic,
                      function(s) v %in% parse_list(s), logical(1)))
}

## ---- 3. Designer identifiers ----------------------------------------------------
big$designer_first <- vapply(big$boardgamedesigner,
                             function(s) parse_list(s)[1], character(1))
big$designer_id    <- factor(big$designer_first)          # grouping factor
big$multi_designer <- as.integer(
  vapply(big$boardgamedesigner,
         function(s) length(parse_list(s)) > 1, logical(1))
)

## ---- 4. Standardized continuous variables (mean 0, sd 1) ------------------------
## NOTE on naming: z_game_age is the standardized LOG game age
## (scale of log_game_age), matching the delivered data — verified
## corr(z_game_age, log_game_age) = 1.0000 in the delivered CSV.
big$z_log_users <- as.numeric(scale(big$log_users_rated))
big$z_game_age  <- as.numeric(scale(big$log_game_age))
big$z_log_play  <- as.numeric(scale(big$log_playingtime))

## ---- 5. Save ---------------------------------------------------------------------
saveRDS(big, file.path(proc_dir, "big_features.rds"))
cat("02_feature_engineering done\n")
cat("cat_ columns:", length(grep("^cat_", names(big))), "\n")
cat("mech_ columns:", length(grep("^mech_", names(big))), "\n")
cat("multi_designer == 1 count:", sum(big$multi_designer == 1), "\n")
cat("Saved:", file.path(proc_dir, "big_features.rds"), "\n")
