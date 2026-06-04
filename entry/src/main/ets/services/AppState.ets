import { EventBus, EventType, eventBus } from './EventBus';

export interface SessionState {
  peerId: string;
  peerName: string;
  status: 'idle' | 'connecting' | 'connected' | 'disconnected' | 'error';
  errorMessage?: string;
  hasFrame: boolean;
  fps: number;
  latency: number;
}

export interface UserProfile {
  name: string;
  displayName: string;
  avatar: string;
  provider: string;
}

export interface AccountState {
  isLoggedIn: boolean;
  username: string;
  displayName: string;
  avatar: string;
  accessToken: string;
  provider: string;
  loginUrl?: string;
  status?: 'idle' | 'requesting' | 'waiting' | 'logged_in' | 'error';
  lastError?: string;
  detail?: string;
  profile?: UserProfile;
  browserOpened?: boolean;
}

export interface FrameState {
  width: number;
  height: number;
  format: string;
  buffer: ArrayBuffer | null;
  frameId: number;
  timestamp: number;
}

export interface SettingsState {
  theme: 'light' | 'dark' | 'system';
  language: 'zh' | 'en';
  showRemoteCursor: boolean;
  muteAudio: boolean;
  disableClipboard: boolean;
  imageQuality: 'best' | 'balanced' | 'speed';
  videoCodec: 'auto' | 'vp8' | 'vp9' | 'h264' | 'h265';
}

class StateKeys {
  static readonly SESSION = 'app:session';
  static readonly ACCOUNT = 'app:account';
  static readonly FRAME = 'app:frame';
  static readonly SETTINGS = 'app:settings';
  static readonly THEME_IS_DARK = 'themeIsDark';
  static readonly I18N_VERSION = 'i18nVersion';
  static readonly FORCE_REFRESH = 'forceRefreshVersion';
}

function cloneSession(state: SessionState): SessionState {
  const clone = new SessionStateImpl();
  clone.peerId = state.peerId;
  clone.peerName = state.peerName;
  clone.status = state.status;
  clone.errorMessage = state.errorMessage;
  clone.hasFrame = state.hasFrame;
  clone.fps = state.fps;
  clone.latency = state.latency;
  return clone;
}

function cloneAccount(state: AccountState): AccountState {
  const clone = new AccountStateImpl();
  clone.isLoggedIn = state.isLoggedIn;
  clone.username = state.username;
  clone.displayName = state.displayName;
  clone.avatar = state.avatar;
  clone.accessToken = state.accessToken;
  clone.provider = state.provider;
  clone.loginUrl = state.loginUrl;
  clone.status = state.status;
  clone.lastError = state.lastError;
  clone.detail = state.detail;
  if (state.profile) {
    const profile = new UserProfileImpl();
    profile.name = state.profile.name;
    profile.displayName = state.profile.displayName;
    profile.avatar = state.profile.avatar;
    profile.provider = state.profile.provider;
    clone.profile = profile;
  }
  return clone;
}

function cloneFrame(state: FrameState): FrameState {
  const clone = new FrameStateImpl();
  clone.width = state.width;
  clone.height = state.height;
  clone.format = state.format;
  clone.buffer = state.buffer;
  clone.frameId = state.frameId;
  clone.timestamp = state.timestamp;
  return clone;
}

function cloneSettings(state: SettingsState): SettingsState {
  const clone = new SettingsStateImpl();
  clone.theme = state.theme;
  clone.language = state.language;
  clone.showRemoteCursor = state.showRemoteCursor;
  clone.muteAudio = state.muteAudio;
  clone.disableClipboard = state.disableClipboard;
  clone.imageQuality = state.imageQuality;
  clone.videoCodec = state.videoCodec;
  return clone;
}

class SessionStateImpl implements SessionState {
  peerId: string = '';
  peerName: string = '';
  status: 'idle' | 'connecting' | 'connected' | 'disconnected' | 'error' = 'idle';
  errorMessage?: string = '';
  hasFrame: boolean = false;
  fps: number = 0;
  latency: number = 0;
}

class UserProfileImpl implements UserProfile {
  name: string = '';
  displayName: string = '';
  avatar: string = '';
  provider: string = '';
}

