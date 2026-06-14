import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import picker from '@ohos.file.picker';
import { AppContextService } from './AppContextService';

export interface FileAuthorizationOptions {
  folder?: boolean;
  authMode?: boolean;
  defaultFilePathUri?: string;
  maxSelectNumber?: number;
}

export interface FileAuthorizationPermissionResult {
  permission: string;
  status: string;
}

export interface FileAuthorizationResult {
  granted: boolean;
  uris: string[];
  permissionResults: FileAuthorizationPermissionResult[];
  error: string;
}

export class FileAuthorizationService {
  private static atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

  static async requestFileAuthorization(options?: FileAuthorizationOptions): Promise<FileAuthorizationResult> {
    const permissions: Permissions[] = [
      'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY' as Permissions,
      'ohos.permission.FILE_ACCESS_PERSIST' as Permissions
    ];
    const permissionResults = await FileAuthorizationService.requestPermissions(permissions);
    const allGranted = permissionResults.every((item: FileAuthorizationPermissionResult) => item.status === 'granted');
    if (!allGranted) {
      return {
        granted: false,
        uris: [],
        permissionResults,
        error: 'File permissions denied'
      };
    }

    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = options?.folder ? 1 : (options?.maxSelectNumber ?? 1);
      documentSelectOptions.selectMode = options?.folder ? picker.DocumentSelectMode.FOLDER : picker.DocumentSelectMode.FILE;
      if (options?.authMode !== undefined) {
        documentSelectOptions.authMode = options.authMode;
      }
      if (options?.defaultFilePathUri !== undefined && options.defaultFilePathUri.trim().length > 0) {
        documentSelectOptions.defaultFilePathUri = options.defaultFilePathUri.trim();
      }
      const documentPicker = new picker.DocumentViewPicker();
      const selectedUris: Array<string> = await documentPicker.select(documentSelectOptions);
      return {
        granted: selectedUris !== undefined && selectedUris.length > 0,
        uris: selectedUris ?? [],
        permissionResults,
        error: ''
      };
    } catch (error) {
      console.error('Request file access authorization failed:', error);
      return {
        granted: false,
        uris: [],
        permissionResults,
        error: error instanceof Error ? error.message : String(error)
      };
    }
  }

  private static async requestPermissions(permissions: Permissions[]): Promise<FileAuthorizationPermissionResult[]> {
    const context = AppContextService.getContext();
    if (!context) {
      return FileAuthorizationService.createDeniedResults(permissions);
    }

    try {
      const results = await FileAuthorizationService.atManager.requestPermissionsFromUser(context, permissions);
      const mappedResults: FileAuthorizationPermissionResult[] = [];
      for (let index = 0; index < permissions.length; index++) {
        const granted = index < results.authResults.length && results.authResults[index] === 0;
        mappedResults.push({
          permission: permissions[index],
          status: granted ? 'granted' : 'denied'
        });
      }
      return mappedResults;
    } catch (error) {
      console.error('Request file permissions failed:', error);
      return FileAuthorizationService.createDeniedResults(permissions);
    }
  }

  private static createDeniedResults(permissions: Permissions[]): FileAuthorizationPermissionResult[] {
    const deniedResults: FileAuthorizationPermissionResult[] = [];
    for (let index = 0; index < permissions.length; index++) {
      deniedResults.push({
        permission: permissions[index],
        status: 'denied'
      });
    }
    return deniedResults;
  }
}
