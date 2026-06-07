param(
  [ValidateSet("hap", "app", "both")]
  [string]$ArtifactType = "both",
  [ValidateSet("none", "incremental", "full")]
  [string]$VersionBump = "incremental",
  [string]$CoreUrl = $env:RUSTDESK_CORE_URL,
  [string]$ExpectedCoreSha256 = $env:RUSTDESK_CORE_SHA256,
  [string]$SigningZipBase64 = $env:RUSTDESK_SIGNING_ZIP_B64,
  [string]$ArtifactsDir = "",
  [int64]$MinCoreBytes = 52428800,
  [switch]$SkipPackageVerify,
  [switch]$DisableStage,
  [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $scriptDir))
$projectName = Split-Path -Leaf $projectRoot
$tempRoot = if ($env:RUSTDESK_HARMONY_TEMP_ROOT) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_TEMP_ROOT)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp"))
}

if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
  $ArtifactsDir = Join-Path $tempRoot "harmonyos_artifacts\$projectName"
}
$ArtifactsDir = [System.IO.Path]::GetFullPath($ArtifactsDir)

$env:CI = "true"
$env:RUSTDESK_HARMONY_TEMP_ROOT = $tempRoot
if ([string]::IsNullOrWhiteSpace($env:BUILD_CACHE_DIR)) {
  $env:BUILD_CACHE_DIR = Join-Path $tempRoot "harmonyos_cache"
}

function Assert-UnderDirectory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Child,
    [Parameter(Mandatory = $true)]
    [string]$Parent,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  $resolvedChild = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
  $resolvedParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
  $prefix = $resolvedParent + [System.IO.Path]::DirectorySeparatorChar
  if (-not $resolvedChild.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label must stay under $resolvedParent, got $resolvedChild"
  }
}

function Reset-Directory {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$SafeParent,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  $resolvedPath = [System.IO.Path]::GetFullPath($Path)
  Assert-UnderDirectory -Child $resolvedPath -Parent $SafeParent -Label $Label
  if (Test-Path -LiteralPath $resolvedPath) {
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $resolvedPath | Out-Null
  return $resolvedPath
}

function Read-LocalProperties {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith("#")) {
      continue
    }
    $parts = $line -split "=", 2
    if ($parts.Count -ne 2) {
      continue
    }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim() -replace "\\\\", "\"
    if ($key.Length -gt 0) {
      $values[$key] = $value
    }
  }

  return $values
}

function Resolve-FirstExistingPath {
  param(
    [string[]]$Candidates
  )

  foreach ($candidate in $Candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
    $resolved = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath $resolved) {
      return $resolved
    }
  }
  return ""
}

function Resolve-NodeExecutable {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$LocalProperties
  )

  $npmDir = $LocalProperties["npm.dir"]
  $candidates = @(
    $env:DEVECO_NODE_EXE,
    $(if ($npmDir) { Join-Path $npmDir "node.exe" }),
    $(if ($npmDir) { Join-Path $npmDir "node" }),
    "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe"
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath $resolvedCandidate) {
      return $resolvedCandidate
    }
  }

  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  if ($nodeCommand -and $nodeCommand.Source) {
    return [System.IO.Path]::GetFullPath($nodeCommand.Source)
  }

  throw "node executable was not found. Set DEVECO_NODE_EXE or local.properties npm.dir."
}

