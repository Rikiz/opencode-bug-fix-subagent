# OpenCode 自定义 Agent 机制全貌（调研报告）

> 抓取日期：**2026-10-08**（UTC）
> 本机版本：`opencode --version` → **1.18.32**（`/opt/homebrew/bin/opencode`，Homebrew 安装）
> 官方 v1 文档页 footer：**Last updated: Oct 7, 2026**（9 个 v1 页面一致）
> 官方 v2 文档页 footer：**无 "Last updated" 标记**（`/v2/docs/*` 页面结构不同）

---

## 0. 证据边界声明（务必先读）

本报告每条结论都标注证据等级。请按等级决定是否可直接用于工程决策。

| 等级 | 含义 | 标注方式 |
|---|---|---|
| **【观测】** | 本机 1.18.32 只读命令输出，或官方页面/源码逐字原文 | 附命令输出片段或 `文件:行号` |
| **【推论】** | 由两条以上【观测】推导，推理链写在文中 | 显式写出前提 |
| **【判断】** | 工程/设计取舍建议，非事实陈述 | 显式标注"建议" |
| **【待验】** | 假设，尚未双证 | 列入 `verified-facts.md` 未解决问题 |

**本次调研的双证标准**：官方依据 URL + 本机实证输出/源码行号，两者齐备才算【观测】。单边来源一律显式标注。

**重要边界**：

- 本机 1.18.32 使用 **v1 配置 schema**（`agent` / `permission` map）。**v2 的 `agents` / `permissions` 有序数组在本机不生效** —— 已由 `opencode debug config` 实测确认（无 `agents` 键）。
- 但 **1.18.32 的 SDK 内部已内置完整 v2 类型**（`PermissionV2Rule`、`AgentV2Ruleset`、`AgentV2Info`、`AgentDraft`），说明 v2 处于"代码已就位、配置层未切换"的过渡态。详见 §3。
- 线上 `https://opencode.ai/config.json`（权威 JSON Schema）**当前仍是 v1 形态**（含 `AgentConfig.permission`、`AgentConfig.disable`、`task` 键），但已混入 `ConfigV2.Reference.Git/Local`、`Policy.Effect` 等 v2 定义 —— 是一个**过渡期混合 schema**。详见 `frontmatter-and-permissions.md` §1。

---

## 1. Agent 心智模型（一句话版）

**Agent = 一份具名的「系统提示词 + 模型偏好 + 有序权限规则表 + 展示元数据」的助手档案。**

四层叠加：

```
Agent
├── 身份层  mode (primary | subagent | all) + description + name
├── 认知层  prompt (system prompt) + model/variant + temperature/top_p + options
├── 约束层  permission  ← 有序规则表，last-match-wins
└── 展示层  color / hidden / steps（成本闸门）
```

**"上下文"不是 Agent 的属性，是 Session 的属性。** 这是最重要的心智模型修正：

- Agent 定义本身**不含任何对话历史**。
- 每个 session 绑定一个 agent。
- Subagent 调用时**创建 child session**，child 有独立的 message 序列 → **fresh context，不继承父会话上下文**。
  - 【观测】`research/src-task-tool.txt`（官方 `packages/opencode/src/tool/task.txt`）Usage notes 第 4 条原文：*"Each agent invocation starts with a fresh context unless you provide `task_id` to resume the same subagent session (which continues with its previous messages and tool outputs)."*
  - 【观测】`research/src-task-tool.ts:156-172`：`sessions.create({ parentID: ctx.sessionID, agent: next.name, ... })` —— 新建 session，不是复用父 session。
- 唯一"继承"的是：① 模型（subagent 未配 `model` 时继承父 assistant message 的 model）；② variant（仅当 subagent 未配 model）；③ **父 session 的 deny 规则 + external_directory 规则**。见 §2 关键结论 6 与 `dispatch-and-sessions.md` §3。

---

## 2. 10 问速查表

