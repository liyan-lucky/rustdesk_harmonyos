# 功能进度与优化方向

> 更新时间：2026-06-04 01:20。当前状态以本文、`README.md`、`CORE.md`、`CONNECTION_DEBUG_LOG.md` 为准；更早的会话内容已合并到 `BUILD_ARCHIVE.md`，只作为历史记录。每轮修改必须同步更新相关文档并进行构建验证。

## 当前状态快照

- Native core 已采用 `staticlib + CMake 直接链接`，HAP 内通过 `librustdesk_bridge.so` 调用 Rust C ABI。
- 当前已验证 native core：
  - `entry/src/main/libs/arm64/librustdesk_core.a`
  - 大小：`135,673,254` bytes
  - SHA256: `B1224DDE1CD4ECA502D7585F3CCE2D89F41B55FF075914DE6757A2F184EB649B`
- 当前已验证 HAP：
  - BuildInfo 编译时间：`2026-06-03 21:41`
  - bundle：`com.open.rundesk`
  - 无线目标：`192.168.11.100:36169`
  - 无线安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。
  - LAN发现正常工作，发现2个设备，无崩溃关键字。
- 核心已经接入真实 RustDesk session 路径，历史文档中的"仅模拟连接 / 真实网络未实现"不是当前状态。
- 上一轮实机验证曾确认控制端收到真实视频帧，截图显示远程画面，不再只是等待视频流占位。
- 最新改动已收紧重试弹窗触发条件，避免连接成功前先弹重试。
- 自定义键盘已改为会话画面顶部覆盖显示。

## 已完成

核心和构建：

