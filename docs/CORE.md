# 核心状态与 HAP 构建验证

## 2026-06-25 日常维护构建验证

增量构建 `0.33.16` / versionCode `1000192`，BuildInfo `2026-06-25 07:22`。CoreBuildInfo 已更新为线上 core-34：arm64 `133,495,306` bytes / SHA256 `90A28361F8A7801E66B0854334490F6B340BEA26C95E3BC4C666D6C665078337`，x86_64 `131,336,988` bytes / SHA256 `E587465E245DDA662A30110FC3FDEA139A2962295A4D73DCAAEEC9384FF18CE4`。Signed HAP `35,096,258` bytes / SHA256 `97B66222ADD52B95763CC50F37A7EE5DAF5D8E0ACFE49024A84D1A87E01FCD25`。验包通过（签名有效、双 ABI native entries 存在）。5轮全功能审计 770 PASS / 0 FAIL / 5 SKIP，连接链路审计 83 PASS / 0 FAIL / 1 SKIP。SignHap 仍需手动签名（hap-sign-tool.jar），Hvigor SignHap 密码不匹配。

## 2026-06-24 v0.33.14 审计修复验证

commit `c0131e9`（fix: 13 critical/high audit findings），版本 `0.33.14` / versionCode `1000190`，BuildInfo `2026-06-24 18:36`，仓库 HEAD `ac5555a`。CoreBuildInfo arm64 `132,777,178` bytes / SHA256 `EE881BEB9DE44835EE126BACC86D3B373E779334FB58A5D63F4B4D7974077314`，x86_64 `130,416,964` bytes / SHA256 `8ACD4AD130EAE9A36D4AE04A93860193CE8773E91E5CCEA5E34E815BFE633ED4`。设备验证 PID `19288`，`coreReady=true`，5轮审计 154 PASS / 0 FAIL / 1 SKIP。

13项修复：1) RemoteControl sessionExitTimer/reconnectWithPasswordTimer 泄漏修复；2) RemoteControl hasReceivedFrame 首帧逻辑修复；3) RemoteControl 物理键盘 sticky keys 使用 buildModifierMask()；4) Index onlineStatusPollMaxCount 0→3；5) Index oauthCheckTimer 泄漏修复；6) Index shouldPromptForPassword 中文乱码修复；7) Index statusMessage maxLen 8→32；8) Index Terminal 菜单改用 pendingNavigatePage；9) FileTransfer 删除无条件 fileAccessAuthorized=true；10) FileTransfer fileListRefreshTimer 泄漏修复；11) Terminal outputLines 3000行上限；12) OfficialRustDeskBridge 添加 stopEventPump()；13) WindowChromeService 注销 keyboardHeightChange。

## 2026-06-22 00:25 线上最终资产

Core `a7f7795` / run `27920089950` / `core-34`：arm64 `133495306 / 90A28361F8A7801E66B0854334490F6B340BEA26C95E3BC4C666D6C665078337`，x86_64 `131336988 / E587465E245DDA662A30110FC3FDEA139A2962295A4D73DCAAEEC9384FF18CE4`。App `3ebdc726` / run `27920708116` / `OpenRustdesk-Build-v0.33.6`：signed HAP `35067077 / 3D2711AF46FFF6C999362431FFDC7855A485BBBC5BBC1ACE629FA885F8A4E35C`。包内版本和双架构 CoreBuildInfo、签名、ABI、依赖、真机 updateTime/hilog 全部对齐；这是当前线上权威资产。本地 `1D5C...` 只作为同源码本地验证基线，不得替代线上发布哈希。

> 2026-06-23 UI 重构轮：FileTransfer.ets 全面重构（Column 流式布局、排序/三点/文件项菜单、多选+复制粘贴、长按选中、隐藏文件过滤、proicons ft_*.svg 图标），Terminal.ets 重写（header+terminalScreen+customKeyboard），Index.ets ID 卡片菜单修改（宽度收窄 210、文案调整、勾选右移、pendingNavigatePage 连接链路）。核心版本和构建产物未变化，仍为上述线上权威资产。

