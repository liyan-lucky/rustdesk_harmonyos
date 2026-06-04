import { ControlParams, ControlResponseData } from '../common/Types';
import util from '@ohos.util';

export const LEGACY_ARKTS_PROTOCOL_ONLY = true;

/**
 * RustDesk 协议定义
 * 基于 RustDesk 官方协议实现
 */

/**
 * 消息类型枚举
 */
export enum MessageType {
  // 连接相关
  DISCOVERY = 0,
  LOGIN_REQUEST = 1,
  LOGIN_RESPONSE = 2,
  KEEP_ALIVE = 3,

  // 视频相关
  VIDEO_FRAME = 100,
  VIDEO_ACK = 101,

  // 输入相关
  MOUSE_INPUT = 200,
  KEYBOARD_INPUT = 201,
  TOUCH_INPUT = 202,

  // 剪贴板相关
  CLIPBOARD_DATA = 300,

  // 文件传输相关
  FILE_READ = 400,
  FILE_WRITE = 401,
  FILE_DATA = 402,

  // 音频相关
  AUDIO_FRAME = 500,

  // 控制相关
  CONTROL_REQUEST = 600,
  CONTROL_RESPONSE = 601,

  // 错误相关
  ERROR = 999
}

/**
 * 视频编码格式
 */
export enum VideoCodec {
  H264 = 0,
  H265 = 1,
  VP8 = 2,
  VP9 = 3,
  AV1 = 4
}

/**
 * 音频编码格式
 */
export enum AudioCodec {
  OPUS = 0,
  AAC = 1,
  PCM = 2
}

/**
 * 登录请求
 */
export interface LoginRequest {
  id: string;
  password: string;
  version: string;
  os_type: string;
  username: string;
  hostname: string;
}

/**
 * 登录响应
 */
export interface LoginResponse {
  success: boolean;
  error?: string;
  peer_id?: string;
  peer_username?: string;
  peer_hostname?: string;
}

/**
 * 视频帧数据
 */
export interface VideoFrame {
  codec: VideoCodec;
  width: number;
  height: number;
  data: ArrayBuffer;
  timestamp: number;
  key_frame: boolean;
}

/**
 * 鼠标输入事件
 */
export interface MouseInput {
  mask: number; // 鼠标按键掩码
  x: number;    // X坐标
  y: number;    // Y坐标
}

/**
 * 键盘输入事件
 */
export interface KeyboardInput {
  key_code: number;
  is_pressed: boolean;
  modifiers: number;
}

/**
 * 触摸输入事件
 */
export interface TouchInput {
  mask: number;
  x: number;
  y: number;
}

/**
 * 剪贴板数据
 */
export interface ClipboardData {
  content: string;
  timestamp: number;
}

/**
 * 文件读取请求
 */
export interface FileReadRequest {
  path: string;
  offset: number;
  size: number;
}

/**
 * 文件写入请求
 */
export interface FileWriteRequest {
  path: string;
  offset: number;
  data: ArrayBuffer;
}

/**
 * 音频帧数据
 */
export interface AudioFrame {
  codec: AudioCodec;
  sample_rate: number;
  channels: number;
  data: ArrayBuffer;
  timestamp: number;
}

/**
 * 控制请求
 */
export interface ControlRequest {
  action: string;
  params: ControlParams;
}

/**
 * 控制响应
 */
export interface ControlResponse {
  success: boolean;
  error?: string;
  data?: ControlResponseData;
}

/**
 * 错误消息
 */
export interface ErrorMessage {
  code: number;
  message: string;
}

/**
 * 协议消息基类
 */
export interface ProtocolMessage {
  type: MessageType;
  sequence: number;
  timestamp: number;
}

/**
 * 消息编码器
 */
export class MessageEncoder {
  /**
   * 编码登录请求
   */
  static encodeLoginRequest(request: LoginRequest): ArrayBuffer {
    const json = JSON.stringify(request);
    const encoder = new util.TextEncoder();
    const data = encoder.encode(json);

    // 创建消息头
    const header = new ArrayBuffer(12);
    const headerView = new DataView(header);

    // 消息类型 (4字节)
    headerView.setUint32(0, MessageType.LOGIN_REQUEST);
    // 消息长度 (4字节)
    headerView.setUint32(4, data.length);
    // 序列号 (4字节)
    headerView.setUint32(8, 0);

    // 合并头和数据
    const result = new ArrayBuffer(header.byteLength + data.byteLength);
    const resultView = new Uint8Array(result);
    resultView.set(new Uint8Array(header), 0);
    resultView.set(new Uint8Array(data), header.byteLength);

    return result;
  }

  /**
   * 编码视频帧
   */
  static encodeVideoFrame(frame: VideoFrame, sequence: number): ArrayBuffer {
    // 视频帧头部 (16字节)
    const header = new ArrayBuffer(16);
    const headerView = new DataView(header);

    // 消息类型 (4字节)
    headerView.setUint32(0, MessageType.VIDEO_FRAME);
    // 序列号 (4字节)
    headerView.setUint32(4, sequence);
    // 编码格式 (1字节)
    headerView.setUint8(8, frame.codec);
    // 关键帧标志 (1字节)
    headerView.setUint8(9, frame.key_frame ? 1 : 0);
    // 宽度 (2字节)
    headerView.setUint16(10, frame.width);
    // 高度 (2字节)
    headerView.setUint16(12, frame.height);
    // 数据长度 (4字节)
    headerView.setUint32(14, frame.data.byteLength);

    // 合并头和数据
    const result = new ArrayBuffer(header.byteLength + frame.data.byteLength);
    const resultView = new Uint8Array(result);
    resultView.set(new Uint8Array(header), 0);
    resultView.set(new Uint8Array(frame.data), header.byteLength);

    return result;
  }

