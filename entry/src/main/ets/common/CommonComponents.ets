import { ThemeConfig } from './ThemeConfig';
import { I18nService } from '../services/I18nService';
import drawing from '@ohos.graphics.drawing';

export function toArgbColor(color: string): number {
  const normalized = color.trim().startsWith('#') ? color.trim().substring(1) : color.trim();
  if (normalized.length === 8) {
    return parseInt(normalized, 16);
  }
  return 0xFF000000 + parseInt(normalized, 16);
}

export const ICON_DEFAULT_COLORS: string[] = ['#1976C9', '#0F9D8A', '#7C5CE5', '#2E9B58', '#E18428', '#D84E78', '#667085'];

export function resolveIconColor(defaultColor: string, selectedMode: string = ''): string {
  const selected: string = selectedMode.length > 0 ? selectedMode :
    (AppStorage.get<string>('iconColorMode') || 'colorful');
  return selected === 'colorful' ? defaultColor : selected;
}

export function createIconColorFilter(defaultColor: string, selectedMode: string = ''): drawing.ColorFilter {
  return drawing.ColorFilter.createBlendModeColorFilter(
    toArgbColor(resolveIconColor(defaultColor, selectedMode)), drawing.BlendMode.SRC_IN);
}

export function iconDefaultColor(index: number): string {
  return ICON_DEFAULT_COLORS[Math.abs(index) % ICON_DEFAULT_COLORS.length];
}

export function resolveFillColor(color: string, iconIndex: number = -1): string {
  const mode: string = AppStorage.get<string>('iconColorMode') || 'colorful';
  if (mode === 'colorful') {
    if (iconIndex >= 0) return ICON_DEFAULT_COLORS[iconIndex % ICON_DEFAULT_COLORS.length];
    let hash: number = 0;
    for (let i = 0; i < color.length; i++) {
      hash = ((hash << 5) - hash) + color.charCodeAt(i);
      hash = hash & 0x7FFFFFFF;
    }
    return ICON_DEFAULT_COLORS[hash % ICON_DEFAULT_COLORS.length];
  }
  return mode;
}

