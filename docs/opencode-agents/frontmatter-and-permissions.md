# Frontmatter 全表 · 权限匹配与合并规则

> 抓取日期：2026-10-08 · 本机：`opencode 1.18.32`
> 本文所有【观测】均给出 `research/` 内的文件与行号，或本机命令输出。

---

## 1. 权威字段清单的来源与可信度

三个候选权威源，**结论：以线上 JSON Schema 为字段权威，源码为语义权威**。

| 源 | 抓取文件 | 可信度 | 说明 |
|---|---|---|---|
| `https://opencode.ai/config.json` | `research/config-schema.json`（39039 B，sha256 前12 `e8cb6e287a38`） | **字段权威** | 但它是**过渡期混合 schema**：`AgentConfig` 仍是 v1 形态，却已含 `ConfigV2.Reference.Git/Local`、`Policy.Effect` |
| 官方 v1 docs | `research/agents-v1.html`（Last updated: **Oct 7, 2026**） | 语义 + 废弃标记权威 | 唯一给出 `maxSteps`/`tools` 废弃声明的地方 |
| 官方 v2 docs | `research/agents-v2.html`（无 Last updated） | v2 语义权威 | 明确 "Do not use legacy top-level fields..." |
| 源码 `dev` 分支 | `research/src-agent-agent.ts` | **运行时语义权威** | 与官方 docs 有 2 处不一致（见 §6） |
| 本机 SDK 类型 | `.opencode/node_modules/@opencode-ai/sdk@1.18.32` | 本机生效 schema | 与线上 schema 不完全一致 |

### 1.1 线上 schema 的顶层 `Config` 键（实测 dump）

【观测】`research/config-schema.json` → `$defs.Config.properties` 共 28 个键：
`$schema, agent, attachment, autoshare, autoupdate, command, compaction, default_agent, disabled_providers, enabled_providers, enterprise, experimental, formatter, instructions, layout, logLevel, lsp, mcp, mode, model, permission, plugin, provider, reference, references, server, share, shell, skills, small_model, snapshot, subagent_depth, tool_output, tools, username, watcher`

**关键**：
- **有 `agent`（单数），没有 `agents`** → v2 的 `agents` 键在当前线上 schema 中**不存在**。
- **有 `permission`，没有 `permissions`**。
- **`reference` 标注 `@deprecated Use 'references' field instead.`**，`references` 是新字段。
- `mode` 标注 `@deprecated Use \`agent\` field instead.`。
- `small_model` 是**顶层字段**（description: *"Small model to use for tasks like title generation in the format of provider/model"*），**不在 `AgentConfig` 里**。

### 1.2 `subagent_depth` 的 schema 描述（逐字）

【观测】`config-schema.json` → `Config.properties.subagent_depth`：
```json
{ "minimum": 0, "type": "integer", "maximum": 9007199254740991,
  "description": "Maximum subagent nesting depth. Defaults to 1, which prevents subagents from launching subagents." }
```

### 1.3 `default_agent` 的 schema 描述（逐字）

【观测】`config-schema.json` → `Config.properties.default_agent`：
```json
{ "type": "string",
  "description": "Default agent to use when none is specified. Must be a primary agent. Falls back to 'build' if not set or if the specified agent is invalid." }
```
→ 与源码 `throw` 行为**冲突**，见 §6。

---

## 2. v1 `AgentConfig` 字段全表

来源：`research/config-schema.json` → `$defs.AgentConfig`（逐字字段 + description）。

