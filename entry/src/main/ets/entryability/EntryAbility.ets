import { LogUtils } from '../utils/LogUtils'
import { AbilityConstant, common, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { ThemeManager } from '../theme/ThemeManager';
import { AuthService } from '../services/identity/auth/AuthService';
import { AuthMethod } from '../models/DataModels';
import { DialogService } from '../utils/DialogService';
import { AppInfo } from '../constants/AppConstants'
import { PreferencesToolSettingsRepository } from '../services/tool-settings/system-settings/ToolSettingsRepository';
import { BusinessError, commonEventManager, emitter } from '@kit.BasicServicesKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { loadStatusBar, holdStatusBar } from '../utils/StatusBarUtil';
import { LogPowerLifecycleSource } from '../services/log-manage/source/LogPowerLifecycleSource';

const ENTRYABILITY_TAG = 'entryAbility'

let globalContext: common.UIAbilityContext | null = null
let terminateSubscriber: commonEventManager.CommonEventSubscriber | null = null

interface EntryLoggableError {
  code?: number
  message?: string
}

function showEntryAbilityFromStatusBar(): void {
  if (!globalContext) {
    LogUtils.warn(ENTRYABILITY_TAG, 'showEntryAbilityFromStatusBar skipped: context unavailable')
    return
  }
  globalContext.showAbility().then(() => {
    LogUtils.info(ENTRYABILITY_TAG, 'showAbility success | source=statusBarIconClick')
  }).catch((err: Error) => {
    LogUtils.warn(ENTRYABILITY_TAG, 'showAbility failed | source=statusBarIconClick, err=%{public}s', JSON.stringify(err))
  })
}

function onStatusBarIconClick(eventData: emitter.EventData): void {
  let data = eventData.data as Record<string, Object | string | number | boolean> | undefined
  if (!data) {
    return
  }
  if (data['iconClickType'] === 'leftClick') {
    showEntryAbilityFromStatusBar()
  }
}

export default class EntryAbility extends UIAbility {
  private toolSettingsRepository: PreferencesToolSettingsRepository = new PreferencesToolSettingsRepository()

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // 初始化主题管理器
    ThemeManager.getInstance().init(this.context);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      LogUtils.error(ENTRYABILITY_TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    globalContext = this.context
    this.createTerminateSubscriber()
    LogPowerLifecycleSource.init(this.context).catch((err: Error) => {
      LogUtils.warn(ENTRYABILITY_TAG, 'LogPowerLifecycleSource init failed: %{public}s', JSON.stringify(err))
    })
    this.initStatusBar()
  }

  onDestroy(): void {
    LogPowerLifecycleSource.destroy()
    globalContext = null
    statusBarManager.off('statusBarIconClick', onStatusBarIconClick)
    if (terminateSubscriber) {
      commonEventManager.unsubscribe(terminateSubscriber, (err?: BusinessError) => {
        if (err) {
          LogUtils.warn(ENTRYABILITY_TAG, 'unsubscribe terminate event failed: %{public}s', JSON.stringify(err))
        }
      })
      terminateSubscriber = null
    }
  }

  onNewWant(_want: Want): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 异步检查启动认证
    this.checkStartupAuth(windowStage);
  }

  // 检查启动校验配置并决定是否拦截
  private async checkStartupAuth(windowStage: window.WindowStage): Promise<void> {
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
        mainWindow.setWindowDecorVisible(false);
        mainWindow.setWindowDecorHeight(56);
      }).catch((decErr: Error) => {
        LogUtils.error(ENTRYABILITY_TAG, 'Failed to configure window decor: %{public}s', JSON.stringify(decErr));
      });
    });
  }

  private async initStatusBar(): Promise<void> {
    try {
      await loadStatusBar(this.context)
      statusBarManager.off('statusBarIconClick', onStatusBarIconClick)
      statusBarManager.on('statusBarIconClick', onStatusBarIconClick)
      await holdStatusBar(this.context)
      LogUtils.info(ENTRYABILITY_TAG, 'initStatusBar success')
    } catch (err) {
      LogUtils.warn(ENTRYABILITY_TAG, 'initStatusBar failed: %{public}s', JSON.stringify(err))
    }
  }

  private createTerminateSubscriber(): void {
    if (terminateSubscriber) {
      return
    }
    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [AppInfo.BACKGROUND_ABILITY_TERMINATE_EVENT]
    }
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
      if (err) {
        LogUtils.warn(ENTRYABILITY_TAG, 'createTerminateSubscriber failed: %{public}s', JSON.stringify(err))
        return
      }
      terminateSubscriber = subscriber
      commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, _data: commonEventManager.CommonEventData) => {
        if (callbackErr) {
          LogUtils.warn(ENTRYABILITY_TAG, 'terminate event callback failed: %{public}s', JSON.stringify(callbackErr))
          return
        }
        statusBarManager.removeFromStatusBar(this.context)
        setTimeout(() => {
          this.context.terminateSelf().catch((terminateErr: Error) => {
            LogUtils.warn(ENTRYABILITY_TAG, 'terminateSelf failed after tray removal: %{public}s',
              JSON.stringify(terminateErr))
          })
        }, 200)
      });
    })
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
  }

  onBackground(): void {
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const newColorMode = newConfig?.colorMode;
    ThemeManager.getInstance().onConfigurationUpdate(newColorMode);
  }

  onPrepareToTerminate(): boolean {
    this.context.hideAbility().then(() => {
      LogUtils.info(ENTRYABILITY_TAG, 'hideAbility success | source=onPrepareToTerminate')
    }).catch((err: BusinessError) => {
      LogUtils.warn(ENTRYABILITY_TAG, 'hideAbility failed | source=onPrepareToTerminate, err=%{public}s',
        JSON.stringify(err))
    })
    return true
  }
}
