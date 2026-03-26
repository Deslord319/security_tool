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
  LogExportFormat,
  LogExportResult,
  LogExportTrigger,
  LogExportRecoveryAction,
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
const PREF_KEY_LOG_EXPORT_DOWNLOAD_URI = 'log_export_download_uri'
const LEGACY_PREF_KEY_LOG_EXPORT_PATH = 'log_export_path'
const LEGACY_PREF_KEY_LOG_EXPORT_TARGET_TYPE = 'log_export_target_type'
const LEGACY_PREF_KEY_LOG_EXPORT_TARGET_VALUE = 'log_export_target_value'
const LEGACY_PREF_KEY_LOG_EXPORT_AUTH_MODE = 'log_export_auth_mode'

export interface LogStorageChangeEvent {
  totalCount: number
  addedCount: number
  timestamp: number
}

export interface LogContentExportOptions {
  fileNamePrefix?: string
  count?: number
  emptyErrorMessage?: string
}

export type LogStorageChangeListener = (event: LogStorageChangeEvent) => void

// Log storage service for persistence, querying, filtering, and export.
export class LogStorageService {

  private static context: common.UIAbilityContext | null = null
  private static logEntries: LogEntry[] = []
  private static storageConfig: LogStorageConfig = DEFAULT_LOG_STORAGE_CONFIG
  private static exportDirectoryUri: string = ''
  private static nowProvider: () => number = () => Date.now()
  private static randomProvider: () => number = () => Math.random()
  private static lastPersistTruncateWarnAt: number = 0
  private static isInitialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<boolean> | null = null
  private static nextListenerId: number = 1
  private static changeListeners: Map<number, LogStorageChangeListener> = new Map()

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
      LogStorageService.logEntries = normalizedBatch.concat(LogStorageService.logEntries)

