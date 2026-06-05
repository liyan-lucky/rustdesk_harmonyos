param(
  [Parameter(Mandatory = $true)]
  [string]$StageRoot
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$stageRootFull = [System.IO.Path]::GetFullPath($StageRoot)
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "99_Temp"))

if (-not $stageRootFull.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to sync from outside 99_Temp: $stageRootFull"
}

$filesToSync = @(
  "AppScope\app.json5",
  "entry\src\main\ets\common\BuildInfo.ets"
)

foreach ($relativePath in $filesToSync) {
  $sourcePath = Join-Path $stageRootFull $relativePath
  $targetPath = Join-Path $projectRoot $relativePath
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Build sync source file not found: $sourcePath"
  }
  Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

Write-Host "Synced build version files from $stageRootFull"
