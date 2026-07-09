import { usbManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { PeripheralErrorCodes } from '../../../constants/SystemErrorCodes'
import { OperationResult } from '../../../models/CommonModels'
import {
  PeripheralDevicePolicy,
  PeripheralType,
  getUsbPeripheralBaseClass,
  isUsbPeripheralType
} from '../../../models/PeripheralModels'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { EnterpriseAdminService } from '../../admin/activation/EnterpriseAdminService'
import { LogUtils } from '../../../utils/LogUtils'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'

export type PeripheralPolicyDispatchReason =
  'unsupported_device_type' |
  'unsupported_policy' |
  'dispatch_not_implemented' |
  'usb_conflict_account_storage' |
  'usb_dispatch_failed' |
  'usb_dispatch_conflict_unresolved' |
  'device_offline'

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
      return PeripheralDevicePolicyDispatchService.buildFailureResult(
        PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH as PeripheralPolicyDispatchReason
      )
    }

    if (isUsbPeripheralType(request.deviceType)) {
      return PeripheralDevicePolicyDispatchService.dispatchUsbPolicy(request)
    }

    return PeripheralDevicePolicyDispatchService.buildFailureResult(
      PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH as PeripheralPolicyDispatchReason
    )
  }

  private static isSupportedPolicy(policy: PeripheralDevicePolicy): boolean {
    return policy === 'allow' || policy === 'deny'
  }

  private static async dispatchUsbPolicy(
    request: PeripheralPolicyDispatchRequest
  ): Promise<PeripheralPolicyDispatchResult> {
    if (request.deviceType === PeripheralType.USB_STORAGE) {
      const storagePolicyResult = PeripheralDevicePolicyDispatchService.getUsbStoragePolicy()
      if (!storagePolicyResult.success) {
        return PeripheralDevicePolicyDispatchService.copyFailureResult(
          storagePolicyResult,
          PeripheralReasonCodes.USB_DISPATCH_FAILED as PeripheralPolicyDispatchReason
        )
      }
      if (storagePolicyResult.data === usbManager.UsbPolicy.DISABLED) {
        return PeripheralDevicePolicyDispatchService.buildFailureResult(
          PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE as PeripheralPolicyDispatchReason
        )
      }
    }

    if (request.policy === 'deny') {
      return PeripheralDevicePolicyDispatchService.dispatchUsbDeny(request)
    }
    return PeripheralDevicePolicyDispatchService.dispatchUsbAllow(request)
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
        PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED as PeripheralPolicyDispatchReason
      )
    }

    return { success: true } as PeripheralPolicyDispatchResult
  }

  private static dispatchUsbDeny(request: PeripheralPolicyDispatchRequest): PeripheralPolicyDispatchResult {
    const usbDeviceType = PeripheralDevicePolicyDispatchService.toUsbDeviceType(request.deviceType)
    if (!usbDeviceType) {
      return PeripheralDevicePolicyDispatchService.buildFailureResult(
        PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH as PeripheralPolicyDispatchReason
      )
    }

    return PeripheralDevicePolicyDispatchService.tryRunOperation(
      () => {
        usbManager.addDisallowedUsbDevices(ADMIN_WANT, [usbDeviceType])
      },
      'usb',
      PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED as PeripheralPolicyDispatchReason
    )
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

  private static tryRunOperation(
    action: () => void,
    channel: 'usb',
    conflictReason: PeripheralPolicyDispatchReason
  ): PeripheralPolicyDispatchResult {
    try {
      action()
      return { success: true } as PeripheralPolicyDispatchResult
    } catch (err) {
      const error = err as ErrorLike
      const code = CommonErrorUtils.extractErrorCode(error)
      const adminMissing = EnterpriseAdminService.isAdminMissingError(error)
      LogUtils.error(TAG, `${channel} dispatch failed: code=${code ?? -1}, message=${CommonErrorUtils.extractErrorMessage(error)}`)
      return {
        success: false,
        reason: code === PeripheralErrorCodes.POLICY_CONFLICT
          ? conflictReason
          : PeripheralReasonCodes.USB_DISPATCH_FAILED as PeripheralPolicyDispatchReason,
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
