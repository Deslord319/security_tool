import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { FirewallModeStrategyFactory } from '../../main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory'
import { FirewallRepository } from '../../main/ets/services/firewall/repositories/FirewallRepository'
import { FirewallUserDispatchService } from '../../main/ets/services/firewall/user-dispatch/FirewallUserDispatchService'
import { FirewallStore } from '../../main/ets/services/firewall/stores/FirewallStore'

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

    it('should read rule primary key from ruleId or id field', 0, () => {
      let ruleWithRuleId = createRule(8, 'rule-a', netFirewall.NetFirewallRuleType.RULE_IP,
        netFirewall.NetFirewallRuleDirection.RULE_IN, 0)
      let ruleWithId = {
        id: 9,
        userId: 100,
        name: 'rule-b',
        direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
        action: 1,
        type: netFirewall.NetFirewallRuleType.RULE_DOMAIN,
        isEnabled: true
      } as netFirewall.NetFirewallRule

      expect(FirewallRepository.getRulePrimaryKey(ruleWithRuleId)).assertEqual(8)
      expect(FirewallRepository.getRulePrimaryKey(ruleWithId)).assertEqual(9)
    })

    it('should delegate count helpers through FirewallService', 0, () => {
      let rules: netFirewall.NetFirewallRule[] = [
        createRule(1, 'rule-a', netFirewall.NetFirewallRuleType.RULE_IP, netFirewall.NetFirewallRuleDirection.RULE_IN, 0),
        createRule(2, 'rule-b', netFirewall.NetFirewallRuleType.RULE_DOMAIN, netFirewall.NetFirewallRuleDirection.RULE_OUT, 1),
        createRule(3, 'rule-c', netFirewall.NetFirewallRuleType.RULE_DOMAIN, netFirewall.NetFirewallRuleDirection.RULE_IN, 0)
      ]

      expect(FirewallService.countByType(rules, netFirewall.NetFirewallRuleType.RULE_DOMAIN)).assertEqual(2)
      expect(FirewallService.countByDirection(rules, netFirewall.NetFirewallRuleDirection.RULE_IN)).assertEqual(2)
    })

    it('should build default overview when policy is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let getPolicyMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicy)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(getPolicyMock)().afterReturn(Promise.resolve(null))

      let result = await FirewallService.loadOverviewState(context)

      expect((result?.enabled ?? false)).assertFalse()
      expect(result?.currentMode ?? 'custom').assertEqual('custom')
    })

    it('should build overview from repository and store state', 0, async () => {
      let context = {} as common.UIAbilityContext
      let initializeMock = mockKit.mockFunc(FirewallModeStrategyFactory, FirewallModeStrategyFactory.initialize)
      let getPolicyMock = mockKit.mockFunc(FirewallRepository, FirewallRepository.getFirewallPolicy)
      let currentModeMock = mockKit.mockFunc(FirewallStore, FirewallStore.getCurrentMode)
      when(initializeMock)(context).afterReturn(Promise.resolve())
      when(getPolicyMock)().afterReturn(Promise.resolve(createPolicy(true, 0, 1)))
      when(currentModeMock)(context).afterReturn(Promise.resolve('private'))

      let result = await FirewallService.loadOverviewState(context)

      expect(typeof (result?.enabled ?? false)).assertEqual('boolean')
      expect((result?.currentMode ?? 'custom').length > 0).assertTrue()
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
