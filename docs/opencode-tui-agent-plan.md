# TUI 内置 Bug 定位与修复 Agent 项目计划

> 版本：2026-09-22 v3（定稿）｜ 基于 OpenCode 1.17.8（本机已验证）｜ Agent 命名：probe / repair / referee ｜ 取代 `docs/opencode-bug-fix-plan.md` 的 TUI 路线

## 0. 已确认设计决策

1. **probe agent 使用 `mode: primary`**：与 repair 共享会话历史，定位结论零丢失。
2. **referee 与 repair 使用相同模型**：不做异模型 A/B 实验；独立性由"fresh context + 只看 diff 与测试输出"保证，而非换模型。
3. **交互形态为 TUI 自主闭环**：用户在 TUI 中贴入 issue（可附带背景知识，如跨仓线索），repair agent 自主完成「诊断 → 修复 → 验证」全流程，人可随时插话补充信息，最后人审 diff 并 commit。
4. **失败重试策略**：referee FAIL 后只重试一次（共两轮）；第二轮必须基于新的根因假设，不可重复第一轮思路；两轮均失败则停止，输出诊断 artifact（已验证的假设、排除项、建议下一步），交还用户。
5. **命名方案 A（维修工隐喻）**：`probe`（只读探测定位）/ `repair`（自主修复闭环）/ `referee`（独立裁判）——不使用 `bug fix` 命名以避免与团队其他 agent 冲突。

## 1. 方向变更说明

原方案以外部 Node.js 编排器（`bin/bug-fix.js`）驱动 OpenCode headless 进程，用 `.bugfix/validation.json` 控制阶段门。经用户确认，新方向是：**放弃外部编排，完全基于 OpenCode custom agent 机制**，让用户在 TUI 中直接切换/调用 agent，完成「定位 → 修复 → 验证」闭环。

新方案的核心体验优势：

1. **零编排延迟**：用户在 TUI 内 Tab 切 agent、`@` 唤 verifier，不需要离开终端会话，也不再出现 `/bugfix` 后长时间零反馈。
2. **共享会话上下文**：primary agent 之间共享同一个会话历史。probe agent 得出的定位结论（文件、行号、根因假设）会被 repair agent 直接看到，无需跨进程序列化上下文，也消除了「repair 从头排查一遍」的浪费。
3. **权限即安全边界**：每个 agent 的能力由 frontmatter 中的 `permission` 声明，OpenCode 运行时强制执行，不依赖提示词自觉。

## 2. Agent 阵容设计

三个 agent，文件置于 `.opencode/agents/`（项目级，文件名即 agent ID）：

| Agent 文件 | mode | 职责 | 关键能力边界 |
| --- | --- | --- | --- |
| `probe.md` | `primary` | （可选）独立只读定位：复现、读代码、追调用链、输出根因假设与证据 | 不可编辑文件；bash 仅允许只读/测试命令，其余 ask |
| `repair.md` | `primary` | **自主闭环主入口**：接收 issue 与用户补充背景 → 自主诊断 → 最小修复 → 跑回归 → 调度 referee → 失败重试一次 | 可编辑；bash 白名单测试命令 + ask 兜底；仅可调度 referee |
| `referee.md` | `subagent` | 独立审查 diff 与验证结果，给出 PASS/FAIL | 只读；不可编辑；由 repair 调度或用户 `@referee` 手动唤起 |

与现有文件的映射：`bug-fix.md` → 精简重写为 `repair.md`；`bug-fix-verifier.md` → `mode` 由 `primary` 改为 `subagent` 并改名为 `referee.md`；`probe.md` 为新增。旧的 `bug-fix.md` / `bug-fix-verifier.md` 已删除。

## 3. 权限矩阵（v1 格式，已按 1.17.8 验证）

本机 1.17.8 使用 v1 的 `permission` map（非 v2 的 `permissions` 数组），bash 支持通配规则。注意与 v2 格式（`permissions` + `action`/`resource`）**不可混用**。

