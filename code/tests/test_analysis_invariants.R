# Compare model strings, RNG/fit calls and sampler settings with origin/main.
# Parses code only: no analysis is executed.
args <- commandArgs(TRUE); root <- normalizePath(if(length(args)) args[1] else ".",winslash="/")
files <- system2("git",c("-C",shQuote(root),"diff","--name-only","origin/main","--","code/P2","code/P5","code/P4/M1b_export_WAIC_6489.R"),stdout=TRUE)
files <- files[grepl("[.]R$",files)]
collect <- function(exprs) {
  found <- character()
  visit <- function(x) {
    if (is.character(x) && any(grepl("model[[:space:]]*[{]|~[[:space:]]*d(norm|unif|gamma|pois|negbin|t)[(]",x)))
      found <<- c(found,paste(x,collapse="\n"))
    if (is.call(x)) {
      op <- paste(deparse(x[[1]]),collapse="")
      if (op %in% c("set.seed","RNGkind","jags.model","rjags::jags.model","coda.samples","jags.samples","update","rnorm","runif","rbinom","rnbinom","fit_m0_gibbs","fit_m0_jags","fit_m0_cavi","m1b_fit"))
        found <<- c(found,paste(deparse(x),collapse="\n"))
      if (op %in% c("<-","=") && is.symbol(x[[2]]) && grepl("^(SEED|N_ITER|N_BURN|N_CHAINS|N_SAMPLE|N_ADAPT|THIN|seeds|B_per_chain)$",as.character(x[[2]])))
        found <<- c(found,paste(deparse(x),collapse="\n"))
    }
    if (is.call(x) || is.expression(x) || is.pairlist(x)) {
      parts <- as.list(x)
      for (i in seq_along(parts)) {
        if (identical(unname(parts[i]),unname(alist(x=)))) next
        if (!is.symbol(parts[[i]])) visit(parts[[i]])
      }
    }
  }
  visit(exprs); found
}
for (f in files) {
  old <- system2("git",c("-C",shQuote(root),"show",shQuote(paste0("origin/main:",f))),stdout=TRUE)
  a<-collect(parse(text=gsub("\r","",old,fixed=TRUE)));b<-collect(parse(file=file.path(root,f)))
  if (!identical(a,b)) {cat("Mismatch:",f,"\n");print(setdiff(a,b));print(setdiff(b,a));stop("Analysis invariant changed") }
}
cat("PASS:",length(files),"changed R files retain model strings, fitting/RNG calls and sampler settings\n")
