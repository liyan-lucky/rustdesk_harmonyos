# UI设计与图标主题

> 顶部渐变、Tab栏、连接页面布局、SVG图标主题适配

## 2026-06-21 23:23 最终 UI 收口

> 2026-06-22 00:25 发布验证：上述 UI 源码包含在 App 功能提交 `f7fbf217`，最终在线 HAP 由来源修复提交 `3ebdc726` 构建；线上包已下载、验签、双 ABI 核验并真机冷启动。未对已通过真机 UI 回归的布局再做发布后源码改动。

- ID 卡片菜单已大幅收窄并与官方排序对齐；“终端（以管理员身份运行）”缩为“管理员”，未实现项不常驻显示“开发中”，点击统一 toast。
- 文件传输箭头方向/样式与设置一致；文件传输和终端页面按设置页的上下滑动起始位置、主题色、分界线和元素层次统一。
- 设置页上方“显示设置”分组标题使用 `dvr.svg`，下方同名条目图标保持不变；输入控制使用原 `opt_mouse.svg`；方形选中状态使用 `checkbox-outline.svg`。
- ID 数字格式化恢复且中部编辑光标稳定；建议层点击完整填入目标并关闭，ID 与 IP 卡片均可匹配。
- 共享页删除“屏幕共享服务”文本行和 OTP 下方 Core 报错，状态只由右侧指示器表达；服务、屏幕录制和刷新实时联动。华为被控输入行明确显示当前不支持，点击提示开发中。
- 连接重试对话框按钮高度为 `36`，中间按钮仅显示“中继”（英文 `Relay`）。

## 2026-06-21 当前 UI 验证边界

- 真机被控共享已经能在 Windows 端显示真实持续刷新的手机画面；远控显示层不再是“仅黑屏等待”的状态。
- 华为手机被控端输入/操控 UI 已搁置：远端点击已到达但 native 注入 `result=201`，目标 UI 不变化；后续不要再把输入开关显示为打开当作手机被控操控完成证据。
- ID 建议层、`IP直接访问` 布局、五编码选择和所有会话菜单仍需在恢复测试后逐项设备回归；菜单勾选和 option 日志仍只算中间证据。
- 所有布局 dump/截图只保存脱敏证据；包含一次性密码、用户视频画面或隐私内容的截图必须立即删除，不进入 `reports/` 或文档。

## 2026-06-20 会话菜单验证状态

- 所有会话菜单都必须验证真实效果，菜单状态和 Core option 日志只算链路中间证据。
- “显示远程光标”当前未实现完整闭环：App overlay 已存在，Core cursor 回调仍为空。完成后需验证 cursor bitmap、hotspot、缩放/旋转/多显示映射以及关闭时立即隐藏。
- 默认显示方式、默认图像质量、默认编码三个 Select 已补主题属性；仍需最终截图检查浅色/深色主题的控件与弹层颜色。
- 三点“更多操作”菜单也属于必验范围。当前阻止输入的选中状态不可靠，取消会触发重试对话框；文件传输只有入口，未完成端到端功能。修复后菜单关闭/重开、连接断开/重连都要保持正确状态。

## 2026-06-15 远控更多/聊天菜单状态

- 远控“更多操作”中的 `Switch Sides`、`Take Screenshot`、`Session Recording` 必须调用核心 direct session function，不能再通过本地 option 伪装排队。
- `Session Recording` 表示远端会话录制，不等于 Harmony 本机屏幕录制；UI 不应请求 `CUSTOM_SCREEN_CAPTURE`，也不应启动 `ScreenCaptureService`。录制状态以本地点击后的期望状态和核心 `record-status` 事件回流为准。
- 聊天菜单的 `Voice Chat/Stop Voice Chat` 由 `voiceCallActive` 驱动，状态来自 `sessionRequestVoiceCall/sessionCloseVoiceCall` 返回值和核心 `voice-call-started/voice-call-waiting/voice-call-closed` 事件。
- 新增 toast 文案必须有中文翻译：`Screenshot requested`、`Screenshot saved`、`Recording Started`、`Recording Stopped`、`Voice call requested`、`Voice call closed`。

## 2026-06-15 授权弹窗行为

- 共享页点击启动时不能先弹 `CUSTOM_SCREEN_CAPTURE` 普通权限申请，避免用户看到截屏/屏幕捕获授权；录屏授权只允许由 native `OH_AVScreenCapture_StartScreenCapture` 采集链路在核心 ready 后触发。
- 文件传输页必须主动唤起文件访问授权：进入页面、切到本地、刷新本地、上传/下载和本地新建/删除前都要走 `DocumentViewPicker` 目录授权。
- 授权失败只显示短 toast，不在页面加入额外说明卡片；`Screen capture denied` 中文显示为“录屏授权拒绝”，不要再写成“截屏权限拒绝”。
- core-81 已在 core-80 入站帧缓存基础上新增 `captureRequired`；`captureRequired` 只用于触发 App native 录屏提供首帧，`incomingFramePayloadReady/incomingFrameId/incomingFrameBytes/incomingFramesSeen` 只用于诊断“App native buffer 已进入核心缓存”。UI 的共享 TAB 绿点、设备 ID、一次性密码和“服务运行中”仍只能由 `incomingReady=true` 驱动，不能因为入站帧缓存有数据就显示可被远端连接。

