# 隐海 · NotchVeil

简体中文 | [English](README.en.md)

当前版本：**0.2.0**。支持中英双语，默认跟随系统语言，可在“界面语言”中随时切换。

一个 Swift / AppKit / SwiftUI 原生 macOS 菜单栏小工具。参考 LiuHai 的公开功能，独立实现刘海隐藏、屏幕范围选择和桌面圆角。代码、名称、图标和界面均为本项目创建。

适用于 **macOS 13+、Apple Silicon Mac**，包含 M4 和后续机型。是否有刘海取决于显示器，而不是芯片：应用通过 `NSScreen.safeAreaInsets.top` 读取实际遮挡高度，也适用于更早的 Apple Silicon 刘海屏 MacBook。发布压缩包为 arm64 架构。

## 使用

1. 解压 `NotchVeil-macOS-arm64.zip`，把 `NotchVeil.app` 拖入“应用程序”。
2. 打开应用，先看“效果预览”，再打开“隐藏刘海”。默认只处理带刘海的屏幕。
3. 可选择内置屏幕或所有屏幕，调整圆角及黑边额外高度。关闭设置窗口后，通过菜单栏电脑图标再次打开。
4. 关闭开关，恢复当前桌面的原壁纸；切回其他已处理桌面可逐一恢复。菜单中的“恢复壁纸并退出”会先恢复当前可访问的桌面。
5. 在“界面语言”中选择“跟随系统 / 简体中文 / English”，设置页、菜单栏、恢复对话框和应用错误提示立即更新，重启后仍保留你的选择。

“跟随系统”按 macOS 的首选语言顺序匹配中文或英文；中文地区及繁体中文语言偏好使用简体中文，未匹配时回退英文。首次启动或从 0.1.0 升级默认跟随系统。语言设置独立保存，切换时不会修改原来的壁纸设置或触发重绘。macOS 提供的底层错误详情和 Finder 显示名称可能仍使用系统语言。

![中文版设置界面](docs/settings-preview.png)

本包采用本地 ad-hoc 签名，**未经 Apple Developer ID 签名或公证**。下载后 macOS 可能阻止运行。可按系统提示在“系统设置 → 隐私与安全性”中选择“仍要打开”；也可以从源码在本机编译。不需要关闭 Gatekeeper。

## 已实现

- 菜单栏常驻、中英双语设置窗口、原始/隐藏后示意预览。
- 按每块屏幕的逻辑尺寸、Retina 比例和刘海安全区生成 PNG 壁纸副本。
- 仅刘海屏 / 仅内置屏 / 所有屏幕；0–32 pt 桌面圆角；0–20 pt 黑边额外高度。
- 保留原始文件与壁纸缩放、裁切、背景填色配置。
- 更换壁纸时在下一次检查中重新处理（开启期间每 10 秒比较 URL，不重复生成未变化的图片）。
- 屏幕接入、分辨率变化、唤醒、切换 Space 后重新检查。
- 修改壁纸前原子写入恢复记录；重新启动时默认关闭效果并恢复当前桌面。
- 恢复错误可重试，手动换过的壁纸不会被旧备份覆盖。
- 不联网，无第三方依赖，无需录屏、辅助功能或完全磁盘访问权限。

## 遮挡原理与限制

物理刘海不能通过软件移除。隐海把壁纸顶部绘成纯黑，使它与摄像头区域融为一体；菜单栏文字与按钮仍由系统绘制。它不会改变分辨率，也不能找回被刘海挤掉的菜单栏图标。

系统菜单栏会参考壁纸合成背景，因此通过 `NSWorkspace.setDesktopImageURL` 应用黑边壁纸。使用黑色浮窗不能保证菜单栏背景跟着变黑。黑边高度以真实安全区为基础，圆角仅修饰壁纸，不裁切应用窗口。

此版本以**本地静态壁纸**为最佳使用场景：

