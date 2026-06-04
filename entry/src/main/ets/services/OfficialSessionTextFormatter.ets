export interface ParsedNativeMessageBox {
  msgType: string;
  title: string;
  text: string;
  link: string;
  retry: boolean;
}

export class OfficialSessionTextFormatter {
  static deriveMessageBoxSummary(parsed: ParsedNativeMessageBox): string {
    const msgType = parsed.msgType.trim();
    if (msgType === 'input-password') {
      return '等待密码或远端接受';
    }
    if (msgType === 're-input-password') {
      return '远端密码错误';
    }
    if (msgType === 'wait-remote-accept-nook') {
      return '等待对端接受';
    }
    if (msgType === 'input-2fa') {
      return '需要两步验证';
    }
    if (msgType === 'session-login' || msgType === 'session-login-password' || msgType === 'session-login-re-password') {
      return '等待系统登录';
    }
    if (msgType === 'terminal-admin-login' || msgType === 'terminal-admin-login-password') {
      return '等待终端管理员登录';
    }
    if (msgType === 'relay-hint') {
      return '正在尝试中继';
    }
    if (msgType === 'success') {
      return '会话已连接';
    }
    return '';
  }

  static isBlockingMessageBox(parsed: ParsedNativeMessageBox): boolean {
    const msgType = parsed.msgType.trim();
    return msgType === 're-input-password' ||
      msgType === 'input-2fa' ||
      msgType === 'session-login' ||
      msgType === 'session-login-password' ||
      msgType === 'session-login-re-password' ||
      msgType === 'terminal-admin-login' ||
      msgType === 'terminal-admin-login-password';
  }

  static formatSummary(summary: string): string {
    const normalized = summary.trim();
    if (normalized.length === 0) {
      return '';
    }
    if (normalized === 'Official Harmony bridge ready') {
      return '官方 Harmony 桥接已就绪';
    }
    if (normalized === 'Official Harmony bridge available') {
      return '官方 Harmony 桥接可用';
    }
    if (normalized === 'Official session error') {
      return '官方会话出错';
    }
    if (normalized === 'Official session closed') {
      return '官方会话已关闭';
    }
    if (normalized === 'Official session connected') {
      return '官方会话已连接';
    }
    if (normalized === 'Official session connecting') {
      return '官方会话连接中';
    }
    if (normalized === 'Submitting RustDesk password') {
      return '正在提交会话密码';
    }
    if (normalized.startsWith('Submitting password to ')) {
      return `正在提交 ${normalized.substring('Submitting password to '.length)} 的密码`;
    }
    if (normalized.startsWith('Connecting to ')) {
      return `正在连接 ${normalized.substring('Connecting to '.length)}`;
    }
    if (normalized.startsWith('Connected directly to ')) {
      return `已与 ${normalized.substring('Connected directly to '.length)} 直接连接`;
    }
    if (normalized.startsWith('Connected to ') && normalized.endsWith(' through relay')) {
      return `已通过中继连接 ${normalized.substring('Connected to '.length, normalized.length - ' through relay'.length)}`;
    }
    if (normalized.startsWith('Connected to ')) {
      return `已连接 ${normalized.substring('Connected to '.length)}`;
    }
    if (normalized.startsWith('Connecting ')) {
      return `正在连接 ${normalized.substring('Connecting '.length)}`;
    }
    if (normalized.startsWith('Negotiating session with ')) {
      return `正在与 ${normalized.substring('Negotiating session with '.length)} 协商会话`;
    }
    if (normalized.startsWith('Connected ')) {
      return `已连接 ${normalized.substring('Connected '.length)}`;
    }
    return normalized;
  }

