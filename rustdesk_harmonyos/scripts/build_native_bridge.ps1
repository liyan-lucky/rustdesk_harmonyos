param(
  [string]$TargetTriple = "aarch64-unknown-linux-ohos",
  [string]$Profile = "release"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$nativeCoreDir = Join-Path $projectRoot "native_rust_core"
$buildRoot = if ($env:RUSTDESK_HARMONY_BUILD_DIR) {
  $env:RUSTDESK_HARMONY_BUILD_DIR
} else {
  [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\..\99_Temp\rustdesk_harmonyos_build"))
}
$cargoTargetDir = if ($env:CARGO_TARGET_DIR) {
  $env:CARGO_TARGET_DIR
} else {
  Join-Path $buildRoot "native_rust_core\target"
}
$outputDir = Join-Path $cargoTargetDir "harmony"
$linkerScript = Join-Path $PSScriptRoot "$TargetTriple-clang.cmd"
$cxxScript = if ($TargetTriple -eq "aarch64-unknown-linux-ohos") {
  Join-Path $PSScriptRoot "$TargetTriple-clang++.cmd"
} else {
  $linkerScript
}
$llvmArScript = Join-Path $PSScriptRoot "ohos-llvm-ar.cmd"
$ohosEnvScript = Join-Path $PSScriptRoot "_ohos-sdk-env.cmd"
$localProperties = Join-Path $projectRoot "local.properties"
$hostSdkMirrorDir = Join-Path $buildRoot "deveco-sdk"
$cargoExe = $null
$rustupExe = $null
$vcvarsScript = $null
$msysBashExe = $null
$msysPerlExe = $null
$msysBinDir = $null
$cargoTargetKey = $TargetTriple.ToUpper().Replace('-', '_')
$targetEnvKey = $TargetTriple.ToLower().Replace('-', '_').Replace('.', '_')
$bindgenTarget = switch ($TargetTriple) {
  "aarch64-unknown-linux-ohos" { "aarch64-linux-ohos" }
  "armv7-unknown-linux-ohos" { "arm-linux-ohos" }
  "x86_64-unknown-linux-ohos" { "x86_64-linux-ohos" }
  default { throw "Unsupported target triple: $TargetTriple" }
}
$sysrootIncludeDir = switch ($TargetTriple) {
  "aarch64-unknown-linux-ohos" { "aarch64-linux-ohos" }
  "armv7-unknown-linux-ohos" { "arm-linux-ohos" }
  "x86_64-unknown-linux-ohos" { "x86_64-linux-ohos" }
  default { throw "Unsupported target triple: $TargetTriple" }
}
$configureHost = switch ($TargetTriple) {
  "aarch64-unknown-linux-ohos" { "aarch64-unknown-linux-gnu" }
  "armv7-unknown-linux-ohos" { "arm-unknown-linux-gnueabi" }
  "x86_64-unknown-linux-ohos" { "x86_64-unknown-linux-gnu" }
  default { throw "Unsupported target triple: $TargetTriple" }
}
$vcpkgRoot = if ($env:VCPKG_ROOT) {
  $env:VCPKG_ROOT
} else {
  Join-Path $buildRoot "vcpkg"
}
$vcpkgInstalledRoot = if ($env:VCPKG_INSTALLED_ROOT) {
  $env:VCPKG_INSTALLED_ROOT
} else {
  Join-Path $vcpkgRoot "installed"
}

function Convert-ToForwardSlashPath {
  param([string]$Path)

  return ([System.IO.Path]::GetFullPath($Path) -replace '\\', '/')
}

function Convert-ToMsysPath {
  param([string]$Path)

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $forwardPath = $fullPath -replace '\\', '/'
  if ($forwardPath -match '^([A-Za-z]):/(.*)$') {
    return "/$($matches[1].ToLowerInvariant())/$($matches[2])"
  }

  return $forwardPath
}

function Get-LocalPropertyValue {
  param(
    [string]$FilePath,
    [string]$Key
  )

  if (-not (Test-Path $FilePath)) {
    return $null
  }

  foreach ($line in Get-Content -Path $FilePath) {
    if ($line -like "$Key=*") {
      return $line.Substring($Key.Length + 1).Replace('\\', '\')
    }
  }

  return $null
}

function Get-SdkProbePaths {
  param([string]$RootPath)

  if ([string]::IsNullOrWhiteSpace($RootPath)) {
    return @()
  }

  $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
  return @(
    $fullRoot,
    (Join-Path $fullRoot "default\openharmony"),
    (Join-Path $fullRoot "openharmony"),
    (Join-Path $fullRoot "sdk\default\openharmony")
  )
}

function Resolve-HostSdkDirectory {
  param(
    [string]$BuildRoot,
    [string]$LocalPropertiesFile
  )

  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($candidate in @(
    $env:RUSTDESK_HARMONY_HOST_SDK,
    $env:OHOS_NDK_HOME,
    $env:OHOS_SDK_HOME,
    (Join-Path $BuildRoot "deveco-sdk"),
    (Join-Path $BuildRoot "ohos-sdk"),
    (Join-Path $BuildRoot ".ohos-sdk"),
    (Join-Path $BuildRoot "tools\openharmony-sdk"),
    "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony"
  )) {
    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
      $candidates.Add($candidate)
    }
  }

  $sdkFromProperties = Get-LocalPropertyValue -FilePath $LocalPropertiesFile -Key "sdk.dir"
  if ($sdkFromProperties) {
    $candidates.Add($sdkFromProperties)
  }

  foreach ($candidate in $candidates) {
    foreach ($probePath in Get-SdkProbePaths -RootPath $candidate) {
      $clangExe = Join-Path $probePath "native\llvm\bin\clang.exe"
      $llvmArExe = Join-Path $probePath "native\llvm\bin\llvm-ar.exe"
      $sysrootDir = Join-Path $probePath "native\sysroot"
      if ((Test-Path $clangExe) -and (Test-Path $llvmArExe) -and (Test-Path $sysrootDir)) {
        return [System.IO.Path]::GetFullPath($probePath)
      }
    }
  }

  return $null
}

function Ensure-NoSpaceSdkMirror {
  param(
    [string]$SdkDirectory,
    [string]$MirrorDirectory
  )

  if (-not $SdkDirectory) {
    return $null
  }

  $resolvedSdkDirectory = [System.IO.Path]::GetFullPath($SdkDirectory)
  $resolvedMirrorDirectory = [System.IO.Path]::GetFullPath($MirrorDirectory)

  if ($resolvedSdkDirectory -ieq $resolvedMirrorDirectory) {
    return $resolvedSdkDirectory
  }

  if ($resolvedSdkDirectory -notmatch '\s') {
    return $resolvedSdkDirectory
  }

  if (Test-Path $resolvedMirrorDirectory) {
    $mirrorItem = Get-Item -LiteralPath $resolvedMirrorDirectory -ErrorAction SilentlyContinue
    $mirrorTargets = @()
    if ($mirrorItem -and $mirrorItem.Target) {
      $mirrorTargets = @($mirrorItem.Target) | ForEach-Object {
        [System.IO.Path]::GetFullPath($_)
      }
    }
    if ($mirrorTargets -contains $resolvedSdkDirectory) {
      return $resolvedMirrorDirectory
    }
    Remove-Item -LiteralPath $resolvedMirrorDirectory -Recurse -Force
  }

  New-Item -ItemType Junction -Path $resolvedMirrorDirectory -Target $resolvedSdkDirectory | Out-Null
  return $resolvedMirrorDirectory
}

function Resolve-MsysTool {
  param(
    [string[]]$Candidates,
    [string]$Description
  )

  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return [System.IO.Path]::GetFullPath($candidate)
    }
  }

  throw "$Description was not found. Install MSYS2 and make sure the tool exists in one of: $($Candidates -join ', ')"
}

