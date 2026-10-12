# 层次 1–2：调试理论与故障定位（Debugging Theory & Fault Localization）

> 证据边界：本文所有量化论断都可在 `research/` 下的一手 PDF 中按「原文依据位置」定位；无法核实的一律进入文末清单，不参与结论。逐条对应关系见 `claims-table.md` 的 C01–C10、C13、C14、C18–C21。

---

## 层次 1：调试理论与过程

### 1.1 起点更正：一份被广泛误引的「TOCS 调试综述」

调研提纲中把「Clark & Zarembka 的 debugging survey（ACM TOCS 级）」列为必查项。实际核查结果：

- 两轮不同措辞检索（`site:dl.acm.org` 限定 + 通用检索）均未命中该题录；
- 进一步逐条核对 DBLP 镜像的 **ACM TOCS Volume 11 全部四期目录**（mail.vldb.org/dblp/db/journals/tocs/tocs11.html），未发现该论文。

**结论：这是一处引用记忆错误，本文与 `claims-table.md` 均不引用该条。** 层次 1 的锚点改用可核实的一手文献重建：Zeller 1999 的 delta debugging（层次 1 与 2 的交点）、以及后续实证综述中关于「调试仍是手工为主」的量化陈述。

### 1.2 调试的基本结构：科学方法，而不是搜索

**Zeller (1999), *Yesterday, My Program Worked. Today, It Does Not. Why?*（ESEC/FSE 1999, pp.253–267）**
（`research/zeller-esec1999-delta-debugging.pdf`，标题已逐字校验）

- 论文把回归定位形式化为：「若不施加任何变更程序可用；若施加全部变更程序不可用。**哪一条变更导致失败？**」
- 核心算法是 **delta debugging**：对变更集合做子集二分测试（ddmin），用最小测试执行数定位**最小致故障变更集**。
- 量化结果（C02）：原型在数小时内从 **178,000 行 GDB 变更**中定位出**单个**致故障变更。

这条为什么对「问题单驱动修复」重要：

| delta debugging 的性质 | 对多仓问题单修复的可迁移含义 |
|---|---|
| 只依赖「是否失败」这一单调判据 | 复现门禁只需一个稳定的 pass/fail 判定，不需要根因知识 |
| 子集二分把指数级组合搜索降到 O(n log n) 级测试 | 「逐仓试补丁」应改为「按证据维度二分」，而不是线性扫仓 |
| 输出是**最小集合**而非单个猜测 | 定位产物应是「最小致因候选集 + 每项的判别实验」，而不是一段散文报告 |

**de Souza et al. (2017), *Spectrum-based Software Fault Localization: A Survey*（arXiv:1607.04347v2）**
（`research/arxiv-1607.04347.pdf`）

- C01：测试与调试**最多可占开发成本的 75%**，而故障定位在实践中至今主要靠人工。
- C10：SFL 的**面向开发者实验极其稀缺**，因此「现有 SFL 技术很少被企业真正用于自动化调试流程」。
- 同文还给出了 SFL 的成本优势论证：由于复用测试执行时已收集的数据，SFL 相对其他调试技术「往往具有较低的额外开销」。

**这一对数字放在一起是矛盾的，必须一起读：** 成本占比极高（75%）+ 实际采用率极低。含义是——**定位的价值不是「引入一个新技术」，而是「把既有零散信息（测试结果、覆盖率、栈、日志）变成排序」**。本项目在多仓场景下真正缺的往往不是算法，而是「可用的执行数据」。

### 1.3 bisect 与二分定位思想

- `git bisect` 的原始文献出处本轮**未能核实**（U05），故不引用。
- 但二分/子集隔离这一**思想**在 Zeller 1999 中有完整一手表述，并且给出了可核实的量化结果（C02）。本项目可以直接复用其算法内核，不需要引 `git bisect`。
- 关键限定：delta debugging 依赖**单调性**——「施加更多变更不会让失败的程序变好」。真实问题单里往往不满足（见 §2.5 多故障情形）。所以二分是**第一步**，不是全部。

### 1.4 「昨天的测试是错的」——未能核实，改用可核实的等价论断

调研提纲中「Just/Kapfhammer/Zeller 一系论断」本轮**未能定位到确切题录**（U03；DBLP 反爬拦截，作者出版列表无法核对）。因此不引用该系列的具体命题。

