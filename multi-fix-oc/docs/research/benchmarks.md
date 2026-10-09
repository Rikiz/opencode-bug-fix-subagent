# 基准数据集（截至 2026-10）

> 调研于 2026-10 完成。每条带 URL 的数据均在调研时直接读取原始来源；不确定项显式标注 **UNVERIFIED**。
> 方法论批判见 [practitioner-methodology.md](practitioner-methodology.md)。

## 1. SWE-bench 家族

| 名称 | 年份 | 任务 | 实例数 | 仓库数 | 关键指标 | 关键结论 |
| --- | --- | --- | --- | --- | --- | --- |
| **SWE-bench** | 2023/24 | issue → patch（Python） | 2,294 | 12 | % Resolved | 事实标准；约 45% 实例是 Django。Lite 榜单中位数仅 31.5%（2025-08 审计） |
| **SWE-bench Lite** | 2024 | 快速迭代子集 | 300 | 12 | % Resolved、File/Function Match | 多数定位类论文的实验集；79 个条目中位数 31.5%，最高 60.0% |
| **SWE-bench Verified** | 2024 | 人工确认可解子集 | 500 | 12 | % Resolved | 中位数 46.9%、最高 75.2%。**已污染**：不给代码只给 issue 文本，Claude 3.5/3.7 的"定位"准确率 76%/73%；在同规模非 SWE-bench Python 集上塌到 17–44%。Epoch AI 使用 484/500 |
| **SWE-bench Multimodal** | 2025 | 含截图的 issue | 612（dev 102 / test 510） | 17 | % Resolved | 462/510 测试实例的图片在 issue 文本中 |
| **SWE-bench Multilingual** | 2024/25 | 9 语言 | 300 | 42 | % Resolved | 各语言分榜基线显著低于 Python |
| **SWE-bench-Live** | 2025–26 | 自动滚动更新 | 1,319（Py）/ 1,077（多语言，2026-08） | 93 | % Resolved | 由 LLM "RepoLaunch" agent 自动生成可测容器。暴露静态基准掩盖的差距；2026-03 加入 Windows + PowerShell 分榜 |
| **SWE-bench Pro** | 2025 / ICML-26 | 长程、企业级、多语言 | 1,865（公开 11 仓 / held-out 12 / 商业 18） | 41，123 种语言 | Pass@1 | **最佳 Pass@1 = 43.6%（Sonnet 4.5）**，GPT-5 41.8%，Opus 4.1 仅 23%；商业集 <20%。161/500 个 Verified 实例只需改 1–2 行。平均 5.6+ 文件/实例。失败分类：上下文溢出 35.6%（Sonnet 4）、工具错误 42%（Qwen3-32B） |
| **SWE-bench++** | 2026 | 自动合成仓级任务 | 11,133（子集 1,782） | — | pass rate | 头部模型约 20%。细节 **UNVERIFIED** |

**"bash-only" 不是独立基准**——它是 Epoch AI 的脚手架变体（限制 agent 只能用 shell）。

## 2. 多语言与非 Python

