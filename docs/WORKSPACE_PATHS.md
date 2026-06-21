# 工作区路径与构建测试规范

> 更新时间：2026-06-21 17:01（Europe/Berlin）  
> 最终规范复核：2026-06-21 23:41（Europe/Berlin）  

## 2026-06-21 23:41 强制统一规则

`F:\Visual_Studio_Code\99_Temp` 是多个项目共享的临时根目录，不是 RustDesk 专属目录，绝对禁止整体删除、整体移动或按扩展名全局清理。任何位置的 `*.apk` 都必须保留，本项目清理不得触碰 APK。清理前必须把目标解析为绝对路径并确认它位于下面列出的 RustDesk 项目专属子目录内；只删除明确可再生的 stage/cache/log/test evidence，不删除最终 HAP、Release 下载、备份或其他项目文件。

固定职责：

- `11_Rustdesk_harmonyos`：App 源码、脚本、项目文档和提交内容，不放构建缓存或测试截图。
- `13_librustdesk_core`：Core 源码、桥接层、脚本和项目文档，不放 Cargo target、下载缓存或打包副本。
- `99_Temp\harmonyos_build\11_Rustdesk_harmonyos`：App/Hvigor 正式构建树；最终签名 HAP 固定在 `entry\build\default\outputs\default`，发布前保留。
- `99_Temp\harmonyos_stage\11_Rustdesk_harmonyos`：可再生的 Hvigor stage，构建完成后可精准删除整个项目子目录。
- `99_Temp\librustdesk_core`：Core target、工具缓存和 Core 构建临时内容；按明确子目录清理，不能连带其他项目。
- `99_Temp\rustdesk_harmonyos_device_validation`：本项目真机截图/交互临时证据；确认文档已记录无隐私结论后可删除。严禁保留一次性密码截图。
- `99_Temp\release_inspect\11_Rustdesk_harmonyos` 与 `...\13_librustdesk_core`：线上资产下载和哈希复验，保留到发布记录完成。
- `99_Temp\rustdesk_harmonyos_backups`、`99_Temp\rustdesk_core_backups`：两个仓库各自备份目录，各仅保留最新 2 份完整备份和校验文件；不要再创建通用 `99_Temp\backups`。
- 工作区根 `_tmp_rustdesk_1_4_7_src`：历史上为 RustDesk 1.4.7 上游源包的临时解压/对照树，不是第三仓库，也不是构建输入；完成差异确认后应删除，不能继续作为源码来源。

测试节奏统一为 100 轮：每 5 轮做一次增量审计和文档检查点，每 10 轮做一次全量审计/构建检查点；第 100 轮后冻结最终 HAP 哈希，再对同一哈希完成签名、双 ABI、BuildInfo/CoreBuildInfo、安装 updateTime、hilog 和连接链复验。若任何功能源码、资源、构建配置或 Core 变更，必须产生新 BuildInfo 和新哈希，并重新执行最终固定哈希证据链。一次性密码只允许存在测试运行内存，永不写入源码、日志、文档、截图、备份说明或提交说明。
> 本文是当前项目的路径权威说明。后续换电脑、换盘符或换人接手时，先按本文统一目录，不再各自新建临时根目录。

## 当前权威根目录

`%VSCODE_ROOT%` 表示包含 App、Core 和统一临时目录的工作区根目录。当前机器上它是：

```text
F:\Visual_Studio_Code
```

| 路径 | 用途 | 规则 |
| --- | --- | --- |
| `%VSCODE_ROOT%\11_Rustdesk_harmonyos` | HarmonyOS App 仓库 | 只放源码、文档、脚本和必须纳入仓库的资源。不要把构建缓存、HDC dump、截图、临时 JSON 放在这里。 |
| `%VSCODE_ROOT%\13_librustdesk_core` | RustDesk native core 仓库 | 只放 Core 源码、补丁、脚本、CI 和文档。Core 构建输出必须重定向到 `%VSCODE_ROOT%\99_Temp`。 |
| `%VSCODE_ROOT%\99_Temp` | 唯一构建、测试、缓存、备份和临时证据根目录 | 所有本地构建、验包、HDC 临时日志、GitHub artifact inspect、备份都放这里。 |

