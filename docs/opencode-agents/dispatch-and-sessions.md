# 调用与会话机理：task / subagent · child session · depth · @mention · agent 切换

> 抓取日期：2026-10-08 · 本机：`opencode 1.18.32`
> 证据标注同 README：【观测】/【推论】/【判断】/【待验】

---

## 1. 工具名：`task`（v1/本机） vs `subagent`（v2）

### 1.1 本机只有 `task`

【观测】`opencode agent list` 输出的工具布尔映射中，subagent 相关键名为 `task`：
```
tools.task = true / false
```
【观测】线上 schema `$defs.PermissionConfig` 只有 `task` 键，**无 `subagent` 键**。

### 1.2 v2 引入 `subagent`

【观测】v2 docs `Permissions > Configure` 节 Warning 逐字：
> "V1 uses different field and action names. In V2, use `permissions`, `shell`, and `subagent` instead of `permission`, `bash`, and `task`."

【观测】v2 docs `Agents > Modes` 节：`subagent` = *"Runs only in a child session through the subagent tool."*
【观测】v2 docs `Actions` 表：`subagent` → *"Child agents"* / *"Target agent ID"*

### 1.3 v1 `task` 工具的参数（源码逐字）

【观测】`research/src-task-tool.ts:43-62`：
```ts
const BaseParameterFields = {
  description:    Schema.String  // "A short (3-5 words) description of the task"
  prompt:         Schema.String  // "The task for the agent to perform"
  subagent_type:  Schema.String  // "The type of specialized agent to use for this task"
  task_id:        Schema.optional(Schema.String)  // 续接同一 subagent session
  command:        Schema.optional(Schema.String)  // "The command that triggered this task"
}
export const Parameters = Schema.Struct({
  ...BaseParameterFields,
  background: Schema.optional(Schema.Boolean),
})
```
【观测】`:25-30`：`BACKGROUND_DESCRIPTION` 逐字说明 `background=true` 的语义（*"Background mode: `background=true` launches the subagent asynchronously and returns immediately. Foreground is the default..."*），但该描述仅在 `flags.experimentalBackgroundSubagents` 为真时追加（`:362-366`）。

---

## 2. 前台 / 后台 child session

### 2.1 三种执行路径

【观测】`research/src-task-tool.ts`：

| 路径 | 触发条件 | 源码位置 | 父 agent 收到的返回 |
|---|---|---|---|
| **前台**（默认） | `background !== true` | `:328-358`（`Effect.acquireUseRelease` + `Effect.raceFirst`） | `<task_result>` 完整文本 |
| **后台（新建）** | `background === true` | `:316-319` → `background.start(...)` | `<task ... state="running">` + `BACKGROUND_STARTED` 文案 |
| **前台运行中被提升为后台** | 已有前台 job 被外部"promote" | `:267-282`（`background.extend(...)` 返回真） | `<task ... state="running">` + `BACKGROUND_UPDATED` 文案 |

【观测】`:334-337`：前台路径用 `Effect.raceFirst(background.wait(id), background.waitForPromotion(id))` —— 这就是"前台可被就地提升为后台"的机制。

### 2.2 后台能力是实验开关

【观测】`:98-102`：
```ts
if (runInBackground && !flags.experimentalBackgroundSubagents) {
  return yield* Effect.fail(
    new Error("Background subagents require OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true"),
  )
}
```
【观测】SDK `dist/v2/gen/types.gen.d.ts:1746-1748`：
```ts
export type ExperimentalCapabilities = {
    backgroundSubagents: boolean;
};
```
【推论】该能力由 server 下发 capability 标志，环境变量只是本机启用方式。

### 2.3 后台完成后回注父 session

