# 本机 1.18.32 实证记录

> 抓取日期：**2026-10-08**（UTC）
> 二进制：`/opt/homebrew/bin/opencode`（Homebrew 安装）
> 工作目录：`/Users/ruoqiaozheng/data/personal_apps/opencode-bug-fix-subagent`
> **全程只读**：仅执行 `--version` / `agent list` / `debug agent <name>` / `debug config` / `debug --help`，未修改任何 opencode 配置。

---

## 1. 版本与 CLI 能力面

```console
$ opencode --version
1.18.32
```

```console
$ opencode debug --help
debugging and troubleshooting tools
Commands:
  opencode debug config        show resolved configuration
  opencode debug lsp           LSP debugging utilities
  opencode debug rg            ripgrep debugging utilities
  opencode debug file          file system debugging utilities
  opencode debug scrap         list all known projects
  opencode debug skill         list all available skills
  opencode debug snapshot      snapshot debugging utilities
  opencode debug startup       print startup timing
  opencode debug agent <name>  show agent configuration details
  opencode debug v2            debug v2 catalog and built-in plugins
  opencode debug info          show debug information
  opencode debug paths         show global paths (data, config, cache, state)
  opencode debug wait          wait indefinitely (for debugging)
Options:
  -h, --help / -v, --version / --print-logs / --log-level [DEBUG|INFO|WARN|ERROR] / --pure
```

```console
$ opencode agent --help
manage agents
Commands:
  opencode agent create  create a new agent
  opencode agent list    list all available agents
```

【结论】本机有 `opencode debug v2`（v2 catalog / built-in plugins）但**默认 CLI 走 v1 配置层**。

---

## 2. `opencode agent list`（原始形态）

```console
$ opencode agent list
build (primary)
  [
  {
    "permission": "*",
    "action": "allow",
    "pattern": "*"
  },
  {
    "permission": "doom_loop",
    "action": "ask",
    "pattern": "*"
  },
  {
    "permission": "external_directory",
    "pattern": "*",
    "action": "ask"
  },
  {
    "permission": "external_directory",
    "pattern": "/Users/ruoqiaozheng/.local/share/opencode/tool-output/*",
    "action": "allow"
  },
  ...
```
（完整输出含 34–64 条规则/agent，**不再全量粘贴**；下方 §4 给出逐 agent 的关键切片。）

**agent 名称与 mode（提取自完整输出）**：

```
build (primary)
compaction (primary)
explore (subagent)
general (subagent)
plan (primary)
summary (primary)
title (primary)
probe (primary)
referee (subagent)
repair (primary)
```
**共 10 个**。其中 `probe` / `referee` / `repair` 来自本仓库 `.opencode/agents/`。

**输出格式要点**：`agent list` 的 JSON 字段名为 **`permission` / `action` / `pattern`** —— 这是 **v1 的 `{permission, pattern, action}` 三元组有序规则表**，即编译后的中间表示，与配置里的 `permission` map 是两回事。

---

## 3. `opencode debug config`（关键切片）

```console
$ opencode debug config
顶层键: ['$schema','agent','command','mcp','mode','plugin','provider','skills','small_model','username']
default_agent  = None
subagent_depth = None
agent keys     = ['probe','referee','repair']
'agents' 键存在? False
permission     = null
model          = None
small_model    = openrouter/z-ai/glm-5.3-flash
```

**关键读数**：
| 观察 | 含义 |
|---|---|
| **无 `agents` 键** | v2 的 `agents`（复数）在 1.18.32 **完全不生效** |
| **无顶层 `permission` / `permissions`** | 本仓库未设全局权限 |
| **无 `default_agent` / `subagent_depth`** | 均取默认值（fallback = 第一个可见非 subagent；depth = 1） |
| `mode` 键存在但为空 | v1 已加载 `mode` 容器（`result.mode ??= {}`，`src-config-config.ts:427`），本仓库未定义 |
| `small_model = openrouter/z-ai/glm-5.3-flash` | 来自用户级配置；用于 title 等轻量任务 |
| `agent keys = ['probe','referee','repair']` | `.opencode/agents/*.md` 已成功解析进 `cfg.agent`；**原生 agent 不出现在 `cfg.agent` 里**（它们在 `agent.ts` 中硬编码） |

---

