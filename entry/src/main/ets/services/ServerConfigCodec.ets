import util from '@ohos.util';
import { SettingsState } from './AppDataService';

export interface ServerConfigImportResult {
  idServer: string | null;
  relayServer: string | null;
  apiServer: string | null;
  key: string | null;
}

export class ServerConfigCodec {
  static encode(settings: SettingsState): string {
    const config: Record<string, string> = {};
    config['host'] = settings.idServer.trim();
    config['relay'] = settings.relayServer.trim();
    config['api'] = settings.apiServer.trim();
    config['key'] = settings.key.trim();
    const json = JSON.stringify(config);
    const base64 = new util.Base64Helper();
    const textEncoder = new util.TextEncoder();
    const encodedBytes = textEncoder.encodeInto(json);
    const b64Bytes = base64.encodeSync(encodedBytes);
    let b64Str = '';
    for (let i = 0; i < b64Bytes.length; i++) {
      b64Str += String.fromCharCode(b64Bytes[i] as number);
    }
    return b64Str.split('').reverse().join('');
  }

  static decode(raw: string): ServerConfigImportResult | null {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return null;
    }

    try {
      const reversed = trimmed.split('').reverse().join('');
      const base64 = new util.Base64Helper();
      const decodedBytes = base64.decodeSync(reversed);
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonStr = textDecoder.decodeToString(decodedBytes);
      const config = JSON.parse(jsonStr) as Record<string, string>;
      const result: ServerConfigImportResult = {
        idServer: ServerConfigCodec.readField(config, 'idServer', 'host'),
        relayServer: ServerConfigCodec.readField(config, 'relayServer', 'relay'),
        apiServer: ServerConfigCodec.readField(config, 'apiServer', 'api'),
        key: ServerConfigCodec.readField(config, 'key')
      };
      if (result.idServer === null && result.relayServer === null && result.apiServer === null && result.key === null) {
        return null;
      }
      return result;
    } catch (_e) {
      return null;
    }
  }

  private static readField(config: Record<string, string>, primaryKey: string, legacyKey: string = ''): string | null {
    const primary = config[primaryKey];
    if (primary !== undefined && primary !== null) {
      return String(primary);
    }
    if (legacyKey.length > 0) {
      const legacy = config[legacyKey];
      if (legacy !== undefined && legacy !== null) {
        return String(legacy);
      }
    }
    return null;
  }
}
