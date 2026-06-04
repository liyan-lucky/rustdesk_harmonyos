
export type AppThemeMode = 'dark' | 'light' | 'system';
export type StoredThemeMode = 'light' | 'dark' | 'auto';

interface StatusColor {
  bg: string;
  text: string;
}

interface ThemeColors {
  GRAY_BG: string;
  ACCENT: string;
  ACCENT_50: string;
  ACCENT_80: string;
  CANVAS_COLOR: string;
  BORDER: string;
  ID_COLOR: string;
  DARK_GRAY: string;
  BUTTON: string;
  HOVER_BORDER: string;
  WHITE: string;
  BLACK: string;
  ACCENT_TEXT: string;
  CONTRAST_TEXT: string;
  TEXT_PRIMARY: string;
  TEXT_SECONDARY: string;
  TEXT_TERTIARY: string;
  SUCCESS_BG: string;
  SUCCESS_TEXT: string;
  ERROR_BG: string;
  ERROR_TEXT: string;
  WARNING_BG: string;
  WARNING_TEXT: string;
  INPUT_BG: string;
  ACCENT_SURFACE: string;
  BORDER_SUBTLE: string;
  BORDER_SOFT: string;
  SECONDARY_BTN_BG: string;
  SECONDARY_BTN_TEXT: string;
  CARD_BG: string;
  HEADER_BG: string;
  TAB_BAR_BG: string;
  DISABLED_TEXT: string;
  INACTIVE_BG: string;
  PANEL_BG: string;
  TOOLBAR_BG: string;
  OVERLAY_SEMI: string;
  OVERLAY_LIGHT: string;
  OVERLAY_FULL: string;
  ICON_FILL: string;
  ICON_BG: string;
  PROGRESS_COLOR: string;
  PROGRESS_BG: string;
  DIALOG_OVERLAY: string;
  SHADOW_COLOR: string;
  CARET_HIDDEN: string;
  INFO_BG: string;
  INFO_TEXT: string;
}

const DARK_COLORS: ThemeColors = {
  GRAY_BG: '#171A22',
  ACCENT: '#0071FF',
  ACCENT_50: '#770071FF',
  ACCENT_80: '#AA0071FF',
  CANVAS_COLOR: '#212121',
  BORDER: '#CCCCCC',
  ID_COLOR: '#00B6F0',
  DARK_GRAY: '#949494',
  BUTTON: '#2C8CFF',
  HOVER_BORDER: '#999999',
  WHITE: '#FFFFFF',
  BLACK: '#000000',
  ACCENT_TEXT: '#FFFFFF',
  CONTRAST_TEXT: '#F8FAFC',
  TEXT_PRIMARY: '#F8FAFC',
  TEXT_SECONDARY: '#AAB2C5',
  TEXT_TERTIARY: '#7E879A',
  SUCCESS_BG: '#153B2E',
  SUCCESS_TEXT: '#7DD3A7',
  ERROR_BG: '#3B1D24',
  ERROR_TEXT: '#FCA5A5',
  WARNING_BG: '#3B2E10',
  WARNING_TEXT: '#F59E0B',
  INPUT_BG: '#232835',
  ACCENT_SURFACE: '#1A2742',
  BORDER_SUBTLE: '#2C3343',
  BORDER_SOFT: '#3A4355',
  SECONDARY_BTN_BG: '#232835',
  SECONDARY_BTN_TEXT: '#E2E8F0',
  CARD_BG: '#1E232F',
  HEADER_BG: '#171A22',
  TAB_BAR_BG: '#171A22',
  DISABLED_TEXT: '#AAAAAA',
  INACTIVE_BG: '#3A4355',
  PANEL_BG: '#1F1F1F',
  TOOLBAR_BG: '#2A2A2A',
  OVERLAY_SEMI: '#CC1F1F1F',
  OVERLAY_LIGHT: '#8A2A2A2A',
  OVERLAY_FULL: '#E6000000',
  ICON_FILL: '#FFFFFF',
  ICON_BG: '#1FFFFFFF',
  PROGRESS_COLOR: '#2563EB',
  PROGRESS_BG: '#2C3343',
  DIALOG_OVERLAY: '#80000000',
  SHADOW_COLOR: '#00000033',
  CARET_HIDDEN: '#00000000',
  INFO_BG: '#1E335A',
  INFO_TEXT: '#B7D3FF',
};

