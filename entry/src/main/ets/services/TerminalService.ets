import { OfficialSessionTransport } from './OfficialSessionTransport';
import { OfficialRustDeskBridge, OfficialSessionEvent } from './OfficialRustDeskBridge';

export interface TerminalSession {
  id: number;
  rows: number;
  cols: number;
  peerId: string;
  createdAt: number;
  lastActivityAt: number;
  outputLines: string[];
  isAlive: boolean;
}

export interface TerminalOutputEvent {
  terminalId: number;
  data: string;
  type: 'stdout' | 'stderr' | 'system';
}

interface TerminalPayload {
  terminal_id?: number;
  id?: number;
  data?: string;
  type?: string;
}

export class TerminalService {
  private static instance: TerminalService;
  private sessions: Map<number, TerminalSession> = new Map();
  private outputListeners: Array<(event: TerminalOutputEvent) => void> = [];
  private bridgeListener = (event: OfficialSessionEvent): void => {
    this.handleBridgeEvent(event);
  };
  private nextTerminalId: number = 1;

  private constructor() {
    OfficialRustDeskBridge.getInstance().addEventListener(this.bridgeListener);
  }

  static getInstance(): TerminalService {
    if (!TerminalService.instance) {
      TerminalService.instance = new TerminalService();
    }
    return TerminalService.instance;
  }

  openTerminal(peerId: string, rows: number = 30, cols: number = 120): number | null {
    const terminalId = this.nextTerminalId++;
    const success = OfficialSessionTransport.openTerminal(terminalId, rows, cols);
    if (!success) {
      console.error(`[TerminalService] Failed to open terminal ${terminalId}`);
      return null;
    }
    const session: TerminalSession = {
      id: terminalId,
      rows,
      cols,
      peerId,
      createdAt: Date.now(),
      lastActivityAt: Date.now(),
      outputLines: [],
      isAlive: true
    };
    this.sessions.set(terminalId, session);
    console.log(`[TerminalService] Terminal ${terminalId} opened for peer ${peerId}`);
    return terminalId;
  }

  closeTerminal(terminalId: number): boolean {
    const session = this.sessions.get(terminalId);
    if (!session) {
      return false;
    }
    OfficialSessionTransport.closeTerminal(terminalId);
    session.isAlive = false;
    this.sessions.delete(terminalId);
    console.log(`[TerminalService] Terminal ${terminalId} closed`);
    return true;
  }

  closeAllTerminals(): void {
    this.sessions.forEach((session, id) => {
      if (session.isAlive) {
        OfficialSessionTransport.closeTerminal(id);
        session.isAlive = false;
      }
    });
    this.sessions.clear();
    console.log('[TerminalService] All terminals closed');
  }

  sendInput(terminalId: number, data: string): boolean {
    const session = this.sessions.get(terminalId);
    if (!session || !session.isAlive) {
      console.warn(`[TerminalService] Terminal ${terminalId} not found or inactive`);
      return false;
    }
    const success = OfficialSessionTransport.sendTerminalInput(terminalId, data);
    if (success) {
      session.lastActivityAt = Date.now();
    }
    return success;
  }

  resizeTerminal(terminalId: number, rows: number, cols: number): boolean {
    const session = this.sessions.get(terminalId);
    if (!session || !session.isAlive) {
      return false;
    }
    const success = OfficialSessionTransport.resizeTerminal(terminalId, rows, cols);
    if (success) {
      session.rows = rows;
      session.cols = cols;
      session.lastActivityAt = Date.now();
    }
    return success;
  }

  getSession(terminalId: number): TerminalSession | undefined {
    return this.sessions.get(terminalId);
  }

  getAllSessions(): TerminalSession[] {
    return Array.from(this.sessions.values());
  }

  getActiveSessions(): TerminalSession[] {
    return Array.from(this.sessions.values()).filter(s => s.isAlive);
  }

  getSessionOutput(terminalId: number): string[] {
    const session = this.sessions.get(terminalId);
    return session ? [...session.outputLines] : [];
  }

  clearSessionOutput(terminalId: number): void {
    const session = this.sessions.get(terminalId);
    if (session) {
      session.outputLines = [];
    }
  }

  addOutputListener(listener: (event: TerminalOutputEvent) => void): void {
    this.outputListeners.push(listener);
  }

  removeOutputListener(listener: (event: TerminalOutputEvent) => void): void {
    const index = this.outputListeners.indexOf(listener);
    if (index > -1) {
      this.outputListeners.splice(index, 1);
    }
  }

  private handleBridgeEvent(event: OfficialSessionEvent): void {
    if (event.kind !== 'terminal-output' && event.kind !== 'terminal-closed') {
      return;
    }
    if (event.kind === 'terminal-output') {
      this.handleTerminalOutput(event);
    } else if (event.kind === 'terminal-closed') {
      this.handleTerminalClosed(event);
    }
  }

  private handleTerminalOutput(event: OfficialSessionEvent): void {
    try {
      const payload: TerminalPayload = JSON.parse(event.detail || '{}') as TerminalPayload;
      const terminalId = payload.terminal_id ?? payload.id ?? 0;
      const data = payload.data ?? '';
      const type = payload.type ?? 'stdout';
      if (terminalId === 0 || data.length === 0) {
        return;
      }
      const session = this.sessions.get(terminalId);
      if (session && session.isAlive) {
        session.outputLines.push(data);
        if (session.outputLines.length > 5000) {
          session.outputLines = session.outputLines.slice(-4000);
        }
        session.lastActivityAt = Date.now();
      }
      const outputEvent: TerminalOutputEvent = {
        terminalId,
        data,
        type: type === 'stderr' ? 'stderr' : 'stdout'
      };
      this.dispatchOutputEvent(outputEvent);
    } catch (error) {
      console.warn('[TerminalService] Failed to parse terminal output:', error);
    }
  }

  private handleTerminalClosed(event: OfficialSessionEvent): void {
    try {
      const payload: TerminalPayload = JSON.parse(event.detail || '{}') as TerminalPayload;
      const terminalId = payload.terminal_id ?? payload.id ?? 0;
      if (terminalId === 0) {
        return;
      }
      const session = this.sessions.get(terminalId);
      if (session) {
        session.isAlive = false;
        this.sessions.delete(terminalId);
        console.log(`[TerminalService] Terminal ${terminalId} closed by remote`);
      }
    } catch (error) {
      console.warn('[TerminalService] Failed to parse terminal closed event:', error);
    }
  }

  private dispatchOutputEvent(event: TerminalOutputEvent): void {
    this.outputListeners.forEach(listener => {
      try {
        listener(event);
      } catch (error) {
        console.error('[TerminalService] Output listener error:', error);
      }
    });
  }

  destroy(): void {
    this.closeAllTerminals();
    OfficialRustDeskBridge.getInstance().removeEventListener(this.bridgeListener);
    this.outputListeners = [];
  }
}
