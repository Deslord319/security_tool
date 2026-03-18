import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  PREF_KEY_FIREWALL_CUSTOM_RULES,
  PREF_STORE_NAME_FIREWALL_CUSTOM_RULES
} from '../models/DataModels'
import { FirewallService } from './FirewallService'

const TAG = 'FirewallCustomRuleService'
const DOMAIN = 0x0012

interface StoredCustomFirewallRuleRecord {
  customRuleId: string
  rule: netFirewall.NetFirewallRule
}

export class FirewallCustomRuleService {
  static async listRules(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    let records = await FirewallCustomRuleService.loadRecords(context)
    return records.map((record: StoredCustomFirewallRuleRecord) => FirewallCustomRuleService.toDisplayRule(record))
  }

  static async buildRulesForApply(context: common.UIAbilityContext): Promise<netFirewall.NetFirewallRule[]> {
    return FirewallCustomRuleService.listRules(context)
  }

  static async addRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let records = await FirewallCustomRuleService.loadRecords(context)
    records.push({
      customRuleId: FirewallCustomRuleService.generateCustomRuleId(),
      rule: FirewallCustomRuleService.toStoredRule(rule)
    })
    return FirewallCustomRuleService.saveRecords(context, records)
  }

  static async updateRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let customRuleId = FirewallCustomRuleService.getCustomRuleId(rule)
    if (!customRuleId) {
      return false
    }
    let records = await FirewallCustomRuleService.loadRecords(context)
    let index = records.findIndex((item: StoredCustomFirewallRuleRecord) => item.customRuleId === customRuleId)
    if (index < 0) {
      return false
    }
    records[index] = {
      customRuleId: customRuleId,
      rule: FirewallCustomRuleService.toStoredRule(rule)
    }
    return FirewallCustomRuleService.saveRecords(context, records)
  }

  static async removeRule(context: common.UIAbilityContext, rule: netFirewall.NetFirewallRule): Promise<boolean> {
    let customRuleId = FirewallCustomRuleService.getCustomRuleId(rule)
    if (!customRuleId) {
      return false
    }
    let records = await FirewallCustomRuleService.loadRecords(context)
    let nextRecords = records.filter((item: StoredCustomFirewallRuleRecord) => item.customRuleId !== customRuleId)
    return FirewallCustomRuleService.saveRecords(context, nextRecords)
  }

  static async initializeFromSystemIfEmpty(
    context: common.UIAbilityContext,
    systemRules: netFirewall.NetFirewallRule[]
  ): Promise<void> {
    let records = await FirewallCustomRuleService.loadRecords(context)
    if (records.length > 0 || systemRules.length === 0) {
      return
    }
    let migratedRecords: StoredCustomFirewallRuleRecord[] = []
    systemRules.forEach((rule: netFirewall.NetFirewallRule) => {
      migratedRecords.push(FirewallCustomRuleService.createRecord(
        FirewallCustomRuleService.generateCustomRuleId(),
        FirewallCustomRuleService.toStoredRule(rule)
      ))
    })
    await FirewallCustomRuleService.saveRecords(context, migratedRecords)
  }

  static async replaceAllRules(
    context: common.UIAbilityContext,
    rules: netFirewall.NetFirewallRule[]
  ): Promise<boolean> {
    let records: StoredCustomFirewallRuleRecord[] = []
    rules.forEach((rule: netFirewall.NetFirewallRule) => {
      records.push(FirewallCustomRuleService.createRecord(
        FirewallCustomRuleService.getCustomRuleId(rule) ?? FirewallCustomRuleService.generateCustomRuleId(),
        FirewallCustomRuleService.toStoredRule(rule)
      ))
    })
    return FirewallCustomRuleService.saveRecords(context, records)
  }

  static getCustomRuleId(rule: netFirewall.NetFirewallRule): string | undefined {
    let metadata = FirewallService.parseManagedRuleDescription(rule.description)
    return metadata?.kind === 'custom' ? metadata.customRuleId : undefined
  }

  private static async loadRecords(context: common.UIAbilityContext): Promise<StoredCustomFirewallRuleRecord[]> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      let rawValue = await store.get(PREF_KEY_FIREWALL_CUSTOM_RULES, '[]')
      let serialized = typeof rawValue === 'string' ? rawValue : '[]'
      let parsed = JSON.parse(serialized) as StoredCustomFirewallRuleRecord[]
      if (!Array.isArray(parsed)) {
        return []
      }
      let records: StoredCustomFirewallRuleRecord[] = []
      parsed.forEach((item: StoredCustomFirewallRuleRecord) => {
        if (typeof item.customRuleId === 'string' && !!item.rule) {
          records.push(FirewallCustomRuleService.createRecord(
            item.customRuleId,
            FirewallCustomRuleService.toStoredRule(item.rule)
          ))
        }
      })
      return records
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static async saveRecords(
    context: common.UIAbilityContext,
    records: StoredCustomFirewallRuleRecord[]
  ): Promise<boolean> {
    try {
      let store = await preferences.getPreferences(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      await store.put(PREF_KEY_FIREWALL_CUSTOM_RULES, JSON.stringify(records))
      await store.flush()
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static toDisplayRule(record: StoredCustomFirewallRuleRecord): netFirewall.NetFirewallRule {
    let rule = FirewallService.applyManagedRuleMetadata(record.rule, {
      owner: 'security_tool',
      mode: 'custom',
      kind: 'custom',
      customRuleId: record.customRuleId
    })
    rule.id = FirewallCustomRuleService.hashRuleId(record.customRuleId)
    return rule
  }

  private static toStoredRule(rule: netFirewall.NetFirewallRule): netFirewall.NetFirewallRule {
    let clonedRule = FirewallService.cloneRuleForCreate(rule)
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
