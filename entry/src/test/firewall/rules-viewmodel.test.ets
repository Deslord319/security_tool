import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallRuleStrings, FirewallUserStrings } from '../../main/ets/constants/modules/FirewallStrings'
import {
  attachFirewallRuleUserIds,
  FirewallRuleDisplayItem,
  FirewallRuleMutationResult,
  FirewallUserPolicyStateResult,
  UserFirewallListResult,
  UserFirewallOption
} from '../../main/ets/services/firewall/FirewallModels'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'
import { FirewallRulesViewModel } from '../../main/ets/viewmodels/firewall/rules/FirewallRulesViewModel'

function buildUsers(userIds: number[]): UserFirewallOption[] {
  return userIds.map((userId: number): UserFirewallOption => {
    return {
      userId: userId,
      label: `用户 ${userId}`
    }
  })
}

function buildUserResult(userIds: number[]): UserFirewallListResult {
  let users = buildUsers(userIds)
  return {
    users: users,
    selectedUserId: users[0]?.userId
  }
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

function buildRule(name: string, userIds: number[]): netFirewall.NetFirewallRule {
  return attachFirewallRuleUserIds({
    userId: userIds[0] ?? 0,
    name: name,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    protocol: 6,
    remoteIps: [{
      type: 1,
      family: 1,
      address: '8.8.8.8',
      mask: 32
    }]
  }, userIds)
}

function buildDisplayRule(localRuleId: string, userIds: number[]): FirewallRuleDisplayItem {
  let rule = buildRule(localRuleId, userIds) as FirewallRuleDisplayItem
  rule.localRuleId = localRuleId
  rule.targetUserIds = userIds
  rule.deployments = []
  rule.createdAt = 1
  rule.updatedAt = 2
  return rule
}

export default function firewallRulesViewModelTest() {
  describe('FirewallRulesViewModel', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let reconciledUserIds: number[]

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      reconciledUserIds = []
      let reconcileMock = mockKit.mockFunc(FirewallService, FirewallService.reconcileRulesForUsers)
      when(reconcileMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        users: UserFirewallOption[]
      ): Promise<boolean> => {
        reconciledUserIds = users.map((user: UserFirewallOption): number => user.userId)
        return Promise.resolve(true)
      })
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should refresh user options and rules before opening rule editor', 0, async (done: Function) => {
      let listRulesMock = mockKit.mockFunc(FirewallService, FirewallService.listRulesForDisplay)
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([buildDisplayRule('rule-1', [100])])
      let viewModel = new FirewallRulesViewModel()
      viewModel.userOptions = buildUsers([100, 101])

      let result = await viewModel.prepareRuleEditor(context)

      expect(result.success).assertTrue()
      expect(viewModel.userOptions.length).assertEqual(2)
      expect(viewModel.userOptions[1].userId).assertEqual(101)
      expect(viewModel.rules.length).assertEqual(1)
      done()
    })

    it('should reject opening rule editor when no user is available', 0, async (done: Function) => {
      let listRulesMock = mockKit.mockFunc(FirewallService, FirewallService.listRulesForDisplay)
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([buildDisplayRule('rule-1', [100])])
      let viewModel = new FirewallRulesViewModel()

      let result = await viewModel.prepareRuleEditor(context)

      expect(result.success).assertFalse()
      expect(result.errorMessage).assertEqual(FirewallUserStrings.NO_ACTIVATED_USERS)
      expect(viewModel.rules.length).assertEqual(0)
      done()
    })

    it('should reject submit when selected user no longer exists', 0, async (done: Function) => {
      let viewModel = new FirewallRulesViewModel()
      viewModel.userOptions = buildUsers([100])

      let result = await viewModel.validateRuleUserScopeForSubmit(context, buildRule('Allow DNS', [100, 101]))

      expect(result.success).assertFalse()
      expect(result.errorMessage).assertEqual(FirewallRuleStrings.USER_SCOPE_CHANGED)
      done()
    })

    it('should refresh rule page from account snapshot users', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.loadUserPolicyState)
      let listRulesMock = mockKit.mockFunc(FirewallService, FirewallService.listRulesForDisplay)
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        userId: number
      ): FirewallUserPolicyStateResult => buildPolicyState(userId))
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([buildDisplayRule('rule-1', [100])])
      let viewModel = new FirewallRulesViewModel()

      await viewModel.refreshForAccountChange(context, buildUsers([100, 101, 102]))

      expect(reconciledUserIds.length).assertEqual(3)
      expect(reconciledUserIds[2]).assertEqual(102)
      expect(viewModel.userOptions.length).assertEqual(3)
      expect(viewModel.defaultPolicyItems.length).assertEqual(3)
      expect(viewModel.rules.length).assertEqual(1)
      done()
    })

    it('should refresh page data after add success and keep success message', 0, async (done: Function) => {
      let createRuleMock = mockKit.mockFunc(FirewallService, FirewallService.createRule)
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.loadUserPolicyState)
      let listRulesMock = mockKit.mockFunc(FirewallService, FirewallService.listRulesForDisplay)
      when(createRuleMock)(ArgumentMatchers.any).afterReturn({
        success: true,
        localRuleId: 'rule-1',
        successDeployments: []
      } as FirewallRuleMutationResult)
      when(userMock)().afterReturn(buildUserResult([100, 101]))
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        userId: number
      ): FirewallUserPolicyStateResult => buildPolicyState(userId))
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([buildDisplayRule('rule-1', [100, 101])])
      let viewModel = new FirewallRulesViewModel()

      let result = await viewModel.addRule(context, buildRule('Allow DNS', [100, 101]))

      expect(result.success).assertTrue()
      expect(viewModel.userOptions.length).assertEqual(2)
      expect(viewModel.defaultPolicyItems.length).assertEqual(2)
      expect(viewModel.rules.length).assertEqual(1)
      expect(viewModel.lastOperationMessage).assertEqual(FirewallRuleStrings.ADD_SUCCESS)
      done()
    })

    it('should delete rule without switching rule list to loading state', 0, async (done: Function) => {
      let deleteRuleMock = mockKit.mockFunc(FirewallService, FirewallService.deleteRule)
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.loadUserPolicyState)
      let listRulesMock = mockKit.mockFunc(FirewallService, FirewallService.listRulesForDisplay)
      let resolveDelete: (value: FirewallRuleMutationResult) => void = (_value: FirewallRuleMutationResult): void => {}
      when(deleteRuleMock)(ArgumentMatchers.any).afterReturn(new Promise<FirewallRuleMutationResult>((resolve) => {
        resolveDelete = resolve
      }))
      const deleteResult: FirewallRuleMutationResult = {
        success: true,
        localRuleId: 'rule-1',
        successDeployments: []
      }
      when(userMock)().afterReturn(buildUserResult([100]))
      when(policyMock)(ArgumentMatchers.any).afterAction((
        _context: common.UIAbilityContext,
        userId: number
      ): FirewallUserPolicyStateResult => buildPolicyState(userId))
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([])
      let viewModel = new FirewallRulesViewModel()
      let rule = buildDisplayRule('rule-1', [100])

      let deletePromise = viewModel.deleteRule(context, rule)

      expect(viewModel.isLoading).assertFalse()
      expect(viewModel.deletingLocalRuleId).assertEqual('rule-1')
      resolveDelete(deleteResult)
      let result = await deletePromise
      expect(result.success).assertTrue()
      expect(viewModel.isLoading).assertFalse()
      expect(viewModel.deletingLocalRuleId).assertEqual('')
      expect(viewModel.rules.length).assertEqual(0)
      expect(viewModel.lastOperationMessage).assertEqual(FirewallRuleStrings.DELETE_SUCCESS)
      done()
    })
  })
}
