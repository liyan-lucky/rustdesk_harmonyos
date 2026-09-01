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
  'rec.svg', 'file.svg', 'chat.svg'
)

function Test-Hash($name, $hashFn) {
  $dist = @(0,0,0,0,0,0,0)
  $results = @{}
  foreach ($icon in $icons) {
    $idx = & $hashFn $icon
    $dist[$idx]++
    $results[$icon] = $idx
  }
  $max = ($dist | Measure-Object -Maximum).Maximum
  $min = ($dist | Measure-Object -Minimum).Minimum
  Write-Host "$name : dist=$($dist -join ',') max=$max min=$min"
  return $results
}

# Hash 1: FNV-1a with finalizer
function H1($s) {
  $h = 0x811c9dc5
  for ($i = 0; $i -lt $s.Length; $i++) {
    $h = $h -bxor [int]$s[$i]
    $h = [uint32]($h * 0x01000193)
  }
  $h = $h -bxor ($h -shr 13)
  $h = [uint32]($h * 0x5bd1e995)
  $h = $h -bxor ($h -shr 15)
  return [int]([uint32]$h) % 7
}

# Hash 2: char*position + length
function H2($s) {
  $h = $s.Length * 2654435761
  for ($i = 0; $i -lt $s.Length; $i++) {
    $h = ($h + [int]$s[$i] * ($i + 1) * 16777619) -band 0x7FFFFFFF
  }
  $h = (($h -bxor ($h -shr 13)) * 1274126177) -band 0x7FFFFFFF
  $h = ($h -bxor ($h -shr 16)) -band 0x7FFFFFFF
  return [Math]::Abs($h) % 7
}

# Hash 3: simple sum with weights
function H3($s) {
  $h = 0
  for ($i = 0; $i -lt $s.Length; $i++) {
    $h = ($h * 37 + [int]$s[$i] * ($i + 3)) -band 0x7FFFFFFF
  }
  $h = ($h -bxor ($h -shr 11)) -band 0x7FFFFFFF
  return [Math]::Abs($h) % 7
}

# Hash 4: djb2 with mixing
function H4($s) {
  $h = 5381
  for ($i = 0; $i -lt $s.Length; $i++) {
    $h = (($h -shl 5) + $h + [int]$s[$i]) -band 0x7FFFFFFF
  }
  $h = (($h -bxor ($h -shr 16)) * 0x85ebca6b) -band 0x7FFFFFFF
  $h = ($h -bxor ($h -shr 13)) -band 0x7FFFFFFF
  return [Math]::Abs($h) % 7
}

Write-Host "=== Hash Distribution Comparison ==="
$r1 = Test-Hash "FNV-1a+finalizer" H1
$r2 = Test-Hash "char*pos+length" H2
$r3 = Test-Hash "sum+weights" H3
$r4 = Test-Hash "djb2+mixing" H4

Write-Host ""
Write-Host "=== Best hash detail (H2) ==="
$dist = @(0,0,0,0,0,0,0)
foreach ($icon in $icons) {
  $idx = $r2[$icon]
  $dist[$idx]++
  Write-Host "  $icon -> $($colorNames[$idx]) ($($colors[$idx]))"
}
Write-Host ""
for ($i = 0; $i -lt 7; $i++) {
  Write-Host "$($colorNames[$i]): $($dist[$i]) icons"
}
