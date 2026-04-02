import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG,
  DEFAULT_SUBSCRIPTION_CONFIG,
  LogStorageConfig,
  LogSubscriptionConfig,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_KEY_LOG_SUBSCRIBE_ALL,
  PREF_KEY_LOG_SUBSCRIBED_TYPES,
  PREF_STORE_NAME_LOG
} from '../../../models/DataModels'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { ServiceResult } from '../common/LogManagePorts'

const TAG = 'LogConfigRepository'

export class LogConfigRepository {
  private static context: common.UIAbilityContext | null = null
  private static storageConfig: LogStorageConfig = DEFAULT_LOG_STORAGE_CONFIG

  static async init(context: common.UIAbilityContext): Promise<ServiceResult> {
    LogConfigRepository.context = context
    let success = await LogConfigRepository.loadConfigInternal()
    return success ? { success: true, code: 'ok' } : { success: false, code: 'config_init_failed' }
  }

  static async loadStorageConfig(): Promise<LogStorageConfig> {
    await LogConfigRepository.loadConfigInternal()
    return {
      maxLocalEntries: LogConfigRepository.storageConfig.maxLocalEntries,
      retentionDays: LogConfigRepository.storageConfig.retentionDays
    }
  }

  static getStorageConfigSync(): LogStorageConfig {
    return {
      maxLocalEntries: LogConfigRepository.storageConfig.maxLocalEntries,
      retentionDays: LogConfigRepository.storageConfig.retentionDays
    }
  }

  static async saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    if (!LogConfigRepository.context) {
      return { success: false, code: 'not_initialized' }
    }
    try {
      LogConfigRepository.storageConfig = {
        maxLocalEntries: LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries),
        retentionDays: LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
      }
      let store = await preferences.getPreferences(LogConfigRepository.context, PREF_STORE_NAME_LOG)
      await store.put(PREF_KEY_LOG_MAX_ENTRIES, LogConfigRepository.storageConfig.maxLocalEntries)
      await store.put(PREF_KEY_LOG_RETENTION_DAYS, LogConfigRepository.storageConfig.retentionDays)
      await store.flush()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `saveStorageConfig failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  static async loadSubscriptionConfig(): Promise<LogSubscriptionConfig> {
    if (!LogConfigRepository.context) {
      return {
        subscribeAll: DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll,
        subscribedTypes: [...DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes]
      }
    }
    try {
      let store = await preferences.getPreferences(LogConfigRepository.context, PREF_STORE_NAME_LOG)
      let subscribeAll = await store.get(PREF_KEY_LOG_SUBSCRIBE_ALL, DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll) as boolean
      let rawTypes = await store.get(
        PREF_KEY_LOG_SUBSCRIBED_TYPES,
        JSON.stringify(DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes)
      ) as string
      let parsedTypes: number[] = []
      try {
        parsedTypes = JSON.parse(rawTypes) as number[]
      } catch {
        LogUtils.warn(TAG, 'loadSubscriptionConfig: invalid subscribedTypes, fallback to default')
      }
      let subscribedTypes = subscribeAll ? [...ALL_LOG_EVENT_TYPES] : LogConfigRepository.sanitizeSubscribedTypes(parsedTypes)
      if (subscribedTypes.length === 0) {
        subscribedTypes = [...ALL_LOG_EVENT_TYPES]
      }
      return {
        subscribeAll,
        subscribedTypes
      }
    } catch (err) {
      LogUtils.error(TAG, `loadSubscriptionConfig failed: ${JSON.stringify(err)}`)
      return {
        subscribeAll: DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll,
        subscribedTypes: [...DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes]
      }
    }
  }

  private static async loadConfigInternal(): Promise<boolean> {
    if (!LogConfigRepository.context) {
      return false
    }
    try {
      let store = await preferences.getPreferences(LogConfigRepository.context, PREF_STORE_NAME_LOG)
      let maxEntries = await store.get(PREF_KEY_LOG_MAX_ENTRIES, DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries) as number
      let retentionDays = await store.get(PREF_KEY_LOG_RETENTION_DAYS, DEFAULT_LOG_STORAGE_CONFIG.retentionDays) as Object
      let retentionDaysNumber = typeof retentionDays === 'number' ? retentionDays : Number(retentionDays as string)
      LogConfigRepository.storageConfig = {
        maxLocalEntries: LogEntryNormalizer.normalizeMaxEntries(maxEntries),
        retentionDays: LogEntryNormalizer.normalizeRetentionDays(retentionDaysNumber)
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `loadConfigInternal failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static sanitizeSubscribedTypes(types: number[]): number[] {
    let result: number[] = []
    for (let value of types) {
      if (ALL_LOG_EVENT_TYPES.includes(value as number) && !result.includes(value)) {
        result.push(value)
      }
    }
    return result
  }

  static resetForTest(): void {
    LogConfigRepository.context = null
    LogConfigRepository.storageConfig = {
      maxLocalEntries: DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
      retentionDays: DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }
  }

  static setStorageConfigForTest(config: LogStorageConfig): void {
    LogConfigRepository.storageConfig = {
      maxLocalEntries: LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries),
      retentionDays: LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
    }
  }
}
