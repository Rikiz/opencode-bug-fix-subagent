# 多仓修复流程

本文是 [research/](research/) 四份调研的收敛产物：一套在 opencode v1 下可直接运行的多仓 issue→修复流程。

设计取舍全部标注依据。凡标 **[无基准]** 的，是公开文献明确空白之处——本项目在这些场景**不能声称已验证的能力**，因此把它们做成显式的人工升级点，而不是静默兜底。

---

## 0. 为什么需要单独一个"路由"阶段

「这个 bug 属于哪个仓」不是定位的副产品，它是一个独立的、第一性的问题：

- **DNext**（ICSE 2026，唯一以"哪个仓"为主任务的论文，46 仓 / 110 万行 / 真实电信工单）：**Pass@10 = 0.82，MRR = 0.50**，并且在仓库路由上**击败 Copilot 与 Cursor 的 agentic RAG**。做法是把定位重构为在**层级化上下文感知摘要**（文件 → 目录 → 仓库）上的 NL→NL 搜索，**而不是对代码做 RAG**。
- 消融掉目录层：**MRR −54%、Recall@10 −37%、prompt token +44%**。层级不可省。
- 每个 bug 平均改 **7.2 个文件**（最多 10）→ 应该取 k=10 的候选集，而不是要一个 top-1。

两条工程推论：

1. **路由阶段禁止读源码。** 那是定位阶段的事。让路由器读代码会退化成"随便找个仓 grep 一下"，而这正是 DNext 证明打不过纯摘要方案的做法。
2. **按覆盖度评估，不按 top-1。** 真实故障经常真的跨服务。候选集 + 显式排除理由才是正确输出形态。

---

## 1. 整体架构

```
                          ┌─────────────────────────────┐
   不可信 issue 单  ───▶   │  Stage 1  intake            │  归一化、写 .runs/
                          └──────────────┬──────────────┘
                                         ▼
                          ┌─────────────────────────────┐
   topology.json  ───▶     │  Stage 2  topology load     │  加载契约图 + 覆盖缺口
                          └──────────────┬──────────────┘
                                         ▼
                          ┌─────────────────────────────┐
                          │  Stage 3  repo routing      │  subagent: repo-router
                          │  症状 → 入口 → 契约 → 候选集   │  mode: subagent（不读源码）
                          └──────────────┬──────────────┘
                                         ▼  候选集（≤5）+ 排除理由
                          ┌─────────────────────────────┐
                          │  Stage 4  per-repo localize  │  subagent: repo-fixer × N
                          │  仓内层级收窄 → 最小补丁       │  mode: subagent（可改代码）
                          └──────────────┬──────────────┘
                                         ▼
                          ┌─────────────────────────────┐
                          │  Stage 5  cross-repo verify  │  subagent: cross-repo-verifier
                          │  契约一致性 / 过度编辑 / 测试完整性 │  mode: subagent（只读）
                          └──────────────┬──────────────┘
                                         ▼  PASS / PASS WITH UNVERIFIED / FAIL
                          ┌─────────────────────────────┐
                          │  Stage 6  roll-up            │  编排器汇总，人工 review
                          └─────────────────────────────┘
```

`multi-repo-orchestrator` 是 `mode: all`（要进入 task 目录才能派活），三个执行体是 `mode: subagent`。**深度只用一层**：三个 subagent 都不声明 `task` key，因此自动 deny，无法继续嵌套。

---

## 2. 逐阶段契约

### Stage 1 · intake

**输入**：issue JSON（`{issue, comments}`）
**动作**：归一化、截断、写 `.runs/<epoch-ms>-issue-<n>/prompt.txt`
**门禁**：无正向 issue 号 + 标题 → 立即失败
**退路**：issue 无可执行症状 → `ROLLUP_STATUS: no-actionable-scope`，停止

父仓 `lib/issue-context.js` 已实现这一步，本目录复用同一套截断预算（issue 24k / comment 12k 字符）。

