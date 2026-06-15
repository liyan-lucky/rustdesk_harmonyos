# 核心状态与 HAP 构建验证

> 本文档记录 HAP 项目的核心状态、构建安装流程和运行验证清单。核心架构、桥接函数说明、编译问题等详见 `%VSCODE_ROOT%\13_librustdesk_core\docs\CORE.md`。

## 当前结论

- 当前采用 `staticlib + CMake 直接链接` 方案。
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`。
- `librustdesk_bridge.so` 直接链接 Rust staticlib：`entry/src/main/libs/arm64/librustdesk_core.a`。
- 不再使用 `dlopen` 加载 Rust 核心，避免 TEXTREL 和运行时加载问题。
- **核心构建已迁移到独立项目 `%VSCODE_ROOT%\13_librustdesk_core`**：
  - Rust 桥接层、C++ 桥接层、代码生成脚本均在 13 项目维护
  - 核心修改流程：13 项目修改 → git push → GitHub Actions 构建 → 下载 → 放入 11 项目
  - GitHub Releases：`https://github.com/liyan-lucky/librustdesk_core/releases`
- 当前页面应显示三个核心状态入口：`Adapter`、`Native Module`、`Native Core`
- 当前核心已经接入真实 RustDesk 会话路径
- 2026-06-14 13 项目源码已补齐终端 official Session 调用、终端响应事件、音频空队列 `[]` 和 C++ 聊天四参兼容；核心 commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 已推送并由 GitHub Actions run `27483922931` 发布 `core-71`，11 项目已下载、全量构建、验包并安装验证。
- 2026-06-14 13 项目源码已继续补齐文件传输回调事件和 `switch-sides` option 路由，提交 `9c6ad4d`、`275b231e11aefd4a2e51050fc74fbdeba9c566bd` 已推送，GitHub Actions run `27485061967` 成功发布 `core-73`；11 项目已下载 core-73 并完成全量构建、验包和无线安装。设备当前锁屏导致 `aa start` 被系统拒绝，运行态 `coreReady` 待解锁后继续复测。
- 2026-06-14 13 项目旧 Harmony source mirror 的 `send_clipboard_data()` 已同步 active bridge，commit `1b987914a2c27ace376e5af45a9c6790d84d40b4` 已由 GitHub Actions run `27486100946` 发布 `core-74`；11 项目已下载 core-74 并完成全量 HAP 构建、验包、无线安装、解锁后启动和 hilog `coreReady=true` 验证。
- 2026-06-14 13 项目已发布自定义服务器 key 透传 `core-75` 和聊天事件语义修复 `core-76`：`start_service/session_start` 新增 key 参数，空服务器配置会清理旧 option；聊天失败为 `chat-error`、发送成功为 `chat-sent`、远端消息才是 `chat-message`。11 项目已下载 `core-76` 并完成全量构建、验包和无线安装。
- 2026-06-15 13 核心项目已回同步聊天 ABI 源文件修复和 d.ts 自建服务器 key 参数：`rustdesk_bridge_session_send_chat` 的 C++ 声明和调用改为四参，`connectToPeer/setIncomingServiceEnabled` 类型补齐 `key`，避免后续同步覆盖 11 App 已修路径；commits `034e446`、`cc5f4de` 已推送，GitHub Actions run `27515510727` 成功发布 `core-78`，release asset `131,470,442` bytes，SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`。11 App 已下载并全量构建 `0.21.0`，无线安装启动和 hilog `coreReady` 验证通过。
- 2026-06-15 远控 direct session 命令状态返回已在 13 核心 commit `bc36b1d` 推送并发布 `core-79`：Rust bridge、C ABI、C++ NAPI、核心/app d.ts 均改为 bool 返回，并补 `voice-call-*`、`record-status`、`screenshot-response` 事件；11 App 侧远控菜单已同步 direct function 调用，会话录制不再触发本机 `ScreenCaptureService`。11 App 已全量拉取 core-79 构建 `0.22.0` 并无线安装/hilog 验证通过。
- 2026-06-15 App 权限链路继续验证为 `0.22.1` / versionCode `1000104`：共享启动去掉 `CUSTOM_SCREEN_CAPTURE` 预申请，文件传输页改为主动唤起 `DocumentViewPicker` 目录授权；core-79 staticlib 未变化，增量构建、验包、连接链路审计、无线安装启动和严格 app hilog 均通过。
- 2026-06-15 App 屏幕采集底层继续验证为 `0.22.2` / versionCode `1000105`：`ScreenCaptureService` 不再创建 `AVScreenCaptureRecorder` 或临时 mp4 探测文件，改为 C++ NAPI 调用 `OH_AVScreenCapture_StartScreenCapture` 并轮询 native buffer 统计；core-79 staticlib 未变化，增量构建、验包、连接链路审计、无线安装启动和严格 app hilog 均通过。
- 2026-06-15 core-80 入站帧缓存已发布并在 11 App 验证：13 核心 commit `12ad723` / run `27526413545` 发布 `core-80`，新增 `updateIncomingScreenFrame/getIncomingScreenFrameMetadata/copyIncomingScreenFrame/clearIncomingScreenFrame`；11 App 强制拉取线上 core-80 构建 `0.22.4` / versionCode `1000107`，验包、66 项连接链路审计、无线安装启动和干净 hilog 验证通过。当前只接通 native buffer 到核心缓存，`incomingReady` 仍不能置 true。
- 2026-06-15 App 侧 CI strict 修正已验证为 `0.22.5` / versionCode `1000108`：线上 Linux/release workflow 在 `PermissionService.ets` 未显式对象字面量处失败，本地已改为显式 `PermissionRequestResult` 并修正聊天摘要中文错字；core 仍为 `core-80`，增量构建、验包、66 项连接链路审计、无线安装启动和干净 hilog 均通过。
- 2026-06-15 本地 core-81 预发布验证已通过：13 核心新增 OHOS `scrap::common::ohos::Capturer` incoming frame source，并让 `main_start_service(true)` 返回 `captureRequired=true`、`incomingReady=false`，由 App 启动 native `OH_AVScreenCapture_StartScreenCapture` 提供首帧；App `0.22.6` 已用本地 staticlib 构建、验包、66 项审计、无线安装和干净 hilog 验证通过。该记录为线上 core-81 发布前的历史过程，当前已由 `0.22.7` 线上 core-81 验证替代。
- 2026-06-15 线上 core-81 验证已通过：13 核心 commit `c5b3eeb` / run `27563925971` 发布 `core-81`，线上 asset `131,631,706` bytes，SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`；11 App 强制拉取线上 core-81 构建 `0.22.7` / versionCode `1000110`，验包、66 项审计、静态录屏 API 扫描、无线安装和干净 hilog 验证通过。

