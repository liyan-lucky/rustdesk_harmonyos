# Ubuntu 交叉编译 RustDesk HarmonyOS 核心库 — 实战指南

> 目标：在 Ubuntu 上为 `aarch64-unknown-linux-ohos` 交叉编译 `librustdesk_harmony_bridge.a`，
> 使其包含新增的 `rustdesk_bridge_get_peer_option` 和 `rustdesk_bridge_get_peer_info` 导出符号。

---

## 1. 关键认知

### 1.1 OHOS target 特性

| 属性 | 值 | 影响 |
|------|-----|------|
| `target_os` | `"linux"` | **不是** `"ohos"`！所有 `cfg(target_os = "linux")` 都会匹配 |
| `target_env` | `"ohos"` | 唯一区分OHOS的方式，用 `cfg(not(target_env = "ohos"))` 排除 |
| `target_arch` | `"aarch64"` | 64位ARM |
| linker | ld.lld | 必须用lld，GNU ld有TEXTREL bug |

### 1.2 为什么必须在 Ubuntu 上编译

- `libsodium-sys` native库验证：rustc(host=MSVC)无法验证OHOS `.a` 格式
- `pkg-config` 交叉编译：MSYS2 pkg-config不完整
- `libdbus-1-dev` 等系统依赖：Windows无对应包

### 1.3 staticlib 是唯一可行方案

cdylib 因 Rust/lld 的 TEXTREL bug 无法工作。必须用 staticlib + CMake 直接链接。

---

## 2. 环境准备

### 2.1 系统依赖

```bash
sudo apt update && sudo apt install -y \
  build-essential pkg-config libdbus-1-dev libglib2.0-dev libgtk-3-dev \
  libpango1.0-dev libatk1.0-dev libgdk-pixbuf2.0-dev libcairo2-dev \
  libsodium-dev libopus-dev libvpx-dev libaom-dev libyuv-dev libssl-dev \
  libpulse-dev libxdo-dev libx11-dev libxfixes-dev libxrandr-dev libxtst-dev \
  libevdev-dev libpam0g-dev nasm yasm cmake ninja-build clang lld llvm
```

### 2.2 Rust 工具链

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup toolchain install stable
rustup target add aarch64-unknown-linux-ohos
```

### 2.3 OHOS NDK（Linux版）

```bash
# 下载 OpenHarmony 5.0.1 Linux NDK（约2.5GB）
BUILD_DIR="/media/$USER/Data/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

wget https://repo.huaweicloud.com/openharmony/os/5.0.1-Release/ohos-sdk-windows_linux-public.tar.gz
tar xzf ohos-sdk-windows_linux-public.tar.gz

# 验证
ls ohos-sdk/native/llvm/bin/clang  # 应存在
ohos-sdk/native/llvm/bin/clang --version  # clang 15.0.4
```

NDK包含：clang-15, llvm-ar, llvm-nm, ld.lld, llvm-ranlib, sysroot(aarch64-linux-ohos headers)

### 2.4 libsodium（预编译）

已有预编译版本：
```
$BUILD_DIR/external-src/libsodium-aarch64-unknown-linux-ohos/install/lib/libsodium.a
```

---

## 3. 源码修改清单（核心难点）

> ⚠️ 这些修改**大部分不在Windows端**，需要在Ubuntu上直接修改源码。
> 原因：Cargo.toml中注释了桌面crate依赖，但源码中仍有引用，需要添加 `cfg(not(target_env = "ohos"))` 条件编译。

### 3.1 Cargo.toml 修改

#### `rustdesk-master/Cargo.toml`

| 修改 | 原因 |
|------|------|
| 注释 `openssl = { version = "0.10", features = ["vendored"] }` | OHOS sysroot无openssl |
| reqwest features: 移除 `"native-tls"`, 保留 `"rustls-tls"` | 用rustls替代native-tls |
| 注释 sciter/enigo/clipboard/arboard/clipboard-master/portable-pty 等 | 依赖x11/wayland |
| 注释 tray-icon/tao/keepawake/wallpaper/softbuffer/fontdb | 桌面UI |
| 注释 libxdo/pulse/evdev/dbus/gtk/winit 等 | Linux桌面特有 |

#### `rustdesk-master/libs/hbb_common/Cargo.toml`

| 修改 | 原因 |
|------|------|
| 注释 `sctk`, `x11` | wayland/x11不可用 |
| 注释 `tokio-native-tls` | 用rustls替代 |
| `socket2 = { version = "0.3" }` → `socket2 = { version = "0.5", features = ["all"] }` | 0.3 API不兼容OHOS |
| tokio-tungstenite/tungstenite: 移除 `"native-tls"` feature | |

#### `rustdesk-master/libs/scrap/Cargo.toml`

| 修改 | 原因 |
|------|------|
| 注释 `nokhwa` | 引入wayland/smithay |
| `scrap` features: 移除 `"wayland"` | 移除gstreamer/glib |

### 3.2 源码条件编译修改（cfg保护）

**核心模式**：在所有使用桌面crate的代码块前添加 `#[cfg(not(target_env = "ohos"))]`

