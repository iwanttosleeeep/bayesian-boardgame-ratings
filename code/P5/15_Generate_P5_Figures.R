# STAT6106 P5 -- presentation-ready figures, using existing results only.
# Run in the SAME RStudio working directory as Script 13, or a full repo clone.
# Base R only. No model fitting, downloads, JAGS, or modification of existing results.
# Local mode uses the three original input files plus embedded, archived summary CSVs.
# The six PNGs and plotting checks are saved to figures/P5/.
options(stringsAsFactors=FALSE)
root <- normalizePath(getwd(), winslash="/", mustWork=TRUE)
repo_ok <- function(p) file.exists(file.path(p,"outputs/P5/M1a_Baseline/parameter_draws.rds"))
local_ok <- function(p) file.exists(file.path(p,"P5_external_SD/Model_A_same_6416/parameter_draws.rds"))
while (!repo_ok(root) && !local_ok(root)) {
  parent <- dirname(root)
  if (identical(parent,root)) stop("Use the same RStudio working directory as Script 13 (parent of P5_external_SD), or the repository root.")
  root <- parent
}
repo_mode <- repo_ok(root)
p5 <- file.path(root,"outputs/P5")
base <- file.path(root,"P5_external_SD")
out <- file.path(root,"figures/P5")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
# Exact text of seven validated GitHub CSVs; no network access needed in local mode.
# These are the archived November 2026 comparisons, not synthetic data.
archived <- list(
  # GitHub blob 0ff324ec409e2f7b0afc522e1054d28215ccd7ff
  "M1a_Model_Comparison/shrinkage_summary.csv" = "\"metric\",\"value\"\n\"development_games_each\",6416\n\"Baseline_median_abs_adjustment\",0.0359955663193721\n\"Extended_median_abs_adjustment\",0.00950903637682421\n\"median_abs_rating_difference\",0.0255837579362366\n\"p95_abs_rating_difference\",0.239352892449841\n\"max_abs_rating_difference\",0.867188321721243\n\"Baseline_median_shrinkage_weight\",0.915041081366871\n\"Extended_median_shrinkage_weight\",0.978602491693122\n\"development_top50_overlap\",36",
  # GitHub blob 006550e6fafde8d47b4fe027d0b4e0c47f539a22
  "M1a_Model_Comparison/holdout_grouped_PPC.csv" = "\"model\",\"group\",\"games\",\"observed_mean\",\"pred_mean_median\",\"pred_mean_low\",\"pred_mean_high\",\"mean_in_95_interval\",\"observed_variance\",\"pred_variance_median\",\"pred_variance_low\",\"pred_variance_high\",\"variance_in_95_interval\",\"individual_95_coverage\"\n\"M1a_Baseline\",\"30-40\",398,6.11768844221106,6.42675735210097,6.32945215645426,6.5264445558758,FALSE,1.01633570117591,1.00999336479255,0.882127814477412,1.1557267197608,TRUE,0.942211055276382\n\"M1a_Baseline\",\"100-200\",600,6.36781666666667,6.4295635739083,6.34985013055338,6.50455834543458,TRUE,0.802528614079021,0.818000877391657,0.729112503500767,0.908113269693048,TRUE,0.951666666666667\n\"M1a_Baseline\",\"1000-5000\",312,6.87522435897436,6.43104397136368,6.33758103215545,6.52722609900287,FALSE,0.424190303198945,0.756741357738677,0.651121114148201,0.883077465943034,FALSE,0.977564102564103\n\"M1a_Baseline\",\"5000+\",110,7.30918181818182,6.4230492972983,6.26528471923602,6.59148649174465,FALSE,0.240618590492077,0.751811246059145,0.561466408947955,0.986827141073817,FALSE,0.981818181818182\n\"M1a_Extended_ExternalSD\",\"30-40\",398,6.11768844221106,6.1019852315772,5.99556496221878,6.20813289866032,TRUE,1.01633570117591,1.10173937735967,0.94812328823966,1.28153134780161,TRUE,0.949748743718593\n\"M1a_Extended_ExternalSD\",\"100-200\",600,6.36781666666667,6.361443746337,6.27893262462451,6.43712947049153,TRUE,0.802528614079021,0.800269672459724,0.713949693176705,0.896880527491302,TRUE,0.945\n\"M1a_Extended_ExternalSD\",\"1000-5000\",312,6.87522435897436,6.84612373454858,6.75994295753794,6.93036420304602,TRUE,0.424190303198945,0.472899939053655,0.402653077712412,0.563619273379382,TRUE,0.971153846153846\n\"M1a_Extended_ExternalSD\",\"5000+\",110,7.30918181818182,7.16394124108478,7.04270349621114,7.28571767249817,FALSE,0.240618590492077,0.350202667778181,0.26333796489531,0.465716099163695,FALSE,0.972727272727273",
  # GitHub blob a84b948a1a834fcc56ab67d10709fc35c7b1ed16
  "Sensitivity_Analysis/External_SD/SD_sensitivity_summary.csv" = "\"sd_factor\",\"games\",\"median_abs_adjustment\",\"p90_abs_adjustment\",\"count_abs_adjust_gt_0_05\",\"count_abs_adjust_gt_0_10\",\"median_shrinkage_weight\",\"median_effective_pseudo_votes\"\n0.8,6416,0.00606863013724412,0.0399562250108181,438,84,0.986398872020477,1.9316569304859\n1,6416,0.00952935504209496,0.0619597365567279,869,270,0.97858209233192,3.0617691709618\n1.2,6416,0.0137643483005552,0.0884983353238833,1299,533,0.969008246386679,4.46710709416599",
  # GitHub blob 07f5dfb10cc53693b2c596dd3b75c28ba0a25152
  "Sensitivity_Analysis/Priors/prior_sensitivity_summary.csv" = "\"scenario\",\"games\",\"median_abs_adjustment\",\"games_abs_adjust_gt_0_05\",\"games_abs_adjust_gt_0_10\",\"median_shrinkage_weight\",\"median_effective_pseudo_votes\",\"median_abs_change_from_baseline\",\"p95_abs_change_from_baseline\",\"max_abs_change_from_baseline\",\"games_change_gt_0_05\",\"top50_overlap_with_baseline\"\n\"baseline\",6416,0.00952611342336862,869,270,0.978578362628769,3.06233354050912,0,0,0,0,50\n\"tau_tighter\",6416,0.00952208140098953,869,270,0.978594322119564,3.05970548732767,7.43233932309906e-06,4.69560158793403e-05,0.000252081515271563,0,50\n\"tau_wider\",6416,0.00952096209659326,869,269,0.978602812934442,3.0585781154037,1.08815780666127e-05,0.000131703727465515,0.000799757699644132,0,50\n\"gamma_tighter\",6416,0.00952311697349595,869,269,0.978593396050894,3.06017255798743,7.3282167516453e-06,0.000121055672851367,0.000784369354557946,0,50\n\"gamma_wider\",6416,0.00951514198519865,869,269,0.97861584555661,3.05686732810641,1.57470522732517e-05,0.000205089430691086,0.00122132381171092,0,50",
  # GitHub blob a752c933e34f15b8ca4b468f310c43ac99a6e796
  "Holdout_Comparison_3209/holdout_four_model_summary.csv" = "model,games,posterior_draws,ELPD,mean_log_predictive_density,coverage_95\nM1a_Baseline,3209,1000,-4347.827980015384,-1.3548856279262649,0.9460891243377999\nM1a_Extended,3209,1000,-4126.124994400551,-1.2857977545654569,0.9432845123091306\nM1b_Baseline,3209,16000,-3009.6388695977043,-0.9378743750694,0.943596135867872\nM1b_ExternalSD,3209,16000,-3024.698181891765,-0.9425672115586679,0.943596135867872\n",
  # GitHub blob 0fdb62b80d6b15244d119db367d2ad2e8ace48b5
  "Holdout_Comparison_3209/holdout_pairwise_differences.csv" = "model_A,model_B,delta_ELPD_A_minus_B,SE_cluster_approx,approx95_lower,approx95_upper,clusters\nM1a_Extended,M1a_Baseline,221.70298561484051,20.596548179161164,181.33375118368463,262.0722200459964,2226\nM1b_Baseline,M1a_Baseline,1338.1891104176834,52.72154151467528,1234.8548890489199,1441.523331786447,2226\nM1b_ExternalSD,M1a_Baseline,1323.1297981236291,51.15511199102371,1222.8657786212227,1423.3938176260356,2226\nM1b_Baseline,M1a_Extended,1116.4861248028456,54.69648259813527,1009.2810189105004,1223.6912306951906,2226\nM1b_ExternalSD,M1a_Extended,1101.426812508788,53.92134741474428,995.7409715758893,1207.112653441687,2226\nM1b_ExternalSD,M1b_Baseline,-15.059312294060447,8.33580110696237,-31.39748246370669,1.2788578755857962,2226\n",
  # GitHub blob f65f21f36468a2dbaeccd7ee723839eaf2b03e6e
  "WAIC_Comparison_6416/WAIC_four_model_summary.csv" = "\"model\",\"games\",\"posterior_draws\",\"lppd\",\"p_waic\",\"elpd_waic\",\"WAIC\",\"SE_WAIC_gamewise_approx\",\"max_pointwise_p_waic\",\"n_pointwise_p_waic_gt_0_4\",\"fraction_pointwise_p_waic_gt_0_4\",\"delta_WAIC\"\n\"M1b_ExternalSD\",6416,500,-4476.34548840693,1402.91363473512,-5879.25912314203,11758.5182462841,161.893114619785,6.55117662675026,948,0.147755610972569,0\n\"M1b_Baseline\",6416,500,-4551.29953352094,1332.04820707733,-5883.34774059829,11766.6954811966,163.644054378906,9.28423581237983,858,0.133728179551122,8.17723491250581\n\"M1a_Extended\",6416,500,-8248.10200463901,6.41099436760272,-8254.51299900662,16509.0259980132,146.933742634258,0.411453071147129,2,0.000311720698254364,4750.50775172917\n\"M1a_Baseline\",6416,500,-8608.45392316497,2.5533986688963,-8611.00732183387,17222.0146436677,132.063971360318,0.0897920713502988,0,0,5463.49639738367\n"
)
rd <- function(p) {
  if (repo_mode && file.exists(file.path(p5,p))) return(read.csv(file.path(p5,p),check.names=FALSE))
  if (!p %in% names(archived)) stop("Missing summary: ",p)
  read.csv(text=archived[[p]],check.names=FALSE)
}
if (repo_mode) {
  a_path <- file.path(p5,"M1a_Baseline/parameter_draws.rds")
  d_path <- file.path(p5,"M1a_Extended_ExternalSD/parameter_draws.rds")
  tr_path <- file.path(p5,"M1a_Extended_ExternalSD/P5_SD_matched.csv")
} else {
  a_path <- file.path(base,"Model_A_same_6416/parameter_draws.rds")
  d_path <- file.path(base,"Model_D_calibrated/parameter_draws.rds")
  tr_path <- file.path(base,"P5_SD_matched.csv")
}
required <- c(a_path,d_path,tr_path)
if (!all(file.exists(required))) stop("Missing original inputs:\n",paste(required[!file.exists(required)],collapse="\n"))
A <- readRDS(a_path)
D <- readRDS(d_path)
tr <- read.csv(tr_path,check.names=FALSE)
if (!repo_mode) stopifnot(identical(unname(A$input_md5),unname(tools::md5sum(tr_path))))
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
  paste("Source:",root),paste("Input mode:",if(repo_mode) "repository CSVs (embedded fallback)" else "original local RDS/CSV + embedded archived summaries"),paste("Baseline posterior draws:",nrow(za)),
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
