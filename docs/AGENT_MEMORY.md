# 技术经验参考

> 更新时间：2026-08-11
> 本文件记录项目积累的技术经验，按类别组织。修改前必查对应类别。

## 2026-08-11 UI/UX 修复经验

- **HarmonyOS Select 组件 `menuBackgroundColor` 暗色主题不生效**：必须配合 `menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)`，但最终方案是**完全弃用 Select 组件**，用自定义 `Column+ForEach+Row` 弹出列表替代（独立浮层 Stack+zIndex(120)+居中 Blank 关闭）。
- **ArkTS `@Builder` 内 Image 对 SVG 的 width/height 动态更新不可靠**：改用 `scale` 变换（固定基础尺寸24 + `.scale({ x: size/24, y: size/24, centerX: 0, centerY: 0 })`）才能响应 @State 变化。
- **TextInput 格式化导致光标错位**：`deviceIdDisplay` 更新触发重新渲染重置光标。修复需三层保障：① 更新文本前先 `caretPosition` ② 多次异步重试 [16,50,100,200]ms ③ `onTextSelectionChange` 检测 `deviceIdExpectedCaret` 并立即修正。
- **颜色变量命名有 `_TEXT`（文字色）和 `_BG`（背景色）后缀**：`theme_ERROR_TEXT`（深红）不能用作背景，背景用 `theme_ERROR_BG`（浅红）。
- **iconoir 图标库**：`https://github.com/iconoir-icons/iconoir`，SVG 在 `icons/regular/` 目录。`cursor-pointer.svg` 箭头尖端在 (4.68, 6.26)/24 比例处，热点偏移 (0.195, 0.261)。

## 术语约定

- **TAB** = 底部主菜单4项（连接/聊天/共享/设置），对应 `currentTab: HomeTab`
- **选项卡** = ID输入框下方的子选项（历史/收藏/发现/通讯录/登录/核心），对应 `currentConnectTab: ConnectTab`
- 两处经常混淆，必须严格区分

## ArkTS 开发经验

- **@Builder 方法中不能有 const/let 声明**（arkts-no-obj-literals-as-types），必须内联调用或用接口类型
- **对象字面量不能作为类型声明**，必须定义 interface
- **@Prop 在 @Builder 内不实时更新**：需要实时响应的选中状态用内联组件直接绑定父状态
- **HitTestMode.Block 在 overlay Stack 上阻止子元素接收触摸**：overlay 层不要用 Block，让子元素自行处理
- **Stack 布局的 HitTestMode.Transparent 只处理点击穿透，不处理滚动穿透**：需要滚动的列表区域必须用 Column/Row 流式布局
- **ForEach key 不应包含频繁变化的状态变量**（如 accountRefreshTick），否则导致组件销毁重建
- **Row 中子项用 layoutWeight 而非 width('100%')**：每个都设 width('100%') 只有第一个可见
- **animateTo({ iterations: -1 }) 不生效**，必须用 setInterval 驱动动画
- **@State 角度变量绑定 rotate 始终绑定**（角度0=不旋转），不要用条件判断
- **ArkTS 一个花括号错误可导致数千级联语法错误**，先看第一个错误位置
- **画面平移在 Stack Alignment.Center 基础上用 translate 偏移**，panOffset 范围是对称的 `[-(renderedSize-previewSize)/2, (renderedSize-previewSize)/2]`
- **遇到用户描述不清晰时必须先提问确认再动手**
- **HarmonyOS 调试日志**：hilog.info/warn 在设备上可能被隐私过滤不输出，只有 hilog.error 和 console.error 能可靠输出；用字符串拼接代替 `%{public}` 格式
- **OHOS SDK 中 Window 对象没有 `getWindowClassType()` 和 `isWindowKeepScreenOn()` 方法**
- **AvoidAreaType.TYPE_INPUT 不存在**：应使用 `window.AvoidAreaType.TYPE_KEYBOARD`
- **`TextAlign.CENTER` 不存在**：用 `TextAlign.Center`（大小写敏感）
- **`stopPropagation` 不存在于 ClickEvent**：用空 `.onClick(() => {})` 拦截
- **`alignItems` 不能用于 Stack**：用 `.alignContent()` 代替
- **`SliderChangeMode.OnChange` 不存在**：用 `SliderChangeMode.Moving`

