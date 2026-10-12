# 离线研究资料索引

本目录保存可离线阅读的一手资料。论文优先使用 PDF；工程文章保存 HTML；被 403 拦截的 OpenAI evals 页面用 arXiv 替代论文补齐。

## 多 Agent 系统

| 文件 | 资料 | 状态 |
|---|---|---|
| `mast-why-do-multi-agent-llm-systems-fail.pdf` | *Why Do Multi-Agent LLM Systems Fail?* | 有效 PDF，20 页 |
| `nature-capable-language-models-outgrow-benefits-of-collaboration.html` | *Capable language models can outgrow the benefits of collaboration* | Nature Machine Intelligence HTML |
| `when-agents-coordinate.html` | *When Agents Coordinate: Measuring Coordination in Multi-Agent AI Coding* | arXiv HTML |

## 软件工程 Agent 与定位

| 文件 | 资料 | 状态 |
|---|---|---|
| `swe-agent.pdf` | *SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering* | 有效 PDF，118 页 |
| `agentless.pdf` | *Agentless: Demystifying LLM-based Software Engineering Agents* | 有效 PDF，25 页 |
| `sherloc.pdf` | *SHERLOC: Structured Diagnostic Localization for Code Repair Agents* | 有效 PDF |
| `swe-bench-solved-issues-really-solved.pdf` | *Are “Solved Issues” in SWE-bench Really Solved Correctly?* | 有效 PDF，11 页 |

## 工程实践与评估

| 文件 | 资料 | 状态 |
|---|---|---|
| `anthropic-multi-agent-research-system.html` | *How we built our multi-agent research system* | Anthropic 工程文章 HTML |
| `anthropic-building-effective-agents.html` | *Building Effective AI Agents* | Anthropic 工程文章 HTML |
| `anthropic-demystifying-evals-for-ai-agents.html` | *Demystifying evals for AI agents* | Anthropic 工程文章 HTML |
| `agentasseval-tracing-framework.pdf` | *AgentAsSystEval: Evaluating Computer-Control Agents* | arXiv 替代论文，覆盖 tracing/eval 主题 |

## 未成功下载

OpenAI 的以下两页当前由站点访问控制返回 403 或内容不完整，未能保存：

1. *Orchestration and handoffs*：https://developers.openai.com/api/docs/guides/agents/orchestration
2. *Evaluate agent workflows*：https://developers.openai.com/api/docs/guides/agent-evals

如需完整离线版本，建议在浏览器打开后手动保存页面，或之后在有授权的环境重新抓取。

---

# 追加：多仓 / 多服务问题单定位与协同修复（2026-10-08 补充调研）

以下内容为本轮新增，**不删除上方任何既有条目**。

## A. 失效条目的更正记录

### A.1 `agentasseval-tracing-framework.pdf` —— **失效并已移除**

**原索引条目**：`AgentAsSystEval: Evaluating Computer-Control Agents`（标注为"arXiv 替代论文，覆盖 tracing/eval 主题"）。

**核查过程与结论**：

| 步骤 | 结果 |
|---|---|
| `file(1)` | `PDF document, version 1.5, 6 pages` |
| PDF 元数据 | `/Creator = LaTeX with hyperref`、`/Producer = pdfTeX-1.40.25`、`/CreationDate = D:20250411002001Z`；`/Title` 与 `/Author` **均为空** |
| 内嵌 PDF 对象 | 多个内嵌图对象带 `/Author (hidet)`、`/Title (fig_bond_config.ai)`、`/Title (phase_diagram3.ai)`、`/Title (fig2-1.ai)` —— Adobe Illustrator 导出的**物理相图** |
| 首页文本抽取（pypdf） | 真实标题：**"Instability of the ferromagnetic phase under random fields in an Ising spin glass with correlated disorder"**；作者 **Hidetoshi Nishimori**（Institute of Integrated Research, Institute of Science Tokyo / Tohoku University / RIKEN iTHEMS）；页面标注 `(Dated: April 11, 2025)`；正文含 `I. INTRODUCTION`、引用 Imry and Ma、Edwards-Anderson 模型 |
| 实际页数 | 10 页（`file(1)` 报 6 页，为线性化差异；以 pypdf 解析为准） |

