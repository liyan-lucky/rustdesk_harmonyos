# RustDesk HarmonyOS 项目状态文档

## 1. 项目概述

RustDesk HarmonyOS 客户端的触摸交互系统重构和虚拟鼠标控制功能实现。

- **主仓库**：`E:\Visual_Studio_Code\11_Rustdesk_harmonyos`
- **核心库**：`E:\Visual_Studio_Code\13_librustdesk_core`
- **临时构建**：`E:\Visual_Studio_Code\99_Temp\harmonyos_build`
- **目标设备**：`192.168.8.152:36169`（x86_64 模拟器）

## 2. 触摸模式（mouseControlMode === 0）

### 2.1 手势配置系统

7 项可配置手势，每项可设置时长和动作：

| 手势 | 默认时长 | 默认动作 | 说明 |
|------|----------|----------|------|
| 单击 | 300ms | 左键单击 | 300ms 内抬起 |
| 长按 | 500ms | 右键单击 | 500ms 后抬起触发 |
| 滑动 | 300px/s | 画面平移 | 速度达标立即触发 |
| 短按拖动 | 400ms | 滚动 | 按住 400ms 后拖动 |
| 长按拖动 | 600ms | 框选 | 长按后移动触发 |
| 双指开合 | 100ms | 缩放 | 两指距离变化 |
| 双指平移 | 400ms | 画面平移 | 两指同向移动 |

### 2.2 滚动方向

- **自然滚动**（默认）：手指上滑 → 画面向上，手指下滑 → 画面向下
- **反向滚动**（设置开关）：交换方向
- 触摸交互滚动阈值：10px，大位移发送多个滚轮事件
- 两指滚动阈值：15px（累加器模式）

### 2.3 平移边距

- 可超出屏幕边缘 80px
- 回弹时间 1 秒（FRICTION = 0.08）

## 3. 鼠标模式（mouseControlMode === 1）

### 3.1 触摸屏蔽

鼠标模式下屏蔽所有预览区域的触摸事件（`handlePreviewTouch` 直接返回），包括手势识别。所有交互通过虚拟鼠标覆盖层完成。

### 3.2 虚拟鼠标指针

- **样式**：iconoir `cursor-pointer.svg`（白色填充+黑色边框箭头），用 `scale` 变换支持动态大小
- **大小**：`cursorIconSize` @State（16-64，默认28），鼠标设置面板「光标大小」滑条，持久化 `cursor-icon-size`
- **位置**：`cursorScreenX` / `cursorScreenY` 状态变量
- **初始化**：进入鼠标模式时光标初始化到屏幕中心，`hasPointerPosition = true`
- **裁剪**：clip 到实际渲染画面区域（`getVisibleImageBounds()`，含 panOffset）
- **限定**：`getCursorClampBounds()`（不含 panOffset 的基础区域）防止正反馈循环
- **热点**：箭头尖端在 (4.68, 6.26)/24 比例处，热点偏移 (0.195, 0.261)

### 3.3 摇杆

- **位置**：左下角，距边缘 20px
- **底座**：100px 圆形，半透明深色
- **旋钮**：44px 圆形，可拖动
- **最大半径**：28px（角度钳制）
- **触摸跟踪**：`joystickTouchId` 在 Down 时存储 touch ID，Move/Up 时按 ID 查找（不依赖坐标范围过滤）
- **中心坐标**：组件内 (50, 50)

### 3.4 摇杆双模式

| 模式 | 触发条件 | 行为 |
|------|----------|------|
| 光标移动 | 默认 | 更新 cursorScreenX/Y，发送 MOUSE_MASK.MOVE |
| 画面平移 | 按住 P 按钮 | 更新 panOffsetX/Y |

### 3.5 摇杆速度

- **状态变量**：`@State joystickSpeed: number = 5`
- **范围**：1-20，默认 5
- **光标速度公式**：`clampedX * (joystickSpeed / 12.5)`（降低 20% 防止过快）
- **平移速度公式**：`clampedX * (joystickSpeed / 12.5)`
- **持久化**：`joystick-speed` local option
- **UI**：鼠标设置面板「摇杆速度」滑条

