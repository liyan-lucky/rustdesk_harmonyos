import { AccountService, OAuthProvider, accountService, AccountState } from '../services/AccountService';
import { LoginOption } from '../services/HttpClient';
import { AppState } from '../services/AppState';
import { ThemeConfig } from '../common/ThemeConfig';
import { I18nService } from '../services/I18nService';
import { createStrokeIconColorFilter } from '../common/CommonComponents';

type LoginMode = 'oauth' | 'password';

@Entry
@Component
struct LoginPage {
  private accountService: AccountService = AccountService.getInstance();
  private appState: AppState = AppState.getInstance();

  @State loginMode: LoginMode = 'oauth';
  @State selectedProvider: string = 'github';
  @State availableProviders: OAuthProvider[] = [];
  @State username: string = '';
  @State password: string = '';
  @State verifyCode: string = '';
  @State errorMessage: string = '';
  @State isLoading: boolean = false;
  @State requireEmail: boolean = false;
  @State requireTfa: boolean = false;

  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('themeIsDark') themeIsDark: boolean = false;
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageLink('app:account') accountState: AccountState = {
    isLoggedIn: false, username: '', displayName: '', avatar: '',
    accessToken: '', provider: '', loginUrl: '', status: 'idle', lastError: ''
  };

  @Watch('onAccountChanged')
  @State prevLoggedIn: boolean = false;
  @State isPollingOAuth: boolean = false;
  private pollingCheckTimer: number = -1;

  aboutToAppear(): void {
    this.accountService.syncApiServerFromSettings();
    console.info('[LoginPage] Using configured API server');
    void this.loadProviders();

    if (this.accountState.isLoggedIn) {
      this.goBack();
    }
    this.prevLoggedIn = this.accountState.isLoggedIn;
    this.isPollingOAuth = this.accountService.isPolling();
    this.pollingCheckTimer = setInterval(() => {
      this.isPollingOAuth = this.accountService.isPolling();
    }, 500);
  }

  private onAccountChanged(): void {
    if (this.accountState.isLoggedIn && !this.prevLoggedIn) {
      this.isLoading = false;
      try {
        this.getUIContext().getPromptAction().openToast({
          message: this.lt('Login successful')
        });
      } catch (e) {}
      this.goBack();
    }
    if (this.accountState.status === 'error' && this.accountState.lastError) {
      this.errorMessage = this.accountState.lastError;
      this.isLoading = false;
    }
    this.prevLoggedIn = this.accountState.isLoggedIn;
  }

  aboutToDisappear(): void {
    if (this.pollingCheckTimer !== -1) {
      clearInterval(this.pollingCheckTimer);
      this.pollingCheckTimer = -1;
    }
    if (this.accountService.isPolling()) {
      this.accountService.cancelLogin();
    }
  }

  private async loadProviders(): Promise<void> {
    const options: LoginOption[] = await this.accountService.getLoginOptions();
    const providers: OAuthProvider[] = [];
    for (const opt of options) {
      const providerId = opt.op.startsWith('oidc/') ? opt.op.substring(5) : opt.op;
      const info = this.accountService.getProviderInfo(providerId);
      if (info) {
        providers.push(info);
      }
    }
    this.availableProviders = providers.length > 0 ? providers : this.accountService.getAllProviders().slice(0, 5);
  }

