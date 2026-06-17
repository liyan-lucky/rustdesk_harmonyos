# AI 助手记忆文档

> 本文档记录 AI 助手的工作规则、项目经验、用户偏好和处理流程。每次新对话发送"读取文档"时，AI 必须先读本文，再按需读取其他文档。

## 工作规则（必须遵守）

### 1. 文档优先
- 每次处理问题前，先回顾 docs/ 下的经验文档，检查是否有相关经验存在
- 如果经验不存在，处理完问题后将经验保留到对应文档中
- 每次修改代码/资源/脚本/文档后，必须同步更新所有相关项目文档
- 文档阅读顺序：本文 → README.md → CORE.md → PROGRESS.md → ISSUES.md → UI.md → FILES.md
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
- UI/设计变更更新到项目根 README.md（设计要求） / UI.md
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
- 质量显示菜单名称统一2个字（尺寸/帧率/延迟/速度/连接/缩放/编码），标签宽度压缩到最小，值列layoutWeight自适应
- 画面平移严格边界约束：不允许黑边、空白区域或背景漏出，边缘到达极限位置后不可继续拖动
- OS Password 需要记住密码（按 peerId 持久化到 PreferenceStore）
- 所有显示文本必须走 `this.lt()` 国际化，禁止硬编码中文字符串

### 开发偏好
- 使用 ArkTS 进行 HarmonyOS 应用开发
- 多次追问"为何"时，希望 AI 解释遗漏或出错的原因
- 每次修改要及时更新所有对应文档

## 项目关键信息

### 项目概况
- 项目：RustDesk HarmonyOS 客户端
- 工作区：`%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- 包名：`com.open.rundesk`
- 当前本地版本：`0.23.17`，versionCode：`1000140`
- 上游兼容版本：RustDesk 1.4.7
- 核心架构：staticlib + CMake 直接链接

### 构建命令
- 增量构建 HAP：`scripts\build_hap.bat`
- 全量构建 HAP：`scripts\build_full_hap.bat`
- 一键构建安装：`scripts\AUTO_BUILD_INSTALL.bat auto`
- **核心构建已迁移到独立项目**：`%VSCODE_ROOT%\13_librustdesk_core`
- **核心默认下载**：`https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- 当前本地核心 SHA256**：core-9（线上最新），132,720,900 bytes；本地构建核心 129,943,444 bytes（含事件去重修复）
- **最新核心更新**：13 核心 `core-9` 已发布，包含：1) OHOS 被控端完整连接链路（Service/ServiceTmpl/Subscriber、video_service、Connection::start、accept_connection/create_relay_connection、密码验证）；2) 重连稳定性修复（SEC30 30s→60s、SEND_TIMEOUT_VIDEO 12s→30s + 5次重试）；3) Connecting 状态拒绝重连修复（`ConnectionState::Connecting => self.send(Data::Close)`）；4) 设备指纹不显示修复（`Config::get_id()` 替换 `get_local_option("id")`、`pk_to_fingerprint` 计算指纹、`gen_id`/`get_auto_id` cfg 加 `target_env = "ohos"`、`initialize_runtime` 设置 `APP_DIR` 后调用 `get_id()` + `get_key_pair()`、`main_init` 调用 `initialize_runtime`）。本地核心额外修复：5) `set_peer_info` 不再重复触发 `session-connected` 事件（去掉 else 分支冗余 `update_connect_state`）。11 App 已用本地核心构建 `0.23.9` / versionCode `1000132`。
- **2026-06-15 v0.22.8 修复**：1) `setIncomingServiceEnabled` 增加回退到 `mainStartService`/`main_start_service`/`rustdesk_bridge_main_start_service`，修复函数名不匹配导致共享服务无法启动的问题；2) `connectToPeer` 增加回退到 `sessionStart`/`session_start`/`rustdesk_bridge_session_start`；3) 共享页 `serviceEnabled` 时即显示 ID 和密码，未就绪时显示"核心被控视频源未就绪"；4) 聊天时间戳移到消息上方居中显示，格式改为微信风格（今天 HH:MM / 昨天 HH:MM / MM-DD HH:MM / YYYY-MM-DD HH:MM）
- 重编 native core：在 13_librustdesk_core 项目中执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1`
- 项目备份：`powershell -ExecutionPolicy Bypass -File scripts\backup_project.ps1`

### 核心文件
- 主页面：`entry/src/main/ets/pages/Index.ets`
- 远程控制：`entry/src/main/ets/pages/RemoteControl.ets`
- 国际化：`entry/src/main/ets/services/I18nService.ets`
- NAPI 桥接：`entry/src/main/ets/services/NativeRustDeskBridge.ts`
- 数据管理：`entry/src/main/ets/services/AppDataService.ets`
- **核心项目**：`%VSCODE_ROOT%\13_librustdesk_core`（所有核心函数修改在此进行）
- Rust core：`13_librustdesk_core/rustdesk-master/src/harmony_bridge/core.rs`（1500+ pub fn，含 HarmonyHandler 完整 InvokeUiSession 实现、main_start_service 5参数版、apply_server_options）
- Rust ABI：`13_librustdesk_core/native_rust_core/src/bridge_api.rs`（374 导出函数）
- C++ 桥接：`13_librustdesk_core/cpp/rustdesk_bridge_loader.cpp`（约400 NAPI注册）
- C++ ABI 声明：`13_librustdesk_core/cpp/rustdesk_bridge_abi.h`
- TS 类型：`13_librustdesk_core/cpp/types/librustdesk_bridge/index.d.ts`
- 本项目 C++ 桥接（从核心项目同步）：`entry/src/main/cpp/`
- 本项目核心静态库（从 GitHub Releases 下载）：`entry/src/main/libs/arm64/librustdesk_core.a`

### 核心 OHOS 文件（13 项目）
- `src/harmony_bridge/core.rs` — 主桥接层，HarmonyHandler 实现 InvokeUiSession，main_start_service 5参数版，apply_server_options
- `src/harmony_bridge/server_ohos.rs` — OHOS 被控端完整实现：Server/ConnInner/Connection、Service trait/ServiceTmpl/Subscriber、video_service、Connection::start、accept_connection/create_relay_connection、密码验证（verify_h1/validate_password），从146行stub扩展到1461行
- `src/harmony_bridge/rendezvous_mediator_ohos.rs` — OHOS 信令连接，register_peer/register_pk，PunchHole/RequestRelay 处理，create_relay
- `src/harmony_bridge/ipc_ohos.rs` — OHOS IPC 替代（不可用，bail）
- `src/harmony_bridge/clipboard_ohos.rs` — OHOS 剪贴板
- `src/harmony_bridge/clipboard_master_ohos.rs` — OHOS 剪贴板监控
- `src/harmony_bridge/keyboard_ohos.rs` — OHOS 键盘
- `src/harmony_bridge/platform_ohos.rs` — OHOS 平台
- `src/harmony_bridge/ui_interface_ohos.rs` — OHOS UI 接口
- `src/harmony_bridge/clipboard_file_ohos.rs` — OHOS 文件剪贴板
- `src/harmony_bridge/mod.rs` — 模块声明（pub mod core; pub use self::core::*;）
- `libs/scrap/src/common/harmony_bridge/codec_ohos.rs` — OHOS VPX 编解码器（Encoder/Decoder，base_bitrate，Quality）
- `libs/scrap/src/common/harmony_bridge/ohos.rs` — OHOS Capturer/Display/PixelBuffer（从 incoming frame cache 读帧）
- `libs/scrap/src/common/harmony_bridge/record_ohos.rs` — OHOS 录制 stub
- `libs/scrap/src/common/harmony_bridge/mod.rs` — 模块声明（pub mod ohos;）
- `src/lib.rs` — OHOS 条件编译路由（9处 `#[cfg(target_env = "ohos")]`）

### 当前重点问题
1. **C++ OH_AVScreenCapture 无法获取帧**（P0级，搁置待调研）：`OH_CAPTURE_HOME_SCREEN` 模式在非系统应用上无法工作——`StartScreenCapture` 返回成功但服务端状态不是 STARTED（`state:1`），`AcquireVideoBuffer` 持续失败。根因是 `ohos.permission.CAPTURE_SCREEN` 是系统核心权限（system_core），普通应用无法声明。`OH_CAPTURE_SPECIFIED_SCREEN` 也需要此权限。**解决方案**：改用 ArkTS 层 `@ohos.screenCapture` API 获取帧，通过 NAPI 传给核心。C++ 层已增加 `video_buffer_ready` 原子变量等待回调，但回调从未触发。
2. **远程连接后自动回到连接页面**（已修复）：根因1——核心侧 `set_peer_info` 的 else 分支重复调用 `update_connect_state("connected", ...)` 导致大量重复 `session-connected` 事件涌入；根因2——App 侧 `handleTerminalBridgeEvent` 中 `peerClosed` 时直接 `finishTerminalSession`，但连接可能还没真正建立（`hasReceivedFrame=false`）；根因3——App 侧密码弹窗在连接已建立后仍会被重复事件触发。修复：核心去掉 else 分支冗余调用、App 侧 `peerClosed && hasReceivedFrame` 才关闭会话、密码弹窗渲染层加 `!hasReceivedFrame && !isConnected` 硬性守卫。
3. **设备指纹不显示**（已修复）：6处修复，本地构建验证通过。
4. **Connecting 状态拒绝重连**（已修复）：`ConnectionState::Connecting => self.send(Data::Close)`。
5. **自动重连机制**（已实现）：App 侧三处 msgbox 处理增加 `retry=true` 自动重连。

