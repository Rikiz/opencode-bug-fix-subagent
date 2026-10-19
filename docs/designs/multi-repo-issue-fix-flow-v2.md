# 多仓问题单修复：证据增量与设计 v2（OpenCode 落地版）

> 版本：2026-10-12 v2
> 关系：本文是 [`multi-repo-issue-fix-flow.md`](./multi-repo-issue-fix-flow.md)（v1）的**增量修订**，不推翻 v1 的骨架，只补三样东西：
> 1. **新证据**：v1 定稿后新入库的 ~20 篇一手论文（`bugfix-methodology/research`，2026-10 批次），其中 4 篇直接落在多仓/多补丁/跨服务本文的空白区（v1 与 `claims-table.md` 对它们**零引用**，已核对）。
> 2. **两条新的硬结构**：`provenance-attributed patch`（归因到"引入者"而非"传播者"）与 `state-bound evidence + typed revision contract`（证据绑定代码状态、循环不等于可靠）。
> 3. **可实现的 agent/权限增量**：在 v1 §8 的 `repair/probe/contract-checker/referee` 之上，只加必要的机制，并给出 A0→B1 的消融口径。
>
> 证据标签沿用 v1 §0：【观测】【论断】【单边】【推论】【判断】。**本文所有【论断】均来自本机已落盘 PDF 的标题页/摘要逐字抽取**（抽取命令见 §9），未落盘来源一律不出现在结论里。

---

## 0. TL;DR（相对 v1 的净变化）

| # | v1 的做法 | v2 的修订 | 依据 |
|---|---|---|---|
| 1 | S1 候选仓收缩靠"症状归属 + 契约反查" | 增加**两阶段分层检索**：先仓路由、再仓内 file 定位；仓内表示用 **NL 摘要**（非裸代码向量） | ICSE 2026 多仓定位论文：46 仓 / 1.1M LOC 工业系统 Pass@10 **0.82**、MRR **0.50** |
| 2 | T4"判别实验"以 bug 是否复现/消失为主信号 | 增加 **differential execution provenance**：同一失败用例在**上游旧/新版本**下跑，比较返回值差异 → 排序根 API 候选，再用候选过滤上游 diff | BBCFixer/BBCBench：行为性依赖破坏无编译反馈；pass rate +17%、成功修复省 **27%** agent steps |
| 3 | S5 补丁把"跨仓验证矩阵"当一个合集 | 增加 **多 hunk 生产者-消费者排序**：跨仓改动是有向依赖，必须按**先生产者后消费者**生成与选择，逐 hunk 验证不可靠 | Multi2Fixer：hunk 间存在语义依赖、单 hunk 局部验证无效；Coordinator 排序 + Proposer 候选 + 两阶段精炼 |
| 4 | S6 独立验证是运行测试 + diff 审查 | 增加 **"证据绑定代码状态"门**：验证证据必须绑定到**精确代码状态/快照 hash**；不可用陈旧 trace 复用通过 | 循环≠可靠：强制修订时"当前正确率"从 0.820 掉到 0.673（ever-correct 反升至 0.847）；陈旧 trace 对正确起点有害 34/135 vs 4/135 |
| 5 | 提交门 = 单元/契约测试 | 增加 **CI 原样重执行**作为最终门（含环境/依赖/配置类失败） | CI-Repair-Bench：**567** 个真 CI 失败 / 103 仓，**只用完整 CI 重执行判对**；最好 LLM 仅 **18.9%**；环境/依赖/配置类最难 |
| 6 | 跨仓"通知 owner" | 增加 **patch-completeness 校验**（同修 + 分支 + 关联仓）：防"只修一半" | multi-SP 实证：**20.6%** 的 CVE 涉及多补丁，跨仓召回 **0.873**，且在 100 个"公开库记为单补丁"的 CVE 上**发现 28 个未报告补丁** |
| 7 | 依赖经验/记忆（AdaRepair-Mem 等） | **延期**：跨仓可迁移性未证实；先建立"同失败用例、同模型、跨仓对比"的可验证口径 | XRepoSkill：一条成功轨迹里的行为**未必**是成功原因（可能偶然/习惯）；须跨多仓复现才保留 |

一句话：**v1 的骨架（S0–S7 + 三条件确认门 + 单写者账本）保留；v2 把"多仓"特有的三件事补成硬机制——上游归因、hunk 排序、CI 级终验。**

---

## 1. 新增证据清单（全部来自本机已落盘 PDF）

> 抽取方式：`uv run --with pymupdf python3 /tmp/pdfx.py <file> --pages 1`（见 §9）。以下结论均为**摘要/首页逐字**，非二手转述。

### 1.1 多仓 / 跨仓（v1 完全未引用）

