# 功能进度与优化方向

> 更新时间：2026-06-13 08:45。当前状态以本文、`README.md`、`CORE.md`、`CONNECTION_DEBUG_LOG.md` 为准；更早的会话内容已合并到 `BUILD_ARCHIVE.md`，只作为历史记录。每轮修改必须同步更新相关文档并进行构建验证。

## 当前状态快照

- 2026-06-06 项目结构已提升到根目录：`11_Rustdesk_harmonyos/` 直接作为 Git 根和 App 项目根，历史内层 `rustdesk_harmonyos/` 只作为本地坏缓存壳忽略；`99_Temp/` 按当前工作区位置匹配，不依赖固定盘符。
- HAP 签名材料已放入 `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing/`，`build-profile.json5` 使用相对路径引用；签名 profile 校验通过，bundleName 为 `com.open.rundesk`。
- HAP 构建先复制干净副本到 `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`，再把 Hvigor 日志、HAP 输出、Native `.cxx` 中间目录放到 `%VSCODE_ROOT%\99_Temp`；当前本地 BuildInfo 编译时间 `2026-06-13 08:18`，App 显示版本 `0.13.40`，versionCode `1000071`。
- 2026-06-12 线上 Linux 构建脚本已改为 HAP-only：`.github/workflows/build-harmonyos.yml` 和 `.github/workflows/build-harmonyos-linux.yml` 只构建/上传 `.hap`，不再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。
- 线上构建依赖已拆分为 SDK 包和 Hvigor/Command Line Tools 剩余文件包：
  - `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
  - `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
- Linux CI 已显式检查并加载 `openharmony/previewer/common/bin/libcjson.so`、`libsec_shared.so` 和 Ark ets-loader 的 `libsec_shared.so`，避免 Hvigor/previewer 动态库缺失。
- 最新 100 轮功能逻辑审查已完成，审查明细见 `docs/FUNCTION_LOGIC_AUDIT_2026-06-06.md`；当前结论为出站远控链路最成熟，入站被控、文件传输、终端、音频发送和远端剪贴板仍需补齐 native 回调或隐藏未实现入口。
- 当前 U 盘存在历史生成目录权限残留：项目内 `.hvigor/`、`entry/build/`、`entry/.cxx/` 和旧内层 `rustdesk_harmonyos/` 空缓存壳无法可靠删除。日常构建使用 staged copy，日常全量重建清理外部 build/stage 产物并保留 `harmonyos_cache`，避免 Hvigor 内置 clean 访问这些坏目录；深度清理 cache 需显式使用 `-IncludeHvigorCache`。

- 扫码页已新增相册图片二维码识别入口，使用 `photo.svg` 图标；相机扫码和相册识别共用同一结果处理路径。
- 服务器配置导入导出格式抽到 `ServerConfigCodec.ets`：设置页导入/导出会弹出成功提示；扫码结果如果符合服务器导入文本格式，会直接导入服务器配置并保存。
- 构建脚本版本逻辑已调整：增量构建自增版本号右侧数字，全量构建自增中间数字并重置右侧数字，`AppScope/app.json5` 与 `BuildInfo.ets` 同步更新。
- 聊天Tab已按会话内容显示：优先当前会话，返回主页或会话结束后回退最近一次会话；peer 信息只替换聊天Tab头部区域，不再替换连接Tab，并保留右侧 `group.svg` 图标。远控会话聊天浮窗绑定 Scroller，并在打开、发送、接收消息后自动滚动到新消息。
- 固定测试聊天消息和本地模拟自动回复已移除，持久化聊天消息加载时会重建 `ChatSession` 摘要。
- 项目根 `README.md` 已作为线上默认介绍，标题为 `项目设计要求`，内容为完整设计要求（原 `docs/DESIGN.md` 已合并到根 README.md）。

- Native core 已采用 `staticlib + CMake 直接链接`，HAP 内通过 `librustdesk_bridge.so` 调用 Rust C ABI。
- 当前已验证 native core：
  - `entry/src/main/libs/arm64/librustdesk_core.a`
  - 最新 native core 已从 GitHub Releases 下载：
  - `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
  - release：`core-70`
  - 大小：`131,263,476` bytes (`125.18 MB`)
  - mtime/compile time：`2026-06-13 08:18`
  - FNV-1a 1MB：`317b77b6`
  - SHA256: `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- 当前已验证 HAP：
  - 本地 BuildInfo 编译时间：`2026-06-13 08:18`
  - 本地 App 显示版本：`0.13.40`
  - 本地 versionCode：`1000071`
  - bundle：`com.open.rundesk`
  - 最新线上 release：`harmonyos-20260612-065038`
  - signed HAP：`entry-default-signed.hap`，`18,746,430` bytes
  - 2026-06-09 无线安装启动成功，hilog 确认 `coreReady=true`、`adapter=official-native`，无崩溃。
  - 2026-06-09 官方一致性修复后实机验证：HAP 安装启动成功，`coreReady=true`，Bridge 在线查询正常（onlines: 2），远程控制连接建立（加密中继），handshake 诊断正常（fingerprint、connection-type、quality-status），核心详情页新增属性（桥接函数数、NAPI注册数、核心版本、设备ID、指纹）已集成。
