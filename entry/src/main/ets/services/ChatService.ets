import { OfficialSessionTransport } from './OfficialSessionTransport';
import { OfficialRustDeskBridge, OfficialSessionEvent } from './OfficialRustDeskBridge';
import { PreferenceStore } from './PreferenceStore';

/**
 * 聊天服务
 * 负责与远程设备进行文本聊天
 */

/**
 * 聊天消息类型
 */
export enum ChatMessageType {
  TEXT = 'text',
  FILE = 'file',
  SYSTEM = 'system'
}

/**
 * 聊天消息
 */
export interface ChatMessage {
  id: string;
  type: ChatMessageType;
  content: string;
  sender: 'local' | 'remote';
  timestamp: number;
  isRead: boolean;
  fileName?: string;
  fileSize?: number;
}

/**
 * 聊天会话信息
 */
export interface ChatSession {
  deviceId: string;
  deviceName: string;
  unreadCount: number;
  lastMessage?: ChatMessage;
}

/**
 * 聊天事件
 */
export interface ChatEvent {
  type: 'message_received' | 'message_sent' | 'message_read' | 'session_updated' | 'error';
  message?: ChatMessage;
  session?: ChatSession;
  error?: string;
}

/**
 * 聊天服务
 */
export class ChatService {
  private static instance: ChatService;
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private sessions: Map<string, ChatSession> = new Map();
  private messages: Map<string, ChatMessage[]> = new Map(); // deviceId -> messages
  private eventListeners: Array<(event: ChatEvent) => void> = [];
  private maxMessageHistory: number = 1000;

