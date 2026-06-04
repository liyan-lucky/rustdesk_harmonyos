import { NativeRustDeskBridge } from '../services/NativeRustDeskBridge';
import { ThemeConfig } from '../common/ThemeConfig';
import { I18nService } from '../services/I18nService';

const HARMONY_KEY_SHIFT: number = 1;
const HARMONY_KEY_CTRL: number = 2;
const HARMONY_KEY_ALT: number = 4;
const HARMONY_KEY_META: number = 8;

interface ModifierKeyItem {
  name: string;
  mask: number;
  color: string;
}

interface FunctionKeyItem {
  name: string;
  code: number;
}

@Component
export struct KeyboardToolbar {
  @Link modifiers: number;
  @State private textInput: string = '';
  @State private showTextInput: boolean = false;
  @State private modifierKeys: ModifierKeyItem[] = [];
  @State private functionKeys: FunctionKeyItem[] = [];
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  aboutToAppear(): void {
    this.modifierKeys = [
      { name: this.lt('Control'), mask: HARMONY_KEY_CTRL, color: this.theme_ACCENT },
      { name: 'Alt', mask: HARMONY_KEY_ALT, color: this.theme_ACCENT },
      { name: 'Shift', mask: HARMONY_KEY_SHIFT, color: this.theme_ACCENT },
      { name: this.lt('System'), mask: HARMONY_KEY_META, color: this.theme_ACCENT }
    ];
    this.functionKeys = [
      { name: 'Esc', code: 27 },
      { name: 'Tab', code: 9 },
      { name: 'F1', code: 112 },
      { name: 'F2', code: 113 },
      { name: 'F3', code: 114 },
      { name: 'F4', code: 115 },
      { name: 'F5', code: 116 },
      { name: 'F6', code: 117 },
      { name: 'F7', code: 118 },
      { name: 'F8', code: 119 },
      { name: 'F9', code: 120 },
      { name: 'F10', code: 121 },
      { name: 'F11', code: 122 },
      { name: 'F12', code: 123 },
      { name: 'Ins', code: 45 },
      { name: 'Del', code: 46 },
      { name: 'Home', code: 36 },
      { name: 'End', code: 35 },
      { name: 'PgUp', code: 33 },
      { name: 'PgDn', code: 34 }
    ];
  }
  @StorageProp('theme_ACCENT') @Watch('onAccentChanged') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_INACTIVE_BG') theme_INACTIVE_BG: string = '#3A4355';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_WHITE') theme_WHITE: string = '#FFFFFF';