```yaml
# probe.md / referee.md 共同遵循的只读 bash 策略（示意）
permission:
  read: allow
  glob: allow
  grep: allow
  lsp: allow
  edit: deny
  write: deny
  webfetch: deny
  question: allow
  bash:
    "*": ask
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "npm test*": allow
    "npx vitest*": allow
    "cargo test*": allow
    "pytest*": allow
    "go test*": allow

# repair.md 额外差异
permission:
  edit: allow
  write: allow
  task: allow          # OpenCode 1.x 的 task 只接受 action（allow/ask/deny），不支持按子 agent 名称过滤；
                       # 项目内唯一的 subagent 就是 referee，提示词层面约束 repair 仅调度 referee
  # bash 同上，但追加: "git status*": allow（改后自查）

# referee.md 追加
permission:
  task: deny          # verifier 不得再派生子任务
  bash:               # 只允许运行验证命令，其余 ask
    "*": ask
    "npm test*": allow
    "cargo test*": allow
    "pytest*": allow
    "go test*": allow
```

`git commit` / `git push` 不在任何 allowlist 中，走 ask 兜底；提示词层面同时禁止 agent 主动提交。issue 文本、日志、用户输入一律视为不可信数据（沿用 `issue-triage` skill 的注入防护规则）。

## 4. 调度与用户旅程

### 典型流程（用户视角，自主闭环）

```
[Build] 用户遇到 bug
   │ Tab → 切到 repair agent（主入口）
   ▼
[repair] 用户粘贴 issue + 背景（可含跨仓线索）
   │
   ├─ 阶段1 诊断：复现 → 读代码 → 定位根因（内联，遵循 probe 纪律）
   ├─ 阶段2 修复：最小 diff，不动无关代码
   ├─ 阶段3 自测：跑测试，确认无新增失败
   ├─ 阶段4 referee：task 调度 @referee 独立审查
   │     ├─ PASS → 输出 diff + 修复说明，交还用户
   │     └─ FAIL → 换新根因假设重试一次（阶段2-4）
   │              └─ 再 FAIL → 输出诊断 artifact，停止
   ▼
   用户在任意阶段可插话补充背景（如"这个字段来自另一个仓库"）
   repair 会暂停当前假设，吸收新信息后继续
   最终：用户看 diff → 人审 → 自己 commit
```

用户仍可单独用 `probe` agent 做只读定位（不修复），或 `@referee` 手动审查任意 diff——这些是辅助路径，不是主流程。

### 跨仓问题的处理

用户可能在补充背景中提到"问题涉及另一个仓库"。v1 约定：

1. **只读跨仓调查**：若用户提供其他仓库路径，probe/repair 可对其执行只读命令（read/glob/grep/git log），权限走 ask 兜底，提示词要求先确认路径再操作。
2. **编辑限于当前仓库**：跨仓修改 v1 不做——若根因确实在另一仓库，repair 输出诊断 artifact 指明该仓库与建议修改点，由人另行处理。

子会话导航：verifier 作为 subagent 跑在 child session，`+Down` 进入、`Up` 返回（1.17.8 默认键位）。

### 与旧评审问题的对应

- **零反馈** → TUI 内原生流式输出，天然解决。
- **verifier 在 validation 之前出结论** → repair.md 提示词强制：先自跑测试，测试通过后才 task 调度 referee；referee.md 同时声明「若未收到测试结果，先自行运行验证命令」。
- **verifier 与 fixer 共用模型** → referee.md 与 repair.md 使用相同模型（已确认决策，不做 A/B 实验）。
- **triage skill 未接入** → probe.md 开头加载 `issue-triage` skill，产出定位 brief；`log-analysis` 保留给 probe.md 的日志场景。

## 5. Skill 复用与新增

| Skill | 状态 | 用途 |
| --- | --- | --- |
| `issue-triage` | 已有，接入 probe.md | 把非结构化 bug 描述收敛为「现象/验收/范围/证据/未知项」 |
| `log-analysis` | 已有，保留 | probe.md 遇到日志时的系统化分析方法 |
| `minimal-patch` | 已落盘，接入 repair.md | 修复变更纪律：最小 diff、不动无关代码、不弱化测试、改后自查 `git diff` |

