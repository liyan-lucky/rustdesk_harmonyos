# 项目文件说明

> 每个代码文件的作用，修改前必读

## 工作区项目匹配

`%VSCODE_ROOT%` 是包含 `11_Rustdesk_harmonyos/` 和 `99_Temp/` 的可移动工作区根目录。当前项目只依赖下列 RustDesk/HarmonyOS 相关目录；`01_DeepSeek-*`、`03_ Excel_VBA _database`、`04_Excel_VBA_Files`、`05_Excel_VBA_HR`、`06_Excel_VBA_Inventory`、`07 Rustdesk-api-server-pro`、`08_Gun_Rrub2`、`09_Win_desk_time`、`10_Tabssh.github.io`、`12_Monitor tool`、`98_Test` 等同级目录不是当前 HAP 构建依赖。

| 工作区目录 | 匹配结果 |
|------|------|
| `11_Rustdesk_harmonyos/` | 当前 Git 根和 HarmonyOS App 项目根，顶层直接包含 `AppScope/`、`entry/`、`docs/`、`scripts/` |
| `13_librustdesk_core/` | **核心独立项目**，包含 Rust 桥接层、C++ 桥接层、代码生成脚本、上游源码、OHOS 补丁、CI/CD |
| `99_Temp/rustdesk-master/` | （历史）RustDesk 上游源码，核心项目已自带 `rustdesk-master/` |
| `99_Temp/rustdesk_harmonyos_build/` | （历史/辅助）旧 Native core 构建工作区、OHOS SDK mirror、vcpkg、外部依赖；当前 core 权威来源是 `13_librustdesk_core/` |
| `99_Temp/harmonyos_build/` | HAP 构建输出 |
| `99_Temp/harmonyos_stage/` | HAP 构建前的干净项目副本，避开本地旧生成目录权限残留 |
| `99_Temp/harmonyos_cache/` | Hvigor 缓存 |
| `99_Temp/rustdesk_harmonyos_signing/` | 当前可移动签名材料，`build-profile.json5` 通过相对路径引用 |
| `99_Temp/rustdesk_harmonyos_backups/` | 项目 zip 备份目录，只保留最新 2 份 |

## 文档目录 (docs/)

| 文件 | 作用 |
|------|------|
| `README.md` | 新对话接手入口，说明当前状态、问题结构和阅读顺序 |
| `CORE.md` | 核心架构、可复现编译、HDC安装启动、运行验证清单 |
| `PROGRESS.md` | 当前功能进度、已完成事项、重点问题 |
| `CONNECTION_DEBUG_LOG.md` | 连接问题逐轮排查记录 |
| `ISSUES.md` | 问题库和易复发坑 |
| `FILES.md` | 文件职责和外部依赖目录 |
| `DESIGN.md` | 架构、UI、构建、真机测试设计约束 |
| `UI.md` | UI布局、图标、核心页卡片细节 |
| `BUILD_ARCHIVE.md` | 历史构建、脚本、Ubuntu路径和早期会话归档 |
| `GIT_PUBLISH.md` | GitHub 发布说明。本地和远端均为项目根结构；包含正常提交推送流程和生成物禁止项。 |
| `FUNCTION_LOGIC_AUDIT_2026-06-06.md` | 最新 100 轮全功能逻辑检查、已修问题和后续补齐清单。 |

## C++桥接层 (entry/src/main/cpp/)

> **注意**：核心相关文件已迁移到 `%VSCODE_ROOT%\13_librustdesk_core` 项目。本目录的 C++ 桥接层文件从 13 项目的 `cpp/` 目录同步。核心修改在 13 项目进行，修改后需同步到本目录并重新构建 HAP。

