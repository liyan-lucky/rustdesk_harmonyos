import { AppDataService } from '../services/AppDataService';
import { OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { TerminalService, TerminalOutputEvent } from '../services/TerminalService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import inputMethod from '@ohos.inputMethod';

interface TerminalResponsePayload {
  type?: string;
  success?: boolean;
  message?: string;
}

@Entry
@Component
struct Terminal {
  private appData: AppDataService = AppDataService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private terminalService: TerminalService = TerminalService.getInstance();
  private terminalId: number = -1;
  private imeController: TextAreaController = new TextAreaController();
  private imePrevious: string = '\u200B';
  private imeWakeGeneration: number = 0;
  private sessionEventListener = (event: OfficialSessionEvent): void => {
    this.handleOfficialEvent(event);
  };
  private outputListener = (event: TerminalOutputEvent): void => {
    this.handleTerminalOutput(event);
  };

  @State deviceId: string = '';
  @State deviceName: string = '';
  @State commandInput: string = '';
  @State outputLines: string[] = [];
  @State sessionStatus: string = '';
  @State keyboardVisible: boolean = false;
  @State activeKey: string = '';
  @State imeText: string = '\u200B';
  @State pendingTerminalInput: string = '';

  aboutToAppear() {
    this.outputLines = [this.lt('Waiting for terminal session...')];
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
      this.outputLines = this.outputLines.concat([this.lt('Terminal entry unavailable')]);
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

  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageLink('avoidKeyboardHeight') avoidKeyboardHeight: number = 0;

  @StorageProp('themeIsDark') themeIsDark: boolean = true;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.buildTerminalScreen()
        this.buildCustomKeyboard()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .padding({ bottom: this.avoidKeyboardHeight > 0 ? this.avoidKeyboardHeight : 0 })

      this.buildHeader()

      this.buildTerminalImeProxy()

      Column()
        .width('100%')
        .height(this.avoidStatusBarHeight + 96)
        .linearGradient({
          angle: 180,
          colors: [['#CC000000', 0.0], ['#99000000', 0.3], ['#55000000', 0.7], ['#00000000', 1.0]]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildHeader() {
    Row() {
      Image($rawfile('close.svg'))
        .width(24)
        .height(24)
        .fillColor('#FFFFFF')
        .onClick(() => this.goBack())

      Text(this.lt('Terminal'))
        .fontSize(18)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .margin({ left: 12 })
        .layoutWeight(1)

      Text(this.sessionStatus)
        .fontSize(12)
        .fontColor(this.theme_ACCENT)
    }
    .width('100%')
    .height(96)
    .padding({ left: 16, right: 16, top: this.avoidStatusBarHeight, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildTerminalScreen() {
    Scroll() {
      Column() {
        ForEach(this.outputLines, (line: string, index: number) => {
          Text(line)
            .fontSize(13)
            .fontColor('#CCCCCC')
            .fontFamily('monospace')
            .width('100%')
            .textAlign(TextAlign.Start)
            .copyOption(CopyOptions.LocalDevice)
            .onClick(() => {
              this.keyboardVisible = true;
              this.requestTerminalKeyboard(true);
            })
        }, (line: string, index: number) => `${index}-${line}`)
        if (this.pendingTerminalInput.length > 0) {
          Text(`› ${this.pendingTerminalInput}`)
            .fontSize(13)
            .fontColor('#E5E7EB')
            .fontFamily('monospace')
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 96, bottom: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.BottomStart)
    .onClick(() => {
      this.keyboardVisible = true;
      this.requestTerminalKeyboard();
    })
  }

  @Builder
  private buildCustomKeyboard() {
    if (this.keyboardVisible) {
      Column() {
        Scroll() {
          Row({ space: 6 }) {
            this.buildKey('Esc', 48)
            this.buildKey('/', 44)
            this.buildKey('|', 44)
            this.buildKey('Home', 58)
            this.buildKey('↑', 44, 18)
            this.buildKey('End', 48)
            this.buildKey('PgUp', 58)
          }
          .padding({ left: 8, right: 8, top: 6, bottom: 3 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Scroll() {
          Row({ space: 6 }) {
            this.buildKey('Tab', 48)
            this.buildKey('Ctrl+C', 72, 13)
            this.buildKey('~', 44)
            this.buildKey('←', 44, 18)
            this.buildKey('↓', 44, 18)
            this.buildKey('→', 44, 18)
            this.buildKey('PgDn', 58)
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 6 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

      }
      .width('100%')
      .backgroundColor('#66000000')
      .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
      .padding({ bottom: this.avoidNavigationBarHeight })
    }
  }

  @Builder
  private buildKey(label: string, width: number = 52, fontSize: number = 13) {
    Button(label)
      .width(width)
      .height(40)
      .padding(0)
      .fontSize(fontSize)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.activeKey === label ? '#553B82F6' : '#33232835')
      .fontColor('#FFFFFF')
      .opacity(0.82)
      .border({ width: 1, color: this.activeKey === label ? this.theme_ACCENT : this.theme_BORDER_SUBTLE })
      .borderRadius(7)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.activeKey = label;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.activeKey = '';
        }
      })
      .onClick(() => {
        this.handleSpecialKey(label);
      })
  }

  private handleSpecialKey(label: string): void {
    if (this.terminalId === -1) {
      return;
    }
    if (label === 'Esc') {
      this.terminalService.sendInput(this.terminalId, '\x1b');
      return;
    }
    if (label === 'Tab') {
      this.terminalService.sendInput(this.terminalId, '\t');
      return;
    }
    if (label === 'Ctrl+C') {
      this.terminalService.sendInput(this.terminalId, '\x03');
      return;
    }
    if (label === '↑') {
      this.terminalService.sendInput(this.terminalId, '\x1b[A');
      return;
    }
    if (label === '↓') {
      this.terminalService.sendInput(this.terminalId, '\x1b[B');
      return;
    }
    if (label === '←') {
      this.terminalService.sendInput(this.terminalId, '\x1b[D');
      return;
    }
    if (label === '→') {
      this.terminalService.sendInput(this.terminalId, '\x1b[C');
      return;
    }
    if (label === 'Home') {
      this.terminalService.sendInput(this.terminalId, '\x1b[H');
      return;
    }
    if (label === 'End') {
      this.terminalService.sendInput(this.terminalId, '\x1b[F');
      return;
    }
    if (label === 'PgUp') {
      this.terminalService.sendInput(this.terminalId, '\x1b[5~');
      return;
    }
    if (label === 'PgDn') {
      this.terminalService.sendInput(this.terminalId, '\x1b[6~');
      return;
    }
    if (label === '/' || label === '|' || label === '~') {
      this.terminalService.sendInput(this.terminalId, label);
      return;
    }
  }

  private runCommand(command: string): void {
    const text = command.trim();
    if (text.length === 0) {
      return;
    }
    if (this.terminalId === -1) {
      this.outputLines = this.outputLines.concat([this.lt('Terminal not connected')]);
      return;
    }
    const nextLines = this.outputLines.slice();
    nextLines.push(`$ ${text}`);
    this.outputLines = nextLines;
    this.commandInput = '';
    if (this.terminalService.sendInput(this.terminalId, `${text}\r`)) {
      return;
    }
    this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
  }

  private handleTerminalOutput(event: TerminalOutputEvent): void {
    if (event.terminalId !== this.terminalId) {
      return;
    }
    const cleanData = this.sanitizeTerminalOutput(event.data);
    const lines = cleanData.split(/\r?\n/).filter((line: string) => {
      if (line.length === 0) return false;
      // Interactive shells redraw the current command after every keystroke
      // using CR/ANSI cursor controls. It is already rendered by
      // pendingTerminalInput, so do not append every intermediate prefix.
      if (this.pendingTerminalInput.length > 0 &&
          (this.pendingTerminalInput === line || this.pendingTerminalInput.startsWith(line))) {
        return false;
      }
      return true;
    });
    if (lines.length > 0) {
      const combined = this.outputLines.concat(lines);
      const maxLines = 3000;
      this.outputLines = combined.length > maxLines ? combined.slice(combined.length - maxLines) : combined;
    }
  }

  @Builder
  private buildTerminalImeProxy() {
    TextArea({ text: $$this.imeText, controller: this.imeController })
      .id('terminal-ime-proxy')
      .width(2)
      .height(2)
      .opacity(0.01)
      .fontSize(1)
      .enterKeyType(EnterKeyType.NEW_LINE)
      .position({ x: 4, y: 4 })
      .onChange((value: string) => { this.handleTerminalImeChange(value); })
  }

  private requestTerminalKeyboard(forceRebind: boolean = false): void {
    const generation = ++this.imeWakeGeneration;
    try {
      const focusController = this.getUIContext().getFocusController();
      // When the user closes the IME manually, the invisible TextInput often
      // remains focused. requestFocus() alone is then a no-op. Rebind focus
      // before explicitly asking the input-method controller to show again.
      if (forceRebind || this.avoidKeyboardHeight <= 0) {
        focusController.clearFocus();
      }
      setTimeout(() => {
        if (generation !== this.imeWakeGeneration) return;
        try {
          focusController.requestFocus('terminal-ime-proxy');
          setTimeout(() => {
            if (generation !== this.imeWakeGeneration) return;
            void inputMethod.getController().showTextInput().catch((error: Object) => {
              console.warn('show terminal keyboard failed: ' + JSON.stringify(error));
            });
          }, 40);
        } catch (error) {
          console.warn('request terminal keyboard focus failed: ' + JSON.stringify(error));
        }
      }, forceRebind || this.avoidKeyboardHeight <= 0 ? 20 : 0);
    } catch (error) {
      console.warn('request terminal keyboard failed: ' + JSON.stringify(error));
    }
  }

  private handleTerminalImeChange(value: string): void {
    if (this.terminalId === -1 || value === this.imePrevious) return;
    const sentinel = '\u200B';
    const previous = this.imePrevious.startsWith(sentinel) ? this.imePrevious.slice(1) : this.imePrevious;
    const current = value.startsWith(sentinel) ? value.slice(1) : value;
    const submittedByNewLine = current.includes('\n') || current.includes('\r');
    const visibleCurrent = current.replace(/[\r\n]/g, '');
    this.pendingTerminalInput = visibleCurrent;
    let common = 0;
    const limit = Math.min(previous.length, current.length);
    while (common < limit && previous[common] === current[common]) common += 1;
    const removed = previous.length - common;
    if (removed > 0 && !this.terminalService.sendInput(this.terminalId, '\x7f'.repeat(removed))) {
      this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
    }
    const inserted = current.slice(common).replace(/[\r\n]/g, '');
    if (inserted.length > 0 && !this.terminalService.sendInput(this.terminalId, inserted)) {
      this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
    }
    if (submittedByNewLine) {
      const sent = this.terminalService.sendInput(this.terminalId, '\r');
      if (visibleCurrent.length > 0) {
        this.outputLines = this.outputLines.concat([`$ ${visibleCurrent}`]);
      }
      if (!sent) {
        this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
      }
      this.pendingTerminalInput = '';
      this.resetTerminalImeProxy();
      return;
    }
    this.imePrevious = value;
    if (current.length > 64) this.resetTerminalImeProxy();
  }

  private resetTerminalImeProxy(): void {
    this.imePrevious = '\u200B';
    this.imeText = '\u200B';
    setTimeout(() => {
      try { this.imeController.caretPosition(1); } catch (_error) {}
    }, 0);
  }

  private sanitizeTerminalOutput(data: string): string {
    return data
      .replace(/\x1B\][^\x07]*(?:\x07|\x1B\\)/g, '')
      .replace(/\x1B\[[0-?]*[ -/]*[@-~]/g, '')
      .replace(/\x1B[@-_]/g, '')
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001A\u001C-\u001F\u007F]/g, '');
  }

  private handleOfficialEvent(event: OfficialSessionEvent): void {
    if (event.kind !== 'terminal-response') {
      return;
    }
    try {
      const payload = JSON.parse(event.detail) as TerminalResponsePayload;
      if (payload.type === 'data') {
        return;
      }
      if (payload.type === 'opened') {
        this.sessionStatus = payload.success === false ? this.lt('Failed to connect') : this.lt('Connected');
        this.outputLines = [payload.message?.trim() || this.lt('Terminal opened')];
        return;
      }
      if (payload.type === 'error') {
        this.sessionStatus = this.lt('Failed to connect');
        this.outputLines = this.outputLines.concat([`[${this.lt('Error')}] ${payload.message ?? this.lt('Terminal returned error')}`]);
        return;
      }
      if (payload.type === 'closed') {
        this.sessionStatus = this.lt('Disconnected');
        this.outputLines = this.outputLines.concat([this.lt('Terminal closed')]);
      }
    } catch (error) {
      console.error('handleOfficialEvent terminal failed', JSON.stringify(error));
    }
  }

  private getRouteParams(): Record<string, string> {
    return this.getUIContext().getRouter().getParams() as Record<string, string>;
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      console.error('router back failed', JSON.stringify(error));
    }
  }

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nVersion = this.i18nRefresh;
  }
}
