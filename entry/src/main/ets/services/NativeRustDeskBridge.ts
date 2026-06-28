import rustdeskBridgeLibrary from 'librustdesk_bridge.so';
import { AppContextService } from './AppContextService';
import hilog from '@ohos.hilog';

export interface NativeBridgeSnapshot {
  adapter?: string;
  coreReady?: boolean;
  incomingReady?: boolean;
  captureRequired?: boolean;
  incomingFramePayloadReady?: boolean;
  incomingFrameId?: number;
  incomingFrameBytes?: number;
  incomingFramesSeen?: number;
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
  getIncomingScreenFrameMetadata?: (sinceFrameId: number) => string | null;
  copyIncomingScreenFrame?: (frameId: number, expectedBytes: number) => ArrayBuffer | null;
  updateIncomingScreenFrame?: (
    width: number,
    height: number,
    stride: number,
    timestamp: number,
    format: string,
    data: ArrayBuffer | Uint8Array
  ) => boolean;
  clearIncomingScreenFrame?: () => void;
  refreshSessionVideo?: (display: number) => boolean;
  harmonyNextRgba?: (display: number) => void;
  connectToPeer?: (peerId: string, password: string, server: string, relayServer: string, apiServer: string, key: string) => void;
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
  setIncomingServiceEnabled?: (enabled: boolean, server: string, relayServer: string, apiServer: string, key: string) => string;
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
  startNativeScreenCapture?: (width: number, height: number, frameRate: number) => boolean;
  stopNativeScreenCapture?: () => boolean;
  isNativeScreenCaptureActive?: () => boolean;
  getNativeScreenCaptureStats?: () => string;
  requestInputInjectionAuthorization?: () => number;
  getInputInjectionAuthorizationStatus?: () => number;
  cancelInputInjectionAuthorization?: () => void;
  setInputInjectionEnabled?: (enabled: boolean) => boolean;
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
  private static runtimeEventLog: string[] = [];
  private static cachedGetMetadataFn: ((sinceFrameId: number) => NativePayload) | null | undefined = undefined;
  private static cachedCopyFrameFn: ((frameId: number, bytes: number) => NativePayload) | null | undefined = undefined;

  static getModule(): NativeBridgeModule | null {
    if (NativeRustDeskBridge.moduleCache) {
      return NativeRustDeskBridge.moduleCache;
    }

    let staticFallbackModule: NativeBridgeModule | null = null;
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
      const directNames = Object.getOwnPropertyNames(staticModule as Object);
      if (directNames.length > 0) {
        staticFallbackModule = staticModule;
        NativeRustDeskBridge.setModuleLoadSummary(
          `static import object has no bridge entry; keys=${NativeRustDeskBridge.joinNames(directNames)}; ${NativeRustDeskBridge.describeModuleShape(staticModule)}`
        );
      }
    } catch (e) {
      console.warn('Static import failed:', e);
      NativeRustDeskBridge.setModuleLoadSummary(`static import failed ${NativeRustDeskBridge.describeError(e)}`);
    }

    // Fallback to requireNapi
    const napiLoader = (globalThis as Object as Record<string, (name: string) => object>).requireNapi;
    if (typeof napiLoader !== 'function') {
      if (!NativeRustDeskBridge.warnedMissingLoader) {
        NativeRustDeskBridge.warnedMissingLoader = true;
        console.warn('NativeRustDeskBridge requireNapi is unavailable on globalThis; will retry later.');
      }
      if (staticFallbackModule) {
        NativeRustDeskBridge.moduleCache = staticFallbackModule;
        NativeRustDeskBridge.setModuleLoadSummary(
          `requireNapi missing; using static fallback without bridge entry; ${NativeRustDeskBridge.describeModuleShape(staticFallbackModule)}`
        );
        return staticFallbackModule;
      }
      NativeRustDeskBridge.setModuleLoadSummary('requireNapi missing on globalThis');
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
      if (staticFallbackModule) {
        NativeRustDeskBridge.moduleCache = staticFallbackModule;
        NativeRustDeskBridge.warnedMissingLoader = false;
        NativeRustDeskBridge.setModuleLoadSummary(
          `requireNapi returned no usable module; using static fallback without bridge entry; ${NativeRustDeskBridge.truncate(attempts.join(' | '), 700)}; ${NativeRustDeskBridge.describeModuleShape(staticFallbackModule)}`
        );
        return staticFallbackModule;
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
    const nativeModule = NativeRustDeskBridge.getModule();
    if (!nativeModule) {
      return false;
    }
    const bridgeEntryFn = NativeRustDeskBridge.resolveFunction<[], Object>(
      nativeModule,
      [
        'initializeRuntime',
        'getCoreSnapshot',
        'connectToPeer',
        'pullSessionEvents',
        'isCoreLoaded',
        'getCoreLoadInfo'
      ]
    );
    if (bridgeEntryFn) {
      return true;
    }
    NativeRustDeskBridge.setDebugSummary(
      `native module object loaded but bridge entry missing; ${NativeRustDeskBridge.describeFunctionResolution(
        nativeModule,
        ['initializeRuntime', 'getCoreSnapshot', 'connectToPeer', 'isCoreLoaded', 'getCoreLoadInfo']
      )}; ${NativeRustDeskBridge.describeModuleShape(nativeModule)}`
    );
    return false;
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

  static getRuntimeLogSummary(): string {
    if (NativeRustDeskBridge.runtimeEventLog.length > 0) {
      return NativeRustDeskBridge.runtimeEventLog.join('\n');
    }
    const bridgeSummary = NativeRustDeskBridge.getCombinedDebugSummary().trim();
    return bridgeSummary.length > 0 ? `[bridge] ${bridgeSummary}` : '[core] no runtime events';
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
      if (!Array.isArray(parsed)) {
        return [];
      }
      parsed.forEach((event: NativeSessionEvent) => {
        NativeRustDeskBridge.appendRuntimeEvent(event);
      });
      return parsed;
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

  static connectToPeer(peerId: string, password: string, server: string, relayServer: string, apiServer: string, key: string = ''): boolean {
    NativeRustDeskBridge.runtimeEventLog = [
      `${new Date().toISOString().substring(11, 23)} connect peer=${peerId} server=${server}`
    ];
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

    let connectFn: ((peerId: string, password: string, server: string, relayServer: string, apiServer: string, key: string) => void) | null = null;

    const resolvedFn = NativeRustDeskBridge.resolveFunction<[string, string, string, string, string, string], void>(
      nativeModule,
      ['connectToPeer', 'connect_to_peer', 'rustdesk_bridge_connect_to_peer', 'sessionStart', 'session_start', 'rustdesk_bridge_session_start']
    );
    if (resolvedFn) {
      connectFn = resolvedFn;
    }

    if (!connectFn) {
      const directAccess = (nativeModule as Record<string, Object | undefined>)['connectToPeer'];
      if (typeof directAccess === 'function') {
        connectFn = directAccess as (peerId: string, password: string, server: string, relayServer: string, apiServer: string, key: string) => void;
        console.info('[NativeBridge] connectToPeer resolved via direct property access');
      }
    }

    if (!connectFn && nativeModule) {
      const defaultRecord = (nativeModule as Record<string, Object | undefined>)['default'];
      if (defaultRecord && typeof defaultRecord === 'object') {
        const defaultFn = (defaultRecord as Record<string, Object | undefined>)['connectToPeer'];
        if (typeof defaultFn === 'function') {
          connectFn = defaultFn as (peerId: string, password: string, server: string, relayServer: string, apiServer: string, key: string) => void;
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
      connectFn(peerId, password, server, relayServer, apiServer, key);
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

      if (sinceFrameId > 0 && frameId <= sinceFrameId) {
        if (frameId < sinceFrameId) {
          console.warn(`[NativeBridge] Frame older than requested: frameId=${frameId}, sinceFrameId=${sinceFrameId}`);
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
        if (retryFrameId > Math.max(actualFrameId, sinceFrameId) && retryWidth > 0 && retryHeight > 0 && retryBytes > 0) {
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

  static setIncomingServiceEnabled(enabled: boolean, server: string, relayServer: string, apiServer: string, key: string = ''): NativeBridgeSnapshot | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const setIncomingServiceEnabledFn = NativeRustDeskBridge.resolveFunction<[boolean, string, string, string, string], NativePayload>(
      nativeModule,
      ['setIncomingServiceEnabled', 'set_incoming_service_enabled', 'rustdesk_bridge_set_incoming_service_enabled', 'mainStartService', 'main_start_service', 'rustdesk_bridge_main_start_service']
    );
    if (!setIncomingServiceEnabledFn) {
      return null;
    }
    try {
      const raw = setIncomingServiceEnabledFn(enabled, server, relayServer, apiServer, key);
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
    const fn = NativeRustDeskBridge.resolveFunction<[number, boolean, number], boolean>(
      nativeModule,
      ['sendKeyboardInput', 'send_keyboard_input', 'rustdesk_bridge_send_keyboard_input']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(keyCode, isPressed, modifiers) === true;
    } catch (error) {
      return false;
    }
  }

  static sendCtrlAltDel(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sendCtrlAltDel', 'send_ctrl_alt_del', 'rustdesk_bridge_send_ctrl_alt_del']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn() === true;
    } catch (error) {
      return false;
    }
  }

  static sendClipboardData(content: string, timestamp: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string, number], boolean>(
      nativeModule,
      ['sendClipboardData', 'send_clipboard_data']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(content, timestamp) === true;
    } catch (_error) {
      return false;
    }
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
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number, number, boolean, number], boolean>(
      nativeModule,
      ['sendVideoFrameMetadata', 'send_video_frame_metadata']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(codec, width, height, timestamp, keyFrame, dataLength) === true;
    } catch (_error) {
      return false;
    }
  }

  static getIncomingScreenFrameMetadata(sinceFrameId: number): string | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number], string | null>(
      nativeModule,
      ['getIncomingScreenFrameMetadata', 'get_incoming_screen_frame_metadata']
    );
    if (!fn) {
      return null;
    }
    try {
      return fn(sinceFrameId);
    } catch (_error) {
      return null;
    }
  }

  static copyIncomingScreenFrame(frameId: number, expectedBytes: number): ArrayBuffer | null {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, number], ArrayBuffer | null>(
      nativeModule,
      ['copyIncomingScreenFrame', 'copy_incoming_screen_frame']
    );
    if (!fn) {
      return null;
    }
    try {
      return fn(frameId, expectedBytes);
    } catch (_error) {
      return null;
    }
  }

  static updateIncomingScreenFrame(
    width: number,
    height: number,
    stride: number,
    timestamp: number,
    format: string,
    data: ArrayBuffer | Uint8Array
  ): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number, number, string, ArrayBuffer | Uint8Array], boolean>(
      nativeModule,
      ['updateIncomingScreenFrame', 'update_incoming_screen_frame']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(width, height, stride, timestamp, format, data) === true;
    } catch (error) {
      hilog.error(0xA03D00, 'NativeBridge', 'updateIncomingScreenFrame failed: ' + NativeRustDeskBridge.describeError(error));
      return false;
    }
  }

  static clearIncomingScreenFrame(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['clearIncomingScreenFrame', 'clear_incoming_screen_frame']
    );
    if (!fn) {
      return;
    }
    try {
      fn();
    } catch (_error) {
    }
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
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number, number, number], boolean>(
      nativeModule,
      ['sendAudioFrameMetadata', 'send_audio_frame_metadata']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(codec, sampleRate, channels, timestamp, dataLength) === true;
    } catch (_error) {
      return false;
    }
  }

