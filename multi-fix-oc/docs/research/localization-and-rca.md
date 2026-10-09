# 故障定位与运行时根因分析（2023–2026）

> 调研于 2026-10 完成。数字均引自一手来源；不确定项标注 **UNVERIFIED**。
> 本项目直接采纳的部分见每节末尾的「**对本项目**」。

## 1. LLM 源码定位

| 工作 | ID / 会议 | 方法 | 报告数字 |
| --- | --- | --- | --- |
| **LocAgent** | arXiv 2503.09089, ACL 2025 | 有向异构代码图（文件/类/函数；导入/调用/继承）+ 图索引工具 + 微调 Qwen2.5-Coder | file-level Acc@10 最高 **92.70%**；成本比商业模型低约 86%；下游 Pass@10 +12% |
| **OrcaLoca** | arXiv 2502.00350, ICML 2025 | 动作优先级调度 + 带相关性打分的动作分解 + 距离感知剪枝 | function-match **65.33%**，file-match 83.33%，SWE-bench Lite resolved 41.00%；较 Agentless-1.5 +6.33pp |
| **BugCerberus** | arXiv 2502.15292 | 三个按粒度分别微调的 LLM，分别处理 file/function/statement 级 IR | file Top-1 **0.651**、function **0.406**、statement **0.268**；接入 Agentless 后 +17.4%。消融：去掉文件级定位 → statement Top-5 **−94.3%** |
| **COSIL** | ASE 2025 (DOI 10.1109/ASE63991.2025.00249) | 动态 module→function 调用图 + pruner + reflection | Top-1 Lite 43.3% / Verified 44.6%（Qwen2.5-Coder-32B）；**平均超越 SOTA 96.04%** |
| **ToolTrain / RepoSearcher** | arXiv 2508.03012 | 拒绝采样 SFT 预热 → 工具集成 RL，奖励为规则化定位信号 | function Recall@5 **68.55%** @32B，超过 Claude-3.7 |
| **SweRank / SweRankMulti / SweRankAgent** | arXiv 2512.20482 | bi-encoder 检索 + listwise LLM 重排；再扩展为带记忆缓冲的多轮 agentic search | 多轮比单次高 **+3.1 ~ +6.4 Acc@1**；**查询改写基线反而更差** |
| **GraphLocator** | arXiv 2512.22469 | **因果 Issue 图（CIG）**：症状顶点 → 优先队列因果扩展 + 溯因推理；RDFS 层级图 + 懒加载 | function recall +19.49%，precision +11.89%，**下游解决率 +28.74%** |
| **Multi-CoLoR** | arXiv 2602.19407 | *Similar Issue Context*（组织历史检索）+ LocAgent-X（跨 C++/QML 统一依赖图），在 AMD 代码库（2,563 issue）上评测 | LocAgent-X 平均 **+16.1 Acc@5**；**仅 QML 场景 +29.1**（79.10% vs 50.00%）。历史上下文对 C++ 帮助最大，依赖图对 QML 帮助最大 |
| **Kept** | PACMSE(FSE) 2025, DOI 10.1145/3729356 | 由项目文档 + 历史代码构建知识图谱，经软位置嵌入与可见性矩阵注入 | 较 Locus +33.2–59.5%；较 CodeT5 +36.6–63.7%；较 `text-embedding-ada-002` +7.8–17.4%（7 个开源项目、6,000+ 报告） |
| **GREPO + GNN** | arXiv 2602.13921 | 在异构带时间索引仓图上学习 GNN | 所有 GNN 变体优于 IR/LLM 基线；注意力（GAT/GATv2）优于 GCN/GIN/SAGE |
| GraphRAG 家族 | CodexGraph / RepoGraph / RepoUnderstander·LingmaAgent（MCTS） | 上述工作共同比较的图引导基线 | — |

**对本项目**：BugCerberus 的消融是全篇最硬的一条设计依据——去掉文件级定位会损失 94.3% 的语句级 Top-5。这直接对应 `repo-fixer` 提示词里的「逐级收窄、每级记录候选集、不得跳级」。GraphLocator 的 +28.74% 则支持 `cross-repo-localization` 中「因果链优先于表面相似」的原则。Multi-CoLoR 的组织历史检索结论支持把 `topology.json` 与历史 issue 当作一等证据源。

## 2. 日志 / 链路 / 配置定位与根因分析