  private constructor() {
    this.loadPersistedMessages();
    this.officialBridge.addEventListener((event: OfficialSessionEvent) => {
      this.handleOfficialEvent(event);
    });
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  /**
   * 创建或获取聊天会话
   */
  getOrCreateSession(deviceId: string, deviceName: string): ChatSession {
    let session = this.sessions.get(deviceId);

    if (!session) {
      session = {
        deviceId,
        deviceName,
        unreadCount: 0
      };

      this.sessions.set(deviceId, session);
    }

    return session;
  }

  /**
   * 获取聊天会话
   */
  getSession(deviceId: string): ChatSession | undefined {
    return this.sessions.get(deviceId);
  }

  updateSessionDeviceName(deviceId: string, deviceName: string): void {
    const session = this.getOrCreateSession(deviceId, deviceName);
    session.deviceName = deviceName;
    this.dispatchEvent({
      type: 'session_updated',
      session
    });
  }

  /**
   * 获取所有聊天会话
   */
  getAllSessions(): ChatSession[] {
    return Array.from(this.sessions.values());
  }

  /**
   * 删除聊天会话
   */
  deleteSession(deviceId: string): void {
    this.sessions.delete(deviceId);
    this.messages.delete(deviceId);
  }

  /**
   * 发送文本消息
   */
  async sendTextMessage(deviceId: string, content: string): Promise<ChatMessage> {
    try {
      const session = this.getOrCreateSession(deviceId, 'Unknown Device');

      // 创建消息
      const message: ChatMessage = {
        id: this.generateMessageId(),
        type: ChatMessageType.TEXT,
        content,
        sender: 'local',
        timestamp: Date.now(),
        isRead: true
      };

      // 保存消息
      this.saveMessage(deviceId, message);

      // 更新会话
      session.lastMessage = message;
      session.unreadCount = 0;

      // 这里应该通过连接发送消息
      // await this.connection.sendChatMessage(message);

      // 分发事件
      this.dispatchEvent({
        type: 'message_sent',
        message
      });

      this.dispatchEvent({
        type: 'session_updated',
        session
      });

      OfficialSessionTransport.sendChatMessage(deviceId, message.type, message.content, message.timestamp);
      return message;
    } catch (error) {
      console.error('Send text message failed:', error);
      throw new Error(String(error));
    }
  }

  /**
   * 接收文本消息
   */
  receiveTextMessage(deviceId: string, content: string): ChatMessage {
    const session = this.getOrCreateSession(deviceId, 'Unknown Device');

    // 创建消息
    const message: ChatMessage = {
      id: this.generateMessageId(),
      type: ChatMessageType.TEXT,
      content,
      sender: 'remote',
      timestamp: Date.now(),
      isRead: false
    };

    // 保存消息
    this.saveMessage(deviceId, message);

    // 更新会话
    session.lastMessage = message;
    session.unreadCount++;

    // 分发事件
    this.dispatchEvent({
      type: 'message_received',
      message
    });

    this.dispatchEvent({
      type: 'session_updated',
      session
    });

    return message;
  }

  /**
   * 发送文件消息
   */
  async sendFileMessage(deviceId: string, filePath: string, fileName: string, fileSize: number): Promise<ChatMessage> {
    try {
      const session = this.getOrCreateSession(deviceId, 'Unknown Device');

      // 创建消息
      const message: ChatMessage = {
        id: this.generateMessageId(),
        type: ChatMessageType.FILE,
        content: filePath,
        sender: 'local',
        timestamp: Date.now(),
        isRead: true,
        fileName,
        fileSize
      };

      // 保存消息
      this.saveMessage(deviceId, message);

      // 更新会话
      session.lastMessage = message;
      session.unreadCount = 0;

      // 这里应该通过连接发送文件
      // await this.connection.sendFile(filePath);

      // 分发事件
      this.dispatchEvent({
        type: 'message_sent',
        message
      });

      this.dispatchEvent({
        type: 'session_updated',
        session
      });

      OfficialSessionTransport.sendChatMessage(deviceId, message.type, message.fileName || message.content, message.timestamp);
      return message;
    } catch (error) {
      console.error('Send file message failed:', error);
      throw new Error(String(error));
    }
  }

  /**
   * 接收文件消息
   */
  receiveFileMessage(deviceId: string, filePath: string, fileName: string, fileSize: number): ChatMessage {
    const session = this.getOrCreateSession(deviceId, 'Unknown Device');

    // 创建消息
    const message: ChatMessage = {
      id: this.generateMessageId(),
      type: ChatMessageType.FILE,
      content: filePath,
      sender: 'remote',
      timestamp: Date.now(),
      isRead: false,
      fileName,
      fileSize
    };

    // 保存消息
    this.saveMessage(deviceId, message);

    // 更新会话
    session.lastMessage = message;
    session.unreadCount++;

    // 分发事件
    this.dispatchEvent({
      type: 'message_received',
      message
    });

    this.dispatchEvent({
      type: 'session_updated',
      session
    });

    return message;
  }

  /**
   * 发送系统消息
   */
  sendSystemMessage(deviceId: string, content: string): ChatMessage {
    const session = this.getOrCreateSession(deviceId, 'Unknown Device');

    // 创建消息
    const message: ChatMessage = {
      id: this.generateMessageId(),
      type: ChatMessageType.SYSTEM,
      content,
      sender: 'local',
      timestamp: Date.now(),
      isRead: true
    };

    // 保存消息
    this.saveMessage(deviceId, message);

    // 更新会话
    session.lastMessage = message;

    // 分发事件
    this.dispatchEvent({
      type: 'message_sent',
      message
    });

    this.dispatchEvent({
      type: 'session_updated',
      session
    });

    return message;
  }

  /**
   * 获取聊天消息
   */
  getMessages(deviceId: string): ChatMessage[] {
    const messages = this.messages.get(deviceId);
    return messages ? messages.slice() : [];
  }

  hasMessages(deviceId: string): boolean {
    const messages = this.messages.get(deviceId);
    return !!messages && messages.length > 0;
  }

  /**
   * 标记消息为已读
   */
  markAsRead(deviceId: string, messageId?: string): void {
    const session = this.sessions.get(deviceId);
    if (!session) {
      return;
    }

    const messages = this.messages.get(deviceId);
    if (!messages) {
      return;
    }

    if (messageId) {
      // 标记特定消息为已读
      const message = messages.find(msg => msg.id === messageId);
      if (message && !message.isRead) {
        message.isRead = true;
        this.persistMessages();

        this.dispatchEvent({
          type: 'message_read',
          message
        });
      }
    } else {
      // 标记所有消息为已读
      let changed = false;
      messages.forEach(message => {
        if (!message.isRead) {
          message.isRead = true;
          changed = true;
        }
      });

      session.unreadCount = 0;
      if (changed) {
        this.persistMessages();
      }

      this.dispatchEvent({
        type: 'session_updated',
        session
      });
    }
  }

  /**
   * 删除消息
   */
  deleteMessage(deviceId: string, messageId: string): void {
    const messages = this.messages.get(deviceId);
    if (!messages) {
      return;
    }

    const index = messages.findIndex(msg => msg.id === messageId);
    if (index > -1) {
      messages.splice(index, 1);
      this.persistMessages();
    }
  }

  /**
   * 清空聊天消息
   */
  clearMessages(deviceId: string): void {
    this.messages.set(deviceId, []);

    const session = this.sessions.get(deviceId);
    if (session) {
      session.lastMessage = undefined;
      session.unreadCount = 0;

      this.dispatchEvent({
        type: 'session_updated',
        session
      });
    }

    this.persistMessages();
  }

  /**
   * 获取未读消息数
   */
  getUnreadCount(deviceId: string): number {
    const session = this.sessions.get(deviceId);
    return session ? session.unreadCount : 0;
  }

  /**
   * 获取总未读消息数
   */
  getTotalUnreadCount(): number {
    let total = 0;
    this.sessions.forEach(session => {
      total += session.unreadCount;
    });
    return total;
  }

  /**
   * 保存消息
   */
  private saveMessage(deviceId: string, message: ChatMessage): void {
    let messages = this.messages.get(deviceId);
    if (!messages) {
      messages = [];
      this.messages.set(deviceId, messages);
    }

    messages.push(message);

    // 限制消息历史数量
    if (messages.length > this.maxMessageHistory) {
      messages.splice(0, messages.length - this.maxMessageHistory);
    }

    this.persistMessages();
  }

  /**
   * 持久化所有聊天消息
   */
  private persistMessages(): void {
    try {
      const data: Record<string, ChatMessage[]> = {};
      this.messages.forEach((msgs, deviceId) => {
        data[deviceId] = msgs;
      });
      PreferenceStore.setChatMessages(JSON.stringify(data));
    } catch (error) {
      console.error('Persist chat messages failed:', error);
    }
  }

  /**
   * 从持久化存储加载聊天消息
   */
  private loadPersistedMessages(): void {
    try {
      const raw = PreferenceStore.getChatMessages();
      if (!raw) {
        return;
      }
      const data = JSON.parse(raw) as Record<string, ChatMessage[]>;
      const keys = Object.keys(data);
      for (let i = 0; i < keys.length; i++) {
        const deviceId = keys[i];
        const messages = data[deviceId];
        if (!Array.isArray(messages)) {
          continue;
        }
        this.messages.set(deviceId, messages);
        if (messages.length > 0) {
          const lastMessage = messages[messages.length - 1];
          let unreadCount = 0;
          messages.forEach((message: ChatMessage) => {
            if (message.sender === 'remote' && !message.isRead) {
              unreadCount += 1;
            }
          });
          this.sessions.set(deviceId, {
            deviceId,
            deviceName: 'Unknown Device',
            unreadCount,
            lastMessage
          });
        }
      }
    } catch (error) {
      console.error('Load persisted chat messages failed:', error);
    }
  }

  /**
   * 生成消息ID
   */
  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 格式化时间
   */
  static formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    // 如果是今天，只显示时间
    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit'
      });
    }

    // 如果是昨天
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    if (date.toDateString() === yesterday.toDateString()) {
      return '昨天 ' + date.toLocaleTimeString('zh-CN', {
        hour: '2-digit',
        minute: '2-digit'
      });
    }

    // 其他日期
    return date.toLocaleDateString('zh-CN', {
      month: '2-digit',
      day: '2-digit'
    }) + ' ' + date.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  /**
   * 格式化文件大小
   */
  static formatFileSize(bytes: number): string {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return `${size.toFixed(2)} ${units[unitIndex]}`;
  }

  /**
   * 添加事件监听器
   */
  addEventListener(listener: (event: ChatEvent) => void): void {
    this.eventListeners.push(listener);
  }

  /**
   * 移除事件监听器
   */
  removeEventListener(listener: (event: ChatEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  /**
   * 分发事件
   */
  private dispatchEvent(event: ChatEvent): void {
    this.eventListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('Event listener error:', error);
      }
    });
  }

  /**
   * 设置最大消息历史数量
   */
  setMaxMessageHistory(max: number): void {
    this.maxMessageHistory = Math.max(100, max);
  }

  /**
   * 获取最大消息历史数量
   */
  getMaxMessageHistory(): number {
    return this.maxMessageHistory;
  }

  private handleOfficialEvent(event: OfficialSessionEvent): void {
    if (event.kind !== 'chat-message') {
      return;
    }
    const deviceId = event.peerId.trim();
    const content = event.detail.trim();
    if (deviceId.length === 0 || content.length === 0) {
      return;
    }
    this.receiveTextMessage(deviceId, content);
  }
}
