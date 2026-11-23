# Standalone full-development s-prior comparison; never read holdout.
source("code/P4/M1b_inference.R")
aout<-"outputs/P4/baseline_development";bout<-"outputs/P4/sensitivity_s_upper6"
ia<-readRDS(file.path(aout,"inputs.rds"));ib<-readRDS(file.path(bout,"inputs.rds"))
stopifnot(identical(ia$prep$ids,ib$prep$ids),identical(ia$prep$recipe,ib$prep$recipe),
          identical(ia$prep$data,ib$prep$data))
stopifnot(identical(sub("s ~ dunif(0.5, 3)","s ~ dunif(0.5, 6)",ia$model,fixed=TRUE),ib$model))
out<-"outputs/P4/s_prior_comparison"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
a<-read.csv(file.path(aout,"latent_ratings.csv"));b<-read.csv(file.path(bout,"latent_ratings.csv"))
stopifnot(identical(a$id,b$id))
da<-read.csv(file.path(aout,"diagnostics.csv"));db<-read.csv(file.path(bout,"diagnostics.csv"))
ac<-m1b_read_chains(aout);bc<-m1b_read_chains(bout)
merged<-merge(da,db,by="parameter",suffixes=c("_baseline","_upper6"))
merged$mean_change<-merged$mean_upper6-merged$mean_baseline
merged$change_in_baseline_sd<-merged$mean_change/merged$sd_baseline
write.csv(merged,file.path(out,"parameter_comparison.csv"),row.names=FALSE)
beta_names<-paste0("beta[",seq_len(ia$prep$data$P),"]")
coef<-merged[match(beta_names,merged$parameter),]
coef$term<-colnames(ia$prep$data$X)
coef$p_positive_baseline<-vapply(beta_names,function(v)mean(vapply(ac,function(z)mean(z[,v]>0),0)),0)
coef$p_positive_upper6<-vapply(beta_names,function(v)mean(vapply(bc,function(z)mean(z[,v]>0),0)),0)
coef$sign_of_mean_agrees<-sign(coef$mean_baseline)==sign(coef$mean_upper6)
coef$interval_excludes_zero_baseline<-coef$lower95_baseline>0|coef$upper95_baseline<0
coef$interval_excludes_zero_upper6<-coef$lower95_upper6>0|coef$upper95_upper6<0
write.csv(coef,file.path(out,"coefficient_comparison.csv"),row.names=FALSE)
per_game<-data.frame(id=a$id,n=a$n,known=a$known,baseline_mean=a$mean,upper6_mean=b$mean,
  mean_change=b$mean-a$mean,baseline_adjustment=a$adjustment,upper6_adjustment=b$adjustment,
  baseline_weight=a$weight,upper6_weight=b$weight)
write.csv(per_game,file.path(out,"per_game_changes.csv"),row.names=FALSE)
groups<-list(all=seq_len(nrow(a)),n30_100=which(a$n<=100),n101_1000=which(a$n>100&a$n<=1000),
  n1000plus=which(a$n>1000),named=which(a$known==1),anonymous=which(a$known==0))
grouped<-do.call(rbind,lapply(names(groups),function(g) {
  ix<-groups[[g]]
  data.frame(group=g,games=length(ix),median_absolute_theta_change=median(abs(b$mean[ix]-a$mean[ix])),
    baseline_median_abs_adjustment=median(abs(a$adjustment[ix])),
    upper6_median_abs_adjustment=median(abs(b$adjustment[ix])),
    baseline_mean_weight=mean(a$weight[ix]),upper6_mean_weight=mean(b$weight[ix]))
}))
write.csv(grouped,file.path(out,"grouped_shrinkage.csv"),row.names=FALSE)
top<-function(x)order(x,decreasing=TRUE)[1:50]
metrics<-c(baseline_diagnostic_pass=all(da$pass),upper6_diagnostic_pass=all(db$pass),
  median_absolute_theta_change=median(abs(b$mean-a$mean)),max_absolute_theta_change=max(abs(b$mean-a$mean)),
  within_sample_rank_spearman=cor(a$mean,b$mean,method="spearman"),top50_overlap=length(intersect(top(a$mean),top(b$mean))),
  baseline_median_abs_adjustment=median(abs(a$adjustment)),upper6_median_abs_adjustment=median(abs(b$adjustment)),
  slopes_with_same_mean_sign=sum(coef$sign_of_mean_agrees),slopes=length(beta_names),
  strong_baseline_effects=sum(coef$interval_excludes_zero_baseline),
  strong_baseline_effects_retain_direction=sum(!coef$interval_excludes_zero_baseline|coef$sign_of_mean_agrees)-sum(!coef$interval_excludes_zero_baseline),
  baseline_s_above_2_95=mean(vapply(ac,function(z)mean(z[,"s"]>2.95),0)),
  upper6_s_above_5_95=mean(vapply(bc,function(z)mean(z[,"s"]>5.95),0)))
write.csv(data.frame(metric=names(metrics),value=unname(metrics)),file.path(out,"summary.csv"),row.names=FALSE)
png(file.path(out,"s_prior_and_posterior.png"),1400,900,res=150)
as<-unlist(lapply(ac,function(z)z[,"s"]));bs<-unlist(lapply(bc,function(z)z[,"s"]))
baseline_density<-density(as,from=.5,to=3)
upper6_density<-density(bs,from=.5,to=6)
plot(upper6_density,col="#D55E00",lwd=2,xlim=c(.5,6),
     ylim=c(0,1.05*max(baseline_density$y,upper6_density$y)),
     xlab="Shared rating SD s",main="Development-only s prior sensitivity")
lines(baseline_density,col="#0072B2",lwd=2)
segments(.5,1/2.5,3,1/2.5,col="#0072B2",lty=2)
segments(.5,1/5.5,6,1/5.5,col="#D55E00",lty=2)
legend("topright",c("Baseline posterior","Upper-6 posterior","Baseline prior","Upper-6 prior"),
       col=c("#0072B2","#D55E00","#0072B2","#D55E00"),lty=c(1,1,2,2),lwd=2,bty="n")
dev.off()
png(file.path(out,"latent_sensitivity.png"),1500,750,res=150)
par(mfrow=c(1,2),mar=c(4,4,2,1))
plot(a$mean,b$mean,pch=16,cex=.3,col=adjustcolor("#0072B2",.35),xlab="Baseline theta mean",ylab="Upper-6 theta mean");abline(0,1,col="grey40")
plot(log10(a$n),b$mean-a$mean,pch=16,cex=.3,col=adjustcolor("#D55E00",.35),xlab="log10(number of ratings)",ylab="Upper-6 minus baseline theta mean");abline(h=0,col="grey40")
dev.off()
writeLines(c("Same complete development games and identical preprocessing; only s prior upper limit changes.",
  "Baseline U(0.5,3) remains the baseline. U(0.5,6) is an explicitly relaxed boundary stress test.",
  "No holdout outcomes or formal model-comparison sample used.",
  "All diagnostics and covariance/scale caveats must accompany interpretation.",
  "Conditional theta means are Rao-Blackwellized over 1000 selected posterior draws; small per-game differences retain Monte Carlo error.",
  "Ranks and Top 50 overlap are within-development descriptive results, not global BGG rankings.",
  "Development PPC is in each run directory and is not held-out prediction."),file.path(out,"interpretation_notes.txt"))
cat("Saved development-only baseline versus s-upper6 comparison\n")
