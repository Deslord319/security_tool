import { common } from '@kit.AbilityKit'
import { AppInfo } from '../../../constants/AppConstants'
import { LogEntry, LogEventType, LogSubscriptionConfig } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import {
  AuditSubscribeResult,
  CollectorStartResult,
  CollectorStopResult,
  CollectorStatus,
  CrashSubscribeResult,
  InitializeResult,
  LogAuditSourcePort,
  LogConfigRepositoryPort,
  LogCrashSourcePort,
  LogRepositoryPort,
  MutationResult,
  ServiceResult
} from '../common/LogManagePorts'
import { LogConfigRepository } from '../repository/LogConfigRepository'
import { LogRepository } from '../repository/LogRepository'
import { LogAuditSource } from '../source/LogAuditSource'
import { LogCrashSource } from '../source/LogCrashSource'

const TAG = 'LogCollectorService'

interface CollectorRepositoryDeps {
  init(context: common.UIAbilityContext): Promise<InitializeResult>
  addEntries(entries: LogEntry[]): Promise<MutationResult>
}

interface CollectorConfigDeps {
  init(context: common.UIAbilityContext): Promise<ServiceResult>
  loadSubscriptionConfig(): Promise<LogSubscriptionConfig>
}

interface LogCollectorTestDeps {
  repositoryPort?: CollectorRepositoryDeps
  configPort?: CollectorConfigDeps
  auditSourcePort?: LogAuditSourcePort
  crashSourcePort?: LogCrashSourcePort
  setTimerFn?: (task: () => void, delayMs: number) => number
  clearTimerFn?: (timerId: number) => void
}

class DefaultCollectorRepositoryPort implements CollectorRepositoryDeps {
  init(context: common.UIAbilityContext): Promise<InitializeResult> {
    return LogRepository.init(context)
  }

  addEntries(entries: LogEntry[]): Promise<MutationResult> {
    return LogRepository.addEntries(entries)
  }
}

class DefaultCollectorConfigPort implements CollectorConfigDeps {
  init(context: common.UIAbilityContext): Promise<ServiceResult> {
    return LogConfigRepository.init(context)
  }

  loadSubscriptionConfig(): Promise<LogSubscriptionConfig> {
    return LogConfigRepository.loadSubscriptionConfig()
  }
}

class DefaultCollectorAuditSourcePort implements LogAuditSourcePort {
  subscribe(onEntry: (entry: LogEntry) => void, eventTypes?: LogEventType[]): Promise<AuditSubscribeResult> {
    return LogAuditSource.subscribe(onEntry, eventTypes)
  }

  unsubscribe(): boolean {
    return LogAuditSource.unsubscribe()
  }

  getStatus() {
    return LogAuditSource.getStatus()
  }
}

class DefaultCollectorCrashSourcePort implements LogCrashSourcePort {
  subscribe(onEntry: (entry: LogEntry) => void): CrashSubscribeResult {
    return LogCrashSource.subscribe(onEntry)
  }

  unsubscribe(): boolean {
    return LogCrashSource.unsubscribe()
  }

  getStatus() {
    return LogCrashSource.getStatus()
  }
}

export class LogCollectorService {
  private static initialized: boolean = false
  private static running: boolean = false
  private static auditEnabled: boolean = false
  private static crashEnabled: boolean = false
  private static auditReady: boolean = false
  private static crashReady: boolean = false
  private static pendingEntries: LogEntry[] = []
  private static flushTimerId: number = -1
  private static isFlushingEntries: boolean = false
  private static readonly BATCH_FLUSH_INTERVAL_MS: number = 200
  private static readonly MAX_PENDING_ENTRIES: number = 1200
  private static setTimerFn: (task: () => void, delayMs: number) => number =
    (task: () => void, delayMs: number): number => setTimeout(task, delayMs) as number
  private static clearTimerFn: (timerId: number) => void =
    (timerId: number): void => clearTimeout(timerId)
  private static repositoryPort: CollectorRepositoryDeps = new DefaultCollectorRepositoryPort()
  private static configPort: CollectorConfigDeps = new DefaultCollectorConfigPort()
  private static auditSourcePort: LogAuditSourcePort = new DefaultCollectorAuditSourcePort()
  private static crashSourcePort: LogCrashSourcePort = new DefaultCollectorCrashSourcePort()
  private static readonly INTERNAL_LOG_PATH_KEYWORDS: string[] = [
    'preferences/log_settings',
    'preferences/theme_preferences',
    'files/hiappevent/',
    'databases/appevent.db',
    'files/securitylog/'
  ]

