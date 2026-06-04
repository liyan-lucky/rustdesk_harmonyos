# 项目接手说明

> 新开对话先读本文，再按“阅读顺序”查看对应文档。本文只写当前状态和文档结构，不记录长篇历史。

## 当前项目状态

- 项目：RustDesk HarmonyOS 客户端。
- 工作区：`E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos`
- 当前 USB 测试设备：`2NX0224429035123`
- 当前无线测试设备：`192.168.11.100:36169`
- 包名：`com.open.rundesk`
- 当前 HAP 输出：`E:\Visual_Studio_Code\99_Temp\harmonyos_build\rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`
- 当前 native core 已接入真实 RustDesk session 路径，历史“仅模拟连接 / 真实网络未实现”不是当前状态。
- 上一轮实机验证曾确认访问端收到真实视频帧，并显示远程画面。
- 最新构建安装验证：
  - BuildInfo 编译时间：`2026-06-03 20:03`
  - USB 安装成功
  - `aa start -a EntryAbility -b com.open.rundesk` 启动成功

## 当前核心状态

- 核心加载方案：`staticlib + CMake 直接链接`
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`
- `librustdesk_bridge.so` 直接链接 `entry/src/main/libs/arm64/librustdesk_core.a`
- 当前 verified native core：
  - 大小：`135,673,254` bytes
  - SHA256：`B1224DDE1CD4ECA502D7585F3CCE2D89F41B55FF075914DE6757A2F184EB649B`
- 核心页应显示三个状态入口：
  - `Adapter`
  - `Native Module`
  - `Native Core`
- 每个入口都应有详情菜单。
- 详情菜单中的时间字段应显示“编译时间”。

## 当前重点问题

共享服务启动：

- **ScreenCaptureService 当前SDK下screen capture API不可用**（2026-06-03）。`@ohos.avScreenCapture` 无类型声明不可编译，`@ohos.screenshot.capture()` 会触发signal:6崩溃。真实屏幕采集需后续接入Harmony可用的官方录屏/采集链路。
- Toggle 回弹、ForEach key、startCapture throw 等问题已修复（2026-06-03）。

LAN 发现（2026-06-03）：

- LAN 发现保持 30 秒周期轮询，手动刷新时重置 UI 状态并立即触发一次发现。
- 忽略列表删除后立即刷新，不再重新出现。
- 发现 listener 不再触发非发现 tab 闪烁。

服务器配置（2026-06-03）：

- 服务器对话框改为官方样式：小标签+底部细线分隔的TextInput，新增Key字段。
- 右上角导出（arrow-autofit-up）和导入（arrow-autofit-down）按钮，兼容官方 JSON→Base64→反转 格式。

UI 交互修复（2026-06-03）：

- 连接页面未登录时ID输入框始终可用。
- 通讯录未登录时只在通讯录tab内显示登录按钮，其他tab正常。
- 会话菜单（显示/鼠标/更多/聊天）已在 build() 中条件渲染，底部弹出，点击可正常弹出。
- 自定义键盘半透明背景，位置在屏幕顶部。
- ID卡片复制到输入框不激活输入法。
- ID输入框删除数字时光标保持位置不跳到末尾。
- 菜单箭头图标统一为 arrow-forward-ios 样式。

设置合并（2026-06-03）：

- 删除死代码 RemoteSettingsPanel.ets 和重复的 Settings.ets 独立页面，只保留 Index.ets 设置tab。

刷新修复（2026-06-03）：

- 发现tab使用独立 discoveredVersion 计数器，不再因其他操作闪烁。
- 内层 ForEach key 移除全局 version 号，避免条目销毁重建。
- 登录成功后立即触发 UI 刷新和地址簿拉取。
- 刷新按钮多重递增精简。

聊天tab完善（2026-06-03）：

- 会话结束后聊天tab显示聊天记录或"No messages yet."，不再显示"No active connection"。
- 连接成功时加载聊天记录，不再清空历史记录。

连接稳定性：

- 需要继续确认连接过程中是否还会在成功前先弹重试对话框。
- 需要继续确认连接成功后访问端是否稳定持续显示远程画面，不再立即断开或停在等待视频流页面。
- 官方重试对话框只应在非人为断开且会话已有效建立后出现。
- 重试对话框按钮应为：取消、使用中继线路、重试。

名称和在线状态：

- ID 卡片第二行应显示官方格式：`用户名@设备名`。
- 所有来源都要确认：历史、发现、LAN、连接建立后的 peer info。
- LAN 只能作为发现来源，不能作为修复名称或全局在线状态的唯一依据。
- 离线状态刷新不应延迟 30 秒以上。

登录和共享：

- 需要继续确认 App 重启后登录态不丢失。
- 远程连接不应在 App 已登录时提示需要登录。
- 共享服务默认停止。
- 共享服务停止时不显示设备 ID 和密码；启动后才显示。
- 共享服务关闭状态必须持久化，App 重启后不能被核心 ready 流程自动打开。
- 生成密码后 UI 应立即刷新，并同步 native local options。
- 一次性密码必须写入官方临时密码 `temporary-password`，并设置 `verification-method=use-temporary-password`、`approve-mode=password`；不能只写 wrapper 内存 map。
- 未确认 official incoming ready 时不能显示为“运行中”，避免共享服务实际不可访问但 UI 显示正常。
- LAN 发现只在 App 打开时自动执行一次；之后需要用户手动刷新。手动刷新只清空 ArkTS/UI 发现状态并重新执行 `discoverLanPeers()` + `loadLanPeers()`，不能调用 native `removeDiscoveredPeer()` 清 LAN peers，否则会删除 RustDesk 原生发现结果。
- 通讯录必须登录后才能添加设备；未登录时通讯录区域显示登录入口，历史记录里的添加动作也必须先弹出登录。
- 文件访问授权必须同时申请 `READ_WRITE_DOWNLOAD_DIRECTORY` 和 `FILE_ACCESS_PERSIST`。

输入和会话 UI：

- 触摸、鼠标、滚轮、键盘必须通过 active native session 真实转发。
- 自定义键盘应显示在视频画面顶部，并覆盖在画面上方；面板背景保持透明，不再在面板内放额外键盘按钮或关闭按钮。
- 会话显示菜单、鼠标菜单、更多菜单、连接质量浮层都必须保证关闭入口可见；菜单内容超过屏幕时必须可滚动。
- 聊天、文件传输、重启远程、锁屏、阻止输入、插入 Ctrl+Alt+Del、截图、会话录制等入口不能只显示菜单，至少要有 native 调用或明确的本地排队/不可用提示；`Ctrl+Alt+Del` 当前必须走 `sendCtrlAltDel()` 到 official `Session::ctrl_alt_del()`，不能再用普通键盘事件模拟。

## 文档阅读顺序

1. `README.md`
   - 当前接手入口，说明项目状态、问题结构、文档用途。
2. `CORE.md`
   - 当前核心架构、可复现编译、HDC 安装启动、运行验证清单。
3. `PROGRESS.md`
   - 当前功能完成度、已完成事项、当前重点问题。
4. `CONNECTION_DEBUG_LOG.md`
   - 连接问题的逐轮排查记录，最新段落优先。
5. `ISSUES.md`
   - 问题库和易复发坑，修改前查这里。
6. `FILES.md`
   - 文件职责和外部依赖目录说明。
7. `DESIGN.md`
   - 架构、UI、构建、真机测试设计约束。
8. `UI.md`
   - UI 布局、图标、核心页面卡片细节。
9. `BUILD_ARCHIVE.md`
   - 历史构建、脚本、Ubuntu 路径、早期会话归档；不作为当前产物依据。
10. `GIT_PUBLISH.md`
   - GitHub 发布规则：本地保持 `rustdesk_harmonyos/` 子目录结构，远端 `master` 发布为项目根结构；包含临时发布目录操作方法和禁止项。

## 当前构建命令

构建 HAP：

```powershell
cd E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos
node scripts\run_hvigor_with_sdk_patch.js assembleHap
```

安装并启动：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hap = 'E:\Visual_Studio_Code\99_Temp\harmonyos_build\rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap'
& $hdc -t 2NX0224429035123 install -r $hap
& $hdc -t 2NX0224429035123 shell aa start -a EntryAbility -b com.open.rundesk
```

