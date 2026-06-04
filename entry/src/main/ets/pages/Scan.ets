import customScan from '@hms.core.scan.customScan';
import scanCore from '@hms.core.scan.scanCore';
import type scanBarcode from '@hms.core.scan.scanBarcode';
import { AppDataService } from '../services/AppDataService';
import { ClipboardService } from '../services/ClipboardService';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';
import { I18nService } from '../services/I18nService';
import { PermissionService, PermissionStatus } from '../services/PermissionService';

@Entry
@Component
struct Scan {
  private appData: AppDataService = AppDataService.getInstance();
  private clipboardService: ClipboardService = ClipboardService.getInstance();
  private xComponentController: XComponentController = new XComponentController();
  private surfaceId: string = '';

  @State scanResult: string = '';
  @State status: string = '';
  @State isScanning: boolean = false;
  @State hasCameraPermission: boolean = false;
  @State surfaceWidth: number = 1080;
  @State surfaceHeight: number = 1920;
  @StorageProp('avoidStatusBarHeight') avoidStatusBarHeight: number = 0;
  @StorageProp('avoidNavigationBarHeight') avoidNavigationBarHeight: number = 0;
  @StorageProp('i18nVersion') @Watch('onI18nVersionChanged') i18nRefresh: number = 0;
  @State i18nVersion: number = 0;

  aboutToAppear(): void {
    this.status = this.lt('Waiting for camera...');
    void this.prepareCameraScan();
  }

