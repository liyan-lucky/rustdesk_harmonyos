import { PreferenceStore } from './PreferenceStore';
import { AppContextService } from './AppContextService';
import { AppDataService, EffectiveServerConfig, LocalDeviceProfile, SettingsState } from './AppDataService';
import { NativeBridgeSnapshot, NativeRustDeskBridge, NativeSessionEvent } from './NativeRustDeskBridge';
import { OfficialSessionTextFormatter } from './OfficialSessionTextFormatter';

export interface OfficialCoreState {
  adapter: 'native-stub' | 'official-native';
  coreReady: boolean;
  incomingReady: boolean;
  displayId: string;
  fingerprint: string;
  directAddress: string;
  statusSummary: string;
  detailMessage: string;
  server: string;
  sessionStage: 'idle' | 'connecting' | 'connected' | 'error';
  activePeerId: string;
  lastError: string;
}

export interface OfficialSessionEvent {
  kind: string;
  detail: string;
  peerId: string;
  timestamp: number;
}

type OfficialSessionListener = (event: OfficialSessionEvent) => void;

export interface OnlineStatusResult {
  onlines: string[];
  offlines: string[];
}

type OnlineStatusListener = (result: OnlineStatusResult) => void;

interface StoredOfficialCoreState {
  adapter?: 'native-stub' | 'official-native';
  coreReady?: boolean;
  incomingReady?: boolean;
  displayId?: string;
  fingerprint?: string;
  directAddress?: string;
  statusSummary?: string;
  detailMessage?: string;
  server?: string;
  sessionStage?: 'idle' | 'connecting' | 'connected' | 'error';
  activePeerId?: string;
  lastError?: string;
}

export class OfficialRustDeskBridge {
  private static instance: OfficialRustDeskBridge;
  private state: OfficialCoreState = OfficialRustDeskBridge.createStubState('');
  private eventListeners: OfficialSessionListener[] = [];
  private onlineStatusListeners: OnlineStatusListener[] = [];
  private eventPumpTimer: number = -1;
  private runtimeBootstrapReady: boolean = false;
  private closeRequestedByUser: boolean = false;

  private constructor() {
    this.loadStoredState();
    this.startEventPump();
  }

  static getInstance(): OfficialRustDeskBridge {
    if (!OfficialRustDeskBridge.instance) {
      OfficialRustDeskBridge.instance = new OfficialRustDeskBridge();
    }
    return OfficialRustDeskBridge.instance;
  }

  getCoreState(): OfficialCoreState {
    return OfficialRustDeskBridge.copyCoreState(this.state);
  }

  async refresh(settings: SettingsState): Promise<OfficialCoreState> {
    this.loadStoredState();
    const serverConfig = AppDataService.resolveServerConfig(settings);
    const nativeSnapshot =
      this.readLiveSnapshot(serverConfig.idServer) ??
      NativeRustDeskBridge.readSnapshot(serverConfig.idServer);
    if (nativeSnapshot) {
      const normalizedState = OfficialRustDeskBridge.mergeNativeStateWithCurrentState(
        OfficialRustDeskBridge.normalizeNativeState(nativeSnapshot, serverConfig.idServer),
        this.state
      );
      this.state = this.closeRequestedByUser
        ? OfficialRustDeskBridge.applyCloseRequestedState(normalizedState)
        : normalizedState;
      this.persistState();
    } else if (NativeRustDeskBridge.hasNativeModule()) {
      this.state = OfficialRustDeskBridge.createBridgeAvailableState(serverConfig.idServer);
      this.persistState();
    } else if (!this.state.coreReady) {
      this.state = OfficialRustDeskBridge.createStubState(serverConfig.idServer);
    } else if (this.state.server !== serverConfig.idServer) {
      const updatedState = OfficialRustDeskBridge.copyCoreState(this.state);
      updatedState.server = serverConfig.idServer;
      this.state = updatedState;
      this.persistState();
    }
    return this.getCoreState();
  }