## 架构总览

```text
ArkTS UI (11_Rustdesk_harmonyos)
    -> NAPI
librustdesk_bridge.so
    -> C++ bridge loader (entry/src/main/cpp/)
    -> Rust C ABI
librustdesk_core.a (从 13 项目 GitHub Releases 下载)
    -> rustdesk_harmony_bridge
    -> RustDesk official session/core (13_librustdesk_core/rustdesk-master/)
RustDesk Server / Peer
```

关键关系：

- Harmony app project: `%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- RustDesk native core project: `%VSCODE_ROOT%\13_librustdesk_core`
- Core staticlib in app: `%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`
- HAP staged project copy: `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/cpp/` | 从 13 项目同步到 App 项目的 C++ 桥接层 |
| `entry/src/main/cpp/CMakeLists.txt` | 将 `librustdesk_core.a`、`native_avscreen_capture`、`native_buffer` 链接进 `librustdesk_bridge.so` |
| `entry/src/main/libs/arm64/librustdesk_core.a` | 从 GitHub Releases 下载的 Rust staticlib |
| `entry/src/main/ets/common/CoreBuildInfo.ets` | 构建时生成的 native core 文件大小、mtime 和 hash 信息 |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | ArkTS 原生桥接封装，包含 native 屏幕采集 NAPI 包装 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 官方连接状态和事件封装 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程会话 UI、视频帧、输入、重试弹窗 |

## 上游源码版本

- 当前编译基于：**RustDesk 1.4.7**
- 升级状态：**已完成并验证**
- 源码位置：`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`

## 当前验证过的产物

Native core:

- 文件：`entry/src/main/libs/arm64/librustdesk_core.a`
- Source URL: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Latest online release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-81`
- Latest online size: `131,631,706` bytes (`125.53 MB`)
- Latest online SHA256: `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`
- Latest online workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27563925971`

HAP:

- Bundle: `com.open.rundesk`
- ABI: `arm64-v8a`
- Wireless target: `192.168.11.100:36169`
- Latest local pre-release validation: 2026-06-15 使用本地 core-81 staticlib 构建 `0.22.6` / versionCode `1000109`；signed HAP `18,433,473` bytes，SHA256 `4D669584F44B6462F570747723E66EB2894204FF7860CA0FBB27339D7FCE7DDD`；`verify_native_harmonyos_hap.ps1` 通过 native/signature 校验，`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`；无线目标 `192.168.11.100:36169` 安装和启动成功，设备上 `versionName=0.22.6`、`versionCode=1000109`，`pidof com.open.rundesk` 返回 `7527`。干净 app hilog `reports\hilog_latest_after_0226_localcore_wireless_app_strict_clean_x.txt` 中 app fatal/panic/`exit(-1)`/signal bad count 为 0。
- Latest validation: 2026-06-15 强制下载线上 `core-81` 后增量 HAP 构建通过；signed HAP `18,978,267` bytes，SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`；unsigned HAP `18,899,289` bytes，SHA256 `2BE7B2E594B03868D5E8C6939ACB8FE4AD5B2476959498A43DD1A5E03A12C03B`；`verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 通过 native/signature 校验，`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`；无线目标 `192.168.11.100:36169` 安装和启动成功，设备上 `versionName=0.22.7`、`versionCode=1000110`，`pidof com.open.rundesk` 返回 `40016`。干净 app hilog `reports\hilog_latest_after_0227_core81_wireless_app_strict_clean_x.txt` 中 app/core 相关 132 行，app fatal/panic/`exit(-1)`/signal/native core missing bad count 为 0。

## Native core 构建来源

当前核心构建的权威来源是独立项目 `%VSCODE_ROOT%\13_librustdesk_core`，11 项目只消费构建产物。

下载后放入：

```text
%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a
```

当前 11 项目构建脚本默认使用：

```text
RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a
RUSTDESK_CORE_SHA256=
```

默认不设置 `RUSTDESK_CORE_SHA256`，这样 13 项目自动发布新 tag 并更新 latest release 后，11 项目的本地和线上构建都会在构建前下载最新 `librustdesk_core.a`。如果需要固定某一次核心产物，再显式设置 `RUSTDESK_CORE_URL` 和 `RUSTDESK_CORE_SHA256`。

## 构建和安装 HAP

构建：

```cmd
cd %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_hap.bat
```

全量构建 HAP：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_full_hap.bat
```