  aboutToDisappear(): void {
    void this.stopScan(true);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({
        id: 'rustdesk_qr_scan_view',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .onLoad(() => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId();
          void this.startCustomScan();
        })
        .onDestroy(() => {
          this.surfaceId = '';
          void this.stopScan(true);
        })
        .onAreaChange((_oldValue, newValue) => {
          const width = Number(newValue.width);
          const height = Number(newValue.height);
          if (width > 0) {
            this.surfaceWidth = vp2px(width);
          }
          if (height > 0) {
            this.surfaceHeight = vp2px(height);
          }
        })

      Column() {
        Row() {
          Button('<')
            .width(44)
            .height(44)
            .fontSize(24)
            .fontColor('#FFFFFF')
            .backgroundColor('#66000000')
            .borderRadius(22)
            .onClick(() => {
              this.goBack();
            })
          Blank()
          Text(this.lt('Scan'))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank()
            .width(44)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })

        Blank()

        this.buildScanFrame()

        Blank()

        this.buildResultPanel()
      }
      .width('100%')
      .height('100%')
      .padding({
        top: this.avoidStatusBarHeight,
        bottom: this.avoidNavigationBarHeight + 18
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildScanFrame() {
    Stack() {
      Column() {
        Row() {
          this.buildCorner(true, true)
          Blank()
          this.buildCorner(false, true)
        }
        .width('100%')
        Blank()
        Row() {
          this.buildCorner(true, false)
          Blank()
          this.buildCorner(false, false)
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')

      if (this.isScanning) {
        Text(this.lt('Scanning...'))
          .fontSize(14)
          .fontColor('#FFFFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#66000000')
          .borderRadius(14)
      } else {
        Text(this.status)
          .fontSize(14)
          .fontColor('#FFFFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#66000000')
          .borderRadius(14)
      }
    }
    .width(260)
    .height(260)
  }

  @Builder
  private buildCorner(left: boolean, top: boolean) {
    Stack() {
      Rect()
        .width(44)
        .height(5)
        .fill('#FFFFFFFF')
        .position({ x: 0, y: top ? 0 : 39 })
      Rect()
        .width(5)
        .height(44)
        .fill('#FFFFFFFF')
        .position({ x: left ? 0 : 39, y: 0 })
    }
    .width(44)
    .height(44)
  }

  @Builder
  private buildResultPanel() {
    Column({ space: 14 }) {
      Text(this.scanResult.length > 0 ? this.scanResult : this.status)
        .width('100%')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontSize(14)
        .fontColor('#FFFFFFFF')
        .textAlign(TextAlign.Center)

      Row({ space: 12 }) {
        Button(this.lt('Rescan'))
          .layoutWeight(1)
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#0071FF')
          .borderRadius(8)
          .onClick(() => {
            void this.rescan();
          })

        Button(this.lt('Copy scanned content'))
          .layoutWeight(1)
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#4DFFFFFF')
          .borderRadius(8)
          .enabled(this.scanResult.length > 0)
          .onClick(() => {
            void this.copyScanResult();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }

  private async prepareCameraScan(): Promise<void> {
    const permission = PermissionService.getInstance();
    let status = await permission.checkPermission('ohos.permission.CAMERA');
    if (status !== PermissionStatus.GRANTED) {
      status = await permission.requestPermission('ohos.permission.CAMERA');
    }
    this.hasCameraPermission = status === PermissionStatus.GRANTED;
    this.status = this.hasCameraPermission ? this.lt('Waiting for camera...') : this.lt('Camera permission denied');
    if (this.hasCameraPermission) {
      void this.startCustomScan();
    }
  }

  private async startCustomScan(): Promise<void> {
    if (!this.hasCameraPermission || this.isScanning || this.surfaceId.length === 0) {
      return;
    }

    try {
      customScan.init({
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: false
      });
      this.scanResult = '';
      this.status = this.lt('Scanning...');
      this.isScanning = true;
      customScan.start({
        surfaceId: this.surfaceId,
        width: Math.max(1, Math.floor(this.surfaceWidth)),
        height: Math.max(1, Math.floor(this.surfaceHeight))
      }, (error, results: Array<scanBarcode.ScanResult>) => {
        if (error) {
          console.error('custom scan failed: ' + JSON.stringify(error));
          this.status = this.lt('Scan failed, try again.');
          this.isScanning = false;
          return;
        }
        this.handleScanResults(results);
      });
    } catch (error) {
      console.error('start custom scan failed: ' + JSON.stringify(error));
      this.status = this.lt('Scan failed, try again.');
      this.isScanning = false;
    }
  }

  private handleScanResults(results: Array<scanBarcode.ScanResult>): void {
    if (!results || results.length === 0) {
      return;
    }

    const value = results[0].originalValue.trim();
    if (value.length === 0) {
      return;
    }

    this.scanResult = value;
    this.status = this.lt('Scan complete');
    this.isScanning = false;
    void this.stopScan(false);
    this.applyScanResult(value);
  }

  private async rescan(): Promise<void> {
    this.scanResult = '';
    this.status = this.lt('Scanning...');
    try {
      customScan.rescan();
      this.isScanning = true;
    } catch (error) {
      console.warn('custom scan rescan failed, restarting: ' + JSON.stringify(error));
      await this.stopScan(false);
      await this.startCustomScan();
    }
  }

  private async stopScan(release: boolean): Promise<void> {
    try {
      await customScan.stop();
    } catch (error) {
      console.warn('stop custom scan skipped: ' + JSON.stringify(error));
    }

    if (release) {
      try {
        await customScan.release();
      } catch (error) {
        console.warn('release custom scan skipped: ' + JSON.stringify(error));
      }
    }
    this.isScanning = false;
  }

  private async copyScanResult(): Promise<void> {
    if (this.scanResult.length === 0) {
      return;
    }
    const success = await this.clipboardService.copyText(this.scanResult);
    await this.showToast(success ? this.lt('Scanned content copied') : this.lt('Copy failed'));
  }

  private applyScanResult(value: string): void {
    const deviceId = this.extractDeviceId(value);
    if (!this.isPlausibleDeviceId(deviceId)) {
      return;
    }

    this.appData.addRecentSession(this.appData.createRecentSession(deviceId));
    this.appData.addAddressBookEntry({
      id: deviceId,
      alias: `${this.lt('Remote Device')} ${DeviceIdFormatter.format(deviceId)}`,
      note: this.lt('Scan import'),
      group: this.lt('Scan import'),
      online: true,
      favorite: false,
      platform: ''
    });
  }

  private extractDeviceId(text: string): string {
    const pure = text.replace('rustdesk://', '').replaceAll('/', '').replaceAll('@', '');
    let digits = '';
    for (let index = 0; index < pure.length; index++) {
      const char = pure.charAt(index);
      if (char >= '0' && char <= '9') {
        digits += char;
      }
    }
    return digits;
  }

  private isPlausibleDeviceId(id: string): boolean {
    return id.length >= 6 && id.length <= 18;
  }

  private async showToast(message: string): Promise<void> {
    try {
      await this.getUIContext().getPromptAction().openToast({ message });
    } catch (error) {
      console.warn('scan toast failed: ' + JSON.stringify(error));
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