function Confirm-DevEcoEnvironment {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$LocalProperties
  )

  $sdkDirParent = if ($LocalProperties["sdk.dir"]) {
    [System.IO.Path]::GetFullPath((Join-Path $LocalProperties["sdk.dir"] ".."))
  } else {
    ""
  }

  $toolsRoot = Resolve-FirstExistingPath -Candidates @(
    $env:DEVECO_TOOLS_HOME,
    $(if ($env:DEVECO_HOME) { Join-Path $env:DEVECO_HOME "tools" }),
    $(if ($env:DEVECO_NODE_EXE) { Join-Path (Split-Path -Parent $env:DEVECO_NODE_EXE) ".." }),
    $(if ($LocalProperties["npm.dir"]) { Join-Path $LocalProperties["npm.dir"] ".." }),
    "C:\Program Files\Huawei\DevEco Studio\tools"
  )

  if ([string]::IsNullOrWhiteSpace($toolsRoot)) {
    throw "DevEco tools were not found. Install DevEco Studio on the runner or set DEVECO_TOOLS_HOME."
  }

  $hvigorEntry = Join-Path $toolsRoot "hvigor\bin\hvigorw.js"
  if (-not (Test-Path -LiteralPath $hvigorEntry)) {
    throw "Hvigor entry was not found: $hvigorEntry"
  }

  $sdkRoot = Resolve-FirstExistingPath -Candidates @(
    $env:DEVECO_SDK_HOME,
    $env:OHOS_HVIGOR_SDK_ROOT,
    $LocalProperties["hwsdk.dir"],
    $sdkDirParent,
    "C:\Program Files\Huawei\DevEco Studio\sdk\default"
  )

  if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
    throw "DevEco SDK was not found. Install HarmonyOS SDK on the runner or set DEVECO_SDK_HOME."
  }

  $nativeRoot = Join-Path $sdkRoot "openharmony\native"
  if (-not (Test-Path -LiteralPath $nativeRoot)) {
    throw "OpenHarmony native SDK component was not found: $nativeRoot"
  }

  return [ordered]@{
    ToolsRoot = $toolsRoot
    HvigorEntry = $hvigorEntry
    SdkRoot = $sdkRoot
    NativeRoot = $nativeRoot
  }
}

function Get-CoreBuildInfoSha256 {
  $coreBuildInfoPath = Join-Path $projectRoot "entry\src\main\ets\common\CoreBuildInfo.ets"
  if (-not (Test-Path -LiteralPath $coreBuildInfoPath)) {
    return ""
  }
  $content = Get-Content -LiteralPath $coreBuildInfoPath -Raw
  $match = [regex]::Match($content, 'HASH_SHA256:\s*string\s*=\s*"([^"]+)"')
  if ($match.Success) {
    return $match.Groups[1].Value.Trim().ToUpperInvariant()
  }
  return ""
}

function Confirm-NativeCore {
  $corePath = Join-Path $projectRoot "entry\src\main\libs\arm64\librustdesk_core.a"
  if (-not (Test-Path -LiteralPath $corePath) -and -not [string]::IsNullOrWhiteSpace($CoreUrl)) {
    Write-Host "Native core is missing; downloading from RUSTDESK_CORE_URL."
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $corePath) | Out-Null
    Invoke-WebRequest -Uri $CoreUrl -OutFile $corePath
  }

  if (-not (Test-Path -LiteralPath $corePath)) {
    throw "Native core staticlib is missing: $corePath. Provide RUSTDESK_CORE_URL or commit a valid local core outside CI."
  }

  $coreItem = Get-Item -LiteralPath $corePath
  if ($coreItem.Length -lt $MinCoreBytes) {
    throw "Native core staticlib is too small: $($coreItem.Length) bytes at $corePath"
  }

  $sha256 = (Get-FileHash -LiteralPath $corePath -Algorithm SHA256).Hash.ToUpperInvariant()
  $expected = $ExpectedCoreSha256.Trim().ToUpperInvariant()
  if (-not [string]::IsNullOrWhiteSpace($expected) -and $sha256 -ne $expected) {
    throw "Native core SHA256 mismatch. Expected $expected but got $sha256"
  }

  $declared = Get-CoreBuildInfoSha256
  if (-not [string]::IsNullOrWhiteSpace($declared) -and $declared -ne $sha256) {
    Write-Warning "CoreBuildInfo.ets hash differs from the native core on disk. Build will refresh CoreBuildInfo before packaging."
  }

  return [ordered]@{
    Path = $corePath
    Size = $coreItem.Length
    Sha256 = $sha256
    ModifiedTime = $coreItem.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
  }
}

