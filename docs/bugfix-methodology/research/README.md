# 离线原文索引（bugfix-methodology）

> 覆盖范围：bug fixing 全流程的最新研究进展、可用方法论与工业实践。
> 本索引由三批下载合并而成，全部文件落盘在本目录（共 342 份，已按 sha256 校验零重复）：
> - **批次 1（2026-10-08）**：调试理论/故障定位/APR/测试/评测/Agent 工程 6 层共 30 份原文。
> - **批次 2（2026-10-10）**：新增业界最新进展（2026-06 → 2026-10 为主）、方法论综述与工业实践共 257 份原文。
> - **批次 3（2026-10-10，二次检索）**：在批次 2 之后用 OpenAlex 全库 + arXiv API 再次检索并增量补齐 **52 份**最新原文（2026-06 → 2026-10），见第 23 节；另有 10 份经 sha256 判定与批次 2 内容完全相同、4 份同 ID 已存在，按去重纪律未重复入库。
>
> 校验方法：逐文件 `file(1)` 识别类型 → `sha256` 取前 12 位 → `pypdf` 抽取首页文本/页数 →
> 与 `arxiv.org/abs/<id>` 的官方标题做词元重叠比对（阈值 0.6；HTML 用 `<title>`+正文，阈值 0.35）。
> 落盘纪律：**任何未通过校验的文件一律删除**，只把通过校验的原文留在目录中；失败的记入第 20 节。
> 去重纪律：文件名、arXiv ID、内容 sha256 三重去重；与 `../../multi-repo-bugfix/research/` 交叉去重，重复内容不再下载。
> 安全边界：仅执行只读网络 GET（`curl -fsSL`），未安装依赖、未改动工作区其他文件。

---

## 0. 方法论地图：bugfix 的十大家族

> 本目录不是「论文堆」，而是一张**方法论地图**。下表把 bugfix 全流程拆成十个家族，说明每个家族解决的问题、可用的方法与代表原文。文件名对应第 1–10 节的分族清单。

| # | 家族 | 解决什么问题 | 核心方法论 | 何时使用 |
|---|---|---|---|---|
| **A** | 调试理论与过程 | 「为什么坏了」——如何系统地提问，而不是靠猜 | 科学调试（假设–实验–结论循环）、delta debugging / ddmin 自动缩小失败输入、扎根理论（grounded theory）刻画真实开发者的调试行为 | 缺陷成因未知、可复现但输入庞大、需要可审计的推理链 |
| **B** | 故障定位（FL） | 「坏在哪里」——把搜索空间从整个仓库缩到函数/行/切片 | 基于频谱的定位（SBFL：Tarantula/Ochiai/DStar）、程序切片、执行特征（数据流/值/分支）增强、LLM 与 agentic 定位、测试驱动定位、多模态（截图/UI）定位、验证失败定位 | 已有失败测试或崩溃报告；定位质量直接决定后续修复上限 |
| **C** | 生产系统根因分析（RCA） | 「线上为什么坏了」——跨服务、跨遥测 | 证据抽取与推理解耦、图增强（服务依赖图）推理、轨迹级评估与故障传播分析、可观测性驱动修复闭环、大规模 RCA 平台化、RCA 失败的检索/重排分解 | 微服务/云/内核等分布式或长链路系统；单点 FL 不足以解释级联故障 |
| **D** | 自动程序修复（APR）范式 | 「怎么改」——从缺陷到补丁 | 遗传编程搜索、模板/条件合成、学习式（神经）修复、LLM 生成–验证、检索增强与修复成分复用、多候选融合、生成后精炼、多 hunk 协同、经验记忆编排、RL 训练 | 有明确失败信号（测试/报告）；需要批量、可规模化的修复产出 |
| **E** | Agent 化修复与 Harness 工程 | 「怎么让 agent 可靠地完成一次修复」 | 单 agent / 多 agent / workflow 编排、上下文工程与语义记忆、验证–修复循环与**停止准则**、结构化反馈与外部验证器、harness 作为运行时底座、模型–harness 边界缺陷分类、轨迹复用 | 修复需要多轮工具交互、跨文件探索、长时程决策 |
| **F** | 测试与验证方法论 | 「改对了吗」——如何获得可信的正确性信号 | 回归测试选择、缺陷复现测试生成、测试预言（oracle）构造、属性测试、差分测试、蜕变测试、变异测试、模糊测试、补丁正确性评估、不稳定（flaky）测试修复 | 任何修复都必须回答的问题；也是「假通过」的主要来源 |
| **G** | 安全缺陷修复 | 「改得安全吗」——漏洞修复有其特有失效模式 | 自动漏洞修复（AVR）SoK、成对漏洞/功能预言机、基准可靠性审计、多补丁与修复完整性、形式化验证辅助、内存安全 | 修复涉及 CWE、漏洞披露流程、可能被绕过或引入回归 |
| **H** | 评测与元评估 | 「这个结论可信吗」——如何不欺骗自己 | 基准构建与验证、污染/记忆化探测、测试过拟合检测、未获通过的 pass 审计、排行榜饱和分析、实验设置元研究、失败模式与轨迹分类法 | 比较方法、发布结论、决定是否上线某个 agent |
| **I** | 工业实践与交付方法论 | 「在真实组织里怎么落地」 | 事故响应与无责事后复盘、DORA 交付指标、变更风险评分、灰度/回滚/特性开关/混沌工程、AI 代码审查与自动修复产品化、缺陷分类法（ODC）、标准（NIST SSDF / CWE Top 25） | 需要把单点修复能力变成组织级流程与门禁 |
| **J** | 大规模调试基础设施 | 「靠什么工具看见并重现」 | eBPF 追踪、连续 profiling、sanitizer、record–replay 与时间旅行调试、确定性仿真与回放 | 缺陷只在生产、只在特定调度/时序下出现；需要可重现证据 |

### 0.1 选择指南（决策表）

| 症状 | 首选家族 | 组合建议 |
|---|---|---|
| 有失败测试，改动范围小 | B → D | SBFL/执行特征定位 → LLM 生成–验证修复 → F 的回归+变异验证 |
| 有 GitHub issue，仓库级 | E → D | agent 探索定位 → 补丁生成 → 复现测试生成（F）→ 独立补丁验证（H） |
| 线上告警，跨服务 | C → D | 遥测证据抽取 → 图/轨迹根因 → 可观测性驱动修复 → 灰度回滚（I） |
| 漏洞（CVE/CWE） | G | AVR → 成对预言机 → 基准可靠性审计 → SSDF/CWE 门禁（I） |
| 修复「通过了测试但没修对」 | H → F | 测试过拟合检测 → 独立重建验证 → 补丁正确性评估 |
| 反复修不好 / 循环不收敛 | E | 停止准则研究 → 结构化反馈与外部验证器 → 多候选融合 |
| 只在生产偶发 | J | eBPF/连续 profiling → record–replay → 确定性仿真 → A 的 ddmin |

### 0.2 六条跨家族工程纪律（本目录反复出现、可直接执行的结论）

1. **定位与修复要解耦评估**：把 FL 上下文当作自变量做对照实验，否则无法判断收益来自定位还是来自模型。
2. **验证信号必须可信**：LLM 生成的测试、以及「测试通过」本身都会说谎；要用独立重建验证 + 变异/蜕变测试交叉检查。
3. **循环要有停止准则**：多轮验证–修复在噪声下会损伤正确计划，"再修一次"不是免费的。
4. **补丁正确性 ≠ 测试通过**：评估需同时覆盖正确性、简洁性、设计约束与安全属性。
5. **经验要结构化复用**：把历史修复轨迹抽象为可复用计划/记忆，比重新探索更省 token 且更稳定。
6. **基准会被污染、排行榜会饱和**：任何跨模型比较都必须先审计记忆化与未获通过的 pass。

---

## 1–18. 分族原文清单

> 「校验」列为 `ov=`（标题词元重叠率）与页数；全部条目均已通过 `file`+`pypdf`+标题比对。

### 1. 综述、分类法与田野研究

（9 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `classic-dynamic-slicing-complexity-2011.pdf` | On the computational complexity of dynamic slicing problems for program schemas | https://arxiv.org/pdf/1705.07686 | 274,946 | 27189976a341 | 26 | ov=1.0 |
| `classic-git-bisect-analysis-2023.pdf` | Theoretical analysis of git bisect | https://arxiv.org/pdf/2312.13644 | 753,834 | 0b637368f6f4 | 39 | ov=1.0 |
| `classic-probdd-2025.pdf` | Toward a Better Understanding of Probabilistic Delta Debugging | https://arxiv.org/pdf/2408.04735 | 595,629 | 0b60e4968f60 | 12 | ov=1.0 |
| `classic-tip-slicing-survey-1994.pdf` | A Survey of Program Slicing Techniques | https://ir.cwi.nl/pub/5120/5120D.pdf | 604,578 | 02a55f70b747 | 60 | ov=1.0 |
| `classic-wdd-weighted-delta-debugging-2025.pdf` | WDD: Weighted Delta Debugging | https://arxiv.org/pdf/2411.19410 | 748,409 | 92a2c92aedc6 | 12 | ov=1.0 |
| `classic-whyline-chi2004.pdf` | Designing the Whyline: A Debugging Interface for Asking Questions about Program Behavior | http://www.cs.cmu.edu/~NatProg/papers/Ko2004Whyline.pdf | 870,087 | 107cf82cda44 | 8 | ov=1.0 |
| `classic-whyline-icse2008.pdf` | Debugging Reinvented: Asking and Answering Why and Why Not Questions about Program Behavior | http://www.cs.cmu.edu/~NatProg/papers/Ko2008JavaWhyline.pdf | 876,158 | 55998b2699e3 | 10 | ov=1.0 |
| `survey-llm-issue-resolution.pdf` | Advances and Frontiers of LLM-based Issue Resolution in Software Engineering: A Comprehensive Survey | https://arxiv.org/pdf/2601.11655 | 3,509,933 | 5804c97553e2 | 26 | html-ok |
| `survey-llm4apr-slr-tosem.pdf` | A Systematic Literature Review on Large Language Models for Automated Program Repair | https://arxiv.org/pdf/2405.01466 | 1,348,343 | d675f79ec135 | 56 | html-ok |

### 2. 故障定位（FL）

（31 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `a-goal-driven-survey-on-root-cause-analysis.pdf` | A Goal-Driven Survey on Root Cause Analysis | https://arxiv.org/pdf/2510.19593 | 5,333,299 | f344800de327 | 55 | ov=1.0 |
| `a-grounded-theory-of-debugging-in-professional-software-engineering.pdf` | A Grounded Theory of Debugging in Professional Software Engineering Practice | https://arxiv.org/pdf/2602.11435 | 911,582 | 4b3ba562ae43 | 22 | ov=1.0 |
| `agentic-software-issue-resolution-with-large-language-models-a.pdf` | Agentic Software Issue Resolution with Large Language Models: A Survey | https://arxiv.org/pdf/2512.22256 | 2,715,250 | 038835f8add1 | 50 | ov=1.0 |
| `arxiv-2604.00167.pdf` | A Study on the Impact of Fault localization Granularity for Repository-Scale Code Repair Tasks | https://arxiv.org/pdf/2604.00167 | 1,843,195 | 82a1aad7aa99 | 30 | ov=1.0 |
| `arxiv-2604.05481.pdf` | On the Role of Fault Localization Context for LLM-Based Program Repair | https://arxiv.org/pdf/2604.05481 | 757,089 | 445db7666c93 | 30 | ov=1.0 |
| `arxiv-2606.30963.pdf` | Loc2Repair: A Framework for Evaluating the Impact of File-Level Issue Localization in Repo-Level LLM Repair | https://arxiv.org/pdf/2606.30963 | 766,085 | 529f17a2e3e8 | 10 | ov=1.0 |
| `arxiv-2607.09553.pdf` | Writing Bug Reports for Software Repair Agents: What Information Matters Most? | https://arxiv.org/pdf/2607.09553 | 238,190 | 8bebd6d1a0e7 | 13 | ov=1.0 |
| `arxiv-2607.11046.pdf` | Retrieval-Oriented Code Representations in Agentic Bug Localization | https://arxiv.org/pdf/2607.11046 | 1,648,494 | 1d03ac6b42e6 | 34 | ov=1.0 |
| `arxiv-2607.17286.pdf` | IssueExec: A Test-Driven Approach for Localizing Software Engineering Issues | https://arxiv.org/pdf/2607.17286 | 1,914,613 | 401b87301d05 | 22 | ov=1.0 |
| `arxiv-2607.25873.pdf` | How Do LLMs Read Bug Reports? An Empirical Study of Attention in LLMs for Automated Program Repair | https://arxiv.org/pdf/2607.25873 | 3,240,054 | 5be8e3e3e4db | 14 | ov=1.0 |
| `bug-report-driven-fault-localization-industrial-benchmarking-and-lesson.pdf` | Bug-Report-Driven Fault Localization: Industrial Benchmarking and Lesson Learned at ABB Robotics | https://arxiv.org/pdf/2604.25700 | 638,662 | 10c843280a18 | 9 | ov=0.909 |
| `characterizing-faults-in-agentic-ai-a-taxonomy-of-types.pdf` | Characterizing Faults in Agentic AI: A Taxonomy of Types, Symptoms, and Root Causes | https://arxiv.org/pdf/2603.06847 | 4,109,753 | afef4a1c9099 | 32 | ov=1.0 |
| `classic-abreu-sbfl-accuracy-2007.pdf` | On the Accuracy of Spectrum-based Fault Localization | https://repositorium.uminho.pt/bitstreams/d681099f-2895-46a0-aee3-acb7bb0246e5/download | 262,954 | 3f30ff357f5f | 10 | ov=0.8 |
| `classic-agentfl-2024.pdf` | AgentFL: Scaling LLM-based Fault Localization to Project-Level Context | https://arxiv.org/pdf/2403.16362 | 662,660 | 98ed9b5f40be | 12 | ov=0.889 |
| `classic-deepfl-issta2019.pdf` | DeepFL: Integrating Multiple Fault Diagnosis Dimensions for Deep Fault Localization | https://par.nsf.gov/servlets/purl/10111196 | 1,316,818 | c3c9bc6c55be | 12 | ov=1.0 |
| `classic-fluccs-issta2017.pdf` | FLUCCS: Using Code and Change Metrics to Improve Fault Localisation | https://coinse.github.io/publications/pdfs/Sohn2017xq.pdf | 252,013 | 69e3cff84951 | 11 | ov=1.0 |
| `classic-multiagent-fl-graph-2024.pdf` | A Multi-Agent Approach to Fault Localization via Graph-Based Retrieval and Reflexion | https://arxiv.org/pdf/2409.13642 | 878,768 | e7f47333bb22 | 12 | ov=1.0 |
| `classic-predfl-ase2019.pdf` | Combining Spectrum-Based Fault Localization and Statistical Debugging: An Empirical Study | https://xgdsmileboy.github.io/files/paper/predfl-ase19.pdf | 763,812 | 2a460d93ee5d | 13 | ov=1.0 |
| `classic-sbfl-challenges-2022.pdf` | A Survey of Challenges in Spectrum-Based Software Fault Localization | https://publicatio.bibl.u-szeged.hu/39015/1/A_Survey_of_Challenges_in_Spectrum-Based_Software_Fault_Localization-1.pdf | 4,076,056 | 8c46bc4f063b | 22 | ov=1.0 |
| `classic-sbfl-multifault-ijcai2023.pdf` | Augmenting Automated Spectrum Based Fault Localization for Multiple Faults | https://www.ijcai.org/proceedings/2023/0350.pdf | 353,436 | 0678e5f1e322 | 9 | ov=1.0 |
| `classic-sbfl-without-oracles-2010.pdf` | Spectrum-Based Fault Localization without Test Oracles | https://www.utdallas.edu/~ewong/documents/UTD-CS-TR-2010-02-12.pdf | 279,057 | 58e7f341cd8a | 19 | ov=1.0 |
| `classic-transfer-icse2021.pdf` | Fault Localization with Code Coverage Representation Learning | https://arxiv.org/pdf/2103.00270 | 1,359,686 | 1dcf86d9d012 | 13 | ov=1.0 |
| `classic-variable-fl-tosem2023.pdf` | Variable-based Fault Localization via Enhanced Decision Tree | https://xgdsmileboy.github.io/files/paper/tosem23-localization.pdf | 1,904,047 | 40c1a6a0c8f2 | 32 | ov=1.0 |
| `classic-wong-fl-survey-2009.pdf` | A Survey of Software Fault Localization | https://personal.utdallas.edu/~ewong/documents/fault-localization-survey.pdf | 169,187 | 8d8f79e4d9b6 | 19 | ov=1.0 |
| `cloud-opsbench-a-reproducible-benchmark-for-agentic-root-cause.pdf` | Cloud-OpsBench: A Reproducible Benchmark for Agentic Root Cause Analysis in Cloud Systems | https://arxiv.org/pdf/2603.00468 | 1,228,916 | a66b038cdef7 | 14 | ov=1.0 |
| `dafny-automated-fault-localization.pdf` | Improving Debugging in Verification-Aware Languages Through Automated Fault Localization: A Case Study in Dafny | https://arxiv.org/pdf/2608.05399 | 327,275 | 2d64b88bd981 | 12 | ov=1.0 |
| `execution-features-statistical-fl.pdf` | How do Execution Features Improve Statistical Fault Localization? An Empirical Study | https://arxiv.org/pdf/2606.30324 | 274,164 | f98e4907c8f0 | 7 | ov=1.0 |
| `fault-localization-vs-fresh-attempt-placebo.pdf` | Does Fault Localization Beat a Fresh Attempt? A Placebo-Controlled Study of Test-Guided Code Repair | https://arxiv.org/pdf/2609.00854 | 301,158 | d68bfd905b84 | 14 | ov=1.0 |
| `linux-kernel-fault-localization.pdf` | Towards Better Linux Kernel Fault Localization: Leveraging Contrastive Reasoning and Hierarchical Context Analysis | https://arxiv.org/pdf/2607.00562 | 905,785 | f3ee81a6b8a3 | 13 | ov=1.0 |
| `test-driven-approaches-to-software-engineering-with-large-language.pdf` | Test-Driven Approaches to Software Engineering with Large Language Models: A Survey of Phases, Tasks, and Agent Skills | https://arxiv.org/pdf/2609.12012 | 239,576 | 2bea79c56c87 | 19 | ov=1.0 |
| `where-root-cause-analysis-fails-a-retrieval-reranking-decomposition.pdf` | Where Root Cause Analysis Fails: A Retrieval-Reranking Decomposition | https://arxiv.org/pdf/2609.36686 | 659,472 | 2269ec700254 | 35 | ov=1.0 |

