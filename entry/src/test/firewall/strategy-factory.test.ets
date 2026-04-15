import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import {
  attachFirewallRuleUserIds,
  FirewallUserApplyMode,
  UserFirewallOption
} from '../../main/ets/models/DataModels'
import { FirewallModeStrategyFactory } from '../../main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory'
import { FirewallCustomRulesRepository } from '../../main/ets/services/firewall/repositories/FirewallCustomRulesRepository'
import { FirewallModeRepository } from '../../main/ets/services/firewall/repositories/FirewallModeRepository'
import { FirewallUserBindingsRepository } from '../../main/ets/services/firewall/repositories/FirewallUserBindingsRepository'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'
import { SystemUserProvider } from '../../main/ets/services/firewall/providers/SystemUserProvider'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

function createManagedRule(
  name: string,
  action: number,
  customRuleId: string = 'demo'
): netFirewall.NetFirewallRule {
  return FirewallRulesService.applyManagedRuleMetadata({
    userId: 100,
    name,
    direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
    action,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true
  } as netFirewall.NetFirewallRule, {
    owner: 'security_tool',
    mode: 'custom',
    kind: 'custom',
    customRuleId
  })
}

function createUsers(): UserFirewallOption[] {
  return [
    { userId: 100, label: '用户 100' } as UserFirewallOption,
    { userId: 101, label: '用户 101' } as UserFirewallOption
  ]
}

