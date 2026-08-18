import { createStrokeIconColorFilter, EmptyState } from '../common/CommonComponents';
import { AppDataService, SettingsState } from '../services/AppDataService';
import { OfficialCoreState, OfficialRustDeskBridge, OfficialSessionEvent } from '../services/OfficialRustDeskBridge';
import { NativeRustDeskBridge, NativeVideoFrame } from '../services/NativeRustDeskBridge';
import { RemoteCursor } from '../components/RemoteCursor';
import { ThemeConfig } from '../common/ThemeConfig';
import { util } from '@kit.ArkTS';

import image from '@ohos.multimedia.image';
import { I18nService } from '../services/I18nService';
import { MOUSE_MASK } from '../services/InputService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { PreferenceStore } from '../services/PreferenceStore';
import { TouchInteractionManager, TouchInteractionState, TouchInteractionContext, MarqueeRect } from '../common/TouchInteractionManager';
import { TouchAction, TouchSettings, DEFAULT_TOUCH_SETTINGS, TOUCH_ACTION_LABELS, TAP_ACTIONS, LONG_PRESS_ACTIONS, SWIPE_ACTIONS, SHORT_PRESS_DRAG_ACTIONS, LONG_PRESS_DRAG_ACTIONS, TWO_FINGER_PINCH_ACTIONS, TWO_FINGER_PAN_ACTIONS } from '../common/TouchActionConfig';
import { WindowChromeService } from '../services/WindowChromeService';
import { ClipboardService } from '../services/ClipboardService';
import { AudioService } from '../services/AudioService';
import { ChatEvent, ChatMessage, ChatMessageType, ChatService } from '../services/ChatService';
import { FrameService, frameService } from '../services/FrameService';
import { AppState, appState } from '../services/AppState';
import audio from '@ohos.multimedia.audio';
import hilog from '@ohos.hilog';
import { Logger } from '../common/Logger';

interface DeviceRouteParams {
  deviceId: string;
  deviceName?: string;
  clearChat?: string;
}

interface RemoteTouchPoint {
  x: number;
  y: number;
}

interface RemoteMouseInput {
  mask: number;
  x: number;
  y: number;
}

interface SessionBadgePalette {
  text: string;
  backgroundColor: string;
  fontColor: string;
}

interface RemoteCursorDetailPayload {
  id: string;
  hotx: number;
  hoty: number;
  width: number;
  height: number;
  colors: number[];
}

interface RemoteCursorAsset {
  pixelMap: image.PixelMap;
  hotx: number;
  hoty: number;
  width: number;
  height: number;
}

interface AudioFrameData {
  sampleRate: number;
  channels: number;
  format: string;
  timestamp: number;
  dataBase64: string;
}

interface SessionRetryPrompt {
  title: string;
  text: string;
  canUseRelay: boolean;
}

interface QualityMetricItem {
  key: string;
  label: string;
  value: string;
  priority: number;
}

interface PanelHeaderAction {
  icon: string;
  isStroke: boolean;
  action: () => void;
}

function base64ToArrayBuffer(base64Str: string): ArrayBuffer {
  const base64Helper = new util.Base64Helper();
  const uint8Arr: Uint8Array = base64Helper.decodeSync(base64Str);
  return uint8Arr.buffer;
}

@Entry
@Component
struct RemoteControl {
  private appData: AppDataService = AppDataService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private settings: SettingsState = this.appData.getSettings();
  private frameRefreshTimer: number = -1;
  private bridgeRefreshTimer: number = -1;
  private audioFrameRefreshTimer: number = -1;
  private audioService: AudioService = AudioService.getInstance();
  private chatService: ChatService = ChatService.getInstance();
  private audioRenderer: audio.AudioRenderer | null = null;
  private remoteAudioEnabled: boolean = false;
  @State renderedFrame: image.PixelMap | null = null;
  private renderedFrameWidth: number = 0;
  private renderedFrameHeight: number = 0;
  private renderedFrameFormat: string = '';
  private staleFrames: image.PixelMap[] = [];
  private lastFrameId: number = 0;
  private frameRefreshInFlight: boolean = false;
  private renderGeneration: number = 0;
  private frameWidth: number = 0;
  private frameHeight: number = 0;
  private remoteDisplayWidth: number = 0;
  private remoteDisplayHeight: number = 0;
  private remoteDisplayOriginX: number = 0;
  private remoteDisplayOriginY: number = 0;
  private remoteDisplayScale: number = 1;
  private currentRemoteDisplay: number = 0;
  private peerPlatform: string = '';
  private lastFrameUpdatedAt: number = 0;
  private lastVideoRefreshRequestAt: number = 0;
  private sessionBecameActive: boolean = false;
  private sessionBecameActiveAt: number = 0;
  private sessionCloseRequestedLocally: boolean = false;
  private sessionExitScheduled: boolean = false;
  private pointerActive: boolean = false;
  private lastPointerRemoteX: number = 0;
  private lastPointerRemoteY: number = 0;
  private hasPointerPosition: boolean = false;
  private lastRefreshTraceAt: number = 0;
  private lastFramePullTraceAt: number = 0;
  private lastNativeFrameAdvanceAt: number = 0;
  private lastBridgeActivityAt: number = 0;
  private lastSilentSessionWarningAt: number = 0;
  private readonly silentSessionTimeoutMs: number = 5000;
  private readonly nativeFrameAdvanceMinIntervalMs: number = 48;
  private readonly renderPixelMapTimeoutMs: number = 260;
  private readonly zoomLevels: number[] = [1, 1.6, 2.4, 3.4];
  private readonly maxPinchScale: number = 6;
  private readonly longPressRightClickMs: number = 520;
  private readonly dragStartThresholdPx: number = 12;
  private longPressTimer: number = -1;
  private sessionExitTimer: number = -1;
  private reconnectWithPasswordTimer: number = -1;
  private chatScrollTimers: number[] = [];
  private i18nOpacityTimer: number = -1;
  private imeBlurTimer: number = -1;
  private bitrateDebounceTimer: number = -1;
  private fpsDebounceTimer: number = -1;
  private longPressTriggered: boolean = false;
  private touchDownAt: number = 0;
  private touchDownPreviewX: number = 0;
  private touchDownPreviewY: number = 0;
  private leftButtonActive: boolean = false;
  private axisScrollAccumulator: number = 0;
  private twoFingerScrollAccumulator: number = 0;
  private readonly AXIS_SCROLL_THRESHOLD: number = 1.0;
  private readonly SCROLL_THRESHOLD: number = 10;
  private readonly TWO_FINGER_SCROLL_THRESHOLD: number = 100;
  private readonly TOUCH_SCROLL_THRESHOLD: number = 100;
  private touchInteractionManager: TouchInteractionManager | null = null;
  @State showMarquee: boolean = false;
  @State marqueeRect: MarqueeRect = { left: 0, top: 0, right: 0, bottom: 0 };
  private gestureActive: boolean = false;
  private gestureStartDistance: number = 0;
  private gestureStartScale: number = 1;
  private gestureStartPanX: number = 0;
  private gestureStartPanY: number = 0;
  private gestureStartCenterX: number = 0;
  private gestureStartCenterY: number = 0;
  private lastGestureCenterX: number = 0;
  private lastGestureCenterY: number = 0;
  private bridgeListener = (event: OfficialSessionEvent): void => {
    if (this.sessionExitScheduled) {
      return;
    }
    if (this.shouldIgnoreBridgeEvent(event.kind)) {
      return;
    }
    this.captureBridgeEvent(event);
    if (event.kind === 'msgbox') {
      if (!this.sessionCloseRequestedLocally && !this.sessionExitScheduled &&
          this.isRetryableDisconnectText(event.detail) && this.shouldShowReconnectPromptNow(event.detail)) {
        console.warn(`[RemoteControl] msgbox with retryable disconnect: ${event.detail.substring(0, 100)}`);
        const msgValues = this.parseKeyValueDetail(event.detail);
        const autoRetry = (msgValues['retry'] ?? '').trim() === 'true';
        if (autoRetry && !this.isRetryingConnection) {
          console.info('[RemoteControl] auto-reconnecting due to retry=true');
          void this.retrySessionConnection(false);
          return;
        }
        this.showReconnectDialogFromState(this.lt('Connection Error'), event.detail);
        return;
      }
    }
    if (this.handleTerminalBridgeEvent(event)) {
      return;
    }
    this.maybeShowReconnectDialogForEvent(event);
    if (this.showReconnectDialog) {
      return;
    }
    if (event.kind === 'block-input-state') {
      this.blockInputOn = event.detail.includes('on=true');
    } else if (event.kind === 'privacy-mode-state') {
      this.privacyMode = event.detail.includes('on=true');
    }
    if (event.kind !== 'video-frame') {
      this.applyBridgeState(this.officialBridge.getCoreState());
    }
    if (event.kind === 'session-connected') {
      this.maybeRequestVideoRefresh(true);
    } else if ((event.kind === 'switch-display' || event.kind === 'current-display') &&
      !this.hasReceivedFrame) {
      this.maybeRequestVideoRefresh(true);
    }
    if (event.kind === 'video-frame' ||
      event.kind === 'peer-info' ||
      event.kind === 'connection-type' ||
      event.kind === 'session-connected' ||
      !this.hasReceivedFrame) {
      if (event.kind === 'video-frame' && !this.isConnected) {
        this.applyBridgeState(this.officialBridge.getCoreState());
      }
      void this.refreshRenderedFrame();
    }
  };
  private chatListener = (event: ChatEvent): void => {
    if (!this.showChatPanel) {
      return;
    }
    if (event.session && event.session.deviceId !== this.deviceId) {
      return;
    }
    if (event.type === 'message_received' || event.type === 'message_sent' || event.type === 'session_updated') {
      this.chatMessages = this.chatService.getMessages(this.deviceId);
      this.scheduleChatPanelScroll(50);
    }
  };

  @State deviceId: string = '';
  @State deviceName: string = '';
  @State statusText: string = I18nService.getInstance().translate('Connecting...');
  @State videoStatus: string = I18nService.getInstance().translate('Waiting for video...');
  @State isConnected: boolean = false;
  @State frameVersion: number = 0;
  @State showToolbar: boolean = false;
  @State toolbarX: number = -1;
  @State toolbarY: number = -1;
  @State toolbarSide: string = 'left';
  private toolbarDragStartX: number = 0;
  private toolbarDragStartY: number = 0;
  private toolbarTouchStartX: number = 0;
  private toolbarTouchStartY: number = 0;
  @State @Watch('onShowKeyboardChange') showKeyboard: boolean = false;
  @State imeProxyText: string = ' ';
  private imeProxyPrev: string = ' ';
  private imeProxyController: TextInputController = new TextInputController();
  @State imeProxyFocused: boolean = false;
  private imeProxyDismissRequested: boolean = false;
  @State hasReceivedFrame: boolean = false;
  @State sessionPassword: string = '';
  @State isSubmittingPassword: boolean = false;
  @State showOsPasswordDialog: boolean = false;
  @State osPassword: string = '';
  @State osAutoLogin: boolean = true;
  @State showReconnectDialog: boolean = false;
  @StorageLink('avoidKeyboardHeight') @Watch('onAvoidKeyboardHeightChange') avoidKeyboardHeight: number = 0;
  private systemKeyboardWasVisible: boolean = false;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @State remoteInputActive: boolean = false;
  @State reconnectDialogTitle: string = '';
  @State reconnectDialogText: string = '';
  @State reconnectDialogCanRelay: boolean = false;
  @State isRetryingConnection: boolean = false;
  @State previewWidth: number = 0;
  @State previewHeight: number = 0;
  @State viewRotation: number = 0;
  @State isLandscapeMode: boolean = false;
  private originalLandscapeMode: boolean = false;
  @State zoomLevelIndex: number = 0;
  @State pinchScale: number = 1;
  private lastPinchScale: number = 1;
  @State panOffsetX: number = 0;
  @State panOffsetY: number = 0;
  private preKeyboardPanOffsetY: number = 0;
  private panSpringTimer: number = -1;
  @State showConnectionInfo: boolean = false;
  @State connectionLatency: number = 0;
  @State connectionFps: number = 0;
  @State connectionRecvSpeed: string = '--';
  @State connectionSendSpeed: string = '--';
  @State connectionSpeedDisplay: string = '--';
  @State connectionType: string = '';
  @State connectionCodec: string = '';
  @State qualityMetricItems: QualityMetricItem[] = [];
  @State qualityDetailText: string = '';
  @State qualityUpdatedAtText: string = '';
  @State qualityRefreshTick: number = 0;
  private qualityRefreshTimer: number = -1;
  @State showDisplayMenu: boolean = false;
  @State displayMenuPopupId: string = '';
  @State showMoreMenu: boolean = false;
  @State showMouseModeMenu: boolean = false;
  @State showChatModeMenu: boolean = false;
  @State showChatPanel: boolean = false;
  @State chatDraft: string = '';
  @State chatMessages: ChatMessage[] = [];
  private chatPanelScroller: Scroller = new Scroller();
  @State chatPanelOffsetX: number = 0;
  @State chatPanelOffsetY: number = 0;
  private chatPanelDragStartX: number = 0;
  private chatPanelDragStartY: number = 0;
  private chatPanelDragStartOffsetX: number = 0;
  private chatPanelDragStartOffsetY: number = 0;
  @State chatPanelWidth: number = 144;
  @State chatPanelHeight: number = 187;
  private chatPanelResizeStartX: number = 0;
  private chatPanelResizeStartY: number = 0;
  private chatPanelResizeStartWidth: number = 0;
  private chatPanelResizeStartHeight: number = 0;
  @State blockInputOn: boolean = false;
  @State displayScaleMode: number = 1;
  @State customZoomPercent: number = 160;
  @State imageQualityMode: number = 1;
  @State videoCodecMode: number = 0;
  @State videoCodecCapabilities: Record<string, boolean> = {};
  @State customBitrate: number = 50;
  @State customFps: number = 60;
  @State showMoreBitrate: boolean = false;
  @State showCustomQualityPanel: boolean = false;
  @State keyboardMode: number = 0;
  @State keyboardMapSupported: boolean = false;
  @State keyboardTranslateSupported: boolean = false;
  @State sessionRecording: boolean = false;
  @State voiceCallActive: boolean = false;
  @State showRemoteCursor: boolean = true;
  @State showQualityMonitor: boolean = false;
  @State muteAudio: boolean = false;
  @State disableClipboard: boolean = false;
  @State lockAfterSession: boolean = false;
  @State reverseScroll: boolean = false;
  @State swapMouseButtons: boolean = false;
  @State viewMode: boolean = false;
  @State privacyMode: boolean = false;
  @State remotePeerFingerprint: string = '';
  @State mouseControlMode: number = 0;
  @State multiTouchFingers: number = 2;
  @State stickyCtrl: boolean = false;
  @State touchSettings: TouchSettings = DEFAULT_TOUCH_SETTINGS;
  @State touchPopupId: string = '';
  @State touchPopupRow: number = 0;
  @State touchPopupDurVal: number = 0;
  @State touchPopupSpdVal: number = 0;
  @State joystickActive: boolean = false;
  @State joystickKnobX: number = 0;
  @State joystickKnobY: number = 0;
  @State leftBtnActive: boolean = false;
  @State rightBtnActive: boolean = false;
  @State middleBtnActive: boolean = false;
  @State panBtnActive: boolean = false;
  @State joystickPanMode: boolean = false;
  private joystickTouchId: number = -1;
  @State cursorScreenX: number = 0;
  @State cursorScreenY: number = 0;
  private hasCursorScreenPosition: boolean = false;
  @State joystickSpeed: number = 5;
  @State mouseSensitivity: number = 8;
  @State mouseScrollSpeed: number = 3;
  @State cursorIconSize: number = 28;
  @State stickyAlt: boolean = false;
  @State stickyShift: boolean = false;
  @State stickyWin: boolean = false;
  @State stickyFn: boolean = false;
  @State activeKey: string = '';
  private fpsCalcLastTime: number = 0;
  private fpsCalcFrameCount: number = 0;
  private lastNonZeroFps: number = 0;
  private lastNonZeroFpsAt: number = 0;

  private remoteCursorAssets: Map<string, RemoteCursorAsset> = new Map();
  @State remoteCursorX: number = 0;
  @State remoteCursorY: number = 0;
  @State remoteCursorVisible: boolean = false;
  @State remoteCursorId: string = '';
  @State remoteCursorEmbedded: boolean = false;
  @State remoteCursorPixelMap: image.PixelMap | null = null;
  @State remoteCursorHotX: number = 0;
  @State remoteCursorHotY: number = 0;
  @State remoteCursorWidth: number = 0;
  @State remoteCursorHeight: number = 0;
  @State remoteCursorScale: number = 1.0;
  private remoteCursorPositionEventCount: number = 0;
  private remoteCursorDataEventCount: number = 0;
  private remoteCursorIdEventCount: number = 0;

  private shouldIgnoreBridgeEvent(kind: string): boolean {
    return kind === 'video-refresh-requested' ||
      kind === 'mouse-input' ||
      kind === 'keyboard-input';
  }

  private formatRemoteTitle(deviceId: string): string {
    return DeviceIdFormatter.formatRemoteLabel(deviceId);
  }

  private formatId(id: string): string {
    return DeviceIdFormatter.format(id);
  }

  private loadSessionMenuState(): void {
    this.showRemoteCursor = this.resolveToggleOption('show-remote-cursor');
    this.showQualityMonitor = this.resolveToggleOption('show-quality-monitor');
    this.muteAudio = this.resolveToggleOption('disable-audio');
    this.disableClipboard = this.resolveToggleOption('disable-clipboard');
    this.lockAfterSession = this.resolveToggleOption('lock-after-session-end');
    this.reverseScroll = this.resolveToggleOption('reverse-scroll');
    this.swapMouseButtons = this.resolveToggleOption('swap-left-right-mouse');
    this.viewMode = this.resolveToggleOption('view-only');
    this.privacyMode = this.resolveToggleOption('privacy-mode');
    const joystickSpeedValue = NativeRustDeskBridge.getLocalOption('joystick-speed');
    if (joystickSpeedValue) {
      const parsed = parseFloat(joystickSpeedValue);
      if (!isNaN(parsed) && parsed >= 0.1 && parsed <= 20) {
        this.joystickSpeed = parsed;
      }
    }
    const mouseSensValue = NativeRustDeskBridge.getLocalOption('mouse-sensitivity');
    if (mouseSensValue) {
      const parsed = parseInt(mouseSensValue, 10);
      if (!isNaN(parsed) && parsed >= 1 && parsed <= 20) {
        this.mouseSensitivity = parsed;
      }
    }
    const mouseScrollValue = NativeRustDeskBridge.getLocalOption('mouse-scroll-speed');
    if (mouseScrollValue) {
      const parsed = parseInt(mouseScrollValue, 10);
      if (!isNaN(parsed) && parsed >= 1 && parsed <= 10) {
        this.mouseScrollSpeed = parsed;
      }
    }
    const cursorIconSizeValue = NativeRustDeskBridge.getLocalOption('cursor-icon-size');
    if (cursorIconSizeValue) {
      const parsed = parseInt(cursorIconSizeValue, 10);
      if (!isNaN(parsed) && parsed >= 16 && parsed <= 64) {
        this.cursorIconSize = parsed;
      }
    }
    const remoteCursorScaleValue = NativeRustDeskBridge.getLocalOption('remote-cursor-scale');
    if (remoteCursorScaleValue) {
      const parsed = parseFloat(remoteCursorScaleValue);
      if (!isNaN(parsed) && parsed >= 0.5 && parsed <= 3.0) {
        this.remoteCursorScale = parsed;
      }
    }
    const toolbarSideValue = NativeRustDeskBridge.getLocalOption('toolbar-side');
    const toolbarYValue = NativeRustDeskBridge.getLocalOption('toolbar-y');
    if (toolbarYValue) {
      const parsed = parseInt(toolbarYValue, 10);
      if (!isNaN(parsed) && parsed >= 0) {
        this.toolbarY = parsed;
      }
    }
    if (toolbarSideValue === 'right') {
      this.toolbarSide = 'right';
    } else {
      this.toolbarSide = 'left';
    }
    this.touchSettings = this.loadTouchSettings();
    this.sessionRecording = NativeRustDeskBridge.sessionGetIsRecording();
    const qualityValue = NativeRustDeskBridge.getLocalOption('image-quality');
    if (qualityValue) {
      const qualityMap: Record<string, number> = { 'best': 0, 'balanced': 1, 'low': 2, 'speed': 2, 'custom': 3 };
      this.imageQualityMode = qualityMap[qualityValue] ?? 1;
      if (qualityValue === 'speed') {
        this.applySessionOption('image-quality', 'low');
      }
    }
    const displayScaleValue = NativeRustDeskBridge.getLocalOption('display-scale-mode').trim();
    const displayScaleMap: Record<string, number> = { 'original': 0, 'fit': 1, 'custom': 2 };
    this.displayScaleMode = displayScaleMap[displayScaleValue] ?? 1;
    const customZoomValue = Number(NativeRustDeskBridge.getLocalOption('custom-zoom-percent'));
    this.customZoomPercent = Number.isFinite(customZoomValue) && customZoomValue >= 100 && customZoomValue <= 600
      ? Math.round(customZoomValue)
      : 160;
    this.pinchScale = this.displayScaleMode === 2 ? this.customZoomPercent / 100 : 1;
    this.zoomLevelIndex = 0;
    const legacyCodecValue = NativeRustDeskBridge.getLocalOption('video-codec-preference').trim();
    const codecValue = NativeRustDeskBridge.getLocalOption('codec-preference').trim() || legacyCodecValue;
    if (codecValue) {
      const codecMap: Record<string, number> = { 'auto': 0, 'vp8': 1, 'vp9': 2, 'av1': 3, 'h264': 4, 'h265': 5 };
      this.videoCodecMode = codecMap[codecValue] ?? 0;
      if (legacyCodecValue.length > 0 && NativeRustDeskBridge.getLocalOption('codec-preference').trim().length === 0) {
        NativeRustDeskBridge.setLocalOption('codec-preference', codecValue);
      }
    }
    try {
      const codecCapabilities = JSON.parse(NativeRustDeskBridge.sessionGetAlternativeCodecs()) as Record<string, boolean>;
      this.videoCodecCapabilities = codecCapabilities;
    } catch (_error) {
      this.videoCodecCapabilities = {};
    }
    this.keyboardMapSupported = NativeRustDeskBridge.sessionIsKeyboardModeSupported('map');
    this.keyboardTranslateSupported = NativeRustDeskBridge.sessionIsKeyboardModeSupported('translate');
    const kbValue = NativeRustDeskBridge.sessionGetKeyboardMode().trim() || NativeRustDeskBridge.getLocalOption('keyboard-mode');
    if (kbValue) {
      const kbMap: Record<string, number> = { 'legacy': 0, 'map': 1, 'translate': 2 };
      this.keyboardMode = kbMap[kbValue] ?? 0;
    }
    const customBitrateValue = NativeRustDeskBridge.getLocalOption('custom-image-quality');
    if (customBitrateValue) {
      this.customBitrate = Number(customBitrateValue) || 50;
    }
    const customFpsValue = NativeRustDeskBridge.getLocalOption('custom-fps');
    if (customFpsValue) {
      this.customFps = Number(customFpsValue) || 30;
    }
  }

  private resolveToggleOption(key: string): boolean {
    const sessionValue = NativeRustDeskBridge.getSessionToggleOption(key);
    if (sessionValue) {
      return true;
    }
    const localValue = NativeRustDeskBridge.getLocalOption(key).trim().toUpperCase();
    return localValue === 'Y' || localValue === 'YES' || localValue === 'TRUE' || localValue === '1';
  }

  private loadTouchSettings(): TouchSettings {
    const s: TouchSettings = {
      tap: { duration: this.resolveNumberOption('touch-tap-ms', 300, 50, 1000), action: this.resolveTouchAction('touch-tap-action', TouchAction.LEFT_CLICK), speed: 1 },
      longPress: { duration: this.resolveNumberOption('touch-long-press-ms', 500, 200, 2000), action: this.resolveTouchAction('touch-long-press-action', TouchAction.RIGHT_CLICK), speed: 1 },
      swipe: { duration: this.resolveNumberOption('touch-swipe-ms', 300, 100, 2000), action: this.resolveTouchAction('touch-swipe-action', TouchAction.SCREEN_PAN), speed: this.resolveNumberOption('touch-swipe-speed', 5, 1, 20) },
      shortPressDrag: { duration: this.resolveNumberOption('touch-short-press-drag-ms', 400, 100, 2000), action: this.resolveTouchAction('touch-short-press-drag-action', TouchAction.SCREEN_SCROLL), speed: this.resolveNumberOption('touch-short-press-drag-speed', 5, 1, 20) },
      longPressDrag: { duration: this.resolveNumberOption('touch-long-press-drag-ms', 600, 200, 2000), action: this.resolveTouchAction('touch-long-press-drag-action', TouchAction.MARQUEE_SELECT), speed: this.resolveNumberOption('touch-long-press-drag-speed', 5, 1, 20) },
      twoFingerPinch: { duration: this.resolveNumberOption('touch-two-finger-pinch-ms', 100, 0, 1000), action: this.resolveTouchAction('touch-two-finger-pinch-action', TouchAction.ZOOM), speed: 1 },
      twoFingerPan: { duration: this.resolveNumberOption('touch-two-finger-pan-ms', 400, 200, 2000), action: this.resolveTouchAction('touch-two-finger-pan-action', TouchAction.SCREEN_PAN), speed: 1 },
    };
    return s;
  }

  private saveTouchSettings(): void {
    NativeRustDeskBridge.setLocalOption('touch-tap-ms', String(this.touchSettings.tap.duration));
    NativeRustDeskBridge.setLocalOption('touch-tap-action', this.touchSettings.tap.action);
    NativeRustDeskBridge.setLocalOption('touch-long-press-ms', String(this.touchSettings.longPress.duration));
    NativeRustDeskBridge.setLocalOption('touch-long-press-action', this.touchSettings.longPress.action);
    NativeRustDeskBridge.setLocalOption('touch-swipe-ms', String(this.touchSettings.swipe.duration));
    NativeRustDeskBridge.setLocalOption('touch-swipe-action', this.touchSettings.swipe.action);
    NativeRustDeskBridge.setLocalOption('touch-swipe-speed', String(this.touchSettings.swipe.speed));
    NativeRustDeskBridge.setLocalOption('touch-short-press-drag-ms', String(this.touchSettings.shortPressDrag.duration));
    NativeRustDeskBridge.setLocalOption('touch-short-press-drag-action', this.touchSettings.shortPressDrag.action);
    NativeRustDeskBridge.setLocalOption('touch-short-press-drag-speed', String(this.touchSettings.shortPressDrag.speed));
    NativeRustDeskBridge.setLocalOption('touch-long-press-drag-ms', String(this.touchSettings.longPressDrag.duration));
    NativeRustDeskBridge.setLocalOption('touch-long-press-drag-action', this.touchSettings.longPressDrag.action);
    NativeRustDeskBridge.setLocalOption('touch-long-press-drag-speed', String(this.touchSettings.longPressDrag.speed));
    NativeRustDeskBridge.setLocalOption('touch-two-finger-pinch-ms', String(this.touchSettings.twoFingerPinch.duration));
    NativeRustDeskBridge.setLocalOption('touch-two-finger-pinch-action', this.touchSettings.twoFingerPinch.action);
    NativeRustDeskBridge.setLocalOption('touch-two-finger-pan-ms', String(this.touchSettings.twoFingerPan.duration));
    NativeRustDeskBridge.setLocalOption('touch-two-finger-pan-action', this.touchSettings.twoFingerPan.action);
  }

  private resolveTouchAction(key: string, defaultValue: TouchAction): TouchAction {
    const raw = NativeRustDeskBridge.getLocalOption(key).trim();
    if (raw.length === 0) {
      return defaultValue;
    }
    return raw as TouchAction;
  }

  private resolveNumberOption(key: string, defaultValue: number, min: number, max: number): number {
    const raw = NativeRustDeskBridge.getLocalOption(key).trim();
    if (raw.length === 0) {
      return defaultValue;
    }
    const parsed = parseInt(raw, 10);
    if (isNaN(parsed)) {
      return defaultValue;
    }
    return Math.max(min, Math.min(max, parsed));
  }

  private async showToast(message: string): Promise<void> {
    try {
      await this.getUIContext().getPromptAction().openToast({ message });
    } catch (error) {
      console.error('RemoteControl toast failed', JSON.stringify(error));
    }
  }

  private openSessionChatPanel(): void {
    this.showDisplayMenu = false;
    this.showMouseModeMenu = false;
    this.showMoreMenu = false;
    this.showChatModeMenu = false;
    this.chatPanelWidth = this.resolveDefaultChatPanelWidth();
    this.chatPanelHeight = this.resolveDefaultChatPanelHeight();
    this.showChatPanel = true;
    this.chatDraft = '';
    const viewportWidth = this.previewWidth > 0 ? this.previewWidth : 360;
    this.chatPanelOffsetX = Math.max(8, (viewportWidth - this.chatPanelWidth) / 2);
    this.chatPanelOffsetY = 60;
    this.chatMessages = this.chatService.getMessages(this.deviceId);
    this.chatService.updateSessionDeviceName(this.deviceId, this.deviceName);
    this.scheduleChatPanelScroll(100);
  }

  private async sendSessionChatMessage(): Promise<void> {
    const text = this.chatDraft.trim();
    if (text.length === 0) {
      return;
    }
    this.chatDraft = '';
    try {
      await this.chatService.sendTextMessage(this.deviceId, text);
      this.chatMessages = this.chatService.getMessages(this.deviceId);
      this.scheduleChatPanelScroll(50);
    } catch (_error) {
      this.chatDraft = text;
      void this.showToast(this.lt('Chat send failed'));
    }
  }

  private resolveDefaultChatPanelWidth(): number {
    return 144;
  }

  private resolveDefaultChatPanelHeight(): number {
    return 187;
  }

  private openVoiceChatMode(): void {
    this.showChatModeMenu = false;
    this.showChatPanel = false;
    if (this.voiceCallActive) {
      const handled = NativeRustDeskBridge.sessionCloseVoiceCall();
      if (handled) {
        this.voiceCallActive = false;
      }
      void this.showToast(handled ? this.lt('Voice call closed') : this.lt('In development'));
      return;
    }
    const handled = NativeRustDeskBridge.sessionRequestVoiceCall();
    if (handled) {
      this.voiceCallActive = true;
    }
    void this.showToast(handled ? this.lt('Voice call requested') : this.lt('In development'));
  }

  private scheduleChatPanelScroll(delayMs: number): void {
    [0, delayMs, delayMs + 80, delayMs + 180].forEach((delay: number) => {
      const timerId = setTimeout(() => {
        this.chatScrollTimers = this.chatScrollTimers.filter((id: number) => id !== timerId);
        this.chatPanelScroller.scrollEdge(Edge.Bottom);
      }, Math.max(0, delay));
      this.chatScrollTimers.push(timerId);
    });
  }

  private getChatMessageBody(message: ChatMessage): string {
    if (message.type === ChatMessageType.FILE) {
      const size = message.fileSize ? ChatService.formatFileSize(message.fileSize) : '';
      return `${message.fileName ?? this.lt('Attachment')} ${size}`.trim();
    }
    return message.content;
  }

