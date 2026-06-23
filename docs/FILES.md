# 项目文件说明

> 每个代码文件的作用，修改前必读

> 2026-06-21 23:23 收口补充：`Index.ets` 负责 ID/IP 悬浮建议、格式化光标、官方对齐菜单、共享状态和未实现提示；`RemoteControl.ets` 负责会话菜单与紧凑重试对话框；`FileTransfer.ets` / `Terminal.ets` 已按设置页主题和滑动边界统一；`dvr.svg` 只用于设置页上方“显示设置”分组标题，下面同名条目继续使用原图标；输入控制继续使用原 `opt_mouse.svg`。最终产物和证据见 `AGENT_HANDOFF.md`。

> 2026-06-22 线上构建文件职责：`.github/workflows/build-harmonyos*.yml` 只能从显式 dispatch 输入或 latest Release 获取两架构 Core，禁止隐藏 secret/var URL 静默覆盖；`run_hvigor_with_sdk_patch.js` 把 arm64/x86_64 大小与 SHA256 一并写入 `CoreBuildInfo.ets`；两个审计脚本必须核对这些字段和 workflow 来源规则。

> 2026-06-21 更新：路径职责以 `docs/WORKSPACE_PATHS.md` 为准。所有构建、测试、缓存、日志和备份必须统一放在 `F:\Visual_Studio_Code\99_Temp` / `%VSCODE_ROOT%\99_Temp`，不要再使用 `F:\99_Temp`、`C:\99_Temp`、仓库内 `.codex_*` 或散落备份目录。

## 工作区项目匹配

`%VSCODE_ROOT%` 是包含 `11_Rustdesk_harmonyos/` 和 `99_Temp/` 的可移动工作区根目录。当前项目只依赖下列 RustDesk/HarmonyOS 相关目录；`01_DeepSeek-*`、`03_ Excel_VBA _database`、`04_Excel_VBA_Files`、`05_Excel_VBA_HR`、`06_Excel_VBA_Inventory`、`07 Rustdesk-api-server-pro`、`08_Gun_Rrub2`、`09_Win_desk_time`、`10_Tabssh.github.io`、`12_Monitor tool`、`98_Test` 等同级目录不是当前 HAP 构建依赖。

| 工作区目录 | 匹配结果 |
|------|------|
| `11_Rustdesk_harmonyos/` | 当前 Git 根和 HarmonyOS App 项目根，顶层直接包含 `AppScope/`、`entry/`、`docs/`、`scripts/` |
| `13_librustdesk_core/` | **核心独立项目**，包含 Rust 桥接层、C++ 桥接层、代码生成脚本、上游源码、OHOS 补丁、CI/CD |
| `11_Rustdesk_harmonyos/13_librustdesk_core/` | 本地 NTFS Junction，指向同级 `%VSCODE_ROOT%\13_librustdesk_core`，便于从 App 项目内直接进入核心项目；该链接已加入 `.git/info/exclude`，不作为仓库内容提交 |
| `99_Temp/rustdesk-master/` | **已清理/不应重建**。历史 RustDesk 上游源码副本；当前 core 源码以 `../13_librustdesk_core/rustdesk-master/` 为准 |
| `99_Temp/rustdesk_harmonyos_build/` | （历史/辅助）仅保留 OHOS/HMS/DevEco SDK mirror、vcpkg、外部依赖源码、tools、toolchains、patches；旧 target/HAP/clone/log 已删除 |
| `99_Temp/harmonyos_build/` | HAP 构建输出 |
| `99_Temp/harmonyos_stage/` | 可再生成的 HAP staged copy；2026-06-21 清理后当前不存在，构建脚本需要时重建 |
| `99_Temp/harmonyos_cache/` | Hvigor 缓存 |
| `99_Temp/rustdesk_harmonyos_signing/` | 当前可移动签名材料，`build-profile.json5` 通过相对路径引用 |
| `99_Temp/rustdesk_harmonyos_backups/` | 项目 zip 备份目录，只保留最新 2 份 |
| `99_Temp/rustdesk_core_backups/` | Core 项目 zip 备份目录，只保留最新 2 份 |
| `F:\99_Temp` / `\99_Temp` | **废弃**。历史盘符根临时目录，清理后不得再写入 |

## 文档目录 (docs/)

