# P5: M0 / M1a / M1b WAIC comparison (6,489 development games)

**Status:** Computed 2026-11-24 from the 500-draw pointwise log-likelihood files already committed by P2, P4, and P5. No models refitted, and no holdout observations used.

## Inputs and reproducibility

- Script: [code/P5/10_Compare_M0_M1a_M1b_WAIC_6489.R](../../../../code/P5/10_Compare_M0_M1a_M1b_WAIC_6489.R)
- M0 JAGS (primary): [outputs/P2/M0_loglik_jags_share.rds](../../../../outputs/P2/M0_loglik_jags_share.rds)
- M0 Gibbs (same-model sampler verification): [outputs/P2/M0_loglik_gibbs_share.rds](../../../../outputs/P2/M0_loglik_gibbs_share.rds)
- M1a (6,489-game Baseline refit): [archive/outputs/P5/M1a_WAIC_6489/pointwise_loglik_share.rds](../M1a_WAIC_6489/pointwise_loglik_share.rds)
- M1b (designer-conditional): [outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds](../../../../outputs/P4/M1b_WAIC_6489/pointwise_loglik_share.rds)

All matrices are 500 posterior draws × 6,489 games. IDs and column order were validated before WAIC calculations. M1a reproduces its independently calculated WAIC 17,496.14838. M0 Gibbs versus JAGS differs in WAIC by 0.01998.

## Output files

- `WAIC_three_model_summary.csv`: per-model lppd, pWAIC, elpdWAIC, WAIC, SE, diagnostics, and delta WAIC from the numerical minimum.
- `WAIC_pairwise_differences.csv`: signed pairwise WAIC gaps and **paired gamewise** standard errors.
- `M0_Gibbs_vs_JAGS_check.csv`: independent inference-method agreement for the *same* M0 model, not a fourth candidate model.
- `WAIC_interpretation_and_checks.txt`: interpretive precautions accompanying these tables.

### Values (development-sample WAIC, lower numerically is better)

| Model | WAIC | Delta WAIC | pWAIC |
|---|---:|---:|---:|
| M1b | 11,939.468 | 0 | 1,345.704 |
| M0 (JAGS) | 14,399.379 | 2,459.911 | 10.834 |
| M1a | 17,496.148 | 5,556.681 | 2.239 |

**Scientific caution:** M1b has 888 of 6,489 gamewise pWAIC values >0.4 (maximum 8.082), warning that regular WAIC may be unreliable. Its game theta is integrated out but **named designer effects remain conditioned on fitted training designer values**, whereas M1a has no designer effect and M0 is ordinary regression. Therefore the scores have different predictive-condition conventions; the numerical ordering does **not** establish relative out-of-sample performance for entirely new designers or isolate the effect of any one model component. These scores are **not independent holdout evaluation**. Do not combine them with P3 popularity-model WAIC.

The 6,416-game M1a Baseline/Extended historical-SD analysis is a separate experiment and is **not** included in this table.
