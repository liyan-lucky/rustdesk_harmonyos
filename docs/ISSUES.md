# 问题整理

> 避免问题反复出现，修改前必查此文档

## 2026-06-17 OHOS 被控端编译经验汇总

### 核心 Rust 编译常见坑

**现象**：实现 OHOS 被控端服务链路时遇到多个编译错误。

**经验清单**：
1. `TargetAddr` 不是 `Copy`，传给 `FramedSocket::send()` 需要用 `addr.clone()`
2. `bytes::Bytes` 不实现 `Display`，用 `String::from_utf8_lossy()` 转换
3. `Server::id_count` 是私有字段，需要 `pub id_count` 或构造函数
4. `SupportedEncoding` protobuf 没有 `vp9` 字段（只有 `h264`/`h265`/`vp8`/`av1`/`i444`）
5. `with_context()` 需要 `use hbb_common::anyhow::Context` trait import
6. `hbb_common::tcp::Stream` 不存在，正确类型是 `hbb_common::stream::Stream`
7. `NatType::from_i32()` 需要 `use hbb_common::protobuf::Enum as _` trait import
8. `Config::get_relay_server()` 不存在，官方用 `Config::get_option("relay-server")` + fallback
9. `VpxEncoder` 的 `id`/`ctx`/`width`/`height`/`yuvfmt` 是私有字段，`calc_q_values`/`bitrate`/`get_yuvfmt`/`create_frame` 是私有方法
10. 避免启动 IPC（`ipc::start("")`），这是之前 appspawn 崩溃的主因
11. **核心函数名称必须和官方保持一致**，不要自造函数名
12. **OHOS 文件已重构到 `harmony_bridge/` 子目录**，旧路径 `src/server_ohos.rs` 等已不存在

**教训**：修改核心前必须重读核心文件了解用户更新；函数命名对照官方源码。

## 2026-06-15 文件访问授权被普通权限预检挡住

### `DocumentViewPicker` 必须先唤起，不能等权限位全部通过后才弹

**现象**：文件管理/文件传输页进入后仍可能没有唤醒文件访问授权，用户看不到系统目录选择器；后续本地列表、上传/下载或新建/删除操作会继续依赖未确认的本地目录访问状态。

**根因**：`FileAuthorizationService.requestFileAuthorization()` 先请求/检查普通权限结果，一旦 `READ_WRITE_DOWNLOAD_DIRECTORY` 或 `FILE_ACCESS_PERSIST` 在系统侧未立即返回 granted，就可能提前返回 false，导致真正能授权目录 URI 的 `DocumentViewPicker` 没有机会弹出。

**解决**：文件授权服务改为 picker-first：先调用 `DocumentViewPicker` 获取文件/目录 URI，再记录普通权限位状态。`FileTransfer.ets` 页面进入时延迟 200ms 再 bootstrap，避免页面尚未可见时系统 picker 被吞掉。

**验证**：线上 core-81 + App `0.22.7` 构建通过；signed HAP `18,978,267` bytes / SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`；验包、66 项连接链路审计、无线安装启动和干净 app hilog 均通过，设备端 `versionName=0.22.7`、进程 `40016` 存活。

**教训**：文件访问授权不是普通权限位的同义词。目录/文件 URI 授权必须由 `DocumentViewPicker` 主动唤起，普通权限结果只能作为补充记录，不能作为阻止 picker 的前置条件。

## 2026-06-15 共享录屏应由 `captureRequired` 触发，不能伪装 ready

### `captureRequired=true` 是“请 App 提供首帧”，不是共享服务运行中

**现象**：core-80 之后 App 已能把 native buffer payload 推入核心缓存，但 `incomingReady=false` 时 App 不会启动 native screen capture；如果只等 `incomingReady=true` 才开始采集，就会形成“核心等首帧、App 等核心 ready”的死锁。反过来，如果因为本机有采集帧就把 `incomingReady=true`，又会把尚未接通 desktop server/video source 的共享伪装成可用。

**根因**：共享链路需要一个介于“核心请求服务”和“服务真正 ready”之间的状态。`incomingReady` 只能表示远端可连接的真实被控服务；它不能同时承担“请启动本机录屏提供帧”的触发信号。

**解决**：线上 core-81 新增 `captureRequired` 快照字段，`main_start_service(true)` 返回 `captureRequired=true`、`incomingReady=false`，并等待 App native `OH_AVScreenCapture_StartScreenCapture` 推送首帧。App 看到 `captureRequired=true` 会启动 native `ScreenCaptureService`，但 UI 的服务运行态、共享 TAB 绿点、设备 ID 和一次性密码仍只由 `incomingReady=true` 驱动。

**验证**：线上核心 `core-81` 构建 `131,631,706` bytes / SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`；App `0.22.7` 强制拉取线上核心构建、验包、66 项审计、无线安装启动和干净 app hilog 均通过。静态扫描无 `@ohos.screenshot`、`screenshot.capture`、`AVScreenCaptureRecorder` 或显式 `CUSTOM_SCREEN_CAPTURE` runtime permission request。

**教训**：共享状态至少分三层：`captureRequired` 触发本机采集，`incomingFramePayloadReady` 证明核心有帧缓存，`incomingReady` 才能表示远端可访问的被控服务。三者不能互相替代。

## 2026-06-15 HAP 签名验证临时文件不能复用固定文件名

### 反复验包时证书/profile 提取文件要使用唯一名

**现象**：`verify_native_harmonyos_hap.ps1` 一度通过 native 检查后在签名验证清理/复用阶段失败，原因是 `%VSCODE_ROOT%\99_Temp\...` 下固定名 `cert-chain.cer` 或 `profile.p7b` 仍被上一次进程占用或权限拒绝。

**根因**：验包脚本使用固定临时输出名，连续验证或异常中断后，旧文件可能仍处于不可删除状态；这会把工具清理问题误报为 HAP 签名失败。

**解决**：证书链和 profile 提取临时文件改为带 GUID 的唯一文件名，例如 `cert-chain-<guid>.cer`、`profile-<guid>.p7b`。

**验证**：修复后重新运行 `scripts\verify_native_harmonyos_hap.ps1` 通过 native library、runtime dependency、bundle 和 signature verification，输出 `verify-app success`。

**教训**：验证脚本的临时文件失败不能混淆为包体失败；连续验包的中间产物应使用唯一名，尤其是外部工具可能短暂持有文件句柄时。

## 2026-06-15 GitHub Actions ArkTS strict 未显式对象字面量

### 本地构建能过不代表线上 strict ArkTS 能过，map 返回对象必须显式类型

**现象**：App commit `c803bee` 推送后，GitHub Actions Linux run `27528204491` 和发布 run `27528218065` 都在 `:entry:default@CompileArkTS` 失败；完整 job log 中的根因是 `PermissionService.ets:173:14 Object literal must correspond to some explicitly declared class or interface (arkts-no-untyped-obj-literals)`。

**根因**：`PermissionService.requestFileAuthorization()` 在 `Array.map()` 中直接 `return { permission, status }`，本地构建未拦截，但线上 Linux/Hvigor strict ArkTS 把该对象字面量视为未显式类型。类似问题常见于 `map/filter/reduce` 回调里直接返回对象。

**解决**：在回调里先声明 `const mappedItem: PermissionRequestResult = { ... }`，再 `return mappedItem`。同轮复查还修正了 `Index.describeLastChatMessage()` 中聊天摘要分隔符的中文错字/编码残留，并移除历史 generated alias 判断里的 mojibake 字符串。

**验证**：强制下载线上 core-80 后 `scripts\build_hap.bat` 构建 `0.22.5` / versionCode `1000108` 通过；signed HAP `18,968,203` bytes / SHA256 `05E86D1D2900D3D0F873113B28338EB468B36AF4063461476D7E87C4A49D726A`；验包、`audit_connection_chain.ps1` `66 PASS, 0 FAIL, 0 SKIP`、无线安装启动和干净 app hilog 均通过，设备端进程 `20911` 存活，app fatal/panic/`exit(-1)`/app signal 为 0。

**教训**：线上 workflow 失败时不要只看末尾 worker exit；必须拉完整 job log 并搜索 `ArkTS Compiler Error`。ArkTS 对象字面量尤其是 `map()` 回调返回值要显式落到 interface 类型，避免 CI strict 与本地构建行为差异。

## 2026-06-15 共享 native buffer 未进入核心缓存

### 有 native 采集帧不等于 incoming ready，必须先进入独立入站帧缓存

**现象**：App 侧已经从 `OH_AVScreenCapture_StartScreenCapture` 拿到 native buffer 统计，但 13 核心缺少接收 App native buffer payload 的 C ABI/NAPI 入口；只看 App 侧帧统计无法证明共享链路已经进入核心。

**根因**：出站远控视频帧和入站被控共享帧方向不同，不能复用 `latest_video_frame`。如果直接因为 App native buffer 有帧就把 `incomingReady=true`，远端客户端会认为设备可被控，但 Harmony desktop server/video source 尚未消费这些帧，会造成假共享。

**解决**：13 核心 `core-80` 新增独立 `incoming_screen_frame` latest-frame 缓存，暴露 `updateIncomingScreenFrame/getIncomingScreenFrameMetadata/copyIncomingScreenFrame/clearIncomingScreenFrame`；11 App C++ drain loop map `OH_NativeBuffer` 后调用 `rustdesk_bridge_update_incoming_screen_frame()`，并在 stats 中记录 `coreFrameCount/payloadBytes/corePushOk`。

**验证**：13 核心 commit `12ad723` 已由 run `27526413545` 发布 `core-80`，线上 asset `131,624,954` bytes / SHA256 `4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`，release body 已补中文说明。11 App 强制下载线上 core-80 构建 `0.22.4` / versionCode `1000107`，signed HAP `18,968,380` bytes / SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`；验包、66 项连接链路审计、无线安装启动和干净 app hilog 均通过，设备端进程 `14881` 存活。

**教训**：共享链路至少分为“录屏 API 可启动”“App native buffer 有帧”“核心已接收入站 payload”“desktop server/video source 已消费帧并可对外服务”。只有最后一层完成后才能把 `incomingReady` 置 true。

## 2026-06-15 共享录屏误用 AVScreenCaptureRecorder/临时 mp4 探测

### 当前共享录屏底层必须走 native StartScreenCapture，不再使用 recorder 文件探测

**现象**：共享录屏虽然已经去掉 `CUSTOM_SCREEN_CAPTURE` 预申请，但 `ScreenCaptureService` 仍创建 `AVScreenCaptureRecorder` 并写临时 mp4 文件做录制探测；用户看到系统录屏状态时容易继续误判为“截屏 API/录制 API 混用”，也会把本地文件录制探测误当成 RustDesk live frame。

**根因**：`AVScreenCaptureRecorder` 的语义是屏幕录制到文件，更适合历史阶段探测授权；它不会天然把 frame payload 接入 RustDesk desktop server/video source。共享链路需要的是 live buffer，因此应使用 OHOS native `OH_AVScreenCapture_StartScreenCapture` + `OH_AVScreenCapture_AcquireVideoBuffer`，再把 native buffer 转成后续 RustDesk 视频源输入。

**解决**：`ScreenCaptureService` 删除 `AVScreenCaptureRecorder`、临时 mp4 文件和 `@ohos.multimedia.media` 依赖，改为调用 C++ NAPI `startNativeScreenCapture/stopNativeScreenCapture/isNativeScreenCaptureActive/getNativeScreenCaptureStats`；C++ bridge 链接 `native_avscreen_capture`、`native_buffer`，使用 `OH_AVScreenCapture_StartScreenCapture` 启动采集，并在后台线程轮询 native buffer 做帧统计。

**验证**：`scripts\build_hap.bat` 通过，`0.22.2` / versionCode `1000105` 已验证 native StartScreenCapture 替换；后续 `0.22.4` / versionCode `1000107` 强制拉取 `core-80` 后再次验证通过，signed HAP `18,968,380` bytes / SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`，66 项连接链路审计和干净 app hilog 均通过，设备端进程 `14881` 存活。

**教训**：文件录制成功、native buffer 有统计、核心入站帧缓存有 payload、核心 `incomingReady=true` 是不同层级。当前 0.22.4 已把 App native 采集 payload 推进核心缓存，但真实共享还必须继续实现 OHOS 采集帧到 RustDesk desktop server/video source 的桥接，完成前不能把共享 UI 标记为真实运行。

## 2026-06-15 共享启动预申请截屏/屏幕捕获权限

### 录屏授权必须由真实录屏 API 触发，不能先调普通权限申请

**现象**：点击共享启动时，系统先出现类似截屏/屏幕捕获的授权提示，然后才可能进入录屏状态；这会让共享录屏看起来像同时唤起了截屏 API。

**根因**：`Index.checkScreenCapturePermissionAndToggle()` 在调用核心 incoming 前显式请求 `ohos.permission.CUSTOM_SCREEN_CAPTURE`。该权限在系统侧属于屏幕捕获/截屏类授权，不等同于 RustDesk 被控链路的 live frame，也不应该在核心尚未 ready 时提前弹出。

**解决**：去掉共享启动前的 `CUSTOM_SCREEN_CAPTURE` 显式 `requestPermissionsFromUser`；`PermissionService.getRequiredPermissions()` 和 `requestShareRuntimePermissions()` 也不再把它作为普通功能权限申请。保留 manifest 声明，真正录屏授权只由 native `OH_AVScreenCapture_StartScreenCapture` 在 `incomingReady=true` 后触发。

**验证**：`0.22.1` 已验证去掉预申请；`0.22.2` 进一步去掉 `AVScreenCaptureRecorder`/临时 mp4 探测，验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端进程 `62121` 存活。

**教训**：共享链路里“权限位已申请”“录屏授权弹窗”“核心 incoming ready”“真实 live frame”是四个不同状态，不能用前一个状态替代后一个状态。

## 2026-06-15 文件管理页未主动唤起文件访问授权

### 文件传输页自身必须兜底调用 DocumentViewPicker 目录授权

**现象**：从文件管理/文件传输页进入后，本地文件列表和上传/下载目标可能直接读 `/storage/Users/currentUser/Download`，但没有唤起系统文件访问授权。

**根因**：远控菜单和共享页开关已有文件授权入口，但 `FileTransfer.ets` 页面自身没有兜底；直接进入页面、切到本地或刷新本地时只调用 `FileTransferService.listDirectory()`。同时 `requestFileAccessAuthorization()` 默认未固定为目录授权模式。

**解决**：`FileTransfer.ets` 在页面进入、切到本地、刷新本地、打开本地目录、上传/下载、本地新建/删除前统一调用 `PermissionService.requestFileAuthorization({ folder: true, authMode: true })`；`PermissionService.requestFileAccessAuthorization()` 默认也改成目录授权模式。聊天发文件、核心导入这类“选择单个文件”入口仍直接调用 `requestFileAuthorization({ maxSelectNumber: 1 })`。

**验证**：同 0.22.1 增量构建和无线安装验证；新增中文/英文 `File access authorized` 文案，文件授权失败继续提示 `File access permission denied`。

**教训**：文件管理页面不能假设调用方已经授权；页面级本地文件操作必须自己兜底唤起 `DocumentViewPicker`，普通权限位通过不代表用户完成了文件访问授权。

## 2026-06-15 远控会话录制误用本机录屏 API

### 远控会话命令必须走核心 direct function 并返回真实状态

**现象**：远控页“会话录制”开启时会请求 `CUSTOM_SCREEN_CAPTURE` 并启动 `ScreenCaptureService`，导致系统进入本机录屏状态；“切换主控端/截图/语音聊天”等菜单虽然有核心函数，但 UI 部分仍走通用 option 或本地音频状态，无法判断无活动 session 时命令是否真正发出。

**根因**：早期 UI 把“远端会话录制”和“入站共享/录屏探测”混在一起；核心 direct session 函数也多为 void，ArkTS 只能按函数存在推断成功。只检查 wrapper 名称不够，必须检查 Rust bridge、C ABI、C++ NAPI、d.ts、ArkTS wrapper、UI caller 以及事件回流。

**解决**：13 核心 commit `bc36b1d` 已将相关 session 函数改为 bool 返回，并补 `voice-call-*`、`record-status`、`screenshot-response` 事件；该核心已由 run `27516993020` 发布为 `core-79`。11 App 远控菜单改用 `sessionSwitchSides/sessionTakeScreenshot/sessionRecordScreen/sessionRequestVoiceCall/sessionCloseVoiceCall`，会话录制不再请求本机录屏权限或启动 `ScreenCaptureService`。`0.22.0` / versionCode `1000103` 已全量构建、验包、连接链路审计、无线安装启动和 app-only hilog 验证通过。

**教训**：入站共享链路和远控会话命令必须分离。本机屏幕采集只属于共享/被控链路，远控菜单中的录制、截图、切换方向和语音呼叫都必须以核心 active session 返回值和回调事件为准。

## 2026-06-15 共享开关提前唤起录屏探针

### 已修复 App 状态与启动顺序，核心 live frame 仍待实现

**现象**：共享开关打开后即使核心返回 `incomingReady=false`，App 仍会先启动 `AVScreenCaptureRecorder` 写 MP4 探针文件，系统出现录屏状态，容易与真实 RustDesk 被控共享混淆。

**根因**：`Index.toggleIncomingService(true)` 原先先调用 `ScreenCaptureService.startCapture()`，再调用核心 `setIncomingServiceEnabled()`；但当前 13 核心 `main_start_service(true)` 明确返回 `incoming-service-unavailable`，`send_video_frame_metadata()` 仍为 false，OHOS `scrap::Capturer` 也尚未实现 live frame。