| 字段 | 类型 | 默认值 | 废弃? | 含义 | 证据锚点 |
|---|---|---|---|---|---|
| `model` | string（`models.dev` Model） | primary 用全局配置；subagent 继承父 session 的 model | 否 | 覆盖该 agent 的模型，格式 `provider/model-id` | schema `$defs.AgentConfig.model`；v1 docs `Model` 节 Tip：*"If you don't specify a model, primary agents use the model globally configured while subagents will use the model of the primary agent that invoked the subagent."*；源码 `src-task-tool.ts:181-184` |
| `variant` | string | 无 | 否 | 默认 model variant，**仅在使用该 agent 自身配置的 model 时生效** | schema `variant.description`：*"Default model variant for this agent (applies only when using the agent's configured model)."*；源码 `src-task-tool.ts:209` |
| `temperature` | number | **模型自带默认** | 否 | 0.0–1.0。官方：*"typically 0 for most models, 0.55 for Qwen models"* | schema `temperature`；v1 docs `Temperature` 节末句 |
| `top_p` | number | 无 | 否 | 0.0–1.0，temperature 的替代多样性控制 | schema `top_p`；v1 docs `Top P` 节 |
| `prompt` | string | 无 | 否 | 自定义 system prompt。可为内联文本或 `{file:./prompts/x.txt}`。**Markdown agent 中由 body 填充** | schema `prompt`；v1 docs `Prompt` 节；源码 `src-config-agent.ts:27`（`prompt: md.content.trim()`） |
| `tools` | `{[k:string]: boolean}` | 无 | **是** `@deprecated Use 'permission' field instead` | `true` ≡ `{"*":"allow"}`，`false` ≡ `{"*":"deny"}`；支持 `"mymcp_*": false` 通配 | schema `tools.description`；v1 docs `Tools (deprecated)` 节逐字：*"In an agent's tools config, true is equivalent to `{"*": "allow"}` permission and false is equivalent to `{"*": "deny"}` permission."* |
| `disable` | boolean | `false` | 否（v1 字段名；v2 改名 `disabled`） | `true` 删除该 agent | schema `disable`；源码 `src-agent-agent.ts:268-271`（`if (value.disable) { delete agents[key]; continue }`） |
| `description` | string | 无 | 官方称"This is a required config option" | 何时用该 agent。**subagent 必填** —— 模型靠它选 agent | schema `description`；v1 docs `Description` 节；v2 docs：*"Add it to subagents because OpenCode shows it to the model choosing which agent to launch"* |
| `mode` | `"subagent"\|"primary"\|"all"` | **`all`**（v1 新建自定义 agent） | 否 | 见 §3 | schema `mode.enum`；源码 `src-agent-agent.ts:276`（`mode: "all"`）；v1 docs `Mode` 节：*"If no mode is specified, it defaults to all."* |
| `hidden` | boolean | `false` | 否 | 从 `@` 自动补全隐藏。**仅对 `mode: subagent` 生效** | schema `hidden.description` 逐字：*"Hide this subagent from the @ autocomplete menu (default: false, only applies to mode: subagent)"*；v1 docs `Hidden` 节：*"This only affects user visibility in the autocomplete menu. Hidden agents can still be invoked by the model via the Task tool if permissions allow."* |
| `options` | object | `{}` | 否 | 透传给 provider 的 model options（如 `reasoningEffort`、`textVerbosity`） | schema `options`；v1 docs `Additional` 节：*"Any other options you specify in your agent configuration will be passed through directly to the provider as model options."*；源码 `src-agent-agent.ts:292`（`mergeDeep(item.options, value.options ?? {})`） |
| `color` | `^#[0-9a-fA-F]{6}$` \| `primary\|secondary\|accent\|success\|warning\|error\|info` | 无 | 否 | UI 颜色。**v2 只接受六位 hex，不接受主题色名** | schema `color`；v2 docs `Color` 节：*"color sets the agent's UI color using a six-digit hex value"* |
| `steps` | integer > 0 | 无 | 否 | 最大 agentic 迭代数。到达上限时**移除 tools** 并要求模型输出文本总结 | schema `steps`；v1 docs `Max steps` 节；v2 docs `Steps` 节：*"On the final step, OpenCode removes tools and asks the model to summarize in text. New user input resets the allowance."* |
| `maxSteps` | integer > 0 | 无 | **是** `@deprecated Use 'steps' field instead.` | 同 `steps`。⚠️ **1.18.32 源码中该字段未被读取（静默失效）** | schema `maxSteps.description` 逐字；v1 docs Caution 节：*"The legacy maxSteps field is deprecated. Use steps instead."*；v1.18.32 tag `agent.ts` 覆盖循环只有 `item.steps = value.steps ?? item.steps`，**无 `maxSteps` 分支** |
| `permission` | `PermissionConfig` | 见 §4 base policy | 否 | 权限规则 map | schema `permission` → `$defs.PermissionConfig` |
| `name` | string | 由文件名/键推导 | 否（v1 源码接受但未在 schema 明列） | agent ID | 源码 `src-agent-agent.ts:290`（`item.name = value.name ?? item.name`） |

### 2.1 不属于 AgentConfig 的常见误认字段