  private onAccentChanged(): void {
    for (const key of this.modifierKeys) {
      key.color = this.theme_ACCENT;
    }
  }

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nVersion = this.i18nRefresh;
    this.modifierKeys = [
      { name: this.lt('Control'), mask: HARMONY_KEY_CTRL, color: this.theme_ACCENT },
      { name: 'Alt', mask: HARMONY_KEY_ALT, color: this.theme_ACCENT },
      { name: 'Shift', mask: HARMONY_KEY_SHIFT, color: this.theme_ACCENT },
      { name: this.lt('System'), mask: HARMONY_KEY_META, color: this.theme_ACCENT }
    ];
  }

  build() {
    Column({ space: ThemeConfig.SPACING_MD }) {
      this.buildModifierBar();
      this.buildFunctionKeyBar();
      this.buildSpecialCombosBar();
      this.buildTextInputArea();
    }
    .width('100%')
    .padding(ThemeConfig.SPACING_MD)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    ;
  }

  @Builder
  private buildModifierBar() {
    Row({ space: 8 }) {
      ForEach(this.modifierKeys, (key: ModifierKeyItem) => {
        Button(key.name)
          .width(60)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isModifierActive(key.mask) ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
          .backgroundColor(this.isModifierActive(key.mask) ? key.color : this.theme_INACTIVE_BG)
          .borderRadius(8)
          .onClick(() => {
            this.toggleModifier(key.mask);
          });
      }, (key: ModifierKeyItem) => key.name);
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private buildFunctionKeyBar() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      ForEach(this.functionKeys, (key: FunctionKeyItem) => {
        Button(key.name)
          .width(key.name.length > 2 ? 44 : 40)
          .height(36)
          .fontSize(12)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_WHITE)
          .border({ width: 1, color: this.theme_BORDER_SOFT })
          .borderRadius(6)
          .margin(2)
          .onClick(() => {
            this.sendKey(key.code);
          });
      }, (key: FunctionKeyItem) => key.name);
    }
    .width('100%');
  }

  @Builder
  private buildSpecialCombosBar() {
    Row({ space: 8 }) {
      Button(this.lt('Send Ctrl+Alt+Del'))
        .height(40)
        .fontSize(13)
        .fontColor(this.theme_CONTRAST_TEXT)
        .backgroundColor(this.theme_ERROR_TEXT)
        .borderRadius(8)
        .onClick(() => {
          this.sendCtrlAltDel();
        });

      Button(this.lt('Lock screen'))
        .height(40)
        .fontSize(13)
        .fontColor(this.theme_ACCENT_TEXT)
        .backgroundColor(this.theme_ACCENT)
        .borderRadius(8)
        .onClick(() => {
          this.sendLockScreen();
        });

      Button(this.lt('Clear'))
        .height(40)
        .fontSize(13)
        .fontColor(this.theme_TEXT_PRIMARY)
        .backgroundColor(this.theme_INACTIVE_BG)
        .borderRadius(8)
        .onClick(() => {
          this.modifiers = 0;
        });
    }
    .width('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private buildTextInputArea() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Button(this.showTextInput ? this.lt('Hide') : this.lt('Input'))
          .height(36)
          .fontSize(13)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INACTIVE_BG)
          .borderRadius(8)
          .onClick(() => {
            this.showTextInput = !this.showTextInput;
          });

        if (this.showTextInput) {
          Button(this.lt('Enter'))
            .height(36)
            .fontSize(13)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              this.sendKey(13);
            });
        }
      }
      .width('100%');

      if (this.showTextInput) {
        TextInput({ text: this.textInput, placeholder: this.lt('Enter text...') })
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor(this.theme_WHITE)
          .border({ width: 1, color: this.theme_BORDER_SOFT })
          .borderRadius(8)
          .onChange((value: string) => {
            if (value.length > this.textInput.length) {
              const newChars = value.substring(this.textInput.length);
              for (let i = 0; i < newChars.length; i++) {
                this.sendChar(newChars.charCodeAt(i));
              }
            }
            this.textInput = value;
          })
          .onSubmit(() => {
            this.sendKey(13);
            this.textInput = '';
          });
      }
    }
    .width('100%');
  }

  private isModifierActive(mask: number): boolean {
    return (this.modifiers & mask) !== 0;
  }

  private toggleModifier(mask: number): void {
    if (this.isModifierActive(mask)) {
      this.modifiers = this.modifiers & ~mask;
    } else {
      this.modifiers = this.modifiers | mask;
    }
  }

  private sendKey(keyCode: number): void {
    const success = NativeRustDeskBridge.sendKeyboardInput(keyCode, true, this.modifiers);
    if (success) {
      NativeRustDeskBridge.sendKeyboardInput(keyCode, false, this.modifiers);
    }
  }

  private sendChar(charCode: number): void {
    if (charCode >= 32 && charCode <= 126) {
      const success = NativeRustDeskBridge.sendKeyboardInput(charCode, true, this.modifiers);
      if (success) {
        NativeRustDeskBridge.sendKeyboardInput(charCode, false, this.modifiers);
      }
    }
  }

  private sendCtrlAltDel(): void {
    NativeRustDeskBridge.sendCtrlAltDel();
  }

  private sendLockScreen(): void {
    NativeRustDeskBridge.sendKeyboardInput(162, true, HARMONY_KEY_CTRL | HARMONY_KEY_ALT);
    NativeRustDeskBridge.sendKeyboardInput(76, true, 0);
    NativeRustDeskBridge.sendKeyboardInput(76, false, 0);
    NativeRustDeskBridge.sendKeyboardInput(162, false, HARMONY_KEY_CTRL | HARMONY_KEY_ALT);
  }
}