class AccountStateImpl implements AccountState {
  isLoggedIn: boolean = false;
  username: string = '';
  displayName: string = '';
  avatar: string = '';
  accessToken: string = '';
  provider: string = '';
  loginUrl?: string = '';
  status?: 'idle' | 'requesting' | 'waiting' | 'logged_in' | 'error' = 'idle';
  lastError?: string = '';
  detail?: string = '';
  profile?: UserProfile;
  browserOpened?: boolean = false;
}

class FrameStateImpl implements FrameState {
  width: number = 0;
  height: number = 0;
  format: string = '';
  buffer: ArrayBuffer | null = null;
  frameId: number = 0;
  timestamp: number = 0;
}

class SettingsStateImpl implements SettingsState {
  theme: 'light' | 'dark' | 'system' = 'system';
  language: 'zh' | 'en' = 'zh';
  showRemoteCursor: boolean = true;
  muteAudio: boolean = false;
  disableClipboard: boolean = false;
  imageQuality: 'best' | 'balanced' | 'speed' = 'balanced';
  videoCodec: 'auto' | 'vp8' | 'vp9' | 'h264' | 'h265' = 'auto';
}

export class AppState {
  private static instance: AppState;
  private eventBus: EventBus = EventBus.getInstance();

  private session: SessionState = new SessionStateImpl();
  private account: AccountState = new AccountStateImpl();
  private frame: FrameState = new FrameStateImpl();
  private settings: SettingsState = new SettingsStateImpl();