  static async init(context: common.UIAbilityContext): Promise<InitializeResult> {
    if (LogCollectorService.initialized) {
      return { success: true, code: 'ok' }
    }
    let repoReady = await LogCollectorService.repositoryPort.init(context)
    if (!repoReady.success) {
      return repoReady
    }
    let configReady = await LogCollectorService.configPort.init(context)
    if (!configReady.success) {
      return { success: false, code: 'config_init_failed' }
    }
    LogCollectorService.initialized = true
    return { success: true, code: 'ok' }
  }

  static async start(): Promise<CollectorStartResult> {
    if (LogCollectorService.running) {
      return LogCollectorService.buildStartResult(true, 'ok')
    }
    if (!LogCollectorService.initialized) {
      return LogCollectorService.buildStartResult(false, 'not_initialized')
    }
    let subscribeConfig = await LogCollectorService.configPort.loadSubscriptionConfig()
    let targetTypes = subscribeConfig.subscribeAll ? undefined : subscribeConfig.subscribedTypes
    let auditTypes = targetTypes?.filter((type: LogEventType) => type !== LogEventType.CRASH)
    let shouldCollectCrash = targetTypes === undefined || targetTypes.includes(LogEventType.CRASH)
    let shouldCollectAudit = auditTypes === undefined || auditTypes.length > 0
    LogCollectorService.auditEnabled = shouldCollectAudit
    LogCollectorService.crashEnabled = shouldCollectCrash
    let auditResult: AuditSubscribeResult = auditTypes === undefined || auditTypes.length > 0 ?
      await LogCollectorService.auditSourcePort.subscribe((entry: LogEntry) => {
        LogCollectorService.handleIncomingEntry(entry)
      }, auditTypes) :
      LogCollectorService.buildSkippedAuditSubscribeResult()
    let crashResult: CrashSubscribeResult = shouldCollectCrash ?
      LogCollectorService.crashSourcePort.subscribe((entry: LogEntry) => {
        LogCollectorService.handleIncomingEntry(entry)
      }) :
      LogCollectorService.buildSkippedCrashSubscribeResult()

    LogCollectorService.auditReady = shouldCollectAudit && auditResult.success
    LogCollectorService.crashReady = shouldCollectCrash && crashResult.success
    let success = LogCollectorService.auditReady || LogCollectorService.crashReady
    LogCollectorService.running = success
    if (!success) {
      return LogCollectorService.buildStartResult(false, 'no_source_available')
    }
    if (LogCollectorService.pendingEntries.length > 0) {
      LogCollectorService.scheduleFlushPendingEntries()
    }
    let allEnabledSourcesReady = (!LogCollectorService.auditEnabled || LogCollectorService.auditReady) &&
      (!LogCollectorService.crashEnabled || LogCollectorService.crashReady)
    return LogCollectorService.buildStartResult(
      true,
      allEnabledSourcesReady ? 'ok' : 'partial'
    )
  }

