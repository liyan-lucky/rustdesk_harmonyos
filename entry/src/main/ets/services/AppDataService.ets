import { PreferenceStore } from './PreferenceStore';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import deviceInfo from '@ohos.deviceInfo';

export interface RecentSession {
  id: string;
  name: string;
  username: string;
  time: string;
  online: boolean;
  platform: string;
}

export interface AddressBookEntry {
  id: string;
  alias: string;
  note: string;
  group: string;
  online: boolean;
  favorite: boolean;
  platform: string;
}

export interface SettingsState {
  theme: 'light' | 'dark' | 'auto';
  language: string;
  notificationsEnabled: boolean;
  autoConnect: boolean;
  videoQuality: 'low' | 'medium' | 'high';
  allowRemoteControl: boolean;
  allowFileTransfer: boolean;
  allowClipboard: boolean;
  idServer: string;
  relayServer: string;
  apiServer: string;
  key: string;
  enableAudio: boolean;
  enableClipboard: boolean;
  enableFloatingWindow: boolean;
  autoRecordOutgoing: boolean;
  enableHardwareCodec: boolean;
  enableAdaptiveBitrate: boolean;
  showTerminalExtraKeys: boolean;
  enableDirectIp: boolean;
  denyLanDiscovery: boolean;
  allowWebSocket: boolean;
  enableUdpHolePunching: boolean;
  enableIpv6P2p: boolean;
  autoRecordIncoming: boolean;
  startOnBoot: boolean;
  requestRemarkOnSessionEnd: boolean;
  twoFactorEnabled: boolean;
  onlyWhitelistIpAccess: boolean;
  allowRecordingSessions: boolean;
  autoCloseInactiveSessions: boolean;
  checkUpdatesOnStartup: boolean;
  keepScreenOnWhenControlled: boolean;
  quality: number;
  keepScreenOn: 'never' | 'session' | 'service';
  approvalMode: 'password' | 'click' | 'both';
  serviceEnabled: boolean;
  socks5Proxy: string;
  httpProxy: string;
}

export interface EffectiveServerConfig {
  idServer: string;
  relayServer: string;
  apiServer: string;
  key: string;
}

export interface LocalDeviceProfile {
  id: string;
  alias: string;
  platform: string;
  ip: string;
  status: string;
  fingerprint: string;
  directAddress: string;
}

export interface TransferTask {
  id: string;
  name: string;
  direction: 'upload' | 'download';
  progress: number;
  status: 'queued' | 'running' | 'done' | 'failed' | 'cancelled';
  size: string;
}

export interface TerminalSnippet {
  id: string;
  title: string;
  command: string;
  description: string;
}

export interface ChatMessage {
  id: string;
  sender: 'local' | 'remote';
  text: string;
  time: string;
}

export class AppDataService {
  private static instance: AppDataService;
  static readonly OFFICIAL_ID_SERVER: string = 'rs-ny.rustdesk.com';
  static readonly OFFICIAL_RELAY_SERVER: string = 'rs-ny.rustdesk.com';
  static readonly OFFICIAL_API_SERVER: string = 'https://admin.rustdesk.com';

  private settings: SettingsState = AppDataService.createDefaultSettings();
  private password: string = 'd8k4p2';
  private recentSessions: RecentSession[] = AppDataService.createDefaultRecentSessions();
  private addressBook: AddressBookEntry[] = [];
  private localFavorites: Set<string> = new Set();
  private discoveredDevices: AddressBookEntry[] = [];
  private localDevice: LocalDeviceProfile = AppDataService.createDefaultLocalDevice();
  private initialized: boolean = false;
  private peerOnlineMap: Map<string, boolean> = new Map();
  private lanOnlineUntilMap: Map<string, number> = new Map();

  private constructor() {}

  static getInstance(): AppDataService {
    if (!AppDataService.instance) {
      AppDataService.instance = new AppDataService();
    }
    return AppDataService.instance;
  }

  initialize(): void {
    if (this.initialized) {
      return;
    }
    this.loadSettings();
    this.migrateIncomingServiceDefaultOff();
    this.loadRecentSessions();
    this.loadAddressBook();
    this.loadLocalFavorites();
    const password = PreferenceStore.getPassword();
    if (password) {
      this.password = password;
    }
    this.syncIncomingPasswordToCore();
    this.resolveDeviceAlias();
    this.initialized = true;
  }

  private resolveDeviceAlias(): void {
    try {
      const name: string = deviceInfo.marketName;
      if (name.trim().length > 0) {
        this.localDevice.alias = name.trim();
      }
    } catch (_) {
      // fallback to default alias
    }
  }

  getSettings(): SettingsState {
    return this.copySettings(this.settings);
  }

  getEffectiveServerConfig(): EffectiveServerConfig {
    return AppDataService.resolveServerConfig(this.settings);
  }

