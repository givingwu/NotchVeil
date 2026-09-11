# Contributing

English | [中文](CONTRIBUTING.zh-CN.md)

## Local setup

Use macOS 13+, Apple Command Line Tools (Swift 5.9+), and Node.js 24 LTS. Node is only needed for repository tooling; the app has no JavaScript runtime or third-party Swift dependencies.

```sh
npm ci
swift run NotchVeilTests
bash scripts/build-app.sh
```

`npm ci` installs the Husky `commit-msg` hook for this clone. Every contributor should run it once. CI uses the same commitlint configuration even when local hooks are skipped.

## Commits and pull requests

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), enforced by [commitlint's conventional configuration](https://commitlint.js.org/guides/getting-started):

```text
feat(ui): add a display selector
fix(wallpaper): restore the original image
docs: simplify the readme
ci: verify release packages
```

Other supported types are `build`, `chore`, `perf`, `refactor`, `revert`, `style`, and `test`. Scopes are optional. Describe breaking changes with `!` and a `BREAKING CHANGE:` footer. Keep the subject lowercase and the header within 100 characters.

PR titles must follow the same format. CI checks **every new commit in a push or PR**, including earlier commits in a batch, and rechecks edited PR titles. Merge with **Squash and merge** using the PR title, or rebase already compliant commits. Automatic `Merge ...` messages are not exempted. Review the final squash message before merging.

The two commits at/before `f9c463c` predate this policy. `.commitlint-baseline` preserves that published history and anchors checks for new branches and manual runs. Existing commit SHAs and the `v0.2.0` release remain valid.

```sh
npm run format
npm run format:check
npm run test:automation
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/check-version.py
npm run commitlint -- --last
```

## Automation

| Workflow                   | Trigger                        | Result                                                                                                                    |
| -------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| CI / Conventions           | Branch push, PR, or manual run | Commit messages, PR title, Markdown/config formatting, workflow syntax, automation regression tests, version consistency  |
| CI / macOS build and tests | Same                           | Apple Silicon build, regression tests, ad-hoc signature and bundled localization checks; ZIP artifact retained for 7 days |
| Release                    | Push to `main`, or manual run  | Release Please proposes version and changelog updates; merging the release PR builds and publishes a release              |
| Dependabot                 | Weekly                         | Action and npm dependency update PRs with conventional titles; no automatic merging                                       |

Workflows use pinned action SHAs and limited job permissions. PR tests have read-only access and do not change the real desktop wallpaper. GUI appearance, disconnected displays, and individual Spaces still need manual acceptance.

## Maintainer setup

1. In **Settings → Actions → General → Workflow permissions**, enable **Allow GitHub Actions to create and approve pull requests**. Keep default workflow permissions read-only; the release job requests its own write permissions. This toggle is required for Release Please to create version PRs.
2. To block noncompliant changes before they reach `main`, add a branch ruleset requiring PRs, linear history, and passing **Conventions** and **macOS build and tests** checks, with no bypass. Enable squash merging and use the PR title as its default commit message. CI alone reports failures after direct pushes; it cannot reject them without a repository rule.
3. Review and merge dependency and release PRs when ready. No personal access token is required: Release explicitly dispatches CI on Release Please's bot branches because `GITHUB_TOKEN`-created PR workflows may otherwise wait for approval.

No signing secret is needed for the existing ad-hoc preview builds. Apple-notarized distribution is separate and would require your Apple Developer signing certificate and notarization credentials; the workflow does not claim to notarize builds.

## Releases and recovery

Release Please starts at `0.2.0`. A `fix:` produces a patch release; `feat:` produces a minor release. Before 1.0, a breaking change also bumps the minor version. Documentation/CI-only changes do not create a release on their own. The generated PR updates `version.txt`, `.release-please-manifest.json`, `Resources/Info.plist`, and `CHANGELOG.md`.

After you merge that PR, Release creates a tagged draft, checks out that exact tag, validates versions, runs regression tests, and builds the app. It uploads the arm64 app ZIP, a source ZIP from the same commit, and `SHA256SUMS.txt`, then publishes. Versions below 1.0 remain marked as prereleases. The distributed bundle's build number is the Release workflow run number plus 2 (the original build number).

If packaging fails, the release stays a draft. Use **Actions → Release → Run workflow** on `main`, supplying its existing tag (for example `v0.3.0`) to retry. Leave `tag` empty to refresh the release proposal. Retry can replace draft assets; published releases are rejected and must receive a new version for changes.

References: [Release Please](https://github.com/googleapis/release-please-action), [GitHub workflow token behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).
