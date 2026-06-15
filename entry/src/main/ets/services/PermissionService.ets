import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { AppContextService } from './AppContextService';
import { FileAuthorizationService } from './FileAuthorizationService';

export enum PermissionStatus {
  NOT_REQUESTED = 'not_requested',
  GRANTED = 'granted',
  DENIED = 'denied',
  PERMANENTLY_DENIED = 'permanently_denied'
}

export interface PermissionConfig {
  name: Permissions;
  reason: string;
  required: boolean;
}

export interface PermissionRequestResult {
  permission: string;
  status: PermissionStatus;
}

export interface PermissionSummary {
  allGranted: boolean;
  results: PermissionRequestResult[];
}

export interface FileAuthorizationOptions {
  folder?: boolean;
  authMode?: boolean;
  defaultFilePathUri?: string;
  maxSelectNumber?: number;
}

export interface FileAuthorizationResult {
  granted: boolean;
  uris: string[];
  permissionResults: PermissionRequestResult[];
  error: string;
}

export class PermissionService {
  private static instance: PermissionService;
  private atManager: abilityAccessCtrl.AtManager;

  private constructor() {
    this.atManager = abilityAccessCtrl.createAtManager();
  }

  static getInstance(): PermissionService {
    if (!PermissionService.instance) {
      PermissionService.instance = new PermissionService();
    }
    return PermissionService.instance;
  }

  getRequiredPermissions(): PermissionConfig[] {
    return [
      {
        name: 'ohos.permission.CAMERA',
        reason: 'Required for QR code scanning.',
        required: false
      },
      {
        name: 'ohos.permission.INPUT_MONITORING',
        reason: 'Required for monitoring remote input events.',
        required: false
      },
      {
        name: 'ohos.permission.MICROPHONE',
        reason: 'Required for audio features.',
        required: false
      },
      {
        name: 'ohos.permission.SYSTEM_FLOAT_WINDOW',
        reason: 'Required for floating window features.',
        required: false
      },
      {
        name: 'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY',
        reason: 'Required for file transfer features.',
        required: false
      },
      {
        name: 'ohos.permission.FILE_ACCESS_PERSIST',
        reason: 'Required to keep file access authorization for file transfer.',
        required: false
      },
      {
        name: 'ohos.permission.READ_PASTEBOARD',
        reason: 'Required for clipboard sync and paste to remote sessions.',
        required: false
      },
      {
        name: 'ohos.permission.KEEP_BACKGROUND_RUNNING',
        reason: 'Required to keep the session alive in background.',
        required: true
      },
      {
        name: 'ohos.permission.READ_LOCAL_DEVICE_NAME',
        reason: 'Required to read the device name for display.',
        required: false
      }
    ];
  }

