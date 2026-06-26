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

set "ABI_FILTER=%~1"
if /I "%ABI_FILTER%"=="arm64" set "ABI_FILTER=arm64-v8a"
if /I "%ABI_FILTER%"=="x86" set "ABI_FILTER=x86_64"
if /I "%ABI_FILTER%"=="x86_64" set "ABI_FILTER=x86_64"
if /I "%ABI_FILTER%"=="arm64-v8a" set "ABI_FILTER=arm64-v8a"
if /I "%ABI_FILTER%"=="both" set "ABI_FILTER="
if /I "%ABI_FILTER%"=="all" set "ABI_FILTER="
if /I "%ABI_FILTER%"=="" set "ABI_FILTER="

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

if not defined DEVECO_SDK_HOME if exist "C:\Program Files\Huawei\DevEco Studio\sdk\default" set "DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk\default"
if not defined JAVA_HOME if exist "C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe" set "JAVA_HOME=C:\Program Files\Huawei\DevEco Studio\jbr"
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

call powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\fetch_native_core.ps1"
if errorlevel 1 exit /b 1

if defined ABI_FILTER (
  echo Full HAP rebuild for %PROJECT_ROOT% ^(ABI: %ABI_FILTER%^)
) else (
  echo Full HAP rebuild for %PROJECT_ROOT% ^(ABI: arm64-v8a + x86_64^)
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\clean_project.ps1" -IncludeExternalBuild
if errorlevel 1 exit /b 1

set "BUILD_PROJECT_ROOT=%PROJECT_ROOT%"
if not defined RUSTDESK_HARMONY_DISABLE_STAGE (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\stage_project_for_build.ps1" -StageRoot "%STAGE_ROOT%"
  if errorlevel 1 exit /b 1
  set "BUILD_PROJECT_ROOT=%STAGE_ROOT%"
)

set "RUSTDESK_HARMONY_VERSION_BUMP=full"
set "OUTPUT_DIR=%RUSTDESK_HARMONY_TEMP_ROOT%\harmonyos_build\%PROJECT_NAME%\entry\build\default\outputs\default"

if defined ABI_FILTER (
  call :build_single_abi "%ABI_FILTER%"
  if errorlevel 1 exit /b 1
) else (
  call :build_single_abi "arm64-v8a"
  if errorlevel 1 exit /b 1
  call :build_single_abi "x86_64"
  if errorlevel 1 exit /b 1
)

echo Full HAP rebuild completed. BuildInfo.ets was updated by run_hvigor_with_sdk_patch.js.
exit /b 0

:build_single_abi
set "TARGET_ABI=%~1"
echo --- Building %TARGET_ABI% HAP (full) ---

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$bp = '%BUILD_PROJECT_ROOT:\=\\%\\entry\\build-profile.json5'; " ^
  "$content = Get-Content $bp -Raw; " ^
  "$content = $content -replace '\"abiFilters\"\s*:\s*\[[^\]]*\]', ('\"abiFilters\": [\"' + '%TARGET_ABI%' + '\"]'); " ^
  "Set-Content $bp $content -NoNewline; " ^
  "Write-Host 'Patched abiFilters to: %TARGET_ABI%'"

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

set "ABI_SUFFIX="
if /I "%TARGET_ABI%"=="arm64-v8a" set "ABI_SUFFIX=-arm64"
if /I "%TARGET_ABI%"=="x86_64" set "ABI_SUFFIX=-x86_64"

if exist "%OUTPUT_DIR%\entry-default-signed.hap" (
  move /y "%OUTPUT_DIR%\entry-default-signed.hap" "%OUTPUT_DIR%\entry-default-signed%ABI_SUFFIX%.hap" >nul 2>nul
  echo Renamed: entry-default-signed%ABI_SUFFIX%.hap
)
if exist "%OUTPUT_DIR%\entry-default-unsigned.hap" (
  move /y "%OUTPUT_DIR%\entry-default-unsigned.hap" "%OUTPUT_DIR%\entry-default-unsigned%ABI_SUFFIX%.hap" >nul 2>nul
  echo Renamed: entry-default-unsigned%ABI_SUFFIX%.hap
)

echo --- %TARGET_ABI% HAP build completed (full) ---
exit /b 0
