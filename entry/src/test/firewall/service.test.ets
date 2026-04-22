import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { AuthService } from '../../main/ets/services/identity/auth/AuthService'
import { FirewallLocalRepository } from '../../main/ets/services/firewall/FirewallLocalRepository'
import {
  FirewallBatchOperationResult,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallRuleIntentInput,
  FirewallRuleIntentMappingData,
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

function buildDeployment(localRuleId: string, userId: number, systemRuleId: number): FirewallRuleDeployment {
  return {
    localRuleId: localRuleId,
    userId: userId,
    systemRuleId: systemRuleId
  }
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

  when(userMock)().afterReturn(buildUserResult(users))
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

      it('should keep successful deployments when multi-user create partially fails', 0, async (done: Function) => {
        let addedRules: netFirewall.NetFirewallRule[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
        let saveIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.saveRuleIntent)
        let replaceDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.replaceRuleDeployments)

        when(addRuleMock)(ArgumentMatchers.any).afterAction((rule: netFirewall.NetFirewallRule): Object => {
          addedRules.push(rule)
          if (rule.userId === 101) {
            return new FakeAddRuleRawResult(undefined, 123, 'add failed')
          }
          return new FakeAddRuleRawResult(7300 + addedRules.length)
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

        let result = await FirewallService.createRule(context, buildIpRuleInput('Allow HTTPS', [100, 101]))

        expect(result.success).assertFalse()
        expect(result.successDeployments?.length).assertEqual(1)
        expect(result.successDeployments?.[0].userId).assertEqual(100)
        expect(result.failedItems?.length).assertEqual(1)
        expect(result.failedItems?.[0].userId).assertEqual(101)
        expect(savedDeployments.length).assertEqual(1)
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

      it('should fail update when rule intent is not found', 0, async (done: Function) => {
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        when(getIntentMock)(ArgumentMatchers.any).afterReturn(null)

        let result = await FirewallService.updateRule(context, 'missing-rule', buildIpRuleInput('Allow HTTPS', [100]))

        expect(result.success).assertFalse()
        expect(result.localRuleId).assertEqual('missing-rule')
        expect(result.errorMessage).assertEqual('rule intent not found')
        done()
      })

      it('should update an existing rule by replacing deployments for the same local rule id', 0, async (done: Function) => {
        let removedSystemRuleIds: number[] = []
        let savedIntents: FirewallRuleIntent[] = []
        let savedDeployments: FirewallRuleDeployment[] = []
        let getIntentMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.getRuleIntent)
        let listDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.listRuleDeployments)
        let removeRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.removeRule)
        let removeDeploymentsMock = mockKit.mockFunc(FirewallLocalRepository, FirewallLocalRepository.removeRuleDeployments)
        let addRuleMock = mockKit.mockFunc(FirewallSystemRepository, FirewallSystemRepository.addRule)
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
        expect(removedSystemRuleIds.length).assertEqual(1)
        expect(removedSystemRuleIds[0]).assertEqual(8001)
        expect(savedIntents[0].localRuleId).assertEqual('rule-1')
        expect(savedIntents[0].name).assertEqual('Updated Rule')
        expect(savedDeployments[0].localRuleId).assertEqual('rule-1')
        expect(savedDeployments[0].systemRuleId).assertEqual(8101)
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
    })
  })
}
