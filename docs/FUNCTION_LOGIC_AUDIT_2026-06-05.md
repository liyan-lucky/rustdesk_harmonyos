# 功能逻辑与实现审查 2026-06-05

> 本文记录本轮对 `rustdesk_harmonyos` 的项目文档、便携路径、构建链、功能实现和逻辑风险的集中审查。当前工作区从固定电脑迁移到可移动盘，后续可能在不同电脑上使用，因此所有路径判断均以“可移动 `%VSCODE_ROOT%` 根目录”为前提。

## 审查范围

- 已读取并同步理解：`docs/README.md`、`docs/CORE.md`、`docs/PROGRESS.md`、`docs/FILES.md`、`docs/DESIGN.md`、`docs/UI.md`、`docs/ISSUES.md`、`docs/BUILD_ARCHIVE.md`、`docs/GIT_PUBLISH.md`、`docs/SESSION3_SUMMARY.md`、`docs/UBUNTU_CROSS_COMPILE_GUIDE.md`、`scripts/README.md`、`CHANGELOG.md`。
- 当前项目匹配：`%VSCODE_ROOT%\11_Rustdesk_harmonyos` 是本轮维护目标；`%VSCODE_ROOT%\99_Temp` 中的 RustDesk 源码、构建输出、缓存、签名材料是当前项目依赖；`01_` 到 `12_` 其他项目目录未发现与本 HAP 构建链存在直接依赖关系。
- 固定路径回扫：旧固定盘符、当前机器盘符、Linux 绝对挂载路径、用户目录 `.ohos` 签名路径在项目正文内回扫无命中。

## 本轮直接修复

- 将 HAP 签名材料迁移到 `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing`，`build-profile.json5` 改为相对路径引用，避免借用不同电脑时依赖原用户目录。
- `hvigor-config.json5` 保持相对便携占位，构建包装脚本在运行时写入当前机器绝对路径，结束后恢复相对配置。
- Windows 构建脚本增加 `RUSTDESK_HARMONY_TEMP_ROOT`、`BUILD_CACHE_DIR`、`CI=true` 和 DevEco/Node/HDC 自动发现逻辑。
- `clean_project.ps1` 支持长路径和外部构建目录清理，无法删除 USB 残留生成目录时改为警告并继续。
- `AccountService.fetchAddressBook()` 修复空通讯录响应不覆盖旧缓存的问题，避免切换账号或服务端后显示过期设备。
- `HttpClient` 请求体、响应体和 URL 查询参数日志增加脱敏，避免 `password`、`access_token`、`token`、`uuid`、`code` 进入构建或运行日志。

## 构建检查

| 检查轮次 | 命令 | 结果 | BuildInfo |
|---:|---|---|---|
| 10 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 00:55` |
| 20 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 00:58` |
| 30 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:00` |
| 40 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:02` |
| 50 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:03` |
| 60 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:06` |
| 70 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:07` |
| 80 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:08` |
| 90 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:09` |
| 100 | `cmd /c scripts\build_full_hap.bat` | 通过 | `2026-06-05 01:10` |

最终签名 HAP：

- 路径：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`
- 大小：`45304142` 字节
- 最后写入：`2026-06-05 01:10:34`

稳定复现的构建警告：

- `NativeRustDeskBridge.ts` 的 NAPI 模块验证提醒。
- `CoreLoaderService.getUserDownloadDir` 能力集覆盖提醒和若干可能抛异常提醒。
- `encode`、`getDefaultDisplay`、`read`、`write`、`vp2px` 等 SDK 废弃 API 提醒。
- `Index.ets` 中 `key` 仅测试目录使用提醒。
- `Scan.ets` 的 HMS `customScan` 相关能力并非所有设备支持。

## 100 项功能逻辑审查

