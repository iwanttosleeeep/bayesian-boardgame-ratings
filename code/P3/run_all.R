args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
mode <- if (length(args) >= 2) tolower(args[2]) else "saved"
stopifnot(mode %in% c("saved", "jags", "source", "sensitivity"))
setwd(root)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
script_dir <- file.path(root, "code", "P3")
required <- c("01_prepare_data.R", "02_fit_M2.R", "02b_fit_M2_source.R",
              "03_analyze_M2.R", "04_prior_sensitivity.R", "05_write_report.R")
stopifnot(dir.exists(script_dir), all(file.exists(file.path(script_dir, required))))
run <- function(script, arguments = character()) {
  status <- system2(rscript, c(file.path(script_dir, script), root, arguments))
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