const LIGHT_COLORS: ThemeColors = {
  GRAY_BG: '#F8FAFC',
  ACCENT: '#0071FF',
  ACCENT_50: '#770071FF',
  ACCENT_80: '#AA0071FF',
  CANVAS_COLOR: '#FFFFFF',
  BORDER: '#CCCCCC',
  ID_COLOR: '#00B6F0',
  DARK_GRAY: '#949494',
  BUTTON: '#2C8CFF',
  HOVER_BORDER: '#999999',
  WHITE: '#FFFFFF',
  BLACK: '#000000',
  ACCENT_TEXT: '#FFFFFF',
  CONTRAST_TEXT: '#111827',
  TEXT_PRIMARY: '#111827',
  TEXT_SECONDARY: '#6B7280',
  TEXT_TERTIARY: '#9CA3AF',
  SUCCESS_BG: '#DCFCE7',
  SUCCESS_TEXT: '#166534',
  ERROR_BG: '#FEE2E2',
  ERROR_TEXT: '#991B1B',
  WARNING_BG: '#FEF3C7',
  WARNING_TEXT: '#D97706',
  INPUT_BG: '#F3F4F6',
  ACCENT_SURFACE: '#EFF6FF',
  BORDER_SUBTLE: '#CBD5E1',
  BORDER_SOFT: '#D1D5DB',
  SECONDARY_BTN_BG: '#F3F4F6',
  SECONDARY_BTN_TEXT: '#374151',
  CARD_BG: '#FFFFFF',
  HEADER_BG: '#F8FAFC',
  TAB_BAR_BG: '#F8FAFC',
  DISABLED_TEXT: '#AAAAAA',
  INACTIVE_BG: '#E5E7EB',
  PANEL_BG: '#FFFFFF',
  TOOLBAR_BG: '#F3F4F6',
  OVERLAY_SEMI: '#CCF8FAFC',
  OVERLAY_LIGHT: '#8AF8FAFC',
  OVERLAY_FULL: '#E6F8FAFC',
  ICON_FILL: '#374151',
  ICON_BG: '#1F000000',
  PROGRESS_COLOR: '#2563EB',
  PROGRESS_BG: '#E5E7EB',
  DIALOG_OVERLAY: '#80000000',
  SHADOW_COLOR: '#00000033',
  CARET_HIDDEN: '#00000000',
  INFO_BG: '#DBEAFE',
  INFO_TEXT: '#1E40AF',
};

function getColorsForMode(isDark: boolean): ThemeColors {
  return isDark ? DARK_COLORS : LIGHT_COLORS;
}