  updateSettings(settings: Partial<SettingsState>): SettingsState {
    const next: SettingsState = this.copySettings(this.settings);
    if (settings.theme !== undefined) next.theme = settings.theme;
    if (settings.language !== undefined) next.language = settings.language;
    if (settings.notificationsEnabled !== undefined) next.notificationsEnabled = settings.notificationsEnabled;
    if (settings.autoConnect !== undefined) next.autoConnect = settings.autoConnect;
    if (settings.videoQuality !== undefined) next.videoQuality = settings.videoQuality;
    if (settings.allowRemoteControl !== undefined) next.allowRemoteControl = settings.allowRemoteControl;
    if (settings.allowFileTransfer !== undefined) next.allowFileTransfer = settings.allowFileTransfer;
    if (settings.allowClipboard !== undefined) next.allowClipboard = settings.allowClipboard;
    if (settings.idServer !== undefined) next.idServer = AppDataService.normalizeStoredServerValue(settings.idServer, AppDataService.OFFICIAL_ID_SERVER);
    if (settings.relayServer !== undefined) next.relayServer = AppDataService.normalizeStoredServerValue(settings.relayServer, AppDataService.OFFICIAL_RELAY_SERVER);
    if (settings.apiServer !== undefined) next.apiServer = AppDataService.normalizeStoredServerValue(settings.apiServer, AppDataService.OFFICIAL_API_SERVER);
    if (settings.key !== undefined) next.key = settings.key;
    if (settings.enableAudio !== undefined) next.enableAudio = settings.enableAudio;
    if (settings.enableClipboard !== undefined) next.enableClipboard = settings.enableClipboard;
    if (settings.enableFloatingWindow !== undefined) next.enableFloatingWindow = settings.enableFloatingWindow;
    if (settings.autoRecordOutgoing !== undefined) next.autoRecordOutgoing = settings.autoRecordOutgoing;
    if (settings.enableHardwareCodec !== undefined) next.enableHardwareCodec = settings.enableHardwareCodec;
    if (settings.enableAdaptiveBitrate !== undefined) next.enableAdaptiveBitrate = settings.enableAdaptiveBitrate;
    if (settings.showTerminalExtraKeys !== undefined) next.showTerminalExtraKeys = settings.showTerminalExtraKeys;
    if (settings.enableDirectIp !== undefined) next.enableDirectIp = settings.enableDirectIp;
    if (settings.denyLanDiscovery !== undefined) next.denyLanDiscovery = settings.denyLanDiscovery;
    if (settings.allowWebSocket !== undefined) next.allowWebSocket = settings.allowWebSocket;
    if (settings.enableUdpHolePunching !== undefined) next.enableUdpHolePunching = settings.enableUdpHolePunching;
    if (settings.enableIpv6P2p !== undefined) next.enableIpv6P2p = settings.enableIpv6P2p;
    if (settings.autoRecordIncoming !== undefined) next.autoRecordIncoming = settings.autoRecordIncoming;
    if (settings.startOnBoot !== undefined) next.startOnBoot = settings.startOnBoot;
    if (settings.requestRemarkOnSessionEnd !== undefined) next.requestRemarkOnSessionEnd = settings.requestRemarkOnSessionEnd;
    if (settings.twoFactorEnabled !== undefined) next.twoFactorEnabled = settings.twoFactorEnabled;
    if (settings.onlyWhitelistIpAccess !== undefined) next.onlyWhitelistIpAccess = settings.onlyWhitelistIpAccess;
    if (settings.allowRecordingSessions !== undefined) next.allowRecordingSessions = settings.allowRecordingSessions;
    if (settings.autoCloseInactiveSessions !== undefined) next.autoCloseInactiveSessions = settings.autoCloseInactiveSessions;
    if (settings.checkUpdatesOnStartup !== undefined) next.checkUpdatesOnStartup = settings.checkUpdatesOnStartup;
    if (settings.keepScreenOnWhenControlled !== undefined) next.keepScreenOnWhenControlled = settings.keepScreenOnWhenControlled;
    if (settings.quality !== undefined) next.quality = settings.quality;
    if (settings.keepScreenOn !== undefined) next.keepScreenOn = settings.keepScreenOn;
    if (settings.approvalMode !== undefined) next.approvalMode = settings.approvalMode;
    if (settings.serviceEnabled !== undefined) next.serviceEnabled = settings.serviceEnabled;
    if (settings.socks5Proxy !== undefined) next.socks5Proxy = settings.socks5Proxy;
    if (settings.httpProxy !== undefined) next.httpProxy = settings.httpProxy;
    this.settings = next;
    this.persistSettings();
    return this.getSettings();
  }

  saveSettings(settings: SettingsState): void {
    this.settings = this.copySettings(settings);
    this.settings.idServer = AppDataService.normalizeStoredServerValue(this.settings.idServer, AppDataService.OFFICIAL_ID_SERVER);
    this.settings.relayServer = AppDataService.normalizeStoredServerValue(this.settings.relayServer, AppDataService.OFFICIAL_RELAY_SERVER);
    this.settings.apiServer = AppDataService.normalizeStoredServerValue(this.settings.apiServer, AppDataService.OFFICIAL_API_SERVER);
    this.persistSettings();
  }

