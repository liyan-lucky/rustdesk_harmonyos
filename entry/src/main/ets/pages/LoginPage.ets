import { AccountService, OAuthProvider, accountService, AccountState } from '../services/AccountService';
import { AppState } from '../services/AppState';
import { ThemeConfig } from '../common/ThemeConfig';
import { I18nService } from '../services/I18nService';
import { createStrokeIconColorFilter } from '../common/CommonComponents';
import { Logger } from '../common/Logger';

type LoginMode = 'oauth' | 'password';

@Entry
@Component
struct LoginPage {
  private accountService: AccountService = AccountService.getInstance();
  private appState: AppState = AppState.getInstance();

  @State loginMode: LoginMode = 'oauth';
  @State selectedProvider: string = 'github';
  @State availableProviders: OAuthProvider[] = [];
  @State providersSyncing: boolean = false;
  @State username: string = '';
  @State password: string = '';
  @State verifyCode: string = '';
  @State errorMessage: string = '';
  @State isLoading: boolean = false;
  @State requireEmail: boolean = false;
  @State requireTfa: boolean = false;
  @State showSearchInput: boolean = false;
  @State searchText: string = '';

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
  @StorageLink('apiNetworkStatus') apiNetworkStatus: string = 'idle';
  @StorageLink('apiNetworkServer') apiNetworkServer: string = '';
  @StorageLink('apiNetworkError') apiNetworkError: string = '';
  @StorageLink('app:account') accountState: AccountState = {
    isLoggedIn: false, username: '', displayName: '', avatar: '',
    accessToken: '', provider: '', loginUrl: '', status: 'idle', lastError: ''
  };

  @Watch('onAccountChanged')
  @State prevLoggedIn: boolean = false;
  @State isPollingOAuth: boolean = false;
  private pollingCheckTimer: number = -1;
  private providersRefreshTimer: number = -1;
  private readonly PROVIDERS_REFRESH_INTERVAL: number = 60000;

  aboutToAppear(): void {
    this.accountService.syncApiServerFromSettings();
    Logger.debug('LOGIN', 'LoginPage aboutToAppear, using configured API server');
    void this.loadProviders();

    if (this.accountState.isLoggedIn) {
      this.goBack();
    }
    this.prevLoggedIn = this.accountState.isLoggedIn;
    this.isPollingOAuth = this.accountService.isPolling();
    this.pollingCheckTimer = setInterval(() => {
      this.isPollingOAuth = this.accountService.isPolling();
    }, 500);
    this.providersRefreshTimer = setInterval(() => {
      if (this.loginMode === 'oauth' && !this.isPollingOAuth) {
        void this.syncProviders(false);
      }
    }, this.PROVIDERS_REFRESH_INTERVAL);
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
    if (this.providersRefreshTimer !== -1) {
      clearInterval(this.providersRefreshTimer);
      this.providersRefreshTimer = -1;
    }
    if (this.accountService.isPolling()) {
      this.accountService.cancelLogin();
    }
  }

  private async loadProviders(): Promise<void> {
    const cached = this.accountService.getCachedAvailableProviders();
    if (cached !== undefined) {
      this.availableProviders = cached;
      return;
    }
    await this.syncProviders(false);
  }

  private async syncProviders(showFeedback: boolean = true): Promise<void> {
    if (this.providersSyncing) return;
    this.providersSyncing = true;
    this.availableProviders = await this.accountService.refreshAvailableProviders();
    this.providersSyncing = false;
    if (showFeedback) {
      try {
        this.getUIContext().getPromptAction().openToast({
          message: this.lt(this.accountService.didProvidersSyncSucceed() ? 'Login information synced' : 'Login information sync failed')
        });
      } catch (_error) {}
    }
  }

