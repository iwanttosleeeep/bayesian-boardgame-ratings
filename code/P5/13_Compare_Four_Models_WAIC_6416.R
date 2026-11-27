# STAT6106 P5: four-model development WAIC, 6416 matched games.
# Postprocessing only; base R; script-based checkout and original-cache discovery.
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
repo_check_paths(c(p5_input("train", required=FALSE),
  p5_input("a_draws", required=FALSE),
  p5_input("d_draws", required=FALSE),
  repo_path("outputs/P4/ExternalSD_6416/matched_baseline/pointwise_loglik_share.rds"),
  repo_path("outputs/P4/ExternalSD_6416/external_sd/pointwise_loglik_share.rds")))

base <- .p5_cache
train_path <- p5_input("train", required=FALSE)
a_path <- p5_input("a_draws", required=FALSE)
d_path <- p5_input("d_draws", required=FALSE)
inputs <- c(train_path, a_path, d_path)
if (!all(file.exists(inputs))) stop("Check working directory. Missing:\n", paste(inputs[!file.exists(inputs)], collapse="\n"))
p5_training_provenance(readRDS(a_path), train_path)
train <- read.csv(train_path, stringsAsFactors=FALSE)
a <- readRDS(a_path)
d <- readRDS(d_path)
ids <- as.character(train$id)
N <- length(ids)
y <- train$average_2022
n <- train$n_2022
v <- train$sd_hist^2/n
stopifnot(N==6416L, !anyDuplicated(ids), all(is.finite(y)),
          all(is.finite(n) & n>=30), all(is.finite(v) & v>0),
          identical(as.character(a$ids), ids),
          identical(unname(a$input_md5), unname(tools::md5sum(train_path))),
          isTRUE(all.equal(as.numeric(d$x_center), mean(log(n)), tolerance=1e-9)))
for (term in c("s ~ dunif(0.5, 3)", "tau ~ dt(0, 1, 1) T(0,)", "y[i] ~ dnorm(alpha, prec[i])")) stopifnot(grepl(term,a$model,fixed=TRUE))
for (term in c("gamma ~ dnorm(0, 1)", "a_tau ~ dnorm(log(0.85), 4)", "b_tau ~ dnorm(0, 16)", "v_obs[i]")) stopifnot(grepl(term,d$model,fixed=TRUE))
x <- log(n)-d$x_center
# The original P5 scripts concatenate four chains of 3000 retained rows.
# Select 125 equally spaced retained rows within each chain, as in P4.
select_draws <- function(fit, params) {
  z <- as.matrix(fit$draws)
  stopifnot(nrow(z)==12000L, all(params %in% colnames(z)), all(is.finite(z[,params,drop=FALSE])))
  within <- as.integer(round(seq(1,3000,length.out=125)))
  idx <- unlist(lapply(0:3,function(k) k*3000L+within))
  stopifnot(length(idx)==500L,!anyDuplicated(idx))
  z[idx,params,drop=FALSE]
}
za <- select_draws(a,c("alpha","s","tau"))
zd <- select_draws(d,c("alpha","gamma","a_tau","b_tau"))
stopifnot(all(za[,"s"]>0),all(za[,"tau"]>0))

# Choose local copies of the two PR #5 RDS files, in this order.
# Use the repository copies automatically if they exist in the working directory.
load_p4 <- function(mode, label, external) {
  path <- repo_path("outputs","P4","ExternalSD_6416",mode,"pointwise_loglik_share.rds")
  path <- repo_existing(path,paste("P4",mode,"6416 likelihood"))
  obj <- readRDS(path)
  stopifnot(is.list(obj),identical(dim(obj$loglik),c(500L,6416L)),
            identical(as.character(obj$ids),ids),identical(colnames(obj$loglik),ids),
            is.numeric(obj$loglik),all(is.finite(obj$loglik)),
            nrow(obj$draw_index)==500L,!anyDuplicated(obj$draw_index),
            identical(as.integer(table(obj$draw_index$chain)),rep(125L,4)))
  if (external) {
    stopifnot(grepl("v_obs[i]",obj$model,fixed=TRUE),!grepl("s ~ dunif",obj$model,fixed=TRUE))
  } else {
    stopifnot(grepl("pow(s, 2)/n[i]",obj$model,fixed=TRUE),grepl("s ~ dunif(0.5, 3)",obj$model,fixed=TRUE))
  }
  cat("PASS:",label,"500 x 6416, ordered IDs, chain indices and model\n")
  obj$loglik
}

