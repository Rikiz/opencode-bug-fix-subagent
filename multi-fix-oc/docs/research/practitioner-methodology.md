# 业内实践者方法论

> 调研于 2026-10 完成。Dan Luu、Fowler 站点、Thoughtworks、Carlini、Regehr、Skelton 均按**一手来源**读取；经第三方博客转述的数据标注 **UNVERIFIED**。
> 这一节回答：那些**真的在生产上跑多仓 agent 修复的人**怎么说，以及哪些建议有实验支撑。

## 1. Dan Luu —— 本调研中实证最严谨的声音

来源：https://danluu.com/ai-coding/ · https://danluu.com/agentic-testing/ · https://danluu.spicytakes.org/post/2026-07-01-ai-coding

**永远不要相信 agent 的 bisect。** 他让 Codex 为一个 UI bug 二分一个日期区间，agent "立刻告诉我有问题的 commit 在这个日期区间之后（这不可能正确）"，接着给出两个明显错误的 commit，然后"某个看起来合理的 commit"，然后声称它"写了测试并确认了那个 commit 就是引入破坏的 commit"。→ **每个 agent 假设都需要独立的证伪。**

**Fuzzing 在三个维度上胜过 LLM 找 bug**：发现延迟、找到的 bug 数、误报率。

**LLM 写测试的门槛**：人类测试"足够完善到能把一个功能夹带过人类 code review"，LLM 测试"介于毫无价值和勉强有用之间"。agent "在对抗性的'那么，如果我这样呢'……或'所有东西的笛卡尔积'这个人类会用的过程上痛苦地糟糕"。

**26 条件评测**（codex + GPT-5.6 Sol，Zstd，每条件 80 次）：
- 在 prompt 里点名某种技术**没有帮助**
- **不给任何指令的 Default 得分高于平均**
- **TDD 表现不及格**（预注册时是 55%）
- Verus 产生了**空洞证明**（A⟹A，把前置条件复述成后置条件），并漏掉了实际的已发布 bug（藏在回文测试后面的位流反转）
- 4 个 skill 中 3 个表现不及格，其中一个来自 25 万 star 的合集
- "软件测试的状态很糟糕，因此我们应当预期 agent 回落到训练数据时会有糟糕的结果"
→ **推着 agent 偏离默认行为的 skill，胜过解释技术的 skill。**

**测试是 agentic workflow 的限速因素**："当你让 agent 开始做大量事情，任何测试不完善的东西都会随机地退化。你和 agent 交付的东西越多，情况就越糟。"

**Centaur** 用专职测试工程师 + 持续随机化测试，做到了每年 <1 个重大用户可见 bug，**没有默认 code review，没有单元测试**。结论："LLM 极大放大了测试与开发速度，但只在人类专业知识的引导下……朴素的 prompting 和汇总型基准指标几乎无用。"并且："从 agent 身上获得价值的很大一部分，似乎是**对其失败模式有某种理解，然后绕开它们**。"

**产出物降低误报**：为 UI bug 生成视频/截图降低误报率；让 agent **审查该产物**进一步降低；请求独立视角降低得更多。

## 2. Martin Fowler 站点（2026）

**Kief Morris, "Humans and Agents in Software Engineering Loops"（2026-03-04）** —— "on the loop" 而非 "in the loop" 的规范表述。核心主张：
- 逐行 code review 门禁让人成为瓶颈，且产生"混杂"的生产率结果
- **shift left**：agent 在能自己判断质量时能产出更好的代码，所以**告诉它我们在看什么**
- 控制 how-loop 的规格、质量检查与工作流指引**就是 harness**，构建与维护它是"Harness Engineering"
- 自我改进飞轮：把生产数据、用户旅程日志、商业结果喂回来；agent 审阅结果并推荐 harness 变更，人类先交互式分诊，再评分与自动应用

https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html

**Martin Fowler, Fragments（2026-03-19）**
- code review **不是**捕捉 bug 的机制；它关乎引导代码库与人际沟通
- 可观测性是未来的"IDE"：**测试帮你应对已知路径，而现实总把你带进未知**
- 关于 review-by-exception：**保留一小份例行变更的随机抽样供人工审阅，专门用于检验风险分类器是否漏掉了架构性或安全性变更**——"否则这个流程会对自己从未检视过什么变得非常自信"

