import { AppDataService, TransferTask } from '../services/AppDataService';
import { createStrokeIconColorFilter, PageHeader } from '../common/CommonComponents';
import { ThemeConfig } from '../common/ThemeConfig';
import {
  FileInfo,
  FileOverrideRequest,
  FileTransferEvent,
  FileTransferService
} from '../services/FileTransferService';
import { I18nService } from '../services/I18nService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { PermissionService } from '../services/PermissionService';

type FilePane = 'local' | 'remote';
type SortField = 'name' | 'type' | 'time' | 'size';

interface FileEntry {
  name: string;
  type: 'folder' | 'file';
  size: string;
  modified: string;
  modifiedTime: number;
  path: string;
  selected: boolean;
}

@Entry
@Component
struct FileTransfer {
  private appData: AppDataService = AppDataService.getInstance();
  private fileTransferService: FileTransferService = FileTransferService.getInstance();
  private transferListener = (event: FileTransferEvent): void => {
    if (event.type === 'override_required' && event.overrideRequest) {
      this.pendingOverrideRequest = event.overrideRequest;
      this.showOverrideDialog = true;
      return;
    }
    if (event.task) {
      this.refreshTransferTasks();
    }
    if (event.type === 'remote_fs_changed') {
      const resolvedPath = this.fileTransferService.getLastRemoteDirectoryPath();
      if (this.remotePath.length === 0 && resolvedPath.length > 0) {
        this.remotePath = resolvedPath;
      }
      if (this.currentPane === 'remote') {
        const files = this.fileTransferService.getCachedRemoteDirectory(this.remotePath);
        this.remoteFiles = this.sortEntries(files.map((item: FileInfo) => this.mapFileInfo(item)));
      }
    }
  };
  private fileAccessRequestPromise: Promise<boolean> | null = null;
  private bootstrapTimer: number = -1;

  @State deviceId: string = '';
  @State deviceName: string = '';
  @State currentPane: FilePane = 'remote';
  @State sortField: SortField = 'name';
  @State tasks: TransferTask[] = [];
  @State localPath: string = '';
  @State remotePath: string = '';
  @State localFiles: FileEntry[] = [];
  @State remoteFiles: FileEntry[] = [];
  @State newFolderName: string = '';
  @State isFileListRefreshing: boolean = false;
  @State fileListRefreshAngle: number = 0;
  @State fileAccessAuthorized: boolean = false;
  @State showOverrideDialog: boolean = false;
  @State showSortMenu: boolean = false;
  @State showMoreMenu: boolean = false;
  @State showItemMenu: boolean = false;
  @State itemMenuEntry: FileEntry | null = null;
  @State showNewFolderDialog: boolean = false;
  @State showRenameDialog: boolean = false;
  @State renameDraft: string = '';
  @State showHiddenFiles: boolean = false;
  @State multiSelectMode: boolean = false;
  @State clipboardEntries: FileEntry[] = [];
  @State clipboardSource: FilePane = 'local';
  @State pasteMode: boolean = false;
  private pendingOverrideRequest: FileOverrideRequest | null = null;
  private fileListRefreshTimer: number = -1;

  aboutToAppear() {
    const params = this.getRouteParams();
    if (params && params['deviceId']) {
      this.deviceId = params['deviceId'];
    }
    this.deviceName = this.appData.getDisplayName(this.deviceId);
    this.localPath = this.fileTransferService.getLocalRootPath();
    this.remotePath = this.fileTransferService.getRemoteRootPath();
    this.fileTransferService.addEventListener(this.transferListener);
    this.refreshTransferTasks();
    this.bootstrapTimer = setTimeout(() => {
      void this.bootstrapFileTransferPage();
    }, 200);
  }

