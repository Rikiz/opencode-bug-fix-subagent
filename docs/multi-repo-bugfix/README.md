# 多仓 Bugfix Agent 方法论与参照体系

> 版本：2026-09-29  
> 目标：提供一套不依赖 webfetch 也能复用的多仓 bugfix agent 分析方法。  
> 证据边界：本文区分观测事实、结构推论、设计判断和待验证假设；不把研究结论当成对某个具体系统故障的直接证明。

## 1. 核心原则

一个 bugfix agent 系统首先是一个控制系统和一个实验系统，其次才是多 Agent 拓扑。

定位的目标不是“产出更多调查报告”，而是持续减少根因不确定性。判断一个循环是否有效，看它是否具备以下能力：

1. **复现**：固定失败命令、环境、版本和期望错误。
2. **假设**：把根因转成可观察、可反驳的候选假设。
3. **区分实验**：每个实验必须能区分至少两个仍存活的假设。
4. **证据校验**：命令、观测、artifact、版本可机器验证。
5. **确认门禁**：现象复现、因果证据、干预验证三者同时成立。
6. **独立验证**：修复不能由生成者自证通过。

缺少其中任何一项，系统都可能表现为：耗时持续增长、报告持续产生、结论不收敛。

## 2. 分析框架

### 2.1 四类信息分层

分析 agent workflow 时，先不要解释原因，先把信息分层：

| 层级 | 含义 | 合法结论 |
|---|---|---|
| 观测事实 | 输入或 trace 中明确记录 | 可以直接陈述 |
| 结构推论 | 由架构定义必然推出 | 可以严谨推导 |
| 设计判断 | 基于工程原则的选择 | 需说明权衡 |
| 待验证假设 | 有可能但无证据 | 只能列为待验证 |

常见错误是把“可能风险”当成“已发生故障”，或者把“模型可能幻觉”当成具体失败原因。没有 trace，就不应对模型行为、prompt 质量、工具故障或单个 Agent 的判断质量作断言。

### 2.2 状态机检查

把 workflow 还原为状态机，而不是先看角色分工。

对每个阶段回答：

1. 进入条件是什么？
2. 退出条件是什么？
3. 什么情况下必须停止？
4. 什么情况下必须升级人工？
5. 什么情况下禁止进入下游？

一个定位流程至少应有这些终态：

```text
CONFIRMED
UNRESOLVED
ESCALATED
REPRODUCTION_UNAVAILABLE
BUDGET_EXHAUSTED
```

如果只有 `CONFIRMED` 和 `NEEDS_MORE_INVESTIGATION`，系统就会用固定轮数、继续调查或默认下游步骤来伪装成收敛。

### 2.3 信息增益检查

每轮调查前必须回答：

1. 这轮要区分哪两个假设？
2. 每个假设的可观察预测是什么？
3. 什么结果支持它？
4. 什么结果反驳它？
5. 实验命令是什么？
6. 环境和 revision 是否固定？
7. 与上一轮实验有什么不同？
8. artifact 如何保存和校验？

如果这些问题没有答案，该轮任务不是实验，而是重复调查。重复调查可以增加 token 和时间，但不必然减少不确定性。

### 2.4 关键路径重算

不要直接相信汇总时间。按依赖关系重算关键路径。

至少区分：

| 时间口径 | 含义 |
|---|---|
| wall-clock | 用户等待的客观时间 |
| agent active time | Agent 正在推理或执行的时间 |
| queue time | 任务等待被调度的时间 |
| tool time | 命令、测试、浏览器、trace 等工具时间 |
| token time | 生成 token 引入的延迟 |
| critical path | 串行依赖上的最短完成时间 |

如果多个总数互相矛盾，说明时间口径混乱。此时不能把性能问题归因于模型、工具、队列或上下文膨胀。

### 2.5 瓶颈定位

找出关键路径上最贵的节点，再问它为什么贵。

例如 reviewer 单步耗时超过 investigator，通常说明 reviewer 被迫承担了：

1. 从自由文本提取证据；
2. 解析冲突；
3. 比较假设；
4. 设计补证；
5. 做出 verdict。

这五件事压在一个长回合里，说明证据结构化不足，而不是 reviewer 数量不足。

