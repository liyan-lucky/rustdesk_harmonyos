# 核心状态与 HAP 构建验证

> 本文档记录 HAP 项目的核心状态、构建安装流程和运行验证清单。核心架构、桥接函数说明、编译问题等详见 `%VSCODE_ROOT%\13_librustdesk_core\docs\CORE.md`。

## 当前结论

- 当前采用 `staticlib + CMake 直接链接` 方案。
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`。
- `librustdesk_bridge.so` 直接链接 Rust staticlib：`entry/src/main/libs/arm64/librustdesk_core.a`。
- 不再使用 `dlopen` 加载 Rust 核心，避免 TEXTREL 和运行时加载问题。
- **核心构建已迁移到独立项目 `%VSCODE_ROOT%\13_librustdesk_core`**：
  - Rust 桥接层、C++ 桥接层、代码生成脚本均在 13 项目维护
  - 核心修改流程：13 项目修改 → git push → GitHub Actions 构建 → 下载 → 放入 11 项目
  - GitHub Releases：`https://github.com/liyan-lucky/librustdesk_core/releases`
- 当前页面应显示三个核心状态入口：`Adapter`、`Native Module`、`Native Core`
- 当前核心已经接入真实 RustDesk 会话路径

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
- HAP staged project copy: `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/cpp/` | 从 13 项目同步到 App 项目的 C++ 桥接层 |
| `entry/src/main/cpp/CMakeLists.txt` | 将 `librustdesk_core.a` 链接进 `librustdesk_bridge.so` |
| `entry/src/main/libs/arm64/librustdesk_core.a` | 从 GitHub Releases 下载的 Rust staticlib |
| `entry/src/main/ets/common/CoreBuildInfo.ets` | 构建时生成的 native core 文件大小、mtime 和 hash 信息 |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | ArkTS 原生桥接封装 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 官方连接状态和事件封装 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程会话 UI、视频帧、输入、重试弹窗 |

## 上游源码版本

- 当前编译基于：**RustDesk 1.4.7**
- 升级状态：**已完成并验证**
- 源码位置：`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`

## 当前验证过的产物

Native core:

- 文件：`entry/src/main/libs/arm64/librustdesk_core.a`
- Source URL: `https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a`
- Size: `138,394,514` bytes (`131.98 MB`)
- SHA256: `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`

HAP:

- Bundle: `com.open.rundesk`
- ABI: `arm64-v8a`
- Wireless target: `192.168.11.100:36169`
- Latest validation: 2026-06-12 WiFi 安装启动成功，hilog 确认 `coreReady=true`、`adapter=official-native`、`module registered (400 functions)`

## Native core 构建来源

当前核心构建的权威来源是独立项目 `%VSCODE_ROOT%\13_librustdesk_core`，11 项目只消费构建产物。

下载后放入：

```text
%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a
```

当前 11 项目 CI 使用：

```text
RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a
RUSTDESK_CORE_SHA256=A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8
```

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
$target = "192.168.11.100:36169"
Push-Location "L:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default"
& $hdc -t $target install -r entry-default-signed.hap
Pop-Location
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
- 启动服务后显示设备 ID 和一次性密码
- **当前未解决**：Screen Capture API 在当前 SDK 下不可用

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

## 2026-06-03 服务器与共享核心状态

- 服务器配置有效值统一由 `AppDataService.resolveServerConfig()` 解析
- `OfficialRustDeskBridge` 的刷新、连接、共享服务启动均使用解析后的有效服务器配置
- Harmony bridge 采用安全 incoming requested 路径：写入官方 server option、设置 `stop-service=N`、更新 incoming 状态并刷新 rendezvous
- 屏幕采集仍是未完成项：系统截图 fallback 已确认会崩溃并被禁用

## 2026-06-12 verified current core

- Upstream compatibility: `RustDesk 1.4.7`
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a`
- Native core size: `138,394,514` bytes (`131.98 MB`)
- Native core SHA256: `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`
- WiFi install verified: `coreReady=true`, `adapter=official-native`, `module registered (400 functions)`
