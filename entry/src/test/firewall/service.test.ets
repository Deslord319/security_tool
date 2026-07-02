import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import { FirewallPolicyService } from '../../main/ets/services/firewall/FirewallPolicyService'
import {
  FirewallBatchOperationResult,
  FirewallPreparedRule,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallRuleIntentInput,
  FirewallRuleIntentMappingData,
  FirewallPresetMode,
  FirewallScopedRule,
  FirewallUserPolicyMode,
  FirewallUserPolicyModeRecord,
  UserFirewallListResult,
  UserFirewallOption
} from '../../main/ets/services/firewall/FirewallModels'
import { FirewallModeStrategy } from '../../main/ets/services/firewall/FirewallModeStrategy'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallSystemRepository } from '../../main/ets/services/firewall/FirewallSystemRepository'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'
import { FirewallRuleStrings } from '../../main/ets/constants/modules/FirewallStrings'

function buildUsers(): UserFirewallOption[] {
  return [
    { userId: 100, label: '用户 100' },
    { userId: 101, label: '用户 101' },
    { userId: 102, label: '用户 102' }
  ]
}

function buildUserResult(users: UserFirewallOption[], selectedUserId?: number): UserFirewallListResult {
  return {
    users: users,
    selectedUserId: selectedUserId ?? users[0]?.userId
  }
}

function buildClearResult(): FirewallBatchOperationResult {
  return {
    success: true,
    failedItems: []
  }
}

interface AppliedPolicyRecord {
  userId: number
  isOpen: boolean
  inAction: number
  outAction: number
}

class FakeAddRuleRawResult {
  systemRuleId?: number
  errorCode?: number
  errorMessage?: string

  constructor(systemRuleId?: number, errorCode?: number, errorMessage?: string) {
    this.systemRuleId = systemRuleId
    this.errorCode = errorCode
    this.errorMessage = errorMessage
  }
}

class FakeSystemRuleMutationResult {
  success: boolean
  errorCode?: number
  errorMessage?: string

  constructor(success: boolean, errorCode?: number, errorMessage?: string) {
    this.success = success
    this.errorCode = errorCode
    this.errorMessage = errorMessage
  }
}

function findPolicy(records: AppliedPolicyRecord[], userId: number): AppliedPolicyRecord | undefined {
  return records.find((item: AppliedPolicyRecord): boolean => item.userId === userId)
}

function buildIpRuleInput(name: string, targetUserIds: number[] = [100]): FirewallRuleIntentInput {
  return {
    name: name,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    targetUserIds: targetUserIds,
    protocol: 6,
    remoteIps: [{
      type: 1,
      family: 1,
      address: '8.8.8.8',
      mask: 32
    }],
    remotePorts: [{ startPort: 443, endPort: 443 }]
  }
}

function buildDnsRuleInput(name: string, targetUserIds: number[] = [100]): FirewallRuleIntentInput {
  return {
    name: name,
    type: netFirewall.NetFirewallRuleType.RULE_DNS,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    targetUserIds: targetUserIds,
    dns: {
      primaryDns: '8.8.8.8',
      standbyDns: '1.1.1.1'
    }
  }
}

function buildStoredIntent(localRuleId: string, name: string, targetUserIds: number[] = [100]): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: name,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    targetUserIds: targetUserIds,
    protocol: 6,
    remoteIps: [{
      type: 1,
      family: 1,
      address: '8.8.8.8',
      mask: 32
    }],
    remotePorts: [{ startPort: 443, endPort: 443 }],
    createdAt: 1,
    updatedAt: 2
  }
}

function buildStoredDnsIntent(localRuleId: string, name: string, targetUserIds: number[] = [100]): FirewallRuleIntent {
  return {
    localRuleId: localRuleId,
    name: name,
    type: netFirewall.NetFirewallRuleType.RULE_DNS,
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    isEnabled: true,
    targetUserIds: targetUserIds,
    dns: {
      primaryDns: '8.8.8.8',
      standbyDns: '1.1.1.1'
    },
    createdAt: 1,
    updatedAt: 2
  }
}

function buildDeployment(localRuleId: string, userId: number, systemRuleId: number): FirewallRuleDeployment {
  return {
    localRuleId: localRuleId,
    userId: userId,
    systemRuleId: systemRuleId
  }
}

function emptyRuleMappingData(): FirewallRuleIntentMappingData {
  return {
    version: 1,
    ruleIntents: [],
    ruleDeployments: []
  }
}

function buildExistingSystemRule(userId: number, systemRuleId: number): netFirewall.NetFirewallRule {
  let rule: netFirewall.NetFirewallRule = {
    userId: userId,
    name: 'Existing Rule',
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true,
    protocol: 6,
    remoteIps: [{
      type: 1,
      family: 1,
      address: '10.0.0.1',
      mask: 32
    }]
  }
  let scopedRule = rule as FirewallScopedRule
  scopedRule.id = systemRuleId
  return rule
}

function buildPolicy(
  isOpen: boolean,
  inAction: netFirewall.FirewallRuleAction,
  outAction: netFirewall.FirewallRuleAction
): netFirewall.NetFirewallPolicy {
  return {
    isOpen: isOpen,
    inAction: inAction,
    outAction: outAction
  }
}

function stubAuthResult(
  mockKit: MockKit,
  success: boolean,
  reason?: 'failed' | 'unavailable'
): void {
  let authMock = mockKit.mockFunc(AuthService, AuthService.authenticate)
  when(authMock)(ArgumentMatchers.any).afterReturn({
    success: success,
    reason: reason,
    errorCode: success ? undefined : 12500010,
    message: success ? undefined : 'auth failed'
  })
}

