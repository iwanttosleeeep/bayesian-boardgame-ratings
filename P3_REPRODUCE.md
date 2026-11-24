# P3 复现说明

## 当前交付范围

交付包含数据准备、主模型、后验分析、先验敏感性、报告生成及运行入口。`data_clean.csv` 是 P1 的输入文件，不重复放入 P3 文件包。运行前需将 P3 文件放回完整仓库，或手动把 P1 的 `data_clean.csv` 放在仓库根目录。

保存的主模型后验、敏感性后验、PPC 模拟数据、表格和图片均已包含。无需重新抽样即可查看数值结果。英文报告和演示稿作为单独文档交付，不放入 GitHub；`05_write_report.R` 可根据结果表在本地生成 `report/sections/P3_M2_popularity.md` 和 `slides/P3/P3_presentation.md`。这两个路径是本地生成输出，不是缺失的已提交文件。

两个全量 `M2_*_pointwise_loglik.rds` 缓存各约 427–430 MiB，只保留在本地，不进入 GitHub。它们不是原始数据或独立后验，运行 `03_analyze_M2.R` 时会根据已包含的正式后验重新计算，因此不影响从头复现，但首次计算会耗时并需要较多内存。

## 环境与依赖

使用 R，以及 `coda`、`rjags` 两个 R 包。JAGS 只在运行 JAGS 版本时需要；已保存结果重建、实际 MCMC 来源脚本和敏感性脚本不需要安装 JAGS。

R 会话信息记录在 `outputs/P3/P3_session_info.txt`，所需扩展包为 `coda` 和 `rjags`。并行使用 R 自带的 `parallel`，默认四条链。抽样脚本使用固定随机种子，但不同 R、BLAS、操作系统或并行环境可能产生小幅数值差异，不承诺跨平台逐位一致。

## 安全重建

在完整仓库根目录运行：

```sh
Rscript code/P3/run_all.R . saved
```

`saved` 是默认模式，不会重新拟合模型。它根据现有后验重建表格和图片，并生成英文报告和展示稿。大型逐点似然与 PPC 文件可能被覆盖，运行前需要保存其他版本时应先备份。

## 从头运行

```sh
Rscript code/P3/01_prepare_data.R .
Rscript code/P3/02b_fit_M2_source.R . poisson 2000 6000 6 4
Rscript code/P3/02b_fit_M2_source.R . negbin 2000 6000 6 4
Rscript code/P3/03_analyze_M2.R .
Rscript code/P3/05_write_report.R .
```

`02b_fit_M2_source.R` 是按当时运行记录恢复的来源级预条件 MALA 实现，与当前主后验使用同一模型、先验、截断和链条设置。脚本包含有限差分梯度检查。完整重跑会覆盖 `M2_Poisson_posterior.rds`、`M2_NB_posterior.rds` 及下游结果，请先备份。当前正式数值继续来自已保存后验，没有用短链测试或另一套 JAGS 结果替换。

也可使用同一模型的 JAGS 实现：

```sh
Rscript code/P3/02_fit_M2.R . poisson
Rscript code/P3/02_fit_M2.R . negbin
```

这是独立的同模型实现，并不声称生成当前主后验中的同一组随机抽样。若选择 JAGS 结果，应统一重跑两种模型及其下游分析，再替换报告。全量截断 JAGS 在本机耗时较长。

敏感性分析单独运行，不计入主模型的内部 WAIC/DIC 比较：

```sh
Rscript code/P3/04_prior_sensitivity.R .
```

它同时改变回归系数先验和 NB 离散参数先验，因此是联合替代先验比较。该脚本也会覆盖现有敏感性输出。

## 运行入口

`run_all.R` 的第二个参数决定运行范围：

| 参数 | 行为 |
|---|---|
| `saved` | 使用保存的主后验重建分析、报告与展示稿，不重新抽样 |
| `jags` | 重跑两个 JAGS 主模型，再重建下游结果 |
| `source` | 用实际 MCMC 来源脚本重跑两个主模型，再重建下游结果 |
| `sensitivity` | 重跑替代先验敏感性，再重建主模型分析和报告 |

除 `saved` 外，其他模式可能耗时较长并覆盖已有结果。

## 配对 WAIC 标准误

`03_analyze_M2.R` 对每个模型先计算逐点 `elpd_waic_i = lppd_i - Var_draw(loglik_i)`，再计算 `difference_i = elpd_waic_NB_i - elpd_waic_Poisson_i`。`M2_WAIC_difference.csv` 中 `se_delta_waic = 2 * sqrt(N * var(difference_i))`，并校验 `delta_waic = -2 * sum(difference_i)` 与 WAIC 汇总表一致。

## 结果边界

当前结果来自全量清洗数据，属于 M2 内部比较，不是独立 holdout 验证。两个模型的 WAIC 和 DIC 使用全部 4,000 个已保存后验抽样，每链 1,000 个。PPC 使用 50 组复制数据，极端 NB 长尾的预测仍可能有较大随机波动。

主结论仅为 NB 相对 Poisson 更受支持，以及若干特征与评分人数之间的条件关联。NB 的中位数、低评分区间和部分比例仍有失配，不能解释为因果或泛化到所有桌游。M2 的 WAIC 不与 M0/M1a/M1b 评分模型的 WAIC 直接比较。
