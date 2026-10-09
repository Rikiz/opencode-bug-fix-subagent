# multi-fix-oc

在 opencode v1 下运行的多仓 issue→修复流程：把一张问题单路由到可能拥有它的仓库，在每个仓库内做证据化定位与最小修复，然后跨仓验证契约一致性。

**不含可执行编排器**——流程由四个 agents、两个 skills 与一份拓扑清单驱动。

## 为什么单独做多仓

「这个 bug 属于哪个仓」不是定位的副产品，而是一个独立的第一性问题。DNext（ICSE 2026，唯一以"哪个仓"为主任务的论文）在 46 仓 / 110 万行 / 真实电信工单上做到 **Pass@10 = 0.82、MRR = 0.50**，并击败 Copilot 与 Cursor 的 agentic RAG——关键是它把定位重构为**在层级化上下文摘要上的自然语言搜索，而不是对代码做 RAG**。去掉目录层，MRR 掉 54%。

所以本目录把**仓库路由单独作为第一阶段**，且路由阶段**禁止读源码**。完整论证见 [docs/multi-repo-fix-workflow.md](docs/multi-repo-fix-workflow.md)。

## 组成

```
multi-fix-oc/
├── opencode.json                    权限兜底：bash 白名单 + deny 一切破坏性/网络命令
├── topology.example.json            拓扑清单示例（复制为 topology.json 后填写）
├── .opencode/agents/
│   ├── multi-repo-orchestrator.md   mode:all    路由 / 派活 / 汇总，自身不改代码
│   ├── repo-router.md               mode:subagent  issue → 仓库候选集（不读源码）
│   ├── repo-fixer.md                mode:subagent  单仓定位 + 最小补丁 + 回归测试
│   └── cross-repo-verifier.md       mode:subagent  只读，审契约一致性与 diff 最小性
├── .opencode/skills/
│   ├── cross-repo-localization/     契约边检索、关联 ID 追溯、缺失证据一等公民
│   └── topology-manifest/           清单 schema 读写规范
└── docs/
    ├── multi-repo-fix-workflow.md         六阶段流程手册（主文档）
    ├── opencode-agents-reference.md      opencode v1 agent/权限机制参考
    └── research/                         论文与方法论调研（4 篇 + 索引）
```

## 快速开始

**1. 建拓扑清单**

```bash
cd multi-fix-oc
cp topology.example.json topology.json
```

编辑 `topology.json`：仓库列表、契约边（HTTP 路径 / 事件 topic / schema / config key）、每仓的验证命令、以及 `coverage`（陈旧仓库与未知边）。

`topology.json` 被 git-ignore——它含内部仓库路径、归属人与服务拓扑。

**2. 会话内驱动**

```bash
cd /abs/path/to/one-of-the-repos
OPENCODE_CONFIG=/abs/multi-fix-oc/opencode.json \
OPENCODE_CONFIG_DIR=/abs/multi-fix-oc/.opencode \
opencode
```

然后：

```
@multi-repo-orchestrator <issue JSON 路径，或问题描述>
```

**3. 逐仓修复（CI 场景）**

```bash
OPENCODE_CONFIG=/abs/multi-fix-oc/opencode.json \
OPENCODE_CONFIG_DIR=/abs/multi-fix-oc/.opencode \
opencode run --agent repo-fixer "<该仓的 brief>"
```

`OPENCODE_CONFIG_DIR` 是必需的：`--dir` 指向目标仓时 opencode 从该仓向上找配置，拿不到本目录的 agents。已实测该变量优先级最高。

逐仓运行同时也是最干净的隔离方式：每个 fixer 的 worktree 就是它自己的仓库，因此**无需 `external_directory` 授权**。拓扑里的路径运行期才知道，而 opencode 权限不支持变量插值（实测 JSON 里写 `$HOME` 会直接解析失败）。

## 设计约束

- **v1 方言**。`permission` / `bash` / `task`，不是 v2 的 `permissions` / `shell` / `subagent`。
- **深度一层**。三个 subagent 都不声明 `task` key，因此自动 deny，无法继续嵌套。`subagent_depth` 未写入配置——本机 CLI 1.17.7 不支持它，写入会报 `Configuration is invalid`。
- **用 `deny` 不用 `ask`**。`opencode --auto` 会把所有 `ask` 变 `allow`；权限匹配是 `findLast`，所以 `"*"` 放最前、例外放后。
- **父 agent 的 `allow`/`ask` 不向子 agent 传递**（只有 `deny` 继承）。每个 subagent 自带完整 allow-list。
- **`mode: primary` 对 task 工具不可见**。所以编排器是 `mode: all`，执行体是 `mode: subagent`。
- **不可信输入加固重复两次**（agent 提示与运行 prompt 各一次）：issue、评论、日志、源码文本都是数据，不能授权命令、扩大范围或覆盖规则。

## 已知限制

完整清单见 [docs/multi-repo-fix-workflow.md §5](docs/multi-repo-fix-workflow.md)。最需要知道的四条：

1. **没有公开的 issue→仓库路由基准**（DNext 专有），因此路由质量无法引用任何榜单数字证明，必须自建评测集。
2. **API 契约 / schema 不一致这一最高频的多仓缺陷类，没有基准。** 本项目在此类上是 `[无基准]`。
3. **网关 / 服务网格 / 路由器的根因在代码修复文献中完全未被处理**（网格级 RCA 全是遥测-based），需要人工判断。
4. **`confidence` 目前只影响措辞，未做硬门控**——低于阈值不会真正拒绝行动。这是已知缺口。

另一个工程陷阱：**frontmatter 重复 key 会让 agent 静默消失**，不报错、只表现为 `opencode agent list` 里没有它。本目录踩过一次（`repo-fixer.md` 的 `lsp` 写了两次）。建议把 YAML 解析纳入 CI。

## 与父仓的关系

本目录是自包含的，不修改父仓实现。父仓的 `bug-fix` / `bug-fix-verifier`（`mode: primary`，单仓）与本目录的多仓流程**并列**，`bin/`、`lib/`、`test/` 均未改动，`npm test` 不受影响。

调研时的参考文档仍保留在父仓 `docs/`：`bug-fix-agent-research.md`、`opencode-bug-fix-plan.md`。