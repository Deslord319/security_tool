import { LogUtils } from './utils/LogUtils'
import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ThemeManager, STORAGE_KEY_THEME } from '../theme/ThemeManager';
import { ThemeOption } from '../theme/ThemeColors';
import { AuthService } from '../services/AuthService';
import { AuthMethod } from '../models/DataModels';
import { DialogService } from '../utils/DialogService';
import { PreferencesToolSettingsRepository } from '../services/ToolSettingsRepository';

const DOMAIN = 0x0000;
const UI_TEST_ROUTE_KEY = 'ui_test_route'
const TOOL_SETTINGS_TAG = 'ToolSettings.Entry'

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
      LogUtils.error('testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    LogUtils.info('testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    LogUtils.info('testTag', '%{public}s', 'Ability onDestroy');
  }

  onNewWant(want: Want): void {
    this.startupWant = want
    this.applyUiTestLaunchOverrides()
    LogUtils.info('testTag', 'onNewWant received')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 异步检查启动认证
    this.checkStartupAuth(windowStage);
  }

  // 检查启动校验配置并决定是否拦截
  private async checkStartupAuth(windowStage: window.WindowStage): Promise<void> {
    if (this.shouldSkipStartupAuth()) {
      LogUtils.info('testTag', 'skip_startup_auth is enabled, loading MainPage directly')
      this.loadMainPage(windowStage)
      return
    }

    try {
      let config = await this.toolSettingsRepository.loadConfig(this.context)
      LogUtils.info(TOOL_SETTINGS_TAG,
        `[STARTUP_AUTH_READ] load startup auth config | enabled=${config.startupAuthEnabled}, authMethod=${config.authMethod}`
      )

      if (!config.startupAuthEnabled) {
        LogUtils.info(TOOL_SETTINGS_TAG, '[STARTUP_AUTH_RESULT] startup auth disabled | fallback=false')
        this.loadMainPage(windowStage);
        return;
      }

      // 启用了启动校验，执行认证
      await this.performStartupAuth(windowStage, config.authMethod as AuthMethod);
    } catch (err) {
      let error = err as EntryLoggableError
      LogUtils.error(TOOL_SETTINGS_TAG,
        `[STARTUP_AUTH_READ] load startup auth config failed | code=${error?.code ?? 'unknown'}, message=${error?.message ?? 'unknown'}, fallback=true`
      )
      // 异常时降级：直接加载主页面
      this.loadMainPage(windowStage);
    }
  }

  private shouldSkipStartupAuth(): boolean {
    try {
      const params = this.startupWant?.parameters
      if (!params) {
        return false
      }

      const raw = params['skip_startup_auth']
      if (raw === true || raw === 1) {
        return true
      }
      if (typeof raw === 'string') {
        const normalized = raw.toLowerCase()
        return normalized === 'true' || normalized === '1' || normalized === 'yes'
      }
    } catch (err) {
      LogUtils.warn('testTag', 'shouldSkipStartupAuth read failed: %{public}s', JSON.stringify(err))
    }
    return false
  }

  private getLaunchParamString(name: string): string {
    try {
      const params = this.startupWant?.parameters
      if (!params) {
        return ''
      }
      const raw = params[name]
      if (typeof raw === 'string') {
        return raw
      }
      if (typeof raw === 'number' || typeof raw === 'boolean') {
        return `${raw}`
      }
    } catch (_err) {
      // ignore
    }
    return ''
  }

  private applyUiTestLaunchOverrides(): void {
    const route = this.getLaunchParamString('ui_route')
    const theme = this.getLaunchParamString('ui_theme').toLowerCase()
    LogUtils.info('testTag', 'applyUiTestLaunchOverrides route=%{public}s theme=%{public}s', route, theme)
    if (route.length > 0) {
      AppStorage.setOrCreate<string>(UI_TEST_ROUTE_KEY, route)
    }

    if (theme === 'dark') {
      ThemeManager.getInstance().setOption(ThemeOption.DARK).catch((err: Error) => {
        LogUtils.warn('testTag', 'applyUiTestLaunchOverrides dark failed: %{public}s', JSON.stringify(err))
      })
    } else if (theme === 'light') {
      ThemeManager.getInstance().setOption(ThemeOption.LIGHT).catch((err: Error) => {
        LogUtils.warn('testTag', 'applyUiTestLaunchOverrides light failed: %{public}s', JSON.stringify(err))
      })
    } else if (theme === 'system') {
      ThemeManager.getInstance().setOption(ThemeOption.SYSTEM).catch((err: Error) => {
        LogUtils.warn('testTag', 'applyUiTestLaunchOverrides system failed: %{public}s', JSON.stringify(err))
      })
    }
  }

  // 执行启动认证
  private async performStartupAuth(windowStage: window.WindowStage, authMethod: AuthMethod): Promise<void> {
    // 先检查认证方式是否可用
    let checkResult = AuthService.checkAuthMethodAvailability(authMethod);
    LogUtils.info(TOOL_SETTINGS_TAG,
      `[STARTUP_AUTH_RESULT] check availability | authMethod=${authMethod}, available=${checkResult.available}, errorCode=${checkResult.errorCode ?? 0}`
    )

    if (!checkResult.available) {
      // 认证方式不可用时优雅降级：直接加载主页面，不阻断启动
      LogUtils.warn(TOOL_SETTINGS_TAG,
        `[STARTUP_AUTH_RESULT] auth unavailable | authMethod=${authMethod}, errorCode=${checkResult.errorCode ?? 0}, fallback=true`
      )
      this.loadMainPage(windowStage, `启动校验跳过：${checkResult.message}`);
      return;
    }

    // 认证方式可用，执行认证
    let authResult = await AuthService.authenticate(authMethod);
    LogUtils.info(TOOL_SETTINGS_TAG,
      `[STARTUP_AUTH_RESULT] authenticate | authMethod=${authMethod}, success=${authResult.success}, reason=${authResult.reason ?? 'success'}, errorCode=${authResult.errorCode ?? 0}`
    )

    if (authResult.success) {
      LogUtils.info(TOOL_SETTINGS_TAG, '[STARTUP_AUTH_RESULT] authenticate success | fallback=false');
      this.loadMainPage(windowStage);
    } else if (authResult.reason === 'unavailable') {
      LogUtils.warn(TOOL_SETTINGS_TAG, '[STARTUP_AUTH_RESULT] authenticate unavailable | fallback=true');
      this.loadMainPage(windowStage, authResult.message);
    } else {
      // 认证失败时直接退出应用，避免绕过启动校验。
      LogUtils.warn(TOOL_SETTINGS_TAG, '[STARTUP_AUTH_RESULT] authenticate failed | terminate=true');
      this.context.terminateSelf();
    }
  }

  // 加载主页面，可选传入启动提示消息
  private loadMainPage(windowStage: window.WindowStage, toastMessage?: string): void {
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        LogUtils.error('testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
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
          LogUtils.error('testTag', 'Failed to show startup dialog: %{public}s', JSON.stringify(dialogErr));
        });
      }

      // 隐藏系统标题栏（装饰栏），保留三键区和拖拽能力
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        // Ensure snapshots are allowed for UI regression capture.
        mainWindow.setWindowPrivacyMode(false)
        mainWindow.setWindowDecorVisible(false);
        mainWindow.setWindowDecorHeight(56);
        LogUtils.info('testTag', 'Window decor hidden, height set to 56');
      }).catch((decErr: Error) => {
        LogUtils.error('testTag', 'Failed to configure window decor: %{public}s', JSON.stringify(decErr));
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    LogUtils.info('testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
  }

  onBackground(): void {
    // Ability has back to background
    LogUtils.info('testTag', '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // 系统配置变化时（包括深色模式切换），传入最新的 colorMode
    const newColorMode = newConfig?.colorMode;
    ThemeManager.getInstance().onConfigurationUpdate(newColorMode);
  }
}
