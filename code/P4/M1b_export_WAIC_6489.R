# Export ONLY saved original-prior baseline likelihood rows; never fits a model.
# Run from repo root after preparing source_checksums.csv (see handoff README).
# Locate the checkout from Rscript, source(), RStudio or an explicit root.
.launch_dir <- getwd()
.repo_hints <- c(Sys.getenv("BOARDGAME_REPO_ROOT", unset=""),
  vapply(rev(sys.frames()), function(f) if (is.null(f$ofile)) "" else dirname(f$ofile), ""),
  dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE))), .launch_dir)
if (requireNamespace("rstudioapi", quietly=TRUE) && rstudioapi::isAvailable())
  .repo_hints <- c(.repo_hints, dirname(rstudioapi::getActiveDocumentContext()$path))
.repo_helper <- NULL
for (.start in unique(.repo_hints[nzchar(.repo_hints)])) {
  .p <- normalizePath(.start, winslash="/", mustWork=FALSE)
  repeat {
    .candidate <- file.path(.p, "code", "repo_paths.R")
    if (file.exists(.candidate)) { .repo_helper <- .candidate; break }
    .parent <- dirname(.p); if (identical(.parent,.p)) break; .p <- .parent
  }
  if (!is.null(.repo_helper)) break
}
if (is.null(.repo_helper)) stop("Cannot locate code/repo_paths.R; use a full checkout or set BOARDGAME_REPO_ROOT.")
source(.repo_helper, local=TRUE)
p4_source <- Sys.getenv("P4_BASELINE_DIR", unset=repo_path("outputs/P4/baseline_development"))
p4_share <- repo_path("outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds")
p4_regenerate <- "--regenerate" %in% commandArgs(trailingOnly=TRUE)
p4_sources <- file.path(p4_source,c("inputs.rds","pointwise_loglik.rds",paste0("chain_",1:4,".rds"),"train_game_ids.csv"))
repo_check_paths(if (p4_regenerate) p4_sources else c(p4_share,repo_path("outputs/P4/M1b_WAIC_6489/train_game_ids.csv")))
if (!p4_regenerate && file.exists(p4_share)) {
  saved_share <- readRDS(p4_share)
  expected_ids <- read.csv(repo_path("outputs/P4/M1b_WAIC_6489/train_game_ids.csv"))$id
  stopifnot(identical(dim(saved_share$loglik),c(500L,6489L)),
            identical(as.character(saved_share$ids),as.character(expected_ids)),
            all(is.finite(saved_share$loglik)),
            identical(colnames(saved_share$loglik),as.character(expected_ids)),
            identical(unname(saved_share$train_md5_git_lf),unname(tools::md5sum(repo_path("dev_subsample.csv")))))
  cat("Using existing original-prior 6489-game P4 shared likelihood:", p4_share, "\n")
} else {
  for (p in p4_sources) repo_existing(p,"original P4 baseline source")

source(repo_path("code/P4/M1b_prepare.R"))
base <- p4_source
out <- Sys.getenv("P4_EXPORT_DIR", unset=repo_path("outputs/P4/M1b_WAIC_6489"))
if (dir.exists(out) && length(list.files(out, all.files=TRUE, no..=TRUE)))
  stop("Regeneration requires a NEW empty P4_EXPORT_DIR; existing evidence is read-only.")
dir.create(out,recursive=TRUE,showWarnings=FALSE)
checksums <- read.csv(repo_path("outputs/P4/M1b_WAIC_6489/source_checksums.csv"),stringsAsFactors=FALSE)
hash <- function(label,algo) checksums[checksums$source==label,algo]
saved <- readRDS(file.path(base,"pointwise_loglik.rds"))
input <- readRDS(file.path(base,"inputs.rds"))
ids <- saved$ids
stopifnot(identical(dim(saved$loglik),c(1000L,6489L)),!anyDuplicated(ids),
  all(is.finite(saved$loglik)),identical(as.character(ids),colnames(saved$loglik)),
  identical(input$prep$ids,ids),grepl("s ~ dunif(0.5, 3)",input$model,fixed=TRUE))
dev <- read.csv(repo_path("dev_subsample.csv"),stringsAsFactors=FALSE,check.names=FALSE,fileEncoding="UTF-8")
stopifnot(identical(input$prep$data,m1b_prepare(dev)$data),
  identical(as.character(ids),as.character(read.csv(file.path(base,"train_game_ids.csv"))$id)),
  identical(unname(tools::md5sum(repo_path("dev_subsample.csv"))),hash("training_git_lf","md5")))
peers <- c(P2_JAGS="outputs/P2/M0_loglik_jags_share.rds",
           P2_Gibbs="outputs/P2/M0_loglik_gibbs_share.rds",
           P5="archive/outputs/P5/M1a_WAIC_6489/pointwise_loglik_share.rds")
alignment <- lapply(names(peers),function(who) {
  z<-readRDS(repo_path(peers[[who]]))
  stopifnot(identical(dim(z$loglik),c(500L,6489L)),all(is.finite(z$loglik)),
    identical(as.character(ids),as.character(z$ids)),
    identical(colnames(z$loglik),as.character(ids)),
    identical(z$train_md5,hash("training_git_lf","md5")))
  idfile<-if(who=="P5")"archive/outputs/P5/M1a_WAIC_6489/train_game_ids.csv" else "outputs/P2/M0_train_game_ids.csv"
  stopifnot(identical(as.character(ids),as.character(read.csv(repo_path(idfile))$id)))
  data.frame(peer=who,games=length(z$ids),same_order=TRUE,finite=TRUE,peer_train_md5=z$train_md5)
})
write.csv(do.call(rbind,alignment),file.path(out,"ids_alignment.csv"),row.names=FALSE)
index <- saved$draw_index
stopifnot(all(c("chain","iteration") %in% names(index)),nrow(index)==1000,
  all(index$chain %in% 1:4),all(index$iteration %in% 1:4000))
# Keep first saved occurrence of each chain/retained-row pair, then random select.
unique_row <- !duplicated(index[,c("chain","iteration")])
RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(20261124)
selected<-unlist(lapply(1:4,function(k) {
  pool<-which(unique_row & index$chain==k)
  stopifnot(length(pool)>=125)
  chosen<-sample(pool,125,replace=FALSE)
  chosen[order(index$iteration[chosen])]
}),use.names=FALSE)
draw_index<-data.frame(chain=index$chain[selected],iteration=index$iteration[selected],
  source_loglik_row=selected,
  pooled_retained_index=(index$chain[selected]-1L)*4000L+index$iteration[selected])
stopifnot(!anyDuplicated(draw_index[,c("chain","iteration")]),all(table(draw_index$chain)==125))
ll<-saved$loglik[selected,,drop=FALSE]
rownames(ll)<-NULL
# Independent scalar log-Normal calculation from ORIGINAL saved parameter rows.
set.seed(20261125)
games<-unique(c(1L,6489L,which.min(input$prep$data$n),which.max(input$prep$data$n),
  head(which(input$prep$data$known==0),10),sample.int(6489,20)))
errors<-NULL
for(k in 1:4) {
  chain<-readRDS(file.path(base,paste0("chain_",k,".rds")))
  stopifnot(chain$chain==k,nrow(chain$draws)==4000L)
  rows<-which(draw_index$chain==k)
  rows<-unique(c(head(rows,1),tail(rows,1),sample(rows,8)))
  for(b in rows) for(i in games) {
    p<-chain$draws[draw_index$iteration[b],]
    d<-input$prep$data
    mu<-p["alpha"]+sum(d$X[i,]*p[paste0("beta[",seq_len(d$P),"]")])
    if(d$known[i]==1) mu<-mu+p[paste0("u[",d$designer[i],"]")]
    variance<-p["tau"]^2+p["s"]^2/d$n[i]+(1-d$known[i])*p["sigma_d"]^2
    manual<--.5*(log(2*pi)+log(variance)+(d$y[i]-mu)^2/variance)
    errors<-rbind(errors,data.frame(export_row=b,chain=k,iteration=draw_index$iteration[b],
      game_column=i,id=ids[i],absolute_error=abs(unname(manual)-ll[b,i])))
  }
  rm(chain);gc()
}
stopifnot(max(errors$absolute_error)<1e-10)
convention<-paste("Natural log p(average_i | n_i,X_i,alpha,beta,tau,s,sigma_d,u_named).",
 "Game theta integrated; named training designer u conditioned on posterior draw;",
 "missing/uncredited designers independent effects integrated as extra sigma_d^2.",
 "Pointwise unit=game; not new-designer-group extrapolation, posterior density or deviance.")
payload<-list(ids=ids,draw_index=draw_index,loglik=ll,convention=convention,
  train_md5=hash("training_worktree","md5"),train_sha256=hash("training_worktree","sha256"),
  train_md5_git_lf=hash("training_git_lf","md5"),train_sha256_git_lf=hash("training_git_lf","sha256"),
  provenance=list(model="P4 M1b original-prior constant-tau baseline; s~Uniform(0.5,3)",
    fit_source_commit="dab0f291adfc0a8755f45b6b4f7194a89bbc2a7b",
    source_checksums=checksums,selection_seed=20261124L,
    rule="First occurrence of each (chain,retained iteration); sample 125 unique rows per chain without replacement; sort within each chain by retained iteration",
    original_loglik_dimension=dim(saved$loglik),index_meaning="iteration is 1-based retained matrix row, not raw JAGS iteration"))
path<-file.path(out,"pointwise_loglik_share.rds")
saveRDS(payload,path,compress="gzip",version=3)
roundtrip<-readRDS(path)
stopifnot(identical(payload,roundtrip),identical(dim(roundtrip$loglik),c(500L,6489L)),
  all(is.finite(roundtrip$loglik)),!anyDuplicated(roundtrip$ids))
write.csv(data.frame(id=ids),file.path(out,"train_game_ids.csv"),row.names=FALSE)
write.csv(draw_index,file.path(out,"draw_index.csv"),row.names=FALSE)
write.csv(errors,file.path(out,"numerical_spotchecks.csv"),row.names=FALSE)
writeLines(c("PASS: 500 x 6489 finite natural log-likelihood; unique IDs; 125 unique retained draws/chain",
  "PASS: exact column order equals original P4 training inputs, source matrix, development CSV, P2 JAGS/Gibbs and P5 RDS/CSV IDs",
  paste("PASS: independent scalar recomputations:",nrow(errors),"max absolute error:",format(max(errors$absolute_error),digits=17)),
  "PASS: serialization reread exactly identical; no fit/update/coda.samples call executed",
  paste("Export RDS bytes:",file.info(path)$size),paste("R:",R.version.string),
  "Existing full posterior and source loglik were read only; seed=20261124; validation seed=20261125",
  "Raw training MD5 differs from peers only by CRLF/LF: full normalized bytes exactly equal Git blob (see checksum provenance)",
  "No holdout used; no WAIC/ranking computed"),file.path(out,"validation.txt"))
cat(paste(readLines(file.path(out,"validation.txt")),collapse="\n"),"\n")

}
