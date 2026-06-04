import http from '@ohos.net.http';
import util from '@ohos.util';
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
  remember_me: boolean;
}

class OidcAuthRequestImpl implements OidcAuthRequest {
  op: string = '';
  id: string = '';
  uuid: string = '';
  remember_me: boolean = false;
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
  }

  private getAccessToken(): string {
    return NativeRustDeskBridge.getLocalOption('access_token').trim();
  }

  private async request<T>(
    method: http.RequestMethod,
    path: string,
    body?: Object
  ): Promise<HttpResult<T>> {
    const httpRequest = http.createHttp();
    const url = `${this.baseUrl}${path}`;
    const accessToken = this.getAccessToken();

    console.info(`[HttpClient] ${method === http.RequestMethod.GET ? 'GET' : 'POST'} ${url}`);
    if (body) {
      console.info(`[HttpClient] body: ${JSON.stringify(body)}`);
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
        console.info(`[HttpClient] Response data: ${JSON.stringify(data).substring(0, 200)}`);
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
        if (typeof item === 'string' && item.startsWith('oidc/')) {
          const opt = new LoginOption();
          opt.op = item;
          opt.name = item.substring(5);
          oauth.push(opt);
        }
      }
    } else if (raw['oauth'] && Array.isArray(raw['oauth'])) {
      for (const item of raw['oauth'] as LoginOption[]) {
        oauth.push(item);
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
    let uuid = NativeRustDeskBridge.getLocalOption('uuid').trim();
    if (uuid.length === 0) {
      uuid = AppStorage.get<string>('myDeviceUuid') ?? '';
    }
    return uuid;
  }

  private getDeviceUuidBase64(): string {
    const raw = this.getDeviceUuid();
    if (raw.length === 0) {
      return '';
    }
    try {
      const base64 = new util.Base64Helper();
      const bytes = new Uint8Array(Array.from(raw).map(c => c.charCodeAt(0)));
      const encoded = base64.encodeSync(bytes);
      let result = '';
      for (let i = 0; i < encoded.length; i++) {
        result += String.fromCharCode(encoded[i]);
      }
      return result;
    } catch (e) {
      console.warn('[HttpClient] Base64 encode uuid failed, using raw:', e);
      return raw;
    }
  }

  async oidcAuth(op: string, rememberMe: boolean = true): Promise<HttpResult<OidcAuthResponse>> {
    const body = new OidcAuthRequestImpl();
    body.op = op;
    body.id = this.getDeviceId();
    body.uuid = this.getDeviceUuidBase64();
    body.remember_me = rememberMe;
    console.info(`[HttpClient] oidcAuth: op=${body.op}, id=${body.id}, uuid_len=${body.uuid.length}`);
    return this.post<OidcAuthResponse>('/api/oidc/auth', body);
  }

  async oidcAuthQuery(code: string): Promise<HttpResult<AuthQueryResponse>> {
    const id = this.getDeviceId();
    const uuid = this.getDeviceUuidBase64();
    console.info(`[HttpClient] oidcAuthQuery: code=${code}, id=${id}, uuid_len=${uuid.length}`);
    const rawResult = await this.get<Record<string, Object>>(`/api/oidc/auth-query?code=${encodeURIComponent(code)}&id=${encodeURIComponent(id)}&uuid=${encodeURIComponent(uuid)}`);

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
    return this.get<AbResponse>('/api/ab');
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
