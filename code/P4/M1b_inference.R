source("code/P4/M1b_prepare.R")
source("code/P4/M1b_diagnostics.R")

m1b_simulate <- function(data,truth) {
  u <- rnorm(data$J,0,truth$sigma_d)
  effect <- ifelse(data$known==1,u[data$designer],rnorm(data$N,0,truth$sigma_d))
  mu <- as.numeric(truth$alpha+data$X%*%truth$beta+effect)
  theta <- rnorm(data$N,mu,truth$tau)
  list(y=rnorm(data$N,theta,truth$s/sqrt(data$n)),theta=theta,u=u,
       designer_effect=effect,mu=mu)
}

m1b_save_inputs <- function(prep,dat,out,model,seeds,label) {
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  saveRDS(list(prep=prep,dat=dat,model=model,seeds=seeds,label=label),
          file.path(out,"inputs.rds"))
  saveRDS(prep$recipe,file.path(out,"preprocessing.rds"))
  write.csv(data.frame(id=prep$ids,known=prep$data$known,
                      designer_index=ifelse(prep$data$known==1,prep$data$designer,NA)),
            file.path(out,"train_game_ids.csv"),row.names=FALSE)
  write.csv(data.frame(designer_index=seq_along(prep$recipe$designers),
                      designer_name=prep$recipe$designers),
            file.path(out,"designer_mapping.csv"),row.names=FALSE,fileEncoding="UTF-8")
  write.csv(data.frame(term=colnames(prep$data$X),prior_sd=1/sqrt(prep$data$beta_prec)),
            file.path(out,"design_columns.csv"),row.names=FALSE)
  writeLines(model,file.path(out,"model.bug"))
  writeLines(c(paste("Label:",label),paste("Training rows:",prep$data$N),
    paste("Source MD5:",unname(tools::md5sum("dev_subsample.csv"))),
    paste("Model MD5:",unname(tools::md5sum(file.path(out,"model.bug")))),
    paste("Seeds:",paste(seeds,collapse=",")),"Holdout read: FALSE"),file.path(out,"provenance.txt"))
}

m1b_worker_init <- function(job,k) {
  suppressPackageStartupMessages(library(rjags))
  if(isTRUE(job$glm)) load.module("glm",quiet=TRUE)
  assign(".p4job",job,.GlobalEnv);assign(".p4chain",k,.GlobalEnv)
  set.seed(job$seeds[k])
  init<-list(.RNG.name="base::Mersenne-Twister",.RNG.seed=job$seeds[k],
    alpha=6.4+rnorm(1,0,.15),s=runif(1,1,2.8),tau=runif(1,.4,1),
    sigma_d=runif(1,.15,.6),beta=rnorm(job$data$P,0,.03),z_u=rnorm(job$data$J,0,.2))
  if (!is.null(job$initial)) init<-job$initial[[k]]
  tm<-system.time({
    fit<-jags.model(textConnection(job$model),data=job$data,inits=init,
                    n.chains=1,n.adapt=job$adapt,quiet=TRUE)
    if(job$burn>0) update(fit,job$burn,progress.bar="none")
  })
  assign(".p4fit",fit,.GlobalEnv);assign(".p4draws",NULL,.GlobalEnv)
  writeLines(c(paste("pid",Sys.getpid()),paste("compile_adapt_burn_seconds",tm["elapsed"])),
             file.path(job$out,paste0("worker_",k,".txt")))
  list(chain=k,pid=Sys.getpid(),warmup_seconds=unname(tm["elapsed"]),
       samplers=list.samplers(fit))
}

m1b_worker_batch <- function(n) {
  tm<-system.time({
    samp<-coda.samples(.p4fit,c("alpha","beta","s","tau","sigma_d","u"),
                      n.iter=n,progress.bar="none")
  })
  mat<-rbind(.p4draws,as.matrix(samp))
  assign(".p4draws",mat,.GlobalEnv)
  state<-.p4fit$state(internal=TRUE)[[1]]
  record<-list(draws=mat,chain=.p4chain,seed=.p4job$seeds[.p4chain],state=state,
               retained=nrow(mat),object_bytes=as.numeric(object.size(mat)),
               sample_batch_seconds=unname(tm["elapsed"]))
  saveRDS(record,file.path(.p4job$out,paste0("chain_",.p4chain,".rds")),compress=FALSE)
  list(chain=.p4chain,retained=nrow(mat),object_bytes=record$object_bytes,
       sample_batch_seconds=record$sample_batch_seconds)
}

