# 核心架构与可复现编译

> 本文档记录 HarmonyOS 版 RustDesk 的核心结构、当前可用核心状态、重新编译路径和验证清单。目标是：即使清理了旧备份和生成产物，也能按本文重新编译出当前可用核心。

## 当前结论

- 当前采用 `staticlib + CMake 直接链接` 方案。
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`。
- `librustdesk_bridge.so` 直接链接 Rust staticlib：`entry/src/main/libs/arm64/librustdesk_core.a`。
- 不再使用 `dlopen` 加载 Rust 核心，避免 TEXTREL 和运行时加载问题。
- **核心构建已迁移到独立项目 `%VSCODE_ROOT%\13_librustdesk_core`**：
  - Rust 桥接层、C++ 桥接层、代码生成脚本均在 13 项目维护
  - 核心修改流程：13 项目修改 → git push → GitHub Actions 构建 → 下载 → 放入 11 项目
  - GitHub Releases：`https://github.com/liyan-lucky/librustdesk_core/releases`
- 当前页面应显示三个核心状态入口：
  - `Adapter`
  - `Native Module`
  - `Native Core`
- 当前核心已经接入真实 RustDesk 会话路径，不能再按旧文档理解为“真实网络未实现”。

## 架构总览

```text
ArkTS UI
    -> NAPI
librustdesk_bridge.so
    -> C++ bridge loader
    -> Rust C ABI
librustdesk_core.a
    -> rustdesk_harmony_bridge
    -> RustDesk official session/core
RustDesk Server / Peer
```

关键关系：

`%VSCODE_ROOT%` 是可移动工作区根目录，不是固定盘符。当前脚本默认从项目目录向上一级匹配同级 `99_Temp`，所以 `11_Rustdesk_harmonyos/` 和 `99_Temp/` 必须保持在同一个工作区根下。

- Harmony app project: `%VSCODE_ROOT%\11_Rustdesk_harmonyos`
- RustDesk native core project: `%VSCODE_ROOT%\13_librustdesk_core`
- RustDesk upstream source: `%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`
- Historical native build workspace: `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build`
- Core staticlib in app: `%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`
- HAP staged project copy: `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `%VSCODE_ROOT%\13_librustdesk_core\native_rust_core/Cargo.toml` | Rust bridge crate 配置，输出 `staticlib` |
| `%VSCODE_ROOT%\13_librustdesk_core\native_rust_core/src/bridge_api.rs` | Rust C ABI 导出入口 |
| `%VSCODE_ROOT%\13_librustdesk_core\cpp/rustdesk_bridge_abi.h` | C++ 侧 Rust ABI 声明源文件 |
| `%VSCODE_ROOT%\13_librustdesk_core\cpp/rustdesk_bridge_loader.cpp` | NAPI bridge loader 源文件 |
| `entry/src/main/cpp/` | 从 13 项目同步到 App 项目的 C++ 桥接层 |
| `entry/src/main/cpp/CMakeLists.txt` | 将 `librustdesk_core.a` 链接进 `librustdesk_bridge.so` |
| `entry/src/main/libs/arm64/librustdesk_core.a` | 当前 HAP 链接用 Rust staticlib |
| `entry/src/main/ets/common/CoreBuildInfo.ets` | 构建时生成的 native core 文件大小、mtime 和 hash 信息 |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | ArkTS 原生桥接封装 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 官方连接状态和事件封装 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程会话 UI、视频帧、输入、重试弹窗 |

## 当前核心必须保留的能力

重建环境时，`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master` 中的 Harmony bridge 相关改动必须保留，尤其是：

- `src/harmony_bridge/core.rs`
  - `connect_to_peer()` 走官方 RustDesk session 路径，并保存 active `Session<HarmonyHandler>`。
  - `refresh_session_video(display)` 调用：
    - `session.request_init_msgs(display)`
    - `session.refresh_video(display)`
  - `harmony_next_rgba(display)` 从 `session.ui_handler.next_rgba(display)` 取帧。
  - `send_mouse_input(mask, x, y)` 转发到 active session，不能退回旧的 stub `false`。
  - `send_ctrl_alt_del()` 调用 active session 的 official `ctrl_alt_del()`，不能用普通键盘按键模拟替代。
  - `get_peer_info(peer_id)` 从 `PeerConfig.info` 返回 hostname、username、platform、alias。
  - `HarmonyHandler.close_success()` 只能表示官方 UI 的连接成功提示关闭；首帧时也会触发，必须保持 `connected` 并上报 `connection-ready`，不能映射成 `session-closed`。
- OHOS platform stubs 必须避免依赖桌面 Linux/Windows API。
- ArkTS 输入必须按官方 RustDesk mouse mask 编码：
  - 低 3 bit 是 event type。
  - button bits 左移 3 位。
  - wheel 使用官方 wheel type 和滚动 delta。

## 上游源码版本

- 当前编译基于：**RustDesk 1.4.7**（GitHub 2026-06-02 发布）
- 升级状态：**已完成并验证**。13 项目已完成 Cargo.toml/lib.rs/build.rs/scrap 的 OHOS 条件排除和桥接适配，`v1.4.7-ohos` release 已发布。
- 兼容说明：核心页详细信息应显示兼容的官方版本号，避免远端版本不匹配时找不到支撑信息
- 源码位置：`%VSCODE_ROOT%\13_librustdesk_core\rustdesk-master`
- 备份位置：`%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_backups\harmony_bridge_backup_20260606\`

## 当前验证过的产物

Native core:

- 文件：`entry/src/main/libs/arm64/librustdesk_core.a`
- Source URL: `https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a`
- Size: `138,394,514` bytes (`131.98 MB`)
- Build time observed: `2026-06-12 02:31`
- FNV-1a 1MB: `11786fd9`
- SHA256: `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`

HAP:

- Local BuildInfo compile time: `2026-06-12 02:57`
- Local app version: `0.13.30`
- Local versionCode: `1000061`
- Bundle: `com.open.rundesk`
- ABI: `arm64-v8a`
- Latest online release: `https://github.com/liyan-lucky/rustdesk_harmonyos/releases/tag/harmonyos-20260612-020111`
- Release assets: signed/unsigned HAP, signed/unsigned `.app.zip`, `manifest.json`, `SHA256SUMS.txt`
- USB target used for validation: configured by `RUSTDESK_HARMONY_USB_TARGET`; hardware IDs are not recorded in docs.
- Wireless target used for validation: `192.168.11.100:36169`
- Latest online validation: 2026-06-12 Linux GitHub Actions HAP/APP build and release succeeded.
- 2026-06-09 wireless validation: HAP install and launch succeeded. hilog confirmed `coreReady=true`, `adapter=official-native`, Bridge 在线查询正常，远控连接建立。
- **1.4.7 升级已完成**: 上游源码已升级到 1.4.7，native core 在线构建发布成功，HAP/APP 在线构建发布通过。
- **2026-06-07 修复**: (1) 无密码连接时密码输入框丢失——`RemoteControl.ets` applyBridgeState error/idle 分支优先检查 `shouldPromptForPassword`；(2) 无密码连接被访问端刚提示就结束会话——`handleTerminalBridgeEvent` 将密码检查扩展到 `session-closed`；(3) LAN 发现失效——`rendezvous_mediator_ohos.rs` start_all() 中启动 `crate::lan::start_listening()` 监听线程。

## Native core 构建来源

当前核心构建的权威来源是独立项目 `%VSCODE_ROOT%\13_librustdesk_core`，11 项目只消费构建产物。

本地重编：

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..).Path
Set-Location "$env:VSCODE_ROOT\13_librustdesk_core"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1
```

推荐发布流程：

1. 在 `%VSCODE_ROOT%\13_librustdesk_core` 修改 Rust/C++/生成脚本。
2. 提交并推送 13 项目，触发 GitHub Actions 构建 `librustdesk_core.a`。
3. 发布或更新 `v1.4.7-ohos` release asset。
4. 11 项目的 GitHub Actions 通过 `RUSTDESK_CORE_URL` 下载该 `.a`，并用 `RUSTDESK_CORE_SHA256` 校验。

当前 11 项目使用：

```text
RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a
RUSTDESK_CORE_SHA256=A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8
```

下载后放入：

```text
%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a
```

检查：

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..).Path
Get-Item "$env:VSCODE_ROOT\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a"
Get-FileHash "$env:VSCODE_ROOT\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a" -Algorithm SHA256
```

## 构建和安装 HAP

构建：

```cmd
cd %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_hap.bat
```

`build_hap.bat` 是增量构建入口，会先复制干净 staging 副本，自动更新 App 内构建时间，并将版本号右侧数字自增 1；底层仍调用 `node scripts\run_hvigor_with_sdk_patch.js assembleHap`，构建成功后把 `AppScope/app.json5` 和 `BuildInfo.ets` 同步回真实项目根。

全量构建 HAP（会清理生成产物、`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos` 和对应 staging 副本，自动更新 App 内构建时间，并将版本号中间数字自增 1、右侧数字归零）：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\build_full_hap.bat
```

`build_full_hap.bat` 默认保留 `%VSCODE_ROOT%\99_Temp\harmonyos_cache`，避免 Hvigor 内置 clean 触碰 U 盘上历史残留的项目内 `.hvigor/`、`entry/build/`、`entry/.cxx/` 坏目录。需要深度清理 Hvigor cache 时，手动运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\clean_project.ps1 -IncludeExternalBuild -IncludeHvigorCache`，随后再运行 `scripts\build_hap.bat`。

线上 Linux 构建：

```text
GitHub Actions -> Build HarmonyOS Package Linux
version_bump: incremental/full/none
skip_package_verify: true
publish_release: true
```