function pushColorsToAppStorage(colors: ThemeColors): void {
  AppStorage.setOrCreate<string>('theme_GRAY_BG', colors.GRAY_BG);
  AppStorage.setOrCreate<string>('theme_ACCENT', colors.ACCENT);
  AppStorage.setOrCreate<string>('theme_ACCENT_50', colors.ACCENT_50);
  AppStorage.setOrCreate<string>('theme_ACCENT_80', colors.ACCENT_80);
  AppStorage.setOrCreate<string>('theme_CANVAS_COLOR', colors.CANVAS_COLOR);
  AppStorage.setOrCreate<string>('theme_BORDER', colors.BORDER);
  AppStorage.setOrCreate<string>('theme_ID_COLOR', colors.ID_COLOR);
  AppStorage.setOrCreate<string>('theme_DARK_GRAY', colors.DARK_GRAY);
  AppStorage.setOrCreate<string>('theme_BUTTON', colors.BUTTON);
  AppStorage.setOrCreate<string>('theme_HOVER_BORDER', colors.HOVER_BORDER);
  AppStorage.setOrCreate<string>('theme_WHITE', colors.WHITE);
  AppStorage.setOrCreate<string>('theme_BLACK', colors.BLACK);
  AppStorage.setOrCreate<string>('theme_ACCENT_TEXT', colors.ACCENT_TEXT);
  AppStorage.setOrCreate<string>('theme_CONTRAST_TEXT', colors.CONTRAST_TEXT);
  AppStorage.setOrCreate<string>('theme_TEXT_PRIMARY', colors.TEXT_PRIMARY);
  AppStorage.setOrCreate<string>('theme_TEXT_SECONDARY', colors.TEXT_SECONDARY);
  AppStorage.setOrCreate<string>('theme_TEXT_TERTIARY', colors.TEXT_TERTIARY);
  AppStorage.setOrCreate<string>('theme_SUCCESS_BG', colors.SUCCESS_BG);
  AppStorage.setOrCreate<string>('theme_SUCCESS_TEXT', colors.SUCCESS_TEXT);
  AppStorage.setOrCreate<string>('theme_ERROR_BG', colors.ERROR_BG);
  AppStorage.setOrCreate<string>('theme_ERROR_TEXT', colors.ERROR_TEXT);
  AppStorage.setOrCreate<string>('theme_WARNING_BG', colors.WARNING_BG);
  AppStorage.setOrCreate<string>('theme_WARNING_TEXT', colors.WARNING_TEXT);
  AppStorage.setOrCreate<string>('theme_INPUT_BG', colors.INPUT_BG);
  AppStorage.setOrCreate<string>('theme_ACCENT_SURFACE', colors.ACCENT_SURFACE);
  AppStorage.setOrCreate<string>('theme_BORDER_SUBTLE', colors.BORDER_SUBTLE);
  AppStorage.setOrCreate<string>('theme_BORDER_SOFT', colors.BORDER_SOFT);
  AppStorage.setOrCreate<string>('theme_SECONDARY_BTN_BG', colors.SECONDARY_BTN_BG);
  AppStorage.setOrCreate<string>('theme_SECONDARY_BTN_TEXT', colors.SECONDARY_BTN_TEXT);
  AppStorage.setOrCreate<string>('theme_CARD_BG', colors.CARD_BG);
  AppStorage.setOrCreate<string>('theme_HEADER_BG', colors.HEADER_BG);
  AppStorage.setOrCreate<string>('theme_TAB_BAR_BG', colors.TAB_BAR_BG);
  AppStorage.setOrCreate<string>('theme_DISABLED_TEXT', colors.DISABLED_TEXT);
  AppStorage.setOrCreate<string>('theme_INACTIVE_BG', colors.INACTIVE_BG);
  AppStorage.setOrCreate<string>('theme_PANEL_BG', colors.PANEL_BG);
  AppStorage.setOrCreate<string>('theme_TOOLBAR_BG', colors.TOOLBAR_BG);
  AppStorage.setOrCreate<string>('theme_OVERLAY_SEMI', colors.OVERLAY_SEMI);
  AppStorage.setOrCreate<string>('theme_OVERLAY_LIGHT', colors.OVERLAY_LIGHT);
  AppStorage.setOrCreate<string>('theme_OVERLAY_FULL', colors.OVERLAY_FULL);
  AppStorage.setOrCreate<string>('theme_ICON_FILL', colors.ICON_FILL);
  AppStorage.setOrCreate<string>('theme_ICON_BG', colors.ICON_BG);
  AppStorage.setOrCreate<string>('theme_PROGRESS_COLOR', colors.PROGRESS_COLOR);
  AppStorage.setOrCreate<string>('theme_PROGRESS_BG', colors.PROGRESS_BG);
  AppStorage.setOrCreate<string>('theme_DIALOG_OVERLAY', colors.DIALOG_OVERLAY);
  AppStorage.setOrCreate<string>('theme_SHADOW_COLOR', colors.SHADOW_COLOR);
  AppStorage.setOrCreate<string>('theme_CARET_HIDDEN', colors.CARET_HIDDEN);
  AppStorage.setOrCreate<string>('theme_INFO_BG', colors.INFO_BG);
  AppStorage.setOrCreate<string>('theme_INFO_TEXT', colors.INFO_TEXT);
}

export class ThemeManager {
  private static instance: ThemeManager;
  private currentMode: AppThemeMode = 'system';
  private isDark: boolean = false;

  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  getMode(): AppThemeMode {
    return this.currentMode;
  }

  getIsDark(): boolean {
    return this.isDark;
  }

  applyStoredTheme(mode: StoredThemeMode): void {
    this.setMode(ThemeManager.resolveMode(mode));
  }

  setMode(mode: AppThemeMode): void {
    this.currentMode = mode;
    if (mode === 'system') {
      this.isDark = this.detectSystemDark();
    } else {
      this.isDark = mode === 'dark';
    }
    AppStorage.setOrCreate<boolean>('themeIsDark', this.isDark);
    AppStorage.setOrCreate<string>('themeMode', this.currentMode);
    pushColorsToAppStorage(getColorsForMode(this.isDark));
  }