【观测】`:227-254`（`injectBackgroundResult`）：构造一个 **`type: "text", synthetic: true`** 的 part，`agent: currentParent.agent ?? ctx.agent`，`Effect.ignore` 忽略失败。
【观测】`:71-79`（`renderOutput`）输出结构：
```
<task id="{sessionID}" state="{completed|error|running}">
  [<summary>...</summary>]
  <task_result>...</task_result>   // 或 <task_error>...</task_error>
</task>
```
【观测】`:31-41` 的 `BACKGROUND_STARTED` / `BACKGROUND_UPDATED` 文案均含强制约束：*"DO NOT sleep, poll for progress, ask the task for status, or duplicate this task's work — avoid working with the same files or topics it is using."*

【判断】后台 subagent 是"给模型上缰绳"的设计：不只是异步执行，而是通过工具返回值文本**禁止父 agent 重复劳动 / 轮询**。这对本仓库 `repair → referee` 的编排有直接价值：若把 `referee` 改成后台，需要在 `repair.md` 里显式说明"等待期间不要并行改同一批文件"。

---

## 3. `subagent_depth`：语义、默认值、超限报错原文

### 3.1 语义与默认值

【观测】v1 docs `Subagent depth` 节逐字：
> "You can control how deeply subagents can invoke other subagents using the `subagent_depth` option. ... **The default is 1, which allows primary agents to launch subagents but prevents those subagents from launching additional subagents. Set it to 2 to allow one additional level of nested subagents, or 0 to prevent all subagent launches.**"

【观测】`config-schema.json` → `Config.properties.subagent_depth.description`：*"Maximum subagent nesting depth. Defaults to 1, which prevents subagents from launching subagents."*（`minimum: 0`）

### 3.2 实现：沿 `parentID` 链数深度

【观测】`research/src-task-tool.ts:104-117`（完整逻辑）：
```ts
const parent = yield* sessions.get(ctx.sessionID)
let current = parent
let depth = 0
while (current.parentID) {
  depth++
  current = yield* sessions.get(current.parentID)
}
if (depth >= (cfg.subagent_depth ?? 1)) {
  return yield* Effect.fail(
    new Error(
      `Subagent depth limit reached (${cfg.subagent_depth ?? 1}). Increase "subagent_depth" to allow nested subagents.`,
    ),
  )
}
```

| 场景 | `depth` | `subagent_depth` 默认 1 | 结果 |
|---|---|---|---|
| root session（primary）调 task | 0 | `0 >= 1`? 否 | ✅ 允许 |
| depth-1 child session 调 task | 1 | `1 >= 1`? 是 | ❌ 报错 |
| `subagent_depth: 2` 时 depth-1 调 task | 1 | `1 >= 2`? 否 | ✅ 允许 |
| `subagent_depth: 0` 时 root 调 task | 0 | `0 >= 0`? 是 | ❌ 报错 |

### 3.3 报错原文（逐字）

```
Subagent depth limit reached (1). Increase "subagent_depth" to allow nested subagents.
```
（括号内数字为**当时生效的** `subagent_depth`，即 `cfg.subagent_depth ?? 1`）

相关报错原文（同一工具）：
| 触发条件 | 原文 |
|---|---|
| `background=true` 但未开实验开关 | `Background subagents require OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true` |
| `subagent_type` 不存在 | `Unknown agent type: {subagent_type} is not a valid agent type` |
| `ctx.extra.promptOps` 缺失 | `TaskTool requires promptOps in ctx.extra` |
| 当前 message 非 assistant | `Not an assistant message` |
| child assistant 返回 error | `Subagent failed (task_id: {sessionID}): {message}` |
| child 有 error 状态的 tool part | `Subagent failed (task_id: {sessionID}): {state.error}` |
| 前台 job 被取消 | `Task cancelled` |
| 前台 job error（另一分支） | `Task failed` |

---

## 4. 子 agent 用**谁的** permission？（本报告最反直觉的一节）

### 4.1 官方表述

