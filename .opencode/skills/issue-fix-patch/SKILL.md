---
name: issue-fix-patch
description: "Use at stages S5 and S7 of the issue-fix workflow: make the smallest correct change at the root cause, follow project conventions, and strip everything that is not the fix"
---

# Patch and Minimize

## Before editing

1. **Mine the conventions.** Read the project's own instruction files, look at two or three neighbouring modules, check recent history on the files you are about to touch. Passing tests and correct-looking patches still violate this project's design constraints a third of the time, and generic guidance barely helps.
2. **Know the baseline.** Which tests already fail before you start? Only new failures matter later.
3. **Know the escape hatches.** Stop and ask the user when the fix needs a dependency change, build or CI change, a public API signature change, a data migration, or more than 5 files / 200 lines.

## The edit

- Change only what the root cause requires. Every hunk must be justifiable in one sentence that names the root cause or a requirement id.
- No refactor, no rename, no reformat, no import cleanup, no "while I was here".
- Follow the surrounding style: error handling, null handling, typing, naming, logging.
- Keep the change at the origin of the bad value, not at the place it surfaced.
- Do not add defensive code for cases that cannot occur — that is scope creep wearing a hat.
- Never modify an existing test's expectations. If a test is genuinely wrong, prove it from the spec or the ticket and say so explicitly in the report.

After editing: compile or type-check. A patch that does not build is not a candidate.

## Minimizing (S7)

This is a separate pass, not a reminder to be careful. Even well-instructed agents ship patches roughly twice the size of the human reference, and telling them "be minimal" in the prompt does not fix it — a dedicated pass does.

1. `git diff` against the base snapshot, plus the content of every new file.
2. For each hunk, ask: which root cause or `R<n>` does this serve?
   - no answer → delete it
   - "it makes the code cleaner" → delete it
3. Defensive guards, extra logging, reordering, renamed locals: delete unless the requirement demands them.
4. Re-run the verification after deleting. If anything breaks that used to pass, the deleted line was load-bearing — put it back and say why.

The goal is a diff where a reviewer cannot find a line they would question.

## Retrying

Do not repeat the same reasoning on the same span. Restoring source to the base snapshot and re-generating from the diagnosis beats re-editing the failed location by a wide margin.

Before a retry, write down four things:

1. **target** — the file:line you are changing this time, and why it differs from last time
2. **operation** — the concrete edit
3. **verification signal** — the exact command and the expected change in its output
4. **boundary** — what you will not touch

Keep the repro test across retries. It is the only thing that makes a retry comparable to the previous attempt.
