import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import {
  LogEntry,
  LogFilter,
  LogStorageConfig,
  LogSubscriptionConfig,
  LogStatistics,
  LogEventType,
  LogEventResult,
  LogExportResult,
  DEFAULT_LOG_STORAGE_CONFIG,
  DEFAULT_SUBSCRIPTION_CONFIG,
  ALL_LOG_EVENT_TYPES,
  PREF_STORE_NAME_LOG,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_KEY_LOG_SUBSCRIBE_ALL,
  PREF_KEY_LOG_SUBSCRIBED_TYPES,
  formatLogTimestamp,
  getLogEventTypeLabel,
  getLogEventResultLabel
} from '../models/DataModels'

const TAG = 'LogStorageService'
const DOMAIN = 0x0007

// Log data storage key
const LOG_DATA_KEY = 'log_entries'
const MAX_IN_MEMORY_ENTRIES = 5000
const MAX_PERSIST_ENTRIES = 1000
const MAX_PERSIST_PAYLOAD_CHARS = 1024 * 1024
const MAX_DETAIL_LENGTH = 1024
const MAX_PROCESS_NAME_LENGTH = 128
const MAX_FILE_PATH_LENGTH = 512
const MAX_REMOTE_ADDR_LENGTH = 256
const MAX_RAW_EVENT_NAME_LENGTH = 128
const MAX_RAW_OUTCOME_LENGTH = 64
const MAX_RAW_ACTION_LENGTH = 64

export interface LogCsvExportPayload {
  csvContent: string
  count?: number
  fileNamePrefix?: string
}

// Log storage service for persistence, querying, filtering, and export.
export class LogStorageService {

  private static context: common.UIAbilityContext | null = null
  private static logEntries: LogEntry[] = []
  private static storageConfig: LogStorageConfig = DEFAULT_LOG_STORAGE_CONFIG
  private static nowProvider: () => number = () => Date.now()
  private static randomProvider: () => number = () => Math.random()
  private static lastPersistTruncateWarnAt: number = 0
  private static isInitialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<boolean> | null = null

  // Initialize with a UIAbilityContext for Preferences access.
  static async init(context: common.UIAbilityContext): Promise<boolean> {
    LogStorageService.context = context
    let contextDir = context.filesDir || ''
    if (LogStorageService.isInitialized && LogStorageService.initializedContextDir === contextDir) {
      return true
    }

    if (LogStorageService.initPromise) {
      return LogStorageService.initPromise
    }

    LogStorageService.initPromise = LogStorageService.doInit(context, contextDir)
    let result = await LogStorageService.initPromise
    LogStorageService.initPromise = null
    return result
  }

