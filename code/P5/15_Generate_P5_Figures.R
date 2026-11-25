# STAT6106 P5 -- presentation-ready figures, using existing results only.
# Run from the root of the updated GitHub repository (source this script).
# Base R only. No model fitting, downloads, JAGS, or modification of existing results.
# The six PNGs and plotting checks are saved to figures/P5/.
options(stringsAsFactors=FALSE)
root <- normalizePath(getwd(), winslash="/", mustWork=TRUE)
while (!file.exists(file.path(root,"outputs/P5/M1a_Baseline/parameter_draws.rds"))) {
  parent <- dirname(root)
  if (identical(parent,root)) stop("Set RStudio working directory to the downloaded repository root (contains code/ and outputs/).")
  root <- parent
}
p5 <- file.path(root,"outputs/P5")
out <- file.path(root,"figures/P5")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
rd <- function(p) read.csv(file.path(p5,p),check.names=FALSE)
rds <- function(p) readRDS(file.path(p5,p))
A <- rds("M1a_Baseline/parameter_draws.rds")
D <- rds("M1a_Extended_ExternalSD/parameter_draws.rds")
tr <- rd("M1a_Extended_ExternalSD/P5_SD_matched.csv")
sh <- rd("M1a_Model_Comparison/shrinkage_summary.csv")
pp <- rd("M1a_Model_Comparison/holdout_grouped_PPC.csv")
ss <- rd("Sensitivity_Analysis/External_SD/SD_sensitivity_summary.csv")
ps <- rd("Sensitivity_Analysis/Priors/prior_sensitivity_summary.csv")
hs <- rd("Holdout_Comparison_3209/holdout_four_model_summary.csv")
hp <- rd("Holdout_Comparison_3209/holdout_pairwise_differences.csv")
ws <- rd("WAIC_Comparison_6416/WAIC_four_model_summary.csv")
stopifnot(nrow(tr)==6416L,!anyDuplicated(tr$id),
          identical(as.character(A$ids),as.character(tr$id)),
          isTRUE(all.equal(as.numeric(D$x_center),mean(log(tr$n_2022)),tolerance=1e-9)),
          all(is.finite(tr$average_2022)),all(tr$n_2022>=30),
          all(is.finite(tr$sd_hist)&tr$sd_hist>0),
          all(hs$games==3209),all(ws$games==6416),all(ws$posterior_draws==500))
za <- as.matrix(A$draws); zd <- as.matrix(D$draws)
stopifnot(all(c("alpha","s","tau") %in% colnames(za)),
          all(c("alpha","gamma","a_tau","b_tau") %in% colnames(zd)),
          all(is.finite(za)),all(is.finite(zd)),nrow(za)>=1000,nrow(zd)>=1000,
          all(za[,"s"]>=0.5 & za[,"s"]<=3))
# Same deterministic selection and analytical conditional posterior mean as Script 07.
sel <- function(z) z[unique(as.integer(round(seq(1,nrow(z),length.out=1000L)))),,drop=FALSE]
aa <- sel(za); dd <- sel(zd)
n <- tr$n_2022; y <- tr$average_2022; x <- log(n)-D$x_center
ra <- re <- numeric(length(y))
for (j in seq_len(nrow(aa))) {
  d <- aa[j,]; w <- d["tau"]^2/(d["tau"]^2+d["s"]^2/n)
  ra <- ra+d["alpha"]+w*(y-d["alpha"])
}
for (j in seq_len(nrow(dd))) {
  d <- dd[j,]; mu <- d["alpha"]+d["gamma"]*x
  tau2 <- exp(2*(d["a_tau"]+d["b_tau"]*x))
  w <- tau2/(tau2+tr$sd_hist^2/n)
  re <- re+mu+w*(y-mu)
}
adjA <- abs(ra/nrow(aa)-y); adjD <- abs(re/nrow(dd)-y)
ma <- median(adjA); md <- median(adjD)
get_sh <- function(k) sh$value[match(k,sh$metric)]
stopifnot(abs(ma-get_sh("Baseline_median_abs_adjustment"))<1e-8,
          abs(md-get_sh("Extended_median_abs_adjustment"))<1e-8)
