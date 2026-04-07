import { LogUtils } from '../../../utils/LogUtils'
import { OperationResult, PeripheralDevicePolicy, PeripheralType } from '../../../models/DataModels'

const TAG = 'PeripheralDevicePolicyDispatchService'

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
    LogUtils.warn(
      TAG,
      `dispatchUsbPolicy not implemented yet: deviceId=${request.deviceId}, deviceType=${request.deviceType}, policy=${request.policy}`
    )
    return PeripheralDevicePolicyDispatchService.buildFailureResult('dispatch_not_implemented')
  }

  private static async dispatchBluetoothPolicy(
    request: PeripheralPolicyDispatchRequest
  ): Promise<PeripheralPolicyDispatchResult> {
    LogUtils.warn(
      TAG,
      `dispatchBluetoothPolicy not implemented yet: deviceId=${request.deviceId}, deviceType=${request.deviceType}, policy=${request.policy}`
    )
    return PeripheralDevicePolicyDispatchService.buildFailureResult('dispatch_not_implemented')
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
