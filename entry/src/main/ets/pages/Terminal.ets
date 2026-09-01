import { AppDataService } from '../services/AppDataService';
import { OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { TerminalService, TerminalOutputEvent } from '../services/TerminalService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { createIconColorFilterForSrc, resolveIconFillColor } from '../common/CommonComponents';
import { TerminalEmulator, TerminalRenderLine, TerminalRenderRun } from '../common/terminal/TerminalEmulator';
import inputMethod from '@ohos.inputMethod';
import router from '@ohos.router';

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

  aboutToAppear() {
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
    }
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
    try {
      this.terminalScroller.scrollEdge(Edge.Bottom);
    } catch (e) {
    }
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
    return this.themeIsDark ? '#000000' : '#FFFFFF';
  }

  private terminalForeground(): string {
    return this.themeIsDark ? '#D1FAE5' : '#1A202C';
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
      .fontColor(this.controlText())
      .backgroundColor(this.themeIsDark ? '#C0171A1E' : '#C0F0F4FA')
      .border({ width: 1, color: this.themeIsDark ? '#55FFFFFF' : '#70FFFFFF' })
      .borderRadius(8)
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
      .fontColor(this.modifierActive(modifier) ? '#071B2E' : this.controlText())
      .backgroundColor(this.modifierActive(modifier) ? '#E00A84FF' :
        (this.themeIsDark ? '#C0171A1E' : '#C0F0F4FA'))
      .border({ width: this.modifierActive(modifier) ? 2 : 1,
        color: this.modifierActive(modifier) ? '#D0FFFFFF' :
          (this.themeIsDark ? '#55FFFFFF' : '#70FFFFFF') })
      .borderRadius(8)
      .focusable(false)
      .onClick(() => this.toggleModifier(modifier))
  }

  @Builder
  private terminalOutput() {
    if (this.terminalLines.length === 0) {
      Text(this.terminalText)
        .width('100%')
        .textAlign(TextAlign.Start)
        .fontFamily('monospace')
        .fontSize(13)
        .lineHeight(15)
        .letterSpacing(-0.52)
        .fontColor(this.terminalForeground())
        .copyOption(CopyOptions.LocalDevice)
    } else {
      Text() {
        ForEach(this.terminalLines, (line: TerminalRenderLine, lineIndex: number) => {
          ForEach(line.runs, (run: TerminalRenderRun) => {
            Span(run.text)
              .fontColor(run.cursor ? this.theme_ACCENT : this.terminalForeground())
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
      .fontFamily('monospace')
      .fontSize(13)
      .lineHeight(15)
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
        .padding({ left: 2, right: 2, top: 0, bottom: 66 })
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

      Column()
        .width('100%')
        .height(this.avoidStatusBarHeight + 50)
        .linearGradient({
          angle: 180,
          colors: this.themeIsDark
            ? [['#BB000000', 0.0], ['#99000000', 0.3], ['#55000000', 0.7], ['#00000000', 1.0]]
            : [['#CCF8FAFC', 0.0], ['#AAF8FAFC', 0.3], ['#55F8FAFC', 0.7], ['#00F8FAFC', 1.0]]
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
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.controlText())
            Text(this.sessionStatus)
              .fontSize(12)
              .fontColor(this.theme_ACCENT)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 8, top: 8 })
        .backgroundColor('#00000000')

        Blank()

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
