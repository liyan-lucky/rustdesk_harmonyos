param(
  [int]$Keep = 2
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\99_Temp"))
$backupRoot = Join-Path $tempRoot "rustdesk_harmonyos_backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stageRoot = Join-Path $env:TEMP "rustdesk_harmonyos_backup_$timestamp"
$zipPath = Join-Path $backupRoot "rustdesk_harmonyos_$timestamp.zip"

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
if (Test-Path -LiteralPath $stageRoot) {
  Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

$excludeDirs = @(
  (Join-Path $projectRoot ".hvigor"),
  (Join-Path $projectRoot ".hvigor_home"),
  (Join-Path $projectRoot ".appanalyzer"),
  (Join-Path $projectRoot "oh_modules"),
  (Join-Path $projectRoot "entry\build"),
  (Join-Path $projectRoot "entry\.cxx"),
  (Join-Path $projectRoot "native_rust_core\target")
)

try {
  $robocopyArgs = @($projectRoot, $stageRoot, "/E", "/XD") + $excludeDirs + @("/XF", "*.log")
  & robocopy @robocopyArgs | Out-Host
  $robocopyExit = $LASTEXITCODE
  if ($robocopyExit -gt 7) {
    throw "robocopy failed with exit code $robocopyExit"
  }

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal
} finally {
  if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
  }
}

Get-ChildItem -LiteralPath $backupRoot -Filter "rustdesk_harmonyos_*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -Skip $Keep |
  Remove-Item -Force

Write-Host "Backup written to $zipPath"
