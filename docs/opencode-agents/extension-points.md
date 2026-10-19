# 扩展点清单：commands / custom tools / MCP / plugins+hooks / skills / references

> 抓取日期：2026-10-08 · 本机：`opencode 1.18.32`
> hook 清单来源：本仓库 `.opencode/node_modules/@opencode-ai/plugin/dist/index.d.ts`（版本 **1.18.32**）`Hooks` 接口，`:173-330`

---

## 1. Custom Commands

### 1.1 配置形态

【观测】`research/config-schema.json` → `Config.properties.command`（`additionalProperties: false`，**无通配扩展位**）：
```json
{ "template": "string", "description": "string", "agent": "string",
  "model": "string", "variant": "string", "subtask": "boolean" }
```
`required: ["template"]`。

| 字段 | 类型 | 必填 | 含义 | 证据 |
|---|---|---|---|---|
| `template` | string | **是** | 发送给 LLM 的 prompt 模板。Markdown 命令取 body | schema `required:["template"]`；v1 docs `Template` 节：*"This is a required config option."* |
| `description` | string | 否 | TUI 里输入命令时显示的说明 | v1 docs `Description` 节 |
| `agent` | string | 否 | **由哪个 agent 执行此命令** | v1 docs `Agent` 节逐字：*"Use the `agent` config to optionally specify which agent should execute this command. **If this is a subagent the command will trigger a subagent invocation by default. To disable this behavior, set `subtask` to false.** ... If not specified, defaults to your current agent."* |
| `model` | string | 否 | 覆盖命令的模型 | v1 docs `Model` 节 |
| `variant` | string | 否 | 模型 variant（**线上 schema 有，v1 docs 未提**） | schema `command.properties.variant` |
| `subtask` | boolean | 否 | **强制**以 subagent 方式触发 | v1 docs `Subtask` 节逐字：*"Use the `subtask` boolean to force the command to trigger a subagent invocation. This is useful if you want the command to not pollute your primary context and will force the agent to act as a subagent, **even if `mode` is set to `primary` on the agent configuration**."* |

【观测】SDK `dist/v2/gen/types.gen.d.ts:1928-1934` 的 `Command` 类型额外含 `source?: "command" | "mcp" | "skill"` 与 `hints: Array<string>`。

### 1.2 文件位置与命名

【观测】v1 docs `Markdown` 节：
- 全局：`~/.config/opencode/commands/`
- 项目：`.opencode/commands/`
- *"The markdown file name becomes the command name. For example, `test.md` lets you run `/test`."*

### 1.3 模板内的占位符

| 语法 | 含义 | 证据 |
|---|---|---|
| `$ARGUMENTS` | 全部参数 | v1 docs `Arguments` 节 |
| `$1` `$2` `$3` … | 位置参数 | v1 docs 同节 |
| `!`command`` | 注入 shell 输出（在**项目根目录**执行，输出成为 prompt 的一部分） | v1 docs `Shell output` 节逐字：*"Commands run in your project's root directory and their output becomes part of the prompt."* |
| `@filename` | 引用文件内容进 prompt | v1 docs `File references` 节逐字：*"Include files in your command using @ followed by the filename... The file content gets included in the prompt automatically."* |

### 1.4 与内置命令的关系

【观测】v1 docs `Built-in` 节：*"opencode includes several built-in commands like `/init`, `/undo`, `/redo`, `/share`, `/help`"* + Note：*"**Custom commands can override built-in commands.** If you define a custom command with the same name, it will override the built-in command."*

### 1.5 最小示例

`.opencode/commands/triage.md`：
```markdown
---
description: Triage an issue file and produce a structured brief
agent: probe
subtask: false
---

Triage the issue at $1.

Recent commits:
!`git log --oneline -10`

Relevant code: @src/index.ts
```
→ `/triage issue-123.md`。因 `agent: probe` 是 primary，需 `subtask: false` 才不会退化成 subagent 调用。

---

## 2. Custom Tools

### 2.1 v1（plugin `tool` 字段）

