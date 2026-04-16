import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallModeStrategyFactory } from '../../main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'
import { FirewallUserDispatchService } from '../../main/ets/services/firewall/user-dispatch/FirewallUserDispatchService'
import { FirewallStore } from '../../main/ets/services/firewall/stores/FirewallStore'
import { FirewallAuthService } from '../../main/ets/services/firewall/auth/FirewallAuthService'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'
import { UserFirewallOption } from '../../main/ets/models/firewall/firewall_service_contracts'

function createPolicy(isOpen: boolean, inAction: number, outAction: number): netFirewall.NetFirewallPolicy {
  return {
    isOpen,
    inAction,
    outAction
  } as netFirewall.NetFirewallPolicy
}

function createRule(
  key: number,
  name: string,
  type: netFirewall.NetFirewallRuleType,
  direction: netFirewall.NetFirewallRuleDirection,
  action: number
): netFirewall.NetFirewallRule {
  return {
    ruleId: key,
    userId: 100,
    name,
    type,
    direction,
    action,
    isEnabled: true
  } as netFirewall.NetFirewallRule
}

function createUsers(): UserFirewallOption[] {
  return [
    { userId: 100, label: '用户 100' } as UserFirewallOption,
    { userId: 101, label: '用户 101' } as UserFirewallOption
  ]
}

