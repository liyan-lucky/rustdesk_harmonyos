param(
  [string]$BuildProfilePath,
  [string]$AppJsonPath,
  [string]$ProductName = "default"
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir

function Resolve-DefaultFilePath {
  param(
    [string[]]$Candidates
  )

  foreach ($candidate in $Candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return [System.IO.Path]::GetFullPath($candidate)
    }
  }

  return $null
}

function Read-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "JSON file was not found: $Path"
  }

  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "JSON file is empty: $Path"
  }

  try {
    return $raw | ConvertFrom-Json
  } catch {
    throw "Failed to parse JSON file '$Path'."
  }
}

function Resolve-ConfigPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BaseDirectory,
    [Parameter(Mandatory = $true)]
    [string]$CandidatePath
  )

  if ([System.IO.Path]::IsPathRooted($CandidatePath)) {
    return [System.IO.Path]::GetFullPath($CandidatePath)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $CandidatePath))
}

function Get-AppBundleName {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $appJson = Read-JsonFile -Path $Path
  $bundleName = $appJson.app.bundleName
  if ([string]::IsNullOrWhiteSpace($bundleName)) {
    throw "bundleName was not found in $Path"
  }

  return $bundleName
}

function Get-ProductSigningProfile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$ProductName
  )

  $buildProfile = Read-JsonFile -Path $Path
  $product = @($buildProfile.app.products | Where-Object { $_.name -eq $ProductName } | Select-Object -First 1)
  if ($product.Count -eq 0) {
    throw "Product '$ProductName' was not found in $Path"
  }

  $signingConfigName = "$($product[0].signingConfig)".Trim()
  if ([string]::IsNullOrWhiteSpace($signingConfigName)) {
    return $null
  }

  $signingConfig = @($buildProfile.app.signingConfigs | Where-Object { $_.name -eq $signingConfigName } | Select-Object -First 1)
  if ($signingConfig.Count -eq 0) {
    throw "Signing config '$signingConfigName' was not found in $Path"
  }

  $profilePath = "$($signingConfig[0].material.profile)".Trim()
  if ([string]::IsNullOrWhiteSpace($profilePath)) {
    throw "Signing config '$signingConfigName' does not define material.profile in $Path"
  }

  return [PSCustomObject]@{
    SigningConfigName = $signingConfigName
    ProfilePath = Resolve-ConfigPath -BaseDirectory (Split-Path -Parent $Path) -CandidatePath $profilePath
  }
}

function Format-Timestamp {
  param(
    [object]$UnixTimeSeconds
  )

  if ($null -eq $UnixTimeSeconds -or [string]::IsNullOrWhiteSpace("$UnixTimeSeconds")) {
    return $null
  }

  return [DateTimeOffset]::FromUnixTimeSeconds([Int64]$UnixTimeSeconds).ToString("yyyy-MM-dd HH:mm:ss zzz")
}

function Get-SigningProfileMetadata {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ProfilePath
  )

  if (-not (Test-Path -LiteralPath $ProfilePath)) {
    throw "Signing profile was not found: $ProfilePath"
  }

  try {
    Add-Type -AssemblyName System.Security
  } catch {
    throw "System.Security could not be loaded. It is required to inspect the HarmonyOS .p7b profile."
  }

  $cms = New-Object System.Security.Cryptography.Pkcs.SignedCms
  try {
    $cms.Decode([System.IO.File]::ReadAllBytes($ProfilePath))
  } catch {
    throw "Failed to decode the HarmonyOS signing profile: $ProfilePath"
  }

  $contentText = [System.Text.Encoding]::UTF8.GetString($cms.ContentInfo.Content)
  if ([string]::IsNullOrWhiteSpace($contentText)) {
    throw "The HarmonyOS signing profile did not contain readable content: $ProfilePath"
  }

  try {
    $contentJson = $contentText | ConvertFrom-Json
  } catch {
    throw "Failed to parse the decoded HarmonyOS signing profile JSON: $ProfilePath"
  }

  $validFrom = $null
  $validTo = $null
  if ($contentJson.validity.'not-before') {
    $validFrom = [Int64]$contentJson.validity.'not-before'
  }
  if ($contentJson.validity.'not-after') {
    $validTo = [Int64]$contentJson.validity.'not-after'
  }

  return [PSCustomObject]@{
    BundleName = $contentJson.'bundle-info'.'bundle-name'
    ValidFrom = $validFrom
    ValidTo = $validTo
  }
}