- Windows native core 重编脚本已验证：`E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat`
- HAP 构建脚本已验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap`
- `run_hvigor_with_sdk_patch.js` 会自动更新 `BuildInfo.ets`。
- C++ NAPI、Rust ABI、ArkTS d.ts 已对齐。
- `coreReady=true`、NAPI 注册、HAP 安装启动均已验证。

远程连接：

- `connect_to_peer()` 接入官方 session。
- `refresh_session_video()` 调用 `request_init_msgs()` 和 `refresh_video()`。
- `harmony_next_rgba()` 从 native session 拉取 RGBA 帧。
- ArkTS 侧支持帧元数据读取、copy race 重试和 PixelMap 渲染。
- peer info 可返回 `username` 和 `hostname`，为 `用户名@设备名` 提供数据来源。

输入控制：

- mouse mask 已按官方 RustDesk 编码修正。
- wheel 使用官方 wheel type 和滚动 delta。
- native `send_mouse_input()` 已从 stub 改为转发到 active session。
- 插入 `Ctrl+Alt+Del` 不再模拟普通键盘输入；ArkTS/C++/Rust ABI 已接入 `sendCtrlAltDel()`，native 侧调用 official `Session::ctrl_alt_del()`。
- 自定义键盘上的 `Ins`、`PrtScr`、`Menu` 已补齐按键码，避免菜单上有键但点击无效。

共享页和发现：

- 共享服务默认停止。
- 停止状态下隐藏 ID 和密码。
- App 启动时不再无条件自动开启共享服务；只在 `serviceEnabled=true` 的持久化设置下恢复开启，用户关闭后重启仍保持关闭。
- 一次性迁移 `incoming_service_default_off_migration_20260602`，升级后首次启动将历史脏状态纠正为关闭。
- 启动服务后显示 ID 和一次性密码。
- 生成密码后 UI 立即更新，并同步 native local options。
- 一次性密码同步到官方临时密码：`temporary-password`，并设置 `verification-method=use-temporary-password`、`approve-mode=password`。
- wrapper 不再在 official incoming service 返回 `{}` 时把服务状态伪装成运行中。
- 发现删除记录已持久化。
- LAN 发现不再作为全局在线点的唯一依据。
- 已添加发现页手动刷新入口。
- LAN 发现保持 30 秒周期轮询，手动刷新时重置 UI 状态并立即触发一次发现。
- 通讯录添加现在要求登录。
- 文件传输权限申请已补齐 `FILE_ACCESS_PERSIST`。
- 控制端等待首帧时的 `refresh_session_video()` 强制刷新间隔已从 900ms 收紧到 450ms。

权限管理（2026-06-03 本轮修复）：

- 所有5个权限开关（Screen Capture/Input Control/File transfer/Audio Recording/Clipboard Sync）的 onChange 回调中，先同步 `updateSettings` 更新状态，再执行异步权限请求，防止 Toggle 重渲染回弹。
- 权限请求拒绝时回滚状态为 false。
- `checkScreenCapturePermissionAndToggle` 添加 try-catch 包裹 `toggleIncomingService`，失败时回滚 `serviceEnabled: false`。
- `toggleIncomingService` 中 `startCapture` 失败后现在 throw，不再继续把 `serviceEnabled` 设为 true。
- ForEach key 移除 `accountRefreshTick`，避免登录状态刷新时销毁整个 Tab 内容导致 Toggle 回调丢失。
- 调试日志从 `console.info` 改为 `hilog.info`（domain `0xA03D00`，tag `SHARE`），确保设备 hilog 可见。

核心页面：

- 核心页应显示三个状态入口：`Adapter`、`Native Module`、`Native Core`，每个入口应有详情菜单。

## 当前重点问题

- **设置页已按官方分组重排（2026-06-03）**：`Settings` Tab 对齐官方菜单顺序：账户、设置、硬件编解码、录屏、2FA、共享屏幕、显示设置、增强功能、关于。设置页 `Share Screen` 分组只保留长期偏好（LAN 发现、白名单 IP、自适应码率、允许录制会话、IP 直接访问、自动关闭不活跃会话），不再放与共享页重复的录屏/输入/文件/剪贴板运行时授权入口。
- **共享服务仍无法启动**：Screen Capture 开关点击后能弹出截屏权限对话框，授权后 `toggleIncomingService(true)` 仍失败。`startCapture()` 调用 `avScreenCapture.createAVScreenCapture()` 可能因配置或权限问题失败。需要通过 hilog 确认具体失败原因。
- 连接过程中需要继续确认：是否还会在成功前先弹重试对话框。
- 连接成功后需要确认：访问端是否稳定持续显示远程画面。
- ID 卡片第二行需要继续确认：所有来源都显示官方格式 `用户名@设备名`。
- 登录态需要继续确认：App 重启后登录状态不丢失。
- 在线状态刷新需要继续确认：离线状态不应延迟 30 秒以上。

## 2026-06-03 LAN发现逻辑修复 + 服务器配置官方样式

- **LAN发现恢复周期轮询**：`startDiscovery()` 恢复30秒周期timer，`refreshNow()` 手动刷新时重置UI状态并立即触发一次发现，未启动时自动启动周期轮询。
- **LAN发现忽略列表刷新修复**：`removeDiscoveredPeer()` 和 `refreshNow()` 先重置 `ignoredPeerIdsLoaded=false` 再加载，确保删除后立即生效；`handleDiscoveredPeer()` 不重复调用 `loadIgnoredPeerIds()`。
- **LAN发现listener不再递增addressBookVersion**：`lanDiscoveryListener` 只递增 `discoveredVersion` 和 `peerOnlineVersion`，避免发现触发非发现tab闪烁。
- **stopDiscovery主动关闭LAN**：停止时写入 `enable-lan-discovery=N`，确保native侧也停止。
- **服务器对话框改为官方样式**：标题栏右侧添加导出（`arrow-autofit-up`）和导入（`arrow-autofit-down`）图标按钮；字段布局改为小标签在上+底部细线分隔的TextInput；新增Key字段。
- **服务器配置导入/导出**：导出=JSON→Base64→字符串反转→剪贴板；导入=剪贴板→字符串反转→Base64解码→JSON解析→填充字段。兼容官方RustDesk导出格式。
- **Key字段**：`SettingsState.key`、`EffectiveServerConfig.key`、`draftKey`；应用时通过 `NativeRustDeskBridge.setLocalOption('key', ...)` 同步到native。

## 后续优化方向

- **共享服务启动**：排查 `avScreenCapture.createAVScreenCapture()` 失败原因，可能需要调整 capture config 或确认录屏权限在 HarmonyOS 商业设备上的可用性。
- HAP 体积优化：strip、LTO、减少未用 crate feature，目标 < 25MB。
- 构建流程自动化：串联 native core 构建、HAP 构建、安装、启动、日志采集。
- 音频功能验证：确认 opus/staticlib 状态后再启用远程音频。
- 会话稳定性：围绕 `session-connected`、`video-frame`、`session-closed`、retry dialog 做 USB 日志闭环。
- 文档维护：当前状态写入 `README.md`、`CORE.md` 和 `CONNECTION_DEBUG_LOG.md`；历史会话内容统一归档到 `BUILD_ARCHIVE.md`。

## 2026-06-03 最新追加

- 扫码页已改为相机扫码路径：`Scan.ets` 使用 HMS `customScan` + `XComponent` 相机预览，页面仅保留返回、重扫、复制扫到的内容。扫码结果会写入最近会话和通讯录，复制走 `ClipboardService`。
- 共享服务已完成两处修复并重新构建：ArkTS `ScreenCaptureService` 从缺失的 `avScreenCapture` 临时路径改为当前 SDK 可编译的 `@ohos.screenshot.capture()` 探测/截图；native `set_incoming_service_enabled()` 不再返回空 `{}`，会写入官方 server option 并请求 `start_server(true, false)`。
- 最新 HAP 已安装到 USB 设备 `2NX0224429035123`，但 `aa start` 被设备锁屏阻止：`Error Code:10106102`。需要设备手动解锁后继续复测共享 Tab 启动服务和 hilog。
- 服务器配置已调整为官方默认隐含配置：`AppDataService` 默认存储空字符串，运行时通过 `resolveServerConfig()` 将空 ID/Relay/API 分别回落到官方 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`。设置页不再显示官方服务器明文，显示为“官方默认”。
- 后续 10 轮全功能覆盖检查待共享启动复测后执行，范围包括连接、共享、权限、扫码、登录、通讯录、聊天、文件、显示/输入、会话命令（含发送重启/关机）等细小功能；每轮修改后立即更新文档并构建验证。
- 共享截图 fallback 已限速：`ScreenCaptureService` 默认帧率从 30fps 降到 2fps，interval 下限 500ms，避免当前 `@ohos.screenshot.capture()` 临时方案在启动恢复服务时高频调用系统截图导致页面退出或系统压力过高。
- USB 实机复测确认 `@ohos.screenshot.capture()` 会触发 `signal:6` 退出，不能作为共享截图 fallback。`ScreenCaptureService` 已改为不再调用系统截图 API，当前屏幕采集标记为不可用；共享服务启动继续走 native incoming，后续需要接入真正可用的官方录屏/被控端采集链路。

