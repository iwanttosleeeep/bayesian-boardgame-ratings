# P3 交接说明

## 数据与模型

P3 只使用 P1 的 `data_clean.csv`，共 21,631 行。删除协变量缺失的 2,191 行后，Poisson 和负二项模型共同使用 19,440 个游戏。这里直接在全表上拟合，没有把 `dev_subsample.csv` 或 `comparison_sample.csv` 当作单独的训练或测试文件。因此当前 WAIC/DIC 是全样本上的 M2 内部比较，不是独立 holdout 验证。

两个模型都以 `users_rated` 为结果，并处理至少 30 个评分造成的左截断。自变量包括游戏时长、人数、建议年龄、20 个类别、20 个机制、多设计师和游戏年龄。

## 主要结果

- WAIC 使用全部 4,000 个后验抽样：Poisson 为 50,805,323，负二项为 266,545，因此选择负二项模型。与此前 400 次抽样的结果相比，模型排序和结论不变。
- 按 Chapter 10 公式计算的 DIC：Poisson 为 49,711,402，负二项为 266,340。NB 的 pD 为 -25.1，因此 DIC 只作补充，WAIC 仍为主要依据。
- 游戏年龄：RR 1.53，95% CrI [1.46, 1.59]。
- 游戏时长：RR 1.17，95% CrI [1.11, 1.23]。
- 多设计师：RR 1.26，95% CrI [1.17, 1.36]。
- 最大 R-hat 为 1.004，最小 ESS 为 2,369。
- 负二项模型优于 Poisson，但仍低估 30–39 个评分的游戏比例；预测中位数约为 195，而观测中位数为 140，至少 1,000 个评分的比例也预测偏高。因此只能说相对更好，不能说已经拟合良好。
- 替代先验敏感性分析中，主要特征效应比几乎不变；NB 离散参数中位数由 0.000681 降为 0.000469，因此长尾程度仍需谨慎解释。替代先验拟合最大 R-hat 为 1.014，最小 ESS 为 467。回归系数先验和离散参数先验是一起改变的，不能把变化单独归因于其中一个。

以上都是条件关联，不是因果效应。结论只适用于至少有 30 个评分的 BGG 上榜游戏。

## 与群内样本讨论的衔接

- M0/M1a/M1b 需要统一训练 ID，是这些评分模型之间的比较要求；M2 只做 Poisson 与 NB 的内部比较，不把两类模型的 WAIC 混在一起。
- M1a 的外部 SD 扩展和每款游戏不同的 pseudo-votes 不影响 M2；M1a 的 PPC 也不能替代 M2 的评分人数 PPC。
- 当前全量 M2 拟合包含 `comparison_sample.csv` 中的 2,919 个游戏，所以不能作为 holdout 成绩。若之后要做 holdout，必须先排除这些游戏再重新拟合。

## 文件与复现

- 代码：`code/P3`
- 主后验实际来源：`02b_fit_M2_source.R`，与当前主结果保持相同模型、先验和 MCMC 设置
- 同模型 JAGS 实现：`02_fit_M2.R`，作为独立实现，不声称产生相同随机抽样
- 先验敏感性：`04_prior_sensitivity.R`
- 报告与展示稿生成：`05_write_report.R`
- 复现说明：[复现说明](P3_REPRODUCE.md)
- 英文报告：`report/sections/P3_M2_popularity.md`，由 `05_write_report.R` 本地生成，单独交付，不随 PR 提交
- 两页展示稿：`slides/P3/P3_presentation.md`，由 `05_write_report.R` 本地生成，单独交付，不随 PR 提交
- 表格：`tables/P3`，其中 `M2_DIC.csv` 为讲义版 DIC，`M2_prior_sensitivity.csv` 为先验对照，`M2_WAIC_stability.csv` 为 400 与 4,000 次抽样的 WAIC 对照
- 图片：`figures/P3`
- 后验与建模数据：`outputs/P3`；两个全量 pointwise log-likelihood 缓存各约 427–430 MiB，只保留本地，不上传 GitHub，可由 `03_analyze_M2.R` 根据正式后验重算

默认安全重建命令为 `Rscript code/P3/run_all.R . saved`，不会重新拟合主模型。`M2_WAIC_difference.csv` 使用两个模型逐点 `elpd_waic_i = lppd_i - Var_draw(loglik_i)` 的差计算配对标准误 `2 * sqrt(N * var(diff))`。从头运行、覆盖范围、环境依赖和大文件处理见 [复现说明](P3_REPRODUCE.md)。`data_clean.csv` 属于 P1，需保留在共享项目根目录。
