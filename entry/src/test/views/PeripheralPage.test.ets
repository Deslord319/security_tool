import { describe, expect, it } from '@ohos/hypium'
import { PeripheralViewModel } from '../../main/ets/viewmodels/peripheral/overview/PeripheralViewModel'

interface PeripheralPageBoundaryHost {
  viewModel: PeripheralViewModel
  currentTabIndex: number
}

export default function peripheralPageBoundaryTest() {
  describe('PeripheralPage boundary', () => {
    it('should expose stable default page state', 0, () => {
      const viewModel = new PeripheralViewModel()

      expect(viewModel.currentTab).assertEqual(0)
      expect(viewModel.records.state.records.length).assertEqual(0)
      expect(viewModel.policy.state.records.length).assertEqual(0)
      expect(viewModel.records.state.connectionDetailDialog.record === null).assertTrue()
      expect(viewModel.records.state.connectionDetailDialog.historyItems.length).assertEqual(0)
    })

    it('should preserve selected tab when page remounts with shared viewModel', 0, () => {
      const sharedViewModel = new PeripheralViewModel()
      sharedViewModel.switchToTab(2)

      const firstPage: PeripheralPageBoundaryHost = {
        viewModel: sharedViewModel,
        currentTabIndex: sharedViewModel.currentTab
      }
      const remountedPage: PeripheralPageBoundaryHost = {
        viewModel: sharedViewModel,
        currentTabIndex: sharedViewModel.currentTab
      }

      expect(firstPage.viewModel === remountedPage.viewModel).assertTrue()
      expect(firstPage.currentTabIndex).assertEqual(2)
      expect(remountedPage.currentTabIndex).assertEqual(2)
    })
  })
}
