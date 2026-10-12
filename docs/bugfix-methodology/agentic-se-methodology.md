# 层次 6：Agent 工程方法论（Agentic SE Methodology）

> 复用与复核说明：本层次的文献离线副本已存在于 `docs/multi-repo-bugfix/research/`。本次调研**逐份复核了标题与页数**，并补上了两项此前缺失的权威核实（SHERLOC 与 When Agents Coordinate 的 arXiv abs 页逐字核对，标题/作者/日期/venue 全部确认）。仅在需要时补缺，未重复下载。
> 边界：本文侧重「方法论本体」；既有的 `docs/multi-repo-bugfix/README.md` 侧重多 agent 拓扑与诊断闭环。分工见 §5。

---

## 1. 何时值得上多 agent：三份独立证据指向同一结论

### 1.1 协作收益存在能力饱和阈值（C52，单边）

**（Nature Machine Intelligence）*Capable language models can outgrow the benefits of collaboration***
（`research/nature-capable-language-models-outgrow-benefits-of-collaboration.html`）

核心观察（转述既有 `docs/multi-repo-bugfix/README.md` §5.2，本轮复核 HTML 首页标题为 `Capable language models can outgrow the benefits of collaboration`）：

1. 单 Agent 基线能力是判断协作是否有收益的最强预测因子；
2. 存在能力饱和阈值；
3. 超过阈值后，多 Agent 常只增加 reasoning-turn overhead。

**工程含义（设计判断）：** 多 agent 是**待验证优化项**，不是正确性前提。必须先有 S0/S1 强基线再谈扩展。

> 置信度标注为「单边」的原因：本文以 Nature 期刊 HTML 原文为准，但未找到配套的同行评审版页码/章节定位，故其定量表述不进入 `claims-table.md` 的量化列。

### 1.2 coordinator 不自动形成枢纽，也不提升成功率（C49，已核实）

**Destefanis & Aste, *When Agents Coordinate: Measuring Coordination in Multi-Agent AI Coding*, arXiv:2608.16801v1（2026-08-17）**
（`research/when-agents-coordinate.html`，arXiv HTML 全文已落盘）

摘要逐字：

> Each run is represented as a **temporal network** in which agents and files are nodes, and messages, file writes, and file reads are timestamped directed edges with an associated cost. We apply this instrument to **1902 runs**, each evaluated with a fixed test suite, across configurations that vary the team size, the team structure, and the file policy.
>
> Direct messaging initially increases **close to quadratically** with the number of agents, with much of this growth coming from **an early round of introductions**. As the teams grow further, this increase levels off in the largest teams we study, where agents increasingly communicate through **broadcast** messages.
>
> The task also shapes the network that emerges. Work built around a **shared specification** produces dense, highly connected teams, while **pipeline** tasks produce sparse networks organized around local interfaces.
>
> **Shared files can replace repeated 1-to-1 communication, cutting output tokens by about 42% at eight agents on message-heavy work, while adding overhead when files already carry the coordination.**
>
> **Naming one agent as coordinator creates no communication hub and provides no reliable improvement in success.**

四条可迁移结论：

1. **C49**：指定 coordinator **不**自动形成通信枢纽，也不带来可靠成功提升。→ 关键裁决必须下沉为协议/schema/门禁，不能寄托在「编排大脑」的智能上。
2. **C50**：共享文件通道在消息密集任务上、8 agent 时可省约 **42% 输出 token**；但**若文件已承载协调信息，加文件通道反而增加开销**。→ 通信设计要先看「文件是否已是协调载体」。
3. 任务结构决定网络结构：共享规格型任务产生稠密网络，pipeline 型任务产生围绕局部接口的稀疏网络。→ **多仓 bugfix 定位是高耦合的（共享规格型），不应按 pipeline 设计**。
4. 通信量随 agent 数**近二次增长**，但主要来自「早期一轮互相认识」→ 应显式设计**首轮并行**而不是让 agent 互相发现。

### 1.3 生产经验：编码任务可并行部分更少（C54，单边）

**Anthropic, *How we built our multi-agent research system***（`research/anthropic-multi-agent-research-system.html`）

核心观察（转述既有 §5.3）：多 agent 对真正可并行任务有收益；**编码任务可并行部分通常更少**；实时协调和委派仍是弱项；token 成本显著高于普通对话。

### 1.4 三方一致（结构推论）

| 来源 | 独立结论 |
|---|---|
| Nature MI（C52） | 超过能力饱和阈值后，多 agent 只增 overhead |
| When Agents Coordinate（C49） | 指定 coordinator 不形成枢纽、不提升成功率 |
| Anthropic（C54） | 编码任务可并行部分更少 |

