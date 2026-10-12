# 跨仓 / 多服务问题单定位方法论

> 范围：一套服务的多个仓库（前端、后端服务、数据库、网关、SDK）。现象在系统层，根因落在未知的一个或多个仓库。
> 引用纪律：每条论断后括注一手来源。凡本轮未能用权威页面打开核实的，一律标【未核实】且不进入结论。
>
> **证据边界**：【事实】论文/报告原文的量化结论；【推论】由事实导出的结构判断；【判断】本文给出的可落地操作建议；【未核实】未核实的来源。量化结论多在**注入故障的基准**上取得（如 MicroRCA 89% precision / 97% MAP 测于 Sock-shop 基准），**不可直接外推到开放世界的真实问题单**。

## 0. 为什么"多仓问题单"比"单仓 bug"难

系统层现象与代码根因之间有三重错位，Multi-SWE-bench 的实证支持这一点：

- **规模错位**。BeyondSWE 500 个实例的目标解平均触及 **10.9 个文件 / 1039.6 行**，显著超过 SWE-bench 类基准的修改规模（BeyondSWE §1）。
- **范围错位**。Multi-SWE-bench（NeurIPS 2025 版本，Daoguang Zan 等，arXiv 2504.02605，Tab. 4/Fig. 3）显示：**修改文件数增加时 resolved rate 显著下降**，三种框架（Agentless / SWE-agent / OpenHands）均如此。
- **知识错位**。BeyondSWE 把"知识范围"（信息能否只从目标仓恢复）与"解决范围"（局部修补 vs 仓级改造）作为两个设计维度，CrossRepo 子集即属于"必须依赖外部仓库信息"的类型。

这三点合起来意味着：**候选仓空间先要收缩，传播假设再要生成，最后才谈改哪一行。**

---

## 阶段 ① 候选仓空间收缩（issue 文本 → 症状归属 → 候选集）

### 可落地操作

1. **症状归属锚定**：从 issue 文本抽取"用户可见层"实体（页面、接口路径、错误码、事件名），先确定**症状落在哪个仓的边界上**。前端仓通常拥有最直接的症状文本（控制台报错、UI 状态），后端仓拥有指标与日志。
2. **契约面反查**：用接口契约（OpenAPI / proto / GraphQL schema）把"前端调用的符号"映射到"后端实现仓"。这一步不需要装服务，纯静态。
3. **分级候选集**：产出 `候选集 = {直接症状仓} ∪ {契约对端仓} ∪ {共享 SDK / 网关 / 配置仓}`，并给每个候选标注**证据等级**（症状直证 / 契约推断 / 拓扑推断）。

### 输入 / 输出

| 项 | 内容 |
|---|---|
| 输入 | issue 正文 + 复现描述、契约文件（`openapi.yaml` / `*.proto` / schema）、仓清单与 CODEOWNERS |
| 输出 | 带置信分级的候选仓列表；每个候选的"一句话症状归属理由" |

### 失效兜底

- **契约缺失/过期**：契约文件与实际实现漂移时，映射会静默漏掉真正的对端。兜底是**加一层运行时证据**（阶段③的 trace）反向校正，而不是相信契约。
- **SDK 未标版本**：若前端依赖的是未 pin 版本的内部 SDK，契约面无法闭合。兜底是退到"仓名 + 语言 + 发布节奏"的粗粒度分组，先做整仓级实验。
- **爆炸半径失控**：候选集超过 8–10 个仓时，阶段④的判别性实验成本会指数上升。此时必须**先切分批次**（按是否在关键路径上二分）。

### 文献依据

- MicroRCA 的失败边界论述直接支持这一步的必要性：既有第三类方法（构建因果图、沿图推因、以后端/前端相关性排序根因）**"may fail to identify faulty services that have little or no impact on front-end services"**（MicroRCA §I）。也就是说，**只看前端症状这一路信号会把"对前端影响很小的后端故障"直接漏掉**。因此阶段①的候选集**不能只由症状仓闭包生成**，必须显式补入"低前端影响面"的旁路服务（异步写入、批处理、缓存预热、SDK 内部路径）。
- CodeScaleBench 的 CSB-Org 子集给出同方向的量化证据：跨仓发现任务要求信息分布在 **3–20 个仓库**（Sourcegraph CodeScaleBench 技术报告 §任务设计）。纯前端症状闭包通常远小于这个跨度。

---

## 阶段 ② 契约 / 调用拓扑建模（依赖图、契约清单、版本矩阵）

### 可落地操作

