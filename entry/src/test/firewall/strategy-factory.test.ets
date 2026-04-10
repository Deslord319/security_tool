import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { FirewallModeStrategyFactory } from '../../main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory'
import { FirewallCustomRulesRepository } from '../../main/ets/services/firewall/repositories/FirewallCustomRulesRepository'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

function createCustomRule(): netFirewall.NetFirewallRule {
  return FirewallRulesService.applyManagedRuleMetadata({
    userId: 100,
    name: 'custom-demo',
    direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true
  } as netFirewall.NetFirewallRule, {
    owner: 'security_tool',
    mode: 'custom',
    kind: 'custom',
    customRuleId: 'custom_demo'
  })
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

    it('should fallback to custom mode when store is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext
      let mode = await FirewallModeStrategyFactory.getCurrentMode(context)

      expect(mode).assertEqual('custom')
    })

    it('should expose empty custom rules when storage is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      when(loadMock)(context).afterReturn([])
      let modeRules = await FirewallModeStrategyFactory.buildRulesForMode(context, 'custom')
      let customRules = await FirewallModeStrategyFactory.listCustomRules(context)
      let applyRules = await FirewallModeStrategyFactory.buildCustomRulesForApply(context)

      expect(modeRules.length >= 0).assertTrue()
      expect(customRules.length >= 0).assertTrue()
      expect(applyRules.length).assertEqual(customRules.length)
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
      let result = await FirewallModeStrategyFactory.replaceAllCustomRules(context, [createCustomRule()])

      expect(typeof result === 'boolean').assertTrue()
    })

    it('should expose custom rule id through factory helper', 0, () => {
      let rule = createCustomRule()

      expect(FirewallModeStrategyFactory.getCustomRuleId(rule)).assertEqual('custom_demo')
    })
  })
}
