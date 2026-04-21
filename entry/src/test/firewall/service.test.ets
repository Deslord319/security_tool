import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import {
  FirewallBatchOperationResult,
  FirewallPresetMode,
  FirewallUserPolicyMode,
  FirewallUserPolicyModeRecord,
  UserFirewallListResult,
  UserFirewallOption
} from '../../main/ets/services/firewall/FirewallModels'
import { FirewallModeStrategy } from '../../main/ets/services/firewall/FirewallModeStrategy'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallSystemRepository } from '../../main/ets/services/firewall/FirewallSystemRepository'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'

function buildUsers(): UserFirewallOption[] {
  return [
    { userId: 100, label: '用户 100' },
    { userId: 101, label: '用户 101' },
    { userId: 102, label: '用户 102' }
  ]
}

function buildUserResult(users: UserFirewallOption[]): UserFirewallListResult {
  return {
    users: users,
    selectedUserId: users[0]?.userId
  }
}

function buildClearResult(): FirewallBatchOperationResult {
  return {
    success: true,
    totalCount: 0,
    successCount: 0,
    failedCount: 0,
    failedItems: []
  }
}

interface AppliedPolicyRecord {
  userId: number
  isOpen: boolean
  inAction: number
  outAction: number
}

function findPolicy(records: AppliedPolicyRecord[], userId: number): AppliedPolicyRecord | undefined {
  return records.find((item: AppliedPolicyRecord): boolean => item.userId === userId)
}

function stubSwitchModeDependencies(
  mockKit: MockKit,
  users: UserFirewallOption[],
  modeRecords: FirewallUserPolicyModeRecord[],
  appliedPolicies: AppliedPolicyRecord[]
): void {
  let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
  let clearRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.clearRules)
  let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
  let clearDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.clearAllRuleDeployments)
  let listModesMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listUserPolicyModes)
  let buildRulesMock = mockKit.mockFunc(FirewallModeStrategy, FirewallModeStrategy.buildRulesForMode)
  let saveModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveCurrentMode)

  when(userMock)().afterReturn(buildUserResult(users))
  when(clearRulesMock)(ArgumentMatchers.any).afterReturn(buildClearResult())
  when(clearDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
  when(listModesMock)(ArgumentMatchers.any).afterReturn(modeRecords)
  when(buildRulesMock)(ArgumentMatchers.any).afterReturn([])
  when(saveModeMock)(ArgumentMatchers.any).afterReturn(true)
  when(setPolicyMock)(ArgumentMatchers.any).afterAction((
    userId: number,
    policy: netFirewall.NetFirewallPolicy
  ): boolean => {
    appliedPolicies.push({
      userId: userId,
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    })
    return true
  })
}

export default function firewallServiceTest() {
  describe('FirewallService', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should set public and private mode policy to allow all for every user', 0, async (done: Function) => {
      let users = buildUsers()
      let appliedPolicies: AppliedPolicyRecord[] = []
      stubSwitchModeDependencies(mockKit, users, [], appliedPolicies)

      await FirewallService.switchMode(context, 'public')

      expect(appliedPolicies.length).assertEqual(users.length)
      for (let i = 0; i < users.length; i++) {
        let policy = findPolicy(appliedPolicies, users[i].userId)
        expect(policy?.isOpen).assertTrue()
        expect(policy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(policy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      }

      appliedPolicies.splice(0, appliedPolicies.length)
      await FirewallService.switchMode(context, 'private')

      expect(appliedPolicies.length).assertEqual(users.length)
      for (let i = 0; i < users.length; i++) {
        let policy = findPolicy(appliedPolicies, users[i].userId)
        expect(policy?.isOpen).assertTrue()
        expect(policy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(policy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      }
      done()
    })

    it('should restore custom mode policy from local user mode records', 0, async (done: Function) => {
      let users = buildUsers()
      let appliedPolicies: AppliedPolicyRecord[] = []
      let modeRecords: FirewallUserPolicyModeRecord[] = [
        { userId: 100, mode: 'allowlist' as FirewallUserPolicyMode },
        { userId: 101, mode: 'denylist' as FirewallUserPolicyMode }
      ]
      stubSwitchModeDependencies(mockKit, users, modeRecords, appliedPolicies)

      await FirewallService.switchMode(context, 'custom' as FirewallPresetMode)

      let allowlistPolicy = findPolicy(appliedPolicies, 100)
      expect(allowlistPolicy?.isOpen).assertTrue()
      expect(allowlistPolicy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(allowlistPolicy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)

      let denylistPolicy = findPolicy(appliedPolicies, 101)
      expect(denylistPolicy?.isOpen).assertTrue()
      expect(denylistPolicy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(denylistPolicy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)

      let defaultPolicy = findPolicy(appliedPolicies, 102)
      expect(defaultPolicy?.isOpen).assertTrue()
      expect(defaultPolicy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(defaultPolicy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      done()
    })
  })
}
