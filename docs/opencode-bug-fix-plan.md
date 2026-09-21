# 基于 OpenCode 的完整 bug-fix 能力计划

## 目标架构

`GitHub issue + /bugfix` → **intake** → **triage/reproduce** → **OpenCode fixer** → **只读 verifier** → **确定性验证** → **审阅 PR**。

本仓库已实现该最小可运行骨架：[`bin/bug-fix.js`](../bin/bug-fix.js) 是编排器；现有 `bug-fix` agent 执行修复；`bug-fix-verifier` 独立审查；`.bugfix/validation.json` 是仓库控制的确定性命令白名单；workflow 只为成员评论启动。

## 技术路径与选型

| 层 | 选择 | 原因 |
| --- | --- | --- |
| 执行 agent | OpenCode CLI + 仓库内 `.opencode/agents` | 模型可替换，agent 指令随代码评审、版本化。 |
| 编排 | Node.js 20+、零运行时依赖 | 对 GitHub Actions 可移植；`spawn` 传 argv 而非 shell 字符串。 |
| 输入 | GitHub issue event 写为 JSON | 保留可复跑输入，并明确 issue/comment 不可信。 |
| 模型 | `BUGFIX_MODEL=provider/model` 配置 | 避免锁定供应商；按仓库语言、成本、隐私和实测选择。 |
| 知识/工具 | 本地代码检索优先，MCP 按 allowlist 后接入 | 防止无界网络上下文及不必要凭据暴露。 |
| 交付 | 临时工作区变更 → CI 提交到 `codex/bugfix-<issue>` → PR | agent 没有 git 发布权，人保留 merge 决策。 |

### 扩展为服务化平台的路径

当前提交是零依赖的 **M0 单仓 CLI/Actions 实现**，刻意不虚构 Jira、数据库或云权限。需要支持多仓、多问题单来源和可恢复长任务时，按以下演进：控制面采用 TypeScript + OpenCode SDK、Fastify、PostgreSQL（run/状态/审计）及 Redis/BullMQ 或 Temporal（队列、lease、幂等重试）；对象存储保存压缩 trajectory/日志/SARIF，OpenTelemetry 记录指标。每个 run 固定 `baseSha`，在无特权 Docker/VM 的独立 worktree 中执行，默认禁 egress、限制 CPU/内存/磁盘/墙钟。OpenCode permission 是交互门禁而非安全边界，真实隔离必须由容器/VM 提供。

生产集成优先以 OpenCode SDK 创建内嵌 session（不暴露 HTTP listener）；若用 server/client，必须限定 localhost 并有认证。MCP 只能提供窄的、审计过的只读工具，例如 `issue.get`、`repo.metadata`、`ci.logs.get`；网页、issue 和日志均套入 untrusted-input 边界。需将所安装 OpenCode 主版本锁定在配置中：当前仓库的 v1-style `permission` 字段不可与 v2 的 `permissions`/`shell`/`subagent` 混用。

## Workflow 及阶段门

1. **授权与 intake**：仅 OWNER/MEMBER/COLLABORATOR 的 `/bugfix` 启动；提取 issue、label、评论及环境。
2. **Triage**：调用 `issue-triage`，产出 observed/expected、复现、验收标准、范围、未知项。信息不足或不可复现即阻断并要求补充。
3. **Baseline / diagnosis**：记录 `git status`、manifest、相关测试；先跑目标复现，再建立 root-cause 假设与替代解释。
4. **Fix**：fixer 仅执行已批准的最小计划，修改生产代码和必要的回归测试；禁止绕过测试、改 CI/权限、发布。
5. **Verify**：先跑 target test，再跑 `.bugfix/validation.json`；独立 read-only verifier 必须给出 `VERDICT: PASS`。任一门失败，不建 PR。
6. **Deliver**：保存 prompt、agent 输出和 validation JSON 至被 gitignore 的 run artifact；PR 描述需包括根因、文件、验证命令、已知风险。

## 上下文控制

- **预算分层**：intake 至多 issue 摘要 + 关键评论；diagnosis 只带首个异常的 10–20 行、关联文件/符号/行号；implementation 只带确定的修改面与验收条件。完整日志只存 artifact。
- **检索顺序**：reproduction/test → stack frame → symbol definition → direct callers/tests → adjacent config。未命中才扩大目录，禁止一次读全仓。
- **checkpoint 合约**：每次 handoff 都传 `{facts, hypothesis, files, commands, results, open_questions, next_gate}`；没有事实就写 unknown，不用模型猜测填补。
- **停止条件**：复现失败、根因置信度低、需要高权限/跨仓/生产数据、验证超时或 verifier FAIL 时停止并报告。

## 安全与运维

- 在短生命周期 GitHub runner 或隔离 worktree 运行，使用最小 `GITHUB_TOKEN` 与 provider secret；不要把 secrets 加入 prompt、artifact 或 PR。
- 将网络/MCP、包安装、数据库、部署、`git push --force`、`reset --hard` 作为默认禁止项。验证命令为 argv 数组，拒绝 shell 元字符。
- 为每次运行记下模型、prompt hash、输入 issue、文件 diff、耗时、token/成本、测试结果、verifier verdict 和人工 merge/revert 结果。
- 逐步 rollout：`dry-run`（只诊断）→ 低风险标签自动 PR → 人工采样审查 → 按自有回放集达到质量阈值再扩面。

## 验收指标

离线使用按时间切分的已合并 bug PR 回放集，隐藏测试不得给 agent；线上按“可复现率、验证通过率、PR 接受率、回滚率、平均耗时/成本、人工修改行数”分标签和语言观测。把安全阻断和正确拒绝计为成功的治理行为，而不是失败。

建议实施节奏：M0（本提交）实现 CLI、agent、artifact、验证；M1 加状态机/结构化 RunMemory/预算与 clean-checkout verifier；M2 加 GitHub App、checks 和 draft PR 幂等控制；M3 加 Docker/VM、secret redaction、SAST/SBOM/CODEOWNERS gate；M4 用历史问题单回放、SWE-bench Verified 和长程任务集持续校准。上线门槛至少覆盖 20 个按时间切分的历史 closed issue，报告 verifier pass、人工接受、P95 成本/时延、误改与安全拒绝率，而不是只报告 benchmark resolved rate。

## 运行方式

```bash
npm test
npm run bugfix -- --issue-file ./issue.json --model provider/model --dry-run
# 去掉 --dry-run 后要求本机已安装并登录 OpenCode
```

Issue JSON 最小形式：`{"number": 42, "title": "…", "body": "…"}`。部署 GitHub workflow 前，在仓库 Variables 配置 `BUGFIX_MODEL`，并按所选 OpenCode provider 配置相应 secret。
