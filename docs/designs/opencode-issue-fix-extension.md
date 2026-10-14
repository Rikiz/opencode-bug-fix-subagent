# OpenCode Issue-fix 扩展：设计与实证记录

> 版本：2026-10-13
> 状态：M0 完成（部分实测受环境限制），M1 资产已落地
> 目标产物：一个 OpenCode agent，接收一段问题单文本，在当前工作目录里修好这个 bug，并给出可核查的证据。
> 证据标注：【实测】本机命令输出；【文档】官方文档；【源码】v1.18.32 源码快照（与 dev 逐字节一致）；【设计判断】工程取舍；【待验】尚无证据。

---

## 0. 证据边界

| 标签 | 含义 |
|---|---|
| 【实测】 | 在本机 OpenCode **1.19.0** 上执行命令得到的输出，可复现 |
| 【文档】 | 官方文档原文，已抓取到 `docs/opencode-agents/research/*.html` |
| 【源码】 | `docs/opencode-agents/research/src-*.ts`（v1.18.32 tag，已逐字节比对） |
| 【设计判断】 | 我们的取舍，不是研究结论 |
| 【待验】 | 需要真实 provider 才能验证，本环境被 free tier 挡住 |

调研结论编号沿用 `docs/bugfix-methodology/claims-table.md`（C01–C54）。

---

## 1. 目标与约束

**输入**：一段问题单文本（粘贴）。**输出**：工作目录里的最小改动 + 证据 + 报告。

已确认的约束：

| # | 约束 |
|---|---|
| 1 | 先针对 OpenCode **1.19.0**（v1 配置），v2 移植放到 M5 |
| 2 | 先纯 Markdown，再加插件强制 |
| 3 | 与既有 `probe` / `repair` / `referee` 并存，旧文件不改 |
| 4 | 在本仓库开发，用脚本装到 `~/.config/opencode/` |
| 5 | 只做交互式 TUI；问题单只支持粘贴 |
| 6 | 语言：Java/Kotlin、Python、JS/TS、Go、Rust/C/C++ |

**本期不做**：多仓修改、新功能开发、commit/push/PR、依赖与 CI 改动、无人值守运行、从 GitHub/Jira 拉取问题单。

---

## 2. 三条核心门禁

1. **先复现再改源码。** 改源码之前必须有一个复现测试：稳定失败，且失败原因和问题单描述一致。
   - 【实测/文档】不设约束时 agent 75% 的情况先改源码（Dynamic cogeneration）；去掉"先写测试"掉 7.0pp（CoHarden）；锁住编辑权限直到诊断完成提升 10–13pp（Debug2Fix）。
2. **宣布修好必须有能区分修复前后的证据。** agent 认为"通过"的检查里 **46%** 在有 bug 的代码上也通过，**23.8%** 的运行只凭这种检查收尾（arxiv-2607.28871）。
3. **不自己证明自己修好了。** 自己验收的出错风险 29.5%，用可见测试把关降到 2.4%（Looping）；测试全绿的 patch 仍有 7.8% 过不了开发者测试、29.6% 行为与标准答案不同（C23）。

**结局不止"修好了"**：真实成熟项目里只有 16.7–33.5% 的 bug report 最终被修复（C11）。`NOT_REPRODUCIBLE` / `NEEDS_INFO` / `NOT_A_BUG` / `OUT_OF_SCOPE` 都是正确结局，且前两类**不允许改源码**。

---

## 3. 架构

```
/issue-fix <粘贴的问题单>          或  Tab 切到 issue-fix 后直接粘贴
        │
┌─────── issue-fix（primary · 唯一能改文件 · steps 120 · temperature 0.1）─────────┐
│ S0 受理 → S1 基线 → S2 定位 → S3 复现 → S4 诊断 → S5 修改 → S6 验证 →        │
│ S7 最小化 → S8 独立验证 → S9 报告                                            │
│ 每阶段用 todowrite 打点；每阶段开头重读 .issue-fix/runs/<case>/case.md          │
│ 按需加载 6 个 skill                                                          │
└──────────┬───────────────────────────────────────────────────────────────────┘
           │ task（每次必经）
      issue-fix-verifier（subagent · 只读 · 两段式：先盲审，再对照需求审查）
```

