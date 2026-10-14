---
name: issue-fix-verify-report
description: "Use at stages S6, S8 and S9 of the issue-fix workflow: prove the fix with discriminating evidence, dispatch the independent verifier, and report honestly with graded evidence"
---

# Verify, Review, Report

Test output that the agent produced about its own patch is the weakest possible evidence. Verify against the world, not against your own narration.

## S6 — verification checklist

Gate G4 requires all of these.

1. **Repro goes red → green.** Run the repro three times, not once.
2. **No new failures.** Re-run the S1 baseline scope and diff the result against it. Pre-existing failures are context, not blockers.
3. **Test integrity scan.** Check that the diff contains no deleted, skipped, or loosened test, no raised timeout, no `xfail`, no bare `except: pass`, no swallowed assertion, and no expected value bent to match current output. Inspectors distrust fixes that add `@Ignore` or hide assertions, and rightly so.
4. **At least one discriminating check.** A check is discriminating if it **fails on the base and passes on the patch**. A check that passes on both proves nothing about the bug — nearly half of an agent's "passing" checks have this property, and about a quarter of runs close on nothing better.
5. **Honest about staleness.** Every test result must come from a run after your last edit. Re-run rather than cite an earlier result.

If you cannot name the discriminating check, you have not verified — you have observed.

## S8 — independent review

Dispatch `issue-fix-verifier` twice against one subagent session:

- **Call 1, blind** — base commit, full diff including new files, repro path and command, test summary. No ticket. It states what it thinks the bug was and what the patch does.
- **Call 2, reconcile** — reuse `task_id` from call 1. Now send the ticket and `R1..Rn`. It returns `same` / `partial` / `different` plus located defects and a verdict.

Treat "the patch addresses a symptom, not the cause" as blocking. Everything else the verifier says is advisory against your own deterministic results.

Self-review is not a substitute. Self-acceptance error rates run about 29.5% versus 2.4% when a visible check gates acceptance. A verifier that has seen the ticket first will tend to agree with it, which is why the blind pass comes first.

## S9 — report

Write `.issue-fix/runs/<case-id>/report.md`:

```markdown
# <case-id> — <terminal state>

## Root cause
file:line — mechanism

## Requirements
| R | covered | verified by | evidence class |

## Changes
- path — one line, traceable to root cause or R<n>

## Evidence
| check | on base | on patch | class |
|-------|---------|----------|-------|
| repro test | FAIL | PASS | discriminating |
| related suite | FAIL(2) | FAIL(2) | regression-only |
| not run: <cmd> — <why> |

## Independent review
<verdict, findings, unresolved objections>

## Residual risk
<what could still be wrong, and what would catch it>

## Diff
git diff + new file contents
```

Evidence classes, used consistently:

- **discriminating** — fails on base, passes on patch
- **regression-only** — passes on both; guards against collateral damage, proves nothing about the bug
- **unverified** — not run; say why

## When to stop

- Gates passed → stop. Do not look for more bugs, do not polish, do not re-run "one more time to be sure". Repeated fix passes damage correct code: continuing after verification can turn correct patches wrong, and open-ended "fix anything else" passes break more than they fix.
- Verifier fails → one rework, with a different hypothesis. A second failure is reported, not retried.
- Steps running low → write the report with the current state and mark it `BUDGET_EXHAUSTED`.