## 4. `opencode debug agent <name>` 逐个切片

命令：`opencode debug agent <name> | jq`（本报告用 python 解析后筛选，**未修改任何配置**）。

### 4.1 通用形状

```json
{
  "name": "<id>",
  "mode": "primary" | "subagent",
  "options": {},
  "native": true|false,          // native=true → 内置硬编码；false → 来自配置/文件
  "prompt": "<system prompt 全文>",
  "description": "...",
  "temperature": 0.1,            // 仅显式配置时出现
  "color": "#RRGGBB",
  "steps": 80,
  "tools": { "invalid":…, "question":…, "bash":…, "read":…, "glob":…, "grep":…,
             "edit":…, "write":…, "task":…, "webfetch":…, "todowrite":…, "skill":… },
  "permission": [ { "permission":…, "pattern":…, "action":… }, … ]
}
```

### 4.2 本仓库 3 个 agent

| agent | `native` | `mode` | `description` | `temperature` | `color` | `steps` | permission 规则总数 |
|---|---|---|---|---|---|---|---|
| `probe` | false | primary | "Read-only issue locator: reproduce, trace, and explain the root cause without editing" | 0.1 | `#3498DB` | 40 | **52** |
| `repair` | false | primary | "Self-contained issue resolver: diagnose → minimal fix → independent review → retry once on FAIL, then hand off to user" | 0.1 | `#E74C3C` | 80 | **54** |
| `referee` | false | subagent | "Read-only independent reviewer: reviews diff and test evidence, returns PASS or FAIL" | 0.1 | `#2ECC71` | 25 | **50** |

**`task` 规则（决定性证据）**：

```
probe  : [{'permission': 'task', 'action': 'deny',  'pattern': '*'}]
repair : [{'permission': 'task', 'action': 'allow', 'pattern': '*'}]
referee: [{'permission': 'task', 'action': 'deny',  'pattern': '*'}]
```

**`edit` 规则**：
```
probe  : [{'permission':'edit','action':'deny','pattern':'*'}]
repair : [{'permission':'edit','action':'allow','pattern':'*'}]
referee: [{'permission':'edit','action':'deny','pattern':'*'}]
```

**`repair` 的 bash 规则尾部（agent 自身部分，按声明顺序）**：
```
{'permission':'bash','pattern':'*','action':'ask'}
{'permission':'bash','pattern':'git diff*','action':'allow'}
{'permission':'bash','pattern':'git log*','action':'allow'}
{'permission':'bash','pattern':'git show*','action':'allow'}
{'permission':'bash','pattern':'git status*','action':'allow'}
{'permission':'bash','pattern':'npm test*','action':'allow'}
{'permission':'bash','pattern':'npx vitest*','action':'allow'}
{'permission':'bash','pattern':'cargo test*','action':'allow'}
{'permission':'bash','pattern':'pytest*','action':'allow'}
{'permission':'bash','pattern':'go test*','action':'allow'}
{'permission':'bash','pattern':'node *','action':'ask'}
{'permission':'bash','pattern':'python *','action':'ask'}
```
→ **`"git diff*"` / `"npm test*"` 写法正确**：末尾 `*` 在 `Wildcard.match` 中展开为 `( .*)?`，可匹配无参数形式。

**`tools` 派生映射（`repair`）**：
```json
{"invalid":true,"question":true,"bash":true,"read":true,"glob":true,"grep":true,
 "edit":true,"write":true,"task":true,"webfetch":false,"todowrite":true,"skill":true}
```
→ `webfetch:false` 来自 frontmatter 的 `webfetch: "deny"`。**注意 `"invalid"` 这个 permission 键在官方 schema 中未收录**（见 §6）。

### 4.3 内置 agent（去掉 external_directory 后的完整非噪声规则）

**全部 agent 共有的 base policy（9 条）**：
```
  0  *                | '*'           -> allow
  1  doom_loop        | '*'           -> ask
  2  question         | '*'           -> deny
  3  plan_enter       | '*'           -> deny
  4  plan_exit        | '*'           -> deny
  5  read             | '*'           -> allow
  6  read             | '*.env'       -> ask
  7  read             | '*.env.*'     -> ask
  8  read             | '*.env.example' -> allow
```

