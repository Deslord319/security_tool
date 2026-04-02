import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralTraceRepository } from '../../../services/PeripheralTraceRepository'

const TAG = 'ConnectionRecordClearUsecase'
const DOMAIN = 0x0013

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
      hilog.error(DOMAIN, TAG, `execute failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`)
      return false
    }
  }
}