### 3. 生产系统根因分析（RCA）

（11 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `evirca-microservice-rca.pdf` | EviRCA: Decoupling Evidence Extraction from Reasoning for Microservice Root-Cause Analysis | https://arxiv.org/pdf/2609.19825 | 569,290 | ae9600133948 | 12 | html-ok |
| `gala-graph-rca-incident-response.pdf` | GALA: Graph-Augmented LLM Agents for Root Cause Analysis and Incident Response in Microservices | https://arxiv.org/pdf/2608.08968 | 1,010,597 | 44362b19091d | 13 | ov=1.0 |
| `graph-structure-microservice-rca-controlled.pdf` | Does Graph Structure Earn Its Place in Microservice Root-Cause Analysis? A Controlled Study on RCAEval, and What the Benchmark Was Really Measuring | https://arxiv.org/pdf/2609.27069 | 474,775 | 6ce09ccf1b78 | 17 | ov=1.0 |
| `holmes-mobile-crash-diagnosis.pdf` | Holmes: Multimodal Agentic Diagnosis for Mixed-Language Mobile Crashes at Industrial Scale | https://arxiv.org/pdf/2606.21963 | 879,128 | c4707cf34e63 | 9 | ov=1.0 |
| `kerneldiag-kernel-crash-rca.pdf` | KernelDiag: Agent-Based Root Cause Diagnosis for Kernel Crashes | https://arxiv.org/pdf/2607.17722 | 479,523 | 76c18fa4f113 | 15 | ov=1.0 |
| `krca-hyper-scale-microservice-rca.pdf` | KRCA: An Efficient Root Cause Analysis System in Hyper-scale Microservice Systems via Agentic AI | https://arxiv.org/pdf/2607.01788 | 2,980,663 | 17bfe0bdf97a | 12 | ov=1.0 |
| `longrca-bench.pdf` | LongRCA Bench: Root-Cause Localization in Long-Horizon Agent Trajectories | https://arxiv.org/pdf/2608.15242 | 1,716,171 | 674413ee4635 | 35 | ov=1.0 |
| `orca-observability-grounded-repair.pdf` | ORCA: Observability-Grounded Program Repair for Microservice Incidents | https://arxiv.org/pdf/2608.17018 | 691,637 | 881ad65ecdf1 | 12 | ov=1.0 |
| `root-cause-attribution-continual-search.pdf` | Root-Cause Attribution Is a Search Problem: Continual Search for Long-Horizon Agent Failures | https://arxiv.org/pdf/2609.13463 | 624,917 | 73195b71aa60 | 31 | ov=1.0 |
| `self-evolving-harness-rca.pdf` | From General Agents to RCA Experts: A Self-Evolving Harness for Root Cause Analysis | https://arxiv.org/pdf/2608.25661 | 6,940,012 | 29186cfb8926 | 12 | ov=1.0 |
| `trajectory-level-microservice-rca.pdf` | Beyond Fault Localization: A Trajectory-Level Study of LLM Agents for Microservice Root Cause Analysis | https://arxiv.org/pdf/2608.21310 | 1,168,999 | 66b7341c713f | 13 | ov=1.0 |

### 4. 自动程序修复（APR）范式

（26 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `a-metamorphic-testing-approach-to-diagnosing-memorization-in-llm.pdf` | A Metamorphic Testing Approach to Diagnosing Memorization in LLM-Based Program Repair | https://arxiv.org/pdf/2604.21579 | 632,293 | ddc4fb5f849c | 15 | ov=1.0 |
| `a-systematic-study-of-llm-based-architectures-for-automated.pdf` | A Systematic Study of LLM-Based Architectures for Automated Patching | https://arxiv.org/pdf/2603.01257 | 2,234,644 | bd7e56fb431b | 14 | ov=1.0 |
| `adarepair-mem-experience-orchestration.pdf` | AdaRepair-Mem: Adaptive Experience Orchestration for Repository-Level Program Repair | https://arxiv.org/pdf/2609.20130 | 6,789,951 | e5173ef90706 | 12 | ov=1.0 |
| `apr-bug-complexity-fl-cost.pdf` | Rethinking Automated Program Repair: The Impact of Bug Complexity, Fault Localization, and LLM Cost-efficiency | https://arxiv.org/pdf/2608.14065 | 2,441,578 | a34bf2df9191 | 20 | ov=1.0 |
| `arxiv-2603.01048.pdf` | RepoRepair: Leveraging Code Documentation for Repository-Level Automated Program Repair | https://arxiv.org/pdf/2603.01048 | 3,845,960 | 9b5ed0205895 | 27 | ov=1.0 |
| `arxiv-2603.22048.pdf` | Dynamic analysis enhances issue resolution | https://arxiv.org/pdf/2603.22048 | 12,196,636 | d6b9ae353d76 | 11 | html-ok |
| `arxiv-2604.03610.pdf` | DebugHarness: Emulating Human Dynamic Debugging for Autonomous Program Repair | https://arxiv.org/pdf/2604.03610 | 3,098,246 | f9aff2b936ae | 15 | ov=1.0 |
| `arxiv-2604.24212.pdf` | Empowering Autonomous Debugging Agents with Efficient Dynamic Analysis | https://arxiv.org/pdf/2604.24212 | 2,272,386 | 06142ac31471 | 22 | ov=1.0 |
| `arxiv-2605.09134.pdf` | BoostAPR: Boosting Automated Program Repair via Execution-Grounded Reinforcement Learning with Dual Reward Models | https://arxiv.org/pdf/2605.09134 | 2,218,653 | 545b581f5835 | 21 | ov=1.0 |
| `arxiv-2606.17612.pdf` | PracRepair: LLM-Empowered Automated Program Repair Inspired by Human-Like Debugging Practices | https://arxiv.org/pdf/2606.17612 | 3,012,236 | 1ded52687c35 | 12 | ov=1.0 |
| `arxiv-2607.01597.pdf` | A Single Patch Is Not Enough: Deterministic Fusion of Repair Candidates | https://arxiv.org/pdf/2607.01597 | 504,300 | 754e140fdd9f | 12 | ov=1.0 |
| `arxiv-2607.12605.pdf` | Multi-Perspective Agentic Program Repair via Code Property Graphs and Temporal Execution Graphs | https://arxiv.org/pdf/2607.12605 | 7,132,430 | e5b3362e46e8 | 12 | ov=1.0 |
| `arxiv-2607.26591.pdf` | MultiFixer: A Coordinator-Proposer Based Multi-Agent Framework For Fixing Multi-Hunk Bugs | https://arxiv.org/pdf/2607.26591 | 1,058,889 | 90d4eab7d4de | 13 | ov=0.909 |
| `asad-adaptive-software-agents-debugging.pdf` | ASAD: Adaptive Software Agents for Debugging | https://arxiv.org/pdf/2610.00629 | 609,415 | b472c3e5f1bf | 15 | ov=1.0 |
| `hallucination-llm-apr.pdf` | Better Understanding, Better Fixes? A Study of Hallucination in LLM-based Automated Program Repair | https://arxiv.org/pdf/2609.04909 | 4,933,255 | 6e6331fa0bbf | 51 | ov=1.0 |
| `hej-robust-a-robustness-benchmark-for-llm-based-automated.pdf` | HEJ-Robust: A Robustness Benchmark for LLM-Based Automated Program Repair | https://arxiv.org/pdf/2605.02215 | 468,025 | 74d02c09de6a | 5 | ov=1.0 |
| `independent-patch-verification-for-coding-agents-with-a-bidirectional.pdf` | Independent Patch Verification for Coding Agents with a Bidirectional Reconstruct-and-Verify Framework | https://arxiv.org/pdf/2608.08950 | 1,519,290 | 1d3ec91e3320 | 8 | ov=1.0 |
| `iterative-bugfixing-dynamics.pdf` | If It&#39;s Not Buggy, Don&#39;t Fix It: On the Dynamics of Iterative Bug-fixing with LLMs | https://arxiv.org/pdf/2609.10123 | 1,002,859 | 814a945bae2e | 20 | ov=1.0 |
| `large-language-models-for-programming-actually-fixing-or-reimplementing.pdf` | Large Language Models for Programming: Actually Fixing or Reimplementing Incorrect Code? | https://arxiv.org/pdf/2609.29410 | 291,851 | c262d029dcff | 7 | ov=1.0 |
| `precise-debugging-benchmark-is-your-model-debugging-or-regenerating.pdf` | Precise Debugging Benchmark: Is Your Model Debugging or Regenerating? | https://arxiv.org/pdf/2604.17338 | 3,319,512 | 32f0940dd1dc | 46 | ov=1.0 |
| `refine-after-generation-patch-verbosity.pdf` | Refine After Generation: Toward Correct and Concise Patches in LLM-based Program Repair | https://arxiv.org/pdf/2608.13292 | 765,404 | e57c8f263dde | 13 | ov=1.0 |
| `repair-loop-iteration-limits.pdf` | Is Three the Magic Number? An Empirical Evaluation of LLM-Based Repair Loops | https://arxiv.org/pdf/2607.05197 | 520,580 | b79dadb4c907 | 5 | ov=1.0 |
| `rgfl-reasoning-guided-fault-localization-for-automated-program-repair.pdf` | RGFL: Reasoning Guided Fault Localization for Automated Program Repair Using Large Language Models | https://arxiv.org/pdf/2601.18044 | 831,992 | 5b3a2610c875 | 23 | ov=1.0 |
| `terrarepair-iac-repair-agent.pdf` | TerraRepair: A Tool-Grounded LLM Agent for Infrastructure-as-Code Repair | https://arxiv.org/pdf/2607.11390 | 913,797 | 2fa4cc4192fd | 13 | ov=1.0 |
| `what-s-in-a-benchmark-the-case-of-swe.pdf` | What&#39;s in a Benchmark? The Case of SWE-Bench in Automated Program Repair | https://arxiv.org/pdf/2602.04449 | 704,773 | 6cad7cabdb00 | 12 | ov=1.0 |
| `who-broke-me-dependency-breaks.pdf` | Who Broke Me? Execution-Guided Repair of Behavioral Dependency Breaks | https://arxiv.org/pdf/2610.09267 | 951,952 | 8391ec17636d | 21 | ov=1.0 |

### 5. Agent 化修复与 Harness 循环