**依据**：SWE-bench-Live 揭示静态基准掩盖的差距；Active-SWE 显示生成测试的"数量"与"有效性"错位——所以 intake 阶段就要区分"有症状描述"和"有可执行断言"。

### Stage 2 · topology load

**输入**：`topology.json`（git-ignored；`topology.example.json` 仅用于说明 schema，**绝不用于路由**）
**动作**：加载 `repos` / `contracts` / `coverage`；把 `coverage.staleRepos` 与 `coverage.unknownEdges` 抄进工作笔记
**门禁**：文件缺失 → 停止并告诉用户要建什么
**退路**：无

**依据**：SCIP 索引包归属与版本但**不含 manifest**；Atlas 把未匹配的跨仓调用做成**一等 `external` 节点**，code-system-graph 把动态路由留作**未解析证据**——都是同一个原则：缺失必须可见。`coverage` 两个字段就是本项目对此的实现。

### Stage 3 · repo routing

**输入**：归一化 issue + `repos[].{name, role, summary, provides, consumes}` + `contracts`
**执行**：`repo-router` subagent
**输出**：≤5 个候选（`rank` / `confidence` / `evidence` / `why`）+ 显式排除理由 + `COVERAGE_WARNINGS`
**门禁**：每个候选至少一条具体引用（契约边 / 日志行 / 栈帧 / 命令）。"听起来像支付团队的"不算。
**退路**：全部候选置信度低于门槛，或只由 `confidence < 0.5` 的边支撑 → **停下要证据**，不进入 Stage 4

**核心方法**（`repo-router` 提示词）：**从症状向外走层，不从猜测向内猜**。

1. 字面写下可观测现象（HTTP 400 from X / 事件 Y 从未到达 / 审计记录缺字段 Z）
2. 映射到入口点（网关路由 / 前端调用点 / 事件消费者 / 定时任务）
3. 按 `provides`/`consumes`/`contracts` 双向展开。**按症状选边类型**：`http`→路由/状态码，`event`→生产了没消费，`schema`→字段/类型/enum，`config`→环境差异
4. 选**能解释完整症状的那一层**。调用根本没到服务 → 网关优先于服务
5. **显式排除**并给理由

**要点**：**边界上的问题通常同时 implicate 生产者与消费者**。把这种问题强行收敛到单仓是本阶段最常见的失败模式。网关 / 路由 / 网格 / 基础设施故障是一等候选，不是事后补想。

**依据**：DNext（层级摘要、无代码 RAG、k=10）；BugCerberus 的消融（层级不可跳）；AetherLog 的失败诊断（纯 LLM 停在**症状**"disk not ready"，错过根因 `nvme timeout`，因为时间近因偏置）→ 所以必须先字面写下现象再解释；Sherlogs 的 originating/relaying 分类 → 网关是典型 relaying 层。

### Stage 4 · per-repo localization & repair

**输入**：**一个**仓库名 + 绝对路径 + 该仓的 `validation[]` + 与它相关的拓扑切片
**执行**：`repo-fixer` subagent，**一个仓一次调用**
**输出**：`VERDICT` ∈ `fixed | no-plausible-fault | blocked | out-of-scope` + 收窄轨迹 + diff 规模

**为什么一个仓一次调用**：ChainSWE 显示连续多缺陷处理最多退化 **70%**，且**携带原始历史≈无用、摘要与子 agent 编辑反而更差**。混仓调用还会让证据链不可读。

**强制的工作流**：
1. 复现，或找到最具体的可执行证据（栈帧 / 命名 symbol 的日志行 / 两侧都引用的 schema 不匹配）。**都不行 → `blocked`，不打补丁**
2. **逐级收窄：repo → 目录/模块 → 文件 → 类/函数 → 语句，每级先记候选集**。不得跳级
3. 优先结构（调用图、importers、符号引用）而非文本搜索
4. **下结论前查边界**：证据落在契约边上就两侧都引。边在别的仓 → 报告并停在边界，**不得出仓编辑**
5. 先说根因与最小计划，再动文件
6. 最小生产修复 + 回归测试（无修复时必须失败、有修复时必须通过）
7. 跑该仓配置的 `validation[]`（不得替换成更容易过的命令）
8. **自查 diff 规模**。远大于根因能解释的量 → 重新诊断