m1b_read_chains <- function(out) lapply(1:4,function(k)readRDS(file.path(out,paste0("chain_",k,".rds")))$draws)

m1b_fit <- function(prep,dat,out,label="baseline",adapt=1000,burn=1000,
                    batch=2000,max_draws=8000,min_draws=batch,initial=NULL,seeds=610650L+1:4,glm=FALSE) {
  if(file.exists(file.path(out,"inputs.rds"))) stop("Refusing to overwrite run: ",out)
  model<-paste(readLines("code/P4/M1b_baseline.bug"),collapse="\n")
  if(label=="sensitivity_s_upper6") model<-sub("s ~ dunif(0.5, 3)","s ~ dunif(0.5, 6)",model,fixed=TRUE)
  m1b_save_inputs(prep,dat,out,model,seeds,label)
  job<-list(data=prep$data,model=model,out=normalizePath(out),seeds=seeds,
            adapt=adapt,burn=burn,initial=initial,glm=glm)
  saveRDS(list(adapt=adapt,burn=burn,batch=batch,max_draws=max_draws,
               min_draws=min_draws,seeds=seeds,glm=glm),file.path(out,"run_settings.rds"))
  cl<-parallel::makePSOCKcluster(4,outfile=file.path(out,"workers.log"))
  on.exit(parallel::stopCluster(cl))
  parallel::clusterCall(cl,function(repo,libs) {
    setwd(repo);.libPaths(libs);source("code/P4/M1b_inference.R");NULL
  },getwd(),.libPaths())
  start<-proc.time()["elapsed"]
  warm<-parallel::clusterMap(cl,m1b_worker_init,rep(list(job),4),1:4)
  saveRDS(warm,file.path(out,"worker_initialization.rds"))
  write.csv(do.call(rbind,lapply(warm,function(x)data.frame(chain=x$chain,pid=x$pid,
                     warmup_seconds=x$warmup_seconds))),file.path(out,"worker_pids.csv"),row.names=FALSE)
  history<-NULL
  repeat {
    res<-parallel::clusterCall(cl,m1b_worker_batch,batch)
    chains<-m1b_read_chains(out)
    dg<-m1b_diag(m1b_derived(chains))
    write.csv(dg,file.path(out,"diagnostics.csv"),row.names=FALSE)
    row<-data.frame(draws_per_chain=nrow(chains[[1]]),elapsed=unname(proc.time()["elapsed"]-start),
      max_rhat=max(dg$rhat),min_bulk_ess=min(dg$ess_bulk),min_tail_ess=min(dg$ess_tail),
      max_mcse_ratio=max(dg$mcse_mean_over_sd),passed=all(dg$pass),
      draw_object_MB=sum(vapply(chains,function(x)as.numeric(object.size(x)),0))/1024^2,
      max_worker_batch_seconds=max(vapply(res,function(x)x$sample_batch_seconds,0)))
    history<-rbind(history,row)
    write.csv(history,file.path(out,"progress.csv"),row.names=FALSE)
    cat(label,basename(out),"draws/chain",row$draws_per_chain,"max Rhat",round(row$max_rhat,4),
        "min bulk/tail",round(row$min_bulk_ess),round(row$min_tail_ess),"elapsed",round(row$elapsed),"s\n")
    flush.console()
    if((row$passed && row$draws_per_chain>=min_draws)||row$draws_per_chain>=max_draws||
       file.exists(file.path(out,"STOP_AFTER_CHECKPOINT"))) break
    rm(chains);gc()
  }
  m1b_plots(chains,out)
  writeLines(c(paste("Status:",if(row$passed)"diagnostic thresholds met" else "diagnostic thresholds NOT met"),
               paste("Draws per chain:",row$draws_per_chain),paste("Elapsed seconds:",row$elapsed),
               "Diagnostics: posterior rank-normalized/folded split Rhat, bulk/tail ESS, MCSE",
               "Thresholds: Rhat<=1.01; bulk/tail ESS>=400; MCSE(mean)/SD<=0.05",
               "Parameter draws and RNG states saved per chain; chain number is explicit",
               paste("Resource stop requested:",file.exists(file.path(out,"STOP_AFTER_CHECKPOINT"))),
               "No holdout read; no formal matched-model comparison performed"),file.path(out,"status.txt"))
  invisible(list(chains=chains,diagnostics=dg,history=history))
}