| 来源 | 逐字原文 |
|---|---|
| v1 docs `Agents` 节 | *"If you don't specify a model, primary agents use the model globally configured while subagents will use the model of the primary agent that invoked the subagent."* |
| v1 docs `Permissions > Agents` 节 | *"You can override permissions per agent. Agent permissions are merged with the global config, and agent rules take precedence."* |
| v2 docs `Modes` 节 | *"The parent agent's subagent permissions control which agents it may launch; **the child uses its own configured permissions**."* |
| v2 docs `Permissions > Agents` 节 | *"Agent rules are appended after global rules; they do not replace the global array. **A custom subagent uses its own permissions, not a subset of its parent's permissions.**"* |

### 4.2 源码实际行为

【观测】`research/src-agent-subagent-permissions.ts` **全文 27 行**（含原始注释）：
```ts
/**
 * Build the `permission` ruleset for a subagent's session when it's spawned
 * via the task tool. Combines:
 *
 * 1. The parent session's deny rules and external_directory rules.
 *    Parent agent restrictions only govern that agent; the subagent's own
 *    permissions determine its capabilities.
 * 2. Default `todowrite` and `task` denies if the subagent's own ruleset
 *    doesn't already permit them.
 */
export function deriveSubagentSessionPermission(input: {
  parentSessionPermission: PermissionV1.Ruleset
  subagent: Agent.Info
}): PermissionV1.Ruleset {
  const canTask = input.subagent.permission.some((rule) => rule.permission === "task")
  const canTodo = input.subagent.permission.some((rule) => rule.permission === "todowrite")
  return [
    ...input.parentSessionPermission.filter(
      (rule) => rule.permission === "external_directory" || rule.action === "deny",
    ),
    ...(canTodo ? [] : [{ permission: "todowrite", pattern: "*", action: "deny" }]),
    ...(canTask ? [] : [{ permission: "task", pattern: "*", action: "deny" }]),
  ]
}
```

【观测】`research/src-session-llm.ts:149`（运行时最终合并顺序）：
```ts
const ruleset = Permission.merge(input.agent.permission ?? [], input.permission ?? [])
```
即 **agent 规则在前，session 规则在后**；而求值是 `findLast`（last-match-wins）→ **session 规则覆盖 agent 规则**。

### 4.2b 已排除"版本差异"假设（webfetch 核验）

【观测】`https://raw.githubusercontent.com/anomalyco/opencode/v1.18.32/packages/opencode/src/agent/subagent-permissions.ts`（HTTP 200）内容与 `dev` 分支**逐字节一致**。
【观测】`v1.18.32` tag 的 `agent/agent.ts`、`tool/task.ts`、`tool/task.txt` 亦与 `dev` 一致。
→ **本节 §4.2 的源码结论对 1.18.32 全部成立**，无需版本折扣。

【观测】`opencode debug agent` 的 `tools` 字段只反映 **agent 级** ruleset（`Permission.disabled()` 用 `findLast` + `pattern==="*" && action==="deny"` 判定），**不反映 child session 的有效权限**。因此 `general` 的 `tools.task === true` 与它实际不能派生子 agent 并不矛盾。逐 agent 对照表见 `frontmatter-and-permissions.md` §3.1。

### 4.3 综合结论

| 问题 | 答案 | 等级 |
|---|---|---|
| 子 agent 用自身 permission 还是父的子集？ | **用自身 permission**（不是交集、不是子集） | 【观测】v2 docs + 源码 |
| 父的规则会流向子吗？ | **会**：父 session 的**全部 `deny` 规则** + **全部 `external_directory` 规则**被追加到子 session ruleset 末尾 → **因 last-match-wins 而覆盖子 agent 的同名规则** | 【观测】`src-agent-subagent-permissions.ts:21-23` + `src-session-llm.ts:149` |
| 父的 `ask` / `allow` 会流向子吗？ | **不会**（filter 只保留 `external_directory` 或 `deny`） | 同上 |
| subagent 不写 `task` 规则会怎样？ | **自动注入 `task/* deny`** | 【观测】`src-task-tool.ts:147-149` |
| subagent 不写 `todowrite` 规则会怎样？ | **自动注入 `todowrite/* deny`** | 【观测】`src-task-tool.ts:143-146` |
| `experimental.primary_tools` | 额外注入 `deny` 规则（仅对 child session） | 【观测】`src-task-tool.ts:150-154` |