| 字段 | 实际位置 | 证据 |
|---|---|---|
| `small_model` | **顶层 `Config`**，用于 title 生成等 | `config-schema.json` → `Config.properties.small_model`；`AgentConfig` 中**无**此字段 |
| `system` | **v2 专属**；v1 用 `prompt` 或 Markdown body | v2 docs `System` 节；v1 `AgentConfig` 无 `system` |
| `permissions`（数组） | **v2 专属**；v1 用 `permission` map | v2 docs `Permissions > Configure` 节 Warning |
| `request` | **v2 专属**（headers/body 覆盖），且 v2 文档自述 *"does not yet send them with model requests"* | v2 docs `Request` 节 Warning |
| `disabled` | **v2 专属**；v1 用 `disable` | v2 docs `Disabled` 节 |

---

## 3. `mode` 三值语义与默认值

| mode | 行为 | v1 官方表述 | v2 官方表述 |
|---|---|---|---|
| `primary` | 作为 session 主 agent。v1：可用 Tab / keybind 循环切换 | *"Primary agents are the main assistants you interact with directly."* | *"Runs as the main agent for a session."* |
| `subagent` | 仅在 child session 中通过 task/subagent 工具运行 | *"Subagents are specialized assistants that primary agents can invoke for specific tasks."* | *"Runs only in a child session through the subagent tool."* |
| `all` | 两者皆可 | — | *"Runs either as a primary agent or a subagent."* |

**默认值**：
- 【观测】v1 docs `Mode` 节：*"The mode option can be set to primary, subagent, or all. If no mode is specified, it defaults to all."*
- 【观测】源码 `research/src-agent-agent.ts:274-280`：新建自定义 agent 时写死 `mode: "all"`。
- 【观测】v2 docs `Mode` 节：*"When omitted on a new custom agent, it defaults to primary."*
- ⚠️ **v1 与 v2 默认值不同（`all` vs `primary`）** —— 这是升级迁移时最容易踩的坑：本仓库若不显式写 `mode`，v1 下新 agent 会同时出现在 Tab 切换链和 Task 目录里。

**v1 独有**：`modes/*.md`（复数目录）加载的 agent 被**强制**为 `mode: "primary"`。
【观测】`research/src-config-agent.ts:50-56`（`loadMode`）：`result[config.name] = { ...parsed.value, mode: "primary" as const }`；`research/src-config-config.ts:550-557` 在所有合并之后再把 `result.mode` 灌进 `result.agent` 并强制 primary。
⚠️ 顺序含义：`mode` 键**最后**生效，会覆盖同名 `agent` 键里写的 `mode`。

### 3.1 primary vs subagent 的"真实差别"（不只是 mode 值）

| 维度 | primary | subagent |
|---|---|---|
| 会话 | 用户直接对话的 session | **child session**（`parentID` 指向父 session） |
| 上下文 | 自身 session 的历史 | **fresh，不继承父历史**（可传 `task_id` 续接同一 child） |
| 谁可以启动 | 用户（Tab / keybind / `default_agent`） | 父 agent 通过 task 工具；或用户 `@` mention |
| `todowrite` | 可用 | **默认被 deny**（除非自身规则含 `todowrite`） |
| `task`（能否再派生子 agent） | 可用（受 `permission.task` 约束） | **默认被 deny**（除非自身规则含 `task`）+ 受 `subagent_depth` 约束 |
| `question` | build/plan 已 `allow` | base policy 是 `deny` |

【观测】`research/src-task-tool.ts:143-155`：
```ts
const childToolDenies = [
  ...(next.permission.some((rule) => rule.permission === "todowrite")
      ? [] : [{ permission: "todowrite", pattern: "*", action: "deny" }]),
  ...(next.permission.some((rule) => rule.permission === id)   // id === "task"
      ? [] : [{ permission: id, pattern: "*", action: "deny" }]),
  ...(cfg.experimental?.primary_tools?.map((permission) => ({ permission, pattern: "*", action: "deny" })) ?? []),
]
```

#### `debug agent` 的 `tools` 映射 ≠ subagent 能否再派生（重要澄清）