**为什么只有一个 agent 能改文件**：三方独立证据一致指出，编码类高耦合任务上多 agent 收益可疑（C49、C52、C54）；`Agentless` 用无 agent 的固定三阶段流程就达到 31.00% / $0.65（C16/C17）。独立性的收益集中在**验证**环节，不在并发。

---

## 4. 阶段与门禁

| 阶段 | 动作 | 门禁 | 不通过 |
|---|---|---|---|
| S0 受理 | 抽字段、判类型、拆可测试需求 | **G1** 至少 1 条可测试需求且类型为缺陷 | 只问 1 个问题；否则 `NEEDS_INFO` / `OUT_OF_SCOPE` |
| S1 基线 | `git stash create` 拍 base（不动用户改动）；识别构建与测试命令；记录相关范围基线 | 测试命令可运行，基线已记录 | 环境问题问一次 |
| S2 定位 | 模块 → top-3 文件 → 函数 → 编辑点；多路证据；栈只当起点 | 候选 ≤5 且各有证据 | 扩搜一次；再不行交给 investigator（M3） |
| S3 复现 | 每条需求一个复现测试；期望值来自问题单；关掉缓存跑 3 次 | **G2** 3 次全红且失败原因与问题单一致（排除编译/导入/环境错误） | 交给 investigator；否则 `NOT_REPRODUCIBLE`，**不改源码** |
| S4 诊断 | 假设账本（预测 + 可证伪实验）；插桩或调试拿运行时证据；区分根因/症状、引入/传播、单/多故障 | **G3** 根因文件行号 + 机制 + 运行时证据；源码相对 base 无残留插桩 | 回到 S2 |
| S5 修改 | 根因处最小改动；遵循项目约定 | 能编译/类型检查 | 触发放弃条件就停 |
| S6 验证 | 复现测试 3 次全绿；回归与基线对比无新增失败；扫描测试完整性；至少一条可区分证据 | **G4** | 预算内回到 S4/S5，从干净代码重来 |
| S7 最小化 | 每个改动块绑定根因或需求；删无关改动后重跑 S6 | **G5** | 回退到检查点 |
| S8 独立验证 | verifier 盲审 + 对照需求逐行审查 | **G6** PASS；部分一致要说明 | 返工 1 次；仍不过如实写进报告 |
| S9 报告 | 结局、根因、改动、证据分级、未执行项、剩余风险、diff（含新文件） | — | — |

- **改源码锁**：G3 之前只允许改测试文件和 `.issue-fix/scratch/**`。M1 靠提示词，M2 由插件强制。
- **循环上限**：最多 3 次补丁尝试；verifier 触发的返工 ≤1；G4–G6 通过立即停止。
  依据：前 3–4 轮之后几乎没有收益（Is-Three）；验证通过后继续修会把对的改坏（VRR-Stop）；陈旧的测试输出让 135 个正确状态毁掉 34 个（Looping）。
- **重试方式**：恢复源码到 base、保留复现测试、带 4 项结构化指导（改哪里 / 做什么操作 / 用什么信号验证 / 边界在哪）重新生成。
  依据：重新开始 vs 在原处反复改 = 40:3（安慰剂对照）；结构化重试指导多恢复 12.5pp（PROBE）。
- **7 种结局**：`FIXED` / `PARTIALLY_FIXED` / `NOT_REPRODUCIBLE` / `NEEDS_INFO` / `NOT_A_BUG` / `OUT_OF_SCOPE` / `BUDGET_EXHAUSTED`。
- **放弃条件**：需要改依赖、构建配置或 CI；需要改公共 API 签名；需要数据迁移；改动 >5 文件或 >200 行。
  依据：FlowAgent（工业实践）跳过 flaky、已失败、>100 文件或 >1000 行的任务；上限 100 次工具调用 / 30 分钟；最终由模型之外的程序确定性重跑测试；不信任加 `@Ignore` 或吞断言的修复。

---

## 5. M0 实证记录（1.19.0）

### 5.1 已验证

