# Windows 服务关闭优化指南

> 针对低配电脑的 Windows 服务优化方案，安全关闭不必要的后台服务以释放内存和 CPU

## 风险等级说明

- 🟢 **安全**：关闭不影响开发和系统正常使用
- 🟡 **谨慎**：特定场景可能需要，建议按需关闭
- 🔴 **危险**：禁止关闭，会导致系统故障或功能损失

## 推荐关闭的服务（🟢 安全）

### 1. 多媒体和图形相关

| 服务名 | 显示名称 | 内存节省 | 风险 |
|--------|---------|--------|------|
| `DiagTrack` | 诊断跟踪服务 | 20-50MB | 🟢 安全 |
| `dmwappushservice` | dmwappushservice | 10-30MB | 🟢 安全 |
| `MapsBroker` | 地图下载管理器 | 30-50MB | 🟢 安全 |
| `lfsvc` | 位置服务 | 10-20MB | 🟢 安全 |
| `SysMainSvc` | 系统和压缩内存 | 50-100MB | 🟡 谨慎* |

> `SysMainSvc` 可关闭，但关闭后大程序启动会慢，低配可考虑关闭

### 2. 网络和云相关

| 服务名 | 显示名称 | 内存节省 | 说明 |
|--------|---------|--------|------|
| `OneSyncSvc` | 同步主机服务 | 20-40MB | 不用 OneDrive 可关 |
| `wuauserv` | Windows 更新 | 50-100MB | **构建期间建议关闭** |
| `WSearch` | Windows Search 索引 | 100-200MB | 不需要全文搜索可关 |
| `Dnscache` | DNS 客户端 | 10-20MB | 仅关闭缓存，需手动配置 |

### 3. 音频和打印

| 服务名 | 显示名称 | 内存节省 | 风险 |
|--------|---------|--------|------|
| `Audiosrv` | Windows 音频 | 30-50MB | 🟢 若不需要声音 |
| `Spooler` | 打印机后台处理 | 20-40MB | 🟢 无打印机可关 |
| `WinRM` | Windows 远程管理 | 15-30MB | 🟢 不用远程可关 |

### 4. 蓝牙和设备

| 服务名 | 显示名称 | 内存节省 | 风险 |
|--------|---------|--------|------|
| `bthserv` | 蓝牙支持服务 | 10-20MB | 🟢 无蓝牙设备可关 |
| `NaturalAuthentication` | 自然身份验证 | 10-15MB | 🟢 安全 |

## 禁止关闭的服务（🔴 危险）

这些服务对开发环境和系统正常运行至关重要：

```
❌ DoSvc              (交付优化服务)
❌ Ntfs              (NTFS 文件系统)
❌ RpcSs              (RPC 服务)
❌ WinDefend         (Windows Defender)
❌ UserManager       (用户管理)
❌ WdNisSvc          (Defender 网络检查服务)
❌ Themes            (主题服务 - 影响 UI)
❌ Power             (电源管理)
❌ Netlogon          (登录验证)
```

## 快速优化方案

### 方案 A：超级优化（释放 300-500MB）

运行此 PowerShell 脚本：

```powershell
# 以管理员身份运行
$services = @(
    "DiagTrack",
    "dmwappushservice",
    "MapsBroker",
    "lfsvc",
    "OneSyncSvc",
    "WSearch",
    "Spooler",
    "bthserv",
    "NaturalAuthentication"
)

foreach ($service in $services) {
    Write-Host "关闭服务: $service"
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
}

Write-Host "✓ 完成"
```

### 方案 B：保守优化（释放 100-200MB）

仅关闭完全不需要的服务：

```powershell
# 以管理员身份运行
$services = @(
    "DiagTrack",           # 诊断跟踪
    "dmwappushservice",    # 推送通知
    "MapsBroker",          # 地图
    "bthserv"              # 蓝牙（假设无蓝牙设备）
)

foreach ($service in $services) {
    Write-Host "关闭服务: $service"
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
}

Write-Host "✓ 完成"
```