【观测】`research/src-permission-v1-bridge.ts:204-214` 的 `disabled()` 判定：
```ts
export function disabled(tools: string[], ruleset: PermissionV1.Ruleset): Set<string> {
  const edits = ["edit", "write", "apply_patch"]
  const reads = ["list_mcp_resources", "list_mcp_resource_templates", "read_mcp_resource"]
  return new Set(tools.filter((tool) => {
    const permission = edits.includes(tool) ? "edit" : reads.includes(tool) ? "read" : tool
    const rule = ruleset.findLast((rule) => Wildcard.match(permission, rule.permission))
    return rule?.pattern === "*" && rule.action === "deny"
  }))
}
```
→ `opencode debug agent` 的 `tools` 字段 = 用 **agent 自身** ruleset 跑 `disabled()`。**它不模拟 child session 的 ruleset**。

【观测】本机实测：
| agent | `tools.task` | agent 自身 ruleset 中的 `task` | child session 里**实际**的 `task` |
|---|---|---|---|
| `explore` | **false** | 无 `task` 规则，但有 `*: deny` → `findLast` 命中 `*`/deny → 隐藏 | deny |
| `general` | **true** | 无 `task` 规则 → `findLast` 落到 base 的 `*`/allow → 不隐藏 | **deny**（由 `deriveSubagentSessionPermission` 注入） |
| `plan` | **true** | 有 `task: { general: "deny" }` → 落到 base `*`/allow → 不隐藏 | — |
| `referee`（本仓库） | **false** | 有 `task: { "*": "deny" }` → 隐藏 | deny |

【观测】**"版本差异"假设已被排除**：webfetch 核验 `https://raw.githubusercontent.com/anomalyco/opencode/v1.18.32/packages/opencode/src/agent/subagent-permissions.ts`（HTTP 200），内容与 `dev` 分支**逐字节一致**；同 tag 的 `agent.ts`、`tool/task.ts`、`tool/task.txt` 亦与 `dev` 一致。

【推论】`general` 在 `debug agent` 里显示 `tools.task === true`，但它作为 subagent 被拉起时 child session 会被注入 `task/* deny`（除非显式声明 `task` 规则）。→ **`debug agent` 的 `tools` 映射不能用来判断 subagent 能否再派生子 agent。** 这解释了 v2 docs "general — cannot launch more subagents" 与本机输出的表面矛盾：两者都对，只是观测层面不同。

---

## 4. 权限模型：v1 map vs v2 有序规则表

### 4.1 v1 map 的编译过程（源码逐行）

【观测】`research/src-permission-v1-bridge.ts:186-198`：
```ts
export function fromConfig(permission: ConfigPermissionV1.Info) {
  const ruleset: PermissionV1.Rule[] = []
  for (const [key, value] of Object.entries(permission)) {
    if (typeof value === "string") {
      ruleset.push({ permission: key, action: value, pattern: "*" })
      continue
    }
    ruleset.push(
      ...Object.entries(value).map(([pattern, action]) => ({ permission: key, pattern: expand(pattern), action })),
    )
  }
  return ruleset
}
```
【观测】同文件 `:200-202`：
```ts
export function merge(...rulesets: PermissionV1.Ruleset[]): PermissionV1.Rule[] {
  return rulesets.flat()
}
```

**由此得到三条硬事实**：

1. **map 的 key 声明顺序 = 规则顺序**。`Object.entries` 保留插入顺序（字符串键），所以 YAML/JSON 里 `bash:` 下面 `*` 写在前还是最后，**直接决定 last-match-wins 的结果**。
2. **简写形式等价于 `{pattern: "*"}`**。`edit: deny` ≡ `edit: { "*": "deny" }`。
3. **合并 = 简单拼接（append）**，后来的 ruleset 排在后面 → 后者优先。

### 4.2 匹配算法（源码逐行，这是全篇最硬的证据）

【观测】`research/src-util-wildcard.ts`（全文 13 行）：
```ts
export function match(input: string, pattern: string) {
  const normalized = input.replaceAll("\\", "/")
  let escaped = pattern
    .replaceAll("\\", "/")
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".")

  if (escaped.endsWith(" .*")) escaped = escaped.slice(0, -3) + "( .*)?"

  return new RegExp("^" + escaped + "$", process.platform === "win32" ? "si" : "s").test(normalized)
}
```

**逐条解读**：

