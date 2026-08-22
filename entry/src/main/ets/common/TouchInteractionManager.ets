import { TouchAction, TouchSettings } from './TouchActionConfig';

export enum TouchInteractionState {
  IDLE = 'idle',
  PRESSED = 'pressed',
  PANNING = 'panning',
  SCROLLING = 'scrolling',
  SHORT_PRESS_DRAG = 'short_press_drag',
  QUICK_DRAG = 'quick_drag',
  LONG_PRESS = 'long_press',
  LONG_PRESS_DRAG = 'long_press_drag',
}

export interface TouchInteractionContext {
  startX: number;
  startY: number;
  currentX: number;
  currentY: number;
  deltaX: number;
  deltaY: number;
  startTime: number;
  duration: number;
  isMoving: boolean;
  isLongPressTriggered: boolean;
  state: TouchInteractionState;
}

export interface MarqueeRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface TouchInteractionListener {
  onAction?: (action: TouchAction, ctx: TouchInteractionContext) => void;
  onActionStart?: (action: TouchAction, ctx: TouchInteractionContext) => void;
  onActionUpdate?: (action: TouchAction, ctx: TouchInteractionContext) => void;
  onActionEnd?: (action: TouchAction, ctx: TouchInteractionContext) => void;
}

export class TouchInteractionManager {
  private ctx: TouchInteractionContext = {
    startX: 0, startY: 0, currentX: 0, currentY: 0,
    deltaX: 0, deltaY: 0, startTime: 0, duration: 0,
    isMoving: false, isLongPressTriggered: false,
    state: TouchInteractionState.IDLE,
  };
  private listener: TouchInteractionListener;
  private settings: TouchSettings;
  private longPressTimer: number = -1;
  private shortPressDragTimer: number = -1;
  private lastTapTime: number = 0;
  private lastTapX: number = 0;
  private lastTapY: number = 0;
  private scrollLastX: number = 0;
  private scrollLastY: number = 0;
  private currentAction: TouchAction = TouchAction.NONE;
  readonly TAP_THRESHOLD: number = 10;

  constructor(listener: TouchInteractionListener, settings: TouchSettings) {
    this.listener = listener;
    this.settings = settings;
  }

  updateSettings(settings: TouchSettings): void {
    this.settings = settings;
  }

  onTouchDown(x: number, y: number): void {
    this.ctx.startX = x;
    this.ctx.startY = y;
    this.ctx.currentX = x;
    this.ctx.currentY = y;
    this.ctx.deltaX = 0;
    this.ctx.deltaY = 0;
    this.ctx.startTime = Date.now();
    this.ctx.duration = 0;
    this.ctx.isMoving = false;
    this.ctx.isLongPressTriggered = false;
    this.ctx.state = TouchInteractionState.PRESSED;
    this.scrollLastX = x;
    this.scrollLastY = y;
    this.currentAction = TouchAction.NONE;
    if (this.settings.longPress.action !== TouchAction.NONE || this.settings.longPressDrag.action !== TouchAction.NONE) {
      this.startLongPressTimer();
    }
  }

  onTouchMove(x: number, y: number): void {
    const deltaX = x - this.ctx.startX;
    const deltaY = y - this.ctx.startY;
    const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);

    this.ctx.currentX = x;
    this.ctx.currentY = y;
    this.ctx.deltaX = deltaX;
    this.ctx.deltaY = deltaY;
    this.ctx.duration = Date.now() - this.ctx.startTime;

    if (this.ctx.state === TouchInteractionState.IDLE) {
      return;
    }

    if (this.ctx.state === TouchInteractionState.LONG_PRESS) {
      if (distance > this.TAP_THRESHOLD && this.settings.longPressDrag.action !== TouchAction.NONE) {
        this.ctx.state = TouchInteractionState.LONG_PRESS_DRAG;
        this.ctx.isMoving = true;
        this.currentAction = this.settings.longPressDrag.action;
        this.scrollLastX = x;
        this.scrollLastY = y;
        this.listener.onActionStart?.(this.currentAction, this.ctx);
      }
      return;
    }

    if (this.ctx.state === TouchInteractionState.LONG_PRESS_DRAG) {
      this.listener.onActionUpdate?.(this.currentAction, this.ctx);
      return;
    }

    if (this.ctx.state === TouchInteractionState.SHORT_PRESS_DRAG || this.ctx.state === TouchInteractionState.QUICK_DRAG) {
      this.listener.onActionUpdate?.(this.currentAction, this.ctx);
      return;
    }

