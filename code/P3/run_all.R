args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
mode <- if (length(args) >= 2) tolower(args[2]) else "saved"
stopifnot(mode %in% c("saved", "jags", "source", "sensitivity"))
setwd(root)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
run <- function(script, arguments = character()) {
  status <- system2(rscript, c(file.path(root, "code/P3_popularity", script), root, arguments))
  if (status != 0) stop("Failed: ", script)
}

run("01_prepare_data.R")
if (mode == "jags") {
  run("02_fit_M2.R", c("poisson", 1000, 1000, 4000, 4, "base", 4))
  run("02_fit_M2.R", c("negbin", 1000, 1000, 4000, 4, "base", 4))
}
if (mode == "source") {
  run("02b_fit_M2_source.R", c("poisson", 2000, 6000, 6, 4))
  run("02b_fit_M2_source.R", c("negbin", 2000, 6000, 6, 4))
}
if (mode == "sensitivity") run("04_prior_sensitivity.R")
run("03_analyze_M2.R")
run("05_write_report.R")
