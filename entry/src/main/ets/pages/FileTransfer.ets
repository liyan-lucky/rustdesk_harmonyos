import { AppDataService, TransferTask } from '../services/AppDataService';
import { createStrokeIconColorFilter } from '../common/CommonComponents';
import { EmptyState, PageHeader, SectionTitle, StatusBadge } from '../common/CommonComponents';
import { ThemeConfig } from '../common/ThemeConfig';
import { FileInfo, FileTransferEvent, FileTransferService } from '../services/FileTransferService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

type FilePane = 'local' | 'remote';
type SortMode = 'name' | 'time';

interface FileEntry {
  name: string;
  type: 'folder' | 'file';
  size: string;
  modified: string;
  modifiedTime: number;
  path: string;
}

@Entry
@Component
struct FileTransfer {
  private appData: AppDataService = AppDataService.getInstance();
  private fileTransferService: FileTransferService = FileTransferService.getInstance();
  private transferListener = (event: FileTransferEvent): void => {
    if (event.task || event.type === 'remote_fs_changed') {
      this.refreshTransferTasks();
      void this.loadCurrentPaneFiles();
    }
  };

  @State deviceId: string = '';
  @State deviceName: string = '';
  @State currentPane: FilePane = 'remote';
  @State sortMode: SortMode = 'name';
  @State tasks: TransferTask[] = [];
  @State localPath: string = '/storage/Users/currentUser/Download';
  @State remotePath: string = '/remote';
  @State localFiles: FileEntry[] = [];
  @State remoteFiles: FileEntry[] = [];
  @State newFolderName: string = '';
  @State isFileListRefreshing: boolean = false;
  @State fileListRefreshAngle: number = 0;
  private fileListRefreshTimer: number = -1;
  aboutToAppear() {
    const params = this.getRouteParams();
    if (params && params['deviceId']) {
      this.deviceId = params['deviceId'];
    }
    this.deviceName = this.appData.getDisplayName(this.deviceId);
    this.fileTransferService.addEventListener(this.transferListener);
    this.refreshTransferTasks();
    void this.loadCurrentPaneFiles();
  }