function Restore-SigningFromSecret {
  if ([string]::IsNullOrWhiteSpace($SigningZipBase64)) {
    return
  }

  $extractRoot = Reset-Directory `
    -Path (Join-Path $tempRoot "rustdesk_harmonyos_signing_extract") `
    -SafeParent $tempRoot `
    -Label "Signing extract directory"
  $zipPath = Join-Path $tempRoot "rustdesk_harmonyos_signing.zip"
  [System.IO.File]::WriteAllBytes($zipPath, [System.Convert]::FromBase64String($SigningZipBase64))
  Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

  $candidateRoots = New-Object System.Collections.Generic.List[string]
  $candidateRoots.Add($extractRoot) | Out-Null
  Get-ChildItem -LiteralPath $extractRoot -Directory -Recurse | ForEach-Object {
    $candidateRoots.Add($_.FullName) | Out-Null
  }

  $sourceRoot = ""
  foreach ($candidate in $candidateRoots) {
    $p12 = Get-ChildItem -LiteralPath $candidate -File -Filter "*.p12" -ErrorAction SilentlyContinue | Select-Object -First 1
    $cer = Get-ChildItem -LiteralPath $candidate -File -Filter "*.cer" -ErrorAction SilentlyContinue | Select-Object -First 1
    $p7b = Get-ChildItem -LiteralPath $candidate -File -Filter "*.p7b" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p12 -and $cer -and $p7b) {
      $sourceRoot = $candidate
      break
    }
  }

  if ([string]::IsNullOrWhiteSpace($sourceRoot)) {
    throw "RUSTDESK_SIGNING_ZIP_B64 was decoded, but no directory containing .p12, .cer, and .p7b was found."
  }

  $signingRoot = Reset-Directory `
    -Path (Join-Path $tempRoot "rustdesk_harmonyos_signing") `
    -SafeParent $tempRoot `
    -Label "Signing material directory"
  Get-ChildItem -LiteralPath $sourceRoot -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $signingRoot -Recurse -Force
  }
}

function Confirm-SigningMaterial {
  Restore-SigningFromSecret
  $signingRoot = Join-Path $tempRoot "rustdesk_harmonyos_signing"
  if (-not (Test-Path -LiteralPath $signingRoot)) {
    throw "Signing material directory is missing: $signingRoot. Provide RUSTDESK_SIGNING_ZIP_B64 or pre-provision the runner."
  }

  foreach ($extension in @("*.p12", "*.cer", "*.p7b")) {
    $file = Get-ChildItem -LiteralPath $signingRoot -File -Filter $extension -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $file) {
      throw "Signing material is missing $extension under $signingRoot"
    }
  }

  $materialRoot = Join-Path $signingRoot "material"
  if (-not (Test-Path -LiteralPath $materialRoot)) {
    throw "Signing encryption material directory is missing: $materialRoot"
  }

  $checkScript = Join-Path $scriptDir "check_harmony_signing_profile.ps1"
  if (-not (Test-Path -LiteralPath $checkScript)) {
    throw "Signing profile check script was not found: $checkScript"
  }
  $global:LASTEXITCODE = 0
  & $checkScript -ProductName "default"
  $profileCheckSucceeded = $?
  $profileCheckExitCode = $LASTEXITCODE
  if (-not $profileCheckSucceeded -or $profileCheckExitCode -ne 0) {
    throw "Signing profile preflight failed with exit code $profileCheckExitCode."
  }

  return $signingRoot
}

function Confirm-RequiredRepoFiles {
  $requiredFiles = @(
    "build-profile.json5",
    "AppScope\app.json5",
    "entry\hvigorfile.ts",
    "entry\src\main\cpp\CMakeLists.txt",
    "entry\src\main\cpp\rustdesk_bridge_loader.cpp",
    "entry\src\main\cpp\types\librustdesk_bridge\oh-package.json5",
    "entry\src\main\cpp\types\librustdesk_bridge\index.d.ts",
    "entry\src\main\module.json5",
    "scripts\run_hvigor_with_sdk_patch.js",
    "scripts\stage_project_for_build.ps1",
    "scripts\sync_build_version_from_stage.ps1"
  )

  foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
      throw "Required repository file is missing: $relativePath"
    }
  }
}

function Get-HvigorTasks {
  if ($ArtifactType -eq "hap") {
    return @("assembleHap")
  }
  if ($ArtifactType -eq "app") {
    return @("assembleApp")
  }
  return @("assembleApp")
}

function Get-PackageSearchRoots {
  return @(
    (Join-Path $tempRoot "harmonyos_build\$projectName\entry\build\default\outputs\default"),
    (Join-Path $tempRoot "harmonyos_build\$projectName\build\outputs\default"),
    (Join-Path $projectRoot "entry\build\default\outputs\default"),
    (Join-Path $projectRoot "build\outputs\default")
  ) | Where-Object { Test-Path -LiteralPath $_ }
}

