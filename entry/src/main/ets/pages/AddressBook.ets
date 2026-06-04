import { AddressBookEntry, AppDataService } from '../services/AppDataService';
import { createStrokeIconColorFilter } from '../common/CommonComponents';
import { ThemeConfig } from '../common/ThemeConfig';
import { CardContainer, EmptyState, PageHeader, SectionTitle, StatusBadge } from '../common/CommonComponents';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { I18nService } from '../services/I18nService';
import { AppState, AccountState } from '../services/AppState';
import { EventBus, EventType } from '../services/EventBus';
import { AccountService } from '../services/AccountService';

type AddressFilter = 'all' | 'favorites' | 'online';

interface DeviceRouteParams {
  deviceId: string;
}

@Entry
@Component
struct AddressBook {
  private appData: AppDataService = AppDataService.getInstance();
  private appState: AppState = AppState.getInstance();
  private eventBus: EventBus = EventBus.getInstance();
  private accountService: AccountService = AccountService.getInstance();

  @State query: string = '';
  @State currentFilter: AddressFilter = 'all';
  @State entries: AddressBookEntry[] = [];
  @State showAddPanel: boolean = false;
  @State draftId: string = '';
  @State draftAlias: string = '';
  @State draftGroup: string = '';
  @State draftNote: string = '';
  @State accountState: AccountState = this.appState.getAccount();

  aboutToAppear() {
    this.reloadEntries();
    this.eventBus.on(EventType.ADDRESS_BOOK_UPDATED, this.onAddressBookUpdated);
    if (this.accountState.isLoggedIn) {
      void this.accountService.fetchAddressBook();
    }
  }

  aboutToDisappear() {
    this.eventBus.off(EventType.ADDRESS_BOOK_UPDATED, this.onAddressBookUpdated);
  }

