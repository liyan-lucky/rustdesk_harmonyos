import { EventBus, EventType, eventBus } from './EventBus';
import { AppState, AccountState } from './AppState';
import { HttpClient, LoginOption, LoginResponse, CurrentUserResponse, AuthBody, UserInfo, AbResponse, AbPeer } from './HttpClient';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { AppContextService } from './AppContextService';
import { AppDataService, AddressBookEntry } from './AppDataService';
import { PreferenceStore } from './PreferenceStore';

export interface OAuthProvider {
  id: string;
  name: string;
  icon: string;
  color: string;
}

class OAuthProviderImpl implements OAuthProvider {
  id: string = '';
  name: string = '';
  icon: string = '';
  color: string = '';
}

function createOAuthProvider(id: string, name: string, icon: string, color: string): OAuthProvider {
  const provider = new OAuthProviderImpl();
  provider.id = id;
  provider.name = name;
  provider.icon = icon;
  provider.color = color;
  return provider;
}

function initOAuthProviders(): Map<string, OAuthProvider> {
  const map = new Map<string, OAuthProvider>();
  map.set('github', createOAuthProvider('github', 'GitHub', 'auth-github.svg', '#333333'));
  map.set('google', createOAuthProvider('google', 'Google', 'auth-google.svg', '#4285F4'));
  map.set('apple', createOAuthProvider('apple', 'Apple', 'auth-apple.svg', '#000000'));
  map.set('gitlab', createOAuthProvider('gitlab', 'GitLab', 'auth-gitlab.svg', '#FC6D26'));
  map.set('facebook', createOAuthProvider('facebook', 'Facebook', 'auth-facebook.svg', '#1877F2'));
  map.set('microsoft', createOAuthProvider('microsoft', 'Microsoft', 'auth-microsoft.svg', '#00A4EF'));
  map.set('azure', createOAuthProvider('azure', 'Azure', 'auth-azure.svg', '#0078D4'));
  map.set('auth0', createOAuthProvider('auth0', 'Auth0', 'auth-auth0.svg', '#EB5424'));
  map.set('okta', createOAuthProvider('okta', 'Okta', 'auth-okta.svg', '#007DC1'));
  return map;
}

const OAUTH_PROVIDERS: Map<string, OAuthProvider> = initOAuthProviders();

export interface PasswordLoginResult {
  success: boolean;
  emailCheck?: boolean;
  tfaCheck?: boolean;
}

class PasswordLoginResultImpl implements PasswordLoginResult {
  success: boolean = false;
  emailCheck?: boolean = false;
  tfaCheck?: boolean = false;
}

export { AccountState } from './AppState';

export class AccountService {
  private static instance: AccountService;
  private eventBus: EventBus = EventBus.getInstance();
  private appState: AppState = AppState.getInstance();
  private httpClient: HttpClient = HttpClient.getInstance();
  private appData: AppDataService = AppDataService.getInstance();

  private oauthCode: string = '';
  private oauthUrl: string = '';
  private pollTimer: number = -1;
  private pollCount: number = 0;
  private readonly MAX_POLL: number = 180;
  private readonly POLL_INTERVAL: number = 500;

  private constructor() {
    this.loadSavedToken();
  }

  static getInstance(): AccountService {
    if (!AccountService.instance) {
      AccountService.instance = new AccountService();
    }
    return AccountService.instance;
  }

  setApiServer(apiServer: string): void {
    this.httpClient.setApiServer(apiServer);
  }

  syncApiServerFromSettings(): void {
    this.httpClient.setApiServer(this.appData.getEffectiveServerConfig().apiServer);
  }

  getHttpClient(): HttpClient {
    return this.httpClient;
  }

  private async loadSavedToken(): Promise<void> {
    let token = NativeRustDeskBridge.getLocalOption('access_token').trim();
    let userInfoRaw = NativeRustDeskBridge.getLocalOption('user_info').trim();
    if (token.length === 0) {
      token = (PreferenceStore.getAccountToken() ?? '').trim();
      if (token.length > 0) {
        NativeRustDeskBridge.setLocalOption('access_token', token);
      }
    }
    if (userInfoRaw.length === 0) {
      userInfoRaw = (PreferenceStore.getAccountUserInfo() ?? '').trim();
      if (userInfoRaw.length > 0) {
        NativeRustDeskBridge.setLocalOption('user_info', userInfoRaw);
      }
    }

    if (token.length > 0) {
      let username = '';
      let displayName = '';
      let avatar = '';
      let provider = '';

      if (userInfoRaw.length > 0) {
        try {
          const user = JSON.parse(userInfoRaw) as UserInfo;
          username = user.name ?? '';
          displayName = user.display_name ?? user.name ?? '';
          avatar = user.avatar ?? '';
          provider = user.third_auth_type ?? '';
        } catch (e) {
          console.error('[AccountService] Parse user_info failed:', e);
        }
      }

      this.appState.setAccount({
        isLoggedIn: true,
        username: username,
        displayName: displayName,
        avatar: avatar,
        accessToken: token,
        provider: provider
      });
    }
  }

