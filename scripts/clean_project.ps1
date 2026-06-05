param(
  [switch]$IncludeIdea,
  [switch]$IncludeExternalBuild,
  [switch]$IncludeHvigorCache
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$projectName = Split-Path -Leaf $projectRoot
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "99_Temp"))
$pathsToClean = @(
  ".hvigor",
  ".hvigor_home",
  ".appanalyzer",
  ".local_sdk",
  "entry\\build",
  "entry\\.cxx",
  "native_rust_core\\target",
  "native_rust_core\\cargo-check.log"
)

if ($IncludeIdea) {
  $pathsToClean += ".idea"
}

$absolutePathsToClean = @()
if ($IncludeExternalBuild) {
  $absolutePathsToClean += @(
    (Join-Path $tempRoot ("harmonyos_build\" + $projectName)),
    (Join-Path $tempRoot ("harmonyos_stage\" + $projectName))
  )
}

if ($IncludeHvigorCache) {
  $absolutePathsToClean += (Join-Path $tempRoot "harmonyos_cache")
}

function Get-ItemSizeBytes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )

  if (-not (Test-Path -LiteralPath $LiteralPath)) {
    return 0
  }

  $item = Get-Item -LiteralPath $LiteralPath
  if (-not $item.PSIsContainer) {
    return [int64]$item.Length
  }

  $measure = Get-ChildItem -LiteralPath $LiteralPath -Recurse -Force -File -ErrorAction SilentlyContinue |
    Measure-Object -Property Length -Sum

  if ($null -eq $measure.Sum) {
    return 0
  }

  return [int64]$measure.Sum
}

function Convert-ToExtendedLengthPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )

  $fullPath = [System.IO.Path]::GetFullPath($LiteralPath)
  if ($fullPath.StartsWith("\\?\", [System.StringComparison]::Ordinal)) {
    return $fullPath
  }
  if ($fullPath.StartsWith("\\", [System.StringComparison]::Ordinal)) {
    return "\\?\UNC\" + $fullPath.Substring(2)
  }
  return "\\?\" + $fullPath
}

function Remove-PathWithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )

  $lastError = $null
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
      return $true
    }

    try {
      Get-ChildItem -LiteralPath $LiteralPath -Recurse -Force -ErrorAction SilentlyContinue |
        ForEach-Object {
          try {
            $_.Attributes = [System.IO.FileAttributes]::Normal
          } catch {}
        }

      try {
        (Get-Item -LiteralPath $LiteralPath -Force).Attributes = [System.IO.FileAttributes]::Normal
      } catch {}

      Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction Stop
      if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $true
      }
    } catch {
      $lastError = $_
    }

    Start-Sleep -Milliseconds (250 * $attempt)

    try {
      if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $true
      }

      $extendedPath = Convert-ToExtendedLengthPath -LiteralPath $LiteralPath
      if ([System.IO.Directory]::Exists($extendedPath)) {
        [System.IO.Directory]::Delete($extendedPath, $true)
      } elseif ([System.IO.File]::Exists($extendedPath)) {
        [System.IO.File]::Delete($extendedPath)
      }

      if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $true
      }
    } catch {
      $lastError = $_
    }

    Start-Sleep -Milliseconds (250 * $attempt)
  }

  if ($lastError) {
    Write-Verbose $lastError.Exception.Message
  }
  return $false
}

$cleanTargets = @()
foreach ($relativePath in $pathsToClean) {
  $absolutePath = Join-Path $projectRoot $relativePath
  if (-not (Test-Path -LiteralPath $absolutePath)) {
    continue
  }

  $cleanTargets += [PSCustomObject]@{
    RelativePath = $relativePath
    AbsolutePath = $absolutePath
    SizeBytes = Get-ItemSizeBytes -LiteralPath $absolutePath
  }
}

foreach ($absolutePath in $absolutePathsToClean) {
  $resolvedPath = [System.IO.Path]::GetFullPath($absolutePath)
  if (-not $resolvedPath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean external path outside 99_Temp: $resolvedPath"
  }
  if (-not (Test-Path -LiteralPath $resolvedPath)) {
    continue
  }
  $cleanTargets += [PSCustomObject]@{
    RelativePath = $resolvedPath
    AbsolutePath = $resolvedPath
    SizeBytes = Get-ItemSizeBytes -LiteralPath $resolvedPath
  }
}

if (-not $cleanTargets) {
  Write-Host "No generated caches or build outputs were found."
  exit 0
}

$totalBytes = ($cleanTargets | Measure-Object -Property SizeBytes -Sum).Sum

Write-Host "Cleaning generated files from $projectRoot"
$staleProjectGeneratedPaths = @(
  ".hvigor",
  ".hvigor_home",
  ".appanalyzer",
  "entry\\build",
  "entry\\.cxx"
)
foreach ($target in $cleanTargets) {
  $sizeMb = [Math]::Round(($target.SizeBytes / 1MB), 2)
  Write-Host (" - {0} ({1} MB)" -f $target.RelativePath, $sizeMb)
  if (Remove-PathWithRetry -LiteralPath $target.AbsolutePath) {
    continue
  }

  if ($staleProjectGeneratedPaths -contains $target.RelativePath) {
    Write-Warning ("Unable to remove stale project generated path '{0}'. Continuing because Hvigor build outputs are redirected to 99_Temp." -f $target.RelativePath)
    continue
  }

  $currentSizeBytes = Get-ItemSizeBytes -LiteralPath $target.AbsolutePath
  $isExternalTempTarget = $target.AbsolutePath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)
  $isEmptyDirectory = (Test-Path -LiteralPath $target.AbsolutePath -PathType Container) -and $currentSizeBytes -eq 0
  if ($isExternalTempTarget -and $isEmptyDirectory) {
    Write-Warning ("Unable to remove empty external build directory '{0}'. Continuing because the directory contains no generated files." -f $target.AbsolutePath)
    continue
  }

  throw "Unable to remove generated path: $($target.AbsolutePath)"
}

$freedMb = [Math]::Round(($totalBytes / 1MB), 2)
Write-Host ("Cleanup complete. Reclaimed about {0} MB." -f $freedMb)