**解决**：共享启动顺序改为先写 `enable-screen-capture` option 并调用核心，被控服务只有在 `officialCoreState.incomingReady=true` 后才启动屏幕采集。核心未 ready 时 UI 显示 `Share requested/Requested` 和核心错误详情，不再显示“服务运行中”或设备 ID/密码。

**后续**：真实共享还需要补 13 核心 `server_ohos.rs`、`scrap::common::ohos::Capturer` 与 OHOS native `OH_AVScreenCapture` live buffer 到 RustDesk video source 的链路。

## 2026-06-15 核心 C++ 源项目聊天 ABI 漏同步

### App 副本修好不等于核心源项目修好

**现象**：11 App 项目 `entry/src/main/cpp` 已经把 `rustdesk_bridge_session_send_chat` 修为四参调用（`peer_id/message_type/content/timestamp`），但 13 核心项目真实源码 `cpp/rustdesk_bridge_abi.h` 和 `cpp/rustdesk_bridge_loader.cpp` 仍是旧的一参 `content` 调用。

**根因**：前一轮紧急修复落在 App 同步副本，核心源项目没有完全回同步；后续如果从 13 项目重新同步 `cpp/`，会把 App 的已修聊天发送路径覆盖回旧 ABI 调用。

**解决**：在真实 `F:\Visual_Studio_Code\13_librustdesk_core` 中把 C++ ABI 声明和 `SendChatMessage`/`SessionSendChat` 调用同步为四参，并保留一参 fallback；同时补齐核心 d.ts 中 `connectToPeer/setIncomingServiceEnabled` 的自建服务器 `key` 参数。本地核心构建通过，commits `034e446`、`cc5f4de` 已推送，线上 run `27515510727` 已成功发布 `core-78`；11 App 已下载该核心并全量构建 `0.21.0`，无线安装和 hilog 验证通过。

**教训**：核心 ABI 修复必须同时检查 13 核心项目和 11 App 同步副本；`bridge_api.rs`、`rustdesk_bridge_abi.h`、`rustdesk_bridge_loader.cpp` 三层签名必须完全一致，否则 C 调用约定下会出现参数错位且不一定编译报错。

## 2026-06-14 聊天发送失败根因修复

### C++ 调用 rustdesk_bridge_session_send_chat 参数数量不匹配

**现象**：聊天发送消息时，核心返回 `chat-error: failed=empty-content`，App 提示"聊天发送失败"。

**根因**：C++ 层 `SessionSendChat` 和 `SendChatMessage` 调用 `rustdesk_bridge_session_send_chat(content.c_str())` 只传1个参数，但 Rust bridge_api.rs 的 ABI 签名是4个参数：`rustdesk_bridge_session_send_chat(_peer_id, _message_type, content, _timestamp)`。C++ 只传1个参数时，content 字符串被映射到 `_peer_id` 位置，而真正的 `content` 参数位置是未初始化的垃圾值，核心读到空内容。同时本地头文件 `rustdesk_bridge_abi.h` 声明也是1个参数 `int rustdesk_bridge_session_send_chat(const char * content)`，与实际 ABI 不匹配。

**修复**：
1. `rustdesk_bridge_abi.h` 声明改为4参数：`int rustdesk_bridge_session_send_chat(const char * peer_id, const char * message_type, const char * content, long long timestamp);`
2. `rustdesk_bridge_loader.cpp` 中 `SessionSendChat` 和 `SendChatMessage` 改为读取所有4个参数并传给 ABI 函数
3. TS 层 `NativeRustDeskBridge.ts` 的 `sessionSendChat` 和 `sendChatMessage` 添加 hilog 诊断日志

**教训**：C++ ABI 声明必须与 Rust `#[no_mangle] pub extern "C"` 导出签名完全一致；参数数量不匹配在 C 调用约定下是未定义行为，不会编译报错但运行时参数错位。核心项目修改 ABI 签名后，App 项目的头文件和 C++ 调用必须同步更新。

## 2026-06-14 staging/core 构建路径问题

## 2026-06-14 文件传输对接问题

### 文件传输页面不能使用本地模拟文件

**现象**：文件传输页本地列表来自 `FileTransferService.seedLocalFiles()` 的固定示例数据，例如 `demo.hap`、`rustdesk-log.txt`。UI 可以排队上传，但路径在设备上不一定存在，最终会把假路径交给 native/core。

**根因**：早期为了完成 UI 闭环使用虚拟文件模型；后续核心已接入 official `send_files()`，但 app 本地列表没有随之切到真实文件系统。

**解决**：`FileTransferService.ets` 改为通过 `@ohos.file.fs.listFileSync/statSync` 读取真实 `/storage/Users/currentUser/Download`；本地新建目录走 `mkdirSync`，本地删除走 `unlinkSync/rmdirSync`，上传前用 `statSync` 检查源路径存在。

**教训**：文件传输不能只看远端 official Session API 是否接通；app 侧展示的本地路径也必须是真实可读文件，否则 UI 成功和核心失败会脱节。`DocumentViewPicker` 可以作为授权入口，但若没有把选中 URI 转成 native 可读路径，就不能用示例数据冒充本地文件列表。

### 摄像头查看入口不能假连接

**现象**：`ViewCamera.ets` 的 `startCameraStream()` 没有调用 official view-camera session，却直接把 `isConnected=true`、状态设成 `Camera connected`；Recent 菜单也会进入该页面。

**根因**：页面复用了通用视频帧渲染路径，但没有建立摄像头查看会话；`session_is_view_camera` 也不能代表 app 已能打开远端摄像头。

**解决**：Recent 菜单 `View Camera` 改为灰色不可用提示，不再导航；`ViewCamera.ets` 自身也只显示 `Camera entry unavailable`，不再假设连接成功。

**教训**：有页面和 wrapper 不等于功能完成。未接通 official session 的功能必须禁用或明确提示不可用，不能用本地状态把 UI 伪装成 connected。

### 剪贴板和一次性远控命令不能假成功

**现象**：远控菜单 `Send Clipboard Keys` 读取本机剪贴板后直接调用 `NativeRustDeskBridge.sendClipboardData()`，但没有检查返回值；无 active session 或 native/core 返回 `false` 时仍提示 `Clipboard sent to remote`。`sendSessionAction()` / `sendOptionCommand()` 在 core 不支持命令时写入本地 option，并提示 `Command queued locally`，但实际没有队列会继续发送。

**根因**：早期 UI 把“已点击命令”和“native/core 已接收命令”混在一起；本地 option 只适合持久化会话选项，不适合作为截图、录制、关机、切换方向这类一次性命令的假队列。

**解决**：剪贴板发送检查 native 返回值，失败时提示 `Failed to send clipboard`；一次性命令未被 native/core 处理时提示 `Command unavailable`，不再写入本地 option 伪装排队。

**教训**：菜单命令必须根据 native/core 返回值决定提示文案；能保存本地偏好的开关和必须立刻被 session 处理的一次性命令要分开。

### App staging 不能跟随 `13_librustdesk_core` junction

**现象**：下载 `core-71` 后执行 `scripts\build_hap.bat`，staging 清理阶段报错，路径落在 `99_Temp\harmonyos_stage\11_Rustdesk_harmonyos\13_librustdesk_core\.git\refs\codex\...`。

**根因**：App 根目录里的 `13_librustdesk_core` 是 NTFS junction。旧 `stage_project_for_build.ps1` 没有显式排除该 junction，也没有给 robocopy 加 `/XJ`，导致 staging 复制了整个核心项目和 `.git` 深路径；后续清理旧 staging 时又遇到深路径/只读 Git object。

**修复**：`stage_project_for_build.ps1` 显式排除 `13_librustdesk_core`，robocopy 增加 `/XJ`；旧 staging 删除增加只读属性清理和 `\\?\` 长路径兜底。

**教训**：staged build 只能复制 app 工程自身；项目根下用于开发便利的 junction/symlink 必须排除，且 robocopy 必须使用 `/XJ`。

### 核心构建不能从 app 内 junction 路径启动

**现象**：从 `11_Rustdesk_harmonyos\13_librustdesk_core` 执行 `scripts\build_native_bridge.ps1 -Profile release` 时，脚本寻找 `F:\Visual_Studio_Code\11_Rustdesk_harmonyos\99_Temp\rustdesk_harmonyos_build\vcpkg\installed` 并失败。

**根因**：核心脚本按当前项目路径向上推导 workspace/build root；从 app 内 junction 启动会把 app 项目当作根的一部分，导致 `99_Temp` 推导到错误位置。

**修复**：从真实路径 `%VSCODE_ROOT%\13_librustdesk_core` 运行核心构建；本轮真实路径 release 构建成功，并已连续发布 `core-71`、`core-73`、`core-74`。

**教训**：app 内 `13_librustdesk_core` junction 只用于浏览源码，不作为核心构建 cwd；构建/提交/推送核心时都切到真实 `%VSCODE_ROOT%\13_librustdesk_core`。

## 2026-06-14 core/app 对接复查：终端 stub、音频空队列和聊天参数

### 终端页面存在不等于核心已接通

**现象**：App 有 `Terminal.ets`、`TerminalService.ets` 和 NAPI 声明，但核心 `session_open_terminal()`、`session_send_terminal_input()`、`session_resize_terminal()`、`session_close_terminal()` 仍返回 `false`，终端页只能显示入口不可用。

**根因**：旧审计只确认了 ArkTS/NAPI 函数名存在，没有继续检查 13 项目 `rustdesk-master/src/harmony_bridge/core.rs` 是否调用 official `Session`。

**修复**：13 项目外层和旧副本 `harmony_bridge/core.rs` 均改为调用 `Session::open_terminal/send_terminal_input/resize_terminal/close_terminal`；`HarmonyHandler.handle_terminal_response()` 将 official `TerminalResponse` 转成 `terminal-response`、`terminal-output`、`terminal-closed` 事件。

**教训**：核心功能对接必须按 ArkTS → NAPI → C ABI → Rust bridge → official Session → 事件回流全链路检查。

### 终端输出不能直接写入事件 JSON

**现象**：终端输出可能含 ANSI/control bytes，如果直接放入 session event 的 `detail` 字符串，JSON 可能不可解析或页面输出乱码。

**根因**：`queue_event()` 只适合普通文本详情；终端字节流不是普通 JSON 字符串。

**修复**：核心将终端 data response 解压后 base64 到 `dataBase64`；App `TerminalService` 用 `util.Base64Helper` 和 `TextDecoder` 解码。`Terminal.ets` 不再消费 `terminal-response:data` 追加输出，只处理 opened/error/closed，避免和 `terminal-output` 重复。

**教训**：二进制或控制字符数据必须编码穿过事件总线；页面层不要同时订阅两个数据入口。

### 音频空队列和本地音频上传不能伪装成功

**现象**：核心 `pull_audio_frames_json()` 返回 `{}`，App 远端音频轮询按数组解析会反复异常；本地“Send Local Audio”会启动麦克风并提示成功，但核心 `send_audio_frame_metadata()` 没有采样数据 payload，实际没有向远端发送音频。

**根因**：音频接收空队列返回值不符合 App 约定；音频上传 ABI 只有 metadata 参数，缺少音频数据参数或 official voice-call 采集链路。

**修复**：核心空音频队列返回 `[]`；App 本地音频上传入口改为提示 `Audio upload unavailable`，不再启动采集假成功。

**教训**：只有 metadata 的接口不能当作媒体上传能力；UI 有入口时必须要么真实 native 调用成功，要么明确不可用。

### 聊天 NAPI 四参调用要读 content 参数

**现象**：App 侧聊天调用形如 `sendChatMessage(peerId, messageType, content, timestamp)`，如果 C++ bridge 只读 `args[0]`，会把 peerId 当作消息内容。

**根因**：13 项目 C++ bridge 仍是旧的一参实现，11 项目已修但核心项目未同步。

**修复**：13 项目 `cpp/rustdesk_bridge_loader.cpp` 中 `SendChatMessage` 和 `SessionSendChat` 改为四参兼容：优先读 `args[2]`，旧一参调用 fallback 读 `args[0]`。

**教训**：C++ bridge 的修复必须同时落到 13 核心项目，否则后续从核心同步会覆盖 11 项目的已修行为。

## 2026-06-13 core-70 / 设备验证 / 线上状态

### 设备锁屏会让安装成功后的启动和视频流验证被阻断

**现象**：`scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169` 安装 HAP 成功，但 `aa start` 返回 `Error Code:10106102`，随后 `pidof com.open.rundesk` 无进程，hilog 中没有 `coreReady`、`session-connected` 或 `video-frame`。2026-06-14 core-73 和 core-74 复测时，`power-shell wakeup`、`uitest uiInput swipe` 和 `aa start -N` 都不能绕过锁屏，WindowManager 仍显示 `SCBScreenLock` 处于顶层。

**根因**：设备处于锁屏状态，系统阻止应用启动；这不是 HAP 构建、签名、安装或 native core 链接失败。

**解决**：先手动解锁设备，再重新执行安装/启动或单独执行 `hdc -t 192.168.11.100:36169 shell aa start -a EntryAbility -b com.open.rundesk`，随后重新抓取 hilog 验证 `coreReady=true`、`session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`。不要把锁屏导致的无进程误判为 HAP、签名或 native core 链接失败。

**教训**：安装成功和启动成功必须分开记录；遇到 `10106102` 时不要继续分析视频流缺失，先处理设备解锁。

**2026-06-14 复核**：手机手动解锁后，`scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169` 可同时完成安装和 `aa start`；本轮复核进程 `12565` 存活，`reports/hilog_latest_after_core74_post_docs_unlocked.txt` 记录 `coreReady= true` 7 次、`query-onlines-result` 14 次，app fatal/panic/signal 为 0。

### App 线上最新 run 可能不是本地最新验证状态

**现象**：本地已用 core-70 构建、校验并安装 HAP 成功，但 GitHub App 仓库最新 workflow run `27443845710` 仍失败。

**根因**：该 run 来自旧提交 `0000da60074323447862ac75774b6ebe26a95ea3`，尚未包含本地已验证的 core-70 下载、HAP-only 和 staged signing 修正；最新 release `harmonyos-20260612-065038` 也不是本轮 core-70 构建产物。

**解决**：推送当前 App 仓库改动后，重新触发 `Build HarmonyOS HAP Linux`；验证 release/artifact 只包含 `.hap`，并确认构建前下载 latest core。

**教训**：分析“线上状态”时必须同时看 run 的 head SHA、时间、workflow 输入和本地是否已推送；不能只用“最新 run 失败”否定本地构建结果。

## 2026-06-12 Linux 在线构建问题（已解决）

### Core release tag 会变化，App 构建不能写死 `core-63`

**现象**：用户提供的核心下载地址为 `https://github.com/liyan-lucky/librustdesk_core/releases/download/core-63/librustdesk_core.a`，但线上自动构建核心后会发布到新的 tag，后续 tag 不一定仍是 `core-63`。

**根因**：App 构建脚本如果写死 `releases/download/<tag>/librustdesk_core.a`，核心仓库发布新 tag 后仍会拉旧核心，或者旧 tag 被删除/替换时构建失败。

**解决**：默认使用 `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`；本地 `build_hap.bat`、`build_full_hap.bat`、`AUTO_BUILD_INSTALL.bat` 和线上 `github_build_harmonyos*.ps1/sh` 都在构建前强制刷新 `entry/src/main/libs/arm64/librustdesk_core.a`。需要固定某次核心时才设置 `RUSTDESK_CORE_URL` 和 `RUSTDESK_CORE_SHA256`。

**教训**：✅ 自动发布核心时，App 侧默认应跟随 latest release asset，而不是固定 tag；✅ 默认不要配置 SHA，否则 latest core 更新后会被旧 SHA 卡住；✅ 固定 tag/SHA 只用于回归或临时锁版本。

### 线上构建只需要 HAP，不再生成 APP 或附加文件

**现象**：旧 workflow 会构建 HAP + APP，并上传 `.app.zip`、`manifest.json`、`SHA256SUMS.txt`；新要求是线上构建后只保留 HAP 文件。

**根因**：`ARTIFACT_TYPE=both`、`assembleApp`、APP zip 和 manifest/SHA 生成逻辑属于旧发布路径，继续保留会让 release 资产变多，也增加出错点。

**解决**：`.github/workflows/build-harmonyos.yml` 和 `.github/workflows/build-harmonyos-linux.yml` 固定 `ARTIFACT_TYPE=hap`，上传路径只匹配 `*.hap`；`scripts/github_build_harmonyos.ps1` 与 `scripts/github_build_harmonyos_linux.sh` 只接受 HAP 并运行 `assembleHap`，不再生成 `manifest.json` 或 APP 相关文件。

**教训**：✅ workflow HAP-only 不够，底层脚本也要拒绝 `app/both` 参数；✅ 发布资产路径必须写成 `*.hap`，不能再上传整个 artifacts 目录。

### Staged build 中签名文件路径不能指向项目外

**现象**：构建到 `SignHap` 时失败：`Invalid storeFile value... file must be included in ... debug_hos.p12`。问题出现在 staged project 的 `build-profile.json5` 仍指向 `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing`。

**根因**：Hvigor 签名任务要求 signing file 位于当前项目允许范围内；staged build 把项目复制到 `99_Temp/harmonyos_stage/...` 后，原来的 `../99_Temp/...` 或绝对签名路径不再满足签名校验。

**解决**：`scripts/stage_project_for_build.ps1` 在 staging 时把 `99_Temp/rustdesk_harmonyos_signing` 复制到 staged 项目的 `signing/` 目录，并把 staged `build-profile.json5` 中签名路径重写为 `./signing/`。

**教训**：✅ 修改签名路径只改 staged copy，不改项目根 portable 配置；✅ 后续 SignHap 路径错误先检查 staged `build-profile.json5` 与 `signing/` 是否同步。