  private constructor() {
    this.initAppStorage();
  }

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState();
    }
    return AppState.instance;
  }

  private initAppStorage(): void {
    AppStorage.setOrCreate<SessionState>(StateKeys.SESSION, this.session);
    AppStorage.setOrCreate<AccountState>(StateKeys.ACCOUNT, this.account);
    AppStorage.setOrCreate<FrameState>(StateKeys.FRAME, this.frame);
    AppStorage.setOrCreate<SettingsState>(StateKeys.SETTINGS, this.settings);
    AppStorage.setOrCreate<boolean>(StateKeys.THEME_IS_DARK, false);
    AppStorage.setOrCreate<number>(StateKeys.I18N_VERSION, 0);
    AppStorage.setOrCreate<number>(StateKeys.FORCE_REFRESH, 0);
  }

  getSession(): SessionState {
    return cloneSession(this.session);
  }

  setSession(partial: Partial<SessionState>): void {
    if (partial.peerId !== undefined) this.session.peerId = partial.peerId;
    if (partial.peerName !== undefined) this.session.peerName = partial.peerName;
    if (partial.status !== undefined) this.session.status = partial.status;
    if (partial.errorMessage !== undefined) this.session.errorMessage = partial.errorMessage;
    if (partial.hasFrame !== undefined) this.session.hasFrame = partial.hasFrame;
    if (partial.fps !== undefined) this.session.fps = partial.fps;
    if (partial.latency !== undefined) this.session.latency = partial.latency;

    AppStorage.set<SessionState>(StateKeys.SESSION, this.session);
    this.eventBus.emit(EventType.SESSION_STATE_CHANGED, this.session);

    if (partial.status === 'connected' && this.session.status !== 'connected') {
      this.eventBus.emit(EventType.SESSION_CONNECTED, this.session);
    } else if (partial.status === 'disconnected' && this.session.status !== 'disconnected') {
      this.eventBus.emit(EventType.SESSION_DISCONNECTED, this.session);
    } else if (partial.status === 'error') {
      this.eventBus.emit(EventType.SESSION_ERROR, this.session);
    }
  }

  getAccount(): AccountState {
    return cloneAccount(this.account);
  }

  setAccount(partial: Partial<AccountState>): void {
    const wasLoggedIn = this.account.isLoggedIn;
    
    if (partial.isLoggedIn !== undefined) this.account.isLoggedIn = partial.isLoggedIn;
    if (partial.username !== undefined) this.account.username = partial.username;
    if (partial.displayName !== undefined) this.account.displayName = partial.displayName;
    if (partial.avatar !== undefined) this.account.avatar = partial.avatar;
    if (partial.accessToken !== undefined) this.account.accessToken = partial.accessToken;
    if (partial.provider !== undefined) this.account.provider = partial.provider;
    if (partial.loginUrl !== undefined) this.account.loginUrl = partial.loginUrl;
    if (partial.status !== undefined) this.account.status = partial.status;
    if (partial.lastError !== undefined) this.account.lastError = partial.lastError;
    if (partial.detail !== undefined) this.account.detail = partial.detail;
    if (partial.profile !== undefined) this.account.profile = partial.profile;
    if (partial.browserOpened !== undefined) this.account.browserOpened = partial.browserOpened;

    AppStorage.set<AccountState>(StateKeys.ACCOUNT, this.account);
    this.eventBus.emit(EventType.ACCOUNT_STATE_CHANGED, this.account);

    if (partial.isLoggedIn === true && !wasLoggedIn) {
      this.eventBus.emit(EventType.ACCOUNT_LOGIN, this.account);
    } else if (partial.isLoggedIn === false && wasLoggedIn) {
      this.eventBus.emit(EventType.ACCOUNT_LOGOUT);
    }
  }

  getFrame(): FrameState {
    const clone = cloneFrame(this.frame);
    clone.buffer = this.frame.buffer;
    return clone;
  }

  setFrame(partial: Partial<FrameState>): void {
    const prevFrameId = this.frame.frameId;
    
    if (partial.width !== undefined) this.frame.width = partial.width;
    if (partial.height !== undefined) this.frame.height = partial.height;
    if (partial.format !== undefined) this.frame.format = partial.format;
    if (partial.buffer !== undefined) this.frame.buffer = partial.buffer;
    if (partial.frameId !== undefined) this.frame.frameId = partial.frameId;
    if (partial.timestamp !== undefined) this.frame.timestamp = partial.timestamp;

    AppStorage.set<FrameState>(StateKeys.FRAME, this.frame);

    if (partial.buffer && partial.frameId !== prevFrameId) {
      this.eventBus.emit(EventType.FRAME_RECEIVED, this.frame);
    }
  }

  getSettings(): SettingsState {
    return cloneSettings(this.settings);
  }

  setSettings(partial: Partial<SettingsState>): void {
    const prevTheme = this.settings.theme;
    const prevLanguage = this.settings.language;
    
    if (partial.theme !== undefined) this.settings.theme = partial.theme;
    if (partial.language !== undefined) this.settings.language = partial.language;
    if (partial.showRemoteCursor !== undefined) this.settings.showRemoteCursor = partial.showRemoteCursor;
    if (partial.muteAudio !== undefined) this.settings.muteAudio = partial.muteAudio;
    if (partial.disableClipboard !== undefined) this.settings.disableClipboard = partial.disableClipboard;
    if (partial.imageQuality !== undefined) this.settings.imageQuality = partial.imageQuality;
    if (partial.videoCodec !== undefined) this.settings.videoCodec = partial.videoCodec;

    AppStorage.set<SettingsState>(StateKeys.SETTINGS, this.settings);
    this.eventBus.emit(EventType.SETTINGS_CHANGED, this.settings);

    if (partial.theme && partial.theme !== prevTheme) {
      this.eventBus.emit(EventType.THEME_CHANGED, partial.theme);
    }
    if (partial.language && partial.language !== prevLanguage) {
      this.eventBus.emit(EventType.LANGUAGE_CHANGED, partial.language);
    }
  }

  isDarkMode(): boolean {
    return AppStorage.get<boolean>(StateKeys.THEME_IS_DARK) ?? false;
  }

  setDarkMode(isDark: boolean): void {
    AppStorage.set<boolean>(StateKeys.THEME_IS_DARK, isDark);
  }

  refreshUI(): void {
    const version = AppStorage.get<number>(StateKeys.I18N_VERSION) ?? 0;
    AppStorage.set<number>(StateKeys.I18N_VERSION, version + 1);
    AppStorage.set<number>(StateKeys.FORCE_REFRESH, version + 1);
  }

  reset(): void {
    this.session = new SessionStateImpl();
    this.frame = new FrameStateImpl();
    AppStorage.set<SessionState>(StateKeys.SESSION, this.session);
    AppStorage.set<FrameState>(StateKeys.FRAME, this.frame);
  }
}

export const appState = AppState.getInstance();
