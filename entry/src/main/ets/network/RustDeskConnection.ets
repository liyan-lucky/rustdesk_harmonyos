import socket from '@ohos.net.socket';
import { AppDataService, SettingsState } from '../services/AppDataService';
import { ClipboardService } from '../services/ClipboardService';
import { OfficialRustDeskBridge } from '../services/OfficialRustDeskBridge';
import { OfficialSessionTransport } from '../services/OfficialSessionTransport';
import {
  SessionClipboardData,
  SessionKeyboardInput,
  SessionMouseInput,
  SessionVideoFrame
} from '../services/OfficialSessionTypes';

export enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  AUTHENTICATING = 'authenticating',
  AUTHENTICATED = 'authenticated',
  ERROR = 'error'
}

export enum ConnectionEventType {
  STATE_CHANGED = 'state_changed',
  LOGIN_SUCCESS = 'login_success',
  LOGIN_FAILED = 'login_failed',
  VIDEO_FRAME_RECEIVED = 'video_frame_received',
  ERROR = 'error',
  DISCONNECTED = 'disconnected'
}

export interface OfficialLoginResponse {
  success: boolean;
  error?: string;
  peer_id?: string;
  peer_username?: string;
  peer_hostname?: string;
}

export interface ConnectionEvent {
  type: ConnectionEventType;
  state?: ConnectionState;
  loginResponse?: OfficialLoginResponse;
  videoFrame?: SessionVideoFrame;
  error?: string;
}

export interface ConnectionConfig {
  host: string;
  port: number;
  deviceId: string;
  password: string;
  useRelay: boolean;
}

export class RustDeskConnection {
  private static instance: RustDeskConnection;
  private socket: socket.TCPSocket | null = null;
  private state: ConnectionState = ConnectionState.DISCONNECTED;
  private eventListeners: Map<ConnectionEventType, Array<(event: ConnectionEvent) => void>> = new Map();
  private isConnected: boolean = false;
  private sessionPollTimer: number = 0;
  private sessionPollAttempts: number = 0;
  private readonly maxSessionPollAttempts: number = 20;
  private clipboardService: ClipboardService = ClipboardService.getInstance();
  private appData: AppDataService = AppDataService.getInstance();
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();

  private constructor() {
    this.initializeEventListeners();
  }

  static getInstance(): RustDeskConnection {
    if (!RustDeskConnection.instance) {
      RustDeskConnection.instance = new RustDeskConnection();
    }
    return RustDeskConnection.instance;
  }

  private initializeEventListeners(): void {
    const eventTypes: ConnectionEventType[] = [
      ConnectionEventType.STATE_CHANGED,
      ConnectionEventType.LOGIN_SUCCESS,
      ConnectionEventType.LOGIN_FAILED,
      ConnectionEventType.VIDEO_FRAME_RECEIVED,
      ConnectionEventType.ERROR,
      ConnectionEventType.DISCONNECTED
    ];
    eventTypes.forEach((type: ConnectionEventType) => {
      if (!this.eventListeners.has(type)) {
        this.eventListeners.set(type, []);
      }
    });
  }

  async connect(config: ConnectionConfig): Promise<void> {
    try {
      this.setState(ConnectionState.CONNECTING);
      const settings = this.appData.getSettings();
      await this.tryOfficialBridgeConnect(config, settings);
    } catch (error) {
      console.error('Connection failed:', error);
      this.clearSessionPollTimer();
      this.closeLegacySocket();
      this.isConnected = false;
      this.setState(ConnectionState.ERROR);
      this.dispatchEvent({
        type: ConnectionEventType.ERROR,
        error: error instanceof Error ? error.message : String(error)
      });
      throw new Error(error instanceof Error ? error.message : String(error));
    }
  }

  disconnect(): void {
    try {
      this.clearSessionPollTimer();
      this.closeLegacySocket();
      OfficialSessionTransport.closeSession();
      this.isConnected = false;
      this.setState(ConnectionState.DISCONNECTED);
      this.dispatchEvent({
        type: ConnectionEventType.DISCONNECTED
      });
    } catch (error) {
      console.error('Disconnect failed:', error);
    }
  }

  async sendMouseInput(input: SessionMouseInput): Promise<void> {
    if (!this.isConnectionActive()) {
      throw new Error('官方会话尚未激活');
    }
    const sent = OfficialSessionTransport.sendMouseInput(input);
    if (!sent) {
      console.info('鼠标输入正在等待官方原生桥接传输层接管。', JSON.stringify(input));
    }
  }

