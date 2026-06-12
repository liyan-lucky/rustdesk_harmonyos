# AI 助手记忆文档

> 本文档记录 AI 助手的工作规则、项目经验、用户偏好和处理流程。每次新对话发送"读取文档"时，AI 必须先读本文，再按需读取其他文档。

## 工作规则（必须遵守）

### 1. 文档优先
- 每次处理问题前，先回顾 docs/ 下的经验文档，检查是否有相关经验存在
- 如果经验不存在，处理完问题后将经验保留到对应文档中
- 每次修改代码/资源/脚本/文档后，必须同步更新所有相关项目文档
- 文档阅读顺序：本文 → README.md → CORE.md → PROGRESS.md → ISSUES.md → DESIGN.md → UI.md → FILES.md
- **新对话启动规则**：用户发送"读取文档"时，AI 必须按文档阅读顺序读取所有文档，了解项目详细信息、要求、偏好和习惯，然后按工作规则执行后续任务

### 2. 构建验证
- 每轮修改后必须构建验证
- ArkTS/UI 修改：至少运行 HAP 构建 `scripts\build_hap.bat`
- 涉及 native core：先重编 native core，再构建 HAP
- 涉及设备行为：构建后优先 USB 安装启动验证
- 构建脚本不可用时，按构建逻辑安装构建脚本并修复
- 安装测试：每次修改后应进行安装测试验证

### 3. 经验记录
- 解决新问题后，将根因、解决方案和教训记录到 ISSUES.md
- 功能进度更新到 PROGRESS.md
- 核心架构变更更新到 CORE.md
- UI/设计变更更新到 DESIGN.md / UI.md
- 文件结构变更更新到 FILES.md

### 4. 修改原则
- 参考官方做法和标准实现方式
- 分析问题根因而非盲目重试
- 一步一步逐步调整而非一次修改多处
- 只修改明确要求的内容，不连带修改未提及的元素
- 理解有偏差时先询问核对而非直接修改

## 用户偏好

### UI 偏好
- 页面间配色一致性：核心页面与登录页的状态指示配色保持统一
- 图标和排序等 UI 元素颜色跟随主题适配，而非固定黑色
- 使用单个 SVG 图标通过外部 ArkTS 控制动画（如 rotate + animateTo），而非在 SVG 内嵌动画
- 核心选项卡状态显示简写，点击弹出的核心信息菜单中状态应显示详细描述
- 偏好使用中文交互，关注 app 中文翻译完整性，不希望出现中英混合显示问题

### 开发偏好
- 使用 ArkTS 进行 HarmonyOS 应用开发
- 多次追问"为何"时，希望 AI 解释遗漏或出错的原因
- 每次修改要及时更新所有对应文档

## 项目关键信息

### 项目概况
- 项目：RustDesk HarmonyOS 客户端
- 工作区：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- 包名：`com.open.rundesk`
- 当前本地版本：`0.13.30`，versionCode：`1000061`
- 上游兼容版本：RustDesk 1.4.7
- 核心架构：staticlib + CMake 直接链接

