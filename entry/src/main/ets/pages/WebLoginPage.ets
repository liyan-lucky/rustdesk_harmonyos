import webview from '@ohos.web.webview';
import { AccountService } from '../services/AccountService';
import { AppState } from '../services/AppState';
import { HttpClient, AuthBody } from '../services/HttpClient';
import { ThemeConfig } from '../common/ThemeConfig';
import { I18nService } from '../services/I18nService';
import { NativeRustDeskBridge } from '../services/NativeRustDeskBridge';
import { PreferenceStore } from '../services/PreferenceStore';

interface WebLoginParams {
  url: string;
  code: string;
  provider: string;
}

@Entry
@Component
struct WebLoginPage {
  private accountService: AccountService = AccountService.getInstance();
  private appState: AppState = AppState.getInstance();
  private httpClient: HttpClient = HttpClient.getInstance();

  @State loginUrl: string = '';
  @State authCode: string = '';
  @State provider: string = '';
  @State isLoading: boolean = true;
  @State errorMessage: string = '';
  @State pollCount: number = 0;
  @State pollTimer: number = -1;
  @State webController: webview.WebviewController = new webview.WebviewController();

  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('themeIsDark') themeIsDark: boolean = false;
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;

  aboutToAppear(): void {
    this.accountService.syncApiServerFromSettings();
    try {
      const params = this.getUIContext().getRouter().getParams() as WebLoginParams;
      if (params?.url) {
        this.loginUrl = params.url;
        this.authCode = params.code ?? '';
        this.provider = params.provider ?? 'github';
        this.startPolling();
      } else {
        this.errorMessage = this.lt('Invalid login parameters');
      }
    } catch (e) {
      console.error('[WebLoginPage] getParams failed:', e);
      this.errorMessage = this.lt('Failed to get login URL');
    }
  }

  aboutToDisappear(): void {
    this.stopPolling();
  }

  build() {
    Column() {
      Row() {
        Button(this.lt('Back'))
          .height(36)
          .backgroundColor(this.theme_CARD_BG)
          .fontColor(this.theme_TEXT_PRIMARY)
          .onClick(() => this.goBack())

        Text(this.lt('GitHub Login'))
          .fontSize(16)
          .fontColor(this.theme_TEXT_PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.isLoading) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(this.theme_ACCENT)
        } else {
          Blank().width(60)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.themeIsDark ? '#2D3139' : '#FFFFFF')

      if (this.errorMessage.length > 0) {
        Column() {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#FCA5A5')
            .textAlign(TextAlign.Center)
          
          Button(this.lt('Retry'))
            .margin({ top: 16 })
            .onClick(() => this.goBack())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Web({ src: this.loginUrl, controller: this.webController })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.None)
          .darkMode(this.themeIsDark ? WebDarkMode.On : WebDarkMode.Off)
          .onPageBegin((url: string) => {
            console.info('[WebLoginPage] onPageBegin:', url);
            this.isLoading = true;
          })
          .onPageEnd((url: string) => {
            console.info('[WebLoginPage] onPageEnd:', url);
            this.isLoading = false;
          })
          .onErrorReceive((event) => {
            console.error('[WebLoginPage] onErrorReceive:', JSON.stringify(event));
            if (event?.error) {
              this.errorMessage = event.error.getErrorInfo();
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
  }

  private startPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
    }

    this.pollTimer = setInterval(async () => {
      this.pollCount++;
      if (this.pollCount >= 180) {
        this.stopPolling();
        this.errorMessage = this.lt('Login timeout, please try again');
        return;
      }

      try {
        const result = await this.httpClient.oidcAuthQuery(this.authCode);
        if (result.success && result.data) {
          const auth_body = result.data.auth_body;
          const failed_msg = result.data.failed_msg;

          if (failed_msg) {
            if (failed_msg === 'No authed oidc is found') {
              return;
            }
            this.stopPolling();
            this.errorMessage = failed_msg;
            return;
          }

          if (auth_body?.access_token) {
            this.stopPolling();
            await this.handleLoginSuccess(auth_body);
          }
        }
      } catch (e) {
        console.error('[WebLoginPage] Poll error:', e);
      }
    }, 1000);
  }

  private stopPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private async handleLoginSuccess(authBody: AuthBody): Promise<void> {
    const access_token = authBody.access_token;
    const user = authBody.user;
    if (!access_token) {
      return;
    }

    NativeRustDeskBridge.setLocalOption('access_token', access_token);
    PreferenceStore.setAccountToken(access_token);
    if (user) {
      const userInfoJson = JSON.stringify(user);
      NativeRustDeskBridge.setLocalOption('user_info', userInfoJson);
      PreferenceStore.setAccountUserInfo(userInfoJson);
    }

    this.appState.setAccount({
      isLoggedIn: true,
      username: user?.name ?? '',
      displayName: user?.display_name ?? user?.name ?? '',
      avatar: user?.avatar ?? '',
      accessToken: access_token,
      provider: user?.third_auth_type ?? this.provider,
      status: 'logged_in',
      loginUrl: '',
      lastError: ''
    });

    await this.accountService.fetchAddressBook();

    try {
      await this.getUIContext().getPromptAction().openToast({
        message: this.lt('Login successful')
      });
    } catch (e) {}

    this.goBack();
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (e) {
      console.error('[WebLoginPage] goBack failed:', e);
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