  aboutToAppear() {
    const params = this.getRouteParams();
    Logger.info('RC', `aboutToAppear deviceId=${params?.deviceId ?? 'null'} verboseLog=${Logger.isDebugEnabled()}`);
    if (params !== null && params.deviceId !== undefined) {
      this.deviceId = params.deviceId;
      this.deviceName = this.formatRemoteTitle(params.deviceId);
      this.chatService.retainOnlyPeer(params.deviceId);
    }
    this.disposeRenderedFrame();
    this.settings = this.appData.getSettings();
    this.originalLandscapeMode = this.isLandscapeMode;
    this.sessionBecameActive = false;
    this.sessionBecameActiveAt = 0;
    this.sessionCloseRequestedLocally = false;
    this.sessionExitScheduled = false;
    this.isRetryingConnection = false;
    this.lastFrameId = 0;
    this.lastFrameUpdatedAt = 0;
    this.lastVideoRefreshRequestAt = 0;
    this.lastFramePullTraceAt = 0;
    this.lastNativeFrameAdvanceAt = 0;
    this.lastBridgeActivityAt = 0;
    this.lastSilentSessionWarningAt = 0;
    this.frameVersion = 0;
    this.hasReceivedFrame = false;
    this.imeProxyText = ' ';
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.remoteDisplayWidth = 0;
    this.remoteDisplayHeight = 0;
    this.remoteDisplayOriginX = 0;
    this.remoteDisplayOriginY = 0;
    this.remoteDisplayScale = 1;
    this.currentRemoteDisplay = 0;
    this.connectionLatency = 0;
    this.connectionFps = 0;
    this.connectionRecvSpeed = '--';
    this.connectionSendSpeed = '--';
    this.connectionSpeedDisplay = '--';
    this.connectionType = '';
    this.connectionCodec = '';
    this.clearConnectionQualityState();
    this.fpsCalcLastTime = 0;
    this.fpsCalcFrameCount = 0;
    this.lastNonZeroFps = 0;
    this.lastNonZeroFpsAt = 0;
    this.touchDownAt = 0;
    this.touchDownPreviewX = 0;
    this.touchDownPreviewY = 0;
    this.leftButtonActive = false;
    this.longPressTriggered = false;
    this.gestureActive = false;
    this.initTouchInteractionManager();
    this.gestureStartDistance = 0;
    this.gestureStartScale = this.pinchScale;
    this.gestureStartPanX = this.panOffsetX;
    this.gestureStartPanY = this.panOffsetY;
    this.gestureStartCenterX = 0;
    this.gestureStartCenterY = 0;
    this.lastGestureCenterX = 0;
    this.lastGestureCenterY = 0;
    this.remotePeerFingerprint = '';
    this.loadSessionMenuState();
    if (this.showQualityMonitor) {
      this.setConnectionInfoVisible(true);
    }
    this.clearLongPressTimer();
    this.officialBridge.addEventListener(this.bridgeListener);
    this.chatService.addEventListener(this.chatListener);
    this.officialBridge.resetCloseRequestedFlag();
    void this.syncBridgeState();
    this.startBridgeRefresh();
    this.startFrameRefresh();
    WindowChromeService.getInstance().enterImmersiveMode();
    if (this.settings.keepScreenOn === 'session' || this.settings.keepScreenOn === 'service') {
      void WindowChromeService.getInstance().setKeepScreenOn(true);
    }
    this.initAudioPlayback();
    this.startAudioFrameRefresh();
    if (!this.disableClipboard) {
      void ClipboardService.getInstance().startMonitoring();
    }
  }

  aboutToDisappear() {
    this.officialBridge.removeEventListener(this.bridgeListener);
    this.chatService.removeEventListener(this.chatListener);
    this.stopBridgeRefresh();
    this.stopFrameRefresh();
    this.stopConnectionInfoRefresh();
    this.disposeRenderedFrame();
    this.clearLongPressTimer();
    this.stopPanSpringBack();
    if (this.sessionExitTimer !== -1) {
      clearTimeout(this.sessionExitTimer);
      this.sessionExitTimer = -1;
    }
    if (this.reconnectWithPasswordTimer !== -1) {
      clearTimeout(this.reconnectWithPasswordTimer);
      this.reconnectWithPasswordTimer = -1;
    }
    this.chatScrollTimers.forEach((id: number) => clearTimeout(id));
    this.chatScrollTimers = [];
    if (this.i18nOpacityTimer !== -1) { clearTimeout(this.i18nOpacityTimer); this.i18nOpacityTimer = -1; }
    if (this.imeBlurTimer !== -1) { clearTimeout(this.imeBlurTimer); this.imeBlurTimer = -1; }
    if (this.bitrateDebounceTimer !== -1) { clearTimeout(this.bitrateDebounceTimer); this.bitrateDebounceTimer = -1; }
    if (this.fpsDebounceTimer !== -1) { clearTimeout(this.fpsDebounceTimer); this.fpsDebounceTimer = -1; }
    ClipboardService.getInstance().stopMonitoring();
    WindowChromeService.getInstance().exitImmersiveMode();
    void WindowChromeService.getInstance().setKeepScreenOn(false);
    this.stopAudioFrameRefresh();
    this.cleanupAudioResources();
  }
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_MENU_BG') theme_MENU_BG: string = '#D01E232F';
  @StorageProp('theme_CARET_HIDDEN') theme_CARET_HIDDEN: string = '#00000000';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_DIALOG_OVERLAY') theme_DIALOG_OVERLAY: string = '#80000000';
  @StorageProp('theme_DISABLED_TEXT') theme_DISABLED_TEXT: string = '#AAAAAA';
  @StorageProp('theme_ERROR_BG') theme_ERROR_BG: string = '#3B1D24';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_HEADER_BG') theme_HEADER_BG: string = '#171A22';
  @StorageProp('theme_ICON_BG') theme_ICON_BG: string = '#1FFFFFFF';
  @StorageProp('theme_ICON_FILL') theme_ICON_FILL: string = '#FFFFFF';
  @StorageProp('theme_INACTIVE_BG') theme_INACTIVE_BG: string = '#3A4355';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_INFO_BG') theme_INFO_BG: string = '#1E335A';
  @StorageProp('theme_INFO_TEXT') theme_INFO_TEXT: string = '#B7D3FF';
  @StorageProp('theme_OVERLAY_FULL') theme_OVERLAY_FULL: string = '#E6000000';
  @StorageProp('theme_OVERLAY_SEMI') theme_OVERLAY_SEMI: string = '#CC1F1F1F';
  @StorageProp('theme_PANEL_BG') theme_PANEL_BG: string = '#1F1F1F';
  @StorageProp('theme_SHADOW_COLOR') theme_SHADOW_COLOR: string = '#00000033';
  @StorageProp('theme_SUCCESS_BG') theme_SUCCESS_BG: string = '#153B2E';
  @StorageProp('theme_SUCCESS_TEXT') theme_SUCCESS_TEXT: string = '#7DD3A7';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('theme_TOOLBAR_BG') theme_TOOLBAR_BG: string = '#2A2A2A';
  @StorageProp('theme_WHITE') theme_WHITE: string = '#FFFFFF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @State i18nOpacity: number = 1;

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nOpacity = 0;
    this.i18nVersion = this.i18nRefresh;
    this.statusText = this.lt('Connecting...');
    this.videoStatus = this.lt('Waiting for video...');
    this.i18nOpacityTimer = setTimeout(() => { this.i18nOpacity = 1; }, 30);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Stack({ alignContent: Alignment.Bottom }) {
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              if (this.frameVersion > 0 && this.hasRenderedFrame()) {
                Stack({ alignContent: Alignment.TopStart }) {
                  Image(this.renderedFrame as image.PixelMap)
                    .width(this.resolveRenderedImageWidth())
                    .height(this.resolveRenderedImageHeight())

                  if (this.shouldRenderRemoteCursor()) {
                    RemoteCursor({
                      cursorX: this.remoteCursorX,
                      cursorY: this.remoteCursorY,
                      cursorVisible: this.remoteCursorVisible,
                      cursorId: this.remoteCursorId,
                      cursorImage: this.remoteCursorPixelMap,
                      cursorHotX: this.remoteCursorHotX,
                      cursorHotY: this.remoteCursorHotY,
                      cursorImageWidth: this.remoteCursorWidth,
                      cursorImageHeight: this.remoteCursorHeight,
                      previewWidth: this.resolveRenderedImageWidth(),
                      previewHeight: this.resolveRenderedImageHeight(),
                      displayOriginX: this.remoteDisplayOriginX,
                      displayOriginY: this.remoteDisplayOriginY,
                      remoteWidth: this.resolveInteractiveWidth(),
                      remoteHeight: this.resolveInteractiveHeight(),
                      cursorScale: this.remoteCursorScale
                    });
                  }
                }
                .width(this.resolveRenderedImageWidth())
                .height(this.resolveRenderedImageHeight())
                .rotate({ angle: this.viewRotation })
                .translate({ x: this.panOffsetX, y: this.panOffsetY });
              } else {
                Column({ space: 16 }) {
                  Image($rawfile('display.svg'))
                    .width(64)
                    .height(64)
                    .fillColor(this.theme_TEXT_TERTIARY);
                  Text(this.videoStatus)
                    .fontSize(16)
                    .fontColor(this.theme_TEXT_SECONDARY)
                    .textAlign(TextAlign.Center);
                  LoadingProgress()
                    .width(48)
                    .height(48)
                    .color(this.theme_ACCENT);
                }
                .padding({ left: 24, right: 24 });
              }

              Stack() {
                Column() {}
                  .width('100%')
                  .height('100%')
                  .onTouch((event: TouchEvent) => {
                    this.handlePreviewTouch(event);
                  })
                  .onMouse((event: MouseEvent) => {
                    this.handlePreviewMouse(event);
                  })
                  .onHover((isHover: boolean) => {
                    this.handlePreviewHover(isHover);
                  })
                  .onAxisEvent((event: AxisEvent) => {
                    this.handlePreviewAxis(event);
                  });

                if (this.showMarquee) {
                  Rect()
                    .width(Math.abs(this.marqueeRect.right - this.marqueeRect.left))
                    .height(Math.abs(this.marqueeRect.bottom - this.marqueeRect.top))
                    .position({
                      x: Math.min(this.marqueeRect.left, this.marqueeRect.right),
                      y: Math.min(this.marqueeRect.top, this.marqueeRect.bottom)
                    })
                    .fill('rgba(76, 139, 245, 0.15)')
                    .stroke('rgba(76, 139, 245, 0.8)')
                    .strokeWidth(1)
                    .strokeDashArray([5, 5]);
                }

                if (this.mouseControlMode === 1 && this.isConnected) {
                  this.buildVirtualMouseOverlay();
                }
              }
              .width('100%')
              .height('100%');
            }
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(this.theme_GRAY_BG)
            .animation({ duration: 300, curve: Curve.EaseInOut })
            .onAreaChange((_oldValue, newValue) => {
              const nextWidth = Number(newValue.width);
              const nextHeight = Number(newValue.height);
              this.previewWidth = nextWidth > 0 ? nextWidth : 0;
              this.previewHeight = nextHeight > 0 ? nextHeight : 0;
              if (this.toolbarX < 0 && this.previewWidth > 0) {
                this.toolbarX = this.toolbarSide === 'right' ? this.previewWidth - 68 : 8;
              }
              if (!this.hasCursorScreenPosition && this.previewWidth > 0 && this.previewHeight > 0) {
                const bounds = this.getCursorClampBounds();
                this.cursorScreenX = bounds[0] + bounds[2] / 2;
                this.cursorScreenY = bounds[1] + bounds[3] / 2;
                this.hasCursorScreenPosition = true;
                const mapped = this.mapTouchToRemote(this.cursorScreenX, this.cursorScreenY, true);
                if (mapped !== null) {
                  this.lastPointerRemoteX = mapped.x;
                  this.lastPointerRemoteY = mapped.y;
                  this.hasPointerPosition = true;
                }
              }
              this.applySuggestedViewTransform(true);
            })
            .parallelGesture(
              GestureGroup(GestureMode.Parallel,
                TapGesture({ count: 1 })
                  .onAction(() => {}),
                PinchGesture()
                  .onActionStart(() => {
                    this.lastPinchScale = this.pinchScale;
                  })
                  .onActionUpdate((event: PinchGestureEvent) => {
                     const newScale = this.lastPinchScale * event.scale;
                     this.displayScaleMode = 2;
                     this.pinchScale = Math.max(1, Math.min(this.maxPinchScale, newScale));
                   })
                  .onActionEnd(() => {
                    this.lastPinchScale = this.pinchScale;
                    this.customZoomPercent = Math.max(100, Math.min(600, Math.round(this.pinchScale * 100)));
                    NativeRustDeskBridge.setLocalOption('display-scale-mode', 'custom');
                    NativeRustDeskBridge.setLocalOption('custom-zoom-percent', String(this.customZoomPercent));
                  })
              )
            );