### 2.6 状态所有权检查

对共享状态回答：

1. 谁写？
2. 谁读？
3. 是否有版本号？
4. 是否有快照 hash？
5. 是否 append-only？
6. 是否能回放决策？
7. 是否存在旁路写？

多写者和 P2P 旁路并不必然产生故障，但没有单写者、版本和事件日志时，无法证明每次决策都基于同一证据快照。

## 3. 推荐架构

### 3.1 诊断闭环

```text
Issue / Logs
  ↓
Reproduction Gate
  固定失败命令 + 环境 + 期望错误
  ↓
Scope
  CodeGraph / 调用链 / 变更历史 / 多仓边界
  ↓
Hypothesis Ledger
  H1, H2, H3...
  每条假设有 prediction + falsifier
  ↓
Experiment Scheduler
  选择最小区分实验
  ↓
Bounded Investigator
  执行一个具体实验，不做开放式调查
  ↓
Evidence Verifier
  schema + artifact hash + 可复现性 + 冲突检查
  ↓
Confirmation Gate
  现象复现 + 因果证据 + 干预验证
  ↓
Repair
  patch 声明满足哪个根因预测
  ↓
Independent Validation
  原始复现 + 回归测试 + 独立 diff 审查
```

### 3.2 结构化证据事件

自由 Markdown 只适合人读，不适合作为机器决策输入。每个 investigation 应输出结构化事件：

```json
{
  "case_id": "CASE-123",
  "hypothesis_id": "H-03",
  "claim": "WebView 初始化时读取了过期配置",
  "prediction": "在复现步骤 S 中，配置读取发生在刷新事件之前",
  "method": {
    "command": "node scripts/repro-webview.js",
    "environment": "commit-sha + container digest"
  },
  "observation": {
    "trace_ref": "sha256:...",
    "summary": "配置读取发生于 refresh 前 42ms"
  },
  "supports": ["H-03"],
  "contradicts": ["H-01"],
  "falsifier": "如果配置读取发生在刷新事件之后，则拒绝 H-03",
  "reproducible": true,
  "next_experiment": null
}
```

Evidence verifier 应拒绝：

1. 只有 confidence，没有 observation；
2. 没有命令或环境；
3. 不区分任何假设；
4. 重复上一轮证据；
5. artifact 缺失或 hash 不匹配。

### 3.3 根因确认门禁

`confirmed_root_cause` 不能由 reviewer 文字判断直接产生。至少需要三个条件：

1. **现象可复现**：固定 revision 和环境下，原始失败稳定复现。
2. **因果证据成立**：观测满足某个假设的 prediction，并排除至少一个强竞争候选。
3. **干预可验证**：最小 patch、开关或实验性修改按预测改变失败现象。

三者任一不满足，状态只能是 `UNRESOLVED`、`ESCALATED` 或继续一个明确的区分实验，不能进入修复。

### 3.4 单写者与事件流

把共享 belief state 拆为：

| 文件 | 职责 | 写入者 |
|---|---|---|
| `case.json` | 状态机、预算、当前决策 | case-controller 单写 |
| `evidence.ndjson` | append-only 证据事件 | 证据校验器追加 |
| `hypotheses.json` | 从事件流物化 | case-controller 生成 |
| `decision.json` | continue / confirm / escalate 决策与输入快照 hash | case-controller 单写 |

P2P 通信可以保留，但只能产生“补证请求 / 答复事件”，不能直接修改假设权重，也不能绕过确认门禁。

### 3.5 并发原则

默认采用一个 case owner + 受限工具专家。只在满足以下条件时并发：

1. 实验彼此独立；
2. 不共享可变环境；
3. 输出可以用 schema 合并；
4. 每个实验能排除不同候选；
5. 协调成本小于并行收益。

定位是高耦合因果推断任务，不是天然可并行任务。不要用“更多 Agent”解决协议缺失。

## 4. 消融与验收

### 4.1 架构消融

在冻结 case 集上比较：

