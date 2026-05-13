import { LogUtils } from '../../../utils/LogUtils'
import restrictions from '@ohos.enterprise.restrictions'
import { networkManager, usbManager } from '@kit.MDMKit'

import { ADMIN_WANT } from '../../../constants/AppConstants'
import { PeripheralServiceErrorStrings } from '../../../constants/modules/PeripheralErrorStrings'
import { PeripheralErrorCodes } from '../../../constants/SystemErrorCodes'
import { OperationResult } from '../../../models/CommonModels'
import { OperationResultUtils } from '../../common/OperationResultUtils'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'

const TAG = 'PeripheralService'

interface UsbConflictSnapshot {
  storagePolicy: usbManager.UsbPolicy
}

export class PeripheralService {
  static readonly FEATURE_USB: string = 'usb'
  static readonly FEATURE_BLUETOOTH: string = 'bluetooth'
  static readonly FEATURE_WIFI: string = 'wifi'
  static readonly FEATURE_HDC: string = 'hdc'
  static readonly FEATURE_NETWORK: string = 'network'
  static readonly FEATURE_PRINTER: string = 'printer'
  static readonly FEATURE_MICROPHONE: string = 'microphone'
  static readonly FEATURE_CAMERA: string = 'camera'

  static setInterfaceDisabledWithResult(feature: string, disallow: boolean): OperationResult<void> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.setNetworkInterfaceDisabledWithResult(disallow)
    }
    if (feature === PeripheralService.FEATURE_USB) {
      return PeripheralService.setUsbInterfaceDisabledWithCleanup(disallow)
    }

    try {
      restrictions.setDisallowedPolicy(ADMIN_WANT, feature, disallow)
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set interface disabled policy', err as ErrorLike)
    }
  }

  static getInterfaceDisabledWithResult(feature: string): OperationResult<boolean> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.getNetworkInterfaceDisabledWithResult()
    }

    try {
      const disabled = restrictions.getDisallowedPolicy(ADMIN_WANT, feature)
      return {
        success: true,
        data: disabled
      } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('get interface disabled status', err as ErrorLike, false)
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
      return PeripheralService.buildFailureResult<usbManager.UsbPolicy>(
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
      return PeripheralService.buildFailureResult<void>('set usb storage policy', err as ErrorLike)
    }
  }

  private static setNetworkInterfaceDisabledWithResult(disallow: boolean): OperationResult<void> {
    try {
      const interfaces: string[] = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
      for (let i = 0; i < interfaces.length; i++) {
        networkManager.setNetworkInterfaceDisabledSync(ADMIN_WANT, interfaces[i], disallow)
      }
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set network interface status', err as ErrorLike)
    }
  }

  private static getNetworkInterfaceDisabledWithResult(): OperationResult<boolean> {
    try {
      const interfaces: string[] = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
      if (interfaces.length === 0) {
        return { success: true, data: false } as OperationResult<boolean>
      }
      let allDisabled = true
      for (let i = 0; i < interfaces.length; i++) {
        if (!networkManager.isNetworkInterfaceDisabledSync(ADMIN_WANT, interfaces[i])) {
          allDisabled = false
          break
        }
      }
      return { success: true, data: allDisabled } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('get network interface status', err as ErrorLike, false)
    }
  }

  private static setUsbInterfaceDisabledWithCleanup(disallow: boolean): OperationResult<void> {
    const snapshotResult = PeripheralService.getUsbConflictSnapshot()
    if (!snapshotResult.success) {
      return PeripheralService.copyFailureAsVoid(snapshotResult, 'read_usb_storage_policy')
    }
    const snapshot = snapshotResult.data!
    if (snapshot.storagePolicy !== usbManager.UsbPolicy.READ_WRITE) {
      const resetResult = PeripheralService.resetUsbStoragePolicyToReadWrite()
      if (!resetResult.success) {
        return resetResult
      }
    }

    try {
      restrictions.setDisallowedPolicy(ADMIN_WANT, PeripheralService.FEATURE_USB, disallow)
      return {
        success: true,
        userMessage: PeripheralServiceErrorStrings.USB_INTERFACE_POLICY_UPDATED,
        stage: 'completed'
      } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `setUsbInterfaceDisabledWithCleanup failed: ${JSON.stringify(err)}`)
      if (CommonErrorUtils.extractErrorCode(err as ErrorLike) === PeripheralErrorCodes.POLICY_CONFLICT) {
        return PeripheralService.buildUserFailureResult<void>(
          'set_usb_interface',
          PeripheralServiceErrorStrings.USB_INTERFACE_CONFLICT
        )
      }
      return PeripheralService.buildFailureResult<void>('set usb interface', err as ErrorLike)
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

  private static resetUsbStoragePolicyToReadWrite(): OperationResult<void> {
    try {
      usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, usbManager.UsbPolicy.READ_WRITE)
      return { success: true } as OperationResult<void>
    } catch (err) {
      LogUtils.error(TAG, `resetUsbStoragePolicyToReadWrite failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildUserFailureResult<void>(
        'reset_usb_storage_policy',
        PeripheralServiceErrorStrings.RESTORE_USB_STORAGE_READ_WRITE_FAILED
      )
    }
  }

  static buildFailureResult<T>(action: string, err: ErrorLike, fallbackData?: T): OperationResult<T> {
    return OperationResultUtils.buildFailureResult(action, err, fallbackData)
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