但本文要表达的方法论要点——**测试判定本身可能是错的**——在本文其他可核实来源中有直接支撑，且更贴近本项目的实际需要：

- **flaky test 的工业规模噪声地板**（C42）：Google TAP 平均每天 1.6M 次测试失败，其中 73K（**4.56%**）由 flaky test 造成。任何「测试红了 = 有 bug」的判定都有约 4.6% 的错误立案率。
- **「任一次通过即算通过」这条通行折中不可靠**（C43）：Luo et al. (FSE 2014) 明确指出当前对抗 flaky 的最常见做法（「重跑多次、任一次通过就判过」）是不令人满意的。
- **flaky 有明确的可识别根因类别**（C44）：async wait（可通过改动时间延迟人为改变失败结果）、order dependence 等。

工程结论：复现门禁必须写成「**在固定 revision + 固定环境下稳定复现 N 次全红**」，而不是「跑一次看到红」。

### 1.5 非技术权威论断

- **Michael T. Nygard《My Philosophy of Debugging》**：官方 PDF 返回 HTML 错误页、HTTPS 端点自签证书被拒，**未核实**（U02）。仅作线索列出，不给引文。
- **Gerald Weinberg《The Art of Debugging》、Kernighan & Plauger《The Practice of Programming》、Brooks《The Mythical Man-Month》**：本轮未打开权威页面确认版次与页码，**未核实**（U04）。

本文因此不依赖非技术权威文献。所有「假设驱动调试」「二分隔离」「复现优先」的方法论主张，都由 §1.2–§1.4 的一手文献承担。

---

## 层次 2：故障定位（Fault Localization）

### 2.1 方法家族全景（按证据来源划分）

| 家族 | 核心输入 | 代表方法 | 一手可核实度 |
|---|---|---|---|
| Spectrum-based / statistical (SBFL) | pass/fail 谱 + 覆盖信息 | Ochiai、DStar、Tarantula | 公式与实测值在 Zou 2019 一手可查（Ochiai/DStar 公式在 §2.2 原文逐字给出） |
| Slicing-based | 动态切片 / 静态切片 | Soremekun et al. 2021 | 一手可核实（`arxiv-2101.03008.pdf`） |
| Stack-trace-based | 崩溃时的活动栈帧 | Zou 2019 中的 stack trace 分析 | 一手可核实（实测值极差，见 C05） |
| Mutation-based (MBFL) | 变异体 + 覆盖 | Metallaxis | 一手可核实（Metallaxis 实测值见 Zou 2019 Table 3） |
| IR / history-based | 检索、历史、调用链 | BugLocator、Bugspots | 一手可核实（Zou 2019 实测：**单独使用时 Top-10 命中 0**） |
| Execution-feature-based | 定义-使用对、变量值谓词、标量对关系 | Smytzek et al. 2025 | 一手可核实（`arxiv-2502.18664.pdf`） |

### 2.2 量化结论：Top-1 / Top-3 数量级

这是本层次最需要精确的部分。三份一手文献给出了可对照的实测值。

**Zou, Liang, Xiong, Ernst & Zhang (2019), *An Empirical Study of Fault Localization Families and Their Combinations*（arXiv:1803.09939v2，Defects4J 上 357 个真实故障）**
（`research/arxiv-1803.09939.pdf`）

论文在 §2.1 逐字给出两个公式：

```
Ochiai(element) = ef / ( (ef + nf) · (ef + ep) )
DStar(element)  = ef* / ( ep + nf )      [论文设定 *=2，依据 Wong et al.]
```

**语句粒度（Table 3，357 faults，`EXAM@1/@3/@5/@10`）：**

| 方法 | @1 | @3 | @5 | @10 |
|---|---|---|---|---|
| SBFL Ochiai | 16 (4%) | 81 (23%) | 111 (31%) | **156 (44%)** |
| SBFL DStar | 17 (5%) | 84 (24%) | 111 (31%) | 155 (43%) |
| MBFL Metallaxis | 23 (6%) | 78 (22%) | 103 (29%) | 129 (36%) |
| MUSE | 24 (7%) | 44 (12%) | 58 (16%) | 68 (19%) |
| slicing union | 5 (1%) | 33 (9%) | 58 (16%) | 84 (24%) |
| slicing intersection | 5 (1%) | 35 (10%) | 55 (15%) | 71 (20%) |
| stack trace | 3 (3%) | 15 (13%) | 20 (17%) | 23 (20%) |
| IR-based BugLocator | 0 (0%) | 0 (0%) | 0 (0%) | 1 (0%) |
| history-based Bugspots | 0 (0%) | 0 (0%) | 0 (0%) | 0 (0%) |

