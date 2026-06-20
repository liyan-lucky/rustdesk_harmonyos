param(
  [ValidateSet("Status", "Portable", "DevEco")]
  [string]$Mode = "Status",

  [string]$TempRoot,
  [string]$SigningRoot
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".."))
if ([string]::IsNullOrWhiteSpace($TempRoot)) {
  if ($env:RUSTDESK_HARMONY_TEMP_ROOT) {
    $TempRoot = $env:RUSTDESK_HARMONY_TEMP_ROOT
  } else {
    $TempRoot = Join-Path $workspaceRoot "99_Temp"
  }
}
$tempRootFull = [System.IO.Path]::GetFullPath($TempRoot)
if ([string]::IsNullOrWhiteSpace($SigningRoot)) {
  $SigningRoot = Join-Path $tempRootFull "rustdesk_harmonyos_signing"
}
$signingRootFull = [System.IO.Path]::GetFullPath($SigningRoot)

$buildProfilePath = Join-Path $projectRoot "build-profile.json5"
$hvigorConfigPath = Join-Path $projectRoot "hvigor\hvigor-config.json5"

function Convert-ToJsonPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  return ([System.IO.Path]::GetFullPath($Path) -replace "\\", "/")
}

function Convert-ToRepoRelativeJsonPath {
  param([Parameter(Mandatory = $true)][string]$FileName)
  return "../99_Temp/rustdesk_harmonyos_signing/$FileName"
}

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-SigningFileName {
  param(
    [Parameter(Mandatory = $true)][string]$Extension,
    [Parameter(Mandatory = $true)][string]$PreferredName
  )

  $preferredPath = Join-Path $signingRootFull $PreferredName
  if (Test-Path -LiteralPath $preferredPath) {
    return $PreferredName
  }

  $match = Get-ChildItem -LiteralPath $signingRootFull -File -Filter "*.$Extension" -ErrorAction Stop |
    Sort-Object Name |
    Select-Object -First 1
  if (-not $match) {
    throw "Signing file '*.$Extension' was not found under $signingRootFull"
  }
  return $match.Name
}

function Set-JsonStringValue {
  param(
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][string]$Key,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $escaped = $Value.Replace("\", "\\")
  return [regex]::Replace(
    $Content,
    "(?m)(`"$([regex]::Escape($Key))`"\s*:\s*`")[^`"]*(`")",
    { param($match) $match.Groups[1].Value + $escaped + $match.Groups[2].Value },
    1
  )
}

function Write-HvigorConfig {
  param(
    [Parameter(Mandatory = $true)][string]$CacheDir,
    [Parameter(Mandatory = $true)][string]$BuildDir
  )

  $content = @"
{
  "modelVersion": "6.1.1",
  "dependencies": {},
  "properties": {
    "hvigor.cacheDir": "$CacheDir",
    "ohos.buildDir": "$BuildDir"
  }
}
"@
  Write-Utf8NoBomFile -Path $hvigorConfigPath -Content ($content + [Environment]::NewLine)
}

function Write-BuildProfileSigningPaths {
  param(
    [Parameter(Mandatory = $true)][string]$CertPath,
    [Parameter(Mandatory = $true)][string]$ProfilePath,
    [Parameter(Mandatory = $true)][string]$StoreFilePath
  )

  $content = (Get-Content -LiteralPath $buildProfilePath -Raw).TrimStart([char]0xFEFF)
  $content = Set-JsonStringValue -Content $content -Key "certpath" -Value $CertPath
  $content = Set-JsonStringValue -Content $content -Key "profile" -Value $ProfilePath
  $content = Set-JsonStringValue -Content $content -Key "storeFile" -Value $StoreFilePath
  Write-Utf8NoBomFile -Path $buildProfilePath -Content $content
}

function Show-Status {
  $buildProfile = Get-Content -LiteralPath $buildProfilePath -Raw
  $hvigorConfig = Get-Content -LiteralPath $hvigorConfigPath -Raw
  $paths = [ordered]@{
    "projectRoot" = $projectRoot
    "tempRoot" = $tempRootFull
    "signingRoot" = $signingRootFull
    "hvigor.cacheDir" = ([regex]::Match($hvigorConfig, '"hvigor\.cacheDir"\s*:\s*"([^"]+)"')).Groups[1].Value
    "ohos.buildDir" = ([regex]::Match($hvigorConfig, '"ohos\.buildDir"\s*:\s*"([^"]+)"')).Groups[1].Value
    "certpath" = ([regex]::Match($buildProfile, '"certpath"\s*:\s*"([^"]+)"')).Groups[1].Value
    "profile" = ([regex]::Match($buildProfile, '"profile"\s*:\s*"([^"]+)"')).Groups[1].Value
    "storeFile" = ([regex]::Match($buildProfile, '"storeFile"\s*:\s*"([^"]+)"')).Groups[1].Value
  }
  $paths.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key): $($_.Value)"
  }
}

if ($Mode -eq "Status") {
  Show-Status
  exit 0
}

if (-not (Test-Path -LiteralPath $signingRootFull)) {
  throw "Signing material directory is missing: $signingRootFull"
}

$certName = Get-SigningFileName -Extension "cer" -PreferredName "debug_hos.cer"
$profileName = Get-SigningFileName -Extension "p7b" -PreferredName "debug_hos.p7b"
$storeName = Get-SigningFileName -Extension "p12" -PreferredName "debug_hos.p12"

if ($Mode -eq "Portable") {
  Write-HvigorConfig -CacheDir "../99_Temp/harmonyos_cache" -BuildDir "../99_Temp/harmonyos_build"
  Write-BuildProfileSigningPaths `
    -CertPath (Convert-ToRepoRelativeJsonPath $certName) `
    -ProfilePath (Convert-ToRepoRelativeJsonPath $profileName) `
    -StoreFilePath (Convert-ToRepoRelativeJsonPath $storeName)
  Write-Host "Switched to portable repo paths."
  Show-Status
  exit 0
}

$cacheDir = Join-Path $tempRootFull "harmonyos_cache"
$buildDir = Join-Path $tempRootFull "harmonyos_build"
New-Item -ItemType Directory -Force -Path $cacheDir, $buildDir | Out-Null

Write-HvigorConfig -CacheDir (Convert-ToJsonPath $cacheDir) -BuildDir (Convert-ToJsonPath $buildDir)
Write-BuildProfileSigningPaths `
  -CertPath (Convert-ToJsonPath (Join-Path $signingRootFull $certName)) `
  -ProfilePath (Convert-ToJsonPath (Join-Path $signingRootFull $profileName)) `
  -StoreFilePath (Convert-ToJsonPath (Join-Path $signingRootFull $storeName))

Write-Host "Switched to DevEco absolute paths."
Show-Status
