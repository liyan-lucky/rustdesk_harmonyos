import preferences from '@ohos.data.preferences';
import { AppContextService } from './AppContextService';

export class PreferenceStore {
  private static readonly STORE_NAME: string = 'rustdesk_harmonyos';
  private static readonly SETTINGS_KEY: string = 'settings';
  private static readonly SESSION_OPTIONS_KEY: string = 'session_options';
  private static readonly RECENT_SESSIONS_KEY: string = 'recent_sessions';
  private static readonly ADDRESS_BOOK_KEY: string = 'address_book';
  private static readonly PASSWORD_KEY: string = 'password';
  private static readonly OFFICIAL_CORE_SNAPSHOT_KEY: string = 'official_core_snapshot';
  private static readonly ACCOUNT_TOKEN_KEY: string = 'account_access_token';
  private static readonly ACCOUNT_USER_INFO_KEY: string = 'account_user_info';
  private static readonly PEER_PASSWORDS_KEY: string = 'peer_passwords';
  private static readonly CHAT_MESSAGES_KEY: string = 'chat_messages';
  private static readonly VISIBLE_TABS_KEY: string = 'visible_connect_tabs';
  private static readonly LOCAL_FAVORITES_KEY: string = 'local_favorites';
  private static readonly IGNORED_DISCOVERED_PEERS_KEY: string = 'ignored_discovered_peers';
  private static readonly INCOMING_SERVICE_DEFAULT_OFF_MIGRATION_KEY: string = 'incoming_service_default_off_migration_20260602';
  private static readonly DEBUG_KEEP_SCREEN_AWAKE_DEFAULT_ON_MIGRATION_KEY: string = 'debug_keep_screen_awake_default_on_20260615';
  private static readonly PEER_CONNECT_MODES_KEY: string = 'peer_connect_modes';
  private static readonly PEER_OS_PASSWORDS_KEY: string = 'peer_os_passwords';

  private static getStore(): preferences.Preferences | undefined {
    const context = AppContextService.getContext();
    if (!context) {
      return undefined;
    }
    try {
      return preferences.getPreferencesSync(context, { name: PreferenceStore.STORE_NAME });
    } catch (error) {
      console.error('PreferenceStore getStore failed', JSON.stringify(error));
      return undefined;
    }
  }

