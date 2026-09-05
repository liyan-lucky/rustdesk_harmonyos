# 当前仓库状态

更新时间：2026-09-05

## 审批流程 v9.7

- **审批前画面控制**：在 C++ 层 `NativeScreenCaptureState` 添加 `paused` 原子标志，drain loop 在 `paused=true` 时推送黑色画面帧，`paused=false` 时推送真实画面帧
- **click 模式**：服务启动时默认暂停；审批对话框弹出时暂停；接受后恢复；拒绝/断开后保持暂停
- **非 click 模式**：服务启动时恢复；`login-authorized` 事件后自动恢复画面推送
- **自动暂停**：`PullSessionEventsJson` 在 C++ 层检测到 `incoming-connection` 或 `login-authorized` 事件时自动设置 `paused=true`
- **已知遗留**：第一次审批前仍有一瞬间真实画面泄漏；断开连接后对方画面一直黑色等待（CM 接口在 HarmonyOS 上不工作，无法真正断开连接）

## 设备信息同步

- 按官方 RustDesk 定义区分通讯录联系人字段与本机设备 `sysinfo`。HarmonyOS 端现通过核心 `get_sysinfo()` 上报 `cpu`、`memory`、`os`、`hostname`、`username`，并补充 `version`、`id`、`uuid` 到 `/api/sysinfo`，不再发送空的 CPU/内存字段。

## 定位

`rustdesk_harmonyos` 是独立的 HarmonyOS / OpenHarmony RustDesk 兼容客户端仓库，采用 ArkTS Stage UI、C++ NAPI 桥接和 Rust 静态库核心。项目源码按 `AGPL-3.0-only` 分发。

本项目是第三方兼容客户端，不属于 RustDesk 官方发布、认可、赞助或背书项目。

## 当前工程信息

- `oh-package.json5`：`modelVersion` 为 `6.1.1`，包名为 `rustdesk_harmonyos`，版本字段为 `1.0.0`。
- SDK 配置：两个 product 的 `compileSdkVersion` / `targetSdkVersion` 均为 `6.1.1(24)`；HarmonyOS 与 OpenHarmony product 的最低兼容版本分别为 `6.1.0(23)` 和 `6.0.0(20)`。构建脚本同时接受 DevEco SDK 集合根目录和具体 SDK 目录，并自动解析到本机 `C:\Program Files\Huawei\DevEco Studio\sdk\default`。
- App 包名：`com.open.rundesk`。
- UI：ArkTS / ArkUI Stage 模型。
- Native：C++ NAPI → Rust C ABI。
- Core：从 `liyan-lucky/librustdesk_core` Release 下载并链接双架构 `librustdesk_core.a`。
- 当前维护构建：`0.35.15` / `versionCode 1000314`，于 `2026-09-05` 使用 DevEco 调试签名完成构建验证。
- arm64 Core：`140149676` bytes，SHA256 `B0A80CF0C2B166336DB4B0CEDFA163A1E500CB6B72882FDF2E1CD701721882D3`；源码提交 `b8dab7e`。
- x86_64 Core：`130840066` bytes，SHA256 `2199D151CD6C2900BD1FB489561F6C7716314147DF2F87F542178134C4482476`。
- 本次验证设备：USB/HDC `2NX0224429035123`（arm64）；最近无线调试地址为 `192.168.0.108:36169`。
- 本次签名产物：`E:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`（约 `20398565` bytes）。
- 当前开发分支：`master`；项目规范要求后续修改、构建与安装均在 `master` 上进行，且构建安装必须调用仓库现有脚本。

## 当前能力边界

