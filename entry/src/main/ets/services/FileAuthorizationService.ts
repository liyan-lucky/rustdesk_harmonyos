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
    let selectedUris: Array<string> = [];
    let pickerError: string = '';

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
      selectedUris = await documentPicker.select(documentSelectOptions);
    } catch (error) {
      console.error('Request file access authorization failed:', error);
      pickerError = error instanceof Error ? error.message : String(error);
    }

    const permissions: Permissions[] = [
      'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY' as Permissions,
      'ohos.permission.FILE_ACCESS_PERSIST' as Permissions
    ];
    const permissionResults = await FileAuthorizationService.requestPermissions(permissions);
    const pickerGranted = selectedUris !== undefined && selectedUris.length > 0;

    return {
      granted: pickerGranted,
      uris: selectedUris ?? [],
      permissionResults,
      error: pickerGranted ? '' : (pickerError.length > 0 ? pickerError : 'File authorization cancelled or denied')
    };
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