### 3.6 光标到边缘自动平移

- 光标到达画面边缘时，excess 位移转化为 panOffset
- 松开摇杆时调用 `startPanSpringBack()` 回弹到限制线
- `getCursorClampBounds()` 不含 panOffset（基础区域），避免正反馈循环
- `getVisibleImageBounds()` 含 panOffset（裁剪区域），用于 clip

### 3.7 按钮布局

**当前布局（菱形，靠右边缘）**：

```
        [M]     ← 最上 (previewWidth - 72, previewHeight - 188)
        [R]     ← M下方 (previewWidth - 72, previewHeight - 130)
[L]     [P]     ← 最底行 (L: previewWidth - 130, P: previewWidth - 72, y: previewHeight - 72)
```

- **按钮大小**：全部 52px 等大
- **M/R/P 一列**：x = previewWidth - 72（靠右边缘，20px 边距）
- **L 在 P 左侧**：x = previewWidth - 130
- **间距**：6px

### 3.8 按钮功能

| 按钮 | 功能 | 触摸处理 |
|------|------|----------|
| L | 鼠标左键 | LEFT_DOWN / LEFT_UP |
| R | 鼠标右键 | RIGHT_DOWN / RIGHT_UP |
| M | 鼠标中键 | MIDDLE_DOWN / MIDDLE_UP |
| P | 画面平移模式开关 | 按下 joystickPanMode=true，抬起 false |

### 3.9 按钮视觉反馈

- 按下时：填充蓝色 `rgba(0, 113, 255, 0.85)`，白色边框
- 释放时：填充深色 `rgba(30, 40, 60, 0.55)`，灰色边框
- 80ms 缓出动画过渡

### 3.10 按钮触摸实现

每个按钮内联三个元素：
1. Circle（视觉，`HitTestMode.Transparent`）
2. Text（标签，`HitTestMode.Transparent`）
3. Column（触摸处理，`HitTestMode.Block`，`onTouch`）

## 4. 悬浮工具栏

### 4.1 收起状态

- 尺寸：60×48px
- 图标：`<>`（iconoir nav-arrow-left/right SVG）
- 位置：`toolbarX` / `toolbarY`，可拖拽

### 4.2 展开状态

- 宽度：`min(previewWidth - 16, 380)`px
- 图标：两端显示 `><` 图标
- 右侧向左展开：`toolbarSide === 'right'` 时 x = `previewWidth - 8 - width`

### 4.3 拖拽行为

- `toolbarTouchStartX/Y` 记录初始触点
- 总位移 > 5px 时不切换展开/收起（防误触）
- 松手时 `snapToolbarToEdge()` 吸附到左/右边缘

### 4.4 位置持久化

- `toolbar-side`：left / right
- `toolbar-y`：Y 坐标
- 启动时从 `getLocalOption` 加载

## 5. 鼠标控制菜单

- **菜单宽度**：260px
- **模式选择**：内联 Row 替换 RadioOptionItem（直接绑定 `this.mouseControlMode`，选中状态立即更新）
- **鼠标模式选中**：关闭菜单 + 收起工具栏
- **鼠标设置**：标题「鼠标设置」+ 三个滑条（灵敏度、滚动速度、摇杆速度）
- **灵敏度和滚动速度**：启动时从 `getLocalOption('mouse-sensitivity')` 和 `getLocalOption('mouse-scroll-speed')` 加载
- **光标大小**：`cursorIconSize`（16-64，默认28），持久化 `cursor-icon-size`

## 5.5 显示菜单

- **缩放/编码选择**：弃用 HarmonyOS Select 组件，改用自定义浮层弹出列表
- **浮层结构**：`Stack` + `zIndex(120)` + `Blank` 居中浮层，点击空白关闭列表
- **背景**：`theme_MENU_BG`，暗色/浅色主题均正确显示
- **远程光标缩放**：`cursorScale`（0.5x-3.0x，默认1.0），持久化 `remote-cursor-scale`
- **远程光标默认样式**：Windows 箭头（`cursor-pointer.svg`），热点修正到箭头尖端