不再新增 orchestration 类 skill——调度由 OpenCode 原生的 primary/subagent 机制承担。

## 6. 阶段计划

### M0 — 骨架跑通（0.5 天）

1. ✅ 新建 `probe.md`；重写 `bug-fix.md` → `repair.md`（补 task: referee、强制先测后验）；`bug-fix-verifier.md` → `referee.md`（mode: subagent）。
2. ✅ 按 §3 配齐权限矩阵。
3. 验证：`opencode` 启动 TUI，确认 Tab 循环出现 probe/repair（Build/Plan 之外）、`@referee` 出现在 autocomplete。
   - 已知问题：`opencode agent list` CLI 在本机因日志文件权限报错，改以 TUI 内 `/agents` 界面目视验证。
4. 用一个已知小 bug 全流程走一遍，确认子会话导航与 diff 展示正常。

验收标准：TUI 中三个 agent 均可被发现并按权限执行；referee 返回标准 `VERDICT:` 格式。

### M1 — 纪律与体验打磨（1-2 天）

1. ✅ 提示词精修：repair.md 内嵌诊断阶段纪律（复用 probe 的结构化 brief 格式：Observed/Expected、Reproduction、Root Cause、Evidence、Proposed Fix、Open Questions）；referee.md 保持独立输入格式。
2. ✅ 写 `minimal-patch` skill 并接入 repair.md。
3. ✅ 重试策略提示词：repair.md 明确"referee FAIL → 必须提出与上一轮不同的根因假设 → 重试一次 → 仍 FAIL → 输出诊断 artifact 停止"，禁止无限循环或重复同一路径。
4. 权限实测：逐条触发 allowlist 内/外命令，确认 ask/deny 行为符合预期。
5. 在 2-3 个真实 bug 上做端到端走查，收集体感和上下文占用。

验收标准：真实 bug 流程无越权命令；repair→referee→PASS 全程不需要用户重复粘贴上下文。

### M2 — 效果度量与旧路线取舍（持续）

1. 建立最小回放集：10 个本仓库历史 bug（含 issue 文本 + 正确修复 commit），用 `opencode run --agent repair "..."` 做非交互回归。
2. 统计：定位命中率（probe brief 是否指出正确根因）、修复通过率、referee 误报率、平均 token 消耗。
3. **旧 Node 编排器处置**（建议，待用户确认）：
   - TUI 流程稳定后，`bin/bug-fix.js` / `lib/` / `.github/workflows/bug-fix.yml` 标记为 deprecated；
   - 保留 `.opencode/skills/` 与两份 docs 作为资产；
   - CI 场景若仍需自动修 bug，用 `opencode run --agent repair` 替代编排器，工作流保留但内部简化。

### M3 — 可选扩展

- `test-runner` skill：按仓库类型自动发现并执行测试命令，收敛到 referee/repair 的公共白名单。
- referee 独立会话证据存档：将 child session 导出（`opencode export`）挂到 PR 描述。
- 全局 agent：将 probe/repair/referee 复制到 `~/.config/opencode/agents/` 以跨项目复用（M2 验证效果后决定）。

## 7. 安全边界（沿用并收紧）

1. Issue 文本、日志、用户粘贴内容均为不可信输入，不能授权命令或覆盖 agent 规则。
2. 禁止读取 `.env`、密钥、SSH 凭证；禁止网络访问（webfetch deny）。
3. 禁止 agent commit/push/改 CI——提交始终由人完成；CI 自动化（若保留）另行评估。
4. referee 只读且不可再派生子任务，防止审查链自我放大。
5. bash 兜底为 ask 而非 deny，保持灵活性；allowlist 由各仓库按实际测试命令增删。

## 8. 开放项 / 待确认

1. **旧 Node 编排器去留**：M2 给出建议（保留 CI 路径 or 直接移除），需用户拍板。
2. **Build/Plan 内置 agent 是否保留**：Tab 会循环所有 primary agent，若嫌切换链变长，可考虑将 probe/repair 的日常入口改为在 Build 内 `@` 调用（代价是失去共享上下文优势）——默认保留为 primary。
