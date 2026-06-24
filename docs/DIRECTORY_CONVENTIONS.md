# 项目目录规范手册

> 从 WORKSPACE_PATHS.md、AGENT_MEMORY.md、ISSUES.md 等所有文档中提取的目录规范汇总。
> 整理项目时以此文档为唯一依据，逐项对照执行。

---

## 1. 根目录定义

| 变量 | 当前值 | 说明 |
|---|---|---|
| `%VSCODE_ROOT%` | 项目启动时设定（如 `E:\Visual_Studio_Code`） | 包含 App、Core 和 99_Temp 的工作区根 |
| `%VSCODE_ROOT%\99_Temp` | 唯一构建/测试/缓存/备份/临时证据根 | 多项目共享，禁止整体删除或全局清理 |

---

## 2. 三大仓库职责

| 路径 | 职责 | 禁止 |
|---|---|---|
| `%VSCODE_ROOT%\11_Rustdesk_harmonyos` | App 源码、文档、脚本、必须纳入仓库的资源 | 不放构建缓存、HDC dump、截图、临时 JSON |
| `%VSCODE_ROOT%\13_librustdesk_core` | Core 源码、补丁、脚本、CI、文档 | 不放 Cargo target、下载缓存、打包副本 |
| `%VSCODE_ROOT%\99_Temp` | 所有本地构建、验包、HDC 日志、artifact inspect、备份 | 不放源码；不整体删除；不删除任何 `*.apk` |

---

## 3. App 仓库目录规范

### 3.1 必须保留的目录/文件

| 路径 | 说明 |
|---|---|
| `13_librustdesk_core/` | NTFS junction → `%VSCODE_ROOT%\13_librustdesk_core`，仅用于浏览源码 |
| `entry/src/main/libs/arm64/librustdesk_core.a` | arm64 核心静态库（从 GitHub Releases 下载） |
| `entry/src/main/libs/x86_64/librustdesk_core.a` | x86_64 核心静态库 |
| `local.properties` | SDK 路径配置 |
| `signing/` | 构建脚本复制到 staging 用的签名材料副本 |
| `docs/` | 项目文档 |
| `scripts/` | 构建脚本 |
| `reports/` | Markdown 审计报告（只保留有审计价值的 .md） |
| `AppScope/` | 应用配置 |
| `hvigor/` | Hvigor 配置 |
| `entry/` | 模块源码 |
| `.github/` | CI workflow |

### 3.2 交接前必须删除的目录/文件

| 路径 | 原因 |
|---|---|
| `.codeartsdoer/` | IDE 工具缓存，自动重建 |
| `.hvigor/` | Hvigor 运行时缓存，自动重建 |
| `.idea/` | IDE 配置缓存，自动重建 |
| `.appanalyzer/` | 应用分析缓存 |
| `entry/.cxx/` | CMake/Ninja 中间目录 |
| `entry/oh_modules/` | OH 包管理缓存 |
| `oh_modules/` | 根级 OH 包管理缓存 |
| `.codex_*` | 旧版 AI 探针/布局 JSON |
| `entry/build/` | Hvigor 构建输出（应重定向到 99_Temp） |
| `system_optimization_backup/` | 系统优化备份残留 |
| `check_i18n.py`、`check_result.txt` | 旧检查脚本残留 |
| `entry/src/main/cpp/undefined_symbols.txt` | 旧诊断残留 |

### 3.3 App 核心文件路径

| 文件 | 路径 |
|---|---|
| 主页面 | `entry/src/main/ets/pages/Index.ets` |
| 远程控制 | `entry/src/main/ets/pages/RemoteControl.ets` |
| 国际化 | `entry/src/main/ets/services/I18nService.ets` |
| NAPI 桥接 | `entry/src/main/ets/services/NativeRustDeskBridge.ts` |
| 数据管理 | `entry/src/main/ets/services/AppDataService.ets` |
| C++ 桥接 | `entry/src/main/cpp/`（从核心项目同步） |

---

## 4. Core 仓库目录规范

### 4.1 必须保留的目录/文件

| 路径 | 说明 |
|---|---|
| `entry/` | 静态库副本 |
| `rdev-fork/` | OHOS 输入 fork 源码 |
| `rustdesk-master/src/version.rs` | 生成版本文件 |
| `rustdesk-master/src/harmony_bridge/` | OHOS 桥接层（core.rs/server_ohos.rs 等） |
| `cpp/` | C++ 桥接层 |
| `native_rust_core/src/bridge_api.rs` | 374 导出函数 |
| `patches/` | 补丁 |
| `scripts/` | 构建脚本 |
| `docs/` | 核心文档 |
| `.github/` | CI workflow |

### 4.2 交接前必须删除的目录/文件