const ICON_COLOR_MAP: Record<string, string> = {
  'history.svg': '#1976C9', 'star.svg': '#2E9B58', 'explore.svg': '#7C5CE5',
  'address_book.svg': '#D84E78', 'device_group.svg': '#E18428',
  'monitor.svg': '#D84E78', 'chat.svg': '#1976C9', 'screen.svg': '#2E9B58',
  'settings_gear.svg': '#E18428', 'search.svg': '#7C5CE5',
  'close.svg': '#D84E78', 'refresh.svg': '#0F9D8A', 'secure.svg': '#0F9D8A',
  'dark_mode.svg': '#7C5CE5', 'light_mode.svg': '#E18428', 'translate.svg': '#0F9D8A',
  'fingerprint.svg': '#D84E78', 'logout.svg': '#D84E78', 'dots_vertical.svg': '#667085',
  'arrow-forward-ios.svg': '#667085', 'arrow-back-ios.svg': '#667085',
  'settings_palette.svg': '#7C5CE5', 'display.svg': '#1976C9',
  'call-made.svg': '#2E9B58', 'group.svg': '#0F9D8A', 'info_edit.svg': '#1976C9',
  'delete-forever.svg': '#D84E78', 'scan_frame.svg': '#0F9D8A',
  'checkbox-outline.svg': '#1976C9', 'checkbox-checked.svg': '#2E9B58',
  'checkbox-unchecked.svg': '#667085', 'Sorting_order.svg': '#7C5CE5',
  'arrow_input.svg': '#E18428', 'color_palette.svg': '#D84E78',
  'settings.svg': '#667085', 'settings_person.svg': '#1976C9',
  'dvr.svg': '#2E9B58',
  'settings_network.svg': '#0F9D8A', 'settings_cpu.svg': '#E18428',
  'settings_server.svg': '#7C5CE5', 'menu_key.svg': '#D84E78',
  'opt_user.svg': '#2E9B58', 'auth_api.svg': '#D84E78', 'auth_oidc.svg': '#7C5CE5',
  'auth-google.svg': '#E18428', 'auth-github.svg': '#667085', 'auth-selfhosted.svg': '#0F9D8A',
  'auth-apple.svg': '#1976C9', 'auth-gitlab.svg': '#D84E78', 'auth-gitee.svg': '#D84E78',
  'auth-facebook.svg': '#1976C9', 'auth-microsoft.svg': '#2E9B58', 'auth-azure.svg': '#7C5CE5',
  'auth-qq.svg': '#0F9D8A', 'auth-wechat.svg': '#2E9B58', 'auth-auth0.svg': '#E18428',
  'auth-okta.svg': '#1976C9', 'auth-webauth.svg': '#7C5CE5', 'auth-default.svg': '#D84E78',
  'arrow-autofit-up.svg': '#1976C9', 'arrow-autofit-down.svg': '#D84E78',
  'file_transfer.svg': '#D84E78', 'terminal.svg': '#0F9D8A', 'clipboard.svg': '#7C5CE5',
  'lock.svg': '#E18428', 'unlock.svg': '#2E9B58', 'shield.svg': '#1976C9',
  'key.svg': '#D84E78', 'user.svg': '#1976C9', 'network.svg': '#0F9D8A',
  'globe.svg': '#1976C9', 'server.svg': '#7C5CE5', 'cpu.svg': '#E18428',
  'folder.svg': '#E18428', 'file.svg': '#D84E78', 'image.svg': '#2E9B58',
  'play.svg': '#1976C9', 'pause.svg': '#E18428', 'stop.svg': '#D84E78',
  'volume.svg': '#7C5CE5', 'mic.svg': '#D84E78', 'camera.svg': '#0F90F0A',
  'edit.svg': '#1976C9', 'delete.svg': '#D84E78', 'more.svg': '#667085',
  'back.svg': '#667085', 'forward.svg': '#667085', 'check.svg': '#2E9B58',
  'x.svg': '#D84E78', 'plus.svg': '#2E9B58', 'minus.svg': '#D84E78',
  'info.svg': '#1976C9', 'warning.svg': '#E18428', 'error.svg': '#D84E78',
  'success.svg': '#2E9B58', 'arrow.svg': '#667085', 'checkmark.svg': '#2E9B58',
  'rec.svg': '#D84E78', 'secure_stop.svg': '#D84E78', 'add.svg': '#2E9B58',
  'qr_code.svg': '#0F9D8A', 'bookmark.svg': '#E18428', 'connect.svg': '#1976C9',
  'insecure.svg': '#E18428', 'keyboard.svg': '#7C5CE5', 'keyboard_mouse.svg': '#0F9D8A',
  'login.svg': '#2E9B58', 'content_copy.svg': '#1976C9', 'content_paste.svg': '#7C5CE5',
  'copy.svg': '#1976C9', 'file_export.svg': '#0F9D8A',
  'android.svg': '#2E9B58', 'linux.svg': '#E18428',
  'history_filled.svg': '#D84E78', 'star_filled.svg': '#E18428',
  'actions.svg': '#7C5CE5', 'cursor-pointer.svg': '#1976C9',
  'explore_filled.svg': '#2E9B58', 'address_book_filled.svg': '#1976C9',
  'device_group_filled.svg': '#7C5CE5', 'secure_filled.svg': '#667085',
  'opt_login.svg': '#0F9D8A', 'settings_proxy.svg': '#2E9B58',
  'settings_websocket.svg': '#1976C9', 'settings_udp.svg': '#D84E78',
  'settings_ipv6.svg': '#E18428', 'settings_remark.svg': '#1976C9',
  'settings_keepscreen.svg': '#0F9D8A', 'settings_display.svg': '#7C5CE5',
  'settings_language.svg': '#0F9D8A', 'settings_theme.svg': '#E18428',
  'settings_record.svg': '#D84E78', 'settings_record_in.svg': '#1976C9',
  'settings_record_out.svg': '#2E9B58', 'settings_shield.svg': '#7C5CE5',
  'settings_shield_check.svg': '#1976C9', 'settings_terminal.svg': '#0F9D8A',
  'settings_timer.svg': '#E18428', 'settings_tune.svg': '#D84E78',
  'settings_update.svg': '#2E9B58', 'settings_video.svg': '#7C5CE5',
  'settings_websocket_off.svg': '#667085', 'settings_wifi_off.svg': '#D84E78',
  'settings_whitelist.svg': '#0F9D8A', 'settings_power.svg': '#E18428',
  'settings_privacy.svg': '#7C5CE5', 'settings_router.svg': '#1976C9',
  'settings_monitor.svg': '#0F9D8A', 'settings_floating.svg': '#D84E78',
  'settings_folder.svg': '#D84E78', 'settings_gauge.svg': '#E18428',
  'settings_info.svg': '#1976C9', 'settings_info_circle.svg': '#7C5CE5',
  'opt_touch.svg': '#D84E78', 'opt_mouse.svg': '#1976C9',
  'opt_activity.svg': '#0F9D8A', 'opt_download.svg': '#E18428',
  'opt_upload.svg': '#2E9B58', 'opt_view.svg': '#7C5CE5',
  'opt_mic.svg': '#7C5CE5', 'opt_mute.svg': '#667085',
  'opt_rotate.svg': '#1976C9', 'opt_shield.svg': '#0F9D8A',
  'opt_timer.svg': '#E18428', 'opt_translate.svg': '#D84E78',
  'opt_move.svg': '#2E9B58', 'opt_link.svg': '#7C5CE5',
  'opt_balance.svg': '#2E9B58',
  'opt_codec.svg': '#0F9D8A', 'opt_custom.svg': '#E18428',
  'opt_fit.svg': '#D84E78', 'opt_grid.svg': '#7C5CE5',
  'opt_grip.svg': '#2E9B58', 'opt_original.svg': '#667085',
  'opt_quality.svg': '#1976C9', 'opt_speed.svg': '#0F9D8A',
  'opt_zoom.svg': '#E18428',
  'ft_phone.svg': '#1976C9', 'ft_remote.svg': '#D84E78',
  'ft_home.svg': '#0F9D8A', 'ft_back.svg': '#7C5CE5',
  'ft_up.svg': '#E18428', 'ft_sort.svg': '#2E9B58',
  'ft_copy.svg': '#1976C9', 'ft_delete.svg': '#D84E78',
  'ft_paste.svg': '#0F9D8A', 'ft_show.svg': '#7C5CE5',
  'ft_hidden.svg': '#E18428', 'ft_new_folder.svg': '#2E9B58',
  'ft_file.svg': '#1976C9', 'ft_folder.svg': '#D84E78',
  'ft_monitor.svg': '#0F9D8A',
  'nav-arrow-left.svg': '#667085', 'nav-arrow-right.svg': '#667085',
  'menu_block.svg': '#E18428',
  'menu_clipboard.svg': '#1976C9', 'menu_fingerprint.svg': '#7C5CE5',
  'menu_lock.svg': '#0F9D8A', 'menu_record.svg': '#D84E78',
  'menu_refresh.svg': '#2E9B58', 'menu_reset.svg': '#E18428',
  'menu_restart.svg': '#7C5CE5', 'menu_screenshot.svg': '#1976C9',
  'menu_switch.svg': '#D84E78', 'menu_transfer.svg': '#D84E78',
  'info_alert.svg': '#D84E78', 'info_clock.svg': '#1976C9',
  'info_code.svg': '#7C5CE5', 'info_drive.svg': '#0F9D8A',
  'info_file.svg': '#E18428', 'info_hash.svg': '#2E9B58',
  'info_layers.svg': '#D84E78', 'info_route.svg': '#7C5CE5',
  'info_target.svg': '#1976C9', 'info_trash.svg': '#667085',
};

