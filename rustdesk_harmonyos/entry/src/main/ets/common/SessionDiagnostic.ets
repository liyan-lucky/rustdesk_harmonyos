/**
 * 会话建立诊断工具
 * 解决"被访问端点击允许后没有建立会话"问题
 */

import { OfficialRustDeskBridge, OfficialSessionEvent, OfficialCoreState } from '../services/OfficialRustDeskBridge';
import { NativeRustDeskBridge } from '../services/NativeRustDeskBridge';

export class SessionDiagnostic {
  private static instance: SessionDiagnostic | null = null;
  
  // 会话状态
  private sessionState = {
    isConnected: false,
    sessionStage: '',
    activePeerId: '',
    lastEvent: '',
    lastEventTime: 0,
    events: [] as string[],
    errors: [] as string[],
    connectionAttempts: 0,
    lastConnectionAttempt: 0
  };
  
  // 诊断模式
  private diagnosticMode: boolean = true;
  private eventListeners: ((event: OfficialSessionEvent) => void)[] = [];
  
  private constructor() {
    this.startDiagnostic();
  }
  
  static getInstance(): SessionDiagnostic {
    if (!SessionDiagnostic.instance) {
      SessionDiagnostic.instance = new SessionDiagnostic();
    }
    return SessionDiagnostic.instance;
  }
  
  /**
   * 启动诊断
   */
  private startDiagnostic(): void {
    console.log('[SessionDiagnostic] Starting session diagnostic');
    
    // 监听所有事件
    const originalListener = OfficialRustDeskBridge.getInstance().getEventListener();
    OfficialRustDeskBridge.getInstance().setEventListener((event: OfficialSessionEvent) => {
      // 调用原始监听器
      if (originalListener) {
        originalListener(event);
      }
      
      // 记录事件
      this.recordEvent(event);
      
      // 诊断事件
      this.diagnoseEvent(event);
    });
    
    // 定期检查会话状态
    setInterval(() => {
      this.checkSessionHealth();
    }, 5000);
  }
  
  /**
   * 记录事件
   */
  private recordEvent(event: OfficialSessionEvent): void {
    const timestamp = new Date().toISOString();
    const eventStr = `[${timestamp}] ${event.kind || 'unknown'}: ${event.detail || 'no detail'}`;
    
    this.sessionState.lastEvent = event.kind || '';
    this.sessionState.lastEventTime = Date.now();
    this.sessionState.events.push(eventStr);
    
    // 限制事件数量
    if (this.sessionState.events.length > 50) {
      this.sessionState.events.shift();
    }
    
    if (this.diagnosticMode) {
      console.log(`[SessionDiagnostic] Event: ${event.kind}`, event);
    }
  }
  
  /**
   * 诊断事件
   */
  private diagnoseEvent(event: OfficialSessionEvent): void {
    switch (event.kind) {
      case 'session-connected':
        this.sessionState.isConnected = true;
        this.sessionState.sessionStage = 'connected';
        console.log('[SessionDiagnostic] ✅ Session connected!');
        this.printSessionStatus();
        break;
        
      case 'session-disconnected':
        this.sessionState.isConnected = false;
        this.sessionState.sessionStage = 'disconnected';
        console.log('[SessionDiagnostic] ❌ Session disconnected');
        break;
        
      case 'session-error':
        this.sessionState.sessionStage = 'error';
        this.sessionState.errors.push(`Error: ${event.detail || 'unknown error'}`);
        console.error('[SessionDiagnostic] ❌ Session error:', event.detail);
        break;
        
      case 'peer-info':
        if (event.peerId) {
          this.sessionState.activePeerId = event.peerId;
          console.log(`[SessionDiagnostic] Peer info: ${event.peerId}`);
        }
        break;
        
      case 'video-frame':
        // 视频帧事件，会话可能已连接
        if (!this.sessionState.isConnected) {
          console.log('[SessionDiagnostic] 📹 Video frame received but session not marked as connected');
        }
        break;
    }
  }
  