| # | 问题 | 结论 | 主要证据 |
|---|---|---|---|
| 1 | `mode` 取值/默认值？primary vs subagent 差别？context 继承吗？ | `primary` \| `subagent` \| `all`；**v1 新建自定义 agent 默认 `all`**；**context 不继承**（fresh child session） | v1 docs `Mode` 节 / `research/src-agent-agent.ts:276` / `research/src-task-tool.txt:4` |
| 2 | frontmatter 全字段 | v1 权威 15 个字段（含 2 个 deprecated）；`small_model` **不是** agent 字段而是顶层 Config 字段；`system` 是 v2 专属 | `research/config-schema.json` `$defs.AgentConfig` |
| 3 | v1 map vs v2 有序表 | v1 map **编译期被 `fromConfig()` 拍平成有序数组**；规则顺序 = map 的 key 声明顺序；last-match-wins；未匹配 → v1 走内置 base，v2 走 `ask` | `research/src-permission-v1-bridge.ts:186-202` + `:29-39`；`research/src-permission-core-v2.ts:76-90` |
| 4 | `permission.task` 能否按 subagent 名 glob？ | **能**，官方有 glob 示例原文；`deny` 时该 subagent 从 Task 工具描述中移除 | v1 docs `Task permissions` 节 / `research/src-task-tool.ts:120-128` |
| 5 | 注册优先级 / 合并规则 | 内置 → 全局 `~/.config/opencode/agents/` → 项目 `.opencode/agents/` → json `agent` 键 → json `mode` 键（强制 primary）；标量覆盖、`options` 深合并、`permission` **追加** | `research/src-config-config.ts:473-475,550-557` + `src-agent-agent.ts:267-294` |
| 6 | `task` vs `subagent`；depth；子 agent 用谁的权限 | 本机 1.18.32 **只有 `task`**；`subagent` 是 v2 动作名/工具名；`subagent_depth` 默认 **1**；子 agent 用**自身** permission，但**父 session 的 deny + external_directory 追加在后面 → 覆盖它** | `research/src-task-tool.ts:111-117` + `src-agent-subagent-permissions.ts:20-26` + `src-session-llm.ts:149` |
| 7 | `@agent` mention → 数据结构 | `@name` 解析为 `AgentPart{ type:"agent", name, source{value,start,end} }` | SDK `dist/v2/gen/types.gen.d.ts:442-452` |
| 8 | `default_agent` 选择与回退；已有 session 受影响吗 | v1 源码：**无效值直接 `throw`**（不回落 build，官方文档说会回落 —— 不一致）；未设置时取"第一个 `mode !== subagent` 且 `hidden !== true` 的 agent"；**改配置不改已有 session 已存的 agent** | `research/src-agent-agent.ts:328-340`；v2 docs `Selection` 节 |
| 9 | 扩展点清单 | commands / custom tools / MCP / plugins（20 个 hook，逐个列名）/ skills / references —— 见 `extension-points.md` | v1 docs 全部 + `plugin/dist/index.d.ts:173-330` |
| 10 | permission 的能力边界 | 官方定位为**交互门（approval gate）而非安全边界**；shell 以宿主用户的 file/process/network 权限运行 | v2 docs `Permissions > Directories` 节 Warning 原文 |

---

## 3. 版本对齐结论（工程决策最关键）

### 3.1 三套并存的 schema

| 维度 | v1（本机 1.18.32 生效） | v2（文档已发布，配置层未切换） |
|---|---|---|
| agent 键 | `agent`（单数） | `agents`（复数） |
| 权限字段 | `permission`（map） | `permissions`（**有序数组**） |
| shell 动作名 | `bash` | `shell` |
| 子 agent 动作名 | `task` | `subagent` |
| 禁用字段 | `disable: true` | `disabled: true` |
| 系统提示字段 | `prompt`（Markdown body 或 `prompt:` frontmatter） | `system`（JSON 侧）；Markdown 仍用 body |
| 未匹配规则的兜底 | 走内置 base policy（默认多为 `allow`） | **`ask`** |
| 规则合并 | map 编译成数组后追加 | 显式数组追加 |
| model variant | `model` + 独立 `variant` 字段 | `model: "provider/id#variant"` 或展开对象 |
| 内置 subagent | general / explore（官方 v1 docs 另称有 **scout**，本机无） | general / explore（**无 scout**） |
| 额外/移除动作 | `doom_loop` / `lsp` 有效 | **`doom_loop` 和 `lsp` 不是 v2 Core 动作**；新增 `plan_enter` / `plan_exit` |

【观测】v2 docs `Permissions > Actions` 节原文：*"V2 action names are strings, so plugins may define more actions... `doom_loop` and `lsp` are not current V2 Core permission actions."*
【观测】v2 docs `Agents > Options` 末尾原文：*"Do not use legacy top-level fields such as `temperature`, `top_p`, `prompt`, `permission`, `tools`, `disable`, or `maxSteps` in new V2 agent configuration."*

### 3.2 本机 1.18.32 的实测定位