# P6-inspired palette; all data-derived values are read or calculated above.
ink <- "#1a1a19"; muted <- "#52514e"; grid <- "#e5e4e0"; bg <- "#fcfcfb"
blue <- "#2a78d6"; orange <- "#eb6834"; aqua <- "#1baf7a"; gray <- "#777777"
model_names <- c("M1a_Baseline","M1a_Extended","M1b_Baseline","M1b_ExternalSD")
model_labels <- c("M1a Baseline","M1a Extended","M1b Baseline","M1b External SD")
model_colors <- c(orange,blue,orange,blue)
hs <- hs[match(model_names,hs$model),]; ws <- ws[match(model_names,ws$model),]
stopifnot(!anyNA(hs$model),!anyNA(ws$model))
fmt <- function(z,d=2) formatC(z,digits=d,format="f",big.mark=",")
openfig <- function(name,w=10.5,h=5.8,panels=c(1,2),mar=c(4.7,4.7,2.4,1.2)) {
  png(file.path(out,name),width=w,height=h,units="in",res=240,bg=bg,pointsize=13)
  par(mfrow=panels,mar=mar,oma=c(2.6,0.5,3.4,0.5),
      family="sans",col=ink,col.axis=muted,col.lab=muted,col.main=ink,
      las=1,bty="n",mgp=c(2.6,.75,0),xaxs="r",yaxs="r")
}
closefig <- function(title,caption) {
  mtext(title,side=3,outer=TRUE,line=1.6,adj=0,font=2,cex=1.28,col=ink)
  mtext(caption,side=1,outer=TRUE,line=.7,adj=0,cex=.79,col=muted)
  dev.off()
}
# 1. Prior and posterior of s. Same histogram normalization in both panels.
h <- hist(za[,"s"],breaks=seq(.5,3,by=.01),plot=FALSE,include.lowest=TRUE)
openfig("fig01_prior_posterior_s.png")
for (lim in list(c(.5,3),c(2.75,3))) {
  plot(h,freq=FALSE,xlim=lim,ylim=c(0,max(h$density)*1.09),col=blue,border=NA,
       xlab="Shared noise parameter s",ylab="Density",
       main=if(lim[1]==.5) "Full prior support" else "Zoom near upper bound")
  abline(h=1/(3-.5),col=orange,lwd=2,lty=2)
  abline(v=3,col=gray,lty=3,lwd=1.5)
  if(lim[1]==.5) legend("topleft",c("Posterior draws","Uniform(0.5, 3) prior"),
                        lty=c(1,2),
                        col=c(blue,orange),lwd=c(NA,2),bty="n",cex=.82)
  if(lim[1]> .5) legend("topleft",c(paste("Mean:",fmt(mean(za[,"s"]),3)),
    paste("95% CrI:",paste(fmt(quantile(za[,"s"],c(.025,.975)),3),collapse=" to "))),
    bty="n",cex=.8)
}
closefig("The baseline noise parameter is concentrated near its prior bound",
         "6,416 development games | Original M1a Baseline | The prior-sensitive s is not a reliably identified rater SD.")
# 2. Rating adjustment by disjoint rating-count bands. Medians and IQR, not fitted trends.
bands <- cut(n,breaks=c(30,50,100,200,500,1000,5000,Inf),right=FALSE,
             labels=c("30-49","50-99","100-199","200-499","500-999","1k-4,999","5k+"))
stopifnot(!anyNA(bands),all(table(bands)>0))
qfun <- function(z) t(vapply(levels(bands),function(g) quantile(z[bands==g],c(.25,.5,.75),names=FALSE),numeric(3)))
qa <- qfun(adjA); qe <- qfun(adjD); k <- seq_len(nrow(qa))
openfig("fig02_rating_shrinkage.png",w=10.8,h=5.7,panels=c(1,1),mar=c(5.3,5,2.3,1.5))
plot(k,qa[,2],type="n",ylim=c(0,max(qa,qe)*1.15),xlim=c(.55,length(k)+.45),
     xaxt="n",xlab="",ylab="Absolute rating adjustment (points)",main="")
abline(h=axTicks(2),col=grid,lwd=.8)
axis(1,at=k,labels=paste0(levels(bands),"\n(n=",as.integer(table(bands)),")"),cex.axis=.78)
mtext("Rating count band",side=1,line=3.7,col=muted)
for (i in 1:2) {
  q <- if(i==1) qa else qe; xx <- k+c(-.12,.12)[i]; cc <- c(orange,blue)[i]
  arrows(xx,q[,1],xx,q[,3],angle=90,code=3,length=.045,col=cc,lwd=2)
  lines(xx,q[,2],col=cc,lwd=1.5);points(xx,q[,2],pch=if(i==1) 16 else 17,col=cc,cex=1.15)
}
legend("topright",c(paste0("Baseline (overall median ",fmt(ma,4),")"),
                     paste0("Extended (overall median ",fmt(md,4),")")),
       pch=c(16,17),col=c(orange,blue),lwd=2,bty="n",cex=.85)
closefig("The Extended model makes smaller rating adjustments",
         "Same 6,416 development games | Points: median absolute adjustment; bars: interquartile range, not credible intervals.")