  async checkPermission(permission: Permissions): Promise<PermissionStatus> {
    try {
      const grantStatus = await this.atManager.checkAccessToken(0, permission);
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return PermissionStatus.GRANTED;
      }
      return PermissionStatus.DENIED;
    } catch (error) {
      console.error('Check permission failed:', error);
      return PermissionStatus.NOT_REQUESTED;
    }
  }

  async requestPermission(permission: Permissions): Promise<PermissionStatus> {
    const context = AppContextService.getContext();
    if (!context) {
      console.error('Request permission failed: missing UI ability context');
      return PermissionStatus.DENIED;
    }

    try {
      const permissions: Permissions[] = [permission];
      const result = await this.atManager.requestPermissionsFromUser(context, permissions);
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return PermissionStatus.GRANTED;
      }
      return PermissionStatus.DENIED;
    } catch (error) {
      console.error('Request permission failed:', error);
      return PermissionStatus.DENIED;
    }
  }

  async requestPermissions(permissions: Permissions[]): Promise<PermissionRequestResult[]> {
    if (permissions.length === 0) {
      return [];
    }

    const context = AppContextService.getContext();
    if (!context) {
      return this.createDeniedResults(permissions);
    }

    try {
      const results = await this.atManager.requestPermissionsFromUser(context, permissions);
      const mappedResults: PermissionRequestResult[] = [];

      for (let index = 0; index < permissions.length; index++) {
        const granted = index < results.authResults.length && results.authResults[index] === 0;
        const item: PermissionRequestResult = {
          permission: permissions[index],
          status: granted ? PermissionStatus.GRANTED : PermissionStatus.DENIED
        };
        mappedResults.push(item);
      }

      return mappedResults;
    } catch (error) {
      console.error('Request permissions failed:', error);
      return this.createDeniedResults(permissions);
    }
  }

  async requestFileAuthorization(options?: FileAuthorizationOptions): Promise<FileAuthorizationResult> {
    const result = await FileAuthorizationService.requestFileAuthorization(options);
    const permissionResults: PermissionRequestResult[] = result.permissionResults.map((item) => {
      return {
        permission: item.permission,
        status: item.status === PermissionStatus.GRANTED ? PermissionStatus.GRANTED : PermissionStatus.DENIED
      };
    });
    return {
      granted: result.granted,
      uris: result.uris,
      permissionResults,
      error: result.error
    };
  }

  async requestFileAccessAuthorization(): Promise<boolean> {
    const result = await this.requestFileAuthorization({ folder: true, authMode: true });
    return result.granted;
  }

  async requestShareRuntimePermissions(): Promise<PermissionSummary> {
    const results = await this.requestPermissions([
      'ohos.permission.KEEP_BACKGROUND_RUNNING' as Permissions,
      'ohos.permission.READ_LOCAL_DEVICE_NAME' as Permissions
    ]);
    return this.buildPermissionSummary(results);
  }

  async requestAllFeaturePermissions(): Promise<PermissionSummary> {
    const permissions = this.getRequiredPermissions().map((config: PermissionConfig) => config.name);
    const results = await this.requestPermissions(permissions);
    return this.buildPermissionSummary(results);
  }

  async checkAllRequiredPermissions(): Promise<PermissionSummary> {
    const permissions = this.getRequiredPermissions();
    const results: PermissionRequestResult[] = [];

    for (let index = 0; index < permissions.length; index++) {
      const config = permissions[index];
      const status = await this.checkPermission(config.name);
      const item: PermissionRequestResult = {
        permission: config.name,
        status: status
      };
      results.push(item);
    }

    let allGranted = true;
    for (let index = 0; index < results.length; index++) {
      const result = results[index];
      if (this.isPermissionRequired(result.permission as Permissions) && result.status !== PermissionStatus.GRANTED) {
        allGranted = false;
        break;
      }
    }

    return this.buildPermissionSummary(results, allGranted);
  }

  async requestAllRequiredPermissions(): Promise<PermissionSummary> {
    const permissions = this.getRequiredPermissions()
      .filter((config: PermissionConfig) => config.required)
      .map((config: PermissionConfig) => config.name);

    if (permissions.length === 0) {
      const emptySummary: PermissionSummary = {
        allGranted: true,
        results: []
      };
      return emptySummary;
    }

    const results = await this.requestPermissions(permissions);
    let allGranted = true;
    for (let index = 0; index < results.length; index++) {
      if (results[index].status !== PermissionStatus.GRANTED) {
        allGranted = false;
        break;
      }
    }

    return this.buildPermissionSummary(results, allGranted);
  }

  private buildPermissionSummary(results: PermissionRequestResult[], allGrantedOverride?: boolean): PermissionSummary {
    if (allGrantedOverride !== undefined) {
      return {
        allGranted: allGrantedOverride,
        results: results
      };
    }
    let allGranted = true;
    for (let index = 0; index < results.length; index++) {
      if (results[index].status !== PermissionStatus.GRANTED) {
        allGranted = false;
        break;
      }
    }
    return {
      allGranted: allGranted,
      results: results
    };
  }

  async openAppSettings(): Promise<void> {
    const context = AppContextService.getContext();
    if (!context) {
      console.warn('Open app settings failed: missing UI ability context');
      return;
    }
    try {
      await context.startAbility({
        action: 'ohos.settings.application.details',
        parameters: {
          'package': context.abilityInfo.bundleName
        }
      });
    } catch (error) {
      console.warn('Open app settings failed:', JSON.stringify(error));
    }
  }

  getPermissionReason(permission: Permissions): string {
    const config = this.getRequiredPermissions().find((item: PermissionConfig) => item.name === permission);
    if (config) {
      return config.reason;
    }
    return 'Required for app features.';
  }

  isPermissionRequired(permission: Permissions): boolean {
    const config = this.getRequiredPermissions().find((item: PermissionConfig) => item.name === permission);
    if (config) {
      return config.required;
    }
    return false;
  }

  private createDeniedResults(permissions: Permissions[]): PermissionRequestResult[] {
    const deniedResults: PermissionRequestResult[] = [];
    for (let index = 0; index < permissions.length; index++) {
      const item: PermissionRequestResult = {
        permission: permissions[index],
        status: PermissionStatus.DENIED
      };
      deniedResults.push(item);
    }
    return deniedResults;
  }

  static formatPermissionStatus(status: PermissionStatus): string {
    switch (status) {
      case PermissionStatus.GRANTED:
        return 'granted';
      case PermissionStatus.DENIED:
        return 'denied';
      case PermissionStatus.PERMANENTLY_DENIED:
        return 'permanently_denied';
      case PermissionStatus.NOT_REQUESTED:
        return 'not_requested';
      default:
        return 'unknown';
    }
  }
}

export class PermissionDialog {
  static async showRequiredPermissionsDialog(): Promise<boolean> {
    return new Promise((resolve: (value: boolean) => void) => {
      setTimeout(() => {
        resolve(true);
      }, 300);
    });
  }

  static showPermissionDeniedDialog(permission: string, onOpenSettings: () => void): void {
    console.warn(`Permission denied: ${permission}`);
    onOpenSettings();
  }
}
