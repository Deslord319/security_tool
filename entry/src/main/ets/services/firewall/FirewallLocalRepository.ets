import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'
import { PreferencesAccessor } from '../../storage/preferences/PreferencesAccessor'
import {
  FIREWALL_RULE_MAPPING_VERSION,
  FirewallPresetMode,
  FirewallRuleDeployment,
  FirewallRuleIntent,
  FirewallRuleIntentMappingData,
  FirewallUserPolicyMode,
  FirewallUserPolicyModeRecord,
  PREF_KEY_FIREWALL_ACTIVE_MODE,
  PREF_KEY_FIREWALL_RULE_MAPPING,
  PREF_KEY_FIREWALL_USER_POLICY,
  PREF_STORE_NAME_FIREWALL_MODE,
  PREF_STORE_NAME_FIREWALL_RULE_MAPPING,
  PREF_STORE_NAME_FIREWALL_USER_POLICY
} from './FirewallModels'

const TAG = 'FirewallLocalRepository'

export class FirewallLocalRepository {
  static async loadRuleIntentMappingData(context: common.Context): Promise<FirewallRuleIntentMappingData> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
      let data = await pref.getJsonObject<FirewallRuleIntentMappingData>(
        PREF_KEY_FIREWALL_RULE_MAPPING,
        FirewallLocalRepository.emptyRuleIntentMappingData()
      )
      return FirewallLocalRepository.normalizeRuleIntentMappingData(data)
    } catch (err) {
      LogUtils.error(TAG, `loadRuleIntentMappingData failed: ${JSON.stringify(err)}`)
      return FirewallLocalRepository.emptyRuleIntentMappingData()
    }
  }

  static async saveRuleIntentMappingData(
    context: common.Context,
    data: FirewallRuleIntentMappingData
  ): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
      return await pref.setJson(PREF_KEY_FIREWALL_RULE_MAPPING, FirewallLocalRepository.normalizeRuleIntentMappingData(data))
    } catch (err) {
      LogUtils.error(TAG, `saveRuleIntentMappingData failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async listRuleIntents(context: common.Context): Promise<FirewallRuleIntent[]> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    return data.ruleIntents
  }

  static async getRuleIntent(context: common.Context, localRuleId: string): Promise<FirewallRuleIntent | null> {
    let intents = await FirewallLocalRepository.listRuleIntents(context)
    return intents.find((item: FirewallRuleIntent): boolean => item.localRuleId === localRuleId) ?? null
  }

  static async saveRuleIntent(context: common.Context, intent: FirewallRuleIntent): Promise<boolean> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    data.ruleIntents = data.ruleIntents.filter((item: FirewallRuleIntent): boolean => item.localRuleId !== intent.localRuleId)
    data.ruleIntents.push(intent)
    return FirewallLocalRepository.saveRuleIntentMappingData(context, data)
  }

  static async removeRuleIntent(context: common.Context, localRuleId: string): Promise<boolean> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    data.ruleIntents = data.ruleIntents.filter((item: FirewallRuleIntent): boolean => item.localRuleId !== localRuleId)
    return FirewallLocalRepository.saveRuleIntentMappingData(context, data)
  }

  static async listRuleDeployments(context: common.Context, localRuleId?: string): Promise<FirewallRuleDeployment[]> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    if (localRuleId === undefined) {
      return data.ruleDeployments
    }
    return data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId === localRuleId)
  }

  static async replaceRuleDeployments(
    context: common.Context,
    localRuleId: string,
    deployments: FirewallRuleDeployment[]
  ): Promise<boolean> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    data.ruleDeployments = data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId !== localRuleId)
    data.ruleDeployments.push(...deployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId === localRuleId))
    return FirewallLocalRepository.saveRuleIntentMappingData(context, data)
  }

  static async removeRuleDeployments(context: common.Context, localRuleId: string): Promise<boolean> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    data.ruleDeployments = data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean => item.localRuleId !== localRuleId)
    return FirewallLocalRepository.saveRuleIntentMappingData(context, data)
  }

  static async clearAllRuleDeployments(context: common.Context): Promise<boolean> {
    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    data.ruleDeployments = []
    return FirewallLocalRepository.saveRuleIntentMappingData(context, data)
  }

  static async getCurrentMode(context: common.Context): Promise<FirewallPresetMode> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
      let storedModeValue = await pref.getString(PREF_KEY_FIREWALL_ACTIVE_MODE, '')
      if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
        return storedModeValue
      }
    } catch (err) {
      LogUtils.error(TAG, `getCurrentMode failed: ${JSON.stringify(err)}`)
    }
    return 'custom'
  }

  static async saveCurrentMode(context: common.Context, mode: FirewallPresetMode): Promise<boolean> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
      return await pref.setValue(PREF_KEY_FIREWALL_ACTIVE_MODE, mode)
    } catch (err) {
      LogUtils.error(TAG, `saveCurrentMode failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async getUserPolicyMode(
    context: common.Context,
    userId: number
  ): Promise<FirewallUserPolicyMode | undefined> {
    let records = await FirewallLocalRepository.listUserPolicyModes(context)
    return records.find((item: FirewallUserPolicyModeRecord): boolean => item.userId === userId)?.mode
  }

  static async saveUserPolicyMode(
    context: common.Context,
    userId: number,
    mode: FirewallUserPolicyMode
  ): Promise<boolean> {
    let records = await FirewallLocalRepository.listUserPolicyModes(context)
    let nextRecords = records.filter((item: FirewallUserPolicyModeRecord): boolean => item.userId !== userId)
    nextRecords.push({ userId: userId, mode: mode })
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_POLICY)
      return await pref.setJson(PREF_KEY_FIREWALL_USER_POLICY, nextRecords)
    } catch (err) {
      LogUtils.error(TAG, `saveUserPolicyMode failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async listUserPolicyModes(context: common.Context): Promise<FirewallUserPolicyModeRecord[]> {
    try {
      let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_POLICY)
      let records = await pref.getJsonArray<FirewallUserPolicyModeRecord>(PREF_KEY_FIREWALL_USER_POLICY, [])
      return records.filter((item: FirewallUserPolicyModeRecord): boolean =>
        typeof item.userId === 'number' && (item.mode === 'allowlist' || item.mode === 'denylist')
      )
    } catch (err) {
      LogUtils.error(TAG, `listUserPolicyModes failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static emptyRuleIntentMappingData(): FirewallRuleIntentMappingData {
    return {
      version: FIREWALL_RULE_MAPPING_VERSION,
      ruleIntents: [],
      ruleDeployments: []
    }
  }

  private static normalizeRuleIntentMappingData(data: FirewallRuleIntentMappingData): FirewallRuleIntentMappingData {
    return {
      version: FIREWALL_RULE_MAPPING_VERSION,
      ruleIntents: Array.isArray(data.ruleIntents) ? data.ruleIntents.filter((item: FirewallRuleIntent): boolean =>
        typeof item.localRuleId === 'string' && item.localRuleId.length > 0 && Array.isArray(item.targetUserIds)
      ) : [],
      ruleDeployments: Array.isArray(data.ruleDeployments) ? data.ruleDeployments.filter((item: FirewallRuleDeployment): boolean =>
        typeof item.localRuleId === 'string' &&
          item.localRuleId.length > 0 &&
          typeof item.userId === 'number' &&
          typeof item.systemRuleId === 'number'
      ) : []
    }
  }
}