重编 native core：

```cmd
cmd /c E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat
```

## 接手规则

- 不要再按旧文档判断“真实网络未实现”；当前问题是稳定性、首帧、断线重试、名称刷新、登录态和在线状态。
- 每次修改代码、资源、脚本或文档，都必须同步更新相关项目文档，保持新开对话读取文档即可接手。
- 每轮修改后必须进行构建验证；ArkTS/UI 修改至少运行 HAP 构建，涉及 native core 时先重编 native core，再构建 HAP。
- 涉及设备行为、会话连接、共享服务、LAN 发现或输入转发时，构建后优先使用 USB 设备安装启动验证。
- 修改核心后必须重新构建 native core，再构建 HAP，再安装验证。
- 修改 ArkTS/UI 后至少重新构建 HAP 并安装验证。
- 多目标 HDC 环境必须显式加 `-t <target>`。
- 当前优先使用 USB 目标 `2NX0224429035123`。
- 历史无线目标 `192.168.11.100:36169` 仅备用。
- GitHub 仓库展示结构和本地工作结构不同：本地必须保持 `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos`，远端 `master` 通过 `99_Temp/rustdesk_harmonyos_publish_root` 发布为项目根结构。不要在本地普通 `git pull` 合并远端发布提交；发布前先读 `docs/GIT_PUBLISH.md`。

## 2026-06-03 当前补充

- 服务器配置默认值已改为“官方默认但不显示”：设置中空 ID/Relay/API 会在运行时回落到官方 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`，UI 只显示“官方默认”。
- 扫码页已改为相机扫码页，仅保留重扫和复制扫到的内容。
- 共享服务 native incoming 入口已从空 `{}` 返回修正为请求启动 official server；最新 HAP 已安装到 USB 设备，但设备锁屏导致启动复测暂时阻塞。