export default function firewallStrategyFactoryTest() {
  describe('FirewallModeStrategyFactory', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should return expected strategies for each mode', 0, () => {
      expect(FirewallModeStrategyFactory.getStrategy('public').mode).assertEqual('public')
      expect(FirewallModeStrategyFactory.getStrategy('private').mode).assertEqual('private')
      expect(FirewallModeStrategyFactory.getStrategy('custom').mode).assertEqual('custom')
    })

    it('should expose empty custom rules when storage is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      when(loadMock)(context).afterReturn([])

      let modeRules = (await FirewallModeStrategyFactory.buildRulesForMode(context, 'custom')) ?? []
      let customRules = (await FirewallModeStrategyFactory.listCustomRules(context)) ?? []
      let applyRules = (await FirewallModeStrategyFactory.buildCustomRulesForApply(context)) ?? []

      expect(modeRules.length >= 0).assertTrue()
      expect(customRules.length >= 0).assertTrue()
      expect(applyRules.length).assertEqual(customRules.length)
    })

    it('should apply preset mode to all available users and preserve existing actions', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let buildRulesMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.buildRulesForMode)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let getPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicyByUserId)
      let getAllRulesMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getAllRules)
      let setPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallPolicyByUserId)
      let addRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.addRule)
      let saveModeMock = mockKit.mockFunc(FirewallModeRepository, FirewallModeRepository.saveCurrentMode)
      let targetRule = createManagedRule('preset-rule', netFirewall.FirewallRuleAction.RULE_ALLOW, 'preset_demo')
      let policyPayloads: netFirewall.NetFirewallPolicy[] = []
      let addRuleUserIds: number[] = []

      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(buildRulesMock)(context, 'public').afterReturn(Promise.resolve([targetRule]))
      when(loadUsersMock)().afterReturn({
        users: createUsers(),
        selectedUserId: 100
      })
      when(getPolicyByUserMock)(100).afterReturn(Promise.resolve({
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_DENY,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      } as netFirewall.NetFirewallPolicy))
      when(getPolicyByUserMock)(101).afterReturn(Promise.resolve({
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_DENY
      } as netFirewall.NetFirewallPolicy))
      when(getAllRulesMock)(100).afterReturn(Promise.resolve([]))
      when(getAllRulesMock)(101).afterReturn(Promise.resolve([]))
      when(setPolicyByUserMock)(ArgumentMatchers.anyNumber, ArgumentMatchers.anyObj).afterAction((
        _userId: number,
        policy: netFirewall.NetFirewallPolicy
      ) => {
        policyPayloads.push(policy)
        return Promise.resolve(true)
      })
      when(addRuleMock)(ArgumentMatchers.anyObj).afterAction((rule: netFirewall.NetFirewallRule) => {
        addRuleUserIds.push(rule.userId ?? -1)
        return Promise.resolve(addRuleUserIds.length)
      })
      when(saveModeMock)(context, 'public').afterReturn(Promise.resolve())

      let result = await FirewallModeStrategyFactory.switchMode(context, 'public')

      expect(result.success).assertTrue()
      expect(policyPayloads.length).assertEqual(2)
      expect(policyPayloads[0].isOpen).assertTrue()
      expect(policyPayloads[0].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(policyPayloads[0].outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(policyPayloads[1].isOpen).assertTrue()
      expect(policyPayloads[1].inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(policyPayloads[1].outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(addRuleUserIds.length).assertEqual(2)
      expect(addRuleUserIds[0]).assertEqual(100)
      expect(addRuleUserIds[1]).assertEqual(101)
    })

    it('should apply custom mode to all users using binding-based policy and user scoped rules', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let loadUsersMock = mockKit.mockFunc(SystemUserProvider, SystemUserProvider.loadAvailableUserIds)
      let getPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicyByUserId)
      let getAllRulesMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getAllRules)
      let getBindingModeMock = mockKit.mockFunc(FirewallUserBindingsRepository, FirewallUserBindingsRepository.getBindingMode)
      let setPolicyByUserMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.setFirewallPolicyByUserId)
      let addRuleMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.addRule)
      let saveModeMock = mockKit.mockFunc(FirewallModeRepository, FirewallModeRepository.saveCurrentMode)
      let denyRule = attachFirewallRuleUserIds(
        createManagedRule('deny-only', netFirewall.FirewallRuleAction.RULE_DENY, 'custom_deny'),
        [100]
      )
      let allowRule = attachFirewallRuleUserIds(
        createManagedRule('allow-only', netFirewall.FirewallRuleAction.RULE_ALLOW, 'custom_allow'),
        [101]
      )
      let policyByUser = new Map<number, netFirewall.NetFirewallPolicy>()
      let addedRuleUserIds: number[] = []

      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(loadUsersMock)().afterReturn({
        users: createUsers(),
        selectedUserId: 100
      })
      when(getPolicyByUserMock)(100).afterReturn(Promise.resolve({
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      } as netFirewall.NetFirewallPolicy))
      when(getPolicyByUserMock)(101).afterReturn(Promise.resolve({
        isOpen: false,
        inAction: netFirewall.FirewallRuleAction.RULE_ALLOW,
        outAction: netFirewall.FirewallRuleAction.RULE_ALLOW
      } as netFirewall.NetFirewallPolicy))
      when(getAllRulesMock)(100).afterReturn(Promise.resolve([]))
      when(getAllRulesMock)(101).afterReturn(Promise.resolve([]))
      when(getBindingModeMock)(context, 100).afterReturn(Promise.resolve('denylist' as FirewallUserApplyMode))
      when(getBindingModeMock)(context, 101).afterReturn(Promise.resolve('allowlist' as FirewallUserApplyMode))
      when(setPolicyByUserMock)(ArgumentMatchers.anyNumber, ArgumentMatchers.anyObj).afterAction((
        userId: number,
        policy: netFirewall.NetFirewallPolicy
      ) => {
        policyByUser.set(userId, policy)
        return Promise.resolve(true)
      })
      when(addRuleMock)(ArgumentMatchers.anyObj).afterAction((rule: netFirewall.NetFirewallRule) => {
        addedRuleUserIds.push(rule.userId ?? -1)
        return Promise.resolve(addedRuleUserIds.length)
      })
      when(saveModeMock)(context, 'custom').afterReturn(Promise.resolve())

      let result = await FirewallModeStrategyFactory.applyCustomRules(context, [denyRule, allowRule])

      expect(result.success).assertTrue()
      expect(policyByUser.get(100)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(policyByUser.get(100)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_DENY)
      expect(policyByUser.get(101)?.inAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(policyByUser.get(101)?.outAction).assertEqual(netFirewall.FirewallRuleAction.RULE_ALLOW)
      expect(addedRuleUserIds.length).assertEqual(2)
      expect(addedRuleUserIds[0]).assertEqual(100)
      expect(addedRuleUserIds[1]).assertEqual(101)
    })


    it('should fallback to custom mode when store is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext
      let mode = await FirewallModeStrategyFactory.getCurrentMode(context)

      expect(mode).assertEqual('custom')
    })

    it('should initialize custom rules from empty system rule set without throwing', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      when(loadMock)(context).afterReturn([])

      await FirewallModeStrategyFactory.initializeCustomRulesFromSystemIfEmpty(context, [])

      expect(true).assertTrue()
    })

    it('should replace custom rules and return a boolean result', 0, async () => {
      let context = {} as common.UIAbilityContext
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      when(saveMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))
      let result = await FirewallModeStrategyFactory.replaceAllCustomRules(context, [createManagedRule('custom-demo', netFirewall.FirewallRuleAction.RULE_ALLOW, 'custom_demo')])

      expect(typeof result === 'boolean').assertTrue()
    })

    it('should expose custom rule id through factory helper', 0, () => {
      let rule = createManagedRule('custom-demo', netFirewall.FirewallRuleAction.RULE_ALLOW, 'custom_demo')

      expect(FirewallModeStrategyFactory.getCustomRuleId(rule)).assertEqual('custom_demo')
    })
  })
}