  private filterProviders(providers: OAuthProvider[]): OAuthProvider[] {
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return providers;
    }
    return providers.filter((provider: OAuthProvider) => {
      return provider.id.toLowerCase().includes(keyword) ||
        provider.name.toLowerCase().includes(keyword) ||
        provider.icon.toLowerCase().includes(keyword);
    });
  }

  private dismissSearch(clearText: boolean = true): void {
    this.showSearchInput = false;
    if (clearText) {
      this.searchText = '';
    }
  }

  private openSearch(): void {
    this.showSearchInput = true;
    setTimeout(() => {
      try {
        focusControl.requestFocus('login-search-input');
      } catch (e) { console.warn('requestFocus failed: ' + JSON.stringify(e)); }
    }, 30);
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

      Row() {
        Row({ space: 16 }) {
          this.buildModeTab(this.lt('OAuth Login'), 'oauth')
          this.buildModeTab(this.lt('Password Login'), 'password')
        }
        .layoutWeight(1)

        Row({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            if (this.providersSyncing) {
              LoadingProgress().width(18).height(18).color(this.theme_ACCENT)
            } else {
              Image($rawfile('menu_refresh.svg'))
                .width(18)
                .height(18)
                .fillColor(this.theme_TEXT_TERTIARY)
            }
          }
          .width(28)
          .height(32)
          .enabled(!this.providersSyncing)
          .accessibilityText(this.lt('Sync now'))
          .onClick(() => void this.syncProviders())

          this.buildLoginSearchAnchor()
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .margin({ bottom: 16 })

      this.buildApiNetworkStatus()

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
  private buildApiNetworkStatus() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.apiNetworkStatus === 'online' ? '#22C55E' :
            (this.apiNetworkStatus === 'offline' ? '#EF4444' : '#F59E0B'))
        Text(`${this.lt('API Server')}: ${this.describeApiNetworkStatus()}`)
          .fontSize(13)
          .fontColor(this.apiNetworkStatus === 'offline' ? this.theme_ERROR_TEXT : this.theme_TEXT_SECONDARY)
          .layoutWeight(1)
      }
      .width('100%')

      Text(this.apiNetworkServer)
        .fontSize(11)
        .fontColor(this.theme_TEXT_TERTIARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      if (this.apiNetworkStatus === 'offline' && this.apiNetworkError.length > 0) {
        Text(this.apiNetworkError)
          .fontSize(11)
          .fontColor(this.theme_ERROR_TEXT)
          .maxLines(3)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 12 })
  }

  private describeApiNetworkStatus(): string {
    if (this.apiNetworkStatus === 'online') return this.lt('Available');
    if (this.apiNetworkStatus === 'offline') return this.lt('Unreachable');
    if (this.apiNetworkStatus === 'checking') return this.lt('Connecting...');
    return this.lt('Not checked');
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
        this.dismissSearch();
      })
  }

  @Builder
  private buildLoginSearchAnchor() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('search.svg'))
        .width(18)
        .height(18)
        .fillColor(this.showSearchInput ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
        .onClick(() => {
          if (this.showSearchInput) {
            this.dismissSearch();
          } else if (this.searchText.trim().length > 0) {
            this.searchText = '';
          } else {
            this.openSearch();
          }
        })

      if (this.showSearchInput) {
        TextInput({ placeholder: this.lt('Search'), text: this.searchText })
          .width(140)
          .height(32)
          .fontSize(14)
          .fontColor(this.theme_TEXT_PRIMARY)
          .placeholderColor(this.theme_TEXT_TERTIARY)
          .backgroundColor(this.theme_CARD_BG)
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .id('login-search-input')
          .zIndex(10)
          .position({ x: -122, y: 0 })
          .onChange((value: string) => {
            this.searchText = value;
          })
          .onSubmit(() => {
            this.dismissSearch(false);
          })
          .onBlur(() => {
            this.showSearchInput = false;
          })
      }
    }
    .width(18)
    .height(32)
    .clip(false)
  }

  @Builder
  private buildOAuthLogin() {
    Column({ space: 12 }) {
      ForEach(this.filterProviders(this.availableProviders), (provider: OAuthProvider) => {
        this.buildProviderButton(provider)
      }, (provider: OAuthProvider) => provider.id)

      if (this.filterProviders(this.availableProviders).length === 0) {
        Text(this.lt('No matching results'))
          .fontSize(13)
          .fontColor(this.theme_TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 8 })
      }

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
