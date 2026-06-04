
import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

/**
 * 密码验证结果接口
 */
interface PasswordValidationResult {
  valid: boolean;
  message: string;
}

/**
 * 设备ID生成器
 * 基于 RustDesk 官方的设备ID生成算法
 */

/**
 * 设备ID生成器类
 */
export class DeviceIdGenerator {
  private static instance: DeviceIdGenerator;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): DeviceIdGenerator {
    if (!DeviceIdGenerator.instance) {
      DeviceIdGenerator.instance = new DeviceIdGenerator();
    }
    return DeviceIdGenerator.instance;
  }

  /**
   * 生成设备ID
   * 基于设备的唯一信息生成
   * @returns 设备ID (9位数字)
   */
  async generateDeviceId(): Promise<string> {
    try {
      // 获取设备唯一标识
      const deviceInfo = await this.getDeviceUniqueInfo();

      // 使用 SHA256 哈希
      const hash = await this.sha256(deviceInfo);

      // 将哈希转换为数字ID
      const numericId = this.hashToNumericId(hash);

      return numericId;
    } catch (error) {
      console.error('Failed to generate device ID:', error);
      // 生成随机ID作为后备
      return this.generateRandomId();
    }
  }
  /**
   * 获取设备唯一信息
   */
  private async getDeviceUniqueInfo(): Promise<string> {
    // 使用设备信息生成唯一字符串
    // 注意：实际应用中应该使用更可靠的设备标识
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2);
    const platform = 'harmonyos';
    
    return JSON.stringify({ timestamp, random: randomStr, platform });
  }

  /**
   * SHA256 哈希
   */
  private async sha256(data: string): Promise<Uint8Array> {
    try {
      const mdAlgName = 'SHA256';
      const md = cryptoFramework.createMd(mdAlgName);
      const encoder = new util.TextEncoder();

      const dataBlob: cryptoFramework.DataBlob = {
        data: encoder.encode(data)
      };

      await md.update(dataBlob);
      const mdOutput = await md.digest();

      return mdOutput.data;
    } catch (error) {
      console.error('SHA256 hash failed:', error);
      throw new Error(`SHA256 hash failed: ${error}`);
    }
  }

  /**
   * 将哈希转换为数字ID
   */
  private hashToNumericId(hash: Uint8Array): string {
    // 取前几个字节转换为数字
    let num = 0;
    for (let i = 0; i < Math.min(4, hash.length); i++) {
      num = (num << 8) | hash[i];
    }

    // 确保是9位正数
    const id = Math.abs(num) % 1000000000;

    // 格式化为9位数字，前面补零
    return id.toString().padStart(9, '0');
  }

  /**
   * 生成随机ID（后备方案）
   */
  private generateRandomId(): string {
    const randomNum = Math.floor(Math.random() * 1000000000);
    return randomNum.toString().padStart(9, '0');
  }

  /**
   * 验证设备ID格式
   */
  static validateDeviceId(id: string): boolean {
    // 检查是否为9位数字
    return /^\d{9}$/.test(id);
  }

  /**
   * 格式化设备ID显示
   * 将9位数字格式化为 123 456 789 的形式
   */
  static formatDeviceId(id: string): string {
    if (id.length !== 9) {
      return id;
    }

    return `${id.slice(0, 3)} ${id.slice(3, 6)} ${id.slice(6, 9)}`;
  }

  /**
   * 解析格式化的设备ID
   * 将 "123 456 789" 转换为 "123456789"
   */
  static parseDeviceId(formattedId: string): string {
    return formattedId.replace(/\s/g, '');
  }
}

/**
 * 密码生成器
 */
export class PasswordGenerator {
  /**
   * 生成随机密码
   * @param length 密码长度
   * @returns 随机密码
   */
  static generateRandomPassword(length: number = 6): string {
    const chars = '23456789abcdefghijkmnpqrstuvwxyz';
    let password = '';
    for (let i = 0; i < length; i++) {
      const randomIndex = Math.floor(Math.random() * chars.length);
      password += chars.charAt(randomIndex);
    }

    return password;
  }
  /**
   * 验证密码强度
   */
  static validatePassword(password: string): PasswordValidationResult {
    if (password.length < 6) {
      return {
        valid: false,
        message: '密码长度至少为6位'
      };
    }

    if (password.length > 20) {
      return {
        valid: false,
        message: '密码长度不能超过20位'
      };
    }

    return {
      valid: true,
      message: '密码有效'
    };
  }
}

/**
 * 密码加密工具
 */
export class PasswordCrypto {
  /**
   * 对密码进行哈希
   */
  static async hashPassword(password: string): Promise<string> {
    try {
      const mdAlgName = 'SHA256';
      const md = cryptoFramework.createMd(mdAlgName);
      const encoder = new util.TextEncoder();

      const dataBlob: cryptoFramework.DataBlob = {
        data: encoder.encode(password)
      };

      await md.update(dataBlob);
      const mdOutput = await md.digest();

      // 转换为十六进制字符串
      const hexString = Array.from(mdOutput.data)
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');

      return hexString;
    } catch (error) {
      console.error('Password hash failed:', error);
      throw new Error('Password hash failed');
    }
  }

  /**
   * 验证密码
   */
  static async verifyPassword(password: string, hash: string): Promise<boolean> {
    try {
      const passwordHash = await PasswordCrypto.hashPassword(password);
      return passwordHash === hash;
    } catch (error) {
      console.error('Password verification failed:', error);
      return false;
    }
  }
}