    if (distance > this.TAP_THRESHOLD) {
      this.ctx.isMoving = true;

      if (this.ctx.state === TouchInteractionState.PRESSED) {
        if (this.ctx.duration <= this.settings.swipe.duration && this.settings.swipe.action !== TouchAction.NONE) {
          this.cancelLongPressTimer();
          this.ctx.state = TouchInteractionState.SCROLLING;
          this.currentAction = this.settings.swipe.action;
          this.scrollLastX = x;
          this.scrollLastY = y;
          this.listener.onActionStart?.(this.currentAction, this.ctx);
        } else if (this.ctx.duration >= this.settings.quickDrag.duration && this.settings.quickDrag.action !== TouchAction.NONE) {
          this.cancelLongPressTimer();
          this.ctx.state = TouchInteractionState.QUICK_DRAG;
          this.currentAction = this.settings.quickDrag.action;
          this.scrollLastX = x;
          this.scrollLastY = y;
          this.listener.onActionStart?.(this.currentAction, this.ctx);
        } else if (this.ctx.duration >= this.settings.shortPressDrag.duration && this.settings.shortPressDrag.action !== TouchAction.NONE) {
          this.cancelLongPressTimer();
          this.ctx.state = TouchInteractionState.SHORT_PRESS_DRAG;
          this.currentAction = this.settings.shortPressDrag.action;
          this.scrollLastX = x;
          this.scrollLastY = y;
          this.listener.onActionStart?.(this.currentAction, this.ctx);
        }
      } else if (this.ctx.state === TouchInteractionState.PANNING || this.ctx.state === TouchInteractionState.SCROLLING) {
        this.listener.onActionUpdate?.(this.currentAction, this.ctx);
      }
    }
  }

  onTouchUp(x: number, y: number): void {
    this.cancelLongPressTimer();
    this.cancelShortPressDragTimer();
    this.ctx.currentX = x;
    this.ctx.currentY = y;
    this.ctx.duration = Date.now() - this.ctx.startTime;

    const state = this.ctx.state;

    if (state === TouchInteractionState.LONG_PRESS_DRAG) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    } else if (state === TouchInteractionState.SHORT_PRESS_DRAG || state === TouchInteractionState.QUICK_DRAG) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    } else if (state === TouchInteractionState.PANNING || state === TouchInteractionState.SCROLLING) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    } else if (state === TouchInteractionState.LONG_PRESS) {
      this.listener.onAction?.(this.settings.longPress.action, this.ctx);
    } else if (state === TouchInteractionState.PRESSED && !this.ctx.isMoving) {
      if (this.ctx.duration <= this.settings.tap.duration) {
        if (this.settings.tap.action === TouchAction.LEFT_DOUBLE_CLICK) {
          const now = Date.now();
          const interval = now - this.lastTapTime;
          const dist = Math.sqrt((x - this.lastTapX) ** 2 + (y - this.lastTapY) ** 2);
          if (interval <= this.settings.tap.duration && dist < this.TAP_THRESHOLD) {
            this.listener.onAction?.(TouchAction.LEFT_DOUBLE_CLICK, this.ctx);
            this.lastTapTime = 0;
          } else {
            this.lastTapTime = now;
            this.lastTapX = x;
            this.lastTapY = y;
            this.listener.onAction?.(TouchAction.LEFT_CLICK, this.ctx);
          }
        } else {
          this.listener.onAction?.(this.settings.tap.action, this.ctx);
        }
      }
    }

    this.ctx.state = TouchInteractionState.IDLE;
    this.ctx.isMoving = false;
    this.currentAction = TouchAction.NONE;
  }

  onTouchCancel(): void {
    this.cancelLongPressTimer();
    this.cancelShortPressDragTimer();
    if (this.ctx.state === TouchInteractionState.PANNING || this.ctx.state === TouchInteractionState.SCROLLING) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    } else if (this.ctx.state === TouchInteractionState.LONG_PRESS_DRAG) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    } else if (this.ctx.state === TouchInteractionState.SHORT_PRESS_DRAG || this.ctx.state === TouchInteractionState.QUICK_DRAG) {
      this.listener.onActionEnd?.(this.currentAction, this.ctx);
    }
    this.ctx.state = TouchInteractionState.IDLE;
    this.ctx.isMoving = false;
    this.currentAction = TouchAction.NONE;
  }

  getScrollDeltaX(): number {
    return this.ctx.currentX - this.scrollLastX;
  }

  getScrollDeltaY(): number {
    return this.ctx.currentY - this.scrollLastY;
  }

  updateScrollBaseline(): void {
    this.scrollLastX = this.ctx.currentX;
    this.scrollLastY = this.ctx.currentY;
  }

  getMarqueeRect(): MarqueeRect {
    const left = Math.min(this.ctx.startX, this.ctx.currentX);
    const right = Math.max(this.ctx.startX, this.ctx.currentX);
    const top = Math.min(this.ctx.startY, this.ctx.currentY);
    const bottom = Math.max(this.ctx.startY, this.ctx.currentY);
    const result: MarqueeRect = { left, top, right, bottom };
    return result;
  }

  private startLongPressTimer(): void {
    this.cancelLongPressTimer();
    const lpDuration = Math.min(
      this.settings.longPress.action !== TouchAction.NONE ? this.settings.longPress.duration : Number.MAX_SAFE_INTEGER,
      this.settings.longPressDrag.action !== TouchAction.NONE ? this.settings.longPressDrag.duration : Number.MAX_SAFE_INTEGER,
    );
    if (lpDuration === Number.MAX_SAFE_INTEGER) return;
    this.longPressTimer = setTimeout(() => {
      if (this.ctx.state === TouchInteractionState.PRESSED && !this.ctx.isMoving) {
        this.ctx.isLongPressTriggered = true;
        this.ctx.state = TouchInteractionState.LONG_PRESS;
      }
      this.longPressTimer = -1;
    }, lpDuration);
  }

  private cancelLongPressTimer(): void {
    if (this.longPressTimer !== -1) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = -1;
    }
  }

  private startShortPressDragTimer(): void {
    this.cancelShortPressDragTimer();
    if (this.settings.shortPressDrag.action === TouchAction.NONE) return;
    const delay = this.settings.shortPressDrag.duration;
    if (delay <= 0) return;
    this.shortPressDragTimer = setTimeout(() => {
      if (this.ctx.state === TouchInteractionState.PRESSED && !this.ctx.isMoving) {
        // finger still held but not moving - short press drag timer expired without movement
      }
      this.shortPressDragTimer = -1;
    }, delay);
  }

  private cancelShortPressDragTimer(): void {
    if (this.shortPressDragTimer !== -1) {
      clearTimeout(this.shortPressDragTimer);
      this.shortPressDragTimer = -1;
    }
  }
}