export function getIconColor(src: string): string {
  const fileName: string = src.split('/').pop() ?? src;
  const mapped: string | undefined = ICON_COLOR_MAP[fileName];
  if (mapped) {
    return mapped;
  }
  let hash: number = 0;
  for (let i = 0; i < fileName.length; i++) {
    hash = (hash * 31 + fileName.charCodeAt(i)) | 0;
  }
  hash = hash ^ (hash >>> 13);
  hash = (Math.abs(hash) * 2654435761) | 0;
  hash = hash ^ (hash >>> 15);
  return ICON_DEFAULT_COLORS[Math.abs(hash) % ICON_DEFAULT_COLORS.length];
}

export function getIconColorByIndex(index: number): string {
  return ICON_DEFAULT_COLORS[Math.abs(index) % ICON_DEFAULT_COLORS.length];
}

export function createIconColorFilterByIndex(index: number, mode: string = ''): drawing.ColorFilter {
  return createIconColorFilter(getIconColorByIndex(index), mode);
}

export function resolveIconFillColor(src: string): string {
  const mode: string = AppStorage.get<string>('iconColorMode') || 'colorful';
  if (mode === 'colorful') return getIconColor(src);
  return mode;
}

export function createIconColorFilterForSrc(src: string, mode: string = ''): drawing.ColorFilter {
  return createIconColorFilter(getIconColor(src), mode);
}