| # | 项 | 结果 | 依据 |
|---|---|---|---|
| E1 | 规则顺序 | 内置基线在前、agent 规则追加在后，最后匹配生效 | 【实测】`opencode debug agent repair` |
| E2 | `task` 按名字过滤生效 | 编译出 `task * deny` + `task probe/contract-checker/referee allow` | 【实测】 |
| E3 | **自定义 agent 基线是 `* → allow`** | 第一条编译规则就是 `{permission:"*",action:"allow"}`；三个旧 agent 的 `tools.websearch` 都是 `true`（没人显式 deny） | 【实测】 |
| E4 | **`read: "allow"` 会覆盖内置密钥保护** | 编译顺序：`read * allow` → `read *.env ask` → `read *.env.* ask` → `read *.env.example allow` → **agent 的 `read * allow` 在最后** ⇒ `.env` 重新可读 | 【实测】 |
| E5 | `steps` 正常解析 | repair 80 / probe 40 / referee 25 | 【实测】 |
| E6 | 内置 agent 清单 | primary: build / plan / compaction / title / summary；subagent: general / explore。**无 scout** | 【实测】`opencode agent list` |
| E7 | `bug-fix` agent 不存在 | `debug agent bug-fix` → not found ⇒ `bin/bug-fix.js`、`lib/runner.js`、CI 目前指向已删除的 agent，是坏的 | 【实测】 |
| E8 | 技能目录被自动加 `external_directory: allow` | 全局 `skill/`、`skills/`、项目 `.opencode/skills/*` 全部进白名单 | 【实测】 |
| E9 | 工具级错误不终止 agent 循环 | 主 agent 拿到"工具不存在"和两次子 agent 失败后，仍完成并输出结论（`LOOP_ALIVE=yes`） | 【实测】`opencode run --agent parent-probe` |
| E10 | 全局插件依赖是陈旧的 | `~/.config/opencode/package.json` 里 `@opencode-ai/plugin@1.2.24`（CLI 已 1.19.0）；没有 `~/.config/opencode/plugins/` | 【实测】 |
| E11 | `opencode run --command <name>` 可用 | 评测可走 `opencode run --command issue-fix "<ticket>" --agent issue-fix --auto --dir <worktree>`，产品本身仍只做 TUI | 【实测】`opencode run --help` |
| E12 | stdout 管道在 64 KiB 截断 | `opencode debug config` / `debug skill` 的输出不能喂给 JSON 解析器，只能 `grep`/`head`；**重定向到文件不受影响**（实测 `debug skill` 落盘 88237 字节完整可解析） | 【实测】 |

### 5.2 待验（本环境被 free tier 挡住）

| # | 项 | 阻塞原因 | 设计上的兜底 |
|---|---|---|---|
| P1 | 父会话 deny 是否覆盖子会话规则 | 免费层不允许从 CLI 派发子 agent（"OpenCode's free tier can only be used from within OpenCode"） | **不依赖 skill**：verifier / investigator 的审查清单直接写进各自 prompt【源码】`src-agent-subagent-permissions.ts:21-23` + `src-session-llm.ts:149`（session 规则追加在后 → 覆盖 agent 规则） |
| P2 | 权限被拒绝时循环是否继续 | 需要真实 provider | 不依赖它；E9 已证明工具级错误不会停循环 |
| P3 | 多行粘贴能否完整进入 `$ARGUMENTS` | 首次探测写错了 fixture（用了带指令的 agent）；补测时免费层额度耗尽 | 命令模板之外，`issue-fix` agent 可直接接收粘贴文本（Tab 切换） |
| P4 | `skill: "*": deny` 是否移除整个 skill 工具 | 无法与"free 层没有 skill 工具"区分 | 无影响：本扩展靠 frontmatter 放行 `issue-fix-*` |

### 5.3 由 E3/E4/E8 带来的三处规划修订

1. **read 必须显式写成表**，不能写 `read: "allow"`：

```yaml
  read:
    "*": "allow"              # 必须在前，用来建立基线
    "**/.env": "deny"
    "**/.env.*": "deny"
    "*.pem": "deny"
    "**/id_rsa*": "deny"
    "**/.ssh/**": "deny"
    "**/.aws/**": "deny"
```

2. **每个动作都要显式列出**（因为基线是 allow）：`webfetch` / `websearch` / `external_directory` / `task` / `skill` 全部显式 deny 或白名单。
3. **edit 要挡住"改自己指令"的路径**：`.git/**`、`.github/**`、`.opencode/**`、`.claude/**`、`**/node_modules/**`。

