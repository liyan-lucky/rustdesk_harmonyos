param(
  [string]$HapPath = "",
  [string]$RustDeskSourceRoot = "",
  [string]$ReportPath = "",
  [int64]$MinCoreBytes = 52428800
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = $PSScriptRoot
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $scriptDir))
$projectName = Split-Path -Leaf $projectRoot
if ([string]::IsNullOrWhiteSpace($RustDeskSourceRoot)) {
  $RustDeskSourceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp\rustdesk-master"))
} else {
  $RustDeskSourceRoot = [System.IO.Path]::GetFullPath($RustDeskSourceRoot)
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $projectRoot "reports\connection_chain_audit_latest.md"
}
$ReportPath = [System.IO.Path]::GetFullPath($ReportPath)

$results = New-Object System.Collections.Generic.List[object]

function New-CheckResult {
  param(
    [ValidateSet("PASS", "FAIL", "SKIP")]
    [string]$Status,
    [string]$Detail
  )
  return [ordered]@{
    Status = $Status
    Detail = $Detail
  }
}

function Get-RepoPath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  return [System.IO.Path]::GetFullPath((Join-Path $projectRoot $RelativePath))
}

function Get-ExternalPath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  return [System.IO.Path]::GetFullPath((Join-Path $RustDeskSourceRoot $RelativePath))
}

function Read-TextFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }
  return Get-Content -LiteralPath $Path -Raw
}

function Test-FileExists {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $path = Get-RepoPath $RelativePath
  if (Test-Path -LiteralPath $path) {
    return New-CheckResult "PASS" $RelativePath
  }
  return New-CheckResult "FAIL" "missing: $RelativePath"
}

function Test-TextMatch {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [string]$Detail = ""
  )
  $path = Get-RepoPath $RelativePath
  $text = Read-TextFile $path
  if ($null -eq $text) {
    return New-CheckResult "FAIL" "missing: $RelativePath"
  }
  if ($text -match $Pattern) {
    return New-CheckResult "PASS" $(if ($Detail) { $Detail } else { "$RelativePath matches $Pattern" })
  }
  return New-CheckResult "FAIL" "$RelativePath does not match $Pattern"
}

function Test-TextNotMatch {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [string]$Detail = ""
  )
  $path = Get-RepoPath $RelativePath
  $text = Read-TextFile $path
  if ($null -eq $text) {
    return New-CheckResult "FAIL" "missing: $RelativePath"
  }
  if ($text -notmatch $Pattern) {
    return New-CheckResult "PASS" $(if ($Detail) { $Detail } else { "$RelativePath does not match forbidden pattern" })
  }
  return New-CheckResult "FAIL" "$RelativePath contains forbidden pattern: $Pattern"
}

function Invoke-AuditCheck {
  param(
    [Parameter(Mandatory = $true)][int]$Number,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Body
  )
  try {
    $result = & $Body
    if ($null -eq $result) {
      $result = New-CheckResult "FAIL" "check returned no result"
    }
  } catch {
    $result = New-CheckResult "FAIL" $_.Exception.Message
  }

  $item = [PSCustomObject]@{
    Number = $Number
    Name = $Name
    Status = [string]$result.Status
    Detail = [string]$result.Detail
  }
  $results.Add($item) | Out-Null

  $statusText = "[{0}] {1:00}. {2} - {3}" -f $item.Status, $item.Number, $item.Name, $item.Detail
  if ($item.Status -eq "PASS") {
    Write-Host $statusText -ForegroundColor Green
  } elseif ($item.Status -eq "SKIP") {
    Write-Host $statusText -ForegroundColor Yellow
  } else {
    Write-Host $statusText -ForegroundColor Red
  }
}

