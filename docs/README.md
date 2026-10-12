# docs 索引

本目录是本仓库的设计与调研文档总入口。每份文档开头都应带有**证据边界**声明，请按标签（观测事实 / 论断 / 推论 / 判断 / 待验证假设）区分后再据此决策。

## 按问题找文档

| 你想知道 | 看哪篇 |
|---|---|
| OpenCode 自定义 agent 到底怎么实现、权限怎么算、为什么我的配置没生效 | [`opencode-agents/`](opencode-agents/README.md) |
| 业内怎么"基于问题单修 bug"（含论文与量化论断） | [`bugfix-methodology/`](bugfix-methodology/README.md) |
| 业内怎么定位"多仓/多服务"的问题（前端+后端+DB+网关） | [`multi-repo-bugfix/`](multi-repo-bugfix/README.md) |
| **多仓问题单修复流程怎么设计**（本文档族的汇合点） | [`designs/multi-repo-issue-fix-flow.md`](designs/multi-repo-issue-fix-flow.md) |
| 单仓路线的 TUI/agent 实现方案 | [`opencode-tui-agent-plan.md`](opencode-tui-agent-plan.md) |
| 单仓路线的 SDK / 服务化实现方案 | [`opencode-bug-fix-plan.md`](opencode-bug-fix-plan.md) |
| 最初的 agent 定位与业界方向调研 | [`bug-fix-agent-research.md`](bug-fix-agent-research.md) |
| 对某套描述性多 agent 工作流的架构诊断与批评 | [`../bugfix-multi-agent-diagnosis.md`](../bugfix-multi-agent-diagnosis.md)（[HTML 版](../bugfix-multi-agent-diagnosis.html)） |

## 三条主线

### 1. 机制事实：`opencode-agents/`

基于本机 OpenCode **1.18.32** 实测 + 官方 v1/v2 文档 + 源码快照（`v1.18.32` tag 与 `dev` 分支已交叉验证）。含 31 份离线副本。

- `README.md` —— 心智模型、10 问速查、**版本对齐结论**、对本仓库现有 agent 的启示、对既有文档的证伪清单
- `frontmatter-and-permissions.md` —— 字段全表、v1↔v2 对照、匹配算法、常见误配
- `dispatch-and-sessions.md` —— task/subagent、child session、`subagent_depth`、`@mention`、内置 agent 全清单
- `extension-points.md` —— commands / tools / MCP / plugins hooks / skills / references
- `verified-facts.md` —— 本机命令输出与 `.d.ts` 行号锚点

### 2. 方法论证据：`bugfix-methodology/` + `multi-repo-bugfix/`

| 文档 | 内容 | 离线原文 |
|---|---|---|
| [`bugfix-methodology/`](bugfix-methodology/README.md) | 六层次方法论：调试理论与过程 / 故障定位 / 自动程序修复 / 验证与评测 / agent 工程方法论 | `research/` 30 份 |
| [`bugfix-methodology/claims-table.md`](bugfix-methodology/claims-table.md) | **54 条可追溯论断**（已核实 51 + 单边 3）+ 9 条未核实 | —— |
| [`multi-repo-bugfix/`](multi-repo-bugfix/README.md) | 多智能体诊断闭环（既有文档，OpenCode 无关） | `research/` |
| [`multi-repo-bugfix/cross-repo-localization.md`](multi-repo-bugfix/cross-repo-localization.md) | **跨仓定位五阶段**（候选集收缩 → 拓扑建模 → 传播假设 → 判别实验 → 确认门） | —— |
| [`multi-repo-bugfix/cross-repo-patch-coordination.md`](multi-repo-bugfix/cross-repo-patch-coordination.md) | 多仓补丁协同、版本偏斜、发布顺序、**跨仓验证矩阵** | —— |
| [`multi-repo-bugfix/toolchain.md`](multi-repo-bugfix/toolchain.md) | 工具矩阵（license / 活跃度 / 权限副作用 / 兜底） | `research/` 8 份工具文档 |

> `multi-repo-bugfix` 目录中曾存在一份文件名错误的 PDF（实为物理论文），已核实并移除，更正记录见 `multi-repo-bugfix/research/README.md`。

### 3. 流程设计：`designs/`

[`designs/multi-repo-issue-fix-flow.md`](designs/multi-repo-issue-fix-flow.md) —— 多仓问题单修复流程设计（v1，未实现）：角色拓扑、S0–S7 阶段、证据账本 schema、状态机、权限矩阵（含 5 个实测陷阱）、工具接入点、消融矩阵与指标、风险登记表。

## 建议阅读顺序

1. `designs/multi-repo-issue-fix-flow.md` 的 §1 决策摘要 + §3 问题定义
2. `opencode-agents/README.md` 的 §3 版本对齐结论（决定你的配置能不能用）
3. `bugfix-methodology/claims-table.md`（挑与你的决策相关的条目精读）
4. `multi-repo-bugfix/cross-repo-localization.md`（落地 S1–S5 时精读）
5. 其余按需

## 已知需要修订的既有结论

`opencode-agents/README.md` §6 列出了对以下文件的交叉核对结果（**尚未修改原文件**）：

- **已证伪 2 条**：`opencode-tui-agent-plan.md:65-66`、`bugfix-multi-agent-diagnosis.md:20` 关于「`task` 权限不能按 subagent 名过滤」的论断 —— 有官方文档、线上 schema、本机 SDK 类型、内建 `plan` agent 定义、源码五重证据支持 glob 过滤。
- **需修正 8 条**：版本号、keybind id、内置 agent 清单、`write` 规则永不生效等。详见该文件 §6.2。