if (-not $BuildProfilePath) {
  $BuildProfilePath = Resolve-DefaultFilePath -Candidates @(
    (Join-Path $projectRoot "build-profile.json5")
  )
}
if (-not $AppJsonPath) {
  $AppJsonPath = Resolve-DefaultFilePath -Candidates @(
    (Join-Path $projectRoot "AppScope\\app.json5"),
    (Join-Path $projectRoot "AppScope\\app.json")
  )
}

if (-not $BuildProfilePath) {
  throw "build-profile.json5 could not be located under $projectRoot"
}
if (-not $AppJsonPath) {
  throw "AppScope/app.json5 or AppScope/app.json could not be located under $projectRoot"
}

$BuildProfilePath = [System.IO.Path]::GetFullPath($BuildProfilePath)
$AppJsonPath = [System.IO.Path]::GetFullPath($AppJsonPath)

$appBundleName = Get-AppBundleName -Path $AppJsonPath
$productSigningProfile = Get-ProductSigningProfile -Path $BuildProfilePath -ProductName $ProductName

Write-Host "App bundleName: $appBundleName"
Write-Host "Build profile: $BuildProfilePath"
Write-Host "Product: $ProductName"

if ($null -eq $productSigningProfile) {
  Write-Host "Product '$ProductName' does not define a signingConfig. Signing profile check is not required."
  exit 0
}

$profileMetadata = Get-SigningProfileMetadata -ProfilePath $productSigningProfile.ProfilePath

Write-Host "Signing config: $($productSigningProfile.SigningConfigName)"
Write-Host "Signing profile: $($productSigningProfile.ProfilePath)"
if (-not [string]::IsNullOrWhiteSpace($profileMetadata.BundleName)) {
  Write-Host "Profile bundleName: $($profileMetadata.BundleName)"
}

$validFromText = Format-Timestamp -UnixTimeSeconds $profileMetadata.ValidFrom
if ($validFromText) {
  Write-Host "Profile valid from: $validFromText"
}

$validToText = Format-Timestamp -UnixTimeSeconds $profileMetadata.ValidTo
if ($validToText) {
  Write-Host "Profile valid to: $validToText"
}

$issues = New-Object System.Collections.Generic.List[string]
if ([string]::IsNullOrWhiteSpace($profileMetadata.BundleName)) {
  $issues.Add("The profile bundle-name could not be read from $($productSigningProfile.ProfilePath).") | Out-Null
} elseif ($profileMetadata.BundleName -ne $appBundleName) {
  $issues.Add("The profile bundle-name '$($profileMetadata.BundleName)' does not match app bundleName '$appBundleName'.") | Out-Null
}

if ($profileMetadata.ValidTo -and ([DateTimeOffset]::FromUnixTimeSeconds($profileMetadata.ValidTo).UtcDateTime -lt [DateTime]::UtcNow)) {
  $issues.Add("The profile expired on $validToText.") | Out-Null
}

if ($issues.Count -gt 0) {
  $details = $issues | ForEach-Object { " - $_" }
  $guidance = @(
    "Generate a new HarmonyOS signing profile in DevEco Studio for bundle '$appBundleName'.",
    "Replace the repo-local signing files referenced by build-profile.json5, especially debug_hos.p7b and any matching .cer/.p12 files."
  )
  throw ("Signing profile validation failed:`n{0}`n{1}" -f ($details -join "`n"), (($guidance | ForEach-Object { " - $_" }) -join "`n"))
}

Write-Host "Signing profile validation passed."
