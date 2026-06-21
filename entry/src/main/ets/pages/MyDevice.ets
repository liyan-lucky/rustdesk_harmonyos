import { AppDataService, LocalDeviceProfile, SettingsState } from '../services/AppDataService';
import { ClipboardService } from '../services/ClipboardService';
import { ThemeConfig } from '../common/ThemeConfig';
import { CardContainer, InfoRow, MenuInfoItem, MenuRowDivider, MenuSectionCard, MenuToggleItem, PageHeader, PrimaryButton, SecondaryButton, SectionTitle, StatusBadge, ToggleSettingItem } from '../common/CommonComponents';
import { OfficialCoreState, OfficialRustDeskBridge } from '../services/OfficialRustDeskBridge';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

type ApprovalMode = 'password' | 'click' | 'both';

@Entry
@Component
struct MyDevice {
  private appData: AppDataService = AppDataService.getInstance();
  private clipboardService: ClipboardService = ClipboardService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private refreshTimer: number = -1;

  @State deviceProfile: LocalDeviceProfile = {
    id: '',
    alias: '',
    platform: '',
    ip: '',
    status: '',
    fingerprint: '',
    directAddress: ''
  };
  @State settings: SettingsState = this.appData.getSettings();
  @State password: string = '';
  @State aliasDraft: string = '';
  @State officialCoreState: OfficialCoreState = this.officialBridge.getCoreState();
  aboutToAppear() {
    void this.reloadState();
    this.startRefreshLoop();
  }

