---
name: issue-fix-reproduce
description: "Use at stage S3 of the issue-fix workflow: write one failing repro test per requirement, prove it fails for the reported reason three times, and never edit source to make it pass"
---

# Reproduce

The repro test is the only thing standing between you and a plausible-but-wrong patch. Treat it as an artifact you must justify, not a formality.

## Order matters

1. Read one existing test near the code and copy its structure, helpers, and naming.
2. Write the test. Load the matching `lang/*.md` for placement and invocation.
3. Run it. It must fail.
4. Only then may source code be edited (and only after S4 passes).

Left alone, an agent edits source first in about three quarters of cases, and a repro test written afterwards is measurably worse. Writing the test first is worth about 7 percentage points.

## Rules

1. **One test per requirement.** A test that asserts three requirements cannot tell you which one broke.
2. **Expected values come from the ticket or the spec.** Never from current output. Capturing current output encodes the bug as correct behavior — this happens in 8-17% of generated regression tests.
3. **Fail for the reported reason.** Classify the failure: compile error, import error, environment error, timeout, and assertion about behavior are not the same thing. Only the last one counts.
4. **Three consecutive runs.** A single red is noise: flaky tests account for about 4.6% of all failures in industrial test suites, and "retry until it passes" is exactly the wrong policy.
5. **Disable test caching.** Go needs `-count=1`, Gradle needs `--rerun-tasks` or `cleanTest`, watch-mode runners need an explicit non-watch flag. Details in `lang/*.md`.
6. **Deterministic.** Fixed seeds, no wall-clock dependency, no network, no shared mutable state, no ordering dependence. If you cannot make it deterministic, the bug is flaky-suspect — say so instead of forcing a red.
7. **Keep it.** Do not delete or weaken the repro later, even if the project would rather not have the test. Ship it as the regression test.

## Interpreting the result

| Result | Meaning | Action |
|---|---|---|
| red before fix | correct | proceed to S4 |
| green before fix | the test does not capture the bug | fix the test |
| red before, red after a plausible fix | the fix is wrong, or the test is too lax | re-diagnose before changing anything |
| red for the wrong reason | environment or harness problem | fix the harness, not the code |

A test that stays red after a fix that looks correct is evidence. Do not weaken the test to make it green.

## Budget

Three runs to confirm, then stop. If the defect cannot be reproduced after writing one test and one re-attempt, report `NOT_REPRODUCIBLE` with the diagnosis record. Do not edit source to produce a repro.