## 顶部渐变背景

### 设计目标

- 状态栏背景全透明，避免切换任务时颜色不一致
- 渐变从屏幕顶部(y=0)开始，覆盖状态栏区域
- 文本通过padding避让状态栏，背景不避让

### 实现原理

```
┌─────────────────────────┐
│      状态栏（透明）       │ ← statusBarColor: #00000000
├─────────────────────────┤
│   渐变背景（从顶部开始）   │ ← linearGradient angle:180
│      Logo/标题区域        │ ← padding避让状态栏高度
│   渐变背景（逐渐透明）     │
└─────────────────────────┘
```

### 渐变控制点

**暗色主题** (基色 `#171A1E`，当前实现):

| 位置 | 不透明度 | 颜色 |
|------|----------|------|
| 0.0 | 73% | `#BB171A1E` |
| 0.05 | 67% | `#AA171A1E` |
| 0.12 | 60% | `#99171A1E` |
| 0.22 | 53% | `#88171A1E` |
| 0.35 | 47% | `#77171A1E` |
| 0.52 | 40% | `#66171A1E` |
| 0.72 | 33% | `#55171A1E` |
| 0.88 | 20% | `#33171A1E` |
| 1.0 | 0% | `#00171A1E` |

**亮色主题** (基色 `#F0F4FA`，当前实现):

| 位置 | 不透明度 | 颜色 |
|------|----------|------|
| 0.0 | 75% | `#C0F0F4FA` |
| 0.05 | 69% | `#B0F0F4FA` |
| 0.12 | 63% | `#A0F0F4FA` |
| 0.22 | 56% | `#90F0F4FA` |
| 0.35 | 50% | `#80F0F4FA` |
| 0.52 | 44% | `#70F0F4FA` |
| 0.72 | 31% | `#50F0F4FA` |
| 0.88 | 19% | `#30F0F4FA` |
| 1.0 | 0% | `#00F0F4FA` |

### 颜色演进

| 版本 | 暗色基色 | 亮色基色 | 问题 |
|------|----------|----------|------|
| v1 | #2D3139 | #FDFEFE | 偏白，对比度不足 |
| v2 | #1F2428 | #E8EAED | 仍偏白 |
| v3 | #171A1E | #D4D7DC | 已替换，亮色仍偏灰 |
| v4 | #171A1E | #F0F4FA | ✅ 当前实现，亮色更清透 |

### 代码实现

```typescript
// Index.ets
Column() {
  Column() { PageHeader(this.lt('RustDesk')) }
    .width('100%')
    .padding({ top: this.avoidStatusBarHeight })
}
.width('100%')
.linearGradient({
  angle: 180,
  colors: this.themeIsDark
    ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ...]
    : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ...]
})

// WindowChromeService.ets
mainWindow.setWindowSystemBarProperties({
  statusBarColor: '#00000000',
  statusBarContentColor: textPrimary,
});
```

---

## 底部Tab栏

### 毛玻璃效果

**暗色**:
```typescript
.backgroundColor('#20000000')           // 纯黑13%不透明
.backgroundBlurStyle(BlurStyle.Thin)   // 轻度磨砂
.border({ width: 1, color: '#18FFFFFF' }) // 白色9%边框
.shadow({ radius: 8, color: '#18000000', offsetY: 3 })
```

**亮色**:
```typescript
.backgroundColor('#30FFFFFF')           // 纯白19%不透明
.backgroundBlurStyle(BlurStyle.Thin)
.border({ width: 1, color: '#28FFFFFF' }) // 白色16%边框
.shadow({ radius: 8, color: '#18000000', offsetY: 3 })
```

设计：以材质色为主(高透明度backgroundColor)，轻度模糊(Thin)，细边框和阴影。

---

## 连接页面布局

### 层叠结构

```
Stack
├── Scroll (底层，内容区域)
│   └── Column (buildConnectPeerTabContent)
│       .padding({ top: 200, bottom: 120 })
│
└── Column (上层，渐变背景)
    ├── PageHeader
    │   .padding({ top: avoidStatusBarHeight })
    └── buildOfficialConnectPanel (ID输入框 + 选项卡)
    .linearGradient(...)
```

### 高度计算

| 区域 | 高度 | 说明 |
|------|------|------|
| 状态栏避让 | ~40px | avoidStatusBarHeight |
| PageHeader | ~32px | 标题区域 |
| ID输入框 | 64px | 固定高度 |
| 选项卡Row | 42px | 固定高度 |
| padding | ~32px | 上下padding |
| **总计** | **~200px** | Scroll避让距离 |

### ID输入框样式

```typescript
Column() { /* TextInput... */ }
.width('100%')
.height(64)
.border({ width: 1, color: this.theme_BORDER_SUBTLE })
.borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
// 无背景色，由渐变背景统一覆盖
```

---

## 页面布局规范