### 已验证状态
- 当前本地 native core：本地构建 `librustdesk_core.a`，129,943,444 bytes（含事件去重修复）；线上 core-9 `132,720,900` bytes
- 最新线上 native core release：`https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-9`
- 最新本地构建版本：`0.23.9`，versionCode `1000132`，构建时间 `2026-06-17`
- 2026-06-17 core-9 + 本地核心修复验证：11 App 下载 core-9 后构建 `0.23.8`，验证设备指纹正确显示（`6b3c ef42 ...`）；随后本地核心修复 `set_peer_info` 事件去重 + App 侧修复 `peerClosed` 不再直接关闭会话 + 密码弹窗渲染层硬性守卫，构建 `0.23.9`，无线安装启动成功。
- 2026-06-14 core-74 无线安装验证通过：`192.168.11.100:36169` install bundle successfully，`bm dump` 显示 `versionName=0.19.0`、`versionCode=1000090`；手动解锁后 `aa start` 成功，进程 `4232` 20 秒后仍存活，hilog 确认 `coreReady= true`、`query-onlines-result` 正常，app fatal/panic/signal 为 0。
- 2026-06-14 文档更新后复核：手机再次解锁后执行 `scripts\AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.100:36169`，安装与启动均成功；`pidof com.open.rundesk` 返回 `12565`，`reports/hilog_latest_after_core74_post_docs_unlocked.txt` 记录 `coreReady= true` 7 次、`query-onlines-result` 14 次、app log lines 314，app fatal/panic/signal 为 0。
- 2026-06-14 core-76 全量构建和安装验证：`scripts\build_full_hap.bat` 下载 latest core-76 并构建 `0.20.0` / versionCode `1000096`；signed HAP `18,909,325` bytes，SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`；验包通过，`192.168.11.100:36169` 安装成功且 `bm dump` 显示 `0.20.0`。当前设备密码锁屏导致 `aa start` 返回 `Error Code:10106102`，运行态 hilog 待手动解锁后继续。
- 2026-06-15 最新无线安装验证：USB-only 安装脚本/文档变更重新构建后，`scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 已把 `0.20.4` / versionCode `1000100` 安装并启动到 `192.168.11.100:36169`；`bm dump -n com.open.rundesk` 确认版本一致，`pidof com.open.rundesk` 返回 `29101`，signed HAP `18,917,915` bytes，SHA256 `D14C9DECF5199277F0AB7E97BBFCDF540BACEB06BCDA3AB74581F09A4CBF3CDB`；`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 与 `audit_connection_chain.ps1` 均通过。
- 2026-06-15 核心源项目缺陷修复与 core-78 验证：13 核心项目 `cpp/rustdesk_bridge_abi.h`/`rustdesk_bridge_loader.cpp` 曾仍是一参 `rustdesk_bridge_session_send_chat(content)`，与 Rust 四参 ABI 不一致；核心 d.ts 也缺自建服务器 `key` 参数。已修正并本地构建通过，commits `034e446`、`cc5f4de` 已推送，线上 run `27515510727` 已发布 `core-78`。11 App 下载后全量构建 `0.21.0` / versionCode `1000102`，无线安装到 `192.168.11.100:36169` 并启动成功，进程 `41841` 存活，hilog `coreReady` 14 次、`query-onlines-result` 20 次，app fatal/panic/signal/`exit(-1)` 为 0。
- 2026-06-15 core-79 远控 direct session 命令验证：13 核心 commit `bc36b1d` 已由 run `27516993020` 发布 `core-79`，release body 已补中文说明；11 App 拉取 core-79 后全量构建 `0.22.0` / versionCode `1000103`，signed HAP `18,929,896` bytes / SHA256 `C8EB6B133B71752F50447410DE3E9DECC0BDE3EFD3630E8CBA9AB015E3A39F96`；验包、连接链路审计和无线安装启动通过，设备端进程 `56136` 存活，app-only hilog `coreReady=187`、`query-onlines-result=366`，fatal/panic/signal/`exit(-1)` 均为 0。
- 2026-06-15 共享/文件授权复查：11 App 增量构建 `0.22.1` / versionCode `1000104`，signed HAP `18,953,784` bytes / SHA256 `F16398FCB29E9E4F24131602D7B03C7BEED0A88BE0C37463BC7238AFF4C31A06`；共享启动不再预申请 `CUSTOM_SCREEN_CAPTURE`，文件传输页与 `requestFileAccessAuthorization()` 改为 `DocumentViewPicker` 目录授权。验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端进程 `56711` 存活。
- 2026-06-15 共享录屏底层切换复查：11 App 增量构建 `0.22.2` / versionCode `1000105`，signed HAP `18,946,878` bytes / SHA256 `9F4C40E9B10BE4D88BA5B76A24C887B1A8586F1A2812619CDC48C843C97DE1DA`；`ScreenCaptureService` 不再使用 `AVScreenCaptureRecorder` 或临时 mp4 探测文件，改为 native `OH_AVScreenCapture_StartScreenCapture` + `OH_AVScreenCapture_AcquireVideoBuffer` 统计。验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端进程 `62121` 存活。
- 2026-06-15 core-80 入站帧缓存复查：13 核心 commit `12ad723` 已由 run `27526413545` 发布 `core-80`，release body 已补中文说明；11 App 强制拉取线上 core-80 后增量构建 `0.22.4` / versionCode `1000107`，signed HAP `18,968,380` bytes / SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`；`OH_NativeBuffer` payload 已推入核心 `incoming_screen_frame` 缓存，但 `incomingReady` 仍保持 false。验包、66 项连接链路审计、无线安装启动和干净 app hilog 均通过，设备端进程 `14881` 存活。
- 2026-06-15 CI strict/中文摘要修正复查：push 后 Linux run `27528204491` 和发布 run `27528218065` 曾因 `PermissionService.ets:173` 未显式对象字面量失败；已改为显式 `PermissionRequestResult` 并修正聊天摘要错字。11 App 强制拉取线上 core-80 后增量构建 `0.22.5` / versionCode `1000108`，signed HAP `18,968,203` bytes / SHA256 `05E86D1D2900D3D0F873113B28338EB468B36AF4063461476D7E87C4A49D726A`；验包、66 项链路审计、无线安装启动和干净 app hilog 均通过，设备端进程 `20911` 存活。
- 2026-06-15 v0.22.6/core-81 本地预发布复查：13 核心本地构建 `128,894,588` bytes / SHA256 `2DC3B655664B756E255684D28FBA0CB3A9DEC14E6080EA4682FA26486ADF9B6D`；11 App 使用本地 staticlib 构建 `0.22.6` / versionCode `1000109`，signed HAP `18,433,473` bytes / SHA256 `4D669584F44B6462F570747723E66EB2894204FF7860CA0FBB27339D7FCE7DDD`。文件授权改为 picker-first；共享启动由 `captureRequired` 触发 native 录屏提供首帧，但 `incomingReady` 仍严格表示真实服务 ready。验包、66 项审计、无线安装启动和干净 app hilog 均通过，设备端进程 `7527` 存活。
- 2026-06-17 core-6 被控端连接链路验证：13 核心实现 OHOS 被控端完整连接链路（Service/ServiceTmpl/Subscriber、video_service、Connection::start、accept_connection/create_relay_connection、密码验证）+ 重连稳定性修复；CI 经3轮修复（EncoderApi私有引用→子模块类型引用→Frame导入）后构建成功，run `27662916996` 发布 `core-6`，线上 asset `132,744,466` bytes / SHA256 `C9435DD89B4A0FC2DA5D502E307EDC5AD9B94A095C7D593B1DD6DD48A57C36FC`；11 App 全量构建 `0.23.0` / versionCode `1000123`，signed HAP `19,254,376` bytes。实机验证待进行。
- 最新线上 App release：`https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/OpenRustdesk-Build-v0.22.7`
- 最新线上 App workflow：push run `27567811582` 成功，release run `27568044749` 成功；线上 signed HAP `20,870,632` bytes / SHA256 `ce62df82dd5167f9d31b34c0e2b88c869ed947a05214ca156fc3eeab9ff76fe3`，unsigned HAP `20,790,546` bytes / SHA256 `024ca74d649c305e8598ab36bf57a27e7f54869cd5c584f4d35798a89e008e98`，release notes 已补中文说明。
- coreReady=true，adapter=official-native
- LAN 发现实机验证通过
- 函数覆盖：core.rs 367 pub fn，bridge_api.rs 374 导出，NAPI 约400注册

## 经验库（按类别）

### 术语约定
- **TAB** = 底部主菜单4项（连接/聊天/共享/设置），对应 `currentTab: HomeTab`
- **选项卡** = ID输入框下方的子选项（历史/收藏/发现/通讯录/登录/核心），对应 `currentConnectTab: ConnectTab`
- 两处经常混淆，必须严格区分

### ArkTS 开发经验
- Toggle isOn 值绑定导致异步权限请求期间回弹：onChange 中必须先同步 updateSettings 更新状态，再执行异步操作
- direct session function 不能只看 NAPI 函数存在：必须确认 Rust bridge、C ABI、C++ NAPI、d.ts、ArkTS wrapper、UI 调用路径全部返回/消费同一个 bool，并检查核心事件是否回流到页面状态。
- ForEach key 不应包含频繁变化的状态变量（如 accountRefreshTick），否则导致组件销毁重建
- HarmonyOS 调试日志必须用 hilog API，console.info 在设备上不输出
- hilog.info/hilog.warn 在设备上也不输出（OHOS 5/6 隐私过滤），只有 hilog.error 和 console.error 能输出
- hilog %{public} 格式在 OHOS 5/6 上可能被隐私过滤不输出，用字符串拼接代替
- OHOS SDK 中 Window 对象没有 `getWindowClassType()` 和 `isWindowKeepScreenOn()` 方法，不要在诊断代码中使用不存在的 API
- ArkTS 一个花括号错误可导致数千级联语法错误，先看第一个错误位置
- ArkTS 画面平移在 Stack Alignment.Center 基础上用 translate 偏移，panOffset 范围是对称的 `[-(renderedSize-previewSize)/2, (renderedSize-previewSize)/2]`，不是 `[previewSize-renderedSize, 0]`
- animateTo({ iterations: -1 }) 在 ArkTS 中不生效，必须用 setInterval 驱动动画
- @State 角度变量绑定 rotate 始终绑定（角度0=不旋转），不要用条件判断
- **@Builder 方法中不能有 const/let 声明**（arkts-no-obj-literals-as-types），必须内联调用或用接口类型
- **对象字面量不能作为类型声明**（arkts-no-obj-literals-as-types），必须定义 interface
- **遇到用户描述不清晰时必须先提问确认再动手**，避免理解偏差导致错误修改

