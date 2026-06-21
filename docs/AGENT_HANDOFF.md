# 当前任务交接入口

> 更新时间：2026-06-21 17:06（Europe/Berlin）  
> 最终本地收口：2026-06-21 23:48（Europe/Berlin）  

## 2026-06-21 23:48 最新接力摘要（最高优先级）

本地功能实现、固定哈希真机验证、精准清理和双仓库备份已收口，后续第一执行序列只剩：复核两仓库完整 diff → 提交、推送 → 等待并验证线上 Core Release 与 HarmonyOS HAP → 把线上 run/asset/hash 证据回写全部相关文档并推送文档收尾提交。不得回滚或覆盖当前未提交修改。

最终本地候选 HAP：`F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`，大小 `34,284,688`，mtime `2026-06-21 23:46:38.466 +01:00`，SHA256 `1D5C7395753D4E8F143FA051E0E931CCFB6C48FFEDA03A8DF91282DD007EC8D2`，BuildInfo `VERSION=0.33.6 / BUILD_TIME=2026-06-21 23:46`。CoreBuildInfo 同时记录 arm64 `131,091,732 / E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D / 9cbd45a1` 与 x86_64 `130,090,572 / DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD / 38bf9990`。两架构均为 2026-06-21 本地同源码基线构建；此前 `0.33.4` 的 x86_64 被默认 latest 下载覆盖为 2026-06-20 线上资产，已发现并废弃，不得发布。

真机 `192.168.11.102:36169` 已安装上述精确 HAP；`bm dump` 为 `versionName=0.33.6`、`versionCode=1000182`、`updateTime=1782082072534`（2026-06-21 23:47:52.534 +01:00）、`cpuAbi=arm64-v8a`。强制停止后冷启动 PID `29233`，hilog 见 NAPI 413 functions、`coreReady=true`、LAN discovery 与在线查询正常，筛选日志未见 fatal/panic/signal。不能仅凭版本号判定新旧，必须同时核对本段 HAP 哈希、mtime、BuildInfo、双架构 CoreBuildInfo、设备 updateTime 和 hilog。

固定哈希最终审计：`reports/full_function_audit_latest.md` 为 100 轮、每轮 152 PASS / 0 FAIL / 1 个预期 SKIP（合计 15200 PASS / 0 FAIL / 100 SKIP）；`reports/connection_chain_audit_latest.md` 为 83 PASS / 0 FAIL / 0 SKIP，其中新增 x86_64 文件、大小、SHA256/CoreBuildInfo 强制断言；签名、两架构 native entries 和两架构 runtime dependencies 验包通过；`git diff --check` 通过，仅有 Git 的 LF→CRLF 提示。

真机 UI 已复验：数字 ID 分组保留且中部连续编辑光标不再跳到结尾；悬浮建议点击会完整写入并关闭；输入 `192.` 能匹配并写入 IP 卡片。ID 卡片菜单宽度收窄、管理员项仅显示“管理员”、未实现项点击统一提示“开发中”；重试对话框按钮高度降低且中间按钮为“中继”。共享页去掉重复的“屏幕共享服务”和 OTP 下方 Core 报错文本，服务/录屏状态联动刷新；文件传输和终端按设置菜单的主题、分界、滑动起止位置收口。

华为手机作为被控端的远程输入/操控和 accessibility 已按用户决定搁置，不作为 P0 或发布失败。一次性密码只能存在测试运行内存，严禁写入源码、日志、文档、截图或提交说明。

23:51 最终清理与备份：前两次可计量白名单清理释放 `1,348,092,177` bytes，最终双架构审计后又删除重新生成的 stage/intermediates/cache/generated；只触及本项目可再生内容、旧 `windows_hap`、真机临时截图/布局和残留 `.tmp`。共享 `99_Temp` 的 3 个 APK 数量/大小/哈希前后一致，`_tmp_rustdesk_1_4_7_src` 已确认不存在。App 最新备份 `rustdesk_harmonyos_20260621_235131.zip`（`1,434,138` bytes，SHA256 `CBD47DA1E03A54CF0EAB5FF47E1C18EF7BC6D17C7D8FE0BC244C4F589739F40A`）；Core 最新备份 `rustdesk_core_20260621_235131.zip`（`3,592,925` bytes，SHA256 `E2CFF8937F62325BF7A8AD0081935D3347F9B62192E5490F52FAEB552D09875B`）；各目录均仅保留最新 2 份 zip 及对应 `.sha256`。
> 新对话必须先完整读取本文件，再按“必读顺序”读取项目文档并继续执行。不要重置、回滚或覆盖当前未提交改动。

## 2026-06-21 17:06 华为手机被控操控搁置与其他功能收口规则（最高优先级）

用户已确认：华为手机当前不支持本项目需要的被控端远程操控/输入注入能力。因此本轮不再把“Windows 端实际点击/键盘操控 HarmonyOS 手机 UI”作为 P0、发布阻塞项或 100% 完成条件。