  private detectSystemDark(): boolean {
    try {
      const colorMode = AppStorage.get<string>('colorMode') ?? '';
      if (colorMode === 'dark') return true;
      if (colorMode === 'light') return false;
    } catch (_e) {}
    return false;
  }

  refreshSystemTheme(): void {
    if (this.currentMode === 'system') {
      this.isDark = this.detectSystemDark();
      AppStorage.setOrCreate<boolean>('themeIsDark', this.isDark);
      pushColorsToAppStorage(getColorsForMode(this.isDark));
    }
  }

  static resolveMode(mode: StoredThemeMode): AppThemeMode {
    return mode === 'auto' ? 'system' : mode;
  }
}

export class ThemeConfig {
  private static colors(): ThemeColors {
    const stored: boolean | undefined = AppStorage.get<boolean>('themeIsDark');
    const isDark: boolean = stored !== undefined ? stored : false;
    return getColorsForMode(isDark);
  }

  static readonly CM_ID_COLOR = '#21790B';

  static get GRAY_BG(): string { return ThemeConfig.colors().GRAY_BG; }
  static get ACCENT(): string { return ThemeConfig.colors().ACCENT; }
  static get ACCENT_50(): string { return ThemeConfig.colors().ACCENT_50; }
  static get ACCENT_80(): string { return ThemeConfig.colors().ACCENT_80; }
  static get CANVAS_COLOR(): string { return ThemeConfig.colors().CANVAS_COLOR; }
  static get BORDER(): string { return ThemeConfig.colors().BORDER; }
  static get ID_COLOR(): string { return ThemeConfig.colors().ID_COLOR; }
  static get DARK_GRAY(): string { return ThemeConfig.colors().DARK_GRAY; }
  static get BUTTON(): string { return ThemeConfig.colors().BUTTON; }
  static get HOVER_BORDER(): string { return ThemeConfig.colors().HOVER_BORDER; }
  static get WHITE(): string { return ThemeConfig.colors().WHITE; }
  static get BLACK(): string { return ThemeConfig.colors().BLACK; }
  static get ACCENT_TEXT(): string { return ThemeConfig.colors().ACCENT_TEXT; }
  static get CONTRAST_TEXT(): string { return ThemeConfig.colors().CONTRAST_TEXT; }
  static get TEXT_PRIMARY(): string { return ThemeConfig.colors().TEXT_PRIMARY; }
  static get TEXT_SECONDARY(): string { return ThemeConfig.colors().TEXT_SECONDARY; }
  static get TEXT_TERTIARY(): string { return ThemeConfig.colors().TEXT_TERTIARY; }
  static get SUCCESS_BG(): string { return ThemeConfig.colors().SUCCESS_BG; }
  static get SUCCESS_TEXT(): string { return ThemeConfig.colors().SUCCESS_TEXT; }
  static get ERROR_BG(): string { return ThemeConfig.colors().ERROR_BG; }
  static get ERROR_TEXT(): string { return ThemeConfig.colors().ERROR_TEXT; }
  static get WARNING_BG(): string { return ThemeConfig.colors().WARNING_BG; }
  static get WARNING_TEXT(): string { return ThemeConfig.colors().WARNING_TEXT; }
  static get INPUT_BG(): string { return ThemeConfig.colors().INPUT_BG; }
  static get ACCENT_SURFACE(): string { return ThemeConfig.colors().ACCENT_SURFACE; }
  static get BORDER_SUBTLE(): string { return ThemeConfig.colors().BORDER_SUBTLE; }
  static get BORDER_SOFT(): string { return ThemeConfig.colors().BORDER_SOFT; }
  static get SECONDARY_BTN_BG(): string { return ThemeConfig.colors().SECONDARY_BTN_BG; }
  static get SECONDARY_BTN_TEXT(): string { return ThemeConfig.colors().SECONDARY_BTN_TEXT; }
  static get CARD_BG(): string { return ThemeConfig.colors().CARD_BG; }
  static get HEADER_BG(): string { return ThemeConfig.colors().HEADER_BG; }
  static get TAB_BAR_BG(): string { return ThemeConfig.colors().TAB_BAR_BG; }
  static get DISABLED_TEXT(): string { return ThemeConfig.colors().DISABLED_TEXT; }
  static get INACTIVE_BG(): string { return ThemeConfig.colors().INACTIVE_BG; }
  static get PANEL_BG(): string { return ThemeConfig.colors().PANEL_BG; }
  static get TOOLBAR_BG(): string { return ThemeConfig.colors().TOOLBAR_BG; }
  static get OVERLAY_SEMI(): string { return ThemeConfig.colors().OVERLAY_SEMI; }
  static get OVERLAY_LIGHT(): string { return ThemeConfig.colors().OVERLAY_LIGHT; }
  static get OVERLAY_FULL(): string { return ThemeConfig.colors().OVERLAY_FULL; }
  static get ICON_FILL(): string { return ThemeConfig.colors().ICON_FILL; }
  static get ICON_BG(): string { return ThemeConfig.colors().ICON_BG; }
  static get PROGRESS_COLOR(): string { return ThemeConfig.colors().PROGRESS_COLOR; }
  static get PROGRESS_BG(): string { return ThemeConfig.colors().PROGRESS_BG; }
  static get DIALOG_OVERLAY(): string { return ThemeConfig.colors().DIALOG_OVERLAY; }
  static get SHADOW_COLOR(): string { return ThemeConfig.colors().SHADOW_COLOR; }
  static get CARET_HIDDEN(): string { return ThemeConfig.colors().CARET_HIDDEN; }
  static get INFO_BG(): string { return ThemeConfig.colors().INFO_BG; }
  static get INFO_TEXT(): string { return ThemeConfig.colors().INFO_TEXT; }