  static startNativeScreenCapture(width: number, height: number, frameRate: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number], boolean>(
      nativeModule,
      ['startNativeScreenCapture', 'start_native_screen_capture']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(width, height, frameRate) === true;
    } catch (error) {
      hilog.error(0xA03D00, 'NativeBridge', 'startNativeScreenCapture failed: ' + NativeRustDeskBridge.describeError(error));
      return false;
    }
  }

  static stopNativeScreenCapture(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['stopNativeScreenCapture', 'stop_native_screen_capture']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn() === true;
    } catch (error) {
      hilog.error(0xA03D00, 'NativeBridge', 'stopNativeScreenCapture failed: ' + NativeRustDeskBridge.describeError(error));
      return false;
    }
  }

  static isNativeScreenCaptureActive(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isNativeScreenCaptureActive', 'is_native_screen_capture_active']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn() === true;
    } catch (_error) {
      return false;
    }
  }

  static getNativeScreenCaptureStats(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getNativeScreenCaptureStats', 'get_native_screen_capture_stats']
    );
    if (!fn) {
      return '{}';
    }
    try {
      return fn();
    } catch (error) {
      hilog.error(0xA03D00, 'NativeBridge', 'getNativeScreenCaptureStats failed: ' + NativeRustDeskBridge.describeError(error));
      return '{}';
    }
  }

  static sendChatMessage(peerId: string, messageType: string, content: string, timestamp: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string, string, string, number], boolean>(
      nativeModule,
      ['sendChatMessage', 'send_chat_message']
    );
    if (!fn) {
      hilog.error(0xA03D00, 'NativeBridge', 'sendChatMessage: resolveFunction failed');
      return false;
    }
    try {
      const result = fn(peerId, messageType, content, timestamp) === true;
      hilog.error(0xA03D00, 'NativeBridge', 'sendChatMessage: returned ' + result + ' contentLen=' + content.length);
      return result;
    } catch (error) {
      hilog.error(0xA03D00, 'NativeBridge', 'sendChatMessage: ' + NativeRustDeskBridge.describeError(error));
      return false;
    }
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
    const fn = NativeRustDeskBridge.resolveFunction<[string, string, string, number, string], boolean>(
      nativeModule,
      ['sendFileTransferRequest', 'send_file_transfer_request']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(taskId, peerId, fileName, totalBytes, direction) === true;
    } catch (_error) {
      return false;
    }
  }

  static openTerminal(terminalId: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number], boolean>(
      nativeModule,
      ['openTerminal', 'open_terminal']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(terminalId, rows, cols) === true;
    } catch (_error) {
      return false;
    }
  }

  static sendTerminalInput(terminalId: number, data: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, string], boolean>(
      nativeModule,
      ['sendTerminalInput', 'send_terminal_input']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(terminalId, data) === true;
    } catch (_error) {
      return false;
    }
  }

  static resizeTerminal(terminalId: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number, number, number], boolean>(
      nativeModule,
      ['resizeTerminal', 'resize_terminal']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(terminalId, rows, cols) === true;
    } catch (_error) {
      return false;
    }
  }

  static closeTerminal(terminalId: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[number], boolean>(
      nativeModule,
      ['closeTerminal', 'close_terminal']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(terminalId) === true;
    } catch (_error) {
      return false;
    }
  }

  static readRemoteDirectory(path: string, includeHidden: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string, boolean], boolean>(
      nativeModule,
      ['readRemoteDirectory', 'read_remote_directory']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(path, includeHidden) === true;
    } catch (_error) {
      return false;
    }
  }

  static createRemoteDirectory(path: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string], boolean>(
      nativeModule,
      ['createRemoteDirectory', 'create_remote_directory']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(path) === true;
    } catch (_error) {
      return false;
    }
  }

  static deleteRemotePath(path: string, isDirectory: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string, boolean], boolean>(
      nativeModule,
      ['deleteRemotePath', 'delete_remote_path']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(path, isDirectory) === true;
    } catch (_error) {
      return false;
    }
  }

  static startFileTransfer(path: string, to: string, isRemote: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    NativeRustDeskBridge.ensureRuntimeInitialized(nativeModule);
    const fn = NativeRustDeskBridge.resolveFunction<[string, string, boolean], boolean>(
      nativeModule,
      ['startFileTransfer', 'start_file_transfer']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(path, to, isRemote) === true;
    } catch (_error) {
      return false;
    }
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

  static requestInputInjectionAuthorization(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], number>(
      nativeModule,
      ['requestInputInjectionAuthorization']
    );
    if (!fn) {
      return -1;
    }
    try {
      return fn();
    } catch (_error) {
      return -1;
    }
  }

  static getInputInjectionAuthorizationStatus(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], number>(
      nativeModule,
      ['getInputInjectionAuthorizationStatus']
    );
    if (!fn) {
      return -1;
    }
    try {
      return fn();
    } catch (_error) {
      return -1;
    }
  }

  static cancelInputInjectionAuthorization(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['cancelInputInjectionAuthorization']
    );
    if (!fn) {
      return;
    }
    try {
      fn();
    } catch (_error) {
      // Ignore cancellation failures during shutdown.
    }
  }

  static setInputInjectionEnabled(enabled: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[boolean], boolean>(
      nativeModule,
      ['setInputInjectionEnabled']
    );
    if (!fn) {
      return false;
    }
    try {
      return fn(enabled) === enabled;
    } catch (_error) {
      return false;
    }
  }

  private static appendRuntimeEvent(event: NativeSessionEvent): void {
    const kind = event.kind?.trim() ?? 'unknown';
    if (kind === 'video-frame' ||
      kind === 'video-refresh-requested' ||
      kind === 'quality-status' ||
      kind === 'query-onlines-result' ||
      kind.startsWith('lan-') ||
      kind === 'cursor_position' ||
      kind === 'cursor_data' ||
      kind === 'display' ||
      kind === 'switch-display') {
      return;
    }
    const peerId = event.peerId?.trim() ?? '';
    const detail = NativeRustDeskBridge.truncate(event.detail?.trim() ?? '', 500);
    const timestamp = new Date().toISOString().substring(11, 23);
    const peerText = peerId.length > 0 ? ` peer=${peerId}` : '';
    const detailText = detail.length > 0 ? ` ${detail}` : '';
    const line = `${timestamp} ${kind}${peerText}${detailText}`;
    NativeRustDeskBridge.runtimeEventLog.push(line);
    if (NativeRustDeskBridge.runtimeEventLog.length > 24) {
      NativeRustDeskBridge.runtimeEventLog.shift();
    }
    console.info(`[CORE_EVENT] ${line}`);
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
  // ---- extended session & main functions ----
  static getSessionStage(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getSessionStage', 'get_session_stage', 'rustdesk_bridge_get_session_stage']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getActivePeerId(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getActivePeerId', 'get_active_peer_id', 'rustdesk_bridge_get_active_peer_id']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getConnectStatusSummary(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getConnectStatusSummary', 'get_connect_status_summary', 'rustdesk_bridge_get_connect_status_summary']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getConnectDetailMessage(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getConnectDetailMessage', 'get_connect_detail_message', 'rustdesk_bridge_get_connect_detail_message']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getConnectLastError(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getConnectLastError', 'get_connect_last_error', 'rustdesk_bridge_get_connect_last_error']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static drainConnectEventsJson(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['drainConnectEventsJson', 'drain_connect_events_json', 'rustdesk_bridge_drain_connect_events_json']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getCoreSnapshotJson(server: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[server: string], string>(
      nativeModule,
      ['getCoreSnapshotJson', 'get_core_snapshot_json', 'rustdesk_bridge_get_core_snapshot_json']
    );
    if (!fn) return '';
    try { return fn(server) || ''; } catch { return ''; }
  }

  static pullSessionEventsJson(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['pullSessionEventsJson', 'pull_session_events_json', 'rustdesk_bridge_pull_session_events_json']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static pullAudioFramesJson(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['pullAudioFramesJson', 'pull_audio_frames_json', 'rustdesk_bridge_pull_audio_frames_json']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getLatestVideoFrameMetadataJson(since_frame_id: number): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[since_frame_id: number], string>(
      nativeModule,
      ['getLatestVideoFrameMetadataJson', 'get_latest_video_frame_metadata_json', 'rustdesk_bridge_get_latest_video_frame_metadata_json']
    );
    if (!fn) return '';
    try { return fn(since_frame_id) || ''; } catch { return ''; }
  }

  static getIncomingScreenFrameMetadataJson(since_frame_id: number): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[since_frame_id: number], string>(
      nativeModule,
      ['getIncomingScreenFrameMetadataJson', 'get_incoming_screen_frame_metadata_json', 'rustdesk_bridge_get_incoming_screen_frame_metadata_json']
    );
    if (!fn) return '';
    try { return fn(since_frame_id) || ''; } catch { return ''; }
  }

  static copyLatestVideoFrame(frame_id: number, buffer: any): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[frame_id: number, buffer: any], number>(
      nativeModule,
      ['copyLatestVideoFrame', 'copy_latest_video_frame', 'rustdesk_bridge_copy_latest_video_frame']
    );
    if (!fn) return 0;
    try { return fn(frame_id, buffer) || 0; } catch { return 0; }
  }

  static mainStartService(enabled: boolean, server: string, relay_server: string, api_server: string, key: string = ''): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[enabled: boolean, server: string, relay_server: string, api_server: string, key: string], string>(
      nativeModule,
      ['mainStartService', 'main_start_service', 'rustdesk_bridge_main_start_service']
    );
    if (!fn) return '';
    try { return fn(enabled, server, relay_server, api_server, key) || ''; } catch { return ''; }
  }

  static sessionSendMouse(mask: number, x: number, y: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[mask: number, x: number, y: number], boolean>(
      nativeModule,
      ['sessionSendMouse', 'session_send_mouse', 'rustdesk_bridge_session_send_mouse']
    );
    if (!fn) return false;
    try { return fn(mask, x, y) || false; } catch { return false; }
  }

  static sessionInputKey(key_code: number, is_pressed: boolean, modifiers: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key_code: number, is_pressed: boolean, modifiers: number], boolean>(
      nativeModule,
      ['sessionInputKey', 'session_input_key', 'rustdesk_bridge_session_input_key']
    );
    if (!fn) return false;
    try { return fn(key_code, is_pressed, modifiers) || false; } catch { return false; }
  }

  static sessionCtrlAltDel(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionCtrlAltDel', 'session_ctrl_alt_del', 'rustdesk_bridge_session_ctrl_alt_del']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionSendChat(peerId: string, messageType: string, content: string, timestamp: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[peerId: string, messageType: string, content: string, timestamp: number], boolean>(
      nativeModule,
      ['sessionSendChat', 'session_send_chat', 'rustdesk_bridge_session_send_chat']
    );
    if (!fn) {
      hilog.error(0xA03D00, 'NativeBridge', 'sessionSendChat: resolveFunction returned null, module=' + (nativeModule ? 'exists' : 'null'));
      return false;
    }
    try {
      const result = fn(peerId, messageType, content, timestamp);
      return result || false;
    } catch (e) {
      hilog.error(0xA03D00, 'NativeBridge', 'sessionSendChat: exception ' + JSON.stringify(e));
      return false;
    }
  }

  static sessionStart(peer_id: string, password: string, server: string, relay_server: string, api_server: string, key: string = ''): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[peer_id: string, password: string, server: string, relay_server: string, api_server: string, key: string], void>(
      nativeModule,
      ['sessionStart', 'session_start', 'rustdesk_bridge_session_start']
    );
    if (!fn) return;
    try { fn(peer_id, password, server, relay_server, api_server, key); } catch { /* ignore */ }
  }

  static mainAccountAuth(op: string, remember_me: boolean, server: string, relay_server: string, api_server: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[op: string, remember_me: boolean, server: string, relay_server: string, api_server: string], void>(
      nativeModule,
      ['mainAccountAuth', 'main_account_auth', 'rustdesk_bridge_main_account_auth']
    );
    if (!fn) return;
    try { fn(op, remember_me, server, relay_server, api_server); } catch { /* ignore */ }
  }

  static mainAccountAuthCancel(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainAccountAuthCancel', 'main_account_auth_cancel', 'rustdesk_bridge_main_account_auth_cancel']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainAccountAuthResult(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainAccountAuthResult', 'main_account_auth_result', 'rustdesk_bridge_main_account_auth_result']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetLocalOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetLocalOption', 'main_get_local_option', 'rustdesk_bridge_main_get_local_option']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainGetPeerOption(peer_id: string, key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[peer_id: string, key: string], string>(
      nativeModule,
      ['mainGetPeerOption', 'main_get_peer_option', 'rustdesk_bridge_main_get_peer_option']
    );
    if (!fn) return '';
    try { return fn(peer_id, key) || ''; } catch { return ''; }
  }

  static sessionGetToggleOption(key: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], boolean>(
      nativeModule,
      ['sessionGetToggleOption', 'session_get_toggle_option', 'rustdesk_bridge_session_get_toggle_option']
    );
    if (!fn) return false;
    try { return fn(key) || false; } catch { return false; }
  }

  static mainSetLocalOption(key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string, value: string], void>(
      nativeModule,
      ['mainSetLocalOption', 'main_set_local_option', 'rustdesk_bridge_main_set_local_option']
    );
    if (!fn) return;
    try { fn(key, value); } catch { /* ignore */ }
  }

  static markSessionConnected(peer_id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[peer_id: string], void>(
      nativeModule,
      ['markSessionConnected', 'mark_session_connected', 'rustdesk_bridge_mark_session_connected']
    );
    if (!fn) return;
    try { fn(peer_id); } catch { /* ignore */ }
  }

  static sessionReconnect(force_relay: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[force_relay: boolean], boolean>(
      nativeModule,
      ['sessionReconnect', 'session_reconnect', 'rustdesk_bridge_session_reconnect']
    );
    if (!fn) return false;
    try { return fn(force_relay) || false; } catch { return false; }
  }

  static markSessionError(message: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[message: string], void>(
      nativeModule,
      ['markSessionError', 'mark_session_error', 'rustdesk_bridge_mark_session_error']
    );
    if (!fn) return;
    try { fn(message); } catch { /* ignore */ }
  }

  static sessionClose(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionClose', 'session_close', 'rustdesk_bridge_session_close']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionLogin(password: string, remember: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[password: string, remember: boolean], boolean>(
      nativeModule,
      ['sessionLogin', 'session_login', 'rustdesk_bridge_session_login']
    );
    if (!fn) return false;
    try { return fn(password, remember) || false; } catch { return false; }
  }

  static sessionRestartRemoteDevice(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionRestartRemoteDevice', 'session_restart_remote_device', 'rustdesk_bridge_session_restart_remote_device']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionLockScreen(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionLockScreen', 'session_lock_screen', 'rustdesk_bridge_session_lock_screen']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionOpenTerminal(terminal_id: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[terminal_id: number, rows: number, cols: number], boolean>(
      nativeModule,
      ['sessionOpenTerminal', 'session_open_terminal', 'rustdesk_bridge_session_open_terminal']
    );
    if (!fn) return false;
    try { return fn(terminal_id, rows, cols) || false; } catch { return false; }
  }

  static sessionSendTerminalInput(terminal_id: number, data: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[terminal_id: number, data: string], boolean>(
      nativeModule,
      ['sessionSendTerminalInput', 'session_send_terminal_input', 'rustdesk_bridge_session_send_terminal_input']
    );
    if (!fn) return false;
    try { return fn(terminal_id, data) || false; } catch { return false; }
  }

  static sessionResizeTerminal(terminal_id: number, rows: number, cols: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[terminal_id: number, rows: number, cols: number], boolean>(
      nativeModule,
      ['sessionResizeTerminal', 'session_resize_terminal', 'rustdesk_bridge_session_resize_terminal']
    );
    if (!fn) return false;
    try { return fn(terminal_id, rows, cols) || false; } catch { return false; }
  }

  static sessionCloseTerminal(terminal_id: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[terminal_id: number], boolean>(
      nativeModule,
      ['sessionCloseTerminal', 'session_close_terminal', 'rustdesk_bridge_session_close_terminal']
    );
    if (!fn) return false;
    try { return fn(terminal_id) || false; } catch { return false; }
  }

  static sessionReadRemoteDir(path: string, include_hidden: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: string, include_hidden: boolean], boolean>(
      nativeModule,
      ['sessionReadRemoteDir', 'session_read_remote_dir', 'rustdesk_bridge_session_read_remote_dir']
    );
    if (!fn) return false;
    try { return fn(path, include_hidden) || false; } catch { return false; }
  }

  static sessionCreateDir(path: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: string], boolean>(
      nativeModule,
      ['sessionCreateDir', 'session_create_dir', 'rustdesk_bridge_session_create_dir']
    );
    if (!fn) return false;
    try { return fn(path) || false; } catch { return false; }
  }

  static sessionSendFiles(path: string, to: string, is_remote: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: string, to: string, is_remote: boolean], boolean>(
      nativeModule,
      ['sessionSendFiles', 'session_send_files', 'rustdesk_bridge_session_send_files']
    );
    if (!fn) return false;
    try { return fn(path, to, is_remote) || false; } catch { return false; }
  }

  static mainDiscover(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainDiscover', 'main_discover', 'rustdesk_bridge_main_discover']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainLoadLanPeers(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainLoadLanPeers', 'main_load_lan_peers', 'rustdesk_bridge_main_load_lan_peers']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainRemoveDiscovered(peer_id: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[peer_id: string], boolean>(
      nativeModule,
      ['mainRemoveDiscovered', 'main_remove_discovered', 'rustdesk_bridge_main_remove_discovered']
    );
    if (!fn) return false;
    try { return fn(peer_id) || false; } catch { return false; }
  }

  static sessionSend2fa(code: string, trust_this_device: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[code: string, trust_this_device: boolean], boolean>(
      nativeModule,
      ['sessionSend2fa', 'session_send2fa', 'rustdesk_bridge_session_send2fa']
    );
    if (!fn) return false;
    try { return fn(code, trust_this_device) || false; } catch { return false; }
  }

  static sessionToggleOption(name: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[name: string], void>(
      nativeModule,
      ['sessionToggleOption', 'session_toggle_option', 'rustdesk_bridge_session_toggle_option']
    );
    if (!fn) return;
    try { fn(name); } catch { /* ignore */ }
  }

  static sessionTogglePrivacyMode(impl_key: string, on: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[impl_key: string, on: boolean], boolean>(
      nativeModule,
      ['sessionTogglePrivacyMode', 'session_toggle_privacy_mode', 'rustdesk_bridge_session_toggle_privacy_mode']
    );
    if (!fn) return false;
    try { return fn(impl_key, on) || false; } catch { return false; }
  }

  static sessionSwitchDisplay(display: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], boolean>(
      nativeModule,
      ['sessionSwitchDisplay', 'session_switch_display', 'rustdesk_bridge_session_switch_display']
    );
    if (!fn) return false;
    try { return fn(display) || false; } catch { return false; }
  }

  static sessionEnterOrLeave(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionEnterOrLeave', 'session_enter_or_leave', 'rustdesk_bridge_session_enter_or_leave']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionLeave(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionLeave', 'session_leave', 'rustdesk_bridge_session_leave']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionSetSize(display: number, width: number, height: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number, width: number, height: number], void>(
      nativeModule,
      ['sessionSetSize', 'session_set_size', 'rustdesk_bridge_session_set_size']
    );
    if (!fn) return;
    try { fn(display, width, height); } catch { /* ignore */ }
  }

  static sessionChangeResolution(display: number, width: number, height: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number, width: number, height: number], void>(
      nativeModule,
      ['sessionChangeResolution', 'session_change_resolution', 'rustdesk_bridge_session_change_resolution']
    );
    if (!fn) return;
    try { fn(display, width, height); } catch { /* ignore */ }
  }

  static sessionElevateDirect(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionElevateDirect', 'session_elevate_direct', 'rustdesk_bridge_session_elevate_direct']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionElevateWithLogon(username: string, password: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[username: string, password: string], void>(
      nativeModule,
      ['sessionElevateWithLogon', 'session_elevate_with_logon', 'rustdesk_bridge_session_elevate_with_logon']
    );
    if (!fn) return;
    try { fn(username, password); } catch { /* ignore */ }
  }

  static sessionSwitchSides(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionSwitchSides', 'session_switch_sides', 'rustdesk_bridge_session_switch_sides']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionTakeScreenshot(display: number): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], boolean>(
      nativeModule,
      ['sessionTakeScreenshot', 'session_take_screenshot', 'rustdesk_bridge_session_take_screenshot']
    );
    if (!fn) return false;
    try { return fn(display) || false; } catch { return false; }
  }

  static sessionRecordScreen(start: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[start: boolean], boolean>(
      nativeModule,
      ['sessionRecordScreen', 'session_record_screen', 'rustdesk_bridge_session_record_screen']
    );
    if (!fn) return false;
    try { return fn(start) || false; } catch { return false; }
  }

  static sessionGetIsRecording(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionGetIsRecording', 'session_get_is_recording', 'rustdesk_bridge_session_get_is_recording']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionRequestVoiceCall(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionRequestVoiceCall', 'session_request_voice_call', 'rustdesk_bridge_session_request_voice_call']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionCloseVoiceCall(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionCloseVoiceCall', 'session_close_voice_call', 'rustdesk_bridge_session_close_voice_call']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionAddPortForward(local_port: number, remote_host: string, remote_port: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[local_port: number, remote_host: string, remote_port: number], void>(
      nativeModule,
      ['sessionAddPortForward', 'session_add_port_forward', 'rustdesk_bridge_session_add_port_forward']
    );
    if (!fn) return;
    try { fn(local_port, remote_host, remote_port); } catch { /* ignore */ }
  }

  static sessionRemovePortForward(local_port: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[local_port: number], void>(
      nativeModule,
      ['sessionRemovePortForward', 'session_remove_port_forward', 'rustdesk_bridge_session_remove_port_forward']
    );
    if (!fn) return;
    try { fn(local_port); } catch { /* ignore */ }
  }

  static sessionNewRdp(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionNewRdp', 'session_new_rdp', 'rustdesk_bridge_session_new_rdp']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionRemoveFile(act_id: number, path: string, file_num: number, is_remote: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[act_id: number, path: string, file_num: number, is_remote: boolean], void>(
      nativeModule,
      ['sessionRemoveFile', 'session_remove_file', 'rustdesk_bridge_session_remove_file']
    );
    if (!fn) return;
    try { fn(act_id, path, file_num, is_remote); } catch { /* ignore */ }
  }

  static sessionRenameFile(act_id: number, path: string, new_name: string, is_remote: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[act_id: number, path: string, new_name: string, is_remote: boolean], void>(
      nativeModule,
      ['sessionRenameFile', 'session_rename_file', 'rustdesk_bridge_session_rename_file']
    );
    if (!fn) return;
    try { fn(act_id, path, new_name, is_remote); } catch { /* ignore */ }
  }

  static sessionCancelJob(act_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[act_id: number], void>(
      nativeModule,
      ['sessionCancelJob', 'session_cancel_job', 'rustdesk_bridge_session_cancel_job']
    );
    if (!fn) return;
    try { fn(act_id); } catch { /* ignore */ }
  }

  static sessionResumeJob(act_id: number, is_remote: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[act_id: number, is_remote: boolean], void>(
      nativeModule,
      ['sessionResumeJob', 'session_resume_job', 'rustdesk_bridge_session_resume_job']
    );
    if (!fn) return;
    try { fn(act_id, is_remote); } catch { /* ignore */ }
  }

  static sessionSetConfirmOverrideFile(act_id: number, file_num: number, need_override: boolean, remember: boolean, is_upload: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[act_id: number, file_num: number, need_override: boolean, remember: boolean, is_upload: boolean], void>(
      nativeModule,
      ['sessionSetConfirmOverrideFile', 'session_set_confirm_override_file', 'rustdesk_bridge_session_set_confirm_override_file']
    );
    if (!fn) return;
    try { fn(act_id, file_num, need_override, remember, is_upload); } catch { /* ignore */ }
  }

  static sessionSendNote(note: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[note: string], void>(
      nativeModule,
      ['sessionSendNote', 'session_send_note', 'rustdesk_bridge_session_send_note']
    );
    if (!fn) return;
    try { fn(note); } catch { /* ignore */ }
  }

  static sessionInputString(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionInputString', 'session_input_string', 'rustdesk_bridge_session_input_string']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionInputOsPassword(pass: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[pass: string], void>(
      nativeModule,
      ['sessionInputOsPassword', 'session_input_os_password', 'rustdesk_bridge_session_input_os_password']
    );
    if (!fn) return;
    try { fn(pass); } catch { /* ignore */ }
  }

  static sessionLoadLastTransferJobs(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionLoadLastTransferJobs', 'session_load_last_transfer_jobs', 'rustdesk_bridge_session_load_last_transfer_jobs']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionGetViewStyle(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetViewStyle', 'session_get_view_style', 'rustdesk_bridge_session_get_view_style']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetViewStyle(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionSetViewStyle', 'session_set_view_style', 'rustdesk_bridge_session_set_view_style']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetScrollStyle(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetScrollStyle', 'session_get_scroll_style', 'rustdesk_bridge_session_get_scroll_style']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetScrollStyle(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionSetScrollStyle', 'session_set_scroll_style', 'rustdesk_bridge_session_set_scroll_style']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetImageQuality(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetImageQuality', 'session_get_image_quality', 'rustdesk_bridge_session_get_image_quality']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetImageQuality(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionSetImageQuality', 'session_set_image_quality', 'rustdesk_bridge_session_set_image_quality']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetKeyboardMode(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetKeyboardMode', 'session_get_keyboard_mode', 'rustdesk_bridge_session_get_keyboard_mode']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetKeyboardMode(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionSetKeyboardMode', 'session_set_keyboard_mode', 'rustdesk_bridge_session_set_keyboard_mode']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetCustomImageQuality(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetCustomImageQuality', 'session_get_custom_image_quality', 'rustdesk_bridge_session_get_custom_image_quality']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetCustomImageQuality(value: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: number], void>(
      nativeModule,
      ['sessionSetCustomImageQuality', 'session_set_custom_image_quality', 'rustdesk_bridge_session_set_custom_image_quality']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionSetCustomFps(fps: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[fps: number], void>(
      nativeModule,
      ['sessionSetCustomFps', 'session_set_custom_fps', 'rustdesk_bridge_session_set_custom_fps']
    );
    if (!fn) return;
    try { fn(fps); } catch { /* ignore */ }
  }

  static sessionGetTrackpadSpeed(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], number>(
      nativeModule,
      ['sessionGetTrackpadSpeed', 'session_get_trackpad_speed', 'rustdesk_bridge_session_get_trackpad_speed']
    );
    if (!fn) return 0;
    try { return fn() || 0; } catch { return 0; }
  }

  static sessionSetTrackpadSpeed(value: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: number], void>(
      nativeModule,
      ['sessionSetTrackpadSpeed', 'session_set_trackpad_speed', 'rustdesk_bridge_session_set_trackpad_speed']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetFlutterOption(k: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string], string>(
      nativeModule,
      ['sessionGetFlutterOption', 'session_get_flutter_option', 'rustdesk_bridge_session_get_flutter_option']
    );
    if (!fn) return '';
    try { return fn(k) || ''; } catch { return ''; }
  }

  static sessionSetFlutterOption(k: string, v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string, v: string], void>(
      nativeModule,
      ['sessionSetFlutterOption', 'session_set_flutter_option', 'rustdesk_bridge_session_set_flutter_option']
    );
    if (!fn) return;
    try { fn(k, v); } catch { /* ignore */ }
  }

  static sessionGetReverseMouseWheelSync(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetReverseMouseWheelSync', 'session_get_reverse_mouse_wheel_sync', 'rustdesk_bridge_session_get_reverse_mouse_wheel_sync']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionSetReverseMouseWheel(value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: string], void>(
      nativeModule,
      ['sessionSetReverseMouseWheel', 'session_set_reverse_mouse_wheel', 'rustdesk_bridge_session_set_reverse_mouse_wheel']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionGetOption(k: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string], string>(
      nativeModule,
      ['sessionGetOption', 'session_get_option', 'rustdesk_bridge_session_get_option']
    );
    if (!fn) return '';
    try { return fn(k) || ''; } catch { return ''; }
  }

  static sessionSetOption(k: string, v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string, v: string], void>(
      nativeModule,
      ['sessionSetOption', 'session_set_option', 'rustdesk_bridge_session_set_option']
    );
    if (!fn) return;
    try { fn(k, v); } catch { /* ignore */ }
  }

  static sessionGetPeerOption(name: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[name: string], string>(
      nativeModule,
      ['sessionGetPeerOption', 'session_get_peer_option', 'rustdesk_bridge_session_get_peer_option']
    );
    if (!fn) return '';
    try { return fn(name) || ''; } catch { return ''; }
  }

  static sessionPeerOption(name: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[name: string, value: string], void>(
      nativeModule,
      ['sessionPeerOption', 'session_peer_option', 'rustdesk_bridge_session_peer_option']
    );
    if (!fn) return;
    try { fn(name, value); } catch { /* ignore */ }
  }

  static sessionIsKeyboardModeSupported(mode: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[mode: string], boolean>(
      nativeModule,
      ['sessionIsKeyboardModeSupported', 'session_is_keyboard_mode_supported', 'rustdesk_bridge_session_is_keyboard_mode_supported']
    );
    if (!fn) return false;
    try { return fn(mode) || false; } catch { return false; }
  }

  static sessionGetPlatform(is_remote: boolean): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[is_remote: boolean], string>(
      nativeModule,
      ['sessionGetPlatform', 'session_get_platform', 'rustdesk_bridge_session_get_platform']
    );
    if (!fn) return '';
    try { return fn(is_remote) || ''; } catch { return ''; }
  }

  static sessionGetRemember(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionGetRemember', 'session_get_remember', 'rustdesk_bridge_session_get_remember']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionGetEnableTrustedDevices(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionGetEnableTrustedDevices', 'session_get_enable_trusted_devices', 'rustdesk_bridge_session_get_enable_trusted_devices']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionGetAlternativeCodecs(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetAlternativeCodecs', 'session_get_alternative_codecs', 'rustdesk_bridge_session_get_alternative_codecs']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionChangePreferCodec(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionChangePreferCodec', 'session_change_prefer_codec', 'rustdesk_bridge_session_change_prefer_codec']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainGetOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetOption', 'main_get_option', 'rustdesk_bridge_main_get_option']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainSetOption(key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string, value: string], void>(
      nativeModule,
      ['mainSetOption', 'main_set_option', 'rustdesk_bridge_main_set_option']
    );
    if (!fn) return;
    try { fn(key, value); } catch { /* ignore */ }
  }

  static mainGetOptions(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetOptions', 'main_get_options', 'rustdesk_bridge_main_get_options']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetMyId(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetMyId', 'main_get_my_id', 'rustdesk_bridge_main_get_my_id']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetUuid(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetUuid', 'main_get_uuid', 'rustdesk_bridge_main_get_uuid']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetVersion(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetVersion', 'main_get_version', 'rustdesk_bridge_main_get_version']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetFingerprint(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetFingerprint', 'main_get_fingerprint', 'rustdesk_bridge_main_get_fingerprint']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetApiServer(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetApiServer', 'main_get_api_server', 'rustdesk_bridge_main_get_api_server']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getVersion(): string {
    return NativeRustDeskBridge.mainGetVersion();
  }

  static getMyId(): string {
    return NativeRustDeskBridge.mainGetMyId();
  }

  static getFingerprint(): string {
    return NativeRustDeskBridge.mainGetFingerprint();
  }

  static getRegisteredFunctionCount(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    if (!nativeModule) return 0;
    const keys = Object.keys(nativeModule as Record<string, Object>);
    return keys.filter(k => typeof (nativeModule as Record<string, Object>)[k] === 'function').length;
  }

  static mainGetTemporaryPassword(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetTemporaryPassword', 'main_get_temporary_password', 'rustdesk_bridge_main_get_temporary_password']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static getTemporaryPassword(): string {
    return NativeRustDeskBridge.mainGetTemporaryPassword();
  }

  static mainSetPermanentPasswordWithResult(password: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[password: string], boolean>(
      nativeModule,
      ['mainSetPermanentPasswordWithResult', 'main_set_permanent_password_with_result', 'rustdesk_bridge_main_set_permanent_password_with_result']
    );
    if (!fn) return false;
    try { return fn(password) || false; } catch { return false; }
  }

  static mainUpdateTemporaryPassword(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainUpdateTemporaryPassword', 'main_update_temporary_password', 'rustdesk_bridge_main_update_temporary_password']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainTestIfValidServer(server: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[server: string], string>(
      nativeModule,
      ['mainTestIfValidServer', 'main_test_if_valid_server', 'rustdesk_bridge_main_test_if_valid_server']
    );
    if (!fn) return '';
    try { return fn(server) || ''; } catch { return ''; }
  }

  static mainGetConnectStatus(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetConnectStatus', 'main_get_connect_status', 'rustdesk_bridge_main_get_connect_status']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainIsUsingPublicServer(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsUsingPublicServer', 'main_is_using_public_server', 'rustdesk_bridge_main_is_using_public_server']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainForgetPassword(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['mainForgetPassword', 'main_forget_password', 'rustdesk_bridge_main_forget_password']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static mainPeerHasPassword(id: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], boolean>(
      nativeModule,
      ['mainPeerHasPassword', 'main_peer_has_password', 'rustdesk_bridge_main_peer_has_password']
    );
    if (!fn) return false;
    try { return fn(id) || false; } catch { return false; }
  }

  static mainPeerExists(id: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], boolean>(
      nativeModule,
      ['mainPeerExists', 'main_peer_exists', 'rustdesk_bridge_main_peer_exists']
    );
    if (!fn) return false;
    try { return fn(id) || false; } catch { return false; }
  }

  static mainSetPeerAlias(id: string, alias: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, alias: string], void>(
      nativeModule,
      ['mainSetPeerAlias', 'main_set_peer_alias', 'rustdesk_bridge_main_set_peer_alias']
    );
    if (!fn) return;
    try { fn(id, alias); } catch { /* ignore */ }
  }

  static mainSetPeerOption(id: string, key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, key: string, value: string], void>(
      nativeModule,
      ['mainSetPeerOption', 'main_set_peer_option', 'rustdesk_bridge_main_set_peer_option']
    );
    if (!fn) return;
    try { fn(id, key, value); } catch { /* ignore */ }
  }

  static mainRemovePeer(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['mainRemovePeer', 'main_remove_peer', 'rustdesk_bridge_main_remove_peer']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static mainGetNewStoredPeers(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetNewStoredPeers', 'main_get_new_stored_peers', 'rustdesk_bridge_main_get_new_stored_peers']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainLoadRecentPeers(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainLoadRecentPeers', 'main_load_recent_peers', 'rustdesk_bridge_main_load_recent_peers']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainGetLangs(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetLangs', 'main_get_langs', 'rustdesk_bridge_main_get_langs']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetError(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetError', 'main_get_error', 'rustdesk_bridge_main_get_error']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetBuildDate(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetBuildDate', 'main_get_build_date', 'rustdesk_bridge_main_get_build_date']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetLicense(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetLicense', 'main_get_license', 'rustdesk_bridge_main_get_license']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetAppName(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetAppName', 'main_get_app_name', 'rustdesk_bridge_main_get_app_name']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainHasHwcodec(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasHwcodec', 'main_has_hwcodec', 'rustdesk_bridge_main_has_hwcodec']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGenerate2fa(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGenerate2fa', 'main_generate2fa', 'rustdesk_bridge_main_generate2fa']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainVerify2fa(code: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[code: string], boolean>(
      nativeModule,
      ['mainVerify2fa', 'main_verify2fa', 'rustdesk_bridge_main_verify2fa']
    );
    if (!fn) return false;
    try { return fn(code) || false; } catch { return false; }
  }

  static mainGetTrustedDevices(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetTrustedDevices', 'main_get_trusted_devices', 'rustdesk_bridge_main_get_trusted_devices']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainClearTrustedDevices(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainClearTrustedDevices', 'main_clear_trusted_devices', 'rustdesk_bridge_main_clear_trusted_devices']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainSetUserDefaultOption(key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string, value: string], void>(
      nativeModule,
      ['mainSetUserDefaultOption', 'main_set_user_default_option', 'rustdesk_bridge_main_set_user_default_option']
    );
    if (!fn) return;
    try { fn(key, value); } catch { /* ignore */ }
  }

  static mainGetUserDefaultOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetUserDefaultOption', 'main_get_user_default_option', 'rustdesk_bridge_main_get_user_default_option']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainResolveAvatarUrl(avatar: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[avatar: string], string>(
      nativeModule,
      ['mainResolveAvatarUrl', 'main_resolve_avatar_url', 'rustdesk_bridge_main_resolve_avatar_url']
    );
    if (!fn) return '';
    try { return fn(avatar) || ''; } catch { return ''; }
  }

  static mainGetLoginDeviceInfo(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetLoginDeviceInfo', 'main_get_login_device_info', 'rustdesk_bridge_main_get_login_device_info']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetHardOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetHardOption', 'main_get_hard_option', 'rustdesk_bridge_main_get_hard_option']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainGetBuildinOption(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetBuildinOption', 'main_get_buildin_option', 'rustdesk_bridge_main_get_buildin_option']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainGetCommon(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetCommon', 'main_get_common', 'rustdesk_bridge_main_get_common']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainSetCommon(key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string, value: string], void>(
      nativeModule,
      ['mainSetCommon', 'main_set_common', 'rustdesk_bridge_main_set_common']
    );
    if (!fn) return;
    try { fn(key, value); } catch { /* ignore */ }
  }

  static mainCheckConnectStatus(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainCheckConnectStatus', 'main_check_connect_status', 'rustdesk_bridge_main_check_connect_status']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainStopService(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainStopService', 'main_stop_service', 'rustdesk_bridge_main_stop_service']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainOnMainWindowClose(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainOnMainWindowClose', 'main_on_main_window_close', 'rustdesk_bridge_main_on_main_window_close']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainWol(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['mainWol', 'main_wol', 'rustdesk_bridge_main_wol']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static mainHttpRequest(url: string, method: string, body: string, header: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[url: string, method: string, body: string, header: string], void>(
      nativeModule,
      ['mainHttpRequest', 'main_http_request', 'rustdesk_bridge_main_http_request']
    );
    if (!fn) return;
    try { fn(url, method, body, header); } catch { /* ignore */ }
  }

  static sessionIsFileTransfer(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsFileTransfer', 'session_is_file_transfer', 'rustdesk_bridge_session_is_file_transfer']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionIsTerminal(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsTerminal', 'session_is_terminal', 'rustdesk_bridge_session_is_terminal']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionIsPortForward(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsPortForward', 'session_is_port_forward', 'rustdesk_bridge_session_is_port_forward']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionIsRdp(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsRdp', 'session_is_rdp', 'rustdesk_bridge_session_is_rdp']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionIsViewCamera(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsViewCamera', 'session_is_view_camera', 'rustdesk_bridge_session_is_view_camera']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionToggleVirtualDisplay(index: number, on: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[index: number, on: boolean], void>(
      nativeModule,
      ['sessionToggleVirtualDisplay', 'session_toggle_virtual_display', 'rustdesk_bridge_session_toggle_virtual_display']
    );
    if (!fn) return;
    try { fn(index, on); } catch { /* ignore */ }
  }

  static sessionGetAuditServer(typ: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[typ: string], string>(
      nativeModule,
      ['sessionGetAuditServer', 'session_get_audit_server', 'rustdesk_bridge_session_get_audit_server']
    );
    if (!fn) return '';
    try { return fn(typ) || ''; } catch { return ''; }
  }

  static sessionSendSelectedSessionId(sid: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[sid: string], void>(
      nativeModule,
      ['sessionSendSelectedSessionId', 'session_send_selected_session_id', 'rustdesk_bridge_session_send_selected_session_id']
    );
    if (!fn) return;
    try { fn(sid); } catch { /* ignore */ }
  }

  static sessionGetConnToken(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetConnToken', 'session_get_conn_token', 'rustdesk_bridge_session_get_conn_token']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionHandleFlutterKeyEvent(keyboard_mode: string, character: string, usb_hid: number, lock_modes: number, down_or_up: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[keyboard_mode: string, character: string, usb_hid: number, lock_modes: number, down_or_up: boolean], void>(
      nativeModule,
      ['sessionHandleFlutterKeyEvent', 'session_handle_flutter_key_event', 'rustdesk_bridge_session_handle_flutter_key_event']
    );
    if (!fn) return;
    try { fn(keyboard_mode, character, usb_hid, lock_modes, down_or_up); } catch { /* ignore */ }
  }

  static sessionHandleFlutterRawKeyEvent(keyboard_mode: string, name: string, platform_code: number, position_code: number, lock_modes: number, down_or_up: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[keyboard_mode: string, name: string, platform_code: number, position_code: number, lock_modes: number, down_or_up: boolean], void>(
      nativeModule,
      ['sessionHandleFlutterRawKeyEvent', 'session_handle_flutter_raw_key_event', 'rustdesk_bridge_session_handle_flutter_raw_key_event']
    );
    if (!fn) return;
    try { fn(keyboard_mode, name, platform_code, position_code, lock_modes, down_or_up); } catch { /* ignore */ }
  }

  static sessionSendTouchScale(scale: number, alt: boolean, ctrl: boolean, shift: boolean, command: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[scale: number, alt: boolean, ctrl: boolean, shift: boolean, command: boolean], void>(
      nativeModule,
      ['sessionSendTouchScale', 'session_send_touch_scale', 'rustdesk_bridge_session_send_touch_scale']
    );
    if (!fn) return;
    try { fn(scale, alt, ctrl, shift, command); } catch { /* ignore */ }
  }

  static sessionSendTouchPanEvent(event: string, x: number, y: number, alt: boolean, ctrl: boolean, shift: boolean, command: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[event: string, x: number, y: number, alt: boolean, ctrl: boolean, shift: boolean, command: boolean], void>(
      nativeModule,
      ['sessionSendTouchPanEvent', 'session_send_touch_pan_event', 'rustdesk_bridge_session_send_touch_pan_event']
    );
    if (!fn) return;
    try { fn(event, x, y, alt, ctrl, shift, command); } catch { /* ignore */ }
  }

  static sessionRefresh(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionRefresh', 'session_refresh', 'rustdesk_bridge_session_refresh']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionGetPeerVersion(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetPeerVersion', 'session_get_peer_version', 'rustdesk_bridge_session_get_peer_version']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionGetPathSep(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetPathSep', 'session_get_path_sep', 'rustdesk_bridge_session_get_path_sep']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionIsRestartingRemoteDevice(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsRestartingRemoteDevice', 'session_is_restarting_remote_device', 'rustdesk_bridge_session_is_restarting_remote_device']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static cmInit(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['cmInit', 'cm_init', 'rustdesk_bridge_cm_init']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static cmGetClientsState(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['cmGetClientsState', 'cm_get_clients_state', 'rustdesk_bridge_cm_get_clients_state']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static cmCheckClientsLength(length: number): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[length: number], string>(
      nativeModule,
      ['cmCheckClientsLength', 'cm_check_clients_length', 'rustdesk_bridge_cm_check_clients_length']
    );
    if (!fn) return '';
    try { return fn(length) || ''; } catch { return ''; }
  }

  static cmGetClientsLength(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['cmGetClientsLength', 'cm_get_clients_length', 'rustdesk_bridge_cm_get_clients_length']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static cmSendChat(conn_id: number, msg: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number, msg: string], void>(
      nativeModule,
      ['cmSendChat', 'cm_send_chat', 'rustdesk_bridge_cm_send_chat']
    );
    if (!fn) return;
    try { fn(conn_id, msg); } catch { /* ignore */ }
  }

  static cmLoginRes(conn_id: number, res: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number, res: boolean], void>(
      nativeModule,
      ['cmLoginRes', 'cm_login_res', 'rustdesk_bridge_cm_login_res']
    );
    if (!fn) return;
    try { fn(conn_id, res); } catch { /* ignore */ }
  }

  static cmCloseConnection(conn_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number], void>(
      nativeModule,
      ['cmCloseConnection', 'cm_close_connection', 'rustdesk_bridge_cm_close_connection']
    );
    if (!fn) return;
    try { fn(conn_id); } catch { /* ignore */ }
  }

  static cmRemoveDisconnectedConnection(conn_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number], void>(
      nativeModule,
      ['cmRemoveDisconnectedConnection', 'cm_remove_disconnected_connection', 'rustdesk_bridge_cm_remove_disconnected_connection']
    );
    if (!fn) return;
    try { fn(conn_id); } catch { /* ignore */ }
  }

  static cmCheckClickTime(conn_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number], void>(
      nativeModule,
      ['cmCheckClickTime', 'cm_check_click_time', 'rustdesk_bridge_cm_check_click_time']
    );
    if (!fn) return;
    try { fn(conn_id); } catch { /* ignore */ }
  }

  static cmGetClickTime(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['cmGetClickTime', 'cm_get_click_time', 'rustdesk_bridge_cm_get_click_time']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static cmSwitchPermission(conn_id: number, name: string, enabled: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number, name: string, enabled: boolean], void>(
      nativeModule,
      ['cmSwitchPermission', 'cm_switch_permission', 'rustdesk_bridge_cm_switch_permission']
    );
    if (!fn) return;
    try { fn(conn_id, name, enabled); } catch { /* ignore */ }
  }

  static cmCanElevate(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['cmCanElevate', 'cm_can_elevate', 'rustdesk_bridge_cm_can_elevate']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static cmElevatePortable(conn_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number], void>(
      nativeModule,
      ['cmElevatePortable', 'cm_elevate_portable', 'rustdesk_bridge_cm_elevate_portable']
    );
    if (!fn) return;
    try { fn(conn_id); } catch { /* ignore */ }
  }

  static cmSwitchBack(conn_id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[conn_id: number], void>(
      nativeModule,
      ['cmSwitchBack', 'cm_switch_back', 'rustdesk_bridge_cm_switch_back']
    );
    if (!fn) return;
    try { fn(conn_id); } catch { /* ignore */ }
  }

  static cmGetConfig(name: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[name: string], string>(
      nativeModule,
      ['cmGetConfig', 'cm_get_config', 'rustdesk_bridge_cm_get_config']
    );
    if (!fn) return '';
    try { return fn(name) || ''; } catch { return ''; }
  }

  static cmHandleIncomingVoiceCall(id: number, accept: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, accept: boolean], void>(
      nativeModule,
      ['cmHandleIncomingVoiceCall', 'cm_handle_incoming_voice_call', 'rustdesk_bridge_cm_handle_incoming_voice_call']
    );
    if (!fn) return;
    try { fn(id, accept); } catch { /* ignore */ }
  }

  static cmCloseVoiceCall(id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number], void>(
      nativeModule,
      ['cmCloseVoiceCall', 'cm_close_voice_call', 'rustdesk_bridge_cm_close_voice_call']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static pluginEvent(id: string, peer: string, msg: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, peer: string, msg: string], void>(
      nativeModule,
      ['pluginEvent', 'plugin_event', 'rustdesk_bridge_plugin_event']
    );
    if (!fn) return;
    try { fn(id, peer, msg); } catch { /* ignore */ }
  }

  static pluginRegisterEventStream(id: string, peer: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, peer: string], void>(
      nativeModule,
      ['pluginRegisterEventStream', 'plugin_register_event_stream', 'rustdesk_bridge_plugin_register_event_stream']
    );
    if (!fn) return;
    try { fn(id, peer); } catch { /* ignore */ }
  }

  static pluginGetSessionOption(id: string, key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, key: string], string>(
      nativeModule,
      ['pluginGetSessionOption', 'plugin_get_session_option', 'rustdesk_bridge_plugin_get_session_option']
    );
    if (!fn) return '';
    try { return fn(id, key) || ''; } catch { return ''; }
  }

  static pluginSetSessionOption(id: string, key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, key: string, value: string], void>(
      nativeModule,
      ['pluginSetSessionOption', 'plugin_set_session_option', 'rustdesk_bridge_plugin_set_session_option']
    );
    if (!fn) return;
    try { fn(id, key, value); } catch { /* ignore */ }
  }

  static pluginGetSharedOption(id: string, key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, key: string], string>(
      nativeModule,
      ['pluginGetSharedOption', 'plugin_get_shared_option', 'rustdesk_bridge_plugin_get_shared_option']
    );
    if (!fn) return '';
    try { return fn(id, key) || ''; } catch { return ''; }
  }

  static pluginSetSharedOption(id: string, key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, key: string, value: string], void>(
      nativeModule,
      ['pluginSetSharedOption', 'plugin_set_shared_option', 'rustdesk_bridge_plugin_set_shared_option']
    );
    if (!fn) return;
    try { fn(id, key, value); } catch { /* ignore */ }
  }

  static pluginReload(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['pluginReload', 'plugin_reload', 'rustdesk_bridge_plugin_reload']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static pluginEnable(id: string, enable: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, enable: boolean], void>(
      nativeModule,
      ['pluginEnable', 'plugin_enable', 'rustdesk_bridge_plugin_enable']
    );
    if (!fn) return;
    try { fn(id, enable); } catch { /* ignore */ }
  }

  static pluginIsEnabled(id: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], boolean>(
      nativeModule,
      ['pluginIsEnabled', 'plugin_is_enabled', 'rustdesk_bridge_plugin_is_enabled']
    );
    if (!fn) return false;
    try { return fn(id) || false; } catch { return false; }
  }

  static pluginFeatureIsEnabled(id: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], boolean>(
      nativeModule,
      ['pluginFeatureIsEnabled', 'plugin_feature_is_enabled', 'rustdesk_bridge_plugin_feature_is_enabled']
    );
    if (!fn) return false;
    try { return fn(id) || false; } catch { return false; }
  }

  static pluginSyncUi(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['pluginSyncUi', 'plugin_sync_ui', 'rustdesk_bridge_plugin_sync_ui']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static pluginListReload(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['pluginListReload', 'plugin_list_reload', 'rustdesk_bridge_plugin_list_reload']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static pluginInstall(id: string, b: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, b: boolean], void>(
      nativeModule,
      ['pluginInstall', 'plugin_install', 'rustdesk_bridge_plugin_install']
    );
    if (!fn) return;
    try { fn(id, b); } catch { /* ignore */ }
  }

  static installInstallMe(path: string, options: string, exe: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: string, options: string, exe: string], void>(
      nativeModule,
      ['installInstallMe', 'install_install_me', 'rustdesk_bridge_install_install_me']
    );
    if (!fn) return;
    try { fn(path, options, exe); } catch { /* ignore */ }
  }

  static installInstallOptions(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['installInstallOptions', 'install_install_options', 'rustdesk_bridge_install_install_options']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static installInstallPath(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['installInstallPath', 'install_install_path', 'rustdesk_bridge_install_install_path']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static installRunWithoutInstall(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['installRunWithoutInstall', 'install_run_without_install', 'rustdesk_bridge_install_run_without_install']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static installShowRunWithoutInstall(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['installShowRunWithoutInstall', 'install_show_run_without_install', 'rustdesk_bridge_install_show_run_without_install']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isCustomClient(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isCustomClient', 'is_custom_client', 'rustdesk_bridge_is_custom_client']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isDisableAb(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isDisableAb', 'is_disable_ab', 'rustdesk_bridge_is_disable_ab']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isDisableAccount(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isDisableAccount', 'is_disable_account', 'rustdesk_bridge_is_disable_account']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isDisableGroupPanel(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isDisableGroupPanel', 'is_disable_group_panel', 'rustdesk_bridge_is_disable_group_panel']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isDisableInstallation(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isDisableInstallation', 'is_disable_installation', 'rustdesk_bridge_is_disable_installation']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isDisableSettings(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isDisableSettings', 'is_disable_settings', 'rustdesk_bridge_is_disable_settings']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isIncomingOnly(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isIncomingOnly', 'is_incoming_only', 'rustdesk_bridge_is_incoming_only']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isOutgoingOnly(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isOutgoingOnly', 'is_outgoing_only', 'rustdesk_bridge_is_outgoing_only']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isPresetPassword(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isPresetPassword', 'is_preset_password', 'rustdesk_bridge_is_preset_password']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isPresetPasswordMobileOnly(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isPresetPasswordMobileOnly', 'is_preset_password_mobile_only', 'rustdesk_bridge_is_preset_password_mobile_only']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isSelinuxEnforcing(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isSelinuxEnforcing', 'is_selinux_enforcing', 'rustdesk_bridge_is_selinux_enforcing']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static isSupportMultiUiSession(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['isSupportMultiUiSession', 'is_support_multi_ui_session', 'rustdesk_bridge_is_support_multi_ui_session']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainChangeId(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['mainChangeId', 'main_change_id', 'rustdesk_bridge_main_change_id']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static mainChangeLanguage(lang: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[lang: string], void>(
      nativeModule,
      ['mainChangeLanguage', 'main_change_language', 'rustdesk_bridge_main_change_language']
    );
    if (!fn) return;
    try { fn(lang); } catch { /* ignore */ }
  }

  static mainChangeTheme(dark: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[dark: string], void>(
      nativeModule,
      ['mainChangeTheme', 'main_change_theme', 'rustdesk_bridge_main_change_theme']
    );
    if (!fn) return;
    try { fn(dark); } catch { /* ignore */ }
  }

  static mainGetDisplays(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetDisplays', 'main_get_displays', 'rustdesk_bridge_main_get_displays']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetPrinterNames(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetPrinterNames', 'main_get_printer_names', 'rustdesk_bridge_main_get_printer_names']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetSocks(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetSocks', 'main_get_socks', 'rustdesk_bridge_main_get_socks']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainSetSocks(proxy: string, username: string, password: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[proxy: string, username: string, password: string], void>(
      nativeModule,
      ['mainSetSocks', 'main_set_socks', 'rustdesk_bridge_main_set_socks']
    );
    if (!fn) return;
    try { fn(proxy, username, password); } catch { /* ignore */ }
  }

  static mainGetProxyStatus(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainGetProxyStatus', 'main_get_proxy_status', 'rustdesk_bridge_main_get_proxy_status']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGetAppNameSync(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetAppNameSync', 'main_get_app_name_sync', 'rustdesk_bridge_main_get_app_name_sync']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetNewVersion(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetNewVersion', 'main_get_new_version', 'rustdesk_bridge_main_get_new_version']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetHomeDir(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetHomeDir', 'main_get_home_dir', 'rustdesk_bridge_main_get_home_dir']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainDeviceId(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainDeviceId', 'main_device_id', 'rustdesk_bridge_main_device_id']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainDeviceName(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainDeviceName', 'main_device_name', 'rustdesk_bridge_main_device_name']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainIsInstalled(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsInstalled', 'main_is_installed', 'rustdesk_bridge_main_is_installed']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsInstalledDaemon(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsInstalledDaemon', 'main_is_installed_daemon', 'rustdesk_bridge_main_is_installed_daemon']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsRoot(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsRoot', 'main_is_root', 'rustdesk_bridge_main_is_root']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsProcessTrusted(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsProcessTrusted', 'main_is_process_trusted', 'rustdesk_bridge_main_is_process_trusted']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsCanScreenRecording(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsCanScreenRecording', 'main_is_can_screen_recording', 'rustdesk_bridge_main_is_can_screen_recording']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsCanInputMonitoring(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsCanInputMonitoring', 'main_is_can_input_monitoring', 'rustdesk_bridge_main_is_can_input_monitoring']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainCurrentIsWayland(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainCurrentIsWayland', 'main_current_is_wayland', 'rustdesk_bridge_main_current_is_wayland']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsLoginWayland(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsLoginWayland', 'main_is_login_wayland', 'rustdesk_bridge_main_is_login_wayland']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainHasVram(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasVram', 'main_has_vram', 'rustdesk_bridge_main_has_vram']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainSupportedHwdecodings(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainSupportedHwdecodings', 'main_supported_hwdecodings', 'rustdesk_bridge_main_supported_hwdecodings']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainCheckHwcodec(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainCheckHwcodec', 'main_check_hwcodec', 'rustdesk_bridge_main_check_hwcodec']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainCreateShortcut(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainCreateShortcut', 'main_create_shortcut', 'rustdesk_bridge_main_create_shortcut']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGetMouseTime(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['mainGetMouseTime', 'main_get_mouse_time', 'rustdesk_bridge_main_get_mouse_time']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static mainCheckMouseTime(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainCheckMouseTime', 'main_check_mouse_time', 'rustdesk_bridge_main_check_mouse_time']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGetAsyncStatus(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetAsyncStatus', 'main_get_async_status', 'rustdesk_bridge_main_get_async_status']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetLanPeers(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetLanPeers', 'main_get_lan_peers', 'rustdesk_bridge_main_get_lan_peers']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetLastRemoteId(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetLastRemoteId', 'main_get_last_remote_id', 'rustdesk_bridge_main_get_last_remote_id']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetFav(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetFav', 'main_get_fav', 'rustdesk_bridge_main_get_fav']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainStoreFav(fav: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[fav: string], void>(
      nativeModule,
      ['mainStoreFav', 'main_store_fav', 'rustdesk_bridge_main_store_fav']
    );
    if (!fn) return;
    try { fn(fav); } catch { /* ignore */ }
  }

  static mainGetPeerSync(id: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], string>(
      nativeModule,
      ['mainGetPeerSync', 'main_get_peer_sync', 'rustdesk_bridge_main_get_peer_sync']
    );
    if (!fn) return '';
    try { return fn(id) || ''; } catch { return ''; }
  }

  static mainGetPeerFlutterOptionSync(id: string, k: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, k: string], string>(
      nativeModule,
      ['mainGetPeerFlutterOptionSync', 'main_get_peer_flutter_option_sync', 'rustdesk_bridge_main_get_peer_flutter_option_sync']
    );
    if (!fn) return '';
    try { return fn(id, k) || ''; } catch { return ''; }
  }

  static mainSetPeerFlutterOptionSync(id: string, k: string, v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, k: string, v: string], void>(
      nativeModule,
      ['mainSetPeerFlutterOptionSync', 'main_set_peer_flutter_option_sync', 'rustdesk_bridge_main_set_peer_flutter_option_sync']
    );
    if (!fn) return;
    try { fn(id, k, v); } catch { /* ignore */ }
  }

  static mainGetPeerOptionSync(id: string, k: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, k: string], string>(
      nativeModule,
      ['mainGetPeerOptionSync', 'main_get_peer_option_sync', 'rustdesk_bridge_main_get_peer_option_sync']
    );
    if (!fn) return '';
    try { return fn(id, k) || ''; } catch { return ''; }
  }

  static mainSetPeerOptionSync(id: string, k: string, v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string, k: string, v: string], void>(
      nativeModule,
      ['mainSetPeerOptionSync', 'main_set_peer_option_sync', 'rustdesk_bridge_main_set_peer_option_sync']
    );
    if (!fn) return;
    try { fn(id, k, v); } catch { /* ignore */ }
  }

  static mainRemoveTrustedDevices(json: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[json: string], void>(
      nativeModule,
      ['mainRemoveTrustedDevices', 'main_remove_trusted_devices', 'rustdesk_bridge_main_remove_trusted_devices']
    );
    if (!fn) return;
    try { fn(json); } catch { /* ignore */ }
  }

  static mainHasValid_2faSync(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasValid_2faSync', 'main_has_valid_2fa_sync', 'rustdesk_bridge_main_has_valid_2fa_sync']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainHasValidBotSync(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasValidBotSync', 'main_has_valid_bot_sync', 'rustdesk_bridge_main_has_valid_bot_sync']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainVerifyBot(token: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[token: string], boolean>(
      nativeModule,
      ['mainVerifyBot', 'main_verify_bot', 'rustdesk_bridge_main_verify_bot']
    );
    if (!fn) return false;
    try { return fn(token) || false; } catch { return false; }
  }

  static mainMaxEncryptLen(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['mainMaxEncryptLen', 'main_max_encrypt_len', 'rustdesk_bridge_main_max_encrypt_len']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static mainGetUnlockPin(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetUnlockPin', 'main_get_unlock_pin', 'rustdesk_bridge_main_get_unlock_pin']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainSetUnlockPin(pin: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[pin: string], void>(
      nativeModule,
      ['mainSetUnlockPin', 'main_set_unlock_pin', 'rustdesk_bridge_main_set_unlock_pin']
    );
    if (!fn) return;
    try { fn(pin); } catch { /* ignore */ }
  }

  static mainOptionSynced(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainOptionSynced', 'main_option_synced', 'rustdesk_bridge_main_option_synced']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainSupportRemoveWallpaper(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainSupportRemoveWallpaper', 'main_support_remove_wallpaper', 'rustdesk_bridge_main_support_remove_wallpaper']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainTestWallpaper(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainTestWallpaper', 'main_test_wallpaper', 'rustdesk_bridge_main_test_wallpaper']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainSupportedPrivacyModeImpls(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainSupportedPrivacyModeImpls', 'main_supported_privacy_mode_impls', 'rustdesk_bridge_main_supported_privacy_mode_impls']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainDefaultPrivacyModeImpl(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainDefaultPrivacyModeImpl', 'main_default_privacy_mode_impl', 'rustdesk_bridge_main_default_privacy_mode_impl']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainIsOptionFixed(key: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], boolean>(
      nativeModule,
      ['mainIsOptionFixed', 'main_is_option_fixed', 'rustdesk_bridge_main_is_option_fixed']
    );
    if (!fn) return false;
    try { return fn(key) || false; } catch { return false; }
  }

  static mainGetUseTextureRender(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainGetUseTextureRender', 'main_get_use_texture_render', 'rustdesk_bridge_main_get_use_texture_render']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainHasFileClipboard(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasFileClipboard', 'main_has_file_clipboard', 'rustdesk_bridge_main_has_file_clipboard']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainHasGpuTextureRender(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainHasGpuTextureRender', 'main_has_gpu_texture_render', 'rustdesk_bridge_main_has_gpu_texture_render']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainAudioSupportLoopback(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainAudioSupportLoopback', 'main_audio_support_loopback', 'rustdesk_bridge_main_audio_support_loopback']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainIsShareRdp(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsShareRdp', 'main_is_share_rdp', 'rustdesk_bridge_main_is_share_rdp']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainSetShareRdp(v: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[v: boolean], void>(
      nativeModule,
      ['mainSetShareRdp', 'main_set_share_rdp', 'rustdesk_bridge_main_set_share_rdp']
    );
    if (!fn) return;
    try { fn(v); } catch { /* ignore */ }
  }

  static mainIsInstalledLowerVersion(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainIsInstalledLowerVersion', 'main_is_installed_lower_version', 'rustdesk_bridge_main_is_installed_lower_version']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGetSoftwareUpdateUrl(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetSoftwareUpdateUrl', 'main_get_software_update_url', 'rustdesk_bridge_main_get_software_update_url']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainHandleRelayId(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['mainHandleRelayId', 'main_handle_relay_id', 'rustdesk_bridge_main_handle_relay_id']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static mainHideDock(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainHideDock', 'main_hide_dock', 'rustdesk_bridge_main_hide_dock']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainSetCursorPosition(x: number, y: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[x: number, y: number], void>(
      nativeModule,
      ['mainSetCursorPosition', 'main_set_cursor_position', 'rustdesk_bridge_main_set_cursor_position']
    );
    if (!fn) return;
    try { fn(x, y); } catch { /* ignore */ }
  }

  static mainClipCursor(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainClipCursor', 'main_clip_cursor', 'rustdesk_bridge_main_clip_cursor']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainGetEnv(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetEnv', 'main_get_env', 'rustdesk_bridge_main_get_env']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainSetEnv(key: string, value: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string, value: string], void>(
      nativeModule,
      ['mainSetEnv', 'main_set_env', 'rustdesk_bridge_main_set_env']
    );
    if (!fn) return;
    try { fn(key, value); } catch { /* ignore */ }
  }

  static mainSetHomeDir(home: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[home: string], void>(
      nativeModule,
      ['mainSetHomeDir', 'main_set_home_dir', 'rustdesk_bridge_main_set_home_dir']
    );
    if (!fn) return;
    try { fn(home); } catch { /* ignore */ }
  }

  static mainStartDbusServer(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainStartDbusServer', 'main_start_dbus_server', 'rustdesk_bridge_main_start_dbus_server']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainStartIpcUrlServer(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainStartIpcUrlServer', 'main_start_ipc_url_server', 'rustdesk_bridge_main_start_ipc_url_server']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainCheckSuperUserPermission(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainCheckSuperUserPermission', 'main_check_super_user_permission', 'rustdesk_bridge_main_check_super_user_permission']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGotoInstall(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGotoInstall', 'main_goto_install', 'rustdesk_bridge_main_goto_install']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainUpdateMe(path: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: string], void>(
      nativeModule,
      ['mainUpdateMe', 'main_update_me', 'rustdesk_bridge_main_update_me']
    );
    if (!fn) return;
    try { fn(path); } catch { /* ignore */ }
  }

  static mainDeployDevice(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['mainDeployDevice', 'main_deploy_device', 'rustdesk_bridge_main_deploy_device']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static mainGetMainDisplay(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetMainDisplay', 'main_get_main_display', 'rustdesk_bridge_main_get_main_display']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetInputSource(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetInputSource', 'main_get_input_source', 'rustdesk_bridge_main_get_input_source']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainSetInputSource(source: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[source: string], void>(
      nativeModule,
      ['mainSetInputSource', 'main_set_input_source', 'rustdesk_bridge_main_set_input_source']
    );
    if (!fn) return;
    try { fn(source); } catch { /* ignore */ }
  }

  static mainInitInputSource(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainInitInputSource', 'main_init_input_source', 'rustdesk_bridge_main_init_input_source']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainSupportedInputSource(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainSupportedInputSource', 'main_supported_input_source', 'rustdesk_bridge_main_supported_input_source']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainVideoSaveDirectory(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainVideoSaveDirectory', 'main_video_save_directory', 'rustdesk_bridge_main_video_save_directory']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetDataDirIos(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetDataDirIos', 'main_get_data_dir_ios', 'rustdesk_bridge_main_get_data_dir_ios']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainShowOption(key: string): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], boolean>(
      nativeModule,
      ['mainShowOption', 'main_show_option', 'rustdesk_bridge_main_show_option']
    );
    if (!fn) return false;
    try { return fn(key) || false; } catch { return false; }
  }

  static mainSetOptions(options: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[options: string], void>(
      nativeModule,
      ['mainSetOptions', 'main_set_options', 'rustdesk_bridge_main_set_options']
    );
    if (!fn) return;
    try { fn(options); } catch { /* ignore */ }
  }

  static mainGetOptionsSync(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetOptionsSync', 'main_get_options_sync', 'rustdesk_bridge_main_get_options_sync']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainGetOptionSync(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetOptionSync', 'main_get_option_sync', 'rustdesk_bridge_main_get_option_sync']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainGetCommonSync(key: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: string], string>(
      nativeModule,
      ['mainGetCommonSync', 'main_get_common_sync', 'rustdesk_bridge_main_get_common_sync']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static mainGetHttpStatus(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainGetHttpStatus', 'main_get_http_status', 'rustdesk_bridge_main_get_http_status']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainUriPrefixSync(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainUriPrefixSync', 'main_uri_prefix_sync', 'rustdesk_bridge_main_uri_prefix_sync']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainLoadAb(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainLoadAb', 'main_load_ab', 'rustdesk_bridge_main_load_ab']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainSaveAb(ab: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[ab: string], void>(
      nativeModule,
      ['mainSaveAb', 'main_save_ab', 'rustdesk_bridge_main_save_ab']
    );
    if (!fn) return;
    try { fn(ab); } catch { /* ignore */ }
  }

  static mainClearAb(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainClearAb', 'main_clear_ab', 'rustdesk_bridge_main_clear_ab']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainLoadGroup(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainLoadGroup', 'main_load_group', 'rustdesk_bridge_main_load_group']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainSaveGroup(group: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[group: string], void>(
      nativeModule,
      ['mainSaveGroup', 'main_save_group', 'rustdesk_bridge_main_save_group']
    );
    if (!fn) return;
    try { fn(group); } catch { /* ignore */ }
  }

  static mainClearGroup(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['mainClearGroup', 'main_clear_group', 'rustdesk_bridge_main_clear_group']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static mainLoadFavPeers(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainLoadFavPeers', 'main_load_fav_peers', 'rustdesk_bridge_main_load_fav_peers']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainLoadRecentPeersForAb(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['mainLoadRecentPeersForAb', 'main_load_recent_peers_for_ab', 'rustdesk_bridge_main_load_recent_peers_for_ab']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static mainHandleWaylandScreencastRestoreToken(token: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[token: string], void>(
      nativeModule,
      ['mainHandleWaylandScreencastRestoreToken', 'main_handle_wayland_screencast_restore_token', 'rustdesk_bridge_main_handle_wayland_screencast_restore_token']
    );
    if (!fn) return;
    try { fn(token); } catch { /* ignore */ }
  }

  static getDoubleClickTime(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['getDoubleClickTime', 'get_double_click_time', 'rustdesk_bridge_get_double_click_time']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static getLocalFlutterOption(k: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string], string>(
      nativeModule,
      ['getLocalFlutterOption', 'get_local_flutter_option', 'rustdesk_bridge_get_local_flutter_option']
    );
    if (!fn) return '';
    try { return fn(k) || ''; } catch { return ''; }
  }

  static setLocalFlutterOption(k: string, v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[k: string, v: string], void>(
      nativeModule,
      ['setLocalFlutterOption', 'set_local_flutter_option', 'rustdesk_bridge_set_local_flutter_option']
    );
    if (!fn) return;
    try { fn(k, v); } catch { /* ignore */ }
  }

  static getLocalKbLayoutType(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getLocalKbLayoutType', 'get_local_kb_layout_type', 'rustdesk_bridge_get_local_kb_layout_type']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static setLocalKbLayoutType(v: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[v: string], void>(
      nativeModule,
      ['setLocalKbLayoutType', 'set_local_kb_layout_type', 'rustdesk_bridge_set_local_kb_layout_type']
    );
    if (!fn) return;
    try { fn(v); } catch { /* ignore */ }
  }

  static getVoiceCallInputDevice(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['getVoiceCallInputDevice', 'get_voice_call_input_device', 'rustdesk_bridge_get_voice_call_input_device']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static setVoiceCallInputDevice(device: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[device: string], void>(
      nativeModule,
      ['setVoiceCallInputDevice', 'set_voice_call_input_device', 'rustdesk_bridge_set_voice_call_input_device']
    );
    if (!fn) return;
    try { fn(device); } catch { /* ignore */ }
  }

  static hostStopSystemKeyPropagate(stop: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[stop: boolean], void>(
      nativeModule,
      ['hostStopSystemKeyPropagate', 'host_stop_system_key_propagate', 'rustdesk_bridge_host_stop_system_key_propagate']
    );
    if (!fn) return;
    try { fn(stop); } catch { /* ignore */ }
  }

  static optionSynced(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['optionSynced', 'option_synced', 'rustdesk_bridge_option_synced']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static peerGetSessionsCount(): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], any>(
      nativeModule,
      ['peerGetSessionsCount', 'peer_get_sessions_count', 'rustdesk_bridge_peer_get_sessions_count']
    );
    if (!fn) return undefined;
    try { return fn() || undefined; } catch { return undefined; }
  }

  static sendUrlScheme(url: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[url: string], void>(
      nativeModule,
      ['sendUrlScheme', 'send_url_scheme', 'rustdesk_bridge_send_url_scheme']
    );
    if (!fn) return;
    try { fn(url); } catch { /* ignore */ }
  }

  static setCurSessionId(id: string): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: string], void>(
      nativeModule,
      ['setCurSessionId', 'set_cur_session_id', 'rustdesk_bridge_set_cur_session_id']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static startGlobalEventStream(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['startGlobalEventStream', 'start_global_event_stream', 'rustdesk_bridge_start_global_event_stream']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static stopGlobalEventStream(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['stopGlobalEventStream', 'stop_global_event_stream', 'rustdesk_bridge_stop_global_event_stream']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static translate(name: string): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[name: string], string>(
      nativeModule,
      ['translate', 'translate', 'rustdesk_bridge_translate']
    );
    if (!fn) return '';
    try { return fn(name) || ''; } catch { return ''; }
  }

  static versionToNumber(v: string): any {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[v: string], any>(
      nativeModule,
      ['versionToNumber', 'version_to_number', 'rustdesk_bridge_version_to_number']
    );
    if (!fn) return undefined;
    try { return fn(v) || undefined; } catch { return undefined; }
  }

  static willSessionCloseCloseSession(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['willSessionCloseCloseSession', 'will_session_close_close_session', 'rustdesk_bridge_will_session_close_close_session']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static getNextTextureKey(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], number>(
      nativeModule,
      ['getNextTextureKey', 'get_next_texture_key', 'rustdesk_bridge_get_next_texture_key']
    );
    if (!fn) return 0;
    try { return fn() || 0; } catch { return 0; }
  }


  // ---- extended session & main functions ----
  static mainInit(app_dir: any, custom_client_config: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[app_dir: any, custom_client_config: any], void>(
      nativeModule,
      ['mainInit', 'main_init', 'rustdesk_bridge_main_init']
    );
    if (!fn) return;
    try { fn(app_dir, custom_client_config); } catch { /* ignore */ }
  }

  static sessionAddExistedSync(is_sync: boolean): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[is_sync: boolean], boolean>(
      nativeModule,
      ['sessionAddExistedSync', 'session_add_existed_sync', 'rustdesk_bridge_session_add_existed_sync']
    );
    if (!fn) return false;
    try { return fn(is_sync) || false; } catch { return false; }
  }

  static sessionAddJob(id: number, path: any, to: any, file_num: number, include_hidden: boolean, is_remote: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, path: any, to: any, file_num: number, include_hidden: boolean, is_remote: boolean], void>(
      nativeModule,
      ['sessionAddJob', 'session_add_job', 'rustdesk_bridge_session_add_job']
    );
    if (!fn) return;
    try { fn(id, path, to, file_num, include_hidden, is_remote); } catch { /* ignore */ }
  }

  static sessionAddSync(is_sync: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[is_sync: boolean], void>(
      nativeModule,
      ['sessionAddSync', 'session_add_sync', 'rustdesk_bridge_session_add_sync']
    );
    if (!fn) return;
    try { fn(is_sync); } catch { /* ignore */ }
  }

  static sessionGetAuditGuid(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetAuditGuid', 'session_get_audit_guid', 'rustdesk_bridge_session_get_audit_guid']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionGetAuditServerSync(typ: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[typ: any], string>(
      nativeModule,
      ['sessionGetAuditServerSync', 'session_get_audit_server_sync', 'rustdesk_bridge_session_get_audit_server_sync']
    );
    if (!fn) return '';
    try { return fn(typ) || ''; } catch { return ''; }
  }

  static sessionGetCommon(key: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: any], string>(
      nativeModule,
      ['sessionGetCommon', 'session_get_common', 'rustdesk_bridge_session_get_common']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static sessionGetCommonSync(key: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[key: any], string>(
      nativeModule,
      ['sessionGetCommonSync', 'session_get_common_sync', 'rustdesk_bridge_session_get_common_sync']
    );
    if (!fn) return '';
    try { return fn(key) || ''; } catch { return ''; }
  }

  static sessionGetConnSessionId(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetConnSessionId', 'session_get_conn_session_id', 'rustdesk_bridge_session_get_conn_session_id']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionGetDisplaysAsIndividualWindows(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetDisplaysAsIndividualWindows', 'session_get_displays_as_individual_windows', 'rustdesk_bridge_session_get_displays_as_individual_windows']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionGetEdgeScrollEdgeThickness(): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], number>(
      nativeModule,
      ['sessionGetEdgeScrollEdgeThickness', 'session_get_edge_scroll_edge_thickness', 'rustdesk_bridge_session_get_edge_scroll_edge_thickness']
    );
    if (!fn) return 0;
    try { return fn() || 0; } catch { return 0; }
  }

  static sessionGetLastAuditNote(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetLastAuditNote', 'session_get_last_audit_note', 'rustdesk_bridge_session_get_last_audit_note']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionGetRgbaSize(display: number): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], number>(
      nativeModule,
      ['sessionGetRgbaSize', 'session_get_rgba_size', 'rustdesk_bridge_session_get_rgba_size']
    );
    if (!fn) return 0;
    try { return fn(display) || 0; } catch { return 0; }
  }

  static sessionGetToggleOptionSync(arg: any): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[arg: any], boolean>(
      nativeModule,
      ['sessionGetToggleOptionSync', 'session_get_toggle_option_sync', 'rustdesk_bridge_session_get_toggle_option_sync']
    );
    if (!fn) return false;
    try { return fn(arg) || false; } catch { return false; }
  }

  static sessionGetUseAllMyDisplaysForTheRemoteSession(): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], string>(
      nativeModule,
      ['sessionGetUseAllMyDisplaysForTheRemoteSession', 'session_get_use_all_my_displays_for_the_remote_session', 'rustdesk_bridge_session_get_use_all_my_displays_for_the_remote_session']
    );
    if (!fn) return '';
    try { return fn() || ''; } catch { return ''; }
  }

  static sessionHandleScreenshot(action: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[action: any], string>(
      nativeModule,
      ['sessionHandleScreenshot', 'session_handle_screenshot', 'rustdesk_bridge_session_handle_screenshot']
    );
    if (!fn) return '';
    try { return fn(action) || ''; } catch { return ''; }
  }

  static sessionIsMultiUiSession(): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], boolean>(
      nativeModule,
      ['sessionIsMultiUiSession', 'session_is_multi_ui_session', 'rustdesk_bridge_session_is_multi_ui_session']
    );
    if (!fn) return false;
    try { return fn() || false; } catch { return false; }
  }

  static sessionNextRgba(display: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], void>(
      nativeModule,
      ['sessionNextRgba', 'session_next_rgba', 'rustdesk_bridge_session_next_rgba']
    );
    if (!fn) return;
    try { fn(display); } catch { /* ignore */ }
  }

  static sessionOnWaitingForImageDialogShow(): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[], void>(
      nativeModule,
      ['sessionOnWaitingForImageDialogShow', 'session_on_waiting_for_image_dialog_show', 'rustdesk_bridge_session_on_waiting_for_image_dialog_show']
    );
    if (!fn) return;
    try { fn(); } catch { /* ignore */ }
  }

  static sessionPrinterResponse(id: number, path: any, printer_name: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, path: any, printer_name: any], void>(
      nativeModule,
      ['sessionPrinterResponse', 'session_printer_response', 'rustdesk_bridge_session_printer_response']
    );
    if (!fn) return;
    try { fn(id, path, printer_name); } catch { /* ignore */ }
  }

  static sessionReadDirToRemoveRecursive(id: number, path: any, include_hidden: boolean): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, path: any, include_hidden: boolean], void>(
      nativeModule,
      ['sessionReadDirToRemoveRecursive', 'session_read_dir_to_remove_recursive', 'rustdesk_bridge_session_read_dir_to_remove_recursive']
    );
    if (!fn) return;
    try { fn(id, path, include_hidden); } catch { /* ignore */ }
  }

  static sessionReadLocalDirSync(path: any, include_hidden: boolean, id: number): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[path: any, include_hidden: boolean, id: number], string>(
      nativeModule,
      ['sessionReadLocalDirSync', 'session_read_local_dir_sync', 'rustdesk_bridge_session_read_local_dir_sync']
    );
    if (!fn) return '';
    try { return fn(path, include_hidden, id) || ''; } catch { return ''; }
  }

  static sessionReadLocalEmptyDirsRecursiveSync(id: number, path: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, path: any], string>(
      nativeModule,
      ['sessionReadLocalEmptyDirsRecursiveSync', 'session_read_local_empty_dirs_recursive_sync', 'rustdesk_bridge_session_read_local_empty_dirs_recursive_sync']
    );
    if (!fn) return '';
    try { return fn(id, path) || ''; } catch { return ''; }
  }

  static sessionReadRemoteEmptyDirsRecursiveSync(id: number, path: any): string {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number, path: any], string>(
      nativeModule,
      ['sessionReadRemoteEmptyDirsRecursiveSync', 'session_read_remote_empty_dirs_recursive_sync', 'rustdesk_bridge_session_read_remote_empty_dirs_recursive_sync']
    );
    if (!fn) return '';
    try { return fn(id, path) || ''; } catch { return ''; }
  }

  static sessionRegisterGpuTexture(display: number): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], number>(
      nativeModule,
      ['sessionRegisterGpuTexture', 'session_register_gpu_texture', 'rustdesk_bridge_session_register_gpu_texture']
    );
    if (!fn) return 0;
    try { return fn(display) || 0; } catch { return 0; }
  }

  static sessionRegisterPixelbufferTexture(display: number): number {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], number>(
      nativeModule,
      ['sessionRegisterPixelbufferTexture', 'session_register_pixelbuffer_texture', 'rustdesk_bridge_session_register_pixelbuffer_texture']
    );
    if (!fn) return 0;
    try { return fn(display) || 0; } catch { return 0; }
  }

  static sessionRemoveAllEmptyDirs(id: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[id: number], void>(
      nativeModule,
      ['sessionRemoveAllEmptyDirs', 'session_remove_all_empty_dirs', 'rustdesk_bridge_session_remove_all_empty_dirs']
    );
    if (!fn) return;
    try { fn(id); } catch { /* ignore */ }
  }

  static sessionRequestNewDisplayInitMsgs(display: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[display: number], void>(
      nativeModule,
      ['sessionRequestNewDisplayInitMsgs', 'session_request_new_display_init_msgs', 'rustdesk_bridge_session_request_new_display_init_msgs']
    );
    if (!fn) return;
    try { fn(display); } catch { /* ignore */ }
  }

  static sessionSendPointer(msg: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[msg: any], void>(
      nativeModule,
      ['sessionSendPointer', 'session_send_pointer', 'rustdesk_bridge_session_send_pointer']
    );
    if (!fn) return;
    try { fn(msg); } catch { /* ignore */ }
  }

  static sessionSetAuditGuid(guid: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[guid: any], void>(
      nativeModule,
      ['sessionSetAuditGuid', 'session_set_audit_guid', 'rustdesk_bridge_session_set_audit_guid']
    );
    if (!fn) return;
    try { fn(guid); } catch { /* ignore */ }
  }

  static sessionSetDisplaysAsIndividualWindows(value: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: any], void>(
      nativeModule,
      ['sessionSetDisplaysAsIndividualWindows', 'session_set_displays_as_individual_windows', 'rustdesk_bridge_session_set_displays_as_individual_windows']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionSetEdgeScrollEdgeThickness(value: number): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: number], void>(
      nativeModule,
      ['sessionSetEdgeScrollEdgeThickness', 'session_set_edge_scroll_edge_thickness', 'rustdesk_bridge_session_set_edge_scroll_edge_thickness']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionSetUseAllMyDisplaysForTheRemoteSession(value: any): void {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[value: any], void>(
      nativeModule,
      ['sessionSetUseAllMyDisplaysForTheRemoteSession', 'session_set_use_all_my_displays_for_the_remote_session', 'rustdesk_bridge_session_set_use_all_my_displays_for_the_remote_session']
    );
    if (!fn) return;
    try { fn(value); } catch { /* ignore */ }
  }

  static sessionStartWithDisplays(displays: any): boolean {
    const nativeModule = NativeRustDeskBridge.getModule();
    const fn = NativeRustDeskBridge.resolveFunction<[displays: any], boolean>(
      nativeModule,
      ['sessionStartWithDisplays', 'session_start_with_displays', 'rustdesk_bridge_session_start_with_displays']
    );
    if (!fn) return false;
    try { return fn(displays) || false; } catch { return false; }
  }


}