（12 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `agent-reactive-bugs-model-harness.pdf` | Understanding Agent-Reactive Bugs at the Model-Harness Boundary: An Empirical Study of LLM Agent Issue Reports | https://arxiv.org/pdf/2607.15684 | 865,862 | 6a5bea273c56 | 12 | ov=1.0 |
| `arxiv-2607.18859.pdf` | PhoenixRepair: Rethinking Repair Strategy Exploration in Software Agents | https://arxiv.org/pdf/2607.18859 | 872,137 | 892d0c8b4a57 | 14 | ov=1.0 |
| `arxiv-2608.04682.pdf` | Active-SWE: Benchmarking Coding Agents for Proactive Bug Fixing without Issue Reports | https://arxiv.org/pdf/2608.04682 | 11,732,524 | e84c764fe3ec | 26 | html-ok |
| `fc-swe-failure-conditioned-rl.pdf` | FC-SWE: Failure-Conditioned RL for Long-Horizon Software Engineering Agents | https://arxiv.org/pdf/2610.07898 | 799,487 | aeaf8a774da3 | 23 | ov=1.0 |
| `kozuchi-agent-software-repair.pdf` | Kozuchi Agent: A Language-Agnostic Open-Weight Agent for Software Repair | https://arxiv.org/pdf/2608.15579 | 1,631,609 | 256691b2a734 | 13 | ov=1.0 |
| `repair-or-resample-mas-failure-debugging.pdf` | Repair or Resample? Rethinking Failure Debugging in LLM Multi-Agent Systems | https://arxiv.org/pdf/2608.25920 | 926,940 | 40419265e399 | 20 | ov=1.0 |
| `retrace-ci-repair-experience.pdf` | RETRACE: From Entangled Repair Histories to Reusable Experience for CI Repair | https://arxiv.org/pdf/2610.04658 | 843,751 | 9be2673405a6 | 32 | ov=1.0 |
| `self-play-swe-rl.pdf` | Toward Training Superintelligent Software Agents through Self-Play SWE-RL | https://arxiv.org/pdf/2512.18552 | 1,206,190 | dccc8543a0e6 | 21 | ov=1.0 |
| `stair-trajectory-abstraction-reuse.pdf` | Reusing Past Repairs Through Hierarchical Trajectory Abstraction for Coding Agents | https://arxiv.org/pdf/2607.29658 | 528,840 | 1d856215d93f | 11 | ov=1.0 |
| `swe-doctor-runtime-diagnosis.pdf` | SWE-Doctor: Guiding Software Engineering Agents with Runtime Diagnosis from Multi-Faceted Bug Reproduction Tests | https://arxiv.org/pdf/2607.00990 | 1,258,859 | c7a4b91298b7 | 12 | ov=1.0 |
| `swe-rl.pdf` | SWE-RL: Advancing LLM Reasoning via Reinforcement Learning on Open Software Evolution | https://arxiv.org/pdf/2502.18449 | 1,941,290 | c649093be691 | 26 | ov=1.0 |
| `verification-failures-reusable-guidance.pdf` | From Verification Failures to Reusable Guidance for Coding Agents | https://arxiv.org/pdf/2609.39022 | 266,971 | 07a0635e85ed | 24 | ov=1.0 |

### 6. 测试与验证方法论

（25 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `ai-driven-test-case-generation-from-natural-language-requirements.pdf` | AI-Driven Test Case Generation from Natural Language Requirements: A Survey of Techniques and Research Gaps | https://arxiv.org/pdf/2606.06563 | 2,871,054 | 0332fc27c864 | 23 | ov=1.0 |
| `arxiv-2604.04580.pdf` | Beyond Fixed Tests: Repository-Level Issue Resolution as Coevolution of Code and Behavioral Constraints | https://arxiv.org/pdf/2604.04580 | 1,086,708 | 57bb54f38288 | 21 | ov=1.0 |
| `arxiv-2607.06065.pdf` | SWE-Review: Closing the Loop on Issue Resolution with Agentic Code Review | https://arxiv.org/pdf/2607.06065 | 916,651 | 6dd673df7edf | 34 | ov=1.0 |
| `arxiv-2607.09123.pdf` | ReProAgent: Tool-Augmented Multi-Stage Agentic Generation of Bug Reproduction Tests from Issue Reports | https://arxiv.org/pdf/2607.09123 | 1,390,566 | c4961228fcaa | 23 | ov=1.0 |
| `arxiv-2607.19843.pdf` | Beyond Fail-to-Pass: Iterative Hardening of Co-Generated Bug Reproduction Tests and Fixes | https://arxiv.org/pdf/2607.19843 | 691,319 | a3a4704f8bfc | 29 | ov=1.0 |
| `automated-unit-test-case-generation-a-systematic-literature-review.pdf` | Automated Unit Test Case Generation: A Systematic Literature Review | https://arxiv.org/pdf/2504.20357 | 1,003,965 | b3d1006e9148 | 47 | ov=1.0 |
| `bidirectional-empowerment-of-metamorphic-testing-and-large-language-models.pdf` | Bidirectional Empowerment of Metamorphic Testing and Large Language Models: A Systematic Survey | https://arxiv.org/pdf/2605.13898 | 2,585,599 | 643a0c2091f4 | 35 | ov=1.0 |
| `can-we-classify-flaky-tests-using-only-test-code.pdf` | Can We Classify Flaky Tests Using Only Test Code? An LLM-Based Empirical Study | https://arxiv.org/pdf/2602.05465 | 362,351 | 441fafd2ad88 | 10 | ov=1.0 |
| `ci-repair-bench.pdf` | CI-Repair-Bench: A Repository-Aware Benchmark for Automated Patch Validation via CI Workflows | https://arxiv.org/pdf/2604.27148 | 807,948 | 9a3310364f3c | 31 | ov=1.0 |
| `dynamic-cogeneration-bug-reproduction-test.pdf` | Dynamic Cogeneration of Bug Reproduction Test in Agentic Program Repair | https://arxiv.org/pdf/2601.19066 | 852,745 | 1d31dc191528 | 11 | ov=1.0 |
| `flaky-tests-in-a-large-industrial-database-management-system.pdf` | Flaky Tests in a Large Industrial Database Management System: An Empirical Study of Fixed Issue Reports for SAP HANA | https://arxiv.org/pdf/2602.03556 | 671,190 | 70dbee0fc547 | 8 | ov=1.0 |
| `flakyguard-automatically-fixing-flaky-tests-at-industry-scale.pdf` | FlakyGuard: Automatically Fixing Flaky Tests at Industry Scale | https://arxiv.org/pdf/2511.14002 | 823,193 | f61801135dc8 | 13 | ov=1.0 |
| `how-far-are-we-from-detecting-flaky-tests-on.pdf` | How Far Are We from Detecting Flaky Tests? On the Limits of Code-Based Detection | https://arxiv.org/pdf/2607.09345 | 347,492 | 2f5a3feff80c | 15 | ov=1.0 |
| `human-in-the-loop-for-fuzz-testing-literature-review.pdf` | Human in the Loop for Fuzz Testing: Literature Review and the Road Ahead | https://arxiv.org/pdf/2603.13411 | 1,577,505 | 26d7a24f3aa6 | 23 | ov=1.0 |
| `large-language-models-for-fuzz-testing-in-microservices-a.pdf` | Large Language Models for Fuzz Testing in Microservices: A Systematic Literature Review | https://arxiv.org/pdf/2609.04219 | 395,935 | 1299ce58f90d | 17 | ov=1.0 |
| `large-language-models-for-unit-testing-a-systematic-literature.pdf` | Large Language Models for Unit Testing: A Systematic Literature Review | https://arxiv.org/pdf/2506.15227 | 1,796,233 | 258fa31d125a | 33 | ov=1.0 |
| `llm-based-test-oracles-source-of-authority-taxonomy-a.pdf` | LLM-Based Test Oracles: Source-of-Authority Taxonomy -- A Systematic Literature Review | https://arxiv.org/pdf/2607.05031 | 571,699 | 615daf687075 | 21 | ov=1.0 |
| `pbt-bench-benchmarking-ai-agents-on-property-based-testing.pdf` | PBT-Bench: Benchmarking AI Agents on Property-Based Testing | https://arxiv.org/pdf/2605.15229 | 726,943 | 7d70b2aff417 | 27 | ov=1.0 |
| `risks-llm-generated-tests-regression.pdf` | On the Risks of using LLM-Generated Tests for Regression Testing | https://arxiv.org/pdf/2610.11835 | 4,601,795 | 2f925784493f | 20 | ov=1.0 |
| `testexplora-benchmarking-llms-for-proactive-bug-discovery-via-repository.pdf` | TestExplora: Benchmarking LLMs for Proactive Bug Discovery via Repository-Level Test Generation | https://arxiv.org/pdf/2602.10471 | 2,240,634 | 9ad51e603880 | 43 | ov=1.0 |
| `testgrad-evolving-test-suites.pdf` | TestGRAD: Evolving Test Suites via Failure Pattern Momentum for SWE-Agent Ensemble | https://arxiv.org/pdf/2610.10242 | 895,029 | d3be3276570b | 12 | ov=1.0 |
| `trustworthy-runtime-error-healing.pdf` | Trustworthy Runtime Error Healing in Real-World Repositories: A Benchmark and Guardrail | https://arxiv.org/pdf/2609.39086 | 1,325,288 | e760f2807397 | 37 | ov=0.778 |
| `understanding-the-characteristics-of-llm-generated-property-based-tests.pdf` | Understanding the Characteristics of LLM-Generated Property-Based Tests in Exploring Edge Cases | https://arxiv.org/pdf/2510.25297 | 244,060 | 039abcc3b668 | 8 | ov=1.0 |
| `verify-repair-repeat-or-stop.pdf` | Verify, Repair, Repeat, or Stop? Robust Stopping for Noisy Verify-Repair Loops in LLM Agents | https://arxiv.org/pdf/2607.17641 | 2,709,785 | d1cc6353465c | 18 | ov=1.0 |
| `veriharness-structured-feedback-repair.pdf` | Structured Feedback Improves Repair in an LLM Agent Loop | https://arxiv.org/pdf/2607.14167 | 456,412 | 8b9e390bea8b | 4 | ov=1.0 |

### 7. 评测与元评估