### HDC `list targets` 输出 `[Empty]` 不能当作设备目标

**现象**：无设备时 `hdc list targets` 输出 `[Empty]`，旧脚本会把它当成 target，导致后续 `hdc -t [Empty] install` 报 `[Fail]Not match target founded`。

**根因**：脚本只判断非空行，未过滤 `[Empty]`；环境变量 `RUSTDESK_HARMONY_USB_TARGET` 也可能被设置成 `[Empty]`，仅过滤 fallback 列表不够。

**解决**：`AUTO_BUILD_INSTALL.bat` 对入参、USB 环境目标、无线目标和 fallback 列表都过滤包含 `[Empty]` 的值。无线复试使用 `scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169`，安装成功并 `start ability successfully`。

**教训**：✅ HDC 多目标脚本必须显式拒绝 `[Empty]`；✅ 自动目标失败后先用显式无线 target 复测，避免把设备连接问题误判为构建失败。

### SDK 拆包缺少 previewer 动态库导致 Hvigor 失败

**现象**：Linux GitHub Actions 中，前面补齐 `ets-loader` 的 `libsec_shared.so` 后，后续又报 previewer 依赖库缺失，典型缺失文件为 `openharmony/previewer/common/bin/libcjson.so`。

**根因**：从 Command Line Tools 分离出的 `harmonyos-sdk-full.zip` 初版没有完整带上 `openharmony/previewer/`，Hvigor/previewer 在 Linux runner 上需要这些 so 参与运行时加载。

**解决**：重新打包并上传 `harmonyos-sdk-full.zip`，确保包含 `openharmony/previewer/common/bin/libcjson.so`、previewer `libsec_shared.so`、ets-loader `libsec_shared.so`；workflow 中添加显式 `test -f` 检查，并把 previewer、ets-loader、toolchains 等目录加入 `LD_LIBRARY_PATH`。

**教训**：✅ 只验证 `restool/native/modulecheck` 不够，Linux CI 还必须检查 previewer common/bin；✅ SDK release URL 可以不变，但重新上传后要记录新 SHA/大小；✅ workflow 中对关键 so 做 `test -f` 比等 Hvigor 崩溃更容易定位。

### ArkTS `AvoidAreaType.TYPE_INPUT` 当前 SDK 不存在

**现象**：线上 ArkTS 编译失败，提示 `Property 'TYPE_INPUT' does not exist on type 'typeof AvoidAreaType'`。

**根因**：当前 HarmonyOS/OpenHarmony SDK 中输入法避让区域枚举名为 `window.AvoidAreaType.TYPE_KEYBOARD`，旧写法 `TYPE_INPUT` 不存在。

**解决**：将 `WindowChromeService.ets` 中的 `window.AvoidAreaType.TYPE_INPUT` 改为 `window.AvoidAreaType.TYPE_KEYBOARD`。

**教训**：✅ 遇到 ArkTS 枚举/属性不存在，不要只按旧样例写法修；先以当前 SDK 类型声明为准；✅ 输入法避让区域当前统一用 `TYPE_KEYBOARD`。

### GitHub Release 直接上传 `.app` 资产失败（历史规则，当前已改为 HAP-only）

**现象**：HAP/APP 已生成，但 release 上传 `.app` 资产失败或不稳定。

**根因**：HarmonyOS `.app` 是目录/包格式，在 GitHub Release asset 上传链路中不适合作为裸 `.app` 直接上传。

**解决**：旧规则下发布前将每个 `.app` 压缩为同名 `.app.zip`。当前新规则已取消 APP 产物，线上 release 只上传 `.hap`。

**教训**：✅ 如果未来重新启用 APP，release 资产不能直接上传裸 `.app`；✅ 当前 HAP-only 规则下不要再生成 `.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。

## 顽固问题 (未解决)

### 并行密码+无密码连接流程：密码框不弹出 (2026-06-07, 已修复待验证)

**用户要求**：无保存密码时，立即弹密码框 + 同时发无密码申请；无密码申请成功则关闭密码框；用户输入密码则切换密码连接。

**根因**：
1. `handleConnect()` 中 `await initiateBackgroundConnection()` 返回后立即跳转 RemoteControl，跳过了 `monitorConnectionWhileWaiting()` 轮询阶段，导致密码框状态管理丢失
2. `openRemoteControlForPendingSession()` 内部设 `this.showPasswordDialog = false` 后传参，但 RemoteControl 的 `applyBridgeState` connected 分支可能在 `passwordPromptProactive` 被重置时关闭密码框
3. `bridgeListener` msgbox 检查条件 `!this.isConnected` 过严——native 可能已报 connected 但还没收到帧
4. `syncBridgeState` 只在 `sessionStage === 'connecting'` 时弹密码框，不覆盖 error 状态中的密码提示
5. `applyBridgeState` error/idle 分支中密码提示优先级不够高，可能被重连/关闭逻辑短路

**修复**：
- `Index.ets handleConnect()`: 恢复备份的并行流程——`showPasswordDialog = true` + `pendingPasswordDialogProactive = true` + `void initiateBackgroundConnection()` (不 await) + `void monitorConnectionWhileWaiting()`
- `RemoteControl.ets bridgeListener`: msgbox 密码检查条件从 `!this.isConnected` 放宽为 `!this.hasReceivedFrame`
- `RemoteControl.ets syncBridgeState`: 扩展密码框触发条件，也检查 error 状态中的密码提示
- `RemoteControl.ets applyBridgeState connected`: 添加 hilog 追踪 `keepPasswordFallback`
- `RemoteControl.ets applyBridgeState error`: 在重连/关闭判断前先检查密码提示，如果是密码提示且没收到帧则弹密码框
- `RemoteControl.ets applyBridgeState idle`: 密码提示检查提前到重连判断之前
- `RemoteControl.ets handleTerminalBridgeEvent`: 重写逻辑——密码框开着且是密码提示时保持；密码提示且没收到帧时弹密码框；其他走重连

**验证**：HAP 构建通过 (2026-06-07 12:42)，待实机验证密码框弹出和并行连接行为。

**教训**：✅ 并行密码+无密码连接不能 await connectToPeer 后立即跳转，必须走 monitor 轮询；✅ 密码框触发条件不能依赖 isConnected，应依赖 hasReceivedFrame；✅ 密码提示优先级必须在所有重连/关闭逻辑之前；✅ 从最近会话/历史记录进入 RemoteControl 不经过 Index.handleConnect，密码框逻辑必须在 RemoteControl 侧也完整；✅ showPasswordDialog 被覆盖回 false 的常见位置：applyBridgeState connected 分支、monitorConnectionWhileWaiting 轮询、syncBridgeState 周期刷新；✅ showReconnectDialogFromState 内部已调 prepareReconnectPromptSurface，不要重复调用。

### ECONNRESET 后无重连提示 (2026-06-07, 已修复待验证)

**现象**：连接建立后立即被对端重置（`Connection reset by peer (os error 104)`），页面卡在 `connected=false hasFrame=false`，无重连对话框。

**根因**：`handleTerminalBridgeEvent` 中原逻辑在密码框开着且 retryable 时直接 return true 不弹重连框。ECONNRESET 被 `isRetryableDisconnectText` 识别为 retryable，但原条件 `this.showPasswordDialog && !retryable` 不匹配。实际问题是 `handleTerminalBridgeEvent` 之前有 `prepareReconnectPromptSurface()` + `showReconnectDialogFromState()` 重复调用，且密码框开着时可能被短路。

**修复**：重写 `handleTerminalBridgeEvent`——密码框开着且是密码提示时保持密码框；密码框开着且没收到帧时也保持；其他情况（包括 ECONNRESET）直接弹重连框。`showReconnectDialogFromState` 内部已包含 `prepareReconnectPromptSurface()`，不再重复调用。

**验证**：HAP 构建通过 (2026-06-07 12:42)，待实机验证 ECONNRESET 后重连框弹出。

### 远端密码提示 msgbox 到达但未触发密码框 (2026-06-07)

**hilog 证据**：`Event: msgbox, detail: 当前连接没有携带预设密码。若远端配置为密码访问，请填写 RustDesk 密码；也可以先保存密码以便下次自动填充。`

msgbox 事件到达了 ArkTS，但密码框未弹出。说明 `bridgeListener` 中新增的 msgbox 检查逻辑未生效，或 `showPasswordDialog` 被后续 `applyBridgeState` 调用覆盖为 false。

## 连接问题 (排查中)

### 连接流程应采用并行密码+无密码策略 (2026-06-07用户要求, 待实现)

**用户描述的完整流程**：
1. 从任意位置发起连接
2. **立即判断**远端是否存在密码需求（不等待远端响应）
3. **同时执行两条路径**：
   - **路径A**：弹出密码输入框，等待用户输入
   - **路径B**：发起无密码连接申请（等待被访问端确认/拒绝）
4. **竞争结果处理**：
   - 如果路径B先成功（被访问端同意无密码申请）→ 直接建立连接，**同时关闭密码输入框**
   - 如果路径A先完成（用户输入密码并确认）→ **切换到密码连接链路**，用密码重新建立连接

**当前实现的差距**：
- 当前 `handleConnect()` 是串行流程：先查本地保存密码 → 有密码则直接密码连接 → 无密码则发起空密码连接 → 等远端返回密码提示后才弹密码框
- 密码框只在远端返回密码提示（`shouldPromptForPassword`）后才弹出，不是连接发起时立即弹出
- 无密码申请和密码输入是互斥的，不是并行的
- `submitSessionPassword()` 只是在已有连接上提交密码，不是"切换到密码连接链路"

**需要修改的关键点**：
- `Index.ets` `handleConnect()`: 无保存密码时，立即弹出密码框 + 同时发起空密码连接
- `RemoteControl.ets` `applyBridgeState()`: 连接成功（无密码申请被同意）时关闭密码框
- `RemoteControl.ets` `submitSessionPassword()`: 密码确认后，如果无密码申请还在进行中，需要断开当前连接并用密码重新连接
- 密码框需要新增"跳过/等待确认"按钮，让用户选择等待无密码申请结果而非必须输入密码

### 无密码连接时密码输入框丢失 + 会话过早关闭 (2026-06-07发现, 已修复, 待验证)

**现象**: (1) 发起连接到设置了密码的远端时，如果本地没有保存密码，密码输入框不弹出，直接显示连接错误或关闭页面；(2) 被访问端刚弹出确认/拒绝提示时，访问端会话就已结束。
**根因**: `RemoteControl.ets` 的 `applyBridgeState` 中，error/idle 分支在 `shouldAutoCloseTerminalSession()` 为 true 时，会跳过密码提示直接关闭或重连。`handleTerminalBridgeEvent` 只在 `session-error` 时检查密码需求，`session-closed` 不检查。
**解决**: `applyBridgeState` error/idle 分支在 `shouldAutoCloseTerminalSession()` 判断之前，先检查 `shouldPromptForPassword(coreState)`，为 true 则优先显示密码对话框。`handleTerminalBridgeEvent` 将密码检查从仅 `session-error` 扩展到 `session-error` 和 `session-closed` 都检查。
**待验证**: 设备上实际发起无密码连接确认密码框弹出；确认被访问端拒绝/超时时不再直接关闭页面。
**教训**: ✅ 密码提示优先级必须高于自动关闭/重连逻辑；✅ `session-closed` 事件也需要检查密码需求，不能只在 `session-error` 检查。

### LAN 发现失效：rendezvous_mediator_ohos.rs 未启动 LAN 监听线程 (2026-06-07发现, 已修复, 待验证)

**现象**: LAN 发现功能完全失效——发现页手动刷新后列表为空，同网段设备不可见。hilog 确认 `discoverLanPeers` 返回 true、`loadLanPeers` 返回 `[]`、`lan-discovery-done` 事件到达——UDP ping 发出但没有监听线程接收响应。
**根因**: `rendezvous_mediator_ohos.rs` 的 `start_all()` 只执行 `std::future::pending().await`，从未启动 LAN 监听线程。OHOS 使用独立的 `rendezvous_mediator_ohos.rs`（不是 `rendezvous_mediator.rs`），其中完全没有调用 `crate::lan::start_listening()`。而 `rendezvous_mediator.rs`（非 OHOS）在 `start_all()` 中会调用 `crate::lan::start_listening()`。此外 `platform_ohos.rs` 的 `is_installed()` 返回 false，也会阻止 LAN 监听启动，但即使修复 `is_installed()`，`rendezvous_mediator_ohos.rs` 仍不会调用 `start_listening()`。
**解决**: 在 `rendezvous_mediator_ohos.rs` 的 `start_all()` 中添加 `std::thread::spawn` 启动 `crate::lan::start_listening()` LAN 监听线程。同时还原了误改的 `rendezvous_mediator.rs`（OHOS 编译不使用该文件）。
**待验证**: 确认 LAN 监听线程日志 `lan discovery listener started` 出现，同网段设备可被发现。
**教训**: ✅ OHOS 有独立的 `rendezvous_mediator_ohos.rs`，修改 LAN 逻辑时必须检查 OHOS 专用文件而非通用文件；✅ `is_installed()` 返回 false 会阻止 LAN 监听，但根因是 `start_all()` 根本没调用 `start_listening()`；✅ UDP ping 发出但无监听线程接收响应是 LAN 发现失效的典型症状。

### 远程连接 ECONNRESET (os error 104) (2026-06-07发现, 2026-06-09已修复)

**现象**: 发起远程连接到 peer 后，收到 `session-error: 连接错误：Connection reset by peer (os error 104)`。连接能建立（收到 quality-status delay=108ms），但随后被远端重置。
**根因**: 上游 Cargo.toml 默认启用 scrap wayland feature 和 arboard wayland-data-control feature，导致 librustdesk_core.a 引入 libwayland-server.so/libwayland-client.so 依赖，OHOS 设备上不存在这些库，dlopen 失败导致 SO 加载失败，NAPI 模块不可用。
**修复**: (1) 上游 Cargo.toml: `scrap = { path = "libs/scrap" }` 移除 wayland feature; (2) `arboard = { git = "..." }` 移除 wayland-data-control feature; (3) CMakeLists.txt 添加 `-Wl,--as-needed`; (4) 重新编译核心+构建 HAP。
**验证**: 2026-06-09 实机验证 coreReady=true，连接建立成功，ECONNRESET 后重连框弹出，重连成功恢复帧传输。
**教训**: ✅ OHOS 交叉编译必须禁用所有 wayland 相关 feature; ✅ SO 的 NEEDED 依赖在设备上不存在会导致 dlopen 失败; ✅ `--as-needed` 只移除 NEEDED 记录不移除符号引用，根本解决必须从 Rust 侧排除依赖。

### 密码输入框不唤醒输入法 (2026-06-09发现, 已修复)

**现象**: 密码对话框弹出后，TextInput 不自动获取焦点，输入法不弹出，用户需要手动点击才能输入。
**根因**: (1) TextInput 缺少 `.defaultFocus(true)` 属性; (2) `buildPasswordDialog()` 定义了但未在 `build()` 中渲染; (3) `buildImeProxyInput()` 无条件渲染抢占输入法焦点。
**修复**: (1) 两个 TextInput 添加 `.defaultFocus(true)`; (2) build() 中添加 `if (this.showPasswordDialog) { this.buildPasswordDialog() }`; (3) 密码框显示时隐藏 imeProxyInput。
**验证**: 全屏模式下输入法可正常弹出。

### 全屏会话输入法弹出时画面不挤压/平移 (2026-06-09发现, 未解决)

**现象**: 全屏会话中输入法弹出时，画面不向上挤压或平移，键盘遮挡内容。
**已尝试**: (1) module.json5 添加 `softInputMode: adjustResize` — 当前 SDK schema 不接受该 ability 字段，已移除; (2) WindowChromeService 监听 `avoidAreaChange TYPE_KEYBOARD` — 全屏模式下未形成可用避让效果; (3) `window.on('keyboardHeightChange')` — 不触发; (4) TextInput onFocus/onBlur 手动设置 translate — translate 未生效。
**待解决**: 需要找到 OHOS 全屏模式下获取键盘高度的正确 API，或改用非全屏模式。

### 上游源码升级 1.4.6→1.4.7 编译适配 (2026-06-07发现, 2026-06-12已解决)

**问题**: RustDesk 1.4.7 引入更多 Linux 桌面端依赖（gtk 0.18、winit 0.30 等），OHOS 交叉编译时 `target_os = "linux"` 导致这些桌面依赖全部激活，触发 pkg-config/gtk 编译失败。
**解决进展**:
- ✅ Cargo.toml：注释/排除 tray-icon、tao、keepawake；用 `not(target_env = "ohos")` 条件排除 wallpaper/gtk/libxdo/pulse/dbus/evdev/pam 等
- ✅ scrap/Cargo.toml：排除 OHOS 的 dbus/gstreamer/zbus/nokhwa
- ✅ build.rs：基于 CARGO_CFG_TARGET_OS 运行时检查，避免 OHOS 交叉编译时触发 Windows C++ 编译
- ✅ lib.rs：恢复所有 OHOS target_env 条件修改
- ✅ 13 项目曾构建并发布 `v1.4.7-ohos` core，11 项目 Linux CI 旧规则下曾成功构建并发布 HAP/APP；当前规则已改为 latest core + HAP-only
**教训**: ✅ OHOS 的 `target_os = "linux"`，所有 Linux 桌面端依赖必须显式排除；✅ `#[cfg(windows)]` 在 build.rs 中基于 host 平台，交叉编译时需改为 CARGO_CFG_TARGET_OS 运行时检查；✅ git 依赖（tray-icon 等）可能删除旧 tag/commit，直接注释比版本锁定更可靠。

## 核心加载问题 (已解决)

