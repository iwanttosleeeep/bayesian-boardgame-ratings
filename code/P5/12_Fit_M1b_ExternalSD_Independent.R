# STAT6106 P5 exploratory replication of P4 M1b, with EXTERNAL per-game SD.
# This is NOT the original verified P4 model; do not overwrite or relabel it.
# Reuses P4's existing m1b_prepare() and BUGS model structure (fetched from GitHub).
# Change ONLY measurement variance: s^2/n -> sd_hist_i^2/n_i; remove shared s.
# Keep P4's constant tau, covariates, designer random intercepts and all other priors.
# Training data: 6416 SD-matched development games ONLY; NO holdout fitting.
# Runs 4 independent JAGS chains SEQUENTIALLY to reduce peak RAM on an 8GB Mac.
# Needs installed JAGS and R packages rjags, coda, posterior.
# Expected output is local under P5_external_SD/M1b_ExternalSD_independent.
# User can run: source(url("https://raw.githubusercontent.com/iwanttosleeeep/bayesian-boardgame-ratings/main/code/P5/12_Fit_M1b_ExternalSD_Independent.R"))

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
  library(posterior)
})
options(timeout=max(getOption("timeout",60), 600))
base <- "P5_external_SD"
cache <- file.path(base,"source_cache")
out <- file.path(base,"M1b_ExternalSD_independent")
dir.create(cache,recursive=TRUE,showWarnings=FALSE)
if (dir.exists(out) && length(list.files(out,all.files=TRUE,no..=TRUE))>0)
  stop("Refusing to overwrite an existing M1b External-SD run: ",out)
dir.create(out,recursive=TRUE,showWarnings=FALSE)
repo <- "https://raw.githubusercontent.com/iwanttosleeeep/bayesian-boardgame-ratings/main/"

fetch <- function(repo_path, alternatives=character()) {
  local <- alternatives[file.exists(alternatives)]
  if(length(local)) { cat("Using local: ",local[1],"\n",sep=""); return(local[1]) }
  dest <- file.path(cache,gsub("/","__",repo_path,fixed=TRUE))
  if (file.exists(dest) && file.info(dest)$size>100) {
    cat("Using cache: ",dest,"\n",sep=""); return(dest)
  }
  tmp <- paste0(dest,".part")
  if(file.exists(tmp)) unlink(tmp)
  cat("Downloading ",repo_path,"\n",sep="")
  status <- tryCatch(utils::download.file(paste0(repo,repo_path),tmp,mode="wb",
                                         method="libcurl",quiet=FALSE),
                     error=function(e) stop("Download failed: ",conditionMessage(e)))
  if(!identical(status,0L) || !file.exists(tmp) || file.info(tmp)$size<=100 ||
     !file.rename(tmp,dest)) stop("Download incomplete: ",repo_path)
  dest
}
data_path <- fetch("dev_subsample.csv",c("dev_subsample.csv","../dev_subsample.csv"))
sd_path <- fetch("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv",
                 c("outputs/P5/M1a_Extended_ExternalSD/P5_SD_matched.csv",
                   file.path(base,"P5_SD_matched.csv")))
prepare_path <- fetch("code/P4/M1b_prepare.R",c("code/P4/M1b_prepare.R"))
bug_path <- fetch("code/P4/M1b_baseline.bug",c("code/P4/M1b_baseline.bug"))
source(prepare_path,local=TRUE)

dev <- read.csv(data_path,stringsAsFactors=FALSE,check.names=FALSE)
sd <- read.csv(sd_path,stringsAsFactors=FALSE,check.names=FALSE)
stopifnot(nrow(dev)==6489L, nrow(sd)==6416L, !anyDuplicated(dev$id),
          !anyDuplicated(sd$id), all(c("id","sd_hist","n_hist","n_2022",
                                      "average_2022") %in% names(sd)))
# Preserve original P1 development row order rather than the SD lookup order.
keep <- dev$id %in% sd$id
dat <- dev[keep,,drop=FALSE]
matching <- sd[match(dat$id,sd$id),,drop=FALSE]
stopifnot(nrow(dat)==6416L,all(dat$id==matching$id),
          max(abs(dat$average-matching$average_2022))<1e-8,
          max(abs(dat$users_rated-matching$n_2022))<1e-8,
          all(is.finite(matching$sd_hist)&matching$sd_hist>0),
          all(is.finite(matching$n_hist)&matching$n_hist>0))
prep <- m1b_prepare(dat)
v_obs <- matching$sd_hist^2/dat$users_rated
stopifnot(length(v_obs)==prep$data$N, all(is.finite(v_obs)&v_obs>0))
prep$data$v_obs <- unname(v_obs)

bug <- paste(readLines(bug_path,warn=FALSE),collapse="\n")
stopifnot(grepl("pow(s, 2)/n[i]",bug,fixed=TRUE),
          grepl("s ~ dunif(0.5, 3)",bug,fixed=TRUE))
