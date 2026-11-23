# P4 三个节点交付清单与复现说明

核验日期：2026-11-23（Asia/Shanghai）。下列日期是团队计划节点，不是伪造的运行日期；11/24、11/26 的交付条件已提前完成。
本次仅整理既有有效结果及上传：不新增模型、PPT、讲稿、跨模型 WAIC 或 holdout 调参。

## 节点清单

| 计划节点 | 完成状态 | 交付与证据 |
|---|---|---|
| 11月23日：模型代码及后验评分函数 | 已完成 | [JAGS 模型](../code/P4/M1b_baseline.bug)、[预处理和条件后验](../code/P4/M1b_prepare.R)、[四链拟合与评分抽样](../code/P4/M1b_inference.R)、[可移植复现入口](../code/P4/M1b_reproduce.R) |
| 11月24日：据运行测试确定规模 | 已完成，最终规模为 6,489 款 development 游戏 | [规模信息](../outputs/P4/resources/development_information.csv)、[重复设计师信息](../outputs/P4/resources/repeat_information_summary.csv)、[资源评估](../outputs/P4/resources/resource_projection.csv)、实际全量运行见下表 |
| 11月26日：初步拟合及诊断 | 已完成 | [结果报告](../outputs/P4/README.md)、[最终核验](../outputs/P4/resources/final_verification.csv)、两套模型各自的 IDs、映射、配置、诊断、评分及 PPC 摘要 |

## 代码接口：输入、输出和调用

所有 R 命令从仓库根目录执行；相对路径以该目录为基准。

| 文件/函数 | 输入 | 输出或作用 |
|---|---|---|
| `M1b_baseline.bug` | `N,P,J,y,n,X,known,designer,beta_prec` | constant τ 的边际 Normal 模型；具名设计师随机截距；未署名/缺失设计师独立效应积分到方差；基线 `s~U(0.5,3)` |
| `M1b_prepare.R::m1b_prepare(dat, recipe=NULL)` | development 数据框；预测时可传训练 recipe | `data`（JAGS 数据）、`recipe`（中位数、中心、尺度、保留列、设计师映射）、`ids`；每次训练重新估计 recipe |
| `M1b_prepare.R::m1b_latent(y,n,mu,tau,s,sigma_d,known)` | 同一参数抽样下的观测、均值、方差参数和设计师状态 | 条件后验 `mean,sd,weight`；`theta ~ N(mean,sd^2)`。具名设计师的 `mu` 必须包含该次抽样的 `u[d]` |
| `M1b_inference.R::m1b_fit(prep,dat,out,...)` | 预处理结果、训练行、新输出目录和四链配置 | 每链 `chain_k.rds`（参数抽样、chain、seed、retained、JAGS RNG/state）、诊断、进度、模型及元数据；已有运行拒绝覆盖 |
| `M1b_inference.R::m1b_latent_output(prep,out,B=1000)` | 相同 prep、已拟合的四链文件 | `latent_ratings.csv`、`latent_draws.rds`、`pointwise_loglik.rds`、`development_PPC.csv`；参数抽样索引保留 chain/iteration，跨游戏共享同一参数抽样 |
| `M1b_reproduce.R baseline\|sensitivity NEW_DIR` | 根目录 `dev_subsample.csv`，新的空输出目录 | 完整 development 训练和评分导出；敏感性只将 s 上界放宽为 6 |

条件评分示例（仅函数计算，不拟合）：

```r
source("code/P4/M1b_prepare.R")
moments <- m1b_latent(y=7, n=30, mu=6.4, tau=.42, s=3,
                      sigma_d=.44, known=1)
set.seed(42)
theta_draws <- rnorm(1000, moments$mean, moments$sd)
```

评分 CSV 的 `mean` 为选取参数抽样上条件均值的平均；区间来自条件 theta 抽样。抽样评分、点估计和原始 `average` 不是同一量。
log-likelihood 积分了游戏 theta，但对具名设计师效应条件化；保存它不等于已开展跨模型 WAIC。

## 最终规模、配置和资源

只训练 `dev_subsample.csv` 全部 6,489 行，不删除协变量缺失行；训练中位数填补加缺失标记，56 个预测列；3,221 位具名设计师，623 款缺失/未署名游戏。
`comparison_sample.csv` 为 holdout，本次没有读取其结果进行调参或评分。

两次均为 4 个独立 R 工作进程，JAGS `glm::Generic`，每链 2,000 adaptation + 2,000 burn-in，按 2,000 次/批保留；实际各保留 4,000 次，无 thinning。最低 4,000、上限 12,000，由全参数诊断决定是否延长。

| 运行 | 链种子 | 实际拟合及分批诊断 | 峰值合计工作集 | 保守的单进程峰值之和 | 最大 R-hat | 最小 bulk/tail ESS |
|---|---|---:|---:|---:|---:|---:|
| baseline_development | 610801–610804 | 1276.75秒（21.3分钟） | 3248 MiB | 4148 MiB | 1.0012 | 1457 / 2470 |
| sensitivity_s_upper6 | 610901–610904 | 1300.93秒（21.7分钟） | 3243 MiB | 4152 MiB | 1.0054 | 1377 / 3006 |

时间包含编译、预热、抽样和分批诊断，评分导出另计。工作集每两秒采样；各进程峰值之和不代表同时峰值。测试机 32 GB RAM、22 逻辑处理器；其他机器需自行评估，不能保证相同耗时或逐位相同抽样。
诊断标准：rank-normalized/folded split R-hat≤1.01，bulk/tail ESS≥400，MCSE(mean)/SD≤0.05；两套全部通过。具体值见各自 `diagnostics.csv`、`progress.csv` 和 `status.txt`。

