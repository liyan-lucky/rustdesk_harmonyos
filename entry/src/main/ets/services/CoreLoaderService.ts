import { AppContextService } from './AppContextService';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { FileAuthorizationService } from './FileAuthorizationService';
import fileFs from '@ohos.file.fs';
import http from '@ohos.net.http';
import environment from '@ohos.file.environment';

const CORE_SO_FILENAME = 'librustdesk_core.so';
const CORE_SUBDIR = 'core';

const BUNDLE_LIBS_DIR = '/data/storage/el1/bundle/libs/arm64/';
const BUNDLE_LIBS_PATH = BUNDLE_LIBS_DIR + CORE_SO_FILENAME;

export interface CoreLoadResult {
  success: boolean;
  path: string;
  source: 'bundle' | 'filesdir' | 'download' | 'import' | 'none';
  error?: string;
}

export interface CoreStatus {
  loaded: boolean;
  source: string;
  path: string;
  coreReady: boolean;
}

export class CoreLoaderService {
  private static instance: CoreLoaderService | null = null;
  private coreLoaded: boolean = false;
  private corePath: string = '';
  private coreSource: 'bundle' | 'filesdir' | 'download' | 'import' | 'none' = 'none';

  static getInstance(): CoreLoaderService {
    if (!CoreLoaderService.instance) {
      CoreLoaderService.instance = new CoreLoaderService();
    }
    return CoreLoaderService.instance;
  }

  isCoreLoaded(): boolean {
    if (this.coreLoaded) return true;
    return NativeRustDeskBridge.isCoreLoaded();
  }

  getCorePath(): string {
    return this.corePath;
  }

  getCoreSource(): string {
    return this.coreSource;
  }

  getBundleLibsPath(): string {
    return BUNDLE_LIBS_PATH;
  }

  getCoreDirectory(): string {
    const context = AppContextService.getContext();
    if (!context) return '';
    const contextRecord = context as Object as Record<string, string | undefined>;
    const filesDir = contextRecord.filesDir;
    if (typeof filesDir !== 'string' || filesDir.trim().length === 0) return '';
    return filesDir.trim() + '/' + CORE_SUBDIR;
  }

  getCoreSoPath(): string {
    return this.getCoreDirectory() + '/' + CORE_SO_FILENAME;
  }

  getStatus(): CoreStatus {
    return {
      loaded: this.isCoreLoaded(),
      source: this.coreSource,
      path: this.corePath,
      coreReady: AppStorage.get<boolean>('coreReady') ?? false
    };
  }

  async autoLoadCore(): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      console.info('[CoreLoader] Core already loaded');
      this.coreLoaded = true;
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    const filesDirPath = this.getCoreSoPath();
    console.info(`[CoreLoader] filesDir core path: ${filesDirPath}`);
    if (filesDirPath.length > 0) {
      const filesDirResult = await this.tryLoadFromPath(filesDirPath, 'filesdir');
      if (filesDirResult.success) {
        return filesDirResult;
      }
    }

    const bundleResult = await this.tryLoadFromPath(BUNDLE_LIBS_PATH, 'bundle');
    if (bundleResult.success) {
      return bundleResult;
    }

    const downloadResult = await this.importFromDownloadDir();
    if (downloadResult.success) {
      return downloadResult;
    }

    const tmpImportPath = '/data/local/tmp/' + CORE_SO_FILENAME;
    console.info(`[CoreLoader] Trying import from: ${tmpImportPath}`);
    const importResult = await this.importAndLoad(tmpImportPath);
    if (importResult.success) {
      return importResult;
    }

