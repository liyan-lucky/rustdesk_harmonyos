# RustDesk HarmonyOS 变更日志

> 本文件记录阶段性变更，不作为当前状态总入口。新开对话或接手项目请先读 `docs/README.md`，当前核心、构建、安装和验证状态以 `docs/CORE.md`、`docs/PROGRESS.md`、`docs/CONNECTION_DEBUG_LOG.md` 为准。

## 0.33.6 release candidate (2026-06-21 23:48)

- Published and verified online on 2026-06-22: Core run `27920089950` / `core-34`; HAP run `27920708116` / `OpenRustdesk-Build-v0.33.6`. Final online signed HAP SHA256 is `3D2711AF46FFF6C999362431FFDC7855A485BBBC5BBC1ACE629FA885F8A4E35C`.
- Fixed online-build provenance after detecting that a stale hidden arm64 URL could override the latest Core while x86_64 used the new Release. Both workflows now default to latest and accept explicit dual-architecture URL/SHA256 inputs; the final HAP embeds `90A283…` arm64 and `E58746…` x86_64 metadata.

- Final signed dual-ABI HAP: `34,284,688` bytes, SHA256 `1D5C7395753D4E8F143FA051E0E931CCFB6C48FFEDA03A8DF91282DD007EC8D2`, BuildInfo `2026-06-21 23:46`; both Core architectures are local 2026-06-21 builds from the same source baseline and their size/SHA256 values are embedded in CoreBuildInfo.
- Finalized themed file-transfer and terminal pages, compact official-aligned ID-card menu, development toasts for unavailable functions, compact retry dialog (`中继`), corrected settings/title icons, share-service/capture linkage and live state refresh.
- Restored numeric ID grouping without forcing the caret to the end; floating suggestions now fill the complete ID and include IP-address cards.
- Removed duplicate share-status text and core readiness error text; OTP remains runtime-memory-only and is never written to source, logs, documents, screenshots, or commits.
- Huawei controlled-side input/accessibility is explicitly shelved as unsupported; all remaining release checks passed: 100 rounds × 155 checks (154 PASS + 1 expected SKIP per round), 0 failures, and connection-chain 84/84.
- Installed the exact online signed HAP on the x86_64 emulator: `0.33.6 / 1000182`, `updateTime=1782084584518`, PID `694`, NAPI 413 functions, `coreReady=true`, normal LAN/online polling, and no app-process fatal/panic/signal.

## Unreleased (2026-06-20 handoff)

- Added the five-codec UI/native decoder work in progress and themed default Select controls.
- Moved the current wireless device target to `192.168.11.102:36169`; verified and installed the staged signed HAP.
- Recorded that all session-menu behavior remains pending. In particular, remote-cursor UI exists but Core cursor callbacks are still empty, so the feature is not complete.

## v0.22.7 (2026-06-15)

### 修复

- **线上 core-81 正式接入**：13 核心 commit `c5b3eeb` 已由 GitHub Actions run `27563925971` 发布 `core-81`，`librustdesk_core.a` 正式包含 OHOS incoming frame source、`captureRequired` 快照字段和共享首帧触发链路。
- **共享录屏触发边界确认**：App 强制下载线上 core-81 后重建，`captureRequired=true` 仅用于启动 native `OH_AVScreenCapture_StartScreenCapture` 提供首帧；`incomingReady=true` 仍是唯一真实共享运行态，不再唤起截屏 API，也不再使用 `AVScreenCaptureRecorder`。
- **文件管理授权闭环确认**：文件访问继续保持 picker-first，文件管理/文件传输页不会被普通权限预检挡住 `DocumentViewPicker` 授权弹窗。

### 验证