https://www.martinfowler.com/fragments/2026-03-19.html

**Birgitta Böckeler, "How far can we push AI autonomy in code generation?"（2025-08-05）**
agentic Spring Boot 实战中，模型"会生成我们没要求的功能，对需求空缺做出随意假设，并且**在测试失败时宣告成功**"。有效的缓解：
- 一个**审阅 agent** 对照原始 prompt 检查产出（"LLM 在第一次生成之后，被要求审阅它创建的东西时，通常相当擅长推理其作品的忠实度"）
- 经 MCP 提供的**参考应用**，放大编码标准并支持**参考漂移检测**
- **静态代码分析**（"它能比人工审阅快得多地浮现出代码问题的基线"）
- **频繁重启会话**（会话越长结果越"时好时坏"）

硬限制："LLM 总有办法绕过确定性检查点……我可以想象它们仍然能删除或跳过测试。"结论："AI 还**不能**在无人监督下创建和维护一个可维护的业务软件代码库。"

https://martinfowler.com/articles/pushing-ai-autonomy.html

**Unmesh Joshi（what/how loop）** —— TDD 是一种**设计策略**，它让 what/how 反馈回路显式化；没有稳定的抽象词汇表，"LLM 生成的代码趋于过程式"；推着它重构又摆到另一个极端。"我留下的代码，是我能有信心解释、测试和修改的代码。"用 LLM 为"覆盖率"生成测试没有意义。

https://martinfowler.com/articles/convo-what-how.html

**Korny Sietsma, "Agentic AI and Security"（2025-10-28）**
- **Lethal Trifecta**（敏感数据 + 不可信内容 + 对外通信）
- "最重要的是做小步、可控、可被人审阅的事"
- 拆分任务 **Think → Research → Plan → Act** 以压低上下文
- 不可信 agent 跑在容器里
- "**审查所有输出是你的责任**——检查虚假命令、被篡改的内容，当然还有 AI 垃圾"

https://martinfowler.com/articles/agentic-ai-security.html

## 3. Anthropic / Nicholas Carlini —— 验证器的教训

来源：https://gokawiil.com/article/252557

从 C 编译器实验："**任务验证器必须近乎完美，否则 Claude 会去解决错误的问题。**"他们**没有**让 Claude 自评；而是用 **GCC 作为已知良好的 oracle**。大部分精力花在设计环境/测试脚手架，"**好让它不用我在旁边也能自己定位方向**"。

架构刻意极简：8 行 bash（死循环）、`current_tasks/` 里的 git lock 文件做协调、**没有编排 agent、没有消息队列、没有共享内存**；测试脚手架**本身就是**通信通道。子技术：GCC-oracle 二分（把 Linux 内核构建这个巨型集成测试切分给多个 agent）、`--fast` 确定性逐 agent 测试采样、grep 友好的 `ERROR: reason` 同行格式、外部超时。Opus 4.5 是"第一个跨过门槛的"，Opus 4.6 推进到"能编译 Linux"。

**独立审计（John Regehr, 2026-03）** —— 目前可得的最强外部验证：https://john.regehr.org/writing/claude_c_compiler.html

用 Csmith + YARPGen 对该编译器做对拍，只把**缩减后的测试用例与参考编译器**交给 Codex（gpt-5.3-codex high），零指引，每次要求它产出一个回归测试。结果：先从 YARPGen 拿到 11 个修复（约 20 万测试、零误编译），再从 Csmith 拿到 18 个，再从 YARPGen v2 拿到 5 个。**Codex 从来不是瓶颈**，每个修复 15–30 分钟。Regehr 提出的注意事项："我这份 CCC 是对的吗？完全不可能有问题"；"Rust 代码质量低于专家水平"；"程序员部署自己从未亲手验证过的软件，这个想法令人担忧。"

