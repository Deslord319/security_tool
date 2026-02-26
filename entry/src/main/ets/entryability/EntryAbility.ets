import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager';
import { AuthService } from '../services/AuthService';
import { AuthMethod, PREF_KEY_STARTUP_AUTH, PREF_KEY_AUTH_METHOD, PREF_STORE_NAME_TOOL } from '../models/DataModels';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '[DIAG] onCreate start, colorMode=%{public}d, DARK=%{public}d, LIGHT=%{public}d, NOT_SET=%{public}d',
      this.context.config?.colorMode ?? -999,
      ConfigurationConstant.ColorMode.COLOR_MODE_DARK,
      ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT,
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    // 初始化主题管理器
    ThemeManager.getInstance().init(this.context);
    hilog.info(DOMAIN, 'testTag', '[DIAG] after init, colorMode=%{public}d, AppStorage_theme=%{public}s',
      this.context.config?.colorMode ?? -999,
      AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined');

    try {
      hilog.info(DOMAIN, 'testTag', '[DIAG] before setColorMode(NOT_SET)');
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      hilog.info(DOMAIN, 'testTag', '[DIAG] after setColorMode, colorMode=%{public}d', this.context.config?.colorMode ?? -999);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '[DIAG] onWindowStageCreate, AppStorage_theme=%{public}s',
      AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined');

    // 异步检查启动认证
    this.checkStartupAuth(windowStage);
  }

  // 检查启动校验配置并决定是否拦截
  private async checkStartupAuth(windowStage: window.WindowStage): Promise<void> {
    try {
      let prefs = await preferences.getPreferences(this.context, PREF_STORE_NAME_TOOL);
      let startupAuthEnabled = await prefs.get(PREF_KEY_STARTUP_AUTH, false) as boolean;
      let authMethodValue = await prefs.get(PREF_KEY_AUTH_METHOD, AuthMethod.PIN) as number;

      hilog.info(DOMAIN, 'testTag', `Startup auth config: enabled=${startupAuthEnabled}, method=${authMethodValue}`);

      if (!startupAuthEnabled) {
        hilog.info(DOMAIN, 'testTag', 'Startup auth disabled, loading MainPage directly');
        this.loadMainPage(windowStage);
        return;
      }

      // 启用了启动校验，执行认证
      await this.performStartupAuth(windowStage, authMethodValue as AuthMethod);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', `checkStartupAuth failed: ${JSON.stringify(err)}, fallback to load MainPage`);
      // 异常时降级：直接加载主页面
      this.loadMainPage(windowStage);
    }
  }

  // 执行启动认证
  private async performStartupAuth(windowStage: window.WindowStage, authMethod: AuthMethod): Promise<void> {
    // 先检查认证方式是否可用
    let checkResult = AuthService.checkAuthMethodAvailability(authMethod);

    if (!checkResult.available) {
      // 认证方式不可用时优雅降级：直接加载主页面，不阻断启动
      // 注意：此时尚未调用 loadContent，promptAction 没有 UI 上下文无法弹窗
      hilog.warn(DOMAIN, 'testTag', `Startup auth method unavailable: ${checkResult.message}, fallback to load MainPage`);
      this.loadMainPage(windowStage, `启动校验跳过：${checkResult.message}`);
      return;
    }

    // 认证方式可用，执行认证
    let success = await AuthService.authenticate(authMethod);

    if (success) {
      hilog.info(DOMAIN, 'testTag', 'Startup auth succeeded, loading MainPage');
      this.loadMainPage(windowStage);
    } else {
      // 认证失败或取消，直接退出应用
      // 注意：此时没有页面上下文，无法使用 promptAction 弹窗
      hilog.warn(DOMAIN, 'testTag', 'Startup auth failed or cancelled, terminating');
      this.context.terminateSelf();
    }
  }

  // 加载主页面，可选传入启动提示消息
  private loadMainPage(windowStage: window.WindowStage, toastMessage?: string): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // 页面组件创建后，@StorageLink 可能用默认值覆盖了 AppStorage
      // 需要在此重新应用正确的主题
      ThemeManager.getInstance().reapplyTheme();
      hilog.info(DOMAIN, 'testTag', '[DIAG] loadContent done, AppStorage_theme=%{public}s',
        AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined');

      // 页面加载完成后显示启动提示（如认证方式不可用的降级提示）
      if (toastMessage) {
        promptAction.showToast({ message: toastMessage, duration: 3000 });
      }

      // 隐藏系统标题栏（装饰栏），保留三键区和拖拽能力
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        mainWindow.setWindowDecorVisible(false);
        mainWindow.setWindowDecorHeight(56);
        hilog.info(DOMAIN, 'testTag', 'Window decor hidden, height set to 56');
      }).catch((decErr: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to configure window decor: %{public}s', JSON.stringify(decErr));
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '[DIAG] onForeground, AppStorage_theme=%{public}s',
      AppStorage.get<string>(STORAGE_KEY_THEME) ?? 'undefined');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 系统配置变化时（包括深色模式切换），传入最新的 colorMode
    const newColorMode = newConfig?.colorMode;
    hilog.info(DOMAIN, 'testTag', '[DIAG] onConfigurationUpdate, newConfig.colorMode=%{public}d, context.colorMode=%{public}d',
      newColorMode ?? -999, this.context.config?.colorMode ?? -999);
    ThemeManager.getInstance().onConfigurationUpdate(newColorMode);
  }
}