> 本文档记录 HAP 项目的核心状态、构建安装流程和运行验证清单。核心架构、桥接函数说明、编译问题等详见 `%VSCODE_ROOT%\13_librustdesk_core\docs\CORE.md`。

## 2026-06-21 23:48 最终本地候选

本地验证基线 HAP 为 SHA256 `1D5C7395753D4E8F143FA051E0E931CCFB6C48FFEDA03A8DF91282DD007EC8D2`（`34,284,688` bytes，BuildInfo `0.33.6 / 2026-06-21 23:46`）。CoreBuildInfo：arm64 `131091732 / E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D / 9cbd45a1`，x86_64 `130090572 / DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD / 38bf9990`，均为 2026-06-21 本地同源码基线。签名、双 ABI、两架构依赖、真机安装与冷启动均通过；最终 100 轮审计 15400 PASS / 0 FAIL / 100 预期 SKIP，连接链 84/84。当前线上权威包为本节上方 `3D2711...`，不能只看 `0.33.6`。

同一线上权威包也已在 `127.0.0.1:5555` x86_64 虚拟机补验：`0.33.6 / 1000182`、`updateTime=1782084584518`、PID `694`、NAPI 413 functions，初始化后 `coreReady=true`，应用进程无 fatal/panic/signal。

> 2026-06-21 路径规则：本地构建、验包、Core target、Hvigor stage/build/cache 和测试日志统一写入 `%VSCODE_ROOT%\99_Temp`。细则见 `docs/WORKSPACE_PATHS.md`，不要再把 `.codex_*`、Cargo target 或 HAP 输出长期留在 App 仓库根。

## 2026-06-21 17:12 真机共享与 HAP 历史快照（已被 23:48 基线替代）

- 当时本地构建/验包 HAP：size `34,233,149` bytes，SHA256 `A18FCCEE04A1903372124399035444B5BEBDF84FBB2B9F1918142C994C0797C9`，BuildInfo `2026-06-21 17:12`，签名和双 ABI 验包通过，当时尚未安装到真机。
- CoreBuildInfo：arm64 `131,091,732` bytes / SHA256 `E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D`；x86_64 `130,090,572` bytes / SHA256 `DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD`。
- 最后一次真机安装证据仍是 15:00 HAP：SHA256 `487EB88719B505013666D74841974A9CF4B031BF6EBFBF2BD6A352089822A35E`，`bm dump updateTime=1782050494366`，设备版本仍显示 `0.32.0 / 1000172`。版本号不能作为新旧判断依据。
- 被控共享链路已在真机验证到 Windows 端真实手机画面持续刷新；native `videoBufferReady/frameCount/coreFrameCount/corePushOk` 均有正向证据。
- 华为手机被控端输入/操控已按用户确认搁置：native input injection 返回 `result=201`，Huawei 设置页未列出 OpenRDesk；`module.json5` 已移除 accessibility extension 与 `ohos.permission.INPUT_MONITORING`，CMake 不再链接 `ohinput`，ArkTS accessibility service 已删除，仅由 `ohos_stubs.cpp` 保留固定返回 `201` 的 native 链接兼容符号。文件传输、全部会话菜单、五编码和远程光标仍需后续端到端验证。

## 2026-06-20 当前 Core 未完成项

- `HarmonySessionHandler` 的 cursor data/id/position/display 回调仍为空，“显示远程光标”尚未从官方 Session 回流到 App。
- 最新五编码源码目前只构建 x86_64；arm64 仍需重编后再构建最终 HAP。详细状态见 `docs/AGENT_HANDOFF.md`。
- `block-input` 的权威状态回流与 UI 读取尚未统一，取消阻止后的疑似断线必须结合完整事件链定位；FileManager/事件骨架也尚未形成可用文件传输闭环。

## 当前结论

