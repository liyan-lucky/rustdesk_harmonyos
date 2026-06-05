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
  throw "Refusing to stage outside 99_Temp: $stageRootFull"
}

if (Test-Path -LiteralPath $stageRootFull) {
  Remove-Item -LiteralPath $stageRootFull -Recurse -Force
}

$excludeDirs = @(
  (Join-Path $projectRoot ".git"),
  (Join-Path $projectRoot ".codeartsdoer"),
  (Join-Path $projectRoot ".hvigor"),
  (Join-Path $projectRoot ".hvigor_home"),
  (Join-Path $projectRoot ".idea"),
  (Join-Path $projectRoot ".vscode"),
  (Join-Path $projectRoot ".appanalyzer"),
  (Join-Path $projectRoot ".local_sdk"),
  (Join-Path $projectRoot "rustdesk_harmonyos"),
  (Join-Path $projectRoot "node_modules"),
  (Join-Path $projectRoot "entry\build"),
  (Join-Path $projectRoot "entry\.cxx"),
  (Join-Path $projectRoot "native_rust_core\target")
)

$excludeFiles = @(
  "*.hap",
  "*.log",
  "*.tmp",
  "*.bak",
  "check_i18n.py",
  "check_result.txt"
)

New-Item -ItemType Directory -Force -Path $stageRootFull | Out-Null
$robocopyArgs = @($projectRoot, $stageRootFull, "/E", "/XD") + $excludeDirs + @("/XF") + $excludeFiles
& robocopy @robocopyArgs | Out-Host
$robocopyExit = $LASTEXITCODE
if ($robocopyExit -gt 7) {
  throw "robocopy failed with exit code $robocopyExit"
}

$buildProfilePath = Join-Path $stageRootFull "build-profile.json5"
if (Test-Path -LiteralPath $buildProfilePath) {
  $signingRoot = (Join-Path $tempRoot "rustdesk_harmonyos_signing").Replace("\", "/")
  $buildProfile = Get-Content -LiteralPath $buildProfilePath -Raw
  $buildProfile = $buildProfile.Replace("../99_Temp/rustdesk_harmonyos_signing/", "$signingRoot/")
  $buildProfile = $buildProfile.Replace("..\\99_Temp\\rustdesk_harmonyos_signing\\", "$signingRoot/")
  Set-Content -LiteralPath $buildProfilePath -Value $buildProfile -Encoding UTF8 -NoNewline
}

Write-Host "Staged project for build at $stageRootFull"
