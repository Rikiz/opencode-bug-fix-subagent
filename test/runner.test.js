import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readValidation } from "../lib/runner.js";

test("rejects shell-like validation commands", () => {
  const root = mkdtempSync(join(tmpdir(), "bugfix-"));
  mkdirSync(join(root, ".bugfix"));
  writeFileSync(join(root, ".bugfix", "validation.json"), JSON.stringify({ commands: [["npm", "test;rm"]] }));
  assert.throws(() => readValidation(root), /safe argument/);
});

test("requires a versioned validation policy", () => {
  const root = mkdtempSync(join(tmpdir(), "bugfix-"));
  assert.throws(() => readValidation(root), /Missing required/);
});