- 核心加载：staticlib + CMake 直接链接，NAPI 注册，`coreReady=true`。
- 远程连接：已接入 RustDesk session 路径，真实视频帧渲染，peer info 获取。
- 访问端控制：手机作为访问端控制远端 PC 的触摸、鼠标、滚轮、键盘等仍按 native active session 路径收口。
- 触摸交互系统：8 项手势可配置；默认时间轴为单击/双击 200ms、快速滑动 200ms 平移、短按拖动 400ms 滚动、600ms 左框、800ms 长按右键/右框；自然滚动按约 32vp 一行换算，平移回弹和双指手势保持不变。
- 虚拟鼠标控制：鼠标模式下提供虚拟光标（iconoir cursor-pointer.svg 箭头图标，可调大小16-64）、摇杆（touch ID 跟踪、速度可调、双模式）、L/R/M/P 菱形按钮、光标到边缘自动平移。
- 远程光标：跟随摇杆移动，支持缩放（0.5x-3.0x），默认 Windows 箭头样式（cursor-pointer.svg），热点偏移 (0.195, 0.261)。
- 悬浮工具栏：可收起/展开、拖拽吸边、位置持久化；工具菜单失焦或点击菜单外部时自动关闭菜单并折叠工具栏，点击子菜单功能后立即折叠。
- 鼠标控制菜单：内联 Row 模式选择、鼠标设置面板（灵敏度/滚动速度/摇杆速度/光标大小）。
- 显示菜单：缩放/编码选择弃用 Select 组件，改用自定义浮层弹出列表（Stack+zIndex(120)+居中），暗色主题正确显示。
- 连接日志系统：统一 Logger 工具类，关于页面详细日志开关。
- 调试入口：核心显示开关保持原逻辑；关于页使用"调试开关"统一控制 App、核心页面、网络、同步和会话诊断输出。
- 自建 API 登录：第三方登录项严格跟随当前 API；未指定 API 时使用官方默认项，自建 API 空配置不回退官方列表；OAuth 事务按 API 服务器隔离。
- 登录信息：第三方登录配置与用户列表按 API/账户持久缓存，页面停留期间每 60 秒刷新，支持搜索后的手动同步按钮。
- 用户列表诊断：区分网络不可达、授权失效、权限不足、服务端错误和响应格式异常，不再将所有失败误报为网络故障。
- 通讯录：兼容个人地址簿 GUID、分页设备、标签及颜色、标签增删改、按标签过滤、设备增删改与标签分配；仅在个人地址簿接口返回 404 时回退旧版整体替换协议。
- 设备状态：ID 设备沿用核心在线查询；IP 设备使用直连探测并持续轮询，`onPageShow` 中重启轮询，切换页面不丢失在线状态。
- 在线状态合并：核心查询的离线结果不得覆盖仍在有效 TTL 内的 LAN 在线结果；LAN 在线 TTL 保持三个发现周期，避免轮询时序和短暂发现延迟导致设备先在线后掉线。
- 共享页：访问模式、永久密码、一次性密码长度和纯数字选项已接入核心真实配置接口。
- ID 输入框：格式化光标位置修正（deviceIdExpectedCaret + onTextSelectionChange 检测），快速连续输入不再错位。
- 聊天工具栏：浅色/暗色主题配色均正确（清空按钮 theme_ERROR_BG+theme_ERROR_TEXT，图标 theme_TEXT_SECONDARY）。
- 远程键盘输入：大写字母正确发送（Core `session_input_key` 对 Shift+字母键直接发送 chr=key_code，绕过 KEY_MAP 小写映射；ArkTS `sendTextPayload` 小写字母转 VK 码 65-90、大写字母加 Shift modifier=4）；自定义键盘面板含 Backspace `⌫` 按钮；空格通过键盘事件 `sendKeyboardInput(32, true/false, 0)` 正确发送。
- 英文标点输入：IME 提交文本按字符分流；字母、数字和空格继续发送键盘事件，英文标点及其他字符使用 `sessionInputString`，避免 Windows OEM 虚拟键码在 Harmony 会话链路中丢失。
- IME 代理输入：sentinel 方案（零宽空格 `\u200B`）保证断开重连后 Backspace 可删除远端旧内容（`$$` 双向绑定 + `imeProxyPrev` 独立前值跟踪 + `TextInputController` 恢复 sentinel + `caretPosition(1)` 定位光标）；IME 自动补全符号删除问题部分修复（`isAutoCompletionDeletion` 检测），剩余场景已搁置。
- 共享设置菜单：共享页面 logo 右侧三点菜单按钮，弹出共享设置弹窗（访问方式、密码设置、密码类型）。
- 构建版本规则：增量构建尾号加 1，全量构建中间版本加 1 且尾号归零；同一修改失败重试使用 `none`。双 ABI 构建只允许第一个 ABI 更新版本。
- 被控端限制：华为手机作为被控端的远程操控/输入注入按平台不支持处理，当前搁置，不作为发布阻塞项。
- 文件传输、终端菜单跳转已修复（`resetConnectionUiAfterTerminalEvent` 不再清除 `pendingNavigatePage`）；五编码和全部访问端会话菜单仍需端到端回归。远程光标显示功能已基本完整实现（App UI + Core 回调 + Bridge 事件消费 + PixelMap 渲染），剩余仅为健壮性优化（事件队列容量、载荷编码、cursor clip）。
- 剪贴板同步：本地→远端由 `ClipboardService` 与 `sendClipboardData` 发送；远端→本地由 Core 解压、UTF-8 解码并输出 `clipboard-incoming`，App 仅将真实载荷写入系统剪贴板，诊断事件不会再被误写。正向菜单“允许剪贴板同步”与会话 `disable-clipboard` 配置一致。
- 最近会话、收藏和发现菜单均提供“加入通讯录”，未登录时保存到本地通讯录，登录时继续同步服务器；发现设备会保留已发现的别名和平台。
- 页面状态快照：最近会话和通讯录加载时保留已确认的在线状态、用户名和设备名，后台轮询负责校正，页面切换不再先清空再恢复。
- 线上构建当前为 HAP-only；Release 和 workflow artifact 只上传 `.hap`，不再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。

## 当前搁置问题

- 文件传输和五编码设备切换仍需更完整的跨设备端到端回归。
- 华为手机作为被控端的系统级输入注入受平台权限限制，继续按非发布阻塞项处理。

## 当前分支和备份

- `master`：当前主工作分支。
- `backup`：`master` 的快照备份分支。
- 所有后续修改直接在 `master` 进行；除 `backup` 外不保留长期功能或修复分支。
- `.github/workflows/force-backup-master.yml`：手动输入 `YES` 后，把 `master` 当前提交强制覆盖到 `backup`。

## 目录和文档职责

- `entry/`：HarmonyOS App 主模块、ArkTS UI、C++ NAPI、资源和 native libs。
- `scripts/`：本地构建、安装、审计和辅助脚本。
- `docs/`：接手、路径、构建、测试、发布、合规和当前状态文档。
- `docs/AGENT_HANDOFF.md`：跨对话接手第一入口。
- `docs/README.md`：文档阅读顺序。
- `docs/DIRECTORY_CONVENTIONS.md`：项目目录、路径、构建环境和清理规范。

## 合规边界

- 不提交 HarmonyOS SDK、DevEco、hvigor、ohpm、签名材料、私钥、token、用户数据或构建缓存。
- 线上构建只能通过授权来源提供工具链。
- 发布产物必须遵守 AGPL 源码提供义务和第三方依赖许可证。
- 不宣称官方授权、官方发布或官方背书。

当前功能、构建、Release、路径或验收状态变化时，必须同步更新本文件、根 README、`docs/README.md` 和相关专项文档。