  aboutToDisappear() {
    this.fileTransferService.removeEventListener(this.transferListener);
  }
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_INACTIVE_BG') theme_INACTIVE_BG: string = '#3A4355';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('themeIsDark') themeIsDark: boolean = false;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: ThemeConfig.SPACING_LG }) {
          this.buildPaneSwitch()
          this.buildPathCard()
          this.buildToolbar()
          this.buildCreateFolderCard()
          this.buildFileList()
          this.buildTransferQueue()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: 56, bottom: this.avoidNavigationBarHeight + ThemeConfig.SPACING_MD })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Column() {
        PageHeader(this.lt('File Transfer'), `${this.deviceName} · ${DeviceIdFormatter.format(this.deviceId)}`, true, () => {
          this.goBack();
        })
      }
      .padding({ top: this.avoidStatusBarHeight })
      .backgroundColor(this.themeIsDark ? '#802D3139' : '#80F8FAFC')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildPaneSwitch() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.buildModeButton(this.lt('Local'), this.currentPane === 'local', () => {
          this.currentPane = 'local';
          void this.loadCurrentPaneFiles();
        })
        this.buildModeButton(this.lt('Remote'), this.currentPane === 'remote', () => {
          this.currentPane = 'remote';
          void this.loadCurrentPaneFiles();
        })
      }

      Row({ space: 8 }) {
        this.buildModeButton(this.lt('By Name'), this.sortMode === 'name', () => {
          this.sortMode = 'name';
          void this.loadCurrentPaneFiles();
        })
        this.buildModeButton(this.lt('By Time'), this.sortMode === 'time', () => {
          this.sortMode = 'time';
          void this.loadCurrentPaneFiles();
        })
      }
    }
    .width('100%')
  }

  @Builder
  private buildPathCard() {
    Column({ space: 8 }) {
      SectionTitle(this.currentPane === 'local' ? this.lt('Local Path') : this.lt('Remote Path'))
      Text(this.getCurrentPath())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme_TEXT_PRIMARY)
        .width('100%')

      if (this.canGoUp()) {
        Button(this.lt('Parent Directory'))
          .height(36)
          .fontSize(12)
          .backgroundColor(this.theme_INPUT_BG)
          .fontColor(this.theme_TEXT_PRIMARY)
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
          .onClick(() => {
            void this.goParentDirectory();
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(18)
  }

  @Builder
  private buildToolbar() {
    Row({ space: 8 }) {
      this.buildToolButton($rawfile('file_transfer.svg'), this.lt('Upload'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
        void this.startFirstLocalUpload();
      })
      this.buildToolButton($rawfile('transfer.svg'), this.lt('Download'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
        void this.startFirstRemoteDownload();
      })
      Button() {
        Row({ space: 4 }) {
          Image($rawfile('refresh.svg'))
            .width(14)
            .height(14)
            .colorFilter(createStrokeIconColorFilter(this.theme_CONTRAST_TEXT))
            .rotate({ x: 0, y: 0, z: 1, angle: this.fileListRefreshAngle })
          Text(this.lt('Refresh'))
            .fontSize(12)
            .fontColor(this.theme_CONTRAST_TEXT)
        }
      }
      .layoutWeight(1)
      .height(40)
      .backgroundColor(this.theme_INPUT_BG)
      .borderRadius(12)
      .onClick(() => {
        if (this.isFileListRefreshing) {
          return;
        }
        void this.refreshCurrentPaneFiles();
      })
    }
    .width('100%')
  }

  @Builder
  private buildCreateFolderCard() {
    Row({ space: 8 }) {
      TextInput({ placeholder: this.lt('New folder name'), text: this.newFolderName })
        .layoutWeight(1)
        .height(42)
        .backgroundColor(this.theme_CARD_BG)
        .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.newFolderName = value;
        })

      Button(this.lt('Create'))
        .width(74)
        .height(42)
        .fontSize(12)
        .backgroundColor(this.theme_INPUT_BG)
        .fontColor(this.theme_CONTRAST_TEXT)
        .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
        .onClick(() => {
          void this.createFolder();
        })
    }
    .width('100%')
  }

  @Builder
  private buildFileList() {
    Column({ space: 12 }) {
      SectionTitle(this.currentPane === 'local' ? this.lt('Local Files') : this.lt('Remote Files'))

      if (this.getCurrentEntries().length === 0) {
        EmptyState($rawfile('folder.svg'), this.lt('Current dir empty'))
      } else {
        Column({ space: 10 }) {
          ForEach(this.getCurrentEntries(), (entry: FileEntry) => {
            this.buildFileCard(entry)
          }, (entry: FileEntry) => entry.path)
        }
      }
    }
  }

  @Builder
  private buildFileCard(entry: FileEntry) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(entry.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme_TEXT_PRIMARY)

          Text(`${entry.type === 'folder' ? this.lt('Folder') : this.lt('File')} · ${entry.size} · ${entry.modified}`)
            .fontSize(12)
            .fontColor(this.theme_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        StatusBadge(entry.type === 'folder' ? this.lt('Folder') : this.lt('File'), entry.type === 'folder')
      }

      Row({ space: 8 }) {
        if (entry.type === 'folder') {
          this.buildInlineAction(this.lt('Open'), this.theme_TEXT_PRIMARY, this.theme_CONTRAST_TEXT, () => {
            void this.openFolder(entry);
          })
        } else if (this.currentPane === 'local') {
          this.buildInlineAction(this.lt('Upload'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
            void this.queueTransfer(entry, 'upload');
          })
        } else {
          this.buildInlineAction(this.lt('Download'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
            void this.queueTransfer(entry, 'download');
          })
        }

        this.buildInlineAction(this.lt('Delete Action'), this.theme_TEXT_TERTIARY, this.theme_CONTRAST_TEXT, () => {
          void this.deleteEntry(entry);
        })
      }
    }
    .padding(14)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(16)
  }

  @Builder
  private buildTransferQueue() {
    Column({ space: 12 }) {
      SectionTitle(this.lt('Transfer Queue'))

      if (this.tasks.length === 0) {
        EmptyState($rawfile('transfer.svg'), this.lt('No transfer tasks'))
      } else {
        Column({ space: 10 }) {
          ForEach(this.tasks, (task: TransferTask) => {
            Column({ space: 8 }) {
              Row() {
                Column({ space: 4 }) {
                  Text(task.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme_TEXT_PRIMARY)
                  Text(`${task.direction === 'upload' ? this.lt('Upload') : this.lt('Download')} · ${task.size}`)
                    .fontSize(12)
                    .fontColor(this.theme_TEXT_SECONDARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                StatusBadge(this.formatTaskStatus(task.status), task.status === 'done')
              }

              Progress({ value: task.progress, total: 100, type: ProgressType.Linear })
                .height(8)
                .color(this.theme_ACCENT)
                .backgroundColor(this.theme_INACTIVE_BG)

              Row({ space: 8 }) {
                Text(`${task.progress}%`)
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_TERTIARY)
                  .layoutWeight(1)

                if (task.status === 'running') {
                  this.buildTaskAction(this.lt('Pause'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
                    this.pauseTask(task.id);
                  })
                  this.buildTaskAction(this.lt('Cancel'), this.theme_ERROR_TEXT, this.theme_CONTRAST_TEXT, () => {
                    this.cancelTask(task.id);
                  })
                }
                if (task.status === 'queued') {
                  this.buildTaskAction(this.lt('Start'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
                    void this.startTask(task.id);
                  })
                  this.buildTaskAction(this.lt('Cancel'), this.theme_ERROR_TEXT, this.theme_CONTRAST_TEXT, () => {
                    this.cancelTask(task.id);
                  })
                }
              }
            }
            .padding(16)
            .backgroundColor(this.theme_CARD_BG)
            .borderRadius(18)
          }, (task: TransferTask) => task.id)
        }
      }
    }
  }

  @Builder
  private buildTaskAction(label: string, color: string, fontColor: string, action: () => void) {
    Button(label)
      .height(28)
      .fontSize(11)
      .backgroundColor(color)
      .fontColor(fontColor)
      .borderRadius(10)
      .onClick(action)
  }

  @Builder
  private buildModeButton(label: string, active: boolean, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(40)
      .fontSize(13)
      .backgroundColor(active ? this.theme_ACCENT : this.theme_INPUT_BG)
      .fontColor(active ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
      .borderRadius(12)
      .onClick(action)
  }

  @Builder
  private buildToolButton(icon: Resource, label: string, color: string, fontColor: string, action: () => void) {
    Button() {
      Row({ space: 4 }) {
        Image(icon)
          .width(14)
          .height(14)
          .colorFilter(createStrokeIconColorFilter(fontColor))
        Text(label)
          .fontSize(12)
          .fontColor(fontColor)
      }
    }
    .layoutWeight(1)
    .height(40)
    .backgroundColor(color)
    .borderRadius(12)
    .onClick(action)
  }

  @Builder
  private buildInlineAction(label: string, color: string, fontColor: string, action: () => void) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(12)
      .backgroundColor(color)
      .fontColor(fontColor)
      .borderRadius(10)
      .onClick(action)
  }

  private async loadCurrentPaneFiles(): Promise<void> {
    if (this.currentPane === 'local') {
      const files = await this.fileTransferService.listDirectory(this.localPath);
      this.localFiles = this.sortEntries(files.map((item: FileInfo) => this.mapFileInfo(item)));
      return;
    }
    const files = await this.fileTransferService.listRemoteDirectory(this.remotePath);
    this.remoteFiles = this.sortEntries(files.map((item: FileInfo) => this.mapFileInfo(item)));
  }

  private async refreshCurrentPaneFiles(): Promise<void> {
    this.isFileListRefreshing = true;
    this.fileListRefreshAngle = 0;
    this.fileListRefreshTimer = setInterval(() => {
      this.fileListRefreshAngle = (this.fileListRefreshAngle + 18) % 360;
    }, 40);
    try {
      await this.loadCurrentPaneFiles();
    } finally {
      if (this.fileListRefreshTimer !== -1) {
        clearInterval(this.fileListRefreshTimer);
        this.fileListRefreshTimer = -1;
      }
      this.fileListRefreshAngle = 0;
      this.isFileListRefreshing = false;
    }
  }

  private sortEntries(entries: FileEntry[]): FileEntry[] {
    const next = entries.slice();
    next.sort((a: FileEntry, b: FileEntry) => {
      if (a.type !== b.type) {
        return a.type === 'folder' ? -1 : 1;
      }
      if (this.sortMode === 'time') {
        return b.modifiedTime - a.modifiedTime;
      }
      return a.name.localeCompare(b.name);
    });
    return next;
  }

  private async openFolder(entry: FileEntry): Promise<void> {
    if (this.currentPane === 'local') {
      this.localPath = entry.path;
    } else {
      this.remotePath = entry.path;
    }
    await this.loadCurrentPaneFiles();
  }

  private async goParentDirectory(): Promise<void> {
    if (this.currentPane === 'local') {
      this.localPath = this.parentPath(this.localPath, '/storage/Users/currentUser/Download');
    } else {
      this.remotePath = this.parentPath(this.remotePath, '/remote');
    }
    await this.loadCurrentPaneFiles();
  }

  private async createFolder(): Promise<void> {
    const name = this.newFolderName.trim();
    if (name.length === 0) {
      return;
    }
    if (this.currentPane === 'local') {
      await this.fileTransferService.createDirectory(`${this.localPath}/${name}`);
    } else {
      await this.fileTransferService.createRemoteDirectory(`${this.remotePath}/${name}`);
    }
    this.newFolderName = '';
    await this.loadCurrentPaneFiles();
  }

  private async deleteEntry(entry: FileEntry): Promise<void> {
    if (this.currentPane === 'local') {
      await this.fileTransferService.deleteFile(entry.path);
    } else {
      await this.fileTransferService.deleteRemoteFile(entry.path);
    }
    await this.loadCurrentPaneFiles();
  }

  private async queueTransfer(entry: FileEntry, direction: 'upload' | 'download'): Promise<void> {
    const fileInfo: FileInfo = {
      path: entry.path,
      name: entry.name,
      size: this.parseFileSize(entry.size),
      isDirectory: entry.type === 'folder',
      modifiedTime: entry.modifiedTime
    };
    const task = this.fileTransferService.createTransferTask(fileInfo, direction);
    this.refreshTransferTasks();
    await this.fileTransferService.startTransfer(task.id, this.getTransferTargetPath(direction));
  }

  private async startFirstLocalUpload(): Promise<void> {
    if (this.localFiles.length === 0) {
      await this.loadCurrentPaneFiles();
    }
    const firstFile = this.localFiles.find((item: FileEntry) => item.type === 'file');
    if (firstFile) {
      await this.queueTransfer(firstFile, 'upload');
    }
  }

  private async startFirstRemoteDownload(): Promise<void> {
    if (this.remoteFiles.length === 0) {
      await this.loadCurrentPaneFiles();
    }
    const firstFile = this.remoteFiles.find((item: FileEntry) => item.type === 'file');
    if (firstFile) {
      await this.queueTransfer(firstFile, 'download');
    }
  }

  private async startTask(taskId: string): Promise<void> {
    const task = this.fileTransferService.getTransferTask(taskId);
    if (!task) {
      return;
    }
    await this.fileTransferService.startTransfer(taskId, this.getTransferTargetPath(task.direction));
    this.refreshTransferTasks();
  }

  private pauseTask(taskId: string): void {
    this.fileTransferService.pauseTransfer(taskId);
    this.refreshTransferTasks();
  }

  private cancelTask(taskId: string): void {
    this.fileTransferService.cancelTransfer(taskId);
    this.refreshTransferTasks();
  }

  private refreshTransferTasks(): void {
    const activeTasks = this.fileTransferService.getAllTransferTasks();
    if (activeTasks.length === 0) {
      this.tasks = this.appData.getTransferTasks(this.deviceId);
      return;
    }
    this.tasks = activeTasks.map((task): TransferTask => {
      return {
        id: task.id,
        name: task.fileInfo.name,
        direction: task.direction,
        progress: Math.floor(task.progress),
        status: this.mapTaskStatus(task.status),
        size: FileTransferService.formatFileSize(task.totalBytes)
      };
    });
  }

  private mapTaskStatus(status: string): 'queued' | 'running' | 'done' | 'failed' | 'cancelled' {
    if (status === 'completed') {
      return 'done';
    }
    if (status === 'transferring') {
      return 'running';
    }
    if (status === 'failed') {
      return 'failed';
    }
    if (status === 'cancelled') {
      return 'cancelled';
    }
    return 'queued';
  }

  private mapFileInfo(item: FileInfo): FileEntry {
    return {
      name: item.name,
      type: item.isDirectory ? 'folder' : 'file',
      size: item.isDirectory ? '-' : FileTransferService.formatFileSize(item.size),
      modified: this.formatTimestamp(item.modifiedTime),
      modifiedTime: item.modifiedTime,
      path: item.path
    };
  }

  private parseFileSize(value: string): number {
    if (value === '-') {
      return 0;
    }
    if (value.endsWith('KB')) {
      return Math.floor(Number(value.replace('KB', '').trim()) * 1024);
    }
    if (value.endsWith('MB')) {
      return Math.floor(Number(value.replace('MB', '').trim()) * 1024 * 1024);
    }
    if (value.endsWith('GB')) {
      return Math.floor(Number(value.replace('GB', '').trim()) * 1024 * 1024 * 1024);
    }
    return Number(value.replace('B', '').trim());
  }

  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}-${date.getDate()} ${date.getHours()}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private formatTaskStatus(status: string): string {
    if (status === 'done') {
      return this.lt('Completed');
    }
    if (status === 'running') {
      return this.lt('Transferring');
    }
    if (status === 'failed') {
      return this.lt('Failed');
    }
    if (status === 'cancelled') {
      return this.lt('Cancelled');
    }
    return this.lt('Queued');
  }

  private getTransferTargetPath(direction: 'upload' | 'download'): string {
    return direction === 'upload' ? this.remotePath : this.localPath;
  }

  private getCurrentPath(): string {
    return this.currentPane === 'local' ? this.localPath : this.remotePath;
  }

  private getCurrentEntries(): FileEntry[] {
    return this.currentPane === 'local' ? this.localFiles : this.remoteFiles;
  }

  private canGoUp(): boolean {
    return this.currentPane === 'local'
      ? this.localPath !== '/storage/Users/currentUser/Download'
      : this.remotePath !== '/remote';
  }

  private parentPath(path: string, rootPath: string): string {
    if (path === rootPath) {
      return rootPath;
    }
    const segments = path.split('/');
    segments.pop();
    const joined = segments.join('/');
    return joined.length > 0 ? joined : rootPath;
  }

  private getRouteParams(): Record<string, string> {
    return this.getUIContext().getRouter().getParams() as Record<string, string>;
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      console.error('router back failed', JSON.stringify(error));
    }
  }

  private lt(key: string): string {
    this.i18nVersion;
    return I18nService.getInstance().translate(key);
  }

  private onI18nVersionChanged(): void {
    this.i18nVersion = this.i18nRefresh;
  }
}
