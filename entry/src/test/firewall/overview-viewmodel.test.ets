import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallOperationResult, FirewallOverviewState, FirewallPresetMode } from '../../main/ets/models/firewall/FirewallModels'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallOverviewViewModel } from '../../main/ets/viewmodels/firewall/overview/FirewallOverviewViewModel'

function createOverview(enabled: boolean, currentMode: FirewallPresetMode): FirewallOverviewState {
  return {
    enabled: enabled,
    currentMode: currentMode
  }
}

export default function firewallOverviewViewModelTest() {
  describe('FirewallOverviewViewModel', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should reload confirmed mode when mode switch throws', 0, async (done: Function) => {
      let switchMock = mockKit.mockFunc(FirewallService, FirewallService.switchMode)
      let loadMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)

      when(switchMock)(ArgumentMatchers.any).afterAction((): FirewallOperationResult => {
        throw new Error('switch failed')
      })
      when(loadMock)(ArgumentMatchers.any).afterReturn(createOverview(true, 'private'))

      let viewModel = new FirewallOverviewViewModel()
      viewModel.state.currentMode = 'public'

      let result = await viewModel.requestModeSwitch(context, 'custom')

      expect(result.success).assertFalse()
      expect(viewModel.state.currentMode).assertEqual('private')
      expect(viewModel.state.enabled).assertTrue()
      expect(viewModel.state.isModeProcessing).assertFalse()
      done()
    })

    it('should reject toggle while mode switch is processing', 0, async (done: Function) => {
      let viewModel = new FirewallOverviewViewModel()
      viewModel.state.isModeProcessing = true

      let result = await viewModel.requestToggle(context, true)

      expect(result.success).assertFalse()
      expect(result.targetEnabled).assertTrue()
      expect(result.errorMessage).assertEqual('mode switch in progress')
      expect(viewModel.state.isToggleProcessing).assertFalse()
      done()
    })

    it('should reject mode switch while toggle is processing', 0, async (done: Function) => {
      let viewModel = new FirewallOverviewViewModel()
      viewModel.state.isToggleProcessing = true

      let result = await viewModel.requestModeSwitch(context, 'private')

      expect(result.success).assertFalse()
      expect(result.errorMessage).assertEqual('toggle in progress')
      expect(viewModel.state.isModeProcessing).assertFalse()
      done()
    })
  })
}