## Native 桥接经验

- **C++ ABI 声明必须与 Rust `#[no_mangle] pub extern "C"` 导出签名完全一致**：参数数量不匹配在 C 调用约定下是未定义行为，不会编译报错但运行时参数错位。`sessionSendChat` 曾因 1参数 vs 4参数导致 content 错位到 peer_id 位置。
- **三层签名必须完全一致**：Rust `bridge_api.rs`、C++ `rustdesk_bridge_abi.h`、TS `NativeRustDeskBridge.ts`
- **staticlib + CMake 直接链接是 HarmonyOS 唯一可靠方案**，不要尝试 cdylib/dlopen
- **HarmonyOS dlopen 只能从 `/data/storage/el1/bundle/libs/arm64/` 加载**
- **缺失一个符号会导致整个 SO 加载失败**
- **TEXTREL 是 Rust/lld bug，无法从 Rust 侧修复**
- **close_success() 只能表示"连接成功提示关闭"**，不能映射成 session-closed
- **终端输出包含 ANSI/control bytes**，核心应 base64 编码为 `dataBase64`，App 侧用 `util.BaseC64Helper + TextDecoder` 解码
- **空音频队列必须返回 `[]`**，不要返回 `{}`；否则 App 远端音频轮询按数组解析时会反复异常
- **`captureRequired=true` 是"核心请求 App 启动录屏提供首帧"**，不是 `incomingReady`；共享 UI 真实运行态仍只能由 `incomingReady=true` 驱动
- **TS 文件不能 import ETS 文件**：跨层能力要拆成 `.ts` 服务
- **GitHub Actions Linux/Hvigor ArkTS strict 可能比本地更严格**：`map()` 回调里直接 `return { ... }` 触发 `arkts-no-untyped-obj-literals`，应先声明 `const item: SomeInterface = { ... }` 再返回
- **App 根目录下的 `13_librustdesk_core` 是 NTFS junction**，只用于浏览源码；核心构建必须从真实路径启动

## 连接/会话经验

- **connectToPeer 是异步发起连接，不代表连接已完成**：必须通过 `monitorConnectionWhileWaiting` 等待 `sessionStage === 'connected'` 后再导航
- **closeRequestedByUser 必须在新连接发起时无条件重置**
- **isPendingConnectionAlive 必须考虑 isConnecting 状态**：连接刚发起时 `sessionStage` 可能仍为 `idle`
- **ID卡片连接模式 per-card 化**：PreferenceStore 按 peerId 存储 connect mode；中继重连后自动更新为 relay
- **密码提示优先级必须高于自动关闭/重连逻辑**
- **session-closed 事件也需要检查密码需求**，不能只在 session-error 检查
- **连接成功前不弹重试，非人为断开才弹重试**
- **密码框触发条件不能依赖 isConnected，应依赖 hasReceivedFrame**
- **从最近会话/历史记录进入 RemoteControl 不经过 Index.handleConnect**，密码框逻辑必须在 RemoteControl 侧也完整
- **重连对话框最大 bug**：buildReconnectDialog() 定义了但从未在 build() 中渲染 → 在 Stack 中添加 `if(showReconnectDialog) buildReconnectDialog()`
- **syncBridgeState 中 showReconnectDialog=true && stage=connected && hasReceivedFrame=true 时会错误覆盖**，需加 `!sessionCloseRequestedLocally && !isRetryingConnection` 检查
- **msgbox 事件携带可重试断开文本时需弹重连框**，"Successful: Connected"不能触发重连
- **远端主动关闭（"Closed manually by the peer"）是正常断开**，不应弹重连框
- **删除 LAN 设备时必须调 `NativeRustDeskBridge.removeDiscoveredPeer()`** 清除 Rust 侧 LanPeers 文件
- **共享页 `isShareServiceRunning()` 只能表示真实被控服务 ready**：必须用 `settings.serviceEnabled && officialCoreState.incomingReady`
- **共享启动不要显式调用 `requestPermissionsFromUser(['ohos.permission.CUSTOM_SCREEN_CAPTURE'])`**；录屏授权由 native `OH_AVScreenCapture_StartScreenCapture` 在核心 ready 后触发
- **文件授权必须 picker-first**：`DocumentViewPicker` 是授权入口，普通权限位只是补充记录
- **ECONNRESET 被 isRetryableDisconnectText 识别**，应直接弹重连