- 线上 core-81 asset `131,631,706` bytes，SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`；release 已补中文说明。
- 11 App 使用 `RUSTDESK_CORE_FORCE_DOWNLOAD=1` + 指定 SHA256 强制拉取线上 core-81 构建通过，版本 `0.22.7` / versionCode `1000110`，BuildInfo 时间 `2026-06-15 19:09`。
- signed HAP `18,978,267` bytes，SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`；unsigned HAP `18,899,289` bytes，SHA256 `2BE7B2E594B03868D5E8C6939ACB8FE4AD5B2476959498A43DD1A5E03A12C03B`。
- `verify_native_harmonyos_hap.ps1` 验包和签名通过；`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`。
- 静态扫描无 `AVScreenCaptureRecorder`、`@ohos.screenshot`、`screenshot.capture`、显式 `CUSTOM_SCREEN_CAPTURE` runtime permission request 命中。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.7`、`versionCode=1000110`，进程 `40016` 存活。
- 干净 hilog `reports\hilog_latest_after_0227_core81_wireless_app_strict_clean_x.txt`：7252 行、app/core 相关 132 行，app fatal/panic/`exit(-1)`/signal/native core missing bad count = 0。
- 线上 push Linux workflow run `27567811582` 成功；发布 workflow run `27568044749` 成功创建 `OpenRustdesk-Build-v0.22.7`。线上 signed HAP `20,870,632` bytes，SHA256 `ce62df82dd5167f9d31b34c0e2b88c869ed947a05214ca156fc3eeab9ff76fe3`；unsigned HAP `20,790,546` bytes，SHA256 `024ca74d649c305e8598ab36bf57a27e7f54869cd5c584f4d35798a89e008e98`。

## v0.22.6 (2026-06-15)

### 修复

- **文件管理主动唤起文件访问授权**：`FileAuthorizationService` 改为先唤起 `DocumentViewPicker`，再记录 `READ_WRITE_DOWNLOAD_DIRECTORY` / `FILE_ACCESS_PERSIST` 普通权限结果，避免权限预检挡住目录授权弹窗；`FileTransfer.ets` 页面进入后延迟 bootstrap，给系统 picker 留出页面 attach 时机。
- **共享录屏启动状态拆分**：`OfficialRustDeskBridge` / `NativeRustDeskBridge` / `Index` 增加并消费 `captureRequired`、`incomingFramePayloadReady`、`incomingFrameId`、`incomingFrameBytes`、`incomingFramesSeen`。`captureRequired=true` 会启动 native `OH_AVScreenCapture_StartScreenCapture` 提供首帧，但共享 UI 仍只在 `incomingReady=true` 时显示真实运行。
- **核心 OHOS 入站帧源本地预发布**：本地 core-81 源码让 `scrap::common::ohos::Capturer` 从核心 incoming frame cache 读取最新帧，并通过 `captureRequired` 打通 App 启动采集的触发信号；`incomingReady` 继续保持严格语义，等待 desktop server/video source 真正 ready。
- **验包脚本稳定性**：`verify_native_harmonyos_hap.ps1` 的签名证书/profile 提取临时文件改用 GUID 名，避免连续验包时固定文件名被占用导致误失败。

### 验证

- 13 核心本地 release 构建通过，staticlib `128,894,588` bytes，SHA256 `2DC3B655664B756E255684D28FBA0CB3A9DEC14E6080EA4682FA26486ADF9B6D`。
- 11 App 使用 `RUSTDESK_CORE_SKIP_DOWNLOAD=1` 构建通过，版本 `0.22.6` / versionCode `1000109`，BuildInfo 时间 `2026-06-15 18:00`。
- signed HAP `18,433,473` bytes，SHA256 `4D669584F44B6462F570747723E66EB2894204FF7860CA0FBB27339D7FCE7DDD`；unsigned HAP `18,352,811` bytes，SHA256 `93377FB03E689004EAD1D7C8C916537D5A5092F04BDD810DA947EFA4842F1BEA`。
- `verify_native_harmonyos_hap.ps1` 验包和签名通过；`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`。
- 静态扫描无 `AVScreenCaptureRecorder`、`@ohos.screenshot`、`screenshot.capture`、显式 `CUSTOM_SCREEN_CAPTURE` 普通权限请求命中。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.6`、`versionCode=1000109`，进程 `7527` 存活。
- 干净 hilog `reports\hilog_latest_after_0226_localcore_wireless_app_strict_clean_x.txt`：799 行、app 相关 176 行，app fatal/panic/`exit(-1)`/signal bad count = 0。

## v0.22.5 (2026-06-15)

### 修复

- **修复线上 ArkTS 严格模式编译失败**：`PermissionService.requestFileAuthorization()` 将 `FileAuthorizationService` 返回项映射为显式 `PermissionRequestResult`，避免 GitHub Actions Linux/Hvigor 报 `arkts-no-untyped-obj-literals`。
- **修复聊天摘要中文乱码/误字**：连接页聊天 Tab 的最近消息摘要分隔符从异常的“路”修正为 ` - `，避免文件/系统/文本摘要出现错字。
- **清理旧自动别名兼容判断**：历史设备别名过滤去掉旧编码残留，改为按 `Remote ` 和当前语言下的 `Remote Device` 生成前缀判断。

### 验证

- `scripts\build_hap.bat` 强制拉取 latest core-80 后增量构建通过，版本 `0.22.5` / versionCode `1000108`，BuildInfo 时间 `2026-06-15 07:32`。
- signed HAP `18,968,203` bytes，SHA256 `05E86D1D2900D3D0F873113B28338EB468B36AF4063461476D7E87C4A49D726A`。
- `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 验包和签名通过；`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`。
- 当前代码静态扫描无 `AVScreenCaptureRecorder`、`@ohos.screenshot`、`screenshot.capture`、显式 `CUSTOM_SCREEN_CAPTURE` 普通权限请求命中。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.5`、`versionCode=1000108`，进程 `20911` 存活。
- 清空 hilog 后重新抓取 `reports\hilog_latest_after_0225_core80_wireless_app_strict_clean.txt`：`coreReady=4`、`query-onlines-result=8`、app fatal/panic/`exit(-1)` = 0，app 相关 `signal` = 0。
- 线上 push Linux workflow run `27528676811` 成功；发布 workflow run `27528681007` 成功创建 `OpenRustdesk-Build-v0.22.5`，release notes 已补中文说明。线上 signed HAP `20,856,465` bytes，SHA256 `515805c9a960a3a200400bf4b104d5683e500a27e08f9dd5a9992eaa1b0bac98`。

