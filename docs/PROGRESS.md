# 功能进度与优化方向

> 更新时间：2026-06-15 已验证。当前状态以本文、`README.md`、`CORE.md`、`CONNECTION_DEBUG_LOG.md` 为准；更早的会话内容已合并到 `BUILD_ARCHIVE.md`，只作为历史记录。每轮修改必须同步更新相关文档并进行构建验证。

## 术语约定

- **TAB** = 底部主菜单4项（连接/聊天/共享/设置），对应 `currentTab: HomeTab`
- **选项卡** = ID输入框下方的子选项（历史/收藏/发现/通讯录/登录/核心），对应 `currentConnectTab: ConnectTab`

## 当前状态快照

- 2026-06-06 项目结构已提升到根目录：`11_Rustdesk_harmonyos/` 直接作为 Git 根和 App 项目根，历史内层 `rustdesk_harmonyos/` 只作为本地坏缓存壳忽略；`99_Temp/` 按当前工作区位置匹配，不依赖固定盘符。
- HAP 签名材料已放入 `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing/`，`build-profile.json5` 使用相对路径引用；签名 profile 校验通过，bundleName 为 `com.open.rundesk`。
- HAP 构建先复制干净副本到 `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`，再把 Hvigor 日志、HAP 输出、Native `.cxx` 中间目录放到 `%VSCODE_ROOT%\99_Temp`；当前本地 BuildInfo 编译时间 `2026-06-15 07:15`，App 显示版本 `0.22.4`，versionCode `1000107`。
- 2026-06-12 线上 Linux 构建脚本已改为 HAP-only：`.github/workflows/build-harmonyos.yml` 和 `.github/workflows/build-harmonyos-linux.yml` 只构建/上传 `.hap`，不再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。
- 线上构建依赖已拆分为 SDK 包和 Hvigor/Command Line Tools 剩余文件包：
  - `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip`
  - `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip`
- Linux CI 已显式检查并加载 `openharmony/previewer/common/bin/libcjson.so`、`libsec_shared.so` 和 Ark ets-loader 的 `libsec_shared.so`，避免 Hvigor/previewer 动态库缺失。
- 最新 100 轮功能逻辑审查已完成，审查明细见历史审计文档；当前结论为出站远控链路最成熟，终端和文件传输核心事件已接入 core-73，core-74 补齐旧 Harmony source mirror 剪贴板防回归，core-75 补齐自定义服务器 key 透传，core-76 修正聊天事件语义；App 侧本轮补齐共享录屏授权、文件授权 API、搜索/设置/会话菜单状态同步。入站被控 live frame、音频真实 payload 和远端剪贴板仍需继续补齐 native 回调或隐藏未实现入口。
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
  - release：`core-80`
  - 大小：`131,624,954` bytes (`125.53 MB`)
  - mtime/compile time：`2026-06-15 07:15`
  - FNV-1a 1MB：`bea81e95`
  - SHA256: `4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`