- PageHeader统一padding: `top: SPACING_SM, bottom: SPACING_MD`
- 内容区域Scroll: `padding({ top: 80, bottom: 120 })`
- 所有页面顶部对齐: `.align(Alignment.TopStart)`
- 菜单项高度: `MENU_ITEM_HEIGHT = 50`
- 分割线: top border方式 (N项N-1条线)
- Toggle: `constraintSize({ maxHeight: 32 })`
- CardContainer: 只保留左右padding(SPACING_XL=18)

---

## 会话浮层规范

- 自定义键盘位于远程画面顶部，背景透明，只保留功能按键行；面板内不再放键盘按钮和关闭按钮。
- 显示菜单、鼠标菜单、更多菜单都使用顶部标题行 + 关闭图标，关闭入口必须始终可见。
- 更多菜单项目多，必须使用垂直滚动，不能让聊天、文件传输、截图、录制、重启、锁屏等后半段入口被屏幕裁掉。
- 连接质量浮层由顶部工具栏显示按钮直接开关；固定显示分辨率、FPS、延迟、速度、编码、连接线路、缩放比例 7 行，核心上报只更新对应缓存值，不追加动态行。
- 菜单入口必须带完整行为：跳转类入口传递当前 `deviceId`，命令类入口调用 native 或给出本地排队提示，不能静默失败。
- 未接通 official session 的菜单入口必须灰显并明确提示不可用，不能跳转到会把本地状态伪装成 connected 的页面；当前 `View Camera` 入口采用此规则。
- 一次性远控命令必须按 native/core 返回值显示结果；未被处理时显示 `Command unavailable`，不能用“本地排队”或成功提示替代真实发送。
- 聊天工具栏按钮不直接打开唯一聊天框，先弹出“语音聊天 / 文字聊天”两个模式；语音模式匹配音频采集可用性，文字模式打开聊天浮窗。
- 聊天浮窗默认尺寸 `144x187`，最小尺寸 `144x187`，最大 `420x640`；聊天消息时间按跨天或 5 分钟以上间隔显示，不要每条都显示。

---

## 搜索浮层规范

- 历史、收藏、发现、通讯录、登录、核心页面的搜索入口使用同一视觉：`search.svg` 图标按钮 + 悬浮 TextInput。
- 搜索框从搜索图标向左展开，使用 overlay/Stack 绝对定位和 zIndex，不参与 tab 或列表容器排版，不能把标签挤开。
- 搜索框失焦（onBlur）只关闭输入框，不清空搜索文本，保持过滤结果可见；再次点击搜索图标时如果有搜索文本则清空重新开始。
- 从其他 TAB 返回连接 TAB 时，默认焦点回到底部 TAB 按钮（`connect-bottom-tab-btn`）；ID TextInput 不得自动获取焦点。
- ID输入框悬浮匹配框只在输入法激活时显示（`deviceIdInputFocused`），输入法关闭时自动隐藏；`onChange` 中检查 `deviceIdInputFocused && raw.length >= 3` 才显示匹配。
- ID 匹配框必须使用外层 `Stack + position` 完全悬浮，覆盖下方内容但不参与排版；不得用覆盖整个连接面板的 `.overlay(...)`。
- ID输入框右侧X（清除）和→（连接）按钮必须始终可点击：左侧输入 Column 保留 right padding（60），候选框宽度只覆盖输入文本区，候选行显式使用 `HitTestMode.Block`；右侧命令 Row 保持高于候选框的 zIndex，且命令区不得落入候选命中矩形。
- ID输入框连接状态提示文本不超过8个字：连接中、输入ID、ID格式错误、核心就绪、已停止、未知、连接失败、需要密码等；`setStatusMessageRaw` 自动截断超过8字的文本。

---

## 核心页面卡片布局

### 设计要求

- 参考设置Tab样式: `buildSettingsSectionLabel` + `CardContainer` + `buildSettingsInfoSettingRow`
- 4个卡片: 核心 / 服务信息 / 会话 / 运行摘要
- 卡片间距: `SPACING_LG` (16)
- 核心卡片: `Adapter`、`Native Module`、`Native Core` 三行都可点击(带箭头图标)，点击弹出各自详情弹窗
- 详情弹窗: 与Language/Server弹窗样式一致(半透明遮罩+圆角卡片+关闭按钮)
- 核心页状态文案停止态统一显示“停止”，不要再显示“已停止”。
- 主按钮有“开始 / 重启”两态，负责启动或重启所有核心；副按钮有“加载 / 停止”两态，负责加载核心文件或停止并分离运行状态。按钮状态必须跟 Adapter、Native Module、Native Core 的实际 snapshot 同步。

### 核心卡片内容

| 行 | 内容 | 交互 |
|----|------|------|
| Adapter | official-native 等桥接适配器状态 | 点击弹出Adapter详情 |
| Native Module | NAPI bridge module状态 | 点击弹出Native Module详情 |
| Native Core | Rust staticlib/核心状态 | 点击弹出Native Core详情 |

按钮: Start(核心未就绪时) / Restart(核心已就绪时) + Stop(核心运行时可点击，未运行时disabled)

核心页固定展示三类状态入口，详情菜单内容应与上方入口一一对应。

