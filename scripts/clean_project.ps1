param(
  [switch]$IncludeIdea,
  [switch]$IncludeExternalBuild
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp"))
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
    (Join-Path $tempRoot "harmonyos_build\rustdesk_harmonyos"),
    (Join-Path $tempRoot "harmonyos_cache")
  )
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

$cleanTargets = foreach ($relativePath in $pathsToClean) {
  $absolutePath = Join-Path $projectRoot $relativePath
  if (-not (Test-Path -LiteralPath $absolutePath)) {
    continue
  }

  [PSCustomObject]@{
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
  [PSCustomObject]@{
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
foreach ($target in $cleanTargets) {
  $sizeMb = [Math]::Round(($target.SizeBytes / 1MB), 2)
  Write-Host (" - {0} ({1} MB)" -f $target.RelativePath, $sizeMb)
  Remove-Item -LiteralPath $target.AbsolutePath -Recurse -Force
}

$freedMb = [Math]::Round(($totalBytes / 1MB), 2)
Write-Host ("Cleanup complete. Reclaimed about {0} MB." -f $freedMb)