| 路径 | 原因 |
|---|---|
| `rustdesk-master/target/` | Cargo 构建输出，必须重定向到 99_Temp |
| `native_rust_core/target/` | Cargo 构建输出 |
| `.codeartsdoer/` | IDE 工具缓存 |
| `native_rust_core/.cargo/` | Cargo 本地配置缓存 |
| 根目录 `build_debug_*` / `build_env_*` / `cargo_build_*` | 旧构建日志 |

---

## 5. 99_Temp 子目录规范

### 5.1 子目录职责与清理规则

| 子目录 | 用途 | 清理规则 |
|---|---|---|
| `harmonyos_build\11_Rustdesk_harmonyos` | Hvigor/HAP 输出 | 保留 signed HAP；intermediates/cache/generated/.cxx/unsigned HAP/mapping/pack.info 可删 |
| `harmonyos_stage\11_Rustdesk_harmonyos` | 构建前 staged copy | 构建完成后可删除整个项目子目录 |
| `harmonyos_cache` | Hvigor/DevEco 缓存 | 默认保留；仅排查缓存污染时清理 |
| `librustdesk_core` | Core 产物/下载/构建统一根 | 可清理下载缓存；不误删正在被 App 引用的 `.a` |
| `librustdesk_core\cargo_target` | Core 本地 Cargo target | 可删除重建；不放 App 仓库根 |
| `librustdesk_core\build_cache` | Core 本地依赖构建缓存 | 可删除重建 |
| `librustdesk_core\build_logs` | Core 本地构建日志 | 只保留最近有效日志 |
| `rustdesk_harmonyos_build` | SDK/HMS/DevEco/vcpkg/external-src/tools/toolchains/patches 依赖镜像 | 只保留依赖镜像和工具链；不一键删除 |
| `rustdesk_harmonyos_signing` | 便携签名材料 | **必须保留**；不得散落复制到其他目录 |
| `rustdesk_harmonyos_backups` | App 仓库 zip 备份 | 只保留最新 2 份及 `.sha256` |
| `rustdesk_core_backups` | Core 仓库 zip 备份 | 只保留最新 2 份及 `.sha256` |
| `rustdesk_harmonyos_test_logs` | 运行时测试日志/hilog/HDC 输出 | 可保留脱敏最新证据；不得保存一次性密码 |
| `rustdesk_harmonyos_device_validation` | 真机截图/交互临时证据 | 确认文档已记录后可删除；严禁保留一次性密码截图 |
| `release_inspect\11_Rustdesk_harmonyos` | 线上资产下载和哈希复验 | 保留到发布记录完成 |
| `release_inspect\13_librustdesk_core` | 线上 Core 资产复验 | 保留到发布记录完成 |
| `harmonyos_artifacts\11_Rustdesk_harmonyos` | GitHub HAP artifact 暂存 | 可删除重建 |
| `hap_inspect` / `release_inspect` | HAP/Release 解包检查临时目录 | 可删除重建 |

### 5.2 99_Temp 根目录禁止散落文件

以下文件不应出现在 99_Temp 根目录（历史残留，应删除）：
- `build_log*.txt` / `hap_build_log.txt` — 旧构建日志
- `cert_temp.cer` / `verify_cert_chain.cer` / `verify_profile.p7b` — 临时签名验证文件
- `old_profile.json` — 旧 profile
- `sign_debug.bat` / `sign_hap.bat` / `sign_hap2.bat` — 旧签名脚本
- `msys2-base-x86_64-*.sfx.exe` — MSYS2 安装包
- `test_hap/` — 调试签名工具残留

### 5.3 harmonyos_build 内部清理规则

**保留**：
- `entry/build/default/outputs/default/entry-default-signed.hap` — 最终签名 HAP

**可删除**（构建可再生）：
- `entry/build/default/intermediates/` — 编译中间产物
- `entry/build/default/cache/` — 编译缓存
- `entry/.cxx/` — CMake/Ninja 中间目录
- `build/` — App 级缓存
- `entry/build/default/outputs/default/entry-default-unsigned.hap` — 未签名 HAP
- `entry/build/default/outputs/default/mapping/` — source map
- `entry/build/default/outputs/default/pack.info` — 打包信息

---

## 6. 废弃路径（必须保持不存在）