| 文件 | 作用 |
|------|------|
| `README.md` | 新对话接手入口，说明当前状态、问题结构和阅读顺序 |
| `WORKSPACE_PATHS.md` | 构建/测试/缓存/备份路径权威规范；定义 `99_Temp` 子目录职责和废弃路径 |
| `CORE.md` | 核心架构、可复现编译、HDC安装启动、运行验证清单 |
| `PROGRESS.md` | 当前功能进度、已完成事项、重点问题 |
| `CONNECTION_DEBUG_LOG.md` | 连接问题逐轮排查记录 |
| `ISSUES.md` | 问题库和易复发坑 |
| `FILES.md` | 文件职责和外部依赖目录 |
| ~~`DESIGN.md`~~ | 已合并到项目根 `README.md` |
| `UI.md` | UI布局、图标、核心页卡片细节 |
| `BUILD_ARCHIVE.md` | 历史构建、脚本、Ubuntu路径和早期会话归档 |
| `GIT_PUBLISH.md` | GitHub 发布说明。本地和远端均为项目根结构；包含正常提交推送流程和生成物禁止项。 |
| `FUNCTION_LOGIC_AUDIT_2026-06-06.md` | 最新 100 轮全功能逻辑检查、已修问题和后续补齐清单。 |

## 脚本补充 (scripts/)

| 文件 | 作用 |
|------|------|
| `AGENT_HANDOFF.md` | 2026-06-20 当前跨对话接棒入口；包含全部用户目标、验证证据、未完成边界、构建产物和继续顺序 |
| `switch_deveco_paths.ps1` | 在 portable `../99_Temp/...` 配置与 DevEco Studio 绝对路径配置之间切换；提交、脚本构建和换电脑前必须切回 portable |

## C++桥接层 (entry/src/main/cpp/)

> **注意**：核心相关文件已迁移到 `%VSCODE_ROOT%\13_librustdesk_core` 项目。本目录的 C++ 桥接层文件从 13 项目的 `cpp/` 目录同步。核心修改在 13 项目进行，修改后需同步到本目录并重新构建 HAP。

| 文件 | 行数 | 作用 |
|------|------|------|
| `CMakeLists.txt` | 75 | 构建配置，STATIC LINK MODE 链接 `librustdesk_core.a` 到 bridge SO，并链接 `native_avscreen_capture`/`native_buffer` 供共享录屏 native buffer 采集使用 |
| `rustdesk_bridge_loader.cpp` | 4553 | C++ NAPI桥接层，当前约400个NAPI注册，staticlib模式直接调用Rust C ABI；聊天四参调用需读`args[2]`内容参数，服务器 key 需随 start/connect 透传；direct session 命令的 bool 返回值必须透传给 ArkTS；共享录屏 native drain loop 使用 `OH_AVScreenCapture_StartScreenCapture`/`OH_AVScreenCapture_AcquireVideoBuffer`，并把 `OH_NativeBuffer` payload 通过 `rustdesk_bridge_update_incoming_screen_frame` 推入核心入站帧缓存 |
| `rustdesk_bridge_abi.h` | 427 | 当前声明Rust extern "C"函数；需与13项目`native_rust_core/src/bridge_api.rs`完全对齐，尤其注意 C ABI 返回类型变更和 incoming screen frame metadata/copy/update/clear 新接口 |
| `types/librustdesk_bridge/index.d.ts` | 415 | NAPI模块TypeScript类型声明，与C++ NAPI签名对齐；`sessionRecordScreen/sessionSwitchSides/sessionRequestVoiceCall/sessionCloseVoiceCall` 等 direct session 命令返回 boolean，native 屏幕采集函数返回 boolean/string 状态，并声明 incoming frame metadata/copy/update/clear |
| `types/librustdesk_bridge/oh-package.json5` | 6 | NAPI模块包配置 |

## Rust核心 (native_rust_core/)