  aboutToDisappear() {
    if (this.bootstrapTimer !== -1) {
      clearTimeout(this.bootstrapTimer);
      this.bootstrapTimer = -1;
    }
    if (this.fileListRefreshTimer !== -1) {
      clearInterval(this.fileListRefreshTimer);
      this.fileListRefreshTimer = -1;
    }
    this.fileTransferService.removeEventListener(this.transferListener);
  }

  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_SURFACE') theme_ACCENT_SURFACE: string = '#1A2742';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SUBTLE') theme_BORDER_SUBTLE: string = '#2C3343';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_DIALOG_OVERLAY') theme_DIALOG_OVERLAY: string = '#80000000';
  @StorageProp('theme_ERROR_BG') theme_ERROR_BG: string = '#3B1D24';
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
  private get selectedCount(): number {
    return this.getCurrentEntries().filter((e: FileEntry) => e.selected).length;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.buildHeader()
        this.buildToolbar()
        this.buildFileListArea()
        this.buildBottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme_GRAY_BG)

      Column()
        .width('100%')
        .height(this.avoidStatusBarHeight + 156)
        .linearGradient({
          angle: 180,
          colors: this.themeIsDark
            ? [['#CC171A22', 0.0], ['#99171A22', 0.3], ['#55171A22', 0.7], ['#00171A22', 1.0]]
            : [['#CCF0F4FA', 0.0], ['#99F0F4FA', 0.3], ['#55F0F4FA', 0.7], ['#00F0F4FA', 1.0]]
        })
        .hitTestBehavior(HitTestMode.Transparent)

