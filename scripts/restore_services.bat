@echo off
REM Windows 服务恢复脚本 - 恢复被关闭的后台服务
REM 用法: 以管理员身份运行 scripts/restore_services.bat
REM 效果: 将所有服务恢复为默认启动状态

setlocal enabledelayedexpansion

echo.
echo ========================================
echo Windows 服务恢复
echo ========================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] 此脚本需要管理员权限运行！
    echo 请右键点击此脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo [INFO] 开始恢复服务...
echo.

REM 恢复诊断跟踪服务
echo [1/8] 恢复诊断跟踪服务...
sc config DiagTrack start= auto >nul 2>&1
net start DiagTrack >nul 2>&1
echo     ✓ DiagTrack

REM 恢复推送通知服务
echo [2/8] 恢复推送通知服务...
sc config dmwappushservice start= auto >nul 2>&1
net start dmwappushservice >nul 2>&1
echo     ✓ dmwappushservice

REM 恢复地图下载管理器
echo [3/8] 恢复地图服务...
sc config MapsBroker start= auto >nul 2>&1
net start MapsBroker >nul 2>&1
echo     ✓ MapsBroker

REM 恢复定位服务
echo [4/8] 恢复定位服务...
sc config lfsvc start= auto >nul 2>&1
net start lfsvc >nul 2>&1
echo     ✓ lfsvc

REM 恢复 Windows 搜索
echo [5/8] 恢复 Windows 搜索索引...
sc config WSearch start= auto >nul 2>&1
net start WSearch >nul 2>&1
echo     ✓ WSearch

REM 恢复打印机后台处理
echo [6/8] 恢复打印机服务...
sc config Spooler start= auto >nul 2>&1
net start Spooler >nul 2>&1
echo     ✓ Spooler

REM 恢复蓝牙支持
echo [7/8] 恢复蓝牙服务...
sc config bthserv start= auto >nul 2>&1
net start bthserv >nul 2>&1
echo     ✓ bthserv

REM 恢复自然身份验证
echo [8/8] 恢复自然身份验证...
sc config NaturalAuthentication start= auto >nul 2>&1
net start NaturalAuthentication >nul 2>&1
echo     ✓ NaturalAuthentication

echo.
echo ========================================
echo [SUCCESS] 服务恢复完成！
echo ========================================
echo.
echo 建议重启电脑以确保所有服务正常工作。
echo.

pause
endlocal