**禁止**：削弱/删除/跳过既有断言、放宽 lint 或类型阈值、加依赖、改 lockfile、commit/push/reset/stash、读 secrets、联网、在消费端放松校验"修复"契约不匹配（**这把响亮的失败变成静默的错值**）。

**依据**：BugCerberus（去文件级 → 语句级 Top-5 **−94.3%**；SWE-bench 项目平均 11,020 函数 / 168,721 语句，一个函数约 15 语句）；PDB（**>76% 单测通过 vs ≤45% 编辑精度，排名倒挂** → 步骤 8 自查 diff 规模是必需的，不是可选的）；SWE-PolyBench（高检索是必要非充分条件）；Thoughtworks TCR（测试失败即回滚是确定性护栏）；Carlini（"验证器必须近乎完美，否则 Claude 会去解决错误的问题"）→ 修复器**不得自评**。

### Stage 5 · cross-repo verification

**输入**：所有候选 diff + 触及被改仓库的契约边
**执行**：`cross-repo-verifier` subagent，`temperature: 0.0`，只读
**输出**：恰好一个 `VERDICT` ∈ `PASS | FAIL | PASS WITH UNVERIFIED ITEMS`

**检查项**：
1. diff 是否匹配所述根因
2. 过度编辑（文件/行数）
3. **契约一致性**：对每个被改仓库，比对两侧的 payload 字段、事件 topic 及其 schema、路由路径、config key、enum 成员。生产者改名而消费者还在读旧名 = FAIL，反之亦然
4. **缺失证据规则**：相关边 `confidence` 低、或边类别在 `unknownEdges`、或仓库在 `staleRepos` → **不能放行**，报 `unverified`。**没有矛盾 ≠ 一致，前提是证据本来就不存在**
5. 测试完整性：回归测试是否真的钉住行为；有无削弱断言、放宽容差、放松阈值
6. 验证强度：命令是否可能"没修复也能过"
7. 静默失败风险：吞异常、消费端放松校验、加 retry 掩盖真实缺陷、硬编码环境值
8. 未经验证的主张：fixer 报告里 diff 支撑不了的断言

**门禁**：`PASS` 要求无 `blocker`/`major` 且每条相关契约边 `consistent`。有任何一项只是 `unverified` → `PASS WITH UNVERIFIED ITEMS`，**由人显式接受残余风险**。

**依据**：Carlini 用 GCC 作已知良好 oracle 而**不让 Claude 自评**；Regehr 独立审计（Csmith + YARPGen 只给缩减测试用例，Codex 修好 34 个编译器 bug，15–30 分钟/个，**Codex 从来不是瓶颈**）——验证侧成熟度高于生成侧；Osmani："一个自信的'看起来不错'而其中没有任何人，是**借来的自信**"；MicroRCA-Agent（**日志+指标 51.27 优于三模态全上 50.71**）→ 加模态不等于加信息，契约检查不必穷尽所有层，但**相关层必须覆盖**。

### Stage 6 · roll-up

编排器（自身 `edit`/`write` 全 deny）汇总，不做判断。输出见 `multi-repo-orchestrator.md` 的固定契约：`ISSUE / ROUTING / COVERAGE_GAPS / PER_REPO / CROSS_REPO_VERDICT / ROLLUP_STATUS / BLOCKERS`。

**`ROLLUP_STATUS` 门禁**：以下任一成立必须是 `needs-evidence`，绝不能 `ready-for-review`：
- 路由置信度低
- 某个必需仓库不在拓扑中
- verifier 返回 FAIL
- 有 `unverified` 的相关契约边

