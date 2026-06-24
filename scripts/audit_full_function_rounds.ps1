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
  $test = ${function:Test-FileExists}
  Add-Check $Name ({ & $test -RelativePath $RelativePath }.GetNewClosure())
}

function Add-PatternCheck {
  param([string]$Name, [string]$RelativePath, [string]$Pattern)
  $test = ${function:Test-Pattern}
  Add-Check $Name ({ & $test -RelativePath $RelativePath -Pattern $Pattern }.GetNewClosure())
}

function Add-NotPatternCheck {
  param([string]$Name, [string]$RelativePath, [string]$Pattern)
  $test = ${function:Test-NotPattern}
  Add-Check $Name ({ & $test -RelativePath $RelativePath -Pattern $Pattern }.GetNewClosure())
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
Add-FileCheck "github Linux workflow" ".github\workflows\build-harmonyos-linux.yml"
Add-Check "online workflows reject hidden stale core URL overrides" {
  foreach ($workflow in @(".github\workflows\build-harmonyos.yml", ".github\workflows\build-harmonyos-linux.yml")) {
    $text = Read-RepoText $workflow
    if ($null -eq $text -or $text -match "(secrets|vars)\.RUSTDESK_CORE(_X86_64)?_URL") {
      return New-Result "FAIL" "$workflow still allows a hidden stale core URL override"
    }
    if ($text -notmatch "inputs\.core_url" -or $text -notmatch "inputs\.core_x86_64_url" -or
        $text -notmatch "RUSTDESK_CORE_SHA256" -or $text -notmatch "RUSTDESK_CORE_X86_64_SHA256") {
      return New-Result "FAIL" "$workflow lacks explicit dual-arch URL/SHA256 inputs"
    }
  }
  return New-Result "PASS" "both workflows use explicit dual-arch URL/SHA256 inputs"
}
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

Add-Check "x86_64 native core archive exists and is plausible" {
  $path = Get-RepoPath "entry\src\main\libs\x86_64\librustdesk_core.a"
  if (-not (Test-Path -LiteralPath $path)) {
    return New-Result "FAIL" "x86_64 native core archive missing"
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

Add-Check "CoreBuildInfo x86_64 size and hash match native core" {
  $corePath = Get-RepoPath "entry\src\main\libs\x86_64\librustdesk_core.a"
  $infoText = Read-RepoText "entry\src\main\ets\common\CoreBuildInfo.ets"
  if (-not (Test-Path -LiteralPath $corePath) -or $null -eq $infoText) {
    return New-Result "FAIL" "x86_64 core file or CoreBuildInfo missing"
  }
  $size = (Get-Item -LiteralPath $corePath).Length
  $sha = (Get-FileHash -LiteralPath $corePath -Algorithm SHA256).Hash.ToUpperInvariant()
  $declaredSize = Get-CoreInfoValue -Text $infoText -Name "X86_64_FILE_SIZE"
  $declaredSha = (Get-CoreInfoValue -Text $infoText -Name "X86_64_HASH_SHA256").ToUpperInvariant()
  if ($declaredSize -ne "$size") {
    return New-Result "FAIL" "X86_64_FILE_SIZE $declaredSize != $size"
  }
  if ($declaredSha -ne $sha) {
    return New-Result "FAIL" "X86_64_HASH_SHA256 mismatch"
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
Add-NotPatternCheck "remote route does not carry obsolete password dialog flags" "entry\src\main\ets\pages\Index.ets" "showPasswordDialog:\s*shouldShowPasswordDialog|passwordPromptProactive:\s*shouldUseProactivePasswordDialog"
Add-PatternCheck "password confirmation submits to active handshake" "entry\src\main\ets\pages\Index.ets" "submitSessionPassword\(password,\s*this\.rememberPassword\)"
Add-NotPatternCheck "proactive password confirmation does not close active handshake" "entry\src\main\ets\pages\Index.ets" "pendingPasswordDialogProactive\s*\)\s*\{[\s\S]{0,320}resetPendingConnectionState"
Add-PatternCheck "password dialog avoids software keyboard" "entry\src\main\ets\pages\Index.ets" "translate\(\{\s*y:\s*this\.avoidKeyboardHeight"
Add-NotPatternCheck "msgbox success cannot promote session to connected" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "msgType\s*===\s*'success'[\s\S]{0,160}sessionStage\s*=\s*'connected'"
Add-PatternCheck "password dialog remains on index while connection monitor waits" "entry\src\main\ets\pages\Index.ets" "showConnectPasswordDialog\(targetId,\s*true\)[\s\S]{0,180}initiateBackgroundConnection\(this\.pendingTransportTarget,\s*targetId\)"
Add-PatternCheck "password prompt helper covers unicode password text" "entry\src\main\ets\pages\RemoteControl.ets" "shouldPromptForPasswordText"
Add-NotPatternCheck "ID suggestions do not overlay input commands" "entry\src\main\ets\pages\Index.ets" "\.overlay\(this\.buildIdSuggestions"
Add-PatternCheck "ID suggestions use a floating positioned popup" "entry\src\main\ets\pages\Index.ets" "private\s+buildIdSuggestions\(\)[\s\S]{0,2600}\.width\('calc\(100% - 116vp\)'\)[\s\S]{0,500}\.position\("
Add-Check "ID suggestion and command hit targets are explicit" {
  $text = Read-RepoText "entry\src\main\ets\pages\Index.ets"
  if ($null -eq $text) {
    return New-Result "FAIL" "Index missing"
  }
  $suggestionBlock = [regex]::Match(
    $text,
    "private\s+buildIdSuggestions\(\)[\s\S]*?private\s+buildOfficialLoginEntry"
  )
  $connectPanelBlock = [regex]::Match(
    $text,
    "private\s+buildOfficialConnectPanel\(\)[\s\S]*?private\s+buildConnectSearchAnchor"
  )
  if (-not $suggestionBlock.Success -or
      $suggestionBlock.Value -notmatch "\.position\(" -or
      $suggestionBlock.Value -notmatch "\.zIndex\(35\)" -or
      $suggestionBlock.Value -notmatch "\.width\('calc\(100% - 116vp\)'\)" -or
      $suggestionBlock.Value -notmatch "\.hitTestBehavior\(HitTestMode\.Block\)") {
    return New-Result "FAIL" "suggestion popup is not a tightly bounded positioned hit target"
  }
  if (-not $connectPanelBlock.Success -or
      $connectPanelBlock.Value -notmatch "\.zIndex\(40\)" -or
      $connectPanelBlock.Value -notmatch "this\.buildIdSuggestions\(\)") {
    return New-Result "FAIL" "clear/connect command row is not above the suggestion popup"
  }
  return New-Result "PASS" "positioned popup and command row use explicit bounded hit targets"
}

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
Add-PatternCheck "official bridge deduplicates repeated terminal events" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "lastTerminalEventSignature"
Add-NotPatternCheck "official bridge does not feed native terminal events back into core" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "NativeRustDeskBridge\.markSession(Error|Connected)"
Add-PatternCheck "official bridge preserves logical ID for direct transport" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "sessionTransportPeerId[\s\S]{0,500}sessionDisplayPeerId"
Add-PatternCheck "official bridge exposes query online" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "queryOnlines"
Add-PatternCheck "official bridge exposes LAN discover" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "discoverLanPeers"
Add-PatternCheck "official bridge exposes LAN load" "entry\src\main\ets\services\OfficialRustDeskBridge.ets" "loadLanPeers"

Add-PatternCheck "LAN discovery enables native option" "entry\src\main\ets\services\LanDiscoveryService.ets" "enable-lan-discovery"
Add-PatternCheck "LAN discovery calls native discover" "entry\src\main\ets\services\LanDiscoveryService.ets" "discoverLanPeers"
Add-PatternCheck "LAN discovery loads peers" "entry\src\main\ets\services\LanDiscoveryService.ets" "loadDiscoveredPeers"
Add-PatternCheck "LAN discovery debounces transient empty results" "entry\src\main\ets\services\LanDiscoveryService.ets" "consecutiveEmptyLoadCount"
Add-PatternCheck "LAN discovery parses peer json" "entry\src\main\ets\services\LanDiscoveryService.ets" "JSON.parse"

Add-PatternCheck "quality status event is handled" "entry\src\main\ets\pages\RemoteControl.ets" "quality-status"
Add-NotPatternCheck "quality panel omits removed dynamic details section" "entry\src\main\ets\pages\RemoteControl.ets" "this\.lt\('Quality Details'\)|ForEach\(this\.qualityMetricItems"
Add-PatternCheck "quality cache keeps extended parser range" "entry\src\main\ets\pages\RemoteControl.ets" "2400"
Add-PatternCheck "quality panel is scrollable" "entry\src\main\ets\pages\RemoteControl.ets" "scrollable\(ScrollDirection\.Vertical\)"
Add-PatternCheck "quality panel refreshes cached values while visible" "entry\src\main\ets\pages\RemoteControl.ets" "startConnectionInfoRefresh[\s\S]{0,900}qualityRefreshTick\s*\+=\s*1"
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
Add-PatternCheck "core page probes packaged x86 bridge" "entry\src\main\ets\pages\Index.ets" "bundle/libs/x86_64/librustdesk_bridge\.so"
Add-PatternCheck "core runtime summary displays native event log" "entry\src\main\ets\pages\Index.ets" "getRuntimeLogSummary"
Add-PatternCheck "LAN discovered ID can use direct address" "entry\src\main\ets\pages\Index.ets" "getDirectAddress\(peerId\)"
Add-PatternCheck "numeric ID editor restores grouped display formatting" "entry\src\main\ets\pages\Index.ets" "formattedValue\s*=\s*numericTarget\s*\?\s*this\.formatId\(raw\)\s*:\s*raw"
Add-PatternCheck "formatted ID editor restores the mapped caret" "entry\src\main\ets\pages\Index.ets" "onTextSelectionChange[\s\S]{0,900}mapConnectionTargetCaret|mapConnectionTargetCaret[\s\S]{0,2800}onTextSelectionChange"
Add-PatternCheck "formatted ID caret restore survives controlled rerender" "entry\src\main\ets\pages\Index.ets" "deviceIdCaretRestoreVersion[\s\S]{0,2200}\[0,\s*40,\s*120\][\s\S]{0,400}caretPosition\(position\)"
Add-PatternCheck "formatted ID caret uses stable text diff mapping" "entry\src\main\ets\pages\Index.ets" "resolveRawCaretAfterEdit[\s\S]{0,1500}changedEnd[\s\S]{0,220}countConnectionTargetCharactersBeforeCaret"
Add-PatternCheck "ID suggestions include direct IP cards" "entry\src\main\ets\pages\Index.ets" "getIdSuggestions\(\)[\s\S]{0,1200}toLowerCase\(\)\.includes\(query\)"
Add-NotPatternCheck "ID suggestions are not restricted to numeric targets" "entry\src\main\ets\pages\Index.ets" "buildIdSuggestions\(\)[\s\S]{0,180}isNumericConnectionTarget"
Add-PatternCheck "ID suggestion selection rejects stale partial onChange" "entry\src\main\ets\pages\Index.ets" "pendingDeviceIdSelection[\s\S]{0,1400}raw\s*!==\s*this\.pendingDeviceIdSelection"
Add-PatternCheck "ID suggestion click fills the complete selected ID" "entry\src\main\ets\pages\Index.ets" "buildIdSuggestions[\s\S]{0,1800}selectDeviceIdInputTarget\(id\)"
Add-PatternCheck "ID suggestion captures touch before input blur" "entry\src\main\ets\pages\Index.ets" "id-suggestion-[\s\S]{0,320}TouchType\.Down[\s\S]{0,180}selectDeviceIdInputTarget"
Add-PatternCheck "ID suggestion stays closed after complete programmatic fill" "entry\src\main\ets\pages\Index.ets" "raw\s*===\s*this\.pendingDeviceIdSelection[\s\S]{0,320}showIdSuggestions\s*=\s*false;[\s\S]{0,180}return;"
Add-PatternCheck "incoming password syncs to core" "entry\src\main\ets\services\AppDataService.ets" "temporary-password"
Add-PatternCheck "temporary password starts empty in source" "entry\src\main\ets\services\AppDataService.ets" "private\s+password:\s*string\s*=\s*''"
Add-NotPatternCheck "temporary password is not persisted in app preferences" "entry\src\main\ets\services\AppDataService.ets" "PreferenceStore\.(getPassword|setPassword)"
Add-PatternCheck "legacy persisted temporary password is deleted" "entry\src\main\ets\services\PreferenceStore.ts" "clearLegacyTemporaryPassword[\s\S]{0,220}deleteKey"
Add-PatternCheck "share running status requires incoming service and active capture" "entry\src\main\ets\pages\Index.ets" "isShareServiceRunning\(\)[\s\S]{0,240}incomingReady[\s\S]{0,160}isNativeScreenCaptureRunning"
Add-PatternCheck "share service always starts native capture when inactive" "entry\src\main\ets\pages\Index.ets" "performToggleIncomingService[\s\S]{0,3000}if\s*\(!this\.isNativeScreenCaptureRunning\(\)\)\s*\{[\s\S]{0,180}startCapture\(\)"
Add-PatternCheck "official scam warning gate and countdown exist" "entry\src\main\ets\pages\Index.ets" "show-scam-warning[\s\S]{0,500}shareWarningCountdown\s*=\s*12"
Add-PatternCheck "Harmony input control remains visible as unsupported" "entry\src\main\ets\pages\Index.ets" "buildUnsupportedCapabilityRow\([\s\S]{0,180}Input Control[\s\S]{0,180}HarmonyOS currently does not support this feature"
Add-PatternCheck "Harmony input control keeps original mouse icon" "entry\src\main\ets\pages\Index.ets" "buildUnsupportedCapabilityRow\([\s\S]{0,180}Input Control[\s\S]{0,240}opt_mouse\.svg"
Add-PatternCheck "relay selected state uses square checkbox asset" "entry\src\main\ets\pages\Index.ets" "buildForceRelayConnectionRow[\s\S]{0,7000}checkbox-(checked|unchecked)\.svg"
Add-PatternCheck "ID card menu uses compact fixed width" "entry\src\main\ets\pages\Index.ets" "buildRecentSessionMenu[\s\S]{0,7000}\.width\(210\)"
Add-PatternCheck "administrator terminal menu uses compact label" "entry\src\main\ets\pages\Index.ets" "buildPeerMenuActionRow\(this\.lt\('Terminal \(Admin beta\)'\)[\s\S]{0,140}closePeerMenuAsDeveloping"
Add-NotPatternCheck "ID card menu hides persistent development labels" "entry\src\main\ets\pages\Index.ets" "buildPeerMenuActionRow[\s\S]{0,700}Text\(this\.lt\('In development'\)\)"
Add-PatternCheck "ID card unavailable actions show development toast" "entry\src\main\ets\pages\Index.ets" "closePeerMenuAsDeveloping[\s\S]{0,180}showToast[\s\S]{0,100}In development"
Add-PatternCheck "disabled settings actions show development toast" "entry\src\main\ets\pages\Index.ets" "buildSettingsToggleSettingRow[\s\S]{0,1800}if\s*\(disabled\)[\s\S]{0,180}In development"
Add-PatternCheck "unsupported capability actions show development toast" "entry\src\main\ets\pages\Index.ets" "buildUnsupportedCapabilityRow[\s\S]{0,1200}showToast[\s\S]{0,120}In development"
Add-PatternCheck "settings display section title uses dvr icon" "entry\src\main\ets\pages\Index.ets" "buildSettingsDisplaySection[\s\S]{0,180}buildSettingsSectionLabel\(this\.lt\('Display Settings'\), 'dvr\.svg'\)"
Add-PatternCheck "settings display entry keeps display icon" "entry\src\main\ets\pages\Index.ets" "buildSettingsDisplaySection[\s\S]{0,500}display\.svg"
Add-PatternCheck "share card keeps one trailing status badge" "entry\src\main\ets\pages\Index.ets" "buildShareServiceCard[\s\S]{0,1000}StatusBadge\(this\.resolveShareStatusBadgeText"
Add-NotPatternCheck "share card omits duplicate service title and readiness error" "entry\src\main\ets\pages\Index.ets" "buildShareServiceCard[\s\S]{0,2400}(Text\(this\.lt\('Screen sharing service'\)\)|Core video source not ready)"
Add-PatternCheck "file transfer follows settings scroll and themed borders" "entry\src\main\ets\pages\FileTransfer.ets" "avoidStatusBarHeight[\s\S]{0,15000}\.border\(\{\s*width:\s*1,\s*color:\s*this\.theme_BORDER_SUBTLE"
Add-PatternCheck "terminal follows settings scroll and themed borders" "entry\src\main\ets\pages\Terminal.ets" "avoidStatusBarHeight[\s\S]{0,15000}theme_BORDER_SUBTLE"
Add-PatternCheck "server config codec exists" "entry\src\main\ets\services\ServerConfigCodec.ets" "ServerConfigCodec"

Add-PatternCheck "native dts declares reconnect" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "reconnectSession"
Add-PatternCheck "best-speed quality uses official low value" "entry\src\main\ets\pages\RemoteControl.ets" "2:\s*'low'"
Add-PatternCheck "all official codecs are visible on Harmony" "entry\src\main\ets\pages\RemoteControl.ets" "\{ value: 'VP8' \}[\s\S]{0,500}\{ value: 'VP9' \}[\s\S]{0,500}\{ value: 'AV1' \}[\s\S]{0,500}\{ value: 'H264' \}[\s\S]{0,500}\{ value: 'H265' \}"
Add-PatternCheck "native AV1 H264 H265 decoder is compiled" "entry\src\main\cpp\CMakeLists.txt" "ohos_video_decoder\.cpp"
Add-PatternCheck "native decoder uses Harmony codec API" "entry\src\main\cpp\ohos_video_decoder.cpp" "OH_VideoDecoder_CreateByMime"
Add-PatternCheck "keyboard menu checks map support" "entry\src\main\ets\pages\RemoteControl.ets" "sessionIsKeyboardModeSupported\('map'\)"
Add-NotPatternCheck "unsupported local audio upload is hidden" "entry\src\main\ets\pages\RemoteControl.ets" "Send Local Audio|toggleLocalAudioCapture"
Add-PatternCheck "terminal connection errors remain visible" "entry\src\main\ets\pages\Index.ets" "resetConnectionUiAfterTerminalEvent\(finalError\)"
Add-NotPatternCheck "remote menu unavailable actions use development feedback" "entry\src\main\ets\pages\RemoteControl.ets" "this\.lt\('(Command|Codec) unavailable'\)"
Add-PatternCheck "reconnect dialog uses compact relay button" "entry\src\main\ets\pages\RemoteControl.ets" "buildReconnectDialog[\s\S]{0,1600}Button\(this\.lt\('Relay'\)\)[\s\S]{0,160}\.height\(36\)"
Add-PatternCheck "block input follows core state" "entry\src\main\ets\pages\RemoteControl.ets" "block-input-state"
Add-PatternCheck "terminal persistence uses official key" "entry\src\main\ets\pages\Index.ets" "terminal-persistent"
Add-NotPatternCheck "unsupported Harmony defaults are hidden" "entry\src\main\ets\pages\Index.ets" "applySessionAndLocalToggleOption\('(follow-remote-cursor|follow-remote-window|true-color-444|keep-terminal-on-disconnect)'"
Add-PatternCheck "clipboard toggle manages monitor lifecycle" "entry\src\main\ets\pages\RemoteControl.ets" "toggleClipboardSync[\s\S]{0,700}stopMonitoring\(\)[\s\S]{0,250}startMonitoring\(\)"
Add-PatternCheck "native dts declares LAN discovery" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "discoverLanPeers"
Add-PatternCheck "native dts declares load LAN peers" "entry\src\main\ets\services\librustdesk_bridge.d.ts" "loadLanPeers"
Add-PatternCheck "native TS wrapper declares hasNativeModule" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "hasNativeModule"
Add-PatternCheck "native TS wrapper declares core loaded" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "isCoreLoaded"
Add-PatternCheck "native TS wrapper declares debug summary" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "getCombinedDebugSummary"

Add-PatternCheck "github build checks native core" "scripts\github_build_harmonyos.ps1" "Confirm-NativeCore"
Add-PatternCheck "github build script is HAP-only" "scripts\github_build_harmonyos.ps1" 'ValidateSet\("hap"\)'
Add-PatternCheck "github build verifies package" "scripts\github_build_harmonyos.ps1" "Invoke-PackageVerification"
Add-PatternCheck "github build uses staged project" "scripts\github_build_harmonyos.ps1" "New-BuildStage"
Add-PatternCheck "github build syncs staged metadata" "scripts\github_build_harmonyos.ps1" "Sync-BuildStage"
Add-PatternCheck "github workflow builds HAP only" ".github\workflows\build-harmonyos.yml" 'ARTIFACT_TYPE:\s*"hap"'
Add-PatternCheck "github workflow exposes package verify switch" ".github\workflows\build-harmonyos.yml" "skip_package_verify"
Add-NotPatternCheck "github workflow avoids APP and extra release assets" ".github\workflows\build-harmonyos.yml" "\.app\.zip|manifest\.json|SHA256SUMS\.txt"

Add-NotPatternCheck "CMake avoids unsupported time_service_ndk" "entry\src\main\cpp\CMakeLists.txt" "time_service_ndk"
Add-NotPatternCheck "native wrapper avoids fake module fallback for loaded core" "entry\src\main\ets\services\NativeRustDeskBridge.ts" "Module:\s*FAILED"

Add-Check "latest HAP has native bridge libraries" {
  if ([string]::IsNullOrWhiteSpace($hapResolved) -or -not (Test-Path -LiteralPath $hapResolved)) {
    return New-Result "SKIP" "HAP not found"
  }
  $entries = Get-ZipEntryNames -ZipPath $hapResolved
  if ($entries -contains "libs/arm64-v8a/librustdesk_bridge.so" -and
      $entries -contains "libs/arm64-v8a/libc++_shared.so" -and
      $entries -contains "libs/x86_64/librustdesk_bridge.so" -and
      $entries -contains "libs/x86_64/libc++_shared.so") {
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
