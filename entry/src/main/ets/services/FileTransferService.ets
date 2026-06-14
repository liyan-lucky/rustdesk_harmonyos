import { OfficialSessionTransport } from './OfficialSessionTransport';
import { OfficialRustDeskBridge, OfficialSessionEvent } from './OfficialRustDeskBridge';
import fileFs from '@ohos.file.fs';

export interface FileInfo {
  path: string;
  name: string;
  size: number;
  isDirectory: boolean;
  modifiedTime: number;
}

export enum FileTransferStatus {
  IDLE = 'idle',
  TRANSFERRING = 'transferring',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled'
}

export interface FileTransferTask {
  id: string;
  fileInfo: FileInfo;
  direction: 'upload' | 'download';
  status: FileTransferStatus;
  progress: number;
  transferredBytes: number;
  totalBytes: number;
  speed: number;
  officialJobId?: number;
  targetPath?: string;
  error?: string;
}

export interface FileTransferEvent {
  type: 'task_started' | 'task_progress' | 'task_completed' | 'task_failed' | 'task_cancelled' | 'error' | 'remote_fs_changed';
  task?: FileTransferTask;
  error?: string;
}

interface FileTransferStartPayload {
  id?: number;
  path?: string;
  to?: string;
  is_remote?: boolean;
}

interface FileTransferProgressPayload {
  id?: number;
  speed?: number;
  finished_size?: number;
}

interface FileTransferDonePayload {
  id?: number;
}

interface FileTransferErrorPayload {
  id?: number;
  error?: string;
  direction?: string;
  file_name?: string;
}

interface RemoteDirectoryEntryPayload {
  name?: string;
  size?: number;
  modified_time?: number;
  entry_type?: number;
}

interface RemoteDirectoryPayload {
  path?: string;
  entries?: RemoteDirectoryEntryPayload[];
}

export class FileTransferService {
  private static instance: FileTransferService;
  private officialBridge: OfficialRustDeskBridge = OfficialRustDeskBridge.getInstance();
  private transferTasks: Map<string, FileTransferTask> = new Map();
  private eventListeners: Array<(event: FileTransferEvent) => void> = [];
  private activeTransfers: Set<string> = new Set();
  private maxConcurrentTransfers: number = 3;
  private readonly rootLocalPath: string = '/storage/Users/currentUser/Download';
  private readonly rootRemotePath: string = '/remote';
  private remoteFiles: FileInfo[] = [];

  private constructor() {
    this.seedRemoteFiles();
    this.officialBridge.addEventListener((event: OfficialSessionEvent) => {
      this.handleOfficialEvent(event);
    });
  }

  static getInstance(): FileTransferService {
    if (!FileTransferService.instance) {
      FileTransferService.instance = new FileTransferService();
    }
    return FileTransferService.instance;
  }

  async listDirectory(path: string): Promise<FileInfo[]> {
    return Promise.resolve(this.readLocalDirectory(path));
  }

  async listRemoteDirectory(path: string): Promise<FileInfo[]> {
    if (!OfficialSessionTransport.readRemoteDirectory(path, false)) {
      this.dispatchEvent({ type: 'error', error: 'official remote directory entry unavailable' });
      return Promise.resolve([]);
    }
    return Promise.resolve(this.listVirtualDirectory(this.remoteFiles, path));
  }

  async createDirectory(path: string): Promise<void> {
    const normalized = this.normalizePath(path);
    const name = this.getBaseName(normalized);
    if (name.length === 0) {
      return;
    }
    try {
      fileFs.mkdirSync(normalized, true);
    } catch (error) {
      this.dispatchEvent({ type: 'error', error: `local mkdir failed: ${this.errorToMessage(error)}` });
    }
  }

  async createRemoteDirectory(path: string): Promise<void> {
    const normalized = this.normalizePath(path);
    const name = this.getBaseName(normalized);
    if (name.length === 0) {
      return;
    }
    if (OfficialSessionTransport.createRemoteDirectory(normalized)) {
      return;
    }
    this.dispatchEvent({ type: 'error', error: 'official remote mkdir entry unavailable' });
  }

