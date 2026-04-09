import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogEntry,
  LogStatistics
} from '../../../models/DataModels'
import {
  ClearLogsResult,
  InitializeResult,
  LogQuery,
  LogSnapshot,
  MutationResult
} from '../common/LogManagePorts'
import { LogSettingsRepository } from './LogSettingsRepository'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { LogEntryRepository } from './LogEntryRepository'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'

const TAG = 'LogRepository'

type ChangeListener = () => void

export class LogRepository {
  private static isInitialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<InitializeResult> | null = null
  private static nextListenerId: number = 1
  private static listeners: Map<number, ChangeListener> = new Map()

  static async init(context: common.UIAbilityContext): Promise<InitializeResult> {
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
      let maintained = await LogStorageMaintenanceService.reconcileStorageConfig()
      if (!maintained.success) {
        return maintained
      }
      LogUtils.info(TAG, `addEntries success: appended=${normalizedBatch.length}`)
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
      LogRepository.notifyChanged()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `reconcileStorageConfig failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  private static async doInit(context: common.UIAbilityContext, contextDir: string): Promise<InitializeResult> {
    try {
      let configResult = await LogSettingsRepository.init(context)
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
      let reconcileResult = await LogStorageMaintenanceService.reconcileStorageConfig()
      if (!reconcileResult.success) {
        LogRepository.isInitialized = false
        LogRepository.initializedContextDir = ''
        return { success: false, code: 'storage_init_failed' }
      }
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
}