### Rust C ABI 缺失导出导致 NAPI 模块无法加载 (2026-06-06发现, 已修复)

**现象**: 核心页 Native Module 状态异常，连接链路无法发起会话；hilog 报 `rustdesk_bridge_reconnect_session: symbol not found`。
**根因**: Rust `bridge_api.rs` 缺少 `rustdesk_bridge_send_ctrl_alt_del` 和 `rustdesk_bridge_reconnect_session` 两个 C ABI 导出函数。C++ `rustdesk_bridge_abi.h` 声明50个函数，Rust 之前只导出46个。HarmonyOS 运行时动态链接器严格检查所有符号，缺失符号导致整个 `librustdesk_bridge.so` 加载失败。
**解决**: 在 `bridge_api.rs` 新增两个 `#[no_mangle] pub extern "C"` 函数；`module.json5` 设置 `compressNativeLibs: true` + `extractNativeLibs: true` + `libIsolation: true` 确保 SO 正确解压。
**验证**: 重编 native core + 构建 HAP + 安装启动成功，hilog 确认 `module registered (52 functions)`、`coreReady=true`、`adapter=official-native`，无崩溃。
**教训**: ✅ C++ ABI header 声明的每个函数必须在 Rust `bridge_api.rs` 有对应 `#[no_mangle] pub extern "C"` 导出；✅ `--unresolved-symbols=ignore-all` 只影响链接阶段，不影响运行时动态链接器符号检查；✅ 缺失一个符号会导致整个 SO 加载失败，NAPI 模块完全不可用。

### SO加载方案4次迭代 (2026-05-29最终解决)

**问题**: 将Rust核心SO加载到HarmonyOS应用中

**方案1: cdylib + dlopen → 失败**
- 现象: dlopen返回error，hilog报mprotect errno=22(EINVAL)
- 根因: cdylib SO有DT_TEXTREL/DF_TEXTREL flag → HarmonyOS musl linker拒绝mprotect(RWX)
- TEXTREL详情: Rust/lld bug——实际0个text段重定位(全部25005个R_AARCH64_RELATIVE目标在data段)，但lld错误设置DT_TEXTREL flag

**方案2: 清除TEXTREL + dlopen → 失败**
- 现象: dlopen后SIGSEGV crash
- 根因: 无TEXTREL flag时，linker跳过text段重定位处理，但某些内部机制依赖TEXTREL触发的mprotect流程，导致重定位未完成

**方案3: cdylib + CMake直接链接 → 失败**
- 问题A: NEEDED记录包含构建机器绝对路径 → 用IMPORTED_SONAME修复
- 问题B: 修复后仍失败 → 核心SO的TEXTREL flag导致系统拒绝加载整个bridge SO

**方案4: staticlib + CMake直接链接 → 成功 ✅**
- Cargo.toml: `crate-type = ["staticlib"]`
- CMakeLists.txt: 链接librustdesk_core.a到bridge SO
- rustdesk_bridge_loader.cpp: IsCoreLoaded()=true，直接调用extern "C"
- 额外: qsort_r stub(ohos musl缺失) + libtime_service_ndk.so fallback
- 验证: coreReady:true, "Official Harmony bridge ready"

**总体教训**:
- ❌ TEXTREL是Rust/lld bug，非代码问题，无法从Rust侧修复
- ❌ 不要尝试cdylib方案(会触发TEXTREL)
- ❌ 不要尝试手动清除TEXTREL(会SIGSEGV)
- ❌ 不要尝试从filesDir/cache dlopen(SELinux限制)
- ✅ staticlib + CMake直接链接是HarmonyOS唯一可靠方案
- ✅ 方案迭代成本高，每次需完整编译+构建+安装+验证

### TEXTREL导致dlopen失败
**现象**: cdylib SO有DT_TEXTREL flag，HarmonyOS musl linker拒绝mprotect(RWX)，errno=22(EINVAL)
**根因**: Rust/lld bug——实际0个text段重定位(全部25005个R_AARCH64_RELATIVE目标在data段)，但lld错误设置DT_TEXTREL flag
**解决**: 改用staticlib + CMake直接链接，绕过TEXTREL
**教训**: ❌不要尝试cdylib方案；❌不要尝试手动清除TEXTREL(会SIGSEGV)；✅staticlib是唯一可靠方案

### HarmonyOS dlopen限制
**现象**: dlopen只能从`/data/storage/el1/bundle/libs/arm64/`加载，应用无权写入
**根因**: HarmonyOS SELinux策略限制
**解决**: staticlib方案不需要dlopen
**教训**: ❌不要尝试从filesDir/cache加载SO；❌不要尝试写入bundle libs

### libopus依赖缺失
**现象**: 旧版.so包含libopus.so.0依赖，NAPI加载失败(requireNapi undefined)
**根因**: 重新编译Rust核心时默认链接了opus动态库
**解决**: staticlib方案中opus静态链接到.a中
**教训**: ❌不要引入动态链接的opus；✅opus必须静态链接或禁用audio feature

## 编译问题 (已解决)

### LAN 手动刷新破坏发现状态 (2026-06-02发现,已修复)
**现象**: 添加发现页手动刷新后，LAN 发现列表可能继续显示旧结果，或 native 已返回 LAN 设备但发现页没有重新渲染。
**根因**: 手动刷新只调用一次 `discoverOnce()` 时没有重置 ArkTS/UI 状态；后续尝试调用 native `removeDiscoveredPeer()` 又会把 RustDesk 原生 `_lan_peers` 中的真实发现结果删除，导致 LAN 列表消失。
**解决**: `LanDiscoveryService.refreshNow()` 改为只清空 ArkTS `discoveredPeers` 和 UI `discoveredDevices`，重新打开 `enable-lan-discovery` 并触发 `discoverLanPeers()` + `loadLanPeers()`；同时增加 listener，发现结果变化后通知 `Index.ets` 更新版本号触发重绘。LAN 发现保持 30 秒周期轮询 timer，手动刷新时重置 UI 状态并立即触发一次发现。
**教训**: ✅ 手动刷新必须重置 UI 状态但不能删除 native LAN peer 缓存；发现服务写入数据后要显式通知页面重绘；LAN 发现不能长期干扰在线状态刷新。

### LAN 发现时序与消失设备未清理 (2026-06-03发现,已修复)
**现象**: (1) 手动刷新后UI清空，但 `discoverOnce()` 立即调用 `loadLanPeers()` 拿到旧缓存数据导致"清空→闪回旧数据→2秒后刷新"闪烁；(2) LAN设备下线后不会从ArkTS `discoveredPeers` 列表中移除，因为 `loadDiscoveredPeers()` 只做增量添加不做差异清理；(3) 手动刷新时 `resetCurrentDiscoveryResults()` 先清空所有数据导致卡片短暂消失1.5秒；(4) 忽略列表持久化后手动刷新不清除，导致被删除的设备永远无法重新出现。
**根因**: (1) `discoverLanPeers()` 触发异步网络发现，立即 `loadLanPeers()` 只能拿到上一次结果，在 `refreshNow()` 场景下旧数据立即回填造成闪烁；(2) `loadDiscoveredPeers()` 不对比native返回结果与ArkTS缓存，native侧已消失的设备不会被移除；(3) `refreshNow()` 先调 `resetCurrentDiscoveryResults()` 清空UI再等延迟加载，中间有空白期；(4) `refreshNow()` 只重载忽略列表不清除，被删除设备的忽略标记持续生效。
**解决**: (1) `discoverOnce()` 改为延迟1.5秒和3.5秒两次调用 `loadDiscoveredPeers()`，不再立即调用，避免旧缓存闪回；(2) `loadDiscoveredPeers()` 增加 `nativePeerIds` 集合收集本次native返回的所有设备ID，遍历完成后对比 `discoveredPeers` Map，移除native不再返回的设备并同步 `AppDataService.removeDiscoveredDevice()`；(3) `refreshNow()` 不再调 `resetCurrentDiscoveryResults()`，直接触发发现等新数据做差异替换，避免卡片短暂消失；(4) `refreshNow()` 清除忽略列表并持久化空列表，手动刷新意味着用户想重新看到所有设备。
**验证**: 2026-06-03 22:15 无线设备 `192.168.11.100:36169` 安装启动成功，hilog显示LAN发现正常工作，发现2个设备，无崩溃关键字，手动刷新无卡片消失。
**教训**: ✅ 异步发现结果必须延迟读取，不能在触发发现后立即读取旧缓存；✅ 每次加载native结果后必须做差异清理，移除native不再返回的设备；✅ 手动刷新不应先清空再加载，应等新数据做差异替换避免UI闪烁；✅ 手动刷新应清除忽略列表，用户主动刷新意味着想重新看到所有设备。

### Ctrl+Alt+Del 用普通键盘事件模拟导致远程无效 (2026-06-02发现, 已修复)
**现象**: 远程控制菜单里点击插入 `Ctrl+Alt+Del`，远端没有生效。
**根因**: UI 侧模拟普通键盘事件，但 Harmony native `send_keyboard_input()` 仍是 stub/fallback；`Ctrl+Alt+Del` 在 RustDesk official 中有专用 session 命令，不能依赖普通键盘序列模拟。
**解决**: 新增 `sendCtrlAltDel()` ArkTS/NAPI/C ABI/Rust bridge 链路，native 侧调用 active session 的 official `Session::ctrl_alt_del()`；失败时 UI 提示命令不可用，不再误报成功。
**教训**: ✅ 会话安全命令要优先查 official session API；菜单入口不能只模拟 UI 行为，必须确认 native 已有真实命令路径。

### 通讯录未登录仍可进入添加逻辑 (2026-06-02发现, 已修复)
**现象**: 通讯录属于账户数据，但未登录时仍可能看到通讯录内容或从历史记录触发添加。
**根因**: 通讯录 Tab 和“添加到通讯录”菜单没有统一登录态门禁。
**解决**: 通讯录 Tab 未登录时显示登录入口；历史记录添加到通讯录前先检查登录态，未登录则弹出登录对话框并终止添加。
**教训**: ✅ 账户通讯录必须先经过登录态检查；未登录状态下应该给登录动作，而不是静默写入本地数据。

### 共享服务关闭后重启又自动开启 (2026-06-02发现, 已修复)
**现象**: 共享页要求默认关闭，但 App 启动后核心 ready 流程会自动调用 `toggleIncomingService(true)`，导致用户关闭服务后重启状态丢失。
**根因**: `ensureIncomingServiceEnabled()` 只判断 `coreReady && !incomingReady`，没有尊重持久化的 `settings.serviceEnabled`。
**解决**: 启动恢复逻辑改为以持久化设置为准：`serviceEnabled=true` 时恢复开启；`serviceEnabled=false` 时如果 native incoming 已开启则明确关闭。
**补充修复**: 实机上旧版本已经把错误的 `serviceEnabled=true` 写入偏好，导致新版本继续恢复“运行中”。已增加一次性迁移 `incoming_service_default_off_migration_20260602`，升级后首次启动强制把历史脏状态纠正为关闭，迁移后再尊重用户手动开启/关闭。
**教训**: ✅ 共享服务属于用户安全状态，不能用核心 ready 状态推导自动开启。

### 共享服务假运行和临时密码未进入官方鉴权 (2026-06-02发现, 已修复)
**现象**: 共享页显示服务运行中，但其他设备无法访问；生成一次性密码后 UI/服务不立即使用新密码。
**根因**: wrapper 在 official `set_incoming_service_enabled()` 返回 `{}` 时把 `incomingReady` 伪装为 true；`setLocalOption('temporary-password')` 只进入 Harmony bridge 内存 map，没有写入官方 `password_security::TEMPORARY_PASSWORD`。
**解决**: wrapper fallback 不再标记未确认 incoming service 为运行中；一次性密码写入 `temporary-password`、`verification-method=use-temporary-password`、`approve-mode=password`，Rust bridge 将 `temporary-password` 同步到官方临时密码内存。生成密码后立即同步 native 并刷新本地 profile。
**教训**: ✅ UI 不能把 wrapper fallback 状态当作真实服务监听状态；密码必须进入官方鉴权读取路径，只写本地偏好或 wrapper map 不够。

### 文件访问授权只声明未申请 (2026-06-02发现, 已修复)
**现象**: manifest 已声明 `FILE_ACCESS_PERSIST`，但运行时"文件传输/共享权限"只申请 `READ_WRITE_DOWNLOAD_DIRECTORY`。
**根因**: `PermissionService.getRequiredPermissions()` 和共享页申请链路未包含 `FILE_ACCESS_PERSIST`。
**解决**: 权限服务和共享页文件传输开关同时申请 `READ_WRITE_DOWNLOAD_DIRECTORY`、`FILE_ACCESS_PERSIST`。
**教训**: ✅ manifest 声明不等于运行时授权；文件传输能力要同时检查声明和 requestPermissions 链路。

### 设置页和共享页重复权限入口冲突 (2026-06-03发现, 已修复)
**现象**: 设置页中存在与共享页重复的 `Share Screen` 权限开关区，容易造成用户从两个位置修改 `allowClipboard`、`allowFileTransfer`、`allowRemoteControl` 等同一组状态，并误判文件访问授权没有被唤起。
**根因**: 设置页重复入口只更新状态，和共享页权限请求链路容易不一致；但官方设置页仍需要 `共享屏幕` 分组承载长期偏好。
**解决**: 设置页按官方分组重排为账户、设置、硬件编解码、录屏、2FA、共享屏幕、显示设置、增强功能、关于；设置页 `Share Screen` 分组只保留长期偏好（LAN 发现、白名单 IP、自适应码率、允许录制会话、IP 直接访问、自动关闭不活跃会话），共享页权限菜单保留为运行时授权唯一入口。
**教训**: ✅ 同一运行时权限只保留一个交互入口；设置页可以保留官方长期偏好分组，但不能复制共享页的录屏/输入/文件/剪贴板授权菜单。

### Toggle isOn 值绑定导致异步权限请求期间回弹 (2026-06-03发现, 已修复)
**现象**: 点击 Screen Capture 开关后，开关瞬间打开又立即弹回关闭状态，权限对话框不弹出或弹出后开关仍显示关闭。
**根因**: `buildToggleRow` 中 `Toggle({ isOn: value })` 是值绑定，`value` 是普通 boolean 参数。onChange 中调用 async 权限请求方法，在 `await` 等待期间，任何 `@State` 变化触发重渲染都会把 Toggle 的 `isOn` 重置回旧值（`this.settings.serviceEnabled` 仍为 false），导致视觉回弹。
**解决**: 所有5个权限开关的 onChange 回调中，先同步 `updateSettings` 更新对应状态为 true，再执行异步权限请求；权限拒绝时回滚为 false。这样 Toggle 的 `isOn` 绑定值立即更新，重渲染不会回弹。
**教训**: ✅ ArkUI Toggle 的 `isOn` 如果是值绑定（非 `@Link` 双向绑定），onChange 中必须先同步更新数据源，再执行异步操作；✅ 异步操作期间任何 `@State` 变化都会重渲染，把 Toggle 回弹到 `isOn` prop 的旧值。

### ForEach key 包含 accountRefreshTick 导致 Toggle 组件销毁 (2026-06-03发现, 已修复)
**现象**: 点击权限开关时，如果同时有登录状态刷新，Toggle 组件被销毁重建，onChange 回调丢失。
**根因**: `build()` 中 `ForEach([this.i18nVersion], ..., (_, index) => '${this.i18nVersion}_${this.accountRefreshTick}_${index}')` 的 key 包含 `accountRefreshTick`。`accountRefreshTick` 在登录状态刷新时递增，导致整个 Tab 内容销毁重建。
**解决**: ForEach key 移除 `accountRefreshTick`，改为 `${this.i18nVersion}_${index}`。i18n 切换仍能正确触发重渲染，但登录状态刷新不再销毁 Tab 组件。
**教训**: ✅ ForEach key 应只包含需要触发子树销毁重建的状态变量；✅ 账号刷新等频繁变化的状态不应放入 ForEach key。

### toggleIncomingService 中 startCapture 失败后未 throw (2026-06-03发现, 已修复)
**现象**: `startCapture()` 抛异常后，catch 块只调了 `stopCapture()` 但没有 throw，导致 `toggleIncomingService` 继续执行把 `serviceEnabled` 设为 true，开关显示打开但录屏实际未启动。
**根因**: catch 块吞掉了异常，调用方 `checkScreenCapturePermissionAndToggle` 不知道失败了。
**解决**: catch 块末尾添加 `throw new Error('startCapture failed: ' + error)`，让调用方的 catch 块能回滚 `serviceEnabled: false`。
**教训**: ✅ 异步操作失败时必须向上传播异常，不能在 catch 中吞掉；✅ 调用方需要根据异常回滚 UI 状态。

### console.info 在 HarmonyOS 设备上不输出到 hilog (2026-06-03发现, 已修复)
**现象**: 代码中添加了 `console.info('[SHARE]')` 调试日志，但设备 `hilog -x | grep SHARE` 完全没有输出。
**根因**: HarmonyOS 上 `console.info` 的日志可能被优化掉或输出到不同缓冲区，不保证出现在 hilog 中。
**解决**: 改用 `hilog` API：`import hilog from '@ohos.hilog'`，调用 `hilog.info(0xA03D00, 'SHARE', 'message')`。
**教训**: ✅ HarmonyOS 调试日志必须用 `hilog` API，不要依赖 `console.info/warn/error`；✅ domain 使用应用已有 domain `0xA03D00`（com.open.rundesk/JSAPP）。

### 多余右花括号导致5554个级联语法错误 (2026-05-31)
**现象**: Index.ets编译报5554个语法错误
**根因**: Index.ets:1687 onClick闭包内if语句后多了一个`}`，把this.refreshAccountState()推到闭包外面
**解决**: 删除多余的`}`
**教训**: ✅ArkTS一个花括号错误可导致数千级联错误，先看第一个错误位置

