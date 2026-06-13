param(
  [string]$ProjectRoot = "",
  [string]$CoreUrl = $env:RUSTDESK_CORE_URL,
  [string]$ExpectedSha256 = $env:RUSTDESK_CORE_SHA256,
  [int64]$MinCoreBytes = 52428800,
  [switch]$Force,
  [switch]$SkipDownload
)

$ErrorActionPreference = "Stop"

$defaultCoreUrl = "https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

if ([string]::IsNullOrWhiteSpace($CoreUrl)) {
  $CoreUrl = $defaultCoreUrl
}

if ($env:RUSTDESK_CORE_SKIP_DOWNLOAD -match '^(1|true|yes)$') {
  $SkipDownload = $true
}

if ($env:RUSTDESK_CORE_FORCE_DOWNLOAD -match '^(1|true|yes)$') {
  $Force = $true
}

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot ".."))
$tempRoot = if ($env:RUSTDESK_HARMONY_TEMP_ROOT) {
  [System.IO.Path]::GetFullPath($env:RUSTDESK_HARMONY_TEMP_ROOT)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot "99_Temp"))
}

$corePath = Join-Path $ProjectRoot "entry\src\main\libs\arm64\librustdesk_core.a"
$coreDir = Split-Path -Parent $corePath
$downloadDir = Join-Path $tempRoot "librustdesk_core"

New-Item -ItemType Directory -Force -Path $coreDir | Out-Null
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

function Get-UpperSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-CoreFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Native core staticlib is missing: $Path"
  }

  $item = Get-Item -LiteralPath $Path
  if ($item.Length -lt $MinCoreBytes) {
    throw "Native core staticlib is too small: $($item.Length) bytes at $Path"
  }

  $sha256 = Get-UpperSha256 -Path $Path
  $expected = if ($ExpectedSha256) { $ExpectedSha256.Trim().ToUpperInvariant() } else { "" }
  if (-not [string]::IsNullOrWhiteSpace($expected) -and $sha256 -ne $expected) {
    throw "Native core SHA256 mismatch. Expected $expected but got $sha256"
  }

  return [PSCustomObject]@{
    Path = $Path
    Size = $item.Length
    Sha256 = $sha256
    ModifiedTime = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
  }
}

$shouldDownload = -not $SkipDownload -and ($Force -or -not (Test-Path -LiteralPath $corePath))

if (-not $shouldDownload -and -not [string]::IsNullOrWhiteSpace($ExpectedSha256) -and (Test-Path -LiteralPath $corePath)) {
  $currentSha = Get-UpperSha256 -Path $corePath
  if ($currentSha -ne $ExpectedSha256.Trim().ToUpperInvariant()) {
    $shouldDownload = $true
  }
}

if ($shouldDownload) {
  $tempFile = Join-Path $downloadDir ("librustdesk_core_{0}.a.tmp" -f ([DateTime]::UtcNow.ToString("yyyyMMddHHmmss")))
  Write-Host "Downloading native core:"
  Write-Host "  URL: $CoreUrl"
  Write-Host "  To : $tempFile"

  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  Invoke-WebRequest -Uri $CoreUrl -OutFile $tempFile -UseBasicParsing
  $downloaded = Assert-CoreFile -Path $tempFile
  Move-Item -LiteralPath $tempFile -Destination $corePath -Force
  Write-Host "Native core refreshed: size=$($downloaded.Size), sha256=$($downloaded.Sha256)"
} elseif ($SkipDownload) {
  Write-Host "Native core download skipped by RUSTDESK_CORE_SKIP_DOWNLOAD."
} else {
  Write-Host "Native core already exists; keeping local file. Use -Force or RUSTDESK_CORE_FORCE_DOWNLOAD=1 to refresh."
}

$final = Assert-CoreFile -Path $corePath
Write-Host "Native core ready:"
Write-Host "  Path  : $($final.Path)"
Write-Host "  Size  : $($final.Size)"
Write-Host "  SHA256: $($final.Sha256)"
Write-Host "  MTime : $($final.ModifiedTime)"
