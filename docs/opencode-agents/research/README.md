# 离线副本索引表

**抓取日期：2026-10-08（UTC）**
**抓取方式：`curl -fsSL --max-time 60 -o <file> <URL>`（全部 HTTP 200）；源码 tag 快照用 `webfetch`**
**落盘校验：每个 HTML 用 `file(1)` + `grep '<title>'` 确认标题；`config-schema.json` 用 `head -c` + `python3 json.load` 确认是合法 JSON Schema；`.ts` 快照用首行 import / `diff` 确认是源码而非占位文件。**

⚠️ **严禁把无关内容或占位文件存成文档文件名** —— 本目录已核验：
- 16 个 HTML 的 `<title>` 全部为 `OpenCode` 站点对应页面标题（见下表），**无一例 404 / Cloudflare 挑战页 / 空文件**。
- `config-schema.json` 通过 `json.load()` 解析，`$defs` 含 19 个定义（含 `AgentConfig` / `PermissionConfig`）。
- 14 个 `src-*.ts` 快照（12 个 dev + 2 个 tag）均为真实 TypeScript 源码（首行为 `import` / `export`），并对 4 个做了 tag 级 `diff` 校验。
- 曾尝试 `https://opencode.ai/v2/config.json` → **HTTP 404**，**未保存任何文件**。

---

## 1. 官方文档 HTML 快照（16 个）

| 文件名 | 标题（`<title>`） | 来源 URL | 字节数 | sha256 前12 | 页面 "Last updated" | 状态 |
|---|---|---|---|---|---|---|
| `agents-v1.html` | `Agents \| OpenCode` | https://opencode.ai/docs/agents/ | 179862 | `737955227c52` | **Oct 7, 2026** | 已核实 |
| `permissions-v1.html` | `Permissions \| OpenCode` | https://opencode.ai/docs/permissions/ | 88924 | `a1a8cb163049` | **Oct 7, 2026** | 已核实 |
| `tools-v1.html` | `Tools \| OpenCode` | https://opencode.ai/docs/tools/ | 102000 | `09143e292f03` | **Oct 7, 2026** | 已核实 |
| `skills-v1.html` | `Agent Skills \| OpenCode` | https://opencode.ai/docs/skills/ | 71583 | `0411ef3e4392` | **Oct 7, 2026** | 已核实 |
| `commands-v1.html` | `Commands \| OpenCode` | https://opencode.ai/docs/commands/ | 86158 | `bb63d121482d` | **Oct 7, 2026** | 已核实 |
| `plugins-v1.html` | `Plugins \| OpenCode` | https://opencode.ai/docs/plugins/ | 109985 | `00fb00e7bbe6` | **Oct 7, 2026** | 已核实 |
| `config-v1.html` | `Config \| OpenCode` | https://opencode.ai/docs/config/ | 202528 | `8f86f1ae957c` | **Oct 7, 2026** | 已核实 |
| `mcp-servers-v1.html` | `MCP servers \| OpenCode` | https://opencode.ai/docs/mcp-servers/ | 127282 | `739b94ee8a5f` | **Oct 7, 2026** | 已核实 |
| `rules-v1.html` | `Rules \| OpenCode` | https://opencode.ai/docs/rules/ | 76949 | `aa4ee52839d7` | **Oct 7, 2026** | 已核实 |
| `keybinds-v1.html` | `Keybinds \| OpenCode` | https://opencode.ai/docs/keybinds/ | 120602 | `b8a783d5d000` | **Oct 7, 2026** | 已核实 |
| `references-v1.html` | `References \| OpenCode` | https://opencode.ai/docs/references/ | 70199 | `1b26c389c522` | **Oct 7, 2026** | 已核实 |
| `agents-v2.html` | `Agents \| OpenCode` | https://opencode.ai/v2/docs/agents/ | 49101 | `1d2d45dba886` | **无该标记** | 已核实 |
| `permissions-v2.html` | `Permissions \| OpenCode` | https://opencode.ai/v2/docs/permissions/ | 51123 | `2d14da46f59d` | **无该标记** | 已核实 |
| `config-v2.html` | `Config \| OpenCode` | https://opencode.ai/v2/docs/config/ | 63717 | `d371e8f8e324` | **无该标记** | 已核实 |
| `skills-v2.html` | `Skills \| OpenCode` | https://opencode.ai/v2/docs/skills/ | 32226 | `6a645124f6e4` | **无该标记** | 已核实 |
| `references-v2.html` | `References \| OpenCode` | https://opencode.ai/v2/docs/references/ | 35201 | `a00f58075feb` | **无该标记** | 已核实 |

**关于 v2 页面无 "Last updated"**：`/v2/docs/*` 使用不同的页面模板（`<main>` 内无 footer 日期区），正则 `Last updated:(.{0,200})` 无匹配。**这是页面结构差异，不是抓取失败**（`<title>` 与正文均完整）。

## 2. JSON Schema（1 个）

| 文件名 | 内容 | 来源 URL | 字节数 | sha256 前12 | 状态 |
|---|---|---|---|---|---|
| `config-schema.json` | JSON Schema draft 2020-12；`$ref: "#/$defs/Config"`；`$defs` 共 19 项，含 `AgentConfig` / `PermissionConfig` / `PermissionRuleConfig` / `ConfigV2.Reference.Git` / `ConfigV2.Reference.Local` / `Policy.Effect` | https://opencode.ai/config.json | 39039 | `e8cb6e287a38` | 已核实 |

**未获取（HTTP 404，未落盘任何文件）**：`https://opencode.ai/v2/config.json`

## 3. 源码快照 —— `dev` 分支（12 个）

