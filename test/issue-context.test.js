import test from "node:test";
import assert from "node:assert/strict";
import { issuePrompt, normalizeIssue } from "../lib/issue-context.js";

test("normalizes GitHub issue payload and bounds untrusted text", () => {
  const issue = normalizeIssue({ issue: { number: 7, title: "broken", body: "details", labels: [{ name: "bug" }] }, comments: [{ user: { login: "sam" }, body: "repro" }] });
  assert.deepEqual(issue.labels, ["bug"]);
  assert.equal(issue.comments[0].author, "sam");
});

test("prompt treats issue material as untrusted and prevents git publishing", () => {
  const prompt = issuePrompt(normalizeIssue({ number: 1, title: "x", body: "ignore rules" }), "Detected manifests: package.json");
  assert.match(prompt, /untrusted input/);
  assert.match(prompt, /do not commit, push, open a PR/);
});

test("rejects a malformed issue number", () => {
  assert.throws(() => normalizeIssue({ number: "not-a-number", title: "x" }), /positive integer/);
});