当前明确废弃并应保持不存在/空置的路径：

| 路径 | 状态 |
| --- | --- |
| `F:\99_Temp` / `\99_Temp` | 废弃的盘符根临时目录。不要再写入；若脚本或手工命令生成，应迁移有效内容后删除。 |
| `C:\99_Temp` | 废弃。不要用于本项目。 |
| `%VSCODE_ROOT%\_tmp_rustdesk_1_4_7_src` | 已删除的官方 RustDesk `1.4.7` tag 临时 clone。它只是上游参考副本，不是当前 Core 改造源码；不要重建到工作区根。 |
| App 仓库内 `.codex_*`、`.hvigor/`、`entry/build/`、`entry/.cxx/` | 只允许短时诊断/工具缓存；交接前必须删除或移到 `%VSCODE_ROOT%\99_Temp`。 |
| `%TEMP%\rustdesk_*`、`%TEMP%\rundesk_*`、`%TEMP%\accessibility_*` | 只允许一次性截图/布局探针；测试结束立即删除，尤其不能保留包含一次性密码或用户隐私画面的截图。 |

## 2026-06-21 清理结果

- App 仓库根 `.codex_*` 临时 JSON、Core/Hvigor 构建缓存和临时 HAP 输出已清理；当前最新 HAP/Core 产物已迁移到本文规定的 `99_Temp` 标准路径。
- `reports/` 已收敛为 Markdown 审计报告：`connection_chain_audit_latest.md`、`full_function_audit_latest.md`。旧 PNG/JPEG/JSON/XML 设备探针和截图已删除。
- 废弃目录 `F:\99_Temp`、旧散落备份 `F:\Visual_Studio_Code\99_Temp\backups`、`harmonyos_stage` 和旧 root 日志/截图/验证目录已删除。
- `%TEMP%` 下 RustDesk/Rundesk 截图、布局 JSON、HAP 签名解包临时目录和临时 Core build cache 已删除；保留的 0-byte `*.rustdesk` 文件是 RustDesk 运行态 marker，不作为项目证据。
- 16:26 二次清理已完成：删除 `%VSCODE_ROOT%\_tmp_rustdesk_1_4_7_src`（官方 `1.4.7` 干净临时 clone）、`99_Temp\rustdesk_harmonyos_build\native_rust_core\target`、`99_Temp\rustdesk_harmonyos_build\windows_hap`、`99_Temp\rustdesk_harmonyos_build\rustdesk-1.4.7-clone`、旧 downloads/build、当前 HAP build 的 `intermediates/cache/generated`。
- App 仓库二次清理已完成：删除 `.codeartsdoer/`、`.idea/`、`.hvigor/`、`oh_modules/`、`entry/oh_modules/`、`check_i18n.py`、`check_result.txt`、`entry/src/main/cpp/undefined_symbols.txt`。当前 App ignored 保留项只应是 `13_librustdesk_core/` junction、`entry/src/main/libs/` native core 副本、`local.properties` 和 `signing/`。
- Core 仓库二次清理已完成：删除 `.codeartsdoer/`、`rustdesk-master/target/`、`native_rust_core/target/` 和根目录 `build_debug_*` / `build_env_*` / `cargo_build_*` 日志。当前 Core ignored 保留项只应是 `entry/` 静态库副本、`rdev-fork/` OHOS 输入 fork 源码、`rustdesk-master/src/version.rs` 生成版本文件。
- 2026-06-21 17:01 最终核验：工具重新生成的 App `.codeartsdoer/` 已再次删除；Core `rustdesk-master/libs/rdev/` 经确认只有空目录 `.github/` 与 `src/`，已删除。当前 ignored 边界仍按上一条执行，不把空目录壳作为保留项。
- 2026-06-21 23:41 最终白名单清理：两次清理合计释放 `1,348,092,177` bytes；删除本项目 `harmonyos_stage\11_Rustdesk_harmonyos`、Hvigor `intermediates/cache/generated`、两组旧 `windows_hap`、真机临时截图/布局、空 test logs 和残留 `.tmp`。`rustdesk_harmonyos_build` 中的 OHOS/HMS/DevEco SDK、vcpkg、external-src、tools、toolchains、patches 是可复现构建依赖，保留。共享目录 3 个 APK 的数量、大小和 SHA256 清理前后完全一致。