### 服务信息卡片内容

| 行 | 内容 |
|----|------|
| 显示ID | 设备ID或“等待核心初始化” |
| 服务器 | 服务器地址 |
| 指纹 | 指纹 |
| 直连地址 | 直连地址 |

### 会话卡片内容

| 行 | 内容 |
|----|------|
| 阶段 | idle/connecting/connected/error |
| 当前目标 | 对端ID或“无” |
| 状态 | 状态摘要或“空闲” |
| 错误 | 错误信息或“无” |
| 输入控制 | 允许/不允许 |
| 文件传输 | 允许/不允许 |

### 详情弹窗内容

弹窗标题为当前入口名称或核心模块文件名，内容精简为8行：

| 行 | 内容 |
|----|------|
| 类型 | 核心模块类型(kind) |
| 运行 | 合并状态+运行摘要+异常+详情，以 ` | ` 分隔 |
| 兼容 | 兼容官方版本(如 RustDesk 1.4.7) |
| 文件 | 核心文件名(从路径提取) |
| 大小 | 文件大小(MB + bytes) |
| 哈希(FNV-1a) | 文件哈希 |
| 编译 | 核心编译时间(来自librustdesk_core.a的mtime) |
| 有效 | 有效ELF(是/否) |

---

## SVG图标主题适配

### 图标格式原则

**不要重绘SVG图标**，重绘容易丢失图形标识。根据图标自身格式选择着色方法：

| 图标格式 | 着色方法 | SVG要求 |
|---------|---------|---------|
| **fill格式**（填充图形） | fillColor | path必须有`fill="#000000"`属性 |
| **stroke格式**（线条图形） | colorFilter(BlendMode.SRC_IN) | path必须有`stroke="#000000"`属性，每个path显式`fill="none"` |

判断图标格式的规则：
- SVG根元素或path有`fill`属性且无`stroke`→ fill格式，用fillColor
- SVG根元素或path有`stroke`属性且`fill="none"`→ stroke格式，用colorFilter
- 不确定时打开SVG源文件检查，不要猜测

### 平台图标着色

| 图标 | 格式 | 着色方法 |
|------|------|---------|
| win.svg | stroke | colorFilter(createStrokeIconColorFilter(theme_ACCENT)) |
| mac.svg | stroke | colorFilter(createStrokeIconColorFilter(theme_ACCENT)) |
| android.svg | fill | fillColor(theme_ACCENT) |
| linux.svg | fill | fillColor(theme_ACCENT) |

`buildThemedPlatformIcon` 内部通过 `isFillPlatformIcon()` 自动判断平台对应的图标格式，fill格式平台(android/harmony/linux/ubuntu)用fillColor，stroke格式平台(win/mac/ios)用colorFilter。

### 核心机制

**fillColor**: 覆盖SVG中path的fill属性值。前提: path必须有`fill="#000000"`属性

**colorFilter**: 使用BlendMode.SRC_IN混合模式。前提: SVG有`stroke="#000000"`属性

**SVG修复步骤**:
1. 删除背景path (去掉`fill="none"`的rect/path，防止fillColor填充背景导致方块)
2. fill格式图标: path添加`fill="#000000"`
3. stroke格式图标: path添加`stroke="#000000"`

### 代码实现

```typescript
// CommonComponents.ets
import drawing from '@ohos.graphics.drawing';

export function toArgbColor(color: string): number {
  const normalized = color.trim().startsWith('#') ? color.trim().substring(1) : color.trim();
  if (normalized.length === 8) return parseInt(normalized, 16);
  return 0xFF000000 + parseInt(normalized, 16);
}

export function createStrokeIconColorFilter(color: string): drawing.ColorFilter {
  return drawing.ColorFilter.createBlendModeColorFilter(
    toArgbColor(color), drawing.BlendMode.SRC_IN
  );
}

// fill格式工具按钮
@Builder buildToolBtnSvg(icon: string, action: () => void) {
  Image($rawfile(icon)).fillColor(this.theme_TEXT_TERTIARY).onClick(action)
}

// stroke格式工具按钮
@Builder buildToolBtnStroke(icon: string, action: () => void) {
  Image($rawfile(icon)).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)).onClick(action)
}
```

### fill格式图标 (fillColor)

| 图标 | 用途 | 图标 | 用途 |
|------|------|------|------|
| monitor.svg | Tab-连接 | chat.svg | Tab-聊天 |
| settings_gear.svg | Tab-设置 | search.svg | 搜索 |
| close.svg | 关闭 | dots_vertical.svg | 三点菜单 |
| keyboard.svg | 键盘 | display.svg | 显示设置 |
| secure.svg | 安全连接 | insecure.svg | 非安全连接 |
| arrow.svg | 返回箭头 | arrow-forward-ios.svg | 工具栏展开 |
| arrow-back-ios.svg | 工具栏收起 | translate.svg | 语言 |
| dark_mode.svg | 暗色主题 | light_mode.svg | 亮色主题 |
| fingerprint.svg | 指纹 | star.svg/star_filled.svg | 收藏 |
| explore.svg/explore_filled.svg | 发现 | history.svg/history_filled.svg | 历史 |
| device_group.svg/device_group_filled.svg | 登录 | address_book.svg/address_book_filled.svg | 通讯录 |
| login.svg | 登录图标 | logout.svg | 登出图标 |
| win.svg | Windows平台 | android.svg | Android平台(已重画为stroke) |

