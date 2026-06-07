# 连接调试记录

> 本文记录每一轮连接和核心调试过程。当前结论以最新时间段为准，历史段落保留排查脉络。

## 2026-06-07 无密码连接密码框丢失 + 会话过早关闭 + LAN发现诊断

### 用户观察

1. 发起无密码连接时，密码输入框丢失——远端要求密码时没有弹出密码输入对话框。
2. 无密码连接时，被访问端刚提示连接请求，会话就结束了——访问端直接关闭或弹重连对话框。
3. LAN 发现功能失效——发现列表始终为空。

### 根因

1. **密码框丢失**：`handleTerminalBridgeEvent` 对 `session-error` 含密码关键词时调用 `applyBridgeState`，但 `applyBridgeState` 中 `sessionStage === 'error'` 分支在 `shouldAutoCloseTerminalSession()` 为 true（`sessionBecameActive` 已被设为 true）时，会跳过密码提示直接进入重连或关闭流程。`shouldPromptForPassword` 检查只在 `!sessionCloseRequestedLocally` 的 else 分支中执行，被 `shouldAutoCloseTerminalSession()` 的 true 分支短路。
2. **会话过早关闭**：`handleTerminalBridgeEvent` 对 `session-closed` 只在 `session-error` 时检查密码需求，`session-closed` 事件不检查。当远端因密码需求返回 `session-closed`（idle 状态），`applyBridgeState` 的 idle 分支在 `shouldAutoCloseTerminalSession()` 为 true 时直接 `finishTerminalSession` 关闭页面。
3. **LAN 发现**：ArkTS → OfficialRustDeskBridge → NativeRustDeskBridge → C ABI → Rust `harmony_bridge::discover_lan_peers()` → `crate::lan::discover()` 链路完整。可能原因：HarmonyOS 上 UDP broadcast 权限不足、`default_net::get_interfaces()` 返回空、或 native `discover()` 静默失败。已将 `LanDiscoveryService` 所有 `console.log/error` 改为 `hilog`（domain `0xA03D00`，tag `LAN`），便于设备端排查。

### 修改

- `RemoteControl.ets` `applyBridgeState` error 分支：在 `shouldAutoCloseTerminalSession()` 判断之前，先检查 `shouldPromptForPassword(coreState)`，如果为 true 则优先显示密码对话框并 return。
- `RemoteControl.ets` `applyBridgeState` idle 分支：在 `shouldAutoCloseTerminalSession()` 判断内部，先检查 `shouldPromptForPassword(coreState)`，如果为 true 则优先显示密码对话框并 return，而不是直接关闭或弹重连。
- `RemoteControl.ets` `handleTerminalBridgeEvent`：将密码检查从仅 `session-error` 扩展到 `session-error` 和 `session-closed` 都检查，即 `if (this.shouldPromptForPassword(coreState))` 不再限定 `event.kind === 'session-error'`。
- `LanDiscoveryService.ets`：所有 `console.log/error` 改为 `hilog.info/error`（domain `0xA03D00`，tag `LAN`），`loadDiscoveredPeers` 增加 `loadLanPeers` 返回值长度和前100字符预览日志。

### 验证

- HAP 构建通过（BUILD SUCCESSFUL）。
- 待实机验证：无密码连接时远端要求密码应弹出密码框；被访问端拒绝/超时不应直接关闭页面；LAN 发现 hilog 应输出 `LAN` tag 日志。

## 2026-06-06 22:09 NAPI模块加载失败修复

### 用户观察

- 核心页 Native Module 状态显示异常（Unrecognized/Error），连接链路无法发起会话。
- App 启动后所有核心功能不可用。

### 根因

- Rust `bridge_api.rs` 缺少两个 C ABI 导出函数：`rustdesk_bridge_send_ctrl_alt_del` 和 `rustdesk_bridge_reconnect_session`。
- C++ `rustdesk_bridge_abi.h` 声明了这两个 extern "C" 函数，C++ bridge loader 通过 NAPI 注册了对应入口，但 Rust staticlib 中没有实现。
- HarmonyOS 运行时动态链接器严格检查所有符号，`rustdesk_bridge_reconnect_session: symbol not found` 导致整个 `librustdesk_bridge.so` 加载失败。
- CMake 链接时 `--unresolved-symbols=ignore-all` 只影响链接阶段，不影响运行时 dlopen 符号解析。
- 同时修正 `module.json5`：`compressNativeLibs: true` + `extractNativeLibs: true` + `libIsolation: true`，确保 SO 安装时解压到 `libs/` 目录。

### 修改

- `native_rust_core/src/bridge_api.rs`：新增 `rustdesk_bridge_send_ctrl_alt_del()` 和 `rustdesk_bridge_reconnect_session(force_relay)` 两个 `#[no_mangle] pub extern "C"` 函数，分别调用上游 `harmony_bridge::send_ctrl_alt_del()` 和 `harmony_bridge::reconnect_session()`。
- `entry/src/main/module.json5`：`compressNativeLibs` 改为 `true`，`libIsolation` 改为 `true`，确保设备安装时正确解压 native SO。

