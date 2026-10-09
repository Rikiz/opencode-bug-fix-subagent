# OpenCode 自定义 Agent 参考（v1 方言）

本文针对本仓库锁定的 **opencode v1** 配置方言写作（`@opencode-ai/plugin` 1.18.31，本机 CLI 实测 1.17.7）。字段清单以 `https://opencode.ai/config.json`（`$defs.AgentConfig` / `$defs.PermissionConfig`）为准并经本机 `opencode agent list` 实测校正。

> **版本警告**：opencode 目前同时存在两套不兼容的 agent 配置方言。v2 使用 `permissions` 数组、`shell`/`subagent` 工具名、`system` 字段，并**拒绝**未知 key；v1 则把未知 key 静默转发为 provider model options。本目录所有配置都是 v1。若将来升级到 v2，`permission`/`bash`/`task` 必须整体迁移，混用不会报错、只会静默失效。

## 1. 配置文件位置与优先级

agent 定义为 Markdown 文件，实际加载 glob 是 `{agent,agents}/**/*.md`——**单数与复数目录名都支持，复数是规范写法**，且递归（嵌套路径会并入 agent id，如 `agents/team/reviewer.md` → id `team/reviewer`）。

配置目录搜索顺序：

```
1. ~/.config/opencode
2. <cwd>/.opencode，然后逐级向上直到 git worktree 根（OPENCODE_DISABLE_PROJECT_CONFIG 可完全禁用）
3. ~/.opencode
4. $OPENCODE_CONFIG_DIR← 这四个里优先级最高
```

JSON 配置按来源**合并**而非替换（对象走 `mergeDeep`，`instructions` 数组去重）。

单个 agent id 内部的解析顺序：标量后者覆盖前者，但 **permission 规则是追加**（agent 自身的规则排在最后）。由于权限匹配是 `findLast`，把 `"*"` 放最前、例外放后面即可。

### 本目录的加载方式

多仓场景下 `opencode run --dir <目标仓>` 会从目标仓向上找配置，拿不到 `multi-fix-oc/.opencode`。解决办法是显式指定（**已实测**）：

```bash
OPENCODE_CONFIG=<abs>/multi-fix-oc/opencode.json \
OPENCODE_CONFIG_DIR=<abs>/multi-fix-oc/.opencode \
opencode run --agent repo-fixer --dir /abs/path/to/repo-a
```

`OPENCODE_CONFIG_DIR` 优先级最高，因此用它加载 agents，用 `OPENCODE_CONFIG` 加载权限兜底。

## 2. Frontmatter 字段全表

`AgentConfig` 的 JSON Schema **没有 `required` 数组**，即所有字段都是可选的（官方文档称 `description` 必填，与 schema 及实现不符）。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `description` | string | **唯一**进入模型视野的选择信号。无描述的 subagent 会被登记为"仅供用户手动调用" |
| `mode` | `subagent`\|`primary`\|`all` | 新建自定义 agent 默认 `all`。**`primary` 对 task 工具不可见** |
| `model` | `provider/model-id` | 不填则继承调用方模型 ID + provider |
| `variant` | string | 模型 variant（推理档位）。仅在 agent 自带 `model` 时生效。**未文档化但真实存在** |
| `temperature` | number | 未设置时用模型默认 |
| `top_p` | number | 配置键 `top_p` |
| `prompt` | string | **在 `.md` agent 中写 frontmatter 会被静默丢弃**，文件正文永远胜出。正文只在 `opencode.json` 里用 |
| `tools` | `{[k]: boolean}` | 已废弃，会被规范化成 permission 规则；显式 `permission` 优先 |
| `permission` | object | 见 §4。v1 支持 `read, edit, glob, grep, list, bash, task, external_directory, lsp, skill` 的对象形式，以及 `todowrite, question, webfetch, websearch, doom_loop` 的字符串形式；**额外任意 key 按工具名通配匹配**（用于 MCP 工具） |
| `disable` | boolean | 在加载链该位置直接删除该 agent |
| `hidden` | boolean | **v1 语义：仅从 `@` 自动补全菜单隐藏**。不移出模型可见目录，也不是安全控制 |
| `color` | `#RRGGBB` \| 主题色名 | 有正则约束 |
| `steps` | positive int | 最大 agentic 迭代数，最后一步强制只输出文本 |
| `maxSteps` | positive int | 已废弃但仍生效（归一化为 `steps`） |
| `options` | object | 深合并进 provider option bag。**未文档化** |
| `name` | string | 覆盖由文件名推导的 id。**未文档化** |
| 其他任意 key | any | 透传到 provider model options（`reasoningEffort: high` 等）。v1 未知 key 静默接受即由此而来 |