  static formatDetail(detail: string): string {
    const normalized = OfficialSessionTextFormatter.normalizeWhitespace(detail);
    if (normalized.length === 0) {
      return '';
    }
    const parsed = OfficialSessionTextFormatter.parseMessageBox(normalized);
    if (parsed) {
      return OfficialSessionTextFormatter.formatMessageBox(parsed);
    }
    if (normalized === 'Official RustDesk session startup requested') {
      return '已向 RustDesk 官方原生会话发起连接请求。';
    }
    if (normalized === 'The Harmony bridge handed the request to RustDesk\'s official session runtime.') {
      return '连接请求已交给 RustDesk 官方会话运行时，正在等待下一步响应。';
    }
    if (normalized === 'The Harmony bridge submitted a RustDesk password to the active session.') {
      return '已向当前会话提交 RustDesk 密码，正在等待远端响应。';
    }
    if (normalized === 'Official session closed by Harmony') {
      return 'Harmony 侧已关闭当前官方会话。';
    }
    if (normalized === 'Harmony requested the active official session to close.') {
      return '已请求关闭当前官方会话。';
    }
    if (normalized === 'Outgoing connections now use RustDesk\'s official native client session flow.') {
      return '当前外连已经切换到 RustDesk 官方原生会话流程。';
    }
    if (normalized.startsWith('Official Harmony bridge runtime initialized at ')) {
      return `官方 Harmony 桥接运行时已初始化：${normalized.substring('Official Harmony bridge runtime initialized at '.length)}`;
    }
    if (normalized.startsWith('Official RustDesk session established with connection type ')) {
      return `官方会话已建立，连接类型：${normalized.substring('Official RustDesk session established with connection type '.length)}`;
    }
    if (normalized.startsWith('Official channel negotiated: ')) {
      return `官方链路协商完成：${normalized.substring('Official channel negotiated: '.length)}`;
    }
    if (normalized.startsWith('Remote peer fingerprint received: ')) {
      return `已收到对端指纹：${normalized.substring('Remote peer fingerprint received: '.length)}`;
    }
    return normalized;
  }

  static deriveErrorSummary(detail: string): string {
    const normalized = OfficialSessionTextFormatter.normalizeWhitespace(detail);
    if (normalized.includes('currently requires users to log in before connecting')) {
      return '公共服务器要求先登录';
    }
    if (normalized.includes('target device is offline or does not exist')) {
      return '目标设备离线或不存在';
    }
    if (normalized.includes('The connection is not allowed')) {
      return '连接被服务器拒绝';
    }
    if (normalized.includes('Timeout')) {
      return '连接超时';
    }
    // 新增：更详细的错误提示
    if (normalized.includes('Failed to connect')) {
      return '连接失败';
    }
    if (normalized.includes('Invalid')) {
      return '无效的连接参数';
    }
    if (normalized.length > 0 && normalized.length < 100) {
      return normalized; // 返回原始错误信息
    }
    return '官方会话出错';
  }

  static formatEventKind(kind: string): string {
    switch (kind.trim()) {
      case 'connect-requested':
        return '发起连接';
      case 'login-requested':
        return '提交密码';
      case 'session-connected':
        return '会话已连接';
      case 'session-error':
        return '会话错误';
      case 'session-closed':
        return '会话已关闭';
      case 'peer-info':
        return '对端信息';
      case 'peer-fingerprint':
        return '对端指纹';
      case 'connection-type':
        return '连接类型';
      case 'video-frame':
        return '画面事件';
      case 'quality-status':
        return '质量反馈';
      case 'msgbox':
        return '会话提示';
      case 'clipboard':
      case 'clipboard-incoming':
        return '剪贴板';
      case 'runtime-initialized':
        return '运行时已初始化';
      default:
        return kind.trim().length > 0 ? kind.trim() : '未知事件';
    }
  }

  static formatSessionStage(stage: string): string {
    switch (stage.trim()) {
      case 'idle':
        return '空闲';
      case 'connecting':
        return '连接中';
      case 'connected':
        return '已连接';
      case 'error':
        return '错误';
      default:
        return stage.trim().length > 0 ? stage.trim() : '未知';
    }
  }

  static formatRemoteAlias(id: string): string {
    return `远程 ${id.trim()}`;
  }

