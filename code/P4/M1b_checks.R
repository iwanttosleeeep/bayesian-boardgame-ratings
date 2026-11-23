source("code/P4/M1b_prepare.R")
if (file.exists("code/P4/M1b_diagnostics.R")) source("code/P4/M1b_diagnostics.R")
if (file.exists("code/P4/M1b_inference.R")) source("code/P4/M1b_inference.R")
stopifnot(exists("m1b_diag"), exists("m1b_simulate"))
set.seed(610641)
iid <- lapply(1:4, function(k) matrix(rnorm(2000), ncol=1, dimnames=list(NULL,"a")))
good <- m1b_diag(iid)
bad <- iid; bad[[4]] <- bad[[4]]+2
stopifnot(good$rhat < 1.01, good$ess_bulk > 400, good$ess_tail > 400,
          m1b_diag(bad)$rhat > 1.1)
# Independent Gaussian conditioning calculation, including unknown designers.
for (known in 0:1) {
  t2 <- .7^2+(1-known)*.4^2; v <- 2^2/30
  exact_variance <- 1/(1/t2+1/v)
  exact_mean <- exact_variance*(6/t2+7/v)
  got <- m1b_latent(7,30,6,.7,2,.4,known)
  stopifnot(abs(got$mean-exact_mean)<1e-12,
            abs(got$sd^2-exact_variance)<1e-12)
}
# Many simulated blocks: same named designer shares covariance; anonymous games don't.
base <- list(N=4L,P=1L,J=1L,X=matrix(0,4,1),n=rep(30,4),
             known=c(1L,1L,0L,0L),designer=rep(1L,4),beta_prec=4)
truth <- list(alpha=6.4,beta=0,tau=.7,s=2,sigma_d=.5)
ys <- replicate(20000, m1b_simulate(base,truth)$y)
cv <- cov(t(ys))
stopifnot(abs(cv[1,2]-.5^2)<.025, abs(cv[3,4])<.025,
          max(abs(diag(cv)-(.7^2+.5^2+4/30)))<.03)
cat("PASS: modern diagnostics detect shifted chain; Gaussian conditioning; repeated/anonymous covariance\n")