function Resolve-HapPath {
  if (-not [string]::IsNullOrWhiteSpace($HapPath)) {
    $resolved = [System.IO.Path]::GetFullPath($HapPath)
    if (Test-Path -LiteralPath $resolved) {
      return $resolved
    }
    return ""
  }

  $candidates = @(
    $env:RUSTDESK_HARMONY_SIGNED_HAP,
    (Join-Path $projectRoot "..\99_Temp\harmonyos_build\$projectName\entry\build\default\outputs\default\entry-default-signed.hap"),
    (Join-Path $projectRoot "entry\build\default\outputs\default\entry-default-signed.hap"),
    (Join-Path $projectRoot "..\99_Temp\rustdesk_harmonyos_build\windows_hap\entry-default-signed.hap")
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidate in $candidates) {
    $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
    if (Test-Path -LiteralPath $resolvedCandidate) {
      return $resolvedCandidate
    }
  }
  return ""
}

function Get-ZipEntries {
  param([Parameter(Mandatory = $true)][string]$ZipPath)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    return @($archive.Entries | ForEach-Object { $_.FullName })
  } finally {
    $archive.Dispose()
  }
}

function Extract-ZipEntry {
  param(
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$EntryName,
    [Parameter(Mandatory = $true)][string]$OutPath
  )
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entry = $archive.GetEntry($EntryName)
    if ($null -eq $entry) {
      return $false
    }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $OutPath, $true)
    return $true
  } finally {
    $archive.Dispose()
  }
}

function Resolve-ReadElf {
  $commands = @("readelf", "llvm-readelf")
  foreach ($command in $commands) {
    $found = Get-Command $command -ErrorAction SilentlyContinue
    if ($found -and $found.Source) {
      return $found.Source
    }
  }
  return ""
}

function Get-CoreInfoValue {
  param(
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][string]$Name
  )
  $match = [regex]::Match($Content, "$Name\s*:\s*(?:number|string)\s*=\s*`"?([^`";]+)`"?")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }
  return ""
}

function Test-CoreBuildInfoValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Expected
  )
  $infoPath = Get-RepoPath "entry\src\main\ets\common\CoreBuildInfo.ets"
  $content = Read-TextFile $infoPath
  if ($null -eq $content) {
    return New-CheckResult "FAIL" "CoreBuildInfo.ets missing"
  }
  $actual = Get-CoreInfoValue -Content $content -Name $Name
  if ($actual -eq $Expected) {
    return New-CheckResult "PASS" "$Name=$actual"
  }
  return New-CheckResult "FAIL" "$Name expected $Expected, got $actual"
}

$nativeBridgePath = "entry\src\main\ets\services\NativeRustDeskBridge.ts"
$officialBridgePath = "entry\src\main\ets\services\OfficialRustDeskBridge.ets"
$remoteControlPath = "entry\src\main\ets\pages\RemoteControl.ets"
$indexPath = "entry\src\main\ets\pages\Index.ets"
$cmakePath = "entry\src\main\cpp\CMakeLists.txt"
$loaderPath = "entry\src\main\cpp\rustdesk_bridge_loader.cpp"
$stubsPath = "entry\src\main\cpp\ohos_stubs.cpp"
$corePath = Get-RepoPath "entry\src\main\libs\arm64\librustdesk_core.a"
$hapResolvedPath = Resolve-HapPath

Invoke-AuditCheck 1 "Hvigor build wrapper exists" { Test-FileExists "scripts\run_hvigor_with_sdk_patch.js" }
Invoke-AuditCheck 2 "Native HAP verifier exists" { Test-FileExists "scripts\verify_native_harmonyos_hap.ps1" }
Invoke-AuditCheck 3 "GitHub online build wrapper exists" { Test-FileExists "scripts\github_build_harmonyos.ps1" }
Invoke-AuditCheck 4 "GitHub online workflow exists" { Test-FileExists ".github\workflows\build-harmonyos.yml" }
Invoke-AuditCheck 5 "App profile exists" { Test-FileExists "AppScope\app.json5" }
Invoke-AuditCheck 6 "Entry build profile exists" { Test-FileExists "entry\build-profile.json5" }

