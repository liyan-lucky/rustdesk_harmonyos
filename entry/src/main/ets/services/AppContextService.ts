import common from '@ohos.app.ability.common';

export class AppContextService {
  private static context?: common.UIAbilityContext;

  public static setContext(context: common.UIAbilityContext): void {
    AppContextService.context = context;
  }

  public static getContext(): common.UIAbilityContext | undefined {
    return AppContextService.context;
  }

  public static hasContext(): boolean {
    return AppContextService.context !== undefined;
  }
}