**判定**：该文件是**统计物理/凝聚态物理论文**（关联无序自旋玻璃的随机场不稳定性），与 Agent 追踪 / 评测框架**完全无关**。原索引的标题与作者**均属错误标注**。

**处置**：已按要求**删除该错误文件**（`rm` 于 2026-10-08，删除前大小 560,179 字节）。

**对"AgentAsSystEval"本身的检索结果**：以 `"AgentAsSystEval"` 为关键词、经两轮不同措辞的 websearch（"AgentAsSystEval arXiv"、'"AgentAsSystEval" agentic diagnostic systems environment traces arxiv 2506'），**未检索到任何以该名称发表的论文、预印本或评测框架**。因此【未核实】：该条目所指向的成果是否存在，无法确认；**不得凭名称推断其存在**。

**替代补齐**：以主题（agent 执行追踪 + 错误定位评测）而非错误名称重新检索，找到并下载了两篇可核实的替代文献：

| 文件 | 真实标题 | 作者 | 核实状态 |
|---|---|---|---|
| `trail-2505.08638.pdf` | *TRAIL: Trace Reasoning and Agentic Issue Localization*（arXiv:2505.08638v3, 2025-06-23） | Darshan Deshpande, Varun Gangal, Hersh Mehta, Jitin Krishnan, Anand Kannappan, Rebecca Qian | **已核实**（arXiv 页面 + PDF 25 页首页文本） |
| `agentracer-2509.03312.pdf` | *AgenTracer: Who Is Inducing Failure in the LLM Agentic Systems?*（arXiv:2509.03312） | PDF 首页署名 Gui…（本轮未逐字录完全部作者，见"未核实"节） | **部分核实**（PDF 18 页首页文本匹配标题） |

### A.2 原"未成功下载"的两篇 OpenAI 文档 —— **仍未获取**

| 目标 URL | 本轮尝试 | 结果 |
|---|---|---|
| https://developers.openai.com/api/docs/guides/agents/orchestration | 直接 curl（带 User-Agent） | **HTTP 403**，站点访问控制 |
| https://developers.openai.com/api/docs/guides/agent-evals | 直接 curl（带 User-Agent） | **HTTP 403** |
| https://web.archive.org/web/2025/… | curl `--max-time 60` | **连接超时**（`curl (28) Connection timed out`，archive.org 在本网络环境不可达） |
| http://archive.org/wayback/available?url=… | curl `--max-time 25` | **连接超时**（`curl (28)`） |

**结论**：两篇文档**均未获取**。web.archive.org 与 archive.org 的可用性 API 在本环境**整体不可达**（不是这两个 URL 特有问题，已用 `archive.org` 主站与可用性 API 两次交叉确认）。**不得**以任何 arXiv 论文冒充这两篇官方文档的替代品——它们是**版本化工程指南**而非学术论文，替代会引入事实错误。

## B. 新增原文索引表（含校验信息）

- 校验方式：每个 PDF 经 `file(1)` 确认容器类型 + `pypdf` 抽取首页文本核对标题/作者；sha256 取前 12 位；页数以 `pypdf` 解析为准（`file(1)` 的页数在线性化 PDF 上会偏小）。
- **下载日期统一为 2026-10-08。**

### B.1 论文（PDF）

