@echo off
setlocal
call "%~dp0_ohos-sdk-env.cmd" || exit /b 1
"%OHOS_LLVM_AR%" %*
