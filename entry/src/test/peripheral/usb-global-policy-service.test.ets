import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { OperationResult } from '../../main/ets/models/CommonModels'
import { PeripheralInterfaceFeature, PeripheralInterfaceFeatures } from '../../main/ets/models/PeripheralModels'
import { PeripheralReasonCodes } from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { UsbGlobalPolicyService } from '../../main/ets/services/peripheral/interface-control/UsbGlobalPolicyService'
import { UsbDevicePolicyStateService } from '../../main/ets/services/peripheral/device-policy/UsbDevicePolicyStateService'
import {
  CurrentUsbDeviceSnapshot,
  PeripheralPolicySnapshotTraceService
} from '../../main/ets/services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'
import { PeripheralTraceMutationResult } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

function successVoidResult(): OperationResult<void> {
  return { success: true } as OperationResult<void>
}

function successStorageResult(policy: usbManager.UsbPolicy): OperationResult<usbManager.UsbPolicy> {
  return { success: true, data: policy } as OperationResult<usbManager.UsbPolicy>
}

export default function usbGlobalPolicyServiceTest() {
  describe('UsbGlobalPolicyService', () => {
    let mockKit: MockKit
    let storageResult: OperationResult<usbManager.UsbPolicy>
    let globalResult: OperationResult<void>
    let suspendSuccess: boolean
    let restoreSuccess: boolean
    let suspendCalls: number
    let restoreCalls: number
    let globalSetCalls: number
    let captureCalls: number
    let capturedDevices: CurrentUsbDeviceSnapshot[]
    let disabledSnapshotCalls: number
    let enabledSnapshotCalls: number
    let lastDisabled: boolean | undefined

    beforeEach(() => {
      mockKit = new MockKit()
      storageResult = successStorageResult(usbManager.UsbPolicy.READ_WRITE)
      globalResult = successVoidResult()
      suspendSuccess = true
      restoreSuccess = true
      suspendCalls = 0
      restoreCalls = 0
      globalSetCalls = 0
      captureCalls = 0
      capturedDevices = []
      disabledSnapshotCalls = 0
      enabledSnapshotCalls = 0
      lastDisabled = undefined

      const storageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
      const globalSetMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
      const suspendMock = mockKit.mockFunc(UsbDevicePolicyStateService, UsbDevicePolicyStateService.suspendActivePolicies)
      const restoreMock = mockKit.mockFunc(
        UsbDevicePolicyStateService,
        UsbDevicePolicyStateService.restorePresentDeniedPolicies
      )
      const captureMock = mockKit.mockFunc(
        PeripheralPolicySnapshotTraceService,
        PeripheralPolicySnapshotTraceService.captureCurrentUsbDevices
      )
      const disabledSnapshotMock = mockKit.mockFunc(
        PeripheralPolicySnapshotTraceService,
        PeripheralPolicySnapshotTraceService.appendUsbGlobalDisabledSnapshot
      )
      const enabledSnapshotMock = mockKit.mockFunc(
        PeripheralPolicySnapshotTraceService,
        PeripheralPolicySnapshotTraceService.appendUsbGlobalEnabledSnapshot
      )

      when(storageMock)().afterAction(() => storageResult)
      when(globalSetMock)(ArgumentMatchers.any).afterAction((
        feature: PeripheralInterfaceFeature,
        disabled: boolean
      ) => {
        if (feature === PeripheralInterfaceFeatures.USB) {
          globalSetCalls += 1
          lastDisabled = disabled
        }
        return globalResult
      })
      when(suspendMock)().afterAction(() => {
        suspendCalls += 1
        return Promise.resolve(suspendSuccess)
      })
      when(restoreMock)().afterAction(() => {
        restoreCalls += 1
        return Promise.resolve(restoreSuccess)
      })
      when(captureMock)().afterAction(() => {
        captureCalls += 1
        return capturedDevices
      })
      when(disabledSnapshotMock)(ArgumentMatchers.any).afterAction(() => {
        disabledSnapshotCalls += 1
        return Promise.resolve({ success: true, code: 'ok' } as PeripheralTraceMutationResult)
      })
      when(enabledSnapshotMock)(ArgumentMatchers.any).afterAction(() => {
        enabledSnapshotCalls += 1
        return Promise.resolve({ success: true, code: 'ok' } as PeripheralTraceMutationResult)
      })
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should preserve usb storage read failure and stop before global mutation', 0, async () => {
      storageResult = {
        success: false,
        stage: 'read_usb_storage_policy',
        errorMessage: 'read failed'
      } as OperationResult<usbManager.UsbPolicy>

      const result = await UsbGlobalPolicyService.setDisabled(true)

      expect(result.success).assertFalse()
      expect(result.stage).assertEqual('read_usb_storage_policy')
      expect(suspendCalls).assertEqual(0)
      expect(globalSetCalls).assertEqual(0)
    })

    it('should reject global disable when usb storage is not read write', 0, async () => {
      storageResult = successStorageResult(usbManager.UsbPolicy.READ_ONLY)

      const result = await UsbGlobalPolicyService.setDisabled(true)

      expect(result.success).assertFalse()
      expect(result.stage).assertEqual(PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT)
      expect(suspendCalls).assertEqual(0)
      expect(globalSetCalls).assertEqual(0)
    })

    it('should suspend device denies and append captured snapshot after global disable', 0, async () => {
      const result = await UsbGlobalPolicyService.setDisabled(true)

      expect(result.success).assertTrue()
      expect(suspendCalls).assertEqual(1)
      expect(captureCalls).assertEqual(1)
      expect(globalSetCalls).assertEqual(1)
      expect(lastDisabled).assertTrue()
      expect(disabledSnapshotCalls).assertEqual(1)
      expect(enabledSnapshotCalls).assertEqual(0)
      expect(restoreCalls).assertEqual(0)
    })

    it('should restore present denies when global disable fails after suspension', 0, async () => {
      globalResult = { success: false, stage: 'set_usb_failed' } as OperationResult<void>

      const result = await UsbGlobalPolicyService.setDisabled(true)

      expect(result.success).assertFalse()
      expect(restoreCalls).assertEqual(1)
      expect(disabledSnapshotCalls).assertEqual(0)
      expect(enabledSnapshotCalls).assertEqual(0)
    })

    it('should keep global enable successful when a device deny replay is partial', 0, async () => {
      restoreSuccess = false

      const result = await UsbGlobalPolicyService.setDisabled(false)

      expect(result.success).assertTrue()
      expect(restoreCalls).assertEqual(1)
      expect(lastDisabled).assertFalse()
      expect(captureCalls).assertEqual(2)
      expect(disabledSnapshotCalls).assertEqual(0)
      expect(enabledSnapshotCalls).assertEqual(1)
    })

    it('should skip the 1.5 second fallback when devices are available after 0.5 seconds', 0, async () => {
      capturedDevices = [{ deviceId: 'VID:1234 PID:5678' } as CurrentUsbDeviceSnapshot]

      const result = await UsbGlobalPolicyService.setDisabled(false)

      expect(result.success).assertTrue()
      expect(captureCalls).assertEqual(1)
      expect(enabledSnapshotCalls).assertEqual(1)
    })
  })
}
