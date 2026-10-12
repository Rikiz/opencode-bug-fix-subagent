# 基于问题单（issue）修复代码仓：业内方法论全景

> 版本：2026-10-08
> 覆盖范围：从 issue 描述出发定位、修复并验证一个 bug 的**完整方法论链**，共六层。
> 配套：`research/` 26 份离线原文（逐份 `file(1)` + sha256 + 首页标题校验）、`claims-table.md` 54 条已核实论断。

---

## 0. 证据边界声明（先读这一节）

本文所有陈述按四类标注，**不同类别的可信度不同，不可混用**：

| 类别 | 定义 | 在本文中的用法 |
|---|---|---|
| **观测事实** | 一手原文（已落盘 PDF / 已打开权威页面）中明确记录的表述或数字，可在给定页/节/表逐字复核 | 可直接作为设计依据 |
| **结构推论** | 由观测事实与架构定义必然推出 | 可严谨推导，但可能因前提未变而失效 |
| **设计判断** | 基于工程原则的选择，含权衡 | 必须说明取舍，不伪装成研究结论 |
| **待验证假设** | 有可能但无证据 | 只能列为待验证，不得进入验收标准 |

**三条硬纪律：**

1. **研究结论 ≠ 本系统故障的证据。** 本文所有量化数字来自他人系统上的公开评测；它们是**先验与基线**，不是对本仓库的证明。
2. **未核实的不进正文结论。** 凡未能打开权威页面确认的条目（含 arXiv ID、作者、数字），一律进入 `claims-table.md` 的「未核实」区（U01–U09）与 `research/README.md` 的「未获取清单」。
3. **本次调研发现并剔除了一处错误引用。** 调研提纲中的「Clark & Zarembka 的 ACM TOCS debugging survey」经两轮检索 + DBLP TOCS 卷 11 全目录逐条核对后**确认不存在**，已剔除（见 U01 与 `debug-theory-and-fault-localization.md` §1.1）。另有一份继承自既有 research 目录的 PDF（`agentasseval-tracing-framework.pdf`）经首页校验为**凝聚态物理论文**，已删除（见 `research/README.md` §5）。

---

## 1. 六层次全景

```
                    ┌──────────────────────────────────────────────┐
                    │  层次 6  Agent 工程方法论                     │
                    │  何时值得多 agent / 失败归因 / 评测可信度      │
                    └────────────────────┬─────────────────────────┘
                                         │ 提供控制面与评测纪律
┌────────────────────────────────────────┼─────────────────────────────┐
│ 层次 1  调试理论与过程                                                    │
│ 复现优先 / delta debugging 二分隔离 / 单-多故障判定 / flaky 噪声地板       │
└────────────────────────┬────────────────────────────────────────────────┘
                         │ 提供「怎么找」
┌────────────────────────┼────────────────────────────────────────────────┐
│ 层次 2  故障定位 (FL)                                                    │
│ SBFL / Slicing / Stack-trace / MBFL / IR / Execution-feature            │
│ 关键量化：Top-1 4–5%（语句粒度）→ 26%（方法粒度）；Top-10 仅 44%          │
└────────────────────────┬────────────────────────────────────────────────┘
                         │ 提供「改哪里」
┌────────────────────────┼────────────────────────────────────────────────┐
│ 层次 3  自动程序修复 (APR)                                                │
│ 搜索式 / 历史模式式 / issue-report 驱动式 / LLM-based                    │
│ 关键量化：真实 issue 可修复天花板 16.7–33.5%；正确/可信 ≈ 0.5             │
│ 关键失效：patch overfitting（7.8% 假阳 / 29.6% 行为不同）                 │
└────────────────────────┬────────────────────────────────────────────────┘
                         │ 提供「凭什么说改对了」
┌────────────────────────┼────────────────────────────────────────────────┐
│ 层次 4  测试与验证纪律                                                    │
│ 差分测试(PatchDiff) / 变形测试(3–6 条 MR → 90%) / flaky(4.56%) /           │
│ 变异测试(作为压力源而非门禁)                                              │
└────────────────────────┬────────────────────────────────────────────────┘
                         │ 提供「怎么量」
┌────────────────────────┼────────────────────────────────────────────────┐
│ 层次 5  Benchmark 与评测                                                  │
│ SWE-bench 全家 / Multi-SWE-bench / SWE-Lancer / Terminal-Bench          │
│ 关键量化：跨语言 26 倍衰减；3+ 文件跌破 10%；issue 结构 OR 3.61           │
└──────────────────────────────────────────────────────────────────────────┘
```