Invoke-AuditCheck 7 "Native core archive exists" {
  if (Test-Path -LiteralPath $corePath) {
    return New-CheckResult "PASS" $corePath
  }
  return New-CheckResult "FAIL" "missing native core archive: $corePath"
}
Invoke-AuditCheck 8 "Native core archive size is plausible" {
  if (-not (Test-Path -LiteralPath $corePath)) {
    return New-CheckResult "FAIL" "native core archive missing"
  }
  $size = (Get-Item -LiteralPath $corePath).Length
  if ($size -ge $MinCoreBytes) {
    return New-CheckResult "PASS" "$size bytes"
  }
  return New-CheckResult "FAIL" "$size bytes is below $MinCoreBytes"
}
Invoke-AuditCheck 9 "CoreBuildInfo exists" { Test-FileExists "entry\src\main\ets\common\CoreBuildInfo.ets" }
Invoke-AuditCheck 10 "CoreBuildInfo size matches native core" {
  if (-not (Test-Path -LiteralPath $corePath)) {
    return New-CheckResult "FAIL" "native core archive missing"
  }
  Test-CoreBuildInfoValue "FILE_SIZE" "$((Get-Item -LiteralPath $corePath).Length)"
}
Invoke-AuditCheck 11 "CoreBuildInfo SHA256 matches native core" {
  if (-not (Test-Path -LiteralPath $corePath)) {
    return New-CheckResult "FAIL" "native core archive missing"
  }
  $sha = (Get-FileHash -LiteralPath $corePath -Algorithm SHA256).Hash.ToUpperInvariant()
  Test-CoreBuildInfoValue "HASH_SHA256" $sha
}
Invoke-AuditCheck 12 "CMake declares rustdesk_bridge shared library" { Test-TextMatch $cmakePath "add_library\(\s*rustdesk_bridge\s+SHARED" }
Invoke-AuditCheck 13 "CMake links static native core archive" { Test-TextMatch $cmakePath "librustdesk_core\.a" }
Invoke-AuditCheck 14 "CMake does not link time_service_ndk" { Test-TextNotMatch $cmakePath "time_service_ndk" }
Invoke-AuditCheck 15 "OH_TimeService fallback stub is compiled locally" { Test-TextMatch $stubsPath "OH_TimeService_GetTimeZone" }
Invoke-AuditCheck 16 "NAPI loader source exists" { Test-FileExists $loaderPath }
Invoke-AuditCheck 17 "NAPI loader registers librustdesk_bridge.so alias" { Test-TextMatch $loaderPath 'nm_modname\s*=\s*"librustdesk_bridge\.so"' }
Invoke-AuditCheck 18 "NAPI loader registers librustdesk_bridge alias" { Test-TextMatch $loaderPath 'nm_modname\s*=\s*"librustdesk_bridge"' }
Invoke-AuditCheck 19 "NAPI loader registers canonical rustdesk_bridge name" { Test-TextMatch $loaderPath 'nm_modname\s*=\s*"rustdesk_bridge"' }
Invoke-AuditCheck 20 "NAPI loader logs alias registration" { Test-TextMatch $loaderPath "aliases ready" }