## v0.22.4 (2026-06-15)

### 核心

- **接入 core-80 入站屏幕帧缓存桥**：13 核心 commit `12ad723` 已由 GitHub Actions run `27526413545` 发布为 `core-80`；线上 asset `librustdesk_core.a` `131,624,954` bytes，SHA256 `4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`，release 已补中文说明。
- **共享 native buffer 进入核心缓存**：App C++ NAPI 的 `OH_AVScreenCapture_StartScreenCapture` / `OH_AVScreenCapture_AcquireVideoBuffer` 会把 native buffer payload 通过 `rustdesk_bridge_update_incoming_screen_frame` 推入核心，并暴露 `getIncomingScreenFrameMetadata/copyIncomingScreenFrame/clearIncomingScreenFrame`。
- **保持安全边界**：`incomingReady` 仍保持 false，直到 Harmony desktop server / RustDesk 被控端视频源真正接通，避免只因本机有采集帧就假显示共享可连接。

### 验证

- `scripts\build_hap.bat` 强制下载 latest core 后增量构建通过，版本 `0.22.4` / versionCode `1000107`，BuildInfo 时间 `2026-06-15 07:15`。
- signed HAP `18,968,380` bytes，SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`。
- `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 验包和签名通过；`audit_connection_chain.ps1` 已扩展到 `66 PASS, 0 FAIL, 0 SKIP`，覆盖 native screen capture、incoming frame bridge 和文件授权兜底。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.4`、`versionCode=1000107`，进程 `14881` 存活。
- 清空 hilog 后重新抓取 `reports\hilog_latest_after_0224_core80_wireless_app_strict_clean.txt`：`coreReady=4`、`query-onlines-result=8`、app fatal/panic/`exit(-1)` 为 0，app 相关 `signal` 为 0；日志中的 `signal` 仍为系统 Wi-Fi `HandleSignalPollChangedMsg unsupported` 噪声。

## v0.22.2 (2026-06-15)

### 修复

- **共享录屏改为原生 StartScreenCapture**：`ScreenCaptureService` 不再创建 `AVScreenCaptureRecorder`、不再写临时 mp4 探测文件，改为调用 C++ NAPI `startNativeScreenCapture/stopNativeScreenCapture`，底层使用 `OH_AVScreenCapture_StartScreenCapture` 和 native buffer 取帧统计。
- **屏幕采集 NAPI 补齐**：`rustdesk_bridge_loader.cpp` 新增原生采集启动/停止/active/stats 导出，CMake 链接 `native_avscreen_capture` 与 `native_buffer`，ArkTS d.ts 和 `NativeRustDeskBridge.ts` 同步包装。

### 验证

- `scripts\build_hap.bat` 增量构建通过，版本 `0.22.2` / versionCode `1000105`，BuildInfo 时间 `2026-06-15 06:17`。
- signed HAP `18,946,878` bytes，SHA256 `9F4C40E9B10BE4D88BA5B76A24C887B1A8586F1A2812619CDC48C843C97DE1DA`。
- `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 验包和签名通过，`audit_connection_chain.ps1` 通过 `50 PASS, 0 FAIL, 0 SKIP`。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.2`、`versionCode=1000105`，进程 `62121` 存活。
- `reports\hilog_latest_after_0222_wireless_app_strict.txt` 统计：`coreReady=1`、`query-onlines-result=2`，app fatal/panic/`exit(-1)` 均为 0；日志中的 `signal` 为 Wi-Fi 服务 `HandleSignalPollChangedMsg unsupported`，不是 `com.open.rundesk` 崩溃。

## v0.22.1 (2026-06-15)

### 修复

- **共享启动不再预申请截屏/屏幕捕获权限**：`Index` 去掉启动共享前对 `CUSTOM_SCREEN_CAPTURE` 的显式 `requestPermissionsFromUser` 调用，避免系统先弹“截屏/屏幕捕获”授权；该版本仍由后续 `AVScreenCaptureRecorder` 采集链路触发录屏授权，已在 `v0.22.2` 替换为 native `StartScreenCapture`。
- **文件管理唤起文件访问授权**：文件传输页进入、切到本地、刷新本地、上传/下载/本地新建/删除前都会走 `DocumentViewPicker` 目录授权；`PermissionService.requestFileAccessAuthorization()` 默认改为目录授权模式。
- **文案修正**：`Screen capture denied` 中文改为“录屏授权拒绝”，避免把共享录屏误描述成截屏。

### 验证

- `scripts\build_hap.bat` 增量构建通过，版本 `0.22.1` / versionCode `1000104`，BuildInfo 时间 `2026-06-15 06:01`。
- signed HAP `18,953,784` bytes，SHA256 `F16398FCB29E9E4F24131602D7B03C7BEED0A88BE0C37463BC7238AFF4C31A06`。
- `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 验包和签名通过，`audit_connection_chain.ps1` 通过 `50 PASS, 0 FAIL, 0 SKIP`。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.1`、`versionCode=1000104`，进程 `56711` 存活。
- `reports\hilog_latest_after_0221_wireless_app_strict.txt` 统计：`coreReady=71`、`initializeRuntimeFn returned=3`、`Bootstrap snapshot=1`、`query-onlines-result=134`，app fatal/panic/signal/`exit(-1)` 均为 0。

## v0.22.0 (2026-06-15)

### 修复

- **远控 direct session 命令接入**：切换主控端、截图、会话录制、语音聊天改用核心 direct function 的 bool 返回值；无活动 session 时提示 `Command unavailable`，不再误报成功。
- **会话录制与本机录屏分离**：远控“会话录制”不再请求 `CUSTOM_SCREEN_CAPTURE` 或启动 `ScreenCaptureService`，避免和共享/录屏探测状态冲突。
- **核心事件回写 UI 状态**：新增消费 `record-status`、`voice-call-started`、`voice-call-waiting`、`voice-call-closed`、`screenshot-response`，并补齐相关中文 toast。

### 核心

- 13 核心 commit `bc36b1d` 已由 GitHub Actions run `27516993020` 发布为 `core-79`；线上 asset `librustdesk_core.a` `131,493,470` bytes，SHA256 `8BBB12AA93EE8703ABBED5BA6D411031AD78CE7FA6A71D7C407A0A350A8789F2`，release 已补中文更新说明。

### 验证

- `scripts\build_full_hap.bat` 已拉取 core-79 并全量构建 `0.22.0` / versionCode `1000103`，BuildInfo 时间 `2026-06-15 01:55`。
- signed HAP `18,929,896` bytes，SHA256 `C8EB6B133B71752F50447410DE3E9DECC0BDE3EFD3630E8CBA9AB015E3A39F96`。
- `verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` 验包和签名通过，`audit_connection_chain.ps1` 通过 `50 PASS, 0 FAIL, 0 SKIP`。
- `scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 已无线安装并启动到 `192.168.11.102:36169`；设备端 `versionName=0.22.0`、`versionCode=1000103`，进程 `56136` 存活。
- `reports\hilog_latest_after_core79_wireless_app_only.txt` 统计：`coreReady=187`、`initializeRuntimeFn returned=3`、`Bootstrap snapshot=1`、`query-onlines-result=366`、app fatal/panic/signal/`exit(-1)` 均为 0。

