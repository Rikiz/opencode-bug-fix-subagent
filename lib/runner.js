import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const SAFE_NAME = /^[a-zA-Z0-9_./:@=+-]+$/;

export function repositoryFacts(root) {
  const names = readdirSync(root, { withFileTypes: true })
    .filter((entry) => ![".git", "node_modules", ".bugfix"].includes(entry.name))
    .slice(0, 80)
    .map((entry) => entry.name + (entry.isDirectory() ? "/" : ""));
  const manifests = ["package.json", "pyproject.toml", "go.mod", "Cargo.toml", "pom.xml", "README.md"]
    .filter((file) => existsSync(join(root, file)));
  return `Top-level entries: ${names.join(", ") || "(empty)"}\nDetected manifests: ${manifests.join(", ") || "none"}`;
}

export function readValidation(root) {
  const path = join(root, ".bugfix", "validation.json");
  if (!existsSync(path)) throw new Error("Missing required .bugfix/validation.json.");
  const config = JSON.parse(readFileSync(path, "utf8"));
  if (!Array.isArray(config.commands) || !config.commands.length || !config.commands.every((args) => Array.isArray(args) && args.length && args.every((part) => typeof part === "string" && SAFE_NAME.test(part)))) {
    throw new Error(".bugfix/validation.json commands must be non-empty arrays of safe argument strings.");
  }
  return { commands: config.commands, timeoutMs: Number(config.timeoutMs) || 120_000 };
}

export function runValidation(root, config) {
  return config.commands.map((args) => {
    const result = spawnSync(args[0], args.slice(1), { cwd: root, encoding: "utf8", timeout: config.timeoutMs });
    return { args, exitCode: result.status, timedOut: result.error?.code === "ETIMEDOUT", output: `${result.stdout ?? ""}${result.stderr ?? ""}`.slice(-12_000) };
  });
}

export function runOpenCode(root, prompt, model, dryRun, agentName = "bug-fix") {
  const args = ["run", "--agent", agentName];
  if (model) args.push("--model", model);
  args.push(prompt);
  if (dryRun) return { args: ["opencode", ...args], exitCode: 0, output: "Dry run: OpenCode not invoked." };
  const result = spawnSync("opencode", args, { cwd: root, encoding: "utf8", timeout: 30 * 60_000 });
  return { args: ["opencode", ...args.slice(0, -1), "<prompt>"], exitCode: result.status, output: `${result.stdout ?? ""}${result.stderr ?? ""}`.slice(-20_000), error: result.error?.message };
}