- 当前采用 `staticlib + CMake 直接链接` 方案。
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`。
- `librustdesk_bridge.so` 直接链接 Rust staticlib：`entry/src/main/libs/arm64/librustdesk_core.a`。
- 不再使用 `dlopen` 加载 Rust 核心，避免 TEXTREL 和运行时加载问题。
- **核心构建已迁移到独立项目 `%VSCODE_ROOT%\13_librustdesk_core`**：
  - Rust 桥接层、C++ 桥接层、代码生成脚本均在 13 项目维护
  - 核心修改流程：13 项目修改 → git push → GitHub Actions（Windows runner）自动构建 → 下载 → 放入 11 项目
  - 也可本地构建：`13_librustdesk_core\scripts\build_native_bridge.ps1`
  - GitHub Releases：`https://github.com/liyan-lucky/librustdesk_core/releases`
- 当前页面应显示三个核心状态入口：`Adapter`、`Native Module`、`Native Core`
- 当前核心已经接入真实 RustDesk 会话路径
- 2026-06-14 13 项目源码已补齐终端 official Session 调用、终端响应事件、音频空队列 `[]` 和 C++ 聊天四参兼容；核心 commit `38c837cee0bb28aee795c0fc3895044f1440f96a` 已推送并由 GitHub Actions run `27483922931` 发布 `core-71`，11 项目已下载、全量构建、验包并安装验证。
- 2026-06-14 13 项目源码已继续补齐文件传输回调事件和 `switch-sides` option 路由，提交 `9c6ad4d`、`275b231e11aefd4a2e51050fc74fbdeba9c566bd` 已推送，GitHub Actions run `27485061967` 成功发布 `core-73`；11 项目已下载 core-73 并完成全量构建、验包和无线安装。设备当前锁屏导致 `aa start` 被系统拒绝，运行态 `coreReady` 待解锁后继续复测。
- 2026-06-14 13 项目旧 Harmony source mirror 的 `send_clipboard_data()` 已同步 active bridge，commit `1b987914a2c27ace376e5af45a9c6790d84d40b4` 已由 GitHub Actions run `27486100946` 发布 `core-74`；11 项目已下载 core-74 并完成全量 HAP 构建、验包、无线安装、解锁后启动和 hilog `coreReady=true` 验证。
- 2026-06-14 13 项目已发布自定义服务器 key 透传 `core-75` 和聊天事件语义修复 `core-76`：`start_service/session_start` 新增 key 参数，空服务器配置会清理旧 option；聊天失败为 `chat-error`、发送成功为 `chat-sent`、远端消息才是 `chat-message`。11 项目已下载 `core-76` 并完成全量构建、验包和无线安装。
- 2026-06-15 13 核心项目已回同步聊天 ABI 源文件修复和 d.ts 自建服务器 key 参数：`rustdesk_bridge_session_send_chat` 的 C++ 声明和调用改为四参，`connectToPeer/setIncomingServiceEnabled` 类型补齐 `key`，避免后续同步覆盖 11 App 已修路径；commits `034e446`、`cc5f4de` 已推送，GitHub Actions run `27515510727` 成功发布 `core-78`，release asset `131,470,442` bytes，SHA256 `F68E575D593BBE331E931E582870CB72EAA810BF56B817045162C44FCAF91ACD`。11 App 已下载并全量构建 `0.21.0`，无线安装启动和 hilog `coreReady` 验证通过。
- 2026-06-20 会话默认选项与编码切换修复：13 核心把 Harmony 显示/质量/编码及其他会话默认项持久化到 Config，新建 `Session` 后写入对应 PeerConfig；`codec-preference` 在当前会话变化时调用 `update_supported_decodings()`。本地 arm64 与 x86_64 均通过 `scripts/build_native_bridge.ps1` release 构建。
- 2026-06-15 远控 direct session 命令状态返回已在 13 核心 commit `bc36b1d` 推送并发布 `core-79`：Rust bridge、C ABI、C++ NAPI、核心/app d.ts 均改为 bool 返回，并补 `voice-call-*`、`record-status`、`screenshot-response` 事件；11 App 侧远控菜单已同步 direct function 调用，会话录制不再触发本机 `ScreenCaptureService`。11 App 已全量拉取 core-79 构建 `0.22.0` 并无线安装/hilog 验证通过。
- 2026-06-15 App 权限链路继续验证为 `0.22.1` / versionCode `1000104`：共享启动去掉 `CUSTOM_SCREEN_CAPTURE` 预申请，文件传输页改为主动唤起 `DocumentViewPicker` 目录授权；core-79 staticlib 未变化，增量构建、验包、连接链路审计、无线安装启动和严格 app hilog 均通过。
- 2026-06-15 App 屏幕采集底层继续验证为 `0.22.2` / versionCode `1000105`：`ScreenCaptureService` 不再创建 `AVScreenCaptureRecorder` 或临时 mp4 探测文件，改为 C++ NAPI 调用 `OH_AVScreenCapture_StartScreenCapture` 并轮询 native buffer 统计；core-79 staticlib 未变化，增量构建、验包、连接链路审计、无线安装启动和严格 app hilog 均通过。
- 2026-06-15 core-80 入站帧缓存已发布并在 11 App 验证：13 核心 commit `12ad723` / run `27526413545` 发布 `core-80`，新增 `updateIncomingScreenFrame/getIncomingScreenFrameMetadata/copyIncomingScreenFrame/clearIncomingScreenFrame`；11 App 强制拉取线上 core-80 构建 `0.22.4` / versionCode `1000107`，验包、66 项连接链路审计、无线安装启动和干净 hilog 验证通过。当前只接通 native buffer 到核心缓存，`incomingReady` 仍不能置 true。
- 2026-06-15 App 侧 CI strict 修正已验证为 `0.22.5` / versionCode `1000108`：线上 Linux/release workflow 在 `PermissionService.ets` 未显式对象字面量处失败，本地已改为显式 `PermissionRequestResult` 并修正聊天摘要中文错字；core 仍为 `core-80`，增量构建、验包、66 项连接链路审计、无线安装启动和干净 hilog 均通过。
- 2026-06-15 本地 core-81 预发布验证已通过：13 核心新增 OHOS `scrap::common::ohos::Capturer` incoming frame source，并让 `main_start_service(true)` 返回 `captureRequired=true`、`incomingReady=false`，由 App 启动 native `OH_AVScreenCapture_StartScreenCapture` 提供首帧；App `0.22.6` 已用本地 staticlib 构建、验包、66 项审计、无线安装和干净 hilog 验证通过。该记录为线上 core-81 发布前的历史过程，当前已由 `0.22.7` 线上 core-81 验证替代。
- 2026-06-15 线上 core-81 验证已通过：13 核心 commit `c5b3eeb` / run `27563925971` 发布 `core-81`，线上 asset `131,631,706` bytes，SHA256 `64463FA57005CD5CCD99BAFA9A40F18A9D605F8E90F5E199F92B38ABFCDB4829`；11 App 强制拉取线上 core-81 构建 `0.22.7` / versionCode `1000110`，验包、66 项审计、静态录屏 API 扫描、无线安装和干净 hilog 验证通过。
- 2026-06-17 OHOS 被控端完整连接链路已实现：13 核心项目两次 commit 已推送：
  - `7681b0d`：实现 OHOS 被控端完整连接链路（Service trait/ServiceTmpl/Subscriber、video_service、Connection::start、accept_connection/create_relay_connection、密码验证），`server_ohos.rs` 从146行stub扩展到1461行
  - `6b228d7`：修复重连稳定性（SEC30 30s→60s、SEND_TIMEOUT_VIDEO 12s→30s + 5次重试、session_reconnect 帧缓存清理）
  - `e8317b7`：修复 Connecting 状态拒绝重连（`ConnectionState::Connecting => self.send(Data::Close)`）
  - `f2833c3` + `123f823`：修复设备指纹不显示（`Config::get_id()` 替换 `get_local_option("id")`、`pk_to_fingerprint` 计算指纹、`gen_id`/`get_auto_id` cfg 加 `target_env = "ohos"`、`initialize_runtime` 设置 `APP_DIR` 后调用公开 API、`main_init` 调用 `initialize_runtime`）
  - CI 构建 core-25 已成功发布，arm64 `132,777,178` bytes，x86_64 `130,416,964` bytes
  - 本地核心额外修复：`set_peer_info` 不再重复触发 `session-connected` 事件（去掉 else 分支冗余 `update_connect_state`）
  - 11 App 已用本地核心构建 `0.23.9` / versionCode `1000132`，无线安装启动验证通过
