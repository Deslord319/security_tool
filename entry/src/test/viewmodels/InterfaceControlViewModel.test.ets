import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { MockKit, when } from '@ohos/hamock'
import { OperationResult } from '../../main/ets/models/DataModels'
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
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let getInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.getInterfaceDisabledWithResult)
    let getUsbStorageMock = mockKit.mockFunc(PeripheralService, PeripheralService.getUsbStoragePolicyWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = true
    let getResult = new BooleanOperationResult()
    getResult.success = true
    getResult.data = true
    let usbResult = new UsbPolicyOperationResult()
    usbResult.success = true
    usbResult.data = edmUsbManager.UsbPolicy.READ_WRITE
    when(setInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(setResult)
    when(getInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(getResult)
    when(getUsbStorageMock)().afterReturn(usbResult)

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_USB, true)

    expect(reason).assertNull()
    expect(viewModel.processingKey).assertEqual('')
    done()
  })

  it('should surface failure stage for interface toggle', 0, async (done: Function) => {
    let setInterfaceMock = mockKit.mockFunc(PeripheralService, PeripheralService.setInterfaceDisabledWithResult)
    let setResult = new VoidOperationResult()
    setResult.success = false
    setResult.stage = 'read_usb_status'
    when(setInterfaceMock)(PeripheralService.FEATURE_USB).afterReturn(setResult)

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
  })
}
