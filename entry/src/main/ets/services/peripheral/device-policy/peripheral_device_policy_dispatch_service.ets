import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { Want } from '@kit.AbilityKit'
import { AppInfo } from '../../../constants/AppConstants'
import { OperationResult, PeripheralDevicePolicy, PeripheralType, parseUsbDeviceId } from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { EnterpriseAdminService } from '../../admin/activation/EnterpriseAdminService'
import { LogUtils } from '../../../utils/LogUtils'

export type PeripheralPolicyDispatchReason =
  'unsupported_device_type' |
  'unsupported_policy' |
  'dispatch_not_implemented' |
  'usb_conflict_global_disabled' |
  'usb_conflict_account_storage' |
  'usb_dispatch_failed' |
  'usb_dispatch_conflict_unresolved' |
  'bluetooth_conflict_global_disabled' |
  'bluetooth_dispatch_failed' |
  'bluetooth_dispatch_conflict_unresolved'

export interface PeripheralPolicyDispatchRequest {
  deviceId: string
  deviceType: PeripheralType
  policy: PeripheralDevicePolicy
}

export interface PeripheralPolicyDispatchResult extends OperationResult<void> {
  reason?: PeripheralPolicyDispatchReason
}

const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}
const TAG = 'PeripheralDevicePolicyDispatchService'

export class PeripheralDevicePolicyDispatchService {
  static async dispatch(request: PeripheralPolicyDispatchRequest): Promise<PeripheralPolicyDispatchResult> {
    if (!PeripheralDevicePolicyDispatchService.isSupportedPolicy(request.policy)) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('unsupported_policy')
    }

    if (PeripheralDevicePolicyDispatchService.isUsbType(request.deviceType)) {
      return PeripheralDevicePolicyDispatchService.dispatchUsbPolicy(request)
    }

    if (request.deviceType === PeripheralType.BLUETOOTH) {
      return PeripheralDevicePolicyDispatchService.dispatchBluetoothPolicy(request)
    }