> **注意**：Rust 桥接层已迁移到 `%VSCODE_ROOT%\13_librustdesk_core\native_rust_core\`。本目录的 `native_rust_core/` 仅作为历史参考，不再用于构建。核心修改在 13 项目进行，构建产物通过 GitHub Releases 下载。

| 文件 | 行数 | 作用 |
|------|------|------|
| `Cargo.toml` | - | crate配置，`crate-type=["staticlib"]`，`default-features=false`，`features=["use_dasp"]` |
| `build.rs` | - | 构建脚本，编译时生成 |
| `src/bridge_api.rs` | 2978 | C ABI导出层，当前约374个 `rustdesk_bridge_*` 导出，含 session/main/cm/plugin/install/incoming frame 等接口；initialize_runtime返回本地BridgeSnapshot避免上游stub空JSON透传 |
| `src/bridge_state.rs` | 130 | 桥接状态管理 |
| `src/lib.rs` | 50 | crate入口 |

## ArkTS页面 (entry/src/main/ets/pages/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `Index.ets` | 6025 | **主页面**，4个Tab(连接/聊天/共享/设置)，设置Tab代码全在此，核心页面4卡片布局+详情弹窗(Status/Error/Detail/File/Size/Hash/ELF/BuildTime/Source)，CoreModuleInfo多模块支持，核心状态简词(就绪/停止/未识)+弹窗详细描述，运行摘要卡片，统一搜索悬浮框，通讯录服务器同步，共享启动不再预申请 `CUSTOM_SCREEN_CAPTURE`，`captureRequired=true` 时启动 native 录屏提供首帧但真实运行仍只认 `incomingReady=true`，设置/会话同源 option，调试常亮，权限开关先同步更新再异步请求，hilog调试日志，设置行图标(Lucide stroke SVG via colorFilter)，服务器导入导出提示，聊天Tab固定显示当前/最近会话聊天内容并保留右侧图标，最近聊天摘要使用明确分隔符避免中文错字 |
| `RemoteControl.ets` | 5080 | **远程控制页**，视频渲染+输入控制+工具栏+手势，会话聊天浮窗自动滚动到最新消息；聊天按钮弹出语音/文字模式；远控更多菜单的切换主控端/截图/会话录制必须走核心 direct session function，会话录制禁止启动本机 `ScreenCaptureService`；本地音频上传当前提示不可用，避免metadata-only接口假启动 |
| ~~`Settings.ets`~~ | - | 已删除，设置功能合并到Index.ets设置tab |
| `FileTransfer.ets` | 1200 | 文件传输页面（已全面重构），Column 流式布局（header+toolbar+fileList+bottomBar），排序菜单/三点菜单/文件项菜单，多选+复制→粘贴，长按选中，隐藏文件过滤，菜单半透明主题色背景，顶部渐变遮罩，所有图标从 proicons 提取（ft_*.svg），进入/切到本地/刷新/上传/下载/本地新建删除前唤起 `DocumentViewPicker` 目录授权 |
| `LoginPage.ets` | 436 | 登录页面(OAuth+密码，统一走AccountService)，提供统一搜索入口过滤登录 provider |
| `Terminal.ets` | 470 | 终端页面（已重写），Column 流式布局（header+terminalScreen+customKeyboard），自定义终端键盘含 Ctrl/Alt/Tab/Esc/F1-F12 等特殊键，终端输出 Base64 解码显示 |
| `AddressBook.ets` | 487 | 地址簿页面 |
| `Chat.ets` | 432 | 聊天页面，移除固定示例回复和种子消息；发送失败恢复草稿，不把 failed 文本写入消息 |
| `MyDevice.ets` | 364 | 我的设备页面 |
| `ViewCamera.ets` | 323 | 摄像头页面；当前 official view-camera session 未接入，入口显示不可用，不能假连接 |
| `WebLoginPage.ets` | 232 | Web登录页面 |
| `Scan.ets` | 410 | 扫描页面，相机/相册二维码识别，服务器配置扫码直存 |

## ArkTS服务层 (entry/src/main/ets/services/)

| 文件 | 行数 | 作用 |
|------|------|------|
| `NativeRustDeskBridge.ts` | 5571 | **NAPI底层桥接**，ArkTS封装C++ SO；374 ABI/约400 NAPI surface 的安全包装与fallback，连接/共享服务透传自建服务器 key；direct session 命令返回值必须按 native boolean 透传，不能把函数存在当作成功；封装 native 屏幕采集 start/stop/active/stats 和 incoming frame metadata/copy/update/clear，快照包含 `captureRequired` 与 incoming frame 诊断字段 |
| `I18nService.ets` | 2117 | **国际化服务**，translate()/lt()，中英翻译，@State i18nVersion触发重渲染；核心停止态中文统一为“停止”，录屏/文件授权提示避免截屏误译 |
| `OfficialRustDeskBridge.ets` | 898 | 官方桥接高层封装，统一调用NativeRustDeskBridge；核心状态保留 `captureRequired`、`incomingFramePayloadReady`、`incomingFrameId`、`incomingFrameBytes`、`incomingFramesSeen`，避免把请求采集和真实 incoming ready 混淆 |
| `AppDataService.ets` | 1125 | **核心数据管理**，会话列表/连接状态/核心状态/发现列表，createRecentSession()优先用getPeerInfo()获取hostname(2026-05-31)，不再返回固定测试聊天消息，保存调试常亮偏好且调试常亮当前默认开启；旧演示别名/分组自动翻译已清理 |
| `ServerConfigCodec.ets` | 66 | 服务器配置导入导出编解码，复用官方 JSON→Base64→反转格式 |
| `ChatService.ets` | 637 | 聊天服务，持久化消息加载时重建会话摘要；发送成功后才落本地消息，过滤旧 `failed=`/`error=` 事件和本地 echo，按跨天/5分钟间隔显示时间 |
| `AccountService.ets` | 515 | 账户服务(token持久化/登录登出/PasswordLoginResult) |
| `FileTransferService.ets` | 537 | 文件传输服务；本地侧通过 `@ohos.file.fs` 读取真实下载目录/新建/删除，远端侧消费 official session 文件事件和 job 进度 |
| `CoreLoaderService.ts` | 373 | 核心SO加载服务(staticlib方案下仅做初始化检查)，文件选择授权走 TS 层 `FileAuthorizationService` |
| `AudioService.ets` | 344 | 音频服务(AudioRenderer, 48kHz mono S16LE) |
| `AppState.ets` | 330 | 应用状态管理 |
| `OfficialSessionTextFormatter.ets` | 346 | 会话文本格式化 |
| `InputService.ets` | 353 | 输入服务(鼠标/键盘/触摸) |
| `HttpClient.ets` | 415 | HTTP客户端 |
| `ClipboardService.ets` | 246 | 剪贴板服务(双向同步) |
| `PermissionService.ets` | 352 | 权限服务；统一请求麦克风/输入/悬浮窗/文件授权，文件访问默认走 `DocumentViewPicker` 目录授权；共享录屏不再通过普通权限列表预申请 `CUSTOM_SCREEN_CAPTURE`；文件授权结果映射显式使用 `PermissionRequestResult` 兼容线上 ArkTS strict |
| `FileAuthorizationService.ts` | 96 | 文件授权服务；先唤起 `DocumentViewPicker` 返回 URI，再记录 `READ_WRITE_DOWNLOAD_DIRECTORY` + `FILE_ACCESS_PERSIST` 权限结果，避免普通权限预检挡住文件访问授权弹窗 |
| `ScreenCaptureService.ets` | 225 | 屏幕捕获服务；仅用于共享/被控链路的 native `OH_AVScreenCapture_StartScreenCapture` 启动和 native buffer 统计，禁止截图 fallback、禁止 `AVScreenCaptureRecorder`/临时 mp4 探测，也禁止被远控会话录制菜单调用 |
| `TerminalService.ets` | 246 | 终端服务，打开/输入/resize/关闭走official Session，终端输出事件从`dataBase64`解码 |
| `WindowChromeService.ets` | 247 | 窗口管理(状态栏透明/全屏/系统栏颜色/保持屏幕常亮) |
| `EventBus.ets` | 171 | 事件总线 |
| `FrameService.ets` | 225 | 视频帧服务 |
| `PreferenceStore.ts` | 234 | 偏好存储(轻量KV)，包含调试常亮一次性默认开启迁移 |
| `LanDiscoveryService.ets` | 121 | LAN发现服务(启动一次发现，后续手动刷新) |
| `OfficialSessionTransport.ets` | 81 | 会话传输层，聊天发送优先走 `sessionSendChat` |
| `librustdesk_bridge.d.ts` | 462 | NAPI模块类型声明，包含 direct session boolean 返回、native 屏幕采集函数和 incoming frame metadata/copy/update/clear |
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
- **Index.ets**: 6013行，修改前定位到具体Builder方法；权限开关onChange必须先同步updateSettings再异步请求；调试日志用hilog不用console；搜索浮层和 ID 输入焦点不要互相抢焦点
- **RemoteControl.ets**: 4778行，视频帧性能敏感，避免ForEach；聊天浮窗尺寸和模式菜单要同时检查
- **I18nService.ets**: 所有翻译文本在此，新增语言需添加
- **ThemeConfig.ets**: 颜色通过AppStorage管理，不是color.json
- **BuildInfo.ets**: 每次构建前脚本自动更新BUILD_TIME

## 外部依赖目录 (`%VSCODE_ROOT%\99_Temp\` / Ubuntu挂载同名目录)

| 目录 | 作用 |
|------|------|
| `../13_librustdesk_core/` | 当前 RustDesk native core 独立项目；包含上游源码、Rust/C++桥接、代码生成脚本、OHOS patch 和 core CI/CD |
| `rustdesk-master/` | 历史 RustDesk 官方源码副本；当前 core 源码以 `../13_librustdesk_core/rustdesk-master/` 为准 |
| `rustdesk_harmonyos_build/` | 保留的历史/辅助依赖环境，仅含 ohos-sdk/hms-sdk/deveco-sdk/vcpkg/external-src/tools/toolchains/patches |
| `rustdesk_harmonyos_build/ohos-sdk/` | OpenHarmony Linux Native SDK，Rust交叉编译使用 |
| `rustdesk_harmonyos_build/deveco-sdk/` | DevEco/OpenHarmony SDK缓存，HAP构建使用 |
| `rustdesk_harmonyos_build/external-src/` | C依赖源码 (opus/libsodium/aom/libyuv/libvpx) |
| `rustdesk_harmonyos_build/build/` | **已清理**。旧依赖 build 输出，不再作为当前保留项 |
| `rustdesk_harmonyos_build/native_rust_core/target/` | **已清理**。旧 Windows native core target；当前 verified core 在 `99_Temp/librustdesk_core/cargo_target/`，见 `WORKSPACE_PATHS.md` 和 `CORE.md` |
| `rustdesk_harmonyos_build/vcpkg/` | vcpkg包管理器及已安装依赖；`downloads/buildtrees/packages`缓存已清理 |
| `harmonyos_build/` | 当前 HAP 输出目录，项目子目录名与 `11_Rustdesk_harmonyos/` 保持一致 |
| `harmonyos_stage/` | 临时 staged build 目录，可删除，可由脚本重新生成 |
| `rustdesk_harmonyos_signing/` | 便携签名材料目录，包含当前 `com.open.rundesk` HAP 签名所需 `.cer`、`.p12`、`.p7b` 和 `material/`；换电脑时必须随 `99_Temp` 一起保留 |
| `rustdesk_harmonyos_backups/` | 当前项目zip备份目录；只保留最新2份，旧备份清理时删除。备份必须统一写入此目录，不要在 `99_Temp` 下新建 `rustdesk_harmonyos_project_backup_*` 等散落目录；需要备份时运行 `scripts/backup_project.ps1`。 |
| `rustdesk_harmonyos_test_logs/` | 真机安装/启动日志目录；历史日志仅作参考，当前验证结果以`CONNECTION_DEBUG_LOG.md`为准 |
| `librustdesk_core/` | 构建前下载 native core 的临时目录；`scripts/fetch_native_core.ps1` 和 Linux 构建脚本会先下载到这里再替换 `entry/src/main/libs/arm64/librustdesk_core.a` |

## 线上 Release 依赖

| 资产 | 作用 |
|------|------|
| `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a` | 当前默认 RustDesk OHOS native core 来源；构建前智能刷新，当前 latest release `core-81`，SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829` |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip` | Linux CI 使用的 HarmonyOS SDK 包，必须包含 openharmony/hms SDK 和 previewer 依赖库 |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip` | Linux CI 使用的 Command Line Tools/Hvigor 剩余文件包 |
| `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/OpenRustdesk-Build-v0.22.7` | 当前最新线上 App release；已包含 core-81 `captureRequired`、文件授权 picker-first、共享录屏 native buffer 触发和验包脚本 GUID 临时文件修复；push workflow `27567811582` 与 release workflow `27568044749` 均成功 |

