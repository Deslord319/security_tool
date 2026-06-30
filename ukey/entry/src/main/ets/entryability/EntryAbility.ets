import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { UKeyRuntimeManager } from '../runtime/UKeyRuntimeManager'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'EntryAbility'

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      LogUtils.error(TAG, `setColorMode failed: ${JSON.stringify(err)}`)
    }
    UKeyRuntimeManager.getInstance().bindContext(this.context)
    UKeyRuntimeManager.getInstance().start().catch((err: Error) => {
      LogUtils.warn(TAG, `UKey runtime start failed: ${JSON.stringify(err)}`)
    })
    LogUtils.info(TAG, 'Ability onCreate')
  }

  onDestroy(): void {
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
}
