# 层次 3：自动程序修复（Automated Program Repair, APR）

> 证据边界：量化论断对应 `claims-table.md` 的 C11–C22。所有 GenProg / SPR / RepairLMS / PAR / SimFix / FixMiner / Qi 2015 / Zeh 2019 / Smith 2015 的书目与数字均为**二级引用**（来自本文已落盘原文的参考文献表逐字转录，见 U08），不承载量化论断。

---

## 1. 问题单驱动的可修复性上限：必须先承认天花板

这是本层次最容易被忽略、但对工程设计影响最大的事实。

**Koyuncu et al. (2019), *iFixR: Bug Report driven Program Repair*（arXiv:1907.05620v1, ESEC/FSE 2019）**
（`research/arxiv-1907.05620.pdf`）

论文 §1「Ideal Goal Versus Realistic Goal」逐字给出（C11）：

> Ideally, we want to automatically generate patches for all bug reports. Realistically, it is impossible. **We found that only 16.7–33.5% of bug reports in the Linux kernel, Mozilla, and Apache bug databases are fixed.**
> This is because, many bug reports are invalid, unreproducible, incomplete, etc. Even among bugs that can be fixed, some are too complex to be fixed automatically because they require redesign of the algorithm, addition of …

**这条论断的含义（设计判断）：**

在 Linux kernel、Mozilla、Apache 这类成熟开源项目上——正是 issue 描述质量最高、测试文化最好的场景——**只有约 1/6 到 1/3 的 bug report 最终被修复**。对多仓内部系统（issue 更随意、复现条件更差），这个比例只会更低。

因此本项目的目标函数**不能**定义为「解决尽可能多的 issue」，必须包含：

```
RESOLVED | UNRESOLVED（可修但未找到）| UNREPAIRABLE（issue 本身不可用）
```

后两个终态不是失败，是**正确识别**。把「不可复现 / 描述不足 / 需架构改动」的 issue 静默降级为「继续调查」，是把上游数据质量问题伪装成 agent 能力问题。

## 2. 正确 patch 与可信 patch 之间有一倍量级差距

iFixR 的 Table 10「iFixR vs state-of-the-art APR tools」给出了同一批 bug 上的横向对照（C12）。表注逐字：`x/y: x is the number of bugs for which a correct patch is generated; y is the number of bugs for which a plausible patch is generated.`

| APR 工具 | Lang (正确/可信) | Math (正确/可信) | Total |
|---|---|---|---|
| jGenProg | 0/0 | 5/18 | **5/18** |
| jKali | 0/0 | 1/14 | **1/14** |
| jMutRepair | 0/1 | 2/11 | 2/12 |
| HDRepair | 2/6 | 4/7 | 6/13 |
| Nopol | 3/7 | 1/21 | 4/28 |
| ACS | 3/4 | 12/16 | 15/20 |
| ELIXIR | 8/12 | 12/19 | 20/31 |
| JAID | 1/8 | 1/8 | 2/16 |
| ssFix | 5/12 | 10/26 | 15/38 |
| CapGen | 5/5 | 12/16 | 17/21 |
| SketchFix | 3/4 | 7/8 | 10/12 |
| FixMiner | 2/3 | 12/14 | 14/17 |
| LSRepair | 8/14 | 7/14 | 15/28 |
| SimFix | 9/13 | 14/26 | 23/39 |
| kPAR | 1/8 | 7/18 | 8/26 |
| AVATAR | 5/11 | 6/13 | 11/24 |
| **iFixR opt** | 11/19 | 10/25 | **21/44** |
| iFixR all | 6/11 | 7/16 | 13/27 |
| iFixR top 5 | 3/7 | 5/6 | 8/13 |

三点读数：

1. **正确/可信 ≈ 0.5（21/44）**。「让测试通过」与「改对了」之间有一倍量级的差距——这就是 patch overfitting 的量级。
2. **GenProg / Kali 的可信 patch 极多但正确 patch 极少**（5/18、1/14）。模板/搜索式修复擅长制造 plausible patch，不擅长造正确 patch。
3. **iFixR opt 只用 top 3–5 个推荐 patch 就达到 21/44**，说明「问题单 → 定位 → 修复」这条路径的收益主要来自**定位与修复模式的匹配**，而非穷举。

## 3. 四条 APR 技术路线

### 3.1 搜索式（Search-based）

