import display from '@ohos.display';
import image from '@ohos.multimedia.image';
import media from '@ohos.multimedia.media';
import fileFs from '@ohos.file.fs';
import { AppContextService } from './AppContextService';
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
  private screenRecorder: media.AVScreenCaptureRecorder | null = null;
  private recorderFile: fileFs.File | null = null;
  private recorderFilePath: string = '';

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
    const capturePath = this.resolveRecorderFilePath();
    const recorderFile = fileFs.openSync(
      capturePath,
      fileFs.OpenMode.CREATE | fileFs.OpenMode.TRUNC | fileFs.OpenMode.READ_WRITE
    );
    this.recorderFile = recorderFile;
    this.recorderFilePath = capturePath;

    try {
      const recorder = await media.createAVScreenCaptureRecorder();
      this.screenRecorder = recorder;
      await recorder.init({
        fd: recorderFile.fd,
        frameWidth: this.config.width,
        frameHeight: this.config.height,
        videoBitrate: this.resolveVideoBitrate(),
        preset: media.AVScreenCaptureRecordPreset.SCREEN_RECORD_PRESET_H264_AAC_MP4
      });
      await recorder.startRecording();
      this.hasScreenCapturePermission = true;
    } catch (error) {
      this.stopScreenCaptureSession();
      throw new Error('Screen recording API start failed: ' + (error instanceof Error ? error.message : String(error)));
    }
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
    const recorder = this.screenRecorder;
    const recorderFile = this.recorderFile;
    const recorderPath = this.recorderFilePath;
    this.screenRecorder = null;
    this.recorderFile = null;
    this.recorderFilePath = '';
    this.hasScreenCapturePermission = false;
    if (recorder) {
      void recorder.stopRecording()
        .catch((error: Object | string) => {
          console.warn('AVScreenCaptureRecorder stop failed: ' + JSON.stringify(error));
        })
        .then(() => recorder.release())
        .catch((error: Object | string) => {
          console.warn('AVScreenCaptureRecorder release failed: ' + JSON.stringify(error));
        })
        .then(() => {
          this.closeRecorderFile(recorderFile, recorderPath);
        });
      return;
    }
    this.closeRecorderFile(recorderFile, recorderPath);
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

  private resolveRecorderFilePath(): string {
    const context = AppContextService.getContext();
    if (!context) {
      throw new Error('Screen recording requires UIAbility context.');
    }
    const contextRecord = context as Object as Record<string, string | undefined>;
    const baseDir = (contextRecord.cacheDir ?? contextRecord.tempDir ?? contextRecord.filesDir ?? '').trim();
    if (baseDir.length === 0) {
      throw new Error('Screen recording cache directory is unavailable.');
    }
    return baseDir + '/rustdesk_screen_recording_probe.mp4';
  }

  private resolveVideoBitrate(): number {
    const pixels = Math.max(1, this.config.width * this.config.height);
    const fps = Math.max(1, this.config.frameRate);
    const quality = Math.max(30, Math.min(100, this.config.quality));
    return Math.max(1000000, Math.floor(pixels * fps * quality / 24));
  }

  private closeRecorderFile(recorderFile: fileFs.File | null, recorderPath: string): void {
    if (recorderFile) {
      try {
        fileFs.closeSync(recorderFile);
      } catch (_e) {}
    }
    if (recorderPath.length > 0) {
      try {
        fileFs.unlinkSync(recorderPath);
      } catch (_e) {}
    }
  }
}
