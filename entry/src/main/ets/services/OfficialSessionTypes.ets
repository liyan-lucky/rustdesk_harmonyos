export enum SessionVideoCodec {
  H264 = 0,
  H265 = 1,
  VP8 = 2,
  VP9 = 3,
  AV1 = 4
}

export enum SessionAudioCodec {
  OPUS = 0,
  AAC = 1,
  PCM = 2
}

export interface SessionVideoFrame {
  codec: SessionVideoCodec;
  width: number;
  height: number;
  data: ArrayBuffer;
  timestamp: number;
  key_frame: boolean;
}

export interface SessionAudioFrame {
  codec: SessionAudioCodec;
  channels: number;
  data: ArrayBuffer;
  timestamp: number;
  sampleRate?: number;
  sample_rate?: number;
}

export class SessionAudioFrameImpl implements SessionAudioFrame {
  codec: SessionAudioCodec = SessionAudioCodec.OPUS;
  channels: number = 1;
  data: ArrayBuffer = new ArrayBuffer(0);
  timestamp: number = 0;
  sampleRate?: number = 48000;
  sample_rate?: number = 48000;
}

export interface SessionMouseInput {
  mask: number;
  x: number;
  y: number;
}

export interface SessionKeyboardInput {
  key_code: number;
  is_pressed: boolean;
  modifiers: number;
}

export interface SessionTouchInput {
  mask: number;
  x: number;
  y: number;
}

export interface SessionClipboardData {
  content: string;
  timestamp: number;
}