  aboutToDisappear() {
    this.stopRefreshLoop();
  }
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('themeIsDark') themeIsDark: boolean = false;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: ThemeConfig.SPACING_LG }) {
          this.buildIdentityCard()
          this.buildServiceCard()
          this.buildApprovalCard()
          this.buildCapabilityCard()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: 56, bottom: this.avoidNavigationBarHeight + ThemeConfig.SPACING_MD })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Column() {
        PageHeader(this.lt('My Device'), this.lt('Official RustDesk identity and incoming access state'), true, () => {
          this.goBack();
        })
      }
      .padding({ top: this.avoidStatusBarHeight })
      .backgroundColor(this.themeIsDark ? '#802D3139' : '#80F8FAFC')

      Column() {
        Blank().layoutWeight(1)
        Row({ space: ThemeConfig.SPACING_MD }) {
          SecondaryButton(this.lt('Open Settings'), () => {
            this.navigateToSettings();
          })
        }
        .padding(ThemeConfig.SPACING_MD)
        .backgroundColor(this.theme_CARD_BG)
        .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
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
  private buildIdentityCard() {
    MenuSectionCard() {
      Column() {
        Row() {
          Column({ space: 4 }) {
            Text(this.deviceProfile.alias)
              .fontSize(ThemeConfig.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme_TEXT_PRIMARY)
              .width('100%')

            Text(this.deviceProfile.platform)
              .fontSize(ThemeConfig.FONT_SIZE_SM)
              .fontColor(this.theme_TEXT_SECONDARY)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          StatusBadge(this.officialCoreState.coreReady ? this.lt('Core Ready') : this.lt('Core Missing'), this.officialCoreState.coreReady)
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, top: ThemeConfig.SPACING_LG, bottom: ThemeConfig.SPACING_SM })

        TextInput({ placeholder: this.lt('Device alias'), text: this.aliasDraft })
          .height(46)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
          .padding({ left: 14, right: 14 })
          .margin({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })

        Row({ space: ThemeConfig.SPACING_SM }) {
          Button(this.lt('Save Alias'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .borderRadius(12)
            .onClick(() => {
              this.saveAlias();
            })

          Button(this.lt('Copy Fingerprint'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .borderRadius(12)
            .onClick(() => {
              void this.copyText(this.deviceProfile.fingerprint, this.lt('Fingerprint copied'));
            })
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, top: ThemeConfig.SPACING_MD })

        Column() {
          this.buildCopyableMenuInfoItem(this.lt('Device ID'), DeviceIdFormatter.format(this.deviceProfile.id), this.deviceProfile.id, this.lt('Device ID copied'))
          MenuInfoItem({ label: this.lt('LAN IP'), value: this.deviceProfile.ip, showTopBorder: true })
          MenuInfoItem({ label: this.lt('Direct Address'), value: this.deviceProfile.directAddress, showTopBorder: true })
          MenuInfoItem({ label: this.lt('Fingerprint'), value: this.deviceProfile.fingerprint, showTopBorder: true })
        }
        .width('100%')

        Text(this.officialCoreState.detailMessage)
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.officialCoreState.coreReady ? this.theme_TEXT_SECONDARY : this.theme_ACCENT)
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, top: ThemeConfig.SPACING_SM })
      }
      .width('100%')
    }
  }

  @Builder
  private buildServiceCard() {
    MenuSectionCard() {
      Column() {
        Row() { SectionTitle(this.lt('Share Service')) }
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
        Column() {
          MenuToggleItem({ label: this.lt('Allow incoming connections'), isOpen: this.settings.serviceEnabled, onToggle: (value: boolean) => {
              this.settings = this.appData.updateSettings({ serviceEnabled: value, allowRemoteControl: false });
              void this.refreshIncomingState(value);
            } })
          MenuToggleItem({ label: this.lt('Allow file transfer'), isOpen: this.settings.allowFileTransfer, showTopBorder: true, onToggle: (value: boolean) => {
              this.settings = this.appData.updateSettings({ allowFileTransfer: value });
            } })
          this.buildCopyableMenuInfoItem(this.lt('One-time Password'), this.password, this.password, this.lt('Password copied'), true)
        }
        .width('100%')

        Row() {
          Button(this.lt('New Password'))
            .width('100%')
            .height(40)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_CONTRAST_TEXT)
            .borderRadius(12)
            .onClick(() => {
              this.generatePassword();
            })
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, top: ThemeConfig.SPACING_MD })
      }
      .width('100%')
    }
  }

  @Builder
  private buildApprovalCard() {
    MenuSectionCard() {
      Column() {
        Row() { SectionTitle(this.lt('Connection Approval')) }
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, top: ThemeConfig.SPACING_LG })
        Text(this.lt('These toggles now describe the desired policy. Real incoming approval requires the official RustDesk native core bridge.'))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG, bottom: ThemeConfig.SPACING_SM })

        Row({ space: ThemeConfig.SPACING_SM }) {
          this.buildModeButton(this.lt('Password'), this.settings.approvalMode === 'password', () => {
            this.applyApprovalMode('password');
          })
          this.buildModeButton(this.lt('Accept Click'), this.settings.approvalMode === 'click', () => {
            this.applyApprovalMode('click');
          })
          this.buildModeButton(this.lt('Both'), this.settings.approvalMode === 'both', () => {
            this.applyApprovalMode('both');
          })
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
      }
      .width('100%')
    }
  }

  @Builder
  private buildCapabilityCard() {
    MenuSectionCard() {
      Column() {
        Row() { SectionTitle(this.lt('Capabilities')) }
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
        Column() {
          this.buildCapabilityRow(this.lt('Audio'), this.settings.enableAudio, false)
          this.buildCapabilityRow(this.lt('Clipboard'), this.settings.enableClipboard, true)
          this.buildCapabilityRow(this.lt('Floating Window'), this.settings.enableFloatingWindow, true)
          this.buildCapabilityRow(this.lt('Auto Record Outgoing'), this.settings.autoRecordOutgoing, true)
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private buildCapabilityRow(label: string, enabled: boolean, showTopBorder: boolean) {
    Row() {
      Text(label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      StatusBadge(enabled ? this.lt('Enabled') : this.lt('Disabled'), enabled)
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
  }

  @Builder
  private buildModeButton(label: string, active: boolean, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(40)
      .fontSize(ThemeConfig.FONT_SIZE_SM)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(active ? this.theme_ACCENT : this.theme_INPUT_BG)
      .fontColor(active ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
      .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
      .onClick(action)
  }

  private async reloadState(): Promise<void> {
    const baseProfile = this.appData.getLocalDevice();
    this.settings = this.appData.getSettings();
    this.password = this.appData.getPassword();
    this.aliasDraft = baseProfile.alias;
    this.officialCoreState = await this.officialBridge.refresh(this.settings);
    this.deviceProfile = this.officialBridge.buildLocalDeviceProfile(baseProfile, this.officialCoreState);
  }

  @Builder
  private buildCopyableMenuInfoItem(label: string, value: string, copyValue: string, copiedMessage: string, showTopBorder: boolean = false) {
    Row() {
      Text(label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_SECONDARY)
        .layoutWeight(1)

      Text(value)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .gesture(
      LongPressGesture({ duration: 500 })
        .onAction(() => {
          void this.copyText(copyValue, copiedMessage);
        })
    )
  }

  private saveAlias(): void {
    const nextAlias = this.aliasDraft.trim();
    if (nextAlias.length === 0) {
      return;
    }
    this.appData.updateLocalDevice({ alias: nextAlias });
    void this.reloadState();
  }

  private applyApprovalMode(mode: ApprovalMode): void {
    this.settings = this.appData.updateSettings({ approvalMode: mode });
  }

  private async refreshIncomingState(enabled: boolean): Promise<void> {
    this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(enabled, this.settings);
    const baseProfile = this.appData.setServiceEnabled(enabled);
    this.deviceProfile = this.officialBridge.buildLocalDeviceProfile(baseProfile, this.officialCoreState);
    this.password = this.appData.getPassword();
    setTimeout(() => {
      void this.reloadState();
    }, 300);
  }

  private generatePassword(): void {
    this.password = this.appData.generatePassword();
    setTimeout(() => {
      void this.reloadState();
    }, 250);
  }

  private startRefreshLoop(): void {
    if (this.refreshTimer !== -1) {
      return;
    }
    this.refreshTimer = setInterval(() => {
      void this.reloadState();
    }, 2000);
  }

  private stopRefreshLoop(): void {
    if (this.refreshTimer === -1) {
      return;
    }
    clearInterval(this.refreshTimer);
    this.refreshTimer = -1;
  }

  private async copyText(value: string, message: string): Promise<void> {
    const success: boolean = await this.clipboardService.copyText(value);
    try {
      await this.getUIContext().getPromptAction().openToast({
        message: success ? message : 'Copy failed'
      });
    } catch (error) {
      console.error('toast failed', JSON.stringify(error));
    }
  }

  private navigateToSettings(): void {
    try {
      void this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
    } catch (error) {
      console.error('router push failed', JSON.stringify(error));
    }
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
