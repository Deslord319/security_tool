import { common } from '@kit.AbilityKit'
import { SafeRunner } from '../../utils/SafeRunner'
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
  PREF_KEY_FIREWALL_DESIRED_ENABLED,
  PREF_KEY_FIREWALL_LAST_APPLIED_MODE,
  PREF_KEY_FIREWALL_LAST_APPLIED_USER_IDS_SIGNATURE,
  PREF_KEY_FIREWALL_RULE_MAPPING,
  PREF_KEY_FIREWALL_USER_POLICY,
  PREF_STORE_NAME_FIREWALL_MODE,
  PREF_STORE_NAME_FIREWALL_RULE_MAPPING,
  PREF_STORE_NAME_FIREWALL_USER_POLICY
} from './FirewallModels'

const TAG = 'FirewallLocalRepository'

export class FirewallLocalRepository {
  static async loadRuleIntentMappingData(context: common.Context): Promise<FirewallRuleIntentMappingData> {
    return SafeRunner.runAsync(
      TAG,
      'loadRuleIntentMappingData',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
        let data = await pref.getJsonObject<FirewallRuleIntentMappingData>(
          PREF_KEY_FIREWALL_RULE_MAPPING,
          FirewallLocalRepository.emptyRuleIntentMappingData()
        )
        return FirewallLocalRepository.normalizeRuleIntentMappingData(data)
      },
      () => FirewallLocalRepository.emptyRuleIntentMappingData()
    )
  }

  static async saveRuleIntentMappingData(
    context: common.Context,
    data: FirewallRuleIntentMappingData
  ): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'saveRuleIntentMappingData',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_RULE_MAPPING)
        return await pref.setJson(PREF_KEY_FIREWALL_RULE_MAPPING, FirewallLocalRepository.normalizeRuleIntentMappingData(data))
      },
      () => false
    )
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
    return SafeRunner.runAsync(
      TAG,
      'getCurrentMode',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        let storedModeValue = await pref.getString(PREF_KEY_FIREWALL_ACTIVE_MODE, '')
        if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
          return storedModeValue
        }
        return 'custom'
      },
      () => 'custom' as FirewallPresetMode
    )
  }

  static async saveCurrentMode(context: common.Context, mode: FirewallPresetMode): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'saveCurrentMode',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        return await pref.setValue(PREF_KEY_FIREWALL_ACTIVE_MODE, mode)
      },
      () => false
    )
  }

  static async getDesiredEnabled(context: common.Context): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'getDesiredEnabled',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        let storedValue = await pref.getString(PREF_KEY_FIREWALL_DESIRED_ENABLED, '')
        if (storedValue === 'true') {
          return true
        }
        if (storedValue === 'false') {
          return false
        }
        return true
      },
      () => true
    )
  }

  static async saveDesiredEnabled(context: common.Context, enabled: boolean): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'saveDesiredEnabled',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        return await pref.setValue(PREF_KEY_FIREWALL_DESIRED_ENABLED, String(enabled))
      },
      () => false
    )
  }

  static async getLastAppliedMode(context: common.Context): Promise<FirewallPresetMode | undefined> {
    return SafeRunner.runAsync(
      TAG,
      'getLastAppliedMode',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        let storedModeValue = await pref.getString(PREF_KEY_FIREWALL_LAST_APPLIED_MODE, '')
        if (storedModeValue === 'public' || storedModeValue === 'private' || storedModeValue === 'custom') {
          return storedModeValue
        }
        return undefined
      },
      () => undefined as FirewallPresetMode | undefined
    )
  }

  static async getLastAppliedUserIdsSignature(context: common.Context): Promise<string> {
    return SafeRunner.runAsync(
      TAG,
      'getLastAppliedUserIdsSignature',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        return await pref.getString(PREF_KEY_FIREWALL_LAST_APPLIED_USER_IDS_SIGNATURE, '')
      },
      () => ''
    )
  }

  static async saveModeApplyState(
    context: common.Context,
    mode: FirewallPresetMode,
    userIdsSignature: string
  ): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'saveModeApplyState',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_MODE)
        let modeSaved = await pref.setValue(PREF_KEY_FIREWALL_LAST_APPLIED_MODE, mode)
        let signatureSaved = await pref.setValue(PREF_KEY_FIREWALL_LAST_APPLIED_USER_IDS_SIGNATURE, userIdsSignature)
        return modeSaved && signatureSaved
      },
      () => false
    )
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
    return SafeRunner.runAsync(
      TAG,
      'saveUserPolicyMode',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_POLICY)
        return await pref.setJson(PREF_KEY_FIREWALL_USER_POLICY, nextRecords)
      },
      () => false
    )
  }

  static async removeUserPolicyMode(
    context: common.Context,
    userId: number
  ): Promise<boolean> {
    let records = await FirewallLocalRepository.listUserPolicyModes(context)
    let nextRecords = records.filter((item: FirewallUserPolicyModeRecord): boolean => item.userId !== userId)
    return FirewallLocalRepository.saveUserPolicyModes(context, nextRecords)
  }

  static async pruneUnavailableUsers(context: common.Context, validUserIds: number[]): Promise<boolean> {
    let validUserSet = FirewallLocalRepository.buildValidUserSet(validUserIds)
    if (validUserSet.size === 0) {
      return true
    }

    let data = await FirewallLocalRepository.loadRuleIntentMappingData(context)
    let nextRuleIntents: FirewallRuleIntent[] = []
    let validLocalRuleIds = new Set<string>()
    data.ruleIntents.forEach((intent: FirewallRuleIntent) => {
      let targetUserIds = intent.targetUserIds.filter((userId: number): boolean => validUserSet.has(userId))
      if (targetUserIds.length === 0) {
        return
      }
      intent.targetUserIds = targetUserIds
      nextRuleIntents.push(intent)
      validLocalRuleIds.add(intent.localRuleId)
    })

    let nextRuleDeployments = data.ruleDeployments.filter((deployment: FirewallRuleDeployment): boolean =>
      validUserSet.has(deployment.userId) && validLocalRuleIds.has(deployment.localRuleId)
    )
    let mappingSaved = await FirewallLocalRepository.saveRuleIntentMappingData(context, {
      version: data.version,
      ruleIntents: nextRuleIntents,
      ruleDeployments: nextRuleDeployments
    } as FirewallRuleIntentMappingData)

    let policyModes = await FirewallLocalRepository.listUserPolicyModes(context)
    let nextPolicyModes = policyModes.filter((item: FirewallUserPolicyModeRecord): boolean =>
      validUserSet.has(item.userId)
    )
    let policyModesSaved = await FirewallLocalRepository.saveUserPolicyModes(context, nextPolicyModes)
    return mappingSaved && policyModesSaved
  }

  static async listUserPolicyModes(context: common.Context): Promise<FirewallUserPolicyModeRecord[]> {
    return SafeRunner.runAsync(
      TAG,
      'listUserPolicyModes',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_POLICY)
        let records = await pref.getJsonArray<FirewallUserPolicyModeRecord>(PREF_KEY_FIREWALL_USER_POLICY, [])
        return records.filter((item: FirewallUserPolicyModeRecord): boolean =>
          typeof item.userId === 'number' && (item.mode === 'allowlist' || item.mode === 'denylist')
        )
      },
      () => [] as FirewallUserPolicyModeRecord[]
    )
  }

  private static async saveUserPolicyModes(
    context: common.Context,
    records: FirewallUserPolicyModeRecord[]
  ): Promise<boolean> {
    return SafeRunner.runAsync(
      TAG,
      'saveUserPolicyModes',
      async () => {
        let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_FIREWALL_USER_POLICY)
        return await pref.setJson(PREF_KEY_FIREWALL_USER_POLICY, records)
      },
      () => false
    )
  }

  private static buildValidUserSet(userIds: number[]): Set<number> {
    let validUserSet = new Set<number>()
    userIds.forEach((userId: number) => {
      if (Number.isFinite(userId) && userId >= 0) {
        validUserSet.add(userId)
      }
    })
    return validUserSet
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
