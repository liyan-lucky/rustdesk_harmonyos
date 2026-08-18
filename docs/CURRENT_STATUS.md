# 当前仓库状态

更新时间：2026-08-18

## 定位

`rustdesk_harmonyos` 是独立的 HarmonyOS / OpenHarmony RustDesk 兼容客户端仓库，采用 ArkTS Stage UI、C++ NAPI 桥接和 Rust 静态库核心。项目源码按 `AGPL-3.0-only` 分发。

本项目是第三方兼容客户端，不属于 RustDesk 官方发布、认可、赞助或背书项目。

## 当前工程信息

- `oh-package.json5`：`modelVersion` 为 `6.1.1`，包名为 `rustdesk_harmonyos`，版本字段为 `1.0.0`。
- App 包名：`com.open.rundesk`。
- UI：ArkTS / ArkUI Stage 模型。
- Native：C++ NAPI → Rust C ABI。
- Core：从 `liyan-lucky/librustdesk_core` Release 下载并链接双架构 `librustdesk_core.a`。
- 当前维护构建：`0.34.34` / `versionCode 1000279`，BuildInfo `2026-08-18 22:29`。
- arm64 Core：`133353216` bytes，SHA256 `AE629ED2045851469952DAF881D86E963C5344C787745AA5DDB69387EBBA41B5`。
- x86_64 Core：`130840066` bytes，SHA256 `2199D151CD6C2900BD1FB489561F6C7716314147DF2F87F542178134C4482476`。

## 当前能力边界

- 核心加载：staticlib + CMake 直接链接，NAPI 注册，`coreReady=true`。
- 远程连接：已接入 RustDesk session 路径，真实视频帧渲染，peer info 获取。
- 访问端控制：手机作为访问端控制远端 PC 的触摸、鼠标、滚轮、键盘等仍按 native active session 路径收口。
- 触摸交互系统：7 项手势可配置（单击/长按/滑动/短按拖动/长按拖动/双指开合/双指平移），自然滚动，平移回弹。
- 虚拟鼠标控制：鼠标模式下提供虚拟光标（iconoir cursor-pointer.svg 箭头图标，可调大小16-64）、摇杆（touch ID 跟踪、速度可调、双模式）、L/R/M/P 菱形按钮、光标到边缘自动平移。
- 远程光标：跟随摇杆移动，支持缩放（0.5x-3.0x），默认 Windows 箭头样式（cursor-pointer.svg），热点偏移 (0.195, 0.261)。
- 悬浮工具栏：可收起/展开、拖拽吸边、位置持久化。
- 鼠标控制菜单：内联 Row 模式选择、鼠标设置面板（灵敏度/滚动速度/摇杆速度/光标大小）。
- 显示菜单：缩放/编码选择弃用 Select 组件，改用自定义浮层弹出列表（Stack+zIndex(120)+居中），暗色主题正确显示。
- 连接日志系统：统一 Logger 工具类，关于页面详细日志开关。
- 调试入口：核心显示开关保持原逻辑；关于页使用“调试开关”统一控制 App、核心页面、网络、同步和会话诊断输出。
- 自建 API 登录：第三方登录项严格跟随当前 API；未指定 API 时使用官方默认项，自建 API 空配置不回退官方列表；OAuth 事务按 API 服务器隔离。
- 登录信息：第三方登录配置与用户列表按 API/账户持久缓存，页面停留期间每 60 秒刷新，支持搜索后的手动同步按钮。
- 用户列表诊断：区分网络不可达、授权失效、权限不足、服务端错误和响应格式异常，不再将所有失败误报为网络故障。
- 通讯录：兼容个人地址簿 GUID、分页设备、标签及颜色、标签增删改、按标签过滤、设备增删改与标签分配；仅在个人地址簿接口返回 404 时回退旧版整体替换协议。
- 设备状态：ID 设备沿用核心在线查询；IP 设备使用直连探测并持续轮询，切换页面不丢失状态。
- 共享页：访问模式、永久密码、一次性密码长度和纯数字选项已接入核心真实配置接口。
- ID 输入框：格式化光标位置修正（deviceIdExpectedCaret + onTextSelectionChange 检测），快速连续输入不再错位。
- 聊天工具栏：浅色/暗色主题配色均正确（清空按钮 theme_ERROR_BG+theme_ERROR_TEXT，图标 theme_TEXT_SECONDARY）。
- 远程键盘输入：大写字母正确发送（Core `session_input_key` 对 Shift+字母键直接发送 chr=key_code，绕过 KEY_MAP 小写映射；ArkTS `sendTextPayload` 小写字母转 VK 码 65-90、大写字母加 Shift modifier=4）；自定义键盘面板含 Backspace `⌫` 按钮。
- IME 代理输入：sentinel 方案保证断开重连后 Backspace 可删除远端旧内容（`$$` 双向绑定 + `imeProxyPrev` 独立前值跟踪 + `TextInputController` 恢复 sentinel + `caretPosition(1)` 定位光标）；IME 自动补全符号删除问题部分修复（`isAutoCompletionDeletion` 检测），剩余场景已搁置。
- 共享设置菜单：共享页面 logo 右侧三点菜单按钮，弹出共享设置弹窗（访问方式、密码设置、密码类型）。
- 构建版本规则：增量构建尾号加 1，全量构建中间版本加 1 且尾号归零；同一修改失败重试使用 `none`。双 ABI 构建只允许第一个 ABI 更新版本。
- 被控端限制：华为手机作为被控端的远程操控/输入注入按平台不支持处理，当前搁置，不作为发布阻塞项。
- 文件传输、五编码和全部访问端会话菜单仍需端到端回归。远程光标显示功能已基本完整实现（App UI + Core 回调 + Bridge 事件消费 + PixelMap 渲染），剩余仅为健壮性优化（事件队列容量、载荷编码、cursor clip）。
- 线上构建当前为 HAP-only；Release 和 workflow artifact 只上传 `.hap`，不再生成 APP、`.app.zip`、`manifest.json` 或 `SHA256SUMS.txt`。

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
