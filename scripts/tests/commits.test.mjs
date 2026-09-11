import { test } from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  writeFileSync,
  cpSync,
  symlinkSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { execFileSync, spawnSync } from "node:child_process";

const project = resolve(import.meta.dirname, "../..");

function repository(t) {
  const dir = mkdtempSync(join(tmpdir(), "notchveil-commits-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const git = (...args) =>
    execFileSync("git", args, { cwd: dir, encoding: "utf8" }).trim();
  git("init", "-q");
  git("config", "user.name", "Automation test");
  git("config", "user.email", "test@example.invalid");
  git("config", "core.hooksPath", "/dev/null");
  const commit = (message) => {
    git("commit", "-q", "--allow-empty", "-m", message);
    return git("rev-parse", "HEAD");
  };
  const baseline = commit("Legacy release");
  writeFileSync(join(dir, ".commitlint-baseline"), baseline);
  cpSync(
    join(project, "commitlint.config.cjs"),
    join(dir, "commitlint.config.cjs"),
  );
  symlinkSync(join(project, "node_modules"), join(dir, "node_modules"));
  const lint = (name, event) => {
    const eventPath = join(dir, "event.json");
    writeFileSync(eventPath, JSON.stringify(event));
    return spawnSync(
      process.execPath,
      [join(project, "scripts/lint-commits.mjs")],
      {
        cwd: dir,
        encoding: "utf8",
        env: {
          ...process.env,
          GITHUB_EVENT_NAME: name,
          GITHUB_EVENT_PATH: eventPath,
          GITHUB_SHA: git("rev-parse", "HEAD"),
        },
      },
    );
  };
  return { dir, git, baseline, commit, lint };
}

test("a multi-commit push checks earlier commits, not only the tip", (t) => {
  const r = repository(t);
  r.commit("Unconventional message");
  const after = r.commit("fix: restore wallpaper");
  assert.notEqual(r.lint("push", { before: r.baseline, after }).status, 0);
});

test("new branches and manual runs exclude legacy history but lint new commits", (t) => {
  const r = repository(t);
  const after = r.commit("feat(ui): add language selection");
  assert.equal(r.lint("push", { before: "0".repeat(40), after }).status, 0);
  assert.equal(r.lint("workflow_dispatch", {}).status, 0);
  r.commit("Invalid message");
  assert.notEqual(r.lint("workflow_dispatch", {}).status, 0);
});

test("pull requests validate both title and every branch commit", (t) => {
  const r = repository(t);
  const head = r.commit("fix: preserve original wallpaper");
  const event = (title) => ({
    pull_request: { title, base: { sha: r.baseline }, head: { sha: head } },
  });
  assert.equal(
    r.lint("pull_request", event("fix: preserve wallpaper")).status,
    0,
  );
  assert.notEqual(r.lint("pull_request", event("Update wallpaper")).status, 0);
  assert.equal(
    r.lint("pull_request", event("fix: handle $(exit 99) as text")).status,
    0,
  );
});

test("missing push history fails instead of silently checking only one commit", (t) => {
  const r = repository(t);
  const after = r.commit("ci: add checks");
  assert.notEqual(r.lint("push", { before: "a".repeat(40), after }).status, 0);
  assert.notEqual(r.lint("push", { before: "--all", after }).status, 0);
});

test("the local commit-msg hook accepts conventional commits and rejects invalid ones", (t) => {
  const r = repository(t);
  const message = join(r.dir, "COMMIT_EDITMSG");
  const hook = () =>
    spawnSync("sh", [join(project, ".husky/commit-msg"), message], {
      cwd: r.dir,
    });
  writeFileSync(message, "docs: simplify readme\n");
  assert.equal(hook().status, 0);
  writeFileSync(message, "Update readme\n");
  assert.notEqual(hook().status, 0);
});