| # | 检查项 | 实现判断 | 逻辑漏洞或优化空间 |
|---:|---|---|---|
| 1 | 文档入口 | 已实现 | `README.md` 已作为当前入口，但后续修改必须同步更新时间。 |
| 2 | 项目匹配 | 已实现 | 当前目标明确为 `11_Rustdesk_harmonyos`。 |
| 3 | 兄弟目录识别 | 已实现 | 其他编号目录未纳入构建链，避免误改。 |
| 4 | 便携根目录模型 | 已实现 | 使用 `%VSCODE_ROOT%` 表示可移动工作区根。 |
| 5 | Git dubious ownership | 已记录 | 借用电脑时需使用 `safe.directory` 临时查看状态。 |
| 6 | 签名材料便携化 | 已实现 | 签名材料已迁移到 `99_Temp`。 |
| 7 | 签名 profile 校验 | 已实现 | bundleName 为 `com.open.rundesk`，profile 有效期到 2027-06-03。 |
| 8 | 构建输出外置 | 已实现 | HAP、Hvigor build、Native `.cxx` 输出进入 `99_Temp`。 |
| 9 | USB 残留生成目录 | 已绕过 | 项目内旧 `.hvigor`、`entry\build`、`entry\.cxx` 删除失败不影响当前构建。 |
| 10 | 旧固定路径回扫 | 已实现 | 项目正文无旧固定盘符和用户 `.ohos` 路径。 |
| 11 | `build_hap.bat` | 已实现 | 支持当前根目录、`99_Temp` 和 DevEco Node 自动发现。 |
| 12 | `build_full_hap.bat` | 已实现 | 只清理外部构建目录，避免误删可复用缓存。 |
| 13 | `AUTO_BUILD_INSTALL.bat` | 已实现 | Node 和 HDC 支持从 `local.properties` 或环境变量发现。 |
| 14 | `local.properties` 借机适配 | 已记录 | 不同电脑 DevEco 路径变化时只需更新本地配置或环境变量。 |
| 15 | DevEco 环境变量覆盖 | 已实现 | 支持 `DEVECO_SDK_HOME`、`DEVECO_TOOLS_HOME`、`DEVECO_NODE_EXE`、`HDC_EXE`。 |
| 16 | Hvigor 配置恢复 | 已实现 | 构建结束后恢复为相对路径，避免把当前电脑路径写死。 |
| 17 | CI 模式 Native 输出重定向 | 已实现 | `CI=true` 触发 Native `.cxx` 外置输出。 |
| 18 | 清理脚本缓存语义 | 已实现 | `-IncludeHvigorCache` 明确作为深度清理开关。 |
| 19 | 备份和发布目录 | 已记录 | 备份、发布目录统一归入 `99_Temp` 体系。 |
| 20 | 文档路径统一 | 已实现 | 文档改用 `%VSCODE_ROOT%` 和 `$VSCODE_ROOT_LINUX`。 |
| 21 | NAPI 导出面 | 已实现 | C++ bridge 导出连接、视频、输入、文件、终端、音频等入口。 |
| 22 | Rust staticlib + CMake 链路 | 已实现 | HAP 构建连续验证可用。 |
| 23 | Native runtime 初始化 | 已实现 | `NativeRustDeskBridge` 封装加载、初始化和状态恢复。 |
| 24 | NAPI fallback/requireNapi | 已实现 | 启动失败时有日志和降级路径。 |
| 25 | Core snapshot 归一化 | 部分实现 | native snapshot 为空对象，UI 主要依赖本地状态和事件。 |
| 26 | 事件轮询 | 已实现 | ArkTS 侧定期 pull native events。 |
| 27 | 事件队列容量 | 风险 | native 事件队列有上限，极端高频事件可能丢失。 |
| 28 | 视频帧复制 | 已实现 | 支持 metadata 和 RGBA 拷贝 fallback。 |
| 29 | ABI 声明一致性 | 部分实现 | 构建通过，但 SDK 提醒未来 NAPI 声明验证会更严格。 |
| 30 | Bridge 日志摘要 | 已实现 | 关键 native 调用有摘要日志。 |
| 31 | 远控连接 | 已实现 | `connect_to_peer` 接入 official RustDesk session。 |
| 32 | 密码提交 | 已实现 | password challenge 可走 native 提交。 |
| 33 | 重连 | 已实现 | reconnect/session retry 路径存在。 |
| 34 | 会话关闭事件 | 部分实现 | core 存在 `closed` 与 UI 期待 `session-closed` 的事件命名差异风险。 |
| 35 | 连接错误展示 | 已实现 | session error 能传回 UI。 |
| 36 | Peer 信息更新 | 已实现 | 设备名、平台、状态可更新到 UI。 |
| 37 | 连接质量类型 | 部分实现 | 有连接类型和质量展示，但部分质量测量仍是模拟或估算。 |
| 38 | 远控 stale watchdog | 已实现 | UI 有失联/停帧检测。 |
| 39 | 官方服务器配置 | 已实现 | 支持 official server fallback 和自定义服务端。 |
| 40 | 自定义 key/relay 选项 | 已实现 | 通过 local option 写入。 |
| 41 | 视频刷新请求 | 已实现 | UI 周期请求 native 刷新 session 视频。 |
| 42 | 8ms 帧轮询 | 优化空间 | 高频轮询可能耗电，应根据帧率或可见状态自适应。 |
| 43 | 视频 fallback 逻辑 | 已实现 | 无新帧时能保持上一帧和状态。 |
| 44 | 色彩格式处理 | 部分实现 | ABGR/ARGB/BGRA 有兼容逻辑，真实设备仍需画面验证。 |
| 45 | 多显示器元数据 | 部分实现 | core handler 的 display 回调为空，UI 多屏信息可能不完整。 |
| 46 | 远端光标 | 部分实现 | cursor 回调为空，光标样式/位置可能不能真实同步。 |
| 47 | 鼠标输入 | 已实现 | native 路径已接入 official session input。 |
| 48 | 键盘输入 | 部分实现 | 基础按键可用，复杂组合键和 IME 仍需真机验证。 |
| 49 | Ctrl+Alt+Del | 已实现 | native 有专门入口。 |
| 50 | 文本输入/粘贴 | 部分实现 | 部分路径依赖键盘输入或本地 pasteboard，不等同完整远端剪贴板。 |
| 51 | 密码登录 | 已实现 | ArkTS `HttpClient` 登录路径可用。 |
| 52 | OIDC 登录 | 已实现 | ArkTS 路径实现 login-options、auth、query。 |
| 53 | native 账号登录 | 未实现 | core 中 `account_auth` 和 auth result 仍为空，当前 UI 未依赖此路径。 |
| 54 | token 恢复 | 已实现 | access token 从 local option 恢复。 |
| 55 | logout 清理 | 已实现 | 登出会清 token、用户、通讯录。 |
| 56 | 空通讯录覆盖 | 已修复 | 空响应现在会覆盖旧缓存并发事件。 |
| 57 | 通讯录映射 | 已实现 | peers/groups/tags 能映射到本地模型。 |
| 58 | 用户信息持久化 | 优化空间 | `refreshUser` 后续可明确持久化最新 user info。 |
| 59 | 敏感 body/response 日志 | 已修复 | password/token/uuid 已脱敏。 |
| 60 | 敏感 URL 查询日志 | 已修复 | code/uuid/token/access_token 已脱敏。 |
| 61 | 在线状态查询 | 已实现 | native `query_online_status` 可用。 |
| 62 | 在线状态轮询 | 优化空间 | 当前 5 秒无限轮询，后台或无可见设备时应降频。 |
| 63 | `refreshSessionOnlineStatus` | 部分实现 | 存在 placeholder 或未充分使用路径。 |
| 64 | LAN 发现 | 已实现 | native discover/load/remove 路径存在。 |
| 65 | LAN 忽略设备 | 已实现 | ignored peers 可持久化。 |
| 66 | LAN 空列表处理 | 风险 | native 临时空结果会清当前列表，弱网下可能闪烁。 |
| 67 | 最近会话 | 已实现 | 本地持久化可用。 |
| 68 | 收藏设备 | 已实现 | favorites 本地保存。 |
| 69 | 设备显示名 | 已实现 | 支持 username@hostname 等组合展示。 |
| 70 | 搜索和 Tab 过滤 | 已实现 | UI 有搜索、最近、收藏、LAN、通讯录分组。 |
| 71 | 聊天本地记录 | 已实现 | ChatService 可保存消息。 |
| 72 | 聊天 native 发送结果 | 风险 | UI 保存/显示发生在发送确认前，失败反馈不足。 |
| 73 | 聊天回显 | 风险 | core 会推送同内容 chat event，可能造成发送端回显重复。 |
| 74 | 文件传输界面 | 已实现 | 页面、队列、进度 UI 齐全。 |
| 75 | 本地文件列表 | 部分实现 | 当前仍有虚拟目录/默认路径，缺少完整文件选择器和真实遍历。 |
| 76 | 远端目录读取 | 风险 | core 推 generic `file-transfer`，UI 期待 `folder-files`。 |
| 77 | 传输进度事件 | 未实现 | core job progress/done/error 回调为空。 |
| 78 | 远端创建/删除 | 风险 | native 事件名与 UI 监听项不完全一致。 |
| 79 | 并发传输限制 | 已实现 | UI service 有并发上限和队列管理。 |
| 80 | 文件路径策略 | 优化空间 | `/storage/Users/currentUser/Download` 需要替换为系统 picker 或沙箱 API。 |
| 81 | 终端界面 | 已实现 | UI、历史、输入区域已具备。 |
| 82 | native 终端打开/输入 | 未实现 | core terminal functions 直接返回 false。 |
| 83 | 终端响应事件 | 未实现 | `handle_terminal_response` 为空。 |
| 84 | 终端历史持久化 | 部分实现 | UI 有历史概念，完整持久化和失败恢复不足。 |
| 85 | 本地剪贴板 | 已实现 | 读写本机 pasteboard 路径存在。 |
| 86 | 远端剪贴板发送 | 未实现 | core `send_clipboard_data` 返回 false。 |
| 87 | 剪贴板权限体验 | 优化空间 | 读取 pasteboard 可能频繁触发权限或提示。 |
| 88 | 本地音频采集 | 部分实现 | Harmony audio capturer 可读取麦克风。 |
| 89 | 音频发送 native | 未实现 | core `send_audio_frame_metadata` 返回 false。 |
| 90 | 远端音频播放 | 部分实现 | UI 有拉取/播放路径，端到端链路仍需 native 确认。 |
| 91 | 屏幕采集 | 未实现 | 当前 SDK 可用 API 不满足完整远控采集需求。 |
| 92 | 被控服务启动 | 部分实现 | UI 可请求 incoming，但没有完整屏幕采集供给。 |
| 93 | 桌面 server thread | 未实现 | 为避免 appspawn 退出，native 桌面服务线程仍禁用。 |
| 94 | 权限模型 | 部分实现 | 必要权限分层清晰，但部分可选权限需要真机策略验证。 |
| 95 | 打开应用设置 | 未实现 | `openAppSettings()` 仍是 placeholder。 |
| 96 | 扫码能力 | 部分实现 | `customScan` 构建警告显示并非所有设备支持，需要 fallback。 |
| 97 | 窗口与安全区域 | 已实现 | UI 有窗口 chrome、avoid area、状态栏处理。 |
| 98 | 多语言和编码 | 部分实现 | 源码多语言较全，PowerShell 查看中文会出现终端编码错显。 |
| 99 | 性能热点 | 优化空间 | 8ms 视频轮询、无限在线轮询、高频日志需按前台状态优化。 |
| 100 | 发布就绪度 | 部分就绪 | 出站远控最成熟；入站被控、文件、终端、音频、远端剪贴板仍需核心回调补齐。 |

## 优先级建议

| 优先级 | 建议 | 理由 |
|---|---|---|
| P0 | 保持 `11_Rustdesk_harmonyos` 与 `99_Temp` 同级移动，借用电脑只改 `local.properties` 或环境变量 | 这是当前便携构建能稳定复现的关键前提。 |
| P0 | 补齐 native 文件传输事件名和 job 回调 | 当前 UI 和 core 事件协议不一致，文件功能看起来完整但端到端风险最高。 |
| P0 | 明确终端、远端剪贴板、音频发送为未实现状态或隐藏入口 | 避免用户以为功能已可用。 |
| P1 | 为扫码页增加手动输入/粘贴 fallback | `customScan` 能力并非所有设备支持。 |
| P1 | 降低远控视频轮询和在线轮询频率 | 对移动设备耗电和发热影响明显。 |
| P1 | 将 token/password 迁移到加密存储 | 借用电脑和可移动盘场景下，凭据保护更重要。 |
| P2 | 清理 SDK deprecated API 和 NAPI `.d.ts` 验证提醒 | 现在不阻塞构建，但后续 SDK 可能收紧。 |
