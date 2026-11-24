root<-"outputs/P4/ExternalSD_6416";out<-file.path(root,"comparison")
p<-read.csv(file.path(out,"scales.csv"));bet<-read.csv(file.path(out,"coefficients.csv"))
g<-read.csv(file.path(out,"grouped_shrinkage.csv"))
fmt<-function(x)ifelse(is.na(x),"removed",formatC(x,digits=4,format="f"))
lines<-c("# P4: same-sample M1b versus M1b-ExternalSD","",
 "Executed 2026-11-24; primary contrast uses identical 6,416 development games, design and designer map.",
 "ExternalSD changes only shared s²/n to fixed sd_hist²/n and removes s/prior. Constant tau and remaining priors are unchanged.",
 "Original 6,489-game results and WAIC share remain preserved. No three-model WAIC is computed here.","",
 "See [specification, provenance and reproduction](../../../docs/P4_EXTERNALSD.md), [matching audit](matching_audit.csv), [historical SD](historical_sd_matched.csv) and [source hashes](source_manifest.csv).","",
 "## Full-chain diagnostics and resources","",
 "| Run | Draws/chain | Max R-hat | Min bulk/tail ESS | Max mean MCSE/SD | All pass | Seconds | Peak working set MiB |",
 "|---|---:|---:|---:|---:|---|---:|---:|")
for(run in c("matched_baseline","external_sd")) {
 path<-file.path(root,run);dg<-read.csv(file.path(path,"diagnostics.csv"));pr<-tail(read.csv(file.path(path,"progress.csv")),1)
 mem<-read.csv(file.path(path,"memory_samples.csv"))
 lines<-c(lines,paste0("| ",run," | ",pr$draws_per_chain," | ",fmt(max(dg$rhat))," | ",round(min(dg$ess_bulk))," / ",
  round(min(dg$ess_tail))," | ",fmt(max(dg$mcse_mean_over_sd))," | ",all(dg$pass)," | ",round(pr$elapsed,1)," | ",round(max(mem$working_set_MB))," |"))
 write.csv(dg[!grepl("^u\\[",dg$parameter),],file.path(path,"parameter_summary.csv"),row.names=FALSE)
 settings<-readRDS(file.path(path,"run_settings.rds"))
 write.csv(data.frame(chain=1:4,seed=settings$seeds,adapt=settings$adapt,burn=settings$burn,
  retained=pr$draws_per_chain,glm=settings$glm),file.path(path,"chain_configuration.csv"),row.names=FALSE)
}
lines<-c(lines,"","Time includes compile/adapt/burn/sample and batch diagnostics; exports occur afterward. Working-set peaks are observed samples, not an absolute RAM bound.","",
 "## Scale changes (ExternalSD minus same-sample original)","",
 "| Parameter | Original mean [95% interval] | External mean [95% interval] | Mean change | MCSE of mean change |",
 "|---|---|---|---:|---:|")
for(k in seq_len(nrow(p))) {r<-p[k,];lines<-c(lines,paste0("| ",r$parameter," | ",fmt(r$mean_baseline)," [",fmt(r$lower95_baseline),", ",fmt(r$upper95_baseline),"] | ",
 fmt(r$mean_external)," [",fmt(r$lower95_external),", ",fmt(r$upper95_external),"] | ",fmt(r$mean_change)," | ",fmt(r$change_mcse)," |"))}
lines<-c(lines,"","## Main standardized covariates","",
 "| Term | Original mean [95% interval] | External mean [95% interval] | Change MCSE |",
 "|---|---|---|---:|")
for(k in 1:6){r<-bet[k,];lines<-c(lines,paste0("| ",r$term," | ",fmt(r$mean_baseline)," [",fmt(r$lower95_baseline),", ",fmt(r$upper95_baseline),"] | ",
 fmt(r$mean_external)," [",fmt(r$lower95_external),", ",fmt(r$upper95_external),"] | ",fmt(r$change_mcse)," |"))}
lines<-c(lines,"","All coefficient magnitudes, directions and interval changes: [coefficients.csv](comparison/coefficients.csv).",
 "Per-designer mean/95% interval/MCSE and number of training games: [designer_effects.csv](comparison/designer_effects.csv). Effects are associations, not causal contributions.","",
 "There are 3,192 named groups: 2,307 with one game and 885 repeated groups. The median absolute change in designer posterior means is 0.0167 rating points; the largest changes occur in single-game groups (maximum 0.4264). [Grouped summaries](comparison/designer_groups.csv) separate one-game and repeated groups.","",
 "![Designer effect comparison](comparison/designer_effects.png)","",
 "The main continuous slopes retain their mean directions. log1p_n decreases from 0.2213 to 0.2108; the small maxplayers_capped interval changes from excluding zero to including zero. The only mean sign flip is missing_minplayers, with wide intervals spanning zero in both models.",
 "The control s mean is 2.9816, near its preserved upper prior bound of 3. This contrast therefore includes the consequences of that original prior constraint; it is not a comparison with the prior-upper-6 sensitivity fit.","",
 "tau increases by 0.0558 and sigma_d by 0.0314. These changes exceed Monte Carlo mean error, while the model-specific credible intervals describe posterior uncertainty and are not a paired effect test.","",
 "## Latent ratings and shrinkage","",
 "Means and their MCSE below use the same 125 evenly-spaced retained rows per chain (500/model). Full 1,000-draw latent exports are also retained locally. MCSE describes numerical precision, not scientific effect uncertainty.","",
 "| Group | Games | Median absolute theta change | Original median absolute adjustment | External median absolute adjustment | Median change MCSE |",
 "|---|---:|---:|---:|---:|---:|")