失败重传**至多一次**。第二次失败说明诊断错了，应当上报而不是循环 —— 13Labs："在同一道门禁上失败五次的 agent 没有收敛，第六次只是花钱学到零"。

---

## 3. 证据到设计的映射总表

| 证据 | 数字 | 本设计 |
| --- | --- | --- |
| DNext（ICSE-26） | Pass@10 0.82 / MRR 0.50；去目录层 MRR −54% | Stage 3 独立成阶段；只读摘要；输出候选集 |
| 平均改 7.2 文件（最多 10） | k=10 | 候选集上限 5，评估用 Pass@3/Recall@3 |
| BugCerberus 消融 | 去文件级 → 语句级 Top-5 −94.3% | `repo-fixer` 步骤 2 逐级收窄 + 输出 `NARROWING` |
| PDB | >76% 单测 vs ≤45% 编辑精度，排名倒挂 | 步骤 8 自查 diff；verifier 的 `minimality` 字段 |
| ChainSWE | 多缺陷 −70%；摘要/子 agent 编辑更差 | 一仓一全新子会话，不共享历史 |
| SWE-bench Verified 污染 | 只给 issue 文本即 76% 定位准确率 | 路由阶段禁止读源码（避免文本捷径） |
| SWE-bench Pro | 最佳 Pass@1 43.6%，商业集 <20% | 不引用任何榜单数字承诺成功率 |
| SWE-sweep / Active-SWE | 4.7% / 20.0% | 路由按**发现问题**对待，容忍空候选集 |
| AetherLog | 纯 LLM 停在症状（F1 0.93/0.97 靠 KG 组合） | 先字面写现象；verifier 区分 originating/relaying |
| MicroRCA-Agent | 日志+指标 51.27 > 三模态 50.71 | 契约检查覆盖相关层即可，不追求穷尽 |
| OpenRCA | metric→trace→log 是正确顺序 | 需要运行时证据时按此顺序索取 |
| Sherlogs | AC@1 92.2%（区分 originating/relaying） | 网关作为 relaying 层优先排查 |
| AutoCodeRover | 采用 SBFL 排名 3、5 而非第 1 | 传统 FL 只作搜索循环中的提示，不作答案 |
| OpenHands RepoMap | 不完整索引导致过度信任 | 不预建跨仓代码索引；用拓扑 + 逐仓搜索 |
| CodeScaleBench | MCP 使 F1@10 0.091→0.240，成本 −30% | 深度检索优先于宽泛 RAG |
| Atlas / code-system-graph | 显式拒绝 embedding；缺失证据一等公民 | `topology.json` 用确定性契约边 + `coverage` 字段 |
| Carlini / Regehr | 验证器是瓶颈；finder 侧已不是 | 独立只读 verifier，禁止自评 |
| Dan Luu | Default > TDD > skills；agent 写测试"介于毫无价值与勉强有用" | 验证命令由仓库提供，不由 agent 设计 |
| Dan Luu | agent 的 bisect 不可信，需独立证伪 | verifier 不采信 fixer 的结论 |
| Fowler / Morris | shift left；on-the-loop；harness 即护栏 | 契约化输出格式即 harness |
| Thoughtworks v33 | TCR（Test && Commit \|\| Revert）| 验证失败即回滚作为外部护栏 |
| 13Labs | 单一 verify 脚本、首个失败即停、<90s、限轮数 | `validation[]` 白名单 + 至多一次重传 |

---

## 4. 运行方式

### 编排器在会话内驱动

```bash
cd /abs/path/to/one-of-the-repos
OPENCODE_CONFIG=/abs/multi-fix-oc/opencode.json \
OPENCODE_CONFIG_DIR=/abs/multi-fix-oc/.opencode \
opencode
```

然后 `@multi-repo-orchestrator <issue JSON 路径或问题描述>`。