function Resolve-LibsodiumCrateDirectory {
  $cargoRegistrySrcRoot = Join-Path $env:USERPROFILE ".cargo\registry\src"
  if (-not (Test-Path $cargoRegistrySrcRoot)) {
    throw "Cargo registry sources were not found under $cargoRegistrySrcRoot."
  }

  foreach ($registryRoot in Get-ChildItem -Path $cargoRegistrySrcRoot -Directory) {
    $candidate = Join-Path $registryRoot.FullName "libsodium-sys-0.2.7"
    if (Test-Path (Join-Path $candidate "libsodium\configure")) {
      return $candidate
    }
  }

  throw "libsodium-sys-0.2.7 source was not found in the Cargo registry. Run a normal cargo build once to download it."
}

function Resolve-LibsodiumHostImportLibrary {
  $crateDirectory = Resolve-LibsodiumCrateDirectory
  $hostArch = if ([Environment]::Is64BitProcess) { "x64" } else { "Win32" }
  $candidates = @(
    (Join-Path $crateDirectory "msvc\$hostArch\Release\v143\libsodium.lib"),
    (Join-Path $crateDirectory "msvc\$hostArch\Release\v142\libsodium.lib")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return [System.IO.Path]::GetFullPath($candidate)
    }
  }

  throw "A host libsodium import library was not found under $crateDirectory\msvc\$hostArch\Release."
}

