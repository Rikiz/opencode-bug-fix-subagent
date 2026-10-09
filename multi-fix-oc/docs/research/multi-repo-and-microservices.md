# 多仓 / 跨仓与微服务定位

> 调研于 2026-10 完成。**这一节是整个调研中最重要的部分**：它是「一个 issue 单，不知道该改前端、后端、网关还是别的仓」这个问题的直接对应物。
> 核心发现：**这个方向的公开文献很薄，但并非空白。** 本节末尾列出确实**不存在**的东西。

## 1. 存在的公开工作

### 1.1 BeyondSWE / SearchSWE（arXiv 2603.03194）—— 最实质的公开基准

500 实例 / 246 仓库，沿两条轴组织：**解析范围**（局部函数 → 全局仓库）与**知识范围**（仓内 → 跨仓/领域/网络）。四个子集：

| 子集 | 实例 / 仓库 | 定义 | 要点 |
| --- | --- | --- | --- |
| **CrossRepo** | 200 / 67 | issue 格式熟悉，但**必须**依赖外部仓库 / StackOverflow / 上游库 | 平均每 issue 约 1.3 条外部链接 |
| **DomainFix** | 72 / 12 | 11 个研究领域（量子物理、分子动力学、地理空间、生物信息学、材料科学）；需 3 名领域专家一致通过 | — |
| **DepMigrate** | 178 / 120 | 上游破坏性升级下的全仓迁移（23 个包，如 NumPy 1.x→2.0） | 环境装**已升级**依赖，代码停在迁移前 commit |
| **Doc2Repo** | 50 / 50 | 从自然语言规格构建整个仓库（2025-08 之后的仓，名称遮蔽） | — |

结果：最佳 OpenHands agent 平均 **46.12**；Codex+GPT-5.4(xhigh) 配合 search-aware prompt 达 **56.65**。前沿模型尽管在 SWE-bench Verified 上有 80%+，在此**低于 45%**。搜索增强对多数模型有帮助，对少数模型帮助很大，也**会让一些模型变差**。

规模：repo card 称平均 **5.6 文件 / 209.9 行**每实例，论文摘要称 **10.9 文件 / 1039 行**，对比 SWE-bench Verified 的 1.3 / 11.6（18×）。**该数字在两个来源间不一致，未解决。**

> **重要区分**：CrossRepo 从**已知仓库**出发、需要外部*证据*，它**不要求选择仓库**。这与本项目的路由问题不是同一件事。

### 1.2 DNext 多仓定位（arXiv 2512.05908, ICSE 2026 LLM4Code）—— 唯一以"哪个仓"为主任务的论文

把定位重构为在**层级化上下文感知摘要**上的自然语言到自然语言搜索（文件 → 目录 → 仓库），而非对代码做 RAG。在 **DNext** 上评测：46 个仓库、110 万行 LOC、真实电信工单。

- **Pass@10 = 0.82，MRR = 0.50**
- 在 Pass@3 / Recall@3 的**仓库路由**上优于检索基线**以及 agentic RAG**（GitHub Copilot、Cursor）
- 消融目录层过滤：MRR **−54%**，Recall@10 **−37%**，prompt token **+44%**
- 平均每个 bug 修改 7.2 个文件（最多 10），故取 k=10

> **对本项目最关键的三条**：层级摘要是路由的正确表示；目录层不可省；**用 Pass@3/Recall@3 而不是 top-1 评估路由**，因为歧义问题本来就跨服务。

### 1.3 Sourcegraph CodeScaleBench

370 个任务中 220 个是**跨仓/跨组织发现**，每个跨 **3–20 个仓库**，覆盖 11 个精选生态（kubernetes-ecosystem、apache-kafka-ecosystem、compiler-toolchain、mozilla-firefox），带 oracle 核验的真值与**信息对等**（baseline 本地 clone 全部仓库）。套件包括 `csb_org_onboarding`、`csb_org_migration`、`csb_org_security`、`csb_org_crossrepo_tracing`、`csb_org_domain`、`csb_org_incident`、`csb_org_compliance`、`csb_org_platform`、`csb_org_crossorg`、`csb_org_org`、`csb_org_crossrepo`。

结果：Sourcegraph MCP 在 org 任务上 reward **+0.0339**——正收益但**不大**；真正显著的是**检索质量**（P@10 0.095→0.313、R@10 0.120→0.272、F1@10 0.091→0.240）与**成本 −30.2%**。

