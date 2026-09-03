import { AppDataService } from '../services/AppDataService';
import { OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { TerminalService, TerminalOutputEvent } from '../services/TerminalService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { createIconColorFilterForSrc, resolveIconFillColor } from '../common/CommonComponents';
import { TerminalEmulator, TerminalRenderLine, TerminalRenderRun } from '../common/terminal/TerminalEmulator';
import inputMethod from '@ohos.inputMethod';
import router from '@ohos.router';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';

@Entry
@Component
struct Terminal {
  private appData: AppDataService = AppDataService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private terminalService: TerminalService = TerminalService.getInstance();
  private terminalId: number = -1;
  private imeController: TextInputController = new TextInputController();
  private imePrevious: string = '\u200B';
  private imeWakeGeneration: number = 0;
  private emulator: TerminalEmulator = new TerminalEmulator(120, 30);
  private terminalScroller: Scroller = new Scroller();
  private sessionEventListener = (event: OfficialSessionEvent): void => {
    this.handleOfficialEvent(event);
  };
  private outputListener = (event: TerminalOutputEvent): void => {
    this.handleTerminalOutput(event);
  };

  @StorageLink('iconColorMode') iconColorMode: string = 'colorful';@State deviceId: string = '';
  @State deviceName: string = '';
  @State commandInput: string = '';
  @State terminalLines: TerminalRenderLine[] = [];
  @State terminalText: string = '';
  @State sessionStatus: string = '';
  @State ctrlPending: boolean = false;
  @State altPending: boolean = false;
  @State shiftPending: boolean = false;
  @State imeText: string = '\u200B';
  @State manualScrollBrowsing: boolean = false;
  private terminalTouching: boolean = false;
  private terminalTouchStartX: number = 0;
  private terminalTouchStartY: number = 0;
  private terminalTouchMoved: boolean = false;
  private terminalStableHeight: number = 0;
  private terminalStableWidth: number = 0;

  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageLink('avoidKeyboardHeight') avoidKeyboardHeight: number = 0;
  @StorageProp('themeIsDark') themeIsDark: boolean = true;
  @StorageLink('terminalThemeMode') terminalThemeMode: string = 'app';
  @StorageLink('terminalFontColorMode') @Watch('onTerminalFontColorChanged') terminalFontColorMode: string = 'colorful';
  @StorageLink('terminalFontSizeMode') @Watch('onTerminalFontSizeChanged') terminalFontSizeMode: string = 'medium';
  @StorageLink('terminalFontFamily') terminalFontFamily: string = 'monospace';
  @StorageLink('terminalExtraKeysEnabled') terminalExtraKeysEnabled: boolean = true;
  @State sessionTerminalFontColor: string = '#38BDF8';

  aboutToAppear() {
    this.chooseSessionTerminalFontColor();
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.terminalText = this.lt('Waiting for terminal session...');
    this.sessionStatus = this.lt('Disconnected');
    const params = this.getRouteParams();
    if (params && params['deviceId']) {
      this.deviceId = params['deviceId'];
    }
    this.deviceName = this.appData.getDisplayName(this.deviceId);
    this.officialBridge.addEventListener(this.sessionEventListener);
    this.terminalService.addOutputListener(this.outputListener);
    this.terminalId = this.terminalService.openTerminal(this.deviceId, 30, 120) ?? -1;
    if (this.terminalId === -1) {
      this.terminalText = this.lt('Terminal entry unavailable');
      this.sessionStatus = this.lt('Failed to connect');
    } else {
      this.sessionStatus = this.lt('Connecting');
    }
  }

  aboutToDisappear() {
    this.officialBridge.removeEventListener(this.sessionEventListener);
    this.terminalService.removeOutputListener(this.outputListener);
    if (this.terminalId !== -1) {
      this.terminalService.closeTerminal(this.terminalId);
      this.terminalId = -1;
    }
    this.officialBridge.requestSessionClose();
  }

  private lt(key: string): string {
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nVersion = this.i18nRefresh;
  }

  private getRouteParams(): Record<string, string> | null {
    try {
      const params = router.getParams() as Record<string, string>;
      return params ?? null;
    } catch (e) {
      return null;
    }
  }

  private handleOfficialEvent(event: OfficialSessionEvent): void {
    if (event.kind === 'session-connected') {
      this.sessionStatus = this.lt('Connected');
    } else if (event.kind === 'session-closed' || event.kind === 'closed') {
      this.sessionStatus = this.lt('Disconnected');
    }
  }

  private handleTerminalOutput(event: TerminalOutputEvent): void {
    if (event.terminalId !== this.terminalId || event.data.length === 0) {
      return;
    }
    this.manualScrollBrowsing = false;
    this.emulator.consume(event.data);
    this.terminalText = this.emulator.render();
    this.terminalLines = this.emulator.renderLines();
    this.scrollToLatest();
  }

  private scrollToLatest(): void {
    if (this.manualScrollBrowsing) return;
    setTimeout((): void => {
      const meaningfulText: string = this.terminalText.replace(/\s+$/, '');
      const lineCount: number = Math.max(1, meaningfulText.split('\n').length);
      const headerInset: number = this.avoidStatusBarHeight + 54;
      const bottomInset: number = this.terminalExtraKeysEnabled ? 76 : 12;
      const visibleHeight: number = Math.max(1,
        this.terminalStableHeight - this.avoidKeyboardHeight - headerInset - bottomInset);
      const outputHeight: number = lineCount * this.terminalLineHeight();
      try {
        this.terminalScroller.scrollEdge(outputHeight > visibleHeight ? Edge.Bottom : Edge.Top);
      } catch (e) {
      }
    }, 0);
  }

  private goBack(): void {
    router.back();
  }

  private sendTerminalInput(data: string): void {
    if (this.terminalId !== -1) {
      this.terminalService.sendInput(this.terminalId, data);
    }
  }

  private onImeTextChanged(value: string): void {
    if (value.length > this.imePrevious.length) {
      const diff = value.substring(this.imePrevious.length);
      this.sendTerminalInput(this.applyCtrlModifier(diff));
    } else if (value.length < this.imePrevious.length) {
      const deleteCount = this.imePrevious.length - value.length;
      for (let i = 0; i < deleteCount; i++) {
        this.sendTerminalInput('\u007f');
      }
    }
    this.imePrevious = value;
    if (value.length === 0 || value === '\u200B') {
      this.imeText = '\u200B';
      this.imePrevious = '\u200B';
    }
  }

  private applyCtrlModifier(text: string): string {
    if (!this.ctrlPending) return text;
    this.ctrlPending = false;
    let result = '';
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      const code = text.charCodeAt(i);
      if (code >= 97 && code <= 122) {
        result += String.fromCharCode(code - 96);
      } else if (code >= 65 && code <= 90) {
        result += String.fromCharCode(code - 64);
      } else {
        result += ch;
      }
    }
    return result;
  }

  private sendTerminalSpecial(key: string): void {
    const modifier: number = 1 + (this.shiftPending ? 1 : 0) + (this.altPending ? 2 : 0) + (this.ctrlPending ? 4 : 0);
    this.ctrlPending = false;
    this.altPending = false;
    this.shiftPending = false;
    const modified: boolean = modifier > 1;
    let sequence: string = '';
    if (key === 'Enter') sequence = '\r';
    else if (key === 'Backspace') sequence = '\u007f';
    else if (key === 'Esc') sequence = '\u001b';
    else if (key === 'Tab') sequence = modified ? '\u001b[Z' : '\t';
    else if (key === 'Up' || key === 'Down' || key === 'Right' || key === 'Left' ||
      key === 'Home' || key === 'End') {
      let suffix: string = 'A';
      if (key === 'Down') suffix = 'B';
      else if (key === 'Right') suffix = 'C';
      else if (key === 'Left') suffix = 'D';
      else if (key === 'Home') suffix = 'H';
      else if (key === 'End') suffix = 'F';
      sequence = modified ? '\u001b[1;' + modifier.toString() + suffix : '\u001b[' + suffix;
    } else if (key === 'Insert' || key === 'Delete' || key === 'PageUp' || key === 'PageDown') {
      let number: string = '2';
      if (key === 'Delete') number = '3';
      else if (key === 'PageUp') number = '5';
      else if (key === 'PageDown') number = '6';
      sequence = '\u001b[' + number + (modified ? ';' + modifier.toString() : '') + '~';
    } else if (key.substring(0, 1) === 'F') {
      const fn: number = Number.parseInt(key.substring(1));
      if (fn >= 1 && fn <= 4) {
        const suffixes: string[] = ['P', 'Q', 'R', 'S'];
        sequence = modified ? '\u001b[1;' + modifier.toString() + suffixes[fn - 1] : '\u001bO' + suffixes[fn - 1];
      } else {
        const codes: string[] = ['15', '17', '18', '19', '20', '21', '23', '24'];
        const index: number = fn - 5;
        if (index >= 0 && index < codes.length) {
          sequence = '\u001b[' + codes[index] + (modified ? ';' + modifier.toString() : '') + '~';
        }
      }
    }
    if (sequence.length > 0) {
      this.sendTerminalInput(sequence);
    }
  }

  private focusTerminalIme(): void {
    const generation: number = ++this.imeWakeGeneration;
    try {
      const focusController = this.getUIContext().getFocusController();
      if (this.avoidKeyboardHeight > 0) {
        focusController.requestFocus('terminal-ime-input');
        return;
      }
      focusController.clearFocus();
      setTimeout(() => {
        if (generation !== this.imeWakeGeneration) return;
        try {
          focusController.requestFocus('terminal-ime-input');
          setTimeout(() => {
            if (generation !== this.imeWakeGeneration) return;
            const controller = inputMethod.getController();
            controller.showTextInput().catch(() => {});
            setTimeout(() => {
              if (generation !== this.imeWakeGeneration) return;
              controller.showTextInput().catch(() => {});
            }, 120);
          }, 40);
        } catch (e) {
        }
      }, 20);
    } catch (e) {
    }
  }

  private shellBg(): string {
    return this.terminalIsDark() ? '#000000' : '#FFFFFF';
  }

  private terminalIsDark(): boolean {
    if (this.terminalThemeMode === 'app') return this.themeIsDark;
    return this.terminalThemeMode === 'dark';
  }

  private terminalFontSize(): number {
    if (this.terminalFontSizeMode === 'extraSmall') return 9.2;
    if (this.terminalFontSizeMode === 'small') return 10.5;
    if (this.terminalFontSizeMode === 'large') return 13;
    return 11.5;
  }

  private terminalLineHeight(): number {
    if (this.terminalFontSizeMode === 'extraSmall') return 11;
    if (this.terminalFontSizeMode === 'small') return 12.5;
    if (this.terminalFontSizeMode === 'large') return 15;
    return 13.5;
  }

  private terminalForeground(color: string): string {
    if (this.terminalIsDark()) return color;
    if (color === '#D1FAE5' || color === '#FFFFFF' || color === '#E5E5E5' || color === '#F5F543') {
      return '#111827';
    }
    return color;
  }

  private configuredTerminalForeground(fallback: string): string {
    if (this.terminalFontColorMode === 'colorful') return this.sessionTerminalFontColor;
    if (!this.terminalIsDark() && this.terminalFontColorMode === '#E5E7EB') return '#374151';
    return this.terminalFontColorMode.length > 0 ? this.terminalFontColorMode : this.terminalForeground(fallback);
  }

  private chooseSessionTerminalFontColor(): void {
    const darkColors: string[] = ['#38BDF8', '#34D399', '#A78BFA', '#FB923C', '#F472B6', '#E5E7EB'];
    const lightColors: string[] = ['#0369A1', '#047857', '#6D28D9', '#C2410C', '#BE185D', '#1F2937'];
    const colors: string[] = this.terminalIsDark() ? darkColors : lightColors;
    const candidates: string[] = colors.filter((color: string) => color !== this.sessionTerminalFontColor);
    const available: string[] = candidates.length > 0 ? candidates : colors;
    this.sessionTerminalFontColor = available[Math.floor(Math.random() * available.length)];
  }

  private onTerminalFontColorChanged(): void {
    if (this.terminalFontColorMode === 'colorful') this.chooseSessionTerminalFontColor();
  }

  private onTerminalFontSizeChanged(): void {
    if (this.terminalStableWidth <= 0 || this.terminalStableHeight <= 0) return;
    this.updateTerminalSize(this.terminalStableWidth,
      Math.max(1, this.terminalStableHeight - this.avoidKeyboardHeight));
  }

  private updateTerminalSize(width: number, height: number): void {
    if (width <= 0 || height <= 0) return;
    if (this.terminalStableWidth > 0 && Math.abs(width - this.terminalStableWidth) > this.terminalStableWidth * 0.2) {
      this.terminalStableHeight = 0;
    }
    this.terminalStableWidth = width;
    this.terminalStableHeight = Math.max(this.terminalStableHeight, height + this.avoidKeyboardHeight);
  }

  private controlBg(): string {
    return this.themeIsDark ? '#111827' : '#F8FAFC';
  }

  private controlText(): string {
    return this.themeIsDark ? '#F8FAFC' : '#111827';
  }

  private modifierActive(modifier: string): boolean {
    if (modifier === 'ctrl') return this.ctrlPending;
    if (modifier === 'alt') return this.altPending;
    return this.shiftPending;
  }

  private toggleModifier(modifier: string): void {
    if (modifier === 'ctrl') this.ctrlPending = !this.ctrlPending;
    else if (modifier === 'alt') this.altPending = !this.altPending;
    else this.shiftPending = !this.shiftPending;
    this.focusTerminalIme();
  }

  @Builder
  TerminalKey(label: string, action: () => void) {
    Button(label)
      .height(36)
      .padding({ left: 13, right: 13 })
      .fontSize(13)
      .fontColor(this.theme_TEXT_PRIMARY)
      .backgroundColor(this.themeIsDark ? '#C0171A1E' : '#C0F0F4FA')
      .border({ width: 1, color: this.themeIsDark ? '#55FFFFFF' : '#70FFFFFF' })
      .borderRadius(8)
      .shadow({ radius: 5, color: this.themeIsDark ? '#44000000' : '#18000000', offsetY: 2 })
      .focusable(false)
      .onClick(action)
  }

  @Builder
  TerminalModifierKey(label: string, modifier: string) {
    Button(label)
      .height(36)
      .padding({ left: 13, right: 13 })
      .fontSize(13)
      .fontWeight(this.modifierActive(modifier) ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.modifierActive(modifier) ? '#071B2E' : this.theme_TEXT_PRIMARY)
      .backgroundColor(this.modifierActive(modifier) ? '#E00A84FF' :
        (this.themeIsDark ? '#C0171A1E' : '#C0F0F4FA'))
      .border({ width: this.modifierActive(modifier) ? 2 : 1,
        color: this.modifierActive(modifier) ? '#D0FFFFFF' :
          (this.themeIsDark ? '#55FFFFFF' : '#70FFFFFF') })
      .borderRadius(8)
      .shadow({ radius: this.modifierActive(modifier) ? 8 : 5,
        color: this.modifierActive(modifier) ? '#660A84FF' :
          (this.themeIsDark ? '#44000000' : '#18000000'), offsetY: 2 })
      .focusable(false)
      .onClick(() => this.toggleModifier(modifier))
  }

  @Builder
  private terminalOutput() {
    if (this.terminalLines.length === 0) {
      Text(this.terminalText)
        .width('100%')
        .textAlign(TextAlign.Start)
        .fontFamily(this.terminalFontFamily)
        .fontSize(this.terminalFontSize())
        .lineHeight(this.terminalLineHeight())
        .letterSpacing(-0.52)
        .fontColor(this.configuredTerminalForeground('#D1FAE5'))
        .copyOption(CopyOptions.LocalDevice)
    } else {
      Text() {
        ForEach(this.terminalLines, (line: TerminalRenderLine, lineIndex: number) => {
          ForEach(line.runs, (run: TerminalRenderRun) => {
            Span(run.text)
              .fontColor(run.cursor ? '#0A84FF' : this.configuredTerminalForeground(run.foreground))
              .backgroundColor(Color.Transparent)
              .fontWeight(run.bold ? FontWeight.Bold : FontWeight.Normal)
              .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
              .decoration({
                type: run.underline ? TextDecorationType.Underline :
                  (run.strikeThrough ? TextDecorationType.LineThrough : TextDecorationType.None)
              })
              .opacity(run.dim ? 0.68 : 1.0)
          })
          if (lineIndex < this.terminalLines.length - 1) {
            Span('\n')
          }
        })
      }
      .width('100%')
      .textAlign(TextAlign.Start)
      .fontFamily(this.terminalFontFamily)
      .fontSize(this.terminalFontSize())
      .lineHeight(this.terminalLineHeight())
      .letterSpacing(-0.62)
      .copyOption(CopyOptions.LocalDevice)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        TextInput({ text: this.imeText })
          .key('terminal-ime-input')
          .width(2)
          .height(2)
          .opacity(0.01)
          .position({ x: 4, y: 4 })
          .backgroundColor(Color.Transparent)
          .fontColor(Color.Transparent)
          .caretColor(Color.Transparent)
          .defaultFocus(true)
          .focusable(true)
          .enterKeyType(EnterKeyType.Send)
          .onClick(() => this.focusTerminalIme())
          .onChange((value: string) => this.onImeTextChanged(value))
          .onSubmit((_enterKey: EnterKeyType, event: SubmitEvent) => {
            event.keepEditableState();
            this.sendTerminalInput('\r');
          })

        Scroll(this.terminalScroller) {
          Column() {
            Blank().height(this.avoidStatusBarHeight + 54)
            this.terminalOutput()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 2, right: 2, top: 0,
          bottom: this.terminalExtraKeysEnabled ? 76 : 12 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.terminalTouching = true;
            this.terminalTouchMoved = false;
            if (event.touches.length > 0) {
              this.terminalTouchStartX = event.touches[0].x;
              this.terminalTouchStartY = event.touches[0].y;
            }
          } else if (event.type === TouchType.Move && event.touches.length > 0) {
            const deltaX: number = Math.abs(event.touches[0].x - this.terminalTouchStartX);
            const deltaY: number = Math.abs(event.touches[0].y - this.terminalTouchStartY);
            if (deltaX > 8 || deltaY > 8) {
              this.terminalTouchMoved = true;
              this.manualScrollBrowsing = true;
            }
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.terminalTouching = false;
            if (event.type === TouchType.Up && !this.terminalTouchMoved) this.focusTerminalIme();
          }
        })
      }
      .height('100%')
      .width('100%')
      .backgroundColor(this.shellBg())
      .onAreaChange((_oldValue, newValue) => {
        this.updateTerminalSize(Number(newValue.width), Number(newValue.height));
      })

      Column()
        .width('100%')
        .height(this.avoidStatusBarHeight + 50)
        .linearGradient({
          angle: 180,
          colors: this.themeIsDark
            ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ['#99171A1E', 0.12], ['#88171A1E', 0.22],
              ['#77171A1E', 0.35], ['#66171A1E', 0.52], ['#55171A1E', 0.72], ['#33171A1E', 0.88],
              ['#00171A1E', 1.0]]
            : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ['#A0F0F4FA', 0.12], ['#90F0F4FA', 0.22],
              ['#80F0F4FA', 0.35], ['#70F0F4FA', 0.52], ['#50F0F4FA', 0.72], ['#30F0F4FA', 0.88],
              ['#00F0F4FA', 1.0]]
        })
        .position({ x: 0, y: 0 })
        .zIndex(1)

      Column() {
        Row() {
          Image($rawfile('close.svg'))
            .width(24)
            .height(24)
            .colorFilter(createIconColorFilterForSrc('close.svg', this.iconColorMode))
            .onClick(() => this.goBack())

          Column() {
            Text(this.deviceName || this.lt('Terminal'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme_TEXT_PRIMARY)
            Text(this.sessionStatus)
              .fontSize(12)
              .fontColor(this.controlText())
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 8, top: 8 })
        .backgroundColor('#00000000')

        Blank()

        if (this.terminalExtraKeysEnabled) {
          Scroll() {
            Row({ space: 6 }) {
              this.TerminalModifierKey('Ctrl', 'ctrl')
              this.TerminalModifierKey('Alt', 'alt')
              this.TerminalModifierKey('Shift', 'shift')
              this.TerminalKey('Esc', () => this.sendTerminalSpecial('Esc'))
              this.TerminalKey('Tab', () => this.sendTerminalSpecial('Tab'))
              this.TerminalKey('Enter', () => this.sendTerminalSpecial('Enter'))
              this.TerminalKey('Backspace', () => this.sendTerminalSpecial('Backspace'))
              this.TerminalKey('Insert', () => this.sendTerminalSpecial('Insert'))
              this.TerminalKey('Delete', () => this.sendTerminalSpecial('Delete'))
              this.TerminalKey('Home', () => this.sendTerminalSpecial('Home'))
              this.TerminalKey('End', () => this.sendTerminalSpecial('End'))
              this.TerminalKey('PgUp', () => this.sendTerminalSpecial('PageUp'))
              this.TerminalKey('PgDn', () => this.sendTerminalSpecial('PageDown'))
              this.TerminalKey('←', () => this.sendTerminalSpecial('Left'))
              this.TerminalKey('↑', () => this.sendTerminalSpecial('Up'))
              this.TerminalKey('↓', () => this.sendTerminalSpecial('Down'))
              this.TerminalKey('→', () => this.sendTerminalSpecial('Right'))
              this.TerminalKey('F1', () => this.sendTerminalSpecial('F1'))
              this.TerminalKey('F2', () => this.sendTerminalSpecial('F2'))
              this.TerminalKey('F3', () => this.sendTerminalSpecial('F3'))
              this.TerminalKey('F4', () => this.sendTerminalSpecial('F4'))
              this.TerminalKey('F5', () => this.sendTerminalSpecial('F5'))
              this.TerminalKey('F6', () => this.sendTerminalSpecial('F6'))
              this.TerminalKey('F7', () => this.sendTerminalSpecial('F7'))
              this.TerminalKey('F8', () => this.sendTerminalSpecial('F8'))
              this.TerminalKey('F9', () => this.sendTerminalSpecial('F9'))
              this.TerminalKey('F10', () => this.sendTerminalSpecial('F10'))
              this.TerminalKey('F11', () => this.sendTerminalSpecial('F11'))
              this.TerminalKey('F12', () => this.sendTerminalSpecial('F12'))
            }
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          }
          .width('100%')
          .height(54)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .backgroundColor(Color.Transparent)
          .padding({ bottom: 4 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.avoidStatusBarHeight, bottom: this.avoidNavigationBarHeight })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.shellBg())
  }
}