| 工作 | ID / 会议 | 方法 | 报告数字 |
| --- | --- | --- | --- |
| **OpenRCA** | ICLR 2025 | 335 次故障、68 GB 遥测；RCA-agent = Controller + Executor（程序合成与执行），顺序为 **metric → trace → log** | Claude 3.5：oracle 遥测 5.37%，均衡采样 3.88%，**RCA-agent 11.34%** |
| **RCLAgent** | arXiv 2508.20370 | 对专业 SRE 访谈提炼三条性质（**递归性、多维扩展、跨模态推理**）→ 多 agent recursion-of-thought + 协调者（初始推理 → 关键反思 → 最终复核） | **单次请求的 Recall@1 就超过 SOTA Recall@10 约 2–9%**；较同 Recall@1 基线 +30.44%；较 mABC +15.60%；group-ranking MRR +32.53% |
| **LATS-RCA** | Springer LNCS, DOI 10.1007/978-3-032-36590-3_14 | 反思引导的根因假设**树搜索** | LO2 上诊断准确率 **91.3%**（Sonnet 4.5 / GPT-5 / Gemini 3 Pro 均 89.7–91.3%）。**真实生产事故**（Zoner Oy，30 万+ 站点）**65.1%** |
| **ChatRCA** | ACM, DOI 10.1145/3842744 | 多 agent 分解（Manager + 专家），**在两个检查点设 human-in-the-loop**，3 名盲测运维工程师共识后仲裁 | 类别 Top-1：TrainTicket **91.11%** / CMCC 私有集 86.67% / GAIA 87.80% |
| **AetherLog** | ISSRE 2025 | 离线：LLM 抽取实体与关系 → 紧凑语义对齐**知识图谱**（embedding 聚类 + 归一化）。在线：日志摘要 → 检索相似 KG 实体 → 上下文增强 prompt → 因果链检索 | F1 **0.93 / 0.97**（+6% / +8%）。基线：LogRAG 0.87/0.89、LogPrompt 0.85/0.77、LogKG 0.48/0.50、LogRule 0.31/0.23。**关键诊断**：纯 LLM 会停在**症状**（"disk not ready"）而错过根因（`nvme timeout`），原因是时间近因偏置 |
| **MicroRCA-Agent** | arXiv 2509.15635（AIOps-25 决赛 Top-5） | Drain3 日志模板化 + 多级过滤；双链路异常检测（IsolationForest 时长 + 状态码）；两阶段 LLM 指标摘要；跨模态 LLM 推理并输出 `reasoning_trace` | 最终 **50.71**。消融：仅指标 42.78、仅链路 31.09、仅日志 23.59；**日志+指标 51.27（最佳）**，链路+指标 48.58，日志+链路 35.32 |
| **Sherlogs**（工程实践） | github.com/rohitraju1966/Sherlogs | Drain3 → DuckDB 双表 → LangGraph agent + 两个有界工具（`summarize(service?)`、`get_lines(template_id)`）；跳转预算；把每条错误分类为 **originating（崩溃源）vs relaying（指针转发）** 并沿链追踪 | RCAEval RE3（90 起事故、3 系统、7–47 服务）：**AC@1 92.2%、AC@3 100%、MRR 0.954**，单次调用基线 83.3% / 100% / 0.913 |
| **LogConfigLocalizer** | arXiv 2404.00640, ISSTA 2024 | 两阶段：异常识别（与无故障库做模板 diff）→ 异常推断（规则 + LLM 直接 + LLM 间接验证） | 5 工作负载 Hadoop 基准上平均准确率 **99.91%**；真实案例 93.94%（31/33） |
| **PAL / LogRCA / LogGPT / LogAgent** | 各自 | PAL ≈ 预训练 LM 做日志异常检测；**LogRCA ≈ 在日志+指标上用 PC/MCI 建因果图**；LogGPT ≈ GPT 微调日志；LogAgent ≈ 处理 256k token 日志文件 | **LogRCA 是该族最强经典基线**，也是要超越的对象 |
| **PreLog** | SIGMOD 2024 | 条目级 + 序列级预训练目标，prompt tuning | 注入 20% 日志不稳定下 F-measure **0.936–0.950**；16 个数据集中 9 个 GA 最优 |
| **LogFormer** | AAAI 2025 | 预训练 + adapter 微调 + **Log-Attention**（保留解析器丢弃的变量） | HDFS F1 **0.98**、BGL 0.99、Thunderbird 0.99；ChatGPT 基线 0.78/0.74/0.81。**诊断**：LLM 抓住 "Error"/"failed" 而忽略变量 |
| **LogLLaMA** | arXiv 2503.14849 | LLaMA2 在正常日志 key 上微调 + REINFORCE Top-K 奖励 | BGL F1 0.959、HDFS 0.894、Thunderbird 0.974 |

