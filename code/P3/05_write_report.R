args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[1], winslash = "/") else getwd()
setwd(root)
dir.create("report/sections", recursive = TRUE, showWarnings = FALSE)
dir.create("slides/P3", recursive = TRUE, showWarnings = FALSE)

audit <- read.csv("tables/P3/M2_sample_audit.csv")
waic <- read.csv("tables/P3/M2_WAIC.csv")
dic <- read.csv("tables/P3/M2_DIC.csv")
effects <- read.csv("tables/P3/M2_NB_effects.csv")
ppc <- read.csv("tables/P3/M2_NB_PPC.csv")
sensitivity <- read.csv("tables/P3/M2_prior_sensitivity.csv")
posts <- list(Poisson = readRDS("outputs/P3/M2_Poisson_posterior.rds"),
              NB = readRDS("outputs/P3/M2_NB_posterior.rds"))
wide <- readRDS("outputs/P3/M2_NB_wide_posterior.rds")
convergence <- lapply(c("Poisson", "NB"), function(label) {
  read.csv(paste0("tables/P3/M2_", label, "_convergence.csv"))
})
wide_convergence <- read.csv("tables/P3/M2_NB_wide_convergence.csv")

f <- function(x, digits = 0) formatC(x, format = "f", digits = digits, big.mark = ",")
interval <- function(lo, hi, digits = 2) paste0("[", f(lo, digits), ", ", f(hi, digits), "]")
get_effect <- function(term) effects[effects$term == term, ][1, ]
effect_line <- function(term, label) {
  z <- get_effect(term)
  paste0("| ", label, " | ", f(z$rr_median, 2), " | ",
         interval(z$rr_q025, z$rr_q975), " |")
}
get_ppc <- function(statistic, column) ppc[[column]][ppc$statistic == statistic]
get_sensitivity <- function(parameter, column) {
  sensitivity[[column]][sensitivity$parameter == parameter]
}
engine <- vapply(posts, function(p) {
  if (!is.null(p$run$implementation)) p$run$implementation else p$run$engine
}, character(1))
engine_text <- if (all(engine == "MCMC")) "custom preconditioned MALA" else paste(engine, collapse = " and ")
max_rhat <- max(vapply(convergence, function(z) max(z$rhat, na.rm = TRUE), numeric(1)))
min_ess <- min(vapply(convergence, function(z) min(z$ess, na.rm = TRUE), numeric(1)))
waic_p <- waic[waic$model == "Poisson", ]
waic_nb <- waic[waic$model == "NB", ]
dic_p <- dic[dic$model == "Poisson", ]
dic_nb <- dic[dic$model == "NB", ]
draws_used <- waic_nb$posterior_draws
age <- get_effect("z_game_age")
play <- get_effect("z_log_play")
designer <- get_effect("multi_designer")
age_wide <- exp(get_sensitivity("delta", "wide_median"))
play_wide <- exp(get_sensitivity("beta[1]", "wide_median"))
designer_wide <- exp(get_sensitivity("beta[45]", "wide_median"))
r_base <- get_sensitivity("r", "base_median")
r_wide <- get_sensitivity("r", "wide_median")

