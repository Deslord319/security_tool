import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager';

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