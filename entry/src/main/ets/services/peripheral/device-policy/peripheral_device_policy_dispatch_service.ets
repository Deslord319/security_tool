import restrictions from '@ohos.enterprise.restrictions'
import { bluetoothManager, usbManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import {
  OperationResult,
  PeripheralDevicePolicy,
  PeripheralType,
  getUsbPeripheralBaseClass,
  isUsbPeripheralType
} from '../../../models/DataModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { EnterpriseAdminService } from '../../admin/activation/EnterpriseAdminService'
import { LogUtils } from '../../../utils/LogUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'

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

const TAG = 'PeripheralDevicePolicyDispatchService'

export class PeripheralDevicePolicyDispatchService {
  static async dispatch(request: PeripheralPolicyDispatchRequest): Promise<PeripheralPolicyDispatchResult> {
    if (!PeripheralDevicePolicyDispatchService.isSupportedPolicy(request.policy)) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('unsupported_policy')
    }

    if (isUsbPeripheralType(request.deviceType)) {
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

  private static async dispatchBluetoothPolicy(request: PeripheralPolicyDispatchRequest): Promise<PeripheralPolicyDispatchResult> {
    const bluetoothDisabledResult = PeripheralDevicePolicyDispatchService.getBluetoothDisabledState()
    if (!bluetoothDisabledResult.success) {
      return PeripheralDevicePolicyDispatchService.copyFailureResult(bluetoothDisabledResult, 'bluetooth_dispatch_failed')
    }
    if (bluetoothDisabledResult.data === true) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('bluetooth_conflict_global_disabled')
    }

    const bluetoothDeviceId = PeripheralDevicePolicyDispatchService.toBluetoothDeviceId(request.deviceId)
    if (!bluetoothDeviceId) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('bluetooth_dispatch_failed')
    }

    if (request.policy === 'deny') {
      return PeripheralDevicePolicyDispatchService.dispatchBluetoothDeny(bluetoothDeviceId)
    }
    return PeripheralDevicePolicyDispatchService.dispatchBluetoothAllow(bluetoothDeviceId)
  }

  private static dispatchBluetoothAllow(deviceId: string): PeripheralPolicyDispatchResult {
    return PeripheralDevicePolicyDispatchService.tryRunOperation(
      () => {
        const disallowed = bluetoothManager.getDisallowedBluetoothDevices(ADMIN_WANT)
        if (PeripheralDevicePolicyDispatchService.containsBluetoothDeviceId(disallowed, deviceId)) {
          bluetoothManager.removeDisallowedBluetoothDevices(ADMIN_WANT, [deviceId])
        }
      },
      'bluetooth',
      'bluetooth_dispatch_conflict_unresolved'
    )
  }

  private static dispatchBluetoothDeny(deviceId: string): PeripheralPolicyDispatchResult {
    return PeripheralDevicePolicyDispatchService.tryRunOperation(
      () => {
        const disallowed = bluetoothManager.getDisallowedBluetoothDevices(ADMIN_WANT)
        if (!PeripheralDevicePolicyDispatchService.containsBluetoothDeviceId(disallowed, deviceId)) {
          bluetoothManager.addDisallowedBluetoothDevices(ADMIN_WANT, [deviceId])
        }
      },
      'bluetooth',
      'bluetooth_dispatch_conflict_unresolved'
    )
  }

  private static dispatchUsbAllow(request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult {
    const usbDeviceType = PeripheralDevicePolicyDispatchService.toUsbDeviceType(request.deviceType)
    if (usbDeviceType) {
      return PeripheralDevicePolicyDispatchService.tryRunOperation(
        () => {
          const disallowed = usbManager.getDisallowedUsbDevices(ADMIN_WANT)
          if (PeripheralDevicePolicyDispatchService.containsUsbDeviceType(disallowed, usbDeviceType)) {
            usbManager.removeDisallowedUsbDevices(ADMIN_WANT, [usbDeviceType])
          }
        },
        'usb',
        'usb_dispatch_conflict_unresolved'
      )
    }

    return { success: true } as PeripheralPolicyDispatchResult
  }

  private static dispatchUsbDeny(request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult {
    const usbDeviceType = PeripheralDevicePolicyDispatchService.toUsbDeviceType(request.deviceType)
    if (!usbDeviceType) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult('unsupported_device_type')
    }

    return PeripheralDevicePolicyDispatchService.tryRunOperation(
      () => {
        usbManager.addDisallowedUsbDevices(ADMIN_WANT, [usbDeviceType])
      },
      'usb',
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
      return PeripheralDevicePolicyDispatchService.buildOperationFailureResult<boolean>('read usb disabled state', err as ErrorLike, false)
    }
  }

  private static getBluetoothDisabledState(): OperationResult<boolean> {
    try {
      return {
        success: true,
        data: restrictions.getDisallowedPolicy(ADMIN_WANT, 'bluetooth')
      } as OperationResult<boolean>
    } catch (err) {
      LogUtils.error(TAG, `getBluetoothDisabledState failed: ${JSON.stringify(err)}`)
      return PeripheralDevicePolicyDispatchService.buildOperationFailureResult<boolean>(
        'read bluetooth disabled state',
        err as ErrorLike,
        false
      )
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
        err as ErrorLike,
        usbManager.UsbPolicy.READ_WRITE
      )
    }
  }

  private static toUsbDeviceType(deviceType: PeripheralType): usbManager.UsbDeviceType | null {
    const baseClass = getUsbPeripheralBaseClass(deviceType)
    return baseClass === null ? null : PeripheralDevicePolicyDispatchService.buildUsbDeviceType(baseClass)
  }

  private static toBluetoothDeviceId(deviceId: string): string | null {
    const normalized = deviceId.trim().replace(/^MAC:\s*/i, '').replace(/-/g, ':').toUpperCase()
    if (!/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/.test(normalized)) {
      return null
    }
    return normalized
  }

  private static buildUsbDeviceType(baseClass: number): usbManager.UsbDeviceType {
    return {
      baseClass: baseClass,
      subClass: 0,
      protocol: 0,
      descriptor: usbManager.Descriptor.INTERFACE
    } as usbManager.UsbDeviceType
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

  private static containsBluetoothDeviceId(items: string[], target: string): boolean {
    return items.some((item: string) => {
      return PeripheralDevicePolicyDispatchService.toBluetoothDeviceId(item) === target
    })
  }

  private static tryRunOperation(
    action: () => void,
    channel: 'usb' | 'bluetooth',
    conflictReason: PeripheralPolicyDispatchReason
  ): PeripheralPolicyDispatchResult {
    try {
      action()
      return { success: true } as PeripheralPolicyDispatchResult
    } catch (err) {
      const error = err as ErrorLike
      const code = CommonErrorUtils.extractErrorCode(error)
      const defaultReason: PeripheralPolicyDispatchReason = channel === 'usb' ? 'usb_dispatch_failed' : 'bluetooth_dispatch_failed'
      const adminMissing = EnterpriseAdminService.isAdminMissingError(error)
      LogUtils.error(TAG, `${channel} dispatch failed: code=${code ?? -1}, message=${CommonErrorUtils.extractErrorMessage(error)}`)
      return {
        success: false,
        reason: code === 9200010 ? conflictReason : defaultReason,
        errorCode: code,
        errorMessage: CommonErrorUtils.extractErrorMessage(error),
        isAdminMissing: adminMissing,
        suggestion: adminMissing
          ? EnterpriseAdminService.buildEnableCommand()
          : undefined,
        stage: 'device_policy_dispatch'
      } as PeripheralPolicyDispatchResult
    }
  }

  private static buildOperationFailureResult<T>(
    action: string,
    err: ErrorLike,
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