## v0.21.0 (2026-06-15)

### 核心

- **core-78 已接入验证**：13 核心项目聊天四参 ABI 回同步和 d.ts 自建服务器 `key` 参数修复已由 GitHub Actions run `27515510727` 发布为 `core-78`，release asset `librustdesk_core.a` 为 `131,470,442` bytes，SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`。
- **全量 HAP 重新构建**：11 App 通过 `scripts\build_full_hap.bat` 下载 `core-78` 后全量构建为 `0.21.0` / versionCode `1000102`，BuildInfo 时间 `2026-06-15 01:02`。

### 验证

- signed HAP `18,928,728` bytes，SHA256 `491ED6E5CF1A8B6E2DD3F1E4661D99C15A4EB7D9B7B6FCB4A45BC92346BE2F90`。
- `scripts\verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 验包通过，`scripts\audit_connection_chain.ps1` 连接链路审计 `50 PASS, 0 FAIL, 0 SKIP`。
- 无线目标 `192.168.11.102:36169` 复装启动成功；设备端 `bm dump` 显示 `versionName=0.21.0`、versionCode `1000102`，`pidof com.open.rundesk` 返回 `41841`。`reports\hilog_latest_after_core78_wireless.txt` 记录 `coreReady` 14 次、`query-onlines-result` 20 次，app fatal/panic/signal/`exit(-1)` 均为 0。

## v0.20.5 (2026-06-15)

### 修复

- **共享启动顺序**：打开共享时不再先启动 `AVScreenCaptureRecorder` MP4 录屏探针，改为先调用核心 `setIncomingServiceEnabled`；只有核心返回 `incomingReady=true` 后才启动屏幕采集，避免核心明确不可用时仍唤起录屏并把 UI 误判为共享中。
- **共享未就绪状态**：共享开关打开但核心未 ready 时新增 `Share requested` / `Requested` 状态和中文翻译，直接展示核心错误或详情，不再显示成“未运行/请再次点击”。

### 验证

- 增量 HAP 构建通过，版本 `0.20.5` / versionCode `1000101`，signed HAP `18,928,713` bytes，SHA256 `E174E07ABB77CBF3E17489AABFEBDC7A5827A7DDE409206C59377C4BA9631FF0`。
- 同包 native/signature 验证通过，连接链路审计 `50 PASS, 0 FAIL, 0 SKIP`；无线安装启动到 `192.168.11.102:36169` 成功，设备端 `bm dump` 和 `pidof` 确认版本与进程存活。