## 环境与复现（不依赖本机 .local）

已验证组合：R 4.5.3（64-bit）、JAGS 4.3.2、rjags 4-18、coda 0.19-4.1、posterior 1.8.0。JAGS 的 glm 模块必须可加载；使用兼容的 JAGS/rjags 主版本配对。优先使用这个已验证组合。不同版本产生的结果属于新运行，需要重新核验。
R 自带 `parallel`，不需要额外集群服务。先安装 JAGS，再在自己的 R 库安装兼容的 rjags、coda、posterior；不要在缺少匹配 JAGS 的情况下盲目安装最新 rjags。

Windows PowerShell 示例（路径替换成自己的；包已安装时无需重复安装）：

```powershell
$env:P4_RSCRIPT = 'C:/Program Files/R/R-4.5.3/bin/x64/Rscript.exe'
$env:JAGS_HOME = 'C:/Program Files/JAGS/JAGS-4.3.2'
# 如使用自定义 R 包库，可设置 R_LIBS_USER；否则使用 R 的正常包库。
& $env:P4_RSCRIPT --vanilla -e "library(rjags);library(coda);library(posterior);load.module('glm');print(jags.version())"
& $env:P4_RSCRIPT --vanilla code/P4/M1b_checks.R
# 以下是需要重新生成大型后验时的命令；本次交付核验没有执行这两个拟合。
& $env:P4_RSCRIPT --vanilla code/P4/M1b_reproduce.R baseline p4_reproduced/baseline
& $env:P4_RSCRIPT --vanilla code/P4/M1b_reproduce.R sensitivity p4_reproduced/sensitivity
```

Linux/macOS 在安装好的系统 JAGS/R 环境中，从根目录执行同样的 `Rscript --vanilla code/P4/M1b_reproduce.R ...` 命令。
此跨平台入口不做 Windows 内存监控；使用系统工具监测资源。Windows 历史入口 `run_analysis.ps1` 支持 `P4_RSCRIPT`、`JAGS_HOME`、`R_LIBS_USER`，没有设置时才尝试本机 `.local` 后备。不要重跑它去覆盖已发布摘要；新的空目录入口更适合组员。
相同 JAGS 文件和拟合/评分函数仍是唯一模型实现，新增入口只是将输出目录参数化。

## GitHub 上传与本机文件的界限

上传：`code/P4/`、本交付说明及 P4 baseline/诊断文档、`outputs/P4/` 中的结果报告、模型文本、诊断/评分/PPC CSV、训练 IDs、设计师映射、链配置、数值预处理 CSV、运行资源和模拟检查摘要、已有诊断 PNG；以及必要 `.gitignore`。
每个正式模型目录新增 `numeric_preprocessing.csv`、`numeric_missing_indicators.csv`、`retained_columns.csv`、`chain_configuration.csv`，由已有 RDS 读取导出，没有重新抽样。

**仅本机保存，不随 Git 上传：** 所有 `*.rds`（包括 `inputs.rds`、`preprocessing.rds`、`run_settings.rds`、四个 `chain_*.rds`、`latent_draws.rds`、`pointwise_loglik.rds`，以及模拟/原试跑 RDS）、原始代码快照、主机绝对路径哈希清单、逐进程日志、`.local` 内运行时/安装包/包库。文档中这些名称均为本机产物说明，不是承诺 GitHub 中存在的下载链接。
缺少这些 RDS 时，查看已上传 CSV/PNG 不需要重跑；若需要完整后验，则使用上述新目录命令重新生成。不能只从 CSV 重建完整联合后验。

本机审计工具 `finish_analysis.ps1` 需要本机两套 RDS、原始 smoke RDS 和完整性哈希清单；它不是干净克隆后的第一条命令，也不应为了上传重复启动。原运行的核验结果已经上传到 `resources/final_verification.csv` 和 `smoke_integrity.txt`。
`M1b_compare.R`、`M1b_final_checks.R`、`M1b_write_report.R` 默认读取历史 `outputs/P4/` 目录；对新目录结果进行比较时，需在独立副本中调整这些后处理脚本的输入/输出路径，不能覆盖仓库证据。

## 保留的科学限制

- 两组完整结构模拟中，潜在评分 95% 区间覆盖仅约 84–88%，oracle 条件计算接近95%；MCMC 收敛不保证校准。重复设计师共享效应、匿名游戏独立效应及高斯条件计算的独立检查已通过。
- development PPC 仍有低评分人数均值和高评分人数方差偏差；不是 holdout 验证。
- s 后验均值从 2.981 变为4.026，绝对评分调整中位数从0.0555增至0.0989；数值收缩依赖上界。26个 baseline 区间不跨0的系数方向保持，但不代表所有估计都不变。
- τ 一直为常数；baseline 原先验未替换。敏感性不是新的 baseline，也没有据此选择新模型。
- P1 固定标签选择仍有全量数据预处理局限；正式跨模型比较样本另行协调。

## 本次核验与 Git 状态

本机路径为 `C:/Users/Lenovo/Documents/Codex/bayesian-boardgame-ratings`，分支为 `p4/m1b`。核验开始时无新的提交，P4 文件为未跟踪工作；未发现活动中的验证/拟合进程，故没有重启 `finish_analysis.ps1`。
提交前执行语法、函数/协方差检查、现有后验读取核验、链接/上传范围检查；核验记录见 `outputs/P4/resources/delivery_validation.txt`。提交与推送结果以 Git 历史及本次聊天最终报告为准。
