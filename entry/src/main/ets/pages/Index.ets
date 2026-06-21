import { AppDataService, LocalDeviceProfile, RecentSession, SettingsState } from '../services/AppDataService';
import router from '@ohos.router';
import { ThemeConfig, ThemeManager, AppThemeMode } from '../common/ThemeConfig';
import { AddressBookEntry } from '../services/AppDataService';
import {
  CardContainer,
  CaptionLabel,
  CustomTextInput,
  EmptyState,
  InfoRow,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  SectionTitle,
  StatusBadge
} from '../common/CommonComponents';
import { OfficialCoreState, OfficialRustDeskBridge, OfficialSessionEvent, OnlineStatusResult } from '../services/OfficialRustDeskBridge';
import { CoreLoaderService } from '../services/CoreLoaderService';
import { AccountService } from '../services/AccountService';
import { AppState, AccountState } from '../services/AppState';
import { ChatMessage, ChatMessageType, ChatService, ChatSession, ChatEvent } from '../services/ChatService';
import { ClipboardService } from '../services/ClipboardService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { PreferenceStore } from '../services/PreferenceStore';
import { NativeRustDeskBridge } from '../services/NativeRustDeskBridge';
import { AppContextService } from '../services/AppContextService';
import { ServerConfigCodec, ServerConfigImportResult } from '../services/ServerConfigCodec';
import { WindowChromeService } from '../services/WindowChromeService';
import { BuildInfo } from '../common/BuildInfo';
import { CoreBuildInfo } from '../common/CoreBuildInfo';
import drawing from '@ohos.graphics.drawing';

import { LanDiscoveryService } from '../services/LanDiscoveryService';
import { ScreenCaptureService } from '../services/ScreenCaptureService';
import { PermissionService } from '../services/PermissionService';
import { PermissionStatus } from '../services/PermissionService';
import { Permissions } from '@ohos.abilityAccessCtrl';
import hilog from '@ohos.hilog';
import connection from '@ohos.net.connection';

type HomeTab = 'connect' | 'chat' | 'share' | 'settings';
type ConnectPeerTab = 'recent' | 'favorites' | 'discovered' | 'addressBook' | 'account' | 'core';

interface CoreModuleInfo {
  kind: string;
  name: string;
  path: string;
  source: string;
  fileSize: string;
  fileSizeMB: string;
  hash: string;
  compatibleOfficialVersion: string;
  validElf: boolean;
  buildTime: string;
  statusText: string;
  statusActive: boolean;
  icon: string;
  lastError: string;
  detailMessage: string;
  statusSummary: string;
  bridgeFunctionCount: string;
  napiRegisteredCount: string;
  coreVersion: string;
  deviceId: string;
  fingerprint: string;
  upstreamVersion: string;
}

interface PeerInfoCacheEntry {
  hostname: string;
  username: string;
  platform: string;
  alias: string;
  cachedAt: number;
}

const ALL_TABS: ConnectPeerTab[] = ['recent', 'favorites', 'discovered', 'addressBook', 'account', 'core'];

function loadVisibleTabs(): Set<ConnectPeerTab> {
  const saved = PreferenceStore.getVisibleTabs();
  if (saved) {
    try {
      const arr = JSON.parse(saved) as string[];
      const tabs = arr.filter((t: string) => ALL_TABS.includes(t as ConnectPeerTab)) as ConnectPeerTab[];
      if (tabs.length > 0) {
        return new Set<ConnectPeerTab>(tabs);
      }
    } catch (_e) {}
  }
  return new Set<ConnectPeerTab>(ALL_TABS);
}

function saveVisibleTabs(tabs: Set<ConnectPeerTab>): void {
  PreferenceStore.setVisibleTabs(JSON.stringify(Array.from(tabs)));
}

interface DeviceRouteParams {
  deviceId: string;
  showPasswordDialog?: boolean;
  passwordPromptProactive?: boolean;
}

@Entry
@Component
struct Index {
  private appData: AppDataService = AppDataService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private accountService: AccountService = AccountService.getInstance();
  private appState: AppState = AppState.getInstance();
  private chatService: ChatService = ChatService.getInstance();
  private clipboardService: ClipboardService = ClipboardService.getInstance();
  private refreshTimer: number = -1;
  private shareWarningTimer: number = -1;
  private refreshStateBusy: boolean = false;
  private onlineStatusPollTimer: number = -1;
  private onlineStatusPollInterval: number = 5000;
  private onlineStatusPollCount: number = 0;
  private onlineStatusPollMaxCount: number = 3;
  private peerInfoCache: Map<string, PeerInfoCacheEntry> = new Map();
  private static readonly PEER_INFO_CACHE_TTL: number = 15000;
  private pendingConnectionMonitorId: number = 0;
  private pendingConnectionRetryCount: number = 0;
  private pendingConnectionRetryLimit: number = 1;
  private pendingConnectionInactivePollCount: number = 0;
  private bridgeListener = (event: OfficialSessionEvent): void => {
    const prevReady = this.officialCoreState.coreReady;
    const prevPeerId = this.officialCoreState.activePeerId.trim();
    this.officialCoreState = this.officialBridge.getCoreState();
    AppStorage.setOrCreate<boolean>('coreReady', this.officialCoreState.coreReady);
    this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
    this.syncPendingConnectionUi(this.officialCoreState);
    if (event.kind === 'peer-info') {
      this.refreshRecentSessionFromPeerInfo(event.peerId, event.detail);
    }
    if (prevReady !== this.officialCoreState.coreReady) {
      this.refreshCoreDetailInfo();
      if (this.officialCoreState.coreReady) {
        this.startOnlineStatusPoll();
      }
    }
    const currentPeerId = this.officialCoreState.activePeerId.trim();
    if (prevPeerId !== currentPeerId) {
      if (currentPeerId.length > 0) {
        const pendingPeerId = this.pendingPeerId.trim();
        if (pendingPeerId.length === 0 || pendingPeerId === currentPeerId) {
          this.selectLatestChatPeer(currentPeerId);
        }
        this.chatMessages = this.chatService.getMessages(currentPeerId);
        this.hasHadSession = true;
        this.refreshChatSessions();
        if (this.currentTab === 'chat' && this.chatService.getUnreadCount(currentPeerId) > 0) {
          this.chatService.markAsRead(currentPeerId);
        }
        if (this.chatMessages.length > 0) {
          this.scheduleChatTabScroll(50);
        }
      }
    } else if (event.kind === 'session-connected' || event.kind === 'session-closed' || event.kind === 'session-error') {
      this.refreshCurrentSessionChat(true);
    }
    if (event.kind === 'session-closed' || event.kind === 'closed') {
      this.resetConnectionUiAfterTerminalEvent();
    } else if (event.kind === 'session-error' && !this.shouldPromptForPassword(event.detail)) {
      this.officialCoreState = this.officialBridge.getCoreState();
      const finalError = this.officialCoreState.lastError || this.officialCoreState.detailMessage || event.detail;
      this.resetConnectionUiAfterTerminalEvent(finalError);
      this.refreshCoreDetailInfo();
    }
  };
  private onlineStatusListener = (result: OnlineStatusResult): void => {
    this.appData.updateOnlineStatusFromResult(result.onlines, result.offlines);
    this.recentSessions = this.appData.getRecentSessions();
    this.addressBookVersion++;
    this.peerOnlineVersion++;
  };
  private lanDiscoveryListener = (): void => {
    this.discoveredVersion++;
    this.peerOnlineVersion++;
  };
  private chatEventListener = (event: ChatEvent): void => {
    if (event.type === 'message_received' || event.type === 'message_sent' || event.type === 'session_updated') {
      this.refreshChatSessions();
      this.refreshCurrentSessionChat(true);
    }
  };

  @State currentTab: HomeTab = 'connect';
  @State currentConnectTab: ConnectPeerTab = 'recent';
  @State isConnectTabRefreshing: boolean = false;
  @State connectTabRefreshAngle: number = 0;
  private connectTabRefreshTimer: number = -1;
  @State showConnectTabVisibilityMenu: boolean = false;
  @State showIdSuggestions: boolean = false;
  @State deviceIdInputFocused: boolean = false;
  @State showSortMenu: boolean = false;
  @State showSearchInput: boolean = false;
  @State searchText: string = '';
  @State settingsOptionVersion: number = 0;
  @State currentSort: string = I18nService.getInstance().translate('Remote ID');
  @State visibleConnectTabs: Set<ConnectPeerTab> = loadVisibleTabs();
  @State addressBookVersion: number = 0;
  @State discoveredVersion: number = 0;
  @State peerOnlineVersion: number = 0;
  @State deviceId: string = '';
  @State deviceIdDisplay: string = '';
  @State deviceIdInputKey: number = 0;
  private deviceIdInputController: TextInputController = new TextInputController();
  private deviceIdSelectionEnd: number = 0;
  private deviceIdCaretRestoreVersion: number = 0;
  private pendingDeviceIdSelection: string = '';
  @State hasHadSession: boolean = false;
  @State lastSessionPeerId: string = '';
  @State statusMessage: string = '';
  @State statusMessageKey: string = '';
  @State statusMessageTargetId: string = '';
  private setStatusMessage(key: string, targetId: string = ''): void {
    this.statusMessageKey = key;
    this.statusMessageTargetId = targetId;
    this.statusMessage = this.resolveStatusMessage(key, targetId);
  }
  private setStatusMessageRaw(raw: string): void {
    this.statusMessageKey = '';
    this.statusMessageTargetId = '';
    const maxLen = 8;
    if (raw.length > maxLen) {
      this.statusMessage = raw.substring(0, maxLen);
    } else {
      this.statusMessage = raw;
    }
  }
  private getIdSuggestions(): Array<RecentSession | AddressBookEntry> {
    const raw = this.deviceId.trim();
    if (raw.length < 3) {
      return [];
    }
    const query = raw.toLowerCase();
    const results: Array<RecentSession | AddressBookEntry> = [];
    const seen = new Set<string>();
    for (const s of this.recentSessions) {
      if (s.id.replace(/\s+/g, '').toLowerCase().includes(query) && !seen.has(s.id)) {
        seen.add(s.id);
        results.push(s);
      }
    }
    for (const e of this.appData.getAddressBook()) {
      if (e.id.replace(/\s+/g, '').toLowerCase().includes(query) && !seen.has(e.id)) {
        seen.add(e.id);
        results.push(e);
      }
    }
    return results.slice(0, 5);
  }

  private sanitizeConnectionTargetInput(value: string): string {
    return value.replace(/\s+/g, '').replace(/[^0-9A-Za-z.:[\]-]/g, '');
  }

  private countConnectionTargetCharactersBeforeCaret(value: string, caret: number): number {
    const safeCaret = Math.max(0, Math.min(caret, value.length));
    return this.sanitizeConnectionTargetInput(value.slice(0, safeCaret)).length;
  }

  private mapConnectionTargetCaret(displayValue: string, rawCaret: number): number {
    if (rawCaret <= 0) {
      return 0;
    }
    let rawCount = 0;
    for (let index = 0; index < displayValue.length; index++) {
      if (displayValue[index] !== ' ') {
        rawCount++;
        if (rawCount >= rawCaret) {
          return index + 1;
        }
      }
    }
    return displayValue.length;
  }

  private resolveRawCaretAfterEdit(previousValue: string, nextValue: string, fallbackCaret: number): number {
    if (previousValue === nextValue) {
      return this.countConnectionTargetCharactersBeforeCaret(nextValue, fallbackCaret);
    }
    let prefixLength = 0;
    const sharedLength = Math.min(previousValue.length, nextValue.length);
    while (prefixLength < sharedLength && previousValue[prefixLength] === nextValue[prefixLength]) {
      prefixLength++;
    }
    let suffixLength = 0;
    while (suffixLength < previousValue.length - prefixLength &&
      suffixLength < nextValue.length - prefixLength &&
      previousValue[previousValue.length - 1 - suffixLength] === nextValue[nextValue.length - 1 - suffixLength]) {
      suffixLength++;
    }
    const changedEnd = nextValue.length - suffixLength;
    return this.countConnectionTargetCharactersBeforeCaret(nextValue, changedEnd);
  }

  private restoreDeviceIdCaret(position: number): void {
    this.deviceIdSelectionEnd = position;
    const restoreVersion = ++this.deviceIdCaretRestoreVersion;
    [0, 40, 120].forEach((delay: number) => {
      setTimeout(() => {
        if (restoreVersion === this.deviceIdCaretRestoreVersion) {
          this.deviceIdInputController.caretPosition(position);
        }
      }, delay);
    });
  }

  private selectDeviceIdInputTarget(value: string): void {
    const normalized = this.sanitizeConnectionTargetInput(value);
    this.pendingDeviceIdSelection = normalized;
    this.deviceId = normalized;
    this.deviceIdDisplay = this.isNumericConnectionTarget(normalized) ? this.formatId(normalized) : normalized;
    this.deviceIdInputKey++;
    this.showIdSuggestions = false;
    this.restoreDeviceIdCaret(this.deviceIdDisplay.length);
    setTimeout(() => {
      if (this.pendingDeviceIdSelection === normalized) {
        this.pendingDeviceIdSelection = '';
      }
    }, 300);
  }

  private isNumericConnectionTarget(value: string): boolean {
    return /^\d+$/.test(value.trim());
  }

  private isValidPort(value: string | undefined): boolean {
    if (value === undefined || value.length === 0) {
      return true;
    }
    const port = Number(value);
    return Number.isInteger(port) && port >= 1 && port <= 65535;
  }

  private isValidIpv4Target(value: string): boolean {
    const match = value.match(/^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$/);
    if (match === null || !this.isValidPort(match[2])) {
      return false;
    }
    return match[1].split('.').every((part: string) => {
      const octet = Number(part);
      return Number.isInteger(octet) && octet >= 0 && octet <= 255;
    });
  }

  private isValidIpv6Target(value: string): boolean {
    let address = value;
    let port: string | undefined = undefined;
    const bracketed = value.match(/^\[([0-9A-Fa-f:]+)\](?::(\d{1,5}))?$/);
    if (bracketed !== null) {
      address = bracketed[1];
      port = bracketed[2];
    } else if (!value.includes('::') && (value.match(/:/g) ?? []).length < 2) {
      return false;
    }
    if (!this.isValidPort(port) || !address.includes(':') || !/^[0-9A-Fa-f:]+$/.test(address)) {
      return false;
    }
    const segments = address.split(':');
    return segments.length >= 3 && segments.length <= 8 && segments.every((part: string) => part.length <= 4);
  }

  private isValidConnectionTarget(value: string): boolean {
    const normalized = value.trim();
    if (this.isNumericConnectionTarget(normalized)) {
      return normalized.length >= 9;
    }
    return this.isValidIpv4Target(normalized) || this.isValidIpv6Target(normalized);
  }

  private selectLatestChatPeer(peerId: string): void {
    const normalizedPeerId = peerId.trim();
    if (normalizedPeerId.length === 0) {
      return;
    }
    this.chatService.retainOnlyPeer(normalizedPeerId);
    this.lastSessionPeerId = normalizedPeerId;
    this.chatMessages = this.chatService.getMessages(normalizedPeerId);
    this.refreshChatSessions();
  }

  private getSuggestionId(item: RecentSession | AddressBookEntry): string {
    return item.id;
  }

  private getSuggestionName(item: RecentSession | AddressBookEntry): string {
    const rs = item as RecentSession;
    if (rs.name && rs.name.length > 0) {
      return rs.name;
    }
    const ab = item as AddressBookEntry;
    if (ab.alias && ab.alias.length > 0) {
      return ab.alias;
    }
    return '';
  }

  private getSuggestionPlatform(item: RecentSession | AddressBookEntry): string {
    return item.platform ?? '';
  }

  private filterRecentSessions(items: RecentSession[]): RecentSession[] {
    if (!this.searchText || this.searchText.trim() === '') {
      return items;
    }
    const searchLower = this.searchText.toLowerCase().trim();
    return items.filter(item => {
      const idMatch = item.id.toLowerCase().includes(searchLower);
      const nameMatch = item.name ? item.name.toLowerCase().includes(searchLower) : false;
      return idMatch || nameMatch;
    });
  }
  private filterAddressEntries(items: AddressBookEntry[]): AddressBookEntry[] {
    if (!this.searchText || this.searchText.trim() === '') {
      return items;
    }
    const searchLower = this.searchText.toLowerCase().trim();
    return items.filter(item => {
      const idMatch = item.id.toLowerCase().includes(searchLower);
      const aliasMatch = item.alias ? item.alias.toLowerCase().includes(searchLower) : false;
      const noteMatch = item.note ? item.note.toLowerCase().includes(searchLower) : false;
      const groupMatch = item.group ? item.group.toLowerCase().includes(searchLower) : false;
      const platformMatch = item.platform ? item.platform.toLowerCase().includes(searchLower) : false;
      return idMatch || aliasMatch || noteMatch || groupMatch || platformMatch;
    });
  }

  private dismissConnectSearch(clearText: boolean = true): void {
    this.showSearchInput = false;
    if (clearText) {
      this.searchText = '';
    }
  }

  private openConnectSearch(): void {
    this.showSearchInput = true;
    setTimeout(() => {
      try {
        focusControl.requestFocus('connect-search-input');
      } catch (_e) {}
    }, 30);
  }

  private requestConnectTabFocus(delayMs: number = 40, targetId: string = 'recent-tab-btn'): void {
    setTimeout(() => {
      try {
        focusControl.requestFocus(targetId);
      } catch (_e) {}
    }, delayMs);
  }

  private switchHomeTab(tab: HomeTab): void {
    this.currentTab = tab;
    if (tab === 'connect') {
      this.showIdSuggestions = false;
      this.dismissConnectSearch();
      this.requestConnectTabFocus(60, 'connect-bottom-tab-btn');
    }
    if (tab === 'chat' && this.chatMessages.length > 0) {
      this.scheduleChatTabScroll(100);
    }
  }
  private clearStatusMessage(): void {
    this.statusMessageKey = '';
    this.statusMessageTargetId = '';
    this.statusMessage = '';
  }
  private resolveStatusMessage(key: string, targetId: string): string {
    const i18n = I18nService.getInstance();
    switch (key) {
      case 'connecting_saved': return i18n.translate('Connecting');
      case 'connecting': return i18n.translate('Connecting');
      case 'enter_id': return i18n.translate('Enter ID');
      case 'id_incorrect': return i18n.translate('ID incorrect');
      case 'core_not_ready': return i18n.translate('Core Unknown');
      case 'share_requested': return i18n.translate('Core Ready');
      case 'share_stopped': return i18n.translate('Core Stopped');
      case 'server_updated': return i18n.translate('Core Ready');
      case 'detected_saved_password': return i18n.translate('Connecting');
      case 'connection_failed': return i18n.translate('Conn failed');
      case 'connection_request_cancelled': return '';
      case 'password_saved': return i18n.translate('Core Ready');
      case 'password_saved_continue': return i18n.translate('Connecting');
      case 'connection_established': return i18n.translate('Core Ready');
      case 'session_ended': return '';
      case 'connection_still': return i18n.translate('Connecting');
      case 'password_submitted': return i18n.translate('Connecting');
      case 'password_required': return i18n.translate('Pwd required');
      default: return '';
    }
  }
  private refreshStatusMessage(): void {
    if (this.statusMessageKey.length > 0) {
      this.statusMessage = this.resolveStatusMessage(this.statusMessageKey, this.statusMessageTargetId);
    }
  }
  @State isConnecting: boolean = false;
  @State settings: SettingsState = this.appData.getSettings();
  @State draftIdServer: string = '';
  @State draftRelayServer: string = '';
  @State draftApiServer: string = '';
  @State draftKey: string = '';
  @State themeMode: AppThemeMode = ThemeManager.resolveMode(this.appData.getSettings().theme);
  @StorageProp('themeIsDark') themeIsDark: boolean = false;
  @State officialCoreState: OfficialCoreState = this.officialBridge.getCoreState();
  @State coreModules: CoreModuleInfo[] = [];
  @State coreLoadBusy: boolean = false;
  @State coreDownloadUrl: string = '';
  @State coreDownloadBusy: boolean = false;
  @State coreLoadStatus: string = '';
  @State showCoreDetailDialog: boolean = false;
  @State selectedCoreModuleIndex: number = 0;
  @State accountState: AccountState = this.appState.getAccount();
  @State accountRefreshTick: number = 0;
  @State recentSessions: RecentSession[] = this.appData.getRecentSessions();
  @State chatSessions: ChatSession[] = [];
  @State chatMessages: ChatMessage[] = [];
  private chatTabScroller: Scroller = new Scroller();
  @State chatDraft: string = '';
  @State localDevice: LocalDeviceProfile = this.appData.getLocalDevice();
  @State oneTimePassword: string = this.appData.getPassword();
  @State shareUiVersion: number = 0;
  @State showShareStartWarning: boolean = false;
  @State shareWarningDontShowAgain: boolean = false;
  @State shareWarningCountdown: number = 12;
  @State nativeBridgeSummary: string = NativeRustDeskBridge.getRuntimeLogSummary();
  @State showPasswordDialog: boolean = false;
  @State showServerDialog: boolean = false;
  @State showLanguageDialog: boolean = false;
  @State languageDialogOpacity: number = 1;
  @State showAccountDialog: boolean = false;
  @State showThemeDialog: boolean = false;
  @State showDisplaySettingsDialog: boolean = false;
  @State loginUsername: string = '';
  @State loginPassword: string = '';
  @State loginErrorMsg: string = '';
  @State buildTime: string = '';
  @State buildVersion: string = '';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @State i18nOpacity: number = 1;
  @State pendingPassword: string = '';
  @State rememberPassword: boolean = false;
  @State pendingPeerId: string = '';
  private pendingTransportTarget: string = '';
  private pendingPasswordDialogProactive: boolean = false;
  @State swipedRecentTargetId: string = '';
  @State recentMenuSessionId: string = '';
  @State showRenameDialog: boolean = false;
  @State renameTargetId: string = '';
  @State renameDraft: string = '';
  @State showDirectAccessPortDialog: boolean = false;
  @State directAccessIp: string = '';
  @State directAccessPort: string = '21118';
  @State directAccessPortDraft: string = '21118';
  @State showProxyDialog: boolean = false;
  @State showConnectModeMenu: boolean = false;
  @State draftSocks5Proxy: string = '';
  @State draftHttpProxy: string = '';
  private cachedHostname: string = '';
  private autoSubmittedSavedPasswordPeerId: string = '';
  private incomingServiceRestoreBusy: boolean = false;
  private incomingServiceActionBusy: boolean = false;
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('avoidKeyboardHeight') avoidKeyboardHeight: number = 0;

