@echo off
setlocal enabledelayedexpansion

echo ========================================
echo RustDesk HarmonyOS HAP安装脚本
echo ========================================
echo.

set "PROJECT_ROOT=E:\Visual_Studio_Code\11_Rustdesk"
set "HAP_FILE=%PROJECT_ROOT%\rustdesk_harmonyos\entry\build\default\outputs\default\entry-default-signed.hap"
set "HDC=C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
set "PACKAGE_NAME=com.open.rundesk"
set "ABILITY_NAME=EntryAbility"

echo [步骤 1/4] 检查HAP文件...
if not exist "%HAP_FILE%" (
    echo 错误: HAP文件不存在
    echo 路径: %HAP_FILE%
    echo.
    echo 请先构建HAP:
    echo   编译HAP_修复SDK环境.bat
    pause
    exit /b 1
)

for %%A in ("%HAP_FILE%") do (
    set HAP_SIZE=%%~zA
    set HAP_TIME=%%~tA
)
echo HAP文件: %HAP_FILE%
echo 文件大小: !HAP_SIZE! 字节 (约 !HAP_SIZE:~0,-6! MB)
echo 修改时间: !HAP_TIME!
echo.

echo [步骤 2/4] 检查设备连接...
"%HDC%" list targets
echo.

echo 请输入设备地址 (格式: IP:端口，如 192.168.11.100:34767)
echo 或直接按回车使用默认地址...
set /p DEVICE_TARGET="设备地址: "

if "!DEVICE_TARGET!"=="" (
    set DEVICE_TARGET=192.168.11.100:34767
    echo 使用默认地址: !DEVICE_TARGET!
)

echo.
echo 测试设备连接...
"%HDC%" -t !DEVICE_TARGET! shell echo "连接成功" 2>nul
if errorlevel 1 (
    echo 错误: 无法连接到设备 !DEVICE_TARGET!
    echo.
    echo 请检查:
    echo 1. 设备是否开机
    echo 2. 网络是否连接
    echo 3. IP和端口是否正确
    echo 4. HDC工具是否可用
    pause
    exit /b 1
)
echo 设备连接正常
echo.

echo [步骤 3/4] 安装HAP...
echo 卸载旧版本...
"%HDC%" -t !DEVICE_TARGET! uninstall %PACKAGE_NAME% 2>nul
echo.

echo 安装新版本...
"%HDC%" -t !DEVICE_TARGET! install -r "%HAP_FILE%"
if errorlevel 1 (
    echo 错误: 安装失败
    pause
    exit /b 1
)
echo 安装成功
echo.

echo [步骤 4/4] 启动应用...
"%HDC%" -t !DEVICE_TARGET! shell aa start -a %ABILITY_NAME% -b %PACKAGE_NAME%
if errorlevel 1 (
    echo 警告: 启动失败，请手动启动应用
) else (
    echo 应用已启动
)

echo.
echo ========================================
echo 安装完成！
echo ========================================
echo.
echo 应用信息:
echo   包名: %PACKAGE_NAME%
echo   Ability: %ABILITY_NAME%
echo.
echo 测试步骤:
echo 1. 在设备上查看RustDesk应用
echo 2. 检查首页显示的设备ID
echo 3. 输入远端设备ID进行连接
echo 4. 观察视频画面是否实时更新
echo.
echo 查看日志:
echo   %HDC% -t !DEVICE_TARGET! shell hilog -x ^| findstr "pullLatest frameId"
echo.

pause
