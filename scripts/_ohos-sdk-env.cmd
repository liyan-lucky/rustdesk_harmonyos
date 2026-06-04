@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0.." >nul
set "PROJECT_ROOT=%CD%"
popd >nul
if defined RUSTDESK_HARMONY_BUILD_DIR (
  set BUILD_ROOT=%RUSTDESK_HARMONY_BUILD_DIR%
) else (
  for %%I in ("%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build") do set BUILD_ROOT=%%~fI
)
set LOCAL_PROPERTIES=%PROJECT_ROOT%\local.properties
set SDK_DIR=
set CLANG_BIN=
set CLANGXX_BIN=
set LLVM_AR_BIN=
set SDK_DIR_FROM_PROPERTIES=

for %%B in ("%RUSTDESK_HARMONY_HOST_SDK%" "%OHOS_NDK_HOME%" "%OHOS_SDK_HOME%" "%BUILD_ROOT%\deveco-sdk" "%BUILD_ROOT%\ohos-sdk" "%BUILD_ROOT%\.ohos-sdk" "%BUILD_ROOT%\tools\openharmony-sdk") do (
  if not defined SDK_DIR if not "%%~B"=="" (
    for %%C in ("%%~fB" "%%~fB\default\openharmony" "%%~fB\openharmony" "%%~fB\sdk\default\openharmony") do (
      if not defined SDK_DIR if exist "%%~fC\native\llvm\bin\clang.exe" if exist "%%~fC\native\sysroot" (
        set "SDK_DIR=%%~fC"
      )
    )
  )
)

if exist "%LOCAL_PROPERTIES%" (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b "sdk.dir=" "%LOCAL_PROPERTIES%"`) do (
    set "SDK_DIR_FROM_PROPERTIES=%%B"
  )
)
if not defined SDK_DIR if defined SDK_DIR_FROM_PROPERTIES (
  call set "SDK_DIR_FROM_PROPERTIES=%%SDK_DIR_FROM_PROPERTIES:\\=\%%"
  if exist "%SDK_DIR_FROM_PROPERTIES%\native\llvm\bin\clang.exe" if exist "%SDK_DIR_FROM_PROPERTIES%\native\sysroot" (
    set "SDK_DIR=%SDK_DIR_FROM_PROPERTIES%"
  )
  for %%C in ("%SDK_DIR_FROM_PROPERTIES%" "%SDK_DIR_FROM_PROPERTIES%\default\openharmony" "%SDK_DIR_FROM_PROPERTIES%\openharmony" "%SDK_DIR_FROM_PROPERTIES%\sdk\default\openharmony") do (
    if not defined SDK_DIR if exist "%%~fC\native\llvm\bin\clang.exe" if exist "%%~fC\native\sysroot" (
      set "SDK_DIR=%%~fC"
    )
  )
)

for %%B in ("%PROJECT_ROOT%\.ohos-sdk" "%PROJECT_ROOT%\.tools\openharmony-sdk" "%PROJECT_ROOT%\.tools\ohos-sdk") do (
  if not defined SDK_DIR if not "%%~B"=="" (
    for %%C in ("%%~fB" "%%~fB\default\openharmony" "%%~fB\openharmony" "%%~fB\sdk\default\openharmony") do (
      if not defined SDK_DIR if exist "%%~fC\native\llvm\bin\clang.exe" if exist "%%~fC\native\sysroot" (
        set "SDK_DIR=%%~fC"
      )
    )
  )
)

if defined SDK_DIR goto found

echo OpenHarmony SDK not found. Set OHOS_NDK_HOME/OHOS_SDK_HOME or place the SDK under %BUILD_ROOT%\ohos-sdk. 1>&2
exit /b 1

:found
set LLVM_BIN=%SDK_DIR%\native\llvm\bin
set SYSROOT=%SDK_DIR%\native\sysroot
set CLANG_BIN=%LLVM_BIN%\clang.exe
set CLANGXX_BIN=%LLVM_BIN%\clang++.exe
set LLVM_AR_BIN=%LLVM_BIN%\llvm-ar.exe

if not exist "%CLANG_BIN%" if exist "%LLVM_BIN%\clang" set CLANG_BIN=%LLVM_BIN%\clang
if not exist "%CLANGXX_BIN%" if exist "%LLVM_BIN%\clang++" set CLANGXX_BIN=%LLVM_BIN%\clang++
if not exist "%LLVM_AR_BIN%" if exist "%LLVM_BIN%\llvm-ar" set LLVM_AR_BIN=%LLVM_BIN%\llvm-ar

if not exist "%CLANG_BIN%" (
  echo OpenHarmony clang executable not found under %LLVM_BIN% 1>&2
  exit /b 1
)

if not exist "%SYSROOT%" (
  echo OpenHarmony sysroot not found under %SYSROOT% 1>&2
  exit /b 1
)

if not exist "%CLANGXX_BIN%" (
  echo OpenHarmony clang++ executable not found under %LLVM_BIN% 1>&2
  exit /b 1
)

if not exist "%LLVM_AR_BIN%" (
  echo OpenHarmony llvm-ar executable not found under %LLVM_BIN% 1>&2
  exit /b 1
)

endlocal & (
  set "OHOS_SDK_DIR=%SDK_DIR%"
  set "LLVM_BIN=%LLVM_BIN%"
  set "SYSROOT=%SYSROOT%"
  set "OHOS_CLANG=%CLANG_BIN%"
  set "OHOS_CLANGXX=%CLANGXX_BIN%"
  set "OHOS_LLVM_AR=%LLVM_AR_BIN%"
)
exit /b 0
