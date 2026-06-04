import { ThemeConfig } from '../common/ThemeConfig';

export type IconName = 'display' | 'folder' | 'search' | 'dots' | 'chat' | 'screen' |
  'arrow' | 'close' | 'refresh' | 'plus' | 'minus' | 'check' | 'settings' |
  'android' | 'apple' | 'windows' | 'linux' | 'mac';

@Component
export struct Icon {
  @Prop name: IconName = 'display';
  @Prop size: number = 24;
  @Prop color: string = ThemeConfig.TEXT_PRIMARY;

  build() {
    Text(this.getIconChar())
      .fontSize(this.size)
      .fontColor(this.color)
      .fontFamily('tabbar')
  }

  private getIconChar(): string {
    const iconMap: Record<IconName, string> = {
      'display': '\uE001',
      'folder': '\uE002',
      'search': '\uE003',
      'dots': '\uE004',
      'chat': '\uE005',
      'screen': '\uE006',
      'arrow': '\uE007',
      'close': '\uE008',
      'refresh': '\uE009',
      'plus': '\uE00A',
      'minus': '\uE00B',
      'check': '\uE00C',
      'settings': '\uE00D',
      'android': '\uE00E',
      'apple': '\uE00F',
      'windows': '\uE010',
      'linux': '\uE011',
      'mac': '\uE012'
    };
    return iconMap[this.name] || '\uE001';
  }
}

export const IconSvg = {
  display: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M8 4h16a4 4 0 014 4v12a4 4 0 01-4 4H8a4 4 0 01-4-4V8a4 4 0 014-4zm0 2a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V8a2 2 0 00-2-2H8z"/></svg>`,
  folder: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M4 8a2 2 0 012-2h8l2 2h10a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V8z"/></svg>`,
  search: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M14 4a10 10 0 016.32 17.74l6.97 6.97-1.41 1.41-6.97-6.97A10 10 0 1114 4zm0 2a8 8 0 100 16 8 8 0 000-16z"/></svg>`,
  dots: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><circle fill="currentColor" cx="8" cy="16" r="2"/><circle fill="currentColor" cx="16" cy="16" r="2"/><circle fill="currentColor" cx="24" cy="16" r="2"/></svg>`,
  chat: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M6 6h20a2 2 0 012 2v12a2 2 0 01-2 2h-6l-4 4-4-4H6a2 2 0 01-2-2V8a2 2 0 012-2z"/></svg>`,
  screen: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path fill="currentColor" d="M4 8a2 2 0 012-2h20a2 2 0 012 2v14a2 2 0 01-2 2H6a2 2 0 01-2-2V8zm2 0v14h20V8H6z"/></svg>`
};