  /**
   * 检查会话健康状态
   */
  private checkSessionHealth(): void {
    const coreState = OfficialRustDeskBridge.getInstance().getCoreState();
    
    // 更新状态
    this.sessionState.sessionStage = coreState.sessionStage || '';
    this.sessionState.activePeerId = coreState.activePeerId || '';
    
    // 检查状态一致性
    if (coreState.sessionStage === 'connected' && !this.sessionState.isConnected) {
      console.warn('[SessionDiagnostic] ⚠️ Core state shows connected but diagnostic state does not');
      this.sessionState.isConnected = true;
    }
    
    if (coreState.sessionStage !== 'connected' && this.sessionState.isConnected) {
      console.warn('[SessionDiagnostic] ⚠️ Diagnostic state shows connected but core state does not');
      this.sessionState.isConnected = false;
    }
    
    // 检查长时间无活动
    const timeSinceLastEvent = Date.now() - this.sessionState.lastEventTime;
    if (timeSinceLastEvent > 10000 && this.sessionState.isConnected) {
      console.warn(`[SessionDiagnostic] ⚠️ No events for ${timeSinceLastEvent}ms`);
    }
    
    // 打印状态（每30秒）
    if (Date.now() % 30000 < 5000) {
      this.printSessionStatus();
    }
  }
  
  /**
   * 打印会话状态
   */
  printSessionStatus(): void {
    const coreState = OfficialRustDeskBridge.getInstance().getCoreState();
    
    console.log('========================================');
    console.log('🔍 SESSION DIAGNOSTIC STATUS');
    console.log('========================================');
    console.log(`📊 Core State:`);
    console.log(`   Session Stage: ${coreState.sessionStage}`);
    console.log(`   Active Peer ID: ${coreState.activePeerId}`);
    console.log(`   Status Summary: ${coreState.statusSummary}`);
    console.log(`   Detail Message: ${coreState.detailMessage}`);
    console.log(`   Last Error: ${coreState.lastError}`);
    console.log('');
    console.log(`📊 Diagnostic State:`);
    console.log(`   Is Connected: ${this.sessionState.isConnected}`);
    console.log(`   Session Stage: ${this.sessionState.sessionStage}`);
    console.log(`   Active Peer ID: ${this.sessionState.activePeerId}`);
    console.log(`   Last Event: ${this.sessionState.lastEvent}`);
    console.log(`   Time Since Last Event: ${Date.now() - this.sessionState.lastEventTime}ms`);
    console.log(`   Connection Attempts: ${this.sessionState.connectionAttempts}`);
    console.log('');
    console.log(`📈 Recent Events (${this.sessionState.events.length}):`);
    for (const event of this.sessionState.events.slice(-5)) {
      console.log(`   ${event}`);
    }
    console.log('');
    console.log(`❌ Recent Errors (${this.sessionState.errors.length}):`);
    for (const error of this.sessionState.errors.slice(-5)) {
      console.log(`   ${error}`);
    }
    console.log('========================================');
    
    // 检查常见问题
    this.checkCommonIssues(coreState);
  }
  