当前 workflow 固定构建 `both`，会生成 HAP 和 APP。发布时 HAP 直接上传，APP 先压缩为 `.app.zip` 再上传，因为 GitHub Release 对直接 `.app` 资产处理不稳定。默认下载的线上依赖为：

```text
HARMONYOS_SDK_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-sdk-full/harmonyos-sdk-full.zip
HARMONYOS_HVIGOR_URL=https://github.com/liyan-lucky/rustdesk_harmonyos/releases/download/harmonyos-hvigor-full/harmonyos-hvigor-full.zip
RUSTDESK_CORE_URL=https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a
```

SDK 包必须包含 `openharmony/previewer/common/bin/libcjson.so`、`openharmony/previewer/common/bin/libsec_shared.so` 和 `openharmony/ets/build-tools/ets-loader/bin/ark/build/bin/libsec_shared.so`；workflow 会显式检查这些文件并把对应目录加入 `LD_LIBRARY_PATH`。

一键构建、安装、启动：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\AUTO_BUILD_INSTALL.bat %RUSTDESK_HARMONY_USB_TARGET%
```

全量构建后自动安装：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\AUTO_BUILD_INSTALL.bat --full auto
```

自动选择 USB/无线目标：

```cmd
cd /d %VSCODE_ROOT%\11_Rustdesk_harmonyos
scripts\AUTO_BUILD_INSTALL.bat auto
```

`AUTO_BUILD_INSTALL.bat` 会优先使用 `RUSTDESK_HARMONY_USB_TARGET` 指定的 USB 目标；USB 不在线时，会尝试 `hdc tconn 192.168.11.100:36169` 并使用无线目标。可通过 `RUSTDESK_HARMONY_USB_TARGET` 和 `RUSTDESK_HARMONY_WIRELESS_TARGET` 覆盖默认值。

如果安装成功但启动返回 `Error Code:10106102`，表示设备锁屏且 HDC 无法自动解锁；脚本会将其视为“安装成功、启动需手动解锁后复测”的 warning。

手动安装、启动：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$env:VSCODE_ROOT = (Resolve-Path ..\..).Path
$target = $env:RUSTDESK_HARMONY_USB_TARGET
$hap = "$env:VSCODE_ROOT\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap"
& $hdc -t $target install -r $hap
& $hdc -t $target shell aa start -a EntryAbility -b com.open.rundesk
```

### HDC 设备验证

当前默认 USB 目标：

- 目标设备：由 `RUSTDESK_HARMONY_USB_TARGET` 指定
- 包名：`com.open.rundesk`
- Ability：`EntryAbility`
- 签名HAP：`%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

USB 验证流程：

```powershell
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$env:VSCODE_ROOT = (Resolve-Path ..\..).Path
$target = $env:RUSTDESK_HARMONY_USB_TARGET
$hap = "$env:VSCODE_ROOT\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap"
& $hdc list targets
& $hdc -t $target install -r $hap
& $hdc -t $target shell aa start -a EntryAbility -b com.open.rundesk
```

2026-06-02 14:40 验证结果：

```text
[Info]App install path:...entry-default-signed.hap msg:install bundle successfully.
AppMod finish
start ability successfully.
```

历史无线目标 `192.168.11.100:36169` 仅作为备用。命令行 `hdc list targets` 返回空并不一定表示设备不可用，可能只是无线目标尚未 attach 到本地 HDC server。无线验证前先执行：

```powershell
hdc start
hdc tconn 192.168.11.100:36169
hdc -t 192.168.11.100:36169 list targets
```

多目标环境必须始终显式加 `-t <target>`。安装当前设备时不要加 `-g`。

## 运行验证清单

基础状态：

- App 可启动，`com.open.rundesk` 前台存活。
- NAPI 注册成功。
- `coreReady=true`。
- 核心页显示 `Adapter`、`Native Module`、`Native Core` 三个状态入口。
- 每个核心状态入口都有对应详情菜单。
- 详情菜单中的时间字段显示“编译时间”。

共享页：

- 共享服务默认停止。
- App 启动时只按持久化 `serviceEnabled` 恢复服务；用户关闭后重启仍保持停止，不再由 `coreReady && !incomingReady` 自动开启。
- 停止状态下不显示设备 ID 和密码。
- 启动服务后显示设备 ID 和一次性密码。
- 生成密码后 UI 立即刷新。
- 一次性密码同步 native local options：
  - `temporary-password`
  - `verification-method=use-temporary-password`
  - `approve-mode=password`
- wrapper 不能在 official incoming service 返回 `{}` 时把服务状态伪装成运行中；未确认真实 incoming ready 时应显示不可用/未确认，避免其他设备访问失败时误判为 UI 问题。
- 文件传输/共享权限需要申请 `READ_WRITE_DOWNLOAD_DIRECTORY` 和 `FILE_ACCESS_PERSIST`。

权限管理（2026-06-03 修复）：

- 权限开关 onChange 必须先同步 `updateSettings` 更新状态，再执行异步权限请求，防止 Toggle 重渲染回弹。
- 权限拒绝时回滚状态为 false。
- `toggleIncomingService` 中 `startCapture` 失败后 throw，调用方 catch 回滚 `serviceEnabled: false`。
- ForEach key 不包含 `accountRefreshTick`，避免登录状态刷新时销毁 Tab 内容。
- 调试日志用 `hilog` API（domain `0xA03D00`，tag `SHARE`），不用 `console.info`。
- **当前未解决**：Screen Capture 开关授权后 `avScreenCapture.createAVScreenCapture()` 仍失败，共享服务无法启动。需要通过 hilog 确认具体失败原因。

发现和设备名：

- ID 卡片第二行应显示官方格式：`用户名@设备名`。
- `get_peer_info(peer_id)` 应能返回 `username` 和 `hostname`。
- LAN 发现只能作为发现来源，不能作为修复名称或在线状态的唯一依据。
- LAN 发现只在 App 打开时自动运行一次；后续由用户手动刷新触发完整 `discoverLanPeers()` + `loadLanPeers()`。手动刷新会清空 ArkTS/UI 发现状态，但不能清 native LAN peer 缓存，否则会删除原生发现结果。
- 通讯录添加必须依赖登录态；未登录时显示登录入口，不能静默添加到本地通讯录。
- 在线查询频率应足够高，离线状态不应延迟 30 秒以上才刷新。

远程连接：

- 连接过程不应在成功前先弹重试对话框。
- 只有非人为断开，且会话已经进入有效连接状态后，才显示官方重试对话框。
- 重试对话框按钮为：
  - 取消
  - 使用中继线路
  - 重试
- 访问端应收到：
  - `session-connected`
  - `peer-info`
  - `video-refresh-requested`
  - `video-frame`
- 被访问端显示已连接时，访问端不能停留在等待视频流页面。
- 远程触摸必须调用 `sendMouseInput()`，native core 应发出/处理 `mouse-input`。
- 插入 `Ctrl+Alt+Del` 必须调用 `sendCtrlAltDel()`，native core 应发出/处理 `keyboard-input command=ctrl-alt-del`。

会话 UI：

- 自定义键盘应显示在画面顶部，并覆盖在视频画面上方。
- 自定义键盘不应贴在屏幕底部。

## CMake 链接要点

```cmake
add_library(rustdesk_bridge SHARED rustdesk_bridge_loader.cpp)
set(RUST_CORE_A ${CMAKE_CURRENT_SOURCE_DIR}/../libs/arm64/librustdesk_core.a)

if(EXISTS ${RUST_CORE_A})
  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
    ${time-lib}
    ${RUST_CORE_A}
    m
  )
  target_link_options(rustdesk_bridge PRIVATE "-Wl,--unresolved-symbols=ignore-all")
endif()
```

依赖检查：

```bash
objdump -p librustdesk_bridge.so | grep NEEDED
```

预期包含：

- `hilog_ndk.z`
- `ace_napi.z`
- `time_service_ndk`
- `c++_shared`
- `c`

不应单独依赖：

- `libopus`
- `librustdesk_core`

## 编译问题和固定处理

已经处理过的问题：

- `dlopen` 路径因 TEXTREL/RWX 限制不可用，改为 staticlib 直接链接。
- Rust/lld 误置 `DT_TEXTREL/DF_TEXTREL`，不能从 Rust 侧可靠修复。
- OHOS musl 不提供 GNU `qsort_r`，C++ loader 中使用替代实现。
- `libtime_service_ndk.so` 通过 CMake fallback 路径搜索。
- `machine-uid build.rs` 需要按 `TARGET` 判断，而不是按 host OS 判断。
- `rustix 0.37` 与 nightly 不兼容，当前使用 stable toolchain。
- libsodium 必须为 OHOS target 单独交叉编译。
- bindgen 必须传入 OHOS sysroot，否则会出现结构体字段异常。
- `RUSTFLAGS` 必须指定 OHOS lld，避免错误调用 PATH 中的 `ld.exe`。

关键环境变量：

| 变量 | 作用 |
| --- | --- |
| `LIBCLANG_PATH` | bindgen 加载 libclang |
| `BINDGEN_EXTRA_CLANG_ARGS` | 给 libclang 传 OHOS target/sysroot |
| `RUSTFLAGS` | 强制使用 OHOS lld |
| `SODIUM_LIB_DIR` | 指向 OHOS libsodium |
| `VCPKG_ROOT` | vcpkg 根目录 |
| `VCPKG_INSTALLED_ROOT` | vcpkg installed 目录 |

## 历史路径说明

旧版 Ubuntu/Windows 交叉编译路径曾验证通过，但当前核心构建已迁移到 `%VSCODE_ROOT%\13_librustdesk_core`。`99_Temp\rustdesk_harmonyos_build` 只保留历史工具链和旧排查资料，不再作为 11 项目的权威核心源码。

历史 Ubuntu 入口：