Invoke-AuditCheck 21 "ArkTS statically imports native bridge so" { Test-TextMatch $nativeBridgePath "import\s+rustdeskBridgeLibrary\s+from\s+'librustdesk_bridge\.so'" }
Invoke-AuditCheck 22 "Native module candidates include canonical name" { Test-TextMatch $nativeBridgePath "'rustdesk_bridge'" }
Invoke-AuditCheck 23 "Native module shape probes nested rustdesk_bridge export" { Test-TextMatch $nativeBridgePath "top\.rustdesk_bridge" }
Invoke-AuditCheck 24 "Known bridge function list includes connectToPeer" { Test-TextMatch $nativeBridgePath "'connectToPeer'" }
Invoke-AuditCheck 25 "initializeRuntime wrapper is present" { Test-TextMatch $nativeBridgePath "static\s+initializeRuntime" }
Invoke-AuditCheck 26 "connectToPeer wrapper resolves native ABI names" { Test-TextMatch $nativeBridgePath "rustdesk_bridge_connect_to_peer" }
Invoke-AuditCheck 27 "pullSessionEvents wrapper is present" { Test-TextMatch $nativeBridgePath "pullSessionEvents" }
Invoke-AuditCheck 28 "pullLatestVideoFrame wrapper is present" { Test-TextMatch $nativeBridgePath "pullLatestVideoFrame" }
Invoke-AuditCheck 29 "refreshSessionVideo wrapper is present" { Test-TextMatch $nativeBridgePath "refreshSessionVideo" }
Invoke-AuditCheck 30 "harmonyNextRgba wrapper is present" { Test-TextMatch $nativeBridgePath "harmonyNextRgba" }
Invoke-AuditCheck 31 "reconnectSession wrapper is present" { Test-TextMatch $nativeBridgePath "reconnectSession" }
Invoke-AuditCheck 32 "submitSessionPassword wrapper is present" { Test-TextMatch $nativeBridgePath "submitSessionPassword" }

Invoke-AuditCheck 33 "Official bridge reports missing native core as hard error" { Test-TextMatch $officialBridgePath "Native core missing" }
Invoke-AuditCheck 34 "Official bridge retries connect after native reset" { Test-TextMatch $officialBridgePath "resetForRetry\(\)" }
Invoke-AuditCheck 35 "Official bridge handles session-connected events" { Test-TextMatch $officialBridgePath "session-connected" }
Invoke-AuditCheck 36 "Official bridge handles session-error events" { Test-TextMatch $officialBridgePath "session-error" }
Invoke-AuditCheck 37 "Official bridge handles session-closed events" { Test-TextMatch $officialBridgePath "session-closed" }
Invoke-AuditCheck 38 "Remote page has terminal event handler" { Test-TextMatch $remoteControlPath "handleTerminalBridgeEvent" }
Invoke-AuditCheck 39 "Remote terminal event handler opens reconnect dialog" { Test-TextMatch $remoteControlPath "showReconnectDialogFromState\(this\.lt\('Connection Error'\)" }
Invoke-AuditCheck 40 "Remote page has stale connected-session watchdog" { Test-TextMatch $remoteControlPath "maybeHandleStaleConnectedSession" }

Invoke-AuditCheck 41 "Quality status is cached even when panel is hidden" {
  $text = Read-TextFile (Get-RepoPath $remoteControlPath)
  if ($null -eq $text) {
    return New-CheckResult "FAIL" "RemoteControl missing"
  }
  $match = [regex]::Match($text, "private\s+applyQualityStatus[\s\S]*?private\s+computeCombinedSpeedDisplay")
  if (-not $match.Success) {
    return New-CheckResult "FAIL" "applyQualityStatus block not found"
  }
  if ($match.Value -match "if\s*\(\s*!this\.showConnectionInfo\s*\)\s*\{\s*return\s*;\s*\}") {
    return New-CheckResult "FAIL" "quality-status still returns early while panel is hidden"
  }
  return New-CheckResult "PASS" "applyQualityStatus parses and caches before panel rendering"
}
Invoke-AuditCheck 42 "Quality cache state exists" { Test-TextMatch $remoteControlPath "qualityMetricItems" }
Invoke-AuditCheck 43 "Quality cache updater exists" { Test-TextMatch $remoteControlPath "updateQualityDetailCache" }
Invoke-AuditCheck 44 "Connection info panel is scrollable" { Test-TextMatch $remoteControlPath "Scroll\(\)\s*\{\s*Column\(\{\s*space:\s*8\s*\}\)" }
Invoke-AuditCheck 45 "Quality panel renders dynamic metric rows" { Test-TextMatch $remoteControlPath "ForEach\(this\.qualityMetricItems" }
Invoke-AuditCheck 46 "Quality parser captures target bitrate" { Test-TextMatch $remoteControlPath "target_bitrate" }
Invoke-AuditCheck 47 "Quality parser captures codec format" { Test-TextMatch $remoteControlPath "codec_format" }
Invoke-AuditCheck 48 "Speed summary falls back to target bitrate" { Test-TextMatch $remoteControlPath "targetBitrateDisplay" }

