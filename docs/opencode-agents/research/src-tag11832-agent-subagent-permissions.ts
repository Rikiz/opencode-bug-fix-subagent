// SOURCE: https://raw.githubusercontent.com/anomalyco/opencode/v1.18.32/packages/opencode/src/agent/subagent-permissions.ts
// FETCHED: 2026-10-08 via webfetch (verified present, HTTP 200)
// VERIFIED BYTE-FOR-BYTE IDENTICAL to dev branch (src-agent-subagent-permissions.ts)
export function deriveSubagentSessionPermission(input: {
  parentSessionPermission: PermissionV1.Ruleset
  subagent: Agent.Info
}): PermissionV1.Ruleset {
  const canTask = input.subagent.permission.some((rule) => rule.permission === "task")
  const canTodo = input.subagent.permission.some((rule) => rule.permission === "todowrite")
  return [
    ...input.parentSessionPermission.filter(
      (rule) => rule.permission === "external_directory" || rule.action === "deny",
    ),
    ...(canTodo ? [] : [{ permission: "todowrite" as const, pattern: "*" as const, action: "deny" as const }]),
    ...(canTask ? [] : [{ permission: "task" as const, pattern: "*" as const, action: "deny" as const }]),
  ]
}