## 2026-06-03 10:53 共享服务 USB 复测结论

- 最新 HAP 构建时间：`2026-06-03 10:52`，已安装到 USB 设备 `2NX0224429035123` 并启动成功。
- App 进程稳定存在：`com.open.rundesk`，本轮日志未再出现 `signal:6`、`LastFatal` 或 RustDesk 进程 `Unexpected call: exit(-1)`。
- native `set_incoming_service_enabled()` 已调整为 Harmony 安全路径：不再调用会触发 appspawn 退出的桌面端 `start_server(true, false)`，而是写入 server option、`stop-service=N`、标记 incoming requested 并刷新 rendezvous 状态。
- native `get_core_snapshot_json()` 已补齐 `incomingReady` 快照，前端共享状态不会再因刷新快照丢失 incoming 状态。
- `Index.toggleIncomingService()` 的 15 次轮询重试已改为单次延迟刷新；USB 日志中 `incoming-service-requested` 计数从多次重复降为 `1`。
- 当前仍未接入真实屏幕采集：`ScreenCaptureService` 明确返回当前 SDK/runtime 下 screen capture API 不可用，避免再次调用会崩溃的截图 fallback。后续真正远程被控画面仍需要接入 Harmony 可用的官方录屏/采集链路。

## 2026-06-03 全功能检查第 1 轮

- 已建立初步功能清单：主入口包含连接、聊天、共享、设置；独立页面包含远控、扫码、登录/Web 登录、通讯录、聊天、文件传输、终端、我的设备、查看相机。
- 会话命令检查发现：UI 已提供 `Restart Remote`、`Lock Remote`、`Insert Ctrl+Alt+Del`，但 Harmony native bridge 中 `restart_remote_device()` 和 `lock_remote_screen()` 仍返回 `false`，按钮实际不可用。
- 已修复：`restart_remote_device()` 现在转发到 active session 的 official `Session::restart_remote_device()`；`lock_remote_screen()` 现在转发到 official `Session::lock_screen()`；两者都会写入 `session-command` 事件，便于 hilog/事件泵验证。
- `Shutdown Remote` 未实现：当前官方 RustDesk protobuf/client/session 链路中只找到 `restart_remote_device`，未找到关机对应字段或 session 方法。暂不伪装按钮，列为协议扩展缺口。

## 2026-06-03 全功能检查第 2 轮

- 远控键盘链路发现断点：`RemoteControl.ets` 与 `KeyboardToolbar.ets` 大量调用 `NativeRustDeskBridge.sendKeyboardInput()`，但 native `send_keyboard_input()` 原先直接返回 `false`。
- 已修复：`send_keyboard_input()` 现在通过 active session 的 official `Session::input_key()` 转发；新增 keyCode 到官方 `VK_*`/`Meta`/`Apps` 名称映射，并按现有 UI modifier mask 转换 Ctrl/Alt/Shift/Command。
- 远控设置链路发现断点：`applySessionOption()` 原先直接返回 `false`，导致图像质量、自定义码率/FPS、录制、截图、block-input、view-only 等 UI 操作只会落到本地缓存或排队提示。
- 已修复：`apply_session_option()` 现在将 `image-quality`、`custom-image-quality`、`custom-fps`、`record-session`、`take-screenshot` 和普通 session option 转发到 official active session，并写入 `session-option` 事件。
- 明确未伪装实现：`switch-sides` 在当前 OHOS 编译路径没有可用 official 实现；`session-action=shutdown` 没有官方协议字段。两者继续作为后续协议/平台扩展缺口记录。

