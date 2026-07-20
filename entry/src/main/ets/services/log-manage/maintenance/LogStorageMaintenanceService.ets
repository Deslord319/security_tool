import { common } from '@kit.AbilityKit'
import { LogEntry } from '../../../models/LogModels'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogEntryRepository } from '../repository/LogEntryRepository'
import { ClearLogsResult, InitializeResult, MutationResult } from '../common/LogManagePorts'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LogStorageMaintenance'

export function buildLogStorageNaturalDayCutoff(now: number, retentionDays: number): number {
  let anchor = new Date(now)
  anchor.setHours(0, 0, 0, 0)
  anchor.setDate(anchor.getDate() - Math.max(0, retentionDays - 1))
  return anchor.getTime()
}

export class LogStorageMaintenanceService {
  static async initialize(context: common.UIAbilityContext): Promise<InitializeResult> {
    let configResult = await LogSettingsRepository.init(context)
    if (!configResult.success) {
      LogUtils.error(TAG, `initialize failed: stage=config, code=${configResult.code}`)
      return { success: false, code: 'config_init_failed' }
    }
    let rdbReady = await LogEntryRepository.init(context)
    if (!rdbReady) {
      LogUtils.error(TAG, 'initialize failed: stage=storage')
      return { success: false, code: 'storage_init_failed' }
    }
    let reconcileResult = await LogStorageMaintenanceService.reconcileStorageConfig()
    if (!reconcileResult.success) {
      LogUtils.error(TAG, `initialize failed: stage=reconcile, code=${reconcileResult.code}`)
      return { success: false, code: 'storage_init_failed' }
    }
    return { success: true, code: 'ok' }
  }

  static async appendEntries(entries: LogEntry[]): Promise<MutationResult> {
    if (entries.length === 0) {
      return { success: true, code: 'ok' }
    }
    if (!LogEntryRepository.isReady()) {
      LogUtils.warn(TAG, `appendEntries skipped: repository not initialized, count=${entries.length}`)
      return { success: false, code: 'not_initialized' }
    }
    let normalizedBatch = LogEntryNormalizer.normalizeEntriesForAppend(entries)
    if (normalizedBatch.length === 0) {
      return { success: true, code: 'ok' }
    }
    let saved = await LogEntryRepository.upsertEntries(normalizedBatch)
    if (!saved) {
      LogUtils.error(TAG, `appendEntries failed: count=${normalizedBatch.length}`)
      return { success: false, code: 'save_failed' }
    }
    return LogStorageMaintenanceService.reconcileAfterAppend(normalizedBatch)
  }

  static async reconcileStorageConfig(): Promise<MutationResult> {
    if (!LogEntryRepository.isReady()) {
      LogUtils.warn(TAG, 'reconcileStorageConfig skipped: repository not initialized')
      return { success: false, code: 'not_initialized' }
    }
    let config = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
    let maxEntries = LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries)
    let cutoff = buildLogStorageNaturalDayCutoff(Date.now(), retentionDays)
    return LogStorageMaintenanceService.applyStorageLimits(maxEntries, cutoff)
  }

  static async clearAll(): Promise<ClearLogsResult> {
    if (!LogEntryRepository.isReady()) {
      LogUtils.warn(TAG, 'clearAll skipped: repository not initialized')
      return { success: false, code: 'clear_failed' }
    }
    let cleared = await LogEntryRepository.clearAll()
    if (!cleared) {
      LogUtils.error(TAG, 'clearAll failed: repository clear returned false')
      return { success: false, code: 'clear_failed' }
    }
    LogEntryRepository.notifyChanged()
    return { success: true, code: 'ok' }
  }

  private static async reconcileAfterAppend(entries: LogEntry[]): Promise<MutationResult> {
    let config = await LogSettingsRepository.loadStorageConfig()
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(config.retentionDays)
    let maxEntries = LogEntryNormalizer.normalizeMaxEntries(config.maxLocalEntries)
    let cutoff = buildLogStorageNaturalDayCutoff(Date.now(), retentionDays)
    let hasExpiredEntry = entries.some((entry: LogEntry) => entry.timestamp < cutoff)
    if (hasExpiredEntry) {
      return LogStorageMaintenanceService.applyStorageLimits(maxEntries, cutoff)
    }
    let totalCount = await LogEntryRepository.countByQuery()
    if (totalCount > maxEntries) {
      return LogStorageMaintenanceService.applyStorageLimits(maxEntries, cutoff)
    }
    LogEntryRepository.notifyChanged()
    return { success: true, code: 'ok' }
  }

  private static async applyStorageLimits(maxEntries: number, cutoff: number): Promise<MutationResult> {
    let cleaned = await LogEntryRepository.deleteExpired(cutoff)
    if (!cleaned) {
      LogUtils.error(TAG, `applyStorageLimits failed: stage=deleteExpired, cutoff=${cutoff}`)
      return { success: false, code: 'save_failed' }
    }
    let trimmed = await LogEntryRepository.trimToMaxEntries(maxEntries)
    if (!trimmed) {
      LogUtils.error(TAG, `applyStorageLimits failed: stage=trim, maxEntries=${maxEntries}`)
      return { success: false, code: 'save_failed' }
    }
    LogEntryRepository.notifyChanged()
    return { success: true, code: 'ok' }
  }
}
