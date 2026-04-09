import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogEntry,
  LogStatistics,
  PREF_STORE_NAME_LOG
} from '../../../models/DataModels'
import {
  ClearLogsResult,
  InitializeResult,
  LogQuery,
  LogSnapshot,
  MutationResult
} from '../common/LogManagePorts'
import { LogConfigRepository } from './LogConfigRepository'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'
import { LogEntryRepository } from './LogEntryRepository'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'

const TAG = 'LogRepository'
const LOG_DATA_KEY = 'log_entries'
const LOG_MIGRATED_KEY = 'log_entries_rdb_migrated'

type ChangeListener = () => void

export class LogRepository {
  private static context: common.UIAbilityContext | null = null
  private static logEntries: LogEntry[] = []
  private static isInitialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<InitializeResult> | null = null
  private static nextListenerId: number = 1
  private static listeners: Map<number, ChangeListener> = new Map()

  static async init(context: common.UIAbilityContext): Promise<InitializeResult> {
    LogRepository.context = context
    let contextDir = context.filesDir || ''
    if (LogRepository.isInitialized && LogRepository.initializedContextDir === contextDir) {
      return { success: true, code: 'ok' }
    }
    if (LogRepository.initPromise) {
      return LogRepository.initPromise
    }
    LogRepository.initPromise = LogRepository.doInit(context, contextDir)
    let result = await LogRepository.initPromise
    LogRepository.initPromise = null
    return result
  }

  static addChangeListener(listener: ChangeListener): number {
    let id = LogRepository.nextListenerId++
    LogRepository.listeners.set(id, listener)
    return id
  }

  static removeChangeListener(listenerId: number): void {
    LogRepository.listeners.delete(listenerId)
  }

  static async addEntry(entry: LogEntry): Promise<MutationResult> {
    return LogRepository.addEntries([entry])
  }

  static async addEntries(entries: LogEntry[]): Promise<MutationResult> {
    try {
      if (entries.length === 0) {
        return { success: true, code: 'ok' }
      }
      if (!LogRepository.isInitialized) {
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
      let maintained = await LogStorageMaintenanceService.maintainAfterAppend()
      if (!maintained.success) {
        return maintained
      }
      await LogRepository.reloadFromStorage()
      LogUtils.info(TAG, `addEntries success: appended=${normalizedBatch.length}, total=${LogRepository.logEntries.length}, latestTimestamp=${LogRepository.logEntries[0]?.timestamp ?? 0}`)
      LogRepository.notifyChanged()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `addEntries failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  static async snapshot(query?: LogQuery): Promise<LogSnapshot> {
    try {
      let statistics = await LogEntryRepository.getStatistics()
      let entries = await LogEntryRepository.listByQuery(query)
      return {
        totalCount: statistics.totalCount,
        todayCount: statistics.todayCount,
        blockedCount: statistics.blockedCount,
        entries
      }
    } catch (err) {
      LogUtils.error(TAG, `snapshot failed: ${JSON.stringify(err)}`)
      return {
        totalCount: 0,
        todayCount: 0,
        blockedCount: 0,
        entries: []
      }
    }
  }

  static async getStatistics(): Promise<LogStatistics> {
    return LogEntryRepository.getStatistics()
  }

  static async clear(): Promise<ClearLogsResult> {
    try {
      let cleared = await LogEntryRepository.clearAll()
      if (!cleared) {
        return { success: false, code: 'clear_failed' }
      }
      LogRepository.logEntries = []
      LogRepository.notifyChanged()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `clear failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'clear_failed' }
    }
  }

  static async reconcileStorageConfig(): Promise<MutationResult> {
    try {
      if (!LogRepository.isInitialized) {
        return { success: false, code: 'not_initialized' }
      }
      let maintained = await LogStorageMaintenanceService.reconcileStorageConfig()
      if (!maintained.success) {
        return maintained
      }
      await LogRepository.reloadFromStorage()
      LogRepository.notifyChanged()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `reconcileStorageConfig failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  private static async doInit(context: common.UIAbilityContext, contextDir: string): Promise<InitializeResult> {
    try {
      LogRepository.context = context
      let configResult = await LogConfigRepository.init(context)
      if (!configResult.success) {
        LogRepository.isInitialized = false
        LogRepository.initializedContextDir = ''
        return { success: false, code: 'config_init_failed' }
      }
      let rdbReady = await LogEntryRepository.init(context)
      if (!rdbReady) {
        LogRepository.isInitialized = false
        LogRepository.initializedContextDir = ''
        return { success: false, code: 'storage_init_failed' }
      }
      await LogRepository.migrateLegacyPayloadIfNeeded()
      let reconcileResult = await LogStorageMaintenanceService.reconcileStorageConfig()
      if (!reconcileResult.success) {
        LogRepository.isInitialized = false
        LogRepository.initializedContextDir = ''
        return { success: false, code: 'storage_init_failed' }
      }
      await LogRepository.reloadFromStorage()
      LogRepository.isInitialized = true
      LogRepository.initializedContextDir = contextDir
      return { success: true, code: 'ok' }
    } catch (err) {
      LogRepository.isInitialized = false
      LogRepository.initializedContextDir = ''
      LogUtils.error(TAG, `doInit failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'storage_init_failed' }
    }
  }

  private static notifyChanged(): void {
    LogRepository.listeners.forEach((listener: ChangeListener) => {
      try {
        listener()
      } catch (err) {
        LogUtils.warn(TAG, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }

  private static async reloadFromStorage(): Promise<void> {
    if (!LogRepository.context) {
      return
    }
    try {
      let maxEntries = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
      LogRepository.logEntries = await LogEntryRepository.listLatest(maxEntries)
    } catch (err) {
      LogUtils.error(TAG, `reloadFromStorage failed: ${JSON.stringify(err)}`)
      LogRepository.logEntries = []
    }
  }

  private static async migrateLegacyPayloadIfNeeded(): Promise<void> {
    if (!LogRepository.context) {
      return
    }
    try {
      let pref = PreferencesAccessor.of(LogRepository.context, PREF_STORE_NAME_LOG)
      let migrated = await pref.getBoolean(LOG_MIGRATED_KEY, false)
      if (migrated) {
        return
      }
      let legacyEntries = await pref.getJsonArray<LogEntry>(LOG_DATA_KEY, [])
      let maxEntries = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
      let sanitized = LogEntryNormalizer.sanitizeEntries(legacyEntries, maxEntries)
      if (sanitized.length > 0) {
        let imported = await LogEntryRepository.upsertEntries(sanitized)
        if (!imported) {
          LogUtils.error(TAG, 'migrateLegacyPayloadIfNeeded failed: import_failed')
          return
        }
      }
      let saved = await pref.setMany([
        { key: LOG_DATA_KEY, value: '[]' },
        { key: LOG_MIGRATED_KEY, value: true }
      ])
      if (!saved) {
        LogUtils.error(TAG, 'migrateLegacyPayloadIfNeeded failed: save_migration_marker_failed')
      }
    } catch (err) {
      LogUtils.error(TAG, `migrateLegacyPayloadIfNeeded failed: ${JSON.stringify(err)}`)
    }
  }
}