## 6. 连接日志系统

- `Logger.ets`：统一日志工具类（info/warn/error/debug）
- 关于页面「详细连接日志」开关，持久化到 `verbose-connection-log`
- 连接流程、状态转换、会话生命周期详细日志

## 6.5 远程键盘输入

### 6.5.1 大写字母修复

- **Core 修复**（`13_librustdesk_core` commit `b1e0b06`，core-019）：`session_input_key` 中对 `shift && (65..=90).contains(&key_code)` 直接 `key_event.set_chr(key_code as u32)`（如 65='A'），绕过 KEY_MAP 的 `"VK_A" → Key::Chr('a')` 小写映射
- **ArkTS 修复**（`RemoteControl.ets:sendTextPayload`）：
  - 小写字母 a-z（charCode 97-122）→ VK 码 65-90（`vk = code - 32`），modifier=0
  - 大写字母 A-Z（charCode 65-90）→ VK 码不变，modifier=4（Shift）
- **Core modifier 定义**：bit0=Ctrl(1), bit1=Alt(2), bit2=Shift(4), bit3=Command(8)

### 6.5.2 自定义键盘面板

- `buildKeyboardPanel`：包含字母、数字、符号、功能键
- Backspace 按钮：`⌫` 图标，`specialKeys` 映射 `'⌫': 8`（VK_BACKSPACE）

### 6.5.3 IME 代理输入（sentinel 方案）

- **问题**：断开重连后 `imeProxyText` 被重置为空（新页面实例），远端文本框仍有旧内容。Backspace 时 IME 不触发 `onChange`（TextInput 已空），无法发送删除到远端
- **Sentinel 方案**：
  - `@State imeProxyText: string = ' '` — 初始 sentinel（前导空格占位符）
  - `private imeProxyPrev: string = ' '` — 独立前值跟踪（因 `$$` 双向绑定会自动更新 `imeProxyText`）
  - `private imeProxyController: TextInputController = new TextInputController()` — 控制器
  - `TextInput({ text: $$this.imeProxyText, controller: this.imeProxyController })` — 双向绑定
  - `handleImeProxyTextChange`：sentinel 删除时发 `max(realPrev.length, 1)` 个 Backspace，恢复 sentinel + `caretPosition(1)`
  - `onFocus` 中恢复 sentinel；`aboutToAppear` 中重置 `imeProxyText`/`imeProxyPrev`
- **IME 自动补全问题**（部分修复，已搁置）：`isAutoCompletionDeletion` 检测（文本变短 + 插入文本是原文本后缀）时只发长度差个 Backspace。剩余：输入冒号也自动补右括号，自动补的删不掉

## 6.6 共享设置菜单

- 共享页面 logo 右侧三点菜单按钮
- 弹出共享设置弹窗：
  - 访问方式（永久/一次性）
  - 密码设置
  - 密码类型（固定/随机）
- i18n 翻译键已添加到 `I18nService.ets`

## 6.7 构建版本号自增

- `scripts/run_hvigor_with_sdk_patch.js` 是版本号更新的唯一实现，必须同步写入 `AppScope/app.json5` 与 `BuildInfo.ets`。
- 增量构建设置 `RUSTDESK_HARMONY_VERSION_BUMP=incremental`：只将版本尾号加 `1`，例如 `0.34.21 -> 0.34.22`。
- 全量构建设置 `RUSTDESK_HARMONY_VERSION_BUMP=full`：中间版本号加 `1`，尾号归零，例如 `0.34.22 -> 0.35.0`。
- 两种构建的 `versionCode` 都必须单调加 `1`。同一次失败构建的重试使用 `none`，不得再次消耗版本号。
- 当前版本：0.34.27 (1000272)

## 7. I18n 翻译

所有新增字符串的中英文翻译：
- 触摸设置、手势名称、动作名称
- 鼠标模式、摇杆速度、鼠标灵敏度、滚动速度
- 鼠标设置、悬浮工具栏
- 调试日志等

