import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallOperationResult, FirewallOverviewState, FirewallPresetMode } from '../../main/ets/services/firewall/FirewallModels'
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
  })
}