| 文件名 | 标题 | 作者 | 来源 URL | 字节数 | sha256前12 | 页数 | 状态 |
|---|---|---|---|---|---|---|---|
| `microrca-noms2020.pdf` | MicroRCA: Root Cause Localization of Performance Issues in Microservices | Li Wu, Johan Tordsson, Erik Elmroth, Odej Kao | https://inria.hal.science/hal-02441640/document | 740,010 | `2acc191e330e` | 10（含 HAL 封面页 1） | 有效。IEEE/IFIP NOMS 2020, pp. 1–9；DOI `10.1109/NOMS47738.2020.9110353` |
| `sage-asplos2021-2101.00267.pdf` | Sage: Using Unsupervised Learning for Scalable Performance Debugging in Microservices | Yu Gan, Mingyu Liang, Sundar Dev, David Lo, Christina Delimitrou | https://arxiv.org/pdf/2101.00267 | 1,937,986 | `9e4ef0bf0861` | 13 | 有效。arXiv:2101.00267；会议版 ASPLOS'21 标题与 DOI `10.1145/3445814.3446700` 不同 |
| `beyondswe-2603.03194.pdf` | BeyondSWE: Can Current Code Agent Survive Beyond Single-Repo Bug Fixing? | Guoxin Chen, Fanzhe Meng, Jiale Zhao, Minghao Li, Daixuan Cheng, Huatong Song, Jie Chen, Yuzhi Lin, Hui Chen, Xin Zhao, Ruihua Song, Chang Liu, Cheng Chen, Kai Jia, Ji-Rong Wen | https://arxiv.org/pdf/2603.03194 | 10,303,506 | `af8aa5d55283` | 28 | 有效。arXiv:2603.03194（v2, 2026-05-26）；DOI `10.48550/arXiv.2603.03194` |
| `multi-swe-bench-2504.02605.pdf` | Multi-SWE-bench: A Multilingual Benchmark for Issue Resolving | Daoguang Zan, Zhirong Huang, Wei Liu, Hanwu Chen, Linhao Zhang, Shulin Xin, Lu Chen, Qi Liu, Xiaojian Zhong, Aoyan Li, Siyao Liu, Yongsheng Xiao, Liangqiang Chen, Yuyu Zhang, Jing Su, Tianyu Liu, Rui Long, Kai Shen, Liang Xiang | https://arxiv.org/pdf/2504.02605 | 7,042,084 | `4de921d8d88a` | 32 | 有效。arXiv:2504.02605（v1, 2025-04-03）；**注意：NeurIPS 2025 D&B 版本为 2,132 实例 / 8 语言，与 arXiv v1 的 1,632 实例 / 7 语言不同** |
| `falat-2606.00765.pdf` | FALAT: Tracing Failures in LLM Agent Trajectories via Dependency-Guided Search | Md Nakhla Rafi, Md Ahasanuzzaman, Dong Jae Kim, Zhijie Wang, Tse-Hsun Chen | https://arxiv.org/pdf/2606.00765 | 549,003 | `4f82b059a557` | 17 | 有效。arXiv:2606.00765（2026-05-30） |
| `trail-2505.08638.pdf` | TRAIL: Trace Reasoning and Agentic Issue Localization | Darshan Deshpande, Varun Gangal, Hersh Mehta, Jitin Krishnan, Anand Kannappan, Rebecca Qian | https://arxiv.org/pdf/2505.08638 | 2,644,981 | `9d7dc90d3343` | 25 | 有效。arXiv:2505.08638v3（2025-06-23）。**替代失效条目 A.1 的追踪/评测文献** |
| `agentracer-2509.03312.pdf` | AgenTracer: Who Is Inducing Failure in the LLM Agentic Systems? | 见"未核实"说明 | https://arxiv.org/pdf/2509.03312 | 7,768,508 | `cd10c5315aeb` | 18 | 有效 PDF（标题匹配）。**作者列表未逐字录全 → 部分核实** |
| `swe-explore-2606.07297.pdf` | SWE-Explore: Benchmarking How Coding Agents Explore Repositories | Shaoqiu Zhang, Yuhang Wang, Jialiang Liang, Yuling Shi, Wenhao Zeng, Maoquan Wang, Shilin He, Ningyuan Xu, Siyu Ye, Kai Cai, Xiaodong Gu | https://arxiv.org/pdf/2606.07297 | 875,316 | `b06d9e16e8c4` | 20 | 有效。arXiv:2606.07297 |
| `agentopseval-2606.29193.pdf` | A Multi-Dataset Benchmark for Evaluating LLM Agents in Microservice Failure Diagnosis | Yuanhong Cai, Xiaohui Nie, Kanglin Yin, Changhua Pei, Yongqian Sun, Shenglin Zhang, Haibin Liu, Guiyang Liu, Xidao Wen（前 9 位由 PDF 首页逐字录取；余下作者未录全） | https://arxiv.org/pdf/2606.29193 | 3,546,190 | `e417a0fff0a9` | 10 | **有效**（首次下载截断，经 `curl -C -` 断点续传后完整，首页标题/作者/机构匹配）。arXiv ID 来自下载 URL，**未单独打开 arxiv.org abs 页复核** |

### B.2 既有 PDF 的复核（本轮重新校验，页数与既有索引存在出入）