【判断】**对工程决策的含义**：v2 docs 那句"not a subset of its parent's permissions"是**简化表述**，不能作为安全推理依据。真正的安全边界是：父 session 上任何一条 `deny`（或 `external_directory` 规则）都是子 session 的**不可覆盖天花板**。要放开某个能力，必须确保**父 session 上也没有对应的 deny**。

【观测】已知 bug：GitHub issue `anomalyco/opencode#45078` *"Task subagents inherit parent session denies that later rules..."* —— 指出父 session 中已被后续规则覆盖掉的 deny 仍被无差别继承。

---

## 5. 模型继承规则

【观测】`research/src-task-tool.ts:181-184, 209`：
```ts
const model = next.model ?? {
  modelID: msg.info.modelID,
  providerID: msg.info.providerID,
}
...
variant: next.model ? undefined : variant,
```

| 情况 | model | variant |
|---|---|---|
| subagent 配了 `model` | 用自己的 | **不继承**（`undefined`） |
| subagent 未配 `model` | 继承**父 assistant message** 的 modelID/providerID | 继承父 message 的 variant |

【观测】v2 docs `Model` 节逐字一致：*"A subagent uses its configured model, or inherits the parent session's model when none is configured. A session stores its selected model separately. Selecting a primary agent by ID does not change that model."*

【判断】对本仓库的启示：`referee` 若要跑便宜的小模型复核，必须显式写 `model:`（会失去 variant 继承），或者保持不写（则与 `repair` 同一个模型，成本翻倍）。

---

## 6. `@agent` mention 与 `AgentPart`

### 6.1 解析路径（官方表述）

【观测】v1 docs `Subagents` 节：*"You can also manually invoke them by @ mentioning them in your messages."*
【观测】v1 docs `Usage` 节逐字示例：
> "Manually by @ mentioning a subagent in your message. For example.
> `@general help me search for this function`"

【观测】v2 docs `Selection`/`Modes` 节：`@explore find where authentication errors are handled`，语义是 *"ask the current agent to delegate work to it"* —— **不是直接把会话切到该 subagent，而是请求当前 agent 去委派**。

【观测】v1 docs `Task permissions` 节 Tip 逐字（重要安全边界）：
> "Users can always invoke any subagent directly via the @ autocomplete menu, even if the agent's task permissions would deny it."

### 6.2 `AgentPart` 的实际数据结构

【观测】本仓库 `.opencode/node_modules/@opencode-ai/sdk/dist/v2/gen/types.gen.d.ts:442-452`：
```ts
export type AgentPart = {
    id: string;
    sessionID: string;
    messageID: string;
    type: "agent";
    name: string;
    source?: {
        value: string;
        start: number;
        end: number;
    };
};
```
【推论】`name` 是解析出的 agent ID；`source` 记录原始文本及其在 message 文本中的 `[start, end)` 偏移（用于 UI 高亮）。因此 `@referee` 解析出的 `name` 应为 `"referee"`（无 `@`）。

### 6.3 agent part 与 session 存储

【观测】SDK v2 types 中存在 `SessionMessageAgentSwitched` 事件类型（同文件 `:3213` 附近），字段 `id` / `metadata` / `time...`。
【观测】SDK v1 types `Session`（`dist/gen/types.gen.d.ts:467-492`）**没有 `agent` 字段**；SDK v2 `SessionV2Info`（`dist/v2/gen/types.gen.d.ts:3183-3190`）**有 `agent?: string`**。
【推论】agent 归属存在 server 侧（v1 的 message info）并通过 `session.updated` 事件体现，v1 的 `Session` DTO 只是没暴露。

