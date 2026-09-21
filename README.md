# OpenCode Bug Fix Subagent

An issue-to-fix harness for OpenCode. It turns a reviewed GitHub issue into a bounded diagnosis/fix session, captures evidence, runs repository-owned validation, and lets CI open a reviewable PR.

```bash
npm test
npm run bugfix -- --issue-file ./issue.json --model provider/model --dry-run
```

See [the implementation plan](docs/opencode-bug-fix-plan.md) and [industry research](docs/bug-fix-agent-research.md). The GitHub workflow is intentionally opt-in: a repository member comments `/bugfix` on an issue.