function Stage-LibsodiumHostImportLibrary {
  param([string]$LibDirectory)

  $hostImportLibrary = Resolve-LibsodiumHostImportLibrary
  New-Item -ItemType Directory -Path $LibDirectory -Force | Out-Null
  Copy-Item -LiteralPath $hostImportLibrary -Destination (Join-Path $LibDirectory "libsodium.lib") -Force
}

function Ensure-LibsodiumStaticLibrary {
  param(
    [string]$TargetTriple,
    [string]$BuildRoot,
    [string]$SdkDirectory,
    [string]$MsysBashExe,
    [string]$PSScriptRoot,
    [string]$BindgenTarget,
    [string]$SysrootIncludeDir,
    [string]$ConfigureHost
  )

  $installDir = Join-Path $BuildRoot "build\libsodium\$TargetTriple"
  $libDir = Join-Path $installDir "lib"
  $finalLib = Join-Path $libDir "liblibsodium.a"
  if (Test-Path $finalLib) {
    Stage-LibsodiumHostImportLibrary -LibDirectory $libDir
    return $libDir
  }

  $crateDirectory = Resolve-LibsodiumCrateDirectory
  $workRoot = Join-Path $BuildRoot "external-src\libsodium-$TargetTriple"
  $sourceRoot = Join-Path $workRoot "source"
  $sourceDirectory = Join-Path $sourceRoot "libsodium"
  if (Test-Path $sourceRoot) {
    Remove-Item -LiteralPath $sourceRoot -Recurse -Force
  }
  if (Test-Path $installDir) {
    Remove-Item -LiteralPath $installDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $sourceRoot, $installDir -Force | Out-Null
  Copy-Item -Path (Join-Path $crateDirectory "libsodium") -Destination $sourceDirectory -Recurse -Force

  $jobs = 4
  $parsedJobs = 0
  if ([int]::TryParse($env:NUMBER_OF_PROCESSORS, [ref]$parsedJobs) -and $parsedJobs -gt 0) {
    $jobs = $parsedJobs
  }

  $linkerMsys = Convert-ToMsysPath (Join-Path $PSScriptRoot "$TargetTriple-clang.cmd")
  $sdkLlvmBin = Join-Path $SdkDirectory "native\llvm\bin"
  $sdkLlvmBinMsys = Convert-ToMsysPath $sdkLlvmBin
  $sdkSysrootMsys = Convert-ToMsysPath (Join-Path $SdkDirectory "native\sysroot")
  $archIncludeMsys = "$sdkSysrootMsys/usr/include/$SysrootIncludeDir"
  $usrIncludeMsys = "$sdkSysrootMsys/usr/include"
  $installMsys = Convert-ToMsysPath $installDir
  $sourceMsys = Convert-ToMsysPath $sourceDirectory
  $bashScriptPath = Join-Path $workRoot "build-libsodium.sh"
  $bashScriptContent = @"
set -euo pipefail
cd "$sourceMsys"
export PATH="/usr/bin:${sdkLlvmBinMsys}:`$PATH"
export CC="$linkerMsys"
export LD="$sdkLlvmBinMsys/ld.lld.exe"
export AR="$sdkLlvmBinMsys/llvm-ar.exe"
export RANLIB="$sdkLlvmBinMsys/llvm-ranlib.exe"
export NM="$sdkLlvmBinMsys/llvm-nm.exe"
export STRIP=":"
export LDCONFIG=":"
export CFLAGS="--target=$BindgenTarget --sysroot=$sdkSysrootMsys -I$archIncludeMsys -I$usrIncludeMsys -D__MUSL__"
./configure --host=$ConfigureHost --prefix="$installMsys" --libdir="$installMsys/lib" --enable-shared=no
make -j$jobs all
make install
cp -f "$installMsys/lib/libsodium.a" "$installMsys/lib/liblibsodium.a"
"@
  Set-Content -Path $bashScriptPath -Value $bashScriptContent -Encoding ascii

  Write-Host "Building external libsodium for $TargetTriple..."
  & $MsysBashExe $bashScriptPath
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to build libsodium for $TargetTriple."
  }

  if (-not (Test-Path $finalLib)) {
    throw "libsodium build completed, but $finalLib was not produced."
  }

  Stage-LibsodiumHostImportLibrary -LibDirectory $libDir
  return $libDir
}