## 2. 每层一句话定义 + 代表文献 + 可迁移性评级

### 层次 1 · 调试理论与过程

**定义：** 把「修 bug」从自由探索改造成**可复现、可二分、可证伪的科学过程**；核心资产是「一次失败 + 一个稳定判定」。

| 代表文献 | 状态 | 一句话贡献 |
|---|---|---|
| Zeller, *Yesterday, My Program Worked. Today, It Does Not. Why?* (ESEC/FSE 1999) | 一手 ✅ | delta debugging：数小时从 178,000 行变更定位单个致因 |
| de Souza et al., *Spectrum-based FL: A Survey* (arXiv:1607.04347v2) | 一手 ✅ | 调试占开发成本至多 75%，但 SFL 几乎未被企业采用 |
| Luo et al., *An Empirical Analysis of Flaky Tests* (FSE 2014) | 一手 ✅ | flaky 占测试失败 4.56%；「任一次通过即过」不可靠 |

**可迁移性：高。** 复现门禁是整个体系的地基，且与模型能力无关。

### 层次 2 · 故障定位（FL）

**定义：** 用执行期证据（通过/失败、覆盖、栈、日志、调用关系）给「哪里有 bug」**排序**，并把排序转成**可判别的实验**。

| 代表文献 | 状态 | 一句话贡献 |
|---|---|---|
| Zou et al., *An Empirical Study of FL Families* (arXiv:1803.09939v2) | 一手 ✅ | Ochiai Top-1 4% / Top-10 44%（语句粒度）；方法粒度 Top-1 26% / Top-10 68%；组合提升 Top-1 200% |
| Soremekun et al., *Locating Faults with Program Slicing* (arXiv:2101.03008v1) | 一手 ✅ | 统计调试看 1 个位置即命中 33%；混合策略只需看 15%（30 行）；单/多故障下切片与统计调试优劣反转 |
| Smytzek et al., *How Execution Features Relate to Failures* (arXiv:2502.18664v1) | 一手 ✅ | 定义-使用对/值谓词/标量关系比行覆盖更能解释失败；并警告 single-patch bias |

**可迁移性：高，但必须分阶段。** 最可操作的一条：**第一阶段的目标粒度不能是行**（Top-1 差 6 倍）。

### 层次 3 · 自动程序修复（APR）

**定义：** 在定位基础上**生成修改并通过测试验证**；四类路线（搜索 / 历史模式 / issue-report / LLM）的根本区别在于「修复知识从哪来」。

| 代表文献 | 状态 | 一句话贡献 |
|---|---|---|
| Koyuncu et al., *iFixR* (arXiv:1907.05620v1) | 一手 ✅ | 真实 bug report 只有 **16.7–33.5%** 最终被修复；iFixR opt 21 正确 / 44 可信 |
| Zhang et al., *AutoCodeRover* (arXiv:2404.05427v3) | 一手 ✅ | **18.0% 改错文件 + 6.7% 无可用 patch**；接入 SBFL 后 19%→22% |
| Xia et al., *Agentless* (arXiv:2407.01489v2) | 一手 ✅ | 无 agent 三阶段（文件→类/函数→编辑点，top-3 文件）达 31.00% / $0.65 |
| Yang et al., *SWE-smith* (arXiv:2504.21798v2) | 一手 ✅ | 合成数据难度与下游表现**无强相关**（12.4/10.8/13.6/12.2%） |
| GenProg / SPR / RepairLMS / PAR / SimFix / FixMiner | 二级 ⚠️ | 仅作脉络，未独立核实（U08） |