## OHOS 被控端服务链路经验

- `TargetAddr` 不是 `Copy`，传给 `FramedSocket::send()` 需要用 `addr.clone()`
- `bytes::Bytes` 不实现 `Display`，用 `String::from_utf8_lossy()` 转换
- `SupportedEncoding` protobuf 没有 `vp9` 字段（只有 `h264`/`h265`/`vp8`/`av1`/`i444`）
- `call_vpx!` 宏在失败时 `return Err(...)`，函数签名必须返回 `Result` 类型
- `hbb_common::tcp::Stream` 不存在，正确类型是 `hbb_common::stream::Stream`
- `Config::get_relay_server()` 不存在，官方用 `Config::get_option("relay-server")` + fallback
- **避免启动 IPC（`ipc::start("")`）**，这是之前 appspawn 崩溃的主因
- **核心函数名称必须和官方保持一致**，不要自造函数名
- **Rust 侧 OHOS 特有问题：target_os="linux" 导致所有 android/ios 条件分支不生效，必须额外加 target_env="ohos" 条件**
- **Config::path() 和 Config::get_home() 的 cfg 条件加上 target_env="ohos"**，让 OHOS 走 APP_DIR 分支（LAN 发现最大根因）

## LAN 发现经验

- discoverLanPeers() 返回 true 只表示 native 调用成功，不代表发现了设备
- Rust log::info! 不输出到 OHOS hilog，诊断 LAN 问题需用 JS 侧 console.error
- OHOS 设备 ifconfig 确认 BROADCAST RUNNING 才能发 UDP 广播
- **SO_REUSEPORT 的 libc 直接调用在 OHOS 上会导致 bind 失败**，必须用标准 `UdpSocket::bind()`
- **create_broadcast_sockets() 中 OHOS 应通过 UDP connect 8.8.8.8:53 获取本机 IP 并绑具体 IP**
- **wait_response 中 MAC 过滤会误杀同设备不同客户端**，改为用 ID 过滤（p.id != my_id）
- **同设备 APK+HAP 并存时，OHOS→APK 发现不了是 Android 兼容层网络隔离限制**，非代码 bug
- 服务器设置不影响 LAN 发现（LAN 是纯 UDP 广播/响应），但影响 ID 注册和远程连接

## GitHub Actions CI 构建经验

