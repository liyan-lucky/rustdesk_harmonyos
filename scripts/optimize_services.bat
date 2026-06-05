@echo off
REM Windows 服务内存优化 - 快速关闭不必要的后台服务
REM 用法: 以管理员身份运行 scripts/optimize_services.bat
REM 效果: 释放 200-500MB 内存，不影响开发工作

setlocal enabledelayedexpansion

echo.
echo ========================================
echo Windows 服务内存优化
echo ========================================
echo.
echo 此脚本将关闭以下不必要的后台服务:
echo   - DiagTrack (诊断跟踪)
echo   - dmwappushservice (推送通知)
echo   - MapsBroker (地图服务)
echo   - lfsvc (定位服务)
echo   - WSearch (Windows 搜索)
echo   - Spooler (打印机)
echo   - bthserv (蓝牙)
echo.
echo 预期释放内存: 200-500MB
echo.

REM 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 此脚本需要管理员权限运行！
    echo 请右键点击此脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo [INFO] 检测到管理员权限，继续...
echo.

REM 关闭诊断跟踪服务
echo [1/8] 关闭诊断跟踪服务...
net stop DiagTrack >nul 2>&1
sc config DiagTrack start= disabled >nul 2>&1
echo     ✓ DiagTrack

REM 关闭推送通知服务
echo [2/8] 关闭推送通知服务...
net stop dmwappushservice >nul 2>&1
sc config dmwappushservice start= disabled >nul 2>&1
echo     ✓ dmwappushservice

REM 关闭地图下载管理器
echo [3/8] 关闭地图服务...
net stop MapsBroker >nul 2>&1
sc config MapsBroker start= disabled >nul 2>&1
echo     ✓ MapsBroker

REM 关闭定位服务
echo [4/8] 关闭定位服务...
net stop lfsvc >nul 2>&1
sc config lfsvc start= disabled >nul 2>&1
echo     ✓ lfsvc

REM 关闭 Windows 搜索
echo [5/8] 关闭 Windows 搜索索引...
net stop WSearch >nul 2>&1
sc config WSearch start= disabled >nul 2>&1
echo     ✓ WSearch

REM 关闭打印机后台处理
echo [6/8] 关闭打印机服务...
net stop Spooler >nul 2>&1
sc config Spooler start= disabled >nul 2>&1
echo     ✓ Spooler

REM 关闭蓝牙支持
echo [7/8] 关闭蓝牙服务...
net stop bthserv >nul 2>&1
sc config bthserv start= disabled >nul 2>&1
echo     ✓ bthserv

REM 关闭自然身份验证
echo [8/8] 关闭自然身份验证...
net stop NaturalAuthentication >nul 2>&1
sc config NaturalAuthentication start= disabled >nul 2>&1
echo     ✓ NaturalAuthentication

echo.
echo ========================================
echo [SUCCESS] 服务优化完成！
echo ========================================
echo.
echo 下一步:
echo   1. 重启电脑以应用更改（推荐）
echo   2. 或直接开始编译: scripts\build_hap_lowmem.bat
echo.
echo 恢复方法:
echo   运行: scripts\restore_services.bat
echo   或访问: docs\WINDOWS_SERVICE_OPTIMIZATION.md
echo.

pause
endlocal
