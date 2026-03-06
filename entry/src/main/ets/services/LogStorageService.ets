import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
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
  DEFAULT_LOG_STORAGE_CONFIG,
  DEFAULT_SUBSCRIPTION_CONFIG,
  ALL_LOG_EVENT_TYPES,
  PREF_STORE_NAME_LOG,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_KEY_LOG_AUTO_EXPORT,
  PREF_KEY_LOG_EXPORT_PATH,
  PREF_KEY_LOG_SUBSCRIBE_ALL,
  PREF_KEY_LOG_SUBSCRIBED_TYPES,
  formatLogTimestamp,
  getLogEventTypeLabel,
  getLogEventResultLabel
} from '../models/DataModels'

const TAG = 'LogStorageService'
const DOMAIN = 0x0007

// 日志数据存储 key
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
const DEFAULT_EXPORT_DIR_NAME = 'log_exports'

// 日志存储服务 - 负责日志的持久化、查询、过滤、导出
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

  // 初始化（需要 UIAbilityContext 用于 Preferences）
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

      // 加载存储配置
      await LogStorageService.loadConfig()
      // 从持久化存储加载日志
      await LogStorageService.loadEntries()
      // 清理过期日志
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

  // 添加新日志条目
  static async addEntry(entry: LogEntry): Promise<boolean> {
    return LogStorageService.addEntries([entry])
  }

  // 批量添加日志条目（用于高频审计事件，避免每条都落盘）
  static async addEntries(entries: LogEntry[]): Promise<boolean> {
    try {
      if (entries.length === 0) {
        return true
      }

      // 批量归一化后一次性拼接，避免循环头插导致 O(n^2) 退化
      let normalizedBatch = LogStorageService.normalizeEntriesForAppend(entries)
      if (normalizedBatch.length === 0) {
        return true
      }
      LogStorageService.logEntries = normalizedBatch.concat(LogStorageService.logEntries)

      // 超出最大条数时删除旧条目
      let maxEntries = LogStorageService.getEffectiveMaxEntries()
      let overflowCount = LogStorageService.logEntries.length - maxEntries
      if (overflowCount > 0 && LogStorageService.storageConfig.autoExportEnabled) {
        let exportResult = await LogStorageService.exportToFile(
          LogStorageService.logEntries,
          LogExportFormat.JSON,
          'auto'
        )
        if (exportResult.success) {
          hilog.info(
            DOMAIN,
            TAG,
            `Auto export success: ${exportResult.fileName} -> ${exportResult.directory}`
          )
        } else {
          hilog.warn(
            DOMAIN,
            TAG,
            `Auto export failed before truncate: ${exportResult.errorMessage ?? 'unknown error'}`
          )
        }
      }

      if (overflowCount > 0) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(
          0, maxEntries
        )
      }

      await LogStorageService.saveEntries()
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addEntries failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 根据过滤条件查询日志
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
      // 事件类型过滤
      if (filter.eventTypes && filter.eventTypes.length > 0) {
        if (!filter.eventTypes.includes(entry.eventType)) {
          return false
        }
      }

      // 结果过滤
      if (filter.results && filter.results.length > 0) {
        if (!filter.results.includes(entry.result)) {
          return false
        }
      }

      // 时间范围过滤
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

      // 关键字搜索
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

  // 获取日志统计信息
  static getStatistics(): LogStatistics {
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()

    let byType = new Map<LogEventType, number>()
    let todayCount = 0
    let blockedCount = 0

    for (let entry of LogStorageService.logEntries) {
      // 按类型统计
      let count = byType.get(entry.eventType) || 0
      byType.set(entry.eventType, count + 1)

      // 今日统计
      if (entry.timestamp >= todayTimestamp) {
        todayCount++
      }

      // 阻止事件统计
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

  // 清空所有日志
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

  // 删除指定日志条目
  static async deleteEntry(entryId: string): Promise<boolean> {
    try {
      let initialLength = LogStorageService.logEntries.length
      LogStorageService.logEntries = LogStorageService.logEntries.filter(
        (e: LogEntry) => e.id !== entryId
      )

      if (LogStorageService.logEntries.length < initialLength) {
        await LogStorageService.saveEntries()
        hilog.debug(DOMAIN, TAG, `Deleted entry: ${entryId}`)
        return true
      }
      return false
    } catch (err) {
      hilog.error(DOMAIN, TAG, `deleteEntry failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 导出日志为文本
  static exportToString(entries: LogEntry[], format: LogExportFormat): string {
    switch (format) {
      case LogExportFormat.JSON:
        return JSON.stringify(entries, null, 2)

      case LogExportFormat.CSV:
        return LogStorageService.toCsv(entries)

      case LogExportFormat.TXT:
        return LogStorageService.toTxt(entries)

      default:
        return JSON.stringify(entries, null, 2)
    }
  }

  // 导出日志到文件
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
        errorMessage: '没有可导出的日志'
      }
    }

    let content = LogStorageService.exportToString(entries, format)
    let fileName = LogStorageService.buildExportFileName(format, entries.length, now)
    let primaryDir = LogStorageService.resolveConfiguredExportDirectory()
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

    let defaultDir = LogStorageService.resolveDefaultExportDirectoryFromCurrentContext()
    if (defaultDir.length > 0 && defaultDir !== primaryDir) {
      let fallbackWrite = LogStorageService.tryWriteExportFile(defaultDir, fileName, content)
      if (fallbackWrite.success) {
        let fallbackMsg = `配置目录不可写，已降级到默认目录: ${defaultDir}`
        hilog.warn(DOMAIN, TAG, fallbackMsg)
        return {
          count: entries.length,
          format: format,
          timestamp: now,
          trigger: trigger,
          success: true,
          fileName: fileName,
          directory: defaultDir,
          fullPath: fallbackWrite.fullPath,
          sizeBytes: fallbackWrite.sizeBytes,
          errorMessage: fallbackMsg
        }
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

  // 获取默认导出目录
  static getDefaultExportDirectory(context: common.UIAbilityContext): string {
    return LogStorageService.resolveDefaultExportDirectory(context)
  }

  // 设置导出目录
  static async setExportDirectory(path: string): Promise<boolean> {
    let cfg = LogStorageService.getConfig()
    cfg.exportPath = path
    return LogStorageService.updateConfig(cfg)
  }

  // 获取当前条目总数
  static getEntryCount(): number {
    return LogStorageService.logEntries.length
  }

  // 获取存储配置
  static getConfig(): LogStorageConfig {
    let cfg = LogStorageService.storageConfig
    let copy: LogStorageConfig = {
      maxLocalEntries: cfg.maxLocalEntries,
      retentionDays: cfg.retentionDays,
      autoExportEnabled: cfg.autoExportEnabled,
      exportPath: cfg.exportPath
    }
    return copy
  }

  // 更新存储配置
  static async updateConfig(config: LogStorageConfig): Promise<boolean> {
    try {
      LogStorageService.storageConfig = {
        maxLocalEntries: LogStorageService.normalizeMaxEntries(config.maxLocalEntries),
        retentionDays: LogStorageService.normalizeRetentionDays(config.retentionDays),
        autoExportEnabled: LogStorageService.normalizeBoolean(
          config.autoExportEnabled as Object,
          DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
        ),
        exportPath: LogStorageService.sanitizeConfiguredExportDirectory(config.exportPath)
      }
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

  // 加载日志订阅配置
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

  // 保存日志订阅配置
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

  // ========== 内部方法 ==========

  // 过滤非法事件类型并去重
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

  private static normalizeExportDirectory(path: string | undefined): string | undefined {
    if (!path) {
      return undefined
    }

    let normalized = path.trim()
    if (normalized.length === 0) {
      return undefined
    }

    normalized = normalized.replace(/\\/g, '/')
    if (normalized.startsWith('file://')) {
      normalized = normalized.substring('file://'.length)
    }
    let queryIndex = normalized.indexOf('?')
    if (queryIndex >= 0) {
      normalized = normalized.substring(0, queryIndex)
    }
    try {
      normalized = decodeURIComponent(normalized)
    } catch (_err) {
    }
    normalized = normalized.replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : undefined
  }

  private static sanitizeConfiguredExportDirectory(path: string | undefined): string | undefined {
    let normalized = LogStorageService.normalizeExportDirectory(path)
    if (!normalized) {
      return undefined
    }
    if (!LogStorageService.isExportDirectoryAllowed(normalized)) {
      hilog.warn(DOMAIN, TAG, `exportPath is outside app sandbox, fallback to default: ${normalized}`)
      return undefined
    }
    return normalized
  }

  private static normalizePathForCompare(path: string): string {
    let normalized = path.replace(/\\/g, '/').replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : '/'
  }

  private static isSameOrChildPath(path: string, root: string): boolean {
    let normalizedPath = LogStorageService.normalizePathForCompare(path).toLowerCase()
    let normalizedRoot = LogStorageService.normalizePathForCompare(root).toLowerCase()
    return normalizedPath === normalizedRoot || normalizedPath.startsWith(`${normalizedRoot}/`)
  }

  private static isExportDirectoryAllowed(path: string): boolean {
    if (path.length === 0 || path.includes('\0')) {
      return false
    }

    let normalized = LogStorageService.normalizePathForCompare(path)
    let parts = normalized.split('/')
    for (let part of parts) {
      if (part === '..') {
        return false
      }
    }

    if (!LogStorageService.context) {
      return true
    }

    let filesDir = LogStorageService.context.filesDir || ''
    if (filesDir.length === 0) {
      return true
    }
    return LogStorageService.isSameOrChildPath(normalized, filesDir)
  }

  private static resolveDefaultExportDirectory(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${DEFAULT_EXPORT_DIR_NAME}`
  }

  private static resolveDefaultExportDirectoryFromCurrentContext(): string {
    if (!LogStorageService.context) {
      return ''
    }
    return LogStorageService.resolveDefaultExportDirectory(LogStorageService.context)
  }

  private static resolveConfiguredExportDirectory(): string {
    let configured = LogStorageService.sanitizeConfiguredExportDirectory(LogStorageService.storageConfig.exportPath)
    if (configured && configured.length > 0) {
      return configured
    }
    return LogStorageService.resolveDefaultExportDirectoryFromCurrentContext()
  }

  private static buildExportFileName(format: LogExportFormat, count: number, timestamp: number): string {
    let date = new Date(timestamp)
    let pad = (n: number): string => n.toString().padStart(2, '0')
    let datePart = `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`
    let timePart = `${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
    return `security_log_${datePart}_${timePart}_${count}.${format}`
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

    let fullPath = LogStorageService.joinPath(directory, fileName)
    let file: fileIo.File | undefined = undefined
    try {
      LogStorageService.ensureDirectoryExists(directory)
      file = fileIo.openSync(
        fullPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      )
      fileIo.writeSync(file.fd, content)
      fileIo.closeSync(file)
      file = undefined

      let stat = fileIo.statSync(fullPath)
      return {
        success: true,
        fullPath: fullPath,
        sizeBytes: stat.size
      }
    } catch (err) {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (_closeErr) {
        }
      }
      try {
        let code = LogStorageService.extractErrorCode(err as Object)
        let msg = `写入导出文件失败: ${JSON.stringify(err)}`
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
    if (path.length === 0 || path === '/') {
      return
    }

    let normalized = path.replace(/\\/g, '/').replace(/\/+$/, '')
    if (normalized.length === 0 || normalized === '/') {
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
      // 目录可能由并发流程创建，再次校验即可
      let stat = fileIo.statSync(normalized)
      if (!stat.isDirectory()) {
        throw new Error(`Failed to create directory: ${normalized}`)
      }
    }
  }

  private static getParentDirectory(path: string): string {
    let normalized = path.replace(/\\/g, '/').replace(/\/+$/, '')
    if (normalized.length === 0 || normalized === '/') {
      return ''
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
    if (base.endsWith('/')) {
      return `${base}${name}`
    }
    return `${base}/${name}`
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

  // 归一化最大存储条数，避免过大导致内存峰值
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

  private static normalizeBoolean(value: Object, fallback: boolean): boolean {
    if (typeof value === 'boolean') {
      return value
    }
    if (typeof value === 'number') {
      if (value === 1) {
        return true
      }
      if (value === 0) {
        return false
      }
      return fallback
    }
    if (typeof value === 'string') {
      let normalized = value.trim().toLowerCase()
      if (normalized === 'true' || normalized === '1' || normalized === 'yes' || normalized === 'on') {
        return true
      }
      if (normalized === 'false' || normalized === '0' || normalized === 'no' || normalized === 'off') {
        return false
      }
    }
    return fallback
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

  // 生效的内存上限
  private static getEffectiveMaxEntries(): number {
    return LogStorageService.normalizeMaxEntries(LogStorageService.storageConfig.maxLocalEntries)
  }

  // 截断超长字符串，防止单条日志过大
  private static truncateString(value: string | undefined, limit: number): string | undefined {
    if (value === undefined) {
      return undefined
    }
    if (value.length <= limit) {
      return value
    }
    return `${value.substring(0, limit)}...`
  }

  // 单条日志瘦身
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

    // 归一化后反转，保证最终“最新在前”
    normalizedBatch.reverse()
    return normalizedBatch
  }

  // 批量日志瘦身并过滤异常项
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

  // 构建可安全落盘的 payload（按条数和内容大小双重裁剪）
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

  // 限频输出裁剪日志，避免高频事件下日志风暴
  private static warnPersistTruncate(memoryCount: number, savedCount: number): void {
    let now = LogStorageService.nowProvider()
    if (now - LogStorageService.lastPersistTruncateWarnAt < 10000) {
      return
    }
    LogStorageService.lastPersistTruncateWarnAt = now
    hilog.warn(DOMAIN, TAG, `Persist entries truncated: memory=${memoryCount}, saved=${savedCount}`)
  }

  // 从 Preferences 加载日志条目
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

  // 持久化日志条目到 Preferences
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

  // 加载存储配置
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
      let autoExport = await store.get(
        PREF_KEY_LOG_AUTO_EXPORT,
        DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
      ) as Object
      let exportPath = await store.get(PREF_KEY_LOG_EXPORT_PATH, '') as string

      let retentionDaysNumber = typeof retentionDays === 'number' ? retentionDays : Number(retentionDays as string)
      LogStorageService.storageConfig = {
        maxLocalEntries: LogStorageService.normalizeMaxEntries(maxEntries),
        retentionDays: LogStorageService.normalizeRetentionDays(retentionDaysNumber),
        autoExportEnabled: LogStorageService.normalizeBoolean(
          autoExport,
          DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
        ),
        exportPath: LogStorageService.sanitizeConfiguredExportDirectory(exportPath)
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // 保存存储配置
  private static async saveConfig(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      await store.put(PREF_KEY_LOG_MAX_ENTRIES, LogStorageService.storageConfig.maxLocalEntries)
      await store.put(PREF_KEY_LOG_RETENTION_DAYS, LogStorageService.storageConfig.retentionDays)
      await store.put(PREF_KEY_LOG_AUTO_EXPORT, LogStorageService.storageConfig.autoExportEnabled)
      await store.put(
        PREF_KEY_LOG_EXPORT_PATH,
        LogStorageService.storageConfig.exportPath ?? ''
      )
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // 清理过期日志条目
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

  // 转换为 CSV 格式
  private static toCsv(entries: LogEntry[]): string {
    let header = '时间,事件类型,详情,进程名,PID,结果'
    let lines: string[] = [header]

    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      // CSV 中双引号转义
      let detail = `"${entry.detail.replace(/"/g, '""')}"`
      let process = entry.processName || ''
      let pid = entry.pid !== undefined ? entry.pid.toString() : ''
      let result = getLogEventResultLabel(entry.result)

      lines.push(`${time},${type},${detail},${process},${pid},${result}`)
    }

    return lines.join('\n')
  }

  // 转换为纯文本格式
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