| 论文 | 落盘文件 | 关键量化结论 | 对本设计的直接影响 |
|---|---|---|---|
| *Natural Language Summarization Enables Multi-Repository Bug Localization by LLMs in Microservice Architectures*（ICSE 2026） | 目录外，本文新增下载 `mrbugloc`（arXiv 2512.05908） | 把代码抽象上移为**分层 NL 摘要**（file/dir/repo 三层），做 **NL→NL** 检索而非跨模态检索；两阶段 = 先路由到仓、再仓内自顶向下定位。工业系统 **DNext（46 仓 / 1.1M LOC）**：**Pass@10 0.82、MRR 0.50**，显著优于 retrieval baseline 与 agentic RAG（Copilot/Cursor） | **S1 的默认实现**：候选仓路由可用"仓级摘要 + 问题单"先做；退回到 v1 的"契约反查 + 症状归属"作为兜底 |
| *LogicLens: Leveraging Semantic Code Graph to explore Multi Repository large systems*（arXiv 2601.10773） | 目录外，本文新增下载 | 预构建**语义多仓图**（AST 结构 + LLM 语义富化：领域实体/操作/工作流）；自然语言查询动态取子图；出现 **impact analysis** 与 **symptom-based debugging** 两种涌现能力 | 为 S2 的"运行期/契约/编译期三图"补一张**语义图**；`probe` 的只读检索工具之一 |
| *Who Broke Me? Execution-Guided Repair of Behavioral Dependency Breaks*（arXiv 2610.09267，FSE 系） | `who-broke-me-dependency-breaks.pdf` | 行为性破坏**无编译反馈、常无文档**，失败测试不指向根 API；跑旧/新版本、**排序返回值不同的调用**→选出根 API→用其过滤库 diff。**BBCBench（100 例，Python/JS）**：相对"无升级证据"的 Pure Agent pass rate **+17%**、每个成功修复 **省 27% agent steps**；18% 由行为不兼容导致的下游 bug 长期未修 | **T4 归因的关键新机制**：跨仓改动中，"下游仓报错"未必是"下游仓引入"。用旧/新上游版本做差分执行来**区分引入者与传播者** |

### 1.2 多补丁 / 补全性

| 论文 | 落盘文件 | 关键量化结论 | 直接影响 |
|---|---|---|---|
| *One Is Not Enough: The Untold Story of Multiple Security Patches for One Vulnerability*（ASE'26） | `one-is-not-enough-the-untold-story-of-multiple.pdf` | 合并 4 个漏洞库 → **6,053** 个多补丁 CVE / **16,260** 个补丁；**20.6%** 的 CVE 涉及多补丁；合并库比任一单库认出多 **36–55%**。原型 SPectre 在人工核验下：同仓 **0.927 recall**、跨仓 **0.873 recall**；在 100 个"公开库都记为单补丁"的 CVE 上额外发现 **28 个未报告补丁（覆盖 20 个 CVE）** | **S5 增补"patch-completeness"判定**：一个补丁"通过测试"不等于"修完整"。跨仓任务尤其要检查**同因多补丁 / 分支回移 / 关联仓复刻** |

### 1.3 多 hunk / 协同修复

| 论文 | 落盘文件 | 关键量化结论 | 直接影响 |
|---|---|---|---|
| *Multi2Fixer: A Coordinator-Proposer Based Multi-Agent Framework For Fixing Multi-Hunk Bugs*（ASE'26） | `arxiv-2607.26591.pdf` | Defects4J 835 bug 中**近 50% 涉及多 hunk**，修复率随 hunk 数**显著下降**；hunk 间常有**语义/logic 依赖**，天然存在**修复顺序**；**单 hunk 的局部补丁无法用测试验证**（hunk 交互会掩盖个体效果）。设计：BugAnalyzer → 上下文构造 → **Coordinator 调度 hunk + 选候选** / **Proposer 生成候选** → 两阶段精炼。Defects4J 修好 **326** 个（含 **62** multi-method、**27** multi-file）；VUL4J **24**（含 5 多 hunk）；SEC-bench 11、PatchEval 19 | **S5 的排序机制原型**：跨仓 = 跨文件的推广。注意其失败模式：**10+ hunk 时 68.75% 出现"过度循环"**、35% 失败源于多向/多层依赖 —— 正是本设计要设**硬预算 + 停止准则**的理由 |

### 1.4 停止 / 循环 / 幻觉（v1 的 S6 只有"独立验证"，缺"何时不修"）

