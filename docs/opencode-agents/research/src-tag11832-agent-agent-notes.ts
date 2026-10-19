// SOURCE: https://raw.githubusercontent.com/anomalyco/opencode/v1.18.32/packages/opencode/src/agent/agent.ts
// FETCHED: 2026-10-08 via webfetch (verified present, HTTP 200, byte-substance identical to dev branch)
// NOTE: content not duplicated here; identical to src-agent-agent.ts (dev branch). Key confirmations:
//   - builtin agents: build, plan, general, explore, compaction, title, summary  (NO scout)
//   - plan has: task: { general: "deny" }        <-- per-subagent-name task rule
//   - user agents loop reads value.steps ONLY (no value.maxSteps fallback)
//   - new custom agent defaults: mode: "all", permission = merge(defaults, user), native: false
//   - defaultInfo() THROWS on invalid default_agent (docs say it falls back to build)
