@echo off
setlocal enabledelayedexpansion

set "TARGET_TRIPLE=aarch64-unknown-linux-ohos"
set "PROFILE=release"

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "BUILD_ROOT=E:\Visual_Studio_Code\99_Temp\rustdesk_harmonyos_build"
set "CARGO_TARGET_DIR=%BUILD_ROOT%\native_rust_core\target"
set "OUTPUT_DIR=%CARGO_TARGET_DIR%\harmony"

set "SDK_DIR=%BUILD_ROOT%\deveco-sdk"
set "LLVM_BIN=%SDK_DIR%\native\llvm\bin"
set "SYSROOT=%SDK_DIR%\native\sysroot"

set "VCPKG_ROOT=%BUILD_ROOT%\vcpkg"
set "VCPKG_INSTALLEDROOT=%VCPKG_ROOT%\installed"

if not exist "%LLVM_BIN%\clang.exe" (
    echo OpenHarmony clang not found: %LLVM_BIN%\clang.exe
    exit /b 1
)

if not exist "%SYSROOT%" (
    echo OpenHarmony sysroot not found: %SYSROOT%
    exit /b 1
)

if not exist "%VCPKG_INSTALLEDROOT%" (
    echo vcpkg installed root not found: %VCPKG_INSTALLEDROOT%
    exit /b 1
)

:: Set environment variables
set "CC_aarch64_unknown_linux_ohos=%SCRIPT_DIR%aarch64-unknown-linux-ohos-clang.bat"
set "CXX_aarch64_unknown_linux_ohos=%SCRIPT_DIR%aarch64-unknown-linux-ohos-clang++.bat"
set "AR_aarch64_unknown_linux_ohos=%SCRIPT_DIR%ohos-llvm-ar.bat"
set "CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER=%SCRIPT_DIR%aarch64-unknown-linux-ohos-clang.bat"
set "CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_AR=%SCRIPT_DIR%ohos-llvm-ar.bat"

set "VCPKG_ROOT=%VCPKG_ROOT%"
set "VCPKG_INSTALLEDROOT=%VCPKG_INSTALLEDROOT%"
set "CARGO_TARGET_DIR=%CARGO_TARGET_DIR%"

:: Navigate to native_rust_core
cd /d "%PROJECT_ROOT%\native_rust_core"

echo Building Rust core for HarmonyOS...
echo Target: %TARGET_TRIPLE%
echo Profile: %PROFILE%
echo SDK: %SDK_DIR%

:: Run cargo build
cargo build --target %TARGET_TRIPLE% -p rustdesk_harmony_bridge --release

if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build completed successfully!
echo Output: %CARGO_TARGET_DIR%\%TARGET_TRIPLE%\%PROFILE%\librustdesk_harmony_bridge.a