1. **三层图分离**：把"能查证的依赖"拆成三张图，避免混为一谈：
   - **编译期图**（import / package / Bazel target）：最可靠，但只覆盖同语言同构建系统。
   - **契约图**（谁声明、谁消费）：跨语言、跨团队的最小公共接口。
   - **运行期图**（trace span、DB query、消息 topic）：覆盖动态依赖（反射、配置驱动、服务发现），但需要线上数据。
2. **契约清单化**：每条跨仓边必须落到一个**可 diff 的契约文件**上，而不是只记一条调用关系。
3. **版本矩阵**：记录 `消费方仓 × 契约版本 × 期望最低提供方版本` 三元组。这是阶段④判别性实验和阶段③假设生成的公共输入。

### 输入 / 输出

| 项 | 内容 |
|---|---|
| 输入 | 源码树、构建文件（`package.json` / `pom.xml` / `go.mod` / `MODULE.bazel`）、契约文件 |
| 输出 | 三张图 + 一张版本矩阵；每条边标注 `图类型 / 证据来源 / 是否可静态证明` |

### 失效兜底

- **动态语言/反射**：编译期图不完整时，必须用运行期图补；但运行期图受采样偏差影响，**未被采样到的边会被误判为"不存在"**。兜底是标记 `观测覆盖率` 而非宣称完备。
- **服务发现 / 配置**：DB schema 变更、消息 topic 变更常常既不在编译期图也不在 proto 里，只存在于 migration 脚本或配置中心。这类边要单独建一类"迁移边"。

### 文献依据

- Sage 的教训：**轻量 tracing 而非应用改动或内核埋点**是其可部署性的来源（ASPLOS'21 扩展摘要）；它用 CBN 训练在 **RPC 级 trace** 上，同时捕获后端到前端的 latency propagation。反过来说，**运行期图是唯一能捕获 backpressure 与 cascading QoS violation 的手段**。
- Seer 给出反面约束：**仅轮询 NIC 队列深度**能识别 routing / incast / 失败 / 资源饱和类热点，但**"misses QoS violations that are caused by performance and efficiency bugs in the application implementation, such as blocking behavior between microservices"**（Seer §4.2）。即：**观测面不全会让一整类根因系统性消失**。
- GitNexus 的 `group sync` / Contract Registry 提供了工程化的对应物：跨仓抽取契约并做交叉链接，`gitnexus group impact <name> --target <symbol> --repo <groupPath>` 直接给**跨仓爆炸半径**（GitNexus README）。同理 `route_map`、`tool_map`、`shape_check`、`api_impact` 分别对应路由面、RPC 工具面、响应形状面、API 变更前影响面。

---

## 阶段 ③ 传播路径假设生成（沿依赖与追踪传播）

### 可落地操作

1. **按图类型分别生成假设**，并给每条假设标注它依赖哪种传播语义：
   - 编译期图 → "编译/链接期破坏"
   - 契约图 → "语义不兼容（版本偏斜）"
   - 运行期图 → "延迟/错误率/饱和度传播"
2. **用统一的目标函数排序**：把候选假设映射到 `可判别性 × 先验概率 ÷ 验证成本`。
3. **记录传播假设的失效模式**（见下）。

### 三类方法的算法思想与失效边界