if (Get-Command cargo -ErrorAction SilentlyContinue) {
  $cargoExe = (Get-Command cargo).Source
} elseif (Test-Path "$env:USERPROFILE\.cargo\bin\cargo.exe") {
  $cargoExe = "$env:USERPROFILE\.cargo\bin\cargo.exe"
}

if (Get-Command rustup -ErrorAction SilentlyContinue) {
  $rustupExe = (Get-Command rustup).Source
} elseif (Test-Path "$env:USERPROFILE\.cargo\bin\rustup.exe") {
  $rustupExe = "$env:USERPROFILE\.cargo\bin\rustup.exe"
}

$vcvarsCandidates = @()
if ($env:VISUAL_STUDIO_VCVARS64 -and (Test-Path $env:VISUAL_STUDIO_VCVARS64)) {
  $vcvarsCandidates += $env:VISUAL_STUDIO_VCVARS64
}
$vcvarsCandidates += @(
  "C:\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
  "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
  "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
  "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
  "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
)
foreach ($candidate in $vcvarsCandidates) {
  if ($candidate -and (Test-Path $candidate)) {
    $vcvarsScript = $candidate
    break
  }
}

$msysBashExe = Resolve-MsysTool -Candidates @(
  "C:\msys64\usr\bin\bash.exe",
  "$env:USERPROFILE\scoop\apps\msys2\current\usr\bin\bash.exe"
) -Description "MSYS2 bash.exe"
$msysPerlExe = Resolve-MsysTool -Candidates @(
  "C:\msys64\usr\bin\perl.exe",
  "$env:USERPROFILE\scoop\apps\msys2\current\usr\bin\perl.exe"
) -Description "MSYS2 perl.exe"
$msysBinDir = Split-Path -Parent $msysBashExe

if (-not $cargoExe) {
  throw "cargo.exe was not found. Install Rust or add cargo to PATH before building the Harmony native bridge."
}

if (-not (Test-Path $linkerScript)) {
  throw "OpenHarmony linker wrapper was not found: $linkerScript"
}

if (-not (Test-Path $llvmArScript)) {
  throw "OpenHarmony llvm-ar wrapper was not found: $llvmArScript"
}

if (-not (Test-Path $ohosEnvScript)) {
  throw "OpenHarmony SDK env wrapper was not found: $ohosEnvScript"
}

if (-not (Test-Path $vcpkgInstalledRoot)) {
  throw "vcpkg installed root was not found: $vcpkgInstalledRoot"
}

$resolvedHostSdkDir = Resolve-HostSdkDirectory -BuildRoot $buildRoot -LocalPropertiesFile $localProperties
if (-not $resolvedHostSdkDir) {
  throw "OpenHarmony host SDK was not found. Install the DevEco SDK or set OHOS_SDK_HOME/OHOS_NDK_HOME."
}
$hostSdkDir = Ensure-NoSpaceSdkMirror -SdkDirectory $resolvedHostSdkDir -MirrorDirectory $hostSdkMirrorDir
$sdkLlvmBin = Join-Path $hostSdkDir "native\llvm\bin"
$sdkLdExe = Join-Path $sdkLlvmBin "ld.lld.exe"
$sdkNmExe = Join-Path $sdkLlvmBin "llvm-nm.exe"
$sdkRanlibExe = Join-Path $sdkLlvmBin "llvm-ranlib.exe"
if (-not (Test-Path $sdkLdExe)) {
  throw "OpenHarmony linker executable was not found under $sdkLlvmBin."
}
if (-not (Test-Path $sdkNmExe)) {
  throw "OpenHarmony llvm-nm executable was not found under $sdkLlvmBin."
}
if (-not (Test-Path $sdkRanlibExe)) {
  throw "OpenHarmony llvm-ranlib executable was not found under $sdkLlvmBin."
}

