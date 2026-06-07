param(
  [int]$Rounds = 100,
  [string]$HapPath = "",
  [string]$AppPath = "",
  [string]$ReportPath = "",
  [int64]$MinCoreBytes = 52428800
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = $PSScriptRoot
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $scriptDir))
$projectName = Split-Path -Leaf $projectRoot
$tempRoot = if ($env:RUSTDESK_HARMONY_TEMP_ROOT) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_TEMP_ROOT)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp"))
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
  $ReportPath = Join-Path $projectRoot "reports\full_function_audit_latest.md"
}
$ReportPath = [System.IO.Path]::GetFullPath($ReportPath)

$fileCache = @{}
$checks = New-Object System.Collections.Generic.List[object]
$roundResults = New-Object System.Collections.Generic.List[object]

function New-Result {
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

function Read-RepoText {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  if ($fileCache.ContainsKey($RelativePath)) {
    return $fileCache[$RelativePath]
  }
  $path = Get-RepoPath $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    $fileCache[$RelativePath] = $null
    return $null
  }
  $text = Get-Content -LiteralPath $path -Raw
  $fileCache[$RelativePath] = $text
  return $text
}

function Resolve-LatestPackage {
  param([Parameter(Mandatory = $true)][string]$Extension)
  $roots = @(
    (Join-Path $projectRoot "github_artifacts"),
    (Join-Path $tempRoot "harmonyos_build\$projectName"),
    (Join-Path $projectRoot "entry\build"),
    (Join-Path $projectRoot "build")
  ) | Where-Object { Test-Path -LiteralPath $_ }

  foreach ($root in $roots) {
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

function Get-ZipEntryNames {
  param([Parameter(Mandatory = $true)][string]$ZipPath)
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    return @($archive.Entries | ForEach-Object { $_.FullName })
  } finally {
    $archive.Dispose()
  }
}

function Test-FileExists {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $path = Get-RepoPath $RelativePath
  if (Test-Path -LiteralPath $path) {
    return New-Result "PASS" $RelativePath
  }
  return New-Result "FAIL" "missing $RelativePath"
}

function Test-Pattern {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Pattern
  )
  $text = Read-RepoText $RelativePath
  if ($null -eq $text) {
    return New-Result "FAIL" "missing $RelativePath"
  }
  if ($text -match $Pattern) {
    return New-Result "PASS" $RelativePath
  }
  return New-Result "FAIL" "$RelativePath lacks pattern $Pattern"
}

function Test-NotPattern {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Pattern
  )
  $text = Read-RepoText $RelativePath
  if ($null -eq $text) {
    return New-Result "FAIL" "missing $RelativePath"
  }
  if ($text -notmatch $Pattern) {
    return New-Result "PASS" $RelativePath
  }
  return New-Result "FAIL" "$RelativePath contains forbidden pattern $Pattern"
}

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Body
  )
  $checks.Add([PSCustomObject]@{
    Name = $Name
    Body = $Body
  }) | Out-Null
}

function Add-FileCheck {
  param([string]$Name, [string]$RelativePath)
  Add-Check $Name ({ Test-FileExists -RelativePath $RelativePath }.GetNewClosure())
}

function Add-PatternCheck {
  param([string]$Name, [string]$RelativePath, [string]$Pattern)
  Add-Check $Name ({ Test-Pattern -RelativePath $RelativePath -Pattern $Pattern }.GetNewClosure())
}

function Add-NotPatternCheck {
  param([string]$Name, [string]$RelativePath, [string]$Pattern)
  Add-Check $Name ({ Test-NotPattern -RelativePath $RelativePath -Pattern $Pattern }.GetNewClosure())
}