  async deleteFile(path: string): Promise<void> {
    const normalized = this.normalizePath(path);
    try {
      const stat = fileFs.statSync(normalized);
      if (stat.isDirectory()) {
        fileFs.rmdirSync(normalized);
      } else {
        fileFs.unlinkSync(normalized);
      }
    } catch (error) {
      this.dispatchEvent({ type: 'error', error: `local delete failed: ${this.errorToMessage(error)}` });
    }
  }

  async deleteRemoteFile(path: string): Promise<void> {
    const normalized = this.normalizePath(path);
    const existing = this.remoteFiles.find((item: FileInfo) => item.path === normalized);
    if (OfficialSessionTransport.deleteRemotePath(normalized, existing?.isDirectory === true)) {
      return;
    }
    this.dispatchEvent({ type: 'error', error: 'official remote delete entry unavailable' });
  }

  createTransferTask(fileInfo: FileInfo, direction: 'upload' | 'download'): FileTransferTask {
    const task: FileTransferTask = {
      id: this.generateTaskId(),
      fileInfo,
      direction,
      status: FileTransferStatus.IDLE,
      progress: 0,
      transferredBytes: 0,
      totalBytes: fileInfo.size > 0 ? fileInfo.size : 1024 * 1024,
      speed: 0
    };
    this.transferTasks.set(task.id, task);
    return task;
  }

  async startTransfer(taskId: string, targetPath?: string): Promise<void> {
    const task = this.transferTasks.get(taskId);
    if (!task) {
      this.dispatchEvent({ type: 'error', error: 'task not found' });
      return;
    }
    if (this.activeTransfers.size >= this.maxConcurrentTransfers) {
      task.status = FileTransferStatus.FAILED;
      task.error = 'maximum concurrent transfers reached';
      this.dispatchEvent({ type: 'task_failed', task, error: task.error });
      return;
    }

    task.status = FileTransferStatus.TRANSFERRING;
    task.error = undefined;
    this.activeTransfers.add(taskId);
    if (task.direction === 'upload' && !this.localPathExists(task.fileInfo.path)) {
      task.status = FileTransferStatus.FAILED;
      task.error = 'local source path unavailable';
      this.activeTransfers.delete(task.id);
      this.dispatchEvent({ type: 'task_failed', task, error: task.error });
      return;
    }
    const resolvedTargetPath = this.normalizePath(targetPath ?? (task.direction === 'upload'
      ? this.rootRemotePath
      : this.rootLocalPath));
    task.targetPath = resolvedTargetPath;
    const officialStarted = OfficialSessionTransport.startFileTransfer(
      task.fileInfo.path,
      resolvedTargetPath,
      task.direction === 'download'
    );
    this.dispatchEvent({ type: 'task_started', task });

    if (officialStarted) {
      return;
    }
    task.status = FileTransferStatus.FAILED;
    task.error = 'official file transfer entry unavailable';
    this.activeTransfers.delete(task.id);
    this.dispatchEvent({ type: 'task_failed', task, error: task.error });
  }

  pauseTransfer(taskId: string): void {
    const task = this.transferTasks.get(taskId);
    if (!task || task.status !== FileTransferStatus.TRANSFERRING) {
      return;
    }
    task.status = FileTransferStatus.PAUSED;
    this.activeTransfers.delete(taskId);
  }

  cancelTransfer(taskId: string): void {
    const task = this.transferTasks.get(taskId);
    if (!task) {
      return;
    }
    task.status = FileTransferStatus.CANCELLED;
    this.activeTransfers.delete(taskId);
    this.dispatchEvent({ type: 'task_cancelled', task });
  }

  getTransferTask(taskId: string): FileTransferTask | undefined {
    return this.transferTasks.get(taskId);
  }

  getAllTransferTasks(): FileTransferTask[] {
    return Array.from(this.transferTasks.values()).sort((a: FileTransferTask, b: FileTransferTask) => b.fileInfo.modifiedTime - a.fileInfo.modifiedTime);
  }

