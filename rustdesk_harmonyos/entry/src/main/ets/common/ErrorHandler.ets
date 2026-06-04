/**
 * 错误处理器
 * 统一管理和处理应用错误
 */
import promptAction from '@ohos.promptAction';

/**
 * 错误类型
 */
export enum ErrorType {
  NETWORK = 'network',
  PERMISSION = 'permission',
  AUTHENTICATION = 'authentication',
  CONNECTION = 'connection',
  MEDIA = 'media',
  FILE = 'file',
  UNKNOWN = 'unknown'
}

/**
 * 错误严重程度
 */
export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

/**
 * 错误信息
 */
export interface ErrorInfo {
  type: ErrorType;
  severity: ErrorSeverity;
  code: string;
  message: string;
  details?: string;
  timestamp: number;
  stackTrace?: string;
}

/**
 * 错误处理事件
 */
export interface ErrorEvent {
  error: ErrorInfo;
  handled: boolean;
}

/**
 * 错误处理器
 */
export class ErrorHandler {
  private static instance: ErrorHandler;
  private errorHistory: ErrorInfo[] = [];
  private maxHistorySize: number = 100;
  private eventListeners: Array<(event: ErrorEvent) => void> = [];

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): ErrorHandler {
    if (!ErrorHandler.instance) {
      ErrorHandler.instance = new ErrorHandler();
    }
    return ErrorHandler.instance;
  }

  /**
   * 处理错误
   */
  handleError(
    error: Error | string,
    type: ErrorType = ErrorType.UNKNOWN,
    severity: ErrorSeverity = ErrorSeverity.MEDIUM,
    details?: string
  ): void {
    const errorMessage = typeof error === 'string' ? error : error.message;
    const stackTrace = typeof error === 'string' ? undefined : error.stack;

    const errorInfo: ErrorInfo = {
      type,
      severity,
      code: this.generateErrorCode(type),
      message: errorMessage,
      details,
      timestamp: Date.now(),
      stackTrace
    };

    // 添加到历史记录
    this.addToHistory(errorInfo);

    // 记录错误日志
    this.logError(errorInfo);

    // 分发错误事件
    this.dispatchEvent({
      error: errorInfo,
      handled: false
    });

    // 根据严重程度显示用户提示
    this.showErrorToUser(errorInfo);
  }

  /**
   * 处理网络错误
   */
  handleNetworkError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.NETWORK, ErrorSeverity.HIGH, details);
  }

  /**
   * 处理权限错误
   */
  handlePermissionError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.PERMISSION, ErrorSeverity.HIGH, details);
  }

  /**
   * 处理认证错误
   */
  handleAuthenticationError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.AUTHENTICATION, ErrorSeverity.MEDIUM, details);
  }

  /**
   * 处理连接错误
   */
  handleConnectionError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.CONNECTION, ErrorSeverity.HIGH, details);
  }

  /**
   * 处理媒体错误
   */
  handleMediaError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.MEDIA, ErrorSeverity.MEDIUM, details);
  }

  /**
   * 处理文件错误
   */
  handleFileError(error: Error | string, details?: string): void {
    this.handleError(error, ErrorType.FILE, ErrorSeverity.LOW, details);
  }

  /**
   * 添加到历史记录
   */
  private addToHistory(errorInfo: ErrorInfo): void {
    this.errorHistory.push(errorInfo);

    // 限制历史记录大小
    if (this.errorHistory.length > this.maxHistorySize) {
      this.errorHistory.shift();
    }
  }

  /**
   * 记录错误日志
   */
  private logError(errorInfo: ErrorInfo): void {
    const logMessage = `[${errorInfo.type.toUpperCase()}] ${errorInfo.message}`;
    console.error(logMessage, errorInfo);

    if (errorInfo.details) {
      console.error('Details:', errorInfo.details);
    }

    if (errorInfo.stackTrace) {
      console.error('Stack trace:', errorInfo.stackTrace);
    }
  }

  /**
   * 向用户显示错误
   */
  private showErrorToUser(errorInfo: ErrorInfo): void {
    const userMessage = this.getUserMessage(errorInfo);

    switch (errorInfo.severity) {
      case ErrorSeverity.CRITICAL:
      case ErrorSeverity.HIGH:
        // 显示提示框
        this.showAlertDialog(userMessage, errorInfo);
        break;

      case ErrorSeverity.MEDIUM:
        // 显示Toast
        this.showToast(userMessage, 3000);
        break;

      case ErrorSeverity.LOW:
        // 只记录日志，不显示给用户
        break;
    }
  }

  /**
   * 显示警告对话框
   */
  private showAlertDialog(message: string, errorInfo: ErrorInfo): void {
    // 这里应该实现一个AlertDialog
    // 由于鸿蒙的AlertDialog实现较为复杂，这里使用Toast代替
    this.showToast(message, 5000);

    console.log('Should show alert dialog:', message);
  }

  /**
   * 显示Toast提示
   */
  private showToast(message: string, duration: number = 3000): void {
    try {
      promptAction.showToast({
        message,
        duration,
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show toast failed:', error);
    }
  }

  /**
   * 获取用户友好的错误消息
   */
  private getUserMessage(errorInfo: ErrorInfo): string {
    const typeMessages: Record<ErrorType, string> = {
      [ErrorType.NETWORK]: '网络连接失败',
      [ErrorType.PERMISSION]: '缺少必要权限',
      [ErrorType.AUTHENTICATION]: '认证失败',
      [ErrorType.CONNECTION]: '连接中断',
      [ErrorType.MEDIA]: '媒体处理失败',
      [ErrorType.FILE]: '文件操作失败',
      [ErrorType.UNKNOWN]: '发生未知错误'
    };

    const typeMessage = typeMessages[errorInfo.type] || '发生错误';

    // 根据错误代码提供更具体的消息
    const specificMessage = this.getSpecificMessage(errorInfo.code, errorInfo.message);

    return specificMessage || `${typeMessage}: ${errorInfo.message}`;
  }

  /**
   * 获取特定的错误消息
   */
  private getSpecificMessage(code: string, message: string): string | null {
    const specificMessages: Record<string, string> = {
      'NET_001': '无法连接到服务器，请检查网络连接',
      'NET_002': '连接超时，请重试',
      'NET_003': '服务器无响应',
      'PERM_001': '需要网络权限',
      'PERM_002': '需要存储权限',
      'PERM_003': '需要麦克风权限',
      'PERM_004': '需要屏幕录制权限',
      'AUTH_001': '密码错误',
      'AUTH_002': '设备ID不存在',
      'AUTH_003': '登录已过期',
      'CONN_001': '连接被拒绝',
      'CONN_002': '连接已断开',
      'CONN_003': '连接超时',
      'MEDIA_001': '无法启动屏幕录制',
      'MEDIA_002': '无法启动音频录制',
      'MEDIA_003': '视频编码失败',
      'FILE_001': '文件不存在',
      'FILE_002': '文件读取失败',
      'FILE_003': '文件写入失败',
      'FILE_004': '存储空间不足'
    };

    return specificMessages[code] || null;
  }

  /**
   * 生成错误代码
   */
  private generateErrorCode(type: ErrorType): string {
    const typePrefixes: Record<ErrorType, string> = {
      [ErrorType.NETWORK]: 'NET',
      [ErrorType.PERMISSION]: 'PERM',
      [ErrorType.AUTHENTICATION]: 'AUTH',
      [ErrorType.CONNECTION]: 'CONN',
      [ErrorType.MEDIA]: 'MEDIA',
      [ErrorType.FILE]: 'FILE',
      [ErrorType.UNKNOWN]: 'UNKNOWN'
    };

    const prefix = typePrefixes[type] || 'UNKNOWN';
    const timestamp = Date.now().toString().slice(-3);
    const random = Math.floor(Math.random() * 100).toString().padStart(2, '0');

    return `${prefix}_${timestamp}${random}`;
  }

  /**
   * 获取错误历史记录
   */
  getErrorHistory(): ErrorInfo[] {
    return this.errorHistory.slice();
  }

  /**
   * 清空错误历史记录
   */
  clearErrorHistory(): void {
    this.errorHistory = [];
  }

  /**
   * 添加事件监听器
   */
  addEventListener(listener: (event: ErrorEvent) => void): void {
    this.eventListeners.push(listener);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(listener: (event: ErrorEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  /**
   * 分发事件
   */
  private dispatchEvent(event: ErrorEvent): void {
    this.eventListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('Event listener error:', error);
      }
    });
  }

  /**
   * 格式化错误类型
   */
  static formatErrorType(type: ErrorType): string {
    const typeNames: Record<ErrorType, string> = {
      [ErrorType.NETWORK]: '网络错误',
      [ErrorType.PERMISSION]: '权限错误',
      [ErrorType.AUTHENTICATION]: '认证错误',
      [ErrorType.CONNECTION]: '连接错误',
      [ErrorType.MEDIA]: '媒体错误',
      [ErrorType.FILE]: '文件错误',
      [ErrorType.UNKNOWN]: '未知错误'
    };

    return typeNames[type] || '未知错误';
  }

  /**
   * 格式化错误严重程度
   */
  static formatErrorSeverity(severity: ErrorSeverity): string {
    const severityNames: Record<ErrorSeverity, string> = {
      [ErrorSeverity.LOW]: '低',
      [ErrorSeverity.MEDIUM]: '中',
      [ErrorSeverity.HIGH]: '高',
      [ErrorSeverity.CRITICAL]: '严重'
    };

    return severityNames[severity] || '未知';
  }
}

/**
 * 用户提示工具
 */
export class UserPrompt {
  /**
   * 显示成功提示
   */
  static showSuccess(message: string, duration: number = 2000): void {
    try {
      promptAction.showToast({
        message: '✓ ' + message,
        duration,
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show success toast failed:', error);
    }
  }

  /**
   * 显示错误提示
   */
  static showError(message: string, duration: number = 3000): void {
    try {
      promptAction.showToast({
        message: '✗ ' + message,
        duration,
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show error toast failed:', error);
    }
  }

  /**
   * 显示警告提示
   */
  static showWarning(message: string, duration: number = 2500): void {
    try {
      promptAction.showToast({
        message: '⚠ ' + message,
        duration,
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show warning toast failed:', error);
    }
  }

  /**
   * 显示信息提示
   */
  static showInfo(message: string, duration: number = 2000): void {
    try {
      promptAction.showToast({
        message: 'ℹ ' + message,
        duration,
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show info toast failed:', error);
    }
  }

  /**
   * 显示加载提示
   */
  static showLoading(message: string = '加载中...'): void {
    try {
      promptAction.showToast({
        message,
        duration: 0, // 不自动消失
        bottom: '50%'
      });
    } catch (error) {
      console.error('Show loading toast failed:', error);
    }
  }

  /**
   * 隐藏加载提示
   */
  static hideLoading(): void {
    // 鸿蒙的Toast不支持手动隐藏，这里只是占位
    console.log('Hide loading');
  }
}
