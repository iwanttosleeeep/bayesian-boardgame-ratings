## ============================================================================
## 01_data_cleaning.R
## STAT1606 Project — BoardGameGeek data
##
## Purpose : Read raw details.csv + ratings.csv, merge, and apply the cleaning
##           steps promised in the proposal:
##             - invalid publication years (outside 1900-2022) -> NA
##             - structural zeros (playingtime / maxplayers / minplayers /
##               minage == 0) -> NA
##             - extreme values capped (playingtime at 600 min,
##               maxplayers at 36)
##             - derived variables: zero_raters, log_users_rated,
##               playingtime_capped, log_playingtime, maxplayers_capped,
##               game_age, log_game_age
## Input   : data/raw/details.csv, data/raw/ratings.csv
## Output  : data/processed/big_clean.rds
## Run from the project root directory, e.g.:
##   Rscript script/01_data_cleaning.R
## ============================================================================

suppressMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

raw_dir  <- file.path("data", "raw")
proc_dir <- file.path("data", "processed")
dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)

## ---- 1. Read raw tables (auto-detect encoding) ------------------------------
enc_details <- guess_encoding(file.path(raw_dir, "details.csv"))$encoding[1]
enc_ratings <- guess_encoding(file.path(raw_dir, "ratings.csv"))$encoding[1]
cat("details.csv encoding:", enc_details, "\n")
cat("ratings.csv encoding:", enc_ratings, "\n")

cat("Reading details ...\n")
details <- read_csv(file.path(raw_dir, "details.csv"),
                    show_col_types = FALSE,
                    locale = locale(encoding = enc_details))

cat("Reading ratings ...\n")
ratings <- read_csv(file.path(raw_dir, "ratings.csv"),
                    show_col_types = FALSE,
                    locale = locale(encoding = enc_ratings))

## ---- 2. Basic tidying: exact duplicates + whitespace trimming ---------------
details <- details %>%
  distinct() %>%
  mutate(across(where(is.character), str_trim))

ratings <- ratings %>%
  distinct() %>%
  mutate(across(where(is.character), str_trim))

cat("details:", nrow(details), "rows x", ncol(details), "cols\n")
cat("ratings:", nrow(ratings), "rows x", ncol(ratings), "cols\n")

## ---- 3. Merge by game id (inner join: keep games present in both tables) ----
big <- merge(as.data.frame(details), as.data.frame(ratings),
             by = "id", suffixes = c(".x", ".y"))
cat("Merged:", nrow(big), "rows x", ncol(big), "cols\n")

rm(details, ratings); gc()

## ---- 4. Drop pure index columns ----------------------------------------------
big <- big %>% select(-any_of(c("num.x", "num.y")))

## ---- 5. Invalid publication years -> NA ---------------------------------------
## Proposal: years outside the plausible range are data errors.
big$yearpublished <- ifelse(between(big$yearpublished, 1900, 2022),
                            big$yearpublished, NA)
cat("Invalid yearpublished set to NA:", sum(is.na(big$yearpublished)), "\n")

## ---- 6. Structural zeros -> NA -------------------------------------------------
## 0 is not a real measurement for these fields; it encodes "unknown".
big$playingtime[big$playingtime == 0] <- NA
big$maxplayers[big$maxplayers == 0]   <- NA
big$minplayers[big$minplayers == 0]   <- NA
big$minage[big$minage == 0]           <- NA
cat("Zeros set to NA -> playingtime:", sum(is.na(big$playingtime)),
    " maxplayers:", sum(is.na(big$maxplayers)),
    " minplayers:", sum(is.na(big$minplayers)),
    " minage:", sum(is.na(big$minage)), "\n")

## ---- 7. Extreme values: cap at plausible upper bounds --------------------------
## NOTE: na.rm = TRUE replicates the original console pipeline exactly.
## Side effect to be aware of: rows where playingtime/maxplayers are NA
## (the zeros set to NA in step 6) become 600 / 36 after capping, because
## pmin(NA, cap, na.rm = TRUE) returns the cap. If the intended behaviour is
## "keep them missing", replace na.rm = TRUE with na.rm = FALSE (or drop it)
## and downstream complete.cases filtering will exclude those rows instead.
big$playingtime_capped <- pmin(big$playingtime, 600, na.rm = TRUE)  # cap 600 min
big$log_playingtime    <- log1p(big$playingtime_capped)
big$maxplayers_capped  <- pmin(big$maxplayers, 36, na.rm = TRUE)    # cap 36 players

## ---- 8. Other derived variables -------------------------------------------------
big$zero_raters     <- (big$users_rated == 0)          # games with no ratings
big$log_users_rated <- log1p(big$users_rated)
big$game_age        <- 2022 - big$yearpublished
big$log_game_age    <- log1p(big$game_age)

## ---- 9. Save --------------------------------------------------------------------
saveRDS(big, file.path(proc_dir, "big_clean.rds"))
cat("01_data_cleaning done. Rows:", nrow(big), " Cols:", ncol(big), "\n")
cat("Saved:", file.path(proc_dir, "big_clean.rds"), "\n")