## SVG 图标资源 (entry/src/main/resources/rawfile/)

### 文件传输图标（2026-06-23 从 proicons 提取，stroke 格式）

| 文件 | 用途 |
|------|------|
| `ft_folder.svg` | 文件夹图标 |
| `ft_file.svg` | 普通文件图标 |
| `ft_local.svg` | 本地切换 |
| `ft_remote.svg` | 远端切换 |
| `ft_sort.svg` | 排序（三横线样式） |
| `ft_copy.svg` | 复制 |
| `ft_cut.svg` | 剪切 |
| `ft_paste.svg` | 粘贴 |
| `ft_delete.svg` | 删除 |
| `ft_rename.svg` | 重命名 |
| `ft_new_folder.svg` | 新建文件夹 |
| `ft_select_all.svg` | 全选 |
| `ft_hidden.svg` | 显示隐藏文件 |
| `ft_detail.svg` | 详情 |
| `ft_open.svg` | 打开 |
| `ft_refresh.svg` | 刷新列表 |

### 其他新增图标

| 文件 | 用途 | 格式 |
|------|------|------|
| `checkmark.svg` | 勾选标记（菜单右侧勾选） | stroke |
| `refresh.svg` | 刷新（替换旧版） | stroke |
| `checkbox-checked.svg` | 已勾选复选框 | stroke |
| `checkbox-unchecked.svg` | 未勾选复选框 | stroke |