**可迁移性：分层三阶段高；搜索式在多仓场景下低（依赖单文件、模板假设）。**

### 层次 4 · 测试与验证纪律

**定义：** 回答「凭什么说这个 patch 是对的」——而**测试全绿只是 L1 级证据**。

| 代表文献 | 状态 | 一句话贡献 |
|---|---|---|
| Wang, Pradel & Liu, *Are "Solved Issues" in SWE-bench Really Solved Correctly?* (arXiv:2503.15223v2) | 一手 ✅ | **7.8%** 判对的 patch 过不了开发者测试；**29.6%** 可信 patch 行为与真实不同；**PatchDiff** 差分验证不需 ground truth |
| Chen et al., *Metamorphic Testing* (ACM CSUR 51(1):4, 2018) | 一手 ✅ | 每程序 **3–6 条** diverse MR 达 oracle 的 **90%**；MT 恒优于无 oracle 的 RT |
| Luo et al. (FSE 2014) | 一手 ✅ | flaky 4.56%；async wait 可**仅改时间延迟**改变失败结果 |
| Papadakis et al., *Mutation Testing Advances* (Adv. Comput. 112, 2019) | 一手 ✅ | 变异分数与故障检出率的**个体相关性常常很弱** → 只能当压力源 |

**可迁移性：高，且成本低。** 差分 + 变形是**唯一能在无现成测试时规模化合成 oracle 的手段**（而真实 issue 只有 5.5% 带 test case）。

### 层次 5 · Benchmark 与评测

**定义：** 用**真实 issue + 真实 patch + 机器判据**构造可复现的能力测量，并明确其**已测与未测的轴**。

| Benchmark | 规模 | 状态 |
|---|---|---|
| SWE-bench (arXiv:2310.06770v3) | 2,294 / 12 仓 / Python | 一手 ✅（发布时 Claude 2 仅 1.96%） |
| SWE-bench Multimodal (arXiv:2410.03859v1) | 619 / 17 仓 / JS | 一手 ✅（83.5% 实例图像必需） |
| SWE-PolyBench (arXiv:2504.08703v3) | 多语言 | 一手 ✅（**3+ 文件跌破 10%**） |
| Multi-SWE-bench (arXiv:2504.02605v1) | 1,632 / 7 语言 | 一手 ✅（**跨语言 26 倍衰减**） |
| SWE-Lancer (arXiv:2502.12115v4) | 1,400+ / $1M / Upwork | 一手 ✅（88% 是 bug fix） |
| Terminal-Bench (arXiv:2601.11868v1) | 89 终端任务 | 一手 ✅（前沿模型 <65%；人工难度仅 r=0.436） |
| SWE-bench Verified / Pro / Live | — | **未核实**（U09） |

**可迁移性：中（方法论高，数字低）。** 结论：**单语言 benchmark 分数不可外推**；成功率必须分难度/分 issue 类型/分语言报告。

### 层次 6 · Agent 工程方法论

**定义：** 关于「怎么把上面五层装进一个 agent 系统」的经验与证据。

| 来源 | 状态 | 一句话贡献 |
|---|---|---|
| Tamoyan et al., *SHERLOC* (arXiv:2606.24820v2, EMNLP 2026) | 一手 ✅ | agent **一半预算花在编辑前的定位**；定位结论注入修复 agent → **+5.95 pp**，定位 token −36.7%；**低质量定位主动劣于基线** |
| Cemri et al., *MAST* (arXiv:2503.13657v3) | 一手 ✅ | 三类失败：specification / inter-agent misalignment / task verification failure |
| Destefanis & Aste, *When Agents Coordinate* (arXiv:2608.16801v1) | 一手 ✅ | 指定 coordinator **不形成枢纽、不提升成功率**；共享文件省约 42% 输出 token；**四分之五运行去找隐藏评分材料** |
| Nature MI, *Capable language models can outgrow the benefits of collaboration* | 单边 ⚠️ | 单 agent 能力是多 agent 收益的最强预测因子；存在饱和阈值 |
| Anthropic ×3 | 单边 ⚠️ | 环境反馈优于主观判断；loop 必须有停止条件；编码任务可并行部分更少 |
| OpenAI ×2 | **未获取** ❌ | developers.openai.com 403（U06） |