---

## 7. Agent 注册、优先级与合并

### 7.1 完整加载与合并顺序（源码逐行）

【观测】`research/src-config-paths.ts:17-30`（搜索目录，从早到晚）：
```ts
export const directories = Effect.fn("ConfigPaths.directories")(function* (directory: string, worktree?: string) {
  return unique([
    Global.Path.config,                    // ~/.config/opencode
    ...(!Flag.OPENCODE_DISABLE_PROJECT_CONFIG
      ? yield* afs.up({ targets: [".opencode"], start: directory, stop: worktree }) : []),
    ...(yield* afs.up({ targets: [".opencode"], start: Global.Path.home, stop: Global.Path.home })),
    ...(Flag.OPENCODE_CONFIG_DIR ? [Flag.OPENCODE_CONFIG_DIR] : []),
  ])
})
```
即顺序：**全局 `~/.config/opencode` → 从当前目录向上到 worktree 的各 `.opencode`（由远及近）→ `$HOME/.opencode` → `OPENCODE_CONFIG_DIR`**。

【观测】`research/src-config-config.ts`：
| 行 | 动作 |
|---|---|
| `:421-423` | 遍历 `ConfigPaths.files(...)`（远→近的 `opencode.json` / `opencode.jsonc`），逐个 `merge` |
| `:438-448` | 遍历 `directories`；若是 `.opencode` 目录，再 merge 其内的 `opencode.json`/`opencode.jsonc` |
| `:473` | `result.command = mergeDeep(result.command ?? {}, ConfigCommand.load(dir))` |
| `:474` | `result.agent = mergeDeep(result.agent ?? {}, ConfigAgent.load(dir))` |
| `:475` | `result.agent = mergeDeep(result.agent ?? {}, ConfigAgent.loadMode(dir))` |
| `:550-557` | 全部合并完后：`result.mode` 的每一项灌进 `result.agent` 并**强制 `mode: "primary"`** |
| `:559-565` | `OPENCODE_PERMISSION` env 里的 JSON merge 进 `result.permission` |
| `:567-578` | 顶层 `result.tools`（legacy bool）翻译成 `result.permission` |

【观测】顶层 `tools` → `permission` 的翻译代码（`:567-578`）：
```ts
for (const [tool, enabled] of Object.entries(result.tools)) {
  const action = enabled ? "allow" : "deny"
  if (tool === "write" || tool === "edit" || tool === "patch") { perms.edit = action; continue }
  perms[tool] = action
}
result.permission = mergeDeep(perms, result.permission ?? {})
```
→ **`tools` 生成的规则在前，显式 `permission` 在后 → 显式 `permission` 优先**。

### 7.2 Markdown agent 加载（`:74` 与源码逐行）

【观测】`research/src-config-agent.ts:13-30`：
```ts
for (const item of await Glob.scan("{agent,agents}/**/*.md", { cwd: dir, absolute: true, dot: true, symlink: true })) {
  const md = await ConfigMarkdown.parse(item).catch(() => undefined)
  if (!md) continue
  const name = configEntryNameFromPath(path.relative(dir, item), ["agent/", "agents/"])
  const config = { name, ...md.data, prompt: md.content.trim() }
  result[config.name] = ConfigParse.schema(ConfigAgentV1.Info, config, item)
}
```
| 事实 | 依据 |
|---|---|
| 同时支持 `agent/` 与 `agents/`（**复数优先是文档建议，单数向后兼容**） | `"{agent,agents}/**/*.md"`；v1 docs `Config` 节：*"The .opencode and ~/.config/opencode directories use plural names for subdirectories... Singular names (e.g., agent/) are also supported for backwards compatibility."* |
| 支持**嵌套子目录**，路径成为 ID 的一部分 | `"**/*.md"` + v2 docs：*".opencode/agents/team/reviewer.md → `team/reviewer`"* |
| **Markdown body 直接成为 `prompt`**（会覆盖 frontmatter 的 `prompt:`，因为 spread 顺序是 `{name, ...md.data, prompt: md.content.trim()}`） | `:24-28` |
| `agents/` 加载时**不注入**默认 `mode` | 对比 `loadMode`（`:52-55`）显式写 `mode: "primary"` |
| `dot: true` → `.hidden.md` 也会被扫描 | `:16` |

