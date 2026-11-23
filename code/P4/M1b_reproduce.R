# Cross-platform full-development reproduction. Run from the repository root.
# Rscript code/P4/M1b_reproduce.R baseline p4_reproduced/baseline
# Requires an already installed matching JAGS/rjags pair, coda and posterior.
options(warn=1)
suppressPackageStartupMessages({library(rjags);library(coda);library(posterior)})
source("code/P4/M1b_inference.R")
args<-commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L,args[1] %in% c("baseline","sensitivity"))
out<-args[2]
if(dir.exists(out) && length(list.files(out,all.files=TRUE,no..=TRUE)))
  stop("Choose a NEW empty output directory; existing evidence will not be overwritten")
dev<-read.csv("dev_subsample.csv",stringsAsFactors=FALSE,check.names=FALSE,fileEncoding="UTF-8")
stopifnot(nrow(dev)==6489L,!anyDuplicated(dev$id))
prep<-m1b_prepare(dev)
label<-if(args[1]=="baseline")"baseline_development" else "sensitivity_s_upper6"
seeds<-if(args[1]=="baseline")610800L+1:4 else 610900L+1:4
m1b_fit(prep,dev,out,label=label,adapt=2000,burn=2000,batch=2000,
         min_draws=4000,max_draws=12000,seeds=seeds,glm=TRUE)
m1b_latent_output(prep,out,B=1000)
writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))