# 3. PPC on four selected holdout bands, means and variances.
grp <- c("30-40","100-200","1000-5000","5000+")
# Explicit matching by model and group, independent of CSV row order.
pa <- pp[match(paste("M1a_Baseline",grp),paste(pp$model,pp$group)),]
pe <- pp[match(paste("M1a_Extended_ExternalSD",grp),paste(pp$model,pp$group)),]
stopifnot(!anyNA(pa$group),!anyNA(pe$group),all(pa$games==pe$games))
openfig("fig03_grouped_holdout_ppc.png",w=11,h=5.7)
for (v in c("mean","variance")) {
  obs <- pa[[paste0("observed_",v)]]
  stopifnot(all(obs==pe[[paste0("observed_",v)]]))
  lo <- paste0("pred_",v,"_low"); hi <- paste0("pred_",v,"_high"); med <- paste0("pred_",v,"_median")
  yr <- range(obs,pa[[lo]],pa[[hi]],pe[[lo]],pe[[hi]])
  plot(1:4,obs,type="n",xaxt="n",xlim=c(.6,4.4),ylim=yr+diff(yr)*c(-.08,.14),
       xlab="Selected rating count band",ylab=if(v=="mean") "Group mean rating" else "Group rating variance",
       main=if(v=="mean") "Predictive mean" else "Predictive variance")
  abline(h=axTicks(2),col=grid)
  axis(1,at=1:4,labels=c("30-40","100-200","1k-5k","5k+"),cex.axis=.84)
  for(i in 1:2) {
    p <- if(i==1) pa else pe; xx <- (1:4)+c(-.12,.12)[i]; cc <- c(orange,blue)[i]
    arrows(xx,p[[lo]],xx,p[[hi]],angle=90,code=3,length=.045,col=cc,lwd=2)
    points(xx,p[[med]],pch=if(i==1) 16 else 17,col=cc,cex=1.1)
  }
  points(1:4,obs,pch=4,col=ink,lwd=2,cex=1.2)
  legend(if(v=="mean") "topleft" else "topright",c("Baseline","Extended","Observed"),
         pch=c(16,17,4),col=c(orange,blue,ink),bty="n",cex=.77)
}
closefig("The Extended model better captures rating-count-dependent patterns",
         "Exploratory holdout | Four selected groups (not all 3,209 games) | Bars: 95% predictive intervals; crosses: observed statistics.")
# 4. Sensitivity: actual SD scale results and tested prior scenarios.
ss <- ss[order(ss$sd_factor),]
ps <- ps[match(c("baseline","tau_tighter","tau_wider","gamma_tighter","gamma_wider"),ps$scenario),]
stopifnot(all(ss$games==6416),all(ps$games==6416),!anyNA(ps$scenario))
openfig("fig04_sensitivity.png",w=11,h=5.7)
plot(ss$sd_factor,ss$median_effective_pseudo_votes,type="b",pch=16,col=blue,lwd=2,
     ylim=c(0,max(ss$median_effective_pseudo_votes)*1.25),xaxt="n",
     xlab="Historical SD multiplier",ylab="Median effective pseudo-votes",main="External SD sensitivity")
axis(1,at=ss$sd_factor,labels=paste0(ss$sd_factor,"x"));abline(h=axTicks(2),col=grid)
text(ss$sd_factor,ss$median_effective_pseudo_votes,labels=fmt(ss$median_effective_pseudo_votes),pos=3,cex=.9)
plot(1:5,ps$median_effective_pseudo_votes,type="n",xaxt="n",
     ylim=c(0,max(ps$median_effective_pseudo_votes)*1.27),xlab="Tested prior scenario",
     ylab="Median effective pseudo-votes",main="Prior sensitivity")
abline(h=axTicks(2),col=grid);axis(1,at=1:5,labels=c("Base","Tau\ntight","Tau\nwide","Gamma\ntight","Gamma\nwide"),cex.axis=.78)
lines(1:5,ps$median_effective_pseudo_votes,col=blue,lwd=2);points(1:5,ps$median_effective_pseudo_votes,col=blue,pch=17,cex=1.1)
text(1:5,ps$median_effective_pseudo_votes,labels=fmt(ps$median_effective_pseudo_votes),pos=3,cex=.78)
mtext(paste("Top-50 overlap:",min(ps$top50_overlap_with_baseline),"/ 50 in all scenarios"),side=3,line=.05,cex=.7,col=muted)
closefig("Small adjustments persist across the tested assumptions",
         "6,416 development games only | Extended model | Pseudo-votes summarized as median of gamewise posterior means.")
