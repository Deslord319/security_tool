import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { PeripheralTraceMaintenanceService } from '../../../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'ConnectionRecordClearUsecase'

export class PeripheralConnectionRecordClearUsecase {
  async execute(context: common.UIAbilityContext | null): Promise<boolean> {
    if (!context) {
      return false
    }
    try {
      const inited = await PeripheralTraceMaintenanceService.initialize(context)
      if (!inited) {
        return false
      }
      return PeripheralTraceMaintenanceService.clearAll()
    } catch (err) {
      const error = err as BusinessError
      LogUtils.error(TAG, `execute failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`)
      return false
    }
  }
}
