@echo off
setlocal
call "%~dp0_ohos-sdk-env.cmd" || exit /b 1
"%OHOS_CLANG%" -target arm-linux-ohos --sysroot="%SYSROOT%" -D__MUSL__ -march=armv7-a -mfloat-abi=softfp -mtune=generic-armv7-a -mthumb %*
