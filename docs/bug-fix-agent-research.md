# 问题单自动修复智能体：业界进展调研（2026-09-21）

## 定义与边界

本文所说的 bug fix agent 是：以问题单（标题、描述、评论、复现信息）为入口，在指定代码仓中完成**证据化诊断、最小修复、回归验证和可审阅交付**的智能体。它不是“看到 issue 就改代码”的聊天机器人；问题单是非可信输入，PR 仍须人审。

## 进展概览

| 方向 | 最新信号 | 对本项目的结论 |
| --- | --- | --- |
| 端到端 issue resolution | SWE-bench Verified 的公开榜单已出现约 79.2% 的最高已报解决率；但该集只有 500 个经人工筛选任务。 | 把榜单分数当上限参考，不把它当线上成功率；建立自有 issue/PR 回放集。 |
| 强化的代码代理 | OpenAI 报告 GPT-5-Codex 面向调试、测试、重构与 code review 训练，并已以 500 个任务报告 SWE-bench Verified。 | 选择能长程执行、读写仓库、运行测试且可遵循仓库指令的模型/agent，而非单次补丁生成。 |
| 通用 CLI agent 平台 | OpenCode 原生支持 `opencode run --agent …`、MCP，以及 GitHub issue/PR 中 `/opencode fix this` 后建分支/PR。 | 以 OpenCode 作为执行层；把本项目差异化放在输入治理、阶段门、上下文预算与独立验收。 |
| 可靠评测 | 新的 SWE-bench Pro 研究强调长程任务与污染/数据质量问题；SWE-bench+ 也指出问题描述泄漏会高估成绩。 | 不能只跑公开 benchmark；按真实仓库、历史 cutoff、隐藏测试与人工审查率评估。 |
| 安全与审计 | Agent 会接触 issue 文本、shell、CI token 和供应链。Issue 中的 prompt injection 已是现实攻击面。 | 只有成员显式 `/bugfix` 才启动；最小 token、隔离 runner、禁止 agent 直接提交/推送，所有结果进 PR。 |

## 可复用的工程模式

成熟方案逐步收敛到一个“证据—假设—变更—验证”的闭环：先复现和定位，压缩地交给实施 agent；实施后由独立、只读 verifier 审查 diff 和测试结果。对失败应输出可复跑的诊断 artifact，而不是不断重试。上下文检索由 issue → 报错/测试 → symbol → callers → 邻近配置逐层扩展；每一步保留摘要和文件位置，原始日志落盘。

## 资料

- [OpenCode GitHub 集成文档](https://thdxr.dev.opencode.ai/docs/github/)：issue/PR 命令、GitHub runner 内执行与创建 PR 的官方流程。
- [OpenCode CLI 文档](https://dev.opencode.ai/docs/cli/)：`run`、agent 与 MCP 管理接口。
- [SWE-bench 官方排行榜](https://www.swebench.com/)：当前可比较的公开 resolved-rate 与运行轨迹入口。
- [OpenAI：Codex 升级](https://openai.com/index/introducing-upgrades-to-codex/)：GPT-5-Codex 的工程任务定位和全 500 task 报告说明。
- [SWE-bench Pro 论文](https://arxiv.org/abs/2509.16941)：长程、污染抗性 issue-resolution 评测的动机。
- [SWE-bench+ 论文](https://arxiv.org/abs/2410.06992)：公开任务中泄漏与数据质量会夸大“修复成功”的证据。

这些资料支持架构判断；具体模型成本、榜单名次和产品接口会快速变化，部署时应重新验证。