  /**
   * 检查常见问题
   */
  private checkCommonIssues(coreState: OfficialCoreState): void {
    console.log('[SessionDiagnostic] 🔍 Checking for common issues...');
    
    // 问题1: 会话阶段为connecting但长时间无进展
    if (coreState.sessionStage === 'connecting') {
      const timeSinceLastAttempt = Date.now() - this.sessionState.lastConnectionAttempt;
      if (timeSinceLastAttempt > 30000) {
        console.warn('[SessionDiagnostic] ⚠️ Session stuck in "connecting" for 30+ seconds');
        console.warn('[SessionDiagnostic] 💡 Suggestion: Check network connection and peer availability');
      }
    }
    
    // 问题2: 有activePeerId但会话未连接
    if (coreState.activePeerId && coreState.activePeerId.length > 0 && coreState.sessionStage !== 'connected') {
      console.warn('[SessionDiagnostic] ⚠️ Has active peer ID but session not connected');
      console.warn('[SessionDiagnostic] 💡 Suggestion: Peer may have rejected the connection');
    }
    
    // 问题3: 有错误信息
    if (coreState.lastError && coreState.lastError.length > 0) {
      console.error('[SessionDiagnostic] ❌ Last error:', coreState.lastError);
      
      // 常见错误处理建议
      if (coreState.lastError.includes('timeout')) {
        console.warn('[SessionDiagnostic] 💡 Suggestion: Connection timeout. Check network and try again.');
      } else if (coreState.lastError.includes('refused')) {
        console.warn('[SessionDiagnostic] 💡 Suggestion: Connection refused. Peer may be offline or firewall blocked.');
      } else if (coreState.lastError.includes('password')) {
        console.warn('[SessionDiagnostic] 💡 Suggestion: Password error. Check password and try again.');
      }
    }
    
    // 问题4: 有detailMessage但会话未建立
    if (coreState.detailMessage && coreState.detailMessage.length > 0 && !coreState.sessionStage.includes('connected')) {
      console.log('[SessionDiagnostic] ℹ️ Detail message:', coreState.detailMessage);
    }
  }
  
  /**
   * 记录连接尝试
   */
  recordConnectionAttempt(): void {
    this.sessionState.connectionAttempts++;
    this.sessionState.lastConnectionAttempt = Date.now();
    console.log(`[SessionDiagnostic] Connection attempt #${this.sessionState.connectionAttempts}`);
  }
  
  /**
   * 手动触发会话检查
   */
  triggerSessionCheck(): void {
    console.log('[SessionDiagnostic] 🔍 Manual session check triggered');
    
    // 获取当前状态
    const coreState = OfficialRustDeskBridge.getInstance().getCoreState();
    const nativeSnapshot = NativeRustDeskBridge.getCoreSnapshot();
    
    console.log('[SessionDiagnostic] Official Bridge State:', JSON.stringify(coreState, null, 2));
    console.log('[SessionDiagnostic] Native Bridge Snapshot:', nativeSnapshot);
    
    // 检查会话状态
    this.checkSessionHealth();
    
    // 尝试强制刷新
    this.forceSessionRefresh();
  }
  
  /**
   * 强制会话刷新
   */
  private forceSessionRefresh(): void {
    console.log('[SessionDiagnostic] 🔄 Force refreshing session...');
    
    // 尝试重新连接
    if (this.sessionState.activePeerId && this.sessionState.activePeerId.length > 0) {
      console.log(`[SessionDiagnostic] Attempting to reconnect to peer: ${this.sessionState.activePeerId}`);
      
      // 这里可以添加重连逻辑
      // 例如：OfficialRustDeskBridge.getInstance().connectToPeer(...)
    }
    
    // 强制刷新视频
    NativeRustDeskBridge.refreshSessionVideo(0);
    console.log('[SessionDiagnostic] Video refresh triggered');
  }
  
  /**
   * 重置会话状态
   */
  resetSession(): void {
    console.log('[SessionDiagnostic] 🔄 Resetting session state');
    
    this.sessionState = {
      isConnected: false,
      sessionStage: '',
      activePeerId: '',
      lastEvent: '',
      lastEventTime: 0,
      events: [],
      errors: [],
      connectionAttempts: 0,
      lastConnectionAttempt: 0
    };
    
    // 关闭现有会话
    NativeRustDeskBridge.closeSession();
    console.log('[SessionDiagnostic] Session closed via NativeRustDeskBridge');
  }
  