  static readonly BORDER_RADIUS_SMALL = 8;
  static readonly BORDER_RADIUS_MEDIUM = 12;
  static readonly BORDER_RADIUS_LARGE = 16;
  static readonly BORDER_RADIUS_XLARGE = 18;
  static readonly BORDER_RADIUS_ROUND = 999;

  static readonly SPACING_XS = 4;
  static readonly SPACING_SM = 8;
  static readonly SPACING_MD = 12;
  static readonly SPACING_LG = 16;
  static readonly SPACING_XL = 18;
  static readonly SPACING_XXL = 24;
  static readonly SPACING_XXXL = 32;

  static readonly MENU_ITEM_HEIGHT = 50;

  static readonly FONT_SIZE_XS = 11;
  static readonly FONT_SIZE_SM = 12;
  static readonly FONT_SIZE_MD = 14;
  static readonly FONT_SIZE_LG = 15;
  static readonly FONT_SIZE_XL = 16;
  static readonly FONT_SIZE_XXL = 18;
  static readonly FONT_SIZE_HUGE = 20;
  static readonly FONT_SIZE_TITLE = 24;
  static readonly FONT_SIZE_ID = 26;

  static readonly BUTTON_HEIGHT_SMALL = 30;
  static readonly BUTTON_HEIGHT_MEDIUM = 34;
  static readonly BUTTON_HEIGHT_LARGE = 44;
  static readonly BUTTON_HEIGHT_ENTRY = 52;

  static getAccentColor(): string { return ThemeConfig.ACCENT; }
  static getIdColor(): string { return ThemeConfig.ID_COLOR; }
  static getDarkGray(): string { return ThemeConfig.DARK_GRAY; }
  static getTextPrimary(): string { return ThemeConfig.TEXT_PRIMARY; }
  static getTextSecondary(): string { return ThemeConfig.TEXT_SECONDARY; }
  static getBackgroundColor(): string { return ThemeConfig.GRAY_BG; }
  static getCardBackgroundColor(): string { return ThemeConfig.CARD_BG; }
  static getInputBackgroundColor(): string { return ThemeConfig.INPUT_BG; }
  static getHeaderBackgroundColor(): string { return ThemeConfig.HEADER_BG; }
  static getTabBarBackgroundColor(): string { return ThemeConfig.TAB_BAR_BG; }

  static getStatusColor(isOnline: boolean): StatusColor {
    if (isOnline) {
      return { bg: ThemeConfig.SUCCESS_BG, text: ThemeConfig.SUCCESS_TEXT };
    } else {
      return { bg: ThemeConfig.WARNING_BG, text: ThemeConfig.WARNING_TEXT };
    }
  }
}
