/**
 * 音频服务
 * 负责录制本地音频并传输到远程
 * 对应 Android 版本的 AudioRecordHandle.kt
 */
import audio from '@ohos.multimedia.audio';
import { OfficialSessionTransport } from './OfficialSessionTransport';
import { SessionAudioCodec, SessionAudioFrame, SessionAudioFrameImpl } from './OfficialSessionTypes';
import { I18nService } from './I18nService';

/**
 * 音频录制配置
 */
export interface AudioCaptureConfig {
  sampleRate: number;
  channels: number;
  bitRate: number;
  codec: SessionAudioCodec;
  bufferSize: number;
}

class AudioCaptureConfigImpl implements AudioCaptureConfig {
  sampleRate: number = 48000;
  channels: number = 1;
  bitRate: number = 128000;
  codec: SessionAudioCodec = SessionAudioCodec.OPUS;
  bufferSize: number = 4096;
}

/**
 * 音频传输事件
 */
export interface AudioEvent {
  type: 'audio_captured' | 'error';
  data?: SessionAudioFrame;
  error?: string;
}

class AudioEventImpl implements AudioEvent {
  type: 'audio_captured' | 'error' = 'error';
  data?: SessionAudioFrame;
  error?: string;
}

export interface ConfigValidationResult {
  valid: boolean;
  message: string;
}

class ConfigValidationResultImpl implements ConfigValidationResult {
  valid: boolean = false;
  message: string = '';
}

/**
 * 音频服务
 */
export class AudioService {
  private static instance: AudioService;
  private isRecording: boolean = false;
  private config: AudioCaptureConfig;
  private audioCapturer: audio.AudioCapturer | null = null;
  private eventListeners: Array<(event: AudioEvent) => void> = [];

  private constructor() {
    this.config = {
      sampleRate: 48000,
      channels: 1,
      bitRate: 128000,
      codec: SessionAudioCodec.OPUS,
      bufferSize: 4096
    };
  }

  /**
   * 获取单例实例
   */
  static getInstance(): AudioService {
    if (!AudioService.instance) {
      AudioService.instance = new AudioService();
    }
    return AudioService.instance;
  }

  private applyConfig(config: Partial<AudioCaptureConfig>): void {
    if (config.sampleRate !== undefined) {
      this.config.sampleRate = config.sampleRate;
    }
    if (config.channels !== undefined) {
      this.config.channels = config.channels;
    }
    if (config.bitRate !== undefined) {
      this.config.bitRate = config.bitRate;
    }
    if (config.bufferSize !== undefined) {
      this.config.bufferSize = config.bufferSize;
    }
  }

  /**
   * 开始音频录制
   */
  async startCapture(config?: Partial<AudioCaptureConfig>): Promise<void> {
    try {
      if (this.isRecording) {
        console.warn('Audio capture already started');
        return;
      }

      // 更新配置
      if (config) {
        this.applyConfig(config);
      }

      // 创建音频录制器
      const audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      };

      const audioCapturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      };

