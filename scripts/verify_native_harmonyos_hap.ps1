param(
  [string]$HapPath,
  [switch]$Install,
  [switch]$SkipSignatureCheck,
  [switch]$SkipLaunch,
  [switch]$SkipLogs,
  [string]$HdcTarget,
  [int]$LogTail = 200,
  [int]$LaunchDelaySeconds = 8,
  [string]$BundleName = "",
  [string]$AbilityName = "EntryAbility"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$buildRoot = if ($env:RUSTDESK_HARMONY_BUILD_DIR) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_BUILD_DIR)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp\rustdesk_harmonyos_build"))
}

$expectedEntries = @(
  "libs/arm64-v8a/librustdesk_bridge.so",
  "libs/arm64-v8a/libc++_shared.so"
)
$logRegex = "NativeRustDeskBridge|rustdesk_bridge|harmony_bridge|session-connected|video-frame|quality-status|fingerprint|msgbox"

function Get-AppBundleName {
  $appJsonPath = Join-Path $projectRoot "AppScope\app.json"
  if (-not (Test-Path -LiteralPath $appJsonPath)) {
    return $null
  }

  $rawJson = Get-Content -LiteralPath $appJsonPath -Raw
  if ([string]::IsNullOrWhiteSpace($rawJson)) {
    return $null
  }

  $appJson = $rawJson | ConvertFrom-Json
  $bundle = $appJson.app.bundleName
  if ([string]::IsNullOrWhiteSpace($bundle)) {
    return $null
  }

  return $bundle
}

function Resolve-DefaultHapPath {
  $candidates = @(
    $env:RUSTDESK_HARMONY_SIGNED_HAP,
    (Join-Path $buildRoot "windows_hap\entry-default-signed.hap"),
    (Join-Path $projectRoot "entry\build\default\outputs\default\entry-default-signed.hap"),
    (Join-Path $buildRoot "hap_repack\entry-default-native-signed-openharmony.hap")
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath $resolvedCandidate) {
      return $resolvedCandidate
    }
  }

  return [System.IO.Path]::GetFullPath((Join-Path $buildRoot "windows_hap\entry-default-signed.hap"))
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
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
      continue
    }
    $parts = $line -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }
    $key = $parts[0].Trim()
    $value = $parts[1].Trim() -replace '\\\\', '\'
    if ($key.Length -gt 0) {
      $values[$key] = $value
    }
  }

  return $values
}

function Get-DevEcoPaths {
  $properties = Read-LocalProperties -Path (Join-Path $projectRoot "local.properties")

  $sdkDirCandidates = @(
    $properties["sdk.dir"],
    $env:OHOS_BASE_SDK_HOME,
    $(if ($env:DEVECO_SDK_HOME) { Join-Path $env:DEVECO_SDK_HOME "openharmony" }),
    "C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony"
  ) | Where-Object { $_ }

  $hmsRootCandidates = @(
    $properties["hwsdk.dir"],
    $env:DEVECO_SDK_HOME,
    "C:\Program Files\Huawei\DevEco Studio\sdk\default"
  ) | Where-Object { $_ }

  $javaCandidates = @(
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\java.exe" }),
    "C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe"
  ) | Where-Object { $_ }

  $result = [ordered]@{
    Hdc = $null
    Java = $null
    HapSignTool = $null
  }

  foreach ($sdkDir in $sdkDirCandidates) {
    $resolvedSdkDir = [System.IO.Path]::GetFullPath($sdkDir)
    $hdcPath = Join-Path $resolvedSdkDir "toolchains\hdc.exe"
    $signToolPath = Join-Path $resolvedSdkDir "toolchains\lib\hap-sign-tool.jar"
    if (-not $result.Hdc -and (Test-Path -LiteralPath $hdcPath)) {
      $result.Hdc = $hdcPath
    }
    if (-not $result.HapSignTool -and (Test-Path -LiteralPath $signToolPath)) {
      $result.HapSignTool = $signToolPath
    }
  }

  foreach ($hmsRoot in $hmsRootCandidates) {
    $resolvedHmsRoot = [System.IO.Path]::GetFullPath($hmsRoot)
    if (-not $result.Hdc) {
      $hmsHdcPath = Join-Path $resolvedHmsRoot "openharmony\toolchains\hdc.exe"
      if (Test-Path -LiteralPath $hmsHdcPath) {
        $result.Hdc = $hmsHdcPath
      }
    }
    if (-not $result.HapSignTool) {
      $hmsSignToolPath = Join-Path $resolvedHmsRoot "openharmony\toolchains\lib\hap-sign-tool.jar"
      if (Test-Path -LiteralPath $hmsSignToolPath) {
        $result.HapSignTool = $hmsSignToolPath
      }
    }
  }

  foreach ($javaPath in $javaCandidates) {
    $resolvedJavaPath = [System.IO.Path]::GetFullPath($javaPath)
    if (Test-Path -LiteralPath $resolvedJavaPath) {
      $result.Java = $resolvedJavaPath
      break
    }
  }

  [PSCustomObject]$result
}

