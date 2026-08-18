import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xA03D00;

export class Logger {
  private static debugEnabled: boolean = false;
  private static sessionLog: string[] = [];
  private static debugStartedAt: string = '';
  private static readonly MAX_LOG_ENTRIES: number = 1000;

  static setDebugEnabled(enabled: boolean): void {
    if (Logger.debugEnabled === enabled) {
      return;
    }
    Logger.debugEnabled = enabled;
    Logger.debugStartedAt = enabled ? new Date().toISOString() : '';
    hilog.info(LOG_DOMAIN, 'Logger', `debug logging ${enabled ? 'ENABLED' : 'DISABLED'}`);
    Logger.appendSessionLog(`[INFO][APP] Debug mode ${enabled ? 'enabled' : 'disabled'}`);
  }

  static isDebugEnabled(): boolean {
    return Logger.debugEnabled;
  }

  static info(tag: string, msg: string): void {
    const safeMsg = Logger.sanitize(msg);
    console.info(`[${tag}] ${safeMsg}`);
    Logger.appendSessionLog(`[INFO][${tag}] ${safeMsg}`);
  }

  static warn(tag: string, msg: string): void {
    const safeMsg = Logger.sanitize(msg);
    console.warn(`[${tag}] ${safeMsg}`);
    Logger.appendSessionLog(`[WARN][${tag}] ${safeMsg}`);
  }

  static error(tag: string, msg: string): void {
    const safeMsg = Logger.sanitize(msg);
    console.error(`[${tag}] ${safeMsg}`);
    Logger.appendSessionLog(`[ERROR][${tag}] ${safeMsg}`);
  }

  static debug(tag: string, msg: string): void {
    if (Logger.debugEnabled) {
      const safeMsg = Logger.sanitize(msg);
      console.debug(`[${tag}] [DEBUG] ${safeMsg}`);
      Logger.appendSessionLog(`[DEBUG][${tag}] ${safeMsg}`);
    }
  }

  static appendSessionLog(entry: string): void {
    const timestamp = new Date().toISOString();
    const line = `${timestamp} ${entry}`;
    Logger.sessionLog.push(line);
    if (Logger.sessionLog.length > Logger.MAX_LOG_ENTRIES) {
      Logger.sessionLog.shift();
    }
  }

  static getSessionLog(): string {
    return Logger.sessionLog.join('\n');
  }

  static getRecentLog(count: number): string {
    const start = Math.max(0, Logger.sessionLog.length - count);
    return Logger.sessionLog.slice(start).join('\n');
  }

  static clearSessionLog(): void {
    Logger.sessionLog = [];
  }

  static getLogEntryCount(): number {
    return Logger.sessionLog.length;
  }

  static getDebugStartedAt(): string {
    return Logger.debugStartedAt;
  }

  private static sanitize(msg: string): string {
    return msg
      .replace(/(authorization\s*[:=]\s*)([^\s,;]+)/gi, '$1<redacted>')
      .replace(/((?:access[_-]?token|refresh[_-]?token|password|passwd|secret)\s*[:=]\s*)([^\s,;]+)/gi, '$1<redacted>')
      .replace(/([?&](?:access_token|token|password)=)([^&#\s]+)/gi, '$1<redacted>');
  }

  static dumpConnectionSummary(): string {
    const lines: string[] = [];
    lines.push('=== Connection Debug Summary ===');
    lines.push(`Time: ${new Date().toISOString()}`);
    lines.push(`Debug enabled: ${Logger.debugEnabled}`);
    lines.push(`Debug started at: ${Logger.debugStartedAt || '-'}`);
    lines.push(`Total log entries: ${Logger.sessionLog.length}`);
    lines.push('--- Recent 100 entries ---');
    lines.push(Logger.getRecentLog(100));
    lines.push('=== End Summary ===');
    return lines.join('\n');
  }
}