for(k in seq_len(nrow(g))){r<-g[k,];lines<-c(lines,paste0("| ",r$group," | ",r$games," | ",fmt(r$median_abs_change)," | ",
 fmt(r$baseline_median_abs_adjustment)," | ",fmt(r$external_median_abs_adjustment)," | ",fmt(r$median_change_mcse)," |"))}
lines<-c(lines,"","![Latent changes by rating count](comparison/latent_changes.png)","",
 "## Development PPC","",
 "| Run | Group | Mean within 95% predictive interval | Variance within 95% predictive interval |",
 "|---|---|---|---|")
for(run in c("matched_baseline","external_sd")){
 pp<-read.csv(file.path(root,run,"development_PPC.csv"))
 for(k in seq_len(nrow(pp))){r<-pp[k,];lines<-c(lines,paste0("| ",run," | ",r$group," | ",
  r$observed_mean>=r$predicted_mean_low & r$observed_mean<=r$predicted_mean_high," | ",
  r$observed_variance>=r$predicted_variance_low & r$observed_variance<=r$predicted_variance_high," |"))}
}
lines<-c(lines,"","Intervals and observed values: [PPC_comparison.csv](comparison/PPC_comparison.csv). These condition on named training designer effects and use development data; they are not holdout performance. Passing chain diagnostics does not prove model adequacy.","",
 "For n=30–40, ExternalSD moves the replicated mean interval toward the observed mean (6.162 is inside [6.065,6.165], versus the original [6.027,6.141]). Both still underpredict the observed variance 1.145; ExternalSD's interval [0.866,1.032] is farther below it than the original [0.939,1.129].",
 "For n>5000, both overpredict variance: observed 0.365, original interval [0.419,0.574], ExternalSD [0.467,0.647]. ExternalSD also overpredicts variance in n=1000–5000, where the original interval contains the observed variance. These mixed PPC results do not establish overall improvement.","",
 "## Files and reproduction","",
 "Each run directory contains train_game_ids.csv, designer_mapping.csv, model.bug, chain_configuration.csv, diagnostics.csv, progress.csv, memory_samples.csv and scale trace/ACF/joint PNGs.",
 "Only these two explicitly named binary shares are uploaded:","",
 "- [Matched original 500×6416 loglik](matched_baseline/pointwise_loglik_share.rds)",
 "- [ExternalSD 500×6416 loglik](external_sd/pointwise_loglik_share.rds)","",
 "Each RDS contains ids, draw_index (real chain and 1-based retained row), loglik (draws×games), convention, train_md5, model and source_manifest. No raw JAGS iteration numbering is invented. These files must not replace the old 6489 share or be numerically compared to its WAIC.",
 "For both, theta is integrated, named training effects conditioned, independent anonymous effects integrated as extra sigma_d². The observed unit is game-average rating conditional on n/X. This is not unseen-designer-group extrapolation.",
 "Local-only ignored RDS: inputs, preprocessing, settings, chain_1–4 (complete parameters and RNG state), full theta draws and 1000-row pointwise likelihood, plus joint balanced theta draws. They can be regenerated using the documented sequence; CSV summaries cannot reconstruct a joint posterior.",
 "[Export verification](comparison/verification.csv), [independent replay](final_validation.txt) and per-run export_validation.txt record numerical checks and reread. [file_manifest.csv](file_manifest.csv) records actual sizes/SHA256 and upload/local-only status for all new RDS artifacts. Input data hashes are in source_manifest.csv. postprocessing_sources.csv records the later comparison/report code separately.","",
 "## Limits","",
 "Historical SD is fixed, in rating units, with unverified acquisition date and no propagated SD estimation uncertainty. Median/max rating-count mismatch is 0.3%/62.3%; this may reflect temporal differences. Current users_rated is always the variance denominator.",
 "Only 6416 matched development games are modeled; 73 were excluded. The original 6489 parameter file is supplementary and also uses different standardization. Do not attribute across-sample differences to historical SD alone.",
 "Constant tau, first-listed-designer grouping, imputation and full-table P1 tag-selection caveats remain. Original simulated theta interval undercoverage is not erased by this extension. No component-specific causal explanation or predetermined ExternalSD improvement is warranted.")
writeLines(lines,file.path(root,"README.md"),useBytes=TRUE)
des<-read.csv(file.path(out,"designer_effects.csv"),fileEncoding="UTF-8")
summary<-data.frame(group=c("all_named","one_game","repeated"),designers=NA,
 median_absolute_mean_change=NA,max_absolute_mean_change=NA,mean_correlation=NA)
for(k in 1:3) {
 i<-switch(k,seq_len(nrow(des)),which(des$training_games==1),which(des$training_games>1))
 summary$designers[k]<-length(i)
 summary$median_absolute_mean_change[k]<-median(abs(des$mean_change[i]))
 summary$max_absolute_mean_change[k]<-max(abs(des$mean_change[i]))
 summary$mean_correlation[k]<-cor(des$mean_baseline[i],des$mean_external[i])
}
write.csv(summary,file.path(out,"designer_groups.csv"),row.names=FALSE)
cat("Designer groups: ",paste(summary$group,summary$designers,collapse="; "),"\n")
cat("PASS: ExternalSD comparison report generated\n")