  static async stop(): Promise<CollectorStopResult> {
    if (!LogCollectorService.running && LogCollectorService.pendingEntries.length === 0) {
      return {
        success: true,
        code: 'not_running',
        status: LogCollectorService.getStatus()
      }
    }
    LogCollectorService.running = false
    LogCollectorService.auditEnabled = false
    LogCollectorService.crashEnabled = false
    LogCollectorService.auditReady = false
    LogCollectorService.crashReady = false
    LogCollectorService.auditSourcePort.unsubscribe()
    LogCollectorService.crashSourcePort.unsubscribe()
    if (LogCollectorService.flushTimerId >= 0) {
      LogCollectorService.clearTimerFn(LogCollectorService.flushTimerId)
      LogCollectorService.flushTimerId = -1
    }
    await LogCollectorService.flushPendingEntries()
    let success = LogCollectorService.pendingEntries.length === 0
    return {
      success: success,
      code: success ? 'ok' : 'flush_failed',
      status: LogCollectorService.getStatus()
    }
  }

  static getStatus(): CollectorStatus {
    let auditFailed = LogCollectorService.auditEnabled && !LogCollectorService.auditReady
    let crashFailed = LogCollectorService.crashEnabled && !LogCollectorService.crashReady
    let degraded = auditFailed || crashFailed
    let status: CollectorStatus = {
      running: LogCollectorService.running,
      auditReady: LogCollectorService.auditReady,
      crashReady: LogCollectorService.crashReady,
      pendingCount: LogCollectorService.pendingEntries.length,
      degraded: degraded
    }
    if (auditFailed && crashFailed) {
      status.degradedReason = 'partial'
    } else if (auditFailed) {
      status.degradedReason = 'audit_failed'
    } else if (crashFailed) {
      status.degradedReason = 'crash_failed'
    } else {
      status.degradedReason = undefined
    }
    return status
  }

  private static handleIncomingEntry(entry: LogEntry): void {
    if (!LogCollectorService.running) {
      LogUtils.warn(TAG, `Ignored incoming entry because collector is stopped: type=${entry.eventType}, detail=${entry.detail}`)
      return
    }
    if (LogCollectorService.shouldIgnoreInternalEntry(entry)) {
      LogUtils.info(TAG, `Ignored internal log entry: type=${entry.eventType}, path=${entry.filePath || '-'}`)
      return
    }
    LogCollectorService.pendingEntries.push(entry)
    if (LogCollectorService.pendingEntries.length > LogCollectorService.MAX_PENDING_ENTRIES) {
      let dropped = LogCollectorService.pendingEntries.length - LogCollectorService.MAX_PENDING_ENTRIES
      LogCollectorService.pendingEntries.splice(0, dropped)
      LogUtils.warn(TAG, `Dropped ${dropped} queued log entries due to burst traffic`)
    }
    LogCollectorService.scheduleFlushPendingEntries()
  }

  private static shouldIgnoreInternalEntry(entry: LogEntry): boolean {
    if (entry.eventType !== LogEventType.FILE) {
      return false
    }
    let process = (entry.processName || '').toLowerCase()
    let content = `${entry.filePath || ''} ${entry.detail || ''}`.toLowerCase()
    let bundleName = AppInfo.BUNDLE_NAME.toLowerCase()
    let fromSelfProcess = process.includes(bundleName)
    for (let keyword of LogCollectorService.INTERNAL_LOG_PATH_KEYWORDS) {
      if (content.includes(keyword)) {
        return true
      }
    }
    return fromSelfProcess && content.includes(bundleName)
  }

  private static scheduleFlushPendingEntries(): void {
    if (LogCollectorService.flushTimerId >= 0) {
      return
    }
    LogCollectorService.flushTimerId = LogCollectorService.setTimerFn(() => {
      LogCollectorService.flushTimerId = -1
      LogCollectorService.flushPendingEntries().catch((err: Object) => {
        LogUtils.error(TAG, `flushPendingEntries timer failed: ${JSON.stringify(err)}`)
      })
    }, LogCollectorService.BATCH_FLUSH_INTERVAL_MS)
  }

