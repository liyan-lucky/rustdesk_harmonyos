import { ThemeConfig } from '../common/ThemeConfig';
import { createStrokeIconColorFilter } from '../common/CommonComponents';
import {
  CardContainer,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  SectionTitle,
  InfoRow,
  StatusBadge
} from '../common/CommonComponents';
import { NativeRustDeskBridge, NativeVideoFrame } from '../services/NativeRustDeskBridge';
import image from '@ohos.multimedia.image';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { I18nService } from '../services/I18nService';

interface DeviceRouteParams {
  deviceId: string;
}

@Entry
@Component
struct ViewCamera {
  private deviceId: string = '';
  private frameRefreshTimer: number = -1;
  @State renderedFrame: image.PixelMap | null = null;
  private lastFrameId: number = 0;

  @State cameraStatus: string = '';
  @State isConnected: boolean = false;
  @State frameWidth: number = 0;
  @State frameHeight: number = 0;
  @State fps: number = 0;
  @State showControls: boolean = true;
  aboutToAppear() {
    this.cameraStatus = this.lt('Waiting for terminal session...');
    const params = this.getRouteParams();
    if (params !== null && params.deviceId !== undefined) {
      this.deviceId = params.deviceId;
    }
    this.startCameraStream();
    this.startFrameRefresh();
  }