| 论文 | 落盘文件 | 关键量化结论 | 直接影响 |
|---|---|---|---|
| *Looping Is Not Reliability*（阿里云，arXiv 2607.24604） | `arxiv-2607.24604.pdf` | 30 个 HumanEval 修复 × 5 seed = **900** 条三修订轨迹：强制修订下"当前正确率"从 1 次修订后 **0.820** 降到 2 次后 **0.673**（ever-correct 反升至 0.847）。同状态实验中**陈旧 trace 对正确起点有害 34/135，仅 4/135**（+22.2pp，95% CI [8.9, 37.0]）。主张把 **admission / preservation / grounded certification / competence / liveness** 分离，并把**验证证据绑定到精确代码状态** | **S6/S7 新增两条不变量**：① 验证通过后**冻结已验证状态**，后续修订不得覆盖；② 证据必须绑定 `code_state_hash`，**禁止复用陈旧 trace 通过门禁** |
| *If It's Not Buggy, Don't Fix It*（arXiv 2609.10123） | `iterative-bugfixing-dynamics.pdf` | LLM 会在**完全无 bug** 的程序上"发现 bug"，且**修复 buggy 的速度低于破坏正确程序的速度**；常出现**同一改动反复加删的伪修复循环**；存在控制"编辑倾向"的 steering vector | **"不修改"必须是一等输出**；S3 的假设若无法被失败信号支持，应优先输出 `UNREPAIRABLE`/`NO_CHANGE`，而不是"顺手改点" |
| *Better Understanding, Better Fixes? A Study of Hallucination in LLM-based APR*（arXiv，51 页） | `hallucination-llm-apr.pdf` | 832 个 Defects4J bug：**21.0%–55.9%** 的生成补丁能过开发者测试；手工分析 812 个修复，**72.7%** 存在修复幻觉；其中**错误因果定位占 45.9%**、**错误修复策略占 18.5%**；能过全部测试的补丁里也存在幻觉 | **幻觉三层过滤**（见 §5.6）：因果定位层 / 策略层 / 补丁层，各自设可机器判据 |
| *Verify, Repair, Repeat, or Stop?*（arXiv 2609.xxxx） | `verify-repair-repeat-or-stop.pdf` | 验证器与修复器**都带噪**时，反复修复会**损伤已正确**的方案，"被接受的"比例上升而真实有效率下降。提出 VRR-Stop（四参数噪声模型 + belief filtering，按真实边际收益符号决定提交/继续）；判据退化为"仅需符号可辨识"；噪声大时配合无估计回退 VRR-Guard。GSM8K 压力设置下最终真实有效率比固定 5 轮修复高 **60.6pp**，平均只用 **0.72** 轮修复 | **S6 FAIL 的重试上限**从"≤1 次"改为"**按边际收益符号**决定"；每轮必须证明"继续修复的预期增益 > 0"，否则提交当前最优或 `ESCALATED` |

### 1.5 跨仓终验 / CI 级验证（v1 未覆盖）

| 论文 | 落盘文件 | 关键量化结论 | 直接影响 |
|---|---|---|---|
| *CI-Repair-Bench* | `ci-repair-bench.pdf` | **567** 个真 CI 失败 / **103** 仓，**只用完整 CI 重执行**（原始 workflow）判对；**12** 类 CI 错误；参考流程最好 LLM 仅 **18.9%**；格式化/lint 这类"局部、工具强制"的失败最易修，**环境/依赖/配置类最难** | **S6 的终验改为 CI 原样重执行**（而非只跑单测）；并把失败**按类型分层报告**，因为多仓任务最容易踩的正是依赖/配置类 |
| *RETRACE* | `retrace-ci-repair-experience.pdf` | 从 PR/CI 历史重建"问题级"修复经验（endpoint view + development view，用 CI 执行证据对齐）；CI-Repair-Bench（565 PR/101 仓/12 类）上 mini-SWE-agent Pass@1 **19.6%→31.9%**（MiniMax-M2.5）、**23.3%→32.8%**（DeepSeek-V4-Flash）；Codex **15.5%→27.5%** | **可选经验层**：把历史 PR 里的"多仓同修"模式抽成问题级经验；这是 v1"延期记忆"的**有条件**启用路径（先建 CI 证据对齐，再谈复用） |
| *ORCA: Observability-Grounded Program Repair for Microservice Incidents* | `orca-observability-grounded-repair.pdf` | 575 例（合成代码/合成配置/真实微服务事故三部分）；在 **150 例真实事故**子集上产出 **113** 个过 validity 的补丁、**45** 个通过 telemetry-replay 的缓解；基线中最高的是 mini-SWE-agent **74 / 23**，但**均 token 约 640k/例 vs ORCA 约 26k/例** | **多仓事故的"遥测重放"验证**：服务级事故的终验不能只看单测，要看**遥测是否恢复**；同时提示"上下文预算"是决定性成本项 |
| *Beyond Fault Localization: A Trajectory-Level Study of LLM Agents for Microservice RCA* | `trajectory-level-microservice-rca.pdf` | 在公开微服务 RCA 基准上分析 **3,500** 条诊断轨迹：agent 可以**答对故障服务**，却**无法重建故障在受影响服务间的传播路径**；存在"答案正确性"与"诊断质量"的分离 | **S4 的确认门要看"传播路径证据"，不只看"点对服务"**；这也解释了为什么 v1 的 C2（因果证据）必须要求"区分实验"而非"命中" |

### 1.6 成本/失败面（用于校准 S7 与指标）