| 方法 | 核心算法思想 | 输入数据要求 | 量化结论 | 失效边界 |
|---|---|---|---|---|
| **MicroRCA**（Li Wu, Johan Tordsson, Erik Elmroth, Odej Kao；IEEE/IFIP NOMS 2020，pp. 1–9，DOI `10.1109/NOMS47738.2020.9110353`） | **attributed graph**（service 节点 + host 节点，异常不仅沿调用路径传播，也沿**同机共置**传播）→ 异常子图抽取（以服务间 **response time 边**为异常检测目标，取边的**起点**为异常节点）→ 边权用 **Pearson correlation** 三种方式计算 → **Personalized PageRank**（c = 0.15）定位 | **无应用埋点**（"without any application instrumentation"）。需要：应用层服务间 response time + 系统层资源利用率（CPU / 内存 / I/O / 网络，容器与宿主机两级） | **precision 89%、MAP 97%**；相对基线至少高 **13% precision / 15% MAP**；相对 MonitorRank + Microscope 平均 **24% MAP** 提升 | 论文自述：先前"前后端相关性排序"类方法**无法定位对前端影响很小的故障服务**；MicroRCA 靠"服务异常症状 × 资源利用率"相关性来救这类 leaf 服务 |
| **Seer**（Yu Gan, Yanqi Zhang, Kelvin Hu, Dailun Cheng, Yuan He, Meghna Pancholi, Christina Delimitrou；ASPLOS'19，DOI `10.1145/3297858.3304004`，15 页） | DNN 在**每服务队列深度**上学空间（服务间依赖）+ 时间（负载、资源争用）模式；输入/输出神经元数 = 活跃微服务数，输入按**拓扑序**排列以捕捉空间热点 | **需要侵入式埋点**才能拿到每服务 outstanding requests（NIC 队列 + 软件队列探针）；无埋点时降级为仅 NIC 队列 | **91% 正确预判 QoS 违规**，并在 **84%** 情况下彻底避免违规；tracing 开销 **< 0.1% 端到端延迟、< 0.15% QPS**（未采样） | 论文明确：仅 NIC 队列会**漏掉应用实现层的性能/效率 bug**（如微服务间 blocking）；公有云无 perf counters 时改用 10 个可调 microbenchmark |
| **Sage**（arXiv 2101.00267，题名 *Sage: Using Unsupervised Learning for Scalable Performance Debugging in Microservices*；会议版题名 *Sage: practical and scalable ML-driven performance debugging in microservices*，Yu Gan, Mingyu Liang, Sundar Dev, David Lo, Christina Delimitrou；ASPLOS'21，DOI `10.1145/3445814.3446700`） | **Causal Bayesian Network (CBN)** + **Graphical Variational Auto-Encoder (GVAE)**；CBN 在 RPC trace 上捕获服务间依赖 + 单服务到端到端性能的因果关系 + 后端→前端 latency 传播；GVAE 生成 **counterfactual**（把某服务性能/用量调到已知满足 QoS 的值），推断该改变是否恢复 QoS | **无标签数据**；只需**轻量 tracing**，**不需应用改动、不需内核埋点**；实际用 **Jaeger** + **Prometheus Node Exporter** | **> 93%** 根因识别准确率（本地集群 **91%–95%**）；GCE 上 **188 容器**（本地集群的 **6.7×**）时训练时间仅 **+19.4%**、推理时间 **+26.5%**，准确率不受规模影响；transfer learning + partial retraining 使重训快 **3–30×** | 论文对比中 **CauseInfer 与 Microscope 常在依赖图上找错路径**；Sage 相对 Seer 不需要毫秒级队列长度 tracing 与标注数据，但精度"very similar" |

> Microscope（WSDM 2020）、CloudRanger、FreeLPA、MicroRank：【未核实】。本轮未能打开 ACM DL（`dl.acm.org/doi/10.1145/3331166.3331605` 返回 403）、dblp（Anubis 反爬）与 arXiv API（429）。仅在 MicroRCA 的引用列表中出现 Microscope（"Microscope performs well in CPU hog and memory leak when the anomalies are detected correctly but worse in fault latency when more false alarms are detected"），其原始出处与 venue **未核实**，故不写入结论。CloudRanger 仅见二手描述（"non-intrusive ... random walk procedure"），**未核实**。FreeLPA、MicroRank **本轮未检索到可打开的权威页面**。

### 可落地操作（续）

- **假设必须写成可判别的形式**：`如果在 A 仓回滚到版本 v，则症状 S 消失；否则假设 H1 被证伪`。不能写成"可能与 A 有关"。
- **区分"依赖异常传播"型与"直接症状"型**：MicroRCA 属前者（沿 attributed graph 用 PPR 排序）；Sage 的 counterfactual 属第三类（**假设性干预**：改一个变量的取值看 QoS 是否恢复）。多仓场景下第三类最贵但最有判别力，因为它是**真的干预**而不是相关性。

### 输入 / 输出

| 项 | 内容 |
|---|---|
| 输入 | 阶段②三张图 + 版本矩阵 + 运行期 trace 样本 + issue 复现步骤 |
| 输出 | 假设列表 `H1..Hn`，每条含：依赖的传播语义、判别实验设计、预期观测、若被证伪的替代假设 |

### 失效兜底

- **trace 采样不足**：trace 未覆盖故障窗口时，"无异常"只反映采样。兜底是把"观测覆盖率"作为假设的置信折扣项。
- **异步链路**（消息队列、最终一致）：传播路径可能跨越小时级，MicroRCA 的 response-time 边模型不成立。兜底是显式建"消息 topic 边"并单独建模。
- **多根因**：BeyondSWE 的 DepMigrate 子集提示存在"上游破坏性变更导致的仓级协同改造"这类多仓任务，**根因不是单点**。兜底是把假设从"一个仓"放宽到"一个仓集合"，并允许集合内元素无序。

