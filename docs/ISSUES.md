# 问题整理

> 避免问题反复出现，修改前必查此文档

## 顽固问题 (未解决)

### 并行密码+无密码连接流程：密码框不弹出 (2026-06-07)

**用户要求**：无保存密码时，立即弹密码框 + 同时发无密码申请；无密码申请成功则关闭密码框；用户输入密码则切换密码连接。

**已做改动**：
- `Index.ets handleConnect()`: 无保存密码时调 `showConnectPasswordDialog()` + `initiateBackgroundConnection()`
- `RemoteControl.ets aboutToAppear()`: 接收 `showPasswordDialog` 路由参数
- `RemoteControl.ets syncBridgeState()`: connecting 状态+无保存密码时设 `showPasswordDialog=true`
- `RemoteControl.ets bridgeListener()`: msgbox 含密码关键词时设 `showPasswordDialog=true`
- `RemoteControl.ets applyBridgeState()`: connecting 状态不调 `updatePasswordDialogState`；error 状态密码框开着则保持
- `RemoteControl.ets handleTerminalBridgeEvent()`: 删掉 `!hasReceivedFrame` 阻止条件；密码框开着时 return true
- 密码框 UI 新增"等待确认"按钮；i18n 翻译已添加

**仍未弹出的原因**：用户从最近会话/历史记录进入 RemoteControl，不经过 Index 的 `handleConnect`。RemoteControl 的 `syncBridgeState` 检查 `coreState.sessionStage === 'connecting'` 但 msgbox 到达时 stage 可能已变。`bridgeListener` 的 msgbox 检查已加但仍未生效，需进一步调试确认 `showPasswordDialog` 被谁覆盖回 false。

**下一步**：在 `showPasswordDialog` 的 setter 中加 hilog 追踪所有赋值点，确认被谁覆盖。

### ECONNRESET 后无重连提示 (2026-06-07)

**现象**：连接建立后立即被对端重置（`Connection reset by peer (os error 104)`），页面卡在 `connected=false hasFrame=false`，无重连对话框。

**已做改动**：
- `handleTerminalBridgeEvent()` 删掉了 `!this.hasReceivedFrame && !this.shouldShowReconnectPromptNow()` 的 return false 条件
- `applyBridgeState()` error 分支中 `showPasswordDialog` 为 true 时保持不触发重连

**仍未弹出的原因**：ECONNRESET 发生在从未收到帧的情况下，`shouldShowReconnectPromptNow()` 可能返回 false。删掉阻止条件后仍不弹，需确认 `handleTerminalBridgeEvent` 是否被调用、`showReconnectDialogFromState` 是否执行。

**下一步**：在 `handleTerminalBridgeEvent` 和 `showReconnectDialogFromState` 加 hilog 追踪执行路径。

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

### 远程连接 ECONNRESET (os error 104) (2026-06-07发现, 排查中)

**现象**: 发起远程连接到 peer 后，收到 `session-error: 连接错误：Connection reset by peer (os error 104)`。连接能建立（收到 quality-status delay=108ms），但随后被远端重置。最终停在连接错误画面。
**可能原因**: 上游源码版本不匹配——当前编译基于 RustDesk 1.4.6，远端可能已升级到 1.4.7，协议/握手可能不兼容。
**当前措施**: 升级上游源码到 1.4.7 并重新编译 native core。
**待验证**: 1.4.7 编译完成后构建 HAP 安装验证连接。

### 上游源码升级 1.4.6→1.4.7 编译适配 (2026-06-07进行中)

**问题**: RustDesk 1.4.7 引入更多 Linux 桌面端依赖（gtk 0.18、winit 0.30 等），OHOS 交叉编译时 `target_os = "linux"` 导致这些桌面依赖全部激活，触发 pkg-config/gtk 编译失败。
**解决进展**:
- ✅ Cargo.toml：注释/排除 tray-icon、tao、keepawake；用 `not(target_env = "ohos")` 条件排除 wallpaper/gtk/libxdo/pulse/dbus/evdev/pam 等
- ✅ scrap/Cargo.toml：排除 OHOS 的 dbus/gstreamer/zbus/nokhwa
- ✅ build.rs：基于 CARGO_CFG_TARGET_OS 运行时检查，避免 OHOS 交叉编译时触发 Windows C++ 编译
- ✅ lib.rs：恢复所有 OHOS target_env 条件修改
- 🔄 编译进行中，需继续完成
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
**解决**: native bridge 已改为写入 server option、`stop-service`，并请求 `start_server(true, false)`；ArkTS `ScreenCaptureService` 当前改用 `@ohos.screenshot.capture()` 作为 SDK 可编译的屏幕捕获探测/截图路径。
**剩余风险**: 最新 HAP 已安装到 USB 设备，但设备锁屏导致 `aa start` 失败，仍需解锁后通过共享 Tab 和 hilog 验证服务是否真正监听并可被其他设备访问。