### 验证

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1` 通过。
- Native core：`entry/src/main/libs/arm64/librustdesk_core.a`
  - Size: `135,670,438` bytes
  - Compile time: `2026-06-06 22:03`
  - FNV-1a 1MB: `45b5baa5`
  - SHA256: `6CEDA7DB08CE3FF5BF39AC4691DED2C502F749F22D5C715166256155559E4827`
- HAP 构建通过，BuildInfo 编译时间：`2026-06-06 22:08`，版本 `0.6.17`。
- 无线目标 `192.168.11.100:36169` 卸载旧版后安装成功，启动成功。
- hilog 确认：
  - `RustDesk bridge loader module registered (52 functions)` ✅
  - `module loaded via static import` ✅
  - `initializeRuntimeFn returned: coreReady=true` ✅
  - `Bootstrap snapshot: adapter=official-native, coreReady=true` ✅
  - 无 `symbol not found`、`signal:6`、`LastFatal` 错误。

## 2026-06-06 20:03 首帧后误报会话关闭根因修复

### 用户观察

- 连接建立后画面刚刷新出来，被访问端会话状态立刻关闭，访问端画面卡住。
- 正常情况下，只有被访问端人工断开或真实异常断开时，访问端才应进入重新连接对话。
- 核心详情中的编译时间/文件大小应显示核心文件信息，不能显示 App 构建时间。

### 根因

- RustDesk 官方 `client/io_loop.rs` 在收到第一帧时会调用 `handler.close_success()`；官方 UI 中这个方法语义是“关闭连接成功/等待对话”，不是远端会话关闭。
- Harmony bridge 曾把 `HarmonyHandler.close_success()` 映射成 `update_connect_state("idle", ...)` 和 `queue_event("session-closed", "Remote session closed", ...)`。
- 因此第一帧刚出现就会被 ArkTS 误认为远端关闭，会话页清理/冻结，表现为“被访问端立马断开、访问端卡死”。
- 静态链接方案下 `Native Core` 没有运行时独立文件路径，核心详情原来用 `BuildInfo.BUILD_TIME` 兜底，导致显示 App 构建时间。

### 修改

- `rustdesk-master/src/harmony_bridge/core.rs`：`close_success()` 改为保持 `connected`，并上报 `connection-ready`，不再上报 `session-closed`。
- 保留 ArkTS `RemoteControl` 对真实 `session-closed/session-error` 的重连对话处理，作为真实断线兜底。
- `native_rust_core/Cargo.toml` 修正 portable path，从项目根相邻 `99_Temp` 解析 RustDesk 源码与 `machine-uid` patch。
- `scripts/build_native_bridge.ps1` 强制使用 Rust stable toolchain，并在 native 构建成功后自动复制新 `.a` 到 `entry/src/main/libs/arm64/librustdesk_core.a`。
- 新增 `entry/src/main/ets/common/CoreBuildInfo.ets`，`scripts/run_hvigor_with_sdk_patch.js` 每次 HAP 构建读取 `librustdesk_core.a` 的 size、mtime、FNV-1a 和 SHA256，核心详情读取该文件，不再用 App BuildInfo 兜底。

### 验证

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1` 通过。
- Native core：`entry/src/main/libs/arm64/librustdesk_core.a`
  - Size: `135,668,882` bytes
  - Compile time / mtime: `2026-06-06 20:02`
  - FNV-1a 1MB: `1f19e29a`
  - SHA256: `C75BF0D5F17F0812A76DEDD8FB3634462F4BDA655FDCC50CDB582AB8C3073226`
- `cmd /c scripts\build_hap.bat` 通过。
- BuildInfo App 构建时间：`2026-06-06 20:03`。
- App 显示版本：`0.6.13`，versionCode：`1000018`。
- Signed HAP size: `45,429,679` bytes。
- Signed HAP SHA256: `638919DD459DFCD4343845C19B347C9FE93359DC2C70C84D01091B2B57C36914`。
- 无线目标 `192.168.11.100:36169` 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功，设备 bundle dump 确认 `0.6.13/1000018` 已安装。
- 本轮自动抓日志期间未捕获到新的连接动作；仍需在设备上实际点一次连接，确认第一帧后不再出现假的 `session-closed`。

### 2026-06-06 20:12 核心页状态显示修正

- 用户反馈核心详情里 `Native Module` 显示异常，`Native Core` 显示已停止。
- 判断：HAP 内 native entry 是 `libs/arm64-v8a/librustdesk_bridge.so`，核心页原来只验证 `/data/storage/el1/bundle/libs/arm64/librustdesk_bridge.so`，运行时 stat 路径不稳定会导致模块详情显示异常；同时 staticlib 方案下核心已经链接进 `librustdesk_bridge.so`，不能只用 `isCoreLoaded()` 作为 `Native Core` 是否就绪的唯一条件。
- 修改：
  - `Native Module` 文件信息尝试多个 HarmonyOS bundle/lib 可能路径；只要 NAPI 模块可用，Valid ELF 不再因为 stat 路径不可访问而显示异常。
  - `Native Core` 在 `officialCoreState.coreReady`、`isCoreLoaded()` 或 `Native Module` 可用且 `CoreBuildInfo` 记录到 staticlib 时显示 `Ready`。
  - 如果 NAPI 模块不可用，`Native Core` 显示 `Error` 而不是误导性的 `Stop`。
  - 核心 tab 打开或详情弹窗打开时，周期刷新会同步刷新核心模块列表，避免初始化后的状态仍显示旧值。
- 验证：
  - `cmd /c scripts\build_hap.bat` 通过。
  - App 显示版本：`0.6.14`，versionCode：`1000019`。
  - BuildInfo App 构建时间：`2026-06-06 20:11`。
  - Native core manifest 仍为：size `135,668,882` bytes，mtime `2026-06-06 20:02`，FNV-1a `1f19e29a`，SHA256 `C75BF0D5F17F0812A76DEDD8FB3634462F4BDA655FDCC50CDB582AB8C3073226`。
  - Signed HAP size: `45,428,257` bytes。
  - Signed HAP SHA256: `D077245989BB3C1A3EAF5271DFB517DE0BFD4BCCE684EF4E878668FF3CC784A7`。
  - 无线目标 `192.168.11.100:36169` 安装成功，设备 bundle dump 确认 `0.6.14/1000019`。
  - `aa start` 运行时设备处于锁屏状态，返回 `Error Code:10106102`；核心页最终显示需解锁后再确认。

## 2026-06-06 07:47 连接入口与远端断开重连对话修复

### 用户观察

- 0.6.10 二次优化后，点击连接可能无法进入远控画面。
- 会话建立后，如果被访问端主动断开，访问端仍停留在旧画面，表现为画面卡死；此时应进入重连对话。

### 判断

- `Index.ets` 的连接入口仍把进入 `RemoteControl` 绑定在 `sessionStage === 'connected'`，保存密码路径还会在首页最多等待 12 秒。远端等待确认、密码提示或 native connected 事件延迟时，会表现为“点击连接没有进入画面”。
- 实机日志确认，新包发起连接后 native `connectToPeer` 返回成功，随后进入 `RemoteControl` 并收到 `connection-type`。在被访问端断开时，native 上报 `session-closed: Remote session closed`，旧逻辑没有立即清掉本地 connected/旧帧状态。

