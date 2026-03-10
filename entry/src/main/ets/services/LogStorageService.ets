import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { Environment, fileIo, fileShare } from '@kit.CoreFileKit'
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
  LogExportTargetType,
  LogExportAuthMode,
  DEFAULT_LOG_STORAGE_CONFIG,
  DEFAULT_SUBSCRIPTION_CONFIG,
  ALL_LOG_EVENT_TYPES,
  PREF_STORE_NAME_LOG,
  PREF_KEY_LOG_MAX_ENTRIES,
  PREF_KEY_LOG_RETENTION_DAYS,
  PREF_KEY_LOG_AUTO_EXPORT,
  PREF_KEY_LOG_EXPORT_PATH,
  PREF_KEY_LOG_EXPORT_TARGET_TYPE,
  PREF_KEY_LOG_EXPORT_TARGET_VALUE,
  PREF_KEY_LOG_EXPORT_AUTH_MODE,
  PREF_KEY_LOG_SUBSCRIBE_ALL,
  PREF_KEY_LOG_SUBSCRIBED_TYPES,
  formatLogTimestamp,
  getLogEventTypeLabel,
  getLogEventResultLabel
} from '../models/DataModels'

const TAG = 'LogStorageService'
const DOMAIN = 0x0007

// 鏃ュ織鏁版嵁瀛樺偍 key
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
const DEFAULT_EXPORT_PARENT_DIR_NAME = 'SecurityTool'
const EXPORT_TARGET_DOWNLOAD: LogExportTargetType = 'download'
const EXPORT_TARGET_DOCUMENTS: LogExportTargetType = 'documents'
const EXPORT_TARGET_DESKTOP: LogExportTargetType = 'desktop'
const EXPORT_TARGET_CUSTOM_URI: LogExportTargetType = 'custom_uri'
const EXPORT_AUTH_RUNTIME: LogExportAuthMode = 'runtime_permission'
const EXPORT_AUTH_PERSISTED: LogExportAuthMode = 'persisted_uri'
const PERSIST_URI_OPERATION_MODE: number =
  fileShare.OperationMode.READ_MODE |
  fileShare.OperationMode.WRITE_MODE |
  fileShare.OperationMode.CREATE_MODE

