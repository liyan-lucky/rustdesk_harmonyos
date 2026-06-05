# DESIGN

> 线上仓库默认介绍。当前项目设计要求以 `docs/DESIGN.md` 为准；新接手开发请先读 `docs/README.md`，再按文档阅读顺序继续。

RustDesk HarmonyOS 客户端采用 `staticlib + CMake` 直接链接方案：RustDesk 核心编译为静态库，由 `librustdesk_bridge.so` 通过 NAPI 暴露给 ArkTS。协议、加密、会话管理和文件传输保留 Rust 实现；录屏、音频、输入、文件访问和 UI 按 HarmonyOS 能力重写。

UI 和交互必须跟随项目现有设计：透明状态栏、顶部渐变、主题色由 `AppStorage` 管理、SVG 图标随主题着色、国际化通过 `I18nService.translate()` 与 `i18nVersion` 刷新。菜单入口必须有真实行为、失败提示或明确不可用说明。

构建和发布遵守便携工作区规则：所有临时产物、staging 副本、备份、HAP 输出和缓存默认放在 `%VSCODE_ROOT%/99_Temp/`，不要在文档或脚本里写死盘符或设备硬件编号。增量构建自增 `0.x.patch` 的右侧数字；全量构建自增中间数字并将右侧数字归零。