  static resolveServerConfig(settings: SettingsState): EffectiveServerConfig {
    return {
      idServer: AppDataService.resolveServerValue(settings.idServer, AppDataService.OFFICIAL_ID_SERVER),
      relayServer: AppDataService.resolveServerValue(settings.relayServer, AppDataService.OFFICIAL_RELAY_SERVER),
      apiServer: AppDataService.resolveServerValue(settings.apiServer, AppDataService.OFFICIAL_API_SERVER),
      key: settings.key || ''
    };
  }

  static isUsingOfficialServer(settings: SettingsState): boolean {
    const effective = AppDataService.resolveServerConfig(settings);
    return effective.idServer.toLowerCase() === AppDataService.OFFICIAL_ID_SERVER &&
      effective.relayServer.toLowerCase() === AppDataService.OFFICIAL_RELAY_SERVER &&
      effective.apiServer.toLowerCase() === AppDataService.OFFICIAL_API_SERVER;
  }

  static displayServerValue(value: string, officialLabel: string): string {
    return value.trim().length > 0 ? value.trim() : officialLabel;
  }

  private static resolveServerValue(value: string, officialValue: string): string {
    const normalized = AppDataService.normalizeStoredServerValue(value, officialValue);
    return normalized.length > 0 ? normalized : officialValue;
  }