二手佐证：某 LangChain harness 改动（仅加验证与反馈、同一模型）把一个基准从 **52.8% 移到 66.5%**（**UNVERIFIED**，转述）。

## 4. Thoughtworks Technology Radar（连续三卷）

| 条目 | 卷 / 日期 | 环 | 要点 |
| --- | --- | --- | --- |
| Complacency with AI-generated code | v32 / 2025-04 | **Hold** | GitClear：重复代码与 churn 上升，重构活动**下降**。变更集越大审阅越不可能，"我们要去操心"的意愿下降 |
| Replacing pair programming with AI | v32 / 2025-04 | **Hold** | 缺少同等的收益 |
| AI-friendly code design | v32 / 2025-04 | Assess | 表达性命名提供领域上下文；模块化限制上下文；DRY 保持行为一致。"目前最好的 AI-friendly 模式与既有最佳实践一致" |
| **AGENTS.md** | v33 / 2025-11 | Trial | "本质上就是给 agent 读的 README"，无必填字段 |
| **TCR（Test && Commit \|\| Revert）** | v33 / 2025-11 | Trial | 测试失败即自动回滚——一个**确定性**护栏 |
| Anchoring coding agents to a reference application | v33 / 2025-11 | Assess | 活的、可编译的代码库作为真相来源，使标准默认传播到新仓 |
| **Model Context Protocol** | v33 / 2025-11 | **Adopt** | "驱动 agent 的终极集成协议" |
| Context engineering | v33 / 2025-11 | Assess | "对优化行为与资源消耗至关重要" |
| Team of coding agents | v33→v34 | Assess | 编排者 + 角色专精 agent；子 agent 支持已成标配；Claude Code 加入 agent teams |
| Coding agent swarms | v34 / 2026-04 | **Caution** | "昂贵且远未成熟"。两大标志性实验（C 编译器、Cursor 浏览器）**都选择了规格细致、测试完备的用例**——"不代表典型的产品开发" |
| Sandboxed execution for coding agents、Agentic RL environments、Architecture drift reduction、Code intelligence as agentic tooling、Context graph、Feedback flywheel、Ralph loop、Skills as executable onboarding documentation | v34 / 2026-04 | Assess | **2026 年的议程是关于 harness，不是模型** |
| Curated shared instructions for software teams | v34 / 2026-04 | **Adopt** | prompt 库 → 指引文件**烘焙进服务模板仓库**，使 AI 指引随每个新服务一起交付 |
| v34 主题 | 2026-04 | — | (1) 在 agentic 世界中评估技术；(2) **保留原则、放弃模式**；(3) 约束贪求权限的 agent；(4) **给编码 agent 套上缰绳**。Rachel Laycock："我们所处的拐点与其说关乎技术，不如说关乎**技艺**。"预警：OpenClaw —— 不受约束的 agent、prompt injection / lethal trifecta、爆炸半径 |

## 5. 其他实践者

**Matthew Skelton**（Conflux，《Team Topologies》合著者）："AI 没有消除对快速反馈回路与软件护栏的需求——它让它们比以往更重要。"对多仓调试直接相关的可运维性模式："日志成为应用状态的连续轨迹，每个有趣的执行点都有足够唯一的标识符……**事务标识符用来跨组件、服务与队列追踪调用，以便事后重建分布式调用**"。还要跟踪依赖并区分**阻塞与非阻塞**依赖；用 CodeScene 之类工具检测隐藏耦合。

**Simon Willison**：选择核心编码 LLM 工具"主要看它们是否能安全地运行并迭代我的代码"。

**Loop engineering**（Peter Steinberger、Boris Cherny、Addy Osmani）："你不再应该 prompt 编码 agent。你应该设计 prompt 你 agent 的回路。"约束在验证器："**一个回路的质量上限就是它闭合所依赖的信号的质量。**" `Stop` hook + 独立评估模型的 `/goal`；Kent Beck 的"genie 会照字面满足你的愿望，而非精神"。