  private readLiveSnapshot(server: string): NativeBridgeSnapshot | null {
    const appDir = this.resolveAppDir();
    if (appDir.length === 0) {
      return null;
    }
    if (!this.runtimeBootstrapReady) {
      const bootstrapSnapshot = NativeRustDeskBridge.initializeRuntime(appDir, '');
      if (bootstrapSnapshot) {
        this.runtimeBootstrapReady = true;
        return bootstrapSnapshot;
      }
    }
    return NativeRustDeskBridge.readSnapshot(server.trim());
  }

  private resolveAppDir(): string {
    const context = AppContextService.getContext();
    if (!context) {
      return '';
    }
    const contextRecord = context as Object as Record<string, string | undefined>;
    const candidates = ['filesDir', 'databaseDir', 'cacheDir'];
    for (let index = 0; index < candidates.length; index += 1) {
      const value = contextRecord[candidates[index]];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim();
      }
    }
    return '';
  }

  buildLocalDeviceProfile(source: LocalDeviceProfile, coreState: OfficialCoreState): LocalDeviceProfile {
    return {
      id: coreState.displayId.length > 0 ? coreState.displayId : '',
      alias: source.alias,
      platform: source.platform,
      ip: source.ip,
      status: coreState.statusSummary,
      fingerprint: coreState.fingerprint,
      directAddress: coreState.directAddress
    };
  }

  async connectToPeer(peerId: string, _password: string, settings: SettingsState): Promise<void> {
    this.closeRequestedByUser = false;
    const serverConfig = AppDataService.resolveServerConfig(settings);
    const coreState = await this.refresh(settings);
    if (!coreState.coreReady && !NativeRustDeskBridge.hasNativeModule()) {
      const missingCoreState = OfficialRustDeskBridge.copyCoreState(coreState);
      missingCoreState.sessionStage = 'error';
      missingCoreState.activePeerId = peerId;
      missingCoreState.lastError = 'Native core missing';
      missingCoreState.statusSummary = 'Core not available';
      missingCoreState.detailMessage = '';
      this.state = missingCoreState;
      this.persistState();
      throw new Error('Native core not available. Cannot connect without native RustDesk core bridge.');
    }

    const connectingState = OfficialRustDeskBridge.copyCoreState(coreState);
    connectingState.adapter = 'official-native';
    connectingState.coreReady = true;
    connectingState.sessionStage = 'connecting';
    connectingState.activePeerId = peerId;
    connectingState.lastError = '';
      connectingState.statusSummary = `Connecting ${peerId}`;
      connectingState.detailMessage = '';
    this.state = connectingState;
    this.persistState();
    let invoked = NativeRustDeskBridge.connectToPeer(
      peerId,
      _password,
      serverConfig.idServer,
      serverConfig.relayServer,
      serverConfig.apiServer
    );
    if (!invoked) {
      NativeRustDeskBridge.resetForRetry();
      invoked = NativeRustDeskBridge.connectToPeer(
        peerId,
        _password,
        serverConfig.idServer,
        serverConfig.relayServer,
        serverConfig.apiServer
      );
    }
    if (!invoked) {
      const failedConnectState = OfficialRustDeskBridge.copyCoreState(this.state);
      failedConnectState.sessionStage = 'error';
      failedConnectState.lastError = 'Connect entry missing';
      failedConnectState.statusSummary = 'Connect entry not exported';
      const nativeDebug = NativeRustDeskBridge.getCombinedDebugSummary().trim();
      const moduleAvailable = NativeRustDeskBridge.hasNativeModule();
      const coreLoaded = NativeRustDeskBridge.isCoreLoaded();
      failedConnectState.detailMessage =
        `Native module did not export connect function. ` +
        `moduleAvailable=${moduleAvailable}, coreLoaded=${coreLoaded}` +
        (nativeDebug.length > 0 ? ` Debug: ${nativeDebug}` : '');
      this.state = failedConnectState;
      this.persistState();
      throw new Error(
        `Native core marked ready but connect entry not exported. ` +
        `moduleAvailable=${moduleAvailable}, coreLoaded=${coreLoaded}` +
        (nativeDebug.length > 0 ? ` Debug: ${nativeDebug}` : '')
      );
    }
  }

  requestSessionClose(): OfficialCoreState {
    this.closeRequestedByUser = true;
    NativeRustDeskBridge.closeSession();
    this.state = OfficialRustDeskBridge.applyCloseRequestedState(
      OfficialRustDeskBridge.copyCoreState(this.state)
    );
    this.persistState();
    return this.getCoreState();
  }

  resetCloseRequestedFlag(): void {
    this.closeRequestedByUser = false;
  }

  reconnectSession(forceRelay: boolean = false): boolean {
    this.closeRequestedByUser = false;
    const reconnected = NativeRustDeskBridge.reconnectSession(forceRelay);
    if (!reconnected) {
      return false;
    }
    const nextState = OfficialRustDeskBridge.copyCoreState(this.state);
    nextState.adapter = 'official-native';
    nextState.coreReady = true;
    nextState.sessionStage = 'connecting';
    nextState.lastError = '';
    nextState.statusSummary = forceRelay ? 'Connecting through relay' : 'Connecting';
    nextState.detailMessage = forceRelay ? 'Reconnecting through relay' : 'Retrying connection';
    this.state = nextState;
    this.persistState();
    return true;
  }

  submitSessionPassword(password: string, remember: boolean = true): boolean {
    const normalizedPassword = password.trim();
    if (normalizedPassword.length === 0) {
      return false;
    }
    this.closeRequestedByUser = false;
    const submitted = NativeRustDeskBridge.submitSessionPassword(normalizedPassword, remember);
    if (!submitted) {
      return false;
    }

    const nextState = OfficialRustDeskBridge.copyCoreState(this.state);
    nextState.adapter = 'official-native';
    nextState.coreReady = true;
    nextState.sessionStage = 'connecting';
    nextState.lastError = '';
    nextState.statusSummary = nextState.activePeerId.length > 0
      ? 'Submitting password to ' + nextState.activePeerId
      : 'Submitting session password';
    nextState.detailMessage = 'The current RustDesk password has been submitted. Waiting for the remote response.';
    this.state = nextState;
    this.persistState();
    return true;
  }

  async setIncomingServiceEnabled(enabled: boolean, settings: SettingsState): Promise<OfficialCoreState> {
    const serverConfig = AppDataService.resolveServerConfig(settings);
    const current = await this.refresh(settings);
    let nativeSnapshot = NativeRustDeskBridge.setIncomingServiceEnabled(
      enabled,
      serverConfig.idServer,
      serverConfig.relayServer,
      serverConfig.apiServer
    );
    if (!nativeSnapshot) {
      NativeRustDeskBridge.resetForRetry();
      nativeSnapshot = NativeRustDeskBridge.setIncomingServiceEnabled(
        enabled,
        serverConfig.idServer,
        serverConfig.relayServer,
        serverConfig.apiServer
      );
    }
    if (nativeSnapshot) {
      this.state = OfficialRustDeskBridge.normalizeNativeState(nativeSnapshot, serverConfig.idServer);
      this.persistState();
      return this.getCoreState();
    }
    if (!current.coreReady) {
      const incomingState = OfficialRustDeskBridge.copyCoreState(current);
      incomingState.incomingReady = false;
      incomingState.statusSummary = enabled
        ? 'Incoming blocked, waiting for core'
        : 'Incoming service stopped';
      incomingState.detailMessage = enabled
        ? 'Waiting for native core to register and start listening.'
        : '';
      this.state = incomingState;
      this.persistState();
      return this.getCoreState();
    }
    return this.getCoreState();
  }

  async bootstrapCoreSnapshot(
    displayId: string,
    fingerprint: string,
    directAddress: string,
    settings: SettingsState
  ): Promise<OfficialCoreState> {
    const serverConfig: EffectiveServerConfig = AppDataService.resolveServerConfig(settings);
    let nativeSnapshot = NativeRustDeskBridge.bootstrapCoreSnapshot(
      displayId,
      fingerprint,
      directAddress,
      serverConfig.idServer
    );
    if (!nativeSnapshot) {
      NativeRustDeskBridge.resetForRetry();
      nativeSnapshot = NativeRustDeskBridge.bootstrapCoreSnapshot(
        displayId,
        fingerprint,
        directAddress,
        serverConfig.idServer
      );
    }
    if (nativeSnapshot) {
      this.state = OfficialRustDeskBridge.normalizeNativeState(nativeSnapshot, serverConfig.idServer);
      this.persistState();
      return this.getCoreState();
    }
    const bootstrapState = OfficialRustDeskBridge.copyCoreState(this.state);
    bootstrapState.adapter = 'native-stub';
    bootstrapState.coreReady = false;
    bootstrapState.statusSummary = 'Bootstrap entry missing';
    const nativeDebug = NativeRustDeskBridge.getCombinedDebugSummary().trim();
    const moduleAvailable = NativeRustDeskBridge.hasNativeModule();
    bootstrapState.detailMessage =
      `NAPI loaded but native module did not export bootstrapCoreSnapshot. ` +
      `moduleAvailable=${moduleAvailable}` +
      (nativeDebug.length > 0 ? ` Debug: ${nativeDebug}` : '');
    bootstrapState.lastError = 'bootstrapCoreSnapshot not exported';
    this.state = bootstrapState;
    this.persistState();
    return this.getCoreState();
  }

  pullSessionEvents(): OfficialSessionEvent[] {
    const events = NativeRustDeskBridge.pullSessionEvents();
    const normalizedEvents: OfficialSessionEvent[] = [];
    events.forEach((event: NativeSessionEvent) => {
      const normalizedEvent: OfficialSessionEvent = {
        kind: event.kind?.trim() ?? 'unknown',
        detail: OfficialSessionTextFormatter.formatDetail(event.detail?.trim() ?? ''),
        peerId: event.peerId?.trim() ?? '',
        timestamp: typeof event.timestamp === 'number' ? event.timestamp : 0
      };
      normalizedEvents.push(normalizedEvent);
    });
    return normalizedEvents;
  }

  addEventListener(listener: OfficialSessionListener): void {
    this.eventListeners.push(listener);
  }

  removeEventListener(listener: OfficialSessionListener): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  addOnlineStatusListener(listener: OnlineStatusListener): void {
    this.onlineStatusListeners.push(listener);
  }

  removeOnlineStatusListener(listener: OnlineStatusListener): void {
    const index = this.onlineStatusListeners.indexOf(listener);
    if (index > -1) {
      this.onlineStatusListeners.splice(index, 1);
    }
  }

  queryOnlines(ids: string[]): boolean {
    return NativeRustDeskBridge.queryOnlines(ids);
  }

  discoverLanPeers(): boolean {
    return NativeRustDeskBridge.discoverLanPeers();
  }

  removeDiscoveredPeer(peerId: string): boolean {
    return NativeRustDeskBridge.removeDiscoveredPeer(peerId);
  }

  loadLanPeers(): string {
    return NativeRustDeskBridge.loadLanPeers();
  }

  private startEventPump(): void {
    if (this.eventPumpTimer !== -1) {
      return;
    }
    
    let lastEventTime = Date.now();
    const handshakeTimeout = 30000; // 30秒握手超时
    
    this.eventPumpTimer = setInterval(() => {
      const events = this.pullSessionEvents();
      
      // 握手诊断：检测超时
      if (this.state.sessionStage === 'connecting') {
        const elapsed = Date.now() - lastEventTime;
        if (events.length === 0 && elapsed > 5000) {
          console.warn(`[HANDSHAKE_DIAG] No events for ${elapsed}ms, stage=${this.state.sessionStage}, peerId=${this.state.activePeerId}`);
        }
        if (elapsed > handshakeTimeout) {
          console.error(`[HANDSHAKE_DIAG] Handshake timeout after ${elapsed}ms`);
        }
      }
      
      if (events.length === 0) {
        return;
      }
      
      lastEventTime = Date.now();
      
      events.forEach((event: OfficialSessionEvent) => {
        if (!this.shouldLogEvent(event.kind)) {
          return;
        }
        console.log(
          `[HANDSHAKE_DIAG] Event: ${event.kind}, detail: ${event.detail.substring(0, 100)}, peerId: ${event.peerId}`
        );
      });
      
      const hasListeners = this.eventListeners.length > 0;
      events.forEach((event: OfficialSessionEvent) => {
        if (hasListeners) {
          this.dispatchEvent(event);
        } else {
          this.applyEventToState(event);
        }
      });
    }, 150);
  }

  private shouldLogEvent(kind: string): boolean {
    return kind !== 'video-frame' &&
      kind !== 'video-refresh-requested' &&
      kind !== 'display' &&
      kind !== 'switch-display' &&
      kind !== 'cursor_position' &&
      kind !== 'cursor_data';
  }

  private dispatchEvent(event: OfficialSessionEvent): void {
    this.applyEventToState(event);
    this.eventListeners.forEach((listener: OfficialSessionListener) => {
      try {
        listener(event);
      } catch (error) {
        console.error('OfficialRustDeskBridge dispatchEvent failed', JSON.stringify(error));
      }
    });
  }

  private applyEventToState(event: OfficialSessionEvent): void {
    if (this.closeRequestedByUser &&
      (event.kind === 'session-error' ||
        event.kind === 'session-connected' ||
        event.kind === 'peer-info' ||
        event.kind === 'connection-type' ||
        event.kind === 'video-frame' ||
        event.kind === 'msgbox')) {
      return;
    }

    const nextState = OfficialRustDeskBridge.copyCoreState(this.state);
    let changed = false;
    const normalizedPeerId = event.peerId.trim();
    const normalizedDetail = OfficialSessionTextFormatter.formatDetail(event.detail).trim();

    if (normalizedPeerId.length > 0 && nextState.activePeerId !== normalizedPeerId) {
      nextState.activePeerId = normalizedPeerId;
      changed = true;
    }

    if (event.kind === 'connect-requested' ||
      event.kind === 'login-requested' ||
      event.kind === 'login' ||
      event.kind === 'reconnect' ||
      event.kind === 'reconnect-relay') {
      this.closeRequestedByUser = false;
      nextState.coreReady = true;
      nextState.adapter = 'official-native';
      nextState.sessionStage = 'connecting';
      nextState.lastError = '';
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
      }
      if (event.kind === 'login-requested' || event.kind === 'login') {
        nextState.statusSummary = nextState.activePeerId.length > 0
          ? `Submitting password for ${nextState.activePeerId}`
          : 'Submitting password';
      } else if (event.kind === 'reconnect' || event.kind === 'reconnect-relay') {
        nextState.statusSummary = event.kind === 'reconnect-relay' ? 'Connecting through relay' : 'Connecting';
      } else {
        nextState.statusSummary = nextState.activePeerId.length > 0
          ? `Connecting ${nextState.activePeerId}`
          : 'Connecting';
      }
      changed = true;
    } else if (event.kind === 'session-connected' || event.kind === 'connection-ready') {
      nextState.coreReady = true;
      nextState.adapter = 'official-native';
      nextState.sessionStage = 'connected';
      nextState.lastError = '';
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
      }
      nextState.statusSummary = nextState.activePeerId.length > 0
        ? `Connected ${nextState.activePeerId}`
        : 'Connected';
      changed = true;
    } else if (event.kind === 'session-error') {
      nextState.sessionStage = 'error';
      nextState.lastError = normalizedDetail.length > 0 ? normalizedDetail : nextState.lastError;
      nextState.statusSummary = OfficialSessionTextFormatter.deriveErrorSummary(normalizedDetail);
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
      }
      changed = true;
    } else if (event.kind === 'session-closed' || event.kind === 'closed') {
      nextState.sessionStage = 'idle';
      nextState.lastError = '';
      if (normalizedPeerId.length > 0) {
        nextState.activePeerId = normalizedPeerId;
      }
      nextState.statusSummary = 'Session closed';
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
      }
      changed = true;
    } else if (event.kind === 'peer-info' || event.kind === 'connection-type') {
      nextState.coreReady = true;
      nextState.adapter = 'official-native';
      if (nextState.sessionStage !== 'connected') {
        nextState.sessionStage = 'connected';
        changed = true;
      }
      if (nextState.lastError.length > 0) {
        nextState.lastError = '';
        changed = true;
      }
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
        changed = true;
      }
    } else if (event.kind === 'video-frame') {
      nextState.coreReady = true;
      nextState.adapter = 'official-native';
      if (nextState.sessionStage !== 'connected') {
        nextState.sessionStage = 'connected';
        changed = true;
      }
      if (nextState.lastError.length > 0) {
        nextState.lastError = '';
        changed = true;
      }
    } else if (event.kind === 'msgbox') {
      const parsedMessageBox = OfficialSessionTextFormatter.parseMessageBox(event.detail);
      if (normalizedDetail.length > 0) {
        nextState.detailMessage = normalizedDetail;
        changed = true;
      }
      if (parsedMessageBox) {
        const summary = OfficialSessionTextFormatter.deriveMessageBoxSummary(parsedMessageBox);
        if (summary.length > 0 && nextState.statusSummary !== summary) {
          nextState.statusSummary = summary;
          changed = true;
        }
        if (OfficialSessionTextFormatter.isBlockingMessageBox(parsedMessageBox)) {
          nextState.sessionStage = 'error';
          nextState.lastError = normalizedDetail;
          changed = true;
        } else if (parsedMessageBox.msgType.trim() === 'input-password' ||
          parsedMessageBox.msgType.trim() === 're-input-password') {
          nextState.sessionStage = 'connecting';
          if (nextState.lastError.length > 0) {
            nextState.lastError = '';
          }
          changed = true;
        } else if (parsedMessageBox.msgType.trim() === 'wait-remote-accept-nook' ||
          parsedMessageBox.msgType.trim() === 'relay-hint' ||
          parsedMessageBox.msgType.trim() === 'relay-hint2') {
          nextState.sessionStage = 'connecting';
          if (nextState.lastError.length > 0) {
            nextState.lastError = '';
          }
          changed = true;
        } else if (parsedMessageBox.msgType.trim() === 'success') {
          nextState.sessionStage = 'connected';
          if (nextState.lastError.length > 0) {
            nextState.lastError = '';
          }
          changed = true;
        }
      }
    } else if (event.kind === 'callback-query-online' || event.kind === 'query-onlines-result') {
      console.info('[Bridge] query-online event kind:', event.kind, 'detail:', event.detail, 'peerId:', event.peerId);
      try {
        const dataStr = event.detail.trim().length > 0 ? event.detail : event.peerId;
        const parsed = JSON.parse(dataStr) as Record<string, string[]>;
        if (parsed && (parsed.onlines || parsed.offlines)) {
          const result: OnlineStatusResult = {
            onlines: Array.isArray(parsed.onlines) ? parsed.onlines : [],
            offlines: Array.isArray(parsed.offlines) ? parsed.offlines : [],
          };
          console.info('[Bridge] query-online result onlines:', result.onlines.length, 'offlines:', result.offlines.length);
          this.onlineStatusListeners.forEach((listener: OnlineStatusListener) => {
            try { listener(result); } catch (_e) {}
          });
        } else {
          console.info('[Bridge] query-online parsed but no onlines/offlines:', JSON.stringify(parsed));
        }
      } catch (_parseError) {
        console.error('[Bridge] query-online parse error:', event.detail, event.peerId);
      }
    }

    if (!changed) {
      return;
    }

    this.state = nextState;
    this.persistState();
  }

  private loadStoredState(): void {
    const raw = PreferenceStore.getOfficialCoreSnapshot();
    if (!raw) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as StoredOfficialCoreState;
      this.state = OfficialRustDeskBridge.normalizeStoredState(parsed);
    } catch (error) {
      console.error('OfficialRustDeskBridge loadStoredState failed', JSON.stringify(error));
      this.state = OfficialRustDeskBridge.createStubState('');
    }
  }

  private persistState(): void {
    PreferenceStore.setOfficialCoreSnapshot(JSON.stringify(this.state));
  }

  private static normalizeStoredState(parsed: StoredOfficialCoreState): OfficialCoreState {
    const detailMessage = OfficialSessionTextFormatter.formatDetail(parsed.detailMessage?.trim() ?? '');
    const lastError = OfficialSessionTextFormatter.formatDetail(parsed.lastError?.trim() ?? '');
    const state: OfficialCoreState = {
      adapter: parsed.adapter === 'official-native' ? 'official-native' : 'native-stub',
      coreReady: parsed.coreReady === true,
      incomingReady: parsed.incomingReady === true,
      displayId: parsed.displayId?.trim() ?? '',
      fingerprint: parsed.fingerprint?.trim() ?? '',
      directAddress: parsed.directAddress?.trim() ?? '',
      statusSummary: parsed.statusSummary?.trim() ?? '',
      detailMessage: parsed.detailMessage?.trim() ?? '',
      server: parsed.server?.trim() ?? '',
      sessionStage: parsed.sessionStage ?? 'idle',
      activePeerId: parsed.activePeerId?.trim() ?? '',
      lastError: parsed.lastError?.trim() ?? ''
    };
    state.statusSummary = state.statusSummary.length > 0
      ? OfficialSessionTextFormatter.formatSummary(state.statusSummary)
      : (state.coreReady ? 'Official Harmony bridge ready' : '');
    state.detailMessage = detailMessage.length > 0 ? detailMessage : '';
    state.lastError = lastError;
    return state;
  }

  private static normalizeNativeState(snapshot: NativeBridgeSnapshot, server: string): OfficialCoreState {
    const rawDetailMessage = snapshot.detailMessage?.trim() ?? '';
    const detailMessage = OfficialSessionTextFormatter.formatDetail(rawDetailMessage);
    const lastError = OfficialSessionTextFormatter.formatDetail(snapshot.lastError?.trim() ?? '');
    const state: OfficialCoreState = {
      adapter: snapshot.adapter === 'official-native' ? 'official-native' : 'native-stub',
      coreReady: snapshot.coreReady === true,
      incomingReady: snapshot.incomingReady === true,
      displayId: snapshot.displayId?.trim() ?? '',
      fingerprint: snapshot.fingerprint?.trim() ?? '',
      directAddress: snapshot.directAddress?.trim() ?? '',
      statusSummary: snapshot.statusSummary?.trim() ?? '',
      detailMessage: snapshot.detailMessage?.trim() ?? '',
      server: snapshot.server?.trim() ?? server,
      sessionStage: OfficialRustDeskBridge.normalizeSessionStage(snapshot.sessionStage),
      activePeerId: snapshot.activePeerId?.trim() ?? '',
      lastError: snapshot.lastError?.trim() ?? ''
    };
    state.statusSummary = state.statusSummary.length > 0
      ? OfficialSessionTextFormatter.formatSummary(state.statusSummary)
      : (state.coreReady ? 'Official Harmony bridge ready' : '');
    state.detailMessage = detailMessage.length > 0 ? detailMessage : '';
    state.lastError = lastError;
    return OfficialRustDeskBridge.applyNativeMessageBoxState(state, rawDetailMessage);
  }

  private static mergeNativeStateWithCurrentState(nativeState: OfficialCoreState, currentState: OfficialCoreState): OfficialCoreState {
    if (nativeState.sessionStage !== 'idle' || currentState.sessionStage === 'idle') {
      return nativeState;
    }
    if (currentState.sessionStage !== 'connecting') {
      return nativeState;
    }

    const mergedState = OfficialRustDeskBridge.copyCoreState(nativeState);
    mergedState.sessionStage = currentState.sessionStage;
    mergedState.activePeerId = nativeState.activePeerId.length > 0 ? nativeState.activePeerId : currentState.activePeerId;
    mergedState.statusSummary = nativeState.statusSummary.length > 0 &&
      nativeState.statusSummary !== 'Official Harmony bridge ready'
      ? nativeState.statusSummary
      : currentState.statusSummary;
    mergedState.detailMessage = nativeState.detailMessage.length > 0 ? nativeState.detailMessage : currentState.detailMessage;
    mergedState.lastError = nativeState.lastError.length > 0 ? nativeState.lastError : currentState.lastError;
    return mergedState;
  }

  private static applyNativeMessageBoxState(state: OfficialCoreState, rawDetailMessage: string): OfficialCoreState {
    const parsedMessageBox = OfficialSessionTextFormatter.parseMessageBox(rawDetailMessage);
    if (!parsedMessageBox) {
      return state;
    }

    const nextState = OfficialRustDeskBridge.copyCoreState(state);
    const formattedDetail = OfficialSessionTextFormatter.formatDetail(rawDetailMessage);
    const derivedSummary = OfficialSessionTextFormatter.deriveMessageBoxSummary(parsedMessageBox);
    const msgType = parsedMessageBox.msgType.trim();

    if (formattedDetail.length > 0) {
      nextState.detailMessage = formattedDetail;
    }
    if (derivedSummary.length > 0) {
      nextState.statusSummary = derivedSummary;
    }

    if (OfficialSessionTextFormatter.isBlockingMessageBox(parsedMessageBox)) {
      nextState.sessionStage = 'error';
      if (formattedDetail.length > 0) {
        nextState.lastError = formattedDetail;
      }
      return nextState;
    }

    if (msgType === 're-input-password') {
      nextState.sessionStage = 'connecting';
      if (formattedDetail.length > 0) {
        nextState.detailMessage = formattedDetail;
      }
      nextState.lastError = '';
      return nextState;
    }

    if (msgType === 'input-password' ||
      msgType === 'wait-remote-accept-nook' ||
      msgType === 'relay-hint' ||
      msgType === 'relay-hint2') {
      nextState.sessionStage = 'connecting';
      nextState.lastError = '';
      return nextState;
    }

    if (msgType === 'success') {
      nextState.sessionStage = 'connected';
      nextState.lastError = '';
      return nextState;
    }

    return nextState;
  }

  private static applyCloseRequestedState(source: OfficialCoreState): OfficialCoreState {
    const nextState = OfficialRustDeskBridge.copyCoreState(source);
    nextState.adapter = 'official-native';
    nextState.sessionStage = 'idle';
    nextState.activePeerId = '';
    nextState.lastError = '';
    nextState.statusSummary = 'Session closed';
    nextState.detailMessage = '';
    return nextState;
  }

  private static createStubState(server: string): OfficialCoreState {
    const normalizedServer = server.trim();
    return {
      adapter: 'native-stub',
      coreReady: false,
      incomingReady: false,
      displayId: '',
      fingerprint: '',
      directAddress: '',
      statusSummary: '',
      detailMessage: '',
      server: normalizedServer,
      sessionStage: 'idle',
      activePeerId: '',
      lastError: ''
    };
  }

  private static createBridgeAvailableState(server: string): OfficialCoreState {
    const normalizedServer = server.trim();
    return {
      adapter: 'official-native',
      coreReady: true,
      incomingReady: false,
      displayId: '',
      fingerprint: '',
      directAddress: '',
      statusSummary: 'Official Harmony bridge ready',
      detailMessage: '',
      server: normalizedServer,
      sessionStage: 'idle',
      activePeerId: '',
      lastError: ''
    };
  }

  private static normalizeSessionStage(value?: string): 'idle' | 'connecting' | 'connected' | 'error' {
    if (value === 'connecting' || value === 'connected' || value === 'error') {
      return value;
    }
    return 'idle';
  }

  private static copyCoreState(source: OfficialCoreState): OfficialCoreState {
    return {
      adapter: source.adapter,
      coreReady: source.coreReady,
      incomingReady: source.incomingReady,
      displayId: source.displayId,
      fingerprint: source.fingerprint,
      directAddress: source.directAddress,
      statusSummary: source.statusSummary,
      detailMessage: source.detailMessage,
      server: source.server,
      sessionStage: source.sessionStage,
      activePeerId: source.activePeerId,
      lastError: source.lastError
    };
  }
}
