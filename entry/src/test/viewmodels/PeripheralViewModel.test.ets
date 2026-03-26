/**
 * PeripheralViewModel coordinator tests.
 */
import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
  })

  it('should initialize nested view models with expected defaults', 0, () => {
    expect(viewModel.adminState.activated).assertFalse()
    expect(viewModel.interfaceControl.state.usbDisabled).assertFalse()
    expect(viewModel.interfaceControl.state.usbStoragePolicyIndex).assertEqual(1)
    expect(viewModel.records.records.length).assertEqual(0)
    expect(viewModel.policy.records.length).assertEqual(0)
    expect(viewModel.records.connectionDetailDialog.visible).assertFalse()
  })

  it('should switch tabs and ignore invalid indices', 0, () => {
    viewModel.switchToTab(1)
    expect(viewModel.currentTab).assertEqual(1)

    viewModel.switchToTab(3)
    expect(viewModel.currentTab).assertEqual(1)
  })

  it('should expose admin required reason when admin is not ready', 0, () => {
    const ready = viewModel.ensureAdminReady()
    expect(ready).assertFalse()
    expect(viewModel.reasonCode).assertEqual('admin_required')
  })
})
