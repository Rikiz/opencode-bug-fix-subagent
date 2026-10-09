---
name: topology-manifest
description: "Use when reading, writing, or validating topology.json — the multi-repository manifest that lists repositories, contract edges, and coverage gaps. Also use before routing an issue or judging cross-repo contract consistency."
---

# Topology manifest

`topology.json` is the machine-readable map of which repositories exist, what each one owns, and how they connect. It is the input to repository routing and to cross-repo verification. It is git-ignored because it names internal paths, owners, and service topology — commit `topology.example.json` instead.

## Schema

```jsonc
{
  "version": 1,
  "org": "<org name>",
  "repos": [
    {
      "name": "<unique repo id>",              // stable, used as the routing key
      "path": "/absolute/path",                // machine-local; no ~ or $VAR
      "language": ["typescript"],              // array, may be empty
      "role": "gateway|service|frontend|library|infra|job",
      "summary": "<2-4 sentences: what it owns>",
      "provides": [{ "kind": "http|event|schema|config|grpc", "path": "", "topic": "", "name": "", "location": "" }],
      "consumes": [ /* same shapes */ ],
      "owner": "<team>",
      "validation": [["npm", "test"]]          // argv arrays, no shell strings
    }
  ],
  "contracts": [
    {
      "from": "<repo>", "to": "<repo>",
      "kind": "http|event|schema|config|grpc",
      "field": "<field, topic, path, or key that this edge governs>",
      "evidence": "<repo:file:line or manifest entry>",
      "confidence": 0.0                        // 0..1
    }
  ],
  "coverage": {
    "indexedAt": "<ISO timestamp>",
    "staleRepos": ["<repo>"],
    "unknownEdges": [{ "description": "", "affects": ["<repo>"] }],
    "notes": "<layers that are not modelled at all, e.g. service-mesh routing rules>"
  }
}
```

## Rules for writing it

- **`path` is absolute and literal.** opencode does not expand `~` or environment variables in permission patterns, and the manifest is read by tooling rather than by a shell. Use full paths and let the operator fix them per machine.
- **`validation` is argv arrays.** Never a shell string. The same rule applies anywhere a command is stored, so that no untrusted value can be word-split or injected.
- **Every contract edge needs `evidence` and `confidence`.** An edge without evidence is an assumption. Set `confidence` below `0.5` for anything inferred rather than read from code.
- **Model contracts, not just symbols.** Compiler-grade symbol graphs miss the failures that actually cross repositories: HTTP paths, event topics, JSON schemas, config keys, enum members, deployment manifests. If an edge is only "repo A calls repo B", it is not yet a contract.
- **`role` matters for routing.** A gateway or router failure presents as an upstream service failure; without `role: gateway` in the manifest the router will chase the wrong repository.
- **Keep `summary` factual.** It is often the only text a router reads before deciding. Written marketing copy ("fast, scalable payments") gives it nothing to reason with. State what it owns and which surfaces it exposes.
- **Record gaps in `coverage`, not by omission.** Unmodelled layers, runtime-resolved routes, stale repositories. An edge you did not model and an edge that does not exist must be distinguishable.
- **Duplicate `name` is invalid.** Routing uses it as a key.

## Reading it

1. Check `coverage.indexedAt` and `coverage.staleRepos` first. A stale manifest bounds every conclusion drawn from it.
2. Prefer `provides`/`consumes` and `contracts` over `summary`. Summaries drift; declared contracts are the thing you are maintaining on purpose.
3. Treat any edge with `confidence < 0.5` as a hypothesis. Confirm it against code in both repositories before acting.
4. If `topology.json` is absent, `topology.example.json` explains the schema only. Never route a real issue from the example file — its paths do not exist.
5. Report unmodelled layers. Gateway and mesh routing are the most commonly missing layer, and they are exactly the cases where a code-level answer is wrong.

## Keeping it honest

The manifest is the highest-leverage artifact in the whole system: routing quality, contract verification, and coverage reporting all degrade silently when it is stale. Treat a refresh as a scheduled task, not an occasional cleanup. Record what changed since `indexedAt` rather than pretending the map is complete.