- 2026-06-17 会话体验修复轮（v0.23.17 / versionCode 1000140）：
  - 删除旧 `showPasswordDialog`/`buildPasswordDialog()`，新增 `buildOsPasswordDialog()` + OS密码记住功能（PreferenceStore `peer_os_passwords`）
  - 修复多余闭合花括号导致100+级联编译错误
  - 清理死代码6处，修复硬编码日志
  - 质量菜单精简7项（尺寸/帧率/延迟/速度/连接/缩放/编码），标签36px，面板160px
  - I18n翻译补全9项，Resolution→尺寸，Codec→编码
  - 画面平移边界修复：对称范围 `[-(renderedSize-previewSize)/2, (renderedSize-previewSize)/2]`
  - 3处msgbox自动重连、peerClosed守卫、ClipboardService集成

## 架构总览

```text
ArkTS UI (11_Rustdesk_harmonyos)
    -> NAPI
librustdesk_bridge.so
    -> C++ bridge loader (entry/src/main/cpp/)
    -> Rust C ABI
librustdesk_core.a (从 13 项目 GitHub Releases 下载)
    -> rustdesk_harmony_bridge
    -> RustDesk official session/core (13_librustdesk_core/rustdesk-master/)
RustDesk Server / Peer
```

关键关系：

- Harmony app project: `%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- RustDesk native core project: `%VSCODE_ROOT%\13_librustdesk_core`
- Core staticlib in app: `%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`
- HAP staged project copy: `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`（可再生成；2026-06-21 16:26 清理后当前不存在，构建脚本需要时重建）
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/cpp/` | 从 13 项目同步到 App 项目的 C++ 桥接层 |
| `entry/src/main/cpp/CMakeLists.txt` | 将 `librustdesk_core.a`、`native_avscreen_capture`、`native_buffer` 链接进 `librustdesk_bridge.so` |
| `entry/src/main/libs/arm64/librustdesk_core.a` | 从 GitHub Releases 下载的 Rust staticlib |
| `entry/src/main/ets/common/CoreBuildInfo.ets` | 构建时生成的 native core 文件大小、mtime 和 hash 信息 |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | ArkTS 原生桥接封装，包含 native 屏幕采集 NAPI 包装 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 官方连接状态和事件封装 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程会话 UI、视频帧、输入、重试弹窗 |

