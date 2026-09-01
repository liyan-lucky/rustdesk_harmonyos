$file = 'E:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\ets\pages\RemoteControl.ets'
$content = [System.IO.File]::ReadAllText($file)
$newContent = [regex]::Replace($content, 'this\.buildToolBtnSvg\(\$rawfile\(''([^'']+)''\),', "this.buildToolBtnSvg(`$rawfile('$1'), '$1',")
if ($newContent -ne $content) {
  [System.IO.File]::WriteAllText($file, $newContent, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Updated buildToolBtnSvg call sites"
} else {
  Write-Host "No changes"
}