### 修改

- `Index.handleConnect()` 空密码路径不再默认弹首页密码框；native `connectToPeer` 成功返回后立即进入 `RemoteControl`，密码补交、远端确认、连接错误都交由会话页处理。
- 保存密码路径同样改为 native 连接请求成功后立即进入会话页，不再在首页等待 connected 轮询。
- 新增 `openRemoteControlForPendingSession()`，统一最近会话、聊天缓存、pending 监控失效和路由跳转，避免多路径重复跳转。
- `RemoteControl` 新增 `handleTerminalBridgeEvent()`：收到 `session-closed` 或非密码类 `session-error` 时，立即清理本地 connected、输入、游标和帧刷新状态，并显示重连对话。
- 密码/认证类 error 仍交给原有密码输入 UI，避免把可补交密码流程误判为断线。

### 验证

- `cmd /c scripts\build_hap.bat` 增量 HAP 构建通过。
- BuildInfo 编译时间：`2026-06-06 07:46`。
- App 显示版本：`0.6.12`，versionCode：`1000017`。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- 签名 HAP 大小：`45,420,552` bytes。
- 签名 HAP SHA256：`593D9C459246E0C51B690C7A5266AAAB0C6BEEF07ADBCB4F506D2833E460CD8C`。
- 无线目标 `192.168.11.100:36169` 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- 实机日志确认连接入口已经进入远控页：`connectToPeer START` -> `Native connect returned SUCCESS` -> `RemoteControl` 初始化 -> `connection-type`。
- 实机日志确认远端断开已被新逻辑接管：`session-closed detail=Remote session closed` 后出现 `[RemoteControl] terminal session event kind=session-closed detail=Remote session closed`。

## 2026-06-06 07:30 连接后画面不刷新二次优化

### 用户观察

- 之前“每次构建后第一次连接必定失败”的现象经调整后变成：连接能建立，但远程画面不继续刷新。

### 判断

- Rust 侧 `get_latest_video_frame_metadata_json(sinceFrameId)` 已经只返回严格大于 `sinceFrameId` 的帧；ArkTS wrapper 再额外允许旧 1-2 帧会造成 UI frameId 回退风险。
- 上一轮异步 `createPixelMap` 仍把 `harmonyNextRgba()` 放在渲染完成之后；如果 PixelMap Promise 慢或挂起，native latest RGBA 槽推进会被拖住。
- `maybeAdvanceNativeFrame()` 每 16ms 都可能推进 native 槽，缺少节流，容易在渲染进行中制造 copy race。

### 修改

- `NativeRustDeskBridge.pullLatestVideoFrame()` 改为只接受 `frameId > sinceFrameId` 的帧，重试 copy 时也要求新帧大于当前请求。
- `RemoteControl.refreshRenderedFrame()` 在完成 native frame copy 后立即推进 `harmonyNextRgba()`，不再等待 PixelMap 渲染结束。
- `RemoteControl` 增加 `renderGeneration`，页面退出、重连、清理帧时使旧异步 PixelMap 结果失效，避免旧 Promise 回写。
- `createPixelMap` 增加 260ms 超时保护；超时后释放迟到的 PixelMap，防止 `frameRefreshInFlight` 长时间卡死。
- `maybeAdvanceNativeFrame()` 增加 48ms 节流，并允许已连接但尚未收到首帧时低频 prime native RGBA。

### 验证

- `cmd /c scripts\build_hap.bat` 增量 HAP 构建通过。
- BuildInfo 编译时间：`2026-06-06 07:30`。
- App 显示版本：`0.6.10`，versionCode：`1000015`。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- 无线目标 `192.168.11.100:36169` 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- 仍需在设备上实际发起一次远程连接，确认画面持续刷新和首帧后重试弹窗行为。

## 2026-06-06 01:22 画面卡住不刷新 + 质量菜单 + 帧率优化

### 用户观察

- 远程连接链路故障：点击ID卡片连接成功后画面卡住不刷新。
- 质量显示菜单中收发速率分两行显示，应合并为一行"速度"，单位MB/s。
- 视频帧率只有25左右，需要提升。

### 根因分析

1. **画面卡住**：`createPixelMapSync` 同步阻塞帧轮询流水线；`frameRefreshInFlight` 互斥锁导致 8ms 轮询被跳过；stale 阈值 600ms 偏长；watchdog 12s 超时偏晚。
2. **帧率25fps**：FrameService `isRendering` 锁拒绝新帧；`MAX_QUEUE_SIZE=3` 太小易丢帧；FPS 计算周期 1s 偏长；默认 `customFps=30` 偏低。
3. **质量菜单**：Received/Sent 分两行冗余，单位不统一。

### 修改

- `updateRenderedFrameSurface` 改为 `updateRenderedFrameSurfaceAsync`，使用 `image.createPixelMap` 异步创建。
- 帧轮询间隔 8ms -> 16ms，stale 阈值 600ms -> 300ms，watchdog 12s -> 5s。
- 新增 `maybeAdvanceNativeFrame()` 主动推进 native 帧缓冲。
- FrameService 去掉 `isRendering` 锁，队列 3 -> 5，FPS 历史 30 -> 60。
- FPS 计算周期 1000ms -> 500ms，默认 `customFps` 30 -> 60。
- 质量菜单：Received+Sent -> Speed，单位 MB/s，新增 `computeCombinedSpeedDisplay()` 和 `parseSpeedToMbps()`。
- 分辨率/FPS 无数据时显示 `--`。

### 验证

- HAP 构建通过，构建时间 `2026-06-06 01:22`，版本 `0.6.9`。
- 需实机验证画面刷新和帧率提升效果。

## 2026-06-03 07:51

### 用户观察

- 点击 Screen Capture 开关后能弹出截屏权限对话框，授权后开关保持打开，但共享服务仍无法启动。
- 之前版本点击开关没有任何反应（不弹权限对话框，开关不切换）。

### 判断

