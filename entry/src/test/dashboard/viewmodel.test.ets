import { describe, expect, it } from '@ohos/hypium'
import { DashboardViewModel } from '../../main/ets/viewmodels/dashboard/overview/DashboardViewModel'

export default function dashboardViewModelTest() {
  describe('DashboardViewModel', () => {
    it('should keep basic defaults stable before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      expect(viewModel.moduleCards.length).assertEqual(0)
      expect(viewModel.quickEntries.length).assertEqual(0)
    })

    it('should allow destroy before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      viewModel.destroy()

      expect(true).assertTrue()
    })
  })
}