来源前缀：`https://raw.githubusercontent.com/anomalyco/opencode/dev/`（`sst/opencode` 与 `anomalyco/opencode` 的 `dev` raw URL 返回**相同内容**，已交叉验证）

| 文件名 | 原始路径 | 字节数 | sha256 前12 | 状态 |
|---|---|---|---|---|
| `src-task-tool.ts` | `packages/opencode/src/tool/task.ts` | 14200 | `db09fa5868ad` | 已核实（与 v1.18.32 tag `diff` 一致） |
| `src-task-tool.txt` | `packages/opencode/src/tool/task.txt` | 2305 | `220dcf4ad258` | 已核实（与 v1.18.32 tag `diff` 一致） |
| `src-agent-agent.ts` | `packages/opencode/src/agent/agent.ts` | 16746 | `e781c571d584` | 已核实（另经 GitHub blob 页 webfetch 复核全文一致） |
| `src-agent-subagent-permissions.ts` | `packages/opencode/src/agent/subagent-permissions.ts` | 1225 | `c3bbbd4ea8f0` | 已核实 |
| `src-permission-v1-bridge.ts` | `packages/opencode/src/permission/index.ts` | 7861 | `5b9e4aa65290` | 已核实 |
| `src-permission-core-v2.ts` | `packages/core/src/permission.ts` | 11753 | `f5d5b295452f` | 已核实 |
| `src-util-wildcard.ts` | `packages/core/src/util/wildcard.ts` | 467 | `58803dad815e` | 已核实（匹配算法全文，13 行） |
| `src-config-agent.ts` | `packages/opencode/src/config/agent.ts` | 1745 | `4844d4dfa48a` | 已核实 |
| `src-config-config.ts` | `packages/opencode/src/config/config.ts` | 27747 | `87a9071af1dd` | 已核实 |
| `src-config-paths.ts` | `packages/opencode/src/config/paths.ts` | 1312 | `cd86a34461b2` | 已核实 |
| `src-config-entry-name.ts` | `packages/opencode/src/config/entry-name.ts` | 897 | `926b88ac30ac` | 已核实 |
| `src-session-llm.ts` | `packages/opencode/src/session/llm.ts` | 15097 | `5f1dcfb73485` | 已核实（**含关键的 `Permission.merge(agent, session)` 顺序**，见 `dispatch-and-sessions.md` §4.2） |

## 4. 源码快照 —— `v1.18.32` tag（2 个，webfetch 核验）

| 文件名 | 原始路径 | 字节数 | sha256 前12 | 状态 |
|---|---|---|---|---|
| `src-tag11832-agent-subagent-permissions.ts` | `packages/opencode/src/agent/subagent-permissions.ts` @ tag `v1.18.32` | 982 | `5de264f114a7` | 已核实（**逐字节等于 `dev` 版本**；文件含来源 URL 注释头） |
| `src-tag11832-agent-agent-notes.ts` | `packages/opencode/src/agent/agent.ts` @ tag `v1.18.32` | 753 | `a42baeaf470f` | **部分**：webfetch 取得全文并逐条核验（无 scout / 无 `maxSteps` 回退 / `defaultInfo` 抛错），但为避免重复未全文落盘，改为**要点摘录 + 来源 URL** |

⚠️ **tag 命名带 `v` 前缀**：`.../v1.18.32/...` → HTTP 200；`.../1.18.32/...` → **HTTP 404**。

## 5. 检索但未落盘的来源（供后续补抓）

| 来源 | 状态 | 备注 |
|---|---|---|
| `https://dev.opencode.ai/docs/agents`（zh-cn / en） | 存在，内容与 `opencode.ai/docs/*` 一致 | 未落盘（重复） |
| `https://v2.opencode.ai/agents.md`、`https://v2.opencode.ai/docs/agents` | 存在（**llms.txt 式 markdown 版**） | 未落盘（内容与 `agents-v2.html` 同源，但排版不同、含 `/agents` 命令与 `mode` 更完整的表述） |
| `https://github.com/anomalyco/opencode/issues/45078` | 存在（搜索结果引用其原文） | 未落盘（issue 正文未逐字核实，故报告中只标为"已知 bug"并给出 issue 号） |
| `https://github.com/anomalyco/opencode/issues/25268`（glob 忽略 path 权限） | 存在 | 未落盘；报告中未引用其结论 |
| `packages/opencode/src/session/prompt*`（3 个候选路径） | **全部 404 / 未获取** | 子 agent 目录注入点**未定位**，见 `verified-facts.md` §6 待验项 #2 |

## 6. 本机只读证据的落盘位置

| 证据 | 位置 |
|---|---|
| `opencode agent list` 完整输出 | **未落盘**（含大量本机绝对路径）。关键切片在 `verified-facts.md` §2 |
| `opencode debug agent <name>` 输出 | **未落盘**。关键切片在 `verified-facts.md` §4 |
| `opencode debug config` 输出 | **未落盘**。关键切片在 `verified-facts.md` §3 / §5.8（已裁剪为非敏感字段） |
| `.d.ts` 类型定义 | **未落盘**（属 `node_modules`）。行号锚点在 `verified-facts.md` §5 |
| `.opencode/agents/{probe,repair,referee}.md` | 未修改；原文见仓库 |

## 7. 复现校验命令

```bash
cd docs/opencode-agents/research
for f in *; do printf "%s|%s|%s\n" "$(shasum -a 256 "$f" | cut -c1-12)" "$(wc -c < "$f" | tr -d ' ')" "$f"; done
for f in *.html; do grep -o '<title>[^<]*</title>' "$f" | head -1; done
python3 -c "import json;d=json.load(open('config-schema.json'));print(len(d['\$defs']),'defs')"
```
