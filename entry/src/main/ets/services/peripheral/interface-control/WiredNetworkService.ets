import { common } from '@kit.AbilityKit'
import { networkManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { OperationResult } from '../../../models/CommonModels'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'WiredNetworkService'
const STORE_NAME = 'peripheral_wired_network'
const KEY_INTERFACES = 'managed_interfaces'
const KEY_DISABLED = 'disabled'

export class WiredNetworkService {
  private static context: common.Context | null = null

  static init(context: common.Context): void {
    WiredNetworkService.context = context
  }

  static async getDisabledWithResult(): Promise<OperationResult<boolean>> {
    if (!WiredNetworkService.context) {
      return { success: false, stage: 'wired_network_not_initialized' } as OperationResult<boolean>
    }
    const pref = PreferencesAccessor.of(WiredNetworkService.context, STORE_NAME)
    return {
      success: true,
      data: await pref.getBoolean(KEY_DISABLED, false)
    } as OperationResult<boolean>
  }

  static async setDisabledWithResult(disabled: boolean): Promise<OperationResult<void>> {
    if (!WiredNetworkService.context) {
      return { success: false, stage: 'wired_network_not_initialized' } as OperationResult<void>
    }
    const pref = PreferencesAccessor.of(WiredNetworkService.context, STORE_NAME)
    try {
      let interfaces: string[] = disabled ? networkManager.getAllNetworkInterfacesSync(ADMIN_WANT) :
        await pref.getJsonArray<string>(KEY_INTERFACES, [] as string[])
      let normalizedInterfaces: string[] = []
      for (const item of interfaces) {
        const normalized = item.trim()
        if (normalized.length > 0 && !normalizedInterfaces.includes(normalized)) {
          normalizedInterfaces.push(normalized)
        }
      }
      interfaces = normalizedInterfaces
      if (interfaces.length === 0) {
        return { success: false, stage: PeripheralReasonCodes.WIRED_NETWORK_NOT_CONNECTED } as OperationResult<void>
      }
      if (disabled && !await pref.setJson(KEY_INTERFACES, interfaces)) {
        return { success: false, stage: 'save_wired_network_interfaces' } as OperationResult<void>
      }
      for (const item of interfaces) {
        networkManager.setNetworkInterfaceDisabledSync(ADMIN_WANT, item, disabled)
      }
      if (!await pref.setValue(KEY_DISABLED, disabled)) {
        return { success: false, stage: 'save_wired_network_state' } as OperationResult<void>
      }
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setDisabled failed: ${JSON.stringify(err)}`)
      return { success: false, stage: 'set_wired_network_disabled' } as OperationResult<void>
    }
  }
}
