import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import {
  SessionAudioFrame,
  SessionClipboardData,
  SessionKeyboardInput,
  SessionMouseInput,
  SessionVideoFrame
} from './OfficialSessionTypes';
import hilog from '@ohos.hilog';

export class OfficialSessionTransport {
  static closeSession(): boolean {
    return NativeRustDeskBridge.closeSession();
  }

  static sendMouseInput(input: SessionMouseInput): boolean {
    return NativeRustDeskBridge.sendMouseInput(input.mask, input.x, input.y);
  }

  static sendKeyboardInput(input: SessionKeyboardInput): boolean {
    return NativeRustDeskBridge.sendKeyboardInput(input.key_code, input.is_pressed, input.modifiers);
  }

  static sendClipboardData(data: SessionClipboardData): boolean {
    return NativeRustDeskBridge.sendClipboardData(data.content, data.timestamp);
  }

  static sendVideoFrameMetadata(frame: SessionVideoFrame): boolean {
    return NativeRustDeskBridge.sendVideoFrameMetadata(
      frame.codec,
      frame.width,
      frame.height,
      frame.timestamp,
      frame.key_frame,
      frame.data.byteLength
    );
  }

  static sendAudioFrameMetadata(frame: SessionAudioFrame): boolean {
    const sampleRate = frame.sampleRate ?? frame.sample_rate ?? 0;
    return NativeRustDeskBridge.sendAudioFrameMetadata(
      frame.codec,
      sampleRate,
      frame.channels,
      frame.timestamp,
      frame.data.byteLength
    );
  }

  static sendChatMessage(peerId: string, messageType: string, content: string, timestamp: number): boolean {
    hilog.error(0xA03D00, 'Transport', 'sendChatMessage: peerId=' + peerId + ' type=' + messageType + ' contentLen=' + content.length + ' content=[' + content.substring(0, 30) + ']');
    if (messageType !== 'file') {
      const sessionResult = NativeRustDeskBridge.sessionSendChat(content);
      hilog.error(0xA03D00, 'Transport', 'sessionSendChat returned: ' + sessionResult);
      if (sessionResult) {
        return true;
      }
    }
    const fallbackResult = NativeRustDeskBridge.sendChatMessage(peerId, messageType, content, timestamp);
    hilog.error(0xA03D00, 'Transport', 'sendChatMessage fallback returned: ' + fallbackResult);
    return fallbackResult;
  }

  static sendFileTransferRequest(
    taskId: string,
    peerId: string,
    fileName: string,
    totalBytes: number,
    direction: string
  ): boolean {
    return NativeRustDeskBridge.sendFileTransferRequest(taskId, peerId, fileName, totalBytes, direction);
  }

  static openTerminal(terminalId: number, rows: number, cols: number): boolean {
    return NativeRustDeskBridge.openTerminal(terminalId, rows, cols);
  }

  static sendTerminalInput(terminalId: number, data: string): boolean {
    return NativeRustDeskBridge.sendTerminalInput(terminalId, data);
  }

  static resizeTerminal(terminalId: number, rows: number, cols: number): boolean {
    return NativeRustDeskBridge.resizeTerminal(terminalId, rows, cols);
  }

  static closeTerminal(terminalId: number): boolean {
    return NativeRustDeskBridge.closeTerminal(terminalId);
  }

  static readRemoteDirectory(path: string, includeHidden: boolean = false): boolean {
    return NativeRustDeskBridge.readRemoteDirectory(path, includeHidden);
  }

  static createRemoteDirectory(path: string): boolean {
    return NativeRustDeskBridge.createRemoteDirectory(path);
  }

  static deleteRemotePath(path: string, isDirectory: boolean): boolean {
    return NativeRustDeskBridge.deleteRemotePath(path, isDirectory);
  }

  static startFileTransfer(path: string, to: string, isRemote: boolean): boolean {
    return NativeRustDeskBridge.startFileTransfer(path, to, isRemote);
  }
}
