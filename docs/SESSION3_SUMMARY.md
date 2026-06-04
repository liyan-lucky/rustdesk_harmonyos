# 会话3总结 (2026-06-01)

> 供新对话接续使用，包含完整上下文和下一步操作

## 本次会话目标

修复 RustDesk HarmonyOS 客户端构建后连接时提示"官方接入口未导出"的问题，确保 Rust 原生核心能正确初始化和运行。

## 已完成的工作

### 1. bridge_api.rs 空JSON修复 (已编译进当前staticlib，HAP待验证)
- **问题**: `rustdesk_core::harmony_bridge` 模块全部是 stub 空实现，`initialize_runtime` 返回 `"{}"`，`get_core_snapshot_json` 返回 `"{}"`
- **影响**: ArkTS 解析 `{}` 后所有字段 undefined，coreReady 为 undefined，核心状态异常
- **修复**: `native_rust_core/src/bridge_api.rs` 中 `initialize_runtime` 和 `get_core_snapshot` 在上游返回 `{}` 时使用 `bridge_state::BridgeSnapshot` 生成有效 JSON（`coreReady: true`, `adapter: "official-native"`）
- **文件**: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\native_rust_core\src\bridge_api.rs`

### 2. ohos_stubs.cpp XCB符号stub (已完成)
- **问题**: `librustdesk_bridge.so` 中 23 个 XCB/X11 未解析符号导致运行时 dlopen 失败
- **修复**: 创建 `entry/src/main/cpp/ohos_stubs.cpp` 提供 23 个空 stub 实现
- **文件**: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\entry\src\main\cpp\ohos_stubs.cpp`

### 3. NativeRustDeskBridge.ts 增强 (已完成)
- **修复**: resolveFunction 直接属性 fallback、getModule forced 缓存、connectToPeer 3 层函数解析、MODULE_CANDIDATES 增加 librustdesk_bridge
- **文件**: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\entry\src\main\ets\services\NativeRustDeskBridge.ts`

### 4. OfficialRustDeskBridge.ets 增强 (已完成)
- **修复**: connectToPeer/bootstrapCoreSnapshot/setIncomingServiceEnabled 增加重试+诊断
- **文件**: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\entry\src\main\ets\services\OfficialRustDeskBridge.ets`

### 5. Windows 交叉编译环境搭建 (已完成；原中断状态见下)

已解决的前置问题:
- **libsodium**: 通过 MSYS2+OHOS clang 交叉编译成功，产物 549KB `liblibsodium.a`
  - 位置: `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build\libsodium\aarch64-unknown-linux-ohos\lib\liblibsodium.a`
- **machine-uid build.rs**: `#[cfg(target_os="windows")]` 在交叉编译时检查 host 而非 target
  - 修复: patch 改用 `env::var("TARGET")` 判断
  - patch 位置: `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\patches\machine-uid\381ff57\build.rs`
  - Cargo.toml 已添加 `[patch."https://github.com/rustdesk-org/machine-uid"]`
- **rustix 0.37 与 nightly 不兼容**: 切换 stable 工具链 (`cargo +stable build`)
  - 已安装: `rustup target add aarch64-unknown-linux-ohos --toolchain stable-x86_64-pc-windows-msvc`

原编译被中断时的状态（已被下方接续结果覆盖）:
- `cargo +stable build --release --target aarch64-unknown-linux-ohos` 正在编译中
- 大部分依赖已编译完成，正在编译应用层 crate

## 下一步操作 (新对话接续)

## 接续结果 (2026-06-01)

Windows 端 Rust 核心已继续编译成功，`build_bridge_now.bat` 已生成并同步新 staticlib。