  getActiveTransferTasks(): FileTransferTask[] {
    const result: FileTransferTask[] = [];
    this.activeTransfers.forEach((taskId: string) => {
      const task = this.transferTasks.get(taskId);
      if (task) {
        result.push(task);
      }
    });
    return result;
  }

  setMaxConcurrentTransfers(max: number): void {
    this.maxConcurrentTransfers = Math.max(1, max);
  }

  getMaxConcurrentTransfers(): number {
    return this.maxConcurrentTransfers;
  }

  static formatFileSize(bytes: number): string {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return `${size.toFixed(unitIndex === 0 ? 0 : 2)} ${units[unitIndex]}`;
  }

  static formatTransferSpeed(bytesPerSecond: number): string {
    return FileTransferService.formatFileSize(bytesPerSecond) + '/s';
  }

  addEventListener(listener: (event: FileTransferEvent) => void): void {
    this.eventListeners.push(listener);
  }

  removeEventListener(listener: (event: FileTransferEvent) => void): void {
    const index = this.eventListeners.indexOf(listener);
    if (index > -1) {
      this.eventListeners.splice(index, 1);
    }
  }

  private readLocalDirectory(path: string): FileInfo[] {
    const normalized = this.normalizePath(path);
    try {
      const names = fileFs.listFileSync(normalized);
      const result: FileInfo[] = [];
      names.forEach((name: string) => {
        const entryName = this.getBaseName(name);
        if (entryName.length === 0) {
          return;
        }
        const entryPath = name.startsWith('/') ? this.normalizePath(name) : this.normalizePath(`${normalized}/${name}`);
        try {
          const stat = fileFs.statSync(entryPath);
          const isDirectory = stat.isDirectory();
          result.push({
            path: entryPath,
            name: entryName,
            size: isDirectory ? 0 : stat.size,
            isDirectory,
            modifiedTime: stat.mtime > 0 ? stat.mtime : Date.now()
          });
        } catch (_error) {
          return;
        }
      });
      return result;
    } catch (error) {
      this.dispatchEvent({ type: 'error', error: `local directory unavailable: ${this.errorToMessage(error)}` });
      return [];
    }
  }

  private localPathExists(path: string): boolean {
    try {
      fileFs.statSync(this.normalizePath(path));
      return true;
    } catch (_error) {
      return false;
    }
  }

