# Postprocessing only. No holdout read, model fit, or WAIC computation.
source("code/P4/M1b_sd_inference.R")
root<-"outputs/P4/ExternalSD_6416"
dirs<-file.path(root,c("matched_baseline","external_sd"))
a<-readRDS(file.path(dirs[1],"inputs.rds"));b<-readRDS(file.path(dirs[2],"inputs.rds"))
stopifnot(identical(a$prep$ids,b$prep$ids),identical(a$prep$recipe,b$prep$recipe),
 identical(a$prep$data$X,b$prep$data$X),identical(a$prep$data$designer,b$prep$data$designer),
 identical(a$prep$data$known,b$prep$data$known),nrow(a$dat)==6416,
 !is.null(b$prep$data$v_obs),identical(a$model,sd_model(FALSE)),identical(b$model,sd_model(TRUE)))
da<-read.csv(file.path(dirs[1],"diagnostics.csv"));db<-read.csv(file.path(dirs[2],"diagnostics.csv"))
out<-file.path(root,"comparison");dir.create(out,showWarnings=FALSE)
comparison<-merge(da,db,by="parameter",all=TRUE,suffixes=c("_baseline","_external"))
comparison$mean_change<-comparison$mean_external-comparison$mean_baseline
comparison$change_mcse<-sqrt(comparison$mcse_mean_baseline^2+comparison$mcse_mean_external^2)
write.csv(comparison,file.path(out,"all_parameters.csv"),row.names=FALSE)
main<-comparison[comparison$parameter %in% c("alpha","tau","sigma_d","s"),]
write.csv(main,file.path(out,"scales.csv"),row.names=FALSE)
bet<-comparison[match(paste0("beta[",seq_len(a$prep$data$P),"]"),comparison$parameter),]
bet$term<-colnames(a$prep$data$X)
bet$same_mean_direction<-sign(bet$mean_baseline)==sign(bet$mean_external)
bet$baseline_interval_excludes_zero<-bet$lower95_baseline>0|bet$upper95_baseline<0
bet$external_interval_excludes_zero<-bet$lower95_external>0|bet$upper95_external<0
write.csv(bet,file.path(out,"coefficients.csv"),row.names=FALSE)
designer<-comparison[match(paste0("u[",seq_len(a$prep$data$J),"]"),comparison$parameter),]
designer$designer<-a$prep$recipe$designers
designer$training_games<-tabulate(a$prep$data$designer[a$prep$data$known==1],nbins=a$prep$data$J)
write.csv(designer,file.path(out,"designer_effects.csv"),row.names=FALSE,fileEncoding="UTF-8")
write.csv(data.frame(metric=c("same_IDs_order","same_covariates","same_recipe_mapping",
 "baseline_all_diagnostics_pass","external_all_diagnostics_pass"),value=c(TRUE,TRUE,TRUE,all(da$pass),all(db$pass))),
 file.path(out,"verification.csv"),row.names=FALSE)

# Common deterministic 125/chains spread over retained rows. Preserve real indices.
summaries<-list()
for(k in 1:2) {
 input<-if(k==1)a else b;d<-input$prep$data
 chains<-m1b_read_chains(dirs[k]);nr<-nrow(chains[[1]])
 stopifnot(("s" %in% colnames(chains[[1]]))==(k==1))
 within<-unique(as.integer(round(seq(1,nr,length.out=125))))
 stopifnot(length(within)==125)
 idx<-data.frame(chain=rep(1:4,each=125),iteration=rep(within,4))
 theta<-cm<-weights<-ll<-matrix(NA_real_,500,6416)
 set.seed(611400+k)
 maxerr<-0
 for(j in 1:500) {
  z<-chains[[idx$chain[j]]][idx$iteration[j],]
  mu<-as.numeric(z["alpha"]+d$X%*%z[paste0("beta[",1:d$P,"]")]+
   d$known*z[paste0("u[",d$designer,"]")])
  noise<-if(k==2)d$v_obs else z["s"]^2/d$n
  t2<-z["tau"]^2+(1-d$known)*z["sigma_d"]^2
  moments<-sd_latent(d$y,mu,z["tau"],z["sigma_d"],d$known,noise)
  cm[j,]<-moments$mean;weights[j,]<-moments$weight
  theta[j,]<-rnorm(6416,moments$mean,moments$sd)
  ll[j,]<-dnorm(d$y,mu,sqrt(t2+noise),log=TRUE)
  if(j %in% c(1,125,126,250,251,375,376,500)) {
   direct<--.5*(log(2*pi*(t2+noise))+(d$y-mu)^2/(t2+noise))
   maxerr<-max(maxerr,max(abs(direct-ll[j,])))
  }
 }
 stopifnot(maxerr<1e-10,all(is.finite(ll)),all(is.finite(theta)))
 colnames(ll)<-as.character(input$prep$ids)
 convention<-paste("Game-average Normal loglik; theta integrated; named training u conditioned; anonymous independent u integrated sigma_d^2;",
  if(k==2)"fixed historical SD squared/current n" else "original s~Uniform(0.5,3), observation variance s^2/n",
  "6416-game sample only; NOT numerically comparable with 6489-game WAIC")
 payload<-list(ids=input$prep$ids,draw_index=idx,loglik=ll,convention=convention,
   train_md5=unname(tools::md5sum("dev_subsample.csv")),model=input$model,
   source_manifest=read.csv(file.path(root,"source_manifest.csv")))
 path<-file.path(dirs[k],"pointwise_loglik_share.rds")
 saveRDS(payload,path,compress="gzip");stopifnot(identical(readRDS(path),payload))
 saveRDS(list(ids=input$prep$ids,draw_index=idx,theta_draws=t(theta),
    note="500 joint draws, 125 balanced real retained rows per chain"),file.path(dirs[k],"latent_draws_share_local.rds"))
 write.csv(idx,file.path(dirs[k],"share_draw_index.csv"),row.names=FALSE)
 # MCSE of conditional posterior means from the ordered thinned chains, not theta SD.
 means<-colMeans(cm)
 mcse<-vapply(seq_len(6416),function(i)posterior::mcse_mean(matrix(cm[,i],125,4)),0)
 summaries[[k]]<-data.frame(id=input$prep$ids,n=d$n,known=d$known,raw=d$y,
  mean=means,mean_mcse=mcse,lower95=apply(theta,2,quantile,.025),upper95=apply(theta,2,quantile,.975),
  adjustment=means-d$y,weight=colMeans(weights))
 write.csv(summaries[[k]],file.path(dirs[k],"balanced_latent_summary.csv"),row.names=FALSE)
 writeLines(c(paste("PASS: share",nrow(ll),ncol(ll),"finite; 125 real draws/chain; indices preserved; reread exact"),
  paste("Independent loglik maximum absolute error",maxerr),
  paste("All original chain diagnostic thresholds met",all(if(k==1)da$pass else db$pass)),
  paste("RDS bytes",file.info(path)$size)),file.path(dirs[k],"export_validation.txt"))
 rm(chains,theta,cm,weights,ll);gc()
}
x<-summaries[[1]];y<-summaries[[2]]
pergame<-data.frame(id=x$id,n=x$n,known=x$known,baseline_mean=x$mean,external_mean=y$mean,
 mean_change=y$mean-x$mean,change_mcse=sqrt(x$mean_mcse^2+y$mean_mcse^2),
 baseline_adjustment=x$adjustment,external_adjustment=y$adjustment)