    return {
      success: false,
      path: '',
      source: 'none',
      error: `No loadable core found (tried filesDir: ${filesDirPath}, bundle: ${BUNDLE_LIBS_PATH})`
    };
  }

  async tryLoadFromPath(path: string, source: 'bundle' | 'filesdir' | 'download' | 'import'): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    try {
      console.info(`[CoreLoader] Trying: ${path}`);
      const verifyJson = NativeRustDeskBridge.verifyCoreFile(path);
      const verifyObj = JSON.parse(verifyJson) as Record<string, Object>;

      if (verifyObj['validElf'] !== true) {
        const err = String(verifyObj['error'] ?? 'invalid ELF');
        console.info(`[CoreLoader] ${path}: ${err}`);
        return { success: false, path: path, source: source, error: err };
      }

      const ok = NativeRustDeskBridge.loadCoreLibrary(path);
      if (ok) {
        this.coreLoaded = true;
        this.corePath = path;
        this.coreSource = source;
        console.info(`[CoreLoader] Core loaded from ${source}: ${path}`);
        return { success: true, path: path, source: source };
      }

      console.warn(`[CoreLoader] dlopen failed for ${path} (HarmonyOS may restrict dlopen to bundle libs)`);

      if (path !== BUNDLE_LIBS_PATH) {
        const copyResult = await this.tryCopyToBundleLibsAndLoad(path, source);
        if (copyResult.success) {
          return copyResult;
        }
      }

      return { success: false, path: path, source: source, error: 'dlopen failed' };
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] tryLoadFromPath failed: ${errMsg}`);
      return { success: false, path: path, source: source, error: errMsg };
    }
  }

  private async tryCopyToBundleLibsAndLoad(srcPath: string, source: 'bundle' | 'filesdir' | 'download' | 'import'): Promise<CoreLoadResult> {
    try {
      console.info(`[CoreLoader] Attempting copy to bundle libs: ${srcPath} -> ${BUNDLE_LIBS_PATH}`);

      const srcFile = fileFs.openSync(srcPath, fileFs.OpenMode.READ_ONLY);
      try {
        const stat = fileFs.statSync(srcPath);
        const size = stat.size;
        if (size === 0) {
          console.warn('[CoreLoader] Source file is empty, skip copy');
          return { success: false, path: '', source: 'none', error: 'source empty' };
        }

        const buffer = new ArrayBuffer(size);
        fileFs.readSync(srcFile.fd, buffer);
        fileFs.closeSync(srcFile);

        try {
          const destFile = fileFs.openSync(BUNDLE_LIBS_PATH, fileFs.OpenMode.CREATE | fileFs.OpenMode.TRUNC | fileFs.OpenMode.READ_WRITE);
          try {
            fileFs.writeSync(destFile.fd, buffer);
            fileFs.closeSync(destFile);
            console.info(`[CoreLoader] Copied to bundle libs: ${BUNDLE_LIBS_PATH} (${size} bytes)`);
          } catch (writeErr) {
            fileFs.closeSync(destFile);
            throw writeErr;
          }
        } catch (copyErr) {
          const errMsg = this.errorToString(copyErr);
          console.error(`[CoreLoader] Write to bundle libs failed: ${errMsg}`);
          return { success: false, path: '', source: 'none', error: `copy to bundle libs failed: ${errMsg}` };
        }

        const ok = NativeRustDeskBridge.loadCoreLibrary(BUNDLE_LIBS_PATH);
        if (ok) {
          this.coreLoaded = true;
          this.corePath = BUNDLE_LIBS_PATH;
          this.coreSource = source;
          console.info(`[CoreLoader] Core loaded from bundle libs after copy: ${BUNDLE_LIBS_PATH}`);
          return { success: true, path: BUNDLE_LIBS_PATH, source: source };
        }

        console.warn('[CoreLoader] dlopen from bundle libs also failed after copy');
        return { success: false, path: BUNDLE_LIBS_PATH, source: source, error: 'dlopen failed after copy to bundle libs' };
      } catch (readErr) {
        fileFs.closeSync(srcFile);
        throw readErr;
      }
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] tryCopyToBundleLibsAndLoad failed: ${errMsg}`);
      return { success: false, path: '', source: 'none', error: errMsg };
    }
  }

  async downloadAndLoad(downloadUrl: string): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    try {
      const coreDir = this.getCoreDirectory();
      if (coreDir.length === 0) {
        return { success: false, path: '', source: 'none', error: 'Cannot determine core directory' };
      }

      const targetPath = coreDir + '/' + CORE_SO_FILENAME;
      this.ensureCoreDirectory(coreDir);

      console.info(`[CoreLoader] Downloading core from: ${downloadUrl}`);
      const httpClient = http.createHttp();
      const response = await httpClient.request(downloadUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });

      if (response.responseCode !== 200) {
        httpClient.destroy();
        return { success: false, path: '', source: 'none', error: `HTTP ${response.responseCode}` };
      }

      const arrayBuffer = response.result as ArrayBuffer;
      if (!arrayBuffer || arrayBuffer.byteLength === 0) {
        httpClient.destroy();
        return { success: false, path: '', source: 'none', error: 'Downloaded content empty' };
      }

      console.info(`[CoreLoader] Downloaded: ${arrayBuffer.byteLength} bytes -> ${targetPath}`);
      this.writeCoreFile(targetPath, arrayBuffer);
      httpClient.destroy();

      const loadResult = await this.tryLoadFromPath(targetPath, 'download');
      if (loadResult.success) {
        return loadResult;
      }

      return {
        success: false,
        path: targetPath,
        source: 'download',
        error: `Core saved to ${targetPath} but dlopen failed. HarmonyOS restricts dlopen to bundle libs. Re-install HAP to use downloaded core.`
      };
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] downloadAndLoad failed: ${errMsg}`);
      return { success: false, path: '', source: 'none', error: errMsg };
    }
  }

  async importAndLoad(localPath: string): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    try {
      const coreDir = this.getCoreDirectory();
      if (coreDir.length === 0) {
        return { success: false, path: '', source: 'none', error: 'Cannot determine core directory' };
      }

      const targetPath = coreDir + '/' + CORE_SO_FILENAME;
      this.ensureCoreDirectory(coreDir);

      console.info(`[CoreLoader] Importing core from: ${localPath} -> ${targetPath}`);
      const file = this.readFileFromPath(localPath);
      if (!file || file.byteLength === 0) {
        return { success: false, path: '', source: 'none', error: 'Local file not found or empty' };
      }

      this.writeCoreFile(targetPath, file);

      const loadResult = await this.tryLoadFromPath(targetPath, 'import');
      if (loadResult.success) {
        return loadResult;
      }

      return {
        success: false,
        path: targetPath,
        source: 'import',
        error: `Core saved to ${targetPath} but dlopen failed. HarmonyOS restricts dlopen to bundle libs. Re-install HAP to use imported core.`
      };
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] importAndLoad failed: ${errMsg}`);
      return { success: false, path: '', source: 'none', error: errMsg };
    }
  }

  async importFromPicker(): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    try {
      const authorization = await FileAuthorizationService.requestFileAuthorization({ maxSelectNumber: 1 });
      if (!authorization.granted || authorization.uris.length === 0) {
        return { success: false, path: '', source: 'none', error: authorization.error || 'No file selected' };
      }

      const selectedUri = authorization.uris[0];
      console.info(`[CoreLoader] Picker selected: ${selectedUri}`);

      const coreDir = this.getCoreDirectory();
      if (coreDir.length === 0) {
        return { success: false, path: '', source: 'none', error: 'Cannot determine core directory' };
      }

      const targetPath = coreDir + '/' + CORE_SO_FILENAME;
      this.ensureCoreDirectory(coreDir);

      const srcFile = fileFs.openSync(selectedUri, fileFs.OpenMode.READ_ONLY);
      try {
        const stat = fileFs.statSync(selectedUri);
        const size = stat.size;
        if (size === 0) {
          return { success: false, path: '', source: 'none', error: 'Selected file is empty' };
        }

        const buffer = new ArrayBuffer(size);
        fileFs.readSync(srcFile.fd, buffer);
        fileFs.closeSync(srcFile);

        this.writeCoreFile(targetPath, buffer);
        console.info(`[CoreLoader] Imported from picker: ${selectedUri} -> ${targetPath} (${size} bytes)`);

        const loadResult = await this.tryLoadFromPath(targetPath, 'import');
        if (loadResult.success) {
          return loadResult;
        }

        return {
          success: false,
          path: targetPath,
          source: 'import',
          error: `Core saved to ${targetPath} but dlopen failed.`
        };
      } catch (readErr) {
        fileFs.closeSync(srcFile);
        throw readErr;
      }
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] importFromPicker failed: ${errMsg}`);
      return { success: false, path: '', source: 'none', error: errMsg };
    }
  }

  async importFromDownloadDir(): Promise<CoreLoadResult> {
    if (this.coreLoaded || NativeRustDeskBridge.isCoreLoaded()) {
      return { success: true, path: this.corePath, source: this.coreSource };
    }

    try {
      const downloadDir = environment.getUserDownloadDir();
      const downloadPath = downloadDir + '/' + CORE_SO_FILENAME;
      console.info(`[CoreLoader] Trying Download dir: ${downloadPath}`);

      const access = fileFs.accessSync(downloadPath);
      if (!access) {
        return { success: false, path: downloadPath, source: 'none', error: `Core not found in Download: ${downloadPath}` };
      }

      return await this.importAndLoad(downloadPath);
    } catch (error) {
      const errMsg = this.errorToString(error);
      console.error(`[CoreLoader] importFromDownloadDir failed: ${errMsg}`);
      return { success: false, path: '', source: 'none', error: errMsg };
    }
  }

  private ensureCoreDirectory(coreDir: string): void {
    try {
      fileFs.mkdirSync(coreDir);
    } catch (e) {
    }
  }

  private writeCoreFile(targetPath: string, content: ArrayBuffer): void {
    const file = fileFs.openSync(targetPath, fileFs.OpenMode.CREATE | fileFs.OpenMode.TRUNC | fileFs.OpenMode.READ_WRITE);
    try {
      fileFs.writeSync(file.fd, content);
    } finally {
      fileFs.closeSync(file);
    }
  }

  private readFileFromPath(localPath: string): ArrayBuffer | null {
    try {
      const stat = fileFs.statSync(localPath);
      const size = stat.size;
      if (size === 0) return null;

      const file = fileFs.openSync(localPath, fileFs.OpenMode.READ_ONLY);
      try {
        const buffer = new ArrayBuffer(size);
        fileFs.readSync(file.fd, buffer);
        return buffer;
      } finally {
        fileFs.closeSync(file);
      }
    } catch (error) {
      console.error(`[CoreLoader] readFileFromPath failed: ${this.errorToString(error)}`);
      return null;
    }
  }

  private errorToString(error: Object | string | undefined): string {
    if (error === undefined || error === null) return 'unknown';
    if (typeof error === 'string') return error;
    if (error instanceof Error) return error.message;
    try {
      return JSON.stringify(error);
    } catch (e) {
      return String(error);
    }
  }
}
