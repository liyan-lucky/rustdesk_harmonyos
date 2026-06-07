# 项目设计要求

> 修改方向必须符合这些设计要求，避免偏离

## 架构设计

### 核心架构
- **staticlib + CMake直接链接**: Rust核心编译为.a，链接到bridge SO，无dlopen
- **Cargo.toml必须保持**: `crate-type = ["staticlib"]`, `default-features=false`, `features=["use_dasp"]`
- **C++桥接层**: IsCoreLoaded()=true，直接extern "C"调用，无dlopen
- **单一SO**: librustdesk_bridge.so包含C++桥接+Rust核心，无TEXTREL

### 分层原则
- **保留Rust**: 协议层(relay/rendezvous/NAT/protobuf)、加密、会话管理、文件传输
- **HarmonyOS重写**: 录屏(AVScreenCapture)、音频(AudioRenderer)、输入(InputManager)、UI(ArkTS)、文件(@ohos.file.fs)
- **裁剪**: flutter/scrap/cpal/dxgi/x11/pipewire/ffmpeg/system-tray

### 主题管理
- **AppStorage管理颜色**，不使用标准color.json资源文件
- ThemeConfig.ets通过AppStorage存取，所有页面通过`this.theme_XXX`访问
- SVG图标fillColor/colorFilter必须响应主题变化

### 国际化
- **I18nService.translate() + @State i18nVersion**触发重渲染，不用@StorageProp('i18n_xxx')
- lt()方法包裹所有翻译文本
- ForEach([this.i18nVersion]) key变化 → 子树销毁/重建
- 应用启动时**默认显示系统语言**而非英语
- 语言切换**即时生效**，带过渡动画

## UI设计要求

### 整体布局
- 状态栏背景**全透明**，Logo区域渐变背景延伸覆盖状态栏下方
- 内容卡片从**顶部开始**向下显示，不居中
- 显示区域延伸到Tab菜单以下直到屏幕边缘
- 下方可向上滑动位置与其他页面保持一致

### 顶部渐变
- 暗色基色: `#171A1E`，亮色基色: `#F0F4FA`
- linearGradient angle:180，从屏幕顶部开始
- 多控制点渐变(9个点)，暗色从73%→0%不透明度，亮色从75%→0%不透明度
- ID输入和选项卡的背景色应去掉，上方logo区域的半透背景应延伸下来

### Tab栏
- 毛玻璃效果: material color为主(高透明度backgroundColor) + 轻blur(Thin) + 细border + shadow
- 暗色: `#20000000`背景 + `#18FFFFFF`边框
- 亮色: `#30FFFFFF`背景 + `#28FFFFFF`边框
- Tab宽度与页面卡片宽度保持一致

### 连接页面
- ID输入框: 固定高度(64px)避免跳动，从右向左每3位空格分隔
- 输入内容后提示文本上移至输入框内上方
- 输入框有边框线，背景渐变不变
- 宽度适当放宽，减少距离屏幕两边的间距
- 核心Tab: 表样式卡片布局(参考设置Tab)，4卡片(核心/服务信息/会话/调试摘要)
- Rust Core行可点击弹出详情弹窗(文件大小/哈希/ELF有效性/构建时间)
- 核心卡片保留Start/Stop按钮，Stop可停止核心加载状态

### 菜单设置
- 菜单项高度: MENU_ITEM_HEIGHT=50
- 分割线: top border方式，N项N-1条线
- 所有选项左对齐一条竖线位置
- 选中指示标识使用圆形方案
- 会话菜单宽度适合内容宽度，不铺到屏幕边缘
- 三点菜单触摸区域放大
- 会话菜单内容超过屏幕时必须使用滚动容器；关闭入口必须固定在顶部或始终可见，不能被长列表挤出屏幕。
- 有菜单入口就必须有完整行为：真实 native 调用、跳转参数、失败提示、本地排队提示或明确不可用说明，不能只显示菜单文字。
- 连接质量浮层必须至少显示分辨率、FPS、延迟、收发速率、连接线路、缩放比例；未收到 native 质量事件时用本地已知值和“检测中/--”兜底。

### 交互
- 单指滑动指示滑动内容而非平移画面，双指滑动才移动画面
- 去掉触摸的视觉点击效果
- 主题使用点击弹出菜单选中，默认跟随系统
- 语言切换关闭动画1000ms + 页面淡入淡出400ms
- 自定义键盘显示在远程画面顶部，背景透明，不遮挡下方内容；面板内不放额外键盘按钮和关闭按钮，由会话工具栏负责开关。所有按键背景必须使用半透明色（如#55333333），避免遮挡远程画面。