write.csv(pergame,file.path(out,"latent_changes.csv"),row.names=FALSE)
groups<-list(all=1:6416,n30_40=which(x$n<=40),n30_100=which(x$n<=100),
 n100_200=which(x$n>=100&x$n<=200),n1000_5000=which(x$n>=1000&x$n<=5000),n5000plus=which(x$n>5000))
grouped<-do.call(rbind,lapply(names(groups),function(g){i<-groups[[g]]
 data.frame(group=g,games=length(i),median_abs_change=median(abs(y$mean[i]-x$mean[i])),
 baseline_median_abs_adjustment=median(abs(x$adjustment[i])),external_median_abs_adjustment=median(abs(y$adjustment[i])),
 median_change_mcse=median(pergame$change_mcse[i]),baseline_mean_weight=mean(x$weight[i]),external_mean_weight=mean(y$weight[i]))}))
write.csv(grouped,file.path(out,"grouped_shrinkage.csv"),row.names=FALSE)
pa<-read.csv(file.path(dirs[1],"development_PPC.csv"));pb<-read.csv(file.path(dirs[2],"development_PPC.csv"))
stopifnot(identical(pa$group,pb$group),identical(pa$games,pb$games))
write.csv(merge(pa,pb,by=c("group","games","observed_mean","observed_variance"),suffixes=c("_baseline","_external")),
 file.path(out,"PPC_comparison.csv"),row.names=FALSE)
png(file.path(out,"designer_effects.png"),1500,750,res=150)
par(mfrow=c(1,2),mar=c(4,4,2,1))
plot(designer$mean_baseline,designer$mean_external,pch=16,cex=.4,col=adjustcolor("#0072B2",.35),
 xlab="Same-sample original M1b designer mean",ylab="ExternalSD designer mean");abline(0,1,col="grey50")
plot(designer$training_games,designer$mean_change,log="x",pch=16,cex=.4,
 col=adjustcolor("#D55E00",.35),xlab="Games per named designer (log axis)",ylab="External minus original designer mean");abline(h=0,col="grey50")
dev.off()
png(file.path(out,"latent_changes.png"),1200,800,res=150)
plot(log10(x$n),pergame$mean_change,pch=16,cex=.35,col=adjustcolor("#009E73",.3),
 xlab="log10(rating count)",ylab="ExternalSD minus same-sample original theta mean");abline(h=0,col="grey50");dev.off()
# Original 6489 fit only supplementary parameter reference, never WAIC comparison.
old<-read.csv("outputs/P4/baseline_development/diagnostics.csv")
stopifnot(identical(colnames(a$prep$data$X),read.csv("outputs/P4/baseline_development/design_columns.csv")$term))
supp<-merge(comparison,old,by="parameter",suffixes=c("","_6489_reference"))
write.csv(supp[!grepl("^u\\[",supp$parameter),],file.path(out,"supplementary_6489_parameters.csv"),row.names=FALSE)
cat("PASS: same-sample comparison, designer associations, balanced shares and PPC exported; no WAIC computed\n")
