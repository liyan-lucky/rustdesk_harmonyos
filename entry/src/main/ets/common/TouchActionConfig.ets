export enum TouchAction {
  NONE = 'none',
  LEFT_CLICK = 'left-click',
  LEFT_DOUBLE_CLICK = 'left-double-click',
  RIGHT_CLICK = 'right-click',
  MIDDLE_CLICK = 'middle-click',
  SCREEN_PAN = 'screen-pan',
  SCREEN_SCROLL = 'screen-scroll',
  MARQUEE_SELECT = 'marquee-select',
  LEFT_MARQUEE_SELECT = 'left-marquee-select',
  LEFT_DRAG = 'left-drag',
  ZOOM = 'zoom',
}

export interface TouchGestureConfig {
  duration: number;
  action: TouchAction;
  speed: number;
}

export interface TouchSettings {
  tap: TouchGestureConfig;
  quickDrag: TouchGestureConfig;
  longPress: TouchGestureConfig;
  swipe: TouchGestureConfig;
  shortPressDrag: TouchGestureConfig;
  longPressDrag: TouchGestureConfig;
  twoFingerPinch: TouchGestureConfig;
  twoFingerPan: TouchGestureConfig;
}

export const DEFAULT_TOUCH_SETTINGS: TouchSettings = {
  tap: { duration: 200, action: TouchAction.LEFT_CLICK, speed: 1 },
  quickDrag: { duration: 600, action: TouchAction.LEFT_MARQUEE_SELECT, speed: 1 },
  longPress: { duration: 800, action: TouchAction.RIGHT_CLICK, speed: 1 },
  swipe: { duration: 200, action: TouchAction.SCREEN_PAN, speed: 5 },
  shortPressDrag: { duration: 400, action: TouchAction.SCREEN_SCROLL, speed: 5 },
  longPressDrag: { duration: 800, action: TouchAction.MARQUEE_SELECT, speed: 5 },
  twoFingerPinch: { duration: 100, action: TouchAction.ZOOM, speed: 1 },
  twoFingerPan: { duration: 400, action: TouchAction.SCREEN_PAN, speed: 1 },
};

export const QUICK_DRAG_ACTIONS: TouchAction[] = [
  TouchAction.LEFT_MARQUEE_SELECT,
  TouchAction.MARQUEE_SELECT,
  TouchAction.LEFT_DRAG,
  TouchAction.SCREEN_SCROLL,
  TouchAction.NONE,
];

export const TOUCH_ACTION_LABELS: Record<string, string> = {
  [TouchAction.NONE]: 'None',
  [TouchAction.LEFT_CLICK]: 'Left Click',
  [TouchAction.LEFT_DOUBLE_CLICK]: 'Double Click',
  [TouchAction.RIGHT_CLICK]: 'Right Click',
  [TouchAction.MIDDLE_CLICK]: 'Middle Click',
  [TouchAction.SCREEN_PAN]: 'Screen Pan',
  [TouchAction.SCREEN_SCROLL]: 'Scroll',
  [TouchAction.MARQUEE_SELECT]: 'Right Box',
  [TouchAction.LEFT_MARQUEE_SELECT]: 'Left Box',
  [TouchAction.LEFT_DRAG]: 'Left Drag',
  [TouchAction.ZOOM]: 'Zoom',
};

export const TAP_ACTIONS: TouchAction[] = [
  TouchAction.LEFT_CLICK,
  TouchAction.LEFT_DOUBLE_CLICK,
  TouchAction.MIDDLE_CLICK,
  TouchAction.RIGHT_CLICK,
  TouchAction.NONE,
];

export const LONG_PRESS_ACTIONS: TouchAction[] = [
  TouchAction.RIGHT_CLICK,
  TouchAction.MIDDLE_CLICK,
  TouchAction.LEFT_DOUBLE_CLICK,
  TouchAction.NONE,
];

export const SWIPE_ACTIONS: TouchAction[] = [
  TouchAction.SCREEN_PAN,
  TouchAction.SCREEN_SCROLL,
  TouchAction.NONE,
];

export const SHORT_PRESS_DRAG_ACTIONS: TouchAction[] = [
  TouchAction.SCREEN_SCROLL,
  TouchAction.SCREEN_PAN,
  TouchAction.LEFT_DRAG,
  TouchAction.LEFT_MARQUEE_SELECT,
  TouchAction.MARQUEE_SELECT,
  TouchAction.NONE,
];

export const LONG_PRESS_DRAG_ACTIONS: TouchAction[] = [
  TouchAction.MARQUEE_SELECT,
  TouchAction.LEFT_MARQUEE_SELECT,
  TouchAction.LEFT_DRAG,
  TouchAction.NONE,
];

export const TWO_FINGER_PINCH_ACTIONS: TouchAction[] = [
  TouchAction.ZOOM,
  TouchAction.SCREEN_SCROLL,
  TouchAction.NONE,
];

export const TWO_FINGER_PAN_ACTIONS: TouchAction[] = [
  TouchAction.SCREEN_PAN,
  TouchAction.NONE,
];