- Toggle `isOn` 值绑定导致回弹：onChange 中调 async 方法，await 期间重渲染把 Toggle 回弹到旧值。
- ForEach key 包含 `accountRefreshTick`，登录状态刷新时销毁整个 Tab 内容。
- `toggleIncomingService` 中 `startCapture` 失败后 catch 块没有 throw，继续把 `serviceEnabled` 设为 true。
- `console.info` 在 HarmonyOS 设备上不输出到 hilog，导致无法通过日志排查。

### 修改

1. **Toggle 回弹修复**：所有5个权限开关的 onChange 回调中，先同步 `updateSettings` 更新状态，再执行异步权限请求；权限拒绝时回滚为 false。
2. **ForEach key 修复**：移除 `accountRefreshTick`，改为 `${this.i18nVersion}_${index}`。
3. **toggleIncomingService throw 修复**：`startCapture` 失败后 catch 块末尾添加 `throw new Error('startCapture failed: ' + error)`。
4. **checkScreenCapturePermissionAndToggle catch 回滚**：添加 try-catch 包裹 `toggleIncomingService(true)`，失败时回滚 `serviceEnabled: false`。
5. **hilog 替代 console.info**：`import hilog from '@ohos.hilog'`，`checkScreenCapturePermissionAndToggle` 和 `toggleIncomingService` 中的调试日志改用 `hilog.info(0xA03D00, 'SHARE', ...)`。

### 构建与安装

- HAP 通过 `node scripts/run_hvigor_with_sdk_patch.js assembleHap` 重建成功。
- BuildInfo 编译时间：`2026-06-03 07:51`。
- 无线目标 `192.168.11.100:36169` 安装成功。
- `aa start -a EntryAbility -b com.open.rundesk` 启动成功。

### 验证结果

- 点击 Screen Capture 开关后能弹出截屏权限对话框 ✅
- 授权后开关保持打开状态 ✅
- 共享服务仍无法启动 ❌（`avScreenCapture.createAVScreenCapture()` 可能失败，需要通过 hilog 确认具体原因）

### 下一步

- 抓取 `hilog -x | grep SHARE` 确认 `toggleIncomingService` 和 `startCapture` 的具体失败原因。
- 排查 `avScreenCapture.createAVScreenCapture()` 在 HarmonyOS 商业设备上的可用性和配置要求。

## 2026-06-02 14:35

### 用户观察

- 共享服务默认停止符合预期，但运行状态需要切换 Tab 后才刷新。
- 生成新密码后，界面不会立即显示，重启共享服务后才更新。
- `复制设备 ID` 和 `复制密码` 按钮应移除，改成长按 ID/密码文本复制。
- 连接过程中会先弹重试对话框，然后连接成功，说明重试弹窗触发过早。
- 删除发现设备后，重启不再出现在发现页；需要增加手动刷新入口便于验证。

### 判断

- 共享卡片依赖通用 5 秒刷新循环，密码生成后还依赖一次完整核心刷新，界面可能滞后或被旧 native 快照覆盖。
- 密码生成只更新 App 偏好，运行中的 native incoming service 未立即收到新密码。
- `RemoteControl` 会把早期 `msgbox` / `session-error` 事件当作重试提示，即使会话还没真正活跃。
- 发现删除已经按持久化忽略列表设计；手动刷新应重新跑 LAN 发现，同时继续尊重已忽略 ID。

### 修改

- 共享刷新循环从 5 秒降为 2 秒。
- 共享服务开关和密码生成后，立即更新本地 UI，并安排一次短延迟核心刷新。
- `AppDataService.setPassword()` / `generatePassword()` 同步 native local options：`password` 和 `temporary-password`。
- 移除共享页复制按钮，长按设备 ID 或一次性密码复制。
- 我的设备页同步长按复制和刷新行为。
- 发现页增加手动刷新图标。
- 抑制会话活跃或收到首帧前的早期重试弹窗。
- 修复远程触摸输入链路：
  - ArkTS mouse mask 改为官方 RustDesk 编码：低 3 位是事件类型，按键位左移 3 位。
  - 滚轮事件发送官方 `MOUSE_TYPE_WHEEL` 和滚动 delta，不再发送当前指针坐标。
  - `harmony_bridge::send_mouse_input()` 不再返回 stub `false`，改为转发到 active `Session.send_mouse()`。

### 构建与安装

- native core 通过 `build_bridge_now.bat` 重编成功。
- 新 `entry/src/main/libs/arm64/librustdesk_core.a` 大小：135,575,952 bytes。
- native core SHA256：`14863BC23CD2B940664CD501EE1501897E5B1E498150EAFDCFD607B78A38D0D4`。
- HAP 通过 `node scripts/run_hvigor_with_sdk_patch.js assembleHap` 重建成功。
- BuildInfo 编译时间：`2026-06-02 14:23`。
- 签名 HAP 大小：45,298,265 bytes。
- USB 安装到 `%RUSTDESK_HARMONY_USB_TARGET%` 成功。
- `aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- bundle dump 确认 `com.open.rundesk` 已安装并更新。

## 2026-06-02 14:15

### 用户观察

- 在历史/发现页来回切换时，在线点偶尔短暂闪绿后消失。
- 被访问端停止服务后，删除发现页 ID 卡片，重启 App 后该卡片可能再次出现在发现页。

### 判断

- 发现卡片删除路径只把忽略 ID 存在 `LanDiscoveryService.ignoredPeerIds` 内存集合中，App 重启后集合为空，LAN 发现会重新添加同一 peer。
- LAN 发现曾在发现到 `online=true` 时直接写 `peerOnlineMap`；随后官方/core 在线查询又可能返回离线，所以共享在线点会短暂闪绿再恢复离线。

### 修改

- 通过 `PreferenceStore` 持久化已忽略的发现设备 ID。
- 处理 LAN 发现结果前重新加载忽略列表。
- 不再用 LAN 发现作为全局在线点来源；发现只更新发现列表，共享在线状态由 `queryOnlines` 驱动。
- 删除发现设备后，立即在共享在线 map 中标记离线。

### 预期行为

- 手动删除的发现卡片，App 重启后不应重新出现，除非清除忽略列表。
- 历史/发现在线点不应再因为 LAN 发现单独闪绿。

### 构建与安装

- HAP 通过 `node scripts/run_hvigor_with_sdk_patch.js assembleHap` 重建成功。
- BuildInfo 编译时间：`2026-06-02 14:06`。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- HAP 大小：45,296,009 bytes。
- USB 安装到 `%RUSTDESK_HARMONY_USB_TARGET%` 成功。
- 第一次启动因设备锁屏被阻止：`Error Code:10106102`。
- 重试后 `aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- bundle dump 确认 `com.open.rundesk` 已安装并更新。