- **搁置范围**：HarmonyOS 手机作为被控端时的远程鼠标、触摸、键盘注入，以及 accessibility fallback 启用/验证。不要继续尝试绕过系统授权，不要把 Huawei 设置页无法列出 OpenRDesk 当成待强攻问题。
- **仍然保留并收口的范围**：真机被控共享真实画面、连接/断开清理、官方 ID 与 IP 直接访问、ID 建议悬浮层、文件传输、五编码、远程光标、显示/质量/会话菜单、聊天/剪贴板/音频、审计、备份、双仓库提交推送与线上 Release/HAP 验证。
- `entry/src/main/module.json5` 已移除 accessibility `extensionAbilities` 与 `ohos.permission.INPUT_MONITORING`，后续 HAP 不再把不可启用的 accessibility extension 当作发布能力。`ohinput` 实现、ArkTS accessibility service 和 extension 原型均已从活动工作树移除；仅在 `ohos_stubs.cpp` 保留固定返回 `201` 的 native input 符号用于 Core/C++ 链接兼容。若未来恢复该能力，可从 16:40 清理备份或历史差异中找回原型。
- Core/native 中保留的 input injection 符号仅用于链接兼容和诊断边界；运行时若仍返回 `result=201`，结论是系统不支持/未授权，不再阻塞其他功能验收。
- 文档中较早“必须验证输入实际改变手机 UI”的表述均以本节为准：手机被控操控已从必做项降级为后续有系统能力证据后再恢复的 backlog。

## 2026-06-21 15:50 文档与清理暂停摘要（优先于旧执行序列）

用户已明确要求暂停功能推进，先完成文档同步、项目整理和无用文件清理。下一位接手时先确认本节，再按下方“必读顺序”阅读。

- 当前工作重心已从真机继续验证切换为：更新所有对应文档、统一构建/测试路径、清理散落临时文件和重复备份。功能测试线暂停，不要继续点设备或远控窗口，除非用户重新要求恢复测试。
- 新增路径权威文档：`docs/WORKSPACE_PATHS.md`。当前唯一构建/测试/缓存/备份根目录是 `F:\Visual_Studio_Code\99_Temp`（即 `%VSCODE_ROOT%\99_Temp`）。废弃 `F:\99_Temp` / `\99_Temp`、`C:\99_Temp`、App 仓库内 `.codex_*` 和 `%TEMP%` 下的长期测试文件。
- 备份目录统一为两个：`F:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_backups`（App）和 `F:\Visual_Studio_Code\99_Temp\rustdesk_core_backups`（Core）。旧 `99_Temp\backups` 属于历史散落备份，清理时不要再新增同类目录。
- 2026-06-21 17:12 在搁置华为手机被控操控、移除 accessibility extension/`ohinput` 后，已重新构建并验包通过当前标准路径 HAP：
  - HAP：`F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`
  - size `34,233,149` bytes，mtime `2026-06-21 17:12:52.337`，SHA256 `A18FCCEE04A1903372124399035444B5BEBDF84FBB2B9F1918142C994C0797C9`
  - BuildInfo `2026-06-21 17:12`
  - CoreBuildInfo arm64 `131,091,732` bytes / SHA256 `E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D`
  - CoreBuildInfo x86_64 `130,090,572` bytes / SHA256 `DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD`
  - `verify_native_harmonyos_hap.ps1 -SkipLaunch -SkipLogs` 已通过：签名有效，arm64/x86_64 native libs 均存在，runtime dependency check passed。
  - 该 17:12 HAP **尚未安装到真机**。最后一次真机已安装包仍是 15:00 HAP：SHA256 `487EB88719B505013666D74841974A9CF4B031BF6EBFBF2BD6A352089822A35E`，`bm dump updateTime=1782050494366`，BuildInfo `2026-06-21 14:59`。后续安装/验证必须按 hash/updateTime/BuildInfo/CoreBuildInfo/hilog 判断新旧，不能看版本号 `0.32.0 / 1000172`。