Invoke-AuditCheck 49 "Built HAP contains required native libraries" {
  if ([string]::IsNullOrWhiteSpace($hapResolvedPath)) {
    return New-CheckResult "SKIP" "signed HAP not found; run assembleHap first or pass -HapPath"
  }
  $entries = Get-ZipEntries $hapResolvedPath
  $hasBridge = $entries -contains "libs/arm64-v8a/librustdesk_bridge.so"
  $hasCpp = $entries -contains "libs/arm64-v8a/libc++_shared.so"
  if ($hasBridge -and $hasCpp) {
    return New-CheckResult "PASS" $hapResolvedPath
  }
  return New-CheckResult "FAIL" "bridge=$hasBridge libc++=$hasCpp in $hapResolvedPath"
}
Invoke-AuditCheck 50 "Packaged native bridge has no missing time service dependency" {
  if ([string]::IsNullOrWhiteSpace($hapResolvedPath)) {
    return New-CheckResult "SKIP" "signed HAP not found; run assembleHap first or pass -HapPath"
  }
  $readelf = Resolve-ReadElf
  if ([string]::IsNullOrWhiteSpace($readelf)) {
    return New-CheckResult "SKIP" "readelf/llvm-readelf not found"
  }
  $tempDir = Join-Path $env:TEMP ("rustdesk_chain_audit_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
  try {
    $bridgeOut = Join-Path $tempDir "librustdesk_bridge.so"
    if (-not (Extract-ZipEntry -ZipPath $hapResolvedPath -EntryName "libs/arm64-v8a/librustdesk_bridge.so" -OutPath $bridgeOut)) {
      return New-CheckResult "FAIL" "librustdesk_bridge.so missing from HAP"
    }
    $needed = & $readelf -d $bridgeOut 2>&1 | Out-String
    if ($needed -match "libtime_service_ndk\.so") {
      return New-CheckResult "FAIL" "libtime_service_ndk.so is still a runtime dependency"
    }
    if ($needed -notmatch "libace_napi\.z\.so" -or $needed -notmatch "libhilog_ndk\.z\.so") {
      return New-CheckResult "FAIL" "expected NAPI/Hilog dependencies not found"
    }
    return New-CheckResult "PASS" "NEEDED set excludes libtime_service_ndk.so and includes NAPI/Hilog"
  } finally {
    if (Test-Path -LiteralPath $tempDir) {
      Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
  }
}

$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$skipCount = @($results | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Host ""
Write-Host ("Connection chain audit: {0} PASS, {1} FAIL, {2} SKIP" -f $passCount, $failCount, $skipCount)

$reportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Connection Chain Audit") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Project: $projectRoot") | Out-Null
$lines.Add("- HAP: $(if ($hapResolvedPath) { $hapResolvedPath } else { 'not found' })") | Out-Null
$lines.Add("- Summary: $passCount PASS, $failCount FAIL, $skipCount SKIP") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| # | Status | Check | Detail |") | Out-Null
$lines.Add("|---:|:---:|---|---|") | Out-Null
foreach ($item in $results) {
  $detail = $item.Detail.Replace("|", "\|")
  $lines.Add("| $($item.Number) | $($item.Status) | $($item.Name) | $detail |") | Out-Null
}
$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Report written: $ReportPath"

if ($failCount -gt 0) {
  exit 1
}