      // Trim oldest entries when the effective max count is exceeded.
      let maxEntries = LogStorageService.getEffectiveMaxEntries()
      let overflowCount = LogStorageService.logEntries.length - maxEntries
      if (overflowCount > 0) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(
          0, maxEntries
        )
      }

      LogStorageService.notifyEntriesChanged(normalizedBatch.length)
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
      LogStorageService.notifyEntriesChanged(0)
      hilog.info(DOMAIN, TAG, 'All log entries cleared')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // Delete a specific entry by id.
  static async deleteEntry(entryId: string): Promise<boolean> {
    try {
      let initialLength = LogStorageService.logEntries.length
      LogStorageService.logEntries = LogStorageService.logEntries.filter(
        (e: LogEntry) => e.id !== entryId
      )

      if (LogStorageService.logEntries.length < initialLength) {
        await LogStorageService.saveEntries()
        LogStorageService.notifyEntriesChanged(0)
        hilog.debug(DOMAIN, TAG, `Deleted entry: ${entryId}`)
        return true
      }
      return false
    } catch (err) {
      hilog.error(DOMAIN, TAG, `deleteEntry failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // Export logs as text content.
  static exportToString(entries: LogEntry[], format: LogExportFormat): string {
    switch (format) {
      case LogExportFormat.JSON:
        return JSON.stringify(entries, null, 2)

      case LogExportFormat.CSV:
        // Add UTF-8 BOM for Excel-compatible CSV decoding.
        return `﻿${LogStorageService.toCsv(entries)}`

      case LogExportFormat.TXT:
        return LogStorageService.toTxt(entries)

      default:
        return JSON.stringify(entries, null, 2)
    }
  }

  // Export logs to a file.
  static async exportToFile(
    entries: LogEntry[],
    format: LogExportFormat,
    trigger: LogExportTrigger
  ): Promise<LogExportResult> {
    let now = LogStorageService.nowProvider()

    if (entries.length === 0) {
      return {
        success: false,
        count: entries.length,
        format: format,
        timestamp: now,
        trigger: trigger,
        errorMessage: '无可导出日志'
      }
    }

    let content = LogStorageService.exportToString(entries, format)
    let fileName = LogStorageService.buildExportFileName(format, entries.length, now)
    let primaryTarget = LogStorageService.resolveConfiguredExportDirectory()
    let authResult = await LogStorageService.ensureExportTargetReady(primaryTarget, trigger)
    let primaryDir = authResult.directory || primaryTarget.directory
    if (!authResult.success) {
      return {
        success: false,
        count: entries.length,
        format: format,
        timestamp: now,
        trigger: trigger,
        fileName: fileName,
        directory: primaryDir,
        errorCode: authResult.errorCode,
        errorMessage: authResult.errorMessage,
        recoverAction: authResult.recoverAction
      }
    }

    let primaryWrite = LogStorageService.tryWriteExportFile(primaryDir, fileName, content)
    if (primaryWrite.success) {
      return {
        count: entries.length,
        format: format,
        timestamp: now,
        trigger: trigger,
        success: true,
        fileName: fileName,
        directory: primaryDir,
        fullPath: primaryWrite.fullPath,
        sizeBytes: primaryWrite.sizeBytes
      }
    }

    if (
      trigger === 'manual' &&
      LogStorageService.isUriPath(primaryDir) &&
      LogStorageService.shouldRetryDownloadAuthorization(primaryWrite.errorCode)
    ) {
      await LogStorageService.clearDownloadAuthorization()
      let retryTarget = LogStorageService.resolveConfiguredExportDirectory()
      let retryAuth = await LogStorageService.ensureExportTargetReady(retryTarget, trigger)
      let retryDir = retryAuth.directory || retryTarget.directory
      if (!retryAuth.success) {
        return {
          success: false,
          count: entries.length,
          format: format,
          timestamp: now,
          trigger: trigger,
          fileName: fileName,
          directory: retryDir,
          errorCode: retryAuth.errorCode,
          errorMessage: retryAuth.errorMessage,
          recoverAction: retryAuth.recoverAction
        }
      }

      let retryWrite = LogStorageService.tryWriteExportFile(retryDir, fileName, content)
      if (retryWrite.success) {
        return {
          count: entries.length,
          format: format,
          timestamp: now,
          trigger: trigger,
          success: true,
          fileName: fileName,
          directory: retryDir,
          fullPath: retryWrite.fullPath,
          sizeBytes: retryWrite.sizeBytes
        }
      }

      return {
        success: false,
        count: entries.length,
        format: format,
        timestamp: now,
        trigger: trigger,
        fileName: fileName,
        directory: retryDir,
        errorCode: retryWrite.errorCode,
        errorMessage: retryWrite.errorMessage,
        recoverAction: 'authorize_download'
      }
    }

    return {
      success: false,
      count: entries.length,
      format: format,
      timestamp: now,
      trigger: trigger,
      fileName: fileName,
      directory: primaryDir,
      errorCode: primaryWrite.errorCode,
      errorMessage: primaryWrite.errorMessage
    }
  }

  private static async ensureExportTargetReady(
    target: ResolvedExportTarget,
    trigger: LogExportTrigger
  ): Promise<ExportAuthResult> {
    let directoryUri = LogStorageService.sanitizeExportTargetUri(target.directory)
    if (directoryUri.length > 0) {
      return {
        success: true,
        directory: directoryUri
      }
    }

    if (trigger !== 'manual') {
      return {
        success: false,
        errorMessage: 'Download directory authorization is required before auto export.',
        recoverAction: 'authorize_download'
      }
    }

    return LogStorageService.requestDownloadAuthorization()
  }

  private static sanitizeExportTargetUri(uri: string | undefined): string {
    if (!uri) {
      return ''
    }
    let normalized = uri.trim().replace(/\/+$/, '')
    return LogStorageService.isUriPath(normalized) ? normalized : ''
  }

  private static async requestDownloadAuthorization(): Promise<ExportAuthResult> {
    if (!LogStorageService.context) {
      return {
        success: false,
        errorMessage: 'UI context unavailable for download authorization.',
        recoverAction: 'authorize_download'
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
          errorMessage: 'No download directory URI returned by picker.',
          recoverAction: 'authorize_download'
        }
      }
      let directoryUri = LogStorageService.sanitizeExportTargetUri(result[0])
      if (directoryUri.length === 0) {
        return {
          success: false,
          errorMessage: 'No download directory URI returned by picker.',
          recoverAction: 'authorize_download'
        }
      }

      LogStorageService.exportDirectoryUri = directoryUri
      await LogStorageService.saveConfig()

      return {
        success: true,
        directory: directoryUri
      }
    } catch (err) {
      return {
        success: false,
        errorCode: LogStorageService.extractErrorCode(err as Object),
        errorMessage: `Download directory authorization failed: ${JSON.stringify(err)}`,
        recoverAction: 'authorize_download'
      }
    }
  }

  static async exportContentToFile(
    content: string,
    format: LogExportFormat,
    trigger: LogExportTrigger,
    options?: LogContentExportOptions
  ): Promise<LogExportResult> {
    let now = LogStorageService.nowProvider()
    let trimmed = content.trim()
    let count = options?.count ?? 0
    if (trimmed.length === 0) {
      return {
        success: false,
        count: count,
        format: format,
        timestamp: now,
        trigger: trigger,
        errorMessage: options?.emptyErrorMessage ?? '无可导出内容'
      }
    }

    let fileName = LogStorageService.buildExportFileNameWithPrefix(
      options?.fileNamePrefix ?? 'export',
      format,
      count,
      now
    )
    let primaryTarget = LogStorageService.resolveConfiguredExportDirectory()
    let authResult = await LogStorageService.ensureExportTargetReady(primaryTarget, trigger)
    let primaryDir = authResult.directory || primaryTarget.directory
    if (!authResult.success) {
      return {
        success: false,
        count: count,
        format: format,
        timestamp: now,
        trigger: trigger,
        fileName: fileName,
        directory: primaryDir,
        errorCode: authResult.errorCode,
        errorMessage: authResult.errorMessage,
        recoverAction: authResult.recoverAction
      }
    }

    let primaryWrite = LogStorageService.tryWriteExportFile(primaryDir, fileName, content)
    if (primaryWrite.success) {
      return {
        count: count,
        format: format,
        timestamp: now,
        trigger: trigger,
        success: true,
        fileName: fileName,
        directory: primaryDir,
        fullPath: primaryWrite.fullPath,
        sizeBytes: primaryWrite.sizeBytes
      }
    }

    if (
      trigger === 'manual' &&
      LogStorageService.isUriPath(primaryDir) &&
      LogStorageService.shouldRetryDownloadAuthorization(primaryWrite.errorCode)
    ) {
      await LogStorageService.clearDownloadAuthorization()
      let retryTarget = LogStorageService.resolveConfiguredExportDirectory()
      let retryAuth = await LogStorageService.ensureExportTargetReady(retryTarget, trigger)
      let retryDir = retryAuth.directory || primaryTarget.directory
      if (!retryAuth.success) {
        return {
          success: false,
          count: count,
          format: format,
          timestamp: now,
          trigger: trigger,
          fileName: fileName,
          directory: retryDir,
          errorCode: retryAuth.errorCode,
          errorMessage: retryAuth.errorMessage,
          recoverAction: retryAuth.recoverAction
        }
      }

      let retryWrite = LogStorageService.tryWriteExportFile(retryDir, fileName, content)
      if (retryWrite.success) {
        return {
          count: count,
          format: format,
          timestamp: now,
          trigger: trigger,
          success: true,
          fileName: fileName,
          directory: retryDir,
          fullPath: retryWrite.fullPath,
          sizeBytes: retryWrite.sizeBytes
        }
      }

      return {
        success: false,
        count: count,
        format: format,
        timestamp: now,
        trigger: trigger,
        fileName: fileName,
        directory: retryDir,
        errorCode: retryWrite.errorCode,
        errorMessage: retryWrite.errorMessage,
        recoverAction: 'authorize_download'
      }
    }

    return {
      success: false,
      count: count,
      format: format,
      timestamp: now,
      trigger: trigger,
      fileName: fileName,
      directory: primaryDir,
      errorCode: primaryWrite.errorCode,
      errorMessage: primaryWrite.errorMessage
    }
  }

  private static async clearDownloadAuthorization(): Promise<void> {
    if (LogStorageService.exportDirectoryUri.length === 0) {
      return
    }
    LogStorageService.exportDirectoryUri = ''
    await LogStorageService.saveConfig()
  }

  private static shouldRetryDownloadAuthorization(errorCode?: number): boolean {
    if (errorCode === undefined) {
      return true
    }
    return errorCode === 13900001 || errorCode === 13900002 || errorCode === 201 || errorCode === 202
  }

  // Get the current entry count.
  static getEntryCount(): number {
    return LogStorageService.logEntries.length
  }

  // Get the current storage config.
  static getConfig(): LogStorageConfig {
    let cfg = LogStorageService.storageConfig
    let copy: LogStorageConfig = {
      maxLocalEntries: cfg.maxLocalEntries,
      retentionDays: cfg.retentionDays
    }
    return copy
  }

  static addChangeListener(listener: LogStorageChangeListener): number {
    let listenerId = LogStorageService.nextListenerId++
    LogStorageService.changeListeners.set(listenerId, listener)
    return listenerId
  }

  static removeChangeListener(listenerId: number): void {
    LogStorageService.changeListeners.delete(listenerId)
  }

  // Update the storage config.
  static async updateConfig(config: LogStorageConfig): Promise<boolean> {
    try {
      let normalizedConfig = LogStorageService.normalizeStorageConfig(config)
      LogStorageService.storageConfig = normalizedConfig
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

  // Save the subscription config.
  static async saveSubscriptionConfig(config: LogSubscriptionConfig): Promise<boolean> {
    if (!LogStorageService.context) {
      return false
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      let subscribedTypes = config.subscribeAll
        ? [...ALL_LOG_EVENT_TYPES]
        : LogStorageService.sanitizeSubscribedTypes(config.subscribedTypes as number[])
      let subscribeAll = config.subscribeAll
      if (subscribedTypes.length === 0) {
        subscribeAll = true
        subscribedTypes = [...ALL_LOG_EVENT_TYPES]
      }

      await store.put(PREF_KEY_LOG_SUBSCRIBE_ALL, subscribeAll)
      await store.put(PREF_KEY_LOG_SUBSCRIBED_TYPES, JSON.stringify(subscribedTypes))
      await store.flush()
      hilog.info(DOMAIN, TAG, 'Subscription config saved')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveSubscriptionConfig failed: ${JSON.stringify(err)}`)
      return false
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

  private static notifyEntriesChanged(addedCount: number): void {
    if (LogStorageService.changeListeners.size === 0) {
      return
    }
    let event: LogStorageChangeEvent = {
      totalCount: LogStorageService.logEntries.length,
      addedCount: addedCount,
      timestamp: LogStorageService.nowProvider()
    }
    LogStorageService.changeListeners.forEach((listener: LogStorageChangeListener) => {
      try {
        listener(event)
      } catch (err) {
        hilog.warn(DOMAIN, TAG, `change listener failed: ${JSON.stringify(err)}`)
      }
    })
  }

  private static normalizeStorageConfig(config: LogStorageConfig): LogStorageConfig {
    return {
      maxLocalEntries: LogStorageService.normalizeMaxEntries(config.maxLocalEntries),
      retentionDays: LogStorageService.normalizeRetentionDays(config.retentionDays)
    }
  }

  private static resolveConfiguredExportDirectory(): ResolvedExportTarget {
    return {
      directory: LogStorageService.sanitizeExportTargetUri(LogStorageService.exportDirectoryUri)
    }
  }

  private static buildExportFileName(format: LogExportFormat, count: number, timestamp: number): string {
    return LogStorageService.buildExportFileNameWithPrefix('security_log', format, count, timestamp)
  }

  private static buildExportFileNameWithPrefix(
    prefix: string,
    format: LogExportFormat,
    count: number,
    timestamp: number
  ): string {
    let date = new Date(timestamp)
    let pad = (n: number): string => n.toString().padStart(2, '0')
    let datePart = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`
    let timePart = `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
    return `${prefix}_${datePart}_${timePart}_${count}.${format}`
  }

  private static tryWriteExportFile(
    directory: string,
    fileName: string,
    content: string
  ): ExportWriteResult {
    if (directory.length === 0) {
      return {
        success: false,
        errorMessage: '导出目录为空'
      }
    }

    let targetPath = LogStorageService.joinPath(directory, fileName)
    let file: fileIo.File | undefined = undefined
    try {
      if (LogStorageService.isUriPath(directory)) {
        targetPath = new fileUri.FileUri(targetPath).path
      } else {
        LogStorageService.ensureDirectoryExists(directory)
      }
      file = fileIo.openSync(
        targetPath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE
      )
      fileIo.writeSync(file.fd, content)
      fileIo.closeSync(file.fd)
      file = undefined

      let sizeBytes: number | undefined = undefined
      try {
        sizeBytes = fileIo.statSync(targetPath).size
      } catch (statErr) {
        hilog.warn(
          DOMAIN,
          TAG,
          `Export stat failed after write: ${JSON.stringify(statErr)}; targetPath=${targetPath}`
        )
      }
      return {
        success: true,
        fullPath: targetPath,
        sizeBytes: sizeBytes
      }
    } catch (err) {
      if (file) {
        try {
          fileIo.closeSync(file.fd)
        } catch (closeErr) {
          hilog.warn(DOMAIN, TAG, `Failed to close file handle during error recovery: ${JSON.stringify(closeErr)}`)
        }
      }
      try {
        let code = LogStorageService.extractErrorCode(err as Object)
        let msg = `写入导出文件失败: ${JSON.stringify(err)}; directory=${directory}; targetPath=${targetPath}`
        hilog.error(DOMAIN, TAG, msg)
        return {
          success: false,
          errorCode: code,
          errorMessage: msg
        }
      } catch (_formatErr) {
        return {
          success: false,
          errorMessage: '写入导出文件失败'
        }
      }
    }
  }

  private static ensureDirectoryExists(path: string): void {
    if (path.length === 0 || LogStorageService.isDirectoryRoot(path) || LogStorageService.isUriPath(path)) {
      return
    }

    let normalized = LogStorageService.normalizeDirectoryPath(path)
    if (normalized.length === 0 || LogStorageService.isDirectoryRoot(normalized)) {
      return
    }

    try {
      let stat = fileIo.statSync(normalized)
      if (!stat.isDirectory()) {
        throw new Error(`Path exists but is not a directory: ${normalized}`)
      }
      return
    } catch (statErr) {
      let message = `${statErr}`
      if (message.includes('Path exists but is not a directory')) {
        throw statErr as Error
      }
    }

    let parent = LogStorageService.getParentDirectory(normalized)
    if (parent.length > 0 && parent !== normalized) {
      LogStorageService.ensureDirectoryExists(parent)
    }

    try {
      fileIo.mkdirSync(normalized)
    } catch (_mkdirErr) {
      // The directory may have been created concurrently; recheck before failing.
      let stat = fileIo.statSync(normalized)
      if (!stat.isDirectory()) {
        throw new Error(`Failed to create directory: ${normalized}`)
      }
    }
  }

  private static getParentDirectory(path: string): string {
    let normalized = LogStorageService.normalizeDirectoryPath(path)
    if (normalized.length === 0 || LogStorageService.isDirectoryRoot(normalized)) {
      return ''
    }

    if (LogStorageService.isFileUri(normalized)) {
      let body = normalized.substring('file://'.length)
      if (body.length === 0 || body === '/') {
        return ''
      }
      let idx = body.lastIndexOf('/')
      if (idx < 0) {
        return ''
      }
      if (idx === 0) {
        return 'file:///'
      }
      return `file://${body.substring(0, idx)}`
    }

    let idx = normalized.lastIndexOf('/')
    if (idx < 0) {
      return ''
    }
    if (idx === 0) {
      return '/'
    }
    return normalized.substring(0, idx)
  }

  private static joinPath(base: string, name: string): string {
    if (LogStorageService.isUriPath(base)) {
      let queryIndex = base.indexOf('?')
      let fragmentIndex = base.indexOf('#')
      let cutIndex = -1
      if (queryIndex >= 0 && fragmentIndex >= 0) {
        cutIndex = Math.min(queryIndex, fragmentIndex)
      } else if (queryIndex >= 0) {
        cutIndex = queryIndex
      } else if (fragmentIndex >= 0) {
        cutIndex = fragmentIndex
      }

      let prefix = cutIndex >= 0 ? base.substring(0, cutIndex) : base
      let suffix = cutIndex >= 0 ? base.substring(cutIndex) : ''
      if (prefix.endsWith('/')) {
        return `${prefix}${name}${suffix}`
      }
      return `${prefix}/${name}${suffix}`
    }

    if (base.endsWith('/')) {
      return `${base}${name}`
    }
    return `${base}/${name}`
  }

  private static isUriPath(path: string): boolean {
    return path.includes('://')
  }

  private static isFileUri(path: string): boolean {
    return path.startsWith('file://')
  }

  private static normalizeDirectoryPath(path: string): string {
    let normalized = path.replace(/\\/g, '/')
    if (LogStorageService.isFileUri(normalized)) {
      let body = normalized.substring('file://'.length).replace(/\/+$/, '')
      if (body.length === 0) {
        return 'file:///'
      }
      return `file://${body}`
    }

    normalized = normalized.replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : '/'
  }

  private static isDirectoryRoot(path: string): boolean {
    if (path === '/' || path.length === 0) {
      return true
    }
    if (!LogStorageService.isFileUri(path)) {
      return false
    }
    let body = path.substring('file://'.length).replace(/\/+$/, '')
    if (body.length === 0 || body === '/') {
      return true
    }
    return !body.includes('/')
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
      let exportDirectoryUri = await store.get(PREF_KEY_LOG_EXPORT_DOWNLOAD_URI, '') as string
      if (exportDirectoryUri.length === 0) {
        exportDirectoryUri = await store.get(LEGACY_PREF_KEY_LOG_EXPORT_TARGET_VALUE, '') as string
      }
      if (exportDirectoryUri.length === 0) {
        exportDirectoryUri = await store.get(LEGACY_PREF_KEY_LOG_EXPORT_PATH, '') as string
      }

      let retentionDaysNumber = typeof retentionDays === 'number' ? retentionDays : Number(retentionDays as string)
      LogStorageService.storageConfig = LogStorageService.normalizeStorageConfig({
        maxLocalEntries: LogStorageService.normalizeMaxEntries(maxEntries),
        retentionDays: LogStorageService.normalizeRetentionDays(retentionDaysNumber)
      })
      LogStorageService.exportDirectoryUri = LogStorageService.sanitizeExportTargetUri(exportDirectoryUri)

      let legacyExportTargetType = await store.get(LEGACY_PREF_KEY_LOG_EXPORT_TARGET_TYPE, '') as string
      let legacyExportAuthMode = await store.get(LEGACY_PREF_KEY_LOG_EXPORT_AUTH_MODE, '') as string
      if (
        legacyExportTargetType.length > 0 ||
        legacyExportAuthMode.length > 0 ||
        exportDirectoryUri.length > 0
      ) {
        await LogStorageService.saveConfig()
      }
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
      await store.put(PREF_KEY_LOG_EXPORT_DOWNLOAD_URI, LogStorageService.exportDirectoryUri)
      await store.delete(LEGACY_PREF_KEY_LOG_EXPORT_PATH)
      await store.delete(LEGACY_PREF_KEY_LOG_EXPORT_TARGET_TYPE)
      await store.delete(LEGACY_PREF_KEY_LOG_EXPORT_TARGET_VALUE)
      await store.delete(LEGACY_PREF_KEY_LOG_EXPORT_AUTH_MODE)
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveConfig failed: ${JSON.stringify(err)}`)
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

  // Convert to plain text format.
  private static toTxt(entries: LogEntry[]): string {
    let lines: string[] = []

    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      let result = getLogEventResultLabel(entry.result)
      let line = `[${time}] [${type}] [${result}] ${entry.detail}`

      if (entry.processName) {
        line += ` (进程: ${entry.processName})`
      }
      if (entry.filePath) {
        line += ` 路径: ${entry.filePath}`
      }
      if (entry.remoteAddr) {
        line += ` 地址: ${entry.remoteAddr}`
      }

      lines.push(line)
    }

    return lines.join('\n')
  }
}

interface ExportWriteResult {
  success: boolean
  fullPath?: string
  sizeBytes?: number
  errorCode?: number
  errorMessage?: string
}

interface ExportAuthResult {
  success: boolean
  directory?: string
  errorCode?: number
  policyErrorCode?: number
  persistenceForbidden?: boolean
  errorMessage?: string
  recoverAction?: LogExportRecoveryAction
}

interface ResolvedExportTarget {
  directory: string
}