- 真机共享链路最新结果：录屏授权后 native buffer 与 Core push 已贯通，日志出现 `videoBufferReady=true`、`frameCount/coreFrameCount` 持续增长、`corePushOk=true`，Windows RustDesk 远控窗口已看到持续刷新的真实手机画面。这一项已从“黑屏待判定”推进为“真机真实画面已验证”；虚拟机仍可记录为 AVScreenCapture 零帧限制候选。
- 被控端手机操控最新结论：远端鼠标事件能到 App/Core，但 native 注入返回 `result=201` 且目标 UI 未改变；Huawei 设置页未列出 OpenRDesk。用户已确认华为手机不支持该操控能力，本轮搁置。不要把收到 mouse event 当作输入完成，也不要继续把 accessibility fallback 作为发布阻塞项。
- Core 已修复一次密码错误后关闭 socket 的问题：`rustdesk-master/src/harmony_bridge/server_ohos.rs` 在 Wrong Password 响应后保持原 socket 存活，Windows 端可继续提交密码并进入会话。
- 临时截图和布局 dump 中曾出现敏感/隐私风险；后续文档和日志禁止写入一次性密码。测试截图只允许短时留在 `%TEMP%`，归纳后立即删除。
- 本轮清理已完成：App 仓库根 `.codex_*` 临时文件/缓存已清空，`reports/` 仅保留两个 Markdown 审计报告，`F:\99_Temp`、旧 `F:\Visual_Studio_Code\99_Temp\backups`、`harmonyos_stage`、旧 root 日志/截图/探针目录已删除；`%TEMP%` 中 RustDesk/Rundesk 截图、布局、签名解包目录已删除，仅剩 RustDesk 运行态 0-byte session marker。
- 16:26 二次清理已完成并写入 `docs/WORKSPACE_PATHS.md`：已删除 `%VSCODE_ROOT%\_tmp_rustdesk_1_4_7_src` 官方 1.4.7 临时 clone、旧 `99_Temp\rustdesk_harmonyos_build\native_rust_core\target`、旧 `windows_hap`、旧 `rustdesk-1.4.7-clone`、旧 downloads/build、HAP intermediates/cache/generated、App/Core 仓库内 IDE/工具缓存和 Core 根构建日志。当前 `99_Temp` 只保留 7 个规范目录；当前 App ignored 保留项只应是 Core junction、`entry/src/main/libs/`、`local.properties`、`signing/`；当前 Core ignored 保留项只应是 `entry/`、`rdev-fork/`、`rustdesk-master/src/version.rs`。
- 17:01 最终核验又清理了工具重新生成的 App `.codeartsdoer/`，并删除 Core `rustdesk-master/libs/rdev/` 空目录壳；该目录只有空 `.github/` 与 `src/`，实际 OHOS rdev 源码以 `rdev-fork/` 为准。若 ignored 状态再次出现除此以外的项，先按 `docs/WORKSPACE_PATHS.md` 判定并清理。
- 清理后备份：
  - App：`F:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_backups\rustdesk_harmonyos_20260621_164050.zip`，`1,424,210` bytes，SHA256 `0ED94CEE63D8CDE9846B2EE3D6CFEA24BA67BAB1CB61F5668E6348CBDE3427CB`
  - Core：`F:\Visual_Studio_Code\99_Temp\rustdesk_core_backups\rustdesk_core_20260621_164050.zip`，`3,588,905` bytes，SHA256 `B64E5962551103380CF6DCDBDB1632124965DDF1B75FD47589F6982DBB0E85DA`

## 2026-06-21 最新接力摘要（优先于下文较早状态）

### 本轮判断纠正与证据规则

- **不得再以 `versionName` 单独判断设备是否安装了最新包。** 本轮多次诊断构建故意直接调用 `run_hvigor_with_sdk_patch.js`，日志为 `bump: none`；它不会执行 `build_hap.bat` 的增量自增或 `build_full_hap.bat` 的全量自增。正式脚本的自增能力没有丢失。
- 当前源码为 `0.32.0 / 1000172`，BuildInfo 为 `2026-06-21 14:12`。真机也显示 `0.32.0 / 1000172`，但设备 `updateTime=1782034726028`（本机换算 `2026-06-21 10:38:46.028 +01:00`），早于当前 HAP 的 `14:13:42`，因此**真机尚未安装当前最新 HAP**。
- 虚拟机此前显示 `0.31.0 / 1000171` 也不能证明包的新旧。后续所有结论必须分别标注：已构建、已安装、运行时已验证。安装证据至少对齐 HAP 时间/SHA256、`bm dump updateTime`、包内 BuildInfo/CoreBuildInfo 和本轮 hilog 特征；版本号只能作为辅助字段。
- 一次性密码仅在安全测试脚本内存中读取，设备临时布局随即删除，且不得写入源码、日志或文档。

### 当前仓库与未提交修改

- App：`F:\Visual_Studio_Code\11_Rustdesk_harmonyos`，`master`，HEAD 仍为 `fe0f984`。当前有大量已跟踪文件修改、新增视频解码/C++ bridge 文件、native input 链接兼容 stub、交接文档和审计报告；ArkTS accessibility service、extension 原型和 `ohinput` 真实实现已按 17:06 搁置决策从活动树移除。继续前仍要以实际 `git status --short` 和完整 diff 为准。
- Core：`F:\Visual_Studio_Code\13_librustdesk_core`，`main`，HEAD 仍为 `99edbb0`。当前有 12 个已跟踪文件修改（约 `1253 insertions / 136 deletions`）和新增 `scripts/backup_project.ps1`。
- **两个工作树都必须原样保留。** 不要 reset、checkout、stash 覆盖、清理用户证据文件或重新拉取覆盖。先完整检查 `git status --short`、`git diff` 和未跟踪文件用途，再继续。
- 清理前 App 工作区曾有 `.codex_core_cargo_target/`、`.codex_core_build_logs/`、`.codex_hvigor_temp/` 及 `.codex_*.json/png` 临时产物；本轮已将有效 HAP/Core 产物迁移到 `F:\Visual_Studio_Code\99_Temp` 标准路径并删除这些散落临时文件。后续不要在仓库根长期保留 `.codex_*`，也不要删除 `reports/` 中保留下来的 Markdown 审计报告。

### 已实现但仍需最终回归的用户新增要求

- ID 匹配列表已按最新要求改为**完全悬浮**：覆盖下方内容但不挤压布局；候选层命中区域被限制在候选框内，不能抢占输入框清除按钮或连接按钮。需要在真机和虚拟机再次用布局 dump + 实际点击回归，并把最终证据同步到 UI/PROGRESS/ISSUES/README 等文档。
- 官方 ID 的菜单已去掉“直连”选项：默认连接由 Core 自动识别直连/中继，菜单中的“中继”只代表强制走中继。
- 设置项已按官方语义实现为 `IP直接访问`：启用后显示本地 IP；IP 文本与开关之间有铅笔图标；对话框中 IP 只显示不可改，仅允许修改端口，默认 `21118`。Core 持久化 `direct-access-port`，监听端口已在虚拟机看到 `21118`。UI 编辑端口、监听切换和恢复 `21118` 尚需最终设备验证。
- 用户提供的蜂窝网络失败日志已经解释清楚：手机蜂窝网尝试 `192.168.11.101:21118` 时失败，是 RFC1918 私网地址跨公网不可路由，不是 ID 解析或密码问题。局域网测试 ID 为 `1283267036`，远程测试 ID 为 `187720470`；密码绝不入文档。