| 论文 | 落盘文件 | 关键量化结论 |
|---|---|---|
| *How Coding Agents Fail Their Users*（20,574 真实会话 / 1,639 仓） | `how-coding-agents-fail-their-users-a-large-scale.pdf` | 以"开发者反弹"为可观测信号，归纳 **7** 种反复出现的错位形态（如何读项目、如何理解意图、如何遵守规则、如何界定动作边界……） |
| *Characterizing the Failure Modes of LLMs in Resolving Real-World GitHub Issues* | `arxiv-2605.12270.pdf` | 900 次试验 / **243** 次失败人工分析：**策略形成与逻辑合成最易错**，其次是问题理解；**定位反而失败率最低** |
| *CHAIN SWE*（arXiv，19 页） | `chainswe-multi-bug-maintenance.pdf` | **304** 个 issue 链 / **54** 个 Python 项目；链越长性能**最多掉 70%** |
| *ChainSWE 同向的"多文件掉点"* | `arxiv-2504.08703.pdf`（C29，v1 已引用） | 改 ≥3 个文件时成功率跌破 10%；**注意其"不得单因归因于任务复杂度"限定** |
| *XRepoSkill* | `arxiv-2609.36807.pdf` | 同一 issue 的**成功 vs 失败轨迹对比**导出候选规则，规则配**可执行谓词**，且**必须跨多仓复现**才保留；DeepSWE 上比同 agent 无技能高 **10.3pp**、比最强技能基线高 **5.0pp** |
| *DARS: Dependency-Aware Reward Shaping* | `arxiv-2610.01207.pdf` | 用**前置依赖图**给 step 级信用；被验证的谓词按到最近破损前置的图距离衰减，独立谓词不衰减。适用面广（GiGPO/ARPO/AEPO 可插拔） |
| *PatchFusion: A Single Patch Is Not Enough* | `arxiv-2607.01597.pdf` | 事后**确定性**融合补丁候选（不做测试判决、不请 LLM judge）：SWE-bench Verified **426/500**、Multilingual **236/300**；**3.28ms/例**；恢复 **41 / 27** 个"任何单一来源都修不出"的 bug |

---

## 2. 修订后的多仓判据（这是全文的核心结构）

v1 §3 说"多仓 = 把系统级现象收敛到仓级候选再证明其为因"。v2 把它拆成**四个可判定的子问题**，每个都有对应的新证据：

```
Q1 症状落在哪个仓的边界？        → 分层路由（仓 → 目录 → 文件），NL 摘要表示     [ICSE'26 多仓定位]
Q2 哪个仓/哪次改动是"引入者"？     → 差分执行（旧/新上游）+ 返回值差异排序根 API    [BBCFixer]
Q3 补丁要不要跨仓协同、谁是生产者？ → hunk 依赖建模 + Coordinator 排序 + 候选选择  [Multi2Fixer]
Q4 跨仓"改完了吗"？              → CI 原样重执行 + patch-completeness + 遥测重放   [CI-Repair-Bench / multi-SP / ORCA]
```

| 子问题 | v1 的机制 | v2 的机制 | 为什么必须改 |
|---|---|---|---|
| Q1 | 症状归属锚定 + 契约面反查 | **两阶段**：先"问题单→仓"路由，再"仓内→文件"定位；仓内用 NL 摘要 | 工业 46 仓系统上 0.82 Pass@10 说明"路由优先"可规模化；契约反查在契约缺失/漂移时静默漏检（v1 已列为失效兜底） |
| Q2 | 传播假设 + 判别实验 | 增加**差分执行**：固定失败用例，在上游旧/新版本各跑一次，比较返回值 | 行为性破坏**无编译反馈、失败测试不指向根 API**；只看"下游报错"会把修复打在传播者上（与 FALAT"引入 vs 继承"同源） |
| Q3 | 无显式排序 | hunk 依赖图 + 生产者先行 + 候选融合 | hunk 间有语义依赖，**单 hunk 局部验证无效**；一 hunk 错则整补丁作废 |
| Q4 | 跨仓验证矩阵（合集） | CI 原样重执行 + 补丁完整性 + 遥测重放 | 多改动的失败面主要在依赖/环境/配置，单测覆盖不到；"只修一半"在多补丁现象里占 **20.6%** |

---

## 3. 修订后的流程与角色

保留 v1 的 S0–S7 编号与状态机（`RECEIVED`→…→`DELIVERABLE` 等 7 个终态）。v2 仅在 S1/S4/S5/S6 注入新步骤，**不新增阶段编号**，避免与 v1 §12.1 的 A0/A1/B1/B2 消融档混淆。

```
S0 受理（不可信输入封装）                                    repair
S1 候选仓收缩  ── 两阶段：问题单→仓路由 → 仓内 目录→文件 定位   probe
S2 契约/拓扑建模 ── 编译期图 ‖ 契约图 ‖ 运行期图 ‖ 语义图       probe ∥ contract-checker
S3 假设生成   ── 每条假设带 prediction + falsifier            probe
S4 判别实验   ── ①差分执行(旧/新上游) ②可逆干预 ③传播路径证据   probe
     ╔══════════════════════════════════════════════════════╗
     ║ 确认门  C1 现象可复现 ∧ C2 因果证据 ∧ C3 干预可验证     ║
     ║ 新增：C2' 引入者/传播者已区分（差分执行证据）           ║
     ╚══════════════════════════════════════════════════════╝
S5 补丁协同   ── hunk 依赖图 → 生产者先行 → 候选生成/选择      repair
                 → patch-completeness 校验（同因多补丁/分支/关联仓）
S6 交叉验证   ── ①CI 原样重执行 ②遥测重放(服务类) ③独立 diff 审查 referee
                 → 证据绑定 code_state_hash；禁止复用陈旧 trace
S7 交付/升级  ── DELIVERABLE / RANKED / PRE_MERGE / UNREPAIRABLE / ESCALATED …
```

