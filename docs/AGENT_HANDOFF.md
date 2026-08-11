# 新对话交接入口

> 更新时间：2026-08-11
> 本文件是新对话的第一入口。读取本文件后，按"必读顺序"读取其他文档。

## 当前项目状态

- **项目**：RustDesk HarmonyOS 客户端（`com.open.rundesk`），第三方兼容客户端，非官方发布
- **工作区**：`E:\Visual_Studio_Code\11_Rustdesk_harmonyos`
- **核心库**：`E:\Visual_Studio_Code\13_librustdesk_core`（独立仓库，staticlib + CMake 链接）
- **目标设备**：`192.168.8.152:36169`（x86_64 模拟器）
- **用户主题**：暗色主题
- **核心架构**：ArkTS Stage UI → C++ NAPI → Rust C ABI staticlib
- **包名**：`com.open.rundesk`，AGPL-3.0-only

## 最近完成的工作

### 2026-08-11 UI/UX 修复 + 光标图标 + 自定义选择器

1. 鼠标模式光标用 iconoir `cursor-pointer.svg` 替换十字线，`scale` 变换支持动态大小（16-64）
2. 远程光标跟随摇杆 + 缩放滑条（0.5x-3.0x），默认 Windows 箭头样式
3. 缩放/编码菜单弃用 Select 组件，自定义浮层弹出列表（Stack+zIndex(120)）
4. 聊天工具栏浅色主题配色修复（`theme_ERROR_BG`+`theme_ERROR_TEXT`）
5. ID 输入框光标错位修复（三层保障：更新前 caretPosition + 多次重试 + onTextSelectionChange 检测）

### 2026-08-10 触摸交互重构 + 虚拟鼠标控制

1. 7 项手势可配置触摸交互系统（`TouchActionConfig.ets` + `TouchInteractionManager.ets`）
2. 虚拟鼠标覆盖层（摇杆 + L/R/M/P 菱形按钮，touch ID 跟踪，速度可调）
3. 悬浮工具栏（收起/展开、拖拽吸边、位置持久化）
4. 鼠标控制菜单 + 设置面板（灵敏度/滚动速度/摇杆速度/光标大小）
5. 连接日志系统（`Logger.ets`）

## 待完成任务

- 推送仓库上线并监控 CI 结果
- 远程光标显示健壮性优化（事件队列容量、载荷编码、cursor clip）
- 全部会话菜单端到端回归验证（Core cursor 回调仍为空实现）
- 文件传输完整链路实现
- 五编码设备切换和质量面板验证
- 华为手机被控端操控已搁置（平台不支持，不作为阻塞项）

## 工作规则

### 0. 文档规范与分支管理（最高优先级）

- **所有操作必须按照项目规范要求文档进行**：`docs/DIRECTORY_CONVENTIONS.md`（目录/路径/构建环境）、`docs/AGENT_MEMORY.md`（技术经验）、`docs/ISSUES.md`（问题记录）是唯一权威规范。避免文档到处都是，新问题经验统一写入对应文档。
- **所有修改在自主分支进行**：不要在 `master` 主分支直接修改，不要随意构建分支。从 `master` 创建自主分支（如 `feature/xxx`），修改完成后合并回 `master`。
- **分支清理**：除 `master` 主分支和 `backup` 备份分支外，清理所有其他分支。定期删除已合并的自主分支。

### 1. 文档优先
- 每次处理问题前，先查 docs/ 下的经验文档
- 解决新问题后，将经验保留到对应文档
- 每次修改代码/资源/脚本/文档后，必须同步更新所有相关项目文档
- **新对话启动规则**：用户发送"读取文档"时，按必读顺序读取所有文档

### 2. 构建验证
- 每轮修改后必须构建验证
- ArkTS/UI 修改：运行 HAP 构建
- 涉及 native core：先在 13_librustdesk_core 重编，再构建 HAP
- 涉及设备行为：构建后安装启动验证

### 3. 经验记录
- 解决新问题后，根因/方案/教训记录到 `ISSUES.md`
- 功能进度更新到 `PROGRESS.md`
- 核心架构变更更新到 `CORE.md`
- UI/设计变更更新到 `UI.md`

### 4. 修改原则
- 参考官方做法和标准实现方式
- 分析问题根因而非盲目重试
- 一步一步逐步调整而非一次修改多处
- 只修改明确要求的内容，不连带修改未提及的元素
- 理解有偏差时先询问核对而非直接修改

## 用户偏好

