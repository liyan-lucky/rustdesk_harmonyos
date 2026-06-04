import rustdeskBridgeLibrary from 'librustdesk_bridge.so';
import { AppContextService } from './AppContextService';

export interface NativeBridgeSnapshot {
  adapter?: string;
  coreReady?: boolean;
  incomingReady?: boolean;
  displayId?: string;
  fingerprint?: string;
  directAddress?: string;
  statusSummary?: string;
  detailMessage?: string;
  server?: string;
  sessionStage?: string;
  activePeerId?: string;
  lastError?: string;
}

export interface NativeSessionEvent {
  kind?: string;
  detail?: string;
  peerId?: string;
  timestamp?: number;
}

export interface NativeVideoFrameMetadata {
  frameId?: number;
  display?: number;
  width?: number;
  height?: number;
  stride?: number;
  bytes?: number;
  timestamp?: number;
  format?: string;
}

export interface NativeVideoFrame {
  frameId: number;
  display: number;
  width: number;
  height: number;
  stride: number;
  bytes: number;
  timestamp: number;
  format: string;
  rgba: ArrayBuffer;
}

export interface NativeAccountUserInfo {
  name?: string;
  display_name?: string;
  avatar?: string;
  email?: string;
  status?: number;
  third_auth_type?: string;
}

export interface NativeAccountAuthBody {
  access_token?: string;
  type?: string;
  user?: NativeAccountUserInfo;
}

export interface NativeAccountAuthResult {
  state_msg?: string;
  failed_msg?: string;
  url?: string | null;
  auth_body?: NativeAccountAuthBody | null;
}

type NativePayload = Object | string | undefined | null;

export interface PeerInfo {
  hostname: string;
  username: string;
  platform: string;
  alias: string;
}

interface NamedModuleRecord {
  label: string;
  record: Record<string, Object | undefined>;
}

export interface NativeBridgeModule {
  loadCoreLibrary?: (path: string) => boolean;
  isCoreLoaded?: () => boolean;
  getCoreLoadInfo?: () => string;
  verifyCoreFile?: (path: string) => string;
  getCoreFileInfo?: (path: string) => string;
  initializeRuntime?: (appDir: string, customClientConfig: string) => string;
  getCoreSnapshot?: (server: string) => string;
  pullSessionEvents?: () => string;
  pullAudioFrames?: () => string;
  getLatestVideoFrameMetadata?: (sinceFrameId: number) => string | null;
  copyLatestVideoFrame?: (frameId: number, expectedBytes: number) => ArrayBuffer | null;
  refreshSessionVideo?: (display: number) => boolean;
  harmonyNextRgba?: (display: number) => void;
  connectToPeer?: (peerId: string, password: string, server: string, relayServer: string, apiServer: string) => void;
  accountAuth?: (op: string, rememberMe: boolean, server: string, relayServer: string, apiServer: string) => void;
  accountAuthCancel?: () => void;
  accountAuthResult?: () => string;
  getLocalOption?: (key: string) => string;
  getSessionToggleOption?: (key: string) => boolean;
  setLocalOption?: (key: string, value: string) => void;
  applySessionOption?: (key: string, value: string) => boolean;
  closeSession?: () => void;
  reconnectSession?: (forceRelay: boolean) => boolean;
  restartRemoteDevice?: () => boolean;
  lockRemoteScreen?: () => boolean;
  submitSessionPassword?: (password: string, remember: boolean) => boolean;
  setIncomingServiceEnabled?: (enabled: boolean, server: string, relayServer: string, apiServer: string) => string;
  bootstrapCoreSnapshot?: (displayId: string, fingerprint: string, directAddress: string, server: string) => string;
  sendMouseInput?: (mask: number, x: number, y: number) => boolean;
  sendKeyboardInput?: (keyCode: number, isPressed: boolean, modifiers: number) => boolean;
  sendCtrlAltDel?: () => boolean;
  sendClipboardData?: (content: string, timestamp: number) => boolean;
  sendVideoFrameMetadata?: (
    codec: number,
    width: number,
    height: number,
    timestamp: number,
    keyFrame: boolean,
    dataLength: number
  ) => boolean;
  sendAudioFrameMetadata?: (
    codec: number,
    sampleRate: number,
    channels: number,
    timestamp: number,
    dataLength: number
  ) => boolean;
  sendChatMessage?: (peerId: string, messageType: string, content: string, timestamp: number) => boolean;
  sendFileTransferRequest?: (
    taskId: string,
    peerId: string,
    fileName: string,
    totalBytes: number,
    direction: string
  ) => boolean;
  openTerminal?: (terminalId: number, rows: number, cols: number) => boolean;
  sendTerminalInput?: (terminalId: number, data: string) => boolean;
  resizeTerminal?: (terminalId: number, rows: number, cols: number) => boolean;
  closeTerminal?: (terminalId: number) => boolean;
  readRemoteDirectory?: (path: string, includeHidden: boolean) => boolean;
  createRemoteDirectory?: (path: string) => boolean;
  deleteRemotePath?: (path: string, isDirectory: boolean) => boolean;
  startFileTransfer?: (path: string, to: string, isRemote: boolean) => boolean;
  queryOnlines?: (idsJson: string) => boolean;
  discoverLanPeers?: () => boolean;
  removeDiscoveredPeer?: (peerId: string) => boolean;
}

export class NativeRustDeskBridge {
  private static readonly MODULE_CANDIDATES: string[] = [
    'librustdesk_bridge.so',
    'librustdesk_bridge',
    'rustdesk_bridge',
    'libentry.so',
    'entry'
  ];
  private static moduleCache?: NativeBridgeModule;
  private static runtimeInitialized: boolean = false;
  private static runtimeInitializationUnavailable: boolean = false;
  private static warnedMissingLoader: boolean = false;
  private static lastDebugSummary: string = '';
  private static lastModuleLoadSummary: string = '';
  private static cachedGetMetadataFn: ((sinceFrameId: number) => NativePayload) | null | undefined = undefined;
  private static cachedCopyFrameFn: ((frameId: number, bytes: number) => NativePayload) | null | undefined = undefined;