#### hbb_common 修改

| 文件 | 修改内容 |
|------|---------|
| `src/lib.rs` | 注释 `pub use x11;` |
| `src/platform/linux.rs` | 注释 sctk import 和 `get_wayland_displays()` 函数 |
| `src/proxy.rs` | 注释 tokio_native_tls import，NativeTls分支替换为Rustls fallback |
| `src/websocket.rs` | 注释 tokio_native_tls import，NativeTls分支替换为Rustls fallback |
| `src/udp.rs` | socket2 0.5 API: `Domain::ipv4()` → `Domain::IPV4`, `Type::dgram()` → `Type::DGRAM`, `.into_udp_socket()` → `.into()` |

#### scrap 修改

| 文件 | 修改内容 |
|------|---------|
| `src/common/mod.rs` | `#[cfg(not(any(target_os = "ios", target_env = "ohos")))] pub mod camera;` |
| `src/common/camera.rs` | nokhwa import添加 `not(target_env = "ohos")` |

#### rustdesk-master/src/lib.rs 修改

```rust
// 桌面模块添加OHOS排除
#[cfg(not(any(target_os = "android", target_os = "ios", target_env = "ohos")))]
pub mod ui;
#[cfg(not(any(target_os = "ios", target_env = "ohos")))]
mod clipboard;
#[cfg(not(any(target_os = "android", target_os = "ios", target_env = "ohos")))]
mod tray;
#[cfg(not(any(target_os = "android", target_os = "ios", target_env = "ohos")))]
mod whiteboard;
#[cfg(not(any(target_os = "android", target_os = "ios", target_env = "ohos")))]
mod updater;
#[cfg(not(target_env = "ohos"))]
mod ui_cm_interface;
#[cfg(not(target_env = "ohos"))]
mod ui_interface;
#[cfg(not(target_env = "ohos"))]
mod ui_session_interface;
pub mod harmony_bridge;  // 新增
```

#### rustdesk-master/src/harmony_bridge/ 新建

需要创建stub模块，当前包含bridge_api.rs调用的45个core函数，并通过mod.rs重导出：

```
src/harmony_bridge/mod.rs   → pub mod core; pub use self::core::*;
src/harmony_bridge/core.rs  → 45个pub fn stub/PeerConfig helper实现
```

stub策略：返回String的返回`"{}"`, 返回bool的返回`false`, 返回c_int的返回`0`, 返回()的为空实现。

#### 批量cfg替换（最关键的修改）

**对以下文件**，将所有 `cfg(not(any(target_os = "android", target_os = "ios")))` 替换为 `cfg(not(any(target_os = "android", target_os = "ios", target_env = "ohos")))`：

```
src/client.rs, src/ipc.rs, src/clipboard.rs, src/clipboard_file.rs,
src/common.rs, src/core_main.rs, src/flutter_ffi.rs, src/flutter.rs,
src/lan.rs, src/privacy_mode.rs, src/tray.rs, src/keyboard.rs,
src/ui_cm_interface.rs, src/ui.rs, src/ui_session_interface.rs
```

**对server/目录**，同样替换，并将 `cfg(target_os = "linux")` 替换为 `cfg(all(target_os = "linux", not(target_env = "ohos")))`：

```
src/server/connection.rs, src/server/input_service.rs,
src/server/display_service.rs, src/server/video_service.rs,
src/server/terminal_service.rs, src/server/clipboard_service.rs
```

#### server/目录特殊处理

