# How Much Should We Shrink a Board Game Rating?

**STAT6106 Bayesian Data Analysis | Group project**  
**Working repository overview — 22 Nov 2026**

We examine Bayesian shrinkage of BoardGameGeek (BGG) average ratings, how assumptions influence adjusted scores and ranking uncertainty, and how our results compare with BGG's own adjusted-rating benchmark. M0, M1b and M2 support the central M1a shrinkage analysis.

**Key dates:** 28 Nov — freeze **presentation results**; 1 Dec — ~15-minute presentation; **18 Dec — final report, code and data**. The presentation freeze is not the final analysis deadline.

## Repository guide

| Where | What you will find |
| --- | --- |
| **[P1 data guide](docs/P1_DATA_GUIDE.md)** | The four shared CSVs, scripts, cleaning rules and training/holdout contract |
| **[P1 original technical notes](docs/P1_PIPELINE_NOTES_2026-11-22.md)** | P1's detailed README preserved verbatim |
| **[Team plan and progress](docs/TEAM_PLAN_AND_STATUS.md)** | P1–P6 roles, handoffs, deadlines, verified status and limitations |
| **[P5 results](outputs/P5/README.md)** | M1a baseline, external-SD extension, tests and comparisons |
| **[P5 R scripts](code/P5/)** | Numbered P5 workflow |
| **[P1 script index](code/P1/README.md)** | Links to the four P1 scripts, which remain at the repository root |

**P1's original scripts and CSVs remain at the root** for backward compatibility. The new documentation organizes them without moving or rewriting source files.

## Fixed data contract

| Root file | Size | Correct use |
| --- | ---: | --- |
| [\`data_clean.csv\`](data_clean.csv) | 21,631 games × 83 columns | Full cleaned/engineered BGG table |
| [\`variable_dictionary.csv\`](variable_dictionary.csv) | 83 fields | Variable definitions, types and missingness |
| [\`dev_subsample.csv\`](dev_subsample.csv) | 6,489 games | **Development / fitting** |
| [\`comparison_sample.csv\`](comparison_sample.csv) | 3,244 games | **Independent-by-game holdout: NEVER use for fitting** |

The split uses seed **20261122**, randomly samples **games** rather than whole designers, and has no overlapping game IDs. **912 designer IDs** appear in both partitions: do not call this an unseen-designer validation split.

**Important:** \`comparison_sample.csv\` is *currently a holdout*, **not** the common complete-case training sample for WAIC described in the 20 Nov plan. M0/M1a/M1b WAIC needs separately agreed **common development game IDs**, comparable likelihoods, and consistent fits. Holdout ELPD and WAIC are different evaluations.

P5's two current models share **6,416** SD-matched development games and are evaluated on **3,209** SD-matched holdout games. These are *subsets* of P1's samples, **not all BGG games**. The holdout was inspected during earlier model exploration, so predictive comparison is exploratory.

## Team ownership and current GitHub status

**Status means artifacts verified in this repository, not whether a person has worked locally.** See the [detailed team plan](docs/TEAM_PLAN_AND_STATUS.md) for handoffs and dates.

| Owner | Responsibility | Repo status as of 22 Nov |
| --- | --- | --- |
| **P1** | Cleaning, features, dictionary, EDA, M0/M1 PPC | **Four data files + four scripts delivered**; own EDA/PPC artifacts not verified |
| **P2** | M0 Bayesian regression, JAGS/Gibbs/CAVI; M1b runtime | No P2-owned outputs verified |
| **P3** | M2 popularity: Poisson and truncated NB | No P3-owned outputs verified |
| **P4** | M1b covariates + designer random effects | No P4-owned outputs verified |
| **P5** | M1a baseline, external-SD extension, PPC, prior/SD sensitivity, model comparison | **Code, results and both models' parameter/latent posterior RDS uploaded** |
| **P6** | BGG benchmark, ranking uncertainty, slides/report integration | No P6-owned outputs verified; P5 draw handoff is available |

## Model naming

| Model | Summary | Owner |
| --- | --- | --- |
| **M0** | Bayesian regression on average rating | P2 |
| **M1a Baseline** | Intercept-only Normal hierarchical shrinkage; constant between-game spread and shared unknown rating SD | P5 |
| **M1a Extended — External SD** | Per-game historical SD plug-in; rating mean and latent spread vary with log number of ratings | P5 |
| **M1b** | Hierarchical shrinkage with covariates, log rating count, designer effects | P4 |
| **M2** | Number of ratings, Poisson vs truncated negative binomial | P3 |

External-SD M1a changes **more than one modeling assumption**. A-vs-Extended predictive differences cannot be attributed to external SD alone. Rank uncertainty computed from the 6,416 matched games is **within-sample**, not global BGG ranking uncertainty.

## Next checkpoints

| Date | Planned handoff |
| --- | --- |
| **23–24 Nov** | M1b code and timing decision; M2 truncation check; P5 draws ready for P6 |
| **26–27 Nov** | Preliminary M0/M1b/M2, EDA/PPC and first BGG/ranking outputs (as available) |
| **28 Nov** | Presentation-result freeze: reproducible numbers, figures, limitations and slide material from every owner |
| **29–30 Nov** | Slides compiled and verified; team rehearsal |
| **1 Dec** | Progress presentation |
| **6 Dec** | Further diagnostics, CAVI, matched WAIC, M1b sensitivity and full ranking work |
| **10–16 Dec** | English sections, assembled draft, corrections and final review |
| **18 Dec** | PDF report (≤20 pages excluding appendix), code and data submission |

## Working rules and limitations

- Keep *training* and *holdout* distinct. Report models' game-ID sets, priors, seeds, diagnostics, and which results have actually been fitted and verified.
- Current P1 features were standardized and high-frequency categories selected **before** splitting on the full merged dataset. For strict leakage-free assessment, preprocessing rules should be fit on training data; report this limitation rather than silently changing existing samples.
- P4 must distinguish existing versus unseen designers in out-of-sample prediction; the game-level split can include shared designers.
- External per-game SD is from an historical BGG snapshot with **unverified collection date** and is treated as a fixed plug-in value.
- Each member should understand, run, check and explain the model code and author their own English report contribution, consistent with course integrity requirements.

**Plan reconciliation:** The implemented game-level P1 development/holdout split differs from the designer-group development and nested WAIC comparison samples in the plan dated 20 Nov. This README documents *what is currently implemented*; it does **not** silently amend the original proposal or eliminate the need for the team to explain the selected design.