**可迁移性：分层定位与 oracle 隔离高；多 agent 拓扑默认低（需消融证明）。**

## 3. 三个层次交叉处最值得读的结论

| # | 论断 | 交叉点 | 依据 |
|---|---|---|---|
| X1 | **「定位是瓶颈」有硬证据**：约 24.7% 的失败纯粹因为改错地方；agent 一半预算花在编辑前 | 2 × 3 × 6 | C13 + C18 |
| X2 | **「测试通过 ≠ 根因确认」有硬证据**：7.8% 假阳 + 29.6% 行为不同 + 四分之五运行去找隐藏材料 | 3 × 4 × 6 | C23 + C51 |
| X3 | **问题单本身是稀缺资源**：真实 issue 只有 16.7–33.5% 最终被修复、5.5% 带可执行测试、48.3% 带复现脚本；且长度不是可靠质量代理 | 1 × 3 × 5 | C11 + C34 + C30/C31 冲突 |

## 4. 推荐阅读顺序

| 场景 | 顺序 | 理由 |
|---|---|---|
| **只有 2 小时** | ① 本文 §0–§3 → ② `claims-table.md` 的 X1–X3 → ③ `swe-bench-solved-issues-really-solved.pdf` 摘要 | 先拿到会改变设计的三条数字 |
| **要做定位阶段** | `debug-theory-and-fault-localization.md` §2.2 → 2.3 → 2.4 → `arxiv-1803.09939.pdf` Table 3/11 → `arxiv-2404.05427.pdf` §失败分析 | 粒度选择 + 多路合并 + 瓶颈证据 |
| **要做修复与验证** | `automated-program-repair.md` §1–§4 → `verification-and-evaluation.md` §1–§3 | 天花板 → 过拟合 → 差分/变形验证 |
| **要做评测** | `verification-and-evaluation.md` §3–§9 → `agentic-se-methodology.md` §4 | 分维度报告 + oracle 隔离 |
| **要决定是否上多 agent** | `agentic-se-methodology.md` §1（三方独立证据）→ §6 评级表 | 先看饱和阈值与枢纽证据 |
| **要建内部 case 集** | `verification-and-evaluation.md` §7（C36/C37/C38）+ §9 清单 | 对齐 Multi-SWE-bench 的质量标注方式 |

## 5. 与既有 `docs/multi-repo-bugfix/README.md` 的分工

**既有文档**（`docs/multi-repo-bugfix/README.md`）侧重**多 agent 拓扑与诊断闭环**：信息分层、状态机检查、信息增益、关键路径重算、瓶颈定位、单写者事件流、并发原则、消融配置（S0/S1/M1/M2）、指标定义、失败映射表、最小检查清单。

**本文**侧重 **bug 修复方法论本体**：调试理论、故障定位技术家族与量化效果、APR 四条路线与失效模式、测试与验证纪律、benchmark 量化基线、agent 工程证据。

| 主题 | 本文（bugfix-methodology） | 既有（multi-repo-bugfix） |
|---|---|---|
| 问题单的角色 | 修复**输入**：结构与长度对成功率的影响、可修复性天花板 | 触发**信号**：进入 Reproduction Gate |
| 定位 | 技术家族、量化效果、粒度选择、SBFL 接入 | 诊断闭环的**流程状态**（CodeGraph → Hypothesis Ledger → Experiment Scheduler） |
| 验证 | L1/L2/L3 证据分层、差分/变形测试、flaky 地板 | 确认门禁的三条件（复现 + 因果 + 干预） |
| 多 agent | 是否值得（三方证据） | 怎么搭（角色、协议、单写者、并发条件） |
| 评测 | benchmark 量化基线与报告维度 | 指标**定义**（root-cause precision、discriminating-evidence rate） |
| 失败分类 | 引用 MAST（C48） | 展开为工作流检查清单 |

