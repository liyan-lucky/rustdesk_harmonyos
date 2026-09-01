$baseDir = 'E:\Visual_Studio_Code\11_Rustdesk_harmonyos'
$files = @(
  'entry\src\main\ets\pages\Index.ets',
  'entry\src\main\ets\pages\RemoteControl.ets',
  'entry\src\main\ets\pages\AddressBook.ets',
  'entry\src\main\ets\pages\FileTransfer.ets',
  'entry\src\main\ets\pages\Chat.ets',
  'entry\src\main\ets\pages\ViewCamera.ets'
)

$allIcons = @{}

foreach ($relFile in $files) {
  $file = Join-Path $baseDir $relFile
  $lines = Get-Content $file
  $lastIcon = ''
  $replaceCount = 0

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Track last rawfile icon
    $rawfileMatches = [regex]::Matches($line, '\$rawfile\(''([^'']+)''\)')
    if ($rawfileMatches.Count -gt 0) {
      $lastIcon = $rawfileMatches[$rawfileMatches.Count - 1].Groups[1].Value
    }

    # Check for fillColor(this.theme_XXX)
    $fillColorMatches = [regex]::Matches($line, '\.fillColor\(this\.theme_[A-Z_]+\)')
    if ($fillColorMatches.Count -gt 0) {
      $iconName = $lastIcon
      if (-not $allIcons.ContainsKey($iconName)) {
        $allIcons[$iconName] = 0
      }
      $allIcons[$iconName]++

      # Replace
      $newLine = [regex]::Replace($line, '\.fillColor\(this\.theme_[A-Z_]+\)', ".fillColor(resolveIconFillColor('$iconName'))")
      if ($newLine -ne $line) {
        $lines[$i] = $newLine
        $replaceCount++
      }
    }
  }

  if ($replaceCount -gt 0) {
    $content = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Modified $replaceCount replacements: $relFile"
  } else {
    Write-Host "No changes: $relFile"
  }
}

Write-Host ""
Write-Host "=== Icons used in fillColor calls ==="
foreach ($kv in $allIcons.GetEnumerator() | Sort-Object Name) {
  Write-Host "  $($kv.Key): $($kv.Value) occurrences"
}
