# RustDesk HarmonyOS 变更日志

> 本文件记录阶段性变更，不作为当前状态总入口。新开对话或接手项目请先读 `docs/README.md`，当前核心、构建、安装和验证状态以 `docs/CORE.md`、`docs/PROGRESS.md`、`docs/CONNECTION_DEBUG_LOG.md` 为准。

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
