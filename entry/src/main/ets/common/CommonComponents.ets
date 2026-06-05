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

export function createStrokeIconColorFilter(color: string): drawing.ColorFilter {
  return drawing.ColorFilter.createBlendModeColorFilter(toArgbColor(color), drawing.BlendMode.SRC_IN);
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
    .backgroundColor(ThemeConfig.ACCENT)
    .fontColor(ThemeConfig.ACCENT_TEXT)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
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
    .backgroundColor(ThemeConfig.SECONDARY_BTN_BG)
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
    .backgroundColor(ThemeConfig.ACCENT)
    .fontColor(ThemeConfig.ACCENT_TEXT)
    .borderRadius(ThemeConfig.BORDER_RADIUS_SMALL)
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
        .colorFilter(drawing.ColorFilter.createBlendModeColorFilter(toArgbColor(ThemeConfig.TEXT_TERTIARY), drawing.BlendMode.SRC_IN))
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