### stroke格式图标 (colorFilter)

| 图标 | 用途 |
|------|------|
| screen.svg | Tab-共享(含箭头开放图形) |
| actions.svg | 操作菜单 |
| refresh.svg | 刷新(静态+动态旋转) |
| Sorting_order.svg | 排序 |
| mac.svg | macOS平台 |
| linux.svg | Linux平台 | fill | fillColor |
| scan_frame.svg | 扫码入口 | fill | fillColor | 内空半透描边圆形按钮，背景透明+1.5px描边 |
| settings_person.svg | 设置-账户(分组标签) |
| settings_server.svg | 设置-服务器(分组标签+行图标) |
| settings_proxy.svg | 设置-代理(行图标) |
| settings_cpu.svg | 设置-硬件编解码(分组标签+行图标) |
| settings_video.svg | 设置-录屏(分组标签) |
| settings_shield.svg | 设置-2FA(分组标签) |
| settings_monitor.svg | 设置-共享屏幕/显示(分组标签) |
| settings_tune.svg | 设置-增强功能(分组标签) |
| settings_info.svg | 设置-关于(分组标签) |
| settings_websocket.svg | 设置-WebSocket(Lucide globe) |
| settings_network.svg | 设置-IPv6 P2P(Lucide network) |
| settings_udp.svg | 设置-UDP打洞(Lucide arrow-down-up) |
| settings_ipv6.svg | 设置-IPv6(Lucide network) |
| settings_remark.svg | 设置-会话结束备注(Lucide message-square-plus) |
| settings_keepscreen.svg | 设置-保持亮屏(Lucide sun) |
| settings_folder.svg | 设置-目录(Lucide folder) |
| settings_shield_check.svg | 设置-2FA开关(Lucide shield-check) |
| settings_wifi_off.svg | 设置-拒绝LAN发现(Lucide wifi-off) |
| settings_whitelist.svg | 设置-白名单IP(Lucide shield-alert) |
| settings_gauge.svg | 设置-自适应码率(Lucide gauge) |
| settings_record.svg | 设置-允许录制(Lucide circle-dot) |
| settings_router.svg | 设置-直连IP(Lucide router) |
| settings_timer.svg | 设置-自动关闭/构建时间(Lucide timer) |
| settings_power.svg | 设置-开机启动(Lucide power) |
| settings_update.svg | 设置-检查更新(Lucide refresh-cw) |
| settings_terminal.svg | 设置-终端扩展键(Lucide terminal) |
| settings_floating.svg | 设置-悬浮窗(Lucide app-window) |
| settings_display.svg | 设置-显示/保持亮屏(Lucide monitor) |
| settings_info_circle.svg | 设置-版本信息(Lucide info) |
| settings_privacy.svg | 设置-隐私政策(Lucide file-text) |
| settings_language.svg | 设置-语言(Lucide languages) |
| settings_palette.svg | 设置-主题(Lucide palette) |
| settings_record_in.svg | 设置-录入站(Lucide arrow-down-to-line) |
| settings_record_out.svg | 设置-录出站(Lucide arrow-up-from-line) |
| menu_key.svg | 菜单-密码/Ctrl+Alt+Del(Lucide key) |
| menu_clipboard.svg | 菜单-发送剪贴板(Lucide clipboard) |
| menu_reset.svg | 菜单-重置画布(Lucide maximize) |
| menu_lock.svg | 菜单-锁屏(Lucide lock) |
| menu_block.svg | 菜单-阻止输入(Lucide ban) |
| menu_restart.svg | 菜单-重启远端(Lucide rotate-ccw) |
| menu_refresh.svg | 菜单-刷新屏幕(Lucide refresh-cw) |
| menu_transfer.svg | 菜单-文件传输(Lucide folder-sync) |
| menu_fingerprint.svg | 菜单-复制指纹(Lucide copy) |
| menu_switch.svg | 菜单-切换方向(Lucide arrow-left-right) |
| menu_screenshot.svg | 菜单-截图(Lucide camera) |
| menu_record.svg | 菜单-会话录制(Lucide circle-dot) |

### 动态图标方案 (refresh.svg为例)

**原则**: 一个SVG同时实现静态显示和动态旋转，由ArkTS控制，SVG内不写动画。

**SVG要求**: stroke格式，`stroke="#000000"`，不含`<animateTransform>`。

**ArkTS实现**:

```typescript
// 1. @State角度变量 + 定时器引用
@State refreshAngle: number = 0;
private refreshTimer: number = -1;

// 2. 图标渲染：始终rotate（角度0=不旋转）
Image($rawfile('refresh.svg'))
  .width(18).height(18)
  .colorFilter(createStrokeIconColorFilter(theme_TEXT_TERTIARY))
  .rotate({ x: 0, y: 0, z: 1, angle: this.refreshAngle })

// 3. 开始旋转：setInterval驱动@State递增
this.refreshAngle = 0;
this.refreshTimer = setInterval(() => {
  this.refreshAngle = (this.refreshAngle + 18) % 360;
}, 40);  // 每40ms转18度，约2秒一圈

// 4. 停止旋转：clearInterval + 归零
if (this.refreshTimer !== -1) {
  clearInterval(this.refreshTimer);
  this.refreshTimer = -1;
}
this.refreshAngle = 0;
```