| 文件 | 行数 | 作用 |
|------|------|------|
| `CMakeLists.txt` | 91 | 构建配置，STATIC LINK MODE链接librustdesk_core.a到bridge SO |
| `rustdesk_bridge_loader.cpp` | 828 | C++ NAPI桥接层，当前注册50个NAPI函数，IsCoreLoaded()=true，直接调用extern "C"函数，包含qsort_r stub实现 |
| `rustdesk_bridge_abi.h` | 102 | 当前声明46个Rust extern "C"函数；与Rust侧`bridge_api.rs`导出的46个函数完全对齐 |
| `types/librustdesk_bridge/index.d.ts` | 52 | NAPI模块TypeScript类型声明，与C++ NAPI签名对齐 |
| `types/librustdesk_bridge/oh-package.json5` | 6 | NAPI模块包配置 |

## Rust核心 (native_rust_core/)

> **注意**：Rust 桥接层已迁移到 `%VSCODE_ROOT%\13_librustdesk_core\native_rust_core\`。本目录的 `native_rust_core/` 仅作为历史参考，不再用于构建。核心修改在 13 项目进行，构建产物通过 GitHub Releases 下载。

| 文件 | 行数 | 作用 |
|------|------|------|
| `Cargo.toml` | - | crate配置，`crate-type=["staticlib"]`，`default-features=false`，`features=["use_dasp"]` |
| `build.rs` | - | 构建脚本，编译时生成 |
| `src/bridge_api.rs` | 559 | C ABI导出层，46个`rustdesk_bridge_*`函数，含get_peer_option/get_peer_info；initialize_runtime返回本地BridgeSnapshot避免上游stub空JSON透传 |
| `src/bridge_state.rs` | 130 | 桥接状态管理 |
| `src/lib.rs` | 50 | crate入口 |

## ArkTS页面 (entry/src/main/ets/pages/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `Index.ets` | 5027 | **主页面**，4个Tab(连接/聊天/共享/设置)，设置Tab代码全在此，核心页面4卡片布局+详情弹窗(Status/Error/Detail/File/Size/Hash/ELF/BuildTime/Source)，CoreModuleInfo多模块支持，核心状态简词(就绪/停止/未识)+弹窗详细描述，运行摘要卡片，权限开关先同步更新再异步请求，hilog调试日志，设置行图标(Lucide stroke SVG via colorFilter)，服务器导入导出提示，聊天Tab固定显示当前/最近会话聊天内容并保留右侧图标 |
| `RemoteControl.ets` | 3884 | **远程控制页**，视频渲染+输入控制+工具栏+手势，会话聊天浮窗自动滚动到最新消息 |
| ~~`Settings.ets`~~ | - | 已删除，设置功能合并到Index.ets设置tab |
| `FileTransfer.ets` | 635 | 文件传输页面 |
| `LoginPage.ets` | 393 | 登录页面(OAuth+密码，统一走AccountService) |
| `Terminal.ets` | 470 | 终端页面(多会话) |
| `AddressBook.ets` | 487 | 地址簿页面 |
| `Chat.ets` | 412 | 聊天页面，移除固定示例回复和种子消息 |
| `MyDevice.ets` | 364 | 我的设备页面 |
| `ViewCamera.ets` | 323 | 摄像头页面 |
| `WebLoginPage.ets` | 232 | Web登录页面 |
| `Scan.ets` | 410 | 扫描页面，相机/相册二维码识别，服务器配置扫码直存 |

## ArkTS服务层 (entry/src/main/ets/services/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `NativeRustDeskBridge.ts` | 1653 | **NAPI底层桥接**，ArkTS封装C++ SO；getPeerInfo()/getPeerOption优先解析NAPI函数，未注册时回退读取PeerConfig文件 |
| `I18nService.ets` | 1956 | **国际化服务**，translate()/lt()，中英翻译，@State i18nVersion触发重渲染 |
| `OfficialRustDeskBridge.ets` | 772 | 官方桥接高层封装，统一调用NativeRustDeskBridge |
| `AppDataService.ets` | 1053 | **核心数据管理**，会话列表/连接状态/核心状态/发现列表，createRecentSession()优先用getPeerInfo()获取hostname(2026-05-31)，不再返回固定测试聊天消息 |
| `ServerConfigCodec.ets` | 66 | 服务器配置导入导出编解码，复用官方 JSON→Base64→反转格式 |
| `ChatService.ets` | 544 | 聊天服务，持久化消息加载时重建会话摘要 |
| `AccountService.ets` | 515 | 账户服务(token持久化/登录登出/PasswordLoginResult) |
| `FileTransferService.ets` | 537 | 文件传输服务 |
| `CoreLoaderService.ts` | 443 | 核心SO加载服务(staticlib方案下仅做初始化检查) |
| `AudioService.ets` | 344 | 音频服务(AudioRenderer, 48kHz mono S16LE) |
| `AppState.ets` | 330 | 应用状态管理 |
| `OfficialSessionTextFormatter.ets` | 346 | 会话文本格式化 |
| `InputService.ets` | 353 | 输入服务(鼠标/键盘/触摸) |
| `HttpClient.ets` | 415 | HTTP客户端 |
| `ClipboardService.ets` | 246 | 剪贴板服务(双向同步) |
| `PermissionService.ets` | 255 | 权限服务 |
| `ScreenCaptureService.ets` | 238 | 屏幕捕获服务 |
| `TerminalService.ets` | 227 | 终端服务 |
| `WindowChromeService.ets` | 221 | 窗口管理(状态栏透明/全屏/系统栏颜色) |
| `EventBus.ets` | 171 | 事件总线 |
| `FrameService.ets` | 225 | 视频帧服务 |
| `PreferenceStore.ts` | 160 | 偏好存储(轻量KV) |
| `LanDiscoveryService.ets` | 121 | LAN发现服务(启动一次发现，后续手动刷新) |
| `OfficialSessionTransport.ets` | 94 | 会话传输层 |
| `librustdesk_bridge.d.ts` | 65 | NAPI模块类型声明 |
| `OfficialSessionTypes.ets` | 63 | 会话类型定义 |
| `AppContextService.ts` | 17 | 应用上下文服务 |

## ArkTS通用组件 (entry/src/main/ets/common/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `CommonComponents.ets` | 516 | **通用UI组件库**，CardContainer/PrimaryButton/SecondaryButton/SectionTitle/PageHeader/InfoRow(含icon)/createStrokeIconColorFilter/toArgbColor |
| `ThemeConfig.ets` | 383 | **主题配置**，ThemeManager(单例)/ThemeConfig(AppStorage管理颜色)，MENU_ITEM_HEIGHT=50 |
| `ErrorHandler.ets` | 465 | 错误处理器 |
| `SessionDiagnostic.ets` | 449 | 会话诊断 |
| `PerformanceMonitor.ets` | 272 | 性能监控 |
| `DeviceIdFormatter.ets` | 32 | 设备ID格式化(从右向左每3位空格) |
| `BuildInfo.ets` | 4 | 构建时间(脚本自动更新) |
| `Types.ets` | 11 | 公共类型 |

## ArkTS组件 (entry/src/main/ets/components/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `Icon.ets` | 52 | 图标组件 |
| `KeyboardToolbar.ets` | 279 | 键盘工具栏 |
| `RemoteCursor.ets` | 133 | 远程光标 |
| ~~`RemoteSettingsPanel.ets`~~ | - | 已删除(死代码，从未被import) |

## ArkTS网络层 (entry/src/main/ets/network/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `RustDeskProtocol.ets` | 470 | 协议层 |
| `ConnectionQualityManager.ets` | 435 | 连接质量管理 |
| `RustDeskConnection.ets` | 294 | 连接管理 |
| `DeviceIdGenerator.ets` | 237 | 设备ID生成 |

## ArkTS入口 (entry/src/main/ets/entryability/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `EntryAbility.ets` | 215 | **应用入口**，onCreate初始化Native桥接/主题/语言/i18n |

## 修改注意事项

- **设置Tab**: 所有UI代码在Index.ets中，不在Settings.ets
- **Index.ets**: 5027行，修改前定位到具体Builder方法；权限开关onChange必须先同步updateSettings再异步请求；调试日志用hilog不用console
- **RemoteControl.ets**: 3884行，视频帧性能敏感，避免ForEach
- **I18nService.ets**: 所有翻译文本在此，新增语言需添加
- **ThemeConfig.ets**: 颜色通过AppStorage管理，不是color.json
- **BuildInfo.ets**: 每次构建前脚本自动更新BUILD_TIME

## 外部依赖目录 (`%VSCODE_ROOT%\99_Temp\` / Ubuntu挂载同名目录)

| 目录 | 作用 |
|------|------|
| `../13_librustdesk_core/` | 当前 RustDesk native core 独立项目；包含上游源码、Rust/C++桥接、代码生成脚本、OHOS patch 和 core CI/CD |
| `rustdesk-master/` | 历史 RustDesk 官方源码副本；当前 core 源码以 `../13_librustdesk_core/rustdesk-master/` 为准 |
| `rustdesk_harmonyos_build/` | 保留的历史构建环境 (ohos-sdk/deveco-sdk/vcpkg/外部依赖源码/tools/patches/旧构建脚本/旧Rust产物) |
| `rustdesk_harmonyos_build/ohos-sdk/` | OpenHarmony Linux Native SDK，Rust交叉编译使用 |
| `rustdesk_harmonyos_build/deveco-sdk/` | DevEco/OpenHarmony SDK缓存，HAP构建使用 |
| `rustdesk_harmonyos_build/external-src/` | C依赖源码 (opus/libsodium/aom/libyuv/libvpx) |
| `rustdesk_harmonyos_build/build/libsodium/aarch64-unknown-linux-ohos/lib/liblibsodium.a` | Windows端交叉编译得到的OHOS libsodium静态库 |
| `rustdesk_harmonyos_build/native_rust_core/target/harmony/librustdesk_harmony_bridge.a` | 历史 Windows native core 构建产物；当前 verified core 通过 13 项目 GitHub Releases 下载，见 `CORE.md` |
| `rustdesk_harmonyos_build/vcpkg/` | vcpkg包管理器及已安装依赖；`downloads/buildtrees/packages`缓存已清理 |
| `harmonyos_build/` | 当前 HAP 输出目录，项目子目录名与 `11_Rustdesk_harmonyos/` 保持一致 |
| `harmonyos_stage/` | 临时 staged build 目录，可删除，可由脚本重新生成 |
| `rustdesk_harmonyos_signing/` | 便携签名材料目录，包含当前 `com.open.rundesk` HAP 签名所需 `.cer`、`.p12`、`.p7b` 和 `material/`；换电脑时必须随 `99_Temp` 一起保留 |
| `rustdesk_harmonyos_backups/` | 当前项目zip备份目录；只保留最新2份，旧备份清理时删除。备份必须统一写入此目录，不要在 `99_Temp` 下新建 `rustdesk_harmonyos_project_backup_*` 等散落目录；需要备份时运行 `scripts/backup_project.ps1`。 |
| `rustdesk_harmonyos_test_logs/` | 真机安装/启动日志目录；历史日志仅作参考，当前验证结果以`CONNECTION_DEBUG_LOG.md`为准 |

## 线上 Release 依赖

| 资产 | 作用 |
|------|------|
| `https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a` | 当前 RustDesk 1.4.7 OHOS native core，SHA256 `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8` |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip` | Linux CI 使用的 HarmonyOS SDK 包，必须包含 openharmony/hms SDK 和 previewer 依赖库 |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip` | Linux CI 使用的 Command Line Tools/Hvigor 剩余文件包 |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-020111` | 当前已验证 HAP/APP 发布结果，APP 资产以 `.app.zip` 形式上传 |