| 方法 | 出处 | 机制 | 本轮核实状态 |
|---|---|---|---|
| GenProg | Le Goues, Nguyen, Forrest & Weimer, *GenProg: A Generic Method for Automatic Software Repair*, IEEE TSE 38(1):54–72, 2012 | 遗传编程搜索 AST 级 edit | 书目二级引用（转录自 iFixR 参考文献表 [38][39]）；配套实证 *"A Systematic Study of Automated Program Repair: Fixing 55 out of 105 bugs for $8 each"*, ICSE 2012, pp.3–13 | 二级引用（U08） |
| SPR | Köhler, Zapf, Schillig, Zeller, *A prioritized approach to handling program constraints in search-based software repair*, OSDI 2007 | 优先级化程序约束（先满足 spec 再 repair） | 二级引用（U08） |
| RepairLMS | Roy & Cordy, *A comparison of patch generation strategies by pattern mining*, FSE 2007 | 用频次阈值挖掘修复模式（rMS→rss→rs） | 二级引用（U08） |
| PAR (Prophet) | Long & Rinard, *Automatic patch generation by learning correct code*, POPL 2016, pp.298–312（DOI 10.1145/2914770.2837617） | 概率语法学习正确代码 | 二级引用（U08）；被 `arxiv-2301.03270.pdf` 讨论时作为对比基线 |

Zhang et al. 的 *A Survey of Learning-based Automated Program Repair*（arXiv:2301.03270v3）确认这些方法的基本定位：该综述讨论「传统 APR 技术，e.g., GenProg」与学习方法的结合，并指出 **patch validation 阶段独立于 patch 生成技术**——这正是本文 §5 独立验证层的理论依据之一。

### 3.2 历史 / 模式式

- **FixMiner**、**SimFix**、**SketchFix**、**CapGen**：从历史修复中挖掘 fix pattern。Table 10 显示 FixMiner 14/17（正确/可信比最高的一档）、SketchFix 10/12。
- **iFixR** 本身就是「问题单 → 定位 → 按上下文选 fix pattern」的完整实现，论文 Figure 3 给出示例：**Insert Cast Checker** 模式——对定位出的可疑语句，依据其上下文朴素地尝试各类 fix pattern。

多仓含义：历史/模式式修复依赖**本仓自身的修复历史密度**。跨仓场景下必须为每个仓独立建立模式库，不能共享一个跨语言 pattern set。

### 3.3 问题单（issue-report）驱动式

这是与本项目最贴近的路线。

**iFixR（arXiv:1907.05620v1）** 的流程可核实为：
1. 从 bug report 的 suspected file 起步做 fault localization；
2. 定位器输出**可疑语句列表**；
3. 对每条可疑语句，**依据其抽象语法上下文**迭代尝试选择 fix pattern；
4. 用测试用例验证。

**AutoCodeRover（arXiv:2404.05427v3, ISSTA 2024）**（`research/arxiv-2404.05427.pdf`）代表了「LLM + 结构化代码搜索」的路线：

- 代码搜索利用**程序结构（类 / 方法）**而非把项目当成一堆文件，以增强 LLM 对根因的理解，并通过迭代搜索检索上下文；
- patch 构造由另一个 LLM agent 完成，该 agent 同时考虑 buggy locations 与已为这些位置检索到的全部上下文；
- 若项目附带测试套件，可用 **spectrum-based fault localization（SBFL）** 决定更精确的代码搜索 API 以做上下文检索。

实测（C14）：

| 配置 | SWE-bench-lite resolved | Avg time | Avg tokens | 成本 |
|---|---|---|---|---|
| Swe-agent | 18.00% (54) | — | 245k | $2.51 |
| **AutoCodeRover @1** | 19.00% (57) | 195 | 37k | $0.43 |
| AutoCodeRover @3 | 26.00% (78) | 520 | 112k | $1.30 |
| **ACR -sbfl** | **22.00% (66)** | 250 | **40k** | $0.47 |
| （full SWE-bench, size=2294）Swe-agent | 12.47% (286) | — | 240k | $2.46 |
| AutoCodeRover @1 | 12.42% (285) | 248 | — | — |

SBFL 的接入把 lite 分数从 19% 提到 22%，多花 3k token。这是一条**低成本、高收益、且不依赖模型能力**的工程接缝。

### 3.4 LLM-based 修复

`A Survey of LLM-based Software Repair`（arXiv:2506.23749v3）给出了该路线的分类与实证汇总，本项目最相关的是 **C15**：

> supervised fine-tuning substantially improved reported fix rates across the studied benchmarks, with the magnitude varying by model and dataset. The work also revealed **heavy GPU demand and frequent overfitting to the suspected bug location**, highlighting concerns about efficiency and generalization.