  private static normalizeStoredServerValue(value: string, officialValue: string): string {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return '';
    }
    if (normalized.toLowerCase() === officialValue.toLowerCase()) {
      return '';
    }
    if (officialValue === AppDataService.OFFICIAL_API_SERVER && normalized.toLowerCase() === 'https://rustdesk.com') {
      return '';
    }
    return normalized;
  }

  getRecentSessions(): RecentSession[] {
    return this.recentSessions.map((session: RecentSession) => this.cloneRecentSession(session));
  }

  addRecentSession(session: RecentSession): void {
    const filtered = this.recentSessions.filter((item: RecentSession) => item.id !== session.id);
    const nextSessions: RecentSession[] = [this.cloneRecentSession(session)];
    filtered.forEach((item: RecentSession) => {
      if (nextSessions.length < 12) {
        nextSessions.push(this.cloneRecentSession(item));
      }
    });
    this.recentSessions = nextSessions;
    this.persistRecentSessions();
  }

  removeRecentSession(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions
      .filter((item: RecentSession) => item.id !== normalizedId)
      .map((item: RecentSession) => this.cloneRecentSession(item));
    this.persistRecentSessions();
  }

  renameRecentSession(id: string, newName: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id === normalizedId) {
        const updated = this.cloneRecentSession(item);
        updated.name = newName;
        return updated;
      }
      return this.cloneRecentSession(item);
    });
    this.persistRecentSessions();
  }

  clearRecentSessions(): void {
    this.recentSessions = [];
    this.persistRecentSessions();
  }

  createRecentSession(id: string, platform: string = 'RustDesk', online: boolean = true, hostname: string = '', username: string = ''): RecentSession {
    const normalizedId = DeviceIdFormatter.parse(id);
    const defaultName = `远程 ${DeviceIdFormatter.format(normalizedId)}`;
    const peerInfo = NativeRustDeskBridge.getPeerInfo(normalizedId);
    let displayName = '';
    if (hostname.trim().length > 0) {
      displayName = hostname.trim();
    } else if (peerInfo.hostname.length > 0) {
      displayName = peerInfo.hostname;
    } else {
      const fromAddressBook = this.getDisplayName(normalizedId);
      if (fromAddressBook.trim().length > 0) {
        displayName = fromAddressBook.trim();
      }
    }
    if (displayName.trim().length === 0) {
      displayName = defaultName;
    }
    let resolvedUsername = username.trim();
    if (resolvedUsername.length === 0 && peerInfo.username.length > 0) {
      resolvedUsername = peerInfo.username;
    }
    displayName = AppDataService.formatPeerDisplayName(displayName, resolvedUsername);
    let resolvedPlatform = platform;
    if ((resolvedPlatform === 'RustDesk' || resolvedPlatform.trim().length === 0) && peerInfo.platform.length > 0) {
      resolvedPlatform = peerInfo.platform;
    }
    return {
      id: normalizedId,
      name: displayName,
      username: resolvedUsername,
      time: this.formatRelativeNow(),
      online: online,
      platform: resolvedPlatform
    };
  }

  refreshSessionOnlineStatus(id: string): boolean {
    return false;
  }

  isPeerOnline(id: string): boolean {
    const normalizedId = DeviceIdFormatter.parse(id);
    const lanOnlineUntil = this.lanOnlineUntilMap.get(normalizedId) ?? 0;
    if (lanOnlineUntil > Date.now()) {
      return true;
    }
    return this.peerOnlineMap.get(normalizedId) ?? false;
  }

  markLanPeerOnline(id: string, ttlMs: number = 15000): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    if (normalizedId.length === 0) {
      return;
    }
    this.peerOnlineMap.set(normalizedId, true);
    this.lanOnlineUntilMap.set(normalizedId, Date.now() + ttlMs);
    this.updateStoredPeerOnlineState(normalizedId, true);
  }

  updateOnlineStatusFromResult(onlines: string[], offlines: string[]): void {
    onlines.forEach((id: string) => {
      const normalizedId = DeviceIdFormatter.parse(id);
      this.peerOnlineMap.set(normalizedId, true);
      this.updateStoredPeerOnlineState(normalizedId, true);
    });
    offlines.forEach((id: string) => {
      const normalizedId = DeviceIdFormatter.parse(id);
      const lanOnlineUntil = this.lanOnlineUntilMap.get(normalizedId) ?? 0;
      if (lanOnlineUntil > Date.now()) {
        return;
      }
      this.peerOnlineMap.set(normalizedId, false);
      this.updateStoredPeerOnlineState(normalizedId, false);
    });
  }

  private updateStoredPeerOnlineState(id: string, online: boolean): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    let addressChanged = false;
    this.addressBook = this.addressBook.map((item: AddressBookEntry) => {
      if (item.id !== normalizedId || item.online === online) {
        return item;
      }
      addressChanged = true;
      const updated = this.cloneAddressBookEntry(item);
      updated.online = online;
      return updated;
    });
    if (addressChanged) {
      this.persistAddressBook();
    }

    let recentChanged = false;
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id !== normalizedId || item.online === online) {
        return item;
      }
      recentChanged = true;
      const updated = this.cloneRecentSession(item);
      updated.online = online;
      return updated;
    });
    if (recentChanged) {
      this.persistRecentSessions();
    }

    this.discoveredDevices = this.discoveredDevices.map((item: AddressBookEntry) => {
      if (item.id !== normalizedId || item.online === online) {
        return item;
      }
      const updated = this.cloneAddressBookEntry(item);
      updated.online = online;
      return updated;
    });
  }

  updateAddressBookEntryOnline(id: string, online: boolean): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    let changed = false;
    this.addressBook = this.addressBook.map((item: AddressBookEntry) => {
      if (item.id === normalizedId && item.online !== online) {
        changed = true;
        const updated = this.cloneAddressBookEntry(item);
        updated.online = online;
        return updated;
      }
      return item;
    });
    if (changed) {
      this.persistAddressBook();
    }
  }

  updateRecentSessionOnline(id: string, online: boolean): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id === normalizedId) {
        const updated = this.cloneRecentSession(item);
        updated.online = online;
        return updated;
      }
      return this.cloneRecentSession(item);
    });
    this.persistRecentSessions();
  }

  updateRecentSessionName(id: string, hostname: string): void {
    if (hostname.trim().length === 0) {
      return;
    }
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id === normalizedId) {
        const updated = this.cloneRecentSession(item);
        const normalizedName = this.normalizeRecentSessionName(
          AppDataService.formatPeerDisplayName(hostname.trim(), updated.username)
        );
        if (normalizedName.trim().length > 0) {
          updated.name = normalizedName;
        }
        return updated;
      }
      return this.cloneRecentSession(item);
    });
    this.persistRecentSessions();
  }

  updateRecentSessionPlatform(id: string, platform: string): void {
    if (platform.trim().length === 0) {
      return;
    }
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id === normalizedId) {
        const updated = this.cloneRecentSession(item);
        updated.platform = platform.trim();
        return updated;
      }
      return this.cloneRecentSession(item);
    });
    this.persistRecentSessions();
  }

  updateRecentSessionUsername(id: string, username: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.recentSessions = this.recentSessions.map((item: RecentSession) => {
      if (item.id === normalizedId) {
        const updated = this.cloneRecentSession(item);
        updated.username = username.trim();
        updated.name = AppDataService.formatPeerDisplayName(updated.name, updated.username);
        return updated;
      }
      return this.cloneRecentSession(item);
    });
    this.persistRecentSessions();
  }

  getFavorites(): AddressBookEntry[] {
    const result: AddressBookEntry[] = [];
    this.localFavorites.forEach((id: string) => {
      const abEntry = this.getAddressBookEntry(id);
      if (abEntry) {
        const cloned = this.cloneAddressBookEntry(abEntry);
        cloned.favorite = true;
        result.push(cloned);
        return;
      }
      const session = this.recentSessions.find((s: RecentSession) => s.id === id);
      if (session) {
        result.push({
          id: id,
          alias: session.name,
          note: '',
          group: '',
          online: this.isPeerOnline(id),
          favorite: true,
          platform: session.platform
        });
        return;
      }
      result.push({
        id: id,
        alias: DeviceIdFormatter.format(id),
        note: '',
        group: '',
        online: this.isPeerOnline(id),
        favorite: true,
        platform: ''
      });
    });
    return result;
  }

  isFavorite(id: string): boolean {
    const normalizedId = DeviceIdFormatter.parse(id);
    return this.localFavorites.has(normalizedId);
  }

  toggleFavorite(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    if (this.localFavorites.has(normalizedId)) {
      this.localFavorites.delete(normalizedId);
    } else {
      this.localFavorites.add(normalizedId);
    }
    this.persistLocalFavorites();
  }

  addFavorite(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.localFavorites.add(normalizedId);
    this.persistLocalFavorites();
  }

  removeFavorite(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.localFavorites.delete(normalizedId);
    this.persistLocalFavorites();
  }

  private persistLocalFavorites(): void {
    PreferenceStore.setLocalFavorites(JSON.stringify(Array.from(this.localFavorites)));
  }

  private loadLocalFavorites(): void {
    const value = PreferenceStore.getLocalFavorites();
    if (value) {
      try {
        const arr = JSON.parse(value) as string[];
        arr.forEach((id: string) => this.localFavorites.add(DeviceIdFormatter.parse(id)));
      } catch (_e) {}
    }
  }

  getDiscoveredDevices(): AddressBookEntry[] {
    return this.discoveredDevices.map((entry: AddressBookEntry) => this.cloneAddressBookEntry(entry));
  }

  addDiscoveredDevice(entry: AddressBookEntry): void {
    const normalized = this.normalizeAddressBookEntry(entry);
    const existingIndex = this.discoveredDevices.findIndex((item: AddressBookEntry) => item.id === normalized.id);
    if (existingIndex >= 0) {
      this.discoveredDevices.splice(existingIndex, 1, normalized);
    } else {
      this.discoveredDevices.unshift(normalized);
    }
  }

  removeDiscoveredDevice(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    this.discoveredDevices = this.discoveredDevices.filter((item: AddressBookEntry) => item.id !== normalizedId);
  }

  clearDiscoveredDevices(): void {
    this.discoveredDevices = [];
  }

  getAddressBook(): AddressBookEntry[] {
    return this.addressBook.map((entry: AddressBookEntry) => this.cloneAddressBookEntry(entry));
  }

  getAddressBookEntry(id: string): AddressBookEntry | undefined {
    const normalizedId = DeviceIdFormatter.parse(id);
    const entry = this.addressBook.find((item: AddressBookEntry) => item.id === normalizedId);
    return entry ? this.cloneAddressBookEntry(entry) : undefined;
  }

  addAddressBookEntry(entry: AddressBookEntry): AddressBookEntry {
    const normalized = this.normalizeAddressBookEntry(entry);
    const existingIndex = this.addressBook.findIndex((item: AddressBookEntry) => item.id === normalized.id);
    if (existingIndex >= 0) {
      this.addressBook.splice(existingIndex, 1, normalized);
    } else {
      this.addressBook.unshift(normalized);
    }
    this.persistAddressBook();
    return this.cloneAddressBookEntry(normalized);
  }

  updateAddressBookEntry(id: string, patch: Partial<AddressBookEntry>): AddressBookEntry | undefined {
    const existing = this.addressBook.find((item: AddressBookEntry) => item.id === id);
    if (!existing) {
      return undefined;
    }
    const next: AddressBookEntry = this.cloneAddressBookEntry(existing);
    if (patch.alias !== undefined) next.alias = patch.alias;
    if (patch.note !== undefined) next.note = patch.note;
    if (patch.group !== undefined) next.group = patch.group;
    if (patch.online !== undefined) next.online = patch.online;
    if (patch.favorite !== undefined) next.favorite = patch.favorite;
    const normalized = this.normalizeAddressBookEntry(next);
    const index = this.addressBook.findIndex((item: AddressBookEntry) => item.id === id);
    this.addressBook.splice(index, 1, normalized);
    this.persistAddressBook();
    return this.cloneAddressBookEntry(normalized);
  }

  removeAddressBookEntry(id: string): void {
    this.addressBook = this.addressBook.filter((entry: AddressBookEntry) => entry.id !== id);
    this.persistAddressBook();
    this.recentSessions = this.recentSessions.map((session: RecentSession) => {
      if (session.id !== id) {
        return this.cloneRecentSession(session);
      }
      const nextSession = this.cloneRecentSession(session);
      nextSession.name = `远程 ${DeviceIdFormatter.format(id)}`;
      return nextSession;
    });
    this.persistRecentSessions();
  }

  setAddressBook(entries: AddressBookEntry[]): void {
    this.addressBook = entries.map((entry: AddressBookEntry) => this.normalizeAddressBookEntry(entry));
    this.persistAddressBook();
  }

  getDisplayName(id: string): string {
    const normalizedId = DeviceIdFormatter.parse(id);
    const normalizedEntry = this.getAddressBookEntry(normalizedId);
    if (normalizedEntry) {
      const alias = normalizedEntry.alias.trim();
      if (alias.length > 0 && !alias.startsWith('远程 ') && !alias.startsWith('Remote ')) {
        return alias;
      }
    }
    return '';
  }

  getPassword(): string {
    return this.password;
  }

  setPassword(password: string): void {
    this.password = password.trim();
    PreferenceStore.setPassword(this.password);
    this.syncIncomingPasswordToCore();
  }

  generatePassword(): string {
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    let result = '';
    for (let index = 0; index < 6; index++) {
      result += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
    }
    this.password = result;
    PreferenceStore.setPassword(this.password);
    this.syncIncomingPasswordToCore();
    return result;
  }

  private syncIncomingPasswordToCore(): void {
    if (this.password.trim().length === 0) {
      return;
    }
    NativeRustDeskBridge.setLocalOption('verification-method', 'use-temporary-password');
    NativeRustDeskBridge.setLocalOption('approve-mode', 'password');
    NativeRustDeskBridge.setLocalOption('temporary-password', this.password);
  }

  getLocalDevice(): LocalDeviceProfile {
    return {
      id: this.localDevice.id,
      alias: this.localDevice.alias,
      platform: this.localDevice.platform,
      ip: this.localDevice.ip,
      status: this.localDevice.status,
      fingerprint: this.localDevice.fingerprint,
      directAddress: this.localDevice.directAddress
    };
  }

  updateLocalDeviceStatus(status: string): LocalDeviceProfile {
    this.localDevice.status = status;
    return this.getLocalDevice();
  }

  updateLocalDevice(patch: Partial<LocalDeviceProfile>): LocalDeviceProfile {
    if (patch.alias !== undefined) {
      const value = patch.alias.trim();
      if (value.length > 0) {
        this.localDevice.alias = value;
      }
    }
    if (patch.platform !== undefined) {
      this.localDevice.platform = patch.platform;
    }
    if (patch.ip !== undefined) {
      this.localDevice.ip = patch.ip;
    }
    if (patch.status !== undefined) {
      this.localDevice.status = patch.status;
    }
    if (patch.fingerprint !== undefined) {
      this.localDevice.fingerprint = patch.fingerprint;
    }
    if (patch.directAddress !== undefined) {
      this.localDevice.directAddress = patch.directAddress;
    }
    return this.getLocalDevice();
  }

  setServiceEnabled(enabled: boolean): LocalDeviceProfile {
    this.updateSettings({ serviceEnabled: enabled });
    this.localDevice.status = enabled ? '服务已就绪，可接收传入连接' : '服务已停止';
    return this.getLocalDevice();
  }

  getTransferTasks(deviceId: string): TransferTask[] {
    /*
    return [
      { id: `${deviceId}-1`, name: '日志归档.zip', direction: 'download', progress: 100, status: 'done', size: '18 MB' },
      { id: `${deviceId}-2`, name: '安装包.hap', direction: 'upload', progress: 68, status: 'running', size: '96 MB' },
      { id: `${deviceId}-3`, name: '屏幕截图', direction: 'download', progress: 0, status: 'queued', size: '24 MB' }
    ];
    */
    return [];
  }

  getTerminalSnippets(): TerminalSnippet[] {
    return [
      { id: 'health', title: '健康检查', command: 'uname -a && df -h && free -m', description: '查看系统版本、磁盘和内存使用情况。' },
      { id: 'logs', title: '最近日志', command: 'tail -n 200 /var/log/syslog', description: '检查最近的服务日志输出。' },
      { id: 'network', title: '网络状态', command: 'ip addr && netstat -tunlp', description: '查看网卡、监听端口和当前连接。' }
    ];
  }

  getChatMessages(deviceId: string): ChatMessage[] {
    return [];
  }

  private persistSettings(): void {
    PreferenceStore.setSettings(JSON.stringify(this.settings));
  }

  private persistRecentSessions(): void {
    PreferenceStore.setRecentSessions(JSON.stringify(this.recentSessions));
  }

  private persistAddressBook(): void {
    PreferenceStore.setAddressBook(JSON.stringify(this.addressBook));
  }

  private loadSettings(): void {
    const value = PreferenceStore.getSettings();
    if (!value) {
      this.persistSettings();
      return;
    }
    try {
      const parsed = JSON.parse(value) as Partial<SettingsState>;
      this.settings = AppDataService.createDefaultSettings();
      this.updateSettings(parsed);
    } catch (_error) {
      this.settings = AppDataService.createDefaultSettings();
      this.persistSettings();
    }
  }

  private migrateIncomingServiceDefaultOff(): void {
    if (PreferenceStore.hasMigratedIncomingServiceDefaultOff()) {
      return;
    }
    if (this.settings.serviceEnabled) {
      this.updateSettings({ serviceEnabled: false });
      this.localDevice.status = '服务已停止';
    }
    PreferenceStore.setMigratedIncomingServiceDefaultOff();
  }

  private loadRecentSessions(): void {
    const value = PreferenceStore.getRecentSessions();
    if (!value) {
      this.persistRecentSessions();
      return;
    }
    try {
      const parsed = JSON.parse(value) as RecentSession[];
      const normalizedSessions = parsed.map((item: RecentSession) => this.cloneRecentSession(item));
      this.recentSessions = AppDataService.isSeededRecentSessionList(normalizedSessions) ? [] : normalizedSessions;
      if (this.recentSessions.length !== normalizedSessions.length) {
        this.persistRecentSessions();
      }
    } catch (_error) {
      this.recentSessions = AppDataService.createDefaultRecentSessions();
      this.persistRecentSessions();
    }
  }

  private loadAddressBook(): void {
    const value = PreferenceStore.getAddressBook();
    if (!value) {
      this.addressBook = [];
      this.persistAddressBook();
      return;
    }
    try {
      const parsed = JSON.parse(value) as AddressBookEntry[];
      this.addressBook = parsed.map((item: AddressBookEntry) => this.normalizeAddressBookEntry(item));
      if (this.isSeededAddressBook(this.addressBook)) {
        this.addressBook = [];
        this.persistAddressBook();
      }
    } catch (_error) {
      this.addressBook = [];
      this.persistAddressBook();
    }
  }

  private isSeededAddressBook(entries: AddressBookEntry[]): boolean {
    const seededIds = ['918224103', '520770642', '341888901', '771006543'];
    if (entries.length !== seededIds.length) {
      return false;
    }
    for (let i = 0; i < seededIds.length; i++) {
      if (entries[i].id !== seededIds[i]) {
        return false;
      }
    }
    return true;
  }

  private normalizeAddressBookEntry(entry: AddressBookEntry): AddressBookEntry {
    const normalizedId = DeviceIdFormatter.parse(entry.id);
    const normalizedAlias = entry.alias.trim().length > 0
      ? entry.alias.trim()
      : `远程 ${DeviceIdFormatter.format(normalizedId)}`;
    const normalizedGroup = this.normalizeAddressBookGroup(entry.group);
    return {
      id: normalizedId,
      alias: this.normalizeAddressBookAlias(normalizedAlias),
      note: this.normalizeAddressBookNote(entry.note),
      group: normalizedGroup,
      online: entry.online,
      favorite: entry.favorite,
      platform: entry.platform ?? ''
    };
  }

  private copySettings(source: SettingsState): SettingsState {
    return {
      theme: source.theme,
      language: source.language,
      notificationsEnabled: source.notificationsEnabled,
      autoConnect: source.autoConnect,
      videoQuality: source.videoQuality,
      allowRemoteControl: source.allowRemoteControl,
      allowFileTransfer: source.allowFileTransfer,
      allowClipboard: source.allowClipboard,
      idServer: source.idServer,
      relayServer: source.relayServer,
      apiServer: source.apiServer,
      key: source.key,
      enableAudio: source.enableAudio,
      enableClipboard: source.enableClipboard,
      enableFloatingWindow: source.enableFloatingWindow,
      autoRecordOutgoing: source.autoRecordOutgoing,
      enableHardwareCodec: source.enableHardwareCodec,
      enableAdaptiveBitrate: source.enableAdaptiveBitrate,
      showTerminalExtraKeys: source.showTerminalExtraKeys,
      enableDirectIp: source.enableDirectIp,
      denyLanDiscovery: source.denyLanDiscovery,
      allowWebSocket: source.allowWebSocket,
      enableUdpHolePunching: source.enableUdpHolePunching,
      enableIpv6P2p: source.enableIpv6P2p,
      autoRecordIncoming: source.autoRecordIncoming,
      startOnBoot: source.startOnBoot,
      requestRemarkOnSessionEnd: source.requestRemarkOnSessionEnd,
      twoFactorEnabled: source.twoFactorEnabled,
      onlyWhitelistIpAccess: source.onlyWhitelistIpAccess,
      allowRecordingSessions: source.allowRecordingSessions,
      autoCloseInactiveSessions: source.autoCloseInactiveSessions,
      checkUpdatesOnStartup: source.checkUpdatesOnStartup,
      keepScreenOnWhenControlled: source.keepScreenOnWhenControlled,
      quality: source.quality,
      keepScreenOn: source.keepScreenOn,
      approvalMode: source.approvalMode,
      serviceEnabled: source.serviceEnabled,
      socks5Proxy: source.socks5Proxy,
      httpProxy: source.httpProxy
    };
  }

  private cloneRecentSession(session: RecentSession): RecentSession {
    const normalizedId = DeviceIdFormatter.parse(session.id);
    const defaultName = `远程 ${DeviceIdFormatter.format(normalizedId)}`;
    const normalizedName = this.normalizeRecentSessionName(session.name);
    const finalName = normalizedName.trim().length > 0 ? normalizedName : defaultName;
    return {
      id: normalizedId,
      name: finalName,
      username: session.username ?? '',
      time: this.normalizeRecentSessionTime(session.time),
      online: session.online,
      platform: session.platform
    };
  }

  private cloneAddressBookEntry(entry: AddressBookEntry): AddressBookEntry {
    const normalizedId = DeviceIdFormatter.parse(entry.id);
    const remoteLabel = `远程 ${DeviceIdFormatter.format(normalizedId)}`;
    const remoteDeviceLabel = `远程设备 ${DeviceIdFormatter.format(normalizedId)}`;
    return {
      id: normalizedId,
      alias: entry.alias === `远程 ${normalizedId}`
        ? remoteLabel
        : (entry.alias === `远程设备 ${normalizedId}` ? remoteDeviceLabel : this.normalizeAddressBookAlias(entry.alias)),
      note: this.normalizeAddressBookNote(entry.note),
      group: this.normalizeAddressBookGroup(entry.group),
      online: entry.online,
      favorite: entry.favorite,
      platform: entry.platform ?? ''
    };
  }

  private formatRelativeNow(): string {
    return '刚刚';
  }

  private normalizeRecentSessionName(name: string): string {
    if (name.startsWith('远程 ')) {
      return '';
    }
    if (name.startsWith('Remote ')) {
      return '';
    }
    if (name === 'Office Mac mini') {
      return '办公室 Mac mini';
    }
    if (name === 'Design Workstation') {
      return '设计工作站';
    }
    if (name === 'Warehouse Tablet') {
      return '仓库平板';
    }
    return name;
  }

  private static formatPeerDisplayName(hostname: string, username: string): string {
    const normalizedHostname = hostname.trim();
    const normalizedUsername = username.trim();
    if (normalizedHostname.length === 0) {
      return normalizedUsername;
    }
    if (normalizedUsername.length === 0) {
      return normalizedHostname;
    }
    if (normalizedHostname.startsWith(`${normalizedUsername}@`)) {
      return normalizedHostname;
    }
    return `${normalizedUsername}@${normalizedHostname}`;
  }

  private normalizeRecentSessionTime(time: string): string {
    if (time === 'Just now') {
      return '刚刚';
    }
    if (time === '2 min ago') {
      return '2 分钟前';
    }
    if (time === '18 min ago') {
      return '18 分钟前';
    }
    if (time === 'Yesterday') {
      return '昨天';
    }
    return time;
  }

  private normalizeAddressBookAlias(alias: string): string {
    if (alias === 'Office Mac mini') {
      return '办公室 Mac mini';
    }
    if (alias === 'Design Workstation') {
      return '设计工作站';
    }
    if (alias === 'Android Test Phone') {
      return 'Android 测试手机';
    }
    if (alias === 'Store Kiosk') {
      return '门店展示终端';
    }
    return alias;
  }

  private normalizeAddressBookNote(note: string): string {
    if (note === 'Main release and maintenance device.') {
      return '主发布与维护设备。';
    }
    if (note === 'Graphics design and CAD environment.') {
      return '图形设计与 CAD 工作环境。';
    }
    if (note === 'Regression testing device.') {
      return '回归测试设备。';
    }
    if (note === 'Locked-down demo environment.') {
      return '受限的演示环境。';
    }
    return note.trim();
  }

  private normalizeAddressBookGroup(group: string): string {
    const normalizedGroup = group.trim();
    if (normalizedGroup.length === 0) {
      return '未分组';
    }
    if (normalizedGroup === 'Ops') {
      return '运维';
    }
    if (normalizedGroup === 'Design') {
      return '设计';
    }
    if (normalizedGroup === 'QA') {
      return '测试';
    }
    if (normalizedGroup === 'Retail') {
      return '零售';
    }
    return normalizedGroup;
  }

  private static createDefaultSettings(): SettingsState {
    return {
      theme: 'auto',
      language: 'zh-CN',
      notificationsEnabled: true,
      autoConnect: false,
      videoQuality: 'medium',
      allowRemoteControl: true,
      allowFileTransfer: true,
      allowClipboard: true,
      idServer: '',
      relayServer: '',
      apiServer: '',
      key: '',
      enableAudio: true,
      enableClipboard: true,
      enableFloatingWindow: false,
      autoRecordOutgoing: false,
      enableHardwareCodec: true,
      enableAdaptiveBitrate: true,
      showTerminalExtraKeys: true,
      enableDirectIp: true,
      denyLanDiscovery: false,
      allowWebSocket: true,
      enableUdpHolePunching: true,
      enableIpv6P2p: false,
      autoRecordIncoming: false,
      startOnBoot: false,
      requestRemarkOnSessionEnd: false,
      twoFactorEnabled: false,
      onlyWhitelistIpAccess: false,
      allowRecordingSessions: true,
      autoCloseInactiveSessions: false,
      checkUpdatesOnStartup: true,
      keepScreenOnWhenControlled: false,
      quality: 80,
      keepScreenOn: 'session',
      approvalMode: 'password',
      serviceEnabled: false,
      socks5Proxy: '',
      httpProxy: ''
    };
  }

  private static createDefaultRecentSessions(): RecentSession[] {
    return [];
  }

  private static isSeededRecentSessionList(sessions: RecentSession[]): boolean {
    if (sessions.length !== 3) {
      return false;
    }
    const expectedIds: string[] = ['918224103', '520770642', '103441888'];
    for (let index = 0; index < expectedIds.length; index += 1) {
      if (sessions[index].id !== expectedIds[index]) {
        return false;
      }
    }
    return true;
  }

  private static createDefaultAddressBook(): AddressBookEntry[] {
    return [
      { id: '918224103', alias: '办公室 Mac mini', note: '主发布与维护设备。', group: '运维', online: true, favorite: true, platform: 'Mac OS' },
      { id: '520770642', alias: '设计工作站', note: '图形设计与 CAD 工作环境。', group: '设计', online: true, favorite: true, platform: 'Windows' },
      { id: '341888901', alias: 'Android 测试手机', note: '回归测试设备。', group: '测试', online: false, favorite: false, platform: 'Android' },
      { id: '771006543', alias: '门店展示终端', note: '受限的演示环境。', group: '零售', online: true, favorite: false, platform: '' }
    ];
  }

  private static createDefaultLocalDevice(): LocalDeviceProfile {
    return {
      id: '',
      alias: 'HarmonyOS 平板',
      platform: 'HarmonyOS 6.0',
      ip: '192.168.1.36',
      status: '等待官方 RustDesk 原生核心',
      fingerprint: '等待官方原生核心',
      directAddress: '等待官方原生核心'
    };
  }
}
