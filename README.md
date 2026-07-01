# RustDesk HarmonyOS 客户端

> 本项目是独立的第三方 RustDesk 兼容 HarmonyOS / OpenHarmony 客户端，不属于 RustDesk 官方发布、认可、赞助或背书项目。修改方向必须符合当前设计和合规要求，新接手开发请先读 `docs/AGENT_HANDOFF.md`，再按 `docs/README.md` 的顺序继续。

## 当前状态

当前事实以 [`docs/CURRENT_STATUS.md`](docs/CURRENT_STATUS.md) 为准。

摘要：

- 工程类型：HarmonyOS / OpenHarmony ArkTS Stage 应用。
- 包名：`com.open.rundesk`。
- `oh-package.json5`：`modelVersion 6.1.1`，工程名 `rustdesk_harmonyos`，版本字段 `1.0.0`。
- 许可证：`AGPL-3.0-only`。
- UI：ArkTS / ArkUI。
- Native：C++ NAPI → Rust C ABI。
- Core：从 `liyan-lucky/librustdesk_core` Release 下载并链接 `librustdesk_core.a`。
- 文档记录的最新维护构建：`0.33.16` / `versionCode 1000192`，BuildInfo `2026-06-25 07:22`。
- 线上构建当前为 HAP-only，只上传 `.hap`。

## 当前能力边界

### 已完成或已接入

- 核心加载：staticlib + CMake 直接链接，NAPI 注册，`coreReady=true`。
- 远程连接：接入 RustDesk session 路径，真实视频帧渲染，peer info 获取。
- 服务器配置：官方样式导入/导出，兼容 JSON → Base64 → 反转格式。
- LAN 发现、登录、通讯录、统一搜索、聊天、设置、扫码等 App 侧主要页面能力已接入。
- 共享录屏底层使用 native `OH_AVScreenCapture_StartScreenCapture` + native buffer 统计，不再使用截图 API、`AVScreenCaptureRecorder` 或临时 mp4 探测。

### 当前限制

- 华为手机作为被控端的远程操控/输入注入按平台不支持处理，当前搁置，不作为发布阻塞项。
- 文件传输、五编码、远程光标和全部访问端会话菜单仍需端到端回归。
- 有菜单入口时必须有真实 native 调用、跳转参数、失败提示、本地排队提示或明确不可用说明，不能宣称未验证能力已完成。

## 架构设计

```text
ArkTS UI (entry/src/main/ets/)
    -> C++ NAPI (entry/src/main/cpp/)
    -> Rust C ABI
    -> librustdesk_core.a
    -> RustDesk session/core
    -> RustDesk Server / Peer
```

双仓库分工：

| 仓库 | 职责 |
| --- | --- |
| `liyan-lucky/rustdesk_harmonyos` | App UI、C++ NAPI、构建脚本、HAP、应用层文档 |
| `liyan-lucky/librustdesk_core` | Rust 桥接层、上游源码、OHOS 补丁、核心静态库 CI/CD |

## 文档入口

- [当前仓库状态](docs/CURRENT_STATUS.md)
- [接手说明](docs/AGENT_HANDOFF.md)
- [文档索引](docs/README.md)
- [路径规范](docs/WORKSPACE_PATHS.md)
- [核心状态与构建验收](docs/CORE.md)
- [Release 产物规则](docs/RELEASE_ARTIFACT_POLICY.md)
- [SDK/toolchain 使用规则](docs/HARMONYOS_TOOLCHAIN.md)
- [供应链与 SBOM](docs/SUPPLY_CHAIN.md)
- [资产来源登记](docs/ASSET_PROVENANCE.md)

## 分支和备份

- `master`：当前主工作分支。
- `backup`：`master` 的快照备份分支。
- `.github/workflows/force-backup-master.yml`：手动输入 `YES` 后，把 `master` 当前提交强制覆盖到 `backup`。

## 构建与路径规则

- 所有构建、测试、验包、日志、备份和临时证据统一写入 `%VSCODE_ROOT%\99_Temp`。
- `99_Temp` 是多个项目共享目录，禁止整体清空，任何 APK/HAP 一律不得随意删除。
- 不要使用盘符根目录、仓库内 `.codex_*`、工作区根 `_tmp_*` 或个人临时目录作为长期路径。
- 构建、安装、验包和设备行为变化后，必须同步更新相关文档。

## 合规与发布入口

- 许可：`LICENSE`，项目源码默认按 `AGPL-3.0-only` 分发。
- 归属与声明：`NOTICE`、`THIRD_PARTY_NOTICES.md`、`TRADEMARKS.md`。
- 隐私与安全：`PRIVACY.md`、`SECURITY.md`。
- 贡献规则：`CONTRIBUTING.md`。
- AGPL 对应源码说明：`SOURCE_OFFER.md`。
- Release 产物规则：`docs/RELEASE_ARTIFACT_POLICY.md`、`RELEASE_COMPLIANCE_CHECKLIST.md`。

不要把 HarmonyOS SDK、DevEco、hvigor、ohpm、签名材料、私钥、token、用户数据或构建缓存发布到公开 Release 或提交进仓库。线上构建只能通过授权来源的 `HARMONYOS_SDK_URL` 和 `HARMONYOS_FULL_URL` 获取工具链。

## 维护要求

1. 当前事实变化先同步 `docs/CURRENT_STATUS.md`、根 README 和 `docs/README.md`。
2. 涉及 native core 时先更新 `librustdesk_core` 并发布核心，再构建 HAP。
3. 涉及设备行为时优先 USB 或明确目标设备安装启动验证。
4. 每次修改代码、资源、脚本或文档后，必须同步更新相关项目文档。