---

## 阶段 ④ 判别性实验（discriminating experiment）

### 可落地操作

1. **实验设计原则**：一次实验应当**尽量多地证伪多个假设**。若一个实验只区分 H1/H2，那它对 H3..Hn 没有信息量——在假设空间大时这是浪费。
2. **按成本升序执行**：静态检查（编译/契约 diff）→ 局部运行时检查（单仓单测 / 契约测试）→ 跨仓集成 → 灰度/影子流量。
3. **对照设计**：变更必须可逆且有对照。Sage 的 counterfactual 是这一原则的规范化形式（把目标服务调到"已知满足 QoS"的值）。

### 输入 / 输出

| 项 | 内容 |
|---|---|
| 输入 | 假设列表、可用环境（本地 / 预发 / 灰度）、回滚手段 |
| 输出 | 每个假设的 `证伪 / 存活 / 不可判定` 状态 + 支撑证据（trace 片段、日志、指标 diff） |

### 失效兜底

- **实验不可逆 / 有副作用**：跳过实验直接改。此时必须承认"确认门"未满足，只能产出"待验证补丁"。
- **灰度流量不足**：判别实验需要足够样本量才有统计意义。兜底是用确定性判据（schema 是否匹配、序列化是否报错）替代统计判据。
- **实验污染**：多个假设共用同一环境时，后跑的实验受前一个影响。兜底是每实验独立环境 + 明确的重置步骤。

### 文献依据

- **counterfactual 是本阶段最有力的形式**：Sage 用 GVAE 生成 counterfactual "tweak the performance and/or usage of individual microservices to values known to meet QoS, and infers whether the change restores QoS"（ASPLOS'21 扩展摘要）。
- **反事实重放在 Agent 轨迹归因上同样有效**：AgenTracer（arXiv 2509.03312）用 **counterfactual replay**（用 oracle 引导替换 agent action）系统性地定位"决定性错误步"，并配合 **programmatic fault injection** 从成功轨迹合成已知失败点；产出的 TracerTraj-2.5K 含 2000+ 高保真失败轨迹；AgenTracer-8B 基于 Qwen3-8B，用多粒度 RL 训练，在 Who&When 上比 Gemini-2.5-Pro / Claude-4-Sonnet 高出至多 **18.18%**，并给 MetaGPT / MaAS 带来 **4.8–14.2%** 的性能增益。
- **FALAT 明确指出归因不能当独立 step 分类**：Md Nakhla Rafi, Md Ahasanuzzaman, Dong Jae Kim, Zhijie Wang, Tse-Hsun Chen，*FALAT: Tracing Failures in LLM Agent Trajectories via Dependency-Guided Search*（arXiv 2606.00765，2026-05-30）——"mistakes can propagate across the trajectory: later actions may appear incorrect, but only because they depend on an earlier corrupted state. Therefore, failure attribution cannot be treated as independent step-level classification."，并把归因建模为**依赖引导的搜索**：先构造"任务本应如何解"的期望，再据此圈定可疑区域，然后沿决策/工具输出/agent 消息的依赖区分**引入错误**的步与**只是继承/传播**前序错误的步，最后检验"修正该候选步是否足以恢复期望结果"。最佳配置在算法生成轨迹上 **46.0% step-level accuracy**，在更难的手工轨迹上 **29.1%**。
  → **这条直接对应多仓场景**：一个后端仓的 commit 可能是"引入错误"，下游服务仓的对应改动只是"传播"。多仓定位必须区分这两者，否则会把修复打在错误的仓上。

---

## 阶段 ⑤ 确认门（三条件）

只有三条**同时**成立才允许把结论标记为"根因已确认"：

| # | 条件 | 判据 | 违反时的处置 |
|---|---|---|---|
| C1 | **现象可复现** | 在**隔离环境**或受控灰度上，用**未打补丁**的代码 + 记录的输入，稳定复现同一症状（同一 trace 特征 / 同一错误路径） | 不可复现 → 结论降级为"疑似"，保留全部假设，不进入修复 |
| C2 | **因果证据** | 存在**判别性实验**结果，把"补丁仓"与"非补丁仓"区分开；且能排除共因（同一 commit 同时改了多个仓时，须能分离） | 只有相关性（监控指标同步异常）而无判别实验 → 只能给"相关性排序"，不能给根因 |
| C3 | **干预可验证** | 对根因仓的最小干预能**恢复**症状；且该干预的移除能**再次复现**（双向可逆） | 单向可逆（改了好但回滚不确定）→ 需补回滚验证，否则不得合并 |