function Invoke-HarmonyBuild {
  param(
    [Parameter(Mandatory = $true)]
    [string]$NodeExe,
    [Parameter(Mandatory = $true)]
    [string[]]$Tasks,
    [Parameter(Mandatory = $true)]
    [string]$BuildRoot
  )

  $runHvigorScript = Join-Path $BuildRoot "scripts\run_hvigor_with_sdk_patch.js"
  if ($VersionBump -eq "none") {
    Remove-Item Env:RUSTDESK_HARMONY_VERSION_BUMP -ErrorAction SilentlyContinue
  } else {
    $env:RUSTDESK_HARMONY_VERSION_BUMP = $VersionBump
  }

  Write-Host "Running Hvigor tasks: $($Tasks -join ', ')"
  Write-Host "Build root: $BuildRoot"
  Push-Location $BuildRoot
  try {
    & $NodeExe $runHvigorScript @Tasks
    if ($LASTEXITCODE -ne 0) {
      throw "Hvigor build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
}

function New-BuildStage {
  if ($DisableStage) {
    Write-Host "Build staging disabled by -DisableStage."
    return $projectRoot
  }

  $stageScript = Join-Path $scriptDir "stage_project_for_build.ps1"
  $stageRoot = [System.IO.Path]::GetFullPath((Join-Path $tempRoot "harmonyos_stage\$projectName"))
  Write-Host "Staging clean build project: $stageRoot"
  $global:LASTEXITCODE = 0
  & $stageScript -StageRoot $stageRoot
  $stageSucceeded = $?
  $stageExitCode = $LASTEXITCODE
  if (-not $stageSucceeded -or $stageExitCode -ne 0) {
    throw "Build staging failed with exit code $stageExitCode."
  }
  return $stageRoot
}

function Sync-BuildStage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BuildRoot
  )

  $resolvedBuildRoot = [System.IO.Path]::GetFullPath($BuildRoot).TrimEnd('\', '/')
  $resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\', '/')
  if ($resolvedBuildRoot.Equals($resolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return
  }

  $syncScript = Join-Path $scriptDir "sync_build_version_from_stage.ps1"
  Write-Host "Syncing build metadata from staged project."
  $global:LASTEXITCODE = 0
  & $syncScript -StageRoot $resolvedBuildRoot
  $syncSucceeded = $?
  $syncExitCode = $LASTEXITCODE
  if (-not $syncSucceeded -or $syncExitCode -ne 0) {
    throw "Build metadata sync failed with exit code $syncExitCode."
  }
}

function Copy-BuildArtifacts {
  $resolvedArtifactsDir = [System.IO.Path]::GetFullPath($ArtifactsDir)
  $resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot).TrimEnd('\', '/')
  $artifactSafeParent = if ($resolvedArtifactsDir.StartsWith($resolvedTempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    $tempRoot
  } else {
    $projectRoot
  }
  $artifactRoot = Reset-Directory -Path $ArtifactsDir -SafeParent $artifactSafeParent -Label "Artifacts directory"
  $expectedExtensions = if ($ArtifactType -eq "both") {
    @(".hap", ".app")
  } elseif ($ArtifactType -eq "hap") {
    @(".hap")
  } else {
    @(".app")
  }

  $searchRoots = Get-PackageSearchRoots

  if ($searchRoots.Count -eq 0) {
    throw "No HarmonyOS build output roots were found."
  }

  $allPackageFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
  foreach ($root in $searchRoots) {
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in @(".hap", ".app") } |
      ForEach-Object { $allPackageFiles.Add($_) | Out-Null }
  }

  $copied = New-Object System.Collections.Generic.List[object]
  foreach ($extension in $expectedExtensions) {
    $matchingFiles = $allPackageFiles |
      Where-Object { $_.Extension -eq $extension } |
      Sort-Object LastWriteTime -Descending
    if (-not $matchingFiles -or $matchingFiles.Count -eq 0) {
      throw "Expected $extension artifact was not produced."
    }

    foreach ($file in $matchingFiles | Select-Object -First 4) {
      $destination = Join-Path $artifactRoot $file.Name
      $destinationExists = $false
      try {
        $destinationExists = Test-Path -LiteralPath $destination
      } catch {
        $destinationExists = $true
      }
      if ($destinationExists) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $destination = Join-Path $artifactRoot ("{0}-{1:yyyyMMddHHmmss}{2}" -f $baseName, $file.LastWriteTime, $file.Extension)
      }
      Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
      $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToUpperInvariant()
      $item = Get-Item -LiteralPath $destination
      $copied.Add([ordered]@{
        Name = $item.Name
        Path = $item.FullName
        Size = $item.Length
        Sha256 = $hash
        Source = $file.FullName
      }) | Out-Null
    }
  }

  $packInfo = $allPackageFiles |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.DirectoryName "pack.info" }
  if ($packInfo -and (Test-Path -LiteralPath $packInfo)) {
    Copy-Item -LiteralPath $packInfo -Destination (Join-Path $artifactRoot "pack.info") -Force
  }

  return $copied
}

