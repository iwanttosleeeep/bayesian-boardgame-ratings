source("code/P4/M1b_inference.R")
dev<-read.csv("dev_subsample.csv",stringsAsFactors=FALSE,fileEncoding="UTF-8",check.names=FALSE)
fresh<-m1b_prepare(dev)
base_model<-paste(readLines("code/P4/M1b_baseline.bug"),collapse="\n")
evidence<-NULL
for(label in c("baseline_development","sensitivity_s_upper6")) {
  out<-file.path("outputs/P4",label)
  input<-readRDS(file.path(out,"inputs.rds"))
  stopifnot(identical(input$prep$ids,dev$id),identical(input$prep$recipe,fresh$recipe),
    identical(input$prep$data,fresh$data),nrow(input$dat)==6489L,
    !anyDuplicated(input$prep$ids))
  target<-if(label=="baseline_development")base_model else sub("s ~ dunif(0.5, 3)","s ~ dunif(0.5, 6)",base_model,fixed=TRUE)
  stopifnot(identical(input$model,target))
  records<-lapply(1:4,function(k)readRDS(file.path(out,paste0("chain_",k,".rds"))))
  chains<-lapply(records,`[[`,"draws")
  for(k in 1:4) stopifnot(records[[k]]$chain==k,records[[k]]$seed==input$seeds[k],
    nrow(chains[[k]])==records[[k]]$retained,all(is.finite(chains[[k]])),
    ".RNG.state" %in% names(records[[k]]$state),
    identical(colnames(chains[[k]]),colnames(chains[[1]])))
  dg<-read.csv(file.path(out,"diagnostics.csv"))
  selected<-lapply(chains,function(z)z[,c("tau","sigma_d","s"),drop=FALSE])
  recheck<-m1b_diag(selected)
  stored<-dg[match(recheck$parameter,dg$parameter),]
  stopifnot(max(abs(recheck$rhat-stored$rhat))<1e-10,
            max(abs(recheck$ess_bulk-stored$ess_bulk))<1e-7)
  latent<-readRDS(file.path(out,"latent_draws.rds"))
  ll<-readRDS(file.path(out,"pointwise_loglik.rds"))
  stopifnot(identical(latent$ids,dev$id),identical(ll$ids,dev$id),
    nrow(latent$theta_draws)==6489L,ncol(ll$loglik)==6489L,
    all(is.finite(latent$theta_draws)),all(is.finite(ll$loglik)),
    all(latent$draw_index$chain %in% 1:4),
    all(latent$draw_index$iteration<=nrow(chains[[1]])))
  row<-data.frame(run=label,games=length(input$prep$ids),chains=4,
    retained_per_chain=nrow(chains[[1]]),max_rhat=max(dg$rhat),
    min_bulk_ess=min(dg$ess_bulk),min_tail_ess=min(dg$ess_tail),
    max_mcse_mean_over_sd=max(dg$mcse_mean_over_sd),all_diagnostics_pass=all(dg$pass),
    resource_stop=file.exists(file.path(out,"STOP_AFTER_CHECKPOINT")),
    data_recipe_map_chain_state_latent_loglik_checks=TRUE)
  evidence<-rbind(evidence,row)
  writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo_postrun.txt"))
  writeLines(c(R.version.string,paste("JAGS",rjags::jags.version()),
    paste("rjags",packageVersion("rjags")),paste("posterior",packageVersion("posterior")),
    paste("coda",packageVersion("coda")),
    "Post-run verification snapshot; sampler configuration is in run_settings.rds and worker_initialization.rds"),
    file.path(out,"runtime_versions.txt"))
  rm(input,records,chains,latent,ll);gc()
}
write.csv(evidence,"outputs/P4/resources/final_verification.csv",row.names=FALSE)
cat("PASS: full training IDs, fresh preprocessing, unchanged priors, chain identity/RNG states, diagnostics and posterior artifacts\n")
print(evidence)
