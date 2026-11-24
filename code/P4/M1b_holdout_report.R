# Summarize existing predictions only; does not fit or generate predictions.
root<-"outputs/P4/Holdout_3209"
labels<-c("matched_baseline","external_sd")
dirs<-file.path(root,labels)
a<-read.csv(file.path(dirs[1],"holdout_game_predictions.csv"),fileEncoding="UTF-8")
b<-read.csv(file.path(dirs[2],"holdout_game_predictions.csv"),fileEncoding="UTF-8")
stopifnot(nrow(a)==3209,identical(a$id,b$id),identical(a$designer_group,b$designer_group),
 identical(a$n,b$n),identical(a$sd_hist,b$sd_hist),identical(a$observed_average,b$observed_average))
paired<-a[,c("id","n","designer_group","designer_name")]
paired$log_predictive_density_baseline<-a$log_predictive_density
paired$log_predictive_density_external<-b$log_predictive_density
paired$external_minus_baseline<-b$log_predictive_density-a$log_predictive_density
write.csv(paired,file.path(root,"paired_log_predictive_density.csv"),row.names=FALSE,fileEncoding="UTF-8")
summary<-do.call(rbind,lapply(dirs,function(d)read.csv(file.path(d,"holdout_summary.csv"))))
ppc<-do.call(rbind,lapply(dirs,function(d)read.csv(file.path(d,"holdout_grouped_PPC.csv"))))
write.csv(summary,file.path(root,"holdout_summary.csv"),row.names=FALSE)
write.csv(ppc,file.path(root,"holdout_grouped_PPC.csv"),row.names=FALSE)
write.csv(data.frame(metric=c("ELPD_external_minus_baseline","games","draws_each_model"),
 value=c(sum(paired$external_minus_baseline),3209,16000)),file.path(root,"paired_summary.csv"),row.names=FALSE)
fmt<-function(x,digits=3)formatC(x,format="f",digits=digits)
lines<-c("# P4: exploratory holdout validation on 3,209 games","",
 "Only the PR #5 same-6,416-game matched_baseline and external_sd posteriors are reused. No refitting or tuning. Original 6,489-game models, upper-6 sensitivity, training PPC and WAIC files are unchanged.","",
 "Sample: comparison_sample.csv order, filtered using P5's published full historical SD matching audit and its exact validation rule. P5's individual holdout cache was not uploaded; this reconstruction matches its published group counts/observed moments and rating-count-discrepancy share. See [sample checks](sample_validation.txt), [IDs](holdout_ids.csv), [metadata](holdout_metadata.csv), [matching audit](holdout_matching_audit.csv) and [source SHA256](source_manifest.csv).", "",
 "## Full-posterior evaluation","",
 "All 4×4,000 retained parameter draws/model are used, one chain at a time in batches of 128. No parameter thinning or subset selection. Pointwise density analytically integrates theta/new designer effects; joint replicates share each unseen named designer effect and keep anonymous effects independent.","",
 "| Model | Games | Holdout ELPD | 95% coverage | Mean interval width |",
 "|---|---:|---:|---:|---:|")
for(label in labels) {
 r<-summary[summary$model==label&summary$group=="all",]
 lines<-c(lines,paste0("| ",label," | ",r$games," | ",fmt(r$ELPD)," | ",fmt(100*r$coverage_95,2),"% | ",fmt(r$mean_interval_width)," |"))
}
lines<-c(lines,"",paste0("Paired pointwise ELPD difference (ExternalSD minus original): **",fmt(sum(paired$external_minus_baseline)),"**. This is holdout ELPD, not WAIC. [Per-game paired values](paired_log_predictive_density.csv) are supplied to P5; no cross-model ranking is published here."),
 "No inferential SE is reported: games share seen/new designers. Individual-game independence would be an insufficient uncertainty assumption. Per-chain log predictive densities are retained to inspect Monte Carlo variation; they are not independent-game uncertainty intervals.","",
 "## Designer and rating-count summaries","",
 "| Model | Group | Games | ELPD | Coverage | Mean width |",
 "|---|---|---:|---:|---:|---:|")
for(k in which(summary$group!="all")) {
 r<-summary[k,];lines<-c(lines,paste0("| ",r$model," | ",r$group," | ",r$games," | ",fmt(r$ELPD)," | ",fmt(100*r$coverage_95,2),"% | ",fmt(r$mean_interval_width)," |"))
}
lines<-c(lines,"","Seen/unseen classification uses the actual 6,416-game designer map, not the 6,489-game fit. Missing and (Uncredited) are separate groups. [Unseen-name mapping](unseen_designer_mapping.csv) records repeated unseen designers.",
 "P5's selected count bands are 30–40, 100–200, 1000–5000 and >5000; the two added complementary bands make the count summary exhaustive.","",
 "## Joint grouped PPC","",
 "| Model | Group | Observed mean within 95% replicated interval | Observed variance within 95% replicated interval |",
 "|---|---|---|---|")
for(k in seq_len(nrow(ppc))) {
 r<-ppc[k,];lines<-c(lines,paste0("| ",r$model," | ",r$group," | ",r$mean_in_95_interval," | ",r$variance_in_95_interval," |"))
}
lines<-c(lines,"","[Full grouped PPC](holdout_grouped_PPC.csv) contains observed values and numerical intervals. Each row derives from whole-sample joint replications with a common parameter draw and the correct designer dependence. These are holdout observed-average predictions, not training PPC or conditional theta intervals.","",
 "## Reproduction, storage and limits","",
 "[Specification and commands](../../../docs/P4_HOLDOUT_3209.md). Each model directory contains holdout_game_predictions.csv, holdout_summary.csv, holdout_grouped_PPC.csv, draw_index.csv, run_configuration.csv, chain_log_predictive_density.csv, memory_samples.csv and validation.txt.",
 "[Implementation/final checks](final_validation.txt), [original-file protection](protection_validation.txt) and [export hashes](file_manifest.csv) document validation. source_manifest.csv records actual execution bytes (including local complete posterior files); exported text hashes use Git LF normalization.",
 "Local-only ignored files: prediction_inputs.rds and each model's predictive_draws.rds, plus logs/sessionInfo. Joint draws are rows=real chain/retained-row draws and columns=ordered games. Their sizes/hashes are inventoried, not download links; regenerate with the documented commands and the original local parameter chains. CSV summaries cannot reconstruct a joint posterior.","",
 "The target is observed average rating conditional on current n and covariates. Historical SD remains a fixed plug-in with unverified snapshot date and ignored estimation uncertainty. Shared/new-designer effects are associations. Feature-selection and first-listed-designer limitations persist. The team explored this holdout earlier, so this is not a pristine untouched final test. No validation-driven model changes are made.")
writeLines(lines,file.path(root,"README.md"),useBytes=TRUE)
cat("PASS: paired holdout comparison and README generated\n")
print(summary[summary$group=="all",],row.names=FALSE)