  private static async flushPendingEntries(): Promise<void> {
    if (LogCollectorService.isFlushingEntries || LogCollectorService.pendingEntries.length === 0) {
      return
    }
    LogCollectorService.isFlushingEntries = true
    let batch = LogCollectorService.pendingEntries.slice()
    LogCollectorService.pendingEntries = []
    try {
      let saved = await LogCollectorService.repositoryPort.addEntries(batch)
      LogUtils.info(TAG, `flushPendingEntries result: batch=${batch.length}, saved=${saved.success}, pendingAfterFlush=${LogCollectorService.pendingEntries.length}`)
      if (!saved.success) {
        LogCollectorService.requeueFailedBatch(batch, 'flushPendingEntries failed')
      }
    } catch (err) {
      LogCollectorService.requeueFailedBatch(batch, 'flushPendingEntries exception')
      LogUtils.error(TAG, `flushPendingEntries exception: ${JSON.stringify(err)}`)
    } finally {
      LogCollectorService.isFlushingEntries = false
    }
    if (LogCollectorService.running && LogCollectorService.pendingEntries.length > 0) {
      LogCollectorService.scheduleFlushPendingEntries()
    }
  }

  private static requeueFailedBatch(batch: LogEntry[], reason: string): void {
    if (batch.length === 0) {
      return
    }
    LogCollectorService.pendingEntries = batch.concat(LogCollectorService.pendingEntries)
    if (LogCollectorService.pendingEntries.length > LogCollectorService.MAX_PENDING_ENTRIES) {
      let dropped = LogCollectorService.pendingEntries.length - LogCollectorService.MAX_PENDING_ENTRIES
      LogCollectorService.pendingEntries = LogCollectorService.pendingEntries.slice(dropped)
      LogUtils.warn(TAG, `${reason} dropped ${dropped} queued entries`)
    }
    LogUtils.warn(TAG, `${reason}, batch=${batch.length}`)
  }

  private static buildStartResult(
    success: boolean,
    code: 'ok' | 'partial' | 'no_source_available' | 'not_initialized'
  ): CollectorStartResult {
    let result: CollectorStartResult = {
      success: success,
      code: code,
      status: LogCollectorService.getStatus()
    }
    return result
  }

  private static buildSkippedAuditSubscribeResult(): AuditSubscribeResult {
    let result: AuditSubscribeResult = {
      success: false,
      code: 'unsupported',
      subscribedEventIds: [],
      failedEventIds: []
    }
    return result
  }

  private static buildSkippedCrashSubscribeResult(): CrashSubscribeResult {
    let result: CrashSubscribeResult = {
      success: false,
      code: 'unsupported'
    }
    return result
  }

  static setTestDeps(deps: LogCollectorTestDeps): void {
    LogCollectorService.initialized = false
    LogCollectorService.running = false
    LogCollectorService.auditEnabled = false
    LogCollectorService.crashEnabled = false
    LogCollectorService.auditReady = false
    LogCollectorService.crashReady = false
    LogCollectorService.pendingEntries = []
    LogCollectorService.flushTimerId = -1
    LogCollectorService.isFlushingEntries = false
    LogCollectorService.setTimerFn = (task: () => void, delayMs: number): number => setTimeout(task, delayMs) as number
    LogCollectorService.clearTimerFn = (timerId: number): void => clearTimeout(timerId)
    LogCollectorService.repositoryPort = new DefaultCollectorRepositoryPort()
    LogCollectorService.configPort = new DefaultCollectorConfigPort()
    LogCollectorService.auditSourcePort = new DefaultCollectorAuditSourcePort()
    LogCollectorService.crashSourcePort = new DefaultCollectorCrashSourcePort()
    if (deps.repositoryPort) {
      LogCollectorService.repositoryPort = deps.repositoryPort
    }
    if (deps.configPort) {
      LogCollectorService.configPort = deps.configPort
    }
    if (deps.auditSourcePort) {
      LogCollectorService.auditSourcePort = deps.auditSourcePort
    }
    if (deps.crashSourcePort) {
      LogCollectorService.crashSourcePort = deps.crashSourcePort
    }
    if (deps.setTimerFn) {
      LogCollectorService.setTimerFn = deps.setTimerFn
    }
    if (deps.clearTimerFn) {
      LogCollectorService.clearTimerFn = deps.clearTimerFn
    }
  }
}