### 方案 C：构建期间临时优化（释放 200MB）

在构建前临时关闭 Windows 更新：

```powershell
# 以管理员身份运行
# 停止 Windows 更新服务
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name UsoSvc -Force -ErrorAction SilentlyContinue

# 构建完成后恢复
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Service -Name UsoSvc -ErrorAction SilentlyContinue
```

## 恢复方法

### 恢复单个服务

```powershell
# 以管理员身份运行
Set-Service -Name <服务名> -StartupType Automatic
Start-Service -Name <服务名>
```

### 恢复全部服务

```powershell
# 系统还原（最安全）
# 设置 > 系统 > 恢复 > 打开系统还原 > 选择还原点

# 或通过 PowerShell 逐个启用
$services = @("DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc", "OneSyncSvc", "WSearch", "Spooler", "bthserv", "NaturalAuthentication")

foreach ($service in $services) {
    Set-Service -Name $service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $service -ErrorAction SilentlyContinue
}
```

## 监控效果

### 查看内存变化

```powershell
# 关闭前
[System.Diagnostics.Process]::GetCurrentProcess().WorkingSet / 1MB

# 查看所有进程内存占用
Get-Process | Sort-Object WorkingSet -Descending | 
  Select-Object -First 10 ProcessName, @{N="Memory(MB)";E={[math]::Round($_.WorkingSet/1MB)}}
```

### 查看服务状态

```powershell
# 查看禁用的服务
Get-Service | Where-Object {$_.StartType -eq "Disabled"} | 
  Select-Object Name, DisplayName
```

## 配置优化（额外效果）

### 关闭视觉效果

**设置 > 系统 > 关于 > 高级系统设置 > 性能 > 设置**

选择"调整为最佳性能"，释放 50-100MB 内存

### 禁用动画和透明

```powershell
# 注册表优化（以管理员身份）
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90, 0x12, 0x03, 0x80))
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaEnabled" -Value 0
```

### 关闭防火墙（仅在离线开发时）

```powershell
# ⚠ 仅在确认网络隔离的情况下使用
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled $false
```

## 开发工作流中的服务优化

### 构建前检查清单

```batch
REM 临时优化脚本：build_with_service_optimization.bat
@echo off

REM 1. 关闭不必要的服务
powershell -Command "Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue"
powershell -Command "Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue"

REM 2. 清理内存
powershell -Command "[System.GC]::Collect()"

REM 3. 执行构建
call scripts\build_hap_lowmem.bat

REM 4. 恢复服务
powershell -Command "Start-Service -Name wuauserv -ErrorAction SilentlyContinue"
powershell -Command "Start-Service -Name WSearch -ErrorAction SilentlyContinue"
```

## 常见问题

**Q：能关闭 Windows Defender 吗？**  
A：❌ 不建议。如果一定要关闭，使用 `Set-MpPreference -DisableRealtimeMonitoring $true`（临时）。构建完成后务必恢复。

**Q：关闭 Windows Search 后文件搜索会怎样？**  
A：✅ 文件夹搜索仍可用，只是速度会慢。对开发工作影响不大。

**Q：关闭这些服务后网络会受影响吗？**  
A：❌ 关闭的服务与核心网络无关，网络正常工作。

**Q：如何快速恢复到原始状态？**  
A：使用"系统还原"功能或逐个启用被禁用的服务。

## 预期效果

| 优化方案 | 内存释放 | 构建速度 | 完成时间 |
|---------|--------|--------|--------|
| 无优化 | - | 基准 | - |
| 方案 B（保守） | 100-200MB | +10% | 3-5 天 |
| 方案 A（激进） | 300-500MB | +20-30% | 1-2 天 |
| A + Cargo 并发限制 | 400-600MB | +50-80% | 立即 |