  private static formatMessageBox(parsed: ParsedNativeMessageBox): string {
    const msgType = parsed.msgType.trim();
    const text = OfficialSessionTextFormatter.normalizeWhitespace(parsed.text);
    if (msgType === 'input-password') {
      return '当前连接没有携带预设密码。若远端配置为密码访问，请填写 RustDesk 密码；也可以先保存密码以便下次自动填充。';
    }
    if (msgType === 're-input-password') {
      return '当前远端密码不正确。请重新输入正确的 RustDesk 密码，或保存新密码以便下次自动填充。';
    }
    if (msgType === 'wait-remote-accept-nook') {
      return '当前连接正在等待对端设备接受。请在远端设备上点击接受后继续等待首帧画面。';
    }
    if (msgType === 'input-2fa') {
      return '当前远端要求 RustDesk 两步验证。HarmonyOS 外壳暂未提供 2FA 输入流程。';
    }
    if (msgType === 'session-login') {
      return '当前远端停留在系统登录界面，需要操作系统账号和密码。HarmonyOS 外壳暂未提供该输入流程。';
    }
    if (msgType === 'session-login-password') {
      return '当前远端停留在系统登录界面，同时需要操作系统账号密码和 RustDesk 密码。HarmonyOS 外壳暂未提供该输入流程。';
    }
    if (msgType === 'session-login-re-password') {
      return '当前远端系统登录流程要求重新输入密码。HarmonyOS 外壳暂未提供该输入流程。';
    }
    if (msgType === 'terminal-admin-login') {
      return '当前终端会话需要管理员系统账号和密码。HarmonyOS 外壳暂未提供该输入流程。';
    }
    if (msgType === 'terminal-admin-login-password') {
      return '当前终端会话同时需要管理员系统账号密码和 RustDesk 密码。HarmonyOS 外壳暂未提供该输入流程。';
    }
    if (msgType === 'relay-hint') {
      return '直连未成功，RustDesk 正在尝试通过中继服务器继续连接。';
    }
    if (msgType === 'success' && text === 'Connected, waiting for image...') {
      return '官方会话已建立，正在等待远端桌面首帧。';
    }
    if (text.includes('currently requires users to log in before connecting')) {
      const lines: string[] = [
        '连接被服务器拒绝。',
        '当前公共演示服务器要求先登录 RustDesk 账号后才能发起连接。',
        '请先登录 RustDesk 账号，或切换到自建服务器后再试。'
      ];
      if (parsed.link.length > 0) {
        lines.push(`登录说明：${parsed.link}`);
      }
      return lines.join('\n');
    }
    if (text.includes('target device is offline or does not exist')) {
      return '连接失败：目标设备当前离线或不存在，请确认对端在线、ID 正确，并且两端服务器配置一致后重试。';
    }
    if (text.includes('The connection is not allowed')) {
      return '连接失败：当前服务器拒绝了这次连接请求。';
    }
    if (text === 'Timeout') {
      return '连接超时，请稍后重试。';
    }
    if (text === 'Reset by the peer') {
      return '连接被对端重置。';
    }
    const title = OfficialSessionTextFormatter.translateTitle(parsed.title);
    if (text.length === 0) {
      return title.length > 0 ? title : msgType;
    }
    if (title.length === 0) {
      return text;
    }
    return `${title}：${text}`;
  }

  static parseMessageBox(detail: string): ParsedNativeMessageBox | null {
    const source = detail.trim();
    if (!source.startsWith('type=')) {
      return null;
    }
    const values = OfficialSessionTextFormatter.parseKeyValueDetail(source);
    const msgType = values['type'] ?? '';
    const title = values['title'] ?? '';
    const text = values['text'] ?? '';
    const link = values['link'] ?? '';
    const retryValue = values['retry'] ?? '';
    if (msgType.length === 0) {
      return null;
    }
    return {
      msgType,
      title,
      text,
      link,
      retry: retryValue === 'true'
    };
  }

  private static parseKeyValueDetail(detail: string): Record<string, string> {
    const result: Record<string, string> = {};
    detail.split(/[;,]/).forEach((segment: string) => {
      const separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0) {
        return;
      }
      const key = segment.slice(0, separatorIndex).trim();
      const value = segment.slice(separatorIndex + 1).trim();
      if (key.length > 0) {
        result[key] = value;
      }
    });
    return result;
  }

  private static translateTitle(title: string): string {
    const normalized = title.trim();
    if (normalized === 'Connection Error') {
      return '连接错误';
    }
    if (normalized === 'Login Error') {
      return '登录错误';
    }
    if (normalized === 'Error') {
      return '错误';
    }
    return normalized;
  }

  private static normalizeWhitespace(value: string): string {
    return value
      .replace(/\r/g, '')
      .replace(/\n{3,}/g, '\n\n')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n[ \t]+/g, '\n')
      .trim();
  }
}