| 文件 | 修改 |
|------|------|
| `uinput.rs` | `pub mod client`, `pub mod service`, `mod mouce` 全部添加 `#[cfg(not(target_env = "ohos"))]` |
| `rdp_input.rs` | `pub mod client` 添加 `#[cfg(not(target_env = "ohos"))]` |
| `input_service.rs` | 使用enigo/Key/Enigo的函数需逐个添加cfg保护（见下文） |

#### platform/目录特殊处理

| 文件 | 修改 |
|------|------|
| `gtk_sudo.rs` | 所有函数添加 `#[cfg(not(target_env = "ohos"))]` |
| `linux.rs` | dbus相关函数添加cfg保护 |

### 3.3 socket2 0.4.10 IovLen bug（cargo cache修改）

socket2 0.4.10（async-io间接依赖）在OHOS target上IovLen类型定义错误。

**修改位置**：`~/.cargo/registry/src/index.crates.io-*/socket2-0.4.10/src/sys/unix.rs`

在IovLen的cfg中添加 `target_env = "ohos"`：

```rust
#[cfg(any(
    all(
        target_os = "linux",
        any(
            target_env = "musl",
            target_env = "ohos",  // 新增
            all(target_env = "uclibc", target_pointer_width = "32")
        )
    ),
```

> ⚠️ `[patch.crates-io]` 无法patch同一registry source，只能直接修改cache。
> 每次 `cargo clean` 或cache更新后需重新修改。

### 3.4 build_native_bridge.sh 修改

在Vcpkg段后添加：

```bash
# pkg-config cross-compilation support
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"

# RUSTFLAGS for OHOS linker
export RUSTFLAGS="-C link-arg=--target=$BINDGEN_TARGET -C link-arg=-fuse-ld=lld"

# LIBCLANG_PATH for bindgen (注意：是lib目录，不是bin目录)
export LIBCLANG_PATH="$LLVM_BIN/../lib"
```

SODIUM_LIB_DIR修改（避免host/target架构冲突）：

```bash
SODIUM_LIB_DIR=${SODIUM_LIB_DIR:-"$BUILD_ROOT/build/libsodium/$TARGET_TRIPLE/lib"}
if [ -d "$SODIUM_LIB_DIR" ]; then
  # 只设置target-specific变量，不设置全局SODIUM_LIB_DIR
  export "SODIUM_LIB_DIR_${TARGET_KEY_CC}=$SODIUM_LIB_DIR"
fi
```

---

## 4. 编译步骤

### 4.1 编译命令

```bash
export RUSTDESK_HARMONY_BUILD_DIR="/media/$USER/Data/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_build"
export OHOS_NDK_HOME="$RUSTDESK_HARMONY_BUILD_DIR/ohos-sdk"

cd /media/$USER/Data/Visual_Studio_Code/11_Rustdesk/rustdesk_harmonyos/scripts
./build_native_bridge.sh aarch64-unknown-linux-ohos release
```

### 4.2 验证输出

```bash
OUTPUT_A="$RUSTDESK_HARMONY_BUILD_DIR/native_rust_core/target/aarch64-unknown-linux-ohos/release/librustdesk_harmony_bridge.a"
NM="$OHOS_NDK_HOME/native/llvm/bin/llvm-nm"

ls -lh "$OUTPUT_A"  # 应 > 100MB
$NM --defined-only "$OUTPUT_A" | grep rustdesk_bridge_get_peer_option  # 应有输出
$NM --defined-only "$OUTPUT_A" | grep rustdesk_bridge_get_peer_info    # 应有输出
```

### 4.3 同步到HAP链接位置

```bash
cp "$RUSTDESK_HARMONY_BUILD_DIR/native_rust_core/target/harmony/librustdesk_harmony_bridge.a" \
   /media/$USER/Data/Visual_Studio_Code/11_Rustdesk/rustdesk_harmonyos/entry/src/main/libs/arm64/librustdesk_core.a
```

---

## 5. 编译错误排查实战记录

### 5.1 libsodium host/target架构冲突

**错误**：`rust-lld: error: ...liblibsodium_sys...rlib is incompatible with elf64-x86-64`

**原因**：全局 `SODIUM_LIB_DIR` 指向aarch64 libsodium.a，但host(x86-64) build script也尝试链接它。