**关键点**:
- `refreshAngle`必须是`@State`，否则变化不触发重渲染
- `rotate`始终绑定（角度0等于不旋转），不要用条件判断`isRefreshing ? rotate(...) : undefined`
- `animateTo({ iterations: -1 })`在ArkTS中不生效，必须用`setInterval`驱动

### 验证要点

主题切换时图标颜色变化:
- 亮色主题 → 深色图标
- 暗色主题 → 浅色图标

关键位置: Tab菜单图标 / ConnectPeerTab图标 / 远程控制工具栏 / 返回箭头 / 搜索/排序 / 三点菜单 / 扫描/指纹 / 账户页InfoRow图标

### 菜单图标位置要求

会话菜单布局规则：**图标在左，选项（Radio圆圈/Checkbox）在右，文字在中间**。
- `buildMenuRow`：图标左 → 文字中间(layoutWeight(1)) → 箭头右
- `buildToggleMenuRow`：图标左 → 文字中间(layoutWeight(1)) → Radio右
- `RadioOptionItem`：图标左 → 文字中间(layoutWeight(1)) → Radio右
- `CheckboxOptionItem`：图标左 → 文字中间(layoutWeight(1)) → Checkbox右

### 会话菜单关闭方式

- 无关闭按钮(×图标)，点击菜单区域外任意位置关闭
- 菜单宽度210，内边距12，标题高度40

### 设置页与会话页开关同步

设置页显示设置开关和会话页菜单开关使用同一套逻辑：`applySessionOption` + `setLocalOption` / `applySessionAndLocalOption`，确保状态一致。同一功能只允许一份状态源：会话页可以显示勾选图标，设置页可以显示 Switch 或选择器，但“显示连接质量 / 显示远程鼠标 / 图像质量 / 会话录制”等同功能必须读写同一个 option/key。

### 画面平移边界限制

- `clampPanOffset` 方法限制画面偏移范围
- 横向：左右最多到屏幕边缘一条缝（gap=4px）
- 竖向显示时：左右可缩小到屏幕边缘（gap=0）
- 横竖屏切换时自动重新计算边界

### 显示设置菜单标题操作按钮

- `buildSessionPanelHeader` 支持可选的 `headerAction` 参数（`PanelHeaderAction` 接口：icon/isStroke/action）
- 显示设置面板标题右侧有旋转方向按钮（`opt_rotate.svg`，stroke格式），点击切换竖屏/横屏显示
- 旋转时重置 panOffset 为 (0,0)，避免越界

### 质量监控面板

- 固定7行：分辨率/FPS/延迟/速度/编码/连接/缩放；核心上报的 `quality-status` 只更新固定行缓存，禁止追加动态指标。
- 编码行：从quality-status的codec_format提取，转大写显示（VP9/H265等）
- 连接行：标签为"连接"（非"连接类型"），显示直连/中继/加密等
- 面板保持窄宽全透背景，固定 7 行位于滚动容器中，避免挤压远控画面。
- 面板打开期间每 500ms 触发一次轻量重绘，刷新普通字段（含分辨率）但不重复解析 native payload。

### 会话与默认显示设置

- 显示模式统一使用 `display-scale-mode`：`original` / `fit` / `custom`；会话菜单和设置页读取同一持久化值。
- 自定义缩放统一使用 `custom-zoom-percent`，范围 100%-600%，使用 Slider 调节。
- 图像质量统一使用 `image-quality`，自定义值使用 `custom-image-quality` 和 `custom-fps`。
- 编码统一使用官方 `codec-preference`：Auto / VP8 / VP9 / AV1 / H264 / H265；菜单使用单行下拉选项。

### 键盘避让

- 只平移画面（Image），不平移容器
- `computeKeyboardOffset()` 计算画面下边缘与键盘区域重叠量
- 只有重叠 > 0 时才向上平移重叠量，且不超过画面顶部位置
- 键盘弹出不自动收起工具栏（已取消 toolbarHiddenByKeyboard 关联）

### 缩放限制

- pinchScale 最小值为 1（最小 100% 缩放，不能缩小）
- 竖屏时画面比容器窄：左右到屏幕边缘（minX=0, maxX=pw-renderedW）
- 横屏时画面比容器矮：上下到屏幕边缘（minY=0, maxY=ph-renderedH）

### 工具栏底部避让

- 展开时：`margin({ bottom: avoidNavigationBarHeight })`
- 收起时：`padding({ bottom: avoidNavigationBarHeight })`
- 菜单面板：`padding({ bottom: 56 + avoidNavigationBarHeight })`，底部贴着展开工具栏顶部

### 关于页