report <- c(
"# M2: Rating-count popularity",
"",
"## Data and model",
"",
paste0("We used P1's cleaned `data_clean.csv`. The modelling sample contained ",
       f(audit$value[audit$item == "Complete M2 rows"]), " games with complete data for all predictors; ",
       f(audit$value[audit$item == "Dropped incomplete rows"]), " of the original ",
       f(audit$value[audit$item == "P1 cleaned rows"]), " rows were incomplete. Poisson and negative-binomial models used exactly the same games. The models were fitted to the full cleaned table rather than a separate development sample. Therefore, the model comparison below is a full-sample, within-M2 comparison, not an independent holdout evaluation."),
"",
"The outcome was `users_rated`. Because the data contain games with at least 30 ratings, both count distributions were left-truncated at 30. The linear predictor was",
"",
"```text",
"log(mu_i) = alpha + X_i beta + delta z_game_age_i.",
"```",
"",
"The predictors were log playing time, minimum and maximum players, minimum recommended age, 20 category indicators, 20 mechanic indicators, a multiple-designer indicator and log game age. Continuous predictors were standardized. Coefficient priors were Normal(0, 1), the intercept was Normal(log(median y), 2^2), and the negative-binomial dispersion parameter had a Gamma(2, 0.1) prior.",
"",
paste0("Four MCMC chains were run for each model, with 4,000 retained draws per model. The largest R-hat was ",
       f(max_rhat, 3), " and the smallest effective sample size was ", f(min_ess),
       ". The saved results were generated with ", engine_text,
       ". The included JAGS script fits the same model as an independent implementation; it does not claim to reproduce the same random draws."),
"",
"## Model comparison",
"",
"| Model | DIC | WAIC | Delta WAIC | pWAIC |",
"|---|---:|---:|---:|---:|",
paste0("| Poisson | ", f(dic_p$dic), " | ", f(waic_p$waic), " | ", f(waic_p$delta_waic), " | ", f(waic_p$p_waic), " |"),
paste0("| Negative binomial | ", f(dic_nb$dic), " | ", f(waic_nb$waic), " | 0 | ", f(waic_nb$p_waic), " |"),
"",
paste0("DIC followed the lecture formula `pD = Dbar - D(theta_bar)` and `DIC = Dbar + pD`. Both DIC and WAIC preferred the negative-binomial model, supporting substantial overdispersion. However, the NB estimate of pD was ",
       f(dic_nb$p_dic, 1), ", so its DIC penalty was not well behaved. We therefore used WAIC as the main comparison and treated DIC as a supplementary result. The very large Poisson WAIC and pWAIC also indicate severe model misfit, so the size of the WAIC difference should not be interpreted as an effect size. WAIC and DIC used all ",
       f(draws_used), " saved posterior draws, equally distributed across the four chains."),
"",
"## Feature associations",
"",
"Rate ratios were obtained by exponentiating the coefficients. For continuous variables, they describe a one-standard-deviation increase. For binary variables, they compare games with and without the feature, holding the other variables constant. The six main features are the primary results; the additional category and mechanic associations are exploratory.",
"",
"| Feature | Rate ratio | 95% credible interval |",
"|---|---:|---:|",
effect_line("z_log_play", "Log playing time"),
effect_line("z_minplayers", "Minimum players"),
effect_line("z_maxplayers", "Maximum players"),
effect_line("z_minage", "Minimum recommended age"),
effect_line("z_game_age", "Log game age"),
effect_line("multi_designer", "Multiple designers"),
effect_line("cat_Wargame", "Wargame category"),
effect_line("mech_Solo...Solitaire.Game", "Solo/Solitaire mechanic"),
effect_line("cat_Economic", "Economic category"),
effect_line("mech_Card.Drafting", "Card drafting mechanic"),
"",
"Older games tended to have more ratings. Playing time, minimum recommended age and having multiple designers were also positively associated with rating counts. These are conditional associations, not causal effects.",
"",
"![NB feature effects](../../figures/P3/M2_NB_effects_forest.png)",
"",
"## Prior sensitivity",
"",
paste0("We also fitted the NB model with Normal(0, 2^2) priors for the regression coefficients and an alternative Gamma(1, 0.1) prior for `r`. The data, likelihood and truncation were unchanged. Both prior components were changed together, so this comparison assesses their joint effect rather than isolating either one. The four chains had maximum R-hat ",
       f(max(wide_convergence$rhat, na.rm = TRUE), 3), " and minimum ESS ",
       f(min(wide_convergence$ess, na.rm = TRUE)), "."),
"",
paste0("The median rate ratios for the six main features were almost unchanged. For example, the estimates for log game age were ",
       f(age$rr_median, 3), " and ", f(age_wide, 3), " under the original and alternative priors, respectively. The corresponding estimates were ",
       f(play$rr_median, 3), " and ", f(play_wide, 3), " for log playing time, and ",
       f(designer$rr_median, 3), " and ", f(designer_wide, 3), " for multiple designers. Thus, the main feature associations were stable under these two prior choices."),
"",
paste0("The dispersion parameter was more sensitive: its posterior median decreased from ",
       f(r_base, 6), " to ", f(r_wide, 6), ". The alternative-prior 95% credible interval was ",
       interval(get_sensitivity("r", "wide_q025"), get_sensitivity("r", "wide_q975"), 6),
       ". Therefore, the regression conclusions were robust in this comparison, but the extreme tail behaviour should still be interpreted cautiously."),
"",
"## Posterior predictive checks",
"",
"We generated 50 replicated datasets from each fitted model, conditional on counts being at least 30.",
"",
"| Statistic | Observed | NB predictive mean | 95% predictive interval |",
"|---|---:|---:|---:|",
paste0("| Proportion with exactly 30 ratings | ", f(get_ppc("exact_30", "observed"), 4), " | ", f(get_ppc("exact_30", "predictive_mean"), 4), " | ", interval(get_ppc("exact_30", "predictive_q025"), get_ppc("exact_30", "predictive_q975"), 4), " |"),
paste0("| Proportion with 30–39 ratings | ", f(get_ppc("band_30_39", "observed"), 4), " | ", f(get_ppc("band_30_39", "predictive_mean"), 4), " | ", interval(get_ppc("band_30_39", "predictive_q025"), get_ppc("band_30_39", "predictive_q975"), 4), " |"),
paste0("| Proportion with at least 10,000 ratings | ", f(get_ppc("at_least_10000", "observed"), 4), " | ", f(get_ppc("at_least_10000", "predictive_mean"), 4), " | ", interval(get_ppc("at_least_10000", "predictive_q025"), get_ppc("at_least_10000", "predictive_q975"), 4), " |"),
paste0("| Variance-to-mean ratio | ", f(get_ppc("variance_mean_ratio", "observed")), " | ", f(get_ppc("variance_mean_ratio", "predictive_mean")), " | ", interval(get_ppc("variance_mean_ratio", "predictive_q025"), get_ppc("variance_mean_ratio", "predictive_q975"), 0), " |"),
"",
paste0("The negative-binomial model reproduced the proportion with at least 10,000 ratings reasonably well, but other checks showed clear remaining misfit. Its predictive mean for the median count was about ",
       f(get_ppc("median", "predictive_mean")), ", compared with an observed median of ",
       f(get_ppc("median", "observed")), ". It also overpredicted the proportion with at least 1,000 ratings (",
       f(get_ppc("at_least_1000", "predictive_mean"), 3), " versus ",
       f(get_ppc("at_least_1000", "observed"), 3), ") and underestimated the concentration of games with 30–39 ratings. Therefore, the negative-binomial model was preferred to Poisson, but it should not be described as fitting all aspects of the data well."),
"",
"![NB posterior predictive checks](../../figures/P3/M2_NB_ppc_summary.png)",
"",
"## Conclusion",
"",
paste0("The negative-binomial model was clearly preferred to the Poisson model. Game age showed a substantial positive association among the main continuous predictors, while several category and mechanic indicators were also associated with popularity. The analysis is limited to ranked BGG games in the January 2022 snapshot and uses complete cases only. Since games below 30 ratings are absent and ",
       f(audit$value[audit$item == "Dropped incomplete rows"]), " incomplete rows were removed, the results should not be generalized to all published board games or interpreted causally.")
)
writeLines(report, "report/sections/P3_M2_popularity.md", useBytes = TRUE)

