import { common } from '@kit.AbilityKit'
import { LogEntry } from '../../../models/DataModels'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { ClearLogsResult, InitializeResult, MutationResult } from '../common/LogManagePorts'

export class LogStorageMaintenanceService {
  static async initialize(context: common.UIAbilityContext): Promise<InitializeResult> {
    let configResult = await LogSettingsRepository.init(context)
    if (!configResult.success) {
      return { success: false, code: 'config_init_failed' }
    }
    let rdbReady = await LogEntryRepository.init(context)
    if (!rdbReady) {
      return { success: false, code: 'storage_init_failed' }
    }
    let reconcileResult = await LogStorageMaintenanceService.reconcileStorageConfig()
    if (!reconcileResult.success) {
      return { success: false, code: 'storage_init_failed' }
    }
    return { success: true, code: 'ok' }
  }

  static async appendEntries(entries: LogEntry[]): Promise<MutationResult> {
    if (entries.length === 0) {
      return { success: true, code: 'ok' }
    }
    if (!LogEntryRepository.isReady()) {
      return { success: false, code: 'not_initialized' }
    }
    let normalizedBatch = LogEntryNormalizer.normalizeEntriesForAppend(entries)
    if (normalizedBatch.length === 0) {
      return { success: true, code: 'ok' }
    }
    let saved = await LogEntryRepository.upsertEntries(normalizedBatch)
    if (!saved) {
      return { success: false, code: 'save_failed' }
    }
    return LogStorageMaintenanceService.reconcileStorageConfig()
  }

  static async reconcileStorageConfig(): Promise<MutationResult> {
    if (!LogEntryRepository.isReady()) {
      return { success: false, code: 'not_initialized' }
    }
    let config = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
    let maxEntries = LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries)
    let cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000
    let cleaned = await LogEntryRepository.deleteExpired(cutoff)
    if (!cleaned) {
      return { success: false, code: 'save_failed' }
    }
    let trimmed = await LogEntryRepository.trimToMaxEntries(maxEntries)
    if (!trimmed) {
      return { success: false, code: 'save_failed' }
    }
    LogEntryRepository.notifyChanged()
    return { success: true, code: 'ok' }
  }

  static async clearAll(): Promise<ClearLogsResult> {
    if (!LogEntryRepository.isReady()) {
      return { success: false, code: 'clear_failed' }
    }
    let cleared = await LogEntryRepository.clearAll()
    if (!cleared) {
      return { success: false, code: 'clear_failed' }
    }
    LogEntryRepository.notifyChanged()
    return { success: true, code: 'ok' }
  }
}