## 8. 已知坑

- **ArkTS 不支持对象字面量作类型声明**：必须用 `interface` 或 `class`
- **ArkTS 不支持 `as` 转换 enum 数组**：需要 `.map()` 转换
- **`SliderChangeMode.OnChange` 不存在**：用 `SliderChangeMode.Moving`
- **`TextAlign.CENTER` 不存在**：用 `TextAlign.Center`（大小写敏感）
- **`stopPropagation` 不存在于 ClickEvent**：用空 `.onClick(() => {})` 拦截
- **`alignItems` 不能用于 Stack**：用 `.alignContent()` 代替
- **`@Prop` 必须用于子组件属性**：否则父状态变化时子组件不更新
- **`@Builder` 方法不能有 `const` 声明**：只能内联值
- **`HitTestMode.Block` 在 overlay Stack 上会阻止子元素接收触摸**
- **构建缓存**：需先删除旧 HAP 文件防止不重新编译
- **hdc install**：需从 HAP 所在目录执行（Push-Location）
- **z-index 冲突**：底部工具栏 zIndex(5) 会遮挡覆盖层按钮，预览区需 zIndex(10)
- **RadioOptionItem 的 @Prop selected 在 @Builder 内不实时更新**：已用内联 Row 替换
- **摇杆触摸过滤用坐标范围 [0,100] 不可靠**：手指超出区域后坐标超出范围，已改用 touch ID 跟踪
- **光标限定范围含 panOffset 会导致正反馈循环**：画面飞走，已解耦为 clamp 用基础区域（不含 panOffset），clip 用可见区域（含 panOffset）
- **HarmonyOS Select 组件 menuBackgroundColor 暗色主题不生效**：已完全弃用 Select 组件，用自定义浮层弹出列表替代
- **ArkTS @Builder 内 Image 对 SVG 的 width/height 动态更新不可靠**：改用 `scale` 变换（固定基础尺寸24 + scale）
- **TextInput 格式化导致光标错位**：三层保障修复（更新前设置 caretPosition + 多次重试 + onTextSelectionChange 检测）
- **聊天工具栏浅色主题配色错误**：`theme_ERROR_TEXT` 误用为背景 → 改用 `theme_ERROR_BG`+`theme_ERROR_TEXT`
- **Core KEY_MAP 字母键映射为小写**：`"VK_A" → Key::Chr('a')` 导致大写字母加 Shift 仍显示小写，需在 `session_input_key` 中对 Shift+字母键直接发送 `chr=key_code`
- **HarmonyOS 软键盘不触发 `onKeyEvent`**：只触发 `onChange` 文本变化回调，`onKeyEvent` 仅捕获物理键盘事件
- **`$$` 双向绑定下不能用 `imeProxyText` 做前值比较**：`$$` 会自动更新 `imeProxyText`，需用独立的 `imeProxyPrev` 变量跟踪前值
- **TextInputController 必须在构造函数中传入**：不能用 `.controller()` 属性方法（编译错误）
- **Sentinel 恢复竞态条件**：设置 `imeProxyText = SENTINEL` 可能同步触发 `onChange`，必须先设置 `imeProxyPrev = SENTINEL` 再设置 `imeProxyText`

## 9. 构建和测试

### 9.1 构建步骤

```powershell
# 1. 恢复签名配置
Copy-Item "E:\Visual_Studio_Code\99_Temp\build-profile-signed.json5" "E:\Visual_Studio_Code\11_Rustdesk_harmonyos\build-profile.json5" -Force

# 2. 删除旧 HAP
Remove-Item "...\entry-default-signed.hap", "...\entry-default-unsigned.hap" -Force

# 3. 构建
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\Visual_Studio_Code\99_Temp\rebuild.ps1"

# 4. 连接设备
hdc tconn 192.168.8.152:36169

# 5. 安装
Push-Location <hap目录>; hdc install entry-default-signed.hap; Pop-Location

# 6. 启动
hdc shell aa start -a EntryAbility -b com.open.rundesk
```

