import { LogUtils } from '../utils/LogUtils'
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager';
import { ThemeOption } from '../theme/ThemeColors';
import { AuthService } from '../services/identity/auth/AuthService';
import { AuthMethod } from '../models/DataModels';
import { DialogService } from '../utils/DialogService';
import { PreferencesToolSettingsRepository } from '../services/tool-settings/system-settings/ToolSettingsRepository';

const UI_TEST_ROUTE_KEY = 'ui_test_route'
const ENTRYABILITY_TAG = 'entryAbility'

interface EntryLoggableError {
  code?: number
  message?: string
}

export default class EntryAbility extends UIAbility {
  private startupWant?: Want
  private toolSettingsRepository: PreferencesToolSettingsRepository = new PreferencesToolSettingsRepository()

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.startupWant = want
    // 初始化主题管理器
    ThemeManager.getInstance().init(this.context);
    this.applyUiTestLaunchOverrides();

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      LogUtils.error(ENTRYABILITY_TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
  }

  onNewWant(want: Want): void {
    this.startupWant = want
    this.applyUiTestLaunchOverrides()
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 异步检查启动认证
    this.checkStartupAuth(windowStage);
  }

  // 检查启动校验配置并决定是否拦截
  private async checkStartupAuth(windowStage: window.WindowStage): Promise<void> {
    if (this.shouldSkipStartupAuth()) {
      LogUtils.info(ENTRYABILITY_TAG, 'skip_startup_auth is enabled, loading MainPage directly')
      this.loadMainPage(windowStage)
      return
    }

    try {
      let config = await this.toolSettingsRepository.loadConfig(this.context)
      if (!config.startupAuthEnabled) {
        LogUtils.info(ENTRYABILITY_TAG, '[STARTUP_AUTH_RESULT] startup auth disabled | fallback=false')
        this.loadMainPage(windowStage);
        return;
      }

      // 启用了启动校验，执行认证
      await this.performStartupAuth(windowStage, config.authMethod as AuthMethod);
    } catch (err) {
      let error = err as EntryLoggableError
      LogUtils.error(ENTRYABILITY_TAG,
        `[STARTUP_AUTH_READ] load startup auth config failed | code=${error?.code ?? 'unknown'}, message=${error?.message ?? 'unknown'}, fallback=true`
      )
      // 异常时降级：直接加载主页面
      this.loadMainPage(windowStage);
    }
  }

  private shouldSkipStartupAuth(): boolean {
    return this.getLaunchParamBoolean('skip_startup_auth')
  }

  private getLaunchParamString(name: string): string {
    try {
      const params = this.startupWant?.parameters
      if (!params) {
        return ''
      }
      const raw = params[name]
      if (raw === undefined || raw === null) {
        return ''
      }
      return `${raw}`.trim()
    } catch (err) {
      LogUtils.warn(ENTRYABILITY_TAG, 'getLaunchParamString failed: name=%{public}s, err=%{public}s', name, JSON.stringify(err))
    }
    return ''
  }

  private getLaunchParamBoolean(name: string): boolean {
    const normalized = this.getLaunchParamString(name).toLowerCase()
    return normalized === 'true' || normalized === '1' || normalized === 'yes'
  }

  private applyUiTestLaunchOverrides(): void {
    const route = this.getLaunchParamString('ui_route')
    const theme = this.getLaunchParamString('ui_theme').toLowerCase()
    if (route.length > 0) {
      AppStorage.setOrCreate<string>(UI_TEST_ROUTE_KEY, route)
    }

    if (theme === 'dark') {
      ThemeManager.getInstance().setOption(ThemeOption.DARK).catch((err: Error) => {
        LogUtils.warn(ENTRYABILITY_TAG, 'applyUiTestLaunchOverrides dark failed: %{public}s', JSON.stringify(err))
      })
    } else if (theme === 'light') {
      ThemeManager.getInstance().setOption(ThemeOption.LIGHT).catch((err: Error) => {
        LogUtils.warn(ENTRYABILITY_TAG, 'applyUiTestLaunchOverrides light failed: %{public}s', JSON.stringify(err))
      })
    } else if (theme === 'system') {
      ThemeManager.getInstance().setOption(ThemeOption.SYSTEM).catch((err: Error) => {
        LogUtils.warn(ENTRYABILITY_TAG, 'applyUiTestLaunchOverrides system failed: %{public}s', JSON.stringify(err))
      })
    }
  }

  // 执行启动认证
  private async performStartupAuth(windowStage: window.WindowStage, authMethod: AuthMethod): Promise<void> {
    // 先检查认证方式是否可用
    let checkResult = AuthService.checkAuthMethodAvailability(authMethod);
    LogUtils.info(ENTRYABILITY_TAG,
      `check availability | authMethod=${authMethod}, available=${checkResult.available}, errorCode=${checkResult.errorCode ?? 0}`
    )

    if (!checkResult.available) {
      // 认证方式不可用时优雅降级：直接加载主页面，不阻断启动
      LogUtils.warn(ENTRYABILITY_TAG,
        `auth unavailable | authMethod=${authMethod}, errorCode=${checkResult.errorCode ?? 0}, fallback=true`
      )
      this.loadMainPage(windowStage, `启动校验跳过：${checkResult.message}`);
      return;
    }

    // 认证方式可用，执行认证
    let authResult = await AuthService.authenticate(authMethod);

    if (authResult.success) {
      this.loadMainPage(windowStage);
    } else if (authResult.reason === 'unavailable') {
      LogUtils.warn(ENTRYABILITY_TAG, 'authenticate unavailable');
      this.loadMainPage(windowStage, authResult.message);
    } else {
      try {
        this.context.terminateSelf();
      } catch (err) {
        LogUtils.error(ENTRYABILITY_TAG, 'terminateSelf failed: %{public}s', JSON.stringify(err));
      }
    }
  }

  // 加载主页面，可选传入启动提示消息
  private loadMainPage(windowStage: window.WindowStage, toastMessage?: string): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        LogUtils.error(ENTRYABILITY_TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      // 页面组件创建后，@StorageLink 可能用默认值覆盖了 AppStorage
      // 需要在此重新应用正确的主题
      ThemeManager.getInstance().reapplyTheme();
      this.applyUiTestLaunchOverrides();

      // 页面加载完成后显示启动提示（如认证方式不可用的降级提示）
      if (toastMessage) {
        windowStage.getMainWindow().then((mainWindow: window.Window) => {
          DialogService.openFailure(mainWindow.getUIContext(), toastMessage);
        }).catch((dialogErr: Error) => {
          LogUtils.error(ENTRYABILITY_TAG, 'Failed to show startup dialog: %{public}s', JSON.stringify(dialogErr));
        });
      }

      // 隐藏系统标题栏（装饰栏），保留三键区和拖拽能力
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        // Ensure snapshots are allowed for UI regression capture.
        mainWindow.setWindowPrivacyMode(false)
        mainWindow.setWindowDecorVisible(false);
        mainWindow.setWindowDecorHeight(56);
      }).catch((decErr: Error) => {
        LogUtils.error(ENTRYABILITY_TAG, 'Failed to configure window decor: %{public}s', JSON.stringify(decErr));
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
  }

  onForeground(): void {
    // Ability has brought to foreground
  }

  onBackground(): void {
    // Ability has back to background
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 系统配置变化时（包括深色模式切换），传入最新的 colorMode
    const newColorMode = newConfig?.colorMode;
    ThemeManager.getInstance().onConfigurationUpdate(newColorMode);
  }
}
