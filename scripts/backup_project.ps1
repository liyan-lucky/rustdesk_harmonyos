param(
  [int]$Keep = 2
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "99_Temp"))
$backupRoot = Join-Path $tempRoot "rustdesk_harmonyos_backups"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$stageRoot = Join-Path $env:TEMP "rustdesk_harmonyos_backup_$timestamp"
$zipPath = Join-Path $backupRoot "rustdesk_harmonyos_$timestamp.zip"

New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

function Remove-DirectorySafe {
  param([Parameter(Mandatory = $true)][string]$Path)

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $tempPath = [System.IO.Path]::GetFullPath($env:TEMP)
  if (-not $fullPath.StartsWith($tempPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove path outside TEMP: $fullPath"
  }

  if (-not (Test-Path -LiteralPath $fullPath)) {
    return
  }

  try {
    Get-ChildItem -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
      ForEach-Object { $_.Attributes = [System.IO.FileAttributes]::Normal }
  } catch {}

  $longPath = "\\?\$fullPath"
  [System.IO.Directory]::Delete($longPath, $true)
}

if (Test-Path -LiteralPath $stageRoot) {
  Remove-DirectorySafe -Path $stageRoot
}

$excludeDirs = @(
  (Join-Path $projectRoot ".git"),
  (Join-Path $projectRoot ".codeartsdoer"),
  (Join-Path $projectRoot ".hvigor"),
  (Join-Path $projectRoot ".hvigor_home"),
  (Join-Path $projectRoot ".idea"),
  (Join-Path $projectRoot ".appanalyzer"),
  (Join-Path $projectRoot ".vscode"),
  (Join-Path $projectRoot "13_librustdesk_core"),
  (Join-Path $projectRoot "rustdesk_harmonyos"),
  (Join-Path $projectRoot "oh_modules"),
  (Join-Path $projectRoot "entry\oh_modules"),
  (Join-Path $projectRoot "entry\build"),
  (Join-Path $projectRoot "entry\.cxx"),
  (Join-Path $projectRoot "native_rust_core\target")
)

try {
  $robocopyArgs = @($projectRoot, $stageRoot, "/E", "/XJ", "/R:2", "/W:1", "/XD") + $excludeDirs + @("/XF", "*.log", "*.tmp", "*.bak", "*.hap", "*.a", "*.so", "local.properties", "check_i18n.py", "check_result.txt")
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
    Remove-DirectorySafe -Path $stageRoot
  }
}

Get-ChildItem -LiteralPath $backupRoot -Filter "rustdesk_harmonyos_*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -Skip $Keep |
  Remove-Item -Force

Write-Host "Backup written to $zipPath"
