@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"

set "NODE_EXE="
if defined DEVECO_NODE_EXE if exist "%DEVECO_NODE_EXE%" set "NODE_EXE=%DEVECO_NODE_EXE%"
if not defined NODE_EXE if exist "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" set "NODE_EXE=C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
if not defined NODE_EXE for /f "delims=" %%N in ('where node 2^>nul') do if not defined NODE_EXE set "NODE_EXE=%%N"
if not defined NODE_EXE (
  echo node was not found. Set DEVECO_NODE_EXE or add node to PATH.
  exit /b 1
)

echo Incremental HAP build for %PROJECT_ROOT%
pushd "%PROJECT_ROOT%" >nul || exit /b 1
"%NODE_EXE%" scripts\run_hvigor_with_sdk_patch.js assembleHap
set "BUILD_EXIT=!ERRORLEVEL!"
popd >nul
if not "!BUILD_EXIT!"=="0" exit /b !BUILD_EXIT!

echo Incremental HAP build completed. BuildInfo.ets was updated by run_hvigor_with_sdk_patch.js.
exit /b 0