【观测】`opencode debug config` 顶层键：
```
['$schema','agent','command','mcp','mode','plugin','provider','skills','small_model','username']
```
→ **无 `agents`、无顶层 `permissions`、无 `permission`**（该仓库未设全局 permission），`default_agent` / `subagent_depth` 均为 None。

【观测】本仓库 `.opencode/node_modules/@opencode-ai/sdk` 版本号 **1.18.32**（与 CLI 一致）；其 `dist/v2/gen/types.gen.d.ts:1520-1652` 的 `Config` 类型**只有 `agent` / `mode` / `permission`，没有 `agents` / `permissions`**。但同一文件 L3166-3172 已有 `PermissionV2Rule` / `PermissionV2Ruleset` / `AgentV2Info`。

【观测】**tag 级交叉验证**（webfetch，HTTP 200）：`v1.18.32` tag 的 `agent/agent.ts`、`agent/subagent-permissions.ts`、`tool/task.ts`、`tool/task.txt` 与 `dev` 分支**内容一致**。→ 本报告引用 `dev` 源码的结论对 1.18.32 直接成立，无需版本折扣；快照另存为 `research/src-tag11832-*.ts`。

【推论】1.18.32 是 **v1 配置层 + v2 内核类型并存**的过渡版本。写配置必须用 v1 语法；读 SDK 类型时注意同名 `AgentConfig` 在 v1 gen 文件里字段更少（见 `verified-facts.md` §5.2）。

### 3.3 版本敏感清单（升级时需重测）