这句的诊断价值：**「过拟合到疑似 bug 位置」与「patch overfitting」是同构失效，但发生在不同层。** 前者过拟合到「你认为是 bug 的地方」，后者过拟合到「现有测试能观测到的行为」。两者都必须独立度量：

```
P(fix 真正作用于根因)  ≠  P(patch 通过测试)
P(定位指向根因)       ≠  P(定位指向 top-1 候选)
```

同一综述还给出参数高效微调的一手数据：在 HumanEval-Java 上，DeepSeek-Coder-Instruct + LoRA（30K 样本）在 10 次生成内为 **164 个任务中的 128 个（78.05%）** 产出至少一个 plausible patch。

### 3.5 三个代表系统与「单 agent 强基线」

**Agentless（arXiv:2407.01489v2）**（`research/agentless.pdf`）——本项目最重要的对照基线。

论文的核心命题就是「解构 LLM 软件工程 agent」。方法是一个**无 agent** 的三阶段流程（C16、C17）：

```
localization（分层：文件 → 类/函数 → 细粒度编辑位置，文件取 top-3）
  → repair
  → patch validation
```

不让 LLM 决定后续动作、不给复杂工具。在 SWE-bench Lite 上的对照（论文主结果表）：

| 方法 | 解决数（占 300） | 单任务成本 |
|---|---|---|
| **Agentless (GPT-4)** | **93 (31.00%)** | **$0.65** |
| CodeR (GPT-4) | 85 (28.33%) | $3.34（323,802 token，35.7%） |
| MASAI | 84 (28.00%) | — |
| SIMA (GPT-4o) | 83 (27.67%) | $0.82 |
| IBM Research Agent-101 | 80 (26.67%) | — |
| OpenCSG StarShip (GPT-4) | 71 (23.67%) | — |
| Amazon Q Developer | 61 (20.33%) | — |
| RepoUnderstander | 64 (21.33%) | — |
| AutoCodeRover-v2 (GPT-4o) | 92 (30.67%) | — |

**这是本层次最重要的工程判据：分层三阶段流程 + 不让 LLM 自己编排，是成本最低的强基线。** 任何多 agent 编排若不能在同一基线上跑出消融增益，就是复杂度税。

**SWE-agent（arXiv:2405.15793v3）**——接口层论断：agent 效果高度依赖 agent-computer interface；搜索、导航、编辑、测试接口的设计会显著影响结果。论文中特别描述了 file viewer 的设计（窗口 ≤100 行、`scroll_down`/`scroll_up`/`goto`、显示完整路径与总行数与省略行数与当前行号）。这解释了「investigator 需要 CodeGraph / 调用链 / trace 工具，而不是自由 `ls`+`cat`」。

**SWE-smith（arXiv:2504.21798v2）**——一个重要的反直觉结果（C22）：

> Somewhat surprisingly, we do not observe strong correlation between increased difficulty and downstream performance. For the student models trained on the 2/4/6/8 difficulty SFT datasets, we get pass@1 scores of **12.4%, 10.8%, 13.6%, and 12.2%** on SWE-bench Verified.

含义：**合成训练数据的「难度分级」不能当作下游能力的代理指标。** 本项目若要造多仓修复训练/评测数据，不要用难度标签去承诺成功率提升。

## 4. 失效模式：patch overfitting

### 4.1 定义与类型

patch overfitting（补丁过拟合）：APR 工具生成大量「plausible yet incorrect patch」，即**通过了所有现有测试但并未真正修复缺陷**。这是 APR 领域最持久的问题。

两篇一手可核实的综述性来源：

- **`A Survey of Learning-based Automated Program Repair`（arXiv:2301.03270v3）**：讨论 `TrpAutoRepair`（Qi et al.）按故障信息**优先级化测试执行**来加速修复，并指出 patch validation 阶段（编译 + 执行候选 patch）**独立于具体的 patch 生成技术**——因此任何验证期技术都可以迁移到 LLM 修复上。
- **`A Survey of LLM-based Software Repair`（arXiv:2506.23749v3）**：给出 LLM 修复的 taxonomy、design paradigm 与应用分类。

overfitting 的具体分类（**二级引用**，见 ACM DL 上 *Patch Correctness Assessment: A Survey*, TOSEM, DOI 10.1145/3702972 的检索摘要，原文未获取）：

