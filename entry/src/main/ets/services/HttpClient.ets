import http from '@ohos.net.http';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { AppDataService } from './AppDataService';
import { Logger } from '../common/Logger';

export interface HttpResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  statusCode?: number;
}

export type ApiNetworkStatus = 'idle' | 'checking' | 'online' | 'offline';

export class LoginOption {
  op: string = '';
  name: string = '';
}

export interface LoginOptionsResponse {
  oauth: LoginOption[];
}

class LoginOptionsResponseImpl implements LoginOptionsResponse {
  oauth: LoginOption[] = [];
}

export interface OidcAuthRequest {
  op: string;
  id: string;
  uuid: string;
  deviceInfo: LoginDeviceInfo;
}

class LoginDeviceInfo {
  os: string = 'ohos';
  type: string = 'client';
  name: string = '';
}

class OidcAuthRequestImpl implements OidcAuthRequest {
  op: string = '';
  id: string = '';
  uuid: string = '';
  deviceInfo: LoginDeviceInfo = new LoginDeviceInfo();
}

export interface OidcAuthResponse {
  code?: string;
  url?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
  remember_me: boolean;
}

class LoginRequestImpl implements LoginRequest {
  username: string = '';
  password: string = '';
  remember_me: boolean = false;
}

export interface VerifyCodeRequest {
  code: string;
}

class VerifyCodeRequestImpl implements VerifyCodeRequest {
  code: string = '';
}

export interface AuthQueryResponse {
  auth_body?: AuthBody;
  state_msg?: string;
  failed_msg?: string;
}

export interface AuthBody {
  access_token?: string;
  type?: string;
  user?: UserInfo;
}

export interface UserInfo {
  name?: string;
  display_name?: string;
  avatar?: string;
  email?: string;
  status?: number;
  third_auth_type?: string;
}

export interface LoginResponse {
  access_token?: string;
  type?: string;
  user?: UserInfo;
  email_check?: boolean;
  tfa_check?: boolean;
}

export interface CurrentUserResponse {
  name?: string;
  display_name?: string;
  avatar?: string;
  email?: string;
  status?: number;
}

export interface AbPeer {
  id: string;
  hash?: string;
  username?: string;
  alias?: string;
  hostname?: string;
  note?: string;
  platform?: string;
  tags?: string[];
  online?: boolean;
}

export interface AbGroup {
  name: string;
  peers: AbPeer[];
}

export interface AbResponse {
  peers?: AbPeer[];
  groups?: AbGroup[];
  tags?: string[];
  tagColors?: string;
}

export interface AbTag {
  name: string;
  color: number;
}

class AbTagCreateRequest {
  name: string = '';
  color: number = 0;
}

class AbTagRenameRequest {
  old: string = '';
  new: string = '';
}

class PersonalAddressBookResponse {
  guid: string = '';
}

interface PagedPeersResponse {
  total: number;
  data: AbPeer[];
}

export interface AccessibleUser {
  name: string;
  display_name?: string;
  avatar?: string;
  email?: string;
  note?: string;
  status?: number;
  is_admin?: boolean;
}

interface PagedUsersResponse {
  total: number;
  data: AccessibleUser[];
}

class LegacyAddressBookData {
  tags: string[] = [];
  peers: AbPeer[] = [];
  tag_colors: string = '{}';
}

class LegacyAddressBookReplaceRequest {
  data: string = '';
}

class DeviceSysinfoRequest {
  cpu: string = '';
  hostname: string = '';
  id: string = '';
  memory: string = '';
  os: string = 'HarmonyOS';
  username: string = '';
  uuid: string = '';
  version: string = '';
}

class HeartbeatRequest {
  id: string = '';
  uuid: string = '';
  modified_at: number = 0;
  ver: number = 0;
  conns: number[] = [];
}

export interface AbTagRequest {
  tags: string[];
}

