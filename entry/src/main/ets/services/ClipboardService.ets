import pasteboard from '@ohos.pasteboard';
import { Permissions } from '@ohos.abilityAccessCtrl';
import { PermissionService, PermissionStatus } from './PermissionService';
import { SessionClipboardData } from './OfficialSessionTypes';

export interface ClipboardEvent {
  type: 'content_changed' | 'sync_required' | 'error';
  content?: string;
  error?: string;
}

export class ClipboardService {
  private static instance: ClipboardService;
  private readonly readPasteboardPermission: Permissions = 'ohos.permission.READ_PASTEBOARD';
  // Remote paste needs real pasteboard reads, so keep the permission path enabled.
  private readonly restrictedReadEnabled: boolean = true;
  private systemPasteboard: pasteboard.SystemPasteboard | null = null;
  private isMonitoring: boolean = false;
  private isSyncEnabled: boolean = true;
  private lastContent: string = '';
  private monitorInterval: number = 0;
  private eventListeners: Array<(event: ClipboardEvent) => void> = [];
  private hasReadPermission: boolean = false;
  private permissionRequestBlocked: boolean = false;

  private constructor() {
    try {
      this.systemPasteboard = pasteboard.getSystemPasteboard();
    } catch (error) {
      console.error('初始化剪贴板失败:', error);
      this.systemPasteboard = null;
    }
  }

  public static getInstance(): ClipboardService {
    if (!ClipboardService.instance) {
      ClipboardService.instance = new ClipboardService();
    }
    return ClipboardService.instance;
  }

  public async startMonitoring(intervalMs: number = 1000): Promise<void> {
    if (this.isMonitoring) {
      return;
    }

    this.lastContent = await this.getClipboardContent();
    this.isMonitoring = true;
    this.monitorInterval = setInterval(() => {
      void this.checkClipboardChange();
    }, intervalMs);
  }

  public stopMonitoring(): void {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;
    if (this.monitorInterval > 0) {
      clearInterval(this.monitorInterval);
      this.monitorInterval = 0;
    }
  }

  private async checkClipboardChange(): Promise<void> {
    if (!this.isMonitoring || !this.isSyncEnabled) {
      return;
    }

    const currentContent: string = await this.getClipboardContent();
    if (currentContent === this.lastContent) {
      return;
    }

    this.lastContent = currentContent;
    this.dispatchEvent({ type: 'content_changed', content: currentContent });
    if (currentContent.trim().length > 0) {
      this.dispatchEvent({ type: 'sync_required', content: currentContent });
    }
  }

  public async getClipboardContent(): Promise<string> {
    try {
      if (!this.systemPasteboard) {
        return '';
      }

      const hasPermission = await this.ensureReadPermission();
      if (!hasPermission) {
        return '';
      }

      const data: pasteboard.PasteData = await this.systemPasteboard.getData();
      if (data.getPrimaryMimeType() !== pasteboard.MIMETYPE_TEXT_PLAIN) {
        return data.getPrimaryText() ?? '';
      }
      return data.getPrimaryText() ?? '';
    } catch (error) {
      console.error('读取剪贴板失败:', error);
      return '';
    }
  }

  public async setClipboardContent(content: string): Promise<boolean> {
    try {
      if (!this.systemPasteboard) {
        this.dispatchEvent({ type: 'error', error: '剪贴板未初始化' });
        return false;
      }

      const pasteData: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        content
      );
      await this.systemPasteboard.setData(pasteData);
      this.lastContent = content;
      return true;
    } catch (error) {
      console.error('写入剪贴板失败:', error);
      this.dispatchEvent({ type: 'error', error: '写入剪贴板失败' });
      return false;
    }
  }

  public async copyText(content: string): Promise<boolean> {
    return this.setClipboardContent(content);
  }

  public async clearClipboard(): Promise<boolean> {
    try {
      if (!this.systemPasteboard) {
        this.dispatchEvent({ type: 'error', error: '剪贴板未初始化' });
        return false;
      }

      await this.systemPasteboard.clearData();
      this.lastContent = '';
      return true;
    } catch (error) {
      console.error('清空剪贴板失败:', error);
      this.dispatchEvent({ type: 'error', error: '清空剪贴板失败' });
      return false;
    }
  }

  public enableSync(): void {
    this.isSyncEnabled = true;
  }

  public disableSync(): void {
    this.isSyncEnabled = false;
  }

  public isSyncActive(): boolean {
    return this.isSyncEnabled;
  }

  public isMonitoringActive(): boolean {
    return this.isMonitoring;
  }

  public createClipboardData(content: string): SessionClipboardData {
    return {
      content: content,
      timestamp: Date.now()
    };
  }

  public addEventListener(listener: (event: ClipboardEvent) => void): void {
    this.eventListeners.push(listener);
  }

  public removeEventListener(listener: (event: ClipboardEvent) => void): void {
    const index: number = this.eventListeners.indexOf(listener);
    if (index >= 0) {
      this.eventListeners.splice(index, 1);
    }
  }

  private dispatchEvent(event: ClipboardEvent): void {
    for (let i = 0; i < this.eventListeners.length; i++) {
      try {
        this.eventListeners[i](event);
      } catch (error) {
        console.error('剪贴板事件监听器执行失败:', error);
      }
    }
  }

  public async hasContent(): Promise<boolean> {
    const content: string = await this.getClipboardContent();
    return content.trim().length > 0;
  }

  public async getContentLength(): Promise<number> {
    const content: string = await this.getClipboardContent();
    return content.length;
  }

  public async getContentSummary(maxLength: number = 50): Promise<string> {
    const content: string = await this.getClipboardContent();
    if (content.length <= maxLength) {
      return content;
    }
    return `${content.substring(0, maxLength)}...`;
  }

  private async ensureReadPermission(): Promise<boolean> {
    if (!this.restrictedReadEnabled) {
      this.permissionRequestBlocked = true;
      return false;
    }

    if (this.hasReadPermission) {
      return true;
    }

    if (this.permissionRequestBlocked) {
      return false;
    }

    const permissionService = PermissionService.getInstance();
    const currentStatus = await permissionService.checkPermission(this.readPasteboardPermission);
    if (currentStatus === PermissionStatus.GRANTED) {
      this.hasReadPermission = true;
      return true;
    }

    if (currentStatus === PermissionStatus.PERMANENTLY_DENIED) {
      this.permissionRequestBlocked = true;
      this.dispatchEvent({ type: 'error', error: '剪贴板读取权限被永久拒绝' });
      return false;
    }

    const requestStatus = await permissionService.requestPermission(this.readPasteboardPermission);
    if (requestStatus === PermissionStatus.GRANTED) {
      this.hasReadPermission = true;
      return true;
    }

    this.permissionRequestBlocked = true;
    this.dispatchEvent({ type: 'error', error: '未获得剪贴板读取权限' });
    return false;
  }
}