## 图标设计要求

### 图标格式
- **使用SVG资源**，不使用TTF图标字体
- **标准化尺寸**: 最小24x24
- **stroke格式**优先(线条图形)，fill格式用于填充图形
- fillColor用于fill格式图标，colorFilter(BlendMode.SRC_IN)用于stroke格式图标

### 图标颜色
- 选中状态: 线条填充成蓝色
- 默认状态: 亮色模式浅白色，暗色模式浅灰色
- 图标颜色**必须跟随主题变化**，不固定为黑色

### 指定图标
- 收藏: grade图标 | 历史: history图标 | Tab设置: settings图标
- 显示设置: system-ok图标 | 指纹: FingerPrint(点击复制内容)
- 连接: iconmonstr-compass-12 | 登录: iconmonstr-computer-10 | 核心: CpuChip | 通讯录: account-box
- 扫描: QrCode.svg | 键盘: keyboard.svg | 排序: sort.svg(需镜像)
- 工具栏展开: arrow-forward-ios | 收起: arrow-back-ios

### SVG修复规则
- 删除背景path(fill="none"的rect/path，防止fillColor填充背景导致方块)
- fill格式图标: path添加fill="#000000"
- stroke格式图标: path添加stroke="#000000"
- 所有图标资源拷贝到项目中，避免构建丢失

## 构建设计要求

### 目录规范
- 所有编译/调试/备份临时产物在项目目录**之外**进行(99_Temp/)
- 文档和脚本不得写死具体盘符；使用 `%VSCODE_ROOT%` 说明工作区根，运行时从项目位置推导 `99_Temp/`，或通过 `RUSTDESK_HARMONY_TEMP_ROOT`、`RUSTDESK_HARMONY_BUILD_DIR` 覆盖。
- 借用不同电脑时，`local.properties` 只记录当前电脑 DevEco 路径；构建脚本必须优先支持环境变量和 `local.properties`，再回退默认安装路径。
- 构建输出默认不在项目目录内；唯一例外是HAP链接需要的 `entry/src/main/libs/arm64/librustdesk_core.a`
- 文档只保留docs/下9个指定文件，入口为 `docs/README.md`
- 项目备份统一放在 `99_Temp/rustdesk_harmonyos_backups/`，以后只保留最新2份；不要每次备份新建独立路径，备份入口固定为 `scripts/backup_project.ps1`
- 清理时保留 `99_Temp/rustdesk-master/` 源码、`99_Temp/rustdesk_harmonyos_build/` 工具链/脚本/patch/外部源码/当前Rust产物、`99_Temp/rustdesk_harmonyos_backups/` 最新2份备份；删除旧归档、旧备份、下载缓存、target缓存和临时日志

### 编译环境
- LIBCLANG_PATH: 必须指向ohos SDK的llvm/bin
- BINDGEN_EXTRA_CLANG_ARGS: 交叉编译必须传入
- RUSTFLAGS: 必须-fuse-ld=lld，否则clang调用错误ld.exe
- SODIUM_LIB_DIR: 必须设置libsodium路径
- **Windows交叉编译**: 使用stable工具链(`cargo +stable build`)，nightly与rustix 0.37不兼容
- **machine-uid patch**: build.rs中`#[cfg(target_os)]`检查host而非target，已patch为`env::var("TARGET")`判断
- **libsodium**: Windows端需通过MSYS2+OHOS clang交叉编译(首次需要)

### HAP构建
- 构建前必须更新BuildInfo.ets的BUILD_TIME(脚本自动处理)
- **module.json5 必须设置**: `compressNativeLibs: true` + `extractNativeLibs: true` + `libIsolation: true`，确保设备安装时正确解压 native SO 到 `libs/` 目录供运行时加载。设备上 `isCompressNativeLibs` 始终为 `true`（系统行为），`extractNativeLibs: true` 保证 SO 被解压而非直接从 APK 内 mmap。
- 增量构建入口 `scripts/build_hap.bat` 必须设置 `RUSTDESK_HARMONY_VERSION_BUMP=incremental`，版本号右侧数字自增1。
- 全量构建入口 `scripts/build_full_hap.bat` 必须设置 `RUSTDESK_HARMONY_VERSION_BUMP=full`，版本号中间数字自增1，并将右侧数字归零。
- `run_hvigor_with_sdk_patch.js` 必须同步写入 `AppScope/app.json5` 的 `versionName/versionCode` 和 `BuildInfo.ets` 的 `VERSION/BUILD_TIME`。
- 增量编译可能不生效，全量重编需删除entry/build
- 使用`node scripts/run_hvigor_with_sdk_patch.js assembleHap`构建