## 2026-06-02 10:04

### 用户观察

- 被访问端显示连接已稳定建立。
- 访问端停在等待页约 30 秒后断开。
- 核心页应对所有核心模块使用一致的点击详情菜单。

### 判断

- `harmony_bridge/core.rs` 中 `refresh_session_video()` 仍是返回 `false` 的 stub。
- `harmony_next_rgba()` 也仍是 stub。
- Harmony 控制端 UI 在等待首帧时反复调用 `refreshSessionVideo()`，但 native core 没有向 RustDesk session 发送 `request_init_msgs()` 或 `refresh_video()`。
- 这解释了两端状态不对称：被访问端接受连接，访问端却收不到/发布不了首帧，随后超时。
- 核心页 UI 混用了可点击模块行和不可点击的 `Adapter / Native Module / Native Core / Native Detail` 行，`Adapter` 没有详情弹窗。

### 修改

- `refresh_session_video(display)` 接入 active RustDesk session：
  - `session.request_init_msgs(display)`
  - `session.refresh_video(display)`
  - 事件：`video-refresh-requested`
- `harmony_next_rgba(display)` 接入 `session.ui_handler.next_rgba(display)`。
- `HarmonyHandler::on_connected()` 中增加初始 `request_init_msgs(0)` 和 `refresh_video(0)`。
- 核心页模块列表改成三个可点击行：
  - `Adapter`
  - `Native Module`
  - `Native Core`
- 移除核心卡片里重复的不可点击 native 状态行。

### 构建与安装

- native core 通过 `build_bridge_now.bat` 重编成功。
- 新 `entry/src/main/libs/arm64/librustdesk_core.a` 大小：135,594,242 bytes。
- native core SHA256：`98C913805A5A8F6DCEB6DED2834ED8BE495902DB4B4406E26765520AA0097EE1`。
- HAP 通过 `node scripts/run_hvigor_with_sdk_patch.js assembleHap` 重建成功。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- HAP 大小：45,286,721 bytes。
- 检测到 USB 目标：`%RUSTDESK_HARMONY_USB_TARGET%`。
- HAP 安装成功。

### 下一步验证

- 手机解锁后通过 USB 启动 App。
- 连接同一 peer。
- 检查访问端是否收到 `session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`。
- 如果仍在等待，抓取 `pullLatestVideoFrame`、`requestVideoRefresh`、`video-refresh-requested`、`session-closed`、native bridge 调用附近的 hilog。

## 2026-06-02 10:42

### 用户观察

- 被访问端显示已建立连接且不主动断开。
- 访问端仍像停留在初始/等待状态。
- 共享页显示 `Waiting for core init`，密码生成后可见值不稳定；官方行为应在共享服务启动前隐藏 ID/密码。
- LAN 设备名仍缺少 `username@hostname` 格式。

### 判断

- 上游 OHOS bridge 的 incoming service 和 bootstrap snapshot 函数仍返回 `{}`。
- wrapper 直接透传 `{}` 后，ArkTS 无法在启动服务后拿到 `incomingReady` 或 `displayId`。
- `AppDataService` 默认 `serviceEnabled=true`，而官方行为是共享服务默认停止。
- OHOS platform stub 返回空 active username，导致本机 LAN 广播包无法生成 `username@hostname`。
- `OfficialRustDeskBridge.refresh()` 可能读取到只表示“核心就绪/空闲”的 native live snapshot，并覆盖当前 connecting/connected UI 状态，导致 native session 活跃时控制端页面看起来仍是初始状态。

### 修改

- 共享服务默认状态改为停止。
- 共享页在服务实际运行前隐藏设备 ID、密码、复制、生成控件。
- 共享页在 native display ID 未出现时，使用本地生成的设备 ID 作为回退。
- 启动/停止共享服务后立即刷新密码和状态。
- native wrapper 在 `setIncomingServiceEnabled()` 和 `bootstrapCoreSnapshot()` 上游返回 `{}` 时合成有效快照。
- native wrapper 在 initialized/live snapshot 中用 local option `id` 填充 `displayId`。
- OHOS `get_active_username()` stub 改为返回 `crate::username()` 或环境变量回退，不再总是空字符串。
- `OfficialRustDeskBridge.refresh()` 在 native snapshot 只是 idle/ready 时保留已有 connecting/connected 状态，避免活动连接期间 UI 被重置为初始状态。

### 验证计划

- 重编 native core 和 HAP。
- 通过 USB 安装并启动。
- 再次连接，观察 `session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`。
- 如果控制端仍等待，抓 hilog 判断是 Rust callback 缺失还是 ArkTS 拉帧失败。

### USB 验证结果