### toggleFavorite()重复定义 (2026-05-31)
**现象**: AppDataService.ets编译报toggleFavorite重复定义
**根因**: 527行旧版基于addressBook的toggleFavorite未删除，与397行基于localFavorites的新版冲突
**解决**: 删除旧版toggleFavorite
**教训**: ✅重构时必须删除旧版方法，不能新旧共存

### `private private`重复修饰符 (2026-05-31)
**现象**: 11个文件共98处`private private`修饰符
**根因**: 批量添加private修饰符时与已有private重复
**解决**: 全部改为`private`
**教训**: ✅批量修改前检查已有修饰符，避免重复

### getPeerOption('hostname')始终返回空字符串 (2026-05-31)
**现象**: 设备名称无法从原生缓存获取hostname，所有设备显示ID而非名称
**根因**: (1) Rust bridge未导出rustdesk_bridge_get_peer_option函数；(2) 即使添加，官方RustDesk中hostname存储在PeerConfig.info.hostname，而get_peer_option从PeerConfig.options读取，两者不同字段
**解决**: 新增rustdesk_bridge_get_peer_info(peer_id)从PeerConfig.info读取hostname/username/platform/alias(返回JSON)；3处名称解析逻辑改为优先getPeerInfo()回退getPeerOption
**教训**: ✅RustDesk配置分PeerConfig.options和PeerConfig.info两个不同结构，hostname在info不在options；✅必须对比官方Flutter逻辑(peer_to_map()从info读取)确认字段位置

### Rust工具链缺失 (2026-05-31)
**现象**: cargo.exe不存在，无法编译Rust核心
**根因**: 未安装rustup和stable工具链
**解决**: 安装rustup + stable工具链 + aarch64-unknown-linux-ohos target
**教训**: ✅确认rustup/cargo可用后再编译；✅ohos target需单独添加

### Windows交叉编译Rust核心: machine-uid build.rs误判host (2026-06-01发现, 已修复)
**现象**: Windows上交叉编译aarch64-unknown-linux-ohos时，`machine-uid` crate的build.rs中`#[cfg(target_os = "windows")]`为true（检查host而非target），编译win.cpp失败（找不到windows.h）
**根因**: build.rs中`#[cfg(target_os)]`基于host平台，交叉编译时host=Windows但target=OHOS(Linux)
**解决**: patch machine-uid crate，build.rs改用`std::env::var("TARGET")`检查target triple而非cfg；Cargo.toml添加`[patch]`指向本地patch
**教训**: ✅build.rs中`#[cfg(target_os)]`检查的是host不是target；✅交叉编译时必须用`env::var("TARGET")`判断目标平台；✅[patch]段可覆盖git依赖

### Windows交叉编译Rust核心: rustix 0.37与nightly不兼容 (2026-06-01发现, 已修复)
**现象**: rustix 0.37.28使用`rustc_layout_scalar_valid_range_start`等nightly内部属性，当前Rust nightly编译器已将其保留为`rustc`前缀，编译失败
**根因**: rustix 0.37太旧，与最新nightly不兼容
**解决**: 切换到stable工具链编译（`cargo +stable build`），stable不暴露这些内部属性，rustix走linux_raw backend
**教训**: ✅rustix旧版本可能不兼容最新nightly；✅交叉编译OHOS用stable工具链更稳定

### Windows交叉编译Rust核心: libsodium缺失 (2026-06-01发现, 已修复)
**现象**: cargo build报`could not find native static library 'sodium'`
**根因**: 99_Temp构建目录中没有预编译的libsodium静态库（aarch64-unknown-linux-ohos）
**解决**: 通过MSYS2 bash + OHOS clang交叉编译libsodium：configure --host=aarch64-unknown-linux-gnu + make install；产物549KB liblibsodium.a
**教训**: ✅libsodium必须为OHOS target单独交叉编译；✅MSYS2+OHOS clang是Windows上交叉编译C库的可行方案

### Windows交叉编译Rust核心: host/target误判与bindgen参数链 (2026-06-01发现, 已修复)
**现象**: Windows端继续编译时依次遇到 `socket2` IovLen cfg、`libsodium-sys` host build script、`kcp-sys`/`scrap` bindgen sysroot、`rdev`/`scrap` X11路径、`rustdesk-master/build.rs` Windows target误判等问题
**根因**: 多个crate在build.rs中混用了host平台与target平台判断；部分bindgen调用没有读取target-specific `BINDGEN_EXTRA_CLANG_ARGS`
**解决**: 为socket2加入OHOS cfg；让libsodium-sys读取 `SODIUM_LIB_DIR_aarch64_unknown_linux_ohos`；kcp-sys/scrap显式传入OHOS bindgen参数；scrap/rdev对OHOS走fallback/no-op；rustdesk-master/build.rs仅在target为Windows时执行Windows资源构建
**教训**: ✅Windows交叉编译OHOS时，所有build.rs都要先分清host与target；✅target-specific环境变量优先，避免host脚本误链接aarch64库

### Rust核心返回空JSON{}导致核心启动失败 (2026-06-01发现, 已修复并真机验证)
**现象**: `rustdesk_core::harmony_bridge`模块当前仍是stub实现，`initialize_runtime`返回`"{}"`，`get_core_snapshot_json`返回`"{}"`；ArkTS解析`{}`后字段缺失，启动快照曾表现为`coreReady:false`，核心状态异常
**根因**: 上游stub的空JSON泄漏到了NAPI返回值；仅检查Rust符号存在和SO可加载不够，必须检查ArkTS实际收到的`initializeRuntimeFn returned`原始值
**解决**: 修改`bridge_api.rs`，`initialize_runtime`调用上游stub后由导出层明确返回`BridgeSnapshot`有效JSON（`coreReady:true`, `adapter:"official-native"`）；`get_core_snapshot`在上游返回`{}`时继续使用本地快照
**验证**: 2026-06-01 22:45，无线设备`192.168.11.100:36169`安装启动成功；日志显示`RustDesk bridge loader module registered (50 functions)`、`initializeRuntimeFn returned`为有效JSON、`Bootstrap snapshot`为`{"adapter":"official-native","coreReady":true,...}`
**日志**: `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_test_logs\launch_after_fix_20260601_224528.log`
**教训**: ✅上游stub返回空JSON时bridge层必须填充默认值；✅BridgeSnapshot结构已有完整序列化逻辑，应优先使用；✅每次修复核心返回值都要同时验证staticlib、bridge SO、HAP内是否包含新标记，再看真机NAPI原始返回值

### XCB未解析符号导致SO加载失败 (2026-06-01发现, 已修复)
**现象**: `librustdesk_bridge.so`中包含23个XCB/X11未解析符号（`xcb_connect`、`xcb_disconnect`等），HarmonyOS运行时dlopen严格检查所有符号，拒绝加载
**根因**: Rust核心的Linux桌面X11依赖残留，虽然链接时用`--unresolved-symbols=ignore-all`，但运行时dlopen仍检查
**解决**: 创建`ohos_stubs.cpp`为23个XCB符号提供空stub实现
**教训**: ✅`--unresolved-symbols=ignore-all`只影响链接，不影响运行时dlopen；✅OHOS运行时严格检查所有符号，必须提供stub

### NAPI模块导出结构兼容性不足 (2026-06-01发现, 已修复)
**现象**: `resolveFunction`仅通过`collectModuleRecords`遍历模块子记录查找函数，可能遗漏HarmonyOS特定的导出结构
**解决**: 增加直接属性访问fallback、forced缓存、重试机制、更多诊断信息
**教训**: ✅NAPI模块加载需要多层fallback策略；✅诊断信息对排查加载问题至关重要

### Ubuntu交叉编译Rust核心失败链路 (2026-06-01已解决)
**现象**: `build_native_bridge.sh aarch64-unknown-linux-ohos release` 初始出现大量Rust错误，后续曾卡在X11链接、`harmony_bridge`缺失、`ui_interface/hbb_common`不可见等问题
**根因**: `aarch64-unknown-linux-ohos` 的 `target_os` 是 `linux`，会误命中Linux桌面代码；同时RustDesk核心作为依赖crate时不应生成桌面相关`cdylib`
**解决**: 用 `target_env="ohos"` 精确排除桌面代码；`rustdesk-master/Cargo.toml` 的lib crate-type收敛为 `["rlib"]`；`harmony_bridge`模块重导出core并补齐stub；`bridge_api.rs`改走`rustdesk_core::harmony_bridge::*`
**验证**: 2026-06-01 Ubuntu release构建成功，生成约128MB `librustdesk_harmony_bridge.a`；随后Windows release构建成功，当时产物132,250,204 bytes，关键符号 `rustdesk_bridge_get_peer_option/get_peer_info/initialize_runtime` 可检出，HAP安装启动后`coreReady:true`
**教训**: ✅OHOS判断必须用`target_env`；✅依赖crate避免生成无用`.so`；✅Rust C ABI、C++ ABI header、NAPI注册、ArkTS d.ts四层需要分别核对

### Rust C ABI与C++ NAPI接线数量不一致 (2026-06-01发现, 已修复)
**现象**: Rust `bridge_api.rs` 已导出46个 `rustdesk_bridge_*` 函数，但 `rustdesk_bridge_loader.cpp` 当前只注册41个NAPI函数，`rustdesk_bridge_abi.h`当前声明39个extern函数
**影响**: ArkTS `NativeRustDeskBridge` 对 `getPeerInfo/getPeerOption` 等函数会先尝试NAPI，再回退读取PeerConfig文件；Rust侧符号存在不等于C++ NAPI已暴露
**解决**: 补齐abi.h 7个缺失声明;补齐loader.cpp 10个NAPI包装函数和注册;重写index.d.ts与C++ NAPI签名对齐
**教训**: ✅文档中“Rust已导出”和“ArkTS可直接调用”必须分开写；✅新增Rust函数后必须同步C++/ArkTS三层

### scrap bindgen字段变_address
**现象**: bindgen生成的C结构体字段名加_address后缀
**根因**: BINDGEN_EXTRA_CLANG_ARGS未传入build.rs的generate_bindings()
**解决**: export BINDGEN_EXTRA_CLANG_ARGS + export LIBCLANG_PATH
**教训**: ✅每次编译前确认环境变量完整(见CORE.md)

### 链接器调用错误ld.exe
**现象**: clang默认调用PATH中的ld.exe(Strawberry Perl的)，而非ohos lld
**根因**: PATH中有其他ld.exe
**解决**: RUSTFLAGS="-C link-arg=--target=aarch64-linux-ohos -C link-arg=-fuse-ld=lld"
**教训**: ✅必须设置RUSTFLAGS强制用lld

### qsort_r未定义
**现象**: Rust核心链接报undefined reference to `qsort_r`
**根因**: HarmonyOS musl libc未实现qsort_r (GNU extension)
**解决**: 在rustdesk_bridge_loader.cpp中实现qsort_r stub (insertion sort)
**教训**: ✅ohos musl缺少部分GNU extension，需要stub

### recorder cfg(E0658)
**现象**: `#[cfg(feature = "recorder")]`不能用在表达式中间
**根因**: Rust experimental attribute限制
**解决**: 提取为变量再cfg保护
**教训**: ✅cfg(feature)不能用在表达式中间，需先提取变量

## 登录链路问题 (已解决, 2026-05-30)

### LoginPage OAuth登录绕过AccountService
**现象**: LoginPage.handleOAuthLogin()直接调用httpClient.oidcAuth()和自己的startWebPolling()，绕过AccountService.loginWithOAuth()
**根因**: LoginPage有独立的轮询逻辑(pollTimer/pollCount)，与AccountService的轮询重复；轮询成功后不触发EventBus ACCOUNT_LOGIN事件，其他组件感知不到登录状态变化
**解决**: LoginPage.handleOAuthLogin()改为调用accountService.loginWithOAuth()，移除LoginPage的startWebPolling()/handleWebLoginSuccess()；通过@Watch('onAccountChanged')监听accountState变化自动返回
**教训**: ✅登录操作必须统一走AccountService，不要在页面层重复实现轮询；✅登录成功通过AppState+EventBus通知全局

### 远控触摸响应区域超出视频显示区域 (2026-06-05发现, 已修复)
**现象**: 远控页面触摸事件在视频画面外的黑边区域也有响应，触摸黑边会被钳制到画面边缘产生非预期操作
**根因**: RemoteControl.ets第549行触摸覆盖层Column(){}设为width('100%')height('100%')，覆盖整个预览容器而非仅视频画面
**解决**: 触摸覆盖层尺寸改为resolveRenderedImageWidth()×resolveRenderedImageHeight()，仅覆盖实际视频画面区域
**教训**: ✅触摸响应区域必须与视频显示区域精确匹配，不能使用100%容器尺寸

### 首次连接远程画面不显示就跳回连接页面 (2026-06-05发现, 已修复)
**现象**: App开启后第一次连接远程，画面没有显示出来就自动跳回连接页面；第二次连接正常
**根因**: session短暂进入connected状态后断开(idle)，此时sessionBecameActive=true但hasReceivedFrame=false，shouldAutoCloseTerminalSession()返回true，直接finishTerminalSession返回连接页面而不显示重试对话框
**解决**: idle状态下，如果sessionBecameActive且!hasReceivedFrame（连接过但没收到帧），优先显示重试对话框而非直接关闭
**教训**: ✅连接已建立但未收到视频帧时不应自动关闭，应给用户重试机会；✅首次连接和重连的帧到达时序可能不同

### 设置页扫码图标丢失 (2026-06-05发现, 已修复)
**现象**: 设置页右上角扫码图标(scan_frame)不见了
**根因**: buildSettingsPageHeader()方法已定义但未被调用，设置Tab头部使用的是PageHeader()通用组件，不含扫码按钮
**解决**: 设置Tab头部从PageHeader(this.lt('RustDesk'))替换为this.buildSettingsPageHeader()
**教训**: ✅修改页面头部时要检查所有Tab是否使用了正确的头部Builder；✅定义了但未调用的Builder方法容易遗漏

### 设置行图标颜色不一致 (2026-06-05发现, 已修复)
**现象**: 新添加的设置行图标使用colorFilter(stroke格式)，旧图标(Language/Theme/Display)使用fillColor(fill格式)，颜色和渲染方式不统一
**根因**: 旧图标行是内联Row直接写fillColor，新图标通过buildSettingsToggleSettingRow的icon参数使用colorFilter
**解决**: Language行translate.svg、Theme行dark_mode/light_mode.svg、Display行display.svg统一改为colorFilter+theme_TEXT_TERTIARY
**教训**: ✅同类位置图标必须统一渲染方式(colorFilter vs fillColor)和颜色层级(TEXT_TERTIARY for行内图标)

### 自定义键盘按键不透明 (2026-06-05发现, 已修复)
**现象**: KeyboardToolbar中修饰键、功能键、特殊组合键、Input/Enter按钮全部使用不透明背景色
**根因**: 所有按键直接使用theme_INACTIVE_BG/theme_ACCENT/theme_WHITE等不透明主题色
**解决**: 未激活修饰键、功能键、Clear、Input/Hide改为#55333333(约33%半透明)；Lock/Enter改为#550071FF；Ctrl+Alt+Del改为#80FCA5A5；TextInput背景改为#55333333
**教训**: ✅覆盖在远程画面上的键盘面板所有按键必须使用半透明背景，避免遮挡画面

### 聊天页面背景不够透明且不自动滚动 (2026-06-05发现, 已修复)
**现象**: 聊天头部背景50%透明度不够透；新消息到达后列表不自动滚动到底部
**根因**: 头部背景色#80前缀(50%透明)；Scroll没有Scroller控制器，没有scrollEdge调用
**解决**: 头部背景从#80改为#40(25%透明)；添加Scroller实例，chatListener和aboutToAppear中调用scrollEdge(Edge.Bottom)
**教训**: ✅聊天类页面必须自动滚动到最新消息；✅覆盖层背景透明度应足够低避免遮挡内容

### 关于页面指纹图标位置和文本显示 (2026-06-05发现, 已修复)
**现象**: 指纹图标在右侧以36x36大图标显示，没有显示实际指纹文本值
**根因**: 原设计把指纹图标当复制按钮放在右侧，与设置行"图标+标签+值"的统一格式不一致
**解决**: 指纹图标移到行首(20x20 colorFilter stroke格式)，标签后显示指纹前12字符+...，点击文本可复制完整指纹
**教训**: ✅设置行格式应统一为"图标+标签+值"模式；✅可复制内容应显示部分文本提示用户可交互

### 版本号不从app.json5同步 (2026-06-05发现, 已修复)
**现象**: 关于页面版本号始终显示v0.4.0，与app.json5中versionName不一致
**根因**: run_hvigor_with_sdk_patch.js中BuildInfo.VERSION硬编码为'0.4.0'，且旧读取路径指向了错误的AppScope位置
**解决**: 构建脚本基于当前BuildInfo显示版本自增并同步写回AppScope/app.json5与BuildInfo.ets；增量构建右侧数字+1，全量构建中间数字+1且右侧归零，versionCode每次构建单调+1
**教训**: ✅构建入口必须明确传入增量/全量版本自增模式；✅显示版本、AppScope版本和versionCode必须由脚本同步维护；✅不要在构建脚本中硬编码版本号

### 密码登录未处理email_check/tfa_check
**现象**: 密码登录返回email_check/tfa_check时，LoginPage/Settings/Index只显示"登录失败"，不触发邮箱验证或2FA流程
**根因**: AccountService.loginWithPassword()返回boolean，无法区分email_check/tfa_check；页面层未处理这两种状态
**解决**: loginWithPassword()返回类型改为PasswordLoginResult{success,emailCheck?,tfaCheck?}，页面层根据返回值设置requireEmail/requireTfa状态
**教训**: ✅API返回多种分支状态时，返回类型必须包含所有分支信息；❌不要用单一boolean掩盖多分支逻辑