运行时结构 `Agent.Info`：`{ name, description?, mode, native?, hidden?, topP?, temperature?, color?, permission, model?, variant?, prompt?, options, steps? }`。

**注意**：pinned SDK 的 `AgentConfig` v1 类型比运行时滞后且权限形状更窄，不要以 SDK 类型为准。

## 3. mode 的选择后果

| mode | task 工具可见 | `--agent` / `@` 可用 |
| --- | --- | --- |
| `primary` | ✗ 从目录中过滤掉 | ✓ |
| `subagent` | ✓ | ✓ |
| `all` | ✓ | ✓ |

内置 `general`、`explore` 是 `subagent`；`build`、`plan`、`compaction`、`title`、`summary` 是 `primary`。因此父仓库的 `bug-fix` / `bug-fix-verifier` 是 `mode: primary`，只能通过 `opencode run --agent` 驱动，会话内无法互相调用。

本目录的分工因此是：`multi-repo-orchestrator` 用 `mode: all`（要出现在目录里才能派活），三个执行体用 `mode: subagent`。

## 4. 权限模型

规则是一个扁平有序数组 `{ permission, pattern, action }`，`action` ∈ `allow|ask|deny`。

- 字符串值 → `{permission: key, action: value, pattern: "*"}`
- 对象值 → 每个 pattern key 生成一条规则
- `evaluate` = `findLast(...)`，即**最后匹配者胜出，跨所有已合并 ruleset**
- 通配符：`*` 匹配任意长度，`?` 匹配单个字符

因此**永远把 `"*"` 放第一，例外放后面**。

### 关键机制差异

1. **工具隐藏 vs 调用时判定**：`disabled()` 只在最后匹配规则的 `pattern === "*"` 且 `action === "deny"` 时才隐藏工具。像 `{"*.env": "deny"}` 这样的细粒度拒绝**不会**隐藏 `read` 工具，只在调用时拒绝。
2. **`apply_patch` 与 `edit`/`write` 依模型而定**：在 OpenAI `gpt-*` 家族模型上，`edit` 和 `write` 会从工具列表移除，只留 `apply_patch`。三者都映射到 `permission.edit` 这个 key，所以**要放行 `permission.edit`，只放行 `permission.write` 会在 GPT-5 上失效**（父仓库 `bug-fix.md` 同时给了 `edit` 和 `write`，做法正确但冗余）。
3. **`ask` 不是安全约束**：`opencode --auto` 把所有 `ask` 变 `allow`。真约束必须用 `deny`。
4. **`bash` 权限不是安全边界**：匹配的是解析后的命令文本，`a && b`、`a; b`、管道都是绕过面。且 `rm`/`mv`/`sed -i`/`>` 重定向/`git checkout` 全部绕过 `permission.edit`。无人值守 agent 只能用 `"*": "deny"` + 显式白名单。

### bash 白名单范式

```jsonc
{
  "bash": {
    "*": "deny",
    "git status*": "allow",
    "git diff*": "allow",
    "npm test": "allow",
    "node --test*": "allow",
    "git push*": "deny",
    "rm -rf *": "deny",
    "curl*": "deny"
  }
}
```