（40 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `a-comprehensive-survey-on-benchmarks-and-solutions-in-software.pdf` | A Comprehensive Survey on Benchmarks and Solutions in Software Engineering of LLM-Empowered Agentic System | https://arxiv.org/pdf/2510.09721 | 1,374,840 | 47e2ee43fd19 | 22 | ov=1.0 |
| `a-memorization-floor-for-llm-refinement-of-decompiled-code.pdf` | A Memorization Floor for LLM Refinement of Decompiled Code | https://arxiv.org/pdf/2609.17236 | 554,788 | 89b739ce928e | 29 | ov=1.0 |
| `arxiv-2605.12270.pdf` | Characterizing the Failure Modes of LLMs in Resolving Real-World GitHub Issues | https://arxiv.org/pdf/2605.12270 | 4,342,785 | 8d511937db13 | 17 | ov=0.889 |
| `arxiv-2605.22526.pdf` | &#34;Refactoring Runaway&#34;: Understanding and Mitigating Tangled Refactorings in Coding Agents for Issue Resolution | https://arxiv.org/pdf/2605.22526 | 6,763,101 | 99bc338dcb1c | 34 | ov=1.0 |
| `arxiv-2606.22110.pdf` | TraceView: Interactive Visualization of Agentic Program Repair Trajectories | https://arxiv.org/pdf/2606.22110 | 750,813 | 2835ba1b65a6 | 5 | ov=1.0 |
| `arxiv-2606.26978.pdf` | To Run or Not to Run: Analyzing the Cost-Effectiveness of Code Execution in LLM-Based Program Repair | https://arxiv.org/pdf/2606.26978 | 711,127 | 599f27dc28ec | 23 | ov=1.0 |
| `arxiv-2607.14657.pdf` | Rethinking Issue Resolution for AI/ML Systems | https://arxiv.org/pdf/2607.14657 | 293,950 | de04513f707a | 6 | ov=1.0 |
| `arxiv-2607.18550.pdf` | Semantic Drift in Bug Resolution: How Behavioral Signals Propagate from Reports to Tests and Patches | https://arxiv.org/pdf/2607.18550 | 1,439,697 | 7e3832e9bd03 | 38 | ov=1.0 |
| `arxiv-2607.28871.pdf` | Validation Evidence in LLM Repair Agents: How Much of What Passes Actually Tests the Bug? | https://arxiv.org/pdf/2607.28871 | 365,916 | bc5d13067188 | 24 | ov=1.0 |
| `arxiv-2609.36635.pdf` | WitnessGym: Benchmarking Coding Agents on the Construction of Bug Witnesses | https://arxiv.org/pdf/2609.36635 | 18,137,755 | e828892c1df3 | 30 | html-ok |
| `chainswe-multi-bug-maintenance.pdf` | ChainSWE: Benchmarking Coding Agents on Multi-Bug Software Maintenance | https://arxiv.org/pdf/2607.02606 | 1,888,489 | be24179287e5 | 19 | ov=1.0 |
| `coding-agents-have-converged-why-the-swe-bench-leaderboard.pdf` | Coding Agents Have Converged: Why the SWE-bench Leaderboard Can No Longer Order Its Top Entries, and What to Measure Instead | https://arxiv.org/pdf/2609.17394 | 2,247,850 | e92261f13d1c | 15 | ov=1.0 |
| `cuadebug-computer-use-agent-failures.pdf` | CUADebug: Diagnosing and Repairing Computer-Use Agent Failures | https://arxiv.org/pdf/2608.02643 | 7,032,123 | 2e09cae67d48 | 26 | ov=1.0 |
| `diff-based-code-corruption-benchmarking.pdf` | Diff-Based Code Corruption using LLMs for Large-Scale Bugfix Benchmarking | https://arxiv.org/pdf/2606.29088 | 260,006 | eae4505b3838 | 13 | ov=1.0 |
| `experimental-settings-llm-apr.pdf` | Experimental Settings in LLM-Based Program Repair: A Study of Inputs, Tool Access, Feedback, and Validation | https://arxiv.org/pdf/2609.17993 | 347,056 | cfa9f425f245 | 11 | ov=1.0 |
| `failure-as-a-process-an-anatomy-of-cli-coding.pdf` | Failure as a Process: An Anatomy of CLI Coding Agent Trajectories | https://arxiv.org/pdf/2607.09510 | 921,191 | 5d45c4f70d9a | 12 | ov=1.0 |
| `how-coding-agents-fail-their-users-a-large-scale.pdf` | How Coding Agents Fail Their Users: A Large-Scale Analysis of Developer-Agent Misalignment in 20,574 Real-World Sessions | https://arxiv.org/pdf/2605.29442 | 682,655 | 2daedf6d2e32 | 19 | ov=1.0 |
| `how-do-practitioners-build-se-agents-insights-from-a.pdf` | How Do Practitioners Build SE Agents? Insights from a Mixed-Methods Study | https://arxiv.org/pdf/2607.10856 | 939,958 | e65997683ea4 | 13 | ov=1.0 |
| `keep-evaluation-fair-detecting-data-leakage-in-code-generation.pdf` | Keep Evaluation Fair: Detecting Data Leakage in Code Generation Benchmarks via Membership Inference Attacks | https://arxiv.org/pdf/2609.09865 | 2,831,768 | 2241e9e742b7 | 32 | ov=1.0 |
| `labelling-bug-fixing-commits.pdf` | Labelling Bug-Fixing Commits with Local Open-Weight Language Models | https://arxiv.org/pdf/2609.21616 | 557,575 | 98e4a05ec9ea | 19 | ov=1.0 |
| `maintaining-benchmarks-against-increasingly-capable-agents-detection-and-remediation.pdf` | Maintaining Benchmarks Against Increasingly Capable Agents: Detection and Remediation of Unearned Passes | https://arxiv.org/pdf/2609.34262 | 5,839,990 | f20670f29ee0 | 32 | ov=1.0 |
| `passing-tests-hide-silent-failures.pdf` | When Passing Tests Hides Vulnerabilities: An Empirical Study of Silent Failures in Agentic Systems | https://arxiv.org/pdf/2609.10548 | 803,251 | 51b0da819762 | 22 | ov=1.0 |
| `position-coding-benchmarks-are-misaligned-with-agentic-software-engineering.pdf` | Position: Coding Benchmarks Are Misaligned with Agentic Software Engineering | https://arxiv.org/pdf/2606.17799 | 700,892 | 741f0d08a82e | 6 | ov=1.0 |
| `rigorous-agentic-benchmarks.pdf` | Establishing Best Practices for Building Rigorous Agentic Benchmarks | https://arxiv.org/pdf/2507.02825 | 1,242,188 | 6bee07172c55 | 39 | ov=1.0 |
| `schroedinger-s-code-repository-have-llms-learned-swe-bench.pdf` | Schrödinger&#39;s Code Repository: Have LLMs Learned SWE-bench or Memorized It? | https://arxiv.org/pdf/2609.27891 | 3,508,285 | 95f959b226b6 | 12 | ov=0.8 |
| `specification-driven-benchmarking-apr.pdf` | Specification-Driven Benchmarking for Automated Program Repair From Static Corpora to Executable Specifications | https://arxiv.org/pdf/2609.28896 | 476,188 | d4953f58bbc3 | 10 | ov=1.0 |
| `swe-abs.pdf` | SWE-ABS: Adversarial Benchmark Strengthening Exposes Inflated Success Rates on Test-based Benchmark | https://arxiv.org/pdf/2603.00520 | 698,597 | e1e972dc190a | 36 | ov=1.0 |
| `swe-bench-illusion.pdf` | The SWE-Bench Illusion: When State-of-the-Art LLMs Remember Instead of Reason | https://arxiv.org/pdf/2506.12286 | 2,341,152 | 9316b486df60 | 11 | ov=1.0 |
| `swe-bench-live.pdf` | SWE-bench Goes Live! | https://arxiv.org/pdf/2505.23419 | 2,178,561 | 4126454bc9b1 | 24 | ov=1.0 |
| `swe-bench-pro-verified-a-reliable-benchmark-for-software.pdf` | SWE-Bench Pro Verified: A Reliable Benchmark for Software Engineering Agents | https://arxiv.org/pdf/2609.08149 | 1,974,858 | 340e06cd2894 | 37 | ov=1.0 |
| `swe-bench-pro.pdf` | SWE-Bench Pro: Can AI Agents Solve Long-Horizon Software Engineering Tasks? | https://arxiv.org/pdf/2509.16941 | 1,585,853 | 38bafe017fe2 | 20 | ov=1.0 |
| `swe-bench-test-overfitting.pdf` | Investigating Test Overfitting on SWE-bench | https://arxiv.org/pdf/2511.16858 | 773,469 | 27c86521338d | 5 | ov=1.0 |
| `swe-bench-verified-memory.pdf` | Does SWE-Bench-Verified Test Agent Ability or Model Memory? | https://arxiv.org/pdf/2512.10218 | 390,177 | 704998200abd | 4 | ov=1.0 |
| `swe-compass.pdf` | SWE-Compass: Towards Unified Evaluation of Agentic Coding Abilities for Large Language Models | https://arxiv.org/pdf/2511.05459 | 1,359,675 | 53d7109a3f9f | 24 | ov=1.0 |
| `swe-shield-design-constraints.pdf` | Does Pass Rate Tell the Whole Story? Evaluating Design Constraint Compliance in LLM-based Issue Resolution | https://arxiv.org/pdf/2604.05955 | 2,173,254 | 2c699842dcf8 | 14 | ov=1.0 |
| `testjack-should-you-trust-the-results-in-coding-benchmarks.pdf` | TestJack: Should you trust the results in coding benchmarks? Agentic Coding Benchmarks Auditing via Evaluator Evolution | https://arxiv.org/pdf/2610.10619 | 675,743 | d9c858663c27 | 36 | ov=1.0 |
| `understanding-code-agent-behaviour-an-empirical-study-of-success.pdf` | Understanding Code Agent Behaviour: An Empirical Study of Success and Failure Trajectories | https://arxiv.org/pdf/2511.00197 | 893,277 | 30bd6484a101 | 9 | ov=1.0 |
| `understanding-software-engineering-agents-a-study-of-thought-action.pdf` | Understanding Software Engineering Agents: A Study of Thought-Action-Result Trajectories | https://arxiv.org/pdf/2506.18824 | 1,336,928 | e26bdd634404 | 12 | ov=1.0 |
| `utboost-swe-bench.pdf` | UTBoost: Rigorous Evaluation of Coding Agents on SWE-Bench | https://arxiv.org/pdf/2506.09289 | 554,927 | 3096d8628d1d | 13 | ov=1.0 |
| `when-agents-fail-a-comprehensive-study-of-bugs-in.pdf` | When Agents Fail: A Comprehensive Study of Bugs in LLM Agents with Automated Labeling | https://arxiv.org/pdf/2601.15232 | 2,699,251 | d3f2ca040954 | 12 | ov=1.0 |

### 8. 安全缺陷修复

（18 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `a-systematic-literature-review-for-transformer-based-software-vulnerability.pdf` | A systematic literature Review for Transformer-based Software Vulnerability detection | https://arxiv.org/pdf/2604.24822 | 1,294,763 | 5c0b47d0e124 | 29 | ov=1.0 |
| `a-systematic-literature-review-on-detecting-software-vulnerabilities-with.pdf` | A Systematic Literature Review on Detecting Software Vulnerabilities with Large Language Models | https://arxiv.org/pdf/2507.22659 | 2,581,596 | 769dc5aa9953 | 63 | ov=1.0 |
| `ai-based-software-vulnerability-detection-a-systematic-literature-review.pdf` | AI-Based Software Vulnerability Detection: A Systematic Literature Review | https://arxiv.org/pdf/2506.10280 | 1,371,888 | 9135fa77c9a6 | 35 | ov=1.0 |
| `arxiv-2605.17444.pdf` | MemRepair: Hierarchical Memory for Agentic Repository-Level Vulnerability Repair | https://arxiv.org/pdf/2605.17444 | 4,602,309 | 4e317102befc | 12 | ov=1.0 |
| `arxiv-2607.29422.pdf` | AgenticRepair: Multi-Faceted Program Context Engineering for Agentic Vulnerability Repair | https://arxiv.org/pdf/2607.29422 | 3,182,460 | 53b421f73cba | 12 | ov=1.0 |
| `benchmarking-automated-security-patch-backporting-how-far-are-we.pdf` | Benchmarking Automated Security Patch Backporting: How Far Are We? | https://arxiv.org/pdf/2608.17671 | 904,958 | 032e468a92c6 | 13 | ov=1.0 |
| `knowledge-enhanced-agentic-vuln-repair.pdf` | Knowledge-Enhanced Agentic Vulnerability Repair | https://arxiv.org/pdf/2607.00820 | 2,013,082 | ae265332f74f | 12 | ov=1.0 |
| `large-language-models-at-the-intersection-of-software-engineering.pdf` | Large Language Models at the Intersection of Software Engineering and Software Security:An Evidence-Centered Structured Survey and Research Agenda | https://arxiv.org/pdf/2608.21107 | 451,451 | a6fd835f1f9c | 23 | ov=1.0 |
| `metrics-failure-in-llm-based-code-vulnerability-repair-an.pdf` | Metrics Failure in LLM-Based Code Vulnerability Repair: An Empirical Study and a Change-Aware Screen | https://arxiv.org/pdf/2609.26749 | 540,691 | 740a2588db0f | 23 | ov=1.0 |
| `one-is-not-enough-the-untold-story-of-multiple.pdf` | One Is Not Enough: The Untold Story of Multiple Security Patches for One Vulnerability | https://arxiv.org/pdf/2609.07224 | 2,046,917 | 402e061041f3 | 13 | ov=1.0 |
| `patchbench-vulnerability-patching.pdf` | PatchBench: Evaluating AI Agents for Vulnerability Patching | https://arxiv.org/pdf/2609.04075 | 1,456,190 | 5df46a03d19f | 21 | ov=1.0 |
| `reinforcement-learning-for-software-vulnerability-analysis-a-systematic-review.pdf` | Reinforcement Learning for Software Vulnerability Analysis: A Systematic Review with Emphasis on C/C++ Source Code and Static Analysis | https://arxiv.org/pdf/2606.28403 | 377,935 | 7e462bce47d4 | 15 | ov=1.0 |
| `reliability-vuln-patching-benchmarks.pdf` | On the Reliability of LLM-Based Vulnerability Patching Benchmarks | https://arxiv.org/pdf/2610.10150 | 257,012 | 0ee3e9dc4857 | 20 | ov=1.0 |
| `silent-failure-origins-vuln-repair.pdf` | Where Did the Repair First Go Wrong? Localizing the Origins of Silent Failures in Agentic Vulnerability Repair | https://arxiv.org/pdf/2610.06163 | 728,699 | 57fb86e8a1f0 | 21 | ov=1.0 |
| `sok-automated-vulnerability-repair-methods-tools-and-assessments.pdf` | SoK: Automated Vulnerability Repair: Methods, Tools, and Assessments | https://arxiv.org/pdf/2506.11697 | 1,926,903 | a202943f13fa | 31 | ov=1.0 |
| `sok-towards-effective-automated-vulnerability-repair.pdf` | SoK: Towards Effective Automated Vulnerability Repair | https://arxiv.org/pdf/2501.18820 | 1,519,211 | daca3446a0ec | 25 | ov=1.0 |
| `vul4py-vulnerability-repair-bench.pdf` | Vul4Py: Benchmarking Automated Vulnerability Repair in Python with Paired Exploit and Functional Oracles | https://arxiv.org/pdf/2608.00692 | 497,766 | 0d569f763a96 | 19 | ov=1.0 |
| `why-not-fix-it-once-and-for-all-an.pdf` | Why Not Fix It Once and for All? An Empirical Study of Multiple Patches for Vulnerability Fixes in Open-Source Software | https://arxiv.org/pdf/2607.13206 | 1,093,681 | 8bc4d9e800a1 | 20 | ov=1.0 |

### 9. 缺陷与失败模式分类法

（7 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `agentbug-smith-harness-bugs.pdf` | AgentBug-Smith: Automatically Reproducing Real-World Harness Bugs in Agentic Systems | https://arxiv.org/pdf/2609.37864 | 2,816,158 | 0ea22d119580 | 20 | ov=1.0 |
| `approval-laundering-harness-failures.pdf` | Approval Laundering: Systematizing Approval--Execution Binding Failures in AI Coding-Agent Harnesses | https://arxiv.org/pdf/2609.38983 | 411,180 | a1c13d650d18 | 20 | ov=1.0 |
| `compound-ai-reliability-failure-taxonomy.pdf` | Compound AI System Reliability: A Failure Taxonomy and Resilience Pattern Catalog from 150 Production Incidents | https://arxiv.org/pdf/2610.02503 | 157,566 | 9c3dea1d6690 | 6 | ov=1.0 |
| `dl-compiler-frontend-bug-taxonomy.pdf` | Demystifying Deep Learning Compiler Frontend Bugs: An LLM-Aided Empirical Study | https://arxiv.org/pdf/2607.25651 | 3,205,856 | baaded753d24 | 13 | ov=1.0 |
| `mcp-server-runtime-fault-taxonomy.pdf` | A Taxonomy of Runtime Faults in Model Context Protocol Servers | https://arxiv.org/pdf/2606.05339 | 592,401 | c41b313b3ca7 | 17 | ov=1.0 |
| `mm-agent-implementation-bug-taxonomy.pdf` | A Comprehensive Study of Implementation Bugs in Multi-modal Agents | https://arxiv.org/pdf/2607.04974 | 949,394 | 4b5d7f7c6836 | 13 | ov=1.0 |
| `sok-os-kernel-bug-lifecycle.pdf` | SoK: From Finding to Deployment: Systematizing the OS Kernel Bug Lifecycle | https://arxiv.org/pdf/2609.23218 | 408,862 | eaf8b2de458b | 19 | ov=1.0 |

### 10. Agent 工程方法论

（4 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `ai-harness-engineering-runtime-substrate.pdf` | AI Harness Engineering: A Runtime Substrate for Foundation-Model Software Agents | https://arxiv.org/pdf/2605.13357 | 263,956 | a1e2d7ce307c | 16 | ov=1.0 |
| `governance-methodology-layer-ai-swe.pdf` | A Governance Methodology Layer for AI-Assisted Software Development: Defect Taxonomy, Controlled Ablation, and a Test of Process-Over-Capability | https://arxiv.org/pdf/2609.04218 | 767,952 | 1f6368d4278b | 23 | ov=1.0 |
| `meta-engineering-harnesses-adversarial-verification.pdf` | Meta-Engineering Harnesses for AI-Native Software Production: A Contract-Driven Adversarial Verification Architecture with Early Deployment Report | https://arxiv.org/pdf/2605.25665 | 424,154 | 4ed626ac4e49 | 16 | ov=1.0 |
| `trajectory-guided-fault-localization-skills.pdf` | Trajectory-Guided Fault Localization for Agent Skill Evolution | https://arxiv.org/pdf/2610.11858 | 1,028,455 | 486a29aba386 | 20 | ov=1.0 |

### 11. 工业界研究与经验报告

（3 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `crash-report-mining-industrial-repair.pdf` | Integrating Crash Report Mining and LLMs for Bug Localization and Repair: An Industrial Report | https://arxiv.org/pdf/2609.04483 | 343,398 | fc225b405100 | 12 | ov=1.0 |
| `google-scale-agentic-repair-low-latency.pdf` | Catching Developers in the Flow: Low-Latency Agentic Program Repair at Google Scale | https://arxiv.org/pdf/2610.07289 | 1,609,936 | 1fd6ae68a612 | 13 | ov=1.0 |
| `industrial-test-failure-analysis-experience.pdf` | Supporting Industrial Test-Failure Analysis with LLM-Based Systems: An Experience Report | https://arxiv.org/pdf/2609.21843 | 825,183 | 3dcc1075dfd4 | 16 | ov=1.0 |