- **SDK 包是完整 command-line-tools**：包含 `bin/`、`hvigor/`、`ohpm/`、`sdk/default/`、`tool/` 等，不是单独的 SDK 内容
- **路径映射**：`DEVECO_SDK_HOME` 指向 `sdk/default`（openharmony/hms 所在），`DEVECO_TOOLS_HOME` 指向 SDK 根目录（bin/hvigor/ohpm 所在）
- **不要用 `setup-harmonyos-sdk@0.2.1`**：它安装的 SDK 2.0.0.2 与私有 SDK 6.1.1 不兼容，且会被 `rm -rf` 清除
- **构建脚本必须尊重工作流设置的 `DEVECO_TOOLS_HOME`**：不要覆盖为 `$SDK_ROOT/command-line-tools`
- **签名密码是机器加密的**：`build-profile.json5` 中 `0000001B` 前缀的密码只能在本机解密，CI 必须构建 unsigned HAP
- **签名路径替换**：`sed` 只能替换已知路径模式，Windows 路径 `C:\\Users\\...` 需用 Python regex 替换所有 `certpath`/`profile`/`storeFile` 值
- **7z 解压**：SDK 包是 `.7z` 格式，需安装 `p7zip-full` 包，用 `7z x -y` 解压
- **SDK_ROOT 检测**：解压后查找含 `sdk/` 和 `bin/`/`hvigor/`/`ohpm/` 的目录作为 SDK 根

## 构建经验

- **构建安装必须全部用脚本**（bat/ps1），不要手动拼接 hdc 命令
- **代码修改必须改项目根源文件**：staging 只是构建副本，全量 robocopy 会从项目根覆盖 staging
- **hdc install 需从 HAP 所在目录执行**（Push-Location）
- **HDC `[Empty]` 不是设备**：脚本必须过滤
- **HDC 服务钝化导致设备丢失**：先 `hdc kill` + `hdc start` 重启 HDC 服务再重试
- **版本降级安装失败时**，需先 `hdc shell bm uninstall -n com.open.rundesk` 卸载旧版
- **签名文件名必须与 build-profile.json5 一致**
- **DEVECO_SDK_HOME 必须设置**：`C:\Program Files\Huawei\DevEco Studio\sdk\default`
- **JAVA_HOME 必须设置**：`C:\Program Files\Huawei\DevEco Studio\jbr`
- **deviceTypes 必须用 "phone"**
- **Hvigor 构建会修改 build-profile.json5**：构建过程会删除 signingConfigs 和 compileSdkVersion，需 save/restore
- **上游 Cargo.toml 的 scrap 依赖默认启用 wayland feature，OHOS 交叉编译必须禁用**
- **librustdesk_core.a 引入 wayland 依赖后 SO 的 NEEDED 会包含 libwayland-*.so**，OHOS 设备上不存在导致 dlopen 失败
- **x86_64 stub 模式**：CMakeLists.txt 通过 OHOS_ARCH 检测架构，无真实核心时编译 stub
- **模拟器安装**：x86_64 模拟器 `hdc shell uname -m` 返回 `x86_64`，HAP 必须包含 x86_64 ABI 的 .so
- **HAP 签名验证脚本的临时文件必须用 GUID 名**：固定文件名连续验包时可能被占用
- **fetch_native_core.ps1 远程失败时**，若本地核心已存在且通过校验，应复用本地核心继续构建

## UI/图标经验

- **画面平移边界限制**：clampPanOffset 限制偏移范围，左右最多到屏幕边缘一条缝(gap=4px)
- **键盘避让只平移画面不平移容器**：通过修改 panOffsetY 平移画面，而非用额外 computeKeyboardOffset 叠加
- **预览容器必须铺满到屏幕底部**：工具栏从 Column 流中移出改为 Stack 悬浮(zIndex)
- **buildOfficialConnectPanel 必须用 Column 不能用 Stack**：外层 Stack 会导致高度计算异常
- **旋转画面不要叠加系统旋转和组件旋转**：setLandscape() 已让系统旋转，viewRotation 保持 0
- **TextInput 默认焦点**：作为页面第一个可聚焦元素会自动获取焦点弹出输入法；将默认焦点放到底部连接 tab 图标
- **TextInput onBlur 焦点循环陷阱**：onBlur 中设 showKeyboard=false 会触发 UI 重排导致重新获取焦点→无限循环。延迟 300ms 再设
- **图标格式原则：不要重绘 SVG，根据图标自身格式选择着色方法**
  - fill 格式图标用 fillColor，stroke 格式图标用 colorFilter(BlendMode.SRC_IN)
  - 判断：SVG 有 fill 属性且无 stroke → fill 格式；有 stroke 属性且 fill="none" → stroke 格式
  - **stroke 格式 SVG 每个 path 必须显式 fill="none"**，OHOS 渲染器不正确继承会导致方块被填充
