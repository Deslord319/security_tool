import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { OperationResult } from '../../main/ets/models/CommonModels'
import {
  PeripheralInterfaceFeatures,
  UsbStoragePolicy
} from '../../main/ets/models/PeripheralModels'
import { PeripheralReasonCodes } from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { InterfaceControlViewModel } from '../../main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PeripheralPolicySnapshotTraceService } from '../../main/ets/services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'
import { PeripheralTraceMutationResult } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'

class VoidOperationResult implements OperationResult<void> {
  success: boolean = false
  stage?: string
}

class BooleanOperationResult implements OperationResult<boolean> {
  success: boolean = false
  stage?: string
  data?: boolean
}

class UsbPolicyOperationResult implements OperationResult<edmUsbManager.UsbPolicy> {
  success: boolean = false
  stage?: string
  data?: edmUsbManager.UsbPolicy
}

function successTraceMutationResult(): PeripheralTraceMutationResult {
  return { success: true, code: 'ok' } as PeripheralTraceMutationResult
}

export default function interfaceControlViewModelTest() {
  describe('InterfaceControlViewModel', () => {
    let viewModel: InterfaceControlViewModel
    let mockKit: MockKit
    let capturedUsbStoragePolicy: UsbStoragePolicy | null

  beforeEach(() => {
    viewModel = new InterfaceControlViewModel()
    mockKit = new MockKit()
    capturedUsbStoragePolicy = null
    let appendUsbSnapshotMock = mockKit.mockFunc(
      PeripheralPolicySnapshotTraceService,
      PeripheralPolicySnapshotTraceService.appendUsbDefaultPolicySnapshot
    )
    let appendUsbStorageSnapshotMock = mockKit.mockFunc(
      PeripheralPolicySnapshotTraceService,
      PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot
    )
    when(appendUsbSnapshotMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(successTraceMutationResult()))
    when(appendUsbStorageSnapshotMock)(ArgumentMatchers.any).afterAction((policy: UsbStoragePolicy) => {
      capturedUsbStoragePolicy = policy
      return Promise.resolve(successTraceMutationResult())
    })
  })

  afterEach(() => {
    mockKit.clearAll()
  })

  it('should toggle interface successfully', 0, async (done: Function) => {
    let setUsbDefaultPolicyMock = mockKit.mockFunc(
      PeripheralDevicePolicyRepository,
      PeripheralDevicePolicyRepository.setUsbDefaultPolicy
    )
    when(setUsbDefaultPolicyMock)('deny').afterReturn(Promise.resolve(true))

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.USB, true)

    expect(reason).assertNull()
    expect(viewModel.processingKey).assertEqual('')
    expect(viewModel.state.usbDisabled).assertTrue()
    done()
  })

  it('should surface failure stage for interface toggle', 0, async (done: Function) => {
    let setUsbDefaultPolicyMock = mockKit.mockFunc(
      PeripheralDevicePolicyRepository,
      PeripheralDevicePolicyRepository.setUsbDefaultPolicy
    )
    when(setUsbDefaultPolicyMock)('deny').afterReturn(Promise.resolve(false))

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.USB, true)

    expect(reason).assertEqual(PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
    done()
  })

  it('should reload usb interface state from local default policy', 0, async (done: Function) => {
    let isUsbDefaultDenyMock = mockKit.mockFunc(
      PeripheralDevicePolicyRepository,
      PeripheralDevicePolicyRepository.isUsbDefaultDeny
    )
    let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
    let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
    let restorePowerMock = mockKit.mockFunc(PeripheralService, PeripheralService.restoreEnabledInterfacePowerWithResult)
    let getInterfaceResult = new BooleanOperationResult()
    getInterfaceResult.success = true
    getInterfaceResult.data = false
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.READ_WRITE
    let restoreResult = new VoidOperationResult()
    restoreResult.success = true
    when(isUsbDefaultDenyMock)().afterReturn(true)
    when(getInterfaceMock)(ArgumentMatchers.any).afterReturn(getInterfaceResult)
    when(getUsbStorageMock)().afterReturn(usbResult)
    when(restorePowerMock)(ArgumentMatchers.any).afterReturn(restoreResult)

    viewModel.reloadState()

    expect(viewModel.state.usbDisabled).assertTrue()
    done()
  })

  it('should reload network sharing state from interface service result', 0, async (done: Function) => {
    let isUsbDefaultDenyMock = mockKit.mockFunc(
      PeripheralDevicePolicyRepository,
      PeripheralDevicePolicyRepository.isUsbDefaultDeny
    )
    let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
    let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
    let restorePowerMock = mockKit.mockFunc(PeripheralService, PeripheralService.restoreEnabledInterfacePowerWithResult)
    let enabledResult = new BooleanOperationResult()
    enabledResult.success = true
    enabledResult.data = false
    let disabledResult = new BooleanOperationResult()
    disabledResult.success = true
    disabledResult.data = true
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.READ_WRITE
    let restoreResult = new VoidOperationResult()
    restoreResult.success = true
    when(isUsbDefaultDenyMock)().afterReturn(false)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.BLUETOOTH).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.WIFI).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.HDC).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.NETWORK).afterReturn(disabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.PRINTER).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.MICROPHONE).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.CAMERA).afterReturn(enabledResult)
    when(getUsbStorageMock)().afterReturn(usbResult)
    when(restorePowerMock)(ArgumentMatchers.any).afterReturn(restoreResult)

    viewModel.reloadState()

    expect(viewModel.state.networkDisabled).assertTrue()
    done()
  })

  it('should update usb storage policy successfully', 0, async (done: Function) => {
    let setUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.setUsbStoragePolicyWithCleanupResult)
    let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
    let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    let getInterfaceResult = new BooleanOperationResult()
    getInterfaceResult.success = true
    getInterfaceResult.data = false
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.DISABLED
    when(setUsbStorageMock)(edmUsbManager.UsbPolicy.DISABLED).afterReturn(setResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.USB).afterReturn(getInterfaceResult)
    when(getUsbStorageMock)().afterReturn(usbResult)

    const reason = await viewModel.setUsbStoragePolicy(2)

    expect(reason).assertNull()
    expect(viewModel.state.usbStoragePolicyIndex).assertEqual(2)
    expect(capturedUsbStoragePolicy).assertEqual(UsbStoragePolicy.DISABLED)
    done()
  })

  it('should surface failure stage for usb storage policy change', 0, async (done: Function) => {
    let setUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.setUsbStoragePolicyWithCleanupResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = 'set_usb_storage_policy'
    when(setUsbStorageMock)(edmUsbManager.UsbPolicy.READ_ONLY).afterReturn(setResult)

    const reason = await viewModel.setUsbStoragePolicy(0)

    expect(reason).assertEqual('set_usb_storage_policy')
    expect(capturedUsbStoragePolicy === null).assertTrue()
    done()
  })

  it('should surface system conflict reason for usb storage policy change', 0, async (done: Function) => {
    let setUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.setUsbStoragePolicyWithCleanupResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT
    when(setUsbStorageMock)(edmUsbManager.UsbPolicy.READ_ONLY).afterReturn(setResult)

    const reason = await viewModel.setUsbStoragePolicy(0)

    expect(reason).assertEqual(PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT)
    done()
  })

  it('should toggle bluetooth interface successfully', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.BLUETOOTH, true)

    expect(reason).assertNull()
    expect(viewModel.state.btDisabled).assertTrue()
    done()
  })

  it('should toggle wifi interface successfully', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.WIFI, true)

    expect(reason).assertNull()
    expect(viewModel.state.wifiDisabled).assertTrue()
    done()
  })

  it('should surface wifi power restore failure when enabling interface', 0, async (done: Function) => {
    viewModel.state.wifiDisabled = true
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = PeripheralReasonCodes.TURN_ON_WIFI_FAILED
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.WIFI, false)

    expect(reason).assertEqual(PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
    expect(viewModel.state.wifiDisabled).assertTrue()
    done()
  })
  })
}
