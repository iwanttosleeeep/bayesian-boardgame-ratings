options(warn=1)
suppressPackageStartupMessages({library(rjags);library(coda);library(posterior)})
source("code/P4/M1b_sd_inference.R")
root<-"outputs/P4/ExternalSD_6416"
dir.create(root,recursive=TRUE,showWarnings=FALSE)
dev<-read.csv("dev_subsample.csv",fileEncoding="UTF-8",check.names=FALSE)
lookup<-read.csv("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv",fileEncoding="UTF-8")
stopifnot(nrow(dev)==6489,!anyDuplicated(dev$id),!anyDuplicated(lookup$id),
 all(lookup$id %in% dev$id),all(is.finite(lookup$sd_hist)&lookup$sd_hist>0),
 all(is.finite(lookup$n_hist)&lookup$n_hist>0))
keep<-dev$id %in% lookup$id
dat<-dev[keep,,drop=FALSE];sd<-lookup[match(dat$id,lookup$id),]
stopifnot(nrow(dat)==6416,identical(dat$id,sd$id),
 max(abs(dat$average-sd$average_2022))<1e-8,max(abs(dat$users_rated-sd$n_2022))<1e-8)
prep<-m1b_prepare(dat)
mode<-commandArgs(trailingOnly=TRUE)[1]
if(mode=="prepare") {
 write.csv(data.frame(id=dev$id,included=keep),file.path(root,"matching_audit.csv"),row.names=FALSE)
 write.csv(sd,file.path(root,"historical_sd_matched.csv"),row.names=FALSE)
 write.csv(data.frame(id=dat$id),file.path(root,"train_game_ids.csv"),row.names=FALSE)
 saveRDS(list(prep=prep,dat=dat,sd=sd),file.path(root,"matched_inputs.rds"))
 write.csv(data.frame(variable=names(prep$recipe$medians),median=prep$recipe$medians,
   center=prep$recipe$center,scale=prep$recipe$scale),file.path(root,"numeric_preprocessing.csv"),row.names=FALSE)
 writeLines(c(paste("Games",nrow(dat)),paste("Predictors",prep$data$P),
  paste("Named designers",prep$data$J),paste("Anonymous games",sum(prep$data$known==0)),
  paste("SD range",paste(range(sd$sd_hist),collapse=" ")),
  paste("Historical rating-count relative discrepancy median/max",median(sd$relative_n_diff),max(sd$relative_n_diff)),
  "Source: AgeOfWar games.csv StdDev, individual rating SD in rating points, not standard error",
  "Source date unverified; fixed plug-in; its estimation uncertainty and temporal mismatch unmodeled",
  "N=users_rated from development (not n_hist); development order preserved; 73 excluded"),file.path(root,"data_audit.txt"))
}
if(mode=="smoke") {
 source("code/P4/M1b_sd_checks.R")
 set.seed(20261124);ix<-sample.int(nrow(dat),400)
 small<-m1b_prepare(dat[ix,]);small$data$v_obs<-sd$sd_hist[ix]^2/dat$users_rated[ix]
 m1b_fit(small,dat[ix,],file.path(root,"smoke_external"),label="external_sd",
   adapt=1000,burn=1000,batch=1000,max_draws=1000,seeds=611100L+1:4,glm=TRUE)
 m1b_latent_output(small,file.path(root,"smoke_external"),B=500,seed=611199)
 # Check exported PPC/loglik against parameter records and conditional moments.
 d<-readRDS(file.path(root,"smoke_external","pointwise_loglik.rds"))
 chains<-m1b_read_chains(file.path(root,"smoke_external"))
 maxerr<-0
 for(b in c(1,125,250,375,500)) {
   z<-chains[[d$draw_index$chain[b]]][d$draw_index$iteration[b],]
   mu<-as.numeric(z["alpha"]+small$data$X%*%z[paste0("beta[",1:small$data$P,"]")]+
     small$data$known*z[paste0("u[",small$data$designer,"]")])
   variance<-z["tau"]^2+(1-small$data$known)*z["sigma_d"]^2+small$data$v_obs
   expected<--.5*(log(2*pi*variance)+(small$data$y-mu)^2/variance)
   maxerr<-max(maxerr,max(abs(expected-d$loglik[b,])))
 }
 stopifnot(maxerr<1e-10,all(is.finite(d$loglik)),!any(grepl("^s$",colnames(chains[[1]]))))
 writeLines(c("PASS: implementation checks and 400-game ExternalSD short run",
   paste("Independent all-game loglik maximum error",maxerr),
   "PPC and conditional latent computations use same per-game sd_hist^2/n; finite outputs; no shared s",
   "Short-run diagnostic thresholds are recorded, not assumed to pass"),file.path(root,"implementation_gate.txt"))
}
if(mode %in% c("baseline","external")) {
 stopifnot(file.exists(file.path(root,"implementation_gate.txt")))
 # Freeze exactly the same prepared design/mapping, not a recipe from 6489 games.
 common<-readRDS(file.path(root,"matched_inputs.rds"))
 stopifnot(identical(common$prep,prep),identical(common$dat,dat),identical(common$sd,sd))
 if(mode=="external")prep$data$v_obs<-sd$sd_hist^2/dat$users_rated
 out<-file.path(root,if(mode=="external")"external_sd" else "matched_baseline")
 m1b_fit(prep,dat,out,label=if(mode=="external")"external_sd" else "matched_baseline",
   adapt=2000,burn=2000,batch=2000,min_draws=4000,max_draws=12000,
   seeds=if(mode=="external")611300L+1:4 else 611200L+1:4,glm=TRUE)
 m1b_latent_output(prep,out,B=1000,seed=611399)
 writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))
}