function Get-ZipEntries {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
  )

  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    return @($archive.Entries | ForEach-Object { $_.FullName })
  } finally {
    $archive.Dispose()
  }
}

function Read-ZipTextEntry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [Parameter(Mandatory = $true)]
    [string]$EntryName
  )

  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entry = $archive.GetEntry($EntryName)
    if ($null -eq $entry) {
      return $null
    }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    try {
      return $reader.ReadToEnd()
    } finally {
      $reader.Dispose()
    }
  } finally {
    $archive.Dispose()
  }
}

function Assert-NativeRuntimeDependencies {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath
  )

  $readelfCommand = Get-Command readelf -ErrorAction SilentlyContinue
  if (-not $readelfCommand -or -not $readelfCommand.Source) {
    Write-Warning "readelf was not found; native runtime dependency check skipped."
    return
  }

  $inspectDir = Join-Path $env:TEMP ("rustdesk_hap_native_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $inspectDir | Out-Null
  try {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
      $bridgeEntry = $archive.GetEntry("libs/arm64-v8a/librustdesk_bridge.so")
      if ($null -eq $bridgeEntry) {
        throw "librustdesk_bridge.so was not found inside $ZipPath"
      }
      $bridgePath = Join-Path $inspectDir "librustdesk_bridge.so"
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($bridgeEntry, $bridgePath, $true)
    } finally {
      $archive.Dispose()
    }

    $neededLines = & $readelfCommand.Source -d $bridgePath 2>&1 | Select-String -Pattern "NEEDED"
    $neededText = ($neededLines | ForEach-Object { "$_" }) -join "`n"
    if ($neededText -match "libtime_service_ndk\.so") {
      throw "librustdesk_bridge.so depends on libtime_service_ndk.so, which is not available on tested devices."
    }
    Write-Host "Native runtime dependency check passed."
  } finally {
    if (Test-Path -LiteralPath $inspectDir) {
      Remove-Item -LiteralPath $inspectDir -Recurse -Force
    }
  }
}

function Quote-CmdArgument {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-Hdc {
  param(
    [Parameter(Mandatory = $true)]
    [string]$HdcPath,
    [string]$Target,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [switch]$IgnoreExitCode
  )

  $hdcArgs = @()
  if ($Target) {
    $hdcArgs += @("-t", $Target)
  }
  $hdcArgs += $Arguments

  $output = & $HdcPath @hdcArgs 2>&1
  $exitCode = $LASTEXITCODE
  if (-not $IgnoreExitCode -and $exitCode -ne 0) {
    $message = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($message)) {
      throw "hdc failed with exit code $exitCode."
    }
    throw ("hdc failed with exit code {0}: {1}" -f $exitCode, $message)
  }

  [PSCustomObject]@{
    ExitCode = $exitCode
    Output = @($output)
  }
}

if (-not $HapPath) {
  $HapPath = Resolve-DefaultHapPath
}
$HapPath = [System.IO.Path]::GetFullPath($HapPath)

if (-not (Test-Path -LiteralPath $HapPath)) {
  throw "HAP was not found: $HapPath"
}

$paths = Get-DevEcoPaths
if (-not $SkipSignatureCheck) {
  if (-not $paths.Java) {
    throw "java.exe was not found. Set JAVA_HOME or install DevEco Studio JBR."
  }
  if (-not $paths.HapSignTool) {
    throw "hap-sign-tool.jar was not found. Check the local Harmony/OpenHarmony SDK installation."
  }
}
if ($Install -and -not $paths.Hdc) {
  throw "hdc.exe was not found. Check the local Harmony/OpenHarmony SDK installation."
}

Write-Host "Inspecting HAP: $HapPath"
$entries = Get-ZipEntries -ZipPath $HapPath
$missingEntries = @($expectedEntries | Where-Object { $entries -notcontains $_ })
if ($missingEntries.Count -gt 0) {
  throw "Missing expected native entries: $($missingEntries -join ', ')"
}
Write-Host "Verified native entries:"
foreach ($entry in $expectedEntries) {
  Write-Host " - $entry"
}
Assert-NativeRuntimeDependencies -ZipPath $HapPath

$packInfoText = Read-ZipTextEntry -ZipPath $HapPath -EntryName "pack.info"
if ($packInfoText) {
  $packInfo = $packInfoText | ConvertFrom-Json
  $bundle = $packInfo.summary.app.bundleName
  $packageName = $packInfo.packages[0].name
  Write-Host "Bundle: $bundle"
  Write-Host "Package: $packageName"
  if ([string]::IsNullOrWhiteSpace($BundleName)) {
    $BundleName = $bundle
  }
}

if ([string]::IsNullOrWhiteSpace($BundleName)) {
  $BundleName = Get-AppBundleName
}

if (-not [string]::IsNullOrWhiteSpace($BundleName)) {
  Write-Host "Launch bundle: $BundleName"
}

