import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import picker from '@ohos.file.picker';
import { AppContextService } from './AppContextService';

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
        name: 'ohos.permission.CUSTOM_SCREEN_CAPTURE',
        reason: 'Required for screen capture and sharing.',
        required: false
      },
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

  async requestFileAccessAuthorization(): Promise<boolean> {
    const results = await this.requestPermissions([
      'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY' as Permissions,
      'ohos.permission.FILE_ACCESS_PERSIST' as Permissions
    ]);
    const allGranted = results.every((item: PermissionRequestResult) => item.status === PermissionStatus.GRANTED);
    if (!allGranted) {
      return false;
    }

    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentPicker = new picker.DocumentViewPicker();
      const selectedUris: Array<string> = await documentPicker.select(documentSelectOptions);
      return selectedUris !== undefined && selectedUris.length > 0;
    } catch (error) {
      console.error('Request file access authorization failed:', error);
      return false;
    }
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

    const summary: PermissionSummary = {
      allGranted: allGranted,
      results: results
    };
    return summary;
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

    const summary: PermissionSummary = {
      allGranted: allGranted,
      results: results
    };
    return summary;
  }

  async openAppSettings(): Promise<void> {
    console.log('Opening app settings is not implemented yet.');
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