  private formatId(id: string): string {
    return DeviceIdFormatter.format(id);
  }

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    console.info(`[I18N] onI18nVersionChanged: i18nRefresh=${this.i18nRefresh}, showLangDialog=${this.showLanguageDialog}`);
    this.i18nOpacity = 0.6;
    this.i18nVersion = this.i18nRefresh;
    this.currentSort = this.lt('Remote ID');
    this.refreshStatusMessage();
    setTimeout(() => { this.i18nOpacity = 1; }, 30);
  }

  private forceI18nRefresh(): void {
    console.info(`[I18N] forceI18nRefresh: Language=${this.lt('Language')}, RemoteID=${this.lt('Remote ID')}`);
    this.i18nOpacity = 0.6;
    this.refreshStatusMessage();
    setTimeout(() => { this.i18nOpacity = 1; }, 30);
  }

  private parseHostnameFromDetail(detail: string): string {
    const hostname = this.parseFieldFromDetail(detail, 'hostname');
    if (hostname.length > 0) {
      this.cachedHostname = hostname;
    }
    return hostname;
  }

  private parseFieldFromDetail(detail: string, field: string): string {
    try {
      const parts = detail.split(/[;,]/);
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i].trim();
        if (part.startsWith(field + '=')) {
          const value = part.substring((field + '=').length).trim();
          if (value.length > 0) {
            return value;
          }
        }
      }
    } catch (_e) {}
    return '';
  }

  private getResolvedHostname(detail: string): string {
    const fromDetail = this.parseHostnameFromDetail(detail);
    if (fromDetail.length > 0) {
      return fromDetail;
    }
    return this.cachedHostname;
  }

  aboutToAppear() {
    this.officialBridge.removeEventListener(this.bridgeListener);
    this.officialBridge.addEventListener(this.bridgeListener);
    this.officialBridge.removeOnlineStatusListener(this.onlineStatusListener);
    this.officialBridge.addOnlineStatusListener(this.onlineStatusListener);
    LanDiscoveryService.getInstance().removeListener(this.lanDiscoveryListener);
    LanDiscoveryService.getInstance().addListener(this.lanDiscoveryListener);
    this.chatService.removeEventListener(this.chatEventListener);
    this.chatService.addEventListener(this.chatEventListener);
    this.syncDraftServers();
    if (this.settings.enableDirectIp) {
      void this.refreshDirectAccessState();
    }
    this.themeMode = ThemeManager.resolveMode(this.settings.theme);
    void WindowChromeService.getInstance().refreshSystemBars();
    this.syncControlledKeepScreenOn();
    void this.refreshState().then(() => {
      this.refreshCoreDetailInfo();
      void this.ensureIncomingServiceEnabled();
    });
    this.startRefreshLoop();
    this.startOnlineStatusPoll();
    this.buildTime = BuildInfo.BUILD_TIME;
    this.buildVersion = BuildInfo.VERSION;
    this.requestConnectTabFocus(100, 'connect-bottom-tab-btn');
    hilog.info(0xA03D00, 'CONN', 'onPageShow denyLanDiscovery=' + this.settings.denyLanDiscovery);
    if (!this.settings.denyLanDiscovery) {
      LanDiscoveryService.getInstance().startDiscovery();
    }
  }

  aboutToDisappear() {
    this.officialBridge.removeEventListener(this.bridgeListener);
    this.officialBridge.removeOnlineStatusListener(this.onlineStatusListener);
    LanDiscoveryService.getInstance().removeListener(this.lanDiscoveryListener);
    this.chatService.removeEventListener(this.chatEventListener);
    this.stopRefreshLoop();
    this.closeShareStartWarning();
    this.stopOnlineStatusPoll();
    LanDiscoveryService.getInstance().stopDiscovery();
  }

  onPageShow(): void {
    void WindowChromeService.getInstance().refreshSystemBars();
    this.refreshAccountState();
    this.syncControlledKeepScreenOn();
    if (this.accountState.isLoggedIn && this.showAccountDialog) {
      this.showAccountDialog = false;
      this.loginErrorMsg = '';
    }
    void this.refreshState().then(() => {
      if ((this.officialCoreState.sessionStage === 'idle' || this.officialCoreState.sessionStage === 'error') &&
        this.pendingPeerId.trim().length === 0) {
        const finalError = this.officialCoreState.sessionStage === 'error'
          ? (this.officialCoreState.lastError || this.officialCoreState.detailMessage)
          : '';
        this.resetConnectionUiAfterTerminalEvent(finalError);
      }
      this.refreshCurrentSessionChat(true);
    });
    if (this.currentTab === 'connect') {
      this.requestConnectTabFocus(100, 'connect-bottom-tab-btn');
    }
  }
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_SURFACE') theme_ACCENT_SURFACE: string = '#1A2742';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_SECONDARY_BTN_BG') theme_SECONDARY_BTN_BG: string = '#232835';
  @StorageProp('theme_SECONDARY_BTN_TEXT') theme_SECONDARY_BTN_TEXT: string = '#E2E8F0';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CARET_HIDDEN') theme_CARET_HIDDEN: string = '#00000000';
  @StorageProp('theme_DIALOG_OVERLAY') theme_DIALOG_OVERLAY: string = '#80000000';
  @StorageProp('theme_ERROR_BG') theme_ERROR_BG: string = '#3B1D24';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_HEADER_BG') theme_HEADER_BG: string = '#171A22';
  @StorageProp('theme_ID_COLOR') theme_ID_COLOR: string = '#00B6F0';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_SHADOW_COLOR') theme_SHADOW_COLOR: string = '#00000033';
  @StorageProp('theme_SUCCESS_TEXT') theme_SUCCESS_TEXT: string = '#7DD3A7';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('theme_WARNING_TEXT') theme_WARNING_TEXT: string = '#F59E0B';
  @StorageProp('theme_WHITE') theme_WHITE: string = '#FFFFFF';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#FFFFFF';

  @Builder
  private buildConnectPage() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column() {
          this.buildConnectPeerTabContent()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_SM, bottom: 0 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .padding({ top: 200, bottom: 120 })
      .id('connect-tab-list')

      Column() {
        Column() { PageHeader(this.lt('RustDesk')) }
          .width('100%')
          .padding({ top: this.avoidStatusBarHeight })

        this.buildOfficialConnectPanel()
      }
      .width('100%')
      .linearGradient({
        angle: 180,
        colors: this.themeIsDark 
          ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ['#99171A1E', 0.12], ['#88171A1E', 0.22], ['#77171A1E', 0.35], ['#66171A1E', 0.52], ['#55171A1E', 0.72], ['#33171A1E', 0.88], ['#00171A1E', 1.0]]
          : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ['#A0F0F4FA', 0.12], ['#90F0F4FA', 0.22], ['#80F0F4FA', 0.35], ['#70F0F4FA', 0.52], ['#50F0F4FA', 0.72], ['#30F0F4FA', 0.88], ['#00F0F4FA', 1.0]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
  }

  @Builder
  private buildChatOverview() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Scroll(this.chatTabScroller) {
          Column({ space: ThemeConfig.SPACING_SM }) {
            if (!this.hasHadSession) {
              Column() {
                Text(this.lt('No active connection'))
                  .fontSize(ThemeConfig.FONT_SIZE_MD)
                  .fontColor(this.theme_TEXT_TERTIARY)
              }
              .width('100%')
              .height(200)
              .justifyContent(FlexAlign.Center)
            } else if (this.chatMessages.length === 0) {
              Column() {
                Text(this.lt('No messages yet.'))
                  .fontSize(ThemeConfig.FONT_SIZE_MD)
                  .fontColor(this.theme_TEXT_TERTIARY)
              }
              .width('100%')
              .height(200)
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.chatMessages, (message: ChatMessage, index?: number) => {
                Column({ space: 4 }) {
                  if (ChatService.shouldShowTimestamp(this.chatMessages, index ?? 0)) {
                    Text(ChatService.formatTimestamp(message.timestamp))
                      .fontSize(10)
                      .fontColor(this.theme_TEXT_TERTIARY)
                      .width('100%')
                      .textAlign(TextAlign.Center)
                      .padding({ top: 2, bottom: 2 })
                  }
                  Row() {
                    if (message.sender === 'remote') {
                      this.buildChatMessageBubble(message, false)
                      Blank().layoutWeight(1)
                    } else {
                      Blank().layoutWeight(1)
                      this.buildChatMessageBubble(message, true)
                    }
                  }
                  .width('100%')
                }
                .width('100%')
              }, (message: ChatMessage) => message.id)
            }
          }
          .width('100%')
          .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_MD, bottom: 0 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .padding({ top: 80, bottom: 120 })
      }
      .width('100%')
      .height('100%')

      Column() {
        Column() {
          if (this.hasHadSession && this.lastSessionPeerId.length > 0 && this.chatMessages.length > 0) {
            Row() {
              Image($rawfile('call-made.svg'))
                .width(22)
                .height(22)
                .fillColor(this.theme_TEXT_PRIMARY)

              Column({ space: 2 }) {
                Text(this.resolveChatPeerName())
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme_TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.formatId(this.lastSessionPeerId))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_TERTIARY)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })

              Row() {
                Image($rawfile('group.svg'))
                  .width(22)
                  .height(22)
                  .fillColor(this.theme_ACCENT)
              }
              .width(40)
              .height(40)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .backgroundColor(this.theme_ACCENT_SURFACE)
              .borderRadius(20)
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Center)
          } else {
            PageHeader(this.lt('RustDesk'))
          }
        }
          .width('100%')
          .padding({ top: this.avoidStatusBarHeight })
      }
      .width('100%')
      .linearGradient({
        angle: 180,
        colors: this.themeIsDark 
          ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ['#99171A1E', 0.12], ['#88171A1E', 0.22], ['#77171A1E', 0.35], ['#66171A1E', 0.52], ['#55171A1E', 0.72], ['#33171A1E', 0.88], ['#00171A1E', 1.0]]
          : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ['#A0F0F4FA', 0.12], ['#90F0F4FA', 0.22], ['#80F0F4FA', 0.35], ['#70F0F4FA', 0.52], ['#50F0F4FA', 0.72], ['#30F0F4FA', 0.88], ['#00F0F4FA', 1.0]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
  }

  @Builder
  private buildShareOverview() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: ThemeConfig.SPACING_LG }) {
          this.buildShareServiceCard()
          this.buildCapabilityCard()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_MD, bottom: 0 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .padding({ top: 80, bottom: 120 })

      Column() {
        Column() { PageHeader(this.lt('RustDesk')) }
          .width('100%')
          .padding({ top: this.avoidStatusBarHeight })
      }
      .width('100%')
      .linearGradient({
        angle: 180,
        colors: this.themeIsDark 
          ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ['#99171A1E', 0.12], ['#88171A1E', 0.22], ['#77171A1E', 0.35], ['#66171A1E', 0.52], ['#55171A1E', 0.72], ['#33171A1E', 0.88], ['#00171A1E', 1.0]]
          : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ['#A0F0F4FA', 0.12], ['#90F0F4FA', 0.22], ['#80F0F4FA', 0.35], ['#70F0F4FA', 0.52], ['#50F0F4FA', 0.72], ['#30F0F4FA', 0.88], ['#00F0F4FA', 1.0]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
  }

  @Builder
  private buildSettingsOverview() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: ThemeConfig.SPACING_LG }) {
          this.buildSettingsAccountSection()
          this.buildSettingsServerSection()
          this.buildSettingsHardwareSection()
          this.buildSettingsRecordingSection()
          this.buildSettingsTwoFactorSection()
          this.buildSettingsShareScreenSection()
          this.buildSettingsDisplaySection()
          this.buildSettingsEnhancedSection()
          this.buildSettingsAboutSection()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_MD, bottom: 0 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .padding({ top: 80, bottom: 120 })

      Column() {
        Column() { this.buildSettingsPageHeader() }
          .width('100%')
          .padding({ top: this.avoidStatusBarHeight })
      }
      .width('100%')
      .linearGradient({
        angle: 180,
        colors: this.themeIsDark 
          ? [['#BB171A1E', 0.0], ['#AA171A1E', 0.05], ['#99171A1E', 0.12], ['#88171A1E', 0.22], ['#77171A1E', 0.35], ['#66171A1E', 0.52], ['#55171A1E', 0.72], ['#33171A1E', 0.88], ['#00171A1E', 1.0]]
          : [['#C0F0F4FA', 0.0], ['#B0F0F4FA', 0.05], ['#A0F0F4FA', 0.12], ['#90F0F4FA', 0.22], ['#80F0F4FA', 0.35], ['#70F0F4FA', 0.52], ['#50F0F4FA', 0.72], ['#30F0F4FA', 0.88], ['#00F0F4FA', 1.0]]
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
  }

  @Builder
  private buildOfficialConnectPanel() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Stack({ alignContent: Alignment.End }) {
          Column() {
            if (this.deviceId.length > 0) {
              Row({ space: 8 }) {
                Text(this.lt('Remote ID'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_TERTIARY)

                if (this.statusMessage.trim().length > 0) {
                  Text(this.statusMessage)
                    .fontSize(12)
                    .fontColor(this.theme_TEXT_TERTIARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                }
              }
              .width('100%')
              .margin({ top: 8 })
            }

            TextInput({ placeholder: this.lt('Remote ID'), text: this.deviceIdDisplay, controller: this.deviceIdInputController })
              .width('100%')
              .layoutWeight(1)
              .type(InputType.Normal)
              .fontSize(ThemeConfig.FONT_SIZE_ID)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme_ID_COLOR)
              .placeholderColor(this.theme_TEXT_TERTIARY)
              .backgroundColor(Color.Transparent)
              .borderWidth(0)
              .padding({ left: 0, right: 0, bottom: 8 })
              .onChange((value: string) => {
                const raw = this.sanitizeConnectionTargetInput(value);
                if (this.pendingDeviceIdSelection.length > 0 && raw !== this.pendingDeviceIdSelection) {
                  this.deviceId = this.pendingDeviceIdSelection;
                  this.deviceIdDisplay = this.formatId(this.pendingDeviceIdSelection);
                  this.showIdSuggestions = false;
                  this.restoreDeviceIdCaret(this.deviceIdDisplay.length);
                  return;
                }
                if (this.pendingDeviceIdSelection.length > 0 && raw === this.pendingDeviceIdSelection) {
                  this.pendingDeviceIdSelection = '';
                  this.deviceId = raw;
                  this.deviceIdDisplay = this.formatId(raw);
                  this.showIdSuggestions = false;
                  this.restoreDeviceIdCaret(this.deviceIdDisplay.length);
                  return;
                }
                const numericTarget = raw.length === 0 || this.isNumericConnectionTarget(raw);
                const rawCaret = this.resolveRawCaretAfterEdit(this.deviceIdDisplay, value, this.deviceIdSelectionEnd);
                const formattedValue = numericTarget ? this.formatId(raw) : raw;
                this.deviceId = raw;
                this.deviceIdDisplay = formattedValue;
                this.showIdSuggestions = this.deviceIdInputFocused && raw.length >= 3;
                this.restoreDeviceIdCaret(this.mapConnectionTargetCaret(formattedValue, rawCaret));
              })
              .onTextSelectionChange((_selectionStart: number, selectionEnd: number) => {
                this.deviceIdSelectionEnd = selectionEnd;
              })
              .onFocus(() => {
                this.deviceIdInputFocused = true;
                if (this.deviceId.trim().length >= 3) {
                  this.showIdSuggestions = true;
                }
              })
              .onBlur(() => {
                this.deviceIdInputFocused = false;
                setTimeout(() => {
                  if (!this.deviceIdInputFocused) {
                    this.showIdSuggestions = false;
                  }
                }, 600);
              })
              .key(this.deviceIdInputKey.toString())
              .id('deviceIdInput')
          }
          .width('100%')
          .height(64)
          .padding({ left: ThemeConfig.SPACING_LG, right: 60 })
          .alignItems(HorizontalAlign.Start)
          .border({ width: 1, color: this.theme_BORDER_SUBTLE })
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)

          Row({ space: 8 }) {
            if (this.deviceId.length > 0) {
              Image($rawfile('close.svg'))
                .width(20)
                .height(20)
                .fillColor(this.theme_TEXT_TERTIARY)
                .hitTestBehavior(HitTestMode.Block)
                .onClick(() => {
                  this.showIdSuggestions = false;
                  this.deviceId = '';
                  this.deviceIdDisplay = '';
                  this.deviceIdInputKey++;
                  this.deviceIdSelectionEnd = 0;
                  this.clearStatusMessage();
                })
            }

            Image($rawfile('arrow_input.svg'))
              .width(30)
              .height(30)
              .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
              .hitTestBehavior(HitTestMode.Block)
              .onClick(() => {
                this.showIdSuggestions = false;
                void this.handleConnect();
              })
          }
          .height(64)
          .padding({ right: ThemeConfig.SPACING_LG })
          .alignItems(VerticalAlign.Center)
          .zIndex(40)
        }
        .width('100%')
        .zIndex(30)

        Row() {
          if (this.visibleConnectTabs.has('recent')) {
            this.buildConnectPeerTabButton('recent')
          }
          if (this.visibleConnectTabs.has('favorites')) {
            this.buildConnectPeerTabButton('favorites')
          }
          if (this.visibleConnectTabs.has('discovered')) {
            this.buildConnectPeerTabButton('discovered')
          }
          if (this.visibleConnectTabs.has('addressBook')) {
            this.buildConnectPeerTabButton('addressBook')
          }
          if (this.visibleConnectTabs.has('account')) {
            this.buildConnectPeerTabButton('account')
          }
          if (this.visibleConnectTabs.has('core')) {
            this.buildConnectPeerTabButton('core')
          }

          Blank().layoutWeight(1)

          Row({ space: 8 }) {
            this.buildConnectSearchAnchor()

            if (this.currentConnectTab === 'recent') {
              Image($rawfile('checkbox-outline.svg'))
                .width(18)
                .height(18)
                .fillColor(this.theme_TEXT_TERTIARY)
            }

            if (this.currentConnectTab !== 'account' && (this.currentConnectTab === 'favorites' || this.currentConnectTab === 'discovered' || this.currentConnectTab === 'addressBook')) {
              Image($rawfile('Sorting_order.svg'))
                .width(18)
                .height(18)
                .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
                .onClick(() => {
                  this.dismissConnectSearch();
                  this.showSortMenu = true;
                })
            }

            if (this.currentConnectTab === 'discovered' || this.currentConnectTab === 'addressBook') {
              Image($rawfile('refresh.svg'))
                .width(18)
                .height(18)
                .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
                .rotate({ x: 0, y: 0, z: 1, angle: this.connectTabRefreshAngle })
                .onClick(() => {
                  if (this.isConnectTabRefreshing) {
                    return;
                  }
                  this.dismissConnectSearch();
                  void this.refreshCurrentConnectTab();
                })
            }
          }
        }
        .width('100%')
        .height(42)
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 0, right: ThemeConfig.SPACING_MD })
      }
      .width('100%')
      .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_SM, bottom: ThemeConfig.SPACING_SM })

      this.buildIdSuggestions()
    }
    .width('100%')
    .clip(false)
  }

  @Builder
  private buildConnectSearchAnchor() {
    Stack({ alignContent: Alignment.Center }) {
      Image($rawfile('search.svg'))
        .width(18)
        .height(18)
        .fillColor(this.showSearchInput ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
        .onClick(() => {
          if (this.showSearchInput) {
            this.dismissConnectSearch();
          } else if (this.searchText.trim().length > 0) {
            this.searchText = '';
          } else {
            this.openConnectSearch();
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
          .border({ width: 1, color: this.theme_BORDER_SUBTLE })
          .borderRadius(8)
          .padding({ left: 10, right: 10 })
          .id('connect-search-input')
          .zIndex(10)
          .position({ x: -122, y: 5 })
          .onChange((value: string) => {
            this.searchText = value;
          })
          .onSubmit(() => {
            this.dismissConnectSearch(false);
          })
           .onBlur(() => {
             this.showSearchInput = false;
           })
      }
    }
    .width(18)
    .height(42)
    .clip(false)
  }

  @Builder
  private buildIdSuggestions() {
    if (this.showIdSuggestions && this.deviceId.trim().length >= 3) {
      Column({ space: 0 }) {
        ForEach(this.getIdSuggestions(), (item: RecentSession | AddressBookEntry) => {
          Row({ space: ThemeConfig.SPACING_MD }) {
            Row() {
              this.buildThemedPlatformIcon(this.getSuggestionPlatform(item), 20)
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme_ACCENT_SURFACE)
            .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)

            Column({ space: 2 }) {
              Text(this.getSuggestionName(item))
                .fontSize(13)
                .fontColor(this.theme_TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.formatId(this.getSuggestionId(item)))
                .fontSize(11)
                .fontColor(this.theme_TEXT_TERTIARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .id(`id-suggestion-${this.getSuggestionId(item)}`)
          .hitTestBehavior(HitTestMode.Block)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.selectDeviceIdInputTarget(this.getSuggestionId(item));
            }
          })
          .onClick(() => {
            const id = this.getSuggestionId(item);
            this.selectDeviceIdInputTarget(id);
          })
        }, (item: RecentSession | AddressBookEntry, index?: number) => `${this.getSuggestionId(item)}-${index ?? 0}`)
      }
      .width('calc(100% - 116vp)')
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .shadow({ radius: 8, color: '#20000000', offsetY: 2 })
      .position({
        x: ThemeConfig.SPACING_MD + ThemeConfig.SPACING_LG,
        y: ThemeConfig.SPACING_SM + 68
      })
      .zIndex(35)
      .hitTestBehavior(HitTestMode.Default)
    }
  }

  @Builder
  private buildOfficialLoginEntry() {
    Column({ space: ThemeConfig.SPACING_MD }) {
      Button(this.lt('Login'))
        .width(156)
        .height(ThemeConfig.BUTTON_HEIGHT_ENTRY)
        .fontSize(ThemeConfig.FONT_SIZE_HUGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme_ACCENT_TEXT)
        .backgroundColor(this.theme_ACCENT)
        .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
        .onClick(() => {
          this.showAccountDialog = true;
        })

      Text(this.lt('Login required for public server'))
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(this.theme_TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: ThemeConfig.SPACING_XXL, bottom: ThemeConfig.SPACING_MD })
  }

  private requireLoginForAddressBook(): boolean {
    if (this.accountState.isLoggedIn) {
      return true;
    }
    this.loginErrorMsg = this.lt('Login required for public server');
    this.showAccountDialog = true;
    return false;
  }

  private getScreenRecordingDirectory(): string {
    try {
      const context = AppContextService.getContext();
      if (context && typeof context.filesDir === 'string' && context.filesDir.trim().length > 0) {
        return context.filesDir.trim() + '/ScreenRecord';
      }
    } catch (_error) {
    }
    return '/data/storage/el2/base/files/ScreenRecord';
  }

  @Builder
  private buildConnectPeerTabContent() {
    if (!this.accountState.isLoggedIn && this.currentConnectTab === 'addressBook') {
      Column({ space: ThemeConfig.SPACING_MD }) {
        Text(this.lt('Login to view address book'))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)

        Button(this.lt('Login'))
          .width(156)
          .height(ThemeConfig.BUTTON_HEIGHT_MEDIUM)
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT)
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
          .onClick(() => {
            this.showAccountDialog = true;
          })
      }
      .width('100%')
      .padding({ top: ThemeConfig.SPACING_XXL, bottom: ThemeConfig.SPACING_MD })
      .justifyContent(FlexAlign.Center)
    } else {
      if (this.currentConnectTab === 'recent') {
        ForEach([this.addressBookVersion], (_v: number) => {
          this.buildRecentSessionsCard()
        }, (_v: number, _i: number) => `${_v}`)
      } else if (this.currentConnectTab === 'favorites') {
        ForEach([this.addressBookVersion], (_v: number) => {
          this.buildConnectAddressCollectionCard(this.lt('Favorites'), this.filterAddressEntries(this.appData.getFavorites()), this.lt('No favorites yet. Add frequent targets to favorites to see them here.'))
        }, (_v: number, _i: number) => `${_v}`)
      } else if (this.currentConnectTab === 'discovered') {
        ForEach([this.discoveredVersion], (_v: number) => {
          this.buildConnectAddressCollectionCard(this.lt('Discover Devices'), this.filterAddressEntries(this.appData.getDiscoveredDevices()), this.lt('No discovered devices online.'))
        }, (_v: number, _i: number) => `${_v}`)
      } else if (this.currentConnectTab === 'addressBook') {
        ForEach([this.addressBookVersion], (_v: number) => {
          this.buildConnectAddressCollectionCard(this.lt('Address book'), this.filterAddressEntries(this.appData.getAddressBook()), this.lt('Address book is empty. Added devices will be displayed here.'))
        }, (_v: number, _i: number) => `${_v}`)
      } else if (this.currentConnectTab === 'account') {
        this.buildConnectAccountCard()
      } else {
        this.buildConnectCoreDeck()
      }
    }
  }

  @Builder
  private buildConnectCoreDeck() {
    Column({ space: ThemeConfig.SPACING_LG }) {
      this.buildCoreBridgeCard()
      this.buildCoreServiceCard()
      this.buildCoreSessionCard()
      this.buildCoreDebugCard()
    }
    .width('100%')
    .constraintSize({ minHeight: 200 })
  }

  @Builder
  private buildConnectAccountCard() {
    if (!this.accountState.isLoggedIn) {
      Column({ space: ThemeConfig.SPACING_MD }) {
        Text(this.lt('Login to view account'))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .textAlign(TextAlign.Center)

        Button(this.lt('Login'))
          .width(156)
          .height(ThemeConfig.BUTTON_HEIGHT_MEDIUM)
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT)
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
          .onClick(() => {
            this.showAccountDialog = true;
          })
      }
      .width('100%')
      .padding({ top: ThemeConfig.SPACING_XXL, bottom: ThemeConfig.SPACING_MD })
      .justifyContent(FlexAlign.Center)
    } else {
      Column({ space: ThemeConfig.SPACING_SM }) {
        Row() {
          SectionTitle(this.lt('Account'))
          Blank().layoutWeight(1)
          StatusBadge(this.lt('Logged in'), true)
        }
        .width('100%')

        InfoRow(this.lt('Account'), this.describeAccountName(), 'settings_person.svg')
        InfoRow(this.lt('Provider'), this.describeAccountProvider(), 'settings_server.svg')
        InfoRow(this.lt('Status'), this.describeAccountState(), 'settings_record.svg')

        CaptionLabel((this.accountState.detail ?? '').trim().length > 0 ? (this.accountState.detail ?? '') : this.lt('Account synced, can continue outgoing.'))

        Button(this.lt('Sign out'))
          .width(156)
          .height(ThemeConfig.BUTTON_HEIGHT_MEDIUM)
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .backgroundColor(this.theme_INPUT_BG)
          .fontColor(this.theme_TEXT_PRIMARY)
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
          .border({ width: 1, color: this.theme_BORDER_SUBTLE })
          .onClick(() => {
            this.signOutAccount();
          })
      }
      .width('100%')
      .padding(ThemeConfig.SPACING_XL)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
    }
  }

  @Builder
  private buildConnectAddressCollectionCard(title: string, entries: AddressBookEntry[], emptyMessage: string) {
    if (entries.length === 0) {
      EmptyState($rawfile('display.svg'), emptyMessage)
    } else {
      Column({ space: ThemeConfig.SPACING_SM }) {
        ForEach(entries, (entry: AddressBookEntry) => {
          this.buildConnectAddressEntryRow(entry)
        }, (entry: AddressBookEntry) => `${entry.id}-${entry.group}-${entry.favorite ? 'fav' : 'plain'}`)
      }
      .width('100%')
    }
  }

  @Builder
  private buildConnectAddressEntryRow(entry: AddressBookEntry) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      Row() {
        this.buildThemedPlatformIcon(entry.platform, 26)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme_ACCENT_SURFACE)
      .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Circle()
            .width(8)
            .height(8)
            .fill((() => { this.peerOnlineVersion; return this.appData.isPeerOnline(entry.id); })() ? this.theme_SUCCESS_TEXT : this.theme_WARNING_TEXT)

          Text(this.formatId(entry.id))
            .fontSize(ThemeConfig.FONT_SIZE_XL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme_TEXT_PRIMARY)
        }

        Text(this.resolveConnectEntryName(entry))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Image($rawfile('dots_vertical.svg'))
          .width(20)
          .height(20)
          .fillColor(this.theme_TEXT_TERTIARY)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.recentMenuSessionId = entry.id;
      })
    }
    .width('100%')
    .padding(ThemeConfig.SPACING_LG)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .border({ width: 1, color: this.theme_BORDER_SUBTLE })
    .onClick(() => {
      this.selectDeviceIdInputTarget(entry.id);
      void this.handleConnect(entry.id);
    })
  }

  @Builder
  private buildSettingsAccountSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Account'), 'settings_person.svg')
      CardContainer() {
        Row({ space: ThemeConfig.SPACING_MD }) {
          Image($rawfile(this.resolveAuthProviderIcon()))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_TERTIARY)

          if (this.accountState.isLoggedIn) {
            Text(this.lt('Account Name'))
              .fontSize(ThemeConfig.FONT_SIZE_SM)
              .fontColor(this.theme_TEXT_SECONDARY)
          }

          Text(this.accountState.isLoggedIn ? this.accountState.username : this.lt('Login'))
            .fontSize(ThemeConfig.FONT_SIZE_XL)
            .fontColor(this.accountState.isLoggedIn ? this.theme_TEXT_PRIMARY : this.theme_TEXT_SECONDARY)
            .layoutWeight(1)

          if (this.accountState.isLoggedIn) {
            Row() {
              Image($rawfile('logout.svg'))
                .width(20)
                .height(20)
                .fillColor(this.theme_TEXT_TERTIARY)
            }
            .width(36)
            .height(36)
            .justifyContent(FlexAlign.Center)
            .borderRadius(18)
            .onClick(() => {
              void this.accountService.logout().then(() => {
                this.refreshAccountState();
              });
            })
          }
        }
        .width('100%')
        .height(ThemeConfig.MENU_ITEM_HEIGHT)
        .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
        .onClick(() => {
          if (!this.accountState.isLoggedIn) {
            this.showAccountDialog = true;
          }
        })
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsServerSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Settings'), 'settings_server.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsLinkRow(this.lt('ID / Relay Server'), this.describeServerSummary(), () => {
            this.syncDraftServers();
            this.showServerDialog = true;
          }, '', false, 'settings_server.svg')

          this.buildSettingsLinkRow(this.lt('Socks5/Http(s) Proxy'), this.settings.socks5Proxy || this.settings.httpProxy ? this.lt('Configured') : this.lt('Not configured'), () => {
            this.draftSocks5Proxy = this.settings.socks5Proxy;
            this.draftHttpProxy = this.settings.httpProxy;
            this.showProxyDialog = true;
          }, '', true, 'settings_proxy.svg')
          this.buildSettingsToggleSettingRow(this.lt('Use WebSocket'), this.settings.allowWebSocket, (value: boolean) => {
            this.updateSettings({ allowWebSocket: value });
          }, '', true, 'settings_websocket.svg')
          this.buildSettingsToggleSettingRow(this.lt('Enable UDP Hole Punching'), this.settings.enableUdpHolePunching, (value: boolean) => {
            this.updateSettings({ enableUdpHolePunching: value });
          }, '', true, 'settings_udp.svg')
          this.buildSettingsToggleSettingRow(this.lt('Enable IPv6 P2P Connection'), this.settings.enableIpv6P2p, (value: boolean) => {
            this.updateSettings({ enableIpv6P2p: value });
          }, '', true, 'settings_ipv6.svg')

          Row({ space: ThemeConfig.SPACING_MD }) {
            Image($rawfile('translate.svg'))
              .width(20)
              .height(20)
              .fillColor(this.theme_TEXT_TERTIARY)

            Column({ space: 4 }) {
              Text(this.lt('Language'))
                .fontSize(ThemeConfig.FONT_SIZE_XL)
                .fontColor(this.theme_TEXT_PRIMARY)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.describeCurrentLanguage())
              .fontSize(ThemeConfig.FONT_SIZE_SM)
              .fontColor(this.theme_TEXT_SECONDARY)
              .textAlign(TextAlign.End)

            Image($rawfile('arrow-forward-ios.svg'))
              .width(16)
              .height(16)
              .fillColor(this.theme_TEXT_TERTIARY)
          }
          .width('100%')
          .height(ThemeConfig.MENU_ITEM_HEIGHT)
          .constraintSize({ minHeight: ThemeConfig.MENU_ITEM_HEIGHT })
          .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
          .onClick(() => {
            this.showLanguageDialog = true;
          })

          Row({ space: ThemeConfig.SPACING_MD }) {
            Image($rawfile(this.themeIsDark ? 'dark_mode.svg' : 'light_mode.svg'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .fillColor(this.theme_TEXT_TERTIARY)

            Column({ space: 4 }) {
              Text(this.themeIsDark ? this.lt('Dark Theme') : this.lt('Light Theme'))
                .fontSize(ThemeConfig.FONT_SIZE_XL)
                .fontColor(this.theme_TEXT_PRIMARY)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(this.themeMode === 'system' ? this.lt('Follow System') : (this.themeMode === 'dark' ? this.lt('Dark') : this.lt('Light')))
              .fontSize(ThemeConfig.FONT_SIZE_SM)
              .fontColor(this.theme_TEXT_SECONDARY)
              .textAlign(TextAlign.End)

            Image($rawfile('arrow-forward-ios.svg'))
              .width(16)
              .height(16)
              .fillColor(this.theme_TEXT_TERTIARY)
          }
          .width('100%')
          .height(ThemeConfig.MENU_ITEM_HEIGHT)
          .constraintSize({ minHeight: ThemeConfig.MENU_ITEM_HEIGHT })
          .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
          .onClick(() => {
            this.showThemeDialog = true;
          })

          this.buildSettingsToggleSettingRow(this.lt('Request remark at session end'), this.settings.requestRemarkOnSessionEnd, (value: boolean) => {
            this.updateSettings({ requestRemarkOnSessionEnd: value });
          }, '', true, 'settings_remark.svg')
          this.buildSettingsToggleSettingRow(this.lt('Keep screen on during outgoing sessions'), this.settings.keepScreenOn !== 'never', (value: boolean) => {
            this.updateSettings({ keepScreenOn: value ? 'session' : 'never' });
          }, '', true, 'settings_keepscreen.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsDisplaySection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Display Settings'), 'dvr.svg')
      CardContainer() {
        Column({ space: 0 }) {
          Row({ space: ThemeConfig.SPACING_MD }) {
            Image($rawfile('display.svg'))
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
              .fillColor(this.theme_TEXT_TERTIARY)

            Text(this.lt('Display Settings'))
              .fontSize(ThemeConfig.FONT_SIZE_XL)
              .fontColor(this.theme_TEXT_PRIMARY)
              .layoutWeight(1)

            Image($rawfile('arrow-forward-ios.svg'))
              .width(16)
              .height(16)
              .fillColor(this.theme_TEXT_TERTIARY)
          }
          .width('100%')
          .height(ThemeConfig.MENU_ITEM_HEIGHT)
          .constraintSize({ minHeight: ThemeConfig.MENU_ITEM_HEIGHT })
           .onClick(() => {
             this.settingsOptionVersion++;
             this.showDisplaySettingsDialog = true;
           })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsHardwareSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Hardware Codec'), 'settings_cpu.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Enable hardware codec'), this.settings.enableHardwareCodec, (value: boolean) => {
            this.updateSettings({ enableHardwareCodec: value });
          }, '', false, 'settings_cpu.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsRecordingSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Screen Recording'), 'settings_video.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Auto-record incoming'), this.settings.autoRecordIncoming, (value: boolean) => {
            this.updateSettings({ autoRecordIncoming: value });
          }, '', false, 'settings_record_in.svg')
          this.buildSettingsToggleSettingRow(this.lt('Auto-record outgoing'), this.settings.autoRecordOutgoing, (value: boolean) => {
            this.updateSettings({ autoRecordOutgoing: value });
          }, '', true, 'settings_record_out.svg')
          this.buildSettingsInfoSettingRow(this.lt('Directory'), this.getScreenRecordingDirectory(), 'settings_folder.svg', '', true)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsTwoFactorSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Two Factor Auth'), 'settings_shield.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Enable Two Factor'), this.settings.twoFactorEnabled, (value: boolean) => {
            this.updateSettings({ twoFactorEnabled: value });
          }, '', false, 'settings_shield.svg')
          this.buildSettingsToggleSettingRow(this.lt('Only Whitelist IP Access'), this.settings.onlyWhitelistIpAccess, (value: boolean) => {
            this.updateSettings({ onlyWhitelistIpAccess: value });
          }, '', true, 'settings_whitelist.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsShareScreenSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Share Screen'), 'settings_display.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Allow Recording Sessions'), this.settings.allowRecordingSessions, (value: boolean) => {
            this.updateSettings({ allowRecordingSessions: value });
          }, '', false, 'settings_record.svg')
          this.buildSettingsToggleSettingRow(this.lt('Auto Close Inactive Sessions'), this.settings.autoCloseInactiveSessions, (value: boolean) => {
            this.updateSettings({ autoCloseInactiveSessions: value });
          }, '', true, 'settings_power.svg')
          this.buildSettingsToggleSettingRow(this.lt('Keep Screen On When Controlled'), this.settings.keepScreenOnWhenControlled, (value: boolean) => {
            this.updateSettings({ keepScreenOnWhenControlled: value });
          }, '', true, 'settings_keepscreen.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsEnhancedSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Enhanced'), 'settings_tune.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Enable Adaptive Bitrate'), this.settings.enableAdaptiveBitrate, (value: boolean) => {
            this.updateSettings({ enableAdaptiveBitrate: value });
          }, '', false, 'settings_gauge.svg')
          this.buildDirectIpSettingRow()
          this.buildSettingsToggleSettingRow(this.lt('Deny LAN Discovery'), this.settings.denyLanDiscovery, (value: boolean) => {
            this.updateSettings({ denyLanDiscovery: value });
          }, '', true, 'settings_wifi_off.svg')
          this.buildSettingsToggleSettingRow(this.lt('Start On Boot'), this.settings.startOnBoot, (value: boolean) => {
            this.updateSettings({ startOnBoot: value });
          }, '', true, 'settings_power.svg')
          this.buildSettingsToggleSettingRow(this.lt('Show Terminal Extra Keys'), this.settings.showTerminalExtraKeys, (value: boolean) => {
            this.updateSettings({ showTerminalExtraKeys: value });
          }, '', true, 'settings_terminal.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildSettingsAboutSection() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('About'), 'settings_info.svg')
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsToggleSettingRow(this.lt('Check Updates On Startup'), this.settings.checkUpdatesOnStartup, (value: boolean) => {
            this.updateSettings({ checkUpdatesOnStartup: value });
          }, '', false, 'settings_update.svg', true)
          this.buildSettingsToggleSettingRow(this.lt('Debug Keep Screen Awake'), this.settings.debugKeepScreenAwake, (value: boolean) => {
            this.updateSettings({ debugKeepScreenAwake: value });
          }, '', true, 'settings_keepscreen.svg', false)
          this.buildSettingsInfoSettingRow(this.lt('Version'), `v${this.buildVersion}`, 'settings_info_circle.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Build Time'), this.buildTime, 'settings_timer.svg', '', true)
          Row({ space: ThemeConfig.SPACING_MD }) {
            Image($rawfile('fingerprint.svg'))
              .width(20)
              .height(20)
              .fillColor(this.theme_TEXT_TERTIARY)

            Text(this.lt('Fingerprint'))
              .fontSize(ThemeConfig.FONT_SIZE_XL)
              .fontColor(this.theme_TEXT_PRIMARY)
              .layoutWeight(1)

            Text(this.localDevice.fingerprint.length > 0 ? this.localDevice.fingerprint.substring(0, 12) + '...' : this.lt('None'))
              .fontSize(ThemeConfig.FONT_SIZE_SM)
              .fontColor(this.theme_TEXT_SECONDARY)
              .textAlign(TextAlign.End)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height(ThemeConfig.MENU_ITEM_HEIGHT)
          .constraintSize({ minHeight: ThemeConfig.MENU_ITEM_HEIGHT })
          .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
          .onClick(() => {
            if (this.localDevice.fingerprint.length > 0) {
              void this.copyText(this.localDevice.fingerprint, this.lt('Fingerprint copied'));
            }
          })
          this.buildSettingsLinkRow(this.lt('Privacy Policy'), 'rustdesk.com', () => {
            try {
              void this.getUIContext().getRouter().pushUrl({ url: 'https://rustdesk.com/privacy' });
            } catch (_e) {
              void this.copyText('https://rustdesk.com/privacy', this.lt('Privacy link copied'));
            }
          }, '', true, 'settings_privacy.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  private createStrokeIconColorFilter(color: string): drawing.ColorFilter {
    return drawing.ColorFilter.createBlendModeColorFilter(this.toArgbColor(color), drawing.BlendMode.SRC_IN);
  }

  private toArgbColor(color: string): number {
    const normalized = color.trim().startsWith('#') ? color.trim().substring(1) : color.trim();
    if (normalized.length === 8) {
      return parseInt(normalized, 16);
    }
    return 0xFF000000 + parseInt(normalized, 16);
  }

  @Builder
  private buildCoreBridgeCard() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Core'))
      CardContainer() {
        Column({ space: 0 }) {
          ForEach(this.coreModules.length > 0 ? this.coreModules : [null as CoreModuleInfo | null], (modItem: CoreModuleInfo | null, index: number) => {
            Row({ space: ThemeConfig.SPACING_MD }) {
              if (modItem !== null && modItem.icon.length > 0) {
                Image($rawfile(modItem.icon))
                  .width(20)
                  .height(20)
                  .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
              } else if (modItem === null) {
                Image($rawfile('settings_cpu.svg'))
                  .width(20)
                  .height(20)
                  .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
              }

              Text(modItem !== null ? modItem.name : this.lt('Rust Core'))
                .fontSize(ThemeConfig.FONT_SIZE_XL)
                .fontColor(this.theme_TEXT_PRIMARY)
                .layoutWeight(1)

              StatusBadge(modItem !== null ? modItem.statusText : this.getCoreStatusText(), modItem !== null ? modItem.statusActive : this.getCoreStatusActive())

              Image($rawfile('arrow-forward-ios.svg'))
                .width(16)
                .height(16)
                .fillColor(this.theme_TEXT_TERTIARY)
            }
            .width('100%')
            .height(ThemeConfig.MENU_ITEM_HEIGHT)
            .onClick(() => {
              this.selectedCoreModuleIndex = index;
              this.refreshCoreDetailInfo();
              this.showCoreDetailDialog = true;
            })
          }, (keyItem: CoreModuleInfo | null, keyIndex: number) => String(keyIndex))

        }
        .width('100%')
      }

      Row({ space: ThemeConfig.SPACING_SM }) {
        Button(this.getCorePrimaryButtonLabel())
          .height(36)
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .backgroundColor(this.officialCoreState.coreReady ? this.theme_SECONDARY_BTN_BG : this.theme_ACCENT)
          .fontColor(this.officialCoreState.coreReady ? this.theme_SECONDARY_BTN_TEXT : this.theme_ACCENT_TEXT)
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.coreLoadBusy)
          .onClick(() => {
            this.handleCorePrimaryAction();
          })

        Button(this.getCoreSecondaryButtonLabel())
          .height(36)
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .backgroundColor(this.theme_SECONDARY_BTN_BG)
          .fontColor(this.theme_SECONDARY_BTN_TEXT)
          .borderRadius(8)
          .layoutWeight(1)
          .enabled(!this.coreLoadBusy && this.officialCoreState.coreReady)
          .onClick(() => {
            this.handleCoreSecondaryAction();
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  private getNativeModuleStatusText(): string {
    if (NativeRustDeskBridge.hasNativeModule()) {
      return this.lt('Ready');
    }
    return this.lt('Unrecognized');
  }

  private isCoreRuntimeLoadedOrRunning(): boolean {
    return this.officialCoreState.coreReady || NativeRustDeskBridge.isCoreLoaded();
  }

  private getCorePrimaryButtonLabel(): string {
    return this.officialCoreState.coreReady ? this.lt('Restart') : this.lt('Start');
  }

  private getCoreSecondaryButtonLabel(): string {
    if (this.coreLoadBusy) {
      return this.lt('Loading...');
    }
    if (this.officialCoreState.coreReady) {
      return this.lt('Stop');
    }
    return this.lt('Stop');
  }

  private handleCorePrimaryAction(): void {
    this.coreLoadBusy = true;
    if (this.officialCoreState.coreReady) {
      this.stopCoreRuntime(false);
      this.coreLoadBusy = true;
    }
    this.ensureCoreLoadedThenStart();
  }

  private handleCoreSecondaryAction(): void {
    if (this.officialCoreState.coreReady) {
      this.stopCoreRuntime(true);
      return;
    }
  }

  private ensureCoreLoadedThenStart(): void {
    if (!NativeRustDeskBridge.isCoreLoaded()) {
      CoreLoaderService.getInstance().autoLoadCore().then((result) => {
        if (result.success) {
          this.refreshCoreDetailInfo();
          this.startCoreRuntime();
        } else {
          this.coreLoadStatus = this.lt('Load failed');
          this.coreLoadBusy = false;
        }
      }).catch(() => {
        this.coreLoadStatus = this.lt('Load failed');
        this.coreLoadBusy = false;
      });
      return;
    }
    this.startCoreRuntime();
  }

  private stopCoreRuntime(refreshAfterStop: boolean = true): void {
    ScreenCaptureService.getInstance().stopCapture();
    NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'N');
    NativeRustDeskBridge.setIncomingServiceEnabled(false, this.settings.idServer, this.settings.relayServer, this.settings.apiServer, this.settings.key);
    NativeRustDeskBridge.closeSession();
    NativeRustDeskBridge.resetForRetry();
    this.settings = this.appData.updateSettings({ serviceEnabled: false });
    this.syncControlledKeepScreenOn();
    this.localDevice = this.appData.setServiceEnabled(false);
    const serverConfig = AppDataService.resolveServerConfig(this.settings);
    this.officialCoreState = {
      adapter: 'official-native',
      coreReady: false,
      incomingReady: false,
      captureRequired: false,
      incomingFramePayloadReady: false,
      incomingFrameId: 0,
      incomingFrameBytes: 0,
      incomingFramesSeen: 0,
      displayId: '',
      fingerprint: '',
      directAddress: '',
      statusSummary: this.lt('Core stopped'),
      detailMessage: this.lt('Core stopped'),
      server: serverConfig.idServer,
      sessionStage: 'idle',
      activePeerId: '',
      lastError: ''
    };
    this.coreLoadStatus = this.lt('Core stopped');
    this.coreLoadBusy = false;
    this.refreshCoreDetailInfo();
    if (refreshAfterStop) {
      void this.refreshState();
    }
  }

  private refreshCoreDetailInfo(): void {
    const modules: CoreModuleInfo[] = [];
    const corePath = CoreLoaderService.getInstance().getCorePath();
    const bridgePaths: string[] = [
      '/data/storage/el1/bundle/libs/arm64/librustdesk_bridge.so',
      '/data/storage/el1/bundle/libs/arm64-v8a/librustdesk_bridge.so',
      '/data/storage/el1/bundle/libs/x86_64/librustdesk_bridge.so',
      '/data/app/el1/bundle/public/com.open.rundesk/libs/arm64-v8a/librustdesk_bridge.so',
      '/data/app/el1/bundle/public/com.open.rundesk/entry/libs/arm64-v8a/librustdesk_bridge.so',
      '/data/app/el1/bundle/public/com.open.rundesk/libs/x86_64/librustdesk_bridge.so',
      '/data/app/el1/bundle/public/com.open.rundesk/entry/libs/x86_64/librustdesk_bridge.so'
    ];
    const bridgeInfo = this.readFirstCoreFileInfo(bridgePaths);
    const rustInfo = corePath.length > 0 ? this.readCoreFileInfo(corePath) : this.readStaticCoreBuildInfo();
    const nativeModuleReady = NativeRustDeskBridge.hasNativeModule();
    const nativeCoreLoaded = NativeRustDeskBridge.isCoreLoaded();
    const staticCorePackaged = CoreBuildInfo.FILE_SIZE.length > 0;
    const nativeCoreAvailable = nativeCoreLoaded || (nativeModuleReady && staticCorePackaged);
    const coreVersion = nativeCoreAvailable ? (NativeRustDeskBridge.getVersion() || '') : '';
    const deviceId = nativeCoreAvailable ? (NativeRustDeskBridge.getMyId() || '') : '';
    const fingerprint = nativeCoreAvailable ? (NativeRustDeskBridge.getFingerprint() || '') : '';
    const bridgeFnCount = nativeCoreAvailable ? String(NativeRustDeskBridge.getRegisteredFunctionCount()) : '0';
    const upstreamVer = CoreBuildInfo.COMPATIBLE_OFFICIAL_VERSION;

    modules.push({
      kind: 'adapter',
      name: this.lt('Adapter'),
      path: 'entry/src/main/ets/services/OfficialRustDeskBridge.ets',
      source: this.officialCoreState.adapter,
      fileSize: '',
      fileSizeMB: '',
      hash: '',
      compatibleOfficialVersion: upstreamVer,
      validElf: true,
      buildTime: BuildInfo.BUILD_TIME,
      statusText: this.officialCoreState.coreReady || nativeModuleReady ? this.lt('Core Ready') : this.lt('Core Unknown'),
      statusActive: this.officialCoreState.coreReady || nativeModuleReady,
      icon: 'settings_tune.svg',
      lastError: this.officialCoreState.lastError,
      detailMessage: this.nativeBridgeSummary,
      statusSummary: `adapter=${this.officialCoreState.adapter}; stage=${this.officialCoreState.sessionStage}; peer=${this.officialCoreState.activePeerId}`,
      bridgeFunctionCount: '369',
      napiRegisteredCount: bridgeFnCount,
      coreVersion: coreVersion,
      deviceId: deviceId,
      fingerprint: fingerprint,
      upstreamVersion: upstreamVer
    });

    modules.push({
      kind: 'native-module',
      name: this.lt('Native Module'),
      path: bridgeInfo.path.length > 0 ? bridgeInfo.path : bridgePaths[0],
      source: 'bundle',
      fileSize: bridgeInfo.fileSize,
      fileSizeMB: bridgeInfo.fileSizeMB,
      hash: bridgeInfo.hash,
      compatibleOfficialVersion: upstreamVer,
      validElf: bridgeInfo.validElf || nativeModuleReady,
      buildTime: bridgeInfo.buildTime.length > 0 ? bridgeInfo.buildTime : BuildInfo.BUILD_TIME,
      statusText: nativeModuleReady ? this.lt('Core Ready') : this.lt('Core Unknown'),
      statusActive: nativeModuleReady,
      icon: 'info_code.svg',
      lastError: nativeModuleReady ? '' : NativeRustDeskBridge.getCombinedDebugSummary(),
      detailMessage: this.nativeBridgeSummary,
      statusSummary: nativeModuleReady ? this.lt('Native Module') : this.lt('Unrecognized'),
      bridgeFunctionCount: '369',
      napiRegisteredCount: bridgeFnCount,
      coreVersion: coreVersion,
      deviceId: deviceId,
      fingerprint: fingerprint,
      upstreamVersion: upstreamVer
    });

    modules.push({
      kind: 'native-core',
      name: this.lt('Native Core'),
      path: corePath.length > 0 ? corePath : (rustInfo.path.length > 0 ? rustInfo.path : 'linked into librustdesk_bridge.so'),
      source: CoreLoaderService.getInstance().getCoreSource().length > 0 ? CoreLoaderService.getInstance().getCoreSource() : 'staticlib',
      fileSize: rustInfo.fileSize,
      fileSizeMB: rustInfo.fileSizeMB,
      hash: rustInfo.hash,
      compatibleOfficialVersion: upstreamVer,
      validElf: nativeCoreAvailable,
      buildTime: rustInfo.buildTime,
      statusText: this.officialCoreState.coreReady ? this.lt('Core Ready') : (nativeCoreAvailable ? this.lt('Core Stopped') : this.lt('Core Unknown')),
      statusActive: this.officialCoreState.coreReady,
      icon: 'settings_cpu.svg',
      lastError: nativeModuleReady ? this.officialCoreState.lastError : NativeRustDeskBridge.getCombinedDebugSummary(),
      detailMessage: this.officialCoreState.detailMessage.length > 0 ? this.officialCoreState.detailMessage : this.nativeBridgeSummary,
      statusSummary: this.officialCoreState.statusSummary,
      bridgeFunctionCount: '369',
      napiRegisteredCount: bridgeFnCount,
      coreVersion: coreVersion,
      deviceId: deviceId,
      fingerprint: fingerprint,
      upstreamVersion: upstreamVer
    });
    this.coreModules = modules;
  }

  private createEmptyCoreFileInfo(): CoreModuleInfo {
    return {
      kind: '',
      name: '',
      path: '',
      source: '',
      fileSize: '',
      fileSizeMB: '',
      hash: '',
      compatibleOfficialVersion: '',
      validElf: false,
      buildTime: '',
      statusText: '',
      statusActive: false,
      icon: '',
      lastError: '',
      detailMessage: '',
      statusSummary: '',
      bridgeFunctionCount: '',
      napiRegisteredCount: '',
      coreVersion: '',
      deviceId: '',
      fingerprint: '',
      upstreamVersion: ''
    };
  }

  private readStaticCoreBuildInfo(): CoreModuleInfo {
    const info = this.createEmptyCoreFileInfo();
    info.path = CoreBuildInfo.SOURCE_PATH;
    info.fileSize = CoreBuildInfo.FILE_SIZE;
    info.fileSizeMB = CoreBuildInfo.FILE_SIZE_MB;
    info.hash = CoreBuildInfo.HASH_FNV1A_1MB.length > 0 ? CoreBuildInfo.HASH_FNV1A_1MB : CoreBuildInfo.HASH_SHA256;
    info.buildTime = CoreBuildInfo.COMPILE_TIME.length > 0
      ? CoreBuildInfo.COMPILE_TIME
      : this.formatCoreCompileTime(Number(CoreBuildInfo.MODIFIED_TIME));
    return info;
  }

  private readFirstCoreFileInfo(paths: string[]): CoreModuleInfo {
    let fallback = this.createEmptyCoreFileInfo();
    for (let index = 0; index < paths.length; index += 1) {
      const info = this.readCoreFileInfo(paths[index]);
      if (index === 0) {
        fallback = info;
      }
      if (info.fileSize.length > 0 || info.validElf) {
        return info;
      }
    }
    return fallback;
  }

  private readCoreFileInfo(path: string): CoreModuleInfo {
    const empty = this.createEmptyCoreFileInfo();
    try {
      const info = JSON.parse(NativeRustDeskBridge.getCoreFileInfo(path)) as Record<string, Object>;
      empty.path = path;
      empty.fileSize = String(info['fileSize'] ?? '');
      empty.fileSizeMB = String(info['fileSizeMB'] ?? '');
      empty.hash = String(info['hash'] ?? '');
      empty.validElf = info['validElf'] === true;
      empty.buildTime = this.formatCoreCompileTime(Number(info['modifiedTime'] ?? 0));
    } catch (_e) {
    }
    return empty;
  }

  @Builder
  private buildCoreDetailDialog() {
    Column() {
      Column({ space: 20 }) {
        Row() {
          Text(this.getSelectedCoreModuleName())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showCoreDetailDialog = false;
            })
        }
        .width('100%')

        Column({ space: 0 }) {
          this.buildSettingsInfoSettingRow(this.lt('Type'), this.getSelectedCoreModuleField('kind').length > 0 ? this.getSelectedCoreModuleField('kind') : this.lt('Unknown'), 'info_layers.svg')
          this.buildSettingsInfoSettingRow(this.lt('Status'), this.getSelectedCoreModuleField('statusActive') === 'true' ? this.lt('Running') : this.lt('Stopped'), 'settings_terminal.svg')
          this.buildSettingsInfoSettingRow(this.lt('Compatible'), this.getSelectedCoreModuleField('compatibleOfficialVersion').length > 0 ? `RustDesk ${this.getSelectedCoreModuleField('compatibleOfficialVersion')}` : this.lt('Unknown'), 'info_code.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('File'), this.getSelectedCoreModuleField('path').length > 0 ? this.getSelectedCoreModuleField('path').split('/').pop() ?? this.getSelectedCoreModuleField('path') : this.lt('None'), 'info_file.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('File Size'), this.getSelectedCoreFileSizeText(), 'info_drive.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Hash (FNV-1a)'), this.getSelectedCoreModuleField('hash').length > 0 ? this.getSelectedCoreModuleField('hash') : this.lt('Unknown'), 'info_hash.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Compile'), this.getSelectedCoreModuleField('buildTime').length > 0 ? this.getSelectedCoreModuleField('buildTime') : this.lt('Unknown'), 'info_clock.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Valid'), this.getSelectedCoreModuleValidElf() ? this.lt('Yes') : this.lt('No'), 'opt_shield.svg', '', true)
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showCoreDetailDialog = false;
    })
  }

  private getSelectedCoreModuleName(): string {
    if (this.coreModules.length > 0 && this.selectedCoreModuleIndex < this.coreModules.length) {
      return this.coreModules[this.selectedCoreModuleIndex].name;
    }
    return this.lt('Rust Core');
  }

  private getSelectedCoreModuleField(field: string): string {
    if (this.coreModules.length > 0 && this.selectedCoreModuleIndex < this.coreModules.length) {
      const mod = this.coreModules[this.selectedCoreModuleIndex];
      if (field === 'kind') return mod.kind;
      if (field === 'statusText') return mod.statusText;
      if (field === 'lastError') return mod.lastError;
      if (field === 'detailMessage') return mod.detailMessage;
      if (field === 'statusSummary') return mod.statusSummary;
      if (field === 'path') return mod.path;
      if (field === 'fileSize') return mod.fileSize;
      if (field === 'fileSizeMB') return mod.fileSizeMB;
      if (field === 'hash') return mod.hash;
      if (field === 'compatibleOfficialVersion') return mod.compatibleOfficialVersion;
      if (field === 'buildTime') return mod.buildTime;
      if (field === 'source') return mod.source;
      if (field === 'bridgeFunctionCount') return mod.bridgeFunctionCount;
      if (field === 'napiRegisteredCount') return mod.napiRegisteredCount;
      if (field === 'coreVersion') return mod.coreVersion;
      if (field === 'deviceId') return mod.deviceId;
      if (field === 'fingerprint') return mod.fingerprint;
      if (field === 'upstreamVersion') return mod.upstreamVersion;
      if (field === 'statusActive') return String(mod.statusActive);
    }
    return '';
  }

  private getSelectedCoreFileSizeText(): string {
    const fileSizeMb = this.getSelectedCoreModuleField('fileSizeMB');
    const fileSize = this.getSelectedCoreModuleField('fileSize');
    if (fileSizeMb.length > 0 && fileSize.length > 0) {
      return `${fileSizeMb} MB (${fileSize} bytes)`;
    }
    if (fileSizeMb.length > 0) {
      return `${fileSizeMb} MB`;
    }
    if (fileSize.length > 0) {
      return `${fileSize} bytes`;
    }
    return this.lt('Unknown');
  }

  private getSelectedCoreModuleValidElf(): boolean {
    if (this.coreModules.length > 0 && this.selectedCoreModuleIndex < this.coreModules.length) {
      return this.coreModules[this.selectedCoreModuleIndex].validElf;
    }
    return false;
  }

  private startCoreRuntime(): void {
    const appDir = CoreLoaderService.getInstance().getCoreDirectory().replace('/' + 'core', '');
    const serverConfig = AppDataService.resolveServerConfig(this.settings);
    const snapshot = NativeRustDeskBridge.initializeRuntime(appDir, '') ??
      NativeRustDeskBridge.readSnapshot(serverConfig.idServer);
    if (snapshot && snapshot.coreReady) {
      this.coreLoadStatus = this.lt('Core started');
      void this.refreshState();
    } else {
      this.coreLoadStatus = this.lt('Start failed, check server config');
      void this.refreshState();
    }
    this.coreLoadBusy = false;
  }

  private getCoreStatusText(): string {
    if (this.officialCoreState.coreReady) {
      return this.lt('Core Ready');
    }
    if (NativeRustDeskBridge.isCoreLoaded()) {
      return this.lt('Core Stopped');
    }
    if (NativeRustDeskBridge.hasNativeModule()) {
      return this.lt('Core Stopped');
    }
    return this.lt('Core Unknown');
  }

  private getCoreRuntimeText(): string {
    const parts: string[] = [];
    if (this.officialCoreState.coreReady) {
      const summary = this.getSelectedCoreModuleField('statusSummary').trim();
      parts.push(summary.length > 0 ? summary : this.lt('Ready'));
    } else if (NativeRustDeskBridge.isCoreLoaded() || NativeRustDeskBridge.hasNativeModule()) {
      parts.push(this.lt('Stop'));
    } else {
      parts.push(this.lt('Error'));
    }
    const lastError = this.getSelectedCoreModuleField('lastError').trim();
    if (lastError.length > 0) parts.push(lastError);
    const detail = this.getSelectedCoreModuleField('detailMessage').trim();
    if (detail.length > 0) parts.push(detail);
    return parts.join(' | ');
  }

  private getCoreStatusDetailText(): string {
    if (this.officialCoreState.coreReady) {
      const summary = this.officialCoreState.statusSummary.trim();
      return summary.length > 0 ? summary : this.lt('Ready');
    }
    if (NativeRustDeskBridge.isCoreLoaded()) {
      return this.lt('Stop');
    }
    if (NativeRustDeskBridge.hasNativeModule()) {
      return this.lt('Stop');
    }
    return this.lt('Error');
  }

  private getCoreStatusActive(): boolean {
    return this.officialCoreState.coreReady;
  }

  @Builder
  private buildCoreServiceCard() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Service Info'))
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsInfoSettingRow(this.lt('Display ID'), this.officialCoreState.displayId.length > 0 ? this.formatId(this.officialCoreState.displayId) : this.lt('Waiting for core init'), 'info_hash.svg')
          this.buildSettingsInfoSettingRow(this.lt('Server'), this.describeEffectiveServer(), 'settings_server.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Fingerprint'), this.officialCoreState.fingerprint.length > 0 ? this.officialCoreState.fingerprint : this.lt('None'), 'settings_shield_check.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Direct Address'), this.officialCoreState.directAddress.length > 0 ? this.officialCoreState.directAddress : this.lt('None'), 'opt_link.svg', '', true)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildCoreSessionCard() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Session'))
      CardContainer() {
        Column({ space: 0 }) {
          this.buildSettingsInfoSettingRow(this.lt('Stage'), this.officialCoreState.sessionStage, 'info_layers.svg')
          this.buildSettingsInfoSettingRow(this.lt('Current Target'), this.officialCoreState.activePeerId.length > 0 ? this.formatId(this.officialCoreState.activePeerId) : this.lt('None'), 'info_target.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('Status'), this.officialCoreState.statusSummary.length > 0 ? this.officialCoreState.statusSummary : this.lt('Idle'), 'settings_record.svg', '', true)
          this.buildSettingsInfoSettingRow(this.lt('File transfer'), this.settings.allowFileTransfer ? this.lt('Allowed') : this.lt('Not Allowed'), 'menu_transfer.svg', '', true)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildCoreDebugCard() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Runtime Summary'))
      CardContainer() {
        Text(this.getFullDebugSummary())
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')
          .maxLines(12)
          .padding({ top: ThemeConfig.SPACING_MD, bottom: ThemeConfig.SPACING_MD })
      }
    }
    .width('100%')
    .gesture(LongPressGesture().onAction(() => {
      void this.copyText(this.getFullDebugSummary(), this.lt('Debug summary copied'));
    }))
  }

  private getFullDebugSummary(): string {
    return this.nativeBridgeSummary.trim().length > 0
      ? this.nativeBridgeSummary
      : NativeRustDeskBridge.getRuntimeLogSummary();
  }

  @Builder
  private buildRecentSessionsCard() {
    if (this.filterRecentSessions(this.recentSessions).length === 0 && this.recentSessions.length > 0) {
      EmptyState($rawfile('display.svg'), this.lt('No matching results'))
    } else if (this.recentSessions.length === 0) {
      EmptyState($rawfile('display.svg'), this.lt('No recent sessions yet. Your first connection will appear here.'))
    } else {
      Column({ space: ThemeConfig.SPACING_SM }) {
        ForEach(this.filterRecentSessions(this.recentSessions), (session: RecentSession) => {
          this.buildRecentSessionRow(session)
        }, (session: RecentSession) => session.id)
      }
      .width('100%')
    }
  }

  @Builder
  private buildChatSessionCard(session: ChatSession) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      Row() {
        this.buildThemedPlatformIcon(this.resolvePlatformForDevice(session.deviceId, session.deviceName), 26)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme_ACCENT_SURFACE)
      .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)

      Column({ space: 4 }) {
        Text(session.deviceName)
          .fontSize(ThemeConfig.FONT_SIZE_XL)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme_TEXT_PRIMARY)
          .width('100%')

        Text(this.formatId(session.deviceId))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')

        Text(this.describeLastChatMessage(session.lastMessage))
          .fontSize(ThemeConfig.FONT_SIZE_SM)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        if (session.unreadCount > 0) {
          this.buildSmallPill(`${session.unreadCount} ${this.lt('unread')}`, this.theme_ERROR_BG, this.theme_ERROR_TEXT)
        }

        Image($rawfile('arrow-forward-ios.svg'))
          .width(16)
          .height(16)
          .fillColor(this.theme_TEXT_TERTIARY)
      }
    }
    .width('100%')
    .padding(ThemeConfig.SPACING_LG)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .border({ width: 1, color: this.theme_BORDER_SUBTLE })
    .onClick(() => {
      this.navigateTo('pages/Chat', { deviceId: session.deviceId });
    })
  }

  @Builder
  private buildShareServiceCard() {
    CardContainer() {
      Column({ space: ThemeConfig.SPACING_MD }) {
        Row({ space: ThemeConfig.SPACING_MD }) {
          Image(this.isShareServiceRunning() ? $rawfile('secure.svg') : $rawfile('secure_stop.svg'))
            .width(36)
            .height(36)
            .fillColor(this.isShareServiceRunning() ? this.theme_SUCCESS_TEXT : (this.isShareRecordingProbeActive() ? this.theme_WARNING_TEXT : this.theme_ERROR_TEXT))

          Column() {
            Text(this.resolveShareServiceDescription())
              .fontSize(ThemeConfig.FONT_SIZE_MD)
              .fontColor(this.theme_TEXT_SECONDARY)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          StatusBadge(this.resolveShareStatusBadgeText(), this.isShareServiceRunning())
        }
        .width('100%')

        Column({ space: 0 }) {
          this.buildSettingsInfoSettingRow(this.lt('Device name'), this.localDevice.alias)
        }
        .width('100%')
        if (this.settings.serviceEnabled) {
          this.buildCopyableInfoRow(
            this.lt('Device ID'),
            this.getShareDisplayId().length > 0 ? this.formatId(this.getShareDisplayId()) : this.lt('Waiting for core init'),
            this.getShareDisplayId(),
            this.lt('Device ID copied')
          )
          if (this.oneTimePassword.length > 0) {
            this.buildCopyableInfoRow(
              this.lt('One-time password'),
              this.oneTimePassword,
              this.oneTimePassword,
              this.lt('Password copied')
            )
          }
        }

        Row({ space: ThemeConfig.SPACING_SM }) {
          Button(this.isShareStopAvailable() ? this.lt('Stop service') : this.lt('Start service'))
            .layoutWeight(1)
            .height(ThemeConfig.BUTTON_HEIGHT_MEDIUM)
            .fontSize(ThemeConfig.FONT_SIZE_MD)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
            .onClick(() => {
              if (this.isShareStopAvailable()) {
                void this.toggleIncomingService(false);
              } else {
                this.requestShareServiceStart();
              }
            })
          if (this.settings.serviceEnabled) {
            Button(this.lt('Generate password'))
              .layoutWeight(1)
              .height(ThemeConfig.BUTTON_HEIGHT_MEDIUM)
              .fontSize(ThemeConfig.FONT_SIZE_MD)
              .backgroundColor(this.theme_INPUT_BG)
              .fontColor(this.theme_TEXT_PRIMARY)
              .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
              .onClick(() => {
                void this.generateSharePassword();
              })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ top: ThemeConfig.SPACING_XL, bottom: ThemeConfig.SPACING_XL })
    }
  }

  private isShareServiceRunning(): boolean {
    return this.settings.serviceEnabled &&
      this.officialCoreState.incomingReady &&
      this.isNativeScreenCaptureRunning();
  }

  private isNativeScreenCaptureRunning(): boolean {
    return ScreenCaptureService.getInstance().isCapturingActive() ||
      NativeRustDeskBridge.isNativeScreenCaptureActive();
  }

  private isShareRecordingProbeActive(): boolean {
    return this.settings.serviceEnabled &&
      this.isNativeScreenCaptureRunning() &&
      !this.officialCoreState.incomingReady;
  }

  private isShareStopAvailable(): boolean {
    return this.settings.serviceEnabled ||
      this.officialCoreState.incomingReady ||
      this.isNativeScreenCaptureRunning();
  }

  private resolveShareServiceDescription(): string {
    if (this.isShareServiceRunning()) {
      return this.lt('Screen share service started, can accept remote connections.');
    }
    if (this.isShareRecordingProbeActive()) {
      return this.lt('Screen recording probe is active, but the core incoming video source is not ready.');
    }
    if (this.settings.serviceEnabled) {
      const detail = (this.officialCoreState.lastError || this.officialCoreState.detailMessage).trim();
      if (detail.length > 0) {
        return detail;
      }
      return this.lt('Incoming service requested, waiting for core readiness.');
    }
    return this.lt('Tap to start service or enable screen capture, then screen sharing will start.');
  }

  private resolveShareStatusBadgeText(): string {
    if (this.isShareServiceRunning()) {
      return this.lt('Running');
    }
    if (this.isShareRecordingProbeActive()) {
      return this.lt('Recording Probe');
    }
    if (this.settings.serviceEnabled) {
      return this.lt('Requested');
    }
    return this.lt('Not running');
  }

  private getShareDisplayId(): string {
    const coreDisplayId = this.officialCoreState.displayId.trim();
    if (coreDisplayId.length > 0) {
      return coreDisplayId;
    }
    return this.localDevice.id.trim();
  }

  @Builder
  private buildCopyableInfoRow(label: string, value: string, copyValue: string, copiedMessage: string) {
    Row() {
      Text(label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_SECONDARY)
        .layoutWeight(1)

      Text(value)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .padding({ left: ThemeConfig.SPACING_LG, right: ThemeConfig.SPACING_LG })
    .gesture(
      LongPressGesture({ duration: 500 })
        .onAction(() => {
          void this.copyText(copyValue, copiedMessage);
        })
    )
  }

  @Builder
  private buildCapabilityCard() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      this.buildSettingsSectionLabel(this.lt('Permissions'))
      CardContainer() {
        Column({ space: 0 }) {
          this.buildToggleRow(this.lt('Screen Capture'), this.isShareServiceRunning(), (value: boolean) => {
            if (value) {
              this.requestShareServiceStart();
            } else {
              void this.toggleIncomingService(false);
            }
          }, false, 'settings_monitor.svg')
          this.buildUnsupportedCapabilityRow(
            this.lt('Input Control'),
            this.lt('HarmonyOS currently does not support this feature'),
            true,
            'opt_mouse.svg'
          )
          this.buildToggleRow(this.lt('File transfer'), this.settings.allowFileTransfer, (value: boolean) => {
            if (value) {
              this.updateSettings({ allowFileTransfer: true });
              void this.checkFileTransferPermissionAndToggle(true);
            } else {
              this.updateSettings({ allowFileTransfer: false });
            }
          }, true, 'menu_transfer.svg')
          this.buildToggleRow(this.lt('Audio Recording'), this.settings.enableAudio, (value: boolean) => {
            if (value) {
              this.updateSettings({ enableAudio: true });
              void this.checkAudioPermissionAndToggle();
            } else {
              this.updateSettings({ enableAudio: false });
            }
          }, true, 'opt_mic.svg')
          this.buildToggleRow(this.lt('Allow Clipboard Sync'), this.settings.allowClipboard, (value: boolean) => {
            if (value) {
              this.updateSettings({ allowClipboard: true, enableClipboard: true });
              void this.checkClipboardPermissionAndToggle();
            } else {
              this.updateSettings({ allowClipboard: false, enableClipboard: false });
            }
          }, true, 'menu_clipboard.svg')
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildUnsupportedCapabilityRow(label: string, detail: string, showTopBorder: boolean, icon: string) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      Image($rawfile(icon))
        .width(20)
        .height(20)
        .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))

      Text(label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      Text(detail)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(this.theme_TEXT_TERTIARY)
        .textAlign(TextAlign.End)
        .constraintSize({ maxWidth: '52%' })
        .maxLines(2)
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .onClick(() => {
      void this.showToast(`${label} · ${this.lt('In development')}`);
    })
  }

  @Builder
  private buildRecentSessionRow(session: RecentSession) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      Row() {
        this.buildThemedPlatformIcon(session.platform, 26)
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme_ACCENT_SURFACE)
      .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Circle()
            .width(8)
            .height(8)
            .fill((() => { this.peerOnlineVersion; return this.appData.isPeerOnline(session.id); })() ? this.theme_SUCCESS_TEXT : this.theme_WARNING_TEXT)

          Text(this.formatId(session.id))
            .fontSize(ThemeConfig.FONT_SIZE_XL)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme_TEXT_PRIMARY)
        }

        if (this.resolveRecentSessionName(session).trim().length > 0) {
          Text(this.resolveRecentSessionName(session))
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Image($rawfile('dots_vertical.svg'))
          .width(20)
          .height(20)
          .fillColor(this.theme_TEXT_TERTIARY)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .hitTestBehavior(HitTestMode.Block)
      .onClick(() => {
        this.recentMenuSessionId = session.id;
      })
    }
    .width('100%')
    .padding(ThemeConfig.SPACING_LG)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
    .border({ width: 1, color: this.theme_BORDER_SUBTLE })
    .onClick(() => {
      this.selectDeviceIdInputTarget(session.id);
      void this.handleConnect(session.id);
    })
  }

  @Builder
  private buildRecentSessionMenu() {
    Column() {
      Scroll() {
        Column({ space: 0 }) {
        this.buildPeerMenuActionRow(this.lt('Connect'), () => {
          const id = this.recentMenuSessionId;
          this.recentMenuSessionId = '';
          this.selectDeviceIdInputTarget(id);
          void this.handleConnect(id);
        })

        this.buildPeerMenuActionRow(this.lt('Transfer file'), () => {
          const id = this.recentMenuSessionId;
          this.recentMenuSessionId = '';
          this.navigateTo('pages/FileTransfer', { deviceId: id });
        })

        this.buildPeerMenuActionRow(this.lt('View Camera'), () => {
          this.closePeerMenuAsDeveloping(this.lt('View Camera'));
        }, false)

        this.buildPeerMenuActionRow(this.lt('Terminal (beta)'), () => {
          const id = this.recentMenuSessionId;
          this.recentMenuSessionId = '';
          this.navigateTo('pages/Terminal', { deviceId: id });
        })

        this.buildPeerMenuActionRow(this.lt('Administrator'), () => {
          this.closePeerMenuAsDeveloping(this.lt('Administrator'));
        }, false)

        this.buildForceRelayConnectionRow(this.recentMenuSessionId)

        Divider()
          .color(this.theme_BORDER_SUBTLE)
          .margin({ left: 20, right: 20 })

        if (this.currentConnectTab === 'recent' || this.currentConnectTab === 'addressBook' || this.currentConnectTab === 'favorites') {
          this.buildPeerMenuActionRow(this.lt('Rename'), () => {
            const id = this.recentMenuSessionId;
            const session = this.recentSessions.find((s: RecentSession) => s.id === id);
            this.renameTargetId = id;
            this.renameDraft = session ? session.name : id;
            this.recentMenuSessionId = '';
            this.showRenameDialog = true;
          })
        }

        if (this.currentConnectTab === 'recent' || this.currentConnectTab === 'addressBook' || this.currentConnectTab === 'favorites') {
          this.buildPeerMenuActionRow(this.lt('Forget Password'), () => {
            const id = this.recentMenuSessionId;
            this.recentMenuSessionId = '';
            void this.clearRecentTargetPasswordById(id);
          })
        }

        if (this.currentConnectTab === 'recent') {
          if (this.appData.isFavorite(this.recentMenuSessionId)) {
            this.buildPeerMenuActionRow(this.lt('Remove from Favorites'), () => {
              const id = this.recentMenuSessionId;
              this.recentMenuSessionId = '';
              this.appData.removeFavorite(id);
              this.addressBookVersion++;
              this.refreshAccountState();
            }, true, '', 'star_filled.svg')
          } else {
            this.buildPeerMenuActionRow(this.lt('Add to Favorites'), () => {
              const id = this.recentMenuSessionId;
              this.recentMenuSessionId = '';
              this.appData.addFavorite(id);
              this.addressBookVersion++;
              this.refreshAccountState();
            }, true, '', 'star.svg')
          }

          if (this.accountState.isLoggedIn && !this.isInAddressBook(this.recentMenuSessionId)) {
            this.buildPeerMenuActionRow(this.lt('Add to Address Book'), () => {
              const id = this.recentMenuSessionId;
              const session = this.recentSessions.find((s: RecentSession) => s.id === id);
              this.recentMenuSessionId = '';
              this.appData.addAddressBookEntry({
                id: id,
                alias: session ? session.name : '',
                note: '',
                group: '',
                online: false,
                favorite: false,
                platform: session ? session.platform : ''
              });
              this.refreshAccountState();
            })
          }
        }

        if (this.currentConnectTab === 'favorites') {
          this.buildPeerMenuActionRow(this.lt('Remove from Favorites'), () => {
            const id = this.recentMenuSessionId;
            this.recentMenuSessionId = '';
            this.appData.removeFavorite(id);
            this.addressBookVersion++;
            this.refreshAccountState();
          }, true, '', 'star_filled.svg')
        }

        if (this.currentConnectTab === 'addressBook') {
          this.buildPeerMenuActionRow(this.lt('Remove from Address Book'), () => {
            const id = this.recentMenuSessionId;
            this.recentMenuSessionId = '';
            this.appData.removeAddressBookEntry(id);
            this.refreshAccountState();
          })
        }

        if (this.currentConnectTab === 'recent' || this.currentConnectTab === 'favorites' ||
          this.currentConnectTab === 'addressBook' || this.currentConnectTab === 'discovered') {
          Divider()
            .color(this.theme_BORDER_SUBTLE)

          this.buildPeerMenuActionRow(this.lt('Delete'), () => {
            const id = this.recentMenuSessionId;
            this.recentMenuSessionId = '';
            if (this.currentConnectTab === 'recent') {
              void this.deleteRecentTargetById(id);
            } else if (this.currentConnectTab === 'favorites') {
              this.appData.removeFavorite(id);
              this.addressBookVersion++;
              this.refreshAccountState();
            } else if (this.currentConnectTab === 'addressBook') {
              this.appData.removeAddressBookEntry(id);
              this.refreshAccountState();
            } else {
              LanDiscoveryService.getInstance().removeDiscoveredPeer(id);
              this.addressBookVersion++;
            }
          }, true, this.theme_ERROR_TEXT, 'delete-forever.svg')
        }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
      .width(248)
      .constraintSize({ maxHeight: '84%' })
      .scrollBar(BarState.Off)
      .backgroundColor(this.theme_CARD_BG)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .borderRadius(12)
      .shadow({ radius: 16, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.recentMenuSessionId = '';
    })
  }

  @Builder
  private buildPeerMenuActionRow(label: string, action: () => void, available: boolean = true, textColor: string = '', icon: string = '') {
    Row({ space: 10 }) {
      Text(label)
        .fontSize(16)
        .fontColor(textColor.length > 0 ? textColor : (available ? this.theme_TEXT_PRIMARY : this.theme_TEXT_TERTIARY))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(20)
          .height(20)
          .fillColor(textColor.length > 0 ? textColor : this.theme_ACCENT)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(action)
  }

  private closePeerMenuAsDeveloping(label: string): void {
    this.recentMenuSessionId = '';
    void this.showToast(`${label} · ${this.lt('In development')}`);
  }

  @Builder
  private buildForceRelayConnectionRow(peerId: string) {
    Row({ space: 10 }) {
      if (PreferenceStore.getPeerConnectMode(peerId) === 'relay') {
        Image($rawfile('checkbox-outline.svg'))
          .width(20)
          .height(20)
          .fillColor(this.theme_ACCENT)
      } else {
        Rect()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.theme_TEXT_TERTIARY)
          .strokeWidth(2)
          .radius(4)
      }

      Text(this.lt('Always connect via relay'))
        .fontSize(16)
        .fontColor(PreferenceStore.getPeerConnectMode(peerId) === 'relay' ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      const forceRelay = PreferenceStore.getPeerConnectMode(peerId) !== 'relay';
      PreferenceStore.setPeerConnectMode(peerId, forceRelay ? 'relay' : 'direct');
      this.recentMenuSessionId = '';
    })
  }

  private resolveConnectEntryName(entry: AddressBookEntry): string {
    const alias = entry.alias.trim();
    const generatedRemoteAlias = this.lt('Remote Device').trim();
    if (alias.length > 0 &&
      !alias.startsWith('Remote ') &&
      (generatedRemoteAlias.length === 0 || !alias.startsWith(generatedRemoteAlias))) {
      return alias;
    }
    const displayName = this.appData.getDisplayName(entry.id);
    if (displayName.trim().length > 0) {
      return displayName;
    }
    const cachedHostname = this.getPeerCachedHostname(entry.id);
    if (cachedHostname.trim().length > 0) {
      return cachedHostname;
    }
    const recentName = this.getRecentSessionName(entry.id);
    if (recentName.trim().length > 0) {
      return recentName;
    }
    if (alias.length > 0) {
      return alias;
    }
    return '';
  }

  private getPeerCachedHostname(id: string): string {
    const info = NativeRustDeskBridge.getPeerInfo(id);
    if (info.hostname.length > 0) {
      return this.formatPeerDisplayName(info.hostname, info.username);
    }
    return '';
  }

  private formatCoreCompileTime(seconds: number): string {
    if (!Number.isFinite(seconds) || seconds <= 0) {
      return '';
    }
    try {
      return new Date(seconds * 1000).toISOString().replace('T', ' ').replace('Z', '');
    } catch (_error) {
      return '';
    }
  }

  private getRecentSessionName(id: string): string {
    for (const s of this.recentSessions) {
      if (s.id === id && s.name.trim().length > 0) {
        return s.name.trim();
      }
    }
    return '';
  }

  private resolveConnectEntrySummary(entry: AddressBookEntry): string {
    const parts: string[] = [];
    if (entry.group.trim().length > 0) {
      parts.push(entry.group.trim());
    }
    if (entry.note.trim().length > 0) {
      parts.push(entry.note.trim());
    }
    if (parts.length === 0) {
      parts.push(entry.online ? this.lt('Online connectable devices') : this.lt('Saved address book devices'));
    }
    return parts.join(' 路 ');
  }

  private resolveRecentSessionName(session: RecentSession): string {
    const cachedHostname = this.getPeerCachedHostname(session.id);
    if (cachedHostname.trim().length > 0) {
      return cachedHostname;
    }
    const alias = this.appData.getDisplayName(session.id);
    if (alias.trim().length > 0) {
      return alias.trim();
    }
    const name = session.name.trim();
    if (name.length > 0) {
      return name;
    }
    return '';
  }

  @Builder
  private buildToggleRow(label: string, value: boolean, action: (value: boolean) => void, showTopBorder: boolean = false, icon: string = '') {
    Row() {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(20)
          .height(20)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
          .margin({ right: ThemeConfig.SPACING_SM })
      }

      Text(label)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.theme_ACCENT)
        .switchPointColor(this.theme_WHITE)
        .constraintSize({ maxHeight: 32 })
        .onChange((isOn: boolean) => {
          action(isOn);
        })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
  }

  @Builder
  private buildSmallPill(text: string, bgColor: string, fontColor: string) {
    Text(text)
      .fontSize(ThemeConfig.FONT_SIZE_XS)
      .fontColor(fontColor)
      .backgroundColor(bgColor)
      .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
  }

  @Builder
  private buildSettingsPageHeader() {
    Column({ space: ThemeConfig.SPACING_SM }) {
      Row({ space: ThemeConfig.SPACING_MD }) {
        Text(this.lt('RustDesk'))
          .fontSize(ThemeConfig.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)
          .layoutWeight(1)

        Button() {
          Image($rawfile('scan_frame.svg'))
            .width(22)
            .height(22)
            .fillColor(this.theme_TEXT_TERTIARY)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(Color.Transparent)
        .border({ width: 1.5, color: this.theme_TEXT_TERTIARY, style: BorderStyle.Solid })
        .onClick(() => {
          this.navigateTo('pages/Scan');
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: ThemeConfig.SPACING_SM, bottom: ThemeConfig.SPACING_MD })
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private buildConnectPeerTabIcon(tab: ConnectPeerTab) {
    if (tab === 'recent' || tab === 'addressBook') {
      Image(this.resolveConnectPeerTabIconResource(tab))
        .width(22)
        .height(22)
        .colorFilter(this.createStrokeIconColorFilter(this.resolveConnectPeerTabIconColor(tab)))
    } else {
      Image(this.resolveConnectPeerTabIconResource(tab))
        .width(tab === 'core' ? 20 : 22)
        .height(tab === 'core' ? 20 : 22)
        .fillColor(this.resolveConnectPeerTabIconColor(tab))
    }
  }

  @Builder
  private buildConnectPeerTabButton(tab: ConnectPeerTab) {
    Column({ space: 4 }) {
      this.buildConnectPeerTabIcon(tab)

      Row() {}
        .width(28)
        .height(2)
        .backgroundColor(this.currentConnectTab === tab ? this.theme_ACCENT : this.theme_CARET_HIDDEN)
        .borderRadius(ThemeConfig.BORDER_RADIUS_ROUND)
    }
    .width(34)
    .height(42)
    .justifyContent(FlexAlign.Start)
    .padding({ top: 6 })
    .alignItems(HorizontalAlign.Center)
    .clip(false)
    .hitTestBehavior(HitTestMode.Block)
    .id(tab === 'recent' ? 'recent-tab-btn' : `${tab}-tab-btn`)
    .onClick(() => {
      this.dismissConnectSearch();
      this.currentConnectTab = tab;
      this.requestConnectTabFocus(20, tab === 'recent' ? 'recent-tab-btn' : `${tab}-tab-btn`);
    })
    .gesture(
      LongPressGesture({ duration: 500 })
        .onAction(() => {
          this.showConnectTabVisibilityMenu = true;
        })
    )
  }

  @Builder
  private buildSettingsSectionLabel(title: string, icon: string = '') {
    Row({ space: 6 }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(16)
          .height(16)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_SECONDARY))
      }
      Text(title)
        .fontSize(ThemeConfig.FONT_SIZE_MD)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme_TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: ThemeConfig.SPACING_SM })
  }

  @Builder
  private buildSettingsLinkRow(label: string, value: string, action: () => void, detail: string = '', showTopBorder: boolean = false, icon: string = '') {
    Row({ space: ThemeConfig.SPACING_MD }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(20)
          .height(20)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Column({ space: 4 }) {
        Text(label)
          .fontSize(ThemeConfig.FONT_SIZE_XL)
          .fontColor(this.theme_TEXT_PRIMARY)
          .width('100%')

        if (detail.trim().length > 0) {
          Text(detail)
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(value)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(this.theme_TEXT_SECONDARY)
        .textAlign(TextAlign.End)
        .width('32%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Image($rawfile('arrow-forward-ios.svg'))
        .width(16)
        .height(16)
        .fillColor(this.theme_TEXT_TERTIARY)
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .onClick(action)
  }

  @Builder
  private buildSettingsInfoSettingRow(label: string, value: string, icon: string = '', detail: string = '', showTopBorder: boolean = false) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(20)
          .height(20)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Column({ space: 4 }) {
        Text(label)
          .fontSize(ThemeConfig.FONT_SIZE_XL)
          .fontColor(this.theme_TEXT_PRIMARY)
          .width('100%')

        if (detail.trim().length > 0) {
          Text(detail)
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(value)
        .fontSize(ThemeConfig.FONT_SIZE_SM)
        .fontColor(this.theme_TEXT_SECONDARY)
        .textAlign(TextAlign.End)
        .width('38%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
  }

  @Builder
  private buildDirectIpSettingRow() {
    Row({ space: ThemeConfig.SPACING_MD }) {
      Image($rawfile('settings_network.svg'))
        .width(20)
        .height(20)
        .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))

      Column({ space: 4 }) {
        Text(this.lt('Direct IP access'))
          .fontSize(ThemeConfig.FONT_SIZE_XL)
          .fontColor(this.theme_TEXT_PRIMARY)
          .width('100%')

        if (this.settings.enableDirectIp) {
          Text(this.directAccessIp.length > 0 ? this.directAccessIp : this.lt('Detecting local IP'))
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.settings.enableDirectIp) {
        Row() {
          Image($rawfile('info_edit.svg'))
            .width(18)
            .height(18)
            .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_SECONDARY))
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Block)
        .onClick(() => {
          this.directAccessPortDraft = this.directAccessPort;
          this.showDirectAccessPortDialog = true;
        })
      }

      Toggle({ type: ToggleType.Switch, isOn: this.settings.enableDirectIp })
        .selectedColor(this.theme_ACCENT)
        .switchPointColor(this.theme_WHITE)
        .constraintSize({ maxHeight: 32 })
        .onChange((isOn: boolean) => {
          this.handleDirectIpSettingChange(isOn);
        })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })
  }

  @Builder
  private buildSettingsToggleSettingRow(label: string, value: boolean, action: (value: boolean) => void, detail: string = '', showTopBorder: boolean = false, icon: string = '', disabled: boolean = false) {
    Row({ space: ThemeConfig.SPACING_MD }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(20)
          .height(20)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Column({ space: 4 }) {
        Text(label)
          .fontSize(ThemeConfig.FONT_SIZE_XL)
          .fontColor(disabled ? this.theme_TEXT_TERTIARY : this.theme_TEXT_PRIMARY)
          .width('100%')

        if (detail.trim().length > 0) {
          Text(detail)
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.theme_ACCENT)
        .switchPointColor(this.theme_WHITE)
        .constraintSize({ maxHeight: 32 })
        .enabled(!disabled)
        .opacity(disabled ? 0.4 : 1)
        .onChange((isOn: boolean) => {
          action(isOn);
        })
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .constraintSize({ maxHeight: ThemeConfig.MENU_ITEM_HEIGHT })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .onClick(() => {
      if (disabled) {
        void this.showToast(`${label} · ${this.lt('In development')}`);
      }
    })
  }

  @Builder
  private buildSortMenu() {
    Column() {
      Column({ space: 0 }) {
        ForEach([this.lt('Remote ID'), this.lt('Hostname'), this.lt('Username'), this.lt('Status')], (item: string) => {
          Row({ space: 10 }) {
            Stack() {
              Circle()
                .width(20)
                .height(20)
                .fill(Color.Transparent)
                .stroke(this.currentSort === item ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
                .strokeWidth(2)

              if (this.currentSort === item) {
                Circle()
                  .width(12)
                  .height(12)
                  .fill(this.theme_ACCENT)
              }
            }
            .width(20)
            .height(20)

            Text(item)
              .fontSize(16)
              .fontColor(this.currentSort === item ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
              .layoutWeight(1)
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.currentSort = item;
            this.applySortToRecentSessions();
            this.showSortMenu = false;
          })
        }, (item: string) => item)
      }
      .width(160)
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(12)
      .shadow({ radius: 16, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showSortMenu = false;
    })
  }

  @Builder
  private buildConnectTabVisibilityMenu() {
    Column() {
      Column({ space: 0 }) {
        this.buildConnectTabVisibilityRow('recent', this.lt('Recently Visited'))
        this.buildConnectTabVisibilityRow('favorites', this.lt('Favorite'))
        this.buildConnectTabVisibilityRow('discovered', this.lt('Discovered'))
        this.buildConnectTabVisibilityRow('addressBook', this.lt('Address book'))
        this.buildConnectTabVisibilityRow('account', this.lt('Account'))
        this.buildConnectTabVisibilityRow('core', this.lt('Core'))
      }
      .width(200)
      .padding({ top: 8, bottom: 8 })
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(12)
      .shadow({ radius: 16, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showConnectTabVisibilityMenu = false;
    })
  }

  @Builder
  private buildConnectTabVisibilityRow(tab: ConnectPeerTab, label: string) {
    Row() {
      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.visibleConnectTabs.has(tab) ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
          .strokeWidth(2)

        if (this.visibleConnectTabs.has(tab)) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.theme_ACCENT)
        }
      }
      .width(20)
      .height(20)
      .margin({ right: 12 })

      Text(label)
        .fontSize(16)
        .fontColor(this.visibleConnectTabs.has(tab) ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      if (tab === 'recent') {
        return;
      }
      const newTabs = new Set<ConnectPeerTab>(this.visibleConnectTabs);
      if (newTabs.has(tab)) {
        if (newTabs.size > 1) {
          newTabs.delete(tab);
        }
      } else {
        newTabs.add(tab);
      }
      this.visibleConnectTabs = newTabs;
      saveVisibleTabs(newTabs);
      if (!this.visibleConnectTabs.has(this.currentConnectTab)) {
        this.currentConnectTab = Array.from(newTabs)[0];
      }
    })
  }

  @Builder
  private buildBottomTabBar() {
    Row() {
      this.buildFillTabItem('connect', $rawfile('monitor.svg'))
      this.buildFillTabItem('chat', $rawfile('chat.svg'))
      this.buildStrokeTabItem('share', $rawfile('screen.svg'))
      this.buildFillTabItem('settings', $rawfile('settings_gear.svg'))
    }
    .width('100%')
    .height(56)
    .borderRadius(28)
    .backgroundColor(this.themeIsDark ? '#20000000' : '#30FFFFFF')
    .backgroundBlurStyle(BlurStyle.Thin, { colorMode: this.themeIsDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT, adaptiveColor: AdaptiveColor.AVERAGE })
    .border({ width: 1, color: this.themeIsDark ? '#18FFFFFF' : '#28FFFFFF' })
    .shadow({ radius: 8, color: '#18000000', offsetY: 3 })
  }

  @Builder
  private buildFillTabItem(tab: HomeTab, icon: Resource) {
    Column({ space: 3 }) {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(this.currentTab === tab ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
      Text(this.resolveHomeTabLabel(tab))
        .fontSize(11)
        .fontColor(this.currentTab === tab ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .id(`${tab}-bottom-tab-btn`)
    .onClick(() => {
      this.switchHomeTab(tab);
    })
  }

  @Builder
  private buildStrokeTabItem(tab: HomeTab, icon: Resource) {
    Column({ space: 3 }) {
      Stack() {
        Image(icon)
          .width(22)
          .height(22)
          .colorFilter(this.createStrokeIconColorFilter(this.currentTab === tab ? this.theme_ACCENT : this.theme_TEXT_TERTIARY))
        if (tab === 'share' && this.isShareServiceRunning()) {
          Circle()
            .width(8)
            .height(8)
            .fill(this.theme_SUCCESS_TEXT)
            .position({ x: 14, y: 0 })
        }
      }
      .width(22)
      .height(22)
      Text(this.resolveHomeTabLabel(tab))
        .fontSize(11)
        .fontColor(this.currentTab === tab ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4, bottom: 4 })
    .onClick(() => {
      this.switchHomeTab(tab);
    })
  }

  private resolveHomeTabLabel(tab: HomeTab): string {
    if (tab === 'connect') return this.lt('Connect');
    if (tab === 'chat') return this.lt('Chat');
    if (tab === 'share') return this.lt('Share');
    return this.lt('Settings');
  }

  private applySortToRecentSessions(): void {
    const sorted = [...this.recentSessions];
    switch (this.currentSort) {
      case this.lt('Remote ID'):
        sorted.sort((a: RecentSession, b: RecentSession) => a.id.localeCompare(b.id));
        break;
      case this.lt('Hostname'):
        sorted.sort((a: RecentSession, b: RecentSession) => a.name.localeCompare(b.name));
        break;
      case this.lt('Username'):
        sorted.sort((a: RecentSession, b: RecentSession) => a.platform.localeCompare(b.platform));
        break;
      case this.lt('Status'):
        sorted.sort((a: RecentSession, b: RecentSession) => (a.online === b.online ? 0 : a.online ? -1 : 1));
        break;
      default:
        break;
    }
    this.recentSessions = sorted;
  }

  private async refreshState(): Promise<void> {
    if (this.refreshStateBusy) {
      return;
    }
    this.refreshStateBusy = true;
    const previousCoreReady = this.officialCoreState.coreReady;
    const previousServiceEnabled = this.settings.serviceEnabled;
    const previousIncomingReady = this.officialCoreState.incomingReady;
    const previousCaptureActive = this.isNativeScreenCaptureRunning();
    const previousPassword = this.oneTimePassword;
    const previousDisplayId = this.getShareDisplayId();
    try {
      this.settings = this.appData.getSettings();
      this.themeMode = ThemeManager.resolveMode(this.settings.theme);
      this.oneTimePassword = this.appData.getPassword();
      this.officialCoreState = await this.officialBridge.refresh(this.settings);
      AppStorage.setOrCreate<boolean>('coreReady', this.officialCoreState.coreReady);
      this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.appData.getLocalDevice(), this.officialCoreState);
      this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
      if (previousCoreReady !== this.officialCoreState.coreReady || this.currentConnectTab === 'core' || this.showCoreDetailDialog) {
        this.refreshCoreDetailInfo();
      }
      this.syncPendingConnectionUi(this.officialCoreState);
      this.accountState = this.appState.getAccount();
      this.recentSessions = this.appData.getRecentSessions();
      this.refreshAllSessionOnlineStatus();
      this.refreshChatSessions();
      this.refreshCurrentSessionChat(false);
      const incomingStateMismatch = this.settings.serviceEnabled
        ? (!this.officialCoreState.incomingReady || !this.isNativeScreenCaptureRunning())
        : (this.officialCoreState.incomingReady || this.isNativeScreenCaptureRunning());
      if (this.officialCoreState.coreReady && incomingStateMismatch) {
        void this.ensureIncomingServiceEnabled();
      }
      if (previousServiceEnabled !== this.settings.serviceEnabled ||
        previousIncomingReady !== this.officialCoreState.incomingReady ||
        previousCaptureActive !== this.isNativeScreenCaptureRunning() ||
        previousPassword !== this.oneTimePassword ||
        previousDisplayId !== this.getShareDisplayId()) {
        this.shareUiVersion++;
      }
    } finally {
      this.refreshStateBusy = false;
    }
  }

  private refreshChatSessions(): void {
    this.chatSessions = this.chatService.getAllSessions().slice().sort((left: ChatSession, right: ChatSession) => {
      const leftTimestamp = left.lastMessage ? left.lastMessage.timestamp : 0;
      const rightTimestamp = right.lastMessage ? right.lastMessage.timestamp : 0;
      return rightTimestamp - leftTimestamp;
    });
  }

  private resolveCurrentChatPeerId(): string {
    const activePeerId = this.officialCoreState.activePeerId.trim();
    if (activePeerId.length > 0) {
      return activePeerId;
    }
    const lastPeerId = this.lastSessionPeerId.trim();
    if (lastPeerId.length > 0) {
      return lastPeerId;
    }
    return '';
  }

  private refreshCurrentSessionChat(shouldScroll: boolean): void {
    const targetPeerId = this.resolveCurrentChatPeerId();
    if (targetPeerId.length === 0) {
      this.hasHadSession = false;
      this.chatMessages = [];
      return;
    }
    this.hasHadSession = true;
    this.lastSessionPeerId = targetPeerId;
    this.chatMessages = this.chatService.getMessages(targetPeerId);
    if (this.currentTab === 'chat' && this.chatService.getUnreadCount(targetPeerId) > 0) {
      this.chatService.markAsRead(targetPeerId);
    }
    this.refreshChatSessions();
    if (shouldScroll && this.chatMessages.length > 0) {
      this.scheduleChatTabScroll(50);
    }
  }

  private scheduleChatTabScroll(delayMs: number): void {
    [0, delayMs, delayMs + 80, delayMs + 180].forEach((delay: number) => {
      setTimeout(() => {
        this.chatTabScroller.scrollEdge(Edge.Bottom);
      }, Math.max(0, delay));
    });
  }

  private refreshAllSessionOnlineStatus(): void {
    const sessions = this.appData.getRecentSessions();
    const connectedPeerId = this.officialCoreState.sessionStage === 'connected'
      ? this.officialCoreState.activePeerId.trim() : '';
    const now = Date.now();
    sessions.forEach((session: RecentSession) => {
      const online = (connectedPeerId.length > 0 && session.id === connectedPeerId) || this.appData.isPeerOnline(session.id);
      if (online !== session.online) {
        this.appData.updateRecentSessionOnline(session.id, online);
      }
      if (online) {
        this.peerInfoCache.delete(session.id);
      }
      const cached = this.peerInfoCache.get(session.id);
      let peerInfo: PeerInfoCacheEntry;
      if (cached && (now - cached.cachedAt) < Index.PEER_INFO_CACHE_TTL) {
        peerInfo = cached;
      } else {
        const fresh = NativeRustDeskBridge.getPeerInfo(session.id);
        peerInfo = {
          hostname: fresh.hostname,
          username: fresh.username,
          platform: fresh.platform,
          alias: fresh.alias,
          cachedAt: now
        };
        this.peerInfoCache.set(session.id, peerInfo);
      }
      if (peerInfo.hostname.length > 0) {
        this.appData.updateRecentSessionName(session.id, peerInfo.hostname);
      }
      if (peerInfo.platform.length > 0 && (session.platform === 'RustDesk' || session.platform.trim().length === 0)) {
        this.appData.updateRecentSessionPlatform(session.id, peerInfo.platform);
      }
      if (peerInfo.username.length > 0) {
        this.appData.updateRecentSessionUsername(session.id, peerInfo.username);
      }
    });
    this.recentSessions = this.appData.getRecentSessions();
  }

  @Builder
  private buildThemedPlatformIcon(platform: string, size: number) {
    if (this.isFillPlatformIcon(platform)) {
      Image(this.resolvePlatformIcon(platform))
        .width(size)
        .height(size)
        .fillColor(this.theme_ACCENT)
    } else {
      Image(this.resolvePlatformIcon(platform))
        .width(size)
        .height(size)
        .colorFilter(this.createStrokeIconColorFilter(this.theme_ACCENT))
    }
  }

  private isFillPlatformIcon(platform: string): boolean {
    const n = platform.toLowerCase();
    return n.indexOf('android') >= 0 || n.indexOf('harmony') >= 0 || n.indexOf('linux') >= 0 || n.indexOf('ubuntu') >= 0;
  }

  private refreshRecentSessionFromPeerInfo(peerId: string, detail: string = ''): void {
    const normalizedId = DeviceIdFormatter.parse(peerId);
    if (normalizedId.length === 0) {
      return;
    }
    const eventHostname = this.parseFieldFromDetail(detail, 'hostname');
    const eventUsername = this.parseFieldFromDetail(detail, 'username');
    const eventPlatform = this.parseFieldFromDetail(detail, 'platform');
    if (eventHostname.length > 0) {
      this.appData.updateRecentSessionName(normalizedId, eventHostname);
      this.cachedHostname = eventHostname;
    }
    if (eventUsername.length > 0) {
      this.appData.updateRecentSessionUsername(normalizedId, eventUsername);
    }
    if (eventPlatform.length > 0) {
      this.appData.updateRecentSessionPlatform(normalizedId, eventPlatform);
    }
    const peerInfo = NativeRustDeskBridge.getPeerInfo(normalizedId);
    if (peerInfo.hostname.length > 0) {
      this.appData.updateRecentSessionName(normalizedId, peerInfo.hostname);
      this.cachedHostname = peerInfo.hostname;
    }
    if (peerInfo.platform.length > 0) {
      this.appData.updateRecentSessionPlatform(normalizedId, peerInfo.platform);
    }
    if (peerInfo.username.length > 0) {
      this.appData.updateRecentSessionUsername(normalizedId, peerInfo.username);
    }
    this.recentSessions = this.appData.getRecentSessions();
  }

  private formatPeerDisplayName(hostname: string, username: string): string {
    const normalizedHostname = hostname.trim();
    const normalizedUsername = username.trim();
    if (normalizedHostname.length === 0) {
      return normalizedUsername;
    }
    if (normalizedUsername.length === 0 || normalizedHostname.startsWith(`${normalizedUsername}@`)) {
      return normalizedHostname;
    }
    return `${normalizedUsername}@${normalizedHostname}`;
  }

  private startOnlineStatusPoll(): void {
    this.stopOnlineStatusPoll();
    this.onlineStatusPollCount = 0;
    this.onlineStatusPollInterval = 5000;
    this.onlineStatusPollMaxCount = 0;
    this.pollOnlineStatusOnce();
    this.onlineStatusPollTimer = setInterval(() => {
      this.onlineStatusPollCount += 1;
      if (this.onlineStatusPollMaxCount > 0 && this.onlineStatusPollCount >= this.onlineStatusPollMaxCount) {
        this.stopOnlineStatusPoll();
        return;
      }
      this.pollOnlineStatusOnce();
    }, this.onlineStatusPollInterval);
  }

  private stopOnlineStatusPoll(): void {
    if (this.onlineStatusPollTimer !== -1) {
      clearInterval(this.onlineStatusPollTimer);
      this.onlineStatusPollTimer = -1;
    }
  }

  private pollOnlineStatusOnce(): void {
    if (!this.officialCoreState.coreReady) {
      return;
    }
    const idSet = new Set<string>();
    const sessions = this.appData.getRecentSessions();
    sessions.forEach((s: RecentSession) => idSet.add(s.id));
    const addressEntries = this.appData.getAddressBook();
    addressEntries.forEach((e: AddressBookEntry) => idSet.add(e.id));
    const discoveredEntries = this.appData.getDiscoveredDevices();
    discoveredEntries.forEach((e: AddressBookEntry) => idSet.add(e.id));
    const ids = Array.from(idSet);
    if (ids.length === 0) {
      return;
    }
    console.info('[Index] pollOnlineStatusOnce: querying', ids.length, 'ids, coreReady=', this.officialCoreState.coreReady);
    const result = this.officialBridge.queryOnlines(ids);
    console.info('[Index] queryOnlines returned:', result);
  }

  private updateSettings(patch: Partial<SettingsState>): void {
    this.settings = this.appData.updateSettings(patch);
    if (patch.theme !== undefined) {
      ThemeManager.getInstance().applyStoredTheme(this.settings.theme);
      this.themeMode = ThemeManager.resolveMode(this.settings.theme);
      void WindowChromeService.getInstance().refreshSystemBars();
    }
    if (patch.debugKeepScreenAwake !== undefined) {
      this.syncControlledKeepScreenOn();
    }
    if (patch.keepScreenOnWhenControlled !== undefined) {
      this.syncControlledKeepScreenOn();
    }
    this.syncDraftServers();
    this.oneTimePassword = this.appData.getPassword();
    void this.refreshState();
  }

  private handleDirectIpSettingChange(enabled: boolean): void {
    NativeRustDeskBridge.setLocalOption('direct-server', enabled ? 'Y' : 'N');
    this.updateSettings({ enableDirectIp: enabled });
    if (enabled) {
      void this.refreshDirectAccessState();
    }
  }

  private async refreshDirectAccessState(): Promise<void> {
    const configuredPort = NativeRustDeskBridge.getLocalOption('direct-access-port').trim();
    const parsedPort = Number(configuredPort);
    this.directAccessPort = Number.isInteger(parsedPort) && parsedPort >= 1 && parsedPort <= 65535
      ? String(parsedPort)
      : '21118';
    try {
      const netHandle = await connection.getDefaultNet();
      const properties = await connection.getConnectionProperties(netHandle);
      const addresses = properties.linkAddresses
        .map((item: connection.LinkAddress) => item.address)
        .filter((item: connection.NetAddress) => item.address.length > 0 && item.address !== '127.0.0.1' && item.address !== '::1');
      const ipv4 = addresses.find((item: connection.NetAddress) => item.family === 1 || item.address.indexOf(':') < 0);
      const ipv6 = addresses.find((item: connection.NetAddress) => item.family === 2 && !item.address.toLowerCase().startsWith('fe80:'));
      const fallback = addresses.find((item: connection.NetAddress) => item.family === 2);
      this.directAccessIp = ipv4?.address ?? ipv6?.address ?? fallback?.address ?? this.lt('No local IP');
    } catch (error) {
      hilog.warn(0xA03D00, 'NET', 'refreshDirectAccessState failed: %{public}s', String(error));
      this.directAccessIp = this.lt('No local IP');
    }
  }

  private saveDirectAccessPort(): void {
    const port = Number(this.directAccessPortDraft.trim());
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      this.setStatusMessageRaw(this.lt('Port must be between 1 and 65535'));
      return;
    }
    this.directAccessPort = String(port);
    NativeRustDeskBridge.setLocalOption('direct-access-port', this.directAccessPort);
    this.showDirectAccessPortDialog = false;
  }

  private syncDraftServers(): void {
    this.settings = this.appData.getSettings();
    this.draftIdServer = this.settings.idServer;
    this.draftRelayServer = this.settings.relayServer;
    this.draftApiServer = this.settings.apiServer;
    this.draftKey = this.settings.key;
  }

  private hasUnsavedServerChanges(): boolean {
    return this.draftIdServer.trim() !== this.settings.idServer.trim() ||
      this.draftRelayServer.trim() !== this.settings.relayServer.trim() ||
      this.draftApiServer.trim() !== this.settings.apiServer.trim() ||
      this.draftKey.trim() !== this.settings.key.trim();
  }

  private async applyDraftServers(): Promise<void> {
    this.settings = this.appData.updateSettings({
      idServer: this.draftIdServer.trim(),
      relayServer: this.draftRelayServer.trim(),
      apiServer: this.draftApiServer.trim(),
      key: this.draftKey.trim()
    });
    NativeRustDeskBridge.setLocalOption('key', this.settings.key.trim());
    this.syncDraftServers();
    this.setStatusMessage("server_updated");
    void this.refreshState();
  }

  private applyPublicServerPreset(): void {
    this.draftIdServer = '';
    this.draftRelayServer = '';
    this.draftApiServer = '';
    this.draftKey = '';
  }

  private applySelfHostedPreset(): void {
    this.draftIdServer = 'hbbs.example.com';
    this.draftRelayServer = 'hbbr.example.com';
    this.draftApiServer = '';
    this.draftKey = '';
  }

  private applyDirectConnectPreset(): void {
    this.draftIdServer = '';
    this.draftRelayServer = '';
    this.draftApiServer = '';
    this.draftKey = '';
  }

  private async exportServerConfig(): Promise<void> {
    const settings = this.appData.getSettings();
    const encoded = ServerConfigCodec.encode(settings);
    const success = await this.clipboardService.copyText(encoded);
    if (success) {
      this.setStatusMessage('server_config_copied');
      await this.showToast(this.lt('server_config_copied'));
    }
  }

  private syncControlledKeepScreenOn(): void {
    const keepAwake = this.settings.debugKeepScreenAwake ||
      (this.settings.keepScreenOnWhenControlled && this.settings.serviceEnabled);
    void WindowChromeService.getInstance().setKeepScreenOn(keepAwake);
  }

  private async importServerConfig(): Promise<void> {
    const raw = await this.clipboardService.getClipboardContent();
    if (!raw || raw.trim().length === 0) {
      return;
    }
    const config: ServerConfigImportResult | null = ServerConfigCodec.decode(raw);
    if (config === null) {
      this.setStatusMessage('invalid_server_config');
      await this.showToast(this.lt('invalid_server_config'));
      return;
    }
    const currentSettings = this.appData.getSettings();
    this.settings = this.appData.updateSettings({
      idServer: config.idServer !== null ? config.idServer : currentSettings.idServer,
      relayServer: config.relayServer !== null ? config.relayServer : currentSettings.relayServer,
      apiServer: config.apiServer !== null ? config.apiServer : currentSettings.apiServer,
      key: config.key !== null ? config.key : currentSettings.key
    });
    NativeRustDeskBridge.setLocalOption('key', this.settings.key.trim());
    this.syncDraftServers();
    this.setStatusMessage('server_config_imported');
    await this.showToast(this.lt('server_config_imported'));
  }

  private startRefreshLoop(): void {
    if (this.refreshTimer !== -1) {
      return;
    }
    this.refreshTimer = setInterval(() => {
      void this.refreshState();
    }, 1000);
  }

  private stopRefreshLoop(): void {
    if (this.refreshTimer === -1) {
      return;
    }
    clearInterval(this.refreshTimer);
    this.refreshTimer = -1;
  }

  private async sleep(ms: number): Promise<void> {
    await new Promise<void>(resolve => setTimeout(resolve, ms));
  }

  private async resetPendingConnectionState(clearPeerId: boolean, nextStatusMessage?: string): Promise<void> {
    this.pendingConnectionMonitorId += 1;
    this.showPasswordDialog = false;
    this.pendingPassword = '';
    this.pendingPasswordDialogProactive = false;
    this.autoSubmittedSavedPasswordPeerId = '';
    this.isConnecting = false;
    this.pendingConnectionInactivePollCount = 0;
    if (clearPeerId) {
      this.pendingPeerId = '';
      this.pendingTransportTarget = '';
      this.pendingConnectionRetryCount = 0;
    }
    this.officialCoreState = this.officialBridge.requestSessionClose();
    if (nextStatusMessage && nextStatusMessage.trim().length > 0) {
      this.setStatusMessageRaw(nextStatusMessage ?? "");
    }
    await this.sleep(180);
  }

  private resetConnectionUiAfterTerminalEvent(finalStatusMessage: string = ''): void {
    this.pendingConnectionMonitorId += 1;
    this.pendingConnectionRetryCount = 0;
    this.pendingConnectionInactivePollCount = 0;
    this.pendingPeerId = '';
    this.pendingTransportTarget = '';
    this.pendingPassword = '';
    this.pendingPasswordDialogProactive = false;
    this.autoSubmittedSavedPasswordPeerId = '';
    this.showPasswordDialog = false;
    this.rememberPassword = false;
    this.isConnecting = false;
    if (finalStatusMessage.trim().length > 0) {
      this.setStatusMessageRaw(finalStatusMessage);
    } else {
      this.clearStatusMessage();
    }
    this.refreshCurrentSessionChat(false);
  }

  private async cancelPendingConnection(): Promise<void> {
    await this.resetPendingConnectionState(true, this.lt('Connection request cancelled.'));
  }

  private isPendingConnectionAlive(coreState: OfficialCoreState, peerId: string): boolean {
    if (coreState.sessionStage === 'connected') {
      return true;
    }
    const activePeerId = coreState.activePeerId.trim();
    if (activePeerId.length > 0 && activePeerId !== peerId) {
      return false;
    }
    if (coreState.sessionStage === 'connecting') {
      return true;
    }
    if (this.isConnecting && this.pendingPeerId.trim() === peerId) {
      return true;
    }
    const promptSource = `${coreState.statusSummary}\n${coreState.detailMessage}\n${coreState.lastError}`;
    return this.shouldPromptForPassword(promptSource);
  }

  private async restartPendingBackgroundConnection(peerId: string, statusMessage: string): Promise<void> {
    await this.resetPendingConnectionState(false);
    this.pendingPeerId = peerId;
    this.pendingTransportTarget = this.resolveConnectionTransportTarget(peerId);
    this.setStatusMessageRaw(statusMessage);
    void this.initiateBackgroundConnection(this.pendingTransportTarget, peerId);
    void this.monitorConnectionWhileWaiting();
  }

  private async handleConnect(overrideTargetId?: string): Promise<void> {
    this.cachedHostname = '';
    const targetId = this.sanitizeConnectionTargetInput(overrideTargetId ?? this.deviceId);
    if (targetId.length === 0) {
      this.setStatusMessage("enter_id");
      return;
    }
    if (!this.isValidConnectionTarget(targetId)) {
      this.setStatusMessage("id_incorrect");
      return;
    }

    this.selectLatestChatPeer(targetId);
    let coreState = await this.officialBridge.refresh(this.settings);
    this.officialCoreState = coreState;
    if (!coreState.coreReady) {
      this.setStatusMessage("core_not_ready");
      console.error('Core not ready:', JSON.stringify(coreState));
      return;
    }

    const hasExistingRequest = this.pendingPeerId.trim().length > 0 ||
      coreState.activePeerId.trim().length > 0 ||
      coreState.sessionStage === 'connecting' ||
      coreState.sessionStage === 'connected' ||
      coreState.sessionStage === 'error';
    if (hasExistingRequest) {
      await this.resetPendingConnectionState(true);
      coreState = await this.officialBridge.refresh(this.settings);
      this.officialCoreState = coreState;
    }
    this.officialBridge.resetCloseRequestedFlag();

    this.pendingConnectionMonitorId += 1;
    this.pendingConnectionRetryCount = 0;
    this.pendingConnectionInactivePollCount = 0;
    this.pendingPeerId = targetId;
    const forceRelay = PreferenceStore.getPeerConnectMode(targetId) === 'relay';
    this.pendingTransportTarget = forceRelay ? targetId : this.resolveConnectionTransportTarget(targetId);
    NativeRustDeskBridge.mainSetPeerOption(
      this.pendingTransportTarget,
      'force-always-relay',
      forceRelay ? 'Y' : 'N'
    );
    this.autoSubmittedSavedPasswordPeerId = '';
    const savedPassword: string = PreferenceStore.getPeerPassword(targetId) ?? '';
    if (savedPassword.trim().length > 0) {
      this.pendingPassword = savedPassword.trim();
      this.showPasswordDialog = false;
      this.setStatusMessage("connecting_saved", targetId);
      await this.handleConnectWithPassword(targetId, savedPassword.trim());
      return;
    }

    this.clearNativePeerPassword(targetId, this.pendingTransportTarget);

    hilog.info(0xA03D00, 'CONN', `[handleConnect] parallel: no saved password for ${targetId}, showing password dialog + empty-password connect`);
    this.showConnectPasswordDialog(targetId, true);
    void this.initiateBackgroundConnection(this.pendingTransportTarget, targetId);
  }

  private resolveConnectionTransportTarget(peerId: string): string {
    if (!this.settings.enableDirectIp || !this.isNumericConnectionTarget(peerId)) {
      return peerId;
    }
    const directAddress = LanDiscoveryService.getInstance().getDirectAddress(peerId).trim();
    return directAddress.length > 0 ? directAddress : peerId;
  }

  private clearNativePeerPassword(peerId: string, transportTarget: string = ''): void {
    const normalizedPeerId = peerId.trim();
    const normalizedTransportTarget = transportTarget.trim();
    if (normalizedPeerId.length > 0) {
      NativeRustDeskBridge.mainForgetPassword(normalizedPeerId);
    }
    if (normalizedTransportTarget.length > 0 && normalizedTransportTarget !== normalizedPeerId) {
      NativeRustDeskBridge.mainForgetPassword(normalizedTransportTarget);
    }
  }

  private async initiateBackgroundConnection(
    transportTarget: string,
    displayPeerId: string = transportTarget,
    password: string = ''
  ): Promise<boolean> {
    try {
      await this.officialBridge.connectToPeer(transportTarget, password, this.settings, displayPeerId);
      this.officialCoreState = this.officialBridge.getCoreState();
      console.info('[Connect] Background connectToPeer completed');
      return true;
    } catch (error) {
      console.error('[Connect] Background connection error:', error);
      const nextState = await this.officialBridge.refresh(this.settings);
      this.officialCoreState = nextState;
      const errMsg = nextState.lastError || nextState.detailMessage;
      if (errMsg.length > 0) {
        this.setStatusMessageRaw(errMsg);
      } else if (error instanceof Error) {
        this.setStatusMessageRaw(error.message);
      } else {
        this.setStatusMessage("connection_failed");
      }
      return false;
    }
  }

  private requestShareServiceStart(): void {
    const warningDisabled = NativeRustDeskBridge.getLocalOption('show-scam-warning').trim().toUpperCase() === 'N';
    if (this.accountState.isLoggedIn || warningDisabled) {
      void this.checkScreenCapturePermissionAndToggle();
      return;
    }
    this.closeShareStartWarning();
    this.shareWarningDontShowAgain = false;
    this.shareWarningCountdown = 12;
    this.showShareStartWarning = true;
    this.shareWarningTimer = setInterval(() => {
      if (this.shareWarningCountdown <= 1) {
        this.shareWarningCountdown = 0;
        if (this.shareWarningTimer !== -1) {
          clearInterval(this.shareWarningTimer);
          this.shareWarningTimer = -1;
        }
        return;
      }
      this.shareWarningCountdown--;
    }, 1000);
  }

  private closeShareStartWarning(): void {
    if (this.shareWarningTimer !== -1) {
      clearInterval(this.shareWarningTimer);
      this.shareWarningTimer = -1;
    }
    this.showShareStartWarning = false;
  }

  private confirmShareServiceStart(): void {
    if (this.shareWarningCountdown > 0) {
      return;
    }
    if (this.shareWarningDontShowAgain) {
      NativeRustDeskBridge.setLocalOption('show-scam-warning', 'N');
    }
    this.closeShareStartWarning();
    void this.checkScreenCapturePermissionAndToggle();
  }

  private async checkScreenCapturePermissionAndToggle(): Promise<void> {
    hilog.info(0xA03D00, 'SHARE', 'checkScreenCapturePermissionAndToggle: start without screen capture pre-request');
    try {
      await this.toggleIncomingService(true);
    } catch (error) {
      hilog.warn(0xA03D00, 'SHARE', 'toggleIncomingService failed: %{public}s', String(error));
      this.settings = this.appData.updateSettings({ serviceEnabled: false, allowRemoteControl: false });
      this.syncControlledKeepScreenOn();
      this.localDevice = this.appData.setServiceEnabled(false);
    }
  }

  private async checkAudioPermissionAndToggle(): Promise<void> {
    const results = await PermissionService.getInstance().requestPermissions([
      'ohos.permission.MICROPHONE' as Permissions
    ]);
    if (!results.every((item) => item.status === PermissionStatus.GRANTED)) {
      this.updateSettings({ enableAudio: false });
      this.setStatusMessageRaw(this.lt('Mic permission denied'));
      return;
    }
  }

  private async checkClipboardPermissionAndToggle(): Promise<void> {
    const results = await PermissionService.getInstance().requestPermissions([
      'ohos.permission.READ_PASTEBOARD' as Permissions
    ]);
    if (!results.every((item) => item.status === PermissionStatus.GRANTED)) {
      this.updateSettings({ allowClipboard: false, enableClipboard: false });
      this.setStatusMessageRaw(this.lt('Clipboard denied'));
      return;
    }
  }

  private async toggleFloatingWindowSetting(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.updateSettings({ enableFloatingWindow: false });
      return;
    }

    const status = await PermissionService.getInstance().requestPermission('ohos.permission.SYSTEM_FLOAT_WINDOW' as Permissions);
    if (status !== PermissionStatus.GRANTED) {
      this.updateSettings({ enableFloatingWindow: false });
      this.setStatusMessageRaw(this.lt('Float window denied'));
      return;
    }

    this.updateSettings({ enableFloatingWindow: true });
  }

  private async toggleIncomingService(enabled: boolean): Promise<void> {
    if (this.incomingServiceActionBusy) {
      return;
    }
    this.incomingServiceActionBusy = true;
    try {
      await this.performToggleIncomingService(enabled);
    } finally {
      this.incomingServiceActionBusy = false;
    }
  }

  private async performToggleIncomingService(enabled: boolean): Promise<void> {
    hilog.info(0xA03D00, 'SHARE', 'toggleIncomingService: enabled=%{public}s', String(enabled));
    if (!enabled) {
      ScreenCaptureService.getInstance().stopCapture();
      NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'N');
      NativeRustDeskBridge.setLocalOption('direct-server', 'N');
      this.settings = this.appData.updateSettings({
        serviceEnabled: false,
        allowRemoteControl: false
      });
      NativeRustDeskBridge.setInputInjectionEnabled(false);
      this.syncControlledKeepScreenOn();
      this.localDevice = this.appData.setServiceEnabled(false);
      this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(false, this.settings);
      this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.localDevice, this.officialCoreState);
      this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
      this.setStatusMessage("share_stopped");
      this.shareUiVersion++;
      setTimeout(() => {
        void this.refreshState();
      }, 300);
      return;
    }

    const permissionsGranted = await this.requestSharePermissions();
    if (!permissionsGranted) {
      this.setStatusMessageRaw(this.lt('Screen capture denied'));
      return;
    }

    NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'Y');
    NativeRustDeskBridge.setLocalOption('direct-server', this.settings.enableDirectIp ? 'Y' : 'N');
    this.settings = this.appData.updateSettings({
      serviceEnabled: true,
      allowRemoteControl: false
    });
    NativeRustDeskBridge.setInputInjectionEnabled(false);
    this.syncControlledKeepScreenOn();
    this.localDevice = this.appData.setServiceEnabled(true);
    this.syncSharePasswordToNative(this.appData.getPassword());
    this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(true, this.settings);
    hilog.info(0xA03D00, 'SHARE', 'setIncomingServiceEnabled result: coreReady=%{public}s', String(this.officialCoreState.coreReady));
    try {
      if (!this.isNativeScreenCaptureRunning()) {
        await ScreenCaptureService.getInstance().startCapture();
      }
      hilog.info(0xA03D00, 'SHARE', 'startCapture succeeded for linked incoming service');
      await this.sleep(260);
      this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(true, this.settings);
      await this.sleep(180);
      this.officialCoreState = await this.officialBridge.refresh(this.settings);
    } catch (error) {
      ScreenCaptureService.getInstance().stopCapture();
      NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'N');
      NativeRustDeskBridge.setLocalOption('direct-server', 'N');
      this.settings = this.appData.updateSettings({
        serviceEnabled: false,
        allowRemoteControl: false
      });
      this.syncControlledKeepScreenOn();
      this.localDevice = this.appData.setServiceEnabled(false);
      this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(false, this.settings);
      hilog.warn(0xA03D00, 'SHARE', 'startCapture failed: %{public}s', String(error));
      this.setStatusMessageRaw(this.lt('Recording not started'));
      this.shareUiVersion++;
      throw new Error(String(error));
    }
    this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.localDevice, this.officialCoreState);
    this.oneTimePassword = this.appData.getPassword();
    this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
    if (this.isNativeScreenCaptureRunning() && !this.officialCoreState.incomingReady) {
      this.setStatusMessageRaw(this.lt('Recording waiting'));
    } else {
      this.setStatusMessage("share_requested");
    }
    this.shareUiVersion++;
    setTimeout(() => {
      void this.refreshState();
    }, 500);
  }

  private async requestSharePermissions(): Promise<boolean> {
    const permissionService = PermissionService.getInstance();
    const sharePermissions: Permissions[] = [
      'ohos.permission.KEEP_BACKGROUND_RUNNING',
      'ohos.permission.READ_LOCAL_DEVICE_NAME'
    ];
    const results = await permissionService.requestPermissions(sharePermissions);
    const backgroundResult = results.find((item) => item.permission === 'ohos.permission.KEEP_BACKGROUND_RUNNING');
    return backgroundResult !== undefined && backgroundResult.status === PermissionStatus.GRANTED;
  }

  private async checkFileTransferPermissionAndToggle(enabled: boolean): Promise<void> {
    const granted = await PermissionService.getInstance().requestFileAccessAuthorization();
    if (!granted) {
      this.settings = this.appData.updateSettings({ allowFileTransfer: false });
      this.setStatusMessageRaw(this.lt('File access denied'));
      return;
    }
    this.updateSettings({ allowFileTransfer: true });
  }

  private async toggleFileTransferCapability(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.updateSettings({ allowFileTransfer: false });
      return;
    }
    const granted = await this.requestFileTransferPermissions();
    if (!granted) {
      this.settings = this.appData.updateSettings({ allowFileTransfer: false });
      this.setStatusMessageRaw(this.lt('File access denied'));
      return;
    }
    this.updateSettings({ allowFileTransfer: true });
  }

  private async requestFileTransferPermissions(): Promise<boolean> {
    return PermissionService.getInstance().requestFileAccessAuthorization();
  }

  private async generateSharePassword(): Promise<void> {
    const newPassword = this.appData.generatePassword();
    this.oneTimePassword = newPassword;
    this.shareUiVersion++;
    this.syncSharePasswordToNative(newPassword);
    this.setStatusMessageRaw(this.lt('Pwd updated'));
    if (this.settings.serviceEnabled) {
      this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(true, this.settings);
    }
    this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.appData.getLocalDevice(), this.officialCoreState);
    this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
    this.addressBookVersion++;
    setTimeout(() => {
      void this.refreshState();
    }, 250);
  }

  private syncSharePasswordToNative(password: string): void {
    const normalizedPassword = password.trim();
    if (normalizedPassword.length === 0) {
      return;
    }
    NativeRustDeskBridge.setLocalOption('verification-method', 'use-temporary-password');
    NativeRustDeskBridge.setLocalOption('approve-mode', 'password');
    NativeRustDeskBridge.setLocalOption('temporary-password', normalizedPassword);
  }

  private async syncAddressBookFromServer(showToast: boolean = false): Promise<void> {
    this.refreshAccountState();
    if (!this.accountState.isLoggedIn) {
      return;
    }
    await this.accountService.fetchAddressBook();
    this.recentSessions = this.appData.getRecentSessions();
    this.addressBookVersion++;
    this.peerOnlineVersion++;
    if (showToast) {
      try {
        await this.getUIContext().getPromptAction().openToast({
          message: this.lt('Address book synced')
        });
      } catch (_e) {}
    }
  }

  private async refreshCurrentConnectTab(): Promise<void> {
    this.isConnectTabRefreshing = true;
    this.connectTabRefreshAngle = 0;
    this.connectTabRefreshTimer = setInterval(() => {
      this.connectTabRefreshAngle = (this.connectTabRefreshAngle + 18) % 360;
    }, 40);
    try {
      if (this.currentConnectTab === 'discovered') {
        if (this.settings.denyLanDiscovery) {
          this.settings = this.appData.updateSettings({ denyLanDiscovery: false });
        }
        LanDiscoveryService.getInstance().refreshNow();
        this.discoveredVersion++;
        this.peerOnlineVersion++;
        setTimeout(() => {
          this.discoveredVersion++;
          this.peerOnlineVersion++;
        }, 2500);
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 2600);
        });
        return;
      }
      if (this.currentConnectTab === 'addressBook') {
        await this.syncAddressBookFromServer(true);
        await this.refreshState();
        return;
      }
      await this.refreshState();
      this.addressBookVersion++;
    } finally {
      if (this.connectTabRefreshTimer !== -1) {
        clearInterval(this.connectTabRefreshTimer);
        this.connectTabRefreshTimer = -1;
      }
      this.connectTabRefreshAngle = 0;
      this.isConnectTabRefreshing = false;
    }
  }

  private async ensureIncomingServiceEnabled(): Promise<void> {
    if (!this.officialCoreState.coreReady || this.incomingServiceRestoreBusy || this.incomingServiceActionBusy) {
      return;
    }
    this.incomingServiceRestoreBusy = true;
    try {
      if (this.settings.serviceEnabled) {
        NativeRustDeskBridge.setLocalOption('direct-server', this.settings.enableDirectIp ? 'Y' : 'N');
        NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'Y');
        if (this.officialCoreState.incomingReady && this.isNativeScreenCaptureRunning()) {
          return;
        }
        if (!this.isNativeScreenCaptureRunning()) {
          await ScreenCaptureService.getInstance().startCapture();
          await this.sleep(260);
        }
        this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(true, this.settings);
        await this.sleep(180);
        this.officialCoreState = await this.officialBridge.refresh(this.settings);
        this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.appData.getLocalDevice(), this.officialCoreState);
        this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
        this.shareUiVersion++;
        return;
      }
      if (this.officialCoreState.incomingReady || this.isNativeScreenCaptureRunning()) {
        ScreenCaptureService.getInstance().stopCapture();
        NativeRustDeskBridge.setLocalOption('enable-screen-capture', 'N');
        NativeRustDeskBridge.setLocalOption('direct-server', 'N');
        this.localDevice = this.appData.setServiceEnabled(false);
        this.settings = this.appData.updateSettings({ serviceEnabled: false, allowRemoteControl: false });
        NativeRustDeskBridge.setInputInjectionEnabled(false);
        this.syncControlledKeepScreenOn();
        this.officialCoreState = await this.officialBridge.setIncomingServiceEnabled(false, this.settings);
        this.localDevice = this.officialBridge.buildLocalDeviceProfile(this.localDevice, this.officialCoreState);
        this.oneTimePassword = this.appData.getPassword();
        this.nativeBridgeSummary = NativeRustDeskBridge.getRuntimeLogSummary();
        this.setStatusMessage("share_stopped");
        this.shareUiVersion++;
        setTimeout(() => {
          this.addressBookVersion++;
          void this.refreshState();
        }, 300);
      }
    } catch (error) {
      hilog.warn(0xA03D00, 'SHARE', 'restore incoming service failed: %{public}s', String(error));
    } finally {
      this.incomingServiceRestoreBusy = false;
    }
  }

  private async copyText(value: string, message: string): Promise<void> {
    if (value.trim().length === 0) {
      return;
    }
    const success = await this.clipboardService.copyText(value);
    await this.showToast(success ? message : this.lt('Copy failed'));
  }

  private async showToast(message: string): Promise<void> {
    try {
      await this.getUIContext().getPromptAction().openToast({
        message
      });
    } catch (error) {
      console.error('toast failed', JSON.stringify(error));
    }
  }

  private async handlePasswordLoginInDialog(): Promise<void> {
    this.loginErrorMsg = '';
    const result = await this.accountService.loginWithPassword(this.loginUsername, this.loginPassword);
    this.accountState = this.appState.getAccount();
    if (result.success && this.accountState.isLoggedIn) {
      this.showAccountDialog = false;
      this.loginUsername = '';
      this.loginPassword = '';
      this.addressBookVersion++;
      this.discoveredVersion++;
      await this.syncAddressBookFromServer(false);
      try {
        await this.getUIContext().getPromptAction().openToast({
          message: this.lt('Login successful')
        });
      } catch (e) {}
    } else if (result.emailCheck) {
      this.loginErrorMsg = this.lt('Email verification required');
    } else if (result.tfaCheck) {
      this.loginErrorMsg = this.lt('Two-factor authentication required');
    } else {
      this.loginErrorMsg = this.lt('Login failed, please check username and password');
    }
  }

  private async handleOAuthLoginInDialog(provider: string): Promise<void> {
    this.loginErrorMsg = '';
    const success = await this.accountService.loginWithOAuth(provider);
    this.accountState = this.appState.getAccount();
    if (!success) {
      this.loginErrorMsg = this.accountState.lastError ?? this.lt('Login failed');
    } else if (this.accountState.status === 'waiting') {
      this.showAccountDialog = true;
      this.startOAuthPollingFromService();
    } else if (this.accountState.isLoggedIn) {
      this.showAccountDialog = false;
    }
  }

  private oauthCheckTimer: number = -1;

  private startOAuthPollingFromService(): void {
    if (this.oauthCheckTimer !== -1) {
      clearInterval(this.oauthCheckTimer);
    }
    this.oauthCheckTimer = setInterval(() => {
      this.refreshAccountState();
      if (this.accountState.isLoggedIn) {
        clearInterval(this.oauthCheckTimer);
        this.oauthCheckTimer = -1;
        this.showAccountDialog = false;
        this.loginErrorMsg = '';
        void this.syncAddressBookFromServer(false);
      } else if (this.accountState.status === 'error') {
        clearInterval(this.oauthCheckTimer);
        this.oauthCheckTimer = -1;
        this.loginErrorMsg = this.accountState.lastError ?? this.lt('Login failed');
      }
    }, 500);
  }

  private openExternalUrl(url: string): void {
    try {
      void this.getUIContext().getRouter().pushUrl({ url });
    } catch (e) {}
  }

  private cancelGithubLogin(): void {
    if (this.oauthCheckTimer !== -1) {
      clearInterval(this.oauthCheckTimer);
      this.oauthCheckTimer = -1;
    }
    this.accountService.cancelLogin();
    this.accountState = this.appState.getAccount();
    this.showAccountDialog = false;
    this.loginErrorMsg = '';
  }

  private signOutAccount(): void {
    void this.accountService.logout().then(() => {
      this.refreshAccountState();
      void this.refreshState();
    });
  }

  private refreshAccountState(): void {
    const fresh = this.appState.getAccount();
    this.accountState = {
      isLoggedIn: fresh.isLoggedIn,
      username: fresh.username,
      displayName: fresh.displayName,
      avatar: fresh.avatar,
      accessToken: fresh.accessToken,
      provider: fresh.provider,
      detail: fresh.detail,
      loginUrl: fresh.loginUrl,
      lastError: fresh.lastError,
      status: fresh.status
    };
    this.accountRefreshTick++;
  }

  private isFavorite(id: string): boolean {
    return this.appData.isFavorite(id);
  }

  private isInAddressBook(id: string): boolean {
    return this.appData.getAddressBookEntry(id) !== undefined;
  }

  private async deleteRecentTargetById(peerId: string): Promise<void> {
    this.swipedRecentTargetId = '';
    this.appData.removeRecentSession(peerId);
    PreferenceStore.setPeerPassword(peerId, '');
    this.recentSessions = this.appData.getRecentSessions();
    if (this.deviceId === peerId) {
      this.deviceId = '';
      this.deviceIdDisplay = '';
      this.deviceIdInputKey++;
    }
    try {
      await this.getUIContext().getPromptAction().openToast({
        message: this.lt('Recent target deleted')
      });
    } catch (error) {
      console.error('toast failed', JSON.stringify(error));
    }
  }

  private async clearRecentTargetPasswordById(peerId: string): Promise<void> {
    this.swipedRecentTargetId = '';
    PreferenceStore.setPeerPassword(peerId, '');
    this.clearNativePeerPassword(peerId, this.resolveConnectionTransportTarget(peerId));
    try {
      await this.getUIContext().getPromptAction().openToast({
        message: this.lt('Saved password deleted')
      });
    } catch (error) {
      console.error('toast failed', JSON.stringify(error));
    }
  }

  private isAccountBusy(): boolean {
    return this.accountState.status === 'requesting' || this.accountState.status === 'waiting';
  }

  private shouldShowPublicLoginBanner(): boolean {
    return this.isUsingPublicServer() && !this.accountState.isLoggedIn;
  }

  private isUsingPublicServer(): boolean {
    return AppDataService.isUsingOfficialServer(this.settings);
  }

  private describeServerSummary(): string {
    return this.isUsingPublicServer() ? this.lt('Official default') : this.lt('Custom / self-hosted server');
  }

  private describeEffectiveServer(): string {
    const stateServer = this.officialCoreState.server.trim();
    if (stateServer.length > 0 && stateServer.toLowerCase() !== AppDataService.OFFICIAL_ID_SERVER) {
      return stateServer;
    }
    const effective = AppDataService.resolveServerConfig(this.settings);
    return effective.idServer.toLowerCase() === AppDataService.OFFICIAL_ID_SERVER ? this.lt('Official default') : effective.idServer;
  }

  private resolveBridgeStageBadge(): string {
    if (this.officialCoreState.sessionStage === 'connected') {
      return this.lt('Connected');
    }
    if (this.officialCoreState.sessionStage === 'connecting') {
      return this.lt('Connecting');
    }
    if (this.officialCoreState.sessionStage === 'error') {
      return this.lt('Error');
    }
    return this.officialCoreState.coreReady ? this.lt('Ready') : this.lt('Idle');
  }

  private resolveBridgeStageActive(): boolean {
    return this.officialCoreState.sessionStage !== 'error';
  }

  private resolveConnectPeerTabIconColor(tab: ConnectPeerTab): string {
    if (this.currentConnectTab === tab) {
      return this.theme_ACCENT;
    }
    return this.themeIsDark ? '#AAB2C5' : '#7E879A';
  }

  private resolveConnectPeerTabIconResource(tab: ConnectPeerTab): Resource {
    const isSelected = this.currentConnectTab === tab;
    
    if (tab === 'recent') {
      return $rawfile(isSelected ? 'history_filled.svg' : 'history.svg');
    }
    if (tab === 'favorites') {
      return $rawfile(isSelected ? 'star_filled.svg' : 'star.svg');
    }
    if (tab === 'discovered') {
      return $rawfile(isSelected ? 'explore_filled.svg' : 'explore.svg');
    }
    if (tab === 'addressBook') {
      return $rawfile(isSelected ? 'address_book_filled.svg' : 'address_book.svg');
    }
    if (tab === 'account') {
      return $rawfile(isSelected ? 'device_group_filled.svg' : 'device_group.svg');
    }
    return $rawfile(isSelected ? 'secure_filled.svg' : 'secure.svg');
  }

  private resolvePlatformForDevice(deviceId: string, fallback: string): string {
    for (let i = 0; i < this.recentSessions.length; i++) {
      if (this.recentSessions[i].id === deviceId) {
        return this.recentSessions[i].platform;
      }
    }
    return fallback;
  }

  private resolvePlatformIcon(text: string): Resource {
    const normalized = text.toLowerCase();
    if (normalized.indexOf('android') >= 0) {
      return $rawfile('android.svg');
    }
    if (normalized.indexOf('harmony') >= 0) {
      return $rawfile('android.svg');
    }
    if (normalized.indexOf('mac') >= 0 || normalized.indexOf('ios') >= 0) {
      return $rawfile('mac.svg');
    }
    if (normalized.indexOf('linux') >= 0 || normalized.indexOf('ubuntu') >= 0) {
      return $rawfile('linux.svg');
    }
    if (normalized.indexOf('windows') >= 0) {
      return $rawfile('win.svg');
    }
    return $rawfile('win.svg');
  }

  private resolveLocalToggleOption(key: string): boolean {
    this.settingsOptionVersion;
    const value = NativeRustDeskBridge.getLocalOption(key).trim().toUpperCase();
    if (value.length > 0) {
      return value === 'Y' || value === 'YES' || value === 'TRUE' || value === '1';
    }
    return NativeRustDeskBridge.getSessionToggleOption(key);
  }

  private applySessionAndLocalOption(key: string, value: string): void {
    NativeRustDeskBridge.applySessionOption(key, value);
    NativeRustDeskBridge.setLocalOption(key, value);
    this.settingsOptionVersion++;
  }

  private applySessionAndLocalToggleOption(key: string, enabled: boolean): void {
    this.applySessionAndLocalOption(key, enabled ? 'Y' : 'N');
  }

  private resolveImageQualityMode(): string {
    this.settingsOptionVersion;
    const value = NativeRustDeskBridge.getLocalOption('image-quality').trim();
    if (value === 'best' || value === 'balanced' || value === 'low' || value === 'custom') {
      return value;
    }
    if (value === 'speed') {
      return 'low';
    }
    return this.settings.quality >= 90 ? 'best' : (this.settings.quality <= 50 ? 'low' : 'balanced');
  }

  private describeImageQualityMode(): string {
    const mode = this.resolveImageQualityMode();
    if (mode === 'best') return this.lt('Best Quality');
    if (mode === 'low') return this.lt('Best Speed');
    if (mode === 'custom') return this.lt('Custom');
    return this.lt('Balanced');
  }

  private applyImageQualityMode(mode: string): void {
    this.applySessionAndLocalOption('image-quality', mode);
    if (mode === 'best') {
      this.settings = this.appData.updateSettings({ quality: 100 });
    } else if (mode === 'low') {
      this.settings = this.appData.updateSettings({ quality: 40 });
    } else if (mode === 'balanced') {
      this.settings = this.appData.updateSettings({ quality: 80 });
    }
    if (mode === 'custom') {
      const customQuality = NativeRustDeskBridge.getLocalOption('custom-image-quality').trim();
      if (customQuality.length === 0) {
        this.applySessionAndLocalOption('custom-image-quality', String(this.settings.quality));
      }
      const customFps = NativeRustDeskBridge.getLocalOption('custom-fps').trim();
      if (customFps.length === 0) {
        this.applySessionAndLocalOption('custom-fps', '30');
      }
    }
  }

  private resolveDefaultDisplayScaleMode(): number {
    this.settingsOptionVersion;
    const value = NativeRustDeskBridge.getLocalOption('display-scale-mode').trim();
    const modeMap: Record<string, number> = { 'original': 0, 'fit': 1, 'custom': 2 };
    return modeMap[value] ?? 1;
  }

  private describeDefaultDisplayScaleMode(): string {
    const mode = this.resolveDefaultDisplayScaleMode();
    if (mode === 0) return this.lt('Original Size');
    if (mode === 2) return this.lt('Custom Zoom');
    return this.lt('Fit Window');
  }

  private applyDefaultDisplayScaleMode(mode: number): void {
    const modeValues: Record<number, string> = { 0: 'original', 1: 'fit', 2: 'custom' };
    NativeRustDeskBridge.setLocalOption('display-scale-mode', modeValues[mode] ?? 'fit');
    this.settingsOptionVersion++;
  }

  private resolveDefaultCustomZoomPercent(): number {
    this.settingsOptionVersion;
    const value = Number(NativeRustDeskBridge.getLocalOption('custom-zoom-percent'));
    return Number.isFinite(value) && value >= 100 && value <= 600 ? Math.round(value) : 160;
  }

  private resolveDefaultCodecMode(): number {
    this.settingsOptionVersion;
    const value = NativeRustDeskBridge.getLocalOption('codec-preference').trim();
    const modeMap: Record<string, number> = { 'auto': 0, 'vp8': 1, 'vp9': 2, 'av1': 3, 'h264': 4, 'h265': 5 };
    return modeMap[value] ?? 0;
  }

  private describeDefaultCodecMode(): string {
    const labels: Record<number, string> = { 0: 'Auto', 1: 'VP8', 2: 'VP9', 3: 'AV1', 4: 'H264', 5: 'H265' };
    return labels[this.resolveDefaultCodecMode()] ?? 'Auto';
  }

  private applyDefaultCodecMode(mode: number): void {
    const codecMap: Record<number, string> = { 0: 'auto', 1: 'vp8', 2: 'vp9', 3: 'av1', 4: 'h264', 5: 'h265' };
    this.applySessionAndLocalOption('codec-preference', codecMap[mode] ?? 'auto');
  }

  private resolveImageQualityModeIndex(): number {
    const modeMap: Record<string, number> = { 'best': 0, 'balanced': 1, 'low': 2, 'custom': 3 };
    return modeMap[this.resolveImageQualityMode()] ?? 1;
  }

  private applyImageQualityModeIndex(mode: number): void {
    const modeMap: Record<number, string> = { 0: 'best', 1: 'balanced', 2: 'low', 3: 'custom' };
    this.applyImageQualityMode(modeMap[mode] ?? 'balanced');
  }

  private resolveDefaultCustomQuality(): number {
    this.settingsOptionVersion;
    const value = Number(NativeRustDeskBridge.getLocalOption('custom-image-quality'));
    return Number.isFinite(value) && value >= 10 && value <= 2000 ? Math.round(value) : 50;
  }

  private resolveDefaultCustomFps(): number {
    this.settingsOptionVersion;
    const value = Number(NativeRustDeskBridge.getLocalOption('custom-fps'));
    return Number.isFinite(value) && value >= 10 && value <= 120 ? Math.round(value) : 30;
  }

  private describeAccountName(): string {
    const profile = this.accountState.profile;
    if (profile) {
      if (profile.displayName.trim().length > 0) {
        return profile.displayName.trim();
      }
      if (profile.name.trim().length > 0) {
        return profile.name.trim();
      }
    }
    if (this.accountState.displayName.trim().length > 0) {
      return this.accountState.displayName.trim();
    }
    if (this.accountState.username.trim().length > 0) {
      return this.accountState.username.trim();
    }
    return this.accountState.isLoggedIn ? this.lt('RustDesk User') : this.lt('Not logged in');
  }

  private describeAccountProvider(): string {
    const profile = this.accountState.profile;
    const provider = profile && profile.provider.trim().length > 0
      ? profile.provider.trim()
      : this.accountState.provider.trim();
    return provider.length > 0 ? provider.charAt(0).toUpperCase() + provider.slice(1) : this.lt('Unknown');
  }

  private resolveAuthProviderIcon(): string {
    const profile = this.accountState.profile;
    const provider = profile && profile.provider.trim().length > 0
      ? profile.provider.trim().toLowerCase()
      : this.accountState.provider.trim().toLowerCase();
    const known = ['github', 'google', 'apple', 'facebook', 'gitlab', 'azure', 'auth0', 'okta'];
    if (known.includes(provider)) {
      return `auth-${provider}.svg`;
    }
    return 'auth-default.svg';
  }

  private resolveLanguageKey(lang: string): string {
    if (lang === 'Follow System' || lang === this.lt('Follow System')) {
      return 'system';
    }
    if (lang === 'Chinese' || lang === this.lt('Chinese')) {
      return 'zh';
    }
    if (lang === 'English' || lang === 'en') {
      return 'en';
    }
    return 'en';
  }

  private describeCurrentLanguage(): string {
    const currentLang = I18nService.getInstance().getCurrentLanguage();
    if (currentLang === 'system') {
      return this.lt('Follow System');
    }
    if (currentLang === 'zh') {
      return this.lt('Chinese');
    }
    return 'English';
  }

  private describeAccountState(): string {
    if (this.accountState.status === 'logged_in') {
      return this.lt('Logged in');
    }
    if (this.accountState.status === 'waiting') {
      return this.lt('Waiting for browser approval');
    }
    if (this.accountState.status === 'requesting') {
      return this.lt('Requesting auth address');
    }
    if (this.accountState.status === 'error') {
      return this.lt('Login anomaly');
    }
    return this.lt('Idle');
  }

  private resolveGithubLoginButtonLabel(): string {
    if (this.accountState.status === 'requesting') {
      return this.lt('Preparing login');
    }
    if (this.accountState.status === 'waiting') {
      return this.accountState.browserOpened ? this.lt('Browser Opened') : this.lt('Open GitHub Login');
    }
    return this.lt('GitHub Login');
  }

  private describeServerProfile(): string {
    return this.isUsingPublicServer() ? this.lt('Official public demo server') : this.lt('Custom / self-hosted server');
  }

  private formatApprovalMode(): string {
    if (this.settings.approvalMode === 'click') {
      return this.lt('Click to confirm');
    }
    if (this.settings.approvalMode === 'both') {
      return this.lt('Password or click to confirm');
    }
    return this.lt('Password only');
  }

  private resolveChatPeerName(): string {
    const peerId = this.lastSessionPeerId.trim();
    if (peerId.length === 0) {
      return '';
    }
    const discovered = this.appData.getDiscoveredDevices().find((e: AddressBookEntry) => e.id === peerId);
    if (discovered && discovered.alias.length > 0) {
      return discovered.alias;
    }
    const abEntry = this.appData.getAddressBookEntry(peerId);
    if (abEntry && abEntry.alias.length > 0) {
      return abEntry.alias;
    }
    const info = NativeRustDeskBridge.getPeerInfo(peerId);
    if (info.username.length > 0 && info.hostname.length > 0) {
      return `${info.username}@${info.hostname}`;
    }
    if (info.hostname.length > 0) {
      return info.hostname;
    }
    return peerId;
  }

  private describeLastChatMessage(message?: ChatMessage): string {
    if (!message) {
      return this.lt('No messages');
    }
    if (message.type === ChatMessageType.FILE) {
      return `${this.lt('File')} - ${message.fileName ?? this.lt('Attachment')}`;
    }
    if (message.type === ChatMessageType.SYSTEM) {
      return `${this.lt('System')} - ${message.content}`;
    }
    return `${message.sender === 'local' ? this.lt('Me') : this.lt('Other')} - ${message.content}`;
  }

  @Builder
  private buildChatMessageBubble(message: ChatMessage, local: boolean) {
    Column() {
      Text(message.type === ChatMessageType.FILE
        ? `${message.fileName ?? this.lt('Attachment')}${message.fileSize ? ' ' + ChatService.formatFileSize(message.fileSize) : ''}`
        : message.content)
        .fontSize(14)
        .fontColor(local ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
        .maxLines(10)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .constraintSize({ maxWidth: '75%' })
    .backgroundColor(local ? this.theme_ACCENT : this.theme_CARD_BG)
    .borderRadius(12)
  }

  private async sendTabChatMessage(): Promise<void> {
    const text = this.chatDraft.trim();
    if (text.length === 0) {
      return;
    }
    const peerId = this.officialCoreState.activePeerId.trim();
    if (peerId.length === 0) {
      return;
    }
    this.chatDraft = '';
    await this.chatService.sendTextMessage(peerId, text);
    this.chatMessages = this.chatService.getMessages(peerId);
    this.scheduleChatTabScroll(50);
  }

  private navigateTo(url: string, params?: DeviceRouteParams): void {
    try {
      void this.getUIContext().getRouter().pushUrl({ url: url, params: params });
    } catch (error) {
      console.error('router push failed', JSON.stringify(error));
    }
  }

  private resetNativeBridgeState(): void {
    NativeRustDeskBridge.resetForRetry();
    this.nativeBridgeSummary = this.lt('Bridge reset requested, next refresh will re-detect Native module.');
    void this.refreshState();
  }

  @Builder
  private buildPasswordDialog() {
    Column() {
      Column({ space: 20 }) {
        Text(this.lt('Enter RustDesk Password'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)
          .width('100%')

        Text(this.lt('If you know the remote password, enter it to connect directly. A no-password request has also been sent — if the remote side approves, the connection will be established automatically.'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')

        TextInput({ placeholder: this.lt('Enter Password'), text: this.pendingPassword })
          .height(50)
          .fontSize(16)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.pendingPassword = value;
          })

        Row() {
          Checkbox()
            .select(this.rememberPassword)
            .onChange((checked: boolean) => {
              this.rememberPassword = checked;
            })
            .width(18)
            .height(18)

          Text(this.lt('Remember Password'))
            .fontSize(14)
            .fontColor(this.theme_TEXT_PRIMARY)
            .margin({ left: 8 })
            .onClick(() => {
              this.rememberPassword = !this.rememberPassword;
            })
        }
        .width('100%')

        Row() {
          Text(this.lt('Wait for confirmation'))
            .fontSize(14)
            .fontColor(this.theme_TEXT_SECONDARY)
            .onClick(() => {
              this.showPasswordDialog = false;
              void this.continueWaitingForPendingSession();
            })

          Blank()

          Text(this.lt('Cancel'))
            .fontSize(16)
            .fontColor(this.theme_ACCENT)
            .onClick(() => {
              void this.cancelPendingConnection();
            })

          Blank()

          Text(this.lt('Confirm'))
            .fontSize(16)
            .fontColor(this.theme_ACCENT)
            .onClick(() => {
              if (this.rememberPassword) {
                const peerId = this.pendingPeerId.trim();
                const password = this.pendingPassword.trim();
                if (peerId.length > 0 && password.length > 0) {
                  PreferenceStore.setPeerPassword(peerId, password);
                }
              } else {
                const peerId = this.pendingPeerId.trim();
                PreferenceStore.setPeerPassword(peerId, '');
                this.clearNativePeerPassword(peerId, this.pendingTransportTarget);
              }
              void this.submitPendingPassword();
            })
        }
        .width('100%')
        .padding({ top: 8 })
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .translate({ y: this.avoidKeyboardHeight > 0 ? -Math.min(this.avoidKeyboardHeight * 0.28, 88) : 0 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
    })
  }

  @Builder
  private buildServerDialog() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text(this.lt('ID / Relay Server'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('arrow-autofit-up.svg'))
            .width(22)
            .height(22)
            .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_SECONDARY))
            .onClick(() => {
              void this.exportServerConfig();
            })

          Image($rawfile('arrow-autofit-down.svg'))
            .width(22)
            .height(22)
            .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_SECONDARY))
            .margin({ left: 12 })
            .onClick(() => {
              void this.importServerConfig();
            })
        }
        .width('100%')

        Column({ space: 0 }) {
          Column({ space: 2 }) {
            Text(this.lt('ID Server'))
              .fontSize(12)
              .fontColor(this.draftIdServer.length > 0 ? this.theme_TEXT_TERTIARY : Color.Transparent)
              .width('100%')
              .height(16)
            TextInput({ text: this.draftIdServer, placeholder: this.lt('ID Server') })
              .height(44)
              .fontSize(15)
              .fontColor(this.theme_TEXT_PRIMARY)
              .placeholderColor(this.theme_TEXT_TERTIARY)
              .backgroundColor(Color.Transparent)
              .border({ width: { bottom: 1 }, color: this.theme_BORDER_SUBTLE })
              .borderRadius(0)
              .padding({ left: 0, right: 0, top: 4, bottom: 8 })
              .width('100%')
              .onChange((val: string) => {
                this.draftIdServer = val;
              })
          }
          .width('100%')
          .height(68)
          .padding({ top: 4, bottom: 2 })

          Column({ space: 2 }) {
            Text(this.lt('Relay Server'))
              .fontSize(12)
              .fontColor(this.draftRelayServer.length > 0 ? this.theme_TEXT_TERTIARY : Color.Transparent)
              .width('100%')
              .height(16)
            TextInput({ text: this.draftRelayServer, placeholder: this.lt('Relay Server') })
              .height(44)
              .fontSize(15)
              .fontColor(this.theme_TEXT_PRIMARY)
              .placeholderColor(this.theme_TEXT_TERTIARY)
              .backgroundColor(Color.Transparent)
              .border({ width: { bottom: 1 }, color: this.theme_BORDER_SUBTLE })
              .borderRadius(0)
              .padding({ left: 0, right: 0, top: 4, bottom: 8 })
              .width('100%')
              .onChange((val: string) => {
                this.draftRelayServer = val;
              })
          }
          .width('100%')
          .height(68)
          .padding({ top: 4, bottom: 2 })

          Column({ space: 2 }) {
            Text(this.lt('API Server'))
              .fontSize(12)
              .fontColor(this.draftApiServer.length > 0 ? this.theme_TEXT_TERTIARY : Color.Transparent)
              .width('100%')
              .height(16)
            TextInput({ text: this.draftApiServer, placeholder: this.lt('API Server') })
              .height(44)
              .fontSize(15)
              .fontColor(this.theme_TEXT_PRIMARY)
              .placeholderColor(this.theme_TEXT_TERTIARY)
              .backgroundColor(Color.Transparent)
              .border({ width: { bottom: 1 }, color: this.theme_BORDER_SUBTLE })
              .borderRadius(0)
              .padding({ left: 0, right: 0, top: 4, bottom: 8 })
              .width('100%')
              .onChange((val: string) => {
                this.draftApiServer = val;
              })
          }
          .width('100%')
          .height(68)
          .padding({ top: 4, bottom: 2 })

          Column({ space: 2 }) {
            Text('Key')
              .fontSize(12)
              .fontColor(this.draftKey.length > 0 ? this.theme_TEXT_TERTIARY : Color.Transparent)
              .width('100%')
              .height(16)
            TextInput({ text: this.draftKey, placeholder: 'Key' })
              .height(44)
              .fontSize(15)
              .fontColor(this.theme_TEXT_PRIMARY)
              .placeholderColor(this.theme_TEXT_TERTIARY)
              .backgroundColor(Color.Transparent)
              .border({ width: { bottom: 1 }, color: this.theme_BORDER_SUBTLE })
              .borderRadius(0)
              .padding({ left: 0, right: 0, top: 4, bottom: 8 })
              .width('100%')
              .onChange((val: string) => {
                this.draftKey = val;
              })
          }
          .width('100%')
          .height(68)
          .padding({ top: 4, bottom: 2 })
        }
        .width('100%')

        Row() {
          Text(this.lt('Cancel'))
            .fontSize(16)
            .fontColor(this.theme_ACCENT)
            .onClick(() => {
              this.showServerDialog = false;
            })

          Blank()

          Text(this.lt('Clear'))
            .fontSize(16)
            .fontColor(this.theme_ACCENT)
            .margin({ right: 24 })
            .onClick(() => {
              this.draftIdServer = '';
              this.draftRelayServer = '';
              this.draftApiServer = '';
              this.draftKey = '';
            })

          Text(this.lt('Confirm'))
            .fontSize(16)
            .fontColor(this.theme_ACCENT)
            .onClick(() => {
              void this.applyDraftServers();
              this.showServerDialog = false;
            })
        }
        .width('100%')
        .padding({ top: 8 })
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showServerDialog = false;
    })
  }

  @Builder
  private buildLanguageDialog() {
    Column() {
      Column({ space: 20 }) {
        Row() {
          Text(this.lt('Language'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showLanguageDialog = false;
            })
        }
        .width('100%')

        Column({ space: 0 }) {
          ForEach(['system', 'zh', 'en'] as string[], (langKey: string, index?: number) => {
            Row({ space: 10 }) {
              Stack() {
                Circle()
                  .width(20)
                  .height(20)
                  .fill(Color.Transparent)
                  .stroke(langKey === I18nService.getInstance().getCurrentLanguage() ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
                  .strokeWidth(2)

                if (langKey === I18nService.getInstance().getCurrentLanguage()) {
                  Circle()
                    .width(12)
                    .height(12)
                    .fill(this.theme_ACCENT)
                }
              }
              .width(20)
              .height(20)

              Text(langKey === 'system' ? this.lt('Follow System') : (langKey === 'zh' ? this.lt('Chinese') : 'English'))
                .fontSize(16)
                .fontColor(langKey === I18nService.getInstance().getCurrentLanguage() ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
                .layoutWeight(1)
            }
            .width('100%')
            .height(ThemeConfig.MENU_ITEM_HEIGHT)
            .border(index != null && index > 0 ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
            .onClick(() => {
              I18nService.getInstance().setLanguage(langKey);
              this.updateSettings({ language: langKey });
              this.languageDialogOpacity = 0;
              setTimeout(() => {
                this.showLanguageDialog = false;
                this.languageDialogOpacity = 1;
                this.forceI18nRefresh();
              }, 500);
            })
          }, (langKey: string) => langKey)
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .opacity(this.languageDialogOpacity)
      .animation({ duration: 500, curve: Curve.EaseInOut })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showLanguageDialog = false;
    })
  }

  @Builder
  private buildThemeDialog() {
    Column() {
      Column({ space: 20 }) {
        Row() {
          Text(this.lt('Theme'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showThemeDialog = false;
            })
        }
        .width('100%')

        Column({ space: 0 }) {
          this.buildThemeOptionRow('light', this.lt('Light'), false)
          this.buildThemeOptionRow('dark', this.lt('Dark'), true)
          this.buildThemeOptionRow('system', this.lt('Follow System'), true)
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showThemeDialog = false;
    })
  }

  @Builder
  private buildThemeOptionRow(mode: AppThemeMode, label: string, showTopBorder: boolean = false) {
    Row({ space: 10 }) {
      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.themeMode === mode ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
          .strokeWidth(2)

        if (this.themeMode === mode) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.theme_ACCENT)
        }
      }
      .width(20)
      .height(20)

      Text(label)
        .fontSize(16)
        .fontColor(this.themeMode === mode ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1);
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .onClick(() => {
      if (this.themeMode !== mode) {
        this.themeMode = mode;
        this.updateSettings({ theme: mode === 'system' ? 'auto' : mode });
      }
      this.showThemeDialog = false;
    })
  }

  @Builder
  private buildDisplaySettingsDialog() {
    Column() {
      Column() {
        Row() {
          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_TERTIARY)
            .onClick(() => {
              this.showDisplaySettingsDialog = false;
            })

          Text(this.lt('Display Settings'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Row().width(20)
        }
        .width('100%')
        .margin({ bottom: 20 })

        Scroll() {
          Column({ space: 0 }) {
            Row({ space: 12 }) {
              Text(this.lt('Default View Mode'))
                .fontSize(16)
                .fontColor(this.theme_TEXT_PRIMARY)
                .layoutWeight(1)
              Select([
                { value: this.lt('Original Size') },
                { value: this.lt('Fit Window') },
                { value: this.lt('Custom Zoom') }
              ])
                .selected(this.resolveDefaultDisplayScaleMode())
                .value(this.describeDefaultDisplayScaleMode())
                .fontColor(this.theme_TEXT_PRIMARY)
                .backgroundColor(this.theme_INPUT_BG)
                .optionBgColor(this.theme_CARD_BG)
                .optionFontColor(this.theme_TEXT_PRIMARY)
                .selectedOptionBgColor(this.theme_ACCENT)
                .selectedOptionFontColor(this.theme_ACCENT_TEXT)
                .menuBackgroundColor(this.theme_CARD_BG)
                .onSelect((index: number, _value?: string) => {
                  this.applyDefaultDisplayScaleMode(index);
                })
            }
            .width('100%')
            .height(ThemeConfig.MENU_ITEM_HEIGHT)

            if (this.resolveDefaultDisplayScaleMode() === 2) {
              Column() {
                Row() {
                  Text(this.lt('Custom Zoom'))
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_SECONDARY)
                    .layoutWeight(1)
                  Text(`${this.resolveDefaultCustomZoomPercent()}%`)
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_PRIMARY)
                }
                .width('100%')
                Slider({ value: this.resolveDefaultCustomZoomPercent(), min: 100, max: 600, step: 10, style: SliderStyle.OutSet })
                  .selectedColor(this.theme_ACCENT)
                  .trackColor(this.theme_BORDER_SOFT)
                  .width('100%')
                  .onChange((value: number) => {
                    NativeRustDeskBridge.setLocalOption('custom-zoom-percent', String(Math.round(value)));
                    this.settingsOptionVersion++;
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 8 })
            }

            Row({ space: 12 }) {
              Text(this.lt('Default Image Quality'))
                .fontSize(16)
                .fontColor(this.theme_TEXT_PRIMARY)
                .layoutWeight(1)
              Select([
                { value: this.lt('Best Quality') },
                { value: this.lt('Balanced') },
                { value: this.lt('Best Speed') },
                { value: this.lt('Custom') }
              ])
                .selected(this.resolveImageQualityModeIndex())
                .value(this.describeImageQualityMode())
                .fontColor(this.theme_TEXT_PRIMARY)
                .backgroundColor(this.theme_INPUT_BG)
                .optionBgColor(this.theme_CARD_BG)
                .optionFontColor(this.theme_TEXT_PRIMARY)
                .selectedOptionBgColor(this.theme_ACCENT)
                .selectedOptionFontColor(this.theme_ACCENT_TEXT)
                .menuBackgroundColor(this.theme_CARD_BG)
                .onSelect((index: number, _value?: string) => {
                  this.applyImageQualityModeIndex(index);
                })
            }
            .width('100%')
            .height(ThemeConfig.MENU_ITEM_HEIGHT)
            .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })

            if (this.resolveImageQualityMode() === 'custom') {
              Column() {
                Row() {
                  Text(this.lt('Bitrate'))
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_SECONDARY)
                    .layoutWeight(1)
                  Text(`${this.resolveDefaultCustomQuality()}%`)
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_PRIMARY)
                }
                .width('100%')
                Slider({ value: this.resolveDefaultCustomQuality(), min: 10, max: 2000, step: 10, style: SliderStyle.OutSet })
                  .selectedColor(this.theme_ACCENT)
                  .trackColor(this.theme_BORDER_SOFT)
                  .width('100%')
                  .onChange((value: number) => {
                    this.applySessionAndLocalOption('custom-image-quality', String(Math.round(value)));
                  })
                Row() {
                  Text(this.lt('FPS'))
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_SECONDARY)
                    .layoutWeight(1)
                  Text(`${this.resolveDefaultCustomFps()}`)
                    .fontSize(13)
                    .fontColor(this.theme_TEXT_PRIMARY)
                }
                .width('100%')
                Slider({ value: this.resolveDefaultCustomFps(), min: 10, max: 120, step: 5, style: SliderStyle.OutSet })
                  .selectedColor(this.theme_ACCENT)
                  .trackColor(this.theme_BORDER_SOFT)
                  .width('100%')
                  .onChange((value: number) => {
                    this.applySessionAndLocalOption('custom-fps', String(Math.round(value)));
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 8 })
            }

            Row({ space: 12 }) {
              Text(this.lt('Default Codec'))
                .fontSize(16)
                .fontColor(this.theme_TEXT_PRIMARY)
                .layoutWeight(1)
              Select([
                { value: 'Auto' },
                { value: 'VP8' },
                { value: 'VP9' },
                { value: 'AV1' },
                { value: 'H264' },
                { value: 'H265' }
              ])
                .selected(this.resolveDefaultCodecMode())
                .value(this.describeDefaultCodecMode())
                .fontColor(this.theme_TEXT_PRIMARY)
                .backgroundColor(this.theme_INPUT_BG)
                .optionBgColor(this.theme_CARD_BG)
                .optionFontColor(this.theme_TEXT_PRIMARY)
                .selectedOptionBgColor(this.theme_ACCENT)
                .selectedOptionFontColor(this.theme_ACCENT_TEXT)
                .menuBackgroundColor(this.theme_CARD_BG)
                .onSelect((index: number, _value?: string) => {
                  this.applyDefaultCodecMode(index);
                })
            }
            .width('100%')
            .height(ThemeConfig.MENU_ITEM_HEIGHT)
            .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })

            Text(this.lt('Other Default options'))
              .fontSize(ThemeConfig.FONT_SIZE_MD)
              .fontColor(this.theme_TEXT_SECONDARY)
              .width('100%')
              .height(ThemeConfig.MENU_ITEM_HEIGHT)
              .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE })

            this.buildDisplaySettingsToggleRow(this.lt('View Mode'), this.resolveLocalToggleOption('view-only'), (value: boolean) => { this.applySessionAndLocalToggleOption('view-only', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Show Remote Cursor'), this.resolveLocalToggleOption('show-remote-cursor'), (value: boolean) => { this.applySessionAndLocalToggleOption('show-remote-cursor', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Show Quality Monitor'), this.resolveLocalToggleOption('show-quality-monitor'), (value: boolean) => { this.applySessionAndLocalToggleOption('show-quality-monitor', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Mute'), this.resolveLocalToggleOption('disable-audio'), (value: boolean) => { this.applySessionAndLocalToggleOption('disable-audio', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Disable Clipboard'), this.resolveLocalToggleOption('disable-clipboard'), (value: boolean) => { this.applySessionAndLocalToggleOption('disable-clipboard', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Lock After Session End'), this.resolveLocalToggleOption('lock-after-session-end'), (value: boolean) => { this.applySessionAndLocalToggleOption('lock-after-session-end', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Reverse Mouse Scroll'), this.resolveLocalToggleOption('reverse-scroll'), (value: boolean) => { this.applySessionAndLocalToggleOption('reverse-scroll', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Swap Mouse Buttons'), this.resolveLocalToggleOption('swap-left-right-mouse'), (value: boolean) => { this.applySessionAndLocalToggleOption('swap-left-right-mouse', value); }, true)
            this.buildDisplaySettingsToggleRow(this.lt('Keep Terminal Session On Disconnect'), this.resolveLocalToggleOption('terminal-persistent'), (value: boolean) => { this.applySessionAndLocalToggleOption('terminal-persistent', value); }, true)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('90%')
      .constraintSize({ maxHeight: '80%' })
      .padding(20)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showDisplaySettingsDialog = false;
    })
  }

  @Builder
  private buildDisplaySettingsLinkRow(label: string, value: string, showTopBorder: boolean = false) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      Text(value)
        .fontSize(14)
        .fontColor(this.theme_TEXT_SECONDARY)
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
  }

  @Builder
  private buildDisplaySettingsToggleRow(label: string, isOn: boolean, onChange: (value: boolean) => void, showTopBorder: boolean = false) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.theme_ACCENT)
        .switchPointColor(this.theme_WHITE)
        .constraintSize({ maxHeight: 32 })
        .onChange(onChange)
    }
    .width('100%')
    .height(ThemeConfig.MENU_ITEM_HEIGHT)
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
  }

  @Builder
  private buildDisplaySettingsChoiceRow(label: string, selected: boolean, onSelect: () => void, showTopBorder: boolean = false) {
    Row({ space: 10 }) {
      Circle()
        .width(10)
        .height(10)
        .fill(selected ? this.theme_ACCENT : this.theme_BORDER_SUBTLE)

      Text(label)
        .fontSize(15)
        .fontColor(selected ? this.theme_TEXT_PRIMARY : this.theme_TEXT_SECONDARY)
        .layoutWeight(1)
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 4 })
    .border(showTopBorder ? { width: { top: 1 }, color: this.theme_BORDER_SUBTLE } : { width: 0 })
    .onClick(onSelect)
  }

  @Builder
  private buildAccountDialog() {
    Column() {
      Column({ space: 16 }) {
        Row() {
          Text(this.lt('Login'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showAccountDialog = false;
            })
        }
        .width('100%')

        if (this.accountState.isLoggedIn) {
          Row({ space: 8 }) {
            Image($rawfile('settings_person.svg'))
              .width(18)
              .height(18)
              .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
            Text(this.describeAccountName())
              .fontSize(16)
              .fontColor(this.theme_TEXT_PRIMARY)
              .layoutWeight(1)
          }
          .width('100%')

          this.buildSettingsInfoSettingRow(this.lt('Provider'), this.describeAccountProvider(), 'settings_server.svg')
          this.buildSettingsInfoSettingRow(this.lt('Status'), this.describeAccountState(), 'settings_record.svg', '', true)

          Row() {
            SecondaryButton(this.lt('Sign out'), () => {
              this.signOutAccount();
              this.showAccountDialog = false;
            })
          }
          .width('100%')
        } else {
          if (this.isAccountBusy()) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color(this.theme_ACCENT)
              Text(this.accountState.status === 'waiting' ? this.lt('Waiting for browser approval') : this.lt('Requesting auth address'))
                .fontSize(14)
                .fontColor(this.theme_TEXT_SECONDARY)
              Row({ space: 12 }) {
                SecondaryButton(this.lt('Reopen browser'), () => {
                  void this.accountService.reopenBrowser();
                })
                SecondaryButton(this.lt('Cancel'), () => {
                  this.cancelGithubLogin();
                })
              }
            }
            .width('100%')
          } else {
            Row({ space: 8 }) {
              Image($rawfile('opt_user.svg'))
                .width(18)
                .height(18)
                .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
              TextInput({ placeholder: this.lt('Username'), text: this.loginUsername })
                .height(44)
                .backgroundColor(this.theme_INPUT_BG)
                .borderRadius(8)
                .layoutWeight(1)
                .onChange((v: string) => this.loginUsername = v)
            }
            .width('100%')

            Row({ space: 8 }) {
              Image($rawfile('menu_key.svg'))
                .width(18)
                .height(18)
                .colorFilter(this.createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
              TextInput({ placeholder: this.lt('Password'), text: this.loginPassword })
                .height(44)
                .type(InputType.Password)
                .backgroundColor(this.theme_INPUT_BG)
                .borderRadius(8)
                .layoutWeight(1)
                .onChange((v: string) => this.loginPassword = v)
            }
            .width('100%')

            if (this.loginErrorMsg.length > 0) {
              Text(this.loginErrorMsg)
                .fontSize(12)
                .fontColor(this.theme_ERROR_TEXT)
                .width('100%')
            }

            Row() {
              PrimaryButton(this.lt('Login'), () => {
                void this.handlePasswordLoginInDialog();
              }, this.loginUsername.length === 0 || this.loginPassword.length === 0)
            }
            .width('100%')

            Text(this.lt('or'))
              .fontSize(14)
              .fontColor(this.theme_TEXT_TERTIARY)
              .margin({ top: 8, bottom: 8 })

            Column({ space: 8 }) {
              this.buildOAuthButton('github', '#333333')
              this.buildOAuthButton('google', '#4285F4')
              this.buildOAuthButton('microsoft', '#00A4EF')
            }
            .width('100%')

            Row() {
              Text(this.lt('Login agreement'))
                .fontSize(11)
                .fontColor(this.theme_TEXT_TERTIARY)
              Text(this.lt('Privacy Policy'))
                .fontSize(11)
                .fontColor(this.theme_ACCENT)
                .onClick(() => this.openExternalUrl('https://rustdesk.com/privacy'))
              Text(this.lt('and'))
                .fontSize(11)
                .fontColor(this.theme_TEXT_TERTIARY)
              Text(this.lt('Terms'))
                .fontSize(11)
                .fontColor(this.theme_ACCENT)
                .onClick(() => this.openExternalUrl('https://rustdesk.com/terms'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 12 })
          }
        }
      }
      .width('85%')
      .padding(20)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showAccountDialog = false;
    })
  }

  @Builder
  private buildOAuthButton(provider: string, color: string) {
    Button() {
      Row() {
        Image($rawfile(`auth-${provider}.svg`))
          .width(18)
          .height(18)
          .colorFilter(this.createStrokeIconColorFilter(this.theme_CONTRAST_TEXT))
        Text(`${this.lt('Continue with')} ${provider.charAt(0).toUpperCase() + provider.slice(1)}`)
          .fontSize(14)
          .fontColor(this.theme_CONTRAST_TEXT)
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height(40)
    .backgroundColor(color)
    .borderRadius(8)
    .onClick(() => {
      this.showAccountDialog = false;
      void this.handleOAuthLoginInDialog(provider);
    })
  }

  @Builder
  private buildShareStartWarning() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          Row({ space: 10 }) {
            Image($rawfile('info_alert.svg'))
              .width(26)
              .height(26)
              .fillColor(Color.White)

            Text(this.lt('Warning'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)
          }
          .width('100%')

          Image($rawfile('scam.png'))
            .width(176)
            .height(132)
            .objectFit(ImageFit.Contain)
            .alignSelf(ItemAlign.Center)

          Text(this.lt('You may be being scammed'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .width('100%')

          Text(`${this.lt('Scam warning detail one')}\n\n${this.lt('Scam warning detail two')}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .lineHeight(24)
            .width('100%')

          Row({ space: 8 }) {
            Checkbox()
              .select(this.shareWarningDontShowAgain)
              .selectedColor(this.theme_ACCENT)
              .onChange((checked: boolean) => {
                this.shareWarningDontShowAgain = checked;
              })

            Text(this.lt("Don't show again"))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
          }
          .width('100%')

          Row({ space: 12 }) {
            Button(this.shareWarningCountdown > 0
              ? `${this.lt('I Agree')} (${this.shareWarningCountdown}s)`
              : this.lt('I Agree'))
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor(this.shareWarningCountdown > 0 ? '#6680A7D8' : this.theme_ACCENT)
              .borderRadius(8)
              .enabled(this.shareWarningCountdown <= 0)
              .onClick(() => {
                this.confirmShareServiceStart();
              })

            Button(this.lt('Decline'))
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .backgroundColor('#55334152')
              .border({ width: 1, color: '#99FFFFFF' })
              .borderRadius(8)
              .onClick(() => {
                this.closeShareStartWarning();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(25)
      }
      .width('88%')
      .constraintSize({ maxHeight: '88%' })
      .linearGradient({
        angle: 135,
        colors: [['#FFE242BC', 0.0], ['#FFF4727C', 1.0]]
      })
      .borderRadius(20)
      .shadow({ radius: 24, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 6 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme_DIALOG_OVERLAY)
  }

  @Builder
  private buildRenameDialog() {
    Column() {
      Column({ space: 20 }) {
        Text(this.lt('Rename'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        TextInput({ text: this.renameDraft, placeholder: this.lt('Input new name') })
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(8)
          .onChange((value: string) => {
            this.renameDraft = value;
          })

        Row({ space: 12 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INPUT_BG)
            .borderRadius(8)
            .onClick(() => {
              this.showRenameDialog = false;
            })

          Button(this.lt('OK'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              const id = this.renameTargetId;
              const newName = this.renameDraft.trim();
              if (newName.length > 0) {
                this.appData.renameRecentSession(id, newName);
                this.recentSessions = this.appData.getRecentSessions();
              }
              this.showRenameDialog = false;
            })
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showRenameDialog = false;
    })
  }

  @Builder
  private buildDirectAccessPortDialog() {
    Column() {
      Column({ space: 18 }) {
        Text(this.lt('Direct IP access'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        Column({ space: 6 }) {
          Text(this.lt('Local IP'))
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
          Text(this.directAccessIp.length > 0 ? this.directAccessIp : this.lt('No local IP'))
            .fontSize(16)
            .fontColor(this.theme_TEXT_PRIMARY)
            .width('100%')
            .maxLines(2)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text(this.lt('Port'))
            .fontSize(ThemeConfig.FONT_SIZE_SM)
            .fontColor(this.theme_TEXT_SECONDARY)
            .width('100%')
          TextInput({ text: this.directAccessPortDraft, placeholder: '21118' })
            .width('100%')
            .height(48)
            .type(InputType.Number)
            .fontSize(16)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INPUT_BG)
            .borderRadius(8)
            .maxLength(5)
            .onChange((value: string) => {
              this.directAccessPortDraft = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row({ space: 12 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INPUT_BG)
            .borderRadius(8)
            .onClick(() => {
              this.showDirectAccessPortDialog = false;
            })

          Button(this.lt('OK'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              this.saveDirectAccessPort();
            })
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(8)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showDirectAccessPortDialog = false;
    })
  }

  @Builder
  private buildProxyDialog() {
    Column() {
      Column({ space: 20 }) {
        Row() {
          Text(this.lt('Proxy Configuration'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)

          Blank()

          Image($rawfile('close.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showProxyDialog = false;
            })
        }
        .width('100%')

        Text(this.lt('Socks5 Proxy'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')
        TextInput({ text: this.draftSocks5Proxy, placeholder: this.lt('Example: socks5://127.0.0.1:1080') })
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(8)
          .onChange((value: string) => {
            this.draftSocks5Proxy = value;
          })

        Text(this.lt('Http(s) Proxy'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')
        TextInput({ text: this.draftHttpProxy, placeholder: this.lt('Example: http://127.0.0.1:8080') })
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(8)
          .onChange((value: string) => {
            this.draftHttpProxy = value;
          })

        Row({ space: 12 }) {
          Button(this.lt('Reset'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INPUT_BG)
            .borderRadius(8)
            .onClick(() => {
              this.draftSocks5Proxy = '';
              this.draftHttpProxy = '';
            })

          Button(this.lt('Apply'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              this.updateSettings({ socks5Proxy: this.draftSocks5Proxy.trim(), httpProxy: this.draftHttpProxy.trim() });
              this.showProxyDialog = false;
            })
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.showProxyDialog = false;
    })
  }

  private async handleConnectWithPassword(peerId: string, password: string): Promise<void> {
    this.pendingConnectionMonitorId += 1;
    this.pendingConnectionRetryCount = 0;
    this.pendingConnectionInactivePollCount = 0;
    this.pendingPeerId = peerId;
    const transportTarget = this.pendingTransportTarget.length > 0
      ? this.pendingTransportTarget
      : this.resolveConnectionTransportTarget(peerId);
    this.pendingTransportTarget = transportTarget;
    this.showPasswordDialog = false;
    this.isConnecting = true;
    this.setStatusMessage("connecting", peerId);

    try {
      await this.officialBridge.connectToPeer(transportTarget, password, this.settings, peerId);
      this.officialCoreState = this.officialBridge.getCoreState();
      if (this.officialCoreState.sessionStage === 'connected') {
        this.openRemoteControlForPendingSession(peerId, this.officialCoreState);
      } else {
        this.isConnecting = false;
        void this.monitorConnectionWhileWaiting();
      }
      return;
    } catch (error) {
      const nextState = await this.officialBridge.refresh(this.settings);
      this.officialCoreState = nextState;
      if (nextState.detailMessage.length > 0) {
        this.setStatusMessageRaw(nextState.detailMessage);
      } else if (error instanceof Error) {
        this.setStatusMessageRaw(error.message);
      } else {
        this.setStatusMessage("connection_failed");
      }
    } finally {
      this.pendingPassword = '';
    }
  }

  private showConnectPasswordDialog(peerId: string, proactive: boolean = false): void {
    this.pendingPeerId = peerId;
    this.pendingPasswordDialogProactive = proactive;
    const savedPassword: string = PreferenceStore.getPeerPassword(peerId) ?? '';
    hilog.info(0xA03D00, 'CONN', `[showConnectPasswordDialog] peerId=${peerId} savedPassword=${savedPassword.length > 0 ? 'yes' : 'no'}`);
    if (savedPassword.trim().length > 0 && this.autoSubmittedSavedPasswordPeerId !== peerId) {
      this.autoSubmittedSavedPasswordPeerId = peerId;
      this.pendingPassword = savedPassword.trim();
      this.showPasswordDialog = false;
      this.setStatusMessage("detected_saved_password");
      void this.submitPendingPassword();
      return;
    }
    this.pendingPassword = savedPassword;
    this.showPasswordDialog = true;
    hilog.info(0xA03D00, 'CONN', `[showConnectPasswordDialog] showPasswordDialog set to TRUE`);
    this.setStatusMessageRaw(savedPassword
      ? this.lt('Saved password filled, submit directly or modify.')
      : this.lt('Enter remote password if known, or wait for remote confirmation.'));
    void this.monitorConnectionWhileWaiting();
  }

  private async savePeerPassword(): Promise<void> {
    const peerId = this.pendingPeerId.trim();
    const password = this.pendingPassword.trim();
    if (peerId.length === 0) {
      return;
    }
    if (password.length === 0) {
      PreferenceStore.setPeerPassword(peerId, '');
      this.setStatusMessageRaw(`${this.lt('Pwd saved')}`);
      try {
        await this.getUIContext().getPromptAction().openToast({
          message: this.lt('Saved password deleted')
        });
      } catch (error) {
        console.error('toast failed', JSON.stringify(error));
      }
      return;
    }
    PreferenceStore.setPeerPassword(peerId, password);
    this.setStatusMessage("password_saved");
    try {
      await this.getUIContext().getPromptAction().openToast({
        message: this.lt('Password saved')
      });
    } catch (error) {
      console.error('toast failed', JSON.stringify(error));
    }
    this.setStatusMessage("password_saved_continue");
    await this.submitPendingPassword();
  }

  private openRemoteControlForPendingSession(peerId: string, state: OfficialCoreState): void {
    const normalizedPeerId = peerId.trim();
    if (normalizedPeerId.length === 0) {
      return;
    }
    this.officialCoreState = state;
    if (state.detailMessage.includes('hostname=')) {
      this.parseHostnameFromDetail(state.detailMessage);
    }
    const hostname = this.getResolvedHostname(state.detailMessage);
    const parsedPlatform = this.parseFieldFromDetail(state.detailMessage, 'platform');
    const parsedUsername = this.parseFieldFromDetail(state.detailMessage, 'username');
    const platform = parsedPlatform.length > 0 ? parsedPlatform : 'RustDesk';
    this.appData.addRecentSession(this.appData.createRecentSession(normalizedPeerId, platform, true, hostname, parsedUsername));
    this.recentSessions = this.appData.getRecentSessions();
    this.selectLatestChatPeer(normalizedPeerId);
    this.hasHadSession = true;
    this.pendingConnectionMonitorId += 1;
    this.pendingPeerId = '';
    this.pendingPassword = '';
    this.showPasswordDialog = false;
    this.pendingPasswordDialogProactive = false;
    this.isConnecting = false;
    this.pendingConnectionRetryCount = 0;
    this.pendingConnectionInactivePollCount = 0;
    this.setStatusMessageRaw(state.sessionStage === 'connected'
      ? this.lt('Connection established. Opening remote desktop...')
      : this.lt('Connection request continuing...'));
    this.navigateTo('pages/RemoteControl', { deviceId: normalizedPeerId });
  }

  private async monitorConnectionWhileWaiting(): Promise<void> {
    const peerId = this.pendingPeerId.trim();
    if (peerId.length === 0) {
      return;
    }
    const monitorId = ++this.pendingConnectionMonitorId;
    for (let i = 0; i < 180; i += 1) {
      await this.sleep(1000);
      if (monitorId !== this.pendingConnectionMonitorId || this.pendingPeerId.trim() !== peerId) {
        return;
      }
      const state = await this.officialBridge.refresh(this.settings);
      this.officialCoreState = state;
      if (state.detailMessage.includes('hostname=')) {
        this.parseHostnameFromDetail(state.detailMessage);
      }
      this.syncPendingConnectionUi(state);
      if (state.sessionStage === 'connected') {
        this.openRemoteControlForPendingSession(peerId, state);
        return;
      }
      if (state.sessionStage === 'error') {
        const errMsg = state.lastError || state.detailMessage;
        if (this.shouldPromptForPassword(errMsg)) {
          this.pendingConnectionInactivePollCount = 0;
          continue;
        }
        this.pendingConnectionInactivePollCount += 1;
        if (this.pendingConnectionInactivePollCount < 3) {
          continue;
        }
        this.showPasswordDialog = false;
        this.setStatusMessageRaw(errMsg.length > 0 ? errMsg : this.lt('Connection failed'));
        this.pendingPeerId = '';
        this.pendingConnectionRetryCount = 0;
        this.pendingConnectionInactivePollCount = 0;
        return;
      }
      if (this.isPendingConnectionAlive(state, peerId)) {
        this.pendingConnectionInactivePollCount = 0;
        continue;
      }
      this.pendingConnectionInactivePollCount += 1;
      if (this.pendingConnectionInactivePollCount < 3) {
        continue;
      }
      this.showPasswordDialog = false;
      this.setStatusMessage("session_ended");
      this.pendingPeerId = '';
      this.pendingConnectionRetryCount = 0;
      this.pendingConnectionInactivePollCount = 0;
      return;
    }
    if (monitorId === this.pendingConnectionMonitorId && this.pendingPeerId.trim() === peerId) {
      this.setStatusMessage("connection_still");
    }
  }

  private async continueWaitingForPendingSession(): Promise<void> {
    const peerId = this.pendingPeerId.trim();
    this.pendingPassword = '';
    if (peerId.length === 0) {
      return;
    }
    this.showPasswordDialog = false;
    this.pendingPasswordDialogProactive = false;
    const state = await this.officialBridge.refresh(this.settings);
    this.officialCoreState = state;
    this.pendingConnectionInactivePollCount = 0;
    this.setStatusMessageRaw(this.isPendingConnectionAlive(state, peerId)
      ? this.lt('Connect request still in progress, waiting for remote confirmation...')
      : this.lt('Connect request still in progress, waiting for remote response...'));
    void this.monitorConnectionWhileWaiting();
  }

  private async submitPendingPassword(): Promise<void> {
    const peerId = this.pendingPeerId.trim();
    const password = this.pendingPassword.trim();
    if (peerId.length === 0) {
      this.pendingPassword = '';
      this.showPasswordDialog = false;
      return;
    }
    if (password.length === 0) {
      this.showPasswordDialog = false;
      await this.continueWaitingForPendingSession();
      return;
    }

    this.pendingConnectionRetryCount = 0;
    this.pendingConnectionInactivePollCount = 0;
    this.isConnecting = true;
    this.showPasswordDialog = false;
    this.pendingPasswordDialogProactive = false;
    const submitted = this.officialBridge.submitSessionPassword(password, this.rememberPassword);
    if (submitted) {
      this.pendingPassword = '';
      this.setStatusMessage("password_submitted");
      this.isConnecting = false;
      void this.monitorConnectionWhileWaiting();
      return;
    }

    this.isConnecting = false;
    this.setStatusMessageRaw(this.lt('Reconnecting'));
    await this.resetPendingConnectionState(true);
    await this.handleConnectWithPassword(peerId, password);
  }

  private async waitForSessionLaunch(peerId: string, allowPasswordPrompt: boolean): Promise<boolean> {
    let latestState = await this.officialBridge.refresh(this.settings);
    this.officialCoreState = latestState;
    if (latestState.detailMessage.includes('hostname=')) {
      this.parseHostnameFromDetail(latestState.detailMessage);
    }
    this.syncPendingConnectionUi(latestState);
    for (let i = 0; i < 24; i += 1) {
      await this.sleep(500);
      latestState = await this.officialBridge.refresh(this.settings);
      this.officialCoreState = latestState;
      if (latestState.detailMessage.includes('hostname=')) {
        this.parseHostnameFromDetail(latestState.detailMessage);
      }
      this.syncPendingConnectionUi(latestState);
      console.info(`[Connect] Check ${i}: stage=${latestState.sessionStage}, error=${latestState.lastError}`);

      const promptSource = `${latestState.statusSummary}\n${latestState.detailMessage}\n${latestState.lastError}`;
      if (allowPasswordPrompt &&
        latestState.sessionStage === 'connecting' &&
        this.shouldPromptForPassword(promptSource)) {
        this.officialCoreState = latestState;
        this.showConnectPasswordDialog(peerId);
        return true;
      }

      if (latestState.sessionStage === 'connected') {
        this.openRemoteControlForPendingSession(peerId, latestState);
        return true;
      }

      if (latestState.sessionStage === 'error') {
        const errorMsg = latestState.lastError || latestState.detailMessage || '';
        if (allowPasswordPrompt && this.shouldPromptForPassword(errorMsg)) {
          console.info('[Connect] Password required, showing dialog');
          this.pendingPassword = '';
          this.showConnectPasswordDialog(peerId);
          this.officialCoreState = latestState;
          this.setStatusMessage("password_required");
          return true;
        }

        this.officialCoreState = latestState;
        this.setStatusMessageRaw(errorMsg.length > 0 ? errorMsg : this.lt('Connection failed'));
        return true;
      }
    }

    this.officialCoreState = latestState;
    if (latestState.sessionStage === 'connecting') {
      this.setStatusMessageRaw(latestState.detailMessage.length > 0
        ? latestState.detailMessage
        : `${this.lt('Connecting to')} ${this.formatId(peerId)}...`);
      return false;
    }

    return false;
  }

  private syncPendingConnectionUi(coreState: OfficialCoreState): void {
    if (!this.showPasswordDialog && !this.isConnecting && this.pendingPeerId.trim().length === 0) {
      return;
    }
    const peerId = this.pendingPeerId.trim().length > 0
      ? this.pendingPeerId.trim()
      : coreState.activePeerId.trim();
    const nextMessage = this.resolvePendingConnectionMessage(coreState, peerId);
    if (nextMessage.length > 0) {
      this.setStatusMessageRaw(nextMessage);
    }
  }

  private resolvePendingConnectionMessage(coreState: OfficialCoreState, peerId: string): string {
    if (coreState.sessionStage === 'connected') {
      return this.lt('Connection established. Opening remote desktop...');
    }
    if (coreState.sessionStage === 'error') {
      const errorText = coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage;
      return errorText.length > 0 ? errorText : this.lt('Connection failed');
    }
    if (coreState.detailMessage.length > 0) {
      return coreState.detailMessage;
    }
    if (coreState.statusSummary.length > 0) {
      return coreState.statusSummary;
    }
    if (peerId.length > 0) {
      return `${this.lt('Connecting to')} ${this.formatId(peerId)}...`;
    }
    return this.lt('Connecting...');
  }

  private resolvePendingDialogTitle(): string {
    const promptSource =
      `${this.officialCoreState.statusSummary}\n${this.officialCoreState.detailMessage}\n${this.officialCoreState.lastError}`;
    if (this.shouldPromptForPassword(promptSource)) {
      return this.lt('Enter RustDesk Password');
    }
    return this.lt('Connecting now');
  }

  private resolvePendingDialogSummary(): string {
    if (this.officialCoreState.statusSummary.trim().length > 0) {
      return this.officialCoreState.statusSummary.trim();
    }
    const peerId = this.pendingPeerId.trim().length > 0
      ? this.pendingPeerId.trim()
      : this.officialCoreState.activePeerId.trim();
    if (peerId.length > 0) {
      return `${this.lt('Connecting to')} ${this.formatId(peerId)}...`;
    }
    return this.lt('Connecting...');
  }

  private resolvePendingDialogDetail(): string {
    if (this.officialCoreState.lastError.trim().length > 0) {
      return this.officialCoreState.lastError.trim();
    }
    if (this.officialCoreState.detailMessage.trim().length > 0) {
      return this.officialCoreState.detailMessage.trim();
    }
    return this.lt('Enter remote password now, or save for next auto-fill.');
  }

  private shouldPromptForPassword(errorMsg: string): boolean {
    const normalized = errorMsg.toLowerCase();
    return errorMsg.includes('瀵嗙爜') ||
      errorMsg.includes('璁よ瘉') ||
      normalized.includes('password') ||
      normalized.includes('input-password') ||
      normalized.includes('re-input-password') ||
      normalized.includes('auth');
  }

  build() {
    Stack() {
      Column() {
        ForEach([`${this.i18nVersion}_${this.shareUiVersion}`], (_: string) => {
          if (this.currentTab === 'connect') {
            this.buildConnectPage()
          } else if (this.currentTab === 'chat') {
            this.buildChatOverview()
          } else if (this.currentTab === 'share') {
            this.buildShareOverview()
          } else {
            this.buildSettingsOverview()
          }
        }, (item: string, index: number) => `${item}_${index}`)
      }
      .width('100%')
      .height('100%')
      .opacity(this.i18nOpacity)
      .animation({ duration: 500, curve: Curve.EaseInOut })

      Column() {
        this.buildBottomTabBar()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, bottom: this.avoidNavigationBarHeight })
      .hitTestBehavior(HitTestMode.Transparent)

      if (this.recentMenuSessionId.length > 0) {
        this.buildRecentSessionMenu()
      }
      if (this.showSortMenu) {
        this.buildSortMenu()
      }
      if (this.showConnectTabVisibilityMenu) {
        this.buildConnectTabVisibilityMenu()
      }
      if (this.showPasswordDialog && this.pendingPeerId.trim().length > 0) {
        this.buildPasswordDialog()
      }
      if (this.showServerDialog) {
        this.buildServerDialog()
      }
      if (this.showLanguageDialog) {
        this.buildLanguageDialog()
      }
      if (this.showThemeDialog) {
        this.buildThemeDialog()
      }
      if (this.showDisplaySettingsDialog) {
        this.buildDisplaySettingsDialog()
      }
      if (this.showAccountDialog) {
        this.buildAccountDialog()
      }
      if (this.showRenameDialog) {
        this.buildRenameDialog()
      }
      if (this.showDirectAccessPortDialog) {
        this.buildDirectAccessPortDialog()
      }
      if (this.showProxyDialog) {
        this.buildProxyDialog()
      }
      if (this.showCoreDetailDialog) {
        this.buildCoreDetailDialog()
      }
      if (this.showShareStartWarning) {
        this.buildShareStartWarning()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .id(`root_${this.i18nVersion}`)
  }
}

