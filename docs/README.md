# 项目接手说明

> 新开对话先读本文，再按“阅读顺序”查看对应文档。本文只写当前状态和文档结构，不记录长篇历史。

## 当前项目状态

- 项目：RustDesk HarmonyOS 客户端。
- 工作区：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- 当前 USB 测试设备：由 `RUSTDESK_HARMONY_USB_TARGET` 指定，文档不记录硬件编号。
- 当前无线测试设备：`192.168.11.100:36169`
- 包名：`com.open.rundesk`
- 当前 HAP 输出：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`
- 当前 native core 已接入真实 RustDesk session 路径，历史“仅模拟连接 / 真实网络未实现”不是当前状态。
- 2026-06-14 13 项目源码已补齐终端 official Session 调用和终端事件回流，修正音频空队列返回 `[]`，并同步 C++ 聊天四参 content 参数读取；commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 已推送并发布 `core-71`，11 项目已下载后完成 HAP 全量构建、验包、安装启动和 hilog 验证。
- 2026-06-14 13 项目继续补齐文件传输事件回流和 `switch-sides` option 路由；commit `275b231e11aefd4a2e51050fc74fbdeba9c566bd` 已由 run `27485061967` 发布 `core-73`。11 项目已下载 core-73 并完成全量 HAP 构建、验包和无线安装；设备当前锁屏导致 `aa start` 被系统拒绝，运行态 hilog 待解锁后继续复测。
- 2026-06-14 13 项目旧 Harmony source mirror 的 `send_clipboard_data()` 已同步 active bridge，commit `1b987914a2c27ace376e5af45a9c6790d84d40b4` 已由 run `27486100946` 发布 `core-74`。11 项目已下载 core-74，并完成全量 HAP 构建、验包、无线安装、解锁后启动和 hilog `coreReady=true` 验证。
- 2026-06-14 本轮 App 侧补齐连接页焦点、统一搜索、登录后通讯录同步、共享录屏授权、核心页启动/重启/加载/停止状态、会话/设置同源选项、文件授权 API、聊天发送/时间/窗口/模式菜单等逻辑；13 核心已发布自定义服务器 key 透传 `core-75` 与聊天事件语义修复 `core-76`。11 项目已下载 `core-76` 并全量构建 `0.20.0` / versionCode `1000096`，验包和无线安装通过；当前设备锁屏导致 `aa start` 被系统拒绝，运行态 hilog 等待手动解锁后继续复测。
- 2026-06-15 13 核心聊天 ABI 源项目回同步和 d.ts 自建服务器 `key` 参数已由 run `27515510727` 发布 `core-78`。11 项目已下载 `core-78` 并全量构建 `0.21.0` / versionCode `1000102`，验包、连接链路审计、无线安装启动和 hilog `coreReady` 验证通过。
- 2026-06-15 远控 direct session 命令已继续接入并验证：13 核心 commit `bc36b1d` 已由 run `27516993020` 发布 `core-79`；11 App 已同步 C++/d.ts/ArkTS，切换主控端、截图、会话录制、语音聊天改用核心 direct function 的 bool 返回值，会话录制不再触发本机录屏 API。已全量构建 `0.22.0` / versionCode `1000103`，无线安装启动和 app-only hilog 验证通过。
- 2026-06-15 权限链路复查：共享开关不再预申请 `CUSTOM_SCREEN_CAPTURE`，避免先唤起截屏/屏幕捕获授权；文件传输页和 `requestFileAccessAuthorization()` 默认改为 `DocumentViewPicker` 目录授权模式。增量构建 `0.22.1` / versionCode `1000104`，验包、连接链路审计、无线安装启动和严格 app hilog 验证通过。
- 2026-06-15 共享录屏底层切换：`ScreenCaptureService` 不再使用 `AVScreenCaptureRecorder` 和临时 mp4 探测文件，改为 C++ NAPI 调用 `OH_AVScreenCapture_StartScreenCapture` 并轮询 native buffer 统计；增量构建 `0.22.2` / versionCode `1000105`，验包、连接链路审计、无线安装启动和严格 app hilog 验证通过。
- 2026-06-15 共享入站帧进入核心缓存：13 核心 commit `12ad723` 已由 run `27526413545` 发布 `core-80` 并补中文 release 说明；11 App 已同步 incoming frame C ABI/NAPI/ArkTS wrapper，native screen capture buffer 会推入核心 `incoming_screen_frame` 缓存，但 `incomingReady` 仍保持 false 直到 desktop server/video source 接通。强制拉取线上 core-80 后增量构建 `0.22.4` / versionCode `1000107`，验包、66 项连接链路审计、无线安装启动和干净 hilog 验证通过。
- 2026-06-15 线上 ArkTS 严格模式复查：push 后 Linux/release workflow 在 `PermissionService.ets` 对文件授权结果的未显式对象字面量处失败，已改为显式 `PermissionRequestResult`；同时修正聊天摘要中文错字。强制拉取线上 core-80 后增量构建 `0.22.5` / versionCode `1000108`，验包、66 项连接链路审计、无线安装启动和干净 hilog 验证通过。
- 上一轮实机验证曾确认访问端收到真实视频帧，并显示远程画面。
- 当前本地工程生成信息：
  - BuildInfo 编译时间：`2026-06-15 07:32`
  - App 显示版本：`0.22.5`
  - versionCode：`1000108`
- 最新线上 Linux 构建验证：
  - Workflow：`.github/workflows/build-harmonyos.yml`
  - 成功 run：`27389574480` / `27389574466`
  - 最新发布：`https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-065038`
  - 最新 run：`27528204491` / `27528218065` 失败（提交 `c803bee`，根因为 `PermissionService.ets` 未显式对象字面量触发线上 ArkTS strict；已在本地 `0.22.5` 修复，等待下一次推送重跑）
  - 当前线上脚本已改为 HAP-only：只上传 `.hap`，不再生成或上传 APP、`.app.zip`、`manifest.json`、`SHA256SUMS.txt`
  - 签名材料校验通过，profile 有效期：`2026-06-03` 至 `2027-06-03`
- 当前线上 SDK/Hvigor 依赖：
  - SDK：`https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
  - Hvigor/Command Line Tools 剩余文件：`https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
  - SDK 包必须包含 `openharmony/previewer/common/bin/libcjson.so` 和 `libsec_shared.so`，否则 Linux CI 的 Hvigor/previewer 依赖会失败。
- 最新 100 轮功能逻辑审查已完成：`docs/FUNCTION_LOGIC_AUDIT_2026-06-06.md`

## 便携工作区路径

`%VSCODE_ROOT%` 表示包含 `11_Rustdesk_harmonyos/` 和 `99_Temp/` 的工作区根目录；当前 U 盘环境会按项目位置自动检测该根目录，后续借用不同电脑时盘符可能变化。项目文档、构建脚本和发布流程都不应再绑定某个固定盘符，而应按当前项目位置向上匹配同级 `99_Temp`。

当前匹配关系：

- App 项目：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- 本地 Git 根：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- RustDesk native core 独立项目：`%VSCODE_ROOT%\13_librustdesk_core`
- App 项目内核心链接：`%VSCODE_ROOT%\11_Rustdesk_harmonyos\13_librustdesk_core` 是本地 NTFS Junction，指向 `%VSCODE_ROOT%\13_librustdesk_core`；只作为本机开发便利，不提交到 Git
- RustDesk 上游源码：`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`
- 历史 Native 构建工作区：`%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build`
- HAP 输出、staging 和 Hvigor 缓存：`%VSCODE_ROOT%\99_Temp\harmonyos_build`、`%VSCODE_ROOT%\99_Temp\harmonyos_stage`、`%VSCODE_ROOT%\99_Temp\harmonyos_cache`
- 便携签名材料：`%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing`
- 备份目录：`%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_backups`
- GitHub 发布方式：本地项目根与远端仓库根一致，直接从当前项目根提交并推送。

换电脑后先确认三件事：

1. `11_Rustdesk_harmonyos/` 和 `99_Temp/` 仍在同一个 `%VSCODE_ROOT%` 下。
2. DevEco Studio 路径如不在默认位置，更新 `local.properties` 的 `sdk.dir`、`hwsdk.dir`、`npm.dir`，或设置 `DEVECO_SDK_HOME`、`DEVECO_TOOLS_HOME`、`DEVECO_NODE_EXE`、`HDC_EXE`。
3. U 盘文件系统可能触发 Git dubious ownership；临时查看可用 `git -c safe.directory=<当前11_Rustdesk_harmonyos路径> status`，不要为了消除提示执行普通 `git pull`。

当前 U 盘上存在历史生成目录权限残留：项目内 `.hvigor/`、`entry/build/`、`entry/.cxx/`，以及旧内层 `rustdesk_harmonyos/` 空缓存壳可能无法删除。构建脚本会先复制干净副本到 `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`，再把 Hvigor cache、HAP 输出和 Native `.cxx` 放到 `%VSCODE_ROOT%\99_Temp`；日常使用 `scripts\build_hap.bat` 或 `scripts\build_full_hap.bat`，不要直接运行 DevEco/Hvigor 内置 clean。`scripts\clean_project.ps1 -IncludeExternalBuild` 清理外部 build/stage 产物；只有明确需要深度清理时才额外加 `-IncludeHvigorCache`。

## 当前核心状态

- 核心加载方案：`staticlib + CMake 直接链接`
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`
- `librustdesk_bridge.so` 直接链接 `entry/src/main/libs/arm64/librustdesk_core.a`
- 当前 verified native core：
  - release：`core-80`
  - 大小：`131,624,954` bytes
  - 编译时间/mtime：`2026-06-15 07:15`
  - FNV-1a 1MB：`bea81e95`
  - SHA256：`4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`
  - 默认下载地址：`https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- 核心页应显示三个状态入口：
  - `Adapter`
  - `Native Module`
  - `Native Core`
- 每个入口都应有详情菜单。
- 详情菜单中的 Native Core 时间、大小和 hash 应来自 `CoreBuildInfo.ets` 记录的 `librustdesk_core.a` 文件信息，不应使用 App `BuildInfo` 兜底。

## 当前重点问题

共享服务启动：

- **ScreenCaptureService 当前走原生屏幕采集**（2026-06-15）：ArkTS 不再使用 `@ohos.multimedia.media` 的 `AVScreenCaptureRecorder`，C++ NAPI 改为 `OH_AVScreenCapture_StartScreenCapture` + native buffer 取帧统计；禁止再用 `@ohos.screenshot.capture()` 或临时 mp4 录制文件作为 fallback。
- Toggle 回弹、ForEach key、startCapture throw、录屏失败后仍启动 incoming 等问题已修复；共享开关现在先请求 native incoming 状态，只有 `incomingReady=true` 后才启动屏幕采集，且不再预申请 `CUSTOM_SCREEN_CAPTURE`，避免录屏前先唤起截屏/屏幕捕获授权。
- 原生 screen capture buffer 与 RustDesk desktop server/live frame 桥仍需继续对接；没有真实视频源时不得标记 `incomingReady=true`，避免其他设备连接后一直等待视频流。

LAN 发现（2026-06-03）：

- LAN 发现保持 30 秒周期轮询，手动刷新时重置 UI 状态并立即触发一次发现。
- 忽略列表删除后立即刷新，不再重新出现。
- 发现 listener 不再触发非发现 tab 闪烁。

服务器配置（2026-06-03）：

- 服务器对话框改为官方样式：小标签+底部细线分隔的TextInput，新增Key字段。
- 右上角导出（arrow-autofit-up）和导入（arrow-autofit-down）按钮，兼容官方 JSON→Base64→反转 格式。

UI 交互修复（2026-06-03）：

- 连接页面未登录时ID输入框始终可用。
- 通讯录未登录时只在通讯录tab内显示登录按钮，其他tab正常。
- 会话菜单（显示/鼠标/更多/聊天）已在 build() 中条件渲染，底部弹出，点击可正常弹出。
- 自定义键盘半透明背景，位置在屏幕顶部。
- ID卡片复制到输入框不激活输入法。
- ID输入框删除数字时光标保持位置不跳到末尾。
- 菜单箭头图标统一为 arrow-forward-ios 样式。

设置合并（2026-06-03）：

- 删除死代码 RemoteSettingsPanel.ets 和重复的 Settings.ets 独立页面，只保留 Index.ets 设置tab。

刷新修复（2026-06-03）：

- 发现tab使用独立 discoveredVersion 计数器，不再因其他操作闪烁。
- 内层 ForEach key 移除全局 version 号，避免条目销毁重建。
- 登录成功后立即触发 UI 刷新和地址簿拉取。
- 刷新按钮多重递增精简。

聊天tab完善（2026-06-03）：

- 会话结束后聊天tab显示聊天记录或"No messages yet."，不再显示"No active connection"。
- 连接成功时加载聊天记录，不再清空历史记录。

连接稳定性：

- 需要继续确认连接过程中是否还会在成功前先弹重试对话框。
- 2026-06-06 已优化：`createPixelMapSync` 改为异步、帧轮询16ms、stale阈值缩短、watchdog 5s、native帧主动推进；二次收紧 frameId 递增判断、PixelMap 超时和 native 推进节流。`0.6.12` 已构建并安装启动成功，点击连接可直接进入会话页；远端 `session-closed` / 非密码类 `session-error` 会清理旧画面并进入重连对话。
- 官方重试对话框只应在非人为断开且会话已有效建立后出现。
- 重试对话框按钮应为：取消、使用中继线路、重试。

名称和在线状态：

- ID 卡片第二行应显示官方格式：`用户名@设备名`。
- 所有来源都要确认：历史、发现、LAN、连接建立后的 peer info。
- LAN 只能作为发现来源，不能作为修复名称或全局在线状态的唯一依据。
- 离线状态刷新不应延迟 30 秒以上。

登录和共享：

- 需要继续确认 App 重启后登录态不丢失。
- 远程连接不应在 App 已登录时提示需要登录。
- 共享服务默认停止。
- 共享服务停止时不显示设备 ID 和密码；启动后才显示。
- 共享服务关闭状态必须持久化，App 重启后不能被核心 ready 流程自动打开。
- 生成密码后 UI 应立即刷新，并同步 native local options。
- 一次性密码必须写入官方临时密码 `temporary-password`，并设置 `verification-method=use-temporary-password`、`approve-mode=password`；不能只写 wrapper 内存 map。
- 未确认 official incoming ready 时不能显示为“运行中”，避免共享服务实际不可访问但 UI 显示正常。
- LAN 发现只在 App 打开时自动执行一次；之后需要用户手动刷新。手动刷新只清空 ArkTS/UI 发现状态并重新执行 `discoverLanPeers()` + `loadLanPeers()`，不能调用 native `removeDiscoveredPeer()` 清 LAN peers，否则会删除 RustDesk 原生发现结果。
- 通讯录必须登录后才能添加设备；未登录时通讯录区域显示登录入口，历史记录里的添加动作也必须先弹出登录。
- 文件访问授权必须同时申请必要权限位并唤起 `DocumentViewPicker`；文件传输页本地操作前必须走目录授权，不能只依赖远控入口提前授权。

输入和会话 UI：

- 触摸、鼠标、滚轮、键盘必须通过 active native session 真实转发。
- 自定义键盘应显示在视频画面顶部，并覆盖在画面上方；面板背景保持透明，不再在面板内放额外键盘按钮或关闭按钮。
- 会话显示菜单、鼠标菜单、更多菜单、连接质量浮层都必须保证关闭入口可见；菜单内容超过屏幕时必须可滚动。
- 聊天、文件传输、重启远程、锁屏、阻止输入、插入 Ctrl+Alt+Del、截图、会话录制等入口不能只显示菜单，至少要有 native 调用或明确的本地排队/不可用提示；`Ctrl+Alt+Del` 当前必须走 `sendCtrlAltDel()` 到 official `Session::ctrl_alt_del()`，不能再用普通键盘事件模拟。

## 文档阅读顺序

1. `AGENT_MEMORY.md`
   - AI 助手记忆：工作规则、用户偏好、项目经验、处理流程。新对话必须先读。
2. `README.md`
   - 当前接手入口，说明项目状态、问题结构、文档用途。
3. `CORE.md`
   - 核心状态、HAP 构建安装、运行验证清单。核心架构和桥接函数详见 13 项目 `docs/CORE.md`。
4. `PROGRESS.md`
   - 当前功能完成度、已完成事项、当前重点问题。
5. `ISSUES.md`
   - 问题库和易复发坑，修改前查这里。
6. `FILES.md`
   - 文件职责和外部依赖目录说明。
7. `README.md`（项目根，设计要求）
   - 架构、UI、构建、真机测试设计约束。原 `docs/DESIGN.md` 已合并到项目根 `README.md`。
8. `UI.md`
   - UI 布局、图标、核心页面卡片细节。
9. `GIT_PUBLISH.md`
   - GitHub 发布规则：本地和远端均为项目根结构；包含正常提交推送流程和生成物禁止项。

**已迁移到 13 项目的核心文档**（`%VSCODE_ROOT%\13_librustdesk_core\docs\`）：
- `CORE.md` — 核心架构、桥接函数完整说明（369个函数）、编译问题
- `BUILD_ARCHIVE.md` — 历史构建、脚本、Ubuntu路径归档
- `CONNECTION_DEBUG_LOG.md` — 连接问题逐轮排查记录
- `UBUNTU_CROSS_COMPILE_GUIDE.md` — Ubuntu 交叉编译指南
- `FUNCTION_LOGIC_AUDIT_*.md` — 功能逻辑审计
- `SESSION3_SUMMARY.md` — 会话3总结
- `WINDOWS_SERVICE_OPTIMIZATION.md` — Windows 服务优化

## 当前构建命令

增量构建 HAP：

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..).Path
Set-Location "$env:VSCODE_ROOT\11_Rustdesk_harmonyos"
cmd /c scripts\build_hap.bat
```

