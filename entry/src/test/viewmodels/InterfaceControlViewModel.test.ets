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
import { UsbGlobalPolicyService } from '../../main/ets/services/peripheral/interface-control/UsbGlobalPolicyService'
import { PeripheralPolicySnapshotTraceService } from '../../main/ets/services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'
import { BluetoothPolicySnapshotTraceService } from '../../main/ets/services/peripheral/connection-record/BluetoothPolicySnapshotTraceService'
import {
  BluetoothConnectedDeviceSnapshot,
  BluetoothRuntimeConnectionStore
} from '../../main/ets/services/peripheral/connection-record/BluetoothRuntimeConnectionStore'
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
    let capturedBluetoothSnapshots: BluetoothConnectedDeviceSnapshot[] | null

  beforeEach(() => {
    BluetoothRuntimeConnectionStore.resetForTest()
    viewModel = new InterfaceControlViewModel()
    mockKit = new MockKit()
    capturedUsbStoragePolicy = null
    capturedBluetoothSnapshots = null
    let appendUsbStorageSnapshotMock = mockKit.mockFunc(
      PeripheralPolicySnapshotTraceService,
      PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot
    )
    when(appendUsbStorageSnapshotMock)(ArgumentMatchers.any).afterAction((policy: UsbStoragePolicy) => {
      capturedUsbStoragePolicy = policy
      return Promise.resolve(successTraceMutationResult())
    })
    let captureBluetoothSnapshotMock = mockKit.mockFunc(
      BluetoothRuntimeConnectionStore,
      BluetoothRuntimeConnectionStore.captureConnectedDevices
    )
    let appendBluetoothSnapshotMock = mockKit.mockFunc(
      BluetoothPolicySnapshotTraceService,
      BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot
    )
    when(captureBluetoothSnapshotMock)().afterReturn([{
      rawDeviceId: '11:22:33:44:55:66',
      deviceId: 'MAC: 11:22:33:44:55:66',
      deviceName: 'Bluetooth Keyboard',
      rawPayload: '{}'
    } as BluetoothConnectedDeviceSnapshot])
    when(appendBluetoothSnapshotMock)(ArgumentMatchers.any).afterAction((snapshots: BluetoothConnectedDeviceSnapshot[]) => {
      capturedBluetoothSnapshots = snapshots
      return Promise.resolve(successTraceMutationResult())
    })
  })

  afterEach(() => {
    BluetoothRuntimeConnectionStore.resetForTest()
    mockKit.clearAll()
  })

  it('should toggle interface successfully', 0, async (done: Function) => {
    let globalPolicyMock = mockKit.mockFunc(UsbGlobalPolicyService, UsbGlobalPolicyService.setDisabled)
    let result = new VoidOperationResult()
    result.success = false
    result.stage = PeripheralReasonCodes.USB_DISPATCH_FAILED
    when(globalPolicyMock)(true).afterReturn(Promise.resolve(result))
    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.USB, true)
    expect(reason).assertEqual(PeripheralReasonCodes.USB_DISPATCH_FAILED)
    done()
  })

  it('should surface failure stage for interface toggle', 0, async (done: Function) => {
    let globalPolicyMock = mockKit.mockFunc(UsbGlobalPolicyService, UsbGlobalPolicyService.setDisabled)
    let result = new VoidOperationResult()
    result.success = false
    result.stage = PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT
    when(globalPolicyMock)(true).afterReturn(Promise.resolve(result))

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.USB, true)

    expect(reason).assertEqual(PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT)
    done()
  })

  it('should reload usb interface state from local default policy', 0, async (done: Function) => {
    let isUsbDefaultDenyMock = mockKit.mockFunc(
      PeripheralDevicePolicyRepository,
      PeripheralDevicePolicyRepository.isUsbDefaultDeny
    )
    let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
    let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
    let getInterfaceResult = new BooleanOperationResult()
    getInterfaceResult.success = true
    getInterfaceResult.data = true
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.READ_WRITE
    when(isUsbDefaultDenyMock)().afterReturn(true)
    when(getInterfaceMock)(ArgumentMatchers.any).afterReturn(getInterfaceResult)
    when(getUsbStorageMock)().afterReturn(usbResult)

    await viewModel.reloadState()

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
    let enabledResult = new BooleanOperationResult()
    enabledResult.success = true
    enabledResult.data = false
    let disabledResult = new BooleanOperationResult()
    disabledResult.success = true
    disabledResult.data = true
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.READ_WRITE
    when(isUsbDefaultDenyMock)().afterReturn(false)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.BLUETOOTH).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.USB).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.WIFI).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.HDC).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.NETWORK).afterReturn(disabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.PRINTER).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.MICROPHONE).afterReturn(enabledResult)
    when(getInterfaceMock)(PeripheralInterfaceFeatures.CAMERA).afterReturn(enabledResult)
    when(getUsbStorageMock)().afterReturn(usbResult)

    await viewModel.reloadState()

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
    expect(capturedBluetoothSnapshots?.length).assertEqual(1)
    expect(BluetoothRuntimeConnectionStore.consumeDisabledDisconnectPending(
      'MAC: 11:22:33:44:55:66'
    )).assertTrue()
    done()
  })

  it('should not append bluetooth snapshot when bluetooth disable policy fails', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = 'set_bluetooth_failed'
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.BLUETOOTH, true)

    expect(reason).assertEqual('set_bluetooth_failed')
    expect(capturedBluetoothSnapshots === null).assertTrue()
    expect(BluetoothRuntimeConnectionStore.consumeDisabledDisconnectPending(
      'MAC: 11:22:33:44:55:66'
    )).assertFalse()
    done()
  })

  it('should roll back bluetooth disconnect marker when policy call throws', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    when(setInterfaceMock)(ArgumentMatchers.any).afterAction(() => {
      throw new Error('set bluetooth failed unexpectedly')
    })

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.BLUETOOTH, true)

    expect(reason).assertEqual(PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
    expect(BluetoothRuntimeConnectionStore.consumeDisabledDisconnectPending(
      'MAC: 11:22:33:44:55:66'
    )).assertFalse()
    done()
  })

  it('should clear stale bluetooth disconnect markers after bluetooth is enabled', 0, async (done: Function) => {
    BluetoothRuntimeConnectionStore.markDisabledDisconnectPending('MAC: 11:22:33:44:55:66')
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.BLUETOOTH, false)

    expect(reason).assertNull()
    expect(BluetoothRuntimeConnectionStore.consumeDisabledDisconnectPending(
      'MAC: 11:22:33:44:55:66'
    )).assertFalse()
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

  it('should surface bluetooth power restore failure when enabling interface', 0, async (done: Function) => {
    viewModel.state.btDisabled = true
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = PeripheralReasonCodes.TURN_ON_BLUETOOTH_FAILED
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralInterfaceFeatures.BLUETOOTH, false)

    expect(reason).assertEqual(PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
    expect(viewModel.state.btDisabled).assertTrue()
    expect(capturedBluetoothSnapshots === null).assertTrue()
    done()
  })
  })
}