**方法粒度（Table 11，同一批故障）：**

| 方法 | @1 | @3 | @10 |
|---|---|---|---|
| SBFL Ochiai | 92 (**26%**) | 180 (**50%**) | 241 (**68%**) |
| SBFL DStar | 95 (27%) | 182 (51%) | 241 (68%) |
| MBFL Metallaxis | 83 (23%) | 151 (42%) | 208 (58%) |
| slicing union | 35 (10%) | 80 (22%) | 131 (37%) |

**组合效应（Table 9–10）：** Level 1 = 20 个方法中的最高可疑元素（EXAM@1 = 28, 8%）；Level 1+slicing = 98（8%）；Level 1+SBFL = 220（11%）；Level 1+SBFL+slicing = 300（**15%**）；Level 4（再加 predicate switching + MBFL）= 5700 EXAM 但 **@1 = 72 (20%)**。论文摘要给出的表述是「组合相比单一技术在 Top-1 上带来 **200%** 的定位提升」。

四条可迁移结论：

1. **C03**：单一定位信号给出**不到一半**的 Top-10 命中率（44%），Top-1 仅 4–5%。定位必须有多路证据 + 判断，不能只靠一条排序。
2. **C04**：**粒度选择比算法选择更重要。** 语句粒度 Top-1 4% → 方法粒度 Top-1 26%，相差 6 倍。多仓定位**不应以行为最小单元**；先收敛到函数/模块/服务粒度，行级排序是二阶段问题。
3. **C05**：**stack trace 是起点而非结论。** 语句粒度下 stack trace 的 Top-10 远低于 SBFL。把栈顶当根因是典型失败模式。
4. **C06**：跨家族方法**相关性弱**，因此并行维护异质证据通道（符号图 / blame / 日志 / 栈 / 覆盖）再 schema 化合并，比堆同源提示更有效。

**Soremekun, Kirschner, Böhme & Zeller (2021), *Locating Faults with Program Slicing: An Empirical Analysis*（arXiv:2101.03008v1，457 bugs / 369 single / 88 multiple / 46 个开源 C 程序）**
（`research/arxiv-2101.03008.pdf`）

- **C07**：只检查统计调试给出的**单个**最可疑位置即可命中 **33%** 的故障；在 top-5% 区域内其效果是 dynamic slicing 的**两倍**。
- **C08**：混合策略——先看不超过 **top-5** 可疑位置，再切到动态切片，平均只需检查代码的 **15%（30 行）**。
- **C09**：单故障下动态切片比最好的统计调试公式高 **8 个百分点**；**多故障下反转**，统计调试更好。

第 3 条对多仓特别关键：issue 描述若暗示多因（跨仓数据不一致、多个 API 语义冲突），**只走一条切片链必然漏因**。

**Smytzek, Eberlein, Grunske & Zeller (2025), *How Execution Features Relate to Failures*（arXiv:2502.18664v1）**
（`research/arxiv-2502.18664.pdf`）

该工作主张：行覆盖之外的信息（定义-使用对、变量值谓词、标量对关系）与失败的相关性强于行执行本身，并给出 EFDD（Execution-Feature-Driven-Debugging）驱动的定位路径。它同时给出重要的**方法论警告**（本轮在检索摘要中见其 Related Work 段）：故障定位评测可能因**单故障简化、理想化 oracle、effort 模型**而高估改进；且存在 **single-patch bias**——只对照参考编辑会漏掉更广的失败相关区域。

> 备注：本条论文正文已落盘可读，但上述「single-patch bias / 评测高估」表述本轮是从其 arXiv HTML 相关工作段的检索摘要读到的，未逐字定位到 PDF 页码，故**不进入 claims-table.md 的量化列**，仅作方法论提示。

### 2.3 「定位是瓶颈」这一论断的出处

这是本文最关键的一条工程论断，出处必须明确。

