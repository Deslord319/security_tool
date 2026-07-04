import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { BusinessError, commonEventManager, emitter } from '@kit.BasicServicesKit'
import { statusBarManager } from '@kit.DesktopExtensionKit'
import { AppInfo } from '../constants/AppConstants'
import { UKeyRuntimeManager } from '../runtime/UKeyRuntimeManager'
import { holdStatusBar, loadStatusBar } from '../utils/StatusBarUtil'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'EntryAbility'

interface StatusBarIconClickData {
  iconClickType?: string
}

export default class EntryAbility extends UIAbility {
  private terminateSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private readonly statusBarIconClickHandler: (eventData: emitter.EventData) => void =
    (eventData: emitter.EventData) => {
      this.handleStatusBarIconClick(eventData)
    }

  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    UKeyRuntimeManager.getInstance().bindContext(this.context)
    UKeyRuntimeManager.getInstance().start().catch((err: Error) => {
      LogUtils.warn(TAG, `UKey runtime start failed: ${JSON.stringify(err)}`)
    })
    this.createTerminateSubscriber()
    this.initStatusBar()
    LogUtils.info(TAG, 'Ability onCreate')
  }

  onDestroy(): void {
    statusBarManager.off('statusBarIconClick', this.statusBarIconClickHandler)
    if (this.terminateSubscriber) {
      commonEventManager.unsubscribe(this.terminateSubscriber, (err?: BusinessError) => {
        if (err) {
          LogUtils.warn(TAG, `unsubscribe terminate event failed: ${JSON.stringify(err)}`)
        }
      })
      this.terminateSubscriber = null
    }
    UKeyRuntimeManager.getInstance().stop()
    LogUtils.info(TAG, 'Ability onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    LogUtils.info(TAG, 'Ability onWindowStageCreate')
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        LogUtils.error(TAG, `loadContent failed: ${JSON.stringify(err)}`)
        return
      }
      LogUtils.info(TAG, 'loadContent success')
      windowStage.getMainWindow().then((mainWindow: window.Window) => {
        mainWindow.setWindowDecorVisible(false)
        mainWindow.setWindowDecorHeight(56)
      }).catch((err: Error) => {
        LogUtils.warn(TAG, `configure window decor failed: ${JSON.stringify(err)}`)
      })
    })
  }

  onWindowStageDestroy(): void {
    LogUtils.info(TAG, 'Ability onWindowStageDestroy')
  }

  onForeground(): void {
    LogUtils.info(TAG, 'Ability onForeground')
  }

  onBackground(): void {
    LogUtils.info(TAG, 'Ability onBackground')
  }

  onPrepareToTerminate(): boolean {
    this.context.hideAbility().then(() => {
      LogUtils.info(TAG, 'hideAbility success | source=onPrepareToTerminate')
    }).catch((err: BusinessError) => {
      LogUtils.warn(TAG, `hideAbility failed | source=onPrepareToTerminate, err=${JSON.stringify(err)}`)
    })
    return true
  }

  private async initStatusBar(): Promise<void> {
    try {
      await loadStatusBar(this.context)
      statusBarManager.off('statusBarIconClick', this.statusBarIconClickHandler)
      statusBarManager.on('statusBarIconClick', this.statusBarIconClickHandler)
      await holdStatusBar(this.context)
      LogUtils.info(TAG, 'initStatusBar success')
    } catch (err) {
      LogUtils.warn(TAG, `initStatusBar failed: ${JSON.stringify(err)}`)
    }
  }

  private createTerminateSubscriber(): void {
    if (this.terminateSubscriber) {
      return
    }
    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [AppInfo.BACKGROUND_ABILITY_TERMINATE_EVENT]
    }
    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
      if (err) {
        LogUtils.warn(TAG, `createTerminateSubscriber failed: ${JSON.stringify(err)}`)
        return
      }
      this.terminateSubscriber = subscriber
      commonEventManager.subscribe(subscriber, (callbackErr: BusinessError) => {
        if (callbackErr) {
          LogUtils.warn(TAG, `terminate event callback failed: ${JSON.stringify(callbackErr)}`)
          return
        }
        statusBarManager.removeFromStatusBar(this.context)
        setTimeout(() => {
          this.context.terminateSelf().catch((terminateErr: Error) => {
            LogUtils.warn(TAG, `terminateSelf failed after tray removal: ${JSON.stringify(terminateErr)}`)
          })
        }, 200)
      })
    })
  }

  private showEntryAbilityFromStatusBar(): void {
    this.context.showAbility().then(() => {
      LogUtils.info(TAG, 'showAbility success | source=statusBarIconClick')
    }).catch((err: Error) => {
      LogUtils.warn(TAG, `showAbility failed | source=statusBarIconClick, err=${JSON.stringify(err)}`)
    })
  }

  private handleStatusBarIconClick(eventData: emitter.EventData): void {
    let data = eventData.data as StatusBarIconClickData | undefined
    if (data?.iconClickType === 'leftClick') {
      this.showEntryAbilityFromStatusBar()
    }
  }
}
