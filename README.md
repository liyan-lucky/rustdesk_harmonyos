# RustDesk HarmonyOS 客户端 — 项目设计要求

> 修改方向必须符合这些设计要求，避免偏离。新接手开发请先读 `docs/README.md`，再按文档阅读顺序继续。

## 项目概况

| 项目 | 值 |
|------|-----|
| 名称 | RustDesk HarmonyOS 客户端 |
| 包名 | `com.open.rundesk` |
| 工作区 | `%VSCODE_ROOT%\11_Rustdesk_harmonyos` |
| 上游兼容 | RustDesk 1.4.7 |
| UI框架 | ArkTS (HarmonyOS Stage 模型) |
| 核心语言 | Rust (staticlib) |
| 桥接 | C++ NAPI → Rust C ABI |
| 许可 | AGPL-3.0 |

## 架构设计

### 核心架构

```
ArkTS UI (entry/src/main/ets/)
    ↓ NAPI
librustdesk_bridge.so
    ↓ C++ bridge (entry/src/main/cpp/)
    ↓ extern "C" 直接调用
librustdesk_core.a (Rust staticlib, 从 GitHub Releases 下载)
    ↓ rustdesk_harmony_bridge
    ↓ RustDesk official session/core (1.4.7)
RustDesk Server / Peer
```

- **staticlib + CMake直接链接**: Rust核心编译为`.a`，链接到bridge SO，无dlopen
- **单一SO**: `librustdesk_bridge.so`包含C++桥接+Rust核心，无TEXTREL
- **C++桥接层**: `IsCoreLoaded()=true`，直接`extern "C"`调用，约400个NAPI注册
- **Rust C ABI**: 369个`rustdesk_bridge_*`导出函数，覆盖官方APK绝大部分`wire_*`函数

### 双项目分离

| 项目 | 位置 | 职责 |
|------|------|------|
| **App项目** (11) | `%VSCODE_ROOT%\11_Rustdesk_harmonyos` | ArkTS UI + C++桥接层 + 构建脚本 + 文档 |
| **核心项目** (13) | `%VSCODE_ROOT%\13_librustdesk_core` | Rust桥接层 + C++桥接层 + 代码生成脚本 + 上游源码 + OHOS补丁 + CI/CD |

**核心修改流程**：
1. 在13项目修改Rust/C++源码
2. `git push` → GitHub Actions自动构建并发布`librustdesk_core.a`到latest release
3. 11项目构建脚本自动从GitHub Releases下载最新核心
4. 放入`entry/src/main/libs/arm64/librustdesk_core.a`
5. 构建HAP并安装验证

**11项目保留的核心相关文件**：
- `entry/src/main/cpp/` — C++桥接层（从13项目同步）
- `entry/src/main/libs/arm64/librustdesk_core.a` — 从GitHub Releases下载

**11项目不再保留的核心相关文件**（已迁移到13项目）：
- `native_rust_core/`、`scripts/generate_*.js`、`scripts/dedup_*.js`、`scripts/regenerate_all.js`

### 分层原则

- **保留Rust**: 协议层(relay/rendezvous/NAT/protobuf)、加密、会话管理、文件传输
- **HarmonyOS重写**: 录屏(AVScreenCapture)、音频(AudioRenderer)、输入(InputManager)、UI(ArkTS)、文件(@ohos.file.fs)
- **裁剪**: flutter/scrap/cpal/dxgi/x11/pipewire/ffmpeg/system-tray

### 主题管理

- **AppStorage管理颜色**，不使用标准color.json资源文件
- `ThemeConfig.ets`通过AppStorage存取，所有页面通过`this.theme_XXX`访问
- SVG图标fillColor/colorFilter必须响应主题变化

### 国际化

- **I18nService.translate() + @State i18nVersion**触发重渲染，不用`@StorageProp('i18n_xxx')`
- `lt()`方法包裹所有翻译文本
- `ForEach([this.i18nVersion])` key变化 → 子树销毁/重建
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
- 核心页固定展示三个状态入口：`Adapter`、`Native Module`、`Native Core`，每个入口有详情菜单
- Native Core详情中的时间、大小和hash应来自`CoreBuildInfo.ets`记录的`librustdesk_core.a`文件信息

### 菜单设置

- 菜单项高度: `MENU_ITEM_HEIGHT=50`
- 分割线: top border方式，N项N-1条线
- 所有选项左对齐一条竖线位置
- 选中指示标识使用圆形方案
- 会话菜单宽度适合内容宽度，不铺到屏幕边缘
- 三点菜单触摸区域放大
- 会话菜单内容超过屏幕时必须使用滚动容器；关闭入口必须固定在顶部或始终可见
- 有菜单入口就必须有完整行为：真实native调用、跳转参数、失败提示、本地排队提示或明确不可用说明
- 连接质量浮层必须至少显示分辨率、FPS、延迟、收发速率、连接线路、缩放比例