  async getLoginOptions(): Promise<LoginOption[]> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getLoginOptions();
    if (result.success && result.data?.oauth) {
      return result.data.oauth;
    }
    const defaultOption = new LoginOption();
    defaultOption.op = 'github';
    defaultOption.name = 'GitHub';
    return [defaultOption];
  }

  getProviderInfo(op: string): OAuthProvider | undefined {
    return OAUTH_PROVIDERS.get(op);
  }

  getAllProviders(): OAuthProvider[] {
    return Array.from(OAUTH_PROVIDERS.values());
  }

  async loginWithOAuth(provider: string): Promise<boolean> {
    this.syncApiServerFromSettings();
    console.info('[AccountService] loginWithOAuth called with provider:', provider);
    this.pollCount = 0;
    this.appState.setAccount({ status: 'requesting' });

    try {
      const result = await this.httpClient.oidcAuth(provider, true);
      if (!result.success || !result.data) {
        this.appState.setAccount({ status: 'error', lastError: result.error ?? '认证请求失败' });
        return false;
      }

      const code = result.data.code ?? '';
      const url = result.data.url;
      if (!url) {
        this.appState.setAccount({ status: 'error', lastError: '未获取到认证URL' });
        return false;
      }

      this.oauthCode = code;
      this.oauthUrl = url;
      this.appState.setAccount({ status: 'waiting', loginUrl: url });

      const opened = await this.openBrowser(url);
      if (!opened) {
        this.appState.setAccount({ status: 'error', lastError: '无法打开浏览器' });
        return false;
      }

      this.startOidcPolling();
      return true;
    } catch (e) {
      console.error('[AccountService] loginWithOAuth error:', e);
      this.appState.setAccount({ status: 'error', lastError: '认证请求异常' });
      return false;
    }
  }

  private startOidcPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
    }

    this.pollTimer = setInterval(async () => {
      this.pollCount++;
      if (this.pollCount >= this.MAX_POLL) {
        this.stopPolling();
        this.appState.setAccount({ status: 'error', lastError: '认证超时' });
        return;
      }

      try {
        const result = await this.httpClient.oidcAuthQuery(this.oauthCode);
        if (!result.success || !result.data) {
          return;
        }

        const failedMsg = result.data.failed_msg;
        const authBody = result.data.auth_body;

        if (failedMsg) {
          if (failedMsg === 'No authed oidc is found') {
            return;
          }
          this.stopPolling();
          this.appState.setAccount({ status: 'error', lastError: failedMsg });
          return;
        }

        if (authBody && authBody.access_token) {
          this.stopPolling();
          this.oauthUrl = '';
          const token = authBody.access_token;
          const user = authBody.user;
          NativeRustDeskBridge.setLocalOption('access_token', token);
          PreferenceStore.setAccountToken(token);
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
            accessToken: token,
            provider: user?.third_auth_type ?? '',
            status: 'logged_in',
            loginUrl: '',
            lastError: ''
          });
          void this.fetchAddressBook();
        }
      } catch (e) {
        console.error('[AccountService] OIDC poll error:', e);
      }
    }, this.POLL_INTERVAL);
  }

  async loginWithPassword(username: string, password: string): Promise<PasswordLoginResult> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.login(username, password, true);
    if (!result.success || !result.data) {
      this.eventBus.emit(EventType.SESSION_ERROR, { error: result.error ?? '登录失败' });
      const r = new PasswordLoginResultImpl();
      r.success = false;
      return r;
    }

    const data = result.data;
    if (data.email_check) {
      const r = new PasswordLoginResultImpl();
      r.success = false;
      r.emailCheck = true;
      return r;
    }
    if (data.tfa_check) {
      const r = new PasswordLoginResultImpl();
      r.success = false;
      r.tfaCheck = true;
      return r;
    }
    if (data.access_token) {
      await this.handleLoginSuccess(data);
      const r = new PasswordLoginResultImpl();
      r.success = true;
      return r;
    }

    const r = new PasswordLoginResultImpl();
    r.success = false;
    return r;
  }

  async verifyEmail(code: string): Promise<boolean> {
    const result = await this.httpClient.verifyEmailVerification(code);
    if (result.success && result.data?.access_token) {
      await this.handleLoginSuccess(result.data);
      return true;
    }
    return false;
  }

  async verifyTfa(code: string): Promise<boolean> {
    const result = await this.httpClient.verifyTfa(code);
    if (result.success && result.data?.access_token) {
      await this.handleLoginSuccess(result.data);
      return true;
    }
    return false;
  }

  private async handleLoginSuccess(data: LoginResponse): Promise<void> {
    const access_token = data.access_token;
    const user = data.user;
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
      provider: user?.third_auth_type ?? '',
      status: 'logged_in',
      loginUrl: '',
      lastError: ''
    });

    void this.fetchAddressBook();
  }

  async fetchAddressBook(): Promise<void> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getAddressBook();
    if (result.success && result.data) {
      const entries: AddressBookEntry[] = [];
      
      if (result.data.peers) {
        for (const peer of result.data.peers) {
          const alias = (peer.alias ?? '').trim().length > 0 ? peer.alias!.trim() : (peer.hostname ?? '').trim();
          entries.push({
            id: peer.id,
            alias: alias,
            note: peer.hostname ?? '',
            group: (peer.tags ?? []).join(', '),
            online: peer.online ?? false,
            favorite: false,
            platform: peer.platform ?? ''
          });
        }
      }

      if (result.data.groups) {
        for (const group of result.data.groups) {
          for (const peer of group.peers) {
            const alias = (peer.alias ?? '').trim().length > 0 ? peer.alias!.trim() : (peer.hostname ?? '').trim();
            entries.push({
              id: peer.id,
              alias: alias,
              note: peer.hostname ?? '',
              group: group.name,
              online: peer.online ?? false,
              favorite: false,
              platform: peer.platform ?? ''
            });
          }
        }
      }

      if (entries.length > 0) {
        AppDataService.getInstance().setAddressBook(entries);
        this.eventBus.emit(EventType.ADDRESS_BOOK_UPDATED, { entries });
      }
    }
  }

  async addPeerToAddressBook(peer: AbPeer): Promise<boolean> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.addAbPeer(peer);
    if (result.success) {
      void this.fetchAddressBook();
      return true;
    }
    return false;
  }

  async updatePeerInAddressBook(peer: AbPeer): Promise<boolean> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.updateAbPeer(peer);
    if (result.success) {
      void this.fetchAddressBook();
      return true;
    }
    return false;
  }

  async deletePeerFromAddressBook(peerId: string): Promise<boolean> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.deleteAbPeer(peerId);
    if (result.success) {
      void this.fetchAddressBook();
      return true;
    }
    return false;
  }

  private async openBrowser(url: string): Promise<boolean> {
    console.info('[AccountService] openBrowser called with URL:', url);
    try {
      const context = AppContextService.getContext();
      if (!context) {
        console.error('[AccountService] No context available');
        return false;
      }

      try {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.default', 'entity.browsable'],
          uri: url,
          flags: 0x10000000
        });
        console.info('[AccountService] Browser opened via implicit Intent');
        return true;
      } catch (e) {
        console.info('[AccountService] Implicit Intent failed:', JSON.stringify(e));
      }

      try {
        await context.openLink(url);
        console.info('[AccountService] Browser opened via openLink');
        return true;
      } catch (e) {
        console.info('[AccountService] openLink failed:', JSON.stringify(e));
      }

      try {
        await context.startAbility({
          bundleName: 'com.huawei.browser',
          abilityName: 'MainAbility',
          uri: url,
          flags: 0x10000000
        });
        console.info('[AccountService] Huawei Browser launched');
        return true;
      } catch (e) {
        console.info('[AccountService] Huawei Browser failed:', JSON.stringify(e));
      }

      console.error('[AccountService] All browser launch methods failed');
      return false;
    } catch (error) {
      console.error('[AccountService] openBrowser error:', JSON.stringify(error));
      return false;
    }
  }

  private stopPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    this.pollCount = 0;
  }

  cancelLogin(): void {
    this.stopPolling();
    NativeRustDeskBridge.accountAuthCancel();
    this.oauthUrl = '';
    this.appState.setAccount({ status: 'idle', lastError: '', loginUrl: '' });
  }



  async reopenBrowser(): Promise<boolean> {
    if (this.oauthUrl.length === 0) {
      return false;
    }
    return this.openBrowser(this.oauthUrl);
  }

  async logout(): Promise<void> {
    this.syncApiServerFromSettings();
    await this.httpClient.logout();
    NativeRustDeskBridge.setLocalOption('access_token', '');
    NativeRustDeskBridge.setLocalOption('user_info', '');
    PreferenceStore.setAccountToken('');
    PreferenceStore.setAccountUserInfo('');

    AppDataService.getInstance().setAddressBook([]);

    this.appState.setAccount({
      isLoggedIn: false,
      username: '',
      displayName: '',
      avatar: '',
      accessToken: '',
      provider: '',
      loginUrl: '',
      status: 'idle',
      lastError: ''
    });
  }

  async refreshUser(): Promise<void> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getCurrentUser();
    if (result.success && result.data) {
      NativeRustDeskBridge.setLocalOption('user_info', JSON.stringify(result.data));
      this.appState.setAccount({
        username: result.data.name ?? '',
        displayName: result.data.display_name ?? result.data.name ?? '',
        avatar: result.data.avatar ?? ''
      });
    } else if (result.statusCode === 401 || result.statusCode === 400) {
      await this.logout();
    }
  }

  isLoggedIn(): boolean {
    return this.appState.getAccount().isLoggedIn;
  }

  getDisplayName(): string {
    return this.appState.getAccount().displayName;
  }

  isPolling(): boolean {
    return this.pollTimer !== -1;
  }
}

export const accountService = AccountService.getInstance();
