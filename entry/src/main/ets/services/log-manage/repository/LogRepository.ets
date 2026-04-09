import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
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

const TAG = 'LogRepository'
const LOG_DATA_KEY = 'log_entries'
const MAX_PERSIST_ENTRIES = 1000
const MAX_PERSIST_PAYLOAD_CHARS = 1024 * 1024

type ChangeListener = () => void

export class LogRepository {
  private static context: common.UIAbilityContext | null = null
  private static logEntries: LogEntry[] = []
  private static isInitialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<InitializeResult> | null = null
  private static nextListenerId: number = 1
  private static listeners: Map<number, ChangeListener> = new Map()
  private static lastPersistTruncateWarnAt: number = 0

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
      let maxEntries = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
      let normalizedBatch = LogEntryNormalizer.normalizeEntriesForAppend(entries)
      if (normalizedBatch.length === 0) {
        return { success: true, code: 'ok' }
      }
      if (normalizedBatch.length > maxEntries) {
        normalizedBatch = normalizedBatch.slice(0, maxEntries)
      }
      LogRepository.logEntries = normalizedBatch.concat(LogRepository.logEntries)
      if (LogRepository.logEntries.length > maxEntries) {
        LogRepository.logEntries = LogRepository.logEntries.slice(0, maxEntries)
      }
      LogRepository.cleanExpiredEntries()
      LogUtils.info(TAG, `addEntries success: appended=${normalizedBatch.length}, total=${LogRepository.logEntries.length}, latestTimestamp=${LogRepository.logEntries[0]?.timestamp ?? 0}`)
      LogRepository.notifyChanged()
      void LogRepository.saveEntries().catch((err: Object) => {
        LogUtils.error(TAG, `saveEntries async failed: ${JSON.stringify(err)}`)
      })
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `addEntries failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'save_failed' }
    }
  }

  static snapshot(query?: LogQuery): LogSnapshot {
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()
    let entries: LogEntry[] = []
    let totalCount = LogRepository.logEntries.length
    let todayCount = 0
    let blockedCount = 0
    for (let entry of LogRepository.logEntries) {
      if (entry.timestamp >= todayTimestamp) {
        todayCount++
      }
      if (entry.result === LogEventResult.BLOCKED) {
        blockedCount++
      }
      if (!query || LogRepository.matchesQuery(entry, query)) {
        entries.push(entry)
      }
    }
    return {
      totalCount,
      todayCount,
      blockedCount,
      entries
    }
  }

  static getStatistics(): LogStatistics {
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()
    let byType = new Map<LogEventType, number>()
    let todayCount = 0
    let blockedCount = 0
    for (let entry of LogRepository.logEntries) {
      let count = byType.get(entry.eventType) || 0
      byType.set(entry.eventType, count + 1)
      if (entry.timestamp >= todayTimestamp) {
        todayCount++
      }
      if (entry.result === LogEventResult.BLOCKED) {
        blockedCount++
      }
    }
    return {
      totalCount: LogRepository.logEntries.length,
      todayCount,
      blockedCount,
      byType
    }
  }

  static async clear(): Promise<ClearLogsResult> {
    try {
      LogRepository.logEntries = []
      LogRepository.notifyChanged()
      await LogRepository.saveEntries()
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
      let maxEntries = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
      if (LogRepository.logEntries.length > maxEntries) {
        LogRepository.logEntries = LogRepository.logEntries.slice(0, maxEntries)
      }
      LogRepository.cleanExpiredEntries()
      LogRepository.notifyChanged()
      await LogRepository.saveEntries()
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
      await LogRepository.loadEntries()
      let cleaned = LogRepository.cleanExpiredEntries()
      if (cleaned > 0) {
        await LogRepository.saveEntries()
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

  private static async loadEntries(): Promise<void> {
    if (!LogRepository.context) {
      return
    }
    try {
      let store = await preferences.getPreferences(LogRepository.context, PREF_STORE_NAME_LOG)
      let rawData = await store.get(LOG_DATA_KEY, '[]') as string
      if (rawData.length > MAX_PERSIST_PAYLOAD_CHARS * 4) {
        LogRepository.logEntries = []
        await store.put(LOG_DATA_KEY, '[]')
        await store.flush()
        return
      }
      let parsed = JSON.parse(rawData) as LogEntry[]
      let maxEntries = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
      LogRepository.logEntries = LogEntryNormalizer.sanitizeEntries(parsed, maxEntries)
      if (LogRepository.logEntries.length > maxEntries) {
        LogRepository.logEntries = LogRepository.logEntries.slice(0, maxEntries)
      }
    } catch (err) {
      LogUtils.error(TAG, `loadEntries failed: ${JSON.stringify(err)}`)
      LogRepository.logEntries = []
    }
  }

  private static async saveEntries(): Promise<void> {
    if (!LogRepository.context) {
      return
    }
    try {
      let store = await preferences.getPreferences(LogRepository.context, PREF_STORE_NAME_LOG)
      let payload = LogRepository.buildPersistPayload()
      await store.put(LOG_DATA_KEY, payload)
      await store.flush()
    } catch (err) {
      LogUtils.error(TAG, `saveEntries failed: ${JSON.stringify(err)}`)
    }
  }

  private static buildPersistPayload(): string {
    let effectiveMax = LogEntryNormalizer.normalizeMaxEntries(LogConfigRepository.getStorageConfigSync().maxLocalEntries)
    let saveLimit = Math.min(LogRepository.logEntries.length, effectiveMax, MAX_PERSIST_ENTRIES)
    let persistEntries = LogRepository.logEntries.slice(0, saveLimit)
    let payload = JSON.stringify(persistEntries)
    while (payload.length > MAX_PERSIST_PAYLOAD_CHARS && persistEntries.length > 1) {
      let nextLimit = Math.max(1, Math.floor(persistEntries.length * 0.8))
      persistEntries = persistEntries.slice(0, nextLimit)
      payload = JSON.stringify(persistEntries)
    }
    if (payload.length > MAX_PERSIST_PAYLOAD_CHARS) {
      return '[]'
    }
    if (saveLimit < LogRepository.logEntries.length) {
      LogRepository.warnPersistTruncate(LogRepository.logEntries.length, persistEntries.length)
    }
    return payload
  }

  private static cleanExpiredEntries(): number {
    let retentionDays = LogEntryNormalizer.normalizeRetentionDays(LogConfigRepository.getStorageConfigSync().retentionDays)
    let retentionMs = retentionDays * 24 * 60 * 60 * 1000
    let cutoff = Date.now() - retentionMs
    let before = LogRepository.logEntries.length
    LogRepository.logEntries = LogRepository.logEntries.filter((entry: LogEntry) => entry.timestamp >= cutoff)
    return before - LogRepository.logEntries.length
  }

  private static matchesQuery(entry: LogEntry, query: LogQuery): boolean {
    if (query.eventTypes && query.eventTypes.length > 0 && !query.eventTypes.includes(entry.eventType)) {
      return false
    }
    if (query.results && query.results.length > 0 && !query.results.includes(entry.result)) {
      return false
    }
    if (query.keyword && query.keyword.length > 0) {
      let keyword = query.keyword.toLowerCase()
      let matchDetail = entry.detail.toLowerCase().includes(keyword)
      let matchProcess = entry.processName ? entry.processName.toLowerCase().includes(keyword) : false
      let matchPath = entry.filePath ? entry.filePath.toLowerCase().includes(keyword) : false
      if (!matchDetail && !matchProcess && !matchPath) {
        return false
      }
    }
    return true
  }

  private static warnPersistTruncate(memoryCount: number, savedCount: number): void {
    let now = Date.now()
    if (now - LogRepository.lastPersistTruncateWarnAt < 10000) {
      return
    }
    LogRepository.lastPersistTruncateWarnAt = now
    LogUtils.warn(TAG, `Persist entries truncated: memory=${memoryCount}, saved=${savedCount}`)
  }

}