      if (this.showSortMenu) {
        this.buildSortMenu()
      }
      if (this.showMoreMenu) {
        this.buildMoreMenu()
      }
      if (this.showItemMenu && this.itemMenuEntry !== null) {
        this.buildItemMenu()
      }
      if (this.showOverrideDialog && this.pendingOverrideRequest !== null) {
        this.buildOverrideDialog()
      }
      if (this.showNewFolderDialog) {
        this.buildNewFolderDialog()
      }
      if (this.showRenameDialog && this.itemMenuEntry !== null) {
        this.buildRenameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildHeader() {
    Row() {
      Image($rawfile('close.svg'))
        .width(24)
        .height(24)
        .fillColor(this.theme_TEXT_PRIMARY)
        .onClick(() => this.goBack())
        .margin({ right: 12 })

      Row() {
        Row() {
          Image($rawfile('ft_phone.svg'))
            .width(16)
            .height(16)
            .colorFilter(createStrokeIconColorFilter(this.currentPane === 'local' ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY))
          Text(this.lt('Local'))
            .fontSize(14)
            .fontColor(this.currentPane === 'local' ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
            .margin({ left: 6 })
        }
        .layoutWeight(1)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentPane === 'local' ? this.theme_ACCENT : this.theme_INACTIVE_BG)
        .borderRadius({ topLeft: 8, bottomLeft: 8 })
        .onClick(() => {
          this.currentPane = 'local';
          void this.loadCurrentPaneFiles();
        })

        Row() {
          Image($rawfile('ft_remote.svg'))
            .width(16)
            .height(16)
            .colorFilter(createStrokeIconColorFilter(this.currentPane === 'remote' ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY))
          Text(this.lt('Remote'))
            .fontSize(14)
            .fontColor(this.currentPane === 'remote' ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
            .margin({ left: 6 })
        }
        .layoutWeight(1)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.currentPane === 'remote' ? this.theme_ACCENT : this.theme_INACTIVE_BG)
        .borderRadius({ topRight: 8, bottomRight: 8 })
        .onClick(() => {
          this.currentPane = 'remote';
          void this.loadCurrentPaneFiles();
        })
      }
      .layoutWeight(1)

      Image($rawfile('dots_vertical.svg'))
        .width(24)
        .height(24)
        .fillColor(this.theme_TEXT_PRIMARY)
        .margin({ left: 12 })
        .onClick(() => {
          this.showMoreMenu = true;
        })
    }
    .width('100%')
    .height(112)
    .padding({ left: 16, right: 16, top: this.avoidStatusBarHeight, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildToolbar() {
    Row() {
      Image($rawfile('ft_home.svg'))
        .width(22)
        .height(22)
        .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_PRIMARY))
        .onClick(() => {
          void this.goHome();
        })

      Blank()

      Image($rawfile('ft_back.svg'))
        .width(22)
        .height(22)
        .colorFilter(createStrokeIconColorFilter(this.canGoBack() ? this.theme_TEXT_PRIMARY : this.theme_TEXT_TERTIARY))
        .margin({ right: 16 })
        .onClick(() => {
          if (this.canGoBack()) {
            void this.goParentDirectory();
          }
        })

      Image($rawfile('ft_up.svg'))
        .width(22)
        .height(22)
        .colorFilter(createStrokeIconColorFilter(this.canGoUp() ? this.theme_TEXT_PRIMARY : this.theme_TEXT_TERTIARY))
        .margin({ right: 16 })
        .onClick(() => {
          if (this.canGoUp()) {
            void this.goParentDirectory();
          }
        })

      Image($rawfile('ft_sort.svg'))
        .width(22)
        .height(22)
        .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_PRIMARY))
        .onClick(() => {
          this.showSortMenu = true;
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildFileListArea() {
    if (this.getCurrentEntries().length === 0) {
      Column() {
        Text(this.lt('Current dir empty'))
          .fontSize(14)
          .fontColor(this.theme_TEXT_TERTIARY)
          .margin({ top: 60 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
    } else {
      List() {
        ForEach(this.getCurrentEntries(), (entry: FileEntry) => {
          ListItem() {
            this.buildFileRow(entry)
          }
        }, (entry: FileEntry) => entry.path)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  private buildFileRow(entry: FileEntry) {
    Row() {
      if (this.multiSelectMode) {
        if (entry.selected) {
          Image($rawfile('checkbox-checked.svg'))
            .width(20)
            .height(20)
            .colorFilter(createStrokeIconColorFilter(this.theme_ACCENT))
            .margin({ right: 12 })
        } else {
          Image($rawfile('checkbox-unchecked.svg'))
            .width(20)
            .height(20)
            .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
            .margin({ right: 12 })
        }
      }

      Image($rawfile(entry.type === 'folder' ? 'ft_folder.svg' : 'ft_file.svg'))
        .width(22)
        .height(22)
        .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_SECONDARY))
        .margin({ right: 12 })

      Column({ space: 2 }) {
        Text(entry.name)
          .fontSize(15)
          .fontColor(this.theme_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(entry.modified)
          .fontSize(12)
          .fontColor(this.theme_TEXT_TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($rawfile('dots_vertical.svg'))
        .width(20)
        .height(20)
        .fillColor(this.theme_TEXT_TERTIARY)
        .onClick(() => {
          this.itemMenuEntry = entry;
          this.showItemMenu = true;
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(entry.selected ? this.theme_ACCENT_SURFACE : Color.Transparent)
    .onClick(() => {
      if (this.multiSelectMode) {
        entry.selected = !entry.selected;
      } else if (entry.type === 'folder') {
        void this.openFolder(entry);
      }
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (!this.multiSelectMode) {
            this.enterMultiSelectWith(entry);
          } else {
            entry.selected = !entry.selected;
          }
        })
    )
  }

  @Builder
  private buildBottomBar() {
    if (this.pasteMode && this.clipboardEntries.length > 0) {
      Row() {
        Column({ space: 2 }) {
          Text(this.lt('Paste here?'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme_ACCENT_TEXT)
          Text(`${this.clipboardEntries.length} ${this.lt('items')} [${this.clipboardSource === 'local' ? this.lt('Local') : this.lt('Remote')}]`)
            .fontSize(12)
            .fontColor(this.theme_ACCENT_TEXT)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Image($rawfile('ft_paste.svg'))
          .width(22)
          .height(22)
          .colorFilter(createStrokeIconColorFilter(this.theme_ACCENT_TEXT))
          .margin({ left: 16 })
          .onClick(() => {
            void this.executePaste();
          })

        Image($rawfile('close.svg'))
          .width(22)
          .height(22)
          .fillColor(this.theme_ACCENT_TEXT)
          .margin({ left: 16 })
          .onClick(() => {
            this.cancelPaste();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.theme_ACCENT)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.avoidNavigationBarHeight })
    } else if (this.multiSelectMode) {
      Row() {
        Text(`${this.lt('Selected')} ${this.selectedCount} ${this.lt('items')}`)
          .fontSize(14)
          .fontColor(this.theme_TEXT_PRIMARY)
          .layoutWeight(1)

        Image($rawfile('ft_copy.svg'))
          .width(22)
          .height(22)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_PRIMARY))
          .margin({ left: 16 })
          .onClick(() => {
            this.copySelected();
          })

        Image($rawfile('ft_delete.svg'))
          .width(22)
          .height(22)
          .colorFilter(createStrokeIconColorFilter(this.theme_ERROR_TEXT))
          .margin({ left: 16 })
          .onClick(() => {
            void this.deleteSelected();
          })

        Image($rawfile('close.svg'))
          .width(22)
          .height(22)
          .fillColor(this.theme_TEXT_PRIMARY)
          .margin({ left: 16 })
          .onClick(() => {
            this.exitMultiSelect();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.theme_CARD_BG)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.avoidNavigationBarHeight })
    } else {
      Column() {
        Text(this.getCurrentPath())
          .fontSize(12)
          .fontColor(this.theme_TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 16, right: 16 })

        Text(`${this.lt('Total')}: ${this.getCurrentEntries().length} ${this.lt('items')}`)
          .fontSize(12)
          .fontColor(this.theme_TEXT_TERTIARY)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }
      .width('100%')
      .padding({ top: 8 })
      .backgroundColor(this.theme_GRAY_BG)
      .margin({ bottom: this.avoidNavigationBarHeight })
    }
  }

  @Builder
  private buildSortMenu() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Column() {
          this.buildSortMenuItem('name', this.lt('Name'))
          this.buildSortMenuItem('type', this.lt('Type'))
          this.buildSortMenuItem('time', this.lt('Modified time'))
          this.buildSortMenuItem('size', this.lt('Size'))
        }
        .width(180)
        .backgroundColor(this.theme_CARD_BG)
        .opacity(0.92)
        .border({ width: 1, color: this.theme_BORDER_SUBTLE })
        .borderRadius(8)
        .shadow({ radius: 16, color: '#66000000' })
      }
      .margin({ top: 160, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#4D000000')
    .onClick(() => {
      this.showSortMenu = false;
    })
    .zIndex(50)
  }

  @Builder
  private buildSortMenuItem(field: SortField, label: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.sortField === field ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
        .layoutWeight(1)
      if (this.sortField === field) {
        Image($rawfile('checkmark.svg'))
          .width(16)
          .height(16)
          .fillColor(this.theme_ACCENT)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.sortField = field;
      this.reSortCurrentEntries();
      this.showSortMenu = false;
    })
  }

  @Builder
  private buildMoreMenu() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Column() {
          this.buildMenuRow($rawfile('refresh.svg'), this.lt('Refresh files'), () => {
            this.showMoreMenu = false;
            void this.refreshCurrentPaneFiles();
          })

          this.buildMenuRow($rawfile('checkbox-checked.svg'), this.lt('Multi-select'), () => {
            this.showMoreMenu = false;
            this.enterMultiSelect();
          })

          this.buildMenuRow($rawfile('ft_new_folder.svg'), this.lt('Create folder'), () => {
            this.showMoreMenu = false;
            this.newFolderName = '';
            this.showNewFolderDialog = true;
          })

          this.buildMenuRow(
            $rawfile(this.showHiddenFiles ? 'ft_show.svg' : 'ft_hidden.svg'),
            this.lt('Show hidden files'),
            () => {
              this.showMoreMenu = false;
              this.showHiddenFiles = !this.showHiddenFiles;
              void this.loadCurrentPaneFiles();
            },
            this.showHiddenFiles
          )
        }
        .width(200)
        .backgroundColor(this.theme_CARD_BG)
        .opacity(0.92)
        .border({ width: 1, color: this.theme_BORDER_SUBTLE })
        .borderRadius(8)
        .shadow({ radius: 16, color: '#66000000' })
      }
      .margin({ top: 160, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#4D000000')
    .onClick(() => {
      this.showMoreMenu = false;
    })
    .zIndex(50)
  }

  @Builder
  private buildItemMenu() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Column() {
          this.buildMenuRow($rawfile('ft_delete.svg'), this.lt('Delete Action'), () => {
            this.showItemMenu = false;
            if (this.itemMenuEntry) {
              void this.deleteEntry(this.itemMenuEntry);
            }
          })

          this.buildMenuRow($rawfile('checkbox-checked.svg'), this.lt('Multi-select'), () => {
            this.showItemMenu = false;
            if (this.itemMenuEntry) {
              this.enterMultiSelectWith(this.itemMenuEntry);
            }
          })

          this.buildMenuRow($rawfile('ft_file.svg'), this.lt('Properties'), () => {
            this.showItemMenu = false;
            if (this.itemMenuEntry) {
              void this.showToast(`${this.itemMenuEntry.name}\n${this.itemMenuEntry.type === 'folder' ? this.lt('Folder') : this.lt('File')}\n${this.itemMenuEntry.size}\n${this.itemMenuEntry.modified}`);
            }
          })

          this.buildMenuRow($rawfile('info_edit.svg'), this.lt('Rename'), () => {
            this.showItemMenu = false;
            if (this.itemMenuEntry) {
              this.renameDraft = this.itemMenuEntry.name;
              this.showRenameDialog = true;
            }
          })
        }
        .width(180)
        .backgroundColor(this.theme_CARD_BG)
        .opacity(0.92)
        .border({ width: 1, color: this.theme_BORDER_SUBTLE })
        .borderRadius(8)
        .shadow({ radius: 16, color: '#66000000' })
      }
      .margin({ top: 200, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#4D000000')
    .onClick(() => {
      this.showItemMenu = false;
    })
    .zIndex(50)
  }

  @Builder
  private buildMenuRow(icon: Resource, label: string, action: () => void, checked: boolean = false) {
    Row({ space: 10 }) {
      Image(icon)
        .width(18)
        .height(18)
        .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_PRIMARY))
      Text(label)
        .fontSize(14)
        .fontColor(this.theme_TEXT_PRIMARY)
        .layoutWeight(1)
      if (checked) {
        Image($rawfile('checkmark.svg'))
          .width(16)
          .height(16)
          .fillColor(this.theme_ACCENT)
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .onClick(action)
  }

  @Builder
  private buildNewFolderDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.lt('Create folder'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        TextInput({ placeholder: this.lt('New folder name'), text: this.newFolderName })
          .height(42)
          .backgroundColor(this.theme_INPUT_BG)
          .border({ width: 1, color: this.theme_BORDER_SUBTLE })
          .borderRadius(8)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.newFolderName = value;
          })

        Row({ space: 8 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showNewFolderDialog = false;
            })
          Button(this.lt('Create'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .onClick(() => {
              this.showNewFolderDialog = false;
              void this.createFolder();
            })
        }
      }
      .width('88%')
      .padding(18)
      .backgroundColor(this.theme_CARD_BG)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .zIndex(80)
    .hitTestBehavior(HitTestMode.Block)
  }

  @Builder
  private buildRenameDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.lt('Rename'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        TextInput({ text: this.renameDraft })
          .height(42)
          .backgroundColor(this.theme_INPUT_BG)
          .border({ width: 1, color: this.theme_BORDER_SUBTLE })
          .borderRadius(8)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.renameDraft = value;
          })

        Row({ space: 8 }) {
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .onClick(() => {
              this.showRenameDialog = false;
            })
          Button(this.lt('Rename'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .onClick(() => {
              this.showRenameDialog = false;
              void this.renameEntry();
            })
        }
      }
      .width('88%')
      .padding(18)
      .backgroundColor(this.theme_CARD_BG)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .zIndex(80)
    .hitTestBehavior(HitTestMode.Block)
  }

  @Builder
  private buildOverrideDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Text(this.lt('Overwrite'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme_TEXT_PRIMARY)

        Text(this.pendingOverrideRequest?.targetPath ?? '')
          .fontSize(13)
          .fontColor(this.theme_TEXT_SECONDARY)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.pendingOverrideRequest?.isIdentical === true) {
          Text(this.lt('Files are identical'))
            .fontSize(12)
            .fontColor(this.theme_TEXT_TERTIARY)
        }

        Row({ space: 8 }) {
          Button(this.lt('Replace'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_ACCENT)
            .fontColor(this.theme_ACCENT_TEXT)
            .onClick(() => this.respondToOverride('replace'))
          Button(this.lt('Skip'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .onClick(() => this.respondToOverride('skip'))
          Button(this.lt('Cancel'))
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.theme_ERROR_BG)
            .fontColor(this.theme_ERROR_TEXT)
            .onClick(() => this.respondToOverride('cancel'))
        }
        .width('100%')
      }
      .width('88%')
      .padding(18)
      .backgroundColor(this.theme_CARD_BG)
      .border({ width: 1, color: this.theme_BORDER_SUBTLE })
      .borderRadius(8)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_DIALOG_OVERLAY)
    .zIndex(80)
    .hitTestBehavior(HitTestMode.Block)
  }

  private enterMultiSelect(): void {
    this.multiSelectMode = true;
    this.clearSelection();
  }

  private enterMultiSelectWith(entry: FileEntry): void {
    this.multiSelectMode = true;
    this.clearSelection();
    entry.selected = true;
  }

  private exitMultiSelect(): void {
    this.multiSelectMode = false;
    this.clearSelection();
  }

  private clearSelection(): void {
    this.localFiles.forEach((e: FileEntry) => e.selected = false);
    this.remoteFiles.forEach((e: FileEntry) => e.selected = false);
  }

  private copySelected(): void {
    const selected = this.getCurrentEntries().filter((e: FileEntry) => e.selected);
    if (selected.length === 0) {
      return;
    }
    this.clipboardEntries = selected.slice();
    this.clipboardSource = this.currentPane;
    this.pasteMode = true;
    this.currentPane = this.currentPane === 'local' ? 'remote' : 'local';
    void this.loadCurrentPaneFiles();
  }

  private cancelPaste(): void {
    this.pasteMode = false;
    this.clipboardEntries = [];
    this.exitMultiSelect();
  }

  private async executePaste(): Promise<void> {
    if (!await this.ensureLocalFileAccessAuthorization()) {
      return;
    }
    const direction = this.clipboardSource === 'local' ? 'upload' : 'download';
    for (const entry of this.clipboardEntries) {
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
    this.pasteMode = false;
    this.clipboardEntries = [];
    this.exitMultiSelect();
  }

  private async deleteSelected(): Promise<void> {
    const selected = this.getCurrentEntries().filter((e: FileEntry) => e.selected);
    for (const entry of selected) {
      await this.deleteEntry(entry);
    }
    this.exitMultiSelect();
  }

  private async renameEntry(): Promise<void> {
    if (!this.itemMenuEntry || this.renameDraft.trim().length === 0) {
      return;
    }
    void this.showToast(`${this.lt('Rename')} → ${this.renameDraft}`);
  }

  private async loadCurrentPaneFiles(): Promise<void> {
    if (this.currentPane === 'local') {
      const granted = await this.ensureLocalFileAccessAuthorization();
      if (!granted) {
        this.localFiles = [];
        return;
      }
      const files = await this.fileTransferService.listDirectory(this.localPath);
      this.localFiles = this.sortEntries(files.map((item: FileInfo) => this.mapFileInfo(item)));
      return;
    }
    const files = await this.fileTransferService.listRemoteDirectory(this.remotePath);
    if (this.remotePath.length === 0) {
      this.remotePath = this.fileTransferService.getLastRemoteDirectoryPath();
    }
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
    let filtered = entries;
    if (!this.showHiddenFiles) {
      filtered = entries.filter((e: FileEntry) => !e.name.startsWith('.'));
    }
    const next = filtered.slice();
    next.sort((a: FileEntry, b: FileEntry) => {
      if (a.type !== b.type) {
        return a.type === 'folder' ? -1 : 1;
      }
      if (this.sortField === 'time') {
        return b.modifiedTime - a.modifiedTime;
      }
      if (this.sortField === 'size') {
        return this.parseFileSize(b.size) - this.parseFileSize(a.size);
      }
      if (this.sortField === 'type') {
        return a.type.localeCompare(b.type) || a.name.localeCompare(b.name);
      }
      return a.name.localeCompare(b.name);
    });
    return next;
  }

  private reSortCurrentEntries(): void {
    if (this.currentPane === 'local') {
      this.localFiles = this.sortEntries(this.localFiles);
    } else {
      this.remoteFiles = this.sortEntries(this.remoteFiles);
    }
  }

  private async openFolder(entry: FileEntry): Promise<void> {
    if (this.currentPane === 'local') {
      if (!await this.ensureLocalFileAccessAuthorization()) {
        return;
      }
      this.localPath = entry.path;
    } else {
      this.remotePath = entry.path;
    }
    await this.loadCurrentPaneFiles();
  }

  private async goParentDirectory(): Promise<void> {
    if (this.currentPane === 'local') {
      if (!await this.ensureLocalFileAccessAuthorization()) {
        return;
      }
      this.localPath = this.parentPath(this.localPath, this.fileTransferService.getLocalRootPath());
    } else {
      this.remotePath = this.parentPath(this.remotePath, this.fileTransferService.getRemoteRootPath());
    }
    await this.loadCurrentPaneFiles();
  }

  private async goHome(): Promise<void> {
    if (this.currentPane === 'local') {
      this.localPath = this.fileTransferService.getLocalRootPath();
    } else {
      this.remotePath = this.fileTransferService.getRemoteRootPath();
    }
    await this.loadCurrentPaneFiles();
  }

  private async createFolder(): Promise<void> {
    const name = this.newFolderName.trim();
    if (name.length === 0) {
      return;
    }
    if (this.currentPane === 'local') {
      if (!await this.ensureLocalFileAccessAuthorization()) {
        return;
      }
      await this.fileTransferService.createDirectory(this.fileTransferService.joinPath(this.localPath, name));
    } else {
      await this.fileTransferService.createRemoteDirectory(this.fileTransferService.joinPath(this.remotePath, name));
    }
    this.newFolderName = '';
    await this.loadCurrentPaneFiles();
  }

  private async deleteEntry(entry: FileEntry): Promise<void> {
    if (this.currentPane === 'local') {
      if (!await this.ensureLocalFileAccessAuthorization()) {
        return;
      }
      await this.fileTransferService.deleteFile(entry.path);
    } else {
      await this.fileTransferService.deleteRemoteFile(entry.path);
    }
    await this.loadCurrentPaneFiles();
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
    if (status === 'completed') return 'done';
    if (status === 'transferring') return 'running';
    if (status === 'failed') return 'failed';
    if (status === 'cancelled') return 'cancelled';
    return 'queued';
  }

  private mapFileInfo(item: FileInfo): FileEntry {
    return {
      name: item.name,
      type: item.isDirectory ? 'folder' : 'file',
      size: item.isDirectory ? '-' : FileTransferService.formatFileSize(item.size),
      modified: this.formatTimestamp(item.modifiedTime),
      modifiedTime: item.modifiedTime,
      path: item.path,
      selected: false
    };
  }

  private parseFileSize(value: string): number {
    if (value === '-') return 0;
    if (value.endsWith('KB')) return Math.floor(Number(value.replace('KB', '').trim()) * 1024);
    if (value.endsWith('MB')) return Math.floor(Number(value.replace('MB', '').trim()) * 1024 * 1024);
    if (value.endsWith('GB')) return Math.floor(Number(value.replace('GB', '').trim()) * 1024 * 1024 * 1024);
    return Number(value.replace('B', '').trim());
  }

  private formatTimestamp(timestamp: number): string {
    const date = new Date(timestamp);
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    const h = date.getHours().toString().padStart(2, '0');
    const min = date.getMinutes().toString().padStart(2, '0');
    const s = date.getSeconds().toString().padStart(2, '0');
    return `${y}-${m}-${d} ${h}:${min}:${s}`;
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
      ? this.localPath !== this.fileTransferService.getLocalRootPath()
      : this.remotePath !== this.fileTransferService.getRemoteRootPath();
  }

  private canGoBack(): boolean {
    return this.canGoUp();
  }

  private parentPath(path: string, rootPath: string): string {
    return this.fileTransferService.parentPath(path, rootPath);
  }

  private getRouteParams(): Record<string, string> {
    return this.getUIContext().getRouter().getParams() as Record<string, string>;
  }

  private async bootstrapFileTransferPage(): Promise<void> {
    await this.loadCurrentPaneFiles();
  }

  private async ensureLocalFileAccessAuthorization(showToastOnSuccess: boolean = false): Promise<boolean> {
    const localRoot = this.fileTransferService.getLocalRootPath();
    if (this.localPath === localRoot || this.localPath.startsWith(`${localRoot}/`)) {
      this.fileAccessAuthorized = true;
      return true;
    }
    if (this.fileAccessAuthorized) return true;
    if (this.fileAccessRequestPromise) return this.fileAccessRequestPromise;
    this.fileAccessRequestPromise = this.requestLocalFileAccessAuthorization(showToastOnSuccess);
    return this.fileAccessRequestPromise;
  }

  private async requestLocalFileAccessAuthorization(showToastOnSuccess: boolean): Promise<boolean> {
    try {
      const result = await PermissionService.getInstance().requestFileAuthorization({ folder: true, authMode: true });
      const granted = result.granted;
      this.fileAccessAuthorized = granted;
      if (granted && showToastOnSuccess) {
        void this.showToast(this.lt('File access authorized'));
      }
      if (!granted) {
        void this.showToast(this.lt('File access permission denied'));
      }
      return granted;
    } catch (error) {
      this.fileAccessAuthorized = false;
      void this.showToast(this.lt('File access permission denied'));
      return false;
    } finally {
      this.fileAccessRequestPromise = null;
    }
  }

  private respondToOverride(action: 'replace' | 'skip' | 'cancel'): void {
    const request = this.pendingOverrideRequest;
    this.pendingOverrideRequest = null;
    this.showOverrideDialog = false;
    if (request !== null) {
      this.fileTransferService.respondToOverride(request, action);
    }
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      console.error('router back failed', JSON.stringify(error));
    }
  }

  private async showToast(message: string): Promise<void> {
    try {
      await this.getUIContext().getPromptAction().openToast({ message });
    } catch (error) {
      console.error('FileTransfer toast failed', JSON.stringify(error));
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