### UI 偏好
- 页面间配色一致性：核心页面与登录页状态指示配色统一
- 图标和 UI 元素颜色跟随主题适配，不固定黑色
- 使用单个 SVG 图标通过外部 ArkTS 控制动画（如 rotate + animateTo）
- 偏好中文交互，关注中文翻译完整性，不出现中英混合
- 质量显示菜单名称统一2个字（尺寸/帧率/延迟/速度/连接/缩放/编码）
- 画面平移严格边界约束：不允许黑边/空白/背景漏出
- OS Password 按 peerId 持久化到 PreferenceStore
- 所有显示文本走 `this.lt()` 国际化，禁止硬编码中文字符串

### 开发偏好
- 使用 ArkTS 进行 HarmonyOS 应用开发
- 多次追问"为何"时，希望 AI 解释遗漏或出错的原因
- 每次修改及时更新所有对应文档

## 构建与设备命令

```powershell
# 1. 恢复签名配置
Copy-Item "E:\Visual_Studio_Code\99_Temp\build-profile-signed.json5" "E:\Visual_Studio_Code\11_Rustdesk_harmonyos\build-profile.json5" -Force

# 2. 构建
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Visual_Studio_Code\99_Temp\rebuild.ps1"

# 3. 设备连接
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc kill
& $hdc tconn 192.168.8.152:36169

# 4. 安装（需从 HAP 所在目录执行）
$hapDir = "E:\Visual_Studio_Code\99_Temp\harmonyos_build\11_Rustdesk_harmonyos\entry\build\default\outputs\default"
Push-Location $hapDir
& $hdc -t 192.168.8.152:36169 install entry-default-signed.hap
Pop-Location

# 5. 启动
& $hdc -t 192.168.8.152:36169 shell aa start -a EntryAbility -b com.open.rundesk
```

## 核心文件

| 文件 | 说明 |
|------|------|
| `entry/src/main/ets/pages/Index.ets` | 主页面（连接、ID输入、Tab导航） |
| `entry/src/main/ets/pages/RemoteControl.ets` | 远程控制（覆盖层、摇杆、按钮、工具栏、触摸处理） |
| `entry/src/main/ets/pages/Chat.ets` | 聊天页面 |
| `entry/src/main/ets/components/RemoteCursor.ets` | 远程光标组件 |
| `entry/src/main/ets/services/I18nService.ets` | 国际化翻译 |
| `entry/src/main/ets/services/NativeRustDeskBridge.ts` | NAPI 桥接 |
| `entry/src/main/ets/common/TouchActionConfig.ets` | 触摸手势配置 |
| `entry/src/main/ets/common/TouchInteractionManager.ets` | 触摸交互状态机 |
| `entry/src/main/ets/common/Logger.ets` | 统一日志工具 |

## 必读顺序

1. 本文件
2. `docs/AGENT_MEMORY.md` — 技术经验参考（ArkTS/原生/构建/连接/UI 经验库）
3. `docs/DIRECTORY_CONVENTIONS.md` — 目录/路径/构建环境规范（唯一权威）
4. `docs/README.md`、根 `README.md`
5. `docs/CORE.md`、`docs/PROGRESS.md`、`docs/ISSUES.md`
6. `docs/UI.md`、`docs/FILES.md`
7. Core 仓库文档（`13_librustdesk_core/docs/`）
8. 两个仓库 `git status --short` 和当前 diff

## 路径与隐私硬规则

- 所有构建、测试、验包、日志、备份统一放在 `E:\Visual_Studio_Code\99_Temp`
- 不使用 `F:\99_Temp`、仓库内 `.codex_*`、`%TEMP%` 作为长期工作区
- 一次性密码只在测试脚本内存中使用，绝不写入源码、日志、文档、截图或提交说明
- 华为手机被控端输入/操控已搁置，不作为 P0 或发布阻塞项

## 新对话提示词

```text
继续 RustDesk HarmonyOS 开发。先完整读取
E:\Visual_Studio_Code\11_Rustdesk_harmonyos\docs\AGENT_HANDOFF.md，
再按"必读顺序"读取项目文档，检查两个仓库 git status，保留全部未提交修改。
所有操作按照项目规范要求文档进行（DIRECTORY_CONVENTIONS.md、AGENT_MEMORY.md、ISSUES.md）。
所有修改在自主分支进行，不要在 master 直接修改，不要随意构建分支。
使用中文交互，每次修改后构建验证。设备 192.168.8.152:36169，暗色主题。
构建前先恢复签名配置，构建脚本在 99_Temp\rebuild.ps1。
```