bug <- sub("pow(s, 2)/n[i]","v_obs[i]",bug,fixed=TRUE)
bug <- sub("s ~ dunif(0.5, 3)","",bug,fixed=TRUE)
stopifnot(grepl("v_obs[i]",bug,fixed=TRUE),
          !grepl("pow(s, 2)",bug,fixed=TRUE),
          !grepl("s ~ dunif",bug,fixed=TRUE))
writeLines(bug,file.path(out,"M1b_external_sd.bug"))
write.csv(data.frame(id=dat$id,sd_hist=matching$sd_hist,
                     n_hist=matching$n_hist),
          file.path(out,"train_game_ids_and_sd.csv"),row.names=FALSE)
write.csv(data.frame(term=colnames(prep$data$X),
                     prior_sd=1/sqrt(prep$data$beta_prec)),
          file.path(out,"design_columns.csv"),row.names=FALSE)
saveRDS(prep$recipe,file.path(out,"preprocessing_recipe.rds"))
cat(sprintf("Input validated: %d games, %d covariates, %d named designer groups.\n",
            prep$data$N,prep$data$P,prep$data$J))

# JAGS 'glm' module is the same block-sampling acceleration used by P4.
rjags::load.module("glm",quiet=TRUE)
chains <- vector("list",4)
monitor <- c("alpha","beta","tau","sigma_d","u")
for(k in seq_len(4L)) {
  seed <- 610950L+k
  set.seed(seed)
  init <- list(.RNG.name="base::Mersenne-Twister",.RNG.seed=seed,
               alpha=6.4+rnorm(1,0,.15),
               tau=runif(1,.4,1),sigma_d=runif(1,.15,.6),
               beta=rnorm(prep$data$P,0,.03),
               z_u=rnorm(prep$data$J,0,.2))
  cat("\nFitting chain ",k,"/4; adapt 2000, burn 2000, save 4000...\n",sep="")
  fit <- rjags::jags.model(textConnection(bug),data=prep$data,inits=init,
                           n.chains=1L,n.adapt=2000L,quiet=TRUE)
  update(fit,n.iter=2000L,progress.bar="none")
  sam <- rjags::coda.samples(fit,variable.names=monitor,
                             n.iter=4000L,progress.bar="none")
  chains[[k]] <- as.matrix(sam)
  saveRDS(chains[[k]],file.path(out,sprintf("chain_%d.rds",k)),
          compress="gzip")
  rm(fit,sam);gc(verbose=FALSE)
  cat("Saved chain ",k," (",nrow(chains[[k]])," draws).\n",sep="")
}

# Check all coefficients and named-designer effects, not only the 3 scale terms.
vars <- colnames(chains[[1]])
stopifnot(all(vapply(chains,function(z)identical(colnames(z),vars),logical(1))),
          length(vars)>prep$data$P)
cat("\nChecking posterior diagnostics for ",length(vars)," parameters...\n",sep="")
dg <- do.call(rbind,lapply(vars,function(v) {
  matrix4 <- do.call(cbind,lapply(chains,function(z) z[,v]))
  mu <- mean(matrix4); ss <- stats::sd(as.vector(matrix4))
  rh <- posterior::rhat(matrix4)
  eb <- posterior::ess_bulk(matrix4)
  et <- posterior::ess_tail(matrix4)
  mc <- posterior::mcse_mean(matrix4)
  data.frame(parameter=v, mean=mu,sd=ss,
             lower95=unname(stats::quantile(matrix4,.025)),
             upper95=unname(stats::quantile(matrix4,.975)),
             rhat=rh,ess_bulk=eb,ess_tail=et,mcse_mean=mc,
             mcse_over_sd=if(ss>0)mc/ss else Inf)
}))
dg$pass <- with(dg,is.finite(rhat)&rhat<=1.01&
                 ess_bulk>=400&ess_tail>=400&mcse_over_sd<=.05)
write.csv(dg,file.path(out,"diagnostics.csv"),row.names=FALSE)
for(v in c("alpha","tau","sigma_d")) {
  row <- dg[dg$parameter==v,,drop=FALSE]
  print(row[,c("parameter","mean","lower95","upper95","rhat",
                "ess_bulk","ess_tail")],row.names=FALSE)
}

# A compact coefficient table and grouped PPC / latent-score checks.
beta_names <- paste0("beta[",seq_len(prep$data$P),"]")
beta_info <- dg[match(beta_names,dg$parameter),
                c("mean","lower95","upper95","rhat","ess_bulk","ess_tail","pass")]
write.csv(data.frame(term=colnames(prep$data$X),beta_info,row.names=NULL),
          file.path(out,"covariate_summary.csv"),row.names=FALSE)

set.seed(610959L)
B <- 500L
# 125 draws/chains, evenly spread. Each column is a JOINT game posterior draw.
within <- unique(as.integer(round(seq(1,nrow(chains[[1]]),length.out=125L))))
stopifnot(length(within)==125L)
theta <- matrix(NA_real_,nrow=prep$data$N,ncol=B)
conditional_means <- matrix(NA_real_,nrow=prep$data$N,ncol=B)
yrep_mean <- matrix(NA_real_,B,4L)
yrep_var <- matrix(NA_real_,B,4L)
groups <- list(n30_40=which(prep$data$n<=40),
               n100_200=which(prep$data$n>=100 & prep$data$n<=200),
               n1000_5000=which(prep$data$n>=1000 & prep$data$n<=5000),
               n5000plus=which(prep$data$n>5000))
