import { EventBus, EventType, eventBus } from './EventBus';
import { AppState, AccountState } from './AppState';
import { HttpClient, LoginOption, LoginResponse, CurrentUserResponse, AuthBody, UserInfo, AbResponse, AbPeer, AccessibleUser } from './HttpClient';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { AppContextService } from './AppContextService';
import { AppDataService, AddressBookEntry } from './AppDataService';
import { PreferenceStore } from './PreferenceStore';
import { I18nService } from './I18nService';
import { Logger } from '../common/Logger';

export interface OAuthProvider {
  id: string;
  name: string;
  icon: string;
  color: string;
}

interface LoginProvidersCache {
  apiServer: string;
  providers: OAuthProvider[];
}

interface AccountUsersCache {
  apiServer: string;
  username: string;
  users: AccessibleUser[];
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
  map.set('gitee', createOAuthProvider('gitee', 'Gitee', 'auth-gitee.svg', '#C71D23'));
  map.set('facebook', createOAuthProvider('facebook', 'Facebook', 'auth-facebook.svg', '#1877F2'));
  map.set('microsoft', createOAuthProvider('microsoft', 'Microsoft', 'auth-microsoft.svg', '#00A4EF'));
  map.set('azure', createOAuthProvider('azure', 'Azure', 'auth-azure.svg', '#0078D4'));
  map.set('qq', createOAuthProvider('qq', 'QQ', 'auth-qq.svg', '#12B7F5'));
  map.set('wechat', createOAuthProvider('wechat', 'WeChat', 'auth-wechat.svg', '#07C160'));
  map.set('auth0', createOAuthProvider('auth0', 'Auth0', 'auth-auth0.svg', '#EB5424'));
  map.set('okta', createOAuthProvider('okta', 'Okta', 'auth-okta.svg', '#007DC1'));
  map.set('webauth', createOAuthProvider('webauth', 'WebAuth', 'auth-webauth.svg', '#4A90D9'));
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
  private oauthApiServer: string = '';
  private oauthGeneration: number = 0;
  private readonly MAX_POLL: number = 180;
  private readonly POLL_INTERVAL: number = 500;
  private serviceSyncTimer: number = -1;
  private serviceSyncBusy: boolean = false;
  private providersSyncSucceeded: boolean = true;
  private readonly SERVICE_SYNC_INTERVAL: number = 30000;
  private clearingLoginState: boolean = false;

  private constructor() {
    this.httpClient.setAuthInvalidatedListener((statusCode: number) => {
      this.clearLoginState(`authorization invalid (${statusCode})`);
    });
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
    const effectiveApi = this.appData.getEffectiveServerConfig().apiServer;
    Logger.debug('SYNC', `syncApiServerFromSettings: apiServer="${effectiveApi}"`);
    this.httpClient.setApiServer(effectiveApi);
  }

  getHttpClient(): HttpClient {
    return this.httpClient;
  }

  private async loadSavedToken(): Promise<void> {
    Logger.info('AUTH', 'loadSavedToken: START');
    let token = NativeRustDeskBridge.getLocalOption('access_token').trim();
    let userInfoRaw = NativeRustDeskBridge.getLocalOption('user_info').trim();
    Logger.info('AUTH', `loadSavedToken: native token_len=${token.length}, user_info_len=${userInfoRaw.length}`);
    if (token.length === 0) {
      token = (PreferenceStore.getAccountToken() ?? '').trim();
      Logger.info('AUTH', `loadSavedToken: prefStore token_len=${token.length}`);
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
          Logger.error('AUTH', `Parse user_info failed: ${JSON.stringify(e)}`);
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
      Logger.info('AUTH', `loadSavedToken: restored login for user="${username}", provider="${provider}"`);
      this.loadCachedAccessibleUsers();
      void this.fetchAddressBook();
      void this.startServiceSync();
    } else {
      Logger.info('AUTH', 'loadSavedToken: no saved token found, skipping login restore');
    }
  }

