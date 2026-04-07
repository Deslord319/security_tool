import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { PeripheralTraceRepository } from '../../../services/peripheral/connection-record/PeripheralTraceRepository'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'ConnectionRecordClearUsecase'

export class PeripheralConnectionRecordClearUsecase {
  async execute(context: common.UIAbilityContext | null): Promise<boolean> {
    if (!context) {
      return false
    }
    try {
      const inited = await PeripheralTraceRepository.init(context)
      if (!inited) {
        return false
      }
      return PeripheralTraceRepository.clearAll()
    } catch (err) {
      const error = err as BusinessError
      LogUtils.error(TAG, `execute failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`)
      return false
    }
  }
}