### LoginPage AccountState接口与AppState不一致
**现象**: LoginPage底部重新定义了AccountState接口(缺少loginUrl/status/lastError等字段)，@StorageLink绑定类型不匹配
**根因**: 页面内重复定义接口，未从AppState导入完整类型
**解决**: 移除LoginPage内部AccountState定义，从AccountService导入完整AccountState接口
**教训**: ✅@StorageLink绑定的类型必须与AppStorage.setOrCreate的类型完全一致；❌不要在页面内重复定义状态接口

### ArkTS对象字面量类型错误(arkts-no-untyped-obj-literals)
**现象**: AccountService.loginWithPassword()返回对象字面量{success:false}，ArkTS编译报错
**根因**: ArkTS要求对象字面量必须对应显式声明的类或接口
**解决**: 定义PasswordLoginResult接口和PasswordLoginResultImpl实现类，用new创建实例
**教训**: ✅ArkTS中返回对象必须用class实例化，不能用对象字面量；✅接口+Impl类是ArkTS标准模式

### oidcAuth的op参数格式错误
**现象**: 发送`op=oidc/github`或`op=OIDC/GITHUB`，服务器返回"oidc OP is not suppported"
**根因**: /api/oidc/auth的op参数应为纯provider名(如`github`)，不需要oidc/前缀；/api/login-options返回的`oidc/github`只是标识符
**解决**: body.op直接传provider名(github/google/microsoft)；loadProviders去掉oidc/前缀匹配本地OAuthProvider.id
**教训**: ✅不同API的op字段格式不同，login-options用oidc/前缀标识，oidc/auth用纯名；✅用curl测试服务器确认格式

### getLoginOptions返回格式不匹配
**现象**: 服务器返回字符串数组["oidc/github","oidc/google",...]，但代码期望{oauth:LoginOption[]}对象
**根因**: HttpClient.getLoginOptions直接反序列化为LoginOptionsResponse，服务器实际返回格式不同
**解决**: 手动解析响应：若为数组则提取oidc/开头的项，若为对象则取oauth字段
**教训**: ✅API响应格式需用curl验证后再写反序列化逻辑；✅两种格式都兼容处理

### 亮色主题ID输入框边框太淡
**现象**: 亮色主题下ID输入框边框几乎看不见
**根因**: BORDER_SUBTLE亮色值#E5E7EB太淡，与白色背景对比度不足
**解决**: BORDER_SUBTLE亮色改为#CBD5E1
**教训**: ✅亮色主题边框色需与背景有足够对比度

### 亮色主题顶部渐变偏暗
**现象**: 亮色主题下顶部渐变区域偏暗灰
**根因**: 渐变基色#D4D7DC偏暗灰蓝
**解决**: 渐变基色已调整为#F0F4FA（更亮的蓝白色）
**教训**: ✅亮色渐变基色应偏亮偏白

### 在线状态回调event.kind不匹配 (已解决, 2026-05-30)
**现象**: queryOnlines调用成功返回true，但UI在线状态不刷新
**根因**: 核心回调event.kind是`query-onlines-result`（非`callback-query-online`），且数据在event.peerId字段（非event.detail）
**解决**: 同时匹配两种kind，优先用detail，回退到peerId
**教训**: ✅核心回调格式需用日志验证，不能假设；✅两种格式都要兼容

### 在线状态各选项卡不同步 (已解决, 2026-05-30)
**现象**: 同一ID在不同选项卡在线状态不一致，recent不刷新
**根因**: 各数据源(recentSessions/addressBook/discoveredDevices)各自维护online字段，更新不同步；UI不追踪AppDataService内部Map变化
**解决**: AppDataService新增统一peerOnlineMap，所有选项卡通过isPeerOnline(id)共享；@State peerOnlineVersion触发重渲染
**教训**: ✅同一状态必须单一数据源(SSOT)，不能各组件各自维护副本；✅@State变量是ArkUI重渲染的唯一触发器

### 设备名称依赖discovered导致删除后丢失 (已解决, 2026-05-30)
**现象**: 删除discovered中ID卡片后，历史卡片名称也丢失
**根因**: resolveRecentSessionName/resolveConnectEntryName通过getDiscoveredDeviceName()获取名称，discovered删除后名称源消失
**解决**: 名称回退链改为: alias→addressBook alias→NativeRustDeskBridge.getPeerOption(hostname)→session.name，不再依赖discovered
**教训**: ✅名称应从持久化源获取(原生缓存/通讯录)，不能依赖临时数据(discovered会随LAN轮询变化)

### fetchAddressBook alias为空导致显示"远程+ID" (已解决, 2026-05-30)
**现象**: 通讯录/收藏中ID卡片显示"远程+ID"而非设备名称
**根因**: 服务器/api/ab返回的peer.alias可能为空，hostname被存到note字段而非alias
**解决**: fetchAddressBook中alias为空时用hostname回退；AddressBookEntry新增platform字段
**教训**: ✅服务器字段映射需验证，alias空时hostname是最佳回退

### 发现中删除设备被LAN轮询重新添加 (已解决, 2026-05-30)
**现象**: 删除discovered中ID卡片后，5秒后又出现
**根因**: LanDiscoveryService每5秒调用discoverLanPeers+loadLanPeers，重新添加已删除设备
**解决**: LanDiscoveryService新增ignoredPeerIds集合，删除后的设备不再重新添加
**教训**: ✅删除操作需要持久化标记，否则会被轮询覆盖

### 收藏/通讯录菜单操作影响其他选项卡 (已解决, 2026-05-30)
**现象**: 收藏中删除实际删历史记录；通讯录有重复操作；发现中删除影响历史名称
**根因**: Delete按钮对所有选项卡都调用deleteRecentTargetById；Rename对所有选项卡都显示
**解决**: Delete/Rename按选项卡区分：recent=删除历史，favorites=取消收藏，addressBook=移除，discovered=删除发现
**教训**: ✅菜单操作必须按选项卡上下文区分，不能共用同一操作

### 收藏与通讯录耦合 (已解决, 2026-05-30)
**现象**: 收藏是addressBook.filter(favorite)的子集，退出登录后收藏也丢失；收藏操作影响通讯录数据
**根因**: 收藏没有独立存储，依赖addressBook的favorite字段
**解决**: AppDataService新增localFavorites:Set<string>独立存储收藏，PreferenceStore持久化；addFavorite/removeFavorite/isFavorite/getFavorites方法；退出登录只清理通讯录不清理收藏
**教训**: ✅收藏是本地数据(持久化在本地)，通讯录是账户在线数据(退出登录清理)；✅两者必须解耦

### Remove from Favorites用toggleFavorite导致行为不确定 (已解决, 2026-05-30)
**现象**: "Remove from Favorites"菜单用toggleFavorite，如果状态不一致可能反而添加收藏
**根因**: toggleFavorite是切换操作，Remove场景应明确用removeFavorite
**解决**: "Remove from Favorites" onClick改为appData.removeFavorite(id)；isFavorite()委托appData.isFavorite(id)而非查addressBook
**教训**: ✅明确操作(add/remove)优于切换(toggle)，避免状态不一致

## UI问题 (易复发)

### 渐变背景分界线
**现象**: 顶部渐变背景与内容区域之间有可见分割线
**根因**: 渐变不透明度过渡不够平滑
**解决**: 调整渐变控制点透明度，确保过渡平滑
**教训**: ✅调整透明度使渐变效果更突出，消除可见分离线

### 主题切换闪烁
**现象**: 语言切换时Tab菜单卡片背景瞬间完全透明导致闪烁
**根因**: 页面重建时过渡动画时间不足
**解决**: 关闭动画1000ms + 页面淡入淡出400ms
**教训**: ✅语言切换动画时间需足够长覆盖重建时间

### SVG图标显示方块
**现象**: fillColor把SVG背景path也填充了，变成黑色方块
**根因**: SVG中有fill="none"的背景rect/path，fillColor也会填充它们
**解决**: 删除SVG中fill="none"的背景path
**教训**: ✅每个SVG必须检查并删除背景path；✅fill格式图标path必须有fill="#000000"

### SVG图标不随主题变色
**现象**: 图标颜色固定为黑色，不跟随主题变化
**根因**: 未设置fillColor或colorFilter属性
**解决**: fill格式用fillColor，stroke格式用colorFilter(BlendMode.SRC_IN)
**教训**: ✅所有图标必须设置fillColor/colorFilter响应主题；❌不要固定图标颜色

### 设置Tab修改不生效
**现象**: 修改Settings.ets但设置Tab无变化
**根因**: 设置Tab的UI代码全在Index.ets中，Settings.ets是独立详情页
**解决**: 修改Index.ets的buildSettingsOverview()
**教训**: ✅设置Tab代码在Index.ets，不在Settings.ets

### 增量编译修改不生效
**现象**: 修改代码后构建HAP但运行无变化
**根因**: hvigor增量编译缓存
**解决**: 删除entry/build目录后全量重编
**教训**: ✅修改不生效时先清除构建缓存

### 全量编译682个ArkTS严格模式错误 (未解决, 2026-05-30发现)
**现象**: 清除构建缓存后全量编译报682个ArkTS错误(arkts-no-any-unknown/arkts-no-standalone-this/arkts-no-untyped-obj-literals等),增量编译因缓存跳过这些检查而成功
**根因**: Index.ets中@Builder private方法使用this(arkts-no-standalone-this)、部分方法缺少显式返回类型(arkts-no-implicit-return-types)、对象字面量未对应class(arkts-no-untyped-obj-literals)、使用any/unknown类型(arkts-no-any-unknown)
**解决**: 待修复——需系统性将@Builder private改为@Builder、添加显式类型注解、定义class替代对象字面量
**教训**: ✅增量编译可能跳过严格检查,需定期全量编译验证;✅ArkTS严格模式要求: @Builder不能private、显式返回类型、class实例化对象、禁用any/unknown

### CMake --warn-unresolved-symbols不生效导致链接失败 (2026-06-01发现, 已修复)
**现象**: CMake链接Rust staticlib时报`ld.lld: error: undefined symbol: xcb_shm_query_version_reply`等XCB符号错误
**根因**: `--warn-unresolved-symbols`在ld.lld上不将未解析符号降级为警告，仍报error退出
**解决**: 改为`--unresolved-symbols=ignore-all`，XCB残留符号仅警告不阻断
**教训**: ✅ld.lld与GNU ld行为不同，`--warn-unresolved-symbols`不保证降级为warning；✅staticlib中残留X11/xcb引用是正常的(ohos运行时不调用)

### HDC命令行直连/无线安装易踩坑 (2026-06-01发现, 已解决)
**现象**: 命令行直接运行`hdc list targets`可能返回空，但DevEco Studio连接正常；同时存在USB和无线目标时，命令可能发到错误设备；无线目标长时间抓日志后可能变为Offline；`hdc install -r -g`在当前设备上会触发`bm install`的`unknown option`
**根因**: hdc需要后台server进程(监听127.0.0.1:8710)，DevEco启动时会自动拉起；多目标环境必须显式指定target；当前设备端`bm install`不支持`-g`
**解决**: 使用前先执行`hdc start`或确认DevEco已启动server；无线测试统一使用`hdc -t 192.168.11.100:36169 ...`；无线Offline时重新执行`hdc tconn 192.168.11.100:36169`；安装使用`hdc -t 192.168.11.100:36169 install -r <hap>`，权限单独处理
**教训**: ✅命令行使用HDC必须先`hdc start`；✅多目标时必须加`-t`；✅无线HDC掉线先`tconn`恢复，不要误判为构建/安装失败；✅当前设备安装不要加`-g`

### 连接失败-上游harmony_bridge为空stub (2026-06-02发现, 已推进到真实session路径)
**现象**: 输入远端ID点击连接，之前状态无任何变化（stub空实现）
**根因**: `rustdesk-master/src/harmony_bridge/core.rs`中`connect_to_peer`为空实现`{}`，不发起网络请求也不产生会话事件
**历史修复**: 曾用ConnectState+事件队列模拟连接生命周期，让UI先能看到connecting→password_required→connected完整流程。
**当前状态**: 已接入官方 RustDesk `Session<HarmonyHandler>` 路径；`connect_to_peer()`会保存active session，`refresh_session_video()`会调用`request_init_msgs()`/`refresh_video()`，`harmony_next_rgba()`会从session拉帧。上一轮USB验证曾确认访问端收到真实视频帧。
**剩余风险**: 仍需继续验证连接稳定性、成功前误弹重试、连接后立即断开、访问端等待视频流等运行时问题。
**教训**: ✅stub函数即使签名正确也不会产生实际效果；✅验证核心不能只看coreReady，还要验证`session-connected`、`peer-info`、`video-frame`、输入转发等关键功能；✅文档中出现“模拟连接/真实网络未实现”时必须标注为历史状态。

### 核心状态显示不完整 (2026-06-01发现, 已修复)
**现象**: 核心加载成功(coreReady:true)但Display ID显示"等待核心初始化"；核心卡片Rust Core行仅显示"已加载"而非具体状态摘要；核心详情弹窗缺少Error和Detail信息
**根因**: (1) 上游stub的displayId为空，UI层正确显示"等待核心初始化"但核心状态文本不够详细；(2) getCoreStatusText()在coreReady时仅返回"Loaded"而非statusSummary；(3) 弹窗只显示Status行缺少Error/Detail行；(4) OfficialRustDeskBridge中多处硬编码中文占位文本(如"等待官方原生核心")混入状态字段，应改为空字符串由UI层统一处理
**解决**: getCoreStatusText()在coreReady时返回statusSummary(有值)或"Loaded"(回退)；弹窗新增Error和Detail行；normalizeNativeState/normalizeStoredState/createStubState/createBridgeAvailableState中fingerprint/directAddress/statusSummary/detailMessage默认值改为空字符串；connectToPeer等错误消息改为英文；I18nService新增Unrecognized/Detail翻译
**教训**: ✅核心状态和错误应集中在弹窗中展示，其余位置显示"等待核心"；✅状态字段默认值用空字符串，UI层通过lt()翻译统一显示占位文本；✅硬编码中文不应出现在状态字段中，应通过i18n翻译

### hilog抓取与过滤误判 (2026-06-01发现, 已解决)
**现象**: `hilog`输出量大，在线过滤容易漏掉关键行或因shell/grep语法差异失败；长时间连续抓取还可能导致无线HDC连接不稳定
**解决**: 测试启动前先`hdc -t <target> shell hilog -r`清空缓冲；启动后用`hdc -t <target> shell hilog -x`拉取完整日志到本地，再用PowerShell `Select-String`按`RustDesk/NativeRustDeskBridge/EntryAbility/coreReady/initializeRuntime`过滤
**教训**: ✅真机验证核心链路时优先保存完整raw日志；✅过滤在本地做，保留raw+filtered两份；✅关键判断看`initializeRuntimeFn returned`和`Bootstrap snapshot`，不要只看“module registered”

### StatusBadge被挤出卡片
**现象**: StatusBadge显示在卡片外部
**根因**: SectionTitle设置了.width('100%')占满Row
**解决**: 移除SectionTitle的.width('100%')
**教训**: ✅检查Row中子元素宽度是否占满导致其他元素被挤

### 图标方向冲突
**现象**: 两个图标共用资源但方向需求不同(如排序需要镜像)
**根因**: 单个SVG资源无法同时满足不同方向需求
**解决**: 断开分成独立图标资源(如sort.svg单独处理镜像)
**教训**: ✅图标方向冲突时分成独立资源文件

## 构建问题 (易复发)

### SDK component missing
**现象**: 直接运行hvigorw.js报SDK component missing
**根因**: 未设置环境变量DEVECO_SDK_HOME等
**解决**: 使用`node scripts/run_hvigor_with_sdk_patch.js assembleHap`
**教训**: ✅不要直接运行hvigorw.js，必须用脚本

### NEEDED含绝对路径
**现象**: CMake链接SO时NEEDED记录含构建机器绝对路径
**根因**: CMake IMPORTED_LOCATION使用完整路径
**解决**: 设置IMPORTED_SONAME为相对路径；staticlib方案不存在此问题
**教训**: ✅staticlib方案下不会出现此问题

### 签名失败(code:9568257)
**现象**: OpenHarmony签名HAP在华为商业设备安装失败
**根因**: 华为设备只信任华为CBG证书链，拒绝OpenHarmony测试签名
**解决**: 使用DevEco Studio签名或手动华为签名
**教训**: ✅华为商业设备必须用DevEco Studio签名

## 调试技巧

### 查看核心初始化状态
```bash
hdc shell "hilog -x | grep -E 'coreReady|RustDeskLoader'"
```

### 检查SO是否正常
```bash
readelf -d librustdesk_bridge.so | grep TEXTREL  # 无输出=正常
nm -D librustdesk_bridge.so | grep rustdesk_bridge_initialize_runtime  # 有输出=正常
objdump -p librustdesk_bridge.so | grep NEEDED  # 检查依赖
```

### 清除构建缓存
```bash
sh scripts/clean_project_artifacts.sh  # 清理entry/build、entry/.cxx、native_rust_core/target等可再生成缓存
```

### 清理99_Temp边界
- 可删除: `build_log*.txt`、临时分析脚本、旧APK/归档/备份、旧Hvigor输出、旧独立build target、vcpkg downloads/buildtrees/packages、Rust target缓存
- 必须保留: `rustdesk-master/`源码、`rustdesk_harmonyos_build/`中的SDK/vcpkg工具/外部依赖源码/tools/patches/构建脚本、`build/libsodium/.../liblibsodium.a`、`native_rust_core/target/harmony/librustdesk_harmony_bridge.a`

