type EventListener = (data?: ESObject) => void;

interface ListenerEntry {
  listener: EventListener;
  once: boolean;
}

class EventQueueItem {
  type: string = '';
  data?: ESObject;
}

export enum EventType {
  FRAME_RECEIVED = 'frame:received',
  FRAME_RENDERED = 'frame:rendered',
  SESSION_CONNECTED = 'session:connected',
  SESSION_DISCONNECTED = 'session:disconnected',
  SESSION_ERROR = 'session:error',
  SESSION_STATE_CHANGED = 'session:state_changed',
  ACCOUNT_LOGIN = 'account:login',
  ACCOUNT_LOGOUT = 'account:logout',
  ACCOUNT_STATE_CHANGED = 'account:state_changed',
  CLIPBOARD_CHANGED = 'clipboard:changed',
  FILE_TRANSFER_PROGRESS = 'file:transfer_progress',
  FILE_TRANSFER_COMPLETE = 'file:transfer_complete',
  CHAT_MESSAGE = 'chat:message',
  TERMINAL_OUTPUT = 'terminal:output',
  AUDIO_FRAME = 'audio:frame',
  THEME_CHANGED = 'theme:changed',
  LANGUAGE_CHANGED = 'language:changed',
  SETTINGS_CHANGED = 'settings:changed',
  ADDRESS_BOOK_UPDATED = 'address_book:updated'
}

export class EventBus {
  private static instance: EventBus;
  private listeners: Map<string, ListenerEntry[]> = new Map();
  private eventQueue: EventQueueItem[] = [];
  private isProcessing: boolean = false;
  private maxListenersPerEvent: number = 50;

  private constructor() {}

  static getInstance(): EventBus {
    if (!EventBus.instance) {
      EventBus.instance = new EventBus();
    }
    return EventBus.instance;
  }

  on(event: string | EventType, listener: EventListener): void {
    this.addListener(event, listener, false);
  }

  once(event: string | EventType, listener: EventListener): void {
    this.addListener(event, listener, true);
  }

  off(event: string | EventType, listener: EventListener): void {
    const key = String(event);
    const entries = this.listeners.get(key);
    if (!entries) {
      return;
    }

    const index = entries.findIndex(e => e.listener === listener);
    if (index >= 0) {
      entries.splice(index, 1);
    }

    if (entries.length === 0) {
      this.listeners.delete(key);
    }
  }

  emit(event: string | EventType, data?: ESObject): void {
    const key = String(event);
    const entries = this.listeners.get(key);
    if (!entries || entries.length === 0) {
      return;
    }

    const toRemove: number[] = [];
    entries.forEach((entry, index) => {
      try {
        entry.listener(data);
        if (entry.once) {
          toRemove.push(index);
        }
      } catch (error) {
        console.error(`[EventBus] Listener error for "${key}":`, error);
      }
    });

    for (let i = toRemove.length - 1; i >= 0; i--) {
      entries.splice(toRemove[i], 1);
    }

    if (entries.length === 0) {
      this.listeners.delete(key);
    }
  }

  emitAsync(event: string | EventType, data?: ESObject): void {
    const item: EventQueueItem = new EventQueueItem();
    item.type = String(event);
    item.data = data;
    this.eventQueue.push(item);
    if (!this.isProcessing) {
      this.processQueue();
    }
  }

  private processQueue(): void {
    if (this.eventQueue.length === 0) {
      this.isProcessing = false;
      return;
    }

    this.isProcessing = true;
    const item = this.eventQueue.shift();
    if (item) {
      this.emit(item.type, item.data);
    }

    setTimeout(() => {
      this.processQueue();
    }, 0);
  }

  private addListener(event: string | EventType, listener: EventListener, once: boolean): void {
    const key = String(event);
    let entries = this.listeners.get(key);
    if (!entries) {
      entries = [];
      this.listeners.set(key, entries);
    }

    if (entries.length >= this.maxListenersPerEvent) {
      console.warn(`[EventBus] Max listeners (${this.maxListenersPerEvent}) reached for "${key}"`);
      return;
    }

    const exists = entries.some(e => e.listener === listener);
    if (exists) {
      return;
    }

    entries.push({ listener, once });
  }

  clear(event?: string | EventType): void {
    if (event) {
      this.listeners.delete(String(event));
    } else {
      this.listeners.clear();
    }
  }

  listenerCount(event: string | EventType): number {
    const entries = this.listeners.get(String(event));
    return entries ? entries.length : 0;
  }

  hasListeners(event: string | EventType): boolean {
    const entries = this.listeners.get(String(event));
    return entries !== undefined && entries.length > 0;
  }
}

export const eventBus = EventBus.getInstance();