      const audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo
      };

      this.audioCapturer = await audio.createAudioCapturer(audioCapturerOptions);

      await this.audioCapturer.start();

      this.isRecording = true;

      // 开始读取音频数据
      this.startReadingAudioData();

      console.log('Audio capture started with config:', this.config);
    } catch (error) {
      console.error('Failed to start audio capture:', error);
      const event = new AudioEventImpl();
      event.type = 'error';
      event.error = I18nService.getInstance().translate('Audio capture start failed') + ': ' + error;
      this.dispatchEvent(event);
      throw new Error(I18nService.getInstance().translate('Audio capture start failed') + ': ' + error);
    }
  }

  /**
   * 停止音频录制
   */
  async stopCapture(): Promise<void> {
    try {
      if (!this.isRecording || !this.audioCapturer) {
        return;
      }

      this.isRecording = false;

      await this.audioCapturer.stop();
      await this.audioCapturer.release();
      this.audioCapturer = null;

      console.log('Audio capture stopped');
    } catch (error) {
      console.error('Failed to stop audio capture:', error);
    }
  }

  /**
   * 开始读取音频数据
   */
  private async startReadingAudioData(): Promise<void> {
    if (!this.audioCapturer) {
      return;
    }

    try {
      const bufferSize = this.config.bufferSize;

      let consecutiveErrors = 0;

      while (this.isRecording) {
        try {
          const buffer = await this.audioCapturer.read(bufferSize, true);
          consecutiveErrors = 0;

          if (buffer && buffer.byteLength > 0) {
            const audioFrame = new SessionAudioFrameImpl();
            audioFrame.codec = this.config.codec;
            audioFrame.sampleRate = this.config.sampleRate;
            audioFrame.channels = this.config.channels;
            audioFrame.data = buffer;
            audioFrame.timestamp = Date.now();

            OfficialSessionTransport.sendAudioFrameMetadata(audioFrame);

            const event = new AudioEventImpl();
            event.type = 'audio_captured';
            event.data = audioFrame;
            this.dispatchEvent(event);
          } else {
            await new Promise<void>((resolve: Function) => setTimeout(resolve, 10));
          }
        } catch (error) {
          consecutiveErrors++;
          console.error('Read audio data failed:', error);
          if (!this.isRecording || consecutiveErrors > 10) {
            break;
          }
          await new Promise<void>((resolve: Function) => setTimeout(resolve, Math.min(100 * consecutiveErrors, 1000)));
        }
      }
    } catch (error) {
      console.error('Start reading audio data failed:', error);
      this.dispatchEvent({
        type: 'error',
        error: I18nService.getInstance().translate('Audio read failed') + ': ' + error
      });
    }
  }

  /**
   * 更新录制配置
   */
  async updateConfig(config: Partial<AudioCaptureConfig>): Promise<void> {
    this.applyConfig(config);

    if (this.isRecording) {
      await this.stopCapture();
      await this.startCapture(this.config);
    }
  }

  /**
   * 获取当前配置
   */
  getConfig(): AudioCaptureConfig {
    const config = new AudioCaptureConfigImpl();
    config.sampleRate = this.config.sampleRate;
    config.channels = this.config.channels;
    config.bitRate = this.config.bitRate;
    config.bufferSize = this.config.bufferSize;
    config.codec = this.config.codec;
    return config;
  }

  /**
   * 是否正在录制
   */
  isCapturingActive(): boolean {
    return this.isRecording;
  }

  /**
   * 添加事件监听器
   */
  addEventListener(listener: (event: AudioEvent) => void): void {
    this.eventListeners.push(listener);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(listener: (event: AudioEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  /**
   * 分发事件
   */
  private dispatchEvent(event: AudioEvent): void {
    this.eventListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('Event listener error:', error);
      }
    });
  }

  /**
   * 获取支持的采样率列表
   */
  static getSupportedSampleRates(): number[] {
    return [8000, 16000, 32000, 44100, 48000];
  }

  /**
   * 获取支持的声道数列表
   */
  static getSupportedChannels(): number[] {
    return [1, 2];
  }

  /**
   * 获取支持的比特率列表
   */
  static getSupportedBitRates(): number[] {
    return [64000, 96000, 128000, 192000, 256000];
  }

  /**
   * 验证音频配置
   */
  static validateConfig(config: AudioCaptureConfig): ConfigValidationResult {
    const result = new ConfigValidationResultImpl();
    
    if (!AudioService.getSupportedSampleRates().includes(config.sampleRate)) {
      result.valid = false;
      result.message = I18nService.getInstance().translate('Unsupported sample rate');
      return result;
    }

    if (!AudioService.getSupportedChannels().includes(config.channels)) {
      result.valid = false;
      result.message = I18nService.getInstance().translate('Unsupported channel count');
      return result;
    }

    if (!AudioService.getSupportedBitRates().includes(config.bitRate)) {
      result.valid = false;
      result.message = I18nService.getInstance().translate('Unsupported bitrate');
      return result;
    }

    result.valid = true;
    result.message = I18nService.getInstance().translate('Configuration valid');
    return result;
  }

  /**
   * 计算音频帧大小
   */
  static calculateFrameSize(sampleRate: number, channels: number, durationMs: number): number {
    // 每个采样点 16bit (2字节)
    const bytesPerSample = 2;
    const samplesPerFrame = (sampleRate * durationMs) / 1000;
    return Math.floor(samplesPerFrame * channels * bytesPerSample);
  }
}