export function createStrokeIconColorFilter(color: string): drawing.ColorFilter {
  const mode: string = AppStorage.get<string>('iconColorMode') || 'colorful';
  if (mode === 'colorful') {
    return drawing.ColorFilter.createBlendModeColorFilter(toArgbColor(color), drawing.BlendMode.SRC_IN);
  }
  return drawing.ColorFilter.createBlendModeColorFilter(toArgbColor(mode), drawing.BlendMode.SRC_IN);
}

@Component
export struct CardContainer {
  @BuilderParam content: () => void;
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .padding({ left: ThemeConfig.SPACING_XL, right: ThemeConfig.SPACING_XL })
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_XLARGE)
    
  }
}

@Builder
export function PrimaryButton(label: string, action: () => void, isLoading: boolean = false) {
  Button(isLoading ? '...' : label)
    .layoutWeight(1)
    .height(ThemeConfig.BUTTON_HEIGHT_ENTRY)
    .fontSize(ThemeConfig.FONT_SIZE_LG)
    .fontWeight(FontWeight.Medium)
    .backgroundColor(Color.Transparent)
    .fontColor(ThemeConfig.ACCENT)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .border({ width: 1.5, color: ThemeConfig.ACCENT })
    .enabled(!isLoading)
    .opacity(isLoading ? 0.65 : 1)
    .onClick(action)
}

@Builder
export function SecondaryButton(label: string, action: () => void) {
  Button(label)
    .layoutWeight(1)
    .height(ThemeConfig.BUTTON_HEIGHT_ENTRY)
    .fontSize(ThemeConfig.FONT_SIZE_LG)
    .fontWeight(FontWeight.Medium)
    .backgroundColor(Color.Transparent)
    .fontColor(ThemeConfig.TEXT_PRIMARY)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .border({
      width: 1,
      color: ThemeConfig.BORDER_SOFT
    })
    .onClick(action)
}

@Builder
export function SmallButton(label: string, action: () => void) {
  Button(label)
    .height(ThemeConfig.BUTTON_HEIGHT_SMALL)
    .fontSize(ThemeConfig.FONT_SIZE_SM)
    .backgroundColor(Color.Transparent)
    .fontColor(ThemeConfig.ACCENT)
    .borderRadius(ThemeConfig.BORDER_RADIUS_SMALL)
    .border({ width: 1, color: ThemeConfig.ACCENT })
    .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD })
    .onClick(action)
}