  /**
   * 编码鼠标输入
   */
  static encodeMouseInput(input: MouseInput, sequence: number): ArrayBuffer {
    const data = new ArrayBuffer(20);
    const view = new DataView(data);

    // 消息类型 (4字节)
    view.setUint32(0, MessageType.MOUSE_INPUT);
    // 序列号 (4字节)
    view.setUint32(4, sequence);
    // 掩码 (4字节)
    view.setUint32(8, input.mask);
    // X坐标 (4字节)
    view.setInt32(12, input.x);
    // Y坐标 (4字节)
    view.setInt32(16, input.y);

    return data;
  }

  /**
   * 编码键盘输入
   */
  static encodeKeyboardInput(input: KeyboardInput, sequence: number): ArrayBuffer {
    const data = new ArrayBuffer(16);
    const view = new DataView(data);

    // 消息类型 (4字节)
    view.setUint32(0, MessageType.KEYBOARD_INPUT);
    // 序列号 (4字节)
    view.setUint32(4, sequence);
    // 键码 (4字节)
    view.setUint32(8, input.key_code);
    // 是否按下 (1字节)
    view.setUint8(12, input.is_pressed ? 1 : 0);
    // 修饰符 (4字节)
    view.setUint32(13, input.modifiers);

    return data;
  }

  /**
   * 编码剪贴板数据
   */
  static encodeClipboardData(data: ClipboardData, sequence: number): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const contentBytes = encoder.encode(data.content);

    const header = new ArrayBuffer(16);
    const headerView = new DataView(header);

    // 消息类型 (4字节)
    headerView.setUint32(0, MessageType.CLIPBOARD_DATA);
    // 序列号 (4字节)
    headerView.setUint32(4, sequence);
    // 时间戳 (8字节)
    headerView.setBigUint64(8, BigInt(data.timestamp));
    // 内容长度 (4字节)
    headerView.setUint32(12, contentBytes.length);

    // 合并头和内容
    const result = new ArrayBuffer(header.byteLength + contentBytes.length);
    const resultView = new Uint8Array(result);
    resultView.set(new Uint8Array(header), 0);
    resultView.set(contentBytes, header.byteLength);

    return result;
  }
}

/**
 * 消息解码器
 */
export class MessageDecoder {
  /**
   * 解码消息
   */
  static decodeMessage(data: ArrayBuffer): ProtocolMessage | null {
    if (data.byteLength < 12) {
      return null;
    }

    const view = new DataView(data);
    const type = view.getUint32(0);
    const sequence = view.getUint32(8);
    const timestamp = Date.now();

    return {
      type,
      sequence,
      timestamp
    };
  }

  /**
   * 解码登录响应
   */
  static decodeLoginResponse(data: ArrayBuffer): LoginResponse | null {
    try {
      const decoder = new util.TextDecoder();
      const json = decoder.decodeWithStream(new Uint8Array(data));
      return JSON.parse(json) as LoginResponse;
    } catch (error) {
      console.error('Failed to decode login response:', error);
      return null;
    }
  }

  /**
   * 解码视频帧
   */
  static decodeVideoFrame(data: ArrayBuffer): VideoFrame | null {
    if (data.byteLength < 16) {
      return null;
    }

    const headerView = new DataView(data);
    const codec = headerView.getUint8(8);
    const keyFrame = headerView.getUint8(9) === 1;
    const width = headerView.getUint16(10);
    const height = headerView.getUint16(12);
    const dataLength = headerView.getUint32(14);

    if (data.byteLength < 16 + dataLength) {
      return null;
    }

    const frameData = data.slice(16, 16 + dataLength);

    return {
      codec,
      width,
      height,
      data: frameData,
      timestamp: Date.now(),
      key_frame: keyFrame
    };
  }

  /**
   * 解码鼠标输入
   */
  static decodeMouseInput(data: ArrayBuffer): MouseInput | null {
    if (data.byteLength < 20) {
      return null;
    }

    const view = new DataView(data);
    const mask = view.getUint32(8);
    const x = view.getInt32(12);
    const y = view.getInt32(16);

    return {
      mask,
      x,
      y
    };
  }

  /**
   * 解码键盘输入
   */
  static decodeKeyboardInput(data: ArrayBuffer): KeyboardInput | null {
    if (data.byteLength < 16) {
      return null;
    }

    const view = new DataView(data);
    const keyCode = view.getUint32(8);
    const isPressed = view.getUint8(12) === 1;
    const modifiers = view.getUint32(13);

    return {
      key_code: keyCode,
      is_pressed: isPressed,
      modifiers
    };
  }

  /**
   * 解码剪贴板数据
   */
  static decodeClipboardData(data: ArrayBuffer): ClipboardData | null {
    if (data.byteLength < 16) {
      return null;
    }

    const headerView = new DataView(data);
    const timestamp = Number(headerView.getBigUint64(8));
    const contentLength = headerView.getUint32(12);

    if (data.byteLength < 16 + contentLength) {
      return null;
    }

    const decoder = new util.TextDecoder();
    const content = decoder.decodeWithStream(new Uint8Array(data.slice(16, 16 + contentLength)));

    return {
      content,
      timestamp
    };
  }
}