【观测】v1 docs `Custom tools` 节：plugins 通过 `return { tool: { mytool: tool({...}) } }` 注入。
【观测】`plugin/dist/tool.d.ts:47-59`：
```ts
export declare function tool<Args extends z.ZodRawShape>(input: {
    description: string;
    args: Args;
    execute(args: z.infer<z.ZodObject<Args>>, context: ToolContext): Promise<ToolResult>;
}): { description: string; args: Args; execute(...): Promise<ToolResult> };
export declare namespace tool { var schema: typeof z; }
export type ToolDefinition = ReturnType<typeof tool>;
```

### 2.2 `ToolContext`（custom tool 的运行时上下文）

【观测】`plugin/dist/tool.d.ts:2-33`（完整）：
```ts
export type ToolContext = {
    sessionID: string;
    messageID: string;
    agent: string;                     // ← 当前 agent 名！custom tool 可据此自检
    directory: string;                 // "Prefer this over process.cwd() when resolving relative paths."
    worktree: string;                  // "Useful for generating stable relative paths"
    abort: AbortSignal;
    metadata(input: { title?: string; metadata?: {...} }): void;
    ask(input: AskInput): Promise<void>;
};
type AskInput = {
    permission: string;                // ← 自定义 permission 名
    patterns: string[];
    always: string[];                  // ← "always" 批准时持久化的 pattern
    metadata: { [key: string]: any };
};
export type ToolResult = string | {
    title?: string; output: string; metadata?: {...};
    attachments?: Array<{ type: "file"; mime: string; url: string; filename?: string }>;
};
```

【判断】`ToolContext.ask()` 是 custom tool 实现**自身权限门**的标准手段：`permission` 名 + `patterns` 会走与内置工具完全相同的 `Wildcard.match` + `findLast` 通路，因此 `opencode.json` 里的 `permission: { mytool: { "*": "ask" } }` 能生效。

### 2.3 命名冲突

【观测】v1 docs `Custom tools` 节 Note 逐字：*"If a plugin tool uses the same name as a built-in tool, **the plugin tool takes precedence**."*

### 2.4 最小示例