**解决**：只设置 `SODIUM_LIB_DIR_aarch64_unknown_linux_ohos`，不设置全局 `SODIUM_LIB_DIR`。编译前清除libsodium_sys缓存：
```bash
rm -rf $BUILD_DIR/native_rust_core/target/release/build/libsodium_sys-*
```

### 5.2 bindgen找不到libclang.so

**错误**：`libclang shared library not found`

**原因**：`LIBCLANG_PATH` 设置为 `$LLVM_BIN`，但 `libclang.so` 在 `$LLVM_BIN/../lib/`。

**解决**：`export LIBCLANG_PATH="$LLVM_BIN/../lib"`

### 5.3 cfg(target_os = "ohos") 永远不匹配

**错误**：添加的 `cfg(target_os = "ohos")` 条件编译不生效。

**原因**：`aarch64-unknown-linux-ohos` 的 `target_os` 是 `"linux"`，不是 `"ohos"`。只有 `target_env` 是 `"ohos"`。

**解决**：统一使用 `cfg(target_env = "ohos")` 或 `cfg(not(target_env = "ohos"))`。

### 5.4 NativeTls → Rustls 替换

**错误**：`tokio_native_tls` unresolved，`openssl-sys` build failure。

**解决**：
1. Cargo.toml注释openssl和tokio-native-tls
2. reqwest features移除"native-tls"，保留"rustls-tls"
3. proxy.rs/websocket.rs中NativeTls分支替换为Rustls fallback调用

### 5.5 socket2 0.3 → 0.5 API变更

| 0.3 API | 0.5 API |
|---------|---------|
| `Domain::ipv4()` | `Domain::IPV4` |
| `Type::dgram()` | `Type::DGRAM` |
| `.into_udp_socket()` | `.into()` |
| `features = ["reuseport"]` | `features = ["all"]` |

### 5.6 harmony_bridge模块不存在

**错误**：`rustdesk_core::harmony_bridge` 找不到。

**原因**：rustdesk-master源码中缺少此模块，之前的129MB .a文件编译时存在。

**解决**：创建 `src/harmony_bridge/mod.rs` + `src/harmony_bridge/core.rs`，`mod.rs`必须 `pub use self::core::*;`，否则 `bridge_api.rs` 中的 `rustdesk_core::harmony_bridge::xxx` 找不到函数。

### 5.7 input_service.rs 逐函数cfg保护

此文件最复杂，使用enigo/Key/Enigo/MouseButton的函数需逐个添加cfg保护：

```rust
#[cfg(all(target_os = "linux", not(target_env = "ohos")))]
fn get_modifier_state(key: Key, en: &mut Enigo) -> bool { ... }

#[cfg(all(target_os = "linux", not(target_env = "ohos")))]
pub fn release_device_modifiers() { ... }

#[cfg(all(target_os = "linux", not(target_env = "ohos")))]
lazy_static::lazy_static! {
    static ref ENIGO: Arc<Mutex<Enigo>> = { ... };
    static ref LATEST_PEER_INPUT_CURSOR: ... = ...;
}
```

### 5.8 connection.rs err_msg变量作用域

**错误**：`err_msg` 在 `cfg(all(target_os = "linux", not(target_env = "ohos")))` 块内定义，块外使用。

**解决**：添加OHOS分支的默认值：
```rust
#[cfg(all(target_os = "linux", target_env = "ohos"))]
let err_msg = "".to_owned();
#[cfg(all(target_os = "linux", not(target_env = "ohos")))]
let err_msg = self.linux_headless_handle.try_start_desktop(...);
```

---

## 6. 当前编译状态

**2026-06-01结果**：Ubuntu release交叉编译已成功。

```text
Finished `release` profile [optimized] target(s) in 7m 59s
Native bridge artifact copied to .../target/harmony/librustdesk_harmony_bridge.a
```

**当前产物**：
- Ubuntu验证时会生成 `$RUSTDESK_HARMONY_BUILD_DIR/native_rust_core/target/aarch64-unknown-linux-ohos/release/librustdesk_harmony_bridge.a`
- 清理后当前保留 `$RUSTDESK_HARMONY_BUILD_DIR/native_rust_core/target/harmony/librustdesk_harmony_bridge.a`
- 当前Windows最新产物大小：132,262,622 bytes，SHA256 `27D91DB4EBC2BF7F51A501103D34050534A39727C8EA710F5C9BAB1133A6FB21`