### 官方服务器默认值显示与空值语义冲突 (2026-06-03发现, 已修复)
**现象**: 设置页直接显示官方服务器地址；用户清空某一行后，运行时可能把空值传给 native，而不是使用官方默认配置。
**根因**: 默认官方服务器值既承担运行参数，又承担 UI 显示值，缺少“存储值”和“有效值”的分层。
**解决**: `AppDataService` 新增官方默认常量和 `resolveServerConfig()`；默认存储空字符串，空 ID/Relay/API 在运行时分别回落到官方默认；设置页只显示“官方默认”，不显示官方域名；`OfficialRustDeskBridge` 和 `AccountService` 全部使用有效配置。
**教训**: ✅ 配置 UI 的空值语义必须和 native 入参语义分离；✅ 官方默认值可以作为隐含有效配置，但不应作为用户自定义值显示和持久化。

### official set_incoming_service_enabled 返回空导致共享服务无法确认 (2026-06-03发现, 已修复崩溃与状态确认)
**现象**: 共享页启动服务后 native 返回 `{}`，ArkTS 只能判断 incoming 未确认，服务显示无法启动。
**根因**: 上游 Harmony bridge 中 `set_incoming_service_enabled()` 仍是 stub。
**解决**: native bridge 已改为写入 server option、`stop-service`，并请求 `start_server(true, false)`；历史 `@ohos.screenshot.capture()` 屏幕捕获探测/截图路径已废弃，`AVScreenCaptureRecorder`/临时 mp4 探测也已在 2026-06-15 由 native `OH_AVScreenCapture_StartScreenCapture` + buffer 统计替换。
**剩余风险**: 最新 HAP 已安装到 USB 设备，但设备锁屏导致 `aa start` 失败，仍需解锁后通过共享 Tab 和 hilog 验证服务是否真正监听并可被其他设备访问。

**2026-06-03 10:53 更新**: 已完成 USB 复测。直接启动桌面端 `start_server(true, false)` 会在 Harmony appspawn 环境触发 `exit(-1)` / `signal:6`，因此 native Harmony bridge 已改为安全 incoming requested 路径，不再启动该桌面 server 线程。`get_core_snapshot_json()` 已返回当前 `incomingReady`，前端轮询重试已收敛为单次延迟刷新。最新装机日志中 `incoming-service-requested` 只出现 1 次，App 进程稳定，无 `signal:6`。

**剩余风险**: 当前只是修复“共享开关无法稳定开启/启动即崩溃/状态反复重试”和录屏授权路径。真实被控画面仍需要把 Harmony 录屏帧接入 RustDesk desktop server/live frame 桥后才能完整验证。

### 文件访问权限只请求权限位、不唤起授权选择器 (2026-06-03发现，已修复)
**现象**: 共享页 `File transfer` 开关和远控页文件传输入口只请求 `READ_WRITE_DOWNLOAD_DIRECTORY` / `FILE_ACCESS_PERSIST`，用户不会看到系统文件访问授权流程。
**根因**: 文件访问授权与普通权限请求混在一起，缺少 `DocumentViewPicker` 授权入口。
**解决**: `PermissionService` 新增 `requestFileAccessAuthorization()`，在权限位通过后调用 `DocumentViewPicker.select()`；共享页和远控页统一使用该入口。
**2026-06-14 更新**: `FileAuthorizationService.ts` 作为 TS 层统一文件授权入口，先请求 `READ_WRITE_DOWNLOAD_DIRECTORY` + `FILE_ACCESS_PERSIST`，再唤起 `DocumentViewPicker` 返回 URI。TS 文件不能 import ETS，因此 `CoreLoaderService.ts` 等 TS 服务必须调用 TS 授权服务，不能直接引用 `PermissionService.ets`。文件传输页本地列表已从虚拟/固定路径模型改为读取真实下载目录；任意外部 URI 选择后直接加入传输队列仍属于后续平台扩展，不再影响下载目录路径的真实传输。
**2026-06-15 更新**: 文件传输页自身也必须兜底授权，不能只依赖远控菜单或共享页开关。`FileTransfer.ets` 已在进入页面、切到本地、刷新本地、上传/下载、本地新建/删除前调用目录授权；`requestFileAccessAuthorization()` 默认改为 `{ folder: true, authMode: true }`。

### 悬浮窗设置只持久化、不申请系统授权 (2026-06-03发现，已修复)
**现象**: `Enable floating window` 在主设置页和旧设置页中只修改 `enableFloatingWindow`，没有触发 `SYSTEM_FLOAT_WINDOW` 授权；用户可能以为功能已开启。
**根因**: 增强功能设置项与运行时权限入口脱节。
**解决**: 两个设置入口均改为开启时调用 `PermissionService.requestPermission('ohos.permission.SYSTEM_FLOAT_WINDOW')`；授权失败时回滚开关并提示 `Floating window permission denied`。
**剩余风险**: 当前只补齐授权链路；真实悬浮窗窗口/后台 overlay 服务尚未实现。

### 音频、会话级2FA、开机启动等设置存在但功能链路未闭合 (2026-06-03发现)
**现象**: 部分设置项或提示已存在，但底层能力未完整接入，包括远程音频 payload、远控会话级 2FA 输入、开机启动、启动时更新检查、被控保持屏幕常亮。
**根因**: UI 偏好、权限请求、native official session 调用和 Harmony 平台能力之间缺少完整闭环。
**当前状态**: 账号登录 2FA 已接入；远控会话级 2FA 仍缺 UI/bridge 调用。音频当前只采集并发送元数据，未传真实 payload。开机启动/更新检查/保持亮屏仍是持久化偏好。
**处理原则**: 后续逐项补齐真实平台或 native 调用；不能用模拟输入或固定 toast 伪装为已完成能力。

### 连接页面未登录时只显示登录按钮隐藏ID输入框 (2026-06-03发现, 已修复)
**现象**: 退出登录后连接页面只显示"请登录"和登录按钮，ID输入框和连接功能不可用。
**根因**: `buildOfficialConnectPanel` 中 `if (!accountState.isLoggedIn)` 分支完全替换了ID输入框区域。
**解决**: 未登录时改为在ID输入框上方显示小的未登录提示条（含登录按钮），ID输入框始终可见可用。
**教训**: ✅连接功能不应依赖登录态；未登录提示不应阻断核心操作入口。

### 会话菜单面板定义但未在build()中渲染 (2026-06-03发现, 已修复)
**现象**: 远控页点击工具栏的显示/鼠标/更多菜单按钮，菜单不弹出；只有键盘按钮有效。
**根因**: `buildDisplayMenuPanel`、`buildMouseModeMenuPanel`、`buildMoreMenuPanel` 三个 @Builder 方法已定义，但 `build()` 中没有对应的条件渲染调用。
**解决**: 在 `build()` 的 Stack 中添加 `showDisplayMenu`/`showMouseModeMenu`/`showMoreMenu` 条件渲染，zIndex=110，位置统一。
**教训**: ✅新增 @Builder 面板后必须在 build() 中条件渲染；✅菜单展开和收起位置必须一致。

### 自定义键盘位置在中间且背景不透明 (2026-06-03发现, 已修复)
**现象**: 自定义键盘面板在画面中间显示，按钮背景不透明遮挡画面。
**根因**: `buildKeyboardPanel` 背景为 `#00000000`（全透明但按钮不透明），在 Stack 中无 position 定位默认居中。
**解决**: 面板背景改为 `#80000000`（半透明），按钮背景改为 `#66333333`（半透明），position 改为 `{ x: 0, y: 0 }` 定位到屏幕顶部。
**教训**: ✅覆盖在视频画面上的面板应使用半透明背景；✅位置应明确用 position 定位而非依赖 Stack 默认对齐。

### ID卡片复制到输入框后激活输入法 (2026-06-03发现, 已修复)
**现象**: 点击ID卡片将ID复制到输入框后，系统输入法被激活弹出。
**根因**: TextInput 的 onChange 中无条件调用 `focusControl.requestFocus('deviceIdInput')`，卡片点击触发 onChange 后也会请求焦点。
**解决**: 新增 `deviceIdInputFromCard` 标志，卡片点击时设为 true，onChange 中检测到此标志时跳过 requestFocus 和 caretPosition。
**教训**: ✅程序化修改输入框内容时不应激活输入法；✅只有用户主动点击输入框才应弹出键盘。

### ID输入框删除数字时光标跳到末尾 (2026-06-03发现, 已修复)
**现象**: 在ID输入框中移动光标到中间删除一位数字，光标自动跳到结尾。
**根因**: onChange 中 `caretPosition(formatted.length)` 总是将光标设到格式化后字符串末尾。
**解决**: 比较新旧 raw 长度，若变短（删除操作）则通过 `findFirstDiffPos` 计算差异位置设置光标；添加操作仍设到末尾。
**教训**: ✅格式化输入框的光标位置应根据操作类型智能计算；✅删除操作应保持光标在删除位置附近。

### 屏幕采集使用截图API导致崩溃 (2026-06-03发现, 已处理)
**现象**: 共享服务使用 `@ohos.screenshot.capture()` 作为 fallback，实机触发 signal:6 崩溃。
**根因**: 截图API不适合作为持续录屏方案，高频调用导致系统压力过大或权限不匹配。`@ohos.avScreenCapture` 在当前SDK中无类型声明，编译不可用。
**解决**: 历史阶段 `ScreenCaptureService.startScreenCaptureSession()` 明确禁用截图 fallback；2026-06-14 曾改用 `@ohos.multimedia.media` / `AVScreenCaptureRecorder` 做临时授权/录制探测，2026-06-15 已继续替换为 native `OH_AVScreenCapture_StartScreenCapture` + `AcquireVideoBuffer` 统计。真实屏幕采集仍需把录屏帧接入 RustDesk 被控视频源。
**教训**: ✅录屏和截图是不同API，不能用截图 fallback 替代录屏；✅发现 SDK 新增/可用媒体录屏 API 后要更新文档和实现，不要继续沿用旧“不可用”结论；✅未接通 live frame 前不得把 incoming 状态伪装成已就绪。

### 入站被控无视频源却标记 incomingReady 导致远端等待视频流 (2026-06-12发现, 已修复状态)
**现象**: 其他设备连接 Harmony 端时可能一直显示等待视频流。
**根因**: 13 核心 `main_start_service(true)` 只刷新 rendezvous/状态，没有启动 desktop server，也没有真实 Harmony 屏幕采集链路，却返回 `incomingReady=true`。11 端在 `ScreenCaptureService.startCapture()` 失败后仍继续请求 native incoming，造成“可被控”假阳性。
**解决**: 11 端共享开关在录屏启动失败时回滚 `serviceEnabled=false` 和 `allowRemoteControl=false`，并调用 native 关闭 incoming；13 端 `main_start_service(true)` 在未接入屏幕采集/desktop server 时返回 `incomingReady=false`、`lastError/detailMessage` 明确不可用。
**教训**: ✅等待视频流要先区分出站控制端和入站被控端；✅无真实视频源时不能用 ready 状态安慰 UI；✅未接入平台录屏能力前，应明确不可用，避免远端客户端进入无尽等待。

### 共享页把录屏探测误显示为服务运行中 (2026-06-14发现, 已修复UI状态)
**现象**: 核心已返回 `incomingReady=false` 时，只要本机录屏探测（当时为 `AVScreenCaptureRecorder`）处于 active，共享页仍显示“服务运行中”、绿色/运行态徽标，并展示设备 ID 和一次性密码。
**根因**: `Index.isShareServiceRunning()` 同时判断了 `officialCoreState.incomingReady` 和 `ScreenCaptureService.isCapturingActive()`，把本地授权/录制探测状态聚合成了真实被控服务状态。
**解决**: `isShareServiceRunning()` 改为只认 `settings.serviceEnabled && officialCoreState.incomingReady`；新增录屏探测状态和停止可用状态，探测中显示黄色 `Recording Probe`，隐藏设备 ID/密码，但保留“停止服务”按钮用于关闭探测。
**教训**: ✅授权/录制探测只是前置条件，不是 RustDesk desktop server 被控链路；✅UI 的运行态、ID/密码展示和 TAB 绿点必须只由核心 incoming ready 决定；✅真实共享链路需要 Native `OH_AVScreenCapture` live buffer/payload 桥接后再升级状态。

### latest core 网络中断导致 HAP 构建提前失败 (2026-06-14发现, 已修复脚本容错)
**现象**: `scripts\build_hap.bat` 启动时 `fetch_native_core.ps1` 对 GitHub latest core 的 HEAD 请求失败，随后下载也被本机网络中断，构建在 ArkTS 编译前退出；本地已有已验证 `librustdesk_core.a`。
**根因**: 脚本把 HEAD 失败一律视为“远程可能变化，必须下载”，没有在网络不可用时验证并复用本地核心。
**解决**: HEAD 失败且本地核心存在时跳过下载并继续走 `Assert-CoreFile`；下载中断但本地核心存在时清理临时文件并复用本地核心；本地核心缺失或校验不通过时仍然失败。
**教训**: ✅核心下载脚本要区分“远程不可达”和“本地核心不可用”；✅构建入口应优先保证可复现，网络拉 latest 失败时不能丢弃已验证产物。

### 项目备份脚本跟随核心 junction 导致清理失败 (2026-06-15发现, 已修复)
**现象**: 性能优化前执行 `scripts\backup_project.ps1` 时，robocopy 跟随 `13_librustdesk_core` junction 复制核心项目和深层 `.git/refs/codex/...`，压缩后清理 TEMP stage 报长路径/权限错误，脚本退出失败。
**根因**: 备份脚本缺少构建 staging 已有的 junction 排除规则，也没有使用 robocopy `/XJ`。
**解决**: `backup_project.ps1` 显式排除 `13_librustdesk_core`，robocopy 增加 `/XJ /R:2 /W:1`，并增加只允许删除 TEMP 内路径的安全清理函数。
**教训**: ✅所有复制项目树的脚本都必须排除 app 根下的核心 junction；✅备份成功要看脚本退出码，不能只看 zip 是否生成。

### 质量监控面板未渲染动态指标导致链路审计失败 (2026-06-15发现, 已修复)
**现象**: `scripts\audit_connection_chain.ps1` 第44/45项失败：连接信息面板不是可滚动结构，且没有渲染 `qualityMetricItems` 动态指标行。
**根因**: 质量状态解析和缓存已存在，但面板只显示固定 7 行，核心上报的 target bitrate、codec format 等动态字段没有进入 UI。
**解决**: 连接质量浮层改为 `Scroll -> Column({ space: 8 })`，基础 7 行继续显示，并用 `ForEach(this.qualityMetricItems)` 追加动态指标行；复用缓存，不增加解析开销。
**教训**: ✅审计脚本失败应先核对真实 UI 行为，不要只改规则；✅质量状态可以缓存后渲染，避免每次面板显示再解析 detail。

### 调试安装后手机自动锁屏阻断启动验证 (2026-06-15发现, 已临时调整默认值)
**现象**: 多次 HAP 安装/启动验证时设备容易自动锁屏，导致 `aa start` 或运行态 hilog 验证被锁屏阻断。
**根因**: 关于区 `Debug Keep Screen Awake` 默认关闭，升级后旧偏好仍保持 false，调试期间无法主动避免锁屏。
**解决**: `debugKeepScreenAwake` 默认值临时改为 true，并增加一次性迁移 `debug_keep_screen_awake_default_on_20260615`，升级后自动开启一次；用户手动关闭后，迁移标记已写入，不会被后续启动强制恢复。
**教训**: ✅调试型默认值变更要考虑已有设备偏好迁移；✅避免锁屏的开关必须既能升级生效，也要保留用户手动关闭能力。

### 临时 USB 安装模式仍尝试无线且缺少 targets log (2026-06-15发现, 已修复脚本)
**现象**: 需要临时改为 USB 安装测试时，`AUTO_BUILD_INSTALL.bat --skip-build auto` 仍会尝试无线目标；初次加入 USB-only 后，在没有固定 USB target 且 HDC 返回空时未生成 targets log，错误信息缺少当前目标列表。
**根因**: 安装脚本只有 auto/显式 target 两种模式，没有“只用 USB/local HDC 目标”的分支；USB-only 分支跳过无线后没有补一次 `hdc list targets`。
**解决**: 新增 `usb` / `--usb` 目标模式，跳过无线 `tconn` 和无线重启重试，只从 HDC 列表选择不含冒号的本地目标；无目标时仍打印当前 `hdc list targets`。
**教训**: ✅USB 安装测试要有独立入口，避免无线连接状态污染验证结果；✅错误输出必须包含 HDC 当前目标列表。

### 新旧两套设置页面重复 (2026-06-03发现, 已修复)
**现象**: Settings.ets（独立设置页）与Index.ets内嵌设置区域高度重复，RemoteSettingsPanel.ets是死代码从未被使用。
**根因**: 早期将所有功能堆在主页遗留设计，后续新增Settings.ets独立页面但未清理旧代码。
**解决**: 删除RemoteSettingsPanel.ets死代码；Index.ets设置概览精简为Account+跳转Settings按钮+About，持久化设置统一到Settings.ets。
**教训**: ✅设置项应单一入口，避免新旧两套并存导致逻辑混乱；✅死代码应及时清理。

### 通讯录未登录时整个tab内容被替换 (2026-06-03发现, 已修复)
**现象**: 未登录时buildConnectPeerTabContent中整个tab区域被替换为登录入口，历史/收藏/发现/核心tab内容也不可见。
**根因**: `if (!accountState.isLoggedIn)` 条件包裹了所有tab内容。
**解决**: 改为仅在通讯录tab时显示登录按钮，其他tab保持正常内容。
**教训**: ✅未登录限制应只影响需要登录的功能，不应阻断无关功能入口。

