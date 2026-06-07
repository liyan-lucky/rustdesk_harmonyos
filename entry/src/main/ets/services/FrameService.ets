import image from '@ohos.multimedia.image';
import { EventBus, EventType, eventBus } from './EventBus';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';

export interface FrameInfo {
  id: number;
  width: number;
  height: number;
  format: string;
  timestamp: number;
  data: ArrayBuffer;
}

export interface FrameStats {
  totalFrames: number;
  droppedFrames: number;
  averageFps: number;
  currentFps: number;
  lastFrameTime: number;
}

class FrameStatsImpl implements FrameStats {
  totalFrames: number = 0;
  droppedFrames: number = 0;
  averageFps: number = 0;
  currentFps: number = 0;
  lastFrameTime: number = 0;
}

function cloneFrameStats(stats: FrameStats): FrameStats {
  const clone = new FrameStatsImpl();
  clone.totalFrames = stats.totalFrames;
  clone.droppedFrames = stats.droppedFrames;
  clone.averageFps = stats.averageFps;
  clone.currentFps = stats.currentFps;
  clone.lastFrameTime = stats.lastFrameTime;
  return clone;
}

export class FrameService {
  private static instance: FrameService;
  private eventBus: EventBus = EventBus.getInstance();

  private currentFrame: image.PixelMap | null = null;
  private currentFrameId: number = 0;
  private lastRenderTime: number = 0;

  private frameQueue: FrameInfo[] = [];
  private readonly MAX_QUEUE_SIZE: number = 5;

  private stats: FrameStats = new FrameStatsImpl();

  private fpsHistory: number[] = [];
  private readonly FPS_HISTORY_SIZE: number = 60;

  private refreshCallback: (() => void) | null = null;
  private isRendering: boolean = false;

  private constructor() {}

  static getInstance(): FrameService {
    if (!FrameService.instance) {
      FrameService.instance = new FrameService();
    }
    return FrameService.instance;
  }

  setRefreshCallback(callback: () => void): void {
    this.refreshCallback = callback;
  }

  clearRefreshCallback(): void {
    this.refreshCallback = null;
  }

  async processFrame(frameData: ArrayBuffer, width: number, height: number): Promise<boolean> {
    const now = Date.now();
    const frameId = ++this.currentFrameId;

    if (this.frameQueue.length >= this.MAX_QUEUE_SIZE) {
      this.frameQueue.shift();
      this.stats.droppedFrames++;
    }

    this.frameQueue.push({
      id: frameId,
      width,
      height,
      format: 'rgba',
      timestamp: now,
      data: frameData
    });

    this.updateStats(now);
    this.eventBus.emit(EventType.FRAME_RECEIVED, { frameId, width, height });

    return true;
  }

  async renderNextFrame(): Promise<image.PixelMap | null> {
    if (this.frameQueue.length === 0) {
      return this.currentFrame;
    }

    this.isRendering = true;

    const frame = this.frameQueue.shift();
    if (!frame) {
      this.isRendering = false;
      return this.currentFrame;
    }

    try {
      const pixelMap = await this.createPixelMap(frame.data, frame.width, frame.height);
      if (pixelMap) {
        if (this.currentFrame) {
          this.currentFrame.release();
        }
        this.currentFrame = pixelMap;
        this.lastRenderTime = Date.now();

        this.eventBus.emit(EventType.FRAME_RENDERED, {
          frameId: frame.id,
          width: frame.width,
          height: frame.height
        });

        if (this.refreshCallback) {
          this.refreshCallback();
        }
      }
      this.isRendering = false;
      return this.currentFrame;
    } catch (error) {
      console.error('[FrameService] Render failed:', error);
      this.isRendering = false;
      return this.currentFrame;
    }
  }

  private async createPixelMap(data: ArrayBuffer, width: number, height: number): Promise<image.PixelMap | null> {
    try {
      const pixelMap = await image.createPixelMap(data, {
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width, height }
      });
      return pixelMap;
    } catch (error) {
      console.error('[FrameService] Create PixelMap failed:', error);
      return null;
    }
  }

  private updateStats(now: number): void {
    this.stats.totalFrames++;
    this.stats.lastFrameTime = now;

    if (this.fpsHistory.length >= this.FPS_HISTORY_SIZE) {
      this.fpsHistory.shift();
    }

    const prevTime = this.fpsHistory.length > 0 ? this.fpsHistory[this.fpsHistory.length - 1] : now;
    const deltaTime = now - prevTime;
    if (deltaTime > 0) {
      const instantFps = 1000 / deltaTime;
      this.fpsHistory.push(now);
      this.stats.currentFps = Math.round(instantFps);

      if (this.fpsHistory.length >= 2) {
        const totalTime = now - this.fpsHistory[0];
        this.stats.averageFps = Math.round((this.fpsHistory.length - 1) * 1000 / totalTime);
      }
    }
  }

  getCurrentFrame(): image.PixelMap | null {
    return this.currentFrame;
  }

  getStats(): FrameStats {
    return cloneFrameStats(this.stats);
  }

  getQueueLength(): number {
    return this.frameQueue.length;
  }

  clearQueue(): void {
    this.frameQueue = [];
  }

  reset(): void {
    this.frameQueue = [];
    if (this.currentFrame) {
      this.currentFrame.release();
      this.currentFrame = null;
    }
    this.currentFrameId = 0;
    this.lastRenderTime = 0;
    this.isRendering = false;
    this.stats = {
      totalFrames: 0,
      droppedFrames: 0,
      averageFps: 0,
      currentFps: 0,
      lastFrameTime: 0
    };
    this.fpsHistory = [];
  }

  hasFrame(): boolean {
    return this.currentFrame !== null;
  }

  getFrameId(): number {
    return this.currentFrameId;
  }
}

export const frameService = FrameService.getInstance();