  private onAddressBookUpdated = (): void => {
    this.reloadEntries();
  };
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
  @StorageProp('theme_ACCENT_SURFACE') theme_ACCENT_SURFACE: string = '#1A2742';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_BORDER_SOFT') theme_BORDER_SOFT: string = '#3A4355';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
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
          if (!this.accountState.isLoggedIn) {
            this.buildLoginPrompt()
          } else {
            this.buildSearchCard()
            if (this.showAddPanel) {
              this.buildAddCard()
            }
            this.buildFilterBar()
            this.buildList()
          }
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: 56, bottom: this.avoidNavigationBarHeight + ThemeConfig.SPACING_MD })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Column() {
        PageHeader(this.lt('Address Book Page'), this.lt('Address Book subtitle'), true, () => {
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
  private buildLoginPrompt() {
    CardContainer() {
      Column({ space: ThemeConfig.SPACING_MD }) {
        Row({ space: ThemeConfig.SPACING_SM }) {
          Image($rawfile('secure_stop.svg'))
            .width(20)
            .height(20)
            .fillColor(this.theme_ACCENT)

          Text(this.lt('Login Required'))
            .fontSize(ThemeConfig.FONT_SIZE_LG)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme_TEXT_PRIMARY)
        }

        Text(this.lt('Please login to sync your address book from server'))
          .fontSize(ThemeConfig.FONT_SIZE_MD)
          .fontColor(this.theme_TEXT_SECONDARY)
          .width('100%')

        Button(this.lt('Go to Login'))
          .width('100%')
          .height(44)
          .backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT)
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
          .onClick(() => {
            this.goBack();
          })
      }
      .width('100%')
    }
  }

  @Builder
  private buildSearchCard() {
    Column({ space: ThemeConfig.SPACING_MD }) {
      Row({ space: ThemeConfig.SPACING_SM }) {
        Row() {
          Image($rawfile('search.svg'))
            .width(18)
            .height(18)
            .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
            .margin({ right: 8 })
          TextInput({ placeholder: this.lt('Search device name, ID or group'), text: this.query })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('transparent')
            .borderRadius(0)
            .padding({ left: 0, right: 0 })
            .onChange((value: string) => {
              this.query = value;
            })
        }
        .layoutWeight(1)
        .height(48)
        .backgroundColor(this.theme_INPUT_BG)
        .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
        .padding({ left: 14, right: 14 })
        .alignItems(VerticalAlign.Center)

        Button(this.showAddPanel ? this.lt('Collapse') : this.lt('Add'))
          .width(80)
          .height(48)
          .fontSize(13)
          .backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT)
          .borderRadius(ThemeConfig.BORDER_RADIUS_LARGE)
          .onClick(() => {
            this.showAddPanel = !this.showAddPanel;
          })
      }

      Row({ space: ThemeConfig.SPACING_SM }) {
        this.buildSummaryChip(this.lt('All Devices'), `${this.entries.length}`)
        this.buildSummaryChip(this.lt('Favorite Devices'), `${this.entries.filter((entry: AddressBookEntry) => entry.favorite).length}`)
        this.buildSummaryChip(this.lt('Online Devices'), `${this.entries.filter((entry: AddressBookEntry) => entry.online).length}`)
      }
    }
  }

  @Builder
  private buildAddCard() {
    Column({ space: ThemeConfig.SPACING_MD }) {
      SectionTitle(this.lt('Add Device'))

      this.buildInput(this.lt('Remote ID'), DeviceIdFormatter.format(this.draftId), (value: string) => {
        this.draftId = DeviceIdFormatter.parse(value);
      })
      this.buildInput(this.lt('Device Name'), this.draftAlias, (value: string) => {
        this.draftAlias = value;
      })
      this.buildInput(this.lt('Group'), this.draftGroup, (value: string) => {
        this.draftGroup = value;
      })
      this.buildInput(this.lt('Note'), this.draftNote, (value: string) => {
        this.draftNote = value;
      })

      Row({ space: ThemeConfig.SPACING_SM }) {
        Button(this.lt('Save'))
          .layoutWeight(1)
          .height(44)
          .backgroundColor(this.theme_ACCENT)
          .fontColor(this.theme_ACCENT_TEXT)
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
          .onClick(() => {
            this.saveDraftEntry();
          })

        Button(this.lt('Clear'))
          .layoutWeight(1)
          .height(44)
          .backgroundColor(this.theme_INPUT_BG)
          .fontColor(this.theme_TEXT_PRIMARY)
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
          .border({ width: 1, color: this.theme_BORDER_SOFT })
          .onClick(() => {
            this.resetDraft();
          })
      }
    }
    .width('100%')
    .padding(ThemeConfig.SPACING_LG)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(ThemeConfig.BORDER_RADIUS_XLARGE)
  }

  @Builder
  private buildInput(placeholder: string, value: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .height(46)
      .backgroundColor(this.theme_INPUT_BG)
      .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
      .padding({ left: 14, right: 14 })
      .onChange(onChange)
  }

  @Builder
  private buildFilterBar() {
    Row({ space: 10 }) {
      this.buildFilterButton(this.lt('All'), this.currentFilter === 'all', () => {
        this.currentFilter = 'all';
      })
      this.buildFilterButton(this.lt('Favorites Only'), this.currentFilter === 'favorites', () => {
        this.currentFilter = 'favorites';
      })
      this.buildFilterButton(this.lt('Online'), this.currentFilter === 'online', () => {
        this.currentFilter = 'online';
      })
    }
    .width('100%')
  }

  @Builder
  private buildList() {
    if (this.filteredEntries().length === 0) {
      EmptyState($rawfile('search.svg'), this.lt('No matching devices found.'))
    } else {
      Column({ space: 12 }) {
        ForEach(this.filteredEntries(), (entry: AddressBookEntry) => {
          this.buildEntryCard(entry)
        }, (entry: AddressBookEntry) => entry.id)
      }
    }
  }

  @Builder
  private buildEntryCard(entry: AddressBookEntry) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(entry.alias)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme_TEXT_PRIMARY)

            StatusBadge(entry.online ? this.lt('Online') : this.lt('Offline'), entry.online)
          }

          Text(`${DeviceIdFormatter.format(entry.id)} · ${entry.group}`)
            .fontSize(13)
            .fontColor(this.theme_TEXT_SECONDARY)

          if (entry.note.length > 0) {
            Text(entry.note)
              .fontSize(13)
              .fontColor(this.theme_TEXT_TERTIARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(entry.favorite ? this.lt('Favorited') : this.lt('Favorite'))
          .height(34)
          .fontSize(12)
          .backgroundColor(entry.favorite ? this.theme_ACCENT_SURFACE : this.theme_INPUT_BG)
          .fontColor(entry.favorite ? this.theme_ACCENT : this.theme_TEXT_PRIMARY)
          .borderRadius(10)
          .onClick(() => {
            this.appData.toggleFavorite(entry.id);
            this.reloadEntries();
          })
      }

      Row({ space: 8 }) {
        this.buildActionButton($rawfile('display.svg'), this.lt('Control Action'), this.theme_ACCENT, () => {
          this.openPage('pages/RemoteControl', entry.id);
        })
        this.buildActionButton($rawfile('file_transfer.svg'), this.lt('File Action'), this.theme_ACCENT, () => {
          this.openPage('pages/FileTransfer', entry.id);
        })
        this.buildActionButton($rawfile('keyboard_mouse.svg'), this.lt('Terminal Action'), this.theme_ACCENT, () => {
          this.openPage('pages/Terminal', entry.id);
        })
        this.buildActionButton($rawfile('chat2.svg'), this.lt('Chat Action'), this.theme_ACCENT, () => {
          this.openPage('pages/Chat', entry.id);
        })
      }

      Row({ space: 8 }) {
        this.buildSecondaryAction($rawfile('pinned.svg'), this.lt('Connect Action'), () => {
          this.appData.addRecentSession(this.appData.createRecentSession(entry.id));
          this.openPage('pages/RemoteControl', entry.id);
        })
        this.buildSecondaryAction($rawfile('trash.svg'), this.lt('Delete Action'), () => {
          this.appData.removeAddressBookEntry(entry.id);
          this.reloadEntries();
        })
      }
    }
    .padding(16)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(18)
  }

  @Builder
  private buildSummaryChip(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme_TEXT_PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor(this.theme_TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(this.theme_CARD_BG)
    .borderRadius(14)
  }

  @Builder
  private buildFilterButton(label: string, active: boolean, action: () => void) {
    Button(label)
      .height(36)
      .fontSize(12)
      .backgroundColor(active ? this.theme_ACCENT : this.theme_INPUT_BG)
      .fontColor(active ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
      .borderRadius(12)
      .onClick(action)
  }

  @Builder
  private buildActionButton(icon: Resource, label: string, color: string, action: () => void) {
    Button() {
      Row({ space: 4 }) {
        Image(icon)
          .width(16)
          .height(16)
          .colorFilter(createStrokeIconColorFilter(this.theme_ACCENT_TEXT))
        Text(label)
          .fontSize(12)
          .fontColor(this.theme_ACCENT_TEXT)
      }
    }
    .layoutWeight(1)
    .height(40)
    .backgroundColor(color)
    .borderRadius(12)
    .onClick(action)
  }

  @Builder
  private buildSecondaryAction(icon: Resource, label: string, action: () => void) {
    Button() {
      Row({ space: 4 }) {
        Image(icon)
          .width(16)
          .height(16)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_PRIMARY))
        Text(label)
          .fontSize(12)
          .fontColor(this.theme_TEXT_PRIMARY)
      }
    }
    .layoutWeight(1)
    .height(36)
    .backgroundColor(this.theme_INPUT_BG)
    .borderRadius(12)
    .onClick(action)
  }

  private filteredEntries(): AddressBookEntry[] {
    const keyword = this.query.trim().toLowerCase();
    const normalizedKeyword = DeviceIdFormatter.parse(keyword);
    return this.entries.filter((entry: AddressBookEntry) => {
      if (this.currentFilter === 'favorites' && !entry.favorite) {
        return false;
      }
      if (this.currentFilter === 'online' && !entry.online) {
        return false;
      }
      if (keyword.length === 0) {
        return true;
      }
      return entry.alias.toLowerCase().indexOf(keyword) >= 0 ||
        DeviceIdFormatter.parse(entry.id).toLowerCase().indexOf(normalizedKeyword) >= 0 ||
        entry.group.toLowerCase().indexOf(keyword) >= 0 ||
        entry.note.toLowerCase().indexOf(keyword) >= 0;
    });
  }

  private saveDraftEntry(): void {
    const id = DeviceIdFormatter.parse(this.draftId);
    if (id.length === 0) {
      return;
    }
    this.appData.addAddressBookEntry({
      id: id,
      alias: this.draftAlias.trim().length > 0 ? this.draftAlias.trim() : `${this.lt('Remote Device')} ${DeviceIdFormatter.format(id)}`,
      note: this.draftNote.trim(),
      group: this.draftGroup.trim().length > 0 ? this.draftGroup.trim() : this.lt('Ungrouped'),
      online: true,
      favorite: false,
      platform: ''
    });
    this.resetDraft();
    this.showAddPanel = false;
    this.reloadEntries();
  }

  private resetDraft(): void {
    this.draftId = '';
    this.draftAlias = '';
    this.draftGroup = '';
    this.draftNote = '';
  }

  private reloadEntries(): void {
    this.entries = this.appData.getAddressBook();
  }

  private openPage(url: string, deviceId: string): void {
    const params: DeviceRouteParams = { deviceId: deviceId };
    this.navigateTo(url, params);
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      console.error('router back failed', JSON.stringify(error));
    }
  }

  private navigateTo(url: string, params?: DeviceRouteParams): void {
    try {
      void this.getUIContext().getRouter().pushUrl({ url: url, params: params });
    } catch (error) {
      console.error('router push failed', JSON.stringify(error));
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
