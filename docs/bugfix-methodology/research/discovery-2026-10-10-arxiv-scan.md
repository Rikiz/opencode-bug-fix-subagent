# arXiv bug-fixing scan — 2026-06 / 2026-07 / 2026-08 (cs.SE)
Generated 2026-10-10. 40 items, all IDs verified HTTP 200 via `curl -sS -o /dev/null -w "%{http_code}" -L --max-time 20 https://arxiv.org/abs/<ID>`.

| arXiv ID | Title | Published | First 3 authors | Contribution |
|---|---|---|---|---|
| 2608.25661 | From General Agents to RCA Experts: A Self-Evolving Harness for Root Cause Analysis | 26 Aug 2026 | Haiyu Huang; Jiewei Lyu; Zhihan Jiang | Self-evolving harness that turns a general coding agent into an RCA specialist instead of building a bespoke agent. |
| 2608.25920 | Repair or Resample? Rethinking Failure Debugging in LLM Multi-Agent Systems | 26 Aug 2026 | Zhongwen Luan; Xiaoyu Zhang; Ming Hu | Controlled replay/intervention framework (SymTrace) + SymFail dataset proving that rerun-and-resample MAS repair is stochastic, not causal; symptom-driven intervention raises repair rate 192%. |
| 2608.21310 | Beyond Fault Localization: A Trajectory-Level Study of LLM Agents for Microservice Root Cause Analysis | 21 Aug 2026 | Qisheng Lu; Aoyang Fang; Junjielong Xu | Moves microservice RCA evaluation beyond endpoint accuracy to trajectory-level evidence and fault-propagation analysis. |
| 2608.18588 | AppEval: A Unified Benchmark for LLM-Based Mobile Application Repair in ArkTS, Swift, and Kotlin | 19 Aug 2026 | Bang Xie; Hao Liu; Zhenyu Shi | Unified mobile-app repair benchmark (ArkTS/Swift/Kotlin) that tests repairs across the real build-install-launch-test boundary. |
| 2608.18595 | OdinEval: A Reproducible Benchmark for LLM-Based Program Repair in the Odin Programming Language | 19 Aug 2026 | Bang Xie; Hao Liu; Zhiyuan Peng | Reproducible repo-level program-repair benchmark for the Odin systems language, binding issues to base/fix commits and regression tests. |
| 2608.17018 | ORCA: Observability-Grounded Program Repair for Microservice Incidents | 17 Aug 2026 | Yuanchen Gao; Yifang Tian; Yiran Li | Observability-grounded APR pipeline that closes the telemetry-diagnosis-to-patch-generation gap for microservice incidents. |
| 2608.15579 | Kozuchi Agent: A Language-Agnostic Open-Weight Agent for Software Repair | 16 Aug 2026 | Mehdi Bahrami; Kosaku Kimura; Satoshi Munakata | Language-agnostic open-weight repair agent plus CI operation that turns bug reports into patches for industrial teams. |
| 2608.15242 | LongRCA Bench: Root-Cause Localization in Long-Horizon Agent Trajectories | 15 Aug 2026 | Yunfei Zhang; Boyu Feng; Changhua Pei | Benchmark of 1,140 complete failed long-horizon agent trajectories for root-cause localization. |
| 2608.14065 | Rethinking Automated Program Repair: The Impact of Bug Complexity, Fault Localization, and LLM Cost-efficiency | 14 Aug 2026 | Junchi Liu; Ali Bigdeli; Roya Daneshi | Empirical decomposition of LLM APR effectiveness by bug complexity, fault-localization quality, reasoning effort and cost-efficiency. |
| 2608.13292 | Refine After Generation: Toward Correct and Concise Patches in LLM-based Program Repair | 13 Aug 2026 | Wenqiang Luo; Jacky Keung; Xiaoyu Shi | Identifies patch verbosity as an overlooked APR failure mode and adds a refinement stage for correct and concise patches. |
| 2608.08968 | GALA: Graph-Augmented LLM Agents for Root Cause Analysis and Incident Response in Microservices | 10 Aug 2026 | Yifang Tian; Yaming Liu; Zichun Chong | Graph-augmented LLM agents that couple microservice RCA with downstream incident response instead of stopping at fault ranking. |
| 2608.05399 | Improving Debugging in Verification-Aware Languages Through Automated Fault Localization: A Case Study in Dafny | 5 Aug 2026 | Álvaro Silva; Isabel Amaral; João Pascoal Faria | Automated fault localization for verification-aware languages, with a Dafny case study turning verification failures into root causes. |
| 2608.02712 | Don't Regenerate, Debug: A Domain-Specific Agent for Repairing Near-Miss Hardware Operators | 3 Aug 2026 | Yansong Sun; Shenxiu Wu; Siyuan Chen | Domain-specific repair agent that debugs near-miss hardware kernel operators rather than regenerating them from scratch. |
| 2608.00692 | Vul4Py: Benchmarking Automated Vulnerability Repair in Python with Paired Exploit and Functional Oracles | 1 Aug 2026 | Tan Bui; Ting Zhang; Ferdian Thung | Python vulnerability-repair benchmark with paired exploit and functional oracles enabling head-to-head AVR comparison. |
| 2607.29658 | Reusing Past Repairs Through Hierarchical Trajectory Abstraction for Coding Agents | 31 Jul 2026 | Yisen Xu; Jiayuan Zhou; Ruiqi Pan | STAIR turns historical repair trajectories into hierarchical, reusable plans that steer future repository-level repairs. |
| 2608.02643 | CUADebug: Diagnosing and Repairing Computer-Use Agent Failures | 31 Jul 2026 | Weijia Zhang; Kunlun Zhu; Zeyi Liu | Five-category/30-subtype taxonomy for localizing root causes in computer-use-agent trajectories, plus guided re-execution repair. |
| 2607.26591 | MultiFixer: A Coordinator-Proposer Based Multi-Agent Framework For Fixing Multi-Hunk Bugs | 29 Jul 2026 | Haichuan Hu; Chunrong Fang; Ye Shang | Coordinator-proposer multi-agent framework targeting multi-hunk bugs that need coordinated edits across locations. |
| 2607.25651 | Demystifying Deep Learning Compiler Frontend Bugs: An LLM-Aided Empirical Study | 28 Jul 2026 | Xinyi Yuan; Wei Chen; Jinyi Liu | LLM-aided empirical study and taxonomy of deep-learning-compiler frontend bugs (fBugs). |
| 2607.17641 | Verify, Repair, Repeat, or Stop? Robust Stopping for Noisy Verify-Repair Loops in LLM Agents | 20 Jul 2026 | Yitao Wu; Si Shen; Rui Yang | Robust stopping rules for noisy verify-repair loops, where repair can damage already-correct plans and acceptance metrics mislead. |
| 2607.17722 | KernelDiag: Agent-Based Root Cause Diagnosis for Kernel Crashes | 20 Jul 2026 | Weijing Wang; Zan Wang; Dong Wang | Agent-based root-cause diagnosis for Linux kernel crashes reported by fuzzers. |
| 2607.15684 | Understanding Agent-Reactive Bugs at the Model-Harness Boundary: An Empirical Study of LLM Agent Issue Reports | 17 Jul 2026 | Jingyi Chen; Songqiang Chen; Hengcheng Zhu | Empirical study of a new bug class arising at the LLM/harness boundary in coding and framework agents. |
| 2607.14167 | Structured Feedback Improves Repair in an LLM Agent Loop | 15 Jul 2026 | Jaideep Ray; Ankit Goyal | VeriHarness: a code-controlled agent loop where external validators own acceptance, budgets and traces, improving repair. |
| 2607.12605 | Multi-Perspective Agentic Program Repair via Code Property Graphs and Temporal Execution Graphs | 14 Jul 2026 | Zhili Huang; Ling Xu; Hongyu Zhang | Multi-perspective agentic APR using code property graphs and temporal execution graphs to compress traces and diversify hypotheses. |
| 2607.11390 | TerraRepair: A Tool-Grounded LLM Agent for Infrastructure-as-Code Repair | 13 Jul 2026 | Minase Mekete Mengistu; Juri Di Rocco; Phuong T. Nguyen | Tool-grounded LLM agent that repairs Infrastructure-as-Code/Terraform misconfigurations using scanner feedback. |
| 2607.09007 | Benchmarking Large Language Models on Repairing Qiskit Programs using Bugs4Q | 10 Jul 2026 | Saumya Brahmbhatt; Mitali Hukkeri; Dongchan Kim | Re-validates the Bugs4Q benchmark (67 real Qiskit defects) with added executable tests for trustworthy LLM repair evaluation. |
| 2607.09123 | ReProAgent: Tool-Augmented Multi-Stage Agentic Generation of Bug Reproduction Tests from Issue Reports | 10 Jul 2026 | Quanjun Zhang; Yi Zheng; Ye Shang | Tool-augmented multi-stage agent that generates bug reproduction tests from issue reports as executable feedback. |
| 2607.04974 | A Comprehensive Study of Implementation Bugs in Multi-modal Agents | 6 Jul 2026 | Suwan Li; Lei Bu; Shangqing Liu | Comprehensive empirical study and taxonomy of implementation bugs unique to multi-modal agents. |
| 2607.05197 | Is Three the Magic Number? An Empirical Evaluation of LLM-Based Repair Loops | 6 Jul 2026 | Tobias Kiecker; Eik Reichmann; Hosung Kang | Empirical evaluation of how repair-loop iteration limits affect LLM-based artifact repair. |
| 2607.01788 | KRCA: An Efficient Root Cause Analysis System in Hyper-scale Microservice Systems via Agentic AI | 2 Jul 2026 | Jiamin Jiang; Jingfei Feng; Yu Luo | Agentic root-cause analysis system for hyper-scale microservice systems. |
| 2607.00562 | Towards Better Linux Kernel Fault Localization: Leveraging Contrastive Reasoning and Hierarchical Context Analysis | 1 Jul 2026 | Haichi Wang; Ruiguo Yu; Yesong Pang | Contrastive reasoning plus hierarchical context analysis for Linux kernel fault localization. |
| 2607.00820 | Knowledge-Enhanced Agentic Vulnerability Repair | 1 Jul 2026 | Sicong Cao; Hao Ma; Le Yu | Knowledge-enhanced agentic vulnerability repair that targets root-cause identification and prior-fix reuse. |
| 2607.00990 | SWE-Doctor: Guiding Software Engineering Agents with Runtime Diagnosis from Multi-Faceted Bug Reproduction Tests | 1 Jul 2026 | Yaoqi Guo; Yang Liu; Jie M. Zhang | SWE-Doctor uses multi-faceted bug reproduction tests for runtime diagnosis to steer SWE agents toward correct patches. |
| 2607.02606 | ChainSWE: Benchmarking Coding Agents on Multi-Bug Software Maintenance | 1 Jul 2026 | Qirui Jin; Lingching Tung; Kenan Li | ChainSWE benchmark for coding agents facing streams of related defects that carry state from one fix to the next. |
| 2606.30324 | How do Execution Features Improve Statistical Fault Localization? An Empirical Study | 29 Jun 2026 | Marius Smytzek; Andreas Zeller | Empirical study of whether data-flow, value and branch-condition execution features improve statistical fault localization. |
| 2606.30963 | Loc2Repair: A Framework for Evaluating the Impact of File-Level Issue Localization in Repo-Level LLM Repair | 29 Jun 2026 | Mohammad Nour Al Awad; Sergey Ivanov | Loc2Repair isolates file-level issue localization as a distinct variable in repository-level LLM repair pipelines. |
| 2606.29088 | Diff-Based Code Corruption using LLMs for Large-Scale Bugfix Benchmarking | 27 Jun 2026 | Balázs Szalontai; Ábel Szauter; Balázs Márton | LLM-driven diff-based code corruption to build large-scale, realistic bugfix benchmarks. |
| 2606.21963 | Holmes: Multimodal Agentic Diagnosis for Mixed-Language Mobile Crashes at Industrial Scale | 20 Jun 2026 | Jia Li; Wenyuan Ma; Ting Peng | Holmes: multimodal agentic diagnosis of mixed-language mobile crashes at industrial scale without local reproduction. |
| 2606.17612 | PracRepair: LLM-Empowered Automated Program Repair Inspired by Human-Like Debugging Practices | 16 Jun 2026 | Yu Cheng; Zhongxin Liu; Zhenchang Xing | PracRepair brings human-like debugging practice (dynamic evidence over static context) into LLM automated program repair. |
| 2606.07314 | QBugLM: An Agentic Benchmarking Framework for LLM-based Quantum Software Debugging | 5 Jun 2026 | An B. B. Pham; Hoa T. Nguyen; Muhammad Usman | Agentic benchmarking framework for LLM-based quantum software debugging, where bugs are silent rather than crashing. |
| 2606.05339 | A Taxonomy of Runtime Faults in Model Context Protocol Servers | 3 Jun 2026 | Joshua Owotogbe; Indika Kumara; Antonio Ken Iannillo | First taxonomy of runtime faults in Model Context Protocol servers, covering accepted-but-unenforced configuration faults. |

