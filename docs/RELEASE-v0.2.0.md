NotchVeil 0.2.0 adds Chinese and English throughout the app, with automatic system-language selection and an immediate, persistent override.

## English

- Choose **System / 简体中文 / English** in Settings; the default follows macOS preferred languages.
- Settings, menu bar actions, window title, tooltips, previews, accessibility labels, recovery dialogs, and app error messages all follow the selected language.
- Changing language does not modify wallpaper settings or invalidate recovery records from 0.1.0.
- Both language catalogs ship inside the app bundle. Includes English and Chinese documentation.
- 21 regression cases cover wallpaper behavior, language resolution, preference persistence, catalog completeness, formatting, and deferred error translation.

Download `NotchVeil-macOS-arm64.zip`, unzip, and move the app to Applications. Requires macOS 13+ and Apple Silicon. This is a **developer preview with an ad-hoc signature, without Apple notarization**.

Dynamic wallpaper becomes a still image while enabled. Revisit treated Spaces to restore their wallpapers after disabling. Final menu bar appearance remains subject to macOS settings; see the README for compatibility and recovery details.

## 简体中文

- 设置中新增 **跟随系统 / 简体中文 / English**，默认按 macOS 首选语言自动适配。
- 设置页、菜单栏、窗口标题、提示文字、预览、辅助功能标签、恢复对话框及应用错误信息统一切换。
- 手动选择立即生效并保存；语言偏好独立存储，不影响壁纸配置及 0.1.0 恢复记录。
- 安装包内包含完整的两套语言资源，附中英文使用说明。
- 21 项回归检查覆盖壁纸处理、语言识别、偏好保存、文案完整性、格式参数和错误信息切换。

下载 `NotchVeil-macOS-arm64.zip`，解压并拖入“应用程序”。需要 macOS 13+ 和 Apple Silicon。此版本为 **ad-hoc 签名、未经 Apple 公证的开发预览版**。

开启后动态壁纸转为静态；关闭后需切回各个已处理桌面恢复。菜单栏最终外观仍受 macOS 设置影响，兼容性和恢复说明详见 README。
