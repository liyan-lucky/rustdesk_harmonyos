import http from '@ohos.net.http';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { AppDataService } from './AppDataService';

export interface HttpResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  statusCode?: number;
}

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
  alias?: string;
  hostname?: string;
  note?: string;
  platform?: string;
  tags?: string[];
  hash?: string;
  online?: boolean;
}

export interface AbGroup {
  name: string;
  peers: AbPeer[];
}

export interface AbResponse {
  peers?: AbPeer[];
  groups?: AbGroup[];
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

  private constructor() {}

  static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  setApiServer(apiServer: string): void {
    const normalized = apiServer.trim();
    this.baseUrl = normalized.length > 0 ? normalized : AppDataService.OFFICIAL_API_SERVER;
    console.info(`[HttpClient] setApiServer: input="${apiServer}" → baseUrl="${this.baseUrl}"`);
  }

  getApiServer(): string {
    return this.baseUrl;
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
    const logUrl = this.redactUrlForLog(url);
    const accessToken = this.getAccessToken();

    console.info(`[HttpClient] ${method === http.RequestMethod.GET ? 'GET' : 'POST'} ${logUrl}`);
    if (body) {
      console.info(`[HttpClient] body: ${this.redactForLog(body)}`);
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

      console.info(`[HttpClient] Response status: ${statusCode}`);

      if (statusCode >= 200 && statusCode < 300) {
        const data = response.result as T;
        console.info(`[HttpClient] Response data: ${this.redactForLog(response.result)}`);
        return { success: true, data, statusCode };
      }

      if (statusCode === 401 || statusCode === 400) {
        console.error(`[HttpClient] Auth failed: ${statusCode}`);
        return { success: false, error: '认证失败，请重新登录', statusCode };
      }

      const errorMsg = this.parseError(response.result);
      console.error(`[HttpClient] Error: ${errorMsg}, status: ${statusCode}`);
      return { success: false, error: errorMsg, statusCode };
    } catch (error) {
      const errorMsg = `网络请求失败: ${JSON.stringify(error)}`;
      console.error(`[HttpClient] Exception: ${errorMsg}`);
      return { success: false, error: errorMsg };
    } finally {
      httpRequest.destroy();
    }
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
            console.warn('[HttpClient] Invalid common OIDC login options: ' + JSON.stringify(error));
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
      console.warn('[HttpClient] Invalid login device info:', JSON.stringify(error));
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
    console.info(`[HttpClient] oidcAuth: op=${body.op}, id=${body.id}, uuid_len=${body.uuid.length}`);
    return this.request<OidcAuthResponse>(http.RequestMethod.POST, '/api/oidc/auth', body, apiServer);
  }

  async oidcAuthQuery(code: string, apiServer?: string): Promise<HttpResult<AuthQueryResponse>> {
    const id = this.getDeviceId();
    const uuid = this.getDeviceUuid();
    console.info(`[HttpClient] oidcAuthQuery: code_len=${code.length}, id=${id}, uuid_len=${uuid.length}`);
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
        console.warn('[HttpClient] Failed to parse nested body string:', e);
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

    console.info(`[HttpClient] oidcAuthQuery adapted: auth_body=${adapted.auth_body ? 'yes' : 'no'}, failed_msg=${adapted.failed_msg ?? 'none'}`);
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
    const rawResult = await this.get<Record<string, Object>>('/api/ab');
    if (!rawResult.success || !rawResult.data) {
      return rawResult as HttpResult<AbResponse>;
    }

    let raw = rawResult.data;
    if (typeof raw['data'] === 'string') {
      try {
        raw = JSON.parse(raw['data'] as string) as Record<string, Object>;
      } catch (error) {
        console.error('[HttpClient] Failed to parse legacy address book data:', JSON.stringify(error));
        return { success: false, error: 'Invalid address book response', statusCode: rawResult.statusCode };
      }
    }

    const adapted: AbResponse = {};
    if (Array.isArray(raw['peers'])) {
      adapted.peers = raw['peers'] as unknown as AbPeer[];
    }
    if (Array.isArray(raw['groups'])) {
      adapted.groups = raw['groups'] as unknown as AbGroup[];
    }
    return { success: true, data: adapted, statusCode: rawResult.statusCode };
  }

  async syncDeviceSysinfo(username: string): Promise<HttpResult<string>> {
    const deviceInfo = this.getLoginDeviceInfo();
    const body = new DeviceSysinfoRequest();
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuid();
    body.hostname = deviceInfo.name.length > 0 ? deviceInfo.name : body.id;
    body.os = deviceInfo.os.length > 0 ? deviceInfo.os : 'HarmonyOS';
    body.username = username;
    body.version = NativeRustDeskBridge.mainGetVersion().trim();
    return this.post<string>('/api/sysinfo', body);
  }

  async sendHeartbeat(): Promise<HttpResult<Record<string, Object>>> {
    const body = new HeartbeatRequest();
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuid();
    body.modified_at = Math.floor(Date.now() / 1000);
    return this.post<Record<string, Object>>('/api/heartbeat', body);
  }

  async addAbPeer(peer: AbPeer): Promise<HttpResult<AbPeer>> {
    return this.post<AbPeer>('/api/ab/peer', peer);
  }

  async updateAbPeer(peer: AbPeer): Promise<HttpResult<AbPeer>> {
    return this.post<AbPeer>(`/api/ab/peer/${peer.id}`, peer);
  }

  async deleteAbPeer(peerId: string): Promise<HttpResult<void>> {
    return this.post<void>(`/api/ab/peer/${peerId}/delete`);
  }

  async updateAbTag(peerId: string, tags: string[]): Promise<HttpResult<void>> {
    const body = new AbTagRequestImpl();
    body.tags = tags;
    return this.post<void>(`/api/ab/peer/${peerId}/tag`, body);
  }
}

export const httpClient = HttpClient.getInstance();