【观测】`research/src-config-entry-name.ts`：名称剥离已知前缀后再去扩展名；注释记录了 issue #25713（父目录名恰好含 `agent`/`agents` 导致误 key 的 bug）。

### 7.3 `agent.ts` 中的覆盖逻辑（源码逐行，最关键）

【观测】`research/src-agent-agent.ts:267-294`：
```ts
for (const [key, value] of Object.entries(cfg.agent ?? {})) {
  if (value.disable) { delete agents[key]; continue }
  let item = agents[key]
  if (!item)
    item = agents[key] = {
      name: key, mode: "all",
      permission: Permission.merge(defaults, user),   // ← 新 agent 基线 = base policy + 全局 permission
      options: {}, native: false,
    }
  if (value.model) item.model = Provider.parseModel(value.model)
  item.variant    = value.variant    ?? item.variant
  item.prompt     = value.prompt     ?? item.prompt
  item.description= value.description?? item.description
  item.temperature= value.temperature?? item.temperature
  item.topP       = value.top_p      ?? item.topP
  item.mode       = value.mode       ?? item.mode
  item.color      = value.color      ?? item.color
  item.hidden     = value.hidden     ?? item.hidden
  item.name       = value.name       ?? item.name
  item.steps      = value.steps      ?? item.steps
  item.options    = mergeDeep(item.options, value.options ?? {})
  item.permission = Permission.merge(item.permission, Permission.fromConfig(value.permission ?? {}))
}
```

### 7.4 合并语义总结表

| 类别 | 语义 | 源码 |
|---|---|---|
| 标量（`variant`/`prompt`/`description`/`temperature`/`top_p`/`mode`/`color`/`hidden`/`name`/`steps`） | **`??` 覆盖**：写了就用写的；`undefined`/未写则保留前值 | `:282-291` |
| `model` | **真值覆盖**（`if (value.model)`，空串也会被忽略） | `:281` |
| `options` | **深合并**（`mergeDeep`），不是替换 | `:292` |
| `permission` | **追加**（append），agent 规则排在已有规则之后 → 后者优先 | `:293` + `src-permission-v1-bridge.ts:200-202` |
| `disable: true` | **删除**该 agent（内置的也能删） | `:268-271` |
| 同名冲突 | **后加载的覆盖/追加到前一个**；加载顺序 = 全局 → 项目（远→近）→ json → mode | §7.1 |
| `agent` 键 vs `mode` 键 | `mode` 最后生效且强制 `mode: "primary"` | `:550-557` |

【观测】新自定义 agent 的基线是 `Permission.merge(defaults, user)` —— 即 **base policy + 全局 `permission`**。这与 v1 docs `Agents` 节 *"Agent permissions are merged with the global config, and agent rules take precedence."* 一致。

### 7.5 内置 agent 定义（`src-agent-agent.ts:140-265` 摘要）