| 路径 | 说明 |
|---|---|
| `<废弃盘符根临时目录>` / `\99_Temp` | 废弃的盘符根临时目录，不再写入 |
| `C:\99_Temp` | 废弃，不用于本项目 |
| `%VSCODE_ROOT%\_tmp_rustdesk_1_4_7_src` | 已删除的官方 1.4.7 tag 临时 clone |
| `%TEMP%\rustdesk_*` / `%TEMP%\rundesk_*` / `%TEMP%\accessibility_*` | 一次性截图/布局探针，测试结束立即删除 |
| `99_Temp\backups` | 废弃的通用备份目录 |
| `99_Temp\rustdesk_harmonyos_build\native_rust_core\target` | 旧 Core target |
| `99_Temp\rustdesk_harmonyos_build\windows_hap` | 旧 HAP 副本 |
| `99_Temp\rustdesk_harmonyos_build\rustdesk-1.4.7-clone` | 旧官方 clone |

---

## 7. 签名文件规范

| 项目 | 规范 |
|---|---|
| 签名材料目录 | `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_signing\` |
| build-profile.json5 引用名 | `debug_hos.cer` / `debug_hos.p12` / `debug_hos.p7b`（相对路径 `../99_Temp/rustdesk_harmonyos_signing/`） |
| p12 实际 keyAlias | `rustdesk_debug`（用 `keytool -list` 查看） |
| p12 密码 | `123456` |
| material 目录 | `signing/material/`（含 ac/ce/fd 子目录，用于 DevEco 密码加密） |
| 签名验证脚本 | `scripts\check_harmony_signing_profile.ps1` |
| 密码验证脚本 | `node scripts\export_deveco_signing_command.js --show-secrets` |
| 手动签名命令 | `java -jar hap-sign-tool.jar sign-app -keyAlias rustdesk_debug -keyPwd 123456 -keystoreFile debug_hos.p12 -keystorePwd 123456 -appCertFile debug_hos.cer -profileFile debug_hos.p7b -inFile unsigned.hap -outFile signed.hap -signAlg SHA256withECDSA -mode localSign` |

**签名经验**：
- 环境迁移后必须检查三项：文件名匹配、keyAlias 匹配、密码加密匹配
- Hvigor SignHap 失败但 PackageHap 成功时，unsigned HAP 已生成，可用 `hap-sign-tool.jar` 手动签名绕过
- 密码加密使用 DevEco 特有的 PBKDF2+XOR+双层 AES-128-GCM 格式，自定义脚本必须匹配 Hvigor 的 `DecipherUtil` 逻辑

---

## 8. 环境变量规范

```powershell
$env:VSCODE_ROOT = 'E:\Visual_Studio_Code'    # 工作区根，按实际位置设定
$env:RUSTDESK_HARMONY_TEMP_ROOT = "$env:VSCODE_ROOT\99_Temp"
$env:RUSTDESK_HARMONY_BUILD_DIR = "$env:VSCODE_ROOT\99_Temp\harmonyos_build"
$env:BUILD_CACHE_DIR = "$env:VSCODE_ROOT\99_Temp\harmonyos_cache"
$env:CARGO_TARGET_DIR = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\cargo_target"
$env:RUSTDESK_CORE_BUILD_CACHE = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\build_cache"
$env:RUSTDESK_CORE_BUILD_LOG_DIR = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\build_logs"
$env:JAVA_HOME = 'C:\Program Files\Huawei\DevEco Studio\jbr'  # 即 %DEVECO_HOME%\jbr
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk\default'  # 即 %DEVECO_HOME%\sdk\default
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

**禁止引入**：`<废弃盘符根临时目录>`、仓库内 `.codex_*`、个人临时习惯路径。

---

## 9. 核心项目路径规范

| 项目 | 路径 | 说明 |
|---|---|---|
| Core 仓库 | `%VSCODE_ROOT%\13_librustdesk_core` | 真实路径，核心构建必须从此启动 |
| App 内 junction | `11_Rustdesk_harmonyos\13_librustdesk_core` | NTFS junction，仅用于浏览，不能用于构建 |
| Rust 桥接层 | `13_librustdesk_core/rustdesk-master/src/harmony_bridge/core.rs` | 1500+ pub fn |
| Rust ABI | `13_librustdesk_core/native_rust_core/src/bridge_api.rs` | 374 导出函数 |
| C++ 桥接 | `13_librustdesk_core/cpp/rustdesk_bridge_loader.cpp` | ~400 NAPI 注册 |
| C++ ABI 声明 | `13_librustdesk_core/cpp/rustdesk_bridge_abi.h` | |
| TS 类型 | `13_librustdesk_core/cpp/types/librustdesk_bridge/index.d.ts` | |

**关键规则**：
- 核心构建必须从真实 `%VSCODE_ROOT%\13_librustdesk_core` 路径启动，不能从 App 内 junction 路径
- `stage_project_for_build.ps1` 必须排除 `13_librustdesk_core` 并使用 robocopy `/XJ`
- `backup_project.ps1` 也必须排除 `13_librustdesk_core` 并使用 robocopy `/XJ`

---

## 10. 构建脚本规范

