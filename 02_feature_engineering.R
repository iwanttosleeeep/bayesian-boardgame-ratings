## ============================================================================
## 02_feature_engineering.R
## STAT6106 Project — BoardGameGeek data
## (regenerated 2026-11-21 to match the delivered pipeline and document the
##  known column artifacts in the delivered data_clean.csv)
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
## IMPORTANT — relationship to the delivered output/data_clean.csv:
##   The delivered CSV was produced by an EARLIER version of this script that
##   split tag strings on "," WITHOUT trimming whitespace. That created
##   8 artifact columns: duplicate indicators for the same tag
##   ('Card Game' x3, 'Wargame' / 'Dice Rolling' / 'Hand Management' /
##   'Set Collection' / 'Simulation' x2) and a wrongly split mechanic
##   ('Bag and Pool Building' -> mech_Bag + mech_and.Pool.Building).
##   This corrected version trims tokens, so a rerun yields a DEDUPLICATED
##   indicator set (fewer cat_*/mech_* columns than the delivered 40).
##   The delivered data_clean.csv (83 columns) remains the authoritative
##   dataset for the current report — merge the artifact columns by logical
##   OR before modelling (see data_dictionary.csv). Do NOT overwrite the
##   delivered CSV without team agreement.
## ============================================================================

suppressMessages(library(dplyr))

proc_dir <- file.path("data", "processed")
big <- readRDS(file.path(proc_dir, "big_clean.rds"))

## ---- Helper: split a comma-separated list field into clean tokens -------------
## NOTE: trimws() is the fix — the delivered data was built without it.
parse_list <- function(x) {
  x <- gsub("[\\[\\]\"']", "", as.character(x))
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
