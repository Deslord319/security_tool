import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import {
  LogEntry,
  LogFilter,
  LogStorageConfig,
  LogStatistics,
  LogEventType,
  LogEventResult,
  LogExportFormat,
  DEFAULT_LOG_STORAGE_CONFIG,
  PREF_STORE_NAME_LOG,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_KEY_LOG_AUTO_EXPORT,
  PREF_KEY_LOG_EXPORT_PATH,
  formatLogTimestamp,
  getLogEventTypeLabel,
  getLogEventResultLabel
} from '../models/DataModels'

const TAG = 'LogStorageService'
const DOMAIN = 0x0007

// 日志数据存储 key
const LOG_DATA_KEY = 'log_entries'

// 日志存储服务 - 负责日志的持久化、查询、过滤、导出
export class LogStorageService {

  private static context: common.UIAbilityContext | null = null
  private static logEntries: LogEntry[] = []
  private static storageConfig: LogStorageConfig = DEFAULT_LOG_STORAGE_CONFIG

  // 初始化（需要 UIAbilityContext 用于 Preferences）
  static async init(context: common.UIAbilityContext): Promise<boolean> {
    try {
      LogStorageService.context = context

      // 加载存储配置
      await LogStorageService.loadConfig()
      // 从持久化存储加载日志
      await LogStorageService.loadEntries()
      // 清理过期日志
      LogStorageService.cleanExpiredEntries()

      hilog.info(DOMAIN, TAG, `Initialized with ${LogStorageService.logEntries.length} entries`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 添加新日志条目
  static async addEntry(entry: LogEntry): Promise<boolean> {
    try {
      LogStorageService.logEntries.unshift(entry) // 新条目在前

      // 超出最大条数时删除旧条目
      if (LogStorageService.logEntries.length > LogStorageService.storageConfig.maxLocalEntries) {
        LogStorageService.logEntries = LogStorageService.logEntries.slice(
          0, LogStorageService.storageConfig.maxLocalEntries
        )
      }

      await LogStorageService.saveEntries()
      hilog.debug(DOMAIN, TAG, `Added entry: ${entry.id}`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addEntry failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 根据过滤条件查询日志
  static queryEntries(filter?: LogFilter): LogEntry[] {
    if (!filter) {
      return LogStorageService.logEntries
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
      if (filter.startTime && entry.timestamp < filter.startTime) {
        return false
      }
      if (filter.endTime && entry.timestamp > filter.endTime) {
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
    let now = Date.now()
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
      LogStorageService.storageConfig = config
      await LogStorageService.saveConfig()
      hilog.info(DOMAIN, TAG, 'Storage config updated')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `updateConfig failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // ========== 内部方法 ==========

  // 从 Preferences 加载日志条目
  private static async loadEntries(): Promise<void> {
    if (!LogStorageService.context) {
      return
    }

    try {
      let store = await preferences.getPreferences(LogStorageService.context, PREF_STORE_NAME_LOG)
      let rawData = await store.get(LOG_DATA_KEY, '[]') as string
      LogStorageService.logEntries = JSON.parse(rawData) as LogEntry[]
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
      await store.put(LOG_DATA_KEY, JSON.stringify(LogStorageService.logEntries))
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
      ) as number
      let autoExport = await store.get(
        PREF_KEY_LOG_AUTO_EXPORT,
        DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
      ) as boolean
      let exportPath = await store.get(PREF_KEY_LOG_EXPORT_PATH, '') as string

      LogStorageService.storageConfig = {
        maxLocalEntries: maxEntries,
        retentionDays: retentionDays,
        autoExportEnabled: autoExport,
        exportPath: exportPath.length > 0 ? exportPath : undefined
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
      if (LogStorageService.storageConfig.exportPath) {
        await store.put(PREF_KEY_LOG_EXPORT_PATH, LogStorageService.storageConfig.exportPath)
      }
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // 清理过期日志条目
  private static cleanExpiredEntries(): void {
    let retentionMs = LogStorageService.storageConfig.retentionDays * 24 * 60 * 60 * 1000
    let cutoff = Date.now() - retentionMs
    let before = LogStorageService.logEntries.length

    LogStorageService.logEntries = LogStorageService.logEntries.filter(
      (e: LogEntry) => e.timestamp >= cutoff
    )

    let removed = before - LogStorageService.logEntries.length
    if (removed > 0) {
      hilog.info(DOMAIN, TAG, `Cleaned ${removed} expired entries`)
    }
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