## 2026-06-03 全功能检查第 3 轮

- 共享页文件权限发现断点：`File transfer` 开关与远控页“File Transfer”菜单原先只请求 `READ_WRITE_DOWNLOAD_DIRECTORY` / `FILE_ACCESS_PERSIST` 权限位，没有唤起系统文件访问授权。
- 已修复：`PermissionService.requestFileAccessAuthorization()` 现在先请求文件权限，再通过 `DocumentViewPicker.select()` 唤起系统文件选择/授权流程；共享页和远控页文件传输入口统一调用该方法。
- 已修正权限说明：`CAMERA` 权限用途从“screen capture and sharing”改为“QR code scanning”，避免扫码授权被误归类为录屏/共享。
- 设置页冲突清理：旧 `Settings.ets` 的 `Allow incoming sessions` 运行时开关已移除，共享服务启停只保留在共享 Tab，避免设置页和共享页同时修改同一个运行状态。
- 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:10`。仍存在 HMS `customScan` syscap 警告和既有 ArkTS 警告，非本轮新增失败。

## 2026-06-03 全功能检查第 4 轮

- 服务器配置一致性检查：`AppDataService` 的空值回落语义已覆盖主入口、native bridge、账号服务和 EntryAbility；本轮继续补齐底层 `HttpClient.setApiServer('')` 的回落保护，空 API server 会自动使用官方默认有效值。
- Web 登录链路发现断点：`WebLoginPage` 直接持有 `HttpClient` 单例轮询 OAuth code，页面出现时没有同步当前设置里的有效 API server。已修复为 `aboutToAppear()` 先调用 `accountService.syncApiServerFromSettings()`。
- 旧设置页分组调整：`Settings.ets` 可从 `MyDevice` 进入，原先仍是旧结构。已调整为账号、Settings、Theme、Hardware Codec、Screen Recording、2FA、Share Screen、Display、Enhanced Features、About 的顺序。
- 设置页重复权限入口清理：旧设置页中 `Enable audio`、`Enable clipboard` 等共享运行授权项已移除，音频/剪贴板运行权限继续由共享 Tab 负责。
- 缺少项补齐：旧设置页补上 `Use WebSocket`、`Enable UDP Hole Punching`、`Enable IPv6 P2P Connection`、`2FA`、共享屏幕长期偏好、增强功能里的更新/终端扩展键/悬浮窗/保持屏幕开启等选项。
- 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:15`。

## 2026-06-03 全功能检查第 5 轮

- 扫码结果导入发现过宽：原逻辑会把任意二维码文本里的数字全部拼成设备 ID，并写入最近会话/通讯录。已收紧为仅当数字 ID 长度在 `6..18` 范围内才导入；复制扫码内容仍支持任意文本。
- LAN 发现删除发现设备发现断点：`ignoredPeerIds` 已有持久化字段，但发现流程没有加载/过滤，删除后的设备可能在下一次刷新重新出现。已修复为启动/手动刷新/处理发现结果时加载忽略列表，删除发现设备时写入忽略列表。
- 在线状态同步发现断点：`queryOnlines` 结果原先只更新 `peerOnlineMap`，没有同步最近会话、通讯录、发现列表里的 `online` 字段，在线筛选可能显示旧值。已修复为在线/离线结果同时更新三类列表数据。
- LAN TTL 保留：LAN 刚发现的设备在 TTL 内仍不会被官方 onlines 的离线结果立即打成离线，避免局域网发现与公网在线查询互相覆盖。
- 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:18`。

## 2026-06-03 全功能检查第 6 轮

- 聊天链路发现断点：`ChatService` 已调用 `OfficialSessionTransport.sendChatMessage()`，但 native `send_chat_message()` 原先直接返回 `false`。已修复为转发到 active session 的 official `Session::send_chat()`，并写入 `chat-message` 事件。
- 文件传输链路发现断点：`read_remote_directory()`、`create_remote_directory()`、`delete_remote_path()`、`start_file_transfer()` 原先均为 `false` stub。已接入 official `FileManager`/`Session` 方法，远端读目录、建目录、删除、启动传输现在会向 active session 发送对应 RustDesk 文件动作。
- 文件传输请求链路：`send_file_transfer_request()` 现在写入 `file-transfer-request` 事件并在有 active session 时返回 true，避免 UI 请求被静默判定为失败。
- 剪贴板链路保留风险：`send_clipboard_data()` 仍未伪装实现。当前没有找到 Harmony 路径下可安全调用的 official “设置远端剪贴板文本”公开 session 方法；不会用 `input_string()` 冒充剪贴板发送，避免把剪贴板内容直接打到远端当前输入焦点。
- native 构建验证：`build_bridge_now.bat` 已通过，`librustdesk_core.a` 已复制到 `entry/src/main/libs/arm64/`。
- HAP 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:26`。

