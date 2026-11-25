# P2 — M0 baseline regression & Bayesian computation

P2 的 M0 全部代码：JAGS + 手写 Gibbs + mean-field CAVI，以及三方法结果对比和运行时间对照。
正式拟合使用 `dev_subsample.csv` 全部 6,489 款 development 游戏（协变量缺失均值插补，不删行）。
数据文件在仓库根目录；脚本会自动在仓库根、`data/` 目录查找，找不到则自动从本仓库下载，无需手动改路径。

## 依赖（在你自己的 R 上装）

```r
install.packages(c("coda", "rjags"))   # rjags 还需系统装 JAGS 运行时
```

- Windows 装 JAGS：下载 JAGS-4.x.exe 安装，然后 `install.packages("rjags")`。
- 只要验证 Gibbs 逻辑，`coda` 一个包就够，JAGS 可以晚点装。

## 文件

| 文件 | 作用 |
| --- | --- |
| `M0_functions.R` | 核心：`fit_m0_gibbs`、`fit_m0_jags`、诊断、pointwise loglik、对比表 |
| `M0_prepare.R` | 真实数据的防御性清洗（缺失均值插补、cap、log变换、标准化） |
| `M0_run.R` | 主入口，两种模式 selftest / real，顶部改 `MODE` 切换 |
| `M0_selftest.R` | Gibbs 的一键自测（单文件、零依赖） |
| `M0_cavi.R` | CAVI 拟合函数 `fit_m0_cavi` + 三方法对比表 `m0_three_method_compare` |
| `M0_cavi_selftest.R` | CAVI 正确性自测：ELBO 单调、均值贴近 Gibbs |
| `M0_cavi_run.R` | 正式入口：CAVI + Gibbs + JAGS 同数据计时、结果对比、ELBO/区间图 |
| `P2_M1b_timing.R` | P2 独立 M1b JAGS 计时探针（单链，不需 `posterior` 包） |
| `P4_M1b_prepare_local.R` / `P4_M1b_baseline_local.bug` | P4 原始模型与预处理的本地副本（未改动，仅供计时脚本调用） |
| `README.md` | 本文件 |

## 周末操作清单

### 第一步：今晚自测（不用等任何人）

1. 把 R 的工作目录设到脚本所在目录（GitHub 上是 `code/P2/`；脚本会自动定位，一般无需手动 setwd）。
2. 打开 `M0_run.R`，顶部确认 `MODE <- "selftest"`。
3. 整段运行（Ctrl+A → Ctrl+Enter）。

你会看到：模拟数据的真值 β=(6.4, 0.5, −0.3)、σ²=0.81，
Gibbs 后验均值应该很接近它们，且真值都落在 95% 区间内。
**如果看到 “All true values inside 95% intervals”，说明手写采样器的公式是对的**——
这是最容易写错的地方，过了这关周末就稳了。

> 自测里若装了 rjags，会额外跑 JAGS 并打印一张 JAGS vs Gibbs 对比表，两者应几乎一致。

### 第二步：切真实数据（正式训练集）

数据为仓库根目录的 `dev_subsample.csv`（6,489 款 development 游戏；`comparison_sample.csv` 是 holdout，不用于拟合）。
脚本自动定位该文件（仓库根 / `data/` / 自动下载），无需手动改 `DATA_PATH`。
`M0_prepare.R` 按 Proposal 规则清洗并对协变量缺失做均值插补，保留全部 6,489 行。

1. `M0_run.R` 顶部确认 `MODE <- "real"`（`DATA_PATH` 已指向 dev_subsample.csv）。
2. 运行。控制台应显示 `n = 6489`、`Saved 6489 training game IDs`。
3. 产物自动落到 `outputs/`、`figures/`、`tables/`：

| 产物 | 用途 |
| --- | --- |
| `outputs/M0_gibbs_draws.rds` | 你的后验样本；给 P1 做 PPC |
| `outputs/M0_loglik_gibbs.rds` | pointwise log-likelihood；给 P5 算 WAIC |
| `outputs/M0_jags_draws.rds` | JAGS 后验样本 |
| `outputs/M0_method_comparison.csv` | JAGS vs Gibbs 对比表（11/28 交付物） |
| `figures/M0_trace_gibbs.png` | 收敛 trace 图（300 dpi） |

