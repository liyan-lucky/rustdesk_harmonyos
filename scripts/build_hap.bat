@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_NAME=%%~nxI"
for %%I in ("%PROJECT_ROOT%\..\99_Temp") do set "TEMP_ROOT=%%~fI"
for %%I in ("%PROJECT_ROOT%\..\99_Temp\harmonyos_stage\%PROJECT_NAME%") do set "STAGE_ROOT=%%~fI"

if not defined RUSTDESK_HARMONY_TEMP_ROOT set "RUSTDESK_HARMONY_TEMP_ROOT=%TEMP_ROOT%"
if not defined BUILD_CACHE_DIR set "BUILD_CACHE_DIR=%RUSTDESK_HARMONY_TEMP_ROOT%\harmonyos_cache"
if not defined CI set "CI=true"
if not exist "%BUILD_CACHE_DIR%" mkdir "%BUILD_CACHE_DIR%" >nul 2>nul

set "NODE_EXE="
if defined DEVECO_NODE_EXE if exist "%DEVECO_NODE_EXE%" set "NODE_EXE=%DEVECO_NODE_EXE%"
if not defined NODE_EXE if exist "%PROJECT_ROOT%\local.properties" (
  set "LOCAL_NPM_DIR="
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b "npm.dir=" "%PROJECT_ROOT%\local.properties"`) do set "LOCAL_NPM_DIR=%%B"
  if defined LOCAL_NPM_DIR (
    call set "LOCAL_NPM_DIR=%%LOCAL_NPM_DIR:\\=\%%"
    if exist "!LOCAL_NPM_DIR!\node.exe" set "NODE_EXE=!LOCAL_NPM_DIR!\node.exe"
  )
)
if not defined NODE_EXE if exist "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" set "NODE_EXE=C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
if not defined NODE_EXE for /f "delims=" %%N in ('where node 2^>nul') do if not defined NODE_EXE set "NODE_EXE=%%N"
if not defined NODE_EXE (
  echo node was not found. Set DEVECO_NODE_EXE or add node to PATH.
  exit /b 1
)

call powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\fetch_native_core.ps1"
if errorlevel 1 exit /b 1

echo Incremental HAP build for %PROJECT_ROOT%
set "BUILD_PROJECT_ROOT=%PROJECT_ROOT%"
if not defined RUSTDESK_HARMONY_DISABLE_STAGE (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\stage_project_for_build.ps1" -StageRoot "%STAGE_ROOT%"
  if errorlevel 1 exit /b 1
  set "BUILD_PROJECT_ROOT=%STAGE_ROOT%"
)
set "RUSTDESK_HARMONY_VERSION_BUMP=incremental"
set "HVIGOR_LOG=%TEMP%\rustdesk_harmonyos_hvigor_%RANDOM%_%RANDOM%.log"
pushd "!BUILD_PROJECT_ROOT!" >nul || exit /b 1
"%NODE_EXE%" scripts\run_hvigor_with_sdk_patch.js assembleHap > "%HVIGOR_LOG%" 2>&1
set "BUILD_EXIT=!ERRORLEVEL!"
popd >nul
type "%HVIGOR_LOG%"
findstr /c:"ERROR: BUILD FAILED" /c:"ERROR: Failed" /c:"Configuration Error" "%HVIGOR_LOG%" >nul 2>nul
if not errorlevel 1 set "BUILD_EXIT=1"
del "%HVIGOR_LOG%" >nul 2>nul
if not "!BUILD_EXIT!"=="0" exit /b !BUILD_EXIT!
if /I not "!BUILD_PROJECT_ROOT!"=="%PROJECT_ROOT%" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\sync_build_version_from_stage.ps1" -StageRoot "!BUILD_PROJECT_ROOT!"
  if errorlevel 1 exit /b 1
)

echo Incremental HAP build completed. BuildInfo.ets was updated by run_hvigor_with_sdk_patch.js.
exit /b 0