function stubGlobalToggleDependencies(
  mockKit: MockKit,
  users: UserFirewallOption[],
  policies: Map<number, netFirewall.NetFirewallPolicy>,
  appliedPolicies: AppliedPolicyRecord[],
  setPolicyFailedUserIds: number[] = []
): void {
  let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
  let getPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
  let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
  let saveDesiredEnabledMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveDesiredEnabled)

  when(userMock)().afterReturn(buildUserResult(users))
  when(saveDesiredEnabledMock)(ArgumentMatchers.any).afterReturn(true)
  when(getPolicyMock)(ArgumentMatchers.any).afterAction((userId: number): netFirewall.NetFirewallPolicy | null => {
    return policies.get(userId) ?? null
  })
  when(setPolicyMock)(ArgumentMatchers.any).afterAction((
    userId: number,
    policy: netFirewall.NetFirewallPolicy
  ): boolean => {
    if (setPolicyFailedUserIds.includes(userId)) {
      return false
    }
    appliedPolicies.push({
      userId: userId,
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    })
    return true
  })
}

function stubSwitchModeDependencies(
  mockKit: MockKit,
  users: UserFirewallOption[],
  modeRecords: FirewallUserPolicyModeRecord[],
  appliedPolicies: AppliedPolicyRecord[],
  policies?: Map<number, netFirewall.NetFirewallPolicy>
): void {
  let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
  let clearRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.clearRules)
  let listRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.listRules)
  let getPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
  let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
  let clearDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.clearAllRuleDeployments)
  let getModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
  let loadMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.loadRuleIntentMappingData)
  let saveMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntentMappingData)
  let listModesMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listUserPolicyModes)
  let pruneUsersMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
  let buildRulesMock = mockKit.mockFunc(FirewallModeStrategy, FirewallModeStrategy.buildRulesForMode)
  let saveModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveCurrentMode)
  let saveModeApplyStateMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveModeApplyState)

  when(userMock)().afterReturn(buildUserResult(users))
  when(clearRulesMock)(ArgumentMatchers.any).afterReturn(buildClearResult())
  when(listRulesMock)(ArgumentMatchers.any).afterReturn([])
  when(getPolicyMock)(ArgumentMatchers.any).afterAction((userId: number): netFirewall.NetFirewallPolicy | null => {
    return policies?.get(userId) ?? buildPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW)
  })
  when(clearDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
  when(getModeMock)(ArgumentMatchers.any).afterReturn('custom')
  when(loadMappingMock)(ArgumentMatchers.any).afterReturn(emptyRuleMappingData())
  when(saveMappingMock)(ArgumentMatchers.any).afterReturn(true)
  when(listModesMock)(ArgumentMatchers.any).afterReturn(modeRecords)
  when(pruneUsersMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
  when(buildRulesMock)(ArgumentMatchers.any).afterReturn([])
  when(saveModeMock)(ArgumentMatchers.any).afterReturn(true)
  when(saveModeApplyStateMock)(ArgumentMatchers.any).afterReturn(true)
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

function stubUserPolicyModeDependencies(
  mockKit: MockKit,
  appliedPolicies: AppliedPolicyRecord[],
  setPolicyResult: boolean = true,
  saveModeResult: boolean = true
): void {
  let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
  let saveModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveUserPolicyMode)

  when(setPolicyMock)(ArgumentMatchers.any).afterAction((
    userId: number,
    policy: netFirewall.NetFirewallPolicy
  ): boolean => {
    if (!setPolicyResult) {
      return false
    }
    appliedPolicies.push({
      userId: userId,
      isOpen: policy.isOpen,
      inAction: policy.inAction,
      outAction: policy.outAction
    })
    return true
  })
  when(saveModeMock)(ArgumentMatchers.any).afterReturn(saveModeResult)
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

    describe('overview state', () => {
      it('should read only admin current user policy for overview enabled state', 0, async (done: Function) => {
        let users = buildUsers()
        let requestedUserIds: number[] = []
        let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
        let getPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
        let getModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)

        when(userMock)().afterReturn(buildUserResult(users, 101))
        when(getPolicyMock)(ArgumentMatchers.any).afterAction((userId: number): netFirewall.NetFirewallPolicy | null => {
          requestedUserIds.push(userId)
          return buildPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW)
        })
        when(getModeMock)(ArgumentMatchers.any).afterReturn('public')

        let overview = await FirewallPolicyService.loadOverviewState(context)

        expect(overview.enabled).assertTrue()
        expect(overview.currentMode).assertEqual('public')
        expect(requestedUserIds.join(',')).assertEqual('101')
        done()
      })
    })

    describe('global toggle', () => {
      it('should reject toggle when PIN auth is unavailable', 0, async (done: Function) => {
        stubAuthResult(mockKit, false, 'unavailable')

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, true)

        expect(result.success).assertFalse()
        expect(result.targetEnabled).assertTrue()
        expect(result.reason).assertEqual('pin_unavailable')
        expect(result.errorCode).assertEqual(12500010)
        done()
      })

      it('should reject toggle when PIN auth fails', 0, async (done: Function) => {
        stubAuthResult(mockKit, false, 'failed')

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, false)

        expect(result.success).assertFalse()
        expect(result.targetEnabled).assertFalse()
        expect(result.reason).assertEqual('pin_failed')
        expect(result.errorMessage).assertEqual('auth failed')
        done()
      })

      it('should reject toggle when no available users are loaded', 0, async (done: Function) => {
        let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
        stubAuthResult(mockKit, true)
        when(userMock)().afterReturn({
          users: [],
          message: 'no activated users'
        } as UserFirewallListResult)

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, true)

        expect(result.success).assertFalse()
        expect(result.targetEnabled).assertTrue()
        expect(result.reason).assertEqual('no_available_users')
        expect(result.errorMessage).assertEqual('no activated users')
        done()
      })

      it('should enable firewall for every user while keeping existing actions', 0, async (done: Function) => {
        let users = buildUsers()
        let appliedPolicies: AppliedPolicyRecord[] = []
        let policies = new Map<number, netFirewall.NetFirewallPolicy>()
        policies.set(100, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_DENY))
        policies.set(101, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_ALLOW))
        policies.set(102, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW))
        stubAuthResult(mockKit, true)
        stubGlobalToggleDependencies(mockKit, users, policies, appliedPolicies)

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, true)

        expect(result.success).assertTrue()
        expect(result.targetEnabled).assertTrue()
        expect(appliedPolicies.length).assertEqual(users.length)
        expect(findPolicy(appliedPolicies, 100)?.isOpen).assertTrue()
        expect(findPolicy(appliedPolicies, 100)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(findPolicy(appliedPolicies, 100)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(findPolicy(appliedPolicies, 101)?.isOpen).assertTrue()
        expect(findPolicy(appliedPolicies, 101)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(findPolicy(appliedPolicies, 101)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        done()
      })

      it('should disable firewall for every user while keeping existing actions', 0, async (done: Function) => {
        let users = buildUsers()
        let appliedPolicies: AppliedPolicyRecord[] = []
        let policies = new Map<number, netFirewall.NetFirewallPolicy>()
        policies.set(100, buildPolicy(true, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY))
        policies.set(101, buildPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_DENY))
        policies.set(102, buildPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW))
        stubAuthResult(mockKit, true)
        stubGlobalToggleDependencies(mockKit, users, policies, appliedPolicies)

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, false)

        expect(result.success).assertTrue()
        expect(result.targetEnabled).assertFalse()
        expect(appliedPolicies.length).assertEqual(users.length)
        expect(findPolicy(appliedPolicies, 100)?.isOpen).assertFalse()
        expect(findPolicy(appliedPolicies, 100)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(findPolicy(appliedPolicies, 100)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(findPolicy(appliedPolicies, 101)?.isOpen).assertFalse()
        expect(findPolicy(appliedPolicies, 101)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(findPolicy(appliedPolicies, 101)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        done()
      })

      it('should report read policy failure for a specific user', 0, async (done: Function) => {
        let users = buildUsers()
        let appliedPolicies: AppliedPolicyRecord[] = []
        let policies = new Map<number, netFirewall.NetFirewallPolicy>()
        policies.set(100, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW))
        policies.set(102, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_DENY))
        stubAuthResult(mockKit, true)
        stubGlobalToggleDependencies(mockKit, users, policies, appliedPolicies)

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, true)

        expect(result.success).assertFalse()
        expect(result.reason).assertEqual('policy_apply_failed')
        expect(result.errorMessage).assertEqual('policy apply failed')
        expect(result.failedItems?.length).assertEqual(1)
        expect(result.failedItems?.[0].userId).assertEqual(101)
        expect(result.failedItems?.[0].errorMessage).assertEqual('read policy failed')
        expect(findPolicy(appliedPolicies, 100)?.isOpen).assertTrue()
        expect(findPolicy(appliedPolicies, 102)?.isOpen).assertTrue()
        done()
      })

      it('should report set policy failure while keeping successful users applied', 0, async (done: Function) => {
        let users = buildUsers()
        let appliedPolicies: AppliedPolicyRecord[] = []
        let policies = new Map<number, netFirewall.NetFirewallPolicy>()
        policies.set(100, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW))
        policies.set(101, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_ALLOW))
        policies.set(102, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_DENY))
        stubAuthResult(mockKit, true)
        stubGlobalToggleDependencies(mockKit, users, policies, appliedPolicies, [101])

        let result = await FirewallService.setFirewallEnabledForAllUsers(context, true)

        expect(result.success).assertFalse()
        expect(result.reason).assertEqual('policy_apply_failed')
        expect(result.failedItems?.length).assertEqual(1)
        expect(result.failedItems?.[0].userId).assertEqual(101)
        expect(result.failedItems?.[0].errorMessage).assertEqual('set policy failed')
        expect(appliedPolicies.length).assertEqual(2)
        expect(findPolicy(appliedPolicies, 100)?.isOpen).assertTrue()
        expect(findPolicy(appliedPolicies, 102)?.isOpen).assertTrue()
        done()
      })
    })

    it('should set public and private mode policy actions while preserving isOpen', 0, async (done: Function) => {
      let users = buildUsers()
      let appliedPolicies: AppliedPolicyRecord[] = []
      let policies = new Map<number, netFirewall.NetFirewallPolicy>()
      policies.set(100, buildPolicy(true, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY))
      policies.set(101, buildPolicy(false, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY))
      policies.set(102, buildPolicy(true, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY))
      stubSwitchModeDependencies(mockKit, users, [], appliedPolicies, policies)

      await FirewallService.switchMode(context, 'public')

      expect(appliedPolicies.length).assertEqual(users.length)
      for (let i = 0; i < users.length; i++) {
        let policy = findPolicy(appliedPolicies, users[i].userId)
        expect(policy?.isOpen).assertEqual(policies.get(users[i].userId)?.isOpen)
        expect(policy?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(policy?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      }

      appliedPolicies.splice(0, appliedPolicies.length)
      await FirewallService.switchMode(context, 'private')

      expect(appliedPolicies.length).assertEqual(users.length)
      for (let i = 0; i < users.length; i++) {
        let policy = findPolicy(appliedPolicies, users[i].userId)
        expect(policy?.isOpen).assertEqual(policies.get(users[i].userId)?.isOpen)
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

    it('should not save target mode when mode switch has failed items', 0, async (done: Function) => {
      let users = buildUsers()
      let savedModeCount = 0
      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let clearRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.clearRules)
      let listRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.listRules)
      let getPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
      let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
      let clearDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.clearAllRuleDeployments)
      let getModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let loadMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.loadRuleIntentMappingData)
      let saveMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntentMappingData)
      let pruneUsersMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let buildRulesMock = mockKit.mockFunc(FirewallModeStrategy, FirewallModeStrategy.buildRulesForMode)
      let saveModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveCurrentMode)

      when(userMock)().afterReturn(buildUserResult(users))
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([])
      when(clearRulesMock)(ArgumentMatchers.any).afterReturn({
        success: false,
        failedItems: [{ userId: 100, errorMessage: 'clear failed' }]
      } as FirewallBatchOperationResult)
      when(getPolicyMock)(ArgumentMatchers.any).afterReturn(buildPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_ALLOW))
      when(setPolicyMock)(ArgumentMatchers.any).afterReturn(true)
      when(clearDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
      when(getModeMock)(ArgumentMatchers.any).afterReturn('custom')
      when(loadMappingMock)(ArgumentMatchers.any).afterReturn(emptyRuleMappingData())
      when(saveMappingMock)(ArgumentMatchers.any).afterReturn(true)
      when(pruneUsersMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(buildRulesMock)(ArgumentMatchers.any).afterReturn([])
      when(saveModeMock)(ArgumentMatchers.any).afterAction((_context: common.Context, mode: FirewallPresetMode): boolean => {
        expect(mode).assertEqual('custom')
        savedModeCount++
        return true
      })

      let result = await FirewallService.switchMode(context, 'public')

      expect(result.success).assertFalse()
      expect(savedModeCount).assertEqual(1)
      done()
    })

    it('should restore previous policy rules deployments and mode when mode switch fails', 0, async (done: Function) => {
      let users: UserFirewallOption[] = [{ userId: 100, label: 'User 100' }]
      let appliedPolicies: AppliedPolicyRecord[] = []
      let restoredMappingData: FirewallRuleIntentMappingData = emptyRuleMappingData()
      let restoredMode: FirewallPresetMode | undefined = undefined
      let addRuleCount = 0
      let previousPolicy = buildPolicy(true, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_DENY)
      let previousMappingData: FirewallRuleIntentMappingData = {
        version: 1,
        ruleIntents: [buildStoredIntent('rule-old', 'Old Rule', [100])],
        ruleDeployments: [buildDeployment('rule-old', 100, 9001)]
      }
      let preparedRules: FirewallPreparedRule[] = [{
        localRuleId: 'rule-new',
        userId: 100,
        rule: buildExistingSystemRule(100, 9002)
      }]

      let userMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let listRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.listRules)
      let clearRulesMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.clearRules)
      let getPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.getPolicy)
      let setPolicyMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.setPolicy)
      let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
      let clearDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.clearAllRuleDeployments)
      let getModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getCurrentMode)
      let loadMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.loadRuleIntentMappingData)
      let saveMappingMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntentMappingData)
      let pruneUsersMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.pruneUnavailableUsers)
      let buildRulesMock = mockKit.mockFunc(FirewallModeStrategy, FirewallModeStrategy.buildRulesForMode)
      let saveModeMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveCurrentMode)

      when(userMock)().afterReturn(buildUserResult(users))
      when(listRulesMock)(ArgumentMatchers.any).afterReturn([buildExistingSystemRule(100, 9001)])
      when(clearRulesMock)(ArgumentMatchers.any).afterReturn(buildClearResult())
      when(getPolicyMock)(ArgumentMatchers.any).afterReturn(previousPolicy)
      when(pruneUsersMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(true))
      when(setPolicyMock)(ArgumentMatchers.any).afterAction((userId: number, policy: netFirewall.NetFirewallPolicy): boolean => {
        appliedPolicies.push({
          userId: userId,
          isOpen: policy.isOpen,
          inAction: policy.inAction,
          outAction: policy.outAction
        })
        return true
      })
      when(clearDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
      when(getModeMock)(ArgumentMatchers.any).afterReturn('custom')
      when(loadMappingMock)(ArgumentMatchers.any).afterReturn(previousMappingData)
      when(saveMappingMock)(ArgumentMatchers.any).afterAction((
        _context: common.Context,
        data: FirewallRuleIntentMappingData
      ): boolean => {
        restoredMappingData = data
        return true
      })
      when(buildRulesMock)(ArgumentMatchers.any).afterReturn(preparedRules)
      when(addRuleMock)(ArgumentMatchers.any).afterAction((): FakeAddRuleRawResult => {
        addRuleCount++
        return addRuleCount === 1
          ? new FakeAddRuleRawResult(undefined, 401, 'add failed')
          : new FakeAddRuleRawResult(9101)
      })
      when(saveModeMock)(ArgumentMatchers.any).afterAction((_context: common.Context, mode: FirewallPresetMode): boolean => {
        restoredMode = mode
        return true
      })

      let result = await FirewallService.switchMode(context, 'public')

      expect(result.success).assertFalse()
      expect(appliedPolicies.length).assertEqual(2)
      expect(appliedPolicies[0].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(appliedPolicies[1].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(restoredMappingData.ruleDeployments[0].systemRuleId).assertEqual(9101)
      expect(restoredMode).assertEqual('custom')
      done()
    })

    describe('user policy mode', () => {
      it('should apply allowlist policy after PIN succeeds', 0, async (done: Function) => {
        let appliedPolicies: AppliedPolicyRecord[] = []
        stubAuthResult(mockKit, true)
        stubUserPolicyModeDependencies(mockKit, appliedPolicies)

        let result = await FirewallService.applyUserPolicyMode(context, 101, 'allowlist')

        expect(result.success).assertTrue()
        expect(result.userId).assertEqual(101)
        expect(result.mode).assertEqual('allowlist')
        expect(appliedPolicies.length).assertEqual(1)
        expect(appliedPolicies[0].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        expect(appliedPolicies[0].outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
        done()
      })

      it('should apply denylist policy after PIN succeeds', 0, async (done: Function) => {
        let appliedPolicies: AppliedPolicyRecord[] = []
        stubAuthResult(mockKit, true)
        stubUserPolicyModeDependencies(mockKit, appliedPolicies)

        let result = await FirewallService.applyUserPolicyMode(context, 101, 'denylist')

        expect(result.success).assertTrue()
        expect(result.userId).assertEqual(101)
        expect(result.mode).assertEqual('denylist')
        expect(appliedPolicies.length).assertEqual(1)
        expect(appliedPolicies[0].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        expect(appliedPolicies[0].outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
        done()
      })

      it('should not write user policy when PIN fails', 0, async (done: Function) => {
        let appliedPolicies: AppliedPolicyRecord[] = []
        stubAuthResult(mockKit, false, 'failed')
        stubUserPolicyModeDependencies(mockKit, appliedPolicies)

        let result = await FirewallService.applyUserPolicyMode(context, 101, 'allowlist')

        expect(result.success).assertFalse()
        expect(result.errorCode).assertEqual(12500010)
        expect(appliedPolicies.length).assertEqual(0)
        done()
      })

      it('should report failure when user policy write fails', 0, async (done: Function) => {
        let appliedPolicies: AppliedPolicyRecord[] = []
        stubAuthResult(mockKit, true)
        stubUserPolicyModeDependencies(mockKit, appliedPolicies, false)

        let result = await FirewallService.applyUserPolicyMode(context, 101, 'denylist')

        expect(result.success).assertFalse()
        expect(result.errorMessage).assertEqual('set policy failed')
        expect(appliedPolicies.length).assertEqual(0)
        done()
      })
    })

    describe('rule mutations', () => {
      it('should list display rules from local intents and deployments', 0, async (done: Function) => {
        let mappingData: FirewallRuleIntentMappingData = {
          version: 1,
          ruleIntents: [buildStoredIntent('rule-1', 'Rule 1', [100, 101])],
          ruleDeployments: [
            buildDeployment('rule-1', 100, 9001),
            buildDeployment('rule-1', 101, 9002)
          ]
        }
        let loadMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.loadRuleIntentMappingData)
        when(loadMock)(ArgumentMatchers.any).afterReturn(mappingData)

        let displayRules = await FirewallService.listRulesForDisplay(context)

        expect(displayRules.length).assertEqual(1)
        expect(displayRules[0].localRuleId).assertEqual('rule-1')
        expect(displayRules[0].targetUserIds.length).assertEqual(2)
        expect(displayRules[0].deployments.length).assertEqual(2)
        expect(displayRules[0].userId).assertEqual(100)
        done()
      })

      it('should create a rule for one user and save the deployment', 0, async (done: Function) => {
        let addedRules: netFirewall.NetFirewallRule[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(7001)
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments.push(...deployments)
          return true
        })

        let result = await FirewallService.createRule(context, buildIpRuleInput('Allow HTTPS', [100]))

        expect(result.success).assertTrue()
        expect(addedRules.length).assertEqual(1)
        expect(addedRules[0].userId).assertEqual(100)
        expect(savedIntents.length).assertEqual(1)
        expect(savedIntents[0].name).assertEqual('Allow HTTPS')
        expect(savedDeployments.length).assertEqual(1)
        expect(savedDeployments[0].userId).assertEqual(100)
        expect(savedDeployments[0].systemRuleId).assertEqual(7001)
        done()
      })

      it('should create a rule for multiple users and save every deployment', 0, async (done: Function) => {
        let addedRules: netFirewall.NetFirewallRule[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(7100 + addedRules.length)
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments.push(...deployments)
          return true
        })

        let result = await FirewallService.createRule(context, buildIpRuleInput('Allow HTTPS', [101, 100, 101]))

        expect(result.success).assertTrue()
        expect(addedRules.length).assertEqual(2)
        expect(addedRules[0].userId).assertEqual(100)
        expect(addedRules[1].userId).assertEqual(101)
        expect(savedDeployments.length).assertEqual(2)
        expect(savedDeployments[0].systemRuleId).assertEqual(7101)
        expect(savedDeployments[1].systemRuleId).assertEqual(7102)
        done()
      })

      it('should reject invalid rule input before adding system rules', 0, async (done: Function) => {
        let addedRules: netFirewall.NetFirewallRule[] = []
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(7201)
        })

        let result = await FirewallService.createRule(context, buildIpRuleInput('', [100]))

        expect(result.success).assertFalse()
        expect(result.errorMessage).assertEqual('rule name is required')
        expect(addedRules.length).assertEqual(0)
        done()
      })

      it('should rollback successful deployments when multi-user create partially fails', 0, async (done: Function) => {
        let addedRules: netFirewall.NetFirewallRule[] = []
        let rolledBackSystemRuleIds: number[] = []
        let savedIntentCount = 0
        let savedDeploymentCount = 0
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          if (rule.userId === 101) {
            return new FakeAddRuleRawResult(undefined, 123, 'add failed')
          }
          return new FakeAddRuleRawResult(7300 + addedRules.length)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          rolledBackSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedIntentCount++
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedDeploymentCount++
          return true
        })

        let result = await FirewallService.createRule(context, buildIpRuleInput('Allow HTTPS', [100, 101]))

        expect(result.success).assertFalse()
        expect(result.failedItems?.length).assertEqual(1)
        expect(result.failedItems?.[0].userId).assertEqual(101)
        expect(rolledBackSystemRuleIds.length).assertEqual(1)
        expect(rolledBackSystemRuleIds[0]).assertEqual(7301)
        expect(savedIntentCount).assertEqual(0)
        expect(savedDeploymentCount).assertEqual(0)
        done()
      })

      it('should fail create when all user deployments fail', 0, async (done: Function) => {
        let savedIntentCount = 0
        let savedDeploymentCount = 0
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(undefined, 401, 'invalid'))
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedIntentCount++
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedDeploymentCount++
          return true
        })

        let result = await FirewallService.createRule(context, buildIpRuleInput('Allow HTTPS', [100, 101]))

        expect(result.success).assertFalse()
        expect(result.errorCode).assertEqual(401)
        expect(result.failedItems?.length).assertEqual(2)
        expect(savedIntentCount).assertEqual(0)
        expect(savedDeploymentCount).assertEqual(0)
        done()
      })

      it('should map duplicate DNS system error when create fails', 0, async (done: Function) => {
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(undefined, 29400007, 'duplicate dns rule'))
        when(saveIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)

        let result = await FirewallService.createRule(context, buildDnsRuleInput('DNS Rule', [100]))

        expect(result.success).assertFalse()
        expect(result.errorCode).assertEqual(29400007)
        expect(result.errorMessage).assertEqual(FirewallRuleStrings.APPLY_FAILED_DNS_DUPLICATE)
        done()
      })

      it('should fail update when rule intent is not found', 0, async (done: Function) => {
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        when(getIntentMock)(ArgumentMatchers.any).afterReturn(null)

        let result = await FirewallService.updateRule(context, 'missing-rule', buildIpRuleInput('Allow HTTPS', [100]))

        expect(result.success).assertFalse()
        expect(result.localRuleId).assertEqual('missing-rule')
        expect(result.errorMessage).assertEqual('rule intent not found')
        done()
      })

      it('should update an existing rule in place for the same target users', 0, async (done: Function) => {
        let removedSystemRuleIds: number[] = []
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('rule-1', 100, 8001)])
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(removeDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(8101))
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments.push(...deployments)
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('Updated Rule', [100]))

        expect(result.success).assertTrue()
        expect(result.localRuleId).assertEqual('rule-1')
        expect(updatedRules.length).assertEqual(1)
        expect((updatedRules[0] as FirewallScopedRule).id).assertEqual(8001)
        expect(updatedRules[0].name).assertEqual('Updated Rule')
        expect(removedSystemRuleIds.length).assertEqual(0)
        expect(savedIntents[0].localRuleId).assertEqual('rule-1')
        expect(savedIntents[0].name).assertEqual('Updated Rule')
        expect(savedDeployments[0].localRuleId).assertEqual('rule-1')
        expect(savedDeployments[0].systemRuleId).assertEqual(8001)
        done()
      })

      it('should update add and remove deployments by user delta when editing a rule', 0, async (done: Function) => {
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let addedRules: netFirewall.NetFirewallRule[] = []
        let removedSystemRuleIds: number[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100, 101]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(8102)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('Updated Rule', [101, 102]))

        expect(result.success).assertTrue()
        expect(updatedRules.length).assertEqual(1)
        expect(updatedRules[0].userId).assertEqual(101)
        expect((updatedRules[0] as FirewallScopedRule).id).assertEqual(8002)
        expect(addedRules.length).assertEqual(1)
        expect(addedRules[0].userId).assertEqual(102)
        expect(removedSystemRuleIds.length).assertEqual(1)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(savedIntents[0].targetUserIds.length).assertEqual(2)
        expect(savedDeployments.length).assertEqual(2)
        expect(savedDeployments[0].userId).assertEqual(101)
        expect(savedDeployments[0].systemRuleId).assertEqual(8002)
        expect(savedDeployments[1].userId).assertEqual(102)
        expect(savedDeployments[1].systemRuleId).assertEqual(8102)
        done()
      })

      it('should replace retained deployments when editing target type to DNS', 0, async (done: Function) => {
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let addedRules: netFirewall.NetFirewallRule[] = []
        let removedSystemRuleIds: number[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old IP Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('rule-1', 100, 8001)])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(8101)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildDnsRuleInput('DNS Rule', [100]))

        expect(result.success).assertTrue()
        expect(updatedRules.length).assertEqual(0)
        expect(removedSystemRuleIds.length).assertEqual(1)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(addedRules.length).assertEqual(1)
        expect(addedRules[0].type).assertEqual(netFirewall.NetFirewallRuleType.RULE_DNS)
        expect(addedRules[0].dns?.primaryDns).assertEqual('8.8.8.8')
        expect(addedRules[0].dns?.standbyDns).assertEqual('1.1.1.1')
        expect(savedIntents[0].type).assertEqual(netFirewall.NetFirewallRuleType.RULE_DNS)
        expect(savedDeployments[0].systemRuleId).assertEqual(8101)
        done()
      })

      it('should replace DNS retained deployments and save new system rule ids', 0, async (done: Function) => {
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let addedRules: netFirewall.NetFirewallRule[] = []
        let removedSystemRuleIds: number[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredDnsIntent('rule-1', 'Old DNS Rule', [100, 101]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(8100 + addedRules.length)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildDnsRuleInput('DNS Rule', [100, 101]))

        expect(result.success).assertTrue()
        expect(updatedRules.length).assertEqual(0)
        expect(removedSystemRuleIds.length).assertEqual(2)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(removedSystemRuleIds[1]).assertEqual(8002)
        expect(addedRules.length).assertEqual(2)
        expect(addedRules[0].userId).assertEqual(100)
        expect(addedRules[1].userId).assertEqual(101)
        expect(savedDeployments.length).assertEqual(2)
        expect(savedDeployments[0].systemRuleId).assertEqual(8101)
        expect(savedDeployments[1].systemRuleId).assertEqual(8102)
        done()
      })

      it('should restore old DNS deployment when replace add fails', 0, async (done: Function) => {
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let removedSystemRuleIds: number[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let savedIntentCount = 0
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredDnsIntent('rule-1', 'Old DNS Rule', [100, 101]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          if (rule.name === 'DNS Rule') {
            return new FakeAddRuleRawResult(undefined, 29400007, 'duplicate dns rule')
          }
          return new FakeAddRuleRawResult(9100)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedIntentCount++
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildDnsRuleInput('DNS Rule', [100, 101]))

        expect(result.success).assertFalse()
        expect(result.errorCode).assertEqual(29400007)
        expect(updatedRules.length).assertEqual(0)
        expect(removedSystemRuleIds.length).assertEqual(1)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(savedIntentCount).assertEqual(0)
        expect(savedDeployments.length).assertEqual(2)
        expect(savedDeployments[0].userId).assertEqual(101)
        expect(savedDeployments[0].systemRuleId).assertEqual(8002)
        expect(savedDeployments[1].userId).assertEqual(100)
        expect(savedDeployments[1].systemRuleId).assertEqual(9100)
        done()
      })

      it('should update retained deployments in place when editing DNS to IP', 0, async (done: Function) => {
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let addedRules: netFirewall.NetFirewallRule[] = []
        let removedSystemRuleIds: number[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredDnsIntent('rule-1', 'Old DNS Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('rule-1', 100, 8001)])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          return new FakeAddRuleRawResult(8101)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          savedDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('IP Rule', [100]))

        expect(result.success).assertTrue()
        expect(updatedRules.length).assertEqual(1)
        expect(updatedRules[0].type).assertEqual(netFirewall.NetFirewallRuleType.RULE_IP)
        expect((updatedRules[0] as FirewallScopedRule).id).assertEqual(8001)
        expect(addedRules.length).assertEqual(0)
        expect(removedSystemRuleIds.length).assertEqual(0)
        expect(savedDeployments[0].systemRuleId).assertEqual(8001)
        done()
      })

      it('should rollback updated and added deployments when edit removal fails', 0, async (done: Function) => {
        let updatePayloadNames: string[] = []
        let addedSystemRuleIds: number[] = []
        let removedSystemRuleIds: number[] = []
        let restoredDeployments: FirewallRuleDeployment[] = []
        let savedIntentCount = 0
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100, 101, 102]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002),
          buildDeployment('rule-1', 102, 8003)
        ])
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatePayloadNames.push(rule.name ?? '')
          return new FakeSystemRuleMutationResult(true)
        })
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          if (rule.userId === 103) {
            addedSystemRuleIds.push(8103)
            return new FakeAddRuleRawResult(8103)
          }
          return new FakeAddRuleRawResult(9100 + rule.userId)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return systemRuleId !== 8003
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedIntentCount++
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          restoredDeployments = deployments
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('Updated Rule', [101, 103]))

        expect(result.success).assertFalse()
        expect(updatePayloadNames.length).assertEqual(2)
        expect(updatePayloadNames[0]).assertEqual('Updated Rule')
        expect(updatePayloadNames[1]).assertEqual('Old Rule')
        expect(addedSystemRuleIds.length).assertEqual(1)
        expect(removedSystemRuleIds.length).assertEqual(3)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(removedSystemRuleIds[1]).assertEqual(8003)
        expect(removedSystemRuleIds[2]).assertEqual(8103)
        expect(savedIntentCount).assertEqual(0)
        expect(restoredDeployments.length).assertEqual(3)
        expect(restoredDeployments[0].systemRuleId).assertEqual(8002)
        expect(restoredDeployments[1].systemRuleId).assertEqual(8003)
        expect(restoredDeployments[2].systemRuleId).assertEqual(9200)
        done()
      })

      it('should keep old deployments when in-place update fails', 0, async (done: Function) => {
        let removedSystemRuleIds: number[] = []
        let updatedRules: netFirewall.NetFirewallRule[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeploymentCount = 0
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let updateRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.updateRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('rule-1', 100, 8001)])
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(undefined, 401, 'invalid'))
        when(updateRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          updatedRules.push(rule)
          return new FakeSystemRuleMutationResult(false, 401, 'invalid')
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((): boolean => {
          savedDeploymentCount++
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('Updated Rule', [100]))

        expect(result.success).assertFalse()
        expect(result.localRuleId).assertEqual('rule-1')
        expect(result.errorCode).assertEqual(401)
        expect(result.failedItems?.length).assertEqual(1)
        expect(updatedRules.length).assertEqual(1)
        expect(removedSystemRuleIds.length).assertEqual(0)
        expect(savedIntents.length).assertEqual(0)
        expect(savedDeploymentCount).assertEqual(0)
        done()
      })

      it('should reject invalid update before removing existing deployments', 0, async (done: Function) => {
        let removedSystemRuleIds: number[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('rule-1', 100, 8001)])
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(removeDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(8101))
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          savedIntents.push(intent)
          return true
        })

        let result = await FirewallService.updateRule(context, 'rule-1', buildIpRuleInput('', [100]))

        expect(result.success).assertFalse()
        expect(result.localRuleId).assertEqual('rule-1')
        expect(result.errorMessage).assertEqual('rule name is required')
        expect(removedSystemRuleIds.length).assertEqual(0)
        expect(savedIntents.length).assertEqual(0)
        done()
      })

      it('should delete a rule and remove local intent', 0, async (done: Function) => {
        let removedSystemRuleIds: number[] = []
        let removedIntentIds: string[] = []
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let removeIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleIntent)

        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          removedSystemRuleIds.push(systemRuleId)
          return true
        })
        when(removeDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
        when(removeIntentMock)(ArgumentMatchers.any).afterAction((_context: common.Context, localRuleId: string): boolean => {
          removedIntentIds.push(localRuleId)
          return true
        })

        let result = await FirewallService.deleteRule(context, 'rule-1')

        expect(result.success).assertTrue()
        expect(removedSystemRuleIds.length).assertEqual(2)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(removedSystemRuleIds[1]).assertEqual(8002)
        expect(removedIntentIds.length).assertEqual(1)
        expect(removedIntentIds[0]).assertEqual('rule-1')
        done()
      })

      it('should restore removed deployments when delete partially fails', 0, async (done: Function) => {
        let removedIntentIds: string[] = []
        let restoredDeployments: FirewallRuleDeployment[] = []
        let addRuleUsers: number[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)
        let removeIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleIntent)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100, 101]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addRuleUsers.push(rule.userId ?? -1)
          return new FakeAddRuleRawResult(9101)
        })
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          return systemRuleId !== 8002
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          restoredDeployments = deployments
          return true
        })
        when(removeIntentMock)(ArgumentMatchers.any).afterAction((_context: common.Context, localRuleId: string): boolean => {
          removedIntentIds.push(localRuleId)
          return true
        })

        let result = await FirewallService.deleteRule(context, 'rule-1')

        expect(result.success).assertFalse()
        expect(result.failedItems?.length).assertEqual(1)
        expect(addRuleUsers.length).assertEqual(1)
        expect(addRuleUsers[0]).assertEqual(100)
        expect(restoredDeployments.length).assertEqual(2)
        expect(restoredDeployments[0].systemRuleId).assertEqual(8002)
        expect(restoredDeployments[1].systemRuleId).assertEqual(9101)
        expect(removedIntentIds.length).assertEqual(0)
        done()
      })

      it('should report restore failure and keep local intent when restored deployments cannot be saved', 0, async (done: Function) => {
        let removedIntentIds: string[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)
        let removeIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleIntent)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('rule-1', 'Old Rule', [100, 101]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([
          buildDeployment('rule-1', 100, 8001),
          buildDeployment('rule-1', 101, 8002)
        ])
        when(addRuleMock)(ArgumentMatchers.any).afterReturn(new FakeAddRuleRawResult(9101))
        when(removeRuleMock)(ArgumentMatchers.any).afterAction((_userId: number, systemRuleId: number): boolean => {
          return systemRuleId !== 8002
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterReturn(false)
        when(removeIntentMock)(ArgumentMatchers.any).afterAction((_context: common.Context, localRuleId: string): boolean => {
          removedIntentIds.push(localRuleId)
          return true
        })

        let result = await FirewallService.deleteRule(context, 'rule-1')

        expect(result.success).assertFalse()
        expect(result.errorMessage).assertEqual('delete rule completed with failed items')
        expect(result.failedItems?.length).assertEqual(2)
        expect(result.failedItems?.[0].systemRuleId).assertEqual(8002)
        expect(result.failedItems?.[0].errorMessage).assertEqual('remove system rule failed')
        expect(result.failedItems?.[1].errorMessage).assertEqual('restore old deployments failed')
        expect(removedIntentIds.length).assertEqual(0)
        done()
      })

      it('should restore deleted conflict rule when replacement create fails', 0, async (done: Function) => {
        let restoredIntents: FirewallRuleIntent[] = []
        let restoredDeployments: FirewallRuleDeployment[] = []
        let addRuleCount = 0
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let removeIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleIntent)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('conflict-rule', 'Conflict Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('conflict-rule', 100, 9001)])
        when(removeRuleMock)(ArgumentMatchers.any).afterReturn(true)
        when(removeDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
        when(removeIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(addRuleMock)(ArgumentMatchers.any).afterAction((): Object => {
          addRuleCount++
          if (addRuleCount === 1) {
            return new FakeAddRuleRawResult(undefined, 401, 'invalid')
          }
          return new FakeAddRuleRawResult(9101)
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          restoredIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          _localRuleId: string,
          deployments: FirewallRuleDeployment[]
        ): boolean => {
          restoredDeployments = deployments
          return true
        })

        let result = await FirewallService.replaceConflictRule(
          context,
          'conflict-rule',
          undefined,
          buildIpRuleInput('Replacement Rule', [100]),
          false
        )

        expect(result.success).assertFalse()
        expect(result.errorMessage).assertEqual('replace conflict rule failed and restored old rule')
        expect(restoredIntents.length).assertEqual(1)
        expect(restoredIntents[0].localRuleId).assertEqual('conflict-rule')
        expect(restoredDeployments.length).assertEqual(1)
        expect(restoredDeployments[0].systemRuleId).assertEqual(9101)
        done()
      })

      it('should report restore failure when replacement create fails and old conflict rule cannot be restored', 0, async (done: Function) => {
        let restoredIntents: FirewallRuleIntent[] = []
        let addRuleCount = 0
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let removeIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleIntent)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(getIntentMock)(ArgumentMatchers.any).afterReturn(buildStoredIntent('conflict-rule', 'Conflict Rule', [100]))
        when(listDeploymentsMock)(ArgumentMatchers.any).afterReturn([buildDeployment('conflict-rule', 100, 9001)])
        when(removeRuleMock)(ArgumentMatchers.any).afterReturn(true)
        when(removeDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)
        when(removeIntentMock)(ArgumentMatchers.any).afterReturn(true)
        when(addRuleMock)(ArgumentMatchers.any).afterAction((): Object => {
          addRuleCount++
          if (addRuleCount === 1) {
            return new FakeAddRuleRawResult(undefined, 401, 'invalid')
          }
          return new FakeAddRuleRawResult(undefined, 9200001, 'restore failed')
        })
        when(saveIntentMock)(ArgumentMatchers.any).afterAction((
          _context: common.Context,
          intent: FirewallRuleIntent
        ): boolean => {
          restoredIntents.push(intent)
          return true
        })
        when(replaceDeploymentsMock)(ArgumentMatchers.any).afterReturn(true)

        let result = await FirewallService.replaceConflictRule(
          context,
          'conflict-rule',
          undefined,
          buildIpRuleInput('Replacement Rule', [100]),
          false
        )

        expect(result.success).assertFalse()
        expect(result.errorMessage).assertEqual('replace conflict rule failed and restore old rule failed')
        expect(result.failedItems?.length).assertEqual(2)
        expect(result.failedItems?.[0].errorMessage).assertEqual('invalid')
        expect(result.failedItems?.[1].errorMessage).assertEqual('restore failed')
        expect(restoredIntents.length).assertEqual(1)
        expect(restoredIntents[0].localRuleId).assertEqual('conflict-rule')
        done()
      })
    })
  })
}
