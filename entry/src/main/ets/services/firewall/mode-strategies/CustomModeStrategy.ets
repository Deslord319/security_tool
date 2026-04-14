import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  attachFirewallRuleUserIds,
  FirewallScopedRule,
  getFirewallRuleUserIds,
  normalizeFirewallRuleUserIds,
  UserScopedFirewallRuleBucket
} from '../../../models/DataModels'
import { FirewallRepository } from '../repositories/FirewallRepository'
import {
  FirewallCustomRulesRepository,
  StoredCustomFirewallRuleRecord
} from '../repositories/FirewallCustomRulesRepository'
import { FirewallRulesService } from '../rules/FirewallRulesService'
import { generateRandomSuffix } from '../../../utils/ValuePicker'

export class CustomModeStrategy {
  static async listRules(context: common.UIAbilityContext): Promise<FirewallScopedRule[]> {
    let records = await CustomModeStrategy.loadRecords(context)
    return records.map((record: StoredCustomFirewallRuleRecord): FirewallScopedRule => {
      return CustomModeStrategy.toDisplayRule(record)
    })
  }

  static async buildRulesForApply(context: common.UIAbilityContext): Promise<FirewallScopedRule[]> {
    return CustomModeStrategy.listRules(context)
  }

  static buildRuleBucketsByUser(rules: netFirewall.NetFirewallRule[]): UserScopedFirewallRuleBucket[] {
    let bucketMap = new Map<number, netFirewall.NetFirewallRule[]>()
    rules.forEach((rule: netFirewall.NetFirewallRule) => {
      let userIds = getFirewallRuleUserIds(rule)
      userIds.forEach((userId: number) => {
        let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
        clonedRule.userId = userId
        let bucketRules = bucketMap.get(userId) ?? []
        bucketRules.push(clonedRule)
        bucketMap.set(userId, bucketRules)
      })
    })

    let buckets: UserScopedFirewallRuleBucket[] = []
    Array.from(bucketMap.keys()).sort((left: number, right: number) => left - right).forEach((userId: number) => {
      buckets.push({
        userId: userId,
        rules: bucketMap.get(userId) ?? []
      })
    })
    return buckets
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
        CustomModeStrategy.toStoredRule(rule),
        normalizeFirewallRuleUserIds([rule.userId ?? 100])
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
      let userIds = getFirewallRuleUserIds(rule)
      if (userIds.length === 0) {
        return
      }
      records.push(CustomModeStrategy.createRecord(
        CustomModeStrategy.getCustomRuleId(rule) ?? CustomModeStrategy.generateCustomRuleId(),
        CustomModeStrategy.toStoredRule(rule),
        userIds
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

  private static toDisplayRule(record: StoredCustomFirewallRuleRecord): FirewallScopedRule {
    let rule = FirewallRepository.cloneRuleForCreate(record.rule)
    let displayRule = FirewallRulesService.applyManagedRuleMetadata(rule, {
      owner: 'security_tool',
      mode: 'custom',
      kind: 'custom',
      customRuleId: record.customRuleId
    })
    let scopedDisplayRule = attachFirewallRuleUserIds(displayRule, record.userIds)
    scopedDisplayRule.id = CustomModeStrategy.hashRuleId(record.customRuleId)
    return scopedDisplayRule
  }

  private static toStoredRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule = FirewallRepository.cloneRuleForCreate(rule)
    clonedRule.description = undefined
    return clonedRule
  }

  private static generateCustomRuleId(): string {
    return `custom_${Date.now()}_${generateRandomSuffix()}`
  }

  private static createRecord(
    customRuleId: string,
    rule: netFirewall.NetFirewallRule,
    userIds: number[]
  ): StoredCustomFirewallRuleRecord {
    return {
      customRuleId: customRuleId,
      rule: rule,
      userIds: normalizeFirewallRuleUserIds(userIds)
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
