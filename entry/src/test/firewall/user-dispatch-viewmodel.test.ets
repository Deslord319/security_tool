import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallRuleStrings, FirewallUserStrings } from '../../main/ets/constants/modules/FirewallStrings'
import {
  FirewallUserPolicyApplyResult,
  FirewallUserPolicyStateResult,
  UserFirewallOption
} from '../../main/ets/models/firewall/FirewallModels'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallUserDispatchViewModel } from '../../main/ets/viewmodels/firewall/user-dispatch/FirewallUserDispatchViewModel'

function buildUsers(userIds: number[]): UserFirewallOption[] {
  return userIds.map((userId: number): UserFirewallOption => {
    return {
      userId: userId,
      label: `User ${userId}`
    }
  })
}

function buildPolicyState(userId: number): FirewallUserPolicyStateResult {
  return {
    userId: userId,
    isManaged: true,
    isOpen: true,
    inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
    outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
  }
}

export default function firewallUserDispatchViewModelTest() {
  describe('FirewallUserDispatchViewModel', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should initialize from external account users', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.loadUserPolicyState)
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        userId: number
      ): FirewallUserPolicyStateResult => buildPolicyState(userId))
      let viewModel = new FirewallUserDispatchViewModel()

      await viewModel.initialize(context, buildUsers([100, 101]))

      expect(viewModel.users.length).assertEqual(2)
      expect(viewModel.selectedUserId).assertEqual(100)
      expect(viewModel.statusHintText.length).assertEqual(0)
      done()
    })

    it('should reject initialization when external account users are empty', 0, async (done: Function) => {
      let viewModel = new FirewallUserDispatchViewModel()

      await viewModel.initialize(context, [])

      expect(viewModel.users.length).assertEqual(0)
      expect(viewModel.selectedUserId).assertEqual(-1)
      expect(viewModel.statusHintText).assertEqual(FirewallUserStrings.NO_ACTIVATED_USERS)
      done()
    })

    it('should reject submit when selected user is no longer in current users', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.loadUserPolicyState)
      let applyMock = mockKit.mockFunc(FirewallService, FirewallService.applyUserPolicyMode)
      let applyCount = 0
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        userId: number
      ): FirewallUserPolicyStateResult => buildPolicyState(userId))
      when(applyMock)(ArgumentMatchers.any).afterAction((): FirewallUserPolicyApplyResult => {
        applyCount++
        return {
          success: true,
          userId: 101,
          mode: 'allowlist'
        }
      })
      let viewModel = new FirewallUserDispatchViewModel()
      await viewModel.initialize(context, buildUsers([100, 101]))
      await viewModel.selectUser(context, 1)
      viewModel.users = buildUsers([100])

      let success = await viewModel.applySelectedMode(context)

      expect(success).assertFalse()
      expect(viewModel.statusHintText).assertEqual(FirewallRuleStrings.USER_SCOPE_CHANGED)
      expect(applyCount).assertEqual(0)
      done()
    })
  })
}
