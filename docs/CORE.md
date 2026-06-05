# 核心架构与可复现编译

> 本文档记录 HarmonyOS 版 RustDesk 的核心结构、当前可用核心状态、重新编译路径和验证清单。目标是：即使清理了旧备份和生成产物，也能按本文重新编译出当前可用核心。

## 当前结论

- 当前采用 `staticlib + CMake 直接链接` 方案。
- ArkTS 通过 NAPI 调用 `librustdesk_bridge.so`。
- `librustdesk_bridge.so` 直接链接 Rust staticlib：`entry/src/main/libs/arm64/librustdesk_core.a`。
- 不再使用 `dlopen` 加载 Rust 核心，避免 TEXTREL 和运行时加载问题。
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
- RustDesk upstream source: `%VSCODE_ROOT%\99_Temp\rustdesk-master`
- Native build workspace: `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build`
- Core staticlib in app: `%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`
- HAP staged project copy: `%VSCODE_ROOT%\99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`
- Signed HAP output: `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`

## 关键文件

| 文件 | 作用 |
| --- | --- |
| `native_rust_core/Cargo.toml` | Rust bridge crate 配置，输出 `staticlib` |
| `native_rust_core/src/bridge_api.rs` | Rust C ABI 导出入口 |
| `entry/src/main/cpp/rustdesk_bridge_abi.h` | C++ 侧 Rust ABI 声明 |
| `entry/src/main/cpp/rustdesk_bridge_loader.cpp` | NAPI bridge loader |
| `entry/src/main/cpp/CMakeLists.txt` | 将 `librustdesk_core.a` 链接进 `librustdesk_bridge.so` |
| `entry/src/main/libs/arm64/librustdesk_core.a` | 当前 HAP 链接用 Rust staticlib |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | ArkTS 原生桥接封装 |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ts` | 官方连接状态和事件封装 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程会话 UI、视频帧、输入、重试弹窗 |

## 当前核心必须保留的能力

重建环境时，`%VSCODE_ROOT%\99_Temp\rustdesk-master` 中的 Harmony bridge 相关改动必须保留，尤其是：

- `src/harmony_bridge/core.rs`
  - `connect_to_peer()` 走官方 RustDesk session 路径，并保存 active `Session<HarmonyHandler>`。
  - `refresh_session_video(display)` 调用：
    - `session.request_init_msgs(display)`
    - `session.refresh_video(display)`
  - `harmony_next_rgba(display)` 从 `session.ui_handler.next_rgba(display)` 取帧。
  - `send_mouse_input(mask, x, y)` 转发到 active session，不能退回旧的 stub `false`。
  - `send_ctrl_alt_del()` 调用 active session 的 official `ctrl_alt_del()`，不能用普通键盘按键模拟替代。
  - `get_peer_info(peer_id)` 从 `PeerConfig.info` 返回 hostname、username、platform、alias。
- OHOS platform stubs 必须避免依赖桌面 Linux/Windows API。
- ArkTS 输入必须按官方 RustDesk mouse mask 编码：
  - 低 3 bit 是 event type。
  - button bits 左移 3 位。
  - wheel 使用官方 wheel type 和滚动 delta。

## 当前验证过的产物

Native core:

- 文件：`entry/src/main/libs/arm64/librustdesk_core.a`
- Size: `135,673,254` bytes
- SHA256: `B1224DDE1CD4ECA502D7585F3CCE2D89F41B55FF075914DE6757A2F184EB649B`
- Build time observed: `2026-06-02 21:15`

HAP:

- BuildInfo compile time: `2026-06-04 01:14`
- Signed HAP size: `45,416,051` bytes
- Bundle: `com.open.rundesk`
- ABI: `arm64-v8a`
- USB target used for validation: configured by `RUSTDESK_HARMONY_USB_TARGET`; hardware IDs are not recorded in docs.
- Wireless target used for validation: `192.168.11.100:36169`

## Windows 一键重编核心

前置要求：

- DevEco Studio SDK: `C:\Program Files\Huawei\DevEco Studio\sdk\default`
- DevEco Node/Hvigor: `C:\Program Files\Huawei\DevEco Studio\tools`
- 如果借用电脑上的 DevEco 不在默认路径，优先更新 `local.properties`，或设置 `DEVECO_SDK_HOME`、`DEVECO_TOOLS_HOME`、`DEVECO_NODE_EXE`、`HDC_EXE`。
- Rust stable toolchain
- Rust target:

```powershell
rustup target add aarch64-unknown-linux-ohos --toolchain stable
```

- MSYS2: `C:\msys64`
- OHOS SDK mirror: `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build\ohos-sdk`
- vcpkg/libsodium outputs under `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build`

重编命令：

```cmd
cmd /c %VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat
```

预期结果：

- Cargo 为 `aarch64-unknown-linux-ohos` 构建 `rustdesk_harmony_bridge`。
- 生成 `librustdesk_harmony_bridge.a`。
- 脚本复制产物到：

```text
%VSCODE_ROOT%\11_Rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a
```

重编后检查：

```powershell
$env:VSCODE_ROOT = (Resolve-Path ..\..).Path
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

Ubuntu 交叉编译路径曾验证通过，但当前优先使用 Windows 的 `build_bridge_now.bat`，因为它与当前 DevEco/HAP 构建环境一致。

历史 Ubuntu 入口：

```bash
export RUSTDESK_HARMONY_BUILD_DIR="$VSCODE_ROOT_LINUX/99_Temp/rustdesk_harmonyos_build"
export OHOS_NDK_HOME="$RUSTDESK_HARMONY_BUILD_DIR/ohos-sdk"
cd $VSCODE_ROOT_LINUX/11_Rustdesk_harmonyos/scripts
./build_native_bridge.sh aarch64-unknown-linux-ohos release
```

如需使用 Ubuntu 路径，必须确认其源码、patch、SDK mirror、libsodium、vcpkg 与 Windows 当前环境一致。脚本目录当前只保留 arm64 有效链路，Linux 下不要再使用旧的 HAP repack/sign/install shell 链。

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
