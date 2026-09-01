$baseDir = 'E:\Visual_Studio_Code\11_Rustdesk_harmonyos'
$files = @(
  'entry\src\main\ets\pages\Index.ets',
  'entry\src\main\ets\pages\RemoteControl.ets',
  'entry\src\main\ets\pages\AddressBook.ets',
  'entry\src\main\ets\pages\FileTransfer.ets',
  'entry\src\main\ets\pages\Chat.ets',
  'entry\src\main\ets\pages\ViewCamera.ets',
  'entry\src\main\ets\pages\LoginPage.ets'
)

$totalFill = 0
$totalStroke = 0
$totalLocal = 0

foreach ($relFile in $files) {
  $file = Join-Path $baseDir $relFile
  $lines = Get-Content $file
  $lastIcon = ''
  $replaceFill = 0
  $replaceStroke = 0
  $replaceLocal = 0

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    # Track last rawfile icon
    $rawfileMatches = [regex]::Matches($line, '\$rawfile\(''([^'']+)''\)')
    if ($rawfileMatches.Count -gt 0) {
      $lastIcon = $rawfileMatches[$rawfileMatches.Count - 1].Groups[1].Value
    }

    # Replace .fillColor(resolveIconFillColor('xxx.svg')) with .colorFilter(createIconColorFilterForSrc('xxx.svg'))
    $fillMatches = [regex]::Matches($line, '\.fillColor\(resolveIconFillColor\(''([^'']+)''\)\)')
    if ($fillMatches.Count -gt 0) {
      $newLine = [regex]::Replace($line, '\.fillColor\(resolveIconFillColor\(''([^'']+)''\)\)', '.colorFilter(createIconColorFilterForSrc(''$1''))')
      if ($newLine -ne $line) {
        $lines[$i] = $newLine
        $replaceFill++
      }
    }

    # Replace .colorFilter(createStrokeIconColorFilter(...)) with .colorFilter(createIconColorFilterForSrc('icon.svg'))
    $strokeMatches = [regex]::Matches($line, '\.colorFilter\(createStrokeIconColorFilter\([^)]+\)\)')
    if ($strokeMatches.Count -gt 0 -and $lastIcon.Length -gt 0) {
      $newLine = [regex]::Replace($line, '\.colorFilter\(createStrokeIconColorFilter\([^)]+\)\)', ".colorFilter(createIconColorFilterForSrc('$lastIcon'))")
      if ($newLine -ne $line) {
        $lines[$i] = $newLine
        $replaceStroke++
      }
    }

    # Replace .colorFilter(this.createStrokeIconColorFilter(...)) with .colorFilter(createIconColorFilterForSrc('icon.svg'))
    $localMatches = [regex]::Matches($line, '\.colorFilter\(this\.createStrokeIconColorFilter\([^)]+\)\)')
    if ($localMatches.Count -gt 0 -and $lastIcon.Length -gt 0) {
      $newLine = [regex]::Replace($line, '\.colorFilter\(this\.createStrokeIconColorFilter\([^)]+\)\)', ".colorFilter(createIconColorFilterForSrc('$lastIcon'))")
      if ($newLine -ne $line) {
        $lines[$i] = $newLine
        $replaceLocal++
      }
    }
  }

  if ($replaceFill -gt 0 -or $replaceStroke -gt 0 -or $replaceLocal -gt 0) {
    $content = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Modified: $relFile (fillColor:$replaceFill, strokeImported:$replaceStroke, strokeLocal:$replaceLocal)"
  } else {
    Write-Host "No changes: $relFile"
  }
  $totalFill += $replaceFill
  $totalStroke += $replaceStroke
  $totalLocal += $replaceLocal
}

Write-Host ""
Write-Host "Total: fillColor=$totalFill, strokeImported=$totalStroke, strokeLocal=$totalLocal"
