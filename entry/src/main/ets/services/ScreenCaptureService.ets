import display from '@ohos.display';
import image from '@ohos.multimedia.image';
import { OfficialSessionTransport } from './OfficialSessionTransport';
import { SessionVideoCodec, SessionVideoFrame } from './OfficialSessionTypes';

export interface ScreenCaptureConfig {
  width: number;
  height: number;
  frameRate: number;
  quality: number;
  codec: SessionVideoCodec;
}

export interface ScreenCaptureEvent {
  type: 'frame_captured' | 'error';
  data?: SessionVideoFrame;
  error?: string;
}

export interface ScreenInfo {
  width: number;
  height: number;
  scale: number;
}

export class ScreenCaptureService {
  private static instance: ScreenCaptureService;
  private isCapturing: boolean = false;
  private config: ScreenCaptureConfig;
  private captureInterval: number = 0;
  private eventListeners: Array<(event: ScreenCaptureEvent) => void> = [];
  private displayInfo: display.Display | null = null;
  private hasScreenCapturePermission: boolean = false;

  private constructor() {
    this.config = {
      width: 1920,
      height: 1080,
      frameRate: 2,
      quality: 80,
      codec: SessionVideoCodec.H264
    };
    this.initDisplayInfo();
  }

  static getInstance(): ScreenCaptureService {
    if (!ScreenCaptureService.instance) {
      ScreenCaptureService.instance = new ScreenCaptureService();
    }
    return ScreenCaptureService.instance;
  }

  private async initDisplayInfo(): Promise<void> {
    try {
      this.displayInfo = await display.getDefaultDisplay();
    } catch (error) {
      console.error('Failed to get display info:', error);
    }
  }

  async startCapture(config?: Partial<ScreenCaptureConfig>): Promise<void> {
    try {
      if (this.isCapturing) {
        return;
      }

      this.applyConfig(config);
      await this.initDisplayInfo();

      if (this.displayInfo) {
        this.config.width = this.displayInfo.width;
        this.config.height = this.displayInfo.height;
      }

      await this.startScreenCaptureSession();

      this.isCapturing = true;
      const intervalMs = Math.max(500, 1000 / Math.max(1, this.config.frameRate));
      this.captureInterval = setInterval(() => {
        this.captureFrame();
      }, intervalMs);
    } catch (error) {
      console.error('Failed to start screen capture:', error);
      throw new Error(error instanceof Error ? error.message : String(error));
    }
  }

  private async startScreenCaptureSession(): Promise<void> {
    this.hasScreenCapturePermission = false;
    throw new Error('Screen capture API is unavailable in the current HarmonyOS SDK/runtime. Real screen capture requires official HarmonyOS AVScreenCapture support which is not yet available in this SDK version.');
  }

  stopCapture(): void {
    if (!this.isCapturing) {
      return;
    }

    this.isCapturing = false;
    if (this.captureInterval > 0) {
      clearInterval(this.captureInterval);
      this.captureInterval = 0;
    }
    this.stopScreenCaptureSession();
  }

  private stopScreenCaptureSession(): void {
    this.hasScreenCapturePermission = false;
  }

  private async captureFrame(): Promise<void> {
    try {
      if (!this.isCapturing) {
        return;
      }
    } catch (error) {
      console.error('Capture frame failed:', error);
      this.dispatchEvent({
        type: 'error',
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  async getScreenInfo(): Promise<ScreenInfo> {
    try {
      await this.initDisplayInfo();
      if (this.displayInfo) {
        return {
          width: this.displayInfo.width,
          height: this.displayInfo.height,
          scale: this.displayInfo.scaledDensity
        };
      }
    } catch (error) {
      console.error('Failed to get screen info:', error);
    }

    return {
      width: this.config.width,
      height: this.config.height,
      scale: 1.0
    };
  }

  updateConfig(config: Partial<ScreenCaptureConfig>): void {
    this.applyConfig(config);
    if (this.isCapturing) {
      this.stopCapture();
      void this.startCapture(this.getConfig());
    }
  }

  getConfig(): ScreenCaptureConfig {
    return {
      width: this.config.width,
      height: this.config.height,
      frameRate: this.config.frameRate,
      quality: this.config.quality,
      codec: this.config.codec
    };
  }

  isCapturingActive(): boolean {
    return this.isCapturing;
  }

  hasInputInjectionPermission(): boolean {
    return this.hasScreenCapturePermission;
  }

  addEventListener(listener: (event: ScreenCaptureEvent) => void): void {
    this.eventListeners.push(listener);
  }

  removeEventListener(listener: (event: ScreenCaptureEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  private dispatchEvent(event: ScreenCaptureEvent): void {
    this.eventListeners.forEach((listener: (event: ScreenCaptureEvent) => void) => {
      try {
        listener(event);
      } catch (error) {
        console.error('Event listener error:', error);
      }
    });
  }

  private applyConfig(config?: Partial<ScreenCaptureConfig>): void {
    if (!config) {
      return;
    }
    if (config.width !== undefined) {
      this.config.width = config.width;
    }
    if (config.height !== undefined) {
      this.config.height = config.height;
    }
    if (config.frameRate !== undefined) {
      this.config.frameRate = config.frameRate;
    }
    if (config.quality !== undefined) {
      this.config.quality = config.quality;
    }
    if (config.codec !== undefined) {
      this.config.codec = config.codec;
    }
  }
}