$libsodiumLibDir = Ensure-LibsodiumStaticLibrary `
  -TargetTriple $TargetTriple `
  -BuildRoot $buildRoot `
  -SdkDirectory $hostSdkDir `
  -MsysBashExe $msysBashExe `
  -PSScriptRoot $PSScriptRoot `
  -BindgenTarget $bindgenTarget `
  -SysrootIncludeDir $sysrootIncludeDir `
  -ConfigureHost $configureHost

New-Item -ItemType Directory -Path $cargoTargetDir -Force | Out-Null

$staleRoots = @(
  (Join-Path $cargoTargetDir "release\build"),
  (Join-Path $cargoTargetDir "release\.fingerprint"),
  (Join-Path $cargoTargetDir "$TargetTriple\$Profile\build"),
  (Join-Path $cargoTargetDir "$TargetTriple\$Profile\.fingerprint")
)
foreach ($staleRoot in $staleRoots) {
  if (-not (Test-Path $staleRoot)) {
    continue
  }
  Get-ChildItem -Path $staleRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "openssl-sys-*" -or $_.Name -like "openssl-*"
  } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$linkerForward = Convert-ToForwardSlashPath $linkerScript
$cxxForward = Convert-ToForwardSlashPath $cxxScript
$llvmArForward = Convert-ToForwardSlashPath $llvmArScript
$sdkLdForward = Convert-ToForwardSlashPath $sdkLdExe
$sdkNmForward = Convert-ToForwardSlashPath $sdkNmExe
$sdkRanlibForward = Convert-ToForwardSlashPath $sdkRanlibExe
$msysPerlForward = Convert-ToForwardSlashPath $msysPerlExe
$sdkClangForward = Convert-ToForwardSlashPath (Join-Path $sdkLlvmBin "clang.exe")
$sdkClangxxForward = Convert-ToForwardSlashPath (Join-Path $sdkLlvmBin "clang++.exe")
$sdkLlvmArForward = Convert-ToForwardSlashPath (Join-Path $sdkLlvmBin "llvm-ar.exe")
$sdkSysrootForward = Convert-ToForwardSlashPath (Join-Path $hostSdkDir "native\sysroot")
$bindgenArchIncludeForward = "$sdkSysrootForward/usr/include/$sysrootIncludeDir"
$bindgenUsrIncludeForward = "$sdkSysrootForward/usr/include"
$bindgenClangArgs = "--target=$bindgenTarget --sysroot=$sdkSysrootForward -isystem $bindgenArchIncludeForward -isystem $bindgenUsrIncludeForward -D__MUSL__"
$targetCompileFlags = "--target=$bindgenTarget --sysroot=$sdkSysrootForward -D__MUSL__ -fPIC"