```bash
export RUSTDESK_HARMONY_BUILD_DIR="$VSCODE_ROOT_LINUX/99_Temp/rustdesk_harmonyos_build"
export OHOS_NDK_HOME="$RUSTDESK_HARMONY_BUILD_DIR/ohos-sdk"
cd $VSCODE_ROOT_LINUX/11_Rustdesk_harmonyos/scripts
./build_native_bridge.sh aarch64-unknown-linux-ohos release
```

如需使用历史 Ubuntu 路径，必须确认其源码、patch、SDK mirror、libsodium、vcpkg 与 13 项目当前环境一致。脚本目录当前只保留 arm64 有效链路，Linux 下不要再使用旧的 HAP repack/sign/install shell 链。

## 历史记录

| 日期 | 状态 | 说明 |
| --- | --- | --- |
| 2026-05-02 | 成功 | 原始 Native 核心可工作 |
| 2026-05-21 | 失败 | 重新编译 Rust 时引入 libopus 等依赖问题 |
| 2026-05-24 | 成功 | 恢复旧版核心，功能正常 |
| 2026-05-28 | 成功 | 验证 SO 体积优化和 dlopen 限制 |
| 2026-05-29 | 成功 | staticlib + CMake 直接链接验证通过 |
| 2026-05-31 | 成功 | 新增 `get_peer_info`，修复设备名称读取路径 |
| 2026-06-01 | 成功 | Windows 交叉编译成功，接口层对齐 |
| 2026-06-01 | 成功 | 实机安装启动通过，`coreReady=true` |
| 2026-06-02 | 成功 | 接入真实会话事件、视频刷新、帧读取、peer-info |
| 2026-06-02 | 成功 | 修复共享页默认停止、密码刷新、在线刷新、触摸转发 |
| 2026-06-02 | 成功 | 收紧重试弹窗触发条件，自定义键盘改为顶部覆盖 |
| 2026-06-06 | 成功 | 修复 bridge_api.rs 缺失 send_ctrl_alt_del/reconnect_session 导出，NAPI 注册 52 函数，coreReady=true |
| 2026-06-07 | 成功 | 1.4.7 升级完成，native core 重编（137,422,248 bytes）；修复无密码连接密码框丢失、会话过早关闭、LAN 发现失效（start_all 未启动 lan::start_listening） |
| 2026-06-08 | 成功 | 大规模函数补齐：54→369个桥接函数；重命名main_use_texture_render→main_get_use_texture_render；添加main_init+34个session_*函数；修复生成脚本bug；全面重写CORE.md函数说明 |
| 2026-06-08 | 成功 | 官方一致性修复：abi.h删除28个旧式声明；main_init移入extern "C"块；loader.cpp旧名NAPI调用新名C函数；session_alternative_codecs→session_get_alternative_codecs；添加drain_connect_events声明；HAP构建通过 |
| 2026-06-12 | 成功 | 13 项目发布 RustDesk 1.4.7 OHOS core（138,394,514 bytes，SHA256 A200A839...AADC8）；11 项目 Linux Actions 下载该 core 并成功构建 HAP/APP |
| 2026-06-12 | 成功 | Linux CI SDK 拆包补齐 `openharmony/previewer/common/bin/libcjson.so` 和 `libsec_shared.so`；ArkTS `AvoidAreaType.TYPE_INPUT` 改为 `TYPE_KEYBOARD`；GitHub Release 将 `.app` 压缩为 `.app.zip` 上传 |

## 2026-06-03 服务器与共享核心状态

- 服务器配置有效值统一由 `AppDataService.resolveServerConfig()` 解析：存储值为空时，ID/Relay/API 分别使用官方默认 `rs-ny.rustdesk.com`、`rs-ny.rustdesk.com`、`https://admin.rustdesk.com`。
- `OfficialRustDeskBridge` 的刷新、连接、共享服务启动、bootstrap 均使用解析后的有效服务器配置，避免 UI 空值传入 native。
- `AccountService` 在登录、通讯录、用户刷新等 API 请求前同步当前有效 API Server。
- native `set_incoming_service_enabled()` 已从 stub 改为请求 official incoming server 启动；USB 设备已安装最新版，实际共享启动仍需设备解锁后用 hilog 复测。

### 2026-06-03 10:53 USB 复测更新

- `start_server(true, false)` 不适合直接在 Harmony app 进程中启动；实机日志显示它会触发 appspawn `exit(-1)` / `signal:6`。
- Harmony bridge 当前采用安全 incoming requested 路径：写入官方 server option、设置 `stop-service=N`、更新 incoming 状态并刷新 rendezvous，不再启动桌面端 server 线程。
- `get_core_snapshot_json()` 已返回 `incomingReady`、`displayId`、server 和状态摘要，避免 ArkTS 刷新时丢失共享状态。
- 前端共享开关的多次轮询已收敛为单次延迟刷新；最新 USB 日志中 `incoming-service-requested` 只出现 1 次，App 进程保持稳定。
- 屏幕采集仍是未完成项：系统截图 fallback 已确认会崩溃并被禁用，真实被控画面需要后续补 Harmony 可用的官方录屏/采集链路。

## 2026-06-12 verified current core

- Upstream compatibility: `RustDesk 1.4.7`.
- Native core archive: `entry/src/main/libs/arm64/librustdesk_core.a`.
- Native core source: `https://github.com/liyan-lucky/librustdesk_core/releases/download/v1.4.7-ohos/librustdesk_core.a`.
- Native core size: `138,394,514` bytes (`131.98 MB`).
- Native core compile time: `2026-06-12 02:31`.
- Native core SHA256: `A200A839F2B361C512A94CE5E2A7081F442438FF62239C90CFFAD90FA98AADC8`.
- Local app build info after verification: version `0.13.30`, build time `2026-06-12 02:57`.
- Latest online release: `harmonyos-20260612-020111`.
- Core detail page must show the native core compile time and `Compatible Official Version: RustDesk 1.4.7`; it must not use the app build time for native core metadata.
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`.
- Signed APP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\build\outputs\default\11_Rustdesk_harmonyos-default-signed.app`.

## 桥接函数完整说明（369个 bridge 函数）

> 当前 core.rs 有 363 个 pub fn，bridge_api.rs 导出 369 个 `rustdesk_bridge_*` C ABI 函数，NAPI 注册约 400 个（含 5 个工具函数 loadCoreLibrary/isCoreLoaded/getCoreLoadInfo/verifyCoreFile/getCoreFileInfo）。以下按功能分类详细说明每个函数的作用和用法。

### 1. 核心生命周期（3个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `initialize_runtime` | appDir, customClientConfig | JSON | 初始化运行时，设置APP_DIR/自定义客户端配置，启动异步任务运行器，返回BridgeSnapshot JSON |
| `get_core_snapshot` / `get_core_snapshot_json` | server / 无 | JSON | 获取核心快照（adapter/coreReady/incomingReady/displayId/fingerprint等），_json版本返回完整JSON |
| `bootstrap_core_snapshot` | displayId, fingerprint, directAddress, server | JSON | 引导核心快照，填充显示ID/指纹/直连地址，返回更新后的快照 |

### 2. 连接管理（8个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `connect_to_peer` | peerId, password, server, relayServer, apiServer | void | 发起到对端的连接，创建Session<HarmonyHandler>并启动io_loop |
| `close_session` | 无 | void | 关闭当前会话（session.close()） |
| `session_close` | 无 | void | 官方名：关闭当前会话 |
| `reconnect_session` | forceRelay | bool | 重连会话，forceRelay=true走中继线路 |
| `session_reconnect` | forceRelay | bool | 官方名：重连会话 |
| `mark_session_connected` | peerId | void | 标记会话已连接（触发session-connected/peer-info事件，调用mark_peer_connected_with_cached_info） |
| `mark_session_error` | message | void | 标记会话错误（触发session-error事件） |
| `session_start` | 无 | void | 官方名：标记会话开始（session.mark_peer_connected()） |

### 3. 连接状态查询（6个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `get_session_stage` | 无 | string | 获取当前会话阶段（idle/connecting/connected/error/login） |
| `get_active_peer_id` | 无 | string | 获取当前活跃的对端ID |
| `get_connect_status_summary` | 无 | string | 获取连接状态摘要（如"Connected"/"Connecting"） |
| `get_connect_detail_message` | 无 | string | 获取连接详情消息 |
| `get_connect_last_error` | 无 | string | 获取最近一次连接错误 |
| `drain_connect_events` / `drain_connect_events_json` | 无 | JSON array | 排空并返回所有排队的连接事件（JSON数组），_json版本返回完整JSON |

### 4. 事件/帧轮询（6个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `pull_session_events` / `pull_session_events_json` | 无 | JSON | 拉取会话事件（session-connected/session-error/session-closed/msgbox等），_json版本返回完整JSON |
| `pull_audio_frames` / `pull_audio_frames_json` | 无 | JSON | 拉取音频帧数据，_json版本返回完整JSON |
| `get_latest_video_frame_metadata` / `get_latest_video_frame_metadata_json` | sinceFrameId / 无 | JSON | 获取最新视频帧元数据（frameId/width/height/stride/format/timestamp），_json版本返回完整JSON |

### 5. 视频帧操作（3个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `copy_latest_video_frame` | frameId, buffer, bufferLen | int | 复制指定帧的RGBA数据到buffer，返回拷贝字节数 |
| `harmony_next_rgba` | display | void | 推进native侧RGBA帧缓冲到下一帧（从session.ui_handler.next_rgba取帧） |
| `refresh_session_video` | display | bool | OHOS特有：请求远端刷新视频（request_init_msgs + refresh_video），返回是否成功 |
| `session_refresh` | display | bool | 官方名：刷新会话视频 |

