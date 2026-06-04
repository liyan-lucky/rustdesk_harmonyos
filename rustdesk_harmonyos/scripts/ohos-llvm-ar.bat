@echo off
setlocal enabledelayedexpansion

set "SDK_DIR=C:\PROGRA~1\Huawei\DEVECO~1\sdk\default\openharmony"
set "LLVM_BIN=%SDK_DIR%\native\llvm\bin"

"%LLVM_BIN%\llvm-ar.exe" %*