@Builder
export function SectionTitle(title: string, trailing?: string) {
  Row() {
    Text(title)
      .fontSize(ThemeConfig.FONT_SIZE_XXL)
      .fontWeight(FontWeight.Bold)
      .fontColor(ThemeConfig.TEXT_PRIMARY)

    if (trailing) {
      Text(trailing)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(ThemeConfig.TEXT_SECONDARY)
    }
  }
}

@Builder
export function CaptionLabel(text: string) {
  Text(text)
    .fontSize(ThemeConfig.FONT_SIZE_SM)
    .fontColor(ThemeConfig.TEXT_SECONDARY)
}

@Builder
export function InfoRow(label: string, value: string, icon: string = '') {
  Row({ space: icon.length > 0 ? 8 : 0 }) {
    if (icon.length > 0) {
      Image($rawfile(icon))
        .width(18)
        .height(18)
        .colorFilter(createIconColorFilterForSrc(icon))
    }

    Text(label)
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_SECONDARY)
      .layoutWeight(1)

    Text(value)
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_PRIMARY)
      .textAlign(TextAlign.End)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: '60%' })
  }
  .width('100%')
  .height(ThemeConfig.MENU_ITEM_HEIGHT)
  .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
}

@Builder
export function StatusBadge(text: string, isActive: boolean) {
  Text(text)
    .fontSize(ThemeConfig.FONT_SIZE_XS)
    .fontWeight(FontWeight.Medium)
    .fontColor(isActive ? ThemeConfig.SUCCESS_TEXT : ThemeConfig.WARNING_TEXT)
    .backgroundColor(isActive ? ThemeConfig.SUCCESS_BG : ThemeConfig.WARNING_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .maxLines(1)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .constraintSize({ maxWidth: 80 })
}

@Builder
export function DeviceCard(name: string, id: string, isOnline: boolean, onClick: () => void) {
  Row() {
    Row() {
      Text(name.substring(0, 1))
        .fontSize(ThemeConfig.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConfig.ACCENT)
    }
    .width(42)
    .height(42)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(ThemeConfig.ACCENT_SURFACE)
    .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)
    .margin({ right: ThemeConfig.SPACING_MD })

    Column({ space: 4 }) {
      Text(name)
        .fontSize(ThemeConfig.FONT_SIZE_LG)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConfig.TEXT_PRIMARY)
        .width('100%')

      Text(id)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(ThemeConfig.TEXT_SECONDARY)
        .width('100%')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)

    StatusBadge(isOnline ? I18nService.getInstance().translate('Online') : I18nService.getInstance().translate('Offline'), isOnline)
  }
  .width('100%')
  .padding(ThemeConfig.SPACING_LG)
  .backgroundColor(ThemeConfig.getCardBackgroundColor())
  .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
  .border({
    width: 1,
    color: ThemeConfig.BORDER_SUBTLE
  })
  .onClick(onClick)
}