### HarmonyOS 被控共享链路本轮实现

- Core `server_ohos.rs` 已补官方 subscriber snapshot/swap 逻辑，避免新订阅者进入后视频服务不切换/不消费首帧。
- Core `rendezvous_mediator_ohos.rs` 在 LAN listener/信令服务初始化成功后设置 incoming service ready。该状态表示监听服务已就绪，**不再伪装成首个视频帧已产生**。
- Core `core.rs` 已有 incoming RGBA/BGRA 帧缓存并调用 `scrap::update_ohos_incoming_frame`；OHOS scrap Capturer 从该缓存取帧。
- App C++ `rustdesk_bridge_loader.cpp` 使用 `OH_AVScreenCapture`、`AcquireVideoBuffer`、`OH_NativeBuffer_Map`，再调用 `rustdesk_bridge_update_incoming_screen_frame`；统计字段包括 `videoBufferReady/frameCount/coreFrameCount/payloadBytes/format/stride/corePushOk`。
- `ScreenCaptureService.ets` 每 5 秒记录一次低频结构化抓屏统计， inactive 错误也附带统计，便于区分系统未给帧、像素格式拒绝和 Core 未消费。
- 已修正一个潜在启动竞态：抓屏状态和 `video_buffer_ready=false` 在 `StartScreenCapture` 前初始化，不再在系统可能同步触发回调后把 ready 清回 false；`SetCallback` 返回值现在也会校验。虚拟机复测仍为零帧，说明该竞态不是虚拟机当前零帧的唯一原因。

### 虚拟机当前实测边界

- VM HDC：`127.0.0.1:5555`；HDC forward 曾验证 `tcp:22118 -> tcp:21118`。
- Windows RustDesk 通过安全内存密码脚本连接 `127.0.0.1:22118`：VM Core 收到 `incoming-connection`，并出现 `login-authorized peer=1283267036`，证明 direct listener、握手和认证贯通。
- 桌面远控窗口标题为 `127.0.0.1:22118@localhost`，但画面黑屏并显示“已连接，等待画面传输...”。**不能宣称共享画面已贯通。**
- 最新虚拟机诊断日志持续显示：`active=true`、`videoBufferReady=false`、`frameCount=0`、`coreFrameCount=0`、`payloadBytes=0`、无错误。开启/关闭系统“屏幕隐私保护”均无变化。因此黑屏发生在系统 `OnVideoBufferAvailable` 回调之前，尚未进入 Core、VP9 编码或网络发送。
- VM 日志同时确认：native capture start、incoming-service-requested/ready、server-started、direct-listener 21118、rendezvous 注册和 LAN 发现均正常。监听/认证成功不能替代画面证据。
- App 端潜在竞态修复后，VM 仍未收到回调。下一步不要继续盲改编码层；优先用真机判断这是虚拟设备 AVScreenCapture 限制还是通用配置问题。若真机也为零帧，再对照官方 OpenHarmony 样例/实现检查 `OH_AVScreenCaptureConfig` 和 callback 生命周期。

### 华为手机被控操控当前状态（已搁置）

- OHOS native input bridge 在 VM/真机上返回 `result=201`；不能把收到 mouse event 当成输入已生效。
- 用户已确认华为手机不支持本项目需要的被控端操控能力，本轮不再继续 accessibility fallback 验证。
- `entry/src/main/module.json5` 已移除 accessibility extension 和 `ohos.permission.INPUT_MONITORING`；`ohinput` 实现、ArkTS accessibility service 与 extension 原型已从活动工作树移除；仅由 `ohos_stubs.cpp` 保留 native input 同名符号并固定返回 `201`，用于 Core/C++ 链接兼容和清晰诊断。
- 后续只有在系统明确提供第三方可用输入注入或 accessibility 启用入口，并由用户手动授权后，才重新评估。不得绕过系统安全或伪装 profile 类型。

### 当前双架构 Core 与最新 HAP（以 15:50 清理摘要为准）