### Native Core构建（上游源码）
- **上游源码位置**: `%VSCODE_ROOT%\99_Temp\rustdesk-master`
- **当前兼容版本**: 1.4.6（已验证），1.4.7（升级进行中）
- **OHOS 交叉编译必须排除的桌面端依赖**（`target_os = "linux"` 会命中）：
  - `Cargo.toml`: 注释 tray-icon/tao/keepawake；用 `not(target_env = "ohos")` 排除 wallpaper/gtk/libxdo/pulse/dbus/evdev/pam 等
  - `scrap/Cargo.toml`: 排除 dbus/gstreamer/zbus/nokhwa
  - `build.rs`: 基于 `CARGO_CFG_TARGET_OS` 运行时检查，避免 OHOS 交叉编译触发 Windows C++ 编译
  - `lib.rs`: 所有桌面端模块（tray/whiteboard/updater/ui_cm_interface/ui_interface/clipboard/clipboard_file）需 `not(target_env = "ohos")` 条件
- **核心页详细信息必须显示兼容的官方版本号**，避免远端版本不匹配时找不到支撑信息
- **harmony_bridge 目录**不在上游仓库中，升级源码时必须保留并恢复

### 真机测试
- 当前USB测试设备由 `RUSTDESK_HARMONY_USB_TARGET` 指定，文档不记录设备硬件编号。
- 同时存在USB和无线目标时，所有hdc命令必须显式加 `-t <target>`
- 当前USB安装HAP使用 `hdc -t <target> install -r <hap>`，不要加 `-g`
- 历史无线目标 `192.168.11.100:36169` 如需使用，先执行 `hdc tconn 192.168.11.100:36169`
- 核心验证以 `initializeRuntimeFn returned` 和 `Bootstrap snapshot` 为准，预期 `coreReady:true`、`adapter:"official-native"`

## 设计偏好(按优先级)

1. 参考官方做法和标准实现方式
2. 分析问题根因而非盲目重试
3. 一步一步逐步调整而非一次修改多处
4. 最优节能方案而非打补丁
5. 系统开支最小方案
6. 只修改明确要求的内容，不连带修改未提及的元素
7. 理解有偏差时先询问核对而非直接修改
8. 删除文件优先清理可再生成缓存/日志/临时脚本/旧备份，避免删除源码、SDK、工具链、patch和当前可用产物
9. 每次修改代码、资源、脚本或文档后，必须同步更新相关项目文档。
10. 每轮修改后必须构建验证；涉及 native core 时先重编 native core，再构建 HAP，涉及设备行为时优先 USB 安装启动验证。

## 核心状态简词偏好

核心卡片外侧、ID输入框顶行、共享Tab状态徽章等所有外部简易提示位置，统一使用2-3字简词显示核心状态：

| 状态条件 | 中文简词 | 英文简词 | 颜色 |
|---------|---------|---------|------|
| coreReady=true | 就绪 | Rdy | 绿色 |
| 核心已加载但未初始化 | 停止 | Stop | 黄色 |
| 无核心模块 | 未识 | Unk | 红色 |

弹窗内部和运行摘要中显示完整状态文本(如"Official Harmony bridge ready")。

## 当前连接稳定性要求

当前核心已经接入官方 RustDesk session 路径，后续设计重点是稳定性和官方行为对齐：

1. **连接成功前不弹重试**：早期`msgbox`或短暂`session-error`不能直接触发重试对话框。
2. **非人为断开才弹重试**：只有会话已经有效建立后，非本地关闭导致断开，才显示官方重试对话框。
3. **重试对话框按钮固定**：取消、使用中继线路、重试。
4. **视频链路必须闭环**：访问端应收到`session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`。
5. **名称显示遵循官方格式**：ID卡片第二行优先显示`用户名@设备名`。
6. **LAN只做发现来源**：不能把LAN发现当作名称修复或全局在线状态的唯一依据。
7. **输入路径必须真实转发**：触摸、鼠标、滚轮、键盘都必须通过native active session转发。
