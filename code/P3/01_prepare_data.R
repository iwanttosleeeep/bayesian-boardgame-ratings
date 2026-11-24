args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
setwd(root)

for (d in c("outputs/P3", "tables/P3", "figures/P3")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

paths <- c("data_clean.csv", "data/data_clean.csv", "output/data_clean.csv")
path <- paths[file.exists(paths)][1]
if (is.na(path)) stop("Cannot find data_clean.csv.")
dat <- read.csv(path, na.strings = c("", "NA"), check.names = FALSE)

continuous <- c("z_log_play", "minplayers", "maxplayers_capped", "minage")
tags <- grep("^(cat_|mech_)", names(dat), value = TRUE)
needed <- c("id", "users_rated", continuous, "z_game_age", tags, "multi_designer")
stopifnot(nrow(dat) == 21631L, length(tags) == 40L, all(needed %in% names(dat)))
keep <- complete.cases(dat[, needed])
dat <- dat[keep, needed]

scale1 <- function(x) as.numeric(scale(x))
dat$z_minplayers <- scale1(dat$minplayers)
dat$z_maxplayers <- scale1(dat$maxplayers_capped)
dat$z_minage <- scale1(dat$minage)
x_names <- c("z_log_play", "z_minplayers", "z_maxplayers", "z_minage", tags,
             "multi_designer")
X <- as.matrix(dat[, x_names])
storage.mode(X) <- "double"
y <- as.integer(dat$users_rated)
age <- dat$z_game_age
stopifnot(!anyDuplicated(dat$id), all(y >= 30), all(is.finite(X)),
          all(is.finite(age)), all(apply(X, 2, sd) > 0))

model_data <- data.frame(id = dat$id, users_rated = y, z_game_age = age,
                         dat[, x_names], check.names = FALSE)
write.csv(model_data, "outputs/P3/M2_model_data.csv", row.names = FALSE)
saveRDS(list(y = y, X = X, age = age, id = dat$id, x_names = x_names,
             source_file = path, source_rows = length(keep)),
        "outputs/P3/M2_design.rds")

labels <- c(z_log_play = "Log playing time (per SD)",
            z_minplayers = "Minimum players (per SD)",
            z_maxplayers = "Maximum players, capped (per SD)",
            z_minage = "Minimum recommended age (per SD)",
            z_game_age = "Log(1 + game age) (per SD)",
            multi_designer = "Multiple designers")
pretty <- function(s) {
  s <- sub("^cat_", "Category: ", s)
  s <- sub("^mech_", "Mechanic: ", s)
  gsub("\\.\\.\\.", " / ", gsub("\\.", " ", s))
}
terms <- c(x_names, "z_game_age")
parameters <- data.frame(
  parameter = c("alpha", paste0("beta[", seq_along(x_names), "]"), "delta", "r"),
  term = c("Intercept", terms, "NB dispersion"),
  label = c("Intercept", unname(labels[terms]), "NB dispersion r"),
  stringsAsFactors = FALSE
)
parameters$label[is.na(parameters$label)] <- pretty(parameters$term[is.na(parameters$label)])
write.csv(parameters, "outputs/P3/M2_parameter_dictionary.csv", row.names = FALSE)

audit <- data.frame(
  item = c("P1 cleaned rows", "Complete M2 rows", "Dropped incomplete rows",
           "Observations at 30", "Observations 30-39", "Observations at least 10000"),
  value = c(length(keep), length(y), sum(!keep),
            sum(y == 30), sum(y >= 30 & y <= 39), sum(y >= 10000))
)
write.csv(audit, "tables/P3/M2_sample_audit.csv", row.names = FALSE)
writeLines(capture.output(sessionInfo()), "outputs/P3/P3_session_info.txt")
cat("Using", path, "\nComplete games:", length(y), "\n")