**参数要自己写进 pattern**：`"grep"` 不放行 `grep foo file`，要写 `"grep*"` 或 `"grep *"`。同理 `"git status"` 不匹配 `git status --porcelain`。

### 真实内建默认权限（源码值，非文档值）

```ts
{ "*": "allow",
  doom_loop: "ask",
  external_directory: { "*": "ask", /* tmp, skillDirs, referenceDirs, 截断目录: allow */ },
  question: "deny",
  plan_enter: "deny", plan_exit: "deny",
  read: { "*": "allow", "*.env": "ask", "*.env.*": "ask", "*.env.example": "allow" } }
```

文档说 `.env` 是 `deny`，源码是 `ask`——**源码为准**。`question` 默认 `deny`（只有 `build`/`plan` 重新放行），所以无人值守 agent 若不显式 `question: allow` 就无法提问。

## 5. 子 agent 的上下文隔离与继承

隔离在**上下文**层面，不是沙箱：子 agent 运行在 child session（`parentID` 指向父会话），**全新上下文**，共享同一文件系统与 worktree。只有最后一条 assistant 消息的文本回传给父级，中间工具调用不回传。

| 维度 | 是否继承 |
| --- | --- |
| 模型 | ✓（自身无 `model` 时继承调用方 modelID + providerID） |
| 模型 `variant` | ✓，仅当自身无 `model` |
| 系统提示 | ✗ 被自身 `prompt` 替换 |
| AGENTS.md / instructions | ✓ |
| skills | ✓（按子 agent 自身权限过滤后重新求值） |
| 全局 permission 的 **deny** | ✓ **作为硬拒绝下传** |
| 全局 permission 的 external_directory | ✓ 下传 |
| 全局 permission 的 **allow/ask** | ✗ **不下传** |
| `todowrite` | ✗ 除非自身 ruleset 含该 key，否则自动 deny |
| `task`（继续嵌套） | ✗ 除非自身 ruleset 含该 key，否则自动 deny |
| session 历史 | ✗ 除非用 `task_id` 恢复 |
| MCP servers | ✓ 同一集合，指令按子 agent 权限重新过滤 |

**安全含义**：父级只贡献 `deny` 和 `external_directory` 规则，子 agent 的能力上限是 `max(自身配置, 全局 deny)`。这意味着**每个子 agent 必须自带完整的 allow-list，不能指望"继承"**。

**深度限制**：新版本的 `subagent_depth` 默认 `1`（primary → subagent 可以，subagent 再调子 agent 被拒），且它是**全局配置项，没有 agent 级字段**。

> **本机实测**：CLI 1.17.7 尚不支持 `subagent_depth`，写入 `opencode.json` 会直接报 `Unrecognized key: subagent_depth` 并拒绝加载。本目录已移除该键——深度 1 本就是默认行为，真正的护栏是三个 subagent 都不声明 `task` key（因此自动 deny）。

## 6. task 工具

参数：`description`（3-5 词，成为子会话标题）、`prompt`（必填）、`subagent_type`（必填）、`task_id`（恢复既有子会话）、`command`、`background`（需 `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`）。

工具描述 = 静态 `task.txt` + **运行时生成的 agent 目录**：

```ts
const items = (yield* agents.list()).filter((item) => item.mode !== "primary")
const filtered = items.filter((i) => Permission.evaluate("task", i.name, agent.permission).action !== "deny")
// → "- <name>: <description>"
```

推论：
- 只有 `subagent` 和 `all` 会被登记；`primary` 对模型不可见
- `description` 是**全部**选择信号，没有 embedding 或模糊匹配
- `permission.task: { "<name>": "deny" }` 会把该 agent **从目录中彻底移除**
- `hidden: true` **不会**移出目录
- 目录按名字字母序排列，与相关性无关
- `task.txt` 明确指示模型："若 agent 描述提到应主动使用，就应尽力在用户未要求时也使用"——所以 description 要写清触发场景