- 当前已验证 HAP：
  - 本地 BuildInfo 编译时间：`2026-06-15 07:15`
  - 本地 App 显示版本：`0.22.4`
  - 本地 versionCode：`1000107`
  - bundle：`com.open.rundesk`
  - 最新线上 release：`harmonyos-20260612-065038`
  - signed HAP：`entry-default-signed.hap`，`18,968,380` bytes，SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`
  - 2026-06-09 无线安装启动成功，hilog 确认 `coreReady=true`、`adapter=official-native`，无崩溃。
  - 2026-06-09 官方一致性修复后实机验证：HAP 安装启动成功，`coreReady=true`，Bridge 在线查询正常（onlines: 2），远程控制连接建立（加密中继），handshake 诊断正常（fingerprint、connection-type、quality-status），核心详情页新增属性（桥接函数数、NAPI注册数、核心版本、设备ID、指纹）已集成。
- 核心已经接入真实 RustDesk session 路径，历史文档中的"仅模拟连接 / 真实网络未实现"不是当前状态。
- 上一轮实机验证曾确认控制端收到真实视频帧，截图显示远程画面，不再只是等待视频流占位。
- 2026-06-12 等待视频流复查：出站控制端仍有真实 `on_rgba -> video-frame` 路径；入站被控端因 Harmony `ScreenCaptureService`/desktop server 未接入，不能再对外标记 `incomingReady=true`。11 端共享开关已在录屏失败时回滚，13 端核心 `main_start_service(true)` 已改为返回 `incomingReady=false` 和明确错误，避免其他设备连接后一直等待视频流。
- 2026-06-14 共享状态复查：共享页已把本机屏幕采集状态和核心 `incomingReady` 拆开。录屏/采集探测 active 只显示黄色 `Recording Probe` 并保留停止按钮，不再展示“服务运行中”、设备 ID 或一次性密码；真正运行态、共享 TAB 绿点和密码展示只由 `settings.serviceEnabled && officialCoreState.incomingReady` 决定。
- 2026-06-15 共享启动顺序修复：`Index.toggleIncomingService(true)` 不再先启动本机录屏探针，改为先写入核心选项并调用 `setIncomingServiceEnabled`；只有核心返回 `incomingReady=true` 后才启动屏幕采集。核心未就绪时显示 `Share requested/Requested` 和核心 detail/error，避免录屏 API 与共享状态判断冲突。
- 2026-06-13 core-70 复测：13 项目 run `27459455573` 成功发布 `core-70`；11 项目下载后 HAP 构建、native/signature 校验和无线安装通过。设备锁屏导致 `aa start` 返回 `Error Code:10106102`，App 未运行，本轮抓到的 hilog 没有 `coreReady`/`video-frame` 证据；视频流需解锁后继续复测。
- 2026-06-13 UI/UX优化轮：核心详情弹窗精简(18→8行)、聊天浮窗优化(宽度/位置/可调整大小)、构建脚本智能核心检测(HTTP HEAD比对)、全量图标主题匹配(10处colorFilter→fillColor)、scan_frame主题匹配、账户菜单修正(登录提供方图标)、会话菜单布局统一(图标左/文字中/选项右)、菜单面板优化(无关闭按钮/四角圆角/半透背景)、显示质量面板精简(7项/140宽/全透)、键盘输入优化(仅远程输入时画面平移/computeKeyboardOffset重叠量计算)、质量监控连接后不显示修复、工具栏底部安全区避让(margin+avoidNavigationBarHeight)、聊天按钮可关闭面板、设置页开关统一逻辑(applySessionOption+setLocalOption)、画面平移边界限制(clampPanOffset/gap=4px/竖向左右可到屏幕边缘)、显示设置标题旋转按钮(opt_rotate.svg/PanelHeaderAction)、质量面板新增编码行/连接标签改为"连接"、关于页检查更新禁用/指纹行点击复制、ID卡片连接模式per-card化(PreferenceStore peer_connect_modes)。版本0.16.4，HAP构建验证通过。
- 2026-06-13 15项问题清单修复轮：1.输入法特殊符号(isAlphanumericText/sessionInputString)；2.中键滚动速度(步长20px)；3.横向显示切换系统屏幕方向(setLandscape)；4.聊天功能链路(C++ SendChatMessage读args[2]/ChatService匹配chat_client_mode)；5.聊天输入区高度(Chat.ets 36→22/RemoteControl 34→20)；6.扫描优化(成功自动复制+导入+退出)；7.核心按钮改为启动/停止2个；8.核心详情弹窗运行行拆分(Status/Summary/Error/Detail)；9.ID输入框自动激活修复；10.ID卡片搜索确认已有；11.通讯录同步添加服务器API调用；12.ID输入悬浮匹配建议；13.平台图标修复(resolvePlatformForDevice)；14.共享页启动服务修复(startCapture异常后仍启动incoming)；15.聊天消息时间优化(shouldShowTimestamp 5分钟内同发送者只显示最后一条)。额外修复：scan_frame.svg替换、输入法关闭修复(onBlur延迟300ms+键盘按钮状态同步)、computeKeyboardOffset方向反转修复(maxShift取Math.max(0,imageTop))、调试日志清理(3条[IME])。版本0.16.4，HAP构建验证通过，无线安装验证通过。
- 2026-06-14 键盘避让重构：删除computeKeyboardOffset()，改为修改panOffsetY模拟双指平移(preKeyboardPanOffsetY保存/恢复)；@Watch监听showKeyboard和avoidKeyboardHeight；工具栏从Column流移出改为Stack悬浮(zIndex=5)，预览区铺满到屏幕底部(previewHeight=到屏幕底部的真实距离)；distanceFromBottom<=0推kbH，0<x<kbH推kbH-x，>=kbH不平移；ID匹配悬浮窗改为Stack绝对定位(position+zIndex=10)宽度70%。HAP构建验证通过，无线安装验证通过。
- 2026-06-14 旋转画面修复：新增isLandscapeMode替代viewRotation=90(setLandscape+rotate叠加导致180度)；isQuarterTurn/transformPreviewPointToImageSpace改用isLandscapeMode；closeSession/goBack恢复横屏；ID输入框默认焦点放到connect-tab-btn。HAP构建验证通过，无线安装验证通过。
- 2026-06-14 底部tab栏修复：buildFillTabItem中width('100%')还原为layoutWeight(1)(Row中多个100%宽度子项只有第一个可见)；buildOfficialConnectPanel外层从Stack还原为Column(悬浮窗改用.overlay()属性)；ForEach还原为i18nVersion作key。HAP构建验证通过，干净卸载重装验证通过。
- 2026-06-14 核心/App 对接复查已闭环：13 项目外层与旧副本 `harmony_bridge/core.rs` 已把 terminal open/input/resize/close 从 `false` stub 改为调用 official `Session`，并把 `TerminalResponse` 转成 `terminal-response`、`terminal-output`、`terminal-closed` 事件；终端数据使用 base64 穿过事件 JSON，11 项目 `TerminalService` 负责解码，`Terminal.ets` 只处理 opened/error/closed 状态，避免重复输出。核心 `pull_audio_frames_json()` 空队列改为 `[]`；本地音频上传因 ABI 只有 metadata、无采样 payload，远控菜单改为明确提示 `Audio upload unavailable`，不再假启动麦克风。13 项目 C++ `SendChatMessage`/`SessionSendChat` 同步 11 项目四参兼容读 `args[2]` 的修复。核心 commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 已推送，GitHub Actions run `27483922931` 成功发布 `core-71`；11 项目已下载 core-71，增量和全量 HAP 构建通过，HAP native/signature 校验通过，无线安装启动通过，hilog 确认 `coreReady= true`、`query-onlines-result` 正常且 app fatal/panic/signal 为 0。
- 2026-06-14 文件传输对接追加：13 项目已补齐 `HarmonyHandler` 文件传输回调事件（`folder-files`、`file-transfer-start`、`job-progress`、`job-done`、`job-error`、`create-remote-dir`、`delete-remote-path`）并让 `switch-sides` option 路径调用 official `Session::switch_sides()`；核心 commits `9c6ad4d`、`275b231e11aefd4a2e51050fc74fbdeba9c566bd` 已推送，run `27485061967` 成功发布 `core-73`。11 项目 `FileTransferService.ets` 已去掉本地示例种子文件，改为用 `@ohos.file.fs` 读取真实 `/storage/Users/currentUser/Download`，本地新建/删除也走文件系统，上传前检查源路径存在；core-73 下载后全量 HAP 构建、验包和无线安装通过，设备锁屏导致启动运行态待复测。
- 2026-06-14 摄像头查看入口收敛：`ViewCamera.ets` 原先 `startCameraStream()` 会直接显示已连接但没有 official view-camera session；近期菜单中的 `View Camera` 已改成灰色不可用提示，页面自身也只显示 `Camera entry unavailable`，避免假连接。
- 2026-06-14 剪贴板和一次性命令提示收敛：远控 `Send Clipboard Keys` 现在检查 `NativeRustDeskBridge.sendClipboardData()` 返回值，native/core 未接收时提示 `Failed to send clipboard`，不再显示成功；`sendSessionAction()` 和 `sendOptionCommand()` 未被 native/core 处理时提示 `Command unavailable`，不再写本地 option 并显示“本地排队”。
- 2026-06-14 core-74 验证：13 项目旧 Harmony source mirror 的 `send_clipboard_data()` 已同步 active bridge，run `27486100946` 成功发布 `core-74`。11 项目下载 latest core 后全量 HAP 构建为 `0.19.0` / versionCode `1000090`，验包、无线安装、解锁后启动和 hilog `coreReady=true` 运行态验证通过。
- 2026-06-14 core-74 最终复核：文档更新后再次在已解锁手机上执行 skip-build 安装启动，`install bundle successfully`、`start ability successfully`；进程 `12565` 存活，`reports/hilog_latest_after_core74_post_docs_unlocked.txt` 记录 `coreReady= true` 7 次、`query-onlines-result` 14 次，app fatal/panic/signal 为 0。
- 2026-06-14 构建脚本修复：`stage_project_for_build.ps1` 增加 `/XJ` 并显式排除 app 根下的 `13_librustdesk_core` junction，避免 staged copy 跟随核心项目和 `.git/refs/codex/...` 深路径；旧坏 staging 清理增加只读属性清理和长路径兜底删除。核心构建必须从真实 `%VSCODE_ROOT%\13_librustdesk_core` 执行，不能从 11 项目内 junction 路径执行，否则 build root 会错误落到 `%VSCODE_ROOT%\11_Rustdesk_harmonyos\99_Temp` 并找不到 vcpkg installed root。
- 2026-06-14 核心下载脚本容错：`fetch_native_core.ps1` 在远程 latest core HEAD/下载失败但本地 `entry/src/main/libs/arm64/librustdesk_core.a` 存在且通过大小/SHA校验时，改为复用本地核心继续构建；只有本地核心缺失或校验失败时才中止。
- 2026-06-14 本轮功能缺失复查：连接 tab 返回不再聚焦 ID 输入框；登录/历史/收藏/发现/通讯录/核心搜索入口统一为从搜索图标向左悬浮展开；通讯录登录成功和刷新按钮触发服务器同步且刷新按钮旋转；核心页按钮拆成开始/重启与加载/停止双状态；共享页启动先申请真实录屏授权并启动 `AVScreenCaptureRecorder` 探测，密码刷新立即更新；自建服务器连接把 key 传到 start/connect bridge 并清理旧 server option；设置页与会话菜单共用同一 option 状态，图像质量可调；关闭会话可触发锁屏，被控保持亮屏和关于页调试常亮已接入窗口 keep-screen-on；文件授权 API 统一请求 `READ_WRITE_DOWNLOAD_DIRECTORY`、`FILE_ACCESS_PERSIST` 并唤起 `DocumentViewPicker`；聊天发送失败不再写入 failed 文本，时间按 5 分钟/跨天间隔显示，远控聊天按钮弹出语音/文字模式。增量 HAP 构建已通过，等待最新 core 发布后做全量构建和实机验证。
- 2026-06-14 旧逻辑清理：`AppDataService` 清掉早期演示设备别名、备注和分组的自动翻译映射，避免用户真实的 `Design Workstation`、`QA`、`Retail` 等字段被误改；只保留明确旧自动名 `远程/Remote + 数字ID` 的清理逻辑。增量 HAP 构建 `0.19.5` / versionCode `1000095` 通过。
- 2026-06-14 core-76 全量验证：13 核心 `core-75`（自建服务器 key 透传）和 `core-76`（聊天 `chat-error/chat-sent/chat-message` 语义）均发布成功；11 项目下载 latest core 后全量 HAP 构建为 `0.20.0` / versionCode `1000096`，`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过，signed HAP `18,909,325` bytes / SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`；无线安装成功且 `bm dump` 已显示 `0.20.0`，但设备当前密码锁屏导致 `aa start` 返回 `Error Code:10106102`，运行态 hilog 待手动解锁后继续复测。
- 2026-06-15 质量监控和备份脚本复查：远控连接质量浮层改为基础 7 行 + `qualityMetricItems` 动态指标滚动显示，复用已有缓存不增加解析频率；`backup_project.ps1` 排除 `13_librustdesk_core` junction 并使用 `/XJ`，性能优化前备份已生成 `F:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_backups\rustdesk_harmonyos_20260615_000050.zip`；连接链路审计通过 `50 PASS, 0 FAIL, 0 SKIP`。
- 2026-06-15 调试常亮临时默认开启：关于区 `Debug Keep Screen Awake` 默认值改为 `true`，新增一次性迁移 `debug_keep_screen_awake_default_on_20260615`，升级后自动开启一次以避免调试安装后手机自动锁屏；用户手动关闭后不会被后续启动覆盖。
- 2026-06-15 USB/无线安装复查：`AUTO_BUILD_INSTALL.bat` 新增 `usb/--usb` 目标模式，`scripts\AUTO_BUILD_INSTALL.bat --skip-build usb` 只检测 USB/local HDC 目标并跳过无线重试；当前电脑 USB HDC 返回 `[Empty]`。随后用户打开无线，`scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 已成功安装并启动 `0.20.3` / versionCode `1000099` 到 `192.168.11.100:36169`，`pidof com.open.rundesk` 返回 `26834`，连接链路审计 `50 PASS, 0 FAIL, 0 SKIP`。
- 2026-06-15 最新无线复装：USB-only 脚本/文档变更重新构建后，`scripts\AUTO_BUILD_INSTALL.bat --skip-build auto` 已成功把 `0.20.4` / versionCode `1000100` 安装并启动到 `192.168.11.100:36169`；`bm dump -n com.open.rundesk` 确认设备端版本一致，`pidof com.open.rundesk` 返回 `29101`，signed HAP `18,917,915` bytes，SHA256 `D14C9DECF5199277F0AB7E97BBFCDF540BACEB06BCDA3AB74581F09A4CBF3CDB`。同包 `verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 验证 native/signature 通过，`audit_connection_chain.ps1` 通过 `50 PASS, 0 FAIL, 0 SKIP`。
- 2026-06-15 v0.20.5 共享启动顺序验证：共享开关不再提前启动 `AVScreenCaptureRecorder`，核心未 ready 时只显示 `Share requested/Requested`。增量 HAP 构建、native/signature 验包和连接链路审计均通过；signed HAP `18,928,713` bytes，SHA256 `E174E07ABB77CBF3E17489AABFEBDC7A5827A7DDE409206C59377C4BA9631FF0`；无线安装启动到 `192.168.11.100:36169` 成功，设备端 `versionName=0.20.5`、versionCode `1000101`，进程 `39312` 存活。
- 2026-06-15 core-78 全量验证：发现 13 核心项目 `cpp/rustdesk_bridge_abi.h`/`rustdesk_bridge_loader.cpp` 仍是一参 `rustdesk_bridge_session_send_chat(content)`，会在后续同步时覆盖 11 App 已修复的四参聊天路径；随后又发现核心 d.ts 少了自定义服务器 `key` 参数。已在真实 `F:\Visual_Studio_Code\13_librustdesk_core` 修正并本地构建通过；核心 commits `034e446`、`cc5f4de` 已推送，GitHub Actions run `27515510727` 发布 `core-78`。11 App 已下载 release asset `131,470,442` bytes / SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`，全量构建 `0.21.0` / versionCode `1000102`，signed HAP `18,928,728` bytes / SHA256 `491ED6E5CF1A8B6E2DD3F1E4661D99C15A4EB7D9B7B6FCB4A45BC92346BE2F90`；验包、连接链路审计、无线安装启动均通过，设备端进程 `41841` 存活，hilog `coreReady` 14 次、`query-onlines-result` 20 次，app fatal/panic/signal/`exit(-1)` 为 0。
- 2026-06-15 远控 direct session 命令接入修正已完成 core-79 验证：13 核心 commit `bc36b1d` 已由 GitHub Actions run `27516993020` 发布 `core-79`，`session_toggle_privacy_mode/session_switch_display/session_enter_or_leave/session_leave/session_switch_sides/session_record_screen/session_request_voice_call/session_close_voice_call` 从 Rust bridge 到 C ABI/C++ NAPI/d.ts 均改为 bool 返回；核心补 `voice-call-*`、`record-status`、`screenshot-response` 事件。11 App 同步更新 `entry/src/main/cpp/`、`NativeRustDeskBridge.ts`、`RemoteControl.ets`：远控“切换主控端/截图/会话录制/语音聊天”改用 direct core function，会话录制不再请求本机录屏权限或启动 `ScreenCaptureService`，新增相关中文 toast。`scripts\build_full_hap.bat` 已拉取 core-79 并构建 `0.22.0` / versionCode `1000103`；signed HAP `18,929,896` bytes / SHA256 `C8EB6B133B71752F50447410DE3E9DECC0BDE3EFD3630E8CBA9AB015E3A39F96`；验包、连接链路审计、无线安装启动和 app-only hilog 验证均通过。
- 2026-06-15 共享/文件授权复查：共享启动入口去掉对 `CUSTOM_SCREEN_CAPTURE` 的显式预申请，避免先唤起截屏/屏幕捕获授权；该 `0.22.1` 阶段屏幕采集仍由 `AVScreenCaptureRecorder` 在核心 `incomingReady=true` 后触发，已在 `0.22.2` 替换为 native `StartScreenCapture`。文件传输页进入、切到本地、刷新本地、上传/下载/本地新建/删除前统一走 `DocumentViewPicker` 目录授权，`PermissionService.requestFileAccessAuthorization()` 默认也改为目录授权模式。增量构建 `0.22.1` / versionCode `1000104` 通过，signed HAP `18,953,784` bytes / SHA256 `F16398FCB29E9E4F24131602D7B03C7BEED0A88BE0C37463BC7238AFF4C31A06`；验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端进程 `56711` 存活，app fatal/panic/signal/`exit(-1)` 为 0。
- 2026-06-15 共享录屏底层切换：`ScreenCaptureService` 不再创建 `AVScreenCaptureRecorder` 或临时 mp4，新增 C++ NAPI `startNativeScreenCapture/stopNativeScreenCapture/isNativeScreenCaptureActive/getNativeScreenCaptureStats`，底层使用 `OH_AVScreenCapture_StartScreenCapture`、`OH_AVScreenCapture_AcquireVideoBuffer` 和 native buffer map/unmap 做采集状态统计；CMake 已链接 `native_avscreen_capture`、`native_buffer`。增量构建 `0.22.2` / versionCode `1000105` 通过，signed HAP `18,946,878` bytes / SHA256 `9F4C40E9B10BE4D88BA5B76A24C887B1A8586F1A2812619CDC48C843C97DE1DA`；验包、连接链路审计、无线安装启动和严格 app hilog 均通过，设备端进程 `62121` 存活，app fatal/panic/`exit(-1)` 为 0。
- 2026-06-15 core-80 共享入站帧缓存接入：13 核心 commit `12ad723` 已由 GitHub Actions run `27526413545` 发布 `core-80`，线上 asset `131,624,954` bytes / SHA256 `4047C8432BCA6C7F5FECBD4E1D6F55BE9717F28889B4699043A74138800E0E2A`，release body 已补中文说明。11 App C++ drain loop 会将 `OH_NativeBuffer` payload 推入核心 `incoming_screen_frame` 缓存并暴露 metadata/copy/clear wrapper；`incomingReady` 仍保持 false，避免未接 desktop server/video source 时假共享。强制下载线上 core 后增量构建 `0.22.4` / versionCode `1000107` 通过，signed HAP `18,968,380` bytes / SHA256 `7C0B0D7AF7FDD224908F6CE10323AA7FD8E11C0BCB233DD03936513219A321C5`；验包、66 项连接链路审计、无线安装启动和干净 app hilog 均通过，设备端进程 `14881` 存活，app fatal/panic/`exit(-1)` 为 0。
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
- 2026-06-14 线上 App 状态：最新 release 仍是 `harmonyos-20260612-065038`；最新 workflow run `27443845710` 是旧提交 `0000da6` 的失败 run，尚未包含本地已验证的 core-80/incoming frame/direct session/permission/HAP-only/staged signing/staging junction 修正。发布前需推送并重跑 workflow。

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
- 文件传输权限申请已补齐 `READ_WRITE_DOWNLOAD_DIRECTORY` + `FILE_ACCESS_PERSIST`，并通过 `FileAuthorizationService.ts` 唤起 `DocumentViewPicker` 获取文件/目录 URI 授权；TS 服务不能 import ETS，供 `CoreLoaderService.ts` 等 TS 调用的授权逻辑必须放在 TS 文件中。
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
- **共享服务启动**：Screen Capture 开关现在只在核心 incoming ready 后启动 native `OH_AVScreenCapture_StartScreenCapture` 屏幕采集；若 native 采集或 incoming 未就绪必须回滚状态并记录 hilog，不能显示假运行。
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