            if (this.shouldShowPasswordAssist()) {
              this.buildPasswordAssist();
            }
          }
          .width('100%')
          .layoutWeight(1);

          this.buildFloatingToolbar();
        }
        .width('100%')
        .layoutWeight(1);
      }

      if (this.showConnectionInfo) {
        this.buildConnectionInfoPanel();
      }

      if (this.showKeyboard) {
        Column() {
          this.buildKeyboardPanel();
        }
        .width('100%')
        .margin({ top: 4 })
        .hitTestBehavior(HitTestMode.Block)
        .zIndex(100)
      }

      if (this.showDisplayMenu) {
        Column() {
          Blank()
          Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              this.buildDisplayMenuPanel();
            }
            .width('100%')

            if (this.displayMenuPopupId.length > 0) {
              Column() {
                Blank()
                Column() {
                  this.buildDisplaySelectPopup();
                }
                Blank()
              }
              .width('100%')
              .height('100%')
              .zIndex(120)
              .onClick(() => { this.displayMenuPopupId = ''; });
            }
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 56 + this.avoidNavigationBarHeight })
        .zIndex(110)
        .onClick(() => {
          this.showDisplayMenu = false;
          this.displayMenuPopupId = '';
        })
      }

      if (this.showMouseModeMenu) {
        Column() {
          Blank()
          Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              this.buildMouseModeMenuPanel();
            }
            .width('100%')

            if (this.touchPopupId.length > 0) {
              Column() {
                this.buildTouchPopup();
              }
              .width('100%')
              .margin({ bottom: 100 + (6 - this.touchPopupRow) * 36 })
              .zIndex(120)
              .onClick(() => {});
            }
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 56 + this.avoidNavigationBarHeight })
        .zIndex(110)
        .onClick(() => {
          if (this.touchPopupId.length > 0) {
            this.touchPopupId = '';
          } else {
            this.showMouseModeMenu = false;
          }
        })
      }

      if (this.showChatModeMenu) {
        Column() {
          Blank()
          Column() {
            this.buildChatModeMenuPanel();
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 56 + this.avoidNavigationBarHeight })
        .zIndex(110)
        .onClick(() => {
          this.showChatModeMenu = false;
        })
      }

      if (this.showMoreMenu) {
        Column() {
          Blank()
          Column() {
            this.buildMoreMenuPanel();
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 56 + this.avoidNavigationBarHeight })
        .zIndex(110)
        .onClick(() => {
          this.showMoreMenu = false;
        })
      }

      if (this.showChatPanel) {
        this.buildFloatingChatPanel();
      }

      if (this.showOsPasswordDialog) {
        this.buildOsPasswordDialog();
      }

      if (this.showReconnectDialog) {
        this.buildReconnectDialog();
      }

      if (!this.showOsPasswordDialog) {
        this.buildImeProxyInput();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
    .opacity(this.i18nOpacity)

    .onKeyEvent((event: KeyEvent) => {
      this.handleKeyEvent(event);
    });
  }

  @Builder
  private buildTopBar() {
    Row() {
      Image($rawfile('close.svg'))
        .width(24)
        .height(24)
        .fillColor(this.theme_TEXT_PRIMARY)
        .onClick(() => {
          this.closeSession();
        });

      Row({ space: 8 }) {
        Text(`${this.lt('Remote ID')} ${this.formatId(this.deviceId)}`)
          .fontSize(15)
          .fontColor(this.theme_CONTRAST_TEXT)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);

        this.buildSessionStatusTag();
      }
      .layoutWeight(1);

      Row({ space: 10 }) {
        Image($rawfile('display.svg'))
          .width(24)
          .height(24)
          .fillColor(this.theme_ICON_FILL)
          .onClick(() => {
            this.setConnectionInfoVisible(!this.showConnectionInfo);
          });
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 8 })
    .backgroundColor(this.theme_OVERLAY_SEMI);
  }

  @Builder
  private buildFloatingToolbar() {
    if (this.showToolbar) {
      Row({ space: 2 }) {
        Column() {
          Image($rawfile('nav-arrow-right.svg'))
            .width(20).height(20)
            .colorFilter(createStrokeIconColorFilter(this.theme_ICON_FILL));
        }
        .width(32).height(48)
        .justifyContent(FlexAlign.Center)
        .onTouch((event: TouchEvent) => { this.handleToolbarDrag(event); });

        this.buildToolBtnSvg($rawfile('close.svg'), () => { this.closeSession(); });
        this.buildToolBtnSvg($rawfile('display.svg'), () => { this.showDisplayMenu = !this.showDisplayMenu; this.showMouseModeMenu = false; }, this.showDisplayMenu);
        this.buildToolBtnSvg($rawfile('keyboard_mouse.svg'), () => {
          if (this.showKeyboard || this.imeProxyFocused) {
            this.showKeyboard = false; this.imeProxyFocused = false; this.imeProxyDismissRequested = true;
            try { this.getUIContext().getFocusController().clearFocus(); } catch (e) { console.warn('clearFocus failed: ' + JSON.stringify(e)); }
          } else {
            this.preKeyboardPanOffsetY = this.panOffsetY; this.showKeyboard = true; this.openSystemKeyboardFromCustomPanel();
          }
          this.showDisplayMenu = false; this.showMouseModeMenu = false;
        }, this.showKeyboard);
        this.buildToolBtnStroke($rawfile('actions.svg'), () => { this.showMouseModeMenu = !this.showMouseModeMenu; this.showDisplayMenu = false; }, this.showMouseModeMenu);
        this.buildToolBtnSvg($rawfile('chat.svg'), () => { this.showChatModeMenu = !this.showChatModeMenu; this.showDisplayMenu = false; this.showMouseModeMenu = false; }, this.showChatPanel || this.showChatModeMenu);
        this.buildToolBtnSvg($rawfile('dots_vertical.svg'), () => { this.showMoreMenu = !this.showMoreMenu; this.showDisplayMenu = false; this.showMouseModeMenu = false; }, this.showMoreMenu);

        Column() {
          Image($rawfile('nav-arrow-left.svg'))
            .width(20).height(20)
            .colorFilter(createStrokeIconColorFilter(this.theme_ICON_FILL));
        }
        .width(32).height(48)
        .justifyContent(FlexAlign.Center)
        .onTouch((event: TouchEvent) => { this.handleToolbarDrag(event); });
      }
      .height(56)
      .padding({ left: 4, right: 4 })
      .backgroundColor('#CC222222')
      .borderRadius(28)
      .position({ x: this.toolbarSide === 'right' && this.previewWidth > 0 ? Math.max(8, this.previewWidth - 8 - 348) : 8, y: this.toolbarY < 0 ? this.previewHeight - 70 : Math.max(0, Math.min(this.previewHeight - 60, this.toolbarY)) })
      .zIndex(100);
    } else {
      Row() {
        Image($rawfile('nav-arrow-left.svg'))
          .width(20).height(20)
          .colorFilter(createStrokeIconColorFilter(this.theme_ICON_FILL));
        Image($rawfile('nav-arrow-right.svg'))
          .width(20).height(20)
          .colorFilter(createStrokeIconColorFilter(this.theme_ICON_FILL));
      }
      .width(60).height(48)
      .justifyContent(FlexAlign.SpaceEvenly)
      .backgroundColor('#CC222222')
      .borderRadius(24)
      .position({ x: this.toolbarX < 0 ? 8 : Math.max(0, Math.min(this.previewWidth - 68, this.toolbarX)), y: this.toolbarY < 0 ? this.previewHeight - 70 : Math.max(0, Math.min(this.previewHeight - 60, this.toolbarY)) })
      .zIndex(100)
      .onTouch((event: TouchEvent) => { this.handleToolbarDrag(event); });
    }
  }

  private handleToolbarDrag(event: TouchEvent): void {
    const touch = event.touches && event.touches.length > 0 ? event.touches[0] : undefined;
    if (touch === undefined) {
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.snapToolbarToEdge();
      }
      return;
    }
    if (event.type === TouchType.Down) {
      this.toolbarDragStartX = touch.x;
      this.toolbarDragStartY = touch.y;
      this.toolbarTouchStartX = touch.x;
      this.toolbarTouchStartY = touch.y;
    } else if (event.type === TouchType.Move) {
      const dx = touch.x - this.toolbarDragStartX;
      const dy = touch.y - this.toolbarDragStartY;
      if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
        const curX = this.toolbarX < 0 ? 8 : this.toolbarX;
        const curY = this.toolbarY < 0 ? this.previewHeight - 70 : this.toolbarY;
        this.toolbarX = Math.max(0, curX + dx);
        this.toolbarY = Math.max(0, Math.min(this.previewHeight - 50, curY + dy));
        this.toolbarDragStartX = touch.x;
        this.toolbarDragStartY = touch.y;
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const totalDx = Math.abs(touch.x - this.toolbarTouchStartX);
      const totalDy = Math.abs(touch.y - this.toolbarTouchStartY);
      if (totalDx < 5 && totalDy < 5) {
        this.showToolbar = !this.showToolbar;
        this.snapToolbarToEdge();
      } else {
        this.snapToolbarToEdge();
      }
    }
  }

  private snapToolbarToEdge(): void {
    if (this.previewWidth <= 0) return;
    const isRight = this.toolbarX >= 0 && this.toolbarX >= this.previewWidth / 2;
    this.toolbarSide = isRight ? 'right' : 'left';
    if (isRight) {
      this.toolbarX = Math.max(8, this.previewWidth - 68);
      NativeRustDeskBridge.setLocalOption('toolbar-side', 'right');
    } else {
      this.toolbarX = 8;
      NativeRustDeskBridge.setLocalOption('toolbar-side', 'left');
    }
    const clampedY = Math.max(0, Math.min(this.previewHeight - 60, this.toolbarY < 0 ? this.previewHeight - 70 : this.toolbarY));
    this.toolbarY = clampedY;
    NativeRustDeskBridge.setLocalOption('toolbar-y', String(Math.round(clampedY)));
  }

  @Builder
  private buildBottomToolbar() {
    Row({ space: 0 }) {
      this.buildToolBtnSvg($rawfile('close.svg'), () => {
        this.closeSession();
      });

      this.buildToolBtnSvg($rawfile('display.svg'), () => {
        const wasOpen = this.showDisplayMenu;
        this.showDisplayMenu = !wasOpen;
        this.showMouseModeMenu = false;
        this.showChatModeMenu = false;
        this.showMoreMenu = false;
      }, this.showDisplayMenu);

      this.buildToolBtnSvg($rawfile('keyboard_mouse.svg'), () => {
        if (this.showKeyboard || this.imeProxyFocused) {
          this.showKeyboard = false;
          this.imeProxyFocused = false;
          this.imeProxyDismissRequested = true;
          try {
            const focusController = this.getUIContext().getFocusController();
            focusController.clearFocus();
          } catch (e) { console.warn('clearFocus failed: ' + JSON.stringify(e)); }
        } else {
          this.preKeyboardPanOffsetY = this.panOffsetY;
          this.showKeyboard = true;
          this.openSystemKeyboardFromCustomPanel();
        }
        this.showDisplayMenu = false;
        this.showMouseModeMenu = false;
        this.showChatModeMenu = false;
        this.showMoreMenu = false;
      }, this.showKeyboard);

      this.buildToolBtnStroke($rawfile('actions.svg'), () => {
        const wasOpen = this.showMouseModeMenu;
        this.showMouseModeMenu = !wasOpen;
        this.showDisplayMenu = false;
        this.showChatModeMenu = false;
        this.showMoreMenu = false;
      }, this.showMouseModeMenu);

      this.buildToolBtnSvg($rawfile('chat.svg'), () => {
        const wasOpen = this.showChatModeMenu;
        this.showChatModeMenu = !wasOpen;
        this.showDisplayMenu = false;
        this.showMouseModeMenu = false;
        this.showMoreMenu = false;
      }, this.showChatPanel || this.showChatModeMenu);

      this.buildToolBtnSvg($rawfile('dots_vertical.svg'), () => {
        const wasOpen = this.showMoreMenu;
        this.showMoreMenu = !wasOpen;
        this.showDisplayMenu = false;
        this.showMouseModeMenu = false;
        this.showChatModeMenu = false;
      }, this.showMoreMenu);

      Blank().layoutWeight(1);

      Image($rawfile('arrow-back-ios.svg'))
        .width(20)
        .height(20)
        .fillColor(this.theme_ICON_FILL)
        .onClick(() => {
          this.showToolbar = false;
        });
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 8 })
    .backgroundColor('#B3222222')
    .margin({ bottom: this.avoidNavigationBarHeight })
  }

  @Builder
  private buildToolBtnSvg(icon: Resource, action: () => void, selected: boolean = false) {
    Row() {
      Image(icon)
        .width(30)
        .height(30)
        .fillColor(selected ? this.theme_ACCENT : this.theme_ICON_FILL)
        .objectFit(ImageFit.Contain);
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(selected ? '#33FFFFFF' : this.theme_ICON_BG)
    .borderRadius(22)
    .onClick(action);
  }

  @Builder
  private buildToolBtnStroke(icon: Resource, action: () => void, selected: boolean = false) {
    Row() {
      Image(icon)
        .width(30)
        .height(30)
        .colorFilter(createStrokeIconColorFilter(selected ? this.theme_ACCENT : this.theme_ICON_FILL))
        .objectFit(ImageFit.Contain);
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(selected ? '#33FFFFFF' : this.theme_ICON_BG)
    .borderRadius(22)
    .onClick(action);
  }

  @Builder
  private buildToolbarExpandHandle() {
    Row() {
      Row() {
        Image($rawfile('arrow-forward-ios.svg'))
          .width(18)
          .height(18)
          .fillColor(this.theme_ICON_FILL)
          .onClick(() => {
            this.showToolbar = true;
          });
      }
      .width(28)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.theme_OVERLAY_SEMI)
      .borderRadius({ topRight: 14, bottomRight: 14 });

      Blank().layoutWeight(1).hitTestBehavior(HitTestMode.Transparent);
    }
    .width('100%')
    .padding({ left: 0, right: 12, bottom: this.avoidNavigationBarHeight })
  }

  private toggleRotation(): void {
    this.isLandscapeMode = !this.isLandscapeMode;
    this.panOffsetX = 0;
    this.panOffsetY = 0;
    WindowChromeService.getInstance().setLandscape(this.isLandscapeMode);
    this.toolbarX = -1;
    this.toolbarY = -1;
  }

  private toggleZoomLevel(): void {
    if (this.zoomLevels.length === 0) {
      return;
    }
    this.zoomLevelIndex = (this.zoomLevelIndex + 1) % this.zoomLevels.length;
  }

  @Builder
  private buildConnectionInfoPanel() {
    Column() {
      Scroll() {
        Column({ space: 8 }) {
          this.buildConnectionInfoRow(this.lt('Resolution'), this.resolveConnectionResolutionText(), this.theme_CONTRAST_TEXT)
          this.buildConnectionInfoRow(this.lt('FPS'), this.connectionFps > 0 ? `${this.connectionFps}` : '--', this.theme_CONTRAST_TEXT)
          this.buildConnectionInfoRow(this.lt('Latency'), this.connectionLatency > 0 ? `${this.connectionLatency} ms` : '--', this.getLatencyColor())
          this.buildConnectionInfoRow(this.lt('Speed'), this.connectionSpeedDisplay, this.theme_CONTRAST_TEXT)
          this.buildConnectionInfoRow(this.lt('Connection'), this.connectionType.length > 0 ? this.connectionType : '--', this.theme_CONTRAST_TEXT)
          this.buildConnectionInfoRow(this.lt('Zoom'), `${Math.round(this.getCurrentZoom() * 100)}%`, this.theme_CONTRAST_TEXT)
          this.buildConnectionInfoRow(this.lt('Codec'), this.connectionCodec.length > 0 ? this.connectionCodec : '--', this.theme_CONTRAST_TEXT)
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(170)
    }
    .width(150)
    .padding({ left: 6, right: 6, top: 6, bottom: 6 })
    .backgroundColor(Color.Transparent)
    .borderRadius(8)
    .position({ x: '100%', y: 60 })
    .translate({ x: -156 })
  }

  private resolveConnectionResolutionText(): string {
    this.qualityRefreshTick;
    return this.frameWidth > 0 && this.frameHeight > 0 ? `${this.frameWidth}×${this.frameHeight}` : '--';
  }

  @Builder
  private buildConnectionInfoRow(label: string, value: string, valueColor: string) {
    Row() {
      Text(label)
        .fontSize(10)
        .fontColor(this.theme_DISABLED_TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(32);
      Text(value.length > 0 ? value : '--')
        .fontSize(10)
        .fontColor(valueColor)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1);
    }
    .width('100%');
  }

  @Builder
  private buildSessionStatusTag() {
    Text(this.resolveSessionBadgePalette().text)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.resolveSessionBadgePalette().fontColor)
      .backgroundColor(this.resolveSessionBadgePalette().backgroundColor)
      .borderRadius(10)
      .padding({ left: 8, right: 8, top: 2, bottom: 2 });
  }

  private resolveSessionBadgePalette(): SessionBadgePalette {
    if (this.sessionExitScheduled || this.sessionCloseRequestedLocally) {
      return {
        text: this.lt('Disconnected'),
        backgroundColor: this.theme_ERROR_BG,
        fontColor: this.theme_ERROR_TEXT
      };
    }
    if (this.isConnected || this.hasReceivedFrame) {
      return {
        text: this.lt('Connected'),
        backgroundColor: this.theme_SUCCESS_BG,
        fontColor: this.theme_SUCCESS_TEXT
      };
    }
    return {
      text: this.lt('Connecting...'),
      backgroundColor: this.theme_INFO_BG,
      fontColor: this.theme_INFO_TEXT
    };
  }

  private requestSystemKeyboard(): void {
    this.showToolbar = true;
    this.imeProxyDismissRequested = false;
    if (this.imeBlurTimer !== -1) {
      clearTimeout(this.imeBlurTimer);
      this.imeBlurTimer = -1;
    }
    try {
      const focusController = this.getUIContext().getFocusController();
      focusController.requestFocus('remote-ime-proxy-input');
    } catch (error) {
      console.warn(`[RemoteControl] requestSystemKeyboard fallback: ${JSON.stringify(error)}`);
      this.showKeyboard = true;
    }
  }

  private toggleKeyboardInputMode(): void {
    if (this.showKeyboard) {
      this.showKeyboard = false;
      this.releaseImeProxyFocus();
      return;
    }
    this.activateCustomKeyboard();
  }

  private activateCustomKeyboard(): void {
    this.releaseImeProxyFocus();
    this.showToolbar = true;
    this.showKeyboard = true;
  }

  private releaseImeProxyFocus(): void {
    this.imeProxyDismissRequested = true;
    this.imeProxyFocused = false;
    try {
      const focusController = this.getUIContext().getFocusController();
      focusController.clearFocus();
    } catch (error) {
      console.warn(`[RemoteControl] releaseImeProxyFocus fallback: ${JSON.stringify(error)}`);
    }
  }

  private openSystemKeyboardFromCustomPanel(): void {
    this.showToolbar = true;
    this.showKeyboard = true;
    this.requestSystemKeyboard();
  }

  private setConnectionInfoVisible(visible: boolean): void {
    this.showConnectionInfo = visible;
    if (visible) {
      this.fpsCalcLastTime = 0;
      this.fpsCalcFrameCount = 0;
      if (this.connectionType.length === 0) {
        this.connectionType = this.lt('Detecting');
      }
      this.startConnectionInfoRefresh();
      this.maybeRequestVideoRefresh(true);
      return;
    }
    this.stopConnectionInfoRefresh();
    this.lastNonZeroFps = 0;
    this.lastNonZeroFpsAt = 0;
    this.fpsCalcLastTime = 0;
    this.fpsCalcFrameCount = 0;
  }

  private startConnectionInfoRefresh(): void {
    if (this.qualityRefreshTimer !== -1) {
      return;
    }
    this.qualityRefreshTimer = setInterval(() => {
      if (!this.showConnectionInfo) {
        this.stopConnectionInfoRefresh();
        return;
      }
      this.qualityRefreshTick += 1;
    }, 500);
  }

  private stopConnectionInfoRefresh(): void {
    if (this.qualityRefreshTimer === -1) {
      return;
    }
    clearInterval(this.qualityRefreshTimer);
    this.qualityRefreshTimer = -1;
  }

  private getLatencyColor(): string {
    if (this.connectionLatency <= 50) {
      return '#4CAF50';
    } else if (this.connectionLatency <= 100) {
      return '#8BC34A';
    } else if (this.connectionLatency <= 200) {
      return '#FFC107';
    } else {
      return '#F44336';
    }
  }

  private updateDisplayedFps(nextFps: number, now: number = Date.now()): void {
    if (nextFps > 0) {
      const roundedFps = Math.round(nextFps);
      this.connectionFps = roundedFps;
      this.lastNonZeroFps = roundedFps;
      this.lastNonZeroFpsAt = now;
      return;
    }
    if (!this.hasReceivedFrame) {
      this.connectionFps = 0;
      return;
    }
    const lastActivityAt = Math.max(this.lastFrameUpdatedAt, this.lastNonZeroFpsAt);
    if (lastActivityAt > 0 && now - lastActivityAt < 8000 && this.lastNonZeroFps > 0) {
      this.connectionFps = this.lastNonZeroFps;
      return;
    }
    this.connectionFps = 0;
  }

  private updateFps(): void {
    const now = Date.now();
    this.fpsCalcFrameCount += 1;

    if (this.fpsCalcLastTime === 0) {
      this.fpsCalcLastTime = now;
      return;
    }
    const elapsed = now - this.fpsCalcLastTime;
    if (elapsed >= 500) {
      const calculatedFps = Math.round(this.fpsCalcFrameCount * 1000 / elapsed);
      this.updateDisplayedFps(calculatedFps, now);
      this.fpsCalcFrameCount = 0;
      this.fpsCalcLastTime = now;
    }
  }

  @Builder
  private buildImeProxyInput() {
    TextInput({ text: $$this.imeProxyText, controller: this.imeProxyController })
      .id('remote-ime-proxy-input')
      .width(2)
      .height(2)
      .opacity(0.02)
      .caretColor(this.theme_CARET_HIDDEN)
      .backgroundColor(this.theme_CARET_HIDDEN)
      .fontSize(1)
      .position({ x: 4, y: 4 })
      .onChange((value: string) => {
        this.handleImeProxyTextChange(value);
      })
      .onSubmit((_enterKey: EnterKeyType) => {
        this.sendEnterKey();
      })
      .onFocus(() => {
        if (this.imeBlurTimer !== -1) {
          clearTimeout(this.imeBlurTimer);
          this.imeBlurTimer = -1;
        }
        this.imeProxyDismissRequested = false;
        this.imeProxyFocused = true;
        this.remoteInputActive = true;
        if (this.imeProxyText.length === 0) {
          this.imeProxyText = ' ';
          this.imeProxyPrev = ' ';
        }
      })
      .onBlur(() => {
        this.imeProxyFocused = false;
        this.remoteInputActive = false;
        this.imeProxyDismissRequested = true;
      });
  }

  @Builder
  private buildKeyboardPanel() {
    Column() {
      Scroll() {
        Row({ space: 6 }) {
          this.buildStickyKeyBtn('Ctrl', 50);
          this.buildStickyKeyBtn('Alt', 46);
          this.buildStickyKeyBtn('Shift', 56);
          this.buildKeyBtn('Win', 48);
          this.buildStickyKeyBtn('Fn', 42);
          this.buildKeyBtn('Esc', 48);
          this.buildKeyBtn('Tab', 48);
          this.buildKeyBtn('⌫', 48, 18);
          this.buildKeyBtn('Home', 58);
          this.buildKeyBtn('End', 48);
          this.buildKeyBtn('Ins', 48);
          this.buildKeyBtn('Del', 48);
          this.buildKeyBtn('PgUp', 58);
          this.buildKeyBtn('PgDn', 58);
          this.buildKeyBtn('PrtScr', 72, 13);
          this.buildKeyBtn('Menu', 54);
          this.buildKeyBtn('Enter', 66);
        }
        .padding({ left: 8, right: 8, top: 6, bottom: 4 });
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%');

      Scroll() {
        Row({ space: 6 }) {
          this.buildKeyBtn('←', 44, 18);
          this.buildKeyBtn('↑', 44, 18);
          this.buildKeyBtn('↓', 44, 18);
          this.buildKeyBtn('→', 44, 18);
          this.buildComboKeyBtn('Ctrl+C', 72, 17, 67);
          this.buildComboKeyBtn('Ctrl+V', 72, 17, 86);
          this.buildComboKeyBtn('Ctrl+S', 72, 17, 83);
          this.buildKeyBtn('F1', 44);
          this.buildKeyBtn('F2', 44);
          this.buildKeyBtn('F3', 44);
          this.buildKeyBtn('F4', 44);
          this.buildKeyBtn('F5', 44);
          this.buildKeyBtn('F6', 44);
          this.buildKeyBtn('F7', 44);
          this.buildKeyBtn('F8', 44);
          this.buildKeyBtn('F9', 44);
          this.buildKeyBtn('F10', 50);
          this.buildKeyBtn('F11', 50);
          this.buildKeyBtn('F12', 50);
        }
        .padding({ left: 8, right: 8, top: 2, bottom: 6 });
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%');
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    .border({ width: 0, color: Color.Transparent })
  }

  @Builder
  private buildKeyBtn(key: string, width: number = 60, fontSize: number = 14) {
    Button(key)
      .width(width)
      .height(42)
      .padding(0)
      .fontSize(fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme_TEXT_PRIMARY)
      .backgroundColor(this.activeKey === key ? this.theme_BORDER_SOFT : this.theme_TOOLBAR_BG)
      .opacity(0.5)
      .border({ width: 1, color: this.activeKey === key ? this.theme_ACCENT : this.theme_BORDER_SOFT })
      .scale(this.activeKey === key ? { x: 0.96, y: 0.96 } : { x: 1, y: 1 })
      .borderRadius(6)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.activeKey = key;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.activeKey = '';
        }
      })
      .onClick(() => {
        this.sendSpecialKey(key);
      });
  }

  private isStickyActive(key: string): boolean {
    if (key === 'Ctrl') return this.stickyCtrl;
    if (key === 'Alt') return this.stickyAlt;
    if (key === 'Shift') return this.stickyShift;
    if (key === 'Fn') return this.stickyFn;
    return false;
  }

  @Builder
  private buildStickyKeyBtn(key: string, width: number = 60) {
    Button(key)
      .width(width)
      .height(42)
      .padding(0)
      .fontSize(14)
      .fontWeight(this.isStickyActive(key) ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.isStickyActive(key) ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
      .backgroundColor(this.isStickyActive(key) ? this.theme_ACCENT : (this.activeKey === key ? this.theme_BORDER_SOFT : this.theme_TOOLBAR_BG))
      .opacity(0.5)
      .border({ width: 1, color: this.isStickyActive(key) || this.activeKey === key ? this.theme_ACCENT : this.theme_BORDER_SOFT })
      .scale(this.activeKey === key ? { x: 0.96, y: 0.96 } : { x: 1, y: 1 })
      .borderRadius(6)
      .shadow(this.isStickyActive(key) ? { radius: 6, color: this.theme_ACCENT, offsetX: 0, offsetY: 0 } : { radius: 0, color: Color.Transparent })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.activeKey = key;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.activeKey = '';
        }
      })
      .onClick(() => {
        this.sendSpecialKey(key);
      });
  }

  @Builder
  private buildComboKeyBtn(label: string, width: number, modifierCode: number, keyCode: number) {
    Button(label)
      .width(width)
      .height(42)
      .padding(0)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme_TEXT_PRIMARY)
      .backgroundColor(this.activeKey === label ? this.theme_BORDER_SOFT : this.theme_TOOLBAR_BG)
      .opacity(0.5)
      .border({ width: 1, color: this.activeKey === label ? this.theme_ACCENT : this.theme_BORDER_SOFT })
      .scale(this.activeKey === label ? { x: 0.96, y: 0.96 } : { x: 1, y: 1 })
      .borderRadius(6)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.activeKey = label;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.activeKey = '';
        }
      })
      .onClick(() => {
        NativeRustDeskBridge.sendKeyboardInput(keyCode, true, 1);
        NativeRustDeskBridge.sendKeyboardInput(keyCode, false, 1);
        this.maybeRequestVideoRefresh(true);
      });
  }

  @Builder
  private buildDisplaySelectPopup() {
    Column({ space: 0 }) {
      if (this.displayMenuPopupId === 'zoom') {
        Row() {
          Text(this.lt('Original Size'))
            .fontSize(13)
            .fontColor(this.displayScaleMode === 0 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
            .layoutWeight(1);
          if (this.displayScaleMode === 0) {
            Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT));
          } else {
            Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY));
          }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyDisplayScaleMode(0); this.displayMenuPopupId = ''; });
        Row() {
          Text(this.lt('Fit Window'))
            .fontSize(13)
            .fontColor(this.displayScaleMode === 1 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
            .layoutWeight(1);
          if (this.displayScaleMode === 1) {
            Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT));
          } else {
            Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY));
          }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyDisplayScaleMode(1); this.displayMenuPopupId = ''; });
        Row() {
          Text(this.lt('Custom Zoom'))
            .fontSize(13)
            .fontColor(this.displayScaleMode === 2 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
            .layoutWeight(1);
          if (this.displayScaleMode === 2) {
            Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT));
          } else {
            Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY));
          }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyDisplayScaleMode(2); this.displayMenuPopupId = ''; });
      } else if (this.displayMenuPopupId === 'codec') {
        Row() {
          Text('Auto').fontSize(13).fontColor(this.videoCodecMode === 0 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 0) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(0); this.displayMenuPopupId = ''; });
        Row() {
          Text('VP8').fontSize(13).fontColor(this.videoCodecMode === 1 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 1) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(1); this.displayMenuPopupId = ''; });
        Row() {
          Text('VP9').fontSize(13).fontColor(this.videoCodecMode === 2 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 2) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(2); this.displayMenuPopupId = ''; });
        Row() {
          Text('AV1').fontSize(13).fontColor(this.videoCodecMode === 3 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 3) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(3); this.displayMenuPopupId = ''; });
        Row() {
          Text('H264').fontSize(13).fontColor(this.videoCodecMode === 4 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 4) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(4); this.displayMenuPopupId = ''; });
        Row() {
          Text('H265').fontSize(13).fontColor(this.videoCodecMode === 5 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY).layoutWeight(1);
          if (this.videoCodecMode === 5) { Image($rawfile('checkbox-checked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_ACCENT)); } else { Image($rawfile('checkbox-unchecked.svg')).width(16).height(16).colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY)); }
        }
        .width('100%').height(40).padding({ left: 16, right: 16 })
        .onClick(() => { this.applyVideoCodec(5); this.displayMenuPopupId = ''; });
      }
    }
    .width(200)
    .borderRadius(12)
    .backgroundColor(this.theme_MENU_BG)
    .border({ width: 1, color: this.theme_BORDER_SOFT })
    .shadow({ radius: 16, color: '#60000000', offsetY: -4 });
  }

  @Builder
  private buildDisplayMenuPanel() {
    Column() {
      this.buildSessionPanelHeader(this.lt('Display Settings'), 'display', { icon: 'opt_rotate.svg', isStroke: true, action: () => { this.toggleRotation(); } });

      Scroll() {
        Column({ space: 0 }) {
          Row({ space: 12 }) {
            Text(this.lt('Zoom Mode'))
              .fontSize(14)
              .fontColor(this.theme_TEXT_PRIMARY)
              .layoutWeight(1)
            Text(this.resolveDisplayScaleModeLabel())
              .fontSize(13)
              .fontColor(this.theme_TEXT_SECONDARY)
            Text(this.displayMenuPopupId === 'zoom' ? '▲' : '▼')
              .fontSize(10)
              .fontColor(this.theme_TEXT_TERTIARY)
          }
          .width('100%')
          .height(48)
          .onClick(() => { this.displayMenuPopupId = this.displayMenuPopupId === 'zoom' ? '' : 'zoom'; })

          if (this.displayScaleMode === 2) {
            Column() {
              Row() {
                Text(this.lt('Custom Zoom'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .layoutWeight(1)
                Text(`${this.customZoomPercent}%`)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_PRIMARY)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              Slider({
                value: this.customZoomPercent,
                min: 100,
                max: 600,
                step: 10,
                style: SliderStyle.OutSet
              })
                .selectedColor(this.theme_ACCENT)
                .trackColor(this.theme_BORDER_SOFT)
                .width('100%')
                .padding({ left: 16, right: 16 })
                .onChange((value: number) => {
                  this.customZoomPercent = Math.round(value);
                  this.pinchScale = this.customZoomPercent / 100;
                  this.lastPinchScale = this.pinchScale;
                  NativeRustDeskBridge.setLocalOption('custom-zoom-percent', String(this.customZoomPercent));
                })
            }
            .width('100%')
            .padding({ bottom: 6 })
          }

          Text(this.lt('Image Quality'))
            .fontSize(13)
            .fontColor(this.theme_TEXT_TERTIARY)
            .width('100%')
            .padding({ top: 12, bottom: 6 });
          RadioOptionItem({ label: this.lt('Best Quality'), icon: 'opt_quality.svg', selected: this.imageQualityMode === 0, onSelected: () => { this.applyImageQuality(0); } })
          RadioOptionItem({ label: this.lt('Balanced'), icon: 'opt_balance.svg', selected: this.imageQualityMode === 1, onSelected: () => { this.applyImageQuality(1); } })
          RadioOptionItem({ label: this.lt('Best Speed'), icon: 'opt_speed.svg', selected: this.imageQualityMode === 2, onSelected: () => { this.applyImageQuality(2); } })
          RadioOptionItem({ label: this.lt('Custom'), icon: 'opt_custom.svg', selected: this.imageQualityMode === 3, onSelected: () => { this.applyImageQuality(3); } })
          if (this.imageQualityMode === 3) {
            Column() {
              Row() {
                Text(this.lt('Bitrate'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .layoutWeight(1)
                Text(`${this.customBitrate}%`)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_PRIMARY)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              Slider({
                value: this.customBitrate,
                min: 10,
                max: this.showMoreBitrate ? 2000 : 100,
                step: this.showMoreBitrate ? 10 : 5,
                style: SliderStyle.OutSet
              })
                .selectedColor(this.theme_ACCENT)
                .trackColor(this.theme_BORDER_SOFT)
                .width('100%')
                .padding({ left: 16, right: 16 })
                .onChange((value: number) => {
                  this.customBitrate = value;
                  if (this.bitrateDebounceTimer !== -1) { clearTimeout(this.bitrateDebounceTimer); }
                  this.bitrateDebounceTimer = setTimeout(() => { this.applySessionOption('custom-image-quality', String(this.customBitrate)); }, 100);
                })
              Row() {
                Checkbox()
                  .select(this.showMoreBitrate)
                  .selectedColor(this.theme_ACCENT)
                  .onChange((checked: boolean) => { this.showMoreBitrate = checked; if (this.customBitrate > 100 && !checked) { this.customBitrate = 100; } })
                Text(this.lt('More'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .margin({ left: 6 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 4, bottom: 8 })

              Row() {
                Text(this.lt('FPS'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .layoutWeight(1)
                Text(`${this.customFps}`)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_PRIMARY)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 4 })
              Slider({
                value: this.customFps,
                min: 10,
                max: 120,
                step: 5,
                style: SliderStyle.OutSet
              })
                .selectedColor(this.theme_ACCENT)
                .trackColor(this.theme_BORDER_SOFT)
                .width('100%')
                .padding({ left: 16, right: 16 })
                .onChange((value: number) => {
                  this.customFps = value;
                  if (this.fpsDebounceTimer !== -1) { clearTimeout(this.fpsDebounceTimer); }
                  this.fpsDebounceTimer = setTimeout(() => { this.applySessionOption('custom-fps', String(this.customFps)); }, 100);
                })
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }

          Row({ space: 12 }) {
            Text(this.lt('Codec'))
              .fontSize(14)
              .fontColor(this.theme_TEXT_PRIMARY)
              .layoutWeight(1)
            Text(this.resolveVideoCodecLabel())
              .fontSize(13)
              .fontColor(this.theme_TEXT_SECONDARY)
            Text(this.displayMenuPopupId === 'codec' ? '▲' : '▼')
              .fontSize(10)
              .fontColor(this.theme_TEXT_TERTIARY)
          }
          .width('100%')
          .height(48)
          .margin({ top: 8 })
          .onClick(() => { this.displayMenuPopupId = this.displayMenuPopupId === 'codec' ? '' : 'codec'; })

          Text(this.lt('Keyboard Mode'))
            .fontSize(13)
            .fontColor(this.theme_TEXT_TERTIARY)
            .width('100%')
            .padding({ top: 12, bottom: 6 });
          RadioOptionItem({ label: this.lt('Legacy mode'), icon: 'settings_terminal.svg', selected: this.keyboardMode === 0, onSelected: () => { this.keyboardMode = 0; this.applySessionOption('keyboard-mode', 'legacy'); } })
          if (this.keyboardMapSupported) {
            RadioOptionItem({ label: this.lt('Map mode'), icon: 'opt_grid.svg', selected: this.keyboardMode === 1, onSelected: () => { if (this.applySessionOption('keyboard-mode', 'map')) { this.keyboardMode = 1; } } })
          }
          if (this.keyboardTranslateSupported) {
            RadioOptionItem({ label: this.lt('Translate mode'), icon: 'opt_translate.svg', selected: this.keyboardMode === 2, onSelected: () => { if (this.applySessionOption('keyboard-mode', 'translate')) { this.keyboardMode = 2; } } })
          }

          Column() {}
            .width('100%')
            .height(1)
            .backgroundColor(this.theme_BORDER_SOFT)
            .margin({ top: 12, bottom: 8 });

          CheckboxOptionItem({ label: this.lt('Show Remote Cursor'), icon: 'opt_mouse.svg', checked: this.showRemoteCursor, onToggle: () => { this.showRemoteCursor = !this.showRemoteCursor; this.applyToggleOption('show-remote-cursor', this.showRemoteCursor); } })
          if (this.showRemoteCursor) {
            Column() {
              Row() {
                Text(this.lt('Cursor Scale'))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .layoutWeight(1)
                Text(`${this.remoteCursorScale.toFixed(1)}x`)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_PRIMARY)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              Slider({
                value: this.remoteCursorScale,
                min: 0.5,
                max: 3.0,
                step: 0.1,
                style: SliderStyle.OutSet
              })
                .selectedColor(this.theme_ACCENT)
                .trackColor(this.theme_BORDER_SOFT)
                .width('100%')
                .padding({ left: 16, right: 16 })
                .onChange((v: number, mode: SliderChangeMode) => {
                  if (mode === SliderChangeMode.Moving) { this.remoteCursorScale = Math.round(v * 10) / 10; }
                  if (mode === SliderChangeMode.End) { this.remoteCursorScale = Math.round(v * 10) / 10; NativeRustDeskBridge.setLocalOption('remote-cursor-scale', String(this.remoteCursorScale)); }
                })
            }
            .width('100%')
            .padding({ bottom: 6 })
          }
          CheckboxOptionItem({ label: this.lt('Show Quality Monitor'), icon: 'opt_activity.svg', checked: this.showQualityMonitor, onToggle: () => { this.showQualityMonitor = !this.showQualityMonitor; this.setConnectionInfoVisible(this.showQualityMonitor); this.applyToggleOption('show-quality-monitor', this.showQualityMonitor); } })
          CheckboxOptionItem({ label: this.lt('Mute'), icon: 'opt_mute.svg', checked: this.muteAudio, onToggle: () => { this.muteAudio = !this.muteAudio; this.applyToggleOption('disable-audio', this.muteAudio); } })
          CheckboxOptionItem({ label: this.lt('Disable Clipboard'), icon: 'menu_clipboard.svg', checked: this.disableClipboard, onToggle: () => { this.toggleClipboardSync(); } })
          CheckboxOptionItem({ label: this.lt('Lock After Session End'), icon: 'menu_lock.svg', checked: this.lockAfterSession, onToggle: () => { this.lockAfterSession = !this.lockAfterSession; this.applyToggleOption('lock-after-session-end', this.lockAfterSession); } })
          CheckboxOptionItem({ label: this.lt('Reverse Scroll'), icon: 'settings_udp.svg', checked: this.reverseScroll, onToggle: () => { this.reverseScroll = !this.reverseScroll; this.applyToggleOption('reverse-scroll', this.reverseScroll); } })
          CheckboxOptionItem({ label: this.lt('Swap Mouse Buttons'), icon: 'menu_switch.svg', checked: this.swapMouseButtons, onToggle: () => { this.swapMouseButtons = !this.swapMouseButtons; this.applyToggleOption('swap-left-right-mouse', this.swapMouseButtons); } })
          CheckboxOptionItem({ label: this.lt('View Mode'), icon: 'opt_view.svg', checked: this.viewMode, onToggle: () => { this.viewMode = !this.viewMode; this.applyToggleOption('view-only', this.viewMode); } })
          CheckboxOptionItem({ label: this.lt('Privacy Mode'), icon: 'opt_shield.svg', checked: this.privacyMode, onToggle: () => {
            const next = !this.privacyMode;
            if (this.applyToggleOption('privacy-mode', next)) {
              this.privacyMode = next;
            } else {
              void this.showToast(this.lt('Unsupported'));
            }
          } })
        }
        .padding({ left: 12, right: 12, bottom: 12 });
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ maxHeight: 520 });
    }
    .width(210)
    .borderRadius(16)
    .backgroundColor(this.theme_MENU_BG)
    .shadow({ radius: 16, color: '#40000000', offsetY: -4 });
  }

  @Builder
  private buildMouseModeMenuPanel() {
    Column() {
      this.buildSessionPanelHeader(this.lt('Mouse Control'), 'mouse');

      Row({ space: 10 }) {
        Image($rawfile('opt_touch.svg'))
          .width(18).height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
        Text(this.lt('Touch Mode'))
          .fontSize(14)
          .fontColor(this.mouseControlMode === 0 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
          .layoutWeight(1)
        Stack() {
          Circle()
            .width(20).height(20)
            .fill(Color.Transparent)
            .stroke(this.mouseControlMode === 0 ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
            .strokeWidth(2)
          if (this.mouseControlMode === 0) {
            Circle().width(12).height(12).fill(this.theme_ACCENT)
          }
        }
        .width(20).height(20)
      }
      .width('100%').height(44)
      .padding({ left: 12, right: 12 })
      .onClick(() => { this.mouseControlMode = 0; NativeRustDeskBridge.setLocalOption('mouse-control-mode', '0'); })

      Row({ space: 10 }) {
        Image($rawfile('opt_mouse.svg'))
          .width(18).height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
        Text(this.lt('Mouse Mode'))
          .fontSize(14)
          .fontColor(this.mouseControlMode === 1 ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
          .layoutWeight(1)
        Stack() {
          Circle()
            .width(20).height(20)
            .fill(Color.Transparent)
            .stroke(this.mouseControlMode === 1 ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
            .strokeWidth(2)
          if (this.mouseControlMode === 1) {
            Circle().width(12).height(12).fill(this.theme_ACCENT)
          }
        }
        .width(20).height(20)
      }
      .width('100%').height(44)
      .padding({ left: 12, right: 12 })
      .onClick(() => { this.mouseControlMode = 1; NativeRustDeskBridge.setLocalOption('mouse-control-mode', '1'); this.showMouseModeMenu = false; this.showToolbar = false; })

      if (this.mouseControlMode === 0) {
        Column() {}
          .width('100%')
          .height(1)
          .backgroundColor(this.theme_BORDER_SOFT)
          .margin({ top: 8, bottom: 8 });

        this.buildTouchSettingsTab();
      }

      if (this.mouseControlMode === 1) {
        Column() {}
          .width('100%')
          .height(1)
          .backgroundColor(this.theme_BORDER_SOFT)
          .margin({ top: 8, bottom: 8 });

        this.buildMouseSettingsTab();
      }
    }
    .width(260)
    .borderRadius(16)
    .backgroundColor(this.theme_MENU_BG)
    .shadow({ radius: 16, color: '#40000000', offsetY: -4 });
  }

  @Builder
  private buildVirtualMouseOverlay() {
    Stack() {
    Stack() {
      Image($rawfile('cursor-pointer.svg'))
        .width(24)
        .height(24)
        .objectFit(ImageFit.Fill)
        .scale({ x: this.cursorIconSize / 24, y: this.cursorIconSize / 24, centerX: 0, centerY: 0 })
        .position({ x: this.cursorScreenX - this.cursorIconSize * 0.195 - this.getVisibleImageBounds()[0], y: this.cursorScreenY - this.cursorIconSize * 0.261 - this.getVisibleImageBounds()[1] })
        .hitTestBehavior(HitTestMode.Transparent);
    }
    .width(this.getVisibleImageBounds()[2])
    .height(this.getVisibleImageBounds()[3])
    .position({ x: this.getVisibleImageBounds()[0], y: this.getVisibleImageBounds()[1] })
    .clip(true)
    .hitTestBehavior(HitTestMode.Transparent);

      Circle({ width: 100, height: 100 })
        .fill('rgba(30, 40, 60, 0.55)')
        .stroke('rgba(100, 120, 160, 0.5)')
        .strokeWidth(2)
        .position({ x: 20, y: this.previewHeight - 120 })
        .hitTestBehavior(HitTestMode.Transparent);

      Circle({ width: 44, height: 44 })
        .fill(this.joystickActive ? 'rgba(0, 113, 255, 0.85)' : 'rgba(90, 110, 150, 0.75)')
        .stroke('#FFFFFF')
        .strokeWidth(1.5)
        .position({ x: 48 + this.joystickKnobX, y: this.previewHeight - 92 + this.joystickKnobY })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.Transparent);

      Column()
        .width(100)
        .height(100)
        .position({ x: 20, y: this.previewHeight - 120 })
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => {
          this.handleJoystickTouch(event);
        });

      Circle({ width: 52, height: 52 })
        .fill(this.leftBtnActive ? 'rgba(0, 113, 255, 0.85)' : 'rgba(30, 40, 60, 0.55)')
        .stroke(this.leftBtnActive ? 'rgba(255, 255, 255, 0.9)' : 'rgba(100, 120, 160, 0.5)')
        .strokeWidth(2)
        .position({ x: this.previewWidth - 130, y: this.previewHeight - 72 })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.Transparent);
      Text('L')
        .fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .width(52).height(52)
        .position({ x: this.previewWidth - 130, y: this.previewHeight - 72 })
        .hitTestBehavior(HitTestMode.Transparent);
      Column().width(52).height(52)
        .position({ x: this.previewWidth - 130, y: this.previewHeight - 72 })
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => { this.handleMouseButtonTouch(event, 'l'); });

      Circle({ width: 52, height: 52 })
        .fill(this.middleBtnActive ? 'rgba(0, 113, 255, 0.85)' : 'rgba(30, 40, 60, 0.55)')
        .stroke(this.middleBtnActive ? 'rgba(255, 255, 255, 0.9)' : 'rgba(100, 120, 160, 0.5)')
        .strokeWidth(2)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 188 })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.Transparent);
      Text('M')
        .fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 188 })
        .hitTestBehavior(HitTestMode.Transparent);
      Column().width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 188 })
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => { this.handleMouseButtonTouch(event, 'm'); });

      Circle({ width: 52, height: 52 })
        .fill(this.rightBtnActive ? 'rgba(0, 113, 255, 0.85)' : 'rgba(30, 40, 60, 0.55)')
        .stroke(this.rightBtnActive ? 'rgba(255, 255, 255, 0.9)' : 'rgba(100, 120, 160, 0.5)')
        .strokeWidth(2)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 130 })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.Transparent);
      Text('R')
        .fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 130 })
        .hitTestBehavior(HitTestMode.Transparent);
      Column().width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 130 })
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => { this.handleMouseButtonTouch(event, 'r'); });

      Circle({ width: 52, height: 52 })
        .fill(this.panBtnActive ? 'rgba(0, 113, 255, 0.85)' : 'rgba(30, 40, 60, 0.55)')
        .stroke(this.panBtnActive ? 'rgba(255, 255, 255, 0.9)' : 'rgba(100, 120, 160, 0.5)')
        .strokeWidth(2)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 72 })
        .animation({ duration: 80, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.Transparent);
      Text('P')
        .fontSize(18).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
        .width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 72 })
        .hitTestBehavior(HitTestMode.Transparent);
      Column().width(52).height(52)
        .position({ x: this.previewWidth - 72, y: this.previewHeight - 72 })
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => { this.handleMouseButtonTouch(event, 'p'); });
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent);
  }

  private handleJoystickTouch(event: TouchEvent): void {
    const centerX = 50;
    const centerY = 50;
    const maxRadius = 28;
    let touch: TouchObject | undefined = undefined;
    if (event.type === TouchType.Down) {
      if (event.touches && event.touches.length > 0) {
        for (let i = 0; i < event.touches.length; i++) {
          const t = event.touches[i];
          if (t.x >= 0 && t.x <= 100 && t.y >= 0 && t.y <= 100) {
            touch = t;
            this.joystickTouchId = t.id;
            break;
          }
        }
        if (touch === undefined) {
          return;
        }
      }
    } else {
      if (this.joystickTouchId >= 0 && event.touches) {
        for (let i = 0; i < event.touches.length; i++) {
          if (event.touches[i].id === this.joystickTouchId) {
            touch = event.touches[i];
            break;
          }
        }
      }
    }
    if (touch === undefined) {
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.joystickActive = false;
        this.joystickKnobX = 0;
        this.joystickKnobY = 0;
        this.joystickTouchId = -1;
        this.startPanSpringBack();
      }
      return;
    }
    const dx = touch.x - centerX;
    const dy = touch.y - centerY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const clampedDist = Math.min(dist, maxRadius);
    const angle = Math.atan2(dy, dx);
    const clampedX = dist > maxRadius ? Math.cos(angle) * clampedDist : dx;
    const clampedY = dist > maxRadius ? Math.sin(angle) * clampedDist : dy;
    if (event.type === TouchType.Down) {
      this.joystickActive = true;
      this.joystickKnobX = clampedX;
      this.joystickKnobY = clampedY;
    } else if (event.type === TouchType.Move) {
      this.joystickKnobX = clampedX;
      this.joystickKnobY = clampedY;
      if (Math.abs(clampedX) > 0 || Math.abs(clampedY) > 0) {
        if (this.joystickPanMode) {
          this.panOffsetX = this.panOffsetX - Math.round(clampedX * (this.joystickSpeed / 5));
          this.panOffsetY = this.panOffsetY - Math.round(clampedY * (this.joystickSpeed / 5));
        } else {
          const speedFactor = this.joystickSpeed / 25;
          const moveX = Math.round(clampedX * speedFactor);
          const moveY = Math.round(clampedY * speedFactor);
          const newScreenX = this.cursorScreenX + moveX;
          const newScreenY = this.cursorScreenY + moveY;
          const bounds = this.getCursorClampBounds();
          const clampedPosX = Math.max(bounds[0], Math.min(bounds[0] + bounds[2], newScreenX));
          const clampedPosY = Math.max(bounds[1], Math.min(bounds[1] + bounds[3], newScreenY));
          const excessX = newScreenX - clampedPosX;
          const excessY = newScreenY - clampedPosY;
          this.cursorScreenX = clampedPosX;
          this.cursorScreenY = clampedPosY;
          if (excessX !== 0 || excessY !== 0) {
            this.panOffsetX = this.panOffsetX - excessX;
            this.panOffsetY = this.panOffsetY - excessY;
          }
          const mapped = this.mapTouchToRemote(this.cursorScreenX, this.cursorScreenY, true);
          if (mapped !== null) {
            this.lastPointerRemoteX = mapped.x;
            this.lastPointerRemoteY = mapped.y;
            this.hasPointerPosition = true;
            this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mapped.x, mapped.y, TouchType.Move);
            this.remoteCursorX = mapped.x;
            this.remoteCursorY = mapped.y;
            this.remoteCursorVisible = true;
          }
        }
      }
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.joystickActive = false;
      this.joystickKnobX = 0;
      this.joystickKnobY = 0;
      this.joystickTouchId = -1;
      this.startPanSpringBack();
    }
  }

  private handleMouseButtonTouch(event: TouchEvent, button: string): void {
    const isDown = event.type === TouchType.Down;
    const isUp = event.type === TouchType.Up || event.type === TouchType.Cancel;
    if (button === 'p') {
      if (isDown) {
        this.panBtnActive = true;
        this.joystickPanMode = true;
      } else if (isUp) {
        this.panBtnActive = false;
        this.joystickPanMode = false;
      }
      return;
    }
    if (isDown && !this.hasPointerPosition && this.previewWidth > 0 && this.previewHeight > 0) {
      if (!this.hasCursorScreenPosition) {
        const bounds = this.getCursorClampBounds();
        this.cursorScreenX = bounds[0] + bounds[2] / 2;
        this.cursorScreenY = bounds[1] + bounds[3] / 2;
        this.hasCursorScreenPosition = true;
      }
      const mapped = this.mapTouchToRemote(this.cursorScreenX, this.cursorScreenY, true);
      if (mapped !== null) {
        this.lastPointerRemoteX = mapped.x;
        this.lastPointerRemoteY = mapped.y;
        this.hasPointerPosition = true;
      }
    }
    if (isDown) {
      if (button === 'l') { this.leftBtnActive = true; }
      else if (button === 'r') { this.rightBtnActive = true; }
      else if (button === 'm') { this.middleBtnActive = true; }
      if (this.hasPointerPosition) {
        if (button === 'l') {
          this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        } else if (button === 'r') {
          this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        } else if (button === 'm') {
          this.sendRemoteMouseMask(MOUSE_MASK.MIDDLE_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        }
        this.maybeRequestVideoRefresh(true);
      }
    } else if (isUp) {
      if (button === 'l') { this.leftBtnActive = false; }
      else if (button === 'r') { this.rightBtnActive = false; }
      else if (button === 'm') { this.middleBtnActive = false; }
      if (this.hasPointerPosition) {
        if (button === 'l') {
          this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        } else if (button === 'r') {
          this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        } else if (button === 'm') {
          this.sendRemoteMouseMask(MOUSE_MASK.MIDDLE_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        }
        this.maybeRequestVideoRefresh(true);
      }
    }
  }

  @Builder
  private buildTouchSettingsTab() {
    Column({ space: 0 }) {
      Text(this.lt('Touch Settings'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 4 });
      TouchGestureRow({ label: this.lt('Tap'), durationText: `${this.touchSettings.tap.duration}ms`, actionText: this.getTouchActionLabel(this.touchSettings.tap.action), onTimeClick: () => { this.touchPopupRow = 0; this.touchPopupDurVal = this.touchSettings.tap.duration; this.touchPopupId = this.touchPopupId === 'tap:slider' ? '' : 'tap:slider'; }, onActionClick: () => { this.touchPopupRow = 0; this.touchPopupId = this.touchPopupId === 'tap:action' ? '' : 'tap:action'; } })
      TouchGestureRow({ label: this.lt('Long Press'), durationText: `${this.touchSettings.longPress.duration}ms`, actionText: this.getTouchActionLabel(this.touchSettings.longPress.action), onTimeClick: () => { this.touchPopupRow = 1; this.touchPopupDurVal = this.touchSettings.longPress.duration; this.touchPopupId = this.touchPopupId === 'long-press:slider' ? '' : 'long-press:slider'; }, onActionClick: () => { this.touchPopupRow = 1; this.touchPopupId = this.touchPopupId === 'long-press:action' ? '' : 'long-press:action'; } })
      TouchGestureRow({ label: this.lt('Swipe'), durationText: `${this.touchSettings.swipe.duration}ms ${this.touchSettings.swipe.speed}x`, actionText: this.getTouchActionLabel(this.touchSettings.swipe.action), onTimeClick: () => { this.touchPopupRow = 2; this.touchPopupDurVal = this.touchSettings.swipe.duration; this.touchPopupSpdVal = this.touchSettings.swipe.speed; this.touchPopupId = this.touchPopupId === 'swipe:slider' ? '' : 'swipe:slider'; }, onActionClick: () => { this.touchPopupRow = 2; this.touchPopupId = this.touchPopupId === 'swipe:action' ? '' : 'swipe:action'; } })
      TouchGestureRow({ label: this.lt('Short Press Drag'), durationText: `${this.touchSettings.shortPressDrag.duration}ms ${this.touchSettings.shortPressDrag.speed}x`, actionText: this.getTouchActionLabel(this.touchSettings.shortPressDrag.action), onTimeClick: () => { this.touchPopupRow = 3; this.touchPopupDurVal = this.touchSettings.shortPressDrag.duration; this.touchPopupSpdVal = this.touchSettings.shortPressDrag.speed; this.touchPopupId = this.touchPopupId === 'short-press-drag:slider' ? '' : 'short-press-drag:slider'; }, onActionClick: () => { this.touchPopupRow = 3; this.touchPopupId = this.touchPopupId === 'short-press-drag:action' ? '' : 'short-press-drag:action'; } })
      TouchGestureRow({ label: this.lt('Long Press Drag'), durationText: `${this.touchSettings.longPressDrag.duration}ms ${this.touchSettings.longPressDrag.speed}x`, actionText: this.getTouchActionLabel(this.touchSettings.longPressDrag.action), onTimeClick: () => { this.touchPopupRow = 4; this.touchPopupDurVal = this.touchSettings.longPressDrag.duration; this.touchPopupSpdVal = this.touchSettings.longPressDrag.speed; this.touchPopupId = this.touchPopupId === 'long-press-drag:slider' ? '' : 'long-press-drag:slider'; }, onActionClick: () => { this.touchPopupRow = 4; this.touchPopupId = this.touchPopupId === 'long-press-drag:action' ? '' : 'long-press-drag:action'; } })
      TouchGestureRow({ label: this.lt('Two-finger Pinch'), durationText: `${this.touchSettings.twoFingerPinch.duration}ms`, actionText: this.getTouchActionLabel(this.touchSettings.twoFingerPinch.action), onTimeClick: () => { this.touchPopupRow = 5; this.touchPopupDurVal = this.touchSettings.twoFingerPinch.duration; this.touchPopupId = this.touchPopupId === 'two-finger-pinch:slider' ? '' : 'two-finger-pinch:slider'; }, onActionClick: () => { this.touchPopupRow = 5; this.touchPopupId = this.touchPopupId === 'two-finger-pinch:action' ? '' : 'two-finger-pinch:action'; } })
      TouchGestureRow({ label: this.lt('Two-finger Pan'), durationText: `${this.touchSettings.twoFingerPan.duration}ms`, actionText: this.getTouchActionLabel(this.touchSettings.twoFingerPan.action), onTimeClick: () => { this.touchPopupRow = 6; this.touchPopupDurVal = this.touchSettings.twoFingerPan.duration; this.touchPopupId = this.touchPopupId === 'two-finger-pan:slider' ? '' : 'two-finger-pan:slider'; }, onActionClick: () => { this.touchPopupRow = 6; this.touchPopupId = this.touchPopupId === 'two-finger-pan:action' ? '' : 'two-finger-pan:action'; } })
    }
    .width('100%');
  }

  @Builder
  private buildMouseSettingsTab() {
    Column({ space: 8 }) {
      Text(this.lt('Mouse Settings'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 4 });
      Text(this.lt('Mouse Sensitivity'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12 });
      Row() {
        Slider({ value: this.mouseSensitivity, min: 1, max: 20, step: 1, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor(this.theme_ACCENT)
          .onChange((v: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) { this.mouseSensitivity = Math.round(v); }
            if (mode === SliderChangeMode.End) { this.mouseSensitivity = Math.round(v); NativeRustDeskBridge.setLocalOption('mouse-sensitivity', String(this.mouseSensitivity)); }
          });
        Text(`${this.mouseSensitivity}`)
          .fontSize(11)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width(30)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ left: 12, right: 12 });

      Text(this.lt('Scroll Speed'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12 });
      Row() {
        Slider({ value: this.mouseScrollSpeed, min: 1, max: 10, step: 1, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor(this.theme_ACCENT)
          .onChange((v: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) { this.mouseScrollSpeed = Math.round(v); }
            if (mode === SliderChangeMode.End) { this.mouseScrollSpeed = Math.round(v); NativeRustDeskBridge.setLocalOption('mouse-scroll-speed', String(this.mouseScrollSpeed)); }
          });
        Text(`${this.mouseScrollSpeed}`)
          .fontSize(11)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width(30)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ left: 12, right: 12 });

      Text(this.lt('Joystick Speed'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12 });
      Row() {
        Slider({ value: this.joystickSpeed, min: 0.1, max: 20, step: 0.1, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor(this.theme_ACCENT)
          .onChange((v: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) { this.joystickSpeed = Math.round(v * 10) / 10; }
            if (mode === SliderChangeMode.End) { this.joystickSpeed = Math.round(v * 10) / 10; NativeRustDeskBridge.setLocalOption('joystick-speed', String(this.joystickSpeed)); }
          });
        Text(`${this.joystickSpeed >= 1 ? Math.floor(this.joystickSpeed) : this.joystickSpeed.toFixed(1)}`)
          .fontSize(11)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width(30)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ left: 12, right: 12 });

      Text(this.lt('Cursor Size'))
        .fontSize(12)
        .fontColor(this.theme_TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 12, right: 12 });
      Row() {
        Slider({ value: this.cursorIconSize, min: 16, max: 64, step: 2, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor(this.theme_ACCENT)
          .onChange((v: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Moving) { this.cursorIconSize = Math.round(v); }
            if (mode === SliderChangeMode.End) { this.cursorIconSize = Math.round(v); NativeRustDeskBridge.setLocalOption('cursor-icon-size', String(this.cursorIconSize)); }
          });
        Text(`${this.cursorIconSize}`)
          .fontSize(11)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width(30)
          .textAlign(TextAlign.Center);
      }
      .width('100%')
      .padding({ left: 12, right: 12 });
    }
    .width('100%');
  }

  @Builder
  private buildTouchPopup() {
    if (this.touchPopupId.length > 0) {
      Column() {
        if (this.touchPopupId === 'tap:slider') {
          this.buildTouchSliderPopup(this.touchSettings.tap.duration, 50, 1000, 50, (v: number) => { this.touchSettings.tap = { duration: v, action: this.touchSettings.tap.action, speed: 1 }; this.saveTouchSettings(); this.initTouchInteractionManager(); });
        } else if (this.touchPopupId === 'long-press:slider') {
          this.buildTouchSliderPopup(this.touchSettings.longPress.duration, 200, 2000, 50, (v: number) => { this.touchSettings.longPress = { duration: v, action: this.touchSettings.longPress.action, speed: 1 }; this.saveTouchSettings(); this.initTouchInteractionManager(); });
        } else if (this.touchPopupId === 'swipe:slider') {
          this.buildTouchDualSliderPopup(this.touchSettings.swipe.duration, this.touchSettings.swipe.speed, (v: number) => { this.touchSettings.swipe = { duration: v, action: this.touchSettings.swipe.action, speed: this.touchSettings.swipe.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); }, (v: number) => { this.touchSettings.swipe = { duration: this.touchSettings.swipe.duration, action: this.touchSettings.swipe.action, speed: v }; this.saveTouchSettings(); this.initTouchInteractionManager(); });
        } else if (this.touchPopupId === 'short-press-drag:slider') {
          this.buildTouchDualSliderPopup(this.touchSettings.shortPressDrag.duration, this.touchSettings.shortPressDrag.speed, (v: number) => { this.touchSettings.shortPressDrag = { duration: v, action: this.touchSettings.shortPressDrag.action, speed: this.touchSettings.shortPressDrag.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); }, (v: number) => { this.touchSettings.shortPressDrag = { duration: this.touchSettings.shortPressDrag.duration, action: this.touchSettings.shortPressDrag.action, speed: v }; this.saveTouchSettings(); this.initTouchInteractionManager(); });
        } else if (this.touchPopupId === 'long-press-drag:slider') {
          this.buildTouchDualSliderPopup(this.touchSettings.longPressDrag.duration, this.touchSettings.longPressDrag.speed, (v: number) => { this.touchSettings.longPressDrag = { duration: v, action: this.touchSettings.longPressDrag.action, speed: this.touchSettings.longPressDrag.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); }, (v: number) => { this.touchSettings.longPressDrag = { duration: this.touchSettings.longPressDrag.duration, action: this.touchSettings.longPressDrag.action, speed: v }; this.saveTouchSettings(); this.initTouchInteractionManager(); });
        } else if (this.touchPopupId === 'two-finger-pinch:slider') {
          this.buildTouchSliderPopup(this.touchSettings.twoFingerPinch.duration, 0, 1000, 50, (v: number) => { this.touchSettings.twoFingerPinch = { duration: v, action: this.touchSettings.twoFingerPinch.action, speed: 1 }; this.saveTouchSettings(); });
        } else if (this.touchPopupId === 'two-finger-pan:slider') {
          this.buildTouchSliderPopup(this.touchSettings.twoFingerPan.duration, 200, 2000, 50, (v: number) => { this.touchSettings.twoFingerPan = { duration: v, action: this.touchSettings.twoFingerPan.action, speed: 1 }; this.saveTouchSettings(); });
        } else if (this.touchPopupId === 'tap:action') {
          this.buildTouchActionPopup(TAP_ACTIONS, this.touchSettings.tap.action, (a: TouchAction) => { this.touchSettings.tap = { duration: this.touchSettings.tap.duration, action: a, speed: 1 }; this.saveTouchSettings(); this.initTouchInteractionManager(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'long-press:action') {
          this.buildTouchActionPopup(LONG_PRESS_ACTIONS, this.touchSettings.longPress.action, (a: TouchAction) => { this.touchSettings.longPress = { duration: this.touchSettings.longPress.duration, action: a, speed: 1 }; this.saveTouchSettings(); this.initTouchInteractionManager(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'swipe:action') {
          this.buildTouchActionPopup(SWIPE_ACTIONS, this.touchSettings.swipe.action, (a: TouchAction) => { this.touchSettings.swipe = { duration: this.touchSettings.swipe.duration, action: a, speed: this.touchSettings.swipe.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'short-press-drag:action') {
          this.buildTouchActionPopup(SHORT_PRESS_DRAG_ACTIONS, this.touchSettings.shortPressDrag.action, (a: TouchAction) => { this.touchSettings.shortPressDrag = { duration: this.touchSettings.shortPressDrag.duration, action: a, speed: this.touchSettings.shortPressDrag.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'long-press-drag:action') {
          this.buildTouchActionPopup(LONG_PRESS_DRAG_ACTIONS, this.touchSettings.longPressDrag.action, (a: TouchAction) => { this.touchSettings.longPressDrag = { duration: this.touchSettings.longPressDrag.duration, action: a, speed: this.touchSettings.longPressDrag.speed }; this.saveTouchSettings(); this.initTouchInteractionManager(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'two-finger-pinch:action') {
          this.buildTouchActionPopup(TWO_FINGER_PINCH_ACTIONS, this.touchSettings.twoFingerPinch.action, (a: TouchAction) => { this.touchSettings.twoFingerPinch = { duration: this.touchSettings.twoFingerPinch.duration, action: a, speed: 1 }; this.saveTouchSettings(); this.touchPopupId = ''; });
        } else if (this.touchPopupId === 'two-finger-pan:action') {
          this.buildTouchActionPopup(TWO_FINGER_PAN_ACTIONS, this.touchSettings.twoFingerPan.action, (a: TouchAction) => { this.touchSettings.twoFingerPan = { duration: this.touchSettings.twoFingerPan.duration, action: a, speed: 1 }; this.saveTouchSettings(); this.touchPopupId = ''; });
        }
      }
      .onClick(() => {});
    }
  }

  @Builder
  private buildTouchDualSliderPopup(duration: number, speed: number, onDurationChange: (v: number) => void, onSpeedChange: (v: number) => void) {
    Column({ space: 10 }) {
      Row() {
        Text(this.lt('Duration'))
          .fontSize(12)
          .fontColor(this.theme_TEXT_SECONDARY)
          .layoutWeight(1);
        Text(`${this.touchPopupDurVal}ms`)
          .fontSize(12)
          .fontColor(this.theme_ACCENT);
      }
      .width('100%');

      Slider({ value: this.touchPopupDurVal, min: 100, max: 2000, step: 50, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.theme_ACCENT)
        .onChange((v: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) { this.touchPopupDurVal = Math.round(v); onDurationChange(Math.round(v)); }
        });

      Row() {
        Text(this.lt('Speed'))
          .fontSize(12)
          .fontColor(this.theme_TEXT_SECONDARY)
          .layoutWeight(1);
        Text(`${this.touchPopupSpdVal}x`)
          .fontSize(12)
          .fontColor(this.theme_ACCENT);
      }
      .width('100%');

      Slider({ value: this.touchPopupSpdVal, min: 1, max: 20, step: 1, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.theme_ACCENT)
        .onChange((v: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) { this.touchPopupSpdVal = Math.round(v); onSpeedChange(Math.round(v)); }
        });
    }
    .width(260)
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.theme_MENU_BG)
    .border({ width: 1, color: this.theme_BORDER_SOFT })
    .shadow({ radius: 12, color: '#60000000', offsetY: -2 });
  }
  @Builder
  private buildTouchSliderPopup(value: number, min: number, max: number, step: number, onChange: (v: number) => void, unit: string = 'ms') {
    Column({ space: 8 }) {
      Row() {
        Text(unit === 'ms' ? this.lt('Duration') : this.lt('Speed'))
          .fontSize(12)
          .fontColor(this.theme_TEXT_SECONDARY)
          .layoutWeight(1);
        Text(`${this.touchPopupDurVal}${unit}`)
          .fontSize(12)
          .fontColor(this.theme_ACCENT);
      }
      .width('100%');

      Slider({ value: this.touchPopupDurVal, min: min, max: max, step: step, style: SliderStyle.OutSet })
        .width('100%')
        .selectedColor(this.theme_ACCENT)
        .onChange((v: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) { this.touchPopupDurVal = Math.round(v); onChange(Math.round(v)); }
        });
    }
    .width(260)
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.theme_MENU_BG)
    .border({ width: 1, color: this.theme_BORDER_SOFT })
    .shadow({ radius: 12, color: '#60000000', offsetY: -2 });
  }

  @Builder
  private buildTouchActionPopup(actions: TouchAction[], currentAction: TouchAction, onSelect: (a: TouchAction) => void) {
    Column({ space: 0 }) {
      ForEach(actions, (action: TouchAction) => {
        Row() {
          Text(this.getTouchActionLabel(action))
            .fontSize(12)
            .fontColor(action === currentAction ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
            .layoutWeight(1);
          if (action === currentAction) {
            Image($rawfile('checkbox-checked.svg'))
              .width(14)
              .height(14)
              .colorFilter(createStrokeIconColorFilter(this.theme_ACCENT));
          } else {
            Image($rawfile('checkbox-unchecked.svg'))
              .width(14)
              .height(14)
              .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY));
          }
        }
        .width('100%')
        .height(34)
        .padding({ left: 12, right: 12 })
        .onClick(() => { onSelect(action); });
      }, (action: TouchAction) => action)
    }
    .width(200)
    .borderRadius(12)
    .backgroundColor(this.theme_MENU_BG)
    .border({ width: 1, color: this.theme_BORDER_SOFT })
    .shadow({ radius: 12, color: '#60000000', offsetY: -2 });
  }

  private getTouchActionLabel(action: TouchAction): string {
    const labels: Record<string, string> = {
      'none': this.lt('None'),
      'left-click': this.lt('Left Click'),
      'left-double-click': this.lt('Double Click'),
      'right-click': this.lt('Right Click'),
      'middle-click': this.lt('Middle Click'),
      'screen-pan': this.lt('Screen Pan'),
      'screen-scroll': this.lt('Scroll'),
      'marquee-select': this.lt('Marquee Select'),
      'left-drag': this.lt('Left Drag'),
      'zoom': this.lt('Zoom'),
    };
    return labels[action] ?? action;
  }

  @Builder
  private buildChatModeMenuPanel() {
    Column() {
      this.buildSessionPanelHeader(this.lt('Chat'), 'chat-mode');
      this.buildMenuRow(
        this.voiceCallActive ? this.lt('Stop Voice Chat') : this.lt('Voice Chat'),
        () => { this.openVoiceChatMode(); },
        false,
        'opt_mic.svg'
      );
      this.buildMenuRow(
        this.lt('Text Chat'),
        () => { this.openSessionChatPanel(); },
        false,
        'chat.svg'
      );
    }
    .width(210)
    .borderRadius(16)
    .backgroundColor(this.theme_MENU_BG)
    .shadow({ radius: 16, color: '#40000000', offsetY: -4 });
  }

  @Builder
  private buildMoreMenuPanel() {
    Column() {
      this.buildSessionPanelHeader(this.lt('More Actions'), 'more');

      Scroll() {
        Column({ space: 0 }) {
          this.buildMenuRow(this.lt('OS Password'), () => { this.showMoreMenu = false; const peerId = this.deviceId.trim(); this.osPassword = peerId.length > 0 ? (PreferenceStore.getPeerOsPassword(peerId) ?? '') : ''; this.showOsPasswordDialog = true; }, false, 'menu_key.svg');
          this.buildMenuRow(this.lt('Send Clipboard Keys'), () => { this.showMoreMenu = false; this.sendClipboardToRemote(); }, false, 'menu_clipboard.svg');
          this.buildMenuRow(this.lt('Reset Canvas'), () => { this.showMoreMenu = false; this.pinchScale = 1; this.panOffsetX = 0; this.panOffsetY = 0; void this.showToast(this.lt('Reset')); }, false, 'menu_reset.svg');
          this.buildMenuRow(this.lt('Insert Ctrl+Alt+Del'), () => { this.showMoreMenu = false; if (this.sendCtrlAltDel()) { void this.showToast(this.lt('Inserted Ctrl+Alt+Del')); } }, false, 'menu_key.svg');
          this.buildMenuRow(this.lt('Restart Remote'), () => { this.showMoreMenu = false; this.sendSessionAction('restart'); }, false, 'menu_restart.svg');
          this.buildMenuRow(this.lt('Lock Remote'), () => { this.showMoreMenu = false; this.sendSessionAction('lock_screen'); }, false, 'menu_lock.svg');
          this.buildToggleMenuRow(this.lt('Block User Input'), this.blockInputOn, () => { this.showMoreMenu = false; this.toggleBlockInput(); }, 'menu_block.svg');
          this.buildMenuRow(this.lt('Refresh Screen'), () => { this.showMoreMenu = false; this.maybeRequestVideoRefresh(true); void this.showToast(this.lt('Refreshing...')); }, false, 'menu_refresh.svg');
          this.buildMenuRow(this.lt('File Transfer'), () => { this.showMoreMenu = false; void this.openFileTransferWithPermissionCheck(); }, true, 'menu_transfer.svg');
          this.buildMenuRow(this.lt('Copy Fingerprint'), () => { this.showMoreMenu = false; this.copyFingerprint(); }, false, 'menu_fingerprint.svg');
          this.buildMenuRow(this.lt('Switch Sides'), () => { this.showMoreMenu = false; this.switchSessionSides(); }, false, 'menu_switch.svg');
          this.buildMenuRow(this.lt('Take Screenshot'), () => { this.showMoreMenu = false; this.takeSessionScreenshot(); }, false, 'menu_screenshot.svg');
          this.buildToggleMenuRow(this.lt('Session Recording'), this.sessionRecording, () => { this.showMoreMenu = false; this.toggleSessionRecording(); }, 'menu_record.svg');
        }
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ maxHeight: 520 });
    }
    .width(210)
    .borderRadius(16)
    .backgroundColor(this.theme_MENU_BG)
    .shadow({ radius: 16, color: '#40000000', offsetY: -4 });
  }

  @Builder
  private buildFloatingChatPanel() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Text(this.deviceName.length > 0 ? this.deviceName : this.lt('Chat'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme_TEXT_PRIMARY)
            .layoutWeight(1);
          Image($rawfile('close.svg'))
            .width(18)
            .height(18)
            .fillColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showChatPanel = false;
            });
        }
        .width('100%')
        .height(36)
        .padding({ left: 12, right: 12 });

        Scroll(this.chatPanelScroller) {
          Column({ space: 10 }) {
            if (this.chatMessages.length === 0) {
              EmptyState($rawfile('chat.svg'), this.lt('No messages yet.'))
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
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Row({ space: 8 }) {
          TextInput({ placeholder: this.lt('Input message'), text: this.chatDraft })
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .fontColor(this.theme_TEXT_PRIMARY)
            .placeholderColor(this.theme_TEXT_TERTIARY)
            .backgroundColor(this.theme_PANEL_BG)
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.chatDraft = value;
            })
          Button(this.lt('Send'))
            .width(72)
            .height(40)
            .fontSize(14)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .borderRadius(10)
            .onClick(() => {
              void this.sendSessionChatMessage();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#B0000000')
      .borderRadius(14)

      Row() {
        Column()
      }
      .width(20)
      .height(20)
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Bottom)
      .hitTestBehavior(HitTestMode.Transparent)
      .gesture(
        PanGesture()
          .onActionStart((event: GestureEvent) => {
            this.chatPanelResizeStartX = event.offsetX;
            this.chatPanelResizeStartY = event.offsetY;
            this.chatPanelResizeStartWidth = this.chatPanelWidth;
            this.chatPanelResizeStartHeight = this.chatPanelHeight;
          })
          .onActionUpdate((event: GestureEvent) => {
            const dx = event.offsetX - this.chatPanelResizeStartX;
            const dy = event.offsetY - this.chatPanelResizeStartY;
            this.chatPanelWidth = Math.max(144, Math.min(420, this.chatPanelResizeStartWidth + dx));
            this.chatPanelHeight = Math.max(187, Math.min(640, this.chatPanelResizeStartHeight + dy));
          })
      )
    }
    .width(this.chatPanelWidth)
    .height(this.chatPanelHeight)
    .shadow({ radius: 18, color: '#50000000', offsetY: 4 })
    .gesture(
      PanGesture()
        .onActionStart((event: GestureEvent) => {
          this.chatPanelDragStartX = event.offsetX;
          this.chatPanelDragStartY = event.offsetY;
          this.chatPanelDragStartOffsetX = this.chatPanelOffsetX;
          this.chatPanelDragStartOffsetY = this.chatPanelOffsetY;
        })
        .onActionUpdate((event: GestureEvent) => {
          this.chatPanelOffsetX = this.chatPanelDragStartOffsetX + (event.offsetX - this.chatPanelDragStartX);
          this.chatPanelOffsetY = this.chatPanelDragStartOffsetY + (event.offsetY - this.chatPanelDragStartY);
        })
    )
    .position({ x: this.chatPanelOffsetX, y: this.chatPanelOffsetY })
  }

  @Builder
  private buildChatMessageBubble(message: ChatMessage, isLocal: boolean) {
    Column({ space: 4 }) {
      Text(this.getChatMessageBody(message))
        .fontSize(14)
        .fontColor(isLocal ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .backgroundColor(isLocal ? this.theme_ACCENT : this.theme_PANEL_BG)
    .borderRadius(12)
    .constraintSize({ maxWidth: '78%' })
  }

  @Builder
  private buildSessionPanelHeader(title: string, panel: string, headerAction?: PanelHeaderAction) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1);
      if (headerAction) {
        if (headerAction.isStroke) {
          Image($rawfile(headerAction.icon))
            .width(18)
            .height(18)
            .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
            .onClick(() => headerAction.action());
        } else {
          Image($rawfile(headerAction.icon))
            .width(18)
            .height(18)
            .fillColor(this.theme_TEXT_TERTIARY)
            .onClick(() => headerAction.action());
        }
      }
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 });
  }

  private closeSessionPanel(panel: string): void {
    if (panel === 'display') {
      this.showDisplayMenu = false;
    } else if (panel === 'mouse') {
      this.showMouseModeMenu = false;
    } else if (panel === 'more') {
      this.showMoreMenu = false;
    } else if (panel === 'chat-mode') {
      this.showChatModeMenu = false;
    } else if (panel === 'chat') {
      this.showChatPanel = false;
    }
  }

  @Builder
  private buildMenuRow(label: string, action: () => void, showArrow: boolean = false, icon: string = '') {
    Row({ space: 10 }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Text(label)
        .fontSize(14)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      if (showArrow) {
        Image($rawfile('arrow-forward-ios.svg'))
          .width(16)
          .height(16)
          .fillColor(this.theme_TEXT_TERTIARY)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .onClick(action);
  }

  @Builder
  private buildToggleMenuRow(label: string, isOn: boolean, action: () => void, icon: string = '') {
    Row({ space: 10 }) {
      if (icon.length > 0) {
        Image($rawfile(icon))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Text(label)
        .fontSize(14)
        .fontColor(isOn ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1)

      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(isOn ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
          .strokeWidth(2)

        if (isOn) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.theme_ACCENT)
        }
      }
      .width(20)
      .height(20)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(action);
  }

  @Builder
  private buildPasswordAssist() {
    Column({ space: 10 }) {
      Text(this.lt('If remote requires RustDesk password, you can submit here; or save the password for next auto-fill.'))
        .fontSize(13)
        .fontColor(this.theme_TEXT_TERTIARY);

      TextInput({ placeholder: this.lt('Enter RustDesk password'), text: this.sessionPassword })
        .height(42)
        .fontSize(15)
        .fontColor(this.theme_CONTRAST_TEXT)
        .backgroundColor(this.theme_TOOLBAR_BG)
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .type(InputType.Password)
        .defaultFocus(true)
        .onChange((value: string) => {
          this.sessionPassword = value;
        })


      Row({ space: 10 }) {
        Button(this.lt('Save password'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.theme_CONTRAST_TEXT)
          .backgroundColor(this.theme_INACTIVE_BG)
          .borderRadius(8)
          .onClick(() => {
            this.savePeerPassword();
          });

        Button(this.isSubmittingPassword ? this.lt('Submitting...') : this.lt('Submit password'))
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor(this.theme_ACCENT_TEXT)
          .backgroundColor(this.theme_ACCENT)
          .borderRadius(8)
          .onClick(() => {
            this.submitSessionPassword();
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.theme_PANEL_BG)
    .border({ width: { top: 1 }, color: this.theme_BORDER_SUBTLE });
  }

  @Builder
  private buildOsPasswordDialog() {
    Column() {
      Column({ space: 20 }) {
        Text(this.lt('OS Password'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        TextInput({ placeholder: this.lt('Enter Password'), text: this.osPassword })
          .height(48)
          .fontSize(16)
          .fontColor(this.theme_TEXT_PRIMARY)
          .backgroundColor(this.theme_INACTIVE_BG)
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .type(InputType.Password)
          .defaultFocus(true)
          .onChange((value: string) => {
            this.osPassword = value;
          })

        Row() {
          Checkbox()
            .select(this.osAutoLogin)
            .onChange((checked: boolean) => {
              this.osAutoLogin = checked;
            })
            .width(18)
            .height(18)

          Text(this.lt('Auto login (effective only when lock after disconnect is set)'))
            .fontSize(13)
            .fontColor(this.theme_TEXT_SECONDARY)
            .margin({ left: 8 })
        }
        .width('100%')
        .onClick(() => {
          this.osAutoLogin = !this.osAutoLogin;
        })

        Row({ space: 12 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INACTIVE_BG)
            .borderRadius(8)
            .onClick(() => {
              this.showOsPasswordDialog = false;
              this.osPassword = '';
            })

          Button(this.lt('Confirm'))
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              this.showOsPasswordDialog = false;
              const password = this.osPassword.trim();
              this.osPassword = '';
              if (password.length > 0) {
                const peerId = this.deviceId.trim();
                if (peerId.length > 0) {
                  PreferenceStore.setPeerOsPassword(peerId, password);
                }
                NativeRustDeskBridge.sessionInputOsPassword(password);
              }
            })
        }
        .width('100%')
      }
      .width('85%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 })
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
    });
  }

  @Builder
  private buildReconnectDialog() {
    Column() {
      Column({ space: 18 }) {
        Text(this.reconnectDialogTitle.length > 0 ? this.reconnectDialogTitle : this.lt('Connection Error'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY);

        Text(this.reconnectDialogText.length > 0 ? this.reconnectDialogText : this.lt('Session ended'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_SECONDARY);

        Row({ space: 10 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(36)
            .fontSize(15)
            .fontColor(this.theme_TEXT_PRIMARY)
            .backgroundColor(this.theme_INACTIVE_BG)
            .borderRadius(8)
            .onClick(() => {
              this.cancelReconnectDialog();
            });

          if (this.reconnectDialogCanRelay) {
            Button(this.lt('Relay'))
              .layoutWeight(1)
              .height(36)
              .fontSize(15)
              .fontColor(this.theme_TEXT_PRIMARY)
              .backgroundColor(this.theme_INACTIVE_BG)
              .borderRadius(8)
              .onClick(() => {
                void this.retrySessionConnection(true);
              });
          }

          Button(this.isRetryingConnection ? this.lt('Connecting...') : this.lt('Retry'))
            .layoutWeight(1)
            .height(36)
            .fontSize(15)
            .fontColor(this.theme_ACCENT_TEXT)
            .backgroundColor(this.theme_ACCENT)
            .borderRadius(8)
            .onClick(() => {
              void this.retrySessionConnection(false);
            });
        }
        .width('100%');
      }
      .width('88%')
      .padding(24)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(16)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .shadow({ radius: 20, color: this.theme_SHADOW_COLOR, offsetX: 0, offsetY: 4 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .justifyContent(FlexAlign.Center);
  }

  private closeSession(): void {
    if (this.sessionExitScheduled) {
      return;
    }
    this.sessionCloseRequestedLocally = true;
    this.showReconnectDialog = false;
    this.isRetryingConnection = false;
    this.showDisplayMenu = false;
    this.showMouseModeMenu = false;
    this.showChatModeMenu = false;
    this.showMoreMenu = false;
    this.showChatPanel = false;
    this.showOsPasswordDialog = false;
    this.setConnectionInfoVisible(false);
    console.warn(`[RemoteControl] closeSession: setting sessionCloseRequestedLocally=true`);
    const wasSessionActive = this.isConnected || this.sessionBecameActive || this.hasReceivedFrame;
    this.isConnected = false;
    this.hasReceivedFrame = false;
    this.sessionBecameActive = false;
    this.isSubmittingPassword = false;
    this.statusText = this.lt('Session closed');
    this.videoStatus = this.lt('Disconnecting...');
    if (this.isLandscapeMode !== this.originalLandscapeMode) {
      this.isLandscapeMode = this.originalLandscapeMode;
      WindowChromeService.getInstance().setLandscape(this.originalLandscapeMode);
    }
    if (this.lockAfterSession && wasSessionActive) {
      NativeRustDeskBridge.lockRemoteScreen();
    }
    this.officialBridge.requestSessionClose();
    this.scheduleSessionExit(160);
  }

  private handleImeProxyTextChange(value: string): void {
    const previous = this.imeProxyPrev;
    const SENTINEL = ' ';
    console.error(`[IME] onChange: prev="${previous}" value="${value}" cur="${this.imeProxyText}"`);
    if (value === previous) {
      return;
    }
    if (value.length === 0) {
      const realPrev = previous.startsWith(SENTINEL) ? previous.slice(1) : previous;
      const backspaceCount = Math.max(realPrev.length, 1);
      console.error(`[IME] sentinel deleted, sending ${backspaceCount} Backspace (realPrev="${realPrev}")`);
      this.sendBackspacePayload(backspaceCount);
      this.imeProxyPrev = SENTINEL;
      this.imeProxyText = SENTINEL;
      try { this.imeProxyController.caretPosition(1); } catch (e) { console.warn('caretPosition failed: ' + JSON.stringify(e)); }
      this.maybeRequestVideoRefresh(true);
      return;
    }
    const realPrev = previous.startsWith(SENTINEL) ? previous.slice(1) : previous;
    const realVal = value.startsWith(SENTINEL) ? value.slice(1) : value;
    console.error(`[IME] realPrev="${realPrev}" realVal="${realVal}"`);
    if (realVal === realPrev) {
      this.imeProxyPrev = value;
      return;
    }
    const commonPrefixLength = this.resolveCommonPrefixLength(realPrev, realVal);
    const removedCount = realPrev.length - commonPrefixLength;
    const insertedText = realVal.slice(commonPrefixLength);
    const autoPairOpening = removedCount === 0 ? this.resolveAutoPairOpening(insertedText) : '';
    if (autoPairOpening.length > 0) {
      this.sendImeCommittedText(autoPairOpening);
      this.restoreImeProxySentinel();
      this.maybeRequestVideoRefresh(true);
      return;
    }
    const isAutoCompletionDeletion = realVal.length < realPrev.length
      && insertedText.length > 0
      && realPrev.endsWith(insertedText);
    console.error(`[IME] diff: removed=${removedCount} inserted="${insertedText}" autoComp=${isAutoCompletionDeletion}`);
    if (isAutoCompletionDeletion) {
      const actualRemoved = realPrev.length - realVal.length;
      this.sendBackspacePayload(actualRemoved);
    } else {
      if (removedCount > 0) {
        this.sendBackspacePayload(removedCount);
      }
      if (insertedText.length > 0) {
        this.sendImeCommittedText(insertedText);
      }
    }
    this.imeProxyPrev = value;
    this.maybeRequestVideoRefresh(true);
  }

  private resolveAutoPairOpening(insertedText: string): string {
    const autoPairs: string[] = ['()', '[]', '{}', '<>', '（）', '［］', '【】', '《》', '〈〉', '「」', '『』'];
    for (const pair of autoPairs) {
      if (insertedText === pair) {
        return pair.slice(0, 1);
      }
    }
    return '';
  }

  private restoreImeProxySentinel(): void {
    const sentinel = ' ';
    this.imeProxyPrev = sentinel;
    this.imeProxyText = sentinel;
    setTimeout(() => {
      try {
        this.imeProxyController.caretPosition(1);
      } catch (error) {
        console.warn('caretPosition failed: ' + JSON.stringify(error));
      }
    }, 0);
  }

  private resolveCommonPrefixLength(left: string, right: string): number {
    const maxLength = Math.min(left.length, right.length);
    for (let index = 0; index < maxLength; index += 1) {
      if (left[index] !== right[index]) {
        return index;
      }
    }
    return maxLength;
  }

  private sendTextPayload(text: string): void {
    const stickyModifiers = this.buildModifierMask();
    for (let i = 0; i < text.length; i += 1) {
      const code = text.charCodeAt(i);
      const keyStroke = this.resolveAsciiKeyStroke(code);
      if (keyStroke[0] <= 0) {
        continue;
      }
      const vk = keyStroke[0];
      const modifiers = stickyModifiers | keyStroke[1];
      NativeRustDeskBridge.sendKeyboardInput(vk, true, modifiers);
      NativeRustDeskBridge.sendKeyboardInput(vk, false, modifiers);
    }
    if (stickyModifiers !== 0) {
      this.releaseAllStickyKeys();
    }
  }

  private sendImeCommittedText(text: string): void {
    if (this.isAlphanumericText(text) || (this.buildModifierMask() !== 0 && this.isAsciiKeyboardText(text))) {
      this.sendTextPayload(text);
      return;
    }
    NativeRustDeskBridge.sessionInputString(text);
  }

  private isAsciiKeyboardText(text: string): boolean {
    for (let index = 0; index < text.length; index += 1) {
      const code = text.charCodeAt(index);
      if (code < 32 || code > 126) {
        return false;
      }
    }
    return text.length > 0;
  }

  private resolveAsciiKeyStroke(code: number): number[] {
    if (code >= 97 && code <= 122) return [code - 32, 0];
    if (code >= 65 && code <= 90) return [code, 4];
    if (code >= 48 && code <= 57) return [code, 0];
    if (code === 32) return [32, 0];
    const plainCodes: number[] = [186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222];
    const plainChars: string = ';=,-./`[\\]\'';
    const plainIndex = plainChars.indexOf(String.fromCharCode(code));
    if (plainIndex >= 0) return [plainCodes[plainIndex], 0];
    const shiftedCodes: number[] = [49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222];
    const shiftedChars: string = '!@#$%^&*():+<_>?~{|}"';
    const shiftedIndex = shiftedChars.indexOf(String.fromCharCode(code));
    if (shiftedIndex >= 0) return [shiftedCodes[shiftedIndex], 4];
    return [0, 0];
  }

  private isAlphanumericText(text: string): boolean {
    for (let index = 0; index < text.length; index += 1) {
      const code = text.charCodeAt(index);
      if (!((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122))) {
        return false;
      }
    }
    return true;
  }

  private sendPasteShortcut(): void {
    NativeRustDeskBridge.sendKeyboardInput(86, true, 2);
    NativeRustDeskBridge.sendKeyboardInput(86, false, 2);
  }

  private sendBackspacePayload(count: number): void {
    for (let index = 0; index < count; index += 1) {
      NativeRustDeskBridge.sendKeyboardInput(8, true, 0);
      NativeRustDeskBridge.sendKeyboardInput(8, false, 0);
    }
  }

  private sendEnterKey(): void {
    NativeRustDeskBridge.sendKeyboardInput(13, true, 0);
    NativeRustDeskBridge.sendKeyboardInput(13, false, 0);
    this.maybeRequestVideoRefresh(true);
  }

  private sendSpecialKey(key: string): void {
    if (key === 'Ctrl') {
      if (this.stickyCtrl) {
        this.stickyCtrl = false;
        NativeRustDeskBridge.sendKeyboardInput(17, false, 0);
      } else {
        this.stickyCtrl = true;
        NativeRustDeskBridge.sendKeyboardInput(17, true, 0);
      }
      this.maybeRequestVideoRefresh(true);
      return;
    }
    if (key === 'Alt') {
      if (this.stickyAlt) {
        this.stickyAlt = false;
        NativeRustDeskBridge.sendKeyboardInput(18, false, 0);
      } else {
        this.stickyAlt = true;
        NativeRustDeskBridge.sendKeyboardInput(18, true, 0);
      }
      this.maybeRequestVideoRefresh(true);
      return;
    }
    if (key === 'Shift') {
      if (this.stickyShift) {
        this.stickyShift = false;
        NativeRustDeskBridge.sendKeyboardInput(16, false, 0);
      } else {
        this.stickyShift = true;
        NativeRustDeskBridge.sendKeyboardInput(16, true, 0);
      }
      this.maybeRequestVideoRefresh(true);
      return;
    }
    if (key === 'Fn') {
      this.stickyFn = !this.stickyFn;
      this.maybeRequestVideoRefresh(true);
      return;
    }
    const specialKeys: Record<string, number> = {
      'Enter': 13,
      'Backspace': 8,
      '⌫': 8,
      'Tab': 9,
      'Esc': 27,
      'Del': 46,
      '←': 37,
      '↑': 38,
      '→': 39,
      '↓': 40,
      'Left': 37,
      'Up': 38,
      'Right': 39,
      'Down': 40,
      'Home': 36,
      'End': 35,
      'Ins': 45,
      'PgUp': 33,
      'PgDn': 34,
      'PrtScr': 44,
      'Menu': 93,
      'Win': 91,
      'win': 91,
      'F1': 112,
      'F2': 113,
      'F3': 114,
      'F4': 115,
      'F5': 116,
      'F6': 117,
      'F7': 118,
      'F8': 119,
      'F9': 120,
      'F10': 121,
      'F11': 122,
      'F12': 123
    };
    const code = specialKeys[key] ?? 0;
    if (code > 0) {
      const modifiers = this.buildModifierMask();
      NativeRustDeskBridge.sendKeyboardInput(code, true, modifiers);
      NativeRustDeskBridge.sendKeyboardInput(code, false, modifiers);
      this.releaseAllStickyKeys();
      this.maybeRequestVideoRefresh(true);
    }
  }

  private buildModifierMask(): number {
    let mask = 0;
    if (this.stickyCtrl) mask |= 1;
    if (this.stickyAlt) mask |= 2;
    if (this.stickyShift) mask |= 4;
    return mask;
  }

  private releaseAllStickyKeys(): void {
    if (this.stickyCtrl) { this.stickyCtrl = false; NativeRustDeskBridge.sendKeyboardInput(17, false, 0); }
    if (this.stickyAlt) { this.stickyAlt = false; NativeRustDeskBridge.sendKeyboardInput(18, false, 0); }
    if (this.stickyShift) { this.stickyShift = false; NativeRustDeskBridge.sendKeyboardInput(16, false, 0); }
    this.stickyFn = false;
  }

  private sendCtrlAltDel(): boolean {
    if (!NativeRustDeskBridge.sendCtrlAltDel()) {
      void this.showToast(this.lt('In development'));
      return false;
    }
    this.maybeRequestVideoRefresh(true);
    return true;
  }

  private applySessionOption(key: string, value: string): boolean {
    const applied = NativeRustDeskBridge.applySessionOption(key, value);
    if (!applied) {
      NativeRustDeskBridge.setLocalOption(key, value);
      return false;
    }
    NativeRustDeskBridge.setLocalOption(key, value);
    return true;
  }

  private applyImageQuality(mode: number): void {
    this.imageQualityMode = mode;
    const qualityMap: Record<number, string> = { 0: 'best', 1: 'balanced', 2: 'low', 3: 'custom' };
    this.applySessionOption('image-quality', qualityMap[mode] ?? 'balanced');
    if (mode === 3) {
      this.showCustomQualityPanel = true;
      this.applySessionOption('custom-image-quality', String(this.customBitrate));
    } else {
      this.showCustomQualityPanel = false;
    }
  }

  private resolveDisplayScaleModeLabel(): string {
    if (this.displayScaleMode === 0) {
      return this.lt('Original Size');
    }
    if (this.displayScaleMode === 2) {
      return this.lt('Custom Zoom');
    }
    return this.lt('Fit Window');
  }

  private applyDisplayScaleMode(mode: number): void {
    this.displayScaleMode = Math.max(0, Math.min(2, mode));
    this.zoomLevelIndex = 0;
    this.pinchScale = this.displayScaleMode === 2 ? this.customZoomPercent / 100 : 1;
    this.lastPinchScale = this.pinchScale;
    this.panOffsetX = 0;
    this.panOffsetY = 0;
    const modeValues: Record<number, string> = { 0: 'original', 1: 'fit', 2: 'custom' };
    NativeRustDeskBridge.setLocalOption('display-scale-mode', modeValues[this.displayScaleMode] ?? 'fit');
  }

  private resolveVideoCodecLabel(): string {
    const labels: Record<number, string> = { 0: 'Auto', 1: 'VP8', 2: 'VP9', 3: 'AV1', 4: 'H264', 5: 'H265' };
    return labels[this.videoCodecMode] ?? 'Auto';
  }

  private applyVideoCodec(mode: number): void {
    const codecMap: Record<number, string> = { 0: 'auto', 1: 'vp8', 2: 'vp9', 3: 'av1', 4: 'h264', 5: 'h265' };
    const codec = codecMap[mode] ?? 'auto';
    if (!this.applySessionOption('codec-preference', codec)) {
      void this.showToast(this.lt('In development'));
      return;
    }
    this.videoCodecMode = mode;
    this.maybeRequestVideoRefresh(true);
  }

  private applyToggleOption(key: string, enabled: boolean): boolean {
    return this.applySessionOption(key, enabled ? 'Y' : 'N');
  }

  private toggleClipboardSync(): void {
    const next = !this.disableClipboard;
    if (!this.applyToggleOption('disable-clipboard', next)) {
      void this.showToast(this.lt('In development'));
      return;
    }
    this.disableClipboard = next;
    if (next) {
      ClipboardService.getInstance().stopMonitoring();
    } else {
      void ClipboardService.getInstance().startMonitoring();
    }
  }

  private sendSessionAction(action: string): void {
    let handled = false;
    if (action === 'restart') {
      handled = NativeRustDeskBridge.restartRemoteDevice();
    } else if (action === 'lock_screen') {
      handled = NativeRustDeskBridge.lockRemoteScreen();
    }
    if (!handled) {
      handled = NativeRustDeskBridge.applySessionOption('session-action', action);
    }
    void this.showToast(handled ? this.lt('Command Sent') : this.lt('In development'));
    this.maybeRequestVideoRefresh(true);
  }

  private switchSessionSides(): void {
    const handled = NativeRustDeskBridge.sessionSwitchSides();
    void this.showToast(handled ? this.lt('Command Sent') : this.lt('In development'));
    this.maybeRequestVideoRefresh(true);
  }

  private takeSessionScreenshot(): void {
    const handled = NativeRustDeskBridge.sessionTakeScreenshot(this.currentRemoteDisplay);
    void this.showToast(handled ? this.lt('Screenshot requested') : this.lt('In development'));
  }

  private toggleSessionRecording(): void {
    const start = !this.sessionRecording;
    const handled = NativeRustDeskBridge.sessionRecordScreen(start);
    if (handled) {
      this.sessionRecording = start;
    }
    void this.showToast(handled ? (start ? this.lt('Recording Started') : this.lt('Recording Stopped')) : this.lt('In development'));
  }

  private async openFileTransferWithPermissionCheck(): Promise<void> {
    this.navigateTo('pages/FileTransfer', this.buildSessionRouteParams());
  }

  private toggleBlockInput(): void {
    const next = !this.blockInputOn;
    if (this.applySessionOption('block-input', next ? 'Y' : 'N')) {
      void this.showToast(this.lt('Command Sent'));
    } else {
      void this.showToast(this.lt('In development'));
    }
  }

  private sendClipboardToRemote(): void {
    if (this.disableClipboard) {
      void this.showToast(this.lt('Clipboard sync disabled in this session'));
      return;
    }
    try {
      const clipboard = ClipboardService.getInstance();
      void clipboard.getClipboardContent().then((content: string) => {
        if (content.length > 0) {
          const sent = NativeRustDeskBridge.sendClipboardData(content, Date.now());
          if (sent) {
            this.maybeRequestVideoRefresh(true);
            void this.showToast(this.lt('Clipboard sent to remote'));
            return;
          }
          void this.showToast(this.lt('Failed to send clipboard'));
          return;
        }
        void this.showToast(this.lt('Local clipboard is empty'));
      }).catch((error: Object) => {
        console.warn('RemoteControl sendClipboardToRemote promise rejected: ' + JSON.stringify(error));
        void this.showToast(this.lt('Failed to read clipboard'));
      });
    } catch (error) {
      console.warn('RemoteControl sendClipboardToRemote failed: ' + JSON.stringify(error));
      void this.showToast(this.lt('Failed to read clipboard'));
    }
  }

  private copyFingerprint(): void {
    try {
      const coreState = this.officialBridge.getCoreState();
      const fp = this.remotePeerFingerprint.trim().length > 0
        ? this.remotePeerFingerprint.trim()
        : (coreState.fingerprint ?? '').trim();
      if (fp.length > 0) {
        void ClipboardService.getInstance().copyText(fp).then((success: boolean) => {
          void this.showToast(success ? this.lt('Fingerprint copied') : this.lt('Copy failed'));
        });
        return;
      }
      void this.showToast(this.lt('No fingerprint to copy'));
    } catch (error) {
      console.warn('RemoteControl copyFingerprint failed: ' + JSON.stringify(error));
      void this.showToast(this.lt('Copy failed'));
    }
  }

  private startBridgeRefresh(): void {
    if (this.bridgeRefreshTimer !== -1) {
      return;
    }
    this.bridgeRefreshTimer = setInterval(() => {
      void this.syncBridgeState();
    }, 1200);
  }

  private stopBridgeRefresh(): void {
    if (this.bridgeRefreshTimer === -1) {
      return;
    }
    clearInterval(this.bridgeRefreshTimer);
    this.bridgeRefreshTimer = -1;
  }

  private startFrameRefresh(): void {
    if (this.frameRefreshTimer !== -1) {
      return;
    }
    this.frameRefreshTimer = setInterval(() => {
      void this.refreshRenderedFrame();
      this.maybeRequestVideoRefresh(false);
      this.maybeAdvanceNativeFrame();
    }, 16);
  }

  private maybeAdvanceNativeFrame(): void {
    if (!this.isConnected || this.sessionExitScheduled) {
      return;
    }
    const now = Date.now();
    const staleMs = this.lastFrameUpdatedAt > 0 ? now - this.lastFrameUpdatedAt : 0;
    const shouldPrimeFirstFrame = !this.hasReceivedFrame;
    const shouldRecoverStaleFrame = this.hasReceivedFrame && staleMs > 200;
    if (!shouldPrimeFirstFrame && !shouldRecoverStaleFrame) {
      return;
    }
    if (now - this.lastNativeFrameAdvanceAt < this.nativeFrameAdvanceMinIntervalMs) {
      return;
    }
    this.advanceNativeFrame(this.currentRemoteDisplay, now);
  }

  private advanceNativeFrame(display: number, now: number = Date.now()): void {
    if (display < 0 || this.sessionExitScheduled) {
      return;
    }
    NativeRustDeskBridge.harmonyNextRgba(display);
    this.lastNativeFrameAdvanceAt = now;
  }

  private stopFrameRefresh(): void {
    if (this.frameRefreshTimer === -1) {
      return;
    }
    clearInterval(this.frameRefreshTimer);
    this.frameRefreshTimer = -1;
  }

  private startAudioFrameRefresh(): void {
    if (this.audioFrameRefreshTimer !== -1) {
      return;
    }
    this.audioFrameRefreshTimer = setInterval(() => {
      if (!this.remoteAudioEnabled || this.muteAudio) {
        return;
      }
      try {
        const audioFramesJson = NativeRustDeskBridge.pullAudioFrames();
        if (!audioFramesJson || audioFramesJson === '[]') {
          return;
        }
        const frames = JSON.parse(audioFramesJson) as AudioFrameData[];
        for (let i = 0; i < frames.length; i++) {
          const frame = frames[i];
          const pcmBuffer = base64ToArrayBuffer(frame.dataBase64);
          void this.playRemoteAudioFrame(pcmBuffer);
        }
      } catch (e) {
        console.warn('audio frame processing failed: ' + JSON.stringify(e));
      }
    }, 20);
  }

  private stopAudioFrameRefresh(): void {
    if (this.audioFrameRefreshTimer === -1) {
      return;
    }
    clearInterval(this.audioFrameRefreshTimer);
    this.audioFrameRefreshTimer = -1;
  }

  private async initAudioPlayback(): Promise<void> {
    try {
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };
      const audioRendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: 0
      };
      const audioRendererOptions: audio.AudioRendererOptions = {
        streamInfo: audioStreamInfo,
        rendererInfo: audioRendererInfo
      };
      this.audioRenderer = await audio.createAudioRenderer(audioRendererOptions);
      this.remoteAudioEnabled = true;
      console.log('[RemoteControl] Remote audio playback initialized');
    } catch (error) {
      console.error('[RemoteControl] Failed to init audio playback:', error);
      this.remoteAudioEnabled = false;
    }
  }

  private async cleanupAudioResources(): Promise<void> {
    try {
      if (this.audioService.isCapturingActive()) {
        await this.audioService.stopCapture();
      }
      if (this.audioRenderer) {
        try {
          const state = this.audioRenderer.state;
          if (state === audio.AudioState.STATE_RUNNING || state === audio.AudioState.STATE_PAUSED) {
            await this.audioRenderer.stop();
          }
        } catch (e) {
          console.warn('audioRenderer.stop failed: ' + JSON.stringify(e));
        }
        try {
          await this.audioRenderer.release();
        } catch (e) {
          console.warn('audioRenderer.release failed: ' + JSON.stringify(e));
        }
        this.audioRenderer = null;
      }
      this.remoteAudioEnabled = false;
      console.log('[RemoteControl] Audio resources cleaned up');
    } catch (error) {
      console.error('[RemoteControl] Failed to cleanup audio:', error);
    }
  }

  private async playRemoteAudioFrame(data: ArrayBuffer): Promise<void> {
    if (!this.audioRenderer || !this.remoteAudioEnabled || this.muteAudio) {
      return;
    }
    try {
      await this.audioRenderer.write(data);
    } catch (error) {
      console.warn('[RemoteControl] Failed to play audio frame:', error);
    }
  }

  private async syncBridgeState(): Promise<void> {
    if (this.sessionExitScheduled) {
      return;
    }
    const coreState = await this.officialBridge.refresh(this.settings);
    if (this.sessionExitScheduled) {
      return;
    }
    if (this.showReconnectDialog && coreState.sessionStage === 'connected') {
      if (!this.isRetryingConnection && !this.hasReceivedFrame) {
        console.warn('[RemoteControl] keeping reconnect dialog while native snapshot is connected without first frame');
        this.isConnected = false;
        return;
      }
      if (!this.sessionCloseRequestedLocally && !this.isRetryingConnection) {
        console.warn('[RemoteControl] keeping reconnect dialog - non-user disconnect with connected stage');
        this.isConnected = false;
        return;
      }
      console.warn('[RemoteControl] syncBridgeState: clearing reconnect dialog, isRetrying=%b closeRequested=%b', this.isRetryingConnection, this.sessionCloseRequestedLocally);
      this.showReconnectDialog = false;
      this.isConnected = true;
      this.sessionBecameActive = true;
      if (this.sessionBecameActiveAt <= 0) {
        this.sessionBecameActiveAt = Date.now();
      }
      if (!this.hasReceivedFrame) {
        this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connected');
        this.videoStatus = coreState.detailMessage.length > 0 ? coreState.detailMessage : this.lt('Session connected, waiting for first frame...');
      }
      this.startFrameRefresh();
      return;
    }
    if (this.showReconnectDialog) {
      return;
    }
    this.applyBridgeState(coreState);
    if (coreState.sessionStage === 'connected') {
      this.maybeHandleStaleConnectedSession(coreState);
      if (this.sessionExitScheduled) {
        return;
      }
      if (!this.hasReceivedFrame) {
        this.maybeRequestVideoRefresh(true);
      }
    }
  }

  private applyBridgeState(coreState: OfficialCoreState): void {
    hilog.error(0xA03D00, 'RC', `applyBridgeState stage=${coreState.sessionStage} showOsPwd=${this.showOsPasswordDialog} connected=${this.isConnected} hasFrame=${this.hasReceivedFrame} err=${coreState.lastError.substring(0, 60)}`);
    Logger.info('RC', `applyBridgeState stage=${coreState.sessionStage} connected=${this.isConnected} hasFrame=${this.hasReceivedFrame} activePeer=${coreState.activePeerId} detail=${coreState.detailMessage.substring(0, 80)}`);
    if (this.sessionExitScheduled) {
      return;
    }
    if (this.showReconnectDialog && coreState.sessionStage === 'connected') {
      if (!this.isRetryingConnection && !this.hasReceivedFrame) {
        console.warn('[RemoteControl] applyBridgeState kept reconnect dialog for connected-without-frame snapshot');
        this.isConnected = false;
        return;
      }
      if (!this.sessionCloseRequestedLocally && !this.isRetryingConnection) {
        console.warn('[RemoteControl] applyBridgeState kept reconnect dialog - non-user disconnect');
        this.isConnected = false;
        return;
      }
      this.showReconnectDialog = false;
      this.isConnected = true;
      this.sessionBecameActive = true;
      if (this.sessionBecameActiveAt <= 0) {
        this.sessionBecameActiveAt = Date.now();
      }
      if (!this.hasReceivedFrame) {
        this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connected');
        this.videoStatus = coreState.detailMessage.length > 0 ? coreState.detailMessage : this.lt('Session connected, waiting for first frame...');
      }
      return;
    }
    if (this.showReconnectDialog && coreState.sessionStage !== 'connecting') {
      return;
    }
    if (coreState.activePeerId.length > 0) {
      this.deviceId = coreState.activePeerId;
      this.deviceName = this.formatRemoteTitle(coreState.activePeerId);
    }

    if (coreState.sessionStage === 'connected') {
      this.sessionBecameActive = true;
      if (this.sessionBecameActiveAt <= 0) {
        this.sessionBecameActiveAt = Date.now();
      }
      this.sessionCloseRequestedLocally = false;
      this.showReconnectDialog = false;
      this.isConnected = true;
      this.isSubmittingPassword = false;
      if (!this.hasReceivedFrame) {
        this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connected');
        this.videoStatus = coreState.detailMessage.length > 0 ? coreState.detailMessage : this.lt('Session connected, waiting for first frame...');
      } else if (coreState.statusSummary.length > 0) {
        this.statusText = coreState.statusSummary;
      }
      return;
    }

    if (coreState.sessionStage === 'connecting') {
      this.isConnected = false;
      this.isSubmittingPassword = false;
      this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connecting...');
      this.videoStatus = coreState.detailMessage.length > 0 ? coreState.detailMessage : this.lt('Waiting for remote response...');
      return;
    }

    if (coreState.sessionStage === 'error') {
      const detail = coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage;
      const isPasswordPrompt = this.shouldPromptForPasswordText(detail);
      if (isPasswordPrompt && !this.hasReceivedFrame && !this.isConnected && !this.showReconnectDialog && !this.isRetryingConnection) {
        this.isConnected = false;
        this.isSubmittingPassword = false;
        if (detail.length > 0) {
          this.videoStatus = detail;
        }
        return;
      }
      if (!this.sessionCloseRequestedLocally && this.shouldShowReconnectPromptNow(detail)) {
        console.warn(`[RemoteControl] applyBridgeState terminal error -> reconnect prompt: ${detail.substring(0, 100)}`);
        this.showReconnectDialogFromState(
          coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connection Error'),
          detail
        );
        return;
      }
      if (this.showReconnectDialog) {
        this.isConnected = false;
        this.isSubmittingPassword = false;
        this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connection failed');
        this.videoStatus = detail;
        return;
      }
      if (!this.sessionCloseRequestedLocally && this.shouldAutoCloseTerminalSession()) {
        if (this.shouldShowReconnectPromptNow(detail)) {
          this.showReconnectDialogFromState(
            coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connection Error'),
            detail
          );
        } else {
          this.isConnected = false;
          this.isSubmittingPassword = false;
          this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connecting...');
          this.videoStatus = coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage;
        }
        return;
      }
      if (this.shouldAutoCloseTerminalSession()) {
        const statusText = this.sessionCloseRequestedLocally
          ? this.lt('Session closed')
          : (coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connection failed'));
        const videoStatus = this.sessionCloseRequestedLocally
          ? this.lt('Session ended')
          : (coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage);
        this.finishTerminalSession(statusText, videoStatus, this.sessionCloseRequestedLocally ? 160 : 420);
        return;
      }
      this.isConnected = false;
      this.isSubmittingPassword = false;
      this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connection failed');
      this.videoStatus = coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage;
      if (this.showConnectionInfo) {
        this.showConnectionInfo = false;
      }
      return;
    }

    if (coreState.sessionStage === 'idle' && this.shouldAutoCloseTerminalSession()) {
      if (this.showReconnectDialog) {
        return;
      }
      if (!this.sessionCloseRequestedLocally) {
        const detail = coreState.detailMessage.length > 0 ? coreState.detailMessage : coreState.lastError.length > 0 ? coreState.lastError : this.lt('Session ended');
        if (this.shouldPromptForPasswordText(detail) && !this.hasReceivedFrame && !this.isConnected && !this.showReconnectDialog && !this.isRetryingConnection) {
          this.isConnected = false;
          this.isSubmittingPassword = false;
          this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Connecting...');
          this.videoStatus = this.lt('Waiting for password...');
          return;
        }
        if (this.isRetryableDisconnectText(detail) ||
          (this.sessionBecameActive && !this.hasReceivedFrame) ||
          this.shouldShowReconnectPromptNow(detail)) {
          console.warn(`[RemoteControl] applyBridgeState idle -> reconnect prompt: ${detail.substring(0, 100)}`);
          this.showReconnectDialogFromState(this.lt('Connection Error'), detail);
          return;
        }
        this.finishTerminalSession(this.lt('Session closed'), detail, 420);
        return;
      }
      this.finishTerminalSession(
        this.lt('Session closed'),
        this.lt('Session ended'),
        this.sessionCloseRequestedLocally ? 160 : 420
      );
      return;
    }

    this.isConnected = false;
    this.isSubmittingPassword = false;
    this.statusText = coreState.statusSummary.length > 0 ? coreState.statusSummary : this.lt('Session closed');
    this.videoStatus = coreState.detailMessage.length > 0 ? coreState.detailMessage : this.lt('Session ended');
  }

  private async refreshRenderedFrame(): Promise<void> {
    if (this.frameRefreshInFlight || this.sessionExitScheduled) {
      return;
    }
    this.frameRefreshInFlight = true;
    try {
      const now = Date.now();
      const frameData = this.pullLatestRenderableFrame(now);
      if (frameData === null) {
        if (this.shouldTraceFramePull(now)) {
          const staleMs = this.lastFrameUpdatedAt > 0 ? now - this.lastFrameUpdatedAt : 0;
          console.log(
            `[RemoteControl] pullLatestVideoFrame null connected=${this.isConnected} hasFrame=${this.hasReceivedFrame} lastFrameId=${this.lastFrameId} staleMs=${staleMs}`
          );
        }
        if (this.isConnected && !this.hasReceivedFrame) {
          this.videoStatus = this.lt('Waiting for video...');
        }
        this.maybeHandleStaleConnectedSession(this.officialBridge.getCoreState(), now);
        return;
      }

      if (frameData.frameId <= this.lastFrameId) {
        if (this.shouldTraceFramePull(now)) {
          console.log(
            `[RemoteControl] pullLatestVideoFrame stale frameId=${frameData.frameId} lastFrameId=${this.lastFrameId} timestamp=${frameData.timestamp} bytes=${frameData.bytes}`
          );
        }
        return;
      }

      if (this.shouldTraceFramePull(now)) {
        const ageMs = frameData.timestamp > 0 ? Math.max(0, now - frameData.timestamp) : -1;
        console.log(
          `[RemoteControl] pullLatestVideoFrame new frameId=${frameData.frameId} prev=${this.lastFrameId} timestamp=${frameData.timestamp} ageMs=${ageMs} bytes=${frameData.bytes}`
        );
      }
      this.advanceNativeFrame(frameData.display);
      const renderGeneration = this.renderGeneration;
      const rendered = await this.updateRenderedFrameSurfaceAsync(frameData, renderGeneration);
      if (!rendered) {
        return;
      }
      this.lastFrameId = frameData.frameId;
      this.frameWidth = frameData.width;
      this.frameHeight = frameData.height;
      this.currentRemoteDisplay = frameData.display;
      if (this.remoteDisplayWidth <= 0 || this.remoteDisplayHeight <= 0) {
        this.remoteDisplayWidth = frameData.width;
        this.remoteDisplayHeight = frameData.height;
      }
      this.lastFrameUpdatedAt = Date.now();
      this.frameVersion += 1;
      const isFirstFrame = !this.hasReceivedFrame;
      this.hasReceivedFrame = true;
      this.sessionBecameActive = true;
      if (this.sessionBecameActiveAt <= 0) {
        this.sessionBecameActiveAt = Date.now();
      }
      this.isConnected = true;
      this.updateFps();
      if (isFirstFrame) {
        this.applySuggestedViewTransform(true);
      }
      this.statusText = this.lt('Connected');
      this.videoStatus = '';
      this.isSubmittingPassword = false;
    } catch (error) {
      console.error('[RemoteControl] Failed to create PixelMap:', JSON.stringify(error));
      this.videoStatus = this.lt('Render failed');
    } finally {
      this.frameRefreshInFlight = false;
    }
  }

  private pullLatestRenderableFrame(now: number): NativeVideoFrame | null {
    const directFrame = NativeRustDeskBridge.pullLatestVideoFrame(this.lastFrameId);
    if (directFrame !== null) {
      return directFrame;
    }
    if (!this.hasReceivedFrame || this.lastFrameId <= 0) {
      return null;
    }
    const staleMs = this.lastFrameUpdatedAt > 0 ? now - this.lastFrameUpdatedAt : 0;
    if (staleMs < 300) {
      return null;
    }
    const latestFrame = NativeRustDeskBridge.pullLatestVideoFrame(0);
    if (latestFrame === null) {
      return null;
    }
    if (latestFrame.frameId > this.lastFrameId) {
      console.warn(
        `[RemoteControl] pullLatestVideoFrame fallback frameId=0 recovered frameId=${latestFrame.frameId} prev=${this.lastFrameId} staleMs=${staleMs}`
      );
      return latestFrame;
    }
    return null;
  }

  private maybeRequestVideoRefresh(force: boolean): void {
    if (this.sessionExitScheduled) {
      return;
    }
    const now = Date.now();
    const staleMs = this.lastFrameUpdatedAt > 0 ? now - this.lastFrameUpdatedAt : 0;
    const waitingFirstFrame = !this.hasReceivedFrame;
    let minIntervalMs = 0;
    if (waitingFirstFrame) {
      minIntervalMs = force ? 450 : 900;
    } else if (force && staleMs > 800) {
      minIntervalMs = 600;
    } else if (!force && staleMs > 3000) {
      minIntervalMs = 1500;
      if (this.showConnectionInfo) {
        this.updateDisplayedFps(0, now);
      }
    } else {
      return;
    }
    if (now - this.lastVideoRefreshRequestAt < minIntervalMs) {
      return;
    }
    const result = NativeRustDeskBridge.refreshSessionVideo(this.currentRemoteDisplay);
    if (!result || waitingFirstFrame || staleMs > 1500 || force || now - this.lastRefreshTraceAt > 2000) {
      this.lastRefreshTraceAt = now;
      console.info(
        `[RemoteControl] requestVideoRefresh force=${force} connected=${this.isConnected} hasFrame=${this.hasReceivedFrame} display=${this.currentRemoteDisplay} staleMs=${staleMs} minInterval=${minIntervalMs} result=${result}`
      );
    }
    if (result) {
      this.lastVideoRefreshRequestAt = now;
    }
  }

  private shouldTraceFramePull(now: number): boolean {
    if (now - this.lastFramePullTraceAt < 1200) {
      return false;
    }
    this.lastFramePullTraceAt = now;
    return true;
  }

  private maybeHandleStaleConnectedSession(coreState: OfficialCoreState, now: number = Date.now()): void {
    if (this.sessionExitScheduled || this.sessionCloseRequestedLocally) {
      return;
    }
    if (coreState.sessionStage !== 'connected') {
      return;
    }
    if (!this.sessionBecameActive && !this.hasReceivedFrame) {
      return;
    }
    const lastObservedActivityAt = Math.max(
      this.lastBridgeActivityAt,
      this.lastFrameUpdatedAt,
      this.lastNonZeroFpsAt
    );
    if (lastObservedActivityAt <= 0) {
      return;
    }
    const staleMs = now - lastObservedActivityAt;
    if (staleMs < this.silentSessionTimeoutMs) {
      return;
    }
    const lastBridgeAgeMs = this.lastBridgeActivityAt > 0 ? now - this.lastBridgeActivityAt : -1;
    const lastFrameAgeMs = this.lastFrameUpdatedAt > 0 ? now - this.lastFrameUpdatedAt : -1;
    const lastFpsAgeMs = this.lastNonZeroFpsAt > 0 ? now - this.lastNonZeroFpsAt : -1;
    if (now - this.lastSilentSessionWarningAt > 1000) {
      this.lastSilentSessionWarningAt = now;
      console.warn(
        `[RemoteControl] session watchdog observed stale media peer=${coreState.activePeerId} staleMs=${staleMs} lastBridgeAgeMs=${lastBridgeAgeMs} lastFrameAgeMs=${lastFrameAgeMs} lastFpsAgeMs=${lastFpsAgeMs}`
      );
      this.videoStatus = this.lt('Waiting for video stream...');
      this.maybeRequestVideoRefresh(true);
    }
  }

  private captureBridgeEvent(event: OfficialSessionEvent): void {
    this.lastBridgeActivityAt = Date.now();
    if (event.kind === 'display') {
      const values = this.parseKeyValueDetail(event.detail);
      this.remoteDisplayOriginX = this.parseDetailNumber(values, 'x', this.remoteDisplayOriginX);
      this.remoteDisplayOriginY = this.parseDetailNumber(values, 'y', this.remoteDisplayOriginY);
      this.remoteDisplayWidth = this.parseDetailNumber(values, 'width', this.remoteDisplayWidth);
      this.remoteDisplayHeight = this.parseDetailNumber(values, 'height', this.remoteDisplayHeight);
      this.remoteDisplayScale = this.parseDetailFloat(values, 'scale', this.remoteDisplayScale);
      this.remoteCursorEmbedded = this.parseDetailBoolean(values, 'cursorEmbedded', this.remoteCursorEmbedded);
      if (this.remoteCursorEmbedded) {
        this.remoteCursorVisible = false;
      }
      this.applySuggestedViewTransform();
      return;
    }

    if (event.kind === 'switch-display' || event.kind === 'current-display') {
      const values = this.parseKeyValueDetail(event.detail);
      this.currentRemoteDisplay = this.parseDetailNumber(values, 'display', this.currentRemoteDisplay);
      if (event.kind === 'current-display') {
        this.currentRemoteDisplay = this.parseLooseNumber(event.detail, this.currentRemoteDisplay);
      }
      return;
    }

    if (event.kind === 'peer-info') {
      const values = this.parseKeyValueDetail(event.detail);
      this.peerPlatform = values['platform'] ?? this.peerPlatform;
      this.updateRecentSessionFromPeerInfoEvent(event.peerId, values);
      return;
    }

    if (event.kind === 'connection-type') {
      console.info(`[RemoteControl] connection-type event: ${event.detail}`);
      const values = this.parseKeyValueDetail(event.detail);
      console.info(`[RemoteControl] parsed values: ${JSON.stringify(values)}`);
      const isSecure = values['secured'] === 'true';
      const isDirect = values['direct'] === 'true';
      console.info(`[RemoteControl] isSecure=${isSecure}, isDirect=${isDirect}`);
      if (isDirect && isSecure) {
        this.connectionType = this.lt('Direct (Encrypted)');
      } else if (isDirect) {
        this.connectionType = this.lt('Direct');
      } else if (isSecure) {
        this.connectionType = this.lt('Relay (Encrypted)');
      } else {
        this.connectionType = this.lt('Relay');
      }
      console.info(`[RemoteControl] connectionType set to: ${this.connectionType}`);
      return;
    }

    if (event.kind === 'quality-status') {
      this.applyQualityStatus(event.detail);
      return;
    }

    if (event.kind === 'record-status') {
      const values = this.parseKeyValueDetail(event.detail);
      this.sessionRecording = this.parseDetailBoolean(values, 'start', this.sessionRecording);
      return;
    }

    if (event.kind === 'voice-call-started' || event.kind === 'voice-call-waiting') {
      this.voiceCallActive = true;
      return;
    }

    if (event.kind === 'voice-call-closed') {
      this.voiceCallActive = false;
      return;
    }

    if (event.kind === 'screenshot-response') {
      void this.showToast(this.lt('Screenshot saved'));
      return;
    }

    if (event.kind === 'cursor_position') {
      this.remoteCursorPositionEventCount += 1;
      const values = this.parseKeyValueDetail(event.detail);
      this.remoteCursorX = this.parseDetailNumber(values, 'x', this.remoteCursorX);
      this.remoteCursorY = this.parseDetailNumber(values, 'y', this.remoteCursorY);
      this.remoteCursorVisible = !this.remoteCursorEmbedded;
      if (this.remoteCursorPositionEventCount === 1 || this.remoteCursorPositionEventCount % 120 === 0) {
        hilog.info(
          0xA03D00,
          'RC',
          `cursor_position count=${this.remoteCursorPositionEventCount} visible=${this.remoteCursorVisible} embedded=${this.remoteCursorEmbedded}`
        );
      }
      return;
    }

    if (event.kind === 'cursor_data') {
      this.remoteCursorDataEventCount += 1;
      if (this.remoteCursorDataEventCount <= 3) {
        hilog.info(0xA03D00, 'RC', `cursor_data count=${this.remoteCursorDataEventCount} detailBytes=${event.detail.length}`);
      }
      this.captureCursorData(event.detail);
      return;
    }

    if (event.kind === 'cursor_id') {
      this.remoteCursorIdEventCount += 1;
      const values = this.parseKeyValueDetail(event.detail);
      this.remoteCursorId = values['id'] ?? this.remoteCursorId;
      this.applyActiveCursorAsset();
      this.remoteCursorVisible = !this.remoteCursorEmbedded;
      if (this.remoteCursorIdEventCount <= 3) {
        hilog.info(
          0xA03D00,
          'RC',
          `cursor_id count=${this.remoteCursorIdEventCount} assetReady=${this.remoteCursorPixelMap !== null}`
        );
      }
      return;
    }

    if (event.kind === 'peer-fingerprint') {
      this.remotePeerFingerprint = event.detail.trim();
      return;
    }

    if (event.kind === 'session-error' || event.kind === 'session-closed' || event.kind === 'closed') {
      this.remoteCursorVisible = false;
      this.voiceCallActive = false;
      this.sessionRecording = false;
    }
  }

  private parseKeyValueDetail(detail: string): Record<string, string> {
    const result: Record<string, string> = {};
    detail.split(/[;,]/).forEach((segment: string) => {
      const separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0) {
        return;
      }
      const key = segment.slice(0, separatorIndex).trim();
      const value = segment.slice(separatorIndex + 1).trim();
      if (key.length > 0) {
        result[key] = value;
      }
    });
    return result;
  }

  private maybeShowReconnectDialogForEvent(event: OfficialSessionEvent): void {
    if (this.sessionCloseRequestedLocally || this.sessionExitScheduled) {
      return;
    }
    const prompt = this.parseRetryPrompt(event);
    if (prompt === null) {
      return;
    }
    if (!this.shouldShowReconnectPromptNow(event.detail)) {
      return;
    }
    console.warn(`[RemoteControl] maybeShowReconnectDialogForEvent kind=${event.kind} title=${prompt.title} detail=${prompt.text.substring(0, 100)}`);
    const msgValues = this.parseKeyValueDetail(event.detail);
    const autoRetry = (msgValues['retry'] ?? '').trim() === 'true';
    if (autoRetry && !this.isRetryingConnection) {
      console.info('[RemoteControl] maybeShowReconnectDialogForEvent: auto-reconnecting due to retry=true');
      void this.retrySessionConnection(false);
      return;
    }
    this.showReconnectDialog = true;
    this.reconnectDialogTitle = prompt.title;
    this.reconnectDialogText = prompt.text;
    this.reconnectDialogCanRelay = prompt.canUseRelay;
    this.statusText = prompt.title;
    this.videoStatus = prompt.text;
    this.prepareReconnectPromptSurface();
    this.stopFrameRefresh();
  }

  private handleTerminalBridgeEvent(event: OfficialSessionEvent): boolean {
    if (event.kind !== 'session-error' && event.kind !== 'session-closed' && event.kind !== 'closed' && event.kind !== 'msgbox') {
      return false;
    }
    if (event.kind === 'msgbox' && !this.isRetryableDisconnectText(event.detail)) {
      return false;
    }
    if (this.sessionCloseRequestedLocally || this.sessionExitScheduled) {
      console.warn(`[RemoteControl] handleTerminalBridgeEvent: skipping due to closeRequested=${this.sessionCloseRequestedLocally} exitScheduled=${this.sessionExitScheduled}`);
      return true;
    }
    const coreState = this.officialBridge.getCoreState();
    const eventDetail = event.detail.trim();
    const stateDetail = coreState.lastError.length > 0 ? coreState.lastError : coreState.detailMessage;
    const detail = eventDetail.length > 0
      ? eventDetail
      : (stateDetail.length > 0 ? stateDetail : this.lt('Session ended'));
    const isPasswordPrompt = this.shouldPromptForPasswordText(detail);
    if (isPasswordPrompt && !this.hasReceivedFrame) {
      return true;
    }
    const retryable = this.isRetryableDisconnectText(detail) || event.kind === 'session-closed' || event.kind === 'closed';
    const peerClosed = detail.toLowerCase().includes('closed manually by the peer') ||
      detail.toLowerCase().includes('closed by the peer') ||
      detail.toLowerCase().includes('对端关闭');
    console.warn(`[RemoteControl] handleTerminalBridgeEvent kind=${event.kind} hasFrame=${this.hasReceivedFrame} retryable=${retryable} peerClosed=${peerClosed} detail=${detail.substring(0, 100)}`);
    hilog.info(0xA03D00, 'RC', `handleTerminalBridgeEvent kind=${event.kind} hasFrame=${this.hasReceivedFrame} retryable=${retryable} peerClosed=${peerClosed} detail=${detail.substring(0, 80)}`);
    if (retryable && !peerClosed) {
      const msgValues = this.parseKeyValueDetail(event.detail);
      const autoRetry = (msgValues['retry'] ?? '').trim() === 'true';
      if (autoRetry && !this.isRetryingConnection) {
        console.info('[RemoteControl] handleTerminalBridgeEvent: auto-reconnecting due to retry=true');
        void this.retrySessionConnection(false);
      } else {
        this.showReconnectDialogFromState(this.lt('Connection lost'), detail);
      }
    } else if (peerClosed && this.hasReceivedFrame) {
      this.finishTerminalSession(this.lt('Session closed'), detail, 420);
    } else {
      this.showReconnectDialogFromState(this.lt('Connection Error'), detail);
    }
    return true;
  }

  private prepareReconnectPromptSurface(): void {
    this.isConnected = false;
    this.isSubmittingPassword = false;
    this.remoteCursorVisible = false;
    this.pointerActive = false;
    this.leftButtonActive = false;
    this.disposeRenderedFrame();
    this.stopFrameRefresh();
  }

  private showReconnectDialogFromState(title: string, detail: string): void {
    this.prepareReconnectPromptSurface();
    this.showReconnectDialog = true;
    this.reconnectDialogTitle = title.trim().length > 0 ? title : this.lt('Connection Error');
    this.reconnectDialogText = detail.trim().length > 0 ? detail : this.lt('Session ended');
    this.reconnectDialogCanRelay = true;
    this.statusText = this.reconnectDialogTitle;
    this.videoStatus = this.reconnectDialogText;
    this.startBridgeRefresh();
  }

  private parseRetryPrompt(event: OfficialSessionEvent): SessionRetryPrompt | null {
    if (event.kind !== 'session-error' && event.kind !== 'session-closed' && event.kind !== 'closed') {
      return null;
    }
    if (event.kind === 'session-closed' || event.kind === 'closed') {
      if (!this.shouldShowReconnectPromptNow(event.detail)) {
        return null;
      }
      return {
        title: this.lt('Connection Error'),
        text: event.detail.trim().length > 0 ? event.detail.trim() : this.lt('Session ended'),
        canUseRelay: true
      };
    }
    const values = this.parseKeyValueDetail(event.detail);
    const msgType = values['type'] ?? '';
    const title = values['title'] ?? '';
    const text = values['text'] ?? event.detail;
    const retry = (values['retry'] ?? '').trim() === 'true';
    const retryableText = this.isRetryableDisconnectText(`${title}\n${text}\n${event.detail}`);
    const canUseRelay = msgType === 'relay-hint' || msgType === 'relay-hint2' || retry;
    if (!retryableText && !this.shouldShowReconnectPromptNow(event.detail)) {
      return null;
    }
    if (!retry && msgType !== 'relay-hint' && msgType !== 'relay-hint2' && !retryableText) {
      return null;
    }
    return {
      title: title.length > 0 ? title : this.lt('Connection Error'),
      text: text.length > 0 ? text : this.lt('Session ended'),
      canUseRelay: canUseRelay || retryableText
    };
  }

  private isRetryableDisconnectText(text: string): boolean {
    const normalized = text.toLowerCase();
    return normalized.includes('reset by the peer') ||
      normalized.includes('reset by peer') ||
      normalized.includes('connection reset') ||
      normalized.includes('os error 104') ||
      normalized.includes('connection refused') ||
      normalized.includes('connection closed') ||
      normalized.includes('forcibly closed') ||
      normalized.includes('broken pipe') ||
      normalized.includes('eof') ||
      normalized.includes('timeout') ||
      normalized.includes('timed out') ||
      normalized.includes('对端') ||
      normalized.includes('重置') ||
      normalized.includes('关闭') ||
      normalized.includes('超时');
  }

  private shouldShowReconnectPromptNow(detail: string = ''): boolean {
    if (this.sessionCloseRequestedLocally || this.sessionExitScheduled) {
      return false;
    }
    if (this.isRetryableDisconnectText(detail)) {
      return true;
    }
    if (this.hasReceivedFrame) {
      return true;
    }
    if (!this.sessionBecameActive || this.sessionBecameActiveAt <= 0) {
      return false;
    }
    return Date.now() - this.sessionBecameActiveAt >= 3000;
  }

  private cancelReconnectDialog(): void {
    this.isRetryingConnection = false;
    this.showReconnectDialog = false;
    this.finishTerminalSession(
      this.lt('Session closed'),
      this.reconnectDialogText.length > 0 ? this.reconnectDialogText : this.lt('Session ended'),
      160
    );
  }

  private async retrySessionConnection(forceRelay: boolean): Promise<void> {
    Logger.info('RC', `retrySessionConnection forceRelay=${forceRelay} isRetrying=${this.isRetryingConnection} deviceId=${this.deviceId}`);
    if (this.isRetryingConnection) {
      return;
    }
    this.isRetryingConnection = true;
    this.showReconnectDialog = false;
    this.sessionCloseRequestedLocally = false;
    if (this.sessionExitTimer !== -1) {
      clearTimeout(this.sessionExitTimer);
      this.sessionExitTimer = -1;
    }
    this.sessionExitScheduled = false;
    this.isConnected = false;
    this.hasReceivedFrame = false;
    this.sessionBecameActive = false;
    this.sessionBecameActiveAt = 0;
    this.disposeRenderedFrame();
    this.statusText = this.lt('Connecting...');
    this.videoStatus = forceRelay ? this.lt('Reconnecting through relay') : this.lt('Retrying connection');
    if (forceRelay) {
      const peerId = this.resolveReconnectPeerId();
      if (peerId.length > 0) {
        PreferenceStore.setPeerConnectMode(peerId, 'relay');
      }
    }
    const reconnected = this.officialBridge.reconnectSession(forceRelay);
    if (!reconnected) {
      const peerId = this.resolveReconnectPeerId();
      if (peerId.length === 0) {
        this.isRetryingConnection = false;
        this.showReconnectDialog = true;
        this.videoStatus = this.lt('Cannot reconnect current session.');
        return;
      }
      try {
        await this.officialBridge.connectToPeer(peerId, this.resolveReconnectPassword(peerId), this.settings);
      } catch (error) {
        console.warn(`[RemoteControl] reconnect fallback connectToPeer failed: ${JSON.stringify(error)}`);
        const latestState = await this.officialBridge.refresh(this.settings);
        const detail = latestState.lastError.length > 0
          ? latestState.lastError
          : (latestState.detailMessage.length > 0 ? latestState.detailMessage : this.lt('Cannot reconnect current session.'));
        this.isRetryingConnection = false;
        this.showReconnectDialogFromState(this.lt('Connection Error'), detail);
        return;
      }
    }
    this.startBridgeRefresh();
    this.startFrameRefresh();
    this.isRetryingConnection = false;
  }

  private resolveReconnectPeerId(): string {
    const statePeerId = this.officialBridge.getCoreState().activePeerId.trim();
    if (statePeerId.length > 0) {
      return statePeerId;
    }
    return this.deviceId.trim();
  }

  private resolveReconnectPassword(peerId: string): string {
    const typedPassword = this.sessionPassword.trim();
    if (typedPassword.length > 0) {
      return typedPassword;
    }
    const savedPassword = PreferenceStore.getPeerPassword(peerId);
    return savedPassword ? savedPassword.trim() : '';
  }

  private updateRecentSessionFromPeerInfoEvent(peerId: string, values: Record<string, string>): void {
    const id = peerId.trim().length > 0 ? peerId.trim() : this.deviceId.trim();
    if (id.length === 0) {
      return;
    }
    const hostname = values['hostname'] ?? '';
    const username = values['username'] ?? '';
    const platform = values['platform'] ?? '';
    if (hostname.trim().length > 0) {
      this.appData.updateRecentSessionName(id, hostname);
      this.deviceName = username.trim().length > 0 ? `${username.trim()}@${hostname.trim()}` : hostname.trim();
    }
    if (username.trim().length > 0) {
      this.appData.updateRecentSessionUsername(id, username);
      if (hostname.trim().length > 0) {
        this.deviceName = `${username.trim()}@${hostname.trim()}`;
      }
    }
    if (platform.trim().length > 0) {
      this.appData.updateRecentSessionPlatform(id, platform);
    }
  }

  private parseDetailNumber(values: Record<string, string>, key: string, fallback: number): number {
    const raw = values[key];
    if (raw === undefined) {
      return fallback;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  private parseDetailFloat(values: Record<string, string>, key: string, fallback: number): number {
    return this.parseDetailNumber(values, key, fallback);
  }

  private parseDetailBoolean(values: Record<string, string>, key: string, fallback: boolean): boolean {
    const raw = values[key];
    if (raw === undefined) {
      return fallback;
    }
    const normalized = raw.trim().toLowerCase();
    if (normalized === '1' || normalized === 'true' || normalized === 'yes') {
      return true;
    }
    if (normalized === '0' || normalized === 'false' || normalized === 'no') {
      return false;
    }
    return fallback;
  }

  private parseLooseNumber(detail: string, fallback: number): number {
    const parsed = Number(detail.trim());
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  private captureCursorData(detail: string): void {
    const payload = this.parseCursorData(detail);
    if (payload === null || payload.id.length === 0) {
      return;
    }
    if (this.remoteCursorAssets.has(payload.id)) {
      if (payload.id === this.remoteCursorId) {
        this.applyActiveCursorAsset();
      }
      return;
    }
    const pixelMap = this.createCursorPixelMap(payload);
    if (pixelMap === null) {
      return;
    }
    this.remoteCursorAssets.set(payload.id, {
      pixelMap: pixelMap,
      hotx: payload.hotx,
      hoty: payload.hoty,
      width: payload.width,
      height: payload.height
    });
    if (this.remoteCursorAssets.size > 20) {
      const oldestKey: string | undefined = this.remoteCursorAssets.keys().next().value;
      if (oldestKey !== undefined) {
        const oldAsset = this.remoteCursorAssets.get(oldestKey);
        if (oldAsset !== undefined) {
          try { oldAsset.pixelMap.release(); } catch (e) { console.warn('release old cursor pixelMap failed: ' + JSON.stringify(e)); }
        }
        this.remoteCursorAssets.delete(oldestKey);
      }
    }
    if (payload.id === this.remoteCursorId) {
      this.applyActiveCursorAsset();
    }
  }

  private parseCursorData(detail: string): RemoteCursorDetailPayload | null {
    const normalized = detail.trim();
    if (!normalized.startsWith('{')) {
      return null;
    }
    try {
      const payload = JSON.parse(normalized) as Record<string, Object | string | number | number[]>;
      const idValue = payload['id'];
      const widthValue = Number(payload['width']);
      const heightValue = Number(payload['height']);
      const hotxValue = Number(payload['hotx']);
      const hotyValue = Number(payload['hoty']);
      const colorsValue = payload['colors'];
      if ((typeof idValue !== 'string' && typeof idValue !== 'number') ||
        !Number.isFinite(widthValue) ||
        !Number.isFinite(heightValue) ||
        !Number.isFinite(hotxValue) ||
        !Number.isFinite(hotyValue) ||
        !Array.isArray(colorsValue)) {
        return null;
      }
      const width = Math.max(0, Math.round(widthValue));
      const height = Math.max(0, Math.round(heightValue));
      if (width <= 0 || height <= 0) {
        return null;
      }
      const colors: number[] = [];
      colorsValue.forEach((value: Object | string | number) => {
        const numeric = Number(value);
        if (Number.isFinite(numeric)) {
          colors.push(Math.max(0, Math.min(255, Math.round(numeric))));
        }
      });
      return {
        id: `${idValue}`,
        hotx: hotxValue,
        hoty: hotyValue,
        width: width,
        height: height,
        colors: colors
      };
    } catch (error) {
      console.warn(`[RemoteControl] Failed to parse cursor_data: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private createCursorPixelMap(payload: RemoteCursorDetailPayload): image.PixelMap | null {
    const expectedBytes = payload.width * payload.height * 4;
    if (payload.colors.length !== expectedBytes) {
      console.warn(
        `[RemoteControl] Ignore cursor_data id=${payload.id} due to byte mismatch expected=${expectedBytes} actual=${payload.colors.length}`
      );
      return null;
    }
    const rgbaBuffer = new ArrayBuffer(expectedBytes);
    const rgba = new Uint8Array(rgbaBuffer);
    for (let index = 0; index < expectedBytes; index += 1) {
      rgba[index] = payload.colors[index];
    }
    try {
      return image.createPixelMapSync(this.swapRedBlueChannels(rgbaBuffer), {
        size: {
          width: payload.width,
          height: payload.height
        },
        pixelFormat: image.PixelMapFormat.BGRA_8888,
        alphaType: image.AlphaType.UNPREMUL
      });
    } catch (error) {
      console.warn(`[RemoteControl] Failed to create cursor PixelMap: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private applyActiveCursorAsset(): void {
    const asset = this.remoteCursorAssets.get(this.remoteCursorId);
    if (asset === undefined) {
      this.remoteCursorPixelMap = null;
      this.remoteCursorHotX = 0;
      this.remoteCursorHotY = 0;
      this.remoteCursorWidth = 0;
      this.remoteCursorHeight = 0;
      return;
    }
    this.remoteCursorPixelMap = asset.pixelMap;
    this.remoteCursorHotX = asset.hotx;
    this.remoteCursorHotY = asset.hoty;
    this.remoteCursorWidth = asset.width;
    this.remoteCursorHeight = asset.height;
  }

  private applyQualityStatus(detail: string): void {
    try {
      const payload = this.parseQualityStatusPayload(detail);
      if (payload === null) {
        console.warn(`[RemoteControl] Failed to parse quality-status: ${detail}`);
        return;
      }
      this.updateQualityDetailCache(payload, detail);
      const delayValue = payload['delay'];
      const parsedDelay = typeof delayValue === 'number' ? delayValue : Number(delayValue ?? '');
      if (Number.isFinite(parsedDelay) && parsedDelay >= 0) {
        this.connectionLatency = Math.round(parsedDelay);
      }

      const recvSpeedValue = payload['speed'];
      if (recvSpeedValue !== undefined && recvSpeedValue !== null) {
        this.connectionRecvSpeed = typeof recvSpeedValue === 'string' && recvSpeedValue.trim().length > 0
          ? recvSpeedValue.trim()
          : '--';
      }

      const sendSpeedValue = payload['send_speed'];
      if (sendSpeedValue !== undefined && sendSpeedValue !== null) {
        this.connectionSendSpeed = typeof sendSpeedValue === 'string' && sendSpeedValue.trim().length > 0
          ? sendSpeedValue.trim()
          : '';
      }
      const combinedSpeedDisplay = this.computeCombinedSpeedDisplay(this.connectionRecvSpeed, this.connectionSendSpeed);
      const targetBitrateDisplay = this.formatBitrateValue(payload['target_bitrate']);
      this.connectionSpeedDisplay = combinedSpeedDisplay !== '--'
        ? combinedSpeedDisplay
        : (targetBitrateDisplay.length > 0 ? targetBitrateDisplay : '--');

      const codecValue = payload['codec_format'];
      if (codecValue !== undefined && codecValue !== null) {
        const codecStr = typeof codecValue === 'string' ? codecValue.trim() : String(codecValue);
        if (codecStr.length > 0 && codecStr !== 'null' && codecStr !== 'undefined') {
          this.connectionCodec = codecStr.toUpperCase();
        }
      }

      const fpsValue = payload['fps'];
      let parsedFps = Number.NaN;
      if (typeof fpsValue === 'number') {
        parsedFps = fpsValue;
      } else if (typeof fpsValue === 'string') {
        parsedFps = Number(fpsValue);
      } else if (fpsValue !== undefined && fpsValue !== null) {
        const fpsRecord = fpsValue as Record<string, number | string>;
        const currentDisplayValue = fpsRecord[this.currentRemoteDisplay.toString()];
        if (currentDisplayValue !== undefined) {
          parsedFps = typeof currentDisplayValue === 'number'
            ? currentDisplayValue
            : Number(currentDisplayValue);
        } else {
          const keys = Object.keys(fpsRecord);
          for (let index = 0; index < keys.length; index += 1) {
            const candidate = fpsRecord[keys[index]];
            const numeric = typeof candidate === 'number' ? candidate : Number(candidate);
            if (Number.isFinite(numeric) && numeric > 0) {
              parsedFps = numeric;
              break;
            }
            if (!Number.isFinite(parsedFps) && Number.isFinite(numeric)) {
              parsedFps = numeric;
            }
          }
        }
      }

      if (Number.isFinite(parsedFps) && parsedFps >= 0) {
        const nextFps = Math.round(parsedFps);
        const hasFreshLocalFrames = this.hasReceivedFrame &&
          this.lastFrameUpdatedAt > 0 &&
          Date.now() - this.lastFrameUpdatedAt < 1500;
        if (nextFps > 0 || !hasFreshLocalFrames) {
          this.updateDisplayedFps(nextFps);
        }
      }
    } catch (error) {
      console.warn(`[RemoteControl] Failed to parse quality-status: ${JSON.stringify(error)}`);
    }
  }

  private computeCombinedSpeedDisplay(recvSpeed: string, sendSpeed: string): string {
    const recvMbps = this.parseSpeedToMbps(recvSpeed);
    const sendMbps = this.parseSpeedToMbps(sendSpeed);
    if (recvMbps === null && sendMbps === null) {
      return '--';
    }
    const totalMbps = (recvMbps ?? 0) + (sendMbps ?? 0);
    if (totalMbps >= 1) {
      return `${totalMbps.toFixed(1)} MB/s`;
    }
    return `${(totalMbps * 1024).toFixed(0)} KB/s`;
  }

  private parseSpeedToMbps(speedStr: string): number | null {
    if (!speedStr || speedStr === '--' || speedStr.trim().length === 0) {
      return null;
    }
    const trimmed = speedStr.trim().toLowerCase();
    const mbMatch = /^([\d.]+)\s*mb\/s/.exec(trimmed);
    if (mbMatch) {
      return parseFloat(mbMatch[1]);
    }
    const kbMatch = /^([\d.]+)\s*kb\/s/.exec(trimmed);
    if (kbMatch) {
      return parseFloat(kbMatch[1]) / 1024;
    }
    const gbMatch = /^([\d.]+)\s*gb\/s/.exec(trimmed);
    if (gbMatch) {
      return parseFloat(gbMatch[1]) * 1024;
    }
    const bMatch = /^([\d.]+)\s*b\/s/.exec(trimmed);
    if (bMatch) {
      return parseFloat(bMatch[1]) / (1024 * 1024);
    }
    return null;
  }

  private clearConnectionQualityState(): void {
    this.qualityMetricItems = [];
    this.qualityDetailText = '';
    this.qualityUpdatedAtText = '';
  }

  private updateQualityDetailCache(
    payload: Record<string, number | string | Record<string, number | string> | null | undefined>,
    detail: string
  ): void {
    this.qualityUpdatedAtText = this.formatQualityTimestamp();
    this.qualityMetricItems = this.buildQualityMetricItems(payload);
    this.qualityDetailText = this.compactQualityDetail(detail);
  }

  private buildQualityMetricItems(
    payload: Record<string, number | string | Record<string, number | string> | null | undefined>
  ): QualityMetricItem[] {
    const items: QualityMetricItem[] = [];
    const keys = Object.keys(payload);
    for (let index = 0; index < keys.length; index += 1) {
      const key = keys[index];
      const value = payload[key];
      const displayValue = this.formatQualityMetricValue(key, value);
      if (displayValue.length === 0) {
        continue;
      }
      items.push({
        key: key,
        label: this.formatQualityMetricLabel(key),
        value: displayValue,
        priority: this.getQualityMetricPriority(key)
      });
    }
    items.sort((left: QualityMetricItem, right: QualityMetricItem) => {
      if (left.priority !== right.priority) {
        return left.priority - right.priority;
      }
      return left.label > right.label ? 1 : -1;
    });
    return items;
  }

  private formatQualityMetricValue(
    key: string,
    value: number | string | Record<string, number | string> | null | undefined
  ): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (key === 'target_bitrate') {
      return this.formatBitrateValue(value);
    }
    if (typeof value === 'number') {
      if (key === 'delay') {
        return `${Math.round(value)} ms`;
      }
      return `${value}`;
    }
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length === 0 || trimmed === 'null' || trimmed === 'undefined') {
        return '';
      }
      if (key === 'delay') {
        const numericDelay = Number(trimmed);
        return Number.isFinite(numericDelay) ? `${Math.round(numericDelay)} ms` : trimmed;
      }
      return trimmed;
    }
    const recordKeys = Object.keys(value);
    const values: string[] = [];
    for (let index = 0; index < recordKeys.length; index += 1) {
      const itemKey = recordKeys[index];
      const itemValue = value[itemKey];
      values.push(`${itemKey}: ${itemValue}`);
    }
    return values.join(', ');
  }

  private formatQualityMetricLabel(key: string): string {
    switch (key) {
      case 'delay':
        return this.lt('Latency');
      case 'fps':
        return this.lt('FPS');
      case 'speed':
        return this.lt('Download');
      case 'send_speed':
        return this.lt('Upload');
      case 'target_bitrate':
        return this.lt('Target Bitrate');
      case 'codec_format':
        return this.lt('Codec');
      case 'chroma':
        return this.lt('Chroma');
      default:
        return key.replace(/_/g, ' ');
    }
  }

  private getQualityMetricPriority(key: string): number {
    switch (key) {
      case 'delay':
        return 10;
      case 'fps':
        return 20;
      case 'speed':
        return 30;
      case 'send_speed':
        return 40;
      case 'target_bitrate':
        return 50;
      case 'codec_format':
        return 60;
      case 'chroma':
        return 70;
      default:
        return 100;
    }
  }

  private formatBitrateValue(value: number | string | Record<string, number | string> | null | undefined): string {
    if (value === undefined || value === null || typeof value === 'object') {
      return '';
    }
    const numeric = typeof value === 'number' ? value : Number(value);
    if (!Number.isFinite(numeric) || numeric <= 0) {
      return typeof value === 'string' && value.trim().length > 0 ? value.trim() : '';
    }
    if (numeric >= 1000) {
      return `${(numeric / 1000).toFixed(1)} Mbps target`;
    }
    return `${Math.round(numeric)} kbps target`;
  }

  private formatQualityTimestamp(): string {
    const now = new Date();
    return `${this.padTimeNumber(now.getHours())}:${this.padTimeNumber(now.getMinutes())}:${this.padTimeNumber(now.getSeconds())}`;
  }

  private padTimeNumber(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private compactQualityDetail(detail: string): string {
    const trimmed = detail.trim();
    if (trimmed.length <= 2400) {
      return trimmed;
    }
    return `${trimmed.substring(0, 2400)}...`;
  }

  private parseQualityStatusPayload(detail: string): Record<string, number | string | Record<string, number | string> | null | undefined> | null {
    try {
      return JSON.parse(detail) as Record<string, number | string | Record<string, number | string> | null | undefined>;
    } catch (_error) {
      return this.parseRustDebugQualityStatus(detail);
    }
  }

  private parseRustDebugQualityStatus(detail: string): Record<string, number | string | Record<string, number | string> | null | undefined> | null {
    if (detail.indexOf('QualityStatus') < 0) {
      return null;
    }
    const payload: Record<string, number | string | Record<string, number | string> | null | undefined> = {};
    const speedMatch = /speed:\s*Some\("([^"]+)"\)/.exec(detail);
    const speedValue = speedMatch?.[1] ?? '';
    if (speedValue.length > 0) {
      payload['speed'] = speedValue;
    }
    const delayMatch = /delay:\s*Some\((-?\d+)\)/.exec(detail);
    const delayValue = delayMatch?.[1] ?? '';
    if (delayValue.length > 0) {
      payload['delay'] = Number(delayValue);
    }
    const targetBitrateMatch = /target_bitrate:\s*Some\((-?\d+)\)/.exec(detail);
    const targetBitrateValue = targetBitrateMatch?.[1] ?? '';
    if (targetBitrateValue.length > 0) {
      payload['target_bitrate'] = Number(targetBitrateValue);
    }
    const codecMatch = /codec_format:\s*Some\((?:"([^"]+)"|([^)]+))\)/.exec(detail);
    const codecValue = codecMatch?.[1] ?? codecMatch?.[2] ?? '';
    if (codecValue.length > 0) {
      payload['codec_format'] = codecValue.trim();
    }
    const fpsRecord: Record<string, number | string> = {};
    const fpsMatch = /fps:\s*\{([^}]*)\}/.exec(detail);
    const fpsValue = fpsMatch?.[1] ?? '';
    if (fpsValue.length > 0) {
      const parts = fpsValue.split(',');
      for (let index = 0; index < parts.length; index += 1) {
        const itemMatch = /^\s*(\d+)\s*:\s*(-?\d+)\s*$/.exec(parts[index]);
        const itemKey = itemMatch?.[1] ?? '';
        const itemValue = itemMatch?.[2] ?? '';
        if (itemKey.length > 0 && itemValue.length > 0) {
          fpsRecord[itemKey] = Number(itemValue);
        }
      }
    }
    if (Object.keys(fpsRecord).length > 0) {
      payload['fps'] = fpsRecord;
    }
    return Object.keys(payload).length > 0 ? payload : null;
  }

  private toHarmonyPixelBuffer(frameData: NativeVideoFrame): ArrayBuffer {
    if (frameData.format === 'bgra' || frameData.format === 'argb') {
      // Native bridge now prefers BGRA bytes for Harmony createPixelMap.
      return frameData.rgba;
    }
    if (frameData.format === 'abgr') {
      // Fallback for older native bridge builds that still expose RGBA bytes.
      return this.swapRedBlueChannels(frameData.rgba);
    }
    return frameData.rgba;
  }

  private swapRedBlueChannels(buffer: ArrayBuffer): ArrayBuffer {
    const source = new Uint8Array(buffer);
    const converted = new Uint8Array(source.byteLength);
    for (let index = 0; index + 3 < source.length; index += 4) {
      converted[index] = source[index + 2];
      converted[index + 1] = source[index + 1];
      converted[index + 2] = source[index];
      converted[index + 3] = source[index + 3];
    }
    return converted.buffer;
  }

  private shouldRenderRemoteCursor(): boolean {
    return this.showRemoteCursor &&
      this.remoteCursorVisible &&
      this.resolveInteractiveWidth() > 0 &&
      this.resolveInteractiveHeight() > 0;
  }

  private async updateRenderedFrameSurfaceAsync(frameData: NativeVideoFrame, renderGeneration: number): Promise<boolean> {
    const pixelBuffer = this.toHarmonyPixelBuffer(frameData);
    try {
      const pixelMap = await this.createFramePixelMapWithTimeout(pixelBuffer, frameData.width, frameData.height);
      if (pixelMap === null) {
        return false;
      }
      if (renderGeneration !== this.renderGeneration || this.sessionExitScheduled) {
        pixelMap.release();
        return false;
      }
      const previousFrame = this.renderedFrame;
      this.renderedFrame = pixelMap;
      this.renderedFrameWidth = frameData.width;
      this.renderedFrameHeight = frameData.height;
      this.renderedFrameFormat = frameData.format;
      this.queueStaleFrame(previousFrame);
      return true;
    } catch (outerError) {
      console.error(`[RemoteControl] updateRenderedFrameSurfaceAsync failed: ${JSON.stringify(outerError)}`);
      return false;
    }
  }

  private createFramePixelMapWithTimeout(pixelBuffer: ArrayBuffer, width: number, height: number): Promise<image.PixelMap | null> {
    return new Promise<image.PixelMap | null>((resolve) => {
      let settled = false;
      const timeoutId = setTimeout(() => {
        if (settled) {
          return;
        }
        settled = true;
        console.warn(`[RemoteControl] createPixelMap timeout width=${width} height=${height}`);
        resolve(null);
      }, this.renderPixelMapTimeoutMs);

      image.createPixelMap(pixelBuffer, {
        size: {
          width,
          height
        },
        pixelFormat: image.PixelMapFormat.BGRA_8888,
        alphaType: image.AlphaType.UNPREMUL
      }).then((pixelMap: image.PixelMap) => {
        if (settled) {
          pixelMap.release();
          return;
        }
        settled = true;
        clearTimeout(timeoutId);
        resolve(pixelMap);
      }).catch((error: Object) => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(timeoutId);
        console.error(`[RemoteControl] createPixelMap failed: ${JSON.stringify(error)}`);
        resolve(null);
      });
    });
  }

  private resolveRenderedImageWidth(): number {
    return Math.max(1, Math.round(this.resolveInteractiveWidth() * this.resolveDisplayScale()));
  }

  private resolveRenderedImageHeight(): number {
    return Math.max(1, Math.round(this.resolveInteractiveHeight() * this.resolveDisplayScale()));
  }

  private getRenderedImageBounds(): number[] {
    const imgW = this.resolveRenderedImageWidth();
    const imgH = this.resolveRenderedImageHeight();
    const imgX = (this.previewWidth - imgW) / 2 + this.panOffsetX;
    const imgY = (this.previewHeight - imgH) / 2 + this.panOffsetY;
    return [imgX, imgY, imgW, imgH];
  }

  private getVisibleImageBounds(): number[] {
    const imgW = this.resolveRenderedImageWidth();
    const imgH = this.resolveRenderedImageHeight();
    const imgX = (this.previewWidth - imgW) / 2 + this.panOffsetX;
    const imgY = (this.previewHeight - imgH) / 2 + this.panOffsetY;
    const visX = Math.max(0, imgX);
    const visY = Math.max(0, imgY);
    const visW = Math.max(1, Math.min(this.previewWidth, imgX + imgW) - visX);
    const visH = Math.max(1, Math.min(this.previewHeight, imgY + imgH) - visY);
    return [visX, visY, visW, visH];
  }

  private getCursorClampBounds(): number[] {
    const imgW = this.resolveRenderedImageWidth();
    const imgH = this.resolveRenderedImageHeight();
    const baseX = (this.previewWidth - imgW) / 2;
    const baseY = (this.previewHeight - imgH) / 2;
    const cx = Math.max(0, baseX);
    const cy = Math.max(0, baseY);
    const cw = Math.max(1, Math.min(this.previewWidth, baseX + imgW) - cx);
    const ch = Math.max(1, Math.min(this.previewHeight, baseY + imgH) - cy);
    return [cx, cy, cw, ch];
  }

  private resolveInteractiveWidth(): number {
    if (this.remoteDisplayWidth > 0) {
      return this.remoteDisplayWidth;
    }
    return this.frameWidth > 0 ? this.frameWidth : 1;
  }

  private resolveInteractiveHeight(): number {
    if (this.remoteDisplayHeight > 0) {
      return this.remoteDisplayHeight;
    }
    return this.frameHeight > 0 ? this.frameHeight : 1;
  }

  private onShowKeyboardChange(): void {
    if (!this.showKeyboard) {
      this.panOffsetY = this.preKeyboardPanOffsetY;
    }
  }

  private onAvoidKeyboardHeightChange(): void {
    if (!this.showKeyboard) {
      this.systemKeyboardWasVisible = false;
      return;
    }
    const kbH = this.avoidKeyboardHeight;
    if (kbH <= 0) {
      this.panOffsetY = this.preKeyboardPanOffsetY;
      if (this.systemKeyboardWasVisible) {
        this.systemKeyboardWasVisible = false;
        this.showKeyboard = false;
        this.releaseAllStickyKeys();
        this.releaseImeProxyFocus();
      }
      return;
    }
    this.systemKeyboardWasVisible = true;
    const renderedH = this.resolveRenderedImageHeight();
    const ph = this.previewHeight;
    if (ph <= 0 || renderedH <= 0) {
      return;
    }
    const imageBottom = (ph - renderedH) / 2 + this.preKeyboardPanOffsetY + renderedH;
    const distanceFromBottom = ph - imageBottom;
    let shift: number;
    if (distanceFromBottom <= 0) {
      shift = kbH;
    } else if (distanceFromBottom >= kbH) {
      return;
    } else {
      shift = kbH - distanceFromBottom;
    }
    this.panOffsetY = this.preKeyboardPanOffsetY - shift;
  }

  private clampPanOffset(x: number, y: number): number[] {
    const renderedW = this.resolveRenderedImageWidth();
    const renderedH = this.resolveRenderedImageHeight();
    const pw = this.previewWidth;
    const ph = this.previewHeight;
    if (pw <= 0 || ph <= 0) return [x, y];

    const PAN_MARGIN = 80;
    let clampedX: number;
    let clampedY: number;

    if (renderedW > pw) {
      const half = (renderedW - pw) / 2 + PAN_MARGIN;
      clampedX = Math.max(-half, Math.min(half, x));
    } else {
      clampedX = Math.max(-PAN_MARGIN, Math.min(PAN_MARGIN, x));
    }

    if (renderedH > ph) {
      const half = (renderedH - ph) / 2 + PAN_MARGIN;
      clampedY = Math.max(-half, Math.min(half, y));
    } else {
      clampedY = Math.max(-PAN_MARGIN, Math.min(PAN_MARGIN, y));
    }

    return [clampedX, clampedY];
  }

  private startPanSpringBack(): void {
    this.stopPanSpringBack();
    const clamped = this.clampPanOffset(this.panOffsetX, this.panOffsetY);
    const targetX = clamped[0];
    const targetY = clamped[1];
    if (Math.abs(this.panOffsetX - targetX) < 0.5 && Math.abs(this.panOffsetY - targetY) < 0.5) {
      this.panOffsetX = targetX;
      this.panOffsetY = targetY;
      return;
    }
    const STEP = 16;
    const FRICTION = 0.08;
    this.panSpringTimer = setInterval(() => {
      this.panOffsetX += (targetX - this.panOffsetX) * FRICTION;
      this.panOffsetY += (targetY - this.panOffsetY) * FRICTION;
      if (Math.abs(this.panOffsetX - targetX) < 0.5 && Math.abs(this.panOffsetY - targetY) < 0.5) {
        this.panOffsetX = targetX;
        this.panOffsetY = targetY;
        this.stopPanSpringBack();
      }
    }, STEP) as number;
  }

  private stopPanSpringBack(): void {
    if (this.panSpringTimer !== -1) {
      clearInterval(this.panSpringTimer);
      this.panSpringTimer = -1;
    }
  }

  private resolveDisplayScale(): number {
    const width = this.resolveInteractiveWidth();
    const height = this.resolveInteractiveHeight();
    if (width <= 0 || height <= 0 || this.previewWidth <= 0 || this.previewHeight <= 0) {
      return this.getCurrentZoom();
    }
    const rotatedWidth = this.isQuarterTurn() ? height : width;
    const rotatedHeight = this.isQuarterTurn() ? width : height;
    const fitScale = Math.min(this.previewWidth / rotatedWidth, this.previewHeight / rotatedHeight);
    if (!Number.isFinite(fitScale) || fitScale <= 0) {
      return this.getCurrentZoom();
    }
    if (this.displayScaleMode === 0) {
      return this.getCurrentZoom();
    }
    return fitScale * this.getCurrentZoom();
  }

  private getCurrentZoom(): number {
    const zoom = this.zoomLevels[this.zoomLevelIndex];
    const baseZoom = zoom !== undefined && zoom > 0 ? zoom : 1;
    return baseZoom * this.pinchScale;
  }

  private isQuarterTurn(): boolean {
    return this.isLandscapeMode;
  }

  private normalizeRotation(rotation: number): number {
    const normalized = rotation % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  private applySuggestedViewTransform(force: boolean = false): void {
    if (!force && this.pinchScale !== 1) {
      return;
    }
    this.pinchScale = 1;
    this.panOffsetX = 0;
    this.panOffsetY = 0;
  }

  private resolvePointerScale(): number {
    const displayScale = this.resolveDisplayScale();
    if (this.peerPlatform === 'Linux' && this.remoteDisplayScale > 0) {
      return displayScale * this.remoteDisplayScale;
    }
    return displayScale;
  }

  private mapTouchToRemote(
    x: number,
    y: number,
    clampToBounds: boolean
  ): RemoteTouchPoint | null {
    const interactiveWidth = this.resolveInteractiveWidth();
    const interactiveHeight = this.resolveInteractiveHeight();
    const displayScale = this.resolveDisplayScale();
    const renderedWidth = interactiveWidth * displayScale;
    const renderedHeight = interactiveHeight * displayScale;
    if (interactiveWidth <= 0 ||
      interactiveHeight <= 0 ||
      this.previewWidth <= 0 ||
      this.previewHeight <= 0 ||
      displayScale <= 0) {
      return null;
    }

    const transformedPoint = this.transformPreviewPointToImageSpace(x, y);
    const imageOffsetX = (this.previewWidth - renderedWidth) / 2;
    const imageOffsetY = (this.previewHeight - renderedHeight) / 2;
    const localX = transformedPoint.x - imageOffsetX;
    const localY = transformedPoint.y - imageOffsetY;

    if (!clampToBounds &&
      (localX < 0 || localX > renderedWidth || localY < 0 || localY > renderedHeight)) {
      return null;
    }

    const clampedX = Math.max(0, Math.min(renderedWidth, localX));
    const clampedY = Math.max(0, Math.min(renderedHeight, localY));

    const localRemoteX = Math.max(0, Math.min(interactiveWidth - 1, Math.round(clampedX / displayScale)));
    const localRemoteY = Math.max(0, Math.min(interactiveHeight - 1, Math.round(clampedY / displayScale)));
    const remoteX = localRemoteX + this.remoteDisplayOriginX;
    const remoteY = localRemoteY + this.remoteDisplayOriginY;

    return { x: remoteX, y: remoteY };
  }

  private transformPreviewPointToImageSpace(x: number, y: number): RemoteTouchPoint {
    let translatedX = x - this.panOffsetX;
    let translatedY = y - this.panOffsetY;
    if (!this.isLandscapeMode) {
      return { x: translatedX, y: translatedY };
    }
    const temp = translatedX;
    translatedX = translatedY;
    translatedY = -temp;
    return { x: translatedX, y: translatedY };
  }

  private shouldShowPasswordAssist(): boolean {
    if (this.hasReceivedFrame) {
      return false;
    }
    const combined = `${this.statusText}\n${this.videoStatus}`.toLowerCase();
    return combined.includes('密码') || combined.includes('password');
  }

  private savePeerPassword(): void {
    const peerId = this.deviceId.trim();
    const password = this.sessionPassword.trim();
    if (peerId.length === 0) {
      return;
    }
    if (password.length === 0) {
      PreferenceStore.setPeerPassword(peerId, '');
      this.videoStatus = this.lt('Saved password deleted.');
      return;
    }
    PreferenceStore.setPeerPassword(peerId, password);
    this.videoStatus = this.lt('Password saved, connecting...');
    this.submitSessionPassword();
  }

  private submitSessionPassword(): void {
    if (this.isSubmittingPassword) {
      return;
    }
    const password = this.sessionPassword.trim();
    if (password.length === 0) {
      this.videoStatus = this.lt('Please enter RustDesk password before submitting.');
      return;
    }
    this.isSubmittingPassword = true;
    const submitted = this.officialBridge.submitSessionPassword(password, false);
    if (!submitted) {
      this.isSubmittingPassword = false;
      this.reconnectWithPassword(password);
      return;
    }
    this.sessionPassword = '';
    this.statusText = this.lt('Submitting session password');
    this.videoStatus = this.lt('Password submitted, waiting for response...');
  }

  private reconnectWithPassword(password: string): void {
    const peerId = this.deviceId.trim();
    if (peerId.length === 0) {
      this.videoStatus = this.lt('Cannot submit password yet...');
      return;
    }
    this.isConnected = false;
    this.statusText = this.lt('Switching to password connection...');
    this.videoStatus = this.lt('Reconnecting with password...');
    this.stopFrameRefresh();
    this.stopBridgeRefresh();
    this.officialBridge.requestSessionClose();
    this.reconnectWithPasswordTimer = setTimeout(() => {
      this.sessionPassword = '';
      this.isSubmittingPassword = false;
      const settings = this.appData.getSettings();
      this.startBridgeRefresh();
      void this.officialBridge.connectToPeer(peerId, password, settings).then(() => {
        const state = this.officialBridge.getCoreState();
        this.applyBridgeState(state);
        this.startFrameRefresh();
      }).catch((error: Object) => {
        console.warn('reconnectWithPassword connectToPeer failed: ' + JSON.stringify(error));
        this.isSubmittingPassword = false;
        const state = this.officialBridge.getCoreState();
        this.applyBridgeState(state);
        this.startFrameRefresh();
      });
    }, 300);
  }

  private shouldPromptForPasswordText(text: string): boolean {
    const combined = text.toLowerCase();
    return combined.includes('密码') ||
      combined.includes('认证') ||
      combined.includes('password') ||
      combined.includes('input-password') ||
      combined.includes('re-input-password') ||
      combined.includes('auth');
  }

  private queueStaleFrame(frame: image.PixelMap | null): void {
    if (frame === null) {
      return;
    }
    this.staleFrames.push(frame);
    while (this.staleFrames.length > 3) {
      const stale = this.staleFrames.shift();
      if (stale !== undefined) {
        stale.release();
      }
    }
  }

  private sendRemoteMouseMask(mask: number, x: number, y: number, eventType: number): boolean {
    const input = this.resolveMouseInput(mask, x, y);
    const sent = NativeRustDeskBridge.sendMouseInput(input.mask, input.x, input.y);
    if (!sent) {
      console.warn(
        `[RemoteControl] sendMouseInput failed type=${eventType} mask=${input.mask} x=${input.x} y=${input.y} connected=${this.isConnected} hasFrame=${this.hasReceivedFrame}`
      );
    }
    return sent;
  }

  private resolveMouseInput(mask: number, x: number, y: number): RemoteMouseInput {
    if ((mask & MOUSE_MASK.WHEEL_UP) !== 0) {
      return { mask: 0x03, x: 0, y: -1 };
    }
    if ((mask & MOUSE_MASK.WHEEL_DOWN) !== 0) {
      return { mask: 0x03, x: 0, y: 1 };
    }
    return {
      mask: this.resolveMouseMask(mask),
      x,
      y
    };
  }

  private resolveMouseMask(mask: number): number {
    if (!this.swapMouseButtons) {
      return mask;
    }
    let mappedMask = mask;
    const hasLeftDown = (mappedMask & MOUSE_MASK.LEFT_DOWN) !== 0;
    const hasLeftUp = (mappedMask & MOUSE_MASK.LEFT_UP) !== 0;
    const hasRightDown = (mappedMask & MOUSE_MASK.RIGHT_DOWN) !== 0;
    const hasRightUp = (mappedMask & MOUSE_MASK.RIGHT_UP) !== 0;
    mappedMask &= ~(MOUSE_MASK.LEFT_DOWN | MOUSE_MASK.LEFT_UP | MOUSE_MASK.RIGHT_DOWN | MOUSE_MASK.RIGHT_UP);
    if (hasLeftDown) {
      mappedMask |= MOUSE_MASK.RIGHT_DOWN;
    }
    if (hasLeftUp) {
      mappedMask |= MOUSE_MASK.RIGHT_UP;
    }
    if (hasRightDown) {
      mappedMask |= MOUSE_MASK.LEFT_DOWN;
    }
    if (hasRightUp) {
      mappedMask |= MOUSE_MASK.LEFT_UP;
    }
    return mappedMask;
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer === -1) {
      return;
    }
    clearTimeout(this.longPressTimer);
    this.longPressTimer = -1;
  }

  private updatePointerPosition(mappedTouch: RemoteTouchPoint): void {
    this.lastPointerRemoteX = mappedTouch.x;
    this.lastPointerRemoteY = mappedTouch.y;
    this.hasPointerPosition = true;
    this.remoteCursorX = mappedTouch.x;
    this.remoteCursorY = mappedTouch.y;
  }

  private resetTouchInteraction(): void {
    this.clearLongPressTimer();
    this.pointerActive = false;
    this.leftButtonActive = false;
    this.longPressTriggered = false;
    this.touchDownAt = 0;
    this.touchDownPreviewX = 0;
    this.touchDownPreviewY = 0;
    this.hasPointerPosition = false;
    this.leftBtnActive = false;
    this.rightBtnActive = false;
    this.middleBtnActive = false;
    this.panBtnActive = false;
    this.joystickActive = false;
    this.joystickKnobX = 0;
    this.joystickKnobY = 0;
    this.joystickPanMode = false;
    this.joystickTouchId = -1;
  }

  private scheduleLongPressRightClick(): void {
    this.clearLongPressTimer();
    this.longPressTriggered = false;
    this.longPressTimer = setTimeout(() => {
      this.longPressTimer = -1;
      if (!this.pointerActive || this.leftButtonActive || this.longPressTriggered || !this.hasPointerPosition) {
        return;
      }
      this.longPressTriggered = true;
      this.sendRemoteMouseMask(
        MOUSE_MASK.MOVE | MOUSE_MASK.MOTION,
        this.lastPointerRemoteX,
        this.lastPointerRemoteY,
        TouchType.Down
      );
      this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
      this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
      this.maybeRequestVideoRefresh(true);
    }, this.longPressRightClickMs);
  }

  private getGestureCenter(event: TouchEvent, count: number): RemoteTouchPoint | null {
    const touches = event.touches;
    if (!touches || touches.length < count) {
      return null;
    }
    let totalX = 0;
    let totalY = 0;
    for (let index = 0; index < count; index += 1) {
      totalX += touches[index].x;
      totalY += touches[index].y;
    }
    return {
      x: totalX / count,
      y: totalY / count
    };
  }

  private getGestureDistance(event: TouchEvent): number {
    const touches = event.touches;
    if (!touches || touches.length < 2) {
      return 0;
    }
    const deltaX = touches[0].x - touches[1].x;
    const deltaY = touches[0].y - touches[1].y;
    return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
  }

  private finishGestureTouch(): void {
    if (this.displayScaleMode === 2) {
      this.customZoomPercent = Math.max(100, Math.min(600, Math.round(this.pinchScale * 100)));
      NativeRustDeskBridge.setLocalOption('display-scale-mode', 'custom');
      NativeRustDeskBridge.setLocalOption('custom-zoom-percent', String(this.customZoomPercent));
    }
    this.gestureActive = false;
    this.gestureStartDistance = 0;
    this.gestureStartCenterX = 0;
    this.gestureStartCenterY = 0;
    this.lastGestureCenterX = 0;
    this.lastGestureCenterY = 0;
    this.twoFingerScrollAccumulator = 0;
    this.resetTouchInteraction();
    this.startPanSpringBack();
  }

  private handleGestureTouch(event: TouchEvent): boolean {
    const touches = event.touches;
    const touchCount = touches ? touches.length : 0;
    if (touchCount === 0) {
      if (this.gestureActive) {
        this.finishGestureTouch();
        return true;
      }
      return false;
    }

    if (this.multiTouchFingers === 4 && touchCount >= 4) {
      if (!this.gestureActive && event.type === TouchType.Down) {
        this.showToolbar = !this.showToolbar;
        this.gestureActive = true;
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.finishGestureTouch();
      }
      return true;
    }

    if (this.multiTouchFingers === 3 && touchCount >= 3) {
      const center = this.getGestureCenter(event, 3);
      if (center === null) {
        return true;
      }
      if (!this.gestureActive || event.type === TouchType.Down) {
        this.gestureActive = true;
        this.gestureStartPanX = this.panOffsetX;
        this.gestureStartPanY = this.panOffsetY;
        this.gestureStartCenterX = center.x;
        this.gestureStartCenterY = center.y;
        this.lastGestureCenterX = center.x;
        this.lastGestureCenterY = center.y;
        this.resetTouchInteraction();
        return true;
      }
      if (event.type === TouchType.Move) {
        this.panOffsetX = this.gestureStartPanX + (center.x - this.gestureStartCenterX);
        this.panOffsetY = this.gestureStartPanY + (center.y - this.gestureStartCenterY);
        this.stopPanSpringBack();
        this.lastGestureCenterX = center.x;
        this.lastGestureCenterY = center.y;
        return true;
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.finishGestureTouch();
      }
      return true;
    }

    if (this.multiTouchFingers === 2 && touchCount >= 2) {
      const center = this.getGestureCenter(event, 2);
      const distance = this.getGestureDistance(event);
      if (center === null || distance <= 0) {
        return true;
      }
      if (!this.gestureActive || event.type === TouchType.Down) {
        this.gestureActive = true;
        this.gestureStartDistance = Math.max(distance, 1);
        this.gestureStartScale = this.pinchScale;
        this.gestureStartPanX = this.panOffsetX;
        this.gestureStartPanY = this.panOffsetY;
        this.gestureStartCenterX = center.x;
        this.gestureStartCenterY = center.y;
        this.lastGestureCenterX = center.x;
        this.lastGestureCenterY = center.y;
        this.twoFingerScrollAccumulator = 0;
        this.resetTouchInteraction();
        return true;
      }
      if (event.type === TouchType.Move) {
        if (this.mouseControlMode === 0) {
          this.panOffsetX = this.gestureStartPanX + (center.x - this.gestureStartCenterX);
          this.panOffsetY = this.gestureStartPanY + (center.y - this.gestureStartCenterY);
          this.stopPanSpringBack();
        } else {
          const scaleRatio = distance / Math.max(this.gestureStartDistance, 1);
          const distanceDelta = Math.abs(distance - this.gestureStartDistance);
          if (distanceDelta >= 8) {
            this.displayScaleMode = 2;
            this.pinchScale = Math.max(1, Math.min(this.maxPinchScale, this.gestureStartScale * scaleRatio));
            this.panOffsetX = this.gestureStartPanX + (center.x - this.gestureStartCenterX);
            this.panOffsetY = this.gestureStartPanY + (center.y - this.gestureStartCenterY);
            this.stopPanSpringBack();
          } else if (this.hasPointerPosition) {
            this.twoFingerScrollAccumulator += center.y - this.lastGestureCenterY;
            const dynamicTwoFingerThreshold = this.TWO_FINGER_SCROLL_THRESHOLD * 5 / this.touchSettings.shortPressDrag.speed;
            if (Math.abs(this.twoFingerScrollAccumulator) >= dynamicTwoFingerThreshold) {
              const scrollDown = this.twoFingerScrollAccumulator > 0;
              const wheelMask = scrollDown
                ? (this.reverseScroll ? MOUSE_MASK.WHEEL_DOWN : MOUSE_MASK.WHEEL_UP)
                : (this.reverseScroll ? MOUSE_MASK.WHEEL_UP : MOUSE_MASK.WHEEL_DOWN);
              this.sendRemoteMouseMask(wheelMask, this.lastPointerRemoteX, this.lastPointerRemoteY, event.type);
              this.maybeRequestVideoRefresh(true);
              this.twoFingerScrollAccumulator = 0;
            }
          }
        }
        this.lastGestureCenterX = center.x;
        this.lastGestureCenterY = center.y;
        return true;
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.finishGestureTouch();
      }
      return true;
    }

    return false;
  }

  private handleDirectTouchMode(event: TouchEvent): void {
    const isRelease = event.type === TouchType.Up;
    const isCancel = event.type === TouchType.Cancel;
    const touch = event.touches && event.touches.length > 0 ? event.touches[0] : undefined;
    let mappedTouch: RemoteTouchPoint | null = null;
    if (touch !== undefined) {
      const clampToBounds = event.type !== TouchType.Down && this.pointerActive;
      mappedTouch = this.mapTouchToRemote(touch.x, touch.y, clampToBounds);
      if (mappedTouch !== null) {
        this.updatePointerPosition(mappedTouch);
      }
    } else if ((isRelease || isCancel) && this.hasPointerPosition) {
      mappedTouch = {
        x: this.lastPointerRemoteX,
        y: this.lastPointerRemoteY
      };
    }

    if (event.type === TouchType.Down) {
      if (mappedTouch === null) {
        this.resetTouchInteraction();
        return;
      }
      const activeTouch: RemoteTouchPoint = mappedTouch;
      this.pointerActive = true;
      this.leftButtonActive = true;
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, activeTouch.x, activeTouch.y, event.type);
      this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, activeTouch.x, activeTouch.y, event.type);
      this.maybeRequestVideoRefresh(true);
      return;
    }

    if (mappedTouch === null) {
      if ((isRelease || isCancel) && this.leftButtonActive && this.hasPointerPosition) {
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, event.type);
      }
      if (isRelease || isCancel) {
        this.resetTouchInteraction();
      }
      return;
    }
    const activeTouch: RemoteTouchPoint = mappedTouch;

    if (event.type === TouchType.Move) {
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, activeTouch.x, activeTouch.y, event.type);
      return;
    }

    if (isRelease || isCancel) {
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, activeTouch.x, activeTouch.y, event.type);
      if (this.leftButtonActive) {
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, activeTouch.x, activeTouch.y, event.type);
      }
      this.resetTouchInteraction();
      this.maybeRequestVideoRefresh(true);
    }
  }

  private handlePreviewTouch(event: TouchEvent): void {
    if (this.viewMode) {
      return;
    }
    if (!this.hasRenderedFrame()) {
      return;
    }
    if (this.mouseControlMode === 1) {
      return;
    }
    if (this.handleGestureTouch(event)) {
      return;
    }
    this.handleSimulatedMouseTouch(event);
  }

  private initTouchInteractionManager(): void {
    this.touchInteractionManager = new TouchInteractionManager({
      onAction: (action: TouchAction, ctx) => {
        this.executeTouchAction(action, ctx);
      },
      onActionStart: (action: TouchAction, ctx) => {
        this.executeTouchActionStart(action, ctx);
      },
      onActionUpdate: (action: TouchAction, ctx) => {
        this.executeTouchActionUpdate(action, ctx);
      },
      onActionEnd: (action: TouchAction, ctx) => {
        this.executeTouchActionEnd(action, ctx);
      },
    }, this.touchSettings);
  }

  private executeTouchAction(action: TouchAction, ctx: TouchInteractionContext): void {
    switch (action) {
      case TouchAction.LEFT_CLICK:
        if (!this.hasPointerPosition) return;
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        this.maybeRequestVideoRefresh(true);
        break;
      case TouchAction.LEFT_DOUBLE_CLICK:
        if (!this.hasPointerPosition) return;
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        this.maybeRequestVideoRefresh(true);
        break;
      case TouchAction.RIGHT_CLICK:
        if (!this.hasPointerPosition) return;
        this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        this.maybeRequestVideoRefresh(true);
        break;
      case TouchAction.MIDDLE_CLICK:
        if (!this.hasPointerPosition) return;
        this.sendRemoteMouseMask(MOUSE_MASK.MIDDLE_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        this.sendRemoteMouseMask(MOUSE_MASK.MIDDLE_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
        this.maybeRequestVideoRefresh(true);
        break;
      default:
        break;
    }
  }

  private executeTouchActionStart(action: TouchAction, ctx: TouchInteractionContext): void {
    switch (action) {
      case TouchAction.SCREEN_PAN:
        this.gestureStartPanX = this.panOffsetX;
        this.gestureStartPanY = this.panOffsetY;
        break;
      case TouchAction.MARQUEE_SELECT:
        this.showMarquee = true;
        const rect: MarqueeRect = { left: ctx.startX, top: ctx.startY, right: ctx.currentX, bottom: ctx.currentY };
        this.marqueeRect = rect;
        if (this.hasPointerPosition) {
          this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        }
        break;
      case TouchAction.LEFT_DRAG:
        if (!this.hasPointerPosition) return;
        this.sendRemoteMouseMask(MOUSE_MASK.LEFT_DOWN, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Down);
        break;
      default:
        break;
    }
  }

  private executeTouchActionUpdate(action: TouchAction, ctx: TouchInteractionContext): void {
    switch (action) {
      case TouchAction.SCREEN_PAN:
        this.panOffsetX = this.gestureStartPanX + ctx.deltaX;
        this.panOffsetY = this.gestureStartPanY + ctx.deltaY;
        this.stopPanSpringBack();
        break;
      case TouchAction.SCREEN_SCROLL:
        if (this.touchInteractionManager === null || !this.hasPointerPosition) return;
        const scrollDeltaY = this.touchInteractionManager.getScrollDeltaY();
        const dynamicThreshold = this.TOUCH_SCROLL_THRESHOLD * 5 / this.touchSettings.shortPressDrag.speed;
        if (Math.abs(scrollDeltaY) >= dynamicThreshold) {
          const scrollDown = scrollDeltaY > 0;
          const wheelMask = scrollDown
            ? (this.reverseScroll ? MOUSE_MASK.WHEEL_UP : MOUSE_MASK.WHEEL_DOWN)
            : (this.reverseScroll ? MOUSE_MASK.WHEEL_DOWN : MOUSE_MASK.WHEEL_UP);
          this.sendRemoteMouseMask(wheelMask, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Move);
          this.touchInteractionManager.updateScrollBaseline();
          this.maybeRequestVideoRefresh(true);
        }
        break;
      case TouchAction.MARQUEE_SELECT:
        if (this.touchInteractionManager === null) return;
        this.marqueeRect = this.touchInteractionManager.getMarqueeRect();
        const mappedPoint = this.mapTouchToRemote(ctx.currentX, ctx.currentY, false);
        if (mappedPoint !== null) {
          this.updatePointerPosition(mappedPoint);
          this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mappedPoint.x, mappedPoint.y, TouchType.Move);
        }
        break;
      case TouchAction.LEFT_DRAG:
        const mappedDrag = this.mapTouchToRemote(ctx.currentX, ctx.currentY, false);
        if (mappedDrag !== null) {
          this.updatePointerPosition(mappedDrag);
          this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mappedDrag.x, mappedDrag.y, TouchType.Move);
        }
        break;
      default:
        break;
    }
  }

  private executeTouchActionEnd(action: TouchAction, ctx: TouchInteractionContext): void {
    switch (action) {
      case TouchAction.SCREEN_PAN:
        this.startPanSpringBack();
        break;
      case TouchAction.MARQUEE_SELECT:
        this.showMarquee = false;
        if (this.hasPointerPosition) {
          this.sendRemoteMouseMask(MOUSE_MASK.RIGHT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
          this.maybeRequestVideoRefresh(true);
        }
        break;
      case TouchAction.LEFT_DRAG:
        if (this.hasPointerPosition) {
          this.sendRemoteMouseMask(MOUSE_MASK.LEFT_UP, this.lastPointerRemoteX, this.lastPointerRemoteY, TouchType.Up);
          this.maybeRequestVideoRefresh(true);
        }
        break;
      default:
        break;
    }
  }

  private handleSimulatedMouseTouch(event: TouchEvent): void {
    if (this.touchInteractionManager === null) {
      this.initTouchInteractionManager();
      if (this.touchInteractionManager === null) return;
    }
    const mgr = this.touchInteractionManager;
    const touch = event.touches && event.touches.length > 0 ? event.touches[0] : undefined;
    if (touch === undefined) {
      if (event.type === TouchType.Up) {
        mgr.onTouchUp(this.lastPointerRemoteX, this.lastPointerRemoteY);
      } else if (event.type === TouchType.Cancel) {
        mgr.onTouchCancel();
      }
      return;
    }
    const mappedTouch = this.mapTouchToRemote(touch.x, touch.y, event.type !== TouchType.Down && this.pointerActive);
    if (mappedTouch !== null) {
      this.updatePointerPosition(mappedTouch);
    } else {
      if (event.type === TouchType.Up) {
        mgr.onTouchUp(this.lastPointerRemoteX, this.lastPointerRemoteY);
      } else if (event.type === TouchType.Cancel) {
        mgr.onTouchCancel();
      }
      return;
    }
    if (event.type === TouchType.Down) {
      this.pointerActive = true;
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mappedTouch.x, mappedTouch.y, event.type);
      mgr.onTouchDown(touch.x, touch.y);
      this.maybeRequestVideoRefresh(true);
    } else if (event.type === TouchType.Move) {
      mgr.onTouchMove(touch.x, touch.y);
    } else if (event.type === TouchType.Up) {
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mappedTouch.x, mappedTouch.y, event.type);
      mgr.onTouchUp(touch.x, touch.y);
      this.resetTouchInteraction();
      this.maybeRequestVideoRefresh(true);
    } else if (event.type === TouchType.Cancel) {
      mgr.onTouchCancel();
      this.resetTouchInteraction();
    }
  }

  private handlePreviewMouse(event: MouseEvent): void {
    if (this.viewMode) {
      return;
    }
    if (!this.hasRenderedFrame()) {
      return;
    }

    const mappedPoint = this.mapTouchToRemote(event.x, event.y, false);
    if (mappedPoint === null) {
      return;
    }

    this.updatePointerPosition(mappedPoint);

    if (event.action === MouseAction.Hover || event.action === MouseAction.Move) {
      this.sendRemoteMouseMask(MOUSE_MASK.MOVE | MOUSE_MASK.MOTION, mappedPoint.x, mappedPoint.y, TouchType.Move);
      return;
    }

    if (event.action === MouseAction.Press || event.action === MouseAction.Release) {
      const isPress = event.action === MouseAction.Press;
      let mask = MOUSE_MASK.MOVE | MOUSE_MASK.MOTION;

      if (event.button === MouseButton.Left) {
        mask |= isPress ? MOUSE_MASK.LEFT_DOWN : MOUSE_MASK.LEFT_UP;
      } else if (event.button === MouseButton.Right) {
        mask |= isPress ? MOUSE_MASK.RIGHT_DOWN : MOUSE_MASK.RIGHT_UP;
      } else if (event.button === MouseButton.Middle) {
        mask |= isPress ? MOUSE_MASK.MIDDLE_DOWN : MOUSE_MASK.MIDDLE_UP;
      } else if (event.button === MouseButton.Back) {
        mask |= isPress ? MOUSE_MASK.LEFT_DOWN : MOUSE_MASK.LEFT_UP;
      } else if (event.button === MouseButton.Forward) {
        mask |= isPress ? MOUSE_MASK.LEFT_DOWN : MOUSE_MASK.LEFT_UP;
      } else {
        mask = isPress ? MOUSE_MASK.LEFT_DOWN : MOUSE_MASK.LEFT_UP;
      }

      this.sendRemoteMouseMask(mask, mappedPoint.x, mappedPoint.y, isPress ? TouchType.Down : TouchType.Up);
      this.maybeRequestVideoRefresh(true);
      return;
    }

  }

  private handlePreviewHover(isHover: boolean): void {
    if (this.viewMode) {
      return;
    }
  }

  private handlePreviewAxis(event: AxisEvent): void {
    if (this.viewMode) {
      return;
    }
    if (!this.hasRenderedFrame()) {
      return;
    }

    const mappedPoint = this.mapTouchToRemote(event.x, event.y, false);
    if (mappedPoint === null) {
      return;
    }

    if (event.action === AxisAction.BEGIN || event.action === AxisAction.UPDATE) {
      const verticalDelta = event.getVerticalAxisValue();
      this.axisScrollAccumulator += verticalDelta;
      if (Math.abs(this.axisScrollAccumulator) >= this.AXIS_SCROLL_THRESHOLD) {
        const scrollDown = this.axisScrollAccumulator < 0;
        const wheelMask = scrollDown
          ? (this.reverseScroll ? MOUSE_MASK.WHEEL_UP : MOUSE_MASK.WHEEL_DOWN)
          : (this.reverseScroll ? MOUSE_MASK.WHEEL_DOWN : MOUSE_MASK.WHEEL_UP);
        this.sendRemoteMouseMask(wheelMask, mappedPoint.x, mappedPoint.y, TouchType.Move);
        this.maybeRequestVideoRefresh(true);
        this.axisScrollAccumulator = 0;
      }
    } else if (event.action === AxisAction.END || event.action === AxisAction.CANCEL) {
      this.axisScrollAccumulator = 0;
    }
  }

  private static readonly HARMONY_TO_VK: Record<number, number> = {
    2000: 48, 2001: 49, 2002: 50, 2003: 51, 2004: 52,
    2005: 53, 2006: 54, 2007: 55, 2008: 56, 2009: 57,
    2011: 65, 2012: 66, 2013: 67, 2014: 68, 2015: 69,
    2016: 70, 2017: 71, 2018: 72, 2019: 73, 2020: 74,
    2021: 75, 2022: 76, 2023: 77, 2024: 78, 2025: 79,
    2026: 80, 2027: 81, 2028: 82, 2029: 83, 2030: 84,
    2031: 85, 2032: 86, 2033: 87, 2034: 88, 2035: 89,
    2036: 90,
  };

  private static readonly HARMONY_SPECIAL_TO_VK: Record<number, number> = {
    2017: 13, 2018: 8, 2019: 9, 2020: 32, 2022: 27, 2021: 46,
    2029: 17, 2030: 17, 2031: 16, 2032: 16, 2033: 18, 2034: 18,
    2037: 112, 2038: 113, 2039: 114, 2040: 115, 2041: 116,
    2042: 117, 2043: 118, 2044: 119, 2045: 120, 2046: 121,
    2047: 122, 2048: 123,
    2049: 186, 2050: 187, 2051: 188, 2052: 189, 2053: 190,
    2054: 191, 2055: 192, 2056: 219, 2057: 220, 2058: 221,
    2059: 222,
    2074: 37, 2075: 38, 2076: 39, 2077: 40,
    2066: 45, 2067: 36, 2068: 35, 2069: 33, 2070: 34,
    2071: 144, 2072: 111, 2073: 106,
  };

  private handleKeyEvent(event: KeyEvent): void {
    if (this.viewMode) {
      return;
    }
    const pressed = event.type === KeyType.Down;
    let vk = RemoteControl.HARMONY_SPECIAL_TO_VK[event.keyCode] ?? RemoteControl.HARMONY_TO_VK[event.keyCode];
    if (vk === undefined) {
      return;
    }
    let modifiers = this.buildModifierMask();
    NativeRustDeskBridge.sendKeyboardInput(vk, pressed, modifiers);
    if (pressed) {
      this.maybeRequestVideoRefresh(true);
    }
  }

  private shouldAutoCloseTerminalSession(): boolean {
    return this.sessionCloseRequestedLocally || this.sessionBecameActive || this.hasReceivedFrame;
  }

  private finishTerminalSession(statusText: string, videoStatus: string, delayMs: number): void {
    this.isConnected = false;
    this.isSubmittingPassword = false;
    this.remoteCursorVisible = false;
    this.pointerActive = false;
    this.showDisplayMenu = false;
    this.showMouseModeMenu = false;
    this.showChatModeMenu = false;
    this.showMoreMenu = false;
    this.showChatPanel = false;
    this.showOsPasswordDialog = false;
    this.setConnectionInfoVisible(false);
    this.statusText = statusText;
    this.videoStatus = videoStatus;
    if (this.isLandscapeMode !== this.originalLandscapeMode) {
      this.isLandscapeMode = this.originalLandscapeMode;
      WindowChromeService.getInstance().setLandscape(this.originalLandscapeMode);
    }
    this.officialBridge.requestSessionClose();
    this.scheduleSessionExit(delayMs);
  }

  private scheduleSessionExit(delayMs: number): void {
    if (this.sessionExitScheduled) {
      return;
    }
    this.sessionExitScheduled = true;
    this.stopFrameRefresh();
    this.stopBridgeRefresh();
    this.sessionExitTimer = setTimeout(() => {
      this.sessionExitTimer = -1;
      this.goBack();
    }, delayMs);
  }

  private hasRenderedFrame(): boolean {
    return this.renderedFrame !== null;
  }

  private disposeRenderedFrame(): void {
    this.renderGeneration += 1;
    this.clearLongPressTimer();
    this.pointerActive = false;
    this.leftButtonActive = false;
    this.longPressTriggered = false;
    this.touchDownAt = 0;
    this.touchDownPreviewX = 0;
    this.touchDownPreviewY = 0;
    this.hasPointerPosition = false;
    this.remoteCursorVisible = false;
    this.remoteCursorId = '';
    this.remoteCursorPixelMap = null;
    this.remoteCursorHotX = 0;
    this.remoteCursorHotY = 0;
    this.remoteCursorWidth = 0;
    this.remoteCursorHeight = 0;
    this.lastFrameId = 0;
    this.lastFrameUpdatedAt = 0;
    this.lastFramePullTraceAt = 0;
    this.lastNativeFrameAdvanceAt = 0;
    this.lastBridgeActivityAt = 0;
    this.lastSilentSessionWarningAt = 0;
    this.frameVersion = 0;
    this.hasReceivedFrame = false;
    this.sessionBecameActive = false;
    this.sessionBecameActiveAt = 0;
    this.frameWidth = 0;
    this.frameHeight = 0;
    this.remoteDisplayWidth = 0;
    this.remoteDisplayHeight = 0;
    this.remoteDisplayOriginX = 0;
    this.remoteDisplayOriginY = 0;
    this.remoteDisplayScale = 1;
    this.currentRemoteDisplay = 0;
    this.connectionLatency = 0;
    this.connectionFps = 0;
    this.connectionRecvSpeed = '--';
    this.connectionSendSpeed = '--';
    this.connectionSpeedDisplay = '--';
    this.connectionType = '';
    this.connectionCodec = '';
    this.clearConnectionQualityState();
    this.fpsCalcLastTime = 0;
    this.fpsCalcFrameCount = 0;
    this.lastNonZeroFps = 0;
    this.lastNonZeroFpsAt = 0;
    this.renderedFrameWidth = 0;
    this.renderedFrameHeight = 0;
    this.renderedFrameFormat = '';
    if (this.renderedFrame !== null) {
      this.renderedFrame.release();
      this.renderedFrame = null;
    }
    while (this.staleFrames.length > 0) {
      const stale = this.staleFrames.shift();
      if (stale !== undefined) {
        stale.release();
      }
    }
    this.remoteCursorAssets.forEach((asset: RemoteCursorAsset) => {
      asset.pixelMap.release();
    });
    this.remoteCursorAssets.clear();
  }

  private getRouteParams(): DeviceRouteParams | null {
    try {
      const params = this.getUIContext().getRouter().getParams();
      return params as DeviceRouteParams;
    } catch (_error) {
      return null;
    }
  }

  private goBack(): void {
    if (this.isLandscapeMode !== this.originalLandscapeMode) {
      this.isLandscapeMode = this.originalLandscapeMode;
      WindowChromeService.getInstance().setLandscape(this.originalLandscapeMode);
    }
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      console.error('goBack failed', JSON.stringify(error));
    }
  }

  private buildSessionRouteParams(): DeviceRouteParams {
    return {
      deviceId: this.deviceId,
      deviceName: this.deviceName
    };
  }

  private buildChatRouteParams(): DeviceRouteParams {
    return {
      deviceId: this.deviceId,
      deviceName: this.deviceName,
      clearChat: '1'
    };
  }

  private navigateTo(url: string, params?: DeviceRouteParams): void {
    try {
      if (params) {
        void this.getUIContext().getRouter().pushUrl({ url: url, params: params });
        return;
      }
      void this.getUIContext().getRouter().pushUrl({ url: url });
    } catch (error) {
      console.error('navigateTo failed', JSON.stringify(error));
    }
  }
}

@Component
struct RadioOptionItem {
  @Prop selected: boolean = false;
  label: string = '';
  icon: string = '';
  onSelected: () => void = () => {};
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';

  build() {
    Row({ space: 10 }) {
      if (this.icon.length > 0) {
        Image($rawfile(this.icon))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Text(this.label)
        .fontSize(14)
        .fontColor(this.selected ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1);

      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.selected ? this.theme_ACCENT : this.theme_TEXT_TERTIARY)
          .strokeWidth(2)

        if (this.selected) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.theme_ACCENT)
        }
      }
      .width(20)
      .height(20)
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .onClick(() => { this.onSelected(); })
    ;
  }
}

@Component
struct CheckboxOptionItem {
  @Prop checked: boolean = false;
  label: string = '';
  icon: string = '';
  onToggle: () => void = () => {};
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';

  build() {
    Row({ space: 10 }) {
      if (this.icon.length > 0) {
        Image($rawfile(this.icon))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
      }

      Text(this.label)
        .fontSize(14)
        .fontColor(this.checked ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1);

      Stack() {
        Circle()
          .width(20)
          .height(20)
          .fill(Color.Transparent)
          .stroke(this.checked ? this.theme_ACCENT : this.theme_BORDER_SOFT)
          .strokeWidth(2)

        if (this.checked) {
          Circle()
            .width(12)
            .height(12)
            .fill(this.theme_ACCENT)
        }
      }
      .width(20)
      .height(20)
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .onClick(() => { this.onToggle(); })
    ;
  }
}

@Component
struct SliderOptionItem {
  @Prop value: number = 0;
  label: string = '';
  min: number = 0;
  max: number = 100;
  step: number = 1;
  onChange: (v: number) => void = () => {};
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#A0AABF';

  build() {
    Column({ space: 4 }) {
      Row() {
        Text(this.label)
          .fontSize(14)
          .fontColor(this.theme_TEXT_PRIMARY)
          .layoutWeight(1);
        Text(`${this.value}`)
          .fontSize(13)
          .fontColor(this.theme_TEXT_SECONDARY);
      }
      .width('100%');

      Slider({
        value: this.value,
        min: this.min,
        max: this.max,
        step: this.step,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor(this.theme_ACCENT)
        .onChange((v: number, mode: SliderChangeMode) => {
          if (mode === SliderChangeMode.Moving || mode === SliderChangeMode.End) {
            this.onChange(Math.round(v));
          }
        });
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 6 });
  }
}

@Component
struct TouchGestureRow {
  @Prop label: string = '';
  @Prop durationText: string = '';
  @Prop actionText: string = '';
  onTimeClick: () => void = () => {};
  onActionClick: () => void = () => {};
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#A0AABF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';

  build() {
    Row() {
      Text(this.label)
        .fontSize(12)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Start);

      Text(this.durationText)
        .fontSize(11)
        .fontColor(this.theme_TEXT_SECONDARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onTimeClick(); });

      Text(this.actionText)
        .fontSize(11)
        .fontColor(this.theme_ACCENT)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .onClick(() => { this.onActionClick(); });
    }
    .width('100%')
    .height(36)
    .padding({ left: 12, right: 12 })
    .border({ width: { bottom: 1 }, color: { bottom: this.theme_BORDER_SOFT } });
  }
}