## 上游源码版本

- 当前编译基于：**RustDesk 1.4.7**
- 升级状态：**已完成并验证**
- 源码位置：`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`

## 当前验证过的产物

Native core:

- 文件：`entry/src/main/libs/arm64/librustdesk_core.a`
- Source URL: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Latest online release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-34`
- Latest online size: `133,495,306` bytes (arm64, core-34)
- Latest online workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27920089950`
- Current local core: core-34 arm64 `133,495,306` bytes

x86_64 native core:

- 文件：`entry/src/main/libs/x86_64/librustdesk_core.a`
- Source URL: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core_x86_64.a`
- 状态：CI 双架构构建已完成，`core-34` release 含真实 x86_64 核心；latest x86_64 asset `131,336,988` bytes。
- 无 x86_64 真实核心时自动降级为 stub 模式（`rustdesk_core_stub.cpp`）

HAP:

- Bundle: `com.open.rundesk`
- ABI: `arm64-v8a` + `x86_64`
- Wireless target: `192.168.11.102:36169`
- Virtual device target: `127.0.0.1:5555` (x86_64 模拟器)
- Latest local pre-release validation: 2026-06-15 使用本地 core-81 staticlib 构建 `0.22.6` / versionCode `1000109`；signed HAP `18,433,473` bytes，SHA256 `4D669584F44B6462F570747723E66EB2894204FF7860CA0FBB27339D7FCE7DDD`；`verify_native_harmonyos_hap.ps1` 通过 native/signature 校验，`audit_connection_chain.ps1` 通过 `66 PASS, 0 FAIL, 0 SKIP`；无线目标 `192.168.11.102:36169` 安装和启动成功，设备上 `versionName=0.22.6`、`versionCode=1000109`，`pidof com.open.rundesk` 返回 `7527`。干净 app hilog `reports\hilog_latest_after_0226_localcore_wireless_app_strict_clean_x.txt` 中 app fatal/panic/`exit(-1)`/signal bad count 为 0。
- Latest validation: 2026-06-19 环境迁移后全量构建 `0.27.0` / versionCode `1000147`；signed HAP `18,915,605` bytes；`verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 通过 native/signature 校验，`audit_connection_chain.ps1` 通过 `63 PASS, 2 FAIL, 1 SKIP`（2 FAIL 为质量面板 UI 审计，不影响编译环境）。2026-06-19 路径复核后当前仓库标准签名配置为 `debug_hos.cer`/`debug_hos.p12`/`debug_hos.p7b`，别名 `debugKey`；DevEco Studio 绝对路径只通过 `switch_deveco_paths.ps1` 临时切换。
- Latest validation: 2026-06-20 全量构建 `0.31.0` / versionCode `1000171`；signed HAP `34,804,139` bytes；真机 `192.168.11.102:36169` 安装成功，进程 `58849`，`versionName=0.31.0`、`versionCode=1000171`，LAN 发现正常（1 peer）。core-33 线上最新核心。
- Latest online App validation: 2026-06-20 GitHub Actions run `27854059963`（commit `fb13e7a`）成功完成 `Build HarmonyOS package` 与 `Upload HarmonyOS artifacts`，artifact `harmonyos-hap` 大小 `65,698,344` bytes。
- Latest virtual device validation: 2026-06-22 增量构建 `0.33.6` / versionCode `1000182`；signed HAP `34,284,691` bytes / SHA256 `7760F8BBC1CC1B956D049A8DC4496DCAB35328CA60D999E73B30270BCABC9FB0`；验签/双 ABI/native 依赖检查通过；x86_64 虚拟机 `127.0.0.1:5555` 安装启动成功，PID `12853`，`coreReady=true`，在线查询正常，fatal/panic/signal 为 0。

