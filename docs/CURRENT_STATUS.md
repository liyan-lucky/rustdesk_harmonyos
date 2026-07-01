# 当前仓库状态

更新时间：2026-07-01

## 定位

`rustdesk_harmonyos` 是独立的 HarmonyOS / OpenHarmony RustDesk 兼容客户端仓库，采用 ArkTS Stage UI、C++ NAPI 桥接和 Rust 静态库核心。项目源码按 `AGPL-3.0-only` 分发。

本项目是第三方兼容客户端，不属于 RustDesk 官方发布、认可、赞助或背书项目。

## 当前工程信息

- `oh-package.json5`：`modelVersion` 为 `6.1.1`，包名为 `rustdesk_harmonyos`，版本字段为 `1.0.0`。
- App 包名：`com.open.rundesk`。
- UI：ArkTS / ArkUI Stage 模型。
- Native：C++ NAPI → Rust C ABI。
- Core：从 `liyan-lucky/librustdesk_core` Release 下载并链接 `librustdesk_core.a`。
- 当前文档记录的最新维护构建：`0.33.16` / `versionCode 1000192`，BuildInfo `2026-06-25 07:22`。

## 当前能力边界

- 核心加载：staticlib + CMake 直接链接，NAPI 注册，`coreReady=true`。
- 远程连接：已接入 RustDesk session 路径，真实视频帧渲染，peer info 获取。
- 访问端控制：手机作为访问端控制远端 PC 的触摸、鼠标、滚轮、键盘等仍按 native active session 路径收口。
- 被控端限制：华为手机作为被控端的远程操控/输入注入按平台不支持处理，当前搁置，不作为发布阻塞项。
- 文件传输、五编码、远程光标和全部访问端会话菜单仍需端到端回归。
- 线上构建当前为 HAP-only；Release 和 workflow artifact 只上传 `.hap`，不再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。

## 当前分支和备份

- `master`：当前主工作分支。
- `backup`：`master` 的快照备份分支。
- `.github/workflows/force-backup-master.yml`：手动输入 `YES` 后，把 `master` 当前提交强制覆盖到 `backup`。

## 目录和文档职责

- `entry/`：HarmonyOS App 主模块、ArkTS UI、C++ NAPI、资源和 native libs。
- `scripts/`：本地构建、安装、审计和辅助脚本。
- `docs/`：接手、路径、构建、测试、发布、合规和当前状态文档。
- `docs/AGENT_HANDOFF.md`：跨对话接手第一入口。
- `docs/README.md`：文档阅读顺序。
- `docs/WORKSPACE_PATHS.md`：构建、测试、日志、备份和临时证据路径规范。

## 合规边界

- 不提交 HarmonyOS SDK、DevEco、hvigor、ohpm、签名材料、私钥、token、用户数据或构建缓存。
- 线上构建只能通过授权来源提供工具链。
- 发布产物必须遵守 AGPL 源码提供义务和第三方依赖许可证。
- 不宣称官方授权、官方发布或官方背书。

当前功能、构建、Release、路径或验收状态变化时，必须同步更新本文件、根 README、`docs/README.md` 和相关专项文档。