  async sendKeyboardInput(input: SessionKeyboardInput): Promise<void> {
    if (!this.isConnectionActive()) {
      throw new Error('官方会话尚未激活');
    }
    const sent = OfficialSessionTransport.sendKeyboardInput(input);
    if (!sent) {
      console.info('键盘输入正在等待官方原生桥接传输层接管。', JSON.stringify(input));
    }
  }

  async sendClipboardData(data: SessionClipboardData): Promise<void> {
    if (!this.isConnectionActive()) {
      throw new Error('官方会话尚未激活');
    }
    const sent = OfficialSessionTransport.sendClipboardData(data);
    if (!sent) {
      console.info('剪贴板同步正在等待官方原生桥接传输层接管。', JSON.stringify({
        timestamp: data.timestamp,
        contentLength: data.content.length
      }));
    }
  }

  getState(): ConnectionState {
    return this.state;
  }

  isConnectionActive(): boolean {
    return this.isConnected && this.state === ConnectionState.AUTHENTICATED;
  }

  addEventListener(type: ConnectionEventType, listener: (event: ConnectionEvent) => void): void {
    const listeners = this.eventListeners.get(type);
    if (listeners) {
      listeners.push(listener);
    }
  }

  removeEventListener(type: ConnectionEventType, listener: (event: ConnectionEvent) => void): void {
    const listeners = this.eventListeners.get(type);
    if (listeners) {
      const index = listeners.indexOf(listener);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  }

  private async tryOfficialBridgeConnect(config: ConnectionConfig, settings: SettingsState): Promise<void> {
    await this.officialBridge.connectToPeer(config.deviceId, config.password, settings);
    const bridgeState = await this.officialBridge.refresh(settings);
    this.isConnected = true;
    this.setState(ConnectionState.CONNECTED);

    if (bridgeState.sessionStage === 'error') {
      this.setState(ConnectionState.ERROR);
      this.dispatchEvent({
        type: ConnectionEventType.LOGIN_FAILED,
        error: bridgeState.lastError || 'Official bridge connect failed'
      });
      throw new Error(bridgeState.lastError || 'Official bridge connect failed');
    }

    this.setState(ConnectionState.AUTHENTICATING);
    this.startSessionPollTimer(config.deviceId);
  }

  private setState(state: ConnectionState): void {
    this.state = state;
    this.dispatchEvent({
      type: ConnectionEventType.STATE_CHANGED,
      state
    });
  }

  private dispatchEvent(event: ConnectionEvent): void {
    const listeners = this.eventListeners.get(event.type);
    if (listeners) {
      listeners.forEach((listener) => {
        try {
          listener(event);
        } catch (error) {
          console.error('Event listener error:', error);
        }
      });
    }
  }

  private startSessionPollTimer(deviceId: string): void {
    this.clearSessionPollTimer();
    this.sessionPollAttempts = 0;
    this.sessionPollTimer = setInterval(async () => {
      const settings = this.appData.getSettings();
      const bridgeState = await this.officialBridge.refresh(settings);
      this.sessionPollAttempts += 1;

      if (bridgeState.sessionStage === 'error') {
        this.clearSessionPollTimer();
        this.isConnected = false;
        this.setState(ConnectionState.ERROR);
        this.dispatchEvent({
          type: ConnectionEventType.LOGIN_FAILED,
          error: bridgeState.lastError || 'Official bridge reported a session error'
        });
        return;
      }

      if (bridgeState.sessionStage === 'connected') {
        this.clearSessionPollTimer();
        this.setState(ConnectionState.AUTHENTICATED);
        this.dispatchEvent({
          type: ConnectionEventType.LOGIN_SUCCESS,
          loginResponse: {
            success: true,
            peer_id: deviceId
          }
        });
        return;
      }

      if (this.sessionPollAttempts >= this.maxSessionPollAttempts) {
        this.clearSessionPollTimer();
        this.isConnected = false;
        this.setState(ConnectionState.ERROR);
        this.dispatchEvent({
          type: ConnectionEventType.LOGIN_FAILED,
          error: 'Official native bridge did not confirm a connected session in time'
        });
      }
    }, 800);
  }

  private clearSessionPollTimer(): void {
    if (this.sessionPollTimer > 0) {
      clearInterval(this.sessionPollTimer);
      this.sessionPollTimer = 0;
    }
    this.sessionPollAttempts = 0;
  }

  private closeLegacySocket(): void {
    if (!this.socket) {
      return;
    }
    try {
      this.socket.close();
    } catch (error) {
      console.error('Close legacy socket failed:', error);
    }
    this.socket = null;
  }

  async debugApplyIncomingClipboard(content: string): Promise<void> {
    await this.clipboardService.setClipboardContent(content);
  }
}