**对本项目**：AetherLog 的失败诊断（纯 LLM 停在症状、时间近因偏置）是 `cross-repo-verifier` 中「区分 originating 与 relaying」的来源，也是 `repo-router` 要求「先字面写下可观测现象、再解释」的原因。OpenRCA 的 metric→trace→log 顺序与 MicroRCA-Agent 的「日志+指标 优于 三模态全上」共同说明：**加模态不等于加信息**。Sherlogs 的 originating/relaying 分类可以直接搬到跨仓场景——网关是典型的 relaying 层，它报告的症状往往来自下游。

## 3. 多缺陷定位

- **Defects4J-mf / BugsInPy-mf**（arXiv 2403.19171）是唯一成熟的多缺陷**定位**资源：平均每版本 9.2 / 18.6 个缺陷，含移植的故障暴露测试与**平移后的故障位置**（`bug.locations.*`）。位置平移失败导致的丢弃率：Defects4J 0.3% vs **BugsInPy 14.3%**。
- **PDB-Multi** 组合 1–3 个经核验的原子缺陷（BigCodeBench + LiveCodeBench），在编辑级精度之外同时报 **bug 级召回**。
- **Tricky²**（FORGE2026, DOI 10.1145/3793655.3793709）扩展 TrickyBugs（3,043 个有缺陷程序 / 324 任务；1,361 修复 / 224 任务，C++/Python/Java），加入 GPT-5 与 OpenAI-oss-20b 注入错误，分 human-only / LLM-only / human+LLM 三档。
- **SWE-sweep**、**Active-SWE**、**ChainSWE** 都把多缺陷推到**任务**层面，而非定位层面。

## 4. 综合结论

1. **层级收窄是承重结构，不是顺带做法。** SWE-bench 项目平均 11,020 个函数、168,721 条语句（BugCerberus 给出），一个函数约 15 条语句。去掉文件级定位 → 语句级 Top-5 掉 94.3%。*设计：repo → 目录/模块 → 文件 → 类/函数 → 语句，后一级不得跳过后一级的候选集。*
2. **结构优于表面相似，且优势在训练分布之外更大。** LocAgent 92.70% file-level、OrcaLoca 65.33% function-match；Multi-CoLoR 在 C++/QML 上增益（+16.1 / +29.1 Acc@5）大于 Python。GREPO：可学习 GNN 在 47k 任务上优于 IR/LLM 基线。*这正是本项目用 `topology.json` 契约图而非文本相似度的原因。*
3. **SBFL / 遥测是搜索循环里的"提示"，不是答案。** AutoCodeRover 的 agent 最终采纳了 SBFL 排名第 3 和第 5 的可疑方法而非第 1，因为只有它们与 issue 文本相关。反过来，RCLAgent 用**单次**请求就超过 SOTA Recall@10，靠的是递归与交叉验证而非多次请求聚合。
4. **传统 FL 在真实噪声输入上失效，LLM 推理在因果上失效，两者都需要。** AetherLog 的诊断精确：纯 LLM 因时间近因偏置只认出症状（"disk not ready"）而错过根因（`nvme timeout`）；纯 KG 也失败，因为该模式不在抽取出的规则集里。组合后 F1 0.93/0.97。
5. **组织记忆是最被低估的定位信号。** Multi-CoLoR 的 Similar-Issue-Context 同时提升 Acc@5 并减少工具调用；Kept 把项目文档 + 历史代码做成知识图谱，相对 IR/LLM 基线 +33–63%；MULocBench 证明非代码构件也是合法定位目标。
6. **因果结构优于相似性。** GraphLocator 的显式因果图带来 +28.74% 下游收益；RCLAgent 的设计来自 SRE 访谈而非架构搜索。
7. **传统 + LLM 混合 > 任一单独，但 SBFL 是提示而非替代品**——这是 AutoCodeRover 的明确论证；MULocBench 则说明代码与非代码构件都要覆盖。
8. **指标体系影响巨大。** 文件级检索远易于节点级（SWE-PolyBench 的 CST 节点指标）；单测通过率掩盖大规模过度编辑（PDB）；定位正确是修复成功的必要但不充分条件。
9. **多模态运行时遥测与源码定位是两个不同问题**，各有基准且 SOTA 低得多（OpenRCA 11.34%；LATS-RCA 真实事故 65.1% vs LO2 上 91.3%）。

