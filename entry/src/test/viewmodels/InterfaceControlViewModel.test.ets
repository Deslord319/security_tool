import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { OperationResult } from '../../main/ets/models/DataModels'
import { PeripheralService } from '../../main/ets/services/PeripheralService'
import { InterfaceControlViewModel } from '../../main/ets/viewmodels/InterfaceControlViewModel'

describe('InterfaceControlViewModel', () => {
  let viewModel: InterfaceControlViewModel
  let originalSetInterface: (feature: string, disallow: boolean) => OperationResult<void>
  let originalGetInterface: (feature: string) => OperationResult<boolean>
  let originalSetUsbStorage: (policy: usbManager.UsbPolicy) => OperationResult<void>
  let originalGetUsbStorage: () => OperationResult<usbManager.UsbPolicy>

  beforeEach(() => {
    viewModel = new InterfaceControlViewModel()
    originalSetInterface = PeripheralService.setInterfaceDisabledWithResult
    originalGetInterface = PeripheralService.getInterfaceDisabledWithResult
    originalSetUsbStorage = PeripheralService.setUsbStoragePolicyWithCleanupResult
    originalGetUsbStorage = PeripheralService.getUsbStoragePolicyWithResult
  })

  afterEach(() => {
    PeripheralService.setInterfaceDisabledWithResult = originalSetInterface
    PeripheralService.getInterfaceDisabledWithResult = originalGetInterface
    PeripheralService.setUsbStoragePolicyWithCleanupResult = originalSetUsbStorage
    PeripheralService.getUsbStoragePolicyWithResult = originalGetUsbStorage
  })

  it('should toggle interface successfully', 0, async (done: Function) => {
    PeripheralService.setInterfaceDisabledWithResult = (_feature: string, _disallow: boolean): OperationResult<void> => {
      return { success: true }
    }
    PeripheralService.getInterfaceDisabledWithResult = (_feature: string): OperationResult<boolean> => {
      return { success: true, data: true }
    }
    PeripheralService.getUsbStoragePolicyWithResult = (): OperationResult<usbManager.UsbPolicy> => {
      return { success: true, data: usbManager.UsbPolicy.READ_WRITE }
    }

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_USB, true)

    expect(reason).assertNull()
    expect(viewModel.processingKey).assertEqual('')
    done()
  })

  it('should surface failure stage for interface toggle', 0, async (done: Function) => {
    PeripheralService.setInterfaceDisabledWithResult = (_feature: string, _disallow: boolean): OperationResult<void> => {
      return { success: false, stage: 'read_usb_status' }
    }

    const reason = await viewModel.toggleInterface(PeripheralService.FEATURE_USB, true)

    expect(reason).assertEqual('read_usb_status')
    done()
  })

  it('should update usb storage policy successfully', 0, async (done: Function) => {
    PeripheralService.setUsbStoragePolicyWithCleanupResult = (_policy: usbManager.UsbPolicy): OperationResult<void> => {
      return { success: true }
    }
    PeripheralService.getInterfaceDisabledWithResult = (_feature: string): OperationResult<boolean> => {
      return { success: true, data: false }
    }
    PeripheralService.getUsbStoragePolicyWithResult = (): OperationResult<usbManager.UsbPolicy> => {
      return { success: true, data: usbManager.UsbPolicy.DISABLED }
    }

    const reason = await viewModel.setUsbStoragePolicy(2)

    expect(reason).assertNull()
    expect(viewModel.state.usbStoragePolicyIndex).assertEqual(2)
    done()
  })

  it('should surface failure stage for usb storage policy change', 0, async (done: Function) => {
    PeripheralService.setUsbStoragePolicyWithCleanupResult = (_policy: usbManager.UsbPolicy): OperationResult<void> => {
      return { success: false, stage: 'set_usb_storage_policy' }
    }

    const reason = await viewModel.setUsbStoragePolicy(0)

    expect(reason).assertEqual('set_usb_storage_policy')
    done()
  })
})
