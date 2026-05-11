import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  LOG_MAX_ENTRIES_OPTIONS,
  LogStorageConfig,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_STORE_NAME_LOG
} from '../../../models/DataModels'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { ServiceResult } from '../common/LogManagePorts'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'LogSettingsRepository'

export class LogSettingsRepository {
  private static context: common.UIAbilityContext | null = null

  static async init(context: common.UIAbilityContext): Promise<ServiceResult> {
    LogSettingsRepository.context = context
    let config = await LogSettingsRepository.readStorageConfig()
    return config ? { success: true, code: 'ok' } : { success: false, code: 'config_init_failed' }
  }

  static async loadStorageConfig(): Promise<LogStorageConfig> {
    let config = await LogSettingsRepository.readStorageConfig()
    return config ?? {
      maxLocalEntries: DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
      retentionDays: DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }
  }

  static async saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    if (!LogSettingsRepository.context) {
      return { success: false, code: 'not_initialized' }
    }
    try {
      let normalizedConfig: LogStorageConfig = {
        maxLocalEntries: LogSettingsRepository.normalizeMaxEntriesOption(config.maxLocalEntries),
        retentionDays: LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
      }
      let pref = PreferencesAccessor.of(LogSettingsRepository.context, PREF_STORE_NAME_LOG)
      let saved = await pref.setMany([
        { key: PREF_KEY_LOG_MAX_ENTRIES, value: normalizedConfig.maxLocalEntries },
        { key: PREF_KEY_LOG_RETENTION_DAYS, value: normalizedConfig.retentionDays }
      ])
      if (!saved) {
        return { success: false, code: 'save_failed' }
      }
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `saveStorageConfig failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  private static async readStorageConfig(): Promise<LogStorageConfig | null> {
    if (!LogSettingsRepository.context) {
      return null
    }
    try {
      let pref = PreferencesAccessor.of(LogSettingsRepository.context, PREF_STORE_NAME_LOG)
      let maxEntries = await pref.getNumber(PREF_KEY_LOG_MAX_ENTRIES, DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries)
      let retentionDays = await pref.getNumber(PREF_KEY_LOG_RETENTION_DAYS, DEFAULT_LOG_STORAGE_CONFIG.retentionDays)
      return {
        maxLocalEntries: LogSettingsRepository.normalizeMaxEntriesOption(maxEntries),
        retentionDays: LogEntryNormalizer.normalizeRetentionDays(retentionDays)
      }
    } catch (err) {
      LogUtils.error(TAG, `readStorageConfig failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  private static normalizeMaxEntriesOption(maxEntries: number): number {
    let normalized = LogEntryNormalizer.normalizeMaxEntries(maxEntries)
    return LOG_MAX_ENTRIES_OPTIONS.includes(normalized)
      ? normalized
      : DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
  }
}
