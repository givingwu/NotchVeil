import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

function run(command, args, input) {
  const result = spawnSync(command, args, { input, encoding: "utf8" });
  process.stdout.write(result.stdout ?? "");
  process.stderr.write(result.stderr ?? "");
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

function sha(value) {
  if (!/^[a-f0-9]{40}$/.test(value ?? ""))
    throw new Error("Invalid commit SHA");
  return value;
}

const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
const baseline = sha(readFileSync(".commitlint-baseline", "utf8").trim());
const lint = ["node_modules/@commitlint/cli/cli.js"];
let from;
let to;

if (process.env.GITHUB_EVENT_NAME === "pull_request") {
  from = sha(event.pull_request.base.sha);
  to = sha(event.pull_request.head.sha);
  // Pass user-controlled text on stdin, never through a shell expression.
  run(process.execPath, [...lint, "--verbose"], event.pull_request.title);
} else if (process.env.GITHUB_EVENT_NAME === "push") {
  if (event.deleted) process.exit(0);
  from = /^0+$/.test(event.before ?? "") ? baseline : sha(event.before);
  to = sha(event.after);
} else {
  from = baseline;
  to = sha(process.env.GITHUB_SHA);
}

run("git", ["cat-file", "-e", `${from}^{commit}`]);
run("git", ["cat-file", "-e", `${to}^{commit}`]);
run(process.execPath, [...lint, "--from", from, "--to", to, "--verbose"]);
