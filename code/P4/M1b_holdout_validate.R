# Independent post-export checks, no fitting or changes to training artifacts.
root<-"outputs/P4/Holdout_3209"
input<-readRDS(file.path(root,"prediction_inputs.rds"));p<-input$p;meta<-input$metadata;groups<-input$groups
ids<-read.csv(file.path(root,"holdout_ids.csv"))$id
stopifnot(length(ids)==3209,!anyDuplicated(ids),identical(ids,p$ids),identical(ids,meta$id),
 sum(lengths(groups[grep("^designer/",names(groups))]))==3209,
 sum(lengths(groups[grep("^n/",names(groups))]))==3209)
selected<-unique(c(1,3209,unlist(lapply(c("seen_named","unseen_named","missing","uncredited"),
 function(g)head(which(p$group==g),2)))))
results<-c("PASS: exact 3209 IDs/order; designer and rating-count partitions exhaustive")
for(model in c("matched_baseline","external_sd")) {
 path<-file.path(root,model);fit<-file.path("outputs/P4/ExternalSD_6416",model)
 draws<-readRDS(file.path(path,"predictive_draws.rds"))
 pred<-read.csv(file.path(path,"holdout_game_predictions.csv"),fileEncoding="UTF-8")
 index<-read.csv(file.path(path,"draw_index.csv"))
 summary<-read.csv(file.path(path,"holdout_summary.csv"));ppc<-read.csv(file.path(path,"holdout_grouped_PPC.csv"))
 stopifnot(identical(draws$ids,ids),identical(pred$id,ids),identical(pred$designer_group,p$group),
  identical(index,draws$draw_index),!anyDuplicated(index),
  identical(as.integer(table(index$chain)),rep(4000L,4)),
  identical(dim(draws$observed_average_draws),c(16000L,3209L)),
  all(is.finite(draws$observed_average_draws)),all(is.finite(pred$log_predictive_density)),
  all(pred$predictive_lower<pred$predictive_upper),
  identical(pred$covered_95,with(pred,observed_average>=predictive_lower&observed_average<=predictive_upper)))
 q<-apply(draws$observed_average_draws,2,quantile,probs=c(.025,.975),names=FALSE)
 interval_error<-max(abs(q[1,]-pred$predictive_lower),abs(q[2,]-pred$predictive_upper))
 chosen_rows<-unique(as.integer(round(seq(1,16000,length.out=100))))
 ppc_error<-0
 for(g in seq_along(groups)) {
  ix<-groups[[g]];rep<-draws$observed_average_draws[chosen_rows,ix,drop=FALSE]
  ppc_error<-max(ppc_error,abs(rowMeans(rep)-draws$grouped_mean_draws[chosen_rows,g]),
   abs(apply(rep,1,var)-draws$grouped_variance_draws[chosen_rows,g]))
  qm<-quantile(draws$grouped_mean_draws[,g],c(.025,.5,.975),names=FALSE)
  qv<-quantile(draws$grouped_variance_draws[,g],c(.025,.5,.975),names=FALSE)
  stopifnot(abs(sum(pred$log_predictive_density[ix])-summary$ELPD[g])<1e-9,
   abs(mean(pred$covered_95[ix])-summary$coverage_95[g])<1e-12,
   abs(mean(pred$predictive_upper[ix]-pred$predictive_lower[ix])-summary$mean_interval_width[g])<1e-12,
   max(abs(qm-as.numeric(ppc[g,c("predictive_mean_low","predictive_mean_median","predictive_mean_high")])))<1e-12,
   max(abs(qv-as.numeric(ppc[g,c("predictive_variance_low","predictive_variance_median","predictive_variance_high")])))<1e-12)
 }
 # Independent scalar mixture formula for selected games, across ALL real draws.
 # Also verify the exact Rao-Blackwell predictive means and total variances.
 manual<-means<-variances<-matrix(NA_real_,16000,length(selected))
 for(k in 1:4) {
  record<-readRDS(file.path(fit,paste0("chain_",k,".rds")));z<-record$draws
  stopifnot(record$chain==k,nrow(z)==4000)
  rows<-(k-1L)*4000+1:4000
  for(j in seq_along(selected)) {
   i<-selected[j]
   mu<-z[,"alpha"]+drop(z[,paste0("beta[",seq_len(ncol(p$X)),"]"),drop=FALSE]%*%p$X[i,])
   if(p$known[i]==1)mu<-mu+z[,paste0("u[",p$designer_index[i],"]")]
   variance<-z[,"tau"]^2+(1-p$known[i])*z[,"sigma_d"]^2+
    if(model=="external_sd")p$sd_hist[i]^2/p$n[i] else z[,"s"]^2/p$n[i]
   manual[rows,j]<--.5*(log(2*pi*variance)+(meta$observed_average[i]-mu)^2/variance)
   means[rows,j]<-mu;variances[rows,j]<-variance
  }
  rm(record,z);gc()
 }
 lpd<-apply(manual,2,function(x) {peak<-max(x);peak+log(sum(exp(x-peak)))-log(length(x))})
 lpd_error<-max(abs(lpd-pred$log_predictive_density[selected]))
 mean_error<-max(abs(colMeans(means)-pred$predictive_mean[selected]))
 sd_error<-max(abs(sqrt(colMeans(variances+means^2)-colMeans(means)^2)-pred$predictive_sd[selected]))
 stopifnot(interval_error<1e-10,ppc_error<1e-10,lpd_error<1e-10,mean_error<1e-10,sd_error<1e-10)
 results<-c(results,paste(model,"PASS: finite 16000 x 3209 observed-average replicates; all four full chain indices and CSV groups agree"),
  paste("Independent interval/PPC/scalar-mixture-LPD/mean/SD max errors:",
   paste(format(c(interval_error,ppc_error,lpd_error,mean_error,sd_error),digits=5),collapse=", ")))
 rm(draws,manual,means,variances);gc()
}
paired<-read.csv(file.path(root,"paired_log_predictive_density.csv"),fileEncoding="UTF-8")
a<-read.csv(file.path(root,"matched_baseline","holdout_game_predictions.csv"),fileEncoding="UTF-8")
b<-read.csv(file.path(root,"external_sd","holdout_game_predictions.csv"),fileEncoding="UTF-8")
stopifnot(identical(paired$id,ids),max(abs(paired$external_minus_baseline-(b$log_predictive_density-a$log_predictive_density)))<1e-12)
results<-c(results,"PASS: paired pointwise log predictive density differences reread and verified",
 "Constructed prediction checks passed before scoring; no conditional theta, refitting or tuning")
writeLines(results,file.path(root,"final_validation.txt"))
cat(paste(results,collapse="\n"),"\n")
