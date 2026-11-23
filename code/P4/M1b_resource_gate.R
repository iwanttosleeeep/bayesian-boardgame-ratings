# Resource gate is evidence-based; no holdout data are read.
stopifnot(file.exists("outputs/P4/simulation/review.txt"))
out<-"outputs/P4/timing_2000_corrected"
p<-read.csv(file.path(out,"progress.csv"))
m<-read.csv(file.path(out,"memory_samples.csv"))
a<-readRDS(file.path(out,"inputs.rds"))
stopifnot(nrow(p)>0,any(m$processes==5),all(is.finite(p$elapsed)))
dev<-read.csv("dev_subsample.csv",fileEncoding="UTF-8")
source("code/P4/M1b_prepare.R")
full<-m1b_prepare(dev)
warm<-read.csv(file.path(out,"worker_pids.csv"))
ratio<-nrow(dev)/a$prep$data$N
sample_sec_per_1000<-p$max_worker_batch_seconds[1]*1000/500*ratio
warm_sec<-max(warm$warmup_seconds)*4*ratio
estimate_4000<-warm_sec+4*sample_sec_per_1000
estimate_12000<-warm_sec+12*sample_sec_per_1000
raw_MB_4000<-4*4000*(4+full$data$P+full$data$J)*8/1024^2
raw_MB_12000<-3*raw_MB_4000
observed_peak<-max(m$sum_process_peak_MB)
# Conservative planning heuristic: graph/process overhead scales with N; allow
# seven copies of retained raw draws across workers, diagnostics and checkpoints.
plan_MB_4000<-observed_peak*ratio+7*raw_MB_4000
plan_MB_12000<-observed_peak*ratio+7*raw_MB_12000
metrics<-c(pilot_elapsed_seconds=p$elapsed[1],pilot_peak_aggregate_working_MB=max(m$working_set_MB),
  pilot_max_private_MB=max(m$private_MB),pilot_sum_process_peaks_MB=observed_peak,
  full_compile_warmup_est_seconds=warm_sec,full_sample_1000_est_seconds=sample_sec_per_1000,
  full_4000_est_seconds=estimate_4000,full_12000_est_seconds=estimate_12000,
  full_4000_raw_draw_MB=raw_MB_4000,full_12000_raw_draw_MB=raw_MB_12000,
  full_4000_memory_planning_MB=plan_MB_4000,full_12000_memory_planning_MB=plan_MB_12000)
write.csv(data.frame(metric=names(metrics),value=unname(metrics)),
          "outputs/P4/resources/resource_projection.csv",row.names=FALSE)
stopifnot(plan_MB_12000<24000,estimate_12000<7200)
writeLines(c("IMPLEMENTATION AND RESOURCE GATE: PASS for monitored full-development baseline run",
  "Implementation: independent Gaussian/covariance tests and two saved simulation fits pass; simulation calibration caveat retained.",
  "Resources: 32 GB installed RAM, 22 logical processors; four R workers plus directly launched x64 master measured.",
  paste("2000-game corrected pilot elapsed seconds:",round(p$elapsed[1],2)),
  paste("Measured pilot maximum aggregate working set MB:",round(max(m$working_set_MB),1)),
  paste("Projected full 4000/chain elapsed minutes:",round(estimate_4000/60,1)),
  paste("Projected full 12000/chain elapsed minutes:",round(estimate_12000/60,1)),
  paste("Planning RAM MB at 4000/12000 draws:",round(plan_MB_4000),round(plan_MB_12000)),
  "Time projection is linear in N/iterations, not a guarantee. Graph compilation, sparse factorization, diagnostics and posterior export can add cost.",
  "RAM planning is a heuristic (N-scaled pilot peak plus seven raw-draw copies), not an observed full-data bound.",
  "Use JAGS glm::Generic block updates with unchanged model/priors; actual sampler list and run settings are saved.",
  "Monitor actual memory and diagnostics. Do not claim convergence when the ceiling is reached.",
  "U(0.5,6) sensitivity is a separate boundary stress test; it is not a replacement baseline or a claim that s>5 is plausible for bounded ratings."),
  "outputs/P4/resources/implementation_resource_gate.txt")
cat(paste(readLines("outputs/P4/resources/implementation_resource_gate.txt"),collapse="\n"),"\n")
