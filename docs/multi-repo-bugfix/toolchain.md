# 跨仓定位工具矩阵

> "维护状态"一列的判定方式：对 GitHub REST API `/repos/{owner}/{repo}` 取 `archived`、`pushed_at`、`license.spdx_id`、`stargazers_count`（本轮取数日期：**2026-10-08**）。`pushed_at` 是**最近推送时间**，是活跃度的客观代理；**不等于**该工具已被本调研验证功能可用。
> 阶段编号对应 `cross-repo-localization.md` 的①–⑤。

---

## 1. 代码图谱类

| 工具 | 解决哪一步 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **GitNexus** | ②建图 / ③传播假设 / ④爆炸半径 | 输入：本地 git 仓库；输出：`.gitnexus/` 下的 LadybugDB 知识图谱 + MCP 工具（`query` / `context` / `impact` / `trace` / `detect_changes` / `check` / `cypher` / `route_map` / `tool_map` / `shape_check` / `api_impact` / `explain` / `pdg_query`，共 17 个）；`group sync` 抽取跨仓契约，`group impact` 给跨仓爆炸半径 | **默认全本地、无网络**（README："Everything local, no network"）；索引写入仓库内 `.gitnexus/`（gitignored）+ 全局注册表 `~/.gitnexus/registry.json`；`gitnexus setup` 会**写编辑器的 MCP 全局配置**，并可注册 Claude Code hooks——这是**唯一需要留意的副作用**；`GITNEXUS_MCP_READ_ONLY=1` 可只暴露只读面 | Tree-sitter 原生 bindings（覆盖取决于 Tree-sitter grammar 可用性；README 提到 "log skipped files when parsers are unavailable"） | **活跃**。`abhigyanpatwari/GitNexus`，license = **NOASSERTION**（GitHub 未能识别，README 声称开源但**未能确认具体 license**，这是合规风险点，见下），`archived=false`，`pushed_at=2026-10-07`，47,766 stars | 退回到构建系统的 affected 计算（Nx/Bazel）+ 人工 grep；跨仓部分退到"逐仓分别建图 + 手工对照契约文件" |
| **Sourcegraph / SCIP** | ②建图 / ④爆炸半径 | 输入：仓库集合（SCIP 索引）；输出：符号级精确的引用图 | 索引需要把镜像推到托管平台（CodeScaleBench 明确说明：需要把 ~180 个仓库镜像到 GitHub org 并 pin commit，因为 "Sourcegraph Deep Search indexes only HEAD"）；**这会产生网络写操作**，在受限环境不可行 | 多语言（SCIP indexer 按语言分实现） | 活跃。`scip-code/scip`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-07`，827 stars。`sourcegraph/sourcegraph` 本轮 API 调用**未返回**（未核实其自身 license 与推送时间） | CodeScaleBench 自身给出了对照基线：仅用本地工具（grep/glob/read）的 agent 在 starter pack 上 mean 0.722，说明**并非必须建全图**；可只建受影响子图 |
| **CodeQL** | ④判别性实验（找危险数据流） | 输入：源码 + 可选查询；输出：告警 | 查询在数据库中执行；部分查询需要编译（Java/C#） | 面向 C/C++/C#/Go/Java/JavaScript/TypeScript/Python/Ruby/Swift 等的 dataflow 分析 | 活跃。`github/codeql`：**MIT**，`archived=false`，`pushed_at=2026-10-07`，10,174 stars | 用语言原生 linter（`rg` + 正则）+ 人工审计关键路径 |

### 跨仓检索的量化证据

Sourcegraph CodeScaleBench 技术报告（本轮读取报告正文）：
- 370 个任务（SDLC 150 + Org 220），9 种主语言，40+ 开源仓库。
- Org 任务要求信息分布在 **3–20 个仓库**。
- 检索质量：Precision@10 **0.095 → 0.313**，Recall@10 **0.120 → 0.272**，F1@10 **0.091 → 0.240**。
- 效率：平均每任务成本 **$0.7333 → $0.5121（−30.16%）**，wall-clock **−36.22s**，agent 执行时间 **−101.06s**。
- 配对 reward 差：**总体 +0.0349**（n=370，95% CI [+0.0130, +0.0579]）；SDLC +0.0363，Org +0.0339（n=220，95% CI [+0.0133, +0.0571]）。
- 报告结论："MCP retrieval gains are larger on multi-repo tasks than single-repo tasks"。

> ⚠️ **该报告的注意事项**：它是 Sourcegraph 自家基准、自家工具、自家镜像（信息对等由 baseline 本地 clone 提供），且基线 P@5 = 0.007 / R@5 = 0.002 的极端低值受"任务分布"影响很大。**引用其绝对数值时应标注为"单方报告"**。

---

## 2. 依赖规则与影响面类

| 工具 | 解决哪一步 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **dependency-cruiser** | ②建图（编译期依赖） | 输入：`dependency-cruiser` 配置；输出：依赖图 + 违规规则报告 | 纯静态分析，无写操作（除输出报告文件）；可作为 CI 门禁 | JavaScript / TypeScript 生态 | 活跃。`sverweij/dependency-cruiser`：**MIT**，`archived=false`，`pushed_at=2026-10-01`，7,264 stars | 对 JS 仓用 `tsc --listFiles` / `madge`；对其他语言用各自 import 图工具 |
| **ArchUnit** | ②建图 + ⑤确认门（架构规则） | 输入：Java 规则（可写在测试里）；输出：违规列表 | 可写成 JUnit 测试，在 CI 中以测试失败呈现——**无额外权限** | Java / JVM | 活跃。`TNG/ArchUnit`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-08`，3,852 stars | JVM 内用 ArchUnit 的等价物（jdeps 已在 JDK 内置）；非 JVM 语言不适用 |
| **jdeps**（JDK 内置） | ②建图 | 输入：`.class` / `.jar`；输出：包级依赖 | **零外部依赖**（JDK 自带）→ 这是它作为兜底的价值所在 | 仅 JVM | 随 JDK 发行，无独立仓库可查（本轮**未核实**其独立维护状态，因为它不存在独立仓库） | 无需兜底 |
| **Nx `affected`** | ④爆炸半径（仓内） | 输入：git base/head + project graph；输出：受影响 project（或 task）集合 + `--explain` 原因 | 需 `fetch-depth: 0` 的完整 git 历史；base 应设为 main 上**最近一次成功 commit**；`NX_LEGACY_AFFECTED=false` 可下沉到 task 级 | JS/TS 为主，另有 Rust/Go/.NET/Python 等插件 | 活跃。`nrwl/nx`：**MIT**，`archived=false`，`pushed_at=2026-10-08`，29,394 stars | 单仓 CI 跑全量（更贵但更安全）；跨仓则需手工维护 affected 集合 |
| **Turborepo** | ④爆炸半径（仓内） | 输入：包依赖图 + git；输出：受影响 task 集合 | 同上类 | JS/TS 为主 | 活跃。`vercel/turborepo`：**MIT**，`archived=false`，`pushed_at=2026-10-07`，31,178 stars | 同 Nx |
| **Bazel affected targets** | ④爆炸半径 | 输入：构建图 + `--experimental_affected_targets` / `bazel query rdeps`；输出：需重跑目标 | 需正确的 WORKSPACE/MODULE 声明；外部依赖需 `repository_cache` 或外部网络 | 跨语言（因各语言 rule 存在） | 活跃。`bazelbuild/bazel`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-08`，25,923 stars | 全量 build；或改用 Nx/Turbo |
| **GitHub dependency graph** | ②建图（生态级） | 输入：仓库网络配置；输出：仓库间依赖关系 | 依赖 GitHub 侧配置与可见性；**跨组织私有仓信息不完全可得** | 语言无关（基于清单文件推断） | 【本轮未单独核实其文档状态】 | 用各仓 manifest（`package.json` / `pom.xml` / `go.mod`）自行汇总 |

> **跨仓的硬边界**：上表全部是**仓内**工具。polyrepo 下"affected"必须在**仓之间**再做一次，而这一步目前没有通用工具——BeyondSWE 的 CrossRepo/DepMigrate 与 CodeScaleBench 的 Org 子集都表明这正是 agent 最弱的一环。〔论文 / 报告，已核实〕

---

## 3. 接口契约与版本偏斜类

| 工具 | 解决哪步骤 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **buf**（`buf breaking`） | ③假设生成（语义不兼容） / ⑤确认门 | 输入：两份 `.proto` 编译产物（image）；输出：破坏性变更清单，规则与类别可在 `buf.yaml` 声明 | 纯静态；对比可对 git 历史 | protobuf 全生态（Go/Java/Python/Rust/TS 等 codegen） | 活跃。`bufbuild/buf`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-07`，11,476 stars | 手改 `.proto` 时靠 `git diff` + 双人评审；或用各语言的 protobuf linter |
| **japicmp** | ③ / ⑤ | 输入：两份 JAR / 模块；输出：不兼容变更报告 | 纯静态 | JVM | 活跃。`siom79/japicmp`：**Apache-2.0**，`archived=false，`pushed_at=2026-10-03`，781 stars | `revapi`；或 JVM 内置 `jdeps` 做粗粒度对比 |
| **Pact**（pact-jvm） | ④判别性实验 | 输入：消费方声明的期望 + 提供方部署；输出：契约测试通过/失败 | 需要**能起提供方服务**（本地/预发）→ 这是它相对静态检查的主要成本 | JVM 为主；pact-jvm 之外有 pact-js / pact-go / pact-python 等独立实现 | 活跃。`pact-foundation/pact-jvm`：**Apache-2.0**，`archived=false`，`pushed_at=2026-09-25`，1,147 stars | 录制/回放 HTTP fixture 做集成测试；或至少让消费方跑自己的契约 mock 测试 |
| **OpenAPI diff** | ③ / ⑤ | 输入：两份 OpenAPI 文档；输出：差异与兼容性判定 | 纯静态 | 语言无关 | 【本轮未单独核实】 | `swagger-cli` diff；或契约测试替代 |

---

## 4. 可观测性与追踪类

| 工具 | 解决哪步骤 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **OpenTelemetry 语义约定** | ②建图（运行期图） / ③传播假设 | 输入：埋点；输出：统一命名的 span / metric / log | 埋点是**侵入式改动**（需在各服务加 SDK）；Seer 实测 tracing 开销 <0.1% 延迟、<0.15% QPS（未采样）〔论文，已核实〕 | 语言无关（多语言 SDK） | 活跃。`open-telemetry/semantic-conventions`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-07`，663 stars；`open-telemetry/opentelemetry-specification`：**Apache-2.0**，`pushed_at=2026-10-06`，4,347 stars | 无 OTel 时用服务间 access log + 统一 `request-id` 透传；代价是丢失细粒度 span 结构 |
| **Jaeger**（查询端） | ④判别性实验 | 输入：trace；输出：按 span 的调用树与延迟 | 只读查询（Sage 即用 Jaeger 做 RPC trace）〔论文，已核实〕 | 语言无关 | 【本轮未单独核实其仓库状态】 | 直接查 trace 后端（Zipkin / Tempo / 云厂商 APM） |
| **Zipkin** | 同上 | 同上 | 同上 | 语言无关 | 【本轮未单独核实】 | 同上 |