  private static async doInit(context: common.UIAbilityContext, contextDir: string): Promise<boolean> {
    try {
      LogStorageService.context = context

      // Load persisted config.
      await LogStorageService.loadConfig()
      await LogStorageService.loadEntries()
      // Remove expired entries.
      let cleaned = LogStorageService.cleanExpiredEntries()
      if (cleaned > 0) {
        await LogStorageService.saveEntries()
      }

      LogStorageService.isInitialized = true
      LogStorageService.initializedContextDir = contextDir
      hilog.info(DOMAIN, TAG, `Initialized with ${LogStorageService.logEntries.length} entries`)
      return true
    } catch (err) {
      LogStorageService.isInitialized = false
      LogStorageService.initializedContextDir = ''
      hilog.error(DOMAIN, TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // Add a single log entry.
  static async addEntry(entry: LogEntry): Promise<boolean> {
    return LogStorageService.addEntries([entry])
  }

  // Add entries in batch to reduce write amplification for high-frequency events.
  static async addEntries(entries: LogEntry[]): Promise<boolean> {
    try {
      if (entries.length === 0) {
        return true
      }

      // Normalize once and prepend once to avoid repeated O(n^2) head inserts.
      let normalizedBatch = LogStorageService.normalizeEntriesForAppend(entries)
      if (normalizedBatch.length === 0) {
        return true
      }
      // Optimize memory: limit batch size first, then merge and trim
      let maxEntries = LogStorageService.getEffectiveMaxEntries()
      
      // Limit incoming batch to avoid excessive temporary array allocation
      if (normalizedBatch.length > maxEntries) {
        normalizedBatch = normalizedBatch.slice(0, maxEntries)
      }
      
      // Merge new entries (newest first) and trim to max
      LogStorageService.logEntries = normalizedBatch.concat(LogStorageService.logEntries)
      if (LogStorageService.logEntries.length > maxEntries) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(0, maxEntries)
      }

      void LogStorageService.saveEntries().catch((err: Object) => {
        hilog.error(DOMAIN, TAG, `saveEntries async failed: ${JSON.stringify(err)}`)
      })
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addEntries failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // Query entries using the provided filter.
  static queryEntries(filter?: LogFilter): LogEntry[] {
    if (!filter) {
      return LogStorageService.logEntries.slice(0, LogStorageService.logEntries.length)
    }

    if (
      filter.startTime !== undefined &&
      Number.isFinite(filter.startTime) &&
      filter.endTime !== undefined &&
      Number.isFinite(filter.endTime) &&
      filter.startTime > filter.endTime
    ) {
      return []
    }

    return LogStorageService.logEntries.filter((entry: LogEntry) => {
      // Filter by event type.
      if (filter.eventTypes && filter.eventTypes.length > 0) {
        if (!filter.eventTypes.includes(entry.eventType)) {
          return false
        }
      }

      // Filter by result.
      if (filter.results && filter.results.length > 0) {
        if (!filter.results.includes(entry.result)) {
          return false
        }
      }

      // Filter by time range.
      if (
        filter.startTime !== undefined &&
        Number.isFinite(filter.startTime) &&
        entry.timestamp < filter.startTime
      ) {
        return false
      }
      if (
        filter.endTime !== undefined &&
        Number.isFinite(filter.endTime) &&
        entry.timestamp > filter.endTime
      ) {
        return false
      }

      // Filter by keyword.
      if (filter.keyword && filter.keyword.length > 0) {
        let keyword = filter.keyword.toLowerCase()
        let matchDetail = entry.detail.toLowerCase().includes(keyword)
        let matchProcess = entry.processName ?
          entry.processName.toLowerCase().includes(keyword) : false
        let matchPath = entry.filePath ?
          entry.filePath.toLowerCase().includes(keyword) : false
        if (!matchDetail && !matchProcess && !matchPath) {
          return false
        }
      }

      return true
    })
  }

  // Compute aggregated log statistics.
  static getStatistics(): LogStatistics {
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()

    let byType = new Map<LogEventType, number>()
    let todayCount = 0
    let blockedCount = 0

    for (let entry of LogStorageService.logEntries) {
      // Count by event type.
      let count = byType.get(entry.eventType) || 0
      byType.set(entry.eventType, count + 1)

      // Count today's entries.
      if (entry.timestamp >= todayTimestamp) {
        todayCount++
      }

      // Count blocked events.
      if (entry.result === LogEventResult.BLOCKED) {
        blockedCount++
      }
    }

    return {
      totalCount: LogStorageService.logEntries.length,
      todayCount: todayCount,
      blockedCount: blockedCount,
      byType: byType
    }
  }

  // Clear all entries.
  static async clearAll(): Promise<boolean> {
    try {
      LogStorageService.logEntries = []
      await LogStorageService.saveEntries()
      hilog.info(DOMAIN, TAG, 'All log entries cleared')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }
  static buildCsvContent(entries: LogEntry[]): string {
    return LogStorageService.toCsv(entries)
  }

  // Export CSV content using a normalized payload.
  static async exportToCsvFile(payload: LogCsvExportPayload): Promise<LogExportResult> {
    let now = LogStorageService.nowProvider()
    let trimmedContent = payload.csvContent.trim()
    if (trimmedContent.length === 0) {
      return {
        success: false,
        timestamp: now,
        errorMessage: '无日志可导出'
      }
    }

    let fileName = LogStorageService.buildExportFileName(now, payload.fileNamePrefix ?? 'security_log')
    return LogStorageService.writeAndSave(trimmedContent, fileName, now)
  }


  private static async writeAndSave(
    content: string,
    fileName: string,
    timestamp: number
  ): Promise<LogExportResult> {
    if (!LogStorageService.context) {
      return {
        success: false,
        timestamp: timestamp,
        errorMessage: 'UI 上下文不可用'
      }
    }

    try {
      let documentViewPicker = new picker.DocumentViewPicker(LogStorageService.context)
      let saveOptions = new picker.DocumentSaveOptions()
      saveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD
      let result = await documentViewPicker.save(saveOptions)
      
      if (result.length === 0) {
        return {
          success: false,
          timestamp: timestamp,
          errorMessage: '用户取消保存'
        }
      }
      
      let directoryUri = result[0]
      let targetPath = new fileUri.FileUri(`${directoryUri}/${fileName}`).path
      let file = fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      fileIo.writeSync(file.fd, content)
      fileIo.closeSync(file.fd)

      let sizeBytes: number | undefined = undefined
      try {
        sizeBytes = fileIo.statSync(targetPath).size
      } catch (statErr) {
        hilog.warn(DOMAIN, TAG, `Export stat failed: ${JSON.stringify(statErr)}`)
      }
      
      return {
        success: true,
        timestamp: timestamp,
        fileName: fileName,
        directory: directoryUri,
        fullPath: targetPath,
        sizeBytes: sizeBytes
      }
    } catch (err) {
      let code = LogStorageService.extractErrorCode(err as Object)
      return {
        success: false,
        timestamp: timestamp,
        errorCode: code,
        errorMessage: `导出失败：${JSON.stringify(err)}`
      }
    }
  }

  // Load the subscription config.
  static async loadSubscriptionConfig(): Promise<LogSubscriptionConfig> {
    if (!LogStorageService.context) {
      return {
        subscribeAll: DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll,
        subscribedTypes: [...DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes]
      }
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)

      let subscribeAll = await store.get(
        PREF_KEY_LOG_SUBSCRIBE_ALL,
        DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll
      ) as boolean
      let rawTypes = await store.get(
        PREF_KEY_LOG_SUBSCRIBED_TYPES,
        JSON.stringify(DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes)
      ) as string

      let parsedTypes: number[] = []
      try {
        parsedTypes = JSON.parse(rawTypes) as number[]
      } catch {
        hilog.warn(DOMAIN, TAG, 'loadSubscriptionConfig: invalid subscribedTypes, fallback to default')
      }

      let subscribedTypes = subscribeAll
        ? [...ALL_LOG_EVENT_TYPES]
        : LogStorageService.sanitizeSubscribedTypes(parsedTypes)
      if (subscribedTypes.length === 0) {
        subscribedTypes = [...ALL_LOG_EVENT_TYPES]
      }

      return {
        subscribeAll: subscribeAll,
        subscribedTypes: subscribedTypes
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadSubscriptionConfig failed: ${JSON.stringify(err)}`)
      return {
        subscribeAll: DEFAULT_SUBSCRIPTION_CONFIG.subscribeAll,
        subscribedTypes: [...DEFAULT_SUBSCRIPTION_CONFIG.subscribedTypes]
      }
    }
  }

  // ========== Internal helpers ==========

  // Filter invalid event types and deduplicate values.
  private static sanitizeSubscribedTypes(types: number[]): LogEventType[] {
    let result: LogEventType[] = []
    for (let value of types) {
      let type = value as LogEventType
      if (ALL_LOG_EVENT_TYPES.includes(type) && !result.includes(type)) {
        result.push(type)
      }
    }
    return result
  }

  private static normalizeStorageConfig(config: LogStorageConfig): LogStorageConfig {
    return {
      maxLocalEntries: LogStorageService.normalizeMaxEntries(config.maxLocalEntries),
      retentionDays: LogStorageService.normalizeRetentionDays(config.retentionDays)
    }
  }



  private static buildExportFileName(timestamp: number, prefix: string = 'security_log'): string {
    let date = new Date(timestamp)
    let pad = (n: number): string => n.toString().padStart(2, '0')
    let datePart = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`
    let timePart = `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
    return `${prefix}_${datePart}_${timePart}.csv`
  }

  private static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  // Normalize the max entry count to avoid excessive memory usage.
  private static normalizeMaxEntries(maxEntries: number): number {
    if (!Number.isFinite(maxEntries) || maxEntries <= 0) {
      return DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
    }
    if (maxEntries > MAX_IN_MEMORY_ENTRIES) {
      hilog.warn(DOMAIN, TAG, `maxLocalEntries too large (${maxEntries}), clamp to ${MAX_IN_MEMORY_ENTRIES}`)
      return MAX_IN_MEMORY_ENTRIES
    }
    return Math.floor(maxEntries)
  }

  private static normalizeRetentionDays(days: number): number {
    if (!Number.isFinite(days)) {
      return DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }

    let normalized = Math.floor(days)
    if (normalized <= 0) {
      return DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    }

    if (normalized > 3650) {
      hilog.warn(DOMAIN, TAG, `retentionDays too large (${normalized}), clamp to 3650`)
      return 3650
    }

    return normalized
  }

  private static normalizeTimestamp(ts: number): number {
    if (!Number.isFinite(ts) || ts < 0) {
      return LogStorageService.nowProvider()
    }
    return Math.floor(ts)
  }

  private static normalizeEventType(type: LogEventType): LogEventType {
    if (ALL_LOG_EVENT_TYPES.includes(type)) {
      return type
    }
    return LogEventType.FILE
  }

  private static normalizeEventResult(result: LogEventResult): LogEventResult {
    if (
      result === LogEventResult.SUCCESS ||
      result === LogEventResult.BLOCKED ||
      result === LogEventResult.FAILED
    ) {
      return result
    }
    return LogEventResult.SUCCESS
  }

  private static normalizeEntryId(id: string | undefined): string {
    if (id && id.trim().length > 0) {
      return id.trim()
    }
    return `persist_${LogStorageService.nowProvider()}_${LogStorageService.randomProvider().toString(36).substring(2, 9)}`
  }

  // Effective in-memory entry limit.
  private static getEffectiveMaxEntries(): number {
    return LogStorageService.normalizeMaxEntries(LogStorageService.storageConfig.maxLocalEntries)
  }

  // Truncate oversized strings to keep a single entry bounded.
  private static truncateString(value: string | undefined, limit: number): string | undefined {
    if (value === undefined) {
      return undefined
    }
    if (value.length <= limit) {
      return value
    }
    return `${value.substring(0, limit)}...`
  }

  // Compact a single log entry.
  private static normalizeEntry(entry: LogEntry): LogEntry {
    return {
      id: LogStorageService.normalizeEntryId(entry.id),
      timestamp: LogStorageService.normalizeTimestamp(entry.timestamp),
      eventType: LogStorageService.normalizeEventType(entry.eventType),
      detail: LogStorageService.truncateString(entry.detail, MAX_DETAIL_LENGTH) || '',
      processName: LogStorageService.truncateString(entry.processName, MAX_PROCESS_NAME_LENGTH),
      pid: entry.pid,
      uid: entry.uid,
      filePath: LogStorageService.truncateString(entry.filePath, MAX_FILE_PATH_LENGTH),
      remoteAddr: LogStorageService.truncateString(entry.remoteAddr, MAX_REMOTE_ADDR_LENGTH),
      sourceEventId: entry.sourceEventId,
      sourceSubType: entry.sourceSubType,
      rawEventName: LogStorageService.truncateString(entry.rawEventName, MAX_RAW_EVENT_NAME_LENGTH),
      rawOutcome: LogStorageService.truncateString(entry.rawOutcome, MAX_RAW_OUTCOME_LENGTH),
      rawAction: LogStorageService.truncateString(entry.rawAction, MAX_RAW_ACTION_LENGTH),
      result: LogStorageService.normalizeEventResult(entry.result)
    }
  }

  private static normalizeEntriesForAppend(entries: LogEntry[]): LogEntry[] {
    let normalizedBatch: LogEntry[] = []
    for (let entry of entries) {
      if (!entry || typeof entry !== 'object') {
        continue
      }
      normalizedBatch.push(LogStorageService.normalizeEntry(entry))
    }

    // Reverse after normalization so the final order remains newest-first.
    normalizedBatch.reverse()
    return normalizedBatch
  }

  // Compact batched entries and drop malformed items.
  private static sanitizeEntries(entries: LogEntry[]): LogEntry[] {
    let result: LogEntry[] = []
    let limit = Math.min(entries.length, LogStorageService.getEffectiveMaxEntries())
    for (let i = 0; i < limit; i++) {
      let item = entries[i]
      if (!item || typeof item !== 'object') {
        continue
      }
      result.push(LogStorageService.normalizeEntry(item))
    }
    return result
  }

  // Build a payload that is safe to persist with both count and size limits.
  private static buildPersistPayload(): string {
    let effectiveMax = LogStorageService.getEffectiveMaxEntries()
    let saveLimit = Math.min(LogStorageService.logEntries.length, effectiveMax, MAX_PERSIST_ENTRIES)
    let persistEntries = LogStorageService.logEntries.slice(0, saveLimit)
    let payload = JSON.stringify(persistEntries)

    while (payload.length > MAX_PERSIST_PAYLOAD_CHARS && persistEntries.length > 1) {
      let nextLimit = Math.max(1, Math.floor(persistEntries.length * 0.8))
      persistEntries = persistEntries.slice(0, nextLimit)
      payload = JSON.stringify(persistEntries)
    }

    if (payload.length > MAX_PERSIST_PAYLOAD_CHARS) {
      hilog.warn(DOMAIN, TAG, 'Persist payload too large, fallback to empty list')
      return '[]'
    }

    if (saveLimit < LogStorageService.logEntries.length) {
      LogStorageService.warnPersistTruncate(LogStorageService.logEntries.length, persistEntries.length)
    }
    return payload
  }

  // Rate-limit truncate warnings to avoid log storms under high-frequency input.
  private static warnPersistTruncate(memoryCount: number, savedCount: number): void {
    let now = LogStorageService.nowProvider()
    if (now - LogStorageService.lastPersistTruncateWarnAt < 10000) {
      return
    }
    LogStorageService.lastPersistTruncateWarnAt = now
    hilog.warn(DOMAIN, TAG, `Persist entries truncated: memory=${memoryCount}, saved=${savedCount}`)
  }

  // Load entries from Preferences.
  private static async loadEntries(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      let rawData = await store.get(LOG_DATA_KEY, '[]') as string
      if (rawData.length > MAX_PERSIST_PAYLOAD_CHARS * 4) {
        hilog.warn(DOMAIN, TAG, `Persisted log payload too large (${rawData.length}), reset to empty`)
        LogStorageService.logEntries = []
        await store.put(LOG_DATA_KEY, '[]')
        await store.flush()
        return
      }
      let parsed = JSON.parse(rawData) as LogEntry[]
      LogStorageService.logEntries = LogStorageService.sanitizeEntries(parsed)
      let maxEntries = LogStorageService.getEffectiveMaxEntries()
      if (LogStorageService.logEntries.length > maxEntries) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(0, maxEntries)
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadEntries failed: ${JSON.stringify(err)}`)
      LogStorageService.logEntries = []
    }
  }

  // Persist entries to Preferences.
  private static async saveEntries(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      let payload = LogStorageService.buildPersistPayload()
      await store.put(LOG_DATA_KEY, payload)
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveEntries failed: ${JSON.stringify(err)}`)
    }
  }

  // Load storage config.
  private static async loadConfig(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)

      let maxEntries = await store.get(
        PREF_KEY_LOG_MAX_ENTRIES,
        DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
      ) as number
      let retentionDays = await store.get(
        PREF_KEY_LOG_RETENTION_DAYS,
        DEFAULT_LOG_STORAGE_CONFIG.retentionDays
      ) as Object

      let retentionDaysNumber = typeof retentionDays === 'number' ? retentionDays : Number(retentionDays as string)
      LogStorageService.storageConfig = LogStorageService.normalizeStorageConfig({
        maxLocalEntries: LogStorageService.normalizeMaxEntries(maxEntries),
        retentionDays: LogStorageService.normalizeRetentionDays(retentionDaysNumber)
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // Save storage config.
  private static async saveConfig(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      await store.put(PREF_KEY_LOG_MAX_ENTRIES, LogStorageService.storageConfig.maxLocalEntries)
      await store.put(PREF_KEY_LOG_RETENTION_DAYS, LogStorageService.storageConfig.retentionDays)
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // Get the current storage config.
  static getConfig(): LogStorageConfig {
    return {
      maxLocalEntries: LogStorageService.storageConfig.maxLocalEntries,
      retentionDays: LogStorageService.storageConfig.retentionDays
    }
  }

  // Update storage config.
  static async updateConfig(config: LogStorageConfig): Promise<boolean> {
    try {
      LogStorageService.storageConfig = LogStorageService.normalizeStorageConfig(config)
      let maxEntries = LogStorageService.getEffectiveMaxEntries()
      if (LogStorageService.logEntries.length > maxEntries) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(0, maxEntries)
      }
      LogStorageService.cleanExpiredEntries()
      await LogStorageService.saveEntries()
      await LogStorageService.saveConfig()
      hilog.info(DOMAIN, TAG, 'Storage config updated')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `updateConfig failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // Remove expired log entries.
  private static cleanExpiredEntries(): number {
    let retentionDays = LogStorageService.normalizeRetentionDays(LogStorageService.storageConfig.retentionDays)
    let retentionMs = retentionDays * 24 * 60 * 60 * 1000
    let cutoff = LogStorageService.nowProvider() - retentionMs
    let before = LogStorageService.logEntries.length

    LogStorageService.logEntries = LogStorageService.logEntries.filter(
      (e: LogEntry) => e.timestamp >= cutoff
    )

    let removed = before - LogStorageService.logEntries.length
    if (removed > 0) {
      hilog.info(DOMAIN, TAG, `Cleaned ${removed} expired entries`)
    }
    return removed
  }

  // Convert to CSV format.
  private static toCsv(entries: LogEntry[]): string {
    let header = '时间,事件类型,详情,进程名,PID,结果'
    let lines: string[] = [header]

    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      // Escape double quotes in CSV fields.
      let detail = `"${entry.detail.replace(/"/g, '""')}"`
      let process = entry.processName || ''
      let pid = entry.pid !== undefined ? entry.pid.toString() : ''
      let result = getLogEventResultLabel(entry.result)

      lines.push(`${time},${type},${detail},${process},${pid},${result}`)
    }

    return lines.join('\r\n')
  }
}
