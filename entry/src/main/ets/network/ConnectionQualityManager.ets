/**
 * 连接质量管理器
 * 负责监控和自适应调整连接质量
 */
import { SessionVideoCodec } from '../services/OfficialSessionTypes';

/**
 * 连接质量级别
 */
export enum ConnectionQuality {
  EXCELLENT = 'excellent',
  GOOD = 'good',
  FAIR = 'fair',
  POOR = 'poor',
  VERY_POOR = 'very_poor'
}

/**
 * 网络状态
 */
export interface NetworkStatus {
  latency: number;           // 延迟 (ms)
  packetLoss: number;        // 丢包率 (%)
  bandwidth: number;         // 带宽 (Kbps)
  jitter: number;           // 抖动 (ms)
  quality: ConnectionQuality;
}

/**
 * 质量调整建议
 */
export interface QualityAdjustment {
  videoCodec: SessionVideoCodec;
  resolution: { width: number; height: number };
  frameRate: number;
  bitrate: number;          // Kbps
  enableAudio: boolean;
  enableFileTransfer: boolean;
}

/**
 * 连接质量事件
 */
export interface ConnectionQualityEvent {
  type: 'quality_changed' | 'network_status_updated' | 'adjustment_applied' | 'error';
  quality?: ConnectionQuality;
  networkStatus?: NetworkStatus;
  adjustment?: QualityAdjustment;
  error?: string;
}

/**
 * 连接质量管理器
 */
export class ConnectionQualityManager {
  private static instance: ConnectionQualityManager;
  private currentQuality: ConnectionQuality = ConnectionQuality.GOOD;
  private networkStatus: NetworkStatus;
  private eventListeners: Array<(event: ConnectionQualityEvent) => void> = [];
  private monitoringInterval: number = 0;
  private isMonitoring: boolean = false;

  // 质量阈值配置
  private readonly qualityThresholds = {
    excellent: { latency: 50, packetLoss: 0.5, bandwidth: 5000, jitter: 10 },
    good: { latency: 100, packetLoss: 1.0, bandwidth: 2000, jitter: 20 },
    fair: { latency: 200, packetLoss: 2.0, bandwidth: 1000, jitter: 40 },
    poor: { latency: 300, packetLoss: 5.0, bandwidth: 500, jitter: 80 }
  };

  // 质量调整策略
  private readonly qualityStrategies: Map<ConnectionQuality, QualityAdjustment> = new Map([
    [ConnectionQuality.EXCELLENT, {
      videoCodec: SessionVideoCodec.H265,
      resolution: { width: 1920, height: 1080 },
      frameRate: 60,
      bitrate: 5000,
      enableAudio: true,
      enableFileTransfer: true
    }],
    [ConnectionQuality.GOOD, {
      videoCodec: SessionVideoCodec.H264,
      resolution: { width: 1280, height: 720 },
      frameRate: 30,
      bitrate: 2000,
      enableAudio: true,
      enableFileTransfer: true
    }],
    [ConnectionQuality.FAIR, {
      videoCodec: SessionVideoCodec.H264,
      resolution: { width: 854, height: 480 },
      frameRate: 24,
      bitrate: 1000,
      enableAudio: true,
      enableFileTransfer: false
    }],
    [ConnectionQuality.POOR, {
      videoCodec: SessionVideoCodec.VP8,
      resolution: { width: 640, height: 360 },
      frameRate: 15,
      bitrate: 500,
      enableAudio: false,
      enableFileTransfer: false
    }],
    [ConnectionQuality.VERY_POOR, {
      videoCodec: SessionVideoCodec.VP8,
      resolution: { width: 320, height: 240 },
      frameRate: 10,
      bitrate: 250,
      enableAudio: false,
      enableFileTransfer: false
    }]
  ]);

  private constructor() {
    this.networkStatus = {
      latency: 0,
      packetLoss: 0,
      bandwidth: 0,
      jitter: 0,
      quality: ConnectionQuality.GOOD
    };
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ConnectionQualityManager {
    if (!ConnectionQualityManager.instance) {
      ConnectionQualityManager.instance = new ConnectionQualityManager();
    }
    return ConnectionQualityManager.instance;
  }

  /**
   * 开始监控连接质量
   */
  startMonitoring(intervalMs: number = 1000): void {
    if (this.isMonitoring) {
      console.warn('Connection quality monitoring already started');
      return;
    }

    this.isMonitoring = true;

    // 开始定期监控
    this.monitoringInterval = setInterval(() => {
      this.measureNetworkStatus();
    }, intervalMs);

    console.log('Connection quality monitoring started');
  }

  /**
   * 停止监控连接质量
   */
  stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;

    if (this.monitoringInterval > 0) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = 0;
    }

