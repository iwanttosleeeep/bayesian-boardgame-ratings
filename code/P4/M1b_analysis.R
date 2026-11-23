options(warn=1)
suppressPackageStartupMessages({library(rjags);library(coda);library(posterior)})
source("code/P4/M1b_inference.R")
args<-commandArgs(trailingOnly=TRUE)
stage<-if(length(args))args[1] else stop("Specify extended, simulation, timing, baseline, sensitivity or compare")
dev<-read.csv("dev_subsample.csv",stringsAsFactors=FALSE,check.names=FALSE,fileEncoding="UTF-8")
stopifnot(nrow(dev)==6489L,!anyDuplicated(dev$id))

if(stage=="extended") {
  saved<-readRDS("outputs/P4/smoke/smoke_draws.rds")
  dat<-dev[match(saved$ids,dev$id),,drop=FALSE]
  stopifnot(identical(dat$id,saved$ids))
  prep<-m1b_prepare(dat,saved$recipe)
  initial<-lapply(1:4,function(k) {
    z<-as.matrix(saved$samples[[k]]);z<-z[nrow(z),]
    list(.RNG.name="base::Mersenne-Twister",.RNG.seed=610710L+k,
      alpha=unname(z["alpha"]),s=unname(z["s"]),tau=unname(z["tau"]),
      sigma_d=unname(z["sigma_d"]),
      beta=unname(z[paste0("beta[",seq_len(prep$data$P),"]")]),
      z_u=unname(z[paste0("u[",seq_len(prep$data$J),"]")]/z["sigma_d"]))
  })
  old<-lapply(saved$samples,as.matrix)
  dir.create("outputs/P4/extended_400",recursive=TRUE,showWarnings=FALSE)
  write.csv(m1b_diag(m1b_derived(old)),"outputs/P4/extended_400/original_smoke_modern_diagnostics.csv",row.names=FALSE)
  m1b_fit(prep,dat,"outputs/P4/extended_400",adapt=1000,burn=500,batch=2000,
           min_draws=8000,max_draws=12000,initial=initial,seeds=610710L+1:4)
  m1b_latent_output(prep,"outputs/P4/extended_400")
}

if(stage=="simulation") {
  source("code/P4/M1b_checks.R")
  for(rep in 1:2) {
    set.seed(610720+rep)
    dat<-dev[sample.int(nrow(dev),2000),,drop=FALSE]
    dat$designer_id<-paste0("SimDesigner_",sample.int(280,nrow(dat),replace=TRUE))
    anonymous<-sample.int(nrow(dat),400)
    dat$designer_id[anonymous[1:200]]<-NA_character_
    dat$designer_id[anonymous[201:400]]<-"(Uncredited)"
    prep<-m1b_prepare(dat)
    beta<-rep(0,prep$data$P)
    beta[1:6]<-c(.25,-.2,.15,.1,-.1,.05)
    beta[7:10]<-c(.2,-.15,.1,-.1)
    truth<-list(alpha=6.4,beta=beta,tau=.55,sigma_d=.4,s=1.8)
    sim<-m1b_simulate(prep$data,truth)
    dat$average<-sim$y;prep$data$y<-sim$y
    out<-paste0("outputs/P4/simulation/rep",rep)
    m1b_fit(prep,dat,out,label=paste0("simulation_",rep),adapt=1000,burn=1000,
             batch=2000,max_draws=8000,seeds=610730L+rep*10L+1:4)
    saveRDS(list(truth=truth,simulation=sim),file.path(out,"simulation_truth.rds"))
    dg<-read.csv(file.path(out,"diagnostics.csv"))
    vals<-c(alpha=truth$alpha,s=truth$s,tau=truth$tau,sigma_d=truth$sigma_d,
            setNames(beta,paste0("beta[",seq_along(beta),"]")),
            setNames(sim$u,paste0("u[",seq_along(sim$u),"]")))
    recovery<-dg[match(names(vals),dg$parameter),]
    recovery$truth<-unname(vals)
    recovery$error<-recovery$mean-recovery$truth
    recovery$covered95<-with(recovery,truth>=lower95 & truth<=upper95)
    write.csv(recovery,file.path(out,"parameter_recovery.csv"),row.names=FALSE)
    m1b_latent_output(prep,out,B=1000,truth=sim$theta,seed=610760+rep)
  }
}