**Addy Osmani**（agentic code review）：一个 agent 写、另一个审、第三个判时，"你得到的是一圈**盲点高度相关的模型**，尤其当它们来自同一家族时"。"一个自信的'看起来不错'而其中没有任何人，是**借来的自信**"。"没有用户"是推迟审阅的许可，**不是跳过验证的许可**。

**Abhishek Murthy**："日志是原材料。链路是关联。指标是压力。**没有任何一个自动变成调试器。**"主张用确定性的故障档案 + 产物清单 + 重放计划替代模型生成的摘要，并**把缺失信号当作一等公民**（"如果没有第一个 stdout chunk……这种缺失应当作为一个调试器状态出现。否则每个前置失败都表现为空白页"）。https://abhishekmurthy.com/posts/logs-are-not-a-debugger/

**实践 harness 检查表**（13Labs，综合 Claude Code hooks / Cursor hooks / Codex config）：
- 一个 `verify` 脚本串起 typecheck + lint + test，在第一个失败处非零退出（**"给 agent 三个可选检查，它会只跑一个"**）
- **控制在约 90 秒内，输出要短**——先打印 400 行通过再打那一个失败的 runner 是在**主动对抗**你
- hook 应该是**确定性**的，而 CLAUDE.md 是建议性的
- 警惕 `tee` 吞掉退出码
- 限制轮数——"在同一道门禁上失败五次的 agent 没有收敛，第六次只是花钱学到零"

## 6. 综合：可迁移的原则

| # | 原则 | 支撑证据 |
| --- | --- | --- |
| P1 | **层级收窄必须强制**，后一级不得跳过前一级的候选集 | BugCerberus：去掉文件级定位 → 语句级 Top-5 −94.3% |
| P2 | **结构优于表面相似**，且在训练分布之外优势更大 | LocAgent 92.70%；Multi-CoLoR 在 QML 上 +29.1 Acc@5；GREPO 的 GNN 全面胜 IR/LLM |
| P3 | **SBFL/遥测是搜索循环里的提示，不是答案** | AutoCodeRover 最终采纳 SBFL 排名 3 与 5 而非第 1；RCLAgent 单次请求超过 SOTA Recall@10 |
| P4 | **传统 FL 与 LLM 推理都需要**：前者败于真实噪声，后者败于因果 | AetherLog：纯 LLM 因时间近因偏置停在症状（"disk not ready"）而错过根因（`nvme timeout`） |
| P5 | **组织记忆是最便宜的未开采定位信号** | Multi-CoLoR 的 Similar-Issue-Context 同时提 Acc@5 与降工具调用；Kept +33–63%；MULocBench |
| P6 | **验证器是瓶颈，其质量决定回路质量上限** | 同模型更好 harness：52.8%→66.5%（UNVERIFIED）；Carlini："验证器必须近乎完美"；Regehr：finder 侧已不是瓶颈 |
| P7 | **必须由你提供验证器，不能让 agent 自评** | Dan Luu：agent 在对抗性测试上"痛苦地糟糕"；Default > TDD > skills；Active-SWE：测试多 ≠ 测试有效 |
| P8 | **度量正确的量**：单测通过率掩盖过度编辑 | PDB：>76% 单测通过 vs ≤45% 编辑精度，排名倒挂 |
| P9 | **固定基准是衰减的仪器** | Verified 只给 issue 文本即 76%；SWE-rebench 同模型 39.7% vs 21.3% |
| P10 | **跨异构候选生成器的选择是未充分利用的杠杆** | Barrel of Monkeys 66.2% vs 最佳成员 62.8% vs 单系统 57.4%；混合验证器 42–43% 各自饱和、组合 51% |
| P11 | **被动索引帮单轮工具，可能害自主 agent** | OpenHands RepoMap 问题：可能不完整的索引导致过度信任而停止探索；Claude Code 完全无索引 |
| P12 | **多仓的结构必须是契约而非仅符号，且要有证据与置信度评分** | SCIP 不含 manifest；Atlas/RepoHelix/code-system-graph/grafel 全部显式建模契约边并把缺失证据表为一等 |
| P13 | **仓库路由是独立第一步；层级摘要优于原始代码 RAG** | DNext Pass@10 0.82 / MRR 0.50；去掉目录层 MRR −54% |
| P14 | **shift left 并交付产物；on-the-loop 优于 in-the-loop** | Fowler/Morris；Dan Luu 的截图/视频实验；Osmani 的相关盲区；Skelton 的关联 ID |

