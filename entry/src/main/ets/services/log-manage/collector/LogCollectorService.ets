import { common } from '@kit.AbilityKit'
import { AppInfo } from '../../../constants/AppConstants'
import { LogEntry, LogEventType } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import {
  AuditSubscribeResult,
  CollectorStartResult,
  CollectorStopResult,
  CollectorStatus,
  CrashSubscribeResult,
  InitializeResult
} from '../common/LogManagePorts'
import { LogSettingsRepository } from '../repository/LogSettingsRepository'
import { LogStorageMaintenanceService } from '../maintenance/LogStorageMaintenanceService'
import { LogAuditSource } from '../source/LogAuditSource'
import { LogCrashSource } from '../source/LogCrashSource'
import { ErrorLike } from '../../../types/LooseValueTypes'

const TAG = 'LogCollectorService'

export class LogCollectorService {
  private static initialized: boolean = false
  private static running: boolean = false
  private static auditEnabled: boolean = false
  private static crashEnabled: boolean = false
  private static auditReady: boolean = false
  private static crashReady: boolean = false
  private static pendingEntries: LogEntry[] = []
  private static flushTimerId: number = -1
  private static flushPromise: Promise<void> | null = null
  private static readonly BATCH_FLUSH_INTERVAL_MS: number = 200
  private static readonly MAX_PENDING_ENTRIES: number = 1200
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
    let repoReady = await LogStorageMaintenanceService.initialize(context)
    if (!repoReady.success) {
      return repoReady
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
    let subscribeConfig = await LogSettingsRepository.loadSubscriptionConfig()
    let targetTypes = subscribeConfig.subscribeAll ? undefined : subscribeConfig.subscribedTypes
    let auditTypes = targetTypes?.filter((type: LogEventType) => type !== LogEventType.CRASH)
    let shouldCollectCrash = targetTypes === undefined || targetTypes.includes(LogEventType.CRASH)
    let shouldCollectAudit = auditTypes === undefined || auditTypes.length > 0
    LogCollectorService.auditEnabled = shouldCollectAudit
    LogCollectorService.crashEnabled = shouldCollectCrash
    let auditResult: AuditSubscribeResult = auditTypes === undefined || auditTypes.length > 0 ?
      await LogAuditSource.subscribe((entry: LogEntry) => {
        LogCollectorService.handleIncomingEntry(entry)
      }, auditTypes) :
      LogCollectorService.buildSkippedAuditSubscribeResult()
    let crashResult: CrashSubscribeResult = shouldCollectCrash ?
      LogCrashSource.subscribe((entry: LogEntry) => {
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
    LogAuditSource.unsubscribe()
    LogCrashSource.unsubscribe()
    if (LogCollectorService.flushTimerId >= 0) {
      clearTimeout(LogCollectorService.flushTimerId)
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
    LogCollectorService.flushTimerId = setTimeout(() => {
      LogCollectorService.flushTimerId = -1
      LogCollectorService.flushPendingEntries().catch((err: ErrorLike) => {
        LogUtils.error(TAG, `flushPendingEntries timer failed: ${JSON.stringify(err)}`)
      })
    }, LogCollectorService.BATCH_FLUSH_INTERVAL_MS) as number
  }

  private static async flushPendingEntries(): Promise<void> {
    if (LogCollectorService.flushPromise) {
      return LogCollectorService.flushPromise
    }
    if (LogCollectorService.pendingEntries.length === 0) {
      return
    }
    LogCollectorService.flushPromise = LogCollectorService.doFlush()
    try {
      await LogCollectorService.flushPromise
    } finally {
      LogCollectorService.flushPromise = null
    }
  }

  private static async doFlush(): Promise<void> {
    let batch = LogCollectorService.pendingEntries.slice()
    LogCollectorService.pendingEntries = []
    try {
      let saved = await LogStorageMaintenanceService.appendEntries(batch)
      LogUtils.info(TAG, `flushPendingEntries result: batch=${batch.length}, saved=${saved.success}, pendingAfterFlush=${LogCollectorService.pendingEntries.length}`)
      if (!saved.success) {
        LogCollectorService.requeueFailedBatch(batch, 'flushPendingEntries failed')
      }
    } catch (err) {
      LogCollectorService.requeueFailedBatch(batch, 'flushPendingEntries exception')
      LogUtils.error(TAG, `flushPendingEntries exception: ${JSON.stringify(err)}`)
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
}