| 机制 | 结论 | 证据行 |
|---|---|---|
| 输入归一化 | `\` → `/`（Windows 路径兼容） | `.replaceAll("\\", "/")`（对 input） |
| pattern 归一化 | 同样 `\` → `/` | 第二次 `.replaceAll` |
| 转义 | `. + ^ $ { } ( ) \| [ ] \` 被转义 | `.replace(/[.+^${}()|[\]\\]/g, "\\$&")` |
| `*` | → `.*`（**可跨 `/`**） | `.replace(/\*/g, ".*")` |
| `?` | → `.`（恰好一个字符） | `.replace(/\?/g, ".")` |
| **末尾 `*` 特判** | `...*` 结尾时展开为 `( .*)?` —— **可选的"空格+参数"** | `if (escaped.endsWith(" .*")) escaped = escaped.slice(0,-3) + "( .*)?"` |
| 锚定 | `^...$` **全值匹配**，不是子串匹配 | `new RegExp("^" + escaped + "$", ...)` |
| 大小写 | **仅 win32 不敏感**（flags `"si"`）；macOS/Linux 是 `"s"` → **大小写敏感** | `process.platform === "win32" ? "si" : "s"` |
| dotAll | `s` flag → `.` 匹配换行 | 同上 |

**官方文档侧交叉验证**：
- v1 docs `Wildcards` 节：*"`*` matches zero or more of any character / `?` matches exactly one character / All other characters match literally"*
- v2 docs `Matching` 节：*"This pattern matches the entire normalized path. Backslashes are normalized to slashes, and matching is **case-insensitive on Windows**."*
- v1 docs `What "Ask" Does` 之后 Tip 节：*"`grep *` allows grep pattern file.txt, while `grep` alone would block it. Commands like `git status` work for default behavior but require explicit permission (like `git status *`) when arguments are passed."*

### 4.3 求值顺序：last-match-wins

【观测】`research/src-permission-v1-bridge.ts:29-39`：
```ts
export function evaluate(permission: string, pattern: string, ...rulesets: PermissionV1.Ruleset[]): PermissionV1.Rule {
  return (
    rulesets
      .flat()
      .findLast((rule) => Wildcard.match(permission, rule.permission) && Wildcard.match(pattern, rule.pattern)) ?? {
      action: "ask", permission, pattern: "*",
    }
  )
}
```
【观测】v2 内核 `research/src-permission-core-v2.ts:76-90` 完全同构（字段名为 `action`/`resource`/`effect`），兜底同样是 `effect: "ask"`。

**双条件同时匹配**：`Wildcard.match(permission, rule.permission)` **且** `Wildcard.match(pattern, rule.pattern)`。所以 `permission` 键本身也是通配的。

【观测】v1 docs `Note` 节逐字：*"Permission keys are matched as wildcard patterns against the underlying tool name, so the same syntax works for built-ins, custom tools, and MCP tools — for example `"mymcp_*": "deny"` denies every tool from an MCP server, and `"mymcp_search": "ask"` targets a single one."*

【观测】v1 docs `Task permissions` 节 Tip 逐字：*"Rules are evaluated in order, and the last matching rule wins. In the example above, `orchestrator-planner` matches both `*` (deny) and `orchestrator-*` (allow), but since `orchestrator-*` comes after `*`, the result is allow."*

### 4.4 多资源操作的聚合

【观测】`research/src-permission-core-v2.ts:148,157-160`：
```ts
return input.resources.some((resource) => evaluate(input.action, resource, rules).effect === "deny")  // denied()
...
const effect: Permission.Effect = effects.includes("deny") ? "deny" : effects.includes("ask") ? "ask" : "allow"
```
→ **deny > ask > allow**。
【观测】v2 docs 逐字：*"Operations may check several resources, such as a patch that touches multiple files. Any deny denies the operation; otherwise any ask asks; otherwise the operation is allowed."*

### 4.5 每条规则匹配的"对象"对照表

| 动作 / permission 键 | 匹配对象 | 证据 |
|---|---|---|
| `read` / `read`(v2) | 文件路径（workspace 内为 location-relative；外部为 canonical absolute） | v1 docs `Available Permissions`：*"read — reading a file (matches the file path)"*；v2 docs `Actions` 表 |
| `edit` / `edit`(v2) | 目标路径；覆盖 `edit` / `write` / `patch` | v1 docs：*"edit — all file modifications (covers edit, write, patch)"*；源码 `src-permission-v1-bridge.ts:205`（`const edits = ["edit","write","apply_patch"]`） |
| `glob` | **请求的 glob 模式本身**，不是匹配到的路径 | v2 docs：*"glob — Requested glob pattern"* |
| `grep` | **正则表达式本身**，不是搜索路径 | v1 docs：*"grep — content search (matches the regex pattern)"*；v2 docs：*"grep — Requested regular expression, not the search path"* |
| `bash` / `shell` | **解析后的命令串**（v1 docs：*"matches parsed commands like `git status --porcelain`"*；v2：*"Scanner-produced command string; compound commands may produce several"*）。**不是正则** | v1 docs `Available Permissions`；v2 docs `Actions` 表 |
| `task` / `subagent` | **目标 agent ID / subagent 名**，支持 glob | v1 docs：*"task — launching subagents (matches the subagent type)"*；源码 `src-task-tool.ts:120-123`（`patterns: [params.subagent_type]`）；v2 docs：*"subagent — Target agent ID"* |
| `skill` | skill 名，支持 glob | v1 docs：*"skill — loading a skill (matches the skill name)"* |
| `webfetch` / `websearch` | URL / 查询串 | v1 docs `Available Permissions` |
| `question` / `lsp` / `doom_loop` | 仅 `*`（非细粒度） | v1 docs：*"The remaining keys accept the shorthand action only."*；schema 中这 3 个是 `PermissionActionConfig` 而非 `PermissionRuleConfig` |
| `external_directory` | 目录边界（通常以 `/*` 结尾） | v1 docs `External Directories` 节；v2 docs：*"Canonical external directory boundary, normally ending in `/*`"* |
| MCP 工具 | `<server>_<tool>`，两侧非法字符转 `_` | v2 docs `Actions` 表：*"`<server>_<tool>` — `*` for an MCP tool; unsupported characters in both names become `_`"* |

### 4.6 `external_directory` 的 `~` / `$HOME` 展开规则

【观测】`research/src-permission-v1-bridge.ts:178-184`（完整实现）：
```ts
function expand(pattern: string): string {
  if (pattern.startsWith("~/")) return os.homedir() + pattern.slice(1)
  if (pattern === "~") return os.homedir()
  if (pattern.startsWith("$HOME/")) return os.homedir() + pattern.slice(5)
  if (pattern.startsWith("$HOME")) return os.homedir() + pattern.slice(5)
  return pattern
}
```

| 规则 | 结果 |
|---|---|
| 仅 `~/`、`$HOME/`、`$HOME`、`~` 会被展开 | 其他位置的 `$HOME` **不展开** |
| 展开发生在**配置加载期**（`fromConfig` 内），不是匹配期 | 运行期 pattern 已是绝对路径 |
| 只作用于 **pattern 侧**，不作用于 input 侧 | v1 docs：*"Home expansion (like `~/...`) only affects how a pattern is written."* |
| **shell/bash 的 pattern 不做 home 展开** | v2 docs：*"Shell resources remain raw command text and do not expand those values."* / *"Shell resources remain raw command text and are not home-expanded."* |

【观测】v1 docs `Home Directory Expansion` 节示例逐字：
```
~/projects/*  -> /Users/username/projects/*
$HOME/projects/* -> /Users/username/projects/*
~ -> /Users/username
```

### 4.7 内置 base policy（本机 1.18.32 实测）

【观测】`opencode debug agent build` 的 permission 数组前 9 条（去掉 external_directory 后）：
```
  0 *               | '*'     -> allow
  1 doom_loop       | '*'     -> ask
  2 question        | '*'     -> deny
  3 plan_enter      | '*'     -> deny
  4 plan_exit       | '*'     -> deny
  5 read            | '*'     -> allow
  6 read            | '*.env' -> ask
  7 read            | '*.env.*' -> ask
  8 read            | '*.env.example' -> allow
```
【观测】源码 `research/src-agent-agent.ts:119-137` 与之一致（`defaults` 定义），并注释 `// mirrors github.com/github/gitignore Node.gitignore pattern for .env files`。

【观测】v2 docs `Defaults` 节给出的 base policy 与 v1 **逐条一致**（除了 `*.env` 的 effect 在 v1 实测是 `ask`、v2 docs 写的也是 `ask`；v1 docs 的旧段落写成 `deny` —— 见 §6 差异 ③）。

本机第 3-5 条 external_directory 白名单（来自 `~/.config` 的 skills 目录）与源码 `src-agent-agent.ts:96-113` 的 `whitelistedDirs` 逻辑吻合：
```ts
const whitelistedDirs = [
  Truncate.GLOB,                                   // ~/.local/share/opencode/tool-output/*
  path.join(Global.Path.tmp, "*"),                 // /tmp/opencode/*
  ...skillDirs.map((dir) => path.join(dir, "*")),
  ...referenceDirs.map((dir) => path.join(dir, "*")),
]
```
【观测】源码 `research/src-agent-agent.ts:296-310`：每个 agent 末尾会再补一条 `external_directory: Truncate.GLOB → allow`，**除非显式写了 `external_directory: { Truncate.GLOB: "deny" }`**。→ **工具输出目录无法被普通配置关闭**。

---

## 5. 常见误配清单

| # | 误配 | 实际行为 | 正确写法 | 证据 |
|---|---|---|---|---|
| 1 | **`"*"` 写在具体规则之后** | 具体的 `allow` 被 `*` 的 `deny`/`ask` 覆盖 | `"*": "deny"` **必须在前** | `src-permission-v1-bridge.ts:34`（`findLast`）；v1 docs `Task permissions` Tip |
| 2 | **map 内 key 顺序被重排** | YAML/JSON 顺序即规则顺序，重排即改变语义 | 保持声明顺序，不依赖格式化工具排序 | `src-permission-v1-bridge.ts:188`（`Object.entries`） |
| 3 | **`"git status"` 想覆盖带参数调用** | 只匹配裸 `git status`；`git status --short` 落到 `*` 兜底 | `"git status*"` 或 `"git status *"` | `src-util-wildcard.ts`（末尾 `*` → `( .*)?`）；v1 docs Tip：*"Commands like git status work for default behavior but require explicit permission (like "git status *") when arguments are passed."* |
| 4 | **`"git status *"`（带空格）误以为不匹配裸命令** | **匹配裸 `git status`** —— 空格是可选的 | 两者等价 | 同上（`( .*)?` 中 ` ` 可选） |
| 5 | **用正则写 bash pattern** | 正则元字符被转义，`.` 变字面 `.` | 用简单通配 | `src-util-wildcard.ts:6`（`.replace(/[.+^${}()|[\]\\]/g, "\\$&")`） |
| 6 | **pattern 大小写写错** | **macOS/Linux 上大小写敏感**（flags 仅 `"s"`）；win32 才 `"si"` | 严格按实际大小写 | `src-util-wildcard.ts:12` |
| 7 | **以为 `*` 不能跨 `/`** | `*` → `.*`，**能跨 `/`** | 需要限制层级时用显式路径段 | `src-util-wildcard.ts:8` |
| 8 | **用 `?` 匹配多字符** | `?` → `.`，恰好一个字符 | 用 `*` | `src-util-wildcard.ts:9` |
| 9 | **在 bash pattern 里写 `~`** | 只有 `~/`、`$HOME/`、`$HOME`、`~` 开头才展开；`git ~/*` 不展开 | 别对 shell 用 home 语法 | `src-permission-v1-bridge.ts:178-184`；v2 docs |
| 10 | **给 subagent 加 `hidden: true` 却期望改变 Task 目录** | `hidden` 只影响 `@` 自动补全，不影响模型可见性 | 用 `permission.task: deny` 控制 Task 目录 | v1 docs `Hidden` 节；v2 docs：*"This controls visibility, not security. Use permissions to restrict behavior."* |
| 11 | **subagent 不写 `task` 规则却期望能派生子 agent** | 无规则 → 注入 `task/* deny`（dev 源码） | 显式写 `task: "allow"` 或 glob 表 | `src-task-tool.ts:147-149` |
| 12 | **`shell` / `subagent` 写进 v1 配置** | 未定义的动作名，永远不匹配 | v1 用 `bash` / `task` | v2 docs Warning：*"V1 uses different field and action names. In V2, use permissions, shell, and subagent instead of permission, bash, and task."* |
| 13 | **`color: "warning"` 在 v2** | v2 只接受六位 hex | v2 用 `color: "#ffb86b"` 之类 | v2 docs `Color` 节；schema `color` 的 pattern 分支 |
| 14 | **给所有 agent 写 `write: false` 期待禁编辑** | `edit` 才是正确 key；`write` 会作为**独立 permission 名**存在但不生效 | `edit: deny` | schema：`edit` 覆盖 write/edit/patch；`src-permission-v1-bridge.ts:205` |
| 15 | **以为全局 `permission` 会完全替换 agent 的** | 是**追加**，agent 规则在后 → agent 可覆盖全局 | 用 `deny` 做不可覆盖的硬禁止 | `src-agent-agent.ts:293`（`Permission.merge(item.permission, ...)`） |

---

## 6. 文档 vs 源码 / v1 vs v2 的已核实不一致

| # | 不一致 | 文档说法 | 源码/实测 | 影响 |
|---|---|---|---|---|
| ① | `default_agent` 无效值的处理 | v1 docs：*"If the specified agent doesn't exist or is a subagent, OpenCode will fall back to `"build"` with a warning."* | `src-agent-agent.ts:332-334` 三种情况全部 `throw`：`default agent "X" not found` / `is a subagent` / `is hidden` | 无效配置可能直接报错而非静默回落。**建议按源码写防御性配置** |
| ② | v2 docs 的 `default_agent` 回落链 | v2 docs：*"must exist, be visible, and support primary use. Otherwise OpenCode uses `build`, then the first visible primary-capable agent."* | 同上（dev 分支未实现） | v1→v2 迁移时行为会变 |
| ③ | `*.env` 的默认 effect | v1 docs `Defaults` 节示例写 `"*.env": "deny"` | 本机实测 `ask`；v2 docs base policy 也写 `ask` | 以 `ask` 为准（v1 docs 该段是过期示例） |
| ④ | `compaction` 的默认策略 | v2 docs：*"compaction — Keeps the base policy"* | 本机实测 `compaction` 追加了 `{"*":"*"}→deny`，即**全禁** | 与 v1 源码一致（`src-agent-agent.ts:220-233` 有 `"*": "deny"`）；v2 docs 表述存疑 |
| ⑤ | `general` 能否派生子 agent | v2 docs：*"General — cannot launch more subagents"*；v1 docs 无此约束 | `debug agent general` 的 `tools.task === true`（agent 级视图），但 v1.18.32 tag 的 `subagent-permissions.ts` 会给它注入 `task/* deny`（child session 视图） | **不是版本差异，是观测层面差异**。文档与源码一致，`debug agent` 输出不代表 child session |
| ⑥ | keybind 名称 | v1 docs `Usage` 节：*"your configured `switch_agent` keybind"* | 实际 keybind id 是 **`agent_cycle`**（默认 `tab`）与 `agent_cycle_reverse`（`shift+tab`）、`agent_list`（`a`） | 配置 keybind 时用 `agent_cycle` |
| ⑦ | `scout` 是否内置 | v1 docs：*"OpenCode comes with three built-in subagents, General, Explore, and Scout."* | 本机 `opencode agent list` **无 scout**；v2 docs 明确 *"V2 has no built-in scout agent."* | 不要依赖 `scout` |

---

## 7. 待验证 / 未定位项

| # | 项 | 状态 | 后续检索建议 |
|---|---|---|---|
| 1 | ~~`general` 的 `tools.task === true` 与注入 deny 的矛盾~~ | **✅ 已解决** | v1.18.32 tag 的 `subagent-permissions.ts` 与 `dev` 逐字节一致；矛盾源于 `debug agent` 只反映 agent 级 ruleset。详见 §3.1 |
| 1b | `debug agent` 是否有办法反映 child session 的有效权限 | **【待验】** | 未找到对应 CLI 子命令。唯一可靠途径是实际调用一次 subagent 并检查其 session 的 permission（需写入配置或发起会话，本次未做） |
| 2 | "从 Task 工具描述中移除该 subagent" 的实现位置 | **未定位到源码** | 当前 `dev` 的 `src-task-tool.txt` **不含 `{agents}` 占位符**，子 agent 目录应在别处注入。候选：`packages/opencode/src/session/prompt*`（本次 3 个候选路径全部 404/失败）。建议用 GitHub 代码搜索 `subagent_type` 或 `<available_agents>` |
| 3 | ~~`maxSteps` → `steps` 的兼容读取~~ | **✅ 已解决（且是坑）** | v1.18.32 tag 的 `agent.ts` 与 `dev` 一致，**只读 `value.steps`，没有 `value.maxSteps` 回退**。→ 写 `maxSteps` 在 1.18.32 **静默失效**，无警告。schema 仍标注 `@deprecated` 但代码已完全丢弃该字段 |
| 4 | 线上 `config-schema.json` 未收录 `plan_enter` / `plan_exit` | **【待验】** 是否会长期缺失 | 追踪 schema PR；本仓库不应依赖这两个键 |
