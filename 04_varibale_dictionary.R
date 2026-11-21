## ============================================================================
## 04_varibale_dictionary.R
## STAT6106 Project — BoardGameGeek data
## (regenerated 2026-11-21: emits the enriched dictionary matching the
##  delivered data_dictionary.csv — type / missingness / range / definition;
##  bayes_average correctly labelled as BGG benchmark, NOT model outcome)
##
## Purpose : Generate data_dictionary.csv documenting every variable in the
##           final feature table: name, type, missing count, missing ratio,
##           value range, definition and business meaning.
## Input   : data/processed/big_features.rds   (from 02_feature_engineering.R)
## Output  : output/data_dictionary.csv
## Run from the project root directory, e.g.:
##   Rscript script/04_varibale_dictionary.R
## ============================================================================

suppressMessages(library(dplyr))

proc_dir <- file.path("data", "processed")
out_dir  <- "output"
dir.create(out_dir, showWarnings = FALSE)

big <- readRDS(file.path(proc_dir, "big_features.rds"))

## ---- Definitions -------------------------------------------------------------------
defs <- list(
  id          = c("Unique game identifier", "Primary key, not used in model"),
  primary     = c("Primary category ID", "Category identifier, usable for group analysis"),
  description = c("Text description of the game", "Text feature, keywords extractable"),
  yearpublished = c("Year first published; values outside 1900-2022 recoded to NA (302 games)",
                    "Reflects era; source of derived game_age (reference year 2022)"),
  minplayers  = c("Minimum number of players supported (0 recoded to NA: 44)", "Entry barrier"),
  maxplayers  = c("Maximum number of players supported (0 recoded to NA: 164)", "Game capacity"),
  playingtime = c("Average playtime in minutes (0 recoded to NA: 774; original NOT capped)",
                  "Time cost, affects player choice"),
  minplaytime = c("Minimum playtime in minutes", "Lower bound of duration"),
  maxplaytime = c("Maximum playtime in minutes", "Upper bound of duration"),
  minage      = c("Minimum recommended player age (0 recoded to NA: 1,301)", "Age barrier"),
  boardgamecategory = c("Game category tags (raw comma-separated string)", "Core category feature"),
  boardgamemechanic = c("Game mechanic tags (raw comma-separated string)", "Core gameplay feature"),
  boardgamefamily   = c("Game series/family tag", "Series affiliation, IP continuity"),
  boardgameexpansion= c("Expansion tag", "Expansion attribute"),
  boardgameimplementation = c("Derived work tag", "Derivation relationship"),
  boardgamedesigner = c("Game designer(s) (raw string)", "Designer brand effect"),
  boardgameartist   = c("Game artist", "Art style, first impression"),
  boardgamepublisher= c("Game publisher", "Publisher reputation"),
  owned     = c("Number of users who own this game", "Market ownership, popularity metric"),
  trading   = c("Number of users trading this game", "Circulation activity"),
  wanting   = c("Number of users on want list", "Latent demand"),
  wishing   = c("Number of users on wish list", "Anticipation, strong demand signal"),
  name      = c("Game name", "Identifier, not used in model"),
  year      = c("Year of rating statistics", "Reference for rating timeliness"),
  rank      = c("BGG overall site ranking", "Composite quality metric, lower is better"),
  average   = c("User average rating (0-10). UNMODIFIED: no winsorization/clipping applied",
                "Core target variable, genuine reputation"),
  bayes_average = c("BGG benchmark rating: Bayes-weighted average that shrinks ratings toward the prior mean",
                    "BGG site benchmark for comparison/ranking; NOT used as model outcome"),
  users_rated = c("Number of users who rated it (data pre-filtered to >=30). UNMODIFIED: no winsorization/clipping applied",
                  "Sample size, rating credibility"),
  url       = c("Game detail page link", "Display only"),
  thumbnail = c("Thumbnail link", "Display only"),
  ## derived
  playingtime_capped = c("playingtime capped at 600 min. NOTE: the 774 zero->NA rows become 600 here (pmin na.rm=TRUE side effect)",
                         "Outlier-robust playtime for modelling"),
  log_playingtime    = c("log1p of playingtime_capped", "Variance-stabilized playtime"),
  maxplayers_capped  = c("maxplayers capped at 36. NOTE: the 164 zero->NA rows become 36 here (pmin na.rm=TRUE side effect)",
                         "Outlier-robust capacity"),
  zero_raters   = c("1 if users_rated==0 else 0. VERIFIED: constant 0 (data pre-filtered to users_rated>=30)",
                    "Dead column, safe to drop"),
  log_users_rated = c("log1p of users_rated", "Variance-stabilized rating count"),
  game_age      = c("Years since publication (2022 - yearpublished); NA when yearpublished NA", "Game age effect"),
  log_game_age  = c("log1p of game_age; NA when game_age NA", "Log age effect"),
  designer_first= c("First-listed designer of boardgamedesigner", "Designer grouping key"),
  designer_id   = c("Factor identifier of designer_first (7,974 unique in delivered data)",
                    "Grouping factor for multilevel model"),
  multi_designer= c("1 if more than one designer credited, else 0 (5,817 games)", "Collaboration indicator"),
  z_log_users   = c("z-standardized log_users_rated: (x-mean)/sd on full data", "Standardized predictor"),
  z_game_age    = c("z-standardized log_game_age (NOTE: standardizes the LOG of game age, matching delivered data)",
                    "Standardized predictor"),
  z_log_play    = c("z-standardized log_playingtime: (x-mean)/sd on full data", "Standardized predictor")
)