| agent | `mode` | `native` | `hidden` | 追加规则（相对 base） |
|---|---|---|---|---|
| `build` | primary | true | — | `question: allow`, `plan_enter: allow` |
| `plan` | primary | true | — | `question: allow`, `plan_exit: allow`, **`task: { general: "deny" }`**, `external_directory: {<Global.Path.data>/plans/*: allow}`, `edit: { "*": "deny", ".opencode/plans/*.md": "allow", <relative>/.local/share/opencode/plans/*.md: "allow" }` |
| `general` | subagent | true | — | `todowrite: "deny"` |
| `explore` | subagent | true | — | `"*": "deny"`, `grep/glob/list/bash/webfetch/websearch/read: "allow"`, `external_directory: <readonlyExternalDirectory>` |
| `compaction` | primary | true | **true** | `"*": "deny"` |
| `title` | primary | true | **true** | `"*": "deny"`, 且 `temperature: 0.5` |
| `summary` | primary | true | **true** | `"*": "deny"` |

【观测】源码 `src-agent-agent.ts:162-176`（plan 的 task 规则逐字）：
```ts
task: {
  general: "deny",
},
```
→ **内置 plan agent 就用了按 subagent 名过滤的 task 规则**。这是"v1 支持 task glob"最直接的官方源码证据。

【观测】源码 `:296-310`：`Truncate.GLOB` 的 allow 会被无条件补回每个 agent（除非显式 deny）。

### 7.6 本机 1.18.32 内置 agent 全清单（`opencode agent list` 实测）

```
build (primary)
compaction (primary)
explore (subagent)
general (subagent)
plan (primary)
summary (primary)
title (primary)
probe (primary)        ← 本仓库 .opencode/agents/probe.md
referee (subagent)     ← 本仓库 .opencode/agents/referee.md
repair (primary)       ← 本仓库 .opencode/agents/repair.md
```
共 **10 个**。

**排序规则**：【观测】源码 `src-agent-agent.ts:316-326`：
```ts
sortBy(
  [(x) => (cfg.default_agent ? x.name === cfg.default_agent : x.name === "build"), "desc"],
  [(x) => x.name, "asc"],
)
```
→ 先把 default_agent（未设时为 `build`）置顶，其余按名称升序。**这解释了实测输出中 build 在首、原生 agent（compaction/explore/general/plan/summary/title）排在本仓库自定义 agent（probe/referee/repair）之前**——因为 p/r 字母序在 c-t 区间之后。

**与官方文档的差异**：
| 项 | 官方 v1 docs（Oct 7, 2026） | 本机 1.18.32 实测 |
|---|---|---|
| 内置 primary | build, plan（"two built-in primary agents"）+ compaction/title/summary（hidden） | 同（7 个原生，含 3 个 hidden） |
| 内置 subagent | **general, explore, scout**（"three built-in subagents"） | **general, explore**（无 scout） |
| `hidden` 是否在 `agent list` 显示 | — | 显示（compaction/summary/title 均出现）→ `agent list` 不按 hidden 过滤 |

---

## 8. `default_agent` 与 session 级 agent 切换

### 8.1 `default_agent` 的选择与回退

【观测】源码 `src-agent-agent.ts:328-340`（完整逻辑）：
```ts
const defaultInfo = Effect.fnUntraced(function* () {
  const c = yield* config.get()
  if (c.default_agent) {
    const agent = agents[c.default_agent]
    if (!agent) throw new Error(`default agent "${c.default_agent}" not found`)
    if (agent.mode === "subagent") throw new Error(`default agent "${c.default_agent}" is a subagent`)
    if (agent.hidden === true) throw new Error(`default agent "${c.default_agent}" is hidden`)
    return agent
  }
  const visible = Object.values(agents).find((a) => a.mode !== "subagent" && a.hidden !== true)
  if (!visible) throw new Error("no primary visible agent found")
  return visible
})
```

| 情况 | v1 docs 说法 | dev 源码实际 |
|---|---|---|
| 未设置 `default_agent` | *"This determines which agent is used when none is explicitly specified."* | 取 `Object.values(agents)` 中**第一个** `mode !== "subagent" && hidden !== true` 的（依赖插入顺序，**不是硬编码 build**） |
| 指向不存在的 agent | *"will fall back to `"build"` with a warning"* | **`throw`** `default agent "X" not found` |
| 指向 subagent | 同上 | **`throw`** `default agent "X" is a subagent` |
| 指向 hidden agent | 未提及 | **`throw`** `default agent "X" is hidden` |
| 全部被禁 | 未提及 | **`throw`** `no primary visible agent found` |
| 生效范围 | *"This setting applies across all interfaces: TUI, CLI (`opencode run`), desktop app, and GitHub Action."* | — |