### 1.4 其他

- **Multi-CoLoR**（arXiv 2602.19407）—— 多*语言*而非多仓，但 AMD 的 C++ + QML 企业代码库是与异构工业环境最接近的已发表类比。
- **MULocBench** —— 把非代码构件纳入定位目标，文件级仍 <40%。

## 2. 产业实践：实际建出来的东西

### 2.1 Sourcegraph —— 最成熟的跨仓基础设施

**SCIP**（Source Code Intelligence Protocol）：语言无关索引，含定义位置、符号元数据、**包归属（仓库 + 版本）**、跨仓依赖信息与版本数据。跨仓 "Go to Definition" 是**符号 ID 直接查找 + 版本感知解析**，不是模式匹配。

他们自己承认的局限：**前向声明和 manifest 文件不在 SCIP 中**。第三方分析（riftmap.dev, 2026-05）指出同一点：处理 Terraform/Helm/K8s/Atlantis/GitOps 的依赖影响问题时，"推荐做法是对 `Chart.yaml` 做正则"，因为"那些关系都不是符号"。

MCP server 暴露 `keyword_search`、`nls_search`、`go_to_definition`、`find_references`、`read_file`、`commit_search`、`diff_search`、`compare_revisions`、`evaluator`（Lua 聚合）、`code_finder`、`deepsearch`。已文档化客户端：Claude Code、Codex、Cursor、Copilot、**OpenCode**、Amp。仅企业版，支持按工具禁用。

**Deep Search** 显式沙箱化：无网络、无文件系统、只读、由 **search context**（一组固定 revision 的命名仓库集合）限定。他们的建议：先调 `list_repos` 再收窄范围，可测地同时改善速度与质量。

他们自己对差距的表述："Claude Code、Cursor 和 Codex 擅长在你当前项目内生成新代码，但它们是孤立的，无法回答规模化后最重要的问题。"他们点名 Amp 的 Librarian subagent 是早期、有限（仅 GitHub、仅开发者探索）的例外。

**GitLab Orbit**（2026-06）据报道是把代码符号 + SDLC 对象做成 GitLab.com group 上的属性图，经 MCP 提供——同一条路线：符号，不是构件。

### 2.2 新兴开源跨仓图工具

全部基于 MCP、本地优先，且**都做出同一个架构选择：确定性图，不用 embedding**。

| 工具 | 特点 |
| --- | --- |
| **Atlas** | TS/JS + Swift + Kotlin + Go；跨仓 **HTTP 契约链接**（前端 `consumes` ↔ 后端 `exposes`，按 method + 归一化路径匹配；未匹配调用成为一等 `external` 节点 = "你依赖但没有的后端"）；`context`/`impact`/`path`/`neighborhood`/`endpoints` 查询；6 个只读 MCP 工具；生成 `architecture.md` 含约定与"地雷"（TODO/FIXME/HACK/WHY）。**明确拒绝 embedding**："embeddings 从未解决跨仓问题" |
| **RepoHelix** | Kuzu 图数据库；契约归一化为 `api / event / package / dto / schema / grpc-method / dubbo-method / graphql-operation / enum / config`；`trace`（某契约的生产者/消费者/schema）、`impact_analysis`；质量治理（低置信证据审计、误报拒绝、别名覆盖） |
| **code-system-graph** | 跨 API、事件、schema、包、数据库、部署、测试、owner、文档的联邦图；**仅在有确切证据时连边**，并刻意把动态路由 / 插值表名留作**未解析证据**，使 agent 无法把"缺失"误认为"安全"。不一致检测器：`enum-mismatch`、`api-path`、`config-key`、`doc-drift` |
| **grafel** | 50+ 语言，跨仓社区 + 在**组装后的 group 图**上算 PageRank（社区可跨仓）；跨仓 `trace(source="mobile-app::UICheckout", target="payments-api::ChargeHandler")` |
| **CoreGraph** | tree-sitter + **stack-graphs** 做跨文件名字解析；**每条边带 0.0–1.0 置信度与来源**，使消费者能区分编译器级事实与启发式；monorepo 原生；检测跨文件不一致 |

**所有这些工具的共同模式**：(1) **预先计算、有证据支撑、带置信度评分**的结构，而非语义 embedding；(2) **契约类型边**（HTTP/事件/schema/DB/config），不只是源码符号；(3) 以 **MCP** 交付给任意 agent；(4) **显式暴露未知/陈旧的覆盖范围**，避免 agent 过度信任这张图。

