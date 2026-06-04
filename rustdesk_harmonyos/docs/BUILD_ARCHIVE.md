# 构建与会话归档

> 本文合并原 `SCRIPT_MAINTENANCE.md`、`SESSION3_SUMMARY.md`、`SESSION4_REAL_CONNECTION_PROBE.md`、`UBUNTU_CROSS_COMPILE_GUIDE.md` 的有效内容。这里保存历史路径和经验，当前权威构建命令、产物大小、SHA256、安装命令以 `CORE.md` 为准。

## 当前日常脚本

- 构建 HAP：`node scripts/run_hvigor_with_sdk_patch.js assembleHap`
- 构建、安装、启动：`scripts/AUTO_BUILD_INSTALL.bat <hdc-target>`
- Windows 原生核心辅助脚本：`scripts/build_native_bridge.ps1`
- Linux 原生核心辅助脚本：`scripts/build_native_bridge.sh`
- Windows 清理脚本：`scripts/clean_project.ps1`
- Linux/macOS 清理脚本：`scripts/clean_project_artifacts.sh`

`run_hvigor_with_sdk_patch.js` 是当前标准 HAP 构建入口，因为它会更新 `BuildInfo.ets`，并应用当前验证过的 SDK/Hvigor 兼容补丁。

已清理的重复脚本：

- 旧的直接 Hvigor 构建/安装 batch，因为它们绕过标准补丁路径，并使用过期输出路径或无线设备默认值。
- 旧的 HAP 重打包/签名/安装 shell 链路，因为当前项目已经通过标准 HAP 构建打包核心。
- 旧的 batch-only native wrapper；`.cmd` wrapper 仍保留，因为 PowerShell native 构建辅助脚本仍会使用。
- `build_with_patch.js`，因为当前标准构建脚本已经包含所需 SDK 和 ArkTS 兼容处理。

## 会话3归档：核心初始化和 Windows 交叉编译

日期：2026-06-01。

目标：修复 RustDesk HarmonyOS 客户端构建后连接时提示“官方接入口未导出”的问题，确保 Rust 原生核心可以初始化并通过 HAP 真机启动验证。

关键修复：

- `native_rust_core/src/bridge_api.rs`
  - 上游 `harmony_bridge` 当时仍返回 `{}`。
  - 导出层改为返回有效 `BridgeSnapshot`，避免 ArkTS 收到空 JSON。
  - `initialize_runtime` 和 `get_core_snapshot` 都保留本地快照回退。
- `entry/src/main/cpp/ohos_stubs.cpp`
  - 新增 23 个 XCB/X11 空 stub，避免运行时符号缺失导致 SO 加载失败。
- `NativeRustDeskBridge.ts`
  - 增加直接属性 fallback、forced module cache、三层函数解析。
- `OfficialRustDeskBridge.ets`
  - 增加连接、启动快照、共享服务状态的重试和诊断。
- Windows 交叉编译环境
  - 通过 MSYS2 + OHOS clang 编译 libsodium。
  - 修复 `machine-uid` build.rs host/target 误判。
  - 切换 stable toolchain，避开旧 `rustix` 与 nightly 的兼容问题。
  - 修复 `socket2`、`libsodium-sys`、`kcp-sys`、`scrap`、`rdev`、`rustdesk-master/build.rs` 等交叉编译问题。

当时验证结果：

- Windows 端 `build_bridge_now.bat` 构建成功。
- 当时 staticlib：132,250,204 bytes。
- 当时 SHA256：`DEA5CF31A6A088231BE20E64BE2CB77A1C53DBA5921385E249A201B6050FF80C`。
- HAP 构建成功，安装到无线设备 `192.168.11.100:36169`。
- 日志确认：
  - `RustDesk bridge loader module registered`
  - `initializeRuntimeFn returned`
  - `Bootstrap snapshot` 中 `coreReady=true`

这些数值是历史值，当前产物以 `CORE.md` 为准。

## 会话4归档：真实连接探针

日期：2026-06-02。

目标：从模拟连接推进到真实 RustDesk transport/login/video decode 探针。

关键改动：