## 2026-06-03 全功能检查第 7 轮

- 远控显示链路复查：`refresh_session_video()` 已通过 active session 调用 `request_init_msgs()` 与 `refresh_video()`；`on_rgba()` 会将真实帧写入 `latest_video_frame`，ArkTS 通过 `getLatestVideoFrameMetadata()` / `copyLatestVideoFrame()` 拉取帧。
- 鼠标触控链路复查：`send_mouse_input()` 已通过 active session `send_mouse()` 转发；远控页触摸映射会按显示缩放和远端显示原点换算坐标，并支持长按右键、滚轮、模拟鼠标/触控模式。
- 特殊键链路复查：Ctrl+Alt+Del、Restart Remote、Lock Remote、快捷键盘均已在第 1/2 轮接入 native official session。
- 构建警告修复：`RemoteControl.ets` 中 `buildImeProxyInput()` 重复 `@Builder` 装饰器已移除，HAP 构建中该警告不再出现。
- 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:28`。

## 2026-06-03 全功能检查第 8 轮

- 权限/增强功能复查：主设置页与旧设置页的 `Enable floating window` 原先只写入本地设置，不会触发 `SYSTEM_FLOAT_WINDOW` 授权。已修复为开启时主动请求悬浮窗权限，拒绝时自动回滚开关并提示 `Floating window permission denied`。
- 账号 2FA 复查：密码登录链路已支持 `email_check` 与 `tfa_check`，`LoginPage` 会显示验证码输入并调用 `AccountService.verifyEmail()` / `verifyTfa()`；账号登录 2FA 可用。
- 会话级 2FA 缺口：官方 `ui_session_interface.rs` 存在 `send2fa(code, trust_this_device)`，但 HarmonyOS 外壳目前没有远控会话级 2FA 输入 UI/bridge 调用；`OfficialSessionTextFormatter` 仍提示远端要求 2FA 时无法输入。该项列为后续会话认证完善项。
- 音频链路复查：`AudioService` 能请求麦克风并采集 PCM，但当前 ArkTS 只向 native 发送 `SessionAudioFrame` 元数据，真实音频 payload 没有跨 NAPI 传入；native `send_audio_frame_metadata()` 仍未转发官方音频流。音频开关目前不应视为完整远程音频。
- 录屏/共享链路复查：为避免 USB 实机 `signal:6`，`ScreenCaptureService` 仍明确禁用当前 SDK 下不可用/会崩溃的截图 fallback；共享服务可稳定进入 incoming requested 状态，但真实被控画面仍依赖后续官方 Harmony 录屏/采集链路。
- 开机启动、启动检查更新、被控保持亮屏复查：相关设置当前仅持久化偏好，未发现 boot extension、真实更新检查请求或窗口 keep-screen-on 调用链路。已记录为平台集成缺口，避免误判为已实现功能。
- 构建验证：`node scripts\run_hvigor_with_sdk_patch.js assembleHap` 已通过，构建时间 `2026-06-03 11:34`。

## 2026-06-03 全功能检查第 9 轮

- USB 安装验证：`entry-default-signed.hap` 已安装到 USB 设备 `2NX0224429035123`，安装结果 `install bundle successfully`。
- USB 启动验证：`aa start -a EntryAbility -b com.open.rundesk` 返回 `start ability successfully`，App 进程 `com.open.rundesk` 稳定存在，PID `32275`。
- 启动日志验证：过滤 hilog 后，`LastFatal: 0`、`signal:6: 0`、`Unexpected call: 0`、`exit(-1): 0`，未复现此前共享/截图 fallback 相关崩溃。
- 运行状态验证：日志出现 `coreReady` 与 `query-onlines-result`，说明 native core 已可用并完成在线状态查询；官方 API `logout` 返回 400 属于旧账号/token 退出请求失败，不影响启动稳定性。
- 共享日志说明：本轮为安装启动烟测，未通过 UI 手动点击共享开关，因此 `incoming-service-requested: 0`；共享按钮交互仍以 10:53 USB 复测结论为准。

## 2026-06-03 全功能检查第 10 轮

- 10 轮覆盖已完成：本轮次覆盖连接、共享、设置、扫码、账号登录、Web 登录、通讯录/LAN 发现、聊天、文件传输、远控显示/输入、会话命令、权限、增强功能、构建与 USB 启动烟测。
- 已落地修复汇总：远端重启/锁屏命令、键盘输入、会话选项、文件访问授权、设置页冲突菜单、旧设置分组、服务器默认隐含配置、扫码相机页、扫码导入校验、LAN 忽略列表、在线状态同步、聊天发送、远程文件目录/创建/删除/传输请求、重复 `@Builder` 警告、悬浮窗授权回滚。
- 明确未伪装完成的缺口：远端关机命令、远程剪贴板主动设置、真实远程音频 payload、真实 Harmony 屏幕采集、远控会话级 2FA 输入、开机启动、启动时真实更新检查、被控保持亮屏、真实悬浮窗 overlay 服务仍需后续平台/native 能力接入。
- 构建与设备验证：最后一次 HAP 构建通过，构建时间 `2026-06-03 11:34`；USB 设备 `2NX0224429035123` 安装启动成功，PID `32275` 稳定，崩溃关键字为 0。
- Git 状态说明：当前 Git 根为 `E:\Visual_Studio_Code\11_Rustdesk`，`rustdesk_harmonyos/` 整体在该仓库视角下仍是未跟踪目录，因此 `git diff` 不显示逐文件差异；本次变更以项目文件和构建产物为准。

## 2026-06-03 UI 交互修复轮

- **连接页面未登录状态修复**：退出登录后连接页面不再只显示登录按钮，改为在ID输入框上方显示小的未登录提示条（含登录按钮），ID输入框和连接功能始终可用。通讯录页面的未登录提示仅在通讯录内部显示，不影响连接主界面。
- **会话菜单渲染修复**：`buildDisplayMenuPanel`、`buildMouseModeMenuPanel`、`buildMoreMenuPanel` 三个菜单面板原先只定义未在 `build()` 中条件渲染，导致点击工具栏菜单按钮无反应。已在 `build()` 的 Stack 中添加 `showDisplayMenu`/`showMouseModeMenu`/`showMoreMenu` 条件渲染，zIndex=110，统一从底部工具栏上方弹出，展开和收起位置一致。
- **自定义键盘样式修复**：`buildKeyboardPanel` 背景从全透明 `#00000000` 改为半透明 `#80000000`；`buildKeyBtn` 和 `buildStickyKeyBtn` 按钮背景从 `theme_TOOLBAR_BG` 改为半透明 `#66333333`；键盘面板位置从中间改为屏幕顶部（`position({ x: 0, y: 0 })`）。
- **ID卡片复制不激活输入法**：新增 `deviceIdInputFromCard` 标志，ID卡片点击复制到输入框时设为 true，TextInput 的 onChange 中检测到此标志时跳过 `focusControl.requestFocus` 和 `caretPosition`，避免激活输入法。只有用户直接点击输入框时才激活输入法。
- **ID输入框光标位置记忆**：删除数字时光标不再自动跳到结尾。新增 `estimateCaretInRaw` 和 `rawPosToFormattedPos` 方法，删除操作时通过差异位置估算raw中光标位置，再映射到格式化后位置设置光标。
- **屏幕采集状态确认**：`ScreenCaptureService.startScreenCaptureSession` 保持明确 throw 标记当前SDK/runtime下screen capture API不可用。`@ohos.avScreenCapture` 在当前SDK中无类型声明不可编译，`@ohos.screenshot.capture()` 会触发signal:6崩溃。真实屏幕采集需后续接入Harmony可用的官方录屏/采集链路。

