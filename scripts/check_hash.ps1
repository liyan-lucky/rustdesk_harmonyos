$colors = @('#1976C9', '#0F9D8A', '#7C5CE5', '#2E9B58', '#E18428', '#D84E78', '#667085')
$colorNames = @('蓝', '青', '紫', '绿', '橙', '玫红', '灰')

$icons = @(
  'close.svg', 'arrow-forward-ios.svg', 'dots_vertical.svg', 'display.svg',
  'call-made.svg', 'group.svg', 'search.svg', 'refresh.svg', 'logout.svg',
  'translate.svg', 'color_palette.svg', 'fingerprint.svg', 'settings_gear.svg',
  'settings_person.svg', 'settings_network.svg', 'settings_cpu.svg', 'settings_server.svg',
  'checkbox-checked.svg', 'checkbox-unchecked.svg', 'checkbox-outline.svg',
  'info_edit.svg', 'delete-forever.svg', 'scan_frame.svg', 'arrow-back-ios.svg',
  'nav-arrow-right.svg', 'nav-arrow-left.svg', 'ft_back.svg', 'ft_up.svg',
  'ft_home.svg', 'ft_phone.svg', 'ft_remote.svg', 'opt_touch.svg', 'opt_mouse.svg',
  'menu_key.svg', 'opt_user.svg', 'arrow_input.svg', 'Sorting_order.svg',
  'arrow-autofit-up.svg', 'arrow-autofit-down.svg', 'secure_stop.svg',
  'settings_gear.svg', 'rec.svg', 'file.svg', 'chat.svg'
)

$dist = @(0,0,0,0,0,0,0)
foreach ($icon in $icons) {
  $hash = 0
  for ($i = 0; $i -lt $icon.Length; $i++) {
    $hash = (($hash -shl 5) - $hash) + [int]$icon[$i]
    $hash = $hash -band 0x7FFFFFFF
  }
  $idx = $hash % 7
  $dist[$idx]++
  Write-Host "$icon -> hash=$hash, idx=$idx, color=$($colors[$idx]) ($($colorNames[$idx]))"
}

Write-Host ""
Write-Host "=== Distribution ==="
for ($i = 0; $i -lt 7; $i++) {
  Write-Host "$($colorNames[$i]) ($($colors[$i])): $($dist[$i]) icons"
}