| 名称 | 年份 | 实例 | 仓库 | 语言 | 关键结论 |
| --- | --- | --- | --- | --- | --- |
| **Multi-SWE-bench**（arXiv 2504.02605） | 2025 | 1,632（mini 400 / flash 300） | 39 | 7（+Py 参考） | 68 名专家标注、双标注 + 交叉评审；Agentless / SWE-agent / OpenHands 在 Python 之外显著退化。Multi-SWE-RL 另发布 4,723 条 RL 实例 |
| **SWE-PolyBench**（arXiv 2504.08703, AWS） | 2025 | 2,110（PB500 / PBv 382） | 21 | Java 165、JS 1017、TS 729、Py 199 | **引入 CST 节点级检索指标**。Python 20–24% pass，Java 11–16%，JS 6.5–12.6%，TS 5–13%。文件检索 ≠ 节点精度；高检索是必要但**不充分**条件 |
| **SWE-rebench**（arXiv 2505.20411, NeurIPS-25 D&B） | 2025 | 数据集 21,000+；可执行评测任务 294 | 169 | Python | 全自动流水线 + LLM-judge 质量审核（微调 Qwen2.5-72B）。DeepSeek-V3-0324 在 Verified 上 39.7%，在其自身 2025-03~04 去污染切片上仅 **21.3%**——污染的直接证据 |
| **SWE-rebench V2**（arXiv 2602.23866） | 2026 | 可执行 32,000+ / 含元数据 120,000+ | 3,600+ | 20 | 语言无关流水线 + 交互式环境构建 agent + LLM-judge 集成筛除不可靠实例 |
| **SWE-smith**（arXiv 2504.21798） | 2025 | 52k 任务、26k 轨迹 | 250+ 环境 | Python | 在任意仓库中合成 bug；SWE-agent-LM-32B 在 Verified 上 40.2%（较基线 +32%） |
| **R2E-Gym**（arXiv 2504.07164） | 2025 | 8,135（子集 4,578） | 10 | Python | SweGen：从 commit 反向翻译 + 生成测试。Pass@1 34.4%，混合验证器下 Best@26 达 51.0% |
| **SWE-Gym** | 2025 | 2,438（原始 66,894） | — | Python | 面向训练的可执行环境 |
| **Commit0**（arXiv 2412.01769） | 2024 | — | — | Python | 从零生成库（非 issue→patch），用作 RL 环境对照 |
| **SWE-Lancer** | 2025 | 1,400+ Upwork 真实接单任务 | — | JS/TS | 真实付费任务，含**管理类**任务 |
| Terminal-bench 2.0/2.1、ProgramBench、DeepSWE、CodeClash | 2026 | — | — | — | 被 SWE-sweep 引为当前前沿基准，均用 mini-SWE-agent 作脚手架。ID **UNVERIFIED** |

## 3. 传统 APR / FL 基准（至今仍是定位研究的地基）

| 名称 | 年份 | 实例 | 仓库 | 备注 |
| --- | --- | --- | --- | --- |
| **Defects4J** | 2014– | 854（+10 已弃用） | 22 Java | SBFL 研究金标准；多为 Java 6 时代字节码，早于 LLM 训练截止 → 污染风险 |
| **Defects4J-mf / BugsInPy-mf**（arXiv 2403.19171） | 2024 | — | 5 + 17 | **真正的多缺陷版本**：测试用例移植 + 故障位置平移。平均 **Defects4J 每版本 9.2 个缺陷、BugsInPy 每版本 18.6 个** |
| **BugsInPy** | 2018 | ~800 | 17 Python | 原始单缺陷 Python 语料 |
| **Bugs.jar / Bears** | 2018/19 | — | 26 / 40 | 已知复现问题（依赖缺失、配置不全） |
| **BugSwarm** | 2019 | 998 | 16 | Durieux & Abreu 2019：**96.4% 不适用于** APR/FL |
| **GitBug-Java**（arXiv 2402.02961） | 2024 | 199 | 55 | 2023 年 commit（截止后），经 GitBug-Actions 完全离线可复现 |
| CodeRepair | 2017 | — | — | BenchRepair 谱系，5 个 Python 项目。实例数 **UNVERIFIED** |
| SWE-bench-java | — | — | — | **UNVERIFIED**——未找到规范一手来源，谨慎对待 |
| RepoBench / DevBench / FeatBench | 2023–24 | — | — | 仓级**补全** / 软件开发基准，非 issue→patch。细节 **UNVERIFIED** |

## 4. 定位专用与 2025–26 评测基准（与本项目最相关）

