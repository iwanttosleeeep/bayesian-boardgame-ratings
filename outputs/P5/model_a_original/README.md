# Original Model A — baseline for P5

**This is the original intercept-only M1a baseline**, not the earlier common-s Model D. The original experiment was on the **full TidyTuesday ratings.csv (~21,831 ranked games)** and was recorded in the November 21 conversation.

Formula:

```
y_i ~ N(alpha, tau^2 + s^2/n_i)
alpha ~ N(6.4, 1^2)
tau ~ Half-Cauchy(0,1)
s ~ Uniform(0.5,3)
m = s^2/tau^2
```

Historical posterior summary: alpha 6.4361; tau 0.8641; s 2.9884, with 95% CrI [2.957, 2.9997]; m about 11.96. MCMC numerical diagnostics passed, but s concentrated near the upper prior boundary and the grouped PPC showed clear model inadequacy.

The two CSVs here **transcribe previously reported numerical outputs** in the uploaded 2026-11-21 chat export. They are NOT newly rerun experiment outputs; no baseline RDS or complete historical model object has been provided. The companion reproduction script at `code/P5/P5_00_Model_A_original_baseline.R` can be run by the student to produce fresh artifacts, which may differ slightly because the original random initialization was not archived.

## Model lineage

- **A:** constant mean, constant between-game tau, common unknown s (original baseline)
- **B:** variable tau with count, constant mean
- **C:** variable mean with count, constant tau
- **D (old):** variable mean AND tau with count, common unknown s
- **D (external SD):** same D mean/dispersion structure, but per-game historical SD used as plug-in rather than unknown shared s

**Caution:** prior same-sample comparison (old D vs external-SD D) is NOT an A-vs-D comparison. The original full-data A results cannot be compared directly to 6,416-game development model scores or ELPD. A valid matched-sample A-vs-D predictive comparison requires fitting A on the same 6,416 development games and scoring the same holdout set.

The Model D external-SD experiment has additional historical game-level information not used by A; interpret any prediction gains and shrinkage differences accordingly.