**符号验证**：
- `rustdesk_bridge_get_peer_option` 存在
- `rustdesk_bridge_get_peer_info` 存在
- `rustdesk_bridge_initialize_runtime` 存在

**注意**：OHOS SDK自带 `llvm-nm` 是LLVM 15，而当前Rust stable对象由LLVM 22生成，扫描完整archive时会输出若干“Unknown attribute kind/Not an int attribute”警告；只要目标符号可检出，不影响本次staticlib生成。

完成了，Rust OHOS 交叉编译已经成功。

产物：/media/ubuntu/Data/Visual_Studio_Code/99_Temp/rustdesk_harmonyos_build/native_rust_core/target/harmony/librustdesk_harmony_bridge.a
大小：Ubuntu验证时约128M；当前清理后仅保留 harmony 拷贝路径，Windows最新产物为132,262,622 bytes。
修复：导出 harmony_bridge core API：/media/ubuntu/Data/Visual_Studio_Code/99_Temp/rustdesk-master/src/harmony_bridge/mod.rs:3
补齐：peer info/option 与尾部 bridge stub：/media/ubuntu/Data/Visual_Studio_Code/99_Temp/rustdesk-master/src/harmony_bridge/core.rs:162
修复：native bridge 不再访问被 cfg 掉的 ui_interface/hbb_common：rustdesk_harmonyos/native_rust_core/src/bridge_api.rs:324
构建结果：Finished release profile [optimized] target(s) in 7m 59s
验证：rustdesk_bridge_get_peer_option、rustdesk_bridge_get_peer_info、rustdesk_bridge_initialize_runtime 等符号已存在；llvm-nm 有 LLVM 版本 warning，但不影响本次产物生成。
完成了，项目现在干净不少，文档也同步到当前状态。