### 3.1 agent 角色（在 v1 §8.1 之上只做增量）

| 角色 | agent | 相对 v1 的增量 | 理由（证据/边界） |
|---|---|---|---|
| 单写者 + 修复 | `repair`（primary） | S5 增加 **hunk 依赖图**生成与**生产者先行**调度；新增 `patch-completeness` 检查 3 项 | Multi2Fixer 的 Coordinator 语义；multi-SP 的"只修一半"风险 |
| 跨仓只读定位 | `probe`（primary） | S1 增加**两阶段路由**；S4 增加**差分执行**（在新版本/旧版本各跑一次失败用例） | ICSE'26 两阶段定位；BBCFixer 差分排序 |
| 契约专精 | `contract-checker`（subagent） | 增加 `buf breaking` / `japicmp` / dependency-cruiser 的**跨仓边**输出 | v1 已定；新增语义图交点 |
| 独立验证 | `referee`（subagent） | 增加 **CI 重执行**与**遥测重放**脚本调用；新增**状态绑定**校验 | CI-Repair-Bench；Oracle 的 telemetry-replay；Looping-Is-Not-Reliability |
| 证据采集 | `tracer`（subagent，B2 档才启用） | 不变 | "编码任务可并行部分更少"【单边 C54】，留最后消融 |

> 【判断】v2 **不新增 agent**。新增能力（差分执行、语义图检索、CI 重执行）都是**工具调用**，可以挂在现有 `probe`/`referee` 的工具权限里。这与 MAST【论断 C48】"多 agent 失败集中在 specification / misalignment / verification"的教训一致：**先补协议与门禁，再谈增员**。

### 3.2 权限增量（OpenCode v1 语法，本机 1.18.32）

在 v1 §8.2 的矩阵基础上，只需为只读角色增补以下**只读**命令白名单；一切写命令保持 `deny`，其余仍落 `"*": "ask"`（注意 v1 §8.3 陷阱：`write` 规则永不生效，只写 `edit`；`"*"` 必须最前；last-match-wins）。

```yaml
# probe / contract-checker（只读）——增量片段
permission:
  bash:
    "*": "ask"
    # —— 新增：跨仓只读检索/差分执行（都不改工作区）——
    "buf breaking*": "allow"
    "japicmp*": "allow"
    "npx dependency-cruiser*": "allow"
    "git -C * log*": "allow"
    "git -C * diff*": "allow"
    "git -C * worktree*": "deny"      # worktree add/remove 会写元数据

# referee（独立验证）——增量片段
permission:
  bash:
    "*": "ask"
    "gh run view*": "allow"           # 只读查看 CI 运行与日志
    "gh pr checks*": "allow"
    "gh run rerun*": "deny"           # 会触发真实执行
    "npm ci*": "allow"                # 仅用于隔离沙箱内
    "npm test*": "allow"
```

> 【观测/判断】CI 重执行与遥测重放**必须发生在隔离沙箱或 scratch 副本**内（v1 §8.5 已要求只读角色 cwd 指向 scratch）。`gh run` 的"只看"与"重跑"要在权限上分开，否则 referee 会无意触发生产 CI。

---

## 4. 证据账本 schema 的增量

v1 §6 的四个文件（`case.json` / `evidence.ndjson` / `hypotheses.json` / `decision.json`）**保持不变**。v2 只加两类**字段级**内容：

### 4.1 `evidence.ndjson` 新增 `provenance` 与 `state_binding`

```json
{
  "case_id": "CASE-123",
  "kind": "differential_execution",
  "hypothesis_id": "H-04",
  "provenance": {
    "role": "introducer",
    "repo": "upstream-lib",
    "old_version": "1.4.2",
    "new_version": "1.5.0",
    "differing_calls": [
      { "call": "Parser.parse", "old_return": "Node", "new_return": "Node?" }
    ],
    "ranked_root_api": ["Parser.parse"]
  },
  "state_binding": {
    "code_state_hash": "sha256:...",
    "env_digest": "container:...",
    "replay_input": "scripts/repro-123.sh",
    "stale": false
  },
  "supports": ["H-04"],
  "contradicts": ["H-01"]
}
```

**拒收规则（在 v1 五条之上加两条）：**

6. `differential_execution` 类证据若无 `old_version`/`new_version` 与 `differing_calls`，拒绝；
7. 任何证据若 `state_binding.code_state_hash` 与**当前待验代码状态**不一致，必须标 `stale: true`，**不得**用于通过 C1–C3 门禁。