if (-not $SkipSignatureCheck) {
  $verifyDir = Join-Path $buildRoot "windows_verify_direct_signed"
  New-Item -ItemType Directory -Force -Path $verifyDir | Out-Null
  $verifyNonce = [Guid]::NewGuid().ToString("N")
  $certChainPath = Join-Path $verifyDir "cert-chain-$verifyNonce.cer"
  $profilePath = Join-Path $verifyDir "profile-$verifyNonce.p7b"

  $verifyCommand = @(
    (Quote-CmdArgument -Value ([string]$paths.Java)),
    "-jar",
    (Quote-CmdArgument -Value ([string]$paths.HapSignTool)),
    "verify-app",
    "-inFile",
    (Quote-CmdArgument -Value $HapPath),
    "-outCertChain",
    (Quote-CmdArgument -Value $certChainPath),
    "-outProfile",
    (Quote-CmdArgument -Value $profilePath),
    "-inForm",
    "zip",
    "2>&1"
  ) -join " "
  $verifyOutput = cmd.exe /d /c $verifyCommand
  $verifyExitCode = $LASTEXITCODE
  if ($verifyExitCode -ne 0) {
    $verifyText = ($verifyOutput | Out-String).Trim()
    throw "HAP signature verification failed: $verifyText"
  }

  Write-Host "Signature verification passed."
  foreach ($line in $verifyOutput) {
    if ($line -match 'profile type is:' -or $line -match 'verify lib:' -or $line -match 'Subject:' -or $line -match 'verify-app success') {
      Write-Host $line
    }
  }
}

if (-not $Install) {
  Write-Host "Install step skipped. Re-run with -Install once the phone is visible to Windows hdc."
  exit 0
}

$targets = @(
  (Invoke-Hdc -HdcPath $paths.Hdc -Target $HdcTarget -Arguments @("list", "targets") -IgnoreExitCode).Output |
    ForEach-Object { "$_".Trim() } |
    Where-Object { $_ -and $_ -ne "[Empty]" }
)

if (-not $HdcTarget) {
  if ($targets.Count -eq 0) {
    throw "No connected HarmonyOS targets were found on Windows."
  }
  if ($targets.Count -gt 1) {
    throw "Multiple HarmonyOS targets were found. Re-run with -HdcTarget <connect key>."
  }
  $HdcTarget = $targets[0]
}

Write-Host "Using HDC target: $HdcTarget"

Invoke-Hdc -HdcPath $paths.Hdc -Target $HdcTarget -Arguments @("shell", "hilog", "-r") -IgnoreExitCode | Out-Null

$installResult = Invoke-Hdc -HdcPath $paths.Hdc -Target $HdcTarget -Arguments @("install", "-r", $HapPath)
$installText = ($installResult.Output | Out-String).Trim()
Write-Host $installText
if ($installText -match "failed to install|error:|Install Failed") {
  throw "HAP install failed: $installText"
}

if (-not $SkipLaunch) {
  if ([string]::IsNullOrWhiteSpace($BundleName)) {
    throw "Bundle name could not be determined. Set -BundleName explicitly."
  }
  $launchResult = Invoke-Hdc -HdcPath $paths.Hdc -Target $HdcTarget -Arguments @(
    "shell", "aa", "start", "-a", $AbilityName, "-b", $BundleName
  ) -IgnoreExitCode
  $launchText = ($launchResult.Output | Out-String).Trim()
  if ($launchResult.ExitCode -eq 0) {
    Write-Host "Launch command sent."
  } elseif (-not [string]::IsNullOrWhiteSpace($launchText)) {
    Write-Warning "Launch command reported: $launchText"
  }
  Start-Sleep -Seconds $LaunchDelaySeconds
}

if ($SkipLogs) {
  Write-Host "Log capture skipped."
  exit 0
}

$logResult = Invoke-Hdc -HdcPath $paths.Hdc -Target $HdcTarget -Arguments @(
  "shell", "hilog", "-z", "$LogTail", "-v", "time", "-v", "year", "-v", "zone"
) -IgnoreExitCode

$logLines = @(
  $logResult.Output |
    Where-Object { $_ -and "$_".Trim().Length -gt 0 -and "$_" -match $logRegex }
)
if ($logLines.Count -eq 0) {
  Write-Warning "No matching bridge logs were found in the recent hilog buffer."
  exit 0
}

Write-Host "Matched bridge logs:"
foreach ($line in $logLines) {
  Write-Host $line
}

$summaryChecks = [ordered]@{
  "NativeRustDeskBridge module present" = $false
  "NativeRustDeskBridge bootstrap snapshot" = $false
  "NativeRustDeskBridge requireNapi failed" = $false
  "rustdesk_bridge" = $false
}

foreach ($line in $logLines) {
  foreach ($key in @($summaryChecks.Keys)) {
    if ($line -match [regex]::Escape($key)) {
      $summaryChecks[$key] = $true
    }
  }
}

Write-Host "Log summary:"
foreach ($key in @($summaryChecks.Keys)) {
  Write-Host (" - {0}: {1}" -f $key, $summaryChecks[$key])
}