## v0.20.4 (2026-06-15)

### 构建/部署

- **USB-only 安装模式**：`AUTO_BUILD_INSTALL.bat --skip-build usb` 只检测 USB/HDC 本地目标，不再尝试无线目标，便于临时改用 USB 安装测试。
- **无线复装验证**：USB-only 脚本/文档变更重新构建后，`AUTO_BUILD_INSTALL.bat --skip-build auto` 已把 `0.20.4` / versionCode `1000100` 安装并启动到 `192.168.11.102:36169`；设备端 `bm dump` 和 `pidof` 均确认运行中，同包 native/signature 验证和连接链路审计通过。
- **核心后续状态**：13 核心项目聊天发送 ABI 源文件同步问题和核心 d.ts 自建服务器 `key` 参数已在后续 `core-78` 中发布，并由 11 App `0.21.0` 全量下载构建、无线安装和 hilog 验证通过。

## v0.20.3 (2026-06-15)

### 调试

- **调试保持亮屏默认开启**：关于区 `Debug Keep Screen Awake` 临时改为默认开启，并增加一次性迁移，升级后自动开启一次，避免调试安装/启动验证时手机自动锁屏；用户仍可手动关闭。

## v0.20.2 (2026-06-15)

### 修复

- **质量监控面板**：连接质量浮层改为可滚动，并渲染核心上报的动态质量指标，连接链路审计恢复 `50 PASS, 0 FAIL`。
- **项目备份脚本**：`backup_project.ps1` 排除 `13_librustdesk_core` junction 并使用 robocopy `/XJ`，避免备份跟随核心项目导致深路径/权限清理失败。

## v0.20.1 (2026-06-14)

### 修复

- **共享页录屏探测状态**：录屏探测中不再显示为“服务运行中”，也不再展示设备 ID 和一次性密码；真正共享运行态只由核心 `incomingReady=true` 决定。
- **共享页停止按钮**：录屏探测已启动但核心被控服务未就绪时，仍保留“停止服务”按钮用于关闭探测。
- **核心下载脚本容错**：远程 latest core HEAD/下载失败但本地核心已存在时，继续使用本地已验证核心，避免网络瞬断阻断 HAP 构建。

### 文档

- 记录 `AVScreenCaptureRecorder` 只能作为授权/录制探测，真实共享链路仍需 Native `OH_AVScreenCapture` live buffer 到 RustDesk desktop server/video source 的桥接。

## v0.20.0 (2026-06-14)

### 新增

- **术语约定**：TAB=底部主菜单4项（连接/聊天/共享/设置），选项卡=ID输入框下方子选项（历史/收藏/发现/通讯录/登录/核心）
- **核心/App功能对接**：终端stub、终端dataBase64事件、音频空队列处理、本地音频上传、核心C++聊天四参、文件传输事件、switch-sides option路由、自定义服务器key透传、聊天语义（chat-error/chat-sent/chat-message）
- **文件授权API**：统一请求下载目录/持久访问并唤起DocumentViewPicker
- **调试常亮开关**：设置页关于区新增Debug Keep Screen Awake开关，WindowChromeService.setKeepScreenOn改为3次重试循环
- **聊天模式选择**：远控聊天按钮弹出语音/文字模式选择
- **搜索浮层**：登录/历史/收藏/发现/通讯录/核心搜索入口改为从图标向左悬浮展开

### 修复

- **TAB连接页返回时自动聚焦ID输入框**：底部tab按钮添加id，焦点请求到connect-bottom-tab-btn，onPageShow和aboutToAppear中均请求焦点到TAB按钮
- **搜索失焦**：onBlur只关闭输入框不清空搜索文本，搜索图标点击时如有搜索文本则清空重开
- **核心按钮逻辑**：主按钮Restart时stopCoreRuntime后重设coreLoadBusy=true防止按钮闪烁，副按钮在staticlib模式下只显示Stop且核心未运行时disabled
- **设置页与会话显示设置状态同步**：打开显示设置对话框时先递增settingsOptionVersion强制重新读取native option值
- **ID输入框X/→按钮点击无反应**：Stack中左侧Column加right:60 padding留出按钮空间，右侧Row加zIndex(20)，按钮加hitTestBehavior(Block)
- **ID输入框悬浮匹配框**：只在输入法激活时显示（deviceIdInputFocused），左右居中显示
- **ID输入框状态提示**：所有提示文本不超过8个字（连接中、输入ID、ID格式错误、连接失败、需要密码等），setStatusMessageRaw自动截断超过8字的文本
- **聊天对话框大小**：默认尺寸144x187，最小尺寸同步调整
- **旋转画面修复**：新增isLandscapeMode状态替代viewRotation=90，transformPreviewPointToImageSpace横屏时交换xy坐标
- **底部tab栏修复**：buildFillTabItem中width('100%')改为layoutWeight(1)，buildOfficialConnectPanel外层从Stack还原为Column
- **剪贴板/命令假成功收敛**：Send Clipboard Keys检查native返回值，一次性远控命令未被core处理时提示Command unavailable
- **摄像头查看入口收敛**：Recent菜单View Camera改为不可用提示，等待后续真实official view-camera session接入