function Get-CoreInfoValue {
  param([string]$Text, [string]$Name)
  $match = [regex]::Match($Text, "$Name\s*:\s*(?:number|string)\s*=\s*`"?([^`";]+)`"?")
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }
  return ""
}

function Get-AppVersionInfo {
  $text = Read-RepoText "AppScope\app.json5"
  if ($null -eq $text) {
    return $null
  }
  $nameMatch = [regex]::Match($text, '"versionName"\s*:\s*"([^"]+)"')
  $codeMatch = [regex]::Match($text, '"versionCode"\s*:\s*(\d+)')
  if (-not $nameMatch.Success -or -not $codeMatch.Success) {
    return $null
  }
  return [PSCustomObject]@{
    VersionName = $nameMatch.Groups[1].Value
    VersionCode = [int]$codeMatch.Groups[1].Value
  }
}

$hapResolved = if ([string]::IsNullOrWhiteSpace($HapPath)) { Resolve-LatestPackage ".hap" } else { [System.IO.Path]::GetFullPath($HapPath) }
$appResolved = if ([string]::IsNullOrWhiteSpace($AppPath)) { Resolve-LatestPackage ".app" } else { [System.IO.Path]::GetFullPath($AppPath) }

Add-FileCheck "app profile" "AppScope\app.json5"
Add-FileCheck "entry module profile" "entry\src\main\module.json5"
Add-FileCheck "native bridge loader" "entry\src\main\cpp\rustdesk_bridge_loader.cpp"
Add-FileCheck "native bridge dts" "entry\src\main\ets\services\librustdesk_bridge.d.ts"
Add-FileCheck "native bridge service" "entry\src\main\ets\services\NativeRustDeskBridge.ts"
Add-FileCheck "official bridge service" "entry\src\main\ets\services\OfficialRustDeskBridge.ets"
Add-FileCheck "remote page" "entry\src\main\ets\pages\RemoteControl.ets"
Add-FileCheck "index page" "entry\src\main\ets\pages\Index.ets"
Add-FileCheck "lan service" "entry\src\main\ets\services\LanDiscoveryService.ets"
Add-FileCheck "chat service" "entry\src\main\ets\services\ChatService.ets"
Add-FileCheck "file transfer service" "entry\src\main\ets\services\FileTransferService.ets"
Add-FileCheck "terminal service" "entry\src\main\ets\services\TerminalService.ets"
Add-FileCheck "clipboard service" "entry\src\main\ets\services\ClipboardService.ets"
Add-FileCheck "audio service" "entry\src\main\ets\services\AudioService.ets"
Add-FileCheck "permission service" "entry\src\main\ets\services\PermissionService.ets"
Add-FileCheck "build wrapper" "scripts\run_hvigor_with_sdk_patch.js"
Add-FileCheck "github build wrapper" "scripts\github_build_harmonyos.ps1"
Add-FileCheck "github workflow" ".github\workflows\build-harmonyos.yml"
Add-FileCheck "package verifier" "scripts\verify_native_harmonyos_hap.ps1"
Add-FileCheck "stage build helper" "scripts\stage_project_for_build.ps1"
Add-FileCheck "stage sync helper" "scripts\sync_build_version_from_stage.ps1"

Add-Check "native core archive exists and is plausible" {
  $path = Get-RepoPath "entry\src\main\libs\arm64\librustdesk_core.a"
  if (-not (Test-Path -LiteralPath $path)) {
    return New-Result "FAIL" "native core archive missing"
  }
  $size = (Get-Item -LiteralPath $path).Length
  if ($size -lt $MinCoreBytes) {
    return New-Result "FAIL" "$size bytes below $MinCoreBytes"
  }
  return New-Result "PASS" "$size bytes"
}

Add-Check "CoreBuildInfo size and hash match native core" {
  $corePath = Get-RepoPath "entry\src\main\libs\arm64\librustdesk_core.a"
  $infoText = Read-RepoText "entry\src\main\ets\common\CoreBuildInfo.ets"
  if (-not (Test-Path -LiteralPath $corePath) -or $null -eq $infoText) {
    return New-Result "FAIL" "core file or CoreBuildInfo missing"
  }
  $size = (Get-Item -LiteralPath $corePath).Length
  $sha = (Get-FileHash -LiteralPath $corePath -Algorithm SHA256).Hash.ToUpperInvariant()
  $declaredSize = Get-CoreInfoValue -Text $infoText -Name "FILE_SIZE"
  $declaredSha = (Get-CoreInfoValue -Text $infoText -Name "HASH_SHA256").ToUpperInvariant()
  if ($declaredSize -ne "$size") {
    return New-Result "FAIL" "FILE_SIZE $declaredSize != $size"
  }
  if ($declaredSha -ne $sha) {
    return New-Result "FAIL" "HASH_SHA256 mismatch"
  }
  return New-Result "PASS" "$size bytes $sha"
}

Add-PatternCheck "core compatible official version visible" "entry\src\main\ets\common\CoreBuildInfo.ets" "COMPATIBLE_OFFICIAL_VERSION"
Add-PatternCheck "core compile time is core metadata" "entry\src\main\ets\common\CoreBuildInfo.ets" "COMPILE_TIME"
Add-PatternCheck "app build info exists" "entry\src\main\ets\common\BuildInfo.ets" "BUILD_TIME"
Add-Check "AppScope and BuildInfo version agree" {
  $appInfo = Get-AppVersionInfo
  $buildInfo = Read-RepoText "entry\src\main\ets\common\BuildInfo.ets"
  if ($null -eq $appInfo -or $null -eq $buildInfo) {
    return New-Result "FAIL" "version metadata missing"
  }
  if ($buildInfo -match "VERSION:\s*string\s*=\s*'$([regex]::Escape($appInfo.VersionName))'") {
    return New-Result "PASS" $appInfo.VersionName
  }
  return New-Result "FAIL" "BuildInfo VERSION does not match $($appInfo.VersionName)"
}

Add-PatternCheck "no-password connection opens password dialog" "entry\src\main\ets\pages\Index.ets" 'showConnectPasswordDialog\(targetId,\s*true\)'
Add-PatternCheck "no-password request remains active while password dialog is shown" "entry\src\main\ets\pages\Index.ets" "Enter remote password if known, or wait for remote confirmation"
Add-PatternCheck "remote route carries password dialog flag" "entry\src\main\ets\pages\Index.ets" "showPasswordDialog:\s*shouldShowPasswordDialog"
Add-PatternCheck "remote route carries proactive password flag" "entry\src\main\ets\pages\Index.ets" "passwordPromptProactive:\s*shouldUseProactivePasswordDialog"
Add-PatternCheck "password confirmation switches to password reconnect" "entry\src\main\ets\pages\Index.ets" "Switching to password connection"
Add-PatternCheck "remote page accepts proactive password route" "entry\src\main\ets\pages\RemoteControl.ets" "passwordPromptProactive"
Add-PatternCheck "remote page preserves password dialog until first frame" "entry\src\main\ets\pages\RemoteControl.ets" "keepPasswordFallback"
Add-PatternCheck "password prompt helper covers unicode password text" "entry\src\main\ets\pages\RemoteControl.ets" "shouldPromptForPasswordText"

Add-PatternCheck "retry handles session-error" "entry\src\main\ets\pages\RemoteControl.ets" "session-error"
Add-PatternCheck "retry handles session-closed" "entry\src\main\ets\pages\RemoteControl.ets" "session-closed"
Add-PatternCheck "retry handles legacy closed event" "entry\src\main\ets\pages\RemoteControl.ets" "event.kind === 'closed'"
Add-PatternCheck "retry detects connection reset" "entry\src\main\ets\pages\RemoteControl.ets" "connection reset"
Add-PatternCheck "retry detects os error 104" "entry\src\main\ets\pages\RemoteControl.ets" "os error 104"
Add-PatternCheck "retry detects forcibly closed" "entry\src\main\ets\pages\RemoteControl.ets" "forcibly closed"
Add-PatternCheck "connected snapshot cannot clear retry before first frame" "entry\src\main\ets\pages\RemoteControl.ets" "connected-without-frame snapshot"
Add-PatternCheck "state error can show reconnect prompt without event callback" "entry\src\main\ets\pages\RemoteControl.ets" "applyBridgeState terminal error -> reconnect prompt"
Add-PatternCheck "idle state can show reconnect prompt" "entry\src\main\ets\pages\RemoteControl.ets" "applyBridgeState idle -> reconnect prompt"
Add-PatternCheck "retry path starts bridge refresh" "entry\src\main\ets\pages\RemoteControl.ets" "startBridgeRefresh\(\)"
Add-PatternCheck "retry path restarts frame refresh" "entry\src\main\ets\pages\RemoteControl.ets" "startFrameRefresh\(\)"

Add-PatternCheck "official bridge treats login as connecting" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "event.kind === 'login'"
Add-PatternCheck "official bridge treats reconnect as connecting" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "event.kind === 'reconnect'"
Add-PatternCheck "official bridge treats connection-ready as connected" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "connection-ready"
Add-PatternCheck "official bridge treats closed as idle" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "event.kind === 'session-closed' \|\| event.kind === 'closed'"
Add-PatternCheck "official bridge exposes query online" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "queryOnlines"
Add-PatternCheck "official bridge exposes LAN discover" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "discoverLanPeers"
Add-PatternCheck "official bridge exposes LAN load" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "loadLanPeers"

Add-PatternCheck "LAN discovery enables native option" "entry\src\main\ets\services\LanDiscoveryService.ets" "enable-lan-discovery"
Add-PatternCheck "LAN discovery calls native discover" "entry\src\main\ets\services\LanDiscoveryService.ets" "discoverLanPeers"
Add-PatternCheck "LAN discovery loads peers" "entry\src\main\ets\services\LanDiscoveryService.ets" "loadDiscoveredPeers"
Add-PatternCheck "LAN discovery debounces transient empty results" "entry\src\main\ets\services\LanDiscoveryService.ets" "consecutiveEmptyLoadCount"
Add-PatternCheck "LAN discovery parses peer json" "entry\src\main\ets\services\LanDiscoveryService.ets" "JSON.parse"

Add-PatternCheck "quality status event is handled" "entry\src\main\ets\pages\RemoteControl.ets" "quality-status"
Add-PatternCheck "quality details panel exists" "entry\src\main\ets\pages\RemoteControl.ets" "Quality Details"
Add-PatternCheck "raw quality panel keeps extended detail" "entry\src\main\ets\pages\RemoteControl.ets" "2400"
Add-PatternCheck "quality panel is scrollable" "entry\src\main\ets\pages\RemoteControl.ets" "scrollBar\(BarState.Auto\)"
Add-PatternCheck "quality parser handles Rust debug struct" "entry\src\main\ets\pages\RemoteControl.ets" "parseRustDebugQualityStatus"
Add-PatternCheck "quality parser handles fps map" "entry\src\main\ets\pages\RemoteControl.ets" "fpsRecord"

Add-PatternCheck "video frame pull path exists" "entry\src\main\ets\pages\RemoteControl.ets" "pullLatestVideoFrame"
Add-PatternCheck "video refresh request path exists" "entry\src\main\ets\pages\RemoteControl.ets" "refreshSessionVideo"
Add-PatternCheck "mouse input path exists" "entry\src\main\ets\pages\RemoteControl.ets" "sendMouseInput"
Add-PatternCheck "keyboard input path exists" "entry\src\main\ets\pages\RemoteControl.ets" "sendKeyboardInput"
Add-PatternCheck "clipboard send path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "sendClipboardData"
Add-PatternCheck "audio frame path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "sendAudioFrameMetadata"
Add-PatternCheck "chat path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "sendChatMessage"
Add-PatternCheck "file transfer path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "sendFileTransferRequest"
Add-PatternCheck "terminal open path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "openTerminal"
Add-PatternCheck "terminal resize path exists" "entry\src\main\ets\services\OfficialSessionTransport.ets" "resizeTerminal"
Add-PatternCheck "permission settings path exists" "entry\src\main\ets\services\PermissionService.ets" "openAppSettings"
Add-PatternCheck "incoming service toggles native core" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "setIncomingServiceEnabled"
Add-PatternCheck "incoming password syncs to core" "entry\src\main\ets\services\AppDataService.ets" "temporary-password"
Add-PatternCheck "server config codec exists" "entry\src\main\ets\services\ServerConfigCodec.ets" "ServerConfigCodec"

Add-PatternCheck "native dts declares reconnect" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "reconnectSession"
Add-PatternCheck "native dts declares LAN discovery" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "discoverLanPeers"
Add-PatternCheck "native dts declares load LAN peers" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "loadLanPeers"
Add-PatternCheck "native TS wrapper declares hasNativeModule" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "hasNativeModule"
Add-PatternCheck "native TS wrapper declares core loaded" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "isCoreLoaded"
Add-PatternCheck "native TS wrapper declares debug summary" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "getCombinedDebugSummary"

Add-PatternCheck "github build checks native core" "scripts\github_build_harmonyos.ps1" "Confirm-NativeCore"
Add-PatternCheck "github build can build hap/app/both" "scripts\github_build_harmonyos.ps1" 'ValidateSet\("hap",\s*"app",\s*"both"\)'
Add-PatternCheck "github build verifies package" "scripts\github_build_harmonyos.ps1" "Invoke-PackageVerification"
Add-PatternCheck "github build uses staged project" "scripts\github_build_harmonyos.ps1" "New-BuildStage"
Add-PatternCheck "github build syncs staged metadata" "scripts\github_build_harmonyos.ps1" "Sync-BuildStage"
Add-PatternCheck "github workflow exposes HAP and APP choice" ".github\workflows\build-harmonyos.yml" "artifact_type"
Add-PatternCheck "github workflow exposes package verify switch" ".github\workflows\build-harmonyos.yml" "skip_package_verify"
Add-PatternCheck "github workflow exposes stage switch" ".github\workflows\build-harmonyos.yml" "disable_stage"

Add-NotPatternCheck "CMake avoids unsupported time_service_ndk" "entry\src\main\cpp\CMakeLists.txt" "time_service_ndk"
Add-NotPatternCheck "native wrapper avoids fake module fallback for loaded core" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "Module:\s*FAILED"

Add-Check "latest HAP has native bridge libraries" {
  if ([string]::IsNullOrWhiteSpace($hapResolved) -or -not (Test-Path -LiteralPath $hapResolved)) {
    return New-Result "SKIP" "HAP not found"
  }
  $entries = Get-ZipEntryNames -ZipPath $hapResolved
  if ($entries -contains "libs/arm64-v8a/librustdesk_bridge.so" -and $entries -contains "libs/arm64-v8a/libc++_shared.so") {
    return New-Result "PASS" $hapResolved
  }
  return New-Result "FAIL" "native libraries missing from HAP"
}

Add-Check "latest APP exists when requested or already built" {
  if ([string]::IsNullOrWhiteSpace($appResolved) -or -not (Test-Path -LiteralPath $appResolved)) {
    return New-Result "SKIP" "APP not found yet"
  }
  $size = (Get-Item -LiteralPath $appResolved).Length
  if ($size -gt 0) {
    return New-Result "PASS" "$appResolved ($size bytes)"
  }
  return New-Result "FAIL" "APP is empty"
}

if ($Rounds -lt 1) {
  throw "Rounds must be >= 1"
}

$totalFailures = 0
$totalSkips = 0
$totalPasses = 0
$startedAt = Get-Date
for ($round = 1; $round -le $Rounds; $round += 1) {
  $roundPass = 0
  $roundFail = 0
  $roundSkip = 0
  $roundFailureDetails = New-Object System.Collections.Generic.List[string]

  foreach ($check in $checks) {
    try {
      $result = & $check.Body
      if ($null -eq $result) {
        $result = New-Result "FAIL" "check returned null"
      }
    } catch {
      $result = New-Result "FAIL" $_.Exception.Message
    }

    switch ($result.Status) {
      "PASS" { $roundPass += 1; $totalPasses += 1 }
      "SKIP" { $roundSkip += 1; $totalSkips += 1 }
      default {
        $roundFail += 1
        $totalFailures += 1
        if ($roundFailureDetails.Count -lt 8) {
          $roundFailureDetails.Add("$($check.Name): $($result.Detail)") | Out-Null
        }
      }
    }
  }

  $roundResults.Add([PSCustomObject]@{
    Round = $round
    Pass = $roundPass
    Fail = $roundFail
    Skip = $roundSkip
    Failures = @($roundFailureDetails)
  }) | Out-Null

  if ($roundFail -eq 0) {
    Write-Host ("Round {0:000}/{1}: PASS {2}, SKIP {3}" -f $round, $Rounds, $roundPass, $roundSkip) -ForegroundColor Green
  } else {
    Write-Host ("Round {0:000}/{1}: FAIL {2}, PASS {3}, SKIP {4}" -f $round, $Rounds, $roundFail, $roundPass, $roundSkip) -ForegroundColor Red
    foreach ($failure in $roundFailureDetails) {
      Write-Host "  - $failure" -ForegroundColor Red
    }
  }
}
$finishedAt = Get-Date

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("# Full Function Audit") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("- Started: $($startedAt.ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
$reportLines.Add("- Finished: $($finishedAt.ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
$reportLines.Add("- Project: $projectRoot") | Out-Null
$reportLines.Add("- Rounds: $Rounds") | Out-Null
$reportLines.Add("- Checks per round: $($checks.Count)") | Out-Null
$reportLines.Add("- Total pass: $totalPasses") | Out-Null
$reportLines.Add("- Total fail: $totalFailures") | Out-Null
$reportLines.Add("- Total skip: $totalSkips") | Out-Null
$reportLines.Add("- HAP: $(if ($hapResolved) { $hapResolved } else { 'not found' })") | Out-Null
$reportLines.Add("- APP: $(if ($appResolved) { $appResolved } else { 'not found' })") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("## Rounds") | Out-Null
foreach ($item in $roundResults) {
  $reportLines.Add("- Round $($item.Round): pass=$($item.Pass), fail=$($item.Fail), skip=$($item.Skip)") | Out-Null
  foreach ($failure in $item.Failures) {
    $reportLines.Add("  - $failure") | Out-Null
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) | Out-Null
$reportLines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Audit report: $ReportPath"

if ($totalFailures -gt 0) {
  exit 1
}
