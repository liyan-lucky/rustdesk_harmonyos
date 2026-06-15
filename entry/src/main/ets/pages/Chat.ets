import { createStrokeIconColorFilter } from '../common/CommonComponents';
import { AppDataService } from '../services/AppDataService';
import { EmptyState, PageHeader } from '../common/CommonComponents';
import { ChatEvent, ChatMessage, ChatMessageType, ChatService } from '../services/ChatService';
import { I18nService } from '../services/I18nService';
import { PermissionService } from '../services/PermissionService';
import { ThemeConfig } from '../common/ThemeConfig';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

interface DragFileInfo {
  name: string;
  size: number;
  uri: string;
}

@Entry
@Component
struct Chat {
  private appData: AppDataService = AppDataService.getInstance();
  private chatService: ChatService = ChatService.getInstance();
  private chatListener = (_event: ChatEvent): void => {
    this.refreshMessages();
    this.scheduleChatScroll(50);
  };
  private chatScroller: Scroller = new Scroller();

  @State deviceId: string = '';
  @State deviceName: string = '';
  @State draft: string = '';
  @State messages: ChatMessage[] = [];
  @State unreadCount: number = 0;
  @State isDragging: boolean = false;
  @State dragFiles: DragFileInfo[] = [];
  aboutToAppear() {
    const params = this.getRouteParams();
    if (params && params['deviceId']) {
      this.deviceId = params['deviceId'];
    }
    this.deviceName = this.appData.getDisplayName(this.deviceId);
    this.chatService.updateSessionDeviceName(this.deviceId, this.deviceName);
    this.refreshMessages();
    this.chatService.addEventListener(this.chatListener);
    this.scheduleChatScroll(100);
  }