### 12. 经典奠基文献（APR）

（22 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `classic-defects4j-dissection-saner2018.pdf` | Dissection of a Bug Dataset: Anatomy of 395 Patches from Defects4J | https://arxiv.org/pdf/1801.06393 | 384,987 | fc0c17028b1a | 11 | ov=1.0 |
| `classic-defects4j-manual-inspection-2019.pdf` | A manual inspection of Defects4J bugs and its implications for automatic program repair | https://xgdsmileboy.github.io/files/paper/scis19.pdf | 1,207,435 | df6d1a40c567 | 16 | ov=1.0 |
| `classic-fixminer-emse2020.pdf` | FixMiner: Mining Relevant Fix Patterns for Automated Program Repair | https://arxiv.org/pdf/1810.01791v1 | 874,665 | 21016f8c96e8 | 31 | ov=1.0 |
| `classic-genesis-fse2017.pdf` | Automatic Inference of Code Transforms for Patch Generation | https://people.csail.mit.edu/rinard/paper/fse17.genesis.pdf | 1,056,156 | d228967ff662 | 13 | ov=1.0 |
| `classic-genprog-tse2012.pdf` | GenProg: A Generic Method for Automatic Software Repair | https://web.eecs.umich.edu/~weimerw/p/weimer-tse2012-genprog.pdf | 3,093,295 | 7f3f698ee3ae | 19 | ov=1.0 |
| `classic-liu-critical-review-jss2021.pdf` | A Critical Review on the Evaluation of Automated Program Repair Systems | https://kui-liu.github.io/papers/liu2020critical.pdf | 950,762 | bd29fefa60af | 13 | ov=0.857 |
| `classic-liu-efficiency-icse2020.pdf` | On the Efficiency of Test Suite based Program Repair: 16 Systems Assessed | https://kui-liu.github.io/papers/liu2020efficiency.pdf | 3,382,697 | 13a9be47a1ef | 13 | ov=1.0 |
| `classic-liu-fl-bias-icst2019.pdf` | You Cannot Fix What You Cannot Find! Fault Localization Bias in Benchmarking APR Systems | https://kui-liu.github.io/papers/liu2019you.pdf | 843,810 | 81759468fa52 | 12 | ov=0.846 |
| `classic-par-issta2015-plausibility.pdf` | An Analysis of Patch Plausibility and Correctness for Generate-and-Validate Patch Generation Systems | https://people.csail.mit.edu/rinard/paper/issta15.pdf | 313,769 | 818edfa4de64 | 13 | ov=1.0 |
| `classic-quixbugs-jss2021.pdf` | A Comprehensive Study of Automatic Program Repair on the QuixBugs Benchmark | https://arxiv.org/pdf/1805.03454 | 1,310,633 | 72513cee6bc2 | 17 | ov=1.0 |
| `classic-repairnator-ubiquity2019.pdf` | Repairnator patches programs automatically | https://arxiv.org/pdf/1910.06247 | 260,700 | 53b7559998d9 | 6 | ov=1.0 |
| `classic-searchspace-icse2016.pdf` | An Analysis of the Search Spaces for Generate and Validate Patch Generation Systems | https://people.csail.mit.edu/rinard/paper/icse16.searchspace.pdf | 270,241 | 4cb69bb69e34 | 12 | ov=1.0 |
| `classic-simfix-issta2018.pdf` | Shaping Program Repair Space with Existing Patches and Similar Code | https://xgdsmileboy.github.io/files/paper/simfix-issta18.pdf | 623,216 | 4fac23fa52b0 | 12 | ov=1.0 |
| `classic-smith-overfitting-fse2015.pdf` | Is the Cure Worse Than the Disease? Overfitting in Automated Program Repair | https://people.cs.umass.edu/~brun/pubs/pubs/Smith15fse.pdf | 523,746 | 60c423f085ab | 12 | ov=1.0 |
| `classic-tian-patch-correctness-ase2020.pdf` | Evaluating Representation Learning of Code Changes for Predicting Patch Correctness | https://kui-liu.github.io/papers/tian2020evaluating.pdf | 945,627 | f276a76a37f0 | 12 | ov=1.0 |
| `classic-xia-apr-llm-icse2023.pdf` | Automated Program Repair in the Era of Large Pre-trained Language Models | https://lingming.cs.illinois.edu/publications/icse2023a.pdf | 652,819 | 968c545d664d | 13 | ov=1.0 |
| `classic-xiong-patch-correctness-icse2018.pdf` | Identifying Patch Correctness in Test-Based Program Repair | https://arxiv.org/pdf/1706.09120 | 803,197 | 5b0d11adf877 | 12 | ov=1.0 |
| `long-fse2015-staged-program-repair.pdf` | Staged Program Repair with Condition Synthesis | https://people.csail.mit.edu/fanl/papers/spr-fse15.pdf | 452,593 | 9f9bf9b79e72 | 13 | ov=1.0 |
| `long-popl2016-learning-correct-code.pdf` | Automatic Patch Generation by Learning Correct Code | https://people.csail.mit.edu/fanl/papers/prophet-popl16.pdf | 537,132 | 46443081f5a3 | 15 | ov=1.0 |
| `monperrus-csur2018-repair-bibliography.pdf` | Automatic Software Repair a Bibliography | https://arxiv.org/pdf/1807.00515 | 518,680 | 820069d4a748 | 26 | ov=1.0 |
| `program-repair-org-catalogue.html` | Program Repair community catalogue | https://program-repair.org/ | 8,601 | 8e87a044575a | — | ov=0.75 |
| `weimer-icse2009-genprog.pdf` | Automatically Finding Patches Using Genetic Programming | https://web.eecs.umich.edu/~weimerw/p/weimer-icse2009-genprog.pdf | 275,536 | 34c70ec1766c | 11 | ov=1.0 |

### 13. 经典奠基文献（测试）

（9 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `classic-aflfast-ccs2016.pdf` | Coverage-based Greybox Fuzzing as Markov Chain | https://mboehme.github.io/paper/CCS16.pdf | 482,163 | fb3a7a742806 | 12 | ov=1.0 |
| `classic-aflgo-ccs2017.pdf` | Directed Greybox Fuzzing | https://mboehme.github.io/paper/CCS17.pdf | 947,732 | 9099941a65dd | 16 | ov=1.0 |
| `classic-csmith-pldi2011.pdf` | Finding and Understanding Bugs in C Compilers | https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf | 316,165 | 4381d8634181 | 12 | ov=1.0 |
| `classic-oracle-problem-tse2015.pdf` | The Oracle Problem in Software Testing: A Survey | http://www0.cs.ucl.ac.uk/staff/m.harman/tse-oracle.pdf | 773,275 | 6c5689497594 | 31 | ov=1.0 |
| `classic-pbt-in-practice-icse2024.pdf` | Property-Based Testing in Practice | https://harrisongoldste.in/papers/icse24-pbt-in-practice.pdf | 496,661 | 53a63988b0f4 | 13 | ov=1.0 |
| `classic-quickcheck-icfp2000.pdf` | QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs | https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf | 194,315 | bfddcaa648f8 | 12 | ov=0.857 |
| `classic-rts-survey-stvr2012.pdf` | Regression testing minimization, selection and prioritization: a survey | https://coinse.github.io/publications/pdfs/Yoo2010fk.pdf | 674,165 | 9b441e100276 | 54 | ov=1.0 |
| `classic-testing-travelogue-2014.pdf` | Software Testing: A Research Travelogue (2000-2014) | https://pdfs.semanticscholar.org/7d5d/612728297a1be12e1081041909078a3d06d9.pdf | 3,553,226 | 40ffb4bc9bc4 | 41 | ov=1.0 |
| `manes-tse2019-fuzzing-survey.pdf` | The Art Science and Engineering of Fuzzing A Survey | https://arxiv.org/pdf/1812.00140 | 507,913 | b683da872e36 | 21 | ov=1.0 |

### 14. 工业实践 I：事故响应与事后复盘

（8 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `industry-atlassian-post-incident-reviews.html` | Post-Incident Reviews Atlassian Incident Management Handbook | https://www.atlassian.com/incident-management/postmortem | 2,151,861 | 2a8bb669583d | — | ov=0.429 |
| `industry-cook-how-complex-systems-fail.html` | How Complex Systems Fail | https://how.complexsystems.fail/ | 23,713 | 49394f4ba596 | — | ov=1.0 |
| `industry-datadog-automated-postmortems.html` | Create actionable postmortems automatically with Datadog | https://www.datadoghq.com/blog/create-postmortems-with-datadog/ | 333,039 | 179233b41e5b | — | ov=1.0 |
| `industry-grafana-ai-assisted-rca-3-5x.html` | How our AI assistant found the root cause 3.5x faster | https://grafana.com/blog/a-tale-of-two-incident-responses-how-our-ai-assist-helped-us-find-the-cause-3-5x-faster/ | 398,747 | 7bdce5c864b1 | — | ov=1.0 |
| `industry-honeycomb-incident-review-working-as-designed.html` | Incident Review Working as Designed But Still Failing | https://www.honeycomb.io/blog/incident-review-designed-failing | 269,728 | 29ff4e46687f | — | ov=1.0 |
| `industry-incident-io-postmortem-guide.html` | Writing a post-mortem The practical guide to incident management | https://incident.io/guide/learn-and-improve/post-mortem-documents | 121,342 | f313046dfab7 | — | ov=1.0 |
| `industry-meta-drp-root-cause-analysis-platform.html` | DrP Meta's Root Cause Analysis Platform at Scale | https://engineering.fb.com/2025/12/19/data-infrastructure/drp-metas-root-cause-analysis-platform-at-scale/ | 102,097 | ad0677373252 | — | ov=1.0 |
| `industry-pagerduty-incident-response-docs.html` | PagerDuty Incident Response Documentation | https://response.pagerduty.com/ | 25,569 | fa6fcd7717fc | — | ov=1.0 |

### 15. 工业实践 II：AI 修复、代码审查与风险评分

（11 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `industry-anthropic-fix-software-bugs-faster.html` | Fix software bugs faster with Claude | https://claude.com/blog/fix-software-bugs-faster-with-claude | 561,992 | 27760e8e14cc | — | ov=1.0 |
| `industry-cloudflare-ai-code-review-at-scale.html` | Orchestrating AI Code Review at scale | https://blog.cloudflare.com/ai-code-review/ | 378,092 | 51a08696d84f | — | ov=1.0 |
| `industry-github-agentic-autofix-changelog.html` | Agentic autofix for code scanning alerts in public preview | https://github.blog/changelog/2026-07-10-agentic-autofix-for-code-scanning-alerts-in-public-preview/ | 108,039 | 424028c2b808 | — | ov=1.0 |
| `industry-github-copilot-autofix.html` | Found means fixed secure code more than three times faster with Copilot Autofix | https://github.blog/news-insights/product-news/secure-code-more-than-three-times-faster-with-copilot-autofix/ | 186,081 | a8c4c36bb4fa | — | ov=1.0 |
| `industry-meta-autopatchbench-security-fixes.html` | Introducing AutoPatchBench A Benchmark for AI-Powered Security Fixes | https://engineering.fb.com/2025/04/29/ai-research/autopatchbench-benchmark-ai-powered-security-fixes/ | 126,909 | 53b17d13cf51 | — | ov=1.0 |
| `industry-meta-diff-risk-score.html` | Diff Risk Score AI-driven risk-aware software development | https://engineering.fb.com/2025/08/06/developer-tools/diff-risk-score-drs-ai-risk-aware-software-development-meta/ | 92,212 | 8da2bfa9901f | — | ov=1.0 |
| `industry-meta-jit-testing-agentic-development.html` | The death of traditional testing agentic development JIT testing revival | https://engineering.fb.com/2026/02/11/developer-tools/the-death-of-traditional-testing-agentic-development-jit-testing-revival/ | 90,938 | 914b740a88e1 | — | ov=0.75 |
| `industry-meta-llm-bug-catchers-ach.html` | Revolutionizing software testing LLM-powered bug catchers | https://engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/ | 98,895 | efef180a2f76 | — | ov=1.0 |
| `industry-meta-llm-mutation-testing.html` | LLMs are the key to mutation testing and better compliance | https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/ | 104,380 | 47698eb07f79 | — | ov=1.0 |
| `industry-microsoft-debug-with-copilot-prompts.html` | Debug with Copilot prompts Visual Studio | https://learn.microsoft.com/en-us/visualstudio/debugger/debug-with-copilot-prompts?view=vs-2022 | 54,475 | c927b5616878 | — | ov=1.0 |
| `industry-uber-ureview-genai-code-review.html` | uReview Scalable Trustworthy GenAI for Code Review at Uber | https://www.uber.com/blog/ureview/ | 513,943 | 55a30b1072c5 | — | html-ok |

### 16. 工业实践 III：交付、变更控制与混沌工程

（8 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `industry-aws-ensuring-rollback-safety.html` | Ensuring rollback safety during deployments Amazon Builders Library | https://aws.amazon.com/builders-library/ensuring-rollback-safety-during-deployments/ | 129,769 | 8a7889cc616e | — | ov=0.625 |
| `industry-dora-2024-report.html` | 2024 DORA Report Accelerate State of DevOps | https://dora.dev/research/2024/dora-report/ | 14,909 | c6fb59d69e45 | — | ov=1.0 |
| `industry-dora-2025-report.html` | 2025 DORA Report State of AI-assisted Software Development | https://dora.dev/research/2025/dora-report/ | 13,392 | 6bb53c243fc6 | — | ov=0.857 |
| `industry-dora-four-keys.html` | DORA metrics four keys | https://dora.dev/guides/dora-metrics-four-keys/ | 19,454 | 00f7a12f296d | — | ov=0.5 |
| `industry-fowler-canary-release.html` | CanaryRelease | https://martinfowler.com/bliki/CanaryRelease.html | 21,078 | 916caf0f38ff | — | html-ok |
| `industry-fowler-feature-toggles.html` | Feature Toggles aka Feature Flags | https://martinfowler.com/articles/feature-toggles.html | 79,854 | d4e1a56d2d8c | — | ov=1.0 |
| `industry-principles-of-chaos-engineering.html` | Principles of Chaos Engineering | https://principlesofchaos.org/ | 8,281 | 06bb2df5d5da | — | ov=1.0 |
| `industry-trunk-based-development.html` | Trunk-Based Development | https://trunkbaseddevelopment.com/ | 23,030 | c9d1c46aeee6 | — | html-ok |

### 17. 工业实践 IV：缺陷分类法与标准