### 9.2 hdc 路径

```
C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe
```

## 10. 关键文件

| 文件 | 说明 |
|------|------|
| `entry/src/main/ets/common/TouchActionConfig.ets` | 触摸动作枚举、手势配置接口、默认配置 |
| `entry/src/main/ets/common/TouchInteractionManager.ets` | 触摸交互状态机管理器 |
| `entry/src/main/ets/common/Logger.ets` | 统一日志工具类 |
| `entry/src/main/ets/pages/RemoteControl.ets` | 主控制页面（覆盖层、摇杆、按钮、工具栏、触摸处理） |
| `entry/src/main/ets/pages/Index.ets` | 首页（连接日志、调试开关） |
| `entry/src/main/ets/services/OfficialRustDeskBridge.ets` | 连接桥（状态转换日志） |
| `entry/src/main/ets/services/I18nService.ets` | 国际化翻译 |
| `entry/src/main/resources/rawfile/nav-arrow-left.svg` | iconoir 左箭头图标 |
| `entry/src/main/resources/rawfile/nav-arrow-right.svg` | iconoir 右箭头图标 |
| `entry/src/main/resources/rawfile/cursor-pointer.svg` | iconoir 鼠标箭头图标（白色填充+黑色边框） |
| `entry/src/main/ets/components/RemoteCursor.ets` | 远程光标组件（cursorScale、Windows 样式图标） |
| `entry/src/main/ets/pages/Chat.ets` | 聊天页面（工具栏主题配色） |

## 11. 需求变更历史

1. 触摸手势设置菜单（7 项手势可配置）
2. 虚拟鼠标覆盖层（摇杆 + 按钮）
3. 连接日志系统
4. 平移边距 80px，回弹 1 秒
5. 滚动方向改为自然滚动（上滑→画面向上）
6. 两指滚动阈值 60px→15px（累加器）
7. 触摸交互滚动阈值 20px→10px，多发滚轮事件
8. 鼠标模式屏蔽所有触摸事件
9. 虚拟鼠标指针（十字线 + 空心圆）
10. PAN 按钮切换摇杆模式（光标/平移）
11. 按钮菱形布局（M 上、R 中、L 左下、P 右下）
12. 摇杆速度可调（1-20 滑条）
13. 按钮内联实现（避免 @Builder 参数问题）
14. z-index 修复（预览区 zIndex(10) 避免工具栏遮挡）
15. 悬浮工具栏（收起/展开、拖拽、位置持久化）
16. 鼠标控制菜单内联 Row（替换 RadioOptionItem）
17. 摇杆 touch ID 跟踪（替换坐标范围过滤）
18. 光标限定到画面区域（getCursorClampBounds / getVisibleImageBounds 解耦）
19. 光标到边缘自动平移 + 松手回弹
20. 摇杆速度公式降低 20%（joystickSpeed / 12.5）
21. 鼠标光标用 iconoir cursor-pointer.svg 替换十字线
22. 光标大小滑条（16-64，默认28，持久化 cursor-icon-size）
23. 远程光标跟随摇杆移动
24. 远程光标缩放滑条（0.5x-3.0x，持久化 remote-cursor-scale）
25. 远程光标默认 Windows 箭头样式
26. 缩放/编码菜单弃用 Select 组件，自定义浮层弹出列表
27. 聊天工具栏浅色主题配色修复
28. ID 输入框光标错位修复（三层保障）
29. 远程键盘大写字母输入修复（Core session_input_key + ArkTS sendTextPayload）
30. IME 代理输入 sentinel 方案（断开重连后 Backspace 可删除远端旧内容）
31. 自定义键盘面板 Backspace 按钮（⌫ → VK_BACKSPACE 8）
32. 共享设置菜单（三点菜单 + 设置弹窗）
33. 构建版本号自增（RUSTDESK_HARMONY_VERSION_BUMP=incremental）
34. IME 自动补全符号删除检测（部分修复，已搁置）