- **共享服务启动**：当前 App 侧已改用 C++ NAPI `OH_AVScreenCapture_StartScreenCapture` + native buffer 统计，禁止回退截图 API，也禁止再使用 `AVScreenCaptureRecorder`/临时 mp4 做当前共享探测；后续重点是把 native buffer frame 与 RustDesk desktop server 的被控视频源桥接起来，并在无视频源时继续保持 `incomingReady=false`。
- HAP 体积优化：strip、LTO、减少未用 crate feature，目标 < 25MB。
- 构建流程自动化：串联 native core 构建、HAP 构建、安装、启动、日志采集。
- 音频功能验证：确认 opus/staticlib 状态后再启用远程音频。
- 会话稳定性：围绕 `session-connected`、`video-frame`、`session-closed`、retry dialog 做 USB 日志闭环。
- 文档维护：当前状态写入 `README.md`、`CORE.md` 和 `CONNECTION_DEBUG_LOG.md`；历史会话内容统一归档到 `BUILD_ARCHIVE.md`。

## 2026-06-03 最新追加

- 扫码页已改为相机扫码路径：`Scan.ets` 使用 HMS `customScan` + `XComponent` 相机预览，页面仅保留返回、重扫、复制扫到的内容。扫码结果会写入最近会话和通讯录，复制走 `ClipboardService`。
- 共享服务已多轮修复：历史 `@ohos.screenshot.capture()` 探测/截图 fallback 已废弃；当前 `ScreenCaptureService` 使用 native `OH_AVScreenCapture_StartScreenCapture` 启动原生屏幕采集并统计 native buffer；native `set_incoming_service_enabled()` 会写入官方 server option 并返回明确状态。
- 最新 HAP 已安装到 USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%`，但 `aa start` 被设备锁屏阻止：`Error Code:10106102`。需要设备手动解锁后继续复测共享 Tab 启动服务和 hilog。
- 服务器配置已调整为官方默认隐含配置：`AppDataService` 默认存储空字符串，运行时通过 `resolveServerConfig()` 将空 ID/Relay/API 分别回落到官方 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`。设置页不再显示官方服务器明文，显示为“官方默认”。
- 后续 10 轮全功能覆盖检查待共享启动复测后执行，范围包括连接、共享、权限、扫码、登录、通讯录、聊天、文件、显示/输入、会话命令（含发送重启/关机）等细小功能；每轮修改后立即更新文档并构建验证。
- 历史共享截图 fallback 已彻底废弃：USB 实机确认 `@ohos.screenshot.capture()` 会触发 `signal:6` 退出，不能作为持续录屏方案。后续任何共享/被控改动都必须使用录屏 API 或明确不可用，不得重新引入截图轮询。
- 2026-06-15 更新：当前 App 侧已切到 native `OH_AVScreenCapture_StartScreenCapture` / `AcquireVideoBuffer` 路径；App 侧可启动原生采集并统计帧，但真实被控视频流仍要继续接入 Harmony 录屏帧到 RustDesk desktop server 的桥。