## 2026-06-03 UI交互修复第2轮

- **新旧设置合并去重**：删除死代码 `RemoteSettingsPanel.ets`（从未被import，功能已被RemoteControl内联替代）。删除 `Settings.ets` 独立页面（与Index.ets设置tab完全重复），MyDevice跳转改为Index页面，main_pages.json移除Settings注册。Index.ets设置tab保留完整9个section（Account/Server/Hardware/Recording/2FA/ShareScreen/Display/Enhanced/About）。
- **通讯录未登录状态**：未登录时只在通讯录tab内显示登录按钮+提示，其他tab（历史、收藏、发现、核心）保持正常内容。`requireLoginForAddressBook` 恢复弹登录对话框。
- **会话菜单布局修复**：菜单面板（显示/鼠标/更多）改为底部弹出（Blank+Column），解决下方截断和展开/收起位置不一致问题。
- **聊天面板渲染修复**：`buildFloatingChatPanel()` 原先只定义未在build()中条件渲染，添加 `showChatPanel` 条件渲染，聊天按钮点击可正常弹出聊天面板。
- **ID输入框光标记忆优化**：从简单的 `findFirstDiffPos` 改为更可靠的 `estimateCaretInRaw` + `rawPosToFormattedPos` 双方法映射，准确将raw中光标位置映射到格式化后位置。
- **菜单箭头图标统一**：Index.ets的 `arrow_menu.svg` 和 CommonComponents.ets的 `arrow.svg` 全部替换为 `arrow-forward-ios.svg`。

## 2026-06-03 发现/登录刷新修复 + 聊天tab完善

