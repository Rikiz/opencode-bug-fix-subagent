# OpenCode Bug Fix Subagent

An issue-to-fix harness for OpenCode. It turns a reviewed GitHub issue into a bounded diagnosis/fix session, captures evidence, runs repository-owned validation, and lets CI open a reviewable PR.

```bash
npm test
npm run bugfix -- --issue-file ./issue.json --model provider/model --dry-run
```

The GitHub workflow is intentionally opt-in: a repository member comments `/bugfix` on an issue.

## The `issue-fix` extension

A separate, newer agent that takes a pasted bug ticket and fixes it in the working
directory, with gates that a prompt alone cannot enforce.

```bash
scripts/install-issue-fix.sh                 # copy into ~/.config/opencode
scripts/install-issue-fix.sh --link          # symlink, for development
scripts/install-issue-fix.sh --uninstall     # remove exactly what it installed

cd <repo> && opencode
#   Tab -> issue-fix, then paste the ticket
#   or:  /issue-fix <paste the ticket>
```

Design, evidence, and the measured OpenCode 1.19.0 findings it rests on:
**[docs/designs/opencode-issue-fix-extension.md](docs/designs/opencode-issue-fix-extension.md)**.
Evaluation harness and metrics: **[eval/README.md](eval/README.md)**.

What it does, in one line: intake → baseline → localize → **reproduce** → **diagnose** →
patch → verify → minimize → **independent review** → report, where the three bold stages
are hard gates — no source edit before a stable repro exists, no `FIXED` without evidence
that distinguishes fixed from unfixed, and no self-certification. The outcomes are seven,
and four of them are honest refusals rather than patches.

### Which agent should I use?

| asset | when |
|---|---|
| `issue-fix` + `/issue-fix` | **the supported path** — a pasted ticket, one repository, a verified minimal patch |
| `repair` → `referee` | older single-session loop; its `contract-checker` subagent does not exist and `probe` is `primary`, so it cannot be dispatched |
| `probe` | read-only triage when you want a diagnosis and no edits |
| `bin/bug-fix.js` | older headless harness; it invokes the deleted `bug-fix` agent and does not work as-is |
| `.github/workflows/bug-fix.yml` | older CI path; points at that same harness |

New and old assets coexist on purpose. The `issue-fix` agent reaches only
`issue-fix-verifier` and only loads `issue-fix-*` skills, so the two families cannot call each
other.

Known holes in the older assets, recorded but not changed: custom agents start from a
`* → allow` baseline, so `repair`/`probe`/`referee` have `websearch` effectively allowed,
and their `read: "allow"` overrides the built-in `.env → ask` protection. `issue-fix` writes
an explicit permission table instead.

## Documentation

Start from **[docs/README.md](docs/README.md)** — the index and reading order for everything under `docs/`.

- [Bugfix extension design](docs/designs/opencode-issue-fix-extension.md) — the current extension: stages, gates, permissions, measured findings, milestones
- [Multi-repo issue-fix flow design](docs/designs/multi-repo-issue-fix-flow.md) — multi-repo variant: role topology, S0–S7 stages, evidence ledger, ablation plan
- [OpenCode custom agent internals](docs/opencode-agents/README.md) — how agents/permissions/subagent dispatch actually work
- [Bug-fix methodologies](docs/bugfix-methodology/README.md) — industry/academic survey with a 54-entry traceable claims table
- [Multi-repo bug localization](docs/multi-repo-bugfix/cross-repo-localization.md) — the five cross-repo localization stages and toolchain
- Earlier plans: [TUI/agent route](docs/opencode-tui-agent-plan.md) · [SDK/service route](docs/opencode-bug-fix-plan.md) · [initial research](docs/bug-fix-agent-research.md) · [workflow diagnosis](bugfix-multi-agent-diagnosis.md)