| 文件名 | 页数（`pypdf`） | sha256前12 | 备注 |
|---|---|---|---|
| `mast-why-do-multi-agent-llm-systems-fail.pdf` | 47 | `1b9e317a2a42` | 既有索引记"20 页"，**与实际 47 页不符**，建议更正 |
| `swe-agent.pdf` | 118 | `d171e0693060` | 既有索引"118 页"一致 |
| `agentless.pdf` | 25 | `1675c2dcd5ec` | 既有索引"25 页"一致 |
| `swe-bench-solved-issues-really-solved.pdf` | 13 | `b2db368d3c96` | 既有索引记"11 页"，**实际 13 页**，建议更正 |
| `sherloc.pdf` | 31 | `862b3137f088` | 有效 |

### B.3 工具与规范文档（HTML / Markdown，均已抓取原文）

| 文件名 | 内容 | 来源 URL | 字节数 | sha256前12 | 状态 |
|---|---|---|---|---|---|
| `gitnexus-readme.md` | GitNexus README（含 19 个 MCP 工具表、Repository groups、`group impact`/`group sync`、`GITNEXUS_MCP_READ_ONLY`） | https://raw.githubusercontent.com/AbhigyanPatwari/GitNexus/main/README.md | 129,798 | `4ccfd0f9cf1e` | 有效 |
| `nx-affected-docs.html` | Nx `affected` 官方文档（project/task 级选择、`--explain`、CI 配置、`projectsAffectedByDependencyUpdates`） | https://nx.dev/ci/features/affected | 277,356 | `0055a77c1f06` | 有效 |
| `buf-breaking-docs.html` | buf 破坏性变更检测文档 | https://buf.build/docs/breaking/ | 155,983 | `b9d99020bf60` | 有效 |
| `dependency-cruiser-readme.md` | dependency-cruiser README | https://raw.githubusercontent.com/sverweij/dependency-cruiser/main/README.md | 7,600 | `84886df812fd` | 有效 |
| `archunit-readme.md` | ArchUnit README | https://raw.githubusercontent.com/TNG/ArchUnit/master/README.md | 2,542 | `0af9222d5e0c` | 有效（内容较短，仅指向官网文档） |
| `pact-jvm-readme.md` | pact-jvm README | https://raw.githubusercontent.com/pact-foundation/pact-jvm/master/README.md | 11,483 | `b6f1e9a1b933` | 有效 |
| `japicmp-readme.md` | japicmp README | https://raw.githubusercontent.com/siom79/japicmp/master/README.md | 9,977 | `5016475a5a0f` | 有效 |

### B.4 工具维护状态的取数记录（GitHub REST API，2026-10-08）

| repo | license.spdx_id | archived | pushed_at | stars |
|---|---|---|---|---|
| `abhigyanpatwari/GitNexus` | **NOASSERTION** | false | 2026-10-07 | 47,766 |
| `nrwl/nx` | MIT | false | 2026-10-08 | 29,394 |
| `vercel/turborepo` | MIT | false | 2026-10-07 | 31,178 |
| `bazelbuild/bazel` | Apache-2.0 | false | 2026-10-08 | 25,923 |
| `github/codeql` | MIT | false | 2026-10-07 | 10,174 |
| `bufbuild/buf` | Apache-2.0 | false | 2026-10-07 | 11,476 |
| `siom79/japicmp` | Apache-2.0 | false | 2026-10-03 | 781 |
| `sverweij/dependency-cruiser` | MIT | false | 2026-10-01 | 7,264 |
| `TNG/ArchUnit` | Apache-2.0 | false | 2026-10-08 | 3,852 |
| `pact-foundation/pact-jvm` | Apache-2.0 | false | 2026-09-25 | 1,147 |
| `chaos-mesh/chaos-mesh` | Apache-2.0 | false | 2026-10-03 | 7,933 |
| `google/osv-scanner` | Apache-2.0 | false | 2026-10-08 | 11,150 |
| `scip-code/scip` | Apache-2.0 | false | 2026-10-07 | 827 |
| `open-telemetry/semantic-conventions` | Apache-2.0 | false | 2026-10-07 | 663 |
| `open-telemetry/opentelemetry-specification` | Apache-2.0 | false | 2026-10-06 | 4,347 |
| `alibaba/ChaosBlade` | — | — | — | **未返回 → 未核实** |
| `sourcegraph/sourcegraph` | — | — | — | **未返回 → 未核实** |