- **发现tab刷新闪烁修复**：新增 `discoveredVersion` 独立@State计数器，LAN发现listener只递增它而非共享的 `addressBookVersion`，避免非发现操作触发发现tab销毁重建。
- **内层ForEach key优化**：`buildConnectAddressCollectionCard` 内层ForEach key移除 `addressBookVersion`，改为仅用条目自身标识 `${entry.id}-${entry.group}-${entry.favorite}`，避免每次版本递增所有条目销毁重建。
- **登录成功后UI刷新**：`handlePasswordLoginInDialog` 登录成功后递增 `addressBookVersion` + `discoveredVersion`，并调用 `fetchAddressBook()` 主动拉取地址簿，解决登录后UI不刷新问题。
- **刷新按钮多重递增精简**：`refreshCurrentConnectTab` 发现tab刷新从4次setTimeout递增（250/1000/2500ms）精简为2次（立即+2500ms），使用 `discoveredVersion` 而非 `addressBookVersion`。
- **聊天tab显示会话记录**：连接成功时加载 `chatMessages = chatService.getMessages(peerId)`；新增 `hasHadSession` + `lastSessionPeerId` 标志；会话结束后聊天tab显示聊天记录或"No messages yet."，只有从未连接过才显示"No active connection"；未连接时不再清空chatMessages；连接新目标时不再清空旧目标记录。

## 2026-06-03 LAN发现时序与消失设备清理修复

- **discoverOnce延迟加载**：`discoverOnce()` 不再立即调用 `loadDiscoveredPeers()`，改为延迟1.5秒和3.5秒两次调用，避免 `discoverLanPeers()` 触发异步发现后立即读取旧缓存导致"清空→闪回旧数据"闪烁。
- **refreshNow不再清空UI**：`refreshNow()` 移除 `resetCurrentDiscoveryResults()` 调用，不再先清空所有数据再等延迟加载，改为直接触发发现等新数据做差异替换，避免手动刷新时卡片短暂消失。
- **refreshNow清除忽略列表**：`refreshNow()` 清除 `ignoredPeerIds` 并持久化空列表，手动刷新意味着用户想重新看到所有设备，之前删除的设备应重新出现。
- **消失设备差异清理**：`loadDiscoveredPeers()` 新增 `nativePeerIds` 集合，遍历native返回结果后对比 `discoveredPeers` Map，移除native不再返回的设备并同步 `AppDataService.removeDiscoveredDevice()`，解决LAN设备下线后仍显示在列表的问题。
- **忽略列表统一检查**：忽略列表加载检查统一在 `loadDiscoveredPeers()` 入口处理，`handleDiscoveredPeer()` 不再重复调用 `loadIgnoredPeerIds()`，避免分散检查导致遗漏。
- **构建验证**：HAP构建通过，构建时间 `2026-06-03 22:15`；无线设备 `192.168.11.100:36169` 安装启动成功，LAN发现正常工作，发现2个设备，无崩溃关键字，手动刷新无卡片消失。

## 2026-06-03 刷新图标替换

- **刷新图标统一为refresh.svg+ArkTS旋转动画**：删除 `autorenew.svg` 和 `arrow-rotate.svg`（含SVG内嵌animateTransform），静态和动态刷新统一使用 `refresh.svg`。刷新中通过 `setInterval` 每40ms递增 `@State angle` 18度驱动 `rotate({ z: 1, angle })` 持续旋转，刷新完成后 `clearInterval` + 归零角度停止。Index.ets 和 FileTransfer.ets 均已改用此方案。

## 2026-06-03 通讯录/账户页登录交互优化

- **通讯录未登录提示**：提示文字从"公共服务器外连前需要登录"改为"登录后可查看和同步通讯录"（`Login to view address book`），更直观说明登录目的。
- **账户tab未登录简化**：未登录时不再显示账户信息卡片+`buildOfficialLoginEntry`，改为与通讯录页一致的简洁布局：提示文字"登录后可查看账户详情"（`Login to view account`）+ 登录按钮。
- **账户tab已登录简化**：删掉"打开设置"按钮（`Open Settings`），只保留"退出登录"（`Sign out`），按钮尺寸（156×MEDIUM）与登录按钮一致，降低操作复杂度。
- **i18n新增**：`Login to view address book`（中：登录后可查看和同步通讯录 / 英：Login to view and sync address book）、`Login to view account`（中：登录后可查看账户详情 / 英：Login to view account details）。

## 2026-06-03 设置页账户菜单精简

- **已登录**：单行菜单，中间显示用户名，右侧 `logout.svg` 图标，点击退出登录。删掉"提供方"信息行和"退出登录"文字行。
- **未登录**：单行菜单，中间显示"登录"文字（次要色），右侧 `login.svg` 图标，点击打开登录对话框。
- 整个账户菜单从3行收敛为1行，降低视觉噪音。

## 2026-06-03 账户tab工具栏精简 + 图标主题修复

