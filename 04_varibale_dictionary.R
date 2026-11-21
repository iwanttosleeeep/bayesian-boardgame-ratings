## ============================================================================
## 04_data_dictionary.R
## STAT1606 Project — BoardGameGeek data
##
## Purpose : Generate data_dictionary.csv documenting every variable in the
##           final feature table: name, description, missing-value count.
## Input   : data/processed/big_features.rds   (from 02_feature_engineering.R)
## Output  : output/data_dictionary.csv
## Run from the project root directory, e.g.:
##   Rscript script/04_data_dictionary.R
## ============================================================================

proc_dir <- file.path("data", "processed")
out_dir  <- "output"
dir.create(out_dir, showWarnings = FALSE)

big <- readRDS(file.path(proc_dir, "big_features.rds"))

desc <- data.frame(variable = character(),
                   description = character(),
                   stringsAsFactors = FALSE)
add_desc <- function(var, txt) {
  desc <<- rbind(desc, data.frame(variable = var, description = txt))
}

## ---- Original variables ---------------------------------------------------------
add_desc("id", "BoardGameGeek game ID (primary key)")
add_desc("primary", "Primary name indicator")
add_desc("description", "Game description text")
add_desc("yearpublished", "Year published; values outside 1900-2022 set to NA")
add_desc("minplayers", "Minimum number of players; 0 treated as missing")
add_desc("maxplayers", "Maximum number of players; 0 treated as missing, capped at 36")
add_desc("playingtime", "Playing time in minutes; 0 treated as missing, capped at 600")
add_desc("minplaytime", "Minimum playing time in minutes")
add_desc("maxplaytime", "Maximum playing time in minutes")
add_desc("minage", "Minimum recommended age for players; 0 treated as missing")
add_desc("boardgamecategory", "Comma-separated list of categories")
add_desc("boardgamemechanic", "Comma-separated list of mechanics")
add_desc("boardgamefamily", "Comma-separated list of families")
add_desc("boardgameexpansion", "Comma-separated list of expansions")
add_desc("boardgameimplementation", "Comma-separated list of implementations")
add_desc("boardgamedesigner", "Comma-separated list of designers")
add_desc("boardgameartist", "Comma-separated list of artists")
add_desc("boardgamepublisher", "Comma-separated list of publishers")
add_desc("owned", "Number of owners")
add_desc("trading", "Number of traders")
add_desc("wanting", "Number of people who want this game")
add_desc("wishing", "Number of people who wish for this game")
add_desc("name", "Game name")
add_desc("year", "Year the game was published (from ratings table)")
add_desc("rank", "Current BGG rank")
add_desc("average", "Average user rating")
add_desc("bayes_average", "Bayesian average rating (model outcome)")
add_desc("users_rated", "Number of users who rated the game")
add_desc("url", "Game URL on BoardGameGeek")
add_desc("thumbnail", "Thumbnail image URL")

## ---- Derived variables ------------------------------------------------------------
add_desc("zero_raters", "Logical flag: TRUE if users_rated == 0")
add_desc("log_users_rated", "log1p(users_rated), suppresses right skew")
add_desc("playingtime_capped", "playingtime capped at 600 minutes")
add_desc("log_playingtime", "log1p(playingtime_capped)")
add_desc("maxplayers_capped", "maxplayers capped at 36")
add_desc("game_age", "Game age in years (2022 - yearpublished)")
add_desc("log_game_age", "log1p(game_age)")
add_desc("designer_first", "First-listed designer name")
add_desc("designer_id", "Factor identifier for first-listed designer (grouping factor)")
add_desc("multi_designer", "Binary flag: 1 if game has more than one designer")
add_desc("z_log_users", "Standardized log_users_rated (mean 0, sd 1)")
add_desc("z_game_age", "Standardized log_game_age (mean 0, sd 1)")
add_desc("z_log_play", "Standardized log_playingtime (mean 0, sd 1)")

## ---- Indicator variables ------------------------------------------------------------
for (v in grep("^cat_", names(big), value = TRUE))
  add_desc(v, paste("Binary indicator for category:", gsub("^cat_", "", v)))
for (v in grep("^mech_", names(big), value = TRUE))
  add_desc(v, paste("Binary indicator for mechanic:", gsub("^mech_", "", v)))

## ---- Missing value counts (per variable) ---------------------------------------------
desc$n_missing <- sapply(desc$variable, function(v)
  if (v %in% names(big)) sum(is.na(big[[v]])) else NA)

write.csv(desc, file.path(out_dir, "data_dictionary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
cat("Dictionary generated:", nrow(desc), "variables\n")
cat("Saved:", file.path(out_dir, "data_dictionary.csv"), "\n")
