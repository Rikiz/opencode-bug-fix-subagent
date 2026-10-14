# Evaluation harness

Purpose: measure whether the `issue-fix` agent actually fixes things, and whether each
part of it earns its keep. A case that fails here is a broken fixture, not a failed agent —
that is what `--validate` is for.

## Case layout

```
eval/cases/<case-id>/
  case.json         metadata + how to build, run, and score the case
  ticket.md         the untrusted ticket text handed to the agent
  repo/             the repository as handed over, with the defect already present
  oracle/           hidden tests; copied into the workspace untracked at run time
  reference.patch   the human fix; used only by --validate
```

`case.json` fields:

| field | meaning |
|---|---|
| `id` | case identifier, also the result filename |
| `language` | python / javascript / java / go / rust / c / cpp |
| `type` | `bug` or `feature` — features must be rejected, not implemented |
| `issue_clarity` | 0-3, how much usable information the ticket carries (C36) |
| `test_coverage` | 0-3, how well the existing suite would catch this (C36) |
| `ticket`, `repo`, `oracle` | paths |
| `test_cmd` | the oracle command; exit code decides pass/fail |
| `reference_patch` | the human fix |
| `toolchain` | binary that must be on PATH, else the case is skipped |

Oracle discipline: an oracle may assert only what the ticket claims, plus behaviour that
already worked before the defect. Asserting unclaimed behaviour (CRLF handling, empty
input) makes a correct patch look wrong and teaches the agent to over-fit.

## Running

```bash
eval/run-case.sh --validate                    # fixture self-check, all cases
eval/run-case.sh --validate py-paginate-empty-page
eval/run-case.sh --eval py-paginate-empty-page --model provider/id --repeats 3
```

`--validate` copies the repo, runs the oracle (must fail), applies `reference.patch`,
runs it again (must pass). It needs no model and no network.

`--eval` copies the repo into a temp dir, makes a git base commit, copies the oracle in
untracked, runs the agent headlessly, then scores with the oracle and appends one line to
`eval/results/<case-id>.jsonl`:

```json
{"case":"py-paginate-empty-page","run":1,"language":"python","terminal_state":"FIXED","oracle_passed":true,"repro_test_added":true,"changed_files":"invoice/billing.py tests/test_repro.py"}
```

`--eval` needs a real provider. `opencode run` executes as a non-interactive agent, so
`ask` permissions cannot be answered; the harness passes `--auto`, so run cases inside a
container.

The oracle is copied into the workspace **after** the agent finishes, never before. An
earlier version of this harness left it in place, and on the Java case the agent found the
oracle, reasoned about whether it was trustworthy, and adopted it as its own repro test.
That is the same behaviour measured in sealed environments, where agents still go looking
for hidden grading material in roughly four runs out of five — which is why `oracle_leak`
is recorded per run.

Infrastructure failures are recorded separately from agent failures: `abort_reason`
carries `provider_bad_request`, `provider_server_error`, `provider_free_tier_subagent`,
or `command_not_found`, and such runs get `terminal_state: ABORTED_INFRA` instead of being
scored. A run that dies mid-pipeline is not a wrong patch.

## Metrics to report

Per language and per difficulty — never pooled. Multi-language averages are meaningless:
the same system scores 36.20% on Python and 1.40% on JavaScript.

| metric | definition | why it matters |
|---|---|---|
| resolved | oracle passes after the run | the headline number |
| terminal state | one of the seven states | `NOT_A_BUG` on a bug case is a wrong answer |
| repro validity | agent's own repro test fails on base, passes on the patch | a repro that never went red proves nothing |
| evidence-free closure | resolved but no discriminating check existed | the dominant failure mode |
| diff precision | changed lines attributable to the root cause | guards against over-fitting |
| correct abstention | `OUT_OF_SCOPE` / `NEEDS_INFO` on a case that deserves it | rewards not-guessing |
| oracle leak | the run read the oracle or evaluation files | in a sealed environment agents still reach for hidden grading material four runs in five |
| cost | wall clock, tokens, tool calls | budget discipline |

Difficulty is defined by measured pass rate across repeated runs, not by human judgement
(human difficulty labels correlate with measured difficulty at only r=0.436).

## Ablation ladder

Each tier must beat the tier below it or be cut.

| tier | contents |
|---|---|
| B0 | the built-in `build` agent, same ticket, no gates |
| A0 | `issue-fix` as shipped in M1, no independent review |
| A1 | A0 + `issue-fix-verifier` |
| A2 | A1 + plugin-enforced gates (M2) |
| A3 | A2 + `issue-fix-investigator` (M3) |
| A4 | A3 + repro hardening against wrong-fix mutants (M3) |

Run every tier on every case at least three times; single runs do not separate a real
effect from noise.

## M1 end-to-end results

One run per case, 2026-10-13, default model on the OpenCode free tier.

| case | terminal state | oracle | repro test added | oracle leak | notes |
|---|---|---|---|---|---|
| `java-invoice-rounding` | `FIXED` | pass | yes | no | both verifier calls returned PASS |
| `js-csv-trailing-row` | `FIXED` | pass | yes | no | fix was `-1` line plus a test |
| `py-paginate-empty-page` | `FIXED` | pass | yes | no | first run, before the oracle was moved out of the tree; diff was −2 lines, better than the reference patch |
| `py-paginate-empty-page` (retries) | `ABORTED_INFRA` | — | partial | no | `provider_bad_request` after the free-tier quota was spent |
| `go-reverse-aliasing` | not run | — | — | — | no Go toolchain |
| `rust-percent-plus` | not run | — | — | — | no Rust toolchain |

Three languages solved end-to-end, each one attempt, each with a repro test the agent wrote
itself. Single runs on six trivially-seeded defects say almost nothing about field
performance: this table is a plumbing check, not a benchmark. Real measurement needs the
M4 case set and repeated runs.

## Current cases

| case | language | clarity | coverage | toolchain |
|---|---|---|---|---|
| `py-paginate-empty-page` | python | 2 | 1 | python3 ✅ |
| `js-csv-trailing-row` | javascript | 2 | 0 | node ✅ |
| `java-invoice-rounding` | java | 2 | 0 | javac ✅ |
| `go-reverse-aliasing` | go | 3 | 0 | go ⏳ not installed |
| `rust-percent-plus` | rust | 3 | 0 | cargo ⏳ not installed |

M4 target is roughly four cases per language, plus two negative cases (a feature request,
and a ticket whose defect cannot be reproduced) to measure correct abstention.