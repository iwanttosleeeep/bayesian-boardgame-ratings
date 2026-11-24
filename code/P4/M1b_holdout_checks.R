# Constructed cases: no model fitting or project outcome scoring.
if(file.exists("code/P4/M1b_holdout_functions.R")) source("code/P4/M1b_holdout_functions.R")
stopifnot(exists("h_batch"),exists("h_replicate"),exists("h_logmeanexp"),exists("h_prepare"))
p<-list(X=matrix(0,6,1,dimnames=list(NULL,"x")),n=rep(50,6),sd_hist=rep(2,6),
 known=c(1L,0L,0L,0L,0L,0L),designer_index=rep(1L,6),
 new_index=c(0L,1L,1L,2L,0L,0L),group=c("seen_named",rep("unseen_named",3),"missing","uncredited"))
z<-matrix(c(6,0,.5,.4,2,.3),1,dimnames=list(NULL,c("alpha","beta[1]","tau","sigma_d","s","u[1]")))
m<-h_batch(z,p,FALSE)
stopifnot(max(abs(m$mean-c(6.3,rep(6,5))))<1e-12,
 max(abs(m$marginal_variance-c(.25+.08,rep(.25+.08+.16,5))))<1e-12,
 max(abs(m$conditional_variance-(.25+.08)))<1e-12,
 isTRUE(all.equal(m,h_batch(z,p,TRUE))))
ze<-z[,colnames(z)!="s",drop=FALSE]
stopifnot(isTRUE(all.equal(m,h_batch(ze,p,TRUE))))
set.seed(61063209);repz<-z[rep(1,60000),,drop=FALSE]
sim<-h_replicate(repz,p,FALSE)
stopifnot(max(abs(colMeans(sim)-c(6.3,rep(6,5))))<.012,
 max(abs(apply(sim,2,var)-c(.33,rep(.49,5))))<.015,
 abs(cov(sim[,2],sim[,3])-.16)<.008,
 abs(cov(sim[,2],sim[,4]))<.008,abs(cov(sim[,5],sim[,6]))<.008)
stopifnot(abs(h_logmeanexp(c(-1000,-1001))-(-1000+log((1+exp(-1))/2)))<1e-12,
 abs(h_logmeanexp(log(c(.2,.8)))-log(.5))<1e-12,
 abs(h_logmeanexp(c(-1,-3))-mean(c(-1,-3)))>.1)
stopifnot(max(abs(h_logmeanexp(matrix(c(-1000,-1001,0,0),2))-c(h_logmeanexp(c(-1000,-1001)),0)))<1e-12)
first<-h_logmeanexp(log(c(.1,.3)))+log(2)
last<-log(.8)
stopifnot(abs(h_logadd(first,last)-log(3)-log(.4))<1e-12)
# Original training preprocessing is reused exactly; the holdout response is ignored.
source("code/P4/M1b_prepare.R")
dat<-read.csv("dev_subsample.csv",fileEncoding="UTF-8",check.names=FALSE)[1:30,]
prep<-m1b_prepare(dat);dat$sd_hist<-2
x<-h_prepare(dat,prep$recipe)
dat$average<-NA_real_;dat$minage[1]<-NA
y<-h_prepare(dat,prep$recipe)
dat$minage[1]<-prep$recipe$medians["minage"]
w<-h_prepare(dat,prep$recipe)
stopifnot(identical(x$X[-1,,drop=FALSE],y$X[-1,,drop=FALSE]),
 abs(y$X[1,"minage"]-(prep$recipe$medians["minage"]-prep$recipe$center["minage"])/prep$recipe$scale["minage"])<1e-12,
 identical(y$X[,"minage"],w$X[,"minage"]),identical(x$recipe,prep$recipe))
dat$average<-seq_len(nrow(dat))*1e6
stopifnot(identical(w,h_prepare(dat,prep$recipe)))
cat("PASS: predictive moments/noise, seen effects, shared new designers, independent anonymous effects, stable log-mean-exp, frozen preprocessing and response invariance\n")