## Native core 构建来源

当前核心构建的权威来源是独立项目 `%VSCODE_ROOT%\13_librustdesk_core`，11 项目只消费构建产物。

下载后放入：

```text
%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a
```

当前 11 项目构建脚本默认使用：

```text
RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a
RUSTDESK_CORE_SHA256=
```

默认不设置 `RUSTDESK_CORE_SHA256`，这样 13 项目自动发布新 tag 并更新 latest release 后，11 项目的本地和线上构建都会在构建前下载最新 `librustdesk_core.a`。如果需要固定某一次核心产物，再显式设置 `RUSTDESK_CORE_URL` 和 `RUSTDESK_CORE_SHA256`。

## 构建和安装 HAP

构建：

```cmd
cd %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_hap.bat
```

全量构建 HAP：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_full_hap.bat
```

一键构建、安装、启动：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\AUTO_BUILD_INSTALL.bat auto
```

手动安装、启动：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$target = "192.168.11.102:36169"
$hap = "F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap"
Get-FileHash -Algorithm SHA256 $hap
& $hdc -t $target install -r $hap
& $hdc -t $target shell aa start -a EntryAbility -b com.open.rundesk
```

多目标环境必须始终显式加 `-t <target>`。安装当前设备时不要加 `-g`。

## 运行验证清单

基础状态：

- App 可启动，`com.open.rundesk` 前台存活
- NAPI 注册成功（400 functions）
- `coreReady=true`
- 核心页显示 `Adapter`、`Native Module`、`Native Core` 三个状态入口
- 每个核心状态入口都有对应详情菜单

共享页：

- 共享服务默认停止
- 停止状态下不显示设备 ID 和密码
- 只有核心返回 `incomingReady=true` 后才显示设备 ID 和一次性密码；本机 native 屏幕采集处于 active 时不得展示为服务运行中。
- **当前限制**：线上 core-81 已让 OHOS `scrap::Capturer` 可消费核心 incoming frame cache，App 看到 `captureRequired=true` 会启动原生屏幕采集并推首帧；但 `incomingReady` 仍需等 RustDesk desktop server/video source 真实 ready 后才能置 true。
- 2026-06-12 起，录屏/被控视频源不可用时共享服务不得进入假运行状态：App 侧回滚 `serviceEnabled/allowRemoteControl`，native core `main_start_service(true)` 返回 `incomingReady=false` 和明确错误，避免其他设备连接后一直等待视频流。
- 2026-06-14 复查：共享页 UI 已把“录屏探测 active”和“核心 incoming ready”拆开，录屏探测只显示黄色 `Recording Probe` 状态并保留停止按钮，真实共享运行态只由 `settings.serviceEnabled && officialCoreState.incomingReady` 决定。

远程连接：

- 连接过程不应在成功前先弹重试对话框
- 只有非人为断开，且会话已经进入有效连接状态后，才显示官方重试对话框
- 访问端应收到 `session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`
- 远程触摸必须调用 `sendMouseInput()`，native core 应发出/处理 `mouse-input`
- 插入 `Ctrl+Alt+Del` 必须调用 `sendCtrlAltDel()`

## 历史记录

| 日期 | 状态 | 说明 |
| --- | --- | --- |
| 2026-05-02 | 成功 | 原始 Native 核心可工作 |
| 2026-05-29 | 成功 | staticlib + CMake 直接链接验证通过 |
| 2026-06-01 | 成功 | 实机安装启动通过，`coreReady=true` |
| 2026-06-02 | 成功 | 接入真实会话事件、视频刷新、帧读取、peer-info |
| 2026-06-07 | 成功 | 1.4.7 升级完成；修复密码框丢失、LAN发现失效 |
| 2026-06-08 | 成功 | 大规模函数补齐：54→369个桥接函数；官方一致性修复 |
| 2026-06-12 | 成功 | 核心项目迁移到 13_librustdesk_core；AvoidAreaType.TYPE_INPUT→TYPE_KEYBOARD 修复；WiFi 安装验证通过 |
| 2026-06-13 | 部分成功 | `core-70` 下载并构建 HAP 成功；HAP native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，视频流待解锁后复测 |
| 2026-06-14 | 成功 | `core-71` 下载并全量构建 HAP 成功；native/signature 校验、WiFi 安装启动和 hilog `coreReady=true` 验证通过；终端 bridge、音频空队列、聊天四参和 staging junction 排除已完成 |
| 2026-06-14 | 部分成功 | `core-73` 下载并全量构建 HAP 成功；native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，文件传输事件和 `switch-sides` 运行态待解锁后复测 |
| 2026-06-14 | 成功 | `core-74` 下载并全量构建 HAP 成功；native/signature 校验、WiFi 安装启动和 hilog `coreReady=true` 验证通过；旧 Harmony source mirror 剪贴板同步防回归已发布 |
| 2026-06-14 | 部分成功 | `core-76` 下载并全量构建 HAP 成功；native/signature 校验和 WiFi 安装通过；设备锁屏阻断启动，聊天语义和自建服务器 key 运行态待解锁后复测 |

## 2026-06-03 服务器与共享核心状态

- 服务器配置有效值统一由 `AppDataService.resolveServerConfig()` 解析
- `OfficialRustDeskBridge` 的刷新、连接、共享服务启动均使用解析后的有效服务器配置；自建服务器的 key 必须和 server/relay/api 一起传入 `start_service` 与 `session_start`
- Harmony bridge 在未接入真实屏幕采集/desktop server 时不能标记 incoming ready；`main_start_service(true)` 返回 `incomingReady=false`，防止被控端无视频源却让远端等待视频流。
- 系统截图 fallback 已确认会崩溃并被禁用；当前 App 侧使用 native `OH_AVScreenCapture_StartScreenCapture` 做屏幕采集启动和 native buffer 统计，后续仍需接入 live frame/desktop server。

## 2026-06-15 verified current core

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-34`
- Native core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27920089950`
- Native core commit: `a7f7795` (`Core-34 dual architecture release`)
- Native core size: `133,495,306` bytes (`127.40 MB`)
- Native core SHA256: `90A28361F8A7801E66B0854334490F6B340BEA26C95E3BC4C666D6C665078337`
- HAP build verified: version `0.22.7`, versionCode `1000110`, signed HAP `18,978,267` bytes, SHA256 `4A147E3D557BBE7CE6CDC527F588C217A137AAB2DF1CCD40287F704302A4C92B`
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.102:36169`; `bm dump` showed `versionName=0.22.7`, `versionCode=1000110`, native library path `entry/libs/arm64`
- Launch/runtime status: `aa start` succeeded, process `40016` stayed alive; `reports\hilog_latest_after_0227_core81_wireless_app_strict_clean_x.txt` recorded 7252 lines, 132 app/core-related lines, and app fatal/panic/`exit(-1)`/signal/native core missing bad count 0.