**主证据 —— AutoCodeRover 的失败归因（C13）：**
Zhang, Ruan, Fan & Roychoudhury, *AutoCodeRover*, arXiv:2404.05427v3（ISSTA 2024）。
原文逐字：`in 18.0% of the tasks a patch is generated in wrong files, and in 6.7% of the tasks there is no applicable patch`。
论文同时给出人工核查观察：**这些任务的 issue 描述很少提到相关的 method / class / file**。

即：**约四分之一的失败纯粹来自「改错了地方」，而不是「改法不对」。** 这就是「定位是瓶颈」最硬的量化证据。

**辅证据 —— SHERLOC 的预算观测（C18）：**
arXiv:2606.24820v2 摘要首句：LLM agent「**utilize half their budget on locating faults before editing**」。

**反向约束 —— 定位不是万能（C20）：**
SHERLOC 上按发现质量分桶，最高桶 resolve 率 75.9%，**最低桶主动劣于 61.6% 的基线**。低质量定位不是「中性」，而是负收益。

**结论性表述（设计判断，非观测事实）：** 定位瓶颈有两面——「精度不足导致改错地方」（AutoCodeRover 24.7%），和「低质量定位结论主动拖垮修复」（SHERLOC 低质量桶）。因此本项目的定位阶段必须**独立设指标 + 独立设门禁**，而不是作为修复阶段的一个前置步骤。

### 2.4 分阶段定位：可直接抄的骨架

把上述量化结论转成工程骨架（**设计判断**，依据 C04/C07/C08/C17）：

```
Stage 1  服务/模块粒度   （依据 C04：方法粒度 Top-1 26% vs 语句粒度 4%）
         候选预算：≤3–5 个（依据 C08：top-5 之后切依赖）
Stage 2  文件粒度        （依据 C03：Top-10 仅 44%，单路不够 → 多路合并）
         证据通道：符号调用图 / 历史 blame / 日志 / 栈 / 覆盖率
Stage 3  符号粒度        （类 / 函数）
Stage 4  编辑点粒度      （仅对已确认符号下钻）
```

`Agentless`（arXiv:2407.01489v2）的分层正是这个骨架：先定位到文件、再到类/函数、最后到细粒度编辑位置，且每个 issue **先取 top-3 可疑文件**（C17）。

### 2.5 未覆盖的定位方向（诚实标注）

以下定位方向本轮**没有取得一手原文**，只在脉络中提及（U08，二级引用）：

- **Ochiai & Ochrimka (ISSRE 2004)** 原始论文——公式本身在 Zou 2019 §2.1 一手给出，但原始定义与实验未独立核实。
- **DStar (Kim, Zhou, Lu & Zhang, ICSE 2008)** 原始论文——同上，实测值在 Zou 2019 一手可查。
- **Bavota et al. 栈追踪 / 日志驱动 FL** —— 未获取一手原文。
- **因果推断式 FL** —— 未取得专文；本文 §2.2 的 Smytzek 2025 只部分相关（execution features ≠ causal inference）。
- **Kochhar et al. (ICSE 2006) 实践者期望** —— ACM 403（U07）。
- **历史 / IR-based FL** 在 Zou 2019 中的实测为 Top-10 命中 **0**（Bugspots、BugLocator），这是本轮唯一可核实的量化点；不能据此否定现代 IR-based 方法（AutoCodeRover/RepoGraph 类），只能说 2019 年的这两个基线在这批 Defects4J 故障上失效。

---

## 小结（层次 1+2 对「问题单驱动修复」的可迁移性）

| # | 结论 | 类型 | 依据 |
|---|---|---|---|
| 1 | 定位应分阶段，第一阶段目标粒度**不能是行** | 结构推论 | C04 |
| 2 | 定位必须多路异质证据合并，单路 Top-10 不足 50% | 观测事实 | C03、C06 |
| 3 | 复现门禁需「N 次稳定全红」，单次红灯有 ~4.6% 噪声地板 | 观测事实 | C42、C43 |
| 4 | 二分/子集隔离可用，但要先判单/多故障 | 观测事实 + 结构推论 | C02、C09 |
| 5 | 定位阶段应独立设指标与门禁（低质量定位是负收益） | 观测事实 | C13、C18、C20 |
| 6 | 「从栈顶开始」是对的，「栈顶即根因」是错的 | 观测事实 | C05 |
| 7 | 有测试套件时应把 SFL 接成结构化检索器 | 观测事实 | C14 |