### 4.2 `case.json` 新增 `patch_plan` 与 `completeness`

```json
{
  "patch_plan": {
    "hunks": [
      { "repo": "upstream-lib", "role": "producer", "depends_on": [] },
      { "repo": "order-svc",    "role": "consumer", "depends_on": ["upstream-lib"] }
    ],
    "order": ["upstream-lib", "order-svc"],
    "candidates_per_hunk": 3,
    "fusion": "deterministic_edit_atom"
  },
  "completeness": {
    "same_cause_multi_patch": "checked",
    "branch_backport": ["release/2.x"],
    "related_repos": ["upstream-lib", "order-svc"],
    "missing_patches": [],
    "verdict": "complete"
  }
}
```

---

## 5. 关键机制的实现细节

### 5.1 S1 两阶段分层检索

| 阶段 | 输入 | 产物 | 判据 |
|---|---|---|---|
| 阶段 A：问题单 → 仓路由 | 问题单文本 + 仓级摘要（NL） | 候选仓 top-k + 每个仓的"一句话归属理由" | top-k 覆盖真值仓；k 默认 5，>10 时分批 |
| 阶段 B：仓内 → 目录 → 文件 | 选定仓 + 目录/文件级摘要 | 候选文件 + 候选函数/方法 | 定位粒度以**方法/服务/契约边界**为最小单元（v1 §3：语句粒度 Top-1 仅 4%） |

【判断】摘要的**种子上下文**要用"仓/目录级架构说明"，而非单文件低层实现描述 —— 这是 ICSE'26 那篇的关键设计（对比图 Fig.1）。摘要落盘为**可 diff 的产物**，随代码变更失效（否则会变成陈旧证据）。

### 5.2 S4 差分执行归因（解决"修错仓"）

```text
前置：已有可复现失败用例 R（S0/S4 产出），且上下游仓都可获取两个版本
1. 在「上游旧版本 v_old」下执行 R → 记录调用序列 C_old 与各调用返回值
2. 在「上游新版本 v_new」下执行 R → 记录 C_new
3. 比较同调用位置的返回值/异常差异 → 得到 differing_calls
4. 按"差异显著性 × 调用深度"排序 → 根 API 候选
5. 用根 API 候选过滤上游 diff（只保留涉及该 API 的改动）
6. 产出 provenance= introducer|propagator 判定，作为 C2' 证据
```

【论断依据】BBCFixer 明确：行为性破坏**无编译反馈、常无文档**；对无升级证据的 agent，**大多数失败修复没有识别出根 API**；其差分排序 + 候选过滤使 pass rate +17%、steps −27%。

【推论】跨仓场景价值更大：因为"改错仓"是多仓独有的失败面（v1 §12.2 已把"误修率"列为指标）。

### 5.3 S5 hunk 依赖图与生产者先行

| 步骤 | 内容 | 失败模式与对策 |
|---|---|---|
| 建图 | 节点 = hunk（仓×文件×区域）；边 = 语义依赖（生产者 → 消费者） | 无明显依赖时退化为并行独立 hunk |
| 定序 | 拓扑序；环 → 拆分为"先建不变量、再消费"两次提交 | Multi2Fixer：多向依赖是 35% 失败的原因 → 环必须显式拆分 |
| 生成 | 每个 hunk 出 **K 个候选**（Proposer） | — |
| 选择 | Coordinator 在"已修复前缀"语境下选候选 | 单 hunk 局部验证**无效**（hunk 交互掩盖效果）→ 只做全补丁级验证 |
| 融合 | 对无法确定选择时的**编辑原子**做确定性融合（不做测试判决） | PatchFusion：426/500、3.28ms、恢复 41 个单来源修不出的 bug |
| 预算 | 10+ hunk 时**强制**降低单 hunk 重试次数 | Multi2Fixer：10+ hunk 时 68.75% 出现过度循环 |

### 5.4 S6 证据绑定与修订契约

```text
不变量（违反即拒绝放行）：
B1 验证证据必须携带 code_state_hash 与 env_digest；
B2 已验证通过的代码状态进入「冻结集」，后续任何修订不得覆盖它；
B3 复用陈旧 trace 的判定 = 拒绝（不是"重新验证即可"）；
B4 续修需满足「真实边际收益符号 > 0」，否则提交当前最优或 ESCALATED。
```

【论断依据】Looping-Is-Not-Reliability：当前正确率 0.820→0.673 而 ever-correct 反升，说明"多轮修订"单独不构成可靠性；陈旧 trace 对正确起点有害 34/135 vs 4/135。VRR-Stop：验证器与修复器都带噪时，应按**真实边际收益符号**决定提交/继续，而非固定轮数。

【判断】把 v1 的"S6 FAIL ≤1 次"升级为"按边际收益符号决定"，但**仍然保留硬上限**（例如 ≤3 轮），两者取**更严者**。理由是 VRR-Stop 的实证在 GSM8K 压力设置下成立，**未见仓库级多仓证据**，因此只能作先验。