- "启动检查更新"开关为禁用状态（disabled=true，灰色不可操作）
- 指纹行：整行可点击复制完整指纹，右侧显示指纹前12字符
- `buildSettingsToggleSettingRow` 支持 `disabled` 参数

### 共享页状态

- 真实共享运行态只由 `settings.serviceEnabled && officialCoreState.incomingReady` 决定，运行态才显示绿色状态、设备 ID 和一次性密码。
- 共享已请求但核心未 ready 时显示 `Share requested` / `Requested`，描述优先展示核心 `lastError/detailMessage`，不显示成“服务运行中”。
- 录屏探针只作为临时诊断状态，不能触发共享 TAB 绿点，也不能展示设备 ID/密码；当前启动顺序已改为核心 ready 后才启动 native 屏幕采集，避免本机采集状态与真实共享状态冲突。

### ID卡片连接模式

- Per-card 存储：PreferenceStore `peer_connect_modes`，`getPeerConnectMode(peerId)` / `setPeerConnectMode(peerId, mode)`
- 菜单中直连/中继选项从 per-peer 存储读取选中状态
- 中继重连后自动更新 per-peer 模式为 relay
- 菜单其他功能（收藏/删除/重命名/文件传输/终端/摄像头）已确认 per-card

---

## 账户页登录后图标 (2026-06-05)

- **InfoRow组件**：`InfoRow(label, value, icon='')` 新增可选icon参数，传入时在label前显示18px stroke图标
- **连接Tab账户卡片**：Account→settings_person.svg、Provider→settings_server.svg、Status→settings_record.svg
- **账户对话框登录后**：账户名前添加settings_person.svg图标（Provider/Status已有buildSettingsInfoSettingRow图标）

---

## 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `entry/src/main/ets/pages/Index.ets` | 渐变背景、Tab栏、Tab图标fillColor/colorFilter、搜索、ID输入框 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 工具栏图标fillColor、箭头图标、buildToolBtnStroke、聊天模式菜单 |
| `entry/src/main/ets/pages/LoginPage.ets` | 登录页搜索入口和 provider 过滤 |
| `entry/src/main/ets/pages/AddressBook.ets` | 登录提示图标 |
| `entry/src/main/ets/common/CommonComponents.ets` | PageHeader返回箭头fillColor、createStrokeIconColorFilter |
| `entry/src/main/ets/common/ThemeConfig.ets` | 主题颜色配置(AppStorage) |
| `entry/src/main/ets/services/WindowChromeService.ets` | 状态栏透明 |

## 2026-06-20 核心属性菜单字段规范

核心属性菜单（点击核心状态指示器弹出）只显示以下8项，不得增减：

| 序号 | 标签 | 字段 | 说明 |
|------|------|------|------|
| 1 | Type | kind | adapter / native-module / native-core |
| 2 | Status | statusActive | Running / Stopped |
| 3 | Compatible | compatibleOfficialVersion | 兼容的 RustDesk 版本 |
| 4 | File | path | 核心文件名 |
| 5 | File Size | fileSize | 文件大小 |
| 6 | Hash (FNV-1a) | hash | 文件哈希 |
| 7 | Compile | buildTime | 编译时间 |
| 8 | Valid | validElf | ELF 有效性 |

**已移除字段**（不再显示）：Summary、Error、Detail。这些信息可通过日志查看，不需要在菜单中展示。

## 2026-06-20 远控质量菜单字段规范

远控会话质量菜单（点击质量指示器弹出）只显示以下7项，名称统一2个字，不得增减：

| 序号 | 标签 | 数据来源 | 说明 |
|------|------|----------|------|
| 1 | 尺寸 | frameWidth × frameHeight | 当前帧分辨率 |
| 2 | 帧率 | connectionFps | 当前帧率 |
| 3 | 延迟 | connectionLatency | 网络延迟(ms) |
| 4 | 速度 | connectionSpeedDisplay | 传输速度 |
| 5 | 连接 | connectionType | 直连/中继 |
| 6 | 缩放 | getCurrentZoom() | 画面缩放比例 |
| 7 | 编码 | connectionCodec | 编码格式 |

**已移除字段**（不再显示）：目标码率(target_bitrate)、下载速度(speed重复)、上传速度(send_speed)、色度(chroma)。核心 quality-payload 事件中的 delay/fps/speed/codec_format 与固定行重复，不再追加显示。

## 2026-06-23 文件传输页面布局规范

### 整体布局

文件传输页面使用 Column 流式布局（**禁止 Stack 叠加布局**，Stack 会拦截滚动事件）：

```
Column
├── Header（返回+标题+刷新按钮）
├── Toolbar（本地/远端切换 + 排序 + 三点菜单）
├── FileList（List 组件，支持滚动）
└── BottomBar（多选操作栏 / 粘贴栏，避让导航栏）
```

### Header

- 高度约为常规 PageHeader 的 2 倍，包含返回箭头、页面标题、刷新按钮
- 刷新按钮使用 `refresh.svg`（stroke 格式，`colorFilter(createStrokeIconColorFilter())` 着色），支持动态旋转动画

### Toolbar