  static getModule(): NativeBridgeModule | null {
    if (NativeRustDeskBridge.moduleCache) {
      return NativeRustDeskBridge.moduleCache;
    }

    try {
      const staticModule = rustdeskBridgeLibrary as NativeBridgeModule;
      if (NativeRustDeskBridge.hasKnownBridgeFunction(staticModule)) {
        NativeRustDeskBridge.moduleCache = staticModule;
        NativeRustDeskBridge.warnedMissingLoader = false;
        NativeRustDeskBridge.setModuleLoadSummary(
          `module loaded via static import; ${NativeRustDeskBridge.describeModuleShape(staticModule)}`
        );
        return staticModule;
      }
      const staticRecord = staticModule as Record<string, Object | undefined>;
      const directNames = Object.getOwnPropertyNames(staticModule as Object);
      if (directNames.length > 0) {
        NativeRustDeskBridge.moduleCache = staticModule;
        NativeRustDeskBridge.warnedMissingLoader = false;
        NativeRustDeskBridge.setModuleLoadSummary(
          `module loaded via static import (forced); keys=${NativeRustDeskBridge.joinNames(directNames)}; ${NativeRustDeskBridge.describeModuleShape(staticModule)}`
        );
        return staticModule;
      }
    } catch (e) {
      console.warn('Static import failed:', e);
    }

    // Fallback to requireNapi
    const napiLoader = (globalThis as Object as Record<string, (name: string) => object>).requireNapi;
    if (typeof napiLoader !== 'function') {
      if (!NativeRustDeskBridge.warnedMissingLoader) {
        NativeRustDeskBridge.warnedMissingLoader = true;
        console.warn('NativeRustDeskBridge requireNapi is unavailable on globalThis; will retry later.');
      }
      NativeRustDeskBridge.setDebugSummary('requireNapi missing on globalThis');
      return null;
    }

    try {
      const attempts: string[] = [];
      let fallbackModule: NativeBridgeModule | null = null;
      for (let index = 0; index < NativeRustDeskBridge.MODULE_CANDIDATES.length; index += 1) {
        const candidateName = NativeRustDeskBridge.MODULE_CANDIDATES[index];
        try {
          const loaded = napiLoader(candidateName) as NativeBridgeModule;
          const shape = NativeRustDeskBridge.describeUnknownValue(loaded as NativePayload);
          const usable = NativeRustDeskBridge.hasKnownBridgeFunction(loaded);
          attempts.push(`${candidateName}:${usable ? 'usable' : 'unusable'}:${shape}`);
          if (usable) {
            NativeRustDeskBridge.moduleCache = loaded;
            NativeRustDeskBridge.warnedMissingLoader = false;
            NativeRustDeskBridge.setDebugSummary(
              `module loaded via ${candidateName}; ${NativeRustDeskBridge.describeModuleShape(loaded)}`
            );
            return loaded;
          }
          if (!fallbackModule && loaded !== null && loaded !== undefined) {
            fallbackModule = loaded;
          }
        } catch (error) {
          attempts.push(`${candidateName}:error:${NativeRustDeskBridge.describeError(error)}`);
        }
      }
      if (fallbackModule) {
        NativeRustDeskBridge.moduleCache = fallbackModule;
        NativeRustDeskBridge.warnedMissingLoader = false;
        NativeRustDeskBridge.setModuleLoadSummary(
          `module loaded but bridge funcs missing; ${NativeRustDeskBridge.truncate(attempts.join(' | '), 900)}`
        );
        return fallbackModule;
      }
      NativeRustDeskBridge.setModuleLoadSummary(
        `requireNapi returned no usable module; ${NativeRustDeskBridge.truncate(attempts.join(' | '), 900)}`
      );
      return null;
    } catch (error) {
      console.error('NativeRustDeskBridge requireNapi failed', JSON.stringify(error));
      NativeRustDeskBridge.setModuleLoadSummary(
        `requireNapi failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return null;
    }
  }

  static loadCoreLibrary(path: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const loadFn = NativeRustDeskBridge.resolveFunction<[string], boolean>(
      nativeModule,
      ['loadCoreLibrary']
    );
    if (!loadFn) {
      console.error('[NativeBridge] loadCoreLibrary function NOT FOUND');
      return false;
    }
    try {
      const result = loadFn(path);
      console.info(`[NativeBridge] loadCoreLibrary result: ${result}`);
      return result;
    } catch (error) {
      console.error('[NativeBridge] loadCoreLibrary EXCEPTION:', JSON.stringify(error));
      return false;
    }
  }

  static isCoreLoaded(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const isLoadedFn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isCoreLoaded']
    );
    if (!isLoadedFn) return false;
    try {
      return isLoadedFn();
    } catch (error) {
      return false;
    }
  }

  static getCoreLoadInfo(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const getInfoFn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getCoreLoadInfo']
    );
    if (!getInfoFn) return '{"loaded":false,"source":"unknown"}';
    try {
      return getInfoFn();
    } catch (error) {
      return '{"loaded":false,"source":"error"}';
    }
  }

  static verifyCoreFile(path: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[string], string>(
      nativeModule,
      ['verifyCoreFile']
    );
    if (!fn) return '{"exists":false,"validElf":false,"error":"function not found"}';
    try {
      return fn(path);
    } catch (error) {
      return `{"exists":false,"validElf":false,"error":"${String(error)}"}`;
    }
  }

  static getCoreFileInfo(path: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[string], string>(
      nativeModule,
      ['getCoreFileInfo']
    );
    if (!fn) return '{"exists":false,"error":"function not found"}';
    try {
      return fn(path);
    } catch (error) {
      return `{"exists":false,"error":"${String(error)}"}`;
    }
  }

  static resetForRetry(): void {
    NativeRustDeskBridge.moduleCache = undefined;
    NativeRustDeskBridge.runtimeInitialized = false;
    NativeRustDeskBridge.runtimeInitializationUnavailable = false;
  }

  static hasNativeModule(): boolean {
    return NativeRustDeskBridge.getModule() !== null;
  }

  static getLastDebugSummary(): string {
    return NativeRustDeskBridge.lastDebugSummary;
  }

  static getCombinedDebugSummary(): string {
    const current = NativeRustDeskBridge.lastDebugSummary.trim();
    const load = NativeRustDeskBridge.lastModuleLoadSummary.trim();
    if (current.length === 0) {
      return load;
    }
    if (load.length === 0 || current === load || current.indexOf(load) >= 0) {
      return current;
    }
    return NativeRustDeskBridge.truncate(`${current}; load=${load}`, 900);
  }

  static initializeRuntime(appDir: string, customClientConfig: string = ''): NativeBridgeSnapshot | null {
    console.info(`[NativeBridge] initializeRuntime START: appDir=${appDir.substring(0, 50)}`);
    const nativeModule = NativeRustDeskBridge.getModule();
    const initializeRuntimeFn = NativeRustDeskBridge.resolveFunction<[string, string], NativePayload>(
      nativeModule,
      ['initializeRuntime', 'initialize_runtime', 'rustdesk_bridge_initialize_runtime']
    );
    if (!initializeRuntimeFn) {
      console.error('[NativeBridge] initializeRuntime function NOT FOUND');
      NativeRustDeskBridge.runtimeInitializationUnavailable = true;
      NativeRustDeskBridge.setDebugSummary(
        `initializeRuntime missing; appDir=${NativeRustDeskBridge.sanitizeValue(appDir)}; ` +
          NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
            'initializeRuntime',
            'initialize_runtime',
            'rustdesk_bridge_initialize_runtime'
          ])
      );
      return null;
    }
    try {
      console.info('[NativeBridge] Calling initializeRuntimeFn...');
      const raw = initializeRuntimeFn(appDir, customClientConfig);
      console.info(`[NativeBridge] initializeRuntimeFn returned: type=${typeof raw}, value=${JSON.stringify(raw).substring(0, 200)}`);
      const parsed = NativeRustDeskBridge.parseJsonPayload<NativeBridgeSnapshot>(raw, 'initializeRuntime');
      console.info(`[NativeBridge] parseJsonPayload result: ${parsed ? 'SUCCESS' : 'NULL'}`);
      if (appDir.trim().length > 0) {
        NativeRustDeskBridge.runtimeInitialized = true;
      }
      if (parsed) {
        NativeRustDeskBridge.setDebugSummary(
          `initializeRuntime ok; appDir=${NativeRustDeskBridge.sanitizeValue(appDir)}; ` +
            `displayId=${NativeRustDeskBridge.sanitizeValue(parsed.displayId)}`
        );
      }
      return parsed;
    } catch (error) {
      console.error('[NativeBridge] initializeRuntime EXCEPTION:', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `initializeRuntime call failed ${NativeRustDeskBridge.describeError(error)}; ` +
          `appDir=${NativeRustDeskBridge.sanitizeValue(appDir)}`
      );
      return null;
    }
  }

  private static ensureRuntimeInitialized(nativeModule: NativeBridgeModule | null): void {
    if (NativeRustDeskBridge.runtimeInitialized || NativeRustDeskBridge.runtimeInitializationUnavailable || !nativeModule) {
      return;
    }
    const initializeRuntimeFn = NativeRustDeskBridge.resolveFunction<[string, string], string>(
      nativeModule,
      ['initializeRuntime', 'initialize_runtime', 'rustdesk_bridge_initialize_runtime']
    );
    if (!initializeRuntimeFn) {
      NativeRustDeskBridge.runtimeInitializationUnavailable = true;
      return;
    }
    const appDir = NativeRustDeskBridge.resolveAppDir();
    if (appDir.length === 0) {
      return;
    }
    NativeRustDeskBridge.initializeRuntime(appDir, '');
  }

  private static resolveAppDir(): string {
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

  static readSnapshot(server: string): NativeBridgeSnapshot | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const getCoreSnapshotFn = NativeRustDeskBridge.resolveFunction<[string], NativePayload>(
      nativeModule,
      ['getCoreSnapshot', 'get_core_snapshot', 'rustdesk_bridge_get_core_snapshot']
    );
    if (!getCoreSnapshotFn) {
      NativeRustDeskBridge.setDebugSummary(
        `getCoreSnapshot missing; server=${NativeRustDeskBridge.sanitizeValue(server)}; ` +
          NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
            'getCoreSnapshot',
            'get_core_snapshot',
            'rustdesk_bridge_get_core_snapshot'
          ])
      );
      return null;
    }
    try {
      const raw = getCoreSnapshotFn(server);
      const parsed = NativeRustDeskBridge.parseJsonPayload<NativeBridgeSnapshot>(raw, 'getCoreSnapshot');
      if (parsed) {
        NativeRustDeskBridge.setDebugSummary(
          `getCoreSnapshot ok; server=${NativeRustDeskBridge.sanitizeValue(server)}; ` +
            `displayId=${NativeRustDeskBridge.sanitizeValue(parsed.displayId)}`
        );
      }
      return parsed;
    } catch (error) {
      console.error('NativeRustDeskBridge readSnapshot failed', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `getCoreSnapshot call failed ${NativeRustDeskBridge.describeError(error)}; ` +
          `server=${NativeRustDeskBridge.sanitizeValue(server)}`
      );
      return null;
    }
  }

  static pullSessionEvents(): NativeSessionEvent[] {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const pullSessionEventsFn = NativeRustDeskBridge.resolveFunction<[], NativePayload>(
      nativeModule,
      ['pullSessionEvents', 'pull_session_events', 'rustdesk_bridge_pull_session_events']
    );
    if (!pullSessionEventsFn) {
      return [];
    }
    try {
      const raw = pullSessionEventsFn();
      const parsed = NativeRustDeskBridge.parseJsonPayload<NativeSessionEvent[]>(raw, 'pullSessionEvents');
      if (!parsed) {
        return [];
      }
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      console.error('NativeRustDeskBridge pullSessionEvents failed', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `pullSessionEvents call failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return [];
    }
  }

  static pullAudioFrames(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const pullAudioFramesFn = NativeRustDeskBridge.resolveFunction<[], NativePayload>(
      nativeModule,
      ['pullAudioFrames', 'pull_audio_frames', 'rustdesk_bridge_pull_audio_frames']
    );
    if (!pullAudioFramesFn) {
      return '[]';
    }
    try {
      const raw = pullAudioFramesFn();
      if (typeof raw === 'string') {
        return raw;
      }
      return '[]';
    } catch (error) {
      return '[]';
    }
  }

  static connectToPeer(peerId: string, password: string, server: string, relayServer: string, apiServer: string): boolean {
    console.info(`[NativeBridge] connectToPeer START: peerId=${peerId}, server=${server}`);

    const nativeModule = NativeRustDeskBridge.getModule();
    console.info(`[NativeBridge] Module: ${nativeModule ? 'LOADED' : 'NULL'}`);

    if (!nativeModule) {
      const errorMsg = 'connectToPeer failed: native module is NULL';
      console.error(`[NativeBridge] ERROR: ${errorMsg}`);
      NativeRustDeskBridge.setDebugSummary(errorMsg);
      return false;
    }

    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);

    let connectFn: ((peerId: string, password: string, server: string, relayServer: string, apiServer: string) => void) | null = null;

    const resolvedFn = NativeRustDeskBridge.resolveFunction<[string, string, string, string, string], void>(
      nativeModule,
      ['connectToPeer', 'connect_to_peer', 'rustdesk_bridge_connect_to_peer']
    );
    if (resolvedFn) {
      connectFn = resolvedFn;
    }

    if (!connectFn) {
      const directAccess = (nativeModule as Record<string, Object | undefined>)['connectToPeer'];
      if (typeof directAccess === 'function') {
        connectFn = directAccess as (peerId: string, password: string, server: string, relayServer: string, apiServer: string) => void;
        console.info('[NativeBridge] connectToPeer resolved via direct property access');
      }
    }

    if (!connectFn && nativeModule) {
      const defaultRecord = (nativeModule as Record<string, Object | undefined>)['default'];
      if (defaultRecord && typeof defaultRecord === 'object') {
        const defaultFn = (defaultRecord as Record<string, Object | undefined>)['connectToPeer'];
        if (typeof defaultFn === 'function') {
          connectFn = defaultFn as (peerId: string, password: string, server: string, relayServer: string, apiServer: string) => void;
          console.info('[NativeBridge] connectToPeer resolved via module.default.connectToPeer');
        }
      }
    }

    console.info(`[NativeBridge] connectFn: ${connectFn ? 'FOUND' : 'NOT FOUND'}`);

    if (!connectFn) {
      const moduleShape = NativeRustDeskBridge.describeModuleShape(nativeModule);
      const errorMsg = `connectToPeer missing; peerId=${NativeRustDeskBridge.sanitizeValue(peerId)}; ` +
        NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
          'connectToPeer',
          'connect_to_peer',
          'rustdesk_bridge_connect_to_peer'
        ]) + `; shape=${moduleShape}`;
      console.error(`[NativeBridge] ERROR: ${errorMsg}`);
      NativeRustDeskBridge.setDebugSummary(errorMsg);
      return false;
    }
    try {
      console.info(`[NativeBridge] Calling native connect function...`);
      connectFn(peerId, password, server, relayServer, apiServer);
      console.info(`[NativeBridge] Native connect returned SUCCESS`);
      NativeRustDeskBridge.setDebugSummary(
        `connectToPeer invoked; peerId=${NativeRustDeskBridge.sanitizeValue(peerId)}`
      );
      return true;
    } catch (error) {
      const errorMsg = `connectToPeer call failed ${NativeRustDeskBridge.describeError(error)}; peerId=${NativeRustDeskBridge.sanitizeValue(peerId)}`;
      console.error(`[NativeBridge] EXCEPTION: ${errorMsg}`);
      NativeRustDeskBridge.setDebugSummary(errorMsg);
      return false;
    }
  }

  static accountAuth(
    op: string,
    rememberMe: boolean,
    server: string,
    relayServer: string,
    apiServer: string
  ): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const accountAuthFn = NativeRustDeskBridge.resolveFunction<[string, boolean, string, string, string], void>(
      nativeModule,
      ['accountAuth', 'account_auth', 'rustdesk_bridge_account_auth']
    );
    if (!accountAuthFn) {
      NativeRustDeskBridge.setDebugSummary(
        `accountAuth missing; provider=${NativeRustDeskBridge.sanitizeValue(op)}; ` +
          NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
            'accountAuth',
            'account_auth',
            'rustdesk_bridge_account_auth'
          ])
      );
      return false;
    }
    try {
      accountAuthFn(op, rememberMe, server, relayServer, apiServer);
      NativeRustDeskBridge.setDebugSummary(
        `accountAuth invoked; provider=${NativeRustDeskBridge.sanitizeValue(op)}`
      );
      return true;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `accountAuth call failed ${NativeRustDeskBridge.describeError(error)}; ` +
          `provider=${NativeRustDeskBridge.sanitizeValue(op)}`
      );
      return false;
    }
  }

  static accountAuthCancel(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const cancelFn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['accountAuthCancel', 'account_auth_cancel', 'rustdesk_bridge_account_auth_cancel']
    );
    if (!cancelFn) {
      return false;
    }
    try {
      cancelFn();
      return true;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `accountAuthCancel failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static getAccountAuthResult(): NativeAccountAuthResult | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const resultFn = NativeRustDeskBridge.resolveFunction<[], NativePayload>(
      nativeModule,
      ['accountAuthResult', 'account_auth_result', 'rustdesk_bridge_account_auth_result']
    );
    if (!resultFn) {
      return null;
    }
    try {
      const raw = resultFn();
      return NativeRustDeskBridge.parseJsonPayload<NativeAccountAuthResult>(raw, 'accountAuthResult');
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `accountAuthResult failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return null;
    }
  }

  static getLocalOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const getOptionFn = NativeRustDeskBridge.resolveFunction<[string], NativePayload>(
      nativeModule,
      ['getLocalOption', 'get_local_option', 'rustdesk_bridge_get_local_option']
    );
    if (!getOptionFn) {
      return '';
    }
    try {
      const raw = getOptionFn(key);
      return typeof raw === 'string' ? raw : '';
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `getLocalOption failed ${NativeRustDeskBridge.describeError(error)}; key=${NativeRustDeskBridge.sanitizeValue(key)}`
      );
      return '';
    }
  }

  static getPeerOption(peerId: string, key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const getPeerOptionFn = NativeRustDeskBridge.resolveFunction<[string, string], NativePayload>(
      nativeModule,
      ['getPeerOption', 'get_peer_option', 'rustdesk_bridge_get_peer_option']
    );
    if (getPeerOptionFn) {
      try {
        const raw = getPeerOptionFn(peerId, key);
        return typeof raw === 'string' ? raw : '';
      } catch (_error) {}
    }
    return NativeRustDeskBridge.readPeerOptionFromFile(peerId, key);
  }

  private static readPeerOptionFromFile(peerId: string, key: string): string {
    try {
      const appDir = NativeRustDeskBridge.getLocalOption('app_dir');
      if (!appDir || appDir.length === 0) return '';
      const safePeerId = peerId.replace(/[:<>\/\\|?*]/g, '_');
      const configPath = `${appDir}/peers/${safePeerId}/config.toml`;
      const fs = globalThis.requireNapi('fileio') as Record<string, Object>;
      if (!fs || typeof fs.readFileSync !== 'function') return '';
      const content = (fs.readFileSync as Function)(configPath, { encoding: 'utf-8' });
      if (typeof content !== 'string' || content.length === 0) return '';
      let inOptionsSection = false;
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (trimmed === '[options]') {
          inOptionsSection = true;
          continue;
        }
        if (trimmed.startsWith('[')) {
          inOptionsSection = false;
          continue;
        }
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        const k = trimmed.substring(0, eqIdx).trim();
        let val = trimmed.substring(eqIdx + 1).trim();
        if (val.startsWith('"') && val.endsWith('"')) {
          val = val.substring(1, val.length - 1);
        }
        if (inOptionsSection && k === key) return val;
      }
      return '';
    } catch (_error) {
      return '';
    }
  }

  static getPeerInfo(peerId: string): PeerInfo {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const getPeerInfoFn = NativeRustDeskBridge.resolveFunction<[string], string>(
      nativeModule,
      ['getPeerInfo', 'get_peer_info', 'rustdesk_bridge_get_peer_info']
    );
    if (getPeerInfoFn) {
      try {
        const raw = getPeerInfoFn(peerId);
        if (typeof raw === 'string' && raw.length > 0) {
          const parsed = JSON.parse(raw) as Record<string, string>;
          return {
            hostname: parsed['hostname'] ?? '',
            username: parsed['username'] ?? '',
            platform: parsed['platform'] ?? '',
            alias: parsed['alias'] ?? '',
          };
        }
      } catch (_error) {}
    }
    return NativeRustDeskBridge.readPeerInfoFromFile(peerId);
  }

  private static readPeerInfoFromFile(peerId: string): PeerInfo {
    try {
      const appDir = NativeRustDeskBridge.getLocalOption('app_dir');
      if (!appDir || appDir.length === 0) {
        return { hostname: '', username: '', platform: '', alias: '' };
      }
      const safePeerId = peerId.replace(/[:<>\/\\|?*]/g, '_');
      const configPath = `${appDir}/peers/${safePeerId}/config.toml`;
      const fs = globalThis.requireNapi('fileio') as Record<string, Object>;
      if (!fs || typeof fs.readFileSync !== 'function') {
        return { hostname: '', username: '', platform: '', alias: '' };
      }
      const content = (fs.readFileSync as Function)(configPath, { encoding: 'utf-8' });
      if (typeof content !== 'string' || content.length === 0) {
        return { hostname: '', username: '', platform: '', alias: '' };
      }
      let hostname = '';
      let username = '';
      let platform = '';
      let alias = '';
      let inInfoSection = false;
      let inOptionsSection = false;
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (trimmed === '[info]') {
          inInfoSection = true;
          inOptionsSection = false;
          continue;
        }
        if (trimmed === '[options]') {
          inInfoSection = false;
          inOptionsSection = true;
          continue;
        }
        if (trimmed.startsWith('[')) {
          inInfoSection = false;
          inOptionsSection = false;
          continue;
        }
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        const key = trimmed.substring(0, eqIdx).trim();
        let val = trimmed.substring(eqIdx + 1).trim();
        if (val.startsWith('"') && val.endsWith('"')) {
          val = val.substring(1, val.length - 1);
        }
        if (inInfoSection) {
          if (key === 'hostname') hostname = val;
          else if (key === 'username') username = val;
          else if (key === 'platform') platform = val;
        }
        if (inOptionsSection && key === 'alias') {
          alias = val;
        }
      }
      return { hostname, username, platform, alias };
    } catch (_error) {
      return { hostname: '', username: '', platform: '', alias: '' };
    }
  }

  static setLocalOption(key: string, value: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const setOptionFn = NativeRustDeskBridge.resolveFunction<[string, string], void>(
      nativeModule,
      ['setLocalOption', 'set_local_option', 'rustdesk_bridge_set_local_option']
    );
    if (!setOptionFn) {
      return false;
    }
    try {
      setOptionFn(key, value);
      return true;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `setLocalOption failed ${NativeRustDeskBridge.describeError(error)}; key=${NativeRustDeskBridge.sanitizeValue(key)}`
      );
      return false;
    }
  }

  static queryOnlines(ids: string[]): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const queryFn = NativeRustDeskBridge.resolveFunction<[string], boolean>(
      nativeModule,
      ['queryOnlines', 'query_onlines', 'rustdesk_bridge_query_onlines']
    );
    if (!queryFn) {
      return false;
    }
    try {
      const idsJson = JSON.stringify(ids);
      return queryFn(idsJson) === true;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `queryOnlines failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static discoverLanPeers(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const discoverFn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['discoverLanPeers', 'discover_lan_peers', 'rustdesk_bridge_discover_lan_peers', 'main_discover']
    );
    if (!discoverFn) {
      console.error('[NativeBridge] discoverLanPeers function not found');
      return false;
    }
    try {
      discoverFn();
      return true;
    } catch (error) {
      console.error('[NativeBridge] discoverLanPeers failed:', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `discoverLanPeers failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static removeDiscoveredPeer(peerId: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const removeFn = NativeRustDeskBridge.resolveFunction<[string], boolean>(
      nativeModule,
      ['removeDiscoveredPeer', 'remove_discovered_peer', 'rustdesk_bridge_remove_discovered_peer', 'main_remove_discovered']
    );
    if (!removeFn) {
      return false;
    }
    try {
      return removeFn(peerId) === true;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `removeDiscoveredPeer failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static loadLanPeers(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const loadFn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['loadLanPeers', 'load_lan_peers', 'rustdesk_bridge_load_lan_peers', 'main_load_lan_peers']
    );
    if (!loadFn) {
      return '[]';
    }
    try {
      const result = loadFn();
      return typeof result === 'string' ? result : '[]';
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `loadLanPeers failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return '[]';
    }
  }

  static getSessionToggleOption(key: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const getOptionFn = NativeRustDeskBridge.resolveFunction<[string], boolean>(
      nativeModule,
      ['getSessionToggleOption', 'get_session_toggle_option', 'rustdesk_bridge_get_session_toggle_option']
    );
    if (!getOptionFn) {
      return false;
    }
    try {
      return getOptionFn(key) === true;
    } catch (_error) {
      return false;
    }
  }

  static applySessionOption(key: string, value: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const applyOptionFn = NativeRustDeskBridge.resolveFunction<[string, string], boolean>(
      nativeModule,
      ['applySessionOption', 'apply_session_option', 'rustdesk_bridge_apply_session_option']
    );
    if (!applyOptionFn) {
      return false;
    }
    try {
      return applyOptionFn(key, value) === true;
    } catch (_error) {
      return false;
    }
  }

  static closeSession(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const closeSessionFn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['closeSession', 'close_session', 'rustdesk_bridge_close_session']
    );
    if (!closeSessionFn) {
      return false;
    }
    closeSessionFn();
    return true;
  }

  static reconnectSession(forceRelay: boolean = false): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const reconnectSessionFn = NativeRustDeskBridge.resolveFunction<[boolean], boolean>(
      nativeModule,
      ['reconnectSession', 'reconnect_session', 'rustdesk_bridge_reconnect_session']
    );
    if (!reconnectSessionFn) {
      NativeRustDeskBridge.setDebugSummary(
        'reconnectSession missing; ' +
          NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
            'reconnectSession',
            'reconnect_session',
            'rustdesk_bridge_reconnect_session'
          ])
      );
      return false;
    }
    try {
      const reconnected = reconnectSessionFn(forceRelay) === true;
      NativeRustDeskBridge.setDebugSummary(`reconnectSession invoked; forceRelay=${forceRelay}`);
      return reconnected;
    } catch (error) {
      NativeRustDeskBridge.setDebugSummary(
        `reconnectSession failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static restartRemoteDevice(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const restartFn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['restartRemoteDevice', 'restart_remote_device', 'rustdesk_bridge_restart_remote_device']
    );
    if (!restartFn) {
      return false;
    }
    try {
      return restartFn() === true;
    } catch (_error) {
      return false;
    }
  }

  static lockRemoteScreen(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const lockFn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['lockRemoteScreen', 'lock_remote_screen', 'rustdesk_bridge_lock_remote_screen']
    );
    if (!lockFn) {
      return false;
    }
    try {
      return lockFn() === true;
    } catch (_error) {
      return false;
    }
  }

  static submitSessionPassword(password: string, remember: boolean = true): boolean {
    const normalizedPassword = password.trim();
    if (normalizedPassword.length === 0) {
      return false;
    }
    console.info(
      `[NativeBridge] submitSessionPassword START: length=${normalizedPassword.length}, remember=${remember}`
    );
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const submitPasswordFn = NativeRustDeskBridge.resolveFunction<[string, boolean], boolean>(
      nativeModule,
      ['submitSessionPassword', 'submit_session_password', 'rustdesk_bridge_submit_session_password']
    );
    console.info(`[NativeBridge] submitPasswordFn: ${submitPasswordFn ? 'FOUND' : 'NOT FOUND'}`);
    if (!submitPasswordFn) {
      NativeRustDeskBridge.setDebugSummary(
        'submitSessionPassword missing; ' +
          NativeRustDeskBridge.describeFunctionResolution(nativeModule, [
            'submitSessionPassword',
            'submit_session_password',
            'rustdesk_bridge_submit_session_password'
          ])
      );
      return false;
    }
    try {
      const submitted = submitPasswordFn(normalizedPassword, remember) === true;
      console.info(`[NativeBridge] Native submitSessionPassword returned ${submitted}`);
      NativeRustDeskBridge.setDebugSummary(
        `submitSessionPassword invoked; length=${normalizedPassword.length}; remember=${remember}`
      );
      return submitted;
    } catch (error) {
      console.error(
        `[NativeBridge] submitSessionPassword EXCEPTION: ${NativeRustDeskBridge.describeError(error)}`
      );
      NativeRustDeskBridge.setDebugSummary(
        `submitSessionPassword failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return false;
    }
  }

  static pullLatestVideoFrame(sinceFrameId: number): NativeVideoFrame | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (NativeRustDeskBridge.cachedGetMetadataFn === undefined) {
      NativeRustDeskBridge.cachedGetMetadataFn = NativeRustDeskBridge.resolveFunction<[number], NativePayload>(
        nativeModule,
        ['getLatestVideoFrameMetadata', 'get_latest_video_frame_metadata', 'rustdesk_bridge_get_latest_video_frame_metadata']
      );
    }
    const getMetadataFn = NativeRustDeskBridge.cachedGetMetadataFn;
    if (!getMetadataFn) {
      return null;
    }
    if (NativeRustDeskBridge.cachedCopyFrameFn === undefined) {
      NativeRustDeskBridge.cachedCopyFrameFn = NativeRustDeskBridge.resolveFunction<[number, number], NativePayload>(
        nativeModule,
        ['copyLatestVideoFrame', 'copy_latest_video_frame', 'rustdesk_bridge_copy_latest_video_frame']
      );
    }
    const copyFrameFn = NativeRustDeskBridge.cachedCopyFrameFn;
    if (!copyFrameFn) {
      return null;
    }

    try {
      const metadataRaw = getMetadataFn(sinceFrameId);
      if (metadataRaw === null || metadataRaw === undefined) {
        return null;
      }
      const metadata = NativeRustDeskBridge.parseJsonPayload<NativeVideoFrameMetadata>(
        metadataRaw,
        'getLatestVideoFrameMetadata'
      );
      if (!metadata) {
        return null;
      }

      const frameId = typeof metadata.frameId === 'number' ? metadata.frameId : 0;
      const width = typeof metadata.width === 'number' ? metadata.width : 0;
      const height = typeof metadata.height === 'number' ? metadata.height : 0;
      const stride = typeof metadata.stride === 'number' ? metadata.stride : width * 4;
      const bytes = typeof metadata.bytes === 'number' ? metadata.bytes : 0;
      const display = typeof metadata.display === 'number' ? metadata.display : 0;
      const timestamp = typeof metadata.timestamp === 'number' ? metadata.timestamp : 0;
      const format = typeof metadata.format === 'string' ? metadata.format : 'abgr';

      if (frameId <= 0 || width <= 0 || height <= 0 || bytes <= 0) {
        return null;
      }

      // Accept large forward jumps and only reject clearly older frames.
      const frameIdDiff = frameId - sinceFrameId;
      const isFrameValid = frameIdDiff > -3;
      
      if (!isFrameValid) {
        if (frameIdDiff <= -3) {
          console.warn(`[NativeBridge] Frame too old: frameId=${frameId}, sinceFrameId=${sinceFrameId}, diff=${frameIdDiff}`);
        }
        return null;
      }

      let actualFrameId = frameId;
      let actualDisplay = display;
      let actualWidth = width;
      let actualHeight = height;
      let actualStride = stride;
      let actualBytes = bytes;
      let actualTimestamp = timestamp;
      let actualFormat = format;
      let rgbaRaw = copyFrameFn(actualFrameId, actualBytes);
      let rgba = NativeRustDeskBridge.parseArrayBufferPayload(rgbaRaw);
      if (!rgba || rgba.byteLength !== actualBytes) {
        const retryMetadataRaw = getMetadataFn(0);
        const retryMetadata = NativeRustDeskBridge.parseJsonPayload<NativeVideoFrameMetadata>(
          retryMetadataRaw,
          'getLatestVideoFrameMetadataRetry'
        );
        const retryFrameId = typeof retryMetadata?.frameId === 'number' ? retryMetadata.frameId : 0;
        const retryWidth = typeof retryMetadata?.width === 'number' ? retryMetadata.width : 0;
        const retryHeight = typeof retryMetadata?.height === 'number' ? retryMetadata.height : 0;
        const retryBytes = typeof retryMetadata?.bytes === 'number' ? retryMetadata.bytes : 0;
        if (retryFrameId > actualFrameId && retryWidth > 0 && retryHeight > 0 && retryBytes > 0) {
          actualFrameId = retryFrameId;
          actualDisplay = typeof retryMetadata?.display === 'number' ? retryMetadata.display : actualDisplay;
          actualWidth = retryWidth;
          actualHeight = retryHeight;
          actualStride = typeof retryMetadata?.stride === 'number' ? retryMetadata.stride : actualWidth * 4;
          actualBytes = retryBytes;
          actualTimestamp = typeof retryMetadata?.timestamp === 'number' ? retryMetadata.timestamp : actualTimestamp;
          actualFormat = typeof retryMetadata?.format === 'string' ? retryMetadata.format : actualFormat;
          rgbaRaw = copyFrameFn(actualFrameId, actualBytes);
          rgba = NativeRustDeskBridge.parseArrayBufferPayload(rgbaRaw);
        }
      }
      if (!rgba || rgba.byteLength !== actualBytes) {
        console.warn(`[NativeBridge] Frame copy skipped: frameId=${actualFrameId}, expected=${actualBytes}, actual=${rgba ? rgba.byteLength : 0}`);
        NativeRustDeskBridge.setDebugSummary(
          `copyLatestVideoFrame skipped; frameId=${actualFrameId}; expected=${actualBytes}; actual=${rgba ? rgba.byteLength : 0}`
        );
        return null;
      }

      return {
        frameId: actualFrameId,
        display: actualDisplay,
        width: actualWidth,
        height: actualHeight,
        stride: actualStride,
        bytes: actualBytes,
        timestamp: actualTimestamp,
        format: actualFormat,
        rgba
      };
    } catch (error) {
      console.error('[NativeBridge] pullLatestVideoFrame exception:', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `pullLatestVideoFrame failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return null;
    }
  }

  static ackVideoFrame(frameId: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const ackFrameFn = NativeRustDeskBridge.resolveFunction<[number], void>(
      nativeModule,
      ['ackVideoFrame', 'ack_video_frame', 'rustdesk_bridge_ack_video_frame']
    );
    if (!ackFrameFn) {
      return;
    }
    try {
      ackFrameFn(frameId);
    } catch (error) {
      // ignore
    }
  }

  static refreshSessionVideo(display: number = 0): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const refreshVideoFn = NativeRustDeskBridge.resolveFunction<[number], boolean>(
      nativeModule,
      ['refreshSessionVideo', 'refresh_session_video', 'rustdesk_bridge_refresh_session_video']
    );
    if (!refreshVideoFn) {
      return false;
    }
    try {
      return refreshVideoFn(display) === true;
    } catch (error) {
      return false;
    }
  }

  static harmonyNextRgba(display: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const nextRgbaFn = NativeRustDeskBridge.resolveFunction<[number], void>(
      nativeModule,
      ['harmonyNextRgba', 'harmony_next_rgba', 'rustdesk_bridge_harmony_next_rgba']
    );
    if (!nextRgbaFn) {
      return;
    }
    try {
      nextRgbaFn(display);
    } catch (error) {
      // ignore
    }
  }

  static sendMouseInput(mask: number, x: number, y: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const sendMouseFn = NativeRustDeskBridge.resolveFunction<[number, number, number], boolean>(
      nativeModule,
      ['sendMouseInput', 'send_mouse_input', 'rustdesk_bridge_send_mouse_input']
    );
    if (!sendMouseFn) {
      return false;
    }
    try {
      return sendMouseFn(mask, x, y) === true;
    } catch (error) {
      return false;
    }
  }

  static setIncomingServiceEnabled(enabled: boolean, server: string, relayServer: string, apiServer: string): NativeBridgeSnapshot | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const setIncomingServiceEnabledFn = NativeRustDeskBridge.resolveFunction<[boolean, string, string, string], NativePayload>(
      nativeModule,
      ['setIncomingServiceEnabled', 'set_incoming_service_enabled', 'rustdesk_bridge_set_incoming_service_enabled']
    );
    if (!setIncomingServiceEnabledFn) {
      return null;
    }
    try {
      const raw = setIncomingServiceEnabledFn(enabled, server, relayServer, apiServer);
      return NativeRustDeskBridge.parseJsonPayload<NativeBridgeSnapshot>(raw, 'setIncomingServiceEnabled');
    } catch (error) {
      console.error('NativeRustDeskBridge setIncomingServiceEnabled failed', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `setIncomingServiceEnabled failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return null;
    }
  }

  static bootstrapCoreSnapshot(
    displayId: string,
    fingerprint: string,
    directAddress: string,
    server: string
  ): NativeBridgeSnapshot | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const bootstrapCoreSnapshotFn = NativeRustDeskBridge.resolveFunction<[string, string, string, string], NativePayload>(
      nativeModule,
      ['bootstrapCoreSnapshot', 'bootstrap_core_snapshot', 'rustdesk_bridge_bootstrap_core_snapshot']
    );
    if (!bootstrapCoreSnapshotFn) {
      return null;
    }
    try {
      const raw = bootstrapCoreSnapshotFn(displayId, fingerprint, directAddress, server);
      return NativeRustDeskBridge.parseJsonPayload<NativeBridgeSnapshot>(raw, 'bootstrapCoreSnapshot');
    } catch (error) {
      console.error('NativeRustDeskBridge bootstrapCoreSnapshot failed', JSON.stringify(error));
      NativeRustDeskBridge.setDebugSummary(
        `bootstrapCoreSnapshot failed ${NativeRustDeskBridge.describeError(error)}`
      );
      return null;
    }
  }

  static sendKeyboardInput(keyCode: number, isPressed: boolean, modifiers: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendKeyboardInput) {
      return false;
    }
    return nativeModule.sendKeyboardInput(keyCode, isPressed, modifiers) === true;
  }

  static sendCtrlAltDel(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendCtrlAltDel) {
      return false;
    }
    return nativeModule.sendCtrlAltDel() === true;
  }

  static sendClipboardData(content: string, timestamp: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendClipboardData) {
      return false;
    }
    return nativeModule.sendClipboardData(content, timestamp) === true;
  }

  static sendVideoFrameMetadata(
    codec: number,
    width: number,
    height: number,
    timestamp: number,
    keyFrame: boolean,
    dataLength: number
  ): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendVideoFrameMetadata) {
      return false;
    }
    return nativeModule.sendVideoFrameMetadata(codec, width, height, timestamp, keyFrame, dataLength) === true;
  }

  static sendAudioFrameMetadata(
    codec: number,
    sampleRate: number,
    channels: number,
    timestamp: number,
    dataLength: number
  ): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendAudioFrameMetadata) {
      return false;
    }
    return nativeModule.sendAudioFrameMetadata(codec, sampleRate, channels, timestamp, dataLength) === true;
  }

  static sendChatMessage(peerId: string, messageType: string, content: string, timestamp: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendChatMessage) {
      return false;
    }
    return nativeModule.sendChatMessage(peerId, messageType, content, timestamp) === true;
  }

  static sendFileTransferRequest(
    taskId: string,
    peerId: string,
    fileName: string,
    totalBytes: number,
    direction: string
  ): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendFileTransferRequest) {
      return false;
    }
    return nativeModule.sendFileTransferRequest(taskId, peerId, fileName, totalBytes, direction) === true;
  }

  static openTerminal(terminalId: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.openTerminal) {
      return false;
    }
    return nativeModule.openTerminal(terminalId, rows, cols) === true;
  }

  static sendTerminalInput(terminalId: number, data: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.sendTerminalInput) {
      return false;
    }
    return nativeModule.sendTerminalInput(terminalId, data) === true;
  }

  static resizeTerminal(terminalId: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.resizeTerminal) {
      return false;
    }
    return nativeModule.resizeTerminal(terminalId, rows, cols) === true;
  }

  static closeTerminal(terminalId: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.closeTerminal) {
      return false;
    }
    return nativeModule.closeTerminal(terminalId) === true;
  }

  static readRemoteDirectory(path: string, includeHidden: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.readRemoteDirectory) {
      return false;
    }
    return nativeModule.readRemoteDirectory(path, includeHidden) === true;
  }

  static createRemoteDirectory(path: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.createRemoteDirectory) {
      return false;
    }
    return nativeModule.createRemoteDirectory(path) === true;
  }

  static deleteRemotePath(path: string, isDirectory: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.deleteRemotePath) {
      return false;
    }
    return nativeModule.deleteRemotePath(path, isDirectory) === true;
  }

  static startFileTransfer(path: string, to: string, isRemote: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    if (!nativeModule?.startFileTransfer) {
      return false;
    }
    return nativeModule.startFileTransfer(path, to, isRemote) === true;
  }

  private static setDebugSummary(summary: string): void {
    const nextSummary = NativeRustDeskBridge.truncate(summary.trim(), 900);
    if (nextSummary.length === 0) {
      NativeRustDeskBridge.lastDebugSummary = nextSummary;
      return;
    }
    if (nextSummary === NativeRustDeskBridge.lastDebugSummary) {
      return;
    }
    NativeRustDeskBridge.lastDebugSummary = nextSummary;
    console.info(`NativeRustDeskBridge debug: ${NativeRustDeskBridge.lastDebugSummary}`);
  }

  private static setModuleLoadSummary(summary: string): void {
    NativeRustDeskBridge.lastModuleLoadSummary = NativeRustDeskBridge.truncate(summary.trim(), 900);
    NativeRustDeskBridge.lastDebugSummary = NativeRustDeskBridge.lastModuleLoadSummary;
    if (NativeRustDeskBridge.lastModuleLoadSummary.length > 0) {
      console.info(`NativeRustDeskBridge load: ${NativeRustDeskBridge.lastModuleLoadSummary}`);
    }
  }

  private static truncate(value: string, maxLength: number): string {
    if (value.length <= maxLength) {
      return value;
    }
    return `${value.substring(0, maxLength)}...`;
  }

  private static sanitizeValue(value: string | undefined): string {
    const normalized = value?.trim() ?? '';
    return normalized.length > 0 ? NativeRustDeskBridge.truncate(normalized, 120) : '<empty>';
  }

  private static describeError(error: Object): string {
    try {
      const serialized = JSON.stringify(error);
      if (typeof serialized === 'string' && serialized.length > 0) {
        return NativeRustDeskBridge.truncate(serialized, 240);
      }
    } catch (_) {}
    return NativeRustDeskBridge.truncate(`${error}`, 240);
  }

  private static safeOwnPropertyNames(record: Record<string, Object | undefined>): string[] {
    try {
      return Object.getOwnPropertyNames(record as Object);
    } catch (_) {
      return [];
    }
  }

  private static joinNames(names: string[]): string {
    if (names.length === 0) {
      return '-';
    }
    const limit = 8;
    const visible = names.slice(0, limit).join(',');
    return names.length > limit ? `${visible},+${names.length - limit}` : visible;
  }

  private static asRecord(value: Object | undefined): Record<string, Object | undefined> | null {
    if (!value) {
      return null;
    }
    const valueType = typeof value;
    if (valueType !== 'object' && valueType !== 'function') {
      return null;
    }
    return value as Record<string, Object | undefined>;
  }

  private static safeGet(record: Record<string, Object | undefined>, key: string): Object | undefined {
    try {
      return record[key];
    } catch (_) {
      return undefined;
    }
  }

  private static collectModuleRecords(nativeModule: NativeBridgeModule | null): NamedModuleRecord[] {
    const records: NamedModuleRecord[] = [];
    const pushRecord = (label: string, value: Object | undefined): void => {
      const record = NativeRustDeskBridge.asRecord(value);
      if (!record) {
        return;
      }
      for (let index = 0; index < records.length; index += 1) {
        if (records[index].record === record) {
          return;
        }
      }
      records.push({ label, record });
    };

    pushRecord('top', nativeModule as Object | undefined);
    if (records.length === 0) {
      return records;
    }

    const topRecord = records[0].record;
    pushRecord('top.default', NativeRustDeskBridge.safeGet(topRecord, 'default'));
    pushRecord('top.exports', NativeRustDeskBridge.safeGet(topRecord, 'exports'));
    pushRecord('top.rustdesk_bridge', NativeRustDeskBridge.safeGet(topRecord, 'rustdesk_bridge'));

    for (let index = 0; index < records.length; index += 1) {
      const current = records[index];
      if (current.label === 'top.default') {
        pushRecord('top.default.exports', NativeRustDeskBridge.safeGet(current.record, 'exports'));
      }
    }

    return records;
  }

  private static describeModuleShape(nativeModule: NativeBridgeModule | null): string {
    const records = NativeRustDeskBridge.collectModuleRecords(nativeModule);
    if (records.length === 0) {
      return 'records=none';
    }
    const parts: string[] = [];
    for (let index = 0; index < records.length; index += 1) {
      const current = records[index];
      const names = NativeRustDeskBridge.safeOwnPropertyNames(current.record);
      parts.push(`${current.label}[${NativeRustDeskBridge.joinNames(names)}]`);
    }
    return parts.join(' ');
  }

  private static describeUnknownValue(value: NativePayload): string {
    if (value === null) {
      return 'type=null';
    }
    if (value === undefined) {
      return 'type=undefined';
    }
    const valueType = typeof value;
    if (valueType === 'string') {
      const stringValue = value as string;
      return `type=string:${NativeRustDeskBridge.truncate(stringValue, 80)}`;
    }
    if (valueType !== 'object' && valueType !== 'function') {
      return `type=${valueType}`;
    }
    return `type=${valueType};${NativeRustDeskBridge.describeModuleShape(value as NativeBridgeModule)}`;
  }

  private static hasKnownBridgeFunction(nativeModule: NativeBridgeModule | null): boolean {
    const records = NativeRustDeskBridge.collectModuleRecords(nativeModule);
    if (records.length === 0) {
      if (nativeModule) {
        const topRecord = nativeModule as Record<string, Object | undefined>;
        const directNames = Object.getOwnPropertyNames(topRecord as Object);
        for (let i = 0; i < directNames.length; i += 1) {
          if (typeof topRecord[directNames[i]] === 'function') {
            return true;
          }
        }
      }
      return false;
    }
    const knownNames = [
      'initializeRuntime',
      'initialize_runtime',
      'rustdesk_bridge_initialize_runtime',
      'getCoreSnapshot',
      'get_core_snapshot',
      'rustdesk_bridge_get_core_snapshot',
      'pullSessionEvents',
      'pull_session_events',
      'rustdesk_bridge_pull_session_events',
      'pullAudioFrames',
      'pull_audio_frames',
      'rustdesk_bridge_pull_audio_frames',
      'connectToPeer',
      'connect_to_peer',
      'rustdesk_bridge_connect_to_peer',
      'closeSession',
      'close_session',
      'rustdesk_bridge_close_session',
      'reconnectSession',
      'reconnect_session',
      'rustdesk_bridge_reconnect_session',
      'setIncomingServiceEnabled',
      'set_incoming_service_enabled',
      'rustdesk_bridge_set_incoming_service_enabled',
      'bootstrapCoreSnapshot',
      'bootstrap_core_snapshot',
      'rustdesk_bridge_bootstrap_core_snapshot',
      'queryOnlines',
      'query_onlines',
      'rustdesk_bridge_query_onlines'
    ];
    for (let recordIndex = 0; recordIndex < records.length; recordIndex += 1) {
      const current = records[recordIndex].record;
      for (let nameIndex = 0; nameIndex < knownNames.length; nameIndex += 1) {
        if (typeof NativeRustDeskBridge.safeGet(current, knownNames[nameIndex]) === 'function') {
          return true;
        }
      }
    }
    if (nativeModule) {
      const topRecord = nativeModule as Record<string, Object | undefined>;
      for (let nameIndex = 0; nameIndex < knownNames.length; nameIndex += 1) {
        if (typeof topRecord[knownNames[nameIndex]] === 'function') {
          return true;
        }
      }
    }
    return false;
  }

  private static describeCandidateType(record: Record<string, Object | undefined>, key: string): string {
    try {
      const candidate = record[key];
      if (candidate === null) {
        return 'null';
      }
      return typeof candidate;
    } catch (error) {
      return `error:${NativeRustDeskBridge.describeError(error)}`;
    }
  }

  private static describeFunctionResolution(nativeModule: NativeBridgeModule | null, names: string[]): string {
    const records = NativeRustDeskBridge.collectModuleRecords(nativeModule);
    if (records.length === 0) {
      return 'records=none';
    }
    const parts: string[] = [];
    for (let recordIndex = 0; recordIndex < records.length; recordIndex += 1) {
      const current = records[recordIndex];
      const typeParts: string[] = [];
      for (let nameIndex = 0; nameIndex < names.length; nameIndex += 1) {
        const name = names[nameIndex];
        typeParts.push(`${name}:${NativeRustDeskBridge.describeCandidateType(current.record, name)}`);
      }
      parts.push(`${current.label}{${typeParts.join(',')}}`);
    }
    return parts.join(' ');
  }

  private static parseJsonPayload<T>(raw: NativePayload, action: string): T | null {
    if (typeof raw === 'string') {
      const rawString = raw as string;
      try {
        return JSON.parse(rawString) as T;
      } catch (error) {
        NativeRustDeskBridge.setDebugSummary(
          `${action} parse failed ${NativeRustDeskBridge.describeError(error)}; ` +
            `raw=${NativeRustDeskBridge.truncate(rawString, 240)}`
        );
        return null;
      }
    }
    if (raw && typeof raw === 'object') {
      return raw as T;
    }
    NativeRustDeskBridge.setDebugSummary(
      `${action} returned ${raw === null ? 'null' : typeof raw}; shape=${NativeRustDeskBridge.describeModuleShape(
        NativeRustDeskBridge.moduleCache ?? null
      )}`
    );
    return null;
  }

  private static parseArrayBufferPayload(raw: NativePayload): ArrayBuffer | null {
    if (raw instanceof ArrayBuffer) {
      return raw;
    }
    if (raw && typeof raw === 'object') {
      const candidateRecord = NativeRustDeskBridge.asRecord(raw);
      const bufferValue = candidateRecord ? NativeRustDeskBridge.safeGet(candidateRecord, 'buffer') : undefined;
      if (bufferValue instanceof ArrayBuffer) {
        return bufferValue;
      }
    }
    return null;
  }

  private static resolveFunction<TArgs extends Object[], TResult>(
    nativeModule: NativeBridgeModule | null,
    names: string[]
  ): ((...args: TArgs) => TResult) | null {
    if (!nativeModule) {
      return null;
    }
    const moduleRecords = NativeRustDeskBridge.collectModuleRecords(nativeModule);
    for (let recordIndex = 0; recordIndex < moduleRecords.length; recordIndex += 1) {
      const currentRecord = moduleRecords[recordIndex].record;
      for (let index = 0; index < names.length; index += 1) {
        const candidate = NativeRustDeskBridge.safeGet(currentRecord, names[index]);
        if (typeof candidate === 'function') {
          return candidate as (...args: TArgs) => TResult;
        }
      }
    }
    const topRecord = nativeModule as Record<string, Object | undefined>;
    for (let index = 0; index < names.length; index += 1) {
      const directCandidate = topRecord[names[index]];
      if (typeof directCandidate === 'function') {
        return directCandidate as (...args: TArgs) => TResult;
      }
    }
    return null;
  }
}