### 6. 密码/认证（6个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `submit_session_password` | password, remember | bool | 提交会话密码进行认证 |
| `session_login` | password, remember | bool | 官方名：会话登录认证 |
| `session_send2fa` | code | bool | 发送2FA验证码 |
| `session_input_os_password` | password | bool | 输入远端OS密码（UAC提权等场景） |
| `session_elevate_direct` | 无 | bool | 直接提权（无需密码） |
| `session_elevate_with_logon` | username, password | bool | 使用Windows凭据提权 |

### 7. 输入控制（9个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `send_mouse_input` | mask, x, y | bool | OHOS特有：发送鼠标/触摸输入（mask低3位=事件类型，按键位左移3位） |
| `session_send_mouse` | mask, x, y | bool | 官方名：发送鼠标输入 |
| `session_send_pointer` | msg | void | 发送指针事件（JSON格式消息） |
| `send_keyboard_input` | keyCode, isPressed, modifiers | bool | 发送键盘输入 |
| `session_input_key` | keyCode, isDown, modifiers | void | 官方名：输入按键 |
| `session_handle_flutter_key_event` | key, isDown, modifiers | void | 处理Flutter格式键盘事件 |
| `session_handle_flutter_raw_key_event` | keyCode, isDown, modifiers | void | 处理Flutter原始键盘事件 |
| `send_ctrl_alt_del` | 无 | bool | OHOS特有：发送Ctrl+Alt+Del命令 |
| `session_ctrl_alt_del` | 无 | bool | 官方名：发送Ctrl+Alt+Del |
| `session_input_string` | value | void | 输入字符串（用于IME输入法） |
| `session_send_touch_pan_event` | ... | void | 发送触摸平移事件 |
| `session_send_touch_scale` | ... | void | 发送触摸缩放事件 |

### 8. 剪贴板（2个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `send_clipboard_data` | content, timestamp | bool | 发送剪贴板数据（构建Clipboard protobuf消息发送到远端） |
| `host_stop_system_key_propagate` | 无 | void | 停止系统按键传播 |

### 9. 会话选项（15个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `apply_session_option` | key, value | bool | OHOS特有高层封装：应用会话选项（image-quality/custom-image-quality/custom-fps/keyboard-mode/video-codec-preference/session-action/toggle-option/block-input等），被ETS广泛使用 |
| `session_set_option` | key, value | void | 官方名：设置会话选项 |
| `session_get_option` | key | string | 获取会话选项值 |
| `session_get_toggle_option` | key | bool | 获取会话开关选项 |
| `session_get_toggle_option_sync` | arg | bool | 同步获取会话开关选项 |
| `session_toggle_option` | key | void | 切换会话开关选项 |
| `session_set_image_quality` | value | void | 设置图像质量 |
| `session_get_image_quality` | 无 | string | 获取图像质量 |
| `session_set_custom_image_quality` | value | void | 设置自定义图像质量 |
| `session_get_custom_image_quality` | 无 | int | 获取自定义图像质量 |
| `session_set_custom_fps` | value | void | 设置自定义FPS |
| `session_set_keyboard_mode` | mode | void | 设置键盘模式 |
| `session_get_keyboard_mode` | 无 | string | 获取键盘模式 |
| `session_is_keyboard_mode_supported` | mode | bool | 检查键盘模式是否支持 |
| `session_set_view_style` | style | void | 设置视图样式 |
| `session_get_view_style` | 无 | string | 获取视图样式 |
| `session_set_scroll_style` | style | void | 设置滚动样式 |
| `session_get_scroll_style` | 无 | string | 获取滚动样式 |
| `session_set_reverse_mouse_wheel` | value | void | 设置反向鼠标滚轮 |
| `session_get_reverse_mouse_wheel_sync` | 无 | bool | 同步获取反向鼠标滚轮设置 |
| `session_set_trackpad_speed` | value | void | 设置触控板速度 |
| `session_get_trackpad_speed` | 无 | string | 获取触控板速度 |
| `session_set_size` | display, w, h | void | 设置会话显示尺寸 |
| `session_change_resolution` | display, w, h | void | 改变分辨率 |
| `session_change_prefer_codec` | codec | void | 改变首选编解码器 |
| `session_alternative_codecs` | 无 | void | 切换到备选编解码器 |
| `session_set_flutter_option` | key, value | void | 设置Flutter选项 |
| `session_get_flutter_option` | key | string | 获取Flutter选项 |
| `session_set_confirm_override_file` | id, need_override, is_upload, remember | void | 确认覆盖文件 |
| `session_peer_option` | key | string | 获取会话对端选项 |
| `session_get_peer_option` | key | string | 获取对端选项 |
| `session_set_peer_option` | key, value | void | 设置对端选项 |
| `session_get_path_sep` | 无 | string | 获取路径分隔符 |
| `session_get_platform` | 无 | string | 获取远端平台 |
| `session_get_peer_version` | 无 | string | 获取对端版本 |
| `session_get_remember` | 无 | bool | 获取是否记住密码 |
| `session_get_conn_token` | 无 | string | 获取连接token |
| `session_get_is_recording` | 无 | bool | 获取是否正在录制 |
| `session_is_file_transfer` | 无 | bool | 是否文件传输会话 |
| `session_is_port_forward` | 无 | bool | 是否端口转发会话 |
| `session_is_rdp` | 无 | bool | 是否RDP会话 |
| `session_is_terminal` | 无 | bool | 是否终端会话 |
| `session_is_view_camera` | 无 | bool | 是否摄像头查看会话 |
| `session_is_restarting_remote_device` | 无 | bool | 远端设备是否正在重启 |
| `session_is_multi_ui_session` | 无 | bool | 是否多UI会话 |
| `session_get_enable_trusted_devices` | 无 | bool | 是否启用受信任设备 |
| `session_get_displays_as_individual_windows` | 无 | string | 获取独立窗口显示设置 |
| `session_set_displays_as_individual_windows` | value | void | 设置独立窗口显示 |
| `session_get_use_all_my_displays_for_the_remote_session` | 无 | string | 获取是否使用所有显示器 |
| `session_set_use_all_my_displays_for_the_remote_session` | value | void | 设置是否使用所有显示器 |
| `session_get_edge_scroll_edge_thickness` | 无 | int | 获取边缘滚动厚度 |
| `session_set_edge_scroll_edge_thickness` | value | void | 设置边缘滚动厚度 |
| `session_get_audit_server` | typ | string | 获取审计服务器 |
| `session_get_audit_server_sync` | typ | string | 同步获取审计服务器 |
| `session_get_audit_guid` | 无 | string | 获取审计GUID |
| `session_set_audit_guid` | guid | void | 设置审计GUID |
| `session_get_last_audit_note` | 无 | string | 获取最后审计备注 |
| `session_get_common` | key | string | 获取通用配置 |
| `session_get_common_sync` | key | string | 同步获取通用配置 |
| `session_set_common` | key, value | void | 设置通用配置 |
| `session_get_conn_session_id` | 无 | string | 获取连接会话ID |

### 10. 本地选项（4个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `get_local_option` | key | string | 获取本地选项值（Config/LocalConfig/TEMPORARY_PASSWORD等） |
| `set_local_option` | key, value | void | 设置本地选项 |
| `main_get_local_option` | key | string | 官方名：获取本地选项 |
| `main_set_local_option` | key, value | void | 官方名：设置本地选项 |
| `get_local_flutter_option` | key | string | 获取Flutter本地选项 |
| `set_local_flutter_option` | key, value | void | 设置Flutter本地选项 |
| `get_local_kb_layout_type` | 无 | string | 获取本地键盘布局类型 |
| `set_local_kb_layout_type` | value | void | 设置本地键盘布局类型 |

### 11. 对端信息（2个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `get_peer_info` | peerId | JSON | 获取对端信息（hostname/username/platform/alias），从PeerConfig.info读取 |
| `peer_get_sessions_count` | 无 | int | 获取对端会话数量 |

### 12. 账号认证（3个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_account_auth` | op, rememberMe, server, relayServer, apiServer | void | 发起账号认证请求（login/logout等操作） |
| `main_account_auth_cancel` | 无 | void | 取消账号认证 |
| `main_account_auth_result` | 无 | JSON | 获取账号认证结果 |

### 13. 远程命令（2个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `restart_remote_device` | 无 | bool | OHOS特有：重启远端设备 |
| `session_restart_remote_device` | 无 | bool | 官方名：重启远端设备 |
| `lock_remote_screen` | 无 | bool | OHOS特有：锁定远端屏幕 |
| `session_lock_screen` | 无 | bool | 官方名：锁定远端屏幕 |

### 14. 聊天/文件传输（8个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `send_chat_message` | peerId, messageType, content, timestamp | bool | OHOS特有：发送聊天消息 |
| `session_send_chat` | content | bool | 官方名：发送聊天消息 |
| `session_send_note` | note | bool | 发送备注 |
| `send_file_transfer_request` | taskId, peerId, fileName, totalBytes, direction | bool | 发送文件传输请求 |
| `start_file_transfer` | path, to, isRemote | bool | OHOS特有：启动文件传输任务 |
| `session_send_files` | path, to, isRemote | bool | 官方名：发送文件 |
| `read_remote_directory` | path, includeHidden | bool | OHOS特有：读取远端目录 |
| `session_read_remote_dir` | path, includeHidden | bool | 官方名：读取远端目录 |
| `session_add_job` | id, path, to, file_num, include_hidden, is_remote | void | 添加文件传输任务 |
| `session_add_sync` | is_sync | void | 添加同步任务 |
| `session_add_existed_sync` | is_sync | bool | 添加已存在的同步任务 |
| `session_cancel_job` | id | void | 取消任务 |
| `session_resume_job` | id, is_remote | void | 恢复任务 |
| `session_load_last_transfer_jobs` | 无 | void | 加载上次传输任务 |
| `session_remove_file` | id, path, is_remote | void | 删除远端/本地文件 |
| `session_rename_file` | id, path, is_remote | void | 重命名文件 |
| `session_read_dir_to_remove_recursive` | id, path, include_hidden | void | 递归读取待删除目录 |
| `session_read_local_dir_sync` | path, include_hidden, id | string | 同步读取本地目录 |
| `session_read_local_empty_dirs_recursive_sync` | id, path | string | 递归读取本地空目录 |
| `session_read_remote_empty_dirs_recursive_sync` | id, path | string | 递归读取远端空目录 |
| `session_remove_all_empty_dirs` | id | void | 删除所有空目录 |
| `session_set_confirm_override_file` | id, need_override, is_upload, remember | void | 确认文件覆盖 |