## C. "未获取 / 未核实"清单

### C.1 未获取（尝试过但失败）

| 目标 | 尝试方式 | 失败原因 |
|---|---|---|
| https://developers.openai.com/api/docs/guides/agents/orchestration | curl 直取 | HTTP 403 |
| https://developers.openai.com/api/docs/guides/agent-evals | curl 直取 | HTTP 403 |
| 同上两页的 web.archive.org 快照 | curl `web.archive.org/web/2025id_/…` | 连接超时（60s） |
| archive.org 可用性 API | curl | 连接超时（25s） |
| Seer ASPLOS'19 全文 PDF | `dl.acm.org` | HTTP 403；改用 `par.nsf.gov` / 作者主页版本核对（未落盘） |
| Microscope（WSDM 2020） | `dl.acm.org/doi/10.1145/3331166.3331605` | HTTP 403 |
| CloudRanger / FreeLPA / MicroRank 原文 | arXiv API（429）、dblp（Anubis 反爬） | 未能打开权威页面 |

### C.2 未核实（**不得进入正文结论**）

1. **"AgentAsSystEval: Evaluating Computer-Control Agents"是否存在** —— 两轮不同措辞检索均无结果。
2. **Microscope 的 WSDM 2020 venue** —— 任务书给出该 venue，本轮**未能核实**。可确认的只有：存在 Microscope 系列工作，其 ICSOC 2018 版（*Microscope: Pinpoint Performance Issues with Causal Graphs in Micro-Service Environments*，Springer, pp. 3–20，作者 Mingyu Lin / Peng Chen / Zheng Zhang）被 MicroRCA 与 Sage 的参考文献引用。
3. **CloudRanger / FreeLPA / MicroRank 的算法细节与量化指标** —— 仅有二手描述（CloudRanger："non-intrusive … exploits measurement data of both application layer and underlay infrastructure and a random walk procedure to improve its accuracy"，来自 Semantic Scholar 条目描述），**未打开一手原文**。
4. **AgenTracer 的完整作者列表** —— PDF 首页文本仅录到 "Gui…" 起始。
5. **arXiv:2606.29193 的官方元数据** —— PDF 已完整获取并核对标题/作者/机构（见 B.1），但 **arXiv ID 来自下载 URL 而非单独核对的 abs 页**，且作者列表仅录到前 9 位。该文献**未进入 `cross-repo-localization.md` 的正文结论**。
6. **Dapper（Google）与分布式追踪综述** —— 本轮未检索。
7. **决策论部分（F）** —— Popper 证伪主义、Kohonen 最小惊讶准则、主动学习/信息增益、anytime 算法、OODA 循环 —— **本轮未检索任何一手来源**，因此 `cross-repo-localization.md` 中**未引用任何 F 类文献**。该部分留作后续。
8. **GitNexus 的 license** —— GitHub API 返回 `NOASSERTION`，README 仅称 "Open source"。**不可当作已确认的开源许可**。
9. **Seer / Sage / Multi-SWE-bench 的部分数字指标来自检索摘要而非逐字阅读论文对应章节** —— 已在正文括注章节号，但**未逐字复核全部数字**。

## D. 本轮检索到的关键事实摘录（供正文引用，均已核实）

### D.1 "2025–2026 是否已有跨仓 / multi-repo issue 解决专门基准"—— **是**

