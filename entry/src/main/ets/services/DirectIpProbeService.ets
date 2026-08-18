import socket from '@ohos.net.socket';

export interface DirectIpTarget {
  source: string;
  host: string;
  port: number;
  family: number;
}

export class DirectIpProbeService {
  private static readonly DEFAULT_PORT: number = 21118;
  private static readonly ATTEMPTS: number = 3;
  private static readonly REQUIRED_SUCCESSES: number = 2;

  static parseTarget(value: string): DirectIpTarget | null {
    const normalized = value.trim();
    const ipv4Match = normalized.match(/^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$/);
    const ipv6Match = normalized.match(/^\[([0-9a-fA-F:]+)\](?::(\d{1,5}))?$/);
    let host = '';
    let portText = '';
    let family = 1;
    if (ipv4Match !== null) {
      const octets = ipv4Match[1].split('.');
      if (octets.some((part: string) => Number(part) > 255)) {
        return null;
      }
      host = ipv4Match[1];
      portText = ipv4Match[2] ?? '';
    } else if (ipv6Match !== null) {
      host = ipv6Match[1];
      portText = ipv6Match[2] ?? '';
      family = 2;
    } else if (normalized.indexOf(':') >= 0 && /^[0-9a-fA-F:]+$/.test(normalized)) {
      host = normalized;
      family = 2;
    } else {
      return null;
    }
    const port = portText.length > 0 ? Number(portText) : DirectIpProbeService.DEFAULT_PORT;
    if (port <= 0 || port > 65535) {
      return null;
    }
    return { source: normalized, host: host, port: port, family: family };
  }

  static async probe(target: DirectIpTarget): Promise<boolean> {
    let successes = 0;
    for (let attempt = 0; attempt < DirectIpProbeService.ATTEMPTS; attempt += 1) {
      if (await DirectIpProbeService.probeOnce(target)) {
        successes += 1;
      }
      const remaining = DirectIpProbeService.ATTEMPTS - attempt - 1;
      if (successes >= DirectIpProbeService.REQUIRED_SUCCESSES) {
        return true;
      }
      if (successes + remaining < DirectIpProbeService.REQUIRED_SUCCESSES) {
        return false;
      }
    }
    return false;
  }

  private static probeOnce(target: DirectIpTarget): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const tcp = socket.constructTCPSocketInstance();
      let completed = false;
      const finish = (online: boolean): void => {
        if (completed) {
          return;
        }
        completed = true;
        try { void tcp.close(); } catch (_error) {}
        resolve(online);
      };
      const timer = setTimeout(() => finish(false), 1500);
      tcp.connect({
        address: { address: target.host, port: target.port, family: target.family },
        timeout: 1200
      }, (error: Error | undefined) => {
        clearTimeout(timer);
        finish(error === undefined || error === null);
      });
    });
  }
}