> 第 (4) 点是本项目 `topology.json` 中 `coverage.staleRepos` 与 `coverage.unknownEdges` 两个字段的直接来源。Atlas 把未匹配的跨仓调用做成**一等 `external` 节点**，code-system-graph 把动态路由留作**未解析证据**——都是同一个原则：缺失必须可见。

## 3. 微服务根因定位（遥测侧）

多仓文献真正所在的地方，但它定位的是**组件**而非代码：

RCLAgent、LATS-RCA、ChatRCA、MicroRCA-Agent、Sherlogs、AetherLog、OpenRCA（详见 [localization-and-rca.md](localization-and-rca.md)）。

**CCF 国际 AIOps 挑战赛**（challenge.aiops.cn）是年度工业赛道，有公开的代码释出方案——MicroRCA-Agent 决赛 Top-5，50.71 分；同赛道另一方案 48.52 分。

可迁移到本项目的核心发现：**众数模态是指标（单独 42.78），而日志+指标（51.27）优于三模态全上（50.71）**；**metric → trace → log 是正确的分析顺序**（OpenRCA 的 RCA-agent 被明确如此指示）。

## 4. 不存在的东西（我找得很用力）

以下是**明确检索后确认没有公开基准**的部分——它们恰恰是真实多仓缺陷的高频形态：

1. **没有公开的"纯 issue → 仓库路由"基准。** DNext 是专有的。一个带 oracle 路由标签的公开多仓定位基准，用真实多语言微服务语料（TrainTicket、Hipster Shop、Sock Shop、OpenRanks、DeathStarBench）加真实企业脱敏集构建，仍是空白。
2. **没有跨仓 *patch* 基准。** BeyondSWE 的 CrossRepo 仍在已知仓内定位。没有任何东西度量"产出一个同时修改仓库 A、仓库 B 并更新两者之间契约的补丁，且测试横跨两者"。
3. **没有 API 契约 / schema 不一致这一缺陷类别的基准。** 这是真实世界最高频的多仓缺陷（生产者改字段名；消费者严格反序列化；网关拒绝）。每个工具都建了契约图，但**没有任何基准包含"故意破坏一个契约"的实例类别**，也没有论文报告该类的端到端修复率。
4. **服务网格 / 网关 / 路由器的根因在代码修复文献中未被处理。** 所有网格级 RCA 工作都是遥测-based。没有人把"网关返回 503 是因为上游 readiness 探针路径被改写"连接到第二个仓库里的实际代码编辑。
5. **跨仓图的陈旧性与漂移未被研究。** 每个工具都承认会陈旧，但**没有一个量化定位精度如何随索引年龄衰减**，也没人研究如何检测它。这直接可测且直接有商业价值。
6. **置信度被展示但从未被 *使用*。** 所有这些工具给边打 0.0–1.0 分，然后把一个扁平答案交给 agent。**没有人建过一个以边置信度为条件进行搜索的定位循环**，或一个低于阈值就拒绝行动的循环。
7. **覆盖率/完整性以散文形式报告，而不是 agent 可据以行动的度量。** "哪里覆盖不完整或陈旧"应该是第一等的、可查询的、机器可读的输出。

### 4.1 更广的空白（定位与修复整体）

8. **发现 ≫ 修复。** SWE-sweep 最佳 agent 4.7%；Active-SWE 20.0%。几乎全部投入都在修*已知* bug。在大仓中定位一个**未知**缺陷是未解的核心。
9. **多缺陷状态累积摧毁 agent。** ChainSWE 最多 −70%；携带原始历史≈无用，摘要与子 agent 编辑**更差**。跨缺陷流的仓库状态管理方法不存在。
10. **过度编辑不被标准指标惩罚。** PDB 的排名倒挂就是发现；该领域对调试没有公认的精度指标。
11. **没有面向有效测试的 RL 环境。** Dan Luu 的明确开放问题。
12. **诊断质量未被度量。** PDB 与 Sherlogs 都提议精度/排名指标，但几乎没工作报告 agent 对 bug 的*解释*是否正确。AetherLog 的失败分析表明这正是纯 LLM 方法崩溃之处。
13. **代码定位与运行时 RCA 两个文献尚未相遇。** 一个系统：从生产事故出发 → 路由到责任仓库 → 定位到函数 → 生成补丁 → 在预发环境验证。这不是任何人写过的论文。
14. **多语言脚手架的可复现性是一笔隐性工程税，会静默偏置结果。** Multi-SWE-bench 中 agentless / swe-agent / openhands 都需要 `mAgentLess`/`mOpenHands` fork、tree-sitter 替换、逐语言执行命令、Docker 修复。任何多语言结论都应报告适配工作量。
15. **榜单不可审计。** "解剖 SWE-bench 榜单"发现 79 个 Lite / 99 个 Verified 条目、80 种方法，**没有任何强制文档**说明结果如何获得；提交以专有 LLM 为主，且学界的中位精度**显著低于**企业（Dunn 事后检验 p = 0.00588 / 0.00313 / 0.01786）。