### 构建/部署

- 核心构建：core-71至core-76多轮发布验证
- HAP构建：0.19.0→0.20.0，签名验证通过，无线安装验证通过
- 构建脚本：13_librustdesk_core junction排除，核心构建cwd必须使用真实路径

## v0.6.3 (2026-06-05)

### 修复

- 工作区路径便携化：文档统一使用 `%VSCODE_ROOT%` 表示包含 `11_Rustdesk_harmonyos/` 和 `99_Temp/` 的可移动根目录，不再绑定旧固定盘符。
- Hvigor 缓存和 HAP 输出改为相对 `../99_Temp/...`，适配 U 盘换盘符和借用不同电脑。
- HAP 签名路径改为 `../99_Temp/rustdesk_harmonyos_signing/...`，当前有效签名材料已移动到 `99_Temp` 便携目录。
- Windows HAP 构建入口补充 `local.properties` / 环境变量查找，支持 DevEco 安装在非默认路径。
- Windows HAP 构建入口在 Node 启动前设置 `CI=true`、`RUSTDESK_HARMONY_TEMP_ROOT` 和 `BUILD_CACHE_DIR`，让 Hvigor 日志、HAP 输出和 Native `.cxx` 中间目录落到 `99_Temp`，避免 U 盘项目内旧 `.hvigor/entry/build/entry/.cxx` 权限残留阻断构建。
- `clean_project.ps1` 增加长路径删除支持；`-IncludeExternalBuild` 默认只清理 `99_Temp/harmonyos_build/rustdesk_harmonyos`，`-IncludeHvigorCache` 作为显式深度缓存清理开关。
- `AccountService.fetchAddressBook()` 修复空通讯录响应不覆盖旧缓存的问题，避免切换账号或服务端后显示过期设备。
- `HttpClient` 请求体、响应体和 URL 查询参数日志增加脱敏，避免 password/token/uuid/code 等敏感值进入日志。
- 扫码页新增相册图片二维码识别入口，扫到服务器配置导入文本时直接保存到服务器配置；设置页服务器导入/导出成功增加 toast 提示。
- 构建脚本新增版本自增规则：增量构建自增右侧数字，全量构建自增中间数字并重置右侧数字，同时同步 `AppScope/app.json5` 与 `BuildInfo.ets`。
- 新增项目根 `README.md` 作为线上默认 `DESIGN` 介绍；Markdown 文档不再记录 USB 设备硬件编号。
- 聊天Tab改为显示当前/最近一次会话中的聊天内容；会话结束或从远控页返回后刷新最近会话历史，peer信息只替换聊天Tab头部并保留右侧图标。
- 远控会话聊天浮窗新增自动滚动到最新消息，每次发送和接收消息后都会滚动；移除固定测试聊天消息和本地模拟自动回复。
- `clean_project.ps1` 在外部构建目录内容已清空但空目录无法删除时降级为警告，避免全量构建被空目录阻断。

### 验证

- 签名 profile 校验通过，bundleName 为 `com.open.rundesk`，profile 有效期 `2026-06-03` 至 `2027-06-03`。
- `scripts\AUTO_BUILD_INSTALL.bat --full auto` 全量重建安装通过，版本从 `0.5.1` 递增到 `0.6.0`，启动阶段因设备锁屏跳过。
- 补回聊天标题右侧图标后，`scripts\AUTO_BUILD_INSTALL.bat auto` 增量构建安装启动通过，版本递增到 `0.6.2`，签名 HAP 输出到 `99_Temp/harmonyos_build/rustdesk_harmonyos/entry/build/default/outputs/default/entry-default-signed.hap`。
- 已完成 100 轮功能逻辑审查，明细记录在 `docs/FUNCTION_LOGIC_AUDIT_2026-06-05.md`。

## v0.6.2 (2026-06-04)

### 修复

- 平台图标着色统一：Windows、Android、Linux、macOS/iOS 等平台图标统一使用主题强调色 SVG 填充，保持与原 Windows 蓝色图标效果一致，同时不改动 SVG 造型。
- 设置页右上角恢复扫码入口，使用固定尺寸主题色图标按钮，避免被标题栏布局或图标颜色隐藏。
- 共享页服务卡片删除“服务状态”信息行，并将设备名称行调整为与设置页信息行一致的显示样式。
- 设置页服务器导入/导出图标改为 stroke 主题色滤镜，适配深浅主题。
- 服务器配置导出结构改为官方短字段 `host/relay/api/key`，导入同时兼容 `idServer/relayServer/apiServer/key` 历史剪贴板内容。

### 验证

