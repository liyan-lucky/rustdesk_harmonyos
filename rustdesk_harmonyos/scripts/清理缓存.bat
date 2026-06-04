@echo off
setlocal

set "PROJECT_ROOT=E:\Visual_Studio_Code\11_Rustdesk"

echo ========================================
echo RustDesk HarmonyOS cleanup
echo ========================================
echo.

if exist "%PROJECT_ROOT%\rustdesk\target" (
  rmdir /s /q "%PROJECT_ROOT%\rustdesk\target"
  echo removed dir  rustdesk\target
) else (
  echo skip dir     rustdesk\target
)

if exist "%PROJECT_ROOT%\rustdesk\vcpkg_installed" (
  rmdir /s /q "%PROJECT_ROOT%\rustdesk\vcpkg_installed"
  echo removed dir  rustdesk\vcpkg_installed
) else (
  echo skip dir     rustdesk\vcpkg_installed
)

if exist "%PROJECT_ROOT%\rustdesk_harmonyos\.hvigor" (
  rmdir /s /q "%PROJECT_ROOT%\rustdesk_harmonyos\.hvigor"
  echo removed dir  rustdesk_harmonyos\.hvigor
) else (
  echo skip dir     rustdesk_harmonyos\.hvigor
)

if exist "%PROJECT_ROOT%\rustdesk_harmonyos\entry\build" (
  rmdir /s /q "%PROJECT_ROOT%\rustdesk_harmonyos\entry\build"
  echo removed dir  rustdesk_harmonyos\entry\build
) else (
  echo skip dir     rustdesk_harmonyos\entry\build
)

if exist "%PROJECT_ROOT%\rustdesk_harmonyos\entry\.cxx" (
  rmdir /s /q "%PROJECT_ROOT%\rustdesk_harmonyos\entry\.cxx"
  echo removed dir  rustdesk_harmonyos\entry\.cxx
) else (
  echo skip dir     rustdesk_harmonyos\entry\.cxx
)

if exist "%PROJECT_ROOT%\rustdesk_harmonyos\native_rust_core\target" (
  for /d %%D in ("%PROJECT_ROOT%\rustdesk_harmonyos\native_rust_core\target\*") do (
    if /I not "%%~nxD"=="harmony" (
      rmdir /s /q "%%~fD"
      echo removed dir  rustdesk_harmonyos\native_rust_core\target\%%~nxD
    )
  )
  if exist "%PROJECT_ROOT%\rustdesk_harmonyos\native_rust_core\target\.rustc_info.json" (
    del /q "%PROJECT_ROOT%\rustdesk_harmonyos\native_rust_core\target\.rustc_info.json"
    echo removed file rustdesk_harmonyos\native_rust_core\target\.rustc_info.json
  )
) else (
  echo skip dir     rustdesk_harmonyos\native_rust_core\target
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target" (
  for /d %%D in ("%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\*") do (
    if /I not "%%~nxD"=="harmony" (
      rmdir /s /q "%%~fD"
      echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\%%~nxD
    )
  )
  if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\.rustc_info.json" (
    del /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\.rustc_info.json"
    echo removed file ..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\.rustc_info.json
  )
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\logs" (
  rmdir /s /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\logs"
  echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\logs
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\logs
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\tmp" (
  rmdir /s /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\tmp"
  echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\tmp
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\tmp
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\downloads" (
  rmdir /s /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\downloads"
  echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\downloads
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\downloads
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\hap_repack" (
  rmdir /s /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\hap_repack"
  echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\hap_repack
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\hap_repack
)

if exist "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\cmake" (
  rmdir /s /q "%PROJECT_ROOT%\..\99_Temp\rustdesk_harmonyos_build\cmake"
  echo removed dir  ..\99_Temp\rustdesk_harmonyos_build\cmake
) else (
  echo skip dir     ..\99_Temp\rustdesk_harmonyos_build\cmake
)

if exist "%PROJECT_ROOT%\device_dump" (
  rmdir /s /q "%PROJECT_ROOT%\device_dump"
  echo removed dir  device_dump
) else (
  echo skip dir     device_dump
)

if exist "%PROJECT_ROOT%\android_analysis" (
  rmdir /s /q "%PROJECT_ROOT%\android_analysis"
  echo removed dir  android_analysis
) else (
  echo skip dir     android_analysis
)

if exist "%PROJECT_ROOT%\tmp_current_profile_dump.txt" (
  del /q "%PROJECT_ROOT%\tmp_current_profile_dump.txt"
  echo removed file tmp_current_profile_dump.txt
) else (
  echo skip file    tmp_current_profile_dump.txt
)

if exist "%PROJECT_ROOT%\tmp_signed_profile_dump.txt" (
  del /q "%PROJECT_ROOT%\tmp_signed_profile_dump.txt"
  echo removed file tmp_signed_profile_dump.txt
) else (
  echo skip file    tmp_signed_profile_dump.txt
)

if exist "%PROJECT_ROOT%\tmp_release_profile_dump.txt" (
  del /q "%PROJECT_ROOT%\tmp_release_profile_dump.txt"
  echo removed file tmp_release_profile_dump.txt
) else (
  echo skip file    tmp_release_profile_dump.txt
)

if exist "%PROJECT_ROOT%\tmp_debug_hos_dump.txt" (
  del /q "%PROJECT_ROOT%\tmp_debug_hos_dump.txt"
  echo removed file tmp_debug_hos_dump.txt
) else (
  echo skip file    tmp_debug_hos_dump.txt
)

if exist "%PROJECT_ROOT%\tmp_verify_profile_dump.txt" (
  del /q "%PROJECT_ROOT%\tmp_verify_profile_dump.txt"
  echo removed file tmp_verify_profile_dump.txt
) else (
  echo skip file    tmp_verify_profile_dump.txt
)

echo.
echo Preserved:
echo   - source code and docs
echo   - ..\99_Temp\rustdesk_harmonyos_build\windows_hap
echo   - ..\99_Temp\rustdesk_harmonyos_build\signing
echo   - ..\99_Temp\rustdesk_harmonyos_build\build
echo   - ..\99_Temp\rustdesk_harmonyos_build\native_rust_core\target\harmony
echo   - ..\99_Temp\rustdesk_harmonyos_build\ohos-sdk / deveco-sdk
echo.
echo Cleanup finished.
