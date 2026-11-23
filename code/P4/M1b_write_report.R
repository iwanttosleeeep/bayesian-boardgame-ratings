# Generate readable evidence from verified artifacts, without reading holdout.
v<-read.csv("outputs/P4/resources/final_verification.csv",stringsAsFactors=FALSE)
summary<-read.csv("outputs/P4/s_prior_comparison/summary.csv")
getmetric<-function(x)summary$value[match(x,summary$metric)]
coef<-read.csv("outputs/P4/s_prior_comparison/coefficient_comparison.csv",check.names=FALSE)
group<-read.csv("outputs/P4/s_prior_comparison/grouped_shrinkage.csv")
f<-function(x)formatC(x,digits=4,format="f")
lines<-c("# P4 — M1b development fit and diagnostic evidence","",
  "Updated 23 November 2026. Baseline retains constant tau and every prior in P4_BASELINE.md.",
  "Sensitivity is separately labeled: only the s prior changes from U(0.5,3) to U(0.5,6).",
  "All 6,489 development games are used; no holdout tuning/scoring or formal cross-team model comparison was performed.","",
  "**Interpretation:** Numerical shrinkage and variance allocation materially depend on the baseline s upper bound. The relaxed prior is a sensitivity result, not a replacement baseline.",
  paste0("Median absolute adjustment increases from ",f(getmetric("baseline_median_abs_adjustment"))," to ",
    f(getmetric("upper6_median_abs_adjustment"))," rating points (",round(100*(getmetric("upper6_median_abs_adjustment")/getmetric("baseline_median_abs_adjustment")-1)),"%)."),
  paste0("Mean-effect directions are more robust: all ",getmetric("strong_baseline_effects_retain_direction")," of ",
    getmetric("strong_baseline_effects")," baseline coefficients whose 95% intervals exclude zero retain their direction. This does not assert that every interval or coefficient magnitude is unchanged."),
  "The same low-count mean and high-count variance PPC discrepancies remain; no pristine test-set or global-ranking claim follows.","",
  "## Full-fit diagnostics","",
  "R-hat is rank-normalized/folded split R-hat; ESS is bulk/tail ESS from posterior.",
  "Targets are R-hat <=1.01, both ESS >=400, and MCSE(mean)/posterior SD <=0.05 for all monitored quantities.","",
  "| Run | Draws/chain | Max R-hat | Min bulk ESS | Min tail ESS | Max MCSE/SD | All pass |",
  "|---|---:|---:|---:|---:|---:|---|")
for(k in seq_len(nrow(v))) lines<-c(lines,paste0("| ",v$run[k]," | ",v$retained_per_chain[k]," | ",
  f(v$max_rhat[k])," | ",round(v$min_bulk_ess[k])," | ",round(v$min_tail_ess[k])," | ",
  f(v$max_mcse_mean_over_sd[k])," | ",v$all_diagnostics_pass[k]," |"))
lines<-c(lines,"","## Scale posterior and sensitivity","",
  "| Run | Parameter | Mean | 95% interval | R-hat | Bulk ESS | Tail ESS | Mean MCSE |",
  "|---|---|---:|---|---:|---:|---:|---:|")
for(run in v$run) {
  dg<-read.csv(file.path("outputs/P4",run,"diagnostics.csv"))
  for(param in c("tau","sigma_d","s")) {
    r<-dg[dg$parameter==param,]
    lines<-c(lines,paste0("| ",run," | ",param," | ",f(r$mean)," | [",f(r$lower95),", ",f(r$upper95),"] | ",
      f(r$rhat)," | ",round(r$ess_bulk)," | ",round(r$ess_tail)," | ",f(r$mcse_mean)," |"))
  }
}
lines<-c(lines,"","![s prior and posterior sensitivity](s_prior_comparison/s_prior_and_posterior.png)","",
  "## Shrinkage and within-development ranking sensitivity","",
  paste("Median absolute latent-mean change:",f(getmetric("median_absolute_theta_change")),"rating points."),
  paste("Largest absolute change:",f(getmetric("max_absolute_theta_change")),"rating points."),
  paste("Within-sample Spearman rank correlation:",f(getmetric("within_sample_rank_spearman")),
        "; Top 50 posterior-mean overlap:",getmetric("top50_overlap"),"/50."),
  paste("Mean coefficient signs agree:",getmetric("slopes_with_same_mean_sign"),"/",getmetric("slopes"),"."),"",
  "| Group | Games | Median absolute theta change | Baseline median absolute adjustment | Upper-6 median absolute adjustment |",
  "|---|---:|---:|---:|---:|")