当前保留的关键产物：

| 产物 | 路径 | SHA256 |
| --- | --- | --- |
| 最新 signed HAP | `%VSCODE_ROOT%\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap` (`34,284,688` bytes, BuildInfo `0.33.6 / 2026-06-21 23:46`, phone-installed) | `1D5C7395753D4E8F143FA051E0E931CCFB6C48FFEDA03A8DF91282DD007EC8D2` |
| arm64 Core archive | `%VSCODE_ROOT%\99_Temp\librustdesk_core\cargo_target\aarch64-unknown-linux-ohos\release\librustdesk_harmony_bridge.a` | `E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D` |
| x86_64 Core archive | `%VSCODE_ROOT%\99_Temp\librustdesk_core\cargo_target\x86_64-unknown-linux-ohos\release\librustdesk_harmony_bridge.a` | `DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD` |
| App 清理后备份 | `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_backups\rustdesk_harmonyos_20260621_235131.zip` (`1,434,138` bytes) | `CBD47DA1E03A54CF0EAB5FF47E1C18EF7BC6D17C7D8FE0BC244C4F589739F40A` |
| Core 清理后备份 | `%VSCODE_ROOT%\99_Temp\rustdesk_core_backups\rustdesk_core_20260621_235131.zip` (`3,592,925` bytes) | `E2CFF8937F62325BF7A8AD0081935D3347F9B62192E5490F52FAEB552D09875B` |

当前 `%VSCODE_ROOT%\99_Temp` 中本项目保留以下目录（2026-06-21 23:41 实测；同级 TabSSH 目录和全部 APK 属于共享根其他保留内容，不列入本项目清单）：

| 子目录 | 大小 | 保留原因 |
| --- | ---: | --- |
| `rustdesk_harmonyos_build` | `6165.37 MB` | 仅保留 SDK/HMS/DevEco/vcpkg/external-src/tools/toolchains/patches 等依赖镜像和工具链；旧 target/HAP/clone/log 已删除。 |
| `librustdesk_core` | `268.15 MB` | 当前标准双架构 Core 产物和 manifest。 |
| `harmonyos_build` | `70.77 MB` | 当前标准 signed HAP 输出，只保留 outputs 等必要内容。 |
| `rustdesk_harmonyos_backups` | `2.72 MB` | App 最新 2 份备份及 `.sha256`。 |
| `harmonyos_cache` | `9.29 MB` | Hvigor/DevEco 缓存，可按需重建。 |
| `rustdesk_core_backups` | `6.85 MB` | Core 最新 2 份备份及 `.sha256`。 |
| `rustdesk_harmonyos_signing` | `0.02 MB` | 便携签名材料，必须保留。 |

## `%VSCODE_ROOT%\99_Temp` 子目录职责

| 子目录 | 用途 | 清理规则 |
| --- | --- | --- |
| `harmonyos_stage\11_Rustdesk_harmonyos` | HAP 构建前的干净 staged copy | 可删除，脚本会重新生成。 |
| `harmonyos_build\11_Rustdesk_harmonyos` | Hvigor/HAP 输出目录 | 可删除重建；保留当前正在验证的 signed HAP，交接文档必须写明 SHA256。 |
| `harmonyos_cache` | Hvigor/DevEco 缓存 | 默认保留；只有排查缓存污染时才清。 |
| `harmonyos_artifacts\11_Rustdesk_harmonyos` | GitHub/self-hosted HAP artifact 暂存 | 可删除重建。 |
| `hap_inspect` / `release_inspect` | HAP/Release 解包检查临时目录 | 可删除重建。 |
| `librustdesk_core` | Core release 下载、解压和本地 Core 构建统一根 | 可清理下载缓存；不要误删正在被 App 引用的最终 `.a` 副本。 |
| `librustdesk_core\cargo_target` | Core 本地 Cargo target | 可删除重建；不要放在 App 仓库根。 |
| `librustdesk_core\build_cache` | Core 本地依赖构建缓存 | 可删除重建。 |
| `librustdesk_core\build_logs` | Core 本地构建日志 | 只保留最近有效日志；旧日志写入文档后可删。 |
| `rustdesk_harmonyos_build` | 历史/辅助 Native 依赖仓库：SDK/HMS/DevEco mirror、vcpkg、外部源码、tools、toolchains、patches | 只保留依赖镜像和工具链。旧 `native_rust_core\target`、`windows_hap`、`rustdesk-1.4.7-clone`、downloads/build、日志和临时命令已删除；不要一键删除整目录，除非确认 SDK/依赖可完整重新拉取。 |
| `rustdesk_harmonyos_signing` | 便携签名材料 | 必须保留；不得散落复制到其他目录。 |
| `rustdesk_harmonyos_backups` | App 仓库 zip 备份 | 只保留最新 2 份及 `.sha256`。 |
| `rustdesk_core_backups` | Core 仓库 zip 备份 | 只保留最新 2 份及 `.sha256`。 |
| `rustdesk_harmonyos_test_logs` | 运行时测试日志、hilog、HDC 输出 | 可保留经脱敏的最新证据；不得保存一次性密码。 |

