# 贡献指南

[English](CONTRIBUTING.md) | 中文

## 本地开发

需要 macOS 13+、Apple Command Line Tools（Swift 5.9+）和 Node.js 24 LTS。Node 仅用于仓库开发工具，应用本身不依赖 JavaScript 或第三方 Swift 包。

```sh
npm ci
swift run NotchVeilTests
bash scripts/build-app.sh
```

每个开发者首次克隆后执行一次 `npm ci`，自动安装 Husky 的 `commit-msg` 钩子。即使跳过本地钩子，CI 仍会校验提交。

## 提交规范

提交和 PR 标题使用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)，例如：

```text
feat(ui): add a display selector
fix(wallpaper): restore the original image
docs: simplify the readme
ci: verify release packages
```

还支持 `build`、`chore`、`perf`、`refactor`、`revert`、`style`、`test`。范围可省略；英文描述用小写开头，标题不超过 100 字符。破坏性改动使用 `!` 和 `BREAKING CHANGE:` 页脚。

CI 检查一次推送或 PR 内的**全部新增提交**，修改 PR 标题也会重新检查。合并时使用 **Squash and merge** 并保留规范的 PR 标题，或对已经合规的提交使用 rebase。普通 `Merge ...` 消息不会豁免，合并前检查最终提交信息。

`f9c463c` 及之前的两条提交早于本规范，保留已发布历史。`.commitlint-baseline` 用于新分支和手动运行时确定检查起点，现有提交哈希与 `v0.2.0` 继续有效。

```sh
npm run format
npm run format:check
npm run test:automation
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/check-version.py
npm run commitlint -- --last
```

## 自动化

- **CI / Conventions**：检查提交、PR 标题、文档和配置格式、工作流语法、自动化回归测试及版本一致性。
- **CI / macOS build and tests**：Apple Silicon 构建、回归测试、ad-hoc 签名与打包资源检查，安装包构建产物保留 7 天。
- **Release**：按规范提交生成版本与更新日志 PR；合并后自动测试、打包和发布。
- **Dependabot**：每周提交 Actions 与 npm 依赖更新 PR，提交信息符合规范，不自动合并。

Actions 固定到提交 SHA，各任务按需分配权限。PR 测试只有读取权限，不修改真实桌面壁纸；界面效果、未连接显示器和不同 Space 的行为仍需要人工验收。

## 仓库维护者需要设置

1. 在 **Settings → Actions → General → Workflow permissions** 开启 **Allow GitHub Actions to create and approve pull requests**。默认工作流权限保持只读，发布任务在配置中单独申请所需权限。此开关是 Release Please 创建版本 PR 的前提。
2. 要在合并前强制拦截，给 `main` 设置分支规则：要求 PR、线性历史，以及 **Conventions**、**macOS build and tests** 两项检查通过，不设置绕过。启用 squash 合并，默认提交信息选择 PR 标题。没有分支规则时，CI 只能报告直接推送后的失败，不能阻止推送。
3. 按需审查并合并依赖和版本 PR。**不需要个人访问令牌**：Release 会显式触发机器人分支的 CI，避免默认 `GITHUB_TOKEN` 创建的 PR 工作流等待人工批准。

现有 ad-hoc 预览版无需额外 Secret。若要 Apple 公证分发，需要另行提供 Apple Developer 签名证书和公证凭据；当前流程不包含公证。

## 发布与重试

从 `0.2.0` 开始，`fix:` 自动提升补丁版本，`feat:` 提升次版本；1.0 之前的破坏性改动也提升次版本。仅文档或 CI 改动不会单独触发新版本。Release Please 自动更新 `version.txt`、`.release-please-manifest.json`、`Resources/Info.plist` 和 `CHANGELOG.md`。

合并版本 PR 后生成带标签的草稿；检查版本一致性，运行测试，基于同一标签构建安装包和源码包，附上 `SHA256SUMS.txt` 后才公开发布。1.0 之前标记为预发布。分发包的构建号为 Release 工作流运行编号加 2（原构建号）。

失败时保留草稿。通过 **Actions → Release → Run workflow**，选择 `main`，填写现有草稿标签（如 `v0.3.0`）即可重试打包；留空 `tag` 则刷新版本提案。重试只允许替换草稿附件，已经公开的版本必须通过新版本修改。