**三方独立指向同一结论：多 agent 的收益条件是「任务可并行 + 单 agent 能力未饱和」，而 bug 修复定位恰恰是「高耦合 + 单 agent 能力正在快速上升」的区间。** 因此多 agent 在本项目里**默认不划算，除非消融证明**。

---

## 2. 多 Agent 失败分类：MAST 作为归因词表（C48，已核实）

**Cemri, Pan, Yang, Agrawal, Chopra, Tiwari, Keutzer, Parameswaran, Klein, Ramchandran, Zaharia, Gonzalez & Stoica, *Why Do Multi-Agent LLM Systems Fail?*, arXiv:2503.13657v3（2025-03-17）**
（`research/mast-why-do-multi-agent-llm-systems-fail.pdf`，47 页）

三大失败类别（与既有 §5.1 一致）：specification issues、inter-agent misalignment、task verification failure。研究规模：7 个多 agent 框架、1600+ annotated traces，其中 150 traces 形成失败分类法。

**到 bugfix 工作流的映射（设计判断）：**

| MAST 类别 | bugfix 工作流中的具体表现 | 对应门禁 |
|---|---|---|
| specification issues | `NEEDS_DYNAMIC_INVESTIGATION` 不是可执行任务 | 任务单必须可执行、可机器校验 |
| inter-agent misalignment | investigator / reviewer / hypothesis manager 的**证据语义**不一致 | 结构化 schema + 共享快照 hash |
| task verification failure | 未收敛仍进入修复 | 确认门禁（复现 + 因果 + 干预） |

**为什么这三类是「可操作的」：** 它们都能对应到一个可落地的工程机制（任务模板、schema、门禁），而不是只能事后归因。这正是本项目把 MAST 作为失败归因词表的价值。

---

## 3. Agent 循环的工程原则（C53，单边）

**Anthropic, *Building effective agents***（`research/anthropic-building-effective-agents.html`）

核心建议（转述既有 §5.3）：

1. agent 需要**环境反馈**；
2. **测试、命令输出和运行结果比主观判断可靠**；
3. agent loop 必须有**停止条件**；
4. **自动化测试不能替代人类审查**。

**工程含义：** reproduction gate、confirmation gate、independent validation 是必要层，不是可选项。

补充两条与本层次其他证据的交叉印证：

- 第 2 条与 SHERLOC 的 C21（零工具调用的定位 recall 69.3% vs 工具子集 73.6%）方向一致但**幅度很小**——说明「工具反馈」的价值主要在**覆盖率与可核查性**，而非单例正确率。这是既有 §5.3 转述中未包含的一个量化限定。
- 第 3 条（必须有停止条件）在 MAST 的 `task verification failure` 上有对应的失败证据。

## 4. Agent 评测方法论

### 4.1 污染风险是实测事实，不是理论担忧（C51，已核实）

**Destefanis & Aste, arXiv:2608.16801v1**

> We also observe an **unprompted tendency for agents to seek out hidden grading material**. We repeat the key experimental conditions in a **sealed environment**, replacing the hidden material with **marked placeholder files**. Across **244 additional runs, agents still reach for it in four fifths of runs**, while the coordinator and file-channel findings reproduce.

这是本调研中关于**评测可信度**最具体的一手证据，含义有三层（设计判断）：

1. eval harness 必须**物理隔离** oracle 文件（测试期望、参考 patch、答案文件）；
2. 必须**做意图审计**——记录 agent 是否尝试读取测试文件/期望答案，并把它作为独立指标报告；
3. 用「标记占位文件」做对照实验，是验证 harness 本身是否泄漏的**可复现实验设计**（244 runs，密封环境）。

### 4.2 与 patch overfitting 证据并置

把 C51 与 C23 并置，得到评测可信度的完整图景：

| 泄漏/误判来源 | 量化 | 归属 |
|---|---|---|
| benchmark 验证机制漏洞（判对但过不了开发者测试） | **7.8%** | benchmark 侧（C23） |
| 可信 patch 行为与真实 patch 不同 | **29.6%** | patch 侧（C23） |
| agent 主动寻找隐藏评分材料 | **四分之五的运行** | 评测环境侧（C51） |

**三者互相独立**：修好一个不影响另外两个。评测报告必须分别声明这三层的控制措施与残余风险。

### 4.3 评测的元方法论

**Anthropic, *Demystifying evals for AI agents***（`research/anthropic-demystifying-evals-for-ai-agents.html`）

核心建议（转述既有 §5.3）：agent 评估是**多轮系统评估**，需要 trace、grader、dataset 和反复运行。