  private listVirtualDirectory(source: FileInfo[], path: string): FileInfo[] {
    const normalized = this.normalizePath(path);
    const prefix = normalized.endsWith('/') ? normalized : `${normalized}/`;
    return source.filter((item: FileInfo) => {
      if (item.path === normalized) {
        return false;
      }
      if (!item.path.startsWith(prefix)) {
        return false;
      }
      const remainder = item.path.substring(prefix.length);
      return remainder.length > 0 && remainder.indexOf('/') === -1;
    }).sort((a: FileInfo, b: FileInfo) => {
      if (a.isDirectory !== b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
  }

  private removeVirtualItem(source: FileInfo[], path: string): FileInfo[] {
    const normalized = this.normalizePath(path);
    const prefix = `${normalized}/`;
    return source.filter((item: FileInfo) => item.path !== normalized && !item.path.startsWith(prefix));
  }

  private upsertVirtualFile(source: FileInfo[], file: FileInfo): void {
    const index = source.findIndex((item: FileInfo) => item.path === file.path);
    if (index >= 0) {
      source.splice(index, 1, file);
    } else {
      source.push(file);
    }
  }

  private normalizePath(path: string): string {
    const trimmed = path.trim();
    if (trimmed.length === 0) {
      return '/';
    }
    return trimmed.endsWith('/') && trimmed.length > 1 ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  private getBaseName(path: string): string {
    const normalized = this.normalizePath(path);
    const segments = normalized.split('/');
    return segments[segments.length - 1] || '';
  }

  private seedRemoteFiles(): void {
    const now = Date.now();
    this.remoteFiles = [
      { path: this.rootRemotePath, name: '远程', size: 0, isDirectory: true, modifiedTime: now }
    ];
  }

  private generateTaskId(): string {
    return `task_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
  }

  private dispatchEvent(event: FileTransferEvent): void {
    this.eventListeners.forEach((listener: (event: FileTransferEvent) => void) => {
      try {
        listener(event);
      } catch (_error) {
        console.error('Event listener error');
      }
    });
  }

  private handleOfficialEvent(event: OfficialSessionEvent): void {
    if (event.kind === 'folder-files') {
      this.applyRemoteDirectoryEvent(event.detail);
      return;
    }
    if (event.kind === 'file-transfer-start') {
      this.applyTransferStartEvent(event.detail);
      return;
    }
    if (event.kind === 'job-progress') {
      this.applyTransferProgressEvent(event.detail);
      return;
    }
    if (event.kind === 'job-done') {
      this.applyTransferDoneEvent(event.detail);
      return;
    }
    if (event.kind === 'job-error' || event.kind === 'file-transfer-unsupported') {
      this.applyTransferErrorEvent(event.detail);
      return;
    }
    if (event.kind === 'create-remote-dir' || event.kind === 'delete-remote-path') {
      this.dispatchEvent({ type: 'remote_fs_changed' });
    }
  }

  private applyTransferStartEvent(detail: string): void {
    try {
      const payload = JSON.parse(detail) as FileTransferStartPayload;
      if (typeof payload.id !== 'number') {
        return;
      }
      const task = this.findTaskForOfficialTransfer(payload.path ?? '', payload.to ?? '', payload.is_remote === true);
      if (!task) {
        return;
      }
      task.officialJobId = payload.id;
      task.targetPath = this.normalizePath(payload.to ?? task.targetPath ?? this.rootRemotePath);
      task.status = FileTransferStatus.TRANSFERRING;
      this.dispatchEvent({ type: 'task_progress', task });
    } catch (error) {
      console.error('applyTransferStartEvent failed', JSON.stringify(error));
    }
  }

  private applyTransferProgressEvent(detail: string): void {
    try {
      const payload = JSON.parse(detail) as FileTransferProgressPayload;
      const task = this.findTaskByOfficialJobId(payload.id);
      if (!task) {
        return;
      }
      const total = task.totalBytes > 0 ? task.totalBytes : 1;
      const transferred = typeof payload.finished_size === 'number'
        ? Math.max(0, Math.floor(payload.finished_size))
        : task.transferredBytes;
      task.status = FileTransferStatus.TRANSFERRING;
      task.transferredBytes = transferred;
      task.progress = Math.max(0, Math.min(100, Math.floor(transferred * 100 / total)));
      task.speed = typeof payload.speed === 'number' ? Math.max(0, Math.floor(payload.speed)) : task.speed;
      this.dispatchEvent({ type: 'task_progress', task });
    } catch (error) {
      console.error('applyTransferProgressEvent failed', JSON.stringify(error));
    }
  }

  private applyTransferDoneEvent(detail: string): void {
    try {
      const payload = JSON.parse(detail) as FileTransferDonePayload;
      const task = this.findTaskByOfficialJobId(payload.id);
      if (!task) {
        return;
      }
      task.status = FileTransferStatus.COMPLETED;
      task.progress = 100;
      task.transferredBytes = task.totalBytes;
      task.speed = 0;
      this.activeTransfers.delete(task.id);
      if (task.direction === 'upload') {
        OfficialSessionTransport.readRemoteDirectory(task.targetPath ?? this.rootRemotePath, false);
        this.dispatchEvent({ type: 'remote_fs_changed' });
      }
      this.dispatchEvent({ type: 'task_completed', task });
    } catch (error) {
      console.error('applyTransferDoneEvent failed', JSON.stringify(error));
    }
  }

  private applyTransferErrorEvent(detail: string): void {
    try {
      const payload = JSON.parse(detail) as FileTransferErrorPayload;
      const task = this.findTaskByOfficialJobId(payload.id)
        ?? this.findPendingTaskByName(payload.file_name ?? '', payload.direction === 'download');
      if (!task) {
        return;
      }
      task.status = FileTransferStatus.FAILED;
      task.error = payload.error?.trim() || 'official file transfer failed';
      task.speed = 0;
      this.activeTransfers.delete(task.id);
      this.dispatchEvent({ type: 'task_failed', task, error: task.error });
    } catch (error) {
      console.error('applyTransferErrorEvent failed', JSON.stringify(error));
    }
  }

  private findTaskForOfficialTransfer(path: string, targetPath: string, isRemote: boolean): FileTransferTask | undefined {
    const normalizedPath = this.normalizePath(path);
    const normalizedTargetPath = this.normalizePath(targetPath);
    const expectedDirection = isRemote ? 'download' : 'upload';
    const candidates = Array.from(this.transferTasks.values()).filter((task: FileTransferTask) => {
      return task.status === FileTransferStatus.TRANSFERRING
        && typeof task.officialJobId !== 'number'
        && task.direction === expectedDirection
        && this.normalizePath(task.fileInfo.path) === normalizedPath
        && this.normalizePath(task.targetPath ?? '') === normalizedTargetPath;
    });
    return candidates.sort((a: FileTransferTask, b: FileTransferTask) => b.fileInfo.modifiedTime - a.fileInfo.modifiedTime)[0];
  }

  private findTaskByOfficialJobId(jobId?: number): FileTransferTask | undefined {
    if (typeof jobId !== 'number') {
      return undefined;
    }
    return Array.from(this.transferTasks.values()).find((task: FileTransferTask) => task.officialJobId === jobId);
  }

  private findPendingTaskByName(name: string, isDownload: boolean): FileTransferTask | undefined {
    const normalizedName = name.trim();
    if (normalizedName.length === 0) {
      return undefined;
    }
    return Array.from(this.transferTasks.values()).find((task: FileTransferTask) => {
      return task.status === FileTransferStatus.TRANSFERRING
        && typeof task.officialJobId !== 'number'
        && task.direction === (isDownload ? 'download' : 'upload')
        && task.fileInfo.name === normalizedName;
    });
  }

  private applyRemoteDirectoryEvent(detail: string): void {
    try {
      const payload = JSON.parse(detail) as RemoteDirectoryPayload;
      const path = this.normalizePath(payload.path ?? this.rootRemotePath);
      const entries = Array.isArray(payload.entries) ? payload.entries : [];
      const nextChildren: FileInfo[] = entries.map((entry: RemoteDirectoryEntryPayload): FileInfo => {
        const name = entry.name?.trim() ?? '';
        const entryType = typeof entry.entry_type === 'number' ? entry.entry_type : 4;
        const isDirectory = entryType !== 4 && entryType !== 5;
        const fullPath = path === '/' ? `/${name}` : `${path}/${name}`;
        return {
          path: fullPath,
          name,
          size: typeof entry.size === 'number' ? entry.size : 0,
          isDirectory,
          modifiedTime: typeof entry.modified_time === 'number' ? entry.modified_time : Date.now()
        };
      }).filter((entry: FileInfo) => entry.name.length > 0);

      this.remoteFiles = this.remoteFiles.filter((item: FileInfo) => {
        const prefix = path.endsWith('/') ? path : `${path}/`;
        if (!item.path.startsWith(prefix)) {
          return true;
        }
        const remainder = item.path.substring(prefix.length);
        return remainder.includes('/');
      });
      nextChildren.forEach((entry: FileInfo) => {
        this.upsertVirtualFile(this.remoteFiles, entry);
      });
      this.dispatchEvent({ type: 'remote_fs_changed' });
    } catch (error) {
      console.error('applyRemoteDirectoryEvent failed', JSON.stringify(error));
    }
  }

  private errorToMessage(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    const record = error as Record<string, Object | undefined>;
    const message = record['message'];
    if (typeof message === 'string' && message.trim().length > 0) {
      return message;
    }
    return JSON.stringify(error);
  }
}