- **SVG 必须删除背景 path**（fill="none" 的 rect/path），防止 fillColor 填充背景
- **主题通过 AppStorage 管理颜色**，不使用标准 color.json 资源文件
- **i18n 使用 I18nService.translate() + @State i18nVersion 触发重渲染**
- **从 proicons 提取 SVG 后必须做属性去重验证**：浏览器能渲染不代表 OHOS 渲染器也能正确解析
- **OHOS 颜色格式不要手动拼接 alpha 前缀**，必须使用 `.opacity()` 方法设置透明度

## 核心项目架构

- **核心构建已迁移到独立项目 `13_librustdesk_core`**
- **核心修改流程**：13 项目修改 → git push → GitHub Actions 自动构建发布 → 11 项目构建脚本自动下载
- **核心 OHOS 文件**（13 项目 `src/harmony_bridge/`）：
  - `core.rs` — 主桥接层，HarmonyHandler 实现 InvokeUiSession
  - `server_ohos.rs` — OHOS 被控端完整实现
  - `rendezvous_mediator_ohos.rs` — OHOS 信令连接
  - `clipboard_ohos.rs`/`keyboard_ohos.rs`/`platform_ohos.rs` 等 — 平台适配
- **11 项目保留**：`entry/src/main/cpp/`（C++桥接层）、`entry/src/main/libs/arm64/librustdesk_core.a`
- **11 项目不再保留**：`native_rust_core/`、代码生成脚本（已迁移到 13 项目）

## 函数名映射（OHOS旧名→官方名）

| OHOS旧名 | 官方名 | 状态 |
|----------|--------|------|
| connect_to_peer | session_start | 旧名NAPI保留，底层调用新名 |
| set_incoming_service_enabled | main_start_service | 旧名NAPI保留，底层调用新名 |
| close_session | session_close | ✅已重命名 |
| reconnect_session | session_reconnect | ✅已重命名 |
| send_mouse_input | session_send_mouse | ✅已重命名 |
| send_chat_message | session_send_chat | ✅已重命名 |
| open_terminal | session_open_terminal | ✅已重命名 |
| start_file_transfer | session_send_files | ✅已重命名 |
| session_alternative_codecs | session_get_alternative_codecs | ✅已重命名 |
| refresh_session_video | session_refresh | 保留（OHOS特有） |
| apply_session_option | session_set_option | 保留（OHOS特有） |

## 官方架构参考（实现 OHOS 被控端时对照）

- `server.rs::Server` 有 `connections: ConnMap` + `services: HashMap<String, Box<dyn Service>>`
- `server.rs::accept_connection()` → `create_tcp_connection()` → `Connection::start()`
- `service.rs::Service` trait: name/on_subscribe/on_unsubscribe/is_subed/join/get_option/set_option/ok
- `connection.rs::Connection::start()` 创建 tx/rx channels，主循环 select!
- `video_service.rs::run()` 主循环：get_capturer → c.frame(spf) → encode → sp.send_video_frame()

## 环境迁移经验

- **签名密码需要重新加密**：p12 密码变更后，build-profile.json5 中的 keyPassword/storePassword 必须用密钥材料重新加密
- **keyAlias 必须与 p12 中实际别名一致**：用 `keytool -list -keystore xxx.p12 -storepass xxx` 查看
- **hvigor-config.json5 的路径模式**：仓库根配置默认用相对路径保持可携带；DevEco 同步失败时用 `switch_deveco_paths.ps1` 临时切绝对路径
- **PATH 修改在 Node.js 中会导致 spawn cmd.exe ENOENT**：必须在 bat 脚本中设置 PATH