## 2026-06-03 10:53 共享服务 USB 复测结论

- 最新 HAP 构建时间：`2026-06-03 10:52`，已安装到 USB 设备 `%RUSTDESK_HARMONY_USB_TARGET%` 并启动成功。
- App 进程稳定存在：`com.open.rundesk`，本轮日志未再出现 `signal:6`、`LastFatal` 或 RustDesk 进程 `Unexpected call: exit(-1)`。
- native `set_incoming_service_enabled()` 已调整为 Harmony 安全路径：不再调用会触发 appspawn 退出的桌面端 `start_server(true, false)`，而是写入 server option、`stop-service=N`、标记 incoming requested 并刷新 rendezvous 状态。
- native `get_core_snapshot_json()` 已补齐 `incomingReady` 快照，前端共享状态不会再因刷新快照丢失 incoming 状态。
- `Index.toggleIncomingService()` 的 15 次轮询重试已改为单次延迟刷新；USB 日志中 `incoming-service-requested` 计数从多次重复降为 `1`。
- 当前 App 侧已改用 native `OH_AVScreenCapture_StartScreenCapture` 做原生屏幕采集启动和 native buffer 统计，截图 fallback 继续禁止；后续真正远程被控画面仍需要把 Harmony 录屏帧接入 RustDesk desktop server/live frame 链路。

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
- 明确未伪装实现：`switch-sides` 已在 core-73 的 `apply_session_option()` 路径调用 official `Session::switch_sides()`；`session-action=shutdown` 仍没有官方协议字段，继续作为后续协议/平台扩展缺口记录。

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
- 录屏/共享链路复查：为避免 USB 实机 `signal:6`，`ScreenCaptureService` 继续禁止截图 fallback；2026-06-15 已改用 native `OH_AVScreenCapture_StartScreenCapture` + `AcquireVideoBuffer` 做原生采集启动和帧统计，共享服务可进入 native capture/incoming requested 状态，但真实被控画面仍依赖后续 Harmony 录屏帧到 RustDesk desktop server 的桥。
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
- **屏幕采集状态确认**：历史 `@ohos.screenshot.capture()` fallback 已确认会触发 signal:6 并禁止使用；2026-06-15 起 `ScreenCaptureService` 使用 native `OH_AVScreenCapture_StartScreenCapture` 和 `OH_AVScreenCapture_AcquireVideoBuffer` 做原生采集启动与 native buffer 统计。真实屏幕采集需继续接入 Harmony 录屏帧到 RustDesk 被控视频源。

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
