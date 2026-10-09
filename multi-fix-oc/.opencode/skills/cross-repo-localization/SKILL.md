---
name: cross-repo-localization
description: "Use when a fault crosses repository boundaries: route a symptom through contract edges, follow a payload field or event topic between producer and consumer, and reason correctly about missing or low-confidence evidence in a topology manifest."
---

# Cross-repository localization

A single-repo fix that ignores the other side of a contract converts a loud failure into a silent wrong value. Work contracts, not just symbols.

## The symptom-to-surface walk

Do this in order. The order is the method.

1. **Write the observable literally.** "HTTP 400 from `/api/v2/orders`", "event `payment.v2.captured` never observed", "field `customerId` absent in the audit record". No interpretation yet.
2. **Identify the entry point.** A gateway route, a frontend call site, an event consumer, a scheduled job, an operator CLI.
3. **Pick the edge kind that carries the symptom.**
   - `http` → routing, auth, path rewrite, status codes
   - `event` → produced-but-not-consumed, wrong topic, consumer crashed and nothing noticed
   - `schema` → field missing, renamed, newly strict, wrong type, enum member added
   - `config` → environment-only difference, key present in one deployment and not another
4. **Walk both directions from the entry point.** The producer side explains "why is it wrong"; the consumer side explains "why it broke here". Quote both sides of the mismatch.
5. **Check the layer that can explain the whole symptom.** If the call never reached the service, the gateway outranks the service, even when the gateway code looks innocent. Readiness probe paths, timeouts, retry and circuit-breaker configuration, and mesh routing rules are all gateway-owned causes.

## Boundary cases worth naming

- **Strict consumer, loose producer.** Producer added a field or changed a type; consumer deserializes strictly and rejects. Both repositories are in scope. The minimal fix is on whichever side is wrong, but you must state which side that is and why.
- **Envelope versus payload.** A gateway can report success while the body it forwards is truncated or re-serialized lossily. Correlate by request id, not by symptom.
- **Fan-out ordering.** Several services receive the same event. A change in ordering, deduplication, or idempotency key breaks only some consumers, which looks like a random bug in one service.
- **Version skew.** Two services legitimately speak different contract versions. That is not a bug; a fix that "aligns" them may be a regression. Check the version before you call it a mismatch.
- **Config and deployment, not code.** The repository may be correct and the environment wrong. Check whether the changed behaviour depends on an environment value before editing code.

## Evidence discipline

**Missing evidence is a finding, not a safety property.** If the topology has no edge for a path you care about, the honest statement is "the relationship is unknown", never "these components are independent". Every serious cross-repo tool represents uncovered ground explicitly, because an agent handed an incomplete map will read absence as safety.

Every contract edge should carry:
- **evidence** — a `file:line`, a manifest entry, a route definition, an access-log line
- **confidence** — how sure you are the edge is real right now

Practical thresholds:
- `>= 0.8` — usable as a basis for a conclusion
- `0.5 – 0.8` — usable as a hint, must be confirmed against the code in both repositories
- `< 0.5` — do not build a conclusion on it; refresh the manifest or gather telemetry

When an edge is weak, say so and say what would fix it: a gateway access log naming the route, a payload capture, a service registry dump.

**Staleness is a first-class condition.** A topology indexed months ago describes a system that no longer exists. Check `coverage.indexedAt` and `coverage.staleRepos` before trusting a high-confidence edge in a frequently changed repository.

## Scope signals to hand back to routing

Stop and report rather than continue when:
- the cause sits in a repository you were not assigned,
- the edge that matters is listed in `coverage.unknownEdges`,
- the relevant routing layer (service mesh, ingress, virtual services, DNS) is not modelled at all,
- the evidence needed is runtime telemetry that nobody captured.

These are routing corrections, not failures. Say which repository should own it and what evidence is missing.

## Verification is external

Never let the agent that wrote the patch grade its own patch. The check must come from outside the change: a configured test command, a schema comparison against both sides, a replayed payload. A verifier that shares context or assumptions with the fixer inherits the same blind spot.

Report localization quality separately from repair success. High test pass rates with poor localization precision means over-editing, which is a defect even when the suite is green.