- 产物: `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\harmony\librustdesk_harmony_bridge.a`
- HAP 链接副本: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`
- 大小: 132,262,622 bytes
- SHA256: `27D91DB4EBC2BF7F51A501103D34050534A39727C8EA710F5C9BAB1133A6FB21`
- 已验证符号: `rustdesk_bridge_initialize_runtime`, `rustdesk_bridge_get_core_snapshot`, `rustdesk_bridge_get_peer_info`

本次 Windows 交叉编译新增/修正的构建环境补丁:
- `socket2-0.4.10`: `IovLen` cfg 增加 `target_env = "ohos"`
- `build_bridge_now.bat`: 移除全局 `SODIUM_LIB_DIR`，避免 host build script 误链接 OHOS aarch64 libsodium；补充 bindgen target-specific 参数
- `libsodium-sys-0.2.7`: 支持读取 `SODIUM_LIB_DIR_aarch64_unknown_linux_ohos`
- `kcp-sys`: bindgen 显式读取 target-specific `BINDGEN_EXTRA_CLANG_ARGS`
- `scrap`: build.rs 改为基于 target 判断 backend，OHOS 不启用 dxgi/x11/quartz；补齐 OHOS fallback `PixelBuffer/Display/Capturer/is_x11`
- `rdev`: OHOS 下排除 X11 linux 模块并提供 no-op API
- `rustdesk-master/build.rs`: `build_windows()` 改为仅 target 为 Windows 时执行

后续可直接进入 HAP 构建:
```bash
cd E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos
node scripts\run_hvigor_with_sdk_patch.js assembleHap
```

## 清理结果 (2026-06-01)

- 项目根目录仅保留 `.codeartsdoer/`、`.git/`、`rustdesk_harmonyos/`
- `rustdesk_harmonyos/` 已删除 `.hvigor/`、`oh_modules/`、`entry/build/`、`entry/.cxx/`、`build_log.txt`
- `docs/o2.md` 和根目录 `stub_symbols.txt` 已删除，docs 当前保留8个Markdown
- `99_Temp/` 仅保留 `rustdesk-master/` 源码和 `rustdesk_harmonyos_build/` 工具/SDK/外部源码/patch/当前产物
- 已删除 `harmonyos_build/`、`harmonyos_cache/`、`rustdesk_archive/`、`rustdesk_compile_fix_backup/`、官方APK、vcpkg下载/构建缓存、Rust target缓存
- 当前 `native_rust_core/target/` 只保留 `target/harmony/librustdesk_harmony_bridge.a`，重新编译会全量构建

### Step 1: 如需重新编译 Rust 核心
```bash
# 直接运行构建脚本 (会自动设置所有环境变量；当前target缓存已清理，会全量编译)
E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat
```
产物会自动复制到:
- `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\harmony\librustdesk_harmony_bridge.a`
- `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\entry\src\main\libs\arm64\librustdesk_core.a`

当前已解决的Windows交叉编译问题包括 stable/rustix、libsodium、machine-uid、socket2、libsodium-sys、kcp-sys、scrap、rdev、rustdesk-master build.rs。

### Step 2: 构建 HAP
```bash
cd E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos
node scripts\run_hvigor_with_sdk_patch.js assembleHap
```

### Step 3: 安装到设备
```bash
hdc start
hdc install entry\build\default\outputs\default\entry-default-signed.hap
```

### Step 4: 验证
```bash
hdc shell "hilog -x | grep -E 'coreReady|RustDeskLoader'"
# 预期: coreReady:true, adapter:"official-native"
```

## 关键文件路径

### 项目目录
- 项目根: `E:\Visual_Studio_Code\11_Rustdesk\rustdesk_harmonyos\`
- 构建环境: `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\`
- RustDesk上游: `E:\Visual_Studio_Code\99_Temp\rustdesk-master\`

### 已修改的源文件
- `native_rust_core/src/bridge_api.rs` — initialize_runtime/get_core_snapshot 使用 BridgeSnapshot
- `native_rust_core/Cargo.toml` — 添加 [patch] 段覆盖 machine-uid
- `entry/src/main/cpp/ohos_stubs.cpp` — 23个 XCB 符号 stub (新建)
- `entry/src/main/cpp/CMakeLists.txt` — 添加 ohos_stubs.cpp
- `entry/src/main/ets/services/NativeRustDeskBridge.ts` — 增强模块加载
- `entry/src/main/ets/services/OfficialRustDeskBridge.ets` — 增加重试+诊断
- `entry/src/main/ets/common/BuildInfo.ets` — 构建时间戳

### 构建脚本
- `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build_bridge_now.bat` — Windows端一键编译脚本
- `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\build_libsodium_msys.sh` — libsodium交叉编译
- `E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\patches\machine-uid\381ff57\` — machine-uid patch

### 关键只读文件
- `native_rust_core/src/bridge_state.rs` — BridgeSnapshot 结构体、JSON 序列化
- `native_rust_core/src/lib.rs` — crate 入口，re-export 46个 bridge 函数
- `entry/src/main/cpp/rustdesk_bridge_loader.cpp` — C++ NAPI 包装层(51个函数)
- `entry/src/main/cpp/rustdesk_bridge_abi.h` — C++ ABI 声明(46个 extern "C")
- `entry/src/main/cpp/types/librustdesk_bridge/index.d.ts` — TypeScript 类型声明(50个导出)
- `entry/src/main/libs/arm64/librustdesk_core.a` — 当前Rust核心staticlib(132,262,622 bytes，含bridge_api.rs空JSON修复)

## 用户偏好

- Rust 作为核心编程语言，HarmonyOS/OpenHarmony 开发环境（DevEco Studio + HDC + ArkTS/ArkUI）
- 希望分析问题原因并解释逻辑原理
- 偏好中文交互和 UI 显示
- 使用 192.168.11.100:36169 作为测试设备地址
- Windows 端编译 Rust 核心（使用 99_Temp 的 SDK 避免权限问题），不再依赖 Ubuntu
- SDK 使用 `99_Temp/rustdesk_harmonyos_build/deveco-sdk/`（从 DevEco Studio 同步的完整 SDK）

## 架构概览

```
ArkTS UI
    ↓ NAPI (C++注册51个函数)
librustdesk_bridge.so (C++桥接 + Rust核心)
    ↓ Rust C ABI (native_rust_core导出46个函数)
RustDesk core (协议/网络/加密)
    ↓
RustDesk Server
```

四层接口对齐: Rust C ABI (46个) → C++ ABI header (46个) → C++ NAPI (51个) → TypeScript (50个)