| 成果 | 类型 | 关键量化结论 |
|---|---|---|
| **BeyondSWE**（arXiv:2603.03194，2026） | **有专门子集 CrossRepo** 的基准 | 500 实例 / 246 仓库；四类设定：CrossRepo（200 issues / 67 repos，平均 1.3 外部链接）、DomainFix、DepMigrate、Doc2Repo（50 例，最佳配置仅 2 个完全正确）。最佳 OpenHands 46.12；Codex + GPT-5.4(xhigh) 默认 48.48、SearchSWE 提示 56.65。目标解平均 10.9 文件 / 1039.6 行 |
| **CodeScaleBench**（Sourcegraph，2026-03） | **以跨仓任务为主**的基准套件 | 370 任务（SDLC 150 / Org 220）；Org 任务信息分布在 **3–20 个仓库**；MCP 检索使 P@10 0.095→0.313、R@10 0.120→0.272、F1@10 0.091→0.240；成本 −30.16%；配对 reward +0.0349（95% CI [+0.0130, +0.0579]） |
| **SWE-Explore**（arXiv:2606.07297，2026） | 定位/探索能力基准（单仓，但含 4 个学术定位 agent 作基线） | 848 issues / 10 语言 / 203 仓库；结论："当前 agent 找对文件已强，行级召回仍是瓶颈"；每实例 core regions 平均约 4.7 |
| **Multi-SWE-bench**（arXiv:2504.02605 / NeurIPS 2025） | 多语言（**非**多仓） | arXiv 版 1,632 实例 / 7 语言 / 39 仓；NeurIPS 版 2,132 实例 / 8 语言；修改文件数↑ → resolved rate↓；hard 级 resolved rate 接近 0；medium+hard 占比 77.1%（对比 SWE-bench Verified 61.2%） |

> **重要区分**：Multi-SWE-bench 的 "Multi-" 指**多语言**，**不是多仓**。真正的多仓基准是 BeyondSWE 的 CrossRepo 与 CodeScaleBench 的 Org。**不得混淆。**

### D.2 分布式根因定位三系统的关键对比

| 系统 | 核心算法 | 输入要求 | 量化结论 | 失效边界（论文自述） |
|---|---|---|---|---|
| **MicroRCA**（NOMS 2020） | attributed graph（service+host 节点，含共置边）→ 异常子图（以 response-time 边为检测目标、取起点为异常节点）→ Pearson 相关边权 → Personalized PageRank（c=0.15） | **无应用埋点**；需服务间 response time + 容器/宿主机资源利用率 | **precision 89%、MAP 97%**；优于基线 ≥13% precision / ≥15% MAP；对 MonitorRank+Microscope 平均 **+24% MAP** | 明确指出"以前后端相关性排序"的方法**无法定位对前端影响很小的故障服务** |
| **Seer**（ASPLOS'19） | DNN 学空间（服务依赖）+ 时间（负载/争用）模式；输入=每服务队列深度，输出=该服务引发 QoS 违规的概率；输入神经元按拓扑序排列 | **需侵入式埋点**拿队列深度；无埋点时降级为仅 NIC 队列 | **91% 预判正确**，**84% 彻底避免**；tracing 开销 **<0.1% 延迟 / <0.15% QPS**（未采样） | 仅 NIC 队列会**漏掉应用实现层 bug**（如微服务间 blocking） |
| **Sage**（ASPLOS'21） | **CBN**（RPC trace 上学依赖 + 服务→端到端因果 + 后端→前端 latency 传播）+ **GVAE 生成 counterfactual** | **无需标签**；只需**轻量 tracing**，不需应用改动或内核埋点；实现用 **Jaeger** + **Prometheus Node Exporter** | **>93% 准确率**（本地集群 91–95%）；GCE 188 容器（**6.7×**）时训练 **+19.4%** / 推理 **+26.5%**；transfer learning 重训快 **3–30×** | 对比中 CauseInfer 与 Microscope **常在依赖图上找错路径** |

### D.3 追踪 / 归因 / 评测类（替代失效条目）

| 成果 | 关键量化结论 |
|---|---|
| **TRAIL**（arXiv:2505.08638） | 148 条人工标注 trace / **1987 个 OTel span**（575 个含 ≥1 错误）/ **841 个标注错误** / 平均 5.68 错误每 trace；最佳 gemini-2.5-pro 仅 **11%**（joint accuracy：GAIA 18%、SWE-Bench 5%）；8 个模型中 3 个**无法处理完整上下文** |
| **FALAT**（arXiv:2606.00765） | 依赖引导搜索；最佳配置 **46.0%** step-level accuracy（算法生成轨迹）/ **29.1%**（手工轨迹） |
| **AgenTracer**（arXiv:2509.03312） | counterfactual replay + programmatic fault injection → TracerTraj-2.5K（2000+ 轨迹）；AgenTracer-8B（Qwen3-8B）比 Gemini-2.5-Pro / Claude-4-Sonnet 高至多 **18.18%**；给 MetaGPT / MaAS 带来 **4.8–14.2%** 增益 |
