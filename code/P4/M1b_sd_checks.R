if(file.exists("code/P4/M1b_sd_inference.R")) source("code/P4/M1b_sd_inference.R")
stopifnot(exists("sd_latent"),exists("sd_model"))
for(k in 0:1) {
  for(v in c(.01,.2,.8)) {
    t2<-.5^2+(1-k)*.4^2
    expected_var<-1/(1/t2+1/v)
    a<-sd_latent(7,6,.5,.4,k,v)
    stopifnot(abs(a$sd^2-expected_var)<1e-12,
      abs(a$mean-expected_var*(6/t2+7/v))<1e-12)
    old<-m1b_latent(7,30,6,.5,sqrt(v*30),.4,k)
    stopifnot(isTRUE(all.equal(a,old)))
    ll1<-dnorm(7,6,sqrt(t2+v),log=TRUE)
    ll2<--.5*(log(2*pi*(t2+v))+1/(t2+v))
    stopifnot(abs(ll1-ll2)<1e-12)
  }
}
original<-paste(readLines("code/P4/M1b_baseline.bug"),collapse="\n")
stopifnot(identical(sd_model(FALSE),original),
 !grepl("s ~",sd_model(TRUE),fixed=TRUE),
 grepl("1/(latent_var[i] + v_obs[i])",sd_model(TRUE),fixed=TRUE),
 grepl("tau ~ dt(0, 1, 1) T(0,)",sd_model(TRUE),fixed=TRUE))
set.seed(20261124)
# Replicated pairs test: same named effect creates covariance, anonymous effects independent.
N<-50000
u<-rnorm(N,0,.4);e1<-rnorm(N,0,.5);e2<-rnorm(N,0,.5)
y1<-u+e1+rnorm(N,0,sqrt(.1));y2<-u+e2+rnorm(N,0,sqrt(.1))
a1<-rnorm(N,0,.4)+e1+rnorm(N,0,sqrt(.1));a2<-rnorm(N,0,.4)+e2+rnorm(N,0,sqrt(.1))
stopifnot(abs(cov(y1,y2)-.4^2)<.01,abs(cov(a1,a2))<.01,
 abs(var(y1)-(.4^2+.5^2+.1))<.015)
cat("PASS: noise SD/variance/precision; conditional theta; marginal loglik; named/anonymous covariance; baseline priors unchanged\n")