### 交互

- 单指滑动指示滑动内容而非平移画面，双指滑动才移动画面
- 去掉触摸的视觉点击效果
- 主题使用点击弹出菜单选中，默认跟随系统
- 语言切换关闭动画1000ms + 页面淡入淡出400ms
- 自定义键盘显示在远程画面顶部，背景透明；面板内不放额外键盘按钮和关闭按钮，由会话工具栏负责开关
- 所有按键背景必须使用半透明色（如`#55333333`），避免遮挡远程画面

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

### SVG修复规则

- 删除背景path(fill="none"的rect/path，防止fillColor填充背景导致方块)
- fill格式图标: path添加`fill="#000000"`
- stroke格式图标: path添加`stroke="#000000"`，每个path必须显式`fill="none"`（OHOS渲染器不正确继承根元素fill="none"）
- stroke格式平台图标(win/mac/linux)统一用colorFilter，不用fillColor
- 所有图标资源拷贝到项目中，避免构建丢失

### 动态图标

- 使用单个SVG图标通过外部ArkTS控制动画（如rotate + setInterval），而非在SVG内嵌动画
- `animateTo({ iterations: -1 })`在ArkTS中不生效，必须用`setInterval`驱动
- `@State`角度变量绑定rotate始终绑定（角度0=不旋转），不要用条件判断

## 构建设计要求

### 目录规范

- 所有编译/调试/备份临时产物在项目目录**之外**进行(`99_Temp/`)
- 文档和脚本不得写死具体盘符；使用`%VSCODE_ROOT%`说明工作区根，运行时从项目位置推导`99_Temp/`
- 构建输出默认不在项目目录内；唯一例外是HAP链接需要的`entry/src/main/libs/arm64/librustdesk_core.a`
- 项目备份统一放在`99_Temp/rustdesk_harmonyos_backups/`，只保留最新2份
- 文档入口为`docs/README.md`

### Native Core获取流程

**核心默认从GitHub Releases下载**，不在本地编译：

1. 构建前脚本自动从`https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a`下载最新核心
2. 下载后放入`entry/src/main/libs/arm64/librustdesk_core.a`
3. 默认不固定release tag和SHA；13项目发布新tag后，11项目构建自动拉取新核心
4. 如需固定版本，设置`RUSTDESK_CORE_URL`和`RUSTDESK_CORE_SHA256`环境变量
5. `CoreBuildInfo.ets`在构建时自动更新核心文件大小、mtime和hash信息

**核心修改流程**（仅在需要修改Rust核心时）：
1. 在`%VSCODE_ROOT%\13_librustdesk_core`项目修改源码
2. `git push` → GitHub Actions自动构建并发布到latest release
3. 11项目下次构建自动下载新核心

**13项目包含**：Rust桥接层(`native_rust_core/`)、C++桥接层(`cpp/`)、代码生成脚本(`scripts/generate_*.js`)、上游源码(`rustdesk-master/`)、OHOS补丁(`patches/`)、CI/CD(`.github/workflows/build-core.yml`)

### HAP构建

- 增量构建：`scripts\build_hap.bat`，版本号右侧数字自增1
- 全量构建：`scripts\build_full_hap.bat`，版本号中间数字自增1，右侧归零
- 一键构建安装：`scripts\AUTO_BUILD_INSTALL.bat auto`
- `run_hvigor_with_sdk_patch.js`同步写入`AppScope/app.json5`的`versionName/versionCode`和`BuildInfo.ets`的`VERSION/BUILD_TIME`
- `module.json5`必须设置：`compressNativeLibs: true` + `extractNativeLibs: true` + `libIsolation: true`
- 构建前必须更新`BuildInfo.ets`的`BUILD_TIME`（脚本自动处理）

### 线上构建

- 使用`.github/workflows/build-harmonyos.yml`，固定生成HAP-only
- Release和workflow artifact只上传`.hap`，不再生成APP、`.app.zip`、`manifest.json`或`SHA256SUMS.txt`
- SDK包拆分为`harmonyos-sdk-full.zip`和`harmonyos-hvigor-full.zip`
- SDK包必须包含previewer的`libcjson.so`/`libsec_shared.so`和ets-loader的`libsec_shared.so`
- workflow必须把这些目录加入`LD_LIBRARY_PATH`

### OHOS交叉编译注意事项（13项目侧）