### 构建命令
- 增量构建 HAP：`scripts\build_hap.bat`
- 全量构建 HAP：`scripts\build_full_hap.bat`
- 一键构建安装：`scripts\AUTO_BUILD_INSTALL.bat auto`
- **核心构建已迁移到独立项目**：`%VSCODE_ROOT%\13_librustdesk_core`
- **核心下载**：`https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a`
- **核心 SHA256**：`A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`
- 重编 native core：在 13_librustdesk_core 项目中执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1`
- 项目备份：`powershell -ExecutionPolicy Bypass -File scripts\backup_project.ps1`

### 核心文件
- 主页面：`entry/src/main/ets/pages/Index.ets`
- 远程控制：`entry/src/main/ets/pages/RemoteControl.ets`
- 国际化：`entry/src/main/ets/services/I18nService.ets`
- NAPI 桥接：`entry/src/main/ets/services/NativeRustDeskBridge.ts`
- 数据管理：`entry/src/main/ets/services/AppDataService.ets`
- **核心项目**：`%VSCODE_ROOT%\13_librustdesk_core`（所有核心函数修改在此进行）
- Rust core：`13_librustdesk_core/rustdesk-master/src/harmony_bridge/core.rs`（363 pub fn）
- Rust ABI：`13_librustdesk_core/native_rust_core/src/bridge_api.rs`（369 导出函数）
- C++ 桥接：`13_librustdesk_core/cpp/rustdesk_bridge_loader.cpp`（约400 NAPI注册）
- C++ ABI 声明：`13_librustdesk_core/cpp/rustdesk_bridge_abi.h`
- TS 类型：`13_librustdesk_core/cpp/types/librustdesk_bridge/index.d.ts`
- 本项目 C++ 桥接（从核心项目同步）：`entry/src/main/cpp/`
- 本项目核心静态库（从 GitHub Releases 下载）：`entry/src/main/libs/arm64/librustdesk_core.a`

### 当前重点问题
1. 并行密码+无密码连接流程：已修复待实机验证（2026-06-07）
2. ECONNRESET 后重连对话框：已修复（2026-06-07）
3. LAN 发现不了设备：已修复并实机验证通过（2026-06-07）
4. 远端主动关闭会话：已修复（2026-06-07）
5. 中文输入法无法输入：已修复（2026-06-07）
6. 共享服务 ScreenCaptureService 当前 SDK 下不可用
7. 桥接函数已补齐至369个（2026-06-08）：从54个扩展至369个，覆盖官方APK绝大部分wire_*函数

### 已验证状态
- 最新 native core：`librustdesk_core.a`，138,394,514 bytes，SHA256 `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`
- 最新本地 HAP 构建时间：2026-06-12 02:57
- 最新线上 release：`https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-020111`
- coreReady=true，adapter=official-native
- LAN 发现实机验证通过
- 函数覆盖：core.rs 363 pub fn，bridge_api.rs 369 导出，NAPI 约400注册

## 经验库（按类别）

### ArkTS 开发经验
- Toggle isOn 值绑定导致异步权限请求期间回弹：onChange 中必须先同步 updateSettings 更新状态，再执行异步操作
- ForEach key 不应包含频繁变化的状态变量（如 accountRefreshTick），否则导致组件销毁重建
- HarmonyOS 调试日志必须用 hilog API，console.info 在设备上不输出
- ArkTS 一个花括号错误可导致数千级联语法错误，先看第一个错误位置
- animateTo({ iterations: -1 }) 在 ArkTS 中不生效，必须用 setInterval 驱动动画
- @State 角度变量绑定 rotate 始终绑定（角度0=不旋转），不要用条件判断

### Native 桥接经验
- C++ ABI header 声明的每个函数必须在 Rust bridge_api.rs 有对应 #[no_mangle] pub extern "C" 导出
- 缺失一个符号会导致整个 SO 加载失败
- staticlib + CMake 直接链接是 HarmonyOS 唯一可靠方案，不要尝试 cdylib/dlopen
- TEXTREL 是 Rust/lld bug，无法从 Rust 侧修复
- HarmonyOS dlopen 只能从 /data/storage/el1/bundle/libs/arm64/ 加载
- close_success() 只能表示"连接成功提示关闭"，不能映射成 session-closed

### 中文输入经验
- sendImeCommittedText() 对中文走 sendClipboardData() + sendPasteShortcut()（设剪贴板后发Ctrl+V）
- Rust 侧 send_clipboard_data() 原是空壳函数直接返回false，剪贴板内容没有同步到远端
- 修复：实现 send_clipboard_data()，构建 Clipboard protobuf 消息通过 session.send(Data::Message(msg)) 发送到远端
- Clipboard 结构体字段：compress: bool, content: bytes::Bytes, format: EnumOrUnknown<ClipboardFormat>, width/height: i32, special_name: String
- Clipboard 赋值方式：用结构体字面量 + ..Default::default()，format 用 ClipboardFormat::Text.into() 转为 EnumOrUnknown
- 参考 screenshot.rs 中 Clipboard 的用法模式

### 连接/会话经验
- 密码提示优先级必须高于自动关闭/重连逻辑
- session-closed 事件也需要检查密码需求，不能只在 session-error 检查
- 连接成功前不弹重试，非人为断开才弹重试
- OHOS 有独立的 rendezvous_mediator_ohos.rs，修改 LAN 逻辑时必须检查 OHOS 专用文件
- UDP ping 发出但无监听线程接收响应是 LAN 发现失效的典型症状
- 并行密码+无密码连接不能 await connectToPeer 后立即跳转，必须走 monitor 轮询
- 密码框触发条件不能依赖 isConnected，应依赖 hasReceivedFrame
- handleTerminalBridgeEvent 中密码框开着且没收到帧时应保持密码框，不弹重连
- applyBridgeState error/idle 分支中密码提示检查必须在重连/关闭判断之前
- 从最近会话/历史记录进入 RemoteControl 不经过 Index.handleConnect，密码框逻辑必须在 RemoteControl 侧也完整
- showReconnectDialogFromState 内部已调 prepareReconnectPromptSurface，不要重复调用
- openRemoteControlForPendingSession 内部先设 showPasswordDialog=false 再传参，密码框状态依赖参数传递链路完整性
- ECONNRESET 被 isRetryableDisconnectText 识别，shouldShowReconnectPromptNow 会返回 true，handleTerminalBridgeEvent 应直接弹重连
- 密码框被覆盖回 false 的常见原因：applyBridgeState connected 分支、monitorConnectionWhileWaiting 轮询、syncBridgeState 周期刷新
- **重连对话框最大bug：buildReconnectDialog()定义了但从未在build()中渲染，showReconnectDialog=true不会显示对话框，只显示statusText状态文本**
- **修复：在build()的Stack中添加 if(showReconnectDialog) buildReconnectDialog()**
- **syncBridgeState/applyBridgeState 中 showReconnectDialog=true && stage=connected && hasReceivedFrame=true 时会错误覆盖showReconnectDialog=false，需加 !sessionCloseRequestedLocally && !isRetryingConnection 检查保持重连框**
- **msgbox事件携带104错误时不被handleTerminalBridgeEvent处理（只处理session-error/session-closed/closed），需扩展msgbox处理：含可重试断开文本时弹重连框**
- **msgbox事件"Successful: Connected"不能触发重连框，handleTerminalBridgeEvent对msgbox需加isRetryableDisconnectText过滤**
- **远端主动关闭（"Closed manually by the peer"）是正常断开，不应弹重连框，应finishTerminalSession显示"会话已关闭"**
- **删除LAN设备时必须调NativeRustDeskBridge.removeDiscoveredPeer()清除Rust侧LanPeers文件，否则下次discover读回旧数据**

### LAN 发现经验
- LAN 发现 JS 层逻辑（LanDiscoveryService）与备份一致，问题通常在 native Rust 侧
- discoverLanPeers() 返回 true 只表示 native 调用成功，不代表发现了设备
- loadLanPeers() 返回 [] 表示 native 侧 LanPeers 存储（配置文件）中没有设备
- Rust 侧 discover() 流程：send_query() 发 UDP 广播 → spawn_wait_responses() 等响应 3 秒 → handle_received_peers() 写 LanPeers 存储
- 如果同一子网没有运行 RustDesk 的 PC，loadLanPeers() 自然返回空
- Rust log::info! 不输出到 OHOS hilog（Rust 侧没有 hilog 后端），诊断 LAN 问题需用 JS 侧 console.error 或 queue_event
- hilog %{public} 格式在 OHOS 5/6 上可能被隐私过滤不输出，用字符串拼接代替
- OHOS 设备 ifconfig 确认 BROADCAST RUNNING 才能发 UDP 广播
- default_net crate 在 OHOS 上可能获取不到网卡接口，create_broadcast_sockets() 只绑 0.0.0.0
- **LAN 发现最大根因：OHOS target_os="linux" 导致 Config::path() 走 directories_next 分支而非 APP_DIR 分支，LanPeers::store() 写入错误路径，LanPeers::load() 读不到数据**
- **修复：Config::path() 和 Config::get_home() 的 cfg 条件加上 target_env="ohos"，让 OHOS 走 APP_DIR 分支**
- **APP_HOME_DIR 也需要为 OHOS 定义（加 target_env="ohos" 到 cfg 条件）**
- OHOS 上 255.255.255.255 全局广播可能被系统拦截，需添加子网定向广播（如 192.168.11.255）
- OHOS 上 set_broadcast(true) 在 0.0.0.0 绑定的 socket 上可能失败，但广播仍可工作，应保留 socket
- OHOS 上 send_query() 的 id 必须用 Config::get_id()（ui_interface::get_id() 需要 flutter feature）
- 服务器设置不影响 LAN 发现（LAN 是纯 UDP 广播/响应，不经过服务器），但影响 ID 注册和远程连接
- **wait_response 中 MAC 过滤会误杀同设备不同客户端（APK和HAP共享MAC），改为用 ID 过滤（p.id != my_id）**
- **同设备 APK+HAP 并存时，OHOS→APK 发现不了是 Android 兼容层网络隔离限制，非代码 bug**：APK 的 pong 回复走兼容层网络栈，无法到达 OHOS 原生 socket
- SO_REUSEPORT 在 OHOS 上不能跨应用 UID 共享端口，同设备双客户端端口冲突是系统限制
- **SO_REUSEPORT 的 libc 直接调用在 OHOS 上会导致 start_listening() bind 失败，LAN listener 无法启动！必须用标准 UdpSocket::bind()**
- **create_broadcast_sockets() 中 OHOS 应通过 UDP connect 8.8.8.8:53 获取本机 IP 并绑具体 IP，而非只绑 0.0.0.0，这样同设备 APK 回复的 pong 才能路由到正确 socket**
- **删除LAN设备时必须调 NativeRustDeskBridge.removeDiscoveredPeer() 清除 Rust 侧 LanPeers 文件，否则下次 discover 读回旧数据**

### 构建经验
- U 盘上 .hvigor/、entry/build/、entry/.cxx/ 有权限残留，构建必须用 staging 副本
- staging 副本的 build-profile.json5 签名路径必须重新计算：项目根用 ../99_Temp/，staging 用 ./signing/ 并复制签名材料到 staging/signing/
- Hvigor 不允许签名路径在项目目录之外（如 ../../99_Temp/），必须用项目内相对路径
- 签名 material 目录必须与 .cer/.p12/.p7b 一起复制，否则 SignHap 报 "Signing material error"
- 99_Temp 下的签名文件名（default_rustdesk_harmonyos_...）与项目根（debug_hos.*）不同，需统一
- robocopy 排除 .cxx/build 目录避免 U 盘权限卡死，加 /R:0 /W:0 避免无限重试
- hdc install 路径拼接有 bug，需从 HAP 所在目录执行或用相对路径
- **关键：代码修改必须改项目根源文件！staging 只是构建副本，全量 robocopy 会从项目根覆盖 staging，导致修改丢失**
- 版本降级安装失败时，需先 `hdc shell bm uninstall -n com.open.rundesk` 卸载旧版，再安装新版
- 2026-06-09 官方一致性修复后实机验证通过：coreReady=true，Bridge 在线查询正常，远程控制连接建立（加密中继），handshake 诊断正常
- **关键：上游 Cargo.toml 的 scrap 依赖默认启用 wayland feature，OHOS 交叉编译必须禁用！** `scrap = { path = "libs/scrap" }` 不加 `features = ["wayland"]`
- **关键：arboard 依赖默认启用 wayland-data-control feature，OHOS 必须禁用！** `arboard = { git = "..." }` 不加 wayland features
- **关键：librustdesk_core.a 引入 wayland 依赖后，SO 的 NEEDED 会包含 libwayland-server.so/libwayland-client.so，OHOS 设备上不存在导致 dlopen 失败**
- CMakeLists.txt 添加 `-Wl,--as-needed` 可移除未使用的动态库依赖，但 wayland 符号引用仍在，必须从 Rust 侧排除
- 密码输入框 TextInput 需要添加 `.defaultFocus(true)` 才能自动唤醒输入法
- staging 的 material 目录不能混入项目根的旧 material 文件，签名会失败

### 编译经验
- OHOS 的 target_os = "linux"，所有 Linux 桌面端依赖必须显式排除
- build.rs 中 #[cfg(windows)] 基于 host 平台，交叉编译时需改为 CARGO_CFG_TARGET_OS 运行时检查
- Rust stable toolchain，nightly 与 rustix 0.37 不兼容
- libsodium 必须为 OHOS target 单独交叉编译
- RUSTFLAGS 必须指定 OHOS lld，避免错误调用 PATH 中的 ld.exe

### UI/图标经验
- fill 格式图标用 fillColor，stroke 格式图标用 colorFilter(BlendMode.SRC_IN)
- SVG 必须删除背景 path（fill="none" 的 rect/path），防止 fillColor 填充背景导致方块
- fill 格式图标 path 添加 fill="#000000"，stroke 格式添加 stroke="#000000"
- **stroke 格式 SVG 每个 path 必须显式 fill="none"，不能只靠根元素 fill="none" 继承，OHOS 渲染器不正确继承会导致方块被填充**
- stroke 格式平台图标（win/mac/linux）统一用 colorFilter(createStrokeIconColorFilter())，不用 fillColor
- fillColor 对 stroke 格式 SVG 会填充图形内部而非边线，必须用 colorFilter
- 图标颜色必须跟随主题变化，不固定为黑色
- 主题通过 AppStorage 管理颜色，不使用标准 color.json 资源文件
- i18n 使用 I18nService.translate() + @State i18nVersion 触发重渲染

### ArkTS API 兼容经验
- **AvoidAreaType.TYPE_INPUT 在 OHOS SDK 中不存在**：应使用 `window.AvoidAreaType.TYPE_KEYBOARD` 替代；`TYPE_INPUT` 是旧 API 名称，当前 SDK 已重命名为 `TYPE_KEYBOARD`
- 构建 ArkTS 时遇到 `Property 'XXX' does not exist on type 'typeof YYY'` 错误，通常是 API 名称变更或 SDK 版本不匹配，需查阅当前 SDK 对应的 API 文档

### 核心项目迁移经验
- **核心构建已迁移到独立项目 `13_librustdesk_core`**：所有 Rust 桥接层、C++ 桥接层、代码生成脚本均在此项目维护
- **核心修改流程**：在 13_librustdesk_core 修改 → git push → GitHub Actions 在线构建 → 下载 librustdesk_core.a → 放入 11 项目 `entry/src/main/libs/arm64/`
- **11 项目保留的核心相关文件**：`entry/src/main/cpp/`（C++桥接层，从13项目同步）、`entry/src/main/libs/arm64/librustdesk_core.a`（从 GitHub Releases 下载）
- **11 项目不再保留的核心相关文件**：`native_rust_core/`（已迁移到13项目）、`scripts/generate_*.js`/`dedup_*.js`/`regenerate_all.js`/`rename_mapping.js`（已迁移到13项目）
- **代码生成脚本路径修复**：所有硬编码的绝对路径已改为相对于 `__dirname`/`os.path` 的相对路径
- **CMakeLists.txt 路径适配**：13项目中 `librustdesk_core.a` 路径改为 `../native_rust_core/target/aarch64-unknown-linux-ohos/release/librustdesk_harmony_bridge.a`

### Linux 在线构建经验
- **当前可用 workflow**：`.github/workflows/build-harmonyos.yml`，固定构建 HAP + APP，输入为 `version_bump`、`skip_package_verify`、`publish_release`
- **SDK 拆包地址**：
  - `HARMONYOS_SDK_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
  - `HARMONYOS_HVIGOR_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
- **SDK 包必需文件**：`openharmony/previewer/common/bin/libcjson.so`、previewer `libsec_shared.so`、ets-loader `libsec_shared.so`；缺任意一个都可能导致 Linux CI Hvigor/previewer 失败
- **LD_LIBRARY_PATH 必须包含**：hms toolchains lib、openharmony previewer common/bin、ets-loader ark build/bin、openharmony toolchains、toolchains/lib、hms native sysroot lib
- **GitHub Release 上传规则**：HAP 直接上传；APP 先压缩为 `.app.zip` 再上传；同时生成 `manifest.json` 和 `SHA256SUMS.txt`
- **2026-06-12 成功 release**：`harmonyos-20260612-020111`

### 修改流程经验（本次会话最大教训）
- **代码修改必须改项目根源文件！staging 只是构建副本，全量 robocopy 会从项目根覆盖 staging，导致修改丢失**
- 修改后立即验证项目根源文件内容，不要只验证 staging
- 每次全量重构前，确认项目根源文件已包含所有修改
- LAN 发现不了设备的根因是 Config::path() 在 OHOS 上走了错误的分支（directories_next 而非 APP_DIR），导致 LanPeers store/load 路径不一致
- 密码框不弹出的根因是 handleConnect 中 await 后立即跳转跳过 monitor 轮询，不是同样的 staging 覆盖问题
- ECONNRESET 后无重连是 handleTerminalBridgeEvent 逻辑问题，已修复
- 版本降级安装失败时，需手动升 versionCode/versionName 超过设备上的版本
- **Rust 侧 OHOS 特有问题：target_os="linux" 导致所有 android/ios 条件分支不生效，必须额外加 target_env="ohos" 条件**

### 官方APK对比经验
- 官方 Android APK 使用 Flutter FFI 架构：单一 rustdesk_core_main + 365个 wire_* 导出函数
- HarmonyOS 使用 staticlib + CMake + NAPI 架构：369个 rustdesk_bridge_* C ABI 函数
- harmony_bridge/core.rs 有 363 个 pub fn，bridge_api.rs 有 369 个导出函数
- core.rs 中每个 pub fn 必须在 bridge_api.rs 有对应 #[no_mangle] pub extern "C" 导出
- core.rs 中每个 pub fn 必须在 loader.cpp 有 NAPI 包装和注册
- core.rs 中每个 pub fn 必须在 abi.h 有 C 声明
- core.rs 中每个 pub fn 必须在 index.d.ts 有 TS 类型声明
- **OHOS特有函数保留**：apply_session_option、mark_session_connected、mark_session_error、refresh_session_video等高层封装函数被ETS广泛使用，不能删除
- **官方名重命名规则**：main_use_texture_render→main_get_use_texture_render，account_auth→main_account_auth等
- **缺失函数添加流程**：core.rs添加stub → bridge_api.rs添加C ABI → abi.h添加声明 → loader.cpp添加NAPI包装和注册 → index.d.ts添加TS声明 → 编译验证
- **生成脚本bug**：generate_cpp_bridge.js不转换String→const char*，generate_bridge_api.js不转换*const c_char→read_c_string()，需手动修复

### 函数名映射（OHOS旧名→官方名）

| OHOS旧名 | 官方名 | 状态 |
|----------|--------|------|
| main_use_texture_render | main_get_use_texture_render | ✅已重命名 |
| account_auth | main_account_auth | ✅已重命名 |
| account_auth_cancel | main_account_auth_cancel | ✅已重命名 |
| account_auth_result | main_account_auth_result | ✅已重命名 |
| discover_lan_peers | main_discover | ✅已重命名 |
| load_lan_peers | main_load_lan_peers | ✅已重命名 |
| remove_discovered_peer | main_remove_discovered | ✅已重命名 |
| close_session | session_close | ✅已重命名 |
| reconnect_session | session_reconnect | ✅已重命名 |
| restart_remote_device | session_restart_remote_device | ✅已重命名 |
| lock_remote_screen | session_lock_screen | ✅已重命名 |
| send_ctrl_alt_del | session_ctrl_alt_del | ✅已重命名 |
| read_remote_directory | session_read_remote_dir | ✅已重命名 |
| create_remote_directory | session_create_dir | ✅已重命名 |
| send_chat_message | session_send_chat | ✅已重命名 |
| send_mouse_input | session_send_mouse | ✅已重命名 |
| open_terminal | session_open_terminal | ✅已重命名 |
| send_terminal_input | session_send_terminal_input | ✅已重命名 |
| resize_terminal | session_resize_terminal | ✅已重命名 |
| close_terminal | session_close_terminal | ✅已重命名 |
| start_file_transfer | session_send_files | ✅已重命名 |
| session_alternative_codecs | session_get_alternative_codecs | ✅已重命名(2026-06-08) |
| connect_to_peer | session_start | ✅旧名NAPI保留，底层调用新名C函数(2026-06-08) |
| set_incoming_service_enabled | main_start_service | ✅旧名NAPI保留，底层调用新名C函数(2026-06-08) |
| refresh_session_video | session_refresh | 保留（OHOS特有高层封装） |
| apply_session_option | session_set_option | 保留（OHOS特有高层封装，被ETS广泛使用） |
| mark_session_connected | session_start | 保留（OHOS特有高层封装） |
| main_option_synced | option_synced | 保留（OHOS特有） |

### 2026-06-08 大规模函数补齐经验

- 从54个桥接函数扩展至369个，覆盖官方APK绝大部分wire_*函数
- 添加了完整的cm_*(11个)、plugin_*(13个)、install_*(5个)、is_*(12个)函数族
- 添加了34个缺失的session_*函数（session_add_job/session_get_audit_guid/session_handle_screenshot等）
- 添加了main_init函数（官方初始化入口，接受app_dir和custom_client_config）
- 重命名main_use_texture_render→main_get_use_texture_render与官方对齐
- 生成脚本(generate_cpp_bridge.js/generate_bridge_api.js/generate_ts_bridge.js)有bug：
  - bridge_api.rs中字符串参数不调用read_c_string()转换，直接传*const u8
  - abi.h中Rust String类型不转换为const char*
  - loader.cpp中字符串参数不调用ReadUtf8String提取
  - 每次用生成脚本后需手动检查并修复这些问题
- 修复模式：bridge_api.rs中`path`→`read_c_string(path)`，abi.h中`String`→`const char *`，loader.cpp中`path`→`ReadUtf8String(env, args[n], &path_str); ... path_str.c_str()`
- 构建验证：Rust编译成功 + HAP构建成功 + 安装成功 + 启动成功（设备锁屏除外）

### 2026-06-08 官方一致性验证经验

- **abi.h旧式声明清理**：abi.h中同时存在两套命名（旧式如send_mouse_input和新式如session_send_mouse），旧式声明在bridge_api.rs中无实现，会导致链接时unresolved symbol。虽然--unresolved-symbols=ignore-all绕过链接检查，但运行时调用旧名NAPI函数会崩溃。必须清理旧式声明。
- **main_init extern "C" 位置**：C++中extern "C"块外的函数声明会经过name mangling，导致链接符号名不匹配（_Z25rustdesk_bridge_main_initPKcS0_ vs rustdesk_bridge_main_init）。所有C ABI声明必须在extern "C" {}块内。
- **旧名NAPI保留策略**：ArkTS层大量使用旧名（connectToPeer、setIncomingServiceEnabled等），修改ArkTS调用名成本太高。策略：保留旧名NAPI注册，但底层C函数调用改为新名实现。这样ArkTS无需修改，C ABI层与官方一致。
- **session_alternative_codecs→session_get_alternative_codecs**：官方flutter_ffi.rs中函数名为session_get_alternative_codecs，OHOS缺少get_前缀。全链路更新：core.rs→bridge_api.rs→abi.h→loader.cpp→index.d.ts→NativeRustDeskBridge.ts→librustdesk_bridge.d.ts。
- **官方一致性验证流程**：(1)提取bridge_api.rs所有#[no_mangle]函数名；(2)提取abi.h所有extern "C"声明名；(3)提取loader.cpp所有NAPI注册名；(4)提取index.d.ts所有TS声明名；(5)提取官方flutter_ffi.rs所有pub fn名；(6)集合差运算找缺失/多余；(7)逐层修复。

## 文档更新记录

| 日期 | 更新内容 |
|------|---------|
| 2026-06-07 | 初始创建，汇总所有项目文档信息 |
| 2026-06-07 | 修复并行密码+无密码连接流程、ECONNRESET重连提示；添加连接/会话经验 |
| 2026-06-07 | 修复win图标着色(fillColor→colorFilter)、SVG path显式fill="none")；添加修改流程经验 |
| 2026-06-07 | 修复LAN发现：Config::path()加OHOS条件走APP_DIR分支、APP_HOME_DIR为OHOS定义、子网定向广播、诊断queue_event；实机验证通过 |
| 2026-06-07 | 修复重连对话框：buildReconnectDialog未渲染到UI、syncBridgeState/applyBridgeState覆盖showReconnectDialog、msgbox事件处理、远端主动关闭区分、LAN设备删除清Rust缓存、SO_REUSEPORT导致LAN listener失败、具体IP绑定 |
| 2026-06-07 | 修复中文输入法：send_clipboard_data()从空壳实现为发送Clipboard protobuf消息，参考screenshot.rs用法模式 |
| 2026-06-07 | 新增工作规则：新对话"读取文档"触发全文档读取；构建脚本不可用时安装构建脚本逻辑；每次修改后安装测试验证 |
| 2026-06-07 | 对比官方APK(365个wire_函数)与当前核心(48个bridge函数)，补齐6个缺失函数：getSessionStage/getActivePeerId/getConnectStatusSummary/getConnectDetailMessage/getConnectLastError/drainConnectEvents；NAPI注册升至58个(54桥接+4工具)；更新CORE.md完整函数说明 |
| 2026-06-08 | 大规模函数补齐：从54个扩展至369个桥接函数，覆盖官方APK绝大部分wire_*函数；添加cm_*/plugin_*/install_*/is_*/session_*全系列；重命名main_use_texture_render→main_get_use_texture_render；添加main_init；修复生成脚本bug（String→const char*、read_c_string、ReadUtf8String）；全面重写CORE.md桥接函数说明（31个分类、369个函数详细描述）；更新函数名映射表 |
| 2026-06-08 | 官方一致性验证修复：(1)abi.h删除28个旧式命名声明（set_incoming_service_enabled/connect_to_peer/send_mouse_input等），只保留新式session_*/main_*命名；(2)main_init声明从extern "C"块外移入块内，修复C++ name mangling问题；(3)添加drain_connect_events缺失声明；(4)loader.cpp中ConnectToPeer改为调用rustdesk_bridge_session_start、SetIncomingServiceEnabled改为调用rustdesk_bridge_main_start_service；(5)session_alternative_codecs→session_get_alternative_codecs与官方对齐（bridge_api.rs/core.rs/loader.cpp/index.d.ts/NativeRustDeskBridge.ts/librustdesk_bridge.d.ts全链路更新）；(6)HAP构建验证通过 |
| 2026-06-12 | 修复AvoidAreaType.TYPE_INPUT→TYPE_KEYBOARD（OHOS SDK API重命名）；HAP构建验证通过（20.67MB）；更新AGENT_MEMORY添加ArkTS API兼容经验 |
| 2026-06-12 | 核心项目迁移：所有核心相关文件（Rust桥接层、C++桥接层、代码生成脚本）迁移到13_librustdesk_core项目；核心构建流程改为在13项目修改→GitHub Actions在线构建→下载librustdesk_core.a→放入11项目libs；修复所有生成脚本的硬编码路径为相对路径；CMakeLists.txt路径适配13项目结构；更新README/AGENT_MEMORY/CORE文档 |
| 2026-06-12 | Linux 在线构建跑通：拆分 SDK/Hvigor 包地址，补齐 previewer `libcjson.so`/`libsec_shared.so`，设置 `LD_LIBRARY_PATH`，使用 RustDesk 1.4.7 OHOS core A200A839...AADC8，HAP/APP 发布到 `harmonyos-20260612-020111`，APP 以 `.app.zip` 上传 |