## 5. 与本项目设计的对应

| 研究结论 | 本项目实现 |
| --- | --- |
| 层级收窄不可跳级（BugCerberus −94.3%） | `repo-fixer` 步骤 2 强制 repo→module→file→function，输出 `NARROWING` 轨迹 |
| 结构优于文本相似 | `repo-router` 只读 `provides`/`consumes`/`contracts`，不 grep 代码 |
| 因果优于相似（GraphLocator +28.74%） | `cross-repo-localization` 的 symptom→entry point→contract 双向走法 |
| 纯 LLM 停在症状（AetherLog） | `repo-router` 步骤 1「先字面写下可观测现象」；verifier 区分 originating / relaying |
| 过度编辑不被主流指标惩罚（PDB） | `repo-fixer` 步骤 8 自查 diff 规模；`cross-repo-verifier` 的 `minimality` 字段 |
| 非代码构件是合法定位目标（MULocBench） | `topology.json` 的契约与配置作为一等证据源 |
| 多缺陷摧毁 agent 状态（ChainSWE −70%） | 每仓一个全新子会话，`steps` 上限，不共享历史 |
| 验证器质量决定上限（Carlini / Regehr） | 独立只读 `cross-repo-verifier`，`temperature: 0.0`，不得让 fixer 自评 |

## 6. 来源

**LLM 定位**：https://arxiv.org/abs/2503.09089（LocAgent）· https://aclanthology.org/2025.acl-long.426/ · https://github.com/gersteinlab/LocAgent · https://arxiv.org/abs/2502.00350（OrcaLoca）· https://proceedings.mlr.press/v267/yu25x.html · https://github.com/fishmingyu/OrcaLoca · https://arxiv.org/abs/2502.15292（BugCerberus）· https://github.com/carryCJM/BugCerberus · https://dlnext.acm.org/doi/10.1109/ASE63991.2025.00249（COSIL）· https://arxiv.org/abs/2508.03012（ToolTrain）· https://arxiv.org/abs/2512.20482（SweRank）· https://arxiv.org/abs/2512.22469（GraphLocator）· https://arxiv.org/abs/2602.19407（Multi-CoLoR）· https://dl.acm.org/doi/full/10.1145/3729356（Kept）· https://arxiv.org/abs/2602.13921（GREPO）

**RCA / 日志 / 链路**：https://proceedings.iclr.cc/paper_files/paper/2025/file/d29b8d53678015079e1d245c023e49d2-Paper-Conference.pdf（OpenRCA）· https://arxiv.org/abs/2508.20370（RCLAgent）· https://link.springer.com/chapter/10.1007/978-3-032-36590-3_14（LATS-RCA）· https://github.com/kottinov/lats-rca · https://dl.acm.org/doi/pdf/10.1145/3842744（ChatRCA）· https://wenweigu.github.io/publications/issre25/issre25-2.pdf（AetherLog）· https://arxiv.org/abs/2509.15635（MicroRCA-Agent）· https://challenge.aiops.cn（AIOps Challenge）· https://github.com/rohitraju1966/Sherlogs · https://arxiv.org/abs/2404.00640（LogConfigLocalizer）· https://github.com/shanshw/LogConfigLocalizer · https://github.com/LogIntelligence/PreLog · https://ojs.aaai.org/index.php/AAAI/article/download/27764/27569（LogFormer）· https://arxiv.org/abs/2503.14849（LogLLaMA）· https://logagent.dev/ · https://zeyang919.github.io/paper/LibreLog_extension.pdf

**多缺陷**：https://arxiv.org/abs/2403.19171（Defects4J-mf / BugsInPy-mf）· https://huggingface.co/datasets/Precise-Debugging-Benchmarking/PDB-Multi · https://dl.acm.org/doi/10.1145/3793655.3793709（Tricky²）