（6 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `industry-chillarege-odc-concept.html` | Orthogonal Defect Classification A Concept for In-Process Measurements | https://www.chillarege.com/docs/Papers/concept/ | 154,862 | e5ec4ab108d9 | — | html-ok |
| `industry-cwe-top25-2025.html` | 2025 CWE Top 25 Most Dangerous Software Weaknesses | https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html | 41,662 | 5549e8bdd7b9 | — | ov=1.0 |
| `industry-howtheysre-archive.html` | How They SRE curated SRE practice archive | https://github.com/upgundecha/howtheysre | 897,138 | 0ce820eaad57 | — | ov=0.429 |
| `industry-lean-five-whys.html` | Five Whys Lean Lexicon | https://www.lean.org/lexicon-terms/five-whys/ | 104,959 | 6f1df62bca5a | — | ov=0.5 |
| `industry-mozilla-filing-good-bugs.html` | Filing good bugs Mozilla Firefox Source Docs | https://firefox-source-docs.mozilla.org/contributing/filing-good-bugs.html | 29,771 | 5787796a918d | — | ov=0.857 |
| `industry-tatham-how-to-report-bugs-effectively.html` | How to Report Bugs Effectively | https://www.chiark.greenend.org.uk/~sgtatham/bugs.html | 22,512 | b75f991675ba | — | ov=1.0 |

### 18. 工业实践 V：大规模调试基础设施

（7 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `industry-antithesis-debugging-in-the-multiverse.html` | Debugging in the Multiverse | https://antithesis.com/blog/multiverse_debugging/ | 100,891 | c64a91d3531f | — | ov=1.0 |
| `industry-google-sanitizers.html` | google sanitizers repository | https://github.com/google/sanitizers | 281,701 | c6ea6500af09 | — | ov=0.667 |
| `industry-grafana-pyroscope-2-0.html` | Introducing Pyroscope 2.0 continuous profiling at scale | https://grafana.com/blog/pyroscope-2-0-release/ | 417,063 | 57734ec355c9 | — | ov=1.0 |
| `industry-gregg-ebpf-tracing-tools.html` | eBPF Tracing Tools | https://www.brendangregg.com/ebpf.html | 103,792 | cec2fee08a9c | — | ov=1.0 |
| `industry-llvm-addresssanitizer.html` | AddressSanitizer LLVM Clang documentation | https://clang.llvm.org/docs/AddressSanitizer.html | 78,037 | 9b7230ddc5b5 | — | ov=0.5 |
| `industry-microsoft-time-travel-debugging.html` | Time Travel Debugging Overview Microsoft | https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/time-travel-debugging-overview | 61,096 | 51f6a44f4009 | — | ov=1.0 |
| `industry-rr-project-record-replay.html` | rr record and replay debugging | https://rr-project.org/ | 19,443 | 7d01202e7fa5 | — | html-ok |

### 19. 批次 1（2026-10-08）既有原文（保留原记录，未重复下载）

| 文件 | 标题（逐字） | 作者 | 来源 URL | 字节数 | sha256(12) | 页数 | 状态 |
|---|---|---|---|---|---|---|---|
| `zeller-esec1999-delta-debugging.pdf` | Yesterday, My Program Worked. Today, It Does Not. Why? | Andreas Zeller | https://www.cs.purdue.edu/homes/xyzhang/spring07/Papers/p253-zeller.pdf | 1015377 | a6fe118aeaf1 | 15 | 有效（作者站点直连超时，改用 Purdue 教学镜像） |
| `arxiv-1607.04347.pdf` | Spectrum-based Software Fault Localization: A Survey of Techniques, Advances, and Challenges | Higor A. de Souza; Marcos L. Chaim; Fabio Kon | https://arxiv.org/pdf/1607.04347 | 618563 | de7977705064 | 46 | 有效（arXiv:1607.04347v2, 2016-07-15 / 2017-11-26） |
| `arxiv-1803.09939.pdf` | An Empirical Study of Fault Localization Families and Their Combinations | Daming Zou; Jingjing Liang; Yingfei Xiong; Michael D. Ernst; Lu Zhang | https://arxiv.org/pdf/1803.09939 | 1195596 | 02ce657a2712 | 16 | 有效（arXiv:1803.09939v2） |
| `arxiv-2101.03008.pdf` | Locating Faults with Program Slicing: An Empirical Analysis | Ezekiel Soremekun; Lukas Kirschner; Marcel Böhme; Andreas Zeller | https://arxiv.org/pdf/2101.03008 | 2016072 | 380e8c9ca138 | 50 | 有效（arXiv:2101.03008v1, 2021-01-08） |
| `arxiv-2502.18664.pdf` | How Execution Features Relate to Failures: An Empirical Study and Diagnosis Approach | Marius Smytzek; Martin Eberlein; Lars Grunske; Andreas Zeller | https://arxiv.org/pdf/2502.18664 | 1002931 | 4b3f56783e6c | 25 | 有效（arXiv:2502.18664v1, 2025-02） |
| `arxiv-1907.05620.pdf` | iFixR: Bug Report driven Program Repair | Anil Koyuncu; Kui Liu; Tegawendé F. Bissyandé; Dongsun Kim; Martin Monperrus; Jacques Klein; Yves Le Traon | https://arxiv.org/pdf/1907.05620 | 2146033 | d29c4c74bfcb | 12 | 有效（arXiv:1907.05620v1, 2019-07） |
| `arxiv-2301.03270.pdf` | A Survey of Learning-based Automated Program Repair | Quanjun Zhang; Chunrong Fang; Yuxiang Ma; Weisong Sun; Zhenyu Chen; 等 | https://arxiv.org/pdf/2301.03270 | 2949930 | c62b8bf79768 | 69 | 有效（arXiv:2301.03270v3） |
| `arxiv-2506.23749.pdf` | A Survey of LLM-based Software Repair: Taxonomies, Design Paradigms, and Applications | Boyang Yang; Zijian Cai; Fengling Liu; Bach Le; Lingming Zhang; Tegawendé F. Bissyandé; Yang Liu; Haoye Tian | https://arxiv.org/pdf/2506.23749 | 2203199 | fad6c0ce8729 | 52 | 有效（arXiv:2506.23749v3, 2025-06） |
| `agentless.pdf` | Agentless: Demystifying LLM-based Software Engineering Agents | Chunqiu Steven Xia; Yinlin Deng; Soren Dunn; Lingming Zhang | https://arxiv.org/pdf/2407.01489 | 1384716 | 1675c2dcd5ec | 25 | 有效（arXiv:2407.01489v2；复用既有副本） |
| `swe-agent.pdf` | SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering | John Yang; Carlos E. Jimenez; Alexander Wettig; Kilian Lieret; Shunyu Yao; Karthik Narasimhan; Ofir Press | https://arxiv.org/pdf/2405.15793 | 4963538 | d171e0693060 | 118 | 有效（arXiv:2405.15793v3；复用既有副本） |
| `arxiv-2404.05427.pdf` | AutoCodeRover: Autonomous Program Improvement | Yuntong Zhang; Haifeng Ruan; Zhiyu Fan; Abhik Roychoudhury | https://arxiv.org/pdf/2404.05427 | 1580568 | b1f6a5942947 | 13 | 有效（arXiv:2404.05427v3） |
| `arxiv-2504.21798.pdf` | SWE-smith: Scaling Data for Software Engineering Agents | John Yang; Kilian Lieret; Carlos E. Jimenez; Alexander Wettig; Kabir Khandpur; Yanzhe Zhang; Binyuan Hui; Ofir Press; Lu ... | https://arxiv.org/pdf/2504.21798 | 3613659 | 6752df853569 | 46 | 有效（arXiv:2504.21798v2） |
| `luo-fse2014-flaky-tests.pdf` | An Empirical Analysis of Flaky Tests | Qingzhou Luo; Farah Hariri; Lamyaa Eloussi; Darko Marinov | https://mir.cs.illinois.edu/lamyaa/publications/fse14.pdf | 250151 | 36abbab3e917 | 11 | 有效（FSE 2014, DOI 10.1145/2635868.2635920） |
| `chen-csur2018-metamorphic-testing.pdf` | Metamorphic Testing: A Review of Challenges and Opportunities | Tsong Yueh Chen; Fei-Ching Kuo; Huai Liu; Pak-Lok Poon; Dave Towey; T. H. Tse; Zhi Quan Zhou | https://homes.cs.washington.edu/~rjust/courses/CSE503/2021_02_12-reading2.pdf | 351596 | 530361c287c8 | 27 | 有效（ACM CSUR 51(1) Art.4, DOI 10.1145/3143561） |
| `papadakis-advcom2019-mutation-survey.pdf` | Mutation Testing Advances: An Analysis and Survey | Mike Papadakis; Marinos Kintis; Jie Zhang; Yue Jia; Yves Le Traon; Mark Harman | https://mpapad.github.io/publications/pdfs/MutationSurvey2019.pdf | 1129278 | 63b7bfca877c | 153 | 有效（Adv. Comput. 112:275-378, DOI 10.1016/bs.adcom.2018.03.015） |
| `arxiv-2310.06770.pdf` | SWE-bench: Can Language Models Resolve Real-World GitHub Issues? | Carlos E. Jimenez; John Yang; Alexander Wettig; Shunyu Yao; Kexin Pei; Ofir Press; Karthik Narasimhan | https://arxiv.org/pdf/2310.06770 | 4533722 | f7e8e1df6412 | 52 | 有效（arXiv:2310.06770v3；ICLR 2024 会议版） |
| `swe-bench-solved-issues-really-solved.pdf` | Are “Solved Issues” in SWE-bench Really Solved Correctly? An Empirical Study | You Wang; Michael Pradel; Zhongxin Liu | https://arxiv.org/pdf/2503.15223 | 1045458 | b2db368d3c96 | 13 | 有效（arXiv:2503.15223v2, DOI 10.1145/3744916.3764576；复用既有副本） |
| `arxiv-2504.02605.pdf` | Multi-SWE-bench: A Multilingual Benchmark for Issue Resolving | Daoguang Zan; Zhirong Huang; Wei Liu; Hanwu Chen; Linhao Zhang; Shulin Xin; Lu Chen; Qi Liu; Xiaojian Zhong; Aoyan Li; Siyao Liu; Yongsheng Xiao; Liangqiang Chen; Yuyu Zhang; Jing Su; Tianyu Liu; Rui Long; Kai Shen; Liang Xiang | https://arxiv.org/pdf/2504.02605 | 7042084 | 4de921d8d88a | 32 | 有效（arXiv:2504.02605v1, 2025-04-03；首次超时断流，用 `curl -C -` 续传后校验通过） |
| `arxiv-2504.08703.pdf` | SWE-PolyBench: A multi-language benchmark for repository level evaluation of coding agents | Muhammad Shihab Rashid; Christian Bock; Yuan Zhuang; Alexander Buchholz; Tim Esler; Simon Valentin; Luca Franceschi; ... | https://arxiv.org/pdf/2504.08703 | 766656 | 0aa5166d646f | 20 | 有效（arXiv:2504.08703v3） |
| `arxiv-2410.03859.pdf` | SWE-bench Multimodal: Do AI Systems Generalize to Visual Software Domains? | John Yang; Carlos E. Jimenez; Alex L. Zhang; Kilian Lieret; Joyce Yang; Xindi Wu; Ofir Press; Niklas Muennighoff; Gabriel Synnaeve; Karthik R. Nar... | https://arxiv.org/pdf/2410.03859 | 4379827 | 4fa09c373454 | 36 | 有效（arXiv:2410.03859v1） |
| `arxiv-2502.12115.pdf` | SWE-Lancer: Can Frontier LLMs Earn $1 Million from Real-World Freelance Software Engineering? | Samuel Miserendino; Michele Wang; Tejal Patwardhan; Johannes Heidecke | https://arxiv.org/pdf/2502.12115 | 3265247 | 5592089e626e | 39 | 有效（arXiv:2502.12115v4） |
| `arxiv-2601.11868.pdf` | Terminal-Bench: Benchmarking Agents on Hard, Realistic Tasks in Command Line Interfaces | Mike A. Merrill; Alexander G. Shaw; Nicholas Carlini; Boxuan Li; Harsh Raj; Ivan Bercovich; Lin Shi; Jeong Yeon Shin; Thomas Walshe; ... | https://arxiv.org/pdf/2601.11868 | 2773926 | 4430e04a507b | 84 | 有效（arXiv:2601.11868v1） |
| `arxiv-2607.07593.pdf` | What Makes a Good Bug Report for an AI Agent? | Lara Khatib; Noble Saji Mathews; Meiyappan Nagappan; Pengyu Nie; Thomas Zimmermann | https://arxiv.org/pdf/2607.07593 | 256413 | 577a1285a197 | 12 | 有效（arXiv:2607.07593v1） |
| `mast-why-do-multi-agent-llm-systems-fail.pdf` | Why Do Multi-Agent LLM Systems Fail? | Mert Cemri; Melissa Z. Pan; Shuyi Yang; Lakshya A. Agrawal; Bhavya Chopra; Rishabh Tiwari; Kurt Keutzer; Aditya Parameswaran; Dan Klein; Kannan Ramchandran; Matei Zaharia; Joseph E. Gonzalez; Ion Stoica | https://arxiv.org/pdf/2503.13657 | 1188307 | 1b9e317a2a42 | — | 有效 PDF，47 页（arXiv:2503.13657v3） |
| `sherloc.pdf` | SHERLOC: Structured Diagnostic Localization for Code Repair Agents | Hovhannes Tamoyan; Sean Narenthiran; Erik Arakelyan; Mira Mezini; Boris Ginsburg | https://arxiv.org/pdf/2606.24820 | 1642045 | 862b3137f088 | — | 有效 PDF，31 页（arXiv:2606.24820v2，EMNLP 2026 Main） |
| `when-agents-coordinate.html` | When Agents Coordinate: Measuring Coordination in Multi-Agent AI Coding | Giuseppe Destefanis; Tomaso Aste | https://arxiv.org/abs/2608.16801（HTML 全文） | 317805 | 559d259904e8 | — | 有效 arXiv HTML（arXiv:2608.16801v1） |
| `nature-capable-language-models-outgrow-benefits-of-collaboration.html` | Capable language models can outgrow the benefits of collaboration | （Nature Machine Intelligence） | https://www.nature.com/articles/s42256-026-01268-y | 469829 | 5591658748c1 | — | 有效 Nature HTML |
| `anthropic-building-effective-agents.html` | Building effective agents | Anthropic | https://www.anthropic.com/engineering/building-effective-agents | 212195 | 8a320f1e7509 | — | 有效 HTML |
| `anthropic-multi-agent-research-system.html` | How we built our multi-agent research system | Anthropic | https://www.anthropic.com/engineering/multi-agent-research-system | 205585 | 09b4f697fad3 | — | 有效 HTML |
| `anthropic-demystifying-evals-for-ai-agents.html` | Demystifying evals for AI agents | Anthropic | https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents | 304431 | d191d9e9a31e | — | 有效 HTML |

## 20. 未获取与跳过清单

### 20.1 去重跳过（目录中已有同 ID/同内容，未重复下载）