| 名称 | 年份 | 任务 | 实例 / 仓库 | 关键数字 |
| --- | --- | --- | --- | --- |
| **Loc-Bench**（LocAgent 配套，ACL-25） | 2025 | 仅定位 | 近期 Python、截止后、可更新 | 修正 SWE-bench 的 85% bug-report 偏斜（feature 仅 14%、security 1%、performance **0%**） |
| **MULocBench**（arXiv 2509.25242） | 2025 | 定位**代码 + 非代码**构件（commit、注释、配置、文档） | 1,100 / 46 Python | **所有 SOTA 与 5 种 LLM prompting 策略的 file-level Acc@5 与 F1 仍 < 40%** |
| **GREPO**（arXiv 2602.13921） | 2026 | 仓级 bug 定位作为可学习 GNN 任务 | 47,294 / 86 Python | 首个提供现成异构、带时间索引仓图的基准。所有 GNN（GAT/GATv2 > GCN/GIN/SAGE）优于 IR/LLM 基线 |
| **Precise Debugging Benchmark**（arXiv 2604.17338） | 2026 | **精度感知**调试：PDB-Single + PDB-Wild | 5,751 + 484 | 前沿模型**单测通过率 >76%，但编辑级精度 ≤45%**，且排名与单测分数**倒挂**。迭代式/agent 式策略无法改善 |
| **ChainSWE**（arXiv 2607.02606） | 2026 | 单次 rollout 内连续依赖缺陷链，不重置仓库 | 304 实例 / 100 链 / 54 Python | 相比孤立处理**最多退化 70%**，链深处最严重。携带原始历史≈无用；摘要与子 agent 编辑**反而更差** |
| **Active-SWE**（arXiv 2608.04682） | 2026 | **无问题单**的主动修复，多个 bug | 1,663 / 8 语言 / 6 类 bug | 最佳解决率 **20.0%**。定位越强解决率越高。生成测试的"数量"与"有效性"错位——测试多 ≠ 有效测试多 |
| **SWE-sweep** | 2026 | 无规格说明，自主**发现并修复**并发 bug | 4,068 / 100 仓 / 22 语言 | 最佳 agent（GPT-5.6 Sol xhigh）仅解决 **4.7%**。瓶颈在发现而非修复。bug <25 的仓 14.9%，≥75 的仓仅 2.2% |
| **OpenRCA**（ICLR 2025） | 2025 | 从 68 GB 遥测（日志/指标/链路）定位根因 | 335 次故障 / 3 个企业系统 | Claude 3.5：oracle 遥测 5.37%，均衡采样 3.88%，**RCA-agent 11.34%** |
| **CodeScaleBench**（Sourcegraph） | 2026 | SDLC 任务 + **跨仓/跨组织**发现 | 370（150 SDLC + 220 org，每个跨 3–20 仓） | MCP 带来 reward +0.0349（org +0.0339）；检索 P@10 0.095→0.313，R@10 0.120→0.272，F1@10 0.091→0.240；成本 −30.2% |
| **BeyondSWE / SearchSWE**（arXiv 2603.03194） | 2026 | 跨仓、跨领域、依赖迁移、文档→仓 | 500 / 246 仓 | 最佳 OpenHands agent 平均 46.12；Codex+GPT-5.4(xhigh) 56.65。详见 [multi-repo-and-microservices.md](multi-repo-and-microservices.md) |
| **Open-SWE-Traces** | 2026 | 207,489 条 agentic 轨迹 / 9 语言 | — | Qwen3-30B-A3B SFT：Verified 61.7%、Multilingual 57.1%、Pro 36.8%。arXiv ID **UNVERIFIED** |
| **BeetleBox**（Chakraborty et al. 2025） | 2025 | 跨语言 issue 定位/修复 | 5 个 Python 仓 | 污染研究中的非污染对照组。arXiv ID **UNVERIFIED** |

## 5. 从基准里读出的对本项目的结论

