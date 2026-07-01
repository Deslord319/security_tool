import { AbilityConstant, AbilityStage } from '@kit.AbilityKit'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'EntryAbilityStage'

export default class EntryAbilityStage extends AbilityStage {
  onPrepareTermination(): AbilityConstant.PrepareTermination {
    LogUtils.info(TAG, 'application termination allowed')
    return AbilityConstant.PrepareTermination.TERMINATE_IMMEDIATELY
  }
}