---

## 6. 组件清单

| 组件 | 路径 | 作用 |
|---|---|---|
| 主 agent | `.opencode/agents/issue-fix.md` | 阶段状态机、门禁、结局、预算、调用协议 |
| 验证者 | `.opencode/agents/issue-fix-verifier.md` | 两段式盲审 + 逐行审查 |
| 命令 | `.opencode/commands/issue-fix.md` | 粘贴入口；注入 `git status` / `git log` |
| 技能 ×6 | `.opencode/skills/issue-fix-*/SKILL.md` | 受理 / 定位 / 复现 / 诊断 / 修改 / 验证与报告 |
| 语言说明 ×5 | `.opencode/skills/issue-fix-reproduce/lang/*.md` | 测试放置、单测命令、缓存陷阱 |
| 安装脚本 | `scripts/install-issue-fix.sh` | 复制到 `~/.config/opencode/`；`--link` / `--uninstall` / `--dry-run` |
| 插件（M2） | `.opencode/plugins/issue-fix-guard.ts` | 账本工具、改源码锁、复现测试防篡改、抗压缩 |
| 评测（M4） | `eval/` | 用例集、runner、指标 |

产物目录：`目标仓库/.issue-fix/runs/<case>/`，内含 `case.md`（状态 + 诊断记录）、`evidence.ndjson`、`report.md`、`.issue-fix/.gitignore` 内容为 `*`（不改任何已跟踪文件）。

### 与旧资产的关系

`probe` / `repair` / `referee` 与 `issue-triage` / `log-analysis` / `minimal-patch` 全部保留不动。新组件一律用 `issue-fix-` 前缀、自成一体：装到全局后不能依赖项目级 skill，且同名会冲突。
注意旧 agent 存在 E3/E4 两个洞（`websearch` 实际放开、`read: allow` 重新放开 `.env`）——属既有资产，本设计不改动，仅在此记录。

---

## 7. 权限矩阵（v1 配置，1.19.0）

| 权限 | issue-fix | issue-fix-verifier |
|---|---|---|
| read | `*` allow，随后 deny `.env` / `.pem` / `id_rsa` / `.ssh` / `.aws` | 同左，且 deny `**/.issue-fix/**`（盲审时不能偷看问题单） |
| edit | `*` allow，deny `.git/**` `.github/**` `.opencode/**` `.claude/**` `**/node_modules/**` | `deny` |
| bash | `*` ask；放行 git 只读 + `git stash create` + 五类语言的测试/构建；deny 提交类、安装类、联网类、提权类 | 同上但更窄 |
| task | `*` deny，`issue-fix-verifier` allow | `*` deny |
| skill | `*` deny，`issue-fix-*` allow | `*` deny（且 P1 表明实际也用不了） |
| webfetch / websearch / external_directory | deny | deny |
| question / todowrite / lsp / glob / grep / list | allow | question deny，其余 allow |

其他要点：`steps` 是每个 agent 的总上限，无法按阶段分配；`write` 权限键永远不生效，只写 `edit`；`"*"` 必须写在表的第一项。

---

## 8. 多语言要点

| 语言 | 复现测试放哪 | 跑单个测试 | 重复运行的陷阱 |
|---|---|---|---|
| Java/Kotlin | `src/test/...`，包路径与被测代码一致 | `mvn -q -Dtest=Cls#m test` / `./gradlew test --tests 'Cls.m'` | Gradle 增量会跳过测试 → `--rerun-tasks` 或 `cleanTest` |
| Python | 跟随现有 `tests/` | `pytest path::test -x -q` | 固定随机种子 |
| JS/TS | 跟随现有 `*.test.ts` / `__tests__/` | `vitest run` / `jest -t` / `node --test` | 必须显式 `vitest run`，避免 watch |
| Go | 同包 `*_test.go` | `go test ./pkg -run '^TestX$' -count=1` | 不加 `-count=1` 则缓存让重复运行无意义 |
| Rust | 模块内 `#[cfg(test)]` 或 `tests/` | `cargo test name -- --exact` | 编译慢 |
| C/C++ | gtest / Catch2 / ctest；无框架时用 `.issue-fix/` 下的独立程序 | `ctest -R name --output-on-failure` | 构建系统差异最大，必要时问一次并记到 `.issue-fix/profile.json` |