@Builder
export function CustomTextInput(placeholder: string, value: string, onChange: (value: string) => void, isPassword: boolean = false) {
  TextInput({ placeholder: placeholder, text: value })
    .height(58)
    .fontSize(ThemeConfig.FONT_SIZE_ID)
    .fontWeight(FontWeight.Bold)
    .fontColor(ThemeConfig.TEXT_PRIMARY)
    .placeholderColor(ThemeConfig.TEXT_TERTIARY)
    .backgroundColor(ThemeConfig.INPUT_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .type(isPassword ? InputType.Password : InputType.Normal)
    .onChange((val: string) => {
      onChange(val);
    })
}

@Builder
export function SettingItem(label: string, value: string, onClick: () => void) {
  Row() {
    Text(label)
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_PRIMARY)
      .layoutWeight(1)

    Text(value)
      .fontSize(ThemeConfig.FONT_SIZE_SM)
      .fontColor(ThemeConfig.TEXT_SECONDARY)
      .margin({ right: ThemeConfig.SPACING_SM })

    Image($rawfile('arrow-forward-ios.svg'))
      .width(16)
      .height(16)
      .fillColor(ThemeConfig.TEXT_TERTIARY)
  }
  .width('100%')
  .padding({ top: ThemeConfig.SPACING_LG, bottom: ThemeConfig.SPACING_LG, left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
  .backgroundColor(ThemeConfig.getCardBackgroundColor())
  .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
  .border({
    width: 1,
    color: ThemeConfig.BORDER_SUBTLE
  })
  .onClick(onClick)
}

@Builder
export function ToggleSettingItem(label: string, isOpen: boolean, onToggle: (isOpen: boolean) => void) {
  Row() {
    Text(label)
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_PRIMARY)
      .layoutWeight(1)

    Toggle({ type: ToggleType.Switch, isOn: isOpen })
      .selectedColor(ThemeConfig.ACCENT)
      .switchPointColor(ThemeConfig.WHITE)
      .constraintSize({ maxHeight: 32 })
      .onChange((isOn: boolean) => {
        onToggle(isOn);
      })
  }
  .width('100%')
  .height(ThemeConfig.MENU_ITEM_HEIGHT)
  .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
}

@Component
export struct MenuToggleItem {
  @Prop label: string = '';
  @Prop isOpen: boolean = false;
  @Prop showTopBorder: boolean = false;
  onToggle: (isOpen: boolean) => void = () => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(ThemeConfig.TEXT_PRIMARY)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.isOpen })
        .selectedColor(ThemeConfig.ACCENT)
        .switchPointColor(ThemeConfig.WHITE)
        .constraintSize({ maxHeight: 32 })
        .onChange((isOn: boolean) => {
          this.onToggle(isOn);
        })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .border(this.showTopBorder ? { width: { top: 1 }, color: ThemeConfig.BORDER_SUBTLE } : { width: 0 })
  }
}

@Component
export struct MenuInfoItem {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop showTopBorder: boolean = false;

  build() {
    Row() {
      Text(this.label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(ThemeConfig.TEXT_SECONDARY)
        .layoutWeight(1)

      Text(this.value)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(ThemeConfig.TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .border(this.showTopBorder ? { width: { top: 1 }, color: ThemeConfig.BORDER_SUBTLE } : { width: 0 })
  }
}

@Component
export struct MenuActionItem {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop valueColor: string = '';
  @Prop showTopBorder: boolean = false;
  onAction: () => void = () => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(ThemeConfig.TEXT_SECONDARY)
        .layoutWeight(1)

      Text(this.value)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.valueColor.length > 0 ? this.valueColor : ThemeConfig.TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .border(this.showTopBorder ? { width: { top: 1 }, color: ThemeConfig.BORDER_SUBTLE } : { width: 0 })
    .onClick(() => { this.onAction(); })
  }
}

@Builder
export function SessionItem(name: string, id: string, time: string, onClick: () => void) {
  Row() {
    Column({ space: 5 }) {
      Text(name)
        .fontSize(ThemeConfig.FONT_SIZE_LG)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConfig.TEXT_PRIMARY)
        .width('100%')

      Text(id)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(ThemeConfig.TEXT_SECONDARY)
        .width('100%')

      Text(time)
        .fontSize(ThemeConfig.FONT_SIZE_XS)
        .fontColor(ThemeConfig.TEXT_TERTIARY)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)

    Image($rawfile('arrow-forward-ios.svg'))
      .width(16)
      .height(16)
      .fillColor(ThemeConfig.TEXT_TERTIARY)
  }
  .width('100%')
  .padding(ThemeConfig.SPACING_LG)
  .backgroundColor(ThemeConfig.getCardBackgroundColor())
  .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
  .border({
    width: 1,
    color: ThemeConfig.BORDER_SUBTLE
  })
  .onClick(onClick)
}

@Builder
export function PageHeader(title: string, subtitle?: string, showBack: boolean = false, onBack?: () => void) {
  Column({ space: ThemeConfig.SPACING_SM }) {
    Row() {
      if (showBack) {
        Row() {
          Image($rawfile('arrow.svg'))
            .width(18)
            .height(18)
            .fillColor(ThemeConfig.TEXT_PRIMARY)
            .rotate({ angle: 180 })
        }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ThemeConfig.getInputBackgroundColor())
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
          .margin({ right: ThemeConfig.SPACING_MD })
          .onClick(() => {
            if (onBack) {
              onBack();
            }
          })
      }

      Column({ space: 2 }) {
        Text(title)
          .fontSize(ThemeConfig.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConfig.TEXT_PRIMARY)
          .width('100%')

        if (subtitle) {
          Text(subtitle)
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(ThemeConfig.TEXT_SECONDARY)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
  }
  .width('100%')
  .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_SM, bottom: ThemeConfig.SPACING_MD })
  .backgroundColor(Color.Transparent)
}

@Builder
export function EmptyState(icon: Resource, message: string) {
  Column({ space: ThemeConfig.SPACING_MD }) {
    Image(icon)
      .width(38)
      .height(38)
      .fillColor(ThemeConfig.TEXT_TERTIARY)

    Text(message)
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_SECONDARY)
      .textAlign(TextAlign.Center)
  }
  .width('100%')
  .padding(ThemeConfig.SPACING_XXL)
  .backgroundColor(ThemeConfig.getCardBackgroundColor())
  .borderRadius(ThemeConfig.BORDER_RADIUS_XLARGE)
}