| 目标 | 跳过原因 | 已有文件 |
|---|---|---|
| `evirca-microservice-rca.pdf` | SKIP-dup-name | 同上（已在目录中） |
| `survey-llm-issue-resolution.pdf` | SKIP-dup-name | 同上（已在目录中） |
| `survey-llm4apr-slr-tosem.pdf` | SKIP-dup-name | 同上（已在目录中） |
| `arxiv-2512.22256.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `agentic-software-issue-resolution-with-large-language-models-a.pdf` |
| `arxiv-2607.01788.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `krca-hyper-scale-microservice-rca.pdf` |
| `arxiv-2607.05197.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `repair-loop-iteration-limits.pdf` |
| `arxiv-2607.13206.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `why-not-fix-it-once-and-for-all-an.pdf` |
| `arxiv-2608.08968.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `gala-graph-rca-incident-response.pdf` |
| `arxiv-2608.15579.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `kozuchi-agent-software-repair.pdf` |
| `arxiv-2608.17671.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `benchmarking-automated-security-patch-backporting-how-far-are-we.pdf` |
| `arxiv-2609.07224.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `one-is-not-enough-the-untold-story-of-multiple.pdf` |
| `arxiv-2609.28896.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `specification-driven-benchmarking-apr.pdf` |
| `arxiv-2609.37864.pdf` | SKIP-dup-content（sha256 与批次 2 完全相同，本批次文件已删除） | `agentbug-smith-harness-bugs.pdf` |
| `arxiv-2606.26978.pdf` | SKIP-dup-id（同 ID 已在目录中） | 同上（已在目录中） |
| `arxiv-2607.25873.pdf` | SKIP-dup-id（同 ID 已在目录中） | 同上（已在目录中） |
| `arxiv-2607.26591.pdf` | SKIP-dup-id（同 ID 已在目录中） | 同上（已在目录中） |
| `arxiv-2607.17286.pdf` | SKIP-dup-id（同 ID 已在目录中） | 同上（已在目录中） |

### 20.2 下载/校验失败（文件已删除，不保留占位）

| 目标 | 原因 | 观测到的首页内容 |
|---|---|---|
| `classic-le-overfitting-semantics-2018.pdf` | FAIL-pages 1 |  |
| `classic-xuan-ranking-icsme2014.pdf` | FAIL-not-pdf HTML document text, ASCII text, with very long lines (9358) |  |

### 20.3 受限来源造成的已知缺口（URL 存在但本沙箱无法获取，非笔误）

| 目标 | 受阻原因 |
|---|---|
| Google SRE Book / Workbook（postmortem culture、effective troubleshooting 等章节） | `sre.google` 及全部 Google 域在本沙箱不可达（连接超时），非 URL 失效 |
| DORA 报告 PDF（services.google.com/fh/files/...） | 同上；已用 `dora.dev` 落地页替代 |
| Netflix Tech Blog / OpenAI / ASQ / NASA-NRC 故障树手册 | Cloudflare 403 / 反爬；已用 PagerDuty、Atlassian、incident.io、Lean 5 Whys 等替代 |
| Jones & Harrold 2005 Tarantula、Wong DStar、Abreu ASE 2009、Naish 2006 | ACM/IEEE 付费墙，无合法开放版本（已用 Abreu 2007、Wong TR、Sarhan 2022 综述替代） |
| PAR — Kim et al. ICSE 2013 | dl.acm.org 403，未见作者/机构镜像 |
| Gazzola et al. *Automatic Software Repair: A Survey*（TSE 2019） | IEEE 付费墙；unimib 机构库被 Cloudflare 403 |
| Zeller & Hildebrandt TSE 2002 / Cleve & Zeller ICSE 2005 | Saarland 主机 TCP 超时，ACM 403；仅 ISSTA'00 讲稿可获取 |
| McKeeman 1998 差分测试原始文献 | hpl.hp.com 已下线，bitsavers 整期扫描需浏览器 UA 且 ~2KB/s |
| Rothermel & Harrold 回归测试选择系列（TSE'96/TOSEM'97/TSE'01） | IEEE/ACM 403，无开放副本 |
| Agans《Debugging》/ Zeller《Why Programs Fail》 | 商业出版书籍，无合法免费全文 |
| Le et al. *Overfitting in Semantics-based APR* 全文（EMSE） | Springer 付费墙；仅 2 页 ISSTA journal-first 摘要免费（1 页，未达本目录 ≥2 页门槛，已删除） |
| Xuan & Monperrus ICSME 2014 排序集成 FL | HAL 返回 JS 挑战页而非 PDF；作者站点 404 |

### 20.4 跨目录重复说明

本目录与 `../../multi-repo-bugfix/research/` 存在 **11 份内容完全相同**的文件，
全部继承自 2026-10-08 批次（两目录当时各自保留了一份副本），**不是本次下载引入的**。
本次新增的 257 份原文在下载前已按文件名、arXiv ID、sha256 三重去重，并显式排除兄弟目录已持有的 7 个 arXiv ID，
因此新增文件与兄弟目录 **零重复**。

## 21. 覆盖度自查

| 家族 | 本目录已覆盖 | 仍缺口（受限来源，见 20.3） |
|---|---|---|
| A 调试理论与过程 | Zeller delta debugging（ESEC'99）、Whyline 提问式调试（CHI'04/ICSE'08）、专业调试扎根理论（FSE'26）、WDD/ProbDD（ICSE'25）、git bisect 理论分析、Tip 程序切片综述（1994）、动态切片复杂度 | Agans《Debugging: The 9 Indispensable Rules》、Zeller《Why Programs Fail》（商业书籍） |
| B 故障定位 | SBFL 相似度系数精度（Abreu'07）、SBFL 挑战综述（Sarhan'22）、Wong FL 综述、无 oracle 的 SBFL、FLUCCS/DeepFL/TRANSFER、多故障 SBFL、PredFL、变量级 FL、AgentFL、多 agent 图检索 FL、执行特征 SFL、FL 上下文对照、测试驱动定位、内核/Dafny 定位 | Tarantula（Jones & Harrold 2005）、DStar、Abreu ASE'09 —— 均无合法开放版本 |
| C 生产系统根因分析 | EviRCA、GALA、KRCA、自演化 harness、轨迹级微服务 RCA、RCA 失败分解、LongRCA、Cloud-OpsBench、Meta DrP、Holmes、KernelDiag、ORCA、图结构是否有效的对照研究 | 部分工业 RCA 平台文章为付费/受限来源 |
| D 自动程序修复 | GenProg（ICSE'09 / TSE'12）、SPR（FSE'15）、Prophet（POPL'16）、Genesis（FSE'17）、FixMiner、SimFix、Repairnator、Monperrus 书目（CSUR'18）、LLM4APR 系统综述、Issue Resolution 综述，以及 26 篇 2026 年修复方法 | PAR（Kim et al. ICSE 2013）、Gazzola TSE'19 综述（付费墙） |
| E Agent 化修复与 Harness | Agentic Issue Resolution 综述、Test-Driven SE 综述、AI Harness Engineering、Meta-Engineering Harnesses、停止准则研究、VeriHarness 结构化反馈、STAIR 轨迹复用、AdaRepair-Mem、SWE-Doctor、FC-SWE、CPG+时序图修复、多 hunk 协同 | — |
| F 测试与验证 | QuickCheck、Csmith 差分测试、模糊测试综述 + AFLFast + AFLGo、oracle 问题综述、RTS 综述、测试研究回顾、PBT 工业实践、单元测试 SLR、oracle 分类 SLR、蜕变↔LLM 综述、flaky 修复/检测、复现测试生成、补丁正确性评估 | Rothermel & Harrold 原始 TSE 论文、McKeeman 1998 差分测试原文 |
| G 安全缺陷修复 | AVR SoK ×2、漏洞检测 SLR ×2、PatchBench、Vul4Py、漏洞补丁基准可靠性审计、多补丁与修复完整性、指标失效研究、崩溃报告工业修复 | — |
| H 评测与元评估 | SWE-bench Pro / Live / Verified、SWE-Bench Illusion、测试过拟合、未获通过的 pass、排行榜饱和、基准错位立场论文、TestJack 基准审计、实验设置元研究、失败模式与轨迹分类法 | SWE-bench Verified 官方公告（openai.com 403） |
| I 工业实践与交付 | Google 规模低延迟 agentic 修复、Meta DrP/DRS/ACH/AutoPatchBench/JIT 测试、GitHub Copilot Autofix（含 agentic）、Uber uReview、Cloudflare AI 审查、Anthropic/微软调试工作流、Postmortem 体系（PagerDuty/Atlassian/incident.io/Datadog/Grafana/Honeycomb/Cook）、DORA、灰度与回滚、混沌工程、ODC、NIST SSDF、CWE Top 25 | Google SRE 书章节、Netflix 博客、NASA/NRC 故障树手册（本沙箱网络受限） |
| J 调试基础设施 | eBPF 追踪、Pyroscope 连续 profiling、AddressSanitizer、Google sanitizers、WinDbg 时间旅行调试、rr record-replay、Antithesis 确定性仿真 | — |


## 22. 附录：2026-10-08 批次 README 的原始「未获取清单」与「覆盖度自查」（原文保留，便于追溯）

> 上一版 README 的 §1–4 表格已作为第 19 节保留；以下是其 §5–§6 原文，未作改写。本批次的缺口见第 20 节。

### 5. 未获取清单（含原因）

| 目标 | 原因 | 处置 |
|---|---|---|
| Michael T. Nygard, *My Philosophy of Debugging* | `https://norc.com/pdf/PhilosophyOfDebugging.pdf` 返回 HTML 错误页（195 字节）；`https://www.norc.com/philosophyOfDebugging` 因自签证书被 `curl` 拒绝 | 已删除占位文件；正文按【未核实】处理，仅作线索，不给量化论断 |
| Kochhar, Wong, Sinha 等，*Practitioners' Expectations on Automated Fault Localization*（ICSE 2006） | `dl.acm.org/ft_gateway.cfm?id=2931051&type=pdf` 返回 **HTTP 403**（ACM 反爬） | 未获取；本文不引用其具体数字 |
| Stephen G. Clark & Richard Zarembka 的 ACM TOCS 级 debugging survey | 两轮不同措辞检索（`dl.acm.org` 限定 + 通用）均未命中；DBLP TOCS 卷 11 目录（mail.vldb.org/dblp）逐条核对后**未发现该论文** | 判定为**原始引用记忆有误**，全文不引用；见 `../debug-theory-and-fault-localization.md` §1.1 更正说明 |
| DBLP / Semantic Scholar 题录核对 | `dblp.org` 触发 Anubis 反爬（"Making sure you're not a bot"）；`dblp.org/search/publ/api` 与 `api.semanticscholar.org` 连续返回 **HTTP 429** | 改用 arXiv 官方 export API + ACM DL 检索结果页 + 期刊页做题录核对 |
| OpenAI, *Orchestration and handoffs* | `developers.openai.com` 返回 **HTTP 403**（与既有 `docs/multi-repo-bugfix/research/README.md` 记录一致） | 未获取；本文不引用其具体表述 |
| OpenAI, *Evaluate agent workflows* | 同上 | 未获取；本文不引用其具体表述 |
| `agentasseval-tracing-framework.pdf`（继承自既有 research 目录） | **校验失败**：首页文本为 *"Instability of the ferromagnetic phase in an Ising spin glass with correlated disorder"*（H. Nishimori 等凝聚态物理论文），与文件名/主题完全无关 | **已删除该文件**，不得再以论文名入库；如需该主题请重新检索后另存 |
| `arxiv-2504.02605.pdf` 首次下载 | `curl` 150s 超时（收到 6,235,385 / 7,042,084 字节），首版文件解析失败（`Stream has ended unexpectedly`） | 已用 `curl -C -` 续传并重新校验通过（32 页，首页标题匹配） |

### 6. 覆盖度自查（上一版）

| 层次 | 已获取原文 | 未覆盖且已在正文标注 |
|---|---|---|
| 1 调试理论与过程 | delta debugging（Zeller 1999）、SFL 综述（de Souza 2017）、execution-feature FL（Smytzek 2025） | Nygard《My Philosophy of Debugging》、Clark & Zarembka TOCS 综述、Just/Kapfhammer/Zeller 测试有效性论断、bisect 原始文献、Kernighan/Weinberg/Brooks 二手文献 |
| 2 故障定位 | de Souza 2017、Zou 2019、Soremekun 2021、Smytzek 2025 | Ochiai & Ochrimka 2004 原文、DStar (Kim et al. 2008) 原文、Kochhar 2006 原文、Bavota 栈追踪/日志 FL 原文、因果推断式 FL 专文 |
| 3 自动程序修复 | iFixR 2019、两篇 APR 综述、Agentless、SWE-agent、AutoCodeRover、SWE-smith | GenProg / SPR / RepairLMS / PAR / SimFix / FixMiner 原文（**仅作二级引用**）；Qi 2015、Zeh 2019、Smith 2015 原文 |
| 4 测试与验证 | Luo 2014 flaky、Chen 2018 metamorphic、Papadakis 2019 mutation、Wang/Pradel/Liu 2025 | 回归测试选择（Rothermel & Harrold 2004）、差分测试、属性测试原文 |
| 5 Benchmark 与评测 | SWE-bench、SWE-bench Multimodal、SWE-PolyBench、Multi-SWE-bench、SWE-Lancer、Terminal-Bench、Khatib 2026 | SWE-bench Verified 官方公告页、SWE-bench Pro、SWE-bench Live |
| 6 Agent 工程 | MAST、SHERLOC、When Agents Coordinate、Nature MI、Anthropic ×3 | OpenAI 两篇工程文章（403） |

> 说明：凡标注「仅作二级引用」的条目，其书目信息来自本文已获取原文的参考文献表（首次出现处逐字转录），**未经原始出版页独立核实**，因此不进入 `../claims-table.md` 的量化论断列，仅出现在脉络叙述中并显式标注二级来源。

> **本批次（2026-10-10）已补齐上述「第 3 层/第 4 层/第 5 层」多处缺口**：GenProg（ICSE'09/TSE'12）、SPR、Prophet、Genesis、FixMiner、SimFix、Repairnator、Smith 2015、Qi 2015、Rothermel & Harrold 综述、QuickCheck、差分测试（Csmith）、SWE-bench Pro/Live/Verified 等均已落盘。
> 统计：批次 2 成功落盘 **257** 份；去重跳过 3 项；失败并删除 2 项。
> 生成时间：2026-10-10 13:21（本机时间）。

## 23. 批次 3（2026-10-10 二次检索）新增原文