`.opencode/plugins/my-tool.ts`：
```ts
import { type Plugin, tool } from "@opencode-ai/plugin"

export const MyTools: Plugin = async () => ({
  tool: {
    issue_get: tool({
      description: "Read one issue by number",
      args: { number: tool.schema.number() },
      async execute(args, ctx) {
        await ctx.ask({ permission: "issue_get", patterns: [String(args.number)], always: ["*"], metadata: {} })
        return `issue #${args.number} (dir=${ctx.directory}, agent=${ctx.agent})`
      },
    }),
  },
})
```
权限：`{ "permission": { "issue_get": { "*": "ask", "42": "allow" } } }`

### 2.5 v2 的 effect 化扩展点

【观测】`plugin/dist/v2/effect/agent.d.ts`（全文）：
```ts
export interface AgentDraft {
    list(): readonly AgentV2Info[];
    get(id: string): AgentV2Info | undefined;
    default(id: string | undefined): void;
    update(id: string, update: (agent: AgentV2Info) => void): void;
    remove(id: string): void;
}
export type AgentHooks = Hooks<{ transform: AgentDraft }>;
```
→ **v2 plugin 可以在配置加载后以 draft 形式改写 agent**：`update()` 改字段、`remove()` 删 agent、`default()` 改 `default_agent`。这是 v1 没有的能力。

【观测】`plugin/dist/v2/effect/reference.d.ts`（全文）：
```ts
export interface ReferenceDraft {
    add(name: string, source: ReferenceLocalSource | ReferenceGitSource): void;
    remove(name: string): void;
    list(): readonly (readonly [string, ReferenceLocalSource | ReferenceGitSource])[];
}
export type ReferenceHooks = Hooks<{ transform: ReferenceDraft }>;
```

---

## 3. MCP

### 3.1 配置形态

【观测】`config-schema.json` → `Config.properties.mcp`：`additionalProperties: { $ref: McpLocalConfig | McpRemoteConfig | { enabled: boolean } }`
【观测】v1 docs `Enable` 节逐字：*"You can also disable a server by setting `enabled` to false."*

| 类型 | 关键字段 | 证据 |
|---|---|---|
| `local` | `command: string[]`、`environment`、`enabled`、`timeout`（默认 **5000 ms**） | v1 docs `Options` 表逐字：*"timeout — Number — Timeout in ms for fetching tools from the MCP server. Defaults to 5000 (5 seconds)."* |
| `remote` | `url`、`enabled`、`headers`、`timeout`、`oauth` | 同上 |

### 3.2 MCP 工具的权限映射（关键）

| 版本 | permission 键形态 | 规则 |
|---|---|---|
| **v1** | 工具名本身就是 permission 键，支持通配 | v1 docs `Agents > Permissions` Note 逐字：*"Permission keys are matched as wildcard patterns against the underlying tool name, so the same syntax works for built-ins, custom tools, and MCP tools — for example `"mymcp_*": "deny"` denies every tool from an MCP server, and `"mymcp_search": "ask"` targets a single one."* |
| **v2** | `action` = `<server>_<tool>`，两侧非法字符转 `_` | v2 docs `Actions` 表逐字：*"`<server>_<tool>` — `*` for an MCP tool; unsupported characters in both names become `_`"* |

【观测】v1 docs `Manage` 节：`"tools": { "my-mcp-foo": false }` 是全局开关的官方写法（连字符原样保留，v1 直接用工具名）。
【观测】v1 docs `Manage` 节首句：*"Your MCPs are available as tools in OpenCode, alongside built-in tools. So you can manage them through the OpenCode config like any other tool."*

【观测】v2 docs `Actions` 表还列了 `execute` → `*`，注释：*"controls Code Mode availability, while nested tools enforce their rules"*。

### 3.3 最小示例

```jsonc
{
  "mcp": {
    "jira": { "type": "remote", "url": "https://jira.example.com/mcp", "enabled": true, "timeout": 10000 }
  },
  "permission": {
    "jira_getIssue": { "*": "ask", "JIRA-1": "allow" }
  }
}
```
（v1 语法。v2 写法：`{ "action": "jira_getIssue", "resource": "*", "effect": "ask" }`）

---

## 4. Plugins 与 Hooks

### 4.1 加载方式与顺序

【观测】v1 docs `Use a plugin` 节：
- 项目级：`.opencode/plugins/`
- 全局：`~/.config/opencode/plugins/`
- npm：`"plugin": ["opencode-helicone-session", "opencode-wakatime", "@my-org/custom-plugin"]`（支持 scoped）
- *"npm plugins are installed automatically using Bun at startup. Packages and their dependencies are cached in `~/.cache/opencode/node_modules/`."*

【观测】v1 docs `Load order` 节逐字（4 级顺序）：
> 1. Global config (`~/.config/opencode/opencode.json`)
> 2. Project config (`opencode.json`)
> 3. Global plugin directory (`~/.config/opencode/plugins/`)
> 4. Project plugin directory (`.opencode/plugins/`)
>
> *"Plugins are loaded from all sources and **all hooks run in sequence**. ... Duplicate npm packages with the same name and version are loaded once. However, a local plugin and an npm plugin with similar names are both loaded separately."*

【观测】`config-schema.json` → `Config.properties.plugin`：
```json
{ "type": "array", "items": { "anyOf": [ "string", ["string", {object}] ] } }
```
→ **plugin 项可以是 `string` 或 `[name, options]` 二元组**（本机 SDK `Config.plugin` 类型确认，`dist/v2/gen/types.gen.d.ts:1549-1554`）。

### 4.2 Plugin 函数签名

【观测】v1 docs `Basic structure` 节：`async ({ project, client, $, directory, worktree }) => ({ /* hooks */ })`

### 4.3 Hooks 全清单（**逐个列出**，来自本机 1.18.32 `plugin/dist/index.d.ts`）

| # | Hook 名 | 行号 | 用途（据签名与官方文档） |
|---|---|---|---|
| 1 | `dispose` | `:174` | `() => Promise<void>` —— 插件卸载/清理 |
| 2 | `event` | `:175-177` | `(input:{event: Event}) => Promise<void>` —— 订阅服务端事件总线。官方示例用 `session.idle` 发系统通知 |
| 3 | `config` | `:178` | `(input: Config) => Promise<void>` —— **改写解析后的配置**（可直接改 `agent` / `permission` / `command`）。**注意是就地 mutate，无返回值** |
| 4 | `tool` | `:179-181` | `{[key: string]: ToolDefinition}` —— 注册 custom tools（见 §2） |
| 5 | `auth` | `:182` | `AuthHook` —— 改写 provider 认证解析 |
| 6 | `provider` | `:183` | `ProviderHook` —— 改写 provider 解析 |
| 7 | `chat.message` | `:187-199` | `(input:{sessionID, agent?, model?, messageID?, variant?}, output:{message: UserMessage; parts: Part[]})` —— 新消息到达时改写 user message 与 parts |
| 8 | `chat.params` | `:203-215` | `(input:{sessionID, agent, model, provider, message}, output:{temperature, topP, topK, maxOutputTokens, options})` —— **改写发给 LLM 的采样参数**。官方注释：*"Modify parameters sent to LLM"* |
| 9 | `chat.headers` | `:216-224` | `(input:{...}, output:{headers: Record<string,string>})` —— 改写 HTTP headers |
| 10 | **`permission.ask`** | `:225-227` | `(input: Permission, output:{status:"ask"\|"deny"\|"allow"}) => Promise<void>` —— **权限审批决策钩子**。可在 UI 无人值守时自动放行 |
| 11 | `command.execute.before` | `:228-234` | `(input:{command, sessionID, arguments}, output:{parts: Part[]})` —— 命令执行前改写 parts |
| 12 | `tool.execute.before` | `:235-241` | `(input, output)` —— 工具执行前改写 args。官方两个示例：bash 命令转义、阻止读 `.env` |
| 13 | `shell.env` | `:242-248` | `(input, output:{env})` —— **注入环境变量到所有 shell 执行**（AI 工具 + 用户终端） |
| 14 | `tool.execute.after` | `:249-258` | `(input, output)` —— 工具执行后改写 result |
| 15 | `experimental.chat.messages.transform` | `:259-264` | `(input:{}, output:{messages: Array<{info, parts}>})` —— 改写整个消息数组（可增删消息） |
| 16 | `experimental.chat.system.transform` | `:265-270` | `(input:{sessionID?, model}, output:{system: string[]})` —— **改写 system prompt 数组**。v1 docs `Compaction hooks` 的 prompt 替换与 `agent.ts` 的 `PROMPT_GENERATE` 都经此 hook |
| 17 | `experimental.provider.small_model` | `:271-282` | `(input:{provider: ProviderV2}, output:{model?: ModelV2})` —— **改写 small_model 解析结果**（用于 title 等轻量任务） |
| 18 | `experimental.session.compacting` | `:283-295` | `(input:{sessionID}, output:{context: string[]; prompt?: string})` —— 定制压缩上下文。官方注释：*"`context`: Additional context strings appended to the default prompt / `prompt`: If set, replaces the default compaction prompt entirely"* |
| 19 | `experimental.compaction.autocontinue` | `:296-305` | `(input:{sessionID, agent, model, provider, message, overflow}, output:{enabled})` —— 压缩后是否追加 synthetic user "continue" 轮。官方注释：*"`enabled`: Defaults to `true`. Set to `false` to skip the synthetic user 'continue' turn."* |
| 20 | `experimental.text.complete` | `:306-315` | `(input:{sessionID, messageID, partID}, output:{text})` —— 改写完成的 text part |
| 21 | `tool.definition` | `:316-329` | `(input:{toolID}, output:{description, parameters})` —— **改写发给 LLM 的工具定义**（description 与 JSON schema）。官方注释：*"Modify tool definitions (description and parameters) sent to LLM"* |

**共 21 个 hook**（含 3 个非 hook 成员：`dispose` / `tool` / `config`，其中 `tool` 是对象不是函数）。

【观测】官方 v1 docs `Events` 节另列了**事件类型**（走 `event` hook 订阅），它们不是 hooks：
`command.executed`、`file.edited`、`file.watcher.updated`、`installation.updated`、`lsp.client.diagnostics`、`lsp.updated`、`message.part.removed`、`message.part.updated`、`message.removed`、`message.updated`、`permission.asked`、`permission.replied`、`server.connected`、`session.created`、`session.compacted`、`session.deleted`、`session.diff`、`session.error`、`session.idle`、`session.status`、`session.updated`、`todo.updated`、`shell.env`、`tool.execute.after`、`tool.execute.before`、`tui.prompt.append`、`tui.command.execute`、`tui.toast.show`。

### 4.4 结构化日志

【观测】v1 docs `Logging` 节：*"Use `client.app.log()` instead of `console.log` for structured logging"*
```js
await client.app.log({ body: { service: "my-plugin", level: "info", message: "...", extra: {...} } })
```
Levels：`debug` / `info` / `warn` / `error`。

### 4.5 外部依赖

【观测】v1 docs `Dependencies` 节：在配置目录放 `package.json`，OpenCode 启动时跑 `bun install`。
```jsonc
// .opencode/package.json
{ "dependencies": { "shescape": "^2.1.0" } }
```
⚠️ 本仓库的 `.opencode/` 已存在 `package.json` + `package-lock.json`，正是这个机制。

### 4.6 与 agent 编排直接相关的两个 hook（【判断】）

- **`permission.ask`**（`:225`）—— 可以实现"CI 无人值守时自动 allow 特定 `task`/`bash` 请求"。但要清楚：`--auto` 模式（v1 docs `Auto mode` 节）已经能做同样的事，且**显式 `deny` 仍然生效**。若两者都用，注意 hook 可能绕过用户的交互意图。
- **`tool.definition`**（`:316`）—— 可以改写 `task` 工具的 `description`，从而**在模型可见层面**影响它对 subagent 的选择。这是"软约束"，与 `permission.task` 的"硬约束"互补。

---

## 5. Skills

### 5.1 目录（6 处，全部实测于官方页面）

【观测】v1 docs `Agent Skills` 节：
| 作用域 | OpenCode 原生 | Claude 兼容 | agent 兼容 |
|---|---|---|---|
| 项目 | `.opencode/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md` |
| 全局 | `~/.config/opencode/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` | `~/.agents/skills/<name>/SKILL.md` |

【观测】本仓库实测存在：`.opencode/skills/{minimal-patch, log-analysis, issue-triage}/`

### 5.2 SKILL.md frontmatter（严格白名单）

【观测】v1 docs `Write frontmatter` 节逐字：*"Each `SKILL.md` must start with YAML frontmatter. **Only these fields are recognized:** `name` (required), `description` (required), `license` (optional), `compatibility` (optional), `metadata` (optional, string-to-string map). **Unknown frontmatter fields are ignored.**"*

| 字段 | 必填 | 校验规则 |
|---|---|---|
| `name` | **是** | 1–64 字符；小写字母数字 + 单连字符分隔；不以 `-` 开头/结尾；无连续 `--`；**必须与所在目录名一致**。正则：`^[a-z0-9]+(-[a-z0-9]+)*$` |
| `description` | **是** | 1–1024 字符 |
| `license` / `compatibility` / `metadata` | 否 | — |

### 5.3 skill 的发现与加载（prompt 层面）

【观测】v1 docs `Recognize tool description` 节逐字：*"OpenCode lists available skills in the skill tool description. Each entry includes the skill name and description:"*
```
<available_skills>
 <skill>
 <name>git-release</name>
 <description>Create consistent releases and changelogs</description>
 </skill>