# 5. ELPD absolute values and within-family paired changes, with cluster SE.
p <- hp[match(c("M1a_Extended M1a_Baseline","M1b_ExternalSD M1b_Baseline"),paste(hp$model_A,hp$model_B)),]
stopifnot(nrow(p)==2L,!anyNA(p$delta_ELPD_A_minus_B))
openfig("fig05_four_model_holdout.png",w=11.4,h=5.8,mar=c(4.6,7.5,2.4,1.5))
yy <- 4:1
plot(hs$ELPD,yy,pch=16,col=model_colors,cex=1.35,yaxt="n",ylim=c(.5,4.5),
     xlim=c(min(hs$ELPD)-200,max(hs$ELPD)+430),xlab="Holdout ELPD (higher is better)",ylab="",main="Four-model comparison")
axis(2,at=yy,labels=model_labels,las=1,cex.axis=.85)
abline(v=axTicks(1),col=grid);points(hs$ELPD,yy,pch=16,col=model_colors,cex=1.35)
text(hs$ELPD,yy,labels=fmt(hs$ELPD),pos=4,cex=.83)
par(mar=c(4.6,5.6,2.4,1.3))
plot(p$delta_ELPD_A_minus_B,2:1,type="n",yaxt="n",ylim=c(.45,2.55),
     xlim=range(0,p$approx95_lower,p$approx95_upper)+c(-30,30),
     xlab="Change in ELPD (Extended - Baseline)",ylab="",main="Paired within-family differences")
axis(2,at=2:1,labels=c("M1a","M1b"),las=1);abline(v=0,lty=2,col=gray,lwd=1.5)
arrows(p$approx95_lower,2:1,p$approx95_upper,2:1,angle=90,code=3,length=.06,col=blue,lwd=2)
points(p$delta_ELPD_A_minus_B,2:1,pch=17,col=blue,cex=1.25)
text(p$delta_ELPD_A_minus_B,2:1,labels=fmt(p$delta_ELPD_A_minus_B),pos=3,cex=.85)
closefig("M1b Baseline has the highest exploratory holdout ELPD",
         "Same 3,209 games | Paired intervals: +/- 1.96 designer-cluster SE (descriptive) | M1a 1,000 draws; M1b 16,000 draws.")
# 6. Matched WAIC and warning fractions; no claims of definitive predictive ranking.
openfig("fig06_four_model_waic.png",w=11.4,h=5.8,mar=c(4.6,7.5,2.4,1.5))
plot(ws$WAIC,yy,pch=16,col=model_colors,cex=1.35,yaxt="n",ylim=c(.5,4.5),
     xlim=c(min(ws$WAIC)-650,max(ws$WAIC)+2000),xlab="Development WAIC (lower is better)",ylab="",main="Same-sample WAIC")
axis(2,at=yy,labels=model_labels,las=1,cex.axis=.85);abline(v=axTicks(1),col=grid)
points(ws$WAIC,yy,pch=16,col=model_colors,cex=1.35);text(ws$WAIC,yy,labels=fmt(ws$WAIC,1),pos=4,cex=.83)
par(mar=c(4.6,7.5,2.4,1.6))
pct <- 100*ws$fraction_pointwise_p_waic_gt_0_4
plot(pct,yy,type="n",yaxt="n",ylim=c(.5,4.5),xlim=c(0,max(pct)*1.55),
     xlab="Games with pointwise p-WAIC > 0.4 (%)",ylab="",main="WAIC reliability warnings")
axis(2,at=yy,labels=model_labels,las=1,cex.axis=.8)
abline(v=axTicks(1),col=grid)
segments(0,yy,pct,yy,col=model_colors,lwd=5);points(pct,yy,pch=16,col=model_colors)
text(pct,yy,labels=paste0(fmt(pct,2),"% (",ws$n_pointwise_p_waic_gt_0_4,")"),pos=4,cex=.8)
closefig("M1b has lower numerical WAIC, but many reliability warnings",
         "Same 6,416 development games | 500 draws/model | M1b conditions on learned named-designer effects; prioritize holdout.")
checks <- c("P5 figure generation checks",
  paste("Source:",root),paste("Baseline posterior draws:",nrow(za)),
  paste("Extended posterior draws:",nrow(zd)),
  "Development IDs and order (Baseline vs matched data): PASS",
  "Extended training centering: PASS (saved object has no independent ID vector)",
  paste("Script 07 shrinkage recomputation, Baseline median:",format(ma,digits=16)),
  paste("Script 07 shrinkage recomputation, Extended median:",format(md,digits=16)),
  "Both match archived shrinkage summary within 1e-8: PASS",
  "Four-model holdout and WAIC sample sizes: PASS",
  "No model fitted; inputs not changed.",
  "Figures: fig01_prior_posterior_s.png, fig02_rating_shrinkage.png, fig03_grouped_holdout_ppc.png, fig04_sensitivity.png, fig05_four_model_holdout.png, fig06_four_model_waic.png")
writeLines(checks,file.path(out,"P5_figure_checks.txt"))
cat(paste(checks,collapse="\n"),"\n\nDONE:",out,"\n")
