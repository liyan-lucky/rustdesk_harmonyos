import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { AppContextService } from '../services/AppContextService';
import { AppDataService } from '../services/AppDataService';
import { NativeRustDeskBridge } from '../services/NativeRustDeskBridge';
import { CoreLoaderService } from '../services/CoreLoaderService';
import { PreferenceStore } from '../services/PreferenceStore';
import { DeviceIdGenerator } from '../network/DeviceIdGenerator';
import util from '@ohos.util';

import { ThemeManager } from '../common/ThemeConfig';
import { WindowChromeService } from '../services/WindowChromeService';
import { I18nService } from '../services/I18nService';
import Configuration from '@ohos.app.ability.Configuration';

export default class EntryAbility extends UIAbility {
  private coreLoadAttempted: boolean = false;

  onCreate(want: object, launchParam: object): void {
    console.info('EntryAbility onCreate');
    AppContextService.setContext(this.context);
    AppDataService.getInstance().initialize();
    const settings = AppDataService.getInstance().getSettings();
    this.initColorMode();
    ThemeManager.getInstance().applyStoredTheme(settings.theme);
    I18nService.getInstance();
  }

  private initColorMode(): void {
    try {
      const config: Record<string, Object> = this.context.config as Record<string, Object>;
      const colorMode: number = (config['colorMode'] as number) ?? 1;
      const isDark = colorMode === 0;
      console.info(`initColorMode: colorMode=${colorMode}, isDark=${isDark}`);
      AppStorage.setOrCreate<string>('colorMode', isDark ? 'dark' : 'light');
      ThemeManager.getInstance().refreshSystemTheme();
    } catch (e) {
      console.error('initColorMode failed: ' + JSON.stringify(e));
      AppStorage.setOrCreate<string>('colorMode', 'light');
    }
  }

  onConfigurationUpdated(newConfig: Configuration): void {
    try {
      const rawMode: string | number = newConfig.colorMode ?? 1;
      const colorMode: number = typeof rawMode === 'number' ? rawMode : parseInt(rawMode, 10);
      const isDark = colorMode === 0;
      AppStorage.setOrCreate<string>('colorMode', isDark ? 'dark' : 'light');
      ThemeManager.getInstance().refreshSystemTheme();
      void WindowChromeService.getInstance().refreshSystemBars();
      I18nService.getInstance().onSystemLocaleChanged();
    } catch (e) {
      console.error('onConfigurationUpdated failed');
    }
  }

