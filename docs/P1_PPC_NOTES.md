# P1 — Grouped PPC notes for M0 and M1a (updated 26 Nov 2026)

Re-ran `code/P1/06_grouped_ppc_m0_m1a.R` with the **6,489-game M1a refit draws**
(`outputs/P5/M1a_WAIC_6489/parameter_draws.rds`). The earlier 6,416-game
fallback is removed; the script now stops unless the draw file's own ID
sequence matches the 6,489 development games in row order (verified against
both `outputs/P2/M0_train_game_ids.csv` and
`outputs/P5/M1a_WAIC_6489/train_game_ids.csv` — 6,489 IDs, identical order).

Outputs: `tables/ppc_grouped_summary.csv` and `figures/ppc_*.png`, including
the new `ppc_variance_comparison_rating_count.png`.

## Conclusions

**1. Mean PPC — M0 is broadly calibrated; M1a is not designed to track group
means.** M0's predictive group means cover the observed mean in four of six
rating-count bands (Bayesian p in [0.05, 0.95]); it slightly under-predicts
the 30–40 band (p = 0.006) and slightly over-predicts the 100–200 band
(p = 0.960). M1a predicts a single global mean (alpha ≈ 6.435), so its group
means systematically miss at both ends (p = 1.000 / 0.000) — expected for an
intercept-only shrinkage model, not evidence against it.

**2. Variance PPC — M0's constant residual variance is the main limitation.**
M0 predicts essentially the same group variance (≈ 0.76–0.92) for every band:

| Band | Observed var | M0 pred (95% PI) | M0 p | M1a pred (95% PI) | M1a p |
| --- | ---: | --- | ---: | --- | ---: |
| 30–40 | 1.172 | 0.837 [0.760, 0.922] | 0.000 | 1.023 [0.924, 1.130] | 0.004 |
| 40–100 | 1.026 | 0.832 [0.778, 0.894] | 0.000 | 0.910 [0.846, 0.980] | 0.000 |
| 100–200 | 0.774 | 0.823 [0.764, 0.891] | 0.934 | 0.823 [0.761, 0.903] | 0.938 |
| 200–1000 | 0.610 | 0.824 [0.766, 0.881] | 1.000 | 0.788 [0.721, 0.855] | 1.000 |
| 1000–5000 | 0.516 | 0.795 [0.726, 0.873] | 1.000 | 0.768 [0.682, 0.868] | 1.000 |
| 5000+ | 0.365 | 0.765 [0.637, 0.909] | 1.000 | 0.757 [0.639, 0.919] | 1.000 |

More precisely, M0 **under-predicts variance at low rating counts** (30–40,
40–100; p = 0.000) and **over-predicts it at high counts** (1000–5000, 5000+;
p = 1.000). This is the expected consequence of a constant residual variance
assumption when observation noise actually decreases with the number of
ratings.

**3. M1a's variance structure is a step in the right direction but not enough.**
With `tau^2 + s^2/n_i`, M1a's predictive variance rises at low counts (1.02
for 30–40 vs M0's 0.84, much closer to the observed 1.17) yet still
over-predicts at high counts (0.76 vs observed 0.37 for 5000+). The remaining
high-count mismatch motivates the **Extended model with per-game historical
observation SD** — see `ppc_variance_comparison_rating_count.png`.

**4. Category PPC** flags several groups for both models (e.g. Wargame,
Party.Game, Fighting mean shifts; Fantasy/Economic variance mismatches),
indicating systematic differences across categories that neither M0's
covariates nor M1a's global shrinkage fully capture. Category-specific
effects are a candidate extension but out of scope for the current models.

**Caveats.** All checks are within the 6,489 development games (descriptive
model checking, not held-out validation). M1a's `s` posterior sits near its
prior upper bound, and pseudo-votes `m` are prior-sensitive — see
`outputs/P5/M1a_WAIC_6489/README.md`.