### 单仓修复器直接驱动（CI / 逐仓修复）

```bash
OPENCODE_CONFIG=/abs/multi-fix-oc/opencode.json \
OPENCODE_CONFIG_DIR=/abs/multi-fix-oc/.opencode \
opencode run --agent repo-fixer "$(cat /abs/multi-fix-oc/.runs/<id>/repo-brief.txt)"
```

**为什么必须带 `OPENCODE_CONFIG_DIR`**：`--dir` 指向目标仓时，opencode 从该仓向上找配置，拿不到本目录的 agents。已实测 `OPENCODE_CONFIG_DIR` 优先级最高，能正确加载 `agents/` 与 `skills/`。

**为什么这样更安全**：逐仓运行让每个 fixer 的 worktree 就是它自己的仓库，天然避免 `external_directory` 授权。拓扑里的路径是运行期才知道的，而 `permission` 不支持变量插值（实测在 JSON 里写 `$HOME` 直接解析失败），所以**逐仓 `--dir` 是本设计里最干净的隔离方式**。

---

## 5. 已知限制（诚实清单）

1. **没有公开的 issue→仓库路由基准**（DNext 专有）。本设计的路由质量**无法引用任何榜单数字证明**，必须自建评测集。
2. **跨仓 patch 没有基准**。没有东西度量"同时改两个仓并更新两者间契约、测试横跨两者"的成功率。
3. **API 契约 / schema 不一致这一缺陷类别没有基准。** 这是真实世界最高频的多仓缺陷，但本项目在此类上的表现是 **[无基准]**。
4. **网关 / 服务网格 / 路由器的根因在代码修复文献中完全未被处理。** 所有网格级 RCA 都是遥测-based。因此本流程对这类故障的代码级结论是 **[无基准]**，需要人工判断。
5. **跨仓拓扑的陈旧性影响未被量化。** 本项目用 `coverage.indexedAt` + `staleRepos` 显式记录，但没有量化"精度随索引年龄如何衰减"——**[无基准]**，需要自建实验。
6. **置信度被记录但未用于门控搜索**。`confidence` 目前只影响措辞（"不能在此之上建立结论"），没有做到"低于阈值就拒绝行动"的硬门控。这是已知缺口。
7. **发现能力弱于修复能力。** SWE-sweep 4.7%、Active-SWE 20.0%。本流程的 Stage 3 在**给定一张拓扑**的前提下工作；它不解决"拓扑里根本没有相关仓库"的情况——那会退化为 `needs-evidence`，交人工。
8. **opencode 版本敏感。** 本机 CLI 1.17.7 **不支持** `subagent_depth`（写入会报 `Configuration is invalid` 并拒绝加载），因此 `opencode.json` 里**不含**该键，深度 1 靠三个 subagent 都不声明 `task` 来保证。新增任何配置项前先确认 CLI 版本。
9. **frontmatter 重复 key 会让 agent 静默消失。** `repo-fixer.md` 最初因 `lsp` 写了两次而从 `opencode agent list` 中消失且无报错。**建议把 YAML 解析作为 CI 门禁。**
10. **本文档不含可执行编排器。** 流程由 agents + skills 驱动，`bin/` 与 `lib/` 未实现；`bug-fix` / `bug-fix-verifier` 与本目录并列，互不影响。

---

## 6. 引用

完整论文、方法论与全部来源见 [research/](research/)：

- [research/benchmarks.md](research/benchmarks.md) — 基准数据集与污染证据
- [research/localization-and-rca.md](research/localization-and-rca.md) — LLM 定位、日志/链路根因、多缺陷
- [research/multi-repo-and-microservices.md](research/multi-repo-and-microservices.md) — 多仓路由、跨仓工具、**与空白清单**
- [research/practitioner-methodology.md](research/practitioner-methodology.md) — 实践者方法论与 14 条可迁移原则

opencode 机制依据见 [opencode-agents-reference.md](opencode-agents-reference.md)。