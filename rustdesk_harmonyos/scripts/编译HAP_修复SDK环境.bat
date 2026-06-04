@echo off
setlocal

set "PROJECT_ROOT=E:\Visual_Studio_Code\11_Rustdesk"
set "HARMONY_PROJECT=%PROJECT_ROOT%\rustdesk_harmonyos"
set "FIXED_SDK_ROOT=%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\deveco-sdk-fixed"
set "FIXED_OHOS_SDK=%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\openharmony"
set "NODE_EXE=C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
set "HVIGOR_JS=C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js"

if not exist "%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\sdk-pkg.json" (
  echo Fixed SDK metadata not found:
  echo   %FIXED_SDK_ROOT%\HarmonyOS-6.0.2\sdk-pkg.json
  exit /b 1
)

set "DEVECO_SDK_HOME=%FIXED_SDK_ROOT%"
set "OHOS_BASE_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_NDK_HOME=%FIXED_OHOS_SDK%"

cd /d "%HARMONY_PROJECT%"

echo Using DEVECO_SDK_HOME=%DEVECO_SDK_HOME%
echo Using OHOS_BASE_SDK_HOME=%OHOS_BASE_SDK_HOME%
echo.

REM Update build time
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set BUILD_DATE=%%a-%%b-%%c
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set BUILD_TIME=%%a:%%b
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set datetime=%%a
set BUILD_TIMESTAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2% %datetime:~8,2%:%datetime:~10,2%

set "BUILD_INFO_FILE=%HARMONY_PROJECT%\entry\src\main\ets\common\BuildInfo.ets"
echo export class BuildInfo { > "%BUILD_INFO_FILE%"
echo   static readonly BUILD_TIME: string = '%BUILD_TIMESTAMP%'; >> "%BUILD_INFO_FILE%"
echo   static readonly VERSION: string = '0.4.0'; >> "%BUILD_INFO_FILE%"
echo } >> "%BUILD_INFO_FILE%"
echo Updated build time: %BUILD_TIMESTAMP%
echo.

REM Clean output directory
set "OUTPUT_DIR=%HARMONY_PROJECT%\entry\build\default\outputs\default"
if exist "%OUTPUT_DIR%" rd /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%" 2>nul

"%NODE_EXE%" "%HVIGOR_JS%" --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone assembleHap --analyze=normal --parallel --no-daemon

REM Check and copy HAP from hvigor cache
if not exist "%OUTPUT_DIR%\entry-default-signed.hap" (
  echo Searching for generated HAP...
  for /r "%HARMONY_PROJECT%\.hvigor" %%f in (*.hap) do (
    echo Found: %%f
    copy "%%f" "%OUTPUT_DIR%\entry-default-signed.hap" >nul
  )
)

if exist "%OUTPUT_DIR%\entry-default-signed.hap" (
  echo HAP created: %OUTPUT_DIR%\entry-default-signed.hap
) else (
  echo WARNING: HAP file not found in expected location
)
exit /b %errorlevel%