**`explore`（subagent, native）— 22 条非 external_directory 规则**：
```
  0  *             | '*'        -> allow      ← base
  1  doom_loop     | '*'        -> ask
  2  question      | '*'        -> deny
  3  plan_enter    | '*'        -> deny
  4  plan_exit     | '*'        -> deny
  5  read          | '*'        -> allow
  6  read          | '*.env'    -> ask
  7  read          | '*.env.*'  -> ask
  8  read          | '*.env.example' -> allow
  9  *             | '*'        -> deny       ← agent 追加：先全禁
 10  grep          | '*'        -> allow
 11  glob          | '*'        -> allow
 12  list          | '*'        -> allow
 13  bash          | '*'        -> allow
 14  webfetch      | '*'        -> allow
 15  websearch     | '*'        -> allow
 16  read          | '*'        -> allow
  （+ 47 条 external_directory；总计 64）
```
`tools.task = false`、`tools.skill = false`、`tools.todowrite = false`、`tools.question = false`。
**无 `task` 规则** → 与 `src-task-tool.ts:147-149` 的"无规则即注入 deny"一致。

**`general`（subagent, native）— 10 条**：
```
  0..8 （base，同上）
  9   todowrite     | '*'        -> deny       ← agent 追加
  （+ external_directory；总计 34）
```
⚠️ **`tools.task = true`，且 permission 数组中无 `task` 规则。
⚠️ **这不是版本差异**：`debug agent` 的 `tools` 只反映 agent 级 ruleset（`Permission.disabled()`），不反映 child session。已用 webfetch 核验 `v1.18.32` tag 的 `subagent-permissions.ts` 与 `dev` 逐字节一致 → `general` 被拉起时 child session **会**被注入 `task/* deny`。详见 `frontmatter-and-permissions.md` §3.1。

**`plan`（primary, native）— 14 条**：
```
  0..8 （base）
  9   question      | '*'        -> allow
 10   plan_exit     | '*'        -> allow
 11   task          | 'general'  -> deny        ← ★ 按 subagent 名过滤的 task 规则
 12   edit          | '*'        -> deny
 13   edit          | '.opencode/plans/*.md'                       -> allow
 14   edit          | '../../../.local/share/opencode/plans/*.md'   -> allow
  （+ external_directory；总计 40）
```
★ **这是"v1 `permission.task` 支持按 subagent 名 glob"的官方一手证据**（内建于二进制，非用户配置）。
注意 #14 的 pattern 是 **worktree-relative**（`../../../.local/share/...`），因为 `src-agent-agent.ts:172` 用 `path.relative(ctx.worktree, ...)` 生成。

**`build`（primary, native）— 10 条**：
```
  0..8 （base）
  9   question      | '*'        -> allow
 10   plan_enter    | '*'        -> allow
  （+ external_directory；总计 34）
```
`tools`：`{invalid:true, question:true, bash:true, read:true, glob:true, grep:true, edit:true, write:true, task:true, webfetch:true, todowrite:true, skill:true}` —— **全部 true，无一条 deny**。

**`title` / `summary` / `compaction`（primary, native, hidden）— 10 条，形状相同**：
```
  0..8 （base）
  9   *             | '*'        -> deny       ← 全禁
```
`tools` 全部 `false`。`title` 额外带 `temperature: 0.5`（源码 `src-agent-agent.ts:237`）。

⚠️ **本机 `compaction` 是全禁**，与 v2 docs *"compaction — Keeps the base policy"* 矛盾（详见 `frontmatter-and-permissions.md` §6 差异 ④）。

---

## 5. 本机 SDK / plugin 类型定义行号锚点

路径根：`/Users/ruoqiaozheng/data/personal_apps/opencode-bug-fix-subagent/.opencode/node_modules/@opencode-ai/`
`@opencode-ai/sdk/package.json` version = **1.18.32**（与 CLI 一致）
`@opencode-ai/plugin/package.json` version = **1.18.32**

### 5.1 `sdk/dist/v2/gen/types.gen.d.ts`

