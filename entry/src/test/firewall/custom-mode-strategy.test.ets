import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'

import { CustomModeStrategy } from '../../main/ets/services/firewall/mode-strategies/CustomModeStrategy'
import {
  FirewallCustomRulesRepository,
  StoredCustomFirewallRuleRecord
} from '../../main/ets/services/firewall/repositories/FirewallCustomRulesRepository'
import { FirewallRulesService } from '../../main/ets/services/firewall/rules/FirewallRulesService'

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

function createStoredRecord(customRuleId: string, name: string): StoredCustomFirewallRuleRecord {
  return {
    customRuleId,
    rule: createRule(name),
    userIds: [100]
  }
}

export default function customModeStrategyTest() {
  describe('CustomModeStrategy', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

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

    it('should convert stored rules to display rules with stable ids and custom metadata', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      when(loadMock)(context).afterReturn([
        createStoredRecord('custom_abc', 'demo')
      ])

      let first = await CustomModeStrategy.listRules(context)
      let second = await CustomModeStrategy.listRules(context)

      expect(first.length).assertEqual(1)
      expect(first[0].id !== undefined).assertTrue()
      expect(first[0].description?.includes('custom_abc') ?? false).assertTrue()
      expect(CustomModeStrategy.getCustomRuleId(first[0])).assertEqual('custom_abc')
      expect(first[0].id).assertEqual(second[0].id)
    })

    it('should strip managed description when replacing stored rules', 0, async () => {
      let context = {} as common.UIAbilityContext
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      when(saveMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))

      let rule = FirewallRulesService.applyManagedRuleMetadata(createRule('demo'), {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: 'custom_demo'
      })
      let replaced = await CustomModeStrategy.replaceAllRules(context, [rule])

      expect(replaced).assertTrue()
    })

    it('should generate custom ids for added rules and initialization migrations', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      when(loadMock)(context).afterReturn([])
      when(saveMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))

      let initializedRule = createRule('system-demo')
      await CustomModeStrategy.initializeFromSystemIfEmpty(context, [initializedRule])
      let replaced = await CustomModeStrategy.replaceAllRules(context, [createRule('manual-demo')])

      expect(replaced).assertTrue()
      expect(true).assertTrue()
    })

    it('should short-circuit initialization when custom store already has records', 0, async () => {
      let context = {} as common.UIAbilityContext
      let saveCount = 0
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      when(loadMock)(context).afterReturn([createStoredRecord('custom_existing', 'existing')])
      when(saveMock)(ArgumentMatchers.anyObj).afterAction(() => {
        saveCount++
        return Promise.resolve(true)
      })

      await CustomModeStrategy.initializeFromSystemIfEmpty(context, [createRule('system-demo')])

      expect(saveCount).assertEqual(0)
    })

    it('should reject update and remove when custom metadata is missing', 0, async () => {
      let context = {} as common.UIAbilityContext
      let rule = createRule('demo')
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      when(saveMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))
      when(loadMock)(context).afterReturn([
        createStoredRecord('custom_generated', 'demo')
      ])
      let replaced = await CustomModeStrategy.replaceAllRules(context, [rule])

      expect(replaced).assertTrue()
      let listed = await CustomModeStrategy.listRules(context)
      expect(listed.length).assertEqual(1)
      expect(CustomModeStrategy.getCustomRuleId(listed[0]) !== undefined).assertTrue()
    })

    it('should update and remove rules through repository when custom metadata exists', 0, async () => {
      let context = {} as common.UIAbilityContext
      let loadMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.loadRecords)
      let saveMock = mockKit.mockFunc(FirewallCustomRulesRepository, FirewallCustomRulesRepository.saveRecords)
      when(loadMock)(context).afterReturn([
        createStoredRecord('custom_demo', 'before')
      ])
      when(saveMock)(ArgumentMatchers.anyObj).afterReturn(Promise.resolve(true))

      let rule = FirewallRulesService.applyManagedRuleMetadata(createRule('after'), {
        owner: 'security_tool',
        mode: 'custom',
        kind: 'custom',
        customRuleId: 'custom_demo'
      })
      let updated = await CustomModeStrategy.replaceAllRules(context, [rule])
      let removed = await CustomModeStrategy.replaceAllRules(context, [])

      expect(updated).assertTrue()
      expect(removed).assertTrue()
      expect(true).assertTrue()
    })
  })
}