- 核心已经接入真实 RustDesk session 路径，历史文档中的"仅模拟连接 / 真实网络未实现"不是当前状态。
- 上一轮实机验证曾确认控制端收到真实视频帧，截图显示远程画面，不再只是等待视频流占位。
- 2026-06-12 等待视频流复查：出站控制端仍有真实 `on_rgba -> video-frame` 路径；入站被控端因 Harmony `ScreenCaptureService`/desktop server 未接入，不能再对外标记 `incomingReady=true`。11 端共享开关已在录屏失败时回滚，13 端核心 `main_start_service(true)` 已改为返回 `incomingReady=false` 和明确错误，避免其他设备连接后一直等待视频流。
- 2026-06-13 core-70 复测：13 项目 run `27459455573` 成功发布 `core-70`；11 项目下载后 HAP 构建、native/signature 校验和无线安装通过。设备锁屏导致 `aa start` 返回 `Error Code:10106102`，App 未运行，本轮抓到的 hilog 没有 `coreReady`/`video-frame` 证据；视频流需解锁后继续复测。
- 最新改动已收紧重试弹窗触发条件，并二次优化远控画面刷新链路：frameId 只接受递增帧、native RGBA 槽在 copy 后立即推进、PixelMap 渲染有超时和代次保护。
- 最新 native 修复已把官方 `close_success()` 从“会话关闭”改回“连接成功提示关闭”语义，避免首帧后误报 `session-closed`。
- 最新核心页改动已把 Native Core 详情时间/大小/hash 切换为 `CoreBuildInfo.ets` 中的 `librustdesk_core.a` 文件信息，并修正 staticlib 模式下 `Native Module` 异常、`Native Core` 误显示停止的问题。
- 自定义键盘已改为会话画面顶部覆盖显示。

## 2026-06-12 Linux 在线构建结论

- `build-harmonyos.yml` 当前 Linux 方案可行；按新要求已改为 HAP-only，线上脚本和 release 只保留 `.hap`。
- 成功修复链路：
  - SDK 包补齐 `openharmony/previewer/common/bin/libcjson.so`、previewer `libsec_shared.so` 和 ets-loader `libsec_shared.so`。
  - workflow 的 `LD_LIBRARY_PATH` 加入 previewer、ets-loader、toolchains 和 hms toolchains lib。
  - ArkTS `window.AvoidAreaType.TYPE_INPUT` 改为当前 SDK 可用的 `window.AvoidAreaType.TYPE_KEYBOARD`。
  - 新规则：不再生成 APP，不再生成 `.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。
- 当前 GitHub secrets/vars 关键值：
  - `RUSTDESK_CORE_URL` 可留空，默认使用 `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
  - `RUSTDESK_CORE_SHA256` 默认留空以跟随 latest；需要固定核心时再设置。
- 已删除失败草稿 release `harmonyos-20260612-015538`；当前最新 App release 为 `harmonyos-20260612-065038`，`harmonyos-20260612-020111` 仅作为历史成功 release 保留。
- 2026-06-13 线上 App 状态：最新 release 是 `harmonyos-20260612-065038`；最新 workflow run `27443845710` 是旧提交 `0000da6` 的失败 run，尚未包含本地已验证的 core-70/HAP-only/staged signing 修正。发布前需推送并重跑 workflow。

## 已完成

核心和构建：

- Windows native core 重编脚本已验证：`%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat`
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
- 最新 HAP 已安装到 USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%`，但 `aa start` 被设备锁屏阻止：`Error Code:10106102`。需要设备手动解锁后继续复测共享 Tab 启动服务和 hilog。
- 服务器配置已调整为官方默认隐含配置：`AppDataService` 默认存储空字符串，运行时通过 `resolveServerConfig()` 将空 ID/Relay/API 分别回落到官方 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`。设置页不再显示官方服务器明文，显示为“官方默认”。
- 后续 10 轮全功能覆盖检查待共享启动复测后执行，范围包括连接、共享、权限、扫码、登录、通讯录、聊天、文件、显示/输入、会话命令（含发送重启/关机）等细小功能；每轮修改后立即更新文档并构建验证。
- 共享截图 fallback 已限速：`ScreenCaptureService` 默认帧率从 30fps 降到 2fps，interval 下限 500ms，避免当前 `@ohos.screenshot.capture()` 临时方案在启动恢复服务时高频调用系统截图导致页面退出或系统压力过高。
- USB 实机复测确认 `@ohos.screenshot.capture()` 会触发 `signal:6` 退出，不能作为共享截图 fallback。`ScreenCaptureService` 已改为不再调用系统截图 API，当前屏幕采集标记为不可用；共享服务启动继续走 native incoming，后续需要接入真正可用的官方录屏/被控端采集链路。

## 2026-06-03 10:53 共享服务 USB 复测结论

