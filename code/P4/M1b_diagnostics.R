m1b_diag <- function(chains) {
  stopifnot(length(chains)==4L, all(vapply(chains,nrow,0L)==nrow(chains[[1]])))
  vars <- colnames(chains[[1]])
  ans <- lapply(seq_along(vars), function(j) {
    x <- do.call(cbind,lapply(chains,function(z) z[,j]))
    stopifnot(all(is.finite(x)))
    data.frame(parameter=vars[j], mean=mean(x), sd=sd(as.vector(x)),
      lower95=unname(quantile(x,.025)), median=median(x), upper95=unname(quantile(x,.975)),
      rhat=posterior::rhat(x), ess_bulk=posterior::ess_bulk(x),
      ess_tail=posterior::ess_tail(x), mcse_mean=posterior::mcse_mean(x),
      mcse_sd=posterior::mcse_sd(x))
  })
  ans <- do.call(rbind,ans)
  ans$mcse_mean_over_sd <- ans$mcse_mean/ans$sd
  ans$pass <- with(ans,is.finite(rhat)&rhat<=1.01&ess_bulk>=400&ess_tail>=400&mcse_mean_over_sd<=.05)
  ans
}

m1b_plots <- function(chains,out) {
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  vars <- c("tau","sigma_d","s")
  colors <- c("#0072B2","#D55E00","#009E73","#CC79A7")
  png(file.path(out,"scale_traces.png"),1600,1100,res=150)
  par(mfrow=c(3,1),mar=c(3,4,2,1))
  for (v in vars) {
    x<-do.call(cbind,lapply(chains,function(z)z[,v]))
    matplot(x,type="l",lty=1,col=colors,xlab="Retained iteration",ylab=v)
    legend("topright",paste("Chain",1:4),col=colors,lty=1,bty="n",cex=.7)
  }; dev.off()
  png(file.path(out,"scale_autocorrelation.png"),1500,1100,res=150)
  par(mfrow=c(3,1),mar=c(3,4,2,1))
  for(v in vars) {
    a<-sapply(chains,function(z)as.numeric(acf(z[,v],lag.max=100,plot=FALSE)$acf))
    matplot(0:100,a,type="l",lty=1,col=colors,xlab="Lag",ylab=paste(v,"ACF"))
    abline(h=0,col="grey60")
  };dev.off()
  z<-do.call(rbind,lapply(seq_along(chains),function(k) {
    pick<-unique(round(seq(1,nrow(chains[[k]]),length.out=min(1500,nrow(chains[[k]])))))
    cbind(chains[[k]][pick,vars,drop=FALSE],chain=k)
  }))
  png(file.path(out,"scale_joint_posterior.png"),1400,1200,res=150)
  pairs(z[,vars],col=adjustcolor(colors[z[,"chain"]],.25),pch=16,cex=.3)
  dev.off()
  write.csv(cor(do.call(rbind,lapply(chains,function(z)z[,vars]))),
            file.path(out,"scale_correlations.csv"))
}

m1b_derived <- function(chains) lapply(chains,function(z)cbind(z,
  total_latent_sd=sqrt(z[,"tau"]^2+z[,"sigma_d"]^2),
  designer_variance_fraction=z[,"sigma_d"]^2/(z[,"tau"]^2+z[,"sigma_d"]^2),
  pseudo_votes=z[,"s"]^2/z[,"tau"]^2))