- 移除不支持的 wrapper 字段后，native core 重编成功。
- 修复 ArkTS `@Builder` 局部变量语法后，HAP 重建成功。
- 安装到 USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%` 并通过 `aa start` 启动。
- hilog 显示控制端媒体状态活跃：
  - `connected=true`
  - `hasFrame=true`
  - `lastFrameId=36`
  - peer `1283267036` 有 `quality-status` FPS/速度数据。
- 通过 `snapshot_display` 抓到的设备截图显示真实远程视频画面，不是等待/渐变占位。
- 剩余清理项：`pullLatestVideoFrame(0)` 回退把 `{}` metadata 当成 `frameId=0`，重复打印 `Frame too old`。这是日志/循环清理问题，不是传输失败。

### 后续修改

- `NativeRustDeskBridge.pullLatestVideoFrame()` 对空/无效 metadata 立即返回 `null`，不再计算 stale frame 差异，消除重复 `Frame too old: frameId=0` 警告。
- 后续 USB 运行发现 frame metadata/copy race：metadata 报告有效帧，但 copy 时 native latest frame 已推进，导致 copy 返回 0 bytes。ArkTS 现在会重新读取最新 metadata 并重试一次 copy。
- 同一轮 USB 运行确认 peer info 已到达：`hostname=latitude-5290-2-in-1`，`username=Li Yan`，核心侧已有官方 `username@hostname` 显示所需数据。

## 2026-06-02 15:18

### 用户观察

- 连接过程中先弹重试对话框，然后会话才连接成功。
- 远程会话界面点击键盘按钮后，自定义键盘工具条出现在屏幕底部；它应该出现在顶部并覆盖视频画面。
- native core 重建说明必须足够完整，不能依赖旧备份产物。

### 判断

- 访问端收到首帧前，早期官方 `msgbox` 或短暂 `session-error` 可能到达；把这些都当成 reconnect prompt 太激进，会造成“先弹重试，再连接成功”的假断线流程。
- 真正的重试提示只应在会话确实活跃后显示：已经收到帧，或 connected 状态保持足够久以避开启动瞬态。
- 自定义键盘面板原本锚定在视频层底部。

### 修改

- `RemoteControl.ets` 收紧重试弹窗门槛：
  - `msgbox` 不再创建重试对话框。
  - `session-error` 和 `session-closed` 只有在非本地关闭，且已收到视频帧或 connected 至少 3 秒后，才显示重试对话框。
  - 成功连接时记录 `sessionBecameActiveAt`；手动重试/清理时重置。
- 自定义键盘工具条改为顶部覆盖，不再锚定视频底部。
- `docs/CORE.md` 增加可复现 native core 构建说明，包括工作区路径、工具、Rust target、源码要求、重建命令、产物 hash/size、HAP 构建安装命令和运行验证清单。

### 验证计划

- 通过 `node scripts/run_hvigor_with_sdk_patch.js assembleHap` 重建 HAP。
- 安装并启动到 USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%`。
- 验证初始连接在首个可用会话状态前不再弹重试对话框。
- 验证键盘工具条显示在视频内容上方。

### 验证结果

- 第一次重建正确失败：页面没有 `avoidStatusBarHeight` 字段。
- 键盘覆盖位置改为固定顶部覆盖 (`y: 8`) 后，ArkTS/HAP 构建通过。
- BuildInfo 编译时间：`2026-06-02 14:40`。
- 签名 HAP 大小：`45,297,012` bytes。
- USB 安装到 `%RUSTDESK_HARMONY_USB_TARGET%` 成功。
- `aa start -a EntryAbility -b com.open.rundesk` 启动成功。

## 2026-06-02 20:18

### 用户观察

- 添加发现页手动刷新后，LAN 发现功能失效；自动刷新需要保留，手动刷新需要完整重置发现逻辑。
- 共享页面默认应为关闭服务状态，且关闭后重启 App 不能丢失。
- 需要添加文件访问授权。
- 使用其他设备访问本 App 时无法建立连接，需要继续完善共享视频逻辑。

### 判断

- `LanDiscoveryService.refreshNow()` 只额外调用一次 `discoverOnce()`，没有清空旧 UI 列表、本地内存和 native LAN peer 缓存；旧发现结果可能继续污染手动刷新。
- `ensureIncomingServiceEnabled()` 在 `coreReady && !incomingReady` 时无条件开启服务，覆盖了默认关闭和用户关闭后的持久化状态。
- manifest 已声明 `FILE_ACCESS_PERSIST`，但运行时权限服务和共享页文件传输开关没有申请它。
- 控制端已连接但未收到首帧时，`refresh_session_video()` 强制刷新间隔偏保守，可能增加等待视频流时间。

### 修改

- `LanDiscoveryService.refreshNow()` 改为强刷新：
  - 读取当前 native `loadLanPeers()` 和 ArkTS 已发现列表。
  - 对已有 peer 调用 native `removeDiscoveredPeer()` 清缓存。
  - 清空 `discoveredPeers` 和 `AppDataService.discoveredDevices`。
  - 重新执行 `discoverLanPeers()`，并继续使用延迟 `loadLanPeers()` 回读。
- 保留 `startDiscovery()` 的 5 秒自动轮询，手动强刷新与自动刷新共存。
- `ensureIncomingServiceEnabled()` 改为按持久化 `settings.serviceEnabled` 恢复：开启状态才恢复服务；关闭状态如果发现 native incoming 已开启则明确关闭。
- 文件访问授权补齐 `ohos.permission.FILE_ACCESS_PERSIST`，与 `READ_WRITE_DOWNLOAD_DIRECTORY` 一起申请。
- 等待首帧时强制 `refresh_session_video()` 最短间隔从 900ms 收紧到 450ms。

### 验证结果

- `node scripts\run_hvigor_with_sdk_patch.js assembleHap` 构建通过。
- BuildInfo 编译时间：`2026-06-02 20:18`。
- 签名 HAP 大小：`45,310,005` bytes。
- 本轮 native ABI 未变更，未重编 native core。
- USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%` 安装成功。
- `aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- 仍需在界面内继续实机复验共享服务默认关闭、关闭后重启保持关闭、LAN 手动强刷新和被访问端视频建连。

### 20:24 补充修复

- 实机打开后共享服务仍显示运行中，确认是旧版本已经把错误的 `serviceEnabled=true` 写入设备偏好，新逻辑按持久化状态恢复时继续恢复了这个脏值。
- 增加一次性迁移 `incoming_service_default_off_migration_20260602`：
  - 迁移未执行过时，如果发现 `serviceEnabled=true`，启动阶段先改回 `false` 并持久化。
  - 写入迁移标记后不再重复覆盖；之后用户手动开启/关闭仍会被正常记住。