### Native 桥接经验
- C++ ABI header 声明的每个函数必须在 Rust bridge_api.rs 有对应 #[no_mangle] pub extern "C" 导出
- 缺失一个符号会导致整个 SO 加载失败
- staticlib + CMake 直接链接是 HarmonyOS 唯一可靠方案，不要尝试 cdylib/dlopen
- TEXTREL 是 Rust/lld bug，无法从 Rust 侧修复
- HarmonyOS dlopen 只能从 /data/storage/el1/bundle/libs/arm64/ 加载
- close_success() 只能表示"连接成功提示关闭"，不能映射成 session-closed
- 终端入口必须全链路确认，不能只看 ArkTS 页面存在：13 项目 `session_open_terminal/session_send_terminal_input/session_resize_terminal/session_close_terminal` 曾仍是 `false` stub，已改为 official `Session` 调用。
- 终端输出包含 ANSI/control bytes，不能直接塞进 session event JSON；核心应 base64 编码为 `dataBase64`，App 侧用 `util.Base64Helper + TextDecoder` 解码。
- 同时发 `terminal-response` 和 `terminal-output` 时，`TerminalService` 作为唯一数据入口，页面只处理 opened/error/closed，避免重复输出。
- 空音频队列必须返回 `[]`，不要返回 `{}`；否则 App 远端音频轮询按数组解析时会反复异常。
- 本地音频上传当前没有采样数据 ABI（只有 metadata），UI 不能显示“已开启”或启动麦克风假成功；应提示 `Audio upload unavailable`。
- `SendChatMessage`/`SessionSendChat` 对四参调用应读 `args[2]` 作为 content，并保留一参旧调用 fallback；13 核心项目和 11 App 项目的 C++ bridge 要保持一致。
- **C++ ABI 声明必须与 Rust `#[no_mangle] pub extern "C"` 导出签名完全一致**：参数数量不匹配在 C 调用约定下是未定义行为，不会编译报错但运行时参数错位。`rustdesk_bridge_session_send_chat` 的 Rust ABI 是4参数（peer_id, message_type, content, timestamp），但 App 的 C++ 头文件声明和调用只有1参数，导致 content 参数错位到 _peer_id 位置，核心读到空内容。
- App 根目录下的 `13_librustdesk_core` 是 NTFS junction，只用于浏览源码；核心构建必须从真实 `%VSCODE_ROOT%\13_librustdesk_core` 路径启动，否则脚本会把 build root 推导到 `11_Rustdesk_harmonyos\99_Temp` 并找不到 vcpkg installed root。
- `stage_project_for_build.ps1` 必须排除 `13_librustdesk_core` 并使用 robocopy `/XJ`，否则 staging 会复制核心项目 `.git/refs/codex/...` 深路径，后续清理可能因长路径/只读 Git object 失败。
- `backup_project.ps1` 也必须排除 `13_librustdesk_core` 并使用 robocopy `/XJ`；性能优化前备份要以脚本退出码为准，不能只看 zip 文件是否生成。
- `fetch_native_core.ps1` 远程 HEAD/下载失败时，若本地 `librustdesk_core.a` 已存在且通过大小/SHA校验，应复用本地核心继续构建；不能把网络不可达误当成本地核心不可用。
- 临时 USB 安装测试使用 `scripts\AUTO_BUILD_INSTALL.bat --skip-build usb`；该模式只选不含冒号的本地 HDC 目标并跳过无线重试。若输出 `[Empty]`，说明当前电脑未识别 USB 设备。
- 临时调试策略：`Debug Keep Screen Awake` 当前默认开启，并有一次性迁移 `debug_keep_screen_awake_default_on_20260615`，目的是避免安装/启动验证时设备自动锁屏；用户手动关闭后不能被后续启动覆盖。
- HAP 签名验证脚本的证书/profile 提取临时文件必须用唯一名；固定 `cert-chain.cer`/`profile.p7b` 连续验包时可能被旧进程占用，导致把工具清理问题误判成签名失败。
- `captureRequired=true` 是“核心请求 App 启动录屏提供首帧”，不是 `incomingReady`；共享 UI 的真实运行态、TAB 绿点、设备 ID 和一次性密码展示仍只能由 `incomingReady=true` 驱动。
- 文件传输对接要同时审计调用方向和回调方向：核心 `InvokeUiSession` 必须发 app 监听的 `folder-files/job-progress/job-done/job-error` 等事件；app 本地文件列表不能使用示例种子数据，必须来自真实文件系统路径。
- 未接通 official session 的页面入口必须禁用或提示不可用；例如 View Camera 不能只靠页面本地状态设置 `isConnected=true`，否则会把未实现功能伪装成已连接。
- TS 文件不能 import ETS 文件；需要被 `CoreLoaderService.ts` 等 TS 模块调用的跨层能力要拆成 `.ts` 服务，例如 `FileAuthorizationService.ts` 负责文件授权，`PermissionService.ets` 只做 ArkTS/页面层封装。
- GitHub Actions 上的 Linux/Hvigor ArkTS strict 可能比本地更严格；`map()` 回调里直接 `return { ... }` 容易触发 `arkts-no-untyped-obj-literals`，应先声明 `const item: SomeInterface = { ... }` 再返回。线上日志末尾只有 worker exit 时，要下载完整 job log 搜索 `ArkTS Compiler Error`。

### 中文输入经验
- sendImeCommittedText() 对中文走 sendClipboardData() + sendPasteShortcut()（设剪贴板后发Ctrl+V）
- Rust 侧 send_clipboard_data() 原是空壳函数直接返回false，剪贴板内容没有同步到远端
- 修复：实现 send_clipboard_data()，构建 Clipboard protobuf 消息通过 session.send(Data::Message(msg)) 发送到远端
- Clipboard 结构体字段：compress: bool, content: bytes::Bytes, format: EnumOrUnknown<ClipboardFormat>, width/height: i32, special_name: String
- Clipboard 赋值方式：用结构体字面量 + ..Default::default()，format 用 ClipboardFormat::Text.into() 转为 EnumOrUnknown
- 参考 screenshot.rs 中 Clipboard 的用法模式

### 连接/会话经验
- **ID卡片连接模式per-card化**：PreferenceStore新增peer_connect_modes存储，getPeerConnectMode/setPeerConnectMode按peerId读写；中继重连后自动更新per-peer模式为relay；菜单其他功能已确认per-card
- **native connectToPeer无forceRelay参数**：首次连接中继通过临时关闭enableDirectIp实现；reconnectSession(forceRelay)有显式参数
- 密码提示优先级必须高于自动关闭/重连逻辑
- session-closed 事件也需要检查密码需求，不能只在 session-error 检查
- 等待视频流要先区分方向：出站控制端看 `session-connected`/`peer-info`/`video-frame`，入站被控端看 `ScreenCaptureService` 和 native incoming 是否真的有视频源。当前 App 侧可用 `OH_AVScreenCapture_StartScreenCapture` 启动原生屏幕采集并统计 native buffer，但没有真实 Harmony 录屏帧接入 RustDesk desktop server 时，必须返回 `incomingReady=false` 并回滚共享开关，不能用 ready 状态让远端无限等待。
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
- 共享页 `isShareServiceRunning()` 只能表示真实被控服务 ready：必须用 `settings.serviceEnabled && officialCoreState.incomingReady`。本机 `ScreenCaptureService.isCapturingActive()` 只能作为本机采集状态，不能驱动“服务运行中”、共享 TAB 绿点、设备 ID 或一次性密码展示。
- ArkTS `AVScreenCaptureRecorder`/临时 mp4 只能算历史探测方案，当前共享录屏不得再使用它；App 侧已切到 C++ NAPI `OH_AVScreenCapture_StartScreenCapture`，通过 `AcquireVideoBuffer`/native buffer map 统计帧。真实共享链路仍要把帧 payload 接入 RustDesk desktop server/video source 后再标记 incoming ready。
- 共享启动不要显式调用 `requestPermissionsFromUser(['ohos.permission.CUSTOM_SCREEN_CAPTURE'])`；该权限在系统上会表现为截屏/屏幕捕获授权，和真实录屏采集弹窗混在一起。当前只保留 manifest 声明，录屏授权由 native `OH_AVScreenCapture_StartScreenCapture` 在核心 ready 后触发。
- 文件授权必须 picker-first：`DocumentViewPicker` 是文件/目录 URI 授权入口，普通权限位只是补充记录；`READ_WRITE_DOWNLOAD_DIRECTORY` 或 `FILE_ACCESS_PERSIST` 未立即 granted 不能让授权函数提前返回，否则文件管理页不会唤醒授权弹窗。
- 文件管理/文件传输页不能只依赖远控入口提前授权；页面进入、切到本地、刷新本地、上传/下载、本地新建/删除前都要走 `DocumentViewPicker` 目录授权。`PermissionService.requestFileAccessAuthorization()` 默认使用 `{ folder: true, authMode: true }`，聊天/导入这类选单文件仍直接调用 `requestFileAuthorization({ maxSelectNumber: 1 })`。
- 密码框被覆盖回 false 的常见原因：applyBridgeState connected 分支、monitorConnectionWhileWaiting 轮询、syncBridgeState 周期刷新

