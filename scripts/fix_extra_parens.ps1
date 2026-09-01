$files = @(
  'E:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\ets\pages\Index.ets',
  'E:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\ets\pages\RemoteControl.ets'
)
foreach ($file in $files) {
  $content = [System.IO.File]::ReadAllText($file)
  $newContent = [regex]::Replace($content, '\.colorFilter\(createIconColorFilterForSrc\(''([^'']+)''\)\)\)', '.colorFilter(createIconColorFilterForSrc(''$1''))')
  if ($newContent -ne $content) {
    [System.IO.File]::WriteAllText($file, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Fixed: $file"
  } else {
    Write-Host "No change: $file"
  }
}