## CAVI + 三方法对比 + 运行时间（已完成）

运行 `M0_cavi_run.R`（约 75 秒）：在同一份 6,489 款 development 数据上拟合 CAVI、手写 Gibbs、JAGS，
计时并对比后验。CAVI 与 Gibbs/JAGS 用**完全相同的先验**（V0=100·I，a0=b0=0.01）；
均值场假设下 q(β)=N(m,S)、q(τ)=Gamma(a,b)，a 固定为 a0+(n+p)/2，只迭代 rate b 到 ELBO 收敛。

结果（6,489 游戏，seed 42）：

- **后验均值**：CAVI 与 Gibbs/JAGS 的全部 8 个参数差异 < 0.0003，三方一致。
- **95% 区间宽度比**（CAVI/Gibbs）：0.979–1.006，接近 1。Proposal 说"CAVI 低估后验方差"
  是一般预期；本数据 n 大、后验近正态，实测差异可忽略，**按实测报告，不要笼统照抄那句**。
- **运行时间**：CAVI 0.04s、手写 Gibbs 3.89s、JAGS 70.64s（同机同设置）。
  CAVI 约比 Gibbs 快 100 倍、比 JAGS 快约 1,700 倍。

M1b 运行时间（proposal 原定 24 Nov 的 P2 任务）：

- `P2_M1b_timing.R` 用 P4 的模型和预处理做**P2 独立探针**：单链 1000 次采样 52.03s，
  即约 **52 秒/1000 次迭代**（本机 R 4.5.1 / JAGS 4.3.2）。仅计时，不声称收敛、不交后验。
- 对照 P4 上传的证据：4 链并行的 pilot 68.48s（500 draws/链）、完整 baseline 1276.75s（4000 draws/链）。
- ⚠️ 口径不同：P2 是单链、P4 是 4 链并行；`tables/M0_M1b_runtime_comparison.csv` 有 `chains` 列，
  报告时务必标明链数，不要直接横比 `seconds_per_1000_kept_draws`。

产物（新文件，不覆盖已验证的 M0 交付）：

| 文件 | 用途 |
| --- | --- |
| `outputs/M0_cavi_fit.rds` | CAVI 完整结果（含 ELBO 轨迹、收敛标志） |
| `outputs/M0_cavi_session_info.txt` | 运行环境与设置 |
| `figures/M0_cavi_elbo.png` | ELBO 收敛曲线（300 dpi） |
| `figures/M0_three_method_intervals.png` | 三方法 95% 区间宽度对比（300 dpi） |
| `tables/M0_three_method_comparison.csv` | 三方法后验均值/SD/95% 区间对比 |
| `tables/M0_M1b_runtime_comparison.csv` | M0 三方法 + M1b 运行时间对照 |
| `tables/M1b_P2_timing_probe.csv` | P2 独立 M1b 计时探针 |

## 关键约束（Proposal 明确要求）

- 4 条链，seed 42，记录 burn-in / thinning；R-hat ≤ 1.01、ESS ≥ 400 才报结果，不达标如实说明。
- M0/M1a/M1b 的 WAIC 已在 6,489 同一批 ID 上完成（见 `outputs/P5/WAIC_Comparison_6489/`，
  M0 Gibbs vs JAGS 的 WAIC 仅差 0.020）；三方 predictive target 不同，报告须注明。
- CAVI 与 MCMC 的差异如实报告，按实测数字，不预设立场。

## 注意

- 以上结果已在本机 R 4.5.1 实跑验证（日志 `outputs/M0_cavi_run.log`、`outputs/M1b_P2_timing.log`）。
- 按课程 AI 规则：提交前请自己读懂并跑通 `M0_cavi.R` 的变分更新与 ELBO 公式，确保能讲清楚每一步。