跨语言结果**不可合并平均**：同一方法 Python 36.20%、JavaScript 1.40%，约 26 倍（C27/C28）；3 个及以上文件改动时成功率跌破 10%（C29）。

---

## 9. 评测与消融（M4）

- **用例**：每种语言至少 4 个，共约 20–24 个。来源：示例仓库里人为植入的 bug；真实历史 bug（回退修复提交、用原始 issue 文本、修复 PR 的测试作隐藏判据）；可选从 Multi-SWE-bench 与 SWE-bench Verified 抽样。
- **标注**：语言、问题单清晰度、测试覆盖度（各 0–3，C36）、类型（C38）。难度按多次实测通过率定义，不靠人工判断（人工与实测相关性仅 r=0.436，C41）。
- **防偷看**：隐藏测试不进工作区；记录是否尝试读取评测目录（C51：密封环境里五分之四的运行会去找隐藏材料）。
- **指标**：隐藏测试是否通过；复现测试是否有效（base 上失败、标准答案上通过）；无证据收尾比例；改动精度；该放弃时是否放弃；token / 时间 / 工具调用次数。**按语言和难度分开报告。**
- **消融**：`B0` 内置 build agent → `A0` M1 → `A1` +verifier → `A2` +插件门禁 → `A3` +investigator → `A4` +变异加固。每配置每用例 ≥3 次。
- **运行方式**：`opencode run --command issue-fix "<ticket>" --agent issue-fix --auto --dir <一次性 worktree>`。产品不做无人值守，评测专用。

---

## 10. 里程碑

| 里程碑 | 内容 | 状态 |
|---|---|---|
| **M0** | 1.19 机制实测 + 本设计文档 | ✅ 完成（E1–E12 实测；P1–P4 待验，free tier 阻塞） |
| **M1** | 纯 Markdown：2 个 agent、6 个 skill + 5 份语言说明、`/issue-fix`、安装脚本、5 个评测用例 + runner | ✅ 完成。Java / JS / Python 三个用例端到端跑通（各一次，均 `FIXED`，oracle 通过，agent 自写复现测试）；Go / Rust 用例因本机缺工具链跳过 |
| **M2** | `issue-fix-guard` 插件：账本工具、改源码锁、防篡改、抗压缩 + 单测；先把 `@opencode-ai/plugin` 从 1.2.24 对齐 | 未开始 |
| **M3** | `issue-fix-investigator` + 复现测试变异加固 | 未开始 |
| **M4** | 评测集与消融 | 未开始 |
| **M5** | 移植到 OpenCode 2（`permissions` 数组、`shell`、`subagent`、v2 插件 API） | 未开始 |

### M1 实测补充（评测侧）

评测 harness 本身暴露了三个必须修的问题，都已修：

1. **oracle 污染**：最初把隐藏测试以未跟踪文件形式留在工作区里，Java 用例中 agent 发现了 `InvoiceOracle.java`、分析了它是否可信，然后直接采用它作为自己的复现测试。这与 C51 描述的行为一致（密封环境中仍有约五分之四的运行去找隐藏评分材料）。**改为：oracle 只在 agent 结束后拷入用于评分**，并新增 `oracle_leak` 字段记录。
2. **基础设施失败被当成修复失败**：免费层 `Bad Request` 会让 agent 在任意阶段中断。新增 `abort_reason` 字段与 `ABORTED_INFRA` 终态，基础设施中断不计入成功率。
3. **终态抽取不可靠**：报告模板里列了全部 7 个终态名，裸 grep 会误匹配。改为只认「标题行携带终态」或「显式 `Terminal state:` 行」，并以 agent 日志兜底。

### 改名记录（2026-10-13）

`bugfix` → `issue-fix` 全量重命名（与同事的 agent 撞名）。改名后复测：agent 清单、编译规则（task/skill glob、read/bash 表序）、6 个技能发现（注意 `debug skill` 管道输出截断，需落盘后解析）、fixture 自检、安装/卸载闭环、`npm test` 全部通过。运行中日志确认 `→ Skill "issue-fix-reproduce"` 加载成功、语言说明被读取（skill glob 的运行时验证）。端到端两次因免费层模型挂起未完成（`build` 短上下文秒回，长上下文挂起 → 记 `ABORTED_INFRA`，属基础设施而非改名缺陷；改名前三用例已端到端跑通）。