## ---- Artifact / duplicate indicator warnings ----------------------------------------
dup_note <- function(v) {
  dups <- c("cat_X..Card.Game.", "cat_X.Card.Game.", "cat_X..Card.Game..",
            "cat_X.Wargame..", "cat_X..Wargame.",
            "mech_X..Dice.Rolling.", "mech_X.Dice.Rolling.",
            "mech_X..Hand.Management.", "mech_X.Hand.Management.",
            "mech_X.Set.Collection..", "mech_X.Set.Collection.",
            "mech_X.Simulation..", "mech_X.Simulation.")
  if (v %in% dups)
    return("Duplicate indicator (whitespace-split artifact of the same tag). OR-merge with its siblings before modelling")
  if (v %in% c("mech_Bag", "mech_and.Pool.Building."))
    return("ARTIFACT: single BGG mechanic 'Bag and Pool Building' wrongly split at 'and'. OR-merge the pair before modelling")
  "Dummy variable from tag splitting"
}

decode_tag <- function(v, prefix) {
  s <- sub(paste0("^", prefix), "", v)
  s <- sub("^X\\.+", "", s)
  s <- sub("\\.+$", "", s)
  s <- gsub("\\.\\.\\.", " / ", s)
  s <- gsub("\\.\\.", " ", s)
  s <- gsub("\\.", " ", s)
  trimws(s)
}

## ---- Assemble -----------------------------------------------------------------------
vars  <- names(big)
rows  <- lapply(vars, function(v) {
  x <- big[[v]]
  n_miss <- sum(is.na(x))
  is_ind <- grepl("^(cat_|mech_)", v)
  if (is_ind) {
    prefix <- if (startsWith(v, "cat_")) "cat_" else "mech_"
    kind   <- if (prefix == "cat_") "category" else "mechanic"
    def    <- paste0("Indicator: BGG ", kind, " '", decode_tag(v, prefix), "'")
    mean_  <- dup_note(v)
    rng    <- paste0("0/1 (1 for ", sum(x == 1, na.rm = TRUE), " games)")
    dtype  <- "indicator"
  } else {
    d      <- defs[[v]]
    def    <- if (!is.null(d)) d[1] else ""
    mean_  <- if (!is.null(d)) d[2] else ""
    dtype  <- class(x)[1]
    rng    <- if (is.numeric(x)) {
                paste(format(range(x, na.rm = TRUE), digits = 6), collapse = " ~ ")
              } else {
                paste0(length(unique(x)), " unique values")
              }
  }
  data.frame(Variable_Name = v, Data_Type = dtype, N_Missing = n_miss,
             Missing_Ratio = round(n_miss / nrow(big), 4),
             Value_Range = rng, Definition = def, Business_Meaning = mean_,
             stringsAsFactors = FALSE)
})

desc <- bind_rows(rows)
write.csv(desc, file.path(out_dir, "data_dictionary.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
cat("Dictionary generated:", nrow(desc), "variables\n")
cat("Saved:", file.path(out_dir, "data_dictionary.csv"), "\n")