  public static getSettings(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.SETTINGS_KEY);
  }

  public static setSettings(value: string): void {
    PreferenceStore.setString(PreferenceStore.SETTINGS_KEY, value);
  }

  public static getSessionOptions(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.SESSION_OPTIONS_KEY);
  }

  public static setSessionOptions(value: string): void {
    PreferenceStore.setString(PreferenceStore.SESSION_OPTIONS_KEY, value);
  }

  public static getRecentSessions(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.RECENT_SESSIONS_KEY);
  }

  public static setRecentSessions(value: string): void {
    PreferenceStore.setString(PreferenceStore.RECENT_SESSIONS_KEY, value);
  }

  public static getAddressBook(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.ADDRESS_BOOK_KEY);
  }

  public static setAddressBook(value: string): void {
    PreferenceStore.setString(PreferenceStore.ADDRESS_BOOK_KEY, value);
  }

  public static getPassword(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.PASSWORD_KEY);
  }

  public static setPassword(value: string): void {
    PreferenceStore.setString(PreferenceStore.PASSWORD_KEY, value);
  }

  public static getOfficialCoreSnapshot(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.OFFICIAL_CORE_SNAPSHOT_KEY);
  }

  public static setOfficialCoreSnapshot(value: string): void {
    PreferenceStore.setString(PreferenceStore.OFFICIAL_CORE_SNAPSHOT_KEY, value);
  }

  public static getAccountToken(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.ACCOUNT_TOKEN_KEY);
  }

  public static setAccountToken(value: string): void {
    PreferenceStore.setString(PreferenceStore.ACCOUNT_TOKEN_KEY, value);
  }

  public static getAccountUserInfo(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.ACCOUNT_USER_INFO_KEY);
  }

  public static setAccountUserInfo(value: string): void {
    PreferenceStore.setString(PreferenceStore.ACCOUNT_USER_INFO_KEY, value);
  }

  public static getPeerPassword(peerId: string): string | undefined {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_PASSWORDS_KEY);
    if (!raw) {
      return undefined;
    }
    try {
      const map = JSON.parse(raw) as Record<string, string>;
      const value = map[peerId];
      return value && value.length > 0 ? value : undefined;
    } catch (error) {
      return undefined;
    }
  }

  public static setPeerPassword(peerId: string, password: string): void {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_PASSWORDS_KEY);
    let map: Record<string, string> = {};
    if (raw) {
      try {
        map = JSON.parse(raw) as Record<string, string>;
      } catch (error) {
        map = {};
      }
    }
    if (password.trim().length > 0) {
      map[peerId] = password.trim();
    } else {
      delete map[peerId];
    }
    PreferenceStore.setString(PreferenceStore.PEER_PASSWORDS_KEY, JSON.stringify(map));
  }

  public static getChatMessages(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.CHAT_MESSAGES_KEY);
  }

  public static setChatMessages(value: string): void {
    PreferenceStore.setString(PreferenceStore.CHAT_MESSAGES_KEY, value);
  }

  public static getVisibleTabs(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.VISIBLE_TABS_KEY);
  }

  public static setVisibleTabs(value: string): void {
    PreferenceStore.setString(PreferenceStore.VISIBLE_TABS_KEY, value);
  }

  public static getLocalFavorites(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.LOCAL_FAVORITES_KEY);
  }

  public static setLocalFavorites(value: string): void {
    PreferenceStore.setString(PreferenceStore.LOCAL_FAVORITES_KEY, value);
  }

  public static getIgnoredDiscoveredPeers(): string | undefined {
    return PreferenceStore.getString(PreferenceStore.IGNORED_DISCOVERED_PEERS_KEY);
  }

  public static setIgnoredDiscoveredPeers(value: string): void {
    PreferenceStore.setString(PreferenceStore.IGNORED_DISCOVERED_PEERS_KEY, value);
  }

  public static hasMigratedIncomingServiceDefaultOff(): boolean {
    return PreferenceStore.getString(PreferenceStore.INCOMING_SERVICE_DEFAULT_OFF_MIGRATION_KEY) === 'Y';
  }

  public static setMigratedIncomingServiceDefaultOff(): void {
    PreferenceStore.setString(PreferenceStore.INCOMING_SERVICE_DEFAULT_OFF_MIGRATION_KEY, 'Y');
  }

  public static hasMigratedDebugKeepScreenAwakeDefaultOn(): boolean {
    return PreferenceStore.getString(PreferenceStore.DEBUG_KEEP_SCREEN_AWAKE_DEFAULT_ON_MIGRATION_KEY) === 'Y';
  }

  public static setMigratedDebugKeepScreenAwakeDefaultOn(): void {
    PreferenceStore.setString(PreferenceStore.DEBUG_KEEP_SCREEN_AWAKE_DEFAULT_ON_MIGRATION_KEY, 'Y');
  }

  public static getPeerConnectMode(peerId: string): 'direct' | 'relay' {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_CONNECT_MODES_KEY);
    if (!raw) {
      return 'direct';
    }
    try {
      const map = JSON.parse(raw) as Record<string, string>;
      const value = map[peerId];
      return value === 'relay' ? 'relay' : 'direct';
    } catch (error) {
      return 'direct';
    }
  }

  public static setPeerConnectMode(peerId: string, mode: 'direct' | 'relay'): void {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_CONNECT_MODES_KEY);
    let map: Record<string, string> = {};
    if (raw) {
      try {
        map = JSON.parse(raw) as Record<string, string>;
      } catch (error) {
        map = {};
      }
    }
    map[peerId] = mode;
    PreferenceStore.setString(PreferenceStore.PEER_CONNECT_MODES_KEY, JSON.stringify(map));
  }

  public static getPeerOsPassword(peerId: string): string | undefined {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_OS_PASSWORDS_KEY);
    if (!raw) {
      return undefined;
    }
    try {
      const map = JSON.parse(raw) as Record<string, string>;
      const value = map[peerId];
      return value && value.length > 0 ? value : undefined;
    } catch (error) {
      return undefined;
    }
  }

  public static setPeerOsPassword(peerId: string, password: string): void {
    const raw = PreferenceStore.getString(PreferenceStore.PEER_OS_PASSWORDS_KEY);
    let map: Record<string, string> = {};
    if (raw) {
      try {
        map = JSON.parse(raw) as Record<string, string>;
      } catch (error) {
        map = {};
      }
    }
    if (password.trim().length > 0) {
      map[peerId] = password.trim();
    } else {
      delete map[peerId];
    }
    PreferenceStore.setString(PreferenceStore.PEER_OS_PASSWORDS_KEY, JSON.stringify(map));
  }

  private static getString(key: string): string | undefined {
    try {
      const store = PreferenceStore.getStore();
      if (!store) {
        return undefined;
      }
      const value = store.getSync(key, '') as string;
      return value.length > 0 ? value : undefined;
    } catch (error) {
      console.error('PreferenceStore getString failed', JSON.stringify(error));
      return undefined;
    }
  }

  private static setString(key: string, value: string): void {
    try {
      const store = PreferenceStore.getStore();
      if (!store) {
        return;
      }
      store.putSync(key, value);
      store.flushSync();
    } catch (error) {
      console.error('PreferenceStore setString failed', JSON.stringify(error));
    }
  }
}