    console.log('Connection quality monitoring stopped');
  }

  /**
   * 测量网络状态
   */
  private async measureNetworkStatus(): Promise<void> {
    try {
      // 这里应该实现真实的网络状态测量
      // 包括延迟、丢包率、带宽、抖动等

      // 模拟测量结果
      const latency = Math.random() * 150 + 50; // 50-200ms
      const packetLoss = Math.random() * 2; // 0-2%
      const bandwidth = Math.random() * 4000 + 1000; // 1000-5000 Kbps
      const jitter = Math.random() * 30 + 5; // 5-35ms

      this.networkStatus = {
        latency,
        packetLoss,
        bandwidth,
        jitter,
        quality: this.calculateQuality(latency, packetLoss, bandwidth, jitter)
      };

      // 检查质量是否变化
      if (this.networkStatus.quality !== this.currentQuality) {
        this.currentQuality = this.networkStatus.quality;

        // 分发质量变化事件
        this.dispatchEvent({
          type: 'quality_changed',
          quality: this.currentQuality
        });

        // 应用质量调整策略
        this.applyQualityAdjustment();
      }

      // 分发网络状态更新事件
      this.dispatchEvent({
        type: 'network_status_updated',
        networkStatus: this.networkStatus
      });
    } catch (error) {
      console.error('Measure network status failed:', error);
      this.dispatchEvent({
        type: 'error',
        error: '测量网络状态失败: ' + error
      });
    }
  }

  /**
   * 计算连接质量
   */
  private calculateQuality(
    latency: number,
    packetLoss: number,
    bandwidth: number,
    jitter: number
  ): ConnectionQuality {
    const thresholds = this.qualityThresholds;

    // 检查优秀质量
    if (latency <= thresholds.excellent.latency &&
        packetLoss <= thresholds.excellent.packetLoss &&
        bandwidth >= thresholds.excellent.bandwidth &&
        jitter <= thresholds.excellent.jitter) {
      return ConnectionQuality.EXCELLENT;
    }

    // 检查良好质量
    if (latency <= thresholds.good.latency &&
        packetLoss <= thresholds.good.packetLoss &&
        bandwidth >= thresholds.good.bandwidth &&
        jitter <= thresholds.good.jitter) {
      return ConnectionQuality.GOOD;
    }

    // 检查一般质量
    if (latency <= thresholds.fair.latency &&
        packetLoss <= thresholds.fair.packetLoss &&
        bandwidth >= thresholds.fair.bandwidth &&
        jitter <= thresholds.fair.jitter) {
      return ConnectionQuality.FAIR;
    }

    // 检查较差质量
    if (latency <= thresholds.poor.latency &&
        packetLoss <= thresholds.poor.packetLoss &&
        bandwidth >= thresholds.poor.bandwidth &&
        jitter <= thresholds.poor.jitter) {
      return ConnectionQuality.POOR;
    }

    // 非常差的质量
    return ConnectionQuality.VERY_POOR;
  }

  /**
   * 应用质量调整策略
   */
  private applyQualityAdjustment(): void {
    const adjustment = this.qualityStrategies.get(this.currentQuality);

    if (adjustment) {
      // 分发调整应用事件
      this.dispatchEvent({
        type: 'adjustment_applied',
        adjustment
      });

      console.log('Quality adjustment applied:', adjustment);
    }
  }

  /**
   * 获取当前连接质量
   */
  getCurrentQuality(): ConnectionQuality {
    return this.currentQuality;
  }

  /**
   * 获取当前网络状态
   */
  getNetworkStatus(): NetworkStatus {
    return {
      latency: this.networkStatus.latency,
      packetLoss: this.networkStatus.packetLoss,
      bandwidth: this.networkStatus.bandwidth,
      jitter: this.networkStatus.jitter,
      quality: this.networkStatus.quality
    };
  }

  /**
   * 获取质量调整建议
   */
  getQualityAdjustment(): QualityAdjustment | undefined {
    return this.qualityStrategies.get(this.currentQuality);
  }

  /**
   * 手动更新网络状态
   */
  updateNetworkStatus(status: Partial<NetworkStatus>): void {
    if (status.latency !== undefined) {
      this.networkStatus.latency = status.latency;
    }
    if (status.packetLoss !== undefined) {
      this.networkStatus.packetLoss = status.packetLoss;
    }
    if (status.bandwidth !== undefined) {
      this.networkStatus.bandwidth = status.bandwidth;
    }
    if (status.jitter !== undefined) {
      this.networkStatus.jitter = status.jitter;
    }

    // 重新计算质量
    const newQuality = this.calculateQuality(
      this.networkStatus.latency,
      this.networkStatus.packetLoss,
      this.networkStatus.bandwidth,
      this.networkStatus.jitter
    );

    if (newQuality !== this.currentQuality) {
      this.currentQuality = newQuality;
      this.networkStatus.quality = newQuality;

      // 分发质量变化事件
      this.dispatchEvent({
        type: 'quality_changed',
        quality: this.currentQuality
      });

      // 应用质量调整策略
      this.applyQualityAdjustment();
    }

    // 分发网络状态更新事件
    this.dispatchEvent({
      type: 'network_status_updated',
      networkStatus: this.networkStatus
    });
  }

  /**
   * 是否正在监控
   */
  isMonitoringActive(): boolean {
    return this.isMonitoring;
  }

  /**
   * 添加事件监听器
   */
  addEventListener(listener: (event: ConnectionQualityEvent) => void): void {
    this.eventListeners.push(listener);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(listener: (event: ConnectionQualityEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  /**
   * 分发事件
   */
  private dispatchEvent(event: ConnectionQualityEvent): void {
    this.eventListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('Event listener error:', error);
      }
    });
  }

  /**
   * 格式化连接质量文本
   */
  static formatQuality(quality: ConnectionQuality): string {
    switch (quality) {
      case ConnectionQuality.EXCELLENT:
        return '优秀';
      case ConnectionQuality.GOOD:
        return '良好';
      case ConnectionQuality.FAIR:
        return '一般';
      case ConnectionQuality.POOR:
        return '较差';
      case ConnectionQuality.VERY_POOR:
        return '很差';
      default:
        return '未知';
    }
  }

  /**
   * 获取质量颜色
   */
  static getQualityColor(quality: ConnectionQuality): string {
    switch (quality) {
      case ConnectionQuality.EXCELLENT:
        return '#047857'; // 绿色
      case ConnectionQuality.GOOD:
        return '#059669'; // 深绿色
      case ConnectionQuality.FAIR:
        return '#D97706'; // 橙色
      case ConnectionQuality.POOR:
        return '#DC2626'; // 红色
      case ConnectionQuality.VERY_POOR:
        return '#991B1B'; // 深红色
      default:
        return '#6B7280'; // 灰色
    }
  }
}
