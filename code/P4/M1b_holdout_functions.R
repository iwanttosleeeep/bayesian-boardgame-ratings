# Prediction only: never condition on holdout average or invoke a fitting routine.
source("code/P4/M1b_prepare.R")

h_prepare<-function(dat,recipe) {
 stopifnot(all(is.finite(dat$sd_hist)&dat$sd_hist>0))
 # The established preparation function requires a finite response; replace it
 # before calling it and never return its artificial response as a prediction input.
 dat$average<-0
 prepared<-m1b_prepare(dat,recipe=recipe)
 stopifnot(identical(prepared$recipe,recipe),identical(colnames(prepared$data$X),recipe$columns))
 missing<-m1b_missing(dat$designer_id)
 uncredited<-!missing&trimws(as.character(dat$designer_id))=="(Uncredited)"
 group<-ifelse(missing,"missing",ifelse(uncredited,"uncredited",
  ifelse(prepared$data$known==1,"seen_named","unseen_named")))
 new_names<-sort(unique(trimws(as.character(dat$designer_id[group=="unseen_named"]))))
 new_index<-integer(nrow(dat))
 new_index[group=="unseen_named"]<-match(trimws(as.character(dat$designer_id[group=="unseen_named"])),new_names)
 list(ids=dat$id,X=prepared$data$X,n=prepared$data$n,sd_hist=dat$sd_hist,
  known=prepared$data$known,designer_index=prepared$data$designer,
  new_index=new_index,new_names=new_names,group=group,recipe=recipe)
}

h_batch<-function(z,p,external=FALSE) {
 B<-nrow(z);N<-nrow(p$X)
 mu<-sweep(z[,paste0("beta[",seq_len(ncol(p$X)),"]"),drop=FALSE]%*%t(p$X),1,z[,"alpha"],"+")
 seen<-which(p$known==1)
 if(length(seen)) mu[,seen]<-mu[,seen,drop=FALSE]+z[,paste0("u[",p$designer_index[seen],"]"),drop=FALSE]
 noise<-if(external)matrix(p$sd_hist^2/p$n,B,N,byrow=TRUE) else outer(z[,"s"]^2,1/p$n)
 conditional<-noise+matrix(z[,"tau"]^2,B,N)
 marginal<-conditional+outer(z[,"sigma_d"]^2,1-p$known)
 stopifnot(all(is.finite(mu)),all(is.finite(marginal)),all(marginal>0))
 list(mean=unname(mu),marginal_variance=unname(marginal),conditional_variance=unname(conditional))
}

h_replicate<-function(z,p,external=FALSE,moments=NULL) {
 if(is.null(moments))moments<-h_batch(z,p,external)
 B<-nrow(z);N<-nrow(p$X);mu<-moments$mean
 new<-which(p$group=="unseen_named")
 if(length(new)) {
  effects<-matrix(rnorm(B*max(p$new_index)),B)*z[,"sigma_d"]
  mu[,new]<-mu[,new,drop=FALSE]+effects[,p$new_index[new],drop=FALSE]
 }
 anonymous<-which(p$group %in% c("missing","uncredited"))
 if(length(anonymous))mu[,anonymous]<-mu[,anonymous,drop=FALSE]+
  matrix(rnorm(B*length(anonymous)),B)*z[,"sigma_d"]
 mu+matrix(rnorm(B*N),B,N)*sqrt(moments$conditional_variance)
}

h_logmeanexp<-function(x) {
 if(is.null(dim(x))) {peak<-max(x);return(peak+log(mean(exp(x-peak))))}
 peak<-apply(x,2,max)
 peak+log(colMeans(exp(sweep(x,2,peak,"-"))))
}

h_logadd<-function(a,b) {
 if(is.null(a))return(b)
 peak<-pmax(a,b)
 peak+log(exp(a-peak)+exp(b-peak))
}

h_groups<-function(p) {
 out<-c(list(all=seq_along(p$n)),setNames(lapply(c("seen_named","unseen_named","missing","uncredited"),
  function(g)which(p$group==g)),paste0("designer/",c("seen_named","unseen_named","missing","uncredited"))))
 c(out,list("n/30-40"=which(p$n>=30&p$n<=40),"n/41-99"=which(p$n>40&p$n<100),
  "n/100-200"=which(p$n>=100&p$n<=200),"n/201-999"=which(p$n>200&p$n<1000),
  "n/1000-5000"=which(p$n>=1000&p$n<=5000),"n/5000+"=which(p$n>5000)))
}