for(k in seq_len(nrow(group))) lines<-c(lines,paste0("| ",group$group[k]," | ",group$games[k]," | ",
  f(group$median_absolute_theta_change[k])," | ",f(group$baseline_median_abs_adjustment[k])," | ",
  f(group$upper6_median_abs_adjustment[k])," |"))
lines<-c(lines,"","![Latent sensitivity](s_prior_comparison/latent_sensitivity.png)","",
  "These are within-development comparisons; they are not out-of-sample model selection, global BGG ranks, or causal effects.",
  "Small per-game mean/rank differences retain Monte Carlo error from the 1,000 selected parameter draws.","",
  "## Main standardized covariates","",
  "| Term | Baseline mean [95% interval] | Upper-6 mean [95% interval] |",
  "|---|---|---|")
for(k in 1:6) {
  r<-coef[k,]
  lines<-c(lines,paste0("| ",r$term," | ",f(r$mean_baseline)," [",f(r$lower95_baseline),", ",f(r$upper95_baseline),"] | ",
    f(r$mean_upper6)," [",f(r$lower95_upper6),", ",f(r$upper95_upper6),"] |"))
}
lines<-c(lines,"","## Development posterior predictive checks","",
  "These checks condition on training data and named designer effects; they are not holdout validation.","",
  "| Run | Rating-count group | Mean in 95% predictive interval | Variance in 95% predictive interval |",
  "|---|---|---|---|")
for(run in v$run) {
  pp<-read.csv(file.path("outputs/P4",run,"development_PPC.csv"))
  for(k in seq_len(nrow(pp))) {
    mean_ok<-with(pp,observed_mean>=predicted_mean_low & observed_mean<=predicted_mean_high)[k]
    var_ok<-with(pp,observed_variance>=predicted_variance_low & observed_variance<=predicted_variance_high)[k]
    lines<-c(lines,paste0("| ",run," | ",pp$group[k]," | ",mean_ok," | ",var_ok," |"))
  }
}
lines<-c(lines,"","Baseline already shows low-count mean and high-count variance discrepancies; MCMC convergence is not model adequacy.","",
  "## Actual full-run resources","",
  "| Run | Monitored elapsed seconds | Peak aggregate working set MB | Max sum of process peaks MB | Minimum available RAM MB |",
  "|---|---:|---:|---:|---:|")
for(run in v$run) {
  m<-read.csv(file.path("outputs/P4",run,"memory_samples.csv"))
  progress<-read.csv(file.path("outputs/P4",run,"progress.csv"))
  lines<-c(lines,paste0("| ",run," | ",round(tail(progress$elapsed,1),1)," | ",round(max(m$working_set_MB))," | ",
    round(max(m$sum_process_peak_MB))," | ",round(min(m$available_physical_MB))," |"))
}
lines<-c(lines,"","Elapsed includes compile/adaptation/burn-in, sampling and batch diagnostics; latent export occurs afterward.",
  "Working set is sampled every two seconds. Sum of individual process peaks is a conservative sum, not a simultaneous peak.","",
  "## Implementation evidence and limitations","",
  "- Original [400-game smoke record](smoke_record_README.md) and all original smoke files are retained.",
  "- [Extended 400-game diagnostics](extended_400/diagnostics.csv) meet targets at 8,000 new draws/chain; restart semantics are documented.",
  "- [Two full-structure simulations](simulation/recovery_overview.csv) recover scales/slopes/designer effects reasonably and reduce latent RMSE, but theta interval coverage is only 84–88% versus 95% oracle conditioning. Passing MCMC diagnostics does not resolve this calibration limitation.",
  "- Development has 901 repeated named designer groups (3,546 games), 2,320 singleton designers and 623 anonymous games. About half of all same-designer pairs come from the ten largest groups.",
  "- Shared s and constant tau are model assumptions; s-upper-6 is an explicitly relaxed boundary stress test, not a replacement baseline or a claim that all allowed SD values are physically plausible.",
  "- Numeric preprocessing is re-estimated and saved on each actual training sample; fixed P1 tag columns retain their documented full-table selection caveat.",
  "- Each formal directory contains training IDs, mapping, recipe, model, run settings, source snapshot/hashes, per-chain parameter/RNG state RDS, diagnostics, scale plots, latent draws and theta-integrated/designer-conditional log likelihood. Binary files remain local and Git-ignored.",
  "- The posterior overwrite guard protects samples. The delivery wrapper now refuses existing formal runs before opening logs; use a new directory via M1b_reproduce.R.","",
  "See [baseline decisions](../../docs/P4_BASELINE.md), [diagnostic notes](../../docs/P4_DIAGNOSTIC_NOTES.md), [commands](../../code/P4/README.md), and [final artifact verification](resources/final_verification.csv).")
writeLines(lines,"outputs/P4/README.md",useBytes=TRUE)
cat("Wrote P4 evidence report from verified artifacts\n")