## 5. 对本项目的结论

1. **仓库路由是一个独立的第一阶段，不是定位的副产品。** DNext：层级 NL 摘要优于对代码做 RAG，Pass@10 0.82 / MRR 0.50，且击败 Copilot 与 Cursor 的 agentic RAG。本项目的 `repo-router` 因此只读 `topology.json` 的摘要与契约，**不 grep 代码**。
2. **路由必须按覆盖度评估，且不设 top-1。** DNext 的目录层消融代价（MRR −54%）说明层级不可省；用 Pass@3 / Recall@3 评估，因为歧义问题本就跨服务。因此 `repo-router` 的输出是**至多 5 个候选 + 显式排除理由**，不是单一答案。
3. **结构必须是契约，而不只是符号；且每条边要有证据与置信度。** SCIP 索引包归属与版本但不含 manifest；Atlas / RepoHelix / code-system-graph / grafel 因此显式建模 HTTP/事件/schema/DB/config 边，给每条边打置信度与来源，并**把缺失证据表示为一等公民**。本项目 `topology.json` 照此设计：`contracts[].evidence` + `confidence`，加上 `coverage.staleRepos` + `coverage.unknownEdges`。
4. **深度检索在关键处取胜。** CodeScaleBench：MCP 把检索 F1@10 从 0.091 提到 0.240，**同时成本降 30%**。收益在检索质量而不在 reward 数字。
5. **网关 / 路由器 / 网格是根因的合法候选，不是事后补想。** 「调用根本没到服务」这个症状，网关排在服务之前。遥测侧的全部工作都是网格/网关级的。
6. **缺失必须可见。** 因为没有公开基准覆盖契约不一致类与网关根因类，本项目不能声称在这些类别上有已验证的能力。`cross-repo-verifier` 因此把低置信与覆盖缺口一律判为 `unverified`，绝不判 `pass`。
7. **这个方向是空白，不是有解决方案。** 本项目在契约不一致与网关根因上的表现需要自建评测集来证明，不能引用任何榜单数字。

## 6. 来源

**论文 / 基准**：https://arxiv.org/abs/2603.03194（BeyondSWE / SearchSWE）· https://github.com/AweAI-Team/BeyondSWE · https://huggingface.co/datasets/AweAI-Team/BeyondSWE · https://arxiv.org/abs/2512.05908（DNext 多仓定位）· https://conf.researchr.org/details/icse-2026/llm4code-2026-papers/28/ · https://github.com/sourcegraph/CodeScaleBench/blob/public/docs/technical_reports/TECHNICAL_REPORT.md · https://arxiv.org/abs/2602.19407（Multi-CoLoR）· https://arxiv.org/abs/2509.25242（MULocBench）

**产业基础设施**：https://sourcegraph.com/blog/cross-repository-code-navigation（SCIP）· https://sourcegraph.com/blog/why-code-search-at-scale-is-essential-when-you-grow-beyond-one-repository · https://onei.ai/mcps/sourcegraph · https://sourcegraph.com/docs/deep-search · https://sourcegraph.com/docs/code-search/working/search-contexts.md · https://riftmap.dev/blog/symbol-graphs-and-artifact-graphs/（对 SCIP 的批评）· https://github.com/sourcegraph/jetbrains

**开源跨仓图工具**：https://github.com/rohanps630/Atlas · https://github.com/arnofeng/repohelix · https://github.com/dertin/code-system-graph · https://github.com/cajasmota/grafel · https://github.com/simplecore-inc/coregraph

**遥测侧 RCA**：见 [localization-and-rca.md](localization-and-rca.md) §2 与 https://challenge.aiops.cn

**榜单审计**：https://arxiv.org/abs/2506.17208