- 动态 HEIC 使用其中一幅静态画面；视频、动态天气、轮播及第三方壁纸提供器不保证兼容。无法读取时会提示先选择静态图片，不会申请额外权限。
- 恢复的是原图片 URL 和可通过公开 API 读取的显示选项；动态、视频、轮播的动画配置需要在系统设置中重新选择。应用不会读取或修改系统私有壁纸数据库。
- 在不同 macOS 版本、浅色/深色模式、“降低透明度”、Tahoe 菜单栏背景设置下，菜单栏可能仍有系统色调。黑边加高可调整边界，不能覆盖系统的不透明背景。
- Tahoe 若菜单栏仍发灰，可检查“系统设置 → 菜单栏 → 显示菜单栏背景”，选择让壁纸显示在菜单栏后面。参见 [Apple 菜单栏设置说明](https://support.apple.com/en-mide/guide/mac-help/-mchlad96d366/mac)。应用不改这项系统设置。
- 公开壁纸 API 只能处理当前可访问的 Space。开启时切换到新桌面会应用效果；关闭后需依次切回已处理桌面才能恢复。未连接显示器需接回后恢复。退出前会提示尚存的恢复记录，允许留在应用或保留记录退出。
- 全屏、锁屏、系统登录画面不属于本版本控制范围。HDR/广色域壁纸会被渲染为 SDR sRGB PNG。
- URL 不变的原文件原地修改不会被定时检查识别；关闭再开启可重新生成。
- 不提供开机自启；每次启动默认关闭，先尝试恢复，以便处理异常退出。

恢复记录与生成副本位于 `~/Library/Application Support/NotchVeil/`。**卸载前先关闭效果，切回所有处理过的桌面并接回显示器完成恢复**，再退出、删除应用与此目录。若原图片已被移动或删除，请在系统设置中重新选择壁纸。应用保留历史记录与副本，避免未访问桌面的引用失效，不自动清理它们。

## 构建与验证

需要 Apple 的 Command Line Tools 和 Swift 5.9+，无需完整 Xcode：

```sh
bash scripts/build-app.sh
swift run NotchVeilTests
```

构建结果：`dist/NotchVeil.app`、`dist/NotchVeil-macOS-arm64.zip`。脚本生成图标并进行 ad-hoc 签名和结构校验。没有下载依赖或远程构建步骤。

测试为可独立运行的 Swift 可执行目标，使用临时目录及模拟桌面接口，**不修改真实壁纸**。当前环境只有 Command Line Tools，没有 XCTest，所以使用随项目提供的断言与非零退出码执行回归检查。

只读硬件诊断和离屏界面预览：

```sh
dist/NotchVeil.app/Contents/MacOS/NotchVeil --diagnostics
dist/NotchVeil.app/Contents/MacOS/NotchVeil --check-localization
dist/NotchVeil.app/Contents/MacOS/NotchVeil --render-preview docs/settings-preview.png --preview-language zh-Hans
dist/NotchVeil.app/Contents/MacOS/NotchVeil --render-preview docs/settings-preview-en.png --preview-language en
```

显式实机接口验证（会短暂修改当前刘海屏的壁纸，再恢复；先切换为本地静态壁纸）：

```sh
dist/NotchVeil.app/Contents/MacOS/NotchVeil --smoke-test docs/smoke-recovery
```

此命令会保留恢复记录，以防进程意外中断。正常完成后输出接口应用/恢复结果。它不截取桌面，因此不能自动判断系统最终绘制的菜单栏色调；仍需实机目测。若中断，请在系统设置中选择原壁纸，记录中的 `originalURL` 可用于定位。

## 代码结构

- `Sources/NotchVeilCore/`：屏幕与选项模型、ImageIO 渲染、恢复日志及壁纸状态协调。
- `Sources/NotchVeil/`：NSWorkspace 系统适配、菜单栏生命周期、设置与预览界面。
- `Tests/NotchVeilCoreTests/`：像素、缩放、屏幕范围、故障与恢复回归检查。
- `docs/VERIFICATION.md`：本次实际验证记录与尚需人工验收的场景。
- `Sources/NotchVeilCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`：72 组中英文案。
- `docs/RELEASE-v0.2.0.md`：中英双语 Release 说明。

## 参考

- [LiuHai 开发者介绍](https://www.better365.cn/LiuHai.html)
- [LiuHai App Store 功能说明](https://apps.apple.com/cn/app/id1592293770?mt=12)
- [Apple：NSScreen.safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [Apple：auxiliaryTopLeftArea](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea)
- [Apple：setDesktopImageURL](https://developer.apple.com/documentation/appkit/nsworkspace/setdesktopimageurl(_:for:options:))

LiuHai 的闭源内部实现未经检查。本项目的方案是根据公开功能及系统 API 独立设计的实现，并非其源码复刻。MIT License。