- 增量 HAP 构建通过，BuildInfo 更新时间：`2026-06-04 23:04`。
- 自动安装并启动通过，目标：`192.168.11.102:36169`。

## v0.6.1 (2026-06-04)

### 文档

- 更新 `docs/GIT_PUBLISH.md`：本地工作目录与远端 `master` 统一为项目根结构，正常从 `%VSCODE_ROOT%\11_Rustdesk_harmonyos` 提交推送。
- 明确禁止在本地工作仓库直接普通 `git pull` 合并远端发布提交，避免把本地目录结构改成线上根结构。
- 在 `docs/README.md` 和 `docs/FILES.md` 增加 Git 发布说明入口和临时发布目录说明。

## v0.6.0 (2026-06-03)

### 新增

#### 1. 服务器配置导入/导出
- **功能**: 服务器对话框右上角添加导出（arrow-autofit-up）和导入（arrow-autofit-down）按钮
- **导出**: 将当前服务器配置（host/relay/api/key）编码为 JSON→Base64→字符串反转，复制到剪贴板
- **导入**: 从剪贴板读取字符串，反转→Base64解码→JSON解析，填充到对话框字段
- **兼容**: 与官方RustDesk导出格式完全兼容
- **文件**: `entry/src/main/ets/pages/Index.ets`

#### 2. 服务器配置Key字段
- **功能**: 服务器对话框新增Key输入字段，应用时通过 `NativeRustDeskBridge.setLocalOption('key', ...)` 同步到native
- **文件**: `entry/src/main/ets/services/AppDataService.ets`, `entry/src/main/ets/pages/Index.ets`

### 修复

#### 1. Toggle isOn 值绑定导致异步权限请求期间回弹
- **问题**: 点击 Screen Capture 等权限开关后，开关瞬间打开又立即弹回关闭状态
- **根因**: `buildToggleRow` 中 `Toggle({ isOn: value })` 是值绑定，onChange 中调 async 权限请求方法，await 期间重渲染把 Toggle 回弹到旧值
- **修复**: 所有5个权限开关的 onChange 回调中，先同步 `updateSettings` 更新状态，再执行异步权限请求；权限拒绝时回滚为 false
- **文件**: `entry/src/main/ets/pages/Index.ets`

#### 2. ForEach key 包含 accountRefreshTick 导致 Toggle 组件销毁
- **问题**: 登录状态刷新时整个 Tab 内容销毁重建，Toggle onChange 回调丢失
- **根因**: ForEach key 包含 `accountRefreshTick`，登录状态刷新时 key 变化
- **修复**: ForEach key 移除 `accountRefreshTick`，改为 `${this.i18nVersion}_${index}`
- **文件**: `entry/src/main/ets/pages/Index.ets`

#### 3. toggleIncomingService 中 startCapture 失败后未 throw
- **问题**: startCapture 抛异常后 catch 块吞掉异常，继续把 serviceEnabled 设为 true
- **修复**: catch 块末尾添加 throw，让调用方能回滚 serviceEnabled: false
- **文件**: `entry/src/main/ets/pages/Index.ets`

#### 4. 调试日志改用 hilog API
- **问题**: console.info 在 HarmonyOS 设备上不输出到 hilog
- **修复**: 改用 `hilog.info(0xA03D00, 'SHARE', ...)` 替代 console.info
- **文件**: `entry/src/main/ets/pages/Index.ets`

#### 5. LAN发现逻辑修复
- **问题**: LAN发现周期轮询被误删；忽略列表删除后不刷新；listener递增addressBookVersion导致非发现tab闪烁；stopDiscovery未关闭native LAN
- **修复**: 恢复30秒周期timer；removeDiscoveredPeer/refreshNow先重置ignoredPeerIdsLoaded再加载；listener只递增discoveredVersion；stopDiscovery写入enable-lan-discovery=N
- **文件**: `entry/src/main/ets/services/LanDiscoveryService.ets`, `entry/src/main/ets/pages/Index.ets`

#### 6. 服务器对话框改为官方样式
- **问题**: 服务器对话框使用CustomTextInput，与官方RustDesk样式不一致，缺少Key字段和导入/导出功能
- **修复**: 改为小标签+底部细线分隔的TextInput布局；添加导出/导入图标按钮；新增Key字段
- **文件**: `entry/src/main/ets/pages/Index.ets`, `entry/src/main/ets/services/AppDataService.ets`

### 修改文件清单

| 文件 | 修改类型 |
|------|---------|
| `entry/src/main/ets/pages/Index.ets` | Toggle回弹+ForEach key+hilog+throw+LAN listener+服务器对话框+导入导出 |
| `entry/src/main/ets/services/LanDiscoveryService.ets` | LAN发现周期轮询恢复+忽略列表刷新修复 |
| `entry/src/main/ets/services/AppDataService.ets` | Key字段+EffectiveServerConfig.key |
| `entry/src/main/ets/services/I18nService.ets` | 导入导出提示翻译 |
| `entry/src/main/resources/rawfile/content_copy.svg` | 新增复制图标 |
| `entry/src/main/resources/rawfile/content_paste.svg` | 新增粘贴图标 |
| `entry/src/main/ets/common/BuildInfo.ets` | 版本更新 |

