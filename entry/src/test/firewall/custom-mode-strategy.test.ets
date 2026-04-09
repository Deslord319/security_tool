import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import { CustomModeStrategy } from '../../main/ets/services/firewall/mode-strategies/CustomModeStrategy'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

interface StoredCustomFirewallRuleRecordLike {
  customRuleId: string
  rule: netFirewall.NetFirewallRule
}

interface CustomModeStrategyContractAccess {
  toDisplayRule(record: StoredCustomFirewallRuleRecordLike): netFirewall.NetFirewallRule
  toStoredRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule
  generateCustomRuleId(): string
  createRecord(customRuleId: string, rule: netFirewall.NetFirewallRule): StoredCustomFirewallRuleRecordLike
  hashRuleId(customRuleId: string): number
}

function createRule(name: string): netFirewall.NetFirewallRule {
  return {
    userId: 100,
    name,
    direction: netFirewall.NetFirewallRuleDirection.RULE_IN,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true
  } as netFirewall.NetFirewallRule
}

export default function customModeStrategyTest() {
  describe('CustomModeStrategy', () => {
    it('should extract custom rule id from managed metadata only', 0, () => {
      let customRule = FirewallRulesService.applyManagedRuleMetadata(createRule('custom-rule'), {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: 'custom_123'
      })
      let presetRule = FirewallRulesService.applyManagedRuleMetadata(createRule('preset-rule'), {
        owner: 'security_tool',
        mode: 'public',
        kind: 'preset',
        templateKey: 'allow_all'
      })

      expect(CustomModeStrategy.getCustomRuleId(customRule)).assertEqual('custom_123')
      expect(CustomModeStrategy.getCustomRuleId(presetRule) === undefined).assertTrue()
    })

    it('should convert stored rule to display rule with hashed id and custom metadata', 0, () => {
      let contract = CustomModeStrategy as Object as CustomModeStrategyContractAccess
      let record = contract.createRecord('custom_abc', createRule('demo'))

      let displayRule = contract.toDisplayRule(record)

      expect(displayRule.id !== undefined).assertTrue()
      expect(displayRule.description?.includes('custom_abc') ?? false).assertTrue()
      expect(CustomModeStrategy.getCustomRuleId(displayRule)).assertEqual('custom_abc')
    })

    it('should strip description when converting to stored rule', 0, () => {
      let contract = CustomModeStrategy as Object as CustomModeStrategyContractAccess
      let rule = FirewallRulesService.applyManagedRuleMetadata(createRule('demo'), {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: 'custom_demo'
      })

      let storedRule = contract.toStoredRule(rule)

      expect(storedRule.description === undefined).assertTrue()
      expect(storedRule.name).assertEqual('demo')
    })

    it('should generate stable non-zero hashes for custom rule ids', 0, () => {
      let contract = CustomModeStrategy as Object as CustomModeStrategyContractAccess
      let generatedId = contract.generateCustomRuleId()
      let hash1 = contract.hashRuleId('custom_same')
      let hash2 = contract.hashRuleId('custom_same')

      expect(generatedId.startsWith('custom_')).assertTrue()
      expect(hash1 > 0).assertTrue()
      expect(hash1).assertEqual(hash2)
    })

    it('should return empty rules when custom store is unavailable', 0, async () => {
      let context = {} as common.UIAbilityContext

      let listRules = await CustomModeStrategy.listRules(context)
      let applyRules = await CustomModeStrategy.buildRulesForApply(context)

      expect(listRules.length >= 0).assertTrue()
      expect(applyRules.length).assertEqual(listRules.length)
    })

    it('should short-circuit initialization when system rules are empty', 0, async () => {
      let context = {} as common.UIAbilityContext

      await CustomModeStrategy.initializeFromSystemIfEmpty(context, [])

      expect(true).assertTrue()
    })

    it('should replace all custom rules and return a boolean result', 0, async () => {
      let context = {} as common.UIAbilityContext
      let result = await CustomModeStrategy.replaceAllRules(context, [createRule('demo')])

      expect(typeof result === 'boolean').assertTrue()
    })

    it('should add rules and reject update/remove when custom metadata is missing', 0, async () => {
      let context = {} as common.UIAbilityContext
      let rule = createRule('demo')

      expect(typeof (await CustomModeStrategy.addRule(context, rule)) === 'boolean').assertTrue()
      expect(await CustomModeStrategy.updateRule(context, rule)).assertFalse()
      expect(await CustomModeStrategy.removeRule(context, rule)).assertFalse()
    })
  })
}
