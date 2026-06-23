import { AppDataService } from '../services/AppDataService';
import { OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { TerminalService, TerminalOutputEvent } from '../services/TerminalService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

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

      this.buildHeader()

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
        }, (line: string, index: number) => `${index}-${line}`)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 96, bottom: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.BottomStart)
    .onClick(() => {
      this.keyboardVisible = !this.keyboardVisible;
    })
  }

  @Builder
  private buildCustomKeyboard() {
    if (this.keyboardVisible) {
      Column() {
        Row({ space: 4 }) {
          this.buildKey('Esc')
          this.buildKey('/')
          this.buildKey('|')
          this.buildKey('Home')
          this.buildKey('↑')
          this.buildKey('End')
          this.buildKey('PgUp')
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 3 })

        Row({ space: 4 }) {
          this.buildKey('Tab')
          this.buildKey('Ctrl+C')
          this.buildKey('~')
          this.buildKey('←')
          this.buildKey('↓')
          this.buildKey('→')
          this.buildKey('PgDn')
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 6 })

        Row({ space: 8 }) {
          TextInput({ placeholder: this.lt('Input command'), text: this.commandInput })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#1A1A1A')
            .fontColor('#FFFFFF')
            .borderRadius(6)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.commandInput = value;
            })
            .onSubmit(() => {
              this.runCommand(this.commandInput);
            })

          Button(this.lt('Send'))
            .height(40)
            .fontSize(13)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .borderRadius(6)
            .onClick(() => {
              this.runCommand(this.commandInput);
            })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 4, bottom: 8 })
      }
      .width('100%')
      .backgroundColor('#111111')
      .border({ width: { top: 1 }, color: '#333333' })
      .padding({ bottom: this.avoidNavigationBarHeight })
    }
  }

  @Builder
  private buildKey(label: string) {
    Button(label)
      .layoutWeight(1)
      .height(36)
      .fontSize(12)
      .backgroundColor('#222222')
      .fontColor('#FFFFFF')
      .borderRadius(6)
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
    if (this.terminalService.sendInput(this.terminalId, `${text}\n`)) {
      return;
    }
    this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
  }

  private handleTerminalOutput(event: TerminalOutputEvent): void {
    if (event.terminalId !== this.terminalId) {
      return;
    }
    const lines = event.data.split(/\r?\n/).filter((line: string) => line.length > 0);
    if (lines.length > 0) {
      this.outputLines = this.outputLines.concat(lines);
    }
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
        this.outputLines = this.outputLines.concat([payload.message?.trim() || this.lt('Terminal opened')]);
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