- 清理前 `331CD1...A6B` HAP 与 `.codex_core_cargo_target` / `.codex_hvigor_temp` 路径只作为历史判断纠正记录；这些散落路径已被迁移/删除，不再作为当前安装目标。
- 当前标准 HAP 路径：`F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`，`34,233,149` bytes，mtime `2026-06-21 17:12:52.337`，SHA256 `A18FCCEE04A1903372124399035444B5BEBDF84FBB2B9F1918142C994C0797C9`，BuildInfo `2026-06-21 17:12`；已本地验包通过，尚未安装到真机。
- 当前标准 Core 产物：`F:\Visual_Studio_Code\99_Temp\librustdesk_core\cargo_target\aarch64-unknown-linux-ohos\release\librustdesk_harmony_bridge.a`，`131,091,732` bytes，SHA256 `E4614BAE4EDB54F2C0A2CFECE96A2E99D558B6900693B2B3A9B08B8F3DCD5D5D`；`F:\Visual_Studio_Code\99_Temp\librustdesk_core\cargo_target\x86_64-unknown-linux-ohos\release\librustdesk_harmony_bridge.a`，`130,090,572` bytes，SHA256 `DB0283F44EA5E5D09A23D1756929B171F28FF2A602D595941902A18ECE5F17DD`。
- 最后一次真机已安装 HAP 是 15:00 包，SHA256 `487EB88719B505013666D74841974A9CF4B031BF6EBFBF2BD6A352089822A35E`，对齐 `bm dump updateTime=1782050494366`、BuildInfo `2026-06-21 14:59` 和 CoreBuildInfo。版本号仍为 `0.32.0 / 1000172`，后续必须继续按 hash/updateTime/BuildInfo/CoreBuildInfo/hilog 判断新旧。

### 新对话第一执行序列

1. 按本文“必读顺序”完整读取资料，检查两个仓库完整 diff，保留全部未提交修改。
2. 若恢复功能测试，先对标准路径下 SHA256 `A18FCCEE04A1903372124399035444B5BEBDF84FBB2B9F1918142C994C0797C9` 的 HAP 执行签名、双 ABI、native 依赖验包；若需重装，必须安装**精确路径的同一 HAP**到真机 `192.168.11.102:36169`，再用 `bm dump updateTime`、BuildInfo/CoreBuildInfo 和 hilog 特征确认，而不是只看 `0.32.0`。
3. 真机打开共享并确认系统录屏授权，抓取 `Native screen capture stats`。完成标准是 `videoBufferReady=true`、`frameCount>0`、`coreFrameCount>0`，随后 Windows 端真实看到持续刷新的手机画面；只有统计无远端画面仍不算完成。
4. 真机画面贯通后测试局域网/官方 ID 自动路由、强制中继、断开清理、重复认证；随后验证文件传输、音频、剪贴板和所有访问端会话菜单。手机被控端输入/操控已搁置，不再要求实际改变手机 UI。密码仍仅内存使用。
5. 真机若能出帧而 VM 不能，记录为虚拟设备 AVScreenCapture 限制并继续以真机优化；真机若也零帧，再核对官方 OpenHarmony AVScreenCapture 样例与实现，不要先改 Core 编码层。
6. 回归 ID 建议层完全悬浮/严格命中区域、`IP直接访问` 官方布局与端口编辑，补齐设计约束和设备证据文档。
7. 完成审计、100 轮、干净 hilog、备份、双仓库提交推送、Core 双架构 Release、App 在线 HAP 构建和线上资产核验。审计结论中明确标注“华为手机被控操控搁置/不支持”，不要计为失败项。当前尚未提交、未推送、未完成 CI/Release。

## 工作区与仓库

- App：`F:\Visual_Studio_Code\11_Rustdesk_harmonyos`，分支 `master`，当前 HEAD `fe0f984`。
- Core：`F:\Visual_Studio_Code\13_librustdesk_core`，分支 `main`，当前 HEAD `99edbb0`。
- App 内 `13_librustdesk_core` 是指向独立 Core 仓库的连接，不是第三份源码。
- 当前真机 HDC：`192.168.11.102:36169`。旧 `.100` 地址已在两个仓库全部替换。
- 包名：`com.open.rundesk`。
- 不得把对话中提供的测试密码写入源码、日志或文档。

## 用户工作规则

1. 每次处理前先查文档和既有经验；没有经验时，解决后写入对应文档。
2. 每次修改同步更新所有对应文档，并完成构建、验包和设备安装验证。
3. 构建脚本失败时按脚本逻辑继续完成，同时修复脚本；优先使用脚本。
4. 问题必须结合虚拟机、真机和核心日志分析，不得盲猜。
5. 所有要求 100% 完成后才能停止；完成修改后推送并等待线上构建结束，Core CI 约 30 分钟。
6. 增量/全量版本号必须通过脚本检查；无源码或核心变化时不要空增版本。
7. 对 Core 的新增接口优先沿用 RustDesk 官方函数及命名。
8. 最后处理共享链路前，必须先为 App 和 Core 两个项目创建可校验备份。

## 必读顺序

1. 本文件。
2. `docs/WORKSPACE_PATHS.md`，先统一构建/测试/备份路径。
3. `docs/AGENT_MEMORY.md`。
4. `docs/README.md`、根 `README.md`。
5. `docs/CORE.md`、`docs/PROGRESS.md`、`docs/ISSUES.md`。
6. `docs/UI.md`、`docs/FILES.md`、`docs/CONNECTION_DEBUG_LOG.md`。
7. Core 仓库的 `docs/WORKSPACE_PATHS.md`、`docs/CORE.md`、`docs/LESSONS_LEARNED.md`、`docs/CONNECTION_DEBUG_LOG.md`。
8. 两个仓库 `git status --short` 和当前 diff；不得回滚用户或本轮已有修改。

## 用户完整目标

