@echo off
setlocal enabledelayedexpansion

echo ========================================
echo RustDesk HarmonyOS 自动构建安装脚本
echo 时间: 2026-05-05
echo ========================================
echo.

set "PROJECT_ROOT=E:\Visual_Studio_Code\11_Rustdesk"
set "HARMONY_PROJECT=%PROJECT_ROOT%\rustdesk_harmonyos"
set "FIXED_SDK_ROOT=%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\deveco-sdk-fixed"
set "FIXED_OHOS_SDK=%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\openharmony"
set "NODE_EXE=C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
set "HVIGOR_JS=C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js"
set "HDC=C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVICE_TARGET=192.168.11.101:33839"

echo [步骤 1/5] 检查环境...
if not exist "%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\sdk-pkg.json" (
    echo 错误: SDK不存在
    pause
    exit /b 1
)
echo SDK检查通过

if not exist "%NODE_EXE%" (
    echo 错误: Node.js不存在
    pause
    exit /b 1
)
echo Node.js检查通过

echo.
echo [步骤 2/5] 设置环境变量...
set "DEVECO_SDK_HOME=%FIXED_SDK_ROOT%"
set "OHOS_BASE_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_NDK_HOME=%FIXED_OHOS_SDK%"
echo 环境变量设置完成

echo.
echo [步骤 2.5/6] 更新构建时间...
set "BUILD_INFO=%HARMONY_PROJECT%\entry\src\main\ets\common\BuildInfo.ets"
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set BUILD_DATE=%%a-%%b-%%c
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set BUILD_TIME=%%a:%%b
set BUILD_TIMESTAMP=%BUILD_DATE% %BUILD_TIME%
echo 构建时间: %BUILD_TIMESTAMP%
echo export class BuildInfo { > "%BUILD_INFO%"
echo   static readonly BUILD_TIME: string = '%BUILD_TIMESTAMP%'; >> "%BUILD_INFO%"
echo   static readonly VERSION: string = '0.4.0'; >> "%BUILD_INFO%"
echo } >> "%BUILD_INFO%"
echo 构建时间已更新

echo.
echo [步骤 3/6] 构建HAP...
cd /d "%HARMONY_PROJECT%"
echo 当前目录: %CD%
echo 开始构建...

"%NODE_EXE%" "%HVIGOR_JS%" --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone assembleHap --analyze=normal --parallel --incremental --daemon

if errorlevel 1 (
    echo.
    echo 错误: HAP构建失败
    pause
    exit /b 1
)

echo.
echo [步骤 4/5] 验证构建产物...
set "HAP_FILE=%HARMONY_PROJECT%\entry\build\default\outputs\default\entry-default-signed.hap"
if not exist "%HAP_FILE%" (
    echo 错误: HAP文件不存在
    pause
    exit /b 1
)

for %%A in ("%HAP_FILE%") do (
    set HAP_SIZE=%%~zA
    set HAP_TIME=%%~tA
)
echo HAP文件: %HAP_FILE%
echo 文件大小: !HAP_SIZE! 字节
echo 修改时间: !HAP_TIME!

echo.
echo [步骤 5/5] 安装到设备...
echo 目标设备: %DEVICE_TARGET%

echo 检查设备连接...
"%HDC%" -t %DEVICE_TARGET% shell echo "设备连接正常" 2>nul
if errorlevel 1 (
    echo 警告: 设备未连接，尝试列出可用设备...
    "%HDC%" list targets
    echo.
    echo 请确认设备IP和端口，然后手动安装:
    echo %HDC% install -r "%HAP_FILE%"
    pause
    exit /b 0
)

echo 卸载旧版本...
"%HDC%" -t %DEVICE_TARGET% uninstall com.open.rundesk 2>nul

echo 安装新版本...
"%HDC%" -t %DEVICE_TARGET% install -r "%HAP_FILE%"
if errorlevel 1 (
    echo 错误: 安装失败
    pause
    exit /b 1
)

echo.
echo 启动应用...
"%HDC%" -t %DEVICE_TARGET% shell aa start -a EntryAbility -b com.open.rundesk
if errorlevel 1 (
    echo 警告: 启动失败，请手动启动应用
)

echo.
echo ========================================
echo 构建安装完成！
echo ========================================
echo.
echo 测试步骤:
echo 1. 在设备上打开RustDesk应用
echo 2. 查看首页显示的设备ID
echo 3. 输入远端设备ID进行连接
echo 4. 观察视频画面是否实时更新
echo 5. 测试鼠标键盘输入
echo.
echo 查看日志:
echo %HDC% -t %DEVICE_TARGET% shell hilog -x ^| findstr "pullLatest frameId"
echo.

pause
