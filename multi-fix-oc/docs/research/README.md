# 调研索引

调研完成于 2026-10，针对两个问题：**(A) 给定一个问题单，agent 能否自动定位并修复**；**(B) 不知道问题在前端、后端、网关还是别的仓时，如何定位与修复**。

| 文件 | 内容 | 对应问题 |
| --- | --- | --- |
| [benchmarks.md](benchmarks.md) | SWE-bench 全家桶、多语言扩展、传统 APR 语料、定位专用与 2025–26 评测基准 | A |
| [localization-and-rca.md](localization-and-rca.md) | LLM 源码定位、日志/链路/配置根因分析、多缺陷定位 | A |
| [multi-repo-and-microservices.md](multi-repo-and-microservices.md) | BeyondSWE、DNext、CodeScaleBench、SCIP、Atlas/RepoHelix 等跨仓工具，以及**确实不存在的东西** | **B** |
| [practitioner-methodology.md](practitioner-methodology.md) | Dan Luu 的实验、Fowler 站点、Thoughtworks Radar、Carlini/Regehr 验证器实验、Skelton 可观测性、Osmani 盲区、harness 检查表 | A + B |

综合产物：[../multi-repo-fix-workflow.md](../multi-repo-fix-workflow.md)——把上述全部证据收敛成一套可在 opencode 下运行的多仓修复流程。

## 五个最该记住的数字

1. **SWE-bench Verified 已污染**：只给 issue 文本、不给代码，Claude 3.5/3.7 的"定位"准确率 76%/73%；在同规模非 SWE-bench 集上塌到 17–44%。→ 榜单分数不是能力上限的可靠估计。
2. **SWE-bench Pro 最佳 Pass@1 仅 43.6%**，商业集 <20%。→ 企业级长程任务比榜单难得多。
3. **PDB：单测通过率 >76%，编辑级精度 ≤45%，且排名倒挂。** → 只看测试通过率会选错系统、掩盖过度编辑。
4. **DNext（唯一以"哪个仓"为主任务）：Pass@10 = 0.82，MRR = 0.50**；去掉目录层 MRR −54%。→ 仓库路由是独立阶段，层级摘要不可省。
5. **ChainSWE：多缺陷连续处理最多退化 70%，摘要与子 agent 编辑反而更差。** → 每仓一个全新会话，不共享累积历史。

## 三个必须承认的空白

1. **没有公开的"issue → 哪个仓"基准**（DNext 专有）。跨仓路由的能力必须自建评测集来证明。
2. **没有跨仓 patch 基准**，也没有 API 契约 / schema 不一致这一缺陷类别的基准。
3. **服务网格 / 网关 / 路由器的根因在代码修复文献中完全未被处理**——所有网格级 RCA 都是遥测-based；没有人把"网关返回 503 是因为上游探针路径被改写"连到第二个仓库的代码编辑上。

## 三条设计原则（贯穿全套文档）

- **定位是层级问题，不是一跳检索。** 去掉文件级定位会损失 94.3% 的语句级精度。
- **验证器质量决定回路质量上限。** 不能让写补丁的 agent 给自己打分。
- **缺失证据是一等公民。** 置信度低、覆盖不全、拓扑陈旧都必须显式报为 `unverified`，而不是默认为"没问题"。

## 诚实性说明

调研于 2026-10 完成。所有带 URL 的条目均在调研时直接读取一手来源；无法核实者显式标注 **UNVERIFIED**，未编造 arXiv ID。两处已知不一致：BeyondSWE 的单实例规模在 repo card（5.6 文件 / 209.9 行）与摘要（10.9 文件 / 1039 行）间矛盾；LangChain harness 的 52.8%→66.5% 数字为二手转述。