  aboutToDisappear() {
    this.stopCameraStream();
    this.stopFrameRefresh();
    this.disposeRenderedFrame();
  }
  @StorageProp('theme_GRAY_BG') theme_GRAY_BG: string = '#171A22';
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;
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
        Column({ space: ThemeConfig.SPACING_MD }) {
          this.buildCameraPreview()

          if (this.showControls) {
            this.buildControls()
          }

          this.buildStatusCard()
        }
        .width('100%')
        .padding({ left: ThemeConfig.SPACING_MD, right: ThemeConfig.SPACING_MD, top: 56, bottom: this.avoidNavigationBarHeight + ThemeConfig.SPACING_MD })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Column() {
        PageHeader(this.lt('Remote Camera'), DeviceIdFormatter.format(this.deviceId), true, () => {
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
  private buildCameraPreview() {
    CardContainer() {
      Column({ space: ThemeConfig.SPACING_MD }) {
        Row() {
          SectionTitle(this.lt('Camera View'))
          StatusBadge(this.isConnected ? this.lt('Connected') : this.lt('Disconnected'), this.isConnected)
        }
        .width('100%')

        if (this.renderedFrame !== null) {
          Image(this.renderedFrame)
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
        } else {
          Column() {
            Image($rawfile('rec.svg'))
              .width(64)
              .height(64)
              .fillColor(this.theme_TEXT_TERTIARY)
            Text(this.lt('Waiting for camera...'))
              .fontSize(ThemeConfig.FONT_SIZE_MD)
              .fontColor(this.theme_TEXT_SECONDARY)
              .margin({ top: ThemeConfig.SPACING_MD })
          }
          .width('100%')
          .height(300)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme_INPUT_BG)
          .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
        }
      }
      .width('100%')
    }
  }

  @Builder
  private buildControls() {
    CardContainer() {
      Column({ space: ThemeConfig.SPACING_MD }) {
        SectionTitle(this.lt('Control'))

        Row({ space: ThemeConfig.SPACING_SM }) {
          if (this.isConnected) {
            SecondaryButton(this.lt('Disconnect'), () => {
              this.stopCameraStream();
            })
          } else {
            PrimaryButton(this.lt('Connect Camera'), () => {
              this.startCameraStream();
            })
          }

          Button(this.showControls ? this.lt('Hide Controls') : this.lt('Show Controls'))
            .layoutWeight(1)
            .height(44)
            .backgroundColor(this.theme_INPUT_BG)
            .fontColor(this.theme_TEXT_PRIMARY)
            .borderRadius(ThemeConfig.BORDER_RADIUS_MEDIUM)
            .onClick(() => {
              this.showControls = !this.showControls;
            })
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private buildStatusCard() {
    CardContainer() {
      Column({ space: ThemeConfig.SPACING_MD }) {
        SectionTitle(this.lt('Status Info'))

        InfoRow(this.lt('Device ID'), DeviceIdFormatter.format(this.deviceId))
        InfoRow(this.lt('Connection Status'), this.cameraStatus)
        if (this.frameWidth > 0 && this.frameHeight > 0) {
          InfoRow(this.lt('Resolution'), `${this.frameWidth}x${this.frameHeight}`)
        }
        if (this.fps > 0) {
          InfoRow(this.lt('FPS'), `${this.fps.toFixed(1)} FPS`)
        }
      }
      .width('100%')
    }
  }

  private startCameraStream(): void {
    if (this.deviceId.length === 0) {
      this.cameraStatus = this.lt('Device ID invalid');
      return;
    }
    this.isConnected = false;
    this.cameraStatus = this.lt('Camera entry unavailable');
  }

  private stopCameraStream(): void {
    this.isConnected = false;
    this.cameraStatus = this.lt('Camera disconnected');
    this.disposeRenderedFrame();
  }

  private startFrameRefresh(): void {
    if (this.frameRefreshTimer !== -1) {
      return;
    }
    this.frameRefreshTimer = setInterval(() => {
      void this.refreshRenderedFrame();
    }, 33);
  }

  private stopFrameRefresh(): void {
    if (this.frameRefreshTimer === -1) {
      return;
    }
    clearInterval(this.frameRefreshTimer);
    this.frameRefreshTimer = -1;
  }

  private async refreshRenderedFrame(): Promise<void> {
    if (!this.isConnected) {
      return;
    }
    const frameData = this.pullLatestRenderableFrame();
    if (frameData !== null && frameData.frameId !== this.lastFrameId) {
      this.lastFrameId = frameData.frameId;
      this.frameWidth = frameData.width;
      this.frameHeight = frameData.height;
      try {
        try {
          const nextFrame = image.createPixelMapSync(this.toHarmonyPixelBuffer(frameData.rgba, frameData.format), {
            size: {
              width: frameData.width,
              height: frameData.height
            },
            pixelFormat: image.PixelMapFormat.BGRA_8888,
            alphaType: image.AlphaType.UNPREMUL
          });
          const previousFrame = this.renderedFrame;
          this.renderedFrame = nextFrame;
          if (previousFrame !== null) {
            previousFrame.release();
          }
        } catch (error) {
          console.error('[ViewCamera] Failed to create PixelMap:', JSON.stringify(error));
        }
      } finally {
        NativeRustDeskBridge.harmonyNextRgba(frameData.display);
      }
    }
  }

  private pullLatestRenderableFrame(): NativeVideoFrame | null {
    const directFrame = NativeRustDeskBridge.pullLatestVideoFrame(this.lastFrameId);
    if (directFrame !== null) {
      return directFrame;
    }
    if (this.lastFrameId <= 0) {
      return null;
    }
    const latestFrame = NativeRustDeskBridge.pullLatestVideoFrame(0);
    if (latestFrame !== null && latestFrame.frameId > this.lastFrameId) {
      console.warn(
        `[ViewCamera] pullLatestVideoFrame fallback frameId=0 recovered frameId=${latestFrame.frameId} prev=${this.lastFrameId}`
      );
      return latestFrame;
    }
    return null;
  }

  private toHarmonyPixelBuffer(buffer: ArrayBuffer, format: string): ArrayBuffer {
    if (format === 'bgra' || format === 'argb') {
      return buffer;
    }
    if (format === 'abgr') {
      return this.swapRedBlueChannels(buffer);
    }
    return buffer;
  }

  private swapRedBlueChannels(buffer: ArrayBuffer): ArrayBuffer {
    const source = new Uint8Array(buffer);
    const converted = new Uint8Array(source.byteLength);
    for (let index = 0; index + 3 < source.length; index += 4) {
      converted[index] = source[index + 2];
      converted[index + 1] = source[index + 1];
      converted[index + 2] = source[index];
      converted[index + 3] = source[index + 3];
    }
    return converted.buffer;
  }

  private disposeRenderedFrame(): void {
    if (this.renderedFrame !== null) {
      this.renderedFrame.release();
      this.renderedFrame = null;
    }
  }

  private getRouteParams(): DeviceRouteParams | null {
    try {
      const router = this.getUIContext().getRouter();
      const params = router.getParams() as DeviceRouteParams;
      return params ?? null;
    } catch (error) {
      console.error('getRouteParams failed', JSON.stringify(error));
      return null;
    }
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
