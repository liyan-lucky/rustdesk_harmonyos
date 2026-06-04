@echo off
setlocal enabledelayedexpansion

:: Set SDK paths
set "SDK_DIR=C:\PROGRA~1\Huawei\DEVECO~1\sdk\default\openharmony"
set "LLVM_BIN=%SDK_DIR%\native\llvm\bin"
set "SYSROOT=%SDK_DIR%\native\sysroot"

:: Execute clang with OHOS target
"%LLVM_BIN%\clang.exe" -target aarch64-linux-ohos --sysroot="%SYSROOT%" -D__MUSL__ %*