1. **公开分数不能当线上成功率。** Verified 中位数 46.9%、最高 75.2%，而 SWE-bench Pro 最佳 Pass@1 仅 43.6%、商业集 <20%。企业级长程任务的真实难度远高于榜单显示。
2. **必须同时报定位精度，不能只报单测通过率。** PDB 显示 >76% 单测通过伴随 ≤45% 编辑精度，且**排名倒挂**——按单测分数选系统会选错。
3. **固定基准已失效。** Verified 只给 issue 文本就有 76% 定位准确率；SWE-rebench 上同一模型 39.7% vs 去污染切片 21.3%。评测集必须新鲜、必须自建。
4. **"高检索 = 能修好"是错的。** SWE-PolyBench 明确指出文件检索与节点精度是两件事，高检索只是必要条件。定位到了不等于改得对。
5. **发现比修复难得多。** SWE-sweep 4.7%、Active-SWE 20.0%——几乎所有投入都在"修已知 bug"，"在仓里找一个未知缺陷"仍是未解核心。多仓场景下"这个 bug 属于哪个仓"就是一个发现问题，应按发现问题而非修复问题来对待。
6. **多缺陷会摧毁 agent 状态。** ChainSWE 的 70% 退化与"摘要/子 agent 编辑反而更差"直接决定了本项目的设计：每个仓库一个全新子会话，不共享累积历史。
7. **非代码构件是合法定位目标。** MULocBench 把 commit、注释、配置、文档纳入定位范围仍 <40%——这支持本项目把契约配置（`topology.json` 的 `provides`/`consumes`/`contracts`）当作一等证据源。

## 6. 来源

**SWE-bench 家族**：https://www.swebench.com/ · https://www.swebench.com/SWE-bench/faq/ · https://huggingface.co/datasets/SWE-bench/SWE-bench_Multimodal · https://openai.com/index/introducing-swe-bench-verified/ · https://arxiv.org/abs/2512.10218（Verified 是否测能力还是记忆）· https://arxiv.org/abs/2506.17208（解剖 SWE-bench 榜单）· https://epoch.ai/benchmarks/swe-bench-verified · https://arxiv.org/abs/2509.16941（SWE-bench Pro）· https://proceedings.mlr.press/v306/deng26f.html · https://arxiv.org/abs/2504.08703（SWE-PolyBench）· https://github.com/amazon-science/SWE-PolyBench · https://arxiv.org/abs/2505.20411（SWE-rebench）· https://arxiv.org/abs/2602.23866（rebench V2）· https://github.com/microsoft/SWE-bench-Live

**多语言**：https://arxiv.org/abs/2504.02605（Multi-SWE-bench）· https://multi-swe-bench.github.io/ · https://github.com/SWE-bench/SWE-smith · https://arxiv.org/abs/2504.07164（R2E-Gym）· https://r2e-gym.github.io · https://arxiv.org/abs/2412.01769（Commit0）

**传统基准**：https://github.com/rjust/defects4j · https://arxiv.org/abs/2403.19171（Defects4J-mf / BugsInPy-mf）· https://arxiv.org/abs/2402.02961（GitBug-Java）· https://github.com/gitbugactions/gitbug-java

**定位基准与方法**：https://arxiv.org/abs/2503.09089（LocAgent）· https://aclanthology.org/2025.acl-long.426/ · https://github.com/gersteinlab/LocAgent · https://arxiv.org/abs/2509.25242（MULocBench）· https://arxiv.org/abs/2602.13921（GREPO）· https://arxiv.org/abs/2604.17338（PDB）· https://arxiv.org/abs/2607.02606（ChainSWE）· https://arxiv.org/abs/2608.04682（Active-SWE）· https://swesweep.com/paper · https://proceedings.iclr.cc/paper_files/paper/2025/file/d29b8d53678015079e1d245c023e49d2-Paper-Conference.pdf（OpenRCA）· https://github.com/sourcegraph/CodeScaleBench/blob/public/docs/technical_reports/TECHNICAL_REPORT.md · https://arxiv.org/abs/2603.03194（BeyondSWE）· https://arxiv.org/abs/2604.03515（编码 agent 架构分类法）

**未验证项**：SWE-bench-java、RepoBench/DevBench/FeatBench 细节、CodeRepair 实例数、BeetleBox 与 Open-SWE-Traces 的 arXiv ID、SWE-bench++/Terminal-bench/ProgramBench/DeepSWE/CodeClash/ScaleSWE/Ambig-SWE/SWE-together 的 arXiv ID（这些仅作为其他论文的引文出现）。