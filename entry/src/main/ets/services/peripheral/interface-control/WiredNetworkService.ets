import { networkManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { OperationResult } from '../../../models/CommonModels'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'WiredNetworkService'

export class WiredNetworkService {
  static getDisabledWithResult(): OperationResult<boolean> {
    try {
      const interfaces = WiredNetworkService.getActiveInterfaces()
      if (interfaces.length === 0) {
        return { success: true, data: false } as OperationResult<boolean>
      }
      const disabled = interfaces.every((item: string): boolean =>
        networkManager.isNetworkInterfaceDisabledSync(ADMIN_WANT, item))
      return { success: true, data: disabled } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getDisabled failed: ${JSON.stringify(err)}`)
      return { success: false, stage: 'read_wired_network_disabled' } as OperationResult<boolean>
    }
  }

  static setDisabledWithResult(disabled: boolean): OperationResult<void> {
    try {
      const interfaces = WiredNetworkService.getActiveInterfaces()
      if (interfaces.length === 0) {
        return { success: false, stage: PeripheralReasonCodes.WIRED_NETWORK_NOT_CONNECTED } as OperationResult<void>
      }
      for (const item of interfaces) {
        networkManager.setNetworkInterfaceDisabledSync(ADMIN_WANT, item, disabled)
        if (networkManager.isNetworkInterfaceDisabledSync(ADMIN_WANT, item) !== disabled) {
          return { success: false, stage: 'verify_wired_network_disabled' } as OperationResult<void>
        }
      }
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setDisabled failed: ${JSON.stringify(err)}`)
      return { success: false, stage: 'set_wired_network_disabled' } as OperationResult<void>
    }
  }

  private static getActiveInterfaces(): string[] {
    const raw = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
    const interfaces: string[] = []
    for (const item of raw) {
      const normalized = item.trim()
      if (normalized.length > 0 && !interfaces.includes(normalized)) {
        interfaces.push(normalized)
      }
    }
    return interfaces
  }
}