> 本批次为 2026-10-10 在批次 2 之后的**二次增量检索**：用 OpenAlex 全库（program repair / agentic repair / fault localization / test oracle / bug reproduction / patch correctness / vuln repair / bisection / SE-agent 工程 等 18 组查询）+ arXiv API 复核，抓取 2025-06 → 2026-10 的最新工作。
> 入库纪律：arXiv ID（文件名）+ 内容 sha256 双重去重；10 份与批次 2 文件字节完全相同者、4 份同 ID 已在库者一律不入库（见 20.1）。
> 校验：`file(1)` + `pypdf` 首页文本词元重叠（阈值 0.6）+ 页数 + sha256；52 份全部通过（其中 1 份因 PDF 提取把标题连写导致 ov=0.556，已逐字人工确认标题一致）。
> 命名与批次 2 的家族编号（A–J）严格对齐，便于合并阅读。

### 23.1 家族 A · 调试理论与过程（2 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2610.02995.pdf` | BISCEPTER: Probability-Driven Bisection for Large-Scale System Software | https://arxiv.org/pdf/2610.02995 | 780,588 | 07b6dba49c33 | 11 | ov=1.000 |
| `arxiv-2506.23281.pdf` | On the Feasibility of Deduplicating Compiler Bugs with Bisection | https://arxiv.org/pdf/2506.23281 | 1,277,927 | d0e342e6877c | 23 | ov=1.000 |

### 23.2 家族 B · 故障定位（FL）（1 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2608.03558.pdf` | EffiHolmes: Differential Profiling-Guided Repository Level Time Inefficiency Fix Localization | https://arxiv.org/pdf/2608.03558 | 1,712,001 | 530deab0750d | 13 | ov=1.000 |

### 23.3 家族 C · 生产系统根因分析（RCA）（2 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2607.23169.pdf` | Bifrost: Empowering Pretrained Language Model with Fallibility Representation for Log-Based Fault Diagnosis | https://arxiv.org/pdf/2607.23169 | 3,486,428 | 42e8e630cbe6 | 13 | ov=1.000 |
| `arxiv-2603.25538.pdf` | ARMOR: A Robust Self-Supervised Framework for Root Cause Analysis in Microservices under Missing Modality | https://arxiv.org/pdf/2603.25538 | 1,285,068 | 4a3714bb89b3 | 13 | ov=1.000 |

### 23.4 家族 D · 自动程序修复（APR）范式（6 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2507.01827.pdf` | PSearch: Search-Based Patch Generation in the Era of LLM-Based Automated Program Repair | https://arxiv.org/pdf/2507.01827 | 1,662,672 | c7c84e19a424 | 13 | ov=1.000 |
| `arxiv-2608.10613.pdf` | CausalRepair: Bridging the Causality Gap in Large Language Model-Based Automated Program Repair via Dual-Slicing | https://arxiv.org/pdf/2608.10613 | 2,159,729 | 9976f0a10698 | 24 | ov=1.000 |
| `arxiv-2604.02647.pdf` | From Guessing to Seeing: Enhancing LLM-Based Program Repair via Trace-Guided Multi-strategy Debate | https://arxiv.org/pdf/2604.02647 | 2,689,417 | ed37cfd87472 | 13 | ov=1.000 |
| `arxiv-2604.17016.pdf` | HELO-APR: Enhancing Low-Resource Program Repair through Cross-Lingual Knowledge Transfer | https://arxiv.org/pdf/2604.17016 | 1,955,660 | 5f4991195536 | 21 | ov=1.000 |
| `arxiv-2606.21926.pdf` | A11YRepair: Bridging Web Accessibility Barriers via Knowledge-Enhanced Divide-and-Conquer Repair | https://arxiv.org/pdf/2606.21926 | 4,723,245 | 5357a9229446 | 13 | ov=1.000 |
| `arxiv-2609.01769.pdf` | From Silicon to Boot Code: Extending Automated Program Repair to Firmware-Layer Security Workarounds | https://arxiv.org/pdf/2609.01769 | 533,176 | c5a7601273ec | 8 | ov=1.000 |

### 23.5 家族 E · Agent 化修复与 Harness 工程（15 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2607.24604.pdf` | Looping Is Not Reliability: State-Bound Evidence and Typed Revision Contracts for Agentic Code Repair | https://arxiv.org/pdf/2607.24604 | 640,443 | ec24f428cd61 | 11 | ov=1.000 |
| `arxiv-2506.08311.pdf` | Understanding Automated Program Repair Agents through the Lens of Traceability: An Empirical Study | https://arxiv.org/pdf/2506.08311 | 1,127,033 | c1bafcfe04d2 | 23 | ov=1.000 |
| `arxiv-2602.18571.pdf` | Debug2Fix: Can Interactive Debugging Help Coding Agents Fix More Bugs? | https://arxiv.org/pdf/2602.18571 | 771,187 | cd48a6342690 | 11 | ov=1.000 |
| `arxiv-2605.08717.pdf` | Debugging the Debuggers: Failure-Anchored Structured Recovery for Software Engineering Agents | https://arxiv.org/pdf/2605.08717 | 1,932,703 | fae1609a4c38 | 12 | ov=1.000 |
| `arxiv-2608.05959.pdf` | AgentExecutor: Partial Code Execution via Agentic Context Generation | https://arxiv.org/pdf/2608.05959 | 2,208,394 | 401859de4e5c | 13 | ov=1.000 |
| `arxiv-2606.26979.pdf` | How Much Static Structure Do Code Agents Need? A Study of Deterministic Anchoring | https://arxiv.org/pdf/2606.26979 | 1,557,398 | b02068983dc5 | 21 | ov=1.000 |
| `arxiv-2609.36807.pdf` | XRepoSkill: Learning Transferable Skills for Software Engineering Agents | https://arxiv.org/pdf/2609.36807 | 668,742 | 250e814c2548 | 16 | ov=1.000 |
| `arxiv-2609.33243.pdf` | CodeSkill: Latent Skill Abstraction for Long-Horizon Code Agents | https://arxiv.org/pdf/2609.33243 | 2,563,274 | 1c146b0394af | 15 | ov=1.000 |
| `arxiv-2609.23377.pdf` | One to More, More to One: Category-Aware Iterative Expert Training for Software Engineering Agents | https://arxiv.org/pdf/2609.23377 | 9,303,153 | 4216b8752e05 | 44 | ov=1.000 |
| `arxiv-2609.33875.pdf` | Counterfactual Rollout Replay: Forkable Environments as Free Process Rewards for Software Engineering Agents | https://arxiv.org/pdf/2609.33875 | 727,002 | c931f02f382d | 35 | ov=1.000 |
| `arxiv-2609.32631.pdf` | SWE-MILE: Asynchronous Potential-Induced Milestone Credit Assignment for Long-Horizon Software Engineering Agents | https://arxiv.org/pdf/2609.32631 | 1,482,049 | 764b73b0f573 | 23 | ov=1.000 |
| `arxiv-2609.35741.pdf` | Shockingly Simple Self-retrospection Improves Agentic Models Without RL | https://arxiv.org/pdf/2609.35741 | 930,993 | 98becce8a0dc | 60 | ov=0.556+人工确认 |
| `arxiv-2603.28119.pdf` | Compressing Code Context for LLM-based Issue Resolution | https://arxiv.org/pdf/2603.28119 | 1,576,250 | 9a7e628ae6a4 | 12 | ov=1.000 |
| `arxiv-2610.01207.pdf` | Dependency-Aware Reward Shaping for Agentic Reinforcement Learning | https://arxiv.org/pdf/2610.01207 | 1,450,743 | c61baa22025e | 39 | ov=1.000 |
| `arxiv-2610.03010.pdf` | Engineering Sustainable Agents: A Systematic Comparison of Agentic LLMs for Developer Workflows | https://arxiv.org/pdf/2610.03010 | 1,193,975 | c5fea5763737 | 50 | ov=1.000 |

### 23.6 家族 F · 测试与验证方法论（11 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2608.05917.pdf` | Escaping the Self-Repair Trap: Improving Test Oracle Generation via Dual-Context Awareness | https://arxiv.org/pdf/2608.05917 | 932,010 | 78878011d65f | 13 | ov=1.000 |
| `arxiv-2604.01518.pdf` | Probe to Generate: Program Variant-Guided Test Augmentation for Repository-Level Repair Benchmarks | https://arxiv.org/pdf/2604.01518 | 1,387,798 | 61c6f0286b44 | 13 | ov=1.000 |
| `arxiv-2607.23963.pdf` | RESTOR: Automated Test Oracle Generation for RESTful APIs via Reinforcement Learning | https://arxiv.org/pdf/2607.23963 | 876,571 | 35b3402277f7 | 22 | ov=1.000 |
| `arxiv-2607.22883.pdf` | Evaluating and Mitigating the Misguidance Effect of Buggy Code in LLM-Generated Unit Tests | https://arxiv.org/pdf/2607.22883 | 1,470,939 | 87a6e17ab6fa | 24 | ov=1.000 |
| `arxiv-2605.21677.pdf` | A Dataset of Reproducible Flaky-Test Failures | https://arxiv.org/pdf/2605.21677 | 1,447,781 | 330ae58d2149 | 20 | ov=1.000 |
| `arxiv-2609.25516.pdf` | The Vocabulary of Flaky Tests in Swift | https://arxiv.org/pdf/2609.25516 | 578,929 | 7c16ec1caec0 | 10 | ov=1.000 |
| `arxiv-2608.00884.pdf` | Documentation vs. Code Patterns: What Drives LLM-Based Exception Oracle Generation? | https://arxiv.org/pdf/2608.00884 | 637,910 | dfa1c6bd4b8e | 12 | ov=1.000 |
| `arxiv-2609.35834.pdf` | A Leakage-Safe, Cost-Aware Regression Testing Methodology for the Quantum Transpiler | https://arxiv.org/pdf/2609.35834 | 935,551 | 6c98a3ddf8c1 | 25 | ov=1.000 |
| `arxiv-2602.03181.pdf` | Synthesizing File-Level Data for Unit Test Generation with Chain-of-Thoughts via Self-Debugging | https://arxiv.org/pdf/2602.03181 | 840,494 | bd3c65597daa | 21 | ov=1.000 |
| `arxiv-2609.34450.pdf` | ReproBench: Benchmarking LLM Agents on Reproducing Vulnerability From Scratch | https://arxiv.org/pdf/2609.34450 | 3,538,497 | 9e4b1a83bcf6 | 15 | ov=1.000 |
| `arxiv-2609.34752.pdf` | Multi-SWT-Bench: A Multilingual Benchmark for Reproduction Test Generation | https://arxiv.org/pdf/2609.34752 | 491,489 | 9faf833c405a | 23 | ov=1.000 |

### 23.7 家族 G · 安全缺陷修复（5 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2608.03134.pdf` | CLEAR: Causal Context-Based Agentic Reasoning for Vulnerability Detection | https://arxiv.org/pdf/2608.03134 | 9,971,857 | 253c16608280 | 13 | ov=1.000 |
| `arxiv-2601.22952.pdf` | Sifting the Noise: A Comparative Study of LLM Agents in Vulnerability False Positive Filtering | https://arxiv.org/pdf/2601.22952 | 1,028,846 | ed09e8edaeed | 24 | ov=1.000 |
| `arxiv-2605.13138.pdf` | A Comprehensive Evaluation of Code Language Models for Security Patch Detection | https://arxiv.org/pdf/2605.13138 | 5,679,020 | 729578a188da | 13 | ov=1.000 |
| `arxiv-2407.02395.pdf` | Toward Secure Code Generation: Bridging Correctness and Security via Task-Adaptive Vulnerability Modeling and Execution-Based Benchmarking | https://arxiv.org/pdf/2407.02395 | 5,880,076 | 90adfabc1264 | 22 | ov=1.000 |
| `arxiv-2609.33763.pdf` | SecProbe: Adaptive Evaluation of Coding Agents on Cybersecurity Vulnerabilities | https://arxiv.org/pdf/2609.33763 | 4,525,005 | 374e4d049acc | 27 | ov=1.000 |

### 23.8 家族 H · 评测与元评估（4 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2610.01618.pdf` | Agents Are Systems, Not Models: Rethinking Agentic Evaluation | https://arxiv.org/pdf/2610.01618 | 765,959 | 2d8c28b4e4b8 | 28 | ov=1.000 |
| `arxiv-2609.26826.pdf` | What Makes a Terminal-Bench Task Hard? Separating Genuine Hardness from Fake-Hardness on an Adjudicated Agentic Corpus | https://arxiv.org/pdf/2609.26826 | 491,117 | dcc186be588f | 8 | ov=1.000 |
| `arxiv-2607.28587.pdf` | PAIChecker: Uncovering and Checking PR-Issue Misalignment in SWE-Bench-Like Benchmarks | https://arxiv.org/pdf/2607.28587 | 1,440,559 | adb7b22c62f7 | 13 | ov=1.000 |
| `arxiv-2602.08866.pdf` | ArkEval: Benchmarking and Evaluating Automated Code Repair for ArkTS | https://arxiv.org/pdf/2602.08866 | 1,076,301 | 005a5a6919eb | 13 | ov=1.000 |

### 23.9 家族 I · 工业实践与交付方法论（4 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2603.05637.pdf` | Real Faults in Model Context Protocol (MCP) Software: a Comprehensive Taxonomy | https://arxiv.org/pdf/2603.05637 | 1,609,753 | 6fa224ad032f | 48 | ov=1.000 |
| `arxiv-2604.08906.pdf` | Understanding Bugs in Modern Agentic Frameworks: A Study of Symptoms, Root Causes, and Triggering Conditions | https://arxiv.org/pdf/2604.08906 | 961,596 | db773042ee90 | 12 | ov=1.000 |
| `arxiv-2607.16740.pdf` | Agentic Code Review in the Terminal: A Trajectory-Level Analysis of Behavior, Cost, and Human-Alignment | https://arxiv.org/pdf/2607.16740 | 581,445 | ffe638b2e3d5 | 5 | ov=1.000 |
| `arxiv-2605.30208.pdf` | Automating Low-Risk Code Review at Meta: RADAR, Risk Calibration, and Review Efficiency | https://arxiv.org/pdf/2605.30208 | 702,293 | d7f6d4efe25f | 11 | ov=1.000 |

### 23.10 家族 J · 大规模调试基础设施（2 份）

| 文件 | 标题（原文） | 来源 URL | 字节数 | sha256(12) | 页数 | 校验 |
|---|---|---|---|---|---|---|
| `arxiv-2603.29122.pdf` | ReLog: Execution-Aware Logging with Runtime Feedback for LLM-Oriented Debugging | https://arxiv.org/pdf/2603.29122 | 1,273,927 | 7ee8bdce00d2 | 13 | ov=1.000 |
| `arxiv-2607.06107.pdf` | DDB: Source-Level Interactive Debugging for Distributed Applications | https://arxiv.org/pdf/2607.06107 | 1,849,964 | 8972e7c06a74 | 22 | ov=1.000 |