## 构建/测试统一环境变量

本地手工构建或验证前先统一设置这些变量，避免脚本落回项目根或盘符根：

```powershell
$env:VSCODE_ROOT = 'F:\Visual_Studio_Code'
$env:RUSTDESK_HARMONY_TEMP_ROOT = "$env:VSCODE_ROOT\99_Temp"
$env:RUSTDESK_HARMONY_BUILD_DIR = "$env:VSCODE_ROOT\99_Temp\harmonyos_build"
$env:BUILD_CACHE_DIR = "$env:VSCODE_ROOT\99_Temp\harmonyos_cache"

$env:CARGO_TARGET_DIR = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\cargo_target"
$env:RUSTDESK_CORE_BUILD_CACHE = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\build_cache"
$env:RUSTDESK_CORE_BUILD_LOG_DIR = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\build_logs"
```

如果脚本已有同类变量，以本文路径为准。新脚本必须默认写入 `%VSCODE_ROOT%\99_Temp`，不能再引入 `F:\99_Temp`、仓库内 `.codex_*` 或个人临时习惯路径。

## 验证和证据规则

- 判断 HAP 新旧时，不能只看 `versionName`。必须同时记录 HAP SHA256/mtime、设备 `bm dump updateTime`、包内 `BuildInfo`、`CoreBuildInfo` 和本轮 hilog 特征。
- 真机/虚拟机布局 dump、截图和 hilog 只保存脱敏后的必要证据。一次性密码只能在测试脚本内存中使用，不写入源码、日志、文档、截图文件名或提交说明。
- `reports/` 只保留有审计价值的 Markdown 或脱敏证据。大批量 JSON/XML/PNG/JPEG 探针应转移到 `%VSCODE_ROOT%\99_Temp\rustdesk_harmonyos_test_logs` 或在文档归纳后删除。
- 备份只用 `scripts\backup_project.ps1` 或 Core 仓库同名脚本生成，目录固定为 `rustdesk_harmonyos_backups` 与 `rustdesk_core_backups`。不要再使用 `99_Temp\backups`、`project_backup_*`、`backup2` 等散落目录。

## 推荐命令

App 构建、验包、安装：

```powershell
$env:VSCODE_ROOT = 'F:\Visual_Studio_Code'
Set-Location "$env:VSCODE_ROOT\11_Rustdesk_harmonyos"
cmd /c scripts\build_hap.bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify_native_harmonyos_hap.ps1 -HapPath "$env:VSCODE_ROOT\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap" -SkipLaunch -SkipLogs
```

Core 双架构本地构建：

```powershell
$env:VSCODE_ROOT = 'F:\Visual_Studio_Code'
$env:CARGO_TARGET_DIR = "$env:VSCODE_ROOT\99_Temp\librustdesk_core\cargo_target"
Set-Location "$env:VSCODE_ROOT\13_librustdesk_core"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1 -TargetTriple aarch64-unknown-linux-ohos -Profile release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1 -TargetTriple x86_64-unknown-linux-ohos -Profile release
```