slides <- c(
"# P3 Slide 1 — Model and comparison",
"",
paste0("- Data: P1's `data_clean.csv`; ", f(audit$value[audit$item == "Complete M2 rows"]), " complete cases used by both models."),
"- Outcome: `users_rated`, with Poisson and negative-binomial distributions truncated at 30.",
"- Predictors: game characteristics, category/mechanic indicators, multiple designers and game age.",
paste0("- Four MCMC chains; 4,000 saved draws per model. Maximum R-hat ", f(max_rhat, 3), "; minimum ESS ", f(min_ess), "."),
paste0("- WAIC: Poisson ", f(waic_p$waic), "; negative binomial ", f(waic_nb$waic), "."),
paste0("- DIC: Poisson ", f(dic_p$dic), "; negative binomial ", f(dic_nb$dic), ". WAIC is the main criterion because NB has a negative pD."),
"- The negative-binomial model is preferred because rating counts are strongly overdispersed.",
"",
"Speaker note: Both models use exactly the same observations. DIC follows the lecture formula, while WAIC is the main comparison. These are full-sample, within-M2 comparisons, not holdout results. Exponentiating a coefficient gives a rate ratio, not a causal effect.",
"",
"# P3 Slide 2 — Main findings",
"",
paste0("- Log game age: RR ", f(age$rr_median, 2), ", 95% CrI ", interval(age$rr_q025, age$rr_q975), "."),
paste0("- Log playing time: RR ", f(play$rr_median, 2), ", 95% CrI ", interval(play$rr_q025, play$rr_q975), "."),
paste0("- Multiple designers: RR ", f(designer$rr_median, 2), ", 95% CrI ", interval(designer$rr_q025, designer$rr_q975), "."),
paste0("- Wargame category: RR ", f(get_effect("cat_Wargame")$rr_median, 2), ", 95% CrI ", interval(get_effect("cat_Wargame")$rr_q025, get_effect("cat_Wargame")$rr_q975), "."),
paste0("- Solo/Solitaire mechanic: RR ", f(get_effect("mech_Solo...Solitaire.Game")$rr_median, 2), ", 95% CrI ", interval(get_effect("mech_Solo...Solitaire.Game")$rr_q025, get_effect("mech_Solo...Solitaire.Game")$rr_q975), "."),
paste0("- Economic category: RR ", f(get_effect("cat_Economic")$rr_median, 2), ", 95% CrI ", interval(get_effect("cat_Economic")$rr_q025, get_effect("cat_Economic")$rr_q975), "."),
"",
paste0("The negative-binomial model predicts the proportion with at least 10,000 ratings reasonably well: observed ",
       f(get_ppc("at_least_10000", "observed"), 4), ", predictive mean ",
       f(get_ppc("at_least_10000", "predictive_mean"), 4), ". However, its predictive median is about ",
       f(get_ppc("median", "predictive_mean")), " versus ", f(get_ppc("median", "observed")),
       " observed, and it also misses the 30–39 group and other summary statistics. It fits better than Poisson, but not every aspect of the data."),
"",
paste0("Alternative priors left the main feature rate ratios almost unchanged, but the NB dispersion median decreased from ",
       f(r_base, 6), " to ", f(r_wide, 6), ". The main associations were stable, while the extreme tail interpretation remained uncertain."),
"",
"Conclusion: older games and several game features are associated with higher rating counts, and the negative-binomial model fits better than Poisson. These results are associational, not causal, and apply only to ranked games with at least 30 ratings."
)
writeLines(slides, "slides/P3/P3_presentation.md", useBytes = TRUE)
cat("Report and presentation updated from the saved result tables.\n")