waic_one <- function(ll,model) {
  stopifnot(identical(dim(ll),c(500L,6416L)),all(is.finite(ll)))
  mx <- apply(ll,2,max)
  lppd <- mx+log(colMeans(exp(sweep(ll,2,mx,"-"))))
  p <- apply(ll,2,var)
  point <- -2*(lppd-p)
  list(point=point,penalty=p,tab=data.frame(model=model,games=N,posterior_draws=nrow(ll),
       lppd=sum(lppd),p_waic=sum(p),elpd_waic=sum(lppd-p),WAIC=sum(point),
       SE_WAIC_gamewise_approx=sqrt(N*var(point)),max_pointwise_p_waic=max(p),
       n_pointwise_p_waic_gt_0_4=sum(p>0.4),fraction_pointwise_p_waic_gt_0_4=mean(p>0.4)))
}
# Normal likelihoods integrate out game theta; never use conditional theta draws.
ll <- t(vapply(seq_len(nrow(za)),function(i) {
  z <- za[i,]; dnorm(y,z["alpha"],sqrt(z["tau"]^2+z["s"]^2/n),log=TRUE)
},numeric(N)))
res <- list(M1a_Baseline=waic_one(ll,"M1a_Baseline"))
rm(ll); invisible(gc())
ll <- t(vapply(seq_len(nrow(zd)),function(i) {
  z <- zd[i,]; dnorm(y,z["alpha"]+z["gamma"]*x,sqrt(exp(2*(z["a_tau"]+z["b_tau"]*x))+v),log=TRUE)
},numeric(N)))
res$M1a_Extended <- waic_one(ll,"M1a_Extended")
rm(ll); invisible(gc())
res$M1b_Baseline <- waic_one(load_p4("matched_baseline","M1b Baseline",FALSE),"M1b_Baseline")
invisible(gc())
res$M1b_ExternalSD <- waic_one(load_p4("external_sd","M1b ExternalSD",TRUE),"M1b_ExternalSD")
invisible(gc())

main <- do.call(rbind,lapply(res,`[[`,"tab"))
main$delta_WAIC <- main$WAIC-min(main$WAIC)
main <- main[order(main$WAIC),]; rownames(main) <- NULL
pairs <- combn(names(res),2,simplify=FALSE)
pairwise <- do.call(rbind,lapply(pairs,function(p) {
  delta <- res[[p[2]]]$point-res[[p[1]]]$point
  data.frame(model_A=p[2],model_B=p[1],delta_WAIC_A_minus_B=sum(delta),
             SE_delta_WAIC_gamewise_approx=sqrt(N*var(delta)))
}))
pointwise <- data.frame(id=ids)
for (nm in names(res)) {
  pointwise[[paste0(nm,"_pointwise_WAIC")]] <- res[[nm]]$point
  pointwise[[paste0(nm,"_p_waic")]] <- res[[nm]]$penalty
}
out <- "P5_WAIC_Comparison_6416"
dir.create(out,showWarnings=FALSE)
write.csv(main,file.path(out,"WAIC_four_model_summary.csv"),row.names=FALSE)
write.csv(pairwise,file.path(out,"WAIC_pairwise_differences.csv"),row.names=FALSE)
write.csv(pointwise,file.path(out,"WAIC_gamewise_diagnostics.csv"),row.names=FALSE)
writeLines(c(
  "Same 6416 development games; 500 retained draws/model, 125 per chain.",
  "M1a draw selection assumes the original 4 x 3000 chain-concatenated saved matrices.",
  "M1a Extended saved RDS has no ID vector; original local input and training center checked, not an independent RDS-to-ID provenance verification.",
  "All models score the observed game-average rating, integrating game theta.",
  "M1b conditions on learned named-designer effects and integrates independent anonymous effects.",
  "Conditional WAIC may be unreliable, especially for singleton designers; not unseen-designer prediction.",
  "p_waic_i > 0.4 is a warning; report counts and proportions, not a definitive ranking.",
  "Gamewise SE assumes independent units and does not account for shared designers; descriptive only.",
  "Do not compare numerical WAIC with the 6489-game table or the count-model WAIC.",
  "Use aligned exploratory holdout results as the primary predictive comparison.",
  "Historical SD timing is unverified and plug-in uncertainty is not propagated."
),file.path(out,"WAIC_interpretation_and_checks.txt"))
print(main,row.names=FALSE,digits=7)
print(pairwise,row.names=FALSE,digits=7)
cat("\nDONE: ",normalizePath(out),"\n",sep="")
