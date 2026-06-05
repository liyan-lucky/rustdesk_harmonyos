# UI设计与图标主题

> 顶部渐变、Tab栏、连接页面布局、SVG图标主题适配

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
- 连接质量浮层由顶部工具栏显示按钮直接开关；浮层至少显示分辨率、FPS、延迟、接收速率、发送速率、连接线路、缩放比例。
- 菜单入口必须带完整行为：跳转类入口传递当前 `deviceId`，命令类入口调用 native 或给出本地排队提示，不能静默失败。

---

## 核心页面卡片布局

### 设计要求

- 参考设置Tab样式: `buildSettingsSectionLabel` + `CardContainer` + `buildSettingsInfoSettingRow`
- 4个卡片: 核心 / 服务信息 / 会话 / 运行摘要
- 卡片间距: `SPACING_LG` (16)
- 核心卡片: `Adapter`、`Native Module`、`Native Core` 三行都可点击(带箭头图标)，点击弹出各自详情弹窗
- 详情弹窗: 与Language/Server弹窗样式一致(半透明遮罩+圆角卡片+关闭按钮)

### 核心卡片内容

| 行 | 内容 | 交互 |
|----|------|------|
| Adapter | official-native 等桥接适配器状态 | 点击弹出Adapter详情 |
| Native Module | NAPI bridge module状态 | 点击弹出Native Module详情 |
| Native Core | Rust staticlib/核心状态 | 点击弹出Native Core详情 |

按钮: Start(核心未就绪时) / Reset(核心已就绪时) + Stop(始终显示，核心未就绪时disabled)

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

弹窗标题为当前入口名称或核心模块文件名，内容为该模块的所有信息：

| 行 | 内容 |
|----|------|
| 状态 | 核心状态(statusSummary或Loaded/Stopped/Unrecognized) |
| 错误 | 错误信息或“无” |
| 详情 | 详细消息或“无” |
| 文件 | 核心文件名(从路径提取) |
| 文件大小 | MB |
| 哈希(FNV-1a) | 文件哈希 |
| 有效ELF | 是/否 |
| 构建时间 | 构建时间 |
| 来源 | 加载来源(bundle/filesdir/download/import/none) |

---

## SVG图标主题适配

### 方案

| 图标类型 | 方法 | 原因 |
|---------|------|------|
| **fill格式**(填充图形) | fillColor | 性能最优，直接替换填充色 |
| **stroke格式**(线条图形) | colorFilter | fillColor对开放图形支持有问题 |

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
| linux.svg | Linux平台 |
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
| `entry/src/main/ets/pages/RemoteControl.ets` | 工具栏图标fillColor、箭头图标、buildToolBtnStroke |
| `entry/src/main/ets/pages/AddressBook.ets` | 登录提示图标 |
| `entry/src/main/ets/common/CommonComponents.ets` | PageHeader返回箭头fillColor、createStrokeIconColorFilter |
| `entry/src/main/ets/common/ThemeConfig.ets` | 主题颜色配置(AppStorage) |
| `entry/src/main/ets/services/WindowChromeService.ets` | 状态栏透明 |