function Find-LatestBuiltPackage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Extension
  )

  $searchRoots = @($ArtifactsDir) + @(Get-PackageSearchRoots)
  $searchRoots = $searchRoots | Where-Object { Test-Path -LiteralPath $_ }

  foreach ($root in $searchRoots) {
    $candidate = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -eq $Extension } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
    if ($candidate) {
      return $candidate.FullName
    }
  }
  return ""
}

function Invoke-PackageVerification {
  if ($SkipPackageVerify) {
    Write-Host "Package verification skipped by -SkipPackageVerify."
    return
  }

  $verifyScript = Join-Path $scriptDir "verify_native_harmonyos_hap.ps1"
  if (-not (Test-Path -LiteralPath $verifyScript)) {
    throw "Package verification script was not found: $verifyScript"
  }

  $hapPath = Find-LatestBuiltPackage -Extension ".hap"
  if ([string]::IsNullOrWhiteSpace($hapPath)) {
    throw "No HAP was found for package verification. APP packaging should also produce an embedded module HAP."
  }

  Write-Host "Verifying generated HAP: $hapPath"
  $global:LASTEXITCODE = 0
  & $verifyScript -HapPath $hapPath -SkipLaunch -SkipLogs
  $verifySucceeded = $?
  $verifyExitCode = $LASTEXITCODE
  if (-not $verifySucceeded -or $verifyExitCode -ne 0) {
    throw "Generated HAP verification failed with exit code $verifyExitCode."
  }
}

function Write-Manifest {
  param(
    [Parameter(Mandatory = $true)]
    [object]$CoreInfo,
    [Parameter(Mandatory = $true)]
    [object[]]$Artifacts
  )

  $manifest = [ordered]@{
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    artifactType = $ArtifactType
    versionBump = $VersionBump
    project = $projectName
    core = $CoreInfo
    artifacts = $Artifacts
  }
  $manifestPath = Join-Path $ArtifactsDir "manifest.json"
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
  Write-Host "Artifact manifest: $manifestPath"
}

Write-Host "HarmonyOS GitHub build preflight"
Write-Host "Project: $projectRoot"
Write-Host "Temp root: $tempRoot"
Write-Host "Artifact type: $ArtifactType"
Write-Host "Version bump: $VersionBump"

$localProperties = Read-LocalProperties -Path (Join-Path $projectRoot "local.properties")
Confirm-RequiredRepoFiles
$deveco = Confirm-DevEcoEnvironment -LocalProperties $localProperties
$nodeExe = Resolve-NodeExecutable -LocalProperties $localProperties
$signingRoot = Confirm-SigningMaterial
$coreInfo = Confirm-NativeCore

Write-Host "DevEco tools: $($deveco.ToolsRoot)"
Write-Host "DevEco SDK: $($deveco.SdkRoot)"
Write-Host "Node: $nodeExe"
Write-Host "Signing material: $signingRoot"
Write-Host "Native core: $($coreInfo.Path)"
Write-Host "Native core size: $($coreInfo.Size)"
Write-Host "Native core sha256: $($coreInfo.Sha256)"

if ($PreflightOnly) {
  Write-Host "Preflight completed; build was skipped."
  exit 0
}

$tasks = Get-HvigorTasks
$buildRoot = New-BuildStage
Invoke-HarmonyBuild -NodeExe $nodeExe -Tasks $tasks -BuildRoot $buildRoot
Sync-BuildStage -BuildRoot $buildRoot
$artifacts = Copy-BuildArtifacts
Invoke-PackageVerification
Write-Manifest -CoreInfo $coreInfo -Artifacts @($artifacts)

Write-Host "Generated artifacts:"
foreach ($artifact in @($artifacts)) {
  Write-Host " - $($artifact.Name) ($($artifact.Size) bytes, sha256=$($artifact.Sha256))"
}