| 脚本 | 用途 |
|---|---|
| `scripts\build_hap.bat` | 增量构建 HAP |
| `scripts\build_full_hap.bat` | 全量构建 HAP |
| `scripts\AUTO_BUILD_INSTALL.bat auto` | 一键构建安装 |
| `scripts\backup_project.ps1` | 项目备份 |
| `scripts\verify_native_harmonyos_hap.ps1` | HAP 验包 |
| `scripts\audit_connection_chain.ps1` | 连接链路审计 |
| `scripts\fetch_native_core.ps1` | 下载线上核心 |
| `scripts\build_harmonyos_hap.ps1` | PowerShell HAP 构建脚本 |
| `scripts\stage_project_for_build.ps1` | 构建 staging 副本 |
| `scripts\switch_deveco_paths.ps1` | 签名路径切换（DevEco/Portable） |
| `scripts\export_deveco_signing_command.js` | 签名命令导出/密码验证 |

**规则**：
- 构建安装必须全部用脚本（bat/ps1），不要手动拼接 hdc 命令
- HDC 路径拼接有 bug，安装 HAP 需从 HAP 所在目录执行或用相对路径
- `hdc list targets` 输出 `[Empty]` 不是设备，脚本必须过滤
- HDC 服务钝化时需 `hdc kill` + `hdc start` 重启

---

## 11. 验证和证据规则

- 判断 HAP 新旧不能只看 `versionName`，必须同时记录 HAP SHA256/mtime、设备 `bm dump updateTime`、BuildInfo、CoreBuildInfo、hilog 特征
- `reports/` 只保留 Markdown 审计报告，大批量 JSON/XML/PNG/JPEG 应删除或转移到 `99_Temp\rustdesk_harmonyos_test_logs`
- 备份只用 `scripts\backup_project.ps1` 生成，目录固定为 `rustdesk_harmonyos_backups` 与 `rustdesk_core_backups`，禁止 `99_Temp\backups`、`project_backup_*`、`backup2` 等散落目录
- 一次性密码只允许在测试脚本内存中使用，永不写入源码、日志、文档、截图、备份说明或提交说明
- 99_Temp 是多项目共享根，**任何 `*.apk` 都不得删除**，清理前必须确认目标位于本项目专属子目录内

---

## 12. 清理检查清单

整理项目时逐项对照：

### App 仓库
- [ ] `.codeartsdoer/` 已删除
- [ ] `.hvigor/` 已删除
- [ ] `.idea/` 已删除
- [ ] `entry/.cxx/` 已删除
- [ ] `entry/oh_modules/` 已删除
- [ ] `oh_modules/` 已删除
- [ ] `.codex_*` 已删除
- [ ] `entry/build/` 不存在（构建输出在 99_Temp）
- [ ] `13_librustdesk_core/` junction 存在
- [ ] `entry/src/main/libs/arm64/librustdesk_core.a` 存在
- [ ] `local.properties` 存在
- [ ] `signing/` 存在

### Core 仓库
- [ ] `rustdesk-master/target/` 不存在
- [ ] `native_rust_core/target/` 不存在
- [ ] `.codeartsdoer/` 已删除
- [ ] `native_rust_core/.cargo/` 已删除
- [ ] 根目录无 `build_debug_*`/`build_env_*`/`cargo_build_*` 日志
- [ ] `entry/` 存在
- [ ] `rdev-fork/` 存在
- [ ] `rustdesk-master/src/version.rs` 存在

### 99_Temp
- [ ] 根目录无散落文件（build_log*.txt、sign_*.bat、cert_temp.cer 等）
- [ ] `harmonyos_stage/` 已删除（或构建后可删）
- [ ] `harmonyos_build` 中只保留 signed HAP（intermediates/cache/.cxx/unsigned/mapping/pack.info 已删）
- [ ] `rustdesk_harmonyos_signing/` 保留完整
- [ ] `rustdesk_harmonyos_backups/` 最多 2 份
- [ ] `rustdesk_core_backups/` 最多 2 份
- [ ] 无 `99_Temp\backups` 散落目录
- [ ] 无 `windows_hap` 目录
- [ ] 无 `test_hap` 目录

### 废弃路径
- [ ] `<废弃盘符根临时目录>` 不存在
- [ ] `C:\99_Temp` 不存在
- [ ] `%VSCODE_ROOT%\_tmp_rustdesk_1_4_7_src` 不存在
- [ ] `%TEMP%\rustdesk_*` / `%TEMP%\rundesk_*` / `%TEMP%\accessibility_*` 不存在

---

> 文档来源：WORKSPACE_PATHS.md、AGENT_MEMORY.md、ISSUES.md、CORE.md、PROGRESS.md
> 生成时间：2026-06-23
