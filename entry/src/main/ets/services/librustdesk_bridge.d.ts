export interface NativeBridgeModule {
  initializeRuntime?(appDir: string, customClientConfig: string): string;
  getCoreSnapshot?(server: string): string;
  pullSessionEvents?(): string;
  pullAudioFrames?(): string;
  getLatestVideoFrameMetadata?(sinceFrameId: number): string | null;
  copyLatestVideoFrame?(frameId: number, expectedBytes: number): ArrayBuffer | null;
  refreshSessionVideo?(display: number): boolean;
  harmonyNextRgba?(display: number): void;
  connectToPeer?(peerId: string, password: string, server: string, relayServer: string, apiServer: string): void;
  accountAuth?(op: string, rememberMe: boolean, server: string, relayServer: string, apiServer: string): void;
  accountAuthCancel?(): void;
  accountAuthResult?(): string;
  getLocalOption?(key: string): string;
  getSessionToggleOption?(key: string): boolean;
  setLocalOption?(key: string, value: string): void;
  applySessionOption?(key: string, value: string): boolean;
  closeSession?(): void;
  reconnectSession?(forceRelay: boolean): boolean;
  restartRemoteDevice?(): boolean;
  lockRemoteScreen?(): boolean;
  submitSessionPassword?(password: string, remember: boolean): boolean;
  setIncomingServiceEnabled?(enabled: boolean, server: string, relayServer: string, apiServer: string): string;
  bootstrapCoreSnapshot?(displayId: string, fingerprint: string, directAddress: string, server: string): string;
  sendMouseInput?(mask: number, x: number, y: number): boolean;
  sendKeyboardInput?(keyCode: number, isPressed: boolean, modifiers: number): boolean;
  sendCtrlAltDel?(): boolean;
  sendClipboardData?(content: string, timestamp: number): boolean;
  sendVideoFrameMetadata?(
    codec: number,
    width: number,
    height: number,
    timestamp: number,
    keyFrame: boolean,
    dataLength: number
  ): boolean;
  sendAudioFrameMetadata?(
    codec: number,
    sampleRate: number,
    channels: number,
    timestamp: number,
    dataLength: number
  ): boolean;
  sendChatMessage?(peerId: string, messageType: string, content: string, timestamp: number): boolean;
  sendFileTransferRequest?(
    taskId: string,
    peerId: string,
    fileName: string,
    totalBytes: number,
    direction: string
  ): boolean;
  openTerminal?(terminalId: number, rows: number, cols: number): boolean;
  sendTerminalInput?(terminalId: number, data: string): boolean;
  resizeTerminal?(terminalId: number, rows: number, cols: number): boolean;
  closeTerminal?(terminalId: number): boolean;
  readRemoteDirectory?(path: string, includeHidden: boolean): boolean;
  createRemoteDirectory?(path: string): boolean;
  deleteRemotePath?(path: string, isDirectory: boolean): boolean;
  startFileTransfer?(path: string, to: string, isRemote: boolean): boolean;
  queryOnlines?(idsJson: string): boolean;
  discoverLanPeers?(): void;
  loadLanPeers?(): string;
  removeDiscoveredPeer?(peerId: string): boolean;
}

declare const rustdeskBridgeLibrary: NativeBridgeModule;
export default rustdeskBridgeLibrary;
