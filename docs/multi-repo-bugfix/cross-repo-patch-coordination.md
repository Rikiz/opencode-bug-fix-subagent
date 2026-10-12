# 多仓补丁协同、版本偏斜与发布顺序

> 每条结论标注出处类型：**〔论文〕**（已核实一手来源）／**〔规范〕**（官方文档，已抓取）/**〔工程惯例〕**（行业通行做法，标注为惯例而非规范）。
> 未核实的一律写【未核实】。

## 1. 单仓 atomic 提交 vs 拆成多个仓 PR

### 权衡

| 方案 | 优点 | 代价 | 出处 |
|---|---|---|---|
| **拆成多个仓独立 PR** | 每个仓可独立评审、独立测试、独立回滚；不阻塞其他仓的无关改动；符合 polyrepo 的 CODEOWNERS 边界 | **没有原子性**：中间态必然存在；跨仓集成只能在全部合并后才可验证；发布顺序成为新的正确性风险 | 〔工程惯例〕＋见下方 BeyondSWE 的多文件实证 |
| **单仓 atomic 提交** | 天然原子，一次评审看到全貌 | 只有在 monorepo 内可行；polyrepo 下无法表达 | 〔工程惯例〕 |

### 量化依据

- Multi-SWE-bench（NeurIPS 2025 D&B 版，Tab. 4 / Fig. 3）：**修改文件数增加时 resolved rate 显著下降**，三种框架均如此；论文称之为 "Cross-file fix patches lead to reduced effectiveness"，并指出跨文件修复 "may demand more intricate handling or coordination between different parts of the repository"〔论文，已核实〕。
  → **含义**：多仓拆分不是纯粹的流程偏好，它把"一次原子评审"变成"多次协调 + 中间态"。agent 在跨文件/跨仓场景下的能力已经显著下降，人工流程必须补上 agent 补不上的部分：**中间的契约兼容状态必须被显式验证，而不是靠最后一次性联调发现**。
- BeyondSWE（arXiv 2603.03194，§1）：500 实例的目标解平均 **10.9 文件 / 1039.6 行**；其 **DepMigrate** 子集专门评估 "repository-wide coordination under breaking changes in upstream dependencies"〔论文，已核实〕。
  → **含义**：上游破坏性变更引发的下游协同改造是一个已被独立立类的任务型，不应塞进单仓 PR 的评审模板。

### 推荐做法

**contract-first + 分层合并**：把"契约变更"与"实现变更"分成两类 PR，先合契约（并让所有消费方的 CI 跑过契约校验），再合实现。所有仓的 PR 互相引用同一个 issue / 变更单，避免"谁也不知道还有谁在改"的经典失败。

---

## 2. 版本偏斜（version skew）处理

### 契约兼容检测工具

| 工具 | 检测什么 | 出处 |
|---|---|---|
| **buf breaking** | protobuf 的 FILE / PACKAGE 级破坏性变更；规则与类别可在 `buf.yaml` 声明；`buf breaking` 对比两个 image | 〔规范〕`buf.build/docs/breaking/`（已抓取 `buf-breaking-docs.html`） |
| **japicmp** | JVM 字节码 / API 兼容性对比，产出不兼容变更清单 | 〔规范〕`github.com/siom79/japicmp`（Apache-2.0，最近 push 2026-10-03，781 stars；README 已抓取 `japicmp-readme.md`） |
| **Pact**（pact-jvm） | **消费者驱动的契约测试**：消费方声明期望，提供方在 CI 中回放验证 | 〔规范〕`github.com/pact-foundation/pact-jvm`（Apache-2.0，最近 push 2026-09-25，1147 stars；README 已抓取） |
| **OpenAPI diff** | OpenAPI 规范差异 | 【本轮未单独核实工具仓库状态】 |

### expand-contract 与向后兼容迁移

两阶段改法（**expand → migrate → contract**）是处理破坏性变更的标准模式：

1. **Expand**：先加新字段 / 新接口，**不删旧的**。新旧并存。
2. **Migrate**：消费方切换到新接口；此处允许 N 个版本的窗口期。
3. **Contract**：确认所有消费方已切换后，才删除旧字段 / 旧接口。

关键点：**"何时可以 contract"是一个可判定的问题，不是一个时间问题。** 判据必须是"全量消费方扫描结果为空"，而不是"过了两周"。若无法扫描（例如存在 SDK 用户），则 contract 无限期延后，或用 major version bump + 明确的 deprecation 日程替代。

〔工程惯例〕。与之配套的观测手段是 OpenTelemetry：契约窗口期内应当监控**新旧字段的实际使用分布**，contract 决策以 telemetry 数据为准，而不是以声明为准。

---

## 3. 破坏性变更的爆炸半径计算

### 三种可用的计算手段

| 手段 | 输入 | 输出 | 出处 |
|---|---|---|---|
| **代码图谱 blast radius** | 符号图 + 改动 | 受影响符号与执行流（按 depth 分组、附置信度） | 〔规范〕GitNexus 的 `impact`（"Blast radius analysis with depth grouping and confidence"）与 `detect_changes`（"Git-diff impact — maps changed lines to affected processes"）；`api_impact` 是"Pre-change impact report for an API route handler"（GitNexus README，已抓取 `gitnexus-readme.md`） |
| **跨仓 blast radius** | 仓组 + 符号 | 跨仓受影响范围 | 〔规范〕`gitnexus group impact <name> --target <symbol> --repo <groupPath>`（GitNexus README 的 Repository groups 一节） |
| **构建系统的 affected targets** | git diff + 构建图 | 需重跑的目标集合 | 〔规范〕Nx `affected`：`nx affected -t <task>` 用 git 判定改动文件 → 用 project graph 判定文件归属 → 判定哪些 project 依赖被改的 project；`NX_LEGACY_AFFECTED=false` 可从 project 级下沉到 **task 级**（"based on whether your change reaches what each task reads"）；`--explain` 打印"为什么受影响"（`nx-affected-docs.html`，已抓取） |

### Nx `affected` 中值得直接借用的工程细节

- **base 应设为 main 上最近一次成功 commit**，而非固定 `~1`。〔规范，Nx 文档 "Configure affected on CI"〕
- **CI 需要 `fetch-depth: 0`**，否则没有 base commit 可比。〔规范，Nx GitHub Actions 示例〕
- **task 选择不是免费的**：`dependsOn` **本身**不会让一个 task 受影响；只有当改动经由该 task 自己的 inputs（如 `^production` 或依赖的 build output via `dependentTasksOutputFiles`）到达时才受影响。**这意味着爆炸半径可能被低估。**〔规范，Nx 文档 caution 块〕
- **自定义 hasher 的 executor 总是被选中**（因为 hash 来自 inputs 之外的代码，Nx 无法判断）——这是**保守方向**的偏差。〔规范〕
- **sync generator 在运行中改文件不会更新选择集**，需要在 sync 之后重跑。〔规范〕
- lock 文件变化时默认**全部 project 标为 affected**；可配 `projectsAffectedByDependencyUpdates` 为 `"auto"`（按 lock 文件结构 diff 判断哪些依赖真的变了，支持 `pnpm-lock.yaml`、`package-lock.json`、`yarn.lock`、`bun.lock`、`bun.lockb`）。〔规范〕

> **跨仓类推**：Nx 的这些偏差在 polyrepo 下会更严重——因为"一个仓的 lock 文件变化"会跨仓触发。因此多仓场景必须显式维护**仓级 affected 集合**，不能依赖各仓 CI 独立跑全量。

---

## 4. 发布顺序与灰度 / 回滚

### 发布顺序原则

1. **只做向后兼容的变更先发布**。任何会破坏旧消费方的变更，其发布顺序必须是：兼容层 → 全部消费方迁移 → 破坏层。
2. **provider 先于 consumer**（在 expand-contract 模型下）。反例只在两种情况下允许：consumer 侧有独立开关且默认关闭。
3. **数据库迁移独立成一次发布**，且与代码发布解耦：先加列（向后兼容）→ 双写 → 回填 → 切读 → 删列。〔工程惯例〕
4. **跨仓发布顺序必须有单一事实来源**（同一 issue / 变更单记录每个仓的 commit 与部署状态）。〔工程惯例〕

### 灰度 / 回滚

- **feature flag 是多仓协同的核心工具**：让"代码已合入"与"行为已生效"解耦，从而把跨仓的**部署顺序问题**降级为跨仓的**配置顺序问题**——后者可秒级回滚，前者不能。
- **canary 必须跨仓对齐**：如果一次变更同时改了网关与后端服务，只灰度一个仓得到的信号是**混合态**，无法判别是修复生效还是回归。〔工程惯例〕
- **回滚顺序应与发布顺序相反**，且**回滚必须先于回滚 schema**。〔工程惯例〕

### 文献侧的支撑

- BeyondSWE 的 **DepMigrate** 子集正是"上游破坏性变更下的仓级协同改造"，且论文强调当前 agent 在这类任务上表现不佳——说明**发布顺序与迁移协调目前没有可靠的自动化**，必须依赖人工契约流程。〔论文，已核实〕
- GitNexus 提供 `group status`（"Check staleness of repos in a group"）与 `group_sync`——多仓索引的**新鲜度**本身需要被显式管理，否则 blast radius 是对过时代码算的。〔规范〕
- TRAIL / FALAT 的教训在此适用：**长执行链里"看起来正常"的步骤可能只是继承前序错误**。多仓发布日志同理——下游仓的绿灯不代表配置正确，只代表它没读到不一致的部分。〔论文，已核实〕

---

## 5. 跨仓验证矩阵（"哪个仓跑什么才算验证完成"）

这是多仓修复最容易被"最后一个仓的 CI 全绿"掩盖盲点的地方。建议的最小矩阵：

| 仓 / 边界 | 必须跑的验证 | 判定标准 | 不可用时的兜底 |
|---|---|---|---|
| **根因仓**（改动仓） | 该改动的单元测试 + 复现原故障的回归测试 | 复现测试**先红后绿**（这个"先红"必须被记录，否则无法证明测试有效） | 若无法构造回归测试，则退回"确认门" C3 未满足，只合到预发不合并 |
| **契约提供方** | 契约 diff 检查（`buf breaking` / `japicmp` 等） | 无新增破坏性变更；若确有破坏，走 expand-contract 三阶段 | 无工具时：手工 diff + 双人复核 + 明确登记破坏项 |
| **契约消费方（全量）** | 契约测试（Pact 或等价） | **每个**消费方仓都跑过；不允许抽样 | 无自动化时：列全量消费方清单 + 逐仓人工确认，作为发布门禁的人工工单 |
| **受影响面（非根因仓）** | affected target / blast radius 内的构建 + 测试 | affected 集合内的目标全绿 | Nx 不可用时：按 CODEOWNERS 通知 + 全量构建（更贵但更安全） |
| **数据库 / migration** | 迁移在**上一版本代码**上正向跑通一次（向后兼容验证） | 旧代码 + 新 schema 能正常读写 | 无双版本环境时：至少在备份快照上验证，且必须准备好回滚 SQL |
| **跨仓集成 / E2E** | 端到端复现原用户症状 | 原症状消失，且无新增回归 | 无 E2E 时：用 trace 比对（症状 span 的错误率归零 + 无新增错误 span）替代 |
| **灰度** | 单一仓灰度时**必须**标注为"混合态信号"，不作为判别依据 | — | 若不能双跑新旧，只能靠 feature flag 在同一部署内切换 |

**关键约定**：上表的"验证完成"是**合集**，不是并集里的任一项。Multi-SWE-bench 已证明"修改面变大 → resolved rate 下降"，BeyondSWE 证明平均要动 10.9 个文件；在这个规模下，"最后一个仓绿了"完全不能代表整体正确。〔论文，已核实〕

---

## 6. 所有权与升级路径

### CODEOWNERS 归属

- CODEOWNERS 决定了"评审该找谁"，但**不解决"根因不在这个仓怎么办"**。多仓问题单需要一个**明确的 owner 归属规则**：症状仓 owner 担任 **triage owner**（负责收敛候选集与推进确认门），根因仓 owner 担任 **fix owner**（负责补丁），两者都必须在变更单上签字。〔工程惯例〕
- 归属应基于**契约面**而非目录面：谁拥有那条跨仓契约，谁承担兼容性的最终责任。

### on-call 升级路径

多仓故障的升级路径应当是**双线**的：

1. **症状线**：从用户可见层（前端 / 网关 / 客服）出发，按阶段①收缩候选集。
2. **依赖线**：从可观测层（trace / 指标）出发，按阶段②③沿传播图搜索。

两条线在"确认门"处汇合。任一条线单独给出的结论都只是"相关性排序"（见 `cross-repo-localization.md` 阶段⑤的三级输出）。

升级触发条件建议为：症状仓无法在约定时限内把候选集收敛到 ≤ 3 个仓，或两条线给出的根因候选不一致。〔工程惯例〕

### 跨仓 PR 的评审与联调成本

- **评审成本**：多仓 PR 的评审成本大致正比于"受影响仓数 × 契约面复杂度"。GitNexus 的 `api_impact` / `group impact` 就是用来把这部分成本前置到评审前（"what breaks before changing"）。〔规范〕
- **联调成本**：最高成本项是"需要同时部署多个仓版本才能复现"。缓解手段是**契约驱动的桩（stub）**：消费方先用提供方的录制契约做桩测试，使联调不必等全量部署。〔工程惯例，Pact 生态的既有实践〕
- **成本可控的信号**：TRAIL 显示长执行链的失败定位极难（SOTA 仅 11%），FALAT 显示归因不是独立分类问题（最高 46.0% / 29.1%）。**这意味着"人工跨仓联调"在复杂场景下不是可以省掉的开销**——自动化 agent 在这一环的能力有明确上限。〔论文，已核实〕
