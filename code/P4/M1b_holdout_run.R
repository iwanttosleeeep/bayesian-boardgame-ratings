# Saved-posterior prediction ONLY. No JAGS, fitting, tuning or conditional theta.
source("code/P4/M1b_holdout_functions.R")
root<-"outputs/P4/Holdout_3209"
fitroot<-"outputs/P4/ExternalSD_6416"
mode<-commandArgs(trailingOnly=TRUE)[1]
stopifnot(mode %in% c("audit","baseline","external"))
dir.create(root,recursive=TRUE,showWarnings=FALSE)

if(mode=="audit") {
 stopifnot(file.exists(file.path(root,"source_manifest.csv")),!file.exists(file.path(root,"prediction_inputs.rds")))
 a<-readRDS(file.path(fitroot,"matched_baseline","inputs.rds"))
 b<-readRDS(file.path(fitroot,"external_sd","inputs.rds"))
 original<-paste(readLines("code/P4/M1b_baseline.bug"),collapse="\n")
 external<-sub("s ~ dunif(0.5, 3)","",sub("pow(s, 2)/n[i]","v_obs[i]",original,fixed=TRUE),fixed=TRUE)
 stopifnot(a$label=="matched_baseline",b$label=="external_sd",identical(a$model,original),identical(b$model,external),
  identical(a$prep$ids,b$prep$ids),length(a$prep$ids)==6416,
  identical(a$prep$recipe,b$prep$recipe),identical(a$prep$data$X,b$prep$data$X),
  identical(a$prep$data$designer,b$prep$data$designer),identical(a$prep$data$known,b$prep$data$known))
 cmp<-read.csv("comparison_sample.csv",fileEncoding="UTF-8",check.names=FALSE)
 hist<-read.csv("outputs/P5/P6_Full_Handoff/P6_all_21631_SD_matching_audit.csv",fileEncoding="UTF-8")
 ref<-read.csv("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv",fileEncoding="UTF-8")
 stopifnot(nrow(cmp)==3244,nrow(hist)==21631,!anyDuplicated(cmp$id),!anyDuplicated(hist$id),
  !length(intersect(cmp$id,a$prep$ids)),!length(intersect(cmp$id,b$prep$ids)))
 hi<-match(cmp$id,hist$id);stopifnot(!anyNA(hi))
 lookup<-hist[hi,]
 stopifnot(max(abs(cmp$average-lookup$average_2022))<1e-12,
  max(abs(cmp$users_rated-lookup$n_2022))<1e-12)
 ri<-match(ref$id,hist$id)
 stopifnot(nrow(ref)==6416,!anyNA(ri),all(hist$valid_sd[ri]),
  max(abs(ref$sd_hist-hist$sd_hist[ri]))<1e-12,max(abs(ref$n_hist-hist$n_hist[ri]))<1e-12,
  identical(ref$id,a$prep$ids))
 valid<-is.finite(cmp$average)&is.finite(cmp$users_rated)&cmp$users_rated>=30&
  is.finite(lookup$sd_hist)&lookup$sd_hist>0&is.finite(lookup$n_hist)&lookup$n_hist>0
 stopifnot(sum(valid)==3209,identical(valid,lookup$valid_sd))
 write.csv(data.frame(id=cmp$id,included=valid,sd_hist=lookup$sd_hist,n_hist=lookup$n_hist),
  file.path(root,"holdout_matching_audit.csv"),row.names=FALSE)
 dat<-cmp[valid,,drop=FALSE];dat$sd_hist<-lookup$sd_hist[valid]
 p<-h_prepare(dat,a$prep$recipe);pb<-h_prepare(dat,b$prep$recipe)
 stopifnot(identical(p,pb),identical(colnames(p$X),colnames(a$prep$data$X)))
 changed<-dat;changed$average<-NA_real_
 stopifnot(identical(p,h_prepare(changed,a$prep$recipe)))
 metadata<-data.frame(id=dat$id,name=dat$name,n=p$n,designer_group=p$group,
  designer_name=as.character(dat$designer_id),training_designer_index=ifelse(p$known==1,p$designer_index,NA),
  unseen_designer_index=ifelse(p$new_index>0,p$new_index,NA),
  observed_average=dat$average,sd_hist=p$sd_hist,n_hist=lookup$n_hist[valid],
  relative_n_diff=abs(lookup$n_hist[valid]-p$n)/p$n)
 groups<-h_groups(p)
 published<-read.csv("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_grouped_PPC.csv")
 for(j in seq_len(nrow(published))) {
  ix<-groups[[paste0("n/",published$group[j])]]
  stopifnot(length(ix)==published$games[j],abs(mean(dat$average[ix])-published$observed_mean[j])<1e-12,
   abs(var(dat$average[ix])-published$observed_variance[j])<1e-12)
 }
 ps<-read.csv("outputs/P5/M1a_Extended_ExternalSD/holdout/holdout_summary.csv")
 stopifnot(sum(valid)==ps$value[ps$metric=="matched_games"],
  abs(mean(metadata$relative_n_diff<=.05)-ps$value[ps$metric=="share_n_hist_within_5pct"])<1e-12)
 write.csv(metadata,file.path(root,"holdout_metadata.csv"),row.names=FALSE,fileEncoding="UTF-8")
 write.csv(data.frame(id=p$ids),file.path(root,"holdout_ids.csv"),row.names=FALSE)
 write.csv(data.frame(group=names(groups),games=lengths(groups)),file.path(root,"group_counts.csv"),row.names=FALSE)
 write.csv(data.frame(index=seq_along(p$new_names),designer=p$new_names,
  games=tabulate(p$new_index[p$new_index>0],nbins=length(p$new_names))),
  file.path(root,"unseen_designer_mapping.csv"),row.names=FALSE,fileEncoding="UTF-8")
 saveRDS(list(p=p,metadata=metadata,groups=groups),file.path(root,"prediction_inputs.rds"))
 writeLines(c("PASS: 3209 unique comparison-order IDs, disjoint from both 6416-game fits",
  "PASS: P5 SD audit matches all original development SD/history counts and all comparison outcomes/counts",
  "PASS: published P5 holdout group counts, observed means/variances and count-discrepancy share agree",
  "PASS: both saved recipes/X columns/maps identical; holdout response replaced before preparing inputs",
  paste("Named unseen designer groups",length(p$new_names)),
  paste("Repeated unseen named groups",sum(tabulate(p$new_index[p$new_index>0])>1)),
  "P5 per-game cache unavailable: IDs reconstructed from its matching code plus published P6 SD audit, not directly compared with unavailable IDs"),
  file.path(root,"sample_validation.txt"))
 cat("PASS: audit and frozen prediction inputs",length(p$ids),"games\n")
 print(data.frame(group=names(groups),games=lengths(groups)),row.names=FALSE)
}