class AbTagRequestImpl implements AbTagRequest {
  tags: string[] = [];
}

export class HttpClient {
  private static instance: HttpClient;
  private baseUrl: string = AppDataService.OFFICIAL_API_SERVER;
  private timeout: number = 30000;
  private personalAddressBookGuid: string = '';
  private authInvalidatedListener?: (statusCode: number) => void;

  private constructor() {
    this.publishNetworkState('idle', '', this.baseUrl);
  }

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  setApiServer(apiServer: string): void {
    const normalized = apiServer.trim();
    this.baseUrl = normalized.length > 0 ? normalized : AppDataService.OFFICIAL_API_SERVER;
    this.personalAddressBookGuid = '';
    this.publishNetworkState('idle', '', this.baseUrl);
    Logger.debug('HTTP', `setApiServer: input="${apiServer}" → baseUrl="${this.baseUrl}"`);
  }

  getApiServer(): string {
    return this.baseUrl;
  }

  setAuthInvalidatedListener(listener: (statusCode: number) => void): void {
    this.authInvalidatedListener = listener;
  }

  private getAccessToken(): string {
    return NativeRustDeskBridge.getLocalOption('access_token').trim();
  }

  private async request<T>(
    method: http.RequestMethod,
    path: string,
    body?: Object,
    apiServer?: string
  ): Promise<HttpResult<T>> {
    const httpRequest = http.createHttp();
    const url = `${apiServer ?? this.baseUrl}${path}`;
    const requestStartedAt = Date.now();
    const logUrl = this.redactUrlForLog(url);
    const accessToken = this.getAccessToken();
    this.publishNetworkState('checking', '', apiServer ?? this.baseUrl);

    Logger.debug('HTTP', `${method === http.RequestMethod.GET ? 'GET' : 'POST'} ${logUrl}`);
    if (body) {
      Logger.debug('HTTP', `body: ${this.redactForLog(body)}`);
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    if (accessToken.length > 0) {
      headers['Authorization'] = `Bearer ${accessToken}`;
    }

    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        connectTimeout: this.timeout,
        readTimeout: this.timeout,
        expectDataType: http.HttpDataType.OBJECT
      };

      if (body) {
        options.extraData = body;
      }

      const response = await httpRequest.request(url, options);
      const statusCode = response.responseCode;
      // Any HTTP response proves that the configured API endpoint is reachable.
      this.publishNetworkState('online', '', apiServer ?? this.baseUrl, Date.now() - requestStartedAt);

      Logger.debug('HTTP', `Response status: ${statusCode}`);

      if (statusCode >= 200 && statusCode < 300) {
        const data = response.result as T;
        Logger.debug('HTTP', `Response data: ${this.redactForLog(response.result)}`);
        return { success: true, data, statusCode };
      }

      if (statusCode === 401 || statusCode === 406) {
        Logger.error('HTTP', `Auth failed: ${statusCode}`);
        if (accessToken.length > 0 && this.authInvalidatedListener) {
          this.authInvalidatedListener(statusCode);
        }
        return { success: false, error: '认证失败，请重新登录', statusCode };
      }

      const errorMsg = this.parseError(response.result);
      Logger.error('HTTP', `Error: ${errorMsg}, status: ${statusCode}`);
      return { success: false, error: errorMsg, statusCode };
    } catch (error) {
      const errorMsg = `网络请求失败: ${JSON.stringify(error)}`;
      Logger.error('HTTP', `Exception: ${errorMsg}`);
      this.publishNetworkState('offline', this.describeNetworkError(error), apiServer ?? this.baseUrl);
      return { success: false, error: errorMsg };
    } finally {
      httpRequest.destroy();
    }
  }

  private publishNetworkState(status: ApiNetworkStatus, error: string, server: string, latencyMs: number = -1): void {
    AppStorage.setOrCreate<string>('apiNetworkStatus', status);
    AppStorage.setOrCreate<string>('apiNetworkServer', server);
    AppStorage.setOrCreate<string>('apiNetworkError', error);
    AppStorage.setOrCreate<number>('apiNetworkLatencyMs', latencyMs);
    AppStorage.setOrCreate<number>('apiNetworkUpdatedAt', Date.now());
  }

  private describeNetworkError(error: Object): string {
    const detail = JSON.stringify(error);
    if (detail.includes('2300028') || detail.toLowerCase().includes('timeout')) {
      return 'Connection timed out. Check the server address and IPv4/IPv6 connectivity.';
    }
    return detail.length > 0 ? detail : 'Unable to reach the API server.';
  }

  private parseError(result: Object | string | undefined): string {
    if (!result) {
      return '未知错误';
    }
    if (typeof result === 'string') {
      return result;
    }
    if (typeof result === 'object') {
      const obj = result as Record<string, Object>;
      if (obj.error) {
        return String(obj.error);
      }
      if (obj.message) {
        return String(obj.message);
      }
    }
    return '请求失败';
  }

  private redactForLog(value: Object | string | undefined): string {
    if (value === undefined) {
      return '';
    }
    try {
      const text = typeof value === 'string' ? value : JSON.stringify(value);
      return text
        .replace(/("(?:password|access_token|token|uuid)"\s*:\s*")[^"]*(")/gi, '$1***$2')
        .substring(0, 200);
    } catch (_error) {
      return '[unserializable]';
    }
  }

  private redactUrlForLog(url: string): string {
    return url.replace(/([?&](?:code|uuid|token|access_token)=)[^&]*/gi, '$1***');
  }

  async get<T>(path: string): Promise<HttpResult<T>> {
    return this.request<T>(http.RequestMethod.GET, path);
  }

  async post<T>(path: string, body?: Object): Promise<HttpResult<T>> {
    return this.request<T>(http.RequestMethod.POST, path, body);
  }

  async put<T>(path: string, body?: Object): Promise<HttpResult<T>> {
    return this.request<T>(http.RequestMethod.PUT, path, body);
  }

  async delete<T>(path: string, body?: Object): Promise<HttpResult<T>> {
    return this.request<T>(http.RequestMethod.DELETE, path, body);
  }

  async getLoginOptions(): Promise<HttpResult<LoginOptionsResponse>> {
    const rawResult = await this.get<Record<string, Object>>('/api/login-options');
    if (!rawResult.success || !rawResult.data) {
      const failResp = new LoginOptionsResponseImpl();
      failResp.oauth = [];
      return { success: false, data: failResp, error: rawResult.error, statusCode: rawResult.statusCode };
    }

    const raw = rawResult.data;
    const oauth: LoginOption[] = [];

    if (Array.isArray(raw)) {
      for (const item of raw as string[]) {
        if (typeof item === 'string' && item.startsWith('common-oidc/')) {
          try {
            const commonOptions = JSON.parse(item.substring('common-oidc/'.length)) as LoginOption[];
            for (const commonOption of commonOptions) {
              if (commonOption.name && commonOption.name.length > 0) {
                const opt = new LoginOption();
                opt.op = commonOption.name;
                opt.name = commonOption.name;
                oauth.push(opt);
              }
            }
          } catch (error) {
            Logger.warn('HTTP', 'Invalid common OIDC login options: ' + JSON.stringify(error));
          }
          break;
        } else if (typeof item === 'string' && item.startsWith('oidc/')) {
          const opt = new LoginOption();
          opt.op = item;
          opt.name = item.substring(5);
          oauth.push(opt);
        }
      }
    } else if (raw['oauth'] && Array.isArray(raw['oauth'])) {
      for (const item of raw['oauth'] as LoginOption[]) {
        if (item.op && item.op.length > 0) {
          oauth.push(item);
        }
      }
    }

    const response = new LoginOptionsResponseImpl();
    response.oauth = oauth;
    return { success: true, data: response, statusCode: rawResult.statusCode };
  }

  private getDeviceId(): string {
    let id = NativeRustDeskBridge.getLocalOption('id').trim();
    if (id.length === 0) {
      id = AppStorage.get<string>('myDeviceId') ?? '';
    }
    return id;
  }

  private getDeviceUuid(): string {
    let uuid = NativeRustDeskBridge.mainGetUuid().trim();
    if (uuid.length === 0) {
      uuid = NativeRustDeskBridge.getLocalOption('uuid').trim();
    }
    if (uuid.length === 0) {
      uuid = AppStorage.get<string>('myDeviceUuid') ?? '';
    }
    return uuid;
  }

  private getLoginDeviceInfo(): LoginDeviceInfo {
    const info = new LoginDeviceInfo();
    const raw = NativeRustDeskBridge.mainGetLoginDeviceInfo().trim();
    try {
      if (raw.length > 0) {
        const parsed = JSON.parse(raw) as Record<string, string>;
        info.os = parsed['os'] ?? info.os;
        info.type = parsed['type'] ?? info.type;
        info.name = parsed['name'] ?? '';
      }
    } catch (error) {
      Logger.warn('HTTP', `Invalid login device info: ${JSON.stringify(error)}`);
    }
    if (info.name.length === 0) {
      info.name = this.getDeviceId();
    }
    return info;
  }

  async oidcAuth(op: string, apiServer?: string): Promise<HttpResult<OidcAuthResponse>> {
    const body = new OidcAuthRequestImpl();
    body.op = op;
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuid();
    body.deviceInfo = this.getLoginDeviceInfo();
    Logger.debug('AUTH', `oidcAuth: op=${body.op}, id=${body.id}, uuid_len=${body.uuid.length}`);
    return this.request<OidcAuthResponse>(http.RequestMethod.POST, '/api/oidc/auth', body, apiServer);
  }

  async oidcAuthQuery(code: string, apiServer?: string): Promise<HttpResult<AuthQueryResponse>> {
    const id = this.getDeviceId();
    const uuid = this.getDeviceUuid();
    Logger.debug('AUTH', `oidcAuthQuery: code_len=${code.length}, id=${id}, uuid_len=${uuid.length}`);
    const path = `/api/oidc/auth-query?code=${encodeURIComponent(code)}&id=${encodeURIComponent(id)}&uuid=${encodeURIComponent(uuid)}`;
    const rawResult = await this.request<Record<string, Object>>(http.RequestMethod.GET, path, undefined, apiServer);

    if (!rawResult.success || !rawResult.data) {
      return rawResult as HttpResult<AuthQueryResponse>;
    }

    let raw = rawResult.data as Record<string, Object>;

    if (typeof raw['body'] === 'string') {
      try {
        raw = JSON.parse(raw['body'] as string) as Record<string, Object>;
      } catch (e) {
        Logger.warn('HTTP', `Failed to parse nested body string: ${JSON.stringify(e)}`);
      }
    }
    const adapted: AuthQueryResponse = {};

    if (raw['access_token']) {
      adapted.auth_body = {
        access_token: String(raw['access_token']),
        type: raw['type'] ? String(raw['type']) : 'access_token',
        user: raw['user'] as UserInfo
      };
    } else if (raw['auth_body']) {
      adapted.auth_body = raw['auth_body'] as AuthBody;
    }

    if (raw['failed_msg']) {
      adapted.failed_msg = String(raw['failed_msg']);
    } else if (raw['error']) {
      adapted.failed_msg = String(raw['error']);
    }

    if (raw['state_msg']) {
      adapted.state_msg = String(raw['state_msg']);
    }

    Logger.debug('AUTH', `oidcAuthQuery adapted: auth_body=${adapted.auth_body ? 'yes' : 'no'}, failed_msg=${adapted.failed_msg ?? 'none'}`);
    return { success: true, data: adapted, statusCode: rawResult.statusCode };
  }

  async login(username: string, password: string, rememberMe: boolean = false): Promise<HttpResult<LoginResponse>> {
    const body = new LoginRequestImpl();
    body.username = username;
    body.password = password;
    body.remember_me = rememberMe;
    return this.post<LoginResponse>('/api/login', body);
  }

  async getCurrentUser(): Promise<HttpResult<CurrentUserResponse>> {
    return this.post<CurrentUserResponse>('/api/currentUser');
  }

  async logout(): Promise<HttpResult<void>> {
    return this.post<void>('/api/logout');
  }

  async verifyEmailVerification(emailCode: string): Promise<HttpResult<LoginResponse>> {
    const body = new VerifyCodeRequestImpl();
    body.code = emailCode;
    return this.post<LoginResponse>('/api/email-verification', body);
  }

  async verifyTfa(tfaCode: string): Promise<HttpResult<LoginResponse>> {
    const body = new VerifyCodeRequestImpl();
    body.code = tfaCode;
    return this.post<LoginResponse>('/api/tfa-verification', body);
  }

  async getAddressBook(): Promise<HttpResult<AbResponse>> {
    const personal = await this.post<PersonalAddressBookResponse>('/api/ab/personal');
    if (personal.success && personal.data && personal.data.guid.trim().length > 0) {
      this.personalAddressBookGuid = personal.data.guid.trim();
      return this.getModernAddressBook(this.personalAddressBookGuid);
    }
    if (personal.statusCode !== 404) {
      return { success: false, error: personal.error, statusCode: personal.statusCode };
    }
    this.personalAddressBookGuid = '';
    return this.getLegacyAddressBook();
  }

  private async getLegacyAddressBook(): Promise<HttpResult<AbResponse>> {
    const rawResult = await this.get<Record<string, Object>>('/api/ab');
    if (!rawResult.success || !rawResult.data) {
      return rawResult as HttpResult<AbResponse>;
    }

    let raw = rawResult.data;
    if (typeof raw['data'] === 'string') {
      try {
        raw = JSON.parse(raw['data'] as string) as Record<string, Object>;
      } catch (error) {
        Logger.error('HTTP', `Failed to parse legacy address book data: ${JSON.stringify(error)}`);
        return { success: false, error: 'Invalid address book response', statusCode: rawResult.statusCode };
      }
    }

    const adapted: AbResponse = {};
    if (Array.isArray(raw['peers'])) {
      adapted.peers = raw['peers'] as Object as AbPeer[];
    }
    if (Array.isArray(raw['groups'])) {
      adapted.groups = raw['groups'] as Object as AbGroup[];
    }
    if (Array.isArray(raw['tags'])) {
      adapted.tags = raw['tags'] as Object as string[];
    }
    if (typeof raw['tag_colors'] === 'string') {
      adapted.tagColors = raw['tag_colors'] as string;
    }
    return { success: true, data: adapted, statusCode: rawResult.statusCode };
  }

  private async getModernAddressBook(guid: string): Promise<HttpResult<AbResponse>> {
    const peers: AbPeer[] = [];
    const pageSize = 100;
    let current = 1;
    let total = 0;
    do {
      const path = `/api/ab/peers?current=${current}&pageSize=${pageSize}&ab=${encodeURIComponent(guid)}`;
      const page = await this.post<PagedPeersResponse>(path);
      if (!page.success || !page.data) {
        return { success: false, error: page.error, statusCode: page.statusCode };
      }
      total = page.data.total ?? 0;
      for (const peer of page.data.data ?? []) {
        peers.push(peer);
      }
      current++;
    } while ((current - 1) * pageSize < total);

    const tagsResult = await this.post<AbTag[]>(`/api/ab/tags/${encodeURIComponent(guid)}`);
    if (!tagsResult.success || !tagsResult.data) {
      return { success: false, error: tagsResult.error, statusCode: tagsResult.statusCode };
    }
    const tags: string[] = [];
    const colors: Record<string, number> = {};
    for (const tag of tagsResult.data) {
      if (tag.name && tag.name.trim().length > 0) {
        tags.push(tag.name);
        colors[tag.name] = tag.color;
      }
    }
    return {
      success: true,
      data: { peers: peers, tags: tags, tagColors: JSON.stringify(colors) },
      statusCode: tagsResult.statusCode
    };
  }

  async syncDeviceSysinfo(username: string): Promise<HttpResult<string>> {
    const deviceInfo = this.getLoginDeviceInfo();
    const body = new DeviceSysinfoRequest();
    const rawSysinfo = NativeRustDeskBridge.mainGetSysinfo().trim();
    try {
      if (rawSysinfo.length > 0) {
        const sysinfo = JSON.parse(rawSysinfo) as Record<string, string>;
        body.cpu = sysinfo['cpu'] ?? '';
        body.memory = sysinfo['memory'] ?? '';
        body.hostname = sysinfo['hostname'] ?? '';
        body.os = sysinfo['os'] ?? body.os;
        body.username = sysinfo['username'] ?? '';
      }
    } catch (error) {
      Logger.warn('HTTP', `Invalid device sysinfo: ${JSON.stringify(error)}`);
    }
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuid();
    if (body.hostname.length === 0) {
      body.hostname = deviceInfo.name.length > 0 ? deviceInfo.name : body.id;
    }
    if (body.os.length === 0) {
      body.os = deviceInfo.os.length > 0 ? deviceInfo.os : 'HarmonyOS';
    }
    if (body.username.length === 0) {
      body.username = username;
    }
    body.version = NativeRustDeskBridge.mainGetVersion().trim();
    Logger.info('SYNC', `syncDeviceSysinfo: hostname="${body.hostname}", cpu="${body.cpu}", memory="${body.memory}", os="${body.os}"`);
    return this.post<string>('/api/sysinfo', body);
  }

  async sendHeartbeat(): Promise<HttpResult<Record<string, Object>>> {
    const body = new HeartbeatRequest();
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuid();
    body.modified_at = Math.floor(Date.now() / 1000);
    return this.post<Record<string, Object>>('/api/heartbeat', body);
  }

  async getAccessibleUsers(): Promise<HttpResult<AccessibleUser[]>> {
    const users: AccessibleUser[] = [];
    const pageSize = 100;
    let current = 1;
    let total = 0;
    do {
      const path = `/api/users?current=${current}&pageSize=${pageSize}&accessible=&status=1`;
      const page = await this.get<PagedUsersResponse>(path);
      if (!page.success || !page.data) {
        return { success: false, error: page.error, statusCode: page.statusCode };
      }
      if (typeof page.data.total !== 'number' || !Array.isArray(page.data.data)) {
        Logger.info('SYNC', `getAccessibleUsers invalid response: status=${page.statusCode ?? 0}`);
        return { success: false, error: 'Invalid user list response', statusCode: page.statusCode };
      }
      total = page.data.total ?? 0;
      for (const user of page.data.data ?? []) {
        users.push(user);
      }
      current++;
    } while ((current - 1) * pageSize < total);
    return { success: true, data: users };
  }

  async addAbPeer(peer: AbPeer): Promise<HttpResult<AbPeer>> {
    Logger.info('HTTP', `addAbPeer: replace legacy address book, id="${peer.id}", alias="${peer.alias ?? ''}"`);
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return book as HttpResult<AbPeer>;
    }
    if (this.personalAddressBookGuid.length > 0) {
      const tagResult = await this.ensureModernTags(book.data, peer.tags ?? []);
      if (!tagResult.success) {
        return { success: false, error: tagResult.error, statusCode: tagResult.statusCode };
      }
      return this.post<AbPeer>(`/api/ab/peer/add/${encodeURIComponent(this.personalAddressBookGuid)}`, peer);
    }
    const peers = book.data.peers ?? [];
    let replaced = false;
    for (let index = 0; index < peers.length; index++) {
      if (peers[index].id === peer.id) {
        peers[index] = this.mergeAbPeer(peers[index], peer);
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      peers.push(peer);
    }
    const writeResult = await this.replaceAddressBook(book.data, peers);
    const result: HttpResult<AbPeer> = writeResult.success
      ? { success: true, data: peer, statusCode: writeResult.statusCode }
      : { success: false, error: writeResult.error, statusCode: writeResult.statusCode };
    Logger.info('HTTP', `addAbPeer result: success=${result.success}, status=${result.statusCode ?? -1}, error=${result.error ?? 'none'}`);
    return result;
  }

  async updateAbPeer(peer: AbPeer): Promise<HttpResult<AbPeer>> {
    Logger.info('HTTP', `updateAbPeer: replace legacy address book, id="${peer.id}"`);
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    let result: HttpResult<AbPeer>;
    if (this.personalAddressBookGuid.length > 0) {
      const tagResult = await this.ensureModernTags(book.data, peer.tags ?? []);
      if (!tagResult.success) {
        return { success: false, error: tagResult.error, statusCode: tagResult.statusCode };
      }
      result = await this.put<AbPeer>(`/api/ab/peer/update/${encodeURIComponent(this.personalAddressBookGuid)}`, peer);
    } else {
      result = await this.addAbPeer(peer);
    }
    Logger.info('HTTP', `updateAbPeer result: success=${result.success}, status=${result.statusCode ?? -1}`);
    return result;
  }

  async deleteAbPeer(peerId: string): Promise<HttpResult<void>> {
    Logger.info('HTTP', `deleteAbPeer: replace legacy address book, id="${peerId}"`);
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    if (this.personalAddressBookGuid.length > 0) {
      const ids: string[] = [peerId];
      return this.delete<void>(`/api/ab/peer/${encodeURIComponent(this.personalAddressBookGuid)}`, ids);
    }
    const peers: AbPeer[] = [];
    for (const peer of book.data.peers ?? []) {
      if (peer.id !== peerId) {
        peers.push(peer);
      }
    }
    const result = await this.replaceAddressBook(book.data, peers);
    Logger.info('HTTP', `deleteAbPeer result: success=${result.success}, status=${result.statusCode ?? -1}, error=${result.error ?? 'none'}`);
    return result;
  }

  async updateAbTag(peerId: string, tags: string[]): Promise<HttpResult<void>> {
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    if (this.personalAddressBookGuid.length > 0) {
      const tagResult = await this.ensureModernTags(book.data, tags);
      if (!tagResult.success) {
        return tagResult;
      }
      const patch: AbPeer = { id: peerId, tags: tags };
      return this.put<void>(`/api/ab/peer/update/${encodeURIComponent(this.personalAddressBookGuid)}`, patch);
    }
    const peers = book.data.peers ?? [];
    for (let index = 0; index < peers.length; index++) {
      if (peers[index].id === peerId) {
        const patch: AbPeer = { id: peerId, tags: tags };
        peers[index] = this.mergeAbPeer(peers[index], patch);
        break;
      }
    }
    return this.replaceAddressBook(book.data, peers);
  }

  async addAddressBookTag(tag: string, color?: number): Promise<HttpResult<void>> {
    const normalized = tag.trim();
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    if ((book.data.tags ?? []).includes(normalized)) {
      return { success: true };
    }
    if (this.personalAddressBookGuid.length > 0) {
      return this.ensureModernTags(book.data, [normalized], color);
    }
    const tags = book.data.tags ?? [];
    tags.push(normalized);
    book.data.tags = tags;
    return this.replaceAddressBook(book.data, book.data.peers ?? []);
  }

  async renameAddressBookTag(oldTag: string, newTag: string): Promise<HttpResult<void>> {
    const oldName = oldTag.trim();
    const newName = newTag.trim();
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    if (this.personalAddressBookGuid.length > 0) {
      const body = new AbTagRenameRequest();
      body.old = oldName;
      body.new = newName;
      return this.put<void>(`/api/ab/tag/rename/${encodeURIComponent(this.personalAddressBookGuid)}`, body);
    }
    book.data.tags = (book.data.tags ?? []).map((tag: string) => tag === oldName ? newName : tag);
    for (const peer of book.data.peers ?? []) {
      peer.tags = (peer.tags ?? []).map((tag: string) => tag === oldName ? newName : tag);
    }
    return this.replaceAddressBook(book.data, book.data.peers ?? []);
  }

  async deleteAddressBookTag(tag: string): Promise<HttpResult<void>> {
    const normalized = tag.trim();
    const book = await this.getAddressBook();
    if (!book.success || !book.data) {
      return { success: false, error: book.error, statusCode: book.statusCode };
    }
    if (this.personalAddressBookGuid.length > 0) {
      const tags: string[] = [normalized];
      return this.delete<void>(`/api/ab/tag/${encodeURIComponent(this.personalAddressBookGuid)}`, tags);
    }
    book.data.tags = (book.data.tags ?? []).filter((value: string) => value !== normalized);
    for (const peer of book.data.peers ?? []) {
      peer.tags = (peer.tags ?? []).filter((value: string) => value !== normalized);
    }
    return this.replaceAddressBook(book.data, book.data.peers ?? []);
  }

  private mergeAbPeer(current: AbPeer, patch: AbPeer): AbPeer {
    return {
      id: patch.id,
      hash: patch.hash ?? current.hash,
      username: patch.username ?? current.username,
      alias: patch.alias ?? current.alias,
      hostname: patch.hostname ?? current.hostname,
      note: patch.note ?? current.note,
      platform: patch.platform ?? current.platform,
      tags: patch.tags ?? current.tags
    };
  }

  private async ensureModernTags(book: AbResponse, tags: string[], requestedColor?: number): Promise<HttpResult<void>> {
    const existing: Set<string> = new Set<string>(book.tags ?? []);
    for (const tag of tags) {
      const normalized = tag.trim();
      if (normalized.length === 0 || existing.has(normalized)) {
        continue;
      }
      const body = new AbTagCreateRequest();
      body.name = normalized;
      body.color = requestedColor ?? this.colorForTag(normalized);
      const result = await this.post<void>(
        `/api/ab/tag/add/${encodeURIComponent(this.personalAddressBookGuid)}`, body);
      if (!result.success) {
        return result;
      }
      existing.add(normalized);
    }
    return { success: true };
  }

  private colorForTag(tag: string): number {
    const colors: number[] = [4280391411, 4283215696, 4294936121, 4288423856, 4294198070, 4278238420];
    let hash = 0;
    for (let index = 0; index < tag.length; index++) {
      hash = ((hash * 31) + tag.charCodeAt(index)) >>> 0;
    }
    return colors[hash % colors.length];
  }

  private async replaceAddressBook(book: AbResponse, peers: AbPeer[]): Promise<HttpResult<void>> {
    const tagSet: Set<string> = new Set<string>();
    for (const tag of book.tags ?? []) {
      if (tag.trim().length > 0) {
        tagSet.add(tag);
      }
    }
    for (const peer of peers) {
      for (const tag of peer.tags ?? []) {
        if (tag.trim().length > 0) {
          tagSet.add(tag);
        }
      }
    }
    const data = new LegacyAddressBookData();
    data.tags = Array.from(tagSet.values());
    data.peers = peers;
    data.tag_colors = book.tagColors ?? '{}';
    const body = new LegacyAddressBookReplaceRequest();
    body.data = JSON.stringify(data);
    return this.post<void>('/api/ab', body);
  }
}

export const httpClient = HttpClient.getInstance();