### 5.5 S6/S7 终验：CI 原样重执行 + patch-completeness + 遥测重放

| 终验项 | 适用 | 判据 | 证据 |
|---|---|---|---|
| CI 原样重执行 | 所有代码类 | 用**原始 workflow** 全量重跑，而非只跑单测 | CI-Repair-Bench：只用完整 CI 重执行判对；最好 LLM 18.9% |
| 按 CI 错误类型分层 | 所有 | 至少区分"格式化/lint"与"环境/依赖/配置" | 同上：后者显著最难 |
| patch-completeness | 安全/依赖类 | 检查同因多补丁、分支回移、关联仓复刻 | multi-SP：20.6% 多补丁；跨仓 recall 0.873 |
| 遥测重放 | 服务/运行时事故 | 补丁后遥测指标恢复（非仅单测通过） | ORCA：telemetry-replay 45/150 真实事故；token 26k vs 640k |
| 传播路径重建 | 微服务 RCA | 不只"点对服务"，还要能重建故障传播路径 | Trajectory-Level RCA：3,500 轨迹显示"答对但路径错" |

### 5.6 幻觉三层过滤

| 层 | 判据 | 依据（幻觉研究） |
|---|---|---|
| 因果定位层 | 假设必须有 prediction + falsifier；且**至少一条差分执行证据**指向"引入者" | 错误因果定位占修复幻觉 **45.9%** |
| 策略层 | 若补丁改变了架构/接口/依赖语义，**强制**进入人工评审（不得自动放行） | 错误修复策略占 **18.5%** |
| 补丁层 | 最小 hunk 原则 + 回归"先红后绿" + CI 重执行 | 仅 21.0%–55.9% 补丁过开发者测试；**过全部测试的补丁里也存在幻觉** |

---

## 6. 指标与消融（在 v1 §12 之上加行）

### 6.1 新增指标

| 指标 | 定义 | 对应证据 |
|---|---|---|
| **仓路由 Top-k 命中率** | 真值仓落在 top-k 候选的比例 | ICSE'26 多仓定位的 Pass@10/MRR 口径 |
| **引入者归因准确率** | `provenance=introducer` 判定与人工真值一致的比例 | BBCFixer 的根 API 识别 |
| **误修率（v1 已有，v2 强化）** | 补丁落在传播者而非引入者的比例 | 同上 |
| **hunk 序正确率** | 生成顺序与真值依赖拓扑序一致的比例 | Multi2Fixer 的排序 |
| **补丁完备率** | 判定 `complete` 且人工认为无遗漏的比例 | multi-SP |
| **陈旧证据拒绝率** | 被 `stale` 规则拒绝的证据条数 / 总证据条数 | Looping-Is-Not-Reliability |
| **CI 级解出率** | 通过 CI 原样重执行的比例 | CI-Repair-Bench |
| **续修增益符号正确率** | "继续修复"决策与事后真实增益符号一致的比例 | VRR-Stop |

### 6.2 消融矩阵（在 v1 A0/A1/B1/B2 之后加一档）

| 档 | 配置 | 相对上一档的唯一增量 |
|---|---|---|
| A0 | 单 agent 全流程 | ——（基线） |
| A1 | A0 + `probe` 只读定位（两阶段路由） | 只读定位 agent |
| B1 | A1 + `contract-checker` + `referee`（v1 设计） | 契约专精 + 独立验证 |
| **B1′** | B1 + **差分执行归因（S4）+ hunk 依赖图（S5）** | 上游归因 + 跨仓排序 |
| **B1″** | B1′ + **CI 原样重执行 + patch-completeness** | 终验升级 |
| B2 | B1″ + `tracer` 同层并行 | 并行只读采集 |

【判断】把"归因/排序"和"终验"分成两档，是为了**分别**回答两个 v1 遗留问题：Q1（多仓定位能否规模化）与 Q4（多仓"改完了吗"如何判）。否则一档加两个变量，无法归因。

### 6.3 可借用基准的更新

| 基准 | 用途 | 备注 |
|---|---|---|
| **BeyondSWE CrossRepo** | 多仓主基准 | 200 issues / 67 仓（v1 已列） |
| **CodeScaleBench Org** | 压测 S1 候选集收缩 | 单方报告，引用须标注（v1 已列） |
| **BBCBench** | 归因机制（差分执行）回归 | 100 例行为性依赖破坏，Python/JS |
| **CI-Repair-Bench** | 终验机制回归 | 567 例 / 103 仓 / 12 类；用完整 CI 判对 |
| **RepoEffi-Bench** | 性能类缺陷（时间低效）扩展 | 140 例；提醒：无崩溃/无失败测试的有另一类失效面 |
| **Defects4J multi-hunk 子集** | hunk 排序机制回归 | Multi2Fixer 报告 62 multi-method / 27 multi-file |

---

## 7. 风险与未决