手工调用：`@<agent-name>`、`opencode run --agent <name>`、或 command 中 `agent: <name>` / `subtask: true`。用户始终可以用 `@` 调用任何 agent，即便 `permission.task` 拒绝了它。

## 7. Skill / Agent / Command 对比

| | Agent | Skill | Command |
| --- | --- | --- | --- |
| 粒度 | 完整 assistant profile | 按需加载的指令包 | 用户触发的 prompt 宏 |
| 文件 | `{agent,agents}/**/*.md` | `{skill,skills}/**/SKILL.md` | `{command,commands}/*.md` |
| 正文作用 | 成为**系统提示** | 不成为提示，由工具调用载入上下文 | 成为**用户提示模板** |
| 独立模型/工具 | ✓ | ✗（在调用方上下文用调用方工具） | 可选 |
| 发现方式 | 配置加载进 task 目录 | 系统提示里的 `<available_skills>` + `skill` 工具 | `/` 自动补全 |
| 调用 | task 工具 / `@` / `--agent` | `skill({ name })` | `/name $ARGUMENTS` |
| 按 agent 门禁 | — | `permission.skill` | — |

skill 发现位置：`<config dir>/skills/<name>/SKILL.md`，另外 `.claude/skills/` 与 `.agents/skills/` 也在扫描范围内；另有 `skills.paths` 与 `skills.urls` 配置。

skill frontmatter：**`name` 必填且必须等于所在目录名**，需匹配 `^[a-z0-9]+(-[a-z0-9]+)*$`、1-64 字符；**`description` 在实现中可选**（文档称必填）。`description` 限 1-1024 字符。跨位置重名 → 先出现者胜出并记 warning。`tools: { skill: false }` 会让 `<available_skills>` 整段消失。

被发现的 skill 目录会**自动加入 `external_directory` allow 列表**。

组合模式：agent 引用 skill；command 的 `agent: <subagent>` 会自动触发子任务，`subtask: false` 禁用、`subtask: true` 强制（即使目标是 `mode: primary`）。skill 自身没有工具，无法派生任何东西。

## 8. Gotchas 清单

**硬限制**
1. subagent 默认不能再调 subagent；`subagent_depth` 是全局项、无 agent 级覆盖。
2. `mode: primary` 对 task 工具不可见。
3. `.md` agent 的 frontmatter `prompt` 被静默丢弃，正文永远胜出。
4. `description` 实为可选；无描述的 subagent 几乎不会被模型选中。
5. agent `description` 无已文档化长度上限，但它**每一轮**都会注入 task 工具描述，冗长等于永久 token 成本。（provider/tool-description 层是否有硬限 —— **UNVERIFIED**）
6. v1 的 `hidden` 是装饰性的。
7. 子会话中 `todowrite` 与 `task` 自动 deny，除非自身 ruleset 显式声明。
8. `question` 默认 deny。
9. `gpt-*` 模型上 `edit`/`write` 被移除，只剩 `apply_patch`。
10. 父级 `allow` 不级联。
11. `--auto` 把 `ask` 变 `allow`，所以受限 agent 必须用 `deny`。
12. agent 目录会被自动写入 `.gitignore`（`node_modules`、`package.json`、`package-lock.json`、`bun.lock`、`.gitignore`）。

**本项目实测踩到的**
13. **frontmatter 里重复 key 会导致整个 agent 加载失败**。`repo-fixer.md` 最初把 `lsp: "allow"` 写了两次（一次在 `permission` 内、一次在顶层），YAML 解析报 `Map keys must be unique`，该 agent 直接从 `opencode agent list` 中消失——不报错在文件里，只表现为"agent 不存在"。已修正：YAML 解析应作为 CI 门禁。
14. **未文档化的 key 在旧版本会硬失败**。`subagent_depth` 在 1.17.7 上直接导致 `Configuration is invalid`。加任何新配置项前先确认 CLI 版本。
15. 子 agent 输出有损：只有最后一条文本回传。需要完整信息时让子 agent 写文件并回传路径。