## 2026-06-14 verified core-76

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-76`
- Native core workflow: `https://github.com/liyan-lucky/librustdesk_core/actions/runs/27505721889`
- Native core commit: `1f474fc` (`Fix Harmony chat event semantics`)
- Native core size: `131,470,712` bytes (`125.38 MB`)
- Native core SHA256: `AA4E99EBBE794C979348E2B1C0CAFDDE7B846703398B2D1146E84DDF5640130F`
- HAP build verified: version `0.20.0`, versionCode `1000096`, signed HAP `18,909,325` bytes, SHA256 `3A6302DCFFCC93D62F79BA37B1E573E8929FDC56A697682A5A88E1BEA8DF4F9C`
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.102:36169`; `bm dump` showed `versionName=0.20.0`, `versionCode=1000096`, native library path `entry/libs/arm64`
- Launch/runtime status: blocked by device password lock, `aa start` returned `Error Code:10106102`; `power-shell wakeup`, `uitest uiInput swipe`, and `aa start -N` did not bypass lock. Runtime hilog remains pending until manual unlock.

## 2026-06-13 verified previous core

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`
- Native core release: `https://github.com/liyan-lucky/librustdesk_core/releases/tag/core-70`
- Native core size: `131,263,476` bytes (`125.18 MB`)
- Native core SHA256: `3C238E788636DEF1BD97B21194D7B8FB16327E19EDD83E4387560E9485C60153`
- HAP build verified: version `0.13.40`, signed HAP `18,746,430` bytes
- Package verify passed: `librustdesk_bridge.so`, `libc++_shared.so`, runtime dependency check, bundle `com.open.rundesk`, signature verify
- WiFi install verified: `192.168.11.102:36169` install bundle successfully; launch blocked by lock screen (`Error Code:10106102`), so runtime `coreReady` and `video-frame` are still pending