m1b_latent_output <- function(prep,out,B=500,truth=NULL,seed=610699L) {
  chains<-m1b_read_chains(out);set.seed(seed)
  theta<-weight<-mu_mat<-conditional_means<-matrix(NA_real_,prep$data$N,B)
  loglik<-matrix(NA_real_,B,prep$data$N)
  groups<-list(n30_40=which(prep$data$n<=40),n100_200=which(prep$data$n>=100&prep$data$n<=200),
               n1000_5000=which(prep$data$n>=1000&prep$data$n<=5000),n5000plus=which(prep$data$n>5000))
  ppc_mean<-ppc_var<-matrix(NA_real_,B,length(groups))
  chosen<-data.frame(chain=sample.int(4,B,replace=TRUE),iteration=sample.int(nrow(chains[[1]]),B,replace=TRUE))
  for(b in seq_len(B)) {
    z<-chains[[chosen$chain[b]]][chosen$iteration[b],]
    beta<-z[paste0("beta[",seq_len(prep$data$P),"]")]
    u<-z[paste0("u[",prep$data$designer,"]")]
    mu<-as.numeric(z["alpha"]+prep$data$X%*%beta+prep$data$known*u)
    cond<-m1b_latent(prep$data$y,prep$data$n,mu,z["tau"],z["s"],z["sigma_d"],prep$data$known)
    theta[,b]<-rnorm(prep$data$N,cond$mean,cond$sd);weight[,b]<-cond$weight;mu_mat[,b]<-mu
    conditional_means[,b]<-cond$mean
    vs<-z["tau"]^2+(1-prep$data$known)*z["sigma_d"]^2+z["s"]^2/prep$data$n
    loglik[b,]<-dnorm(prep$data$y,mu,sqrt(vs),log=TRUE)
    yrep<-rnorm(prep$data$N,mu,sqrt(vs))
    ppc_mean[b,]<-vapply(groups,function(ix)mean(yrep[ix]),0)
    ppc_var[b,]<-vapply(groups,function(ix)var(yrep[ix]),0)
  }
  stopifnot(all(is.finite(theta)))
  rownames(theta)<-as.character(prep$ids)
  summary<-data.frame(id=prep$ids,n=prep$data$n,known=prep$data$known,raw=prep$data$y,
    mean=rowMeans(conditional_means),lower95=apply(theta,1,quantile,.025),upper95=apply(theta,1,quantile,.975),
    weight=rowMeans(weight),mu=rowMeans(mu_mat))
  summary$adjustment<-summary$mean-summary$raw
  write.csv(summary,file.path(out,"latent_ratings.csv"),row.names=FALSE)
  saveRDS(list(ids=prep$ids,theta_draws=theta,draw_index=chosen,weight=weight,
               note="Within-training sample; includes conditional theta and parameter uncertainty"),
          file.path(out,"latent_draws.rds"))
  colnames(loglik)<-as.character(prep$ids)
  saveRDS(list(ids=prep$ids,draw_index=chosen,loglik=loglik,
    convention="Game theta integrated; named designer effects conditional; not designer-level LOO"),
    file.path(out,"pointwise_loglik.rds"))
  ppc<-data.frame(group=names(groups),games=lengths(groups),
    observed_mean=vapply(groups,function(ix)mean(prep$data$y[ix]),0),
    predicted_mean_low=apply(ppc_mean,2,quantile,.025,na.rm=TRUE),
    predicted_mean_high=apply(ppc_mean,2,quantile,.975,na.rm=TRUE),
    observed_variance=vapply(groups,function(ix)var(prep$data$y[ix]),0),
    predicted_variance_low=apply(ppc_var,2,quantile,.025,na.rm=TRUE),
    predicted_variance_high=apply(ppc_var,2,quantile,.975,na.rm=TRUE))
  write.csv(ppc,file.path(out,"development_PPC.csv"),row.names=FALSE)
  if(!is.null(truth)) {
    metrics<-data.frame(group=c("all","named","anonymous"),rmse=NA,raw_rmse=NA,coverage95=NA)
    for(k in 1:3) {
      ix<-switch(k,seq_len(prep$data$N),which(prep$data$known==1),which(prep$data$known==0))
      metrics$rmse[k]<-sqrt(mean((summary$mean[ix]-truth[ix])^2))
      metrics$raw_rmse[k]<-sqrt(mean((summary$raw[ix]-truth[ix])^2))
      metrics$coverage95[k]<-mean(truth[ix]>=summary$lower95[ix]&truth[ix]<=summary$upper95[ix])
    }
    write.csv(metrics,file.path(out,"latent_recovery.csv"),row.names=FALSE)
  }
  invisible(summary)
}