</available_skills>
```
加载方式：`skill({ name: "git-release" })`

【观测】v1 docs `Create one folder per skill name` 节：*"It loads any matching `skills/*/SKILL.md` in `.opencode/` and any matching `.claude/skills/*/SKILL.md` or `.agents/skills/*/SKILL.md` along the way."*（沿目录向上查找）

### 5.4 skill 权限

【观测】v1 docs `Configure permissions` 节原文示例：
```json
{
  "permission": {
    "skill": { "*": "allow", "pr-review": "allow", "internal-*": "deny", "experimental-*": "ask" }
  }
}
```
| effect | 行为（官方表格逐字） |
|---|---|
| `allow` | Skill loads immediately |
| `deny` | **Skill hidden from agent, access rejected** |
| `ask` | User prompted for approval before loading |

【观测】同节末句：*"Patterns support wildcards: `internal-*` matches `internal-docs`, `internal-tools`, etc."*

【观测】v2 docs `Approvals` 节：*"skills and subagents propose their IDs"* —— "always" 批准时保存的是 ID。

### 5.5 额外 skill 搜索路径

【观测】`config-schema.json` → `Config.properties.skills`：
```json
{ "paths": ["string"], "urls": ["string"] }
```
description：*"Additional skill folder paths"*（`urls` 例：`https://example.com/.well-known/skills/`）

### 5.6 最小示例

```
.opencode/skills/issue-triage/SKILL.md
---
name: issue-triage
description: Structure a bug report into Observed/Expected/Reproduction/Root Cause/Evidence/Proposed Fix/Open Questions. Use when a user pastes an issue or error report.
---
（正文为具体工作流指令）
```

---

## 6. References

### 6.1 字段与形态

【观测】`config-schema.json`：
- `Config.properties.reference` → `@deprecated Use 'references' field instead. Named git or local directory references`
- `Config.properties.references` → `Named git or local directory references`
- 两者 `additionalProperties` 均为 `string | ConfigV2.Reference.Git | ConfigV2.Reference.Local`

| 形态 | 字段 | 证据 |
|---|---|---|
| 字符串简写 | 目录路径或 Git URL | v2 docs *Git URLs* 节：*"Use the string shorthand to follow the remote's default branch"* |
| `{repository, branch?, description?, hidden?}` | Git 引用，`repository` 必填，`additionalProperties: false` | schema `ConfigV2.Reference.Git` |
| `{path, description?, hidden?}` | 本地目录引用，`path` 必填，`additionalProperties: false` | schema `ConfigV2.Reference.Local` |

【观测】SDK v2 types `dist/v2/gen/types.gen.d.ts:5230-5243`（运行时权威）：
```ts
export type ReferenceLocalSource = { type: "local"; path: string; description?: string; hidden?: boolean };
export type ReferenceGitSource  = { type: "git"; repository: string; branch?: string; description?: string; hidden?: boolean };
export type ReferenceSource = ReferenceLocalSource | ReferenceGitSource;
```

### 6.2 行为要点（v2 docs `References` 节）

| 行为 | 官方逐字 |
|---|---|
| checkout 位置 | *"OpenCode normalizes each remote and stores one checkout per remote and branch under its global data directory. Without an explicit branch, the path uses this ..."*；*"An explicit branch adds an encoded `@<branch>` suffix"* |
| 加载时机 | *"...in the background when references load or reload and **after a new user prompt is** ..."*（后半句被搜索摘要截断，**【待验】**） |
| 失败隔离 | *"Clone or refresh failures do not stop other references from loading."* |
| `description` 的作用 | *"...description tells agents when a reference is relevant."* |
| `hidden` 的作用 | *"Set `hidden` to true to remove a reference from interactive client selectors... **hidden affects only interactive visibility.** The reference remains in the reference API and, when it has a description, in agent instructions."* |
| 附加方式 | *"Clients attach a reference by its root alias."* |

【观测】**references 会自动获得 external_directory allow**。源码 `research/src-agent-agent.ts:96-113` 的 `whitelistedDirs` 包含 `...referenceDirs.map((dir) => path.join(dir, "*"))`，其中 `referenceDirs` 来自 `Reference.Service.list()`（`:88-95`）。
【观测】`src-agent-agent.ts:88-90` 显示 reference 加载会**等待** `PluginV2` 的 `core/config-reference` 插件：*"yield\* (yield\* PluginV2.Service).wait(PluginV2.ID.make("core/config-reference"))"* —— 印证 §2.5 的 `ReferenceDraft` 扩展点。

### 6.3 最小示例

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "references": {
    "upstream": "https://github.com/sst/opencode",
    "sdk": { "repository": "https://github.com/anomalyco/opencode", "branch": "dev",
             "description": "OpenCode 自身源码，查内部机制时用", "hidden": true },
    "shared": { "path": "../shared-libs", "description": "跨仓共享的类型定义" }
  }
}
```
→ `shared/**` 无需再写 `external_directory` allow。

---

## 7. Rules / 项目指令（补充扩展点）

【观测】v1 docs `Rules` 页（`research/rules-v1.html`）—— 项目指令机制（`AGENTS.md` / `CLAUDE.md` 等）。
【观测】v2 docs `Config` 节提到 `instructions` 字段与 `AGENTS.md`，并明确 *"…field but does not load its entries; use `AGENTS.md` for instructions."*
【观测】`config-schema.json` → `Config.properties.instructions` 为 array 类型（`additionalProperties: false` 的顶层 Config 说明它是显式白名单之一）。

【推论】项目指令是**与 agent 并列的独立注入源**：v2 docs `System` 节明确 *"Project instructions, skills, references, and other instruction sources are **still added**"*（即使 agent 设置了 `system`）。→ 因此 `system`/`prompt` **不是**排他性的系统提示，agent 无法阻止项目指令进入上下文。