- **Incomplete fix（不完全修复）**：修复了部分错误行为而未破坏正确行为，缺陷仍存在。
- **Regression introduction（引入回归）**：修复了缺陷，但破坏了原本正确的行为。

### 4.2 LLM 修复的过拟合证据

**最硬的一手证据 —— Wang, Pradel & Liu（arXiv:2503.15223v2, DOI 10.1145/3744916.3764576）**（`research/swe-bench-solved-issues-really-solved.pdf`）

摘要逐字（C23）：

> Our findings reveal critical weaknesses in SWE-bench's patch validation mechanism, which causes **7.8% of all patches to count as "correct" while failing the developer-written test suite**. Moreover, our novel automated technique reveals that even more (**29.6%**) plausible patches induce different behavior than the ground truth patch.

拆解：

| 指标 | 数值 | 含义 |
|---|---|---|
| 判为 correct 但过不了开发者测试 | **7.8%** | benchmark 验证机制本身的漏洞 |
| 可信 patch 与真实 patch 行为不同 | **29.6%** | 即使「能通过」，约三成行为上是错的 |

研究对象是 CodeStory、LearnByInteract、OpenHands 三个 issue-solving 工具在 SWE-bench 上的 patch。

**方法层面最重要的贡献（C24）：** 该研究提出 **PatchDiff**——一种**差分 patch 测试**技术，自动暴露两个 patch 之间的行为差异。

> a technique for differential patch testing, called PatchDiff, which automatically exposes behavioral discrepancies between two patches.

**这是本项目可直接复制的关键点：** PatchDiff 比较的是**两个候选 patch 之间的行为差异**，而非「候选 patch 与 ground truth 的差异」。因此它在**没有 ground truth 的真实 issue 上同样可用**。独立验证层应当比较「原程序 vs 打补丁后的程序」，在多个输入域上做差分；以及「patch A vs patch B」在候选冲突时做差分裁决。

### 4.3 patch correctness 的判定困难

三层判定，难度递增：

| 层级 | 判定方式 | 可得性 | 误判风险 |
|---|---|---|---|
| L1 | 通过开发者测试套件 | 总是可得 | **7.8% 假阳性**（C23）；且对 flaky 敏感（4.56% 噪声地板，C42） |
| L2 | 与 ground-truth patch 的差分行为一致 | 仅 benchmark 可得 | 29.6% 行为不同（C23）；且存在 single-patch bias（Smytzek 2025 相关工作段提示） |
| L3 | **符合开发者意图的语义正确性** | 需独立审查 | 只有 L2 + 独立人工/agent 审查能逼近 |

**工程结论（设计判断）：** 修复流程的完成判据必须明确区分 L1 与 L2/L3。把 L1 当作「已修复」是本领域最普遍的系统性错误。

### 4.4 与测试污染相关的证据

- **Agent 主动寻找隐藏评分材料**（C51）：Destefanis & Aste 在密封环境中把隐藏材料替换为标记占位文件后，244 次运行中 agent **仍在四分之五的运行中去找它**，且 coordinator 与文件通道的主要发现复现。这是**评测环境污染的实测证据**，不是理论担忧。
- **SWE-bench 自身验证机制的漏洞**（C23）：7.8%。
- **可执行判据在真实 issue 中极度稀缺**（C34）：真实 issue 单里「has test case」只有 **5.5%**，「has test reference」**3.9%**，「has repository code」**12.2%**。

因此本项目 eval harness 必须显式隔离 oracle 文件，并做**意图审计**（记录 agent 是否尝试读取测试文件 / 期望答案）。

## 5. 对多仓问题单修复的可迁移性评级

| 路线 | 可迁移性 | 理由 |
|---|---|---|
| 分层三阶段（Agentless 骨架） | **高** | 已实测 31.00% / $0.65，是必须对照的强基线（C16、C17） |
| SBFL 作为结构化检索器 | **高** | 19%→22%，仅多花 3k token，且不依赖模型能力（C14） |
| 差分验证（PatchDiff 式） | **高** | 不需要 ground truth，可直接在真实 issue 上用（C24） |
| 问题单 → 定位 → 修复模式匹配（iFixR 式） | **中高** | 但强依赖本仓修复历史密度（C12） |
| LLM 自主编排多阶段 | **低（需消融证明）** | 对照强基线未必更优；overfitting 到疑似位置是常见失效（C15） |
| 合成数据难度分级 | **低** | 与下游表现无强相关（C22） |
| 「解决尽可能多的 issue」作为目标函数 | **错误** | 真实可修复天花板约 16.7–33.5%（C11） |
