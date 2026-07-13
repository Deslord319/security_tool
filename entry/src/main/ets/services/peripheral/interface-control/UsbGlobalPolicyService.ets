import { usbManager } from '@kit.MDMKit'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { OperationResult } from '../../../models/CommonModels'
import { PeripheralInterfaceFeatures } from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { UsbDevicePolicyStateService } from '../device-policy/UsbDevicePolicyStateService'
import {
  CurrentUsbDeviceSnapshot,
  PeripheralPolicySnapshotTraceService
} from '../connection-record/PeripheralPolicySnapshotTraceService'
import { PeripheralService } from './PeripheralService'

const TAG = 'UsbGlobalPolicyService'
const USB_FIRST_REENUMERATION_WAIT_MS = 500
const USB_SECOND_REENUMERATION_WAIT_MS = 1000

export class UsbGlobalPolicyService {
  static async setDisabled(disallow: boolean): Promise<OperationResult<void>> {
    let connectedDevices: CurrentUsbDeviceSnapshot[] = []
    if (disallow) {
      const storageResult = PeripheralService.getUsbStoragePolicyWithResult()
      if (!storageResult.success) {
        return {
          success: false,
          errorCode: storageResult.errorCode,
          errorMessage: storageResult.errorMessage,
          stage: storageResult.stage
        } as OperationResult<void>
      }
      if (storageResult.data !== usbManager.UsbPolicy.READ_WRITE) {
        return UsbGlobalPolicyService.failure(PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT)
      }
      if (!await UsbDevicePolicyStateService.suspendActivePolicies()) {
        return UsbGlobalPolicyService.failure(PeripheralReasonCodes.USB_DISPATCH_FAILED)
      }
      connectedDevices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
    }

    const result = PeripheralService.setInterfaceDisabledWithResult(PeripheralInterfaceFeatures.USB, disallow)
    if (!result.success) {
      if (disallow) {
        await UsbDevicePolicyStateService.restorePresentDeniedPolicies()
      }
      return result
    }

    if (!disallow && !await UsbDevicePolicyStateService.restorePresentDeniedPolicies()) {
      LogUtils.warn(TAG, 'USB global policy enabled with partial device deny restore failure')
    }
    if (disallow) {
      const snapshotResult = await PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot(
        connectedDevices
      )
      if (!snapshotResult.success) {
        LogUtils.warn(TAG, `append USB global policy snapshot failed: code=${snapshotResult.code}`)
      }
    } else {
      await UsbGlobalPolicyService.waitForUsbReenumeration(USB_FIRST_REENUMERATION_WAIT_MS)
      let enabledDevices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      if (enabledDevices.length === 0) {
        await UsbGlobalPolicyService.waitForUsbReenumeration(USB_SECOND_REENUMERATION_WAIT_MS)
        enabledDevices = PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices()
      }
      const snapshotResult = await PeripheralPolicySnapshotTraceService.appendUsbGlobalEnabledSnapshot(
        enabledDevices
      )
      if (!snapshotResult.success) {
        LogUtils.warn(TAG, `append USB global enabled snapshot failed: code=${snapshotResult.code}`)
      }
    }
    return result
  }

  private static async waitForUsbReenumeration(delayMs: number): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, delayMs)
    })
  }

  private static failure(stage: string): OperationResult<void> {
    return {
      success: false,
      stage: stage,
      errorMessage: stage
    } as OperationResult<void>
  }
}