if(mode %in% c("baseline","external")) {
 model<-if(mode=="baseline")"matched_baseline" else "external_sd"
 out<-file.path(root,model);source_dir<-file.path(fitroot,model)
 stopifnot(!file.exists(file.path(out,"progress.csv")),file.exists(file.path(root,"sample_validation.txt")))
 dir.create(out,showWarnings=FALSE)
 inputs<-readRDS(file.path(root,"prediction_inputs.rds"));p<-inputs$p;meta<-inputs$metadata;groups<-inputs$groups
 input<-readRDS(file.path(source_dir,"inputs.rds"));settings<-readRDS(file.path(source_dir,"run_settings.rds"))
 stopifnot(identical(input$prep$recipe,p$recipe),length(input$prep$ids)==6416,
  all(read.csv(file.path(source_dir,"diagnostics.csv"))$pass))
 expected_seeds<-if(mode=="baseline")611200L+1:4 else 611300L+1:4
 stopifnot(identical(as.integer(settings$seeds),expected_seeds))
 B<-128L;retained<-4000L;S<-4L*retained;N<-length(p$ids)
 seeds<-if(mode=="baseline")6320900L+1:4 else 6321900L+1:4
 draw_index<-data.frame(chain=rep(1:4,each=retained),retained_row=rep(seq_len(retained),4))
 write.csv(draw_index,file.path(out,"draw_index.csv"),row.names=FALSE)
 write.csv(data.frame(chain=1:4,parameter_seed=settings$seeds,prediction_seed=seeds,
  retained_draws=retained,batch_size=B,training_games=6416,holdout_games=N),
  file.path(out,"run_configuration.csv"),row.names=FALSE)
 predictions<-matrix(NA_real_,S,N)
 ppc_mean<-ppc_var<-matrix(NA_real_,S,length(groups),dimnames=list(NULL,names(groups)))
 mean_sum<-second_sum<-numeric(N);chain_lpd<-matrix(NA_real_,N,4)
 max_direct_error<-0;start<-proc.time()["elapsed"]
 progress<-NULL
 for(k in 1:4) {
  record<-readRDS(file.path(source_dir,paste0("chain_",k,".rds")))
  z<-record$draws
  stopifnot(record$chain==k,record$seed==settings$seeds[k],nrow(z)==retained,
   all(is.finite(z)),all(z[,"tau"]>0),all(z[,"sigma_d"]>0),
   ("s" %in% colnames(z))==(mode=="baseline"))
  if(mode=="baseline")stopifnot(all(z[,"s"]>=.5&z[,"s"]<=3))
  set.seed(seeds[k]);logsum<-NULL
  for(first in seq(1,retained,by=B)) {
   rows<-first:min(retained,first+B-1L);d<-z[rows,,drop=FALSE];slot<-(k-1L)*retained+rows
   moments<-h_batch(d,p,mode=="external")
   ll<-matrix(dnorm(rep(meta$observed_average,each=length(rows)),
    as.vector(moments$mean),sqrt(as.vector(moments$marginal_variance)),log=TRUE),length(rows),N)
   stopifnot(all(is.finite(ll)))
   logsum<-h_logadd(logsum,h_logmeanexp(ll)+log(length(rows)))
   mean_sum<-mean_sum+colSums(moments$mean)
   second_sum<-second_sum+colSums(moments$marginal_variance+moments$mean^2)
   repy<-h_replicate(d,p,mode=="external",moments)
   predictions[slot,]<-repy
   for(g in seq_along(groups)) {
    ix<-groups[[g]];q<-repy[,ix,drop=FALSE];mn<-rowMeans(q)
    ppc_mean[slot,g]<-mn
    ppc_var[slot,g]<-(rowSums(q^2)-length(ix)*mn^2)/(length(ix)-1)
   }
   if(first==1L) {
    for(i in unique(c(1,which(p$group=="seen_named")[1],which(p$group=="unseen_named")[1],
                     which(p$group=="missing")[1],which(p$group=="uncredited")[1],N))) {
     if(is.na(i))next
     zz<-d[1,];mu<-zz["alpha"]+sum(p$X[i,]*zz[paste0("beta[",seq_len(ncol(p$X)),"]")])
     if(p$known[i]==1)mu<-mu+zz[paste0("u[",p$designer_index[i],"]")]
     variance<-zz["tau"]^2+(1-p$known[i])*zz["sigma_d"]^2+
      if(mode=="external")p$sd_hist[i]^2/p$n[i] else zz["s"]^2/p$n[i]
     direct<--.5*(log(2*pi*variance)+(meta$observed_average[i]-mu)^2/variance)
     max_direct_error<-max(max_direct_error,abs(direct-ll[1,i]))
    }
   }
   progress<-rbind(progress,data.frame(chain=k,last_retained_row=max(rows),
    total_predictions=max(slot),elapsed_seconds=unname(proc.time()["elapsed"]-start)))
   write.csv(progress,file.path(out,"progress.csv"),row.names=FALSE)
  }
  chain_lpd[,k]<-logsum-log(retained)
  cat(model,"completed chain",k,"elapsed",round(proc.time()["elapsed"]-start,1),"s\n");flush.console()
  rm(record,z);gc()
 }
 lpd<-h_logmeanexp(t(chain_lpd));predmean<-mean_sum/S
 limits<-apply(predictions,2,quantile,probs=c(.025,.975),names=FALSE)
 result<-cbind(meta,predictive_mean=predmean,predictive_lower=limits[1,],predictive_upper=limits[2,],
  predictive_sd=sqrt(second_sum/S-predmean^2),log_predictive_density=lpd)
 result$covered_95<-with(result,observed_average>=predictive_lower&observed_average<=predictive_upper)
 result$interval_width<-result$predictive_upper-result$predictive_lower
 stopifnot(identical(dim(predictions),c(S,N)),all(is.finite(predictions)),
  all(is.finite(lpd)),max_direct_error<1e-10,identical(result$id,p$ids),!anyDuplicated(result$id))
 write.csv(result,file.path(out,"holdout_game_predictions.csv"),row.names=FALSE,fileEncoding="UTF-8")
 write.csv(data.frame(id=p$ids,chain_lpd),file.path(out,"chain_log_predictive_density.csv"),row.names=FALSE)
 summary<-do.call(rbind,lapply(seq_along(groups),function(g) {
  ix<-groups[[g]]
  data.frame(model=model,group=names(groups)[g],games=length(ix),ELPD=sum(lpd[ix]),
   mean_log_predictive_density=mean(lpd[ix]),coverage_95=mean(result$covered_95[ix]),
   mean_interval_width=mean(result$interval_width[ix]))
 }))
 ppc<-do.call(rbind,lapply(seq_along(groups),function(g) {
  ix<-groups[[g]];mn<-quantile(ppc_mean[,g],c(.025,.5,.975),names=FALSE)
  va<-quantile(ppc_var[,g],c(.025,.5,.975),names=FALSE)
  observed_mean<-mean(meta$observed_average[ix]);observed_variance<-var(meta$observed_average[ix])
  data.frame(model=model,group=names(groups)[g],games=length(ix),observed_mean=observed_mean,
   predictive_mean_low=mn[1],predictive_mean_median=mn[2],predictive_mean_high=mn[3],
   mean_in_95_interval=observed_mean>=mn[1]&observed_mean<=mn[3],observed_variance=observed_variance,
   predictive_variance_low=va[1],predictive_variance_median=va[2],predictive_variance_high=va[3],
   variance_in_95_interval=observed_variance>=va[1]&observed_variance<=va[3])
 }))
 write.csv(summary,file.path(out,"holdout_summary.csv"),row.names=FALSE)
 write.csv(ppc,file.path(out,"holdout_grouped_PPC.csv"),row.names=FALSE)
 payload<-list(ids=p$ids,draw_index=draw_index,observed_average_draws=predictions,
  grouped_mean_draws=ppc_mean,grouped_variance_draws=ppc_var,
  convention="Joint predictions of observed averages, not theta; unseen named effects shared per designer, anonymous independent",
  seeds=seeds,batch_size=B)
 saveRDS(payload,file.path(out,"predictive_draws.rds"),compress=FALSE)
 reread_draws<-readRDS(file.path(out,"predictive_draws.rds"))
 stopifnot(identical(payload,reread_draws))
 rm(reread_draws)
 reread<-read.csv(file.path(out,"holdout_game_predictions.csv"),fileEncoding="UTF-8")
 stopifnot(identical(reread$id,result$id),identical(reread$designer_group,result$designer_group),
  isTRUE(all.equal(reread$predictive_mean,result$predictive_mean,tolerance=1e-12)),
  isTRUE(all.equal(reread$log_predictive_density,result$log_predictive_density,tolerance=1e-12)))
 writeLines(c("PASS: 16000 real draw indices; 3209 ordered finite predictions; CSV/RDS reread verified",
  paste("Independent scalar Normal log-density maximum error",max_direct_error),
  "All four chains and all retained draws used; no posterior fitting; no holdout-conditioned theta",
  paste("Total prediction/export elapsed seconds",unname(proc.time()["elapsed"]-start))),
  file.path(out,"validation.txt"))
 writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))
 print(summary[1,],row.names=FALSE)
}