@Builder
export function LoadingView() {
  Column({ space: ThemeConfig.SPACING_MD }) {
    LoadingProgress()
      .width(32)
      .height(32)
      .color(ThemeConfig.ACCENT)

    Text(I18nService.getInstance().translate('Loading...'))
      .fontSize(ThemeConfig.FONT_SIZE_MD)
      .fontColor(ThemeConfig.TEXT_SECONDARY)
  }
  .width('100%')
  .height('100%')
  .justifyContent(FlexAlign.Center)
}

@Builder
export function RadioOptionRow(label: string, selected: boolean, action: () => void) {
  Row({ space: 10 }) {
    Stack() {
      Circle()
        .width(20)
        .height(20)
        .fill(Color.Transparent)
        .stroke(selected ? ThemeConfig.ACCENT : ThemeConfig.TEXT_TERTIARY)
        .strokeWidth(2)

      if (selected) {
        Circle()
          .width(12)
          .height(12)
          .fill(ThemeConfig.ACCENT)
      }
    }
    .width(20)
    .height(20)

    Text(label)
      .fontSize(14)
      .fontColor(selected ? ThemeConfig.ACCENT : ThemeConfig.TEXT_PRIMARY)
      .layoutWeight(1);
  }
  .width('100%')
  .height(44)
  .padding({ left: 16, right: 16 })
  .onClick(action);
}

@Component
export struct MenuSectionCard {
  @BuilderParam content: () => void;
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_XLARGE)
    .clip(true)
  }
}

@Builder
export function MenuRowDivider() {
  Divider()
    .width('100%')
    .height(1)
    .color(ThemeConfig.BORDER_SUBTLE)
}

@Component
export struct ToastOverlay {
  @Prop toastMessage: string = '';
  @Prop toastVisible: boolean = false;
  @Prop toastColorOffset: number = 0;
  @Prop cardBgColor: string = '#FFFFFF';
  @StorageProp('theme_CARD_BG') themeCardBg: string = '#FFFFFF';

  build() {
    if (this.toastVisible) {
      Row() {
        Text(this.toastMessage)
          .fontSize(14)
          .fontColor(getIconColorByIndex(this.toastColorOffset))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .border({ width: 1.5, color: getIconColorByIndex(this.toastColorOffset), style: BorderStyle.Solid })
      .borderRadius(8)
      .backgroundColor(this.themeCardBg)
      .shadow({ radius: 8, color: '#15000000', offsetY: 2 })
      .position({ x: '10%', y: '82%' })
      .zIndex(100)
      .animation({ duration: 200, curve: Curve.EaseInOut })
    }
  }
}