- 重新构建 HAP 通过。
- BuildInfo 编译时间：`2026-06-02 20:24`。
- 签名 HAP 大小：`45,317,003` bytes。
- USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%` 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- 执行 `aa force-stop com.open.rundesk` 后再次 `aa start -a EntryAbility -b com.open.rundesk` 启动成功，用于覆盖迁移后的重启路径。

### 20:35 LAN 发现和刷新图标补充修复

- 进一步验证发现功能时确认：native `loadLanPeers()` 可以稳定返回 LAN peer，问题不是原生扫描失败，而是页面没有在发现结果写入后重新渲染。
- 原先手动强刷新中调用 native `removeDiscoveredPeer()` 会删除 RustDesk 原生 `_lan_peers` 中的真实结果，导致 LAN 设备反而消失；该路径已撤销。
- `LanDiscoveryService.refreshNow()` 现在只清空 ArkTS `discoveredPeers` 和 UI `discoveredDevices`，重新启用 `enable-lan-discovery` 并触发 `discoverLanPeers()` + `loadLanPeers()`。
- `LanDiscoveryService` 新增 listener；`Index.ets` 订阅发现结果变化后递增 `addressBookVersion` 和 `peerOnlineVersion`，确保发现页卡片重新渲染。
- 发现页和文件传输页刷新图标已从 `refresh.svg` 改为动态 `arrow-rotate.svg`。
- HAP 重建通过：
  - BuildInfo 编译时间：`2026-06-02 20:33`
  - 签名 HAP 大小：`45,316,179` bytes
  - 本轮 native ABI 未变更，未重编 native core。
- USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%` 安装成功，`aa force-stop` 后 `aa start -a EntryAbility -b com.open.rundesk` 启动成功。
- 启动后 hilog 验证到 LAN 发现返回：
  - `id=1283267036`
  - `hostname=latitude-5290-2-in-1`
  - `username=Li Yan`
  - `ip=192.168.11.115`
  - `platform=Windows`
  - `Parsed peers count: 1`
  - `lan-discovery-done`

## 2026-06-02 21:04

### 用户观察

- 会话质量监控中延迟、收发速度不显示，FPS 只有约 32。
- 共享逻辑仍不能被其他设备访问，生成密码后不能立刻刷新。

### 判断

- Harmony native bridge 的 `quality-status` 之前使用 Rust debug 字符串 `format!("{qs:?}")` 发给 ArkTS，而 ArkTS 按 JSON 解析，导致延迟和速度字段为空。
- `AppDataService` 虽然调用 `setLocalOption('temporary-password')`，但 Rust `set_local_option()` 没有把 `temporary-password` 写入官方 `password_security::TEMPORARY_PASSWORD`，运行中的被访问端鉴权读不到新一次性密码。
- `native_rust_core` wrapper 在 official `set_incoming_service_enabled()` 返回 `{}` 时把 `incomingReady` 伪装成 `true`，造成 UI 显示运行中但实际无法访问的假阳性。
- 原生重编脚本把 `SDK_DIR` 指向 `deveco-sdk`，该目录只有 ets；真实 native SDK 镜像在 `ohos-sdk`。

### 修改

- native `quality-status` 改为 JSON 输出：`speed`、`fps`、`delay`、`target_bitrate`、`codec_format`、`chroma`。
- ArkTS `RemoteControl.ets` 增加质量状态兼容解析：优先 JSON，失败时兼容旧 `QualityStatus { ... }` debug 串。
- ArkTS 拉帧间隔从 16ms 改为 8ms，FPS 统计不再依赖质量监控面板是否展开。
- 一次性密码同步链路改为：
  - `temporary-password`
  - `verification-method=use-temporary-password`
  - `approve-mode=password`
- Rust `set_local_option('temporary-password')` 直接写入 `hbb_common::password_security::TEMPORARY_PASSWORD`。
- 生成密码后立即同步 native、刷新本机 profile；如果共享服务已开启则重新推送 incoming 配置。
- wrapper fallback 不再把未确认的 incoming service 标记为运行中。
- 修正 `build_bridge_now.bat`：`SDK_DIR=%BUILD_ROOT%\ohos-sdk`。

### 验证结果

- `cmd /c %VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat` 原生重编通过。
- native core：
  - Size: `135,430,764` bytes
  - SHA256: `18AF989D8AFD8BF8EB7C7ED87FD213F3801FB5B723B64CCF2069C201BD32D724`
- `node scripts\run_hvigor_with_sdk_patch.js assembleHap` 构建通过。
- BuildInfo 编译时间：`2026-06-02 21:03`。
- 签名 HAP 大小：`45,352,609` bytes。
- 仍需实机确认：共享页若显示“不可用/未确认”，说明 official incoming service 仍缺真实服务端实现，需要继续补 official OHOS 被控端监听/屏幕采集链路，而不是 UI 状态刷新问题。

## 2026-06-02 21:16

### 用户观察

- 向远程设备发送 `Ctrl+Alt+Del` 没有生效。
- 通讯录必须登录后才能添加；未登录时应该显示登录按钮。
- 发现功能打开 App 时可以自动运行一次，后续需要改为手动刷新，不再持续自动轮询。

### 判断

- 旧的 `Ctrl+Alt+Del` 路径在 ArkTS 侧模拟普通键盘事件，而 native `send_keyboard_input()` 仍是 stub/fallback，无法等价于 RustDesk 官方的安全序列命令。
- RustDesk official session 已有 `ctrl_alt_del()` 能力，Harmony 侧缺少专用 ABI/NAPI/ArkTS 接线。
- LAN 发现此前文档和实现保留 5 秒轮询，容易继续影响在线状态和发现列表稳定性；当前需求改为启动时自动发现一次，之后只接受手动刷新。
- 通讯录入口此前未登录时仍可能展示本地通讯录操作，和“账户通讯录必须登录”的产品逻辑不一致。

### 修改