### 15. 文件操作（2个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `create_remote_directory` | path | bool | OHOS特有：创建远端目录 |
| `session_create_dir` | path | bool | 官方名：创建远端目录 |
| `delete_remote_path` | path, isDirectory | bool | 删除远端路径（文件或目录） |

### 16. 终端（4个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `open_terminal` | terminalId, rows, cols | bool | OHOS特有：打开终端会话 |
| `session_open_terminal` | terminalId, rows, cols | bool | 官方名：打开终端 |
| `send_terminal_input` | terminalId, data | bool | OHOS特有：发送终端输入 |
| `session_send_terminal_input` | terminalId, data | bool | 官方名：发送终端输入 |
| `resize_terminal` | terminalId, rows, cols | bool | OHOS特有：调整终端大小 |
| `session_resize_terminal` | terminalId, rows, cols | bool | 官方名：调整终端大小 |
| `close_terminal` | terminalId | bool | OHOS特有：关闭终端 |
| `session_close_terminal` | terminalId | bool | 官方名：关闭终端 |

### 17. 截图/录制（3个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_take_screenshot` | 无 | void | 截取远端屏幕截图 |
| `session_record_screen` | 无 | void | 开始/停止录制屏幕 |
| `session_handle_screenshot` | action | string | 处理截图动作，返回结果 |

### 18. 端口转发/RDP（4个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_add_port_forward` | ... | void | 添加端口转发 |
| `session_remove_port_forward` | ... | void | 移除端口转发 |
| `session_new_rdp` | 无 | void | 创建新RDP会话 |

### 19. 语音通话（4个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_request_voice_call` | 无 | void | 请求语音通话 |
| `session_close_voice_call` | 无 | void | 关闭语音通话 |
| `get_voice_call_input_device` | 无 | string | 获取语音通话输入设备 |
| `set_voice_call_input_device` | device | void | 设置语音通话输入设备 |

### 20. 会话切换/显示（6个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_switch_sides` | 无 | void | 切换主控/被控侧 |
| `session_switch_display` | display | void | 切换显示器 |
| `session_enter_or_leave` | 无 | void | 进入或离开会话 |
| `session_leave` | 无 | void | 离开会话 |
| `session_start_with_displays` | displays | bool | 使用指定显示器启动会话 |
| `session_request_new_display_init_msgs` | display | void | 请求新显示器的初始化消息 |
| `session_on_waiting_for_image_dialog_show` | 无 | void | 等待图像对话框显示 |
| `session_send_selected_session_id` | 无 | void | 发送选中的会话ID |
| `session_toggle_privacy_mode` | 无 | void | 切换隐私模式 |
| `session_toggle_virtual_display` | 无 | void | 切换虚拟显示 |

### 21. GPU/纹理渲染（4个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_register_gpu_texture` | display | int | 注册GPU纹理，返回纹理ID |
| `session_register_pixelbuffer_texture` | display | int | 注册像素缓冲区纹理，返回纹理ID |
| `session_get_rgba_size` | display | int | 获取RGBA数据大小 |
| `session_next_rgba` | display | void | 推进到下一帧RGBA数据 |
| `get_next_texture_key` | 无 | int | 获取下一个纹理key |

### 22. 打印（2个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `session_printer_response` | id, path, printer_name | void | 响应打印请求 |
| `main_get_printer_names` | 无 | string | 获取打印机名称列表 |

### 23. LAN发现（3个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `discover_lan_peers` | 无 | void | OHOS特有：启动LAN发现（UDP广播） |
| `main_discover` | 无 | void | 官方名：LAN发现 |
| `load_lan_peers` | 无 | JSON | OHOS特有：加载已发现的LAN设备列表 |
| `main_load_lan_peers` | 无 | string | 官方名：加载LAN设备 |
| `remove_discovered_peer` | peerId | bool | OHOS特有：从LAN列表移除设备 |
| `main_remove_discovered` | peerId | void | 官方名：移除已发现设备 |
| `main_get_lan_peers` | 无 | string | 获取LAN设备列表 |

### 24. 在线查询（1个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `query_onlines` | idsJson | bool | 查询对端在线状态（JSON数组→onlines/offlines回调） |

### 25. 音视频元数据（2个，被控端用）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `send_video_frame_metadata` | codec, width, height, timestamp, keyFrame, dataLength | bool | 发送视频帧元数据（被控端上报） |
| `send_audio_frame_metadata` | codec, sampleRate, channels, timestamp, dataLength | bool | 发送音频帧元数据（被控端上报） |

### 26. 连接管理器 cm_*（11个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `cm_init` | 无 | void | 初始化连接管理器 |
| `cm_close_connection` | id | void | 关闭连接 |
| `cm_remove_disconnected_connection` | 无 | void | 移除断开连接 |
| `cm_send_chat` | ... | void | 发送CM聊天消息 |
| `cm_switch_back` | id | void | 切换回指定连接 |
| `cm_switch_permission` | ... | void | 切换权限 |
| `cm_get_clients_state` | 无 | string | 获取客户端状态 |
| `cm_get_clients_length` | 无 | int | 获取客户端数量 |
| `cm_get_config` | 无 | string | 获取CM配置 |
| `cm_login_res` | 无 | string | 获取登录结果 |
| `cm_check_click_time` | 无 | void | 检查点击时间 |
| `cm_get_click_time` | 无 | string | 获取点击时间 |
| `cm_check_clients_length` | 无 | bool | 检查客户端数量 |
| `cm_can_elevate` | 无 | bool | 是否可以提权 |
| `cm_elevate_portable` | 无 | void | 便携版提权 |
| `cm_close_voice_call` | 无 | void | CM关闭语音通话 |
| `cm_handle_incoming_voice_call` | ... | void | 处理来电语音通话 |

### 27. 插件系统 plugin_*（9个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `plugin_enable` | id, enabled | void | 启用/禁用插件 |
| `plugin_is_enabled` | id | bool | 检查插件是否启用 |
| `plugin_install` | id, is_plugin | void | 安装插件 |
| `plugin_event` | ... | void | 触发插件事件 |
| `plugin_feature_is_enabled` | ... | bool | 检查插件功能是否启用 |
| `plugin_get_session_option` | ... | string | 获取插件会话选项 |
| `plugin_set_session_option` | ... | void | 设置插件会话选项 |
| `plugin_get_shared_option` | ... | string | 获取插件共享选项 |
| `plugin_set_shared_option` | ... | void | 设置插件共享选项 |
| `plugin_list_reload` | 无 | void | 重新加载插件列表 |
| `plugin_register_event_stream` | ... | void | 注册插件事件流 |
| `plugin_reload` | id | void | 重新加载插件 |
| `plugin_sync_ui` | ... | void | 同步插件UI |

### 28. 安装器 install_*（5个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `install_install_me` | ... | void | 安装本应用 |
| `install_install_options` | 无 | string | 获取安装选项 |
| `install_install_path` | 无 | string | 获取安装路径 |
| `install_run_without_install` | 无 | bool | 是否无安装运行 |
| `install_show_run_without_install` | 无 | bool | 是否显示无安装运行选项 |

### 29. 自定义客户端 is_*（10个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `is_custom_client` | 无 | bool | 是否自定义客户端 |
| `is_disable_ab` | 无 | bool | 是否禁用通讯录 |
| `is_disable_account` | 无 | bool | 是否禁用账号 |
| `is_disable_group_panel` | 无 | bool | 是否禁用分组面板 |
| `is_disable_installation` | 无 | bool | 是否禁用安装 |
| `is_disable_settings` | 无 | bool | 是否禁用设置 |
| `is_incoming_only` | 无 | bool | 是否仅入站 |
| `is_outgoing_only` | 无 | bool | 是否仅出站 |
| `is_preset_password` | 无 | bool | 是否预设密码 |
| `is_preset_password_mobile_only` | 无 | bool | 是否仅移动端预设密码 |
| `is_selinux_enforcing` | 无 | bool | SELinux是否强制模式 |
| `is_support_multi_ui_session` | 无 | bool | 是否支持多UI会话 |

### 30. main_* 全局函数（约90个）

#### 初始化/设备

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_init` | appDir, customClientConfig | void | 官方名：初始化核心（设置APP_DIR和自定义客户端配置） |
| `main_device_id` | 无 | string | 获取设备ID（Config::get_id()） |
| `main_device_name` | 无 | string | 获取设备名称 |
| `main_get_my_id` | 无 | string | 获取我的ID |
| `main_get_uuid` | 无 | string | 获取UUID |
| `main_get_version` | 无 | string | 获取版本号 |
| `main_get_build_date` | 无 | string | 获取构建日期 |
| `main_get_home_dir` | 无 | string | 获取home目录 |
| `main_set_home_dir` | path | void | 设置home目录 |
| `main_get_data_dir_ios` | 无 | string | 获取iOS数据目录（OHOS上返回空） |
| `main_video_save_directory` | 无 | string | 获取视频保存目录 |

#### 选项/配置

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_get_option` | key | string | 获取全局选项 |
| `main_set_option` | key, value | void | 设置全局选项 |
| `main_get_option_sync` | key | string | 同步获取全局选项 |
| `main_get_options` | 无 | string | 获取所有选项（JSON） |
| `main_set_options` | options | void | 设置选项（JSON） |
| `main_get_options_sync` | 无 | string | 同步获取所有选项 |
| `main_get_buildin_option` | key | string | 获取内置选项 |
| `main_get_hard_option` | key | string | 获取硬编码选项 |
| `main_show_option` | key | string | 显示选项 |
| `main_is_option_fixed` | key | bool | 检查选项是否固定 |
| `main_option_synced` | 无 | bool | OHOS特有：检查选项是否已同步 |
| `option_synced` | 无 | bool | 官方名：选项是否已同步 |
| `main_get_user_default_option` | key | string | 获取用户默认选项 |
| `main_set_user_default_option` | key, value | void | 设置用户默认选项 |

