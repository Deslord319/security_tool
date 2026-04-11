import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import { FirewallRepository } from '../repositories/FirewallRepository'
import {
  FirewallCustomRulesRepository,
  StoredCustomFirewallRuleRecord
} from '../repositories/FirewallCustomRulesRepository'
import { FirewallRulesService } from '../rules/FirewallRulesService'

export class CustomModeStrategy {
  static async listRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    let records = await CustomModeStrategy.loadRecords(context)
    return records.map((record: StoredCustomFirewallRuleRecord): netFirewall.NetFirewallRule => {
      return CustomModeStrategy.toDisplayRule(record)
    })
  }

  static async buildRulesForApply(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return CustomModeStrategy.listRules(context)
  }

  static async initializeFromSystemIfEmpty(
    context: common.UIAbilityContext,
    systemRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    let records = await CustomModeStrategy.loadRecords(context)
    if (records.length > 0 || systemRules.length === 0) {
      return
    }
    let migratedRecords: StoredCustomFirewallRuleRecord[] = []
    systemRules.forEach((rule: netFirewall.NetFirewallRule) => {
      migratedRecords.push(CustomModeStrategy.createRecord(
        CustomModeStrategy.generateCustomRuleId(),
        CustomModeStrategy.toStoredRule(rule)
      ))
    })
    await CustomModeStrategy.saveRecords(context, migratedRecords)
  }

  static async replaceAllRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    let records: StoredCustomFirewallRuleRecord[] = []
    rules.forEach((rule: netFirewall.NetFirewallRule) => {
      records.push(CustomModeStrategy.createRecord(
        CustomModeStrategy.getCustomRuleId(rule) ?? CustomModeStrategy.generateCustomRuleId(),
        CustomModeStrategy.toStoredRule(rule)
      ))
    })
    return CustomModeStrategy.saveRecords(context, records)
  }

  static getCustomRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    let metadata = FirewallRulesService.parseManagedRuleDescription(rule.description)
    return metadata?.kind === 'custom' ? metadata.customRuleId : undefined
  }

  private static async loadRecords(context: common.UIAbilityContext): Promise<StoredCustomFirewallRuleRecord[]> {
    return FirewallCustomRulesRepository.loadRecords(context)
  }

  private static async saveRecords(
    context: common.UIAbilityContext,
    records: StoredCustomFirewallRuleRecord[]
  ): Promise<boolean> {
    return FirewallCustomRulesRepository.saveRecords(context, records)
  }

  private static toDisplayRule(record: StoredCustomFirewallRuleRecord): netFirewall.NetFirewallRule {
    let rule = FirewallRepository.cloneRuleForCreate(record.rule)
    let displayRule = FirewallRulesService.applyManagedRuleMetadata(rule, {
      owner: 'security_tool',
      mode: 'custom',
      kind: 'custom',
      customRuleId: record.customRuleId
    })
    displayRule.id = CustomModeStrategy.hashRuleId(record.customRuleId)
    return displayRule
  }

  private static toStoredRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
    clonedRule.description = undefined
    return clonedRule
  }

  private static generateCustomRuleId(): string {
    return `custom_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
  }

  private static createRecord(
    customRuleId: string,
    rule: netFirewall.NetFirewallRule
  ): StoredCustomFirewallRuleRecord {
    return {
      customRuleId: customRuleId,
      rule: rule
    }
  }

  private static hashRuleId(customRuleId: string): number {
    let hash = 0
    for (let i = 0; i < customRuleId.length; i++) {
      hash = (hash * 31 + customRuleId.charCodeAt(i)) % 2147483647
    }
    return hash === 0 ? 1 : hash
  }
}