> **可观测性的失效边界（必须写进兜底）**：Seer 明确指出，仅轮询 NIC 队列深度会**漏掉应用实现层的性能/效率 bug**（如微服务间 blocking）。Sage 之所以用 CBN + counterfactual，正是因为**单靠相关性排序会在依赖图上找错路径**（其对比中 CauseInfer 与 Microscope 常找错路径）。所以"没有 trace"时，方法论上应**降低结论等级**到"相关性排序"，而不是用日志硬凑。〔论文，已核实〕

---

## 5. 混沌 / 故障注入类

| 工具 | 解决哪步骤 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **Chaos Mesh** | ④判别性实验 | 输入：实验 spec；输出：注入的故障 + 系统响应 | **副作用强**：需要 K8s 集群权限（Pod kill、流量注入、网络分区）；必须有 blast radius 限制与中止机制 | 语言无关（基础设施层） | 活跃。`chaos-mesh/chaos-mesh`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-03`，7,933 stars | 只在本地/预发做；生产环境改为**只读诊断**（Seer 的做法：无 perf counters 时改用 10 个可调 microbenchmark）〔论文，已核实〕 |
| **ChaosBlade** | ④判别性实验 | 输入：实验 spec；输出：注入与恢复记录 | 同上（且**明确需要较高权限**） | 语言无关 | 【未核实】——本轮 `alibaba/ChaosBlade` 的 GitHub API 调用**未返回**（既可能仓库路径不同，也可能限流）。**在核实前不应写入结论** | 同 Chaos Mesh |
| **Principles of Chaos Engineering** | 方法论 | — | — | — | 【本轮未核实抓取】 | — |

---

## 6. 静态分析类

| 工具 | 解决哪步骤 | 输入 / 输出 | 权限与副作用 | 语言支持 | 维护状态与最近活跃度 | 不可用时的兜底 |
|---|---|---|---|---|---|---|
| **ArchUnit** | ⑤确认门 | 见 §2 | 见 §2 | JVM | 见 §2 | 见 §2 |
| **CodeQL** | ④判别性实验 | 见 §1 | 见 §1 | 见 §1 | 见 §1 | 见 §1 |
| **OSV-Scanner** | ②（生态依赖图） | 输入：SBOM / lock 文件；输出：已知漏洞清单 | 只读 | 语言无关 | 活跃。`google/osv-scanner`：**Apache-2.0**，`archived=false`，`pushed_at=2026-10-08`，11,150 stars | 各语言原生 audit（`npm audit` / `govulncheck` 等） |

---

## 7. 工具使用总则（跨仓特有）

1. **先声明图的类型，再声明结论的强度**。编译期图 / 契约图 / 运行期图覆盖的边集合不同；混用会导致"看起来完备"的错觉。
2. **爆炸半径只能取上界，不能取下界**。Nx 官方文档已列出会低估的场景：`dependsOn` 不传递影响、inputs 未声明、sync generator 运行中改文件。**凡基于 affected 的"无需重测"结论，都应标注为"基于本工具的图完备性假设"**。〔规范〕
3. **索引新鲜度本身要监控**。GitNexus 提供 `gitnexus status` / `group status` 做这件事；Sourcegraph 只索引 HEAD 的行为（CodeScaleBench 报告）说明**不 pin commit 的索引会给错答案**。〔规范 + 报告，已核实〕
4. **降级链是常态而非异常**。全链路降级顺序：`代码图谱 → 构建系统 affected → 契约文件 diff → 人工清单`。每一级都要能在 2 小时内产出可执行结论，否则流程会卡死在"等工具"。〔工程惯例〕

## 8. 未核实项（不得混入结论）

- **CloudRanger / FreeLPA / MicroRank**：本轮未能打开权威页面（ACM DL 403、dblp 被 Anubis 反爬拦截、arXiv API 429）。
- **Microscope（WSDM 2020）**：venue 与 DOI 未能核实。仅确认存在 Microscope 系列工作（ICSOC 2018 版本由 MicroRCA 与 Sage 的引用列表提及）。
- **GitHub dependency graph / OpenAPI diff / Zipkin / Jaeger / ChaosBlade / Principles of Chaos Engineering**：本轮未完成 webfetch 核实。
- **GitNexus 的 license**：GitHub API 返回 `NOASSERTION`（未识别），README 声称 "Open source — audit the code yourself"。**在合规审查场景下不可当作已确认的开源许可**。