- native `harmony_bridge::send_ctrl_alt_del()` 新增 official 命令路径：从 active session 调用 `Session::ctrl_alt_del()`，并记录 `keyboard-input command=ctrl-alt-del` 事件。
- `native_rust_core`、C++ NAPI、ArkTS d.ts、`NativeRustDeskBridge`、`RemoteControl.ets`、`KeyboardToolbar.ets` 已接入 `sendCtrlAltDel()`。
- 远程控制页更多菜单和键盘工具栏的 `Ctrl+Alt+Del` 改为调用专用 native 命令；失败时提示命令不可用，不再误报成功。
- `LanDiscoveryService.startDiscovery()` 改为 one-shot：App 打开时执行一次发现，不再创建 5 秒 timer。
- `LanDiscoveryService.refreshNow()` 在未发现状态下也会临时进入发现流程并执行一次完整 `discoverOnce()`，后续由手动刷新触发。
- 通讯录 Tab 未登录时显示官方登录入口；从历史记录添加到通讯录前会先检查登录态，未登录则弹出登录对话框。

### 验证结果

- `cmd /c %VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat` 原生重编通过。
- native core：
  - Size: `135,673,254` bytes
  - SHA256: `B1224DDE1CD4ECA502D7585F3CCE2D89F41B55FF075914DE6757A2F184EB649B`
- `node scripts\run_hvigor_with_sdk_patch.js assembleHap` 构建通过。
- BuildInfo 编译时间：`2026-06-02 21:15`。
- 签名 HAP 大小：`45,416,051` bytes。
- USB 目标 `%RUSTDESK_HARMONY_USB_TARGET%` 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。

## 2026-06-06 00:02

### 修改

- 项目源码提升到 `%VSCODE_ROOT%\11_Rustdesk_harmonyos` 根目录，旧内层 `rustdesk_harmonyos/` 只作为本地坏缓存壳忽略。
- Windows HAP 构建入口改为先复制干净副本到 `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`，构建产物输出到 `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos`。
- staging 脚本只重写临时副本中的签名材料路径，根项目继续使用便携相对路径。
- 批处理构建入口改用 delayed expansion 读取 `BUILD_PROJECT_ROOT`，避免 staging 构建后版本同步参数为空。

### 验证结果

- `scripts\AUTO_BUILD_INSTALL.bat auto` 增量构建通过。
- BuildInfo 编译时间：`2026-06-06 00:02`。
- App 显示版本：`0.6.6`，versionCode：`1000011`。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- 签名 HAP 大小：`45,406,876` bytes。
- HAP 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。

## 2026-06-06 00:24

### 修改

- 远控触摸输入按显示区域重新审查：首帧前不发输入，Down 必须落在渲染图像内，Move/Up 在已有指针时钳制到图像边界。
- TAB 聊天、远控聊天浮窗、独立聊天页统一改为消息快照刷新，并在发送/接收后多次调度滚动到底部。
- 独立聊天页移除固定 `/remote/Inbox/logs.zip` 文件引用，改用文档选择器选择真实文件 URI。
- 设置页和扫码页的服务器配置导入均直接保存，并同步 native `key`。

### 验证结果

- `scripts\AUTO_BUILD_INSTALL.bat auto` 增量构建通过。
- BuildInfo 编译时间：`2026-06-06 00:24`。
- App 显示版本：`0.6.8`，versionCode：`1000013`。
- 签名 HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。
- 签名 HAP 大小：`45,408,949` bytes。
- HAP 安装成功，`aa start -a EntryAbility -b com.open.rundesk` 启动成功。

## 2026-06-07 连接 ECONNRESET 排查 + 上游 1.4.7 升级

### 现象

- 设备上发起远程连接到 peer `1283267036`，收到 `session-error: 连接错误：Connection reset by peer (os error 104)`。
- 连接能建立（收到 `quality-status` delay=108ms），但随后被远端重置。
- 最终停在连接错误画面，显示 "os error 104"。

### hilog 关键日志

```
[HANDSHAKE_DIAG] Event: quality-status, detail: {"delay":108,...}, peerId: 1283267036
[HANDSHAKE_DIAG] Event: session-error, detail: 连接错误：Connection reset by peer (os error 104), peerId: 1283267036
[RemoteControl] terminal session event kind=session-error detail=连接错误：Connection reset by peer (os error 104)
```

### 排查

- 本轮代码改动（新增2个ABI导出 + module.json5配置）不应导致 ECONNRESET。
- 远端 Windows RustDesk 确认正常运行，之前连接正常。
- 怀疑上游源码版本不匹配：当前编译基于 RustDesk 1.4.6，GitHub 已发布 1.4.7（2026-06-02），远端可能已升级。

### 措施

- 升级上游源码到 1.4.7 并重新编译 native core。
- OHOS 交叉编译适配已完成：Cargo.toml/lib.rs/build.rs/scrap/Cargo.toml 排除桌面端依赖。
- 编译待继续完成。

### 待办

1. 完成 1.4.7 native core 编译
2. 构建 HAP 并安装验证
3. 验证连接是否正常
4. 核心页详细信息添加兼容的官方版本号
## 2026-06-07 1.4.7 rebuild and reconnect-state conclusion

- Native core rebuild succeeded against upstream RustDesk `1.4.7`.
- The key freeze root cause found in ArkTS was stale state merging: native `idle` snapshots were previously merged back into the current `connected` state when a session had already shown frames. After a remote-side close, this could leave the viewer displaying the last frame instead of opening the reconnect prompt.
- Fix: `OfficialRustDeskBridge.mergeNativeStateWithCurrentState()` now only protects native `idle` while the current state is still `connecting`. Once the UI has been `connected`, native `idle` is surfaced as a terminal state.
- `RemoteControl` now:
  - disposes the rendered frame and clears input/cursor state before showing a reconnect dialog,
  - keeps bridge refresh running while the reconnect dialog is displayed,
  - retries through native `reconnectSession()` first,
  - falls back to a fresh `connectToPeer()` using the route peer id and saved password if the native active session handle is already gone.
- `HarmonyHandler.close_success()` was rechecked in upstream `client/io_loop.rs`: it is called on first video frame and must remain mapped to `connection-ready`, not `session-closed`.
- Quality status display now keeps longer raw detail text, allows multi-line metric values, and includes the `chroma` field.
- Verification:
  - HAP build passed at app build time `2026-06-07 01:51`.
  - APP build passed after switching APP tasks to Hvigor project mode.
  - HAP verifier passed native library, dependency, bundle, and signature checks.
  - 50-check connection chain audit passed.
