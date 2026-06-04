export class DeviceIdFormatter {
  static parse(value: string): string {
    return value.replace(/\s+/g, '').trim();
  }

  static format(value: string): string {
    const normalized = DeviceIdFormatter.parse(value);
    if (normalized.length === 0) {
      return '';
    }
    const match = normalized.match(/^(\d+)(.*)$/);
    if (match === null) {
      return normalized;
    }
    const digits = match[1];
    const suffix = match[2];
    const groups: string[] = [];
    for (let end = digits.length; end > 0; end -= 3) {
      const start = Math.max(0, end - 3);
      groups.unshift(digits.slice(start, end));
    }
    return `${groups.join(' ')}${suffix}`;
  }

  static formatRemoteLabel(deviceId: string, prefix: string = '远程'): string {
    const formattedId = DeviceIdFormatter.format(deviceId);
    if (formattedId.length === 0) {
      return prefix;
    }
    return `${prefix} ${formattedId}`;
  }
}