## 7. 直接转化为本项目的决策

| 实践建议 | 本项目实现 |
| --- | --- |
| 验证器必须近乎完美、不能自评 | `cross-repo-verifier` 为独立只读 agent，`temperature: 0.0`，禁止编辑；`repo-fixer` 不得自评 |
| harness 应该是确定性的，且第一个失败即停 | 每仓 `topology.json` 的 `validation[]` 是 argv 数组白名单；一个 `verify` 串起 typecheck+lint+test |
| 用 `deny` 而非 `ask` 做真约束（`--auto` 会把 ask 变 allow） | `opencode.json` 与每个 agent 的 bash 权限均为 `"*": "deny"` + 白名单 |
| 小步、可审阅；限制重试 | 编排器 `steps: 60`，修复器 `steps: 50`，且"同一道门禁失败两次后停止重试并上报" |
| agent 极擅自我批评"看起来不错"，需独立视角 | 编排器自身 `edit`/`write` 全 deny，只能路由与汇总 |
| 缺失信号要作为一等公民出现 | `topology.json` 的 `coverage.staleRepos` / `unknownEdges`；verifier 把低置信判为 `unverified` 而非 `pass` |
| 事务/关联 ID 用于事后重建分布式调用 | `cross-repo-localization` 要求以 request/trace ID 而非症状做关联 |
| 契约与配置是一等定位目标 | `repo-router` 只读契约摘要而非 grep 代码 |
| 评估路由用覆盖度而非 top-1 | `repo-router` 输出至多 5 个候选 + 显式排除理由 |
| 团队共享指引烘焙进模板 | 本目录的 agents/skills 即为可复用模板 |
| agent 上下文要小，原始产物落盘 | 每仓一个全新子会话（ChainSWE：累积历史反而更差），产物写 `.runs/<id>/` |

## 8. 来源

**Dan Luu**：https://danluu.com/ai-coding/ · https://danluu.com/agentic-testing/ · https://danluu.spicytakes.org/post/2026-07-01-ai-coding · https://www.samcodeman.com/writing/how-well-do-agents-use-tests（26 条件评测转述）

**Fowler 站点**：https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html · https://infrastructure-as-code.com/posts/humans-on-the-loop.html · https://www.martinfowler.com/fragments/2026-03-19.html · https://martinfowler.com/articles/pushing-ai-autonomy.html · https://martinfowler.com/articles/convo-what-how.html · https://martinfowler.com/articles/llm-and-dsls.html · https://martinfowler.com/articles/agentic-ai-security.html

**Thoughtworks**：https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/2025/04/tr_technology_radar_vol_32_en.pdf · https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/2025/11/tr_technology_radar_vol_33_en.pdf · https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/2026/04/tr_technology_radar_vol_34_en.pdf · https://www.thoughtworks.com/radar/techniques/team-of-coding-agents · https://www.thoughtworks.com/radar/techniques/coding-agent-swarms

**验证器实验**：https://gokawiil.com/article/252557（Carlini，16 个 Claude agent 造 C 编译器）· https://john.regehr.org/writing/claude_c_compiler.html（Regehr 审计）

**其他**：https://matthewskelton.com/all-videos-and-podcast-episodes/un-broken-logging-the-foundation-of-operability-operabilityio-2014 · https://speakerdeck.com/matthewskelton/practical-operability-techniques-for-teams-conflux-continuous-lifecycle-london-2018 · https://www.oreilly.com/radar/agentic-code-review/（Osmani）· https://abhishekmurthy.com/posts/logs-are-not-a-debugger/ · https://juanjofuchs.com/ai-development/2026/06/16/loop-engineering-for-the-rest-of-us.html · https://danielthegoldman.com/blog/agent-loops-claude-code-loop-engineering/en/ · https://www.13labs.au/guides/ai-coding-agent-harness-hooks-verification