    return PeripheralDevicePolicyDispatchService.buildFailureResult('unsupported_device_type')
  }

  private static isSupportedPolicy(policy: PeripheralDevicePolicy): boolean {
    return policy === 'allow' || policy === 'deny'
  }

  private static isUsbType(deviceType: PeripheralType): boolean {
    switch (deviceType) {
      case PeripheralType.USB_STORAGE:
      case PeripheralType.USB_CAMERA:
      case PeripheralType.USB_PRINTER:
      case PeripheralType.USB_HID:
      case PeripheralType.USB_OTHER:
        return true
      default:
        return false
    }
  }

  private static async dispatchUsbPolicy(
    request: PeripheralPolicyDispatchRequest
  ): Promise<PeripheralPolicyDispatchResult> {
    const usbDisabledResult = PeripheralDevicePolicyDispatchService.getUsbDisabledState()
    if (!usbDisabledResult.success) {
      return PeripheralDevicePolicyDispatchService.copyFailureResult(usbDisabledResult, 'usb_dispatch_failed')
    }
    if (usbDisabledResult.data === true) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('usb_conflict_global_disabled')
    }

    if (request.policy === 'allow' && request.deviceType === PeripheralType.USB_STORAGE) {
      const storagePolicyResult = PeripheralDevicePolicyDispatchService.getUsbStoragePolicy()
      if (!storagePolicyResult.success) {
        return PeripheralDevicePolicyDispatchService.copyFailureResult(storagePolicyResult, 'usb_dispatch_failed')
      }
      if (storagePolicyResult.data === usbManager.UsbPolicy.DISABLED) {
        return PeripheralDevicePolicyDispatchService.buildFailureResult('usb_conflict_account_storage')
      }
    }

    if (request.policy === 'deny') {
      return PeripheralDevicePolicyDispatchService.dispatchUsbDeny(request)
    }
    return PeripheralDevicePolicyDispatchService.dispatchUsbAllow(request)
  }

  private static async dispatchBluetoothPolicy(_request: PeripheralPolicyDispatchRequest): Promise<PeripheralPolicyDispatchResult> {
    return PeripheralDevicePolicyDispatchService.buildFailureResult('dispatch_not_implemented')
  }

  private static dispatchUsbAllow(request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult {
    const usbDeviceId = PeripheralDevicePolicyDispatchService.toUsbDeviceId(request.deviceId)
    if (!usbDeviceId) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('usb_dispatch_failed')
    }

    const usbDeviceType = PeripheralDevicePolicyDispatchService.toUsbDeviceType(request.deviceType)
    if (usbDeviceType) {
      const removeResult = PeripheralDevicePolicyDispatchService.tryRunUsbOperation(() => {
        const disallowed = usbManager.getDisallowedUsbDevices(ADMIN_WANT)
        if (PeripheralDevicePolicyDispatchService.containsUsbDeviceType(disallowed, usbDeviceType)) {
          usbManager.removeDisallowedUsbDevices(ADMIN_WANT, [usbDeviceType])
        }
      })
      if (!removeResult.success) {
        return removeResult
      }
    }

    return PeripheralDevicePolicyDispatchService.tryRunUsbOperation(
      () => {
        usbManager.addAllowedUsbDevices(ADMIN_WANT, [usbDeviceId])
      },
      'usb_dispatch_conflict_unresolved'
    )
  }

  private static dispatchUsbDeny(request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult {
    const usbDeviceType = PeripheralDevicePolicyDispatchService.toUsbDeviceType(request.deviceType)
    if (!usbDeviceType) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('unsupported_device_type')
    }

    const usbDeviceId = PeripheralDevicePolicyDispatchService.toUsbDeviceId(request.deviceId)
    if (usbDeviceId) {
      const removeResult = PeripheralDevicePolicyDispatchService.tryRunUsbOperation(() => {
        const allowed = usbManager.getAllowedUsbDevices(ADMIN_WANT)
        if (PeripheralDevicePolicyDispatchService.containsUsbDeviceId(allowed, usbDeviceId)) {
          usbManager.removeAllowedUsbDevices(ADMIN_WANT, [usbDeviceId])
        }
      })
      if (!removeResult.success) {
        return removeResult
      }
    }

    return PeripheralDevicePolicyDispatchService.tryRunUsbOperation(
      () => {
        usbManager.addDisallowedUsbDevices(ADMIN_WANT, [usbDeviceType])
      },
      'usb_dispatch_conflict_unresolved'
    )
  }

  private static getUsbDisabledState(): OperationResult<boolean> {
    try {
      return {
        success: true,
        data: restrictions.getDisallowedPolicy(ADMIN_WANT, 'usb')
      } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getUsbDisabledState failed: ${JSON.stringify(err)}`)
      return PeripheralDevicePolicyDispatchService.buildOperationFailureResult<boolean>('read usb disabled state', err as Object, false)
    }
  }

  private static getUsbStoragePolicy(): OperationResult<usbManager.UsbPolicy> {
    try {
      return {
        success: true,
        data: usbManager.getUsbStorageDeviceAccessPolicy(ADMIN_WANT)
      } as OperationResult<usbManager.UsbPolicy>
    } catch (err) {
      LogUtils.error(TAG, `getUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralDevicePolicyDispatchService.buildOperationFailureResult<usbManager.UsbPolicy>(
        'read usb storage policy',
        err as Object,
        usbManager.UsbPolicy.READ_WRITE
      )
    }
  }

  private static toUsbDeviceId(deviceId: string): usbManager.UsbDeviceId | null {
    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      return null
    }
    return {
      vendorId: parsed.vendorId,
      productId: parsed.productId
    } as usbManager.UsbDeviceId
  }

  private static toUsbDeviceType(deviceType: PeripheralType): usbManager.UsbDeviceType | null {
    switch (deviceType) {
      case PeripheralType.USB_STORAGE:
        return PeripheralDevicePolicyDispatchService.buildUsbDeviceType(0x08)
      case PeripheralType.USB_CAMERA:
        return PeripheralDevicePolicyDispatchService.buildUsbDeviceType(0x0E)
      case PeripheralType.USB_PRINTER:
        return PeripheralDevicePolicyDispatchService.buildUsbDeviceType(0x07)
      case PeripheralType.USB_HID:
        return PeripheralDevicePolicyDispatchService.buildUsbDeviceType(0x03)
      case PeripheralType.USB_OTHER:
        return null
      default:
        return null
    }
  }

  private static buildUsbDeviceType(baseClass: number): usbManager.UsbDeviceType {
    return {
      baseClass: baseClass,
      subClass: 0,
      protocol: 0,
      descriptor: usbManager.Descriptor.INTERFACE
    } as usbManager.UsbDeviceType
  }

  private static containsUsbDeviceId(items: usbManager.UsbDeviceId[], target: usbManager.UsbDeviceId): boolean {
    return items.some((item: usbManager.UsbDeviceId) => {
      return item.vendorId === target.vendorId && item.productId === target.productId
    })
  }

  private static containsUsbDeviceType(
    items: usbManager.UsbDeviceType[],
    target: usbManager.UsbDeviceType
  ): boolean {
    return items.some((item: usbManager.UsbDeviceType) => {
      return item.baseClass === target.baseClass &&
        item.subClass === target.subClass &&
        item.protocol === target.protocol &&
        item.descriptor === target.descriptor
    })
  }

  private static tryRunUsbOperation(
    action: () => void,
    conflictReason: PeripheralPolicyDispatchReason = 'usb_dispatch_failed'
  ): PeripheralPolicyDispatchResult {
    try {
      action()
      return { success: true } as PeripheralPolicyDispatchResult
    } catch (err) {
      const error = err as Object
      const code = CommonErrorUtils.extractErrorCode(error)
      LogUtils.error(TAG, `usb dispatch failed: code=${code ?? -1}, message=${CommonErrorUtils.extractErrorMessage(error)}`)
      return {
        success: false,
        reason: code === 9200010 ? conflictReason : 'usb_dispatch_failed',
        errorCode: code,
        errorMessage: CommonErrorUtils.extractErrorMessage(error),
        isAdminMissing: EnterpriseAdminService.isAdminMissingError(error),
        suggestion: EnterpriseAdminService.isAdminMissingError(error)
          ? EnterpriseAdminService.buildEnableCommand()
          : undefined,
        stage: 'device_policy_dispatch'
      } as PeripheralPolicyDispatchResult
    }
  }

  private static buildOperationFailureResult<T>(
    action: string,
    err: Object,
    fallbackData?: T
  ): OperationResult<T> {
    const code = CommonErrorUtils.extractErrorCode(err)
    return {
      success: false,
      data: fallbackData,
      errorCode: code,
      errorMessage: CommonErrorUtils.extractErrorMessage(err),
      isAdminMissing: EnterpriseAdminService.isAdminMissingError(err),
      suggestion: EnterpriseAdminService.isAdminMissingError(err)
        ? EnterpriseAdminService.buildEnableCommand()
        : `please check ${action}`
    } as OperationResult<T>
  }

  private static copyFailureResult(
    result: OperationResult<void> | OperationResult<boolean> | OperationResult<usbManager.UsbPolicy>,
    reason: PeripheralPolicyDispatchReason
  ): PeripheralPolicyDispatchResult {
    return {
      success: false,
      reason: reason,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      isAdminMissing: result.isAdminMissing,
      suggestion: result.suggestion,
      stage: 'device_policy_dispatch'
    } as PeripheralPolicyDispatchResult
  }

  private static buildFailureResult(reason: PeripheralPolicyDispatchReason): PeripheralPolicyDispatchResult {
    return {
      success: false,
      reason: reason,
      stage: 'device_policy_dispatch',
      errorMessage: reason
    } as PeripheralPolicyDispatchResult
  }
}