**互链点：**
- 本文层次 2 §2.4 ←→ 既有 §3.1 诊断闭环的 Scope 阶段
- 本文层次 4 §1 ←→ 既有 §3.3 根因确认门禁（本文给出 L1 与 L2/L3 的量化分离）
- 本文层次 6 §4 ←→ 既有 §4 消融与指标（本文给出必须报告的评测污染率）
- `research/` 目录与 `docs/multi-repo-bugfix/research/` 共享层次 6 的 7 份副本（已逐份校验 sha256 一致）

**不重复承诺：** 本文不复述既有的状态机/单写者/关键路径内容；既有文档不重复本文的任何量化基线。

## 6. 待验证假设清单（本文明确标记为「尚无证据」）

| # | 假设 | 现状 |
|---|---|---|
| H1 | patch token 长度超过某阈值即导致成功率显著下降 | 只有间接证据（多文件掉点 C29 + issue 类型 C38），**无直接一手阈值数字** |
| H2 | 结构化事件协议（append-only NDJSON + schema）在多仓 bugfix 上优于自由文本报告 | 本次调研**未检索到**直接对比这两者的实证研究；仅有 `docs/multi-repo-bugfix` 的设计判断 |
| H3 | 因果推断式 FL（counterfactual / interventional）在多仓上优于 SBFL | 本层次未取得任何一手专文；SFL/切片/栈追踪/MBFL/IR 之外的方向是空白 |
| H4 | 真实 issue 描述长度与成功率的负相关（OR=0.49）在多仓非开源场景仍成立 | Khatib 2026 与 Multi-SWE-bench 结论**冲突**，需在自有数据上重测 |
| H5 | 「多 agent 并发定位」的收益 | 三方证据均指向「存疑」，但**无直接针对 bug 修复定位场景的消融研究**被检索到 |

## 7. 未获取 / 未核实清单摘要

| 类别 | 条目 |
|---|---|
| 未获取（网络受限） | Nygard《My Philosophy of Debugging》；Kochhar et al. ICSE 2006（ACM 403）；OpenAI ×2（403） |
| 未核实（检索未命中） | Clark & Zarembka TOCS debugging survey（**经 DBLP TOCS 卷 11 全目录核对后确认不存在**）；Just/Kapfhammer/Zeller「测试有效性」论断；`git bisect` 原始文献；Weinberg / Kernighan / Brooks 具体命题；SWE-bench Verified/Pro/Live |
| 仅二级引用 | GenProg、SPR、RepairLMS、PAR、SimFix、FixMiner、SketchFix、CapGen、Ochiai & Ochrimka 2004、DStar (Kim 2008)、Bavota 栈追踪/日志 FL、Qi et al. 2015、Zeh et al. 2019、Smith et al. 2015、Rothermel & Harrold 2004 |
| 已剔除的错误文件 | `agentasseval-tracing-framework.pdf`（实为凝聚态物理论文，已删除） |

完整清单与原因见 `research/README.md` §5 与 `claims-table.md` 的 U01–U09。

## 8. 后续检索建议

1. **突破 ACM/DOI 付费墙**：用 OpenAlex / Unpaywall 的绿色 OA 镜像替代 `dl.acm.org` 直连，补齐 Kochhar 2006、Ochiai & Ochrimka 2004、Bavota 系列。
2. **补齐非 arXiv 渠道**：DBLP 被 Anubis 反爬拦截、Semantic Scholar API 连续 429；建议换时间窗或用 `dblp.org` 的 `?view=bibtex` 静态导出。
3. **优先补三个方向**：(a) 因果推断式 FL；(b) 差分测试 / 属性测试的一手专文；(c) patch token 长度与成功率的直接阈值研究（H1）。
4. **补多 agent 在修复定位上的直接消融**（H5）——这是本文最大的空白，且与本项目决策直接相关。
5. **SWE-bench Verified / Pro / Live 官方页**（U09）需直接打开 OpenAI 公告与官方站确认原始数字，替代目前的二手转引。
