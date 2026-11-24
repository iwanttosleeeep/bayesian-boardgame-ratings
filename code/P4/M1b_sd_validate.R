# Post-fit validation only; preserves every original fit and export.
source("code/P4/M1b_sd_inference.R")
root<-"outputs/P4/ExternalSD_6416"
common<-readRDS(file.path(root,"matched_inputs.rds"))
ids<-read.csv(file.path(root,"train_game_ids.csv"))$id
stopifnot(identical(ids,common$prep$ids),length(ids)==6416,!anyDuplicated(ids))
results<-character()
for(run in c("matched_baseline","external_sd")) {
 path<-file.path(root,run);input<-readRDS(file.path(path,"inputs.rds"));d<-input$prep$data
 stopifnot(identical(input$prep$ids,ids),identical(input$prep$recipe,common$prep$recipe),
  identical(d$X,common$prep$data$X),identical(d$designer,common$prep$data$designer),
  identical(d$known,common$prep$data$known),identical(input$model,sd_model(run=="external_sd")))
 if(run=="external_sd") stopifnot(identical(d$v_obs,common$sd$sd_hist^2/common$dat$users_rated))
 chains<-m1b_read_chains(path)
 share<-readRDS(file.path(path,"pointwise_loglik_share.rds"))
 stopifnot(identical(dim(share$loglik),c(500L,6416L)),identical(share$ids,ids),
  identical(colnames(share$loglik),as.character(ids)),all(is.finite(share$loglik)),
  !anyDuplicated(share$draw_index),identical(as.integer(table(share$draw_index$chain)),rep(125L,4)))
 saved<-readRDS(file.path(path,"latent_draws.rds"))
 full_ll<-readRDS(file.path(path,"pointwise_loglik.rds"))
 B<-nrow(full_ll$loglik);stopifnot(B==1000,identical(saved$draw_index,full_ll$draw_index))
 groups<-list(n30_40=which(d$n<=40),n100_200=which(d$n>=100&d$n<=200),
  n1000_5000=which(d$n>=1000&d$n<=5000),n5000plus=which(d$n>5000))
 pm<-pv<-matrix(NA_real_,B,length(groups))
 # Independently replay the documented export RNG: theta then replicated y.
 set.seed(611399)
 chosen<-data.frame(chain=sample.int(4,B,replace=TRUE),iteration=sample.int(nrow(chains[[1]]),B,replace=TRUE))
 stopifnot(identical(chosen,saved$draw_index))
 theta_error<-ll_error<-weight_error<-0
 for(j in seq_len(B)) {
  z<-chains[[chosen$chain[j]]][chosen$iteration[j],]
  mu<-drop(z["alpha"]+d$X%*%z[paste0("beta[",seq_len(d$P),"]")])+d$known*z[paste0("u[",d$designer,"]")]
  v<-if(run=="external_sd")d$v_obs else z["s"]^2/d$n
  t2<-z["tau"]^2+(1-d$known)*z["sigma_d"]^2
  conditional_var<-1/(1/t2+1/v)
  conditional_mean<-conditional_var*(mu/t2+d$y/v)
  replay_theta<-rnorm(d$N,conditional_mean,sqrt(conditional_var))
  theta_error<-max(theta_error,abs(replay_theta-saved$theta_draws[,j]))
  weight_error<-max(weight_error,abs(saved$weight[,j]-conditional_var/v))
  direct<--.5*(log(2*pi*(t2+v))+(d$y-mu)^2/(t2+v))
  ll_error<-max(ll_error,abs(direct-full_ll$loglik[j,]))
  yrep<-rnorm(d$N,mu,sqrt(t2+v))
  pm[j,]<-vapply(groups,function(i)mean(yrep[i]),0)
  pv[j,]<-vapply(groups,function(i)var(yrep[i]),0)
 }
 ppc<-read.csv(file.path(path,"development_PPC.csv"))
 expected<-cbind(apply(pm,2,quantile,.025),apply(pm,2,quantile,.975),
  apply(pv,2,quantile,.025),apply(pv,2,quantile,.975))
 actual<-as.matrix(ppc[,c("predicted_mean_low","predicted_mean_high","predicted_variance_low","predicted_variance_high")])
 ppc_error<-max(abs(expected-actual))
 stopifnot(theta_error<1e-10,ll_error<1e-10,weight_error<1e-12,ppc_error<1e-10)
 write.csv(data.frame(variable=names(input$prep$recipe$medians),median=input$prep$recipe$medians,
  center=input$prep$recipe$center,scale=input$prep$recipe$scale),file.path(path,"numeric_preprocessing.csv"),row.names=FALSE)
 write.csv(data.frame(term=input$prep$recipe$dropped_constants),file.path(path,"dropped_constant_columns.csv"),row.names=FALSE)
 write.csv(data.frame(variable=input$prep$recipe$missing_numeric),file.path(path,"numeric_missing_indicators.csv"),row.names=FALSE)
 results<-c(results,paste(run,"PASS: 6416 identical IDs/X/recipe/designer mapping; share 500 x 6416 finite, distinct real indices, 125/chain"),
  paste("Independent full 1000-draw theta/weight/loglik/PPC replay max errors:",
   paste(format(c(theta_error,weight_error,ll_error,ppc_error),digits=5),collapse=", ")))
 rm(chains,saved,full_ll,share);gc()
}
writeLines(results,file.path(root,"final_validation.txt"))
cat(paste(results,collapse="\n"),"\n")