stopifnot(all(lengths(groups)>1L))
loglik <- matrix(NA_real_,nrow=B,ncol=prep$data$N)
for(b in seq_len(B)) {
  k <- 1L+(b-1L)%/%125L
  i <- within[1L+(b-1L)%%125L]
  z <- chains[[k]][i,]
  beta <- z[beta_names]
  named_effect <- z[paste0("u[",prep$data$designer,"]")]
  mu <- as.numeric(z["alpha"]+prep$data$X%*%beta+
                   prep$data$known*named_effect)
  t2 <- unname(z["tau"]^2+(1-prep$data$known)*z["sigma_d"]^2)
  vv <- t2+v_obs
  w <- t2/vv
  conditional_means[,b] <- mu+w*(prep$data$y-mu)
  theta[,b] <- stats::rnorm(prep$data$N,conditional_means[,b],
                            sqrt(t2*v_obs/vv))
  loglik[b,] <- stats::dnorm(prep$data$y,mean=mu,sd=sqrt(vv),log=TRUE)
  yrep <- stats::rnorm(prep$data$N,mu,sqrt(vv))
  for(g in seq_along(groups)) {
    ix <- groups[[g]]
    yrep_mean[b,g] <- mean(yrep[ix])
    yrep_var[b,g] <- stats::var(yrep[ix])
  }
}
stopifnot(all(is.finite(theta)),all(is.finite(loglik)))
rownames(theta) <- as.character(dat$id)
colnames(loglik) <- as.character(dat$id)
theta_avg <- rowMeans(conditional_means)
summary <- data.frame(id=dat$id,raw_average=dat$average,
                      n=dat$users_rated,sd_hist=matching$sd_hist,
                      posterior_mean=theta_avg,
                      lower95=apply(theta,1,stats::quantile,.025),
                      upper95=apply(theta,1,stats::quantile,.975),
                      stringsAsFactors=FALSE)
summary$adjustment <- summary$posterior_mean-summary$raw_average
write.csv(summary,file.path(out,"latent_ratings.csv"),row.names=FALSE)
write.csv(do.call(rbind,lapply(seq_along(groups),function(g) {
  ix <- groups[[g]]
  data.frame(group=names(groups)[g], games=length(ix),
             observed_mean=mean(prep$data$y[ix]),
             predicted_mean_low=unname(stats::quantile(yrep_mean[,g],.025)),
             predicted_mean_high=unname(stats::quantile(yrep_mean[,g],.975)),
             observed_variance=stats::var(prep$data$y[ix]),
             predicted_variance_low=unname(stats::quantile(yrep_var[,g],.025)),
             predicted_variance_high=unname(stats::quantile(yrep_var[,g],.975)))
})),file.path(out,"development_PPC.csv"),row.names=FALSE)
saveRDS(list(ids=dat$id, theta_draws=theta,
             note="M1b External-SD, 6416 training games, joint latent draws"),
        file.path(out,"latent_draws.rds"),compress="gzip")
saveRDS(list(ids=dat$id,loglik=loglik,
             convention="theta integrated; named designer effects conditioned",
             external_sd_fixed=TRUE),
        file.path(out,"pointwise_loglik.rds"),compress="gzip")

verification <- c(
  paste("Date:",Sys.Date()),
  "Independent P5 adaptation of P4's M1b: NOT an existing P4 validated result.",
  "Input: 6416 historical-SD-matched development games; no holdout read.",
  "Specification: P4 covariates and designer effects; constant tau; no common s.",
  "Observation variance replaced with sd_hist^2 / users_rated.",
  paste("R version:",R.version.string),
  paste("Chains:",length(chains),"x",nrow(chains[[1]]),"retained draws"),
  paste("Max R-hat:",max(dg$rhat)),
  paste("Min bulk ESS:",min(dg$ess_bulk)),
  paste("Min tail ESS:",min(dg$ess_tail)),
  paste("All parameters passed P4 diagnostic thresholds:",all(dg$pass)),
  paste("Median absolute latent-rating adjustment:",
        median(abs(summary$adjustment))),
  "These are DEVELOPMENT PPC, not holdout predictions.",
  "Named-designer effects were learned on development data.",
  "External SD's date/upstream provenance has NOT been verified."
)
writeLines(verification,file.path(out,"validation.txt"))
cat("\n=== FINISHED ===\n")
cat(paste(verification,collapse="\n"),"\n")
if (!all(dg$pass)) warning("Not all P4 diagnostic thresholds passed; review before interpretation.")
cat("\nSend for review: validation.txt, diagnostics.csv, covariate_summary.csv,\n")
cat("development_PPC.csv and latent_ratings.csv from ",out,"\n",sep="")