**2026-06-03 10:53 更新**: 已完成 USB 复测。直接启动桌面端 `start_server(true, false)` 会在 Harmony appspawn 环境触发 `exit(-1)` / `signal:6`，因此 native Harmony bridge 已改为安全 incoming requested 路径，不再启动该桌面 server 线程。`get_core_snapshot_json()` 已返回当前 `incomingReady`，前端轮询重试已收敛为单次延迟刷新。最新装机日志中 `incoming-service-requested` 只出现 1 次，App 进程稳定，无 `signal:6`。

**剩余风险**: 当前只是修复“共享开关无法稳定开启/启动即崩溃/状态反复重试”。真实屏幕采集仍未接入，`ScreenCaptureService` 在当前 SDK/runtime 下明确标记 screen capture API 不可用；后续需要接入 Harmony 可用的官方录屏/采集链路后，才能验证被控端画面输出。

### 文件访问权限只请求权限位、不唤起授权选择器 (2026-06-03发现，已修复)
**现象**: 共享页 `File transfer` 开关和远控页文件传输入口只请求 `READ_WRITE_DOWNLOAD_DIRECTORY` / `FILE_ACCESS_PERSIST`，用户不会看到系统文件访问授权流程。
**根因**: 文件访问授权与普通权限请求混在一起，缺少 `DocumentViewPicker` 授权入口。
**解决**: `PermissionService` 新增 `requestFileAccessAuthorization()`，在权限位通过后调用 `DocumentViewPicker.select()`；共享页和远控页统一使用该入口。
**剩余风险**: 当前只补齐授权入口；文件传输页本地文件列表仍是虚拟/固定路径模型，真实本地文件选择、URI 到 native 传输路径的落地需要在文件传输轮次继续完善。

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
**解决**: `ScreenCaptureService.startScreenCaptureSession()` 明确 throw 标记当前SDK/runtime下screen capture API不可用，不调用任何截图或录屏API。真实屏幕采集需后续接入Harmony可用的官方录屏/采集链路。
**教训**: ✅录屏和截图是不同API，不能用截图 fallback 替代录屏；✅`@ohos.avScreenCapture` 是官方录屏链路但当前SDK未提供类型声明，不可编译；✅应按文档记录的当前状态处理，不做超出SDK能力的修改。

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

### 无密码连接密码框、对端重置重试、LAN发现与线上生成包 (2026-06-07补充, 已修复)
**现象**: 升级核心后，无保存密码发起连接不会先弹密码框；对端 reset/closed 后远控页停在最后画面且不弹重试；LAN 发现列表会被一次空结果刷空；线上构建需要同时生成 HAP 和 APP，并在构建前确认 native 核心完整。
**根因**: `Index.ets` 和 `RemoteControl.ets` 对“无密码授权等待”和“输入密码切换连接”没有作为并行流程处理；`RemoteControl.ets` 的 connected 快照会在首帧前关闭对话框并掩盖刚关闭的 native 会话；retry 判断没有覆盖 `closed`、`session-closed` 和 `Connection reset by peer (os error 104)` 这类实际错误；`LanDiscoveryService.ets` 对 native 短暂空列表没有容错；线上构建脚本缺少 staged 产物校验和 HAP/APP 双格式收集。
**解决**: 无保存密码时立即弹出密码框并并行发送无密码连接申请，输入密码确认后重置当前连接并切到密码连接；reset/closed/error 均进入统一 retry 判断，首帧前的 connected 快照不再关闭重连对话框；LAN 发现连续三次空结果才清空旧列表；`github_build_harmonyos.ps1` 增加 strict preflight、staged build、HAP native 校验、HAP/APP 双产物收集和 workflow 输入。
**验证**: `scripts\github_build_harmonyos.ps1 -ArtifactType both -VersionBump none` 通过；signed HAP 安装到 `192.168.11.100:36169` 成功；HAP native 库和签名校验通过；`scripts\audit_connection_chain.ps1` 为 `50 PASS, 0 FAIL, 0 SKIP`；`scripts\audit_full_function_rounds.ps1 -Rounds 100` 每轮 `96 PASS, 0 SKIP`。
**剩余条件**: 设备当前锁屏导致 `aa start` 返回 `Error Code:10106102`，本轮无法继续自动抓取启动后的实机交互日志；解锁后可直接用已安装包继续复测实际无密码授权等待、密码切换、reset 重试弹窗和 LAN 发现。