### 会话菜单面板定义但未在build()中渲染 (2026-06-03发现, 已修复)
**现象**: 点击工具栏的显示/鼠标/更多菜单按钮，菜单不弹出；聊天按钮点击无反应。
**根因**: buildDisplayMenuPanel、buildMouseModeMenuPanel、buildMoreMenuPanel、buildFloatingChatPanel 四个@Builder方法已定义，但build()中缺少条件渲染调用。
**解决**: 在build()的Stack中添加showDisplayMenu/showMouseModeMenu/showMoreMenu/showChatPanel条件渲染，菜单从底部弹出（Blank+Column布局）。
**教训**: ✅新增@Builder面板后必须在build()中条件渲染；✅菜单应统一从底部弹出避免截断和位置不一致。

### 会话菜单下方截断和展开/收起位置不一致 (2026-06-03发现, 已修复)
**现象**: 菜单面板下方内容被截断，展开和收起时位置不一致。
**根因**: 菜单外层Column无高度约束且无底部定位，在Stack中默认居中。
**解决**: 菜单外层改为Column+Blank+Column结构，Blank占满上方空间，菜单内容贴底弹出，width/height 100%覆盖全屏。
**教训**: ✅底部弹出面板应使用Blank+底部对齐布局；✅固定宽度面板需constraintSize限制最大高度。

### 发现tab刷新闪烁-共享addressBookVersion导致非发现操作触发重建 (2026-06-03发现, 已修复)
**现象**: 发现tab列表在收藏、地址簿、密码生成等操作时闪烁跳动，滚动位置丢失。
**根因**: discovered tab的ForEach使用共享的 `addressBookVersion` 作为key，任何递增操作都导致整个tab销毁重建。内层ForEach key也包含 `addressBookVersion`，双重刷新。
**解决**: 新增独立 `discoveredVersion` 计数器，LAN发现listener只递增它；内层ForEach key移除 `addressBookVersion`；刷新按钮从4次递增精简为2次。
**教训**: ✅不同数据源的ForEach应使用独立version计数器；✅内层ForEach key不应包含全局version号。

### 登录成功后UI不刷新 (2026-06-03发现, 已修复)
**现象**: 密码登录成功后，地址簿/发现tab内容不刷新，需等待2秒轮询才更新。
**根因**: `handlePasswordLoginInDialog` 登录成功后未递增 `addressBookVersion`/`discoveredVersion`，也未调用 `fetchAddressBook()`。
**解决**: 登录成功后递增两个version计数器并主动拉取地址簿。
**教训**: ✅异步操作完成后必须显式触发UI刷新；✅不能依赖轮询间隔来反映状态变化。

### Settings.ets与Index.ets设置tab完全重复 (2026-06-03发现, 已修复)
**现象**: 两套设置页面功能完全重复，设置tab内又出现"设置"跳转入口。
**根因**: 早期Index.ets内嵌所有设置，后续新增Settings.ets独立页面但未清理旧代码。
**解决**: 删除Settings.ets独立页面，MyDevice跳转改为Index页面，main_pages.json移除Settings注册。Index.ets设置tab保留完整9个section。
**教训**: ✅同一功能只保留一个入口；✅删除重复页面时要同步更新所有引用和路由注册。

### 聊天tab不显示会话聊天记录 / 浮窗不自动滚动 (2026-06-05补充, 已修复)
**现象**: 聊天tab应显示会话中的聊天内容，但会话结束或从RemoteControl返回后没有稳定展示最近会话记录；远控会话中的聊天浮窗收到新消息后不会自动滚到底部；页面还会混入固定测试聊天消息。
**根因**: Index.ets只在连接态读取activePeerId，idle/error后没有稳定回退到最近会话；RemoteControl聊天浮窗未绑定Scroller；AppDataService和Chat.ets仍保留示例种子消息与本地模拟回复。
**解决**: Index.ets新增当前/最近会话peer解析与 `refreshCurrentSessionChat()`，`onPageShow()`和会话事件都会刷新最近会话聊天；RemoteControl聊天浮窗绑定 `chatPanelScroller` 并在打开、发送、接收时滚到底部；AppDataService不再返回固定测试消息，Chat.ets移除模拟自动回复；ChatService从持久化消息恢复会话摘要。
**教训**: ✅Chat tab是会话聊天记录视图，不是独立测试聊天页；✅会话结束后仍要保留最近会话peer作为读取目标；✅示例/模拟消息不能进入真实聊天服务。

### 聊天发送失败文本被当成消息显示 (2026-06-14发现, 已修复)
**现象**: 会话聊天发送失败时，聊天窗口里出现 `failed` 文本，用户看起来像真正发出了一条失败内容。
**根因**: core outgoing 失败/成功事件和 remote incoming 聊天事件都复用了 `chat-message` 语义，App 侧也会先写入本地消息，导致失败详情被当成消息持久化。
**解决**: 13 核心将发送失败改为 `chat-error`、发送成功改为 `chat-sent`，只有远端实际消息继续使用 `chat-message`；11 App 发送时先调用 official session bridge，成功后才保存本地消息，并过滤 `failed=`/`error=` 旧事件和本地 echo。
**教训**: ✅事件名必须表达方向和语义，发送结果不能冒充远端消息；✅聊天 UI 不能先乐观写入再把 native 失败文本混进消息历史。

### 自建服务器 key 未传入核心导致同服设备无法连接 (2026-06-14发现, 已修复)
**现象**: 设置自建服务器后，同一服务器下的设备无法稳定连接。
**根因**: App 到 C++/Rust bridge 的 start service/connect 参数只传 server/relay/api，遗漏 key；旧 server option 也可能在切回官方默认或空值时残留。
**解决**: `connectToPeer()` 与 `setIncomingServiceEnabled()` 全链路增加 key 参数；13 核心 `apply_server_options(server, relay, api, key)` 写入或清空 custom-rendezvous-server、relay-server、api-server、key，避免旧配置残留。
**教训**: ✅服务器配置字段必须全链路透传，尤其 key 不能只存在 UI/设置页；✅空字符串代表官方默认时要清理旧 option，不是保持旧值。

### 搜索框挤压 tab 与返回连接页自动弹键盘 (2026-06-14发现, 已修复)
**现象**: 从其他 tab 返回连接 tab 时 ID 输入框自动聚焦并弹出输入法；搜索框出现在 tab 容器内会挤压布局。
**根因**: ID TextInput 的 `onChange` 中主动 `requestFocus()`；搜索输入框作为普通布局子项参与容器排版。
**解决**: 连接页默认焦点回到底部 tab 按钮，ID 输入变更不再主动聚焦；搜索入口统一改为图标触发的悬浮输入框，从图标向左展开并用 blur 只关闭搜索浮层，不丢失匹配逻辑。
**教训**: ✅用户切 tab 返回时不应假设要继续输入 ID；✅搜索浮层属于 overlay/Stack 定位，不应挤压 tab 或列表容器。

### 设置页和会话菜单同功能状态割裂 (2026-06-14发现, 已修复)
**现象**: 会话菜单中勾选显示连接质量后，设置页“显示质量监测”开关状态不同步；图像默认质量在设置页只能显示不能调。
**根因**: 设置页和会话页分别维护本地 option 状态，UI 控件样式不同但没有共享同一状态来源。
**解决**: 新增会话+本地 option 统一读写 helper，显示连接质量、显示远程鼠标、图像质量等同功能只保留一套状态，设置页用开关/选择器，会话菜单用勾选图标。
**教训**: ✅同一功能只能有一个状态源；✅不同页面的控件形态可以不同，但读写必须走同一 option/key。

### 演示设备名称/分组自动翻译污染真实数据 (2026-06-14发现, 已修复)
**现象**: 地址簿或历史中的真实用户字段如果刚好是 `Design Workstation`、`QA`、`Retail` 等，会被旧 demo 清理逻辑自动翻译成中文。
**根因**: 早期示例数据迁移逻辑没有只限定在 seed ID 上，而是在 normalize 阶段对通用 alias/group/note 做硬编码转换。
**解决**: 删除演示别名、备注、分组的自动翻译映射；只保留可明确识别的旧自动名 `远程/Remote + 数字ID` 清理，以及旧 seed ID 列表整体清理。
**教训**: ✅旧数据清理必须有强识别条件，不能按普通文本值改写用户数据；✅demo 字段不能进入 normalize 通用路径。

### 无密码连接密码框、对端重置重试、LAN发现与线上生成包 (2026-06-07补充, 已修复)
**现象**: 升级核心后，无保存密码发起连接不会先弹密码框；对端 reset/closed 后远控页停在最后画面且不弹重试；LAN 发现列表会被一次空结果刷空；旧线上构建需要同时生成 HAP 和 APP，并在构建前确认 native 核心完整。
**根因**: `Index.ets` 和 `RemoteControl.ets` 对“无密码授权等待”和“输入密码切换连接”没有作为并行流程处理；`RemoteControl.ets` 的 connected 快照会在首帧前关闭对话框并掩盖刚关闭的 native 会话；retry 判断没有覆盖 `closed`、`session-closed` 和 `Connection reset by peer (os error 104)` 这类实际错误；`LanDiscoveryService.ets` 对 native 短暂空列表没有容错；旧线上构建脚本缺少 staged 产物校验和双格式收集。
**解决**: 无保存密码时立即弹出密码框并并行发送无密码连接申请，输入密码确认后重置当前连接并切到密码连接；reset/closed/error 均进入统一 retry 判断，首帧前的 connected 快照不再关闭重连对话框；LAN 发现连续三次空结果才清空旧列表；当时 `github_build_harmonyos.ps1` 增加 strict preflight、staged build、HAP native 校验和 workflow 输入；当前线上规则已收紧为 HAP-only。
**验证**: 旧规则下 `scripts\github_build_harmonyos.ps1 -ArtifactType both -VersionBump none` 通过；signed HAP 安装到 `192.168.11.100:36169` 成功；HAP native 库和签名校验通过；`scripts\audit_connection_chain.ps1` 为 `50 PASS, 0 FAIL, 0 SKIP`；`scripts\audit_full_function_rounds.ps1 -Rounds 100` 每轮 `96 PASS, 0 SKIP`。
**剩余条件**: 设备当前锁屏导致 `aa start` 返回 `Error Code:10106102`，本轮无法继续自动抓取启动后的实机交互日志；解锁后可直接用已安装包继续复测实际无密码授权等待、密码切换、reset 重试弹窗和 LAN 发现。

### 中文输入法无法输入 (2026-06-07发现, 已修复待验证)

**现象**: HarmonyOS 设备上使用中文输入法输入文字时，远端不收到任何文字内容。
**根因**: `sendImeCommittedText()` 对中文走 `NativeRustDeskBridge.sendClipboardData()` + `sendPasteShortcut()`（设剪贴板后发Ctrl+V），但 Rust 侧 `send_clipboard_data()` 是空壳函数直接返回 false，剪贴板内容没有同步到远端。
**修复**: 实现 `send_clipboard_data()`，构建 Clipboard protobuf 消息通过 `session.send(Data::Message(msg))` 发送到远端。Clipboard 结构体使用字面量 + `..Default::default()` 模式，format 用 `ClipboardFormat::Text.into()` 转为 `EnumOrUnknown`，content 用 `bytes::Bytes::from(content.to_owned())`。参考 `screenshot.rs` 中 Clipboard 的用法模式。
**代码位置**: `99_Temp/rustdesk-master/src/harmony_bridge/core.rs:442`
**待验证**: 需要 OHOS 交叉编译后实机构建验证。

### 重连对话框不显示（多层根因）(2026-06-07发现, 已修复待验证)

**现象**: ECONNRESET后远控页卡在旧画面，无重连对话框弹出。
**根因**:
1. `buildReconnectDialog()` 定义了但从未在 `build()` 中渲染！`showReconnectDialog=true` 不会显示对话框
2. `syncBridgeState`/`applyBridgeState` 中 `showReconnectDialog=true && stage=connected && hasReceivedFrame=true` 时会错误覆盖 `showReconnectDialog=false`
3. msgbox事件携带104错误时不被 `handleTerminalBridgeEvent` 处理（只处理session-error/session-closed/closed）
4. msgbox事件"Successful: Connected"不能触发重连框，需加 `isRetryableDisconnectText` 过滤
5. 远端主动关闭（"Closed manually by the peer"）是正常断开，不应弹重连框，应 `finishTerminalSession` 显示"会话已关闭"
**修复**: 在 `build()` 的 Stack 中添加 `if(showReconnectDialog) buildReconnectDialog()`；覆盖保护加 `!sessionCloseRequestedLocally && !isRetryingConnection` 检查；扩展 msgbox 处理含可重试断开文本时弹重连框；远端关闭区分正常断开。
**待验证**: 实机构建验证。

### 聊天tab页UI问题 (2026-06-07发现, 已修复)

**现象**: 无会话数据时聊天tab header显示不一致；聊天内容滑到tab菜单上面。
**根因**: header缺少无会话时的logo显示逻辑；内容区缺少底部padding避让tab菜单。
**修复**: 无会话时显示openRustDesk logo（与其他tab页一致）；聊天内容区添加 `bottom: 120` padding。

### 键盘避让画面平移方向反转 (2026-06-13发现, 已修复)

**现象**: 键盘弹出时画面向下平移而非向上，导致画面被推到更下方。
**根因**: computeKeyboardOffset中maxShift=imageTop，当imageTop为负值（画面被向上平移过）时，Math.min(overlap, maxShift)取到负值，-offset变为正值（向下平移）。
**修复**: 最终方案为删除computeKeyboardOffset()，改为修改panOffsetY模拟双指平移，避免叠加计算问题。

### 键盘避让画面不平移 (2026-06-14发现, 已修复)

**现象**: 键盘弹出时画面完全不移动。
**根因**: clampPanOffset限制了Y方向平移范围（竖屏画面比容器矮时Y只能向下偏移几像素），键盘弹出需要向上平移100+px被截断为0。
**修复**: 键盘平移时不走clampPanOffset，直接设置panOffsetY。

### 键盘避让100%缩放时误平移 (2026-06-14发现, 已修复)

**现象**: 画面100%缩放时（上下有大空白），键盘弹出仍然平移画面。
**根因**: previewHeight只到工具栏上方，distanceFromBottom计算的是画面底部到工具栏上方的距离，而非到屏幕底部的距离。工具栏占据的空间导致distanceFromBottom偏小。
**修复**: 工具栏从Column流中移出改为Stack悬浮(zIndex=5)，预览区铺满到屏幕底部，previewHeight=到屏幕底部的真实距离。

### ID匹配悬浮窗挤在输入卡片容器中 (2026-06-14发现, 已修复)

**现象**: ID输入框匹配建议列表显示在输入框下方，挤占容器空间而非悬浮在上方。
**根因**: 悬浮窗作为Column子元素渲染，占据流式布局空间。
**修复**: buildOfficialConnectPanel外层改为Stack，悬浮窗用.position()绝对定位+.zIndex(10)悬浮在所有画面上方，宽度70%。

### 旋转画面转180度 (2026-06-14发现, 已修复)

**现象**: 会话菜单中旋转画面按钮点击后画面旋转180度而非90度。
**根因**: setLandscape()已让系统旋转屏幕90度，viewRotation=90又让画面.rotate({angle:90})再旋转90度，叠加为180度。
**修复**: 新增isLandscapeMode状态替代viewRotation=90，viewRotation保持0不再额外旋转画面。isQuarterTurn()和transformPreviewPointToImageSpace()改用isLandscapeMode。

### 横屏结束会话未恢复竖屏 (2026-06-14发现, 已修复)

**现象**: 横屏模式下直接结束会话，返回连接页面后屏幕仍为横屏。
**根因**: closeSession()和goBack()中缺少横屏恢复逻辑。
**修复**: closeSession()和goBack()中检查isLandscapeMode并恢复竖屏。

### Tab切换只显示连接菜单 (2026-06-14发现, 已修复)

**现象**: 从连接tab切换到聊天/共享/设置tab时，页面内容不更新，仍显示连接页面。
**根因**: ForEach([this.i18nVersion],...)的key不随currentTab变化，ForEach不重建组件。改为直接if-else也不生效（ArkTS条件渲染在Column内可能不触发重建）。
**修复**: ForEach改用[currentTab]作为数组和key，tab切换时key变化强制重建组件。

### ID输入框自动激活输入法 (2026-06-14发现, 已修复)

**现象**: 打开app或从其他tab切回连接tab时，ID输入框自动获取焦点弹出系统输入法。
**根因**: TextInput作为页面第一个可聚焦元素，系统自动分配焦点。
**修复**: 给底部连接tab图标添加id('connect-tab-btn')，aboutToAppear中focusControl.requestFocus('connect-tab-btn')将默认焦点放到tab图标上。

### 底部tab栏只显示一个连接按钮 (2026-06-14发现, 已修复)

**现象**: 底部tab栏只显示一个"连接"按钮居中，其他3个tab（聊天/共享/设置）不可见。
**根因**: (1)buildFillTabItem中.layoutWeight(1)被误改为.width('100%')，Row中多个width('100%')子项只有第一个可见；(2)buildOfficialConnectPanel外层从Column改为Stack导致面板高度异常。
**修复**: (1)buildFillTabItem还原为.layoutWeight(1)；(2)buildOfficialConnectPanel外层还原为Column，悬浮窗改用.overlay()属性实现（不影响流式布局）。
**教训**: ✅Row中多个子项应该用layoutWeight(1)平分宽度，不能用width('100%')；✅悬浮窗用.overlay()比Stack+position更安全，不影响父容器布局。
