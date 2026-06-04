param(
  [string[]]$HvigorTasks = @("assembleHap"),
  [switch]$SkipHvigor,
  [switch]$AllowUnsignedOnSignFailure,
  [switch]$SkipSigningProfileCheck,
  [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$buildRoot = if ($env:RUSTDESK_HARMONY_BUILD_DIR) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_BUILD_DIR)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp\rustdesk_harmonyos_build"))
}
$stagingDir = Join-Path $buildRoot "windows_hap"
$sourceOutputDir = Join-Path $projectRoot "entry\build\default\outputs\default"
$runHvigorScript = Join-Path $scriptDir "run_hvigor_with_sdk_patch.js"
$checkSigningScript = Join-Path $scriptDir "check_harmony_signing_profile.ps1"
$cleanScript = Join-Path $scriptDir "clean_project.ps1"

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

function Resolve-NodeExecutable {
  $properties = Read-LocalProperties -Path (Join-Path $projectRoot "local.properties")
  $npmDir = $properties["npm.dir"]

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

function Copy-ArtifactIfPresent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [Parameter(Mandatory = $true)]
    [string]$DestinationPath,
    [switch]$Required
  )

  if (-not (Test-Path -LiteralPath $SourcePath)) {
    if ($Required) {
      throw "Required build artifact was not found: $SourcePath"
    }
    return $false
  }

  Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
  return $true
}

function Get-ShortExceptionMessage {
  param(
    [Parameter(Mandatory = $true)]
    [System.Exception]$Exception
  )

  $messages = New-Object System.Collections.Generic.List[string]
  $current = $Exception
  while ($null -ne $current) {
    if (-not [string]::IsNullOrWhiteSpace($current.Message)) {
      $messages.Add($current.Message.Trim()) | Out-Null
    }
    $current = $current.InnerException
  }

  return ($messages | Select-Object -Unique) -join " | "
}

$hvigorFailed = $false
$hvigorFailureMessage = $null

if (-not $SkipHvigor) {
  if (-not (Test-Path -LiteralPath $runHvigorScript)) {
    throw "hvigor wrapper script was not found: $runHvigorScript"
  }
  if (-not $SkipSigningProfileCheck -and -not (Test-Path -LiteralPath $checkSigningScript)) {
    throw "Signing profile preflight script was not found: $checkSigningScript"
  }

  if (-not $SkipSigningProfileCheck) {
    try {
      & $checkSigningScript -ProductName "default"
      if (-not $?) {
        throw "Signing profile preflight failed."
      }
    } catch {
      $preflightFailureMessage = Get-ShortExceptionMessage -Exception $_.Exception

      if (-not $AllowUnsignedOnSignFailure) {
        throw
      }

      Write-Warning "Signing profile preflight failed: $preflightFailureMessage"
      Write-Warning "AllowUnsignedOnSignFailure is enabled, so the script will still run hvigor to stage any unsigned artifacts that were already produced."
    }
  }

  $nodeExe = Resolve-NodeExecutable
  Write-Host "Using node: $nodeExe"
  Write-Host "Running hvigor tasks: $($HvigorTasks -join ', ')"

  try {
    Push-Location $projectRoot
    try {
      & $nodeExe $runHvigorScript @HvigorTasks
      if ($LASTEXITCODE -ne 0) {
        throw "hvigor build failed with exit code $LASTEXITCODE."
      }
    } finally {
      Pop-Location
    }
  } catch {
    $hvigorFailed = $true
    $hvigorFailureMessage = Get-ShortExceptionMessage -Exception $_.Exception

    if (-not $AllowUnsignedOnSignFailure) {
      throw
    }

    Write-Warning "hvigor did not complete successfully: $hvigorFailureMessage"
    Write-Warning "AllowUnsignedOnSignFailure is enabled, so the script will attempt to stage any unsigned HAP artifacts that were already produced."
  }
}

New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$copiedArtifacts = New-Object System.Collections.Generic.List[string]
$stagedSignedHap = $false
$stagedUnsignedHap = $false

if (Copy-ArtifactIfPresent -SourcePath (Join-Path $sourceOutputDir "entry-default-signed.hap") -DestinationPath (Join-Path $stagingDir "entry-default-signed.hap") -Required:(-not $AllowUnsignedOnSignFailure)) {
  $stagedSignedHap = $true
  $copiedArtifacts.Add((Join-Path $stagingDir "entry-default-signed.hap")) | Out-Null
}
if (Copy-ArtifactIfPresent -SourcePath (Join-Path $sourceOutputDir "entry-default-unsigned.hap") -DestinationPath (Join-Path $stagingDir "entry-default-unsigned.hap")) {
  $stagedUnsignedHap = $true
  $copiedArtifacts.Add((Join-Path $stagingDir "entry-default-unsigned.hap")) | Out-Null
}
if (Copy-ArtifactIfPresent -SourcePath (Join-Path $sourceOutputDir "pack.info") -DestinationPath (Join-Path $stagingDir "pack.info")) {
  $copiedArtifacts.Add((Join-Path $stagingDir "pack.info")) | Out-Null
}

Write-Host "Staged HarmonyOS artifacts:"
foreach ($artifact in $copiedArtifacts) {
  Write-Host " - $artifact"
}

if ($hvigorFailed -and $AllowUnsignedOnSignFailure) {
  if (-not $stagedUnsignedHap) {
    throw "hvigor failed and no unsigned HAP artifact was available to stage. Original failure: $hvigorFailureMessage"
  }

  if (-not $stagedSignedHap) {
    Write-Warning "Only the unsigned HAP is available because signing did not complete."
  }
}

if (-not $SkipCleanup) {
  if (-not (Test-Path -LiteralPath $cleanScript)) {
    throw "Cleanup script was not found: $cleanScript"
  }

  $global:LASTEXITCODE = 0
  & $cleanScript
  if (-not $?) {
    throw "Project cleanup failed with exit code $LASTEXITCODE."
  }
}

if ($stagedSignedHap) {
  Write-Host "Windows-ready signed HAP is now staged under $stagingDir"
} elseif ($stagedUnsignedHap) {
  Write-Warning "Unsigned HAP artifacts are staged under $stagingDir. A valid HarmonyOS signing profile is still required to produce entry-default-signed.hap."
} else {
  Write-Host "No HAP artifacts were staged."
}
