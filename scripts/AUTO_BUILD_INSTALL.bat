@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "PROJECT_ROOT=%%~fI"
for %%I in ("%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build") do set "BUILD_ROOT=%%~fI"
for %%I in ("%PROJECT_ROOT%\..\99_Temp\harmonyos_build\rustdesk_harmonyos") do set "HARMONY_BUILD_ROOT=%%~fI"
for %%I in ("%PROJECT_ROOT%\..") do set "WORKSPACE_ROOT=%%~fI"

set "TARGET=%~1"
set "SKIP_BUILD="
set "FULL_BUILD="
if /I "%TARGET%"=="--skip-build" (
  set "SKIP_BUILD=1"
  set "TARGET=%~2"
)
if /I "%TARGET%"=="--full" (
  set "FULL_BUILD=1"
  set "TARGET=%~2"
)
if /I "%TARGET%"=="auto" set "TARGET="

set "NODE_EXE="
if defined DEVECO_NODE_EXE if exist "%DEVECO_NODE_EXE%" set "NODE_EXE=%DEVECO_NODE_EXE%"
if not defined NODE_EXE if exist "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" set "NODE_EXE=C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
if not defined NODE_EXE for /f "delims=" %%N in ('where node 2^>nul') do if not defined NODE_EXE set "NODE_EXE=%%N"
if not defined NODE_EXE (
  echo node was not found. Set DEVECO_NODE_EXE or add node to PATH.
  exit /b 1
)

set "HDC="
if defined HDC_EXE if exist "%HDC_EXE%" set "HDC=%HDC_EXE%"
if not defined HDC if exist "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" set "HDC=C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
if not defined HDC for /f "delims=" %%H in ('where hdc 2^>nul') do if not defined HDC set "HDC=%%H"
if not defined HDC (
  echo hdc was not found. Set HDC_EXE or add hdc to PATH.
  exit /b 1
)

set "USB_TARGET=%RUSTDESK_HARMONY_USB_TARGET%"
if not defined USB_TARGET set "USB_TARGET=2NX0224429035123"
set "WIRELESS_TARGET=%RUSTDESK_HARMONY_WIRELESS_TARGET%"
if not defined WIRELESS_TARGET set "WIRELESS_TARGET=192.168.11.100:36169"
set "HDC_LOG=%TEMP%\rustdesk_harmonyos_hdc_%RANDOM%_%RANDOM%.log"
set "TARGETS_LOG=%TEMP%\rustdesk_harmonyos_targets_%RANDOM%_%RANDOM%.log"

"%HDC%" start >nul 2>nul

if defined TARGET (
  echo Requested target: %TARGET%
  echo %TARGET% | findstr /c:":" >nul 2>nul
  if not errorlevel 1 "%HDC%" tconn "%TARGET%" >nul 2>nul
  "%HDC%" -t "%TARGET%" shell echo ok > "%HDC_LOG%" 2>&1
  set "TARGET_CHECK_EXIT=!ERRORLEVEL!"
  findstr /c:"[Fail]" /c:"error:" /c:"failed" "%HDC_LOG%" >nul 2>nul
  if not errorlevel 1 set "TARGET_CHECK_EXIT=1"
  if not "!TARGET_CHECK_EXIT!"=="0" (
    echo Requested target is not available, falling back to auto target selection.
    type "%HDC_LOG%"
    set "TARGET="
  )
)

if not defined TARGET (
  "%HDC%" list targets > "%TARGETS_LOG%" 2>&1
  findstr /x /c:"%USB_TARGET%" "%TARGETS_LOG%" >nul 2>nul
  if not errorlevel 1 set "TARGET=%USB_TARGET%"
)

if not defined TARGET (
  "%HDC%" tconn "%WIRELESS_TARGET%" >nul 2>nul
  "%HDC%" list targets > "%TARGETS_LOG%" 2>&1
  findstr /x /c:"%WIRELESS_TARGET%" "%TARGETS_LOG%" >nul 2>nul
  if not errorlevel 1 set "TARGET=%WIRELESS_TARGET%"
)