$cmdLines = @(
  "@echo off",
  $(if ($vcvarsScript) { "call `"$vcvarsScript`" >nul || exit /b 1" } else { "rem vcvars64.bat not found; using current environment" }),
  "set `"RUSTDESK_HARMONY_HOST_SDK=$hostSdkDir`"",
  "set `"OHOS_SDK_HOME=$hostSdkDir`"",
  "call `"$ohosEnvScript`" || exit /b 1",
  "set `"PATH=%LLVM_BIN%;$env:USERPROFILE\.cargo\bin;%PATH%;$msysBinDir`"",
  "set `"CARGO_TARGET_DIR=$cargoTargetDir`"",
  "set `"VCPKG_ROOT=$vcpkgRoot`"",
  "set `"VCPKG_INSTALLED_ROOT=$vcpkgInstalledRoot`"",
  "set `"SODIUM_LIB_DIR=$libsodiumLibDir`"",
  "set `"PERL=$msysPerlForward`"",
  "set `"OPENSSL_SRC_PERL=$msysPerlForward`"",
  "set `"LD=$sdkLdForward`"",
  "set `"NM=$sdkNmForward`"",
  "set `"RANLIB=$sdkRanlibForward`"",
  "set `"CARGO_TARGET_${cargoTargetKey}_LINKER=$linkerScript`"",
  "set `"CARGO_TARGET_${cargoTargetKey}_AR=$llvmArScript`"",
  "set `"CC_${cargoTargetKey}=$sdkClangForward`"",
  "set `"CXX_${cargoTargetKey}=$sdkClangxxForward`"",
  "set `"AR_${cargoTargetKey}=$sdkLlvmArForward`"",
  "set `"CC_${TargetTriple}=$sdkClangForward`"",
  "set `"CXX_${TargetTriple}=$sdkClangxxForward`"",
  "set `"AR_${TargetTriple}=$sdkLlvmArForward`"",
  "set `"CC_${targetEnvKey}=$sdkClangForward`"",
  "set `"CXX_${targetEnvKey}=$sdkClangxxForward`"",
  "set `"AR_${targetEnvKey}=$sdkLlvmArForward`"",
  "set `"CFLAGS_${TargetTriple}=$targetCompileFlags`"",
  "set `"CXXFLAGS_${TargetTriple}=$targetCompileFlags`"",
  "set `"CFLAGS_${targetEnvKey}=$targetCompileFlags`"",
  "set `"CXXFLAGS_${targetEnvKey}=$targetCompileFlags`"",
  "set `"LD_${targetEnvKey}=$sdkLdForward`"",
  "set `"NM_${targetEnvKey}=$sdkNmForward`"",
  "set `"RANLIB_${targetEnvKey}=$sdkRanlibForward`"",
  "set `"BINDGEN_EXTRA_CLANG_ARGS=$bindgenClangArgs`"",
  "set `"BINDGEN_EXTRA_CLANG_ARGS_${TargetTriple}=$bindgenClangArgs`"",
  "set `"BINDGEN_EXTRA_CLANG_ARGS_${targetEnvKey}=$bindgenClangArgs`"",
  $(if ($rustupExe) { "call `"$rustupExe`" target add $TargetTriple || exit /b 1" } else { "rem rustup.exe not found; assuming target $TargetTriple is already installed" }),
  "cd /d `"$nativeCoreDir`" && `"$cargoExe`" build --profile $Profile --target $TargetTriple"
)
$cmdScript = [string]::Join("`r`n", $cmdLines)
$cmdScriptPath = Join-Path $buildRoot "build-native-bridge-$TargetTriple.cmd"
Set-Content -Path $cmdScriptPath -Value $cmdScript -Encoding ascii
try {
  $cmdProcess = Start-Process -FilePath "cmd.exe" -ArgumentList "/d", "/c", $cmdScriptPath -NoNewWindow -Wait -PassThru
  if ($cmdProcess.ExitCode -ne 0) {
    throw "cargo build failed with exit code $($cmdProcess.ExitCode)."
  }
} finally {
  Remove-Item -LiteralPath $cmdScriptPath -Force -ErrorAction SilentlyContinue
}

$artifactProfileDir = switch ($Profile) {
  "dev" { "debug" }
  default { $Profile }
}
$artifactDir = Join-Path $cargoTargetDir "$TargetTriple\$artifactProfileDir"
$staticLib = Join-Path $artifactDir "rustdesk_harmony_bridge.a"
$prefixedStaticLib = Join-Path $artifactDir "librustdesk_harmony_bridge.a"
$depsStaticLib = Join-Path $artifactDir "deps\librustdesk_harmony_bridge.a"

if (Test-Path $prefixedStaticLib) {
  $sourceLib = $prefixedStaticLib
} elseif (Test-Path $staticLib) {
  $sourceLib = $staticLib
} elseif (Test-Path $depsStaticLib) {
  $sourceLib = $depsStaticLib
} else {
  throw "Native bridge build succeeded, but no static library was found in $artifactDir."
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Copy-Item -LiteralPath $sourceLib -Destination (Join-Path $outputDir "librustdesk_harmony_bridge.a") -Force

Write-Host "Native bridge artifact copied to $outputDir\librustdesk_harmony_bridge.a"