清理：项目根只剩 .codeartsdoer、.git 和 rustdesk_harmonyos；99_Temp 只保留 rustdesk-master 与 rustdesk_harmonyos_build，归档/备份/官方APK和可再生成缓存已删除。
同步：最新 Windows 产物 librustdesk_harmony_bridge.a 已复制为 rustdesk_harmonyos/entry/src/main/libs/arm64/librustdesk_core.a，SHA256 校验一致。
文档：8个 docs/*.md 已更新 Ubuntu/Windows 编译、清理结果、132,262,622 bytes staticlib、Rust ABI/C++ NAPI 当前差异。
关键状态：Rust C ABI 是46个函数，C++ NAPI 当前注册51个函数(含5个辅助函数)，abi.h声明46个extern函数，三层完全对齐。
主要更新点：rustdesk_harmonyos/docs/CORE.md、rustdesk_harmonyos/docs/PROGRESS.md、rustdesk_harmonyos/docs/FILES.md、rustdesk_harmonyos/docs/ISSUES.md、rustdesk_harmonyos/docs/SESSION3_SUMMARY.md。
---

## 7. 已修改文件清单

| 文件 | 修改类型 |
|------|---------|
| `rustdesk-master/Cargo.toml` | 依赖crate lib crate-type收敛为`["rlib"]`，避免无用X11 `.so` 链接 |
| `rustdesk-master/src/lib.rs` | 桌面模块cfg保护, 新增harmony_bridge |
| `rustdesk-master/src/harmony_bridge/mod.rs` | **新建** |
| `rustdesk-master/src/harmony_bridge/core.rs` | **新建/补齐** 45个core函数，含`get_peer_option/get_peer_info` |
| `rustdesk-master/src/platform/mod.rs` | OHOS WakeLock/Linux平台stub |
| `rustdesk-master/src/common.rs` | OHOS rendezvous/sound/username/hostname等fallback |
| `rustdesk-master/src/client.rs` | 桌面clipboard/audio/video/io_loop等OHOS cfg/fallback |
| `rustdesk-master/src/client/file_trait.rs` | 桌面/sciter接口OHOS排除 |
| `rustdesk-master/src/client/screenshot.rs` | clipboard更新OHOS排除 |
| `rustdesk-master/src/keyboard.rs` | Linux抓键/桌面输入OHOS排除 |
| `rustdesk-master/src/rendezvous_mediator.rs` | xdesktop启动OHOS排除 |
| `rustdesk-master/src/lan.rs` | OHOS ID分支避免调用cfg掉的ui_interface |
| `rustdesk-master/src/server/connection.rs` | camera/terminal/clipboard/peer info等OHOS cfg/fallback |
| `rustdesk-master/src/server/input_service.rs` | mouse/pointer/key OHOS no-op stub |
| `rustdesk-master/src/server/video_service.rs` | camera capturer OHOS排除/fallback |
| `rustdesk-master/src/ipc/auth.rs` | Linux peer auth函数OHOS stub |
| `rustdesk-master/src/hbbs_http/http_client.rs` | OHOS NativeTls分支改用Rustls |
| `rustdesk_harmonyos/native_rust_core/src/bridge_api.rs` | peer option/info改走`harmony_bridge`，不直接访问`ui_interface/hbb_common` |
| `rustdesk_harmonyos/scripts/build_native_bridge.sh` | pkg-config/RUSTFLAGS/LIBCLANG_PATH/SODIUM target-specific变量 |

---

## 8. 验证清单

- [x] `librustdesk_harmony_bridge.a` 文件大小 > 100MB (当前132,262,622 bytes)
- [x] `llvm-nm --defined-only librustdesk_harmony_bridge.a | grep rustdesk_bridge_get_peer_option` 有输出
- [x] `llvm-nm --defined-only librustdesk_harmony_bridge.a | grep rustdesk_bridge_get_peer_info` 有输出
- [ ] 所有原有符号均存在
- [x] .a复制到 `entry/src/main/libs/arm64/librustdesk_core.a`
- [ ] 使用当前Windows staticlib重新构建HAP并安装验证
- [ ] 安装到设备后，历史ID卡片能正确显示设备名称




### 备忘 Rust Bridge 导出函数完整列表 

| 函数名 | 签名 | 返回值 | 说明 |
|--------|------|--------|------|
| `rustdesk_bridge_initialize_runtime` | `(app_dir: *c_char, config: *c_char) → *c_char` | JSON string | 初始化运行时 |
| `rustdesk_bridge_get_core_snapshot` | `(server: *c_char) → *c_char` | JSON (见 BridgeSnapshot) | 获取核心状态快照 |
| `rustdesk_bridge_bootstrap_core_snapshot` | `(display_id, fingerprint, direct_addr, server: *c_char) → *c_char` | JSON string | 引导核心快照 |
| `rustdesk_bridge_pull_session_events` | `() → *c_char` | JSON array | 拉取会话事件 |
| `rustdesk_bridge_pull_audio_frames` | `() → *c_char` | JSON string | 拉取音频帧 |
| `rustdesk_bridge_get_latest_video_frame_metadata` | `(since_frame_id: u64) → *c_char` | JSON (见 VideoFrameMetadata) | 获取视频帧元数据 |
| `rustdesk_bridge_copy_latest_video_frame` | `(frame_id: u64, buffer: *mut u8, len: usize) → c_int` | 0/1 | 拷贝视频帧到缓冲区 |
| `rustdesk_bridge_refresh_session_video` | `(display: c_int) → c_int` | 0/1 | 刷新视频 |
| `rustdesk_bridge_harmony_next_rgba` | `(display: c_int)` | void | 获取下一帧RGBA |
| `rustdesk_bridge_connect_to_peer` | `(peer_id, password, server, relay, api: *c_char)` | void | 连接到对等端 |
| `rustdesk_bridge_close_session` | `()` | void | 关闭会话 |
| `rustdesk_bridge_get_local_option` | `(key: *c_char) → *c_char` | string | 获取本地选项 |
| `rustdesk_bridge_set_local_option` | `(key, value: *c_char)` | void | 设置本地选项 |
| `rustdesk_bridge_get_session_toggle_option` | `(key: *c_char) → c_int` | 0/1 | 获取会话开关选项 |
| `rustdesk_bridge_apply_session_option` | `(key, value: *c_char) → c_int` | 0/1 | 应用会话选项 |
| **`rustdesk_bridge_get_peer_option`** | **`(peer_id, key: *c_char) → *c_char`** | **string** | **获取对等端选项（新增）** |
| **`rustdesk_bridge_get_peer_info`** | **`(peer_id: *c_char) → *c_char`** | **JSON (见 PeerInfo)** | **获取对等端信息（新增）** |
| `rustdesk_bridge_set_incoming_service_enabled` | `(enabled: c_int, server, relay, api: *c_char) → *c_char` | JSON string | 设置入站服务 |
| `rustdesk_bridge_account_auth` | `(op: *c_char, remember: c_int, server, relay, api: *c_char)` | void | 账号认证 |
| `rustdesk_bridge_account_auth_cancel` | `()` | void | 取消认证 |
| `rustdesk_bridge_account_auth_result` | `() → *c_char` | JSON string | 获取认证结果 |
| `rustdesk_bridge_send_mouse_input` | `(mask, x, y: c_int) → c_int` | 0/1 | 发送鼠标输入 |
| `rustdesk_bridge_send_keyboard_input` | `(key_code, is_pressed, modifiers: c_int) → c_int` | 0/1 | 发送键盘输入 |
| `rustdesk_bridge_send_clipboard_data` | `(content: *c_char, timestamp: i64) → c_int` | 0/1 | 发送剪贴板 |
| `rustdesk_bridge_send_video_frame_metadata` | `(codec, w, h: c_int, ts: i64, key_frame, data_len: c_int) → c_int` | 0/1 | 发送视频帧元数据 |
| `rustdesk_bridge_send_audio_frame_metadata` | `(codec, sample_rate, channels: c_int, ts: i64, data_len: c_int) → c_int` | 0/1 | 发送音频帧元数据 |
| `rustdesk_bridge_send_chat_message` | `(peer_id, msg_type, content: *c_char, ts: i64) → c_int` | 0/1 | 发送聊天消息 |
| `rustdesk_bridge_send_file_transfer_request` | `(task_id, peer_id, file_name: *c_char, total: i64, dir: *c_char) → c_int` | 0/1 | 请求文件传输 |
| `rustdesk_bridge_mark_session_connected` | `(peer_id: *c_char)` | void | 标记会话已连接 |
| `rustdesk_bridge_mark_session_error` | `(message: *c_char)` | void | 标记会话错误 |
| `rustdesk_bridge_submit_session_password` | `(password: *c_char, remember: c_int) → c_int` | 0/1 | 提交会话密码 |
| `rustdesk_bridge_restart_remote_device` | `() → c_int` | 0/1 | 重启远程设备 |
| `rustdesk_bridge_lock_remote_screen` | `() → c_int` | 0/1 | 锁定远程屏幕 |
| `rustdesk_bridge_open_terminal` | `(id, rows, cols: c_int) → c_int` | 0/1 | 打开终端 |
| `rustdesk_bridge_send_terminal_input` | `(id: c_int, data: *c_char) → c_int` | 0/1 | 发送终端输入 |
| `rustdesk_bridge_resize_terminal` | `(id, rows, cols: c_int) → c_int` | 0/1 | 调整终端大小 |
| `rustdesk_bridge_close_terminal` | `(id: c_int) → c_int` | 0/1 | 关闭终端 |
| `rustdesk_bridge_read_remote_directory` | `(path: *c_char, include_hidden: c_int) → c_int` | 0/1 | 读取远程目录 |
| `rustdesk_bridge_create_remote_directory` | `(path: *c_char) → c_int` | 0/1 | 创建远程目录 |
| `rustdesk_bridge_delete_remote_path` | `(path: *c_char, is_dir: c_int) → c_int` | 0/1 | 删除远程路径 |
| `rustdesk_bridge_start_file_transfer` | `(path, to: *c_char, is_remote: c_int) → c_int` | 0/1 | 开始文件传输 |
| `rustdesk_bridge_query_onlines` | `(ids_json: *c_char) → c_int` | 0/1 | 查询在线状态 |
| `rustdesk_bridge_discover_lan_peers` | `()` | void | 发现局域网对等端 |
| `rustdesk_bridge_load_lan_peers` | `() → *c_char` | JSON string | 加载局域网对等端 |
| `rustdesk_bridge_remove_discovered_peer` | `(peer_id: *c_char) → c_int` | 0/1 | 移除发现的对等端 |
| `rustdesk_bridge_string_free` | `(value: *c_char)` | void | 释放C字符串内存 |