  aboutToDisappear() {
    this.chatService.removeEventListener(this.chatListener);
  }
  @StorageProp('theme_ACCENT') theme_ACCENT: string = '#0071FF';
  @StorageProp('theme_ACCENT_TEXT') theme_ACCENT_TEXT: string = '#FFFFFF';
  @StorageProp('theme_CARD_BG') theme_CARD_BG: string = '#1E232F';
  @StorageProp('theme_CONTRAST_TEXT') theme_CONTRAST_TEXT: string = '#F8FAFC';
  @StorageProp('theme_ERROR_TEXT') theme_ERROR_TEXT: string = '#FCA5A5';
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('theme_INPUT_BG') theme_INPUT_BG: string = '#232835';
  @StorageProp('theme_TEXT_PRIMARY') theme_TEXT_PRIMARY: string = '#F8FAFC';
  @StorageProp('theme_TEXT_SECONDARY') theme_TEXT_SECONDARY: string = '#AAB2C5';
  @StorageProp('theme_TEXT_TERTIARY') theme_TEXT_TERTIARY: string = '#7E879A';
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('themeIsDark') themeIsDark: boolean = false;
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll(this.chatScroller) {
        if (this.messages.length === 0) {
          Column() {
            EmptyState($rawfile('chat.svg'), this.lt('No messages yet.'))
          }
          .width('100%')
          .padding({ top: 56 + 40 })
        } else {
          Column({ space: 12 }) {
            ForEach(this.messages, (message: ChatMessage, index?: number) => {
              Column({ space: 4 }) {
                if (ChatService.shouldShowTimestamp(this.messages, index ?? 0)) {
                  Text(ChatService.formatTimestamp(message.timestamp))
                    .fontSize(11)
                    .fontColor(this.theme_TEXT_TERTIARY)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 4, bottom: 4 })
                }
                Row() {
                  if (message.sender === 'remote') {
                    this.buildMessageBubble(message, false)
                    Blank().layoutWeight(1)
                  } else {
                    Blank().layoutWeight(1)
                    this.buildMessageBubble(message, true)
                  }
                }
                .width('100%')
              }
              .width('100%')
            }, (message: ChatMessage) => message.id)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 56 + 40, bottom: 160 })
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      if (this.isDragging) {
        this.buildDragOverlay()
      }

      Column() {
        PageHeader(this.lt('Chat'), `${this.deviceName} · ${DeviceIdFormatter.format(this.deviceId)}`, true, () => {
          this.goBack();
        })
      }
      .padding({ top: this.avoidStatusBarHeight })
      .backgroundColor(this.themeIsDark ? '#402D3139' : '#40F8FAFC')

      Column() {
        Blank().layoutWeight(1)
        this.buildSessionStrip()
        this.buildQuickReplies()
        this.buildActionBar()
        this.buildInputBar()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme_GRAY_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onDrop((event: DragEvent) => {
      this.handleDrop(event);
    })
    .onDragEnter(() => {
      this.isDragging = true;
    })
    .onDragLeave(() => {
      this.isDragging = false;
    })
  }

  @Builder
  private buildDragOverlay() {
    Column() {
      Column({ space: 16 }) {
        Image($rawfile('file.svg'))
          .width(64)
          .height(64)
          .fillColor(this.theme_ACCENT)
        
        Text(this.lt('Drop files to send'))
          .fontSize(18)
          .fontColor(this.theme_TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
        
        if (this.dragFiles.length > 0) {
          Column({ space: 8 }) {
            ForEach(this.dragFiles, (file: DragFileInfo) => {
              Row() {
                Image($rawfile('file.svg'))
                  .width(20)
                  .height(20)
                  .fillColor(this.theme_TEXT_SECONDARY)
                Text(file.name)
                  .fontSize(14)
                  .fontColor(this.theme_TEXT_SECONDARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text(ChatService.formatFileSize(file.size))
                  .fontSize(12)
                  .fontColor(this.theme_TEXT_TERTIARY)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.theme_CARD_BG)
              .borderRadius(8)
            })
          }
          .width('80%')
          .constraintSize({ maxHeight: 150 })
        }
      }
      .width('80%')
      .padding(32)
      .backgroundColor(this.theme_INPUT_BG)
      .borderRadius(16)
      .border({ width: 2, color: this.theme_ACCENT, style: BorderStyle.Dashed })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildSessionStrip() {
    Row({ space: 8 }) {
      this.buildInfoPill(`${this.lt('Message')} ${this.messages.length}`, this.theme_ACCENT)
      this.buildInfoPill(`${this.lt('Unread')} ${this.unreadCount}`, this.theme_ACCENT)
      this.buildInfoPill(this.lt('Text safe channel only'), this.theme_ACCENT)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 8 })
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildInfoPill(label: string, color: string) {
    Text(label)
      .fontSize(11)
      .fontColor(this.theme_ACCENT_TEXT)
      .backgroundColor(color)
      .borderRadius(999)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
  }

  @Builder
  private buildQuickReplies() {
    Row({ space: 8 }) {
      this.buildQuickReply(this.lt('Processing'), this.lt('Processing content'))
      this.buildQuickReply(this.lt('Wait'), this.lt('Wait content'))
      this.buildQuickReply(this.lt('Switch to file'), this.lt('Switch to file content'))
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 4 })
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildQuickReply(label: string, content: string) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(11)
      .backgroundColor(this.theme_CARD_BG)
      .fontColor(this.theme_ACCENT)
      .borderRadius(16)
      .onClick(() => {
        this.draft = content;
      })
  }

  @Builder
  private buildActionBar() {
    Row({ space: 8 }) {
      this.buildActionButton($rawfile('message_24dp_5F6368.svg'), this.lt('System Note'), this.theme_INPUT_BG, this.theme_CONTRAST_TEXT, () => {
        this.chatService.sendSystemMessage(this.deviceId, this.lt('Local note: entered support session.'));
        this.refreshMessages();
      })
      this.buildActionButton($rawfile('file.svg'), this.lt('File Reference'), this.theme_ACCENT, this.theme_ACCENT_TEXT, () => {
        void this.sendFileReference();
      })
      this.buildActionButton($rawfile('trash.svg'), this.lt('Clear Chat'), this.theme_ERROR_TEXT, this.theme_CONTRAST_TEXT, () => {
        this.chatService.clearMessages(this.deviceId);
        this.refreshMessages();
      })
    }
    .padding({ left: 16, right: 16, top: 4, bottom: 8 })
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildActionButton(icon: Resource, label: string, color: string, fontColor: string, action: () => void) {
    Button() {
      Row({ space: 4 }) {
        Image(icon)
          .width(14)
          .height(14)
          .colorFilter(createStrokeIconColorFilter(fontColor))
        Text(label)
          .fontSize(11)
          .fontColor(fontColor)
      }
    }
    .layoutWeight(1)
    .height(34)
    .backgroundColor(color)
    .borderRadius(12)
    .onClick(action)
  }

  @Builder
  private buildInputBar() {
    Row({ space: 8 }) {
      Row() {
        Image($rawfile('chat2.svg'))
          .width(18)
          .height(18)
          .colorFilter(createStrokeIconColorFilter(this.theme_TEXT_TERTIARY))
          .margin({ right: 8 })
        TextInput({ placeholder: this.lt('Input message'), text: this.draft })
          .layoutWeight(1)
          .height(34)
          .fontSize(15)
          .fontColor(this.theme_TEXT_PRIMARY)
          .placeholderColor(this.theme_TEXT_TERTIARY)
          .backgroundColor('transparent')
          .borderRadius(0)
          .padding({ left: 0, right: 0 })
          .onChange((value: string) => {
            this.draft = value;
          })
      }
      .layoutWeight(1)
      .height(44)
      .backgroundColor(this.theme_CARD_BG)
      .borderRadius(12)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Button() {
        Row({ space: 4 }) {
          Image($rawfile('arrow.svg'))
            .width(14)
            .height(14)
            .fillColor(this.theme_ACCENT_TEXT)
            .rotate({ angle: 90 })
          Text(this.lt('Send'))
            .fontSize(13)
            .fontColor(this.theme_ACCENT_TEXT)
        }
      }
      .width(84)
      .height(44)
      .backgroundColor(this.theme_ACCENT)
      .borderRadius(12)
      .onClick(() => {
        this.sendMessage();
      })
    }
    .padding(16)
    .backgroundColor(this.theme_INPUT_BG)
  }

  @Builder
  private buildMessageBubble(message: ChatMessage, local: boolean) {
    Column({ space: 6 }) {
      Text(this.getMessageTypeLabel(message))
        .fontSize(11)
        .fontColor(local ? this.theme_TEXT_SECONDARY : this.theme_TEXT_TERTIARY)

      Text(this.getMessageBody(message))
        .fontSize(14)
        .fontColor(local ? this.theme_ACCENT_TEXT : this.theme_TEXT_PRIMARY)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor(local ? this.theme_ACCENT : this.theme_CARD_BG)
    .borderRadius(18)
    .width('76%')
  }

  private getMessageTypeLabel(message: ChatMessage): string {
    if (message.type === ChatMessageType.FILE) {
      return this.lt('File');
    }
    if (message.type === ChatMessageType.SYSTEM) {
      return this.lt('System');
    }
    return message.sender === 'local' ? this.lt('Me') : this.lt('Other');
  }

  private getMessageBody(message: ChatMessage): string {
    if (message.type === ChatMessageType.FILE) {
      const size = message.fileSize ? ChatService.formatFileSize(message.fileSize) : '';
      return `${message.fileName ?? this.lt('Attachment')} ${size}`.trim();
    }
    return message.content;
  }

  private sendMessage(): void {
    const text = this.draft.trim();
    if (text.length === 0) {
      return;
    }
    this.draft = '';
    void this.chatService.sendTextMessage(this.deviceId, text).then(() => {
      this.refreshMessages();
    }).catch(() => {
      this.draft = text;
      console.error('send chat message failed');
    });
  }

  private async sendFileReference(): Promise<void> {
    try {
      const authorization = await PermissionService.getInstance().requestFileAuthorization({ maxSelectNumber: 1 });
      if (!authorization.granted || authorization.uris.length === 0) {
        return;
      }
      const uri = authorization.uris[0];
      await this.chatService.sendFileMessage(this.deviceId, uri, this.extractFileName(uri), 0);
      this.refreshMessages();
      this.scheduleChatScroll(50);
    } catch (error) {
      console.error('Send file reference failed:', JSON.stringify(error));
    }
  }

  private refreshMessages(): void {
    this.messages = this.chatService.getMessages(this.deviceId);
    this.unreadCount = this.chatService.getUnreadCount(this.deviceId);
    this.chatService.markAsRead(this.deviceId);
  }

  private scheduleChatScroll(delayMs: number): void {
    [0, delayMs, delayMs + 80, delayMs + 180].forEach((delay: number) => {
      setTimeout(() => {
        this.chatScroller.scrollEdge(Edge.Bottom);
      }, Math.max(0, delay));
    });
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

  private handleDrop(_event: DragEvent): void {
    this.isDragging = false;
    console.info('Drag and drop not fully supported in this version');
  }

  private async sendDroppedFile(file: DragFileInfo): Promise<void> {
    try {
      await this.chatService.sendFileMessage(
        this.deviceId,
        file.uri,
        file.name,
        file.size
      );
      this.refreshMessages();
    } catch (error) {
      console.error('Send dropped file failed:', JSON.stringify(error));
    }
  }

  private extractFileName(uri: string): string {
    if (!uri) {
      return 'Unknown file';
    }
    
    const lastSlash = uri.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < uri.length - 1) {
      return decodeURIComponent(uri.substring(lastSlash + 1));
    }
    
    return uri;
  }
}