// 鏃ュ織瀛樺偍鏈嶅姟 - 璐熻矗鏃ュ織鐨勬寔涔呭寲銆佹煡璇€佽繃婊ゃ€佸鍑?
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

  // 鍒濆鍖栵紙闇€瑕?UIAbilityContext 鐢ㄤ簬 Preferences锛?
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

      // 鍔犺浇瀛樺偍閰嶇疆
      await LogStorageService.loadConfig()
      await LogStorageService.tryActivateConfiguredExportTarget()
      await LogStorageService.loadEntries()
      // 娓呯悊杩囨湡鏃ュ織
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

  // 娣诲姞鏂版棩蹇楁潯鐩?
  static async addEntry(entry: LogEntry): Promise<boolean> {
    return LogStorageService.addEntries([entry])
  }

  // 鎵归噺娣诲姞鏃ュ織鏉＄洰锛堢敤浜庨珮棰戝璁′簨浠讹紝閬垮厤姣忔潯閮借惤鐩橈級
  static async addEntries(entries: LogEntry[]): Promise<boolean> {
    try {
      if (entries.length === 0) {
        return true
      }

      // 鎵归噺褰掍竴鍖栧悗涓€娆℃€ф嫾鎺ワ紝閬垮厤寰幆澶存彃瀵艰嚧 O(n^2) 閫€鍖?
      let normalizedBatch = LogStorageService.normalizeEntriesForAppend(entries)
      if (normalizedBatch.length === 0) {
        return true
      }
      LogStorageService.logEntries = normalizedBatch.concat(LogStorageService.logEntries)

      // 瓒呭嚭鏈€澶ф潯鏁版椂鍒犻櫎鏃ф潯鐩?
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

  // 鏍规嵁杩囨护鏉′欢鏌ヨ鏃ュ織
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
      // 浜嬩欢绫诲瀷杩囨护
      if (filter.eventTypes && filter.eventTypes.length > 0) {
        if (!filter.eventTypes.includes(entry.eventType)) {
          return false
        }
      }

      // 缁撴灉杩囨护
      if (filter.results && filter.results.length > 0) {
        if (!filter.results.includes(entry.result)) {
          return false
        }
      }

      // 鏃堕棿鑼冨洿杩囨护
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

      // 鍏抽敭瀛楁悳绱?
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

  // 鑾峰彇鏃ュ織缁熻淇℃伅
  static getStatistics(): LogStatistics {
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()

    let byType = new Map<LogEventType, number>()
    let todayCount = 0
    let blockedCount = 0

    for (let entry of LogStorageService.logEntries) {
      // 鎸夌被鍨嬬粺璁?
      let count = byType.get(entry.eventType) || 0
      byType.set(entry.eventType, count + 1)

      // 浠婃棩缁熻
      if (entry.timestamp >= todayTimestamp) {
        todayCount++
      }

      // 闃绘浜嬩欢缁熻
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

  // 娓呯┖鎵€鏈夋棩蹇?
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

  // 鍒犻櫎鎸囧畾鏃ュ織鏉＄洰
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

  // 瀵煎嚭鏃ュ織涓烘枃鏈?
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

  // 瀵煎嚭鏃ュ織鍒版枃浠?
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
        errorMessage: '娌℃湁鍙鍑虹殑鏃ュ織'
      }
    }

    let content = LogStorageService.exportToString(entries, format)
    let fileName = LogStorageService.buildExportFileName(format, entries.length, now)
    let primaryTarget = LogStorageService.resolveConfiguredExportDirectory()
    let primaryDir = primaryTarget.directory
    let activateMessage = ''
    if (primaryTarget.targetType === EXPORT_TARGET_CUSTOM_URI) {
      let activateResult = await LogStorageService.activateCustomUriPermission(primaryDir)
      if (!activateResult.success) {
        activateMessage = activateResult.errorMessage || '自定义目录授权失效'
        hilog.warn(DOMAIN, TAG, `activate custom uri failed, fallback to default: ${activateMessage}`)
      }
    }
    let primaryWrite = activateMessage.length > 0
      ? {
        success: false,
        errorCode: 13900001,
        errorMessage: activateMessage
      } as ExportWriteResult
      : LogStorageService.tryWriteExportFile(primaryDir, fileName, content)

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
        let fallbackMsg = `配置目录不可写，已回退到默认目录: ${defaultDir}`
        hilog.warn(DOMAIN, TAG, fallbackMsg)
        if (primaryTarget.targetType === EXPORT_TARGET_CUSTOM_URI) {
          await LogStorageService.fallbackToDefaultExportTarget()
        }
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

  // 鑾峰彇榛樿瀵煎嚭鐩綍
  static getDefaultExportDirectory(context: common.UIAbilityContext): string {
    return LogStorageService.resolveDefaultExportDirectory(context)
  }

  static getPublicExportDirectory(targetType: LogExportTargetType): string {
    return LogStorageService.resolvePublicDirectoryByType(targetType) || ''
  }

  static resolvePublicTargetType(pathOrUri: string): LogExportTargetType | undefined {
    return LogStorageService.resolvePublicTargetTypeByPath(pathOrUri)
  }

  static normalizeCustomExportUri(pathOrUri: string): string | undefined {
    return LogStorageService.normalizeCustomUriInput(pathOrUri)
  }

  private static getPublicDirectoryPermission(targetType: LogExportTargetType): Permissions | undefined {
    if (targetType === EXPORT_TARGET_DOWNLOAD) {
      return 'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY' as Permissions
    }
    if (targetType === EXPORT_TARGET_DOCUMENTS) {
      return 'ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY' as Permissions
    }
    if (targetType === EXPORT_TARGET_DESKTOP) {
      return 'ohos.permission.READ_WRITE_DESKTOP_DIRECTORY' as Permissions
    }
    return undefined
  }

  static async ensurePublicDirectoryPermission(
    context: common.UIAbilityContext,
    targetType: LogExportTargetType
  ): Promise<ExportAuthResult> {
    let permission = LogStorageService.getPublicDirectoryPermission(targetType)
    if (!permission) {
      return { success: true }
    }

    try {
      let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
      let grantResult = await atManager.requestPermissionsFromUser(context, [permission])
      if (grantResult.authResults.length === 0) {
        return {
          success: false,
          errorMessage: `权限未授予: ${permission}`
        }
      }

      let granted = grantResult.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      if (granted) {
        return { success: true }
      }
      return {
        success: false,
        errorMessage: `用户拒绝权限: ${permission}`
      }
    } catch (err) {
      return {
        success: false,
        errorCode: LogStorageService.extractErrorCode(err as Object),
        errorMessage: `申请目录权限失败: ${JSON.stringify(err)}`
      }
    }
  }

  static async persistCustomUriPermission(uri: string): Promise<ExportAuthResult> {
    let normalized = LogStorageService.normalizeCustomUriInput(uri)
    if (!normalized) {
      return {
        success: false,
        errorMessage: '无效的自定义目录URI'
      }
    }

    let publicType = LogStorageService.resolvePublicTargetTypeByPath(normalized)
    if (publicType) {
      return {
        success: false,
        errorCode: 13900001,
        errorMessage: '公共目录不支持持久化授权，请切换为下载/文档/桌面目录并通过权限弹窗授权。'
      }
    }

    let policies: fileShare.PolicyInfo[] = [{
      uri: normalized,
      operationMode: PERSIST_URI_OPERATION_MODE
    } as fileShare.PolicyInfo]
    try {
      await fileShare.persistPermission(policies)
      return { success: true }
    } catch (err) {
      let message = `持久化目录授权失败: ${JSON.stringify(err)}`
      hilog.warn(DOMAIN, TAG, message)
      return {
        success: false,
        errorCode: LogStorageService.extractErrorCode(err as Object),
        errorMessage: message
      }
    }
  }

  static async activateCustomUriPermission(uri: string): Promise<ExportAuthResult> {
    let normalized = LogStorageService.normalizeCustomUriInput(uri)
    if (!normalized) {
      return {
        success: false,
        errorMessage: '无效的自定义目录URI'
      }
    }

    let publicType = LogStorageService.resolvePublicTargetTypeByPath(normalized)
    if (publicType) {
      return {
        success: false,
        errorCode: 13900001,
        errorMessage: '公共目录无需持久化授权，请改用目录权限弹窗授权。'
      }
    }

    let policies: fileShare.PolicyInfo[] = [{
      uri: normalized,
      operationMode: PERSIST_URI_OPERATION_MODE
    } as fileShare.PolicyInfo]

    try {
      let persisted = await LogStorageService.checkCustomUriPersistentPermission(normalized)
      if (!persisted) {
        let persistResult = await LogStorageService.persistCustomUriPermission(normalized)
        if (!persistResult.success) {
          return persistResult
        }
      }

      await fileShare.activatePermission(policies)
      return { success: true }
    } catch (err) {
      let message = `激活目录授权失败: ${JSON.stringify(err)}`
      hilog.warn(DOMAIN, TAG, message)
      return {
        success: false,
        errorCode: LogStorageService.extractErrorCode(err as Object),
        errorMessage: message
      }
    }
  }

  // 璁剧疆瀵煎嚭鐩綍
  static async setExportDirectory(path: string): Promise<boolean> {
    let cfg = LogStorageService.getConfig()
    let publicType = LogStorageService.resolvePublicTargetTypeByPath(path)
    if (publicType) {
      cfg.exportTargetType = publicType
      cfg.exportTargetValue = ''
      cfg.exportAuthMode = EXPORT_AUTH_RUNTIME
      cfg.exportPath = LogStorageService.resolvePublicDirectoryByType(publicType) || cfg.exportPath
      return LogStorageService.updateConfig(cfg)
    }

    let customUri = LogStorageService.normalizeCustomUriInput(path)
    if (customUri) {
      cfg.exportPath = customUri
      cfg.exportTargetType = EXPORT_TARGET_CUSTOM_URI
      cfg.exportTargetValue = customUri
      cfg.exportAuthMode = EXPORT_AUTH_PERSISTED
      return LogStorageService.updateConfig(cfg)
    }

    let normalizedPath = LogStorageService.sanitizeConfiguredExportDirectory(path)
    let legacyType = normalizedPath ? LogStorageService.resolveLegacyPublicTargetType(normalizedPath) : undefined
    if (legacyType) {
      cfg.exportTargetType = legacyType
      cfg.exportTargetValue = ''
      cfg.exportAuthMode = EXPORT_AUTH_RUNTIME
      cfg.exportPath = LogStorageService.resolvePublicDirectoryByType(legacyType) || normalizedPath
    } else {
      cfg = LogStorageService.createDefaultTargetConfig(cfg)
    }
    return LogStorageService.updateConfig(cfg)
  }

  // 鑾峰彇褰撳墠鏉＄洰鎬绘暟
  static getEntryCount(): number {
    return LogStorageService.logEntries.length
  }

  // 鑾峰彇瀛樺偍閰嶇疆
  static getConfig(): LogStorageConfig {
    let cfg = LogStorageService.storageConfig
    let copy: LogStorageConfig = {
      maxLocalEntries: cfg.maxLocalEntries,
      retentionDays: cfg.retentionDays,
      autoExportEnabled: cfg.autoExportEnabled,
      exportPath: cfg.exportPath,
      exportTargetType: cfg.exportTargetType,
      exportTargetValue: cfg.exportTargetValue,
      exportAuthMode: cfg.exportAuthMode
    }
    return copy
  }

  // 鏇存柊瀛樺偍閰嶇疆
  static async updateConfig(config: LogStorageConfig): Promise<boolean> {
    try {
      let normalizedConfig = LogStorageService.normalizeStorageConfig(config)
      if (normalizedConfig.exportTargetType === EXPORT_TARGET_CUSTOM_URI) {
        let targetUri = normalizedConfig.exportTargetValue || ''
        let authResult = await LogStorageService.activateCustomUriPermission(targetUri)
        if (!authResult.success) {
          hilog.warn(DOMAIN, TAG, `custom uri not available, fallback to default: ${authResult.errorMessage}`)
          normalizedConfig = LogStorageService.createDefaultTargetConfig(normalizedConfig)
        }
      }

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

  // 鍔犺浇鏃ュ織璁㈤槄閰嶇疆
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

  // 淇濆瓨鏃ュ織璁㈤槄閰嶇疆
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

  // ========== 鍐呴儴鏂规硶 ==========

  // 杩囨护闈炴硶浜嬩欢绫诲瀷骞跺幓閲?
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

    if (LogStorageService.isUriPath(normalized)) {
      return LogStorageService.sanitizeCustomUri(normalized)
    }

    normalized = normalized.replace(/\\/g, '/').replace(/\/+$/, '')
    if (normalized.length === 0 || normalized === '/') {
      return undefined
    }
    return normalized
  }

  private static sanitizeConfiguredExportDirectory(path: string | undefined): string | undefined {
    let normalized = LogStorageService.normalizeExportDirectory(path)
    if (!normalized) {
      return undefined
    }
    if (LogStorageService.isUriPath(normalized)) {
      return normalized
    }
    if (!LogStorageService.isExportDirectoryAllowed(normalized)) {
      hilog.warn(DOMAIN, TAG, `exportPath is invalid, fallback to default: ${normalized}`)
      return undefined
    }
    return normalized
  }

  private static sanitizeCustomUri(uri: string | undefined): string | undefined {
    if (!uri) {
      return undefined
    }

    let normalized = uri.trim()
    if (normalized.length === 0 || normalized.includes('\0')) {
      return undefined
    }
    if (!LogStorageService.isUriPath(normalized)) {
      return undefined
    }

    if (!normalized.includes('?') && !normalized.includes('#')) {
      normalized = normalized.replace(/\/+$/, '')
    }
    return normalized.length > 0 ? normalized : undefined
  }

  private static normalizePathForCompare(path: string): string {
    if (LogStorageService.isUriPath(path)) {
      let normalized = path.trim().replace(/\\/g, '/').replace(/\/+$/, '')
      let idx = normalized.indexOf('://')
      let schema = normalized.substring(0, idx).toLowerCase()
      let body = normalized.substring(idx + 3)
      return `${schema}://${body}`
    }

    let normalized = path.replace(/\\/g, '/').replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : '/'
  }

  private static normalizeSelectionPath(pathOrUri: string | undefined): string | undefined {
    if (!pathOrUri) {
      return undefined
    }

    let normalized = pathOrUri.trim()
    if (normalized.length === 0) {
      return undefined
    }

    if (LogStorageService.isFileUri(normalized)) {
      normalized = normalized.substring('file://'.length)
    } else if (LogStorageService.isUriPath(normalized)) {
      return undefined
    }

    try {
      normalized = decodeURIComponent(normalized)
    } catch (_err) {
    }

    normalized = normalized.replace(/\\/g, '/').replace(/\/+$/, '')
    if (normalized.length === 0) {
      return undefined
    }
    return normalized
  }

  private static normalizeCustomUriInput(uri: string | undefined): string | undefined {
    let normalizedUri = LogStorageService.sanitizeCustomUri(uri)
    if (normalizedUri) {
      return normalizedUri
    }

    let normalizedPath = LogStorageService.normalizeSelectionPath(uri)
    if (!normalizedPath || !normalizedPath.startsWith('/')) {
      return undefined
    }
    return `file://${normalizedPath}`
  }

  private static resolvePublicTargetTypeByPath(pathOrUri: string | undefined): LogExportTargetType | undefined {
    let selectedPath = LogStorageService.normalizeSelectionPath(pathOrUri)
    if (!selectedPath) {
      return undefined
    }

    let selectedNormalized = LogStorageService.normalizePathForCompare(selectedPath)
    let candidates: LogExportTargetType[] = [
      EXPORT_TARGET_DOWNLOAD,
      EXPORT_TARGET_DOCUMENTS,
      EXPORT_TARGET_DESKTOP
    ]
    for (let candidate of candidates) {
      let baseDir = LogStorageService.resolvePublicBaseDirectoryByType(candidate)
      if (!baseDir) {
        continue
      }
      let baseNormalized = LogStorageService.normalizePathForCompare(baseDir)
      if (
        selectedNormalized === baseNormalized ||
        selectedNormalized.startsWith(`${baseNormalized}/`)
      ) {
        return candidate
      }
    }
    return undefined
  }

  private static isExportDirectoryAllowed(path: string): boolean {
    if (path.length === 0 || path.includes('\0')) {
      return false
    }

    if (LogStorageService.isUriPath(path)) {
      return true
    }

    let normalized = LogStorageService.normalizePathForCompare(path)
    if (normalized.length === 0 || normalized === '/') {
      return false
    }

    let parts = normalized.split('/')
    for (let part of parts) {
      if (part === '..') {
        return false
      }
    }

    return normalized.startsWith('/')
  }

  private static normalizeTargetType(
    targetType: LogExportTargetType | string | undefined
  ): LogExportTargetType | undefined {
    if (
      targetType === EXPORT_TARGET_DOWNLOAD ||
      targetType === EXPORT_TARGET_DOCUMENTS ||
      targetType === EXPORT_TARGET_DESKTOP ||
      targetType === EXPORT_TARGET_CUSTOM_URI
    ) {
      return targetType
    }
    return undefined
  }

  private static resolveLegacyPublicTargetType(path: string): LogExportTargetType | undefined {
    let current = LogStorageService.normalizePathForCompare(path)
    let candidates: LogExportTargetType[] = [
      EXPORT_TARGET_DOWNLOAD,
      EXPORT_TARGET_DOCUMENTS,
      EXPORT_TARGET_DESKTOP
    ]
    for (let item of candidates) {
      let expected = LogStorageService.resolvePublicDirectoryByType(item)
      if (!expected) {
        continue
      }
      let expectedNormalized = LogStorageService.normalizePathForCompare(expected)
      if (current === expectedNormalized || current.startsWith(`${expectedNormalized}/`)) {
        return item
      }
    }
    return undefined
  }

  private static createDefaultTargetConfig(baseConfig?: LogStorageConfig): LogStorageConfig {
    let maxLocalEntries = LogStorageService.normalizeMaxEntries(
      baseConfig?.maxLocalEntries ?? DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries
    )
    let retentionDays = LogStorageService.normalizeRetentionDays(
      baseConfig?.retentionDays ?? DEFAULT_LOG_STORAGE_CONFIG.retentionDays
    )
    let autoExportEnabled = LogStorageService.normalizeBoolean(
      baseConfig?.autoExportEnabled as Object,
      DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
    )

    let exportPath = LogStorageService.resolvePublicDirectoryByType(EXPORT_TARGET_DOWNLOAD)
    if (!exportPath || exportPath.length === 0) {
      exportPath = LogStorageService.resolveDefaultExportDirectoryFromCurrentContext()
    }

    return {
      maxLocalEntries: maxLocalEntries,
      retentionDays: retentionDays,
      autoExportEnabled: autoExportEnabled,
      exportPath: exportPath,
      exportTargetType: EXPORT_TARGET_DOWNLOAD,
      exportTargetValue: '',
      exportAuthMode: EXPORT_AUTH_RUNTIME
    }
  }

  private static normalizeStorageConfig(config: LogStorageConfig): LogStorageConfig {
    let baseConfig: LogStorageConfig = {
      maxLocalEntries: LogStorageService.normalizeMaxEntries(config.maxLocalEntries),
      retentionDays: LogStorageService.normalizeRetentionDays(config.retentionDays),
      autoExportEnabled: LogStorageService.normalizeBoolean(
        config.autoExportEnabled as Object,
        DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
      )
    }

    let normalizedType = LogStorageService.normalizeTargetType(config.exportTargetType)
    let targetValue = config.exportTargetValue
    let legacyPath = LogStorageService.sanitizeConfiguredExportDirectory(config.exportPath)
    if (!normalizedType) {
      if (legacyPath && LogStorageService.isUriPath(legacyPath)) {
        normalizedType = EXPORT_TARGET_CUSTOM_URI
        targetValue = legacyPath
      } else if (legacyPath) {
        normalizedType = LogStorageService.resolveLegacyPublicTargetType(legacyPath) ?? EXPORT_TARGET_DOWNLOAD
      } else {
        normalizedType = EXPORT_TARGET_DOWNLOAD
      }
    }

    if (normalizedType === EXPORT_TARGET_CUSTOM_URI) {
      let customUri = LogStorageService.normalizeCustomUriInput(targetValue || legacyPath)
      if (!customUri) {
        return LogStorageService.createDefaultTargetConfig(baseConfig)
      }

      let publicType = LogStorageService.resolvePublicTargetTypeByPath(customUri)
      if (publicType) {
        let publicPath = LogStorageService.resolvePublicDirectoryByType(publicType)
        if (!publicPath || publicPath.length === 0) {
          return LogStorageService.createDefaultTargetConfig(baseConfig)
        }
        return {
          maxLocalEntries: baseConfig.maxLocalEntries,
          retentionDays: baseConfig.retentionDays,
          autoExportEnabled: baseConfig.autoExportEnabled,
          exportPath: publicPath,
          exportTargetType: publicType,
          exportTargetValue: '',
          exportAuthMode: EXPORT_AUTH_RUNTIME
        }
      }

      return {
        maxLocalEntries: baseConfig.maxLocalEntries,
        retentionDays: baseConfig.retentionDays,
        autoExportEnabled: baseConfig.autoExportEnabled,
        exportPath: customUri,
        exportTargetType: EXPORT_TARGET_CUSTOM_URI,
        exportTargetValue: customUri,
        exportAuthMode: EXPORT_AUTH_PERSISTED
      }
    }

    let publicPath = LogStorageService.resolvePublicDirectoryByType(normalizedType)
    if (!publicPath || publicPath.length === 0) {
      return LogStorageService.createDefaultTargetConfig(baseConfig)
    }

    return {
      maxLocalEntries: baseConfig.maxLocalEntries,
      retentionDays: baseConfig.retentionDays,
      autoExportEnabled: baseConfig.autoExportEnabled,
      exportPath: publicPath,
      exportTargetType: normalizedType,
      exportTargetValue: '',
      exportAuthMode: EXPORT_AUTH_RUNTIME
    }
  }

  private static resolveDefaultExportDirectory(context: common.UIAbilityContext): string {
    let publicDefault = LogStorageService.resolvePublicDirectoryByType(EXPORT_TARGET_DOWNLOAD)
    if (publicDefault && publicDefault.length > 0) {
      return publicDefault
    }

    return LogStorageService.joinPath(context.filesDir, DEFAULT_EXPORT_DIR_NAME)
  }

  private static resolvePublicDirectoryByType(targetType: LogExportTargetType): string | undefined {
    let normalizedBase = LogStorageService.resolvePublicBaseDirectoryByType(targetType)
    if (!normalizedBase) {
      return undefined
    }

    return LogStorageService.joinPath(
      LogStorageService.joinPath(normalizedBase, DEFAULT_EXPORT_PARENT_DIR_NAME),
      DEFAULT_EXPORT_DIR_NAME
    )
  }

  private static resolvePublicBaseDirectoryByType(targetType: LogExportTargetType): string | undefined {
    if (targetType === EXPORT_TARGET_CUSTOM_URI) {
      return undefined
    }

    let baseDir = ''
    try {
      if (targetType === EXPORT_TARGET_DOWNLOAD) {
        baseDir = Environment.getUserDownloadDir()
      } else if (targetType === EXPORT_TARGET_DOCUMENTS) {
        baseDir = Environment.getUserDocumentDir()
      } else if (targetType === EXPORT_TARGET_DESKTOP) {
        baseDir = Environment.getUserDesktopDir()
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `resolve public directory failed: type=${targetType}, error=${JSON.stringify(err)}`)
      return undefined
    }

    let normalized = LogStorageService.normalizeExportDirectory(baseDir)
    if (!normalized || LogStorageService.isUriPath(normalized)) {
      return undefined
    }
    return normalized
  }

  private static resolveDefaultExportDirectoryFromCurrentContext(): string {
    if (!LogStorageService.context) {
      return ''
    }
    return LogStorageService.resolveDefaultExportDirectory(LogStorageService.context)
  }

  private static resolveConfiguredExportDirectory(): ResolvedExportTarget {
    let normalizedConfig = LogStorageService.normalizeStorageConfig(LogStorageService.storageConfig)
    let targetType = normalizedConfig.exportTargetType ?? EXPORT_TARGET_DOWNLOAD

    if (targetType === EXPORT_TARGET_CUSTOM_URI) {
      let customUri = LogStorageService.sanitizeCustomUri(normalizedConfig.exportTargetValue)
      if (customUri) {
        return {
          targetType: EXPORT_TARGET_CUSTOM_URI,
          authMode: EXPORT_AUTH_PERSISTED,
          directory: customUri
        }
      }
    }

    let publicPath = LogStorageService.resolvePublicDirectoryByType(targetType)
    if (publicPath && publicPath.length > 0) {
      return {
        targetType: targetType,
        authMode: EXPORT_AUTH_RUNTIME,
        directory: publicPath
      }
    }

    let fallback = LogStorageService.resolveDefaultExportDirectoryFromCurrentContext()
    return {
      targetType: EXPORT_TARGET_DOWNLOAD,
      authMode: EXPORT_AUTH_RUNTIME,
      directory: fallback
    }
  }

  private static async tryActivateConfiguredExportTarget(): Promise<void> {
    let resolvedTarget = LogStorageService.resolveConfiguredExportDirectory()
    if (resolvedTarget.targetType !== EXPORT_TARGET_CUSTOM_URI) {
      if (LogStorageService.storageConfig.exportPath !== resolvedTarget.directory) {
        LogStorageService.storageConfig = LogStorageService.normalizeStorageConfig(LogStorageService.storageConfig)
        await LogStorageService.saveConfig()
      }
      return
    }

    let authResult = await LogStorageService.activateCustomUriPermission(resolvedTarget.directory)
    if (!authResult.success) {
      hilog.warn(DOMAIN, TAG, `configured custom uri invalid, fallback to default: ${authResult.errorMessage}`)
      await LogStorageService.fallbackToDefaultExportTarget()
      return
    }

    if (
      LogStorageService.storageConfig.exportPath !== resolvedTarget.directory ||
      LogStorageService.storageConfig.exportTargetValue !== resolvedTarget.directory
    ) {
      LogStorageService.storageConfig.exportPath = resolvedTarget.directory
      LogStorageService.storageConfig.exportTargetType = EXPORT_TARGET_CUSTOM_URI
      LogStorageService.storageConfig.exportTargetValue = resolvedTarget.directory
      LogStorageService.storageConfig.exportAuthMode = EXPORT_AUTH_PERSISTED
      await LogStorageService.saveConfig()
    }
  }

  private static async fallbackToDefaultExportTarget(): Promise<void> {
    LogStorageService.storageConfig = LogStorageService.createDefaultTargetConfig(LogStorageService.storageConfig)
    await LogStorageService.saveConfig()
  }

  private static async checkCustomUriPersistentPermission(uri: string): Promise<boolean> {
    let normalized = LogStorageService.sanitizeCustomUri(uri)
    if (!normalized) {
      return false
    }

    let policies: fileShare.PolicyInfo[] = [{
      uri: normalized,
      operationMode: PERSIST_URI_OPERATION_MODE
    } as fileShare.PolicyInfo]

    try {
      let raw = await fileShare.checkPersistentPermission(policies) as Object
      if (typeof raw === 'boolean') {
        return raw
      }

      if (Array.isArray(raw) && raw.length > 0) {
        let first = raw[0] as Record<string, Object>
        let boolLike = first['isPersisted'] ?? first['persisted'] ?? first['granted']
        if (typeof boolLike === 'boolean') {
          return boolLike
        }
        if (typeof boolLike === 'number') {
          return boolLike > 0
        }
      }
      return false
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `check persistent permission failed: ${JSON.stringify(err)}`)
      return false
    }
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
      if (!LogStorageService.isUriPath(directory)) {
        LogStorageService.ensureDirectoryExists(directory)
      }
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
      // 鐩綍鍙兘鐢卞苟鍙戞祦绋嬪垱寤猴紝鍐嶆鏍￠獙鍗冲彲
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

  // 褰掍竴鍖栨渶澶у瓨鍌ㄦ潯鏁帮紝閬垮厤杩囧ぇ瀵艰嚧鍐呭瓨宄板€?
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

  // 鐢熸晥鐨勫唴瀛樹笂闄?
  private static getEffectiveMaxEntries(): number {
    return LogStorageService.normalizeMaxEntries(LogStorageService.storageConfig.maxLocalEntries)
  }

  // 鎴柇瓒呴暱瀛楃涓诧紝闃叉鍗曟潯鏃ュ織杩囧ぇ
  private static truncateString(value: string | undefined, limit: number): string | undefined {
    if (value === undefined) {
      return undefined
    }
    if (value.length <= limit) {
      return value
    }
    return `${value.substring(0, limit)}...`
  }

  // 鍗曟潯鏃ュ織鐦﹁韩
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

    // 褰掍竴鍖栧悗鍙嶈浆锛屼繚璇佹渶缁堚€滄渶鏂板湪鍓嶁€?
    normalizedBatch.reverse()
    return normalizedBatch
  }

  // 鎵归噺鏃ュ織鐦﹁韩骞惰繃婊ゅ紓甯搁」
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

  // 鏋勫缓鍙畨鍏ㄨ惤鐩樼殑 payload锛堟寜鏉℃暟鍜屽唴瀹瑰ぇ灏忓弻閲嶈鍓級
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

  // 闄愰杈撳嚭瑁佸壀鏃ュ織锛岄伩鍏嶉珮棰戜簨浠朵笅鏃ュ織椋庢毚
  private static warnPersistTruncate(memoryCount: number, savedCount: number): void {
    let now = LogStorageService.nowProvider()
    if (now - LogStorageService.lastPersistTruncateWarnAt < 10000) {
      return
    }
    LogStorageService.lastPersistTruncateWarnAt = now
    hilog.warn(DOMAIN, TAG, `Persist entries truncated: memory=${memoryCount}, saved=${savedCount}`)
  }

  // 浠?Preferences 鍔犺浇鏃ュ織鏉＄洰
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

  // 鎸佷箙鍖栨棩蹇楁潯鐩埌 Preferences
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

  // 鍔犺浇瀛樺偍閰嶇疆
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
      let exportTargetType = await store.get(PREF_KEY_LOG_EXPORT_TARGET_TYPE, '') as string
      let exportTargetValue = await store.get(PREF_KEY_LOG_EXPORT_TARGET_VALUE, '') as string
      let exportAuthMode = await store.get(PREF_KEY_LOG_EXPORT_AUTH_MODE, '') as string

      let retentionDaysNumber = typeof retentionDays === 'number' ? retentionDays : Number(retentionDays as string)
      let normalized = LogStorageService.normalizeStorageConfig({
        maxLocalEntries: LogStorageService.normalizeMaxEntries(maxEntries),
        retentionDays: LogStorageService.normalizeRetentionDays(retentionDaysNumber),
        autoExportEnabled: LogStorageService.normalizeBoolean(
          autoExport,
          DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled
        ),
        exportPath: LogStorageService.sanitizeConfiguredExportDirectory(exportPath),
        exportTargetType: exportTargetType as LogExportTargetType,
        exportTargetValue: exportTargetValue,
        exportAuthMode: exportAuthMode as LogExportAuthMode
      })
      LogStorageService.storageConfig = normalized

      if (exportTargetType.length === 0) {
        await LogStorageService.saveConfig()
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // 淇濆瓨瀛樺偍閰嶇疆
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
      await store.put(
        PREF_KEY_LOG_EXPORT_TARGET_TYPE,
        LogStorageService.storageConfig.exportTargetType ?? EXPORT_TARGET_DOWNLOAD
      )
      await store.put(
        PREF_KEY_LOG_EXPORT_TARGET_VALUE,
        LogStorageService.storageConfig.exportTargetValue ?? ''
      )
      await store.put(
        PREF_KEY_LOG_EXPORT_AUTH_MODE,
        LogStorageService.storageConfig.exportAuthMode ?? EXPORT_AUTH_RUNTIME
      )
      await store.flush()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `saveConfig failed: ${JSON.stringify(err)}`)
    }
  }

  // 娓呯悊杩囨湡鏃ュ織鏉＄洰
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

  // 杞崲涓?CSV 鏍煎紡
  private static toCsv(entries: LogEntry[]): string {
    let header = '鏃堕棿,浜嬩欢绫诲瀷,璇︽儏,杩涚▼鍚?PID,缁撴灉'
    let lines: string[] = [header]

    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      // CSV 涓弻寮曞彿杞箟
      let detail = `"${entry.detail.replace(/"/g, '""')}"`
      let process = entry.processName || ''
      let pid = entry.pid !== undefined ? entry.pid.toString() : ''
      let result = getLogEventResultLabel(entry.result)

      lines.push(`${time},${type},${detail},${process},${pid},${result}`)
    }

    return lines.join('\n')
  }

  // 杞崲涓虹函鏂囨湰鏍煎紡
  private static toTxt(entries: LogEntry[]): string {
    let lines: string[] = []

    for (let entry of entries) {
      let time = formatLogTimestamp(entry.timestamp)
      let type = getLogEventTypeLabel(entry.eventType)
      let result = getLogEventResultLabel(entry.result)
      let line = `[${time}] [${type}] [${result}] ${entry.detail}`

      if (entry.processName) {
        line += ` (杩涚▼: ${entry.processName})`
      }
      if (entry.filePath) {
        line += ` 璺緞: ${entry.filePath}`
      }
      if (entry.remoteAddr) {
        line += ` 鍦板潃: ${entry.remoteAddr}`
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
  errorCode?: number
  errorMessage?: string
}

interface ResolvedExportTarget {
  targetType: LogExportTargetType
  authMode: LogExportAuthMode
  directory: string
}