  onDestroy(): void {
    console.info('EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    console.info('EntryAbility onWindowStageCreate');

    const ctx = this.context as Object as Record<string, Object | undefined>;
    console.info(`[EntryAbility] context paths: filesDir=${String(ctx.filesDir ?? '')}, cacheDir=${String(ctx.cacheDir ?? '')}, tempDir=${String(ctx.tempDir ?? '')}, distributedFilesDir=${String(ctx.distributedFilesDir ?? '')}`);

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('Failed to load the content. Cause: ' + JSON.stringify(err));
        return;
      }
      console.info('Succeeded in loading the content.');
      this.setWindowBackgroundColor(windowStage);
      WindowChromeService.getInstance().setWindowStage(windowStage);
    });

    void this.bootstrapCoreAndRuntime();
  }

  private setWindowBackgroundColor(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      const isDark = ThemeManager.getInstance().getIsDark();
      const bgColor = isDark ? '#171A22' : '#F8FAFC';
      mainWindow.setWindowBackgroundColor(bgColor);
    } catch (error) {
      console.error('setWindowBackgroundColor failed: ' + JSON.stringify(error));
    }
  }

  private setWindowBarColors(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(false);
      const isDark = ThemeManager.getInstance().getIsDark();
      const barColor = isDark ? '#171A22' : '#F8FAFC';
      void mainWindow.setWindowSystemBarProperties({
        statusBarColor: barColor,
        navigationBarColor: barColor
      });
    } catch (error) {
      console.error('setWindowBarColors failed: ' + JSON.stringify(error));
    }
  }

  onWindowStageDestroy(): void {
    console.info('EntryAbility onWindowStageDestroy');
    WindowChromeService.getInstance().clearWindowStage();
  }

  onForeground(): void {
    console.info('EntryAbility onForeground');
    this.initColorMode();
    ThemeManager.getInstance().refreshSystemTheme();
    if (!this.coreLoadAttempted) {
      void this.bootstrapCoreAndRuntime();
    }
    void WindowChromeService.getInstance().refreshSystemBars();
  }

  onBackground(): void {
    console.info('EntryAbility onBackground');
  }

  private async bootstrapCoreAndRuntime(): Promise<void> {
    if (this.coreLoadAttempted) {
      console.info('[EntryAbility] Core bootstrap already attempted');
      return;
    }
    this.coreLoadAttempted = true;

    const appDir = this.getAppDir();
    if (appDir.length === 0) {
      console.warn('[EntryAbility] filesDir unavailable, deferring bootstrap');
      this.coreLoadAttempted = false;
      return;
    }

    console.info('[EntryAbility] Starting core bootstrap...');

    const loader = CoreLoaderService.getInstance();
    const loadResult = await loader.autoLoadCore();

    if (loadResult.success) {
      console.info(`[EntryAbility] Core loaded: source=${loadResult.source}, path=${loadResult.path}`);
      AppStorage.setOrCreate<boolean>('coreLoaded', true);
      AppStorage.setOrCreate<string>('coreSource', loadResult.source);
    } else {
      console.warn(`[EntryAbility] Core load failed: ${loadResult.error ?? 'unknown'}`);
      AppStorage.setOrCreate<boolean>('coreLoaded', false);
    }

    this.initializeAfterCoreLoad(appDir);
  }

  private getAppDir(): string {
    const contextRecord = this.context as Object as Record<string, string | undefined>;
    return typeof contextRecord.filesDir === 'string' ? contextRecord.filesDir.trim() : '';
  }

  private initializeAfterCoreLoad(appDir: string): void {
    const appData = AppDataService.getInstance();
    const appSettings = appData.getSettings();
    const serverConfig = AppDataService.resolveServerConfig(appSettings);

    const snapshot =
      NativeRustDeskBridge.initializeRuntime(appDir, '') ??
      NativeRustDeskBridge.readSnapshot(serverConfig.idServer);

    if (!snapshot) {
      console.warn('[EntryAbility] Bootstrap produced no snapshot.');
      return;
    }

    try {
      PreferenceStore.setOfficialCoreSnapshot(JSON.stringify(snapshot));
    } catch (error) {
      console.error('[EntryAbility] Snapshot persist failed: ' + JSON.stringify(error));
    }

    console.info(
      '[EntryAbility] Bootstrap snapshot: ' +
        JSON.stringify({
          adapter: snapshot.adapter ?? '',
          coreReady: snapshot.coreReady ?? false,
          incomingReady: snapshot.incomingReady ?? false,
          sessionStage: snapshot.sessionStage ?? '',
          displayId: snapshot.displayId ?? '',
          lastError: snapshot.lastError ?? '',
          statusSummary: snapshot.statusSummary ?? ''
        })
    );

    AppStorage.setOrCreate<boolean>('coreReady', snapshot.coreReady ?? false);

    this.ensureDeviceIdentity();
  }

  private async ensureDeviceIdentity(): Promise<void> {
    let id = NativeRustDeskBridge.getLocalOption('id').trim();
    if (id.length === 0) {
      const generator = DeviceIdGenerator.getInstance();
      id = await generator.generateDeviceId();
      NativeRustDeskBridge.setLocalOption('id', id);
    }
    AppStorage.setOrCreate<string>('myDeviceId', id);

    let uuid = NativeRustDeskBridge.getLocalOption('uuid').trim();
    if (uuid.length === 0) {
      uuid = util.generateRandomUUID(true);
      NativeRustDeskBridge.setLocalOption('uuid', uuid);
    }
    AppStorage.setOrCreate<string>('myDeviceUuid', uuid);
  }
}
