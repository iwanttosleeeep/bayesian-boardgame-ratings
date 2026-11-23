# Lightweight export of already-fitted metadata. No sampling, no log overwrites.
for(run in c("baseline_development","sensitivity_s_upper6")) {
  out<-file.path("outputs/P4",run)
  p<-readRDS(file.path(out,"preprocessing.rds"))
  write.csv(data.frame(variable=names(p$medians),median=unname(p$medians),
    center=unname(p$center),scale=unname(p$scale)),file.path(out,"numeric_preprocessing.csv"),row.names=FALSE)
  write.csv(data.frame(column=p$columns),file.path(out,"retained_columns.csv"),row.names=FALSE)
  write.csv(data.frame(variable=p$missing_numeric),file.path(out,"numeric_missing_indicators.csv"),row.names=FALSE)
  settings<-readRDS(file.path(out,"run_settings.rds"))
  write.csv(data.frame(chain=1:4,seed=settings$seeds,adapt=settings$adapt,burn=settings$burn,
    batch=settings$batch,min_draws=settings$min_draws,max_draws=settings$max_draws,glm=settings$glm,
    actual_retained=tail(read.csv(file.path(out,"progress.csv"))$draws_per_chain,1)),file.path(out,"chain_configuration.csv"),row.names=FALSE)
}
cat("PASS: exported existing preprocessing and chain configuration; no fit executed\n")