- 最新 HAP 构建时间：`2026-06-03 10:52`，已安装到 USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%` 并启动成功。
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

- USB 安装验证：`entry-default-signed.hap` 已安装到 USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%`，安装结果 `install bundle successfully`。
- USB 启动验证：`aa start -a EntryAbility -b com.open.rundesk` 返回 `start ability successfully`，App 进程 `com.open.rundesk` 稳定存在，PID `32275`。
- 启动日志验证：过滤 hilog 后，`LastFatal: 0`、`signal:6: 0`、`Unexpected call: 0`、`exit(-1): 0`，未复现此前共享/截图 fallback 相关崩溃。
- 运行状态验证：日志出现 `coreReady` 与 `query-onlines-result`，说明 native core 已可用并完成在线状态查询；官方 API `logout` 返回 400 属于旧账号/token 退出请求失败，不影响启动稳定性。
- 共享日志说明：本轮为安装启动烟测，未通过 UI 手动点击共享开关，因此 `incoming-service-requested: 0`；共享按钮交互仍以 10:53 USB 复测结论为准。

## 2026-06-03 全功能检查第 10 轮

- 10 轮覆盖已完成：本轮次覆盖连接、共享、设置、扫码、账号登录、Web 登录、通讯录/LAN 发现、聊天、文件传输、远控显示/输入、会话命令、权限、增强功能、构建与 USB 启动烟测。
- 已落地修复汇总：远端重启/锁屏命令、键盘输入、会话选项、文件访问授权、设置页冲突菜单、旧设置分组、服务器默认隐含配置、扫码相机页、扫码导入校验、LAN 忽略列表、在线状态同步、聊天发送、远程文件目录/创建/删除/传输请求、重复 `@Builder` 警告、悬浮窗授权回滚。
- 明确未伪装完成的缺口：远端关机命令、远程剪贴板主动设置、真实远程音频 payload、真实 Harmony 屏幕采集、远控会话级 2FA 输入、开机启动、启动时真实更新检查、被控保持亮屏、真实悬浮窗 overlay 服务仍需后续平台/native 能力接入。
- 构建与设备验证：最后一次 HAP 构建通过，构建时间 `2026-06-03 11:34`；USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%` 安装启动成功，PID `32275` 稳定，崩溃关键字为 0。
- Git 状态说明：当前 Git 根与项目根一致，为 `%VSCODE_ROOT%\11_Rustdesk_harmonyos`；历史内层 `rustdesk_harmonyos/` 残留只作为本地坏缓存壳处理，已加入 `.gitignore`，不会进入远端。

## 2026-06-05 设置项图标添加 + 多项修复

- **为设置中每条选题添加图标**：所有设置行（Toggle/Info/Link）现在左侧显示对应stroke格式SVG图标，图标来源为 proicons.com 收录的 Lucide Icons 图标集（MIT许可，stroke风格，24x24）。
- **触摸区域匹配修复**：远控页面触摸覆盖层从100%容器尺寸改为视频画面实际渲染尺寸，避免黑边区域响应触摸。
- **首次连接跳回修复**：session已连接但未收到视频帧时断开，不再自动关闭页面，改为显示重试对话框。
- **聊天背景更透明+自动滚动**：聊天头部背景从50%改为25%透明；添加Scroller，新消息自动滚动到底部。
- **键盘按键半透明**：KeyboardToolbar所有按键背景改为半透明色（#55333333等），避免遮挡远程画面。
- **scan_frame扫码图标恢复**：设置Tab头部从PageHeader()替换为buildSettingsPageHeader()，恢复扫码入口。
- **图标颜色统一**：Language/Theme/Display行内图标从fillColor改为colorFilter+theme_TEXT_TERTIARY，与新图标一致。
- **指纹图标位置调整**：指纹图标移到行首20x20，后面显示指纹前12字符文本，点击可复制。
- **版本号自动同步**：构建脚本从app.json5读取versionName写入BuildInfo.ets，不再硬编码。
- 构建验证：`BUILD SUCCESSFUL in 8 s 866 ms`，BuildInfo编译时间 `2026-06-05 02:30`。

## 2026-06-05 More菜单图标添加

- **More菜单所有13项添加图标**：`buildMenuRow`/`buildToggleMenuRow` 调用处全部传入icon参数。
- **新增SVG资源**（7个）：menu_restart.svg(rotate-ccw)、menu_refresh.svg(refresh-cw)、menu_transfer.svg(folder-sync)、menu_fingerprint.svg(copy)、menu_switch.svg(arrow-left-right)、menu_screenshot.svg(camera)、menu_record.svg(circle-dot)。
- **图标映射**：OS Password→key、Send Clipboard Keys→clipboard、Reset Canvas→reset、Insert Ctrl+Alt+Del→key(复用)、Restart Remote→restart、Lock Remote→lock、Block User Input→block、Refresh Screen→refresh、File Transfer→transfer、Copy Fingerprint→fingerprint、Switch Sides→switch、Take Screenshot→screenshot、Session Recording→record。
- 构建验证：BUILD SUCCESSFUL，BuildInfo编译时间 `2026-06-05 03:07`。

## 2026-06-05 设置页缺失section方法修复 + 账户页登录后图标

- **重建4个缺失settings section方法**：`buildSettingsTwoFactorSection`/`buildSettingsShareScreenSection`/`buildSettingsEnhancedSection`/`buildSettingsAboutSection` 在之前编辑中意外丢失，已重建。
  - TwoFactor：双因素认证开关 + IP白名单开关
  - ShareScreen：允许录屏 + 自动关闭非活跃会话 + 被控保持亮屏
  - Enhanced：自适应码率 + 直连IP + 拒绝LAN发现 + 开机启动 + 终端额外键
  - About：启动检查更新 + 版本 + 构建时间
- **InfoRow组件添加icon参数**：`CommonComponents.ets` 中 `InfoRow(label, value, icon='')` 新增可选icon，传入时在label前显示18px stroke图标（colorFilter + TEXT_TERTIARY）。
- **连接Tab账户卡片添加图标**：Account→settings_person.svg、Provider→settings_server.svg、Status→settings_record.svg。
- **账户对话框登录后添加图标**：账户名前添加settings_person.svg图标（Provider/Status已有图标）。
- 构建验证：BUILD SUCCESSFUL，BuildInfo编译时间 `2026-06-05 20:41`；无线设备安装启动成功。

## 2026-06-05 图标fill/stroke规范修复 + section选项归位 + 34项翻译补齐

- **fill格式SVG还原+代码改用fillColor**：fingerprint/translate/dark_mode/light_mode/display 5个SVG还原为fill格式（`fill="#000000"`），代码中对应Image从`colorFilter(createStrokeIconColorFilter())`改为`fillColor(theme_TEXT_TERTIARY)`，遵循文档规范：fill格式用fillColor，stroke格式用colorFilter。
- **核心页指纹图标**：`buildSettingsInfoSettingRow`中fingerprint.svg改为settings_shield_check.svg（stroke格式），因为helper方法统一用colorFilter。
- **设置section选项归位**：Recording section中误放的Version/Build Time/Fingerprint/Privacy Policy移回About section；Recording只保留Auto-record incoming/outgoing+Directory。
- **34项翻译补齐**：I18nService中文和英文section各新增34条翻译，覆盖Allow Recording Sessions/Auto Close Inactive Sessions/Check Updates On Startup/Clipboard permission denied/Continue with/Core stopped/Debug summary copied/Deny LAN Discovery/Enable Adaptive Bitrate/Enable Direct IP/Enable Two Factor/Enhanced/File access permission denied/Input control permission denied/Keep Screen On When Controlled/Login failed/Login failed please check username and password/Login successful/Microphone permission denied/No active connection/No matching results/Only Whitelist IP Access/Rust Core/Screen capture permission denied/Search/Session/Show Terminal Extra Keys/Start On Boot/Starting.../Terms/Two Factor Auth/Two-factor authentication required/Type/or。
- 构建验证：BUILD SUCCESSFUL，BuildInfo编译时间 `2026-06-05 21:xx`；无线设备安装启动成功。

## 2026-06-05 聊天tab头部peer信息+聊天内容刷新

- **聊天tab头部**：有会话时只在聊天Tab显示左侧会话图标、peer名称+ID和右侧 `group.svg` 图标；无会话时显示"RustDesk"，不含扫码入口；连接Tab和设置Tab保持原来的头部显示。
- **聊天内容刷新**：`onPageShow()`中重新加载chatMessages，从RemoteControl返回时聊天记录会更新；会话结束后聊天Tab继续显示最近一次会话的聊天记录。
- **聊天浮窗自动滚动**：`RemoteControl.ets` 的会话聊天浮窗消息区绑定 `chatPanelScroller`，收到远端消息、本地发送和打开面板后都会滚动到底部。
- **固定测试消息移除**：`AppDataService.getChatMessages()` 不再返回示例消息，`Chat.ets` 移除本地模拟自动回复，`ChatService` 从持久化消息恢复会话摘要。
- 构建验证：全量构建安装通过，版本 `0.6.0`，启动阶段因设备锁屏跳过；补回右侧图标后增量构建安装启动通过，版本 `0.6.2`。

## 2026-06-05 设置项图标添加

- **为设置中每条选题添加图标**：所有设置行（Toggle/Info/Link）现在左侧显示对应stroke格式SVG图标，图标来源为 proicons.com 收录的 Lucide Icons 图标集（MIT许可，stroke风格，24x24）。
- **新增SVG资源**（22个）：settings_websocket.svg、settings_network.svg、settings_udp.svg、settings_ipv6.svg、settings_remark.svg、settings_keepscreen.svg、settings_folder.svg、settings_shield_check.svg、settings_wifi_off.svg、settings_whitelist.svg、settings_gauge.svg、settings_record.svg、settings_router.svg、settings_timer.svg、settings_power.svg、settings_update.svg、settings_terminal.svg、settings_floating.svg、settings_display.svg、settings_info_circle.svg、settings_privacy.svg、settings_language.svg、settings_palette.svg、settings_record_in.svg、settings_record_out.svg。
- **代码修改**：`buildSettingsToggleSettingRow` 和 `buildSettingsInfoSettingRow` 新增 `icon` 可选参数，传入图标文件名时在行首渲染20x20 colorFilter stroke图标；不传时保持原样无图标。
- **图标映射**：WebSocket→globe、UDP打洞→arrow-down-up、IPv6→network、备注→message-square-plus、保持亮屏→sun、目录→folder、2FA开关→shield-check、LAN发现→wifi-off、白名单→shield-alert、自适应码率→gauge、录制→circle-dot、直连IP→router、自动关闭→timer、开机启动→power、检查更新→refresh-cw、终端→terminal、悬浮窗→app-window、显示→monitor、版本→info、隐私→file-text、录入站→arrow-down-to-line、录出站→arrow-up-from-line。
- 构建验证：`BUILD SUCCESSFUL in 10 s 478 ms`，BuildInfo编译时间 `2026-06-05 01:45`。

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
- **项目备份移动**：`backup_20260604_001655` 从项目目录移动到 `%VSCODE_ROOT%\99_Temp\backup_20260604_001655`。

## 2026-06-06 远程连接画面卡住修复 + 质量菜单优化 + 帧率提升

- **画面卡住不刷新修复**（核心优化）：
  - `createPixelMapSync` 改为异步 `createPixelMap`，避免阻塞帧轮询流水线
  - 帧轮询间隔从8ms调整为16ms（60fps上限），减少无效轮询开销
  - stale帧检测阈值从600ms缩短到300ms，帧恢复更快
  - videoRefresh强制刷新阈值从1500ms/1200ms缩短到800ms/600ms
  - 非强制刷新stale阈值从5000ms/3000ms缩短到3000ms/1500ms
  - 会话watchdog超时从12000ms缩短到5000ms，更早检测链路中断
  - 新增 `maybeAdvanceNativeFrame()`：当帧超过200ms未更新时主动调用 `harmonyNextRgba` 推进native帧缓冲

- **质量显示菜单优化**：
  - 收发速率两行（Received/Sent）合并为一行"速度"（Speed），显示收发合计
  - 单位统一使用MB/s（<1MB/s时显示KB/s），自动换算
  - 新增 `computeCombinedSpeedDisplay()` 和 `parseSpeedToMbps()` 辅助方法
  - 分辨率、FPS在无数据时显示"--"而非0×0/0
  - I18n添加 Speed 键（中文"速度"，英文"Speed"）

- **视频帧率提升**：
  - FrameService帧队列从3增大到5，减少丢帧
  - 去掉FrameService `isRendering` 互斥锁，改为非阻塞帧入队
  - FPS统计历史窗口从30增大到60，计算更稳定
  - FPS计算周期从1000ms缩短到500ms，显示响应更快
  - 自定义FPS默认值从30提升到60
  - staleFrames缓冲从2增大到3，减少频繁release/GC压力

- **构建验证**：HAP构建通过，构建时间 `2026-06-06 01:22`，版本 `0.6.9`，签名成功。

## 2026-06-06 远程连接画面不刷新二次优化

- **帧递增语义收紧**：`NativeRustDeskBridge.pullLatestVideoFrame()` 只接受 `frameId > sinceFrameId` 的帧，避免旧帧被 UI 当作新帧渲染导致 frameId 回退。
- **native帧槽推进提前**：`RemoteControl.refreshRenderedFrame()` 在完成 native frame copy 后立即调用 `harmonyNextRgba()`，不再等待异步 PixelMap 渲染完成后才推进下一帧。
- **异步渲染防卡死**：新增 `renderGeneration` 防止旧 Promise 回写；`createPixelMap` 增加 260ms 超时，超时后释放迟到 PixelMap，避免 `frameRefreshInFlight` 长时间卡住。
- **主动推进节流**：`maybeAdvanceNativeFrame()` 增加 48ms 最小间隔，并支持已连接但首帧未到时低频 prime native RGBA。
- **构建与安装验证**：HAP构建通过，构建时间 `2026-06-06 07:30`，版本 `0.6.10`，versionCode `1000015`；无线目标 `192.168.11.100:36169` 安装成功并启动成功。
- **待复测**：仍需在设备上实际发起一次远程连接，确认画面持续刷新和首帧后重试弹窗行为。

## 2026-06-06 连接入口与远端断开重连对话修复

- **点击连接立即进入会话页**：`Index.ets` 不再把进入 `RemoteControl` 绑定到 `sessionStage === 'connected'`；native `connectToPeer` 成功返回后立即跳转，等待远端确认、密码补交、连接错误都在远控页承接。
- **保存密码路径统一**：保存密码连接不再在首页等待最多 12 秒；发起 native 请求成功后同样进入会话页。
- **跳转逻辑收敛**：新增 `openRemoteControlForPendingSession()`，统一最近会话、聊天缓存、pending monitor 失效和路由跳转。
- **远端断开不再卡旧画面**：`RemoteControl` 增加终止事件处理，收到 `session-closed` 或非密码类 `session-error` 时清理本地 connected、输入、游标和帧刷新状态，并进入重连对话。
- **验证结果**：HAP 构建通过，构建时间 `2026-06-06 07:46`，版本 `0.6.12`，versionCode `1000017`；无线目标安装启动成功。实机日志确认 `session-closed detail=Remote session closed` 后触发 `[RemoteControl] terminal session event kind=session-closed`。

## 2026-06-06 NAPI 模块加载修复（bridge_api.rs 缺失导出 + module.json5 配置）

- **根因**：Rust `bridge_api.rs` 缺少 `rustdesk_bridge_send_ctrl_alt_del` 和 `rustdesk_bridge_reconnect_session` 两个 C ABI 导出函数，导致 `librustdesk_bridge.so` 运行时符号解析失败，整个 NAPI 模块无法加载。C++ `rustdesk_bridge_abi.h` 声明50个函数，Rust 之前只导出46个。
- **关键认知**：CMake `--unresolved-symbols=ignore-all` 只影响链接阶段，HarmonyOS 运行时动态链接器严格检查所有符号，缺失符号会导致整个 SO 加载失败。
- **修复 bridge_api.rs**：新增 `rustdesk_bridge_send_ctrl_alt_del()` 和 `rustdesk_bridge_reconnect_session()` 两个 `#[no_mangle] pub extern "C"` 函数。
- **修复 module.json5**：设置 `compressNativeLibs: true` + `extractNativeLibs: true` + `libIsolation: true`，确保设备安装时正确解压 native SO。
- **重编 native core**：`build_native_bridge.ps1` 成功，产物 135,670,438 bytes。
- **构建 HAP**：成功，BuildInfo `2026-06-06 22:08`，版本 `0.6.17`，versionCode `1000022`。
- **设备验证**：安装到无线目标 `192.168.11.100:36169`，启动成功。hilog 确认 `module registered (52 functions)`、`coreReady=true`、`adapter=official-native`，无崩溃。
- **待完成**：设备上实际发起一次远程连接，确认连接链路和画面刷新正常。

