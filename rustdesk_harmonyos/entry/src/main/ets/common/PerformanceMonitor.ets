/**
 * 性能监控工具类
 * 用于监控帧处理性能，识别瓶颈
 */
import { image } from '@kit.ImageKit';

export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null;
  
  // 性能统计数据
  private stats: PerformanceStats = {
    framePullCount: 0,
    framePullSuccess: 0,
    framePullFailed: 0,
    framePullTimeTotal: 0,
    framePullTimeAvg: 0,
    framePullTimeMax: 0,
    
    pixelMapCreateCount: 0,
    pixelMapCreateTimeTotal: 0,
    pixelMapCreateTimeAvg: 0,
    pixelMapCreateTimeMax: 0,
    
    uiUpdateCount: 0,
    uiUpdateTimeTotal: 0,
    uiUpdateTimeAvg: 0,
    uiUpdateTimeMax: 0,
    
    totalFrameCount: 0,
    lastFrameId: 0,
    lastUpdateTime: 0
  };
  
  // 帧缓冲队列
  private frameBuffer: Map<number, FrameBufferEntry> = new Map();
  private maxBufferSize: number = 3; // 最大缓冲3帧
  
  private constructor() {}
  
  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }
  
  /**
   * 记录帧拉取开始
   */
  startFramePull(): number {
    return performance.now();
  }
  
  /**
   * 记录帧拉取结束
   */
  endFramePull(startTime: number, success: boolean, frameId?: number): void {
    const duration = performance.now() - startTime;
    
    this.stats.framePullCount++;
    this.stats.framePullTimeTotal += duration;
    this.stats.framePullTimeAvg = this.stats.framePullTimeTotal / this.stats.framePullCount;
    
    if (duration > this.stats.framePullTimeMax) {
      this.stats.framePullTimeMax = duration;
    }
    
    if (success) {
      this.stats.framePullSuccess++;
      if (frameId !== undefined) {
        this.stats.lastFrameId = frameId;
      }
    } else {
      this.stats.framePullFailed++;
    }
    
    this.stats.lastUpdateTime = performance.now();
    
    // 每10次记录一次性能日志
    if (this.stats.framePullCount % 10 === 0) {
      this.logPerformance();
    }
  }
  
  /**
   * 记录PixelMap创建时间
   */
  recordPixelMapCreate(duration: number): void {
    this.stats.pixelMapCreateCount++;
    this.stats.pixelMapCreateTimeTotal += duration;
    this.stats.pixelMapCreateTimeAvg = this.stats.pixelMapCreateTimeTotal / this.stats.pixelMapCreateCount;
    
    if (duration > this.stats.pixelMapCreateTimeMax) {
      this.stats.pixelMapCreateTimeMax = duration;
    }
  }
  
  /**
   * 记录UI更新时间
   */
  recordUiUpdate(duration: number): void {
    this.stats.uiUpdateCount++;
    this.stats.uiUpdateTimeTotal += duration;
    this.stats.uiUpdateTimeAvg = this.stats.uiUpdateTimeTotal / this.stats.uiUpdateCount;
    
    if (duration > this.stats.uiUpdateTimeMax) {
      this.stats.uiUpdateTimeMax = duration;
    }
  }
  
  /**
   * 增加总帧数
   */
  incrementFrameCount(): void {
    this.stats.totalFrameCount++;
  }
  
  /**
   * 获取性能统计
   */
  getStats(): PerformanceStats {
    return { ...this.stats };
  }
  
  /**
   * 获取帧成功率
   */
  getFrameSuccessRate(): number {
    if (this.stats.framePullCount === 0) return 0;
    return (this.stats.framePullSuccess / this.stats.framePullCount) * 100;
  }
  
  /**
   * 获取平均帧处理时间
   */
  getAverageFrameProcessingTime(): number {
    const totalTime = this.stats.framePullTimeAvg + this.stats.pixelMapCreateTimeAvg + this.stats.uiUpdateTimeAvg;
    return totalTime;
  }
  
  /**
   * 记录性能日志
   */
  private logPerformance(): void {
    const successRate = this.getFrameSuccessRate();
    const avgProcessingTime = this.getAverageFrameProcessingTime();
    
    console.log(`[PerformanceMonitor] Frame success rate: ${successRate.toFixed(1)}%`);
    console.log(`[PerformanceMonitor] Avg pull time: ${this.stats.framePullTimeAvg.toFixed(2)}ms`);
    console.log(`[PerformanceMonitor] Avg PixelMap create time: ${this.stats.pixelMapCreateTimeAvg.toFixed(2)}ms`);
    console.log(`[PerformanceMonitor] Avg UI update time: ${this.stats.uiUpdateTimeAvg.toFixed(2)}ms`);
    console.log(`[PerformanceMonitor] Total frame processed: ${this.stats.totalFrameCount}`);
    console.log(`[PerformanceMonitor] Last frame ID: ${this.stats.lastFrameId}`);
    
    // 警告：如果成功率低于50%或处理时间超过50ms
    if (successRate < 50) {
      console.warn(`[PerformanceMonitor] WARNING: Low frame success rate: ${successRate.toFixed(1)}%`);
    }
    if (avgProcessingTime > 50) {
      console.warn(`[PerformanceMonitor] WARNING: High frame processing time: ${avgProcessingTime.toFixed(2)}ms`);
    }
  }
  
  /**
   * 重置统计数据
   */
  reset(): void {
    this.stats = {
      framePullCount: 0,
      framePullSuccess: 0,
      framePullFailed: 0,
      framePullTimeTotal: 0,
      framePullTimeAvg: 0,
      framePullTimeMax: 0,
      
      pixelMapCreateCount: 0,
      pixelMapCreateTimeTotal: 0,
      pixelMapCreateTimeAvg: 0,
      pixelMapCreateTimeMax: 0,
      
      uiUpdateCount: 0,
      uiUpdateTimeTotal: 0,
      uiUpdateTimeAvg: 0,
      uiUpdateTimeMax: 0,
      
      totalFrameCount: 0,
      lastFrameId: 0,
      lastUpdateTime: 0
    };
  }
  
  /**
   * 帧缓冲管理
   */
  addToBuffer(frameId: number, frameData: image.PixelMap | null): void {
    // 如果缓冲区已满，移除最旧的帧
    if (this.frameBuffer.size >= this.maxBufferSize) {
      const oldestKey = Array.from(this.frameBuffer.keys())[0];
      this.frameBuffer.delete(oldestKey);
    }
    
    this.frameBuffer.set(frameId, {
      frameId,
      data: frameData,
      timestamp: performance.now()
    });
  }
  
  /**
   * 从缓冲区获取帧
   */
  getFromBuffer(frameId: number): image.PixelMap | null {
    return this.frameBuffer.get(frameId)?.data || null;
  }
  
  /**
   * 检查缓冲区中是否有指定帧
   */
  hasInBuffer(frameId: number): boolean {
    return this.frameBuffer.has(frameId);
  }
  
  /**
   * 清理过期的缓冲区帧（超过1秒）
   */
  cleanupBuffer(): void {
    const now = performance.now();
    const expiredKeys: number[] = [];
    
    for (const [frameId, entry] of this.frameBuffer.entries()) {
      if (now - entry.timestamp > 1000) { // 1秒过期
        expiredKeys.push(frameId);
      }
    }
    
    for (const key of expiredKeys) {
      this.frameBuffer.delete(key);
    }
    
    if (expiredKeys.length > 0) {
      console.log(`[PerformanceMonitor] Cleaned up ${expiredKeys.length} expired frames from buffer`);
    }
  }
}

interface PerformanceStats {
  framePullCount: number;
  framePullSuccess: number;
  framePullFailed: number;
  framePullTimeTotal: number;
  framePullTimeAvg: number;
  framePullTimeMax: number;
  
  pixelMapCreateCount: number;
  pixelMapCreateTimeTotal: number;
  pixelMapCreateTimeAvg: number;
  pixelMapCreateTimeMax: number;
  
  uiUpdateCount: number;
  uiUpdateTimeTotal: number;
  uiUpdateTimeAvg: number;
  uiUpdateTimeMax: number;
  
  totalFrameCount: number;
  lastFrameId: number;
  lastUpdateTime: number;
}

interface FrameBufferEntry {
  frameId: number;
  data: image.PixelMap | null;
  timestamp: number;
}