### OHOS 被控端服务链路经验
- `TargetAddr` 不是 `Copy`，传给 `FramedSocket::send()` 需要用 `addr.clone()`
- `bytes::Bytes` 不实现 `Display`，用 `String::from_utf8_lossy()` 转换
- `Server::id_count` 是私有字段，需要 `pub id_count` 或构造函数
- `SupportedEncoding` protobuf 没有 `vp9` 字段（只有 `h264`/`h265`/`vp8`/`av1`/`i444`），不能写 `encoding.vp9`
- `with_context()` 需要 `use hbb_common::anyhow::Context` trait import
- `call_vpx!` 宏在失败时 `return Err(...)`，函数签名必须返回 `Result` 类型
- `hbb_common::tcp::Stream` 不存在，正确类型是 `hbb_common::stream::Stream`
- `NatType::from_i32()` 需要 `use hbb_common::protobuf::Enum as _` trait import
- `Config::get_relay_server()` 不存在，官方用 `Config::get_option("relay-server")` + fallback
- `VpxEncoder` 的 `id`/`ctx`/`width`/`height`/`yuvfmt` 是私有字段，`calc_q_values`/`bitrate`/`get_yuvfmt`/`create_frame` 是私有方法
- 避免启动 IPC（`ipc::start("")`），这是之前 appspawn 崩溃的主因
- **核心函数名称必须和官方保持一致**，不要自造函数名
- **下次再改核心时需要重读核心文件**，用户做了些更新（OHOS 文件全部移到 `harmony_bridge/` 子目录）
- **构建安装必须全部用脚本**（bat/ps1），不要手动拼接 hdc 命令
- **版本自增功能已存在且正常工作**：`run_hvigor_with_sdk_patch.js` 的 `bumpVersionName()` 处理 incremental/full 模式

### 官方架构参考（实现 OHOS 被控端时对照）
- `server.rs::Server` 有 `connections: ConnMap` + `services: HashMap<String, Box<dyn Service>>`
- `server.rs::new()` 初始化时添加 audio_service、display_service、clipboard_service 等
- `server.rs::add_connection()` 遍历 services 调用 `on_subscribe(conn)`
- `server.rs::accept_connection()` → `accept_connection_()` → `create_tcp_connection()` → `Connection::start()`
- `server.rs::create_relay_connection()` → `create_relay_connection_()` → 连接 relay server → `create_tcp_connection()`
- `service.rs::Service` trait: name/on_subscribe/on_unsubscribe/is_subed/join/get_option/set_option/ok
- `service.rs::Subscriber` trait: id()/send()
- `service.rs::ServiceTmpl<T>` 实现 Service，含 repeat()/run() 启动服务线程
- `connection.rs::Connection::start()` 创建 tx/rx channels，构造 Connection，on_open()，主循环 select!
- `connection.rs::ConnInner` 实现 Subscriber，send() 按 VideoFrame/SwitchDisplay 走 tx_video
- `video_service.rs::new()` 创建 VideoService + GenericService::run()，run() 从 Capturer 读帧编码推送
- `video_service.rs::run()` 主循环：get_capturer → c.frame(spf) → encode → sp.send_video_frame()
- **重连对话框最大bug：buildReconnectDialog()定义了但从未在build()中渲染，showReconnectDialog=true不会显示对话框，只显示statusText状态文本**
- **修复：在build()的Stack中添加 if(showReconnectDialog) buildReconnectDialog()**
- **syncBridgeState/applyBridgeState 中 showReconnectDialog=true && stage=connected && hasReceivedFrame=true 时会错误覆盖showReconnectDialog=false，需加 !sessionCloseRequestedLocally && !isRetryingConnection 检查保持重连框**
- **msgbox事件携带104错误时不被handleTerminalBridgeEvent处理（只处理session-error/session-closed/closed），需扩展msgbox处理：含可重试断开文本时弹重连框**
- **msgbox事件"Successful: Connected"不能触发重连框，handleTerminalBridgeEvent对msgbox需加isRetryableDisconnectText过滤**
- **远端主动关闭（"Closed manually by the peer"）是正常断开，不应弹重连框，应finishTerminalSession显示"会话已关闭"**
- **删除LAN设备时必须调NativeRustDeskBridge.removeDiscoveredPeer()清除Rust侧LanPeers文件，否则下次discover读回旧数据**
- 质量监控浮层解析和渲染要分层：`applyQualityStatus()` 负责更新 `qualityMetricItems` 缓存，`buildConnectionInfoPanel()` 只渲染基础 7 行和缓存动态行，避免打开面板时重复解析 detail。

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
- **构建安装必须全部用脚本**：Windows 上 bat/ps1 脚本均可，不要手动拼接 hdc 命令；HAP 构建用 `scripts\build_hap.bat`/`build_full_hap.bat`，安装验证用 `scripts\AUTO_BUILD_INSTALL.bat`，核心构建用 `scripts\build_native_bridge.ps1`
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
- **99_Temp 签名文件名与 build-profile.json5 引用名不匹配**：99_Temp 下实际文件名为 `default_rustdesk_harmonyos_XXX=.cer/p12/p7b`，但 build-profile.json5 引用 `debug_hos.cer/p12/p7b`。需手动复制/重命名为 debug_hos.*，否则 SignHap 报 "Invalid storeFile value"
- **直接在项目根构建（RUSTDESK_HARMONY_DISABLE_STAGE=1）时签名路径 `../99_Temp/` 可正确解析**，但前提是签名文件名必须匹配
- **Staged build 签名路径必须在 staged 项目内**：`stage_project_for_build.ps1` 需要把 `99_Temp/rustdesk_harmonyos_signing` 复制到 staged `signing/`，并把 staged `build-profile.json5` 的签名路径改为 `./signing/`；不要把项目根配置永久改成绝对路径。
- **HDC `[Empty]` 不是设备**：`hdc list targets` 无设备时输出 `[Empty]`，脚本必须过滤入参、`RUSTDESK_HARMONY_USB_TARGET`、无线目标和 fallback 列表中的 `[Empty]`。
- **HDC服务钝化导致设备丢失**：无线设备在线但`hdc list targets`显示`[Empty]`时，应先`hdc kill`+`hdc start`重启HDC服务再重试连接，不要直接判定设备不在线。AUTO_BUILD_INSTALL.bat已在无线目标未找到和安装失败时自动重启HDC服务重试。

### 编译经验
- OHOS 的 target_os = "linux"，所有 Linux 桌面端依赖必须显式排除
- build.rs 中 #[cfg(windows)] 基于 host 平台，交叉编译时需改为 CARGO_CFG_TARGET_OS 运行时检查
- Rust stable toolchain，nightly 与 rustix 0.37 不兼容
- libsodium 必须为 OHOS target 单独交叉编译
- RUSTFLAGS 必须指定 OHOS lld，避免错误调用 PATH 中的 ld.exe