- 会话质量菜单实时刷新；画质、编码、远程光标及全部显示/会话菜单必须真实生效。
- 聊天按 ID 隔离，只保留最新 ID；新 ID 清除旧 ID 的内存与持久记录。
- ID 建议必须是完全悬浮层，覆盖下方内容但不挤压布局；命中区域严格限制在候选框内，绝不能抢占清除/连接按钮。输入框支持官方 ID、IPv4、IPv6 和端口格式。
- 新装 App 后核心状态立即正确，不靠切换 Tab；所有核心指示器改为两个汉字。
- 核心会话信息移除“状态/有异常”重复；运行摘要改为实际 log 内容。
- 连接结束、失败或换 ID 时重置所有连接请求和注入状态，同时保留最终错误供核心页查看。
- 同一 ID 重连必须用新请求替换旧请求；第二次连接仍需正常认证，不能沿用上次授权直接进入等待画面。
- 修复密码框刚出现即关闭、虚拟机无限重置和连接突然中断。
- 未登录导致账号拒绝时核心页不能消失。
- 服务器设置输入行预留浮动标题高度，输入时对话框尺寸不跳变。
- 会话与设置使用同一套显示选项：画质、显示方式、编码、滑块自定义缩放和其他默认选项均可修改且有效。
- 编码必须包含并真实接入官方集合：VP8、VP9、AV1、H264、H265；质量面板编码必须随实际流变化。
- 默认显示方式、默认图像质量、默认编码三个 Select 与当前主题一致。
- IPv4 与 IPv6 直连均需在真机实测；已提供 IPv6 测试地址，但密码只从当前安全上下文获取，不写文档。
- Core 同时发布 arm64 与 x86_64；任一架构失败不得创建空标签或空 Release。
- 完成后推送 Core 和 App，等待并核验线上构建、双架构 Release 资产与 App HAP。
- 所有上述任务完成后先备份，再收口 HarmonyOS 被控共享：录屏授权、native buffer、Core video source、desktop server、远端真实画面和断开清理闭环。华为手机被控端输入/操控已按 17:06 决策搁置，不再作为共享闭环完成条件。

## 已完成并有设备证据

- IPv6 直连已在虚拟机成功：TCP direct、密码认证、Windows 1.4.7 peer-info、session-connected、connection-ready 和真实 VP9 帧均出现。
- 虚拟机卸载后全新安装，核心首次启动即 ready；第一次进入核心页显示三个两字“就绪”，无需切换 Tab。
- 未知 ID 失败后最终错误仍保留，核心页及模块状态不再消失。
- 密码框竞态、重复请求 generation、连接终止清理已有实现和虚拟机验证；ID 建议层按最新要求改为完全悬浮且严格限制命中区域，仍需最终设备回归。
- 画质 `Best Speed` 已改为官方 `low`；运行时点击已出现 `session-option key=image-quality;value=low`。
- 远程光标运行时点击已出现 `session-option key=show-remote-cursor;value=Y`，但这只证明选项下发，**不代表功能实现**。
- 官方 toggle 已从普通 `set_option` 改为 session toggle；剪贴板开关同步启停本地 ClipboardService。
- 键盘模式、view-only、质量监控、音频、锁屏后断开、terminal-persistent、block-input/privacy 能力路径已按官方 Session API 整理。
- App 构建脚本已支持解析 `hvigor-config.json5` 的绝对或相对 `ohos.buildDir`，可从外部输出目录正确暂存 HAP。
- 2026-06-20 21:20 离线验包通过：签名有效，arm64/x86_64 两 ABI 均存在。
- 历史签名 HAP：`F:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build\windows_hap\entry-default-signed.hap`，34,038,776 bytes，SHA256 `9F0C70F44C8E41464548306FE9F4A81AAA6896508EC523FC6572AEA92F4D3CC1`；该 `windows_hap` 目录已在 16:26 二次清理中删除，只作为历史安装记录。
- 该 HAP 已直接安装到真机 `192.168.11.102:36169` 并启动；设备显示 `0.31.0 / 1000171`，native path `entry/libs/arm64`，进程 `56803`。
- 本次构建脚本报告 `bump: none`，重复构建没有空增版本。

## 当前正在开发但尚未完成验证

### 全部会话菜单（P0，未完成）

- 用户明确确认：全部会话菜单仍需逐项验证，不能把勾选状态或 `session-option` 日志当作功能完成。
- “显示远程光标”当前未贯通。App 已有 cursor state、PixelMap 缓存与 Canvas overlay 代码，但 Core `HarmonySessionHandler` 的 `set_cursor_data`、`set_cursor_id`、`set_cursor_position`、`set_display` 仍是空实现，`main_set_cursor_position` 也是空函数，因此远端 cursor data/position 没有进入 App。
- 下一对话必须优先在 Core 官方 `Interface` 回调中将 cursor data/id/position/display 排入 bridge event，再在真机/虚拟机确认光标图像、热点坐标、缩放映射、显示切换和关闭选项后的隐藏行为。
- 其余菜单也必须看真实结果：原始/适应/自定义缩放、四档画质、自定义码率/FPS、五编码、键盘模式、质量监控实时刷新、静音、剪贴板启停、会话后锁屏、反向滚轮、左右键交换、仅查看、阻止输入、隐私模式、截图、录制、切换控制端、重启/锁屏/Ctrl+Alt+Del、聊天与语音。目标端有破坏性的动作应在可恢复环境测试。
- 每项至少记录四层证据中的适用部分：UI 状态、Core option/command、远端实际行为、断开重连后的持久化/清理。