- `target_os = "linux"`会命中所有Linux桌面端依赖，必须显式排除
- `Cargo.toml`: 注释tray-icon/tao/keepawake；用`not(target_env = "ohos")`排除wallpaper/gtk/libxdo/pulse/dbus/evdev/pam等
- `scrap/Cargo.toml`: 排除dbus/gstreamer/zbus/nokhwa
- `build.rs`: 基于`CARGO_CFG_TARGET_OS`运行时检查，避免OHOS交叉编译触发Windows C++编译
- `lib.rs`: 所有桌面端模块需`not(target_env = "ohos")`条件
- **scrap和arboard必须禁用wayland feature**，否则引入libwayland依赖导致设备上dlopen失败
- `harmony_bridge`目录不在上游仓库中，升级源码时必须保留并恢复

### 真机测试

- USB测试设备由`RUSTDESK_HARMONY_USB_TARGET`指定，文档不记录硬件编号
- 同时存在USB和无线目标时，所有hdc命令必须显式加`-t <target>`
- USB安装HAP使用`hdc -t <target> install -r <hap>`，不要加`-g`
- 核心验证以`initializeRuntimeFn returned`和`Bootstrap snapshot`为准，预期`coreReady:true`、`adapter:"official-native"`
- HDC `list targets`无设备时输出`[Empty]`，脚本必须过滤

## 核心状态简词偏好

核心卡片外侧、ID输入框顶行、共享Tab状态徽章等所有外部简易提示位置，统一使用2-3字简词显示核心状态：

| 状态条件 | 中文简词 | 英文简词 | 颜色 |
|---------|---------|---------|------|
| coreReady=true | 就绪 | Rdy | 绿色 |
| 核心已加载但未初始化 | 停止 | Stop | 黄色 |
| 无核心模块 | 未识 | Unk | 红色 |

弹窗内部和运行摘要中显示完整状态文本(如"Official Harmony bridge ready")。

## 当前功能状态

### 已完成

- 核心加载：staticlib + CMake直接链接，NAPI 400函数注册，`coreReady=true`
- 远程连接：接入官方RustDesk session路径，真实视频帧渲染，peer info获取
- 输入控制：鼠标/键盘/触摸/滚轮/Ctrl+Alt+Del通过native active session转发
- 中文输入：sendImeCommittedText()走sendClipboardData()+sendPasteShortcut()
- LAN发现：30秒周期轮询+手动刷新，Config::path() OHOS条件修复
- 服务器配置：官方样式对话框，导入/导出兼容官方JSON→Base64→反转格式
- 扫码：相机扫码+相册图片二维码识别，服务器配置扫码直存
- 聊天：当前/最近会话聊天内容，持久化消息，浮窗自动滚动
- 地址簿/通讯录：登录后可添加设备，在线状态同步
- 设置：官方分组顺序，Lucide stroke SVG图标，权限开关先同步再异步
- 函数补齐：从54个扩展至369个桥接函数，覆盖官方APK绝大部分wire_*函数

### 当前限制

- **共享服务不可用**：Screen Capture API在当前SDK下不可用，录屏/desktop server未接入时不得标记`incomingReady=true`
- 全屏会话输入法弹出时画面不挤压/平移（未解决）
- `switch-sides`和`session-action=shutdown`无官方协议支持

## 连接稳定性要求

当前核心已接入官方RustDesk session路径，后续设计重点是稳定性和官方行为对齐：

1. **连接成功前不弹重试**：早期`msgbox`或短暂`session-error`不能直接触发重试对话框
2. **非人为断开才弹重试**：只有会话已有效建立后，非本地关闭导致断开，才显示官方重试对话框
3. **重试对话框按钮固定**：取消、使用中继线路、重试
4. **视频链路必须闭环**：访问端应收到`session-connected`、`peer-info`、`video-refresh-requested`、`video-frame`
5. **名称显示遵循官方格式**：ID卡片第二行优先显示`用户名@设备名`
6. **LAN只做发现来源**：不能把LAN发现当作名称修复或全局在线状态的唯一依据
7. **输入路径必须真实转发**：触摸、鼠标、滚轮、键盘都必须通过native active session转发
8. **密码框优先级高于重连/关闭**：密码提示检查必须在所有重连/关闭逻辑之前
9. **并行密码+无密码连接**：无保存密码时，立即弹密码框+同时发无密码申请；无密码成功则关闭密码框

## 设计偏好(按优先级)

1. 参考官方做法和标准实现方式
2. 分析问题根因而非盲目重试
3. 一步一步逐步调整而非一次修改多处
4. 最优节能方案而非打补丁
5. 系统开支最小方案
6. 只修改明确要求的内容，不连带修改未提及的元素
7. 理解有偏差时先询问核对而非直接修改
8. 删除文件优先清理可再生成缓存/日志/临时脚本/旧备份，避免删除源码、SDK、工具链、patch和当前可用产物
9. 每次修改代码、资源、脚本或文档后，必须同步更新相关项目文档
10. 每轮修改后必须构建验证；涉及native core时先重编native core，再构建HAP，涉及设备行为时优先USB安装启动验证