- 左侧：本地/远端切换按钮（`ft_local.svg` / `ft_remote.svg`）
- 中间：当前路径显示
- 右侧：排序按钮（`ft_sort.svg`，三横线样式，stroke 格式）+ 三点菜单（`dots_vertical.svg`）
- 排序菜单：弹出式菜单，选项包括名称/大小/日期/类型排序，勾选图标在右侧
- 三点菜单：新建文件夹、显示隐藏文件、全选

### 文件列表

- 使用 `List` 组件，支持垂直滚动
- 文件项布局：图标（`ft_folder.svg` / `ft_file.svg`）+ 文件名 + 大小/日期 + 三点菜单
- 文件项三点菜单：打开/复制/剪切/重命名/删除/详情
- 长按选中文件项，进入多选模式
- 多选模式：顶部显示选中数量，底部显示操作栏（复制/剪切/删除）
- 隐藏文件默认不显示，通过三点菜单"显示隐藏文件"切换

### 底部操作栏

- 多选模式：显示复制/剪切/删除按钮
- 剪贴板有内容时：显示粘贴按钮
- 底部避让导航栏：`padding({ bottom: avoidNavigationBarHeight })`

### 菜单样式

- 菜单宽度 210，内边距 12
- 菜单背景色：`backgroundColor(theme_CARD_BG).opacity(0.92)` 半透明主题色（**禁止** `'99' + hex` 方式，OHOS 上显示为蓝色）
- 勾选图标在右侧（`checkmark.svg`，stroke 格式）
- 点击菜单区域外任意位置关闭

### 顶部渐变遮罩

- 文件列表顶部使用渐变遮罩，从主题背景色渐变到透明
- 遮罩高度约 8px，覆盖列表顶部边缘

### 文件传输图标（ft_*.svg）

所有文件传输相关图标均从 proicons 提取，stroke 格式，使用 `colorFilter(createStrokeIconColorFilter())` 着色：

| 图标 | 用途 |
|------|------|
| ft_folder.svg | 文件夹图标 |
| ft_file.svg | 普通文件图标 |
| ft_local.svg | 本地切换 |
| ft_remote.svg | 远端切换 |
| ft_sort.svg | 排序（三横线样式） |
| ft_copy.svg | 复制 |
| ft_cut.svg | 剪切 |
| ft_paste.svg | 粘贴 |
| ft_delete.svg | 删除 |
| ft_rename.svg | 重命名 |
| ft_new_folder.svg | 新建文件夹 |
| ft_select_all.svg | 全选 |
| ft_hidden.svg | 显示隐藏文件 |
| ft_detail.svg | 详情 |
| ft_open.svg | 打开 |
| ft_refresh.svg | 刷新列表 |

---

## 2026-06-23 终端页面布局规范

### 整体布局

```
Column
├── Header（返回+标题+终端信息）
├── TerminalScreen（终端输出区域，黑色背景）
└── CustomKeyboard（自定义终端键盘）
```

### Header

- 返回箭头 + 页面标题"终端（管理员 beta）"
- 终端连接状态显示

### TerminalScreen

- 黑色背景，等宽字体
- 终端输出从 `terminal-output` 事件获取，Base64 解码后显示
- 支持文本选择和滚动

### CustomKeyboard

- 自定义终端键盘，包含 Ctrl/Alt/Tab/Esc/F1-F12 等特殊键
- 键盘行布局：功能键行 + 数字行 + QWERTY 三行 + 空格行
- 按键通过 `TerminalService.sendTerminalInput()` 发送到核心

---

## 2026-06-23 ID 卡片菜单规范

### 菜单布局

- 菜单宽度 210（从 248 收窄）
- 菜单项：图标左 → 文字中间 → 勾选/箭头右
- 勾选图标从左侧移到右侧

### 菜单项文案

- "管理员" → "终端（管理员 beta）"
- "始终通过中继连接" → "中继连接"
- 未实现项点击显示 toast 提示，不常驻"开发中"

### 连接链路

- "文件传输"：使用 `pendingNavigatePage` 模式，先建立连接再跳转到 FileTransfer 页面
- "终端(beta)"：直接跳转到 Terminal 页面
- `pendingNavigatePage` 状态变量控制连接成功后的跳转目标

---

## 2026-06-20 连接输入与密码弹窗布局规范

- ID 候选列表是完全悬浮的绝对定位层，覆盖下方 Tab/列表内容但不挤压布局；不允许使用覆盖整个连接面板的 `.overlay(...)`。命中区域必须严格限制在候选框内，并在几何上避开清除、连接命令区，命令 Row 的 zIndex 始终更高。
- 纯数字目标可显示历史匹配；IPv4/IPv6 不显示数字 ID 候选，也不做三位分组。
- 密码弹窗操作区必须始终位于软键盘上方。当前使用 `avoidKeyboardHeight` 将卡片最多上移 88vp；不能依赖用户先收起键盘才能点击确认。
- “记住密码”由 Checkbox 自身 `onChange` 和文字点击分别处理，父 Row 不再整体切换，避免一次点击触发两次反转。
- 密码确认提交到当前等待鉴权的会话；界面不应在确认时先关闭连接再显示第二次连接等待。