### 三点“更多操作”菜单（P0，用户真机实测新增）

- 三点菜单全部项目都要逐项验证，不能只覆盖显示菜单和鼠标菜单。
- **阻止用户输入异常**：用户实测阻止输入可能已作用于远端，但菜单选项仍显示未选中。代码原因之一已经确认：菜单打开读取 `getSessionToggleOption('block-input')`，而官方 `LoginConfigHandler::get_toggle_option()` 没有 `block-input` 分支，会回落到空 option；必须让状态以 `update_block_input_state` 回调为权威来源，不能用不存在的持久 option 推断。
- **取消阻止导致断线**：用户取消阻止输入后立即弹出“需要重试”对话框，说明 `unblock-input` 后会话收到了 retryable disconnect/terminal event。下一轮要用真机和虚拟机抓取点击前后完整 Core bridge event、msgbox、session-error/session-closed 顺序，确认是目标端拒绝、命令语义错误还是 UI 把普通消息误判为断线；修复后反复开/关不得断开连接。
- **文件传输未实现**：三点菜单入口目前只能申请权限并导航到 `pages/FileTransfer`；历史文档里的 official API/事件接入不等于端到端可用。必须验证真实本地目录、远端目录、上传、下载、进度、覆盖确认、取消、失败恢复和断线清理，任一缺失都不能标记完成。
- 三点菜单还包括 OS 密码、发送剪贴板按键、重置画布、Ctrl+Alt+Del、重启、锁定、刷新、复制指纹、切换控制端、截图、录制；全部需要实际结果和安全恢复验证。

### 五种编码

- Core `codec_ohos.rs` 已新增 OHOS native decoder FFI，支持 AV1/H264/H265，并保留 VP8/VP9 libvpx 软件解码。
- App 新增 `entry/src/main/cpp/ohos_video_decoder.cpp`，使用官方 `OH_VideoDecoder_*` buffer API、I420/NV12 输出和 Core 内 libyuv 转 RGBA。
- 会话与设置菜单已恢复 Auto/VP8/VP9/AV1/H264/H265，Core 使用官方 `alternative_codecs()` 合并本机解码与远端编码能力。
- 设置页三个新 Select 已补齐 input/menu/option/selected 的主题背景与文本颜色。
- 最新 x86 Core release 构建成功：129,672,402 bytes，SHA256 `AF9F74082FFF1B807263D2D502AFE090B485ACE736BA007795D025D965DF6C69`。
- **关键未完成**：最新源码的 arm64 Core 尚未重编。App 当前 arm64 Core 仍是旧产物 130,855,122 bytes，SHA256 `9157B97A16526C6328B2FA66D8F923E2254EC6FE694B7E445CA572DECCA2A971`。因此刚安装到真机的 HAP 只验证了 C++ 能编译和安装，没有验证 arm64 五编码 Rust 调用链。
- 下一步必须先构建最新 arm64、复制到 App、重建/验包/安装，再分别选择五种编码；质量面板必须显示远端实际采用的编码，不可只看选项值。

### 安装脚本路径问题

- `AUTO_BUILD_INSTALL.bat --skip-build 192.168.11.102:36169` 选择外部 hvigor 输出目录的 HAP 时，设备返回 `code:9568320 no signature file`。
- 同一轮 `windows_hap\entry-default-signed.hap` 已通过 `verify-app` 并直接安装成功。
- 2026-06-21 16:26 清理后旧 `windows_hap` 目录已删除；当前标准 HAP 是 `F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap`。后续应修复安装脚本：对每个候选包先执行签名/双 ABI/native 依赖验证，不能仅凭文件名或历史 `windows_hap` 目录选择。

## 尚未完成的验证与发布

1. 重新启动虚拟机 HDC，安装含最新双架构 Core 的最终 HAP。
2. 真机从移动/IPv4 网络连接可同时处于 IPv4+IPv6 的客户端；虚拟机访问 Windows 主机应使用 `10.0.2.2`，不要把 QEMU 对宿主 WLAN 地址的 NAT hairpin 失败误判为 App IPv4 失败。
   - 2026-06-20 21:34 已确认手机蜂窝网络输入 `192.168.11.101` 时，Core 正确尝试直连 `192.168.11.101:21118` 并因私网地址不可路由失败；这不是解析或鉴权缺陷。局域网用 `1283267036`，跨网必须用远程 ID `187720470`。
3. 逐项设备验证所有显示/会话菜单，并抓 `session-option`、质量面板和真实行为证据。
   - 首先补齐 Core cursor 回调空实现并验证“显示远程光标”，这是当前已知未实现项。
   - 同时修复三点菜单的 block-input 状态源、unblock-input 断线，以及文件传输完整链路。
4. 修正审计脚本中“只允许 VP8/VP9”的旧断言，改为五编码和 native decoder 链检查。
5. 运行 `audit_connection_chain.ps1`、`audit_full_function_rounds.ps1 -Rounds 100`、双 ABI 验包和干净 hilog 检查。
6. 更新全部对应文档、清理仅用于调试的报告文件，保留有价值证据；不要删除用户文件。
7. 提交并推送 Core，等待约 30 分钟；确认 arm64/x86_64 都成功，Release 只在两者都成功时生成且两个资产非空。
8. App 强制拉取该线上 Core 重建，再提交推送 App，等待线上 HAP 成功并核对资产。
9. 为两仓库创建带时间戳和 SHA256 的备份，再开始最终共享链路。
10. 共享链路必须以远端真实看到 HarmonyOS 屏幕并可持续刷新为完成标准；`captureRequired`、buffer 计数或 `incomingReady` 单项都不能替代画面证据。

