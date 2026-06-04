import { createStrokeIconColorFilter } from '../common/CommonComponents';
import { AppDataService, TerminalSnippet } from '../services/AppDataService';
import { ClipboardService } from '../services/ClipboardService';
import { EmptyState, PageHeader, SectionTitle } from '../common/CommonComponents';
import { OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { OfficialSessionTransport } from '../services/OfficialSessionTransport';
import { TerminalService, TerminalOutputEvent } from '../services/TerminalService';
import { ThemeConfig } from '../common/ThemeConfig';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

interface TerminalResponsePayload {
  type?: string;
  data?: string;
  message?: string;
}

@Entry
@Component
struct Terminal {
  private appData: AppDataService = AppDataService.getInstance();
  private clipboardService: ClipboardService = ClipboardService.getInstance();
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
  @State snippets: TerminalSnippet[] = [];
  @State history: string[] = ['whoami', 'pwd', 'df -h', 'tail -n 200 /var/log/syslog'];
  @State extraKeysVisible: boolean = true;
  @State sessionStatus: string = '';
  aboutToAppear() {
    this.outputLines = [this.lt('Waiting for terminal session...')];
    this.sessionStatus = this.lt('Disconnected');
    const params = this.getRouteParams();
    if (params && params['deviceId']) {
      this.deviceId = params['deviceId'];
    }
    this.deviceName = this.appData.getDisplayName(this.deviceId);
    this.snippets = this.appData.getTerminalSnippets();
    this.officialBridge.addEventListener(this.sessionEventListener);
    this.terminalService.addOutputListener(this.outputListener);
    this.terminalId = this.terminalService.openTerminal(this.deviceId, 30, 120) ?? -1;
    if (this.terminalId === -1) {
      this.outputLines = this.outputLines.concat([this.lt('Terminal entry unavailable')]);
      this.sessionStatus = this.lt('Failed to connect');
    } else {
      this.sessionStatus = this.lt('Connected');
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
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_PANEL_BG') theme_PANEL_BG: string = '#1F1F1F';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('themeIsDark') themeIsDark: boolean = false;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: ThemeConfig.SPACING_LG }) {
          this.buildHistoryBar()
          this.buildSnippetList()
          this.buildOutputPanel()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: 56 + 40, bottom: this.extraKeysVisible ? 190 : 120 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Column() {
        PageHeader(this.lt('Terminal'), `${this.deviceName} | ${DeviceIdFormatter.format(this.deviceId)}`, true, () => {
          this.goBack();
        })
      }
      .padding({ top: this.avoidStatusBarHeight })
      .backgroundColor(this.themeIsDark ? '#802D3139' : '#80F8FAFC')

      Column() {
        Blank().layoutWeight(1)
        this.buildSessionBar()
        if (this.extraKeysVisible) {
          this.buildExtraKeys()
        }
        this.buildInputBar()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildSessionBar() {
    Row({ space: 8 }) {
      this.buildInfoPill(this.lt('Official Terminal'), this.theme_PANEL_BG, this.theme_CONTRAST_TEXT)
      this.buildInfoPill(this.sessionStatus, this.theme_ACCENT, this.theme_ACCENT_TEXT)
      this.buildInfoPill(this.extraKeysVisible ? this.lt('Extra keys enabled') : this.lt('Extra keys disabled'), this.theme_ACCENT, this.theme_ACCENT_TEXT)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 8 })
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildInfoPill(label: string, color: string, fontColor: string) {
    Text(label)
      .fontSize(11)
      .fontColor(fontColor)
      .backgroundColor(color)
      .borderRadius(999)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
  }

  @Builder
  private buildHistoryBar() {
    Column({ space: 8 }) {
      SectionTitle(this.lt('Recent Commands'))
      Row({ space: 8 }) {
        ForEach(this.history.slice(0, 4), (command: string) => {
          Button(command)
            .height(32)
            .fontSize(11)
            .backgroundColor(this.theme_CARD_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .borderRadius(12)
            .onClick(() => {
              this.commandInput = command;
            })
        }, (command: string) => command)
      }
    }
    .width('100%')
  }

  @Builder
  private buildSnippetList() {
    Column({ space: 12 }) {
      SectionTitle(this.lt('Snippets'))

      Column({ space: 10 }) {
        ForEach(this.snippets, (snippet: TerminalSnippet) => {
          Column({ space: 8 }) {
            Row() {
              Column({ space: 4 }) {
                Text(snippet.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme_TEXT_PRIMARY)
                Text(snippet.description)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Button(this.lt('Run'))
                .height(32)
                .fontSize(12)
                .backgroundColor(this.theme_ACCENT)
                .fontColor(this.theme_ACCENT_TEXT)
                .borderRadius(10)
                .onClick(() => {
                  this.runCommand(snippet.command);
                })
            }

            Text(snippet.command)
              .fontSize(12)
              .fontColor(this.theme_ACCENT)
              .width('100%')
          }
          .padding(16)
          .backgroundColor(this.theme_CARD_BG)
          .borderRadius(18)
        }, (snippet: TerminalSnippet) => snippet.id)
      }
    }
  }

  @Builder
  private buildOutputPanel() {
    Column({ space: 12 }) {
      Row() {
        SectionTitle(this.lt('Terminal Output'))

        Button(this.extraKeysVisible ? this.lt('Hide Keys') : this.lt('Show Keys'))
          .height(32)
          .fontSize(11)
          .backgroundColor(this.theme_INPUT_BG)
          .fontColor(this.theme_TEXT_PRIMARY)
          .borderRadius(10)
          .onClick(() => {
            this.extraKeysVisible = !this.extraKeysVisible;
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        this.buildPanelAction(this.lt('Copy Output'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
          void this.copyOutput();
        })
        this.buildPanelAction(this.lt('Clear'), this.theme_ERROR_TEXT, this.theme_CONTRAST_TEXT, () => {
          this.outputLines = [];
        })
      }

      if (this.outputLines.length === 0) {
        EmptyState($rawfile('keyboard_mouse.svg'), this.lt('No terminal output yet.'))
      } else {
        Column({ space: 6 }) {
          ForEach(this.outputLines, (line: string, index: number) => {
            Text(line)
              .fontSize(13)
              .fontColor(this.theme_TEXT_TERTIARY)
              .width('100%')
              .textAlign(TextAlign.Start)
          }, (line: string, index: number) => `${index}-${line}`)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.theme_PANEL_BG)
        .borderRadius(18)
      }
    }
  }

  @Builder
  private buildPanelAction(label: string, color: string, fontColor: string, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(11)
      .backgroundColor(color)
      .fontColor(fontColor)
      .borderRadius(10)
      .onClick(action)
  }

  @Builder
  private buildExtraKeys() {
    Row({ space: 8 }) {
      this.buildExtraKey('Ctrl')
      this.buildExtraKey('Alt')
      this.buildExtraKey('Tab')
      this.buildExtraKey('Esc')
      this.buildExtraKey(this.lt('Left'))
      this.buildExtraKey(this.lt('Right'))
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildExtraKey(label: string) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(12)
      .backgroundColor(this.theme_CARD_BG)
      .fontColor(this.theme_TEXT_PRIMARY)
      .borderRadius(10)
      .onClick(() => {
        if (this.terminalId === -1) {
          return;
        }
        if (label === 'Tab') {
          this.commandInput = `${this.commandInput}\t`;
          return;
        }
        if (label === this.lt('Left')) {
          this.terminalService.sendInput(this.terminalId, '\x1b[D');
          return;
        }
        if (label === this.lt('Right')) {
          this.terminalService.sendInput(this.terminalId, '\x1b[C');
          return;
        }
        if (label === 'Ctrl') {
          this.terminalService.sendInput(this.terminalId, '\x03');
          return;
        }
        if (label === 'Alt') {
          this.terminalService.sendInput(this.terminalId, '\x1b');
          return;
        }
        if (label === 'Esc') {
          this.terminalService.sendInput(this.terminalId, '\x1b');
          return;
        }
      })
  }

  @Builder
  private buildInputBar() {
    Row({ space: 8 }) {
      Row() {
        Image($rawfile('keyboard_mouse.svg'))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
          .margin({ right: 8 })
        TextInput({ placeholder: this.lt('Input command'), text: this.commandInput })
          .layoutWeight(1)
          .height(46)
          .backgroundColor('transparent')
          .borderRadius(0)
          .padding({ left: 0, right: 0 })
          .onChange((value: string) => {
            this.commandInput = value;
          })
      }
      .layoutWeight(1)
      .height(46)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(12)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Button() {
        Row({ space: 4 }) {
          Image($rawfile('arrow.svg'))
            .width(14)
            .height(14)
            .colorFilter(createStrokeIconColorFilter(this.theme_ACCENT_TEXT))
            .rotate({ angle: 90 })
          Text(this.lt('Send'))
            .fontSize(14)
            .fontColor(this.theme_ACCENT_TEXT)
        }
      }
      .width(88)
      .height(46)
      .backgroundColor(this.theme_ACCENT)
      .borderRadius(12)
      .onClick(() => {
        this.runCommand(this.commandInput);
      })
    }
    .padding(16)
    .backgroundColor(this.theme_INPUT_BG)
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
    nextLines.push(`rustdesk@remote:~$ ${text}`);
    this.outputLines = nextLines;
    this.pushHistory(text);
    this.commandInput = '';
    if (this.terminalService.sendInput(this.terminalId, `${text}\n`)) {
      return;
    }
    this.outputLines = this.outputLines.concat([this.lt('Terminal input send failed')]);
  }

  private pushHistory(command: string): void {
    const filtered = this.history.filter((item: string) => item !== command);
    const next = [command];
    filtered.forEach((item: string) => {
      if (next.length < 6) {
        next.push(item);
      }
    });
    this.history = next;
  }

  private async copyOutput(): Promise<void> {
    await this.clipboardService.copyText(this.outputLines.join('\n'));
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
        const lines = (payload.data ?? '').split(/\r?\n/).filter((line: string) => line.length > 0);
        if (lines.length > 0) {
          this.outputLines = this.outputLines.concat(lines);
        }
        return;
      }
      if (payload.type === 'opened') {
        this.outputLines = this.outputLines.concat([payload.message?.trim() || this.lt('Terminal opened')]);
        return;
      }
      if (payload.type === 'error') {
        this.outputLines = this.outputLines.concat([`[${this.lt('Error')}] ${payload.message ?? this.lt('Terminal returned error')}`]);
        return;
      }
      if (payload.type === 'closed') {
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
