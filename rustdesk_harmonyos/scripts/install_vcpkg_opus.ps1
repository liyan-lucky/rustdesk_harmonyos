param(
  [string]$VcpkgRoot = "",
  [string]$Target = "arm64-linux"
)

$ErrorActionPreference = "Stop"

if ($VcpkgRoot -eq "") {
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $buildRoot = if ($env:RUSTDESK_HARMONY_BUILD_DIR) {
    $env:RUSTDESK_HARMONY_BUILD_DIR
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\..\99_Temp\rustdesk_harmonyos_build"))
  }
  $VcpkgRoot = Join-Path $buildRoot "vcpkg"
}

$vcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"
if (-not (Test-Path $vcpkgExe)) {
  $bootstrapScript = Join-Path $VcpkgRoot "bootstrap-vcpkg.bat"
  if (Test-Path $bootstrapScript) {
    Write-Host "vcpkg.exe not found, bootstrapping..."
    Push-Location $VcpkgRoot
    try {
      & cmd.exe /c "bootstrap-vcpkg.bat" 2>&1
    } finally {
      Pop-Location
    }
  } else {
    throw "vcpkg not found at $VcpkgRoot and no bootstrap script available"
  }
}

if (-not (Test-Path $vcpkgExe)) {
  throw "vcpkg.exe still not found after bootstrap at $VcpkgRoot"
}

Write-Host "Installing opus:$Target via vcpkg..."
& $vcpkgExe install "opus:$Target" 2>&1

$installedDir = Join-Path $VcpkgRoot "installed\$Target"
$opusHeader = Join-Path $installedDir "include\opus\opus_multistream.h"
if (Test-Path $opusHeader) {
  Write-Host "opus installed successfully. Headers at: $(Join-Path $installedDir 'include\opus')"
  Write-Host "Libraries at: $(Join-Path $installedDir 'lib')"
} else {
  throw "opus installation completed but headers not found at $opusHeader"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: powershell -ExecutionPolicy Bypass -File scripts\build_native_bridge.ps1"
Write-Host "  2. The Rust core rebuild will link against the new opus library"
Write-Host "  3. After rebuild, run hvigor to recompile the HAP with the updated .so"
