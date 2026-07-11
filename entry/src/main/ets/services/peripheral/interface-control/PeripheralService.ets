import { LogUtils } from '../../../utils/LogUtils'
import { deviceSettings, restrictions, usbManager } from '@kit.MDMKit'

import { ADMIN_WANT } from '../../../constants/AppConstants'
import { PeripheralServiceErrorStrings } from '../../../constants/modules/PeripheralErrorStrings'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { PeripheralErrorCodes } from '../../../constants/SystemErrorCodes'
import { OperationResult } from '../../../models/CommonModels'
import { PeripheralInterfaceFeature, PeripheralInterfaceFeatures } from '../../../models/PeripheralModels'
import { OperationResultUtils } from '../../common/OperationResultUtils'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'

const TAG = 'PeripheralService'
const ACTION_TURN_ON_WIFI = 'turn on wifi'
const ACTION_TURN_ON_BLUETOOTH = 'turn on bluetooth'

interface UsbConflictSnapshot {
  storagePolicy: usbManager.UsbPolicy
}

export class PeripheralService {
  static setInterfaceDisabledWithResult(feature: PeripheralInterfaceFeature, disallow: boolean): OperationResult<void> {
    try {
      restrictions.setDisallowedPolicy(ADMIN_WANT, feature, disallow)
      if (!disallow) {
        return PeripheralService.restoreEnabledInterfacePowerWithResult(feature)
      }
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setInterfaceDisabled failed: ${JSON.stringify(err)}`)
      if (feature === PeripheralInterfaceFeatures.USB &&
        CommonErrorUtils.extractErrorCode(err as ErrorLike) === PeripheralErrorCodes.POLICY_CONFLICT) {
        return PeripheralService.buildUserFailureResult<void>(
          PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT,
          PeripheralServiceErrorStrings.USB_POLICY_CONFLICT
        )
      }
      return OperationResultUtils.buildFailureResult<void>('set interface disabled policy', err as ErrorLike)
    }
  }

  static restoreEnabledInterfacePowerWithResult(feature: PeripheralInterfaceFeature): OperationResult<void> {
    if (feature === PeripheralInterfaceFeatures.WIFI) {
      return PeripheralService.turnOnWifiWithResult()
    }
    if (feature === PeripheralInterfaceFeatures.BLUETOOTH) {
      return PeripheralService.turnOnBluetoothWithResult()
    }
    return { success: true } as OperationResult<void>
  }

  static getInterfaceDisabledWithResult(feature: PeripheralInterfaceFeature): OperationResult<boolean> {
    try {
      const disabled = restrictions.getDisallowedPolicy(ADMIN_WANT, feature)
      return {
        success: true,
        data: disabled
      } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return OperationResultUtils.buildFailureResult<boolean>('get interface disabled status', err as ErrorLike, false)
    }
  }

  static getUsbStoragePolicyWithResult(): OperationResult<usbManager.UsbPolicy> {
    try {
      const policy: usbManager.UsbPolicy = usbManager.getUsbStorageDeviceAccessPolicy(ADMIN_WANT)
      return {
        success: true,
        data: policy
      } as OperationResult<usbManager.UsbPolicy>
    } catch (err) {
      LogUtils.error(TAG, `getUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return OperationResultUtils.buildFailureResult<usbManager.UsbPolicy>(
        'get usb storage policy',
        err as ErrorLike,
        usbManager.UsbPolicy.READ_WRITE
      )
    }
  }

  static setUsbStoragePolicyWithCleanupResult(policy: usbManager.UsbPolicy): OperationResult<void> {
    const snapshotResult = PeripheralService.getUsbConflictSnapshot()
    if (!snapshotResult.success) {
      return PeripheralService.copyFailureAsVoid(snapshotResult, 'read_usb_storage_policy')
    }

    try {
      usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, policy)
      return {
        success: true,
        userMessage: PeripheralServiceErrorStrings.USB_STORAGE_POLICY_UPDATED,
        stage: 'completed'
      } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setUsbStoragePolicyWithCleanupResult failed: ${JSON.stringify(err)}`)
      if (CommonErrorUtils.extractErrorCode(err as ErrorLike) === PeripheralErrorCodes.POLICY_CONFLICT) {
        return PeripheralService.buildUserFailureResult<void>(
          'set_usb_storage_policy',
          PeripheralServiceErrorStrings.USB_POLICY_CONFLICT
        )
      }
      return OperationResultUtils.buildFailureResult<void>('set usb storage policy', err as ErrorLike)
    }
  }

  private static turnOnWifiWithResult(): OperationResult<void> {
    try {
      deviceSettings.setSwitchStatus(
        ADMIN_WANT,
        deviceSettings.SwitchKey.WIFI,
        deviceSettings.SwitchStatus.ON
      )
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `turnOnWifi failed: ${JSON.stringify(err)}`)
      const result = OperationResultUtils.buildFailureResult<void>(ACTION_TURN_ON_WIFI, err as ErrorLike)
      result.stage = PeripheralReasonCodes.TURN_ON_WIFI_FAILED
      return result
    }
  }

  private static turnOnBluetoothWithResult(): OperationResult<void> {
    try {
      deviceSettings.setSwitchStatus(
        ADMIN_WANT,
        deviceSettings.SwitchKey.BLUETOOTH,
        deviceSettings.SwitchStatus.ON
      )
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `turnOnBluetooth failed: ${JSON.stringify(err)}`)
      const result = OperationResultUtils.buildFailureResult<void>(ACTION_TURN_ON_BLUETOOTH, err as ErrorLike)
      result.stage = PeripheralReasonCodes.TURN_ON_BLUETOOTH_FAILED
      return result
    }
  }

  private static getUsbConflictSnapshot(): OperationResult<UsbConflictSnapshot> {
    const storagePolicyResult = PeripheralService.getUsbStoragePolicyWithResult()
    if (!storagePolicyResult.success) {
      return {
        success: false,
        errorCode: storagePolicyResult.errorCode,
        errorMessage: storagePolicyResult.errorMessage,
        userMessage: PeripheralServiceErrorStrings.READ_USB_STORAGE_POLICY_FAILED,
        suggestion: storagePolicyResult.suggestion,
        isAdminMissing: storagePolicyResult.isAdminMissing,
        stage: 'read_usb_storage_policy'
      } as OperationResult<UsbConflictSnapshot>
    }

    return {
      success: true,
      data: {
        storagePolicy: storagePolicyResult.data ?? usbManager.UsbPolicy.READ_WRITE
      }
    } as OperationResult<UsbConflictSnapshot>
  }

  private static buildUserFailureResult<T>(stage: string, userMessage: string, fallbackData?: T): OperationResult<T> {
    return {
      success: false,
      data: fallbackData,
      userMessage: userMessage,
      errorMessage: userMessage,
      stage: stage
    } as OperationResult<T>
  }

  private static copyFailureAsVoid<T>(result: OperationResult<T>, stage: string): OperationResult<void> {
    return {
      success: result.success,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      userMessage: result.userMessage,
      isAdminMissing: result.isAdminMissing,
      suggestion: result.suggestion,
      stage: stage
    } as OperationResult<void>
  }
}
