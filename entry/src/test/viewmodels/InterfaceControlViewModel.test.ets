import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { OperationResult } from '../../main/ets/models/DataModels'
import { PeripheralReasonCodes } from '../../main/ets/constants/modules/PeripheralStrings'
import { PeripheralService } from '../../main/ets/services/peripheral/interface-control/PeripheralService'
import { InterfaceControlViewModel } from '../../main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel'

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

export default function interfaceControlViewModelTest() {
  describe('InterfaceControlViewModel', () => {
    let viewModel: InterfaceControlViewModel
    let mockKit: MockKit

  beforeEach(() => {
    viewModel = new InterfaceControlViewModel()
    mockKit = new MockKit()
  })

  afterEach(() => {
    mockKit.clearAll()
  })

  it('should toggle interface successfully', 0, async (done: Function) => {
    let setUsbInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    when(setUsbInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_USB, true)

    expect(reason).assertNull()
    expect(viewModel.processingKey).assertEqual('')
    done()
  })

  it('should surface failure stage for interface toggle', 0, async (done: Function) => {
    let setUsbInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = 'read_usb_status'
    when(setUsbInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_USB, true)

    expect(reason).assertEqual('read_usb_status')
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
    when(getInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(getInterfaceResult)
    when(getUsbStorageMock)().afterReturn(usbResult)

    const reason = await viewModel.setUsbStoragePolicy(2)

    expect(reason).assertNull()
    expect(viewModel.state.usbStoragePolicyIndex).assertEqual(2)
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
    done()
  })

  it('should surface conflict reason for usb storage policy change when usb interface is disabled', 0, async (done: Function) => {
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

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_BLUETOOTH, true)

    expect(reason).assertNull()
    expect(viewModel.state.btDisabled).assertTrue()
    done()
  })

  it('should toggle wifi interface successfully', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    when(setInterfaceMock)(ArgumentMatchers.any).afterReturn(setResult)

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_WIFI, true)

    expect(reason).assertNull()
    expect(viewModel.state.wifiDisabled).assertTrue()
    done()
  })
  })
}