| 项 | 状态 | 说明 |
|---|---|---|
| `scout` 内置 subagent | **文档错误（已定论）** | 官方 v1 docs（Oct 7, 2026）称 3 个内置 subagent（general/explore/**scout**）；但 ① 本机 `opencode debug config` 显示 `plugin = []`（无插件）② `opencode agent list` 只有 general + explore ③ **webfetch 核验 v1.18.32 tag 的 `agent.ts`，内置 agent 只有 build/plan/general/explore/compaction/title/summary —— 无 scout**。→ **1.18.32 确无 scout，不要依赖** |
| `maxSteps` 兼容读取 | **已失效** | v1.18.32 tag 的 `agent.ts` 覆盖循环**只有 `item.steps = value.steps ?? item.steps`**，无 `maxSteps` 分支 → 写 `maxSteps` **静默失效，无警告** |
| `debug agent` 的 `tools` 语义 | **易误读** | 该字段用 **agent 级** ruleset 判定（`Permission.disabled()`），**不代表 child session 的有效权限**。`general` 显示 `task: true` 但实际 child session 会被注入 `task/* deny` |
| `plan_enter` / `plan_exit` 权限键 | **本机存在、线上 schema 未收录** | 【观测】1.18.32 内置 agent 解析结果含这两个 key；`config-schema.json` 的 `PermissionConfig` 未列 |
| `background` task 参数 | **实验性** | 需 `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`，否则 `Effect.fail` |
| `default_agent` 无效值处理 | **文档 vs 源码不一致** | v1 docs 称"回落到 build 并警告"；dev 源码 `defaultInfo()` 直接 `throw` |
| subagent 继承父 deny | **已知 bug** | GitHub issue `anomalyco/opencode#45078`：父 session 中已被后续规则覆盖的 deny 仍被继承给 child session。`v1.18.32` tag 与 `dev` 的 `subagent-permissions.ts` 逐字节一致 → 1.18.32 **同样受影响** |
| 仓库名 | 已迁移 | `sst/opencode` → **`anomalyco/opencode`**；两者 raw URL 均返回同一份 14200 字节 task.ts（已交叉验证） |
| tag 命名 | **`v` 前缀** | 本机 1.18.32 对应 git tag **`v1.18.32`**（不是 `1.18.32`，后者 404）—— 已 webfetch 核验 |

---

## 4. 对本仓库 3 个现有 agent 的启示（【判断】）

现状（`.opencode/agents/{probe,repair,referee}.md`，均已实测解析成功）：

| agent | mode | steps | task 规则（实测） |
|---|---|---|---|
| `probe` | primary | 40 | `{'permission':'task','action':'deny','pattern':'*'}` |
| `repair` | primary | 80 | `{'permission':'task','action':'allow','pattern':'*'}` |
| `referee` | subagent | 25 | `{'permission':'task','action':'deny','pattern':'*'}` |

### 4.1 可立即落地的强化：把提示词约束变成权限约束

`repair` 目前 `task: allow` 是**全开** —— 内置 `general` / `explore` / 用户全局 agent 全都可被调度。既然已证实 `task` 支持 glob，可收紧为：

```yaml
permission:
  task:
    "*": "deny"
    "referee": "allow"
```

**语义**：`"*"` 必须写在**前面**，因为 last-match-wins（`research/src-permission-v1-bridge.ts:29-39` 的 `findLast`）。这正是官方 v1 docs "Task permissions" 节的示例形态。

【观测】`research/src-task-tool.ts:147-149`：subagent 自身没有 `task` 规则时，child session 会自动注入 `task/* deny`。所以 `referee` 的 `task: deny` 其实是冗余的（保留无害且自解释）。

### 4.2 一个隐性副作用（【观测】+【推论】）

`deriveSubagentSessionPermission`（`research/src-agent-subagent-permissions.ts:20-26`）无条件把父 session 的**全部 `external_directory` 规则**搬进 child session。而 `src-session-llm.ts:149` 是：
```
const ruleset = Permission.merge(input.agent.permission ?? [], input.permission ?? [])
```
即 **session 规则追加在 agent 规则之后 → 覆盖 agent 规则**。

【推论】若用户在 UI 里对某条 external_directory 请求点了 "always"，持久化的 allow 规则进入父 session ruleset 后会流向 child session。这正是 issue #45078 的成因面。

### 4.3 建议的最小改动清单

1. `repair.md`：把 `task: "allow"` 换成 §4.1 的 glob 表。**这是唯一必需的改动。**
2. 三个 agent 的 bash allowlist 用的是 `"git diff*"` / `"git status*"` / `"npm test*"` —— **写法正确，无需改动**。原因见 `frontmatter-and-permissions.md` §5 的末尾 `*` 特判（`git status*` 展开为 `git status.*`，能匹配 `git status --short`）。
3. 不建议给 `referee` 加 `hidden: true`：`hidden` 只对 `mode: subagent` 生效（【观测】schema description 明确 *"only applies to mode: subagent"*），会把它从 `@` 自动补全里藏掉，破坏 `repair.md` Phase 4 依赖的"用户手动 `@referee` 优先"路径。

---

## 5. 文档导航

| 文件 | 内容 |
|---|---|
| `frontmatter-and-permissions.md` | 字段全表、v1↔v2 对照、匹配算法逐行拆解、合并规则、常见误配 |
| `dispatch-and-sessions.md` | `task`/`subagent`、child session、depth、`@mention`、agent 切换、内置 agent 全清单（本机实测） |
| `extension-points.md` | commands / tools / MCP / plugins+hooks / skills / references 配置形态与最小示例 |
| `verified-facts.md` | 本机 1.18.32 命令输出片段 + `.d.ts` 行号锚点 + 未解决问题 |
| `research/README.md` | 离线副本索引表（文件名 / 标题 / URL / 字节 / sha256前12 / 状态） |

---

## 6. 对本仓库既有文档的交叉核对（只报告，未修改）

以下 3 个文件**全程只读**，`git diff` 确认为空：

- `docs/opencode-tui-agent-plan.md`
- `docs/opencode-bug-fix-plan.md`
- `bugfix-multi-agent-diagnosis.md`

### 6.1 已被证伪

| # | 位置 | 原文 | 证伪证据 | 修正建议 |
|---|---|---|---|---|
| **F1** | `docs/opencode-tui-agent-plan.md:65-66` | `task: allow  # OpenCode 1.x 的 task 只接受 action（allow/ask/deny），不支持按子 agent 名称过滤；项目内唯一的 subagent 就是 referee，提示词层面约束 repair 仅调度 referee` | **五重证据**：① 官方 v1 docs（Oct 7, 2026）`Task permissions` 节给出 `permission.task` 的 **glob 对象语法**原文示例；② 线上 `config.json` 的 `$defs.PermissionConfig.task` 类型为 `PermissionRuleConfig = Action \| {pattern→Action}`；③ 本机 SDK 1.18.32 `dist/v2/gen/types.gen.d.ts:1333-1350` 的 `PermissionConfig.task?: PermissionRuleConfig`；④ **本机二进制内建的 `plan` agent 就带 `task: { general: "deny" }`**（`opencode debug agent plan` 输出 `{'permission':'task','pattern':'general','action':'deny'}`）；⑤ 源码 `src-agent-agent.ts` plan 定义 | 改为 `task: { "*": "deny", "referee": "allow" }`（`"*"` 必须在前）。**把提示词约束升级为运行时强制约束** |
| **F2** | `bugfix-multi-agent-diagnosis.md:20` | `"只派发 referee"目前是行为提示，当前 task 权限不能按 agent 名过滤` | 同 F1 | 该条应从"待验证假设"移入"可由配置强制"；`repair.md` 的提示词约束可保留为**双保险** |

### 6.2 需要修正（版本号 / 表述精度）

| # | 位置 | 现状 | 修正 |
|---|---|---|---|
| **R1** | `opencode-tui-agent-plan.md:37`、`:114` | 写 `本机 1.17.8` | 本机现为 **1.18.32**。1.17.8 → 1.18.32 期间的关键变化：`permission.task` 支持 glob（F1）；`plan_enter` / `plan_exit` 权限键出现；`maxSteps` 已被源码完全丢弃 |
| **R2** | `opencode-tui-agent-plan.md:114` | ``子会话导航：`+Down` 进入、`Up` 返回（1.17.8 默认键位）`` | keybind id 应写 `session_child_first`（默认 `<leader>down`）与 `session_parent`（默认 `up`）。另注：同页 `session_child_cycle` = `right` / `session_child_cycle_reverse` = `left` |
| **R3** | `opencode-tui-agent-plan.md` 全文多处 | 隐含"内置 subagent 只有 general/explore"的口径 | **官方 v1 docs 明确说有 3 个（general/explore/**scout**），但本机 1.18.32 无 scout**（`plugin = []` 且 v1.18.32 tag 源码无此 agent）。→ 若将来有依赖 scout 的设计，需标注版本假设 |
| **R4** | `opencode-tui-agent-plan.md:181` | *"Tab 会循环所有 primary agent"* | 精确表述：`Tab` / `Shift+Tab` 循环 **可见的 primary 与 all** agent；keybind id 是 `agent_cycle` / `agent_cycle_reverse`（**不是文档里写的 `switch_agent`**）。且循环范围受 `hidden` 影响 |
| **R5** | `opencode-tui-agent-plan.md:65` 的 `edit: allow` / `write: allow`（`probe.md`/`referee.md` 亦同） | 两者并列声明 | `write` 会**生成一条规则但永不生效**。【观测】`opencode debug agent probe` 的规则键计数含 `write: 1`（规则确实存在），但【观测】`src-permission-v1-bridge.ts:205-209` 的工具→权限映射是 `["edit","write","apply_patch"] → "edit"`，求值时 `write` 工具一律以 `edit` 为 permission 名匹配 → `write` 规则**永远不被命中**。建议只写 `edit`（无害但会误导后来者以为二者独立） |
| **R6** | `opencode-bug-fix-plan.md:22` | *"OpenCode permission 是交互门禁而非安全边界，真实隔离必须由容器/VM 提供。"* | ✅ **完全正确，且被本次调研加强**。v2 docs `Directories` 节 Warning 原文：*"shell runs with the host user's filesystem, process, and network authority. Directory inference from command text is best effort, so prefer a narrow shell allowlist instead of patterns intended to recognize every dangerous command."* 建议把这条官方原文作为引证补进去 |
| **R7** | `opencode-bug-fix-plan.md:24` | *"需将所安装 OpenCode 主版本锁定在配置中"* | ✅ 正确且必要。补充：v1↔v2 的 **action 名也变了**（`bash`→`shell`、`task`→`subagent`），不只是字段名。且线上 `config.json` schema **当前仍是 v1 形态**，`$schema` 引用不会自动帮你校验 v2 配置 |
| **R8** | `opencode-bug-fix-plan.md:32` | *"独立 read-only verifier 必须给出 `VERDICT: PASS`"* | 【判断】若要把该要求变成硬约束而非提示词：把 verifier 的输出校验放到 **CI 脚本**里（解析 `VERDICT: PASS` 字符串），而不是指望 `referee` agent 的自述。permission 层无法校验输出内容 |
| **R9** | `bugfix-multi-agent-diagnosis.md:20` 前半句 | *"permission 是安全边界"* 应改为操作门禁 | ✅ 该修正方向正确（见 R6）。补充一个此前未识别的机制：父 session 的 `deny` 规则会**穿透**到 child session 并覆盖子 agent 自身规则（`src-agent-subagent-permissions.ts:21-23` + `src-session-llm.ts:149`），因此"父级收紧权限"是唯一可靠的全局收紧手段 |