  build() {
    Column() {
      Column() {
        Image($rawfile('app_icon.svg'))
          .width(80)
          .height(80)
          .margin({ bottom: 16 })

        Text('RustDesk')
          .fontSize(28)
          .fontColor(this.theme_TEXT_PRIMARY)
          .fontWeight(FontWeight.Bold)

        Text(this.lt('Remote Desktop Control'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_TERTIARY)
          .margin({ top: 8, bottom: 32 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 32, bottom: 24 })
      .margin({ top: this.avoidStatusBarHeight + 20 })
      .backgroundColor(this.themeIsDark ? '#08FFFFFF' : '#08FFFFFF')
      .borderRadius(20)

      Row({ space: 16 }) {
        this.buildModeTab(this.lt('OAuth Login'), 'oauth')
        this.buildModeTab(this.lt('Password Login'), 'password')
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .margin({ bottom: 16 })

      if (this.loginMode === 'oauth') {
        this.buildOAuthLogin()
      } else {
        this.buildPasswordLogin()
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor(this.theme_ERROR_TEXT)
          .margin({ top: 16 })
          .padding({ left: 12, right: 12 })
      }

      Blank()

      Row() {
        Text(this.lt('Login agreement'))
          .fontSize(12)
          .fontColor(this.theme_TEXT_TERTIARY)
        Text(this.lt('Privacy Policy'))
          .fontSize(12)
          .fontColor(this.theme_ACCENT)
          .onClick(() => this.openUrl('https://rustdesk.com/privacy'))
        Text(this.lt('and'))
          .fontSize(12)
          .fontColor(this.theme_TEXT_TERTIARY)
        Text(this.lt('Terms of Service'))
          .fontSize(12)
          .fontColor(this.theme_ACCENT)
          .onClick(() => this.openUrl('https://rustdesk.com/terms'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildModeTab(label: string, mode: LoginMode) {
    Text(label)
      .fontSize(14)
      .fontColor(this.loginMode === mode ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .borderRadius(8)
      .backgroundColor(this.loginMode === mode ? this.theme_CARD_BG : 'transparent')
      .onClick(() => {
        this.loginMode = mode;
        this.errorMessage = '';
      })
  }

  @Builder
  private buildOAuthLogin() {
    Column({ space: 12 }) {
      ForEach(this.availableProviders, (provider: OAuthProvider) => {
        this.buildProviderButton(provider)
      }, (provider: OAuthProvider) => provider.id)

      if (this.isPollingOAuth) {
        Row() {
          LoadingProgress().width(20).height(20).color(this.theme_TEXT_SECONDARY)
          Text(this.lt('Waiting for browser authorization...'))
            .fontSize(13).fontColor(this.theme_TEXT_SECONDARY).margin({ left: 8 })
        }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })

        Row({ space: 12 }) {
          Button(this.lt('Reopen browser')).height(36).backgroundColor(this.theme_CARD_BG)
            .fontColor(this.theme_TEXT_PRIMARY).onClick(() => void this.accountService.reopenBrowser())
          Button(this.lt('Cancel')).height(36).backgroundColor(this.theme_CARD_BG)
            .fontColor(this.theme_ERROR_TEXT).onClick(() => this.accountService.cancelLogin())
        }
      }

      Column() {
        Text(this.lt('Other Methods')).fontSize(12).fontColor(this.theme_TEXT_TERTIARY).margin({ bottom: 8 })
        Row({ space: 12 }) {
          ForEach(this.accountService.getAllProviders().slice(5), (provider: OAuthProvider) => {
            Image($rawfile(provider.icon)).width(28).height(28)
              .onClick(() => void this.handleOAuthLogin(provider.id))
          }, (provider: OAuthProvider) => provider.id)
        }
      }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private buildProviderButton(provider: OAuthProvider) {
    Button() {
      Row() {
        Image($rawfile(provider.icon)).width(24).height(24).colorFilter(createStrokeIconColorFilter(this.theme_CONTRAST_TEXT))
        Text(`${this.lt('Login with')} ${provider.name}`)
          .fontSize(16).fontColor(this.theme_CONTRAST_TEXT).margin({ left: 12 }).layoutWeight(1)
        if (this.isLoading && this.selectedProvider === provider.id) {
          LoadingProgress().width(20).height(20).color(this.theme_CONTRAST_TEXT)
        }
      }.width('100%').padding({ left: 16, right: 16 })
    }
    .width('100%').height(52).backgroundColor(provider.color).borderRadius(8)
    .enabled(!this.isLoading && !this.isPollingOAuth)
    .onClick(() => void this.handleOAuthLogin(provider.id))
  }

  @Builder
  private buildPasswordLogin() {
    Column({ space: 16 }) {
      if (this.requireEmail) {
        this.buildEmailVerifyForm()
      } else if (this.requireTfa) {
        this.buildTfaVerifyForm()
      } else {
        this.buildPasswordForm()
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
  }

  @Builder
  private buildPasswordForm() {
    Column({ space: 12 }) {
      TextInput({ placeholder: this.lt('Username'), text: this.username })
        .height(48).backgroundColor(this.theme_INPUT_BG).borderRadius(8)
        .onChange((v: string) => this.username = v)
      TextInput({ placeholder: this.lt('Password'), text: this.password })
        .height(48).type(InputType.Password).backgroundColor(this.theme_INPUT_BG).borderRadius(8)
        .onChange((v: string) => this.password = v)
      Button(this.isLoading ? this.lt('Logging in...') : this.lt('Login'))
        .width('100%').height(48).backgroundColor(this.theme_ACCENT)
        .fontColor(this.theme_ACCENT_TEXT).borderRadius(8)
        .enabled(!this.isLoading && this.username.length > 0 && this.password.length > 0)
        .onClick(() => void this.handlePasswordLogin())
    }
  }

  @Builder
  private buildEmailVerifyForm() {
    Column({ space: 12 }) {
      Text(this.lt('Email verification required')).fontSize(16).fontColor(this.theme_TEXT_PRIMARY).width('100%')
      Text(this.lt('Please enter the verification code sent to your email'))
        .fontSize(13).fontColor(this.theme_TEXT_SECONDARY).width('100%')
      TextInput({ placeholder: this.lt('Verification code'), text: this.verifyCode })
        .height(48).backgroundColor(this.theme_INPUT_BG).borderRadius(8)
        .onChange((v: string) => this.verifyCode = v)
      Row({ space: 12 }) {
        Button(this.lt('Verify')).layoutWeight(1).height(48).backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT).borderRadius(8).onClick(() => void this.handleEmailVerify())
        Button(this.lt('Cancel')).layoutWeight(1).height(48).backgroundColor(this.theme_CARD_BG)
          .fontColor(this.theme_TEXT_PRIMARY).borderRadius(8).onClick(() => this.resetForm())
      }
    }
  }

  @Builder
  private buildTfaVerifyForm() {
    Column({ space: 12 }) {
      Text(this.lt('Two-factor authentication')).fontSize(16).fontColor(this.theme_TEXT_PRIMARY).width('100%')
      Text(this.lt('Please enter your 2FA code')).fontSize(13).fontColor(this.theme_TEXT_SECONDARY).width('100%')
      TextInput({ placeholder: this.lt('2FA code'), text: this.verifyCode })
        .height(48).backgroundColor(this.theme_INPUT_BG).borderRadius(8)
        .onChange((v: string) => this.verifyCode = v)
      Row({ space: 12 }) {
        Button(this.lt('Verify')).layoutWeight(1).height(48).backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT).borderRadius(8).onClick(() => void this.handleTfaVerify())
        Button(this.lt('Cancel')).layoutWeight(1).height(48).backgroundColor(this.theme_CARD_BG)
          .fontColor(this.theme_TEXT_PRIMARY).borderRadius(8).onClick(() => this.resetForm())
      }
    }
  }

  private async handleOAuthLogin(providerId: string): Promise<void> {
    this.selectedProvider = providerId;
    this.isLoading = true;
    this.errorMessage = '';

    const result = await this.accountService.loginWithOAuth(providerId);
    this.isLoading = false;

    if (!result) {
      const account = this.appState.getAccount();
      this.errorMessage = account.lastError ?? this.lt('Authentication request failed');
      return;
    }
  }

  private async handlePasswordLogin(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    const result = await this.accountService.loginWithPassword(this.username, this.password);
    this.isLoading = false;
    if (result.success && this.accountState.isLoggedIn) {
      this.goBack();
    } else if (result.emailCheck) {
      this.requireEmail = true;
      this.errorMessage = '';
    } else if (result.tfaCheck) {
      this.requireTfa = true;
      this.errorMessage = '';
    }
  }

  private async handleEmailVerify(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    const success = await this.accountService.verifyEmail(this.verifyCode);
    this.isLoading = false;
    if (success && this.accountState.isLoggedIn) {
      this.goBack();
    }
  }

  private async handleTfaVerify(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    const success = await this.accountService.verifyTfa(this.verifyCode);
    this.isLoading = false;
    if (success && this.accountState.isLoggedIn) {
      this.goBack();
    }
  }

  private resetForm(): void {
    this.requireEmail = false;
    this.requireTfa = false;
    this.verifyCode = '';
    this.errorMessage = '';
  }

  private openUrl(url: string): void {
    try {
      void this.getUIContext().getRouter().pushUrl({ url });
    } catch (e) {}
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {}
  }

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nVersion = this.i18nRefresh;
  }
}