**文档漂移（均以 schema/源码为准）**
16. `.env` 读取是 `ask` 不是 `deny`；`description` 必填性与 skill `description` 必填性与文档描述不符；`maxSteps` 文档称废弃但仍生效；`variant` 与 `name` 真实存在但未文档化；`opencode.ai/docs/agent-builders` 返回 **404**（脚手架是 `opencode agent create`）；文档中 `--path` 写单数 `.opencode/agent`，其余全部用复数。

**UNVERIFIED**：嵌套项目 `opencode.json` 的确切合并次序；`opencode --auto` 在各入口（TUI / run / GitHub Action）是否完全一致；MCP 工具**指令**过滤的确切语义（工具可见性已知，指令过滤未追到底）。

## 9. 脚手架与相关 CLI

```bash
opencode agent create    # 交互式：位置、描述、提示、权限
opencode agent list      # 列出解析后的 agent（含解析后的 permission 数组，是排错 frontmatter 的最快手段）
```

`opencode agent create` 非交互模式需同时给 `--path --description --mode --permissions`。`--permissions` 是来自 `bash, read, edit, glob, grep, webfetch, task, todowrite, websearch, lsp, skill` 的逗号分隔 allowlist，**未列出的一律写成 `deny`**。

`opencode run` 相关 flag：`--agent`、`--model`、`--variant`、`--command`、`--format json`、`--dir`、`-f/--file`。

相关环境变量：`OPENCODE_PERMISSION`（内联 JSON）、`OPENCODE_CONFIG_DIR`、`OPENCODE_CONFIG`、`OPENCODE_CONFIG_CONTENT`、`OPENCODE_DISABLE_PROJECT_CONFIG`、`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS`、`OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS`。

## 10. 本仓库的既有约定（保持一致）

- agents 用**复数**目录 `agents/`。
- 低 `temperature`（0.0–0.1）+ 显式 `steps` 上限 + `color`。
- 完整显式 `permission` allow-list，含 `webfetch: deny` 与 `task: deny`。
- 正文结构固定为 *角色 → 编号工作流 → 规则 → 输出契约*。
- skill 与 agent 提示分离，agent 按名字引用 skill。
- **不可信输入加固**在 agent 与 prompt 中各重复一次：issue、评论、日志、源码文本都是数据，不能授权命令、扩大范围或覆盖规则。
- 运行产物落 `.bugfix/runs/<run-id>/`，`prompt.txt` + `agent.json` + `verifier.json` + `validation.json`，保证可复跑。
- 命令一律用 argv 数组传给 `spawn`，不用 shell 字符串。

## 11. 来源

- https://opencode.ai/docs/agents · https://opencode.ai/docs/config · https://opencode.ai/docs/skills · https://opencode.ai/docs/permissions · https://opencode.ai/docs/tools · https://opencode.ai/docs/commands · https://opencode.ai/docs/mcp-servers · https://opencode.ai/docs/cli
- https://opencode.ai/config.json（`$defs.AgentConfig`、`$defs.PermissionConfig`、顶层 `subagent_depth`）
- 源码 `anomalyco/opencode`（`dev` 分支）：`src/agent/agent.ts`、`src/agent/subagent-permissions.ts`、`src/tool/task.ts`、`src/tool/registry.ts`、`src/permission/index.ts`、`src/config/{config,agent,paths}.ts`、`src/session/{prompt,system}.ts`、`src/skill/index.ts`
- 本机实测：`opencode --version` = 1.17.7；`opencode agent list`；`OPENCODE_CONFIG_DIR` 跨仓加载验证；`subagent_depth` 不被 1.17.7 接受；YAML 重复 key 导致 agent 静默消失
- 父仓现有实现：`.opencode/agents/bug-fix.md`、`.opencode/agents/bug-fix-verifier.md`、`.opencode/skills/{log-analysis,issue-triage}/SKILL.md`、`lib/{runner,issue-context}.js`、`bin/bug-fix.js`、`.bugfix/validation.json`