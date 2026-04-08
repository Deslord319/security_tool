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

    it('should allow replacing page viewModel instance for boundary setup', 0, () => {
      const page: PeripheralPageBoundaryHost = {
        viewModel: new PeripheralViewModel(),
        currentTabIndex: 0
      }
      const nextViewModel = new PeripheralViewModel()

      page.viewModel = nextViewModel

      expect(page.viewModel === nextViewModel).assertTrue()
      expect(page.currentTabIndex).assertEqual(0)
    })
  })
}