## 2026-06-07 上游源码升级 1.4.6→1.4.7 + 连接 ECONNRESET 排查

- **连接失败**：设备上发起远程连接到 peer `1283267036`，收到 `session-error: 连接错误：Connection reset by peer (os error 104)`。连接能建立（收到 `quality-status` delay=108ms），但随后被远端重置。
- **排查结论**：本轮代码改动（新增2个ABI导出 + module.json5配置）不应导致 ECONNRESET。怀疑上游源码变化导致协议不兼容。GitHub 已发布 1.4.7（2026-06-02），当前编译基于 1.4.6。
- **1.4.7 升级进展**：
  - ✅ 从 GitHub clone 1.4.7 tag 源码 + 初始化 hbb_common 子模块
  - ✅ 恢复 `harmony_bridge/` 目录（从备份）
  - ✅ 恢复 `lib.rs` 的 OHOS `target_env` 条件修改
  - ✅ 修改 `Cargo.toml`：`crate-type = ["rlib"]`，排除 OHOS 桌面端依赖（tray-icon/tao/keepawake/wallpaper/gtk/libxdo/pulse/dbus/evdev/pam 等）
  - ✅ 修改 `scrap/Cargo.toml`：排除 OHOS 的 Linux 桌面依赖（dbus/gstreamer/zbus/nokhwa）
  - ✅ 修改 `build.rs`：基于 `CARGO_CFG_TARGET_OS` 运行时检查，避免在 OHOS 交叉编译时触发 Windows 平台 C++ 编译
  - ✅ 2026-06-12 后续已完成：13 项目曾发布 `v1.4.7-ohos` core，11 项目 Linux CI 曾使用该 core 成功构建 HAP/APP；当前构建规则已改为跟随 latest core 且线上只生成 HAP。