  async getLoginOptions(): Promise<LoginOption[]> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getLoginOptions();
    if (result.success && result.data?.oauth) {
      return result.data.oauth;
    }
    return [];
  }

  getCachedAvailableProviders(): OAuthProvider[] | undefined {
    this.syncApiServerFromSettings();
    const raw = PreferenceStore.getLoginProvidersCache();
    if (!raw) return undefined;
    try {
      const cache = JSON.parse(raw) as LoginProvidersCache;
      return cache.apiServer === this.httpClient.getApiServer() ? cache.providers : undefined;
    } catch (_error) {
      return undefined;
    }
  }

  async getAvailableProviders(): Promise<OAuthProvider[]> {
    const cached = this.getCachedAvailableProviders();
    return cached === undefined ? this.refreshAvailableProviders() : cached;
  }

  async refreshAvailableProviders(): Promise<OAuthProvider[]> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getLoginOptions();
    if (!result.success || !result.data) {
      this.providersSyncSucceeded = false;
      const cached = this.getCachedAvailableProviders();
      return cached ?? (AppDataService.isUsingOfficialServer(this.appData.getSettings()) ? this.getOfficialProviders() : []);
    }
    const options = result.data.oauth ?? [];
    const providers: OAuthProvider[] = [];
    for (const option of options) {
      const providerId = option.op.startsWith('oidc/') ? option.op.substring(5) : option.op;
      if (providerId.length === 0) {
        continue;
      }
      const knownProvider = this.getProviderInfo(providerId);
      if (knownProvider) {
        providers.push(knownProvider);
      } else {
        providers.push(createOAuthProvider(
          providerId,
          option.name && option.name.length > 0 ? option.name : providerId,
          'auth-default.svg',
          '#666666'
        ));
      }
    }
    const resolved = providers.length > 0 ? providers :
      (AppDataService.isUsingOfficialServer(this.appData.getSettings()) ? this.getOfficialProviders() : []);
    const cache: LoginProvidersCache = { apiServer: this.httpClient.getApiServer(), providers: resolved };
    PreferenceStore.setLoginProvidersCache(JSON.stringify(cache));
    this.providersSyncSucceeded = true;
    return resolved;
  }

  didProvidersSyncSucceed(): boolean {
    return this.providersSyncSucceeded;
  }

  getProviderInfo(op: string): OAuthProvider | undefined {
    return OAUTH_PROVIDERS.get(op);
  }

  getAllProviders(): OAuthProvider[] {
    return Array.from(OAUTH_PROVIDERS.values());
  }

  getOfficialProviders(): OAuthProvider[] {
    const ids: string[] = ['github', 'google', 'apple', 'gitlab', 'facebook'];
    const providers: OAuthProvider[] = [];
    for (const id of ids) {
      const provider = OAUTH_PROVIDERS.get(id);
      if (provider) {
        providers.push(provider);
      }
    }
    return providers;
  }

  async loginWithOAuth(provider: string): Promise<boolean> {
    this.resetOAuthTransaction();
    this.syncApiServerFromSettings();
    const generation = this.oauthGeneration;
    const apiServer = this.httpClient.getApiServer();
    this.oauthApiServer = apiServer;
    Logger.debug('AUTH', `loginWithOAuth called with provider: ${provider}`);
    this.pollCount = 0;
    this.appState.setAccount({ status: 'requesting' });

    try {
      const result = await this.httpClient.oidcAuth(provider, apiServer);
      if (generation !== this.oauthGeneration) {
        return false;
      }
      if (!result.success || !result.data) {
        this.appState.setAccount({ status: 'error', lastError: I18nService.getInstance().translate('Auth request failed') });
        return false;
      }

      const code = result.data.code ?? '';
      const url = result.data.url;
      if (!url) {
        this.appState.setAccount({ status: 'error', lastError: I18nService.getInstance().translate('Auth URL not received') });
        return false;
      }

      this.oauthCode = code;
      this.oauthUrl = url;
      this.appState.setAccount({ status: 'waiting', loginUrl: url });
      const opened = await this.openBrowser(url);
      if (!opened) {
        this.appState.setAccount({ status: 'error', lastError: I18nService.getInstance().translate('Cannot open browser') });
        return false;
      }
      this.startOidcPolling(apiServer, generation);
      return true;
    } catch (e) {
      Logger.error('AUTH', `loginWithOAuth error: ${JSON.stringify(e)}`);
      this.appState.setAccount({ status: 'error', lastError: I18nService.getInstance().translate('Auth request error') });
      return false;
    }
  }

  private startOidcPolling(apiServer: string, generation: number): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
    }

    this.pollTimer = setInterval(async () => {
      if (generation !== this.oauthGeneration || apiServer !== this.oauthApiServer) {
        return;
      }
      this.pollCount++;
      if (this.pollCount >= this.MAX_POLL) {
        this.stopPolling();
        this.appState.setAccount({ status: 'error', lastError: I18nService.getInstance().translate('Auth timeout') });
        return;
      }

      try {
        const result = await this.httpClient.oidcAuthQuery(this.oauthCode, apiServer);
        if (generation !== this.oauthGeneration) {
          return;
        }
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
          void this.startServiceSync();
        }
      } catch (e) {
        Logger.error('AUTH', `OIDC poll error: ${JSON.stringify(e)}`);
      }
    }, this.POLL_INTERVAL);
  }

  async loginWithPassword(username: string, password: string): Promise<PasswordLoginResult> {
    this.syncApiServerFromSettings();
    const result = await this.httpClient.login(username, password, true);
    if (!result.success || !result.data) {
      this.eventBus.emit(EventType.SESSION_ERROR, { error: result.error ?? I18nService.getInstance().translate('Login failed') });
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
    Logger.debug('AUTH', `handleLoginSuccess: user="${user?.name ?? ''}", provider="${user?.third_auth_type ?? ''}"`);

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
    void this.fetchAccessibleUsers();
    void this.startServiceSync();
  }

  async fetchAddressBook(): Promise<boolean> {
    Logger.info('SYNC', 'fetchAddressBook start');
    Logger.debug('SYNC', 'fetchAddressBook start');
    this.syncApiServerFromSettings();
    const result = await this.httpClient.getAddressBook();
    Logger.info('SYNC', `getAddressBook: success=${result.success}, peers=${result.data?.peers?.length ?? 0}, groups=${result.data?.groups?.length ?? 0}`);
    Logger.debug('SYNC', `getAddressBook success=${result.success}, peers=${result.data?.peers?.length ?? 0}, groups=${result.data?.groups?.length ?? 0}`);
    if (result.success && result.data) {
      AppStorage.setOrCreate<string>('addressBookServerTags', JSON.stringify(result.data.tags ?? []));
      AppStorage.setOrCreate<string>('addressBookTagColors', result.data.tagColors ?? '{}');
      const entries: AddressBookEntry[] = [];
      const seenIds: Set<string> = new Set<string>();
      const appData = AppDataService.getInstance();
      
      if (result.data.peers) {
        for (const peer of result.data.peers) {
          if (!peer.id || seenIds.has(peer.id)) {
            continue;
          }
          seenIds.add(peer.id);
          const alias = (peer.alias ?? '').trim().length > 0 ? peer.alias!.trim() : (peer.hostname ?? '').trim();
          entries.push({
            id: peer.id,
            alias: alias,
            note: peer.note ?? peer.hostname ?? '',
            group: (peer.tags ?? []).join(', '),
            online: peer.online ?? false,
            favorite: appData.isFavorite(peer.id),
            platform: peer.platform ?? '',
            tags: peer.tags ?? []
          });
        }
      }

      if (result.data.groups) {
        for (const group of result.data.groups) {
          for (const peer of group.peers) {
            if (!peer.id || seenIds.has(peer.id)) {
              continue;
            }
            seenIds.add(peer.id);
            const alias = (peer.alias ?? '').trim().length > 0 ? peer.alias!.trim() : (peer.hostname ?? '').trim();
            entries.push({
              id: peer.id,
              alias: alias,
              note: peer.note ?? peer.hostname ?? '',
              group: group.name,
              online: peer.online ?? false,
              favorite: appData.isFavorite(peer.id),
              platform: peer.platform ?? '',
              tags: peer.tags ?? [group.name]
            });
          }
        }
      }

      const beforeCount = appData.getAddressBook().length;
      appData.mergeAddressBook(entries);
      const afterCount = appData.getAddressBook().length;
      Logger.debug('SYNC', `mergeAddressBook: server=${entries.length}, localBefore=${beforeCount}, localAfter=${afterCount}`);
      Logger.info('SYNC', `fetchAddressBook done: server=${entries.length}, merged=${afterCount}`);
      this.eventBus.emit(EventType.ADDRESS_BOOK_UPDATED, { entries });
      return true;
    } else {
      Logger.info('SYNC', `fetchAddressBook failed: success=${result.success}, error=${result.error ?? 'none'}`);
      return false;
    }
  }

  async fetchAccessibleUsers(): Promise<boolean> {
    this.syncApiServerFromSettings();
    AppStorage.setOrCreate<boolean>('accessibleUsersLoading', true);
    try {
      const result = await this.httpClient.getAccessibleUsers();
      AppStorage.setOrCreate<number>('accessibleUsersStatusCode', result.statusCode ?? 0);
      if (!result.success || !result.data) {
        const error = result.error ?? 'Unable to load users';
        Logger.info('SYNC', `fetchAccessibleUsers failed: status=${result.statusCode ?? 0}, error=${error}`);
        AppStorage.setOrCreate<string>('accessibleUsersError', error);
        return false;
      }
      const currentName = this.appState.getAccount().username;
      const users = result.data;
      users.sort((left: AccessibleUser, right: AccessibleUser) => {
        if (left.name === currentName) return -1;
        if (right.name === currentName) return 1;
        return left.name.localeCompare(right.name);
      });
      AppStorage.setOrCreate<string>('accessibleUsers', JSON.stringify(users));
      AppStorage.setOrCreate<string>('accessibleUsersError', '');
      const cache: AccountUsersCache = {
        apiServer: this.httpClient.getApiServer(),
        username: currentName,
        users: users
      };
      PreferenceStore.setAccountUsersCache(JSON.stringify(cache));
      Logger.info('SYNC', `fetchAccessibleUsers done: users=${users.length}`);
      return true;
    } catch (error) {
      const detail = `Invalid user list response: ${JSON.stringify(error)}`;
      Logger.info('SYNC', `fetchAccessibleUsers failed: ${detail}`);
      AppStorage.setOrCreate<number>('accessibleUsersStatusCode', 0);
      AppStorage.setOrCreate<string>('accessibleUsersError', detail);
      return false;
    } finally {
      AppStorage.setOrCreate<boolean>('accessibleUsersLoading', false);
    }
  }

  loadCachedAccessibleUsers(): boolean {
    this.syncApiServerFromSettings();
    const raw = PreferenceStore.getAccountUsersCache();
    if (!raw) return false;
    try {
      const cache = JSON.parse(raw) as AccountUsersCache;
      if (cache.apiServer !== this.httpClient.getApiServer() || cache.username !== this.appState.getAccount().username) {
        return false;
      }
      AppStorage.setOrCreate<string>('accessibleUsers', JSON.stringify(cache.users));
      AppStorage.setOrCreate<string>('accessibleUsersError', '');
      return true;
    } catch (_error) {
      return false;
    }
  }

  async addAddressBookTag(tag: string, color?: number): Promise<boolean> {
    this.syncApiServerFromSettings();
    return (await this.httpClient.addAddressBookTag(tag, color)).success;
  }

  async renameAddressBookTag(oldTag: string, newTag: string): Promise<boolean> {
    this.syncApiServerFromSettings();
    return (await this.httpClient.renameAddressBookTag(oldTag, newTag)).success;
  }

  async deleteAddressBookTag(tag: string): Promise<boolean> {
    this.syncApiServerFromSettings();
    return (await this.httpClient.deleteAddressBookTag(tag)).success;
  }

  private async startServiceSync(): Promise<void> {
    if (!this.appState.getAccount().isLoggedIn) {
      return;
    }
    this.stopServiceSync();
    await this.syncServiceState(true);
    this.serviceSyncTimer = setInterval(() => {
      void this.syncServiceState(false);
    }, this.SERVICE_SYNC_INTERVAL);
  }

  private stopServiceSync(): void {
    if (this.serviceSyncTimer !== -1) {
      clearInterval(this.serviceSyncTimer);
      this.serviceSyncTimer = -1;
    }
  }

  private async syncServiceState(includeSysinfo: boolean): Promise<void> {
    if (this.serviceSyncBusy || !this.appState.getAccount().isLoggedIn) {
      return;
    }
    this.serviceSyncBusy = true;
    try {
      Logger.debug('SYNC', `syncServiceState: includeSysinfo=${includeSysinfo}`);
      this.syncApiServerFromSettings();
      await this.httpClient.sendHeartbeat();
      if (includeSysinfo) {
        const account = this.appState.getAccount();
        await this.httpClient.syncDeviceSysinfo(account.username);
      }
    } finally {
      this.serviceSyncBusy = false;
    }
  }

  async addPeerToAddressBook(peer: AbPeer): Promise<boolean> {
    Logger.debug('SYNC', `addPeerToAddressBook: id="${peer.id}", alias="${peer.alias ?? ''}"`);
    this.syncApiServerFromSettings();
    const result = await this.httpClient.addAbPeer(peer);
    Logger.debug('SYNC', `addPeerToAddressBook result: success=${result.success}`);
    return result.success;
  }

  async updatePeerInAddressBook(peer: AbPeer): Promise<boolean> {
    Logger.debug('SYNC', `updatePeerInAddressBook: id="${peer.id}", alias="${peer.alias ?? ''}"`);
    this.syncApiServerFromSettings();
    const result = await this.httpClient.updateAbPeer(peer);
    Logger.debug('SYNC', `updatePeerInAddressBook result: success=${result.success}`);
    return result.success;
  }

  async deletePeerFromAddressBook(peerId: string): Promise<boolean> {
    Logger.debug('SYNC', `deletePeerFromAddressBook: id="${peerId}"`);
    this.syncApiServerFromSettings();
    const result = await this.httpClient.deleteAbPeer(peerId);
    Logger.debug('SYNC', `deletePeerFromAddressBook result: success=${result.success}`);
    return result.success;
  }

  private async openBrowser(url: string): Promise<boolean> {
    Logger.debug('AUTH', `openBrowser called with URL: ${url}`);
    try {
      const context = AppContextService.getContext();
      if (!context) {
        Logger.error('AUTH', 'No context available');
        return false;
      }

      try {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.default', 'entity.browsable'],
          uri: url,
          flags: 0x10000000
        });
        Logger.debug('AUTH', 'Browser opened via implicit Intent');
        return true;
      } catch (e) {
        Logger.debug('AUTH', `Implicit Intent failed: ${JSON.stringify(e)}`);
      }

      try {
        await context.openLink(url);
        Logger.debug('AUTH', 'Browser opened via openLink');
        return true;
      } catch (e) {
        Logger.debug('AUTH', `openLink failed: ${JSON.stringify(e)}`);
      }

      try {
        await context.startAbility({
          bundleName: 'com.huawei.browser',
          abilityName: 'MainAbility',
          uri: url,
          flags: 0x10000000
        });
        Logger.debug('AUTH', 'Huawei Browser launched');
        return true;
      } catch (e) {
        Logger.debug('AUTH', `Huawei Browser failed: ${JSON.stringify(e)}`);
      }

      Logger.error('AUTH', 'All browser launch methods failed');
      return false;
    } catch (error) {
      Logger.error('AUTH', `openBrowser error: ${JSON.stringify(error)}`);
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

  private resetOAuthTransaction(): void {
    this.stopPolling();
    this.oauthGeneration++;
    this.oauthApiServer = '';
    this.oauthCode = '';
    this.oauthUrl = '';
  }

  cancelLogin(): void {
    this.resetOAuthTransaction();
    NativeRustDeskBridge.accountAuthCancel();
    this.appState.setAccount({ status: 'idle', lastError: '', loginUrl: '' });
  }



  async reopenBrowser(): Promise<boolean> {
    if (this.oauthUrl.length === 0) {
      return false;
    }
    return this.openBrowser(this.oauthUrl);
  }

  async openExternalUrl(url: string): Promise<boolean> {
    return this.openBrowser(url);
  }

  async logout(): Promise<void> {
    this.stopServiceSync();
    this.syncApiServerFromSettings();
    await this.httpClient.logout();
    this.clearLoginState('user logout');
  }

  private clearLoginState(reason: string): void {
    if (this.clearingLoginState) {
      return;
    }
    this.clearingLoginState = true;
    Logger.info('ACCOUNT', `Clearing login state: ${reason}`);
    this.stopServiceSync();
    this.resetOAuthTransaction();
    NativeRustDeskBridge.accountAuthCancel();
    NativeRustDeskBridge.setLocalOption('access_token', '');
    NativeRustDeskBridge.setLocalOption('user_info', '');
    PreferenceStore.setAccountToken('');
    PreferenceStore.setAccountUserInfo('');
    PreferenceStore.setAccountUsersCache('');
    AppStorage.setOrCreate<string>('accessibleUsers', '[]');
    AppStorage.setOrCreate<string>('accessibleUsersError', '');
    AppStorage.setOrCreate<number>('accessibleUsersStatusCode', 0);
    AppStorage.setOrCreate<boolean>('accessibleUsersLoading', false);

    this.appData.setAddressBook([]);

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
    this.clearingLoginState = false;
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
    } else if (result.statusCode === 401 || result.statusCode === 406) {
      this.clearLoginState(`refresh rejected (${result.statusCode})`);
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