  /**
   * 获取诊断报告
   */
  getDiagnosticReport(): string {
    const coreState = OfficialRustDeskBridge.getInstance().getCoreState();
    
    return `
🔍 SESSION DIAGNOSTIC REPORT
========================================
📊 CORE STATE:
  Session Stage: ${coreState.sessionStage || 'N/A'}
  Active Peer ID: ${coreState.activePeerId || 'N/A'}
  Status Summary: ${coreState.statusSummary || 'N/A'}
  Detail Message: ${coreState.detailMessage || 'N/A'}
  Last Error: ${coreState.lastError || 'N/A'}

📊 DIAGNOSTIC STATE:
  Is Connected: ${this.sessionState.isConnected}
  Session Stage: ${this.sessionState.sessionStage}
  Active Peer ID: ${this.sessionState.activePeerId}
  Last Event: ${this.sessionState.lastEvent}
  Connection Attempts: ${this.sessionState.connectionAttempts}
  Time Since Last Event: ${Date.now() - this.sessionState.lastEventTime}ms

📈 RECENT EVENTS (last 5):
${this.sessionState.events.slice(-5).map(e => `  • ${e}`).join('\n')}

❌ RECENT ERRORS (last 5):
${this.sessionState.errors.slice(-5).map(e => `  • ${e}`).join('\n')}

💡 SUGGESTIONS:
${this.generateSuggestions(coreState)}
========================================
    `;
  }
  
  /**
   * 生成建议
   */
  private generateSuggestions(coreState: OfficialCoreState): string {
    const suggestions: string[] = [];
    
    if (coreState.sessionStage === 'connecting' && (Date.now() - this.sessionState.lastConnectionAttempt) > 30000) {
      suggestions.push('• Session stuck in "connecting" for 30+ seconds. Try reconnecting.');
    }
    
    if (coreState.lastError && coreState.lastError.length > 0) {
      suggestions.push(`• Last error: ${coreState.lastError}. Check network and peer status.`);
    }
    
    if (coreState.activePeerId && coreState.activePeerId.length > 0 && coreState.sessionStage !== 'connected') {
      suggestions.push('• Peer ID exists but session not connected. Peer may have rejected.');
    }
    
    if (this.sessionState.events.length === 0) {
      suggestions.push('• No events received. Check if event listeners are properly set up.');
    }
    
    if (suggestions.length === 0) {
      suggestions.push('• No obvious issues detected. Session may be establishing...');
    }
    
    return suggestions.join('\n');
  }
  
  /**
   * 启用/禁用诊断模式
   */
  setDiagnosticMode(enabled: boolean): void {
    this.diagnosticMode = enabled;
    console.log(`[SessionDiagnostic] Diagnostic mode ${enabled ? 'enabled' : 'disabled'}`);
  }
  
  /**
   * 获取当前状态
   */
  getState(): SessionDiagnosticState {
    return new SessionDiagnosticStateImpl(
      this.sessionState.isConnected,
      this.sessionState.sessionStage,
      this.sessionState.activePeerId,
      this.sessionState.lastEvent,
      this.sessionState.lastEventTime,
      this.sessionState.events,
      this.sessionState.errors,
      this.sessionState.connectionAttempts,
      this.sessionState.lastConnectionAttempt
    );
  }
}

interface SessionDiagnosticState {
  isConnected: boolean;
  sessionStage: string;
  activePeerId: string;
  lastEvent: string;
  lastEventTime: number;
  events: string[];
  errors: string[];
  connectionAttempts: number;
  lastConnectionAttempt: number;
}

class SessionDiagnosticStateImpl implements SessionDiagnosticState {
  isConnected: boolean = false;
  sessionStage: string = '';
  activePeerId: string = '';
  lastEvent: string = '';
  lastEventTime: number = 0;
  events: string[] = [];
  errors: string[] = [];
  connectionAttempts: number = 0;
  lastConnectionAttempt: number = 0;

  constructor(
    isConnected: boolean,
    sessionStage: string,
    activePeerId: string,
    lastEvent: string,
    lastEventTime: number,
    events: string[],
    errors: string[],
    connectionAttempts: number,
    lastConnectionAttempt: number
  ) {
    this.isConnected = isConnected;
    this.sessionStage = sessionStage;
    this.activePeerId = activePeerId;
    this.lastEvent = lastEvent;
    this.lastEventTime = lastEventTime;
    this.events = events;
    this.errors = errors;
    this.connectionAttempts = connectionAttempts;
    this.lastConnectionAttempt = lastConnectionAttempt;
  }
}

// 导出单例
export const sessionDiagnostic = SessionDiagnostic.getInstance();