- **账户tab隐藏搜索/排序/刷新**：`currentConnectTab === 'account'` 时隐藏搜索图标、排序图标和刷新图标，账户页不需要这些功能。
- **账户名显示"账户名"字眼**：设置页账户菜单已登录时，用户名前显示"账户名"标签（`Account Name`，中：账户名）。
- **login/logout图标主题匹配**：`login.svg` 和 `logout.svg` 添加 `fill="#000000"` 属性，设置页改用 `fillColor(theme_TEXT_TERTIARY)` 替代 `colorFilter`（fill格式图标必须用fillColor）。
- **arrow-forward-ios图标主题匹配**：该SVG为fill格式（`<polygon fill="#000000">`），Index.ets和CommonComponents.ets中所有使用处从 `colorFilter(createStrokeIconColorFilter())` 改为 `fillColor(theme_TEXT_TERTIARY)`，修复暗色主题下箭头不可见问题。

## 2026-06-03 共享页/历史页/平台图标修复

- **共享页面去掉服务状态行**：MyDevice.ets中删除 `MenuInfoItem({ label: 'Status' })` 行。
- **平台图标放大**：历史页面、聊天会话、发现/收藏/通讯录ID卡片中的平台图标从18x18放大到22x22（容器仍为40x40）。
- **非Win品牌图标主题匹配**：`android.svg` 从 `fill="currentColor"` 改为 `fill="#000000"`；`mac.svg` 从 `stroke="black"` 改为 `stroke="#000000"`；`linux.svg` 添加 `fill="#000000"`。colorFilter(BlendMode.SRC_IN)对fill和stroke格式均有效，修复暗色主题下非Win图标不可见问题。
- **平台图标统一重画+放大**：android/mac/linux全部重画为stroke格式、viewBox 24x24，与win.svg显示样式一致。图标尺寸从22x22放大到26x26。所有平台图标统一使用 `colorFilter(createStrokeIconColorFilter(theme_ACCENT))` 着色。

## 2026-06-03 聊天tab/显示设置同步修复

- **聊天tab删除输入框和发送按钮**：聊天页面仅用于显示消息记录，不支持输入。删除 `TextInput` + `Button('Send')` 及 `sendTabChatMessage()` 调用。
- **显示设置与远程会话菜单功能同步**：显示设置对话框中的toggle选项（Show Remote Cursor、View Mode、Mute、Disable Clipboard等）从 `this.settings` 绑定改为通过 `NativeRustDeskBridge.getLocalOption`/`setLocalOption` 读写native选项，与RemoteControl中的 `applyToggleOption` 使用相同的key和存储，确保两处修改同一功能时状态一致。新增 `resolveLocalToggleOption()` 辅助方法。修复"Show Remote Cursor"错误绑定到 `enableClipboard` 的问题。

## 2026-06-04 会话界面UI优化

- **项目备份**：修改前备份到 `backup_20260604_001655`。
- **聊天窗口优化**：去掉全屏遮罩层（`#40000000`背景+点击关闭），窗口宽度从340缩至272（缩小20%），背景改为半透（`#B0000000`），保留拖拽和阴影。
- **自定义键盘优化**：键盘背景从半透黑（`#80000000`）改为全透（`Color.Transparent`），按键背景从`#66333333`改为`#55444444`（更半透），sticky按键非激活态同步修改。
- **工具菜单底部避让**：显示菜单、触摸菜单、三点菜单容器添加 `padding({ bottom: 56 })` 避让底部工具栏。
- **菜单宽度统一**：显示菜单从320缩至280，触摸菜单从220统一到280，三点菜单保持280，三个菜单统一宽度。

## 2026-06-04 设置图标+排序/刷新图标+共享菜单修复

- **共享tab删除服务状态菜单**：MyDevice.ets删除 `buildServiceCard()` 调用，共享页不再显示服务状态卡片。
- **设置菜单所有选项添加图标+主题匹配**：从Lucide Icons获取9个stroke格式SVG图标（settings_person/settings_server/settings_proxy/settings_cpu/settings_video/settings_shield/settings_monitor/settings_tune/settings_info），全部 `stroke="#000000"`。`buildSettingsSectionLabel` 和 `buildSettingsLinkRow` 新增icon参数，9个section分别配置对应图标，统一使用 `colorFilter(createStrokeIconColorFilter(theme_TEXT_TERTIARY))` 着色。
- **发现页排序/刷新图标主题匹配修复**：`Sorting_order.svg` 从 `currentColor` 改为 `stroke="#000000"`，代码从 `fillColor` 改为 `colorFilter(createStrokeIconColorFilter())`。`refresh.svg` 确认stroke格式正确，代码使用colorFilter。两个图标暗色主题下可见性修复。
- **构建验证**：HAP构建通过，构建时间 `2026-06-04 01:14`；无线设备 `192.168.11.100:36169` 安装成功。
- **项目备份移动**：`backup_20260604_001655` 从项目目录移动到 `E:\Visual_Studio_Code\99_Temp\backup_20260604_001655`。