### UI/图标经验
- **画面平移边界限制**：clampPanOffset方法限制画面偏移范围，左右最多到屏幕边缘一条缝(gap=4px)，竖向显示时左右可缩小到屏幕边缘；横竖屏切换时需重新计算边界
- **键盘避让只平移画面不平移容器**：键盘弹出时通过修改panOffsetY平移画面（模拟双指向上拖动），而非用额外computeKeyboardOffset叠加；键盘关闭时恢复preKeyboardPanOffsetY；只有工具栏键盘按钮激活时才触发平移(imeProxyFocused)，其他方式激活键盘不触发
- **键盘平移计算逻辑**：distanceFromBottom=画面底部到屏幕底部的距离；distanceFromBottom<=0(画面超出屏幕底部)→推整个键盘高度；0<distanceFromBottom<kbH→推kbH-distanceFromBottom；distanceFromBottom>=kbH→不平移
- **预览容器必须铺满到屏幕底部**：工具栏从Column流中移出改为Stack悬浮(zIndex)，预览区layoutWeight(1)占满整个Stack高度；这样previewHeight就是到屏幕底部的真实距离，distanceFromBottom计算才正确
- **Row中子项用layoutWeight而非width('100%')**：Row中多个子项如果每个都设width('100%')，只有第一个可见（每个都占满整行）；应该用layoutWeight(1)让子项平分宽度
- **buildOfficialConnectPanel必须用Column不能用Stack**：外层用Stack会导致连接面板高度计算异常，底部tab栏只显示一个tab；悬浮窗用.overlay()属性实现，不影响Column流式布局
- **ForEach的key必须随内容变化**：ForEach([this.i18nVersion],...)的key不随currentTab变化时，tab切换不会重建组件；但改用currentTab作key也可能有问题，保持原始i18nVersion作key即可（ForEach渲染函数是响应式的，currentTab变化会触发重渲染）
- **旋转画面不要叠加系统旋转和组件旋转**：setLandscape()已让系统旋转屏幕90度，viewRotation=90又让画面.rotate({angle:90})再旋转90度，叠加为180度；用isLandscapeMode状态跟踪，viewRotation保持0
- **ID输入框默认焦点**：TextInput作为页面第一个可聚焦元素会自动获取焦点弹出输入法；将默认焦点放到底部连接tab图标(focusControl.requestFocus)，避免输入法自动弹出
- **TextInput onBlur焦点循环陷阱**：onBlur中设showKeyboard=false会触发UI重排，布局变化可能导致TextInput重新获取焦点→系统键盘再次弹出→形成无限循环。解决方案：onBlur中延迟300ms再设showKeyboard=false，且检查imeProxyFocused是否仍为false才执行；不要在onBlur中用requestFocus恢复焦点
- **键盘关闭按钮状态不同步**：onBlur延迟300ms设showKeyboard=false，但按钮点击时showKeyboard可能仍为true（延迟未生效），导致按钮判断逻辑错误。修复：按钮点击时检查`showKeyboard || imeProxyFocused`，同时直接设imeProxyFocused=false和imeProxyDismissRequested=true并调用clearFocus()
- **工具栏展开时底部避让**：用margin({ bottom: avoidNavigationBarHeight })替代expandSafeArea，与收起时一致避让底部导航栏
- **图标格式原则：不要重绘SVG，根据图标自身格式选择着色方法**
- fill格式图标用fillColor，stroke格式图标用colorFilter(BlendMode.SRC_IN)
- 判断规则：SVG有fill属性且无stroke→fill格式；有stroke属性且fill="none"→stroke格式
- fill格式图标 path 必须有 `fill="#000000"`，stroke格式 path 必须有 `stroke="#000000"` + 显式 `fill="none"`
- 平台图标格式：win/mac=stroke(colorFilter)，android/linux=fill(fillColor)
- `buildThemedPlatformIcon` 通过 `isFillPlatformIcon()` 自动分流：android/harmony/linux/ubuntu 用 fillColor，win/mac/ios 用 colorFilter
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
- **核心修改流程**：在 13_librustdesk_core 修改 → git push → GitHub Actions（Windows runner）自动构建并发布 latest → 11 项目构建脚本自动下载 librustdesk_core.a → 放入 11 项目 `entry/src/main/libs/arm64/`
- **也可本地构建**：在 13_librustdesk_core 项目中执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1`
- **本地核心链接**：`11_Rustdesk_harmonyos/13_librustdesk_core` 是 NTFS Junction，指向同级 `%VSCODE_ROOT%\13_librustdesk_core`；该链接只方便从 App 项目内访问核心仓库，已加入 `.git/info/exclude`，不要提交为仓库文件
- **当前核心下载规则**：11 项目构建前默认强制刷新 `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`；只有需要固定版本时才设置 `RUSTDESK_CORE_URL` 和 `RUSTDESK_CORE_SHA256` → **已改为智能检测**：通过 HTTP HEAD 请求比对 ETag/Content-Length/Last-Modified，线上核心无变化时跳过下载，有变化才下载覆盖；元数据缓存到 `99_Temp/librustdesk_core/librustdesk_core.meta.json`；`-Force` 参数仍可强制下载
- **11 项目保留的核心相关文件**：`entry/src/main/cpp/`（C++桥接层，从13项目同步）、`entry/src/main/libs/arm64/librustdesk_core.a`（从 GitHub Releases 下载）
- **11 项目不再保留的核心相关文件**：`native_rust_core/`（已迁移到13项目）、`scripts/generate_*.js`/`dedup_*.js`/`regenerate_all.js`/`rename_mapping.js`（已迁移到13项目）
- **代码生成脚本路径修复**：所有硬编码的绝对路径已改为相对于 `__dirname`/`os.path` 的相对路径
- **CMakeLists.txt 路径适配**：13项目中 `librustdesk_core.a` 路径改为 `../native_rust_core/target/aarch64-unknown-linux-ohos/release/librustdesk_harmony_bridge.a`

### Linux 在线构建经验
- **当前可用 workflow**：`.github/workflows/build-harmonyos.yml`，固定构建 HAP-only，输入为 `version_bump`、`skip_package_verify`、`publish_release`
- **SDK 拆包地址**：
  - `HARMONYOS_SDK_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
  - `HARMONYOS_HVIGOR_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
- **SDK 包必需文件**：`openharmony/previewer/common/bin/libcjson.so`、previewer `libsec_shared.so`、ets-loader `libsec_shared.so`；缺任意一个都可能导致 Linux CI Hvigor/previewer 失败
- **LD_LIBRARY_PATH 必须包含**：hms toolchains lib、openharmony previewer common/bin、ets-loader ark build/bin、openharmony toolchains、toolchains/lib、hms native sysroot lib
- **GitHub Release 上传规则**：当前线上脚本 HAP-only，只上传 `.hap`；不要再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。
- **线上发布前置检查**：如果 push workflow 或 release workflow 失败，先用 `gh api /repos/<owner>/<repo>/actions/jobs/<job_id>/logs` 保存完整 job log，再搜索 `ArkTS Compiler Error`/`ERROR:`；短日志常被 Hvigor DEBUG 输出淹没。
- **2026-06-12 历史成功 release**：`harmonyos-20260612-020111`
- **2026-06-13 core release**：13 项目 run `27459455573` 成功，发布 `core-70`，asset `librustdesk_core.a` 为 131,263,476 bytes，SHA256 `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- **2026-06-13 设备验证状态**：core-70 构建 HAP 通过，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，`192.168.11.100:36169` 安装成功；但 `aa start` 被锁屏阻止，`Error Code:10106102`，应用未运行，本轮无法验证 `coreReady`/`video-frame`
- **2026-06-14 core release**：13 项目 commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 推送后，GitHub Actions run `27483922931` 成功发布 `core-71`，asset `librustdesk_core.a` 为 131,297,004 bytes，SHA256 `C750A785297AA22A2518B158BF334A1B1415C4E0739E01D0856C8BB5D450E15C`
- **2026-06-14 设备验证状态**：11 项目下载 core-71 后增量/全量 HAP 构建通过，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，`192.168.11.100:36169` 安装启动成功；`bm dump` 显示 `versionName=0.17.0`、`versionCode=1000087`，hilog `coreReady= true`、在线查询和 LAN 发现正常，app fatal/panic/signal 为 0。
- **2026-06-14 core release**：13 项目 commit `275b231e11aefd4a2e51050fc74fbdeba9c566bd` 推送后，GitHub Actions run `27485061967` 成功发布 `core-73`，asset `librustdesk_core.a` 为 131,471,532 bytes，SHA256 `E444D739EC958CD1485519FE0A712BFC1F074B60EEA65D71552E7E95A909A7B1`
- **2026-06-14 设备验证状态**：11 项目下载 core-73 后全量 HAP 构建通过，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，signed HAP 18,828,338 bytes / SHA256 `F40E44646D8DB6A561559B1815E812FB8D4B85FDA0D8D2073DBDC26648AC5DB4`，`192.168.11.100:36169` 安装成功；设备锁屏阻止启动，`pidof com.open.rundesk` 为空，`reports/hilog_latest_after_core73_locked.txt` 无 app runtime 证据。
- **2026-06-14 core release**：13 项目 commit `1b987914a2c27ace376e5af45a9c6790d84d40b4` 推送后，GitHub Actions run `27486100946` 成功发布 `core-74`，asset `librustdesk_core.a` 为 131,471,786 bytes，SHA256 `3755D448FBB1A583E7B5F7C3C6ADEC29D8AF0FBB7E5DD192251CD18A68C45D7C`
- **2026-06-14 设备验证状态**：11 项目下载 core-74 后全量 HAP 构建通过，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，signed HAP 18,828,000 bytes / SHA256 `4BF796ED37DD1FCADF455F1585A55E36CFFC58940235D82FCAC55C6CBA6042A1`，`192.168.11.100:36169` 安装成功；手动解锁后启动成功，`pidof com.open.rundesk` 返回 `4232`，`reports/hilog_latest_after_core74_unlocked.txt` 记录 `coreReady= true` 5 次、`query-onlines-result` 6 次、app fatal/panic/signal 为 0。
- **2026-06-14 复装复启状态**：文档更新后手机再次解锁，skip-build 安装启动成功，进程 `12565` 存活；`reports/hilog_latest_after_core74_post_docs_unlocked.txt` 记录 `coreReady= true` 7 次、`query-onlines-result` 14 次、app log lines 314，app fatal/panic/signal 为 0。
- **2026-06-14 core release**：13 项目 commits `3afa229`（自建服务器 key）和 `1f474fc`（聊天事件语义）分别发布为 `core-75` / `core-76`；`core-76` asset `librustdesk_core.a` 为 131,470,712 bytes，SHA256 `AA4E99EBBE794C979348E2B1C0CAFDDE7B846703398B2D1146E84DDF5640130F`。
- **2026-06-14 设备验证状态**：11 项目下载 core-76 后全量 HAP 构建通过，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，signed HAP 18,909,325 bytes / SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`，`192.168.11.100:36169` 安装成功；设备锁屏阻止启动，`aa start` 返回 `Error Code:10106102`，运行态待解锁后复测。

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
- HarmonyOS 使用 staticlib + CMake + NAPI 架构：374个 rustdesk_bridge_* C ABI 函数
- harmony_bridge/core.rs 有 367 个 pub fn，bridge_api.rs 有 374 个导出函数
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

- 从54个桥接函数扩展至374个，覆盖官方APK绝大部分wire_*函数
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
| 2026-06-15 | v0.22.6/core-81 本地预发布：核心新增 `captureRequired` 与 OHOS incoming frame source，App 文件授权改为 picker-first，验包脚本签名临时文件改为 GUID 名；本地构建、验包、66 项审计、无线安装和干净 hilog 均通过。 |
| 2026-06-15 | v0.22.7/core-81 线上核心：core-81 已由 run `27563925971` 发布，11 App 强制下载线上 asset 构建 `0.22.7`，确认录屏不再唤起截屏 API，文件授权 picker-first，验包、66 项审计、无线安装和干净 hilog 均通过。 |
| 2026-06-07 | 初始创建，汇总所有项目文档信息 |
| 2026-06-07 | 修复并行密码+无密码连接流程、ECONNRESET重连提示；添加连接/会话经验 |
| 2026-06-07 | 修复win图标着色(fillColor→colorFilter)、SVG path显式fill="none")；添加修改流程经验 |
| 2026-06-07 | 修复LAN发现：Config::path()加OHOS条件走APP_DIR分支、APP_HOME_DIR为OHOS定义、子网定向广播、诊断queue_event；实机验证通过 |
| 2026-06-07 | 修复重连对话框：buildReconnectDialog未渲染到UI、syncBridgeState/applyBridgeState覆盖showReconnectDialog、msgbox事件处理、远端主动关闭区分、LAN设备删除清Rust缓存、SO_REUSEPORT导致LAN listener失败、具体IP绑定 |
| 2026-06-07 | 修复中文输入法：send_clipboard_data()从空壳实现为发送Clipboard protobuf消息，参考screenshot.rs用法模式 |
| 2026-06-07 | 新增工作规则：新对话"读取文档"触发全文档读取；构建脚本不可用时安装构建脚本逻辑；每次修改后安装测试验证 |
| 2026-06-07 | 对比官方APK(365个wire_函数)与当前核心(48个bridge函数)，补齐6个缺失函数：getSessionStage/getActivePeerId/getConnectStatusSummary/getConnectDetailMessage/getConnectLastError/drainConnectEvents；NAPI注册升至58个(54桥接+4工具)；更新CORE.md完整函数说明 |
| 2026-06-08 | 大规模函数补齐：当时从54个扩展至369个桥接函数，覆盖官方APK绝大部分wire_*函数；添加cm_*/plugin_*/install_*/is_*/session_*全系列；重命名main_use_texture_render→main_get_use_texture_render；添加main_init；修复生成脚本bug（String→const char*、read_c_string、ReadUtf8String）；后续已继续扩展到374个导出函数。 |
| 2026-06-08 | 官方一致性验证修复：(1)abi.h删除28个旧式命名声明（set_incoming_service_enabled/connect_to_peer/send_mouse_input等），只保留新式session_*/main_*命名；(2)main_init声明从extern "C"块外移入块内，修复C++ name mangling问题；(3)添加drain_connect_events缺失声明；(4)loader.cpp中ConnectToPeer改为调用rustdesk_bridge_session_start、SetIncomingServiceEnabled改为调用rustdesk_bridge_main_start_service；(5)session_alternative_codecs→session_get_alternative_codecs与官方对齐（bridge_api.rs/core.rs/loader.cpp/index.d.ts/NativeRustDeskBridge.ts/librustdesk_bridge.d.ts全链路更新）；(6)HAP构建验证通过 |
| 2026-06-12 | 修复AvoidAreaType.TYPE_INPUT→TYPE_KEYBOARD（OHOS SDK API重命名）；HAP构建验证通过（20.67MB）；更新AGENT_MEMORY添加ArkTS API兼容经验 |
| 2026-06-12 | 核心项目迁移：所有核心相关文件（Rust桥接层、C++桥接层、代码生成脚本）迁移到13_librustdesk_core项目；核心构建流程改为在13项目修改→GitHub Actions在线构建→下载librustdesk_core.a→放入11项目libs；修复所有生成脚本的硬编码路径为相对路径；CMakeLists.txt路径适配13项目结构；更新README/AGENT_MEMORY/CORE文档 |
| 2026-06-12 | Linux 在线构建跑通（历史规则）：拆分 SDK/Hvigor 包地址，补齐 previewer `libcjson.so`/`libsec_shared.so`，设置 `LD_LIBRARY_PATH`，使用 RustDesk 1.4.7 OHOS core A200A839...AADC8，HAP/APP 发布到 `harmonyos-20260612-020111`，APP 以 `.app.zip` 上传；当前规则已改为 HAP-only |
| 2026-06-12 | 新对话读取全部文档，构建验证通过（版本0.13.32，HAP 20.68MB）；修复签名文件名不匹配问题（default_rustdesk_harmonyos_XXX= → debug_hos.*）；更新AGENT_MEMORY版本和签名经验 |
| 2026-06-12 | 按新要求改为构建前自动下载 latest native core：默认 `releases/latest/download/librustdesk_core.a`；当日验证 core 127,130,498 bytes / SHA256 `AA9C1A2D...1C17FCB5`；线上脚本 HAP-only，不再生成 APP/manifest/SHA；修复 staged 签名路径和 HDC `[Empty]` 目标过滤；无线 `192.168.11.100:36169` 安装启动成功（版本0.13.37，signed HAP 17,432,287 bytes） |
| 2026-06-12 | 等待视频流复查：出站控制端真实帧路径仍是 `on_rgba -> video-frame`；入站被控端没有 Harmony 录屏/desktop server 时不能标记 `incomingReady=true`。11端共享开关录屏失败即回滚并关闭 incoming，13端 `main_start_service(true)` 返回 `incomingReady=false` 和明确错误，避免远端无限等待视频流。 |
| 2026-06-13 | 13 native core 本地构建脚本修复：解析到 OHOS SDK 后必须同步设置 `RUSTDESK_HARMONY_HOST_SDK`/`OHOS_SDK_HOME`/`OHOS_NDK_HOME`，并在 libsodium MSYS bash 脚本中 export；否则 Windows `.cmd` clang wrapper 在 configure 中报 `OHOS SDK not found`。 |
| 2026-06-13 | 完成 core-70 闭环：13 项目修复 libvpx RTC C++ CI 构建失败并推送 `d61ceca`；GitHub Actions run `27459455573` 成功发布 `core-70`；11 项目下载新核心（131,263,476 bytes / SHA256 `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`），HAP 构建、native/signature 校验和真机安装通过；设备锁屏导致启动/视频流日志未能继续验证。 |
| 2026-06-13 | 在 App 项目根创建本地 Junction `13_librustdesk_core` → `%VSCODE_ROOT%\13_librustdesk_core`，并加入 `.git/info/exclude`；后续可从 `11_Rustdesk_harmonyos\13_librustdesk_core` 直接进入核心项目。NTFS 支持该方式，exFAT 不适合作为 Junction 宿主。 |
| 2026-06-13 | 新对话读取全部文档，HAP 构建验证通过（版本 0.13.40，signed HAP 18,746,430 bytes，构建时间 2026-06-13 09:34）；确认项目状态与文档一致。 |
| 2026-06-13 | 核心详情弹窗精简：从18行缩减为8行（类型/运行/兼容/文件/大小/哈希/编译/有效），运行行合并状态+运行摘要+异常+详情；新增 getCoreRuntimeText() 方法；i18n 新增 Runtime/Compatible/Compile/Valid 翻译；HAP 构建验证通过（构建时间 2026-06-13 11:33）。 |
| 2026-06-13 | 聊天浮窗宽度从272缩至240（maxWidth从340缩至300），默认弹出位置改为屏幕水平中心；构建脚本智能核心检测：fetch_native_core.ps1 通过 HTTP HEAD 比对 ETag/Content-Length/Last-Modified，线上无变化跳过下载，有变化才下载覆盖；元数据缓存到 99_Temp/librustdesk_core/librustdesk_core.meta.json；build_hap.bat/build_full_hap.bat/AUTO_BUILD_INSTALL.bat 去掉 -Force 参数；HAP 构建验证通过，设备未连接无法安装测试。 |
| 2026-06-13 | HDC服务钝化经验：无线设备在线但hdc list targets显示[Empty]时，应先hdc kill+hdc start重启HDC服务再重试；AUTO_BUILD_INSTALL.bat已在无线目标未找到和安装失败时自动重启HDC服务重试。 |
| 2026-06-13 | 图标格式原则更新：不要重绘SVG，根据图标自身格式选择着色方法；linux.svg是fill格式改用fillColor(theme_ACCENT)；android.svg添加fill="#000000"属性；buildThemedPlatformIcon通过isFillPlatformIcon()自动分流fill/stroke格式；UI.md和AGENT_MEMORY文档更新图标格式原则；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 设置页扫码图标主题匹配：scan_frame.svg保持原始fill格式不变，着色从colorFilter改为fillColor(theme_TEXT_TERTIARY)；按钮从ACCENT_SURFACE实心圆改为透明背景+1.5px TEXT_TERTIARY描边圆形（类似华为运动健康风格）；HAP构建验证通过，无线安装验证通过。 |
| 2026-06-13 | 全量图标主题匹配检查修复：10处fill格式SVG使用colorFilter改为fillColor（arrow.svg×3、file.svg×2、search.svg×1、group.svg×1、display.svg×1、keyboard_mouse.svg×1、rec.svg×1）；3个SVG补fill="#000000"属性（file.svg、group.svg、rec.svg）；账户菜单图标从右侧移到左侧（login/logout.svg）；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 账户菜单修正：左侧图标改为登录提供方图标（resolveAuthProviderIcon()，支持github/google/apple/facebook/gitlab/azure/auth0/okta，未知用auth-default.svg）；右侧退出登录图标缩小为36×36独立容器，点击区域只限退出按钮；未登录时整行点击打开登录对话框；版本自增0.13.41；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 会话菜单布局统一：图标左→文字中间→选项(Radio/Checkbox/箭头)右；菜单宽度从280缩至240；内边距从20统一为16；RadioOptionItem/CheckboxOptionItem/buildMenuRow/buildToggleMenuRow均已符合此布局；版本0.13.42；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 会话菜单优化：buildToggleMenuRow文字从靠Radio改为靠图标(layoutWeight(1))；点击其他功能菜单按钮可关闭当前菜单；点击菜单外空白区域关闭菜单；菜单圆角从仅顶部改为四角16；背景从CARD_BG改为MENU_BG半透(#D01E232F暗/#D0FFFFFF亮)；ThemeConfig新增MENU_BG主题色；版本0.13.44；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 显示质量面板精简：只保留分辨率/帧率/延迟/速度/类型/缩放6项，移除标题栏/关闭按钮/Updated/Quality Details/Raw Quality Status；面板从340×460缩至140宽自适应高度；字号从12/14缩至11；背景改为全透(Color.Transparent)；菜单面板背景也改为全透；版本0.13.45；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 菜单面板恢复半透背景(MENU_BG)，仅质量面板保持全透；键盘挤压逻辑优化：新增remoteInputActive状态，仅远程输入(imeProxy)时向上挤压，聊天/密码等输入不挤压；打开远程键盘时自动收起工具栏(toolbarHiddenByKeyboard)，关闭键盘后自动恢复；移除密码输入框的avoidKeyboardHeight手动设置；版本0.13.46；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 修复质量监控开启状态下连接后不显示：loadSessionMenuState后同步setConnectionInfoVisible；工具栏底部安全区避让expandSafeArea；键盘输入从整个页面translate改为仅视频显示区域translate；聊天按钮可关闭已打开的聊天面板；全量构建版本0.16.0；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 设置页开关统一逻辑：所有显示设置开关从只调setLocalOption改为同时调applySessionOption+setLocalOption，与会话页一致；去掉会话菜单关闭按钮(×图标)，改为点击菜单区域外关闭；菜单宽度从240缩至210；内边距从16缩至12；菜单标题高度从48缩至40；版本0.16.1；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 画面平移边界限制：新增clampPanOffset方法，左右最多到屏幕边缘一条缝(gap=4px)，竖向显示时左右可缩小到屏幕边缘；横竖屏切换时自动重新计算边界；版本0.16.4；HAP构建验证通过，待安装测试。 |
| 2026-06-13 | 显示设置菜单标题右侧添加旋转方向按钮：新增opt_rotate.svg(stroke格式)、PanelHeaderAction接口、buildSessionPanelHeader支持headerAction参数；点击按钮调用toggleRotation()切换竖屏/横屏显示，旋转时重置panOffset；HAP构建验证通过，无线安装启动验证通过(coreReady=true)。 |
| 2026-06-13 | 质量监控面板：新增编码行显示当前编码类型(VP9/H265等，从quality-status的codec_format提取)；连接类型标签从"连接类型"改为"连接"（去掉"类型"两字）；新增@State connectionCodec；HAP构建验证通过。 |
| 2026-06-13 | ID卡片连接模式per-card化：PreferenceStore新增PEER_CONNECT_MODES_KEY/getPeerConnectMode/setPeerConnectMode；buildConnectModeRow从per-peer存储读取选中状态而非全局recentMenuConnectMode；移除recentMenuConnectMode全局状态；中继重连后自动更新per-peer连接模式为relay；菜单其他功能(收藏/删除/重命名/文件传输/终端/摄像头)已确认per-card；HAP构建验证通过，设备离线未安装测试。 |
| 2026-06-13 | 关于页修改：启动检查更新开关改为禁用状态(disabled=true，灰色不可操作)；指纹行点击事件从文本移到整行Row，右侧空白区域显示指纹前12字符点击可复制完整指纹；buildSettingsToggleSettingRow新增disabled参数；HAP构建验证通过。 |
| 2026-06-13 | 键盘避让优化：平移从容器移到画面Image本身，computeKeyboardOffset()计算画面下边缘与键盘区域重叠量，只有重叠>0时才向上平移重叠量(且不超过画面顶部位置)；取消键盘弹出自动收起工具栏(移除toolbarHiddenByKeyboard)；pinchScale最小值从0.5改为1(最小100%缩放)；clampPanOffset竖屏画面比容器窄时左右到屏幕边缘、横屏画面比容器矮时上下到屏幕边缘；收起工具栏bottom从固定20改为avoidNavigationBarHeight；菜单面板bottom从56改为56+avoidNavigationBarHeight；HAP构建验证通过，安装启动验证通过。 |
| 2026-06-13 | 工具栏展开时底部避让：移除expandSafeArea，改为margin({ bottom: avoidNavigationBarHeight })，与收起时一致避让底部导航栏；新增@StorageProp('avoidNavigationBarHeight')；HAP构建验证通过。已合并到键盘避让优化轮。 |
| 2026-06-13 | 多项修复轮(1/2)：1.输入法特殊符号修复：isPlainAsciiText改为isAlphanumericText，非字母数字走sessionInputString；onBlur中焦点恢复防止跳出光标区；2.中键滚动速度：步长从4px改为20px，每步只发1个滚轮事件；3.横向显示时切换系统屏幕方向：WindowChromeService新增setLandscape方法，toggleRotation调用setLandscape，会话结束恢复竖屏；5.聊天输入区高度从46缩至36(Chat.ets)/从42缩至34(RemoteControl)；6.扫描优化：去掉复制按钮只保留重试，扫描成功自动复制+导入服务器+1.2秒后退出；7.核心按钮改为启动/停止2个，停止时closeSession+resetForRetry+重置officialCoreState，去掉消息提示；8.核心详情弹窗运行行拆分为Status/Summary/Error/Detail独立行；9.ID输入框自动激活修复：aboutToAppear中延迟焦点到tab列表。全量构建通过。 |
| 2026-06-13 | 多项修复轮(2/2)：4.聊天功能链路修复：C++层SendChatMessage从读args[0]改为读args[2](content)，ChatService事件匹配增加chat_client_mode；10.ID卡片选项卡搜索功能确认已有实现；11.通讯录同步添加服务器API调用(addPeerToAddressBook/deletePeerFromAddressBook)；12.ID输入悬浮匹配建议(showIdSuggestions/getIdSuggestions)；13.平台图标修复：buildChatSessionCard传platform而非deviceName，resolvePlatformForDevice()；14.共享页启动服务修复：startCapture异常后仍启动incoming service；15.聊天消息时间优化：shouldShowTimestamp()5分钟内同发送者只显示最后一条时间；scan_frame.svg替换；输入法无法关闭修复(onBlur延迟300ms+键盘按钮状态同步)；computeKeyboardOffset方向反转修复(maxShift取Math.max(0,imageTop))；聊天输入框高度再降40%(Chat.ets 36→22/RemoteControl 34→20)；调试日志清理(3条[IME]日志)；HAP构建验证通过，无线安装验证通过。 |
| 2026-06-14 | 键盘避让重构：(1)删除computeKeyboardOffset()方法，translate改为纯panOffsetY；(2)键盘弹出时修改panOffsetY模拟双指平移，关闭时恢复preKeyboardPanOffsetY；(3)@Watch监听showKeyboard和avoidKeyboardHeight变化；(4)工具栏从Column流移出改为Stack悬浮(zIndex=5)，预览区铺满到屏幕底部，previewHeight=到屏幕底部的真实距离；(5)distanceFromBottom计算：<=0推kbH，0<x<kbH推kbH-x，>=kbH不平移；(6)ID匹配悬浮窗从Column流移出改为Stack绝对定位(position+zIndex=10)，宽度70%；HAP构建验证通过，无线安装验证通过。 |
| 2026-06-14 | 旋转画面修复：(1)新增isLandscapeMode状态替代viewRotation=90，viewRotation保持0不再额外旋转画面(setLandscape已旋转系统屏幕，叠加rotate导致180度)；(2)isQuarterTurn()改用isLandscapeMode；(3)transformPreviewPointToImageSpace横屏时交换xy坐标；(4)closeSession()和goBack()中恢复横屏状态；(5)ID输入框焦点：默认焦点放到connect-tab-btn(底部连接tab图标)，避免TextInput自动获取焦点弹出输入法；HAP构建验证通过，无线安装验证通过。 |
| 2026-06-14 | 底部tab栏修复：(1)buildFillTabItem中width('100%')误改回layoutWeight(1)，Row中多个width('100%')子项只有第一个可见；(2)buildOfficialConnectPanel外层从Stack还原为Column，悬浮窗改用.overlay()属性实现（Stack导致面板高度异常）；(3)ForEach还原为原始i18nVersion作key；HAP构建验证通过，干净卸载重装验证通过。 |
| 2026-06-14 | 核心/App 对接闭环：修复 13 项目终端 stub、终端 dataBase64 事件、音频空队列 `[]`、本地音频上传假成功和核心 C++ 聊天四参；commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 推送后发布 `core-71`；11 项目下载后全量 HAP 构建、验包、无线安装启动和 hilog `coreReady=true` 验证通过。 |
| 2026-06-14 | 构建脚本经验：`13_librustdesk_core` junction 不能进入 staging，`stage_project_for_build.ps1` 要排除该目录并使用 `/XJ`；核心构建 cwd 必须是真实 `%VSCODE_ROOT%\13_librustdesk_core`，不能是 app 内 junction 路径。 |
| 2026-06-14 | 核心下载脚本容错：`fetch_native_core.ps1` 在 GitHub latest core HEAD/下载失败但本地核心存在且校验通过时，改为复用本地核心继续 HAP 构建；只有本地核心缺失或校验失败时才中止。 |
| 2026-06-14 | 文件传输对接追加：13 核心补齐 `HarmonyHandler` 文件传输事件和 `switch-sides` option 路由；11 App `FileTransferService` 去掉本地示例文件，改用 `@ohos.file.fs` 读取真实下载目录，并在上传前检查源路径存在。 |
| 2026-06-15 | 性能优化前备份和审计修复：`backup_project.ps1` 排除 `13_librustdesk_core` junction 并使用 `/XJ`，正式备份为 `rustdesk_harmonyos_20260615_000050.zip`；远控质量浮层改为基础7行+`qualityMetricItems`动态指标滚动渲染，连接链路审计恢复 `50 PASS, 0 FAIL`。 |
| 2026-06-15 | 调试常亮临时默认开启：`debugKeepScreenAwake` 默认值改为 true，新增一次性迁移 `debug_keep_screen_awake_default_on_20260615`，升级后自动开启一次防止调试安装后手机锁屏；用户手动关闭后不再覆盖。 |
| 2026-06-15 | USB-only/无线安装：`AUTO_BUILD_INSTALL.bat` 新增 `usb/--usb` 目标模式，只选择 USB/local HDC 目标并跳过无线；`--skip-build usb` 返回 `[Empty]` 说明 USB 未识别。用户打开无线后 `--skip-build auto` 成功安装启动 `0.20.3` 到 `192.168.11.100:36169`，`bm dump` 显示 versionCode `1000099`，进程 `26834` 存活。 |
| 2026-06-15 | 共享录屏冲突经验：共享开关不能再启动 `AVScreenCaptureRecorder` 或截图 API。处理顺序应为先写入核心选项并调用 `setIncomingServiceEnabled`；核心返回 `captureRequired=true` 时启动 native `OH_AVScreenCapture_StartScreenCapture` 提供首帧，只有 `incomingReady=true` 才显示共享服务真实运行。 |
| 2026-06-15 | v0.20.5 增量验证：共享启动顺序修复后 `build_hap.bat` 通过，core-76 未变化；signed HAP `18,928,713` bytes / SHA256 `E174E07ABB77CBF3E17489AABFEBDC7A5827A7DDE409206C59377C4BA9631FF0`，验包和连接链路审计通过，无线安装启动到 `192.168.11.100:36169`，设备端 `versionName=0.20.5`、versionCode `1000101`、进程 `39312` 存活。 |
| 2026-06-15 | core-78 全量验证：13 核心聊天 ABI 与 d.ts key 修复由 run `27515510727` 发布 `core-78`，asset `131,470,442` bytes / SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`；11 App `build_full_hap.bat` 构建 `0.21.0` / versionCode `1000102`，signed HAP `18,928,728` bytes / SHA256 `491ED6E5CF1A8B6E2DD3F1E4661D99C15A4EB7D9B7B6FCB4A45BC92346BE2F90`；验包、连接链路审计、无线安装启动和 hilog `coreReady` 均通过。 |
| 2026-06-15 | v0.22.1 权限复查：共享启动去掉 `CUSTOM_SCREEN_CAPTURE` 预申请，避免先唤起截屏/屏幕捕获授权；文件传输页和 `requestFileAccessAuthorization()` 默认走 `DocumentViewPicker` 目录授权。`build_hap.bat`、验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端 `versionName=0.22.1`、versionCode `1000104`、进程 `56711`。 |
| 2026-06-15 | v0.22.2 共享录屏底层复查：`AVScreenCaptureRecorder` 和临时 mp4 探测文件已从当前 `ScreenCaptureService` 移除，改为 C++ NAPI 调用 `OH_AVScreenCapture_StartScreenCapture` 并轮询 `OH_AVScreenCapture_AcquireVideoBuffer` 统计帧。构建、验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端 `versionName=0.22.2`、versionCode `1000105`、进程 `62121`。 |
| 2026-06-15 | v0.22.4/core-80 入站帧缓存复查：native `OH_NativeBuffer` payload 已通过 `rustdesk_bridge_update_incoming_screen_frame` 推入核心 `incoming_screen_frame` 缓存，核心快照暴露 `incomingFramePayloadReady/incomingFrameId/incomingFrameBytes/incomingFramesSeen`。这仍不是 `incomingReady`，desktop server/video source 未接通前 UI 不能显示真实共享运行。`build_hap.bat` 强制下载线上 core-80，验包、66 项审计、无线安装和干净 hilog 均通过。 |
| 2026-06-15 | v0.22.5/CI strict 复查：线上 Linux/release workflow 在 `PermissionService.ets` 未显式对象字面量处失败，本地修复为显式 `PermissionRequestResult`；聊天摘要分隔符修正为 ` - `，避免中文错字。强制下载 core-80 构建、验包、66 项审计、无线安装和干净 hilog 均通过。 |
| 2026-06-15 | v0.22.5 线上发布闭环：提交 `7bdfd0d` 后 push Linux workflow run `27528676811` 成功，release workflow run `27528681007` 成功发布 `OpenRustdesk-Build-v0.22.5`；线上 signed HAP SHA256 `515805c9a960a3a200400bf4b104d5683e500a27e08f9dd5a9992eaa1b0bac98`，release notes 已补中文说明和 core-80 标签。 |
| 2026-06-15 | v0.22.6/core-81 本地预发布复查：共享 `captureRequired` 触发 native 录屏提供首帧但不等于 `incomingReady`；文件授权改为 `DocumentViewPicker` picker-first；验包签名临时文件使用 GUID 名。本地 core `128,894,588` bytes / SHA256 `2DC3B655664B756E255684D28FBA0CB3A9DEC14E6080EA4682FA26486ADF9B6D`，signed HAP `18,433,473` bytes / SHA256 `4D669584F44B6462F570747723E66EB2894204FF7860CA0FBB27339D7FCE7DDD`，无线安装启动和干净 hilog 均通过。 |
| 2026-06-15 | v0.22.7/core-81 线上核心复查：线上 core-81 asset `131,631,706` bytes / SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829` 已强制下载到 11 App；signed HAP `18,978,267` bytes / SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`，无线安装启动、静态录屏 API 扫描和干净 hilog 均通过。 |
| 2026-06-15 | v0.22.7 线上发布闭环：提交 `42f9b8e` 后 push Linux workflow run `27567811582` 成功，release workflow run `27568044749` 成功发布 `OpenRustdesk-Build-v0.22.7`；线上 signed HAP SHA256 `ce62df82dd5167f9d31b34c0e2b88c869ed947a05214ca156fc3eeab9ff76fe3`，unsigned HAP SHA256 `024ca74d649c305e8598ab36bf57a27e7f54869cd5c584f4d35798a89e008e98`，release notes 已补中文说明和 core-81 标签。 |
| 2026-06-14 | 摄像头查看入口收敛：Recent 菜单 `View Camera` 改为不可用提示，`ViewCamera.ets` 不再将本地状态伪装成 connected，等待后续真实 official view-camera session 接入。 |
| 2026-06-14 | core-73 验证：13 核心文件传输事件和 `switch-sides` option 路由已发布为 `core-73`；11 App 全量构建、验包和无线安装通过，设备锁屏导致启动运行态待解锁后复测。 |
| 2026-06-14 | 剪贴板/命令假成功收敛：`Send Clipboard Keys` 检查 native 返回值；一次性远控命令未被 core 处理时提示 `Command unavailable`，不再写本地 option 伪装排队。 |
| 2026-06-14 | core-74 验证：13 核心旧 Harmony source mirror 剪贴板发送已与 active bridge 对齐并发布为 `core-74`；11 App 全量构建为 `0.19.0`，验包、无线安装、解锁后启动和 hilog `coreReady=true` 验证通过。 |
| 2026-06-14 | 本轮功能缺失复查：连接页返回不再聚焦 ID 输入框；登录/历史/收藏/发现/通讯录/核心搜索入口改为从图标向左悬浮展开；通讯录登录成功和刷新按钮触发服务器同步；核心页按钮拆成开始/重启与加载/停止；共享页使用 `AVScreenCaptureRecorder` 录屏授权探测，密码刷新立即生效；设置页与会话菜单同功能共用一套 option 状态；关于页新增调试常亮；文件授权 API 统一请求下载目录/持久访问并唤起 `DocumentViewPicker`；聊天发送失败不写入 failed 文本，远控聊天按钮弹出语音/文字模式。增量 HAP 构建通过，等待最新 core 发布后全量验证。 |
| 2026-06-14 | 核心追加：自定义服务器 key 必须透传到 `start_service` 和 `session_start`，且空配置要清理旧 server option；聊天发送结果不能复用 `chat-message`，失败用 `chat-error`、成功用 `chat-sent`、远端消息才用 `chat-message`。13 核心 commits `3afa229`、`1f474fc` 已推送，等待 CI 发布新 core。 |
| 2026-06-14 | 旧逻辑清理：`AppDataService` 中早期演示设备别名/备注/分组自动翻译会污染真实用户数据，已移除；以后只允许清理可明确识别的旧自动生成项，例如 `远程/Remote + 数字ID`。 |
| 2026-06-14 | core-76 全量构建和安装：13 核心 key 透传与聊天语义均已发布，11 App 下载 latest core 后全量构建 `0.20.0`，验包和无线安装通过；手机当前密码锁屏，运行态 `coreReady=true` 需要解锁后继续验证。 |
| 2026-06-14 | core-74 复核：文档更新后已在解锁手机上重新执行 skip-build 安装启动；进程 `12565` 存活，hilog `coreReady= true` 7 次、`query-onlines-result` 14 次，app fatal/panic/signal 为 0。 |
| 2026-06-14 | 共享状态复查：`Index.isShareServiceRunning()` 原先把 `ScreenCaptureService.isCapturingActive()` 当成服务运行，导致录屏探测中也显示“服务运行中”、共享 TAB 绿点、设备 ID 和一次性密码。已拆成真实 incoming ready、录屏探测、停止可用三个状态；录屏探测只显示黄色 `Recording Probe` 并保留停止按钮。 |
| 2026-06-14 | 7项问题修复轮：(1)TAB连接页返回时自动聚焦修复：底部tab按钮添加id `${tab}-bottom-tab-btn`，switchHomeTab切到connect时焦点请求到 `connect-bottom-tab-btn`，onPageShow中也请求焦点，aboutToAppear默认焦点也改为 `connect-bottom-tab-btn`；(2)搜索失焦修复：onBlur只关闭输入框不清空搜索文本，搜索图标点击时如果有搜索文本则清空再重新打开；(3)核心按钮逻辑修复：主按钮Restart时stopCoreRuntime后重设coreLoadBusy=true防止按钮闪烁，副按钮在staticlib模式下只显示Stop且核心未运行时disabled，移除无意义的Load逻辑；(4)设置页与会话显示设置状态同步：打开显示设置对话框时先递增settingsOptionVersion强制重新读取native option值；(5)聊天对话框默认大小再缩小40%：168x216→100x130，最小值也同步调整；(6)调试常亮开关：WindowChromeService.setKeepScreenOn改为3次重试循环，onPageShow中重新调用syncControlledKeepScreenOn恢复常亮状态；(7)术语约定：TAB=底部主菜单4项，选项卡=ID输入框下方子选项。增量HAP构建通过，卸载重装验证通过，hilog coreReady=true、LAN发现正常、在线查询正常。 |
| 2026-06-14 | 聊天对话框放大20%：100x130→120x156；再放大20%：120x156→144x187，最小值同步调整。ID输入框悬浮匹配框改为只在输入法激活时显示：新增`deviceIdInputFocused`状态，TextInput的onFocus设true/onBlur设false，onChange中`showIdSuggestions = deviceIdInputFocused && raw.length >= 3`，onBlur时隐藏匹配框。增量HAP构建通过。 |
| 2026-06-14 | ID输入框修复：(1)悬浮匹配框左右居中：overlay align改为Alignment.Top，去掉x偏移；(2)X/→按钮点击无反应：Stack中左侧Column width('100%')覆盖右侧按钮，给左侧Column加right:60 padding留出按钮空间，右侧Row加zIndex(20)确保在overlay之上，按钮加hitTestBehavior(Block)和padding扩大点击区域，X按钮先关闭匹配框再清空避免状态竞争。增量HAP构建通过，卸载重装验证通过。 |
| 2026-06-14 | ID输入框状态提示优化：(1)所有提示文本不超过8个字：连接中、输入ID、ID格式错误、核心就绪、已停止、未知、连接失败、需要密码等；(2)resolveStatusMessage不再拼接目标ID，改用短key如Connecting/Enter ID/ID incorrect/Conn failed/Pwd required；(3)setStatusMessageRaw加8字截断；(4)所有权限拒绝提示缩短：截屏权限拒绝、输入权限拒绝等；(5)去掉按钮padding避免图标视觉变小。增量HAP构建通过，卸载重装验证通过。 |
