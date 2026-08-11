import hilog from '@ohos.hilog';

const LOG_DOMAIN = 0xA03D00;

export class Logger {
  private static debugEnabled: boolean = false;
  private static sessionLog: string[] = [];
  private static readonly MAX_LOG_ENTRIES: number = 500;

  static setDebugEnabled(enabled: boolean): void {
    Logger.debugEnabled = enabled;
    hilog.info(LOG_DOMAIN, 'Logger', `debug logging ${enabled ? 'ENABLED' : 'DISABLED'}`);
  }

  static isDebugEnabled(): boolean {
    return Logger.debugEnabled;
  }

  static info(tag: string, msg: string): void {
    hilog.error(LOG_DOMAIN, 'JSAPP', `[${tag}] ${msg}`);
    Logger.appendSessionLog(`[INFO][${tag}] ${msg}`);
  }

  static warn(tag: string, msg: string): void {
    hilog.error(LOG_DOMAIN, 'JSAPP', `[${tag}] ${msg}`);
    Logger.appendSessionLog(`[WARN][${tag}] ${msg}`);
  }

  static error(tag: string, msg: string): void {
    hilog.error(LOG_DOMAIN, 'JSAPP', `[${tag}] ${msg}`);
    Logger.appendSessionLog(`[ERROR][${tag}] ${msg}`);
  }

  static debug(tag: string, msg: string): void {
    if (Logger.debugEnabled) {
      hilog.error(LOG_DOMAIN, 'JSAPP', `[${tag}] [DEBUG] ${msg}`);
      Logger.appendSessionLog(`[DEBUG][${tag}] ${msg}`);
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

  static dumpConnectionSummary(): string {
    const lines: string[] = [];
    lines.push('=== Connection Debug Summary ===');
    lines.push(`Time: ${new Date().toISOString()}`);
    lines.push(`Debug enabled: ${Logger.debugEnabled}`);
    lines.push(`Total log entries: ${Logger.sessionLog.length}`);
    lines.push('--- Recent 100 entries ---');
    lines.push(Logger.getRecentLog(100));
    lines.push('=== End Summary ===');
    return lines.join('\n');
  }
}
