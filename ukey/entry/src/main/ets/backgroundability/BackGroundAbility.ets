import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit'
import { commonEventManager } from '@kit.BasicServicesKit'
import { AppInfo } from '../constants/AppConstants'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'BackGroundAbility'

export default class BackGroundAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    LogUtils.info(TAG, 'onCreate')
  }

  onDestroy(): void {
    LogUtils.info(TAG, 'onDestroy')
  }

  onPrepareToTerminate(): boolean {
    let publishData: commonEventManager.CommonEventPublishData = {
      code: 1,
      data: 'background_ability_terminate'
    }
    commonEventManager.publish(AppInfo.BACKGROUND_ABILITY_TERMINATE_EVENT, publishData, (err) => {
      if (err) {
        LogUtils.warn(TAG, `publish terminate event failed: ${JSON.stringify(err)}`)
        return
      }
      LogUtils.info(TAG, 'publish terminate event success')
    })
    return false
  }
}
