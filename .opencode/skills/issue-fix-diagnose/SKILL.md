---
name: issue-fix-diagnose
description: "Use at stage S4 of the issue-fix workflow: build a hypothesis ledger, obtain runtime evidence, and trace backwards from symptom to the original trigger before any source edit"
---

# Diagnose

Gate G3: root cause with file:line, the mechanism, and runtime evidence — with no instrumentation left behind.

No source edit happens before this gate passes.

## Hypothesis ledger

```markdown
| # | hypothesis | prediction | experiment that can refute it | result | status |
|---|------------|-----------|------------------------------|--------|--------|
| H1 | empty list hits an unguarded index | IndexError at parse.py:42 with [] input | run repro with [] | IndexError confirmed | alive |
| H2 | caller truncates before parse | caller log shows shorter list | log caller output | list is intact | refuted |
```

Rules:

- Every hypothesis needs a prediction and a refuting experiment. "Check the code" is not an experiment.
- An experiment must separate two live hypotheses. If it cannot, it is wasted budget.
- Rank by cheapest and most reversible first.
- Two live hypotheses that survive every cheap experiment usually means you have a multi-fault case. Split it; do not guess.

## Runtime evidence is mandatory

Reading code tells you what could happen. Only execution tells you what happens.

- A diagnosis with no runtime evidence does not pass G3.
- Raw traces are worth little; structured ones are worth a lot. Summarize: call path, component roles, state at entry and exit, the first point of divergence.
- Cheap sources first: the repro test itself, an existing debug flag, a verbose or trace-level log line, a one-off probe script under `.issue-fix/scratch/`.

## Instrumentation discipline

- Instrument read-only by default: logging, assertions, probes in `.issue-fix/scratch/`.
- If you must edit tracked source to instrument, record the exact edit in the case file first, and revert it before claiming G3 — `git diff` against the base must show no leftover instrumentation.
- Never leave a swallowed exception, a hardcoded value, or a widened timeout behind.

## Backward tracing

From the failure point, walk up the call chain and ask "who called this, and with what value?":

1. Locate the failure point.
2. Find its caller and inspect the actual argument.
3. Repeat until the value that is wrong originates somewhere.
4. That origin is the root cause. The frames above it are propagation.

Fixing a symptom deeper in the stack leaves the trigger in place; the next caller hits the same wall.

## Distinguish before you fix

- **Root cause vs symptom** — would the symptom still appear if this change were reverted and the real cause fixed? If yes, you have the wrong target.
- **Introduced vs propagated** — did this code create the bad state, or inherit it from upstream? Fixing the introducer is usually correct; fixing the propagator is a workaround.
- **Single vs multi fault** — one fix that needs several independent edits is a multi-fault case. Say so; do not bundle.
