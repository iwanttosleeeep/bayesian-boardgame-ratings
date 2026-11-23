source("code/P4/M1b_inference.R")
all_metrics<-NULL
for(rep in 1:2) {
  out<-paste0("outputs/P4/simulation/rep",rep)
  a<-readRDS(file.path(out,"inputs.rds"));t<-readRDS(file.path(out,"simulation_truth.rds"))
  d<-a$prep$data
  mu<-as.numeric(t$truth$alpha+d$X%*%t$truth$beta+d$known*t$simulation$u[d$designer])
  q<-m1b_latent(d$y,d$n,mu,t$truth$tau,t$truth$s,t$truth$sigma_d,d$known)
  oracle<-mean(abs(t$simulation$theta-q$mean)<=qnorm(.975)*q$sd)
  measurement_z<-(d$y-t$simulation$theta)*sqrt(d$n)/t$truth$s
  latent_z<-(t$simulation$theta-t$simulation$mu)/t$truth$tau
  dg<-read.csv(file.path(out,"diagnostics.csv"))
  rec<-read.csv(file.path(out,"parameter_recovery.csv"))
  lr<-read.csv(file.path(out,"latent_recovery.csv"))
  stopifnot(all(dg$pass),all(is.finite(measurement_z)),abs(mean(measurement_z))<.1,
    abs(sd(measurement_z)-1)<.1,abs(mean(latent_z))<.1,abs(sd(latent_z)-1)<.1,
    oracle>.92,oracle<.98,lr$rmse[1]<lr$raw_rmse[1])
  row<-data.frame(rep=rep,max_rhat=max(dg$rhat),min_bulk=min(dg$ess_bulk),min_tail=min(dg$ess_tail),
    oracle_coverage=oracle,posterior_theta_coverage=lr$coverage95[1],theta_rmse=lr$rmse[1],
    raw_rmse=lr$raw_rmse[1],measurement_z_mean=mean(measurement_z),measurement_z_sd=sd(measurement_z),
    latent_z_mean=mean(latent_z),latent_z_sd=sd(latent_z),
    beta_coverage=mean(rec$covered95[grepl("^beta",rec$parameter)]),
    designer_effect_coverage=mean(rec$covered95[grepl("^u\\[",rec$parameter)]))
  write.csv(row,file.path(out,"oracle_check.csv"),row.names=FALSE)
  all_metrics<-rbind(all_metrics,row)
}
write.csv(all_metrics,"outputs/P4/simulation/recovery_overview.csv",row.names=FALSE)
writeLines(c("Implementation checks PASS: Gaussian conditioning, repeated/anonymous covariance, finite draws, generator residual scales.",
  "Both simulations meet modern diagnostic thresholds and improve latent RMSE over raw observed means.",
  "Calibration limitation: posterior s is weakly identified and low in both fixed-truth replicates; theta interval coverage is only 84-88%.",
  "Oracle conditioning coverage is near 95%. Passing MCMC diagnostics is not a calibration guarantee.",
  "Two replicates are a limited recovery check, not simulation-based calibration or a comprehensive coverage study.",
  "Execution note: editing analysis script while its original Rscript invocation was reading it caused a trailing parser error after both replicates were saved.",
  "Both saved replicates were independently checked here; future wrapper parses the whole script using source() before execution."),
  "outputs/P4/simulation/review.txt")
cat("PASS: both saved simulation artifacts independently reviewed; calibration limitation recorded\n")