一键构建、安装、启动：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\AUTO_BUILD_INSTALL.bat auto
```

手动安装、启动：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$target = "192.168.11.100:36169"
Push-Location "L:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default"
& $hdc -t $target install -r entry-default-signed.hap
Pop-Location
& $hdc -t $target shell aa start -a EntryAbility -b com.open.rundesk
```

多目标环境必须始终显式加 `-t <target>`。安装当前设备时不要加 `-g`。

## 运行验证清单

基础状态：

- App 可启动，`com.open.rundesk` 前台存活
- NAPI 注册成功（400 functions）
- `coreReady=true`
- 核心页显示 `Adapter`、`Native Module`、`Native Core` 三个状态入口
- 每个核心状态入口都有对应详情菜单

共享页：

- 共享服务默认停止
- 停止状态下不显示设备 ID 和密码
- 只有核心返回 `incomingReady=true` 后才显示设备 ID 和一次性密码；本机 native 屏幕采集处于 active 时不得展示为服务运行中。
- **当前限制**：线上 core-81 已让 OHOS `scrap::Capturer` 可消费核心 incoming frame cache，App 看到 `captureRequired=true` 会启动原生屏幕采集并推首帧；但 `incomingReady` 仍需等 RustDesk desktop server/video source 真实 ready 后才能置 true。
- 2026-06-12 起，录屏/被控视频源不可用时共享服务不得进入假运行状态：App 侧回滚 `serviceEnabled/allowRemoteControl`，native core `main_start_service(true)` 返回 `incomingReady=false` 和明确错误，避免其他设备连接后一直等待视频流。
- 2026-06-14 复查：共享页 UI 已把“录屏探测 active”和“核心 incoming ready”拆开，录屏探测只显示黄色 `Recording Probe` 状态并保留停止按钮，真实共享运行态只由 `settings.serviceEnabled && officialCoreState.incomingReady` 决定。

远程连接：

- 连接过程不应在成功前先弹重试对话框
- 只有非人为断开，且会话已经进入有效连接状态后，才显示官方重试对话框
- 访问端应收到 `session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`
- 远程触摸必须调用 `sendMouseInput()`，native core 应发出/处理 `mouse-input`
- 插入 `Ctrl+Alt+Del` 必须调用 `sendCtrlAltDel()`

## 历史记录

