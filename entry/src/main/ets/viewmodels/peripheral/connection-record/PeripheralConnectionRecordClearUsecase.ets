import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { PeripheralTraceMaintenanceService } from '../../../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { UsbDevicePolicyStateRepository } from '../../../services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'ConnectionRecordClearUsecase'

export class PeripheralConnectionRecordClearUsecase {
  async execute(context: common.UIAbilityContext | null): Promise<boolean> {
    if (!context) {
      return false
    }
    try {
      const inited = await PeripheralTraceMaintenanceService.initialize(context)
      if (!inited.success) {
        return false
      }
      const usbStateReady = await UsbDevicePolicyStateRepository.init(context)
      if (!usbStateReady) {
        return false
      }
      let cleared = await PeripheralTraceMaintenanceService.clearAll()
      if (!cleared.success) {
        return false
      }
      return await UsbDevicePolicyStateRepository.deleteAbsentStates()
    } catch (err) {
      const error = err as BusinessError
      LogUtils.error(TAG, `execute failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`)
      return false
    }
  }
}