- `rustdesk-master/src/harmony_bridge/core.rs`
  - `connect_to_peer()` 开始走官方 RustDesk client transport 路径。
  - 增加轻量 `HarmonyClientHandler`，实现 `client::Interface`。
  - 复用官方 `handle_hash`、`handle_login_error`、`handle_test_delay`。
  - 将 `Hash`、`LoginResponse::PeerInfo`、`LoginResponse::Error`、`TestDelay`、`CloseReason` 映射为 Harmony bridge 状态和事件。
  - 移除早期伪连接成功生命周期。
  - `submit_session_password()` 改为带认证信息重连。
- 视频探针
  - `VideoFrame` 经 RustDesk `scrap::codec::Decoder` 解码。
  - 解码后的 ARGB/BGRA 字节缓存到 native。
  - 通过 `get_latest_video_frame_metadata_json()` 和 `copy_latest_video_frame()` 暴露给 ArkTS。

当时验证结果：

- Rust OHOS release build 成功。
- 当时 `librustdesk_core.a`：133,488,246 bytes。
- 当时 SHA256：`6E73D97288C91AF1622756F319124BDC2E5975A124A082E639B8DB848524B6DE`。
- HAP 构建、安装、启动成功。
- 日志确认 `coreReady=true`，进程保持前台存活。

当时边界：

- 已经不是伪连接生命周期。
- 仍不是完整远控会话闭环。
- 后续需要把认证流、视频帧、输入、剪贴板、文件、终端、关闭命令都接到 live session。

当前这些工作已有后续推进，最新状态以 `CORE.md` 和 `CONNECTION_DEBUG_LOG.md` 为准。

## Ubuntu 交叉编译归档

Ubuntu 交叉编译路径曾验证成功，但当前优先使用 Windows 的 `build_bridge_now.bat`，因为它和 DevEco/HAP 构建环境一致。

关键认知：

- `aarch64-unknown-linux-ohos` 的 `target_os` 是 `linux`，不是 `ohos`。
- 区分 OHOS 必须使用 `target_env = "ohos"`。
- Rust 核心不能再走 `cdylib + dlopen`，当前稳定方案是 `staticlib + CMake 直接链接`。
- bindgen 必须传入 OHOS sysroot。
- libsodium 必须为 OHOS target 单独交叉编译。

历史 Ubuntu 入口：

```bash
export RUSTDESK_HARMONY_BUILD_DIR="/media/$USER/Data/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_build"
export OHOS_NDK_HOME="$RUSTDESK_HARMONY_BUILD_DIR/ohos-sdk"
cd /media/$USER/Data/Visual_Studio_Code/11_Rustdesk/rustdesk_harmonyos/scripts
./build_native_bridge.sh aarch64-unknown-linux-ohos release
```

常见问题：

- `cfg(target_os = "ohos")` 永远不匹配，应改用 `target_env = "ohos"`。
- `LIBCLANG_PATH` 应指向 LLVM `lib` 目录，而不是 `bin`。
- `BINDGEN_EXTRA_CLANG_ARGS` 必须包含 OHOS target、sysroot 和 include 路径。
- `RUSTFLAGS` 必须指定 OHOS lld，避免调用 PATH 里的错误 `ld.exe`。
- 如果使用 Ubuntu 路径，必须确认 RustDesk 源码 patch、SDK mirror、libsodium、vcpkg 与当前 Windows 环境一致。

历史验证清单：

- `librustdesk_harmony_bridge.a` 文件大小大于 100MB。
- `rustdesk_bridge_get_peer_option` 可检出。
- `rustdesk_bridge_get_peer_info` 可检出。
- `rustdesk_bridge_initialize_runtime` 可检出。
- `.a` 已复制到 `entry/src/main/libs/arm64/librustdesk_core.a`。

## 历史经验

- DevEco Studio 能连接设备，不代表命令行 HDC 已经选中同一目标。
- 多目标环境必须显式加 `-t <target>`。
- 无线 HDC 长时间抓日志后可能 offline，先 `hdc tconn <ip:port>`，不要误判为构建失败。
- 验证核心不能只看 SO 符号或 module registered，必须看 ArkTS 收到的 `initializeRuntimeFn returned` 和 `Bootstrap snapshot`。
- 修改 Rust staticlib 后，要确认 `.a`、`librustdesk_bridge.so`、签名 HAP 都包含新内容，再安装测试。
- 抓 hilog 建议先 `hilog -r` 清空，启动后 `hilog -x` 拉完整日志到本地，再做本地过滤。