## Query terms that returned nothing useful

The arXiv **API** (`export.arxiv.org/api/query`) was unreachable for every task-specified term. Two distinct failures:

1. The literal command in the brief uses `http://`, which returns `HTTP=301 SIZE=0` (redirect to HTTPS, empty body, so the Atom XML is never returned).
2. Following the redirect (`-L`) returns `HTTP=429 SIZE=14` with body `Rate exceeded.` — reproduced for **every** one of the 15 requested terms: `bug fixing`, `automated program repair`, `fault localization`, `issue resolution`, `root cause analysis`, `vulnerability repair`, `patch correctness`, `code repair`, `debugging agent`, `SWE agent`, `test repair`, `crash repair`, `regression debugging`, plus `all:bug` and `cat:cs.SE`. Retries with 3s/12s/…/120s backoff over ~15 minutes never succeeded. Only pre-cached control queries (e.g. `all:electron`) returned HTTP 200, confirming the endpoint itself is alive and the failure is an origin-side throttle.

**Consequence:** no query term returned usable API results. The corpus was therefore built from the two sources that did respond:

- `https://arxiv.org/list/cs.SE/2026-06|2026-07|2026-08?show=2000` → HTTP 200, 999 KB / 1.29 MB / 1.17 MB, containing **624 / 808 / 715 entries** = 2,147 unique cs.SE papers (June–August 2026), with title, full author list, comments and subjects parsed from the listing HTML.
- `https://arxiv.org/abs/<ID>` → HTTP 200 per paper, supplying exact v1 submission date and abstract.