if not defined TARGET (
  for /f "usebackq delims=" %%T in ("%TARGETS_LOG%") do (
    if not defined TARGET if not "%%T"=="" set "TARGET=%%T"
  )
)

if not defined TARGET (
  echo No HDC target is available.
  echo Tried USB target: %USB_TARGET%
  echo Tried wireless target: %WIRELESS_TARGET%
  echo Current hdc targets:
  type "%TARGETS_LOG%"
  del "%HDC_LOG%" >nul 2>nul
  del "%TARGETS_LOG%" >nul 2>nul
  exit /b 1
)

echo Project: %PROJECT_ROOT%
echo Target : %TARGET%

if not defined SKIP_BUILD (
  if defined FULL_BUILD (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\clean_project.ps1" -IncludeExternalBuild
    if errorlevel 1 exit /b 1
  )
  pushd "%PROJECT_ROOT%" >nul || exit /b 1
  "%NODE_EXE%" scripts\run_hvigor_with_sdk_patch.js assembleHap
  set "BUILD_EXIT=!ERRORLEVEL!"
  popd >nul
  if not "!BUILD_EXIT!"=="0" exit /b !BUILD_EXIT!
)

set "HAP_FILE="
if defined RUSTDESK_HARMONY_SIGNED_HAP if exist "%RUSTDESK_HARMONY_SIGNED_HAP%" set "HAP_FILE=%RUSTDESK_HARMONY_SIGNED_HAP%"
if not defined HAP_FILE if exist "%PROJECT_ROOT%\entry\build\default\outputs\default\entry-default-signed.hap" set "HAP_FILE=%PROJECT_ROOT%\entry\build\default\outputs\default\entry-default-signed.hap"
if not defined HAP_FILE if exist "%HARMONY_BUILD_ROOT%\entry\build\default\outputs\default\entry-default-signed.hap" set "HAP_FILE=%HARMONY_BUILD_ROOT%\entry\build\default\outputs\default\entry-default-signed.hap"
if not defined HAP_FILE if exist "%BUILD_ROOT%\windows_hap\entry-default-signed.hap" set "HAP_FILE=%BUILD_ROOT%\windows_hap\entry-default-signed.hap"
if not defined HAP_FILE if exist "%WORKSPACE_ROOT%\entry-default-signed.hap" set "HAP_FILE=%WORKSPACE_ROOT%\entry-default-signed.hap"
if not defined HAP_FILE (
  echo Signed HAP was not found. Build output is missing entry-default-signed.hap.
  exit /b 1
)

"%HDC%" -t "%TARGET%" install -r "%HAP_FILE%" > "%HDC_LOG%" 2>&1
set "HDC_EXIT=%ERRORLEVEL%"
type "%HDC_LOG%"
findstr /c:"[Fail]" /c:"error:" /c:"failed" "%HDC_LOG%" >nul 2>nul
if not errorlevel 1 set "HDC_EXIT=1"
if not "%HDC_EXIT%"=="0" (
  del "%HDC_LOG%" >nul 2>nul
  del "%TARGETS_LOG%" >nul 2>nul
  exit /b %HDC_EXIT%
)

"%HDC%" -t "%TARGET%" shell aa start -a EntryAbility -b com.open.rundesk > "%HDC_LOG%" 2>&1
set "HDC_EXIT=%ERRORLEVEL%"
type "%HDC_LOG%"
findstr /c:"Error Code:10106102" "%HDC_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo Launch skipped because the device screen is locked. The HAP was installed successfully.
  set "HDC_EXIT=0"
  goto launch_checked
)
findstr /c:"[Fail]" /c:"Error Code:" /c:"error:" /c:"failed" "%HDC_LOG%" >nul 2>nul
if not errorlevel 1 set "HDC_EXIT=1"
:launch_checked
del "%HDC_LOG%" >nul 2>nul
del "%TARGETS_LOG%" >nul 2>nul
if not "%HDC_EXIT%"=="0" exit /b %HDC_EXIT%

echo Installed %HAP_FILE%
exit /b 0