【观测】v2 docs `Selection` 节给出了不同的（更宽松的）链：*"The selected default must exist, be visible, and support primary use. Otherwise OpenCode uses `build`, then the first visible primary-capable agent."*

【判断】**工程建议**：配置 `default_agent` 时必须自校验（存在 / 非 subagent / 非 hidden），否则在 `dev` 分支上是硬失败。schema 的 `description` 与 docs 都承诺"回落 build"，但源码未实现 —— 以源码为准更安全。

### 8.2 session 级切换

| 机制 | 证据 |
|---|---|
| `Tab` 循环切换 primary agent | 【观测】v1 docs `Primary agents` 节：*"You can cycle through them using the Tab key"*；keybind id `agent_cycle` 默认 `"tab"`，反向 `agent_cycle_reverse` 默认 `"shift+tab"`，列表 `agent_list` 默认 `"a"`（`research/keybinds-v1.html`） |
| **文档里的 `switch_agent` keybind 名称有误** | 【观测】v1 docs `Usage` 节写 *"your configured `switch_agent` keybind"*，但 keybind 页面无 `switch_agent`，只有 `agent_cycle` / `agent_cycle_reverse` / `agent_list` |
| 切换方向 | 【观测】v2 docs `Modes` 节：*"press Tab and Shift+Tab to cycle through visible primary and all agents, or use `/agents` to choose one."* |
| agent 切换事件 | 【观测】SDK v2 types 有 `SessionMessageAgentSwitched`（`dist/v2/gen/types.gen.d.ts` 约 `:3213` 起） |
| **切换 agent 不改 session 的 model** | 【观测】v2 docs `Model` 节：*"A session stores its selected model separately. Selecting a primary agent by ID does not change that model."* |

### 8.3 改动 `default_agent` 是否影响已有 session？

【观测】v2 docs `Selection` 节逐字：*"**Changing this setting does not replace the agent stored on an existing session.**"*
【观测】v1 docs 无对应表述（**单边来源**）。
【推论】v1 行为应与 v2 一致：session 存储自己的 agent，`default_agent` 只在 session 未选定 agent 时生效。依据：SDK v2 `SessionV2Info.agent?: string` 说明 agent 是 session 级持久字段。

---

## 9. child session 的导航键位

【观测】v1 docs `Usage` 节逐字：
> "Navigation between sessions: When subagents create child sessions, use `session_child_first` (default: `<Leader>`+Down) to enter the first child session from the parent. Once you are in a child session, use:
> `session_child_cycle` (default: Right) to cycle to the next child session
> `session_child_cycle_reverse` (default: Left) to cycle to the previous child session
> `session_parent` (default: Up) to return to the parent session"

【观测】`research/keybinds-v1.html` 的默认 keybind 表（无 leader 前缀版）：
```
"session_child_first": "down",
"session_child_cycle": "right",
"session_child_cycle_reverse": "left",
"session_parent": "up",
```
【观测】同一页说明段逐字：*"Some navigation keybinds intentionally do not use the leader key by default. For subagent sessions, the defaults are `session_child_first = <leader>down`, `session_child_cycle = right`, `session_child_cycle_reverse = left`, and `session_parent = up`."*

【判断】本仓库 `docs/opencode-tui-agent-plan.md:114` 写的 "`+Down` 进入、`Up` 返回（1.17.8 默认键位）" **方向正确但版本号需更新为 1.18.32**，且更准确的表述是 `session_child_first` / `session_parent` 这两个 keybind id。