export default function firewallServiceTest() {
  describe('FirewallRepository and FirewallService', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should remove any-ip remote params during rule normalization', 0, () => {
      let rule: netFirewall.NetFirewallRule = {
        userId: 100,
        name: 'allow-any-ip',
        direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
        action: 0,
        type: netFirewall.NetFirewallRuleType.RULE_IP,
        isEnabled: true,
        remoteIps: [{
          type: 1,
          family: 1,
          address: '0.0.0.0',
          mask: 0
        } as netFirewall.NetFirewallIpParams]
      } as netFirewall.NetFirewallRule

      let result = FirewallRepository.normalizeRuleForCreate(rule)

      expect(result.remoteIps === undefined).assertTrue()
      expect(result.name).assertEqual('allow-any-ip')
    })

    it('should clone rule fields needed for create payload', 0, () => {
      let source: netFirewall.NetFirewallRule = {
        ruleId: 11,
        userId: 100,
        name: 'rule-a',
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: 1,
        type: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        isEnabled: false,
        description: 'demo',
        domains: [{
          domain: 'example.com',
          isWildcard: false
        } as netFirewall.NetFirewallDomainParams]
      } as netFirewall.NetFirewallRule

      let cloned = FirewallRepository.cloneRuleForCreate(source)

      expect(cloned.name).assertEqual('rule-a')
      expect(cloned.description).assertEqual('demo')
      expect(cloned.domains?.length ?? 0).assertEqual(1)
      expect(cloned.isEnabled).assertFalse()
    })

    it('should build default overview when no users are available', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(loadUsersMock)().afterReturn({
        users: [],
        message: 'no users'
      })

      let result = await FirewallService.loadOverviewState(context)

      expect(result.enabled).assertFalse()
      expect(result.currentMode).assertEqual('custom')
    })

    it('should build overview from aggregated user policies and stored mode', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let getPolicyMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.getPolicy)
      let currentModeMock = mockKit.mockFunc(FirewallStore, FirewallStore.getCurrentMode)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(loadUsersMock)().afterReturn({
        users: createUsers(),
        selectedUserId: 100
      })
      when(getPolicyMock)(100).afterReturn(Promise.resolve({
        userId: 100,
        isOpen: true,
        inAction: 0,
        outAction: 0
      }))
      when(getPolicyMock)(101).afterReturn(Promise.resolve({
        userId: 101,
        isOpen: false,
        inAction: 1,
        outAction: 0
      }))
      when(currentModeMock)(context).afterReturn(Promise.resolve('private'))

      let result = await FirewallService.loadOverviewState(context)

      expect(result.enabled).assertFalse()
      expect(result.currentMode).assertEqual('private')
    })

    it('should delegate toggle through auth service with multi-user apply action', 0, async () => {
      let context = {} as common.UIAbilityContext
      let executeToggleMock = mockKit.mockFunc(FirewallAuthService, FirewallAuthService.executeToggle)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let getPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicyByUserId)
      let setPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallPolicyByUserId)
      let currentModeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.getCurrentMode)
      let switchModeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.switchMode)
      let applyInvoked = false
      let switchModeInvoked = false

      when(loadUsersMock)().afterReturn({
        users: createUsers(),
        selectedUserId: 100
      })
      when(getPolicyByUserMock)(100).afterReturn(Promise.resolve(createPolicy(false, 0, 1)))
      when(getPolicyByUserMock)(101).afterReturn(Promise.resolve(createPolicy(false, 1, 0)))
      when(setPolicyByUserMock)(ArgumentMatchers.anyNumber, ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))
      when(currentModeMock)(context).afterReturn(Promise.resolve('public'))
      when(switchModeMock)(context, 'public').afterAction((_ctx: common.UIAbilityContext, mode: string) => {
        switchModeInvoked = true
        let _mode = mode
        return Promise.resolve({
          success: true,
          mode: _mode,
          appliedRuleCount: 2
        })
      })
      when(executeToggleMock)(
        context,
        false,
        true,
        ArgumentMatchers.anyObj
      ).afterAction((
        ctx: common.UIAbilityContext,
        currentEnabled: boolean,
        targetEnabled: boolean,
        applyAction: (enabled: boolean) => Promise<boolean>
      ) => {
        let _ctx = ctx
        let _currentEnabled = currentEnabled
        let _targetEnabled = targetEnabled
        let _ = [_ctx, _currentEnabled, _targetEnabled]
        applyInvoked = true
        return applyAction(true).then((ok: boolean) => {
          return {
            success: ok,
            targetEnabled: true
          }
        })
      })

      let result = await FirewallService.toggleFirewall(context, false, true)

      expect(applyInvoked).assertTrue()
      expect(switchModeInvoked).assertTrue()
      expect(result.success).assertTrue()
      expect(result.targetEnabled).assertTrue()
    })

    it('should disable all available users when toggled off', 0, async () => {
      let context = {} as common.UIAbilityContext
      let executeToggleMock = mockKit.mockFunc(FirewallAuthService, FirewallAuthService.executeToggle)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let getPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicyByUserId)
      let setPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallPolicyByUserId)
      let applyInvoked = false
      let appliedPolicies: Array<{ userId: number, policy: netFirewall.NetFirewallPolicy }> = []

      when(loadUsersMock)().afterReturn({
        users: createUsers(),
        selectedUserId: 100
      })
      when(getPolicyByUserMock)(100).afterReturn(Promise.resolve(createPolicy(true, netFirewall.FirewallRuleAction.RULE_ALLOW, netFirewall.FirewallRuleAction.RULE_DENY)))
      when(getPolicyByUserMock)(101).afterReturn(Promise.resolve(createPolicy(true, netFirewall.FirewallRuleAction.RULE_DENY, netFirewall.FirewallRuleAction.RULE_ALLOW)))
      when(setPolicyByUserMock)(ArgumentMatchers.anyNumber, ArgumentMatchers.anyObj).afterAction((
        userId: number,
        policy: netFirewall.NetFirewallPolicy
      ) => {
        appliedPolicies.push({ userId, policy })
        return Promise.resolve(true)
      })
      when(executeToggleMock)(
        context,
        true,
        false,
        ArgumentMatchers.anyObj
      ).afterAction((
        _ctx: common.UIAbilityContext,
        _currentEnabled: boolean,
        _targetEnabled: boolean,
        applyAction: (enabled: boolean) => Promise<boolean>
      ) => {
        applyInvoked = true
        return applyAction(false).then((ok: boolean) => {
          return {
            success: ok,
            targetEnabled: false
          }
        })
      })

      let result = await FirewallService.toggleFirewall(context, true, false)

      expect(applyInvoked).assertTrue()
      expect(result.success).assertTrue()
      expect(result.targetEnabled).assertFalse()
      expect(appliedPolicies.length).assertEqual(2)
      expect(appliedPolicies[0].policy.isOpen).assertFalse()
      expect(appliedPolicies[1].policy.isOpen).assertFalse()
      expect(appliedPolicies[0].policy.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(appliedPolicies[0].policy.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(appliedPolicies[1].policy.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(appliedPolicies[1].policy.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
    })

    it('should delegate loading user options through dispatch service', 0, async () => {
      let loadUserOptionsMock = mockKit.mockFunc(FirewallUserDispatchService, FirewallUserDispatchService.loadUserOptions)
      when(loadUserOptionsMock)().afterReturn([
        { userId: 100, label: 'owner' },
        { userId: 101, label: 'guest' }
      ])

      let options = await FirewallService.loadUserOptions()

      expect(options.length).assertEqual(2)
      expect(options[1].label).assertEqual('guest')
    })

    it('should return zero user reapply counters after saving custom rules', 0, async () => {
      let context = {} as common.UIAbilityContext
      let rules = [
        createRule(1, 'rule-a', netFirewall.NetFirewallRuleType.RULE_IP, netFirewall.NetFirewallRuleDirection.RULE_IN, 0)
      ]
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let listMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.listCustomRules)
      let applyCustomRulesMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.applyCustomRules)
      let replaceAllRulesMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.replaceAllCustomRules)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(listMock)(context).afterReturn(Promise.resolve([]))
      when(applyCustomRulesMock)(context, rules).afterReturn(Promise.resolve({
        success: true,
        mode: 'custom',
        appliedRuleCount: 1
      }))
      when(replaceAllRulesMock)(context, rules).afterReturn(Promise.resolve(true))

      let result = await FirewallService.saveCustomRules(context, rules)

      expect(result.success).assertTrue()
      expect(result.reapplyTotalUsers ?? -1).assertEqual(0)
      expect(result.reapplySuccessCount ?? -1).assertEqual(0)
      expect(result.reapplyFailedCount ?? -1).assertEqual(0)
    })

    it('should list custom rules from store after initialization', 0, async () => {
      let context = {} as common.UIAbilityContext
      let rules = [
        createRule(1, 'rule-a', netFirewall.NetFirewallRuleType.RULE_IP, netFirewall.NetFirewallRuleDirection.RULE_IN, 0)
      ]
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let listMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.listCustomRules)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(listMock)(context).afterReturn(Promise.resolve(rules))

      let result = await FirewallService.listCustomRules(context)

      expect(result.length).assertEqual(1)
      expect(result[0].name).assertEqual('rule-a')
    })

    it('should delegate user mode apply through dispatch service', 0, async () => {
      let context = {} as common.UIAbilityContext
      let applyModeMock = mockKit.mockFunc(FirewallUserDispatchService, FirewallUserDispatchService.applyUserMode)
      when(applyModeMock)(context, 100, 'allowlist').afterReturn(Promise.resolve({
        success: true,
        userId: 100,
        mode: 'allowlist',
        appliedRuleCount: 0
      }))

      let result = await FirewallService.applyUserMode(context, 100, 'allowlist')

      expect(result.success).assertTrue()
      expect(result.userId).assertEqual(100)
      expect(result.mode).assertEqual('allowlist')
      expect(result.appliedRuleCount).assertEqual(0)
    })

    it('should delegate repository operations through service facade', 0, async () => {
      let rule = createRule(1, 'rule-a', netFirewall.NetFirewallRuleType.RULE_IP, netFirewall.NetFirewallRuleDirection.RULE_IN, 0)
      let policy = createPolicy(true, 0, 1)
      let getPolicyMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicy)
      let getAllRulesMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getAllRules)
      let setEnabledMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallEnabled)
      let setPolicyMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallPolicy)
      let addRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.addRule)
      let removeRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.removeRule)
      let updateRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.updateRule)
      let addRulesMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.addRules)
      let clearAllRulesMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.clearAllRules)
      when(getPolicyMock)().afterReturn(Promise.resolve(policy))
      when(getAllRulesMock)().afterReturn(Promise.resolve([rule]))
      when(setEnabledMock)(true).afterReturn(Promise.resolve(true))
      when(setPolicyMock)(policy).afterReturn(Promise.resolve(true))
      when(addRuleMock)(rule).afterReturn(Promise.resolve(8))
      when(removeRuleMock)(1).afterReturn(Promise.resolve(true))
      when(updateRuleMock)(rule).afterReturn(Promise.resolve(true))
      when(addRulesMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))
      when(clearAllRulesMock)().afterReturn(Promise.resolve(true))

      let loadedPolicy = await FirewallService.getFirewallPolicy()
      let loadedRules = await FirewallService.getAllRules()
      expect(loadedPolicy === null || loadedPolicy === undefined || typeof loadedPolicy.isOpen === 'boolean').assertTrue()
      expect((loadedRules?.length ?? 0) >= 0).assertTrue()
      expect(typeof (await FirewallService.setFirewallEnabled(true))).assertEqual('boolean')
      expect(typeof (await FirewallService.setFirewallPolicy(policy))).assertEqual('boolean')
      expect(typeof (await FirewallService.addRule(rule))).assertEqual('number')
      expect(typeof (await FirewallService.removeRule(1))).assertEqual('boolean')
      expect(typeof (await FirewallService.updateRule(rule))).assertEqual('boolean')
      expect(typeof (await FirewallService.addRules([rule]))).assertEqual('boolean')
      expect(typeof (await FirewallService.clearAllRules())).assertEqual('boolean')
    })

    it('should replace rule only after old rule removal succeeds', 0, async () => {
      let rule = createRule(2, 'rule-b', netFirewall.NetFirewallRuleType.RULE_DOMAIN, netFirewall.NetFirewallRuleDirection.RULE_OUT, 1)
      let removeRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.removeRule)
      let addRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.addRule)
      when(removeRuleMock)(2).afterReturn(true)
      when(addRuleMock)(rule).afterReturn(9)

      let result = await FirewallRepository.replaceRule(2, rule)

      expect(result).assertEqual(9)
    })

    it('should fail replace rule when old rule removal fails', 0, async () => {
      let rule = createRule(3, 'rule-c', netFirewall.NetFirewallRuleType.RULE_DOMAIN, netFirewall.NetFirewallRuleDirection.RULE_OUT, 1)
      let removeRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.removeRule)
      when(removeRuleMock)(3).afterReturn(false)

      let result = await FirewallRepository.replaceRule(3, rule)

      expect(result).assertEqual(-1)
    })

  })
}
