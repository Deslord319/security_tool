import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'

import {
  normalizeFirewallRuleUserIds,
  PREF_KEY_FIREWALL_CUSTOM_RULES,
  PREF_STORE_NAME_FIREWALL_CUSTOM_RULES
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'FirewallCustomRulesRepository'

export interface StoredCustomFirewallRuleRecord {
  customRuleId: string
  rule: netFirewall.NetFirewallRule
  userIds: number[]
}

export class FirewallCustomRulesRepository {
  static async loadRecords(context: common.UIAbilityContext): Promise<StoredCustomFirewallRuleRecord[]> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      let parsed = await pref.getJsonArray<StoredCustomFirewallRuleRecord>(PREF_KEY_FIREWALL_CUSTOM_RULES, [])
      let records: StoredCustomFirewallRuleRecord[] = []
      parsed.forEach((item: StoredCustomFirewallRuleRecord) => {
        if (typeof item.customRuleId === 'string' && item.customRuleId.length > 0 && !!item.rule) {
          let userIds = normalizeFirewallRuleUserIds(Array.isArray(item.userIds) ? item.userIds : [])
          if (userIds.length === 0) {
            return
          }
          records.push({
            customRuleId: item.customRuleId,
            rule: item.rule,
            userIds: userIds
          })
        }
      })
      return records
    } catch (err) {
      LogUtils.error(TAG, `loadRecords failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  static async saveRecords(
    context: common.UIAbilityContext,
    records: StoredCustomFirewallRuleRecord[]
  ): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_CUSTOM_RULES)
      let normalizedRecords = records.map((item: StoredCustomFirewallRuleRecord): StoredCustomFirewallRuleRecord => {
        return {
          customRuleId: item.customRuleId,
          rule: item.rule,
          userIds: normalizeFirewallRuleUserIds(item.userIds)
        }
      }).filter((item: StoredCustomFirewallRuleRecord): boolean => item.userIds.length > 0)
      return await pref.setJson(PREF_KEY_FIREWALL_CUSTOM_RULES, normalizedRecords)
    } catch (err) {
      LogUtils.error(TAG, `saveRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }
}