| 行号 | 类型 | 关键内容 |
|---|---|---|
| **L58** | `PermissionRule` | `{ permission: string; pattern: string; action: PermissionAction }` |
| L57 | `PermissionAction` | `"allow" \| "deny" \| "ask"` |
| L63 | `PermissionRuleset` | `Array<PermissionRule>` |
| **L442–452** | `AgentPart` | `{ id; sessionID; messageID; type:"agent"; name: string; source?:{value;start;end} }` |
| **L1328** | `PermissionActionConfig` | `"ask" \| "allow" \| "deny"` |
| L1329–1331 | `PermissionObjectConfig` | `{ [key: string]: PermissionActionConfig }` |
| L1332 | `PermissionRuleConfig` | `PermissionActionConfig \| PermissionObjectConfig` |
| **L1333–1350** | `PermissionConfig` | `PermissionActionConfig \| { read?, edit?, glob?, grep?, list?, bash?, **task?**, external_directory?, todowrite?, question?, webfetch?, websearch?, lsp?, doom_loop?, skill?, [k:string]: … }` |
| **L1351–1379** | `AgentConfig` | `model?; variant?; temperature?; top_p?; prompt?; tools?:{[k]:boolean}; disable?:boolean; description?; mode?:"subagent"\|"primary"\|"all"; hidden?:boolean; options?:object; color?:…; steps?:number; maxSteps?:number; permission?:PermissionConfig; [k:string]:unknown` |
| **L1520–…** | `Config` | 含 `command?`, `skills?`, `references?`, `reference?`, `model?`, `small_model?`, **`default_agent?`**, **`subagent_depth?`**, `mode?:{build?,plan?}`, **`agent?:{plan?,build?,general?,explore?,title?,summary?,compaction?}`**, `provider?`, `mcp?`, `experimental?:{disable_paste_summary?, batch_tool?, openTelemetry?, primary_tools?, continue_loop_on_deny?, mcp_timeout?, policies?}` … |
| — | **`Config` 中无 `agents`、无顶层 `permissions`** | ← 决定性：v2 配置键在 1.18.32 不存在 |
| **L1936–1956** | `Agent` | `{ name; description?; mode:"subagent"\|"primary"\|"all"; native?:boolean; hidden?:boolean; topP?:number; temperature?:number; color?:string; **permission: PermissionRuleset**; model?:{modelID;providerID}; variant?:string; prompt?:string; options:{[k]:unknown}; steps?:number }` |
| L1928–1934 | `Command` | `{ command?; agent?:string; model?:string; source?:"command"\|"mcp"\|"skill"; template:string; subtask?:boolean; hints:Array<string> }` |
| **L3164** | `AgentColor` | `string \| "primary"\|"secondary"\|"accent"\|"success"\|"warning"\|"error"\|"info"` |
| L3165 | `PermissionV2Effect` | `"allow" \| "deny" \| "ask"` |
| **L3166–3170** | `PermissionV2Rule` | `{ action: string; resource: string; effect: PermissionV2Effect }` |
| **L3171** | `PermissionV2Ruleset` | `Array<PermissionV2Rule>` |
| **L3172–3182** | `AgentV2Info` | `{ id: string; model?:ModelRef; request:ProviderRequest; system?:string; description?:string; mode:"subagent"\|"primary"\|"all"; hidden:boolean; color?:AgentColor; steps?:number; **permissions: PermissionV2Ruleset** }` |
| L3183–… | `SessionV2Info` | `{ id; **parentID?:string**; projectID; **agent?:string**; model?:ModelRef; cost; tokens; time; title; location; subpath?; revert? }` |
| L3225–3234 | `SessionMessageAgentSwitched` | `{ id; metadata?; time.created; type:"agent-switched"; **agent: string** }` |
| L3412 | `SessionMessage` | 联合类型，含 `AgentSwitched` |
| L1746–1748 | `ExperimentalCapabilities` | `{ backgroundSubagents: boolean }` |
| L5230–5243 | `ReferenceLocalSource` / `ReferenceGitSource` / `ReferenceSource` | 见 `extension-points.md` §6.1 |

### 5.2 `sdk/dist/gen/types.gen.d.ts`（**v1** gen，字段更少）