## 2026-06-20 current dual-architecture session build

- Online baseline `core-33` from commit `99edbb0` completed successfully in run `27867454936`; release contains both non-empty arm64 and x86_64 assets.
- Local follow-up adds session generation isolation and clears the upstream peer password before each non-saved request. `set_peer_info` no longer promotes the session; only `on_connected` does.
- The native build script now gives each target a target-triple plus millisecond log name, so parallel arm64/x86_64 builds cannot open the same timestamp-only log file.
- Local arm64 archive: `130,756,888` bytes, SHA256 `1C7B47D058525C21E5EF53F61CD68CD99C9CD1C07FEA04F00FCE815979EAC4D6`.
- Local x86_64 archive: `129,523,566` bytes, SHA256 `67C4E0E726E236073826D85FA704E42889AF8BAC665BC58C6A88ED7333797B04`.
- Signed dual-architecture HAP: `33,964,454` bytes, SHA256 `1373FA150AF4B049A3F5F6F56BBB2098F22B1B5613DB1C6D428090A1856D0AD0`; package signature, arm64/x86_64 native entries and runtime dependencies verified.
- x86 virtual device evidence: initial `coreReady=true`; no event feedback loop; both `remember=false` and `remember=true` password submissions complete on the original handshake; remembered-password reconnect after App restart succeeds.
