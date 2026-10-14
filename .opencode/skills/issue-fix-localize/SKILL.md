---
name: issue-fix-localize
description: "Use at stage S2 of the issue-fix workflow: narrow a bug to module, then top-3 files, then function, then edit point, using several independent evidence channels inside a fixed budget"
---

# Localize

Goal: a short, evidence-backed candidate list — not a root cause. You have a budget and you will not exceed it.

## Order of narrowing

1. **Module** — which part of the system owns this behavior?
2. **Files** — at most 3. Method-level localization is roughly six times more accurate than line-level, so stop at file granularity as long as you can.
3. **Symbol** — class, function, or type.
4. **Edit point** — only once a symbol is confirmed.

Method-level accuracy: 26% top-1 at function granularity versus 4% at statement granularity. Single-signal top-10 recall is under 50%. Budget: **5 candidates, one re-scope.**

## Evidence channels

Run at least three of these. They fail independently, which is exactly why you want more than one.

| Channel | How |
|---|---|
| Ticket cues | file, function, class, or line the reporter named |
| Error string | `grep` the exact message, the exception type, the log tag |
| Stack frames | read every frame; the top frame is a **starting point**, not the answer |
| Symbol graph | `lsp` references and call hierarchy for the symbols you suspect |
| History | `git log -S"<string>"`, `git log --oneline -- <file>`, `git blame` on the suspicious lines |
| Deterministic anchoring | for a hub function, list its callers; inject "called-by" facts so the ranking is not guesswork |
| Tests | the nearest existing test for the area; its name often names the contract |

History deserves weight: experienced developers spend most of their effort building the mental model and lean heavily on git history.

## Recording

```markdown
| # | file | symbol | line | why | evidence | confidence |
|---|------|--------|------|-----|----------|-----------|
| 1 | src/parse.py | parse_list | 42 | ... | traceback frame 3; grep "_parse_items" 2 hits; last touched 3 commits ago | high |
```

## Out of scope

- Do not edit anything here.
- Do not chase a single hypothesis past the budget. If five candidates are exhausted, re-scope once (change the evidence channel, not just the search terms), then hand off.
- A stack trace that points at a getter is usually not a getter bug.
