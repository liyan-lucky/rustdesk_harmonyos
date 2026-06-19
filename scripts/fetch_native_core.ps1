param(
  [string]$ProjectRoot = "",
  [string]$CoreUrl = $env:RUSTDESK_CORE_URL,
  [string]$ExpectedSha256 = $env:RUSTDESK_CORE_SHA256,
  [string]$CoreX86_64Url = $env:RUSTDESK_CORE_X86_64_URL,
  [string]$ExpectedX86_64Sha256 = $env:RUSTDESK_CORE_X86_64_SHA256,
  [int64]$MinCoreBytes = 52428800,
  [switch]$Force,
  [switch]$SkipDownload,
  [switch]$SkipX86_64
)

$ErrorActionPreference = "Stop"

$defaultCoreUrl = "https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core.a"
$defaultCoreX86_64Url = "https://github.com/liyan-lucky/librustdesk_core/releases/latest/download/librustdesk_core_x86_64.a"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
} else {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

if ([string]::IsNullOrWhiteSpace($CoreUrl)) {
  $CoreUrl = $defaultCoreUrl
}

if ([string]::IsNullOrWhiteSpace($CoreX86_64Url)) {
  $CoreX86_64Url = $defaultCoreX86_64Url
}

if ($env:RUSTDESK_CORE_SKIP_DOWNLOAD -match '^(1|true|yes)$') {
  $SkipDownload = $true
}

if ($env:RUSTDESK_CORE_SKIP_X86_64 -match '^(1|true|yes)$') {
  $SkipX86_64 = $true
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
$coreX86_64Path = Join-Path $ProjectRoot "entry\src\main\libs\x86_64\librustdesk_core.a"
$coreX86_64Dir = Split-Path -Parent $coreX86_64Path
$downloadDir = Join-Path $tempRoot "librustdesk_core"
$metaPath = Join-Path $downloadDir "librustdesk_core.meta.json"
$metaX86_64Path = Join-Path $downloadDir "librustdesk_core_x86_64.meta.json"

New-Item -ItemType Directory -Force -Path $coreDir | Out-Null
New-Item -ItemType Directory -Force -Path $coreX86_64Dir | Out-Null
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

function Test-RemoteCoreChanged {
  param([Parameter(Mandatory = $true)][string]$Url)

  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  try {
    $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing
  } catch {
    if (Test-Path -LiteralPath $corePath) {
      Write-Host "Remote core HEAD request failed: $($_.Exception.Message). Reusing local core."
      return $false
    }
    Write-Host "Remote core HEAD request failed: $($_.Exception.Message). Local core missing, will download."
    return $true
  }

  $remoteETag = ""
  $remoteContentLength = ""
  $remoteLastModified = ""
  if ($response.Headers["ETag"]) { $remoteETag = $response.Headers["ETag"] }
  if ($response.Headers["Content-Length"]) { $remoteContentLength = $response.Headers["Content-Length"] }
  if ($response.Headers["Last-Modified"]) { $remoteLastModified = $response.Headers["Last-Modified"] }

  if (-not (Test-Path -LiteralPath $metaPath)) {
    Write-Host "No local core metadata found. Will download."
    return $true
  }

  try {
    $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json
  } catch {
    Write-Host "Local core metadata corrupt. Will download."
    return $true
  }

  $changed = $false
  if ($remoteETag -and $meta.ETag -and $remoteETag -ne $meta.ETag) {
    Write-Host "Remote ETag changed: $($meta.ETag) -> $remoteETag"
    $changed = $true
  }
  if ($remoteContentLength -and $meta.ContentLength -and $remoteContentLength -ne $meta.ContentLength) {
    Write-Host "Remote Content-Length changed: $($meta.ContentLength) -> $remoteContentLength"
    $changed = $true
  }
  if ($remoteLastModified -and $meta.LastModified -and $remoteLastModified -ne $meta.LastModified) {
    Write-Host "Remote Last-Modified changed: $($meta.LastModified) -> $remoteLastModified"
    $changed = $true
  }

  if (-not $changed) {
    Write-Host "Remote core unchanged (ETag/Content-Length/Last-Modified match). Skip download."
  }

  return $changed
}

$shouldDownload = $false

if ($SkipDownload) {
  Write-Host "Native core download skipped by RUSTDESK_CORE_SKIP_DOWNLOAD."
} elseif ($Force) {
  $shouldDownload = $true
  Write-Host "Force download requested."
} elseif (-not (Test-Path -LiteralPath $corePath)) {
  $shouldDownload = $true
  Write-Host "Local core not found. Will download."
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
  $currentSha = Get-UpperSha256 -Path $corePath
  if ($currentSha -ne $ExpectedSha256.Trim().ToUpperInvariant()) {
    $shouldDownload = $true
    Write-Host "Local core SHA256 does not match expected. Will download."
  }
}

if (-not $shouldDownload -and -not $SkipDownload -and (Test-Path -LiteralPath $corePath)) {
  $shouldDownload = Test-RemoteCoreChanged -Url $CoreUrl
}

if ($shouldDownload) {
  $tempFile = Join-Path $downloadDir ("librustdesk_core_{0}.a.tmp" -f ([DateTime]::UtcNow.ToString("yyyyMMddHHmmss")))
  Write-Host "Downloading native core:"
  Write-Host "  URL: $CoreUrl"
  Write-Host "  To : $tempFile"

  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  $downloadSucceeded = $false
  try {
    Invoke-WebRequest -Uri $CoreUrl -OutFile $tempFile -UseBasicParsing
    $downloadSucceeded = $true
  } catch {
    if (Test-Path -LiteralPath $corePath) {
      Write-Host "Warning: native core download failed: $($_.Exception.Message). Reusing local core."
      if (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
      }
    } else {
      throw
    }
  }

  if ($downloadSucceeded) {
    $downloaded = Assert-CoreFile -Path $tempFile
    Move-Item -LiteralPath $tempFile -Destination $corePath -Force

    try {
      $headResponse = Invoke-WebRequest -Uri $CoreUrl -Method Head -UseBasicParsing
      $metaJson = @{};
      if ($headResponse.Headers["ETag"]) { $metaJson["ETag"] = $headResponse.Headers["ETag"] }
      if ($headResponse.Headers["Content-Length"]) { $metaJson["ContentLength"] = $headResponse.Headers["Content-Length"] }
      if ($headResponse.Headers["Last-Modified"]) { $metaJson["LastModified"] = $headResponse.Headers["Last-Modified"] }
      $metaJson["DownloadTime"] = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
      $metaJson["Sha256"] = $downloaded.Sha256
      $metaJson | ConvertTo-Json | Set-Content -LiteralPath $metaPath -Encoding UTF8
    } catch {
      Write-Host "Warning: could not save core metadata: $($_.Exception.Message)"
    }

    Write-Host "Native core refreshed: size=$($downloaded.Size), sha256=$($downloaded.Sha256)"
  }
}

$final = Assert-CoreFile -Path $corePath
Write-Host "Native core ready:"
Write-Host "  Path  : $($final.Path)"
Write-Host "  Size  : $($final.Size)"
Write-Host "  SHA256: $($final.Sha256)"
Write-Host "  MTime : $($final.ModifiedTime)"

# --- x86_64 core download ---
$x86_64ShouldDownload = $false

if ($SkipX86_64 -or $SkipDownload) {
  Write-Host "Native x86_64 core download skipped."
} elseif ($Force) {
  $x86_64ShouldDownload = $true
  Write-Host "Force download requested for x86_64 core."
} elseif (-not (Test-Path -LiteralPath $coreX86_64Path)) {
  $x86_64ShouldDownload = $true
  Write-Host "Local x86_64 core not found. Will download."
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedX86_64Sha256)) {
  $currentX86_64Sha = Get-UpperSha256 -Path $coreX86_64Path
  if ($currentX86_64Sha -ne $ExpectedX86_64Sha256.Trim().ToUpperInvariant()) {
    $x86_64ShouldDownload = $true
    Write-Host "Local x86_64 core SHA256 does not match expected. Will download."
  }
}

if (-not $x86_64ShouldDownload -and -not $SkipX86_64 -and -not $SkipDownload -and (Test-Path -LiteralPath $coreX86_64Path)) {
  $x86_64ShouldDownload = Test-RemoteCoreChanged -Url $CoreX86_64Url
}

if ($x86_64ShouldDownload) {
  $tempFileX86_64 = Join-Path $downloadDir ("librustdesk_core_x86_64_{0}.a.tmp" -f ([DateTime]::UtcNow.ToString("yyyyMMddHHmmss")))
  Write-Host "Downloading native x86_64 core:"
  Write-Host "  URL: $CoreX86_64Url"
  Write-Host "  To : $tempFileX86_64"

  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {}

  $x86_64DownloadSucceeded = $false
  try {
    Invoke-WebRequest -Uri $CoreX86_64Url -OutFile $tempFileX86_64 -UseBasicParsing
    $x86_64DownloadSucceeded = $true
  } catch {
    Write-Host "Warning: x86_64 core download failed: $($_.Exception.Message). Skipping x86_64 core."
    if (Test-Path -LiteralPath $tempFileX86_64) {
      Remove-Item -LiteralPath $tempFileX86_64 -Force -ErrorAction SilentlyContinue
    }
  }

  if ($x86_64DownloadSucceeded) {
    $downloadedX86_64 = Assert-CoreFile -Path $tempFileX86_64
    Move-Item -LiteralPath $tempFileX86_64 -Destination $coreX86_64Path -Force

    try {
      $headResponseX86_64 = Invoke-WebRequest -Uri $CoreX86_64Url -Method Head -UseBasicParsing
      $metaX86_64Json = @{};
      if ($headResponseX86_64.Headers["ETag"]) { $metaX86_64Json["ETag"] = $headResponseX86_64.Headers["ETag"] }
      if ($headResponseX86_64.Headers["Content-Length"]) { $metaX86_64Json["ContentLength"] = $headResponseX86_64.Headers["Content-Length"] }
      if ($headResponseX86_64.Headers["Last-Modified"]) { $metaX86_64Json["LastModified"] = $headResponseX86_64.Headers["Last-Modified"] }
      $metaX86_64Json["DownloadTime"] = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss")
      $metaX86_64Json["Sha256"] = $downloadedX86_64.Sha256
      $metaX86_64Json | ConvertTo-Json | Set-Content -LiteralPath $metaX86_64Path -Encoding UTF8
    } catch {
      Write-Host "Warning: could not save x86_64 core metadata: $($_.Exception.Message)"
    }

    Write-Host "Native x86_64 core refreshed: size=$($downloadedX86_64.Size), sha256=$($downloadedX86_64.Sha256)"
  }
}

if (Test-Path -LiteralPath $coreX86_64Path) {
  $finalX86_64 = Assert-CoreFile -Path $coreX86_64Path
  Write-Host "Native x86_64 core ready:"
  Write-Host "  Path  : $($finalX86_64.Path)"
  Write-Host "  Size  : $($finalX86_64.Size)"
  Write-Host "  SHA256: $($finalX86_64.Sha256)"
  Write-Host "  MTime : $($finalX86_64.ModifiedTime)"
} else {
  Write-Host "Native x86_64 core not available (stub mode will be used for x86_64 builds)."
}