| 行号 | 类型 | 差异 |
|---|---|---|
| **L835–877** | `AgentConfig`（v1） | 字段：`model?; temperature?; top_p?; prompt?; tools?; disable?; description?; mode?; color?:string; maxSteps?:number; permission?:{edit?;bash?;webfetch?;doom_loop?;external_directory?}` |
| — | **`permission` 内联类型只声明 5 个键** | **无 `task`、无 `skill`、无 `read`、无 `list`**；但 `[key:string]` 索引签名允许任意键 → 能写 `task`，只是无类型提示 |
| — | **无 `variant`、无 `steps`、无 `hidden`、无 `options`** | 与 v2 gen 的 `AgentConfig` 差异明显 |
| L467–492 | `Session`（v1） | **无 `agent` 字段**；有 `parentID?` |

> ⚠️ **这是最容易踩的类型坑**：`AgentConfig` 在两个 gen 文件里同名但内容不同。`tsc` 若引用 `@opencode-ai/sdk`（无 `/v2`）会看到 5 键 permission 且不认识 `steps` / `variant` / `hidden`。

### 5.3 `plugin/dist/index.d.ts` — `Hooks` 接口（`:173–329`，共 21 个成员）

行号见 `extension-points.md` §4.3 的完整表格。最相关的 5 个：
| 行号 | Hook | 签名要点 |
|---|---|---|
| `:178` | `config` | `(input: Config) => Promise<void>` —— **就地 mutate** |
| `:225` | `permission.ask` | `(input: Permission, output:{status:"ask"\|"deny"\|"allow"}) => Promise<void>` |
| `:203` | `chat.params` | `output: { temperature; topP; topK; maxOutputTokens; options }` |
| `:316` | `tool.definition` | `(input:{toolID}, output:{description; parameters})` |
| `:179` | `tool` | `{[key:string]: ToolDefinition}` |

### 5.4 `plugin/dist/tool.d.ts`

| 行号 | 内容 |
|---|---|
| `:2–33` | `ToolContext` = `{ sessionID; messageID; **agent**; directory; worktree; abort; metadata(); ask(AskInput) }`；`AskInput` = `{ permission: string; patterns: string[]; **always**: string[]; metadata }` |
| `:41–46` | `ToolResult` = `string \| { title?; output; metadata?; attachments? }` |
| `:47–59` | `declare function tool<Args>(input:{description; args: Args; execute(args, ctx: ToolContext): Promise<ToolResult>})` + `namespace tool { var schema: typeof z }` |

### 5.5 v2 effect 扩展点

| 文件 | 内容 |
|---|---|
| `plugin/dist/v2/effect/agent.d.ts` | `AgentDraft { list(); get(id); **default(id\|undefined)**; **update(id, cb)**; **remove(id)** }`；`AgentHooks = Hooks<{transform: AgentDraft}>` |
| `plugin/dist/v2/effect/reference.d.ts` | `ReferenceDraft { **add**(name, source); **remove**(name); list() }` |

### 5.6 `opencode debug v2`（存在但本次未深挖）

`opencode debug v2` 可打印 v2 catalog 与 built-in plugins —— **【待验】** 建议用它直接读出 1.18.32 内置的 v2 plugin 清单（`core/config-reference` 等）。

---

## 5.7 tag 级源码交叉验证（webfetch，HTTP 200）

| 文件 | tag URL | 结果 |
|---|---|---|
| `agent/subagent-permissions.ts` | `https://raw.githubusercontent.com/anomalyco/opencode/v1.18.32/packages/opencode/src/agent/subagent-permissions.ts` | 与 `dev` **逐字节一致**（27 行） |
| `agent/agent.ts` | `.../v1.18.32/packages/opencode/src/agent/agent.ts` | 内容与 `dev` 一致；**内置 agent 仅 build/plan/general/explore/compaction/title/summary，无 scout**；**只有 `value.steps`，无 `maxSteps`**；`defaultInfo()` 三种情况全 `throw` |
| `tool/task.ts` | `.../v1.18.32/packages/opencode/src/tool/task.ts` | **14200 字节，与 `dev` 逐字节一致**（sha256 前12 `db09fa5868ad`） |
| `tool/task.txt` | `.../v1.18.32/packages/opencode/src/tool/task.txt` | **2305 字节，与 `dev` 一致** |

⚠️ **tag 命名带 `v` 前缀**：`v1.18.32` 有效；`1.18.32` 返回 **404**。

### 5.8 补充观测（`opencode debug config` 非敏感字段）

