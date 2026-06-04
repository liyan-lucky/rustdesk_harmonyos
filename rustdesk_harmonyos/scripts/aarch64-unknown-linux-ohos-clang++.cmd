@echo off
setlocal
call "%~dp0_ohos-sdk-env.cmd" || exit /b 1
"%OHOS_CLANGXX%" -target aarch64-linux-ohos --sysroot="%SYSROOT%" -D__MUSL__ %*