Note also that the listing URL given in the brief, `https://arxiv.org/list/cs.SE/2608`, is **HTTP 404**; arXiv uses the `YYYY-MM` form (`/list/cs.SE/2026-08`).

## Raw evidence

```
$ curl -sS --max-time 40 "http://export.arxiv.org/api/query?search_query=all:%22bug%20fixing%22&start=0&max_results=100&sortBy=submittedDate&sortOrder=descending"
HTTP=301 SIZE=0 REDIRECT=https://export.arxiv.org/api/query?search_query=all:%22bug%20fixing%22&...

$ curl -sS -L --max-time 40 "http://export.arxiv.org/api/query?search_query=all:%22bug%20fixing%22&start=0&max_results=100&sortBy=submittedDate&sortOrder=descending"
Rate exceeded.
HTTP=429 SIZE=14

$ curl -sS -L --max-time 40 "https://export.arxiv.org/api/query?search_query=all:electron&max_results=1"
  <title>arXiv Query: search_query=all:electron&amp;id_list=&amp;start=0&amp;max_results=1</title>
  <opensearch:totalResults>187346</opensearch:totalResults>
    <title>The electronic structure of cuprates from high energy spectroscopy</title>
HTTP=200 SIZE=2938

$ curl -sS -L --max-time 60 "https://arxiv.org/list/cs.SE/2026-06?show=2000"  -> HTTP=200 SIZE=999451  Total of 624 entries
$ curl -sS -L --max-time 60 "https://arxiv.org/list/cs.SE/2026-07?show=2000"  -> HTTP=200 SIZE=1290317 Total of 808 entries
$ curl -sS -L --max-time 60 "https://arxiv.org/list/cs.SE/2026-08?show=2000"  -> HTTP=200 SIZE=1167465 Total of 715 entries
$ curl -sS -L --max-time 60 "https://arxiv.org/list/cs.SE/2608"               -> HTTP=404

$ curl -sS -o /dev/null -w "%{http_code}" -L --max-time 20 "https://arxiv.org/abs/2606.05339"
200
... (all 40 final IDs returned 200; sample of the check loop:)
200 2608.25661
200 2608.25920
200 2608.21310
200 2608.18588
200 2608.18595
200 2608.17018
200 2608.15579
200 2608.15242
200 2608.14065
200 2608.13292
...
200 2606.05339

$ python3 parse_list.py list_2026-06.html list_2026-07.html list_2026-08.html > csse_all.jsonl
total unique: 2147
$ python3 parse_abs.py ids.txt
parsed 45, missing 0:
```

## Method

1. Fetched the three cs.SE monthly listings (`?show=2000`) and parsed all 2,147 unique entries (id, exact title, authors, comments, subjects).
2. Filtered by bugfix/debugging/repair/fault-localization keywords in title + comments (545 matches), then scored for core bugfix signal and demoted pure vulnerability-*detection*, exploitation and test-generation work.
3. Fetched each shortlisted paper's `/abs/` page and parsed the exact API-equivalent metadata (`citation_title`, `citation_author`, `citation_date`, submission history, `citation_abstract`) — 45/45 parsed.
4. Removed the 22 already-held IDs and the 28 already-in-candidate-set IDs (none of the 45 overlapped), then trimmed to 40.
5. Verified all 40 IDs resolve with the required `curl` HTTP-status check (40/40 = 200).