```
plugin      = []
skills      = {"paths": ["/Users/ruoqiaozheng/.config/opencode/skills"]}
mcp keys    = ['gitnexus', 'japicmp']
command keys = []
```
| 读数 | 含义 |
|---|---|
| **`plugin = []`** | **未配置任何 plugin** → 证明 `scout` 不是本机缺失的插件提供的；结合 v1.18.32 tag 源码无 scout，可断定 **1.18.32 无 scout** |
| `skills.paths` | 用户级 skill 搜索路径（与 `skillDirs` → `external_directory` 白名单对应） |
| `mcp keys = ['gitnexus','japicmp']` | 2 个 MCP server → 对应 permission 名 `gitnexus_*` / `japicmp_*` |
| `command keys = []` | 未定义自定义 command |

---

## 6. 未解决问题（本次调研未能双证）

| # | 问题 | 阻塞原因 | 建议下一步 |
|---|---|---|---|
| ~~1~~ | ~~`general` 的 `tools.task === true` 与源码矛盾~~ | **✅ 已解决** | 已 webfetch 核验 `v1.18.32` tag 的 `subagent-permissions.ts`（HTTP 200，与 `dev` 逐字节一致）。矛盾源于 `debug agent` 只反映 agent 级 ruleset，非版本差异 |
| 1b | **是否有 CLI 手段查看 child session 的有效 permission** | 未找到。`debug agent` 只给 agent 级视图 | 实际发起一次 subagent 调用后读其 session；或用 `permission.ask` plugin hook 打印 `input.ruleset`（**属写操作，本次未做**） |
| 2 | **"deny 时从 Task 工具描述中移除 subagent" 的实现位置未定位** | `dev` 分支的 `src-task-tool.txt` **不含 `{agents}` 占位符**；3 个候选 prompt 文件路径全部 404 | GitHub 代码搜索 `subagent_type` / `<available_agents>` / `TaskTool` description 拼接处 |
| ~~3~~ | ~~`maxSteps` 兼容读取未定位~~ | **✅ 已解决（是坑）** | v1.18.32 tag 的 `agent.ts` 与 `dev` 一致，**只有 `value.steps`，无 `maxSteps` 分支** → `maxSteps` 在 1.18.32 静默失效 |
| 3b | `maxSteps` 静默失效是否有 deprecation warning | 未验证（schema 仍标 `@deprecated`，源码已完全丢弃） | 需实际写一个带 `maxSteps` 的 agent 并看启动日志 —— **涉及写入配置，本次未做** |
| 4 | **`plan_enter` / `plan_exit` 未被官方 schema 收录** | 线上 `config-schema.json` 的 `PermissionConfig` 无此二键 | 追踪 schema PR；本仓库不应依赖 |
| 5 | **`compaction` 默认策略文档矛盾** | v2 docs 说"keeps base policy"，实测全禁 | 以实测为准；等待 v2 文档修订 |
| 6 | **`references` 加载时机的完整表述** | v2 docs 该句被搜索摘要截断（*"…after a new user prompt is…"*） | 直接 webfetch `research/references-v2.html` 的 References 节完整段落 |
| 7 | **`opencode debug v2` 的输出结构** | 本次未执行（避免不确定性） | 单独跑一次并归档输出 |
| 8 | **仓库名 `sst/opencode` → `anomalyco/opencode` 的迁移时点** | 两个 raw URL 返回**完全相同**的 14200 字节 task.ts（已交叉验证），无法判断何时切换 | GitHub redirect 链 / releases 页 |

---

## 7. 安全合规记录

本次调研**未**读取、未打印以下任何含明文密钥的文件：
`~/.local/share/opencode/auth.json`、`~/.local/share/opencode/account.json`、`~/.config/opencode/opencode.json`

`opencode debug config` 的输出已被裁剪为**键名与非敏感值**；若输出中曾包含 provider 凭据，本报告不引用。

**未执行**：任何 `npm install` / `bun add` / git 写操作 / 网络写请求 / opencode 配置写入。
**执行的全部命令**：`opencode --version`、`opencode debug --help`、`opencode agent --help`、`opencode agent list`、`opencode debug agent {repair,probe,referee,explore,general,plan,build,title,summary,compaction}`、`opencode debug config`。
**网络**：仅 `webfetch` / `websearch`（读）+ `curl` GET（下载文档快照到 `docs/opencode-agents/research/` 与 `/tmp`）。