#### 对端管理

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_remove_peer` | id | void | 移除对端 |
| `main_peer_exists` | id | bool | 对端是否存在 |
| `main_peer_has_password` | id | bool | 对端是否设置了密码 |
| `main_set_peer_alias` | id, alias | void | 设置对端别名 |
| `main_get_peer_option` | id, key | string | 获取对端选项 |
| `main_set_peer_option` | id, key, value | void | 设置对端选项 |
| `main_get_peer_option_sync` | id, key | string | 同步获取对端选项 |
| `main_set_peer_option_sync` | id, key, value | void | 同步设置对端选项 |
| `main_get_peer_sync` | id | string | 同步获取对端信息 |
| `main_get_peer_flutter_option_sync` | id, key | string | 同步获取对端Flutter选项 |
| `main_set_peer_flutter_option_sync` | id, key, value | void | 同步设置对端Flutter选项 |
| `main_get_new_stored_peers` | 无 | string | 获取新存储的对端 |
| `main_load_recent_peers` | 无 | string | 加载最近对端 |
| `main_load_recent_peers_for_ab` | 无 | string | 加载AB最近对端 |
| `main_load_fav_peers` | 无 | string | 加载收藏对端 |
| `main_store_fav` | fav | void | 存储收藏 |
| `main_get_fav` | 无 | string | 获取收藏列表 |

#### 通讯录/分组

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_load_ab` | 无 | string | 加载通讯录 |
| `main_save_ab` | ab | void | 保存通讯录 |
| `main_clear_ab` | 无 | void | 清空通讯录 |
| `main_load_group` | 无 | string | 加载分组 |
| `main_save_group` | group | void | 保存分组 |
| `main_clear_group` | 无 | void | 清空分组 |

#### 密码/安全

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_get_temporary_password` | 无 | string | 获取临时密码 |
| `main_update_temporary_password` | 无 | void | 更新临时密码 |
| `main_set_permanent_password_with_result` | password | bool | 设置永久密码 |
| `main_forget_password` | id | void | 忘记密码 |
| `main_generate2fa` | 无 | string | 生成2FA密钥 |
| `main_verify2fa` | code | bool | 验证2FA代码 |
| `main_has_valid_2fa_sync` | 无 | bool | 是否有有效的2FA |
| `main_verify_bot` | token | bool | 验证Telegram Bot |
| `main_has_valid_bot_sync` | 无 | bool | 是否有有效的Bot |
| `main_get_trusted_devices` | 无 | string | 获取受信任设备 |
| `main_clear_trusted_devices` | 无 | void | 清空受信任设备 |
| `main_remove_trusted_devices` | id | void | 移除受信任设备 |
| `main_get_unlock_pin` | 无 | string | 获取解锁PIN |
| `main_set_unlock_pin` | pin | void | 设置解锁PIN |

#### 服务器/网络

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_get_api_server` | 无 | string | 获取API服务器地址 |
| `main_test_if_valid_server` | server | bool | 测试服务器是否有效 |
| `main_is_using_public_server` | 无 | bool | 是否使用公共服务器 |
| `main_get_socks` | 无 | string | 获取SOCKS代理 |
| `main_set_socks` | socks | void | 设置SOCKS代理 |
| `main_get_proxy_status` | 无 | string | 获取代理状态 |
| `main_http_request` | url, method, body, header | string | 发送HTTP请求 |
| `main_get_http_status` | 无 | string | 获取HTTP状态 |
| `main_handle_relay_id` | id | void | 处理中继ID |
| `main_get_connect_status` | 无 | string | 获取连接状态 |
| `main_check_connect_status` | 无 | void | 检查连接状态 |
| `main_get_async_status` | 无 | string | 获取异步状态 |
| `main_get_error` | 无 | string | 获取错误信息 |
| `main_get_software_update_url` | 无 | string | 获取软件更新URL |
| `main_uri_prefix_sync` | 无 | string | 同步获取URI前缀 |

#### 服务/进程

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_start_service` | 无 | void | 启动服务 |
| `main_stop_service` | 无 | void | 停止服务 |
| `main_on_main_window_close` | 无 | void | 主窗口关闭回调 |
| `main_goto_install` | 无 | void | 跳转到安装页面 |
| `main_is_installed` | 无 | bool | 是否已安装 |
| `main_is_installed_daemon` | 无 | bool | 守护进程是否已安装 |
| `main_is_installed_lower_version` | 无 | bool | 是否安装了低版本 |
| `main_is_process_trusted` | 无 | bool | 进程是否受信任 |
| `main_is_root` | 无 | bool | 是否root权限 |
| `main_start_dbus_server` | 无 | void | 启动DBus服务器 |
| `main_start_ipc_url_server` | 无 | void | 启动IPC URL服务器 |
| `main_deploy_device` | 无 | void | 部署设备 |

#### 显示/硬件

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_get_displays` | 无 | string | 获取显示器列表 |
| `main_get_main_display` | 无 | string | 获取主显示器 |
| `main_current_is_wayland` | 无 | bool | 当前是否Wayland（OHOS返回false） |
| `main_is_login_wayland` | 无 | bool | 登录界面是否Wayland |
| `main_default_privacy_mode_impl` | 无 | string | 默认隐私模式实现 |
| `main_supported_privacy_mode_impls` | 无 | string | 支持的隐私模式实现列表 |
| `main_support_remove_wallpaper` | 无 | bool | 是否支持移除壁纸 |
| `main_test_wallpaper` | 无 | void | 测试壁纸 |
| `main_hide_dock` | 无 | void | 隐藏Dock栏 |
| `main_has_hwcodec` | 无 | bool | 是否有硬件编解码 |
| `main_has_vram` | 无 | bool | 是否有显存 |
| `main_has_gpu_texture_render` | 无 | bool | 是否有GPU纹理渲染 |
| `main_get_use_texture_render` | 无 | bool | 官方名：是否使用纹理渲染 |
| `main_use_texture_render` | 无 | bool | OHOS旧名（已重命名为main_get_use_texture_render） |
| `main_check_hwcodec` | 无 | void | 检查硬件编解码 |
| `main_supported_hwdecodings` | 无 | string | 获取支持的硬件解码列表 |
| `main_audio_support_loopback` | 无 | bool | 音频是否支持回环 |
| `main_clip_cursor` | ... | void | 裁剪光标 |
| `main_set_cursor_position` | x, y | void | 设置光标位置 |
| `main_get_mouse_time` | 无 | string | 获取鼠标时间 |
| `main_check_mouse_time` | 无 | void | 检查鼠标时间 |
| `main_get_double_click_time` | 无 | int | 获取双击时间 |
| `main_handle_wayland_screencast_restore_token` | ... | void | 处理Wayland截屏恢复token |