- **后续结论**：本段是 2026-06-07 的排查过程，当前状态以文档顶部“2026-06-12 Linux 在线构建结论”和 `CORE.md` 的 verified current core 为准。
- **备份位置**：`99_Temp/rustdesk_harmonyos_backups/harmony_bridge_backup_20260606/`
- **1.4.7 clone 位置**：`99_Temp/rustdesk_harmonyos_build/rustdesk-1.4.7-clone/`
## 2026-06-07 1.4.7 native core build + reconnect state fix

- Built the upstream RustDesk 1.4.7 based native core for `aarch64-unknown-linux-ohos` and refreshed `entry/src/main/libs/arm64/librustdesk_core.a`.
- Core detail info now reports native core file metadata instead of app build metadata:
  - Size: `137,510,852` bytes (`131.14 MB`)
  - Core compile time: `2026-06-07 01:36`
  - SHA256: `8EF4EE215FF7DED1EA78A68BC323A4E51DA613C46DBB6EA75C972EDCC572B272`
  - Compatible official version: `RustDesk 1.4.7`
- Fixed `OfficialRustDeskBridge.mergeNativeStateWithCurrentState()` so native `idle` is no longer masked by a stale ArkTS `connected` state after a session was already active. This prevents the viewer from freezing on the last frame when the controlled side closes unexpectedly.
- `RemoteControl` now clears stale rendered frames/input/cursor state before showing the reconnect dialog, keeps bridge refresh alive while the dialog is open, and falls back from `reconnectSession()` to a fresh `connectToPeer()` when the native active session handle has already gone away.
- Connection quality details now keep a larger raw payload, show dynamic metric values across multiple lines, include `chroma`, and use translated labels for quality detail fields.
- Historical APP packaging note: `run_hvigor_with_sdk_patch.js` once supported APP tasks. Current online build scripts are HAP-only and run `assembleHap`.
- Verification:
  - `node scripts\run_hvigor_with_sdk_patch.js assembleHap` passed.
  - `scripts\verify_native_harmonyos_hap.ps1 -HapPath ... -SkipLaunch -SkipLogs` passed native library and signature checks.
  - `scripts\audit_connection_chain.ps1` passed `50 PASS, 0 FAIL, 0 SKIP`.
  - Historical `scripts\github_build_harmonyos.ps1 -ArtifactType both -VersionBump none -PreflightOnly` passed DevEco/signing/native-core preflight before the HAP-only rule.
  - Signed HAP: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap` (`18,017,442` bytes).
  - Signed APP was a historical artifact from the old packaging path and is not generated by current online scripts.

## 2026-06-07 无密码连接密码框丢失 + 会话过早关闭 + LAN 发现失效修复

- **问题1&2：无密码连接时密码输入框丢失 / 被访问端刚提示就结束会话**：
  - 根因：`RemoteControl.ets` 的 `applyBridgeState` 中，error/idle 分支在 `shouldAutoCloseTerminalSession()` 为 true 时，会跳过密码提示直接关闭或重连。`handleTerminalBridgeEvent` 只在 `session-error` 时检查密码需求，`session-closed` 不检查。
  - 修复：`applyBridgeState` error/idle 分支在 `shouldAutoCloseTerminalSession()` 判断之前，先检查 `shouldPromptForPassword(coreState)`，为 true 则优先显示密码对话框。`handleTerminalBridgeEvent` 将密码检查从仅 `session-error` 扩展到 `session-error` 和 `session-closed` 都检查。

- **问题3：LAN 发现失效**：
  - 根因：`rendezvous_mediator_ohos.rs` 的 `start_all()` 只执行 `std::future::pending().await`，从未启动 LAN 监听线程。OHOS 使用独立的 `rendezvous_mediator_ohos.rs`（不是 `rendezvous_mediator.rs`），其中完全没有调用 `crate::lan::start_listening()`。hilog 确认 `discoverLanPeers` 返回 true、`loadLanPeers` 返回 `[]`、`lan-discovery-done` 事件到达——UDP ping 发出但没有监听线程接收响应。
  - 修复：在 `start_all()` 中添加 `std::thread::spawn` 启动 `crate::lan::start_listening()` LAN 监听线程。

- **LanDiscoveryService.ets 诊断增强**：
  - 所有 `console.log/error` 改为 `hilog.info/error`（domain `0xA03D00`，tag `LAN`）
  - `loadDiscoveredPeers` 增加 `loadLanPeers` 返回值长度和前100字符预览日志

- **Native core 重编**：新产物 `librustdesk_core.a` 137,422,248 bytes，SHA256 `7C10663743785D8AD04078E16274D21497D451FEAAA942D8B2882CC4A58B3A2F`

- **HAP 构建成功 + 安装启动成功**

- **文档更新**：`docs/CONNECTION_DEBUG_LOG.md` 新增修复记录

- **待验证**：需要在设备上实际发起无密码连接确认密码框弹出；确认被访问端拒绝/超时时不再直接关闭页面；确认 LAN 监听线程日志 `lan discovery listener started` 出现

## 2026-06-07 并行密码+无密码连接流程（未解决）

- **目标**：无保存密码时，立即弹密码框 + 同时发无密码申请；无密码申请成功则关闭密码框；用户输入密码则切换密码连接
- **已做改动**：
  - `Index.ets handleConnect()`: 无保存密码时 `showConnectPasswordDialog()` + `initiateBackgroundConnection()` 并行
  - `Index.ets openRemoteControlForPendingSession()`: 传递 `showPasswordDialog` 路由参数
  - `Index.ets buildPasswordDialog()`: 新增"等待确认"按钮，修改描述文字
  - `RemoteControl.ets aboutToAppear()`: 接收 `showPasswordDialog` 路由参数
  - `RemoteControl.ets syncBridgeState()`: connecting+无保存密码时设 `showPasswordDialog=true`
  - `RemoteControl.ets bridgeListener()`: msgbox 含密码关键词时设 `showPasswordDialog=true`
  - `RemoteControl.ets applyBridgeState()`: connecting 不调 `updatePasswordDialogState`；error 时密码框开着则保持；connected 时无条件关闭密码框
  - `RemoteControl.ets handleTerminalBridgeEvent()`: 删 `!hasReceivedFrame` 阻止条件；密码框开着时 return true
  - `RemoteControl.ets submitSessionPassword()`: 密码提交失败时调 `reconnectWithPassword()`
  - `RemoteControl.ets reconnectWithPassword()`: 新增方法，断开当前连接后用密码重连
  - `RemoteControl.ets buildPasswordDialog()`: 新增"等待确认"按钮
  - `I18nService.ets`: 新增5个翻译键
- **顽固问题**：
  - **密码框仍不弹出**：用户从最近会话进入 RemoteControl 不经过 Index；msgbox 密码提示到达但密码框未弹出；`showPasswordDialog` 可能被后续 `applyBridgeState` 覆盖为 false
  - **ECONNRESET 后无重连提示**：连接被对端重置后页面卡住，无重连对话框
- **下一步**：在 `showPasswordDialog` setter 加追踪确认被谁覆盖；在 `handleTerminalBridgeEvent` 和 `showReconnectDialogFromState` 加追踪确认执行路径

## 2026-06-07 连接流程、LAN 发现、线上生成包收口

- 修改前已备份项目到 `L:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_backups\project_backup_20260607_061033`，其中包含 git 状态和 diff 快照。
- 无保存密码连接流程已修复：
  - `Index.ets` 在无保存密码时立即打开密码对话框，同时后台发起无密码授权连接。
  - 用户输入密码确认后会重置当前待处理连接，并切换到密码连接路径。
  - `RemoteControl.ets` 会保留主动弹出的密码框，直到收到首帧或会话明确结束，避免被 `connected` 快照过早关闭。
- 对端重置/关闭后的重试提示已修复：
  - `RemoteControl.ets` 统一处理 `closed`、`session-closed`、`session-error`。
  - `Connection reset by peer`、`connection reset`、`os error 104`、强制关闭、EOF、broken pipe、timeout 以及中文重置/关闭/超时文案都会触发重连对话框。
  - “已连接但尚未收到首帧”的状态不再关闭重连对话框，也不再把 native 已关闭会话误当作正常连接。
- LAN 发现链路已增强：
  - `LanDiscoveryService.ets` 对 native 临时返回空列表做容错，前两次空结果保留旧发现列表，第三次连续为空才清空。
  - 这样避免一次空 `loadLanPeers()` 结果把发现页直接刷空，看起来像 LAN 功能失效。
- 连接质量详细信息显示已优化：
  - 详情面板改为可滚动并增加最大高度。
  - 原始详情保留长度增加，指标行允许换行，长 payload 不再被面板截掉。
- 核心详情元数据已修正为 native 核心文件信息：
  - 文件大小：`137430594` bytes (`131.06 MB`)
  - 编译时间：`2026-06-07 06:20`
  - SHA256：`00B1735321D83C23F68DCDA4058ADA879729055AC88BD9D2D8AB574CE0CE6E7C`
  - 兼容官方版本：`1.4.7`
- 线上生成包功能已完善：
  - `.github/workflows/build-harmonyos.yml` 当前固定 HAP-only；旧的 `app/both` 选择已下线。
  - `scripts/github_build_harmonyos.ps1` 构建前检查 DevEco SDK、签名配置、native 核心是否存在、核心大小和可选 SHA256。
  - 构建从 `99_Temp` 下的干净 staged copy 执行，产物写到 `L:\Visual_Studio_Code\99_Temp\harmonyos_artifacts\11_Rustdesk_harmonyos`，避免污染源码目录。
  - 本轮 signed HAP：`entry-default-signed.hap`，`18020747` bytes，SHA256 `93554B4C39F42330625C7B3B66D451F4BC751E2533F0489F297A3228BF91CC0F`。
- 验证结果：
  - 旧规则下 `scripts\github_build_harmonyos.ps1 -ArtifactType both -VersionBump none` 曾通过；当前线上脚本仅允许 `-ArtifactType hap`。
  - HAP native 校验通过：`librustdesk_bridge.so`、`libc++_shared.so` 均存在，运行时依赖和签名校验通过。
  - 设备 `192.168.11.100:36169` 安装成功。
  - 启动日志抓取受设备锁屏限制阻断，`aa start` 返回 `Error Code:10106102`；安装与包校验本身正常。
  - `scripts\audit_connection_chain.ps1` 通过：`50 PASS, 0 FAIL, 0 SKIP`。
  - `scripts\audit_full_function_rounds.ps1 -Rounds 100` 通过：100 轮均为 `96 PASS, 0 SKIP`。

## 2026-06-07 中文输入法修复 + 重连对话框多层修复 + 聊天UI修复

- **中文输入法无法输入**：
  - 根因：`send_clipboard_data()` 在 Rust 侧是空壳函数直接返回 false，剪贴板内容没有同步到远端
  - 修复：实现 `send_clipboard_data()`，构建 Clipboard protobuf 消息通过 `session.send(Data::Message(msg))` 发送到远端
  - Clipboard 结构体使用字面量 + `..Default::default()` 模式，format 用 `ClipboardFormat::Text.into()` 转为 `EnumOrUnknown`
  - 参考 `screenshot.rs` 中 Clipboard 的用法模式
  - 代码位置：`99_Temp/rustdesk-master/src/harmony_bridge/core.rs:442`

- **重连对话框多层修复**（ECONNRESET后无重连提示）：
  - 根因1：`buildReconnectDialog()` 定义了但从未在 `build()` 中渲染
  - 根因2：`syncBridgeState`/`applyBridgeState` 中错误覆盖 `showReconnectDialog=false`
  - 根因3：msgbox事件携带104错误时不被 `handleTerminalBridgeEvent` 处理
  - 根因4：msgbox事件"Successful: Connected"不能触发重连框
  - 根因5：远端主动关闭应显示"会话已关闭"而非弹重连框

- **聊天tab页UI修复**：
  - 无会话数据时header显示openRustDesk logo（与其他tab页一致）
  - 聊天内容区添加 `bottom: 120` padding，避免内容滑到tab菜单上面

- **项目备份**：`99_Temp/rustdesk_harmonyos_backups/rustdesk_harmonyos_20260607_201953.zip`

- **待验证**：实机构建验证中文输入、重连对话框弹出、远端关闭显示"会话已关闭"
