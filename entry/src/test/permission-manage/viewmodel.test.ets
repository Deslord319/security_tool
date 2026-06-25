import { describe, expect, it } from '@ohos/hypium'
import { PermissionViewModel } from '../../main/ets/viewmodels/permission-manage/PermissionViewModel'

export default function permissionViewModelTest() {
  describe('PermissionViewModel', () => {
    it('should keep default read-only skeleton state before initialization', 0, () => {
      let viewModel = new PermissionViewModel()

      expect(viewModel.state.initialized).assertFalse()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.summary.applicationCount).assertEqual(0)
      expect(viewModel.state.applications.length).assertEqual(0)
    })

    it('should load initial skeleton state without system side effects', 0, async (done: Function) => {
      let viewModel = new PermissionViewModel()
      await viewModel.loadInitialState()

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.loading).assertFalse()
      expect(viewModel.state.adminActivated).assertFalse()
      expect(viewModel.state.summary.accountCount).assertEqual(0)
      expect(viewModel.state.summary.managedPolicyCount).assertEqual(0)
      done()
    })
  })
}
