import window from '@ohos.window';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { ThemeConfig, ThemeManager } from '../common/ThemeConfig';

export class WindowChromeService {
  private static instance: WindowChromeService;
  private windowStage?: window.WindowStage;
  private avoidAreaCallbackRegistered: boolean = false;
  private lockedStatusBarHeight: number = -1;
  private lockedNavigationBarHeight: number = -1;

  static getInstance(): WindowChromeService {
    if (!WindowChromeService.instance) {
      WindowChromeService.instance = new WindowChromeService();
    }
    return WindowChromeService.instance;
  }

  setWindowStage(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    void this.initWindowMode();
  }

  clearWindowStage(): void {
    this.unregisterAvoidAreaCallback();
    this.windowStage = undefined;
  }

  getStatusBarHeight(): number {
    return this.lockedStatusBarHeight >= 0 ? this.lockedStatusBarHeight : 0;
  }

  getNavigationBarHeight(): number {
    return this.lockedNavigationBarHeight >= 0 ? this.lockedNavigationBarHeight : 0;
  }

  enterImmersiveMode(): void {
    this.applyWindowMode(true);
  }

  exitImmersiveMode(): void {
    this.applyWindowMode(false);
  }

  setLandscape(landscape: boolean): void {
    if (!this.windowStage) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      if (landscape) {
        mainWindow.setPreferredOrientation(window.Orientation.LANDSCAPE);
      } else {
        mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT);
      }
    } catch (e) {
      console.warn(`WindowChromeService setLandscape failed: ${JSON.stringify(e)}`);
    }
  }

  async setKeepScreenOn(enabled: boolean): Promise<void> {
    const maxRetries = 3;
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      if (!this.windowStage) {
        hilog.error(0xA03D00, 'WindowChrome', `setKeepScreenOn: windowStage is null, retry ${attempt + 1}/${maxRetries} enabled=${enabled}`);
        await new Promise<void>(resolve => setTimeout(resolve, 500));
        continue;
      }
      try {
        const mainWindow = this.windowStage.getMainWindowSync();
        hilog.error(0xA03D00, 'WindowChrome', `setKeepScreenOn: calling setWindowKeepScreenOn(${enabled}) attempt=${attempt + 1}`);
        await mainWindow.setWindowKeepScreenOn(enabled);
        hilog.error(0xA03D00, 'WindowChrome', `setKeepScreenOn: success enabled=${enabled}`);
        AppStorage.setOrCreate<boolean>('debugKeepScreenAwakeActive', enabled);
        return;
      } catch (error) {
        hilog.error(0xA03D00, 'WindowChrome', `setKeepScreenOn attempt ${attempt + 1} failed: ${JSON.stringify(error)}`);
        if (attempt < maxRetries - 1) {
          await new Promise<void>(resolve => setTimeout(resolve, 300));
        }
      }
    }
    hilog.error(0xA03D00, 'WindowChrome', `setKeepScreenOn: all retries exhausted enabled=${enabled}`);
  }

  private pxToVp(px: number): number {
    let densityDpi = 480;
    try {
      const disp = display.getDefaultDisplaySync();
      densityDpi = disp.densityDPI;
    } catch (_e) {
      console.warn('WindowChromeService getDefaultDisplaySync failed, fallback densityDpi=480');
    }
    const densityFactor = densityDpi / 160;
    return Math.round(px / densityFactor);
  }

  private lockAndApplyHeights(topVp: number, bottomVp: number): void {
    if (this.lockedStatusBarHeight < 0 && topVp >= 0) {
      this.lockedStatusBarHeight = topVp;
    }
    if (this.lockedNavigationBarHeight < 0 && bottomVp > 0) {
      this.lockedNavigationBarHeight = bottomVp;
    }
    AppStorage.setOrCreate<number>('avoidStatusBarHeight', this.lockedStatusBarHeight >= 0 ? this.lockedStatusBarHeight : 0);
    AppStorage.setOrCreate<number>('avoidNavigationBarHeight', this.lockedNavigationBarHeight >= 0 ? this.lockedNavigationBarHeight : 0);
  }

  private registerAvoidAreaCallback(): void {
    if (!this.windowStage || this.avoidAreaCallbackRegistered) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          const topVp = this.pxToVp(data.area.topRect.height);
          const bottomVp = this.pxToVp(data.area.bottomRect.height);
          if (this.lockedStatusBarHeight < 0 && topVp >= 0) {
            this.lockedStatusBarHeight = topVp;
          }
          if (this.lockedNavigationBarHeight < 0 && bottomVp > 0) {
            this.lockedNavigationBarHeight = bottomVp;
          }
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          const bottomVp = this.pxToVp(data.area.bottomRect.height);
          if (this.lockedNavigationBarHeight < 0 && bottomVp > 0) {
            this.lockedNavigationBarHeight = bottomVp;
          }
        } else if (data.type === window.AvoidAreaType.TYPE_KEYBOARD) {
          const keyboardHeightVp = this.pxToVp(data.area.bottomRect.height);
          console.info(`WindowChromeService TYPE_KEYBOARD avoidArea: height=${keyboardHeightVp}vp`);
          AppStorage.setOrCreate<number>('avoidKeyboardHeight', keyboardHeightVp > 0 ? keyboardHeightVp : 0);
        }
      });
      this.avoidAreaCallbackRegistered = true;
      console.info('WindowChromeService avoidAreaChange callback registered (values locked, no redraw)');
      try {
        mainWindow.on('keyboardHeightChange', (height: number) => {
          const heightVp = this.pxToVp(height);
          console.info(`WindowChromeService keyboardHeightChange: px=${height} vp=${heightVp}`);
          AppStorage.setOrCreate<number>('avoidKeyboardHeight', heightVp > 0 ? heightVp : 0);
        });
        console.info('WindowChromeService keyboardHeightChange listener registered');
      } catch (e) {
        console.warn('WindowChromeService keyboardHeightChange failed: ' + JSON.stringify(e));
      }
    } catch (error) {
      console.error('WindowChromeService registerAvoidAreaCallback failed: ' + JSON.stringify(error));
    }
  }

  private unregisterAvoidAreaCallback(): void {
    if (!this.windowStage || !this.avoidAreaCallbackRegistered) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      mainWindow.off('avoidAreaChange');
      this.avoidAreaCallbackRegistered = false;
      console.info('WindowChromeService avoidAreaChange callback unregistered');
    } catch (error) {
      console.error('WindowChromeService unregisterAvoidAreaCallback failed: ' + JSON.stringify(error));
    }
  }

  private applyWindowMode(hideSystemBars: boolean): void {
    if (!this.windowStage) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      const grayBg = AppStorage.get<string>('theme_GRAY_BG') ?? ThemeConfig.GRAY_BG;
      const statusBarBg = '#00000000';
      if (hideSystemBars) {
        void mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#00000000',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#00000000',
          isStatusBarLightIcon: false
        });
      } else {
        const textPrimary = AppStorage.get<string>('theme_TEXT_PRIMARY') ?? ThemeConfig.TEXT_PRIMARY;
        void mainWindow.setWindowSystemBarProperties({
          statusBarColor: statusBarBg,
          statusBarContentColor: textPrimary,
          navigationBarColor: '#00000000',
          navigationBarContentColor: textPrimary
        });
      }
      mainWindow.setWindowBackgroundColor(grayBg);
    } catch (error) {
      console.error('WindowChromeService applyWindowMode failed: ' + JSON.stringify(error));
    }
  }

  private async initWindowMode(): Promise<void> {
    if (!this.windowStage) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      const systemAvoidArea = await mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topVp = this.pxToVp(systemAvoidArea.topRect.height);
      const sysBottomVp = this.pxToVp(systemAvoidArea.bottomRect.height);
      let navBottomVp = sysBottomVp;
      try {
        const navAvoidArea = await mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        const indicatorVp = this.pxToVp(navAvoidArea.bottomRect.height);
        if (indicatorVp > navBottomVp) {
          navBottomVp = indicatorVp;
        }
      } catch (navError) {
        console.warn('WindowChromeService getWindowAvoidArea TYPE_NAVIGATION_INDICATOR failed: ' + JSON.stringify(navError));
      }
      this.lockAndApplyHeights(topVp, navBottomVp);
      console.info(`WindowChromeService locked: statusBar=${this.lockedStatusBarHeight}, navigationBar=${this.lockedNavigationBarHeight}`);
      const textPrimary = AppStorage.get<string>('theme_TEXT_PRIMARY') ?? ThemeConfig.TEXT_PRIMARY;
      const grayBg = AppStorage.get<string>('theme_GRAY_BG') ?? ThemeConfig.GRAY_BG;
      void mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: textPrimary,
        navigationBarColor: '#00000000',
        navigationBarContentColor: textPrimary
      });
      mainWindow.setWindowBackgroundColor(grayBg);
      this.registerAvoidAreaCallback();
      ThemeManager.getInstance().refreshSystemTheme();
    } catch (error) {
      console.error('WindowChromeService initWindowMode failed: ' + JSON.stringify(error));
    }
  }

  async refreshSystemBars(): Promise<void> {
    if (!this.windowStage) {
      return;
    }
    try {
      const mainWindow = this.windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      if (this.lockedStatusBarHeight < 0 || this.lockedNavigationBarHeight < 0) {
        const systemAvoidArea = await mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const topVp = this.pxToVp(systemAvoidArea.topRect.height);
        const sysBottomVp = this.pxToVp(systemAvoidArea.bottomRect.height);
        let navBottomVp = sysBottomVp;
        try {
          const navAvoidArea = await mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          const indicatorVp = this.pxToVp(navAvoidArea.bottomRect.height);
          if (indicatorVp > navBottomVp) {
            navBottomVp = indicatorVp;
          }
        } catch (_navError) {
        }
        this.lockAndApplyHeights(topVp, navBottomVp);
        console.info(`WindowChromeService refreshSystemBars locked: statusBar=${this.lockedStatusBarHeight}, navigationBar=${this.lockedNavigationBarHeight}`);
      }
      void mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: AppStorage.get<string>('theme_TEXT_PRIMARY') ?? ThemeConfig.TEXT_PRIMARY,
        navigationBarColor: '#00000000',
        navigationBarContentColor: AppStorage.get<string>('theme_TEXT_PRIMARY') ?? ThemeConfig.TEXT_PRIMARY
      });
      const grayBg = AppStorage.get<string>('theme_GRAY_BG') ?? ThemeConfig.GRAY_BG;
      mainWindow.setWindowBackgroundColor(grayBg);
      if (!this.avoidAreaCallbackRegistered) {
        this.registerAvoidAreaCallback();
      }
      ThemeManager.getInstance().refreshSystemTheme();
    } catch (error) {
      console.error('WindowChromeService refreshSystemBars failed: ' + JSON.stringify(error));
    }
  }
}