| 配置 | 说明 | 目的 |
|---|---|---|
| S0 | 单 Agent 定位 → 修复 → 验证 | 成本和成功率基线 |
| S1 | 单 case owner + 结构化证据协议 | 判断协议本身收益 |
| M1 | S1 + 独立实验并发 | 判断受限并发收益 |
| M2 | 当前 reviewer + P2P + 多轮模式 | 遗留对照 |

多 Agent 是否值得保留，必须由数据回答，而不是由架构偏好回答。

### 4.2 指标

| 维度 | 指标 | 防止的假象 |
|---|---|---|
| 定位质量 | root-cause precision / recall | 报告像答案被当成定位成功 |
| 诊断质量 | discriminating-evidence rate | 重复搜集同类证据 |
| 修复质量 | independent validation pass rate | 自己给自己判通过 |
| 效率 | time-to-first-repro、time-to-confirm、p50/p95 wall-clock | 只看 Agent 工时 |
| 资源 | cost per validated resolution | 用任务数稀释失败成本 |
| 收敛 | unresolved / escalated rate | 用固定轮数掩盖不确定性 |
| 可靠性 | state conflict rate、missing artifact rate | 控制面故障不可见 |

## 5. 参照资料

### 5.1 多 Agent 失败模式

**Why Do Multi-Agent LLM Systems Fail? / MAST**  
链接：https://arxiv.org/html/2503.13657v2  

研究分析了 7 个多 Agent 框架、1600+ annotated traces，其中 150 traces 形成失败分类法。核心结论是多 Agent 失败集中在：

1. specification issues；
2. inter-agent misalignment；
3. task verification failure。

与 bugfix 工作流的对应关系：

| 研究类别 | bugfix 工作流中的表现 |
|---|---|
| Specification issues | `NEEDS_DYNAMIC_INVESTIGATION` 不是可执行任务 |
| Inter-agent misalignment | investigator、reviewer、hypothesis manager 的证据语义不一致 |
| Task verification failure | 未收敛仍进入修复 |

### 5.2 多 Agent 与单 Agent 的收益边界

**Capable language models can outgrow the benefits of collaboration**  
链接：https://www.nature.com/articles/s42256-026-01268-y  

控制实验显示：

1. 单 Agent 基线能力是判断协作是否有收益的最强预测因子；
2. 存在能力饱和阈值；
3. 超过阈值后，多 Agent 常只增加 reasoning-turn overhead。

工程含义：多 Agent 是待验证优化，不是正确性前提。

### 5.3 生产编排经验

**Anthropic: How we built our multi-agent research system**  
链接：https://www.anthropic.com/engineering/multi-agent-research-system  

核心观察：

1. 多 Agent 对真正可并行任务有收益；
2. 编码任务可并行部分通常更少；
3. 实时协调和委派仍是弱项；
4. 多 Agent 系统 token 成本显著高于普通聊天。

工程含义：并发只用于独立实验和独立环境，不用于高耦合根因裁决。

**OpenAI: Orchestration and handoffs**  
链接：https://developers.openai.com/api/docs/guides/agents/orchestration  

核心建议：

1. specialist 只有在能力隔离、策略隔离、提示清晰度或 trace 可读性上有实质收益才值得增加；
2. manager 保留最终所有权；
3. specialist 更适合作为受限能力调用。

工程含义：case owner 保留裁决权，investigator 是有预算、有 schema 的工具专家。

**Anthropic: Building Effective AI Agents**  
链接：https://www.anthropic.com/engineering/building-effective-agents  

核心建议：

1. agent 需要环境反馈；
2. 测试、命令输出和运行结果比主观判断可靠；
3. agent loop 必须有停止条件；
4. 自动化测试不能替代人类审查。

工程含义：reproduction gate、confirmation gate 和 independent validation 是必要层。

### 5.4 软件工程 Agent 基线

**SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering**  
链接：https://arxiv.org/abs/2405.15793  

核心结论：

1. agent 效果高度依赖 agent-computer interface；
2. 搜索、导航、编辑、测试接口的设计会显著影响结果；
3. 普通 shell 的 `cd/ls/cat` 探索效率低。

工程含义：investigator 需要 CodeGraph、调用链、trace、最小复现工具，而不是自由读文件。

**Agentless: Demystifying LLM-based Software Engineering Agents**  
链接：https://arxiv.org/abs/2407.01489  