## 构建与设备命令

```powershell
# Core x86/arm64
cd F:\Visual_Studio_Code\13_librustdesk_core
.\scripts\build_native_bridge.ps1 -TargetTriple x86_64-unknown-linux-ohos -Profile release
.\scripts\build_native_bridge.ps1 -TargetTriple aarch64-unknown-linux-ohos -Profile release

# App 构建、验包
cd F:\Visual_Studio_Code\11_Rustdesk_harmonyos
.\scripts\build_harmonyos_hap.ps1
.\scripts\verify_native_harmonyos_hap.ps1 -HapPath F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap -SkipLaunch -SkipLogs

# 真机安装
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc tconn 192.168.11.102:36169
& $hdc -t 192.168.11.102:36169 install -r F:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap
& $hdc -t 192.168.11.102:36169 shell aa start -a EntryAbility -b com.open.rundesk
```

## 2026-06-21 新对话提示词（使用此版）

```text
继续 RustDesk HarmonyOS 未完成任务。先完整读取
F:\Visual_Studio_Code\11_Rustdesk_harmonyos\docs\AGENT_HANDOFF.md，
再严格按文档“必读顺序”读取 App/Core 资料，检查两个仓库当前 git status、完整 diff 和未跟踪文件，保留全部未提交修改，不要 reset、checkout、stash 覆盖或重新拉取覆盖。

若用户恢复功能测试，则从交接文档“2026-06-21 最新接力摘要”的第一执行序列继续，不要只给计划：先校验 SHA256 为 A18FCCEE04A1903372124399035444B5BEBDF84FBB2B9F1918142C994C0797C9 的标准路径双架构 HAP；如需重装，必须把精确同一文件安装到已连接真机 192.168.11.102:36169。不要凭 0.32.0 判断是否最新，必须对齐 HAP 哈希/时间、bm dump updateTime、BuildInfo/CoreBuildInfo 和本轮 hilog。

真机优先贯通 HarmonyOS 被控共享：系统录屏授权、OH_AVScreenCapture callback/native buffer、Core incoming frame、desktop server、Windows 端持续真实画面和断开清理闭环。华为手机被控端输入/操控已按 17:06 决策搁置；虚拟机当前 active=true 但 videoBufferReady=false、frameCount=0；先用真机判断是否为虚拟设备限制。局域网测试 ID 为 1283267036，远程测试 ID 为 187720470；一次性密码只在安全测试内存中使用，绝不写入源码、日志或文档。

同时完成并实测：ID 匹配列表完全悬浮、覆盖内容但不挤压布局，命中区域不能抢清除/连接按钮；官方 ID 默认自动识别直连/中继，菜单仅保留强制中继；设置项名称为“IP直接访问”，开启后显示本地 IP，铅笔位于文字与开关之间，对话框只允许修改默认 21118 端口。把这些约束及蜂窝网访问 192.168.11.101:21118 因私网不可路由失败的结论同步进对应文档。

继续处理文件传输、光标、五编码和全部访问端会话菜单真实行为；运行验包、连接链路审计、100 轮、干净 hilog，并为两个仓库创建可校验备份。最后提交并推送 Core/App，等待并核验 Core arm64+x86_64 Release 和 App 在线 HAP。华为手机被控端输入/操控已搁置，不再计入本轮 100% 完成条件。每约 30 秒简短汇报进度，所有结论明确区分已构建、已安装和运行时已验证。
```

## 新对话执行要求

- 不要只回复计划；读取文档和 diff 后直接继续实现。
- 不要重拉覆盖当前工作树。需要同步远端时先 fetch、比较，再保留本地未提交修改。
- 每 30 秒简短汇报进度，长构建和 CI 等待期间继续观察，不能提前结束。
- 所有测试结论都标注来自虚拟机、真机、Core 日志、静态审计或线上 CI 中的哪一种证据。

## 新对话提示词

```text
继续 RustDesk HarmonyOS 未完成任务。先完整读取
F:\Visual_Studio_Code\11_Rustdesk_harmonyos\docs\AGENT_HANDOFF.md，
再严格按该文件“必读顺序”读取 App/Core 文档、检查两个仓库当前 git status 与 diff，保留全部未提交修改，不要重置或从头覆盖。

直接按交接顺序继续实现和实测，不要只给计划：先完成最新 arm64+x86_64 五编码核心、全部会话菜单真实行为（已知远程光标 Core 回调为空；三点菜单阻止输入状态错误、取消后断线、文件传输未实现）、IPv4/IPv6、虚拟机与真机回归、审计、文档、推送并等待线上构建；随后先为两个项目创建可校验备份，再 100% 贯通 HarmonyOS 被控共享链路。每次修改后构建、验包、安装，版本号使用脚本且无变化不递增。结合设备和 Core 日志分析，不要盲猜，中途不要因构建或 CI 等待而停止。
```