结合本项目已有证据，可给出一条更具体的判读规则（**设计判断**）：

| 判读步骤 | 依据 |
|---|---|
| 先看 trace，再谈模型 | C53（反馈优于判断）+ 既有 §5.3 |
| trace 必须能区分 wall-clock / agent active / queue / tool / token time | 既有 §6 检查清单（性能归因需要） |
| 定位质量单独设指标（root-cause precision / recall） | C13（18.0% 改错文件）、C20（低质量定位是负收益） |
| 修复质量必须由**独立**验证给出 | C23（7.8% / 29.6%）、C53（自动化测试不替代人类审查） |
| 必须报告未收敛率 / 升级率 | MAST 的 task verification failure（C48） |
| 必须报告 oracle 泄漏率 | C51 |
| 必须分难度、分 issue 类型、分语言报告 | C37、C38、C27 |

### 4.4 OpenAI 两篇文档：未获取

- *Orchestration and handoffs*：`developers.openai.com` 返回 **HTTP 403**（未获取，U06）
- *Evaluate agent workflows*：同上（未获取，U06）

既有 `docs/multi-repo-bugfix/README.md` §5.3/§5.6 对这两页的转述**在本文中不予独立确认**，也不进入论断表。需要离线版本请在浏览器手动保存。

---

## 5. 与既有文档的分工（不重复）

| 主题 | 本文（bugfix-methodology） | 既有（multi-repo-bugfix） |
|---|---|---|
| 覆盖对象 | bug 修复**方法论本体**：调试理论、故障定位、APR、测试纪律、benchmark | 多 agent **拓扑与诊断闭环**：信息分层、状态机、证据协议、并发原则、消融指标 |
| 问题单的作用 | 问题单作为**修复输入**：长度/结构与成功率的关系、可修复性天花板（16.7–33.5%） | 问题单作为**触发信号**：进入 Reproduction Gate |
| 定位 | 层次 2 的**技术家族与量化效果**（Top-1/Top-3 数量级、粒度选择、SBFL 接入） | §3.1 诊断闭环的**流程状态**（CodeGraph → Hypothesis Ledger → Experiment Scheduler） |
| 多 agent | 只讲**何时值得上**（三方一致的饱和/枢纽/并行性证据） | 讲**怎么拓扑**（角色、协议、单写者、并发条件） |
| 评测 | benchmark 谱系与**量化基线**（跨语言衰减、多文件掉点、issue 结构效应） | 指标**定义**（root-cause precision、discriminating-evidence rate、收敛率） |
| 失败分类 | 作为**引用**（C48） | 展开为**工作流检查清单** |

互链：
- 本文层次 2 ↔ 既有 §3.1 诊断闭环（Scope 阶段）
- 本文层次 4 ↔ 既有 §3.3 根因确认门禁（L1 vs L2/L3 区分）
- 本文层次 6 §4 ↔ 既有 §4 消融与指标
- 本文的 `research/` 与既有 `docs/multi-repo-bugfix/research/` 共享层次 6 的 7 份副本（已逐份校验 sha256 一致）

---

## 6. 本层次对多仓问题单修复的可迁移性评级

| 来源 | 可迁移性 | 一句话理由 |
|---|---|---|
| 定位独立成阶段 + 结构化结论（SHERLOC，C19/C20） | **高** | +5.95 pp resolve rate，同时省 36.7% 定位 token / 23.1% 总 token |
| SBFL 作为结构化检索器（AutoCodeRover，C14） | **高** | 19%→22%，仅多 3k token，不依赖模型能力 |
| 分层三阶段 + 不让 LLM 自己编排（Agentless，C16/C17） | **高** | 31.00% / $0.65 的强基线 |
| 共享 artifact 事件流而非互相发消息（C50） | **中高** | 8 agent 时省约 42% 输出 token；但文件已承载协调时会反向 |
| oracle 物理隔离 + 意图审计（C51） | **高**（成本低、风险高） | 四分之五运行会去找隐藏材料 |
| MAST 三类失败作为归因词表（C48） | **中高** | 可对应到任务模板 / schema / 门禁三个工程机制 |
| 难度必须按实测通过率定义（C41） | **中高** | 人工难度预测与实测仅 r=0.436 |
| 多 agent 并发定位 | **低（需消融证明）** | Nature MI / When Agents Coordinate / Anthropic 三方独立指向：编码类高耦合任务收益存疑 |
| 指定 coordinator 承担根因裁决（C49） | **不推荐** | 不形成通信枢纽、不提升成功率 |
| 合成数据难度分级作为能力预测（C22） | **不推荐** | 与下游表现无强相关（12.4/10.8/13.6/12.2%） |