核心结论：

1. “定位 → 修复 → patch 验证”的简单分层流程是强基线；
2. 多 Agent 不一定优于结构化单 Agent；
3. 复杂编排必须通过消融证明收益。

工程含义：S0/S1 是判断复杂架构是否值得的最低基线。

### 5.5 定位专题

**SHERLOC**  
链接：https://arxiv.org/pdf/2606.24820v1  

核心结论：

1. coding agent 常把大量预算花在编辑前定位；
2. 结构化假设探索和紧凑仓库工具能提升定位效率；
3. 可复用诊断发现能提升后续修复效果。

工程含义：从开放式调查改为结构化假设探索，是 Phase 3 的关键升级方向。

**When Agents Coordinate**  
链接：https://arxiv.org/html/2608.16801v1  

核心结论：

1. 指定 coordinator 不自动形成有效通信枢纽；
2. coordinator 不必然提高成功率；
3. 共享文件通道在消息密集任务中可降低输出 token。

工程含义：把关键控制逻辑下沉为协议、schema 和 gate，而不是继续扩大 coordinator 的编排智能。

### 5.6 评测可靠性

**Are “Solved Issues” in SWE-bench Really Solved Correctly?**  
链接：https://arxiv.org/abs/2503.15223  

核心结论：

1. 部分 benchmark 判为成功的 patch 无法通过开发者测试；
2. 单一自动评测不能作为根因确认证据。

工程含义：确认门禁需要复现、因果和干预三类证据。

**OpenAI: Evaluate agent workflows**  
链接：https://developers.openai.com/api/docs/guides/agent-evals  

核心建议：

1. 先看 trace，再谈模型；
2. trace 覆盖模型、工具、guardrail、handoff；
3. workflow 评估需要 grader 和 dataset。

**Anthropic: Demystifying evals for AI agents**  
链接：https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents  

核心建议：agent 评估是多轮系统评估，需要 trace、grader、dataset 和反复运行。

## 6. 最小检查清单

| 检查项 | 问题 | 不通过的含义 |
|---|---|---|
| Reproduction | 有固定失败命令和环境吗？ | 没有 oracle，定位会漂移 |
| Stopping | 有 `UNRESOLVED` / `ESCALATED` 吗？ | 固定轮次会伪装成确认 |
| Hypothesis | 每个假设有 prediction 和 falsifier 吗？ | 无法做因果推断 |
| Experiment | 每轮能区分至少两个假设吗？ | 只是重复调查 |
| Evidence | 有 command、observation、artifact hash 吗？ | 无法验证证据 |
| State | 有单一写入者和版本吗？ | 决策不可回放 |
| Trace | 能区分 wall-clock / active / queue / tool 吗？ | 性能归因不可信 |
| Reviewer | 是否成为关键路径瓶颈？ | 证据结构化不足 |
| Concurrency | 并行任务是否独立且可合并？ | 可能增加协调成本 |
| Validation | 是否独立验证 patch？ | 可能自证通过 |
| Ablation | 多 Agent 是否优于单 Agent？ | 复杂度未证明 |

## 7. 快速阅读顺序

如果时间有限，建议按以下顺序阅读：

1. MAST：建立失败分类语言。
2. Anthropic multi-agent research system：理解什么时候并行有价值。
3. SWE-agent：理解工具接口为什么比 prompt 重要。
4. Agentless：建立单 Agent / 分层强基线。
5. SHERLOC：理解结构化定位协议。
6. OpenAI orchestration / evals：理解编排和评估原则。

如果只能读一篇，优先读 MAST。

## 8. 使用本文的方式

本文不替代具体 trace 分析。正确用法是：

1. 先用第 2 节检查现有 workflow；
2. 用第 3 节设计控制面和证据面；
3. 用第 4 节建立消融和指标；
4. 用第 5 节对照外部研究，但不能把研究结论当成自己系统的故障证据；
5. 用第 6 节作为每次架构评审的 checklist。

一句话总结：

> 多仓 bugfix agent 的核心不是更多 Agent，而是一个可复现、可证伪、可区分假设、可验证干预的诊断协议。
