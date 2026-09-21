#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { normalizeIssue, issuePrompt } from "../lib/issue-context.js";
import { readValidation, repositoryFacts, runOpenCode, runValidation } from "../lib/runner.js";

function argument(name) {
  const index = process.argv.indexOf(name);
  return index === -1 ? undefined : process.argv[index + 1];
}

const issueFile = argument("--issue-file");
if (!issueFile) {
  console.error("Usage: npm run bugfix -- --issue-file issue.json [--model provider/model] [--dry-run]");
  process.exit(2);
}
const root = resolve(argument("--repo") ?? process.cwd());
const dryRun = process.argv.includes("--dry-run");
const issue = normalizeIssue(JSON.parse(readFileSync(resolve(issueFile), "utf8")));
const validationConfig = readValidation(root); // Read before the writable agent starts.
const runDir = join(root, ".bugfix", "runs", `${Date.now()}-issue-${issue.number}`);
mkdirSync(runDir, { recursive: true });

const prompt = issuePrompt(issue, repositoryFacts(root));
writeFileSync(join(runDir, "prompt.txt"), prompt);
const agent = runOpenCode(root, prompt, argument("--model") ?? process.env.BUGFIX_MODEL, dryRun);
writeFileSync(join(runDir, "agent.json"), JSON.stringify(agent, null, 2));

const verifierPrompt = `Independently verify the proposed fix for issue #${issue.number}. Read the issue and current git diff. Do not edit files, stage, commit, push, or run destructive/network commands. Check that the diff is minimal, addresses the stated behavior, includes an appropriate regression test when feasible, and that configured validation is meaningful. Return exactly VERDICT: PASS or VERDICT: FAIL, followed by evidence and any blocking risk.\n\n${prompt}`;
const verifier = runOpenCode(root, verifierPrompt, argument("--model") ?? process.env.BUGFIX_MODEL, dryRun, "bug-fix-verifier");
writeFileSync(join(runDir, "verifier.json"), JSON.stringify(verifier, null, 2));

const validation = runValidation(root, validationConfig);
writeFileSync(join(runDir, "validation.json"), JSON.stringify(validation, null, 2));
const verifierPassed = dryRun || (verifier.exitCode === 0 && /VERDICT:\s*PASS/i.test(verifier.output));
const passed = !dryRun && agent.exitCode === 0 && verifierPassed && validation.every((result) => result.exitCode === 0);
console.log(JSON.stringify({ issue: issue.number, dryRun, passed: dryRun ? null : passed, runDir, agent: { exitCode: agent.exitCode, error: agent.error }, verifier: { exitCode: verifier.exitCode, passed: verifierPassed }, validation: validation.map(({ args, exitCode, timedOut }) => ({ args, exitCode, timedOut })) }, null, 2));
process.exit(dryRun || passed ? 0 : 1);
