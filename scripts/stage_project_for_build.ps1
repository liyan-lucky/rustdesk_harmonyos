param(
  [Parameter(Mandatory = $true)]
  [string]$StageRoot
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$stageRootFull = [System.IO.Path]::GetFullPath($StageRoot)
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
$tempRoot = if ($env:RUSTDESK_HARMONY_TEMP_ROOT) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_TEMP_ROOT)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "99_Temp"))
}

if (-not $stageRootFull.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to stage outside 99_Temp: $stageRootFull"
}

function ConvertTo-LongPath([string]$Path) {
  if ($Path.StartsWith("\\?\")) {
    return $Path
  }
  if ($Path.StartsWith("\\")) {
    return "\\?\UNC\" + $Path.Substring(2)
  }
  return "\\?\" + $Path
}

function Remove-StageTree([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  try {
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
  } catch {
    $longPath = ConvertTo-LongPath $Path
    Get-ChildItem -LiteralPath $longPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
      } catch {
      }
    }
    try {
      (Get-Item -LiteralPath $longPath -Force).Attributes =
        (Get-Item -LiteralPath $longPath -Force).Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
    } catch {
    }

    Start-Sleep -Milliseconds 250
    try {
      Remove-Item -LiteralPath $longPath -Recurse -Force -ErrorAction Stop
    } catch {
      [System.IO.Directory]::Delete($longPath, $true)
    }
  }
}

if (Test-Path -LiteralPath $stageRootFull) {
  Remove-StageTree $stageRootFull
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
  (Join-Path $projectRoot "13_librustdesk_core"),
  (Join-Path $projectRoot "github_artifacts"),
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
$robocopyArgs = @($projectRoot, $stageRootFull, "/E", "/XJ", "/R:2", "/W:1", "/XD") + $excludeDirs + @("/XF") + $excludeFiles
& robocopy @robocopyArgs | Out-Host
$robocopyExit = $LASTEXITCODE
if ($robocopyExit -gt 7) {
  throw "robocopy failed with exit code $robocopyExit"
}

$buildProfilePath = Join-Path $stageRootFull "build-profile.json5"
if (Test-Path -LiteralPath $buildProfilePath) {
  $sourceSigningRoot = Join-Path $tempRoot "rustdesk_harmonyos_signing"
  $stageSigningRoot = Join-Path $stageRootFull "signing"
  if (-not (Test-Path -LiteralPath $sourceSigningRoot)) {
    throw "Signing material directory is missing: $sourceSigningRoot"
  }
  if (Test-Path -LiteralPath $stageSigningRoot) {
    Remove-Item -LiteralPath $stageSigningRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $stageSigningRoot | Out-Null
  Get-ChildItem -LiteralPath $sourceSigningRoot -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stageSigningRoot -Recurse -Force
  }

  $signingRoot = $sourceSigningRoot.Replace("\", "/").TrimEnd("/") + "/"
  $stageSigningRelative = "./signing/"
  $buildProfile = Get-Content -LiteralPath $buildProfilePath -Raw
  $buildProfile = $buildProfile.Replace("../99_Temp/rustdesk_harmonyos_signing/", $stageSigningRelative)
  $buildProfile = $buildProfile.Replace("..\\99_Temp\\rustdesk_harmonyos_signing\\", $stageSigningRelative)
  $buildProfile = $buildProfile.Replace($signingRoot, $stageSigningRelative)
  Set-Content -LiteralPath $buildProfilePath -Value $buildProfile -Encoding UTF8 -NoNewline
}

Write-Host "Staged project for build at $stageRootFull"
$global:LASTEXITCODE = 0
