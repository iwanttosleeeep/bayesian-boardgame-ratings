# STAT6106 P5: four-model holdout comparison; base R, no fitting.
# Run from repository root. Outputs go to a new local reproduction directory.
rd <- function(p) read.csv(p,stringsAsFactors=FALSE,fileEncoding="UTF-8")
a <- rd("outputs/P5/M1a_Model_Comparison/comparison_holdout_per_game.csv")
b <- rd("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_game_predictions.csv")
c <- rd("outputs/P4/Holdout_3209/holdout_metadata.csv")
d <- rd("outputs/P4/Holdout_3209/paired_log_predictive_density.csv")
s <- rd("outputs/P4/Holdout_3209/holdout_summary.csv")
N <- 3209L
ids <- as.character(a$id)
stopifnot(length(ids)==N,!anyDuplicated(ids),
  all(vapply(list(b,c,d),function(z) identical(as.character(z$id),ids),logical(1))),
  all(a$n==b$n),all(a$n==c$n),all(a$n==d$n),
  all(a$observed_average==b$observed_average),
  all(a$observed_average==c$observed_average),all(b$sd_hist==c$sd_hist))
ll <- cbind(M1a_Baseline=a$log_density_A,M1a_Extended=a$log_density_Extended,
  M1b_Baseline=d$log_predictive_density_baseline,M1b_ExternalSD=d$log_predictive_density_external)
stopifnot(all(is.finite(ll)))
cov <- c(mean(a$covered95_A),mean(a$covered95_Extended),
  s$coverage_95[s$model=="matched_baseline"&s$group=="all"],
  s$coverage_95[s$model=="external_sd"&s$group=="all"])
stopifnot(length(cov)==4L,all(is.finite(cov)))
summary <- data.frame(model=colnames(ll),games=N,posterior_draws=c(1000,1000,16000,16000),
  ELPD=colSums(ll),mean_log_predictive_density=colMeans(ll),coverage_95=cov)
g <- ifelse(d$designer_group %in% c("seen_named","unseen_named"),
  paste0(d$designer_group,":",trimws(d$designer_name)),paste0("anon:",ids))
G <- length(unique(g))
stopifnot(G==2226L)
pair <- do.call(rbind,lapply(combn(1:4,2,simplify=FALSE),function(p){
  z <- ll[,p[2]]-ll[,p[1]]
  delta <- sum(z)
  se <- sqrt(G/(G-1)*sum(tapply(z-mean(z),g,sum)^2))
  data.frame(model_A=colnames(ll)[p[2]],model_B=colnames(ll)[p[1]],
    delta_ELPD_A_minus_B=delta,SE_cluster_approx=se,
    approx95_lower=delta-1.96*se,approx95_upper=delta+1.96*se,clusters=G)
}))
out <- "P5_Holdout_Comparison_3209_reproduced"
dir.create(out,showWarnings=FALSE)
write.csv(summary,file.path(out,"holdout_four_model_summary.csv"),row.names=FALSE)
write.csv(pair,file.path(out,"holdout_pairwise_differences.csv"),row.names=FALSE)
print(summary,row.names=FALSE);print(pair,row.names=FALSE)