| 日期 | 状态 | 说明 |
| --- | --- | --- |
| 2026-05-02 | 成功 | 原始 Native 核心可工作 |
| 2026-05-29 | 成功 | staticlib + CMake 直接链接验证通过 |
| 2026-06-01 | 成功 | 实机安装启动通过，`coreReady=true` |
| 2026-06-02 | 成功 | 接入真实会话事件、视频刷新、帧读取、peer-info |
| 2026-06-07 | 成功 | 1.4.7 升级完成；修复密码框丢失、LAN发现失效 |
| 2026-06-08 | 成功 | 大规模函数补齐：54→369个桥接函数；官方一致性修复 |
| 2026-06-12 | 成功 | 核心项目迁移到 13_librustdesk_core；AvoidAreaType.TYPE_INPUT→TYPE_KEYBOARD 修复；WiFi 安装验证通过 |
| 2026-06-13 | 部分成功 | `core-70` 下载并构建 HAP 成功；HAP native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，视频流待解锁后复测 |
| 2026-06-14 | 成功 | `core-71` 下载并全量构建 HAP 成功；native/signature 校验、WiFi 安装启动和 hilog `coreReady=true` 验证通过；终端 bridge、音频空队列、聊天四参和 staging junction 排除已完成 |
| 2026-06-14 | 部分成功 | `core-73` 下载并全量构建 HAP 成功；native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，文件传输事件和 `switch-sides` 运行态待解锁后复测 |
| 2026-06-14 | 成功 | `core-74` 下载并全量构建 HAP 成功；native/signature 校验、WiFi 安装启动和 hilog `coreReady=true` 验证通过；旧 Harmony source mirror 剪贴板同步防回归已发布 |
| 2026-06-14 | 部分成功 | `core-76` 下载并全量构建 HAP 成功；native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，聊天语义和自建服务器 key 运行态待解锁后复测 |

## 2026-06-03 服务器与共享核心状态

- 服务器配置有效值统一由 `AppDataService.resolveServerConfig()` 解析
- `OfficialRustDeskBridge` 的刷新、连接、共享服务启动均使用解析后的有效服务器配置；自建服务器的 key 必须和 server/relay/api 一起传入 `start_service` 与 `session_start`
- Harmony bridge 在未接入真实屏幕采集/desktop server 时不能标记 incoming ready；`main_start_service(true)` 返回 `incomingReady=false`，防止被控端无视频源却让远端等待视频流。
- 系统截图 fallback 已确认会崩溃并被禁用；当前 App 侧使用 native `OH_AVScreenCapture_StartScreenCapture` 做屏幕采集启动和 native buffer 统计，后续仍需接入 live frame/desktop server。

## 2026-06-15 verified current core

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-81`
- Native core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27563925971`
- Native core commit: `c5b3eeb` (`Add OHOS incoming capture source`)
- Native core size: `131,631,706` bytes (`125.53 MB`)
- Native core SHA256: `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`
- HAP build verified: version `0.22.7`, versionCode `1000110`, signed HAP `18,978,267` bytes, SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.100:36169`; `bm dump` showed `versionName=0.22.7`, `versionCode=1000110`, native library path `entry/libs/arm64`
- Launch/runtime status: `aa start` succeeded, process `40016` stayed alive; `reports\hilog_latest_after_0227_core81_wireless_app_strict_clean_x.txt` recorded 7252 lines, 132 app/core-related lines, and app fatal/panic/`exit(-1)`/signal/native core missing bad count 0.

## 2026-06-14 verified core-76

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-76`
- Native core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27505721889`
- Native core commit: `1f474fc` (`Fix Harmony chat event semantics`)
- Native core size: `131,470,712` bytes (`125.38 MB`)
- Native core SHA256: `AA4E99EBBE794C979348E2B1C0CAFDDE7B846703398B2D1146E84DDF5640130F`
- HAP build verified: version `0.20.0`, versionCode `1000096`, signed HAP `18,909,325` bytes, SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.100:36169`; `bm dump` showed `versionName=0.20.0`, `versionCode=1000096`, native library path `entry/libs/arm64`
- Launch/runtime status: blocked by device password lock, `aa start` returned `Error Code:10106102`; `power-shell wakeup`, `uitest uiInput swipe`, and `aa start -N` did not bypass lock. Runtime hilog remains pending until manual unlock.

## 2026-06-13 verified previous core

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-70`
- Native core size: `131,263,476` bytes (`125.18 MB`)
- Native core SHA256: `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- HAP build verified: version `0.13.40`, signed HAP `18,746,430` bytes
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.100:36169` install bundle successfully; launch blocked by lock screen (`Error Code:10106102`), so runtime `coreReady` and `video-frame` are still pending