| # | 风险 | 证据 | 缓解 |
|---|---|---|---|
| R1' | "跨仓改写"本身可能不必要：有的多补丁只是同仓多 hunk | multi-SP：同仓 0.927 / 跨仓 0.873（都高，但性质不同） | S5 先判"是否真的跨仓"；同因同仓走单仓多 hunk 路径 |
| R2' | 续修决策的边际收益模型无仓库级证据 | VRR-Stop 仅 GSM8K 压力设置 | 只作先验；保留硬上限取更严者 |
| R3' | 语义图/摘要会**陈旧**（代码变更即失效） | Looping-Is-Not-Reliability 的陈旧证据教训 | 摘要作为可 diff 产物 + 失效标记；证据必须绑 `code_state_hash` |
| R4' | 经验/记忆层（AdaRepair-Mem / XRepoSkill / RETRACE）跨仓迁移未证实 | XRepoSkill：成功轨迹里的行为未必是成功原因 | **延期**，见 v2 §8；先建"同失败用例、同模型、跨仓对比"口径 |
| R5' | CI 重执行成本高 | CI-Repair-Bench 用完整 CI 判对；ORCA token 26k vs 640k | 只在 S6 做一次；S4 用轻量差分执行代替 |

**未决问题（新增）**

| # | 问题 | 需要的证据 |
|---|---|---|
| Q7 | 差分执行的"新旧版本"在真实多仓里是否总能获取？（内部 SDK 未 pin 版本时） | 接入规范需定义"版本可获取性"前置条件 |
| Q8 | hunk 依赖图能否自动构建（而非人工标注）？ | 需要一个"跨文件语义依赖"抽取器；可先借 CodeGraph/语义图 |
| Q9 | CI 重执行在私有仓/无 CI 仓的替代门是什么？ | 备选：预发环境遥测重放 + 契约测试 |
| Q10 | patch-completeness 的召回上限（0.873 跨仓）是否够用？ | 需要在本组织数据上复测 |

---

## 8. 明确**不做**（避免"瞎编"）

1. **不引入未见落盘/未核实来源**：本文所有量化结论都能在本机对应 PDF 首页/摘要找到；目录外新增的两篇已单独说明下载来源（arXiv 2512.05908、2601.10773）。
2. **不把"经验记忆/技能学习"当作已成立机制**：AdaRepair-Mem、XRepoSkill、RETRACE 都是 v1 之后的新证据，但**跨仓可迁移性各自只在其自身基准上成立**，本设计把它们列为**可选层 + 消融项**，不进入主流程门禁。
3. **不宣称 v2 一定优于 v1**：B1′/B1″ 是**待消融**的拓扑，不是已证明的增益。这与 v1 §12.1"多 agent 增益需被消融证明"的立场一致。
4. **不把单基准数字外推**：ICSE'26 多仓定位的 0.82/0.50 来自**一个** 46 仓工业系统（DNext）；CI-Repair-Bench 的 18.9% 来自其 567 例构造；Multi2Fixer 是 Defects4J 系。跨到本组织前必须复测。

---

## 9. 可复现的核验方法（供他人抽查）

```bash
# 0) 准备（仅本机，UV_CACHE_DIR 指向 /tmp，避免写用户缓存）
cd docs/bugfix-methodology/research

# 1) 抽取任一论文首页正文（标题/作者/摘要）
UV_CACHE_DIR=/tmp/uvcache uv run --with pymupdf python3 /tmp/pdfx.py <file>.pdf --pages 1

# 2) 全文关键词定位（示例：差分执行、多 hunk 依赖）
UV_CACHE_DIR=/tmp/uvcache uv run --with pymupdf python3 /tmp/pdfx.py \
  who-broke-me-dependency-breaks.pdf --grep "root API,differing,pass rate"
UV_CACHE_DIR=/tmp/uvcache uv run --with pymupdf python3 /tmp/pdfx.py \
  arxiv-2607.26591.pdf --grep "multi-hunk,repair order,dependency"

# 3) 逐篇盘点标题（核对本目录是否已覆盖某主题）
UV_CACHE_DIR=/tmp/uvcache uv run --with pymupdf python3 /tmp/batch_title.py
```

> `/tmp/pdfx.py`（按页/按关键词抽文本）与 `/tmp/batch_title.py`（批量抽首页标题）是本轮为核验写的小工具，未落盘进仓库；如需长期使用可移入 `scripts/`。

---

## 10. 与各文档的关系

| 文档 | 关系 |
|---|---|
| [`multi-repo-issue-fix-flow.md`](./multi-repo-issue-fix-flow.md)（v1） | **主文档**。v2 是增量修订：骨架/状态机/权限矩阵全保留，只在 S1/S4/S5/S6 注入新机制 |
| `docs/bugfix-methodology/` | v2 的新证据来源（2026-10 批次 ~20 篇） |
| `docs/multi-repo-bugfix/` | S1/S2 的方法论与工具来源 |
| `docs/opencode-agents/` | 权限语法的实测事实来源 |
| `docs/opencode-tui-agent-plan.md` / `bugfix-multi-agent-diagnosis.md` | v1 已记录的待修订项（F1/F2、`write`→`edit`）在本设计中同样适用 |