安装并启动：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$env:VSCODE_ROOT = (Resolve-Path ..).Path
$target = $env:RUSTDESK_HARMONY_USB_TARGET
$hap = "$env:VSCODE_ROOT\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap"
& $hdc -t $target install -r $hap
& $hdc -t $target shell aa start -a EntryAbility -b com.open.rundesk
```

重编 native core（独立核心项目）：

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..).Path
Set-Location "$env:VSCODE_ROOT\13_librustdesk_core"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1
```

线上构建 HAP：

```text
GitHub Actions -> Build HarmonyOS HAP Linux
version_bump: incremental
skip_package_verify: true
publish_release: true
```

线上 workflow 会下载 `harmonyos-sdk-full.zip`、`harmonyos-hvigor-full.zip` 和 `RUSTDESK_CORE_URL` 指向的 `librustdesk_core.a`；未设置 `RUSTDESK_CORE_URL` 时默认跟随 `librustdesk_core` 仓库 latest release 的 `librustdesk_core.a`。线上脚本只构建和上传 HAP。

2026-06-14 本地 core-74 验证：`librustdesk_core.a` 从 `core-74` release 下载，HAP 全量构建为 `0.19.0` / versionCode `1000090`，signed HAP `18,828,000` bytes / SHA256 `4BF796ED37DD1FCADF455F1585A55E36CFFC58940235D82FCAC55C6CBA6042A1`。`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，无线设备安装成功；`bm dump` 显示 `versionName=0.19.0`。手动解锁后 `aa start` 成功，进程 `4232` 20 秒后仍存活；hilog `coreReady= true` 5 次、`query-onlines-result` 6 次，app fatal/panic/signal 为 0。

2026-06-14 追加复核：文档更新后手机再次解锁，执行 `scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169` 复装并启动成功；`pidof com.open.rundesk` 返回 `12565`。`reports/hilog_latest_after_core74_post_docs_unlocked.txt` 记录 `coreReady= true` 7 次、`query-onlines-result` 14 次、app log lines 314，app fatal/panic/signal 为 0。

2026-06-14 core-76 本地验证：`librustdesk_core.a` 从 `core-76` release 下载，HAP 全量构建为 `0.20.0` / versionCode `1000096`，signed HAP `18,909,325` bytes / SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`。`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过 native/signature 校验，无线设备安装成功，`bm dump` 显示 `versionName=0.20.0`、`versionCode=1000096`；当前设备锁屏导致 `aa start` 返回 `Error Code:10106102`，运行态 hilog 待手动解锁后继续复测。

## 接手规则

- 不要再按旧文档判断“真实网络未实现”；当前问题是稳定性、首帧、断线重试、名称刷新、登录态和在线状态。
- 每次修改代码、资源、脚本或文档，都必须同步更新相关项目文档，保持新开对话读取文档即可接手。
- 每轮修改后必须进行构建验证；ArkTS/UI 修改至少运行 HAP 构建，涉及 native core 时先重编 native core，再构建 HAP。
- 涉及设备行为、会话连接、共享服务、LAN 发现或输入转发时，构建后优先使用 USB 设备安装启动验证。
- 修改核心后必须先在 `%VSCODE_ROOT%\13_librustdesk_core` 构建并发布 `librustdesk_core.a`，再由 11 项目构建脚本从 latest release 或 `RUSTDESK_CORE_URL` 下载到 `entry/src/main/libs/arm64/librustdesk_core.a`，随后构建 HAP 并安装验证。
- 修改 ArkTS/UI 后至少重新构建 HAP 并安装验证。
- 多目标 HDC 环境必须显式加 `-t <target>`。
- 当前优先使用 `RUSTDESK_HARMONY_USB_TARGET` 指定的 USB 目标。
- 历史无线目标 `192.168.11.100:36169` 仅备用。
- GitHub 仓库展示结构和本地工作结构一致：项目根为 `%VSCODE_ROOT%\11_Rustdesk_harmonyos`，直接从当前项目根提交并推送；发布前先读 `docs/GIT_PUBLISH.md`。

## 2026-06-03 当前补充

- 服务器配置默认值已改为“官方默认但不显示”：设置中空 ID/Relay/API 会在运行时回落到官方 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`，UI 只显示“官方默认”。
- 扫码页已改为相机扫码页，支持相册图片二维码识别；扫到服务器配置导入文本时会直接写入服务器配置并保存，扫到普通设备 ID 时继续写入最近会话和通讯录。
- 共享服务 native incoming 入口在未接入真实屏幕采集/desktop server 时返回 `incomingReady=false`，不能再用 incoming requested 假运行状态对外宣称可被控；真实被控画面仍需后续接入 Harmony 可用录屏/采集链路。

## 2026-06-05 当前补充

- `scripts\build_hap.bat` 标记为增量构建，每次构建将版本号右侧数字自增 1。
- `scripts\build_full_hap.bat` 标记为全量构建，每次构建将版本号中间数字自增 1，并把右侧数字归零。
- `run_hvigor_with_sdk_patch.js` 会同步更新 `AppScope/app.json5` 的 `versionName/versionCode` 和 `BuildInfo.ets` 的 `BUILD_TIME/VERSION`。
- 项目根目录新增 `README.md`，线上仓库默认介绍为完整项目设计要求（原 `docs/DESIGN.md` 已合并到根 README.md）。
- 聊天Tab用于显示当前/最近一次会话中的聊天内容；会话结束返回主页后会刷新同一会话历史，peer信息只替换聊天Tab头部区域，并保留右侧 `group.svg` 图标。远控会话中的聊天浮窗在打开、发送和收到消息后都会滚动到最新消息。
- 已移除固定测试聊天消息和本地模拟自动回复，聊天记录只来自真实会话收发或持久化历史。