if(stage %in% c("timing","timing_corrected","information")) {
  allprep<-m1b_prepare(dev)
  groups<-table(allprep$data$designer[allprep$data$known==1])
  audit<-data.frame(designer_index=as.integer(names(groups)),games=as.integer(groups))
  audit$designer_name<-allprep$recipe$designers[audit$designer_index]
  audit$sd_log1p_n<-vapply(audit$designer_index,function(j)sd(log1p(dev$users_rated[allprep$data$known==1 & allprep$data$designer==j])),0)
  dir.create("outputs/P4/resources",recursive=TRUE,showWarnings=FALSE)
  write.csv(audit,"outputs/P4/resources/development_designer_groups.csv",row.names=FALSE,fileEncoding="UTF-8")
  metrics<-c(games=nrow(dev),named_games=sum(allprep$data$known),anonymous_games=sum(allprep$data$known==0),
    named_designers=length(groups),singleton_designers=sum(groups==1),repeated_designers=sum(groups>=2),
    games_in_repeated_designers=sum(groups[groups>=2]),within_designer_pairs=sum(groups*(groups-1)/2),
    groups_ge5=sum(groups>=5),groups_ge10=sum(groups>=10),largest_group=max(groups),
    full_design_columns=allprep$data$P)
  write.csv(data.frame(metric=names(metrics),value=unname(metrics)),"outputs/P4/resources/development_information.csv",row.names=FALSE)
  if(stage %in% c("timing","timing_corrected")) {
    set.seed(610770)
    dat<-dev[sample.int(nrow(dev),2000),,drop=FALSE]
    prep<-m1b_prepare(dat)
    out<-if(stage=="timing")"outputs/P4/timing_2000" else "outputs/P4/timing_2000_corrected"
    m1b_fit(prep,dat,out,label="timing_only",adapt=500,burn=500,
             batch=500,max_draws=500,seeds=610780L+1:4,glm=(stage=="timing_corrected"))
  }
}

if(stage %in% c("baseline","sensitivity")) {
  stopifnot(file.exists("outputs/P4/resources/implementation_resource_gate.txt"))
  prep<-m1b_prepare(dev) # ALWAYS re-estimate on these actual full-training rows.
  label<-if(stage=="baseline")"baseline_development" else "sensitivity_s_upper6"
  out<-file.path("outputs/P4",label)
  m1b_fit(prep,dev,out,label=label,adapt=2000,burn=2000,batch=2000,
           max_draws=12000,min_draws=4000,seeds=if(stage=="baseline")610800L+1:4 else 610900L+1:4,glm=TRUE)
  m1b_latent_output(prep,out,B=1000)
}

if(stage=="compare") {
  aout<-"outputs/P4/baseline_development";bout<-"outputs/P4/sensitivity_s_upper6"
  a<-read.csv(file.path(aout,"latent_ratings.csv"));b<-read.csv(file.path(bout,"latent_ratings.csv"))
  stopifnot(identical(a$id,b$id))
  da<-read.csv(file.path(aout,"diagnostics.csv"));db<-read.csv(file.path(bout,"diagnostics.csv"))
  merged<-merge(da,db,by="parameter",suffixes=c("_baseline","_upper6"))
  merged$mean_change<-merged$mean_upper6-merged$mean_baseline
  dir.create("outputs/P4/s_prior_comparison",recursive=TRUE,showWarnings=FALSE)
  write.csv(merged,"outputs/P4/s_prior_comparison/parameter_comparison.csv",row.names=FALSE)
  per_game<-data.frame(id=a$id,n=a$n,known=a$known,baseline_mean=a$mean,upper6_mean=b$mean,
    mean_change=b$mean-a$mean,baseline_adjustment=a$adjustment,upper6_adjustment=b$adjustment,
    baseline_weight=a$weight,upper6_weight=b$weight)
  write.csv(per_game,"outputs/P4/s_prior_comparison/per_game_changes.csv",row.names=FALSE)
  top<-function(x)order(x,decreasing=TRUE)[1:50]
  metrics<-c(baseline_converged=all(da$pass),sensitivity_converged=all(db$pass),
    median_absolute_theta_change=median(abs(b$mean-a$mean)),max_absolute_theta_change=max(abs(b$mean-a$mean)),
    rank_spearman=cor(a$mean,b$mean,method="spearman"),top50_overlap=length(intersect(top(a$mean),top(b$mean))),
    median_abs_baseline_shrinkage=median(abs(a$adjustment)),median_abs_upper6_shrinkage=median(abs(b$adjustment)))
  write.csv(data.frame(metric=names(metrics),value=unname(metrics)),"outputs/P4/s_prior_comparison/summary.csv",row.names=FALSE)
  for(g in list(all=seq_len(nrow(a)),low_n=which(a$n<=100),high_n=which(a$n>1000))) {
    # Detailed comparisons remain available in per_game_changes.csv.
    stopifnot(length(g)>0)
  }
}
