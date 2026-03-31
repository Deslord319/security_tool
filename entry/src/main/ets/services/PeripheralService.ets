import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { networkManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { AppInfo } from '../constants/AppConstants'
import { OperationResult } from '../models/DataModels'
import { EnterpriseAdminService } from './EnterpriseAdminService'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'

const TAG = 'PeripheralService'
const DOMAIN = 0x0002

const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

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
      hilog.info(DOMAIN, TAG, `setInterfaceDisabled: ${feature} = ${disallow}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set interface disabled policy', err as Object)
    }
  }

  static getInterfaceDisabledWithResult(feature: string): OperationResult<boolean> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.getNetworkInterfaceDisabledWithResult()
    }

    try {
      const disabled = restrictions.getDisallowedPolicy(ADMIN_WANT, feature)
      hilog.info(DOMAIN, TAG, `getInterfaceDisabledWithResult success: feature=${feature}, disabled=${disabled}`)
      return {
        success: true,
        data: disabled
      } as OperationResult<boolean>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('get interface disabled status', err as Object, false)
    }
  }

  static setUsbStoragePolicyWithResult(policy: usbManager.UsbPolicy): OperationResult<void> {
    try {
      usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, policy)
      hilog.info(DOMAIN, TAG, `setUsbStoragePolicy: ${policy}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set usb storage policy', err as Object)
    }
  }

  static getUsbStoragePolicyWithResult(): OperationResult<usbManager.UsbPolicy> {
    try {
      const policy = usbManager.getUsbStorageDeviceAccessPolicy(ADMIN_WANT)
      hilog.info(DOMAIN, TAG, `getUsbStoragePolicyWithResult success: policy=${policy}`)
      return {
        success: true,
        data: policy
      } as OperationResult<usbManager.UsbPolicy>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<usbManager.UsbPolicy>(
        'get usb storage policy',
        err as Object,
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
      hilog.info(
        DOMAIN,
        TAG,
        `setUsbStoragePolicyWithCleanupResult start: targetPolicy=${policy}, currentStoragePolicy=${snapshotResult.data?.storagePolicy}`
      )
      usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, policy)
      hilog.info(DOMAIN, TAG, `setUsbStoragePolicyWithCleanupResult success: ${policy}`)
      return {
        success: true,
        userMessage: 'USB storage policy updated',
        stage: 'completed'
      } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicyWithCleanupResult failed: ${JSON.stringify(err)}`)
      if (CommonErrorUtils.extractErrorCode(err as Object) === 9200010) {
        return PeripheralService.buildUserFailureResult<void>(
          'set_usb_storage_policy',
          'system detected usb policy conflict'
        )
      }
      return PeripheralService.buildFailureResult<void>('set usb storage policy', err as Object)
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
      hilog.error(DOMAIN, TAG, `setNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set network interface status', err as Object)
    }
  }

  private static getNetworkInterfaceDisabledWithResult(): OperationResult<boolean> {
    try {
      const interfaces: string[] = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
      if (interfaces.length === 0) {
        hilog.info(DOMAIN, TAG, 'getNetworkInterfaceDisabledWithResult success: interfaceCount=0, allDisabled=false')
        return { success: true, data: false } as OperationResult<boolean>
      }
      let allDisabled = true
      for (let i = 0; i < interfaces.length; i++) {
        if (!networkManager.isNetworkInterfaceDisabledSync(ADMIN_WANT, interfaces[i])) {
          allDisabled = false
          break
        }
      }
      hilog.info(
        DOMAIN,
        TAG,
        `getNetworkInterfaceDisabledWithResult success: interfaceCount=${interfaces.length}, allDisabled=${allDisabled}`
      )
      return { success: true, data: allDisabled } as OperationResult<boolean>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('get network interface status', err as Object, false)
    }
  }

  private static setUsbInterfaceDisabledWithCleanup(disallow: boolean): OperationResult<void> {
    const snapshotResult = PeripheralService.getUsbConflictSnapshot()
    if (!snapshotResult.success) {
      return PeripheralService.copyFailureAsVoid(snapshotResult, 'read_usb_storage_policy')
    }
    const snapshot = snapshotResult.data!
    hilog.info(
      DOMAIN,
      TAG,
      `setUsbInterfaceDisabledWithCleanup start: disallow=${disallow}, storagePolicy=${snapshot.storagePolicy}`
    )

    if (snapshot.storagePolicy !== usbManager.UsbPolicy.READ_WRITE) {
      const resetResult = PeripheralService.resetUsbStoragePolicyToReadWrite()
      if (!resetResult.success) {
        return resetResult
      }
    }

    try {
      restrictions.setDisallowedPolicy(ADMIN_WANT, PeripheralService.FEATURE_USB, disallow)
      hilog.info(DOMAIN, TAG, `setUsbInterfaceDisabledWithCleanup success: disallow=${disallow}`)
      return {
        success: true,
        userMessage: 'usb interface policy updated',
        stage: 'completed'
      } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbInterfaceDisabledWithCleanup failed: ${JSON.stringify(err)}`)
      if (CommonErrorUtils.extractErrorCode(err as Object) === 9200010) {
        return PeripheralService.buildUserFailureResult<void>(
          'set_usb_interface',
          'system detected usb interface conflict'
        )
      }
      return PeripheralService.buildFailureResult<void>('set usb interface', err as Object)
    }
  }

  private static getUsbConflictSnapshot(): OperationResult<UsbConflictSnapshot> {
    const storagePolicyResult = PeripheralService.getUsbStoragePolicyWithResult()
    if (!storagePolicyResult.success) {
      return {
        success: false,
        errorCode: storagePolicyResult.errorCode,
        errorMessage: storagePolicyResult.errorMessage,
        userMessage: 'failed to read usb storage policy',
        suggestion: storagePolicyResult.suggestion,
        isAdminMissing: storagePolicyResult.isAdminMissing,
        stage: 'read_usb_storage_policy'
      } as OperationResult<UsbConflictSnapshot>
    }

    hilog.info(
      DOMAIN,
      TAG,
      `getUsbConflictSnapshot success: storagePolicy=${storagePolicyResult.data ?? usbManager.UsbPolicy.READ_WRITE}`
    )
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
      hilog.info(DOMAIN, TAG, 'resetUsbStoragePolicyToReadWrite success')
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `resetUsbStoragePolicyToReadWrite failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildUserFailureResult<void>(
        'reset_usb_storage_policy',
        'failed to restore usb storage policy to read-write'
      )
    }
  }

  static buildFailureResult<T>(action: string, err: Object, fallbackData?: T): OperationResult<T> {
    const code = CommonErrorUtils.extractErrorCode(err)
    const isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    const message = isAdminMissing
      ? 'enterprise admin is not enabled'
      : `${action} failed`
    const suggestion = isAdminMissing
      ? `please enable admin first: ${EnterpriseAdminService.buildEnableCommand()}`
      : 'please check permissions, signature and device policy state before retrying'
    return {
      success: false,
      data: fallbackData,
      errorCode: code,
      errorMessage: message,
      isAdminMissing: isAdminMissing,
      suggestion: suggestion
    } as OperationResult<T>
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
