@echo off
setlocal

set "PROJECT_ROOT=E:\Visual_Studio_Code\11_Rustdesk"
set "FIXED_SDK_ROOT=%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\deveco-sdk-fixed"
set "FIXED_OHOS_SDK=%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\openharmony"
set "DEVECO_EXE=C:\Program Files\Huawei\DevEco Studio\bin\devecostudio64.exe"

if not exist "%DEVECO_EXE%" (
  echo DevEco Studio not found:
  echo   %DEVECO_EXE%
  exit /b 1
)

if not exist "%FIXED_SDK_ROOT%\HarmonyOS-6.0.2\sdk-pkg.json" (
  echo Fixed SDK metadata not found:
  echo   %FIXED_SDK_ROOT%\HarmonyOS-6.0.2\sdk-pkg.json
  exit /b 1
)

set "DEVECO_SDK_HOME=%FIXED_SDK_ROOT%"
set "OHOS_BASE_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_SDK_HOME=%FIXED_OHOS_SDK%"
set "OHOS_NDK_HOME=%FIXED_OHOS_SDK%"

start "" "%DEVECO_EXE%" "%PROJECT_ROOT%\rustdesk_harmonyos"