## v0.5.0 (2026-06-02)

### 修复

#### 1. 设备发现显示"用户名@设备名"格式
- **问题**: LAN发现的设备只显示设备名(hostname)，缺少用户名(username)前缀
- **修复**: `LanDiscoveryService.handleDiscoveredPeer()` 中，当 `loadLanPeers` 返回的 username/hostname 为空时，额外调用 `NativeRustDeskBridge.getPeerInfo()` 补充信息
- **文件**: `entry/src/main/ets/services/LanDiscoveryService.ets`

#### 2. 会话建立后自动断开
- **问题**: `OfficialRustDeskBridge.closeRequestedByUser` 标志在上次会话关闭后残留为 true，导致 `refresh()` 持续将状态强制设为 idle，新连接无法建立
- **修复**:
  - 新增 `OfficialRustDeskBridge.resetCloseRequestedFlag()` 方法
  - `RemoteControl.aboutToAppear()` 中调用 `resetCloseRequestedFlag()` 清除残留标志
  - `applyBridgeState()` idle 分支增加 `sessionBecameActive/hasReceivedFrame` 检查，避免会话未真正建立就弹重试对话框
- **文件**: `OfficialRustDeskBridge.ets`, `RemoteControl.ets`

#### 3. 重试对话框/密码对话框暗色主题不匹配
- **问题**: 对话框背景色使用 `theme_WHITE`，暗色模式下显示为白色卡片
- **修复**: 背景色改为 `theme_CARD_BG`，增加 `border(theme_BORDER_SUBTLE)` 边框增强暗色模式视觉层次
- **文件**: `RemoteControl.ets` (buildReconnectDialog, buildPasswordDialog)

#### 4. 连接成功等待画面提示消失
- **问题**: 重试对话框弹出后，即使连接恢复，`syncBridgeState`/`applyBridgeState` 因 early return 不更新状态
- **修复**:
  - `syncBridgeState` 和 `applyBridgeState` 中增加对 `showReconnectDialog=true && sessionStage=connected` 的处理：关闭重试对话框，恢复连接状态，显示"已连接，等待首帧..."提示
  - 等待画面 `display.svg` 添加 `colorFilter(createStrokeIconColorFilter(theme_TEXT_TERTIARY))`，暗色模式下图标可见
  - 等待画面文字颜色 `theme_DISABLED_TEXT` → `theme_TEXT_SECONDARY`
  - 连接信息按钮的 `display.svg` 添加 `fillColor(theme_ICON_FILL)`
- **文件**: `RemoteControl.ets`

#### 5. 离线设备状态刷新慢(~15秒)
- **问题**: `refreshAllSessionOnlineStatus` 每2秒对每个session调用 `getPeerInfo`(文件I/O)，加上 `queryOnlines` 网络超时，离线设备整体延迟约15秒
- **修复**:
  - 在线状态轮询间隔: 3秒 → 5秒
  - 通用刷新循环间隔: 2秒 → 5秒
  - 新增 `peerInfoCache` (TTL=15秒)，离线设备缓存 peerInfo 避免频繁文件I/O，在线设备即时失效
  - LAN发现二次加载延迟: 3.5秒 → 2秒
- **文件**: `Index.ets`, `LanDiscoveryService.ets`

### 构建/部署

#### 6. 构建脚本SDK路径修正
- **问题**: 脚本引用不存在的 `deveco-sdk-fixed/HarmonyOS-6.0.2/openharmony` 目录
- **修复**: 统一改为实际存在的 `99_Temp/rustdesk_harmonyos_build/deveco-sdk`，验证条件改为检查 `clang.exe`
- **注意**: `local.properties` 的 `sdk.dir` 保持指向 DevEco Studio SDK（hvigor 构建需要完整 SDK 元数据），native bridge 编译通过环境变量 `OHOS_SDK_HOME` 指向 99_Temp
- **文件**: `AUTO_BUILD_INSTALL.bat`；旧的中文固定 SDK batch 已在 2026-06-04 脚本清理中删除。

### 修改文件清单

| 文件 | 修改类型 |
|------|---------|
| `entry/src/main/ets/services/LanDiscoveryService.ets` | 逻辑修复 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 新增方法 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 逻辑修复+UI主题 |
| `entry/src/main/ets/pages/Index.ets` | 性能优化 |
| `entry/src/main/ets/common/BuildInfo.ets` | 版本更新 |
| `scripts/AUTO_BUILD_INSTALL.bat` | 路径修正 |
| `local.properties` | 路径修正 |

> 2026-06-04 脚本清理后，旧的中文固定 SDK batch 已删除；当前构建入口以 `scripts/run_hvigor_with_sdk_patch.js` 和 `scripts/AUTO_BUILD_INSTALL.bat` 为准。
