import { describe, expect, it } from '@ohos/hypium'
import { PeripheralPage } from '../../main/ets/views/PeripheralPage'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'

export default function peripheralPageBoundaryTest() {
  describe('PeripheralPage boundary', () => {
    it('should expose stable default page state', 0, () => {
      const page = new PeripheralPage()

      expect(page.viewModel instanceof PeripheralViewModel).assertTrue()
      expect(page.currentTabIndex).assertEqual(0)
      expect(page.hoveredPanelIndex).assertEqual(-1)
      expect(page.deviceRecords.length).assertEqual(0)
      expect(page.policyRecords.length).assertEqual(0)
      expect(page.detailRecord === null).assertTrue()
      expect(page.detailHistoryItems.length).assertEqual(0)
    })

    it('should allow replacing page viewModel instance for boundary setup', 0, () => {
      const page = new PeripheralPage()
      const nextViewModel = new PeripheralViewModel()

      page.viewModel = nextViewModel

      expect(page.viewModel === nextViewModel).assertTrue()
      expect(page.currentTabIndex).assertEqual(0)
    })
  })
}