### 三条件的必要性依据

- **C1 对应"trace 覆盖率"问题**：TRAIL（arXiv 2505.08638，Darshan Deshpande, Varun Gangal, Hersh Mehta, Jitin Krishnan, Anand Kannappan, Rebecca Qian）给出警示：148 条人工标注 trace、共 **1987 个 OpenTelemetry span**（其中 575 个至少含一个错误）、**841 个标注错误**、平均每 trace **5.68** 个错误；最佳模型 gemini-2.5-pro 在 TRAIL 上仅 **11%**。数据用 GAIA 与 SWE-Bench Lite，所有 trace 经 **OpenTelemetry** 采集，采用 **openinference** 规范。
  → 意思是：**长轨迹里"看起来正常"的一步往往只是下游继承**（TRAIL 论文明确说既有分析框架 "primarily focused on parsed traces containing unstructured text ... do not adequately represent common agent framework outputs that generate structured traces logged in standardized formats like opentelemetry"）。这正是 C2 存在的理由。
- **C2 / C3 对应"多文件掉点"**：Multi-SWE-bench 的实证（Tab. 4 / Tab. 5 / Fig. 3）——hard 级 issue 上现有 LLM 与 agent "mostly ineffective, with resolved rates approaching zero"；且修改文件数越多 resolved rate 越低。hard/medium 占比：Multi-SWE-bench **77.1%**，SWE-bench Verified **61.2%**。这说明**多仓/多文件任务上的"修好了"很可能是假阳性**，必须靠 C3 的双向可逆验证兜住。
- **既有研究指出 SWE-bench 类"已解决"标注本身可能不正确**：本目录 `swe-bench-solved-issues-really-solved.pdf`（*Are "Solved Issues" in SWE-bench Really Solved Correctly? An Empirical Study*，13 页）即为该方向的实证研究，可作为"确认门不能省"的旁证。

### 确认门不通过时的兜底

按证据强度分三级输出：

1. **根因已确认**（C1+C2+C3 全过）→ 进入 `cross-repo-patch-coordination.md` 的补丁协同流程。
2. **相关性排序**（C1 过，C2 未过）→ 只能产出"按 PR@1 排序的候选仓 + 排序依据"，并明确写"这是相关性不是因果"。MicroRCA 的 Personalized PageRank 输出就属于这一类（§IV-C），它的 89% precision 是在**注入故障的 Sock-shop 基准**上测得的，不能外推到开放世界。
3. **不可判定**（C1 未过）→ 退回阶段①，要求补充可复现步骤或补充观测面。

---

## 本轮核实的来源清单（含校验）

| 主题 | 一手来源 | 核实方式 |
|---|---|---|
| MicroRCA | IEEE/IFIP NOMS 2020，DOI `10.1109/NOMS47738.2020.9110353` | HAL `hal-02441640` 全文 PDF 已下载（10 页，含 HAL 封面页），首页文本 + 算法章节逐字核对 |
| Seer | ASPLOS'19，DOI `10.1145/3297858.3304004` | 通过 `par.nsf.gov/servlets/purl/10165223` 与 `csl.cornell.edu` 作者自存版核对 §4.2 埋点小节与摘要 |
| Sage | arXiv 2101.00267；ASPLOS'21 DOI `10.1145/3445814.3446700` | arXiv abs 页 + `asplos-conference.org` 扩展摘要核对 |
| BeyondSWE | arXiv 2603.03194（v2, 2026-05-26），DOI `10.48550/arXiv.2603.03194` | arXiv abs 页 + PDF 28 页首页文本核对 |
| Multi-SWE-bench | arXiv 2504.02605（v1, 2025-04-03）；NeurIPS 2025 D&B 版本（2,132 实例 / 8 语言） | arXiv abs 页 + PDF 32 页；NeurIPS 论文 PDF 与项目页交叉核对 |
| FALAT | arXiv 2606.00765（2026-05-30） | PDF 17 页首页文本核对 |
| AgenTracer | arXiv 2509.03312 | PDF 18 页首页文本核对 |
| TRAIL | arXiv 2505.08638v3（2025-06-23） | PDF 25 页首页文本核对 |
| SWE-Explore | arXiv 2606.07297 | PDF 20 页首页文本核对 |
| CodeScaleBench | Sourcegraph 博客 + `github.com/sourcegraph/CodeScaleBench` 技术报告 | 搜索命中并读取报告正文表格 |

详见 `research/README.md` 的原文索引表。