#### 输入源

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_get_input_source` | 无 | string | 获取输入源 |
| `main_set_input_source` | source | void | 设置输入源 |
| `main_init_input_source` | 无 | void | 初始化输入源 |
| `main_supported_input_source` | 无 | string | 获取支持的输入源 |
| `main_is_can_input_monitoring` | 无 | bool | 是否可以输入监控 |
| `main_is_can_screen_recording` | 无 | bool | 是否可以屏幕录制 |

#### 杂项

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `main_change_id` | id | void | 更改设备ID |
| `main_change_language` | lang | void | 更改语言 |
| `main_change_theme` | theme | void | 更改主题 |
| `main_get_langs` | 无 | string | 获取语言列表 |
| `main_get_app_name` | 无 | string | 获取应用名 |
| `main_get_app_name_sync` | 无 | string | 同步获取应用名 |
| `main_get_license` | 无 | string | 获取许可证信息 |
| `main_get_fingerprint` | 无 | string | 获取指纹 |
| `main_get_env` | key | string | 获取环境变量 |
| `main_set_env` | key, value | void | 设置环境变量 |
| `main_max_encrypt_len` | 无 | int | 最大加密长度 |
| `main_get_login_device_info` | 无 | string | 获取登录设备信息 |
| `main_get_last_remote_id` | 无 | string | 获取上次远程ID |
| `main_has_file_clipboard` | 无 | bool | 是否有文件剪贴板 |
| `main_is_share_rdp` | 无 | bool | 是否共享RDP |
| `main_set_share_rdp` | value | void | 设置RDP共享 |
| `main_wol` | id | void | Wake-on-LAN |
| `main_check_super_user_permission` | 无 | void | 检查超级用户权限 |
| `main_create_shortcut` | id | void | 创建快捷方式 |
| `main_update_me` | path | void | 更新自己 |
| `main_resolve_avatar_url` | url | string | 解析头像URL |
| `main_get_new_version` | 无 | string | 获取新版本号 |

### 31. 其他工具函数（7个）

| 函数 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `string_free` | value | void | 释放Rust侧分配的C字符串内存 |
| `set_cur_session_id` | id | void | 设置当前会话ID |
| `translate` | name, locale | string | 翻译文本 |
| `version_to_number` | version | string | 版本号转数字 |
| `will_session_close_close_session` | 无 | bool | 会话关闭时是否关闭会话 |
| `send_url_scheme` | url | void | 发送URL scheme |
| `start_global_event_stream` | 无 | void | 启动全局事件流 |
| `stop_global_event_stream` | 无 | void | 停止全局事件流 |

### 与官方APK对比说明

官方 Android APK（rustdesk-1.4.7）使用 **Flutter FFI** 架构：
- 单一入口 `rustdesk_core_main` + 365个 `wire_*` 导出函数
- 通过 `StreamSink<EventToUI>` 和 `SyncReturn<T>` 与 Flutter 通信
- 包含完整的插件系统、安装器、连接管理器、桌面特有功能

HarmonyOS 版使用 **staticlib + CMake + NAPI** 架构：
- 369个 `rustdesk_bridge_*` C ABI 函数，通过 NAPI 注册
- 使用 JSON 字符串传递复杂数据，事件通过 `pullSessionEvents` 轮询
- **已覆盖官方绝大部分功能**：连接/会话/视频/输入/文件/聊天/终端/LAN发现/账号认证/连接管理器/插件/安装器/自定义客户端/2FA/截图录制/端口转发/RDP/语音通话/会话切换/GPU纹理渲染/打印
- **OHOS 特有函数**（官方没有对应，保留）：`apply_session_option`、`mark_session_connected`、`mark_session_error`、`refresh_session_video`、`send_mouse_input`、`send_ctrl_alt_del`、`restart_remote_device`、`lock_remote_screen`、`send_chat_message`、`start_file_transfer`、`read_remote_directory`、`create_remote_directory`、`open_terminal`/`send_terminal_input`/`resize_terminal`/`close_terminal`、`discover_lan_peers`/`load_lan_peers`/`remove_discovered_peer`、`harmony_next_rgba`、`copy_latest_video_frame`、`bootstrap_core_snapshot`、`initialize_runtime`、`drain_connect_events`/`pull_session_events`/`pull_audio_frames`、`get_*`/`send_*_metadata` 等视频/音频流函数
- **官方独有但OHOS不需要的函数**：Flutter/Dart内存管理（`drop_dart_object`/`free_*`/`new_*`）、JNI函数（`Java_ffi_*`/`JNI_OnLoad`）、`rustdesk_core_main`、`init_frb_dart_api_dl`/`store_dart_post_cobject`、`hwcodec_*`

## 附录：OHOS Bridge 与官方 RustDesk 函数对标报告（2026-06-08）

> 本报告对比 OHOS bridge_api.rs 369个导出函数与官方 flutter_ffi.rs 约280+个 pub fn 函数，用于确保核心一致性。

### 一、完全对齐的函数（OHOS名 = 官方名，去除 rustdesk_bridge_ 前缀）

以下函数在 OHOS bridge_api.rs 中存在，且命名与官方 flutter_ffi.rs 完全一致（去除 `rustdesk_bridge_` 前缀后）：

#### 1. main_* 全局函数（约70个）
`main_get_option`, `main_set_option`, `main_get_options`, `main_get_my_id`, `main_get_uuid`, `main_get_version`, `main_get_fingerprint`, `main_get_api_server`, `main_get_temporary_password`, `main_set_permanent_password_with_result`, `main_update_temporary_password`, `main_test_if_valid_server`, `main_get_connect_status`, `main_is_using_public_server`, `main_forget_password`, `main_peer_has_password`, `main_peer_exists`, `main_set_peer_alias`, `main_set_peer_option`, `main_remove_peer`, `main_get_new_stored_peers`, `main_load_recent_peers`, `main_get_langs`, `main_get_error`, `main_get_build_date`, `main_get_license`, `main_get_app_name`, `main_has_hwcodec`, `main_generate2fa`, `main_verify2fa`, `main_get_trusted_devices`, `main_clear_trusted_devices`, `main_set_user_default_option`, `main_get_user_default_option`, `main_resolve_avatar_url`, `main_get_login_device_info`, `main_get_hard_option`, `main_get_buildin_option`, `main_get_common`, `main_set_common`, `main_check_connect_status`, `main_stop_service`, `main_on_main_window_close`, `main_wol`, `main_http_request`, `main_change_id`, `main_change_language`, `main_change_theme`, `main_get_displays`, `main_get_printer_names`, `main_get_socks`, `main_set_socks`, `main_get_proxy_status`, `main_get_app_name_sync`, `main_get_new_version`, `main_get_home_dir`, `main_device_id`, `main_device_name`, `main_is_installed`, `main_is_installed_daemon`, `main_is_root`, `main_is_process_trusted`, `main_is_can_screen_recording`, `main_is_can_input_monitoring`, `main_current_is_wayland`, `main_is_login_wayland`, `main_has_vram`, `main_supported_hwdecodings`, `main_check_hwcodec`, `main_create_shortcut`, `main_get_mouse_time`, `main_check_mouse_time`, `main_get_async_status`, `main_get_lan_peers`, `main_get_last_remote_id`, `main_get_fav`, `main_store_fav`, `main_get_peer_sync`, `main_get_peer_flutter_option_sync`, `main_set_peer_flutter_option_sync`, `main_get_peer_option_sync`, `main_set_peer_option_sync`, `main_remove_trusted_devices`, `main_start_service`, `main_account_auth`, `main_account_auth_cancel`, `main_account_auth_result`, `main_get_local_option`, `main_set_local_option`, `main_get_peer_option`, `main_discover`, `main_load_lan_peers`, `main_remove_discovered`, `main_init`, `main_has_valid_2fa_sync`, `main_has_valid_bot_sync`, `main_verify_bot`, `main_max_encrypt_len`

#### 2. session_* 会话函数（约100个）
`session_close`, `session_reconnect`, `session_login`, `session_send2fa`, `session_toggle_option`, `session_toggle_privacy_mode`, `session_switch_display`, `session_enter_or_leave`, `session_leave`, `session_set_size`, `session_change_resolution`, `session_elevate_direct`, `session_elevate_with_logon`, `session_switch_sides`, `session_take_screenshot`, `session_record_screen`, `session_get_is_recording`, `session_request_voice_call`, `session_close_voice_call`, `session_add_port_forward`, `session_remove_port_forward`, `session_new_rdp`, `session_remove_file`, `session_rename_file`, `session_cancel_job`, `session_resume_job`, `session_set_confirm_override_file`, `session_send_note`, `session_input_string`, `session_input_os_password`, `session_load_last_transfer_jobs`, `session_get_view_style`, `session_set_view_style`, `session_get_scroll_style`, `session_set_scroll_style`, `session_get_image_quality`, `session_set_image_quality`, `session_get_keyboard_mode`, `session_set_keyboard_mode`, `session_get_custom_image_quality`, `session_set_custom_image_quality`, `session_set_custom_fps`, `session_get_trackpad_speed`, `session_set_trackpad_speed`, `session_get_flutter_option`, `session_set_flutter_option`, `session_get_reverse_mouse_wheel_sync`, `session_set_reverse_mouse_wheel`, `session_get_option`, `session_set_option`, `session_get_peer_option`, `session_peer_option`, `session_get_toggle_option`, `session_is_keyboard_mode_supported`, `session_get_platform`, `session_get_remember`, `session_get_enable_trusted_devices`, `session_get_alternative_codecs`, `session_change_prefer_codec`, `session_restart_remote_device`, `session_lock_screen`, `session_ctrl_alt_del`, `session_send_mouse`, `session_input_key`, `session_send_chat`, `session_open_terminal`, `session_send_terminal_input`, `session_resize_terminal`, `session_close_terminal`, `session_read_remote_dir`, `session_create_dir`, `session_send_files`, `session_start`, `session_refresh`, `session_is_file_transfer`, `session_is_terminal`, `session_is_port_forward`, `session_is_rdp`, `session_is_view_camera`, `session_handle_flutter_key_event`, `session_handle_flutter_raw_key_event`, `session_send_touch_scale`, `session_send_touch_pan_event`, `session_toggle_virtual_display`, `session_get_audit_server`, `session_send_selected_session_id`, `session_get_conn_token`, `session_get_peer_version`, `session_get_path_sep`, `session_is_restarting_remote_device`, `session_add_existed_sync`, `session_add_job`, `session_add_sync`, `session_get_audit_guid`, `session_get_audit_server_sync`, `session_get_common`, `session_get_common_sync`, `session_get_conn_session_id`, `session_get_displays_as_individual_windows`, `session_get_edge_scroll_edge_thickness`, `session_get_last_audit_note`, `session_get_rgba_size`, `session_get_toggle_option_sync`, `session_get_use_all_my_displays_for_the_remote_session`, `session_handle_screenshot`, `session_is_multi_ui_session`, `session_next_rgba`, `session_on_waiting_for_image_dialog_show`, `session_printer_response`, `session_read_dir_to_remove_recursive`, `session_read_local_dir_sync`, `session_read_local_empty_dirs_recursive_sync`, `session_read_remote_empty_dirs_recursive_sync`, `session_register_gpu_texture`, `session_register_pixelbuffer_texture`, `session_remove_all_empty_dirs`, `session_request_new_display_init_msgs`, `session_send_pointer`, `session_set_audit_guid`, `session_set_displays_as_individual_windows`, `session_set_edge_scroll_edge_thickness`, `session_set_use_all_my_displays_for_the_remote_session`, `session_start_with_displays`

#### 3. cm_* 连接管理函数（16个）
`cm_init`, `cm_get_clients_state`, `cm_check_clients_length`, `cm_get_clients_length`, `cm_send_chat`, `cm_login_res`, `cm_close_connection`, `cm_remove_disconnected_connection`, `cm_check_click_time`, `cm_get_click_time`, `cm_switch_permission`, `cm_can_elevate`, `cm_elevate_portable`, `cm_switch_back`, `cm_get_config`, `cm_handle_incoming_voice_call`, `cm_close_voice_call`

#### 4. plugin_* 插件函数（13个）
`plugin_event`, `plugin_register_event_stream`, `plugin_get_session_option`, `plugin_set_session_option`, `plugin_get_shared_option`, `plugin_set_shared_option`, `plugin_reload`, `plugin_enable`, `plugin_is_enabled`, `plugin_feature_is_enabled`, `plugin_sync_ui`, `plugin_list_reload`, `plugin_install`

#### 5. install_* / is_* 函数（17个）
`install_install_me`, `install_install_options`, `install_install_path`, `install_run_without_install`, `install_show_run_without_install`, `is_custom_client`, `is_disable_ab`, `is_disable_account`, `is_disable_group_panel`, `is_disable_installation`, `is_disable_settings`, `is_incoming_only`, `is_outgoing_only`, `is_preset_password`, `is_preset_password_mobile_only`, `is_selinux_enforcing`, `is_support_multi_ui_session`

### 二、名称已对齐的旧名映射（NAPI保留旧名，C函数调用新名）

| NAPI注册名（旧名保留） | 底层C函数调用（新名） | 官方对应函数 |
|---|---|---|
| `connectToPeer` | `rustdesk_bridge_session_start` | `session_start` |
| `setIncomingServiceEnabled` | `rustdesk_bridge_main_start_service` | `main_start_service` |
| `sendMouseInput` | `rustdesk_bridge_session_send_mouse` | `session_send_mouse` |
| `sendKeyboardInput` | `rustdesk_bridge_session_input_key` | `session_input_key` |
| `sendCtrlAltDel` | `rustdesk_bridge_session_ctrl_alt_del` | `session_ctrl_alt_del` |
| `sendChatMessage` | `rustdesk_bridge_session_send_chat` | `session_send_chat` |
| `closeSession` | `rustdesk_bridge_session_close` | `session_close` |
| `reconnectSession` | `rustdesk_bridge_session_reconnect` | `session_reconnect` |
| `submitSessionPassword` | `rustdesk_bridge_session_login` | `session_login` |
| `openTerminal` | `rustdesk_bridge_session_open_terminal` | `session_open_terminal` |
| `readRemoteDirectory` | `rustdesk_bridge_session_read_remote_dir` | `session_read_remote_dir` |
| `createRemoteDirectory` | `rustdesk_bridge_session_create_dir` | `session_create_dir` |
| `startFileTransfer` | `rustdesk_bridge_session_send_files` | `session_send_files` |
| `discoverLanPeers` | `rustdesk_bridge_main_discover` | `main_discover` |
| `loadLanPeers` | `rustdesk_bridge_main_load_lan_peers` | `main_load_lan_peers` |
| `removeDiscoveredPeer` | `rustdesk_bridge_main_remove_discovered` | `main_remove_discovered` |
| `accountAuth` | `rustdesk_bridge_main_account_auth` | `main_account_auth` |
| `restartRemoteDevice` | `rustdesk_bridge_session_restart_remote_device` | `session_restart_remote_device` |
| `lockRemoteScreen` | `rustdesk_bridge_session_lock_screen` | `session_lock_screen` |

### 三、OHOS 特有函数（官方 flutter_ffi.rs 无对应，保留）

这些函数是 OHOS 适配层特有的，因架构差异（NAPI 轮询模式 vs Flutter StreamSink 推送模式）而存在：

| OHOS 特有函数 | 用途 | 保留原因 |
|---|---|---|
| `initialize_runtime` | 运行时初始化 | OHOS 不使用 Flutter FFI 入口 |
| `get_core_snapshot` / `get_core_snapshot_json` | 核心快照 | OHOS 轮询模式需要 |
| `bootstrap_core_snapshot` | 启动引导 | OHOS 初始化流程需要 |
| `pull_session_events` / `pull_session_events_json` | 事件拉取 | OHOS 无 StreamSink |
| `pull_audio_frames` / `pull_audio_frames_json` | 音频帧拉取 | OHOS 无 StreamSink |
| `get_latest_video_frame_metadata` / `_json` | 视频帧元数据 | OHOS 轮询模式需要 |
| `copy_latest_video_frame` | 视频帧拷贝 | OHOS 无 texture 渲染 |
| `refresh_session_video` | 视频刷新 | OHOS 高层封装，被 ETS 广泛使用 |
| `harmony_next_rgba` | RGBA 帧推进 | OHOS 特有渲染路径 |
| `mark_session_connected` | 标记会话连接 | OHOS 高层封装 |
| `mark_session_error` | 标记会话错误 | OHOS 高层封装 |
| `get_session_stage` | 获取会话阶段 | OHOS 连接状态查询 |
| `get_active_peer_id` | 获取活跃对端ID | OHOS 连接状态查询 |
| `get_connect_status_summary` | 连接状态摘要 | OHOS 连接状态查询 |
| `get_connect_detail_message` | 连接详情 | OHOS 连接状态查询 |
| `get_connect_last_error` | 最近连接错误 | OHOS 连接状态查询 |
| `drain_connect_events` / `_json` | 排空连接事件 | OHOS 轮询模式需要 |
| `apply_session_option` | 应用会话选项 | OHOS 高层封装，被 ETS 广泛使用 |
| `send_clipboard_data` | 发送剪贴板 | OHOS 剪贴板路径 |
| `send_video_frame_metadata` | 视频帧元数据发送 | OHOS 内部使用 |
| `send_audio_frame_metadata` | 音频帧元数据发送 | OHOS 内部使用 |
| `send_file_transfer_request` | 文件传输请求 | OHOS 内部使用 |
| `get_peer_info` | 获取对端信息 | OHOS 连接状态查询 |
| `delete_remote_path` | 删除远端路径 | OHOS 文件操作 |
| `string_free` | 释放C字符串 | OHOS 内存管理 |
| `query_onlines` | 查询在线状态 | OHOS 在线查询 |

### 四、官方独有但 OHOS 暂不需要的函数

| 官方函数 | 说明 | 不需要原因 |
|---|---|---|
| `main_get_sound_inputs` | 获取声音输入设备列表 | 桌面端功能 |
| `drop_dart_object` / `free_*` / `new_*` | Flutter/Dart 内存管理 | OHOS 不使用 Flutter |
| `Java_ffi_*` / `JNI_OnLoad` | JNI 函数 | OHOS 不使用 JVM |
| `rustdesk_core_main` | Flutter FFI 入口 | OHOS 不使用 Flutter |
| `init_frb_dart_api_dl` / `store_dart_post_cobject` | Flutter Rust Bridge | OHOS 不使用 FRB |
| `hwcodec_*` | 硬件编解码 | OHOS 使用不同路径 |

### 五、签名差异说明

官方几乎所有 `session_*` 函数第一个参数为 `session_id: SessionID`（UUID），支持多会话并行。OHOS bridge 采用**单会话模型**（隐式全局 session），所有 session 函数无 `session_id` 参数。这是移动端架构设计选择，官方 Android/iOS 适配也采用同样的单会话模型。

关键签名差异：

| 函数 | 官方签名 | OHOS 签名 | 说明 |
|---|---|---|---|
| `session_send_mouse` | `(session_id, msg: String)` | `(mask, x, y)` | OHOS 用简单参数而非JSON |
| `session_input_key` | `(session_id, name, down, press, alt, ctrl, shift, command)` | `(key_code, is_pressed, modifiers)` | OHOS 用键码+位掩码 |
| `session_send_chat` | `(session_id, text)` | `(content)` | OHOS 简化参数 |
| `main_account_auth` | `(op, remember_me)` | `(op, remember_me, server, relay_server, api_server)` | OHOS 需显式传服务器 |
| `main_test_if_valid_server` | `(server, test_with_proxy)` | `(server)` | OHOS 缺少 test_with_proxy |
| `main_is_installed_daemon` | `(prompt: bool)` | `()` | OHOS 缺少 prompt |
| `main_is_process_trusted` | `(prompt: bool)` | `()` | OHOS 缺少 prompt |
| `main_is_can_screen_recording` | `(prompt: bool)` | `()` | OHOS 缺少 prompt |
| `main_is_can_input_monitoring` | `(prompt: bool)` | `()` | OHOS 缺少 prompt |
| `translate` | `(name, locale)` | `(name)` | OHOS 缺少 locale |
| `main_deploy_device` | `(token, id)` | `()` | OHOS 缺少参数 |
| `main_clip_cursor` | `(left, top, right, bottom, enable)` | `()` | OHOS 缺少参数 |
| `plugin_feature_is_enabled` | `()` | `(id)` | OHOS 多了 id 参数 |

### 六、2026-06-08 修复记录

1. **abi.h 清理28个旧式命名声明**：删除 `set_incoming_service_enabled`、`connect_to_peer`、`send_mouse_input` 等旧式声明，只保留新式 `session_*/main_*` 命名
2. **main_init 移入 extern "C" 块内**：修复 C++ name mangling 导致的链接符号不匹配
3. **添加 drain_connect_events 缺失声明**
4. **loader.cpp 旧名 NAPI 调用新名 C 函数**：`ConnectToPeer` → `rustdesk_bridge_session_start`，`SetIncomingServiceEnabled` → `rustdesk_bridge_main_start_service`
5. **session_alternative_codecs → session_get_alternative_codecs**：全链路更新与官方对齐
6. **核心详情页增强**：添加桥接函数数量、NAPI注册数、核心版本号、设备ID、指纹、上游版本等属性
- **尚未实现的官方函数**（stub存在但未真正实现）：`session_get_rgba`（需要GPU纹理渲染支持）