### M1 验收标准

1. `opencode debug agent issue-fix` 的编译规则顺序与本设计一致（read 表在最后、bash 表 `"*"` 在最前、task/skill 白名单正确）。
2. 5 个冒烟用例都能走到 `FIXED`，且复现测试在修复前失败、修复后通过。
3. 给新功能需求 → 结局 `NOT_A_BUG`；给不可复现的问题单 → `NOT_REPRODUCIBLE`，且全程无源码改动。
4. 无 commit、无测试期望值改动、`git status` 里没有非预期文件。
5. `probe` / `repair` / `referee` 行为不变。

---

## 11. 风险

| 风险 | 对策 |
|---|---|
| 流程复杂度抵消模型红利 | 每个组件都要过消融（C52），没提升就砍 |
| 复现测试误导方向 | 失败原因必须匹配 + verifier 盲审 + 变异加固（CoHarden：宽松 +0，对齐 −3.6） |
| flaky / 时序 bug | 每次 3 遍；疑似 flaky 单独处理；压力循环设预算（4.56% 噪声地板，C42/C43） |
| 长会话上下文膨胀 | skill 按需加载；命令输出只留 10–20 行错误片段；状态落 case 文件；M2 压缩时注入 |
| 问题单夹带指令注入 | 定界符包成数据；bash 默认 ask；禁网 |
| 权限不是沙箱 | TUI 有人确认；无人值守必须容器化 |
| 版本漂移 | 逻辑放 Markdown，插件只做强制；M5 移植并重测 |
| 新旧 agent 混淆 | `issue-fix-` 命名空间 + task/skill 规则隔离 + README 对照表 |
| 工作区有用户改动 | `git stash create` 拍 base，绝不 stash / reset / clean |
| C/C++ 成功率极低（C27 约 1.5%） | 提前说明；按语言报告；必要时只交付诊断结论 |

---

## 12. 设计原则与依据索引

| # | 原则 | 依据 |
|---|---|---|
| P1 | 先复现再改源码，且用工具强制 | Dynamic cogeneration 75%；CoHarden −7.0pp；Debug2Fix +10–13pp |
| P2 | 每条需求一个复现，失败原因与问题单一致 | SWE-Doctor；ReProAgent 56.9%→18.8% |
| P3 | 复现测试要严格，能识别"看起来对"的错修复 | CoHarden +8.5pp / 宽松 +0 / 对齐 −3.6pp；48% 未解决案例被自己的测试放过 |
| P4 | 定位先粗后细、多路证据、栈只当起点 | C04（方法 26% vs 语句 4%）、C03/C06、C05、C17；确定性调用关系锚点 +2.2pp 且方差减半 |
| P5 | 无运行时证据不进入修复 | SWE-Doctor；DAIRA（原始轨迹无收益，结构化摘要有效） |
| P6 | 收尾要有可区分证据 | arxiv-2607.28871（46% / 23.8%） |
| P7 | 不自证，验证要信息隔离 | RETRACE +7.0/+3.6pp；SWE-Review；Looping 29.5% vs 2.4%；C23 7.8% / 29.6% |
| P8 | 循环有上限，保留最佳，证据绑定代码状态 | Is-Three；VRR-Stop；Looping（陈旧输出毁 34/135） |
| P9 | 重试从干净代码重来 | 安慰剂对照 40:3；PROBE +12.5pp |
| P10 | 最小化是独立步骤 | RECAP +122%；PDB 精度 <45%；21.4% 夹带重构 |
| P11 | 保护测试完整性 | FlowAgent；LLM 回归测试 8–17% 固化 bug；mini-swe-agent 禁改测试 |
| P12 | 执行是有预算的资源 | 禁执行 vs 不限执行只差 1.25pp（不显著），省 56–62% token |
| P13 | 诚实报告，证据分级 | 22.6% 自我汇报不准确（20,574 真实会话） |
| P14 | 问题单不可信；权限是确认门不是沙箱 | `issue-triage`；官方 v2 Directories 警告原文 |